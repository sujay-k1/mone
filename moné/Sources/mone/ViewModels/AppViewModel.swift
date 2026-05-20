import SwiftUI
import Observation

// MARK: - App View Model

@Observable
class AppViewModel {

    // MARK: Onboarding State
    var hasCompletedOnboarding: Bool = false
    var onboardingStep: OnboardingStep = .agendaEducation

    // MARK: User Choices
    var primaryAgenda:  AgendaType?  = nil
    var secondaryAgenda: AgendaType? = nil
    var storageMode:    StorageMode?  = nil
    var setupMethod:    SetupMethod? = nil
    var nudgeIntensity: NudgeIntensity = .balanced

    // MARK: AA Flow State
    var verifiedPhone: String? = nil
    var enteredPAN: String? = nil
    var aaConsentId: String? = nil
    var aaResponse: SyntheticAAResponse? = nil
    var aaFetchError: String? = nil

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

    // MARK: - Onboarding Steps (Agenda-First Flow)

    enum OnboardingStep: Int, CaseIterable {
        case agendaEducation      // Education cards + primary/secondary agenda selection
        case methodSelection      // How to gather financial data
        case aaConsent            // AA consent explanation + phone entry
        case phoneOtp             // Phone verification via 2Factor OTP
        case aaFetching           // Fetching dummy AA data based on verified phone
        case processing           // Intelligence pipeline (linking, normalizing, detecting)
        case storageChoice        // Cloud vs local — after user has seen value
        case dashboardTour        // One-time orientation after the Money Map is ready
        case complete             // Done — route to dashboard
    }

    func advance() {
        switch onboardingStep {
        case .agendaEducation:  onboardingStep = .methodSelection
        case .methodSelection:  onboardingStep = .aaConsent
        case .aaConsent:        onboardingStep = .phoneOtp
        case .phoneOtp:         onboardingStep = .aaFetching
        case .aaFetching:       onboardingStep = .complete
        case .processing:       onboardingStep = .storageChoice
        case .storageChoice:    onboardingStep = .dashboardTour
        case .dashboardTour:    onboardingStep = .complete
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
        case .agendaEducation:  break
        case .methodSelection:  onboardingStep = .agendaEducation
        case .aaConsent:        onboardingStep = .methodSelection
        case .phoneOtp:         onboardingStep = .aaConsent
        case .aaFetching:       break // no going back from data fetch
        case .processing:       break // no going back from processing
        case .storageChoice:    break // no going back after processing
        case .dashboardTour:    break
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
    }

    // MARK: - AA Data Handling

    func attachAAData(phone: String, response: SyntheticAAResponse) {
        verifiedPhone = phone
        aaResponse = response
        aaFetchError = nil
    }

    func processAAData() {
        guard let response = aaResponse else { return }
        let result = AADataTransformer.transform(response: response)
        moneyMap = result.moneyMap
        transactions = result.transactions
        insights = result.insights
    }

    // MARK: - Persona Info

    var personaName: String? {
        guard let phone = verifiedPhone else { return nil }
        return DummyAAProvider.personaName(for: phone)
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

    func resetOnboarding(to step: OnboardingStep = .agendaEducation) {
        hasCompletedOnboarding = false
        onboardingStep = step
        primaryAgenda = nil
        secondaryAgenda = nil
        storageMode = nil
        setupMethod = nil
        nudgeIntensity = .balanced
        verifiedPhone = nil
        aaResponse = nil
        aaFetchError = nil
    }

    func startAuthenticatedOnboarding(at step: OnboardingStep = .agendaEducation) {
        resetOnboarding(to: step)
    }
}
