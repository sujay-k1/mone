import SwiftUI
import Observation

// MARK: - App View Model

@Observable
class AppViewModel {

    // MARK: - Local Onboarding Persistence

    @ObservationIgnored
    private let localStateKey = "mone.localOnboardingState.v1"

    @ObservationIgnored
    private var isRestoringLocalState = false

    private struct LocalOnboardingState: Codable {
        var hasCompletedOnboarding: Bool
        var onboardingStepRawValue: Int
        var primaryAgenda: String?
        var secondaryAgenda: String?
        var storageMode: String?
        var setupMethod: String?
        var verifiedPhone: String?
        var enteredPAN: String?
        var aaConsentId: String?
    }

    init() {
        restoreLocalState()
    }

    // MARK: Onboarding State
    var hasCompletedOnboarding: Bool = false {
        didSet { persistLocalState() }
    }

    var onboardingStep: OnboardingStep = .agendaEducation {
        didSet { persistLocalState() }
    }

    // MARK: Dashboard State
    var dashboardHealthState: DashboardHealthState? = nil

    // MARK: User Choices
    var primaryAgenda: AgendaType? = nil {
        didSet { persistLocalState() }
    }

    var secondaryAgenda: AgendaType? = nil {
        didSet { persistLocalState() }
    }

    var storageMode: StorageMode? = nil {
        didSet { persistLocalState() }
    }

    var setupMethod: SetupMethod? = nil {
        didSet { persistLocalState() }
    }

    var nudgeIntensity: NudgeIntensity = .balanced

    // MARK: AA Flow State
    var verifiedPhone: String? = nil {
        didSet { persistLocalState() }
    }

    var enteredPAN: String? = nil {
        didSet { persistLocalState() }
    }

    var aaConsentId: String? = nil {
        didSet { persistLocalState() }
    }

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
        enteredPAN = nil
        aaConsentId = nil
        aaResponse = nil
        aaFetchError = nil

        persistLocalState()
    }

    func startAuthenticatedOnboarding(at step: OnboardingStep = .agendaEducation) {
        resetOnboarding(to: step)
    }
    
    func clearLocalGuestProgress() {
        UserDefaults.standard.removeObject(forKey: localStateKey)
        resetOnboarding(to: .agendaEducation)
    }
    
    // MARK: - Local State Persistence

    private func persistLocalState() {
        guard !isRestoringLocalState else { return }

        let state = LocalOnboardingState(
            hasCompletedOnboarding: hasCompletedOnboarding,
            onboardingStepRawValue: onboardingStep.rawValue,
            primaryAgenda: encodeAgenda(primaryAgenda),
            secondaryAgenda: encodeAgenda(secondaryAgenda),
            storageMode: encodeStorageMode(storageMode),
            setupMethod: encodeSetupMethod(setupMethod),
            verifiedPhone: verifiedPhone,
            enteredPAN: enteredPAN,
            aaConsentId: aaConsentId
        )

        do {
            let data = try JSONEncoder().encode(state)
            UserDefaults.standard.set(data, forKey: localStateKey)
        } catch {
            print("[AppViewModel] Failed to persist local onboarding state:", error)
        }
    }

    private func restoreLocalState() {
        guard let data = UserDefaults.standard.data(forKey: localStateKey) else {
            return
        }

        do {
            isRestoringLocalState = true

            let state = try JSONDecoder().decode(LocalOnboardingState.self, from: data)

            hasCompletedOnboarding = state.hasCompletedOnboarding
            onboardingStep = OnboardingStep(rawValue: state.onboardingStepRawValue) ?? .agendaEducation
            primaryAgenda = decodeAgenda(state.primaryAgenda)
            secondaryAgenda = decodeAgenda(state.secondaryAgenda)
            storageMode = decodeStorageMode(state.storageMode)
            setupMethod = decodeSetupMethod(state.setupMethod)
            verifiedPhone = state.verifiedPhone
            enteredPAN = state.enteredPAN
            aaConsentId = state.aaConsentId

            if let agenda = primaryAgenda {
                nudgeIntensity = agenda.defaultNudgeIntensity
            }

            isRestoringLocalState = false
        } catch {
            isRestoringLocalState = false
            UserDefaults.standard.removeObject(forKey: localStateKey)
            print("[AppViewModel] Failed to restore local onboarding state:", error)
        }
    }

    private func encodeAgenda(_ value: AgendaType?) -> String? {
        guard let value else { return nil }

        switch value {
        case .controlSpending:
            return "controlSpending"
        case .planGoals:
            return "planGoals"
        case .understandPicture:
            return "understandPicture"
        }
    }

    private func decodeAgenda(_ value: String?) -> AgendaType? {
        switch value {
        case "controlSpending":
            return .controlSpending
        case "planGoals":
            return .planGoals
        case "understandPicture":
            return .understandPicture
        default:
            return nil
        }
    }

    private func encodeStorageMode(_ value: StorageMode?) -> String? {
        guard let value else { return nil }

        switch value {
        case .encryptedBackup:
            return "encryptedBackup"
        case .local:
            return "local"
        }
    }

    private func decodeStorageMode(_ value: String?) -> StorageMode? {
        switch value {
        case "encryptedBackup":
            return .encryptedBackup
        case "local":
            return .local
        default:
            return nil
        }
    }

    private func encodeSetupMethod(_ value: SetupMethod?) -> String? {
        guard let value else { return nil }

        switch value {
        case .accountAggregator:
            return "accountAggregator"
        case .email:
            return "email"
        case .manual:
            return "manual"
        }
    }

    private func decodeSetupMethod(_ value: String?) -> SetupMethod? {
        switch value {
        case "accountAggregator":
            return .accountAggregator
        case "email":
            return .email
        case "manual":
            return .manual
        default:
            return nil
        }
    }
}
