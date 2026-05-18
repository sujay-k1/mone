# AA Payload Generation Specification — Moné Synthetic Data

## Overview

Generated data must produce AA (Account Aggregator)-style JSON payloads that are parseable by the existing `setu-fi-parser.ts` without modification. This ensures the synthetic data can be fed directly into the Moné pipeline.

## Target Payload Structure

The payload is an array of FIP (Financial Information Provider) objects:

```json
[
  {
    "fipID": "FIP-001",
    "data": [
      {
        "decryptedFI": {
          "type": "deposit",
          "account": {
            "type": "deposit",
            "version": "2.0.0",
            "linkedAccRef": "uuid-here",
            "profile": {
              "holders": {
                "type": "SINGLE",
                "holder": [
                  {
                    "dob": "1999-03-15",
                    "pan": "ABCDE1234F",
                    "name": "Aarav Sharma",
                    "email": "aarav@example.com",
                    "mobile": "9876543210",
                    "address": "123, HSR Layout, Bangalore 560102",
                    "nominee": "REGISTERED",
                    "ckycCompliance": "true"
                  }
                ]
              }
            },
            "summary": {
              "type": "SAVINGS",
              "branch": "HSR Layout",
              "status": "ACTIVE",
              "currency": "INR",
              "facility": "OD",
              "ifscCode": "HDFC0001234",
              "micrCode": "560240001",
              "openingDate": "2022-01-15T00:00:00+05:30",
              "currentBalance": "63245.50",
              "balanceDateTime": "2026-05-18T23:59:59+05:30"
            },
            "transactions": {
              "startDate": "2025-06-01",
              "endDate": "2026-05-31",
              "transaction": [
                {
                  "txnId": "TXN_AARAV_20250601_001",
                  "type": "CREDIT",
                  "mode": "FT",
                  "amount": "165000.00",
                  "narration": "NEFT/CR/EMPLOYER/TECHCORP INDIA PVT LTD/SALARY/JUN25",
                  "reference": "N123456789",
                  "valueDate": "2025-06-28",
                  "currentBalance": "182450.75",
                  "transactionTimestamp": "2025-06-28T10:30:00+05:30"
                }
              ]
            }
          }
        }
      }
    ]
  }
]
```

## Account Type Payload Differences

### deposit
- Most transactions
- Transaction fields: txnId, type (CREDIT/DEBIT), mode (UPI/CARD/FT/NEFT/CASH/ATM/OTHERS), amount, narration, reference, valueDate, currentBalance, transactionTimestamp

### mutual_funds
- Profile: folio number, AMC name, scheme name
- Summary: holdings with NAV, units, investment value, current value
- Transactions: SIP purchase, redemption, switch, dividend

### recurring_deposit
- Profile: account number, maturity date, monthly instalment
- Summary: principal, interest accrued, maturity amount
- Transactions: monthly instalment debit, interest credit, maturity

### term_deposit
- Profile: FD number, tenure, interest rate
- Summary: principal, interest rate, maturity date, maturity amount
- Transactions: opening, interest payout, TDS, renewal, premature closure

### insurance_policies
- Profile: policy number, insurer, type, sum assured
- Summary: premium amount, frequency, next due date, status
- Transactions: premium payment, renewal, claim, maturity payout

### equities
- Profile: demat account, DP ID
- Summary: holdings with quantity, average price, current value
- Transactions: buy, sell, dividend, charges

### nps
- Profile: PRAN number, tier
- Summary: total corpus, asset allocation
- Transactions: contribution, employer contribution, annual statement

### gstr1_3b
- Profile: GSTIN, trade name, registration date
- Summary: turnover, tax liability, ITC
- Transactions: invoices, tax payments, ITC claims, filings

## Narration Patterns

Narrations must be realistic and parseable. Follow these patterns:

### Deposit Account Narrations

**Salary:**
- `NEFT/CR/EMPLOYER/TECHCORP INDIA PVT LTD/SALARY/JUN25`
- `RTGS/CR/COMPANY NAME/SALARY JUNE 2025`

**UPI:**
- `UPI/DR/9876543210@ybl/SWIGGY/OrderID123456`
- `UPI/DR/aarav@upi/ZOMATO/Food Order`
- `UPI/CR/refund@paytm/REFUND/ORD987654`
- `UPI/DR/merchant@ybl/UBER INDIA/Trip`

**Card:**
- `CARD/DR/POS/STARBUCKS HSR LAYOUT BLR/5678`
- `CARD/DR/ECOM/AMAZON.IN/ORD-123-456`
- `CARD/DR/POS/ZARA PHOENIX MALL BLR/9012`
- `CARD/DR/RECURRING/NETFLIX.COM/SUBSCRIPTION`

**ATM:**
- `ATM/DR/SELF/HDFC ATM HSR LAYOUT/WDL`
- `ATM/DR/SELF/SBI ATM KORAMANGALA/CASH`

**Fund Transfer:**
- `FT/DR/NEFT/AARAV TO LANDLORD/RENT APR 2026`
- `FT/DR/IMPS/TO SAVINGS ACCT XXXX1234/TRANSFER`
- `FT/CR/NEFT/TECHCORP/REIMBURSEMENT/TRAVEL MAR26`

**Auto-debit:**
- `SI/DR/HDFC MF/SIP/FOLIO 12345/BLUECHIP FUND`
- `SI/DR/BAJAJ ALLIANZ/PREMIUM/POLICY HLP12345`
- `ECS/DR/LIC/PREMIUM/POLICY 12345678`

**Rent:**
- `UPI/DR/landlord@upi/RENT/APR2026`
- `FT/DR/NEFT/TO LANDLORD ACCT/MONTHLY RENT`

## FIP Structure

Generate 1-2 FIPs per persona:
- FIP-001: Primary bank (deposit, RD, TD)
- FIP-002: Investment platform (mutual_funds, equities, NPS, insurance)

For deposit-only Pass 1, generate single FIP with deposit account.

## Balance Tracking

- Every transaction must update currentBalance
- Balance must never go below -drawingLimit (if overdraft facility)
- For savings accounts, balance should rarely go below ₹5,000
- End-of-period balance in summary must match last transaction's currentBalance
- Opening balance is derived: starting balance before first generated transaction

## Masked Account Numbers

Format: `XXXX1234` (last 4 digits visible)
Generate unique per account, consistent across the dataset.

## Linked Account References

UUID v4 format, unique per account, consistent across the dataset.

## Timestamps

- Use IST timezone: `+05:30`
- Format: `2026-03-15T14:30:00+05:30`
- valueDate is date-only: `2026-03-15`
- Transactions must be chronologically ordered within each account

## Data Period

- Default: 12 months
- Start: 2025-06-01
- End: 2026-05-31
- This gives us a full fiscal year of behavioral data
