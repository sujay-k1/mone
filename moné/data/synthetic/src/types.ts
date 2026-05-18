// ============================================================================
// Moné Synthetic Data Generator — Core Types
// ============================================================================

// --- Persona & Config ---

export interface PersonaConfig {
  persona: {
    id: string;
    name: string;
    age: number;
    occupation: string;
    city: string;
    pan: string;
    email: string;
    mobile: string;
    address: string;
    dob: string;
  };
  seed: string;
  period: { start: string; end: string };
  accounts: {
    deposit?: DepositAccountConfig;
    mutual_funds?: MutualFundsAccountConfig;
    recurring_deposit?: RDAccountConfig;
    term_deposit?: TDAccountConfig;
    insurance_policies?: InsuranceAccountConfig;
  };
  income: IncomeConfig;
  obligations: ObligationsConfig;
  goals: GoalConfig[];
  life_events: LifeEventConfig[];
  behavioral_defaults: BehavioralDefaults;
}

export interface DepositAccountConfig {
  bank: string;
  ifsc: string;
  branch: string;
  type: "SAVINGS" | "CURRENT";
  opening_balance: number;
}

export interface MutualFundsAccountConfig {
  amc: string;
  schemes: { name: string; folio: string; nav: number; units: number }[];
}

export interface RDAccountConfig {
  bank: string;
  monthly_amount: number;
  tenure_months: number;
  interest_rate: number;
  start_date: string;
}

export interface TDAccountConfig {
  bank: string;
  principal: number;
  tenure_months: number;
  interest_rate: number;
  start_date: string;
}

export interface InsuranceAccountConfig {
  policies: {
    type: string;
    insurer: string;
    policy_number: string;
    sum_assured: number;
    premium: number;
    frequency: "monthly" | "quarterly" | "annual";
    next_due_day: number;
  }[];
}

export interface IncomeConfig {
  salary: {
    amount: number;
    day: number;
    employer: string;
    mode: TransactionMode;
  };
  freelance?: {
    min: number;
    max: number;
    monthly_probability: number;
  };
}

export interface ObligationsConfig {
  rent?: { amount: number; day: number; payee: string; mode: TransactionMode };
  emi?: { amount: number; day: number; lender: string; type: string }[];
  sip?: { amount: number; day: number; fund: string }[];
  broadband?: { amount: number; day: number; provider: string };
  mobile?: { amount: number; day: number; provider: string };
  electricity?: { amount_min: number; amount_max: number; day: number };
  subscriptions?: { name: string; amount: number; day: number }[];
  domestic_help?: { amount: number; day: number };
  family_support?: { amount: number; day: number; recipient: string };
  nps?: { amount: number; day: number };
  insurance_premiums?: { name: string; amount: number; month: number; day: number }[];
  credit_card_due_day?: number;
}

export interface GoalConfig {
  id: string;
  name: string;
  target: number;
  current: number;
  monthly_allocation: number;
  allocation_day: number;
}

export interface LifeEventConfig {
  type: LifeEventType;
  start_month: number; // 1-indexed month offset from period start
  duration_days: number;
  params: Record<string, unknown>;
}

export interface BehavioralDefaults {
  weekday_food_delivery_prob: number;
  weekend_dining_out_prob: number;
  friday_social_prob: number;
  coffee_daily_prob: number;
  cab_vs_metro: number; // probability of cab over metro
  impulse_shopping_weekend_prob: number;
  late_night_food_prob: number;
  atm_withdrawal_monthly_min: number;
  atm_withdrawal_monthly_max: number;
  grocery_weekend_prob: number;
  weekday_cab_prob: number;
}

// --- Behavioral States ---

export type BehavioralState =
  | "normal"
  | "stressed"
  | "social"
  | "frugal"
  | "overconfident_after_salary"
  | "cautious_before_salary"
  | "travel_mode"
  | "health_event"
  | "family_event"
  | "work_crunch"
  | "appraisal_month"
  | "job_switch_phase";

export type LifeEventType =
  | "job_switch"
  | "salary_increment"
  | "work_travel"
  | "friend_wedding"
  | "health_issue"
  | "festival_season"
  | "gadget_purchase"
  | "family_emergency"
  | "tax_filing"
  | "appraisal_bonus"
  | "healthcare_shock"
  | "home_upgrade"
  | "travel_vacation";

// --- Calendar ---

export interface CalendarMonth {
  year: number;
  month: number; // 1-12
  salary_day: number;
  rent_day: number;
  sip_days: number[];
  credit_card_due_day: number;
  utility_due_days: number[];
  subscription_days: number[];
  expected_weekend_spike: boolean;
  life_events: ActiveLifeEvent[];
  days: CalendarDay[];
}

export interface CalendarDay {
  date: string; // YYYY-MM-DD
  day_of_week: DayOfWeek;
  day_of_month: number;
  is_weekend: boolean;
  is_salary_day: boolean;
  is_month_start: boolean;
  is_month_end: boolean;
  salary_cycle_phase: SalaryCyclePhase;
  behavioral_state: BehavioralState;
  active_life_events: ActiveLifeEvent[];
}

export type DayOfWeek = "monday" | "tuesday" | "wednesday" | "thursday" | "friday" | "saturday" | "sunday";

export type SalaryCyclePhase = "week_1" | "week_2" | "week_3" | "week_4";

export interface ActiveLifeEvent {
  type: LifeEventType;
  day_in_event: number;
  total_days: number;
  params: Record<string, unknown>;
}

// --- Transactions ---

export type TransactionMode = "UPI" | "CARD" | "FT" | "NEFT" | "RTGS" | "CASH" | "ATM" | "OTHERS";
export type TransactionDirection = "CREDIT" | "DEBIT";

export interface GeneratedTransaction {
  txn_id: string;
  date: string; // YYYY-MM-DD
  timestamp: string; // ISO 8601 with +05:30
  direction: TransactionDirection;
  mode: TransactionMode;
  amount: number;
  narration: string;
  reference: string;
  balance_after: number;
  ground_truth: GroundTruthLabels;
}

export interface GroundTruthLabels {
  category: string;
  sub_category: string;
  merchant: string;
  is_income: boolean;
  is_salary: boolean;
  is_variable_income: boolean;
  is_internal_transfer: boolean;
  is_refund: boolean;
  is_obligation: boolean;
  is_rent: boolean;
  is_emi: boolean;
  is_sip: boolean;
  is_rd: boolean;
  is_insurance: boolean;
  is_subscription: boolean;
  is_utility: boolean;
  is_family_support: boolean;
  is_tax: boolean;
  is_discretionary: boolean;
  is_recurring: boolean;
  is_reimbursable: boolean;
  is_unplanned: boolean;
  is_healthcare: boolean;
  is_luxury: boolean;
  is_travel: boolean;
  is_gift: boolean;
  is_cash_blindspot: boolean;
  is_credit_card_payment: boolean;
  is_goal_allocation: boolean;
  linked_goal_id: string | null;
  affects_goal: boolean;
  nudge_candidate: boolean;
  expected_nudge_type: string | null;
  expected_user_confirmation: string | null;
  expected_safe_to_spend_impact: number | null;
  expected_goal_drift_days: number | null;
  life_event: string | null;
  behavioral_state: BehavioralState;
  day_of_week: DayOfWeek;
  time_of_day: TimeOfDay;
  salary_cycle_phase: SalaryCyclePhase;
  confidence_expected: "high" | "medium" | "low";
  reimbursement_linked_txn_ids: string[] | null;
  is_reimbursement_credit: boolean;
}

export type TimeOfDay = "morning" | "afternoon" | "evening" | "night" | "late_night";

// --- AA Payload Types ---

export interface AAPayload {
  fipID: string;
  data: AADataItem[];
}

export interface AADataItem {
  decryptedFI: {
    type: string;
    account: AAAccount;
  };
}

export interface AAAccount {
  type: string;
  version: string;
  linkedAccRef: string;
  profile: {
    holders: {
      type: string;
      holder: AAHolder[];
    };
  };
  summary: AADepositSummary;
  transactions: {
    startDate: string;
    endDate: string;
    transaction: AATransaction[];
  };
}

export interface AAHolder {
  dob: string;
  pan: string;
  name: string;
  email: string;
  mobile: string;
  address: string;
  nominee: string;
  ckycCompliance: string;
}

export interface AADepositSummary {
  type: string;
  branch: string;
  status: string;
  currency: string;
  facility: string;
  ifscCode: string;
  micrCode: string;
  openingDate: string;
  currentBalance: string;
  balanceDateTime: string;
}

export interface AATransaction {
  txnId: string;
  type: TransactionDirection;
  mode: TransactionMode;
  amount: string;
  narration: string;
  reference: string;
  valueDate: string;
  currentBalance: string;
  transactionTimestamp: string;
}

// --- Ground Truth File ---

export interface GroundTruthFile {
  dataset_id: string;
  persona_id: string;
  generated_at: string;
  period: { start: string; end: string };
  summary: GroundTruthSummary;
  transactions: GroundTruthRecord[];
}

export interface GroundTruthRecord {
  transaction_id: string;
  persona_id: string;
  account_type: string;
  dataset_id: string;
  ground_truth: GroundTruthLabels;
}

export interface GroundTruthSummary {
  total_transactions: number;
  income_events: number;
  salary_events: number;
  obligation_events: number;
  discretionary_events: number;
  recurring_events: number;
  unplanned_events: number;
  nudge_candidates: number;
  reimbursable_events: number;
  cash_blindspots: number;
  goal_impacting_events: number;
}

// --- Validation ---

export interface ValidationReport {
  dataset_id: string;
  generated_at: string;
  status: "pass" | "partial" | "fail";
  severity_counts: {
    fatal: number;
    error: number;
    warning: number;
  };
  checks: ValidationCheck[];
  summary: {
    total_transactions: number;
    deposit_transactions: number;
    income_events: number;
    obligation_events: number;
    discretionary_events: number;
    life_events: number;
    nudge_candidates: number;
    months_covered: number;
    opening_balance: number;
    closing_balance: number;
  };
}

export interface ValidationCheck {
  id: string;
  name: string;
  category: string;
  expected: string;
  actual: string;
  result: "pass" | "fail" | "warning";
  severity: "FATAL" | "ERROR" | "WARNING";
}

// --- CSV Export ---

export interface AccountCSVRow {
  account_id: string;
  fi_type: string;
  bank: string;
  account_type: string;
  status: string;
  currency: string;
  opening_balance: number;
  closing_balance: number;
  total_credits: number;
  total_debits: number;
  transaction_count: number;
}

export interface TransactionCSVRow {
  transaction_id: string;
  date: string;
  timestamp: string;
  account_id: string;
  fi_type: string;
  direction: string;
  mode: string;
  amount: number;
  narration: string;
  balance_after: number;
  category: string;
  sub_category: string;
  is_income: boolean;
  is_obligation: boolean;
  is_discretionary: boolean;
  is_recurring: boolean;
}

export interface MonthlyCashflowRow {
  month: string; // YYYY-MM
  income: number;
  obligations: number;
  discretionary: number;
  total_debits: number;
  total_credits: number;
  net: number;
  opening_balance: number;
  closing_balance: number;
}

export interface ModeSpendingRow {
  mode: string;
  total_amount: number;
  transaction_count: number;
  avg_amount: number;
  percentage_of_total: number;
}
