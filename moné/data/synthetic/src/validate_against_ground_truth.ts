// ============================================================================
// Synthetic Dataset Validator — Pass 1
// ============================================================================

import type {
  AAPayload,
  AATransaction,
  GroundTruthLabels,
  GroundTruthFile,
  ValidationCheck,
  ValidationReport,
} from "./types.ts";
import { dayOfWeekName, timeOfDayFromHour } from "./random.ts";

const DATASET_ID = "aarav_spend_control_normal";

interface ValidationInput {
  datasetId: string;
  payload: AAPayload[];
  groundTruth: GroundTruthFile;
  accountsCsv: string;
  transactionsCsv: string;
  monthlyCashflowCsv: string;
  modeSpendingCsv: string;
}

export function validateDataset(input: ValidationInput): ValidationReport {
  const checks: ValidationCheck[] = [];
  const account = input.payload[0]?.data[0]?.decryptedFI.account;
  const payloadTransactions = account?.transactions.transaction ?? [];
  const groundTruthIds = new Set(input.groundTruth.transactions.map((t) => t.transaction_id));
  const payloadIds = new Set(payloadTransactions.map((t) => t.txnId));
  const gtById = new Map(input.groundTruth.transactions.map((t) => [t.transaction_id, t.ground_truth]));

  const add = (
    id: string,
    name: string,
    category: string,
    expected: string,
    actual: string,
    result: "pass" | "fail" | "warning",
    severity: "FATAL" | "ERROR" | "WARNING",
  ) => checks.push({ id, name, category, expected, actual, result, severity });

  add(
    "1.1",
    "payload_valid_json",
    "aa_structure",
    "Parseable JSON array of FIP objects",
    Array.isArray(input.payload) ? `Valid array with ${input.payload.length} FIP object(s)` : "Payload is not an array",
    Array.isArray(input.payload) && input.payload.length > 0 ? "pass" : "fail",
    "FATAL",
  );

  add(
    "1.4",
    "account_core_sections_present",
    "aa_structure",
    "Account has profile, summary, transactions, masked account number, linked ref",
    account
      ? `profile=${Boolean(account.profile)}, summary=${Boolean(account.summary)}, transactions=${Boolean(account.transactions)}, masked=${Boolean(account.maskedAccNumber)}, linked=${Boolean(account.linkedAccRef)}`
      : "No account found",
    account?.profile && account?.summary && account?.transactions && account?.maskedAccNumber && account?.linkedAccRef ? "pass" : "fail",
    "FATAL",
  );

  const requiredTxnFields = ["txnId", "type", "mode", "amount", "narration", "reference", "valueDate", "currentBalance", "transactionTimestamp"];
  const missingTxnFields = payloadTransactions.flatMap((txn) =>
    requiredTxnFields.filter((field) => !(field in txn)).map((field) => `${txn.txnId}:${field}`)
  );
  add(
    "1.7",
    "transaction_fields_present",
    "aa_structure",
    "Every transaction has required AA deposit fields",
    missingTxnFields.length === 0 ? `All ${payloadTransactions.length} transactions have required fields` : missingTxnFields.slice(0, 5).join(", "),
    missingTxnFields.length === 0 ? "pass" : "fail",
    "ERROR",
  );

  add(
    "3.1",
    "transaction_ids_unique",
    "transactions",
    "All txnIds are unique",
    `${payloadIds.size} unique IDs for ${payloadTransactions.length} transactions`,
    payloadIds.size === payloadTransactions.length ? "pass" : "fail",
    "FATAL",
  );

  const chronological = payloadTransactions.every((txn, index) => {
    if (index === 0) return true;
    return payloadTransactions[index - 1].transactionTimestamp.localeCompare(txn.transactionTimestamp) <= 0;
  });
  add(
    "3.2",
    "transactions_chronological",
    "transactions",
    "Transactions are in ascending timestamp order",
    chronological ? "Transactions are chronological" : "At least one transaction is out of order",
    chronological ? "pass" : "fail",
    "ERROR",
  );

  const invalidAmounts = payloadTransactions.filter((txn) => Number(txn.amount) <= 0 || Number.isNaN(Number(txn.amount)));
  add(
    "3.3",
    "amounts_positive",
    "transactions",
    "Every transaction amount is greater than zero",
    invalidAmounts.length === 0 ? "All amounts are positive" : `${invalidAmounts.length} invalid amount(s)`,
    invalidAmounts.length === 0 ? "pass" : "fail",
    "ERROR",
  );

  const balanceBreaks: string[] = [];
  let previousBalance = Number(input.accountsCsv.split("\n")[1]?.split(",")[6] ?? 0);
  for (const txn of payloadTransactions) {
    const amount = Number(txn.amount);
    const expected = txn.type === "CREDIT" ? previousBalance + amount : previousBalance - amount;
    const actual = Number(txn.currentBalance);
    if (Math.abs(expected - actual) > 1) balanceBreaks.push(txn.txnId);
    previousBalance = actual;
  }
  add(
    "3.4",
    "balances_update_consistently",
    "transactions",
    "Previous balance plus/minus amount equals current balance",
    balanceBreaks.length === 0 ? "All balances reconcile within Rs 1" : `Mismatches: ${balanceBreaks.slice(0, 5).join(", ")}`,
    balanceBreaks.length === 0 ? "pass" : "fail",
    "ERROR",
  );

  const salaryTxns = payloadTransactions.filter((txn) => gtById.get(txn.txnId)?.is_salary);
  add(
    "4.1",
    "salary_detectable",
    "behavioral",
    "Monthly salary near 28th for 12 months",
    `Found ${salaryTxns.length} salary credits: ${salaryTxns.map((t) => t.valueDate).join(", ")}`,
    salaryTxns.length === 12 && salaryTxns.every((t) => Number(t.valueDate.slice(8, 10)) >= 28) ? "pass" : "fail",
    "ERROR",
  );

  const rentTxns = payloadTransactions.filter((txn) => gtById.get(txn.txnId)?.is_rent);
  add(
    "4.2",
    "rent_detectable",
    "behavioral",
    "Monthly rent debit on expected date",
    `Found ${rentTxns.length} rent debits`,
    rentTxns.length === 12 ? "pass" : "fail",
    "ERROR",
  );

  const sipTxns = payloadTransactions.filter((txn) => gtById.get(txn.txnId)?.is_sip);
  add(
    "4.3",
    "sip_detectable",
    "behavioral",
    "Two SIP debits per month",
    `Found ${sipTxns.length} SIP debits`,
    sipTxns.length === 24 ? "pass" : "fail",
    "ERROR",
  );

  const weekendDiscretionary = sumPayload(payloadTransactions, gtById, (gt) =>
    gt.is_discretionary && (gt.day_of_week === "saturday" || gt.day_of_week === "sunday")
  );
  const weekdayDiscretionary = sumPayload(payloadTransactions, gtById, (gt) =>
    gt.is_discretionary && gt.day_of_week !== "saturday" && gt.day_of_week !== "sunday"
  );
  add(
    "4.5",
    "weekend_spending_visible",
    "behavioral",
    "Weekend discretionary spending is meaningfully visible",
    `Weekend discretionary Rs ${weekendDiscretionary.toFixed(2)}, weekday discretionary Rs ${weekdayDiscretionary.toFixed(2)}`,
    weekendDiscretionary > 0 && weekdayDiscretionary > 0 ? "pass" : "fail",
    "WARNING",
  );

  add(
    "5.1",
    "ground_truth_one_to_one",
    "ground_truth",
    "Every payload transaction has one ground truth record",
    `${payloadTransactions.length} payload transactions, ${input.groundTruth.transactions.length} ground truth records`,
    payloadTransactions.length === input.groundTruth.transactions.length
      && payloadTransactions.every((txn) => groundTruthIds.has(txn.txnId))
      && input.groundTruth.transactions.every((record) => payloadIds.has(record.transaction_id))
      ? "pass" : "fail",
    "FATAL",
  );

  const inconsistentGt = input.groundTruth.transactions.filter((record) => {
    const gt = record.ground_truth;
    return (gt.is_income && gt.is_obligation)
      || (gt.is_salary && !gt.is_income)
      || (gt.is_sip && !gt.is_obligation)
      || (gt.is_subscription && !gt.is_obligation)
      || (gt.is_utility && !gt.is_obligation)
      || (gt.is_tax && gt.is_discretionary)
      || (gt.is_internal_transfer && gt.is_income)
      || (gt.is_refund && gt.is_income);
  });
  add(
    "5.3",
    "ground_truth_consistency",
    "ground_truth",
    "Classification flags do not contradict each other",
    inconsistentGt.length === 0 ? "No contradictory labels found" : `${inconsistentGt.length} inconsistent record(s)`,
    inconsistentGt.length === 0 ? "pass" : "fail",
    "ERROR",
  );

  const cashWithdrawals = input.groundTruth.transactions.filter((record) => record.ground_truth.category === "cash_withdrawal");
  add(
    "5.11",
    "cash_withdrawals_marked_blindspot",
    "ground_truth",
    "ATM withdrawals are marked as cash blind spots",
    `Found ${cashWithdrawals.length} cash withdrawal(s)`,
    cashWithdrawals.length > 0 && cashWithdrawals.every((record) => record.ground_truth.is_cash_blindspot) ? "pass" : "warning",
    "WARNING",
  );

  const transactionCsvRows = nonEmptyDataRows(input.transactionsCsv);
  const monthlyRows = nonEmptyDataRows(input.monthlyCashflowCsv);
  const modeRows = nonEmptyDataRows(input.modeSpendingCsv);
  add(
    "6.2",
    "transactions_csv_matches_payload",
    "csv",
    "transactions.csv row count matches payload transaction count",
    `${transactionCsvRows.length} CSV rows, ${payloadTransactions.length} payload transactions`,
    transactionCsvRows.length === payloadTransactions.length ? "pass" : "fail",
    "ERROR",
  );
  add(
    "6.3",
    "monthly_cashflow_covers_period",
    "csv",
    "monthly_cashflow.csv has 12 data rows",
    `${monthlyRows.length} monthly rows`,
    monthlyRows.length === 12 ? "pass" : "fail",
    "ERROR",
  );
  add(
    "6.5",
    "mode_summary_present",
    "csv",
    "mode_spending_summary.csv includes debit modes",
    `${modeRows.length} mode rows`,
    modeRows.length > 0 ? "pass" : "warning",
    "WARNING",
  );

  const monthlyReconciliation = reconcileMonthlyCashflow(input.monthlyCashflowCsv, payloadTransactions, gtById, openingBalanceFromAccountsCsv(input.accountsCsv));
  add(
    "6.6",
    "monthly_cashflow_reconciles_to_payload",
    "csv",
    "monthly_cashflow.csv totals are regenerated from deposit payload transactions",
    monthlyReconciliation.ok ? "Monthly cashflow reconciles" : monthlyReconciliation.message,
    monthlyReconciliation.ok ? "pass" : "fail",
    "ERROR",
  );

  const modeReconciliation = reconcileModeSummary(input.modeSpendingCsv, payloadTransactions);
  add(
    "6.7",
    "mode_summary_reconciles_to_payload",
    "csv",
    "mode_spending_summary.csv totals are regenerated from deposit payload transactions",
    modeReconciliation.ok ? "Mode summary reconciles" : modeReconciliation.message,
    modeReconciliation.ok ? "pass" : "fail",
    "ERROR",
  );

  const fiTypes = input.payload.flatMap((fip) => fip.data.map((item) => item.decryptedFI.type));
  const unexpectedFiTypes = fiTypes.filter((type) => type !== "deposit");
  add(
    "7.8",
    "unexpected_fi_types_absent",
    "aggregate",
    "Pass 1 output contains deposit rows only",
    unexpectedFiTypes.length === 0 ? `FI types: ${fiTypes.join(", ")}` : `Unexpected FI types: ${unexpectedFiTypes.join(", ")}`,
    unexpectedFiTypes.length === 0 ? "pass" : "fail",
    "ERROR",
  );

  const metadataMismatches = payloadTransactions.filter((txn) => {
    const gt = gtById.get(txn.txnId);
    if (!gt) return true;
    const hour = Number(txn.transactionTimestamp.slice(11, 13));
    return gt.day_of_week !== dayOfWeekName(txn.valueDate)
      || gt.time_of_day !== timeOfDayFromHour(hour)
      || gt.salary_cycle_phase !== salaryCyclePhaseFromLastSalary(txn.valueDate, salaryTxns.map((salaryTxn) => salaryTxn.valueDate));
  });
  add(
    "7.9",
    "ground_truth_time_metadata_matches_transaction",
    "ground_truth",
    "day_of_week, time_of_day, and salary_cycle_phase are derived from transaction date/timestamp",
    metadataMismatches.length === 0 ? "All transaction metadata matches" : `${metadataMismatches.length} metadata mismatch(es)`,
    metadataMismatches.length === 0 ? "pass" : "fail",
    "ERROR",
  );

  const balances = payloadTransactions.map((txn) => Number(txn.currentBalance));
  const minBalance = Math.min(...balances);
  add(
    "7.10",
    "negative_balance_policy",
    "aggregate",
    "Deposit account balance must not go negative in Aarav normal Pass 1",
    `Minimum balance Rs ${minBalance.toFixed(2)}`,
    minBalance >= 0 ? "pass" : "fail",
    "ERROR",
  );

  const holders = input.payload.flatMap((fip) =>
    fip.data.flatMap((item) => item.decryptedFI.account.profile.holders.holder)
  );
  const piiViolations = holders.filter((holder) =>
    !holder.name.includes("Synthetic")
    || !holder.email.endsWith(".invalid")
    || holder.mobile !== "9000000000"
    || !holder.address.includes("Synthetic")
  );
  add(
    "7.11",
    "holder_profile_uses_synthetic_placeholders",
    "privacy",
    "Holder profile fields use synthetic placeholders, not real-looking PII",
    piiViolations.length === 0 ? "Holder profile fields are synthetic placeholders" : `${piiViolations.length} holder profile(s) need placeholder values`,
    piiViolations.length === 0 ? "pass" : "fail",
    "ERROR",
  );

  const warningMissingSafeToSpend = input.groundTruth.transactions.some((record) =>
    record.ground_truth.expected_safe_to_spend_impact !== null
  );
  add(
    "7.5",
    "safe_to_spend_expected_values",
    "aggregate",
    "Safe-to-spend expected impacts exist on debits",
    warningMissingSafeToSpend ? "Found safe-to-spend impact labels" : "No safe-to-spend labels found",
    warningMissingSafeToSpend ? "pass" : "warning",
    "WARNING",
  );

  const failureCounts = checks.reduce((acc, check) => {
    if (check.result === "fail") {
      const key = check.severity.toLowerCase() as "fatal" | "error" | "warning";
      acc[key]++;
    }
    if (check.result === "warning") acc.warning++;
    return acc;
  }, { fatal: 0, error: 0, warning: 0 });

  const status: "pass" | "partial" | "fail" = failureCounts.fatal > 0 || failureCounts.error > 0
    ? "fail"
    : failureCounts.warning > 0
      ? "partial"
      : "pass";

  const gtRecords = input.groundTruth.transactions;
  const openingBalance = Number(input.accountsCsv.split("\n")[1]?.split(",")[6] ?? 0);
  const closingBalance = Number(account?.summary.currentBalance ?? openingBalance);

  return {
    dataset_id: input.datasetId,
    generated_at: new Date().toISOString(),
    status,
    severity_counts: failureCounts,
    checks,
    summary: {
      total_transactions: payloadTransactions.length,
      deposit_transactions: payloadTransactions.length,
      income_events: gtRecords.filter((r) => r.ground_truth.is_income).length,
      obligation_events: gtRecords.filter((r) => r.ground_truth.is_obligation).length,
      discretionary_events: gtRecords.filter((r) => r.ground_truth.is_discretionary).length,
      life_events: gtRecords.filter((r) => r.ground_truth.life_event !== null).length,
      nudge_candidates: gtRecords.filter((r) => r.ground_truth.nudge_candidate).length,
      months_covered: monthlyRows.length,
      opening_balance: openingBalance,
      closing_balance: closingBalance,
    },
  };
}

function sumPayload(
  transactions: AATransaction[],
  gtById: Map<string, GroundTruthLabels>,
  predicate: (gt: GroundTruthLabels) => boolean,
): number {
  return transactions.reduce((sum, txn) => {
    const gt = gtById.get(txn.txnId);
    if (!gt || !predicate(gt)) return sum;
    return sum + Number(txn.amount);
  }, 0);
}

function nonEmptyDataRows(csv: string): string[] {
  return csv.trim().split("\n").slice(1).filter((line) => line.trim().length > 0);
}

function openingBalanceFromAccountsCsv(csv: string): number {
  const row = parseCsv(csv)[0];
  return Number(row?.opening_balance ?? 0);
}

function reconcileMonthlyCashflow(
  csv: string,
  transactions: AATransaction[],
  gtById: Map<string, GroundTruthLabels>,
  openingBalance: number,
): { ok: boolean; message: string } {
  const expected = new Map<string, { income: number; obligations: number; discretionary: number; total_debits: number; total_credits: number }>();
  for (const txn of transactions) {
    const month = txn.valueDate.slice(0, 7);
    if (!expected.has(month)) {
      expected.set(month, { income: 0, obligations: 0, discretionary: 0, total_debits: 0, total_credits: 0 });
    }
    const row = expected.get(month)!;
    const amount = Number(txn.amount);
    const gt = gtById.get(txn.txnId);
    if (txn.type === "CREDIT") {
      row.total_credits += amount;
      if (gt?.is_income) row.income += amount;
    } else {
      row.total_debits += amount;
      if (gt?.is_obligation) row.obligations += amount;
      if (gt?.is_discretionary) row.discretionary += amount;
    }
  }

  const rows = parseCsv(csv);
  let runningBalance = openingBalance;
  for (const row of rows) {
    const e = expected.get(row.month);
    if (!e) return { ok: false, message: `Unexpected month ${row.month}` };
    const net = round2(e.total_credits - e.total_debits);
    const closing = round2(runningBalance + net);
    const checks = [
      ["income", e.income],
      ["obligations", e.obligations],
      ["discretionary", e.discretionary],
      ["total_debits", e.total_debits],
      ["total_credits", e.total_credits],
      ["net", net],
      ["opening_balance", runningBalance],
      ["closing_balance", closing],
    ] as const;
    for (const [key, value] of checks) {
      if (Math.abs(Number(row[key]) - round2(value)) > 0.01) {
        return { ok: false, message: `${row.month}.${key} expected ${round2(value)}, found ${row[key]}` };
      }
    }
    runningBalance = closing;
  }

  return { ok: rows.length === expected.size, message: `${rows.length} CSV rows, ${expected.size} expected months` };
}

function reconcileModeSummary(csv: string, transactions: AATransaction[]): { ok: boolean; message: string } {
  const expected = new Map<string, { total: number; count: number }>();
  let grandTotal = 0;
  for (const txn of transactions) {
    if (txn.type !== "DEBIT") continue;
    const current = expected.get(txn.mode) ?? { total: 0, count: 0 };
    current.total += Number(txn.amount);
    current.count += 1;
    grandTotal += Number(txn.amount);
    expected.set(txn.mode, current);
  }

  for (const row of parseCsv(csv)) {
    const e = expected.get(row.mode);
    if (!e) return { ok: false, message: `Unexpected mode ${row.mode}` };
    const expectedPct = grandTotal > 0 ? round2(e.total / grandTotal * 100) : 0;
    if (Math.abs(Number(row.total_amount) - round2(e.total)) > 0.01) return { ok: false, message: `${row.mode}.total_amount mismatch` };
    if (Number(row.transaction_count) !== e.count) return { ok: false, message: `${row.mode}.transaction_count mismatch` };
    if (Math.abs(Number(row.avg_amount) - round2(e.total / e.count)) > 0.01) return { ok: false, message: `${row.mode}.avg_amount mismatch` };
    if (Math.abs(Number(row.percentage_of_total) - expectedPct) > 0.01) return { ok: false, message: `${row.mode}.percentage_of_total mismatch` };
  }

  return { ok: parseCsv(csv).length === expected.size, message: `${parseCsv(csv).length} CSV rows, ${expected.size} expected modes` };
}

function salaryCyclePhaseFromLastSalary(date: string, salaryDates: string[]): "week_1" | "week_2" | "week_3" | "week_4" {
  const priorSalaryDates = salaryDates.filter((salaryDate) => salaryDate <= date).sort();
  const lastSalaryDate = priorSalaryDates.at(-1) ?? salaryDates.sort()[0];
  const daysAfterSalary = Math.floor((Date.parse(`${date}T00:00:00Z`) - Date.parse(`${lastSalaryDate}T00:00:00Z`)) / 86_400_000);
  if (daysAfterSalary <= 7) return "week_1";
  if (daysAfterSalary <= 14) return "week_2";
  if (daysAfterSalary <= 21) return "week_3";
  return "week_4";
}

function parseCsv(csv: string): Record<string, string>[] {
  const lines = csv.trim().split("\n").filter((line) => line.trim().length > 0);
  const header = splitCsvLine(lines[0]);
  return lines.slice(1).map((line) => {
    const values = splitCsvLine(line);
    return Object.fromEntries(header.map((key, index) => [key, values[index] ?? ""]));
  });
}

function splitCsvLine(line: string): string[] {
  const values: string[] = [];
  let current = "";
  let inQuotes = false;
  for (let i = 0; i < line.length; i++) {
    const char = line[i];
    const next = line[i + 1];
    if (char === "\"" && next === "\"") {
      current += "\"";
      i++;
    } else if (char === "\"") {
      inQuotes = !inQuotes;
    } else if (char === "," && !inQuotes) {
      values.push(current);
      current = "";
    } else {
      current += char;
    }
  }
  values.push(current);
  return values;
}

function round2(value: number): number {
  return Math.round(value * 100) / 100;
}

async function main() {
  const datasetId = getArg("--dataset") ?? DATASET_ID;
  const outputDir = `data/synthetic/output/${datasetId}`;
  const [payloadText, groundTruthText, accountsCsv, transactionsCsv, monthlyCashflowCsv, modeSpendingCsv] = await Promise.all([
    Deno.readTextFile(`${outputDir}/raw_payload.json`),
    Deno.readTextFile(`${outputDir}/ground_truth.json`),
    Deno.readTextFile(`${outputDir}/accounts.csv`),
    Deno.readTextFile(`${outputDir}/transactions.csv`),
    Deno.readTextFile(`${outputDir}/monthly_cashflow.csv`),
    Deno.readTextFile(`${outputDir}/mode_spending_summary.csv`),
  ]);

  const report = validateDataset({
    datasetId,
    payload: JSON.parse(payloadText),
    groundTruth: JSON.parse(groundTruthText),
    accountsCsv,
    transactionsCsv,
    monthlyCashflowCsv,
    modeSpendingCsv,
  });

  await Deno.writeTextFile(`${outputDir}/validation_report.json`, JSON.stringify(report, null, 2) + "\n");
  console.log(`${datasetId}: ${report.status} (${report.summary.total_transactions} transactions)`);
}

function getArg(name: string): string | undefined {
  const index = Deno.args.indexOf(name);
  if (index === -1) return undefined;
  return Deno.args[index + 1];
}

if (import.meta.main) {
  await main();
}
