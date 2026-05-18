import SwiftUI

// MARK: - Primary Button (off-white pill, black text)

struct MonePrimaryButton: View {
    let title: String
    var icon: String? = nil
    var fullWidth: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.moneHLSm)
                }
                Text(title)
                    .font(.moneHLSm)
            }
            .foregroundStyle(Color.moneActionFg)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.vertical, 16)
            .padding(.horizontal, 28)
            .background(Color.moneActionFill)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Secondary Button (transparent, stroke)

struct MoneSecondaryButton: View {
    let title: String
    var fullWidth: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.moneBodyLg)
                .foregroundStyle(Color.moneSecondary)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .padding(.vertical, 14)
                .padding(.horizontal, 24)
                .background(Color.clear)
                .overlay(
                    Capsule().strokeBorder(Color.moneStrokeMid, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tertiary / Text-only Button

struct MoneTertiaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.moneBodyMd)
                .foregroundStyle(Color.moneTertiary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Icon-only Circle Button

struct MoneIconButton: View {
    let icon: String
    var size: CGFloat = 48
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.moneHLSm)
                .foregroundStyle(Color.moneSecondary)
                .frame(width: size, height: size)
                .overlay(
                    Circle().strokeBorder(Color.moneStrokeMid, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Health Status Chip

struct HealthChip: View {
    let status: HealthStatus

    var body: some View {
        Text(status.rawValue.uppercased())
            .font(.moneLabelCaps)
            .tracking(0.8)
            .foregroundStyle(status.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(status.bgColor)
            .clipShape(Capsule())
    }
}

// MARK: - Priority Chip

struct PriorityChip: View {
    let priority: GoalPriority

    var color: Color {
        switch priority {
        case .mustProtect: return .moneRisk
        case .important: return .moneWatch
        case .flexible: return .moneSecondary
        }
    }

    var body: some View {
        Text(priority.shortLabel.uppercased())
            .font(.moneLabelCaps)
            .tracking(0.6)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

// MARK: - Category Filter Chip

struct FilterChip: View {
    let title: String
    var isSelected: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.moneBodySm)
                .foregroundStyle(isSelected ? Color.moneActionFg : Color.moneSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.moneActionFill : Color.clear)
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(
                        isSelected ? Color.clear : Color.moneStroke,
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Nudge Action Button

struct NudgeActionButton: View {
    let action: NudgeAction
    var isPrimary: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(action.rawValue)
                .font(.moneBodyMd)
                .foregroundStyle(isPrimary ? Color.moneActionFg : Color.monePrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isPrimary ? Color.moneActionFill : Color.moneSurfaceEl)
                .clipShape(RoundedRectangle(cornerRadius: MoneRadius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: MoneRadius.lg, style: .continuous)
                        .strokeBorder(Color.moneStroke, lineWidth: isPrimary ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
    }
}
