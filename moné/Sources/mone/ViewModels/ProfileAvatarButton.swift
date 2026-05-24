import SwiftUI

struct ProfileAvatarButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.white.opacity(0.88))
                .padding(.vertical, 11)
                .padding(.horizontal, 6)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.clear.tint(.white.opacity(0.1)), in: Circle())
        .accessibilityLabel("Open profile")
    }
}
