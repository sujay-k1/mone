import SwiftUI
import SwiftData

struct LocalDatabaseDebugView: View {

    @Environment(\.modelContext) private var modelContext

    @State private var latestPersona: StoredPersona?
    @State private var snapshots: [StoredMonthlySnapshot] = []
    @State private var accounts: [StoredAccount] = []
    @State private var reviewRows: [StoredTransactionRow] = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Local DB Debug")
                        .font(.title)
                        .bold()

                    Button("Reload from DB") {
                        load()
                    }
                    .buttonStyle(.borderedProminent)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if let latestPersona {
                        personaSection(latestPersona)
                    } else {
                        Text("No local persona saved yet")
                            .foregroundStyle(.secondary)
                    }

                    if !accounts.isEmpty {
                        accountsSection()
                    }

                    if !snapshots.isEmpty {
                        snapshotsSection()
                    }

                    if !reviewRows.isEmpty {
                        reviewSection()
                    }
                }
                .padding()
            }
            .navigationTitle("Local DB")
            .onAppear {
                load()
            }
        }
    }

    private func personaSection(_ persona: StoredPersona) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Latest Persona")
                .font(.headline)

            Text("ID: \(persona.id)")
            Text("Display name: \(persona.displayName)")
            Text("Source: \(persona.source)")
            Text("Last synced: \(persona.lastSyncedAt.formatted())")
        }
        .font(.caption)
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func accountsSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accounts")
                .font(.headline)

            ForEach(accounts) { account in
                HStack {
                    VStack(alignment: .leading) {
                        Text(account.accountType)
                            .bold()

                        Text(account.maskedAccountNumber ?? "No masked number")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if let balance = account.currentBalance {
                        Text(formatCurrency(balance))
                    } else if let value = account.currentValue {
                        Text(formatCurrency(value))
                    }
                }
                .font(.caption)

                Divider()
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func snapshotsSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Snapshots")
                .font(.headline)

            ForEach(snapshots.suffix(6)) { snapshot in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(snapshot.month)
                            .bold()

                        Spacer()

                        Text("\(snapshot.confidence)% confidence")
                            .foregroundStyle(snapshot.confidence >= 75 ? .green : .orange)
                    }

                    Text("Income: \(formatCurrency(snapshot.income))")
                    Text("Committed: \(formatCurrency(snapshot.committed))")
                    Text("Everyday: \(formatCurrency(snapshot.everyday))")
                    Text("Fund: \(formatCurrency(snapshot.fund))")
                    Text("Liability: \(formatCurrency(snapshot.liability))")
                    Text("Review: \(formatCurrency(snapshot.review))")
                    Text("Remaining: \(formatCurrency(snapshot.remaining))")
                }
                .font(.caption)

                Divider()
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func reviewSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Remaining Review Items")
                .font(.headline)

            ForEach(reviewRows.prefix(10)) { row in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(row.transaction.narration)
                            .bold()

                        Spacer()

                        Text(formatCurrency(row.transaction.amount))
                    }

                    if let classification = row.classification {
                        Text("\(classification.categoryFamily) / \(classification.category)")
                        Text("Reason: \(classification.reviewReason ?? "—")")
                    }
                }
                .font(.caption)

                Divider()
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func load() {
        do {
            let store = IntelligencePersistenceStore(
                modelContext: modelContext
            )

            latestPersona = try store.loadLatestPersona()

            guard let latestPersona,
                  let personaId = PersonaId(rawValue: latestPersona.id)
            else {
                snapshots = []
                accounts = []
                reviewRows = []
                return
            }

            snapshots = try store.loadSnapshots(personaId: personaId)
            accounts = try store.loadAccounts(personaId: personaId)

            let latestMonth = snapshots.last?.month

            reviewRows = try store.loadReviewRows(
                personaId: personaId,
                month: latestMonth
            )
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
