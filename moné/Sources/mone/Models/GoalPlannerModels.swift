import Foundation

// MARK: - Goal Planner Domain

/// Goal Planner uses a separate MVP model instead of overloading the existing
/// `Goal` model. The existing model is still used by Money Map and dashboard
/// projections. These planner goals are the user-created plans from the Goals tab.
struct PlannerGoal: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var kind: PlannerGoalKind
    var title: String
    var planMode: PlannerPlanMode
    var status: PlannerGoalStatus = .notStarted
    var createdAt: Date = Date()
    var nextAction: String
    var milestones: [PlannerMilestone]
    var savings: PlannerSavingsDetails?
    var spending: PlannerSpendingDetails?
    var fundingComponents: [PlannerFundingComponent]? = nil

    var progressFraction: Double {
        switch kind {
        case .buildSavings:
            guard let savings, savings.targetAmount > 0 else { return 0 }
            return min(savings.currentAmount / savings.targetAmount, 1)
        case .controlSpending:
            guard let spending, spending.targetMonthlySpend > 0 else { return 0 }
            return min(spending.currentSpend / spending.targetMonthlySpend, 1)
        }
    }

    var amountLine: String {
        switch kind {
        case .buildSavings:
            guard let savings else { return "" }
            return "\(savings.currentAmount.plannerCurrency) of \(savings.targetAmount.plannerCurrency) saved"
        case .controlSpending:
            guard let spending else { return "" }
            return "\(spending.currentSpend.plannerCurrency) of \(spending.targetMonthlySpend.plannerCurrency) used"
        }
    }

    var planLine: String {
        switch kind {
        case .buildSavings:
            guard let savings else { return planMode.title }
            return "\(planMode.title) · \(savings.monthlyContribution.plannerCurrency)/mo"
        case .controlSpending:
            guard let spending else { return planMode.title }
            return "\(planMode.title) · save around \(spending.expectedMonthlySaving.plannerCurrency)/mo"
        }
    }
}

enum PlannerGoalKind: String, Codable, CaseIterable, Identifiable {
    case buildSavings
    case controlSpending

    var id: String { rawValue }

    var title: String {
        switch self {
        case .buildSavings: return "Build savings"
        case .controlSpending: return "Control spending"
        }
    }

    var subtitle: String {
        switch self {
        case .buildSavings:
            return "Create a realistic path for a future expense or safety buffer."
        case .controlSpending:
            return "Reduce leakage in one part of your lifestyle without cutting everything."
        }
    }

    var icon: String {
        switch self {
        case .buildSavings: return "banknote"
        case .controlSpending: return "slider.horizontal.3"
        }
    }
}

enum PlannerPlanMode: String, Codable, CaseIterable, Identifiable {
    case comfortable
    case optimalBalance
    case aggressive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .comfortable: return "Comfortable"
        case .optimalBalance: return "Optimal balance"
        case .aggressive: return "Aggressive"
        }
    }

    var shortLabel: String {
        switch self {
        case .comfortable: return "LOW PRESSURE"
        case .optimalBalance: return "RECOMMENDED"
        case .aggressive: return "STRICT"
        }
    }

    var icon: String {
        switch self {
        case .comfortable: return "leaf"
        case .optimalBalance: return "scale.3d"
        case .aggressive: return "bolt"
        }
    }
}

enum PlannerGoalStatus: String, Codable, Equatable {
    case notStarted
    case onTrack
    case watch
    case needsAttention
    case completed

    var label: String {
        switch self {
        case .notStarted: return "Not started"
        case .onTrack: return "On track"
        case .watch: return "Watch"
        case .needsAttention: return "Needs attention"
        case .completed: return "Completed"
        }
    }
}

enum PlannerSavingsPurpose: String, Codable, CaseIterable, Identifiable {
    case emergencyFund
    case home
    case travel
    case vehicle
    case education
    case medicalReserve
    case largePurchase
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .emergencyFund: return "Emergency fund"
        case .home: return "Home"
        case .travel: return "Travel"
        case .vehicle: return "Vehicle"
        case .education: return "Education"
        case .medicalReserve: return "Medical reserve"
        case .largePurchase: return "Large purchase"
        case .custom: return "Custom"
        }
    }

    var detail: String {
        switch self {
        case .emergencyFund:
            return "Build a safety buffer for unexpected expenses, job changes, or medical needs."
        case .home:
            return "Prepare for a deposit, down payment, or major home expense."
        case .travel:
            return "Save for a trip without disrupting everyday cashflow."
        case .vehicle:
            return "Plan for a vehicle purchase, down payment, or upgrade."
        case .education:
            return "Fund courses, certifications, coaching, or learning expenses."
        case .medicalReserve:
            return "Keep money ready for health-related uncertainty."
        case .largePurchase:
            return "Plan for something expensive without using emergency cash."
        case .custom:
            return "Create your own savings goal."
        }
    }

    var icon: String {
        switch self {
        case .emergencyFund: return "shield.checkered"
        case .home: return "house"
        case .travel: return "airplane"
        case .vehicle: return "car"
        case .education: return "book.closed"
        case .medicalReserve: return "cross.case"
        case .largePurchase: return "bag"
        case .custom: return "flag"
        }
    }
}

enum PlannerSpendingFocus: String, Codable, CaseIterable, Identifiable {
    case foodDelivery
    case shopping
    case subscriptions
    case upiSmallSpends
    case entertainment
    case travel
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .foodDelivery: return "Food delivery"
        case .shopping: return "Shopping"
        case .subscriptions: return "Subscriptions"
        case .upiSmallSpends: return "UPI small spends"
        case .entertainment: return "Entertainment"
        case .travel: return "Travel"
        case .custom: return "Custom"
        }
    }

    var detail: String {
        switch self {
        case .foodDelivery: return "Orders, eating out, coffee, and repeat food spends."
        case .shopping: return "Fashion, gadgets, marketplaces, and impulse buys."
        case .subscriptions: return "Recurring services and memberships."
        case .upiSmallSpends: return "Small payments that feel harmless but add up."
        case .entertainment: return "Movies, events, games, and weekend spends."
        case .travel: return "Cabs, fuel, commute, and local travel leakage."
        case .custom: return "Create your own spending control area."
        }
    }

    var icon: String {
        switch self {
        case .foodDelivery: return "fork.knife"
        case .shopping: return "bag"
        case .subscriptions: return "repeat"
        case .upiSmallSpends: return "indianrupeesign.circle"
        case .entertainment: return "play.circle"
        case .travel: return "location"
        case .custom: return "flag"
        }
    }

    var mappedCategory: TransactionCategory? {
        switch self {
        case .foodDelivery: return .food
        case .shopping: return .shopping
        case .subscriptions: return .subscriptions
        case .entertainment: return .entertainment
        case .travel: return .transport
        case .upiSmallSpends, .custom: return nil
        }
    }

    var fallbackBaseline: Double {
        switch self {
        case .foodDelivery: return 12_400
        case .shopping: return 9_800
        case .subscriptions: return 3_200
        case .upiSmallSpends: return 7_600
        case .entertainment: return 5_400
        case .travel: return 6_800
        case .custom: return 5_000
        }
    }
}

struct PlannerSavingsDetails: Codable, Equatable {
    var purpose: PlannerSavingsPurpose
    var targetAmount: Double
    var currentAmount: Double
    var desiredDeadline: Date
    var projectedCompletionDate: Date
    var monthlyContribution: Double
    var safeMonthlyCapacity: Double
    var durationMonths: Int? = nil
}

struct PlannerSpendingDetails: Codable, Equatable {
    var focus: PlannerSpendingFocus
    var baselineMonthlySpend: Double
    var targetMonthlySpend: Double
    var currentSpend: Double
    var durationDays: Int
    var expectedMonthlySaving: Double
}

struct PlannerMilestone: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var detail: String
    var targetAmount: Double? = nil
    var isCompleted: Bool = false
}

struct PlannerPlanPreview: Identifiable, Equatable {
    var id: PlannerPlanMode { mode }
    var mode: PlannerPlanMode
    var headline: String
    var detail: String
    var monthlyAction: Double
    var impact: String
    var bullets: [String]
    var isRecommended: Bool
}

enum PlannerFundingSource: Codable, Equatable {
    case safeCapacity
    case leakage(PlannerSpendingFocus)
    case incomeIncrease

    var title: String {
        switch self {
        case .safeCapacity: return "Safe monthly capacity"
        case .leakage(let focus): return focus.title
        case .incomeIncrease: return "Increase income"
        }
    }

    var icon: String {
        switch self {
        case .safeCapacity: return "banknote"
        case .leakage(let focus): return focus.icon
        case .incomeIncrease: return "arrow.up.right"
        }
    }
}

struct PlannerFundingComponent: Identifiable, Codable, Equatable {
    var id: String { sourceKey }
    var source: PlannerFundingSource
    var monthlyAmount: Double
    var maxMonthlyAmount: Double? = nil
    var baseline: Double?
    var note: String

    private var sourceKey: String {
        switch source {
        case .safeCapacity: return "safeCapacity"
        case .leakage(let focus): return "leakage.\(focus.rawValue)"
        case .incomeIncrease: return "incomeIncrease"
        }
    }
}

struct PlannerTimelineOption: Identifiable, Equatable {
    var id: Int { months }
    var months: Int
    var monthlyRequired: Double
    var safeContribution: Double
    var leakageNeeded: Double
    var statusLabel: String
    var label: String
    var detail: String
    var isComfortable: Bool
    var isPossible: Bool = true
}

struct PlannerDraft: Equatable {
    var selectedKind: PlannerGoalKind?
    var savingsPurpose: PlannerSavingsPurpose?
    var savingsAmountText: String = ""
    var savingsDeadline: Date = Calendar.current.date(byAdding: .month, value: 12, to: Date()) ?? Date()
    var selectedDurationMonths: Int?
    var selectedFundingComponents: [PlannerFundingComponent] = []

    var spendingFocus: PlannerSpendingFocus?
    var spendingTargetText: String = ""
    var spendingDurationDays: Int = 30

    var selectedMode: PlannerPlanMode?

    var savingsAmount: Double {
        Double(savingsAmountText.plannerNumericOnly) ?? 0
    }

    var spendingTarget: Double {
        Double(spendingTargetText.plannerNumericOnly) ?? 0
    }

    mutating func reset() {
        self = PlannerDraft()
    }
}

enum PlannerSheetRoute: Equatable {
    case pickType
    case corpusPurpose
    case corpusAmount
    case corpusTimeline
    case corpusFunding
    case corpusPreview
    case savingsDetails
    case savingsPlan
    case spendingFocus
    case spendingPlan
    case created(PlannerGoal)
    case detail(PlannerGoal)
}

// MARK: - Formatting Helpers

extension Double {
    var plannerCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: NSNumber(value: self)) ?? "₹\(Int(self))"
    }
}

extension String {
    var plannerNumericOnly: String {
        filter { $0.isNumber || $0 == "." }
    }
}

extension Date {
    var plannerMonthYear: String {
        formatted(.dateTime.month(.abbreviated).year())
    }
}
