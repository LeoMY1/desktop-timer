import Foundation

public struct LearningEntry: Codable, Identifiable, Equatable {
    public let id: UUID
    public let sessionID: UUID
    public var startOffset: Double
    public var endOffset: Double
    public var note: String
    public var pendingTail: Bool
    public var seconds: Double { endOffset-startOffset }
}
public struct HourlyMilestone: Codable, Identifiable, Equatable {
    public let day: String
    public let hour: Int
    public let reachedAt: Date
    public var entryID: UUID?
    public var presented: Bool
    public var id: String { "\(day)/\(hour)" }
}

extension Ledger {
    public func entries(for sessionID: UUID) -> [LearningEntry] {
        entries.filter { $0.sessionID == sessionID }.sorted { $0.startOffset < $1.startOffset }
    }
    public func canMerge(_ entryID: UUID) -> Bool {
        guard let entry=entries.first(where:{$0.id==entryID}), entry.pendingTail else { return false }
        return entries(for:entry.sessionID).contains { $0.id != entryID && abs($0.endOffset-entry.startOffset)<0.001 }
    }
    public func validateRecords() throws {
        guard Set(entries.map(\.id)).count==entries.count, Set(milestones.map(\.id)).count==milestones.count else {
            throw LedgerError.invalid("备注或整小时记录重复")
        }
        for session in sessions {
            var offset:Double=0
            let items=entries(for:session.id)
            for (index,entry) in items.enumerated() {
                guard entry.startOffset.isFinite,entry.endOffset.isFinite,abs(entry.startOffset-offset)<0.001,
                      entry.endOffset>entry.startOffset,entry.endOffset<=session.seconds+0.001,
                      !entry.pendingTail || (session.endedAt != nil && index==items.count-1) else {
                    throw LedgerError.invalid("内容记录时长重叠、越界或尾段状态错误")
                }
                offset=entry.endOffset
            }
            if session.endedAt != nil && schemaVersion==2 && abs(offset-session.seconds)>0.001 {
                throw LedgerError.invalid("结束学习段的内容记录不完整")
            }
        }
        guard entries.allSatisfy({ entry in sessions.contains{$0.id==entry.sessionID} }) else { throw LedgerError.invalid("备注所属学习段不存在") }
        for item in milestones {
            guard item.hour>0,item.reachedAt.timeIntervalSince1970.isFinite,
                  Double(item.hour)*3600<=total(on:item.day)+0.001,
                  item.entryID == nil || entries.contains(where:{ entry in entry.id==item.entryID && sessions.first(where:{$0.id==entry.sessionID})?.day==item.day }) else {
                throw LedgerError.invalid("整小时记录引用或阈值错误")
            }
        }
    }
}
