# Raw Data Money Map Hardening Audit

Scope: generator-backed raw AA-style evidence enrichment for:

- `aarav_spend_control_rash_decisions`
- `priya_goal_planner_responsibility_burden`

## Completed

- Added raw evidence for LPG, rent components, variable electricity, internet/mobile topups, domestic help advance, EMI/loan extra payments, SIP/RD/MF topups, vehicle service/repair, annual subscriptions, and ambiguous needs-review signals.
- Preserved source-vs-intelligence separation. Raw files remain bank/card/UPI-style; hidden taxonomy remains in ground truth and expected oracle files.
- Regenerated both output folders through the generators.
- Revalidated both packages successfully.

## Final Validation

Priya:

- status: `pass`
- seed: `mone-priya-responsibility-burden-v3`
- total transactions: `590`
- deposit transactions: `549`
- asset transactions: `41`
- financial health: `Watch`
- failed checks: `0`

Aarav:

- status: `pass`
- seed: `mone-aarav-rash-decisions-final-v4`
- total transactions: `1607`
- deposit transactions: `1569`
- asset transactions: `38`
- financial health: `Risk`
- minimum deposit balance: `25078.0`
- closing deposit balance: `175374.0`
- validation checks: `162`
- failed checks: `0`

## Notes

- Aarav remains cash-pressured but not overdrafted.
- Priya remains disciplined and responsibility-burdened, not reckless.
- Outstanding liabilities remain sourced from card/device-finance style sources or expected/user-confirmed layers, not inferred solely from deposit rows.
