import Foundation

public struct TimerEngine {
    public private(set) var ledger: Ledger
    public init(ledger: Ledger) throws { try ledger.validate(); self.ledger = ledger }
    private var activeIndex: Int? { ledger.sessions.firstIndex { $0.id == ledger.activeSessionID } }
    private mutating func begin(at date: Date) {
        let session = StudySession(id: UUID(), day: StudyDate.day(date), startedAt: date, intervals: [StudyInterval(start: date, end: date)])
        ledger.sessions.append(session)
        ledger.activeSessionID = session.id
    }
    private mutating func close(at date: Date, reason: EndReason) {
        if let index = activeIndex {
            ledger.sessions[index].endedAt = date
            ledger.sessions[index].endReason = reason
        }
        ledger.activeSessionID = nil
    }
    private mutating func extend(to date: Date) {
        guard ledger.phase == .running, let index = activeIndex else { return }
        let last = ledger.sessions[index].intervals.count - 1
        ledger.sessions[index].intervals[last].end = date
    }
    public mutating func advance(to date: Date) {
        guard date >= ledger.checkpointAt else { return }
        var cursor = ledger.checkpointAt
        while StudyDate.nextMidnight(cursor) <= date {
            let boundary = StudyDate.nextMidnight(cursor)
            extend(to: boundary)
            close(at: boundary, reason: .midnight)
            ledger.day = StudyDate.day(boundary)
            if ledger.phase == .running { begin(at: boundary) }
            cursor = boundary
        }
        extend(to: date)
        ledger.day = StudyDate.day(date)
        ledger.checkpointAt = date
    }
    public mutating func start(at date: Date) {
        advance(to: date)
        guard ledger.phase == .stopped else { return }
        begin(at: ledger.checkpointAt)
        ledger.phase = .running
    }
    public mutating func pause(at date: Date) {
        advance(to: date)
        guard ledger.phase == .running else { return }
        ledger.phase = .paused
    }
    public mutating func resume(at date: Date) {
        advance(to: date)
        guard ledger.phase == .paused else { return }
        if let index = activeIndex {
            ledger.sessions[index].intervals.append(StudyInterval(start: ledger.checkpointAt, end: ledger.checkpointAt))
        } else { begin(at: ledger.checkpointAt) }
        ledger.phase = .running
    }
    public mutating func stop(at date: Date, reason: EndReason = .stopped) {
        advance(to: date)
        close(at: ledger.checkpointAt, reason: reason)
        ledger.phase = .stopped
    }
    /// Recover exactly the saved snapshot. Never advance an old running interval to launch time.
    public mutating func recover(at launch: Date) {
        close(at: ledger.checkpointAt, reason: .interrupted)
        ledger.phase = .stopped
        ledger.day = StudyDate.day(launch)
        ledger.checkpointAt = launch
    }
}
