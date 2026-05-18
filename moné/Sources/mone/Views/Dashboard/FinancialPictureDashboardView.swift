import SwiftUI

struct FinancialPictureDashboardView: View {
    @Environment(AppViewModel.self) private var appVM

    var health: FinancialHealthReport { appVM.healthReport }
    var map: MoneyMap { appVM.moneyMap }
    var sts: SafeToSpendCalculator.Result { appVM.safeToSpend }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: MoneSpacing.gutter) {

                DashboardHeader(title: "Dashboard")
                    .padding(.top, 16)

                // Hero: Financial health
                ZStack(alignment: .topLeading) {
                    ContourBackground().opacity(0.4)
                    VStack(alignment: .leading, spacing: MoneSpacing.gap) {
                        Text("FINANCIAL HEALTH")
                            .moneLabelCaps()
                        Text(health.overallLabel)
                            .font(.moneAmtMd)
                            .foregroundStyle(Color.monePrimary)
                        Text(health.overallSummary)
                            .font(.moneBodyMd)
                            .foregroundStyle(Color.moneSecondary)

                        Divider().background(Color.moneStroke)

                        HStack(spacing: 0) {
                            MiniStat(label: "Monthly income", value: appVM.formatted(map.totalMonthlyIncome))
                            Divider().background(Color.moneStroke).frame(height: 32)
                            MiniStat(label: "Safe-to-spend", value: sts.monthlyFormatted)
                            Divider().background(Color.moneStroke).frame(height: 32)
                            MiniStat(label: "Obligation", value: "\(Int(map.obligationLoad * 100))%")
                        }
                    }
                    .padding(MoneSpacing.cardLg)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .moneCard()

                // Health signals
                Text("HEALTH SIGNALS")
                    .moneLabelCaps()

                VStack(spacing: 0) {
                    ForEach(health.allSignals) { signal in
                        HealthSignalRow(signal: signal)
                        if signal.id != health.allSignals.last?.id {
                            Divider().background(Color.moneStroke).padding(.horizontal, MoneSpacing.cardSm)
                        }
                    }
                }
                .moneCard()

                // Upcoming
                VStack(alignment: .leading, spacing: MoneSpacing.gap) {
                    Text("UPCOMING")
                        .moneLabelCaps()
                    VStack(spacing: MoneSpacing.gap) {
                        ForEach(map.upcomingItems) { item in
                            UpcomingRow(item: item)
                            if item.id != map.upcomingItems.last?.id {
                                Divider().background(Color.moneStroke)
                            }
                        }
                    }
                    .padding(MoneSpacing.cardSm)
                    .moneCard()
                }

                Spacer(minLength: 20)
            }
            .padding(.horizontal, MoneSpacing.page)
        }
        .background(Color.moneBackground)
    }
}

// MARK: - Health Signal Row

struct HealthSignalRow: View {
    let signal: HealthSignal

    var body: some View {
        HStack(spacing: MoneSpacing.gutter) {
            Image(systemName: signal.dimension.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(signal.status.color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(signal.dimension.rawValue)
                    .font(.moneBodyMd)
                    .foregroundStyle(Color.monePrimary)
                Text(signal.detail)
                    .font(.moneBodySm)
                    .foregroundStyle(Color.moneSecondary)
                    .lineLimit(2)
            }

            Spacer()

            if let value = signal.value {
                Text(value)
                    .font(.moneBodySm)
                    .foregroundStyle(signal.status.color)
            } else {
                HealthChip(status: signal.status)
            }
        }
        .padding(.horizontal, MoneSpacing.cardSm)
        .padding(.vertical, 12)
    }
}

#Preview {
    FinancialPictureDashboardView()
        .environment(AppViewModel())
}
