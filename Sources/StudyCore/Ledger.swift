import Foundation

public enum StudyPhase: String, Codable { case stopped, running, paused }
public enum EndReason: String, Codable { case stopped, midnight, quit, interrupted }
public struct StudyInterval: Codable, Equatable {
    public var start: Date
    public var end: Date
    public var seconds: Double { end.timeIntervalSince(start) }
}
public struct StudySession: Codable, Identifiable, Equatable {
    public let id: UUID
    public let day: String
    public let startedAt: Date
    public var endedAt: Date?
    public var endReason: EndReason?
    public var intervals: [StudyInterval]
    public var seconds: Double { intervals.reduce(0) { $0 + $1.seconds } }
}
public struct Ledger: Codable, Equatable {
    public var schemaVersion = 1
    public var phase: StudyPhase = .stopped
    public var day: String
    public var checkpointAt: Date
    public var activeSessionID: UUID?
    public var sessions: [StudySession] = []
    public init(now: Date) { day = StudyDate.day(now); checkpointAt = now }
    public func total(on day: String) -> Double { sessions.filter { $0.day == day }.reduce(0) { $0 + $1.seconds } }
    public func validate() throws {
        guard schemaVersion == 1 else { throw LedgerError.invalid("不支持的数据版本 \(schemaVersion)") }
        guard checkpointAt.timeIntervalSince1970.isFinite, StudyDate.day(checkpointAt) == day else {
            throw LedgerError.invalid("检查点日期不一致")
        }
        guard Set(sessions.map(\.id)).count == sessions.count else { throw LedgerError.invalid("学习段 ID 重复") }
        let open = sessions.filter { $0.endedAt == nil }
        guard open.count <= 1, open.first?.id == activeSessionID else { throw LedgerError.invalid("活动学习段引用不一致") }
        guard phase != .running || activeSessionID != nil,
              phase != .stopped || activeSessionID == nil else { throw LedgerError.invalid("计时状态不一致") }
        if let active = open.first {
            guard active.day == day, active.endReason == nil else { throw LedgerError.invalid("活动学习段日期错误") }
        }
        for session in sessions {
            guard session.startedAt.timeIntervalSince1970.isFinite, StudyDate.day(session.startedAt) == session.day,
                  !session.intervals.isEmpty else { throw LedgerError.invalid("学习段日期或有效区间错误") }
            let boundary = StudyDate.nextMidnight(session.startedAt)
            var previous = session.startedAt
            for interval in session.intervals {
                guard interval.start.timeIntervalSince1970.isFinite, interval.end.timeIntervalSince1970.isFinite,
                      interval.start >= previous, interval.end >= interval.start,
                      interval.end <= boundary else { throw LedgerError.invalid("学习区间重叠、越界或时长无效") }
                previous = interval.end
            }
            if let end = session.endedAt {
                guard end.timeIntervalSince1970.isFinite, end >= previous, end <= boundary,
                      session.endReason != nil else { throw LedgerError.invalid("学习段结束信息错误") }
            } else if previous > checkpointAt { throw LedgerError.invalid("学习段超出检查点") }
        }
    }
}
public enum LedgerError: Error, LocalizedError {
    case invalid(String)
    public var errorDescription: String? { if case .invalid(let text) = self { return text }; return nil }
}
