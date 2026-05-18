import Foundation

// MARK: - Safe-to-Spend Calculator

struct SafeToSpendCalculator {

    struct Result {
        var weekly: Double
        var daily: Double
        var monthly: Double
        var afterObligations: Double
        var afterGoals: Double
        var spentThisWeek: Double
        var remainingThisWeek: Double

        var weeklyFormatted: String { formatted(weekly) }
        var dailyFormatted: String  { formatted(daily) }
        var remainingFormatted: String { formatted(remainingThisWeek) }
        var monthlyFormatted: String { formatted(monthly) }

        private func formatted(_ value: Double) -> String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            let f = formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
            return "₹\(f)"
        }
    }

    static func calculate(moneyMap: MoneyMap, spentThisWeek: Double = 0) -> Result {
        let income      = moneyMap.totalMonthlyIncome
        let obligations = moneyMap.totalMonthlyObligations
        let subs        = moneyMap.totalMonthlySubscriptions
        let goals       = moneyMap.totalGoalAllocation

        let afterObl    = income - obligations - subs
        let afterGoals  = max(afterObl - goals, 0)
        let weekly      = afterGoals / 4.33
        let remaining   = max(weekly - spentThisWeek, 0)

        return Result(
            weekly: weekly,
            daily: afterGoals / 30,
            monthly: afterGoals,
            afterObligations: afterObl,
            afterGoals: afterGoals,
            spentThisWeek: spentThisWeek,
            remainingThisWeek: remaining
        )
    }

    static func impactOfPayment(amount: Double, moneyMap: MoneyMap, spentThisWeek: Double) -> PaymentImpact {
        let result = calculate(moneyMap: moneyMap, spentThisWeek: spentThisWeek)
        let after  = result.remainingThisWeek - amount
        return PaymentImpact(
            amount: amount,
            remainingAfterPayment: after,
            safeToSpendBefore: result.remainingThisWeek,
            weeklyBudget: result.weekly
        )
    }
}

// MARK: - Payment Impact

struct PaymentImpact {
    var amount: Double
    var remainingAfterPayment: Double
    var safeToSpendBefore: Double
    var weeklyBudget: Double

    var isOverBudget: Bool { remainingAfterPayment < 0 }
    var pctOfWeeklyBudget: Double { weeklyBudget > 0 ? amount / weeklyBudget : 0 }

    var riskLevel: HealthStatus {
        if remainingAfterPayment < 0 { return .risk }
        if pctOfWeeklyBudget > 0.4   { return .watch }
        return .healthy
    }

    var remainingFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let f = formatter.string(from: NSNumber(value: abs(remainingAfterPayment))) ?? "\(Int(abs(remainingAfterPayment)))"
        return "₹\(f)"
    }
}
