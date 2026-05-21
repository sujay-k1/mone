import Foundation
import SwiftUI

enum MoneGoalType: String, Codable, CaseIterable, Identifiable {
    case buildSavings
    case controlSpending
    case growIncome

    var id: String { rawValue }

    var title: String {
        switch self {
        case .buildSavings: return "Build savings"
        case .controlSpending: return "Control spending"
        case .growIncome: return "Grow income"
        }
    }

    var subtitle: String {
        switch self {
        case .buildSavings:
            return "Save toward a future expense or safety buffer."
        case .controlSpending:
            return "Reduce leakage in one part of your lifestyle."
        case .growIncome:
            return "Plan a raise, job switch, side income, or freelance target."
        }
    }

    var systemImage: String {
        switch self {
        case .buildSavings: return "banknote"
        case .controlSpending: return "slider.horizontal.3"
        case .growIncome: return "arrow.up.right"
        }
    }

    var isComingSoon: Bool {
        self == .growIncome
    }
}

enum MoneGoalPlanMode: String, Codable, CaseIterable, Identifiable {
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
        case .comfortable: return "Low pressure"
        case .optimalBalance: return "Recommended"
        case .aggressive: return "Fastest"
        }
    }

    var subtitle: String {
        switch self {
        case .comfortable:
            return "Low pressure with minimal lifestyle change."
        case .optimalBalance:
            return "Meaningful progress without making the plan unrealistic."
        case .aggressive:
            return "Faster progress with stricter trade-offs."
        }
    }

    var systemImage: String {
        switch self {
        case .comfortable: return "leaf"
        case .optimalBalance: return "scale.3d"
        case .aggressive: return "bolt"
        }
    }
}

enum MoneGoalStatus: String, Codable {
    case notStarted
    case onTrack
    case slightlyBehind
    case needsAttention
    case completed
    case paused

    var title: String {
        switch self {
        case .notStarted: return "Not started"
        case .onTrack: return "On track"
        case .slightlyBehind: return "Slightly behind"
        case .needsAttention: return "Needs attention"
        case .completed: return "Completed"
        case .paused: return "Paused"
        }
    }
}

enum MoneSavingsPurpose: String, Codable, CaseIterable, Identifiable {
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

    var subtitle: String {
        switch self {
        case .emergencyFund:
            return "Build a safety buffer for unexpected expenses, job changes, or medical needs."
        case .home:
            return "Create a path toward a down payment, deposit, or home-related expense."
        case .travel:
            return "Save for a trip without disrupting your monthly plan."
        case .vehicle:
            return "Plan for a vehicle purchase or down payment."
        case .education:
            return "Save for courses, certifications, or learning expenses."
        case .medicalReserve:
            return "Keep a dedicated buffer for health-related uncertainty."
        case .largePurchase:
            return "Plan for a high-value purchase without using emergency cash."
        case .custom:
            return "Create your own savings goal."
        }
    }

    var systemImage: String {
        switch self {
        case .emergencyFund: return "shield"
        case .home: return "house"
        case .travel: return "airplane"
        case .vehicle: return "car"
        case .education: return "graduationcap"
        case .medicalReserve: return "cross.case"
        case .largePurchase: return "bag"
        case .custom: return "sparkles"
        }
    }
}

enum MoneSpendingCategory: String, Codable, CaseIterable, Identifiable {
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

    var subtitle: String {
        switch self {
        case .foodDelivery: return "Orders, eating out, and repeat food spends."
        case .shopping: return "Fashion, gadgets, lifestyle, and impulse purchases."
        case .subscriptions: return "Recurring services and memberships."
        case .upiSmallSpends: return "Frequent small payments that add up quietly."
        case .entertainment: return "Movies, events, games, and weekend spends."
        case .travel: return "Cabs, fuel, local trips, and commute leakage."
        case .custom: return "Track a category you define."
        }
    }

    var systemImage: String {
        switch self {
        case .foodDelivery: return "fork.knife"
        case .shopping: return "bag"
        case .subscriptions: return "repeat"
        case .upiSmallSpends: return "indianrupeesign.circle"
        case .entertainment: return "play.circle"
        case .travel: return "location"
        case .custom: return "sparkles"
        }
    }

    var demoBaselineSpend: Double {
        switch self {
        case .foodDelivery: return 12400
        case .shopping: return 9800
        case .subscriptions: return 3200
        case .upiSmallSpends: return 7600
        case .entertainment: return 5400
        case .travel: return 6800
        case .custom: return 5000
        }
    }

    var demoInsight: String {
        switch self {
        case .foodDelivery: return "₹12,400/month · up 28%"
        case .shopping: return "₹9,800/month · mostly weekends"
        case .subscriptions: return "₹3,200/month · recurring"
        case .upiSmallSpends: return "₹7,600/month · 42 payments"
        case .entertainment: return "₹5,400/month · flexible"
        case .travel: return "₹6,800/month · variable"
        case .custom: return "Set your own baseline"
        }
    }
}

struct MoneGoalMilestone: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var subtitle: String
    var targetAmount: Double?
    var targetDate: Date?
    var isCompleted: Bool = false
}

struct MoneSavingsGoalDetails: Codable, Hashable {
    var purpose: MoneSavingsPurpose
    var targetAmount: Double
    var currentAmount: Double
    var monthlyContribution: Double
    var desiredDeadline: Date
    var projectedCompletionDate: Date
}

struct MoneSpendingGoalDetails: Codable, Hashable {
    var category: MoneSpendingCategory
    var baselineMonthlySpend: Double
    var targetMonthlySpend: Double
    var currentSpend: Double
    var durationDays: Int
    var expectedMonthlySaving: Double
}

struct MoneGoal: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var type: MoneGoalType
    var title: String
    var status: MoneGoalStatus
    var planMode: MoneGoalPlanMode
    var createdAt: Date = Date()
    var milestones: [MoneGoalMilestone]
    var nextAction: String
    var savingsDetails: MoneSavingsGoalDetails?
    var spendingDetails: MoneSpendingGoalDetails?

    var progress: Double {
        switch type {
        case .buildSavings:
            guard let details = savingsDetails, details.targetAmount > 0 else { return 0 }
            return min(details.currentAmount / details.targetAmount, 1)
        case .controlSpending:
            guard let details = spendingDetails, details.targetMonthlySpend > 0 else { return 0 }
            return min(details.currentSpend / details.targetMonthlySpend, 1)
        case .growIncome:
            return 0
        }
    }

    var amountLine: String {
        switch type {
        case .buildSavings:
            guard let details = savingsDetails else { return "" }
            return "\(details.currentAmount.asINR) of \(details.targetAmount.asINR) saved"
        case .controlSpending:
            guard let details = spendingDetails else { return "" }
            return "\(details.currentSpend.asINR) of \(details.targetMonthlySpend.asINR) used"
        case .growIncome:
            return "Coming soon"
        }
    }

    var planLine: String {
        switch type {
        case .buildSavings:
            guard let details = savingsDetails else { return planMode.title }
            return "\(planMode.title) · \(details.monthlyContribution.asINR)/month"
        case .controlSpending:
            guard let details = spendingDetails else { return planMode.title }
            return "\(planMode.title) · save around \(details.expectedMonthlySaving.asINR)"
        case .growIncome:
            return "Coming soon"
        }
    }
}

struct MoneLeakageCategory: Codable, Hashable {
    var title: String
    var monthlyAmount: Double
}

struct MoneMoneyMapSnapshot: Codable, Hashable {
    var monthlyIncome: Double
    var monthlyCommitments: Double
    var essentialSpend: Double
    var discretionarySpend: Double
    var safeToSpend: Double
    var monthlySurplus: Double
    var liquidCash: Double
    var subscriptionLoad: Double
    var topLeakageCategories: [MoneLeakageCategory]

    static let demo = MoneMoneyMapSnapshot(
        monthlyIncome: 185000,
        monthlyCommitments: 72000,
        essentialSpend: 46000,
        discretionarySpend: 38000,
        safeToSpend: 24000,
        monthlySurplus: 32000,
        liquidCash: 242000,
        subscriptionLoad: 3200,
        topLeakageCategories: [
            MoneLeakageCategory(title: "Food delivery", monthlyAmount: 12400),
            MoneLeakageCategory(title: "Shopping", monthlyAmount: 9800),
            MoneLeakageCategory(title: "Subscriptions", monthlyAmount: 3200)
        ]
    )
}

struct MoneGoalCreationDraft: Equatable {
    var selectedType: MoneGoalType?
    var selectedMode: MoneGoalPlanMode?

    var savingsPurpose: MoneSavingsPurpose?
    var savingsAmountText: String = ""
    var savingsDeadline: Date = Calendar.current.date(byAdding: .month, value: 12, to: Date()) ?? Date()

    var spendingCategory: MoneSpendingCategory?
    var spendingTargetText: String = ""
    var spendingDurationDays: Int = 30

    var savingsAmount: Double? {
        Double(savingsAmountText.digitsAndDecimalOnly)
    }

    var spendingTarget: Double? {
        Double(spendingTargetText.digitsAndDecimalOnly)
    }

    var canContinueSavings: Bool {
        savingsPurpose != nil && (savingsAmount ?? 0) > 0 && savingsDeadline > Date()
    }

    var canContinueSpending: Bool {
        spendingCategory != nil && (spendingTarget ?? 0) > 0
    }

    mutating func reset() {
        self = MoneGoalCreationDraft()
    }
}

enum MoneGoalSheetRoute: Equatable {
    case pickType
    case pickSavingsPurpose
    case pickSavingsPlan
    case pickSpendingCategory
    case pickSpendingPlan
    case created(MoneGoal)
    case detail(MoneGoal)
}

extension Double {
    var asINR: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: NSNumber(value: self)) ?? "₹0"
    }

    var asPercent: String {
        "\(Int((self * 100).rounded()))%"
    }
}

extension String {
    var digitsAndDecimalOnly: String {
        filter { $0.isNumber || $0 == "." }
    }
}

extension Date {
    var monthYearLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: self)
    }
}
