import Foundation
import CSQLite
import Darwin

public protocol LedgerStore: AnyObject {
    func load() throws -> Ledger
    func save(_ ledger: Ledger) throws
}
public final class SQLiteLedgerStore: LedgerStore {
    private var db: OpaquePointer?
    private var lockFD: Int32 = -1
    public let directory: URL
    public let databaseURL: URL
    public static func defaultDirectory(environment: [String: String] = ProcessInfo.processInfo.environment) throws -> URL {
        if let override = environment["STUDY_TIMER_DATA_DIR"] {
            guard override.hasPrefix("/"), !override.isEmpty else { throw LedgerError.invalid("STUDY_TIMER_DATA_DIR 必须是绝对路径") }
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("StudyTimerP4", isDirectory: true)
    }
    public init(directory: URL, now: Date) throws {
        self.directory = directory.standardizedFileURL.resolvingSymlinksInPath()
        databaseURL = self.directory.appendingPathComponent("study.sqlite3")
        do {
            try FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
            lockFD = Darwin.open(self.directory.appendingPathComponent("writer.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
            guard lockFD >= 0, flock(lockFD, LOCK_EX | LOCK_NB) == 0 else { throw LedgerError.invalid("该数据目录已由另一个应用实例使用，或无法加锁") }
            let exists = FileManager.default.fileExists(atPath: databaseURL.path)
            let flags = SQLITE_OPEN_READWRITE | (exists ? 0 : SQLITE_OPEN_CREATE) | SQLITE_OPEN_FULLMUTEX
            guard sqlite3_open_v2(databaseURL.path, &db, flags, nil) == SQLITE_OK else { throw error("无法打开学习数据库") }
            sqlite3_busy_timeout(db, 1500)
            if exists {
                guard try scalar("PRAGMA quick_check") == "ok" else { throw LedgerError.invalid("数据库完整性检查失败，原文件已保留") }
                guard try scalar("PRAGMA user_version") == "2" else { throw LedgerError.invalid("数据库版本未知，原文件已保留") }
                _ = try load() // Validate before changing pragmas or writing anything.
            }
            try execute("PRAGMA journal_mode=WAL")
            try execute("PRAGMA synchronous=FULL")
            if !exists {
                try execute("BEGIN IMMEDIATE")
                do {
                    try execute("CREATE TABLE ledger (id INTEGER PRIMARY KEY CHECK(id=1), payload TEXT NOT NULL)")
                    try execute("PRAGMA user_version=2")
                    try writePayload(Ledger(now: now))
                    try execute("COMMIT")
                } catch { try? execute("ROLLBACK"); throw error }
            }
        } catch {
            closeResources()
            throw error
        }
    }
    deinit { closeResources() }
    private func closeResources() {
        if let db = db { sqlite3_close(db); self.db = nil }
        if lockFD >= 0 { _ = flock(lockFD, LOCK_UN); Darwin.close(lockFD); lockFD = -1 }
    }
    private func error(_ context: String) -> LedgerError {
        .invalid(context + "：" + (db.map { String(cString: sqlite3_errmsg($0)) } ?? "数据库未打开"))
    }
    private func execute(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw error("保存或读取失败") }
    }
    private func scalar(_ sql: String) throws -> String {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { throw error("无法读取数据库") }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW, let text = sqlite3_column_text(statement, 0) else { throw error("数据库缺少必要记录") }
        return String(cString: text)
    }
    public func load() throws -> Ledger {
        let text = try scalar("SELECT payload FROM ledger WHERE id=1")
        do {
            let ledger = try JSONDecoder().decode(Ledger.self, from: Data(text.utf8))
            try ledger.validate()
            return ledger
        } catch { throw LedgerError.invalid("学习记录无法读取，未覆盖原文件：\(error.localizedDescription)") }
    }
    private func writePayload(_ ledger: Ledger) throws {
        try ledger.validate()
        let payload = String(decoding: try JSONEncoder().encode(ledger), as: UTF8.self)
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "INSERT INTO ledger(id,payload) VALUES(1,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload", -1, &statement, nil) == SQLITE_OK else { throw error("无法准备保存") }
        defer { sqlite3_finalize(statement) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        guard sqlite3_bind_text(statement, 1, payload, -1, transient) == SQLITE_OK,
              sqlite3_step(statement) == SQLITE_DONE else { throw error("无法写入学习记录") }
    }
    public func save(_ ledger: Ledger) throws {
        try ledger.validate()
        try execute("BEGIN IMMEDIATE")
        do {
            try writePayload(ledger)
            try execute("COMMIT")
        } catch { try? execute("ROLLBACK"); throw error }
    }
}

/// Serial owner used from the main actor. Actions commit before changing the visible phase.
public final class StudyController {
    public private(set) var engine: TimerEngine
    public private(set) var lastSavedAt: Date
    public private(set) var lastSaveError: String?
    private let source: TimeSource
    private let store: LedgerStore
    private var lastCheckpointAttempt: Date
    public init(source: TimeSource, store: LedgerStore) throws {
        self.source = source; self.store = store
        engine = try TimerEngine(ledger: store.load())
        engine.recover(at: source.now)
        try store.save(engine.ledger)
        lastSavedAt = engine.ledger.checkpointAt
        lastCheckpointAttempt = lastSavedAt
    }
    public var ledger: Ledger { engine.ledger }
    public func tick() {
        let previousMilestones=engine.ledger.milestones.count
        let previousDay = engine.ledger.day
        engine.advance(to: source.now)
        let dayChanged = engine.ledger.day != previousDay
        if dayChanged || previousMilestones != engine.ledger.milestones.count || (engine.ledger.phase == .running && source.now.timeIntervalSince(lastCheckpointAttempt) >= 5) {
            do { try checkpoint() } catch { /* Keep elapsed time in memory and expose failure for retry. */ }
        }
    }
    public func checkpoint() throws {
        lastCheckpointAttempt = source.now
        engine.advance(to: source.now)
        do {
            try store.save(engine.ledger)
            lastSavedAt = engine.ledger.checkpointAt; lastSaveError = nil
        } catch { lastSaveError = error.localizedDescription; throw error }
    }
    public func perform(_ action: Action) throws {
        var candidate = engine
        switch action {
        case .start: candidate.start(at: source.now)
        case .pause: candidate.pause(at: source.now)
        case .resume: candidate.resume(at: source.now)
        case .stop: candidate.stop(at: source.now)
        case .quit: candidate.stop(at: source.now, reason: .quit)
        }
        do {
            try store.save(candidate.ledger)
            engine = candidate; lastSavedAt = candidate.ledger.checkpointAt; lastCheckpointAttempt = lastSavedAt; lastSaveError = nil
        } catch { lastSaveError = error.localizedDescription; throw error }
    }
    public func editNotes(_ notes:[UUID:String]) throws { try modify { try $0.editNotes(notes) } }
    public func resolveTail(_ id:UUID,merge:Bool) throws { try modify { try $0.resolveTail(id,merge:merge) } }
    public func deleteRecord(_ target: RecordDeletion, notes: [UUID:String] = [:]) throws {
        try modify {
            try $0.editNotes(notes)
            try $0.deleteRecord(target)
        }
    }
    public func markPresented(_ ids:Set<String>) throws { try modify { $0.markPresented(ids) } }
    private func modify(_ operation:(inout TimerEngine)throws->Void) throws {
        var candidate=engine
        candidate.advance(to:source.now)
        do {
            try operation(&candidate)
            try store.save(candidate.ledger)
            engine=candidate;lastSavedAt=candidate.ledger.checkpointAt;lastCheckpointAttempt=lastSavedAt;lastSaveError=nil
        } catch { lastSaveError=error.localizedDescription;throw error }
    }
    public enum Action { case start, pause, resume, stop, quit }
}
