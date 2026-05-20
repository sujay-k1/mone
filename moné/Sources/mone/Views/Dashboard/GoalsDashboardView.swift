import SwiftUI

struct GoalsDashboardView: View {
    @Environment(AppViewModel.self) private var appVM

    var goals: [Goal]   { appVM.moneyMap.goals }
    var sts: SafeToSpendCalculator.Result { appVM.safeToSpend }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: MoneSpacing.gutter) {

                DashboardHeader(title: "Trends")
                    .padding(.top, 16)

                // Hero: Goal health
                ZStack(alignment: .topLeading) {
                    ContourBackground().opacity(0.4)
                    VStack(alignment: .leading, spacing: MoneSpacing.gap) {
                        Text("GOAL HEALTH")
                            .moneLabelCaps()
                        Text("\(appVM.goalsOnTrack) of \(goals.count) goals on track")
                            .font(.moneAmtMd)
                            .foregroundStyle(Color.monePrimary)

                        Divider().background(Color.moneStroke)

                        HStack(spacing: 0) {
                            MiniStat(label: "Allocated", value: appVM.formatted(appVM.moneyMap.totalGoalAllocation) + "/mo")
                            Divider().background(Color.moneStroke).frame(height: 32)
                            MiniStat(label: "Left after goals", value: sts.monthlyFormatted)
                        }
                    }
                    .padding(MoneSpacing.cardLg)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .moneCard()

                // All goals
                Text("YOUR GOALS")
                    .moneLabelCaps()

                ForEach(goals.sorted { $0.priority.sortOrder < $1.priority.sortOrder }) { goal in
                    GoalCard(
                        goal: goal,
                        status: GoalProjectionCalculator.status(for: goal)
                    )
                }

                // Upcoming obligations
                VStack(alignment: .leading, spacing: MoneSpacing.gap) {
                    Text("UPCOMING")
                        .moneLabelCaps()
                    VStack(spacing: MoneSpacing.gap) {
                        ForEach(appVM.moneyMap.upcomingItems) { item in
                            UpcomingRow(item: item)
                            if item.id != appVM.moneyMap.upcomingItems.last?.id {
                                Divider().background(Color.moneStroke)
                            }
                        }
                    }
                    .padding(MoneSpacing.cardSm)
                    .moneCard()
                }

                // Scenario CTA
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Can I afford this?")
                            .font(.moneHLSm)
                            .foregroundStyle(Color.monePrimary)
                        Text("Check impact on your goals before spending")
                            .font(.moneBodySm)
                            .foregroundStyle(Color.moneSecondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.right.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.moneSecondary)
                }
                .padding(MoneSpacing.cardSm)
                .moneCard()

                Spacer(minLength: 20)
            }
            .padding(.horizontal, MoneSpacing.page)
        }
        .background(Color.moneBackground)
    }
}

#Preview {
    GoalsDashboardView()
        .environment(AppViewModel())
}
