# Credit Card and EMI Specification

## Modeling Choice

For `aarav_spend_control_rash_decisions`, credit-card behavior is modeled with separate source files rather than a speculative AA `credit_card` FI type.

Source files:
- `credit_card_statement.json`
- `credit_card_transactions.csv`
- `credit_card_summary.csv`

The final Aarav fixture uses a hybrid compatibility convention because the inherited deposit generator already emits CARD-mode purchase rows:

- Deposit account transactions remain the canonical bank-cashflow stream for this fixture, including legacy CARD-mode purchase rows.
- Credit-card statement transactions provide statement-cycle detail and are linked back to deposit CARD-mode purchase rows with namespaced reconciliation metadata.
- In `credit_card_transactions.csv`, the link uses `source_reconciliation_linked_deposit_transaction_id`.
- In `credit_card_statement.json`, the link lives under `generator_metadata.source_reconciliation_linked_deposit_transaction_id`.
- Credit-card statement purchase rows must have `source_reconciliation_counted_as_additional_cashflow = false`.
- Deposit account transactions also include generated card bill, interest, and late-fee payment rows where applicable.

This convention prevents double-counting because a card purchase may appear in both source files only when the statement row is linked to the deposit source row and explicitly marked as not additional cashflow. A future generator can move fully to statement-only card purchases, but this pass keeps the existing Aarav behavior stable.

The credit-card statement source is scenario-grade, not production-grade issuer accounting. The generated `credit_card_statement.json` root marks:

- `accounting_precision: "scenario_grade"`
- `not_for_production_accounting_rules: true`
- `modeling_limitations`

Production credit-card logic must be validated later against real AA/card-statement formats. This fixture is intended to test Moné’s interpretation of card stress, utilization risk, late fees, interest, payment status, and EMI pressure.

Paid card EMI schedule rows use an explicit scenario-grade convention when no separate bank debit is modeled for the installment:

- `payment_source: "statement_only_paid"`
- `linked_deposit_transaction_id: null`
- `cashflow_link_status: "not_linked_scenario_grade"`
- `cashflow_link_reason`

Blank paid EMI cash links without one of these explanations should fail validation.

## Statement Source Fields

Statement cycles include:
- statement cycle id
- cycle start and end dates
- due date
- total amount due
- minimum amount due
- previous outstanding
- payments received
- payment status
- interest charged
- late fee
- EMI outstanding
- utilization ratio

Card transaction rows include:
- card transaction id
- purchase date
- posting date
- merchant
- amount
- merchant category from statement, if the statement source provides one
- statement cycle id
- converted-to-EMI flag
- EMI id if applicable
- namespaced source reconciliation metadata when the legacy deposit stream already contains the CARD-mode purchase

Statement cycles also include over-limit explanation fields when utilization exceeds 100%:
- `is_over_limit`
- `over_limit_amount`
- `over_limit_reason`
- `over_limit_fee`

## EMI Modeling

Required EMI patterns:
- card EMI from a rash gadget purchase
- another EMI/BNPL/personal-loan/device EMI commitment

EMI source fields include:
- `emi_id`
- `source_purchase_transaction_id`
- `merchant` / `lender`
- `original_purchase_amount`
- `principal`
- interest/no-cost flag
- tenure
- installment amount
- installment number
- due date
- payment status
- linked card statement id
- linked deposit transaction id when paid from bank
- remaining principal

Expected EMI candidates live in `emi_candidates_expected.json`.

The Bajaj/device EMI has a source-grounded record in `device_finance_source.json`. That file contains purchase amount, financed amount, tenure, monthly EMI, due dates, linked deposit payment transaction IDs, and source reconciliation metadata only. It must not contain Moné taxonomy or nudge fields.

## Safe-to-Spend Rules

Credit-card limit is not cash.

Card EMI and personal/device EMI reduce safe-to-spend as debt commitments.

Investment redemptions, RD closure proceeds, and TD closure proceeds are liquidity rescue, not income.

## Priya v2 Credit-Card Cycle Convention

Priya's fixture generates statement cycles from `cc_2025_06` through `cc_2026_07`. Every card transaction and card EMI schedule row references one of these cycles, and `credit_card_summary.csv` contains the same cycle set as `credit_card_statement.json`.

Card bill payment rows in `transactions.csv` are deposit cashflow events near the statement due window. Card purchases in the statement remain scenario-grade purchase context and must not be double counted as additional deposit cashflow.
