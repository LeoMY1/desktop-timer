import Foundation
import StudyCore
import CSQLite

final class FakeClock: TimeSource {
    var now: Date
    init(_ text: String = "2026-09-18T09:00:00+08:00") { now = ISO8601DateFormatter().date(from: text)! }
    func add(_ seconds: Double) { now = now.addingTimeInterval(seconds) }
}
final class MemoryStore: LedgerStore {
    var value: Ledger
    var fail = false
    var saves = 0
    init(_ now: Date) { value = Ledger(now: now) }
    func load() throws -> Ledger { value }
    func save(_ ledger: Ledger) throws {
        if fail { throw LedgerError.invalid("injected save failure") }
        value = ledger; saves += 1
    }
}
func expect(_ condition: @autoclosure () throws -> Bool, _ text: String = "Assertion failed") throws {
    if try !condition() { throw LedgerError.invalid(text) }
}
func near(_ a: Double, _ b: Double) -> Bool { abs(a-b) < 0.001 }
let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "work/p3-evidence/core", isDirectory: true)
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
let scratch = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
var checks: [[String: Any]] = []
func test(_ name: String, _ body: () throws -> Void) {
    do { try body(); checks.append(["name": name, "passed": true]) }
    catch { checks.append(["name": name, "passed": false, "error": error.localizedDescription]) }
}
func fixture(_ text: String = "2026-09-18T09:00:00+08:00") throws -> (FakeClock, MemoryStore, StudyController) {
    let clock = FakeClock(text); let store = MemoryStore(clock.now)
    return (clock, store, try StudyController(source: clock, store: store))
}
func mutateSQL(_ path: URL, _ sql: String) throws {
    var db: OpaquePointer?
    guard sqlite3_open(path.path, &db) == SQLITE_OK else { throw LedgerError.invalid("test open failed") }
    defer { sqlite3_close(db) }
    guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw LedgerError.invalid("test SQL failed") }
}

test("launch_is_stopped_and_empty") { let (_,_,c) = try fixture(); try expect(c.ledger.phase == .stopped && c.ledger.sessions.isEmpty) }
test("25_plus_35_minutes_same_session_pause_excluded") {
    let (t,_,c) = try fixture(); try c.perform(.start); t.add(1500); try c.perform(.pause)
    t.add(600); c.tick(); try expect(near(c.ledger.total(on:c.ledger.day),1500))
    try c.perform(.resume); t.add(2100); try c.perform(.stop)
    try expect(c.ledger.sessions.count == 1 && near(c.ledger.total(on:c.ledger.day),3600))
    try expect(c.ledger.sessions[0].intervals.count == 2)
}
test("90_plus_30_minutes_independent_sessions") {
    let (t,_,c) = try fixture(); try c.perform(.start); t.add(5400); try c.perform(.stop)
    t.add(600); try c.perform(.start); t.add(1800); try c.perform(.stop)
    try expect(c.ledger.sessions.count == 2 && near(c.ledger.total(on:c.ledger.day),7200))
}
test("midnight_2340_to_0020") {
    let (t,_,c) = try fixture("2026-09-18T23:40:00+08:00"); try c.perform(.start); t.add(2400); c.tick()
    try expect(c.ledger.phase == .running && c.ledger.sessions.count == 2)
    try expect(near(c.ledger.total(on:"2026-09-18"),1200) && near(c.ledger.total(on:"2026-09-19"),1200))
    try c.ledger.validate()
}
test("exact_midnight_new_day_zero_running") {
    let (t,_,c) = try fixture("2026-09-18T23:59:00+08:00"); try c.perform(.start); t.add(60); c.tick()
    try expect(c.ledger.day == "2026-09-19" && c.ledger.phase == .running && c.ledger.total(on:c.ledger.day) == 0)
    try c.ledger.validate()
}
test("paused_midnight_stays_paused_resume_new_session") {
    let (t,_,c) = try fixture("2026-09-18T23:40:00+08:00"); try c.perform(.start); t.add(600); try c.perform(.pause)
    t.add(1800); c.tick(); try expect(c.ledger.phase == .paused && c.ledger.activeSessionID == nil)
    try expect(c.ledger.sessions.count == 1 && c.ledger.total(on:c.ledger.day) == 0)
    try c.perform(.resume); t.add(300); try c.perform(.stop)
    try expect(c.ledger.sessions.count == 2 && near(c.ledger.total(on:"2026-09-19"),300))
}
test("stopped_midnight_does_not_start") {
    let (t,_,c) = try fixture("2026-09-18T23:59:00+08:00"); t.add(120); c.tick()
    try expect(c.ledger.phase == .stopped && c.ledger.sessions.isEmpty && c.ledger.day == "2026-09-19")
}
test("missed_callbacks_catch_up_two_hour_sleep_simulation") {
    let (t,_,c) = try fixture(); try c.perform(.start); t.add(7200); c.tick()
    try expect(near(c.ledger.total(on:c.ledger.day),7200))
}
test("multi_day_sleep_simulation") {
    let (t,_,c) = try fixture("2026-09-18T23:40:00+08:00"); try c.perform(.start); t.add(86400*2+2400); c.tick()
    try expect(c.ledger.sessions.count == 4)
    try expect(near(c.ledger.total(on:"2026-09-19"),86400) && near(c.ledger.total(on:"2026-09-21"),1200))
    try c.ledger.validate()
}
test("normal_quit_no_closed_interval_accrual") {
    let (t,s,c) = try fixture(); try c.perform(.start); t.add(70); try c.perform(.quit)
    t.add(3600); let next = try StudyController(source:t,store:s)
    try expect(next.ledger.phase == .stopped && near(next.ledger.total(on:next.ledger.day),70))
    try expect(next.ledger.sessions[0].endReason == .quit)
}
test("abnormal_recovery_saved_snapshot_only") {
    let (t,s,c) = try fixture(); try c.perform(.start); t.add(10); c.tick(); t.add(3); c.tick()
    try expect(near(c.ledger.total(on:c.ledger.day),13))
    t.add(3600); let next = try StudyController(source:t,store:s)
    try expect(next.ledger.phase == .stopped && near(next.ledger.total(on:next.ledger.day),10))
    try expect(next.ledger.sessions[0].endReason == .interrupted)
}
test("checkpoint_five_second_cadence") {
    let (t,s,c) = try fixture(); try c.perform(.start); let saves = s.saves
    t.add(4); c.tick(); try expect(s.saves == saves)
    t.add(1); c.tick(); try expect(s.saves == saves+1 && near(s.value.total(on:s.value.day),5))
}
test("critical_actions_save_immediately") {
    let (t,s,c) = try fixture(); try c.perform(.start); t.add(1); try c.perform(.pause)
    try expect(s.value.phase == .paused && near(s.value.total(on:s.value.day),1))
    try c.perform(.resume); try expect(s.value.phase == .running)
    try c.perform(.stop); try expect(s.value.phase == .stopped)
}
test("failed_pause_keeps_running_and_retry_retains_time") {
    let (t,s,c) = try fixture(); try c.perform(.start); t.add(10); s.fail=true
    do { try c.perform(.pause); throw LedgerError.invalid("expected failure") } catch { try expect(c.ledger.phase == .running) }
    try expect(c.lastSaveError != nil)
    s.fail=false; t.add(5); try c.perform(.pause)
    try expect(c.ledger.phase == .paused && near(c.ledger.total(on:c.ledger.day),15) && c.lastSaveError == nil)
}
test("failed_checkpoint_keeps_memory_and_last_good_snapshot") {
    let (t,s,c) = try fixture(); try c.perform(.start); t.add(5); c.tick(); s.fail=true; t.add(5); c.tick()
    try expect(near(s.value.total(on:s.value.day),5) && near(c.ledger.total(on:c.ledger.day),10) && c.lastSaveError != nil)
    s.fail=false; try c.checkpoint(); try expect(near(s.value.total(on:s.value.day),10))
}
test("failed_quit_does_not_stop_live_engine") {
    let (t,s,c) = try fixture(); try c.perform(.start); t.add(4); s.fail=true
    do { try c.perform(.quit); throw LedgerError.invalid("expected failure") } catch { try expect(c.ledger.phase == .running && c.lastSaveError != nil) }
}
test("fractional_seconds_not_rounded_per_tick") {
    let (t,_,c) = try fixture(); try c.perform(.start)
    for _ in 0..<600 { t.add(0.1); c.tick() }
    try expect(abs(c.ledger.total(on:c.ledger.day)-60)<0.001)
}
test("beijing_day_independent_of_host_timezone") {
    let date = ISO8601DateFormatter().date(from:"2026-09-18T16:00:00Z")!
    try expect(StudyDate.day(date)=="2026-09-19" && StudyDate.clock(date)=="00:00")
}
test("display_HH_MM_and_chinese_duration") {
    try expect(StudyDate.timer(59)=="00:00" && StudyDate.timer(3661)=="01:01")
    try expect(StudyDate.duration(1)=="不足1分钟" && StudyDate.duration(5700)=="1小时35分钟")
}
test("sqlite_roundtrip_and_reopen") {
    let dir=scratch.appendingPathComponent("roundtrip"); let t=FakeClock()
    do { let s=try SQLiteLedgerStore(directory:dir,now:t.now); let c=try StudyController(source:t,store:s)
        try c.perform(.start); t.add(123); try c.perform(.quit) }
    t.add(1800); let s=try SQLiteLedgerStore(directory:dir,now:t.now); let c=try StudyController(source:t,store:s)
    try expect(c.ledger.phase == .stopped && near(c.ledger.total(on:c.ledger.day),123))
}
test("second_writer_rejected") {
    let dir=scratch.appendingPathComponent("lock"); let t=FakeClock(); let s=try SQLiteLedgerStore(directory:dir,now:t.now)
    do { _=try SQLiteLedgerStore(directory:dir,now:t.now); throw LedgerError.invalid("second writer accepted") }
    catch { try expect(error.localizedDescription.contains("加锁")) }
    _=try s.load()
}
test("corrupt_file_preserved") {
    let dir=scratch.appendingPathComponent("corrupt"); try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
    let path=dir.appendingPathComponent("study.sqlite3"); let bytes=Data("not a database".utf8); try bytes.write(to:path)
    do { _=try SQLiteLedgerStore(directory:dir,now:FakeClock().now); throw LedgerError.invalid("accepted corrupt") }
    catch { try expect(error.localizedDescription != "accepted corrupt"); try expect(try Data(contentsOf:path)==bytes) }
}
test("unknown_sqlite_version_preserved") {
    let dir=scratch.appendingPathComponent("version"); let t=FakeClock()
    do { _=try SQLiteLedgerStore(directory:dir,now:t.now) }
    let path=dir.appendingPathComponent("study.sqlite3"); try mutateSQL(path,"PRAGMA user_version=99")
    let before=try Data(contentsOf:path)
    do { _=try SQLiteLedgerStore(directory:dir,now:t.now); throw LedgerError.invalid("accepted unknown") }
    catch { try expect(error.localizedDescription.contains("版本未知")); try expect(try Data(contentsOf:path)==before) }
}
test("invalid_payload_preserved") {
    let dir=scratch.appendingPathComponent("payload"); let t=FakeClock()
    do { _=try SQLiteLedgerStore(directory:dir,now:t.now) }
    let path=dir.appendingPathComponent("study.sqlite3"); try mutateSQL(path,"UPDATE ledger SET payload='{}'")
    let before=try Data(contentsOf:path)
    do { _=try SQLiteLedgerStore(directory:dir,now:t.now); throw LedgerError.invalid("accepted invalid") }
    catch { try expect(error.localizedDescription.contains("无法读取")); try expect(try Data(contentsOf:path)==before) }
}
test("invalid_ledger_cannot_replace_good_snapshot") {
    let t=FakeClock(); let s=try SQLiteLedgerStore(directory:scratch.appendingPathComponent("atomic"),now:t.now)
    let original=try s.load(); var invalid=original; invalid.activeSessionID=UUID()
    do { try s.save(invalid); throw LedgerError.invalid("saved invalid") } catch { try expect(try s.load()==original) }
}
test("relative_data_override_rejected") {
    do { _=try SQLiteLedgerStore.defaultDirectory(environment:["STUDY_TIMER_DATA_DIR":"relative"]); throw LedgerError.invalid("accepted relative") }
    catch { try expect(error.localizedDescription.contains("绝对路径")) }
}
let passed=checks.filter { $0["passed"] as? Bool == true }.count
let report:[String:Any] = ["stage":"P3", "kind":"isolated clocks and SQLite", "checks":checks, "allPassed":passed==checks.count,
 "notCovered":["Actual system sleep", "Actual overnight midnight", "UI window behavior"]]
try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:root.appendingPathComponent("core-checks.json"))
print("P3 core checks: \(passed)/\(checks.count)")
for c in checks where c["passed"] as? Bool == false { print(c) }
if passed != checks.count { exit(1) }
