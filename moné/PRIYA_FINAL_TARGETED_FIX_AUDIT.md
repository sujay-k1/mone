# Priya Final Targeted Fix Audit

Dataset: `priya_goal_planner_responsibility_burden`

Seed: `mone-priya-responsibility-burden-v3`

Scope: final artifact polish only. Priya's persona, safe-to-spend model, net-worth model, education loan EMI, family pressure, and credit-card semantics are intentionally unchanged.

## Findings

- Manifest and validation top-level values were correct in the accepted v3 package, but manifest-status validation diagnostics could display stale on-disk values from the previous validation pass.
- One parent-support source row had `mode = UPI` while the narration used the bank-transfer prefix `FT/DE/MOM HDFC`.

## Fixes

- Manifest/report writing now runs validation-manifest stabilization passes so the final `validation_report.json` diagnostics are computed after the matching manifest exists.
- Added explicit validation checks for current manifest-status diagnostic payloads.
- Changed the `2025-10-19` parent-support row to `mode = FT` while preserving date, amount, narration, and ground-truth interpretation.
- Added deposit cashflow mode/narration prefix validation for UPI, FT, NACH/ECS/ACH, CARD, and ATM rows. Asset FI rows keep their statement-style prefixes such as `RD/` and `MF/`.

## Preservation Notes

- No generated output files were manually patched.
- The full Priya output folder must be regenerated atomically from the generator.
- Safe-to-spend, net worth, card cycles, source boundary, and Priya responsibility-burden behavior are preserved.
