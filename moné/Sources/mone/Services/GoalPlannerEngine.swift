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

    // MARK: - Private Helpers

    private func recentMonthlyEverydaySpend(transactions: [Transaction]) -> Double {
        let cal = Calendar.current
        let fromDate = cal.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return transactions
            .filter { tx in
                !tx.isUpcoming &&
                tx.type == .debit &&
                tx.date >= fromDate &&
                tx.category != .housing &&
                tx.category != .creditCard &&
                tx.category != .bills
            }
            .reduce(0) { $0 + $1.amount }
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
}
