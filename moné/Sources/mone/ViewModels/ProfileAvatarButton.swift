import SwiftUI

struct ProfileAvatarButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 40, height: 40)
                    .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)

                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open profile")
    }
}
