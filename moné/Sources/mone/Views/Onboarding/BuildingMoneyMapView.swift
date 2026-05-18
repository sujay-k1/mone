import SwiftUI

struct BuildingMoneyMapView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var currentStep = 0
    @State private var done = false

    let steps = [
        (icon: "waveform.path",        label: "Finding income"),
        (icon: "repeat",               label: "Detecting recurring payments"),
        (icon: "app.badge",            label: "Identifying subscriptions"),
        (icon: "calendar",             label: "Checking upcoming obligations"),
        (icon: "gauge.with.needle",    label: "Preparing safe-to-spend")
    ]

    var body: some View {
        ZStack {
            Color.moneBackground.ignoresSafeArea()
            ContourBackground().ignoresSafeArea()

            VStack(spacing: MoneSpacing.section) {
                Spacer()

                // Animated logo
                ZStack {
                    Circle()
                        .strokeBorder(Color.moneStroke, lineWidth: 1)
                        .frame(width: 100, height: 100)
                    Circle()
                        .strokeBorder(Color.moneStrokeMid, lineWidth: 1)
                        .frame(width: 72, height: 72)
                    Text("moné")
                        .font(.moneHLMd)
                        .foregroundStyle(Color.monePrimary)
                }
                .rotationEffect(.degrees(done ? 360 : 0))
                .animation(.linear(duration: 4).repeatWhile(!done), value: done)

                // Steps
                VStack(alignment: .leading, spacing: MoneSpacing.gutter) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                        HStack(spacing: MoneSpacing.gutter) {
                            Image(systemName: step.icon)
                                .font(.system(size: 16))
                                .foregroundStyle(idx <= currentStep ? Color.moneHealthy : Color.moneTertiary)
                                .frame(width: 24)

                            Text(step.label)
                                .font(.moneBodyMd)
                                .foregroundStyle(idx <= currentStep ? Color.monePrimary : Color.moneTertiary)

                            Spacer()

                            if idx < currentStep {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.moneHealthy)
                            } else if idx == currentStep && !done {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.7)
                                    .tint(Color.moneSecondary)
                            }
                        }
                        .animation(.easeIn(duration: 0.3), value: currentStep)
                    }
                }
                .padding(MoneSpacing.cardLg)
                .moneCard()
                .padding(.horizontal, MoneSpacing.page)

                if done {
                    MonePrimaryButton(title: "See what moné found") {
                        appVM.advance()
                    }
                    .padding(.horizontal, MoneSpacing.page)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer()
            }
        }
        .onAppear {
            simulateProgress()
        }
        .animation(.easeInOut(duration: 0.4), value: done)
    }

    func simulateProgress() {
        for i in 0..<steps.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.8) {
                currentStep = i
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(steps.count) * 0.8 + 0.4) {
            done = true
        }
    }
}

private extension Animation {
    func repeatWhile(_ condition: Bool, autoreverses: Bool = false) -> Animation {
        condition ? self.repeatForever(autoreverses: autoreverses) : self
    }
}

#Preview {
    BuildingMoneyMapView()
        .environment(AppViewModel())
}
