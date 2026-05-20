# Priya Responsibility-Burden Fixture Spec

Dataset: `priya_goal_planner_responsibility_burden`

Seed: `mone-priya-responsibility-burden-v3`

Priya is a high-income Bangalore product manager whose pressure comes from responsibilities rather than reckless spending. The fixture includes salary, education-loan EMI, parent support, irregular sibling support, household obligations, insurance, healthcare events, self-account transfers, cash withdrawals, local micro-UPI, goals, card pressure, and net-worth/liquidity analysis.

Runtime source files are bank/statement-like and taxonomy-free. Responsibility labels, category labels, goal risk, safe-to-spend, financial-health status, and nudge expectations live only in `ground_truth.json` and `*_expected.json`.

Priya v2 generates card statement cycles from `cc_2025_06` through `cc_2026_07`; every card transaction and EMI schedule reference resolves. Card statement files are scenario-grade, not production card accounting.

Final validation target:

- overall financial health: `Watch`
- safe-to-spend distribution: mixed Risk/Watch/Healthy
- education-loan EMI: 12 monthly rows
- Priya phone: `7304893952`
- package files: 22

Latest v3 validation summary:

- total transactions: 497
- card statement cycles: 14
- local micro-UPI count: 254
- education-loan EMI count: 12
- safe-to-spend risk/watch/healthy months: 4/6/2
- final net worth: 2223234.0
- final liquid net worth: 232934.0
- overall financial health: Watch
- failed checks: 0

Final artifact polish keeps `output_manifest.json` aligned with `validation_report.json`: validation status and failed-check count must match. Card source narrations are merchant-like (`CARD/DE/MYNTRA`, `CARD/DE/CROMA`, `CARD/DE/IRCTC`) while semantic meaning remains in ground truth.

Ground-truth nudge fields are normalized before export. If `nudge_candidate` is false, `expected_nudge_type` is null, `should_interrupt` is false, and `surface_mode` remains `silent_signal`.

Safe-to-spend v3 uses explicit capacity semantics. `actual_safe_to_spend_after_period` is the canonical numeric capacity for the monthly status:

- `Healthy`: non-negative capacity
- `Watch`: tight capacity between roughly `-50000` and `50000`
- `Risk`: material shortfall below `-50000` or an explicit pressure event

`generated_at` is fixture-generation metadata. Data freshness uses `data_period_start`, `data_period_end`, and `data_as_of_date`.
