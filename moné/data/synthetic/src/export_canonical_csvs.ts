// ============================================================================
// CSV Export — generates canonical CSVs from generated transactions
// ============================================================================

import type {
  PersonaConfig,
  GeneratedTransaction,
  AccountCSVRow,
  TransactionCSVRow,
  MonthlyCashflowRow,
  ModeSpendingRow,
} from "./types.ts";

export function buildAccountsCSV(
  config: PersonaConfig,
  transactions: GeneratedTransaction[],
  accountId: string,
): string {
  const credits = transactions.filter((t) => t.direction === "CREDIT").reduce((s, t) => s + t.amount, 0);
  const debits = transactions.filter((t) => t.direction === "DEBIT").reduce((s, t) => s + t.amount, 0);
  const opening = config.accounts.deposit?.opening_balance ?? 0;
  const closing = transactions.length > 0 ? transactions[transactions.length - 1].balance_after : opening;

  const row: AccountCSVRow = {
    account_id: accountId,
    fi_type: "deposit",
    bank: config.accounts.deposit?.bank ?? "",
    account_type: config.accounts.deposit?.type ?? "SAVINGS",
    status: "ACTIVE",
    currency: "INR",
    opening_balance: opening,
    closing_balance: closing,
    total_credits: Math.round(credits * 100) / 100,
    total_debits: Math.round(debits * 100) / 100,
    transaction_count: transactions.length,
  };

  const header = Object.keys(row).join(",");
  const values = Object.values(row).join(",");
  return `${header}\n${values}\n`;
}

export function buildTransactionsCSV(transactions: GeneratedTransaction[], accountId: string): string {
  const header = "transaction_id,date,timestamp,account_id,fi_type,direction,mode,amount,narration,balance_after,category,sub_category,is_income,is_obligation,is_discretionary,is_recurring";

  const rows = transactions.map((t) => {
    const narration = `"${t.narration.replace(/"/g, '""')}"`;
    return [
      t.txn_id,
      t.date,
      t.timestamp,
      accountId,
      "deposit",
      t.direction,
      t.mode,
      t.amount,
      narration,
      t.balance_after,
      t.ground_truth.category,
      t.ground_truth.sub_category,
      t.ground_truth.is_income,
      t.ground_truth.is_obligation,
      t.ground_truth.is_discretionary,
      t.ground_truth.is_recurring,
    ].join(",");
  });

  return [header, ...rows].join("\n") + "\n";
}

export function buildMonthlyCashflowCSV(
  config: PersonaConfig,
  transactions: GeneratedTransaction[],
): string {
  const monthMap = new Map<string, { income: number; obligations: number; discretionary: number; total_credits: number; total_debits: number }>();

  for (const txn of transactions) {
    const monthKey = txn.date.slice(0, 7);
    if (!monthMap.has(monthKey)) {
      monthMap.set(monthKey, { income: 0, obligations: 0, discretionary: 0, total_credits: 0, total_debits: 0 });
    }
    const m = monthMap.get(monthKey)!;

    if (txn.direction === "CREDIT") {
      m.total_credits += txn.amount;
      if (txn.ground_truth.is_income) m.income += txn.amount;
    } else {
      m.total_debits += txn.amount;
      if (txn.ground_truth.is_obligation) m.obligations += txn.amount;
      if (txn.ground_truth.is_discretionary) m.discretionary += txn.amount;
    }
  }

  const header = "month,income,obligations,discretionary,total_debits,total_credits,net,opening_balance,closing_balance";
  const rows: string[] = [];
  let runningBalance = config.accounts.deposit?.opening_balance ?? 0;

  const sortedMonths = Array.from(monthMap.keys()).sort();
  for (const monthKey of sortedMonths) {
    const m = monthMap.get(monthKey)!;
    const opening = runningBalance;
    const net = Math.round((m.total_credits - m.total_debits) * 100) / 100;
    runningBalance = Math.round((runningBalance + net) * 100) / 100;

    rows.push([
      monthKey,
      Math.round(m.income * 100) / 100,
      Math.round(m.obligations * 100) / 100,
      Math.round(m.discretionary * 100) / 100,
      Math.round(m.total_debits * 100) / 100,
      Math.round(m.total_credits * 100) / 100,
      net,
      Math.round(opening * 100) / 100,
      runningBalance,
    ].join(","));
  }

  return [header, ...rows].join("\n") + "\n";
}

export function buildModeSpendingCSV(transactions: GeneratedTransaction[]): string {
  const modeMap = new Map<string, { total: number; count: number }>();
  let grandTotal = 0;

  for (const txn of transactions) {
    if (txn.direction !== "DEBIT") continue;
    if (!modeMap.has(txn.mode)) modeMap.set(txn.mode, { total: 0, count: 0 });
    const m = modeMap.get(txn.mode)!;
    m.total += txn.amount;
    m.count++;
    grandTotal += txn.amount;
  }

  const header = "mode,total_amount,transaction_count,avg_amount,percentage_of_total";
  const rows: string[] = [];

  for (const [mode, data] of Array.from(modeMap.entries()).sort((a, b) => b[1].total - a[1].total)) {
    rows.push([
      mode,
      Math.round(data.total * 100) / 100,
      data.count,
      Math.round((data.total / data.count) * 100) / 100,
      Math.round((data.total / grandTotal) * 10000) / 100,
    ].join(","));
  }

  return [header, ...rows].join("\n") + "\n";
}

export function buildIncomeCandidates(transactions: GeneratedTransaction[]): object[] {
  return transactions
    .filter((t) => t.ground_truth.is_income)
    .map((t) => ({
      transaction_id: t.txn_id,
      date: t.date,
      amount: t.amount,
      narration: t.narration,
      category: t.ground_truth.category,
      is_salary: t.ground_truth.is_salary,
      is_variable: t.ground_truth.is_variable_income,
      merchant: t.ground_truth.merchant,
    }));
}

export function buildRecurringCandidates(transactions: GeneratedTransaction[]): object[] {
  const recurring = transactions.filter((t) => t.ground_truth.is_recurring && t.direction === "DEBIT");

  const grouped = new Map<string, { count: number; amounts: number[]; dates: string[] }>();
  for (const t of recurring) {
    const key = `${t.ground_truth.category}:${t.ground_truth.merchant}`;
    if (!grouped.has(key)) grouped.set(key, { count: 0, amounts: [], dates: [] });
    const g = grouped.get(key)!;
    g.count++;
    g.amounts.push(t.amount);
    g.dates.push(t.date);
  }

  return Array.from(grouped.entries()).map(([key, data]) => {
    const [category, merchant] = key.split(":");
    const avgAmount = data.amounts.reduce((s, a) => s + a, 0) / data.amounts.length;
    return {
      category,
      merchant,
      occurrence_count: data.count,
      avg_amount: Math.round(avgAmount * 100) / 100,
      min_amount: Math.min(...data.amounts),
      max_amount: Math.max(...data.amounts),
      sample_dates: data.dates.slice(0, 5),
    };
  });
}
