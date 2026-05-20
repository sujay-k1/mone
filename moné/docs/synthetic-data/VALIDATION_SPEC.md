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
| 4.9 | category_time_window_coherence | Category/subcategory timestamps fit semantic local-time windows | ERROR |

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

### 8. Rash-Decisions Fixture Validation

These checks apply to `aarav_spend_control_rash_decisions`:

| Check | Expected |
|-------|----------|
| raw_payload_has_required_fi_types | `deposit`, `mutual_funds`, `recurring_deposit`, and `term_deposit` are present |
| linked_cash_and_asset_events_match | SIP, MF redemption, RD closure, and TD closure cash/asset events reference each other |
| asset_account_summary_reconciles_accounts_csv | Asset `accounts.csv` values match raw payload summaries |
| asset_transaction_running_balance_reconciliation | Asset transaction stream final `currentBalance` matches account summary |
| asset_account_balance_role_present | Every account row has `liquidity_class`, `balance_role`, and a current value convention |
| no_asset_double_counting | Asset opening/principal values are not duplicated as ambiguous opening transactions |
| major_rash_events_have_life_event_labels | Major rash, liquidity, card, and investment-break events have `life_event` labels |
| interrupts_are_high_severity_only | `should_interrupt` appears only on high-severity events and remains 8-20 annually |

`category_time_window_coherence` validates semantic timestamp windows such as lunch at 12:00-15:30, late-night food at 22:30-01:30, cab-to-work at 08:00-11:30, cab-from-work at 18:00-22:30, and weekend dining at 12:00-23:30.

### 9. Final Aarav Polish Validation

The polished `aarav_spend_control_rash_decisions` fixture also validates source/intelligence separation, credit-card statement source files, EMI schedules, safe-to-spend debt pressure, recurring taxonomy semantics, and nudge surface discipline.

| Check | Expected |
|-------|----------|
| raw_payload_has_no_expected_intelligence_fields | AA-like raw payload contains financial source facts only, not expected inference fields |
| canonical_source_csvs_have_no_hidden_ground_truth | `accounts.csv` and `transactions.csv` exclude hidden labels such as nudge, goal drift, and expected health fields |
| expected_outputs_are_separate_from_source_data | Ground truth and `*_expected.json` files contain expected intelligence outputs |
| credit_card_statement_present_or_documented | Separate credit-card statement source files exist or deferral is explicitly documented |
| card_statement_payments_reconcile_with_deposit | Statement payment records map to deposit account card-bill payments |
| card_interest_and_late_fee_present | At least one interest charge and one late fee are modeled |
| card_partial_payment_present | At least one statement cycle has partial payment behavior |
| card_utilization_risk_present | At least one statement cycle crosses utilization-risk threshold |
| card_purchases_not_double_counted | Card purchases are not duplicated as both statement spend and deposit spend |
| emi_candidates_present | At least one card EMI and one non-card/device EMI exist |
| emi_schedule_reconciles | EMI schedules reconcile count, amount, dates, and linked source IDs |
| emi_payments_affect_safe_to_spend | EMI obligations reduce safe-to-spend expected output |
| emi_not_treated_as_discretionary_spend_after_conversion | Original purchase can be discretionary; EMI installments are debt obligations |
| emi_linked_to_original_purchase | EMI candidates link back to the rash purchase or source transaction |
| safe_to_spend_excludes_liquidity_rescue_from_income | MF redemption and RD/TD closure proceeds do not inflate income |
| safe_to_spend_includes_emi_pressure | Debt/EMI commitments are reserved before safe-to-spend |
| safe_to_spend_negative_while_balance_positive_present | At least one period has positive bank balance but negative safe-to-spend |
| recurring_taxonomy_semantics_correct | Rent is must-pay, subscriptions are cancelable, groceries are forecast-only, EMI/card dues are debt commitments |
| nudge_candidate_not_equal_interrupt | Most nudge candidates remain non-interrupting signals |
| interrupts_have_user_facing_reason | Every interrupt includes reason and candidate copy |
| micro_spends_not_interrupting | Coffee, cab, and lunch leakage do not interrupt by default |

### 10. Final Cleanup Validation

The final Aarav cleanup adds stricter checks that source files look like realistic AA/statement extraction and do not leak Moné taxonomy.

| Check | Expected |
|-------|----------|
| source_files_have_no_mone_taxonomy | Source files do not contain `category`, `sub_category`, `is_*` taxonomy flags, nudge fields, or product copy |
| source_metadata_is_namespaced | Synthetic helper fields use `source_reconciliation_*` in CSVs or `generator_metadata` in JSON |
| ground_truth_contains_taxonomy | Hidden taxonomy exists in `ground_truth.json` |
| expected_outputs_contain_intelligence | Expected intelligence exists in `*_expected.json` and `nudge_expected.json` |
| app_input_files_are_reality_grounded | App-facing source files can be treated as realistic source/canonical data |
| nudge_copy_not_in_source_files | User-facing nudge copy does not appear in raw/canonical source files |
| interrupt_copy_specific_if_present | Interrupt copy is specific, not generic filler |
| all_emi_schedule_statement_cycles_exist | Every card EMI schedule references an existing statement cycle |
| card_overlimit_explained | Over-limit card cycles include amount and reason fields |
| card_statement_metadata_namespaced | Card statement reconciliation metadata is namespaced |
| card_payment_dates_match_due_or_late_window | Card payments, interest, and late fees land on due date or late-payment windows |
| emi_original_purchase_source_exists | Device EMI links to `device_finance_source.json` |
| emi_schedule_statement_cycles_exist | Card and device EMI schedules reconcile to statement/device source |
| emi_schedule_dates_and_amounts_reconcile | EMI expected candidates reconcile with schedules |
| emi_source_not_taxonomy_polluted | Device finance source has no Moné taxonomy fields |
| term_deposit_closed_balance_semantics_clear | Fully closed TD has zero current value or documented residual |
| td_premature_closure_payout_reconciles | TD closure payout matches linked deposit credit |
| td_penalty_or_residual_documented | TD penalty/residual treatment is explicit |
| validation_summary_counts_match_files | Validation summary counts match generated source and ground truth files |

### 11. Deterministic Aarav V2 Validation

The `mone-aarav-rash-decisions-final-v2` package adds checks for chronological ledger quality, source narration realism, demo identity mapping, dataset registry state, scenario-grade credit-card metadata, and nudge-copy maturity.

| Check | Expected |
|-------|----------|
| deposit_running_balance_chronological_reconciliation | Deposit `balance_after` is recomputed after all deposit streams are merged and sorted |
| raw_payload_current_balance_matches_transactions_csv | Raw payload transaction `currentBalance` equals canonical `transactions.csv` `balance_after` |
| deposit_summary_balance_matches_final_transaction | Deposit summary current balance equals the final chronological deposit transaction balance |
| no_substream_balance_artifacts | No independently balanced substream artifacts remain after merge |
| source_narrations_have_no_mone_taxonomy_leakage | Source narrations do not contain behavioral labels such as `impulse`, `rash`, or `spontaneous_trip` |
| source_narrations_are_bank_like | Source narrations use payment-rail or merchant-like strings |
| rash_behavior_present_only_in_ground_truth_or_expected | Rash behavior remains represented in hidden truth/expected files, not source text |
| demo_identity_map_present | Root `demo_identity_map.json` exists |
| aarav_phone_maps_to_aarav_dataset | `8828290489` maps to Aarav and `aarav_spend_control_rash_decisions` |
| priya_phone_not_mapped_to_aarav_dataset | `7304893952` is marked Priya-not-wired and does not point to Aarav |
| raw_holder_profile_not_used_as_demo_identity | Demo identity comes from mapping, not raw AA holder profile |
| unsupported_numbers_have_explicit_state | Unsupported demo numbers have a retry/unsupported state |
| dataset_registry_present | Root `dataset_registry.json` exists |
| only_ready_datasets_are_wired | Only ready datasets are wired for demo use |
| priya_not_falsely_available | Priya remains explicitly unavailable until her dataset is generated |
| credit_card_modeling_limitations_documented | Card statement source declares scenario-grade modeling limitations |
| credit_card_not_marked_production_grade | Card source is explicitly not production-grade accounting |
| nudge_expected_marked_as_test_scaffold | `nudge_expected.json` is marked as expected-intelligence test scaffolding |
| non_interrupt_copy_not_required_to_be_final | Non-interrupt nudge copy is not treated as reviewed final UX copy |

### 12. Precision Cleanup Validation

The final precision pass keeps the v2 seed and adds checks for self-contained packaging, card EMI paid-cycle semantics, intentional cash pressure, and interrupt-only copy review.

| Check | Expected |
|-------|----------|
| output_package_self_contained | Dataset folder contains source files, expected files, identity map, registry, validation report, and manifest |
| demo_identity_map_present_inside_package | `demo_identity_map.json` exists inside the dataset folder |
| dataset_registry_present_inside_package | `dataset_registry.json` exists inside the dataset folder |
| manifest_includes_demo_identity_files | Manifest includes identity and registry files with hashes |
| no_external_required_files_missing | No required files live only outside the package |
| card_emi_paid_cycles_have_cash_link_or_explicit_statement_only_status | Paid card EMI rows are cash-linked or explicitly statement-only scenario-grade |
| card_emi_payment_source_semantics_clear | Card EMI payment source fields are explicit |
| card_statement_payments_reconcile_or_are_explicitly_scenario_grade | Scenario-grade card payments are documented when not fully bank-linked |
| no_blank_paid_emi_cash_links_without_explanation | Paid EMI rows do not leave blank cash links unexplained |
| aarav_cash_pressure_intentional | Minimum and closing balances are in configured stressed-but-positive ranges |
| minimum_balance_within_configured_risky_range | Minimum balance is positive and meaningfully low |
| closing_balance_within_configured_risky_range | Closing balance is buffered but not excessive |
| positive_bank_balance_negative_safe_to_spend_present | Bank balance remains positive while safe-to-spend is negative in at least one period |
| copy_review_required_true_for_interrupts | Interrupt-level nudge entries require copy review |

### 13. Local UPI and Net Worth Validation

The controlled Aarav enhancement adds messy local UPI behavior and low/risk net-worth expectations.

| Check | Expected |
|-------|----------|
| local_micro_upi_variety_present | Local micro-UPI contains diverse merchants and ground-truth categories |
| local_micro_upi_monthly_frequency_in_target_range | Aarav has 25-55 local micro-UPI spends each month |
| local_micro_upi_amount_distribution_realistic | Most local UPI amounts are small, with only a few larger local payments |
| local_micro_upi_has_truncated_merchants | Source narrations include truncated/local merchant patterns |
| local_micro_upi_has_qr_aggregator_narrations | Source narrations include QR aggregator patterns |
| local_micro_upi_has_ambiguous_payees | Source narrations include person-name or ambiguous payees |
| local_micro_upi_has_ground_truth_categories | Local UPI source rows have hidden categories in ground truth |
| local_micro_upi_not_all_high_confidence | Medium and low-confidence tagging cases exist |
| tagging_ambiguity_cases_present | Ambiguous UPI cases are intentionally represented |
| source_narrations_do_not_leak_local_upi_taxonomy | Local UPI source strings do not reveal hidden taxonomy |
| aarav_upi_micro_spend_density_high | Aarav has high UPI micro-spend density |
| upi_dominates_small_transaction_count | UPI dominates small-value debit transaction count |
| local_upi_contributes_to_spend_drift | Local UPI materially contributes to annual spending drift |
| local_micro_upi_nudge_candidates_present | Local UPI generates expected nudge candidates |
| local_micro_upi_interrupts_limited | Local UPI interrupts stay below 5% of local micro-UPI rows |
| micro_upi_interrupts_contextual | Local UPI interrupts occur as safe-to-spend/risk-context events |
| net_worth_expected_file_present | `net_worth_expected.json` exists |
| final_net_worth_low_or_risk | Final net worth is low/risk |
| net_worth_reconciles_with_source_accounts_and_liabilities | Net worth reconciles source account values, card outstanding, and EMI outstanding |
| liquid_net_worth_low_or_risk | Liquid net worth remains low or negative |
| credit_card_and_emi_liabilities_included_in_net_worth | Card and EMI liabilities are included |
| redemptions_and_deposit_closures_do_not_artificially_inflate_net_worth | Liquidity rescue does not make net worth healthy |
| financial_health_reflects_low_net_worth | Financial health includes net-worth risk |

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
## Priya Responsibility-Burden Validation

The Priya validator applies the Aarav fixture standards to a responsibility-heavy persona:

- source files remain free of Moné taxonomy and expected-intelligence fields
- raw payload, `transactions.csv`, monthly cashflow, mode summary, accounts, ground truth, and expected outputs reconcile
- chronological running balances are enforced and negative deposit balances fail validation
- local micro-UPI density is present but lower than Aarav
- parents support, sibling support, education-loan EMI, healthcare, insurance, self-transfers, cash withdrawals, and goals are explicitly validated
- `net_worth_expected.json` reconciles assets and liabilities, including education-loan outstanding
- Priya's health must be `Watch` or `Risk`, not `Healthy`
- Priya's phone must map to Priya's dataset and must not map to Aarav

The latest validation target is:

```text
dataset_id: priya_goal_planner_responsibility_burden
seed: mone-priya-responsibility-burden-v3
overall_status: Watch
```

Priya v2 also validates complete credit-card cycle coverage, due-window card payments, explicit scenario-grade hybrid card cashflow policy, mixed safe-to-spend monthly statuses, bank-like family/support/self-transfer narrations, and absence of hidden packaging artifacts.

Priya v2 also validates nudge field consistency: non-candidate ground-truth rows must not carry `expected_nudge_type`, candidate rows must have a nudge type, interrupt rows must use the interrupt surface, and `nudge_expected.json` entries must correspond to ground-truth nudge candidates.

Priya v3 validates safe-to-spend numeric/status semantics and data-period metadata. Healthy months must have non-negative capacity, Watch months must not be deeply negative, Risk months require material shortfall or an explicit pressure event, and transaction dates must fall within the declared data period.

Priya final targeted validation also checks that manifest-status diagnostic payloads reflect the current top-level manifest/report values, and that deposit cashflow rows use coherent mode/narration prefixes for UPI, FT, NACH/ECS/ACH, CARD, and ATM. Asset FI statement rows may keep their source-specific prefixes such as `RD/` and `MF/`.

## Raw Money Map Evidence Validation

The final Aarav and Priya raw AA-style packages validate that source data contains enough bank-like evidence for future Money Map and Dashboard derivation without placing derived taxonomy in raw files.

Required raw evidence checks include LPG/gas payments, rent components, variable electricity, internet/mobile topups, domestic help advance where persona-relevant, EMI or loan extra payments, SIP/RD/MF topups, vehicle service or repair costs, annual renewals in the demo month, and ambiguous needs-review signals such as QR/person-name UPI, ATM withdrawals, and own-account credits.

Aarav-specific checks require high subscription load, high local UPI density and variety, device EMI extra payment, vehicle repair outlier, SIP/RD irregularity, cash blindspots, and preservation of the spend-control Risk story.

Priya-specific checks require important but non-chaotic subscriptions, parent extra support, education-loan part payment, disciplined fund topup, and preservation of the responsibility-burdened Watch story.
