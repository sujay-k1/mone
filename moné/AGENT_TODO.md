# AGENT TODO — moné

> Updated: 2026-05-19 07:55 IST

---

## 🔴 NOW (Immediate)

- [ ] **Priya next pass** — only start when explicitly requested; use `aarav_spend_control_rash_decisions` as the source/intelligence boundary template.
- [ ] **Optional TS/Deno port** — Python deterministic fallback now generates the final Aarav rash package; port to TypeScript later only if useful.

## Synthetic Data Pass 1 ✅

- [x] Wrote `CODEX_RESUME_AUDIT.md` before implementation
- [x] Confirmed no `.git` directory at root
- [x] Confirmed all required synthetic-data docs exist
- [x] Added Pass 1 TypeScript runner source
- [x] Added Pass 1 TypeScript validation source
- [x] Fixed deterministic timestamp seconds in `random.ts`
- [x] Updated AA payload builder/types for masked account and link ref fields
- [x] Generated `aarav_spend_control_normal` deposit-only output files
- [x] Generated ground truth for every transaction
- [x] Generated canonical CSVs
- [x] Generated expected income and recurring candidates
- [x] Generated validation report with status `pass`
- [x] Regenerated monthly cashflow from raw deposit payload and ground truth
- [x] Regenerated mode spending summary from raw deposit payload
- [x] Rewrote Pass 1 summaries as deposit-only outputs
- [x] Replaced holder profile PII-like fields with synthetic placeholders
- [x] Fixed ground-truth day/time/salary-cycle metadata derivation
- [x] Added validation checks for reconciliation, unexpected FI types, metadata mismatch, negative balances, and PII policy
- [x] Kept dataset name as `aarav_spend_control_normal`
- [x] Revalidated with status `pass`
- [x] Added exact strict validation check names requested for fixture-quality Pass 1
- [x] Split recurring candidates into protected obligations, recurring spending rhythms, protected goal transfers, and leakage candidates
- [x] Regenerated income candidates excluding reimbursements and refunds
- [x] Confirmed minimum balance stays above `₹25,000`

## Aarav Rash Decisions Fixture ✅

- [x] Preserved `aarav_spend_control_normal`
- [x] Added `data/synthetic/configs/aarav_spend_control_rash_decisions.yaml`
- [x] Generated `deposit`, `mutual_funds`, `recurring_deposit`, and `term_deposit` FI payloads
- [x] Added linked SIP cash/MF purchase events
- [x] Added MF redemption and deposit proceeds
- [x] Added RD installments, RD premature closure, and deposit proceeds
- [x] Added TD opening, TD premature closure, and deposit proceeds
- [x] Added extreme gadget, luxury fashion, and spontaneous-trip clusters
- [x] Added irregular SIP behavior: skipped, failed, delayed, and reduced
- [x] Added credit-card stress: partial payment, late payment, interest, and late fee
- [x] Generated `financial_health_expected.json`
- [x] Generated `safe_to_spend_expected.json`
- [x] Generated `goal_risk_expected.json`
- [x] Validation status `pass`
- [x] Added category/time-window coherence validation and fixed timestamps
- [x] Hardened asset account summaries and extended `accounts.csv` value semantics
- [x] Removed ambiguous TD opening transaction to avoid asset double counting
- [x] Added major `life_event` labels
- [x] Added high-severity-only interrupt validation
- [x] Added `AARAV_FINAL_POLISH_AUDIT.md`
- [x] Added source-vs-intelligence boundary documentation
- [x] Cleaned `raw_payload.json` and canonical source CSVs so expected/nudge intelligence stays in ground truth and expected outputs
- [x] Added credit-card statement source files for statement cycles, utilization, partial payment, late fee, and interest
- [x] Added first-class EMI expected output for card EMI and device EMI behavior
- [x] Added safe-to-spend aliases for protected commitments, debt commitments, liquidity rescue, and excluded income
- [x] Added normalized recurring taxonomy fields for fixed, cancelable, debt, goal-protective, forecast-only, and leakage candidates
- [x] Added nudge reason/copy/suppression fields while keeping interrupts high-severity only
- [x] Raised rash fixture opening balance to `₹390,000`; deterministic regenerated package keeps deposit balance positive
- [x] Final polished rash validation status `pass`
- [x] Removed Moné taxonomy from source files and renamed card statement category to `merchant_category_from_statement`
- [x] Namespaced source reconciliation fields with `source_reconciliation_*` and JSON `generator_metadata`
- [x] Added `device_finance_source.json` for Bajaj/device EMI provenance
- [x] Added `nudge_expected.json` and moved user-facing nudge copy out of ground truth
- [x] Added future/projected statement cycles so EMI schedules do not reference missing cycles
- [x] Clarified card over-limit fields and explanations
- [x] Resolved TD premature closure semantics: zero current value, `₹112,000` payout, `₹8,000` penalty/adjustment
- [x] Fixed stale validation count text; deterministic package reports `928 tx, 928 gt`
- [x] Added final cleanup validation checks and passed all of them
- [x] Added `AARAV_FINAL_REGEN_AUDIT.md`
- [x] Added deterministic Python generator entrypoint `data/synthetic/src/run_all.py`
- [x] Added deterministic Python validator entrypoint `data/synthetic/src/validate_against_ground_truth.py`
- [x] Added shared final generator/validator implementation `data/synthetic/src/rash_final_generator.py`
- [x] Updated seed to `mone-aarav-rash-decisions-final-v2`
- [x] Deleted and regenerated the full rash output folder atomically
- [x] Added `output_manifest.json` with file list, hashes, row counts, transaction counts, expected counts, and layer file lists
- [x] Final deterministic regenerated package has `1475` source transactions and `1475` ground-truth records
- [x] Final validation report has `137` checks, `0` failures, status `pass`
- [x] Recomputed chronological deposit `balance_after` and raw `currentBalance` after stream merge
- [x] Removed Moné intelligence leakage from source transaction IDs/narrations
- [x] Added `demo_identity_map.json` with Aarav wired, Priya not wired, and unsupported-number state
- [x] Added `dataset_registry.json` with only Aarav marked ready
- [x] Marked credit-card statement source as scenario-grade and not production accounting
- [x] Marked `nudge_expected.json` as testing scaffold with interrupt-only copy review
- [x] Included `demo_identity_map.json` and `dataset_registry.json` inside the dataset folder
- [x] Added explicit statement-only-paid semantics for paid card EMI schedule rows
- [x] Tuned Aarav cash pressure to minimum `₹62,049.00` and closing `₹375,741.00` while keeping financial health `Risk`
- [x] Added validation for self-contained package, card EMI paid-cycle semantics, cash-pressure range, and interrupt copy review flags
- [x] Added reusable local micro-UPI noise generator for Aarav
- [x] Added 25-55 messy local UPI spends/month with QR, truncated merchants, ambiguous payees, adult discretionary, and local services
- [x] Added low/medium-confidence local UPI ground truth cases
- [x] Added contextual local UPI nudge/interruption validation
- [x] Added `net_worth_expected.json`
- [x] Tuned final net worth to `₹108,600.00` and liquid net worth to `-₹61,400.00`

## Swift App NOW (Inherited From Claude)

- [ ] **Install iOS Simulator Runtime** — Open Xcode → Settings → Components → Download iOS 26 Simulator
- [ ] **Create + boot simulator** — `xcrun simctl create "iPhone 16 Pro" ...`
- [ ] **Full xcodebuild run** — verify no runtime errors
- [ ] **Fix launch screen** — Info.plist references `LaunchBackground` color asset that doesn't exist yet
- [ ] **Add app icon** — currently placeholder, needs at least a simple dark icon for prototype

---

## 🟡 NEXT (This session)

- [x] **Agenda-first dummy AA flow** — added agenda education, AA-only method selection, dummy AA consent, phone OTP, fetch, processing, storage choice, and dashboard tour screens.
- [x] **Aarav dummy AA provider** — loads the validated `aarav_spend_control_rash_decisions` source bundle and does not read expected intelligence files.
- [x] **Phone mapping** — `8828290489` maps to Aarav, `7304893952` returns Priya-not-wired, unsupported numbers return retry state.
- [x] **Runtime intelligence path** — source bundle is transformed into Money Map, transactions, commitments, card/EMI pressure, goals, and dashboard insights without expected JSON.
- [ ] **Reload Xcode project / verify target membership** — Xcode MCP still reports a stale project model after project-file edits; reopen project if needed before final IDE build.
- [ ] **Full Xcode build in normal user session** — CLI build is blocked in this sandbox by SwiftPM diagnostics cache permissions under `~/Library/Caches`.
- [ ] **Dashboard → Financial Health detail** — tapping the health indicator on dashboard should navigate to `FinancialHealthDetailView`
- [ ] **Dashboard → Scenario check** — "Can I afford this?" CTA on GoalsDashboard should navigate/sheet to the scenario UI
- [ ] **Persistence** — wrap AppViewModel state in UserDefaults or SwiftData so onboarding isn't repeated on each launch
- [ ] **Onboarding skip-to-app** — add debug shortcut to jump straight to dashboard (useful for demo)

---

## 🟢 LATER (Polish phase)

- [ ] **App icon** — design a proper dark monochrome icon (moné wordmark or abstract mark)
- [ ] **Haptic feedback** — add UIImpactFeedbackGenerator on button taps, nudge reveal, goal milestone
- [ ] **Animation polish** — spring transitions between onboarding steps, card appear animations
- [ ] **Swipe gestures** — swipe on transaction row to edit category or ignore
- [ ] **Goal add flow** — `GoalsView` has no "Add goal" UI yet
- [ ] **Money Map edit** — `ConfirmFindingsView` items have no actual edit flow
- [ ] **Subscription detection insight** — "You have 3 subscriptions you haven't used this month"
- [ ] **Credit card discipline detail** — dedicated screen showing due date, min vs full payment
- [ ] **Financial health trend** — month-over-month comparison once persistence exists
- [ ] **Settings: nudge intensity** — SetupView shows current level but no in-place editor
- [ ] **Backup flow** — encrypted backup UI (future scope)
- [ ] **Account Aggregator sandbox** — if Setu credentials exist, replace mock AA flow
- [ ] **iPad layout** — low priority, stretch goal

---

## 🔵 BLOCKED

- [ ] **Real UPI handoff** — blocked on UPI PSP app availability (simulator can't run most UPI apps)
- [ ] **SMS processing** — blocked by iOS restrictions (Message Filter Extension only)
- [ ] **Real email OAuth** — blocked by credentials / backend requirement
- [ ] **Real Account Aggregator** — blocked by Setu sandbox credentials
- [ ] **Credit bureau score** — explicitly out of scope for MVP

---

## COMPLETED ✅

- [x] Full app architecture (Models, Services, ViewModels, Views, Design)
- [x] Design system (dark editorial color tokens, typography, spacing, components)
- [x] All data models (MoneyMap, Goal, Transaction, FinancialHealth, Agenda)
- [x] All service calculators (SafeToSpend, GoalProjection, FinancialHealth, Nudge)
- [x] Mock data service (Aarav profile, full realistic data)
- [x] AppViewModel (@Observable, state machine, computed properties)
- [x] Xcode project generation (xcodegen)
- [x] All 9 onboarding screens
- [x] All 5 main tab views (Dashboard × 3 variants, Transactions, Pay, Goals, Setup)
- [x] Pay with Pause flow (QR scanner simulation + nudge sheet)
- [x] Scenario check ("Can I afford this?") in Goals tab
- [x] Financial Health detail sheet
- [x] Custom dark tab bar (Pay tab elevated)
- [x] Type-check validation (0 errors)
- [x] Agent documentation (HANDOFF, TODO, DECISIONS, CHANGELOG)
## Priya Fixture Follow-Up

- Priya synthetic package is ready for app/provider wiring.
- Do not feed expected oracle files into runtime UI.
- Future product work should add UI copy and dashboard affordances for responsibility-driven Watch states.
- Use `zip -r -X` when sharing Priya package archives to avoid macOS metadata entries.
- Priya v3 artifact and targeted polish are complete; no remaining synthetic-data cleanup is known for Priya.
- Raw AA-style Money Map evidence hardening is complete for Aarav and Priya. Future work should build the derived intelligence tables from raw payloads rather than adding more source-layer labels.
