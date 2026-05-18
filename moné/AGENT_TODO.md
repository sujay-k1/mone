# AGENT TODO — moné

> Updated: 2026-05-17

---

## 🔴 NOW (Immediate)

- [ ] **Install iOS Simulator Runtime** — Open Xcode → Settings → Components → Download iOS 26 Simulator
- [ ] **Create + boot simulator** — `xcrun simctl create "iPhone 16 Pro" ...`
- [ ] **Full xcodebuild run** — verify no runtime errors
- [ ] **Fix launch screen** — Info.plist references `LaunchBackground` color asset that doesn't exist yet
- [ ] **Add app icon** — currently placeholder, needs at least a simple dark icon for prototype

---

## 🟡 NEXT (This session)

- [ ] **Manual onboarding flow** — `SetupMethodView` routes to `buildingMoneyMap` when manual is selected, but there's no actual conversational UI yet. Build a chat-like card system with chips (Salary, Rent, EMI, SIP, etc.)
- [ ] **Email setup flow** — `AAConsentView`-style explainer for email, then mock "processing"
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
