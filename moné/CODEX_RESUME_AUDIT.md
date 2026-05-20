# CODEX Resume Audit — Moné Synthetic Data Pass 1

> Updated: 2026-05-18 23:35 IST  
> Agent: Codex  
> Scope: Resume Claude's unfinished synthetic Account Aggregator data generator work; continue Pass 1 only.

## Ground Truth From Local Inspection

- Working directory: `/Users/sujaykumar/Documents/Assignment/CommerceIQ/moné`
- `.git` directory: not present at project root
- `rg`: not installed in this shell, so inspection used `find`, `ls`, and `sed`
- JavaScript/TypeScript runtimes in shell: `deno`, `node`, `npm`, `npx`, `bun`, and `ts-node` are not currently found on `PATH`

Because no git repository exists, no `git status` or `git diff --stat` command was run.

## What Claude Completed

Claude completed the main SwiftUI app foundation and created the four root handoff files:

- `AGENT_HANDOFF.md`
- `AGENT_TODO.md`
- `AGENT_DECISIONS.md`
- `AGENT_CHANGELOG.md`

For the current synthetic-data task, Claude appears to have started a TypeScript/Deno implementation and created:

- full required synthetic-data documentation files
- `data/synthetic/configs/aarav_spend_control_normal.yaml`
- partial generator modules under `data/synthetic/src`
- empty `data/synthetic/output` directory

The existing TypeScript work includes useful foundations:

- `types.ts`: persona/config, AA payload, transaction, ground truth, validation, CSV row types
- `random.ts`: seeded PRNG and date/time helpers
- `generate_calendar.ts`: 12-month persona calendar and behavioral states
- `generate_daily_transactions.ts`: deposit-only recurring and day-by-day spending generator
- `build_aa_payload.ts`: wraps generated deposit transactions in AA-style payload structure
- `build_ground_truth.ts`: builds ground-truth file and summary
- `export_canonical_csvs.ts`: accounts, transactions, monthly cashflow, mode summary, and expected candidate builders

## Files That Exist

Synthetic docs:

- `docs/synthetic-data/SYNTHETIC_DATA_MASTER_SPEC.md`
- `docs/synthetic-data/PERSONA_BEHAVIOR_SPEC.md`
- `docs/synthetic-data/EVENT_TAXONOMY.md`
- `docs/synthetic-data/AA_PAYLOAD_GENERATION_SPEC.md`
- `docs/synthetic-data/GROUND_TRUTH_SPEC.md`
- `docs/synthetic-data/VALIDATION_SPEC.md`
- `docs/synthetic-data/EXECUTION_PLAN.md`

Synthetic config/source:

- `data/synthetic/configs/aarav_spend_control_normal.yaml`
- `data/synthetic/src/types.ts`
- `data/synthetic/src/random.ts`
- `data/synthetic/src/generate_calendar.ts`
- `data/synthetic/src/generate_daily_transactions.ts`
- `data/synthetic/src/build_aa_payload.ts`
- `data/synthetic/src/build_ground_truth.ts`
- `data/synthetic/src/export_canonical_csvs.ts`

Other relevant files:

- `mone-backend/fixtures/setu/*`
- `mone-backend/scripts/parse-setu-fi-fixture.ts`
- `mone-backend/supabase/migrations/*`
- SwiftUI app files under `Sources/mone`

## Files Missing For Pass 1

Required by the execution plan but not present yet:

- `data/synthetic/src/run_all.ts`
- `data/synthetic/src/validate_against_ground_truth.ts`

Expected by the broader file naming plan but not present yet. These can remain as later-pass placeholders unless needed:

- `data/synthetic/src/generate_persona_profile.ts`
- `data/synthetic/src/generate_accounts.ts`
- `data/synthetic/src/generate_recurring_events.ts`
- `data/synthetic/src/generate_life_events.ts`

Expected output directory and files are missing:

- `data/synthetic/output/aarav_spend_control_normal/raw_payload.json`
- `data/synthetic/output/aarav_spend_control_normal/ground_truth.json`
- `data/synthetic/output/aarav_spend_control_normal/accounts.csv`
- `data/synthetic/output/aarav_spend_control_normal/transactions.csv`
- `data/synthetic/output/aarav_spend_control_normal/monthly_cashflow.csv`
- `data/synthetic/output/aarav_spend_control_normal/mode_spending_summary.csv`
- `data/synthetic/output/aarav_spend_control_normal/income_candidates_expected.json`
- `data/synthetic/output/aarav_spend_control_normal/recurring_candidates_expected.json`
- `data/synthetic/output/aarav_spend_control_normal/validation_report.json`

## What Code Compiles Or Runs

No synthetic-data code has been run in this shell because no JS/TS runtime is currently available on `PATH`.

The root handoff claims the SwiftUI app previously type-checked cleanly, but this audit did not re-run Swift or Xcode validation because the current task is synthetic data Pass 1 and the user explicitly asked to inspect/recover/document first.

## What Is Broken Or Incomplete

- There is no `run_all.ts`, so the generator cannot currently be executed end to end.
- There is no `validate_against_ground_truth.ts`, so no validation report can be produced.
- `random.ts` uses `Math.random()` for timestamp seconds, which breaks full determinism despite the seeded PRNG.
- `build_aa_payload.ts` returns an array of payloads and omits `linkRefNumber` / top-level `maskedAccNumber` on data items, while the requested AA-style shape includes them.
- No generated output files exist yet.
- Existing config has `life_events: []`, which is acceptable for Aarav normal Pass 1, but reimbursement-linked events are not yet implemented.
- The current environment lacks Deno/Node, so local execution may require installing/activating Deno or running in an environment where Deno is available.

## Docs Status

All required synthetic-data documentation files exist and preserve the full product strategy:

- master spec
- persona behavior spec
- event taxonomy
- AA payload generation spec
- ground truth spec
- validation spec
- execution plan

The docs are usable for Pass 1. They are incomplete only in the sense that implementation has not caught up to the documented runner/validator/output requirements.

## Pass 1 Requires

Pass 1 must remain limited to `aarav_spend_control_normal` with deposit account data only:

1. Preserve/update docs and handoff files.
2. Keep TypeScript/Deno implementation direction.
3. Add end-to-end runner.
4. Add validator.
5. Fix deterministic timestamp generation.
6. Produce AA-style deposit payload with required fields.
7. Produce ground truth for every transaction.
8. Produce canonical CSV exports.
9. Produce expected income and recurring candidates.
10. Produce validation report.
11. Update `AGENT_HANDOFF.md`, `AGENT_TODO.md`, `AGENT_DECISIONS.md`, and `AGENT_CHANGELOG.md`.

## Exact Next Steps

1. Patch `random.ts` so timestamp seconds are deterministic.
2. Patch `build_aa_payload.ts` to match the requested Setu-like structure more closely.
3. Add `run_all.ts` with a small dependency-free YAML parser for the existing config shape.
4. Add `validate_against_ground_truth.ts` and call it from the runner.
5. Generate the required output files if a Deno runtime becomes available.
6. If Deno is unavailable, leave exact run commands and note the environment blocker.
7. Update handoff files with final status and commands.

## Commands Used During Audit

```bash
pwd
test -d .git && echo GIT_EXISTS || echo NO_GIT
find . -maxdepth 4 -type f | sort | sed -n '1,300p'
find . -maxdepth 4 -type d | sort | sed -n '1,220p'
sed -n '1,240p' AGENT_HANDOFF.md
sed -n '1,240p' AGENT_TODO.md
sed -n '1,240p' AGENT_DECISIONS.md
sed -n '1,260p' AGENT_CHANGELOG.md
sed -n '1,260p' docs/synthetic-data/SYNTHETIC_DATA_MASTER_SPEC.md
sed -n '1,260p' data/synthetic/src/types.ts
sed -n '1,620p' data/synthetic/src/generate_daily_transactions.ts
sed -n '1,260p' data/synthetic/src/generate_calendar.ts
sed -n '1,260p' data/synthetic/src/random.ts
sed -n '1,260p' data/synthetic/src/build_aa_payload.ts
sed -n '1,260p' data/synthetic/src/build_ground_truth.ts
sed -n '1,320p' data/synthetic/src/export_canonical_csvs.ts
find data/synthetic/output -maxdepth 3 -type f | sort
which deno; which node; which npm; which npx; which bun; which ts-node
```

## Commands To Run After Implementation

Preferred:

```bash
deno run --allow-read --allow-write data/synthetic/src/run_all.ts --dataset aarav_spend_control_normal
deno run --allow-read --allow-write data/synthetic/src/validate_against_ground_truth.ts --dataset aarav_spend_control_normal
```

Expected output:

```text
data/synthetic/output/aarav_spend_control_normal/raw_payload.json
data/synthetic/output/aarav_spend_control_normal/ground_truth.json
data/synthetic/output/aarav_spend_control_normal/accounts.csv
data/synthetic/output/aarav_spend_control_normal/transactions.csv
data/synthetic/output/aarav_spend_control_normal/monthly_cashflow.csv
data/synthetic/output/aarav_spend_control_normal/mode_spending_summary.csv
data/synthetic/output/aarav_spend_control_normal/income_candidates_expected.json
data/synthetic/output/aarav_spend_control_normal/recurring_candidates_expected.json
data/synthetic/output/aarav_spend_control_normal/validation_report.json
```

## Post-Audit Pass 1 Update

After this audit was written, Codex continued Pass 1 and completed the smallest working Aarav normal deposit-only dataset.

Added/updated implementation files:

- `data/synthetic/src/run_all.ts`
- `data/synthetic/src/validate_against_ground_truth.ts`
- `data/synthetic/src/random.ts`
- `data/synthetic/src/types.ts`
- `data/synthetic/src/build_aa_payload.ts`

Generated output files:

- `data/synthetic/output/aarav_spend_control_normal/raw_payload.json`
- `data/synthetic/output/aarav_spend_control_normal/ground_truth.json`
- `data/synthetic/output/aarav_spend_control_normal/accounts.csv`
- `data/synthetic/output/aarav_spend_control_normal/transactions.csv`
- `data/synthetic/output/aarav_spend_control_normal/monthly_cashflow.csv`
- `data/synthetic/output/aarav_spend_control_normal/mode_spending_summary.csv`
- `data/synthetic/output/aarav_spend_control_normal/income_candidates_expected.json`
- `data/synthetic/output/aarav_spend_control_normal/recurring_candidates_expected.json`
- `data/synthetic/output/aarav_spend_control_normal/validation_report.json`

Validation read-back:

- status: `pass`
- total transactions: `1348`
- salary credits: `12`
- rent debits: `12`
- SIP debits: `24`
- subscription debits: `48`
- cash blind spots: `14`
- reimbursement credits: `2`

Environment note:

- `deno` is still unavailable on `PATH` in this shell.
- Network download attempts for a temporary Deno binary hung and were interrupted by the user.
- The output files were generated with the local Xcode Python runtime as an execution fallback.
- The TypeScript source path remains the intended generator implementation, but it has not been runtime-verified with Deno in this shell.
