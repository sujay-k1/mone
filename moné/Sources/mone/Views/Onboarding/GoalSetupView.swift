import SwiftUI

struct GoalSetupView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var showAddGoal = false

    var body: some View {
        ZStack {
            Color.moneBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: MoneSpacing.section) {

                    VStack(alignment: .leading, spacing: 10) {
                        Text("What are you\nsaving for?")
                            .font(.moneDisplayMd)
                            .foregroundStyle(Color.monePrimary)
                        Text("moné tracks progress and tells you if goals are at risk.")
                            .font(.moneBodyMd)
                            .foregroundStyle(Color.moneSecondary)
                    }
                    .padding(.top, 60)

                    // Existing goals
                    VStack(spacing: MoneSpacing.gutter) {
                        ForEach(appVM.moneyMap.goals) { goal in
                            GoalCard(
                                goal: goal,
                                status: GoalProjectionCalculator.status(for: goal)
                            )
                        }
                    }

                    // Goal impact preview
                    if !appVM.moneyMap.goals.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Impact on safe-to-spend")
                                .font(.moneBodyMd)
                                .foregroundStyle(Color.moneSecondary)

                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Monthly goal allocation")
                                        .font(.moneBodySm)
                                        .foregroundStyle(Color.moneTertiary)
                                    Text(appVM.formatted(appVM.moneyMap.totalGoalAllocation))
                                        .font(.moneAmtSm)
                                        .foregroundStyle(Color.moneWatch)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Safe-to-spend after goals")
                                        .font(.moneBodySm)
                                        .foregroundStyle(Color.moneTertiary)
                                    Text(appVM.safeToSpend.monthlyFormatted)
                                        .font(.moneAmtSm)
                                        .foregroundStyle(Color.moneHealthy)
                                }
                            }
                        }
                        .padding(MoneSpacing.cardSm)
                        .moneCard()
                    }

                    MonePrimaryButton(title: "Continue") {
                        appVM.advance()
                    }
                    MoneTertiaryButton(title: "Skip — add goals later") {
                        appVM.advance()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, MoneSpacing.page)
            }
        }
    }
}

#Preview {
    GoalSetupView()
        .environment(AppViewModel())
}
