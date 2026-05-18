import SwiftUI

struct GoalsView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var showScenario = false
    @State private var scenarioAmount: Double = 0
    @State private var scenarioName: String = ""
    @State private var scenarioResult: String? = nil

    var goals: [Goal] { appVM.moneyMap.goals }

    var body: some View {
        ZStack {
            Color.moneBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: MoneSpacing.gutter) {

                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("moné").font(.moneLabelCaps).tracking(1.5).foregroundStyle(Color.moneTertiary)
                            Text("Goals").font(.moneHLMd).foregroundStyle(Color.monePrimary)
                        }
                        Spacer()
                        Text("\(appVM.goalsOnTrack)/\(goals.count) on track")
                            .font(.moneBodySm)
                            .foregroundStyle(Color.moneSecondary)
                    }
                    .padding(.top, 16)

                    // Summary card
                    HStack(spacing: 0) {
                        MiniStat(label: "Monthly allocation", value: appVM.formatted(appVM.moneyMap.totalGoalAllocation))
                        Divider().background(Color.moneStroke).frame(height: 36)
                        MiniStat(label: "Left after goals", value: appVM.safeToSpend.monthlyFormatted)
                        Divider().background(Color.moneStroke).frame(height: 36)
                        MiniStat(label: "Goals", value: "\(goals.count)")
                    }
                    .padding(.vertical, MoneSpacing.cardSm)
                    .moneCard()

                    // Goals list
                    Text("YOUR GOALS")
                        .moneLabelCaps()

                    ForEach(goals.sorted { $0.priority.sortOrder < $1.priority.sortOrder }) { goal in
                        GoalDetailCard(goal: goal)
                    }

                    // Scenario check
                    VStack(alignment: .leading, spacing: MoneSpacing.gap) {
                        Text("SCENARIO CHECK")
                            .moneLabelCaps()

                        VStack(alignment: .leading, spacing: MoneSpacing.gutter) {
                            Text("Can I afford this?")
                                .font(.moneHLSm)
                                .foregroundStyle(Color.monePrimary)
                            Text("Enter a planned purchase to see impact on your goals.")
                                .font(.moneBodySm)
                                .foregroundStyle(Color.moneSecondary)

                            TextField("What do you want to buy?", text: $scenarioName)
                                .font(.moneBodyLg)
                                .foregroundStyle(Color.monePrimary)
                                .tint(Color.moneActionFill)
                                .padding(MoneSpacing.cardSm)
                                .background(Color.moneSurfaceEl)
                                .clipShape(RoundedRectangle(cornerRadius: MoneRadius.lg, style: .continuous))

                            HStack(spacing: 8) {
                                Text("₹").font(.moneAmtSm).foregroundStyle(Color.moneSecondary)
                                TextField("Amount", value: $scenarioAmount, format: .number)
                                    .font(.moneAmtSm)
                                    .foregroundStyle(Color.monePrimary)
                                    .keyboardType(.decimalPad)
                                    .tint(Color.moneActionFill)
                            }
                            .padding(MoneSpacing.cardSm)
                            .background(Color.moneSurfaceEl)
                            .clipShape(RoundedRectangle(cornerRadius: MoneRadius.lg, style: .continuous))

                            if let result = scenarioResult {
                                Text(result)
                                    .font(.moneBodyMd)
                                    .foregroundStyle(Color.moneSecondary)
                                    .padding(MoneSpacing.cardSm)
                                    .moneCard()
                                    .transition(.opacity)
                            }

                            MonePrimaryButton(title: "Check impact") {
                                runScenario()
                            }
                            .disabled(scenarioAmount <= 0)
                            .opacity(scenarioAmount > 0 ? 1 : 0.4)
                        }
                        .padding(MoneSpacing.cardSm)
                        .moneCard()
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, MoneSpacing.page)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: scenarioResult)
    }

    private func runScenario() {
        let impact = SafeToSpendCalculator.impactOfPayment(
            amount: scenarioAmount,
            moneyMap: appVM.moneyMap,
            spentThisWeek: appVM.spentThisWeek
        )

        // Check goal impact
        var goalImpact = ""
        for goal in goals.filter({ $0.priority == .mustProtect || $0.priority == .important }) {
            if let delay = GoalProjectionCalculator.impactOnGoal(goal: goal, extraSpend: scenarioAmount), delay > 0 {
                goalImpact = " This may delay \(goal.name) by \(delay) day\(delay == 1 ? "" : "s")."
                break
            }
        }

        let name = scenarioName.isEmpty ? "This purchase" : scenarioName
        if impact.isOverBudget {
            scenarioResult = "\(name) at ₹\(Int(scenarioAmount)) would push you ₹\(Int(abs(impact.remainingAfterPayment))) over your weekly budget.\(goalImpact) Still worth it?"
        } else {
            scenarioResult = "\(name) is within budget. It leaves ₹\(Int(impact.remainingAfterPayment)) for the rest of the week.\(goalImpact)"
        }
    }
}

// MARK: - Goal Detail Card

struct GoalDetailCard: View {
    let goal: Goal
    var status: GoalStatus { GoalProjectionCalculator.status(for: goal) }

    var statusColor: Color {
        switch status {
        case .onTrack: return .moneHealthy
        case .atRisk:  return .moneWatch
        case .completed: return .moneHealthy
        case .noDeadline: return .moneSecondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MoneSpacing.gap) {
            // Header
            HStack(alignment: .top) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.moneSurfaceEl)
                            .frame(width: 36, height: 36)
                        Image(systemName: goal.type.icon)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.moneSecondary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(goal.name)
                            .font(.moneHLSm)
                            .foregroundStyle(Color.monePrimary)
                        PriorityChip(priority: goal.priority)
                    }
                }
                Spacer()
                HealthChip(status: status == .onTrack ? .healthy : status.isAtRisk ? .watch : .healthy)
            }

            // Progress
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.moneSurfaceHigh).frame(height: 6)
                    Capsule()
                        .fill(statusColor)
                        .frame(width: geo.size.width * CGFloat(goal.progressFraction), height: 6)
                }
            }
            .frame(height: 6)

            // Amounts
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Saved")
                        .font(.moneBodySm).foregroundStyle(Color.moneTertiary)
                    Text(formatAmt(goal.alreadySaved))
                        .font(.moneAmtSm).foregroundStyle(Color.monePrimary)
                }
                Spacer()
                VStack(alignment: .center, spacing: 2) {
                    Text("Target")
                        .font(.moneBodySm).foregroundStyle(Color.moneTertiary)
                    Text(formatAmt(goal.targetAmount))
                        .font(.moneAmtSm).foregroundStyle(Color.moneSecondary)
                }
                Spacer()
                if let alloc = goal.requiredMonthlyAllocation {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Monthly")
                            .font(.moneBodySm).foregroundStyle(Color.moneTertiary)
                        Text(formatAmt(alloc) + "/mo")
                            .font(.moneAmtSm).foregroundStyle(Color.monePrimary)
                    }
                }
            }

            // Status row
            HStack(spacing: 4) {
                Image(systemName: status == .onTrack ? "checkmark.circle" : "clock")
                    .font(.system(size: 12))
                    .foregroundStyle(statusColor)
                Text(status.label)
                    .font(.moneBodySm)
                    .foregroundStyle(statusColor)

                if let deadline = goal.deadline {
                    Text("·")
                        .foregroundStyle(Color.moneTertiary)
                    Text("Deadline: \(deadline, format: .dateTime.month().year())")
                        .font(.moneBodySm)
                        .foregroundStyle(Color.moneTertiary)
                }
            }
        }
        .padding(MoneSpacing.cardSm)
        .moneCard()
    }

    private func formatAmt(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal; f.maximumFractionDigits = 0
        let s = f.string(from: NSNumber(value: v)) ?? "\(Int(v))"
        return "₹\(s)"
    }
}

#Preview {
    GoalsView()
        .environment(AppViewModel())
}
