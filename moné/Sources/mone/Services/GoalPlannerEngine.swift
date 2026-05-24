import Foundation

struct GoalPlannerEngine {
    // MARK: - Savings Feasibility

    func safeMonthlyGoalCapacity(snapshot: PlannerFinancialSnapshot) -> Double {
        snapshot.safeMonthlyGoalCapacity
    }

    func safeMonthlyGoalCapacity(moneyMap: MoneyMap, transactions: [Transaction]) -> Double {
        let snapshot = PlannerFinancialSnapshot.from(
            dashboardSummary: nil,
            moneyMapModel: nil,
            fallbackMoneyMap: moneyMap,
            fallbackTransactions: transactions
        )
        return safeMonthlyGoalCapacity(snapshot: snapshot)
    }

    func monthlyRequired(targetAmount: Double, deadline: Date) -> Double {
        let months = max(1, Calendar.current.dateComponents([.month], from: Date(), to: deadline).month ?? 1)
        return targetAmount / Double(months)
    }

    func savingsFeasibilityMessage(
        amount: Double,
        deadline: Date,
        snapshot: PlannerFinancialSnapshot
    ) -> String? {
        guard amount > 0 else { return nil }
        let required = monthlyRequired(targetAmount: amount, deadline: deadline)
        let capacity = safeMonthlyGoalCapacity(snapshot: snapshot)

        if required > snapshot.income {
            return "This needs \(required.plannerCurrency)/month, which is more than your detected monthly income. Choose a later date or lower target."
        }

        if required > capacity {
            return "This needs \(required.plannerCurrency)/month. A safer limit from your current money map is around \(capacity.plannerCurrency)/month after protecting obligations, everyday spends, fund-building, and review buffer."
        }

        return nil
    }

    func savingsFeasibilityMessage(
        amount: Double,
        deadline: Date,
        moneyMap: MoneyMap,
        transactions: [Transaction]
    ) -> String? {
        let snapshot = PlannerFinancialSnapshot.from(
            dashboardSummary: nil,
            moneyMapModel: nil,
            fallbackMoneyMap: moneyMap,
            fallbackTransactions: transactions
        )
        return savingsFeasibilityMessage(amount: amount, deadline: deadline, snapshot: snapshot)
    }

    func isSavingsGoalUnrealistic(
        amount: Double,
        deadline: Date,
        snapshot: PlannerFinancialSnapshot
    ) -> Bool {
        savingsFeasibilityMessage(
            amount: amount,
            deadline: deadline,
            snapshot: snapshot
        ) != nil
    }

    func isSavingsGoalUnrealistic(
        amount: Double,
        deadline: Date,
        moneyMap: MoneyMap,
        transactions: [Transaction]
    ) -> Bool {
        let snapshot = PlannerFinancialSnapshot.from(
            dashboardSummary: nil,
            moneyMapModel: nil,
            fallbackMoneyMap: moneyMap,
            fallbackTransactions: transactions
        )
        return isSavingsGoalUnrealistic(amount: amount, deadline: deadline, snapshot: snapshot)
    }

    func deadlineDistanceLabel(from date: Date) -> String {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.startOfDay(for: date)
        let days = max(0, cal.dateComponents([.day], from: start, to: end).day ?? 0)

        if days < 60 {
            return days == 1 ? "1 day" : "\(days) days"
        }

        let months = max(1, cal.dateComponents([.month], from: start, to: end).month ?? 1)
        if months < 24 {
            return months == 1 ? "1 month" : "\(months) months"
        }

        let years = months / 12
        let remainingMonths = months % 12
        if remainingMonths == 0 {
            return years == 1 ? "1 year" : "\(years) years"
        }
        return "\(years)y \(remainingMonths)m"
    }

    // MARK: - Savings Plans

    func savingsPlanPreviews(
        purpose: PlannerSavingsPurpose,
        targetAmount: Double,
        deadline: Date,
        snapshot: PlannerFinancialSnapshot
    ) -> [PlannerPlanPreview] {
        let required = monthlyRequired(targetAmount: targetAmount, deadline: deadline)
        let capacity = safeMonthlyGoalCapacity(snapshot: snapshot)
        let comfortable = max(1_000, min(required, capacity * 0.65))
        let optimal = required
        let aggressive = min(max(required * 1.18, required + 2_000), snapshot.income)

        return [
            PlannerPlanPreview(
                mode: .comfortable,
                headline: "Comfortable",
                detail: "Lowest pressure. Best when you want progress without changing much.",
                monthlyAction: comfortable,
                impact: "Low lifestyle impact",
                bullets: [
                    "Save mainly from existing surplus",
                    "Keep emergency liquidity untouched",
                    "Reduce pressure by allowing timeline flexibility"
                ],
                isRecommended: false
            ),
            PlannerPlanPreview(
                mode: .optimalBalance,
                headline: "Optimal\nbalance",
                detail: "Recommended. Meaningful progress with only a few lifestyle trade-offs.",
                monthlyAction: optimal,
                impact: "Recommended by Moné",
                bullets: [
                    "Save first after salary credit",
                    "Recover gaps from 1–2 leakage categories",
                    "Adjust monthly using milestones"
                ],
                isRecommended: true
            ),
            PlannerPlanPreview(
                mode: .aggressive,
                headline: "Aggressive",
                detail: "Fastest path. Use only if this goal is urgent enough for stricter limits.",
                monthlyAction: aggressive,
                impact: "High discipline needed",
                bullets: [
                    "Prioritise this goal before discretionary spends",
                    "Use tighter weekly caps",
                    "Redirect subscriptions or leakage quickly"
                ],
                isRecommended: false
            )
        ]
    }

    func savingsPlanPreviews(
        purpose: PlannerSavingsPurpose,
        targetAmount: Double,
        deadline: Date,
        moneyMap: MoneyMap,
        transactions: [Transaction]
    ) -> [PlannerPlanPreview] {
        let snapshot = PlannerFinancialSnapshot.from(
            dashboardSummary: nil,
            moneyMapModel: nil,
            fallbackMoneyMap: moneyMap,
            fallbackTransactions: transactions
        )
        return savingsPlanPreviews(
            purpose: purpose,
            targetAmount: targetAmount,
            deadline: deadline,
            snapshot: snapshot
        )
    }

    func createSavingsGoal(
        purpose: PlannerSavingsPurpose,
        targetAmount: Double,
        deadline: Date,
        mode: PlannerPlanMode,
        snapshot: PlannerFinancialSnapshot,
        transactions: [Transaction]
    ) -> PlannerGoal {
        let previews = savingsPlanPreviews(
            purpose: purpose,
            targetAmount: targetAmount,
            deadline: deadline,
            snapshot: snapshot
        )
        let monthlyAction = previews.first(where: { $0.mode == mode })?.monthlyAction
            ?? monthlyRequired(targetAmount: targetAmount, deadline: deadline)
        let projected = projectedDate(targetAmount: targetAmount, monthlyContribution: monthlyAction)
        let capacity = safeMonthlyGoalCapacity(snapshot: snapshot)

        return PlannerGoal(
            kind: .buildSavings,
            title: purpose.title,
            planMode: mode,
            nextAction: savingsNextAction(mode: mode, monthlyContribution: monthlyAction, transactions: transactions),
            milestones: savingsMilestones(targetAmount: targetAmount, purpose: purpose),
            savings: PlannerSavingsDetails(
                purpose: purpose,
                targetAmount: targetAmount,
                currentAmount: 0,
                desiredDeadline: deadline,
                projectedCompletionDate: projected,
                monthlyContribution: monthlyAction,
                safeMonthlyCapacity: capacity
            ),
            spending: nil
        )
    }

    func createSavingsGoal(
        purpose: PlannerSavingsPurpose,
        targetAmount: Double,
        deadline: Date,
        mode: PlannerPlanMode,
        moneyMap: MoneyMap,
        transactions: [Transaction]
    ) -> PlannerGoal {
        let snapshot = PlannerFinancialSnapshot.from(
            dashboardSummary: nil,
            moneyMapModel: nil,
            fallbackMoneyMap: moneyMap,
            fallbackTransactions: transactions
        )
        return createSavingsGoal(
            purpose: purpose,
            targetAmount: targetAmount,
            deadline: deadline,
            mode: mode,
            snapshot: snapshot,
            transactions: transactions
        )
    }

    // MARK: - Spending Plans

    func baselineSpend(for focus: PlannerSpendingFocus, transactions: [Transaction]) -> Double {
        let cal = Calendar.current
        let fromDate = cal.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let debits = transactions.filter { tx in
            !tx.isUpcoming && tx.type == .debit && tx.date >= fromDate
        }

        let total: Double
        if focus == .upiSmallSpends {
            total = debits.filter { $0.amount <= 1_000 }.reduce(0) { $0 + $1.amount }
        } else if let mapped = focus.mappedCategory {
            total = debits.filter { $0.category == mapped }.reduce(0) { $0 + $1.amount }
        } else {
            total = 0
        }

        return max(total, focus.fallbackBaseline)
    }

    func suggestedTargetSpend(for focus: PlannerSpendingFocus, transactions: [Transaction]) -> Double {
        let baseline = baselineSpend(for: focus, transactions: transactions)
        return max(1_000, baseline * 0.70)
    }

    func spendingPlanPreviews(
        focus: PlannerSpendingFocus,
        targetSpend: Double,
        transactions: [Transaction]
    ) -> [PlannerPlanPreview] {
        let baseline = baselineSpend(for: focus, transactions: transactions)
        let comfortableTarget = max(targetSpend, baseline - 1_500)
        let optimalTarget = targetSpend
        let aggressiveTarget = max(1_000, min(targetSpend * 0.80, baseline * 0.62))

        return [
            PlannerPlanPreview(
                mode: .comfortable,
                headline: "Comfortable",
                detail: "Awareness first. Reduce gently without strict alerts.",
                monthlyAction: comfortableTarget,
                impact: "Save around \(max(0, baseline - comfortableTarget).plannerCurrency)",
                bullets: [
                    "Use weekly check-ins",
                    "Reduce a small amount first",
                    "Keep normal lifestyle mostly intact"
                ],
                isRecommended: false
            ),
            PlannerPlanPreview(
                mode: .optimalBalance,
                headline: "Optimal\nbalance",
                detail: "Recommended. Visible savings without making the plan too strict.",
                monthlyAction: optimalTarget,
                impact: "Save around \(max(0, baseline - optimalTarget).plannerCurrency)",
                bullets: [
                    "Set a weekly category cap",
                    "Watch repeat spends at 80%",
                    "Redirect saved money to a savings goal"
                ],
                isRecommended: true
            ),
            PlannerPlanPreview(
                mode: .aggressive,
                headline: "Aggressive",
                detail: "Stricter cap for categories that are hurting your monthly plan.",
                monthlyAction: aggressiveTarget,
                impact: "Save around \(max(0, baseline - aggressiveTarget).plannerCurrency)",
                bullets: [
                    "Use 50%, 80%, and 100% alerts",
                    "Pause before repeat high-value spends",
                    "Recover weekly if you cross the pace"
                ],
                isRecommended: false
            )
        ]
    }

    func createSpendingGoal(
        focus: PlannerSpendingFocus,
        targetSpend: Double,
        durationDays: Int,
        mode: PlannerPlanMode,
        transactions: [Transaction]
    ) -> PlannerGoal {
        let previews = spendingPlanPreviews(focus: focus, targetSpend: targetSpend, transactions: transactions)
        let target = previews.first(where: { $0.mode == mode })?.monthlyAction ?? targetSpend
        let baseline = baselineSpend(for: focus, transactions: transactions)
        let expectedSaving = max(0, baseline - target)

        return PlannerGoal(
            kind: .controlSpending,
            title: "\(focus.title) Control",
            planMode: mode,
            nextAction: "Track \(focus.title.lowercased()) spends for 7 days before judging the plan.",
            milestones: spendingMilestones(focus: focus, targetSpend: target, durationDays: durationDays),
            savings: nil,
            spending: PlannerSpendingDetails(
                focus: focus,
                baselineMonthlySpend: baseline,
                targetMonthlySpend: target,
                currentSpend: 0,
                durationDays: durationDays,
                expectedMonthlySaving: expectedSaving
            )
        )
    }

    // MARK: - Corpus Goal Plans

    func corpusTimelineOptions(
        targetAmount: Double,
        snapshot: PlannerFinancialSnapshot,
        transactions: [Transaction]
    ) -> [PlannerTimelineOption] {
        guard targetAmount > 0 else { return [] }

        let flexibleAmount = monthlyFlexibleAmount(snapshot: snapshot)
        let comfortableSaving = comfortableMonthlySaving(snapshot: snapshot, transactions: transactions)
        let stretchCapacity = stretchMonthlySavingCapacity(snapshot: snapshot)
        let absoluteCapacity = absoluteMonthlySavingCap(snapshot: snapshot)
        let baseMonths: [Int]

        if comfortableSaving > 0 || stretchCapacity > 0 {
            let comfortableMonths = comfortableSaving > 0 ? Int(ceil(targetAmount / comfortableSaving)) : 18
            let stretchMonths = stretchCapacity > 0 ? Int(ceil(targetAmount / stretchCapacity)) : comfortableMonths
            let absoluteMonths = absoluteCapacity > 0 ? Int(ceil(targetAmount / absoluteCapacity)) : stretchMonths
            baseMonths = [
                max(3, absoluteMonths),
                max(3, comfortableMonths),
                max(3, stretchMonths),
                min(60, max(comfortableMonths + 3, Int(Double(comfortableMonths) * 1.35)))
            ]
        } else {
            baseMonths = [6, 12, 18]
        }

        return Array(Set(baseMonths))
            .sorted()
            .map { months in
                corpusTimelineOption(
                    targetAmount: targetAmount,
                    months: months,
                    flexibleAmount: flexibleAmount,
                    comfortableSaving: comfortableSaving,
                    stretchCapacity: stretchCapacity,
                    absoluteCapacity: absoluteCapacity
                )
            }
    }

    func corpusTimelineOption(
        targetAmount: Double,
        months: Int,
        snapshot: PlannerFinancialSnapshot,
        transactions: [Transaction]
    ) -> PlannerTimelineOption {
        corpusTimelineOption(
            targetAmount: targetAmount,
            months: months,
            flexibleAmount: monthlyFlexibleAmount(snapshot: snapshot),
            comfortableSaving: comfortableMonthlySaving(snapshot: snapshot, transactions: transactions),
            stretchCapacity: stretchMonthlySavingCapacity(snapshot: snapshot),
            absoluteCapacity: absoluteMonthlySavingCap(snapshot: snapshot)
        )
    }

    func corpusTimelineMonthRange(
        targetAmount: Double,
        snapshot: PlannerFinancialSnapshot,
        transactions: [Transaction]
    ) -> ClosedRange<Int> {
        let options = corpusTimelineOptions(
            targetAmount: targetAmount,
            snapshot: snapshot,
            transactions: transactions
        )
        let lower = options.map(\.months).min() ?? 3
        let upper = options.map(\.months).max() ?? 60

        return lower...max(lower, upper)
    }

    func leakageFundingOptions(
        transactions: [Transaction],
        snapshot: PlannerFinancialSnapshot,
        monthlyRequired: Double
    ) -> [PlannerFundingComponent] {
        let focuses: [PlannerSpendingFocus] = [
            .foodDelivery,
            .shopping,
            .subscriptions,
            .upiSmallSpends,
            .entertainment,
            .travel
        ]
        let comfortableSaving = comfortableMonthlySaving(snapshot: snapshot, transactions: transactions)
        let neededFromLeakage = max(monthlyRequired - comfortableSaving, 0)

        var candidates = focuses
            .map { focus in
                let actual = actualRecentSpend(for: focus, transactions: transactions)
                let baseline = actual
                let maxRecoverable = max(0, min(baseline * recoveryRate(for: focus), baseline - minimumSpendFloor(for: focus)))
                return (focus: focus, actual: actual, baseline: baseline, maxRecoverable: maxRecoverable)
            }
            .filter { $0.baseline > 0 && $0.maxRecoverable > 0 }

        if candidates.isEmpty {
            candidates = focuses
                .map { focus in
                    let baseline = focus.fallbackBaseline
                    let maxRecoverable = max(0, min(baseline * recoveryRate(for: focus), baseline - minimumSpendFloor(for: focus)))
                    return (focus: focus, actual: 0, baseline: baseline, maxRecoverable: maxRecoverable)
                }
                .filter { $0.maxRecoverable > 0 }
        }

        let observedCategorySpend = candidates.reduce(0) { $0 + $1.baseline }

        return candidates
            .map { candidate in
                let proportionalShare = observedCategorySpend > 0
                    ? neededFromLeakage * (candidate.baseline / observedCategorySpend)
                    : candidate.maxRecoverable
                let suggestedRecovery = neededFromLeakage > 0
                    ? min(candidate.maxRecoverable, max(1_000, proportionalShare))
                    : candidate.maxRecoverable
                let note = fundingNote(
                    focus: candidate.focus,
                    actual: candidate.actual,
                    baseline: candidate.baseline,
                    suggestedRecovery: suggestedRecovery,
                    maxRecoverable: candidate.maxRecoverable
                )

                return PlannerFundingComponent(
                    source: .leakage(candidate.focus),
                    monthlyAmount: suggestedRecovery,
                    maxMonthlyAmount: candidate.maxRecoverable,
                    baseline: candidate.baseline,
                    note: note
                )
            }
            .filter { $0.monthlyAmount > 0 }
            .sorted { $0.monthlyAmount > $1.monthlyAmount }
    }

    func createCorpusGoal(
        purpose: PlannerSavingsPurpose,
        targetAmount: Double,
        durationMonths: Int,
        selectedFunding: [PlannerFundingComponent],
        snapshot: PlannerFinancialSnapshot,
        transactions: [Transaction]
    ) -> PlannerGoal {
        let monthlyRequired = targetAmount / Double(max(durationMonths, 1))
        let comfortableSaving = comfortableMonthlySaving(snapshot: snapshot, transactions: transactions)
        let safeContribution = min(comfortableSaving, monthlyRequired)
        let safeComponent = PlannerFundingComponent(
            source: .safeCapacity,
            monthlyAmount: safeContribution,
            baseline: monthlyFlexibleAmount(snapshot: snapshot),
            note: "Use current month-end surplus before adding cuts."
        )
        let components = ([safeComponent] + selectedFunding)
            .filter { $0.monthlyAmount > 0 }
        let projected = Calendar.current.date(byAdding: .month, value: durationMonths, to: Date()) ?? Date()

        return PlannerGoal(
            kind: .buildSavings,
            title: purpose.title,
            planMode: .optimalBalance,
            nextAction: corpusNextAction(components: components, monthlyRequired: monthlyRequired),
            milestones: corpusMilestones(
                targetAmount: targetAmount,
                purpose: purpose,
                durationMonths: durationMonths,
                monthlyRequired: monthlyRequired,
                funding: components
            ),
            savings: PlannerSavingsDetails(
                purpose: purpose,
                targetAmount: targetAmount,
                currentAmount: 0,
                desiredDeadline: projected,
                projectedCompletionDate: projected,
                monthlyContribution: monthlyRequired,
                safeMonthlyCapacity: comfortableSaving,
                durationMonths: durationMonths
            ),
            spending: nil,
            fundingComponents: components
        )
    }

    // MARK: - Private Helpers

    private func actualRecentSpend(for focus: PlannerSpendingFocus, transactions: [Transaction]) -> Double {
        let debits = transactions.filter { tx in
            !tx.isUpcoming && tx.type == .debit
        }
        let monthCount = max(Set(debits.map { monthKey(for: $0.date) }).count, 1)

        let total: Double
        if focus == .upiSmallSpends {
            total = debits
                .filter { $0.amount <= 1_000 && $0.category == .other }
                .reduce(0) { $0 + $1.amount }
        } else {
            guard let mapped = focus.mappedCategory else { return 0 }
            total = debits.filter { $0.category == mapped }.reduce(0) { $0 + $1.amount }
        }

        return total / Double(monthCount)
    }

    private func monthKey(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
    }

    private func monthlyFlexibleAmount(snapshot: PlannerFinancialSnapshot) -> Double {
        snapshot.goalPlanningFlexibleAmount
    }

    private func comfortableMonthlySaving(
        snapshot: PlannerFinancialSnapshot,
        transactions: [Transaction]
    ) -> Double {
        max(monthlyFlexibleAmount(snapshot: snapshot) - observedMonthlyFlexibleSpend(snapshot: snapshot, transactions: transactions), 0)
    }

    private func stretchMonthlySavingCapacity(snapshot: PlannerFinancialSnapshot) -> Double {
        monthlyFlexibleAmount(snapshot: snapshot) * 0.50
    }

    private func absoluteMonthlySavingCap(snapshot: PlannerFinancialSnapshot) -> Double {
        monthlyFlexibleAmount(snapshot: snapshot)
    }

    private func corpusTimelineDetail(
        isComfortable: Bool,
        isPossible: Bool,
        monthlyRequired: Double,
        comfortableSaving: Double,
        stretchCapacity: Double,
        flexibleAmount: Double,
        leakageNeeded: Double
    ) -> String {
        if isComfortable {
            return "Covered by current month-end surplus of \(comfortableSaving.plannerCurrency)/month."
        }

        if isPossible {
            if monthlyRequired <= stretchCapacity {
                return "Stretch. Needs \(leakageNeeded.plannerCurrency)/month from selected spending cuts."
            }

            return "Aggressive. Above the stretch level of \(stretchCapacity.plannerCurrency)/month."
        }

        return "Not practical. This needs \(monthlyRequired.plannerCurrency)/month, above the full flexible amount of \(flexibleAmount.plannerCurrency)."
    }

    private func corpusTimelineOption(
        targetAmount: Double,
        months: Int,
        flexibleAmount: Double,
        comfortableSaving: Double,
        stretchCapacity: Double,
        absoluteCapacity: Double
    ) -> PlannerTimelineOption {
        let safeMonths = max(months, 1)
        let monthlyRequired = targetAmount / Double(safeMonths)
        let safeContribution = min(comfortableSaving, monthlyRequired)
        let leakageNeeded = max(monthlyRequired - safeContribution, 0)
        let isComfortable = monthlyRequired <= comfortableSaving
        let isPossible = monthlyRequired <= absoluteCapacity
        let statusLabel: String

        if isComfortable {
            statusLabel = "Comfortable"
        } else if !isPossible {
            statusLabel = "Impractical"
        } else if monthlyRequired <= stretchCapacity {
            statusLabel = "Stretch"
        } else {
            statusLabel = "Aggressive"
        }

        return PlannerTimelineOption(
            months: safeMonths,
            monthlyRequired: monthlyRequired,
            safeContribution: safeContribution,
            leakageNeeded: leakageNeeded,
            statusLabel: statusLabel,
            label: safeMonths == 1 ? "1 month" : "\(safeMonths) months",
            detail: corpusTimelineDetail(
                isComfortable: isComfortable,
                isPossible: isPossible,
                monthlyRequired: monthlyRequired,
                comfortableSaving: comfortableSaving,
                stretchCapacity: stretchCapacity,
                flexibleAmount: flexibleAmount,
                leakageNeeded: leakageNeeded
            ),
            isComfortable: isComfortable,
            isPossible: isPossible
        )
    }

    private func observedMonthlyFlexibleSpend(
        snapshot: PlannerFinancialSnapshot,
        transactions: [Transaction]
    ) -> Double {
        snapshot.goalPlanningFlexibleSpend
    }

    private func recoveryRate(for focus: PlannerSpendingFocus) -> Double {
        switch focus {
        case .shopping:
            return 0.60
        case .subscriptions:
            return 0.70
        case .foodDelivery, .entertainment:
            return 0.45
        case .upiSmallSpends:
            return 0.40
        case .travel:
            return 0.25
        case .custom:
            return 0.30
        }
    }

    private func minimumSpendFloor(for focus: PlannerSpendingFocus) -> Double {
        switch focus {
        case .subscriptions:
            return 500
        case .upiSmallSpends:
            return 1_000
        case .foodDelivery, .shopping, .entertainment, .travel, .custom:
            return 2_000
        }
    }

    private func fundingNote(
        focus: PlannerSpendingFocus,
        actual: Double,
        baseline: Double,
        suggestedRecovery: Double,
        maxRecoverable: Double
    ) -> String {
        let source = actual > 0 ? "Current spend" : "Estimated spend"
        return "\(source): \(baseline.plannerCurrency)/month. Suggested contribution: \(suggestedRecovery.plannerCurrency), with up to \(maxRecoverable.plannerCurrency) possible."
    }

    private func projectedDate(targetAmount: Double, monthlyContribution: Double) -> Date {
        guard monthlyContribution > 0 else { return Date() }
        let months = Int(ceil(targetAmount / monthlyContribution))
        return Calendar.current.date(byAdding: .month, value: months, to: Date()) ?? Date()
    }

    private func savingsMilestones(targetAmount: Double, purpose: PlannerSavingsPurpose) -> [PlannerMilestone] {
        let firstLayer = min(targetAmount * 0.10, 25_000)
        let purposeDetail = purpose == .emergencyFund ? "A first safety layer for unexpected expenses." : "First proof that the plan is moving."

        return [
            PlannerMilestone(title: "\(firstLayer.plannerCurrency) saved", detail: purposeDetail, targetAmount: firstLayer),
            PlannerMilestone(title: "\((targetAmount * 0.25).plannerCurrency) saved", detail: "25% of the goal is protected.", targetAmount: targetAmount * 0.25),
            PlannerMilestone(title: "\((targetAmount * 0.50).plannerCurrency) saved", detail: "Halfway there. The plan should feel easier now.", targetAmount: targetAmount * 0.50),
            PlannerMilestone(title: "\((targetAmount * 0.75).plannerCurrency) saved", detail: "Strong buffer built. Avoid using this unless the goal changes.", targetAmount: targetAmount * 0.75),
            PlannerMilestone(title: "\(targetAmount.plannerCurrency) saved", detail: "Goal complete.", targetAmount: targetAmount)
        ]
    }

    private func spendingMilestones(focus: PlannerSpendingFocus, targetSpend: Double, durationDays: Int) -> [PlannerMilestone] {
        let weeklyCap = targetSpend / 4
        return [
            PlannerMilestone(title: "7 days tracked", detail: "Understand the current rhythm without judging it."),
            PlannerMilestone(title: "First visible reduction", detail: "Spend less than the previous weekly pace."),
            PlannerMilestone(title: "Stay within weekly cap", detail: "Keep this week under \(weeklyCap.plannerCurrency)."),
            PlannerMilestone(title: "\(durationDays)-day target hit", detail: "Finish under \(targetSpend.plannerCurrency) for \(focus.title.lowercased())."),
            PlannerMilestone(title: "Redirect savings", detail: "Move the saved amount to a savings goal.")
        ]
    }

    private func savingsNextAction(
        mode: PlannerPlanMode,
        monthlyContribution: Double,
        transactions: [Transaction]
    ) -> String {
        let firstMove = max(1_000, monthlyContribution * 0.32)
        switch mode {
        case .comfortable:
            return "Move \(firstMove.plannerCurrency) after salary credit and keep the rest flexible."
        case .optimalBalance:
            return "Move \(firstMove.plannerCurrency) after salary credit, then recover the gap from one leakage category."
        case .aggressive:
            return "Move \((monthlyContribution * 0.50).plannerCurrency) first, then keep discretionary spends tighter this week."
        }
    }

    private func corpusMilestones(
        targetAmount: Double,
        purpose: PlannerSavingsPurpose,
        durationMonths: Int,
        monthlyRequired: Double,
        funding: [PlannerFundingComponent]
    ) -> [PlannerMilestone] {
        let firstLayer = min(targetAmount * 0.10, 25_000)
        var milestones = savingsMilestones(targetAmount: targetAmount, purpose: purpose)
        let fundingLine = funding
            .prefix(3)
            .map { "\($0.source.title): \($0.monthlyAmount.plannerCurrency)" }
            .joined(separator: " + ")

        milestones.insert(
            PlannerMilestone(
                title: "Month 1 plan active",
                detail: "Save \(monthlyRequired.plannerCurrency) using \(fundingLine)."
            ),
            at: 0
        )

        if durationMonths > 1 {
            milestones.insert(
                PlannerMilestone(
                    title: "\(firstLayer.plannerCurrency) first layer",
                    detail: "Confirm the monthly rhythm before increasing pressure.",
                    targetAmount: firstLayer
                ),
                at: 1
            )
        }

        return milestones
    }

    private func corpusNextAction(
        components: [PlannerFundingComponent],
        monthlyRequired: Double
    ) -> String {
        if let primaryLeakage = components.first(where: {
            if case .leakage = $0.source { return true }
            return false
        }) {
            return "Save \(monthlyRequired.plannerCurrency) this month and start with \(primaryLeakage.source.title.lowercased()) to recover \(primaryLeakage.monthlyAmount.plannerCurrency)."
        }

        return "Move \(monthlyRequired.plannerCurrency) after salary credit and track it as this month's corpus milestone."
    }
}
