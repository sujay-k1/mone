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
    @State private var plannerMonthlyContexts: [PlannerMonthlyFinancialContext] = []
    @State private var plannerTransactions: [Transaction] = []
    @State private var plannerContextError: String?
    @State private var isLoadingPlannerContext = false

    private let engine = GoalPlannerEngine()

    private var processedPlannerSnapshot: PlannerFinancialSnapshot? {
        PlannerFinancialSnapshot.fromProcessed(
            dashboardSummary: dashboardSummary,
            moneyMapModel: moneyMapModel,
            monthlyContexts: plannerMonthlyContexts
        )
    }

    private var hasProcessedPlannerContext: Bool {
        processedPlannerSnapshot != nil && !plannerTransactions.isEmpty
    }

    var body: some View {
        ZStack {
            Color.moneBackground.ignoresSafeArea()
            ContourBackground().opacity(0.35).ignoresSafeArea()

            if plannerGoals.isEmpty {
                GeometryReader { geo in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 24) {
                            VStack(alignment: .leading, spacing: 36) {
                                DashboardHeader(
                                    title: "Goals",
                                    tag: "GET STARTED"
                                )

                                suggestedGoalsSection
                            }
                            .padding(.horizontal, MoneSpacing.page)

                            GoalEducationCarousel()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .frame(
                            width: geo.size.width,
                            height: geo.size.height + geo.safeAreaInsets.bottom,
                            alignment: .top
                        )
                    }
                    .scrollDisabled(true)
                }
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 36) {
                        DashboardHeader(
                            title: "Goals",
                            tag: "\(plannerGoals.count) active planner goal\(plannerGoals.count == 1 ? "" : "s")"
                        )

                        plannerSummaryCard
                        activeGoalsSection
                        suggestedGoalsSection

                        Spacer(minLength: 28)
                    }
                    .padding(.horizontal, MoneSpacing.page)
                }
            }
        }
        .sheet(isPresented: $showPlannerSheet) {
            GoalPlannerSheet(
                route: $route,
                draft: $draft,
                transactions: plannerTransactions,
                plannerSnapshot: processedPlannerSnapshot,
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

    private var plannerSummaryCard: some View {
        HStack(spacing: 0) {
            MiniStat(label: "Monthly plan", value: totalMonthlyAction.plannerCurrency)
            Divider().background(Color.moneStroke).frame(height: 36)
            MiniStat(label: "Safe capacity", value: processedPlannerSnapshot.map { engine.safeMonthlyGoalCapacity(snapshot: $0).plannerCurrency } ?? "Not ready")
            Divider().background(Color.moneStroke).frame(height: 36)
            MiniStat(label: "Goals", value: "\(plannerGoals.count)")
        }
        .padding(.vertical, 20)
        .moneCard(radius: MoneRadius.xl, elevated: true)
    }

    private var activeGoalsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
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
        VStack(alignment: .leading, spacing: 20) {
            if !hasProcessedPlannerContext {
                plannerContextUnavailableCard
            }

            MonePrimaryButton(title: "Build a goal", icon: "plus") {
                startBuildCorpusGoal()
            }
            .disabled(isLoadingPlannerContext || !hasProcessedPlannerContext)
            .opacity(isLoadingPlannerContext || !hasProcessedPlannerContext ? 0.55 : 1)

            Button {
                startSuggestedSavingsGoal()
            } label: {
                suggestionCard(
                    icon: "shield.checkered",
                    title: "Build one safety layer",
                    detail: "Start with a small emergency fund before adding more pressure."
                )
            }
            .buttonStyle(.plain)
            .disabled(isLoadingPlannerContext || !hasProcessedPlannerContext)
            .opacity(isLoadingPlannerContext || !hasProcessedPlannerContext ? 0.55 : 1)

            Button {
                startSuggestedSpendingGoal()
            } label: {
                suggestionCard(
                    icon: "fork.knife",
                    title: "Control food delivery",
                    detail: "A repeat category that often releases money without hurting core needs."
                )
            }
            .buttonStyle(.plain)
            .disabled(isLoadingPlannerContext || !hasProcessedPlannerContext)
            .opacity(isLoadingPlannerContext || !hasProcessedPlannerContext ? 0.55 : 1)
        }
    }

    private var plannerContextUnavailableCard: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.moneWatchBg)
                    .frame(width: 46, height: 46)
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.moneWatch)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(isLoadingPlannerContext ? "Loading financial data" : "Financial data not ready")
                    .font(.moneHLSm)
                    .foregroundStyle(Color.monePrimary)
                Text(plannerContextError ?? "Goals needs the processed Money Map data before it can create recommendations.")
                    .font(.moneBodySm)
                    .foregroundStyle(Color.moneSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(MoneSpacing.cardLg)
        .moneCard(radius: MoneRadius.xl, elevated: true)
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

    private func suggestionCard(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.moneSurfaceEl)
                    .frame(width: 46, height: 46)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.moneSecondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.moneHLSm)
                    .foregroundStyle(Color.monePrimary)
                Text(detail)
                    .font(.moneBodySm)
                    .foregroundStyle(Color.moneSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.moneTertiary)
                .padding(.top, 2)
        }
        .padding(MoneSpacing.cardLg)
        .moneCard(radius: MoneRadius.xl, elevated: true)
    }

    @MainActor
    private func loadPlannerContext() async {
        isLoadingPlannerContext = true
        plannerContextError = nil
        defer { isLoadingPlannerContext = false }

        if hasProcessedPlannerContext {
            return
        }

        dashboardSummary = nil
        moneyMapModel = nil
        plannerMonthlyContexts = []
        plannerTransactions = []

        do {
            try loadLocalPlannerContext()
        } catch {
            plannerContextError = "Could not load processed financial data. \(String(describing: error))"
        }

        if dashboardSummary == nil, supabase.auth.currentSession != nil {
            do {
                let restored = try await FinancialDataCloudService()
                    .restoreLatestCloudData(modelContext: modelContext)
                if restored {
                    try loadLocalPlannerContext()
                }
            } catch {
                plannerContextError = "Could not restore processed financial data. \(String(describing: error))"
            }
        }

        if processedPlannerSnapshot == nil || plannerTransactions.isEmpty {
            plannerContextError = plannerContextError ?? "No processed Money Map data was found. Complete Account Aggregator setup or open Dashboard once to restore it."
        }

    }

    @MainActor
    private func loadLocalPlannerContext() throws {
        let dashboardLoader = DashboardDataLoader(modelContext: modelContext)
        dashboardSummary = try dashboardLoader.loadLatestSummary()

        if dashboardSummary == nil {
            let moneyMapLoader = MoneyMapDataLoader(modelContext: modelContext)
            moneyMapModel = try moneyMapLoader.loadLatestMoneyMap()
        } else {
            moneyMapModel = nil
        }

        let store = IntelligencePersistenceStore(modelContext: modelContext)
        guard
            let persona = try store.loadLatestPersona(),
            let personaId = PersonaId(rawValue: persona.id),
            let latestSnapshot = try store.loadLatestSnapshot(personaId: personaId)
        else {
            plannerMonthlyContexts = []
            plannerTransactions = []
            return
        }

        let allRows = try store.loadTransactionRows(personaId: personaId)
        plannerMonthlyContexts = try loadPlannerMonthlyContexts(
            personaId: personaId,
            allRows: allRows
        )
        debugPrintPlannerMonthlyContexts(plannerMonthlyContexts)
        plannerTransactions = loadPlannerTransactionsForAverageWindow(
            allRows: allRows,
            fallbackMonth: latestSnapshot.month
        )
    }

    @MainActor
    private func loadPlannerMonthlyContexts(
        personaId: PersonaId,
        allRows: [StoredTransactionRow]
    ) throws -> [PlannerMonthlyFinancialContext] {
        let store = IntelligencePersistenceStore(modelContext: modelContext)
        let snapshots = try store.loadSnapshots(personaId: personaId)
            .sorted { $0.month < $1.month }
            .suffix(12)
        let rowsByMonth = Dictionary(grouping: allRows) { $0.transaction.month }

        return snapshots.map { snapshot in
            let rows = rowsByMonth[snapshot.month] ?? []
            let taxDeduction = rows
                .filter { row in
                    row.transaction.type.uppercased() == "DEBIT" &&
                    row.classification?.categoryFamily == MoneCategoryFamily.tax
                }
                .map(\.transaction.amount)
                .reduce(0, +)

            return PlannerMonthlyFinancialContext(
                month: snapshot.month,
                income: snapshot.income,
                committed: max(snapshot.committed - taxDeduction, 0),
                everyday: snapshot.everyday,
                fund: snapshot.fund,
                liability: snapshot.liability,
                review: snapshot.review,
                outliers: snapshot.outliers
            )
        }
    }

    private func debugPrintPlannerMonthlyContexts(_ contexts: [PlannerMonthlyFinancialContext]) {
        #if DEBUG
        guard !contexts.isEmpty else {
            print("[Goals] monthly average input: no contexts")
            return
        }

        let amount: (Double) -> String = { value in
            "₹\(Int(value.rounded()).formatted(.number.grouping(.automatic)))"
        }
        let months = Double(contexts.count)
        let averageFlexibleAmount = contexts.map(\.goalPlanningFlexibleAmount).reduce(0, +) / months
        let averageObservedFlex = contexts.map(\.goalPlanningFlexibleSpend).reduce(0, +) / months
        let averageSurplus = max(averageFlexibleAmount - averageObservedFlex, 0)

        print("[Goals] monthly average input · months=\(contexts.count)")
        for context in contexts {
            let fixed = max(context.committed, 0) + max(context.fund, 0) + max(context.liability, 0)
            let observedFlex = context.goalPlanningFlexibleSpend
            let surplus = max(context.goalPlanningFlexibleAmount - observedFlex, 0)
            print(
                "[Goals] \(context.month) · income \(amount(context.income)) · fixed \(amount(fixed)) " +
                "(committed \(amount(context.committed)), fund \(amount(context.fund)), liability \(amount(context.liability))) · " +
                "flexible cap \(amount(context.goalPlanningFlexibleAmount)) · observed flex \(amount(observedFlex)) " +
                "(everyday \(amount(context.everyday)), review \(amount(context.review)), outliers \(amount(context.outliers))) · " +
                "surplus \(amount(surplus))"
            )
        }
        print(
            "[Goals] averages · flexible cap \(amount(averageFlexibleAmount)) · " +
            "observed flex \(amount(averageObservedFlex)) · goal surplus \(amount(averageSurplus))"
        )
        #endif
    }

    private func loadPlannerTransactionsForAverageWindow(
        allRows: [StoredTransactionRow],
        fallbackMonth: String
    ) -> [Transaction] {
        let averageMonths = Set(plannerMonthlyContexts.map(\.month))
        let rows: [StoredTransactionRow]
        if averageMonths.isEmpty {
            rows = allRows.filter { $0.transaction.month == fallbackMonth }
        } else {
            rows = allRows.filter { averageMonths.contains($0.transaction.month) }
        }

        return rows
            .compactMap(plannerTransaction(from:))
    }

    private func plannerTransaction(from row: StoredTransactionRow) -> Transaction? {
        guard let date = plannerDate(from: row.transaction.timestamp ?? row.transaction.valueDate) else {
            return nil
        }

        return Transaction(
            merchant: row.classification?.canonicalEntityName ?? row.transaction.normalizedCounterparty ?? row.transaction.narration,
            amount: row.transaction.amount,
            date: date,
            category: plannerCategory(from: row.classification?.categoryFamily),
            type: row.transaction.type.uppercased() == "CREDIT" ? .credit : .debit,
            notes: row.transaction.id
        )
    }

    private func plannerDate(from value: String?) -> Date? {
        guard let value else { return nil }

        if let date = ISO8601DateFormatter().date(from: value) {
            return date
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private func plannerCategory(from family: String?) -> TransactionCategory {
        switch family {
        case MoneCategoryFamily.foodSnacks, MoneCategoryFamily.groceries:
            return .food
        case MoneCategoryFamily.shopping:
            return .shopping
        case MoneCategoryFamily.subscriptions:
            return .subscriptions
        case MoneCategoryFamily.transport, MoneCategoryFamily.travel:
            return .transport
        case MoneCategoryFamily.lifestyleEntertainment:
            return .entertainment
        case MoneCategoryFamily.housing:
            return .housing
        case MoneCategoryFamily.utilities,
            MoneCategoryFamily.insurance,
            MoneCategoryFamily.tax:
            return .bills
        case MoneCategoryFamily.debt,
            MoneCategoryFamily.creditCard:
            return .creditCard
        case MoneCategoryFamily.medical:
            return .health
        default:
            return .other
        }
    }

    private func startCreateGoal() {
        Task {
            await loadPlannerContext()
            await MainActor.run {
                guard hasProcessedPlannerContext else { return }
                draft.reset()
                route = .pickType
                showPlannerSheet = true
            }
        }
    }

    private func startBuildCorpusGoal() {
        Task {
            await loadPlannerContext()
            await MainActor.run {
                guard hasProcessedPlannerContext else { return }
                draft.reset()
                draft.selectedKind = .buildSavings
                route = .corpusPurpose
                showPlannerSheet = true
            }
        }
    }

    private func startSuggestedSavingsGoal() {
        Task {
            await loadPlannerContext()
            await MainActor.run {
                guard hasProcessedPlannerContext else { return }
                draft.reset()
                draft.selectedKind = .buildSavings
                draft.savingsPurpose = .emergencyFund
                route = .savingsDetails
                showPlannerSheet = true
            }
        }
    }

    private func startSuggestedSpendingGoal() {
        Task {
            await loadPlannerContext()
            await MainActor.run {
                guard hasProcessedPlannerContext else { return }
                draft.reset()
                draft.selectedKind = .controlSpending
                draft.spendingFocus = .foodDelivery
                draft.spendingTargetText = "\(Int(engine.suggestedTargetSpend(for: .foodDelivery, transactions: plannerTransactions)))"
                route = .spendingFocus
                showPlannerSheet = true
            }
        }
    }

    private func saveGoal(_ goal: PlannerGoal) {
        plannerGoals.insert(goal, at: 0)
        GoalPlannerPersistence.save(plannerGoals)
        route = .created(goal)
    }
}

// MARK: - Empty Carousel

private struct GoalEducationCarousel: View {
    @State private var page: Int = 0
    @State private var dragOffset: CGFloat = 0
    @State private var swipeForward: Bool = true

    private let pageIcons = ["dot.scope", "dot.radiowaves.left.and.right", "rainbow"]

    private let cards: [(title: String, body: String)] = [
        (
            "Setting a goal is easy!",
            "Moné helps you set a practical goal that you need: Save money, bracket spending, etc."
        ),
        (
            "moné makes achieving them real",
            "moné determines path for you to stay on track, it is smart enough to reroute!."
        ),
        (
            "Financial well-being for you!",
            "You don't have to worry about yet another task, moné keeps a close eye and works for you!"
        )
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(cards.indices, id: \.self) { index in
                    carouselCard(cards[index], index: index, availableWidth: geo.size.width, isActive: index == page)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .offset(y: cardOffset(for: index, height: geo.size.height))
                        .zIndex(Double(index))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        let dy = value.translation.height
                        if dy < 0 && page < cards.count - 1 {
                            dragOffset = dy
                        } else if dy > 0 && page > 0 {
                            dragOffset = dy
                        }
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 60

                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            if value.translation.height < -threshold && page < cards.count - 1 {
                                swipeForward = true
                                page += 1
                            } else if value.translation.height > threshold && page > 0 {
                                swipeForward = false
                                page -= 1
                            }
                            dragOffset = 0
                        }
                    }
            )
            .overlay(alignment: .bottomTrailing) {
                VStack(spacing: 6) {
                    ForEach(cards.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == page ? Color.moneActionFill : Color.moneStrokeBright)
                            .frame(width: 6, height: index == page ? 18 : 6)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: page)
                .padding(.trailing, MoneSpacing.cardLg)
                .padding(.bottom, MoneSpacing.cardLg)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .overlay(alignment: .topTrailing) {
            CarouselIconsOverlay(page: page)
                .padding(.top, MoneSpacing.cardLg - 2)
                .padding(.trailing, MoneSpacing.cardLg + 6)
        }
        .task(id: page) {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, dragOffset == 0 else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                swipeForward = true
                page = (page + 1) % cards.count
                dragOffset = 0
            }
        }
    }


    private let settledOffsets: [CGFloat] = [0, 96, 160]

    private func cardOffset(for index: Int, height: CGFloat) -> CGFloat {
        let settled = settledOffsets[index]
        let pageSettled = settledOffsets[page]

        if index < page {
            return settled
        } else if index == page {
            return dragOffset > 0 ? settled + dragOffset : settled
        } else {
            let parked = CGFloat(index - page) * height + pageSettled
            return parked + dragOffset
        }
    }

    private func carouselCard(_ card: (title: String, body: String), index: Int, availableWidth: CGFloat, isActive: Bool = true) -> some View {
        ZStack(alignment: .topLeading) {
            ContourBackground().opacity(0.35)

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(card.title)
                            .font(.moneHLMd)
                            .foregroundStyle(Color.monePrimary)
                    }

                }

                Text(card.body)
                    .font(.moneBodyMd)
                    .foregroundStyle(Color.moneSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: availableWidth * 0.6, alignment: .leading)
            }
            .padding(MoneSpacing.cardLg)
            .padding(.top, index == 0 ? 32 : 0)
            .opacity(isActive ? 1 : 0.45)
            .animation(.easeInOut(duration: 0.3), value: isActive)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .moneCard(radius: 0, elevated: true)
    }
}

// MARK: - Carousel Icon Views

private struct CarouselIconsOverlay: View {
    let page: Int

    // dot.scope: showPage0 = outer gate (page transition), page0Cycle = inner gate (drawOn loop)
    @State private var showPage0 = false
    @State private var page0Cycle = false
    @State private var usePage0Disappear = false

    @State private var showPage1Plus = false
    @State private var usePage1PlusDisappear = false
    @State private var page1PlusEffectActive = false

    private let pageIcons = ["dot.scope", "dot.radiowaves.left.and.right", "rainbow"]

    var body: some View {
        ZStack {
            // dot.scope — page 0
            // Two nested conditionals: outer controls page transition, inner drives drawOn loop
            if showPage0 {
                if usePage0Disappear {
                    dotScopeImage
                        .transition(.symbolEffect(.disappear))
                } else if page0Cycle {
                    dotScopeImage
                        .transition(.symbolEffect(.drawOn))
                }
            }

            // radiowave / rainbow — pages 1 and 2
            if showPage1Plus {
                if usePage1PlusDisappear {
                    page1PlusImage(effectActive: false)
                        .transition(.symbolEffect(.disappear))
                } else {
                    page1PlusImage(effectActive: page1PlusEffectActive)
                        .transition(.symbolEffect(.drawOn))
                }
            }
        }
        .frame(width: 88, height: 88)
        .task(id: page) {
            if page == 0 {
                // 1. Stop page1Plus effect, switch to disappear branch, then animate out
                page1PlusEffectActive = false
                usePage1PlusDisappear = true
                try? await Task.sleep(for: .milliseconds(16))
                withAnimation { showPage1Plus = false }

                // 2. Reset dot.scope outer gate and cycle (no animation), then fire drawOn
                var t = SwiftUI.Transaction()
                t.disablesAnimations = true
                withTransaction(t) {
                    showPage0 = false
                    usePage0Disappear = false
                    page0Cycle = false
                }
                try? await Task.sleep(for: .milliseconds(80))
                guard !Task.isCancelled else { return }
                // showPage0=true alone doesn't show image; page0Cycle must be true simultaneously
                withAnimation {
                    showPage0 = true
                    page0Cycle = true   // drawOn fires when both become true together
                }

                // 3. Continuous loop: drawOn → hold briefly → drawOff → drawOn → …
                try? await Task.sleep(for: .milliseconds(400)) // let initial drawOn finish
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(500)) // hold (brief)
                    guard !Task.isCancelled else { return }

                    withAnimation { page0Cycle = false }           // drawOff (reverse of .drawOn transition)
                    try? await Task.sleep(for: .milliseconds(500)) // let drawOff finish
                    guard !Task.isCancelled else { return }

                    withAnimation { page0Cycle = true }            // drawOn fires immediately after
                    try? await Task.sleep(for: .milliseconds(200)) // let drawOn finish
                }

            } else {
                // 1. Ensure dot.scope is in the tree (mid-cycle it might be hidden),
                //    switch to disappear branch, then animate out
                page0Cycle = true          // guarantee image is in tree before disappear
                usePage0Disappear = true   // switch to disappear branch
                try? await Task.sleep(for: .milliseconds(16))
                withAnimation { showPage0 = false }

                if !showPage1Plus {
                    // 2. Reset page1Plus (no animation), then fire drawOn with effect OFF
                    var t = SwiftUI.Transaction()
                    t.disablesAnimations = true
                    withTransaction(t) {
                        showPage1Plus = false
                        usePage1PlusDisappear = false
                        page1PlusEffectActive = false
                    }
                    try? await Task.sleep(for: .milliseconds(80))
                    guard !Task.isCancelled else { return }
                    withAnimation { showPage1Plus = true }

                    // 3. After drawOn finishes, start variableColor
                    try? await Task.sleep(for: .milliseconds(1500))
                    guard !Task.isCancelled else { return }
                    page1PlusEffectActive = true
                }
                // Pages 1↔2: showPage1Plus stays true, symbolName changes → .replace fires
            }
        }
    }

    private var dotScopeImage: some View {
        Image(systemName: "dot.scope")
            .font(.system(size: 88, weight: .thin))
            .foregroundStyle(Color.monePrimary)
            .symbolRenderingMode(.hierarchical)
            .frame(width: 88, height: 88)
    }

    private func page1PlusImage(effectActive: Bool) -> some View {
        Image(systemName: pageIcons[page])
            .font(.system(size: 88, weight: .thin))
            .foregroundStyle(Color.monePrimary)
            .symbolRenderingMode(page == 2 ? .multicolor : .hierarchical)
            .symbolEffect(.variableColor.iterative, options: .repeat(.periodic(delay: 0.2)).speed(4), isActive: effectActive)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: 88, height: 88)
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
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.moneSurfaceEl)
                                .frame(width: 52, height: 52)
                            Image(systemName: goalIcon)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(Color.moneSecondary)
                        }

                        VStack(alignment: .leading, spacing: 5) {
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
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(statusColor.opacity(0.12))
                        .clipShape(Capsule())
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.moneSurfaceHigh).frame(height: 8)
                        Capsule()
                            .fill(statusColor)
                            .frame(width: geo.size.width * CGFloat(goal.progressFraction), height: 8)
                    }
                }
                .frame(height: 8)

                VStack(alignment: .leading, spacing: 10) {
                    Text(goal.planLine)
                        .font(.moneBodyMd)
                        .foregroundStyle(Color.monePrimary)
                    Text(goal.nextAction)
                        .font(.moneBodySm)
                        .foregroundStyle(Color.moneSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(MoneSpacing.cardLg)
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

    let transactions: [Transaction]
    let plannerSnapshot: PlannerFinancialSnapshot?
    let existingGoals: [PlannerGoal]
    let onSave: (PlannerGoal) -> Void
    let onClose: () -> Void

    @State private var isKeyboardVisible = false

    private let engine = GoalPlannerEngine()

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.moneBackground.ignoresSafeArea()
            ContourBackground().opacity(0.25).ignoresSafeArea()

            VStack(spacing: 0) {
                sheetHeader

                if route == .savingsDetails {
                    if let plannerSnapshot {
                        SavingsStickyContinueBar(
                            amount: draft.savingsAmount,
                            deadline: draft.savingsDeadline,
                            plannerSnapshot: plannerSnapshot,
                            onContinue: { route = .savingsPlan }
                        )
                        .padding(.horizontal, MoneSpacing.page)
                        .padding(.bottom, 12)
                    }
                }

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: MoneSpacing.gutter) {
                        content
                    }
                    .padding(.horizontal, MoneSpacing.page)
                    .padding(.bottom, 120)
                }
                .scrollDismissesKeyboard(.interactively)
                .simultaneousGesture(
                    TapGesture().onEnded {
                        Keyboard.dismiss()
                    }
                )
            }

            bottomActionBar
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
    }

    @ViewBuilder
    private var bottomActionBar: some View {
        switch route {
        case .corpusPurpose:
            pinnedAction(title: "Continue", icon: "arrow.right", isEnabled: draft.savingsPurpose != nil) {
                route = .corpusAmount
            }
        case .corpusAmount:
            pinnedAction(title: "Suggest timeline", icon: "arrow.right", isEnabled: draft.savingsAmount > 0) {
                Keyboard.dismiss()
                route = .corpusTimeline
            }
        case .corpusTimeline:
            if let plannerSnapshot {
                let option = engine.corpusTimelineOption(
                    targetAmount: draft.savingsAmount,
                    months: draft.selectedDurationMonths ?? 1,
                    snapshot: plannerSnapshot,
                    transactions: transactions
                )
                pinnedAction(title: "Choose funding", icon: "arrow.right", isEnabled: option.isPossible) {
                    route = .corpusFunding
                }
            }
        case .corpusFunding:
            if let plannerSnapshot {
                let monthlyRequired = draft.savingsAmount / Double(max(draft.selectedDurationMonths ?? 1, 1))
                let comfortable = max(
                    plannerFlexibleAmount(plannerSnapshot) - plannerObservedFlexibleSpend(plannerSnapshot, transactions),
                    0
                )
                let gap = max(monthlyRequired - min(comfortable, monthlyRequired), 0)
                let selected = draft.selectedFundingComponents.reduce(0) { $0 + $1.monthlyAmount }
                VStack(spacing: 12) {
                    fundingProgressBar(requiredGap: gap, selected: selected)
                        .padding(.horizontal, MoneSpacing.page)

                    pinnedAction(title: "Review plan", icon: "arrow.right", isEnabled: gap == 0 || selected >= gap) {
                        route = .corpusPreview
                    }
                }
            }
        default:
            EmptyView()
        }
    }

    private func pinnedAction(
        title: String,
        icon: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        MonePrimaryButton(title: title, icon: icon) {
            action()
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .padding(.horizontal, MoneSpacing.page)
        .padding(.bottom, isKeyboardVisible ? 12 : 0)
    }

    @ViewBuilder
    private var content: some View {
        switch route {
        case .pickType:
            if hasPlannerContext {
                GoalTypeStep(draft: $draft) { kind in
                    draft.selectedKind = kind
                    switch kind {
                    case .buildSavings:
                        route = .savingsDetails
                    case .controlSpending:
                        route = .spendingFocus
                    }
                }
            } else {
                PlannerContextMissingStep(onClose: onClose)
            }

        case .corpusPurpose:
            if hasPlannerContext {
                CorpusPurposeStep(draft: $draft) {
                    route = .corpusAmount
                }
            } else {
                PlannerContextMissingStep(onClose: onClose)
            }

        case .corpusAmount:
            if let plannerSnapshot {
                CorpusAmountStep(
                    draft: $draft,
                    plannerSnapshot: plannerSnapshot,
                    onContinue: { route = .corpusTimeline }
                )
            } else {
                PlannerContextMissingStep(onClose: onClose)
            }

        case .corpusTimeline:
            if let plannerSnapshot, !transactions.isEmpty {
                CorpusTimelineStep(
                    draft: $draft,
                    plannerSnapshot: plannerSnapshot,
                    transactions: transactions,
                    onContinue: { route = .corpusFunding }
                )
            } else {
                PlannerContextMissingStep(onClose: onClose)
            }

        case .corpusFunding:
            if let plannerSnapshot, !transactions.isEmpty {
                CorpusFundingStep(
                    draft: $draft,
                    plannerSnapshot: plannerSnapshot,
                    transactions: transactions,
                    onContinue: { route = .corpusPreview }
                )
            } else {
                PlannerContextMissingStep(onClose: onClose)
            }

        case .corpusPreview:
            if let plannerSnapshot, !transactions.isEmpty {
                CorpusPreviewStep(
                    draft: $draft,
                    plannerSnapshot: plannerSnapshot,
                    transactions: transactions,
                    onCreate: createCorpusGoal
                )
            } else {
                PlannerContextMissingStep(onClose: onClose)
            }

        case .savingsDetails:
            if let plannerSnapshot {
                SavingsDetailsStep(
                    draft: $draft,
                    plannerSnapshot: plannerSnapshot
                )
            } else {
                PlannerContextMissingStep(onClose: onClose)
            }

        case .savingsPlan:
            if let plannerSnapshot {
                SavingsPlanStep(
                    draft: $draft,
                    plannerSnapshot: plannerSnapshot,
                    onCreate: createSavingsGoal
                )
            } else {
                PlannerContextMissingStep(onClose: onClose)
            }

        case .spendingFocus:
            if !transactions.isEmpty {
                SpendingFocusStep(
                    draft: $draft,
                    transactions: transactions,
                    onContinue: { route = .spendingPlan }
                )
            } else {
                PlannerContextMissingStep(onClose: onClose)
            }

        case .spendingPlan:
            if !transactions.isEmpty {
                SpendingPlanStep(
                    draft: $draft,
                    transactions: transactions,
                    onCreate: createSpendingGoal
                )
            } else {
                PlannerContextMissingStep(onClose: onClose)
            }

        case .created(let goal):
            GoalDetailStep(goal: goal, created: true)

        case .detail(let goal):
            GoalDetailStep(goal: goal, created: false)
        }
    }

    private var hasPlannerContext: Bool {
        plannerSnapshot != nil && !transactions.isEmpty
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
        case .corpusPurpose: return "Goal purpose"
        case .corpusAmount: return "Goal amount"
        case .corpusTimeline: return "Goal timeline"
        case .corpusFunding: return "Funding plan"
        case .corpusPreview: return "Review goal"
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
        case .corpusPurpose:
            route = .pickType
        case .corpusAmount:
            route = .corpusPurpose
        case .corpusTimeline:
            route = .corpusAmount
        case .corpusFunding:
            draft.selectedFundingComponents = []
            route = .corpusTimeline
        case .corpusPreview:
            route = .corpusFunding
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

    private func createCorpusGoal() {
        guard let purpose = draft.savingsPurpose,
              let durationMonths = draft.selectedDurationMonths,
              let plannerSnapshot else { return }

        let goal = engine.createCorpusGoal(
            purpose: purpose,
            targetAmount: draft.savingsAmount,
            durationMonths: durationMonths,
            selectedFunding: draft.selectedFundingComponents,
            snapshot: plannerSnapshot,
            transactions: transactions
        )
        onSave(goal)
    }

    private func createSavingsGoal() {
        guard let purpose = draft.savingsPurpose,
              let plannerSnapshot else { return }
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

private struct PlannerContextMissingStep: View {
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MoneSpacing.gutter) {
            intro(
                title: "Financial data not ready",
                subtitle: "Goals needs the same processed Money Map data used by Dashboard before it can calculate recommendations."
            )

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.moneWatch)

                Text("Open Dashboard or complete Account Aggregator setup so Moné can load the processed statement. Goals will not create plans from mock transactions.")
                    .font(.moneBodySm)
                    .foregroundStyle(Color.moneSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(MoneSpacing.cardLg)
            .background(Color.moneWatchBg)
            .clipShape(RoundedRectangle(cornerRadius: MoneRadius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: MoneRadius.xl, style: .continuous)
                    .strokeBorder(Color.moneWatch.opacity(0.35), lineWidth: 1)
            )

            MonePrimaryButton(title: "Close", icon: "xmark") {
                onClose()
            }
        }
    }
}

private struct CorpusPurposeStep: View {
    @Binding var draft: PlannerDraft
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MoneSpacing.gutter) {
            intro(
                title: "What is this money for?",
                subtitle: "Pick the purpose first. Amount, timeline, and funding options come after this."
            )

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(PlannerSavingsPurpose.allCases) { purpose in
                    Button {
                        draft.savingsPurpose = purpose
                    } label: {
                        PurposeGridCard(
                            purpose: purpose,
                            isSelected: draft.savingsPurpose == purpose
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct PurposeGridCard: View {
    let purpose: PlannerSavingsPurpose
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.moneActionFill.opacity(0.15) : Color.moneSurfaceEl)
                        .frame(width: 42, height: 42)
                    Image(systemName: purpose.icon)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(isSelected ? Color.moneActionFill : Color.moneSecondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(isSelected ? Color.moneActionFill : Color.moneTertiary)
            }

            Spacer(minLength: 6)

            Text(purpose.title)
                .font(.moneHLSm)
                .foregroundStyle(Color.monePrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(purpose.shortDetail)
                .font(.moneCaption)
                .foregroundStyle(Color.moneSecondary)
                .lineSpacing(2)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
        .padding(MoneSpacing.cardSm)
        .background(isSelected ? Color.moneSurfaceEl : Color.moneSurface)
        .clipShape(RoundedRectangle(cornerRadius: MoneRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MoneRadius.xl, style: .continuous)
                .strokeBorder(isSelected ? Color.moneStrokeBright : Color.moneStroke, lineWidth: 1)
        )
    }
}

private struct CorpusAmountStep: View {
    @Binding var draft: PlannerDraft
    let plannerSnapshot: PlannerFinancialSnapshot
    let onContinue: () -> Void

    @State private var amountFocused = false
    private let minimumAmount = 10_000.0
    private let defaultAmount = 150_000.0
    private let maximumAmount = 10_000_000.0

    private var purposeTitle: String {
        draft.savingsPurpose?.title ?? "this goal"
    }

    private var amountValue: Binding<Double> {
        Binding(
            get: { min(max(draft.savingsAmount, minimumAmount), maximumAmount) },
            set: { value in
                draft.savingsAmountText = formattedAmountInput(for: value)
            }
        )
    }

    private var amountText: Binding<String> {
        Binding(
            get: {
                draft.savingsAmountText.isEmpty ? "₹" : draft.savingsAmountText
            },
            set: { newValue in
                draft.savingsAmountText = formattedAmountInput(for: newValue)
            }
        )
    }

    private var amountFieldWidth: CGFloat {
        let displayText = draft.savingsAmountText.isEmpty ? "₹" : draft.savingsAmountText
        let renderedWidth = (displayText as NSString).size(
            withAttributes: [.font: UIFont.moneAmountInput]
        ).width
        return min(max(ceil(renderedWidth), 24), 190)
    }

    private func formattedAmountInput(for value: Double) -> String {
        formatIndianCurrencyInput(min(max(value, 0), maximumAmount))
    }

    private func formattedAmountInput(for text: String) -> String {
        let numeric = Double(text.plannerNumericOnly) ?? 0
        return formattedAmountInput(for: numeric)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MoneSpacing.gutter) {
            intro(
                title: "How much for \(purposeTitle.lowercased())?",
                subtitle: "Set the corpus target. Moné will use this to calculate the timeline and monthly funding gap."
            )

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text("TARGET AMOUNT")
                        .moneLabelCaps(color: .moneTertiary)
                    Spacer()
                    CurrencyAmountTextField(
                        text: amountText,
                        isFocused: $amountFocused,
                        maximumAmount: maximumAmount
                    )
                    .frame(width: amountFieldWidth, height: 34)
                    .padding(.horizontal, 10)
                    .background(Color.moneSurfaceEl)
                    .clipShape(RoundedRectangle(cornerRadius: MoneRadius.lg, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: MoneRadius.lg, style: .continuous)
                            .strokeBorder(Color.moneStroke, lineWidth: 1)
                    )
                }

                Slider(
                    value: amountValue,
                    in: minimumAmount...maximumAmount,
                    step: 10_000
                )
                .tint(Color.moneActionFill)

                HStack {
                    Text(minimumAmount.plannerCurrency)
                    Spacer()
                    Text(maximumAmount.plannerCurrency)
                }
                .font(.moneCaption)
                .foregroundStyle(Color.moneTertiary)
            }
            .padding(MoneSpacing.cardLg)
            .background(Color.moneSurface)
            .clipShape(RoundedRectangle(cornerRadius: MoneRadius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: MoneRadius.xl, style: .continuous)
                    .strokeBorder(Color.moneStroke, lineWidth: 1)
            )
        }
        .contentShape(Rectangle())
        .onTapGesture { amountFocused = false }
        .onAppear {
            if draft.savingsAmount <= 0 {
                draft.savingsAmountText = formattedAmountInput(for: defaultAmount)
            }
            amountFocused = true
        }
        .onChange(of: draft.savingsAmountText) { _, newValue in
            let formatted = formattedAmountInput(for: newValue)
            if !newValue.isEmpty && newValue != formatted {
                DispatchQueue.main.async {
                    draft.savingsAmountText = formatted
                }
            }
        }
    }
}

private struct CorpusTimelineStep: View {
    @Binding var draft: PlannerDraft
    let plannerSnapshot: PlannerFinancialSnapshot
    let transactions: [Transaction]
    let onContinue: () -> Void

    private let engine = GoalPlannerEngine()

    private var monthRange: ClosedRange<Int> {
        engine.corpusTimelineMonthRange(
            targetAmount: draft.savingsAmount,
            snapshot: plannerSnapshot,
            transactions: transactions
        )
    }

    private var selectedMonths: Int {
        let value = draft.selectedDurationMonths ?? recommendedStartingMonth
        return min(max(value, monthRange.lowerBound), monthRange.upperBound)
    }

    private var selectedOption: PlannerTimelineOption {
        engine.corpusTimelineOption(
            targetAmount: draft.savingsAmount,
            months: selectedMonths,
            snapshot: plannerSnapshot,
            transactions: transactions
        )
    }

    private var recommendedStartingMonth: Int {
        let options = engine.corpusTimelineOptions(
            targetAmount: draft.savingsAmount,
            snapshot: plannerSnapshot,
            transactions: transactions
        )
        return options.first(where: { $0.isComfortable && $0.isPossible })?.months
            ?? options.first(where: { $0.isPossible })?.months
            ?? monthRange.lowerBound
    }

    private var canContinue: Bool {
        selectedOption.isPossible
    }

    private var sliderValue: Binding<Double> {
        Binding(
            get: { Double(selectedMonths) },
            set: { newValue in
                setDuration(Int(newValue.rounded()))
            }
        )
    }

    private var statusColor: Color {
        switch selectedOption.statusLabel {
        case "Comfortable":
            return .moneHealthy
        case "Stretch":
            return .moneWatch
        case "Aggressive", "Impractical":
            return .moneRisk
        default:
            return .moneSecondary
        }
    }

    private var statusBackground: Color {
        switch selectedOption.statusLabel {
        case "Comfortable":
            return .moneHealthyBg
        case "Stretch":
            return .moneWatchBg
        case "Aggressive", "Impractical":
            return .moneRiskBg
        default:
            return .moneSurfaceEl
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MoneSpacing.gutter) {
            intro(
                title: "Timeline for \(draft.savingsPurpose?.title.lowercased() ?? "your goal")",
                subtitle: "Adjust the duration and see how much comes from existing surplus versus spending cuts."
            )

            GoalBuildContextSummary(
                purpose: draft.savingsPurpose,
                amount: draft.savingsAmount,
                durationMonths: nil
            )

            timelineSummary
        }
        .onAppear {
            if draft.selectedDurationMonths == nil {
                setDuration(recommendedStartingMonth)
            }
        }
    }

    private var timelineSummary: some View {
        VStack(alignment: .leading, spacing: 32) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 8) {
                    
                    Text("Required monthly saving")
                        .font(.moneCaption)
                        .foregroundStyle(Color.moneSecondary)
                    
                    Text(selectedOption.monthlyRequired.plannerCurrency + "/mo")
                        .font(.moneAmtMd)
                        .foregroundStyle(Color.monePrimary)
                }
                
                Spacer(minLength: 12)
                
                Text(selectedOption.statusLabel)
                    .font(.moneCaption.weight(.semibold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(statusBackground)
                    .clipShape(Capsule())
            }
            
            Text(selectedOption.detail)
                .font(.moneBodySm)
                .foregroundStyle(selectedOption.isPossible ? Color.moneSecondary : Color.moneRisk)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            
            stackedContributionBar(
                total: selectedOption.monthlyRequired,
                surplus: selectedOption.safeContribution,
                cuts: selectedOption.leakageNeeded
            )
            
            VStack(alignment: .leading, spacing: 8)
            {
                
            
            HStack {
                Text("Duration")
                    .font(.moneBodySm.weight(.medium))
                    .foregroundStyle(Color.monePrimary)
                Spacer()
                Text("\(selectedMonths) months")
                    .font(.moneBodySm.weight(.medium))
                    .foregroundStyle(Color.moneSecondary)
            }
            
            Slider(
                value: sliderValue,
                in: Double(monthRange.lowerBound)...Double(monthRange.upperBound),
                step: 1
            )
            .tint(statusColor)
            
            HStack {
                Text("\(monthRange.lowerBound)m")
                    .font(.moneCaption)
                    .foregroundStyle(Color.moneSecondary)
                Spacer()
                Text("\(monthRange.upperBound)m")
                    .font(.moneCaption)
                    .foregroundStyle(Color.moneSecondary)
            }
        }
        }
        .padding(MoneSpacing.cardLg)
        .background(Color.moneSurface)
        .clipShape(RoundedRectangle(cornerRadius: MoneRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MoneRadius.xl, style: .continuous)
                .strokeBorder(statusColor.opacity(0.32), lineWidth: 1)
        )
    }

    private func setDuration(_ months: Int) {
        let clamped = min(max(months, monthRange.lowerBound), monthRange.upperBound)
        draft.selectedDurationMonths = clamped
        draft.savingsDeadline = Calendar.current.date(byAdding: .month, value: clamped, to: Date()) ?? Date()
    }
}

private struct CorpusFundingStep: View {
    @Binding var draft: PlannerDraft
    let plannerSnapshot: PlannerFinancialSnapshot
    let transactions: [Transaction]
    let onContinue: () -> Void

    @State private var selectedSubscriptionIds: Set<String> = []

    private let engine = GoalPlannerEngine()

    private var monthlyRequired: Double {
        guard let months = draft.selectedDurationMonths, months > 0 else { return 0 }
        return draft.savingsAmount / Double(months)
    }

    private var safeContribution: Double {
        min(comfortableSaving, monthlyRequired)
    }

    private var leakageNeeded: Double {
        max(monthlyRequired - safeContribution, 0)
    }

    private var flexibleAmount: Double {
        max(plannerSnapshot.income - max(plannerSnapshot.committed, 0) - max(plannerSnapshot.fund, 0) - max(plannerSnapshot.liability, 0), 0)
    }

    private var observedFlexibleSpend: Double {
        plannerObservedFlexibleSpend(plannerSnapshot, transactions)
    }

    private var comfortableSaving: Double {
        max(flexibleAmount - observedFlexibleSpend, 0)
    }

    private var stretchSavingCapacity: Double {
        flexibleAmount * 0.50
    }

    private var debitTransactions: [Transaction] {
        transactions.filter { !$0.isUpcoming && $0.type == .debit }
    }

    private var selectedLeakageTotal: Double {
        draft.selectedFundingComponents.reduce(0) { $0 + $1.monthlyAmount }
    }

    private var options: [PlannerFundingComponent] {
        engine.leakageFundingOptions(
            transactions: transactions,
            snapshot: plannerSnapshot,
            monthlyRequired: monthlyRequired
        )
    }

    private var nonSubscriptionOptions: [PlannerFundingComponent] {
        options.filter { component in
            if case .leakage(.subscriptions) = component.source {
                return false
            }
            return true
        }
    }

    private var subscriptionOption: PlannerFundingComponent? {
        options.first { component in
            if case .leakage(.subscriptions) = component.source {
                return true
            }
            return false
        }
    }

    private var subscriptionItems: [SubscriptionFundingItem] {
        let monthCount = max(Set(debitTransactions.map { plannerMonthKey(for: $0.date) }).count, 1)
        let grouped = Dictionary(grouping: debitTransactions.filter { $0.category == .subscriptions }) { transaction in
            transaction.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return grouped
            .map { merchant, transactions in
                SubscriptionFundingItem(
                    merchant: merchant.isEmpty ? "Subscription" : merchant,
                    monthlyAmount: transactions.reduce(0) { $0 + $1.amount } / Double(monthCount)
                )
            }
            .filter { $0.monthlyAmount > 0 }
            .sorted { $0.monthlyAmount > $1.monthlyAmount }
    }

    private var selectedSubscriptionItems: [SubscriptionFundingItem] {
        subscriptionItems.filter { selectedSubscriptionIds.contains($0.id) }
    }

    private var selectedSubscriptionTotal: Double {
        selectedSubscriptionItems.reduce(0) { $0 + $1.monthlyAmount }
    }

    private var selectedFundingProgress: Double {
        guard leakageNeeded > 0 else { return 1 }
        return min(selectedLeakageTotal / leakageNeeded, 1)
    }

    private var canContinue: Bool {
        leakageNeeded == 0 || selectedLeakageTotal >= leakageNeeded
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MoneSpacing.gutter) {
            intro(
                title: "Fund \(draft.savingsPurpose?.title.lowercased() ?? "this goal")",
                subtitle: "Pick how to close the monthly gap created by your selected timeline."
            )

            GoalBuildContextSummary(
                purpose: draft.savingsPurpose,
                amount: draft.savingsAmount,
                durationMonths: draft.selectedDurationMonths
            )

            if leakageNeeded == 0 {
                FundingComponentCard(
                    component: PlannerFundingComponent(
                        source: .safeCapacity,
                        monthlyAmount: safeContribution,
                        baseline: flexibleAmount,
                        note: "Current month-end surplus can fund this timeline without selected cuts."
                    ),
                    isSelected: true,
                    isLocked: true
                ) {}
            } else {
                ForEach(nonSubscriptionOptions) { component in
                    AdjustableFundingComponentCard(
                        component: component,
                        selectedComponent: selectedComponent(for: component),
                        onToggle: { toggle(component) },
                        onAmountChange: { amount in update(component, amount: amount) }
                    )
                }

                if let subscriptionOption {
                    if subscriptionItems.isEmpty {
                        AdjustableFundingComponentCard(
                            component: subscriptionOption,
                            selectedComponent: selectedComponent(for: subscriptionOption),
                            onToggle: { toggle(subscriptionOption) },
                            onAmountChange: { amount in update(subscriptionOption, amount: amount) }
                        )
                    } else {
                        SubscriptionFundingPickerCard(
                            component: subscriptionOption,
                            items: subscriptionItems,
                            selectedIds: selectedSubscriptionIds,
                            onToggleItem: toggleSubscription
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            if leakageNeeded == 0 {
                draft.selectedFundingComponents = []
            }
        }
    }

    #if DEBUG
    private var fundingDiagnostics: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DEBUG FUNDING INPUT")
                .moneLabelCaps(color: .moneTertiary)

            Text("\(plannerSnapshot.contextLine) · \(transactions.count) rows · \(debitTransactions.count) debits")
                .font(.moneCaption)
                .foregroundStyle(Color.moneSecondary)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                diagnosticCell("Food", categoryTotal(.food))
                diagnosticCell("Shopping", categoryTotal(.shopping))
                diagnosticCell("Subscriptions", categoryTotal(.subscriptions))
                diagnosticCell("Transport", categoryTotal(.transport))
                diagnosticCell("Entertainment", categoryTotal(.entertainment))
                diagnosticCell("Other small UPI", smallUPITotal)
            }
        }
        .padding(MoneSpacing.cardLg)
        .background(Color.moneSurfaceEl)
        .clipShape(RoundedRectangle(cornerRadius: MoneRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MoneRadius.xl, style: .continuous)
                .strokeBorder(Color.moneStroke, lineWidth: 1)
        )
    }

    private var smallUPITotal: Double {
        debitTransactions
            .filter { $0.category == .other && $0.amount <= 1_000 }
            .reduce(0) { $0 + $1.amount }
    }

    private func categoryTotal(_ category: TransactionCategory) -> Double {
        debitTransactions
            .filter { $0.category == category }
            .reduce(0) { $0 + $1.amount }
    }

    private func diagnosticCell(_ label: String, _ amount: Double) -> some View {
        HStack {
            Text(label)
                .font(.moneCaption)
                .foregroundStyle(Color.moneSecondary)
            Spacer()
            Text(amount.plannerCurrency)
                .font(.moneCaption.weight(.semibold))
                .foregroundStyle(Color.monePrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.moneSurface)
        .clipShape(RoundedRectangle(cornerRadius: MoneRadius.md, style: .continuous))
    }
    #endif

    private func toggle(_ component: PlannerFundingComponent) {
        if let index = draft.selectedFundingComponents.firstIndex(where: { $0.id == component.id }) {
            draft.selectedFundingComponents.remove(at: index)
        } else {
            draft.selectedFundingComponents.append(component)
        }
    }

    private func selectedComponent(for component: PlannerFundingComponent) -> PlannerFundingComponent? {
        draft.selectedFundingComponents.first { $0.id == component.id }
    }

    private func update(_ component: PlannerFundingComponent, amount: Double) {
        let minimum = component.monthlyAmount
        let maximum = max(component.maxMonthlyAmount ?? component.monthlyAmount, minimum)
        var updated = component
        updated.monthlyAmount = min(max(amount, minimum), maximum)

        if let index = draft.selectedFundingComponents.firstIndex(where: { $0.id == component.id }) {
            draft.selectedFundingComponents[index] = updated
        } else {
            draft.selectedFundingComponents.append(updated)
        }
    }

    private func toggleSubscription(_ item: SubscriptionFundingItem) {
        if selectedSubscriptionIds.contains(item.id) {
            selectedSubscriptionIds.remove(item.id)
        } else {
            selectedSubscriptionIds.insert(item.id)
        }

        syncSubscriptionComponent()
    }

    private func syncSubscriptionComponent() {
        guard let subscriptionOption else { return }

        if selectedSubscriptionTotal <= 0 {
            draft.selectedFundingComponents.removeAll { $0.id == subscriptionOption.id }
            return
        }

        let names = selectedSubscriptionItems
            .map(\.merchant)
            .joined(separator: ", ")
        var updated = subscriptionOption
        updated.monthlyAmount = selectedSubscriptionTotal
        updated.maxMonthlyAmount = max(subscriptionOption.maxMonthlyAmount ?? 0, selectedSubscriptionTotal)
        updated.note = "Cancel or pause: \(names)."

        if let index = draft.selectedFundingComponents.firstIndex(where: { $0.id == subscriptionOption.id }) {
            draft.selectedFundingComponents[index] = updated
        } else {
            draft.selectedFundingComponents.append(updated)
        }
    }
}

private struct SubscriptionFundingItem: Identifiable, Equatable {
    var id: String { merchant.lowercased() }
    let merchant: String
    let monthlyAmount: Double
}

private struct AdjustableFundingComponentCard: View {
    let component: PlannerFundingComponent
    let selectedComponent: PlannerFundingComponent?
    let onToggle: () -> Void
    let onAmountChange: (Double) -> Void

    private var isSelected: Bool { selectedComponent != nil }
    private var selectedAmount: Double { selectedComponent?.monthlyAmount ?? component.monthlyAmount }
    private var minimumAmount: Double { component.monthlyAmount }
    private var maximumAmount: Double { max(component.maxMonthlyAmount ?? component.monthlyAmount, minimumAmount) }

    private var sliderValue: Binding<Double> {
        Binding(
            get: { selectedAmount },
            set: { onAmountChange($0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: onToggle) {
                fundingHeader
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            if isSelected && maximumAmount > minimumAmount {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Contribution")
                            .font(.moneCaption)
                            .foregroundStyle(Color.moneSecondary)
                        Spacer()
                        Text(selectedAmount.plannerCurrency + "/mo")
                            .font(.moneCaption.weight(.semibold))
                            .foregroundStyle(Color.monePrimary)
                    }

                    Slider(
                        value: sliderValue,
                        in: minimumAmount...maximumAmount,
                        step: 100
                    )
                    .tint(Color.moneActionFill)

                    HStack {
                        Text("Suggested \(minimumAmount.plannerCurrency)")
                        Spacer()
                        Text("Max \(maximumAmount.plannerCurrency)")
                    }
                    .font(.moneCaption)
                    .foregroundStyle(Color.moneTertiary)
                }
            }
        }
        .padding(MoneSpacing.cardLg)
        .background(isSelected ? Color.moneSurfaceEl : Color.moneSurface)
        .clipShape(RoundedRectangle(cornerRadius: MoneRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MoneRadius.xl, style: .continuous)
                .strokeBorder(isSelected ? Color.moneStrokeBright : Color.moneStroke, lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var fundingHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.moneActionFill.opacity(0.15) : Color.moneSurfaceEl)
                    .frame(width: 52, height: 52)
                Image(systemName: component.source.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isSelected ? Color.moneActionFill : Color.moneSecondary)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(component.source.title)
                    .font(.moneHLSm)
                    .foregroundStyle(Color.monePrimary)

                Text("Current spend: \((component.baseline ?? 0).plannerCurrency)/month.")
                    .font(.moneBodySm)
                    .foregroundStyle(Color.moneSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(isSelected ? Color.moneActionFill : Color.moneTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct FundingComponentCard: View {
    let component: PlannerFundingComponent
    let isSelected: Bool
    let isLocked: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.moneActionFill.opacity(0.15) : Color.moneSurfaceEl)
                        .frame(width: 52, height: 52)
                    Image(systemName: component.source.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(isSelected ? Color.moneActionFill : Color.moneSecondary)
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text(component.source.title)
                        .font(.moneHLSm)
                        .foregroundStyle(Color.monePrimary)

                    Text("Current spend: \((component.baseline ?? component.monthlyAmount).plannerCurrency)/month.")
                        .font(.moneBodySm)
                        .foregroundStyle(Color.moneSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(isSelected ? Color.moneActionFill : Color.moneTertiary)
            }
            .padding(MoneSpacing.cardLg)
            .background(isSelected ? Color.moneSurfaceEl : Color.moneSurface)
            .clipShape(RoundedRectangle(cornerRadius: MoneRadius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: MoneRadius.xl, style: .continuous)
                    .strokeBorder(isSelected ? Color.moneStrokeBright : Color.moneStroke, lineWidth: 1)
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SubscriptionFundingPickerCard: View {
    let component: PlannerFundingComponent
    let items: [SubscriptionFundingItem]
    let selectedIds: Set<String>
    let onToggleItem: (SubscriptionFundingItem) -> Void

    private var selectedTotal: Double {
        items
            .filter { selectedIds.contains($0.id) }
            .reduce(0) { $0 + $1.monthlyAmount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(selectedTotal > 0 ? Color.moneActionFill.opacity(0.15) : Color.moneSurfaceEl)
                        .frame(width: 52, height: 52)
                    Image(systemName: component.source.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(selectedTotal > 0 ? Color.moneActionFill : Color.moneSecondary)
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("Subscriptions")
                        .font(.moneHLSm)
                        .foregroundStyle(Color.monePrimary)

                    Text("Current spend: \((component.baseline ?? items.reduce(0) { $0 + $1.monthlyAmount }).plannerCurrency)/month.")
                        .font(.moneBodySm)
                        .foregroundStyle(Color.moneSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: 10) {
                ForEach(items) { item in
                    Button {
                        onToggleItem(item)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: selectedIds.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(selectedIds.contains(item.id) ? Color.moneActionFill : Color.moneTertiary)

                            Text(item.merchant)
                                .font(.moneBodySm)
                                .foregroundStyle(Color.monePrimary)
                                .lineLimit(1)

                            Spacer()

                            Text(item.monthlyAmount.plannerCurrency)
                                .font(.moneBodySm.weight(.medium))
                                .foregroundStyle(Color.moneSecondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.moneSurface)
                        .clipShape(RoundedRectangle(cornerRadius: MoneRadius.lg, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(MoneSpacing.cardLg)
        .background(selectedTotal > 0 ? Color.moneSurfaceEl : Color.moneSurface)
        .clipShape(RoundedRectangle(cornerRadius: MoneRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MoneRadius.xl, style: .continuous)
                .strokeBorder(selectedTotal > 0 ? Color.moneStrokeBright : Color.moneStroke, lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CorpusPreviewStep: View {
    @Binding var draft: PlannerDraft
    let plannerSnapshot: PlannerFinancialSnapshot
    let transactions: [Transaction]
    let onCreate: () -> Void

    private var durationMonths: Int { draft.selectedDurationMonths ?? 1 }
    private var monthlyRequired: Double { draft.savingsAmount / Double(max(durationMonths, 1)) }
    private var flexibleAmount: Double {
        max(plannerSnapshot.income - max(plannerSnapshot.committed, 0) - max(plannerSnapshot.fund, 0) - max(plannerSnapshot.liability, 0), 0)
    }
    private var comfortableSaving: Double {
        max(flexibleAmount - plannerObservedFlexibleSpend(plannerSnapshot, transactions), 0)
    }
    private var safeContribution: Double { min(comfortableSaving, monthlyRequired) }

    private var components: [PlannerFundingComponent] {
        let safe = PlannerFundingComponent(
            source: .safeCapacity,
            monthlyAmount: safeContribution,
            baseline: flexibleAmount,
            note: "Use current month-end surplus."
        )
        return ([safe] + draft.selectedFundingComponents).filter { $0.monthlyAmount > 0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MoneSpacing.gutter) {
            intro(
                title: "Review the goal",
                subtitle: "This creates one corpus goal with monthly funding actions and milestones."
            )

            VStack(spacing: 14) {
                previewRow("Purpose", draft.savingsPurpose?.title ?? "Goal")
                previewRow("Target", draft.savingsAmount.plannerCurrency)
                previewRow("Timeline", durationMonths == 1 ? "1 month" : "\(durationMonths) months")
                previewRow("Monthly action", monthlyRequired.plannerCurrency)
            }
            .padding(MoneSpacing.cardLg)
            .moneCard(radius: MoneRadius.xl, elevated: true)

            VStack(alignment: .leading, spacing: 14) {
                Text("FUNDING")
                    .moneLabelCaps(color: .moneTertiary)

                ForEach(components) { component in
                    HStack {
                        Image(systemName: component.source.icon)
                            .foregroundStyle(Color.moneSecondary)
                            .frame(width: 24)
                        Text(component.source.title)
                            .font(.moneBodyMd)
                            .foregroundStyle(Color.monePrimary)
                        Spacer()
                        Text(component.monthlyAmount.plannerCurrency)
                            .font(.moneBodySm.weight(.medium))
                            .foregroundStyle(Color.monePrimary)
                    }
                }
            }
            .padding(MoneSpacing.cardLg)
            .moneCard(radius: MoneRadius.xl, elevated: true)

            MonePrimaryButton(title: "Create goal", icon: "checkmark") {
                onCreate()
            }
        }
    }

    private func previewRow(_ key: String, _ value: String) -> some View {
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
        VStack(alignment: .leading, spacing: 20) {
            Button(action: onSelect) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(isSelected ? Color.moneActionFill.opacity(0.15) : Color.moneSurfaceEl)
                            .frame(width: 52, height: 52)
                        Image(systemName: purpose.icon)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(isSelected ? Color.moneActionFill : Color.moneSecondary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(purpose.title)
                            .font(.moneHLSm)
                            .foregroundStyle(Color.monePrimary)
                        Text(purpose.detail)
                            .font(.moneBodySm)
                            .foregroundStyle(Color.moneSecondary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(isSelected ? Color.moneActionFill : Color.moneTertiary)
                }
            }
            .buttonStyle(.plain)

            if isSelected {
                VStack(alignment: .leading, spacing: 20) {
                    MoneField(label: "TARGET AMOUNT") {
                        HStack(spacing: 8) {
                            Text("₹")
                                .font(.moneAmtSm)
                                .foregroundStyle(Color.moneSecondary)
                            TextField("3,00,000", text: $amountText)
                                .keyboardType(.decimalPad)
                                .focused(focusedField, equals: .amount)
                                .moneNumericFieldStyle()
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
        .padding(MoneSpacing.cardLg)
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
        VStack(alignment: .leading, spacing: 14) {
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
        VStack(alignment: .leading, spacing: 20) {
            Button(action: onSelect) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(isSelected ? Color.moneActionFill.opacity(0.15) : Color.moneSurfaceEl)
                            .frame(width: 52, height: 52)
                        Image(systemName: focus.icon)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(isSelected ? Color.moneActionFill : Color.moneSecondary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(focus.title)
                            .font(.moneHLSm)
                            .foregroundStyle(Color.monePrimary)
                        Text("\(baseline.plannerCurrency)/month · \(focus.detail)")
                            .font(.moneBodySm)
                            .foregroundStyle(Color.moneSecondary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(isSelected ? Color.moneActionFill : Color.moneTertiary)
                }
            }
            .buttonStyle(.plain)

            if isSelected {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 0) {
                        MiniStat(label: "Baseline", value: baseline.plannerCurrency)
                        Divider().background(Color.moneStroke).frame(height: 36)
                        MiniStat(label: "Suggested", value: suggestedTarget.plannerCurrency)
                    }
                    .padding(.vertical, 16)
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
                                .moneNumericFieldStyle()
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
        .padding(MoneSpacing.cardLg)
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

            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
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
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.moneSurfaceEl)
                        .clipShape(Capsule())
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.moneSurfaceHigh).frame(height: 8)
                        Capsule()
                            .fill(Color.moneActionFill)
                            .frame(width: geo.size.width * CGFloat(goal.progressFraction), height: 8)
                    }
                }
                .frame(height: 8)

                detailRows

                if let fundingComponents = goal.fundingComponents, !fundingComponents.isEmpty {
                    Divider().background(Color.moneStroke)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("FUNDING")
                            .moneLabelCaps(color: .moneTertiary)

                        ForEach(fundingComponents) { component in
                            HStack(spacing: 10) {
                                Image(systemName: component.source.icon)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color.moneSecondary)
                                    .frame(width: 20)
                                Text(component.source.title)
                                    .font(.moneBodySm)
                                    .foregroundStyle(Color.moneSecondary)
                                Spacer()
                                Text(component.monthlyAmount.plannerCurrency)
                                    .font(.moneBodySm.weight(.medium))
                                    .foregroundStyle(Color.monePrimary)
                            }
                        }
                    }
                }

                Divider().background(Color.moneStroke)

                VStack(alignment: .leading, spacing: 8) {
                    Text("NEXT ACTION")
                        .moneLabelCaps(color: .moneTertiary)
                    Text(goal.nextAction)
                        .font(.moneBodyMd)
                        .foregroundStyle(Color.monePrimary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(MoneSpacing.cardLg)
            .moneCard(radius: MoneRadius.xl, elevated: true)

            VStack(alignment: .leading, spacing: 20) {
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
        VStack(spacing: 14) {
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
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(milestone.isCompleted ? Color.moneHealthy : Color.moneSurfaceEl)
                    .frame(width: 38, height: 38)
                Image(systemName: milestone.isCompleted ? "checkmark" : "circle.fill")
                    .font(.system(size: milestone.isCompleted ? 14 : 7, weight: .bold))
                    .foregroundStyle(milestone.isCompleted ? Color.moneBackground : Color.moneSecondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(milestone.title)
                    .font(.moneHLSm)
                    .foregroundStyle(Color.monePrimary)
                Text(milestone.detail)
                    .font(.moneBodySm)
                    .foregroundStyle(Color.moneSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(MoneSpacing.cardLg)
        .moneCard(radius: MoneRadius.xl, elevated: true)
    }
}

// MARK: - Shared UI Helpers

private func intro(title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 12) {
        Text(title)
            .font(.moneHL)
            .foregroundStyle(Color.monePrimary)
            .fixedSize(horizontal: false, vertical: true)

        Text(subtitle)
            .font(.moneBodyMd)
            .foregroundStyle(Color.moneSecondary)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.top, 8)
}

private struct GoalBuildContextSummary: View {
    let purpose: PlannerSavingsPurpose?
    let amount: Double
    let durationMonths: Int?

    var body: some View {
        HStack(spacing: 12) {
            contextItem(
                icon: purpose?.icon ?? "flag",
                title: purpose?.title ?? "Goal",
                subtitle: "Purpose"
            )

            Divider().background(Color.moneStroke).frame(height: 42)

            contextItem(
                icon: "indianrupeesign",
                title: amount > 0 ? amount.plannerCurrency : "Not set",
                subtitle: "Target"
            )

            if let durationMonths {
                Divider().background(Color.moneStroke).frame(height: 42)
                contextItem(
                    icon: "calendar",
                    title: durationMonths == 1 ? "1 month" : "\(durationMonths) months",
                    subtitle: "Timeline"
                )
            }
        }
        .padding(MoneSpacing.cardSm)
        .background(Color.moneSurface)
        .clipShape(RoundedRectangle(cornerRadius: MoneRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MoneRadius.xl, style: .continuous)
                .strokeBorder(Color.moneStroke, lineWidth: 1)
        )
    }

    private func contextItem(icon: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.moneTertiary)
                Text(subtitle.uppercased())
                    .font(.moneLabelCaps)
                    .tracking(0.8)
                    .foregroundStyle(Color.moneTertiary)
                    .lineLimit(1)
            }

            Text(title)
                .font(.moneBodySm.weight(.medium))
                .foregroundStyle(Color.monePrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private func stackedContributionBar(total: Double, surplus: Double, cuts: Double) -> some View {
    VStack(alignment: .leading, spacing: 10) {
        GeometryReader { geo in
            let safeTotal = max(total, 1)
            let surplusWidth = geo.size.width * min(max(surplus / safeTotal, 0), 1)
            let cutsWidth = geo.size.width * min(max(cuts / safeTotal, 0), 1)

            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.moneHealthy)
                    .frame(width: surplusWidth)
                Rectangle()
                    .fill(Color.moneWatch)
                    .frame(width: cutsWidth)
                Rectangle()
                    .fill(Color.moneSurfaceHigh)
            }
            .clipShape(Capsule())
        }
        .frame(height: 12)

        HStack {
            legendDot(Color.moneHealthy, "Surplus \(surplus.plannerCurrency)")
            Spacer()
            legendDot(Color.moneWatch, "Cuts \(cuts.plannerCurrency)")
        }
    }
}

private func fundingProgressBar(requiredGap: Double, selected: Double) -> some View {
    VStack(alignment: .leading, spacing: 10) {
        HStack {
            Text("Funding selected")
                .font(.moneBodySm.weight(.medium))
                .foregroundStyle(Color.monePrimary)
            Spacer()
            Text("\(min(selected, requiredGap).plannerCurrency) / \(requiredGap.plannerCurrency)")
                .font(.moneBodySm.weight(.medium))
                .foregroundStyle(Color.moneSecondary)
        }

        GeometryReader { geo in
            let progress = requiredGap <= 0 ? 1 : min(max(selected / requiredGap, 0), 1)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.moneSurfaceHigh)
                Capsule()
                    .fill(progress >= 1 ? Color.moneHealthy : Color.moneWatch)
                    .frame(width: geo.size.width * progress)
            }
        }
        .frame(height: 10)
    }
    .padding(MoneSpacing.cardSm)
    .background(Color.moneSurface)
    .clipShape(RoundedRectangle(cornerRadius: MoneRadius.xl, style: .continuous))
    .overlay(
        RoundedRectangle(cornerRadius: MoneRadius.xl, style: .continuous)
            .strokeBorder(Color.moneStroke, lineWidth: 1)
    )
}

private func legendDot(_ color: Color, _ label: String) -> some View {
    HStack(spacing: 6) {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
        Text(label)
            .font(.moneCaption)
            .foregroundStyle(Color.moneSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

private func formatIndianNumber(_ value: Double) -> String {
    guard value > 0 else { return "" }

    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.locale = Locale(identifier: "en_IN")
    formatter.maximumFractionDigits = 0
    return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
}

private func formatIndianCurrencyInput(_ value: Double) -> String {
    let number = formatIndianNumber(value)
    return number.isEmpty ? "₹" : "₹\(number)"
}

private func plannerFlexibleAmount(_ snapshot: PlannerFinancialSnapshot) -> Double {
    snapshot.goalPlanningFlexibleAmount
}

private func plannerObservedFlexibleSpend(_ snapshot: PlannerFinancialSnapshot, _ transactions: [Transaction]) -> Double {
    snapshot.goalPlanningFlexibleSpend
}

private func plannerMonthKey(for date: Date) -> String {
    let components = Calendar.current.dateComponents([.year, .month], from: date)
    return String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
}

private func selectableRow(
    icon: String,
    title: String,
    subtitle: String,
    isSelected: Bool,
    tag: String? = nil,
    isDisabled: Bool = false
) -> some View {
    HStack(alignment: .top, spacing: 14) {
        ZStack {
            Circle()
                .fill(isSelected ? Color.moneActionFill.opacity(0.15) : Color.moneSurfaceEl)
                .frame(width: 52, height: 52)
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(isSelected ? Color.moneActionFill : isDisabled ? Color.moneTertiary : Color.moneSecondary)
        }

        VStack(alignment: .leading, spacing: 6) {
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
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }

        Spacer()

        if !isDisabled {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(isSelected ? Color.moneActionFill : Color.moneTertiary)
        }
    }
    .padding(MoneSpacing.cardLg)
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

private struct CurrencyAmountTextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    let maximumAmount: Double

    func makeUIView(context: Context) -> InsetlessCurrencyTextField {
        let textField = InsetlessCurrencyTextField()
        textField.delegate = context.coordinator
        textField.keyboardType = .numberPad
        textField.textAlignment = .right
        textField.textColor = UIColor(Color.monePrimary)
        textField.tintColor = UIColor(Color.monePrimary)
        textField.backgroundColor = .clear
        textField.borderStyle = .none
        textField.font = .moneAmountInput
        textField.setContentCompressionResistancePriority(.required, for: .horizontal)
        return textField
    }

    func updateUIView(_ textField: InsetlessCurrencyTextField, context: Context) {
        if textField.text != text {
            textField.text = text
        }

        if isFocused, !textField.isFirstResponder {
            textField.becomeFirstResponder()
        } else if !isFocused, textField.isFirstResponder {
            textField.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isFocused: $isFocused, maximumAmount: maximumAmount)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding private var text: String
        @Binding private var isFocused: Bool
        private let maximumAmount: Double

        init(text: Binding<String>, isFocused: Binding<Bool>, maximumAmount: Double) {
            _text = text
            _isFocused = isFocused
            self.maximumAmount = maximumAmount
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            isFocused = true
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            isFocused = false
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            let current = textField.text ?? "₹"
            guard let textRange = Range(range, in: current) else { return false }
            let proposed = current.replacingCharacters(in: textRange, with: string)
            let numeric = Double(proposed.plannerNumericOnly) ?? 0
            let formatted = formatIndianCurrencyInput(min(numeric, maximumAmount))
            text = formatted
            textField.text = formatted

            if let end = textField.endOfDocument as UITextPosition? {
                textField.selectedTextRange = textField.textRange(from: end, to: end)
            }

            return false
        }
    }
}

private final class InsetlessCurrencyTextField: UITextField {
    override func textRect(forBounds bounds: CGRect) -> CGRect {
        bounds
    }

    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        bounds
    }

    override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        bounds
    }
}

private extension UIFont {
    static let moneAmountInput = UIFont.monospacedSystemFont(ofSize: 18, weight: .medium)
}

#Preview {
    GoalsView()
        .environment(AppViewModel())
}
