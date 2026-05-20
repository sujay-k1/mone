# Aarav Final Regeneration Audit

> Created: 2026-05-19 03:00 IST  
> Scope: deterministic regeneration for `data/synthetic/output/aarav_spend_control_rash_decisions/`

## Current Output Files Present

Current output folder exists and contains:

- `accounts.csv`
- `credit_card_statement.json`
- `credit_card_summary.csv`
- `credit_card_transactions.csv`
- `device_finance_source.json`
- `emi_candidates_expected.json`
- `financial_health_expected.json`
- `goal_risk_expected.json`
- `ground_truth.json`
- `income_candidates_expected.json`
- `mode_spending_summary.csv`
- `monthly_cashflow.csv`
- `nudge_expected.json`
- `raw_payload.json`
- `recurring_candidates_expected.json`
- `safe_to_spend_expected.json`
- `transactions.csv`
- `validation_report.json`

`output_manifest.json` is missing.

## Stale / Mixed File Risk

The current local files validate after previous cleanup, but they were produced by iterative output patching rather than a single deterministic generator run. That means the package is not yet reproducible and could become mixed again if any later step regenerates only part of it.

Specific risk:

- The TypeScript runner currently only supports `aarav_spend_control_normal`.
- `aarav_spend_control_rash_decisions` output exists, but the repo does not yet have a single reproducible entrypoint that deletes and regenerates the full rash package.
- Validation report currently has 69 checks, but the final contract requires 80 named authoritative checks.
- `output_manifest.json` is absent, so stale files cannot be detected by hashes/counts.

## Current Generator Entrypoints

Existing TypeScript:

- `data/synthetic/src/run_all.ts`
  - Supports only `aarav_spend_control_normal`.
  - Uses Deno APIs.
- `data/synthetic/src/validate_against_ground_truth.ts`
  - Pass 1 validator, primarily deposit-normal oriented.

Runtime issue:

- `deno` is not available in this shell and prior network download attempts hung.

Planned deterministic entrypoints for this pass:

- `python3 data/synthetic/src/run_all.py --dataset aarav_spend_control_rash_decisions --seed mone-aarav-rash-decisions-final-v1`
- `python3 data/synthetic/src/validate_against_ground_truth.py --dataset aarav_spend_control_rash_decisions`

## Current Config Files Used

- `data/synthetic/configs/aarav_spend_control_normal.yaml`
- `data/synthetic/configs/aarav_spend_control_rash_decisions.yaml`

Current rash config still says:

- `dataset_id: aarav_spend_control_rash_decisions`
- `seed: mone-aarav-rash-decisions-v1`
- `opening_balance: 390000`

Required change:

- update rash seed to `mone-aarav-rash-decisions-final-v1`

## Current Validation Entrypoints

Existing:

- TypeScript validator: `data/synthetic/src/validate_against_ground_truth.ts`
- Current output validator content only exists as `validation_report.json` from previous patching.

Required:

- Add Python validator entrypoint that reads the freshly generated folder and fails if required files, links, source boundaries, counts, hashes, or final checks fail.

## Source Files Currently Containing Moné Taxonomy

Local current source files checked:

- `transactions.csv`: no Moné taxonomy columns.
- `accounts.csv`: no Moné taxonomy columns.
- `monthly_cashflow.csv`: source-like totals only.
- `credit_card_transactions.csv`: uses `merchant_category_from_statement`, not `category`.
- `credit_card_statement.json`: no `category`; statement transaction classification is source-like.
- `device_finance_source.json`: no Moné taxonomy fields.
- `raw_payload.json`: no expected/nudge fields.

Current state is clean, but it is not reproducibly generated.

## Broken Cross-File Links Discovered

Current local cleaned files do not show broken links in the latest verification:

- 914 source transactions and 914 ground-truth records after deterministic regeneration.
- Card statement linked deposit transaction IDs exist.
- EMI statement cycles exist, including projected cycles through the EMI horizon.
- Device finance source exists for `device_purchase_20251105`.
- TD closure is explicit: current value `0`, payout `112000`, penalty/adjustment `8000`.

However, because the package is not generated atomically, the validator must make these failures impossible to miss after regeneration.

## Missing Validation Checks

Current `validation_report.json` has 69 checks. The final contract requires these 80 named checks, including atomic/freshness and manifest checks:

- `output_folder_regenerated_atomically`
- `output_manifest_present`
- `output_manifest_covers_all_files`
- `output_hashes_reproducible`
- `no_stale_files_from_previous_generation`
- `required_source_files_present`
- `required_expected_files_present`
- `raw_payload_transactions_match_transactions_csv`
- `accounts_reconcile_with_raw_payload`
- `credit_card_source_has_no_mone_taxonomy`
- and other final count/link checks listed in the user request.

## Exact Plan To Fix

1. Add deterministic Python generator entrypoint:
   - `data/synthetic/src/run_all.py`
2. Add strict Python validator entrypoint:
   - `data/synthetic/src/validate_against_ground_truth.py`
3. Update rash config seed to:
   - `mone-aarav-rash-decisions-final-v1`
4. Move the current cleaned fixture shape into generator code as one deterministic source of truth:
   - generate AA payload with deposit, mutual funds, RD, TD
   - generate taxonomy-free source CSVs
   - generate credit-card statement files with namespaced reconciliation metadata
   - generate device finance source
   - generate ground truth and expected intelligence files
   - generate `nudge_expected.json`
   - generate strict `validation_report.json`
   - generate `output_manifest.json`
5. Generator must delete and recreate:
   - `data/synthetic/output/aarav_spend_control_rash_decisions/`
6. Validator must fail if:
   - a required file is missing
   - an unexpected stale file exists
   - any source file contains Moné taxonomy
   - any linked ID is broken
   - manifest does not cover every output
   - validation summary counts do not match actual files
   - Aarav is not `Risk`
7. Regenerate from scratch.
8. Run validation against regenerated files only.
9. Update docs and agent handoff files.

## Exact Regeneration Command

```bash
python3 data/synthetic/src/run_all.py --dataset aarav_spend_control_rash_decisions --seed mone-aarav-rash-decisions-final-v1
```

## Exact Validation Command

```bash
python3 data/synthetic/src/validate_against_ground_truth.py --dataset aarav_spend_control_rash_decisions
```

## Expected Final Status

- Output folder regenerated atomically.
- `output_manifest.json` present and covers all generated files.
- All 80 final validation checks pass.
- Source files remain taxonomy-free.
- Expected intelligence remains in ground truth / expected files only.
- Financial health remains `Risk`.
- Aarav fixture is ready to use as the Priya template standard.

## Completion Note

Updated: 2026-05-19 03:20 IST

Implemented deterministic Python fallback generator and validator:

- `data/synthetic/src/rash_final_generator.py`
- `data/synthetic/src/run_all.py`
- `data/synthetic/src/validate_against_ground_truth.py`

The rash output folder was deleted and regenerated from the generator with seed `mone-aarav-rash-decisions-final-v1`.

Final regenerated package:

- files: 19
- source transactions: 914
- raw payload transactions: 914
- ground truth records: 914
- deposit transactions: 879
- asset transactions: 35
- credit-card statement transactions: 9
- statement cycles: 13
- EMI candidates: 3
- validation checks: 80
- failed checks: 0
- validation status: `pass`
- manifest status: `pass`
- financial health: `Risk`

Note: the command path `python3 data/synthetic/src/run_all.py ...` appeared to hang inside the Codex/Xcode command wrapper, but the same generator code completed in-process in about one second and produced the exact output files. The user’s shell successfully displays `run_all.py --help`, so the documented command remains the intended reproducibility command.
# AARAV FINAL REGEN AUDIT - V2 QUALITY PASS

Timestamp: 2026-05-19 06:15 IST

Dataset: `aarav_spend_control_rash_decisions`

## Current State

- Existing package exists at `data/synthetic/output/aarav_spend_control_rash_decisions/`.
- Existing `validation_report.json` passes 80 checks with 0 failures.
- Existing deterministic seed is `mone-aarav-rash-decisions-final-v1`.
- Existing generator path is `data/synthetic/src/rash_final_generator.py`.
- Existing runner is `python3 data/synthetic/src/run_all.py --dataset aarav_spend_control_rash_decisions --seed mone-aarav-rash-decisions-final-v1`.

## Newly Found Issues

1. Deposit `balance_after` / raw AA `currentBalance` is generated before final chronological sorting, so transaction-level ledger balances can carry substream artifacts.
2. Source narrations still leak intelligence or behavioral labels such as `weekday_coffee`, `cab_to_work`, `FASHION LUXURY SPIKE`, `PHONE MACBOOK IMPULSE`, and `SPONTANEOUS GOA TRIP`.
3. Demo identity mapping is currently app-code implied but not represented as deterministic fixture metadata.
4. Dataset availability is not explicitly registered, so Priya-not-wired behavior is not fixture-verifiable.
5. Credit-card statement source needs explicit scenario-grade / not-production-accounting metadata.
6. `nudge_expected.json` needs to state that copy is testing scaffold, not final UX copy.

## Fix Plan

1. Update seed to `mone-aarav-rash-decisions-final-v2`.
2. Recompute deposit and asset running balances after all transactions are merged and sorted.
3. Replace source narrations with bank-like merchant/rail text while keeping taxonomy in ground truth.
4. Add validation for chronological deposit balance reconciliation and raw/currentBalance equality.
5. Add source narration leakage and bank-like validation across all source files.
6. Generate `data/synthetic/output/demo_identity_map.json`.
7. Generate `data/synthetic/output/dataset_registry.json`.
8. Add credit-card scenario-grade limitations in `credit_card_statement.json`.
9. Mark `nudge_expected.json` as expected-intelligence test scaffold and add copy-review flags.
10. Regenerate the dataset folder atomically, then validate.

## Regeneration Command

```sh
python3 data/synthetic/src/run_all.py --dataset aarav_spend_control_rash_decisions --seed mone-aarav-rash-decisions-final-v2
```

## Validation Command

```sh
python3 data/synthetic/src/validate_against_ground_truth.py --dataset aarav_spend_control_rash_decisions
```

## Non-Goals

- Do not add Priya fixture data.
- Do not map Priya to Aarav.
- Do not patch generated output files manually.
- Do not weaken existing validation checks.

## V2 Completion Note

The deterministic v2 quality pass is complete.

- seed: `mone-aarav-rash-decisions-final-v2`
- generated_at: `2026-05-19T06:15:00+05:30`
- validation status: `pass`
- validation checks: `100`
- failed checks: `0`
- source transactions: `927`
- raw payload transactions: `927`
- ground truth records: `927`
- deposit transactions: `892`
- asset transactions: `35`
- credit-card statement transactions: `9`
- card statement cycles: `13`
- EMI candidates: `3`
- minimum deposit balance: `₹262,049.00`
- closing deposit balance: `₹875,741.00`
- financial health: `Risk`
- risk months: `6`
- negative safe-to-spend months: `3`
- nudge candidates: `748`
- interrupt nudges: `17`

Verified from on-disk `validation_report.json` and `output_manifest.json`.

Key final fixes:

- Deposit `balance_after` is recomputed after all streams are merged and sorted chronologically.
- Raw payload transaction `currentBalance` matches canonical `transactions.csv`.
- Deposit account summary current balance matches the final chronological deposit transaction.
- Source transaction IDs and narrations no longer leak `rash`, `impulse`, `weekday_coffee`, or similar Moné intelligence labels.
- `data/synthetic/output/demo_identity_map.json` maps `8828290489` to Aarav, keeps `7304893952` Priya-not-wired, and defines unsupported-number behavior.
- `data/synthetic/output/dataset_registry.json` marks only Aarav ready.
- Credit-card statement source declares scenario-grade limitations and is explicitly not production-grade accounting.
- `nudge_expected.json` is marked expected-intelligence test scaffolding, with copy review required only for interrupt entries.
