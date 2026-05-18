import Foundation

// MARK: - Financial Health Calculator

struct FinancialHealthCalculator {

    static func calculate(
        moneyMap: MoneyMap,
        spentThisMonth: Double = 0,
        spentLastMonth: Double = 0,
        savingsBalance: Double = 240000 // mock emergency buffer
    ) -> FinancialHealthReport {
        let income       = moneyMap.totalMonthlyIncome
        let safeToSpend  = SafeToSpendCalculator.calculate(moneyMap: moneyMap)
        let obligPct     = moneyMap.obligationLoad
        let subsPct      = income > 0 ? moneyMap.totalMonthlySubscriptions / income : 0
        let driftPct     = spentLastMonth > 0 ? (spentThisMonth - spentLastMonth) / spentLastMonth : 0
        let essMo        = moneyMap.totalMonthlyObligations
        let emergMonths  = essMo > 0 ? savingsBalance / essMo : 0

        return FinancialHealthReport(
            cashflowStability:    cashflow(income: moneyMap.income),
            obligationLoad:       obligLoad(pct: obligPct),
            safeToSpend:          safeToSpendSignal(amount: safeToSpend.monthly, income: income),
            goalProgress:         goalSignal(goals: moneyMap.goals),
            emergencyReadiness:   emergency(months: emergMonths),
            debtPressure:         debt(obligations: moneyMap.obligations),
            subscriptionLeakage:  subscriptions(pct: subsPct, total: moneyMap.totalMonthlySubscriptions),
            spendingDrift:        drift(pct: driftPct),
            upcomingRisk:         upcoming(items: moneyMap.upcomingItems),
            creditCardDiscipline: creditCard(obligations: moneyMap.obligations)
        )
    }

    // MARK: - Signal Builders

    private static func cashflow(income: [IncomeSource]) -> HealthSignal {
        let stable = income.filter { $0.type == .stable }.reduce(0) { $0 + $1.amount }
        let total  = income.reduce(0) { $0 + $1.amount }
        let ratio  = total > 0 ? stable / total : 0
        let status: HealthStatus = ratio > 0.7 ? .healthy : ratio > 0.4 ? .watch : .risk
        return HealthSignal(dimension: .cashflowStability, status: status,
                            label: status.rawValue,
                            detail: "₹\(formatted(stable)) stable income per month",
                            value: "\(Int(ratio * 100))%")
    }

    private static func obligLoad(pct: Double) -> HealthSignal {
        let status: HealthStatus = pct < 0.4 ? .healthy : pct < 0.6 ? .watch : .risk
        return HealthSignal(dimension: .obligationLoad, status: status,
                            label: status.rawValue,
                            detail: "\(Int(pct * 100))% of your income is already committed.",
                            value: "\(Int(pct * 100))%")
    }

    private static func safeToSpendSignal(amount: Double, income: Double) -> HealthSignal {
        let pct    = income > 0 ? amount / income : 0
        let status: HealthStatus = pct > 0.3 ? .healthy : pct > 0.15 ? .watch : .risk
        return HealthSignal(dimension: .safeToSpend, status: status,
                            label: status.rawValue,
                            detail: "₹\(formatted(amount)) available after all commitments",
                            value: "₹\(formatted(amount))")
    }

    private static func goalSignal(goals: [Goal]) -> HealthSignal {
        guard !goals.isEmpty else {
            return HealthSignal(dimension: .goalProgress, status: .healthy,
                                label: "No goals set", detail: "Add goals to start tracking")
        }
        let atRisk  = goals.filter { GoalProjectionCalculator.status(for: $0).isAtRisk }.count
        let onTrack = goals.count - atRisk
        let status: HealthStatus = atRisk == 0 ? .healthy : atRisk == 1 ? .watch : .risk
        return HealthSignal(dimension: .goalProgress, status: status,
                            label: status.rawValue,
                            detail: "\(onTrack) of \(goals.count) goals on track",
                            value: "\(onTrack)/\(goals.count)")
    }

    private static func emergency(months: Double) -> HealthSignal {
        let status: HealthStatus = months >= 3 ? .healthy : months >= 1.5 ? .watch : .risk
        return HealthSignal(dimension: .emergencyReadiness, status: status,
                            label: status.rawValue,
                            detail: String(format: "%.1f months of essentials covered", months),
                            value: String(format: "%.1f mo", months))
    }

    private static func debt(obligations: [Obligation]) -> HealthSignal {
        let total  = obligations.filter { $0.category == .debt }.reduce(0) { $0 + $1.amount }
        let status: HealthStatus = total == 0 ? .healthy : total < 20000 ? .watch : .risk
        return HealthSignal(dimension: .debtPressure, status: status,
                            label: status.rawValue,
                            detail: total > 0 ? "₹\(formatted(total)) in monthly debt payments" : "No active debt",
                            value: total > 0 ? "₹\(formatted(total))" : nil)
    }

    private static func subscriptions(pct: Double, total: Double) -> HealthSignal {
        let status: HealthStatus = pct < 0.05 ? .healthy : pct < 0.1 ? .watch : .risk
        return HealthSignal(dimension: .subscriptionLeakage, status: status,
                            label: status.rawValue,
                            detail: "₹\(formatted(total))/month across all subscriptions",
                            value: "\(Int(pct * 100))%")
    }

    private static func drift(pct: Double) -> HealthSignal {
        let absPct = abs(pct)
        let status: HealthStatus = absPct < 0.1 ? .healthy : absPct < 0.3 ? .watch : .risk
        let dir    = pct > 0 ? "higher" : "lower"
        return HealthSignal(dimension: .spendingDrift, status: status,
                            label: status.rawValue,
                            detail: "\(Int(absPct * 100))% \(dir) than last month",
                            value: "\(Int(absPct * 100))%")
    }

    private static func upcoming(items: [UpcomingItem]) -> HealthSignal {
        let soon    = items.filter { $0.daysUntilDue <= 7 }
        let total   = soon.reduce(0) { $0 + $1.amount }
        let status: HealthStatus = soon.isEmpty ? .healthy : soon.count <= 2 ? .watch : .risk
        return HealthSignal(dimension: .upcomingRisk, status: status,
                            label: status.rawValue,
                            detail: soon.isEmpty ? "No payments due this week" :
                                "\(soon.count) payment\(soon.count > 1 ? "s" : "") due, ₹\(formatted(total)) total",
                            value: soon.isEmpty ? nil : "₹\(formatted(total))")
    }

    private static func creditCard(obligations: [Obligation]) -> HealthSignal {
        let cc     = obligations.filter { $0.category == .debt && $0.name.lowercased().contains("credit") }
        guard !cc.isEmpty else {
            return HealthSignal(dimension: .creditCardDiscipline, status: .healthy,
                                label: "Healthy", detail: "No credit card dues tracked")
        }
        let total = cc.reduce(0) { $0 + $1.amount }
        return HealthSignal(dimension: .creditCardDiscipline, status: .watch,
                            label: "Watch",
                            detail: "₹\(formatted(total)) due. Full payment avoids interest.",
                            value: "₹\(formatted(total))")
    }

    private static func formatted(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }
}
