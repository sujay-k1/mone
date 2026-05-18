# HANDOFF.md — Post-Auth Routing & Profile Onboarding

## What was implemented

### Phase 1: Auth (unchanged)
A polished passwordless OTP authentication flow (email + mobile) integrated with the dark "Financial Noir" design system. Both email and phone OTP use real Supabase Auth calls.

### Phase 2: Post-Auth Routing & Profile (new)
Session-based app routing with profile management. On launch, the app checks for an existing Supabase session, loads the user's profile from `public.profiles`, and routes accordingly.

#### Routing logic
1. **App launches** → check `supabase.auth.currentSession`
2. **No session** → Auth screens (phone entry by default)
3. **Session exists** → fetch profile from `public.profiles`
4. **No profile or missing name** → Name Onboarding screen
5. **Profile complete** (`onboarding_completed = true`) → Dashboard

#### New screens
- **Name Onboarding** — top bar with back arrow + centered "moné", serif heading "What should we call you?", subtitle, underline-style full name input, "Let's go" CTA. Validates minimum 2 characters. Back button signs out and returns to auth.
- **Post-Auth Dashboard** — greeting using first name, "Log out" button, "Delete account" button with confirmation dialog. Delete shows placeholder message (backend not connected).

#### Session behavior
- Session persists across app relaunch via Supabase Keychain storage
- Sign out clears session and routes to auth
- After OTP verification, "Continue to moné" triggers profile loading (not onboarding advancement)
- AuthView supports standalone mode (no back button) via `showBackButton` parameter

### Auth screens
- **Phone Entry** — Indian mobile number input (+91), 10-digit validation, "Get OTP" CTA, "Use email instead"
- **Email Entry** — email input with validation, "Continue" CTA, "Use mobile number instead"
- **OTP Verification** — shared 6-digit code entry, resend support
- **Signed In** — confirmation screen with checkmark, "Continue to moné" CTA

### Auth flow
- **Email OTP**: `supabase.auth.signInWithOTP(email:)` → `supabase.auth.verifyOTP(email:token:type:.email)`
- **Phone OTP**: `supabase.auth.signInWithOTP(phone:)` → `supabase.auth.verifyOTP(phone:token:type:.sms)`
- Phone numbers formatted as E.164: `+91XXXXXXXXXX`
- Supabase Send SMS Hook triggers the Edge Function which sends OTP via 2Factor

## Database assumptions

The app expects a `public.profiles` table:

```sql
create table public.profiles (
  id uuid primary key references auth.users(id),
  full_name text,
  onboarding_step text,
  onboarding_completed boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- RLS: users can only access their own profile
alter table public.profiles enable row level security;

create policy "Users can view own profile" on public.profiles
  for select using (auth.uid() = id);

create policy "Users can insert own profile" on public.profiles
  for insert with check (auth.uid() = id);

create policy "Users can update own profile" on public.profiles
  for update using (auth.uid() = id);
```

The app uses **upsert** to create or update the profile row when saving the name.

## Files changed

| File | Change |
|------|--------|
| `Sources/mone/Models/Profile.swift` | **New** — `Profile` (Codable) and `ProfileUpsert` (Encodable) structs with snake_case CodingKeys |
| `Sources/mone/ViewModels/SessionViewModel.swift` | **New** — `SessionViewModel` with Route enum, session checking, profile loading, name saving, sign out, delete account placeholder |
| `Sources/mone/Views/Onboarding/NameOnboardingView.swift` | **New** — Name entry screen matching Financial Noir design |
| `Sources/mone/App/MoneApp.swift` | **Modified** — `RootView` uses `SessionViewModel` for routing; added `PostAuthDashboardView` |
| `Sources/mone/Views/Onboarding/AuthView.swift` | **Modified** — Added `onAuthComplete`/`showBackButton` params; fixed email placeholder color; `PhoneEntryScreen.onBack` now optional |

## Current routing behavior

```
SessionViewModel.Route:
  .loading        → ProgressView (checking session)
  .auth           → AuthView (standalone, no back button)
  .nameOnboarding → NameOnboardingView
  .dashboard      → PostAuthDashboardView (greeting + logout + delete)
```

The existing `OnboardingFlow` and `MainTabView` remain in the codebase but are not routed to currently. They will be wired up when the full app flow is connected to Supabase data.

## Manual test checklist

1. Fresh install, no session → auth screen (phone entry)
2. Login with email/mobile OTP as new user → name onboarding screen
3. Enter name (≥2 chars) → dashboard with greeting
4. Kill and relaunch app → dashboard (session persisted)
5. Tap log out → auth screen
6. Login again as same user → dashboard (not name screen)
7. Set `onboarding_completed = false` in Supabase → app routes to name onboarding
8. Delete account button → shows confirmation dialog → shows "not connected" message

## What is intentionally still pending

- **Delete account Edge Function** — UI and confirmation dialog exist; backend function not yet created
- **Full onboarding flow** — Welcome, data privacy, agenda selection, setup method screens exist but are bypassed by session routing
- **Full dashboard** — `MainTabView` with financial dashboard, transactions, pay, goals, setup tabs exists but is not routed to yet
- **Profile fields** — Only `full_name` and `onboarding_completed` are used; `onboarding_step` is set but not used for routing yet

## Next steps

1. Implement `delete-account` Edge Function (uses service_role key server-side)
2. Wire full onboarding steps to profile `onboarding_step` field
3. Replace `PostAuthDashboardView` with `MainTabView` when ready
4. Store user preferences (agenda, storage mode, etc.) in profile

---

## 2026-05-18 Codex update — Delete Account iOS wiring in progress

### What changed
- Added `SupabaseConfig` in `SupabaseClient.swift` so the iOS app can reuse the same Supabase URL/publishable key source of truth.
- Replaced `SessionViewModel.deleteAccount()` placeholder with an async URLSession POST to the Supabase Edge Function `delete-account`.
- The iOS request uses only the current session access token as `Authorization: Bearer <token>` and an empty JSON body. No service-role/admin secrets were added to the client.
- On successful 2xx response, the app attempts local `supabase.auth.signOut()`, clears in-memory profile/returning-user state, and routes to `.auth`.
- On failure, the app leaves the user in place and shows concise user-facing errors without exposing backend details.

### Files modified
- `SupabaseClient.swift`
- `Sources/mone/ViewModels/SessionViewModel.swift`
- `HANDOFF.md`

### Current working state
- UI call sites still need to be updated to await the new async `deleteAccount()` method and use the requested confirmation copy/loading disabled states.
- Build has not been run yet after this checkpoint.

### Assumptions
- `supabase.auth.currentSession?.accessToken` is available from the installed Supabase Swift SDK.
- Routing to `.auth` after deletion is acceptable because the current task explicitly asks to return the user to the auth screen.

### Unresolved issues
- Need to update `SetupMethodView` three-dot Delete Account action and the temporary `PostAuthDashboardView` placeholder action.
- Need to verify build.

### Next recommended step
- Update both existing Delete Account UI call sites to call `Task { await sessionVM.deleteAccount() }` after native confirmation.

---

## 2026-05-18 Codex update — Delete Account UI call sites wired

### What changed
- Wired the existing `SetupMethodView` three-dot menu Delete Account action to the real async `SessionViewModel.deleteAccount()` flow.
- Updated `SetupMethodView` confirmation alert copy to:
  - Title: `Delete account?`
  - Message: `This will permanently delete your Moné account and profile data. This cannot be undone.`
  - Confirm: `Delete account`
  - Cancel: `Cancel`
- Added a deletion loading state to the `SetupMethodView` menu label and disabled the menu/delete actions while deletion is in progress.
- Added inline premium-styled error text in `SetupMethodView` using `Color.moneRisk`.
- Also updated the temporary `PostAuthDashboardView` Delete Account placeholder to use the same real async method, exact confirmation copy, loading text, and disabled state.

### Files modified
- `Sources/mone/App/MoneApp.swift`
- `Sources/mone/Views/Onboarding/SetupMethodView.swift`
- `HANDOFF.md`

### Current working state
- The real backend call is wired at the known current entry point: `SetupMethodView` → three-dot menu → Delete account.
- The remaining temporary delete action in `PostAuthDashboardView` is also wired; no placeholder `deleteAccount()` implementation remains.
- Build has not been run yet after this checkpoint.

### Assumptions
- Native SwiftUI `alert` is acceptable for destructive confirmation.
- The temporary `PostAuthDashboardView` still exists because current routing sends completed users there; keeping its existing Delete Account action wired avoids leaving a reachable placeholder.

### Unresolved issues
- Need to build and resolve any Supabase Swift SDK/API compile issues, especially `Session.accessToken`.

### Next recommended step
- Run Xcode diagnostics/build, then update this handoff with build result and manual Supabase verification checklist.

---

## 2026-05-18 Codex final update — Delete Account flow complete on iOS

### What changed
- Real Delete Account flow is now wired in the iOS app.
- The known current entry point remains unchanged: `SetupMethodView` → three-dot menu → `Delete account`.
- The three-dot menu action now shows a destructive native SwiftUI alert before deletion and only calls the backend after the user confirms.
- Confirmation copy is exactly:
  - Title: `Delete account?`
  - Message: `This will permanently delete your Moné account and profile data. This cannot be undone.`
  - Confirm button: `Delete account`
  - Cancel button: `Cancel`
- `SessionViewModel.deleteAccount()` now:
  - reads the current Supabase session
  - sends `POST https://<project-ref>.supabase.co/functions/v1/delete-account`
  - includes `Authorization: Bearer <current_access_token>`
  - sends `Content-Type: application/json`
  - sends `{}` as the request body
  - uses `URLSession`, not Supabase Admin APIs
  - clears local Supabase session/profile state on success
  - routes to `.auth` on success
  - keeps the user in place and shows a concise error on failure
- Added `isDeletingAccount` loading state and disabled delete controls while deletion is in progress.
- The temporary `PostAuthDashboardView` Delete Account action was also wired to the same real flow because current routing still sends completed users there. This avoids leaving a reachable placeholder.
- No service-role key, database password, 2Factor key, hook secret, or backend secret was added to the iOS client.

### Files modified
- `SupabaseClient.swift`
- `Sources/mone/ViewModels/SessionViewModel.swift`
- `Sources/mone/App/MoneApp.swift`
- `Sources/mone/Views/Onboarding/SetupMethodView.swift`
- `HANDOFF.md`

### Backend function status
- `delete-account` Edge Function exists in the repo at:
  - `mone-backend/supabase/functions/delete-account/index.ts`
- It uses a server-side Supabase admin client and expects the service-role/secret key from Edge Function environment variables, not from iOS.
- Deploy command when Supabase CLI is configured:
  - `supabase functions deploy delete-account --project-ref bvgswlacgejikbuuwnpy`

### Build result
- Xcode live diagnostics were clean for:
  - `mone/Sources/mone/ViewModels/SessionViewModel.swift`
  - `mone/Sources/mone/Views/Onboarding/SetupMethodView.swift`
  - `mone/Sources/mone/App/MoneApp.swift`
- Full Xcode build completed successfully.

### Current working state
- iOS implementation is complete and compiling.
- Real backend call has been wired at `SetupMethodView` under the three-dot menu.
- No `SessionViewModel.deleteAccount()` placeholder remains.
- No other Delete Account placeholder remains in searched Swift sources; `PostAuthDashboardView` has a real call too.

### Assumptions
- The deployed Supabase Edge Function is named exactly `delete-account`.
- The Edge Function has required server-side environment variables configured, including Supabase URL and service-role/secret key.
- After account deletion, routing directly to `.auth` is desired per the current task. This differs from regular logout, which still routes to `.onboarding`.
- Actual filesystem paths in this checkout are rooted at `Sources/mone/...` and `SupabaseClient.swift`; the prompt listed them under an extra `mone/` prefix. Xcode project paths still display as `mone/Sources/...`.

### Known limitations
- Live Supabase deletion was not manually tested from the simulator/device in this run.
- The build verifies compile-time wiring only; Supabase-side behavior still needs manual verification against the deployed Edge Function and database cascade.
- The app currently routes completed users to the temporary `PostAuthDashboardView`; full `MainTabView` wiring remains a separate pending task from the previous handoff.

### Manual test checklist
1. Login as a test user.
2. Confirm user appears in Supabase Authentication → Users.
3. Confirm profile row exists in `public.profiles`.
4. Navigate to `SetupMethodView` and open the three-dot menu.
5. Tap Delete Account.
6. Cancel once and confirm nothing changes.
7. Tap Delete Account again and confirm.
8. User should be routed to the auth screen.
9. Supabase Authentication → Users should no longer contain that user.
10. `public.profiles` row should be gone.
11. Login again with the same email/phone.
12. App should show name onboarding again.

### Next recommended step
- Deploy/verify the `delete-account` Edge Function in Supabase, then run the manual checklist above with a disposable test account.

---

## 2026-05-18 Codex update — Routing fixes in progress

### What changed
- Investigated user-reported issues after the first Delete Account wiring:
  - Delete account success currently routes to `.auth`; updated requirement is to route to the first onboarding screen.
  - `saveName(_:)` currently sets `onboarding_completed = true` and routes to the temporary `PostAuthDashboardView`; updated requirement is to continue to `AgendaSelectionView`.
  - `AgendaSelectionView` always shows a back button; updated requirement is no back button after logged-in name onboarding and a three-dot account menu instead.
  - `SetupMethodView` menu shows a spinner during deletion, which can make the three-dot button feel delayed/resetting after menu dismissal.

### Files modified
- `HANDOFF.md`

### Current working state
- No code changes for this routing pass yet.
- Next edits should be in `AppViewModel`, `SessionViewModel`, `MoneApp`, `NameOnboardingView`, `AgendaSelectionView`, and likely `SetupMethodView`.

### Assumptions
- For logged-in onboarding after name capture, `public.profiles.onboarding_completed` should remain `false` until the full onboarding flow completes.
- The first onboarding screen after account deletion means `WelcomeView`, not `AuthView`.

### Unresolved issues
- Need to ensure returning users with `full_name` but incomplete onboarding resume at `AgendaSelectionView` instead of being asked for their name again.
- Need to build after edits.

### Next recommended step
- Add explicit logged-in onboarding routing and shared account menu behavior for agenda/setup screens.

---

## 2026-05-18 Codex update — Routing fixes implemented, pending build

### What changed
- Added `AppViewModel.resetOnboarding(to:)` and `AppViewModel.startAuthenticatedOnboarding(at:)` helpers.
- Updated `SessionViewModel.handleAuthSuccess()` routing:
  - no profile or missing name → `NameOnboardingView`
  - profile has name and `onboarding_completed = false` → authenticated onboarding at `AgendaSelectionView`
  - profile has name and `onboarding_completed = true` → dashboard
- Updated `SessionViewModel.saveName(_:)` so saving a name writes:
  - `onboarding_step = "primaryAgenda"`
  - `onboarding_completed = false`
  - then routes into onboarding instead of the temporary dashboard
- Added `SessionViewModel.completeOnboarding()` so finishing the local onboarding flow can persist `onboarding_completed = true` before routing to dashboard.
- Updated `RootView` to sync app onboarding state when `SessionViewModel.route == .onboarding`:
  - signed-out users start at `WelcomeView`
  - signed-in users start at `AgendaSelectionView`
- Updated Delete Account success to route to the first onboarding screen (`WelcomeView`) instead of auth.
- Removed the spinner/disabled state from the `SetupMethodView` three-dot menu button itself to avoid the delayed reset feel after menu dismissal. Menu items still disable during deletion.
- Updated `AgendaSelectionView`:
  - logged-in users see the same three-dot account menu pattern as `SetupMethodView`
  - logged-in users do not see the back button
  - non-logged-in users keep the back button
  - delete confirmation and error handling are wired to the same real delete flow

### Files modified
- `Sources/mone/ViewModels/AppViewModel.swift`
- `Sources/mone/ViewModels/SessionViewModel.swift`
- `Sources/mone/App/MoneApp.swift`
- `Sources/mone/Views/Onboarding/SetupMethodView.swift`
- `Sources/mone/Views/Onboarding/AgendaSelectionView.swift`
- `HANDOFF.md`

### Current working state
- Code edits are in place but Xcode diagnostics/build have not yet been run for this pass.

### Assumptions
- First onboarding screen after account deletion means `WelcomeView`.
- Authenticated users who have provided a name but not completed onboarding should resume at `AgendaSelectionView`.

### Unresolved issues
- Need to run Xcode diagnostics/build and fix any compile errors.

### Next recommended step
- Run Xcode diagnostics on edited files, then full project build.

---

## 2026-05-18 Codex final update — Routing/menu fixes complete

### What changed
- Delete Account success now returns the user to the first onboarding screen (`WelcomeView`) instead of the sign-in/sign-up screen.
- Delete Account now calls `supabase.auth.signOut(scope: .local)` after the Edge Function succeeds, then forces signed-out onboarding routing. This avoids stale local session state sending the deleted user into authenticated onboarding.
- New/re-created users should be asked for their name when no `public.profiles` row exists or the row has no `full_name`.
- Saving a name no longer marks onboarding complete. It writes `full_name`, sets `onboarding_step = "primaryAgenda"`, `onboarding_completed = false`, and routes to `AgendaSelectionView`.
- Returning users with a name but incomplete onboarding now resume at `AgendaSelectionView` instead of seeing the name screen again.
- Completing the local onboarding flow now persists `onboarding_completed = true` / `onboarding_step = "dashboard"` before dashboard routing.
- `AgendaSelectionView` now:
  - shows the three-dot account menu for logged-in users
  - hides the back button for logged-in users
  - keeps the back button for non-logged-in onboarding
  - uses the real Delete Account flow and confirmation dialog
- `SetupMethodView` three-dot menu icon no longer swaps to a spinner or disables itself during deletion, which should remove the delayed reset feel after dismissing the menu. The menu actions still disable while deletion is in progress.

### Files modified
- `Sources/mone/ViewModels/AppViewModel.swift`
- `Sources/mone/ViewModels/SessionViewModel.swift`
- `Sources/mone/App/MoneApp.swift`
- `Sources/mone/Views/Onboarding/AgendaSelectionView.swift`
- `Sources/mone/Views/Onboarding/SetupMethodView.swift`
- `HANDOFF.md`

### Build result
- Xcode live diagnostics were clean for:
  - `mone/Sources/mone/ViewModels/AppViewModel.swift`
  - `mone/Sources/mone/ViewModels/SessionViewModel.swift`
  - `mone/Sources/mone/App/MoneApp.swift`
  - `mone/Sources/mone/Views/Onboarding/AgendaSelectionView.swift`
  - `mone/Sources/mone/Views/Onboarding/SetupMethodView.swift`
- Full Xcode build completed successfully.

### Current working state
- The reported routing issues are addressed in code and compile successfully.
- The real Delete Account backend call remains wired through `URLSession` to the `delete-account` Edge Function.
- No service-role/admin secrets were added to iOS.

### Assumptions
- `WelcomeView` is the intended "first onboarding screen" after account deletion.
- Authenticated onboarding after name collection should start at `AgendaSelectionView`.
- `onboarding_completed` should remain false until the existing onboarding flow reaches `.complete`.

### Known limitations
- This pass was validated by Xcode diagnostics/build only. Manual simulator/device testing against Supabase is still needed.
- If signing up with the previous identifier still skips name entry, verify in Supabase that the `delete-account` Edge Function actually removed the Auth user and that the `public.profiles` row cascaded. The iOS routing now asks for name when no profile row or no `full_name` is returned for the current Auth user.

### Manual test checklist
1. Login/sign up as a new test user.
2. Enter name.
3. Confirm the next screen is `AgendaSelectionView`, not the temporary logout/delete dashboard.
4. Confirm `AgendaSelectionView` shows the three-dot menu and no back button when logged in.
5. Continue through onboarding and verify completed onboarding routes to dashboard.
6. Navigate to `SetupMethodView`, open/dismiss the three-dot menu, and confirm the ellipsis resets immediately.
7. Delete the account from the three-dot menu.
8. Confirm the app returns to `WelcomeView`.
9. Confirm Supabase Authentication no longer contains the user.
10. Confirm `public.profiles` no longer contains the deleted user's row.
11. Sign up again with the same email/phone.
12. Confirm the app asks for name again, then routes to `AgendaSelectionView`.

### Next recommended step
- Run the manual checklist with a disposable Supabase user and verify the Edge Function/database cascade in the Supabase dashboard.

---

## 2026-05-18 Codex update — Same email after deletion still skips name, investigation in progress

### What changed
- User reported that signing up with the same email after deleting the account still skips name onboarding.
- Re-read `SessionViewModel.handleAuthSuccess()` and `delete-account` Edge Function.
- Current iOS routing asks for name only when `public.profiles` returns no row or a row without `full_name`.
- Therefore, the observed behavior strongly indicates that `public.profiles` is still returning an old row with `full_name` for the signed-in user after deletion.
- Current Edge Function only calls `auth.admin.deleteUser(user.id)` and relies on database cascade to delete `public.profiles`; if the live FK lacks `on delete cascade`, profile data can survive.

### Files modified
- `HANDOFF.md`

### Current working state
- No code changes yet in this pass.

### Assumptions
- The live database may not have the expected `public.profiles.id references auth.users(id) on delete cascade` constraint.
- A defensive client-side stale-profile guard is worthwhile because the user has already hit this state.

### Unresolved issues
- Need to explicitly delete `public.profiles` in the Edge Function with the server-side admin client.
- Need to add a client-side guard so a just-deleted local user id cannot reuse a stale profile row and skip name onboarding.

### Next recommended step
- Patch backend function and iOS stale-profile handling, then build.

---

## 2026-05-18 Codex final update — Same-email re-signup name prompt fix

### What changed
- Updated `mone-backend/supabase/functions/delete-account/index.ts` to explicitly delete `public.profiles` with the server-side admin client before deleting the Supabase Auth user.
- This removes reliance on the live database having the expected `on delete cascade` FK. If cascade exists, the explicit delete is harmless; if cascade is missing, it fixes the stale profile row.
- Added `ProfileReset` in `Sources/mone/Models/Profile.swift` so the client can write `full_name = null` when recovering from a stale post-deletion profile.
- Added a defensive iOS stale-profile guard in `SessionViewModel`:
  - on successful delete, store the deleted Auth user id locally in `UserDefaults`
  - on next auth success, if Supabase returns a profile for that same user id, reset that profile to no name / incomplete onboarding and route to `NameOnboardingView`
  - after the user saves a new name, clear that local deleted-id marker
- This is intended to recover from the exact observed state where signing up with the same email after deletion still returned an old `full_name`.

### Files modified
- `mone-backend/supabase/functions/delete-account/index.ts`
- `Sources/mone/Models/Profile.swift`
- `Sources/mone/ViewModels/SessionViewModel.swift`
- `HANDOFF.md`

### Build result
- Xcode live diagnostics were clean for:
  - `mone/Sources/mone/ViewModels/SessionViewModel.swift`
  - `mone/Sources/mone/Models/Profile.swift`
- Full Xcode build completed successfully.

### Current working state
- iOS now compiles and defensively forces name onboarding when a stale profile is returned for a locally deleted user id.
- The backend function source now explicitly deletes the profile row, but the deployed Supabase Edge Function must be redeployed before this backend fix affects live testing.

### Assumptions
- The observed skip-name behavior is caused by a surviving `public.profiles` row with `full_name`.
- The live database FK may not actually be `on delete cascade`, despite the intended schema.

### Known limitations
- The local stale-profile guard only helps on the same device/app install that performed the delete, because it uses local `UserDefaults`.
- The real durable fix is redeploying the Edge Function and ensuring `public.profiles` is deleted server-side.

### Deploy command
- From `mone-backend/supabase`:
  - `supabase functions deploy delete-account --project-ref bvgswlacgejikbuuwnpy`

### Manual test checklist
1. Redeploy the `delete-account` Edge Function.
2. Login as a disposable user and complete name onboarding.
3. Confirm `public.profiles` has a row with `full_name`.
4. Delete the account from the app.
5. Confirm Supabase Authentication no longer contains the user.
6. Confirm `public.profiles` no longer contains the profile row.
7. Sign up again with the same email/phone.
8. Confirm the app asks for name again.
9. Enter a name and confirm the app routes to `AgendaSelectionView`.

### Next recommended step
- Redeploy `delete-account`, then inspect the live `public.profiles` row after deletion if the issue persists.

---

## 2026-05-18 Codex update — Same-email issue persists after deploy, identifier guard in progress

### What changed
- User reported that redeploying the `delete-account` Edge Function still did not make same-email signup ask for name.
- Re-inspected the client guard and found it only tracks the deleted Auth user id.
- If Supabase creates a new Auth user id for the same email/phone, the local deleted-user-id guard will not match.

### Files modified
- `HANDOFF.md`

### Current working state
- Backend function already explicitly deletes `profiles`.
- Need to extend iOS guard from deleted user ids to deleted auth identifiers (`email`/`phone`) as well.

### Assumptions
- The observed case may involve a new Auth user id for the same email/phone.
- Because the app only marks identifiers after a successful delete function response, forcing name onboarding for that identifier is acceptable.

### Unresolved issues
- Need to implement identifier guard and rebuild.

### Next recommended step
- Store deleted email/phone locally on successful deletion, match on next auth success, reset profile/name onboarding, and clear the marker when name is saved.

---

## 2026-05-18 Codex final update — Deleted identifier guard added

### What changed
- Extended the same-email/same-phone post-deletion recovery guard in `SessionViewModel`.
- Previously the app only remembered the deleted Auth user id. That does not help if Supabase creates a new Auth user id for the same email/phone.
- The app now stores normalized deleted auth identifiers (`email` and/or `phone`) in `UserDefaults` after a successful delete-account response.
- On next auth success, if the current session's email/phone matches a recently deleted identifier, the app:
  - resets the current `profiles` row to `full_name = null`
  - sets `onboarding_step = "name"`
  - sets `onboarding_completed = false`
  - routes to `NameOnboardingView`
- `ProfileReset` now explicitly encodes `full_name: null`; this matters because synthesized optional encoding may omit nil instead of clearing the backend column.
- The deleted identifier/user id markers are cleared after the user saves a new name.

### Files modified
- `Sources/mone/ViewModels/SessionViewModel.swift`
- `Sources/mone/Models/Profile.swift`
- `HANDOFF.md`

### Build result
- Xcode live diagnostics were clean for:
  - `mone/Sources/mone/ViewModels/SessionViewModel.swift`
  - `mone/Sources/mone/Models/Profile.swift`
- Full Xcode build completed successfully.

### Current working state
- The client now handles both cases:
  - same Auth user id survives/reappears after deletion
  - new Auth user id is created for the same email/phone after deletion
- The backend Edge Function still explicitly deletes `public.profiles` before deleting the Auth user.

### Known limitations
- The identifier guard only applies on the same app install after a successful delete-account response. If the app is reinstalled, local markers are gone and the backend/database must be correct.
- If the issue persists even after this client change, inspect the live `delete-account` invocation logs and verify whether the app is receiving a 2xx response from the expected Supabase project.

### Next recommended step
- Rebuild/run the app, delete the account once with this build, then sign up with the same email/phone and confirm `NameOnboardingView` appears.

---

## 2026-05-18 Codex update — AuthView onboarding bypass found, fix in progress

### What changed
- User confirmed the Supabase Auth user is deleted in the dashboard, but same-email signup still skips name onboarding.
- Found the likely remaining client-side bypass:
  - `OnboardingFlow` uses bare `AuthView()` for `.auth`.
  - In that mode, after OTP the signed-in screen calls `appVM.advance()`.
  - `appVM.advance()` moves from `.auth` directly to `.primaryAgenda`.
  - This bypasses `SessionViewModel.handleAuthSuccess()`, so profile/name routing is never checked.
- Root `.auth` already passes `onAuthComplete: { await sessionVM.handleAuthSuccess() }`; embedded onboarding auth needs the same treatment.

### Files modified
- `HANDOFF.md`

### Current working state
- No code change for this bypass yet.

### Assumptions
- The user is signing up via the onboarding flow after delete (`WelcomeView` → data/privacy → auth), not via root `.auth`.

### Unresolved issues
- Need to inject `SessionViewModel` into `OnboardingFlow` and pass `onAuthComplete` into the `.auth` case.

### Next recommended step
- Patch `OnboardingFlow` auth case, build, and retest same-email signup.

---

## 2026-05-18 Codex final update — AuthView bypass fixed

### What changed
- Fixed the remaining same-email signup bypass in `Sources/mone/App/MoneApp.swift`.
- `OnboardingFlow` now reads `SessionViewModel` from the environment.
- The `.auth` onboarding case now uses:
  - `AuthView(onAuthComplete: { Task { await sessionVM.handleAuthSuccess() } })`
- This means OTP completion from the onboarding auth screen now runs the real session/profile routing:
  - no profile → `NameOnboardingView`
  - profile with missing name → `NameOnboardingView`
  - profile with name but incomplete onboarding → `AgendaSelectionView`
  - completed profile → dashboard
- Previously, bare `AuthView()` called `appVM.advance()` after OTP, which jumped directly from `.auth` to `.primaryAgenda` and skipped all profile/name checks.

### Files modified
- `Sources/mone/App/MoneApp.swift`
- `HANDOFF.md`

### Build result
- Xcode live diagnostics were clean for `mone/Sources/mone/App/MoneApp.swift`.
- Full Xcode build completed successfully.

### Current working state
- The likely cause of "same email after deleted Auth user still skips name" is fixed.
- Backend deletion/profile cleanup and client stale-profile guards remain in place.

### Manual test checklist
1. Run this build.
2. Delete an account.
3. Confirm Supabase Authentication no longer contains that user.
4. Start onboarding from `WelcomeView`.
5. Choose sign-up / encrypted backup path.
6. Sign up with the same email.
7. After OTP, confirm the app shows `NameOnboardingView` instead of `AgendaSelectionView`.
8. Enter a name and confirm the next screen is `AgendaSelectionView`.

### Next recommended step
- Retest same-email signup with this build; no additional Supabase redeploy is required for this specific client routing fix.

---

## 2026-05-18 Codex update — Name screen menu and reset routing in progress

### What changed
- User confirmed same-email signup now works.
- New requested changes:
  - Replace the logout icon on `NameOnboardingView` with the same three-dot account menu used on `SetupMethodView` / `AgendaSelectionView`.
  - After logout or delete, always reset to the first onboarding step.
- Identified why logout/delete can leave the user on the same onboarding page:
  - Agenda/setup screens are already under `SessionViewModel.Route.onboarding`.
  - `SessionViewModel.signOut()` / `deleteAccount()` set `route = .onboarding`, but assigning the same value does not trigger `RootView.onChange(of: sessionVM.route)`.
  - `RootView.syncOnboardingState` therefore may not run, leaving `AppViewModel.onboardingStep` unchanged.

### Files modified
- `HANDOFF.md`

### Current working state
- No code changes for this pass yet.

### Assumptions
- "First step of the onboarding journey" means `WelcomeView`.

### Unresolved issues
- Need explicit reset signal independent of route changes.
- Need to update `NameOnboardingView` top-right account UI.

### Next recommended step
- Add a reset token to `SessionViewModel`, observe it in `RootView`, and wire `NameOnboardingView` three-dot menu.

---

## 2026-05-18 Codex final update — Name menu and onboarding reset fixed

### What changed
- Replaced the top-right logout icon on `NameOnboardingView` with the same ellipsis account menu pattern used by `SetupMethodView` and `AgendaSelectionView`.
- The `NameOnboardingView` menu contains:
  - `Log out`
  - `Delete account` with destructive role
- Added the same native delete confirmation dialog to `NameOnboardingView`.
- Added `SessionViewModel.onboardingResetToken`, which changes whenever logout/delete should force a journey reset.
- `RootView` now observes `sessionVM.onboardingResetToken` and calls `syncOnboardingState(for: .onboarding)` even when `sessionVM.route` was already `.onboarding`.
- `SessionViewModel.signOut()` now:
  - attempts normal sign out
  - falls back to local sign out if needed
  - clears profile/session state
  - marks `shouldForceWelcomeOnboarding = true`
  - changes `onboardingResetToken`
  - routes to `.onboarding`
- `SessionViewModel.deleteAccount()` now also changes `onboardingResetToken` after successful deletion, so the app resets to `WelcomeView` from Agenda/Setup/Name screens.

### Files modified
- `Sources/mone/ViewModels/SessionViewModel.swift`
- `Sources/mone/App/MoneApp.swift`
- `Sources/mone/Views/Onboarding/NameOnboardingView.swift`
- `HANDOFF.md`

### Build result
- Xcode live diagnostics were clean for:
  - `mone/Sources/mone/ViewModels/SessionViewModel.swift`
  - `mone/Sources/mone/App/MoneApp.swift`
  - `mone/Sources/mone/Views/Onboarding/NameOnboardingView.swift`
- Full Xcode build completed successfully.

### Current working state
- Name screen account controls now match Agenda/Setup.
- Logout/delete should reset to the first onboarding screen (`WelcomeView`) even when the user is already inside `SessionViewModel.Route.onboarding`.

### Manual test checklist
1. Reach `NameOnboardingView`.
2. Confirm the top-right control is an ellipsis menu, not a logout icon.
3. Tap Log out and confirm the app returns to `WelcomeView`.
4. Log in again and reach `NameOnboardingView`.
5. Tap Delete account, cancel once, and confirm the user remains on name screen.
6. Tap Delete account again and confirm.
7. Confirm the account is deleted and the app returns to `WelcomeView`.
8. Repeat logout/delete from `AgendaSelectionView` and `SetupMethodView`; both should return to `WelcomeView`.

### Next recommended step
- Manual test logout/delete reset from Name, Agenda, and Setup screens in the simulator/device.

---

## 2026-05-18 Codex update — Returning-user continue/resume fix in progress

### What changed
- User reported that a returning user with a saved name lands on `Welcome back, [name].`, but `Continue to moné` does not take them forward.
- Root cause identified:
  - For incomplete onboarding, `SessionViewModel.handleAuthSuccess()` sets `route = .onboarding`.
  - If the user is already inside `OnboardingFlow`/`.onboarding`, this route assignment does not trigger `RootView.onChange(of: sessionVM.route)`.
  - Therefore `AppViewModel.onboardingStep` can remain at `.auth`, making the signed-in interstitial feel stuck.
- Also found that intermediate onboarding steps are not persisted yet, so returning users with incomplete setup always resume at `.primaryAgenda` instead of their last worked step.

### Files modified
- `HANDOFF.md`

### Current working state
- No code changes for this pass yet.

### Assumptions
- `public.profiles.onboarding_step` should be the source of truth for incomplete onboarding resume.
- Completed setup should continue to route to dashboard.

### Unresolved issues
- Need to trigger onboarding resync when auth success resolves to `.onboarding`.
- Need to map persisted `onboarding_step` strings to `AppViewModel.OnboardingStep`.
- Need to persist onboarding step changes during authenticated onboarding.

### Next recommended step
- Patch `SessionViewModel` step mapping/progress update and `RootView` step-change persistence, then build.

---

## 2026-05-18 Codex final update — Returning-user continue/resume fixed

### What changed
- Fixed returning-user continuation from the `Welcome back, [name].` signed-in interstitial.
- `SignedInScreen` in `AuthView` now uses a normal `MonePrimaryButton` for `Continue to moné`.
- Removed the auto-progress/auto-continue behavior from `SignedInScreen`; the button is now explicitly user-driven and guarded against double taps.
- `SessionViewModel.handleAuthSuccess()` now:
  - maps `profiles.onboarding_step` to the corresponding `AppViewModel.OnboardingStep`
  - sets `onboardingResetToken` when routing to authenticated onboarding, so `RootView` resyncs even if `route` was already `.onboarding`
  - routes completed users to dashboard as before
- Added `SessionViewModel.updateOnboardingProgress(to:)` to persist intermediate authenticated onboarding progress to `public.profiles.onboarding_step`.
- `RootView` now observes `appVM.onboardingStep` and persists progress while the user is authenticated and in onboarding.

### Files modified
- `Sources/mone/ViewModels/SessionViewModel.swift`
- `Sources/mone/App/MoneApp.swift`
- `Sources/mone/Views/Onboarding/AuthView.swift`
- `HANDOFF.md`

### Build result
- Xcode live diagnostics were clean for:
  - `mone/Sources/mone/ViewModels/SessionViewModel.swift`
  - `mone/Sources/mone/App/MoneApp.swift`
  - `mone/Sources/mone/Views/Onboarding/AuthView.swift`
- Full Xcode build completed successfully.

### Current working state
- A returning user with completed setup routes to dashboard.
- A returning user with a name and incomplete setup resumes at the last persisted onboarding step.
- If no last step exists, incomplete setup falls back to `AgendaSelectionView`.
- The `Continue to moné` button should now visibly and reliably continue through session/profile routing.

### Manual test checklist
1. Sign in as a user with `full_name` and `onboarding_completed = false`.
2. Tap `Continue to moné` on the welcome-back screen.
3. Confirm the app resumes at `profiles.onboarding_step`.
4. Move to another onboarding step, quit/relaunch or log out/log back in.
5. Confirm the new step is resumed.
6. Set `onboarding_completed = true` for the user and sign in again.
7. Confirm `Continue to moné` routes to dashboard.

### Next recommended step
- Manually test one incomplete profile and one completed profile against Supabase.

---

## 2026-05-18 Codex update — Setu AA iOS wiring in progress

### What changed
- Read `HANDOFF.md` and inspected current project structure, app entry point, Supabase config, session routing, onboarding flow, AA consent screen, and backend Setu AA functions.
- Confirmed actual filesystem paths are rooted at `Sources/mone/...` and `SupabaseClient.swift`; the prompt lists paths under an extra `mone/` prefix. Xcode project paths still use `mone/Sources/...`.
- Confirmed backend functions exist in repo:
  - `setu-aa-create-consent`
  - `setu-aa-redirect`
  - `setu-aa-callback`
- Confirmed `setu-aa-create-consent` expects an authenticated POST and returns `consentId`, `consentUrl`, and `status`.
- Current `AAConsentView` only calls `appVM.advance()` and does not call Setu/Supabase yet.

### Files modified
- `HANDOFF.md`

### Current working state
- No code changes for this Setu AA pass yet.

### Assumptions
- The iOS app should call `setu-aa-create-consent` from `AAConsentView` when the user taps `Continue to consent`.
- The app should use native SwiftUI plus system URL opening, not a WebView-first flow.
- Email-auth users may not have a phone number in their Supabase session, so the AA consent screen needs a mobile-number field instead of relying only on `session.user.phone`.

### Unresolved issues
- Need to wire `AAConsentView` to call the Edge Function with `Authorization: Bearer <current_access_token>`.
- Need to handle loading, validation, success URL opening, and user-safe errors.

### Next recommended step
- Implement the AA consent client call in `AAConsentView`, then run Xcode diagnostics/build.

---

## 2026-05-18 Codex update — Setu AA iOS call implemented, pending build

### What changed
- Updated `Sources/mone/Views/Onboarding/AAConsentView.swift`.
- Added a native 10-digit Indian mobile-number input on the consent screen.
- Prefills the field from `supabase.auth.currentSession?.user.phone` when available.
- `Continue to consent` now calls `POST /functions/v1/setu-aa-create-consent` using:
  - `Authorization: Bearer <current_supabase_access_token>`
  - `Content-Type: application/json`
  - body `{ "mobileNumber": "<10 digits>" }`
- The endpoint URL is built from `SupabaseConfig.url`; no project ref is duplicated.
- On success, decodes `consentUrl` and opens it with SwiftUI `openURL`.
- Shows loading, disabled, and user-friendly error states.
- After a consent link has been opened, the screen shows:
  - `Open consent again`
  - `I've completed consent` to continue the existing onboarding flow
- No backend secrets were added to iOS.

### Files modified
- `Sources/mone/Views/Onboarding/AAConsentView.swift`
- `HANDOFF.md`

### Current working state
- Code has been edited but Xcode diagnostics/build have not yet been run.

### Assumptions
- `setu-aa-create-consent` returns `consentId`, `consentUrl`, and `status` as currently implemented in the repo.
- Until deep-link return handling is added, a manual `I've completed consent` button is acceptable after opening Setu consent.

### Unresolved issues
- Need to run diagnostics/build.
- Deep-link return from Setu redirect is not implemented; `setu-aa-redirect` currently renders an HTML page telling the user to return to the app.

### Next recommended step
- Run Xcode diagnostics on `AAConsentView.swift`, then build the project.

---

## 2026-05-18 Codex final update — Setu AA consent iOS flow wired

### What changed
- Completed iOS wiring for `setu-aa-create-consent` in `Sources/mone/Views/Onboarding/AAConsentView.swift`.
- The AA consent screen now collects a 10-digit Indian mobile number, prefilled from `supabase.auth.currentSession?.user.phone` when available.
- Tapping `Continue to consent` calls:
  - `POST https://<project-ref>.supabase.co/functions/v1/setu-aa-create-consent`
  - `Authorization: Bearer <current_supabase_access_token>`
  - `Content-Type: application/json`
  - body `{ "mobileNumber": "<10-digit-mobile>" }`
- The implementation uses `URLSession` and `SupabaseConfig.url`, matching the existing delete-account client pattern.
- On a successful response, the app decodes `consentUrl` and opens it via SwiftUI `openURL`.
- After the consent URL opens, the screen shows:
  - `Open consent again`
  - `I've completed consent`, which advances the existing onboarding flow
- Added loading, disabled, validation, and concise error states consistent with the current dark/premium UI.
- No service-role key, Setu credentials, or backend secrets were added to iOS.

### Files modified
- `Sources/mone/Views/Onboarding/AAConsentView.swift`
- `HANDOFF.md`

### Build result
- Xcode live diagnostics were clean for `mone/Sources/mone/Views/Onboarding/AAConsentView.swift`.
- Full Xcode build completed successfully.

### Current working state
- iOS can now start the Setu AA consent creation flow for signed-in users.
- `setu-aa-create-consent` must be deployed and configured with the Setu/Supabase secrets already added in Supabase.
- Deep-link return into the iOS app is still not implemented; the current backend redirect page tells the user to return to the app, and the app provides `I've completed consent` to continue.

### Assumptions
- The deployed `setu-aa-create-consent` response shape is `{ consentId, consentUrl, status }`, matching the repo implementation.
- Manual continuation after browser consent is acceptable until universal/deep link handling is added.

### Known limitations
- The app does not yet poll consent status or consume `aa_consents` / `aa_webhook_events`.
- The app does not yet fetch/process AA financial data after consent.
- `setu-aa-callback` currently only logs/acknowledges webhook payloads in the repo; it does not persist callback events yet.

### Manual test checklist
1. Sign in as a user and choose Account Aggregator as setup method.
2. Reach `AAConsentView`.
3. Confirm mobile number is prefilled for phone-auth users or can be entered manually.
4. Tap `Continue to consent`.
5. Confirm the Edge Function logs show `setu_consent_created`.
6. Confirm a row is inserted in `public.aa_consents`.
7. Confirm the Setu consent URL opens in the browser.
8. Return to moné and tap `I've completed consent`.
9. Confirm onboarding advances to the building Money Map step.

### Next recommended step
- Manually run the Setu sandbox flow from the simulator/device and inspect Edge Function logs plus `public.aa_consents`.

---

## 2026-05-18 Codex update — Setu AA create consent error investigation in progress

### What changed
- User reported iOS shows `Could not create Account Aggregator consent` after tapping `Continue to consent`.
- User also requested the AA mobile text field be pre-populated with the required sandbox number.
- Re-inspected `AAConsentView` and `setu-aa-create-consent`.
- Current iOS field only pre-fills from `supabase.auth.currentSession?.user.phone`; email-auth users therefore see an empty field.
- Current Edge Function calls `${SETU_AA_BASE_URL}/consents`; if Supabase secret `SETU_AA_BASE_URL` is set to `https://fiu-sandbox.setu.co` rather than `https://fiu-sandbox.setu.co/v2`, Setu consent creation can fail.
- Setu docs indicate sandbox base host `https://fiu-sandbox.setu.co` and consent webview URLs under `/v2/...`; making the backend normalize the API base URL is safer.

### Files modified
- `HANDOFF.md`

### Current working state
- No code changes for this pass yet.

### Assumptions
- The required sandbox mobile number to prefill is `9876543210`, based on the current task prompt's expected request body example.
- The Setu consent error may be caused by a base URL/API version mismatch or Setu rejecting the sandbox payload; backend logs still remain the source of truth.

### Unresolved issues
- Need to update iOS default prefill.
- Need to make `setu-aa-create-consent` tolerant of `SETU_AA_BASE_URL` with or without `/v2`.
- Need to run build after iOS changes.

### Next recommended step
- Patch `AAConsentView` and the Setu Edge Function URL construction, then validate.

---

## 2026-05-18 Codex update — Setu AA prefill and endpoint normalization implemented

### What changed
- Updated `Sources/mone/Views/Onboarding/AAConsentView.swift`.
- The AA mobile field now defaults to `9876543210` when the signed-in Supabase session has no usable 10-digit Indian phone number.
- Phone-auth users with a valid session phone still prefill from their session phone.
- iOS error parsing now reads `details.message` from the Edge Function JSON response when available before falling back to `error`.
- Updated `mone-backend/supabase/functions/setu-aa-create-consent/index.ts`.
- Added `getSetuConsentEndpoint()` so `SETU_AA_BASE_URL` can be either:
  - `https://fiu-sandbox.setu.co`
  - `https://fiu-sandbox.setu.co/v2`
- The function now calls `<normalized-base>/consents`, preventing missing or duplicated `/v2`.

### Files modified
- `Sources/mone/Views/Onboarding/AAConsentView.swift`
- `mone-backend/supabase/functions/setu-aa-create-consent/index.ts`
- `HANDOFF.md`

### Current working state
- iOS changes have not yet been rebuilt in this checkpoint.
- Backend function source changed and must be redeployed before the endpoint normalization affects live Supabase.

### Assumptions
- `9876543210` is the intended sandbox mobile number from the current task prompt.
- The Setu failure may have been caused by `SETU_AA_BASE_URL` lacking `/v2`.

### Unresolved issues
- Need to run Xcode diagnostics/build.
- Need to redeploy `setu-aa-create-consent` after backend change.

### Next recommended step
- Run diagnostics/build, then deploy `setu-aa-create-consent`.

---

## 2026-05-18 Codex final update — Setu AA error handling and sandbox prefill complete

### What changed
- Completed the Setu AA iOS/backend patch for the reported `Could not create Account Aggregator consent` error.
- `AAConsentView` now pre-populates the mobile field with `9876543210` when there is no valid phone number on the Supabase session.
- Valid phone-auth session numbers still take precedence over the sandbox default.
- `AAConsentView` now surfaces `details.message` from the Edge Function response when present, making the next Setu rejection more actionable than the generic error.
- `setu-aa-create-consent` now normalizes `SETU_AA_BASE_URL` so the Supabase secret may be configured either with or without `/v2`.
- The function now calls `<normalized-base>/consents`, e.g. `https://fiu-sandbox.setu.co/v2/consents`.

### Files modified
- `Sources/mone/Views/Onboarding/AAConsentView.swift`
- `mone-backend/supabase/functions/setu-aa-create-consent/index.ts`
- `HANDOFF.md`

### Build result
- Xcode live diagnostics were clean for `mone/Sources/mone/Views/Onboarding/AAConsentView.swift`.
- Full Xcode build completed successfully.

### Current working state
- iOS prefill/error parsing is complete and compiling.
- Backend Edge Function source is patched but must be redeployed before live testing uses the `/v2` normalization.

### Assumptions
- `9876543210` is the intended sandbox mobile number from the current task prompt.
- The Setu failure may be caused by `SETU_AA_BASE_URL` being set to the host without `/v2`, while Setu AA consent APIs/webview use `/v2`.

### Known limitations
- I did not invoke the live Supabase Edge Function from this environment.
- If the error persists after redeploy, inspect Edge Function logs for `setu_create_consent_failed`; the logged `response` from Setu is the source of truth.
- If Setu rejects the mobile/VUA, confirm the sandbox number is whitelisted/valid for the configured AA partner/product instance.

### Deploy command
- From `mone-backend/supabase`:
  - `supabase functions deploy setu-aa-create-consent --project-ref bvgswlacgejikbuuwnpy`

### Manual test checklist
1. Redeploy `setu-aa-create-consent`.
2. Run the app and reach `AAConsentView`.
3. Confirm the mobile field is prefilled with `9876543210` for email-auth users.
4. Tap `Continue to consent`.
5. If it succeeds, confirm the consent URL opens and a row appears in `public.aa_consents`.
6. If it fails, check Supabase Edge Function logs for `setu_create_consent_failed` and inspect the Setu response body.

### Next recommended step
- Redeploy the Edge Function and retest the Setu sandbox flow; use the Edge Function logs if Setu still returns non-2xx.

---

## 2026-05-18 Codex update — Setu AA error persists after redeploy, backend hardening in progress

### What changed
- User reported `Could not create Account Aggregator consent` still appears after redeploying `setu-aa-create-consent`.
- Rechecked Setu docs:
  - Create Consent is documented as `POST /consents` on the FIU base host.
  - `/v2` appears in returned consent webview URLs and some later APIs such as multi-consent/revoke/fetch status.
- Current function was changed to always call `/v2/consents`; this may still be wrong for standard Create Consent.
- Setu docs also note `additionalParams.tags` must exist at product instance level before use. Current payload sends custom tags `["mone", "sandbox", "onboarding"]`, which may cause Setu rejection if not configured.

### Files modified
- `HANDOFF.md`

### Current working state
- No code changes for this pass yet.

### Assumptions
- The persistent error is a Setu non-2xx response, not an iOS transport/auth failure.
- The backend should default to documented `POST /consents`, optionally retry `/v2/consents`, and avoid unconfigured tags.

### Unresolved issues
- Need to harden the Edge Function endpoint selection/retry.
- Need to return a safe debug message/trace id to iOS so the next failure is actionable.

### Next recommended step
- Patch `setu-aa-create-consent` and improve iOS error decoding, then build.

---

## 2026-05-18 Codex final update — Setu AA backend retry/debug patch

### What changed
- Updated `mone-backend/supabase/functions/setu-aa-create-consent/index.ts`.
- Create Consent now defaults to the documented standard endpoint:
  - `<SETU_AA_BASE_URL without /v2>/consents`
- If that endpoint returns non-2xx and no explicit endpoint override is set, the function retries:
  - `<SETU_AA_BASE_URL without /v2>/v2/consents`
- Added optional `SETU_AA_CONSENT_ENDPOINT` override. If set, the function uses that exact endpoint and does not retry.
- Removed custom `additionalParams.tags` from the Setu payload. Setu docs say tags must be configured at product-instance level before use, so sending unconfigured tags can cause consent creation rejection.
- Added safe extraction of Setu rejection fields:
  - `debugMessage`
  - `setuStatus`
  - `traceId`
- The Edge Function response on Setu rejection is now:
  - `error: "Setu rejected the Account Aggregator consent request"`
  - plus safe debug fields above and raw Setu `details` for debugging.
- Updated `Sources/mone/Views/Onboarding/AAConsentView.swift` to display `debugMessage` first, then `details.message`, then trace id/error fallback.

### Files modified
- `mone-backend/supabase/functions/setu-aa-create-consent/index.ts`
- `Sources/mone/Views/Onboarding/AAConsentView.swift`
- `HANDOFF.md`

### Build result
- Xcode live diagnostics were clean for `mone/Sources/mone/Views/Onboarding/AAConsentView.swift`.
- Full Xcode build completed successfully.

### Current working state
- iOS compiles and should show a more actionable Setu error if consent creation still fails.
- Backend source is patched but must be redeployed before testing.

### Assumptions
- The previous `/v2/consents` forced endpoint may be wrong for standard Create Consent because Setu docs document `POST /consents`.
- Unconfigured `additionalParams.tags` may be another cause of Setu rejection.

### Known limitations
- I did not invoke the live function from this environment.
- If both `/consents` and `/v2/consents` fail, the returned `debugMessage` / `traceId` and Supabase function logs are required to identify whether the issue is credentials, product instance id, Setu sandbox mobile/VUA whitelisting, or consent payload shape.

### Deploy command
- From `mone-backend/supabase`:
  - `supabase functions deploy setu-aa-create-consent --project-ref bvgswlacgejikbuuwnpy`

### Manual test checklist
1. Redeploy `setu-aa-create-consent`.
2. Tap `Continue to consent` again.
3. If it succeeds, confirm `public.aa_consents` row and browser consent URL.
4. If it fails, copy the exact app-visible message and inspect Supabase logs for:
  - `setu_create_consent_primary_failed_retrying`
  - `setu_create_consent_failed`
5. Use the logged Setu `response`, `status`, and `traceId` to fix the remaining Setu-side configuration/payload issue.

### Next recommended step
- Redeploy and retest. If it still fails, share the exact new app-visible message or Setu response from Edge Function logs.

---

## 2026-05-18 Codex update — Setu trace-only rejection, payload simplification in progress

### What changed
- User reported Setu still rejects consent creation and app now shows trace id:
  - `1-6a0a51db-627bc57719f680e64cd9e095`
- This confirms the request reaches Setu and Setu returns a non-2xx response; auth/session/iOS transport are not the blocker.
- Rechecked Setu docs:
  - Standard Create Consent examples use a comparatively simple payload.
  - `context` is optional.
  - `additionalParams.tags` must be preconfigured if used; already removed.
  - VUA may be either mobile-only for smart routing or mobile with AA handle suffix, depending on setup/AA partner.

### Files modified
- `HANDOFF.md`

### Current working state
- No code changes for this pass yet.

### Assumptions
- The trace-only rejection may be caused by optional smart-routing context or mobile-only VUA not being accepted for the configured Setu/AA setup.

### Unresolved issues
- Need to simplify Setu payload further.
- Need to support optional `SETU_AA_VUA_HANDLE` secret, so the backend can send e.g. `9876543210@setu` or `9876543210@onemoney` without client changes.

### Next recommended step
- Patch the Edge Function payload builder and redeploy.

---

## 2026-05-18 Codex final update — Setu payload simplified and VUA handle override added

### What changed
- Updated `mone-backend/supabase/functions/setu-aa-create-consent/index.ts`.
- Simplified the Setu consent payload closer to documented Create Consent examples:
  - removed optional `context`
  - removed empty `additionalParams`
- Added `buildVua(mobileDigits)`.
- Added optional Supabase secret support:
  - `SETU_AA_VUA_HANDLE`
- Behavior:
  - if `SETU_AA_VUA_HANDLE` is not set, VUA remains mobile-only, e.g. `9876543210`
  - if `SETU_AA_VUA_HANDLE=setu`, VUA becomes `9876543210@setu`
  - if `SETU_AA_VUA_HANDLE=onemoney`, VUA becomes `9876543210@onemoney`
- This lets the backend match whichever AA handle format the configured Setu sandbox/product instance requires without changing iOS.

### Files modified
- `mone-backend/supabase/functions/setu-aa-create-consent/index.ts`
- `HANDOFF.md`

### Current working state
- No iOS code changed in this pass.
- Backend function source changed and must be redeployed.

### Assumptions
- The trace-only Setu rejection is likely due to payload/configuration mismatch, not iOS.
- Optional `context` or mobile-only VUA may not be accepted by the configured sandbox/product instance.

### Known limitations
- Still need the Setu response from Supabase Edge Function logs if this fails again.
- If Setu requires a specific AA handle, the correct `SETU_AA_VUA_HANDLE` value must come from Setu Bridge/support/docs for the sandbox account.

### Deploy command
- From `mone-backend/supabase`:
  - `supabase functions deploy setu-aa-create-consent --project-ref bvgswlacgejikbuuwnpy`

### Optional secret to try
- If mobile-only VUA keeps failing, set:
  - `supabase secrets set SETU_AA_VUA_HANDLE=setu --project-ref bvgswlacgejikbuuwnpy`
- Then redeploy/retest.
- If Setu Bridge indicates a different sandbox AA handle, use that value instead.

### Manual test checklist
1. Redeploy the function with the simplified payload.
2. Retest `9876543210`.
3. If it still fails, set `SETU_AA_VUA_HANDLE=setu`, redeploy, and retest.
4. If it still fails, inspect Supabase logs for `setu_create_consent_failed` and share the logged Setu `response` body with the trace id.

### Next recommended step
- Redeploy with the simplified payload; if the same trace-only error persists, try `SETU_AA_VUA_HANDLE=setu` or inspect the exact Setu response in Edge Function logs.

---

## 2026-05-18 Codex update — Setu log diagnosis in progress

### What changed
- User provided Supabase logs:
  - primary `/consents` call failed with `401 Token issuer not allowed`
  - fallback `/v2/consents` call failed with `400 InvalidRequest`
  - Setu validation error: `frequency -> unit -> Must be one of: HOUR, DAY, MONTH, YEAR, INF.`
- This proves `/v2/consents` is the correct endpoint for the current Setu access token.
- The remaining payload issue is `frequency.unit = "MONTHLY"`, which should be `"MONTH"`.

### Files modified
- `HANDOFF.md`

### Current working state
- No code changes for this diagnosis checkpoint yet.

### Assumptions
- `SETU_AA_BASE_URL` is configured as Setu FIU sandbox host or `/v2` variant, and the endpoint should resolve directly to `/v2/consents`.

### Unresolved issues
- Need to patch backend frequency enum and endpoint default to avoid the known-bad primary `/consents` call.

### Next recommended step
- Update `setu-aa-create-consent` to call `/v2/consents` directly and set `frequency.unit = "MONTH"`.

---

## 2026-05-18 Codex final update — Setu frequency enum and endpoint fixed

### What changed
- Updated `mone-backend/supabase/functions/setu-aa-create-consent/index.ts`.
- `getSetuConsentEndpoint()` now resolves directly to:
  - `<SETU_AA_BASE_URL without /v2>/v2/consents`
- Removed the fallback retry path because Supabase logs prove `/consents` fails with:
  - `401 Token issuer not allowed`
- Fixed consent payload:
  - `frequency.unit` changed from `"MONTHLY"` to `"MONTH"`
- This matches Setu's validation error which allows:
  - `HOUR`, `DAY`, `MONTH`, `YEAR`, `INF`

### Files modified
- `mone-backend/supabase/functions/setu-aa-create-consent/index.ts`
- `HANDOFF.md`

### Current working state
- Backend source is patched.
- No iOS code changed in this pass.
- No Xcode build needed for this backend-only change.

### Assumptions
- `/v2/consents` is the correct Setu endpoint for the current access token issuer.
- After fixing `frequency.unit`, the next request should either succeed or expose the next Setu validation/configuration error.

### Deploy command
- From `mone-backend/supabase`:
  - `supabase functions deploy setu-aa-create-consent --project-ref bvgswlacgejikbuuwnpy`

### Manual test checklist
1. Redeploy `setu-aa-create-consent`.
2. Tap `Continue to consent`.
3. Confirm the logs no longer show the primary `/consents` 401.
4. Confirm the logs no longer show `frequency -> unit`.
5. If Setu succeeds, confirm consent URL opens and `public.aa_consents` receives a row.
6. If Setu fails, inspect the next `setu_create_consent_failed` response body.

### Next recommended step
- Redeploy and retest; the known Setu validation error has been fixed.

---

## 2026-05-18 Codex final update — Setu consent opens in-app

### What changed
- Updated `Sources/mone/Views/Onboarding/AAConsentView.swift`.
- Replaced external `openURL` consent launch with an in-app `SFSafariViewController` sheet via a SwiftUI `UIViewControllerRepresentable`.
- Added `import SafariServices`.
- `Continue to consent` now creates consent and presents the returned Setu consent URL inside the app.
- `Open consent again` reopens the same in-app Safari sheet.
- Updated helper text to say the consent opens in a secure in-app browser.

### Files modified
- `Sources/mone/Views/Onboarding/AAConsentView.swift`
- `HANDOFF.md`

### Build result
- Xcode live diagnostics were clean for `mone/Sources/mone/Views/Onboarding/AAConsentView.swift`.
- Full Xcode build completed successfully.

### Current working state
- Setu consent no longer opens as an external browser page from the primary flow.
- The app still uses Setu's hosted consent UI, but it is presented inside the app using `SFSafariViewController`.

### Assumptions
- In-app browser means native SafariServices, not a custom embedded WebView-only architecture.
- OTP behavior is Setu sandbox/FIP dependent:
  - Setu docs say Setu FIP sends a dynamic OTP to the mobile number used for consent.
  - Setu docs say Setu FIP-2 uses static OTP `123456`.

### Manual test checklist
1. Reach `AAConsentView`.
2. Tap `Continue to consent`.
3. Confirm Setu consent opens as an in-app sheet, not a separate Safari app/page.
4. Complete/close the sheet.
5. Confirm `Open consent again` reopens the in-app sheet.
6. Confirm `I've completed consent` advances onboarding.

### Next recommended step
- Retest the Setu sandbox consent UI in the simulator/device and use OTP `123456` only if the selected sandbox FIP is Setu FIP-2; otherwise expect a dynamic OTP to the consent mobile number.

---

## 2026-05-18 Codex note — Setu sandbox OTP clarification

### What changed
- User reported `123456` is not working in the Setu hosted consent flow.
- Rechecked Setu docs/search results.
- Current understanding:
  - `123456` is not a universal OTP for every Setu AA sandbox screen.
  - Setu docs state Setu FIP sends a dynamic OTP to the mobile number used for consent.
  - Setu docs state Setu FIP-2 uses static OTP `123456`.
- Therefore, if `123456` fails, the user is probably not at the Setu FIP-2 static OTP step, or the selected AA/FIP route is not using FIP-2.

### Files modified
- `HANDOFF.md`

### Current working state
- No app/backend code changed for this note.
- Setu consent opens in-app via `SFSafariViewController`.

### Assumptions
- The OTP shown in the Setu-hosted UI depends on the AA/FIP selected/routed inside Setu.

### Unresolved issues
- Need to identify which Setu hosted screen is asking for OTP:
  - mobile login/verification OTP
  - AA account linking OTP
  - specific FIP/FIP-2 OTP
- If using the prefilled `9876543210`, confirm whether that number can receive the dynamic OTP or whether Setu Bridge has a documented static OTP/test-number pairing for the configured sandbox product.

### Next recommended step
- In the Setu hosted UI, note the selected FIP/AA route. Use `123456` only for Setu FIP-2; otherwise check the dynamic OTP delivery path or request the correct sandbox test number/OTP from Setu Bridge/support.

---

## 2026-05-18 Codex final update — Setu sandbox mobile prefill changed

### What changed
- Updated `Sources/mone/Views/Onboarding/AAConsentView.swift`.
- Changed the AA consent sandbox fallback mobile number from `9876543210` to `8828290489`.
- The text field placeholder now uses the same `sandboxMobileNumber` constant, so it also shows `8828290489`.
- Phone-auth users with a valid Supabase session phone still prefill from their actual session phone; this fallback applies only when no valid session phone is available.

### Files modified
- `Sources/mone/Views/Onboarding/AAConsentView.swift`
- `HANDOFF.md`

### Build result
- Xcode live diagnostics were clean for `mone/Sources/mone/Views/Onboarding/AAConsentView.swift`.
- Full Xcode build completed successfully.

### Current working state
- Email-auth users or users without a valid session phone will see `8828290489` prefilled on `AAConsentView`.
- Backend Setu consent request receives whatever 10-digit mobile is currently in that field.

### Assumptions
- `8828290489` is the sandbox/test number the user wants to try for receiving the Setu dynamic OTP.

### Next recommended step
- Retest Setu consent with `8828290489`; if dynamic OTP still does not arrive, verify in Setu Bridge/support whether that number is enabled/whitelisted for the selected AA/FIP route.

---

## 2026-05-18 Codex update — Backend sandbox mobile fallback in progress

### What changed
- User clarified they also want backend behavior changed for the new sandbox mobile number.
- Current iOS already sends the field value, but backend still returns `Mobile number is required...` if both request body and `user.phone` are absent.
- Plan: add backend fallback `8828290489` so `setu-aa-create-consent` uses that when the request body and Supabase session have no mobile number.

### Files modified
- `HANDOFF.md`

### Current working state
- No backend code changed yet in this pass.

### Assumptions
- Backend fallback should be `8828290489`, matching the updated iOS default.
- Request body `mobileNumber` should still take precedence over the backend fallback.

### Unresolved issues
- Need to patch and redeploy `setu-aa-create-consent`.

### Next recommended step
- Add backend sandbox fallback constant, then update handoff with deploy command.

---

## Financial data architecture foundation — in progress

### What changed
- Started the financial data architecture foundation task.
- Read `HANDOFF.md` completely and inspected repo structure.
- Confirmed actual filesystem paths are rooted at `Sources/mone/...`, not `mone/Sources/...`; Xcode project paths still display with `mone/...`.
- Confirmed Supabase client setup is in root `SupabaseClient.swift`.
- Confirmed app entry/routing is in `Sources/mone/App/MoneApp.swift`.
- Confirmed Setu Edge Functions exist under `mone-backend/supabase/functions/`.
- Confirmed Supabase CLI config exists at `mone-backend/supabase/config.toml`; migrations are enabled but no migration files/folder existed yet.
- Created `docs/financial-data-model.md`.

### Files modified
- `docs/financial-data-model.md`
- `HANDOFF.md`

### Current working state
- Architecture documentation exists.
- Database migration and callback persistence are not implemented yet.

### Assumptions
- New SQL should live under `mone-backend/supabase/migrations/` because this repo contains a Supabase CLI project in `mone-backend/supabase`.

### Unresolved issues
- Need to add stable integration/raw-evidence migration.
- Need to update `setu-aa-callback` to persist webhook events and raw FI artifacts.
- Need to run reasonable checks after changes.

### Next recommended step
- Add the Supabase migration for `aa_data_sessions`, `financial_data_artifacts`, and non-destructive AA table improvements.

### 2026-05-18 update — migration added

#### What changed
- Added Supabase migration `mone-backend/supabase/migrations/202605180001_financial_data_foundation.sql`.
- The migration creates the stable integration/raw-evidence foundation without creating premature canonical transaction/category/nudge tables.
- New table: `public.aa_data_sessions` for Setu AA data-session lifecycle tracking.
- New table: `public.financial_data_artifacts` for exact raw FI payload artifacts.
- Non-destructively improves `public.aa_webhook_events` with consent/session/event/status/payload/header/timestamp columns.
- Non-destructively improves `public.aa_consents` with requested FI/consent type arrays and webhook-derived status timestamp fields.
- Enables RLS and adds read-own policies for authenticated users only; no client insert/update/delete policies were added for integration/raw tables.

#### Files modified
- `mone-backend/supabase/migrations/202605180001_financial_data_foundation.sql`
- `HANDOFF.md`

#### Current working state
- Architecture doc exists.
- Database foundation migration exists but has not been applied from this Codex session.
- `setu-aa-callback` still needs to be patched to persist webhook events.

#### Assumptions
- This repo should use Supabase CLI migrations under `mone-backend/supabase/migrations/`.
- Edge Functions using service role will write `aa_webhook_events`, `aa_data_sessions`, and `financial_data_artifacts`.

#### Unresolved issues
- Need to update `setu-aa-callback` to persist webhook payloads, update consent/session state best-effort, and store raw FI artifacts when present.
- Need to run reasonable checks after callback changes.

#### Next recommended step
- Patch `mone-backend/supabase/functions/setu-aa-callback/index.ts`.

### 2026-05-18 update — callback persistence implemented

#### What changed
- Updated `mone-backend/supabase/functions/setu-aa-callback/index.ts` from acknowledgement-only logging to durable callback persistence.
- The callback remains public/no-JWT compatible for Setu server-to-server webhooks.
- It uses the Supabase service-role/secret key only inside the Edge Function environment.
- It safely parses JSON and returns clear JSON errors for invalid method or invalid JSON.
- It stores every valid callback payload into `public.aa_webhook_events` with redacted request headers.
- It extracts consent id, data-session id, event type, and status best-effort without assuming one rigid payload shape.
- If a consent id matches `aa_consents`, it infers `user_id` and updates `last_webhook_status`, `status`, and approved/rejected/revoked timestamps best-effort.
- If a data-session id is present, it upserts `public.aa_data_sessions` with the latest status and callback payload.
- If the callback contains apparent raw FI data, it inserts an immutable `public.financial_data_artifacts` row with source metadata and a payload hash.
- Logs only safe metadata: event type, status, and whether consent/session/raw FI data were present. It does not log full payloads, tokens, secrets, full phone numbers, or raw financial data.

#### Files modified
- `mone-backend/supabase/functions/setu-aa-callback/index.ts`
- `HANDOFF.md`

#### Current working state
- Architecture doc exists.
- Database foundation migration exists but has not been applied from this Codex session.
- Callback persistence source code is implemented.
- `deno check` was attempted after the callback patch, but it hung and was interrupted by the user.

#### Assumptions
- Edge Function environment contains `SUPABASE_URL` and either `SUPABASE_SERVICE_ROLE_KEY` or `SUPABASE_SECRET_KEYS.default`.
- Setu callback payload shape may vary, so extraction is intentionally best-effort and conservative.
- Raw FI artifact storage only triggers when recognizable FI-like fields such as `fiData`, `FIData`, `financialInformation`, or `accounts` are present.

#### Unresolved issues
- Need to run TypeScript checks outside the stuck Deno invocation or with a strict timeout.
- Need to apply the migration and redeploy `setu-aa-callback` before end-to-end testing.

#### Next recommended step
- Apply the migration and deploy `setu-aa-callback`, then verify with a simulated callback. Avoid retrying the same unbounded `deno check` command in this environment.

---

## 2026-05-18 Codex final update — Backend sandbox mobile fallback changed

### What changed
- Updated `mone-backend/supabase/functions/setu-aa-create-consent/index.ts`.
- Added `DEFAULT_SANDBOX_MOBILE_NUMBER = "8828290489"`.
- Backend mobile selection now uses:
  1. request body `mobileNumber`
  2. Supabase Auth `user.phone`
  3. fallback `8828290489`
- This aligns backend behavior with the current iOS `AAConsentView` default.

### Files modified
- `mone-backend/supabase/functions/setu-aa-create-consent/index.ts`
- `HANDOFF.md`

### Current working state
- Backend source is patched.
- No iOS code changed in this pass.
- No Xcode build needed for this backend-only change.

### Assumptions
- `8828290489` is the desired sandbox/test mobile for Setu AA consent attempts.
- Passing an explicit `mobileNumber` from iOS should continue to override backend fallback.

### Deploy command
- From `mone-backend/supabase`:
  - `supabase functions deploy setu-aa-create-consent --project-ref bvgswlacgejikbuuwnpy`

### Manual test checklist
1. Redeploy `setu-aa-create-consent`.
2. Call it from iOS with the visible `8828290489` field.
3. Optionally test a request without `mobileNumber` and without `user.phone`; backend should use `8828290489`.
4. Inspect Setu/Supabase logs for the VUA/mobile sent if OTP still does not arrive.

### Next recommended step
- Redeploy the function and retest Setu consent with `8828290489`.

---

## 2026-05-18 Codex update — In-app Setu consent browser in progress

### What changed
- User confirmed consent creation now opens a new web page and asked whether it can open inside the app.
- User also asked which OTP to use for the Setu sandbox.
- Current `AAConsentView` uses SwiftUI `openURL`, which leaves the app for the consent page.
- Plan is to use native `SFSafariViewController` in a SwiftUI sheet. This keeps the Setu web consent flow inside the app while preserving Safari security/session behavior.

### Files modified
- `HANDOFF.md`

### Current working state
- No code changes for this pass yet.

### Assumptions
- In-app browser means an in-app Safari sheet, not a custom WebView-only app architecture.
- Setu OTP behavior should be answered from Setu docs and may depend on which sandbox FIP appears in the consent journey.

### Unresolved issues
- Need to replace `openURL` with `SFSafariViewController` sheet in `AAConsentView`.
- Need to build after the SwiftUI/UIKit bridge change.

### Next recommended step
- Patch `AAConsentView` with a SafariServices wrapper, then run Xcode diagnostics/build.

---

## Financial data architecture foundation

### What changed
- Created `docs/financial-data-model.md`.
- Added Supabase migration `mone-backend/supabase/migrations/202605180001_financial_data_foundation.sql`.
- Updated `mone-backend/supabase/functions/setu-aa-callback/index.ts` to persist Setu callback events and raw evidence.
- No iOS SwiftUI files were changed for this task.

### Layered architecture summary
Moné's financial intelligence should be built from a clean pipeline: Setu/AA integration events -> raw evidence artifacts -> canonical financial model -> derived intelligence/nudges. Current work only establishes the first two layers.

The architecture document explains:
- Layer 1: integration state for Setu/AA consents, webhook events, and data sessions.
- Layer 2: exact raw FI payload artifacts before interpretation.
- Layer 3: future Moné-owned canonical financial records such as accounts, balances, transactions, investments, insurance, pension, and obligations.
- Layer 4: future derived intelligence such as income streams, recurring commitments, spending patterns, cashflow risk, goal drift, and nudges.

### New/updated tables
- `public.aa_data_sessions`
  - Tracks Setu AA data-session lifecycle.
  - Columns include `user_id`, `setu_consent_id`, `setu_data_session_id`, status, request/response/error payloads, and timestamps.
- `public.financial_data_artifacts`
  - Stores exact raw FI payloads from Setu before parsing.
  - Columns include user/consent/session linkage, source metadata, FI type, FIP id, artifact kind, schema version, payload hash, and timestamps.
- `public.aa_webhook_events`
  - Non-destructively ensured columns for consent id, data-session id, event type, status, payload, redacted headers, and received timestamp.
- `public.aa_consents`
  - Non-destructively ensured columns for requested FI/consent types, last webhook status, and approved/rejected/revoked timestamps.
- RLS is enabled for the integration/raw tables.
- Authenticated users can read only their own rows.
- No client insert/update/delete policies were added for the new integration/raw-evidence tables; Edge Functions using service role are expected to write them.

### Callback persistence behavior
- `setu-aa-callback` remains public/no-JWT compatible because Setu calls it server-to-server.
- The function uses Supabase service-role/secret key only inside the Edge Function environment.
- It stores every valid callback payload in `public.aa_webhook_events`.
- It redacts sensitive headers before storing headers.
- It extracts consent id, data-session id, event type, and status best-effort from variable Setu payload shapes.
- If a consent id matches an `aa_consents` row, it infers `user_id` and updates consent status fields best-effort.
- If a data-session id is present, it upserts `aa_data_sessions`.
- If the callback contains apparent raw FI data, it stores an immutable `financial_data_artifacts` row with source metadata and a SHA-256 payload hash.
- It logs safe metadata only and avoids logging full payloads, financial data, tokens, secrets, full phone numbers, or user IDs.

### Intentionally not implemented
- FI data-session creation.
- FI data fetch orchestration.
- Transaction parsing or categorisation.
- Canonical account, balance, transaction, investment, insurance, pension, or obligation tables.
- Income detection, recurring-payment detection, spending analysis, cashflow forecasting, goal-risk scoring, or nudges.

### Files modified
- `docs/financial-data-model.md`
- `mone-backend/supabase/migrations/202605180001_financial_data_foundation.sql`
- `mone-backend/supabase/functions/setu-aa-callback/index.ts`
- `HANDOFF.md`

### Current working state
- Documentation and migration are in place.
- Callback persistence source code is implemented.
- Migration has not been applied from this Codex session.
- Edge Function has not been deployed from this Codex session.
- No iOS code was touched; auth/onboarding/logout/delete account UI flows should be unchanged by this task.

### Checks/build
- `deno check mone-backend/supabase/functions/setu-aa-callback/index.ts` was attempted, but it hung and the user interrupted the command. Do not retry blindly; use a shorter timeout or run checks outside the stuck environment.
- No Xcode build was run because this task made no Swift/iOS changes.
- A lightweight source review was performed after the interrupted Deno check.

### Deployment/apply commands
From `mone-backend/supabase`:
- Apply migration:
  - `supabase db push --linked`
- Deploy callback function:
  - `supabase functions deploy setu-aa-callback --project-ref bvgswlacgejikbuuwnpy`

### Assumptions
- Edge Function environment has `SUPABASE_URL` and either `SUPABASE_SERVICE_ROLE_KEY` or `SUPABASE_SECRET_KEYS.default`.
- `aa_consents.setu_consent_id` contains the Setu consent id returned by `setu-aa-create-consent`, allowing callback rows to infer `user_id`.
- Setu callback payload shape may vary, so extraction helpers are intentionally best-effort.

### Unresolved issues
- Need to apply the migration to the linked Supabase project.
- Need to deploy `setu-aa-callback`.
- Need to trigger or simulate a callback and inspect actual Setu payload shape before designing canonical financial tables.

### Manual verification checklist
1. Trigger or simulate Setu callback.
2. Confirm `aa_webhook_events` receives a row.
3. Confirm consent status updates if payload includes consent id/status.
4. Confirm `aa_data_sessions` updates if payload includes data session id/status.
5. Confirm raw FI artifact is stored only if callback contains FI data.
6. Confirm no iOS client secrets were added.
7. Confirm existing auth/onboarding/logout/delete account flows are untouched.

### Next recommended step
- Apply the migration, deploy `setu-aa-callback`, then simulate one callback payload with a known `setu_consent_id` and confirm the database writes before starting FI fetch or canonical modeling work.

---

## Setu AA data fetch stage — in progress

### What changed
- Started backend data-fetch stage for Setu Account Aggregator.
- Re-read `HANDOFF.md` and `docs/financial-data-model.md`.
- Inspected existing Setu Edge Functions and Supabase migration/config.
- Confirmed existing `setu-aa-callback` persists events/raw artifacts but does not create data sessions or fetch FI data yet.
- Found `mone-backend/supabase/config.toml` still has `verify_jwt = true` for `setu-aa-callback`, which conflicts with public Setu server-to-server callback behavior and should be corrected in this task.

### Files modified
- `HANDOFF.md`

### Current working state
- No data-fetch code changes have been made in this pass yet.

### Assumptions
- New backend-only functions should live under `mone-backend/supabase/functions/`.
- Shared helper code is acceptable under `mone-backend/supabase/functions/_shared/` to avoid duplicating Setu auth and Supabase env helpers.

### Unresolved issues
- Need to add shared helper, create `setu-aa-create-data-session`, create `setu-aa-fetch-fi-data`, update callback auto-fetch support, update docs, and update function config.

### Next recommended step
- Add the shared Setu helper and new Edge Function directories.

### 2026-05-18 update — shared helper and artifact idempotency started

#### What changed
- Added `mone-backend/supabase/functions/_shared/setu-aa.ts`.
- Shared helper includes Supabase env/key helpers, user/admin client builders, Setu access-token auth, Setu base/product/header helpers, JSON response helpers, status helpers, data-range extraction, payload hashing, and FI summary counters.
- Updated `mone-backend/supabase/migrations/202605180001_financial_data_foundation.sql` with a unique idempotency index for `financial_data_artifacts` based on source, data-session id, artifact kind, and payload hash.

#### Files modified
- `mone-backend/supabase/functions/_shared/setu-aa.ts`
- `mone-backend/supabase/migrations/202605180001_financial_data_foundation.sql`
- `HANDOFF.md`

#### Current working state
- Shared backend helper exists.
- Migration now has basic raw artifact duplicate protection.
- New data-session/fetch functions are not added yet.
- Callback is not yet updated for auto-create/auto-fetch.

#### Assumptions
- `SETU_AA_BASE_URL` should be used directly for `/sessions`; if the deployed environment includes `/v2`, the function will call `/v2/sessions`.
- Exact Setu FI payload shape is still unknown, so summary counters remain generic.

#### Unresolved issues
- Need to add `setu-aa-create-data-session`.
- Need to add `setu-aa-fetch-fi-data`.
- Need to update `setu-aa-callback`.
- Need to update docs/config and run bounded checks.

#### Next recommended step
- Add `setu-aa-create-data-session`.

### 2026-05-18 update — data-session and FI-fetch functions added

#### What changed
- Added `mone-backend/supabase/functions/setu-aa-create-data-session/`.
- Added `mone-backend/supabase/functions/setu-aa-fetch-fi-data/`.
- `setu-aa-create-data-session` requires a signed-in Supabase user, verifies the consent belongs to that user, checks approved/active-like consent status, calls Setu `POST /sessions`, upserts `aa_data_sessions`, and returns only data-session metadata.
- `setu-aa-fetch-fi-data` requires a signed-in Supabase user, verifies the data session belongs to that user, calls Setu `GET /sessions/:id`, updates `aa_data_sessions`, stores the full raw Setu response in `financial_data_artifacts`, and returns only summary metadata.
- Both functions keep Setu credentials and Supabase service-role key server-side only.

#### Files modified
- `mone-backend/supabase/functions/setu-aa-create-data-session/.npmrc`
- `mone-backend/supabase/functions/setu-aa-create-data-session/deno.json`
- `mone-backend/supabase/functions/setu-aa-create-data-session/index.ts`
- `mone-backend/supabase/functions/setu-aa-fetch-fi-data/.npmrc`
- `mone-backend/supabase/functions/setu-aa-fetch-fi-data/deno.json`
- `mone-backend/supabase/functions/setu-aa-fetch-fi-data/index.ts`
- `HANDOFF.md`

#### Current working state
- Authenticated manual/client backend paths exist for creating data sessions and fetching FI data.
- Callback-side auto-create/auto-fetch is not wired yet.
- `mone-backend/supabase/config.toml` has not yet been updated for the new functions.

#### Assumptions
- `SETU_AA_BASE_URL` points to the Setu FIU API base that supports `/sessions`.
- Existing `aa_consents.request_payload.dataRange` should be reused for session creation; if absent, helper falls back to a one-month range.

#### Unresolved issues
- Need to update `setu-aa-callback` for best-effort auto-create/auto-fetch.
- Need to update `config.toml`.
- Need bounded checks.

#### Next recommended step
- Patch `setu-aa-callback`.

### 2026-05-18 update — callback automation, config, and docs patched

#### What changed
- Updated `mone-backend/supabase/functions/setu-aa-callback/index.ts`.
- Callback still stores every valid webhook row first.
- If callback contains raw FI data, it stores that data directly in `financial_data_artifacts` as `SETU_AA_WEBHOOK_FI_DATA`.
- If callback contains a data-session id and a ready-like status (`PARTIAL`, `COMPLETED`, or `READY`) but no FI data, it fetches Setu `GET /sessions/:id` server-side and stores the raw fetch response as `FI_DATA_FETCH_RESPONSE`.
- If callback contains a consent id with approved/active-like status and no data-session id, it checks for an existing non-terminal data session before creating a new Setu data session.
- Updated `mone-backend/supabase/config.toml`:
  - `setu-aa-callback.verify_jwt = false`
  - added `setu-aa-create-data-session`
  - added `setu-aa-fetch-fi-data`
- Updated `docs/financial-data-model.md` with data-session lifecycle, FI-fetch lifecycle, and the reason fetched FI data remains raw evidence first.

#### Files modified
- `mone-backend/supabase/functions/setu-aa-callback/index.ts`
- `mone-backend/supabase/config.toml`
- `docs/financial-data-model.md`
- `HANDOFF.md`

#### Current working state
- Backend data-fetch source code is implemented.
- Callback is no-JWT compatible in local Supabase config.
- Bounded `deno check` was attempted but still hung in this environment and was interrupted by the user.
- Manual source review found and fixed a callback hardening issue: data-session-only callbacks now infer `setu_consent_id` from the existing session row and avoid overwriting it with null.

#### Assumptions
- Callback automation should be conservative and best-effort; webhook storage succeeds or fails independently from create/fetch automation.
- Ready-like data-session statuses include `PARTIAL`, `COMPLETED`, and `READY`.

#### Unresolved issues
- Need final handoff section with deploy commands and manual checklist after checks.
- Need TypeScript checks in a non-hanging environment before deployment if possible.

#### Next recommended step
- Add final deployment/manual verification handoff section.

---

## Setu AA data fetch stage

### What changed
- Added backend data-fetch foundation for Setu Account Aggregator.
- Added shared helper module `mone-backend/supabase/functions/_shared/setu-aa.ts`.
- Added Edge Function `setu-aa-create-data-session`.
- Added Edge Function `setu-aa-fetch-fi-data`.
- Updated Edge Function `setu-aa-callback`.
- Updated Supabase function config in `mone-backend/supabase/config.toml`.
- Updated `docs/financial-data-model.md`.
- Updated `mone-backend/supabase/migrations/202605180001_financial_data_foundation.sql` with raw artifact idempotency index.
- No iOS files were changed for this task.

### Functions added

#### `setu-aa-create-data-session`
Path:
- `mone-backend/supabase/functions/setu-aa-create-data-session/index.ts`

Behavior:
- Requires signed-in Supabase user.
- Accepts:
  ```json
  {
    "consentId": "setu-consent-id"
  }
  ```
- Verifies the current Supabase user.
- Looks up `public.aa_consents` by `setu_consent_id`.
- Ensures the consent belongs to the current user.
- Requires approved/active-like consent status.
- Reuses existing non-terminal `aa_data_sessions` row for the consent when present.
- Calls Setu `POST {SETU_AA_BASE_URL}/sessions`.
- Stores request/response in `public.aa_data_sessions`.
- Returns only metadata:
  ```json
  {
    "dataSessionId": "...",
    "status": "...",
    "consentId": "..."
  }
  ```

#### `setu-aa-fetch-fi-data`
Path:
- `mone-backend/supabase/functions/setu-aa-fetch-fi-data/index.ts`

Behavior:
- Requires signed-in Supabase user.
- Accepts:
  ```json
  {
    "dataSessionId": "setu-data-session-id"
  }
  ```
- Verifies the current Supabase user.
- Looks up `public.aa_data_sessions` and ensures it belongs to the current user.
- Calls Setu `GET {SETU_AA_BASE_URL}/sessions/:id`.
- Updates `aa_data_sessions.status` and `response_payload`.
- Stores the full raw Setu response in `public.financial_data_artifacts` as `FI_DATA_FETCH_RESPONSE`.
- Returns only summary metadata:
  ```json
  {
    "dataSessionId": "...",
    "status": "...",
    "artifactId": "...",
    "fipCount": 0,
    "accountCount": 0
  }
  ```

### Functions updated

#### `setu-aa-callback`
Path:
- `mone-backend/supabase/functions/setu-aa-callback/index.ts`

Behavior:
- Remains public/no-JWT compatible for Setu server-to-server callbacks.
- Stores every valid webhook payload in `public.aa_webhook_events`.
- Redacts sensitive headers before storing.
- Updates `aa_consents` status fields best-effort.
- Upserts `aa_data_sessions` when callback includes a data-session id.
- If callback contains `fiData`/FI-like payload, stores it directly in `financial_data_artifacts` as `SETU_AA_WEBHOOK_FI_DATA`.
- If callback indicates data ready and has a data-session id, fetches FI data server-side and stores it as `FI_DATA_FETCH_RESPONSE`.
- If callback indicates approved/active consent and no data-session id, checks for an existing non-terminal data session before creating one.
- Logs only safe metadata.

### Tables touched
- `public.aa_consents`
- `public.aa_webhook_events`
- `public.aa_data_sessions`
- `public.financial_data_artifacts`

### Idempotency
- `aa_data_sessions.setu_data_session_id` is unique.
- `financial_data_artifacts` now has `financial_data_artifacts_idempotency_idx` over source, data-session id, artifact kind, and payload hash.
- Fetch and callback code also checks for an existing matching artifact before inserting.

### Current behavior
- Backend can now create Setu data sessions after consent approval.
- Backend can fetch FI data for a data session.
- Callback can support both Setu Auto-Fetch and non-Auto-Fetch modes:
  - Auto-Fetch: callback includes FI data; store it directly.
  - No Auto-Fetch: callback says data ready; backend fetches via session id.
- Raw FI data is stored only as raw evidence artifacts.
- No canonical transaction/account/category/nudge model has been created.
- No full FI payload is returned to iOS.
- No client secrets were added.

### Known limitations
- TypeScript/Deno checks could not complete in this Xcode/Codex environment; `deno check` hung even with an attempted timeout and was interrupted by the user.
- Setu payload shapes are still best-effort until real sandbox callbacks/fetch responses are inspected.
- `extractDataRange` falls back to a one-month range only if stored consent request/response payloads do not include `dataRange`; current `setu-aa-create-consent` stores the original request payload with a six-month data range.
- Callback automation is intentionally conservative. If Setu payload shape is unclear, it still stores the webhook event and avoids crashing, but may skip auto-create/auto-fetch.

### Deploy commands
From `mone-backend/supabase`:
- Apply DB migration:
  - `supabase db push --linked`
- Deploy create data session:
  - `supabase functions deploy setu-aa-create-data-session --project-ref bvgswlacgejikbuuwnpy`
- Deploy fetch FI data:
  - `supabase functions deploy setu-aa-fetch-fi-data --project-ref bvgswlacgejikbuuwnpy`
- Deploy callback without JWT verification:
  - `supabase functions deploy setu-aa-callback --project-ref bvgswlacgejikbuuwnpy --no-verify-jwt`

### Manual verification checklist
1. Approve a Setu AA consent in sandbox.
2. Confirm `aa_consents` reflects approved/active status.
3. Call `setu-aa-create-data-session` for that consent.
4. Confirm `aa_data_sessions` gets a row.
5. Wait for Setu data-ready callback or trigger flow in sandbox.
6. Confirm `aa_webhook_events` receives callback rows.
7. Call `setu-aa-fetch-fi-data` with the data session ID.
8. Confirm `financial_data_artifacts` gets a raw payload row.
9. Confirm no canonical transaction/category tables are created yet.
10. Confirm iOS auth/onboarding/logout/delete-account flows are untouched.

### Next recommended step
- Run TypeScript checks in a terminal where Deno can complete, then apply the migration, deploy the three functions, and test the sandbox lifecycle end to end.

### 2026-05-18 command correction

#### What changed
- User reported `supabase db push --project-ref bvgswlacgejikbuuwnpy` fails because this Supabase CLI version does not support `--project-ref` on `db push`.
- Corrected current handoff migration command to use the linked project:
  - from `mone-backend/supabase`: `supabase db push --linked`
  - from `mone-backend`: `supabase db push --workdir supabase --linked`
- Confirmed `supabase functions deploy` still supports `--project-ref` in this installed CLI.
- User then reported the CLI says `Cannot find project ref. Have you run supabase link?` even though `mone-backend/supabase/.temp/linked-project.json` exists in the repo.
- Codex attempted `supabase status --workdir .`; it hung and the user interrupted it. Do not run Supabase status/db commands from Codex in this environment again; ask the user to run them.

#### Files modified
- `HANDOFF.md`

#### Current working state
- No source code changed in this correction.
- Migration still needs to be applied.
- Functions still need deployment.

#### Next recommended step
- From `mone-backend`, relink explicitly:
  - `supabase link --workdir supabase --project-ref bvgswlacgejikbuuwnpy`
- Then apply migrations:
  - `supabase db push --workdir supabase`
- If link still fails, use a direct DB URL instead:
  - `supabase db push --workdir supabase --db-url "postgresql://postgres:<PASSWORD>@db.bvgswlacgejikbuuwnpy.supabase.co:5432/postgres"`
  - Percent-encode special characters in `<PASSWORD>`.

### 2026-05-18 function deploy command correction

#### What changed
- User reported migration/linking succeeded, but function deploy failed with `Entrypoint path does not exist` while running deploy commands from `mone-backend` with `--workdir supabase`.
- Local source files do exist at:
  - `mone-backend/supabase/functions/setu-aa-create-data-session/index.ts`
  - `mone-backend/supabase/functions/setu-aa-fetch-fi-data/index.ts`
  - `mone-backend/supabase/functions/setu-aa-callback/index.ts`
- `mone-backend/supabase/config.toml` uses entrypoints like `./functions/<name>/index.ts`.
- Correct deploy approach for this CLI/project layout is to run from inside `mone-backend/supabase` and use `--workdir .` or omit `--workdir`.

#### Files modified
- `HANDOFF.md`

#### Correct deploy commands
From `mone-backend/supabase`:
- `supabase functions deploy setu-aa-create-data-session --workdir . --project-ref bvgswlacgejikbuuwnpy`
- `supabase functions deploy setu-aa-fetch-fi-data --workdir . --project-ref bvgswlacgejikbuuwnpy`
- `supabase functions deploy setu-aa-callback --workdir . --project-ref bvgswlacgejikbuuwnpy --no-verify-jwt`

Alternative from `mone-backend/supabase`:
- `supabase functions deploy setu-aa-create-data-session --project-ref bvgswlacgejikbuuwnpy`
- `supabase functions deploy setu-aa-fetch-fi-data --project-ref bvgswlacgejikbuuwnpy`
- `supabase functions deploy setu-aa-callback --project-ref bvgswlacgejikbuuwnpy --no-verify-jwt`

#### Current working state
- Migration/linking reportedly ran before function deploy.
- Function deployment is still pending due to path/workdir command mismatch.

#### Next recommended step
- `cd mone-backend/supabase`, then run the corrected deploy commands above.

---

## 2026-05-18 Setu callback schema drift fix

### What changed
- User reported deployed `setu-aa-callback` inserts a `status` field into `public.aa_webhook_events`, but the cloud database was missing that column.
- User manually fixed production with:
  - `alter table public.aa_webhook_events add column if not exists status text;`
  - `notify pgrst, 'reload schema';`
- Added a dedicated follow-up migration so repo SQL matches production:
  - `mone-backend/supabase/migrations/202605180002_ensure_aa_webhook_events_status.sql`

### Files modified
- `mone-backend/supabase/migrations/202605180002_ensure_aa_webhook_events_status.sql`
- `HANDOFF.md`

### Current working state
- `aa_webhook_events.status` is already present in the earlier foundation migration, but the new follow-up migration explicitly protects environments where the earlier migration was applied before that column existed or where schema drift occurred.
- `setu-aa-callback` requires `public.aa_webhook_events.status` because it inserts the extracted Setu callback/data-session status into that column.

### Assumptions
- Production has already been manually patched and PostgREST schema was reloaded.
- The follow-up migration is still useful as source-of-truth and for local/future environments.

### Unresolved issues
- Need to apply the new follow-up migration in any environment that did not receive the manual patch.

### Next recommended step
- Run migration apply from the Supabase project directory when CLI is usable, or apply the SQL manually if the CLI remains unreliable.

---

## 2026-05-18 Setu AA broad FI consent scope

### What changed
- User reported the latest fetched Setu FI payload only contained `decryptedFI.type = "deposit"` even though Setu product setup selected many data types.
- Audited `mone-backend/supabase/functions/setu-aa-create-consent/index.ts`.
- Confirmed `fiTypes` was hardcoded to `["DEPOSIT"]`.
- Replaced the hardcoded `fiTypes` with a configurable helper.
- Default requested FI types are now:
  - `DEPOSIT`
  - `TERM_DEPOSIT`
  - `RECURRING_DEPOSIT`
  - `MUTUAL_FUNDS`
  - `ETF`
  - `EQUITIES`
  - `NPS`
  - `INSURANCE_POLICIES`
  - `GSTR1_3B`
- Added optional `SETU_AA_FI_TYPES` env override, parsed as a comma-separated list.
- Kept consent types broad:
  - `PROFILE`
  - `SUMMARY`
  - `TRANSACTIONS`
- `setu-aa-create-consent` now stores:
  - `aa_consents.requested_fi_types`
  - `aa_consents.requested_consent_types`
- Added safe logs for requested FI type count and requested consent types.
- Setu failure logs now include a bounded response preview rather than logging the full response object.
- Client error response no longer returns the full Setu response payload as `details`.

### Files modified
- `mone-backend/supabase/functions/setu-aa-create-consent/index.ts`
- `HANDOFF.md`

### Current working state
- Backend source is patched.
- No iOS code changed.
- No financial inference, transaction categorisation, canonical modelling, or nudges were added.
- No secrets were added to iOS.

### Important behavior note
- Setu product setup can allow many data types, but actual returned FI data depends on all of:
  - backend consent `fiTypes`
  - Setu sandbox support for those FI types
  - the selected AA/FIP route
  - accounts/data linked by the user in the consent journey
- Old consents will not change after modifying `fiTypes`; create a fresh consent to request the broader scope.

### Deployment note
From `mone-backend/supabase`, set the optional override if desired:
- `supabase secrets set SETU_AA_FI_TYPES="DEPOSIT,TERM_DEPOSIT,RECURRING_DEPOSIT,MUTUAL_FUNDS,ETF,EQUITIES,NPS,INSURANCE_POLICIES,GSTR1_3B"`

Then redeploy:
- `supabase functions deploy setu-aa-create-consent`

If deploying with explicit project ref from `mone-backend/supabase`:
- `supabase functions deploy setu-aa-create-consent --project-ref bvgswlacgejikbuuwnpy`

### Assumptions
- The default list represents the broadest reliable sandbox FI coverage currently desired for Moné.
- `aa_consents.requested_fi_types` and `aa_consents.requested_consent_types` exist from the financial data foundation migration.

### Checks
- No Supabase CLI or Deno commands were run because prior CLI/Deno commands have repeatedly hung in this environment.
- Source inspection was used for this backend-only change.

### Next recommended step
- Redeploy `setu-aa-create-consent`, create a fresh consent, then fetch FI data again and inspect the raw artifact payloads before changing canonical modelling.

---

## Setu consent completion debug — in progress

### What changed
- Started task to debug broad-FI Setu consent completion after alphanumeric Setu AA OTP could not be entered/completed in the current flow.
- Re-read `HANDOFF.md` and `docs/financial-data-model.md`.
- Inspected `Sources/mone/Views/Onboarding/AAConsentView.swift`.
- Confirmed iOS opens Setu `consentUrl` via `SFSafariViewController`.
- Confirmed the app does not render a native Setu OTP screen and does not restrict Setu OTP input directly. The only numeric restriction in `AAConsentView` is for the Moné-entered mobile number before consent creation.
- Inspected `setu-aa-create-data-session` and `setu-aa-fetch-fi-data`; they currently accept explicit consent/session IDs and do not yet guard against old DEPOSIT-only consents.

### Files modified
- `HANDOFF.md`

### Current working state
- No code changes for this pass yet.

### Assumptions
- External Safari is the preferred temporary/debug fallback for Setu AA OTP input problems.
- Old `["DEPOSIT"]` consents should not be used for broad-data verification unless explicitly allowed for debugging.

### Unresolved issues
- Need to add temporary debug copy/open-external controls for the latest Setu consent URL.
- Need to add backend guardrails against accidental old/narrow consent/session use.
- Need to update handoff with SQL/manual verification checklist after code changes.

### Next recommended step
- Patch `AAConsentView` and backend guardrails.

---

## Setu consent completion debug

### What changed
- Added a temporary/debug-only consent completion path in `Sources/mone/Views/Onboarding/AAConsentView.swift`.
- Confirmed current Setu consent presentation uses `SFSafariViewController`, not `WKWebView`.
- Confirmed the app does not provide a native Setu OTP screen and does not restrict Setu OTP format. The only numeric input restriction in this view is for Moné's mobile-number field before creating the Setu consent.
- When a consent URL exists, `AAConsentView` now shows a small `SETU DEBUG` panel with safe metadata:
  - `consentId`
  - status
  - requested FI type count, if returned by backend
  - whether URL exists
- Added temporary debug actions:
  - copy consent URL to clipboard
  - open consent URL in external Safari
- `setu-aa-create-consent` now returns `requestedFiTypeCount` in its response so iOS can show safe broad-scope metadata.
- Added backend guardrails to avoid accidentally using old DEPOSIT-only consents:
  - shared helper now defines broad Setu FI types and `isBroadSetuConsent(...)`
  - `setu-aa-create-data-session` rejects non-ready consents with `Complete the latest Setu consent before fetching financial data.`
  - `setu-aa-create-data-session` rejects narrow/non-broad consents unless request body includes `allowNarrowConsentForDebug: true`
  - `setu-aa-fetch-fi-data` rejects sessions tied to narrow/non-broad consents unless request body includes `allowNarrowConsentForDebug: true`
  - `setu-aa-callback` skips automatic data-session creation and FI fetch for narrow/non-broad consents

### Files modified
- `Sources/mone/Views/Onboarding/AAConsentView.swift`
- `mone-backend/supabase/functions/setu-aa-create-consent/index.ts`
- `mone-backend/supabase/functions/_shared/setu-aa.ts`
- `mone-backend/supabase/functions/setu-aa-create-data-session/index.ts`
- `mone-backend/supabase/functions/setu-aa-fetch-fi-data/index.ts`
- `mone-backend/supabase/functions/setu-aa-callback/index.ts`
- `HANDOFF.md`

### Current working state
- Temporary external Safari/copy debug path is implemented in the iOS AA consent screen.
- Primary in-app `SFSafariViewController` consent flow remains unchanged.
- Backend now prefers broad Setu consents by enforcing broad FI type coverage before creating/fetching data sessions.
- Old `["DEPOSIT"]` consents are treated as narrow and blocked by default for broad-data verification.
- Explicit debug override exists for backend calls only:
  - `allowNarrowConsentForDebug: true`
- No final production AA UX, financial dashboard, inference, categorisation, nudges, or canonical parser was added.
- No iOS secrets were added.

### Important distinction
- Moné app OTP remains the Supabase/2Factor OTP and may remain numeric.
- Setu AA OTP is controlled by Setu/AA/FIP and may be alphanumeric.
- Moné should not validate, format, restrict, or assume Setu AA OTP format.
- If Setu OTP input is awkward in the in-app browser, use the temporary `Open Safari` or `Copy URL` controls.

### Useful SQL
Check latest consents:
```sql
select
  setu_consent_id,
  status,
  last_webhook_status,
  request_payload->'fiTypes' as requested_fi_types,
  request_payload->'consentTypes' as requested_consent_types,
  setu_consent_url,
  created_at,
  updated_at
from public.aa_consents
order by created_at desc
limit 10;
```

### Assumptions
- The latest broad consent is the one that should be completed and used for new data-session creation.
- A `["DEPOSIT"]`-only consent is old/narrow and should not be used for broad-data verification unless explicitly selected for debugging.
- Backend broad-scope checking uses the expected broad FI list:
  - `DEPOSIT`
  - `TERM_DEPOSIT`
  - `RECURRING_DEPOSIT`
  - `MUTUAL_FUNDS`
  - `ETF`
  - `EQUITIES`
  - `NPS`
  - `INSURANCE_POLICIES`
  - `GSTR1_3B`

### Checks
- Xcode live diagnostics were clean for:
  - `mone/Sources/mone/Views/Onboarding/AAConsentView.swift`
- Full Xcode build was not run.
- Deno/Supabase CLI checks were not run because prior Deno/Supabase commands repeatedly hung in this environment.
- Backend TypeScript changes were source-reviewed.

### Manual verification checklist
1. Confirm latest `aa_consents` row has broad `requested_fi_types`.
2. Confirm latest broad consent may initially be `PENDING`.
3. Open/copy the latest `consentUrl`.
4. Open the consent URL in external Safari if the in-app web flow blocks alphanumeric OTP.
5. Complete Setu OTP/consent flow.
6. Confirm `aa_consents` latest broad-FI row changes from `PENDING` to `ACTIVE`/approved or equivalent.
7. Create data session only for that broad ACTIVE consent.
8. Fetch FI data using the new data session.
9. Confirm `financial_data_artifacts` gets a new payload.
10. Confirm returned FI types from the new payload.
11. Confirm old DEPOSIT-only consent/session is not used for broad-data verification.
12. Confirm no iOS secrets were added.
13. Confirm existing login/onboarding/logout/delete-account flows are untouched.

### Deployment notes
- Redeploy `setu-aa-create-consent` so `requestedFiTypeCount` is returned to iOS.
- Redeploy `setu-aa-create-data-session`, `setu-aa-fetch-fi-data`, and `setu-aa-callback` so old/narrow consent guardrails are active.

### Next recommended step
- Deploy the updated functions, create/complete a fresh broad Setu consent through external Safari if needed, then create a data session and fetch FI data from that broad consent only.

---

## 2026-05-18 AA consent mobile edit fix

### What changed
- User reported that changing the prefilled mobile number in `AAConsentView` still resulted in the backend/Setu using the fallback number `8828290489`.
- Root cause found in iOS flow:
  - once `consentURL` existed, tapping the primary button returned early and reopened the old consent URL
  - changing the mobile number did not clear the previously-created consent state
  - therefore the app could appear to use the edited number, while actually reopening a consent that had already been created with the fallback number
- Updated `AAConsentView` so changing the mobile number after a consent is created clears:
  - `consentURL`
  - `consentId`
  - `consentStatus`
  - `requestedFiTypeCount`
  - copied URL state
- The next tap after editing the number now creates a fresh consent with the edited `mobileDigits`.
- Added safe debug display/logging of the mobile ending used for the consent.
- Updated `setu-aa-create-consent` safe logs with `mobileSourceKind`:
  - `request_body`
  - `session_phone`
  - `fallback`

### Files modified
- `Sources/mone/Views/Onboarding/AAConsentView.swift`
- `mone-backend/supabase/functions/setu-aa-create-consent/index.ts`
- `HANDOFF.md`

### Current working state
- iOS now invalidates stale Setu consent links when the mobile number changes.
- Backend still prioritizes request body mobile number over session phone and fallback.
- Backend source has an extra safe log field but must be redeployed for that log to appear in Supabase logs.

### Checks
- Xcode live diagnostics were clean for:
  - `mone/Sources/mone/Views/Onboarding/AAConsentView.swift`
- Full Xcode build was not run.
- Deno/Supabase CLI checks were not run because those commands have repeatedly hung in this environment.

### Next recommended step
- Redeploy `setu-aa-create-consent`.
- In the app, edit the mobile number before creating consent, confirm the debug panel shows the new mobile ending, and confirm Supabase logs show `mobileSourceKind: "request_body"`.


## Broad Setu fixture created

Created redacted Setu broad FI fixture:

`fixtures/setu/broad-fi-sandbox-redacted.json`

Purpose:
- Stable local fixture for parser development.
- Avoid depending on flaky Setu/OneMoney sandbox UI for every parser iteration.
- Preserve raw payload structure while removing sensitive values.

Do not commit:
- raw private payloads
- unredacted PAN/email/mobile/address/DOB/profile data

Next recommended step:
Implement canonical parser foundation:
- Parse `financial_data_artifacts` / fixture payload.
- Create canonical accounts.
- Create canonical transaction-like records.
- Keep parser idempotent.
- Do not implement income/spending/obligation/nudge inference yet.

---

## Canonical parser foundation — in progress

### What changed
- Started canonical parser foundation task.
- Re-read `HANDOFF.md` and `docs/financial-data-model.md`.
- Located fixture folder at `mone-backend/fixtures/setu/`.
- `mone-backend/fixtures/setu/README.md` documents broad fixture summary: 2 FIPs, 20 accounts, 9 FI types, 1600 transactions.
- `mone-backend/fixtures/setu/broad-fi-sandbox-redacted.json` currently appears to be `0` bytes in this checkout; do not rely on it until restored.
- A Node inspection command against the empty fixture hung and was interrupted by the user. Avoid rerunning that command.

### Files modified
- `HANDOFF.md`

### Current working state
- No parser/schema code has been added yet in this pass.

### Assumptions
- Parser should follow documented Setu shape: top-level FIP array, each FIP has `fipID`, `data[]`, `decryptedFI.type`, and `decryptedFI.account`.
- The redacted fixture should be restored before fixture-based count verification.

### Unresolved issues
- Need to add canonical account/transaction migration.
- Need to add parser code and Edge Function.
- Need to add fixture script with a clear empty-fixture error.

### Next recommended step
- Add canonical schema migration and shared parser module.

---

## Canonical parser foundation

### What changed
- Added canonical schema migration:
  - `mone-backend/supabase/migrations/202605180003_canonical_financial_parser_foundation.sql`
- Added shared Setu FI parser:
  - `mone-backend/supabase/functions/_shared/setu-fi-parser.ts`
- Added authenticated Edge Function:
  - `mone-backend/supabase/functions/parse-setu-fi-artifact/index.ts`
- Added fixture/dev parser script:
  - `mone-backend/scripts/parse-setu-fi-fixture.ts`
- Registered `parse-setu-fi-artifact` in:
  - `mone-backend/supabase/config.toml`
- Updated:
  - `docs/financial-data-model.md`
- No iOS files were changed.

### Tables added
- `public.financial_accounts`
  - Stores account/instrument-level records extracted from Setu FI data.
  - Preserves `raw_profile`, `raw_summary`, and `raw_account`.
  - Unique index on `user_id, source, link_ref_number` for idempotent account upserts where Setu provides a link reference.
- `public.financial_transactions`
  - Stores transaction-like records extracted from Setu account payloads.
  - Preserves `raw_transaction`.
  - Uses `txn_id` idempotency where available.
  - Adds `raw_transaction_hash` fallback for transaction rows without `txn_id`.
- RLS enabled on both tables.
- Authenticated users can select only their own rows.
- No client insert/update/delete policies were added; Edge Functions/service role write rows.

### Parser behavior
- Parser expects documented broad Setu shape:
  - top-level FIP array, or `fips`, `data.fips`, `payload.fips`
  - each FIP has `fipID`/`fipId`
  - each FIP has `data[]`
  - each data item has `decryptedFI.type`
  - each data item has `decryptedFI.account`
  - account may include profile, summary, and transactions
- Parser is defensive:
  - missing accounts are skipped
  - missing transactions do not crash parsing
  - missing transaction ids use raw transaction hash fallback
- Logs safe counts only:
  - FIP count
  - account count
  - transaction count
  - FI types
- Does not log profile details, PAN, mobile, email, address, full narration payloads, or raw financial data.
- Does not mutate `financial_data_artifacts`.

### Edge Function
`parse-setu-fi-artifact`

Expected input:
```json
{
  "artifactId": "..."
}
```

Behavior:
- Requires signed-in Supabase user.
- Verifies the artifact belongs to current user.
- Parses the artifact payload.
- Upserts `financial_accounts`.
- Inserts/upserts `financial_transactions`.
- Returns:
```json
{
  "accountCount": 20,
  "transactionCount": 1600,
  "insertedTransactionCount": 1600,
  "fiTypes": ["deposit"]
}
```

### Fixture script
Script:
- `mone-backend/scripts/parse-setu-fi-fixture.ts`

Run from `mone-backend`:
- `deno run --allow-read scripts/parse-setu-fi-fixture.ts`

Expected when fixture is restored:
- FIPs: 2
- accounts: 20
- FI types: 9
- transactions: 1600

Current caveat:
- `mone-backend/fixtures/setu/broad-fi-sandbox-redacted.json` appears to be `0` bytes in this checkout even though the README documents the broad fixture summary.
- Restore the redacted fixture before relying on local fixture parser counts.

### What is intentionally deferred
- Holdings-specific canonical tables.
- Insurance-policy-specific canonical tables.
- Tax/GSTR-specific canonical tables.
- Category tables.
- Income detection.
- Obligation detection.
- Spending classification.
- Cashflow forecasting.
- Goal-risk scoring.
- Nudges.
- Dashboard UI.

### Deployment commands
From `mone-backend/supabase`:
- Apply migration:
  - `supabase db push --linked`
- Deploy parser function:
  - `supabase functions deploy parse-setu-fi-artifact --project-ref bvgswlacgejikbuuwnpy`

If this CLI has the previously observed workdir/path issue, run from `mone-backend/supabase` and use:
- `supabase functions deploy parse-setu-fi-artifact --workdir . --project-ref bvgswlacgejikbuuwnpy`

### Manual verification checklist
1. Apply migration.
2. Deploy `parse-setu-fi-artifact`.
3. Find latest artifact for consent `8ab8c48e-be3c-42b4-a85b-34bf7cb62888`.
4. Call parser for that artifact.
5. Confirm `financial_accounts` has 20 rows or expected account count.
6. Confirm `financial_transactions` has 1600 rows or expected transaction count.
7. Re-run parser and confirm idempotency: no duplicates.
8. Confirm raw `financial_data_artifacts` remains unchanged.
9. Confirm no inference/nudge/category tables are created.

### Checks
- No Deno/Supabase CLI checks were run because those commands repeatedly hung in this environment.
- No Xcode build was run because no iOS files were changed.
- Source review was performed.

### Known limitations
- Parser field extraction is intentionally conservative and may need refinement after inspecting the restored redacted fixture or real broad artifact payloads.
- Transaction idempotency is strongest when Setu provides both `linkRefNumber` and `txnId`; otherwise it falls back to raw transaction hash.
- Fixture verification cannot pass until `mone-backend/fixtures/setu/broad-fi-sandbox-redacted.json` is restored from zero bytes.

### Next recommended step
- Restore the redacted broad fixture or use the latest broad production artifact, deploy `parse-setu-fi-artifact`, parse the artifact, and inspect canonical row counts before designing any holdings/policy/tax-specific canonical tables.

---

## 2026-05-18 Temporary parse artifact debug UI

### What changed
- Added a temporary developer-only parser trigger to the existing Setu/AA setup screen:
  - `Sources/mone/Views/Onboarding/AAConsentView.swift`
- The new `DEVELOPER DEBUG` card calls the deployed Supabase Edge Function:
  - `parse-setu-fi-artifact`
- The request uses the current signed-in Supabase session access token and sends:
```json
{
  "artifactId": "PASTE_ARTIFACT_ID_HERE"
}
```
- The artifact ID is editable in the UI and defaults to the placeholder `PASTE_ARTIFACT_ID_HERE`.
- The UI shows only safe parser summary fields:
  - account count
  - transaction count
  - inserted transaction count, if returned
  - FI types
- No raw financial payload, PAN, mobile, email, profile data, access token, or secrets are logged or displayed.

### Files modified
- `Sources/mone/Views/Onboarding/AAConsentView.swift`
- `HANDOFF.md`

### Current working state
- `parse-setu-fi-artifact` has a temporary in-app trigger in the Account Aggregator consent/setup area.
- User must be signed in.
- Artifact must belong to the current user or the Edge Function should reject it.
- This is intentionally a temporary debug path, not final production AA UX.

### How to use
1. Open the Setu/AA consent setup screen in the app.
2. In the `DEVELOPER DEBUG` card, replace `PASTE_ARTIFACT_ID_HERE` with a real `public.financial_data_artifacts.id`.
3. Tap `Parse artifact`.
4. Confirm the summary counts are shown in the app.
5. Confirm `financial_accounts` and `financial_transactions` are populated in Supabase.
6. Re-run with the same artifact to verify parser idempotency.

### Assumptions
- `parse-setu-fi-artifact` is deployed and configured with `verify_jwt = true`.
- The deployed function returns `accountCount`, `transactionCount`, optional `insertedTransactionCount`, and `fiTypes`.

### Checks
- Xcode live diagnostics were clean for:
  - `mone/Sources/mone/Views/Onboarding/AAConsentView.swift`
- Full Xcode build was not run for this small UI/debug wiring change.

### Unresolved issues
- Replace the placeholder with a real artifact UUID during manual testing.
- Remove this temporary debug UI before productionizing the AA flow.

### Next recommended step
- Use the latest broad Setu FI artifact ID in the debug card, parse it, verify canonical row counts, then inspect canonical records before designing any richer financial-domain tables or intelligence logic.

---

## 2026-05-18 Parse artifact debug error visibility

### What changed
- Improved the temporary `DEVELOPER DEBUG` parser card in `Sources/mone/Views/Onboarding/AAConsentView.swift`.
- The card now displays the HTTP status returned by `parse-setu-fi-artifact`.
- Parser errors now safely handle common Supabase/function response shapes:
  - `{ "error": "..." }`
  - `{ "message": "..." }`
  - `{ "msg": "..." }`
- If the function returns a 2xx response with an unexpected body shape, the UI now says the parser returned an unexpected response and suggests confirming the latest function is deployed.
- If the app cannot reach the function, the UI now says to check connection/deployment.
- No raw financial payloads, tokens, PAN, mobile, email, or profile details are displayed or logged.

### Files modified
- `Sources/mone/Views/Onboarding/AAConsentView.swift`
- `HANDOFF.md`

### Current working state
- The previous generic `Could not parse artifact. Please try again.` fallback should now be replaced by a safer, more actionable message with HTTP status.
- Expected helpful cases:
  - HTTP `404`: function not deployed at this project ref, or artifact ID not found/not owned by current user.
  - HTTP `401`/`403`: current session rejected; sign in again.
  - HTTP `500`: check Supabase Edge Function logs, likely parser write/schema issue.

### Checks
- Xcode live diagnostics were clean for:
  - `mone/Sources/mone/Views/Onboarding/AAConsentView.swift`

### Next recommended step
- Re-run the parse action in the app and note the HTTP status/message shown. If it is HTTP `500`, inspect Supabase logs for `parse_setu_fi_artifact_unhandled_error` or table/migration errors.

---

## 2026-05-18 Parse artifact network error detail

### What changed
- User saw the parser debug card report: `Could not reach parser function. Check connection and deployment.`
- Updated `Sources/mone/Views/Onboarding/AAConsentView.swift` to show safe URLSession/URLError details when the parser request fails before receiving an HTTP response.
- New transport failure format:
  - `Could not reach parser function. Network error <code>: <localized description>`
- This still does not display tokens, headers, artifact payloads, PAN, mobile, email, or raw financial data.

### Files modified
- `Sources/mone/Views/Onboarding/AAConsentView.swift`
- `HANDOFF.md`

### Current working state
- If the parser request reaches Supabase, the debug card should show an HTTP status.
- If it fails before HTTP, the debug card should now show the URLSession transport error code and description.

### Checks
- Xcode live diagnostics were clean for:
  - `mone/Sources/mone/Views/Onboarding/AAConsentView.swift`

### Next recommended step
- Re-run the parser button in the app and capture the displayed network error code/message. Use that to distinguish simulator/device connectivity, TLS/ATS, cancellation, or host resolution issues.

---

## 2026-05-18 Parse artifact timeout mitigation

### What changed
- User reran the temporary parser debug action and saw:
  - `Network error -1001: The request timed out.`
- Root cause is likely parser execution exceeding the iOS request timeout because `parse-setu-fi-artifact` wrote transactions one-by-one.
- Updated `mone-backend/supabase/functions/parse-setu-fi-artifact/index.ts`:
  - transaction rows with `txn_id` + `link_ref_number` are now batch-upserted per account
  - transaction rows without a stable `txn_id` are checked by hash in one query per account and missing rows are batch-inserted
  - this should reduce the broad sandbox artifact path from roughly one DB request per transaction to a small number of DB requests per account
- Updated `Sources/mone/Views/Onboarding/AAConsentView.swift`:
  - the temporary parser debug request now uses a longer `URLSession` timeout:
    - request timeout: 180 seconds
    - resource timeout: 240 seconds

### Files modified
- `mone-backend/supabase/functions/parse-setu-fi-artifact/index.ts`
- `Sources/mone/Views/Onboarding/AAConsentView.swift`
- `HANDOFF.md`

### Current working state
- iOS debug UI compiles according to Xcode live diagnostics.
- Backend parser source is optimized but not deployed from this environment.
- The deployed parser function must be redeployed before backend batching takes effect.

### Checks
- Xcode live diagnostics were clean for:
  - `mone/Sources/mone/Views/Onboarding/AAConsentView.swift`
- Deno/Supabase CLI checks were not run because these commands have repeatedly hung in this environment.

### Deployment note
From `mone-backend/supabase`, redeploy:
- `supabase functions deploy parse-setu-fi-artifact --project-ref bvgswlacgejikbuuwnpy`

If path/workdir issues recur, run from `mone-backend/supabase`:
- `supabase functions deploy parse-setu-fi-artifact --workdir . --project-ref bvgswlacgejikbuuwnpy`

### Next recommended step
- Redeploy `parse-setu-fi-artifact`, rebuild/run the app, and retry the same artifact ID. If it still times out, check Supabase Edge Function duration/logs and consider moving parsing to an async job table rather than a synchronous debug button.

---

## 2026-05-18 Setu FIP diagnostics and consent context controls

### What changed
- Added Setu FIP health/status diagnostics for sandbox debugging.
- Added shared Setu FIP status helpers in:
  - `mone-backend/supabase/functions/_shared/setu-aa.ts`
- Added authenticated Edge Function:
  - `mone-backend/supabase/functions/setu-aa-fip-status/index.ts`
- Registered the function in:
  - `mone-backend/supabase/config.toml`
- Added optional consent context support in:
  - `mone-backend/supabase/functions/setu-aa-create-consent/index.ts`
- No iOS code was changed for this task.

### Setu FIP diagnostics behavior
`setu-aa-fip-status`:
- Requires a signed-in Supabase user.
- Accepts:
```json
{
  "fipIds": ["setu-fip", "setu-fip-2"],
  "expanded": true
}
```
- If `fipIds` are provided, it checks those FIPs.
- If `fipIds` are omitted, it calls the Setu FIP list endpoint.
- Uses Setu credentials only inside the Edge Function environment.
- Returns safe normalized fields only:
  - `name`
  - `fipId`
  - `fiTypes`
  - `institutionType`
  - `status`
  - `consentConversionRate`
  - `dataFetchSuccessRate`
  - `aaWiseSuccessRate`
  - `traceId`

### Consent context controls
Default behavior remains max coverage with no FIP exclusion and no context in the consent payload.

`setu-aa-create-consent` now supports these optional environment variables:
- `SETU_AA_CONTEXT_FIP_IDS`
- `SETU_AA_CONTEXT_EXCLUDE_FIP_IDS`
- `SETU_AA_ACCOUNT_SELECTION_MODE`

When set, the function adds Setu consent `context` entries:
```json
[
  { "key": "fipId", "value": "<SETU_AA_CONTEXT_FIP_IDS>" },
  { "key": "excludeFipIds", "value": "<SETU_AA_CONTEXT_EXCLUDE_FIP_IDS>" },
  { "key": "accountSelectionMode", "value": "<SETU_AA_ACCOUNT_SELECTION_MODE>" }
]
```

Only non-empty env vars are included. The final context is stored in `aa_consents.request_payload`.

### Important sandbox note
- Setu FIP 2 can return `BANK_NOT_AVAILABLE_ERROR` during broad sandbox account linking.
- The same AA journey can be more fragile after expanding from `DEPOSIT`-only to broad FI types.
- Do not permanently exclude `setu-fip-2` by default.
- Use exclusion only as a fallback/debug mode when sandbox FIP availability blocks consent completion.
- Old consents are unaffected by context/env changes. Create a fresh consent after changing context env vars.

### Safe logging
- Consent creation logs now include:
  - requested FI type count
  - requested consent types
  - whether context was included
  - context keys only
- Consent creation failure logs include a bounded Setu response preview.
- The code avoids logging secrets, access tokens, PAN, full phone numbers, financial payloads, and full profile data.

### Deployment commands
From `mone-backend/supabase`:
- `supabase functions deploy setu-aa-fip-status --project-ref bvgswlacgejikbuuwnpy`
- `supabase functions deploy setu-aa-create-consent --project-ref bvgswlacgejikbuuwnpy`

Optional fallback to exclude Setu FIP 2 temporarily:
- `supabase secrets set SETU_AA_CONTEXT_EXCLUDE_FIP_IDS="setu-fip-2"`
- `supabase functions deploy setu-aa-create-consent --project-ref bvgswlacgejikbuuwnpy`

Optional guided mode:
- `supabase secrets set SETU_AA_CONTEXT_FIP_IDS="setu-fip,setu-fip-2"`
- `supabase functions deploy setu-aa-create-consent --project-ref bvgswlacgejikbuuwnpy`

Reset to max coverage:
- `supabase secrets unset SETU_AA_CONTEXT_EXCLUDE_FIP_IDS`
- `supabase secrets unset SETU_AA_CONTEXT_FIP_IDS`
- `supabase secrets unset SETU_AA_ACCOUNT_SELECTION_MODE`
- `supabase functions deploy setu-aa-create-consent --project-ref bvgswlacgejikbuuwnpy`

### Manual verification checklist
1. Deploy `setu-aa-fip-status`.
2. Call it as a signed-in user with:
```json
{
  "fipIds": ["setu-fip", "setu-fip-2"],
  "expanded": true
}
```
3. Confirm status/health/metric fields for both FIPs.
4. Deploy `setu-aa-create-consent`.
5. Create a normal broad consent with no context env vars set.
6. Verify `aa_consents.request_payload->'context'` is null/absent.
7. If broad consent linking hits `BANK_NOT_AVAILABLE_ERROR`, temporarily set:
   - `SETU_AA_CONTEXT_EXCLUDE_FIP_IDS="setu-fip-2"`
8. Redeploy `setu-aa-create-consent`.
9. Create a fresh consent.
10. Verify `aa_consents.request_payload->'context'` includes `excludeFipIds`.
11. Do not fetch from old consents when testing new context behavior.
12. Reset env vars to max coverage when fallback testing is complete.

### Checks
- Deno/Supabase CLI checks were not run because these commands have repeatedly hung in this environment.
- No Xcode build was run because this task did not change iOS code.
- Backend source was reviewed locally.

### Next recommended step
- Deploy `setu-aa-fip-status`, check `setu-fip` and `setu-fip-2`, then retry a normal no-context broad consent before using the temporary `excludeFipIds` fallback.

---

## 2026-05-18 Temporary Setu FIP status debug UI

### What changed
- Added a temporary developer-only SwiftUI button in the existing Setu/AA setup debug area:
  - `Sources/mone/Views/Onboarding/AAConsentView.swift`
- Button label:
  - `Debug: Check Setu FIP status`
- The button calls the authenticated Supabase Edge Function:
  - `setu-aa-fip-status`
- The app uses the current logged-in Supabase session access token automatically. No manual token copy/paste is required.
- Request body:
```json
{
  "fipIds": ["setu-fip", "setu-fip-2"],
  "expanded": true
}
```

### UI response fields
The debug card displays only safe Setu FIP metadata:
- `fipId`
- `name`
- `status`
- `fiTypes`
- `dataFetchSuccessRate`, if available
- `consentConversionRate`, if available
- HTTP status for debugging

No tokens, Setu secrets, PAN, phone numbers, profile data, or financial payloads are logged or displayed.

### Files modified
- `Sources/mone/Views/Onboarding/AAConsentView.swift`
- `HANDOFF.md`

### How to use
1. Sign in to the app.
2. Navigate to the Setu/AA consent setup screen.
3. In the `DEVELOPER DEBUG` card, tap `Debug: Check Setu FIP status`.
4. Confirm rows appear for `setu-fip` and `setu-fip-2`.
5. Inspect the status and success-rate fields before attempting another broad consent.

### Expected response
The deployed Edge Function should return a shape like:
```json
{
  "fips": [
    {
      "fipId": "setu-fip",
      "name": "...",
      "status": "ACTIVE",
      "fiTypes": ["DEPOSIT"],
      "dataFetchSuccessRate": 0.98,
      "consentConversionRate": 0.91
    }
  ],
  "count": 2
}
```

Fields may be absent depending on what Setu returns. The UI handles missing optional fields.

### Next step based on `setu-fip-2`
- If `setu-fip-2` is `ACTIVE`/healthy, keep max coverage mode and retry a normal broad consent with no context/exclusion env vars.
- If `setu-fip-2` is unavailable or continues causing `BANK_NOT_AVAILABLE_ERROR`, temporarily set:
  - `SETU_AA_CONTEXT_EXCLUDE_FIP_IDS="setu-fip-2"`
- Then redeploy `setu-aa-create-consent` and create a fresh consent.
- Do not make `setu-fip-2` exclusion the production default.
- Old consents are unaffected by env/context changes.

### Checks
- Xcode live diagnostics were clean for:
  - `mone/Sources/mone/Views/Onboarding/AAConsentView.swift`
- Full Xcode build was not run for this temporary debug UI change.

### Unresolved issues
- The `setu-aa-fip-status` Edge Function must be deployed before the button can succeed.
- Remove this temporary debug UI before final production AA UX.

---

## 2026-05-18 Setu FIP status response normalization fix

### What changed
- User reported `Debug: Check Setu FIP status` returned HTTP `200`, but the app displayed:
  - `FIP unknown`
  - `FIP unknown`
- Root cause: Setu's FIP API response is wrapped as `{ "data": [ ... ], "traceId": "..." }`; the single-FIP helper path was normalizing the wrapper instead of the objects inside `data`.
- Updated `mone-backend/supabase/functions/_shared/setu-aa.ts` so FIP status helpers normalize Setu responses into stable app-facing rows:
```json
{
  "traceId": "...",
  "fips": [
    {
      "fipId": "setu-fip",
      "name": "...",
      "status": "...",
      "fiTypes": [],
      "institutionType": "...",
      "consentConversionRate": null,
      "dataFetchSuccessRate": null,
      "aaWiseSuccessRate": []
    }
  ],
  "count": 2
}
```
- Supported response shapes:
  - `GET /v2/fips` returning `{ data: [...] }`
  - `GET /v2/fips/:id` returning `{ data: [...] }`
- If a requested FIP ID is not found, the function now returns:
```json
{
  "fipId": "requested-id",
  "name": "Not found",
  "status": "NOT_FOUND",
  "fiTypes": [],
  "institutionType": null,
  "consentConversionRate": null,
  "dataFetchSuccessRate": null,
  "aaWiseSuccessRate": []
}
```
- Updated `setu-aa-fip-status` to return the normalized `traceId`, `fips`, and `count`.
- Updated `AAConsentView` to decode the normalized `fips` array and display concrete `fipId`/`name` values.
- Added a temporary safe raw response preview in the Swift debug UI only when FIP status decoding fails. It is bounded to 240 characters and does not log tokens, Setu secrets, PAN, phone numbers, profile data, or financial payloads.

### Files modified
- `mone-backend/supabase/functions/_shared/setu-aa.ts`
- `mone-backend/supabase/functions/setu-aa-fip-status/index.ts`
- `Sources/mone/Views/Onboarding/AAConsentView.swift`
- `HANDOFF.md`

### Current working state
- HTTP `200` with `FIP unknown` should be resolved after redeploying `setu-aa-fip-status`.
- The app should display `setu-fip` and `setu-fip-2` rows with name/status/FI types where Setu provides them.

### Verification
1. Redeploy `setu-aa-fip-status`.
2. Sign in to the app.
3. Open the Setu/AA setup screen.
4. Tap `Debug: Check Setu FIP status`.
5. Confirm `FIP` rows show `setu-fip` and `setu-fip-2`, not `unknown`.
6. If `setu-fip-2` is active/healthy, retry broad consent without context exclusions.
7. If `setu-fip-2` is unavailable or still causes `BANK_NOT_AVAILABLE_ERROR`, temporarily use `SETU_AA_CONTEXT_EXCLUDE_FIP_IDS="setu-fip-2"` and create a fresh consent.

### Checks
- Xcode live diagnostics were clean for:
  - `mone/Sources/mone/Views/Onboarding/AAConsentView.swift`
- Deno/Supabase CLI checks were not run because these commands have repeatedly hung in this environment.

### Deployment note
From `mone-backend/supabase`:
- `supabase functions deploy setu-aa-fip-status --project-ref bvgswlacgejikbuuwnpy`

### Next recommended step
- Redeploy `setu-aa-fip-status`, rerun the in-app FIP status button, and decide whether to keep max coverage or temporarily exclude `setu-fip-2` based on the displayed status.
