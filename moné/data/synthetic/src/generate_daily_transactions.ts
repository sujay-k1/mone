// ============================================================================
// Daily Transaction Generator — the life simulator core
// ============================================================================
// Generates day-by-day deposit account transactions from persona behavior.
// Does NOT generate random transactions. Generates a person's financial life.

import type {
  PersonaConfig,
  CalendarMonth,
  CalendarDay,
  GeneratedTransaction,
  GroundTruthLabels,
  TransactionMode,
  TransactionDirection,
  BehavioralState,
  TimeOfDay,
} from "./types.ts";
import { SeededRandom, formatTimestamp, formatAmount, timeOfDayFromHour, dayOfWeekName, daysInMonth } from "./random.ts";

interface TransactionBuilder {
  date: string;
  hour: number;
  minute: number;
  direction: TransactionDirection;
  mode: TransactionMode;
  amount: number;
  narration: string;
  ground_truth: Partial<GroundTruthLabels>;
}

export function generateDailyTransactions(
  config: PersonaConfig,
  calendar: CalendarMonth[],
  rng: SeededRandom,
): GeneratedTransaction[] {
  const allTransactions: GeneratedTransaction[] = [];
  let balance = config.accounts.deposit?.opening_balance ?? 45000;
  let txnCounter = 0;
  let creditCardAccumulator = 0;
  let monthlyAtmCount = 0;

  for (const calMonth of calendar) {
    monthlyAtmCount = 0;
    const monthTxns: TransactionBuilder[] = [];

    // === RECURRING: Salary ===
    const salaryDay = findDay(calMonth, calMonth.salary_day);
    if (salaryDay) {
      monthTxns.push(buildSalary(config, salaryDay, rng));
    }

    // === RECURRING: Rent ===
    if (config.obligations.rent) {
      const rentDay = findDay(calMonth, config.obligations.rent.day);
      if (rentDay) {
        monthTxns.push(buildRent(config, rentDay, rng));
      }
    }

    // === RECURRING: SIPs ===
    for (const sip of config.obligations.sip ?? []) {
      const sipDay = findDay(calMonth, sip.day);
      if (sipDay) {
        monthTxns.push(buildSIP(sip, sipDay, rng));
      }
    }

    // === RECURRING: Utilities ===
    if (config.obligations.electricity) {
      const day = findDay(calMonth, config.obligations.electricity.day);
      if (day) {
        monthTxns.push(buildElectricity(config, day, rng));
      }
    }
    if (config.obligations.broadband) {
      const day = findDay(calMonth, config.obligations.broadband.day);
      if (day) {
        monthTxns.push(buildBroadband(config, day, rng));
      }
    }
    if (config.obligations.mobile) {
      const day = findDay(calMonth, config.obligations.mobile.day);
      if (day) {
        monthTxns.push(buildMobile(config, day, rng));
      }
    }

    // === RECURRING: Subscriptions ===
    for (const sub of config.obligations.subscriptions ?? []) {
      const day = findDay(calMonth, sub.day);
      if (day) {
        monthTxns.push(buildSubscription(sub, day, rng));
      }
    }

    // === RECURRING: Goal allocations ===
    for (const goal of config.goals) {
      const day = findDay(calMonth, goal.allocation_day);
      if (day) {
        monthTxns.push(buildGoalAllocation(goal, day, rng));
      }
    }

    // === RECURRING: Credit card payment ===
    if (config.obligations.credit_card_due_day && creditCardAccumulator > 0) {
      const ccDay = findDay(calMonth, config.obligations.credit_card_due_day);
      if (ccDay) {
        monthTxns.push(buildCreditCardPayment(creditCardAccumulator, ccDay, rng));
        creditCardAccumulator = 0;
      }
    }

    // === DAILY: Behavioral spending ===
    for (const day of calMonth.days) {
      const dailyTxns = generateDaySpending(config, day, rng, monthlyAtmCount);
      for (const txn of dailyTxns) {
        if (txn.mode === "ATM") monthlyAtmCount++;
      }
      monthTxns.push(...dailyTxns);
    }

    // === MONTHLY: Freelance income (probabilistic) ===
    if (config.income.freelance && rng.shouldOccur(config.income.freelance.monthly_probability)) {
      const freelanceDay = calMonth.days[rng.int(10, Math.min(25, calMonth.days.length - 1))];
      if (freelanceDay) {
        monthTxns.push(buildFreelanceIncome(config, freelanceDay, rng));
      }
    }

    // Sort by date + time, assign IDs and balances
    monthTxns.sort((a, b) => {
      const tsA = formatTimestamp(a.date, a.hour, a.minute);
      const tsB = formatTimestamp(b.date, b.hour, b.minute);
      return tsA.localeCompare(tsB);
    });

    for (const txn of monthTxns) {
      txnCounter++;
      const txnId = `TXN_${config.persona.id.toUpperCase()}_${txn.date.replace(/-/g, "")}_${String(txnCounter).padStart(3, "0")}`;

      if (txn.direction === "CREDIT") {
        balance += txn.amount;
      } else {
        balance -= txn.amount;
        if (txn.mode === "CARD") {
          creditCardAccumulator += txn.amount;
        }
      }

      balance = Math.round(balance * 100) / 100;

      const dayInfo = calMonth.days.find((d) => d.date === txn.date)!;
      const derivedDayOfWeek = dayOfWeekName(txn.date);
      const derivedTimeOfDay = timeOfDayFromHour(txn.hour);
      const derivedSalaryCyclePhase = salaryCyclePhaseFromLastSalary(txn.date, config.income.salary.day);

      const fullGT: GroundTruthLabels = {
        category: txn.ground_truth.category ?? "unknown",
        sub_category: txn.ground_truth.sub_category ?? "",
        merchant: txn.ground_truth.merchant ?? "",
        is_income: txn.ground_truth.is_income ?? false,
        is_salary: txn.ground_truth.is_salary ?? false,
        is_variable_income: txn.ground_truth.is_variable_income ?? false,
        is_internal_transfer: txn.ground_truth.is_internal_transfer ?? false,
        is_refund: txn.ground_truth.is_refund ?? false,
        is_obligation: txn.ground_truth.is_obligation ?? false,
        is_rent: txn.ground_truth.is_rent ?? false,
        is_emi: txn.ground_truth.is_emi ?? false,
        is_sip: txn.ground_truth.is_sip ?? false,
        is_rd: txn.ground_truth.is_rd ?? false,
        is_insurance: txn.ground_truth.is_insurance ?? false,
        is_subscription: txn.ground_truth.is_subscription ?? false,
        is_utility: txn.ground_truth.is_utility ?? false,
        is_family_support: txn.ground_truth.is_family_support ?? false,
        is_tax: txn.ground_truth.is_tax ?? false,
        is_discretionary: txn.ground_truth.is_discretionary ?? false,
        is_recurring: txn.ground_truth.is_recurring ?? false,
        is_reimbursable: txn.ground_truth.is_reimbursable ?? false,
        is_unplanned: txn.ground_truth.is_unplanned ?? false,
        is_healthcare: txn.ground_truth.is_healthcare ?? false,
        is_luxury: txn.ground_truth.is_luxury ?? false,
        is_travel: txn.ground_truth.is_travel ?? false,
        is_gift: txn.ground_truth.is_gift ?? false,
        is_cash_blindspot: txn.ground_truth.is_cash_blindspot ?? false,
        is_credit_card_payment: txn.ground_truth.is_credit_card_payment ?? false,
        is_goal_allocation: txn.ground_truth.is_goal_allocation ?? false,
        linked_goal_id: txn.ground_truth.linked_goal_id ?? null,
        affects_goal: txn.ground_truth.affects_goal ?? (txn.direction === "DEBIT" && txn.ground_truth.is_discretionary === true),
        nudge_candidate: txn.ground_truth.nudge_candidate ?? false,
        expected_nudge_type: txn.ground_truth.expected_nudge_type ?? null,
        expected_user_confirmation: txn.ground_truth.expected_user_confirmation ?? null,
        expected_safe_to_spend_impact: txn.direction === "DEBIT" ? -txn.amount : null,
        expected_goal_drift_days: txn.ground_truth.expected_goal_drift_days ?? null,
        life_event: dayInfo.active_life_events.length > 0 ? dayInfo.active_life_events[0].type : null,
        behavioral_state: dayInfo.behavioral_state,
        day_of_week: derivedDayOfWeek,
        time_of_day: derivedTimeOfDay,
        salary_cycle_phase: derivedSalaryCyclePhase,
        confidence_expected: txn.ground_truth.confidence_expected ?? "high",
        reimbursement_linked_txn_ids: txn.ground_truth.reimbursement_linked_txn_ids ?? null,
        is_reimbursement_credit: txn.ground_truth.is_reimbursement_credit ?? false,
      };

      allTransactions.push({
        txn_id: txnId,
        date: txn.date,
        timestamp: formatTimestamp(txn.date, txn.hour, txn.minute),
        direction: txn.direction,
        mode: txn.mode,
        amount: Math.round(txn.amount * 100) / 100,
        narration: txn.narration,
        reference: rng.referenceNumber(),
        balance_after: balance,
        ground_truth: fullGT,
      });
    }
  }

  return allTransactions;
}

// ============================================================================
// Recurring Event Builders
// ============================================================================

function buildSalary(config: PersonaConfig, day: CalendarDay, rng: SeededRandom): TransactionBuilder {
  const { hour, minute } = rng.timeInRange(9, 11);
  return {
    date: day.date,
    hour, minute,
    direction: "CREDIT",
    mode: config.income.salary.mode,
    amount: config.income.salary.amount,
    narration: `NEFT/CR/EMPLOYER/${config.income.salary.employer}/SALARY/${formatMonthLabel(day.date)}`,
    ground_truth: {
      category: "salary",
      sub_category: "monthly_salary",
      merchant: config.income.salary.employer,
      is_income: true,
      is_salary: true,
      is_recurring: true,
      confidence_expected: "high",
    },
  };
}

function buildRent(config: PersonaConfig, day: CalendarDay, rng: SeededRandom): TransactionBuilder {
  const rent = config.obligations.rent!;
  const { hour, minute } = rng.timeInRange(9, 12);
  return {
    date: day.date,
    hour, minute,
    direction: "DEBIT",
    mode: rent.mode,
    amount: rent.amount,
    narration: `UPI/DR/${config.persona.mobile}@ybl/${rent.payee}/RENT/${formatMonthLabel(day.date)}`,
    ground_truth: {
      category: "rent",
      sub_category: "monthly_rent",
      merchant: rent.payee,
      is_obligation: true,
      is_rent: true,
      is_recurring: true,
      confidence_expected: "high",
    },
  };
}

function buildSIP(sip: { amount: number; day: number; fund: string }, day: CalendarDay, rng: SeededRandom): TransactionBuilder {
  const { hour, minute } = rng.timeInRange(9, 10);
  return {
    date: day.date,
    hour, minute,
    direction: "DEBIT",
    mode: "FT",
    amount: sip.amount,
    narration: `SI/DR/HDFC MF/SIP/FOLIO ${rng.int(10000, 99999)}/${sip.fund.toUpperCase()}`,
    ground_truth: {
      category: "sip",
      sub_category: "mutual_fund_sip",
      merchant: sip.fund,
      is_obligation: true,
      is_sip: true,
      is_recurring: true,
      confidence_expected: "high",
    },
  };
}

function buildElectricity(config: PersonaConfig, day: CalendarDay, rng: SeededRandom): TransactionBuilder {
  const elec = config.obligations.electricity!;
  const amount = rng.amount(elec.amount_min, elec.amount_max);
  const { hour, minute } = rng.timeInRange(10, 18);
  return {
    date: day.date,
    hour, minute,
    direction: "DEBIT",
    mode: "UPI",
    amount,
    narration: `UPI/DR/BESCOM/ELECTRICITY BILL/${formatMonthLabel(day.date)}`,
    ground_truth: {
      category: "utility",
      sub_category: "electricity",
      merchant: "BESCOM",
      is_obligation: true,
      is_utility: true,
      is_recurring: true,
      confidence_expected: "high",
    },
  };
}

function buildBroadband(config: PersonaConfig, day: CalendarDay, rng: SeededRandom): TransactionBuilder {
  const bb = config.obligations.broadband!;
  const { hour, minute } = rng.timeInRange(10, 14);
  return {
    date: day.date,
    hour, minute,
    direction: "DEBIT",
    mode: "FT",
    amount: bb.amount,
    narration: `SI/DR/${bb.provider.toUpperCase()}/BROADBAND/MONTHLY`,
    ground_truth: {
      category: "utility",
      sub_category: "broadband",
      merchant: bb.provider,
      is_obligation: true,
      is_utility: true,
      is_recurring: true,
      confidence_expected: "high",
    },
  };
}

function buildMobile(config: PersonaConfig, day: CalendarDay, rng: SeededRandom): TransactionBuilder {
  const mob = config.obligations.mobile!;
  const { hour, minute } = rng.timeInRange(10, 18);
  return {
    date: day.date,
    hour, minute,
    direction: "DEBIT",
    mode: "UPI",
    amount: mob.amount,
    narration: `UPI/DR/${mob.provider.toUpperCase()}/MOBILE RECHARGE`,
    ground_truth: {
      category: "utility",
      sub_category: "mobile",
      merchant: mob.provider,
      is_obligation: true,
      is_utility: true,
      is_recurring: true,
      confidence_expected: "high",
    },
  };
}

function buildSubscription(sub: { name: string; amount: number; day: number }, day: CalendarDay, rng: SeededRandom): TransactionBuilder {
  const { hour, minute } = rng.timeInRange(0, 6);
  return {
    date: day.date,
    hour, minute,
    direction: "DEBIT",
    mode: "CARD",
    amount: sub.amount,
    narration: `CARD/DR/RECURRING/${sub.name.toUpperCase()}/SUBSCRIPTION`,
    ground_truth: {
      category: "subscription",
      sub_category: sub.name.toLowerCase().replace(/\s+/g, "_"),
      merchant: sub.name,
      is_obligation: true,
      is_subscription: true,
      is_recurring: true,
      confidence_expected: "high",
    },
  };
}

function buildGoalAllocation(goal: { id: string; name: string; monthly_allocation: number; allocation_day: number }, day: CalendarDay, rng: SeededRandom): TransactionBuilder {
  const { hour, minute } = rng.timeInRange(19, 22);
  return {
    date: day.date,
    hour, minute,
    direction: "DEBIT",
    mode: "FT",
    amount: goal.monthly_allocation,
    narration: `FT/DR/INTERNAL/GOAL SAVINGS/${goal.name.toUpperCase()}`,
    ground_truth: {
      category: "goal_allocation",
      sub_category: goal.id,
      merchant: "Self",
      is_internal_transfer: true,
      is_goal_allocation: true,
      is_recurring: true,
      linked_goal_id: goal.id,
      affects_goal: true,
      confidence_expected: "high",
    },
  };
}

function buildCreditCardPayment(accumulated: number, day: CalendarDay, rng: SeededRandom): TransactionBuilder {
  const { hour, minute } = rng.timeInRange(18, 22);
  return {
    date: day.date,
    hour, minute,
    direction: "DEBIT",
    mode: "FT",
    amount: Math.round(accumulated * 100) / 100,
    narration: `FT/DR/HDFC CREDIT CARD/BILL PAYMENT/XXXX5678`,
    ground_truth: {
      category: "credit_card_payment",
      sub_category: "full_payment",
      merchant: "HDFC Credit Card",
      is_credit_card_payment: true,
      is_recurring: true,
      confidence_expected: "high",
    },
  };
}

function buildFreelanceIncome(config: PersonaConfig, day: CalendarDay, rng: SeededRandom): TransactionBuilder {
  const fl = config.income.freelance!;
  const amount = rng.amount(fl.min, fl.max);
  const { hour, minute } = rng.timeInRange(10, 18);
  return {
    date: day.date,
    hour, minute,
    direction: "CREDIT",
    mode: "UPI",
    amount,
    narration: `UPI/CR/client@upi/FREELANCE PAYMENT/${formatMonthLabel(day.date)}`,
    ground_truth: {
      category: "freelance_income",
      sub_category: "consulting",
      merchant: "Freelance Client",
      is_income: true,
      is_variable_income: true,
      confidence_expected: "medium",
    },
  };
}

// ============================================================================
// Daily Spending Generator — behavioral, not random
// ============================================================================

function generateDaySpending(
  config: PersonaConfig,
  day: CalendarDay,
  rng: SeededRandom,
  monthlyAtmCount: number,
): TransactionBuilder[] {
  const txns: TransactionBuilder[] = [];
  const bd = config.behavioral_defaults;
  const state = day.behavioral_state;

  const spendMultiplier = getStateMultiplier(state);
  const foodProb = adjustProbability(bd.weekday_food_delivery_prob, state, "food");
  const cabProb = adjustProbability(bd.weekday_cab_prob, state, "cab");

  if (day.is_weekend) {
    // --- WEEKEND BEHAVIOR ---

    // Grocery (high probability on weekends)
    if (rng.shouldOccur(bd.grocery_weekend_prob)) {
      const isBigShop = day.day_of_week === "saturday";
      const amount = isBigShop ? rng.amount(1200, 3500) : rng.amount(400, 1200);
      const { hour, minute } = rng.timeInRange(isBigShop ? 10 : 17, isBigShop ? 13 : 20);
      const merchant = rng.choice(["BigBasket", "Zepto", "Blinkit", "DMart", "More Supermarket"]);
      txns.push({
        date: day.date, hour, minute,
        direction: "DEBIT", mode: "UPI",
        amount: amount * spendMultiplier,
        narration: `UPI/DR/${config.persona.mobile}@ybl/${merchant.toUpperCase()}/GROCERY`,
        ground_truth: {
          category: "groceries", sub_category: isBigShop ? "weekly_grocery" : "grocery_topup",
          merchant, is_discretionary: false, is_recurring: true,
          confidence_expected: "high",
        },
      });
    }

    // Dining out (weekend)
    if (rng.shouldOccur(bd.weekend_dining_out_prob * spendMultiplier)) {
      const amount = rng.amount(600, 2500);
      const { hour, minute } = rng.timeInRange(19, 22);
      const merchant = rng.choice(["Truffles", "Toit", "Vidyarthi Bhavan", "MTR", "Meghana Foods", "Empire Restaurant"]);
      txns.push({
        date: day.date, hour, minute,
        direction: "DEBIT", mode: "CARD",
        amount: amount * spendMultiplier,
        narration: `CARD/DR/POS/${merchant.toUpperCase()} BLR/DINING`,
        ground_truth: {
          category: "eating_out", sub_category: "weekend_dining",
          merchant, is_discretionary: true,
          nudge_candidate: amount > 1500, expected_nudge_type: amount > 1500 ? "weekend_spike" : null,
          confidence_expected: "high",
        },
      });
    }

    // Shopping impulse (Saturday)
    if (day.day_of_week === "saturday" && rng.shouldOccur(bd.impulse_shopping_weekend_prob * spendMultiplier)) {
      const amount = rng.amount(800, 5000);
      const { hour, minute } = rng.timeInRange(14, 19);
      const merchant = rng.choice(["Zara", "H&M", "Myntra", "Amazon", "Flipkart", "Uniqlo"]);
      const isOnline = ["Myntra", "Amazon", "Flipkart"].includes(merchant);
      txns.push({
        date: day.date, hour, minute,
        direction: "DEBIT", mode: "CARD",
        amount: amount * spendMultiplier,
        narration: isOnline
          ? `CARD/DR/ECOM/${merchant.toUpperCase()}/ORDER`
          : `CARD/DR/POS/${merchant.toUpperCase()} PHOENIX MALL BLR`,
        ground_truth: {
          category: "fashion", sub_category: "impulse_shopping",
          merchant, is_discretionary: true, is_luxury: amount > 3000,
          nudge_candidate: true, expected_nudge_type: "spend_velocity_high",
          affects_goal: true, confidence_expected: "high",
        },
      });
    }

    // Café
    if (rng.shouldOccur(0.5)) {
      const amount = rng.amount(200, 500);
      const { hour, minute } = rng.timeInRange(15, 18);
      const merchant = rng.choice(["Starbucks", "Third Wave Coffee", "Blue Tokai", "Cafe Coffee Day"]);
      txns.push({
        date: day.date, hour, minute,
        direction: "DEBIT", mode: "UPI",
        amount,
        narration: `UPI/DR/${config.persona.mobile}@ybl/${merchant.toUpperCase()}/COFFEE`,
        ground_truth: {
          category: "coffee", sub_category: "weekend_coffee",
          merchant, is_discretionary: true,
          confidence_expected: "high",
        },
      });
    }

    // Entertainment (Saturday evening)
    if (day.day_of_week === "saturday" && rng.shouldOccur(0.25)) {
      const amount = rng.amount(300, 1200);
      const { hour, minute } = rng.timeInRange(18, 21);
      const merchant = rng.choice(["PVR Cinemas", "BookMyShow", "Smaaash", "Timezone"]);
      txns.push({
        date: day.date, hour, minute,
        direction: "DEBIT", mode: rng.choice(["CARD", "UPI"]) as TransactionMode,
        amount,
        narration: `CARD/DR/POS/${merchant.toUpperCase()} BLR/ENTERTAINMENT`,
        ground_truth: {
          category: "entertainment", sub_category: "weekend_entertainment",
          merchant, is_discretionary: true,
          confidence_expected: "high",
        },
      });
    }

    // Cab on weekend
    if (rng.shouldOccur(0.4)) {
      const amount = rng.amount(150, 400);
      const { hour, minute } = rng.timeInRange(12, 22);
      const merchant = rng.choice(["Uber", "Ola", "Rapido"]);
      txns.push({
        date: day.date, hour, minute,
        direction: "DEBIT", mode: "UPI",
        amount,
        narration: `UPI/DR/${config.persona.mobile}@ybl/${merchant.toUpperCase()}/TRIP`,
        ground_truth: {
          category: "commute", sub_category: "weekend_cab",
          merchant, is_discretionary: true,
          confidence_expected: "high",
        },
      });
    }

    // Food delivery on Sunday
    if (day.day_of_week === "sunday" && rng.shouldOccur(0.7)) {
      const amount = rng.amount(300, 600);
      const { hour, minute } = rng.timeInRange(12, 14);
      const merchant = rng.choice(["Swiggy", "Zomato"]);
      txns.push({
        date: day.date, hour, minute,
        direction: "DEBIT", mode: "UPI",
        amount,
        narration: `UPI/DR/${config.persona.mobile}@ybl/${merchant.toUpperCase()}/FOOD ORDER`,
        ground_truth: {
          category: "food_delivery", sub_category: "lunch",
          merchant, is_discretionary: true,
          confidence_expected: "high",
        },
      });
    }

    // Laundry (Sunday)
    if (day.day_of_week === "sunday" && rng.shouldOccur(0.4)) {
      const amount = rng.amount(200, 450);
      const { hour, minute } = rng.timeInRange(10, 13);
      txns.push({
        date: day.date, hour, minute,
        direction: "DEBIT", mode: "UPI",
        amount,
        narration: `UPI/DR/${config.persona.mobile}@ybl/UCLEAN/LAUNDRY`,
        ground_truth: {
          category: "household", sub_category: "laundry",
          merchant: "UClean", is_discretionary: false,
          confidence_expected: "high",
        },
      });
    }
  } else {
    // --- WEEKDAY BEHAVIOR ---

    // Morning coffee
    if (rng.shouldOccur(bd.coffee_daily_prob)) {
      const amount = rng.amount(120, 280);
      const { hour, minute } = rng.timeInRange(10, 12);
      const merchant = rng.choice(["Starbucks", "Third Wave Coffee", "Blue Tokai", "Cafe Coffee Day"]);
      txns.push({
        date: day.date, hour, minute,
        direction: "DEBIT", mode: "UPI",
        amount,
        narration: `UPI/DR/${config.persona.mobile}@ybl/${merchant.toUpperCase()}/COFFEE`,
        ground_truth: {
          category: "coffee", sub_category: "morning_coffee",
          merchant, is_discretionary: true,
          nudge_candidate: false, confidence_expected: "high",
        },
      });
    }

    // Lunch
    if (rng.shouldOccur(foodProb)) {
      const amount = rng.amount(200, 450);
      const { hour, minute } = rng.timeInRange(12, 14);
      const isDelivery = rng.shouldOccur(0.6);
      const merchant = isDelivery ? rng.choice(["Swiggy", "Zomato"]) : "Office Canteen";
      txns.push({
        date: day.date, hour, minute,
        direction: "DEBIT", mode: "UPI",
        amount,
        narration: isDelivery
          ? `UPI/DR/${config.persona.mobile}@ybl/${merchant.toUpperCase()}/LUNCH ORDER`
          : `UPI/DR/${config.persona.mobile}@ybl/OFFICE CANTEEN/LUNCH`,
        ground_truth: {
          category: "food_delivery", sub_category: "lunch",
          merchant, is_discretionary: true,
          confidence_expected: "high",
        },
      });
    }

    // Commute (cab or metro)
    const takesCab = rng.shouldOccur(cabProb);
    if (takesCab) {
      // Morning cab
      const amount = rng.amount(150, 350);
      const { hour, minute } = rng.timeInRange(8, 10);
      const merchant = rng.choice(["Uber", "Ola", "Rapido"]);
      txns.push({
        date: day.date, hour, minute,
        direction: "DEBIT", mode: "UPI",
        amount,
        narration: `UPI/DR/${config.persona.mobile}@ybl/${merchant.toUpperCase()}/TRIP`,
        ground_truth: {
          category: "commute", sub_category: "cab_to_work",
          merchant, is_discretionary: true,
          nudge_candidate: true, expected_nudge_type: "cab_leakage",
          confidence_expected: "high",
        },
      });

      // Evening cab (80% chance if took morning cab)
      if (rng.shouldOccur(0.8)) {
        const evAmount = rng.amount(180, 400);
        const { hour: eh, minute: em } = rng.timeInRange(18, 21);
        txns.push({
          date: day.date, hour: eh, minute: em,
          direction: "DEBIT", mode: "UPI",
          amount: evAmount,
          narration: `UPI/DR/${config.persona.mobile}@ybl/${merchant.toUpperCase()}/TRIP`,
          ground_truth: {
            category: "commute", sub_category: "cab_from_work",
            merchant, is_discretionary: true,
            nudge_candidate: true, expected_nudge_type: "cab_leakage",
            confidence_expected: "high",
          },
        });
      }
    } else if (rng.shouldOccur(0.7)) {
      // Metro
      const amount = rng.amount(30, 80);
      const { hour, minute } = rng.timeInRange(8, 9);
      txns.push({
        date: day.date, hour, minute,
        direction: "DEBIT", mode: "CARD",
        amount,
        narration: `CARD/DR/POS/BMRCL METRO/FARE`,
        ground_truth: {
          category: "commute", sub_category: "metro",
          merchant: "BMRCL Metro", is_discretionary: false,
          confidence_expected: "high",
        },
      });
    }

    // Dinner delivery (weekday evening)
    if (rng.shouldOccur(foodProb * 0.7)) {
      const amount = rng.amount(280, 650);
      const { hour, minute } = rng.timeInRange(19, 22);
      const merchant = rng.choice(["Swiggy", "Zomato"]);
      txns.push({
        date: day.date, hour, minute,
        direction: "DEBIT", mode: "UPI",
        amount,
        narration: `UPI/DR/${config.persona.mobile}@ybl/${merchant.toUpperCase()}/DINNER ORDER`,
        ground_truth: {
          category: "food_delivery", sub_category: "dinner",
          merchant, is_discretionary: true,
          nudge_candidate: true, expected_nudge_type: "food_leakage",
          confidence_expected: "high",
        },
      });
    }

    // Late-night food (stress/work-crunch indicator)
    const lateNightProb = (state === "stressed" || state === "work_crunch")
      ? bd.late_night_food_prob * 3
      : bd.late_night_food_prob;
    if (rng.shouldOccur(lateNightProb)) {
      const amount = rng.amount(250, 550);
      const { hour, minute } = rng.timeInRange(22, 24);
      const merchant = rng.choice(["Swiggy", "Zomato"]);
      txns.push({
        date: day.date, hour: hour === 24 ? 0 : hour, minute,
        direction: "DEBIT", mode: "UPI",
        amount,
        narration: `UPI/DR/${config.persona.mobile}@ybl/${merchant.toUpperCase()}/LATE NIGHT ORDER`,
        ground_truth: {
          category: "food_delivery", sub_category: "late_night_food",
          merchant, is_discretionary: true, is_unplanned: true,
          nudge_candidate: true, expected_nudge_type: "food_leakage",
          confidence_expected: "high",
        },
      });
    }

    // Friday social (Aarav special)
    if (day.day_of_week === "friday" && rng.shouldOccur(bd.friday_social_prob * spendMultiplier)) {
      // Dinner with friends
      const dinnerAmount = rng.amount(800, 2200);
      const { hour, minute } = rng.timeInRange(20, 22);
      const merchant = rng.choice(["Toit", "Arbor Brewing", "Biere Club", "Windmills Craftworks", "Byg Brewski"]);
      txns.push({
        date: day.date, hour, minute,
        direction: "DEBIT", mode: "CARD",
        amount: dinnerAmount * spendMultiplier,
        narration: `CARD/DR/POS/${merchant.toUpperCase()} BLR/DINING`,
        ground_truth: {
          category: "eating_out", sub_category: "friday_social",
          merchant, is_discretionary: true,
          nudge_candidate: dinnerAmount > 1500, expected_nudge_type: dinnerAmount > 1500 ? "weekend_spike" : null,
          confidence_expected: "high",
        },
      });

      // Cab home late
      const cabAmount = rng.amount(250, 450);
      const { hour: ch, minute: cm } = rng.timeInRange(23, 24);
      txns.push({
        date: day.date, hour: ch === 24 ? 0 : ch, minute: cm,
        direction: "DEBIT", mode: "UPI",
        amount: cabAmount,
        narration: `UPI/DR/${config.persona.mobile}@ybl/UBER/TRIP`,
        ground_truth: {
          category: "commute", sub_category: "late_night_cab",
          merchant: "Uber", is_discretionary: true,
          confidence_expected: "high",
        },
      });
    }

    // Afternoon coffee (some days)
    if (rng.shouldOccur(0.25)) {
      const amount = rng.amount(100, 250);
      const { hour, minute } = rng.timeInRange(15, 17);
      const merchant = rng.choice(["Starbucks", "Third Wave Coffee", "Blue Tokai"]);
      txns.push({
        date: day.date, hour, minute,
        direction: "DEBIT", mode: "UPI",
        amount,
        narration: `UPI/DR/${config.persona.mobile}@ybl/${merchant.toUpperCase()}/COFFEE`,
        ground_truth: {
          category: "coffee", sub_category: "afternoon_coffee",
          merchant, is_discretionary: true,
          confidence_expected: "high",
        },
      });
    }
  }

  // --- ANY DAY: ATM withdrawal (monthly limit) ---
  const maxAtm = bd.atm_withdrawal_monthly_max;
  if (monthlyAtmCount < maxAtm && rng.shouldOccur(0.05)) {
    const amount = rng.choice([2000, 3000, 5000, 5000, 10000]);
    const { hour, minute } = rng.timeInRange(10, 20);
    txns.push({
      date: day.date, hour, minute,
      direction: "DEBIT", mode: "ATM",
      amount,
      narration: `ATM/DR/SELF/HDFC ATM ${config.persona.city.toUpperCase()}/CASH WDL`,
      ground_truth: {
        category: "cash_withdrawal", sub_category: "atm",
        merchant: "HDFC ATM", is_cash_blindspot: true,
        nudge_candidate: true, expected_nudge_type: "cash_blindspot",
        expected_user_confirmation: `₹${amount} withdrawn in cash. Should this count as spent?`,
        confidence_expected: "low",
      },
    });
  }

  // --- ANY DAY: Small household / personal care (low probability) ---
  if (rng.shouldOccur(0.08)) {
    const amount = rng.amount(150, 800);
    const { hour, minute } = rng.timeInRange(11, 20);
    const merchant = rng.choice(["Amazon", "Flipkart", "Medplus", "Apollo Pharmacy"]);
    const isPharmacy = merchant.includes("Medplus") || merchant.includes("Apollo");
    txns.push({
      date: day.date, hour, minute,
      direction: "DEBIT", mode: "UPI",
      amount,
      narration: isPharmacy
        ? `UPI/DR/${config.persona.mobile}@ybl/${merchant.toUpperCase()}/PHARMACY`
        : `CARD/DR/ECOM/${merchant.toUpperCase()}/HOUSEHOLD`,
      ground_truth: {
        category: isPharmacy ? "pharmacy" : "household",
        sub_category: isPharmacy ? "medicine" : "household_items",
        merchant, is_discretionary: !isPharmacy,
        is_healthcare: isPharmacy,
        confidence_expected: "medium",
      },
    });
  }

  // --- Refund (rare) ---
  if (rng.shouldOccur(0.01)) {
    const amount = rng.amount(200, 2000);
    const { hour, minute } = rng.timeInRange(10, 18);
    txns.push({
      date: day.date, hour, minute,
      direction: "CREDIT", mode: "UPI",
      amount,
      narration: `UPI/CR/refund@paytm/REFUND/ORDER CANCELLED`,
      ground_truth: {
        category: "refund", sub_category: "order_cancellation",
        merchant: "Paytm", is_refund: true,
        confidence_expected: "high",
      },
    });
  }

  return txns;
}

// ============================================================================
// Helpers
// ============================================================================

function findDay(month: CalendarMonth, targetDay: number): CalendarDay | undefined {
  const maxDay = month.days.length;
  const clampedDay = Math.min(targetDay, maxDay);
  return month.days.find((d) => d.day_of_month === clampedDay);
}

function getStateMultiplier(state: BehavioralState): number {
  switch (state) {
    case "overconfident_after_salary": return 1.3;
    case "social": return 1.5;
    case "stressed": return 1.2;
    case "work_crunch": return 1.15;
    case "frugal": return 0.6;
    case "cautious_before_salary": return 0.7;
    case "travel_mode": return 1.8;
    case "family_event": return 1.4;
    case "appraisal_month": return 1.3;
    default: return 1.0;
  }
}

function adjustProbability(baseProbability: number, state: BehavioralState, type: "food" | "cab"): number {
  const multiplier = {
    stressed: type === "food" ? 1.4 : 1.3,
    work_crunch: type === "food" ? 1.5 : 1.4,
    social: 1.2,
    frugal: 0.5,
    cautious_before_salary: 0.6,
    overconfident_after_salary: 1.2,
    normal: 1.0,
    travel_mode: 0.8,
    health_event: 0.4,
    family_event: 1.0,
    appraisal_month: 1.1,
    job_switch_phase: 0.7,
  };
  return Math.min(1, baseProbability * (multiplier[state] ?? 1.0));
}

function salaryCyclePhaseFromLastSalary(dateStr: string, salaryDay: number): SalaryCyclePhase {
  const [year, month, day] = dateStr.split("-").map(Number);
  const currentSalaryDay = Math.min(salaryDay, daysInMonth(year, month));
  let salaryYear = year;
  let salaryMonth = month;

  if (day < currentSalaryDay) {
    salaryMonth -= 1;
    if (salaryMonth === 0) {
      salaryMonth = 12;
      salaryYear -= 1;
    }
  }

  const actualSalaryDay = Math.min(salaryDay, daysInMonth(salaryYear, salaryMonth));
  const txnDate = new Date(year, month - 1, day);
  const lastSalaryDate = new Date(salaryYear, salaryMonth - 1, actualSalaryDay);
  const daysAfterSalary = Math.floor((txnDate.getTime() - lastSalaryDate.getTime()) / 86_400_000);

  if (daysAfterSalary <= 7) return "week_1";
  if (daysAfterSalary <= 14) return "week_2";
  if (daysAfterSalary <= 21) return "week_3";
  return "week_4";
}

function formatMonthLabel(dateStr: string): string {
  const months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
  const [year, month] = dateStr.split("-").map(Number);
  return `${months[month - 1]}${String(year).slice(2)}`;
}
