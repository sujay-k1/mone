# Ground Truth Specification — Moné Synthetic Data

## Purpose

Every generated transaction must carry hidden ground truth labels. These labels enable Moné's detection algorithms to be validated — if Moné's parser detects a transaction as "salary," the ground truth confirms or denies it.

Ground truth is never shown to the user or exposed in the AA payload. It is stored in a separate `ground_truth.json` file per dataset.

## Ground Truth Record Structure

```json
{
  "transaction_id": "txn_aarav_2026_03_15_004",
  "persona_id": "aarav",
  "account_type": "deposit",
  "ground_truth": {
    "category": "food_delivery",
    "sub_category": "dinner",
    "is_income": false,
    "is_obligation": false,
    "is_discretionary": true,
    "is_recurring": false,
    "is_reimbursable": false,
    "is_unplanned": false,
    "affects_goal": true,
    "nudge_candidate": true,
    "merchant": "Swiggy",
    "life_event": "work_crunch",
    "behavioral_state": "stressed",
    "confidence_expected": "high"
  }
}
```

## Complete Ground Truth Fields

### Identity Fields
| Field | Type | Description |
|-------|------|-------------|
| transaction_id | string | Unique ID matching AA payload txnId |
| persona_id | string | Persona identifier |
| account_type | string | FI type (deposit, mutual_funds, etc.) |
| dataset_id | string | Dataset variant identifier |

### Classification Fields
| Field | Type | Description |
|-------|------|-------------|
| category | string | Primary category from event taxonomy |
| sub_category | string | Subcategory (e.g., "dinner" under "food_delivery") |
| merchant | string | Merchant/payee name |
| is_income | boolean | True if this is an income event |
| is_salary | boolean | True if specifically salary |
| is_variable_income | boolean | True if freelance/bonus/irregular income |
| is_internal_transfer | boolean | True if between own accounts |
| is_refund | boolean | True if refund/cancellation credit |

### Obligation Fields
| Field | Type | Description |
|-------|------|-------------|
| is_obligation | boolean | True if this is a committed/recurring obligation |
| is_rent | boolean | True if rent payment |
| is_emi | boolean | True if EMI (any type) |
| is_sip | boolean | True if SIP investment |
| is_rd | boolean | True if recurring deposit |
| is_insurance | boolean | True if insurance premium |
| is_subscription | boolean | True if subscription payment |
| is_utility | boolean | True if utility bill |
| is_family_support | boolean | True if family support transfer |
| is_tax | boolean | True if tax payment |

### Spending Classification
| Field | Type | Description |
|-------|------|-------------|
| is_discretionary | boolean | True if optional/lifestyle spend |
| is_recurring | boolean | True if happens regularly |
| is_reimbursable | boolean | True if work expense, later reimbursed |
| is_unplanned | boolean | True if not in regular pattern |
| is_healthcare | boolean | True if medical/health spend |
| is_luxury | boolean | True if luxury/premium spend |
| is_travel | boolean | True if travel-related |
| is_gift | boolean | True if gift spending |
| is_cash_blindspot | boolean | True if ATM withdrawal (unknown usage) |
| is_credit_card_payment | boolean | True if CC bill payment |

### Goal Impact Fields
| Field | Type | Description |
|-------|------|-------------|
| affects_goal | boolean | True if impacts any financial goal |
| is_goal_allocation | boolean | True if direct goal contribution |
| linked_goal_id | string? | Goal ID if applicable |
| expected_goal_drift_days | number? | Expected days of goal delay |
| expected_safe_to_spend_impact | number? | Impact on safe-to-spend (negative = reduces) |

### Nudge Fields
| Field | Type | Description |
|-------|------|-------------|
| nudge_candidate | boolean | True if should trigger a nudge |
| expected_nudge_type | string? | Type of nudge expected |
| expected_user_confirmation | string? | What Moné should ask the user |

### Context Fields
| Field | Type | Description |
|-------|------|-------------|
| life_event | string? | Active life event (e.g., "work_travel", "wedding") |
| behavioral_state | string? | Active behavioral state (e.g., "stressed", "social") |
| day_of_week | string | Day name |
| time_of_day | string | Time category: morning/afternoon/evening/night/late_night |
| salary_cycle_phase | string | week_1/week_2/week_3/week_4 |
| confidence_expected | string | high/medium/low — how confident Moné should be in detection |

### Rash-Decisions Extension Fields

`aarav_spend_control_rash_decisions` adds optional fields for risky behavior and intervention validation:

| Field | Type | Description |
|-------|------|-------------|
| is_extreme_purchase | boolean | True for large gadget/luxury purchases |
| is_investment_redemption | boolean | True for MF redemption proceeds/events |
| is_liquidity_rescue | boolean | True when an asset is liquidated to rescue cashflow |
| is_premature_withdrawal | boolean | True for RD/TD premature closure |
| is_goal_protective | boolean | True for goal-protective transfers/assets |
| is_credit_card_interest | boolean | True for card interest debit |
| is_late_fee | boolean | True for card late fee debit |
| is_term_deposit | boolean | True for TD events |
| sip_status | string? | scheduled/paid/skipped/failed/delayed/reduced |
| credit_card_payment_status | string? | full/partial/missed/late |
| linked_asset_account_id | string? | Asset FI account linked to a cash transaction |
| linked_cashflow_transaction_id | string? | Deposit transaction linked to an asset event |
| financial_health_impact | string? | Expected health dimension impact |
| nudge_priority | string | low/medium/high |
| surface_mode | string | interrupt/dashboard_insight/weekly_summary/silent_signal |
| should_interrupt | boolean | True only for high-severity interventions |

### Reimbursement Linking
| Field | Type | Description |
|-------|------|-------------|
| reimbursement_linked_txn_ids | string[]? | For reimbursement credits: IDs of original spend transactions |
| is_reimbursement_credit | boolean | True if this is the reimbursement inflow |

## Ground Truth File Structure

```json
{
  "dataset_id": "aarav_spend_control_normal",
  "persona_id": "aarav",
  "generated_at": "2026-05-18T00:00:00+05:30",
  "period": {
    "start": "2025-06-01",
    "end": "2026-05-31"
  },
  "summary": {
    "total_transactions": 2847,
    "income_events": 24,
    "salary_events": 12,
    "obligation_events": 180,
    "discretionary_events": 1840,
    "recurring_events": 420,
    "unplanned_events": 45,
    "nudge_candidates": 380,
    "reimbursable_events": 8,
    "cash_blindspots": 15,
    "goal_impacting_events": 620
  },
  "transactions": [
    {
      "transaction_id": "txn_aarav_20250628_001",
      "persona_id": "aarav",
      "account_type": "deposit",
      "dataset_id": "aarav_spend_control_normal",
      "ground_truth": { ... }
    }
  ]
}
```

## Validation Rules for Ground Truth

1. Every transaction in raw_payload.json must have exactly one entry in ground_truth.json
2. transaction_id must match between payload and ground truth
3. is_income and is_obligation cannot both be true (income is not an obligation)
4. is_salary implies is_income
5. is_emi, is_sip, is_rd, is_insurance, is_subscription, is_utility each imply is_obligation
6. is_internal_transfer should not count as income or spending
7. is_refund should not count as income
8. is_tax should not count as discretionary
9. is_reimbursable should not count as lifestyle spending
10. is_cash_blindspot should flag uncertain spending
11. investment transactions should not be lifestyle spending
12. reimbursement_linked_txn_ids must reference existing transaction IDs
13. expected_goal_drift_days should be non-negative when present
14. expected_safe_to_spend_impact should be negative for debits

## Expected Nudge Types

| Nudge Type | Trigger |
|-----------|---------|
| spend_velocity_high | Discretionary spending pace above normal |
| weekend_spike | Weekend spending significantly above weekday average |
| food_leakage | Food delivery total exceeds threshold |
| cab_leakage | Cab spending above transit alternative |
| subscription_unused | Subscription with no usage signal |
| goal_drift_warning | Spending pattern will delay goal |
| credit_card_minimum | Paying minimum instead of full |
| cash_blindspot | Significant ATM withdrawal |
| reimbursable_detected | Possible work expense |
| large_unplanned | Unplanned large purchase |
| salary_delay | Salary not received on expected date |
| obligation_upcoming | Large obligation due soon |
| goal_opportunity | Surplus available for goal acceleration |

## Final Aarav Polish Fields

For `aarav_spend_control_rash_decisions`, hidden ground truth and expected outputs may include credit-card, EMI, and nudge-surface fields. These fields must not be written into `raw_payload.json`, `accounts.csv`, or source-only `transactions.csv`.

Credit-card and EMI fields:

- `is_emi`
- `is_card_emi`
- `is_bnpl`
- `is_personal_loan_emi`
- `is_device_emi`
- `emi_id`
- `emi_installment_number`
- `emi_total_installments`
- `emi_payment_status`
- `linked_original_purchase_txn_id`
- `linked_card_statement_id`
- `linked_deposit_payment_txn_id`

Nudge semantics:

- `nudge_candidate` means a transaction or signal is eligible for intelligence.
- `surface_mode` is one of `silent_signal`, `weekly_summary`, `dashboard_insight`, or `interrupt`.
- `should_interrupt` is reserved for high-severity, context-sensitive events such as card stress, SIP failure, liquidity rescue, EMI creation from a rash purchase, or severe safe-to-spend risk.
- Micro-spends such as coffee, lunch, and commute leakage should normally remain `weekly_summary`, `dashboard_insight`, or `silent_signal`.
