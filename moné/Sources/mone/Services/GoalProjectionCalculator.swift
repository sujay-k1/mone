import Foundation

// MARK: - Goal Projection Calculator

struct GoalProjectionCalculator {

    static func status(for goal: Goal) -> GoalStatus {
        guard goal.progressFraction < 1.0 else { return .completed }
        guard goal.deadline != nil else { return .noDeadline }

        let delay = daysDelay(goal: goal) ?? 0
        if delay <= 0 { return .onTrack }
        return .atRisk(daysDelay: delay)
    }

    static func daysDelay(goal: Goal) -> Int? {
        guard let deadline = goal.deadline,
              let projected = projectedCompletion(goal: goal) else { return nil }
        let diff = Calendar.current.dateComponents([.day], from: deadline, to: projected)
        return max(diff.day ?? 0, 0)
    }

    static func projectedCompletion(goal: Goal) -> Date? {
        guard let allocation = goal.requiredMonthlyAllocation, allocation > 0 else { return nil }
        let monthsNeeded = goal.remainingAmount / allocation
        return Calendar.current.date(byAdding: .day, value: Int(monthsNeeded * 30), to: Date())
    }

    /// Returns days of delay caused by a one-time extra spend
    static func impactOnGoal(goal: Goal, extraSpend: Double) -> Int? {
        guard let allocation = goal.requiredMonthlyAllocation, allocation > 0 else { return nil }
        let monthsDelay = extraSpend / allocation
        return max(Int(monthsDelay * 30), 0)
    }
}
