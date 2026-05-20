import SwiftUI
import SwiftData

struct DataFetchingView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.modelContext) private var modelContext

    @State private var currentStep: DataProcessingStep = .fetchingAccountData
    @State private var completedSteps: [DataProcessingStep] = []
    @State private var isRunning = false
    @State private var error: String?

    private let pipeline = AAIntelligencePipeline()

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 32) {
                processingLogo

                VStack(spacing: 8) {
                    Text("Preparing your money map")
                        .font(.moneHL)
                        .foregroundStyle(Color.monePrimary)

                    Text("We’re processing your account data on this device.")
                        .font(.moneBodySm)
                        .foregroundStyle(Color.moneSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, MoneSpacing.page)

                VStack(spacing: 16) {
                    ForEach(DataProcessingStep.allCases) { step in
                        stepRow(step)
                    }
                }
                .padding(.horizontal, 40)

                if let error {
                    errorSection(error)
                }
            }

            Spacer()
        }
        .background(Color.moneBackground.ignoresSafeArea())
        .task {
            await runPipelineOnce()
        }
    }

    private var processingLogo: some View {
        ZStack {
            Circle()
                .stroke(Color.moneStroke, lineWidth: 1)
                .frame(width: 100, height: 100)
                .rotationEffect(.degrees(Double(completedSteps.count) * 45))
                .animation(.easeInOut(duration: 0.5), value: completedSteps.count)

            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(Color.monePrimary)
                .symbolEffect(.pulse, isActive: isRunning)
        }
    }

    private func stepRow(_ step: DataProcessingStep) -> some View {
        let isCompleted = completedSteps.contains(step)
        let isCurrent = currentStep == step && isRunning

        return HStack(spacing: 14) {
            ZStack {
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.moneHealthy)
                } else if isCurrent {
                    ProgressView()
                        .tint(Color.monePrimary)
                } else {
                    Image(systemName: iconName(for: step))
                        .foregroundStyle(Color.moneTertiary)
                }
            }
            .font(.system(size: 18))
            .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(step.rawValue)
                    .font(.moneBodyLg)
                    .foregroundStyle(isCompleted || isCurrent ? Color.monePrimary : Color.moneTertiary)

                Text(step.subtitle)
                    .font(.moneBodySm)
                    .foregroundStyle(Color.moneSecondary)
                    .lineLimit(2)
            }

            Spacer()
        }
    }

    private func errorSection(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text(message)
                .font(.moneBodySm)
                .foregroundStyle(Color.moneRisk)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                MoneSecondaryButton(title: "Try again", fullWidth: false) {
                    Task {
                        await runPipelineAgain()
                    }
                }

                MoneSecondaryButton(title: "Try another number", fullWidth: false) {
                    appVM.onboardingStep = .phoneOtp
                }
            }
        }
        .padding(.horizontal, MoneSpacing.page)
    }

    @MainActor
    private func runPipelineOnce() async {
        guard !isRunning, completedSteps.isEmpty else { return }
        await runPipeline()
    }

    @MainActor
    private func runPipelineAgain() async {
        completedSteps = []
        currentStep = .fetchingAccountData
        error = nil
        await runPipeline()
    }

    @MainActor
    private func runPipeline() async {
        guard let phone = appVM.verifiedPhone else {
            error = "No verified phone number. Please go back and verify."
            return
        }

        guard let pan = appVM.enteredPAN, !pan.isEmpty else {
            error = "PAN is missing. Please go back and enter your PAN."
            return
        }

        isRunning = true
        error = nil
        appVM.aaFetchError = nil

        do {
            let result = try await pipeline.runAfterAAConsent(
                mobile: phone,
                pan: pan,
                consentId: currentConsentId()
            ) { step in
                Task { @MainActor in
                    mark(step)
                }
            }

            mark(.savingResults)

            let persistenceStore = IntelligencePersistenceStore(
                modelContext: modelContext
            )

            try persistenceStore.save(result)

            isRunning = false
            appVM.advance()
        } catch {
            isRunning = false
            let message = readableError(error)
            self.error = message
            appVM.aaFetchError = message
        }
    }

    @MainActor
    private func mark(_ step: DataProcessingStep) {
        withAnimation(.easeOut(duration: 0.25)) {
            currentStep = step

            if !completedSteps.contains(step) {
                completedSteps.append(step)
            }
        }
    }

    private func currentPAN() -> String? {
        appVM.enteredPAN
    }

    private func currentConsentId() -> String? {
        appVM.aaConsentId
    }

    private func readableError(_ error: Error) -> String {
        let text = String(describing: error)

        if text.contains("No synthetic AA fixture mapped") {
            return "We could not find test financial data for this phone number."
        }

        if text.contains("invalidURL") {
            return "The data connection is not configured correctly."
        }

        if text.contains("serverError") {
            return "We could not fetch your account data. Please try again."
        }

        return "Could not process your financial data. Please try again."
    }

    private func iconName(for step: DataProcessingStep) -> String {
        switch step {
        case .fetchingAccountData:
            return "arrow.down.doc"
        case .readingAccounts:
            return "building.columns"
        case .readingTransactions:
            return "list.bullet.rectangle"
        case .categorisingTransactions:
            return "tag"
        case .resolvingUnclearItems:
            return "sparkles"
        case .buildingInsights:
            return "chart.bar"
        case .savingResults:
            return "internaldrive"
        }
    }
}

// MARK: - Compatibility shim

/// This view used to run a second fake processing animation.
/// Keep this temporarily only if your AppViewModel/router still references `IntelligenceProcessingView`.
/// Once onboarding is updated to go directly from `DataFetchingView` to dashboard, delete this view.
struct IntelligenceProcessingView: View {
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .tint(Color.monePrimary)

            Text("Finalizing your dashboard")
                .font(.moneHL)
                .foregroundStyle(Color.monePrimary)

            Text("Your insights have been saved on this device.")
                .font(.moneBodySm)
                .foregroundStyle(Color.moneSecondary)
        }
        .padding(MoneSpacing.page)
        .background(Color.moneBackground.ignoresSafeArea())
        .task {
            try? await Task.sleep(for: .milliseconds(250))
            appVM.advance()
        }
    }
}
