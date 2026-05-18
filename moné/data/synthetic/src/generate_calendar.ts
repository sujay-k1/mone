// ============================================================================
// Calendar Generator — builds the day-by-day calendar for a persona
// ============================================================================

import type {
  PersonaConfig,
  CalendarMonth,
  CalendarDay,
  BehavioralState,
  ActiveLifeEvent,
  DayOfWeek,
  SalaryCyclePhase,
} from "./types.ts";
import { SeededRandom, daysInMonth, dayOfWeekName, isWeekend, monthsBetween } from "./random.ts";

export function generateCalendar(config: PersonaConfig, rng: SeededRandom): CalendarMonth[] {
  const months = monthsBetween(config.period.start, config.period.end);
  const calendar: CalendarMonth[] = [];

  for (let i = 0; i < months.length; i++) {
    const { year, month } = months[i];
    const numDays = daysInMonth(year, month);

    const lifeEvents = resolveLifeEvents(config, i);

    const calMonth: CalendarMonth = {
      year,
      month,
      salary_day: config.income.salary.day,
      rent_day: config.obligations.rent?.day ?? 0,
      sip_days: (config.obligations.sip ?? []).map((s) => s.day),
      credit_card_due_day: config.obligations.credit_card_due_day ?? 23,
      utility_due_days: [
        config.obligations.electricity?.day,
        config.obligations.broadband?.day,
        config.obligations.mobile?.day,
      ].filter((d): d is number => d !== undefined),
      subscription_days: [
        ...new Set((config.obligations.subscriptions ?? []).map((s) => s.day)),
      ],
      expected_weekend_spike: true,
      life_events: lifeEvents,
      days: [],
    };

    for (let d = 1; d <= numDays; d++) {
      const dateStr = `${year}-${String(month).padStart(2, "0")}-${String(d).padStart(2, "0")}`;
      const dow = dayOfWeekName(dateStr);
      const salaryDay = config.income.salary.day;
      const phase = getSalaryCyclePhase(d, salaryDay);
      const state = determineBehavioralState(d, dow, phase, salaryDay, lifeEvents, config, rng);

      const dayEvents = lifeEvents.filter((e) => {
        const eventStartDay = e.params._start_day_of_month as number | undefined;
        const eventEndDay = e.params._end_day_of_month as number | undefined;
        if (eventStartDay !== undefined && eventEndDay !== undefined) {
          return d >= eventStartDay && d <= eventEndDay;
        }
        return true;
      });

      calMonth.days.push({
        date: dateStr,
        day_of_week: dow,
        day_of_month: d,
        is_weekend: isWeekend(dow),
        is_salary_day: d === salaryDay || (d === numDays && salaryDay > numDays),
        is_month_start: d <= 5,
        is_month_end: d >= numDays - 4,
        salary_cycle_phase: phase,
        behavioral_state: state,
        active_life_events: dayEvents,
      });
    }

    calendar.push(calMonth);
  }

  return calendar;
}

function getSalaryCyclePhase(dayOfMonth: number, salaryDay: number): SalaryCyclePhase {
  const daysAfterSalary = dayOfMonth >= salaryDay
    ? dayOfMonth - salaryDay
    : dayOfMonth + (28 - salaryDay);

  if (daysAfterSalary <= 7) return "week_1";
  if (daysAfterSalary <= 14) return "week_2";
  if (daysAfterSalary <= 21) return "week_3";
  return "week_4";
}

function determineBehavioralState(
  dayOfMonth: number,
  dow: DayOfWeek,
  phase: SalaryCyclePhase,
  salaryDay: number,
  lifeEvents: ActiveLifeEvent[],
  _config: PersonaConfig,
  rng: SeededRandom,
): BehavioralState {
  for (const event of lifeEvents) {
    switch (event.type) {
      case "work_travel":
        return "travel_mode";
      case "health_issue":
      case "healthcare_shock":
        return "health_event";
      case "friend_wedding":
      case "festival_season":
        return "family_event";
      case "job_switch":
        return "job_switch_phase";
      case "appraisal_bonus":
        return "appraisal_month";
    }
  }

  if (phase === "week_1" && dayOfMonth <= salaryDay + 3) {
    return "overconfident_after_salary";
  }

  if (phase === "week_4" && dayOfMonth >= salaryDay - 5) {
    return rng.shouldOccur(0.6) ? "cautious_before_salary" : "normal";
  }

  if (dow === "friday" || dow === "saturday") {
    return rng.shouldOccur(0.4) ? "social" : "normal";
  }

  if (rng.shouldOccur(0.08)) return "stressed";
  if (rng.shouldOccur(0.1)) return "work_crunch";
  if (rng.shouldOccur(0.05)) return "frugal";

  return "normal";
}

function resolveLifeEvents(config: PersonaConfig, monthIndex: number): ActiveLifeEvent[] {
  const events: ActiveLifeEvent[] = [];

  for (const le of config.life_events) {
    if (le.start_month === monthIndex + 1) {
      events.push({
        type: le.type,
        day_in_event: 1,
        total_days: le.duration_days,
        params: { ...le.params },
      });
    }
  }

  return events;
}
