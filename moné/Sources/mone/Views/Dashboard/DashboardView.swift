import SwiftUI
import SwiftData
import Charts
import UserNotifications

struct DashboardView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(SessionViewModel.self) private var sessionVM
    @Environment(\.modelContext) private var modelContext

    @State private var summary: DashboardSummary?
    @State private var velocityData: VelocityData?
    @State private var netWorthData: NetWorthData?
    @State private var topCategories: [CategorySpendItem] = []
    @State private var savingsTrend: [SavingsTrendPoint] = []
    @State private var errorMessage: String?
    @State private var showSignUp = false
    @State private var isRestoringFinancialData = false
    @State private var didCompleteInitialDashboardLoad = false
    @State private var shouldRunTourAutoScroll = false
    
    @State private var activeNudge: DashboardNudge?
    private let nudgeStore = DashboardNudgeStore()
    
    @State private var showSMSInfoSheet = false

    private enum TourScrollTarget {
        static let top = "dashboardTourTop"
        static let lower = "dashboardTourLower"
        static let bottom = "dashboardTourBottom"
    }

    var body: some View {
        ZStack {
            Color.moneBackground.ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 36) {
                        if let summary {
                            DashboardHeader(
                                title: dashboardTitle(for: summary),
                                subtitle: sessionVM.isSignedIn ? sessionVM.displayName.capitalized : nil,
                                tag: formattedMonth(summary.month)
                            )
                            .id(TourScrollTarget.top)
                            
//                            if let activeNudge {
//                                DashboardNudgeCard(
//                                    nudge: activeNudge,
//                                    onPrimaryAction: {
//                                        handleNudgeAction(activeNudge.id)
//                                    },
//                                    onDismiss: {
//                                        dismissNudge(activeNudge.id)
//                                    }//
//                                )
//                            }

                            
                            HealthStateCard(summary: summary)
                            
                            DashboardSectionTitle("Safe to spend")
                            SafeToSpendSplitCard(summary: summary)

                            DashboardSectionTitle("Spend velocity")
                            SpendVelocityCard(summary: summary, velocity: velocityData)
                            
                            DashboardSectionTitle("Top spending categories")
                                .id(TourScrollTarget.lower)
                            TopSpendingCategoriesCard(summary: summary, categories: topCategories)

                            DashboardSectionTitle("Net worth stratification")
                            NetWorthStratificationCard(summary: summary, netWorth: netWorthData)

                            DashboardSectionTitle("Monthly excess liquid trend")
                            SavingsTrendCard(summary: summary, trend: savingsTrend)

                            DashboardSectionTitle("Tax deductions")
                            TaxDeductionCard(summary: summary)

                            DashboardSectionTitle("Next best actions")
                            NextBestActionsCard(summary: summary)
                            
                            // agendaHero(summary)

                            Color.clear
                                .frame(height: 1)
                                .id(TourScrollTarget.bottom)
                            
                        } else if isRestoringFinancialData {
                            restoringFinancialDataView
                        } else if let errorMessage {
                            dashboardError(errorMessage)
                        } else {
                            ProgressView()
                                .tint(Color.monePrimary)
                        }
                    }
                    .padding(.horizontal, MoneSpacing.page)
                }
                .onReceive(NotificationCenter.default.publisher(for: .moneTabTourStepDidChange)) { notification in
                    guard notification.userInfo?["step"] as? String == MoneTabTourStepName.dashboard else { return }
                    shouldRunTourAutoScroll = true
                    runTourAutoScrollIfReady(proxy)
                }
                .onAppear {
                    if UserDefaults.standard.string(forKey: MoneTabTourStepName.activeStepDefaultsKey) == MoneTabTourStepName.dashboard {
                        shouldRunTourAutoScroll = true
                        runTourAutoScrollIfReady(proxy)
                    }
                }
                .onChange(of: summary != nil) { _, _ in
                    runTourAutoScrollIfReady(proxy)
                }
            }
        }
        .task {
            await loadDashboard()
        }
        .onAppear {
            if didCompleteInitialDashboardLoad, summary != nil {
                loadDashboardNudge()
            }
        }
        .sheet(isPresented: $showSignUp) {
            SignUpSheet(
                aaPhone: appVM.verifiedPhone ?? "",
                onDismissed: {
                    showSignUp = false
                },
                onComplete: {
                    showSignUp = false
                }
            )
            .presentationDetents([PresentationDetent.large])
            .presentationDragIndicator(.visible)
        }
        
        .sheet(isPresented: $showSMSInfoSheet) {
            SMSConnectInfoSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        
    }

    private func runTourAutoScrollIfReady(_ proxy: ScrollViewProxy) {
        guard shouldRunTourAutoScroll, summary != nil else { return }
        shouldRunTourAutoScroll = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.linear(duration: 48.0)) {
                proxy.scrollTo(TourScrollTarget.bottom, anchor: .bottom)
            }
        }
    }

    private func dashboardTitle(for summary: DashboardSummary) -> String {
        switch appVM.primaryAgenda ?? .controlSpending {
        case .controlSpending:
            return "Control your spending"
        case .planGoals:
            return "Plan your goals"
        case .understandPicture:
            return "Understand your money"
        }
    }

    private func formattedMonth(_ monthKey: String) -> String {
        guard monthKey.count == 7,
              let month = Int(monthKey.suffix(2)),
              let year = Int(monthKey.prefix(4)),
              month >= 1 && month <= 12 else { return monthKey }
        let names = ["JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC"]
        return "\(names[month - 1]) \(year)"
    }

    @ViewBuilder
    private func agendaHero(_ summary: DashboardSummary) -> some View {
        switch appVM.primaryAgenda ?? .controlSpending {
        case .controlSpending:
            AgendaMetricCard(
                label: "Safe-to-spend",
                value: formatCurrency(summary.safeToSpend),
                status: summary.healthState.rawValue.uppercased(),
                description: "Available after regular commitments, everyday spends, fund-building, liabilities, and review buffer. Tax is shown separately as liquid cash impact.",
                footerItems: [
                    DashboardFooterItem(title: "Commitments", value: formatCurrency(summary.committed)),
                    DashboardFooterItem(title: "Operating", value: formatCurrency(summary.operatingRemaining)),
                    // DashboardFooterItem(title: "Cash impact", value: formatCurrency(summary.liquidCashImpact))
                ]
            )

        case .planGoals:
            AgendaMetricCard(
                label: "Fund-building pace",
                value: "\(Int(summary.savingsRatio * 100))%",
                status: summary.savingsRatio >= 0.15 ? "ON TRACK" : "WATCH",
                description: "Share of monthly income moving towards SIPs, deposits, investments, or reserves.",
                footerItems: [
                    DashboardFooterItem(title: "Income", value: formatCurrency(summary.income)),
                    DashboardFooterItem(title: "Fund", value: formatCurrency(summary.fund)),
                    DashboardFooterItem(title: "Operating", value: formatCurrency(summary.operatingRemaining))
                ]
            )

        case .understandPicture:
            AgendaMetricCard(
                label: "Clarity index",
                value: summary.clarityLabel,
                status: "\(summary.confidence)%",
                description: "How confidently Moné understands this month after local categorisation and AI-assisted review.",
                footerItems: [
                    DashboardFooterItem(title: "Transactions", value: "\(summary.transactionCount)"),
                    DashboardFooterItem(title: "Review", value: "\(summary.reviewCount)"),
                    DashboardFooterItem(title: "Accounts", value: "\(summary.accountCount)")
                ]
            )
        }
    }
    
    private var restoringFinancialDataView: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProgressView()
                .tint(Color.monePrimary)

            Text("Restoring your money map")
                .font(.moneHLMd)
                .foregroundStyle(Color.monePrimary)

            Text("We found your saved financial profile. Rebuilding it on this device.")
                .font(.moneBodySm)
                .foregroundStyle(Color.moneSecondary)
        }
        .dashboardCard()
    }

    private func dashboardError(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dashboard not ready")
                .font(.moneHLMd)
                .foregroundStyle(Color.monePrimary)

            Text(message)
                .font(.moneBodySm)
                .foregroundStyle(Color.moneSecondary)
        }
        .dashboardCard()
    }

    @MainActor
    private func loadDashboard() async {
        do {
            let loader = DashboardDataLoader(modelContext: modelContext)

            if let localSummary = try loader.loadLatestSummary() {
                summary = localSummary
                appVM.dashboardHealthState = localSummary.healthState
                velocityData = try loader.loadVelocityData(currentMonth: localSummary.month)
                netWorthData = try loader.loadNetWorthData(summary: localSummary)
                topCategories = (try? loader.loadTopCategories(month: localSummary.month)) ?? []
                savingsTrend = (try? loader.loadSavingsTrend(currentMonth: localSummary.month)) ?? []
                errorMessage = nil
                didCompleteInitialDashboardLoad = true
                loadDashboardNudge()
                return
            }

            guard supabase.auth.currentSession != nil else {
                summary = nil
                activeNudge = nil
                errorMessage = "No processed financial data found. Complete Account Aggregator setup first."
                didCompleteInitialDashboardLoad = true
                return
            }

            isRestoringFinancialData = true
            errorMessage = nil

            let restored = try await FinancialDataCloudService()
                .restoreLatestCloudData(modelContext: modelContext)

            isRestoringFinancialData = false

            guard restored else {
                summary = nil
                activeNudge = nil
                errorMessage = "No saved financial data found for this account."
                didCompleteInitialDashboardLoad = true
                return
            }

            let reloadLoader = DashboardDataLoader(modelContext: modelContext)
            let restoredSummary = try reloadLoader.loadLatestSummary()
            summary = restoredSummary

            if let restoredSummary {
                appVM.dashboardHealthState = restoredSummary.healthState
                velocityData = try reloadLoader.loadVelocityData(currentMonth: restoredSummary.month)
                netWorthData = try reloadLoader.loadNetWorthData(summary: restoredSummary)
                topCategories = (try? reloadLoader.loadTopCategories(month: restoredSummary.month)) ?? []
                savingsTrend = (try? reloadLoader.loadSavingsTrend(currentMonth: restoredSummary.month)) ?? []
                errorMessage = nil
                loadDashboardNudge()
            } else {
                activeNudge = nil
                errorMessage = "We restored your data, but could not rebuild the dashboard."
            }

            didCompleteInitialDashboardLoad = true
        } catch {
            isRestoringFinancialData = false
            activeNudge = nil
            didCompleteInitialDashboardLoad = true
            errorMessage = "Could not restore your financial data. \(String(describing: error))"
        }
    }

    @MainActor
    private func loadDashboardNudge() {
        let context = DashboardNudgeContext(
            isSignedIn: isUserSignedIn(),
            hasAnyGoal: hasAnyGoal(),
            hasNotificationPermission: hasNotificationPermission(),
            hasSMSPermission: hasSMSPermission()
        )

        activeNudge = nudgeStore.nextEligibleNudge(context: context)
    }

    private func isUserSignedIn() -> Bool {
        guard supabase.auth.currentSession != nil else { return false }
        guard let profile = sessionVM.profile else { return false }
        return profile.onboardingCompleted == true
            && !(profile.fullName ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func hasAnyGoal() -> Bool {
        !appVM.moneyMap.goals.isEmpty
    }

    private func hasNotificationPermission() -> Bool {
        UserDefaults.standard.bool(forKey: DashboardNudgeKeys.notificationPermissionGranted)
    }

    private func hasSMSPermission() -> Bool {
        UserDefaults.standard.bool(forKey: DashboardNudgeKeys.smsPermissionConnected)
    }

    @MainActor
    private func dismissNudge(_ id: DashboardNudgeID) {
        nudgeStore.dismiss(id)
        activeNudge = nil
    }

    @MainActor
    private func handleNudgeAction(_ id: DashboardNudgeID) {
        switch id {
        case .signUp:
            showSignUp = true

        case .goalSetting:
            NotificationCenter.default.post(name: .moneOpenGoalSetup, object: nil)

        case .notifications:
            requestNotificationPermission()

        case .smsPermission:
            showSMSInfoSheet = true
        }
    }

    @MainActor
    private func requestNotificationPermission() {
        Task {
            let granted = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])

            await MainActor.run {
                if granted == true {
                    UserDefaults.standard.set(true, forKey: DashboardNudgeKeys.notificationPermissionGranted)
                    dismissNudge(.notifications)
                }
            }
        }
    }

}

// MARK: - Shared Dashboard Header

struct DashboardHeader: View {
    @Environment(AppViewModel.self) private var appVM
    let title: String
    var subtitle: String? = nil
    var tag: String? = nil
    var labelColor: Color = .moneTertiary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Text("moné")
                        .font(.system(size: 11, weight: .bold, design: .serif).italic())
                        .tracking(0)
                        .foregroundStyle(labelColor)

                    if let tag {
                        Text("·")
                            .font(.moneLabelCaps)
                            .foregroundStyle(labelColor)
                        Text(tag)
                            .font(.moneLabelCaps)
                            .tracking(1.5)
                            .foregroundStyle(labelColor)
                    }
                }

                Spacer()
            }

            Text(title)
                .font(.moneDisplay)
                .foregroundStyle(Color.monePrimary)
                .fixedSize(horizontal: false, vertical: true)

            if let subtitle {
                Text(subtitle)
                    .font(.moneBodySm)
                    .tracking(0.5)
                    .foregroundStyle(Color.moneSecondary)
            }
        }
    }
}

private struct DashboardSectionTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.moneLabelCaps)
                .tracking(2.5)
                .foregroundStyle(Color.moneTertiary)
            Spacer()
        }
        .padding(.top, 12)
        .padding(.bottom, -20)
    }
}

// MARK: - Cards

private struct HealthStateCard: View {
    let summary: DashboardSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Financial health status".uppercased())
                    .font(.moneLabelCaps)
                    .tracking(2.5)
                    .foregroundStyle(Color.moneTertiary)

                Spacer()

                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
            }

            Text(summary.healthMessage)
                .font(.moneHLMd)
                .foregroundStyle(Color.monePrimary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                DashboardChip(title: "CONFIDENCE", value: "\(summary.confidence)%")
                DashboardChip(title: "REVIEW", value: "\(summary.reviewCount)")
                DashboardChip(title: "MONTHLY CASH IMPACT", value: formatCurrency(summary.liquidCashImpact))
            }
        }
        .padding(20)
        .background(Color.moneSurfaceEl)
        .padding(.horizontal, -MoneSpacing.page)
        .overlay(
            Rectangle()
                .strokeBorder(Color.moneStrokeMid, lineWidth: 0.5)
                .padding(.horizontal, -MoneSpacing.page)
        )
    }

    private var statusColor: Color {
        switch summary.healthState {
        case .healthy:
            return Color.moneHealthy
        case .watch:
            return .orange
        case .risk:
            return Color.moneRisk
        }
    }

    private var statusIcon: String {
        switch summary.healthState {
        case .healthy:
            return "checkmark.circle"
        case .watch:
            return "waveform.path.ecg"
        case .risk:
            return "exclamationmark.triangle"
        }
    }
}

private struct DashboardFooterItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
}

private struct AgendaMetricCard: View {
    let label: String
    let value: String
    let status: String
    let description: String
    let footerItems: [DashboardFooterItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                Text(label.uppercased())
                    .font(.moneLabelCaps)
                    .foregroundStyle(Color.moneSecondary)

                Spacer()

                Text(status)
                    .font(.moneLabelCaps)
                    .foregroundStyle(Color.moneHealthy)
            }

            Text(value)
                .font(.system(size: 42, weight: .regular, design: .serif))
                .foregroundStyle(Color.monePrimary)

            Text(description)
                .font(.moneBodyMd)
                .foregroundStyle(Color.moneSecondary)

            HStack {
                ForEach(footerItems) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title.uppercased())
                            .font(.moneLabelCaps)
                            .tracking(1.5)
                            .foregroundStyle(Color.moneTertiary)

                        Text(item.value)
                            .font(.moneBodySm)
                            .foregroundStyle(Color.monePrimary)
                    }

                    Spacer()
                }
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, MoneSpacing.page)
        .background(Color.moneSurfaceEl)
        .padding(.horizontal, -MoneSpacing.page)
    }
}

private struct MoneySplitCard: View {
    let summary: DashboardSummary

    private var fixedCosts: Double { summary.committed + summary.liability + summary.taxDeduction }
    private var isShortfall: Bool  { summary.operatingRemaining < 0 }
    private var isHighOutliers: Bool { summary.income > 0 && summary.outliers / summary.income > 0.12 }

    private var variantLabel: String {
        if isShortfall    { return "Funding shortfall" }
        if isHighOutliers { return "High outliers" }
        return "Balanced distribution"
    }

    private var variantColor: Color {
        isShortfall || isHighOutliers ? Color.moneRisk : Color.moneSecondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(variantLabel.uppercased())
                .font(.moneLabelCaps)
                .foregroundStyle(variantColor)

            MoneySplitBar(summary: summary)

            if isShortfall {
                shortfallContent
            } else if isHighOutliers {
                outliersContent
            } else {
                balancedContent
            }
        }
        .dashboardCard()
    }

    private var balancedContent: some View {
        VStack(spacing: 0) {
            splitRow("Fixed costs",   fixedCosts,      isLast: false)
            splitRow("Discretionary", summary.everyday, isLast: false)
            splitRow("Wealth build",  summary.fund,     isLast: true)
        }
    }

    private var outliersContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Outliers")
                    .font(.moneBodyMd)
                    .foregroundStyle(Color.moneRisk)
                Spacer()
                Text("+\(formatCurrency(summary.outliers))")
                    .font(.moneAmtSm)
                    .foregroundStyle(Color.moneRisk)
            }
            .padding(.vertical, 14)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.moneStroke.opacity(0.5)).frame(height: 0.5)
            }

            splitRow("Fixed costs",  fixedCosts,   dimmed: true, isLast: false)
            splitRow("Wealth build", summary.fund, dimmed: true, isLast: true)
        }
    }

    private var shortfallContent: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 14))
                .foregroundStyle(Color.moneRisk)
                .padding(.top, 1)

            Text("Income this period does not cover scheduled outflows. Pulling \(formatCurrency(abs(summary.operatingRemaining))) from reserve.")
                .font(.moneBodySm)
                .foregroundStyle(Color.moneRisk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color.moneRisk.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func splitRow(
        _ title: String,
        _ value: Double,
        dimmed: Bool = false,
        isLast: Bool
    ) -> some View {
        HStack {
            Text(title)
                .font(.moneBodyMd)
                .foregroundStyle(dimmed ? Color.moneTertiary : Color.monePrimary)
            Spacer()
            Text(formatCurrency(value))
                .font(.moneAmtSm)
                .foregroundStyle(dimmed ? Color.moneTertiary : Color.monePrimary)
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(Color.moneStroke.opacity(0.5)).frame(height: 0.5)
            }
        }
    }
}

private struct MoneySplitBar: View {
    let summary: DashboardSummary

    private var total: Double {
        max(
            summary.committed + summary.everyday + summary.fund +
            summary.liability + summary.outliers + summary.review +
            max(summary.operatingRemaining, 0),
            1
        )
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                segment(summary.committed,                  geometry.size.width, Color.monePrimary)
                segment(summary.everyday,                   geometry.size.width, Color.moneSecondary)
                segment(summary.fund,                       geometry.size.width, Color.moneHealthy)
                segment(summary.liability,                  geometry.size.width, .blue)
                segment(summary.outliers,                   geometry.size.width, Color.moneRisk)
                segment(summary.review,                     geometry.size.width, .orange)
                segment(max(summary.operatingRemaining, 0), geometry.size.width, Color.moneTertiary.opacity(0.35))
            }
            .clipShape(Capsule())
        }
        .frame(height: 14)
    }

    private func segment(_ value: Double, _ width: Double, _ color: Color) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: max(width * value / total, value > 0 ? 3 : 0))
    }
}

private struct TaxDeductionCard: View {
    let summary: DashboardSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tax")
                        .font(.moneLabelCaps)
                        .foregroundStyle(.purple)

                    Text(formatCurrency(summary.taxDeduction))
                        .font(.system(size: 34, weight: .regular, design: .serif))
                        .foregroundStyle(Color.monePrimary)
                }

                Spacer()

                Text("CASH DEDUCTION")
                    .font(.moneLabelCaps)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.12))
                    .foregroundStyle(.purple)
                    .clipShape(Capsule())
            }

            Text(taxMessage)
                .font(.moneBodySm)
                .foregroundStyle(Color.moneSecondary)
        }
        .dashboardCard()
    }

    private var taxMessage: String {
        if summary.taxDeduction == 0 {
            return "No tax or statutory cash deduction detected for this month."
        }

        return "This reduces liquid cash this month, but it is not counted as a regular commitment or liability."
    }
}

private struct SpendVelocityCard: View {
    let summary: DashboardSummary
    let velocity: VelocityData?

    private var displayAvg: Double {
        velocity?.currentAvg ?? summary.dailySpendVelocity
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(formatCurrency(displayAvg))
                        .font(.moneAmtMd)
                        .foregroundStyle(displayAvg > summary.income / 25 ? Color.moneRisk : Color.monePrimary)
                    Text("/ day")
                        .font(.moneBodySm)
                        .foregroundStyle(Color.moneSecondary)
                }
                Spacer()
                if let velocity {
                    HStack(spacing: 12) {
                        legendDot(Color.monePrimary, monthName(velocity.currentMonth))
                        legendDot(Color.moneSecondary.opacity(0.6), monthName(velocity.previousMonth))
                    }
                }
            }

            if let velocity {
                VelocityLineChart(velocity: velocity)
                    .frame(height: 160)
            } else {
                Rectangle()
                    .fill(Color.moneSurfaceEl)
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        Text("No transaction data yet")
                            .font(.moneBodySm)
                            .foregroundStyle(Color.moneTertiary)
                    )
            }

            Text(velocityMessage)

                .font(.moneBodySm)
                .foregroundStyle(Color.moneSecondary)
        }
        .dashboardCard()
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
                .font(.moneLabelCaps)
                .foregroundStyle(Color.moneTertiary)
        }
    }

    private func monthName(_ monthKey: String) -> String {
        // monthKey format: "yyyy-MM"
        guard monthKey.count == 7, let month = Int(monthKey.suffix(2)) else { return monthKey }
        let names = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
        guard month >= 1 && month <= 12 else { return monthKey }
        return names[month - 1].uppercased()
    }


    private var velocityMessage: String {
        guard let velocity else {
            return "Spending pace is within a manageable range for this month."
        }
        if velocity.currentAvg > velocity.previousAvg * 1.2 {
            return "Spending pace is running \(Int(((velocity.currentAvg / max(velocity.previousAvg, 1)) - 1) * 100))% higher than last month."
        }
        if velocity.currentAvg < velocity.previousAvg * 0.85 {
            return "Spending pace is tracking lower than last month."
        }
        return "Spending pace is broadly in line with last month."
    }
}

private struct VelocityLineChart: View {
    let velocity: VelocityData
    @State private var scrubDay: Int? = nil
    @State private var scrubLocation: CGFloat = 0

    private var currentPoints: [(day: Int, amount: Double)] {
        velocity.current.map { ($0.key, $0.value) }.sorted { $0.day < $1.day }
    }
    private var previousPoints: [(day: Int, amount: Double)] {
        velocity.previous.map { ($0.key, $0.value) }.sorted { $0.day < $1.day }
    }
    private var currentHigherAvg: Bool { velocity.currentAvg >= velocity.previousAvg }

    // All days across both series to define X domain
    private var allDays: [Int] {
        Array(Set(currentPoints.map(\.day) + previousPoints.map(\.day))).sorted()
    }
    private var xMax: Int { allDays.last ?? 31 }

    var body: some View {
        Chart {
            // Area fill under current month
            ForEach(currentPoints, id: \.day) { point in
                AreaMark(
                    x: .value("Day", point.day),
                    yStart: .value("Base", 0),
                    yEnd: .value("Spend", point.amount),
                    series: .value("Series", "current-area")
                )
                .foregroundStyle(LinearGradient(
                    colors: [Color.monePrimary.opacity(0.10), Color.clear],
                    startPoint: .top, endPoint: .bottom
                ))
                .interpolationMethod(.catmullRom)
            }

            // Previous month line
            ForEach(previousPoints, id: \.day) { point in
                LineMark(
                    x: .value("Day", point.day),
                    y: .value("Spend", point.amount),
                    series: .value("Series", "previous")
                )
                .foregroundStyle(Color.moneSecondary.opacity(0.4))
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            }

            // Current month line
            ForEach(currentPoints, id: \.day) { point in
                LineMark(
                    x: .value("Day", point.day),
                    y: .value("Spend", point.amount),
                    series: .value("Series", "current")
                )
                .foregroundStyle(Color.monePrimary)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }

            // Average line — current month (solid)
            if velocity.currentAvg > 0 {
                RuleMark(y: .value("Avg", velocity.currentAvg))
                    .foregroundStyle(Color.monePrimary.opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .annotation(
                        position: currentHigherAvg ? .top : .bottom,
                        alignment: .trailing
                    ) {
                        Text(formatCurrency(velocity.currentAvg))
                            .font(.moneLabelCaps)
                            .foregroundStyle(Color.monePrimary)
                            .padding(.horizontal, 4).padding(.vertical, 2)
                            .background(Color.moneBackground.opacity(0.85))
                    }
            }

            // Average line — previous month (dotted)
            if velocity.previousAvg > 0 {
                RuleMark(y: .value("Avg", velocity.previousAvg))
                    .foregroundStyle(Color.moneSecondary.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    .annotation(
                        position: currentHigherAvg ? .bottom : .top,
                        alignment: .trailing
                    ) {
                        Text(formatCurrency(velocity.previousAvg))
                            .font(.moneLabelCaps)
                            .foregroundStyle(Color.moneSecondary)
                            .padding(.horizontal, 4).padding(.vertical, 2)
                            .background(Color.moneBackground.opacity(0.85))
                    }
            }

            // X-axis baseline
            RuleMark(y: .value("Zero", 0))
                .foregroundStyle(Color.moneSecondary.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 0.75))

            // Dot at the end of the current month line
            if let lastPoint = currentPoints.last {
                PointMark(
                    x: .value("Day", lastPoint.day),
                    y: .value("Spend", lastPoint.amount)
                )
                .foregroundStyle(Color.monePrimary)
                .symbolSize(30)
            }

            // Scrub rule — only the vertical line and dot, no annotation here
            if let day = scrubDay {
                RuleMark(x: .value("Day", day))
                    .foregroundStyle(Color.monePrimary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1))

                if let currentVal = velocity.current[day] {
                    PointMark(
                        x: .value("Day", day),
                        y: .value("Spend", currentVal)
                    )
                    .foregroundStyle(Color.monePrimary)
                    .symbolSize(40)
                }
            }
        }
        .chartYScale(domain: 0...velocity.yMax)
        .chartXScale(domain: 1...xMax)
        .chartXAxis {
            AxisMarks(values: .stride(by: 5)) { value in
                AxisValueLabel {
                    if let day = value.as(Int.self) {
                        Text("\(day)")
                            .font(.moneLabelCaps)
                            .foregroundStyle(Color.moneTertiary)
                    }
                }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.moneStroke.opacity(0.3))
            }
        }
        .chartYAxis(.hidden)
        .chartPlotStyle { plot in plot.background(Color.clear) }
        .chartOverlay { proxy in
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    // Invisible drag target
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let plotOriginX = geo[proxy.plotFrame!].origin.x
                                    let x = value.location.x - plotOriginX
                                    if let day: Int = proxy.value(atX: x) {
                                        scrubDay = max(1, min(day, xMax))
                                        scrubLocation = value.location.x
                                    }
                                }
                                .onEnded { _ in scrubDay = nil }
                        )

                    // Floating callout — positioned left or right of scrub line
                    if let day = scrubDay {
                        let calloutWidth: CGFloat = 130
                        let plotWidth = geo[proxy.plotFrame!].width
                        let plotOriginX = geo[proxy.plotFrame!].origin.x
                        let isLeftHalf = scrubLocation < (plotOriginX + plotWidth / 2)
                        let calloutX = isLeftHalf
                            ? scrubLocation + 10
                            : scrubLocation - calloutWidth - 10

                        scrubCallout(
                            day: day,
                            current: velocity.current[day],
                            previous: velocity.previous[day]
                        )
                        .frame(width: calloutWidth)
                        .offset(x: calloutX, y: 4)
                        .allowsHitTesting(false)
                    }
                }
            }
        }
    }

    private func scrubCallout(day: Int, current: Double?, previous: Double?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Day \(day)")
                .font(.moneLabelCaps)
                .foregroundStyle(Color.moneTertiary)
            if let current {
                HStack(spacing: 6) {
                    Circle().fill(Color.monePrimary).frame(width: 6, height: 6)
                    Text(formatCurrency(current))
                        .font(.moneBodySm.weight(.semibold))
                        .foregroundStyle(Color.monePrimary)
                }
            }
            if let previous {
                HStack(spacing: 6) {
                    Circle().fill(Color.moneSecondary.opacity(0.5)).frame(width: 6, height: 6)
                    Text(formatCurrency(previous))
                        .font(.moneBodySm)
                        .foregroundStyle(Color.moneSecondary)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.moneSurface)
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
        )
    }
}

private struct FundBuildingCard: View {
    let summary: DashboardSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fund-building")
                        .font(.moneLabelCaps)
                        .foregroundStyle(Color.moneSecondary)

                    Text("\(Int(summary.savingsRatio * 100))% of income")
                        .font(.moneHLMd)
                        .foregroundStyle(Color.monePrimary)
                }

                Spacer()

                Image(systemName: "shield")
                    .foregroundStyle(summary.savingsRatio >= 0.15 ? Color.moneHealthy : .orange)
            }

            ProgressView(value: min(summary.savingsRatio / 0.2, 1))
                .tint(summary.savingsRatio >= 0.15 ? Color.moneHealthy : .orange)

            Text("Detected fund-building this month: \(formatCurrency(summary.fund)).")
                .font(.moneBodySm)
                .foregroundStyle(Color.moneSecondary)
        }
        .dashboardCard()
    }
}

private struct DebtAndLiabilityCard: View {
    let summary: DashboardSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Debt & liabilities")
                .font(.moneLabelCaps)
                .foregroundStyle(Color.moneSecondary)

            HStack(alignment: .bottom) {
                Text(formatCurrency(summary.liability))
                    .font(.system(size: 34, weight: .regular, design: .serif))
                    .foregroundStyle(Color.monePrimary)

                Spacer()

                Text(liabilityStatus)
                    .font(.moneLabelCaps)
                    .foregroundStyle(summary.liability > summary.income * 0.35 ? Color.moneRisk : Color.moneHealthy)
            }

            Text("Loan, credit-card, and debt-related outflows detected in the selected month.")
                .font(.moneBodySm)
                .foregroundStyle(Color.moneSecondary)
        }
        .dashboardCard()
    }

    private var liabilityStatus: String {
        guard summary.income > 0 else { return "NO INCOME" }
        return summary.liability > summary.income * 0.35 ? "HIGH PRESSURE" : "MANAGEABLE"
    }
}

private struct SubscriptionLoadCard: View {
    let summary: DashboardSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(subscriptionTitle)
                        .font(.moneLabelCaps)
                        .foregroundStyle(statusColor)

                    Text(formatCurrency(summary.subscriptionAmount))
                        .font(.system(size: 34, weight: .regular, design: .serif))
                        .foregroundStyle(Color.monePrimary)
                }

                Spacer()

                Text("\(summary.subscriptionCount) active")
                    .font(.moneLabelCaps)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(statusColor.opacity(0.12))
                    .foregroundStyle(statusColor)
                    .clipShape(Capsule())
            }

            if summary.subscriptionNames.isEmpty {
                Text("No meaningful subscription load detected for this month.")
                    .font(.moneBodySm)
                    .foregroundStyle(Color.moneSecondary)
            } else {
                HorizontalTags(items: summary.subscriptionNames)
            }

            Text(subscriptionMessage)
                .font(.moneBodySm)
                .foregroundStyle(Color.moneSecondary)
        }
        .dashboardCard()
    }

    private var subscriptionTitle: String {
        if summary.subscriptionAmount == 0 {
            return "Recurring load"
        }

        if summary.subscriptionAmount > summary.income * 0.08 {
            return "Recurring bloat"
        }

        return "Recurring load"
    }

    private var subscriptionMessage: String {
        if summary.subscriptionAmount == 0 {
            return "Moné did not detect recurring subscription pressure this month."
        }

        if summary.subscriptionAmount > summary.income * 0.08 {
            return "Subscriptions are taking a noticeable share of this month’s inflow."
        }

        return "Subscription load looks manageable relative to your monthly inflow."
    }

    private var statusColor: Color {
        if summary.subscriptionAmount == 0 {
            return Color.moneSecondary
        }

        if summary.subscriptionAmount > summary.income * 0.08 {
            return Color.moneRisk
        }

        return Color.moneHealthy
    }
}

private struct NetWorthStratificationCard: View {
    let summary: DashboardSummary
    let netWorth: NetWorthData?

    private let investmentColor = Color.purple.opacity(0.6)

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            heroSection
            stratificationBar
            Divider().background(Color.moneStroke)
            indexSection
            Divider().background(Color.moneStroke)
            gapsSection
        }
        .dashboardCard()
    }

    // MARK: Hero

    private var heroSection: some View {
        Text(formatCurrency(netWorth?.netWorth ?? summary.totalNetWorth))
            .font(.moneAmtLg)
            .foregroundStyle(Color.monePrimary)
            .minimumScaleFactor(0.7)
    }

    // MARK: Bar

    @ViewBuilder
    private var stratificationBar: some View {
        if let nw = netWorth {
            let denom = max(nw.grossAssets, 1)
            GeometryReader { geo in
                HStack(spacing: 2) {
                    barSeg(nw.liquid,         geo.size.width, denom, Color.moneHealthy)
                    barSeg(nw.lockedDeposits, geo.size.width, denom, Color.monePrimary)
                    barSeg(nw.investments,    geo.size.width, denom, investmentColor)
                }
                .clipShape(Capsule())
            }
            .frame(height: 10)
        } else {
            Rectangle()
                .fill(Color.moneStroke.opacity(0.3))
                .frame(height: 10)
                .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private func barSeg(_ value: Double, _ width: CGFloat, _ denom: Double, _ color: Color) -> some View {
        let f = CGFloat(value / denom)
        if f > 0 {
            Rectangle()
                .fill(color)
                .frame(width: max(width * f, 2))
        }
    }

    // MARK: Index

    private var indexSection: some View {
        VStack(spacing: 0) {
            if let nw = netWorth {
                let gross = max(nw.grossAssets, 1)
                let rows: [(String, Double, Color)] = [
                    ("Liquid",         nw.liquid,         Color.moneHealthy),
                    ("Fixed deposits", nw.lockedDeposits, Color.monePrimary),
                    ("Investments",    nw.investments,    investmentColor)
                ].filter { $0.1 > 0 }

                ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                    if idx > 0 { rowDivider() }
                    indexRow(row.0, row.1, pct: row.1 / gross, color: row.2, negative: false)
                }
            } else {
                HStack {
                    Text("Liquid")
                        .font(.moneBodySm)
                        .foregroundStyle(Color.moneSecondary)
                    Spacer()
                    Text(formatCurrency(summary.liquidNetWorth))
                        .font(.moneAmtSm)
                        .foregroundStyle(Color.monePrimary)
                }
                .padding(.vertical, 12)
            }
        }
    }

    private func indexRow(
        _ label: String,
        _ value: Double,
        pct: Double,
        color: Color,
        negative: Bool
    ) -> some View {
        HStack(spacing: 10) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.moneBodySm)
                .foregroundStyle(Color.moneSecondary)
            Spacer()
            Text(negative ? "-\(formatCurrency(value))" : formatCurrency(value))
                .font(.moneAmtSm)
                .foregroundStyle(negative ? Color.moneRisk : Color.monePrimary)
            Text("\(Int((pct * 100).rounded()))%")
                .font(.moneLabelCaps)
                .foregroundStyle(Color.moneTertiary)
                .frame(width: 38, alignment: .trailing)
        }
        .padding(.vertical, 12)
    }

    private func rowDivider() -> some View {
        Rectangle().fill(Color.moneStroke.opacity(0.5)).frame(height: 0.5)
    }

    // MARK: Gaps

    private var gapsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("GAPS & ALERTS")
                .moneLabelCaps(color: Color.moneTertiary)

            if let nw = netWorth {
                let monthlyExpense = summary.committed + summary.everyday + summary.liability
                let efMonths = nw.emergencyFundMonths(monthlyExpense: monthlyExpense)
                let gaps = buildGaps(nw: nw, efMonths: efMonths)

                if gaps.isEmpty {
                    gapRow(
                        icon: "checkmark.circle.fill",
                        color: Color.moneHealthy,
                        label: "Net worth composition looks healthy.",
                        detail: nil
                    )
                } else {
                    ForEach(gaps, id: \.label) { gap in
                        gapRow(icon: gap.icon, color: gap.color, label: gap.label, detail: gap.detail)
                    }
                }
            } else {
                gapRow(
                    icon: "info.circle",
                    color: Color.moneSecondary,
                    label: "Net worth detail not available.",
                    detail: nil
                )
            }
        }
    }

    private struct GapItem {
        let icon: String
        let color: Color
        let label: String
        let detail: String?
    }

    private func buildGaps(nw: NetWorthData, efMonths: Double) -> [GapItem] {
        var items: [GapItem] = []

        // 1. Liability — biggest net-worth red flag
        if summary.liability > 0 {
            let annualDebt = summary.liability * 12
            let isHeavy = nw.grossAssets > 0 && annualDebt / nw.grossAssets > 0.4
            items.append(GapItem(
                icon: isHeavy ? "exclamationmark.triangle.fill" : "info.circle",
                color: isHeavy ? Color.moneRisk : Color.moneWatch,
                label: "Monthly debt obligation: \(formatCurrency(summary.liability)).",
                detail: isHeavy ? "Annual debt payments exceed 40% of your gross asset base." : nil
            ))
        }

        // 2. Emergency fund
        if nw.liquid == 0 {
            items.append(GapItem(
                icon: "exclamationmark.triangle.fill",
                color: Color.moneRisk,
                label: "No liquid savings detected.",
                detail: "Link a savings or current account to see your liquid balance."
            ))
        } else if efMonths < 3 {
            items.append(GapItem(
                icon: "exclamationmark.triangle.fill",
                color: Color.moneRisk,
                label: "Emergency fund is \(String(format: "%.1f", efMonths)) months.",
                detail: "Target: 3× monthly expenses."
            ))
        } else if efMonths < 6 {
            items.append(GapItem(
                icon: "exclamationmark.triangle.fill",
                color: Color.moneWatch,
                label: "Emergency buffer is adequate but not optimal.",
                detail: "Currently \(String(format: "%.1f", efMonths))× of 6× target."
            ))
        }

        // 3. Investments
        if nw.investments == 0 {
            items.append(GapItem(
                icon: "exclamationmark.triangle.fill",
                color: Color.moneRisk,
                label: "No wealth-building investments detected.",
                detail: nil
            ))
        } else if !nw.investmentIsRegular {
            items.append(GapItem(
                icon: "exclamationmark.triangle.fill",
                color: Color.moneWatch,
                label: "Investment contributions have been irregular in recent months.",
                detail: nil
            ))
        }

        // 4. Liquidity ratio
        if nw.liquidityRatio < 0.1 && nw.grossAssets > 0 {
            items.append(GapItem(
                icon: "exclamationmark.triangle.fill",
                color: Color.moneWatch,
                label: "Most assets are locked.",
                detail: "Limited liquid access in case of emergency."
            ))
        }

        // 5. Fixed deposits — informational
        if nw.lockedDeposits == 0 {
            items.append(GapItem(
                icon: "info.circle",
                color: Color.moneSecondary,
                label: "No fixed or recurring deposits linked.",
                detail: nil
            ))
        }

        // 6. NPS — informational
        items.append(GapItem(
            icon: "info.circle",
            color: Color.moneSecondary,
            label: "NPS not linked.",
            detail: "Consider for long-term retirement corpus."
        ))

        return items
    }

    private func gapRow(icon: String, color: Color, label: String, detail: String?) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.moneBodySm.weight(.semibold))
                    .foregroundStyle(Color.monePrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if let detail {
                    Text(detail)
                        .font(.moneBodySm)
                        .foregroundStyle(Color.moneSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct ForecastConfidenceCard: View {
    let summary: DashboardSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Forecast confidence")
                    .font(.moneLabelCaps)
                    .foregroundStyle(summary.confidence >= 75 ? Color.moneSecondary : .orange)

                Spacer()

                Text("\(summary.confidence)%")
                    .font(.moneAmtSm)
                    .foregroundStyle(summary.confidence >= 75 ? Color.monePrimary : .orange)
            }

            ProgressView(value: Double(summary.confidence) / 100)
                .tint(summary.confidence >= 75 ? Color.moneHealthy : .orange)

            Text(confidenceMessage)
                .font(.moneBodySm)
                .foregroundStyle(Color.moneSecondary)
        }
        .dashboardCard()
    }

    private var confidenceMessage: String {
        if summary.reviewCount == 0 {
            return "No high-impact review items remain for this month."
        }

        return "\(summary.reviewCount) transaction(s) may need review to stabilise this month’s MoneyMap."
    }
}

private struct NextBestActionsCard: View {
    let summary: DashboardSummary
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        @Bindable var appVM = appVM
        VStack(alignment: .leading, spacing: 16) {
            ForEach(actions, id: \.title) { action in
                Button {
                    navigate(for: action.deepLink)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(action.priority.uppercased())
                                .font(.moneLabelCaps)
                                .foregroundStyle(action.color)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Color.moneTertiary)
                        }

                        Text(action.title)
                            .font(.moneHLMd)
                            .foregroundStyle(Color.monePrimary)

                        Text(action.description)
                            .font(.moneBodySm)
                            .foregroundStyle(Color.moneSecondary)
                    }
                }
                .buttonStyle(.plain)

                if action.title != actions.last?.title {
                    Divider()
                        .background(Color.moneStroke)
                }
            }
        }
        .dashboardCard()
    }

    private func navigate(for deepLink: ActionDeepLink) {
        switch deepLink {
        case .goals:
            appVM.selectedTab = .goals
        case .moneyMapReview:
            appVM.moneyMapDeepLink = .openReviewTransactions
            appVM.selectedTab = .moneyMap
        case .moneyMapSubscriptions:
            appVM.moneyMapDeepLink = .openSubscriptionCard
            appVM.selectedTab = .moneyMap
        }
    }

    enum ActionDeepLink {
        case goals
        case moneyMapReview
        case moneyMapSubscriptions
    }

    private var actions: [(priority: String, title: String, description: String, color: Color, deepLink: ActionDeepLink)] {
        if summary.taxDeduction > 0, summary.liquidCashImpact < 0 {
            return [
                (
                    "Priority: High",
                    "Plan for statutory cash impact",
                    "Tax reduced this month’s liquid cash by \(formatCurrency(summary.taxDeduction)). Keep this separate from regular commitments.",
                    .purple,
                    .goals
                ),
                (
                    "Priority: Medium",
                    "Review safe-to-spend",
                    "Flexible spending should stay within \(formatCurrency(summary.safeToSpend)) until the next inflow cycle.",
                    Color.moneSecondary,
                    .goals
                )
            ]
        }

        if summary.reviewCount > 0 {
            return [
                (
                    "Priority: High",
                    "Review unclear transactions",
                    "\(summary.reviewCount) item(s) are still affecting forecast confidence.",
                    .orange,
                    .moneyMapReview
                ),
                (
                    "Priority: Medium",
                    "Use safe-to-spend as your guide",
                    "Keep flexible spending within \(formatCurrency(summary.safeToSpend)) for this cycle.",
                    Color.moneSecondary,
                    .goals
                )
            ]
        }

        if summary.operatingRemaining < 0 {
            return [
                (
                    "Priority: Critical",
                    "Reduce flexible spends",
                    "This operating month is overfunded by \(formatCurrency(abs(summary.operatingRemaining))).",
                    Color.moneRisk,
                    .goals
                )
            ]
        }

        if summary.subscriptionAmount > summary.income * 0.08 {
            return [
                (
                    "Priority: Medium",
                    "Audit subscriptions",
                    "Recurring subscriptions are taking a noticeable share of monthly inflow.",
                    .orange,
                    .moneyMapSubscriptions
                ),
                (
                    "Priority: Low",
                    "Move surplus deliberately",
                    "Consider assigning \(formatCurrency(summary.operatingRemaining)) to buffer, investments, or upcoming obligations.",
                    Color.moneSecondary,
                    .goals
                )
            ]
        }

        return [
            (
                "Priority: Low",
                "Maintain current rhythm",
                "Your MoneyMap is stable for this month.",
                Color.moneHealthy,
                .goals
            ),
            (
                "Priority: Low",
                "Move surplus deliberately",
                "Consider assigning \(formatCurrency(summary.operatingRemaining)) to buffer, investments, or upcoming obligations.",
                Color.moneSecondary,
                .goals
            )
        ]
    }
}

// MARK: - Small components

private struct DashboardChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.moneLabelCaps)
                .foregroundStyle(Color.moneTertiary)

            Text(value)
                .font(.moneBodySm)
                .foregroundStyle(Color.monePrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.moneStroke.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct DashboardAmountRow: View {
    let title: String
    let value: Double

    var body: some View {
        HStack {
            Text(title)
                .font(.moneBodyMd)
                .foregroundStyle(Color.moneSecondary)

            Spacer()

            Text(formatCurrency(value))
                .font(.moneBodyMd)
                .foregroundStyle(value < 0 ? Color.moneRisk : Color.monePrimary)
        }
    }
}

private struct HorizontalTags: View {
    let items: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    Text(item.uppercased())
                        .font(.moneLabelCaps)
                        .lineLimit(1)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Color.moneStroke.opacity(0.25))
                        .foregroundStyle(Color.moneSecondary)
                        .clipShape(Capsule())
                }
            }
        }
    }
}

// MARK: - Helpers

private extension View {
    func dashboardCard() -> some View {
        self
            .padding(20)
            .background(Color.moneSurfaceEl)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.moneStrokeMid, lineWidth: 0.5)
            )
    }
}

// MARK: - Safe-to-Spend Split Card

private struct SafeToSpendSplitCard: View {
    let summary: DashboardSummary

    // Buckets from actual transaction data
    private var income: Double       { summary.income }
    private var obligations: Double  { summary.committed + summary.liability }
    private var investments: Double  { summary.fund }
    private var everyday: Double     { summary.everyday }
    private var cashReview: Double   { summary.review }
    private var outliers: Double     { summary.outliers }

    // Tax is excluded from the numerator — income is treated as net of statutory deductions
    // remaining = unallocated cash after all tracked outflows
    private var remaining: Double { income - obligations - investments - everyday - cashReview - outliers }

    // STS formula: (investments + max(remaining,0)) vs 40% wealth target
    private var wealthTarget: Double  { income * 0.40 }
    private var wealthActual: Double  { investments + max(remaining, 0) }
    private var safeToSpend: Double   { wealthActual - wealthTarget }
    private var isNegative: Bool      { safeToSpend < 0 }
    // State 2: STS deficit but no cash overdraft — spending into the savings pool
    private var isConsumingSavingsPool: Bool { isNegative && remaining >= 0 }
    // State 3: actual cash overdraft — spent more than income
    private var isCashOverdraft: Bool  { isNegative && remaining < 0 }

    // Bar denominator expands if spending overflows income
    private var barTotal: Double {
        isNegative ? income + abs(min(remaining, 0)) : max(income, 1)
    }

    private func frac(_ v: Double) -> Double { max(v / barTotal, 0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            heroSection
            distributionBar
            Divider().background(Color.moneStroke)
            indexSection
        }
        .dashboardCard()
    }

    // MARK: Hero

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(isNegative ? "EXCESS EXPENDITURE THIS MONTH" : "SAFE TO SPEND THIS MONTH")
                .moneLabelCaps()

            Text(formatCurrency(isCashOverdraft ? abs(remaining) : abs(safeToSpend)))
                .font(.moneAmtLg)
                .foregroundStyle(isNegative ? Color.moneRisk : Color.monePrimary)
                .minimumScaleFactor(0.7)

            if isCashOverdraft {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("You've spent more than you earned this month.")
                        .font(.moneBodySm)
                }
                .foregroundStyle(Color.moneRisk)
                .padding(.top, 2)
            } else if isConsumingSavingsPool {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("You're spending money that should be going into your savings.")
                        .font(.moneBodySm)
                }
                .foregroundStyle(Color.moneWatch)
                .padding(.top, 2)
            } else {
                Text("Surplus above your 40% wealth-building target.")
                    .font(.moneBodySm)
                    .foregroundStyle(Color.moneSecondary)
                    .padding(.top, 2)
            }
        }
    }

    // MARK: Bar

    private var distributionBar: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                barSeg(obligations, geo.size.width, Color.monePrimary)
                barSeg(everyday,    geo.size.width, Color.moneSecondary)
                if outliers > 0 {
                    barSeg(outliers, geo.size.width, Color.moneWatch)
                }
                if cashReview > 0 {
                    barSeg(cashReview, geo.size.width, .orange)
                }
                barSeg(investments, geo.size.width, Color.moneHealthy)
                if isNegative {
                    // Overflow — spending ate into savings
                    barSeg(abs(min(remaining, 0)), geo.size.width, Color.moneRisk)
                } else if remaining > 0 {
                    barSeg(remaining, geo.size.width, Color.moneActionFill.opacity(0.35))
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: 10)
    }

    @ViewBuilder
    private func barSeg(_ value: Double, _ width: CGFloat, _ color: Color) -> some View {
        let f = frac(value)
        if f > 0 {
            Rectangle()
                .fill(color)
                .frame(width: max(width * CGFloat(f), 2))
        }
    }

    // MARK: Index

    private var indexSection: some View {
        VStack(spacing: 0) {
            row("Obligations",    obligations, Color.monePrimary)
            rowDivider()
            row("Everyday spend", everyday,    Color.moneSecondary)
            if outliers > 0 {
                rowDivider()
                row("Large outliers", outliers, Color.moneWatch)
            }
            if cashReview > 0 {
                rowDivider()
                row("Cash & unclear", cashReview, .orange)
            }
            rowDivider()
            row("Investments",    investments, Color.moneHealthy)
            rowDivider()
            if isNegative {
                let excess = abs(min(remaining, 0))
                HStack(spacing: 10) {
                    Circle().fill(Color.moneRisk).frame(width: 8, height: 8)
                    Text("Excess spend")
                        .font(.moneBodySm)
                        .foregroundStyle(Color.moneRisk)
                    Spacer()
                    Text(formatCurrency(excess))
                        .font(.moneAmtSm)
                        .foregroundStyle(Color.moneRisk)
                    Text(pctLabel(excess))
                        .font(.moneLabelCaps)
                        .foregroundStyle(Color.moneRisk)
                        .frame(width: 38, alignment: .trailing)
                }
                .padding(.vertical, 12)
            } else {
                row("Unallocated", max(remaining, 0), Color.moneActionFill)
            }

            // Denominator row — total income from all sources
            Divider().background(Color.moneStroke)
            HStack(spacing: 10) {
                Rectangle()
                    .fill(Color.monePrimary)
                    .frame(width: 8, height: 2)
                Text("Total income")
                    .font(.moneBodySm.weight(.medium))
                    .foregroundStyle(Color.monePrimary)
                Spacer()
                Text(formatCurrency(income))
                    .font(.moneAmtSm)
                    .foregroundStyle(Color.monePrimary)
                Text("100%")
                    .font(.moneLabelCaps)
                    .foregroundStyle(Color.moneTertiary)
                    .frame(width: 38, alignment: .trailing)
            }
            .padding(.vertical, 12)
        }
    }

    private func row(_ label: String, _ value: Double, _ color: Color) -> some View {
        HStack(spacing: 10) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.moneBodySm)
                .foregroundStyle(Color.moneSecondary)
            Spacer()
            Text(formatCurrency(value))
                .font(.moneAmtSm)
                .foregroundStyle(Color.monePrimary)
            Text(pctLabel(value))
                .font(.moneLabelCaps)
                .foregroundStyle(Color.moneTertiary)
                .frame(width: 38, alignment: .trailing)
        }
        .padding(.vertical, 12)
    }

    private func rowDivider() -> some View {
        Rectangle().fill(Color.moneStroke.opacity(0.5)).frame(height: 0.5)
    }

    private func pctLabel(_ value: Double) -> String {
        guard income > 0 else { return "—" }
        return "\(Int((value / income * 100).rounded()))%"
    }
}

private func formatCurrency(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "INR"
    formatter.maximumFractionDigits = 0
    formatter.locale = Locale(identifier: "en_IN")

    return formatter.string(from: NSNumber(value: value)) ?? "₹\(Int(value))"
}

private struct SMSConnectInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.moneBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("SMS signals")
                        .font(.moneHLMd)
                        .foregroundStyle(Color.monePrimary)

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.moneTertiary)
                    }
                    .buttonStyle(.plain)
                }

                Text("Real-time SMS nudges are not available on iPhone yet.")
                    .font(.moneBodyLg)
                    .foregroundStyle(Color.monePrimary)

                Text("iOS does not allow Moné to read your SMS inbox for transaction messages. For now, Moné uses Account Aggregator data, local categorisation, and notifications to keep your Money Map updated.")
                    .font(.moneBodyMd)
                    .foregroundStyle(Color.moneSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 10) {
                    Text("What still works")
                        .font(.moneLabelCaps)
                        .foregroundStyle(Color.moneTertiary)

                    Text("• Account Aggregator refreshes")
                    Text("• AI-assisted transaction categorisation")
                    Text("• Dashboard and Money Map trends")
                    Text("• Notification-based nudges")
                }
                .font(.moneBodySm)
                .foregroundStyle(Color.moneSecondary)

                Spacer()

                MonePrimaryButton(title: "Got it") {
                    dismiss()
                }
            }
            .padding(MoneSpacing.page)
        }
        .presentationBackground(Color.moneBackground)
    }
}

// MARK: - TopSpendingCategoriesCard

private struct CategoryColumnWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct AmountColumnWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct TopSpendingCategoriesCard: View {
    let summary: DashboardSummary
    let categories: [CategorySpendItem]

    private let labelMaxWidth: CGFloat = 120

    @State private var labelColWidth: CGFloat = 0
    @State private var amountColWidth: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if categories.isEmpty {
                Text("No everyday spend data available for this month.")
                    .font(.moneBodySm)
                    .foregroundStyle(Color.moneSecondary)
            } else {
                ForEach(Array(categories.enumerated()), id: \.offset) { idx, cat in
                    HStack(spacing: 10) {
                        Text(cat.displayLabel)
                            .font(.moneBodySm)
                            .foregroundStyle(Color.moneSecondary)
                            .lineLimit(1)
                            .fixedSize()
                            .background(
                                GeometryReader { g in
                                    Color.clear.preference(key: CategoryColumnWidthKey.self,
                                                           value: min(g.size.width, labelMaxWidth))
                                }
                            )
                            .frame(width: labelColWidth, alignment: .leading)
                            .clipped()

                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(Color.monePrimary)
                                .frame(width: geo.size.width * CGFloat(cat.pct), height: 8)
                                .frame(maxHeight: .infinity, alignment: .center)
                        }

                        Text(formatCurrency(cat.amount))
                            .font(.moneAmtSm)
                            .foregroundStyle(Color.monePrimary)
                            .lineLimit(1)
                            .fixedSize()
                            .background(
                                GeometryReader { g in
                                    Color.clear.preference(key: AmountColumnWidthKey.self,
                                                           value: g.size.width)
                                }
                            )
                            .frame(width: amountColWidth, alignment: .trailing)
                    }
                    .frame(height: 20)
                }
            }
        }
        .onPreferenceChange(CategoryColumnWidthKey.self) { labelColWidth = $0 }
        .onPreferenceChange(AmountColumnWidthKey.self) { amountColWidth = $0 }
        .dashboardCard()
    }
}

// MARK: - SavingsTrendCard

private struct SavingsTrendCard: View {
    let summary: DashboardSummary
    let trend: [SavingsTrendPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if trend.isEmpty {
                Text("Not enough monthly data yet.")
                    .font(.moneBodySm)
                    .foregroundStyle(Color.moneSecondary)
            } else {
                Chart {
                    ForEach(Array(trend.enumerated()), id: \.offset) { idx, point in
                        let value = point.liquidDelta ?? point.remaining
                        LineMark(
                            x: .value("Month", idx),
                            y: .value("Amount", value)
                        )
                        .foregroundStyle(Color.monePrimary)
                        .interpolationMethod(.catmullRom)
                    }

                    RuleMark(y: .value("Baseline", 0))
                        .lineStyle(StrokeStyle(lineWidth: 0.75))
                        .foregroundStyle(Color.moneSecondary.opacity(0.3))
                }
                .chartXAxis {
                    AxisMarks(values: Array(trend.indices)) { idx in
                        AxisValueLabel {
                            if let i = idx.as(Int.self), i < trend.count {
                                Text(trend[i].monthLabel)
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color.moneSecondary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                            .foregroundStyle(Color.moneStroke.opacity(0.3))
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(compactLabel(v))
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color.moneSecondary)
                            }
                        }
                    }
                }
                .frame(height: 160)
            }

        }
        .dashboardCard()
    }

    private func compactLabel(_ value: Double) -> String {
        let abs = Swift.abs(value)
        let prefix = value < 0 ? "-" : ""
        if abs >= 100_000 {
            return "\(prefix)₹\(String(format: "%.0f", abs / 100_000))L"
        } else if abs >= 1_000 {
            return "\(prefix)₹\(String(format: "%.0f", abs / 1_000))K"
        }
        return "\(prefix)₹\(String(format: "%.0f", abs))"
    }
}

#Preview {
    DashboardView()
        .environment(AppViewModel())
}
