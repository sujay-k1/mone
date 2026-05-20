# Priya Cleanup Audit

Dataset: `priya_goal_planner_responsibility_burden`

Previous seed: `mone-priya-responsibility-burden-v1`

Target seed: `mone-priya-responsibility-burden-v2`

## Current Good State

- Priya package exists and validates under the first-pass validator.
- Source/expected separation is established.
- Education loan EMI is present monthly and treated as responsible debt burden.
- Parents support, sibling support, local UPI, cash withdrawals, healthcare, insurance, goals, net worth, and nudges exist.
- Running balances passed after the first cleanup.
- Demo identity maps Priya to Priya and preserves Aarav mapping.

## Issues To Fix

- Credit-card transactions and EMI schedules reference statement cycles not present in the statement/summary.
- Card bill payment dates are earlier than their logical due windows unless explicitly marked interim.
- Hybrid credit-card cashflow semantics need stronger source metadata and validation.
- Priya safe-to-spend status distribution is too risk-heavy relative to overall `Watch`.
- Some source narrations over-label family/support/self-transfer intent.
- Some non-candidate ground-truth rows can retain stale expected nudge fields unless normalized before export.
- Packaging guidance/checks should prevent macOS metadata artifacts.

## Fix Plan

- Generate card statement cycles continuously from 2025-06 through 2026-07.
- Align historical card payment rows to due/late windows where possible and explicitly mark any interim payment semantics in ground truth/statement metadata.
- Add card cashflow counting policy metadata to the card statement source.
- Recalibrate safe-to-spend expected statuses to a Priya-appropriate mix: 2-4 Risk, 6-8 Watch, 1-3 Healthy.
- Replace over-labeled source narrations with bank-like beneficiary/merchant strings while preserving ground-truth labels.
- Normalize nudge fields during transaction generation so non-candidates have no `expected_nudge_type`, cannot interrupt, and only use `silent_signal`.
- Add validation checks for missing cycles, payment timing, hybrid card semantics, safe-to-spend distribution, narration realism, and packaging artifacts.

## Regeneration Command

```bash
python3 data/synthetic/src/run_all.py --dataset priya_goal_planner_responsibility_burden --seed mone-priya-responsibility-burden-v2
python3 data/synthetic/src/validate_against_ground_truth.py --dataset priya_goal_planner_responsibility_burden
```
