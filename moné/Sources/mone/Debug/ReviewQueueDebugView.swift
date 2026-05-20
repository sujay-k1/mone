import SwiftUI

struct ReviewQueueDebugView: View {
    
    private func aiSuggestionButton() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                Task {
                    await fetchAISuggestions()
                }
            } label: {
                HStack {
                    if isLoadingAISuggestions {
                        ProgressView()
                    }

                    Text(isLoadingAISuggestions ? "Asking AI..." : "Ask AI for review suggestions")
                        .bold()
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoadingAISuggestions || currentItems.isEmpty)

            if let aiErrorMessage {
                Text(aiErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if !aiSuggestions.isEmpty {
                Text("AI suggestions received: \(aiSuggestions.count)")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    @MainActor
    private func fetchAISuggestions() async {
        isLoadingAISuggestions = true
        aiErrorMessage = nil

        defer {
            isLoadingAISuggestions = false
        }

        let requests = currentItems.map { item in
            let features = TransactionFeatureExtractor().extract(
                transaction: item.transaction,
                parsed: item.parsed
            )

            return aiRequestBuilder.build(
                transaction: item.transaction,
                parsed: item.parsed,
                features: features
            )
        }

        do {
            let suggestions = try await aiClient.classifyReviewItems(
                personaId: selectedPersona,
                month: selectedMonth,
                items: requests
            )

            aiSuggestions = Dictionary(
                uniqueKeysWithValues: suggestions.map { ($0.transactionId, $0) }
            )
        } catch {
            aiErrorMessage = String(describing: error)
        }
    }

    @State private var reviewItemsByPersona: [PersonaId: [ClassifiedTransaction]] = [:]
    @State private var selectedPersona: PersonaId = .priya
    @State private var selectedMonth: String = ""
    @State private var errorMessage: String?
    
    @State private var aiSuggestions: [String: AIClassificationSuggestion] = [:]
    @State private var aiErrorMessage: String?
    @State private var isLoadingAISuggestions = false

    private let importer = RawPayloadImporter()
    private let parser = NarrationParser()
    private let classifier = TransactionClassifier()
    
    private let aiRequestBuilder = AIClassificationRequestBuilder()
    private let aiClient = AIReviewClassificationClient()

    private var currentItems: [ClassifiedTransaction] {
        let allItems = reviewItemsByPersona[selectedPersona] ?? []

        guard !selectedMonth.isEmpty else {
            return allItems
        }

        return allItems.filter { item in
            monthKey(for: item.transaction) == selectedMonth
        }
    }

    private var availableMonths: [String] {
        let allItems = reviewItemsByPersona[selectedPersona] ?? []

        let months = Set(
            allItems.compactMap { item in
                monthKey(for: item.transaction)
            }
        )

        return months.sorted()
    }

    private var totalReviewAmount: Double {
        currentItems.reduce(0) { $0 + $1.transaction.amount }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let errorMessage {
                        Text("Error")
                            .font(.headline)

                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }

                    controlsSection()
                    summarySection()
                    aiSuggestionButton()
                    reasonBreakdownSection()
                    reviewItemsSection()
                }
                .padding()
            }
            .navigationTitle("Review Queue Debug")
            .onAppear {
                loadData()
            }
            .onChange(of: selectedPersona) { _, newValue in
                selectedMonth = availableMonths.last ?? ""
            }
        }
    }

    private func controlsSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Debug Controls")
                .font(.headline)

            Picker("Persona", selection: $selectedPersona) {
                Text("Aarav").tag(PersonaId.aarav)
                Text("Priya").tag(PersonaId.priya)
            }
            .pickerStyle(.segmented)

            if !availableMonths.isEmpty {
                Picker("Month", selection: $selectedMonth) {
                    ForEach(availableMonths, id: \.self) { month in
                        Text(month).tag(month)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func summarySection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Review Summary")
                .font(.headline)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Amount")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(formatCurrency(totalReviewAmount))
                        .font(.title2)
                        .bold()
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Items")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\(currentItems.count)")
                        .font(.title2)
                        .bold()
                }
            }

            Text("These are transactions that Moné could not classify confidently enough to safely use in the Money Map.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func reasonBreakdownSection() -> some View {
        let grouped = Dictionary(grouping: currentItems) { item in
            item.classification.reviewReason ?? "No review reason"
        }

        let rows = grouped.map { reason, items in
            ReviewReasonRow(
                reason: reason,
                amount: items.reduce(0) { $0 + $1.transaction.amount },
                count: items.count
            )
        }
        .sorted { $0.amount > $1.amount }

        return VStack(alignment: .leading, spacing: 12) {
            Text("Why Items Need Review")
                .font(.headline)

            ForEach(rows) { row in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.reason)
                            .font(.subheadline)
                            .bold()

                        Text("\(row.count) transactions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(formatCurrency(row.amount))
                        .font(.subheadline)
                        .bold()
                }

                Divider()
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func reviewItemsSection() -> some View {
        let sortedItems = currentItems.sorted {
            $0.transaction.amount > $1.transaction.amount
        }

        return VStack(alignment: .leading, spacing: 16) {
            Text("Top Review Items")
                .font(.headline)

            ForEach(sortedItems.prefix(30), id: \.transaction.id) { item in
                reviewItemRow(item)
                Divider()
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func reviewItemRow(_ item: ClassifiedTransaction) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.transaction.narration)
                        .font(.subheadline)
                        .bold()

                    Text(item.transaction.valueDate ?? item.transaction.timestamp ?? "No date")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(formatCurrency(item.transaction.amount))
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Role: \(item.classification.role)")
                Text("Category: \(item.classification.categoryFamily) / \(item.classification.category)")
                Text("Confidence: \(item.classification.confidence)")
                Text("Reason: \(item.classification.reviewReason ?? "—")")

                if !item.classification.evidence.isEmpty {
                    Text("Evidence: \(item.classification.evidence.joined(separator: " • "))")
                }

                if !item.classification.reviewOptions.isEmpty {
                    Text("Options: \(item.classification.reviewOptions.joined(separator: ", "))")
                }
            }
            .font(.caption)
            .foregroundStyle(.orange)
            
            if let suggestion = aiSuggestions[item.transaction.id] {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Suggestion")
                        .font(.caption)
                        .bold()

                    Text("Role: \(suggestion.role)")
                    Text("Category: \(suggestion.categoryFamily) / \(suggestion.category)")
                    Text("Confidence: \(suggestion.confidence)")
                    Text("Needs review: \(suggestion.needsReview ? "Yes" : "No")")

                    if let question = suggestion.reviewQuestion {
                        Text("Question: \(question)")
                    }

                    if !suggestion.evidence.isEmpty {
                        Text("Evidence: \(suggestion.evidence.joined(separator: " • "))")
                    }
                }
                .font(.caption)
                .foregroundStyle(suggestion.needsReview ? .orange : .green)
                .padding(.top, 6)
            }
        }
    }

    private func loadData() {
        do {
            let aaravResult = try importer.importPayload(
                personaId: .aarav,
                fileName: "raw_payload_aarav"
            )

            let priyaResult = try importer.importPayload(
                personaId: .priya,
                fileName: "raw_payload_priya"
            )

            let aaravReviewItems = buildReviewItems(for: aaravResult)
            let priyaReviewItems = buildReviewItems(for: priyaResult)

            reviewItemsByPersona = [
                .aarav: aaravReviewItems,
                .priya: priyaReviewItems
            ]

            selectedPersona = .priya
            selectedMonth = availableMonths.last ?? ""
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func buildReviewItems(for result: ImportResult) -> [ClassifiedTransaction] {
        result.transactions
            .filter { transaction in
                transaction.accountType.lowercased() == "deposit"
            }
            .map { transaction in
                let parsed = parser.parse(transaction)
                let classification = classifier.classify(
                    transaction: transaction,
                    parsed: parsed
                )

                return ClassifiedTransaction(
                    transaction: transaction,
                    parsed: parsed,
                    classification: classification
                )
            }
            .filter { item in
                item.transaction.type.uppercased() == "DEBIT" &&
                item.classification.needsReview
            }
            .sorted { first, second in
                first.transaction.amount > second.transaction.amount
            }
    }

    private func monthKey(for transaction: RawTransaction) -> String? {
        if let valueDate = transaction.valueDate, valueDate.count >= 7 {
            return String(valueDate.prefix(7))
        }

        if let timestamp = transaction.timestamp, timestamp.count >= 7 {
            return String(timestamp.prefix(7))
        }

        return nil
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

private struct ReviewReasonRow: Identifiable {
    let id = UUID()
    let reason: String
    let amount: Double
    let count: Int
}
