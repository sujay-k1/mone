# Financial Data Model

Moné should not turn raw Account Aggregator payloads directly into product-facing transactions, categories, or nudges. The financial data model needs a clean pipeline that separates integration bookkeeping, raw evidence, canonical financial records, and intelligence. This keeps the app debuggable while the Setu sandbox payloads are still being learned, and it avoids baking early assumptions into permanent product tables.

Moné's financial intelligence should be built from a clean pipeline: Setu/AA integration events -> raw evidence artifacts -> canonical financial model -> derived intelligence/nudges. Current work only establishes the first two layers.

## Why Layered Architecture

Account Aggregator data is external, asynchronous, and provider-shaped. Consent status, data session status, webhook payloads, and FI data can arrive in different orders and shapes. Moné needs to preserve those facts before interpreting them.

Layering gives us:
- traceability from every future insight back to the source consent/session/payload
- safer debugging when Setu sandbox or FIP payloads vary
- room to evolve canonical models without losing original evidence
- a clear boundary between integration failures and product intelligence failures
- a way to reprocess old raw payloads when parsers improve

## Layer 1: Integration Layer

The integration layer tracks the relationship with external systems. It should answer operational questions:
- Which Setu consent was created for which user?
- What webhook events arrived?
- Did Setu approve, reject, revoke, or update a consent?
- Which data session was created or updated?
- Did a fetch attempt succeed or fail?

Current integration tables include or should include:
- `public.aa_consents`
- `public.aa_webhook_events`
- `public.aa_data_sessions`

This layer stores IDs, statuses, request/response payloads for integration calls, and timestamps. It does not normalize bank transactions or infer spending behavior.

## Layer 2: Raw Evidence Layer

The raw evidence layer stores exact payloads received from Setu before interpretation.

Current raw evidence table:
- `public.financial_data_artifacts`

Each artifact links back to user, consent, data session, source, FI type, FIP, schema version, and the exact JSON payload. A payload hash can help deduplicate or audit repeated delivery. Raw artifacts should be immutable evidence; later parsers can read from this layer and produce canonical financial records.

Raw Setu payloads should be stored before normalization because:
- sandbox FI payload shape needs to be observed in practice
- different FIPs may return different structures
- parser bugs should not destroy original evidence
- future models may need fields we do not yet understand
- audits and user-support debugging need source payload traceability

## Layer 3: Canonical Financial Layer

This is the future Moné-owned financial model. It should be designed after inspecting real sandbox and production-like FI payloads.

Current minimum canonical tables:
- `public.financial_accounts`
- `public.financial_transactions`

These tables are the first stable canonical parser foundation. `financial_accounts` stores account/instrument-level records extracted from Setu FI payloads, preserving raw profile, summary, and account JSON. `financial_transactions` stores transaction-like records extracted from account payloads while preserving the raw transaction JSON.

Future tables may include:
- investments
- insurance
- pension
- obligations

Holdings, policies, tax-specific records, richer balances, and obligation models are intentionally deferred until broad sandbox payloads are inspected more deeply.

Canonical transactions should stay conservative until we understand:
- account identifiers and masking conventions
- transaction timestamp granularity
- debit/credit sign conventions
- narration/reference fields
- balance availability
- duplicate transaction behavior across fetches
- FIP-specific quirks

## Layer 4: Intelligence Layer

The intelligence layer will power Moné's product value. It should derive meaning from canonical records and source evidence.

Future derived models may include:
- income streams
- fixed obligations
- recurring payments
- classified transactions
- expenditure patterns
- unnecessary spending signals
- cashflow forecasts
- goal drift
- timely interventions and nudges
- goal-risk events

This layer should only be built once raw evidence ingestion and canonical modeling are stable. It should be explainable: every derived insight should be traceable to source evidence and canonical records.

## What Exists Now

The current foundation establishes:
- Setu consent creation through `setu-aa-create-consent`
- Setu redirect handling through `setu-aa-redirect`
- Setu callback handling through `setu-aa-callback`
- Setu data-session creation through `setu-aa-create-data-session`
- Setu FI data fetch through `setu-aa-fetch-fi-data`
- integration tables for consents, webhook events, and data sessions
- raw evidence storage for FI artifacts

The callback stores every webhook payload and updates consent/data-session state best-effort. If a webhook contains raw FI data, it stores that payload as a raw artifact without parsing or classification. If a callback indicates data is ready but does not include FI data, the backend can fetch the data using the Setu data-session id and store the fetched response as raw evidence.

## Data Session Lifecycle

After a consent is approved or active, Moné creates a Setu AA data session. The data session is still integration state, not product data.

The lifecycle is:
1. A user approves consent in Setu's hosted AA flow.
2. Setu calls `setu-aa-callback` with consent status updates.
3. The backend records the webhook in `public.aa_webhook_events`.
4. If the consent is approved/active, `setu-aa-create-data-session` or callback-side automation calls Setu `POST /sessions`.
5. The request and response are stored in `public.aa_data_sessions`.
6. Later callback events update the data-session status.

`aa_data_sessions` exists to make the external Setu lifecycle auditable. It should track status, request payloads, response payloads, errors, and Setu ids. It should not contain parsed transactions or Moné-owned account models.

## Fetch FI Data Lifecycle

When a Setu data session reaches a ready state such as `PARTIAL` or `COMPLETED`, Moné can fetch FI data from Setu.

The lifecycle is:
1. Setu sends a data-ready callback, or a signed-in user/backend process calls `setu-aa-fetch-fi-data`.
2. The backend calls Setu `GET /sessions/:id`.
3. The backend updates `public.aa_data_sessions.status` and stores the Setu response payload.
4. The full fetched FI payload is stored in `public.financial_data_artifacts`.
5. The app/backend receives only summary metadata such as status, artifact id, FIP count, and account count.

If Setu Auto-Fetch is enabled and the callback itself contains FI data, `setu-aa-callback` stores that callback FI payload directly as a raw artifact. If Auto-Fetch is not enabled, the callback can fetch using the data-session id when the status indicates data is ready.

## Why Fetched FI Data Stays Raw First

Fetched FI responses may include FIPs, accounts, profile sections, summary sections, balances, and transactions. The exact sandbox payload shape still needs to be observed before Moné creates permanent canonical tables.

Storing the full response as raw evidence first lets future agents:
- inspect real Setu/FIP shapes before designing canonical schemas
- compare callback-delivered FI data against explicitly fetched FI data
- deduplicate repeated fetches using payload hashes
- reprocess old artifacts when parsers improve
- trace future insights back to consent id and data-session id

## Canonical Parser Lifecycle

Once a raw FI artifact is captured, `parse-setu-fi-artifact` can convert stable account and transaction-like fields into canonical tables.

The lifecycle is:
1. A signed-in user/backend process calls `parse-setu-fi-artifact` with an artifact id.
2. The function verifies the artifact belongs to the current user.
3. The parser reads Setu FIP payloads defensively:
   - top-level FIP array
   - each FIP's `fipID`
   - `data[]`
   - `decryptedFI.type`
   - `decryptedFI.account`
   - account `profile`, `summary`, and `transactions`
4. The function upserts `financial_accounts`.
5. The function inserts/upserts `financial_transactions` idempotently.
6. Raw `financial_data_artifacts` rows remain unchanged.

The parser logs only safe counts: FIP count, account count, transaction count, and FI types. It must not log profile details, PAN, mobile, email, address, full narration payloads, or raw financial data.

`mone-backend/fixtures/setu/broad-fi-sandbox-redacted.json` is the intended local fixture for parser development. The fixture README documents an expected broad sandbox payload summary: 2 FIPs, 20 accounts, 9 FI types, and 1600 transactions. If the fixture file is empty in a checkout, restore the redacted fixture before relying on fixture-based counts.

## What Is Intentionally Deferred

This foundation intentionally does not implement:
- transaction/category tables
- category tables
- holdings-specific canonical tables
- policy-specific canonical tables
- tax-specific canonical tables
- richer canonical balance history
- spending analysis
- income detection
- obligation detection
- recurring payment inference
- goal-risk scoring
- nudges

Those should come after real Setu sandbox FI payloads have been collected and inspected.

## How This Supports Future Intelligence

Once Setu payloads are stored reliably, Moné can build parsers that convert raw evidence into canonical accounts, balances, and transactions. Then intelligence jobs can infer income, obligations, recurring commitments, expenditure patterns, cashflow risks, and goal drift from a stable Moné-owned model.

The key is sequencing: first collect trustworthy evidence, then normalize carefully, then infer. This prevents early product assumptions from corrupting the data model and keeps future nudges explainable.
