# Priya Final Artifact Polish Audit

Dataset: `priya_goal_planner_responsibility_burden`

Seed: `mone-priya-responsibility-burden-v3`

## Current Good State

- Priya v3 validates at the product/data-model level.
- Source-vs-intelligence separation is intact.
- Running balances, card cycles, card payment timing, safe-to-spend numeric semantics, family narration cleanup, education-loan EMI, and nudge consistency are implemented.
- Priya remains responsibility-burdened with overall health `Watch`.

## Remaining Artifact Issues

- `output_manifest.json` can report stale `validation_status` relative to `validation_report.json`.
- Manifest does not explicitly mirror validation failed-check count.
- A few card source narrations are more semantic than ideal:
  - `CARD/DE/MYNTRA FESTIVE SALE`
  - `CARD/DE/CROMA HOME APPLIANCE`
  - `CARD/DE/FAMILY TRAIN BOOKING`

## Fix Plan

- Make manifest generation read the current validation report and include matching `validation_status` and `failed_check_count`.
- Add strict validation checks:
  - `output_manifest_validation_status_matches_validation_report`
  - `output_manifest_failed_check_count_matches_validation_report`
  - `output_manifest_status_not_stale`
  - `card_source_narrations_are_merchant_like`
  - `source_card_narrations_do_not_leak_ground_truth_semantics`
- Replace card source narrations with merchant-like strings while keeping ground-truth labels unchanged.

## Regeneration Command

```bash
python3 data/synthetic/src/run_all.py --dataset priya_goal_planner_responsibility_burden --seed mone-priya-responsibility-burden-v3
python3 data/synthetic/src/validate_against_ground_truth.py --dataset priya_goal_planner_responsibility_burden
```

