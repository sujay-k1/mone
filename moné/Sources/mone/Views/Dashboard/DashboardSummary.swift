import Foundation

struct DashboardSummary {
    let personaId: PersonaId
    let displayName: String
    let month: String

    let income: Double

    /// Original committed amount from MonthlySnapshot before dashboard-level decomposition.
    /// Useful while the snapshot pipeline still places tax into committed outflows.
    let grossCommitted: Double

    /// Regular commitments after separating tax/statutory deductions.
    /// This should represent rent, bills, recurring obligations, family support, etc.
    let committed: Double

    /// Tax/statutory deductions reduce liquid cash, but are not commitments, liabilities, or operating spends.
    let taxDeduction: Double

    let everyday: Double
    let fund: Double
    let liability: Double
    let outliers: Double
    let review: Double

    /// Raw snapshot remaining. Kept for compatibility, but dashboard logic should prefer
    /// operatingRemaining and liquidCashImpact below.
    let remaining: Double

    let confidence: Int
    let transactionCount: Int
    let reviewCount: Int

    let accountCount: Int
    let liquidBalance: Double

    let subscriptionAmount: Double
    let subscriptionCount: Int
    let subscriptionNames: [String]

    let totalNetWorth: Double
    let liquidNetWorth: Double
    let lockedAssets: Double

    /// Operating affordability before tax/statutory deductions and outliers.
    /// This is the correct basis for safe-to-spend.
    var operatingBeforeReview: Double {
        income - committed - everyday - fund - liability
    }

    /// Operating remaining after reserving review amount, but before tax/statutory deductions and outliers.
    var operatingRemaining: Double {
        operatingBeforeReview - review
    }

    /// Final liquid cash impact after tax/statutory deductions and outliers.
    /// This explains why bank cash may reduce even when operating affordability is separate.
    var liquidCashImpact: Double {
        operatingRemaining - taxDeduction - outliers
    }

    var safeToSpend: Double {
        max(operatingBeforeReview - reviewBuffer, 0)
    }

    var reviewBuffer: Double {
        min(review, max(income * 0.05, 0))
    }

    var dailySpendVelocity: Double {
        everyday / 30
    }

    var committedRatio: Double {
        guard income > 0 else { return 0 }
        return committed / income
    }

    var taxRatio: Double {
        guard income > 0 else { return 0 }
        return taxDeduction / income
    }

    var savingsRatio: Double {
        guard income > 0 else { return 0 }
        return fund / income
    }

    var liquidityRatio: Double {
        guard totalNetWorth > 0 else { return 0 }
        return liquidNetWorth / totalNetWorth
    }

    var clarityLabel: String {
        if confidence >= 85 { return "High" }
        if confidence >= 70 { return "Good" }
        if confidence >= 55 { return "Needs review" }
        return "Low"
    }

    var healthState: DashboardHealthState {
        if operatingRemaining < 0 || confidence < 55 {
            return .risk
        }

        if committedRatio > 0.65 || reviewCount > 3 || confidence < 75 {
            return .watch
        }

        return .healthy
    }

    var healthMessage: String {
        if liquidCashImpact < 0, taxDeduction > 0, operatingRemaining >= -(income * 0.05) {
            return "This month’s liquid cash is negative mainly because statutory deductions reduced bank balance. Your operating view is shown separately from tax."
        }

        switch healthState {
        case .healthy:
            return "Your operating architecture is stable. Inflows cover predictable outflows, everyday spends, and fund-building."
        case .watch:
            return "A few operating signals need attention. Review unclear items or rising obligations before they affect your buffer."
        case .risk:
            return "Your operating month is under pressure. Regular outflows or unclear items are weakening your available buffer."
        }
    }
}

enum DashboardHealthState: String {
    case healthy = "Healthy"
    case watch = "Watch"
    case risk = "Risk"
}
