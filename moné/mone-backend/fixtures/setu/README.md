# Setu sandbox fixtures

`broad-fi-sandbox-redacted.json` is a redacted sample of a broad Setu Account Aggregator FI data fetch.

It was captured from sandbox consent:

`8ab8c48e-be3c-42b4-a85b-34bf7cb62888`

Verified summary:
- 2 FIPs
- 20 accounts
- 9 FI types
- 1600 transactions

Returned FI types:
- deposit
- term_deposit
- recurring_deposit
- mutual_funds
- etf
- equities
- nps
- insurance_policies
- gstr1_3b

Use this fixture for parser and canonical model tests.

Do not commit raw/unredacted Setu payloads.