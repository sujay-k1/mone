import SwiftUI

struct SpendingDashboardView: View {
    @Environment(AppViewModel.self) private var appVM

    var sts: SafeToSpendCalculator.Result { appVM.safeToSpend }
    var map: MoneyMap { appVM.moneyMap }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: MoneSpacing.gutter) {

                DashboardHeader(title: "Trends")
                    .padding(.top, 16)

                // Hero: Safe-to-spend
                ZStack(alignment: .topLeading) {
                    ContourBackground().opacity(0.5)

                    VStack(alignment: .leading, spacing: MoneSpacing.gap) {
                        Text("SAFE TO SPEND THIS WEEK")
                            .moneLabelCaps()

                        Text(sts.remainingFormatted)
                            .font(.moneAmtLg)
                            .foregroundStyle(Color.monePrimary)
                            .minimumScaleFactor(0.7)

                        Text("After rent, EMIs, SIPs, bills, and goals.")
                            .font(.moneBodyMd)
                            .foregroundStyle(Color.moneSecondary)

                        Divider().background(Color.moneStroke)

                        HStack(spacing: 0) {
                            MiniStat(label: "Daily", value: sts.dailyFormatted)
                            Divider().background(Color.moneStroke).frame(height: 32)
                            MiniStat(label: "Monthly", value: sts.monthlyFormatted)
                            Divider().background(Color.moneStroke).frame(height: 32)
                            MiniStat(label: "Committed", value: appVM.formatted(map.totalMonthlyObligations + map.totalMonthlySubscriptions))
                        }
                    }
                    .padding(MoneSpacing.cardLg)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .moneCard()

                // Insight cards
                VStack(spacing: MoneSpacing.gap) {
                    Text("ATTENTION")
                        .moneLabelCaps()
                    ForEach(appVM.insights) { insight in
                        InsightCard(data: insight)
                    }
                }

                // Obligation load
                ObligationLoadCard(map: map)

                // Upcoming obligations
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

                // Goals preview
                if !map.goals.isEmpty {
                    VStack(alignment: .leading, spacing: MoneSpacing.gap) {
                        HStack {
                            Text("GOALS")
                                .moneLabelCaps()
                            Spacer()
                            Text("\(appVM.goalsOnTrack) of \(map.goals.count) on track")
                                .font(.moneBodySm)
                                .foregroundStyle(Color.moneSecondary)
                        }

                        ForEach(map.goals.prefix(2)) { goal in
                            MiniGoalRow(goal: goal)
                        }
                    }
                }

                // Pay with Pause CTA
                PayPauseCTA()

                Spacer(minLength: 20)
            }
            .padding(.horizontal, MoneSpacing.page)
        }
        .background(Color.moneBackground)
    }
}

// MARK: - Mini Stat

struct MiniStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label.uppercased())
                .moneLabelCaps()
            Text(value)
                .font(.moneAmtSm)
                .foregroundStyle(Color.monePrimary)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Obligation Load Card

struct ObligationLoadCard: View {
    let map: MoneyMap

    var pct: Double { map.obligationLoad }
    var status: HealthStatus { pct < 0.4 ? .healthy : pct < 0.6 ? .watch : .risk }

    var body: some View {
        VStack(alignment: .leading, spacing: MoneSpacing.gap) {
            HStack {
                Text("OBLIGATION LOAD")
                    .moneLabelCaps()
                Spacer()
                HealthChip(status: status)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(pct * 100))%")
                    .font(.moneAmtMd)
                    .foregroundStyle(status.color)
                Text("of income committed")
                    .font(.moneBodySm)
                    .foregroundStyle(Color.moneSecondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.moneSurfaceHigh).frame(height: 6)
                    Capsule()
                        .fill(status.color)
                        .frame(width: geo.size.width * CGFloat(min(pct, 1.0)), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(MoneSpacing.cardSm)
        .moneCard()
    }
}

// MARK: - Mini Goal Row

struct MiniGoalRow: View {
    let goal: Goal
    var status: GoalStatus { GoalProjectionCalculator.status(for: goal) }

    var statusColor: Color {
        switch status {
        case .onTrack: return .moneHealthy
        case .atRisk:  return .moneWatch
        default:       return .moneSecondary
        }
    }

    var body: some View {
        HStack(spacing: MoneSpacing.gutter) {
            Image(systemName: goal.type.icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.moneSecondary)
                .frame(width: 20)

            Text(goal.name)
                .font(.moneBodyMd)
                .foregroundStyle(Color.monePrimary)

            Spacer()

            Text(status.label)
                .font(.moneBodySm)
                .foregroundStyle(statusColor)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, MoneSpacing.cardSm)
        .moneCard(radius: MoneRadius.lg)
    }
}

// MARK: - Pay with Pause CTA

struct PayPauseCTA: View {
    var body: some View {
        HStack(spacing: MoneSpacing.gutter) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Pay with Pause")
                    .font(.moneHLSm)
                    .foregroundStyle(Color.monePrimary)
                Text("Check impact before you pay")
                    .font(.moneBodySm)
                    .foregroundStyle(Color.moneSecondary)
            }
            Spacer()
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Color.monePrimary)
        }
        .padding(MoneSpacing.cardSm)
        .background(Color.moneSurfaceEl)
        .clipShape(RoundedRectangle(cornerRadius: MoneRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MoneRadius.xl, style: .continuous)
                .strokeBorder(Color.moneStrokeBright, lineWidth: 1)
        )
    }
}

#Preview {
    SpendingDashboardView()
        .environment(AppViewModel())
}
