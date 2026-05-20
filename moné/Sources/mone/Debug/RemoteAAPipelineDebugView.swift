import SwiftUI
import SwiftData

struct RemoteAAPipelineDebugView: View {

    @Environment(\.modelContext) private var modelContext
    
    @State private var mobile = "7304893952"
    @State private var pan = "ABCDE0000P"
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var result: AAIntelligenceResult?
    @State private var didSaveToDatabase = false

    private let pipeline = AAIntelligencePipeline()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Remote AA Pipeline Debug")
                        .font(.title)
                        .bold()

                    TextField("Mobile", text: $mobile)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.phonePad)

                    TextField("PAN", text: $pan)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        Task {
                            await runPipeline()
                        }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                            }

                            Text(isLoading ? "Running..." : "Fetch AA Payload + Run Intelligence")
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    
                    if didSaveToDatabase {
                        Text("Saved to local database")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }

                    if let result {
                        resultSection(result)
                    }
                }
                .padding()
            }
            .navigationTitle("AA Pipeline")
            
        }
    }

    private func resultSection(_ result: AAIntelligenceResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Result")
                .font(.headline)

            Text("Persona: \(result.personaId.rawValue)")
            Text("Accounts: \(result.importResult.accounts.count)")
            Text("Transactions: \(result.importResult.transactions.count)")
            Text("AI suggestions: \(result.aiSuggestions.count)")

            Divider()

            Text("Latest Snapshots")
                .font(.headline)

            ForEach(result.snapshots.suffix(4)) { snapshot in
                VStack(alignment: .leading, spacing: 4) {
                    Text(snapshot.month)
                        .font(.subheadline)
                        .bold()

                    Text("Income: \(formatCurrency(snapshot.income))")
                    Text("Committed: \(formatCurrency(snapshot.committed))")
                    Text("Everyday: \(formatCurrency(snapshot.everyday))")
                    Text("Fund: \(formatCurrency(snapshot.fund))")
                    Text("Liability: \(formatCurrency(snapshot.liability))")
                    Text("Review: \(formatCurrency(snapshot.review))")
                    Text("Remaining: \(formatCurrency(snapshot.remaining))")
                    Text("Confidence: \(snapshot.confidence)%")
                }
                .font(.caption)

                Divider()
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @MainActor
    private func runPipeline() async {
        isLoading = true
        errorMessage = nil
        result = nil
        didSaveToDatabase = false

        defer {
            isLoading = false
        }

        do {
            let pipelineResult = try await pipeline.runAfterAAConsent(
                mobile: mobile,
                pan: pan,
                consentId: "debug_consent_001"
            )

            let persistenceStore = IntelligencePersistenceStore(
                modelContext: modelContext
            )

            try persistenceStore.save(pipelineResult)

            result = pipelineResult
            didSaveToDatabase = true
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale(identifier: "en_IN")

        return formatter.string(from: NSNumber(value: value)) ?? "₹\(Int(value))"
    }
}
