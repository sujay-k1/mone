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
