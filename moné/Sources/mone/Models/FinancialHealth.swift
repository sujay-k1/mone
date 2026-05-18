import Foundation

// MARK: - Financial Health Report

struct FinancialHealthReport {
    var cashflowStability: HealthSignal
    var obligationLoad: HealthSignal
    var safeToSpend: HealthSignal
    var goalProgress: HealthSignal
    var emergencyReadiness: HealthSignal
    var debtPressure: HealthSignal
    var subscriptionLeakage: HealthSignal
    var spendingDrift: HealthSignal
    var upcomingRisk: HealthSignal
    var creditCardDiscipline: HealthSignal

    var allSignals: [HealthSignal] {
        [cashflowStability, obligationLoad, safeToSpend, goalProgress,
         emergencyReadiness, debtPressure, subscriptionLeakage,
         spendingDrift, upcomingRisk, creditCardDiscipline]
    }

    var overallStatus: HealthStatus {
        let statuses = allSignals.map { $0.status }
        if statuses.contains(.risk) { return .risk }
        if statuses.contains(.watch) { return .watch }
        return .healthy
    }

    var overallLabel: String {
        switch overallStatus {
        case .healthy: return "Looking healthy"
        case .watch: return "Worth keeping an eye on"
        case .risk: return "Needs attention"
        }
    }

    var overallSummary: String {
        switch overallStatus {
        case .healthy: return "Your finances are stable and goals are on track."
        case .watch: return "A few areas to keep an eye on this month."
        case .risk: return "Some areas need attention to stay on track."
        }
    }
}

// MARK: - Health Signal

struct HealthSignal: Identifiable {
    let id: UUID = UUID()
    var dimension: HealthDimension
    var status: HealthStatus
    var label: String
    var detail: String
    var value: String?
}

// MARK: - Health Dimension

enum HealthDimension: String, CaseIterable {
    case cashflowStability = "Cashflow Stability"
    case obligationLoad = "Obligation Load"
    case safeToSpend = "Safe-to-Spend"
    case goalProgress = "Goal Progress"
    case emergencyReadiness = "Emergency Readiness"
    case debtPressure = "Debt Pressure"
    case subscriptionLeakage = "Subscription Leakage"
    case spendingDrift = "Spending Drift"
    case upcomingRisk = "Upcoming Risk"
    case creditCardDiscipline = "Credit Card Discipline"

    var icon: String {
        switch self {
        case .cashflowStability: return "waveform.path"
        case .obligationLoad: return "gauge.with.needle"
        case .safeToSpend: return "banknote"
        case .goalProgress: return "flag"
        case .emergencyReadiness: return "shield"
        case .debtPressure: return "creditcard"
        case .subscriptionLeakage: return "repeat"
        case .spendingDrift: return "arrow.up.right"
        case .upcomingRisk: return "calendar.badge.exclamationmark"
        case .creditCardDiscipline: return "checkmark.seal"
        }
    }
}

// MARK: - Health Status

enum HealthStatus: String {
    case healthy = "Healthy"
    case watch = "Watch"
    case risk = "Risk"
}

// MARK: - Nudge

struct Nudge: Identifiable {
    let id: UUID = UUID()
    var merchant: String
    var amount: Double
    var message: String
    var impact: String
    var intensity: NudgeIntensity
    var actions: [NudgeAction]

    var amountFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let formatted = formatter.string(from: NSNumber(value: amount)) ?? "\(Int(amount))"
        return "₹\(formatted)"
    }
}

// MARK: - Nudge Action

enum NudgeAction: String, CaseIterable {
    case continueToUPI = "Continue to UPI"
    case reduceAmount = "Reduce amount"
    case payLater = "Pay later"
    case overrideAnyway = "Override anyway"
    case stillPay = "Still pay"
    case adjustBudget = "Adjust budget"
    case viewImpact = "View impact"
}

// MARK: - Insight Card

struct InsightCardData: Identifiable {
    let id = UUID()
    var title: String
    var detail: String
    var actionLabel: String
    var type: InsightType

    enum InsightType {
        case healthy, watch, risk, info
    }
}
