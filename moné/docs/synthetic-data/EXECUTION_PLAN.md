# Execution Plan — Moné Synthetic Data

## Overview

Implementation is divided into 4 passes. Each pass builds on the previous one. Do not skip passes.

## Pass 1 — Foundation + Aarav Deposit (Current)

### Step 1.1: Documentation
- [x] SYNTHETIC_DATA_MASTER_SPEC.md
- [x] PERSONA_BEHAVIOR_SPEC.md
- [x] EVENT_TAXONOMY.md
- [x] AA_PAYLOAD_GENERATION_SPEC.md
- [x] GROUND_TRUTH_SPEC.md
- [x] VALIDATION_SPEC.md
- [x] EXECUTION_PLAN.md (this file)

### Step 1.2: Folder Structure
```
data/synthetic/
├── configs/
│   └── aarav_spend_control_normal.yaml
├── src/
│   ├── types.ts
│   ├── random.ts
│   ├── generate_persona_profile.ts
│   ├── generate_accounts.ts
│   ├── generate_calendar.ts
│   ├── generate_recurring_events.ts
│   ├── generate_daily_transactions.ts
│   ├── generate_life_events.ts
│   ├── generate_investments.ts
│   ├── generate_insurance.ts
│   ├── generate_gstr.ts
│   ├── build_aa_payload.ts
│   ├── build_ground_truth.ts
│   ├── export_canonical_csvs.ts
│   ├── validate_against_ground_truth.ts
│   └── run_all.ts
└── output/
    └── {dataset_id}/
        ├── raw_payload.json
        ├── ground_truth.json
        ├── accounts.csv
        ├── transactions.csv
        ├── monthly_cashflow.csv
        ├── mode_spending_summary.csv
        ├── income_candidates_expected.json
        ├── recurring_candidates_expected.json
        └── validation_report.json
```

### Step 1.3: Base Types (types.ts)
- PersonaProfile
- AccountConfig
- CalendarMonth
- RecurringEvent
- DailyTransaction (with ground truth)
- BehavioralState
- LifeEvent
- AAPayload types
- GroundTruthRecord
- ValidationReport

### Step 1.4: Deterministic Random (random.ts)
- Seeded PRNG (seedrandom or equivalent)
- `randomFloat(min, max)` — uniform float
- `randomInt(min, max)` — uniform integer
- `randomChoice(array)` — pick one
- `randomWeighted(options, weights)` — weighted selection
- `randomGaussian(mean, stddev)` — normal distribution for amounts
- `randomTime(hourStart, hourEnd)` — realistic timestamp
- `jitterDays(baseDay, maxJitter)` — date jitter for obligations
- `shouldOccur(probability)` — boolean with probability

### Step 1.5: Aarav Normal Config (YAML)
```yaml
persona:
  id: aarav
  name: Aarav Sharma
  age: 27
  occupation: Software Developer
  city: Bangalore
  
seed: mone-aarav-normal-v1
period:
  start: 2025-06-01
  end: 2026-05-31

accounts:
  deposit:
    bank: HDFC
    type: SAVINGS
    opening_balance: 45000
    
income:
  salary:
    amount: 165000
    day: 28
    employer: TECHCORP INDIA PVT LTD
    
obligations:
  rent: { amount: 42000, day: 5 }
  sip: { amount: 15000, day: 10 }
  broadband: { amount: 999, day: 15 }
  mobile: { amount: 599, day: 18 }
  subscriptions:
    - { name: Netflix, amount: 649, day: 12 }
    - { name: Spotify, amount: 119, day: 14 }
    - { name: iCloud, amount: 75, day: 14 }
    
goals:
  - { id: emergency_fund, target: 300000, current: 180000, monthly: 10000 }
  - { id: vacation_bali, target: 150000, current: 37500, monthly: 8000 }
  - { id: laptop, target: 120000, current: 42000, monthly: 6000 }

life_events: []  # Normal variant has no special life events

behavioral_defaults:
  weekday_food_delivery_prob: 0.6
  weekend_dining_out_prob: 0.7
  friday_social_prob: 0.8
  coffee_daily_prob: 0.7
  cab_vs_metro: 0.4
  impulse_shopping_weekend_prob: 0.3
  late_night_food_prob: 0.15
  atm_withdrawal_monthly: 1-2
```

### Step 1.6: Generate Deposit Transactions
- Build 12-month calendar
- Generate recurring events (salary, rent, SIP, subscriptions, utilities)
- Generate weekly habits (groceries, food, commute, coffee)
- Generate daily transactions based on day-type and behavioral state
- Track running balance
- Assign ground truth to every transaction

### Step 1.7: Build AA Payload
- Wrap transactions in AA structure
- Add profile, summary
- Compute final balance

### Step 1.8: Build Ground Truth
- Collect all ground truth records
- Compute summary statistics

### Step 1.9: Export CSVs
- accounts.csv
- transactions.csv
- monthly_cashflow.csv
- mode_spending_summary.csv
- income_candidates_expected.json
- recurring_candidates_expected.json

### Step 1.10: Validate
- Run all validation checks
- Generate validation_report.json

### Step 1.11: Update Agent Handover
- AGENT_HANDOFF.md
- AGENT_TODO.md
- AGENT_DECISIONS.md
- AGENT_CHANGELOG.md

## Pass 2 — Priya + Goals

## Variant — Aarav Rash Decisions

Status: current requested fixture.

Required outputs:
- `data/synthetic/configs/aarav_spend_control_rash_decisions.yaml`
- `data/synthetic/output/aarav_spend_control_rash_decisions/raw_payload.json`
- `data/synthetic/output/aarav_spend_control_rash_decisions/ground_truth.json`
- `data/synthetic/output/aarav_spend_control_rash_decisions/accounts.csv`
- `data/synthetic/output/aarav_spend_control_rash_decisions/transactions.csv`
- `data/synthetic/output/aarav_spend_control_rash_decisions/monthly_cashflow.csv`
- `data/synthetic/output/aarav_spend_control_rash_decisions/mode_spending_summary.csv`
- `data/synthetic/output/aarav_spend_control_rash_decisions/income_candidates_expected.json`
- `data/synthetic/output/aarav_spend_control_rash_decisions/recurring_candidates_expected.json`
- `data/synthetic/output/aarav_spend_control_rash_decisions/financial_health_expected.json`
- `data/synthetic/output/aarav_spend_control_rash_decisions/safe_to_spend_expected.json`
- `data/synthetic/output/aarav_spend_control_rash_decisions/goal_risk_expected.json`
- `data/synthetic/output/aarav_spend_control_rash_decisions/validation_report.json`

Rules:
- Preserve `aarav_spend_control_normal`.
- Required FI types: `deposit`, `mutual_funds`, `recurring_deposit`, `term_deposit`.
- Do not add Priya, equities, NPS, or GSTR.
- Link cash and asset events for SIP purchases, MF redemptions, RD installments/closure, and TD closure.
- Do not count investments or redemptions as lifestyle spending.
- Do not count redemptions, refunds, or reimbursements as income candidates.
- Overall financial health must be Watch or Risk.
- Safe-to-spend must include at least three Watch/Risk months and at least one negative safe-to-spend month.
- Timestamps must pass `category_time_window_coherence`.
- Asset accounts must use explicit `liquidity_class`, `balance_role`, and `current_value` conventions in `accounts.csv`.
- Asset opening/principal values are represented in summary/CSV fields, not duplicate opening transactions.
- Major rash events must carry `life_event` labels.
- `should_interrupt` must remain high-severity only and between 8 and 20 events annually.

### Step 2.1: Priya Normal Config
- Higher salary, more obligations, more goals
- Family responsibilities
- Different spending pattern (less impulse, more planned)

### Step 2.2: Priya Deposit Transactions
- Same generator, different persona config
- Family-oriented spending
- More predictable, less leakage

### Step 2.3: Safe-to-Spend Expected Values
- For each month, compute expected safe-to-spend
- Store in ground truth

### Step 2.4: Goal Drift Expected Values
- For each month, compute expected goal completion dates
- Track drift from baseline
- Store in ground truth

## Pass 3 — Investment Account Types

### Step 3.1: Mutual Funds Generator
- SIP purchases on scheduled dates
- NAV fluctuation simulation
- Occasional redemption
- Dividend events

### Step 3.2: Recurring Deposit Generator
- Monthly instalment
- Interest accrual
- Missed instalment scenario
- Maturity event

### Step 3.3: Term Deposit Generator
- Opening event
- Interest payout (quarterly/annual)
- TDS deduction
- Renewal or premature closure

### Step 3.4: Insurance Generator
- Premium payments (monthly/annual)
- Renewal notices
- Claim events (for healthcare shock variant)
- Maturity payouts

## Pass 4 — Variants + Extended Types

### Step 4.1: Aarav Variants
- aarav_job_switch: salary gap, F&F, new employer
- aarav_lifestyle_creep: gradually increasing spends
- aarav_wedding_travel_spike: event cluster

### Step 4.2: Priya Variants
- priya_healthcare_shock: medical emergency
- priya_family_provider: high family obligations
- priya_bonus_goal_acceleration: bonus → goal boost
- priya_travel_goal_drift: travel spending
- priya_investor_heavy_low_liquidity: high investment, low cash

### Step 4.3: Extended Account Types
- Equities (buy/sell/dividends)
- NPS (contributions)
- GSTR1/3B (business users)

### Step 4.4: Extended Personas
- Freelancer
- Business owner
- Debt-burdened
- Subscription drifter
- Cash withdrawal blind spot

## Commands

### Generate single dataset
```bash
deno run --allow-read --allow-write data/synthetic/src/run_all.ts --dataset aarav_spend_control_normal
```

### Generate Aarav rash-decisions final fixture
```bash
python3 data/synthetic/src/run_all.py --dataset aarav_spend_control_rash_decisions --seed mone-aarav-rash-decisions-final-v4
```

### Generate all datasets
```bash
deno run --allow-read --allow-write data/synthetic/src/run_all.ts --all
```

### Validate single dataset
```bash
deno run --allow-read --allow-write data/synthetic/src/validate_against_ground_truth.ts --dataset aarav_spend_control_normal
```

### Validate Aarav rash-decisions final fixture
```bash
python3 data/synthetic/src/validate_against_ground_truth.py --dataset aarav_spend_control_rash_decisions
```

### Validate all datasets
```bash
deno run --allow-read --allow-write data/synthetic/src/validate_against_ground_truth.ts --all
```

## Current Polished Aarav Fixture

`aarav_spend_control_rash_decisions` is the final Aarav spend-control demo fixture before Priya work starts.

It contains:

- AA-like source data for `deposit`, `mutual_funds`, `recurring_deposit`, and `term_deposit`.
- Separate credit-card statement source files instead of a speculative AA `credit_card` FI type.
- A device-finance source file for Bajaj/device EMI purchase provenance.
- First-class EMI expected output covering card EMI and device EMI behavior.
- Clean source/intelligence separation: raw payload and canonical source CSVs exclude hidden expected/nudge fields.
- Source files do not contain Moné taxonomy such as category/sub-category, nudge fields, or user-facing copy.
- Nudge copy lives in `nudge_expected.json`.
- Financial health remains `Risk`.
- Deterministic seed is `mone-aarav-rash-decisions-final-v4`.
- Regenerated output includes `output_manifest.json`.
- Final validation has 137 checks passing.
- Current regenerated package has 1475 source transactions, 1440 deposit transactions, 35 asset transactions, 9 card statement transactions, 13 statement cycles, and 3 EMI candidates.
- Deposit facility remains `NONE`; opening cash buffer is `₹360,000`, minimum observed balance is `₹29,899.00`, closing balance is `₹186,300.00`, and no unintentional negative balance is allowed.
- Term deposit premature closure is modeled as fully closed with `₹112,000` payout and `₹8,000` penalty/adjustment.
- Chronological deposit `balance_after` now reconciles transaction-by-transaction after all streams are merged.
- Source narrations are bank-like and do not contain Moné intelligence labels.
- Demo identity and dataset availability are included inside the dataset folder and mirrored at `data/synthetic/output/demo_identity_map.json` and `data/synthetic/output/dataset_registry.json`.
- Paid card EMI schedule rows are explicitly `statement_only_paid` scenario-grade rows when they do not have separate deposit cash links.
- Local micro-UPI noise adds 25-55 messy UPI spends per month with QR, truncated merchant, local shop, adult discretionary, and ambiguous payee patterns.
- `net_worth_expected.json` is generated; final net worth is `₹108,600.00` and liquid net worth is `-₹61,400.00`.

Before extending to Priya, use this fixture as the quality bar for:

- source-vs-intelligence boundary,
- credit-card/payment reconciliation,
- EMI schedule modeling,
- safe-to-spend debt pressure,
- recurring taxonomy semantics,
- limited high-severity interrupt nudges.
## Priya Fixture Execution

Priya's deterministic responsibility-burden fixture is generated from:

```bash
python3 data/synthetic/src/run_all.py --dataset priya_goal_planner_responsibility_burden --seed mone-priya-responsibility-burden-v3
python3 data/synthetic/src/validate_against_ground_truth.py --dataset priya_goal_planner_responsibility_burden
```

The generated package is self-contained at:

```text
data/synthetic/output/priya_goal_planner_responsibility_burden/
```

Priya is now wired in `demo_identity_map.json`:

- `8828290489` -> Aarav -> `aarav_spend_control_rash_decisions`
- `7304893952` -> Priya -> `priya_goal_planner_responsibility_burden`

Runtime app code should ingest only source/app-input files from the package. Expected files remain test oracle artifacts.

Clean ZIP packaging command:

```bash
cd data/synthetic/output
zip -r -X priya_goal_planner_responsibility_burden.zip priya_goal_planner_responsibility_burden
```
