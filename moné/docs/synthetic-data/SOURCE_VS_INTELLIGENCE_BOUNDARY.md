# Source vs Intelligence Boundary

Moné synthetic fixtures have two layers.

## Layer 1: Source Data

Source data is what Moné would receive, parse, or import.

Examples:
- `raw_payload.json`
- `accounts.csv`
- `transactions.csv`
- `monthly_cashflow.csv`
- `mode_spending_summary.csv`
- `credit_card_statement.json`
- `credit_card_transactions.csv`
- `credit_card_summary.csv`
- `device_finance_source.json`

Source data may contain financial facts:
- account profile and summary fields
- balances/current values
- transaction amounts, modes, timestamps, and narrations
- statement cycle dates, due dates, total due, minimum due
- EMI schedules and statement lines
- interest, late fees, penalties, and asset events
- source-to-source reconciliation keys when clearly namespaced, such as `source_reconciliation_linked_deposit_transaction_id`
- source counting policy fields when clearly namespaced, such as `source_reconciliation_counted_as_additional_cashflow`
- JSON-only synthetic helper metadata under `generator_metadata`

Source data must not contain hidden Moné inference fields such as:
- `category`
- `sub_category`
- `is_salary`
- `is_emi`
- `is_rent`
- `is_sip`
- `is_discretionary`
- `is_obligation`
- `nudge_candidate`
- `should_interrupt`
- `expected_nudge_type`
- `expected_user_confirmation`
- `expected_safe_to_spend_impact`
- `expected_goal_drift_days`
- `financial_health_impact`
- `nudge_priority`
- `surface_mode`

Source narrations must also avoid leaking Moné intelligence. They should look like bank, payment-rail, issuer, or statement facts, for example `UPI/DE/THIRD WAVE COFFEE/BANGALORE` or `CARD/DE/APPLE STORE INDIA`. They must not contain behavioral labels such as `impulse`, `rash`, `weekday_coffee`, `cab_to_work`, `spontaneous_trip`, `liquidity_rescue`, or `emergency_fund_breach`.

## Layer 2: Expected Intelligence

Expected intelligence is hidden truth used for validation and future parser tests.

Examples:
- `ground_truth.json`
- `income_candidates_expected.json`
- `recurring_candidates_expected.json`
- `emi_candidates_expected.json`
- `safe_to_spend_expected.json`
- `goal_risk_expected.json`
- `financial_health_expected.json`
- `nudge_expected.json`
- `validation_report.json`

Expected intelligence may contain:
- hidden categories
- goal drift
- financial health impact
- expected nudges
- interruption priority
- expected user-facing copy
- confidence labels
- links between source transactions and expected conclusions

## Consumer Rules

The app/parser should consume source data. It should not depend on expected files for runtime behavior.

Validation consumes both layers:
- source files prove structure and financial reconciliation
- expected files prove that Moné’s intended inference targets are represented

## Boundary Rule

When a field describes what happened financially, it belongs in source data.

When a field describes what Moné should infer, how Moné should nudge, or why an event matters, it belongs in ground truth or expected output files.

For CSV source files, any synthetic reconciliation field must be prefixed with `source_reconciliation_`. For JSON source files, synthetic-only helper fields must live under `generator_metadata`.

Demo identity is a separate layer from raw AA holder profile. Runtime demo login should read `data/synthetic/output/demo_identity_map.json`, where `8828290489` maps to Aarav and `7304893952` is explicitly marked Priya-not-wired. The app must not show raw holder names such as synthetic AA holder placeholders as authenticated user identity.
## Priya Boundary Note

Priya's fixture follows the same boundary as Aarav. The Account Aggregator-like source bundle contains realistic statement/source fields only. Family support, education-loan semantics, healthcare burden, local UPI ambiguity, goal pressure, safe-to-spend, net worth status, and nudges live only in `ground_truth.json` and `*_expected.json`.

`merchant_category_from_statement` is allowed only in credit-card statement source files as issuer/card-network style metadata. It is not Moné's inferred taxonomy.

Priya v2 avoids over-labeled source narrations such as `PARENTS SUPPORT`, `SIBLING SUPPORT`, `CARD BUFFER`, and `APPLIANCE BUFFER`. Ground truth retains those responsibility labels.
