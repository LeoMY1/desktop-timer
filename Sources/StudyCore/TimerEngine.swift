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
        if let index=activeIndex { finishTail(session:index,manual:reason == .stopped) }
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
        var cursor=ledger.checkpointAt
        while cursor < date {
            let midnight=StudyDate.nextMidnight(cursor)
            var next=min(midnight,date)
            let hour=(ledger.milestones.filter{$0.day==ledger.day}.map(\.hour).max() ?? 0)+1
            let remaining=max(0,Double(hour)*3600-ledger.total(on:ledger.day))
            let reachesHour=ledger.phase == .running && cursor.addingTimeInterval(remaining)<=next
            if reachesHour { next=cursor.addingTimeInterval(remaining) }
            extend(to:next)
            if reachesHour, let index=activeIndex {
                let entryID=appendUncovered(session:index,pending:false)
                ledger.milestones.append(HourlyMilestone(day:ledger.day,hour:hour,reachedAt:next,entryID:entryID,presented:false))
            }
            if next == midnight {
                close(at:midnight,reason:.midnight)
                ledger.day=StudyDate.day(midnight)
                if ledger.phase == .running { begin(at:midnight) }
            }
            cursor=next
        }
        ledger.day=StudyDate.day(date); ledger.checkpointAt=date
    }
    @discardableResult private mutating func appendUncovered(session index:Int,pending:Bool)->UUID? {
        let session=ledger.sessions[index]
        let start=ledger.entries(for:session.id).last?.endOffset ?? 0
        guard session.seconds-start>0.000001 else { return ledger.entries(for:session.id).last?.id }
        let entry=LearningEntry(id:UUID(),sessionID:session.id,startOffset:start,endOffset:session.seconds,note:"",pendingTail:pending)
        ledger.entries.append(entry)
        return entry.id
    }
    private mutating func finishTail(session index:Int,manual:Bool) {
        let session=ledger.sessions[index]
        if !manual, let last=ledger.entries(for:session.id).last,
           let i=ledger.entries.firstIndex(where:{$0.id==last.id}) {
            ledger.entries[i].endOffset=session.seconds
        } else { appendUncovered(session:index,pending:manual) }
    }
    public mutating func editNotes(_ values:[UUID:String]) throws {
        for (id,text) in values {
            guard let index=ledger.entries.firstIndex(where:{$0.id==id}) else { throw LedgerError.invalid("这条记录已合并或不存在，请刷新后重试") }
            ledger.entries[index].note=text
        }
    }
    public mutating func resolveTail(_ id:UUID,merge:Bool) throws {
        guard let index=ledger.entries.firstIndex(where:{$0.id==id}),ledger.entries[index].pendingTail else { throw LedgerError.invalid("尾段已处理或不存在") }
        if merge {
            let entry=ledger.entries[index]
            guard ledger.canMerge(id),let previous=ledger.entries.firstIndex(where:{$0.sessionID==entry.sessionID && abs($0.endOffset-entry.startOffset)<0.001 && $0.id != id}) else { throw LedgerError.invalid("当前学习段没有可合并的上一条") }
            ledger.entries[previous].endOffset=entry.endOffset
            if !entry.note.isEmpty {
                ledger.entries[previous].note += (ledger.entries[previous].note.isEmpty ? "" : "\n") + entry.note
            }
            let target=ledger.entries[previous].id
            for i in ledger.milestones.indices where ledger.milestones[i].entryID==id { ledger.milestones[i].entryID=target }
            ledger.entries.remove(at:index)
        } else { ledger.entries[index].pendingTail=false }
    }
    public mutating func markPresented(_ ids:Set<String>) {
        for i in ledger.milestones.indices where ids.contains(ledger.milestones[i].id) { ledger.milestones[i].presented=true }
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
        if reason == .quit {
            // Pending IDs come from a validated ledger; each belongs to one closed session.
            for id in ledger.entries.filter({$0.pendingTail}).map(\.id) {
                try? resolveTail(id,merge:ledger.canMerge(id))
            }
        }
    }
    /// Recover exactly the saved snapshot. Never advance an old running interval to launch time.
    public mutating func recover(at launch: Date) {
        close(at: ledger.checkpointAt, reason: .interrupted)
        ledger.phase = .stopped
        ledger.day = StudyDate.day(launch)
        ledger.checkpointAt = launch
    }
}
