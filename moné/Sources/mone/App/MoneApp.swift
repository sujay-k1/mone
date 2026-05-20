import SwiftUI
import SwiftData

@main
struct MoneApp: App {
    @State private var appVM = AppViewModel()

    init() {
        configureTabBarAppearance()
    }

    var body: some Scene {
        WindowGroup {
            // LocalDatabaseDebugView()
            RootView()
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

    // ── UITabBar appearance — Financial Noir palette ──────────────────────
    private func configureTabBarAppearance() {
        let surfaceLow  = UIColor(red: 0x0E/255, green: 0x0E/255, blue: 0x0E/255, alpha: 1)
        let strokeColor = UIColor(red: 0x2A/255, green: 0x2A/255, blue: 0x2A/255, alpha: 1)
        let primaryText = UIColor(red: 0xE5/255, green: 0xE2/255, blue: 0xE0/255, alpha: 1)
        let dimText     = UIColor(red: 0x6B/255, green: 0x6B/255, blue: 0x62/255, alpha: 1)

        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = surfaceLow
        appearance.shadowColor     = strokeColor   // 1 pt top hairline

        // Normal (unselected) items
        appearance.stackedLayoutAppearance.normal.iconColor = dimText
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: dimText,
            .font: UIFont.systemFont(ofSize: 10, weight: .regular)
        ]

        // Selected items
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
        }
        .environment(sessionVM)
        .animation(.easeInOut(duration: 0.35), value: sessionVM.route)
        .task {
            await sessionVM.initialize()
            syncOnboardingState(for: sessionVM.route)
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

        if sessionVM.shouldForceWelcomeOnboarding || supabase.auth.currentSession == nil {
            appVM.resetOnboarding(to: .agendaEducation)
        } else {
            appVM.startAuthenticatedOnboarding(at: sessionVM.nextOnboardingStep)
        }
    }
}

// MARK: - Main Tab View (iOS 18 Tab API)

struct MainTabView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var selectedTab: TabSelection = .dashboard
    @State private var showProfileSpace = false
    @State private var searchText = ""

    enum TabSelection: Hashable {
        case dashboard, moneyMap, pay, goals, transactions
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
        ZStack(alignment: .topTrailing) {
            TabView(selection: $selectedTab) {
                Tab("Dashboard", systemImage: dashboardIcon, value: .dashboard) {
                    DashboardView()
                }

                Tab("Money Map", systemImage: "lightbulb.max", value: .moneyMap) {
                    MoneyMapView()
                }

                Tab("Goals", systemImage: "dot.scope", value: .goals) {
                    GoalsView()
                }

                Tab("Transactions", systemImage: "arrow.up.arrow.down", value: .transactions) {
                    TransactionsView()
                }

                Tab(value: .pay, role: .search) {
                    PayView()
                } label: {
                    Label("Pay", systemImage: "qrcode")
                }
            }

            ProfileAvatarButton {
                showProfileSpace = true
            }
            .padding(.top, 12)
            .padding(.trailing, 20)
        }
        .sheet(isPresented: $showProfileSpace) {
            ProfileSpaceView()
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
