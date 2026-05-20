import SwiftUI

struct AccountAggregatorSetupView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Setup account aggregator")
                    .font(.title2.weight(.semibold))

                Text("This is where Moné will ask for consent, mimic the third-party account aggregator flow, and connect the user’s demo financial data.")
                    .font(.body)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(20)
            .navigationTitle("Account Aggregator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
