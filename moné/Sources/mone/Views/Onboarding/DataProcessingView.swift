import SwiftUI
import SwiftData

struct DataFetchingView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.modelContext) private var modelContext

    @State private var currentStep: DataProcessingStep = .fetchingAccountData
    @State private var completedSteps: [DataProcessingStep] = []
    @State private var isRunning = false
    @State private var error: String?
    @State private var processingIconIndex = 0
    @State private var isProcessingIconVisible = true

    private let pipeline = AAIntelligencePipeline()
    private let processingIcons = [
        "square.text.square",
        "iphone",
        "sparkles"
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 32) {
                processingLogo

                VStack(spacing: 8) {
                    Text("Preparing your MoneyMap")
                        .font(.moneHL)
                        .foregroundStyle(Color.monePrimary)

                    Text("We’re processing your account data on this device.")
                        .font(.moneBodySm)
                        .foregroundStyle(Color.moneSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, MoneSpacing.page)

                VStack(spacing: 16) {
                    ForEach(VisibleProcessingStep.allCases) { step in
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
        .task {
            await runProcessingIconAnimation()
        }
    }

    private var processingLogo: some View {
        ZStack {
            Circle()
                .stroke(Color.moneStroke, lineWidth: 1)
                .frame(width: 100, height: 100)
                .rotationEffect(.degrees(Double(completedSteps.count) * 45))
                .animation(.easeInOut(duration: 0.5), value: completedSteps.count)

            if isProcessingIconVisible {
                Image(systemName: processingIcons[processingIconIndex])
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(Color.monePrimary)
                    .transition(.symbolEffect(.drawOn))
                    .id(processingIconIndex)
            }
        }
    }

    @MainActor
    private func runProcessingIconAnimation() async {
        while !Task.isCancelled {
            withAnimation(.easeInOut(duration: 0.18)) {
                isProcessingIconVisible = false
            }

            guard await sleep(milliseconds: 180) else { return }

            processingIconIndex = (processingIconIndex + 1) % processingIcons.count

            withAnimation(.easeInOut(duration: 0.75)) {
                isProcessingIconVisible = true
            }

            guard await sleep(milliseconds: 1_150) else { return }
        }
    }

    private func sleep(milliseconds: UInt64) async -> Bool {
        do {
            try await Task.sleep(for: .milliseconds(milliseconds))
            return !Task.isCancelled
        } catch {
            return false
        }
    }

    private func stepRow(_ step: VisibleProcessingStep) -> some View {
        let isCompleted = isVisibleStepCompleted(step)
        let isCurrent = isVisibleStepCurrent(step)

        return HStack(spacing: 14) {
            ZStack {
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.moneHealthy)
                } else if isCurrent {
                    ProgressView()
                        .tint(Color.monePrimary)
                } else {
                    Image(systemName: step.iconName)
                        .foregroundStyle(Color.moneTertiary)
                }
            }
            .font(.system(size: 18))
            .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(step.title)
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

    private func isVisibleStepCompleted(_ step: VisibleProcessingStep) -> Bool {
        step.sourceSteps.allSatisfy { completedSteps.contains($0) }
    }

    private func isVisibleStepCurrent(_ step: VisibleProcessingStep) -> Bool {
        isRunning && step.sourceSteps.contains(currentStep) && !isVisibleStepCompleted(step)
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
                    appVM.verifiedPhone = nil
                    appVM.enteredPAN = nil
                    appVM.aaConsentId = nil
                    appVM.shouldOpenAAFetchDetailsSheet = true
                    appVM.onboardingStep = .aaConsent
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

}

private enum VisibleProcessingStep: String, CaseIterable, Identifiable {
    case importingFinancialData
    case categorisingTransactions
    case resolvingUnclearItems
    case buildingInsights
    case savingResults

    var id: String { rawValue }

    var title: String {
        switch self {
        case .importingFinancialData:
            return "Importing financial data"
        case .categorisingTransactions:
            return DataProcessingStep.categorisingTransactions.rawValue
        case .resolvingUnclearItems:
            return DataProcessingStep.resolvingUnclearItems.rawValue
        case .buildingInsights:
            return DataProcessingStep.buildingInsights.rawValue
        case .savingResults:
            return DataProcessingStep.savingResults.rawValue
        }
    }

    var subtitle: String {
        switch self {
        case .importingFinancialData:
            return "Fetching account data, reading accounts, and organising transactions."
        case .categorisingTransactions:
            return DataProcessingStep.categorisingTransactions.subtitle
        case .resolvingUnclearItems:
            return DataProcessingStep.resolvingUnclearItems.subtitle
        case .buildingInsights:
            return DataProcessingStep.buildingInsights.subtitle
        case .savingResults:
            return DataProcessingStep.savingResults.subtitle
        }
    }

    var iconName: String {
        switch self {
        case .importingFinancialData:
            return "square.text.square"
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

    var sourceSteps: [DataProcessingStep] {
        switch self {
        case .importingFinancialData:
            return [.fetchingAccountData, .readingAccounts, .readingTransactions]
        case .categorisingTransactions:
            return [.categorisingTransactions]
        case .resolvingUnclearItems:
            return [.resolvingUnclearItems]
        case .buildingInsights:
            return [.buildingInsights]
        case .savingResults:
            return [.savingResults]
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
