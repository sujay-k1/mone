import SwiftUI
import SwiftData

extension Notification.Name {
    static let moneTabTourStepDidChange = Notification.Name("mone.tabTourStepDidChange")
}

enum MoneTabTourStepName {
    static let activeStepDefaultsKey = "mone.tabTourActiveStep"
    static let dashboard = "dashboard"
    static let moneyMap = "moneyMap"
}

@main
struct MoneApp: App {
    @State private var appVM = AppViewModel()

    init() {
        configureTabBarAppearance()
    }

    var body: some Scene {
        WindowGroup {
            // LocalDatabaseDebugView()
            // LocalDatabaseDebugView()
            RootView()
            // RootView()
                .environment(appVM)
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [
            StoredPersona.self,
            StoredAccount.self,
            StoredTransaction.self,
            StoredClassification.self,
            StoredAISuggestion.self,
            StoredMonthlySnapshot.self
        ])
    }

    // ── UITabBar appearance ───────────────────────────────────────────────
    private func configureTabBarAppearance() {
        let primaryText = UIColor(red: 0xE5/255, green: 0xE2/255, blue: 0xE0/255, alpha: 1)
        let dimText     = UIColor(red: 0x6B/255, green: 0x6B/255, blue: 0x62/255, alpha: 1)

        // configureWithDefaultBackground lets iOS 26 apply liquid glass.
        // Only item colors are overridden — no background or shadow.
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

        appearance.stackedLayoutAppearance.normal.iconColor = dimText
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: dimText,
            .font: UIFont.systemFont(ofSize: 10, weight: .regular)
        ]

        appearance.stackedLayoutAppearance.selected.iconColor = primaryText
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: primaryText,
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]

        UITabBar.appearance().standardAppearance   = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Root

struct RootView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var sessionVM = SessionViewModel()
    @State private var isShowingSplash = true

    var body: some View {
        ZStack {
            Color.moneBackground.ignoresSafeArea()

            switch sessionVM.route {
            case .loading:
                ProgressView()
                    .tint(Color.monePrimary)
            case .onboarding:
                OnboardingFlow()
                    .transition(.opacity)
            case .auth:
                AuthView(
                    onAuthComplete: { Task { await sessionVM.handleAuthSuccess() } },
                    showBackButton: false
                )
            case .nameOnboarding:
                NameOnboardingView()
            case .dashboard:
                MainTabView()
            }

            if isShowingSplash {
                SplashScreenView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .environment(sessionVM)
        .animation(.easeInOut(duration: 0.35), value: sessionVM.route)
        .animation(.easeOut(duration: 0.45), value: isShowingSplash)
        .task {
            await sessionVM.initialize()

            if supabase.auth.currentSession == nil,
               appVM.hasCompletedOnboarding {
                sessionVM.route = .dashboard
            } else {
                syncOnboardingState(for: sessionVM.route)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(2.2))
            isShowingSplash = false
        }
        .onChange(of: sessionVM.route) { _, route in
            syncOnboardingState(for: route)
        }
        .onChange(of: sessionVM.onboardingResetToken) { _, _ in
            syncOnboardingState(for: .onboarding)
        }
        .onChange(of: appVM.hasCompletedOnboarding) { _, completed in
            if completed {
                Task {
                    if supabase.auth.currentSession != nil {
                        await sessionVM.completeOnboarding()
                        await sessionVM.handleAuthSuccess()
                    } else {
                        sessionVM.route = .dashboard
                    }
                }
            }
        }
        .onChange(of: appVM.onboardingStep) { _, step in
            guard sessionVM.route == .onboarding,
                  supabase.auth.currentSession != nil,
                  !sessionVM.shouldForceWelcomeOnboarding else {
                return
            }

            Task { await sessionVM.updateOnboardingProgress(to: step) }
        }
    }

    private func syncOnboardingState(for route: SessionViewModel.Route) {
        guard route == .onboarding else { return }

        if sessionVM.shouldForceWelcomeOnboarding {
            appVM.resetOnboarding(to: .agendaEducation)
            return
        }

        if supabase.auth.currentSession == nil {
            // Anonymous/local user.
            // Do NOT reset here; AppViewModel may have restored local onboarding progress.
            return
        }

        appVM.startAuthenticatedOnboarding(at: sessionVM.nextOnboardingStep)
    }
}

// MARK: - Main Tab View (iOS 18 Tab API)

struct MainTabView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(SessionViewModel.self) private var sessionVM
    @State private var showProfileSpace = false
    @State private var showSignUp = false
    @State private var searchText = ""
    @State private var didEvaluateAutomaticSignUp = false
    @State private var isAutomaticSignUpFlow = false
    @State private var didHandleSignUpSheetResult = false
    @State private var activeTabTourStep: TabTourStep?
    @State private var furthestVisitedTabTourStep: TabTourStep?

    private static let signUpDismissedKey = "mone.signUpDismissed"
    private static let tabTourCompletedKey = "mone.tabTourCompleted"
    private static let tabTourBottomClearance: CGFloat = 86

    fileprivate enum TabTourStep: Int, CaseIterable, Identifiable {
        case dashboard
        case moneyMap
        case goals
        case pay

        var id: Int { rawValue }

        var tab: AppViewModel.TabSelection {
            switch self {
            case .dashboard: return .dashboard
            case .moneyMap: return .moneyMap
            case .goals: return .goals
            case .pay: return .pay
            }
        }

        var message: String {
            switch self {
            case .dashboard:
                return "Numbers that tell you the story of your financial health in real-time."
            case .moneyMap:
                return "See how your actions shape your financial well-being, to set goals!"
            case .goals:
                return "Set and achieve goals with real-time actionable nudges"
            case .pay:
                return "Pay with moné and it will tell if your should make that payment you're about to make."
            }
        }

        var index: Int { rawValue + 1 }
        var isLast: Bool { self == Self.allCases.last }
        var next: TabTourStep? {
            guard let currentIndex = Self.allCases.firstIndex(of: self) else { return nil }
            let nextIndex = Self.allCases.index(after: currentIndex)
            guard nextIndex < Self.allCases.endIndex else { return nil }
            return Self.allCases[nextIndex]
        }
    }

    private var dashboardIcon: String {
        switch appVM.dashboardHealthState {
        case .healthy:  return "chart.line.uptrend.xyaxis"
        case .watch:    return "chart.line.flattrend.xyaxis"
        case .risk:     return "chart.line.downtrend.xyaxis"
        case nil:       return "chart.line.flattrend.xyaxis"
        }
    }

    var body: some View {
        @Bindable var appVM = appVM
        ZStack(alignment: .topTrailing) {
            tabContent(selection: $appVM.selectedTab)

            ProfileAvatarButton {
                MoneTactileFeedback.performGentleButtonTap {
                    showProfileSpace = true
                }
            }
            .padding(.top, 12)
            .padding(.trailing, 20)
        }
        .overlay {
            if activeTabTourStep != nil {
                Color.black.opacity(0.5)
                    .padding(.bottom, Self.tabTourBottomClearance)
                    .ignoresSafeArea(edges: [.top, .horizontal])
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .overlay(alignment: .bottom) {
            if let step = activeTabTourStep {
                TabTourAccessory(
                    step: step,
                    totalSteps: TabTourStep.allCases.count,
                    onSkip: dismissTabTourForNow,
                    onNext: advanceTabTour
                )
                .padding(.bottom, 48)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(2)
            }
        }
        .sheet(isPresented: $showProfileSpace) {
            ProfileSpaceView(onSignUpRequested: {
                isAutomaticSignUpFlow = false
                didHandleSignUpSheetResult = false
                showSignUp = true
            })
        }
        .sheet(isPresented: $showSignUp, onDismiss: handleSignUpSheetNativeDismissal) {
            SignUpSheet(
                aaPhone: appVM.verifiedPhone ?? "",
                onDismissed: {
                    handleSignUpSheetFinished(markDismissed: true)
                },
                onComplete: {
                    handleSignUpSheetFinished(markDismissed: false)
                }
            )
            .presentationDetents([PresentationDetent.large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            presentAutomaticSignUpIfNeeded()
            startTabTourIfNeeded()
        }
        .onChange(of: appVM.selectedTab) { _, selectedTab in
            if enforceTabTourSelection(selectedTab) {
                return
            }
            presentAutomaticSignUpIfNeeded()
            startTabTourIfNeeded()
        }
        .onChange(of: activeTabTourStep) { _, step in
            updateFurthestVisitedTabTourStep(step)
            publishTabTourStep(step)
        }
    }

    private func tabContent(selection: Binding<AppViewModel.TabSelection>) -> some View {
        TabView(selection: selection) {
            Tab("Trends", systemImage: dashboardIcon, value: AppViewModel.TabSelection.dashboard) {
                DashboardView()
            }

            Tab("MoneyMap", systemImage: "binoculars", value: AppViewModel.TabSelection.moneyMap) {
                MoneyMapView()
            }

            Tab("Goals", systemImage: "dot.scope", value: AppViewModel.TabSelection.goals) {
                GoalsView()
            }

            Tab(value: AppViewModel.TabSelection.pay, role: .search) {
                PayView()
            } label: {
                Label("Pay", systemImage: "qrcode")
            }
        }
        .sensoryFeedback(.selection, trigger: selection.wrappedValue)
    }

    private var hasCompletedSignedInProfile: Bool {
        guard supabase.auth.currentSession != nil else { return false }
        guard let profile = sessionVM.profile else { return false }
        return profile.onboardingCompleted == true
            && !(profile.fullName ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func presentAutomaticSignUpIfNeeded() {
        guard activeTabTourStep == nil else { return }
        guard !didEvaluateAutomaticSignUp else { return }
        guard shouldPresentAutomaticSignUp else { return }

        didEvaluateAutomaticSignUp = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            guard activeTabTourStep == nil else { return }
            guard shouldPresentAutomaticSignUp else { return }
            isAutomaticSignUpFlow = true
            didHandleSignUpSheetResult = false
            showSignUp = true
        }
    }

    private var shouldPresentAutomaticSignUp: Bool {
        guard appVM.selectedTab == .dashboard else { return false }
        guard appVM.hasCompletedOnboarding else { return false }
        guard !hasCompletedSignedInProfile else { return false }
        guard !UserDefaults.standard.bool(forKey: Self.signUpDismissedKey) else { return false }
        guard !showProfileSpace, !showSignUp else { return false }
        return true
    }

    private func handleSignUpSheetFinished(markDismissed: Bool) {
        if markDismissed {
            UserDefaults.standard.set(true, forKey: Self.signUpDismissedKey)
        }

        let shouldStartTour = isAutomaticSignUpFlow
        didHandleSignUpSheetResult = true
        isAutomaticSignUpFlow = false
        showSignUp = false

        if shouldStartTour {
            startTabTourIfNeeded()
        }
    }

    private func handleSignUpSheetNativeDismissal() {
        guard isAutomaticSignUpFlow, !didHandleSignUpSheetResult else {
            isAutomaticSignUpFlow = false
            return
        }

        UserDefaults.standard.set(true, forKey: Self.signUpDismissedKey)
        didHandleSignUpSheetResult = true
        isAutomaticSignUpFlow = false
        startTabTourIfNeeded()
    }

    private func startTabTourIfNeeded() {
        guard appVM.hasCompletedOnboarding else { return }
        guard !UserDefaults.standard.bool(forKey: Self.tabTourCompletedKey) else { return }
        guard activeTabTourStep == nil else { return }
        guard appVM.selectedTab == .dashboard else { return }
        guard !showProfileSpace, !showSignUp else { return }
        guard !shouldPresentAutomaticSignUp else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard !showProfileSpace, !showSignUp else { return }
            guard !UserDefaults.standard.bool(forKey: Self.tabTourCompletedKey) else { return }
            guard appVM.selectedTab == .dashboard else { return }
            guard !shouldPresentAutomaticSignUp else { return }

            withAnimation(.easeInOut(duration: 0.25)) {
                appVM.selectedTab = AppViewModel.TabSelection.dashboard
                activeTabTourStep = .dashboard
                furthestVisitedTabTourStep = .dashboard
            }
        }
    }

    private func advanceTabTour() {
        guard let step = activeTabTourStep else { return }
        guard let next = step.next else {
            finishTabTour()
            return
        }

        withAnimation(.easeInOut(duration: 0.25)) {
            appVM.selectedTab = next.tab
            activeTabTourStep = next
        }
    }

    private func finishTabTour() {
        UserDefaults.standard.set(true, forKey: Self.tabTourCompletedKey)
        withAnimation(.easeInOut(duration: 0.2)) {
            activeTabTourStep = nil
        }
    }

    private func dismissTabTourForNow() {
        withAnimation(.easeInOut(duration: 0.2)) {
            activeTabTourStep = nil
        }
    }

    private func enforceTabTourSelection(_ selectedTab: AppViewModel.TabSelection) -> Bool {
        guard let activeStep = activeTabTourStep else { return false }
        guard let selectedStep = tabTourStep(for: selectedTab) else { return false }
        let furthestStep = furthestVisitedTabTourStep ?? activeStep

        guard selectedStep.rawValue <= furthestStep.rawValue else {
            withAnimation(.easeInOut(duration: 0.2)) {
                appVM.selectedTab = activeStep.tab
            }
            return true
        }

        if selectedStep != activeStep {
            withAnimation(.easeInOut(duration: 0.2)) {
                activeTabTourStep = selectedStep
            }
            return true
        }

        return false
    }

    private func tabTourStep(for tab: AppViewModel.TabSelection) -> TabTourStep? {
        TabTourStep.allCases.first { $0.tab == tab }
    }

    private func updateFurthestVisitedTabTourStep(_ step: TabTourStep?) {
        guard let step else { return }
        guard let furthestVisitedTabTourStep else {
            self.furthestVisitedTabTourStep = step
            return
        }

        if step.rawValue > furthestVisitedTabTourStep.rawValue {
            self.furthestVisitedTabTourStep = step
        }
    }

    private func publishTabTourStep(_ step: TabTourStep?) {
        let stepName: String?
        switch step {
        case .dashboard:
            stepName = MoneTabTourStepName.dashboard
        case .moneyMap:
            stepName = MoneTabTourStepName.moneyMap
        case .goals, .pay, .none:
            stepName = nil
        }

        if let stepName {
            UserDefaults.standard.set(stepName, forKey: MoneTabTourStepName.activeStepDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: MoneTabTourStepName.activeStepDefaultsKey)
        }

        NotificationCenter.default.post(
            name: .moneTabTourStepDidChange,
            object: nil,
            userInfo: ["step": stepName as Any]
        )
    }
}

private struct TabTourAccessory: View {
    let step: MainTabView.TabTourStep
    let totalSteps: Int
    let onSkip: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(step.message)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.monePrimary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)

            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onNext) {
                Image(systemName: step.isLast ? "checkmark" : "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.monePrimary)
                    .frame(width: 46, height: 46)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.8)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(step.isLast ? "Finish tour" : "Next tip")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(TabTourGlassCardStyle())
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}

private struct TabTourGlassCardStyle: ViewModifier {
    private let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .background(Color.white.opacity(0.045), in: shape)
                .glassEffect(.clear, in: shape)
                .overlay(
                    shape.strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.26), radius: 22, x: 0, y: 12)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .background(Color.moneSurfaceEl.opacity(0.42), in: shape)
                .overlay(
                    shape.strokeBorder(Color.white.opacity(0.14), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.26), radius: 22, x: 0, y: 12)
        }
    }
}


// MARK: - Onboarding Flow

struct OnboardingFlow: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(SessionViewModel.self) private var sessionVM

    var body: some View {
        ZStack {
            Color.moneBackground.ignoresSafeArea()

            switch appVM.onboardingStep {
            case .agendaEducation:  AgendaEducationView()
            case .methodSelection:  SetupMethodView()
            case .aaConsent:        DummyAAConsentView()
            case .phoneOtp:         PhoneVerificationView()
            case .aaFetching:       DataFetchingView()
            case .processing:       IntelligenceProcessingView()
            case .storageChoice:    StorageChoiceView()
            case .dashboardTour:    DashboardTourView()
            case .complete:         EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appVM.onboardingStep)
    }
}
