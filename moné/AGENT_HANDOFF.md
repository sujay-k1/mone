# AGENT HANDOFF — moné iOS App

> **Last updated:** 2026-05-19 07:55 IST | **Updated by:** Codex  
> **Status:** Synthetic data now includes a clean Aarav normal baseline and a deterministic v4 risky Aarav rash-decisions demo fixture with messy local UPI micro-spends, low/risk net worth, self-contained identity/registry files, intentional cash-pressure ranges, explicit card EMI paid-cycle semantics, chronological balances, bank-like source narrations, manifest, source/intelligence separation, credit-card statement, device-finance, EMI, and nudge expected outputs. Swift app foundation status below is inherited from Claude.

---

## FOR NEXT AGENT — START HERE

### Current task
Synthetic data Pass 1 has been resumed and completed for:

- dataset: `aarav_spend_control_normal`
- account type: `deposit`
- generated transactions: `1348`
- validation: `pass`
- latest correction pass: output summaries and metadata regenerated; minimum balance `₹34,485.15`; only FI type `deposit`
- fixture-quality strict validation pass: exact requested checks present and passing; recurring candidates split into four candidate buckets

New risky demo fixture:

- dataset: `aarav_spend_control_rash_decisions`
- FI types: `deposit`, `mutual_funds`, `recurring_deposit`, `term_deposit`
- credit-card source files: `credit_card_statement.json`, `credit_card_transactions.csv`, `credit_card_summary.csv`
- device-finance source file: `device_finance_source.json`
- EMI expected output: `emi_candidates_expected.json`
- nudge expected output: `nudge_expected.json`
- manifest: `output_manifest.json`
- deterministic seed: `mone-aarav-rash-decisions-final-v4`
- validation: `pass`
- validation checks: `137`
- total transactions: `1475`
- deposit transactions: `1440`
- asset transactions: `35`
- card statement cycles: `13`
- salary events: `12`
- nudge candidates: `748`
- interrupt-level nudges: `17`
- minimum deposit balance: `₹29,899.00`
- closing deposit balance: `₹186,300.00`
- final net worth: `₹108,600.00`
- final liquid net worth: `-₹61,400.00`
- financial health overall status: `Risk`
- safe-to-spend: `6` Watch/Risk months, `3` negative safe-to-spend months
- hardening checks: zero category-time mismatches, zero asset-balance mismatches, zero source-taxonomy mismatches, zero source-metadata namespace mismatches, zero credit-card reconciliation mismatches, zero EMI reconciliation mismatches, zero recurring-taxonomy mismatches, zero low-severity interrupt mismatches, zero TD semantics mismatches
- v2 hardening checks: chronological deposit balances reconcile, raw `currentBalance` matches `transactions.csv`, source narrations are bank-like and taxonomy-free, demo identity map exists, Priya is not mapped to Aarav, dataset registry marks only Aarav ready, card statement is scenario-grade/not production accounting, and nudge expected output is marked as test scaffolding
- precision cleanup checks: dataset folder is self-contained with `demo_identity_map.json` and `dataset_registry.json`, paid card EMI rows are explicit statement-only scenario-grade rows, cash pressure is intentional and within configured ranges, and interrupt copy review flags are enforced
- local UPI/net-worth checks: 25-55 local micro-UPI spends/month, QR/truncated/person-name payees, low/medium confidence ground truth, limited contextual UPI interrupts, `net_worth_expected.json`, and net-worth reconciliation against source assets/liabilities

Immediate next step:

1. Reproduce Aarav rash fixture with:
   ```bash
   python3 data/synthetic/src/run_all.py --dataset aarav_spend_control_rash_decisions --seed mone-aarav-rash-decisions-final-v4
   ```
2. Validate Aarav rash fixture with:
   ```bash
   python3 data/synthetic/src/validate_against_ground_truth.py --dataset aarav_spend_control_rash_decisions
   ```
3. Continue to Priya only when explicitly requested, using the Aarav rash fixture as the template standard.
4. Optionally port the Python fallback generator into TypeScript/Deno later if runtime tooling becomes available.

Use `aarav_spend_control_rash_decisions` as the template standard for Priya: source files must stay reality-grounded and taxonomy-free; taxonomy, expected nudges, safe-to-spend, goal risk, financial health, and product copy belong in ground truth or expected outputs.

Do not start Priya, mutual funds, RD, TD, insurance, equities, NPS, or GSTR unless the user asks for the next pass.

### Synthetic Data Pass 1 Status

What changed:

- Wrote `CODEX_RESUME_AUDIT.md` before implementation.
- Added `data/synthetic/src/run_all.ts`.
- Added `data/synthetic/src/validate_against_ground_truth.ts`.
- Fixed deterministic timestamp seconds in `data/synthetic/src/random.ts`.
- Added `linkRefNumber`, top-level `maskedAccNumber`, and account-level `maskedAccNumber` fields to AA payload types/building.
- Generated all required output files under `data/synthetic/output/aarav_spend_control_normal`.

Files changed:

- `CODEX_RESUME_AUDIT.md`
- `data/synthetic/src/random.ts`
- `data/synthetic/src/types.ts`
- `data/synthetic/src/build_aa_payload.ts`
- `data/synthetic/src/run_all.ts`
- `data/synthetic/src/validate_against_ground_truth.ts`
- `data/synthetic/output/aarav_spend_control_normal/*`
- `AGENT_HANDOFF.md`
- `AGENT_TODO.md`
- `AGENT_DECISIONS.md`
- `AGENT_CHANGELOG.md`

What works:

- Output directory contains:
  - `raw_payload.json`
  - `ground_truth.json`
  - `accounts.csv`
  - `transactions.csv`
  - `monthly_cashflow.csv`
  - `mode_spending_summary.csv`
  - `income_candidates_expected.json`
  - `recurring_candidates_expected.json`
  - `validation_report.json`
- Read-back validation report status is `pass`.
- Ground truth exists for every transaction.
- CSV rows match payload transaction count.
- Cash withdrawals are marked as blind spots.
- SIPs/goal allocations are not marked as lifestyle spending.
- Reimbursements are represented and linked in ground truth.
- `monthly_cashflow.csv` is regenerated from the raw deposit payload and ground-truth labels.
- `mode_spending_summary.csv` is regenerated from raw deposit payload debit transactions.
- Holder profile fields use synthetic placeholders:
  - `Synthetic Holder AARAV`
  - `aarav.synthetic@example.invalid`
  - `9000000000`
  - `SYNTH0000X`
- Ground-truth `day_of_week`, `time_of_day`, and `salary_cycle_phase` are derived from transaction date/timestamp and actual last salary date.
- Validation now checks monthly reconciliation, mode reconciliation, unexpected FI types, metadata mismatch, negative balance policy, and PII policy.
- `validation_report.json` now includes these exact strict checks:
  - `monthly_cashflow_reconciliation`
  - `mode_summary_reconciliation`
  - `unexpected_fi_types_absent`
  - `ground_truth_day_of_week_matches_date`
  - `ground_truth_time_of_day_matches_timestamp`
  - `salary_cycle_phase_matches_salary_calendar`
  - `negative_balance_policy`
  - `pii_policy_holder_profile`
  - `recurring_candidates_split_obligation_vs_rhythm`
  - `income_candidates_exclude_reimbursements`
- `recurring_candidates_expected.json` is split into:
  - `protected_obligation`
  - `recurring_spending_rhythm`
  - `protected_goal_transfer`
  - `leakage_candidate`
- `income_candidates_expected.json` excludes reimbursements and refunds.
- `aarav_spend_control_rash_decisions` output directory contains:
  - `raw_payload.json`
  - `ground_truth.json`
  - `accounts.csv`
  - `transactions.csv`
  - `monthly_cashflow.csv`
  - `mode_spending_summary.csv`
  - `credit_card_statement.json`
  - `credit_card_transactions.csv`
  - `credit_card_summary.csv`
  - `device_finance_source.json`
  - `income_candidates_expected.json`
  - `recurring_candidates_expected.json`
  - `emi_candidates_expected.json`
  - `financial_health_expected.json`
  - `safe_to_spend_expected.json`
  - `goal_risk_expected.json`
  - `nudge_expected.json`
  - `validation_report.json`
  - `output_manifest.json`
- Rash fixture validates linked cash/asset events for SIP, MF redemption, RD closure, and TD closure.
- Rash fixture has overall financial health `Risk`; investment redemptions and deposit closures are not counted as income.
- Rash fixture `accounts.csv` now has asset-aware columns including `current_value`, `opening_value`, `investment_value`, `liquidity_class`, and `balance_role`.
- Asset balances reconcile across raw payload summaries, final asset transaction balances, and `accounts.csv`.
- TD opening/principal value is represented by account summary/CSV fields, not by a duplicate opening transaction.
- Category/subcategory timestamps now pass semantic windows such as lunch, late-night food, cab-to-work, cab-from-work, weekend dining, and coffee.
- Major rash/card/liquidity events have `life_event` labels.
- Interrupt nudges are high-severity only and remain at `17` annually.

What is broken / needs follow-up:

- `deno` is not on `PATH` in this shell.
- Attempted network download of a temporary Deno binary hung and was interrupted by the user.
- TypeScript runner source exists but has not been runtime-verified with Deno in this environment.
- Aarav normal output was produced through the earlier local Python fallback because no TypeScript runtime was available.
- Aarav rash output now has a deterministic Python fallback generator and validator with manifest. Deno/TypeScript runtime verification remains pending only for the older TypeScript path.

Dataset-name decision:

- Keep `aarav_spend_control_normal`.
- Reason: this is Aarav's baseline normal behavior as a high-leakage spend-control persona. A future deliberately intensified dataset can be named separately.

Commands used:

```bash
ps -axo pid,etime,command | grep -E '[c]url|[d]eno|mone-deno'
which python3; python3 --version
python3 - <<'PY'
# generated Aarav normal Pass 1 output files
PY
find data/synthetic/output/aarav_spend_control_normal -maxdepth 1 -type f | sort
wc -l data/synthetic/output/aarav_spend_control_normal/*.csv
python3 - <<'PY'
# read validation_report.json summary
PY
```

How to validate now:

```bash
python3 - <<'PY'
import json
p='data/synthetic/output/aarav_spend_control_normal/validation_report.json'
with open(p) as f:
    r=json.load(f)
print(r['status'])
print(r['summary'])
PY
```

FOR NEXT AGENT:

- Treat generated Pass 1 files as current ground truth until Deno is available.
- First runtime task is validating `run_all.ts` with Deno, not changing product scope.
- Keep updating all four handoff files after meaningful changes.

### Prior Swift App Task From Claude
Foundation is complete. Code type-checks cleanly. Next Swift app task:
1. **Install iOS Simulator Runtime** via Xcode → Settings → Components → iOS 26
2. Create simulator: `xcrun simctl create "iPhone 16 Pro" com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro`
3. Boot + build + install + launch
4. Fix any runtime issues

### Do not touch
- `project.yml` — xcodegen config, stable
- `Sources/mone/Models/*.swift` — all models correct
- `Sources/mone/Services/*.swift` — all calculators correct
- `Sources/mone/Design/Theme.swift` — design tokens, do not change color values

### Files to inspect first (in order)
1. `AGENT_HANDOFF.md` (this file)
2. `AGENT_TODO.md`
3. `Sources/mone/App/MoneApp.swift` — entry point + routing
4. `Sources/mone/ViewModels/AppViewModel.swift` — all state

### Next 3 steps
1. Open Xcode: `open mone.xcodeproj` → confirm it builds
2. Install iOS Simulator runtime from Xcode → Settings → Components
3. Boot simulator, build, and run

### Build verification (no simulator needed)
```bash
cd "/Users/sujaykumar/Documents/Assignment/CommerceIQ/moné"
SDK=$(xcrun --sdk iphonesimulator26.4 --show-sdk-path)
xcrun --sdk iphonesimulator26.4 swiftc \
  -sdk "$SDK" -target arm64-apple-ios17.0-simulator \
  -F "$SDK/System/Library/Frameworks" \
  -module-name mone -typecheck \
  $(find Sources/mone -name "*.swift" | tr '\n' ' ') 2>&1
# Expected: no output (zero errors)
```

### Build + run (once simulator runtime installed)
```bash
cd "/Users/sujaykumar/Documents/Assignment/CommerceIQ/moné"
# Create simulator
xcrun simctl create "iPhone 16 Pro" com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro

# Full build to simulator
xcodebuild -project mone.xcodeproj -scheme mone \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E '(error:|warning:|Build succeeded|BUILD FAILED)'
```

### Known risks
- `BuildingMoneyMapView.swift` uses `Animation.repeatWhile` custom extension — verify at runtime
- `@Observable` + `@Environment` pattern — requires iOS 17+, verify deployment target
- `Bindable(appVM).payMerchant` in PayView — requires @Observable ✅

---

## Project Context

| | |
|---|---|
| **App name** | moné (accent e) |
| **Platform** | iOS 17+ / SwiftUI |
| **Bundle ID** | com.mone.app |
| **Xcode project** | `mone.xcodeproj` (generated by xcodegen) |
| **Build tool** | xcodegen 2.45.4 |
| **Swift** | 5.9, STRICT_CONCURRENCY = minimal |
| **Design** | Dark editorial, monochrome, premium |
| **Stitch project** | `410508295000337477` |
| **Repo root** | `/Users/sujaykumar/Documents/Assignment/CommerceIQ/moné/` |

---

## Current Implementation State

### ✅ COMPLETE (33 Swift files, 0 compile errors)

#### Models
| File | Contents |
|------|----------|
| `Agenda.swift` | AgendaType, NudgeIntensity, StorageMode, SetupMethod |
| `MoneyMap.swift` | MoneyMap, IncomeSource, Obligation, SubscriptionItem, UpcomingItem |
| `Goal.swift` | Goal, GoalType, GoalPriority, GoalStatus (Equatable) |
| `Transaction.swift` | Transaction, TransactionCategory, TransactionType |
| `FinancialHealth.swift` | FinancialHealthReport, HealthSignal, HealthDimension, HealthStatus, Nudge, NudgeAction, InsightCardData |

#### Services
| File | Purpose |
|------|---------|
| `SafeToSpendCalculator.swift` | Weekly/daily/monthly budget + payment impact |
| `GoalProjectionCalculator.swift` | Projected completion, days delay, goal impact |
| `FinancialHealthCalculator.swift` | All 10 health dimension signals |
| `NudgeEngine.swift` | Intensity-aware nudge evaluation |
| `MockDataService.swift` | Full Aarav-profile mock data |

#### Design System
| File | Purpose |
|------|---------|
| `Theme.swift` | Color tokens, typography, spacing, radius, ContourBackground |
| `Components/Buttons.swift` | Primary/Secondary/Tertiary buttons, HealthChip, PriorityChip, FilterChip, NudgeActionButton |
| `Components/Cards.swift` | HeroCard, AgendaCard, InsightCard, ObligationRow, GoalCard, SetupOptionCard, UpcomingRow |

#### ViewModels
- `AppViewModel.swift` — @Observable, full onboarding state machine, pay evaluation, computed safe-to-spend

#### App Shell (`MoneApp.swift`)
- `@main MoneApp` entry point
- `RootView` (onboarding vs main tab routing)
- `MainTabView` with 5 tabs
- `AppTab` enum
- `MoneTabBar` custom dark tab bar
- `OnboardingFlow` dispatcher

#### Onboarding (9 screens complete)
- WelcomeView — animated brand intro + 3 value props
- DataPrivacyView — local vs encrypted backup
- AgendaSelectionView — primary agenda (3 options)
- SecondaryAgendaView — optional secondary agenda
- SetupMethodView — AA / Email / Manual
- AAConsentView — consent explainer
- BuildingMoneyMapView — animated progress simulation
- ConfirmFindingsView — review all found items
- GoalSetupView — goal list + impact preview

#### Main Tabs (5 tabs complete)
- DashboardView — adaptive dispatcher (3 variants)
- SpendingDashboardView — safe-to-spend hero + insights + obligations + goals
- GoalsDashboardView — goal health hero + all goals + scenario CTA
- FinancialPictureDashboardView — health summary + 10 signals + upcoming
- TransactionsView — filter chips + upcoming + past transactions
- PayView — QR scanner simulation + manual entry + nudge integration
- NudgeSheetView — full nudge with before/after + intensity control + actions
- GoalsView — goal cards + scenario check ("Can I afford this?")
- SetupView — agenda / money map / health / privacy / backup
- FinancialHealthDetailView — all 10 health signals in detail

### ⚠️ NOT YET DONE (see AGENT_TODO.md)
- Real simulator run (runtime not yet installed)
- App icon (placeholder only)
- Manual onboarding UI (chat-like cards) — currently stubs to buildingMoneyMap
- Email authorization screen — not built
- SwiftData/UserDefaults persistence (in-memory only)
- Scenario deep-link from Dashboard
- Animation polish pass

---

## Architecture

## 2026-05-19 06:05 IST — Dummy AA Aarav Flow Handoff

**Current status:** Branch `flow/agenda-first-dummy-aa-aarav` contains the agenda-first dummy AA flow wiring and uses the validated Aarav source bundle at `data/synthetic/output/aarav_spend_control_rash_decisions/`.

**What changed:**
- Added `SyntheticAAResponse` / `SyntheticSourceBundle` runtime provider model.
- Added phone mapping: `8828290489` → Aarav, `7304893952` → Priya-not-wired, all others unsupported.
- Added source-bundle loading for `raw_payload.json`, canonical CSVs, credit-card statement files, and `device_finance_source.json`.
- Added deterministic transformer from source bundle to `MoneyMap`, transactions, obligations, subscriptions, goals, upcoming items, and insights.
- Added agenda education, dummy AA consent, OTP, fetch/progress, processing, storage choice, and dashboard tour views.
- Updated onboarding state model to `agendaEducation`, `methodSelection`, `aaConsent`, `phoneOtp`, `aaFetching`, `processing`, `storageChoice`, `dashboardTour`, `complete`.
- Kept expected intelligence files out of runtime app code. Verified `Sources/mone` has no references to `ground_truth.json`, `*_expected.json`, `validation_report.json`, or `output_manifest.json`.

**What works:**
- Aarav dataset package validates: `validation_report.json` status `pass`, 137 checks, 0 failures, 1475 source transactions, financial health `Risk`.
- Runtime provider does not use raw holder identity for display; it uses phone mapping display name `Aarav`.
- Priya is not mapped to Aarav.
- Local-only storage can route to dashboard without forcing auth.
- Logout/delete account remain available in `SetupView`.

**Validation run:**
- `python3` read-back of the Aarav validation report: `pass`, `failed_check_count = 0`.
- Runtime grep confirmed no expected-intelligence filenames are referenced under `Sources/mone`.
- `plutil -lint mone.xcodeproj/project.pbxproj`: OK.
- `xcodebuild -derivedDataPath /private/tmp/mone-derived ...` reached SwiftPM dependency resolution but failed because the sandbox cannot write SwiftPM diagnostics under `/Users/sujaykumar/Library/Caches`.
- Xcode MCP `BuildProject` still appears to use a stale project model and reports missing newly added files until the IDE/project model is reloaded.

**Immediate next step:**
1. Reopen/reload the Xcode project so it picks up `mone.xcodeproj/project.pbxproj` target membership changes.
2. Build from Xcode or from an unrestricted terminal.
3. Fix any remaining Swift compile errors surfaced after SwiftPM dependencies resolve.

**FOR NEXT AGENT:**
- Do not regenerate Aarav data unless the user explicitly asks; the fixture is already validated.
- Do not wire Priya to Aarav data.
- Do not read expected intelligence files at runtime.
- If Xcode still cannot see the new files, inspect `mone.xcodeproj/project.pbxproj` before touching Swift logic.

---

```
Sources/mone/
├── App/
│   └── MoneApp.swift              ← @main, routing, tab bar, onboarding
├── Design/
│   ├── Theme.swift                ← ALL design tokens
│   └── Components/
│       ├── Buttons.swift          ← All button/chip styles
│       └── Cards.swift            ← All card components
├── Models/                        ← Pure structs, Codable
│   ├── Agenda.swift
│   ├── MoneyMap.swift
│   ├── Goal.swift
│   ├── Transaction.swift
│   └── FinancialHealth.swift
├── Services/                      ← Pure static functions, no state
│   ├── SafeToSpendCalculator.swift
│   ├── GoalProjectionCalculator.swift
│   ├── FinancialHealthCalculator.swift
│   ├── NudgeEngine.swift
│   └── MockDataService.swift
├── ViewModels/
│   └── AppViewModel.swift         ← Single @Observable source of truth
└── Views/
    ├── Onboarding/ (9 files)
    ├── Dashboard/  (4 files)
    ├── Transactions/ (1 file)
    ├── Pay/        (2 files)
    ├── Goals/      (1 file)
    └── Setup/      (1 file)
```

---

## Design Tokens

| Token | Value |
|-------|-------|
| Background | `#0D0D0F` (near-black) |
| Surface | `#141417` (dark charcoal) |
| Surface Elevated | `#1C1C20` |
| Surface High | `#242428` |
| Stroke | `white @ 7%` |
| Stroke Mid | `white @ 12%` |
| Stroke Bright | `white @ 20%` |
| Primary text | `#F0F0EB` (soft white) |
| Secondary text | `#8C8C92` (muted grey) |
| Tertiary text | `#5A5A60` (dimmer grey) |
| Healthy | `#3E7A54` (muted deep green) |
| Watch | `#8C6B2A` (muted amber) |
| Risk | `#8A3232` (muted red) |
| Action fill | `#E8E8E0` (off-white pill) |
| Card radius | 24px (xxl) |
| Page margin | 20px |

---

## Mock Data (Aarav profile)

| Item | Value |
|------|-------|
| Monthly income | ₹1,82,000 salary + ₹24,000 freelance |
| Rent | ₹42,000 on 5th |
| Home Loan EMI | ₹18,400 on 7th |
| SIP | ₹15,000 on 10th |
| Health Insurance | ₹3,200 |
| Credit Card due | ₹28,400 in 5 days |
| Subscriptions | Netflix ₹649, iCloud ₹199, Spotify ₹119 |
| Goals | Emergency Fund (60%), Vacation–Bali (25%), Laptop (35%) |
| Safe-to-spend | ~₹63,000/month after all commitments |
| Obligation load | ~48% of income |

---

## Stitch MCP Assets
- **Project ID:** `410508295000337477`
- **35+ screens** available as HTML via `mcp__stitch__get_screen`
- **Key screens:** Dashboard (Premium), Meet moné (Dark), Pay with Pause, Confirm Findings (Premium)
- **Design system:** Full design.md with Hanken Grotesk + Geist tokens
- **Color note:** Stitch uses light theme — moné app uses dark override
## Priya Fixture Status

Final status: Priya fixture generated and validation passed.

Dataset:

```text
priya_goal_planner_responsibility_burden
```

Commands:

```bash
python3 data/synthetic/src/run_all.py --dataset priya_goal_planner_responsibility_burden --seed mone-priya-responsibility-burden-v3
python3 data/synthetic/src/validate_against_ground_truth.py --dataset priya_goal_planner_responsibility_burden
```

Latest v3 validation summary:

- total files: 22
- total transactions: 497
- deposit transactions: 458
- asset transactions: 39
- card statement cycles: 14
- missing card statement cycle count: 0
- local micro-UPI count: 254
- cash withdrawal count: 20
- self-transfer count: 15
- parents support count: 13
- sibling support count: 4
- education-loan EMI count: 12
- healthcare spend count: 26
- goal count: 6
- nudge candidates: 324
- interrupt nudges: 6
- safe-to-spend risk/watch/healthy months: 4/6/2
- final net worth: 2223234.0
- final liquid net worth: 232934.0
- overall financial health: Watch
- failed checks: 0
- final artifact polish checks passed: manifest status matches validation report, manifest failed-check count matches validation report, card source narrations are merchant-like, and source card narrations do not leak ground-truth semantics.
- final targeted polish checks passed: manifest-status diagnostic payloads now show current `pass` / `0` values, and deposit transaction modes match UPI/FT/NACH/CARD/ATM narration prefixes.
- validation checks: 110

Clean packaging command:

```bash
cd data/synthetic/output
zip -r -X priya_goal_planner_responsibility_burden.zip priya_goal_planner_responsibility_burden
```

FOR NEXT AGENT:

- Use Priya as the responsibility-burden / goal-planning fixture.
- Use Aarav as the risky UPI/card-pressure fixture.
- Runtime app code must ingest source-layer files only, not expected oracle files.
- Both final raw AA-style fixtures have been hardened for future Money Map and Dashboard inference. Raw evidence now includes LPG, rent components, variable utilities, internet/mobile topups, EMI/loan extra payments, fund topups, vehicle service/repair, annual renewals, and ambiguous needs-review signals.
- Latest validation: Priya `pass` · 590 transactions · health `Watch`; Aarav `pass` · 1607 transactions · 162 checks · health `Risk`.
