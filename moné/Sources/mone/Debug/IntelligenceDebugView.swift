import SwiftUI

struct IntelligenceDebugView: View {

    @State private var aaravResult: ImportResult?
    @State private var priyaResult: ImportResult?
    @State private var errorMessage: String?

    private let importer = RawPayloadImporter()
    private let parser = NarrationParser()
    private let classifier = TransactionClassifier()
    private let snapshotBuilder = MonthlySnapshotBuilder()

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

                    if let aaravResult {
                        summaryCard(title: "Aarav", result: aaravResult)
                    }

                    if let priyaResult {
                        summaryCard(title: "Priya", result: priyaResult)
                    }
                }
                .padding()
            }
            .navigationTitle("Intelligence Debug")
            .onAppear {
                loadData()
            }
        }
    }

    private func summaryCard(title: String, result: ImportResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2)
                .bold()

            Text("Accounts: \(result.accounts.count)")
            Text("Transactions: \(result.transactions.count)")

            Divider()

            Text("Account Types")
                .font(.headline)

            ForEach(accountTypeCounts(result.accounts), id: \.0) { type, count in
                HStack {
                    Text(type)
                    Spacer()
                    Text("\(count)")
                }
            }
            
            Divider()

            Text("Income Credits Detected")
                .font(.headline)

            ForEach(incomeCredits(for: result).suffix(6), id: \.transaction.id) { item in
                incomeCreditRow(item)
                Divider()
            }

            Divider()

            Text("Monthly Snapshots")
                .font(.headline)

            ForEach(snapshotBuilder.buildSnapshots(for: result).suffix(4)) { snapshot in
                monthlySnapshotRow(snapshot)
                Divider()
            }
            
            Divider()

            Text("Parsed Sample Transactions")
                .font(.headline)

            ForEach(result.transactions.prefix(12)) { txn in
                parsedTransactionRow(txn)
                Divider()
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func monthlySnapshotRow(_ snapshot: MonthlySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(snapshot.month)
                    .font(.headline)

                Spacer()

                Text("\(snapshot.confidence)% confidence")
                    .font(.caption)
                    .foregroundStyle(snapshot.confidence >= 75 ? .green : .orange)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Income: \(formatCurrency(snapshot.income))")
                Text("Committed: \(formatCurrency(snapshot.committed))")
                Text("Everyday: \(formatCurrency(snapshot.everyday))")
                Text("Fund: \(formatCurrency(snapshot.fund))")
                Text("Liability: \(formatCurrency(snapshot.liability))")
                Text("Outliers: \(formatCurrency(snapshot.outliers))")
                Text("Review: \(formatCurrency(snapshot.review))")
                Text("Remaining: \(formatCurrency(snapshot.remaining))")
                Text("Transactions: \(snapshot.transactionCount)")
                Text("Review count: \(snapshot.reviewCount)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
    
    private func incomeCredits(for result: ImportResult) -> [ClassifiedTransaction] {
        result.transactions
            .filter { transaction in
                transaction.accountType.lowercased() == "deposit" &&
                transaction.type.uppercased() == "CREDIT"
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
                item.classification.role == "income"
            }
            .sorted { first, second in
                let firstDate = first.transaction.valueDate ?? first.transaction.timestamp ?? ""
                let secondDate = second.transaction.valueDate ?? second.transaction.timestamp ?? ""
                return firstDate < secondDate
            }
    }
    
    private func incomeCreditRow(_ item: ClassifiedTransaction) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.transaction.valueDate ?? "No date")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(formatCurrency(item.transaction.amount))
                    .font(.headline)
            }

            Text(item.transaction.narration)
                .font(.subheadline)
                .bold()

            VStack(alignment: .leading, spacing: 3) {
                Text("Role: \(item.classification.role)")
                Text("Category: \(item.classification.category)")
                Text("Confidence: \(item.classification.confidence)")
                Text("Evidence: \(item.classification.evidence.joined(separator: " • "))")
            }
            .font(.caption)
            .foregroundStyle(.green)
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

    private func parsedTransactionRow(_ txn: RawTransaction) -> some View {
        let parsed = parser.parse(txn)
        let classification = classifier.classify(transaction: txn, parsed: parsed)

        return VStack(alignment: .leading, spacing: 6) {
            Text(txn.narration)
                .font(.subheadline)
                .bold()

            Text("₹\(txn.amount, specifier: "%.2f") • \(txn.type) • \(txn.mode)")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 3) {
                Text("Rail: \(parsed.rail ?? "—")")
                Text("Direction: \(parsed.directionCode ?? "—")")
                Text("Counterparty: \(parsed.counterpartyRaw ?? "—")")
                Text("Normalized: \(parsed.normalizedCounterparty ?? "—")")
                Text("Location: \(parsed.location ?? "—")")
                Text("Processor: \(parsed.paymentProcessor ?? "—")")
                Text("Low information: \(parsed.isLowInformation ? "Yes" : "No")")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 3) {
                Text("Classification")
                    .font(.caption)
                    .bold()

                Text("Entity: \(classification.canonicalEntityName ?? "—")")
                Text("Entity type: \(classification.entityType)")
                Text("Role: \(classification.role)")
                Text("Category family: \(classification.categoryFamily)")
                Text("Category: \(classification.category)")
                Text("Confidence: \(classification.confidence)")
                Text("Needs review: \(classification.needsReview ? "Yes" : "No")")

                if let reviewReason = classification.reviewReason {
                    Text("Review reason: \(reviewReason)")
                }

                if !classification.evidence.isEmpty {
                    Text("Evidence: \(classification.evidence.joined(separator: " • "))")
                }

                if !classification.reviewOptions.isEmpty {
                    Text("Review options: \(classification.reviewOptions.joined(separator: ", "))")
                }
            }
            .font(.caption)
            .foregroundStyle(classification.needsReview ? .orange : .green)
            .padding(.top, 4)
        }
    }

    private func accountTypeCounts(_ accounts: [FinancialAccount]) -> [(String, Int)] {
        let grouped = Dictionary(grouping: accounts, by: { $0.accountType })
        return grouped
            .map { ($0.key, $0.value.count) }
            .sorted { $0.0 < $1.0 }
    }

    private func loadData() {
        do {
            aaravResult = try importer.importPayload(
                personaId: .aarav,
                fileName: "raw_payload_aarav"
            )

            priyaResult = try importer.importPayload(
                personaId: .priya,
                fileName: "raw_payload_priya"
            )
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
