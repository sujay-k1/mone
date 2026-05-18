import Foundation

// MARK: - Nudge Engine

struct NudgeEngine {

    static func evaluate(
        merchant: String,
        amount: Double,
        category: TransactionCategory,
        moneyMap: MoneyMap,
        spentThisWeek: Double,
        goals: [Goal],
        intensity: NudgeIntensity
    ) -> Nudge? {
        let impact = SafeToSpendCalculator.impactOfPayment(
            amount: amount,
            moneyMap: moneyMap,
            spentThisWeek: spentThisWeek
        )

        // Determine nudge threshold based on intensity
        let shouldNudge: Bool
        switch intensity {
        case .gentle:   shouldNudge = impact.riskLevel == .risk
        case .balanced: shouldNudge = impact.riskLevel != .healthy
        case .strict:   shouldNudge = impact.pctOfWeeklyBudget > 0.15 || impact.riskLevel != .healthy
        }

        guard shouldNudge else { return nil }

        let (message, impactText, actions) = buildNudge(impact: impact, goals: goals, merchant: merchant)

        return Nudge(
            merchant: merchant,
            amount: amount,
            message: message,
            impact: impactText,
            intensity: intensity,
            actions: actions
        )
    }

    private static func buildNudge(
        impact: PaymentImpact,
        goals: [Goal],
        merchant: String
    ) -> (String, String, [NudgeAction]) {
        switch impact.riskLevel {
        case .healthy:
            return (
                "This looks okay.",
                "Leaves \(impact.remainingFormatted) for the rest of the week.",
                [.continueToUPI, .payLater]
            )
        case .watch:
            return (
                "This is okay, but it's \(Int(impact.pctOfWeeklyBudget * 100))% of your weekly budget.",
                "Leaves \(impact.remainingFormatted) for the week after this.",
                [.continueToUPI, .reduceAmount, .payLater, .overrideAnyway]
            )
        case .risk:
            let goalNote = goalImpactText(amount: impact.amount, goals: goals)
            return (
                "This pushes your spending into risk territory.",
                goalNote ?? "You'd be \(impact.remainingFormatted) over your weekly budget.",
                [.stillPay, .payLater, .adjustBudget, .viewImpact]
            )
        }
    }

    private static func goalImpactText(amount: Double, goals: [Goal]) -> String? {
        guard let goal = goals.filter({ $0.priority == .mustProtect || $0.priority == .important }).first,
              let delay = GoalProjectionCalculator.impactOnGoal(goal: goal, extraSpend: amount),
              delay > 0 else { return nil }
        return "This may delay your \(goal.name) by \(delay) day\(delay == 1 ? "" : "s")."
    }
}
