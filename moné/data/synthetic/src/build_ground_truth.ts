// ============================================================================
// Ground Truth Builder — extracts labeled ground truth from generated txns
// ============================================================================

import type {
  PersonaConfig,
  GeneratedTransaction,
  GroundTruthFile,
  GroundTruthRecord,
  GroundTruthSummary,
} from "./types.ts";

export function buildGroundTruth(
  config: PersonaConfig,
  datasetId: string,
  transactions: GeneratedTransaction[],
): GroundTruthFile {
  const records: GroundTruthRecord[] = transactions.map((txn) => ({
    transaction_id: txn.txn_id,
    persona_id: config.persona.id,
    account_type: "deposit",
    dataset_id: datasetId,
    ground_truth: txn.ground_truth,
  }));

  const summary: GroundTruthSummary = {
    total_transactions: records.length,
    income_events: records.filter((r) => r.ground_truth.is_income).length,
    salary_events: records.filter((r) => r.ground_truth.is_salary).length,
    obligation_events: records.filter((r) => r.ground_truth.is_obligation).length,
    discretionary_events: records.filter((r) => r.ground_truth.is_discretionary).length,
    recurring_events: records.filter((r) => r.ground_truth.is_recurring).length,
    unplanned_events: records.filter((r) => r.ground_truth.is_unplanned).length,
    nudge_candidates: records.filter((r) => r.ground_truth.nudge_candidate).length,
    reimbursable_events: records.filter((r) => r.ground_truth.is_reimbursable).length,
    cash_blindspots: records.filter((r) => r.ground_truth.is_cash_blindspot).length,
    goal_impacting_events: records.filter((r) => r.ground_truth.affects_goal).length,
  };

  return {
    dataset_id: datasetId,
    persona_id: config.persona.id,
    generated_at: new Date().toISOString(),
    period: config.period,
    summary,
    transactions: records,
  };
}
