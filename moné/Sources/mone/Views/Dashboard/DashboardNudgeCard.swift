import SwiftUI

struct DashboardNudgeCard: View {
    let nudge: DashboardNudge
    let onPrimaryAction: () -> Void
    let onDismiss: () -> Void

    @State private var didAppear = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.moneStroke.opacity(0.25))
                        .frame(width: 64, height: 64)

                    Image(systemName: nudge.iconName)
                        .font(.system(size: 36, weight: .light))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color.monePrimary, Color.moneSecondary, Color.moneTertiary)
                        .symbolEffect(.drawOn.individually, isActive: !didAppear)
                        .symbolEffect(.pulse.byLayer, options: didAppear ? .repeating : .default)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                didAppear = true
                            }
                        }
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(nudge.title)
                        .font(.moneBodyLg)
                        .foregroundStyle(Color.monePrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(nudge.message)
                        .font(.moneBodySm)
                        .foregroundStyle(Color.moneSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.moneTertiary)
                        .padding(8)
                }
                .buttonStyle(.plain)
            }

            Button {
                onPrimaryAction()
            } label: {
                Text(nudge.primaryActionTitle.uppercased())
                    .font(.moneLabelCaps)
                    .foregroundStyle(Color.monePrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.moneStroke.opacity(0.28))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.moneSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.moneStroke, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
