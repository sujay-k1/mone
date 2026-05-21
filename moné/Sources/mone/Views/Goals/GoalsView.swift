import SwiftUI
import SwiftData
import UIKit

struct GoalsView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.modelContext) private var modelContext

    @State private var plannerGoals: [PlannerGoal] = GoalPlannerPersistence.load()
    @State private var showPlannerSheet = false
    @State private var route: PlannerSheetRoute = .pickType
    @State private var draft = PlannerDraft()
    @State private var dashboardSummary: DashboardSummary?
    @State private var moneyMapModel: MoneyMapScreenModel?
    @State private var plannerContextMessage: String?

    private let engine = GoalPlannerEngine()

    private var plannerSnapshot: PlannerFinancialSnapshot {
        PlannerFinancialSnapshot.from(
            dashboardSummary: dashboardSummary,
            moneyMapModel: moneyMapModel,
            fallbackMoneyMap: appVM.moneyMap,
            fallbackTransactions: appVM.transactions
        )
    }

    var body: some View {
        ZStack {
            Color.moneBackground.ignoresSafeArea()
            ContourBackground().opacity(0.35).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 36) {
                    DashboardHeader(
                        title: "Goals",
                        subtitle: plannerGoals.isEmpty
                            ? "Turn intentions into practical plans"
                            : "\(plannerGoals.count) active planner goal\(plannerGoals.count == 1 ? "" : "s")"
                    )
                    .padding(.top, 16)

                    if plannerGoals.isEmpty {
                        plannerContextCard
                        emptyState
                    } else {
                        plannerContextCard
                        plannerSummaryCard
                        activeGoalsSection
                        suggestedGoalsSection
                    }

                    Spacer(minLength: 28)
                }
                .padding(.horizontal, MoneSpacing.page)
            }
        }
        .sheet(isPresented: $showPlannerSheet) {
            GoalPlannerSheet(
                route: $route,
                draft: $draft,
                moneyMap: appVM.moneyMap,
                transactions: appVM.transactions,
                plannerSnapshot: plannerSnapshot,
                existingGoals: plannerGoals,
                onSave: saveGoal,
                onClose: { showPlannerSheet = false }
            )
            .presentationDetents([PresentationDetent.large])
            .presentationDragIndicator(Visibility.visible)
        }
        .task {
            await loadPlannerContext()
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: MoneSpacing.gutter) {
            GoalEducationCarousel()

            MonePrimaryButton(title: "Add your first goal", icon: "plus") {
                startCreateGoal()
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("AVAILABLE NOW")
                    .moneLabelCaps(color: .moneTertiary)
                    .tracking(2.5)

                compactCapabilityRow(
                    icon: "banknote",
                    title: "Build savings",
                    detail: "Save for emergency, home, travel, medical reserve, or a large purchase."
                )

                compactCapabilityRow(
                    icon: "slider.horizontal.3",
                    title: "Control spending",
                    detail: "Reduce one leakage area without turning the whole month into a budget exercise."
                )

                compactCapabilityRow(
                    icon: "arrow.up.right",
                    title: "Grow income",
                    detail: "Coming soon",
                    isMuted: true
                )
            }
        }
    }

    private var plannerContextCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.moneSurfaceEl)
                        .frame(width: 38, height: 38)
                    Image(systemName: dashboardSummary == nil && moneyMapModel == nil ? "clock.arrow.circlepath" : "checkmark.seal")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(dashboardSummary == nil && moneyMapModel == nil ? Color.moneWatch : Color.moneHealthy)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("PLANNER CONTEXT")
                        .moneLabelCaps(color: .moneTertiary)
                    Text(plannerSnapshot.contextLine)
                        .font(.moneBodySm.weight(.medium))
                        .foregroundStyle(Color.monePrimary)
                    if let plannerContextMessage {
                        Text(plannerContextMessage)
                            .font(.moneBodySm)
                            .foregroundStyle(Color.moneSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()
            }

            HStack(spacing: 0) {
                MiniStat(label: "Income", value: plannerSnapshot.income.plannerCurrency)
                Divider().background(Color.moneStroke).frame(height: 34)
                MiniStat(label: "Operating", value: plannerSnapshot.operatingRemaining.plannerCurrency)
                Divider().background(Color.moneStroke).frame(height: 34)
                MiniStat(label: "Capacity", value: plannerSnapshot.safeMonthlyGoalCapacity.plannerCurrency)
            }
        }
        .padding(MoneSpacing.cardSm)
        .moneCard(radius: MoneRadius.xl, elevated: true)
    }

    private var plannerSummaryCard: some View {
        HStack(spacing: 0) {
            MiniStat(label: "Monthly plan", value: totalMonthlyAction.plannerCurrency)
            Divider().background(Color.moneStroke).frame(height: 36)
            MiniStat(label: "Safe capacity", value: engine.safeMonthlyGoalCapacity(snapshot: plannerSnapshot).plannerCurrency)
            Divider().background(Color.moneStroke).frame(height: 36)
            MiniStat(label: "Goals", value: "\(plannerGoals.count)")
        }
        .padding(.vertical, MoneSpacing.cardSm)
        .moneCard(radius: MoneRadius.xl, elevated: true)
    }

    private var activeGoalsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("ACTIVE GOALS")
                    .moneLabelCaps(color: .moneTertiary)
                    .tracking(2.5)
                Spacer()
                Button {
                    startCreateGoal()
                } label: {
                    Text("ADD")
                        .font(.moneLabelCaps)
                        .tracking(1.2)
                        .foregroundStyle(Color.moneActionFill)
                }
                .buttonStyle(.plain)
            }

            ForEach(plannerGoals) { goal in
                PlannerGoalCard(goal: goal) {
                    route = .detail(goal)
                    showPlannerSheet = true
                }
            }
        }
    }

    private var suggestedGoalsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SUGGESTED BY MONÉ")
                .moneLabelCaps(color: .moneTertiary)
                .tracking(2.5)

            Button {
                draft.reset()
                draft.selectedKind = .buildSavings
                draft.savingsPurpose = .emergencyFund
                route = .savingsDetails
                showPlannerSheet = true
            } label: {
                suggestionCard(
                    icon: "shield.checkered",
                    title: "Build one safety layer",
                    detail: "Start with a small emergency fund before adding more pressure."
                )
            }
            .buttonStyle(.plain)

            Button {
                draft.reset()
                draft.selectedKind = .controlSpending
                draft.spendingFocus = .foodDelivery
                draft.spendingTargetText = "\(Int(engine.suggestedTargetSpend(for: .foodDelivery, transactions: appVM.transactions)))"
                route = .spendingFocus
                showPlannerSheet = true
            } label: {
                suggestionCard(
                    icon: "fork.knife",
                    title: "Control food delivery",
                    detail: "A repeat category that often releases money without hurting core needs."
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var totalMonthlyAction: Double {
        plannerGoals.reduce(0) { partial, goal in
            switch goal.kind {
            case .buildSavings:
                return partial + (goal.savings?.monthlyContribution ?? 0)
            case .controlSpending:
                return partial + (goal.spending?.expectedMonthlySaving ?? 0)
            }
        }
    }

    private func compactCapabilityRow(icon: String, title: String, detail: String, isMuted: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.moneSurfaceEl)
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isMuted ? Color.moneTertiary : Color.moneSecondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.moneHLSm)
                        .foregroundStyle(isMuted ? Color.moneTertiary : Color.monePrimary)

                    if isMuted {
                        Text("COMING SOON")
                            .font(.moneLabelCaps)
                            .tracking(0.8)
                            .foregroundStyle(Color.moneTertiary)
                    }
                }

                Text(detail)
                    .font(.moneBodySm)
                    .foregroundStyle(isMuted ? Color.moneTertiary : Color.moneSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(20)
        .moneCard(radius: MoneRadius.xl, elevated: true)
        .opacity(isMuted ? 0.68 : 1)
    }

    private func suggestionCard(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.moneSurfaceEl)
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.moneSecondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.moneHLSm)
                    .foregroundStyle(Color.monePrimary)
                Text(detail)
                    .font(.moneBodySm)
                    .foregroundStyle(Color.moneSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.moneTertiary)
        }
        .padding(20)
        .moneCard(radius: MoneRadius.xl, elevated: true)
    }

    @MainActor
    private func loadPlannerContext() async {
        do {
            let dashboardLoader = DashboardDataLoader(modelContext: modelContext)
            dashboardSummary = try dashboardLoader.loadLatestSummary()

            let moneyMapLoader = MoneyMapDataLoader(modelContext: modelContext)
            moneyMapModel = try moneyMapLoader.loadLatestMoneyMap()

            if dashboardSummary == nil && moneyMapModel == nil {
                plannerContextMessage = "Using the runtime estimate until processed financial data is available on this device."
            } else {
                plannerContextMessage = nil
            }
        } catch {
            dashboardSummary = nil
            moneyMapModel = nil
            plannerContextMessage = "Using the runtime estimate because processed financial data could not be loaded."
        }
    }

    private func startCreateGoal() {
        draft.reset()
        route = .pickType
        showPlannerSheet = true
    }

    private func saveGoal(_ goal: PlannerGoal) {
        plannerGoals.insert(goal, at: 0)
        GoalPlannerPersistence.save(plannerGoals)
        route = .created(goal)
    }
}

// MARK: - Empty Carousel

private struct GoalEducationCarousel: View {
    @State private var page = 0

    private let cards: [(title: String, body: String, metric: String, icon: String)] = [
        (
            "Goals are action plans",
            "Moné converts a vague intention into a target, duration, milestones, and a next action.",
            "Target → Plan → Milestones",
            "dot.scope"
        ),
        (
            "Built from your money map",
            "Plans use your income, obligations, everyday spends, and safe capacity so targets do not become fantasy.",
            "Reality checked",
            "binoculars"
        ),
        (
            "Adjust when life changes",
            "If a goal starts slipping, Moné helps you change the timeline or intensity instead of treating it as failure.",
            "Adaptive, not rigid",
            "arrow.triangle.2.circlepath"
        )
    ]

    var body: some View {
        VStack(spacing: 10) {
            TabView(selection: $page) {
                ForEach(cards.indices, id: \.self) { index in
                    carouselCard(cards[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 184)

            HStack(spacing: 6) {
                ForEach(cards.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? Color.moneActionFill : Color.moneStrokeBright)
                        .frame(width: index == page ? 18 : 6, height: 6)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: page)
        }
    }

    private func carouselCard(_ card: (title: String, body: String, metric: String, icon: String)) -> some View {
        ZStack(alignment: .topLeading) {
            ContourBackground().opacity(0.35)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(card.metric.uppercased())
                            .moneLabelCaps(color: .moneTertiary)
                        Text(card.title)
                            .font(.moneHLMd)
                            .foregroundStyle(Color.monePrimary)
                    }

                    Spacer()

                    Image(systemName: card.icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Color.moneSecondary)
                }

                Text(card.body)
                    .font(.moneBodyMd)
                    .foregroundStyle(Color.moneSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(MoneSpacing.cardSm)
        }
        .moneCard(radius: MoneRadius.xxl, elevated: true)
    }
}

// MARK: - Cards

private struct PlannerGoalCard: View {
    let goal: PlannerGoal
    let onTap: () -> Void

    var statusColor: Color {
        switch goal.status {
        case .notStarted: return .moneSecondary
        case .onTrack: return .moneHealthy
        case .watch: return .moneWatch
        case .needsAttention: return .moneRisk
        case .completed: return .moneHealthy
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.moneSurfaceEl)
                                .frame(width: 44, height: 44)
                            Image(systemName: goalIcon)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(Color.moneSecondary)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(goal.title)
                                .font(.moneHLSm)
                                .foregroundStyle(Color.monePrimary)
                            Text(goal.amountLine)
                                .font(.moneBodySm)
                                .foregroundStyle(Color.moneSecondary)
                        }
                    }

                    Spacer()

                    Text(goal.status.label.uppercased())
                        .font(.moneLabelCaps)
                        .tracking(0.8)
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(statusColor.opacity(0.12))
                        .clipShape(Capsule())
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.moneSurfaceHigh).frame(height: 6)
                        Capsule()
                            .fill(statusColor)
                            .frame(width: geo.size.width * CGFloat(goal.progressFraction), height: 6)
                    }
                }
                .frame(height: 6)

                VStack(alignment: .leading, spacing: 8) {
                    Text(goal.planLine)
                        .font(.moneBodyMd)
                        .foregroundStyle(Color.monePrimary)
                    Text(goal.nextAction)
                        .font(.moneBodySm)
                        .foregroundStyle(Color.moneSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20)
            .moneCard(radius: MoneRadius.xl, elevated: true)
        }
        .buttonStyle(.plain)
    }

    private var goalIcon: String {
        switch goal.kind {
        case .buildSavings:
            return goal.savings?.purpose.icon ?? "banknote"
        case .controlSpending:
            return goal.spending?.focus.icon ?? "slider.horizontal.3"
        }
    }
}

// MARK: - Planner Sheet

private struct GoalPlannerSheet: View {
    @Binding var route: PlannerSheetRoute
    @Binding var draft: PlannerDraft

    let moneyMap: MoneyMap
    let transactions: [Transaction]
    let plannerSnapshot: PlannerFinancialSnapshot
    let existingGoals: [PlannerGoal]
    let onSave: (PlannerGoal) -> Void
    let onClose: () -> Void

    private let engine = GoalPlannerEngine()

    var body: some View {
        ZStack {
            Color.moneBackground.ignoresSafeArea()
            ContourBackground().opacity(0.25).ignoresSafeArea()

            VStack(spacing: 0) {
                sheetHeader

                if route == .savingsDetails {
                    SavingsStickyContinueBar(
                        amount: draft.savingsAmount,
                        deadline: draft.savingsDeadline,
                        plannerSnapshot: plannerSnapshot,
                        onContinue: { route = .savingsPlan }
                    )
                    .padding(.horizontal, MoneSpacing.page)
                    .padding(.bottom, 12)
                }

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: MoneSpacing.gutter) {
                        content
                    }
                    .padding(.horizontal, MoneSpacing.page)
                    .padding(.bottom, 36)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch route {
        case .pickType:
            GoalTypeStep(draft: $draft) { kind in
                draft.selectedKind = kind
                switch kind {
                case .buildSavings:
                    route = .savingsDetails
                case .controlSpending:
                    route = .spendingFocus
                }
            }

        case .savingsDetails:
            SavingsDetailsStep(
                draft: $draft,
                moneyMap: moneyMap,
                transactions: transactions,
                plannerSnapshot: plannerSnapshot
            )

        case .savingsPlan:
            SavingsPlanStep(
                draft: $draft,
                moneyMap: moneyMap,
                transactions: transactions,
                plannerSnapshot: plannerSnapshot,
                onCreate: createSavingsGoal
            )

        case .spendingFocus:
            SpendingFocusStep(
                draft: $draft,
                transactions: transactions,
                onContinue: { route = .spendingPlan }
            )

        case .spendingPlan:
            SpendingPlanStep(
                draft: $draft,
                transactions: transactions,
                onCreate: createSpendingGoal
            )

        case .created(let goal):
            GoalDetailStep(goal: goal, created: true)

        case .detail(let goal):
            GoalDetailStep(goal: goal, created: false)
        }
    }

    private var sheetHeader: some View {
        HStack {
            Button(action: goBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.moneSecondary)
                    .frame(width: 42, height: 42)
                    .background(Color.moneSurface)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Color.moneStroke, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .opacity(canGoBack ? 1 : 0)
            .disabled(!canGoBack)

            Spacer()

            Text(headerTitle)
                .font(.moneHLSm)
                .foregroundStyle(Color.monePrimary)

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.moneSecondary)
                    .frame(width: 42, height: 42)
                    .background(Color.moneSurface)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Color.moneStroke, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, MoneSpacing.page)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private var headerTitle: String {
        switch route {
        case .pickType: return "Create goal"
        case .savingsDetails: return "Build savings"
        case .savingsPlan: return "Choose plan"
        case .spendingFocus: return "Control spending"
        case .spendingPlan: return "Choose style"
        case .created: return "Goal created"
        case .detail: return "Goal details"
        }
    }

    private var canGoBack: Bool {
        switch route {
        case .pickType, .created, .detail:
            return false
        default:
            return true
        }
    }

    private func goBack() {
        switch route {
        case .savingsDetails, .spendingFocus:
            route = .pickType
        case .savingsPlan:
            route = .savingsDetails
        case .spendingPlan:
            route = .spendingFocus
        default:
            break
        }
    }

    private func createSavingsGoal() {
        guard let purpose = draft.savingsPurpose else { return }
        let goal = engine.createSavingsGoal(
            purpose: purpose,
            targetAmount: draft.savingsAmount,
            deadline: draft.savingsDeadline,
            mode: draft.selectedMode ?? .optimalBalance,
            snapshot: plannerSnapshot,
            transactions: transactions
        )
        onSave(goal)
    }

    private func createSpendingGoal() {
        guard let focus = draft.spendingFocus else { return }
        let goal = engine.createSpendingGoal(
            focus: focus,
            targetSpend: draft.spendingTarget,
            durationDays: draft.spendingDurationDays,
            mode: draft.selectedMode ?? .optimalBalance,
            transactions: transactions
        )
        onSave(goal)
    }
}

// MARK: - Sheet Steps

private enum SavingsField {
    case amount
}

private struct GoalTypeStep: View {
    @Binding var draft: PlannerDraft
    var onSelect: (PlannerGoalKind) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MoneSpacing.gutter) {
            intro(
                title: "What do you want Moné to help you with?",
                subtitle: "Pick one area. Moné will turn it into a realistic plan with milestones."
            )

            ForEach(PlannerGoalKind.allCases) { kind in
                Button { onSelect(kind) } label: {
                    selectableRow(
                        icon: kind.icon,
                        title: kind.title,
                        subtitle: kind.subtitle,
                        isSelected: draft.selectedKind == kind
                    )
                }
                .buttonStyle(.plain)
            }

            selectableRow(
                icon: "arrow.up.right",
                title: "Grow income",
                subtitle: "Plan a raise, job switch, side income, or freelance target.",
                isSelected: false,
                tag: "COMING SOON",
                isDisabled: true
            )
        }
    }
}

private struct SavingsStickyContinueBar: View {
    let amount: Double
    let deadline: Date
    let plannerSnapshot: PlannerFinancialSnapshot
    let onContinue: () -> Void

    private let engine = GoalPlannerEngine()

    private var isReady: Bool {
        amount > 0 &&
        deadline > Date() &&
        !engine.isSavingsGoalUnrealistic(amount: amount, deadline: deadline, snapshot: plannerSnapshot)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onContinue) {
                HStack(spacing: 8) {
                    Text("Continue")
                        .font(.moneHLSm)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(isReady ? Color.moneActionFg : Color.moneTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(isReady ? Color.moneActionFill : Color.moneSurface)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(isReady ? Color.clear : Color.moneStroke, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(!isReady)

            HStack {
                Text("Safe monthly capacity")
                    .font(.moneBodySm)
                    .foregroundStyle(Color.moneTertiary)
                Spacer()
                Text(engine.safeMonthlyGoalCapacity(snapshot: plannerSnapshot).plannerCurrency)
                    .font(.moneBodySm.weight(.medium))
                    .foregroundStyle(Color.moneSecondary)
            }
        }
        .padding(MoneSpacing.cardSm)
        .background(Color.moneBackground.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: MoneRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MoneRadius.xl, style: .continuous)
                .strokeBorder(Color.moneStroke, lineWidth: 1)
        )
    }
}

private struct SavingsDetailsStep: View {
    @Binding var draft: PlannerDraft
    let moneyMap: MoneyMap
    let transactions: [Transaction]
    let plannerSnapshot: PlannerFinancialSnapshot

    @FocusState private var focusedField: SavingsField?
    private let engine = GoalPlannerEngine()

    var body: some View {
        VStack(alignment: .leading, spacing: MoneSpacing.gutter) {
            intro(
                title: "What are you saving for?",
                subtitle: "Choose a purpose, then add the target amount and deadline."
            )

            ForEach(PlannerSavingsPurpose.allCases) { purpose in
                SavingsPurposeCard(
                    purpose: purpose,
                    isSelected: draft.savingsPurpose == purpose,
                    amountText: $draft.savingsAmountText,
                    deadline: $draft.savingsDeadline,
                    focusedField: $focusedField,
                    moneyMap: moneyMap,
                    transactions: transactions,
                    plannerSnapshot: plannerSnapshot,
                    onSelect: { draft.savingsPurpose = purpose }
                )
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = nil
            Keyboard.dismiss()
        }
    }
}

private struct SavingsPurposeCard: View {
    let purpose: PlannerSavingsPurpose
    let isSelected: Bool
    @Binding var amountText: String
    @Binding var deadline: Date
    var focusedField: FocusState<SavingsField?>.Binding
    let moneyMap: MoneyMap
    let transactions: [Transaction]
    let plannerSnapshot: PlannerFinancialSnapshot
    let onSelect: () -> Void

    private let engine = GoalPlannerEngine()

    private var amount: Double { Double(amountText.plannerNumericOnly) ?? 0 }
    private var warning: String? {
        guard isSelected else { return nil }
        return engine.savingsFeasibilityMessage(
            amount: amount,
            deadline: deadline,
            snapshot: plannerSnapshot
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: onSelect) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(isSelected ? Color.moneActionFill.opacity(0.15) : Color.moneSurfaceEl)
                            .frame(width: 46, height: 46)
                        Image(systemName: purpose.icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(isSelected ? Color.moneActionFill : Color.moneSecondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(purpose.title)
                            .font(.moneHLSm)
                            .foregroundStyle(Color.monePrimary)
                        Text(purpose.detail)
                            .font(.moneBodySm)
                            .foregroundStyle(Color.moneSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(isSelected ? Color.moneActionFill : Color.moneTertiary)
                }
            }
            .buttonStyle(.plain)

            if isSelected {
                VStack(alignment: .leading, spacing: 16) {
                    MoneField(label: "TARGET AMOUNT") {
                        HStack(spacing: 8) {
                            Text("₹")
                                .font(.moneAmtSm)
                                .foregroundStyle(Color.moneSecondary)
                            TextField("3,00,000", text: $amountText)
                                .keyboardType(.decimalPad)
                                .focused(focusedField, equals: .amount)
                                .moneFieldStyle()
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("DEADLINE")
                            .moneLabelCaps(color: .moneTertiary)

                        HStack(alignment: .center, spacing: 12) {
                            DatePicker("", selection: $deadline, in: Date()..., displayedComponents: .date)
                                .labelsHidden()
                                .tint(Color.moneActionFill)

                            Spacer()

                            Text(engine.deadlineDistanceLabel(from: deadline).uppercased())
                                .font(.moneLabelCaps)
                                .tracking(0.8)
                                .foregroundStyle(Color.moneActionFill)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.moneActionFill.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }

                    if let warning {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.moneWatch)
                            Text(warning)
                                .font(.moneBodySm)
                                .foregroundStyle(Color.moneSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(MoneSpacing.cardSm)
                        .background(Color.moneWatchBg)
                        .clipShape(RoundedRectangle(cornerRadius: MoneRadius.lg, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: MoneRadius.lg, style: .continuous)
                                .strokeBorder(Color.moneWatch.opacity(0.35), lineWidth: 1)
                        )
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(MoneSpacing.cardSm)
        .background(isSelected ? Color.moneSurfaceEl : Color.moneSurface)
        .clipShape(RoundedRectangle(cornerRadius: MoneRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MoneRadius.xl, style: .continuous)
                .strokeBorder(isSelected ? Color.moneStrokeBright : Color.moneStroke, lineWidth: 1)
        )
    }
}

private struct SavingsPlanStep: View {
    @Binding var draft: PlannerDraft
    let moneyMap: MoneyMap
    let transactions: [Transaction]
    let plannerSnapshot: PlannerFinancialSnapshot
    let onCreate: () -> Void

    private let engine = GoalPlannerEngine()

    private var previews: [PlannerPlanPreview] {
        guard let purpose = draft.savingsPurpose else { return [] }
        return engine.savingsPlanPreviews(
            purpose: purpose,
            targetAmount: draft.savingsAmount,
            deadline: draft.savingsDeadline,
            snapshot: plannerSnapshot
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MoneSpacing.gutter) {
            intro(
                title: "Choose how you want to reach this goal",
                subtitle: "Swipe through or tap a card. Only one plan can be active."
            )

            PlannerPlanCardDeck(previews: previews, selectedMode: $draft.selectedMode)
                .frame(height: 360)

            MonePrimaryButton(title: "Create goal", icon: "checkmark") {
                onCreate()
            }
            .disabled(draft.selectedMode == nil)
            .opacity(draft.selectedMode == nil ? 0.45 : 1)
        }
        .onAppear {
            if draft.selectedMode == nil { draft.selectedMode = .optimalBalance }
        }
    }
}

private struct SpendingFocusStep: View {
    @Binding var draft: PlannerDraft
    let transactions: [Transaction]
    let onContinue: () -> Void

    @FocusState private var targetFocused: Bool
    private let engine = GoalPlannerEngine()

    private var suggested: [PlannerSpendingFocus] { [.foodDelivery, .shopping, .subscriptions, .upiSmallSpends] }
    private var own: [PlannerSpendingFocus] { [.entertainment, .travel, .custom] }
    private var canContinue: Bool { draft.spendingFocus != nil && draft.spendingTarget > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: MoneSpacing.gutter) {
            intro(
                title: "Where do you want more control?",
                subtitle: "Pick one area. Moné will turn the current pattern into a target and milestones."
            )

            focusGroup(title: "SUGGESTED BY MONÉ", items: suggested)
            focusGroup(title: "CHOOSE YOUR OWN", items: own)

            MonePrimaryButton(title: "Continue", icon: "arrow.right") {
                onContinue()
            }
            .disabled(!canContinue)
            .opacity(canContinue ? 1 : 0.45)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            targetFocused = false
            Keyboard.dismiss()
        }
    }

    private func focusGroup(title: String, items: [PlannerSpendingFocus]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .moneLabelCaps(color: .moneTertiary)

            ForEach(items) { focus in
                SpendingFocusCard(
                    focus: focus,
                    isSelected: draft.spendingFocus == focus,
                    targetText: $draft.spendingTargetText,
                    durationDays: $draft.spendingDurationDays,
                    isTargetFocused: $targetFocused,
                    baseline: engine.baselineSpend(for: focus, transactions: transactions),
                    suggestedTarget: engine.suggestedTargetSpend(for: focus, transactions: transactions)
                ) {
                    draft.spendingFocus = focus
                    if draft.spendingTargetText.isEmpty {
                        draft.spendingTargetText = "\(Int(engine.suggestedTargetSpend(for: focus, transactions: transactions)))"
                    }
                }
            }
        }
    }
}

private struct SpendingFocusCard: View {
    let focus: PlannerSpendingFocus
    let isSelected: Bool
    @Binding var targetText: String
    @Binding var durationDays: Int
    var isTargetFocused: FocusState<Bool>.Binding
    let baseline: Double
    let suggestedTarget: Double
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: onSelect) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(isSelected ? Color.moneActionFill.opacity(0.15) : Color.moneSurfaceEl)
                            .frame(width: 46, height: 46)
                        Image(systemName: focus.icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(isSelected ? Color.moneActionFill : Color.moneSecondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(focus.title)
                            .font(.moneHLSm)
                            .foregroundStyle(Color.monePrimary)
                        Text("\(baseline.plannerCurrency)/month · \(focus.detail)")
                            .font(.moneBodySm)
                            .foregroundStyle(Color.moneSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(isSelected ? Color.moneActionFill : Color.moneTertiary)
                }
            }
            .buttonStyle(.plain)

            if isSelected {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 0) {
                        MiniStat(label: "Baseline", value: baseline.plannerCurrency)
                        Divider().background(Color.moneStroke).frame(height: 36)
                        MiniStat(label: "Suggested", value: suggestedTarget.plannerCurrency)
                    }
                    .padding(.vertical, 12)
                    .background(Color.moneSurface)
                    .clipShape(RoundedRectangle(cornerRadius: MoneRadius.lg, style: .continuous))

                    MoneField(label: "TARGET PER MONTH") {
                        HStack(spacing: 8) {
                            Text("₹")
                                .font(.moneAmtSm)
                                .foregroundStyle(Color.moneSecondary)
                            TextField("8,500", text: $targetText)
                                .keyboardType(.decimalPad)
                                .focused(isTargetFocused)
                                .moneFieldStyle()
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("DURATION")
                            .moneLabelCaps(color: .moneTertiary)

                        HStack(spacing: 8) {
                            durationChip(30)
                            durationChip(60)
                            durationChip(90)
                        }
                    }
                }
            }
        }
        .padding(MoneSpacing.cardSm)
        .background(isSelected ? Color.moneSurfaceEl : Color.moneSurface)
        .clipShape(RoundedRectangle(cornerRadius: MoneRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MoneRadius.xl, style: .continuous)
                .strokeBorder(isSelected ? Color.moneStrokeBright : Color.moneStroke, lineWidth: 1)
        )
    }

    private func durationChip(_ days: Int) -> some View {
        Button {
            durationDays = days
        } label: {
            Text("\(days) days")
                .font(.moneBodySm)
                .foregroundStyle(durationDays == days ? Color.moneActionFg : Color.moneSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(durationDays == days ? Color.moneActionFill : Color.clear)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(durationDays == days ? Color.clear : Color.moneStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct SpendingPlanStep: View {
    @Binding var draft: PlannerDraft
    let transactions: [Transaction]
    let onCreate: () -> Void

    private let engine = GoalPlannerEngine()

    private var previews: [PlannerPlanPreview] {
        guard let focus = draft.spendingFocus else { return [] }
        return engine.spendingPlanPreviews(focus: focus, targetSpend: draft.spendingTarget, transactions: transactions)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MoneSpacing.gutter) {
            intro(
                title: "Choose your control style",
                subtitle: "Swipe through or tap a card. The mode controls strictness, alerts, and recovery."
            )

            PlannerPlanCardDeck(previews: previews, selectedMode: $draft.selectedMode)
                .frame(height: 360)

            MonePrimaryButton(title: "Create goal", icon: "checkmark") {
                onCreate()
            }
            .disabled(draft.selectedMode == nil)
            .opacity(draft.selectedMode == nil ? 0.45 : 1)
        }
        .onAppear {
            if draft.selectedMode == nil { draft.selectedMode = .optimalBalance }
        }
    }
}

// MARK: - Plan Deck

private struct PlannerPlanCardDeck: View {
    let previews: [PlannerPlanPreview]
    @Binding var selectedMode: PlannerPlanMode?

    @State private var frontIndex = 0
    @State private var dragOffset: CGSize = .zero
    @State private var dragRotation: Double = 0

    private struct Slot {
        let offset: CGSize
        let rotation: Double
        let scale: CGFloat
    }

    private let slots = [
        Slot(offset: CGSize(width: 0, height: 86), rotation: 5, scale: 1.0),
        Slot(offset: CGSize(width: 0, height: -8), rotation: -2, scale: 0.96),
        Slot(offset: CGSize(width: -8, height: -102), rotation: -9, scale: 0.92)
    ]

    var body: some View {
        GeometryReader { geo in
            let cardWidth = min(geo.size.width * 0.92, 360)
            let cardHeight = min(cardWidth * 0.78, 270)

            ZStack {
                ForEach(Array(previews.enumerated()), id: \.element.id) { index, preview in
                    let slot = slotOf(index)
                    if slot < min(3, previews.count) {
                        let config = slots[slot]
                        let isFront = slot == 0
                        let isSelected = selectedMode == preview.mode

                        PlanStackCard(
                            preview: preview,
                            isSelected: isSelected,
                            showDetail: isFront
                        )
                        .frame(width: cardWidth, height: cardHeight)
                        .scaleEffect(config.scale)
                        .rotationEffect(.degrees(isFront ? config.rotation + dragRotation : config.rotation))
                        .offset(isFront ? CGSize(width: config.offset.width + dragOffset.width, height: config.offset.height + dragOffset.height) : config.offset)
                        .shadow(color: .black.opacity(isFront ? 0.18 : 0.08), radius: isFront ? 12 : 6, y: 4)
                        .zIndex(Double(previews.count - slot))
                        .contentShape(RoundedRectangle(cornerRadius: MoneRadius.xxl, style: .continuous))
                        .onTapGesture {
                            if isFront {
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                                    selectedMode = preview.mode
                                }
                            } else {
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                                    frontIndex = index
                                    selectedMode = preview.mode
                                }
                            }
                        }
                        .gesture(
                            DragGesture(minimumDistance: 8)
                                .onChanged { value in
                                    guard isFront else { return }
                                    dragOffset = value.translation
                                    dragRotation = value.translation.width * 0.035
                                }
                                .onEnded { value in
                                    guard isFront else { return }
                                    if abs(value.translation.width) > 80 {
                                        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                                            frontIndex = nextIndex(direction: value.translation.width > 0 ? 1 : -1)
                                            dragOffset = .zero
                                            dragRotation = 0
                                        }
                                    } else {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                            dragOffset = .zero
                                            dragRotation = 0
                                        }
                                    }
                                }
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func slotOf(_ index: Int) -> Int {
        guard !previews.isEmpty else { return 0 }
        return (index - frontIndex + previews.count) % previews.count
    }

    private func nextIndex(direction: Int) -> Int {
        guard !previews.isEmpty else { return 0 }
        return (frontIndex + direction + previews.count) % previews.count
    }
}

private struct PlanStackCard: View {
    let preview: PlannerPlanPreview
    let isSelected: Bool
    let showDetail: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(preview.headline)
                        .font(.moneHL)
                        .foregroundStyle(Color.monePrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(preview.isRecommended ? "RECOMMENDED" : preview.mode.shortLabel)
                        .font(.moneLabelCaps)
                        .tracking(1.5)
                        .foregroundStyle(preview.isRecommended ? Color.moneCelebration : Color.moneSecondary)
                }

                Spacer()

                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.clear : Color.moneStrokeMid, lineWidth: 1.5)
                        .frame(width: 28, height: 28)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(preview.isRecommended ? Color.moneCelebration : Color.moneActionFill)
                    }
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(preview.monthlyAction.plannerCurrency)
                        .font(.moneAmtMd)
                        .foregroundStyle(Color.monePrimary)
                    Text("/mo")
                        .font(.moneBodySm)
                        .foregroundStyle(Color.moneTertiary)
                }

                Text(preview.impact)
                    .font(.moneLabelCaps)
                    .tracking(1.1)
                    .foregroundStyle(preview.isRecommended ? Color.moneCelebration : Color.moneSecondary)

                if showDetail {
                    Text(preview.detail)
                        .font(.moneBodySm)
                        .foregroundStyle(Color.moneSecondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(preview.bullets.prefix(3), id: \.self) { bullet in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.moneSecondary)
                                    .padding(.top, 2)
                                Text(bullet)
                                    .font(.moneBodySm)
                                    .foregroundStyle(Color.moneSecondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(MoneSpacing.cardLg)
        .background(
            RoundedRectangle(cornerRadius: MoneRadius.xxl, style: .continuous)
                .fill(isSelected ? Color.moneSurfaceEl : Color.moneSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: MoneRadius.xxl, style: .continuous)
                .strokeBorder(isSelected ? Color.moneStrokeBright : Color.moneStroke, lineWidth: 1)
        )
    }
}

// MARK: - Detail

private struct GoalDetailStep: View {
    let goal: PlannerGoal
    let created: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: MoneSpacing.gutter) {
            intro(
                title: created ? "\(goal.title) is ready" : goal.title,
                subtitle: created
                    ? "Your plan now has a target, monthly action, next step, and milestones."
                    : "Here is the current plan and milestone path."
            )

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(goal.amountLine)
                            .font(.moneHLMd)
                            .foregroundStyle(Color.monePrimary)
                        Text(goal.planLine)
                            .font(.moneBodySm)
                            .foregroundStyle(Color.moneSecondary)
                    }

                    Spacer()

                    Text(goal.status.label.uppercased())
                        .font(.moneLabelCaps)
                        .tracking(0.8)
                        .foregroundStyle(Color.moneSecondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.moneSurfaceEl)
                        .clipShape(Capsule())
                }

                ProgressView(value: goal.progressFraction)
                    .tint(Color.moneActionFill)

                detailRows

                Divider().background(Color.moneStroke)

                VStack(alignment: .leading, spacing: 6) {
                    Text("NEXT ACTION")
                        .moneLabelCaps(color: .moneTertiary)
                    Text(goal.nextAction)
                        .font(.moneBodyMd)
                        .foregroundStyle(Color.monePrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20)
            .moneCard(radius: MoneRadius.xl, elevated: true)

            VStack(alignment: .leading, spacing: 14) {
                Text("MILESTONES")
                    .tracking(2.5)
                    .moneLabelCaps(color: .moneTertiary)

                ForEach(goal.milestones) { milestone in
                    MilestoneRow(milestone: milestone)
                }
            }
        }
    }

    @ViewBuilder
    private var detailRows: some View {
        VStack(spacing: 10) {
            switch goal.kind {
            case .buildSavings:
                if let savings = goal.savings {
                    keyValue("Target", savings.targetAmount.plannerCurrency)
                    keyValue("Deadline", savings.desiredDeadline.plannerMonthYear)
                    keyValue("Projected finish", savings.projectedCompletionDate.plannerMonthYear)
                    keyValue("Safe capacity", savings.safeMonthlyCapacity.plannerCurrency)
                }
            case .controlSpending:
                if let spending = goal.spending {
                    keyValue("Baseline", "\(spending.baselineMonthlySpend.plannerCurrency)/mo")
                    keyValue("Target", "\(spending.targetMonthlySpend.plannerCurrency)/mo")
                    keyValue("Expected saving", "\(spending.expectedMonthlySaving.plannerCurrency)/mo")
                    keyValue("Duration", "\(spending.durationDays) days")
                }
            }
        }
    }

    private func keyValue(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key.uppercased())
                .font(.moneLabelCaps)
                .foregroundStyle(Color.moneTertiary)
            Spacer()
            Text(value)
                .font(.moneBodySm.weight(.medium))
                .foregroundStyle(Color.monePrimary)
        }
    }
}

private struct MilestoneRow: View {
    let milestone: PlannerMilestone

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(milestone.isCompleted ? Color.moneHealthy : Color.moneSurfaceEl)
                    .frame(width: 30, height: 30)
                Image(systemName: milestone.isCompleted ? "checkmark" : "circle.fill")
                    .font(.system(size: milestone.isCompleted ? 12 : 6, weight: .bold))
                    .foregroundStyle(milestone.isCompleted ? Color.moneBackground : Color.moneSecondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(milestone.title)
                    .font(.moneHLSm)
                    .foregroundStyle(Color.monePrimary)
                Text(milestone.detail)
                    .font(.moneBodySm)
                    .foregroundStyle(Color.moneSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(20)
        .moneCard(radius: MoneRadius.xl, elevated: true)
    }
}

// MARK: - Shared UI Helpers

private func intro(title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Text(title)
            .font(.moneHLMd)
            .foregroundStyle(Color.monePrimary)
            .fixedSize(horizontal: false, vertical: true)

        Text(subtitle)
            .font(.moneBodyMd)
            .foregroundStyle(Color.moneSecondary)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private func selectableRow(
    icon: String,
    title: String,
    subtitle: String,
    isSelected: Bool,
    tag: String? = nil,
    isDisabled: Bool = false
) -> some View {
    HStack(alignment: .top, spacing: 12) {
        ZStack {
            Circle()
                .fill(isSelected ? Color.moneActionFill.opacity(0.15) : Color.moneSurfaceEl)
                .frame(width: 46, height: 46)
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(isSelected ? Color.moneActionFill : isDisabled ? Color.moneTertiary : Color.moneSecondary)
        }

        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.moneHLSm)
                    .foregroundStyle(isDisabled ? Color.moneTertiary : Color.monePrimary)
                if let tag {
                    Text(tag)
                        .font(.moneLabelCaps)
                        .tracking(0.8)
                        .foregroundStyle(Color.moneTertiary)
                }
            }
            Text(subtitle)
                .font(.moneBodySm)
                .foregroundStyle(isDisabled ? Color.moneTertiary : Color.moneSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }

        Spacer()

        if !isDisabled {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(isSelected ? Color.moneActionFill : Color.moneTertiary)
        }
    }
    .padding(MoneSpacing.cardSm)
    .background(isSelected ? Color.moneSurfaceEl : Color.moneSurface)
    .clipShape(RoundedRectangle(cornerRadius: MoneRadius.xl, style: .continuous))
    .overlay(
        RoundedRectangle(cornerRadius: MoneRadius.xl, style: .continuous)
            .strokeBorder(isSelected ? Color.moneStrokeBright : Color.moneStroke, lineWidth: 1)
    )
    .opacity(isDisabled ? 0.62 : 1)
}

private enum Keyboard {
    static func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

#Preview {
    GoalsView()
        .environment(AppViewModel())
}
