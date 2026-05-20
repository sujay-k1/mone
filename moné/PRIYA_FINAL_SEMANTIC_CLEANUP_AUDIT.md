# Priya Final Semantic Cleanup Audit

Dataset: `priya_goal_planner_responsibility_burden`

Previous seed: `mone-priya-responsibility-burden-v2`

Target seed: `mone-priya-responsibility-burden-v3`

## Current Good State

- Priya is responsibility-burdened, not reckless.
- Overall financial health is `Watch`.
- Education loan EMI, parents support, sibling support, self-transfers, local UPI, cash withdrawals, healthcare, insurance, goals, net worth, and card pressure are present.
- Source-vs-intelligence separation passes.
- Credit-card cycles, EMI schedule cycle references, card payment timing, hybrid card metadata, source narration cleanup, and nudge field cleanup pass.

## Remaining Issue

The safe-to-spend expected file has mixed statuses, but the numeric `safe_to_spend_end` values can remain deeply negative for months marked `Watch` or `Healthy`. This makes the expected oracle semantically inconsistent.

## Fix Plan

- Increment Priya seed to `mone-priya-responsibility-burden-v3`.
- Keep the responsibility-driven monthly pattern: 4 Risk, 6 Watch, 2 Healthy.
- Generate explicit capacity fields:
  - `planned_safe_to_spend_after_expected_spend`
  - `actual_safe_to_spend_after_period`
  - `must_pay_commitments`
  - `family_responsibility_commitments`
  - `education_loan_commitments`
  - `insurance_commitments`
  - `goal_protection`
  - `discretionary_capacity`
- Ensure numeric status semantics:
  - Healthy months are non-negative.
  - Watch months stay tight but not deeply negative.
  - Risk months have a material shortfall or named risk event.
- Add data period metadata separate from fixture generation time:
  - `fixture_generated_at`
  - `data_period_start`
  - `data_period_end`
  - `data_as_of_date`
- Add validation checks for safe-to-spend numeric/status semantics and data-period metadata.

## Regeneration Command

```bash
python3 data/synthetic/src/run_all.py --dataset priya_goal_planner_responsibility_burden --seed mone-priya-responsibility-burden-v3
python3 data/synthetic/src/validate_against_ground_truth.py --dataset priya_goal_planner_responsibility_burden
```

