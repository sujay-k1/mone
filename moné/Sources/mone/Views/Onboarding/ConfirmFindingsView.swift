import SwiftUI

struct ConfirmFindingsView: View {
    @Environment(AppViewModel.self) private var appVM

    var moneyMap: MoneyMap { appVM.moneyMap }

    var body: some View {
        ZStack {
            Color.moneBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: MoneSpacing.section) {

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Here's what\nmoné found.")
                            .font(.moneDisplayMd)
                            .foregroundStyle(Color.monePrimary)
                        Text("Review and confirm each item. Edit or ignore anything that's wrong.")
                            .font(.moneBodyMd)
                            .foregroundStyle(Color.moneSecondary)
                    }
                    .padding(.top, 60)

                    // Income section
                    FindingsSection(title: "Income") {
                        ForEach(moneyMap.income) { src in
                            ObligationRow(
                                name: src.name,
                                amount: formatted(src.amount),
                                detail: incomeDetail(src),
                                isConfirmed: true
                            )
                            if src.id != moneyMap.income.last?.id {
                                Divider().background(Color.moneStroke)
                            }
                        }
                    }

                    // Fixed obligations
                    FindingsSection(title: "Fixed obligations") {
                        ForEach(moneyMap.obligations) { ob in
                            ObligationRow(
                                name: ob.name,
                                amount: formatted(ob.amount),
                                detail: ob.dueDay.map { "on \(ordinal($0))" },
                                category: ob.category,
                                isConfirmed: ob.isConfirmed
                            )
                            if ob.id != moneyMap.obligations.last?.id {
                                Divider().background(Color.moneStroke)
                            }
                        }
                    }

                    // Subscriptions
                    FindingsSection(title: "Subscriptions") {
                        ForEach(moneyMap.subscriptions) { sub in
                            ObligationRow(
                                name: sub.name,
                                amount: formatted(sub.monthlyAmount) + "/mo",
                                detail: sub.billingDay.map { "billed on \(ordinal($0))" },
                                isConfirmed: sub.isConfirmed
                            )
                            if sub.id != moneyMap.subscriptions.last?.id {
                                Divider().background(Color.moneStroke)
                            }
                        }
                    }

                    // Upcoming
                    FindingsSection(title: "Upcoming") {
                        ForEach(moneyMap.upcomingItems) { item in
                            UpcomingRow(item: item)
                            if item.id != moneyMap.upcomingItems.last?.id {
                                Divider().background(Color.moneStroke)
                            }
                        }
                    }

                    // Obligation load indicator
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Obligation load")
                                .font(.moneBodyMd)
                                .foregroundStyle(Color.moneSecondary)
                            Spacer()
                            Text("\(Int(moneyMap.obligationLoad * 100))% of income")
                                .font(.moneAmtSm)
                                .foregroundStyle(moneyMap.obligationLoad > 0.6 ? Color.moneRisk :
                                                 moneyMap.obligationLoad > 0.4 ? Color.moneWatch : Color.moneHealthy)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.moneSurfaceHigh).frame(height: 6)
                                Capsule()
                                    .fill(moneyMap.obligationLoad > 0.6 ? Color.moneRisk :
                                          moneyMap.obligationLoad > 0.4 ? Color.moneWatch : Color.moneHealthy)
                                    .frame(width: geo.size.width * CGFloat(moneyMap.obligationLoad), height: 6)
                            }
                        }
                        .frame(height: 6)
                    }
                    .padding(MoneSpacing.cardSm)
                    .moneCard()

                    MonePrimaryButton(title: "Confirm MoneyMap") {
                        appVM.advance()
                    }
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, MoneSpacing.page)
            }
        }
    }

    private func incomeDetail(_ src: IncomeSource) -> String? {
        switch src.type {
        case .stable:   return src.typicalDay.map { "around \(ordinal($0))" } ?? "monthly"
        case .variable: return "variable / irregular"
        default:        return src.frequency.rawValue
        }
    }

    private func formatted(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return "₹\(f.string(from: NSNumber(value: value)) ?? "\(Int(value))")"
    }

    private func ordinal(_ n: Int) -> String {
        let suffix: String
        switch n % 10 {
        case 1 where n % 100 != 11: suffix = "st"
        case 2 where n % 100 != 12: suffix = "nd"
        case 3 where n % 100 != 13: suffix = "rd"
        default: suffix = "th"
        }
        return "\(n)\(suffix)"
    }
}

private struct FindingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: MoneSpacing.gap) {
            Text(title.uppercased())
                .moneLabelCaps()

            VStack(spacing: MoneSpacing.gap) {
                content()
            }
            .padding(MoneSpacing.cardSm)
            .moneCard()
        }
    }
}

#Preview {
    ConfirmFindingsView()
        .environment(AppViewModel())
}
