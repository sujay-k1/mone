# AGENT CHANGELOG — moné

> Append-only log of meaningful changes. Format: timestamp | summary | files | status

---

## 2026-05-17T16:00 — Initial project inspection

**Summary:** Inspected Stitch MCP project, found 35+ screens in `410508295000337477`. Identified design system (Hanken Grotesk, Geist, light theme with dark variants). Confirmed xcodegen available. Repository was nearly empty (only `Assets/SVG/Logo.svg`).  
**Files:** (read-only inspection)  
**Status:** ✅ Complete

---

## 2026-05-17T16:10 — Project scaffolding

**Summary:** Created full directory structure for iOS app. Generated `project.yml`, `Info.plist`, `Assets.xcassets/Contents.json`, and `AppIcon.appiconset/Contents.json`.  
**Files:**
- `project.yml` (created)
- `Resources/Info.plist` (created)
- `Resources/Assets.xcassets/Contents.json` (created)
- `Resources/Assets.xcassets/AppIcon.appiconset/Contents.json` (created)  
**Status:** ✅ xcodegen generates `mone.xcodeproj` successfully

---

## 2026-05-17T16:15 — Data models

**Summary:** Created all 5 domain model files. All models are value types (structs) conforming to Identifiable and Codable where needed. GoalStatus is Equatable.  
**Files:**
- `Sources/mone/Models/Agenda.swift` (created)
- `Sources/mone/Models/MoneyMap.swift` (created)
- `Sources/mone/Models/Goal.swift` (created)
- `Sources/mone/Models/Transaction.swift` (created)
- `Sources/mone/Models/FinancialHealth.swift` (created)  
**Status:** ✅ Type-checks clean

---

## 2026-05-17T16:20 — Design system

**Summary:** Created full dark editorial design system. Color tokens, typography scale (monospaced amounts), spacing, radius, ContourBackground orbital pattern, all card/button components.  
**Files:**
- `Sources/mone/Design/Theme.swift` (created)
- `Sources/mone/Design/Components/Buttons.swift` (created)
- `Sources/mone/Design/Components/Cards.swift` (created)  
**Status:** ✅ Type-checks clean (after fixing ternary ShapeStyle inference issue)

---

## 2026-05-17T16:25 — Services layer

**Summary:** Created all 5 service files. Pure static functions. SafeToSpend, GoalProjection, FinancialHealth (all 10 dimensions), NudgeEngine (intensity-aware), MockDataService (Aarav profile).  
**Files:**
- `Sources/mone/Services/SafeToSpendCalculator.swift` (created)
- `Sources/mone/Services/GoalProjectionCalculator.swift` (created)
- `Sources/mone/Services/FinancialHealthCalculator.swift` (created)
- `Sources/mone/Services/NudgeEngine.swift` (created)
- `Sources/mone/Services/MockDataService.swift` (created)  
**Status:** ✅ Type-checks clean

---

## 2026-05-17T16:30 — AppViewModel + App Shell

**Summary:** Created AppViewModel (@Observable, full onboarding state machine, pay evaluation). Created MoneApp.swift with @main, routing, custom tab bar, OnboardingFlow dispatcher.  
**Files:**
- `Sources/mone/ViewModels/AppViewModel.swift` (created)
- `Sources/mone/App/MoneApp.swift` (created)  
**Status:** ✅ Type-checks clean

---

## 2026-05-17T16:35 — Onboarding screens (9 screens)

**Summary:** Created all 9 onboarding screens. Welcome → DataPrivacy → AgendaSelection → SecondaryAgenda → SetupMethod → AAConsent → BuildingMoneyMap → ConfirmFindings → GoalSetup. All connected to AppViewModel.advance() state machine.  
**Files:**
- `Sources/mone/Views/Onboarding/WelcomeView.swift` (created)
- `Sources/mone/Views/Onboarding/DataPrivacyView.swift` (created)
- `Sources/mone/Views/Onboarding/AgendaSelectionView.swift` (created)
- `Sources/mone/Views/Onboarding/SecondaryAgendaView.swift` (created)
- `Sources/mone/Views/Onboarding/SetupMethodView.swift` (created)
- `Sources/mone/Views/Onboarding/AAConsentView.swift` (created)
- `Sources/mone/Views/Onboarding/BuildingMoneyMapView.swift` (created)
- `Sources/mone/Views/Onboarding/ConfirmFindingsView.swift` (created)
- `Sources/mone/Views/Onboarding/GoalSetupView.swift` (created)  
**Status:** ✅ Type-checks clean

---

## 2026-05-17T16:40 — Main tab views (10 view files)

**Summary:** Created all main tab views. Dashboard (adaptive, 3 variants), Transactions (filter chips), Pay with Pause (QR scanner sim + nudge sheet), Goals (scenario check), Setup (health detail, privacy, backup).  
**Files:**
- `Sources/mone/Views/Dashboard/DashboardView.swift` (created)
- `Sources/mone/Views/Dashboard/SpendingDashboardView.swift` (created)
- `Sources/mone/Views/Dashboard/GoalsDashboardView.swift` (created)
- `Sources/mone/Views/Dashboard/FinancialPictureDashboardView.swift` (created)
- `Sources/mone/Views/Transactions/TransactionsView.swift` (created)
- `Sources/mone/Views/Pay/PayView.swift` (created)
- `Sources/mone/Views/Pay/NudgeSheetView.swift` (created)
- `Sources/mone/Views/Goals/GoalsView.swift` (created)
- `Sources/mone/Views/Setup/SetupView.swift` (created)  
**Status:** ✅ Type-checks clean

---

## 2026-05-17T16:45 — Bug fixes (2 compile errors)

**Summary:** Fixed 2 type errors surfaced by swiftc -typecheck:
1. `Cards.swift:188` — `foregroundStyle(isConfirmed ? .moneHealthy : .moneSecondary)` — Swift couldn't infer ShapeStyle from ternary; fixed with explicit `Color.moneHealthy`
2. `GoalProjectionCalculator.swift:9` — unused `deadline` binding; replaced with `guard goal.deadline != nil`  
Also added `Equatable` conformance to `GoalStatus` enum (required for `==` operator in `GoalDetailCard`).  
**Files:**
- `Sources/mone/Design/Components/Cards.swift` (edited)
- `Sources/mone/Services/GoalProjectionCalculator.swift` (edited)
- `Sources/mone/Models/Goal.swift` (edited — added Equatable)  
**Status:** ✅ Zero compile errors, clean type-check

---

## 2026-05-17T16:50 — Agent documentation

**Summary:** Created all 4 agent handoff files.  
**Files:**
- `AGENT_HANDOFF.md` (created)
- `AGENT_TODO.md` (created)
- `AGENT_DECISIONS.md` (created)
- `AGENT_CHANGELOG.md` (this file, created)  
**Status:** ✅ Complete

---

## 2026-05-17T16:50 — Xcode project generation

**Summary:** Ran `xcodegen generate` to produce `mone.xcodeproj`. Project validates correctly. SDK is available (iphonesimulator26.4) but no simulator runtime devices installed yet.  
**Files:**
- `mone.xcodeproj/` (generated)  
**Status:** ✅ Project generated. ⚠️ Simulator runtime needs installation via Xcode → Settings → Components

---

## 2026-05-17T17:10 — Financial Noir design system + native tab bar

**Summary:** Applied the third Stitch design system ("Moné Design System" — Financial Noir) to `Theme.swift`. Replaced custom `MoneTabBar`/`MoneTabItem` with native iOS `TabView` + `UITabBar.appearance()` in `MoneApp.swift`.

Design system changes:
- Background: `#141313` (was `#0D0D0F`) · Surface-low: `#0E0E0E` (new) · Card surface `moneSurface`: `#1C1B1B` (was `#141417`)
- Stroke: `#2A2A2A` solid hairline (was `white @ 7%` opacity)
- Primary text: `#E5E2E0` · Secondary: `#C8C7BE` · Action fill: `#F4F1EA`
- Display/Headline fonts now use `.design: .serif` (Playfair Display analog)
- Letter-spacing on label caps increased to 1.5 tracking
- Orbital contour arcs reduced to ultra-low opacity (0.018) for Financial Noir restraint

Tab bar changes:
- Removed `MoneTabBar` + `MoneTabItem` custom views entirely
- Native `TabView(selection:)` with `.tabItem { Label(...) }` per tab
- `UITabBar.appearance()` configured in `MoneApp.init()`: `#0E0E0E` opaque background, `#2A2A2A` shadow/hairline, `#E5E2E0` selected text/icon, `#6B6B62` unselected
- `AppTab` enum simplified to raw cases (no computed title/icon properties needed)

**Files:**
- `Sources/mone/Design/Theme.swift` (updated — Financial Noir tokens)
- `Sources/mone/App/MoneApp.swift` (updated — native TabView)
- `mone.xcodeproj/` (regenerated)
**Status:** ✅ Zero typecheck errors · xcodegen clean

---

## 2026-05-18T23:35+05:30 — Codex resume audit for synthetic data

**Summary:** Inspected local directory without assuming git. Confirmed no `.git` root, no `rg`, and no Deno/Node runtime on PATH. Read existing handoff files, required synthetic-data docs, partial TypeScript modules, config, and output directory. Created `CODEX_RESUME_AUDIT.md` before implementation.  
**Files:**
- `CODEX_RESUME_AUDIT.md` (created)  
**Status:** Complete

---

## 2026-05-18T23:45+05:30 — Synthetic data Pass 1 TypeScript completion

**Summary:** Completed the missing Pass 1 TypeScript source path by adding an end-to-end runner and validator, fixing timestamp determinism, and adding AA masked-account/link-ref fields to the payload types and builder.  
**Files:**
- `data/synthetic/src/run_all.ts` (created)
- `data/synthetic/src/validate_against_ground_truth.ts` (created)
- `data/synthetic/src/random.ts` (updated)
- `data/synthetic/src/types.ts` (updated)
- `data/synthetic/src/build_aa_payload.ts` (updated)  
**Status:** Source complete, not Deno-runtime verified because `deno` is unavailable in this shell

---

## 2026-05-18T23:55+05:30 — Aarav normal deposit-only output generated

**Summary:** Generated the complete required Pass 1 output set for `aarav_spend_control_normal`. Deno was unavailable and temporary Deno download attempts hung, so output files were generated through the local Xcode Python runtime as an execution fallback. Validation report read-back status is `pass` with 1,348 deposit transactions, 12 salary credits, 12 rent debits, 24 SIP debits, 48 subscription debits, 14 cash blind spots, and 2 reimbursement credits.  
**Files:**
- `data/synthetic/output/aarav_spend_control_normal/raw_payload.json`
- `data/synthetic/output/aarav_spend_control_normal/ground_truth.json`
- `data/synthetic/output/aarav_spend_control_normal/accounts.csv`
- `data/synthetic/output/aarav_spend_control_normal/transactions.csv`
- `data/synthetic/output/aarav_spend_control_normal/monthly_cashflow.csv`
- `data/synthetic/output/aarav_spend_control_normal/mode_spending_summary.csv`
- `data/synthetic/output/aarav_spend_control_normal/income_candidates_expected.json`
- `data/synthetic/output/aarav_spend_control_normal/recurring_candidates_expected.json`
- `data/synthetic/output/aarav_spend_control_normal/validation_report.json`
- `CODEX_RESUME_AUDIT.md` (updated)
- `AGENT_HANDOFF.md` (updated)
- `AGENT_TODO.md` (updated)
- `AGENT_DECISIONS.md` (updated)
- `AGENT_CHANGELOG.md` (updated)  
**Status:** Pass 1 artifacts complete; TypeScript runtime verification remains blocked on Deno availability

---

## 2026-05-18T23:59+05:30 — Aarav Pass 1 output correctness repair

**Summary:** Evaluated the existing `aarav_spend_control_normal` package and fixed output correctness issues only. Regenerated `monthly_cashflow.csv` and `mode_spending_summary.csv` directly from the raw deposit payload and ground truth, rewrote `transactions.csv` as deposit-only rows, replaced holder profile PII-like fields with synthetic placeholders, fixed `day_of_week`, `time_of_day`, and `salary_cycle_phase` from actual transaction date/timestamp and last salary date, raised opening balance to `₹150,000` to satisfy the non-negative deposit balance policy, and regenerated validation. Dataset name remains `aarav_spend_control_normal`.  
**Files:**
- `data/synthetic/configs/aarav_spend_control_normal.yaml` (updated synthetic holder/opening balance)
- `data/synthetic/src/build_aa_payload.ts` (updated synthetic holder placeholders)
- `data/synthetic/src/generate_daily_transactions.ts` (updated metadata derivation)
- `data/synthetic/src/run_all.ts` (updated synthetic holder/opening balance)
- `data/synthetic/src/validate_against_ground_truth.ts` (added reconciliation/FI/metadata/balance/PII checks)
- `data/synthetic/output/aarav_spend_control_normal/raw_payload.json` (regenerated profile/balances)
- `data/synthetic/output/aarav_spend_control_normal/ground_truth.json` (regenerated metadata)
- `data/synthetic/output/aarav_spend_control_normal/accounts.csv` (regenerated)
- `data/synthetic/output/aarav_spend_control_normal/transactions.csv` (regenerated deposit-only)
- `data/synthetic/output/aarav_spend_control_normal/monthly_cashflow.csv` (regenerated from raw payload)
- `data/synthetic/output/aarav_spend_control_normal/mode_spending_summary.csv` (regenerated from raw payload)
- `data/synthetic/output/aarav_spend_control_normal/validation_report.json` (regenerated)  
**Status:** Validation pass · 1,348 deposit transactions · minimum balance `₹34,485.15` · only FI type `deposit`

---

## 2026-05-19T00:20+05:30 — Aarav Pass 1 fixture-quality strict validation repair

**Summary:** Re-evaluated and regenerated the existing Aarav Pass 1 deposit-only package without adding Priya or new FI types. Regenerated all required package files in place, kept opening balance at `₹150,000`, verified minimum balance `₹34,485.15`, split `recurring_candidates_expected.json` into `protected_obligation`, `recurring_spending_rhythm`, `protected_goal_transfer`, and `leakage_candidate`, and regenerated `income_candidates_expected.json` excluding reimbursements/refunds. `validation_report.json` now includes and passes the exact strict checks requested: monthly cashflow reconciliation, mode summary reconciliation, unexpected FI types, day-of-week metadata, time-of-day metadata, salary-cycle calendar, negative balance policy, PII policy, recurring candidate split, and income candidate reimbursement exclusion.  
**Files:**
- `data/synthetic/output/aarav_spend_control_normal/raw_payload.json` (regenerated)
- `data/synthetic/output/aarav_spend_control_normal/transactions.csv` (regenerated)
- `data/synthetic/output/aarav_spend_control_normal/accounts.csv` (regenerated)
- `data/synthetic/output/aarav_spend_control_normal/monthly_cashflow.csv` (regenerated)
- `data/synthetic/output/aarav_spend_control_normal/mode_spending_summary.csv` (regenerated)
- `data/synthetic/output/aarav_spend_control_normal/ground_truth.json` (regenerated)
- `data/synthetic/output/aarav_spend_control_normal/income_candidates_expected.json` (regenerated)
- `data/synthetic/output/aarav_spend_control_normal/recurring_candidates_expected.json` (regenerated)
- `data/synthetic/output/aarav_spend_control_normal/validation_report.json` (regenerated)  
**Status:** Validation pass · 1,348 deposit transactions · minimum balance `₹34,485.15` · candidate buckets `{protected_obligation: 10, recurring_spending_rhythm: 12, protected_goal_transfer: 3, leakage_candidate: 39}`

---

## 2026-05-19T00:55+05:30 — Aarav rash-decisions multi-FI fixture

**Summary:** Added `aarav_spend_control_rash_decisions` as a separate risky Aarav demo fixture while preserving `aarav_spend_control_normal`. The new fixture includes deposit, mutual funds, recurring deposit, and term deposit FI payloads. It models high income with rash spending, extreme gadget/fashion/travel clusters, irregular SIPs, MF redemption, RD premature closure, TD premature closure, credit-card stress, goal drift, safe-to-spend risk, and financial health `Risk`. Generated all required expected outputs and validation report.  
**Files:**
- `docs/synthetic-data/SYNTHETIC_DATA_MASTER_SPEC.md` (updated)
- `docs/synthetic-data/EXECUTION_PLAN.md` (updated)
- `data/synthetic/src/types.ts` (updated optional ground-truth fields)
- `data/synthetic/configs/aarav_spend_control_rash_decisions.yaml` (created)
- `data/synthetic/output/aarav_spend_control_rash_decisions/raw_payload.json`
- `data/synthetic/output/aarav_spend_control_rash_decisions/ground_truth.json`
- `data/synthetic/output/aarav_spend_control_rash_decisions/accounts.csv`
- `data/synthetic/output/aarav_spend_control_rash_decisions/transactions.csv`
- `data/synthetic/output/aarav_spend_control_rash_decisions/monthly_cashflow.csv`
- `data/synthetic/output/aarav_spend_control_rash_decisions/mode_spending_summary.csv`
- `data/synthetic/output/aarav_spend_control_rash_decisions/income_candidates_expected.json`
- `data/synthetic/output/aarav_spend_control_rash_decisions/recurring_candidates_expected.json`
- `data/synthetic/output/aarav_spend_control_rash_decisions/financial_health_expected.json`
- `data/synthetic/output/aarav_spend_control_rash_decisions/safe_to_spend_expected.json`
- `data/synthetic/output/aarav_spend_control_rash_decisions/goal_risk_expected.json`
- `data/synthetic/output/aarav_spend_control_rash_decisions/validation_report.json`
- `AGENT_HANDOFF.md` (updated)
- `AGENT_TODO.md` (updated)
- `AGENT_DECISIONS.md` (updated)
- `AGENT_CHANGELOG.md` (updated)  
**Status:** Validation pass · 1,130 total transactions · 1,095 deposit transactions · 35 asset transactions · minimum deposit balance `₹8,222.00` · financial health `Risk`

---

## 2026-05-19T01:20+05:30 — Aarav rash-decisions fixture hardening

**Summary:** Hardened the existing `aarav_spend_control_rash_decisions` package without adding personas or FI types. Fixed category/time-window coherence by regenerating semantic timestamps, added validation for time windows, corrected asset account value semantics in `accounts.csv`, reconciled asset summaries and final running balances, removed the ambiguous TD opening transaction to avoid double counting, added major `life_event` labels, and validated that interrupt nudges are high-severity only.  
**Files:**
- `docs/synthetic-data/AA_PAYLOAD_GENERATION_SPEC.md` (updated asset value convention)
- `docs/synthetic-data/GROUND_TRUTH_SPEC.md` (updated rash extension fields)
- `docs/synthetic-data/VALIDATION_SPEC.md` (updated hardening checks)
- `docs/synthetic-data/EXECUTION_PLAN.md` (updated rash fixture rules)
- `data/synthetic/output/aarav_spend_control_rash_decisions/raw_payload.json` (regenerated)
- `data/synthetic/output/aarav_spend_control_rash_decisions/ground_truth.json` (regenerated)
- `data/synthetic/output/aarav_spend_control_rash_decisions/accounts.csv` (regenerated with asset value columns)
- `data/synthetic/output/aarav_spend_control_rash_decisions/transactions.csv` (regenerated)
- `data/synthetic/output/aarav_spend_control_rash_decisions/monthly_cashflow.csv` (regenerated)
- `data/synthetic/output/aarav_spend_control_rash_decisions/mode_spending_summary.csv` (regenerated)
- `data/synthetic/output/aarav_spend_control_rash_decisions/income_candidates_expected.json` (regenerated)
- `data/synthetic/output/aarav_spend_control_rash_decisions/safe_to_spend_expected.json` (regenerated)
- `data/synthetic/output/aarav_spend_control_rash_decisions/validation_report.json` (regenerated)
- `AGENT_HANDOFF.md` (updated)
- `AGENT_TODO.md` (updated)
- `AGENT_DECISIONS.md` (updated)
- `AGENT_CHANGELOG.md` (updated)  
**Status:** Validation pass · 1,129 total transactions · 1,095 deposit transactions · 34 asset transactions · minimum deposit balance `₹9,191.00` · zero time-window, asset-balance, life-event, and low-severity-interrupt mismatches

---

## 2026-05-19T02:05+05:30 — Aarav final polish: source boundary, credit card, EMI

**Summary:** Completed the final Aarav polish pass for `aarav_spend_control_rash_decisions` without adding Priya or new unrelated FI types. Added source-vs-intelligence boundary documentation, cleaned canonical source CSVs, added separate credit-card statement source files, added first-class EMI expected output, enriched safe-to-spend aliases, normalized recurring taxonomy, tightened nudge semantics, and raised the opening deposit balance to `₹390,000` so facility `NONE` never goes negative after EMI additions.  
**Files:**
- `AARAV_FINAL_POLISH_AUDIT.md` (created/updated)
- `docs/synthetic-data/SOURCE_VS_INTELLIGENCE_BOUNDARY.md` (created)
- `docs/synthetic-data/CREDIT_CARD_AND_EMI_SPEC.md` (created)
- `docs/synthetic-data/AARAV_RASH_DECISIONS_FIXTURE_SPEC.md` (created)
- `docs/synthetic-data/VALIDATION_SPEC.md` (updated final-polish checks)
- `docs/synthetic-data/GROUND_TRUTH_SPEC.md` (updated EMI/nudge hidden fields)
- `docs/synthetic-data/EXECUTION_PLAN.md` (updated polished Aarav fixture status)
- `data/synthetic/configs/aarav_spend_control_rash_decisions.yaml` (opening balance updated)
- `data/synthetic/output/aarav_spend_control_rash_decisions/raw_payload.json` (regenerated balances)
- `data/synthetic/output/aarav_spend_control_rash_decisions/accounts.csv` (regenerated deposit balance row)
- `data/synthetic/output/aarav_spend_control_rash_decisions/transactions.csv` (source-only columns, regenerated balances)
- `data/synthetic/output/aarav_spend_control_rash_decisions/monthly_cashflow.csv` (regenerated from transactions/ground truth)
- `data/synthetic/output/aarav_spend_control_rash_decisions/safe_to_spend_expected.json` (updated aliases/debt pressure)
- `data/synthetic/output/aarav_spend_control_rash_decisions/recurring_candidates_expected.json` (updated normalized taxonomy)
- `data/synthetic/output/aarav_spend_control_rash_decisions/ground_truth.json` (updated EMI/nudge semantics)
- `data/synthetic/output/aarav_spend_control_rash_decisions/credit_card_statement.json` (added)
- `data/synthetic/output/aarav_spend_control_rash_decisions/credit_card_transactions.csv` (added)
- `data/synthetic/output/aarav_spend_control_rash_decisions/credit_card_summary.csv` (added)
- `data/synthetic/output/aarav_spend_control_rash_decisions/emi_candidates_expected.json` (added)
- `data/synthetic/output/aarav_spend_control_rash_decisions/validation_report.json` (updated old and new checks)
- `AGENT_HANDOFF.md` (updated)
- `AGENT_TODO.md` (updated)
- `AGENT_DECISIONS.md` (updated)
- `AGENT_CHANGELOG.md` (updated)  
**Status:** Validation pass · 1,135 total transactions · 1,101 deposit transactions · 34 asset transactions · 9 credit-card source transactions · 3 EMI candidates · minimum deposit balance `₹12,191.00` · financial health `Risk` · 18 interrupt nudges · zero source-boundary, card, EMI, recurring-taxonomy, and low-severity-interrupt mismatches

---

## 2026-05-19T02:35+05:30 — Aarav final cleanup: taxonomy-free source and fixture semantics

**Summary:** Completed the final cleanup for `aarav_spend_control_rash_decisions`. Removed Moné taxonomy from source files, renamed card source category to `merchant_category_from_statement`, namespaced card reconciliation metadata, added `device_finance_source.json`, added `nudge_expected.json`, moved user-facing copy out of ground truth, added missing/projected card statement cycles for EMI schedules, added over-limit explanation fields, resolved TD premature closure semantics to fully closed with explicit payout/penalty, and fixed stale validation count text.  
**Files:**
- `data/synthetic/output/aarav_spend_control_rash_decisions/raw_payload.json` (TD closure semantics updated)
- `data/synthetic/output/aarav_spend_control_rash_decisions/accounts.csv` (TD residual/payout fields added)
- `data/synthetic/output/aarav_spend_control_rash_decisions/transactions.csv` (TD closure row updated)
- `data/synthetic/output/aarav_spend_control_rash_decisions/monthly_cashflow.csv` (source-like cashflow only)
- `data/synthetic/output/aarav_spend_control_rash_decisions/credit_card_statement.json` (metadata namespaced, cycles expanded)
- `data/synthetic/output/aarav_spend_control_rash_decisions/credit_card_transactions.csv` (taxonomy-free source headers)
- `data/synthetic/output/aarav_spend_control_rash_decisions/credit_card_summary.csv` (over-limit fields added)
- `data/synthetic/output/aarav_spend_control_rash_decisions/device_finance_source.json` (added)
- `data/synthetic/output/aarav_spend_control_rash_decisions/ground_truth.json` (copy moved out, counts updated)
- `data/synthetic/output/aarav_spend_control_rash_decisions/nudge_expected.json` (added)
- `data/synthetic/output/aarav_spend_control_rash_decisions/emi_candidates_expected.json` (device source link added)
- `data/synthetic/output/aarav_spend_control_rash_decisions/validation_report.json` (new cleanup checks added)
- `docs/synthetic-data/SOURCE_VS_INTELLIGENCE_BOUNDARY.md` (updated)
- `docs/synthetic-data/CREDIT_CARD_AND_EMI_SPEC.md` (updated)
- `docs/synthetic-data/AARAV_RASH_DECISIONS_FIXTURE_SPEC.md` (updated)
- `docs/synthetic-data/VALIDATION_SPEC.md` (updated)
- `docs/synthetic-data/EXECUTION_PLAN.md` (updated)
- `AGENT_HANDOFF.md` (updated)
- `AGENT_TODO.md` (updated)
- `AGENT_DECISIONS.md` (updated)
- `AGENT_CHANGELOG.md` (updated)  
**Status:** Validation pass · 1,135 source transactions · 1,135 ground-truth records · 13 statement cycles · 3 EMI candidates · source taxonomy mismatches `0` · metadata namespace mismatches `0` · generic interrupt-copy mismatches `0` · TD semantics mismatches `0` · financial health remains `Risk`

---

## 2026-05-19T03:20+05:30 — Aarav deterministic regeneration with manifest

**Summary:** Added a deterministic Python generator/validator path for `aarav_spend_control_rash_decisions`, updated the seed to `mone-aarav-rash-decisions-final-v1`, deleted and regenerated the full rash output folder atomically, and added `output_manifest.json` with file hashes, row counts, transaction counts, source/expected layer lists, and validation status. The final validation report now contains 80 checks and passes with zero failures.  
**Files:**
- `AARAV_FINAL_REGEN_AUDIT.md` (created and completed)
- `data/synthetic/configs/aarav_spend_control_rash_decisions.yaml` (seed updated)
- `data/synthetic/src/rash_final_generator.py` (added deterministic generator/validator implementation)
- `data/synthetic/src/run_all.py` (added Python generation entrypoint)
- `data/synthetic/src/validate_against_ground_truth.py` (added Python validation entrypoint)
- `data/synthetic/output/aarav_spend_control_rash_decisions/*` (deleted and regenerated atomically)
- `data/synthetic/output/aarav_spend_control_rash_decisions/output_manifest.json` (added)
- `docs/synthetic-data/EXECUTION_PLAN.md` (updated deterministic commands/status)
- `docs/synthetic-data/AARAV_RASH_DECISIONS_FIXTURE_SPEC.md` (updated deterministic counts/status)
- `AGENT_HANDOFF.md` (updated)
- `AGENT_TODO.md` (updated)
- `AGENT_DECISIONS.md` (updated)
- `AGENT_CHANGELOG.md` (updated)  
**Status:** Validation pass · 80 checks · 0 failures · 19 output files · 914 source transactions · 914 ground-truth records · 879 deposit transactions · 35 asset transactions · 9 credit-card statement transactions · 13 card statement cycles · 3 EMI candidates · financial health `Risk` · manifest status `pass`

---

## 2026-05-19T06:05+05:30 — Dummy AA Aarav app flow wiring

**Summary:** Started the agenda-first dummy Account Aggregator app flow on branch `flow/agenda-first-dummy-aa-aarav`. Added the synthetic AA provider, source-bundle response shape, Aarav phone mapping, Priya-not-wired and unsupported-number states, source-bundle loading, deterministic runtime transformer, agenda education, dummy AA consent, phone OTP, fetch/progress, processing, storage choice, and dashboard tour screens. Updated routing to the new onboarding state model and preserved local-mode dashboard entry after post-analysis storage choice.

**Files:**
- `Sources/mone/Services/DummyAAProvider.swift` (added)
- `Sources/mone/Services/AADataTransformer.swift` (added)
- `Sources/mone/Views/Onboarding/AgendaEducationView.swift` (added)
- `Sources/mone/Views/Onboarding/DummyAAConsentView.swift` (added)
- `Sources/mone/Views/Onboarding/PhoneVerificationView.swift` (added)
- `Sources/mone/Views/Onboarding/DataProcessingView.swift` (added)
- `Sources/mone/Views/Onboarding/StorageChoiceView.swift` (added)
- `Sources/mone/App/MoneApp.swift` (new onboarding routing)
- `Sources/mone/ViewModels/AppViewModel.swift` (source-bundle state)
- `Sources/mone/ViewModels/SessionViewModel.swift` (new onboarding step persistence names)
- `Sources/mone/Views/Onboarding/SetupMethodView.swift` (AA-only enabled)
- `Sources/mone/Views/Onboarding/AAConsentView.swift` (old enum case compatibility fix)
- `Sources/mone/Views/Setup/SetupView.swift` (logout/delete reachable from dashboard setup)
- `project.yml` and `mone.xcodeproj/project.pbxproj` (Aarav source bundle and new Swift files wired)

**Status:** Dataset validation remains pass. Runtime source code does not reference expected intelligence filenames. `xcodebuild` is blocked in this sandbox by SwiftPM diagnostics cache permissions under `~/Library/Caches`; Xcode MCP still appears to have a stale project model and reports missing new files until the project is reloaded.

---

## 2026-05-19T06:45+05:30 — Aarav rash v2 deterministic quality pass

**Summary:** Completed the final deterministic Aarav fixture hardening pass with seed `mone-aarav-rash-decisions-final-v2`. The regenerated package validates with 100 checks and 0 failures. Deposit running balances now reconcile chronologically, raw payload current balances match canonical CSV balances, source narrations are bank-like and taxonomy-free, demo identity mapping and dataset registry files exist, Priya remains not wired, credit-card source is marked scenario-grade/not production accounting, and `nudge_expected.json` is marked as testing scaffold.

**Files:**
- `AARAV_FINAL_REGEN_AUDIT.md` (updated)
- `data/synthetic/configs/aarav_spend_control_rash_decisions.yaml` (seed updated)
- `data/synthetic/src/rash_final_generator.py` (v2 generator/validator hardening)
- `data/synthetic/output/aarav_spend_control_rash_decisions/*` (regenerated)
- `data/synthetic/output/demo_identity_map.json` (generated)
- `data/synthetic/output/dataset_registry.json` (generated)
- `docs/synthetic-data/SOURCE_VS_INTELLIGENCE_BOUNDARY.md` (updated)
- `docs/synthetic-data/CREDIT_CARD_AND_EMI_SPEC.md` (updated)
- `docs/synthetic-data/AARAV_RASH_DECISIONS_FIXTURE_SPEC.md` (updated)
- `docs/synthetic-data/VALIDATION_SPEC.md` (updated)
- `docs/synthetic-data/EXECUTION_PLAN.md` (updated)
- `docs/synthetic-data/DEMO_IDENTITY_MAPPING_SPEC.md` (added)
- `AGENT_HANDOFF.md` (updated)
- `AGENT_TODO.md` (updated)
- `AGENT_DECISIONS.md` (updated)
- `AGENT_CHANGELOG.md` (updated)

**Status:** Validation pass · 100 checks · 0 failures · 19 dataset files · 927 source transactions · 927 ground-truth records · 892 deposit transactions · 35 asset transactions · 9 credit-card statement transactions · 13 card statement cycles · 3 EMI candidates · financial health `Risk` · manifest status `pass`

---

## 2026-05-19T07:05+05:30 — Aarav rash precision cleanup

**Summary:** Completed the final precision cleanup for `aarav_spend_control_rash_decisions`. The dataset folder is now self-contained with identity and registry files, paid card EMI schedule rows have explicit scenario-grade statement-only paid semantics, Aarav's cash-pressure story is intentional and validated, and interrupt-level nudge copy review flags are enforced.

**Files:**
- `data/synthetic/src/rash_final_generator.py` (self-contained files, card EMI semantics, cash-pressure tuning, validation checks)
- `data/synthetic/output/aarav_spend_control_rash_decisions/*` (regenerated)
- `data/synthetic/output/demo_identity_map.json` (shared copy regenerated)
- `data/synthetic/output/dataset_registry.json` (shared copy regenerated)
- `docs/synthetic-data/AARAV_RASH_DECISIONS_FIXTURE_SPEC.md` (updated)
- `docs/synthetic-data/CREDIT_CARD_AND_EMI_SPEC.md` (updated)
- `docs/synthetic-data/VALIDATION_SPEC.md` (updated)
- `docs/synthetic-data/EXECUTION_PLAN.md` (updated)
- `docs/synthetic-data/DEMO_IDENTITY_MAPPING_SPEC.md` (updated)
- `AGENT_HANDOFF.md` (updated)
- `AGENT_TODO.md` (updated)
- `AGENT_DECISIONS.md` (updated)
- `AGENT_CHANGELOG.md` (updated)

**Status:** Validation pass · 114 checks · 0 failures · 21 dataset files · 928 source transactions · 928 ground-truth records · 893 deposit transactions · 35 asset transactions · min deposit balance `₹62,049.00` · closing deposit balance `₹375,741.00` · 17 interrupt nudges · financial health `Risk`

---

## 2026-05-19T07:55+05:30 — Aarav local UPI and net-worth enhancement

**Summary:** Enhanced `aarav_spend_control_rash_decisions` with realistic messy local UPI micro-spends and low/risk net-worth expectations. Added 25-55 local UPI spends per month across stalls, shops, services, healthcare, mobility, adult discretionary, QR aggregators, and ambiguous person-name payees. Added `net_worth_expected.json` and validations for local UPI diversity, ambiguity, limited contextual UPI interrupts, and net-worth reconciliation.

**Files:**
- `data/synthetic/src/rash_final_generator.py` (local UPI generator, net worth expected output, validation checks)
- `data/synthetic/configs/aarav_spend_control_rash_decisions.yaml` (seed updated)
- `data/synthetic/output/aarav_spend_control_rash_decisions/*` (regenerated)
- `docs/synthetic-data/AARAV_RASH_DECISIONS_FIXTURE_SPEC.md` (updated)
- `docs/synthetic-data/EXECUTION_PLAN.md` (updated)
- `docs/synthetic-data/VALIDATION_SPEC.md` (updated)
- `AGENT_HANDOFF.md` (updated)
- `AGENT_TODO.md` (updated)
- `AGENT_DECISIONS.md` (updated)
- `AGENT_CHANGELOG.md` (updated)

**Status:** Validation pass · 137 checks · 0 failures · 22 dataset files · 1475 source transactions · 1475 ground-truth records · 1440 deposit transactions · 35 asset transactions · min deposit balance `₹29,899.00` · closing deposit balance `₹186,300.00` · final net worth `₹108,600.00` · liquid net worth `-₹61,400.00` · 22 interrupt nudges · financial health `Risk`
## Priya Responsibility-Burden Fixture

- Added deterministic Priya generator: `data/synthetic/src/priya_final_generator.py`.
- Added config: `data/synthetic/configs/priya_goal_planner_responsibility_burden.yaml`.
- Updated generator/validator dispatch so `run_all.py` and `validate_against_ground_truth.py` support both Aarav and Priya datasets.
- Generated a self-contained Priya output package with source files, expected/test-oracle files, manifest, validation report, demo identity map, and dataset registry.
- Priya phone `7304893952` now maps to `priya_goal_planner_responsibility_burden`; it is not mapped to Aarav.
- Added Priya education-loan EMI, family obligations, healthcare, insurance, self-transfers, local micro-UPI, cash withdrawals, goal drift, net worth, and gentle nudge scaffolding.
- Cleaned Priya v2 card cycles, card payment timing, hybrid card cashflow metadata, safe-to-spend distribution, family/support narrations, packaging checks, and validation summary.
- Added Priya v2 ground-truth nudge normalization and strict checks for non-candidate stale nudge fields.
- Added Priya v3 safe-to-spend numeric/status semantics, explicit data-period metadata, and validation checks for generated-at/data-period separation.
- Completed Priya final artifact polish: manifest validation status/failed-check count now match the final validation report, and card source narrations were simplified to merchant-like strings.
- Completed Priya final targeted polish: stabilized manifest-status diagnostic payloads so they report current `pass` / `0` values, corrected the `2025-10-19` parent-support transfer to mode `FT`, and added deposit mode/narration prefix validation. Final Priya v3 validation passes with 110 checks and zero failures.

## Raw AA-Style Money Map Evidence Hardening

- Enhanced both Aarav and Priya generators with raw bank/card/UPI evidence for LPG, rent components, variable electricity, internet/mobile topups, domestic help advance, EMI/loan extra payments, SIP/RD/MF topups, vehicle service/repair, annual renewals, and ambiguous needs-review signals.
- Kept raw source files taxonomy-free; intelligence labels remain only in ground truth and expected oracle artifacts.
- Added/strengthened raw evidence validation checks for future Money Map/Dashboard inference readiness.
- Regenerated both final output folders through their generators.

**Status:** Priya validation pass · 590 transactions · financial health `Watch` · 0 failures. Aarav validation pass · 1607 transactions · 162 checks · minimum deposit balance `₹25,078.00` · closing deposit balance `₹175,374.00` · financial health `Risk` · 0 failures.
