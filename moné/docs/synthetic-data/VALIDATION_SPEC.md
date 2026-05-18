# Validation Specification — Moné Synthetic Data

## Purpose

Every generated dataset must pass a comprehensive validation suite before being considered usable. Validation checks ensure structural correctness, behavioral realism, and ground truth completeness.

## Validation Checks

### 1. AA Structure Validation

| # | Check | Expected | Severity |
|---|-------|----------|----------|
| 1.1 | Payload is valid JSON array of FIP objects | Parseable | FATAL |
| 1.2 | Each FIP has fipID and data array | Present | FATAL |
| 1.3 | Each data item has decryptedFI with type and account | Present | FATAL |
| 1.4 | Each account has profile, summary, transactions | Present | FATAL |
| 1.5 | Profile has holders with holder array | Present | ERROR |
| 1.6 | Summary has type, status, currency, currentBalance, balanceDateTime | Present | ERROR |
| 1.7 | Each transaction has txnId, type, mode, amount, narration, reference, valueDate, transactionTimestamp | Present | ERROR |
| 1.8 | Payload is parseable by setu-fi-parser.ts | Returns valid ParsedSetuPayload | FATAL |

### 2. Account Validation

| # | Check | Expected | Severity |
|---|-------|----------|----------|
| 2.1 | Every account has a unique linkedAccRef (UUID) | Unique | ERROR |
| 2.2 | Every account has maskedAccountNumber | Present | ERROR |
| 2.3 | Account type matches decryptedFI type | Match | ERROR |
| 2.4 | Summary currentBalance matches last transaction balance | Match (±₹1) | WARNING |
| 2.5 | Summary balanceDateTime is at or after last transaction | After | WARNING |

### 3. Transaction Validation

| # | Check | Expected | Severity |
|---|-------|----------|----------|
| 3.1 | All txnIds are unique within dataset | Unique | FATAL |
| 3.2 | Transactions are chronologically ordered | Ascending | ERROR |
| 3.3 | Every transaction has non-zero amount | amount > 0 | ERROR |
| 3.4 | Balance updates correctly: previous ± amount = current | Match (±₹1) | ERROR |
| 3.5 | No balance goes below -drawingLimit | >= limit | WARNING |
| 3.6 | Timestamps have IST timezone (+05:30) | Correct TZ | WARNING |
| 3.7 | valueDate matches date portion of transactionTimestamp | Match | WARNING |
| 3.8 | Transaction modes are valid: UPI, CARD, FT, NEFT, RTGS, CASH, ATM, OTHERS | Valid | ERROR |
| 3.9 | Transaction types are CREDIT or DEBIT only | Valid | ERROR |

### 4. Behavioral Validation

| # | Check | Expected | Severity |
|---|-------|----------|----------|
| 4.1 | Salary/income appears according to persona schedule | Monthly near expected date | ERROR |
| 4.2 | Rent/EMI appears on expected date each month | Within ±3 days | ERROR |
| 4.3 | SIP appears on expected date each month | Within ±2 days | ERROR |
| 4.4 | Subscriptions renew monthly | Present each month | WARNING |
| 4.5 | Weekend spending > weekday spending for discretionary | Higher | WARNING |
| 4.6 | Life events create expected financial behavior | Visible | ERROR |
| 4.7 | Spending timestamps match time-of-day rules | Plausible | WARNING |
| 4.8 | No unrealistic transaction amounts (salary ≠ ₹50) | Reasonable | ERROR |

### 5. Ground Truth Validation

| # | Check | Expected | Severity |
|---|-------|----------|----------|
| 5.1 | Every payload transaction has ground truth entry | 1:1 mapping | FATAL |
| 5.2 | transaction_id matches between payload and ground truth | Exact match | FATAL |
| 5.3 | is_income and is_obligation not both true | Exclusive | ERROR |
| 5.4 | is_salary implies is_income | Consistent | ERROR |
| 5.5 | EMI/SIP/insurance flags imply is_obligation | Consistent | ERROR |
| 5.6 | is_tax not marked discretionary | Exclusive | ERROR |
| 5.7 | Investments not marked as lifestyle spending | Exclusive | ERROR |
| 5.8 | is_internal_transfer not counted as income or spending | Neutral | ERROR |
| 5.9 | is_refund not counted as income | Separate | ERROR |
| 5.10 | Reimbursement linked IDs reference existing transactions | Valid refs | ERROR |
| 5.11 | Cash withdrawals marked as blindspots | Flagged | WARNING |

### 6. CSV Validation

| # | Check | Expected | Severity |
|---|-------|----------|----------|
| 6.1 | accounts.csv has all accounts from payload | Count match | ERROR |
| 6.2 | transactions.csv has all transactions from payload | Count match | ERROR |
| 6.3 | monthly_cashflow.csv covers all 12 months | 12 rows | ERROR |
| 6.4 | Monthly cashflow income + expense = net | Adds up | ERROR |
| 6.5 | mode_spending_summary.csv covers all transaction modes | All modes | WARNING |
| 6.6 | Mode spending totals match transaction totals | Match | ERROR |

### 7. Aggregate Validation

| # | Check | Expected | Severity |
|---|-------|----------|----------|
| 7.1 | Total credits - total debits ≈ ending balance - opening balance | Match (±₹10) | ERROR |
| 7.2 | Minimum 200 transactions per 12-month deposit account | >= 200 | WARNING |
| 7.3 | Income candidate list matches salary/income transactions | Match | WARNING |
| 7.4 | Recurring candidate list matches obligations | Match | WARNING |
| 7.5 | Safe-to-spend expected values exist | Present | WARNING |
| 7.6 | Goal drift expected values exist | Present | WARNING |
| 7.7 | Reimbursements link to original spends | Connected | WARNING |

## Validation Report Format

```json
{
  "dataset_id": "aarav_spend_control_normal",
  "generated_at": "2026-05-18T00:00:00+05:30",
  "status": "pass",
  "severity_counts": {
    "fatal": 0,
    "error": 0,
    "warning": 2
  },
  "checks": [
    {
      "id": "1.1",
      "name": "payload_valid_json",
      "category": "aa_structure",
      "expected": "Parseable JSON array of FIP objects",
      "actual": "Valid JSON with 1 FIP, 1 account",
      "result": "pass",
      "severity": "FATAL"
    },
    {
      "id": "4.1",
      "name": "salary_detectable",
      "category": "behavioral",
      "expected": "Monthly salary near 28th",
      "actual": "Found 12 salary credits, dates: [28, 28, 28, 30, 28, 28, 28, 28, 28, 1, 28, 28]",
      "result": "pass",
      "severity": "ERROR"
    }
  ],
  "summary": {
    "total_transactions": 2847,
    "deposit_transactions": 2847,
    "income_events": 24,
    "obligation_events": 180,
    "discretionary_events": 1840,
    "life_events": 8,
    "nudge_candidates": 380,
    "months_covered": 12,
    "opening_balance": 45000,
    "closing_balance": 63245
  }
}
```

## Severity Levels

| Level | Meaning | Action |
|-------|---------|--------|
| FATAL | Data is structurally broken, cannot be used | Block dataset |
| ERROR | Significant issue, detection algorithms may fail | Must fix |
| WARNING | Minor issue, data is usable but imperfect | Log and continue |

## Running Validation

```bash
cd /Users/sujaykumar/Documents/Assignment/CommerceIQ/moné
deno run --allow-read --allow-write data/synthetic/src/validate_against_ground_truth.ts --dataset aarav_spend_control_normal
```
