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

### Generate all datasets
```bash
deno run --allow-read --allow-write data/synthetic/src/run_all.ts --all
```

### Validate single dataset
```bash
deno run --allow-read --allow-write data/synthetic/src/validate_against_ground_truth.ts --dataset aarav_spend_control_normal
```

### Validate all datasets
```bash
deno run --allow-read --allow-write data/synthetic/src/validate_against_ground_truth.ts --all
```
