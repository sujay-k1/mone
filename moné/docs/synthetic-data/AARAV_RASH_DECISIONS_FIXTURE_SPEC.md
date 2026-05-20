# Aarav Rash Decisions Fixture Specification

Dataset: `aarav_spend_control_rash_decisions`

Purpose: strongest Aarav spend-control demo fixture.

## Required Story

Aarav earns well but is financially unhealthy:
- high salary rhythm
- heavy UPI food/cab/coffee leakage
- extreme gadget and luxury spending
- spontaneous trip
- irregular SIP discipline
- mutual-fund redemption
- recurring-deposit break
- term-deposit premature withdrawal
- credit-card stress
- card EMI and another EMI commitment
- goal drift
- negative safe-to-spend in some months despite positive bank balance
- overall financial health: Risk

## FI and Source Files

AA-style FI payload:
- deposit
- mutual_funds
- recurring_deposit
- term_deposit

Additional source files:
- credit_card_statement.json
- credit_card_transactions.csv
- credit_card_summary.csv
- device_finance_source.json

Expected outputs:
- ground_truth.json
- nudge_expected.json
- income_candidates_expected.json
- recurring_candidates_expected.json
- emi_candidates_expected.json
- safe_to_spend_expected.json
- goal_risk_expected.json
- financial_health_expected.json
- validation_report.json

## Validation Standard

The fixture must pass all baseline checks plus final-polish checks:
- source/intelligence boundary checks
- credit-card statement reconciliation
- EMI schedule reconciliation
- safe-to-spend exclusion of liquidity rescue from income
- recurring taxonomy semantics
- nudge semantics and interrupt quality
- source files free of Moné taxonomy
- namespaced source reconciliation metadata
- device EMI source purchase existence
- term-deposit premature closure semantics

The fixture must stay risky. Validation should not be satisfied by making Aarav healthy.

## Final Cleanup State

Current deterministic regenerated shape:

- seed: `mone-aarav-rash-decisions-final-v4`
- total transactions: 1475
- deposit transactions: 1440
- asset transactions: 35
- credit-card statement transactions: 9
- statement cycles: 13, including future scheduled EMI cycles
- EMI candidates: 3
- validation checks: 137 passing
- manifest: `output_manifest.json`
- financial health: Risk
- interrupt nudges: 17

The source layer no longer exposes Moné taxonomy columns or behavioral source narrations such as `impulse`, `rash`, `weekday_coffee`, or `spontaneous_trip`. Source narrations are bank-like merchant/payment-rail strings. `monthly_cashflow.csv` is source-like and contains only total debits, total credits, net movement, and opening/closing balances. Taxonomy, nudges, health impact, and user-facing copy live in ground truth and expected output files.

The v2 package includes demo metadata inside the dataset folder so the ZIP/package is self-contained:

- `data/synthetic/output/aarav_spend_control_rash_decisions/demo_identity_map.json`
- `data/synthetic/output/aarav_spend_control_rash_decisions/dataset_registry.json`

It also writes shared root-level copies for app/provider convenience:

- `data/synthetic/output/demo_identity_map.json`
- `data/synthetic/output/dataset_registry.json`

The identity map makes the authenticated demo identity explicit:

- `8828290489` maps to Aarav and this dataset.
- `7304893952` maps to Priya with `not_wired_yet`.
- Unsupported numbers return an explicit unsupported demo state.

Raw AA holder profile fields are synthetic/masked source facts and must not be used as user-facing demo identity.

The cash-pressure story is now intentional and validated: Aarav remains solvent, but his minimum deposit balance is `₹29,899.00` and closing balance is `₹186,300.00`, while safe-to-spend is negative in 4 months and financial health remains `Risk`.

Paid card EMI schedule rows are explicit scenario-grade statement-only paid rows. They use `payment_source: statement_only_paid`, `cashflow_link_status: not_linked_scenario_grade`, and a reason field instead of leaving blank cash links unexplained.

The v4 package adds rich local micro-UPI noise for Aarav:

- 25-55 local micro-UPI transactions per month.
- Messy local merchants, QR aggregators, person-name payees, and truncated names.
- Ground truth carries clean categories and confidence; source narrations remain bank-like and taxonomy-free.
- Micro-UPI nudges are broad but interrupts are limited and contextual.

The package also includes `net_worth_expected.json`. Final expected net worth is `₹108,600.00`, liquid net worth is `-₹61,400.00`, and net-worth status remains `risk`.
