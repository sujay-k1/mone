# AGENT DECISIONS — moné

> Implementation decisions log. Each entry has: date, decision, reason, alternatives considered.

---

## 2026-05-17

### D001 — Dark-first design (overrides Stitch light system)
**Decision:** Implement a dark editorial theme (#0D0D0F background) rather than the light theme exported by Stitch.  
**Reason:** The product brief explicitly specifies "dark editorial, monochrome, premium — black/near-black backgrounds, charcoal cards, graphite surfaces." Stitch generated a light variant as default but also produced "(Dark)" and "(Premium)" screen variants as the reference. The brief overrides the Stitch default.  
**Alternatives considered:** Use Stitch light theme with colorScheme(.dark) overlay — rejected because automatic color inversion produces incorrect results.

---

### D002 — @Observable over ObservableObject
**Decision:** Use `@Observable` macro (iOS 17+) instead of `ObservableObject`/`@Published`.  
**Reason:** Target is iOS 17+. `@Observable` is cleaner, eliminates `@StateObject`/`@EnvironmentObject` verbosity, and is the modern SwiftUI pattern. All view references use `@Environment(AppViewModel.self)`.  
**Alternatives considered:** ObservableObject — rejected as legacy pattern for iOS 17 target.

---

### D003 — Single AppViewModel as source of truth
**Decision:** All state lives in `AppViewModel`. Views read via `@Environment(AppViewModel.self)`.  
**Reason:** For an MVP prototype, a single observable is simpler to reason about, easier to hand off to another agent, and avoids prop-drilling. The `AppViewModel` exposes computed properties that delegate to pure service structs.  
**Alternatives considered:** Multiple view-specific ViewModels — rejected as over-engineering for MVP; can refactor later if needed.

---

### D004 — Pure static services (no class instances)
**Decision:** All calculation services (`SafeToSpendCalculator`, `FinancialHealthCalculator`, etc.) are value types with static methods.  
**Reason:** Keeps logic portable, testable, and free of state. No threading concerns. Easy to port to Android later.  
**Alternatives considered:** Service singletons — rejected as unnecessary for stateless calculators.

---

### D005 — In-memory state only (no SwiftData/UserDefaults yet)
**Decision:** AppViewModel state is in-memory. No persistence layer for MVP v1.  
**Reason:** Get the experience right first. Persistence can be layered on later without changing the view layer. For prototype demos, in-memory state is sufficient.  
**Alternatives considered:** SwiftData from day 1 — deferred to avoid migration complexity during active development.

---

### D006 — Simulated integrations for AA / Email / UPI
**Decision:** All third-party integrations (Account Aggregator, Email OAuth, UPI) are simulated in the prototype.  
**Reason:** No Setu credentials in repo. iOS restrictions prevent SMS reading. Real AA/email integrations require backend relay which is out of MVP scope. Product says "simulate if real credentials not present."  
**Alternatives considered:** Real Setu sandbox — deferred; implement if credentials are provided.

---

### D007 — xcodegen for project management
**Decision:** Use `xcodegen` + `project.yml` rather than checked-in `.xcodeproj`.  
**Reason:** Cleaner git history, easier for Codex/Claude agents to add files without `.xcodeproj` XML conflicts. xcodegen regenerates the project from YAML.  
**Alternatives considered:** Committed .xcodeproj — rejected due to merge conflicts and opaque XML.

---

### D008 — Custom tab bar (no UITabBarController)
**Decision:** Implement custom `MoneTabBar` in SwiftUI rather than using system `TabView`.  
**Reason:** The dark editorial design requires precise control over tab bar appearance. System tab bar doesn't support the elevated "Pay" button treatment or the exact dark surface color. Custom approach is fully controllable.  
**Alternatives considered:** `TabView` with `.toolbarBackground` — rejected because UITabBar.appearance() hacks are fragile.

---

### D009 — SWIFT_STRICT_CONCURRENCY = minimal
**Decision:** Set strict concurrency checking to minimal.  
**Reason:** MVP prototype speed > correctness. The app is single-threaded (main actor) for all UI state. Strict concurrency would require extensive `@MainActor` annotations throughout with no current benefit.  
**Alternatives considered:** Full strict mode — deferred to production hardening phase.

---

### D010 — GoalStatus as Equatable enum with associated values
**Decision:** `GoalStatus` conforms to `Equatable` by having `atRisk(daysDelay: Int)` which automatically gets synthesized Equatable.  
**Reason:** Views need to compare `status == .onTrack`. Swift synthesizes Equatable for enums with associated values when the value type is also Equatable (Int is).  
**Alternatives considered:** Computed `isAtRisk` Bool property only — kept both for flexibility.

---

### D011 — Mock data profile: Aarav (27-year-old software developer)
**Decision:** Default mock data reflects Aarav's profile (₹1,82,000 salary, high discretionary spending, credit card discipline issues, vacation goal).  
**Reason:** Product brief defines two personas. Aarav's profile demonstrates safe-to-spend (primary use case) and nudge behavior most effectively for demos.  
**Alternatives considered:** Priya's profile (goals-heavy) — can be a secondary test case.

---

### D012 — Deploy target iOS 17 (not iOS 18+)
**Decision:** Deployment target is iOS 17.0.  
**Reason:** `@Observable` arrived in iOS 17. Wide enough device coverage. iOS 18 features not required.  
**Alternatives considered:** iOS 16 — rejected because `@Observable` not available; iOS 18 — rejected for narrower coverage.

---

## 2026-05-18

### D013 — Keep TypeScript/Deno as synthetic-data implementation target
**Decision:** Continue the synthetic data generator in TypeScript/Deno rather than switching the repo implementation to Python.  
**Reason:** Existing backend and Claude's partial synthetic work are TypeScript-shaped, and docs already specify TypeScript/Deno.  
**Alternatives considered:** Convert generator to Python — rejected because it would restart strategy and diverge from the existing backend direction.

### D014 — Use Python only as a local execution fallback for Pass 1 artifacts
**Decision:** Generate the current Pass 1 output files with the local Xcode Python runtime because `deno` was unavailable and network Deno download attempts hung.  
**Reason:** The user requested a complete Pass 1 output set. Producing artifacts was more useful than leaving implementation code only.  
**Alternatives considered:** Keep attempting network install — rejected after two interrupted hangs; stop without outputs — rejected because Pass 1 requires generated files.

### D015 — Limit Pass 1 to Aarav normal deposit-only
**Decision:** Do not implement Priya, MF, RD, TD, insurance, equities, NPS, or GSTR in this pass.  
**Reason:** User explicitly constrained scope to the smallest complete working Pass 1: Aarav normal deposit-only with AA payload, ground truth, CSVs, expected candidates, and validation report.  
**Alternatives considered:** Opportunistically add other account types — rejected as scope creep.

### D016 — Keep `aarav_spend_control_normal` dataset name
**Decision:** Keep the current dataset ID as `aarav_spend_control_normal` instead of renaming it to `aarav_spend_control_high_leakage`.  
**Reason:** Frequent UPI, food delivery, cabs, weekend social spend, and small-spend leakage are Aarav's baseline normal persona behavior, not a separate variant. The future high-leakage/lifestyle-creep variant should be introduced as a distinct later dataset only if behavior is deliberately intensified beyond this baseline.  
**Alternatives considered:** Rename current output to `aarav_spend_control_high_leakage` — rejected because it would break the Pass 1 contract and blur the distinction between normal baseline and later variants.

### D017 — Opening balance policy for Aarav normal output
**Decision:** Use a synthetic opening deposit balance of `₹150,000` for the generated Aarav Pass 1 package.  
**Reason:** The previous `₹45,000` opening balance caused the account to go negative before the first salary in the period, which is invalid for the normal deposit account policy. The higher opening balance represents cash carried forward from the prior salary cycle and keeps all generated balances non-negative.  
**Alternatives considered:** Reduce early-month spending — rejected because it would alter the behavioral pattern more than necessary; allow negative balance — rejected for normal savings-account output correctness.

---

## 2026-05-19

### D018 — Add Aarav rash-decisions fixture as separate dataset
**Decision:** Create `aarav_spend_control_rash_decisions` as a new dataset beside `aarav_spend_control_normal`.  
**Reason:** The normal fixture is accepted as a clean baseline. The product also needs a stronger Aarav demo where high income is undermined by rash spending, irregular SIPs, asset withdrawals, credit-card stress, safe-to-spend risk, and goal drift.  
**Alternatives considered:** Modify `aarav_spend_control_normal` — rejected because it would destroy the accepted baseline.

### D019 — Include MF/RD/TD only for rash variant
**Decision:** Generate `deposit`, `mutual_funds`, `recurring_deposit`, and `term_deposit` FI payloads for the rash dataset, while leaving Priya, insurance, equities, NPS, and GSTR out.  
**Reason:** These FI types are necessary to model SIP purchases, MF redemption, RD breakage, and TD premature withdrawal without expanding into unrelated future scope.  
**Alternatives considered:** Deposit-only rash dataset — rejected because it cannot validate linked asset/cash rescue behavior; add all FI types — rejected as scope creep.

### D020 — Opening balance policy for Aarav rash-decisions output
**Decision:** Use a synthetic opening deposit balance of `₹390,000` for `aarav_spend_control_rash_decisions`.  
**Reason:** The rash fixture needs severe spending while avoiding unintentional overdraft because facility is `NONE`. After the final credit-card and EMI additions, `₹390,000` produces a low but positive minimum deposit balance of `₹12,191`, matching the requested stressed-but-not-bankrupt behavior.  
**Alternatives considered:** Use OD facility — rejected because the user preferred facility `NONE`; reduce rash behavior — rejected because this fixture is meant to be the strongest Aarav spend-control demo; keep `₹360,000` — rejected because final-polish EMI debits pushed the account negative.

### D021 — Asset account value convention
**Decision:** Keep `closing_balance` for backward compatibility and add `current_value`, `opening_value`, `liquidity_class`, and `balance_role` to `accounts.csv`. For asset FI rows, `closing_balance` equals `current_value`.  
**Reason:** Downstream readers can still use the old column while correctly distinguishing liquid cash from market-linked, semi-locked, and locked asset values.  
**Alternatives considered:** Leave asset `closing_balance` blank — rejected because it would be less compatible with existing CSV readers.

### D022 — Avoid asset opening transaction double counting
**Decision:** Do not emit an explicit TD opening credit transaction when TD principal/opening value is already represented in summary and `accounts.csv`.  
**Reason:** Having both principal in account summary and an opening credit transaction can make downstream parsers double count asset value.  
**Alternatives considered:** Keep the opening transaction and validate it as a special case — rejected because avoiding the ambiguity is cleaner for fixture quality.

### D023 — Keep credit-card behavior in separate statement source files
**Decision:** Add `credit_card_statement.json`, `credit_card_transactions.csv`, and `credit_card_summary.csv` instead of adding a speculative AA `credit_card` FI type.  
**Reason:** The existing AA generator cleanly supports deposit and asset FI types. Separate statement files model card cycles, utilization, due dates, partial payment, interest, and late fees without pretending to know the exact AA credit-card schema.  
**Alternatives considered:** Add `credit_card` to raw AA payload — deferred until the source schema is intentionally designed.

### D024 — Enforce source vs expected-intelligence separation
**Decision:** Keep raw AA-like payload and canonical source CSVs free of expected/nudge intelligence fields; hidden labels live in `ground_truth.json` and `*_expected.json`.  
**Reason:** Moné should infer nudges, goal drift, health, safe-to-spend, and confirmation prompts from source facts. Source fixtures should not leak test answers into app-consumable inputs.  
**Alternatives considered:** Keep classification-heavy `transactions.csv` — rejected for final fixture quality because it blurs app input and validation truth.

### D025 — Model EMI as expected intelligence with source links
**Decision:** Add `emi_candidates_expected.json` with card EMI and device EMI candidates, linked to source purchases, statements, and deposit payments where applicable.  
**Reason:** EMI pressure is part of Moné's expected intelligence layer, but the source layer must still contain enough facts to reconcile statement cycles and deposit payments.  
**Alternatives considered:** Treat EMI installments as ordinary discretionary spending — rejected because installments are debt commitments after conversion.

### D026 — Keep source files free of Moné taxonomy
**Decision:** Remove Moné taxonomy from app-facing source files. `transactions.csv`, `accounts.csv`, `monthly_cashflow.csv`, card statement source files, and device finance source should not contain `category`, `sub_category`, `is_*` inference flags, nudge fields, or user-facing copy.  
**Reason:** Real AA and statement sources do not carry Moné's intelligence taxonomy. Future parser tests must infer taxonomy from source facts instead of reading fixture answers.  
**Alternatives considered:** Keep category-like source columns for convenience — rejected because it pollutes source data and weakens the fixture as a future standard.

### D027 — Move user-facing nudge copy to `nudge_expected.json`
**Decision:** Store expected nudge copy and suppression reasons in `nudge_expected.json`, while ground truth keeps compact expected nudge metadata.  
**Reason:** User-facing copy is expected intelligence, not source data. Separating it keeps source clean and makes interrupt-copy validation explicit.  
**Alternatives considered:** Keep copy in `ground_truth.json` — acceptable but less clean; rejected for the final Aarav template.

### D028 — Add device finance source for Bajaj EMI provenance
**Decision:** Add `device_finance_source.json` for the Bajaj/device EMI original purchase and financed schedule.  
**Reason:** The device EMI expected candidate referenced `device_purchase_20251105`; the source layer needed a real statement-like purchase/finance record for that ID.  
**Alternatives considered:** Add the purchase to credit-card statement — rejected because this was modeled as lender/device finance, not a card-financed purchase.

### D029 — Model term deposit premature closure as fully closed
**Decision:** Set the term deposit current value to `₹0`, closure payout to `₹112,000`, and penalty/adjustment to `₹8,000`.  
**Reason:** A `PREMATURE_CLOSED` TD with `₹8,000` current value was ambiguous. Fully closed semantics are clearer and reconcile with the deposit payout.  
**Alternatives considered:** Keep `₹8,000` as residual value — rejected because it required additional interpretation and could be double counted.

### D030 — Add deterministic Python regeneration path for Aarav rash fixture
**Decision:** Add `data/synthetic/src/rash_final_generator.py`, `run_all.py`, and `validate_against_ground_truth.py` as the deterministic regeneration path for `aarav_spend_control_rash_decisions` using seed `mone-aarav-rash-decisions-final-v1`.  
**Reason:** The existing Deno/TypeScript runner supports only `aarav_spend_control_normal`, and Deno is not available in this environment. The rash package needed a single atomic generator, strict validator, and output manifest to prevent mixed stale files.  
**Alternatives considered:** Continue patching output files — rejected by the final-fix requirement; wait for Deno install — rejected because previous network installs hung and the fixture needed to be finalized now.

### D031 — Use validated synthetic source bundle as dummy AA app input
**Decision:** Runtime dummy AA loads only Aarav source-layer files from `data/synthetic/output/aarav_spend_control_rash_decisions` and exposes them through a `SyntheticAAResponse` with `aaPayload` plus sidecar `sourceBundle`.
**Reason:** `raw_payload.json` alone omits credit-card statement cycles and Bajaj/device finance context. The provider needs the full source bundle while keeping expected intelligence files out of app runtime.
**Alternatives considered:** Load only `raw_payload.json` — rejected because card utilization, late fee, partial payment, and device EMI would be invisible; load expected JSON directly — rejected because it leaks test-oracle intelligence into the product.

### D032 — Keep Priya phone mapped but not wired
**Decision:** `7304893952` returns a Priya-not-wired demo state instead of falling back to Aarav or fake Priya data.
**Reason:** Priya's fixture is not present in the package. Mapping Priya to Aarav would corrupt persona behavior and demo credibility.
**Alternatives considered:** Reuse Aarav data — explicitly rejected by prompt; create a quick Priya stub — rejected because the user asked not to add Priya yet.

### D033 — OTP provider abstraction with explicit dev simulator
**Decision:** Phone verification uses a `PhoneOTPProviding` abstraction. Supabase remains the real provider; `DevPhoneOTPProvider` accepts `000000` only when `MONE_DEV_OTP_ENABLED=1`.
**Reason:** This preserves existing auth infrastructure and avoids committing credentials while allowing a deliberate local demo fallback.
**Alternatives considered:** Hardcode OTP bypass — rejected as unsafe; add 2Factor keys — rejected because no API keys should be committed.

### D034 — Recompute deposit running balances after chronological merge
**Decision:** Recompute deposit `balance_after` and raw payload `currentBalance` after all deposit substreams are generated, merged, and sorted chronologically.
**Reason:** Monthly cashflow can reconcile even when transaction-level balances were calculated in separate substreams. The fixture needs ledger-grade chronological balances so downstream demos do not inherit balance artifacts.
**Alternatives considered:** Mark transaction-level balances low-trust — rejected because the chronological recompute is straightforward and now validated.

### D035 — Keep source narrations bank-like and taxonomy-free
**Decision:** Replace behavioral source narration text with bank-like merchant/payment-rail strings and keep behavioral labels only in ground truth and expected outputs.
**Reason:** Real AA/statement source data should not say `impulse`, `rash`, `weekday_coffee`, or `spontaneous_trip`. Those are Moné inference targets, not app-input source facts.
**Alternatives considered:** Allow descriptive synthetic narrations for readability — rejected because it leaks validation truth into source data.

### D036 — Add explicit demo identity map and dataset registry
**Decision:** Generate `data/synthetic/output/demo_identity_map.json` and `data/synthetic/output/dataset_registry.json` outside the Aarav dataset folder.
**Reason:** Demo authentication identity must come from phone mapping, not synthetic AA holder profile. Priya must remain not wired until her dataset exists.
**Alternatives considered:** Infer identity from raw holder profile — rejected because it could expose synthetic placeholders and confuse source data with authenticated demo identity.

### D037 — Mark credit-card source as scenario-grade
**Decision:** Keep the current hybrid credit-card source model but explicitly mark it scenario-grade and not production accounting.
**Reason:** It is useful for Moné stress interpretation, utilization, payment status, late fee, interest, and EMI pressure, but it is not a complete issuer-grade statement ledger.
**Alternatives considered:** Build a full production card ledger now — rejected as out of scope for the final Aarav fixture pass.

### D038 — Make Aarav rash package self-contained
**Decision:** Include `demo_identity_map.json` and `dataset_registry.json` inside `aarav_spend_control_rash_decisions/`, while still writing shared root copies.
**Reason:** The uploaded package/ZIP should be independently usable without depending on adjacent root output files. Shared root copies remain convenient for app/provider lookup.
**Alternatives considered:** Keep identity/registry only at output root — rejected because it made the dataset package incomplete when zipped.

### D039 — Use statement-only-paid semantics for paid card EMI rows
**Decision:** Paid card EMI schedule rows without separate deposit payment rows are marked with `payment_source: statement_only_paid`, `cashflow_link_status: not_linked_scenario_grade`, and a reason.
**Reason:** This preserves the scenario-grade credit-card model without leaving blank cash links ambiguous or pretending to have issuer-grade bank linkage.
**Alternatives considered:** Add separate deposit payment rows for every paid card EMI installment — rejected because it would disrupt the current hybrid card-cashflow convention.

### D040 — Tune Aarav to buffered but cash-pressured
**Decision:** Set deposit opening balance to `₹190,000` and add a realistic annual tax-payment debit so the final minimum balance is `₹62,049.00` and closing balance is `₹375,741.00`.
**Reason:** Aarav should remain financially Risk with meaningful cash pressure, but not bankrupt or overdrafted.
**Alternatives considered:** Keep the prior higher cash balances — rejected because the story read as too cash-rich for the strongest spend-control demo.

### D041 — Add local micro-UPI noise as reusable persona module
**Decision:** Add a local micro-UPI generator for Aarav with 25-55 messy UPI transactions per month, using bank-like source narrations and hidden ground-truth labels.
**Reason:** Aarav is the Pay with Pause / UPI interruption persona. The fixture needs realistic small local spends, QR strings, person payees, truncated merchants, and ambiguous cases without leaking taxonomy into source files.
**Alternatives considered:** Keep only platform spends like Swiggy/Uber/coffee — rejected because it misses the messy Indian UPI behavior Moné must handle.

### D042 — Add low/risk net worth expected output
**Decision:** Generate `net_worth_expected.json` and tune final net worth to `₹108,600.00` with liquid net worth `-₹61,400.00`.
**Reason:** Aarav should earn well but have weak financial position after liquidity rescues, broken deposits, card outstanding, and EMI pressure.
**Alternatives considered:** Leave net worth implicit in source assets — rejected because Priya’s template needs an explicit expected net-worth oracle for future parser validation.
## Priya Fixture Decisions

- Priya is modeled as `Watch`, not `Healthy` and not Aarav-style reckless Risk.
- Education loan is treated as responsible debt burden: recurring, EMI, must-pay, and safe-to-spend reducing.
- Local UPI exists for realism but remains less dense and less chaotic than Aarav.
- Cash withdrawals are blindspots and summary/dashboard signals, not frequent interrupts.
- Credit card remains scenario-grade statement source, not production accounting truth.
- Priya demo identity comes from phone mapping, not raw AA holder profile.
- Priya v2 card statement cycles are continuous from 2025-06 through 2026-07 so every transaction and EMI schedule reference resolves.
- Priya source narrations intentionally use bank-like names such as `MOM HDFC`, `PAPA SBI`, `ANIKET ICICI`, and own-account transfer strings; responsibility semantics stay in ground truth.
- Priya v3 treats `actual_safe_to_spend_after_period` as canonical monthly capacity; status must match that numeric meaning.
- Priya deposit cashflow rows must keep mode/narration prefixes coherent for UPI, FT, NACH/ECS/ACH, CARD, and ATM. Asset FI statement rows may keep source-specific prefixes such as `RD/` and `MF/`.
- Money Map readiness is handled by enriching raw evidence, not by adding source-layer taxonomy. LPG, rent components, variable utilities, topups, subscriptions, EMI extras, fund topups, vehicle service, annual renewals, and ambiguous review signals stay as bank-like narrations; derived Money Map groups must be inferred later.
