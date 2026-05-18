# Synthetic Data Master Specification — Moné

> Version: 1.0  
> Last updated: 2026-05-18  
> Status: Active — Pass 1 in progress

---

## Purpose

Build hyper-realistic synthetic Account Aggregator (AA)-style dummy data for Moné's personal finance intelligence engine.

Current Setu sandbox data is structurally useful but behaviorally unrealistic. It gives us the raw AA-style payload shape (top-level data objects, decryptedFI, FI type, account profile, summary, linked account reference, masked account number, account-type-specific transactions, transaction modes, dates, balances, narrations). We preserve that structure but generate realistic financial behavior.

## What This Data Tests

- Income detection
- Obligation detection
- Recurring commitments
- Expenditure rhythm
- Unnecessary spending
- Cashflow risk
- Goal drift
- Timely interventions / nudges
- Safe-to-spend
- Financial health
- Liquidity vs net worth
- Persona-specific money behavior

## Core Principle

Generate data like a life simulator:

```
Persona life profile
→ yearly financial calendar
→ monthly obligations
→ weekly habits
→ daily spending rhythm
→ random life events
→ account-type-specific transactions
→ ground truth labels
→ AA-style payload
→ canonical parser
→ validation against ground truth
```

**Do not generate transactions first. Generate a user's life first, then let financial transactions emerge from it.**

## Target Account Types

### Phase 1 (Pass 1–3)

1. `deposit` — most active: salary, rent, food, UPI, card bills, reimbursements, transfers, groceries, healthcare, shopping, travel, cash withdrawal
2. `mutual_funds` — SIP dates, redemptions, switches, dividends, valuation updates
3. `recurring_deposit` — monthly instalment, missed instalment, interest accrual, maturity
4. `term_deposit` — opening, renewal, interest payout, TDS, premature withdrawal
5. `insurance_policies` — premium payments, renewals, claims, maturity/payout events

### Phase 2 (Pass 4)

6. `equities` — buy/sell trades, dividends, charges, speculative spikes
7. `nps` — monthly/quarterly contribution, employer contribution, annual top-up
8. `gstr1_3b` — invoices, GST liability, tax filing, input tax credit, GST payment

Not every account type needs daily transactions. The generator runs day by day, but each account type only appends events when something actually happens.

## Personas

### Core Personas (Phase 1)

1. **Aarav** — 27, software developer, Bangalore, single, high UPI frequency, struggles with daily expense control
2. **Priya** — 35, product manager, stable high salary, household/family responsibilities, goal-oriented

### Extended Personas (Phase 2)

- Freelancer with irregular income
- Self-employed business owner
- Debt-burdened user
- Subscription drifter
- Cash withdrawal blind spot user

See `PERSONA_BEHAVIOR_SPEC.md` for full details.

## Dataset Variants

| # | Dataset ID | Persona | Focus |
|---|-----------|---------|-------|
| 1 | aarav_spend_control_normal | Aarav | Baseline daily expense pattern |
| 2 | aarav_job_switch | Aarav | Salary gap + new employer |
| 3 | aarav_lifestyle_creep | Aarav | Gradual spending inflation |
| 4 | aarav_wedding_travel_spike | Aarav | Social event spending burst |
| 5 | priya_goal_planner_normal | Priya | Baseline goal-oriented pattern |
| 6 | priya_healthcare_shock | Priya | Medical emergency impact |
| 7 | priya_family_provider | Priya | High family obligation load |
| 8 | priya_bonus_goal_acceleration | Priya | Bonus accelerates goals |
| 9 | priya_travel_goal_drift | Priya | Travel causes goal drift |
| 10 | priya_investor_heavy_low_liquidity | Priya | Heavy investments, low liquid cash |

## Output Structure

Per dataset:

```
/data/synthetic/output/{dataset_id}/
├── raw_payload.json              ← AA-style payload (parseable by setu-fi-parser.ts)
├── ground_truth.json             ← Hidden labels for every transaction
├── accounts.csv                  ← Account summary
├── transactions.csv              ← Flat transaction list
├── monthly_cashflow.csv          ← Month-by-month income/expense/net
├── mode_spending_summary.csv     ← Spend by mode (UPI, CARD, CASH, etc.)
├── income_candidates_expected.json
├── recurring_candidates_expected.json
└── validation_report.json
```

## Implementation Language

TypeScript (Deno), matching the existing backend.

## Deterministic Seeds

Each dataset uses a deterministic seed for reproducibility:

- `mone-aarav-normal-v1`
- `mone-aarav-job-switch-v1`
- `mone-aarav-lifestyle-creep-v1`
- `mone-aarav-wedding-v1`
- `mone-priya-normal-v1`
- `mone-priya-healthcare-v1`
- `mone-priya-family-v1`
- `mone-priya-bonus-v1`
- `mone-priya-travel-v1`
- `mone-priya-investor-v1`

## Implementation Passes

### Pass 1 (Current)
1. Documentation (this spec + 6 supporting docs)
2. Folder structure
3. Base schema/types
4. Deterministic random utility
5. Aarav normal config
6. Deposit account only for Aarav normal
7. Day-by-day deposit transactions for 12 months
8. Ground truth
9. Raw AA-style payload export
10. Canonical CSV export
11. Validation report

### Pass 2
1. Priya normal
2. Goals
3. Safe-to-spend expected values
4. Goal drift expected values

### Pass 3
1. Mutual funds
2. Recurring deposits
3. Term deposits
4. Insurance policies

### Pass 4
1. Life-event variants
2. Equities / NPS / GSTR

## Related Documents

- [PERSONA_BEHAVIOR_SPEC.md](./PERSONA_BEHAVIOR_SPEC.md) — Detailed persona profiles and behavior
- [EVENT_TAXONOMY.md](./EVENT_TAXONOMY.md) — Complete event classification
- [AA_PAYLOAD_GENERATION_SPEC.md](./AA_PAYLOAD_GENERATION_SPEC.md) — AA payload structure and generation
- [GROUND_TRUTH_SPEC.md](./GROUND_TRUTH_SPEC.md) — Ground truth labeling system
- [VALIDATION_SPEC.md](./VALIDATION_SPEC.md) — Validation checks and reporting
- [EXECUTION_PLAN.md](./EXECUTION_PLAN.md) — Step-by-step implementation plan
