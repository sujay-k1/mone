import SwiftUI

// MARK: - Underline Field Wrapper

struct MoneField<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label)
                .font(.moneLabelCaps)
                .tracking(2)
                .foregroundStyle(Color.moneTertiary)

            VStack(spacing: 0) {
                content()
                    .padding(.bottom, 14)

                Rectangle()
                    .fill(Color.moneStrokeMid)
                    .frame(height: 1)
            }
        }
    }
}

// MARK: - Standard TextField styling

extension View {
    func moneFieldStyle() -> some View {
        self
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .font(.moneBodyLg)
            .foregroundStyle(Color.monePrimary)
            .tint(Color.monePrimary)
    }

    func moneNumericFieldStyle() -> some View {
        self
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .font(.moneAmtMd)
            .foregroundStyle(Color.monePrimary)
            .tint(Color.monePrimary)
    }
}

extension Text {
    static func monePlaceholder(_ text: String) -> Text {
        Text(text).foregroundColor(.moneTertiary)
    }
}
