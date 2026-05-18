import SwiftUI

// MARK: - Hero Financial Card

struct HeroCard: View {
    var label: String
    var value: String
    var subtext: String?
    var status: HealthStatus = .healthy
    var showOrbital: Bool = true

    var body: some View {
        ZStack(alignment: .topLeading) {
            if showOrbital {
                ContourBackground()
                    .opacity(0.6)
            }

            VStack(alignment: .leading, spacing: MoneSpacing.gap) {
                Text(label.uppercased())
                    .moneLabelCaps()

                Text(value)
                    .font(.moneAmtLg)
                    .foregroundStyle(Color.monePrimary)
                    .minimumScaleFactor(0.7)

                if let subtext {
                    Text(subtext)
                        .font(.moneBodyMd)
                        .foregroundStyle(Color.moneSecondary)
                        .lineLimit(2)
                }
            }
            .padding(MoneSpacing.cardLg)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .moneCard(radius: MoneRadius.xxl, elevated: false)
    }
}

// MARK: - Agenda Card

struct AgendaCard: View {
    let agenda: AgendaType
    var isSelected: Bool = false
    var tag: String? = nil
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: MoneSpacing.gutter) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.moneActionFill.opacity(0.15) : Color.moneSurfaceEl)
                        .frame(width: 48, height: 48)
                    Image(systemName: agenda.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(isSelected ? Color.moneActionFill : Color.moneSecondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(agenda.title)
                        .font(.moneHLSm)
                        .foregroundStyle(Color.monePrimary)
                    Text(agenda.subtitle)
                        .font(.moneBodySm)
                        .foregroundStyle(Color.moneSecondary)
                        .lineLimit(2)
                        .padding(.bottom, 8)
                    if let tag {
                        Text(tag.uppercased())
                            .font(.moneLabelCaps)
                            .tracking(0.6)
                            .foregroundStyle(Color.moneActionFill)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.moneActionFill.opacity(0.12))
                            .clipShape(Capsule())
                            .padding(.top, 2)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isSelected ? Color.moneActionFill : Color.moneTertiary)
            }
            .padding(MoneSpacing.cardSm)
            .background(isSelected ? Color.moneSurfaceEl : Color.moneSurface)
            .clipShape(RoundedRectangle(cornerRadius: MoneRadius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: MoneRadius.xl, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.moneStrokeBright : Color.moneStroke,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Insight Card

struct InsightCard: View {
    let data: InsightCardData
    var onAction: (() -> Void)? = nil

    var accentColor: Color {
        switch data.type {
        case .healthy: return .moneHealthy
        case .watch:   return .moneWatch
        case .risk:    return .moneRisk
        case .info:    return .moneInfo
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: MoneSpacing.gap) {
            // Accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor)
                .frame(width: 3)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 6) {
                Text(data.title)
                    .font(.moneHLSm)
                    .foregroundStyle(Color.monePrimary)

                Text(data.detail)
                    .font(.moneBodyMd)
                    .foregroundStyle(Color.moneSecondary)
                    .lineLimit(2)

                if let onAction {
                    Button(action: onAction) {
                        Text(data.actionLabel)
                            .font(.moneBodySm)
                            .foregroundStyle(accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
        .padding(MoneSpacing.cardSm)
        .moneCard()
    }
}

// MARK: - Obligation Row

struct ObligationRow: View {
    let name: String
    let amount: String
    let detail: String?
    var category: ObligationCategory? = nil
    var isConfirmed: Bool = false
    var onConfirm: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: MoneSpacing.gutter) {
            if let category {
                ZStack {
                    RoundedRectangle(cornerRadius: MoneRadius.sm, style: .continuous)
                        .fill(Color.moneSurfaceEl)
                        .frame(width: 40, height: 40)
                    Image(systemName: category.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.moneSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.moneHLSm)
                    .foregroundStyle(Color.monePrimary)
                if let detail {
                    Text(detail)
                        .font(.moneBodySm)
                        .foregroundStyle(Color.moneTertiary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(amount)
                    .font(.moneAmtSm)
                    .foregroundStyle(Color.monePrimary)

                if let onConfirm {
                    Button(action: onConfirm) {
                        Text(isConfirmed ? "Confirmed" : "Confirm")
                            .font(.moneBodySm)
                            .foregroundStyle(isConfirmed ? Color.moneHealthy : Color.moneSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Goal Card

struct GoalCard: View {
    let goal: Goal
    var status: GoalStatus = .noDeadline
    var onTap: (() -> Void)? = nil

    var statusColor: Color {
        switch status {
        case .onTrack:    return .moneHealthy
        case .atRisk:     return .moneWatch
        case .completed:  return .moneHealthy
        case .noDeadline: return .moneSecondary
        }
    }

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: MoneSpacing.gap) {
                // Header
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: goal.type.icon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.moneSecondary)
                        Text(goal.name)
                            .font(.moneHLSm)
                            .foregroundStyle(Color.monePrimary)
                    }
                    Spacer()
                    PriorityChip(priority: goal.priority)
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.moneSurfaceHigh)
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(statusColor)
                            .frame(width: geo.size.width * CGFloat(goal.progressFraction), height: 4)
                    }
                }
                .frame(height: 4)

                // Amounts row
                HStack {
                    Text("\(goal.amountFormatted(goal.alreadySaved)) saved")
                        .font(.moneBodySm)
                        .foregroundStyle(Color.moneSecondary)
                    Spacer()
                    Text("of \(goal.amountFormatted(goal.targetAmount))")
                        .font(.moneBodySm)
                        .foregroundStyle(Color.moneTertiary)
                }

                // Status
                Text(status.label)
                    .font(.moneBodySm)
                    .foregroundStyle(statusColor)
            }
            .padding(MoneSpacing.cardSm)
            .moneCard()
        }
        .buttonStyle(.plain)
    }
}

private extension Goal {
    func amountFormatted(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let formatted = formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
        return "₹\(formatted)"
    }
}

// MARK: - Setup Option Card

struct SetupOptionCard: View {
    let method: SetupMethod
    var isSelected: Bool = false
    var tag: String? = nil
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: MoneSpacing.gutter) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.moneActionFill.opacity(0.15) : Color.moneSurfaceEl)
                        .frame(width: 48, height: 48)
                    Image(systemName: method.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(isSelected ? Color.moneActionFill : Color.moneSecondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(method.title)
                        .font(.moneHLSm)
                        .foregroundStyle(Color.monePrimary)
                    Text(method.subtitle)
                        .font(.moneBodySm)
                        .foregroundStyle(Color.moneSecondary)
                        .lineLimit(2)
                        .padding(.bottom, 8)
                    if let tag {
                        Text(tag.uppercased())
                            .font(.moneLabelCaps)
                            .tracking(0.6)
                            .foregroundStyle(Color.moneActionFill)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.moneActionFill.opacity(0.12))
                            .clipShape(Capsule())
                            .padding(.top, 2)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isSelected ? Color.moneActionFill : Color.moneTertiary)
            }
            .padding(MoneSpacing.cardSm)
            .padding(.top, method.badge != nil ? 10 : 0)
            .background(isSelected ? Color.moneSurfaceEl : Color.moneSurface)
            .clipShape(RoundedRectangle(cornerRadius: MoneRadius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: MoneRadius.xl, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.moneStrokeBright : Color.moneStroke,
                        lineWidth: 1
                    )
            )
            .overlay(alignment: .topTrailing) {
                if let badge = method.badge {
                    Text(badge.uppercased())
                        .font(.moneLabelCaps)
                        .tracking(0.8)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.moneSecondary)
                        .clipShape(UnevenRoundedRectangle(
                            topLeadingRadius: 0,
                            bottomLeadingRadius: MoneRadius.md,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: MoneRadius.xl
                        ))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Upcoming Payment Row

struct UpcomingRow: View {
    let item: UpcomingItem

    var urgencyColor: Color {
        item.daysUntilDue <= 3 ? .moneRisk :
        item.daysUntilDue <= 7 ? .moneWatch : .moneSecondary
    }

    var body: some View {
        HStack(spacing: MoneSpacing.gutter) {
            ZStack {
                RoundedRectangle(cornerRadius: MoneRadius.sm, style: .continuous)
                    .fill(urgencyColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: item.type.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(urgencyColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.moneHLSm)
                    .foregroundStyle(Color.monePrimary)
                Text(item.daysUntilDue == 0 ? "Due today" :
                     item.daysUntilDue == 1 ? "Due tomorrow" :
                     "Due in \(item.daysUntilDue) days")
                    .font(.moneBodySm)
                    .foregroundStyle(urgencyColor)
            }

            Spacer()

            Text(item.amountFormatted)
                .font(.moneAmtSm)
                .foregroundStyle(Color.monePrimary)
        }
    }
}

private extension UpcomingItem {
    var amountFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let formatted = formatter.string(from: NSNumber(value: amount)) ?? "\(Int(amount))"
        return "₹\(formatted)"
    }
}
