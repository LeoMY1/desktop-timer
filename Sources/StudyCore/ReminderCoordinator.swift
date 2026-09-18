import Foundation

/// Selection only: the UI keeps its active batch stable while the user edits.
public enum ReminderCoordinator {
    public static func pending(in ledger:Ledger)->[HourlyMilestone] {
        ledger.milestones.filter{ !$0.presented }.sorted {
            if $0.reachedAt == $1.reachedAt { return $0.hour < $1.hour }
            return $0.reachedAt < $1.reachedAt
        }
    }
}
