import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.modelContext) private var modelContext

    @State private var summary: DashboardSummary?
    @State private var errorMessage: String?
    @State private var showSignUp = false
    @State private var isRestoringFinancialData = false

    private static let signUpDismissedKey = "mone.signUpDismissed"

    var body: some View {
        ZStack {
            Color.moneBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let summary {
                        DashboardHeader(
                            title: dashboardTitle(for: summary),
                            subtitle: "\(summary.displayName.capitalized) · \(summary.month)"
                        )

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
            let alreadyDismissed = UserDefaults.standard.bool(forKey: Self.signUpDismissedKey)
            let isSignedIn = supabase.auth.currentSession != nil
            if !alreadyDismissed && !isSignedIn && appVM.verifiedPhone != nil {
                showSignUp = true
            }
        }
        .sheet(isPresented: $showSignUp) {
            SignUpSheet(
                aaPhone: appVM.verifiedPhone ?? "",
                onDismissed: {
                    UserDefaults.standard.set(true, forKey: Self.signUpDismissedKey)
                    showSignUp = false
                },
                onComplete: {
                    showSignUp = false
                }
            )
            .presentationDetents([PresentationDetent.large])
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
                    DashboardFooterItem(title: "Cash impact", value: formatCurrency(summary.liquidCashImpact))
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
                return
            }

            guard supabase.auth.currentSession != nil else {
                summary = nil
                errorMessage = "No processed financial data found. Complete Account Aggregator setup first."
                return
            }

            isRestoringFinancialData = true
            errorMessage = nil

            let restored = try await FinancialDataCloudService()
                .restoreLatestCloudData(modelContext: modelContext)

            isRestoringFinancialData = false

            guard restored else {
                summary = nil
                errorMessage = "No saved financial data found for this account."
                return
            }

            let reloadLoader = DashboardDataLoader(modelContext: modelContext)
            summary = try reloadLoader.loadLatestSummary()

            if summary == nil {
                errorMessage = "We restored your data, but could not rebuild the dashboard."
            }
        } catch {
            isRestoringFinancialData = false
            errorMessage = "Could not restore your financial data. \(String(describing: error))"
        }
    }
}

// MARK: - Shared Dashboard Header

struct DashboardHeader: View {
    @Environment(AppViewModel.self) private var appVM
    let title: String
    var subtitle: String? = nil

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("moné")
                    .font(.moneLabelCaps)
                    .tracking(1.5)
                    .foregroundStyle(Color.moneTertiary)

                Text(title)
                    .font(.moneHLMd)
                    .foregroundStyle(Color.monePrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(.moneBodySm)
                        .foregroundStyle(Color.moneSecondary)
                }
            }

            Spacer()

            Circle()
                .fill(Color.moneHealthy)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .strokeBorder(Color.moneHealthy.opacity(0.3), lineWidth: 4)
                )
        }
    }
}

private struct DashboardSectionTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(title.uppercased())
                    .font(.moneLabelCaps)
                    .foregroundStyle(Color.moneTertiary)

                Spacer()
            }

            Rectangle()
                .fill(Color.moneStroke)
                .frame(height: 0.5)
        }
        .padding(.top, 8)
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

            Divider()
                .background(Color.moneStroke)

            HStack {
                ForEach(footerItems) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title.uppercased())
                            .font(.moneLabelCaps)
                            .foregroundStyle(Color.moneTertiary)

                        Text(item.value)
                            .font(.moneBodySm)
                            .foregroundStyle(Color.monePrimary)
                    }

                    Spacer()
                }
            }
        }
        .dashboardCard()
    }
}

private struct MoneySplitCard: View {
    let summary: DashboardSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Monthly money split")
                .font(.moneLabelCaps)
                .foregroundStyle(Color.moneSecondary)

            MoneySplitBar(summary: summary)

            VStack(spacing: 12) {
                DashboardAmountRow(title: "Regular commitments", value: summary.committed)
                DashboardAmountRow(title: "Everyday", value: summary.everyday)
                DashboardAmountRow(title: "Fund-building", value: summary.fund)
                DashboardAmountRow(title: "Liabilities", value: summary.liability)
                DashboardAmountRow(title: "Outliers", value: summary.outliers)
                DashboardAmountRow(title: "Review", value: summary.review)
                DashboardAmountRow(title: "Operating remaining", value: summary.operatingRemaining)
                DashboardAmountRow(title: "Tax / statutory", value: summary.taxDeduction)
                DashboardAmountRow(title: "Liquid cash impact", value: summary.liquidCashImpact)
            }
        }
        .dashboardCard()
    }
}

private struct MoneySplitBar: View {
    let summary: DashboardSummary

    private var total: Double {
        max(
            summary.committed +
            summary.everyday +
            summary.fund +
            summary.liability +
            summary.outliers +
            summary.review +
            max(summary.operatingRemaining, 0),
            1
        )
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                segment(summary.committed, width: geometry.size.width, color: Color.monePrimary)
                segment(summary.everyday, width: geometry.size.width, color: Color.moneSecondary)
                segment(summary.fund, width: geometry.size.width, color: Color.moneHealthy)
                segment(summary.liability, width: geometry.size.width, color: .blue)
                segment(summary.outliers, width: geometry.size.width, color: Color.moneRisk.opacity(0.75))
                segment(summary.review, width: geometry.size.width, color: .orange)
                segment(max(summary.operatingRemaining, 0), width: geometry.size.width, color: Color.moneTertiary.opacity(0.35))
            }
            .clipShape(Capsule())
        }
        .frame(height: 10)
    }

    private func segment(_ value: Double, width: Double, color: Color) -> some View {
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

        return "\(summary.reviewCount) transaction(s) may need review to stabilise this month’s Money Map."
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
                "Your Money Map is stable for this month.",
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
            .background(Color.moneSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.moneStroke, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
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

#Preview {
    DashboardView()
        .environment(AppViewModel())
}
