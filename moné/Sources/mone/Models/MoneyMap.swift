import Foundation

// MARK: - Money Map

struct MoneyMap: Codable {
    var income: [IncomeSource] = []
    var obligations: [Obligation] = []
    var subscriptions: [SubscriptionItem] = []
    var goals: [Goal] = []
    var upcomingItems: [UpcomingItem] = []
    var lastUpdated: Date = Date()

    // MARK: Computed

    var totalMonthlyIncome: Double {
        income.filter { $0.frequency == .monthly || $0.type == .stable }
            .reduce(0) { $0 + $1.amount }
    }

    var totalMonthlyObligations: Double {
        obligations.filter { $0.isMonthly }.reduce(0) { $0 + $1.amount }
    }

    var totalMonthlySubscriptions: Double {
        subscriptions.reduce(0) { $0 + $1.monthlyAmount }
    }

    var totalGoalAllocation: Double {
        goals.compactMap { $0.requiredMonthlyAllocation }.reduce(0, +)
    }

    var obligationLoad: Double {
        guard totalMonthlyIncome > 0 else { return 0 }
        return (totalMonthlyObligations + totalMonthlySubscriptions) / totalMonthlyIncome
    }

    var safeToSpendMonthly: Double {
        let after = totalMonthlyIncome - totalMonthlyObligations - totalMonthlySubscriptions - totalGoalAllocation
        return max(after, 0)
    }
}

// MARK: - Income Source

struct IncomeSource: Identifiable, Codable {
    let id: UUID
    var name: String
    var amount: Double
    var frequency: IncomeFrequency
    var type: IncomeType
    var typicalDay: Int?

    init(
        id: UUID = UUID(),
        name: String,
        amount: Double,
        frequency: IncomeFrequency,
        type: IncomeType,
        typicalDay: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.frequency = frequency
        self.type = type
        self.typicalDay = typicalDay
    }
}

enum IncomeFrequency: String, Codable {
    case monthly, quarterly, annual, irregular, oneTime
}

enum IncomeType: String, Codable {
    case stable, variable, oneTimeInflow, internalTransfer, reimbursement

    var label: String {
        switch self {
        case .stable: return "Stable"
        case .variable: return "Variable"
        case .oneTimeInflow: return "One-time"
        case .internalTransfer: return "Transfer"
        case .reimbursement: return "Reimbursement"
        }
    }
}

// MARK: - Obligation

struct Obligation: Identifiable, Codable {
    let id: UUID
    var name: String
    var amount: Double
    var category: ObligationCategory
    var dueDay: Int?
    var isMonthly: Bool
    var isConfirmed: Bool

    init(
        id: UUID = UUID(),
        name: String,
        amount: Double,
        category: ObligationCategory,
        dueDay: Int? = nil,
        isMonthly: Bool = true,
        isConfirmed: Bool = false
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.category = category
        self.dueDay = dueDay
        self.isMonthly = isMonthly
        self.isConfirmed = isConfirmed
    }
}

enum ObligationCategory: String, Codable, CaseIterable {
    case housing = "Housing"
    case debt = "Debt & EMI"
    case investments = "Investments"
    case insurance = "Insurance"
    case utilities = "Utilities"
    case subscriptions = "Subscriptions"
    case family = "Family"
    case lifestyle = "Lifestyle"
    case annual = "Annual"

    var icon: String {
        switch self {
        case .housing: return "house"
        case .debt: return "creditcard"
        case .investments: return "chart.line.uptrend.xyaxis"
        case .insurance: return "shield"
        case .utilities: return "bolt"
        case .subscriptions: return "repeat"
        case .family: return "person.2"
        case .lifestyle: return "star"
        case .annual: return "calendar"
        }
    }
}

// MARK: - Subscription

struct SubscriptionItem: Identifiable, Codable {
    let id: UUID
    var name: String
    var monthlyAmount: Double
    var billingDay: Int?
    var isConfirmed: Bool

    init(
        id: UUID = UUID(),
        name: String,
        monthlyAmount: Double,
        billingDay: Int? = nil,
        isConfirmed: Bool = false
    ) {
        self.id = id
        self.name = name
        self.monthlyAmount = monthlyAmount
        self.billingDay = billingDay
        self.isConfirmed = isConfirmed
    }
}

// MARK: - Upcoming Item

struct UpcomingItem: Identifiable, Codable {
    let id: UUID
    var name: String
    var amount: Double
    var dueDate: Date
    var type: UpcomingItemType

    init(
        id: UUID = UUID(),
        name: String,
        amount: Double,
        dueDate: Date,
        type: UpcomingItemType
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.dueDate = dueDate
        self.type = type
    }

    var daysUntilDue: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
    }
}

enum UpcomingItemType: String, Codable {
    case creditCard = "Credit Card"
    case bill = "Bill"
    case emi = "EMI"
    case subscription = "Subscription"
    case custom = "Custom"

    var icon: String {
        switch self {
        case .creditCard: return "creditcard"
        case .bill: return "doc.text"
        case .emi: return "building.columns"
        case .subscription: return "repeat"
        case .custom: return "calendar"
        }
    }
}
