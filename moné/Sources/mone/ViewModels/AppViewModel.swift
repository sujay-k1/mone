import SwiftUI
import Observation

// MARK: - App View Model

@Observable
class AppViewModel {

    // MARK: Onboarding State
    var hasCompletedOnboarding: Bool = false
    var onboardingStep: OnboardingStep = .welcome

    // MARK: User Choices
    var primaryAgenda:  AgendaType?  = nil
    var secondaryAgenda: AgendaType? = nil
    var storageMode:    StorageMode?  = nil
    var setupMethod:    SetupMethod? = nil
    var nudgeIntensity: NudgeIntensity = .balanced

    // MARK: Money Map & Data
    var moneyMap: MoneyMap          = MockDataService.defaultMoneyMap()
    var transactions: [Transaction] = MockDataService.defaultTransactions()
    var insights: [InsightCardData] = MockDataService.defaultInsights()

    // MARK: Pay with Pause
    var payMerchant: String    = ""
    var payAmount:   Double    = 0
    var payCategory: TransactionCategory = .other
    var activeNudge: Nudge?    = nil
    var showNudge:   Bool      = false

    // MARK: - Onboarding Steps

    enum OnboardingStep: Int, CaseIterable {
        case welcome, dataPrivacy, auth, primaryAgenda, secondaryAgenda,
             setupMethod, aaConsent, buildingMoneyMap, confirmFindings,
             goalSetup, complete
    }

    func advance() {
        switch onboardingStep {
        case .welcome:          onboardingStep = .dataPrivacy
        case .dataPrivacy:
            onboardingStep = storageMode == .encryptedBackup ? .auth : .primaryAgenda
        case .auth:             onboardingStep = .primaryAgenda
        case .primaryAgenda:    onboardingStep = .setupMethod
        case .secondaryAgenda:  onboardingStep = .setupMethod
        case .setupMethod:
            switch setupMethod {
            case .accountAggregator: onboardingStep = .aaConsent
            default:                 onboardingStep = .buildingMoneyMap
            }
        case .aaConsent:        onboardingStep = .buildingMoneyMap
        case .buildingMoneyMap: onboardingStep = .confirmFindings
        case .confirmFindings:
            let needsGoalSetup = (primaryAgenda == .planGoals || secondaryAgenda == .planGoals)
            onboardingStep = needsGoalSetup ? .goalSetup : .complete
        case .goalSetup:        onboardingStep = .complete
        case .complete:
            if let agenda = primaryAgenda {
                nudgeIntensity = agenda.defaultNudgeIntensity
            }
            hasCompletedOnboarding = true
        }

        if onboardingStep == .complete {
            if let agenda = primaryAgenda {
                nudgeIntensity = agenda.defaultNudgeIntensity
            }
            hasCompletedOnboarding = true
        }
    }

    func goBack() {
        switch onboardingStep {
        case .welcome:          break
        case .dataPrivacy:      onboardingStep = .welcome
        case .auth:             onboardingStep = .dataPrivacy
        case .primaryAgenda:    onboardingStep = .dataPrivacy
        case .secondaryAgenda:  onboardingStep = .primaryAgenda
        case .setupMethod:      onboardingStep = .primaryAgenda
        case .aaConsent:        onboardingStep = .setupMethod
        case .buildingMoneyMap:
            onboardingStep = setupMethod == .accountAggregator ? .aaConsent : .setupMethod
        case .confirmFindings:  onboardingStep = .buildingMoneyMap
        case .goalSetup:        onboardingStep = .confirmFindings
        case .complete:         break
        }
    }

    func selectPrimary(_ agenda: AgendaType) {
        primaryAgenda  = agenda
        nudgeIntensity = agenda.defaultNudgeIntensity
    }

    func selectSecondary(_ agenda: AgendaType?) {
        secondaryAgenda = agenda
    }

    func skipSecondaryAgenda() {
        secondaryAgenda = nil
        advance()
    }

    // MARK: - Calculated Properties

    var spentThisWeek: Double {
        transactions.filter {
            !$0.isUpcoming &&
            $0.type == .debit &&
            Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear)
        }.reduce(0) { $0 + $1.amount }
    }

    var safeToSpend: SafeToSpendCalculator.Result {
        SafeToSpendCalculator.calculate(moneyMap: moneyMap, spentThisWeek: spentThisWeek)
    }

    var healthReport: FinancialHealthReport {
        FinancialHealthCalculator.calculate(moneyMap: moneyMap)
    }

    var goalsOnTrack: Int {
        moneyMap.goals.filter { !GoalProjectionCalculator.status(for: $0).isAtRisk }.count
    }

    // MARK: - Pay with Pause

    func evaluatePay() {
        guard payAmount > 0 else { return }
        activeNudge = NudgeEngine.evaluate(
            merchant: payMerchant.isEmpty ? "Merchant" : payMerchant,
            amount: payAmount,
            category: payCategory,
            moneyMap: moneyMap,
            spentThisWeek: spentThisWeek,
            goals: moneyMap.goals,
            intensity: nudgeIntensity
        )
        showNudge = activeNudge != nil
        if activeNudge == nil {
            // Safe — proceed directly
        }
    }

    func confirmPayment() {
        if payAmount > 0 {
            let t = Transaction(
                merchant: payMerchant.isEmpty ? "Merchant" : payMerchant,
                amount: payAmount,
                date: Date(),
                category: payCategory,
                type: .debit
            )
            transactions.insert(t, at: 0)
        }
        resetPay()
    }

    func resetPay() {
        payMerchant = ""
        payAmount   = 0
        payCategory = .other
        activeNudge = nil
        showNudge   = false
    }

    // MARK: - Formatted helpers

    func formatted(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        let s = f.string(from: NSNumber(value: value)) ?? "\(Int(value))"
        return "₹\(s)"
    }

    // MARK: - Flow Reset

    func resetOnboarding(to step: OnboardingStep = .welcome) {
        hasCompletedOnboarding = false
        onboardingStep = step
        primaryAgenda = nil
        secondaryAgenda = nil
        storageMode = nil
        setupMethod = nil
        nudgeIntensity = .balanced
    }

    func startAuthenticatedOnboarding(at step: OnboardingStep = .primaryAgenda) {
        resetOnboarding(to: step)
        storageMode = .encryptedBackup
    }
}
