import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class DataProcessingViewModel {

    var currentStep: DataProcessingStep = .fetchingAccountData
    var completedSteps: [DataProcessingStep] = []
    var isRunning = false
    var isFinished = false
    var errorMessage: String?

    private var hasStarted = false
    private let pipeline = AAIntelligencePipeline()

    func run(
        mobile: String,
        pan: String?,
        consentId: String?,
        modelContext: ModelContext
    ) async {
        guard !hasStarted else { return }

        hasStarted = true
        isRunning = true
        isFinished = false
        errorMessage = nil
        completedSteps = []

        do {
            let result = try await pipeline.runAfterAAConsent(
                mobile: mobile,
                pan: pan,
                consentId: consentId
            ) { [weak self] step in
                Task { @MainActor in
                    self?.mark(step)
                }
            }

            mark(.savingResults)

            let persistenceStore = IntelligencePersistenceStore(
                modelContext: modelContext
            )

            try persistenceStore.save(result)

            isRunning = false
            isFinished = true
        } catch {
            isRunning = false
            errorMessage = readableError(error)
        }
    }

    private func mark(_ step: DataProcessingStep) {
        currentStep = step

        if !completedSteps.contains(step) {
            completedSteps.append(step)
        }
    }

    func retry(
        mobile: String,
        pan: String?,
        consentId: String?,
        modelContext: ModelContext
    ) async {
        hasStarted = false

        await run(
            mobile: mobile,
            pan: pan,
            consentId: consentId,
            modelContext: modelContext
        )
    }

    private func readableError(_ error: Error) -> String {
        String(describing: error)
    }
}
