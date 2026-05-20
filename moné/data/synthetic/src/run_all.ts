// ============================================================================
// Synthetic Data Runner — Pass 1 Aarav Deposit Dataset
// ============================================================================

import type { PersonaConfig } from "./types.ts";
import { SeededRandom } from "./random.ts";
import { generateCalendar } from "./generate_calendar.ts";
import { generateDailyTransactions } from "./generate_daily_transactions.ts";
import { buildAAPayload } from "./build_aa_payload.ts";
import { buildGroundTruth } from "./build_ground_truth.ts";
import {
  buildAccountsCSV,
  buildIncomeCandidates,
  buildModeSpendingCSV,
  buildMonthlyCashflowCSV,
  buildRecurringCandidates,
  buildTransactionsCSV,
} from "./export_canonical_csvs.ts";
import { validateDataset } from "./validate_against_ground_truth.ts";

const DATASET_ID = "aarav_spend_control_normal";

async function main() {
  const datasetId = getArg("--dataset") ?? DATASET_ID;
  if (datasetId !== DATASET_ID) {
    throw new Error(`Pass 1 only supports ${DATASET_ID}. Received: ${datasetId}`);
  }

  const configPath = `data/synthetic/configs/${datasetId}.yaml`;
  await assertConfigExists(configPath);

  const config = aaravSpendControlNormalConfig();
  const rng = new SeededRandom(config.seed);
  const calendar = generateCalendar(config, rng);
  const transactions = generateDailyTransactions(config, calendar, rng);

  const linkedAccRef = rng.uuid();
  const maskedAccNumber = "XXXXXXXX1234";
  const accountId = linkedAccRef;

  const payload = buildAAPayload(config, transactions, linkedAccRef, maskedAccNumber);
  const groundTruth = buildGroundTruth(config, datasetId, transactions);
  const accountsCsv = buildAccountsCSV(config, transactions, accountId);
  const transactionsCsv = buildTransactionsCSV(transactions, accountId);
  const monthlyCashflowCsv = buildMonthlyCashflowCSV(config, transactions);
  const modeSpendingCsv = buildModeSpendingCSV(transactions);
  const incomeCandidates = buildIncomeCandidates(transactions);
  const recurringCandidates = buildRecurringCandidates(transactions);
  const validationReport = validateDataset({
    datasetId,
    payload,
    groundTruth,
    accountsCsv,
    transactionsCsv,
    monthlyCashflowCsv,
    modeSpendingCsv,
  });

  const outputDir = `data/synthetic/output/${datasetId}`;
  await Deno.mkdir(outputDir, { recursive: true });
  await Promise.all([
    writeJson(`${outputDir}/raw_payload.json`, payload),
    writeJson(`${outputDir}/ground_truth.json`, groundTruth),
    Deno.writeTextFile(`${outputDir}/accounts.csv`, accountsCsv),
    Deno.writeTextFile(`${outputDir}/transactions.csv`, transactionsCsv),
    Deno.writeTextFile(`${outputDir}/monthly_cashflow.csv`, monthlyCashflowCsv),
    Deno.writeTextFile(`${outputDir}/mode_spending_summary.csv`, modeSpendingCsv),
    writeJson(`${outputDir}/income_candidates_expected.json`, incomeCandidates),
    writeJson(`${outputDir}/recurring_candidates_expected.json`, recurringCandidates),
    writeJson(`${outputDir}/validation_report.json`, validationReport),
  ]);

  console.log(`${datasetId}: wrote ${transactions.length} deposit transactions`);
  console.log(`${datasetId}: validation ${validationReport.status}`);
}

async function assertConfigExists(path: string) {
  try {
    await Deno.stat(path);
  } catch {
    throw new Error(`Missing config file: ${path}`);
  }
}

async function writeJson(path: string, value: unknown) {
  await Deno.writeTextFile(path, JSON.stringify(value, null, 2) + "\n");
}

function getArg(name: string): string | undefined {
  const index = Deno.args.indexOf(name);
  if (index === -1) return undefined;
  return Deno.args[index + 1];
}

function aaravSpendControlNormalConfig(): PersonaConfig {
  return {
    persona: {
      id: "aarav",
      name: "Synthetic Aarav",
      age: 27,
      occupation: "Software Developer",
      city: "Bangalore",
      pan: "SYNTH0000X",
      email: "aarav.synthetic@example.invalid",
      mobile: "9000000000",
      address: "Synthetic HSR Layout address, Bangalore",
      dob: "1999-01-01",
    },
    seed: "mone-aarav-normal-v1",
    period: {
      start: "2025-06-01",
      end: "2026-05-31",
    },
    accounts: {
      deposit: {
        bank: "HDFC",
        ifsc: "HDFC0001234",
        branch: "HSR Layout",
        type: "SAVINGS",
        opening_balance: 150000,
      },
    },
    income: {
      salary: {
        amount: 165000,
        day: 28,
        employer: "TECHCORP INDIA PVT LTD",
        mode: "FT",
      },
      freelance: {
        min: 8000,
        max: 24000,
        monthly_probability: 0.25,
      },
    },
    obligations: {
      rent: {
        amount: 42000,
        day: 5,
        payee: "Ramesh Kumar",
        mode: "UPI",
      },
      sip: [
        { amount: 10000, day: 6, fund: "HDFC Bluechip Fund" },
        { amount: 5000, day: 10, fund: "Axis Midcap Fund" },
      ],
      broadband: {
        amount: 999,
        day: 15,
        provider: "ACT Fibernet",
      },
      mobile: {
        amount: 599,
        day: 18,
        provider: "Jio",
      },
      electricity: {
        amount_min: 800,
        amount_max: 2200,
        day: 12,
      },
      subscriptions: [
        { name: "Netflix", amount: 649, day: 12 },
        { name: "Spotify", amount: 119, day: 14 },
        { name: "iCloud", amount: 75, day: 14 },
        { name: "Amazon Prime", amount: 179, day: 20 },
      ],
      credit_card_due_day: 23,
    },
    goals: [
      {
        id: "emergency_fund",
        name: "Emergency Fund",
        target: 300000,
        current: 180000,
        monthly_allocation: 10000,
        allocation_day: 29,
      },
      {
        id: "vacation_bali",
        name: "Bali Vacation",
        target: 150000,
        current: 37500,
        monthly_allocation: 8000,
        allocation_day: 29,
      },
      {
        id: "laptop",
        name: "New Laptop",
        target: 120000,
        current: 42000,
        monthly_allocation: 6000,
        allocation_day: 30,
      },
    ],
    life_events: [],
    behavioral_defaults: {
      weekday_food_delivery_prob: 0.6,
      weekend_dining_out_prob: 0.7,
      friday_social_prob: 0.8,
      coffee_daily_prob: 0.7,
      cab_vs_metro: 0.4,
      impulse_shopping_weekend_prob: 0.3,
      late_night_food_prob: 0.15,
      atm_withdrawal_monthly_min: 1,
      atm_withdrawal_monthly_max: 2,
      grocery_weekend_prob: 0.85,
      weekday_cab_prob: 0.4,
    },
  };
}

if (import.meta.main) {
  await main();
}
