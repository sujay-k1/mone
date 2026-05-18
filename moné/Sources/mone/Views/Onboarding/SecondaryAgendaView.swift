import SwiftUI

struct SecondaryAgendaView: View {
    @Environment(AppViewModel.self) private var appVM

    var options: [AgendaType] {
        AgendaType.allCases.filter { $0 != appVM.primaryAgenda }
    }

    var body: some View {
        ZStack {
            Color.moneBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: MoneSpacing.section) {

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Anything else\nmoné should\nkeep an eye on?")
                            .font(.moneDisplayMd)
                            .foregroundStyle(Color.monePrimary)
                        Text("Optional — you can change this anytime.")
                            .font(.moneBodyLg)
                            .foregroundStyle(Color.moneSecondary)
                    }
                    .padding(.top, 60)

                    VStack(spacing: MoneSpacing.gutter) {
                        ForEach(options) { agenda in
                            AgendaCard(
                                agenda: agenda,
                                isSelected: appVM.secondaryAgenda == agenda
                            ) {
                                appVM.selectSecondary(
                                    appVM.secondaryAgenda == agenda ? nil : agenda
                                )
                            }
                        }
                    }

                    VStack(spacing: MoneSpacing.gap) {
                        MonePrimaryButton(title: appVM.secondaryAgenda != nil ? "Continue" : "Skip for now") {
                            appVM.advance()
                        }
                    }
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, MoneSpacing.page)
            }
        }
    }
}

#Preview {
    SecondaryAgendaView()
        .environment({
            let vm = AppViewModel()
            vm.primaryAgenda = .controlSpending
            return vm
        }())
}
