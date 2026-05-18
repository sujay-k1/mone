import SwiftUI

struct SetupView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var showHealthDetail = false
    @State private var showDeleteAlert  = false

    var map: MoneyMap { appVM.moneyMap }

    var body: some View {
        ZStack {
            Color.moneBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: MoneSpacing.gutter) {

                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("moné").font(.moneLabelCaps).tracking(1.5).foregroundStyle(Color.moneTertiary)
                            Text("Setup").font(.moneHLMd).foregroundStyle(Color.monePrimary)
                        }
                        Spacer()
                    }
                    .padding(.top, 16)

                    // Agenda section
                    SetupSection(title: "Agenda") {
                        if let primary = appVM.primaryAgenda {
                            SetupRow(label: "Primary", value: primary.title)
                        }
                        if let secondary = appVM.secondaryAgenda {
                            Divider().background(Color.moneStroke)
                            SetupRow(label: "Secondary", value: secondary.title)
                        }
                        Divider().background(Color.moneStroke)
                        SetupRow(label: "Nudge style", value: appVM.nudgeIntensity.rawValue)
                    }

                    // Money Map summary
                    SetupSection(title: "Money Map") {
                        SetupRow(label: "Monthly income",
                                 value: appVM.formatted(map.totalMonthlyIncome))
                        Divider().background(Color.moneStroke)
                        SetupRow(label: "Obligations",
                                 value: "\(map.obligations.count) items · \(appVM.formatted(map.totalMonthlyObligations))/mo")
                        Divider().background(Color.moneStroke)
                        SetupRow(label: "Subscriptions",
                                 value: "\(map.subscriptions.count) items · \(appVM.formatted(map.totalMonthlySubscriptions))/mo")
                        Divider().background(Color.moneStroke)
                        SetupRow(label: "Goals",
                                 value: "\(map.goals.count) goals · \(appVM.formatted(map.totalGoalAllocation))/mo")
                    }

                    // Financial health
                    SetupSection(title: "Financial Health") {
                        let report = appVM.healthReport
                        Button {
                            showHealthDetail = true
                        } label: {
                            HStack {
                                Text(report.overallLabel)
                                    .font(.moneBodyMd)
                                    .foregroundStyle(Color.monePrimary)
                                Spacer()
                                HealthChip(status: report.overallStatus)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.moneTertiary)
                            }
                        }
                        .buttonStyle(.plain)

                        Divider().background(Color.moneStroke)

                        ForEach(report.allSignals.filter { $0.status != .healthy }) { signal in
                            HStack {
                                Image(systemName: signal.dimension.icon)
                                    .font(.system(size: 14))
                                    .foregroundStyle(signal.status.color)
                                    .frame(width: 20)
                                Text(signal.dimension.rawValue)
                                    .font(.moneBodySm)
                                    .foregroundStyle(Color.monePrimary)
                                Spacer()
                                HealthChip(status: signal.status)
                            }
                            .padding(.vertical, 4)
                            Divider().background(Color.moneStroke)
                        }
                    }

                    // Data sources
                    SetupSection(title: "Data Sources") {
                        SetupRow(
                            label: "Account Aggregator",
                            value: appVM.setupMethod == .accountAggregator ? "Connected" : "Not connected",
                            valueColor: appVM.setupMethod == .accountAggregator ? .moneHealthy : .moneTertiary
                        )
                        Divider().background(Color.moneStroke)
                        SetupRow(label: "Email", value: "Not connected", valueColor: .moneTertiary)
                        Divider().background(Color.moneStroke)
                        SetupRow(label: "SMS signals", value: "Optional", valueColor: .moneTertiary)
                    }

                    // Privacy
                    SetupSection(title: "Privacy") {
                        SetupRow(label: "Storage mode",
                                 value: appVM.storageMode.map { $0 == .local ? "Local only" : "Encrypted backup" } ?? "Not set")
                        Divider().background(Color.moneStroke)
                        SetupRow(label: "Raw data stored", value: "Never")
                        Divider().background(Color.moneStroke)
                        SetupRow(label: "Money Map on device", value: "Yes")

                        Divider().background(Color.moneStroke)

                        Button {
                            showDeleteAlert = true
                        } label: {
                            Text("Delete Money Map")
                                .font(.moneBodyMd)
                                .foregroundStyle(Color.moneRisk)
                        }
                        .buttonStyle(.plain)
                    }

                    // Backup
                    SetupSection(title: "Backup") {
                        SetupRow(
                            label: "Encrypted backup",
                            value: appVM.storageMode == .encryptedBackup ? "On" : "Off"
                        )
                        Divider().background(Color.moneStroke)
                        MoneSecondaryButton(title: "Create backup", fullWidth: false) { }
                    }

                    // App info
                    HStack {
                        Text("moné v1.0 · Local-first · Privacy-first")
                            .font(.moneBodySm)
                            .foregroundStyle(Color.moneTertiary)
                        Spacer()
                    }
                    .padding(.vertical, MoneSpacing.gap)

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, MoneSpacing.page)
            }
        }
        .sheet(isPresented: $showHealthDetail) {
            FinancialHealthDetailView()
        }
        .alert("Delete Money Map?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                appVM.moneyMap = MoneyMap()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove all your income, obligations, goals, and health data from this device. This cannot be undone.")
        }
    }
}

// MARK: - Setup Section

struct SetupSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: MoneSpacing.gap) {
            Text(title.uppercased())
                .moneLabelCaps()

            VStack(spacing: 0) {
                content()
            }
            .padding(MoneSpacing.cardSm)
            .moneCard()
        }
    }
}

// MARK: - Setup Row

struct SetupRow: View {
    let label: String
    let value: String
    var valueColor: Color = .moneSecondary

    var body: some View {
        HStack {
            Text(label)
                .font(.moneBodyMd)
                .foregroundStyle(Color.monePrimary)
            Spacer()
            Text(value)
                .font(.moneBodySm)
                .foregroundStyle(valueColor)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Financial Health Detail

struct FinancialHealthDetailView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.moneBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: MoneSpacing.gutter) {

                    HStack {
                        Text("Financial Health")
                            .font(.moneHLMd)
                            .foregroundStyle(Color.monePrimary)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Color.moneTertiary)
                        }
                    }
                    .padding(.top, 24)

                    let report = appVM.healthReport
                    Text(report.overallLabel)
                        .font(.moneHL)
                        .foregroundStyle(report.overallStatus.color)
                    Text(report.overallSummary)
                        .font(.moneBodyLg)
                        .foregroundStyle(Color.moneSecondary)

                    ForEach(report.allSignals) { signal in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: signal.dimension.icon)
                                    .font(.system(size: 16))
                                    .foregroundStyle(signal.status.color)
                                Text(signal.dimension.rawValue)
                                    .font(.moneHLSm)
                                    .foregroundStyle(Color.monePrimary)
                                Spacer()
                                HealthChip(status: signal.status)
                            }
                            Text(signal.detail)
                                .font(.moneBodyMd)
                                .foregroundStyle(Color.moneSecondary)
                        }
                        .padding(MoneSpacing.cardSm)
                        .moneCard()
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, MoneSpacing.page)
            }
        }
        .presentationBackground(Color.moneBackground)
    }
}

#Preview {
    SetupView()
        .environment(AppViewModel())
}
