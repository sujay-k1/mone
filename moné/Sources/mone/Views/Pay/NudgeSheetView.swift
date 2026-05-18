import SwiftUI

struct NudgeSheetView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss
    let nudge: Nudge

    var body: some View {
        ZStack {
            Color.moneBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: MoneSpacing.section) {

                // Merchant + amount header
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("₹")
                            .font(.moneHLMd)
                            .foregroundStyle(Color.moneSecondary)
                        Text("\(Int(nudge.amount))")
                            .font(.moneAmtLg)
                            .foregroundStyle(Color.monePrimary)
                    }
                    Text(nudge.merchant)
                        .font(.moneBodyLg)
                        .foregroundStyle(Color.moneSecondary)
                }
                .padding(.top, 32)

                Divider().background(Color.moneStroke)

                // Nudge message
                VStack(alignment: .leading, spacing: MoneSpacing.gap) {
                    Text(nudge.message)
                        .font(.moneHL)
                        .foregroundStyle(Color.monePrimary)

                    Text(nudge.impact)
                        .font(.moneBodyLg)
                        .foregroundStyle(Color.moneSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Safe-to-spend context
                let impact = SafeToSpendCalculator.impactOfPayment(
                    amount: nudge.amount,
                    moneyMap: appVM.moneyMap,
                    spentThisWeek: appVM.spentThisWeek
                )

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Before")
                            .font(.moneBodySm)
                            .foregroundStyle(Color.moneTertiary)
                        Text("₹\(Int(impact.safeToSpendBefore))")
                            .font(.moneAmtSm)
                            .foregroundStyle(Color.moneSecondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.right")
                        .foregroundStyle(Color.moneTertiary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("After")
                            .font(.moneBodySm)
                            .foregroundStyle(Color.moneTertiary)
                        Text(impact.remainingAfterPayment >= 0 ?
                             "₹\(Int(impact.remainingAfterPayment))" :
                             "-₹\(Int(abs(impact.remainingAfterPayment)))")
                            .font(.moneAmtSm)
                            .foregroundStyle(impact.riskLevel.color)
                    }
                }
                .padding(MoneSpacing.cardSm)
                .moneCard()

                // Nudge intensity control
                HStack(spacing: 8) {
                    Text("Nudge level:")
                        .font(.moneBodySm)
                        .foregroundStyle(Color.moneTertiary)
                    ForEach(NudgeIntensity.allCases, id: \.rawValue) { level in
                        Button {
                            appVM.nudgeIntensity = level
                        } label: {
                            Text(level.rawValue)
                                .font(.moneBodySm)
                                .foregroundStyle(appVM.nudgeIntensity == level ? Color.moneActionFg : Color.moneSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(appVM.nudgeIntensity == level ? Color.moneActionFill : Color.clear)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().strokeBorder(
                                        appVM.nudgeIntensity == level ? Color.clear : Color.moneStroke,
                                        lineWidth: 1
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                // Action buttons
                VStack(spacing: MoneSpacing.gap) {
                    ForEach(Array(nudge.actions.prefix(2).enumerated()), id: \.offset) { idx, action in
                        NudgeActionButton(action: action, isPrimary: idx == 0) {
                            handleAction(action)
                        }
                    }
                    if nudge.actions.count > 2 {
                        HStack(spacing: MoneSpacing.gap) {
                            ForEach(Array(nudge.actions.dropFirst(2).enumerated()), id: \.offset) { _, action in
                                NudgeActionButton(action: action, isPrimary: false) {
                                    handleAction(action)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, MoneSpacing.page)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.moneBackground)
    }

    private func handleAction(_ action: NudgeAction) {
        switch action {
        case .continueToUPI, .stillPay, .overrideAnyway:
            appVM.confirmPayment()
            dismiss()
        case .payLater:
            appVM.resetPay()
            dismiss()
        case .reduceAmount:
            dismiss()
        case .adjustBudget, .viewImpact:
            dismiss()
        }
    }
}

#Preview {
    let nudge = Nudge(
        merchant: "Third Wave Coffee",
        amount: 850,
        message: "This is okay, but it's 47% of your weekly budget.",
        impact: "Leaves ₹420 for eating out this week.",
        intensity: .balanced,
        actions: [.continueToUPI, .reduceAmount, .payLater, .overrideAnyway]
    )
    return NudgeSheetView(nudge: nudge)
        .environment(AppViewModel())
}
