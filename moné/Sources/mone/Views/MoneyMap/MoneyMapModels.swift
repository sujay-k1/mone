import Foundation

enum MoneyMapBucketKind: String, CaseIterable {
    case committed
    case everyday
    case fund
    case liability
    case tax
    case outliers
    case review
    case operatingRemaining
    case liquidCashImpact
    case income
    case cash
    case neutral
}

struct MoneyMapBucket: Identifiable {
    var id: String { title }
    let title: String
    let amount: Double
    let kind: MoneyMapBucketKind
}

struct MoneyMapItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let amount: Double
    let status: String
    let symbolName: String
    let kind: MoneyMapBucketKind
    var dateText: String? = nil
}

struct CategoryDailyAmount: Identifiable {
    let id: Int  // day of month (1–31)
    let day: Int
    let amount: Double
}

struct MoneyMapCategoryGroup: Identifiable {
    var id: String { title }
    let title: String
    let amount: Double
    let transactionCount: Int
    let status: String
    let kind: MoneyMapBucketKind
    /// Per-day totals for the current month (only days with transactions)
    let dailyAmounts: [CategoryDailyAmount]
    /// Per-day totals for the previous month (only days with transactions)
    let previousMonthDailyAmounts: [CategoryDailyAmount]
    /// Same category's total spend in the previous month (0 if no data)
    let previousMonthAmount: Double
}

struct MoneyMapTransaction: Identifiable, Hashable {
    let id: String
    let month: String
    let dateText: String
    let sortDateText: String
    let title: String
    let narration: String
    let amount: Double
    let type: String
    let mode: String
    let accountType: String
    let categoryFamily: String
    let category: String
    let role: String
    let confidence: Int
    let needsReview: Bool
    let reviewReason: String?
    let evidenceText: String
    let symbolName: String
    let kind: MoneyMapBucketKind

    var isCredit: Bool {
        type.uppercased() == "CREDIT"
    }

    var signedAmount: Double {
        isCredit ? amount : -amount
    }
}

struct MoneyMapTransactionMonthGroup: Identifiable {
    var id: String { month }
    let month: String
    let title: String
    let transactions: [MoneyMapTransaction]

    var totalDebits: Double {
        transactions
            .filter { !$0.isCredit }
            .map(\.amount)
            .reduce(0, +)
    }

    var totalCredits: Double {
        transactions
            .filter(\.isCredit)
            .map(\.amount)
            .reduce(0, +)
    }
}

enum MoneyMapTransactionFilter: String, CaseIterable, Identifiable {
    case all
    case review
    case income
    case committed
    case everyday
    case fund
    case liability
    case tax
    case outliers
    case cash
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .review: return "Review"
        case .income: return "Income"
        case .committed: return "Committed"
        case .everyday: return "Everyday"
        case .fund: return "Fund"
        case .liability: return "Liability"
        case .tax: return "Tax"
        case .outliers: return "Outliers"
        case .cash: return "Cash"
        case .other: return "Other"
        }
    }

    func matches(_ transaction: MoneyMapTransaction) -> Bool {
        switch self {
        case .all:
            return true
        case .review:
            return transaction.needsReview
        case .income:
            return transaction.isCredit || transaction.kind == .income
        case .committed:
            return transaction.kind == .committed
        case .everyday:
            return transaction.kind == .everyday
        case .fund:
            return transaction.kind == .fund
        case .liability:
            return transaction.kind == .liability
        case .tax:
            return transaction.kind == .tax
        case .outliers:
            return transaction.kind == .outliers
        case .cash:
            return transaction.kind == .cash
        case .other:
            return transaction.kind == .neutral
        }
    }
}

struct MoneyMapRetagOption: Identifiable, Hashable {
    let id: String
    let title: String
    let categoryFamily: String
    let category: String
    let role: String
    let kind: MoneyMapBucketKind
    let symbolName: String

    static let defaults: [MoneyMapRetagOption] = [
        MoneyMapRetagOption(
            id: "food_snacks",
            title: "Food / snacks",
            categoryFamily: MoneCategoryFamily.foodSnacks,
            category: "food_snacks",
            role: MoneRole.everydaySpend,
            kind: .everyday,
            symbolName: "fork.knife"
        ),
        MoneyMapRetagOption(
            id: "groceries",
            title: "Groceries",
            categoryFamily: MoneCategoryFamily.groceries,
            category: "groceries",
            role: MoneRole.everydaySpend,
            kind: .everyday,
            symbolName: "basket"
        ),
        MoneyMapRetagOption(
            id: "transport",
            title: "Transport",
            categoryFamily: MoneCategoryFamily.transport,
            category: "transport",
            role: MoneRole.everydaySpend,
            kind: .everyday,
            symbolName: "car"
        ),
        MoneyMapRetagOption(
            id: "shopping",
            title: "Shopping",
            categoryFamily: MoneCategoryFamily.shopping,
            category: "shopping",
            role: MoneRole.everydaySpend,
            kind: .everyday,
            symbolName: "bag"
        ),
        MoneyMapRetagOption(
            id: "medical",
            title: "Medical",
            categoryFamily: MoneCategoryFamily.medical,
            category: "medical",
            role: MoneRole.everydaySpend,
            kind: .everyday,
            symbolName: "cross.case"
        ),
        MoneyMapRetagOption(
            id: "travel",
            title: "Travel",
            categoryFamily: MoneCategoryFamily.travel,
            category: "travel",
            role: MoneRole.everydaySpend,
            kind: .everyday,
            symbolName: "airplane"
        ),
        MoneyMapRetagOption(
            id: "subscriptions",
            title: "Subscription",
            categoryFamily: MoneCategoryFamily.subscriptions,
            category: "subscription",
            role: MoneRole.committedOutflow,
            kind: .committed,
            symbolName: "repeat"
        ),
        MoneyMapRetagOption(
            id: "housing",
            title: "Housing / rent",
            categoryFamily: MoneCategoryFamily.housing,
            category: "housing",
            role: MoneRole.committedOutflow,
            kind: .committed,
            symbolName: "house"
        ),
        MoneyMapRetagOption(
            id: "utilities",
            title: "Utilities",
            categoryFamily: MoneCategoryFamily.utilities,
            category: "utilities",
            role: MoneRole.committedOutflow,
            kind: .committed,
            symbolName: "bolt"
        ),
        MoneyMapRetagOption(
            id: "family_support",
            title: "Family support",
            categoryFamily: MoneCategoryFamily.familySupport,
            category: "family_support",
            role: MoneRole.committedOutflow,
            kind: .committed,
            symbolName: "person.2"
        ),
        MoneyMapRetagOption(
            id: "investments",
            title: "Investment / saving",
            categoryFamily: MoneCategoryFamily.investments,
            category: "investment",
            role: MoneRole.fundBuilding,
            kind: .fund,
            symbolName: "chart.line.uptrend.xyaxis"
        ),
        MoneyMapRetagOption(
            id: "debt",
            title: "Debt / EMI",
            categoryFamily: MoneCategoryFamily.debt,
            category: "debt_payment",
            role: MoneRole.liabilityPayment,
            kind: .liability,
            symbolName: "creditcard"
        ),
        MoneyMapRetagOption(
            id: "tax",
            title: "Tax / statutory",
            categoryFamily: MoneCategoryFamily.tax,
            category: "tax_payment",
            role: "tax_payment",
            kind: .tax,
            symbolName: "doc.text"
        ),
        MoneyMapRetagOption(
            id: "cash",
            title: "Cash withdrawal",
            categoryFamily: MoneCategoryFamily.cash,
            category: "cash_withdrawal",
            role: MoneRole.cashWithdrawal,
            kind: .cash,
            symbolName: "indianrupeesign.circle"
        ),
        MoneyMapRetagOption(
            id: "other",
            title: "Other",
            categoryFamily: MoneCategoryFamily.other,
            category: "other",
            role: MoneRole.everydaySpend,
            kind: .neutral,
            symbolName: "circle.grid.2x2"
        )
    ]
}

struct WaterfallRow: Identifiable {
    let id = UUID()
    let label: String
    let amount: Double
    let kind: MoneyMapBucketKind
}

struct MoneyMapScreenModel {
    let personaId: PersonaId
    let displayName: String
    let month: String

    let income: Double
    let confidence: Int
    let transactionCount: Int
    let reviewCount: Int

    let regularCommitted: Double
    let everyday: Double
    let fund: Double
    let liability: Double
    let taxDeduction: Double
    let outliers: Double
    let review: Double

    let operatingRemaining: Double
    let liquidCashImpact: Double
    let outstandingLiabilities: Double

    let committedItems: [MoneyMapItem]
    let subscriptionItems: [MoneyMapItem]   // separated for logo-stack UI
    let everydayGroups: [MoneyMapCategoryGroup]
    let outlierItems: [MoneyMapItem]
    let fundItems: [MoneyMapItem]
    let liabilityItems: [MoneyMapItem]
    let reviewItems: [MoneyMapItem]
    let transactions: [MoneyMapTransaction]

    var subscriptions: Double {
        subscriptionItems.map(\.amount).reduce(0, +)
    }

    /// Waterfall rows for the inflow recon chart, in display order.
    var waterfallRows: [WaterfallRow] {
        var rows: [WaterfallRow] = []

        if regularCommitted > 0 {
            rows.append(WaterfallRow(label: "Committed", amount: regularCommitted, kind: .committed))
        }
        if subscriptions > 0 {
            rows.append(WaterfallRow(label: "Subscriptions", amount: subscriptions, kind: .committed))
        }
        if everyday > 0 {
            rows.append(WaterfallRow(label: "Everyday", amount: everyday, kind: .everyday))
        }
        if fund > 0 {
            rows.append(WaterfallRow(label: "Investments", amount: fund, kind: .fund))
        }
        if liability > 0 {
            rows.append(WaterfallRow(label: "Liabilities", amount: liability, kind: .liability))
        }
        if taxDeduction > 0 {
            rows.append(WaterfallRow(label: "Tax", amount: taxDeduction, kind: .tax))
        }
        // Outliers: up to 3 individual items labelled by category, then a "+ N more" roll-up
        let topOutliers = outlierItems.prefix(3)
        for item in topOutliers {
            rows.append(WaterfallRow(label: item.title, amount: item.amount, kind: .outliers))
        }
        if outlierItems.count > 3 {
            let rest = outlierItems.dropFirst(3).map(\.amount).reduce(0, +)
            rows.append(WaterfallRow(label: "+ \(outlierItems.count - 3) more", amount: rest, kind: .outliers))
        }
        if review > 0 {
            rows.append(WaterfallRow(label: "Needs review", amount: review, kind: .review))
        }

        rows.append(WaterfallRow(
            label: operatingRemaining >= 0 ? "Remaining" : "Shortfall",
            amount: operatingRemaining,
            kind: operatingRemaining >= 0 ? .operatingRemaining : .outliers
        ))

        return rows
    }

    var buckets: [MoneyMapBucket] {
        [
            MoneyMapBucket(title: "Committed", amount: regularCommitted, kind: .committed),
            MoneyMapBucket(title: "Everyday", amount: everyday, kind: .everyday),
            MoneyMapBucket(title: "Fund", amount: fund, kind: .fund),
            MoneyMapBucket(title: "Liability", amount: liability, kind: .liability),
            MoneyMapBucket(title: "Tax", amount: taxDeduction, kind: .tax),
            MoneyMapBucket(title: "Outliers", amount: outliers, kind: .outliers),
            MoneyMapBucket(title: "Review", amount: review, kind: .review),
            MoneyMapBucket(title: "Operating", amount: max(operatingRemaining, 0), kind: .operatingRemaining)
        ]
    }

    var positiveMapTotal: Double {
        max(
            regularCommitted + everyday + fund + liability + taxDeduction + outliers + review + max(operatingRemaining, 0),
            1
        )
    }

    var confidenceLabel: String {
        if confidence >= 85 { return "High confidence" }
        if confidence >= 70 { return "Good confidence" }
        if confidence >= 55 { return "Needs review" }
        return "Low confidence"
    }

    var statusLabel: String {
        if operatingRemaining < 0 { return "Operating shortfall" }
        if liquidCashImpact < 0 { return "Cash impact" }
        if reviewCount > 0 { return "Needs review" }
        return "Stable"
    }
}
