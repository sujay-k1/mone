# Aarav Final Polish Audit

> Updated: 2026-05-19 01:40 IST  
> Scope: Final polish for `aarav_spend_control_rash_decisions` only.

## Current Baselines

- `aarav_spend_control_normal` remains intact and validates with status `pass`.
- `aarav_spend_control_rash_decisions` currently validates with status `pass`.
- Current rash fixture FI types: `deposit`, `mutual_funds`, `recurring_deposit`, `term_deposit`.
- Current rash fixture is financially unhealthy by design: `financial_health_overall_status = Risk`.

## Current Rash Package Findings

- `raw_payload.json` does not contain expected intelligence fields such as `nudge_candidate`, `should_interrupt`, `expected_nudge_type`, or `financial_health_impact`.
- `ground_truth.json` contains hidden labels and expected intelligence fields, which is correct.
- `transactions.csv` contains category and boolean classification columns. This is retained for backward compatibility as a canonical labeled CSV, but validation must ensure deeper hidden inference fields remain out of source CSVs.
- `accounts.csv` has already been upgraded with `current_value`, `liquidity_class`, and `balance_role`.
- Credit-card behavior exists only as deposit debits and ground-truth labels. It needs first-class statement source files.
- EMI behavior is not yet first-class. It needs source schedule/output and expected candidates.

## Required Final Polish

1. Add source-vs-intelligence boundary documentation.
2. Add credit-card statement source files without double-counting card purchases as deposit cashflow.
3. Add card EMI and another EMI/debt commitment.
4. Add `emi_candidates_expected.json`.
5. Add safe-to-spend aliases for protected commitments, debt commitments, liquidity rescue, and excluded income.
6. Improve recurring taxonomy with normalized fields.
7. Improve nudge semantics with user-facing reason/copy/suppression fields.
8. Add validation checks for source/intelligence separation, card statement behavior, EMI schedule, safe-to-spend semantics, recurring taxonomy, and nudge semantics.

## Runtime Caveat

`deno` is not available in this shell. This polish pass continues the established local Python fallback for output generation. TypeScript/Deno implementation remains the intended long-term generator path.

## Completion Note

Updated: 2026-05-19 02:05 IST

The final polish pass is complete for `aarav_spend_control_rash_decisions`.

- Source/intelligence boundary docs were added.
- `transactions.csv` is now source-only and excludes hidden inference columns.
- `raw_payload.json` has no expected/nudge intelligence fields.
- Credit-card statement source files were added.
- EMI candidates were added for card EMI and device EMI behavior.
- Safe-to-spend expected output includes debt/EMI aliases and liquidity-rescue exclusions.
- Recurring candidates include normalized commitment semantics.
- Nudge candidates keep broad eligibility while interrupts remain limited to high-severity events.
- Opening deposit balance was raised to `₹390,000` so facility `NONE` never goes negative after credit-card/EMI additions.
- Latest validation status is `pass`; minimum deposit balance is `₹12,191.00`; financial health remains `Risk`.

## Final Cleanup Note

Updated: 2026-05-19 02:35 IST

The final Aarav cleanup is complete.

- Source files are now free of Moné taxonomy and user-facing copy.
- Card statement source uses `merchant_category_from_statement`, namespaced `source_reconciliation_*` CSV fields, and JSON `generator_metadata`.
- `device_finance_source.json` provides the original Bajaj/device EMI source purchase.
- `nudge_expected.json` owns user-facing nudge copy and suppression reasons.
- Card statement cycles now include projected/scheduled EMI cycles through the EMI horizon.
- Over-limit card cycles include `is_over_limit`, `over_limit_amount`, `over_limit_reason`, and `over_limit_fee`.
- Term deposit closure is fully closed with zero current value, `₹112,000` payout, and `₹8,000` penalty/adjustment.
- `ground_truth_one_to_one` now reports `1135 tx, 1135 gt`.
- New cleanup validation checks all pass.
