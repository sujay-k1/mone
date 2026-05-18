import SwiftUI

struct WelcomeView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var animateIn = false

    let valueProps: [(icon: String, title: String, detail: String)] = [
        ("banknote",             "Know what is safe to spend",      "See your real discretionary budget, updated daily."),
        ("lock.shield",          "See what is already committed",   "Rent, EMIs, SIPs, bills — all mapped and tracked."),
        ("hand.raised",          "Pause before money slips away",   "A quiet nudge before risky discretionary spends.")
    ]

    var body: some View {
        ZStack {
            Color.moneBackground.ignoresSafeArea()
            ContourBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: MoneSpacing.section) {

                        // Logo / wordmark
                        VStack(alignment: .leading, spacing: 12) {
                            Text("moné")
                                .font(.moneDisplay)
                                .foregroundStyle(Color.monePrimary)
                                .opacity(animateIn ? 1 : 0)
                                .offset(y: animateIn ? 0 : 12)

                            Text("A local-first money\ncontrol tool.")
                                .font(.moneHL)
                                .foregroundStyle(Color.moneSecondary)
                                .lineSpacing(4)
                                .opacity(animateIn ? 1 : 0)
                                .offset(y: animateIn ? 0 : 8)
                        }
                        .padding(.top, 60)

                        // Value proposition cards
                        VStack(spacing: MoneSpacing.gutter) {
                            ForEach(Array(valueProps.enumerated()), id: \.offset) { idx, prop in
                                WelcomePropCard(icon: prop.icon, title: prop.title, detail: prop.detail)
                                    .opacity(animateIn ? 1 : 0)
                                    .offset(y: animateIn ? 0 : 16)
                                    .animation(
                                        .spring(response: 0.5, dampingFraction: 0.8)
                                        .delay(0.1 + Double(idx) * 0.08),
                                        value: animateIn
                                    )
                            }
                        }

                        // Privacy note
                        HStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.moneSecondary)
                            Text("Your data never leaves your device unless you choose otherwise.")
                                .font(.moneBodySm)
                                .foregroundStyle(Color.moneSecondary)
                        }
                        .opacity(animateIn ? 1 : 0)
                    }
                    .padding(.horizontal, MoneSpacing.page)
                }

                // Sticky bottom CTAs
                VStack(spacing: MoneSpacing.gap) {
                    MoneTertiaryButton(title: "No account required — local mode by default") {
                        appVM.advance()
                    }
                    MonePrimaryButton(title: "Start with moné") {
                        appVM.advance()
                    }
                    .frame(maxWidth: .infinity)
                }
                .opacity(animateIn ? 1 : 0)
                .padding(.horizontal, MoneSpacing.page)
                .padding(.top, MoneSpacing.gutter)
                .padding(.bottom, 0)
                .background(Color.moneBackground)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animateIn = true
            }
        }
    }
}

private struct WelcomePropCard: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: MoneSpacing.gutter) {
            ZStack {
                RoundedRectangle(cornerRadius: MoneRadius.md, style: .continuous)
                    .fill(Color.moneSurfaceEl)
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.moneSecondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.moneHLSm)
                    .foregroundStyle(Color.monePrimary)
                Text(detail)
                    .font(.moneBodySm)
                    .foregroundStyle(Color.moneSecondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(MoneSpacing.cardSm)
        .moneCard()
    }
}

#Preview {
    WelcomeView()
        .environment(AppViewModel())
}
