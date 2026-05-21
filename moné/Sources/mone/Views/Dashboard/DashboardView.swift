import SwiftUI
import SwiftData
import UserNotifications

struct DashboardView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(SessionViewModel.self) private var sessionVM
    @Environment(\.modelContext) private var modelContext

    @State private var summary: DashboardSummary?
    @State private var errorMessage: String?
    @State private var showSignUp = false
    @State private var isRestoringFinancialData = false
    @State private var didCompleteInitialDashboardLoad = false
    
    @State private var activeNudge: DashboardNudge?
    private let nudgeStore = DashboardNudgeStore()
    
    @State private var showSMSInfoSheet = false


    var body: some View {
        ZStack {
            Color.moneBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 36) {
                    if let summary {
                        DashboardHeader(
                            title: dashboardTitle(for: summary),
                            subtitle: sessionVM.isSignedIn
                                ? "\(sessionVM.displayName.capitalized) · \(summary.month)"
                                : summary.month
                        )
                        
                        if let activeNudge {
                            DashboardNudgeCard(
                                nudge: activeNudge,
                                onPrimaryAction: {
                                    handleNudgeAction(activeNudge.id)
                                },
                                onDismiss: {
                                    dismissNudge(activeNudge.id)
                                }
                            )
                        }

                        agendaHero(summary)

                        DashboardSectionTitle("Financial health status")
                        HealthStateCard(summary: summary)

                        DashboardSectionTitle("Monthly money split")
                        MoneySplitCard(summary: summary)

                        DashboardSectionTitle("Tax & statutory deductions")
                        TaxDeductionCard(summary: summary)

                        DashboardSectionTitle("Spend velocity")
                        SpendVelocityCard(summary: summary)

                        DashboardSectionTitle("Fund-building")
                        FundBuildingCard(summary: summary)

                        DashboardSectionTitle("Debt & liabilities")
                        DebtAndLiabilityCard(summary: summary)

                        DashboardSectionTitle("Subscription load")
                        SubscriptionLoadCard(summary: summary)

                        DashboardSectionTitle("Net worth stratification")
                        NetWorthStratificationCard(summary: summary)

                        DashboardSectionTitle("Forecast confidence")
                        ForecastConfidenceCard(summary: summary)

                        DashboardSectionTitle("Next best actions")
                        NextBestActionsCard(summary: summary)
                    } else if isRestoringFinancialData {
                        restoringFinancialDataView
                    } else if let errorMessage {
                        dashboardError(errorMessage)
                    } else {
                        ProgressView()
                            .tint(Color.monePrimary)
                    }
                }
                .padding(MoneSpacing.page)
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
        sessionVM.isSignedIn || supabase.auth.currentSession != nil
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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("moné")
                    .font(.moneLabelCaps)
                    .tracking(3.0)
                    .foregroundStyle(Color.moneTertiary)

                Spacer()

                Circle()
                    .fill(Color.moneHealthy)
                    .frame(width: 6, height: 6)
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
        .padding(.top, 8)
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
                Text(summary.healthState.rawValue.uppercased())
                    .font(.moneLabelCaps)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(statusColor.opacity(0.12))
                    .foregroundStyle(statusColor)
                    .clipShape(Capsule())

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
                DashboardChip(title: "CASH IMPACT", value: formatCurrency(summary.liquidCashImpact))
            }
        }
        .dashboardCard()
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
                    .font(.moneBodyMd)
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
                .font(.moneBodyMd)
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
                    Text("Tax / statutory")
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

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Spend velocity")
                    .font(.moneLabelCaps)
                    .foregroundStyle(Color.moneSecondary)

                Spacer()

                Text("\(formatCurrency(summary.dailySpendVelocity)) / day")
                    .font(.moneBodyMd)
                    .foregroundStyle(summary.dailySpendVelocity > summary.income / 25 ? Color.moneRisk : Color.monePrimary)
            }

            VelocityBars(value: summary.dailySpendVelocity)

            Text(velocityMessage)
                .font(.moneBodySm)
                .foregroundStyle(Color.moneSecondary)
        }
        .dashboardCard()
    }

    private var velocityMessage: String {
        if summary.operatingRemaining < 0 {
            return "Current pace is above available operating buffer."
        }

        if summary.dailySpendVelocity > summary.income / 25 {
            return "Spending pace is elevated for this income cycle."
        }

        return "Spending pace is within a manageable range for this month."
    }
}

private struct VelocityBars: View {
    let value: Double

    var body: some View {
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(0..<7, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4)
                    .fill(index == 4 ? Color.monePrimary : Color.moneStroke)
                    .frame(height: CGFloat([0.45, 0.55, 0.38, 0.68, 0.82, 0.48, 0.42][index]) * 90)
            }
        }
        .frame(height: 100)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Total net worth")
                    .font(.moneLabelCaps)
                    .foregroundStyle(Color.moneSecondary)

                Text(formatCurrency(summary.totalNetWorth))
                    .font(.system(size: 40, weight: .regular, design: .serif))
                    .foregroundStyle(Color.monePrimary)
            }

            Divider()
                .background(Color.moneStroke)

            VStack(alignment: .leading, spacing: 6) {
                Text("Liquid net worth")
                    .font(.moneLabelCaps)
                    .foregroundStyle(Color.moneSecondary)

                Text(formatCurrency(summary.liquidNetWorth))
                    .font(.system(size: 34, weight: .regular, design: .serif))
                    .foregroundStyle(Color.monePrimary)

                Text("The true operational buffer available across deposit accounts.")
                    .font(.moneBodySm)
                    .foregroundStyle(Color.moneSecondary)
            }

            ProgressView(value: min(summary.liquidityRatio, 1))
                .tint(Color.monePrimary)

            HStack {
                DashboardChip(
                    title: "LIQUIDITY",
                    value: "\(Int(summary.liquidityRatio * 100))%"
                )

                DashboardChip(
                    title: "LOCKED / OTHER",
                    value: formatCurrency(summary.lockedAssets)
                )
            }
        }
        .dashboardCard()
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
                    .font(.moneBodyLg)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(actions, id: \.title) { action in
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

                if action.title != actions.last?.title {
                    Divider()
                        .background(Color.moneStroke)
                }
            }
        }
        .dashboardCard()
    }

    private var actions: [(priority: String, title: String, description: String, color: Color)] {
        if summary.taxDeduction > 0, summary.liquidCashImpact < 0 {
            return [
                (
                    "Priority: High",
                    "Plan for statutory cash impact",
                    "Tax reduced this month’s liquid cash by \(formatCurrency(summary.taxDeduction)). Keep this separate from regular commitments.",
                    .purple
                ),
                (
                    "Priority: Medium",
                    "Review safe-to-spend",
                    "Flexible spending should stay within \(formatCurrency(summary.safeToSpend)) until the next inflow cycle.",
                    Color.moneSecondary
                )
            ]
        }

        if summary.reviewCount > 0 {
            return [
                (
                    "Priority: High",
                    "Review unclear transactions",
                    "\(summary.reviewCount) item(s) are still affecting forecast confidence.",
                    .orange
                ),
                (
                    "Priority: Medium",
                    "Use safe-to-spend as your guide",
                    "Keep flexible spending within \(formatCurrency(summary.safeToSpend)) for this cycle.",
                    Color.moneSecondary
                )
            ]
        }

        if summary.operatingRemaining < 0 {
            return [
                (
                    "Priority: Critical",
                    "Reduce flexible spends",
                    "This operating month is overfunded by \(formatCurrency(abs(summary.operatingRemaining))).",
                    Color.moneRisk
                )
            ]
        }

        if summary.subscriptionAmount > summary.income * 0.08 {
            return [
                (
                    "Priority: Medium",
                    "Audit subscriptions",
                    "Recurring subscriptions are taking a noticeable share of monthly inflow.",
                    .orange
                ),
                (
                    "Priority: Low",
                    "Move surplus deliberately",
                    "Consider assigning \(formatCurrency(summary.operatingRemaining)) to buffer, investments, or upcoming obligations.",
                    Color.moneSecondary
                )
            ]
        }

        return [
            (
                "Priority: Low",
                "Maintain current rhythm",
                "Your MoneyMap is stable for this month.",
                Color.moneHealthy
            ),
            (
                "Priority: Low",
                "Move surplus deliberately",
                "Consider assigning \(formatCurrency(summary.operatingRemaining)) to buffer, investments, or upcoming obligations.",
                Color.moneSecondary
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

#Preview {
    DashboardView()
        .environment(AppViewModel())
}
