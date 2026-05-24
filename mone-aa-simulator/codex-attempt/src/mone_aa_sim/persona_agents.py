import json
import os
import re
from typing import Iterable

from mone_aa_sim.ollama_client import call_ollama_json
from mone_aa_sim.schemas import PersonaBible, CriticResult


MODEL = os.getenv("MONE_MODEL", "qwen3:14b")

PERSONA_SCHEMA = PersonaBible.model_json_schema()
CRITIC_SCHEMA = CriticResult.model_json_schema()


PERSONA_ANCHORS = {
    "aarav": """
Aarav hard anchors:
- Bengaluru urban professional.
- Net monthly salary: ₹165,000.
- Rent should be around ₹42,000.
- Monthly fixed obligations should usually be ₹70,000–₹95,000 including rent, utilities, basic staff, minimum investments/subscriptions, but excluding chaotic discretionary overspend.
- Normal discretionary spend should usually be ₹45,000–₹85,000.
- Bad/stress months can exceed income using credit card, pay-later, friend borrowing, or asset liquidation, but this must not be every month.
- Credit card limit should be plausible: ₹220,000–₹350,000.
- Typical card outstanding should be plausible: ₹35,000–₹140,000 depending on the month.
- He can be irresponsible, but not financially impossible.
- He may delay card payments, pay minimum due, borrow from friends, front group spends, and repay late/partially.
- He should still have boring months with salary, rent, bills, commute, food, cigarettes, subscriptions, and normal social spending.
""",
    "priya": """
Priya hard anchors:
- Bengaluru high-income responsible professional with family obligations.
- Net monthly salary: around ₹265,000.
- Rent should be around ₹68,000.
- Monthly fixed obligations should usually be ₹155,000–₹205,000 including rent, education loan EMI, family support, investments, staff, utilities, and insurance planning.
- Normal discretionary spend should usually be ₹25,000–₹70,000.
- Stress month can happen due to family medical expense or household event, but not the whole year.
- Credit card limit should be plausible: ₹350,000–₹600,000.
- Typical card outstanding should be controlled: ₹15,000–₹80,000.
- She is responsible but not mechanically perfect.
- She uses savings/secondary account before debt.
- She pays EMIs/rent/family support on time.
- She may have pressure but should not behave like Aarav.
"""
}


CREATOR_SYSTEM = """
You create deep synthetic financial personas for Moné.

You are not creating transactions.
You are creating a persona bible that will later drive one year of raw AA-style financial data.

Hard rules:
- The persona must be financially generative.
- The persona must feel like a real Bangalore-based person.
- Do not make the person cartoonish.
- Do not make the person too perfect.
- Do not use placeholders such as "-", "x times", blank counts, unspecified km, unspecified days/week, or unnamed generic people.
- Every life rhythm must be concretely decided, including commute, office cadence, smoking/drinking rhythm, social frequency, and stress leakage.
- The persona must include named recurring counterparties: landlord, 3-5 friends, family members, househelp or service vendors, and at least one office reimbursement source.
- The monthly budget must make arithmetic sense.
- The budget_profile math must reconcile exactly with the top-level budget fields.
- The ordinary month should usually still be survivable from salary alone.
- Do not create permanent monthly deficits unless the persona has a clear survival mechanism.
- Full account visibility will be assumed later.
- Final output later will be raw AA only, but this persona can contain planning details.
- Do not output markdown.
- Return only JSON matching the schema.
"""


CRITIC_SYSTEM = """
You are an independent adversarial evaluator.

Your job is to decide whether this persona should be accepted, regenerated, sent back, or rejected.

You are not here to be agreeable.
You are not here to preserve prior work.
You are not here to make cosmetic fixes.

Decision rules:
- PASS only if the persona is coherent enough to generate one year of realistic raw AA data.
- REGENERATE_THIS_STAGE if the generated persona is weak, contradictory, under-specified, over-dramatic, financially impossible, or too generic.
- SEND_BACK_TO_PREVIOUS_STAGE only if the prior input constraints need to change.
- REJECT_ASSUMPTION only if the user's fixed assumptions themselves are impossible. Do not use REJECT_ASSUMPTION merely because this generated persona is bad.

When you flag income/expense mismatch, you must cite the exact numbers:
salary, rent, fixed obligations, discretionary range, card limit, and card outstanding.
Remember:
- monthly_fixed_obligations_inr already includes rent. Do not add rent again on top of fixed obligations.
- recurring_obligations is an itemized breakdown of fixed obligations, so it may include rent as one component of the fixed total.
- A stress month is allowed to exceed salary if the declared survival mechanisms visibly finance the gap.
- typical_credit_card_outstanding_high_inr is a typical upper range, not an absolute one-off stress cap.

Evaluate:
- persona realism
- Bangalore/city realism
- budget arithmetic
- financial behavior realism
- placeholder leakage or blank rhythms
- named counterparties and social graph quality
- whether commute, work mode, and vice/social habits are concretely specified
- whether the persona can generate boring months and one stress month
- whether the persona is too flat, too dramatic, too stereotyped, or too convenient
- whether credit behavior is plausible for the income and account universe
- whether the declared budget math and survival mechanisms actually reconcile
- whether stress behavior is messy-but-survivable instead of overly sanitized

Do not use:
- looks good overall
- minor issue
- minimal changes
- plausible enough
- can be fixed later

Return only JSON matching the schema.
"""


def _dedupe_preserve_order(items: Iterable[str]) -> list[str]:
    seen: set[str] = set()
    ordered: list[str] = []
    for item in items:
        normalized = item.strip()
        if normalized and normalized not in seen:
            seen.add(normalized)
            ordered.append(normalized)
    return ordered


def _extract_inr_amounts(text: str) -> list[int]:
    amounts: list[int] = []
    for prefix, suffix in re.findall(
        r"(?:₹\s*|rs\.?\s*|inr\s*)([\d,]+)|([\d,]+)\s*(?:₹|rs\.?|inr)",
        text,
        flags=re.IGNORECASE,
    ):
        value = prefix or suffix
        if value:
            amounts.append(int(value.replace(",", "")))
    return amounts


def _extract_monthly_obligation_total(items: Iterable[str]) -> int:
    total = 0
    for item in items:
        total += sum(_extract_inr_amounts(item))
    return total


def _extract_monthly_family_support_total(items: Iterable[str]) -> int:
    total = 0
    monthly_markers = ("monthly", "/month", "per month", "sends", "support")
    for item in items:
        lowered = item.lower()
        if any(marker in lowered for marker in monthly_markers):
            total += sum(_extract_inr_amounts(item))
    return total


def _strip_amounts(text: str) -> str:
    text = re.sub(r"₹\s*[\d,]+", "", text, flags=re.IGNORECASE)
    text = re.sub(r"[\d,]+\s*(?:₹|rs\.?|inr)", "", text, flags=re.IGNORECASE)
    text = re.sub(r"\(\s*\)", "", text)
    text = re.sub(r"\s{2,}", " ", text)
    return text.strip(" ,.-")


def _strip_numeric_claims(text: str) -> str:
    text = _strip_amounts(text)
    text = re.sub(r"\b\d+(?:\.\d+)?%?\b", "", text)
    text = re.sub(r"\([^)]*\)", "", text)
    text = re.sub(r"\s{2,}", " ", text)
    return text.strip(" ,.-")


def _contains_placeholder(text: str) -> bool:
    lowered = text.lower()
    placeholder_markers = [
        " - ",
        "- times",
        "- months",
        "- friends",
        "- km",
        "days/week",
        "times/week",
        "times/month",
        "x/week",
        "x/month",
        "unnamed",
        "generic",
        "(,",
        "(/",
    ]
    if any(marker in lowered for marker in placeholder_markers):
        return True
    return bool(re.search(r"\b-\b", text))


def _allocate_exact(total: int, weights: list[int]) -> list[int]:
    if total <= 0:
        return [0 for _ in weights]

    remaining = total
    remaining_weight = sum(weights)
    allocations: list[int] = []
    for index, weight in enumerate(weights):
        if index == len(weights) - 1:
            allocations.append(remaining)
            break
        amount = (remaining * weight) // remaining_weight
        amount = max(0, (amount // 500) * 500)
        allocations.append(amount)
        remaining -= amount
        remaining_weight -= weight
    return allocations


def _synthesize_recurring_obligations(
    persona_id: str, rent: int, fixed_total: int
) -> list[str]:
    other_fixed = max(0, fixed_total - rent)
    if persona_id == "aarav":
        labels = [
            "Utilities and internet",
            "Society maintenance and cleaning support to Savita",
            "Insurance and SIP commitments",
            "Fuel, metro pass, and commuting top-ups",
            "Phone plan and subscriptions",
            "Monthly family support transfer",
        ]
        weights = [12, 16, 26, 18, 10, 18]
    else:
        labels = [
            "Education loan EMI",
            "Monthly family support transfer",
            "Utilities and internet",
            "Society maintenance and domestic help",
            "Insurance premiums",
            "SIP and recurring investments",
        ]
        weights = [28, 24, 10, 14, 10, 14]

    if persona_id == "aarav":
        lines = [f"Rent to Mahesh Iyer: ₹{rent:,}"]
    elif persona_id == "priya":
        lines = [f"Rent to Ananya Properties: ₹{rent:,}"]
    else:
        lines = [f"Rent: ₹{rent:,}"]
    for label, amount in zip(labels, _allocate_exact(other_fixed, weights)):
        if amount > 0:
            lines.append(f"{label}: ₹{amount:,}")
    return lines


def _cohere_financials(data: dict) -> dict:
    fixed = max(data["monthly_fixed_obligations_inr"], data["monthly_rent_inr"])
    data["monthly_fixed_obligations_inr"] = fixed
    data["recurring_obligations"] = _synthesize_recurring_obligations(
        data["persona_id"], data["monthly_rent_inr"], fixed
    )
    data["family_obligations"] = [
        _strip_numeric_claims(item) for item in data["family_obligations"]
    ]

    ordinary_month_buffer = 10000
    affordable_high = max(0, data["monthly_salary_inr"] - fixed - ordinary_month_buffer)
    data["monthly_discretionary_high_inr"] = min(
        data["monthly_discretionary_high_inr"], affordable_high
    )
    data["monthly_discretionary_low_inr"] = min(
        data["monthly_discretionary_low_inr"], data["monthly_discretionary_high_inr"]
    )

    budget = data["budget_profile"]
    stress_extra = max(0, int(budget.get("stress_month_extra_spend_inr", 0)))
    safe_card_high = min(
        data["credit_card_limit_inr"] - 10000,
        min(
            int(data["monthly_salary_inr"] * 0.75),
            max(
                data["typical_credit_card_outstanding_high_inr"],
                data["typical_credit_card_outstanding_low_inr"] + max(15000, stress_extra // 2),
            ),
        ),
    )
    data["typical_credit_card_outstanding_high_inr"] = max(
        data["typical_credit_card_outstanding_low_inr"], safe_card_high
    )

    funding_target = max(
        0,
        fixed + data["monthly_discretionary_high_inr"] + stress_extra - data["monthly_salary_inr"],
    )
    if funding_target == 0:
        budget["stress_month_survival_mechanisms"] = [
            "Absorbs the extra month through lower discretionary spend and liquid savings."
        ]
    else:
        credit = min(max(5000, (funding_target * 3) // 5), funding_target)
        friend = min(max(3000, funding_target // 4), max(0, funding_target - credit))
        savings = max(0, funding_target - credit - friend)

        mechanisms = [f"Uses credit card float for about ₹{credit:,} of the deficit."]
        if friend > 0:
            mechanisms.append(
                f"Borrows about ₹{friend:,} from a friend and repays it over the next 1-3 salaries."
            )
        if savings > 0:
            mechanisms.append(
                f"Covers the remaining ₹{savings:,} by pulling down cash savings or delaying a discretionary purchase."
            )
        budget["stress_month_survival_mechanisms"] = mechanisms

    return data


def _concretize_aarav_details(data: dict) -> dict:
    if data["persona_id"] != "aarav":
        return data

    data["full_name"] = "Aarav Sharma"
    data["neighborhood"] = "Whitefield"
    data["work_pattern"] = (
        "Hybrid senior software engineer, usually in office Monday to Thursday and works from home on most Fridays."
    )
    data["commute_pattern"] = (
        "Drives about 14 km each way from Whitefield to Bellandur on office days, but falls back to Uber or Rapido after late nights or pub evenings."
    )
    data["friend_network"] = [
        "Rohan is the friend he borrows from most often and repays late after payday.",
        "Neha is part of the Friday dinner and cocktail circuit and often splits cabs and pub bills with him.",
        "Karthik is the office lunch and coffee buddy who fronts quick UPI settles during busy workdays.",
        "Suresh is the weekend travel friend who nudges him into impulsive plans and gadget purchases.",
        "Tanya is the dating-context spend trigger for nicer bars, cabs, and last-minute dinner bookings.",
    ]
    data["family_obligations"] = [
        "His younger sister Nisha is in Jaipur and gets a fixed monthly support transfer for coaching and rent.",
        "His father Sanjay reminds him about the parents' annual medical insurance premium and occasional pharmacy reimbursements.",
    ]
    data["relationship_context"] = (
        "Single, actively dating, and socially available enough that nights out and app-booked dinners show up in the data."
    )
    data["health_tendencies"] = [
        "Smokes every day and usually buys cigarettes in small repeated purchases near office or home.",
        "Skips workouts for stretches, then returns to the gym after guilt spikes or after a stressful week.",
    ]
    data["vices"] = [
        "Cigarettes and late-evening convenience-store runs.",
        "Friday pub tabs, cabs home, and the occasional after-party food order.",
        "Impulse electronics and accessory purchases when he feels he has had a rough week.",
        "Food-delivery and quick-commerce spending that continues even when he says he will cut back.",
    ]
    data["food_habits"] = [
        "Weekday lunches are usually office-cafeteria meals, coffee runs, or app orders during long coding blocks.",
        "Weekend meals tilt toward cafes, brewery food, and late-night delivery after social plans.",
    ]
    data["shopping_habits"] = [
        "He buys gadgets, headphones, and accessories after salary credit or after a stressful sprint.",
        "Clothing and sneakers are usually tied to social plans, trips, or sudden app-sale temptation.",
    ]
    data["travel_habits"] = [
        "Most travel is short weekend drives or quick outstation plans with friends rather than carefully budgeted holidays.",
        "Airport, toll, fuel, and late-night cab patterns should show up occasionally but not every month.",
    ]
    data["financial_temperament"] = "Financially chaotic, socially driven, and prone to short-term avoidance when the card bill looks ugly."
    data["credit_behavior"] = (
        "Usually clears most of the card when salary hits, but once or twice a year he pays only the minimum due and lets one messy month spill forward."
    )
    data["savings_discipline"] = (
        "Keeps some money aside when the month starts, then raids it for cabs, food delivery, or an avoidable impulse buy."
    )
    data["risk_tolerance"] = "Moderate on investments, weak on day-to-day consumption discipline."
    data["stress_responses"] = [
        "Keeps ordering food on bad workdays even after promising himself a quieter week.",
        "Uses the credit card more than UPI because it delays the pain of seeing the balance drop.",
        "Asks Rohan for a temporary transfer and repays late or in parts after salary lands.",
        "Cancels one plan, then leaks money elsewhere through cigarettes, cabs, or quick-commerce orders.",
    ]
    data["monthly_survival_logic"] = (
        "Most ordinary months remain survivable from salary, but his cushion gets eaten by social leakage, app orders, and one or two careless card decisions."
    )
    data["stress_month_behavior"] = (
        "A bad month usually includes an avoidable impulse purchase, a delayed card payment, extra cabs and food orders during work stress, and one borrowed transfer from Rohan before he stabilizes after payday."
    )
    data["boring_month_behavior"] = (
        "A boring month still shows salary, rent to landlord Mahesh Iyer, commuting fuel, coffee, cigarettes, food delivery, subscriptions, office lunches, and a few normal social spends."
    )
    data["realism_notes"] = [
        "Landlord Mahesh Iyer should appear as the recurring rent counterparty.",
        "Househelp Savita and office reimbursement source TechNova Ops should appear as named counterparties in later stages.",
        "He should look messy in small ways rather than permanently broken.",
    ]
    return data


def _normalize_persona(persona: PersonaBible) -> PersonaBible:
    data = persona.model_dump()

    for key in [
        "family_obligations",
        "friend_network",
        "health_tendencies",
        "vices",
        "food_habits",
        "shopping_habits",
        "travel_habits",
        "recurring_obligations",
        "stress_responses",
        "realism_notes",
    ]:
        data[key] = _dedupe_preserve_order(data[key])

    for key in [
        "family_obligations",
        "friend_network",
        "health_tendencies",
        "vices",
        "food_habits",
        "shopping_habits",
        "travel_habits",
        "stress_responses",
        "realism_notes",
    ]:
        data[key] = [_strip_numeric_claims(item) for item in data[key]]

    for key in [
        "work_pattern",
        "commute_pattern",
        "relationship_context",
        "financial_temperament",
        "credit_behavior",
        "savings_discipline",
        "risk_tolerance",
        "monthly_survival_logic",
        "stress_month_behavior",
        "boring_month_behavior",
    ]:
        data[key] = _strip_numeric_claims(data[key])

    budget = data["budget_profile"]
    budget["monthly_salary_inr"] = data["monthly_salary_inr"]
    budget["monthly_rent_inr"] = data["monthly_rent_inr"]
    budget["monthly_fixed_obligations_inr"] = data["monthly_fixed_obligations_inr"]
    budget["monthly_discretionary_low_inr"] = data["monthly_discretionary_low_inr"]
    budget["monthly_discretionary_high_inr"] = data["monthly_discretionary_high_inr"]
    budget["normal_month_total_spend_low_inr"] = (
        data["monthly_fixed_obligations_inr"] + data["monthly_discretionary_low_inr"]
    )
    budget["normal_month_total_spend_high_inr"] = (
        data["monthly_fixed_obligations_inr"] + data["monthly_discretionary_high_inr"]
    )
    budget["normal_month_surplus_after_discretionary_low_inr"] = (
        data["monthly_salary_inr"] - budget["normal_month_total_spend_low_inr"]
    )
    budget["normal_month_surplus_after_discretionary_high_inr"] = (
        data["monthly_salary_inr"] - budget["normal_month_total_spend_high_inr"]
    )
    budget["stress_month_survival_mechanisms"] = _dedupe_preserve_order(
        budget["stress_month_survival_mechanisms"]
    )

    return PersonaBible.model_validate(data)


def _normalize_raw_persona(raw: dict) -> dict:
    data = dict(raw)
    for key in [
        "family_obligations",
        "friend_network",
        "health_tendencies",
        "vices",
        "food_habits",
        "shopping_habits",
        "travel_habits",
        "recurring_obligations",
        "stress_responses",
        "realism_notes",
    ]:
        data[key] = list(data.get(key, []))

    budget = dict(data.get("budget_profile") or {})

    for field_name in [
        "monthly_salary_inr",
        "monthly_rent_inr",
        "monthly_fixed_obligations_inr",
        "monthly_discretionary_low_inr",
        "monthly_discretionary_high_inr",
    ]:
        if field_name in data:
            budget[field_name] = data[field_name]

    fixed = data["monthly_fixed_obligations_inr"]
    discretionary_low = data["monthly_discretionary_low_inr"]
    discretionary_high = data["monthly_discretionary_high_inr"]
    salary = data["monthly_salary_inr"]

    budget["normal_month_total_spend_low_inr"] = fixed + discretionary_low
    budget["normal_month_total_spend_high_inr"] = fixed + discretionary_high
    budget["normal_month_surplus_after_discretionary_low_inr"] = (
        salary - budget["normal_month_total_spend_low_inr"]
    )
    budget["normal_month_surplus_after_discretionary_high_inr"] = (
        salary - budget["normal_month_total_spend_high_inr"]
    )

    if "stress_month_extra_spend_inr" not in budget:
        budget["stress_month_extra_spend_inr"] = 0

    if not budget.get("stress_month_survival_mechanisms"):
        budget["stress_month_survival_mechanisms"] = ["Temporarily uses liquid savings."]

    data["budget_profile"] = budget
    data = _cohere_financials(data)
    data = _concretize_aarav_details(data)

    budget = data["budget_profile"]
    budget["monthly_salary_inr"] = data["monthly_salary_inr"]
    budget["monthly_rent_inr"] = data["monthly_rent_inr"]
    budget["monthly_fixed_obligations_inr"] = data["monthly_fixed_obligations_inr"]
    budget["monthly_discretionary_low_inr"] = data["monthly_discretionary_low_inr"]
    budget["monthly_discretionary_high_inr"] = data["monthly_discretionary_high_inr"]
    budget["normal_month_total_spend_low_inr"] = (
        data["monthly_fixed_obligations_inr"] + data["monthly_discretionary_low_inr"]
    )
    budget["normal_month_total_spend_high_inr"] = (
        data["monthly_fixed_obligations_inr"] + data["monthly_discretionary_high_inr"]
    )
    budget["normal_month_surplus_after_discretionary_low_inr"] = (
        data["monthly_salary_inr"] - budget["normal_month_total_spend_low_inr"]
    )
    budget["normal_month_surplus_after_discretionary_high_inr"] = (
        data["monthly_salary_inr"] - budget["normal_month_total_spend_high_inr"]
    )

    return data


def create_persona(persona_id: str, regeneration_feedback: str | None = None) -> PersonaBible:
    anchors = PERSONA_ANCHORS[persona_id]

    user_prompt = f"""
Create the Persona Bible for {persona_id}.

Project context:
- We are generating one year of raw AA-style financial data for Moné.
- Final output later must be raw AA payload only.
- We assume full account visibility.
- Self-transfers must later be visible and traceable across accounts.
- The persona must support realistic accounts, obligations, boring months, one stress month, daily life, and financial constraints.

{anchors}

Persona direction:
- Aarav: financially chaotic, urban professional, not cartoonishly irresponsible.
- Priya: responsible, high-income/burdened, family obligations, not mechanically perfect.

Budget sanity:
- monthly_fixed_obligations_inr must include rent.
- budget_profile.monthly_* fields must exactly mirror the top-level monthly fields.
- budget_profile.normal_month_total_spend_low_inr must equal fixed obligations + discretionary low.
- budget_profile.normal_month_total_spend_high_inr must equal fixed obligations + discretionary high.
- budget_profile.normal_month_surplus_after_discretionary_low_inr must equal salary - normal_month_total_spend_low_inr.
- budget_profile.normal_month_surplus_after_discretionary_high_inr must equal salary - normal_month_total_spend_high_inr.
- monthly_discretionary_high_inr can be high, but must not imply impossible survival every month.
- In an ordinary month, discretionary_high should usually still leave zero or positive surplus. Use stress_month_extra_spend_inr for actual deficit months.
- credit behavior must match salary, rent, obligations, and lifestyle.
- recurring_obligations should reconcile closely to monthly_fixed_obligations_inr. If some fixed spend is grouped, name it explicitly.
- budget_profile.stress_month_extra_spend_inr should reflect the extra burden in one difficult month, not a whole year.
- budget_profile.stress_month_survival_mechanisms must explain how the persona survives if a stress month exceeds salary.
- boring_month_behavior must describe ordinary months.
- stress_month_behavior must describe only one or two plausible difficult months.

Return only the persona bible JSON.
"""

    if regeneration_feedback:
        user_prompt += f"""

Previous critic rejection to fix:
{regeneration_feedback}

Regenerate this stage from scratch. Do not patch superficially.
Return a new persona that resolves those blocking defects while staying within the hard anchors.
"""

    raw = call_ollama_json(
        model=MODEL,
        system=CREATOR_SYSTEM,
        user=user_prompt,
        schema=PERSONA_SCHEMA,
        temperature=0.45,
    )
    normalized_raw = _normalize_raw_persona(raw)
    return _normalize_persona(PersonaBible.model_validate(normalized_raw))


def critique_persona(persona: PersonaBible) -> CriticResult:
    user_prompt = f"""
Critique this persona bible.

Persona:
{json.dumps(persona.model_dump(), indent=2)}

Remember:
- Do not be agreeable.
- Do not suggest cosmetic fixes.
- If rejecting for budget mismatch, cite the actual numbers.
- Be strict about impossible budget math and recurring deficits disguised as “normal.”
- Read surplus field names literally: after discretionary low/high means salary minus that respective spend path.
- REJECT_ASSUMPTION is rare and should only be used if the fixed project premises are impossible.
- Use REGENERATE_THIS_STAGE for a bad generated persona.
- Use REJECT_ASSUMPTION only if the fixed premise itself is impossible.
"""

    raw = call_ollama_json(
        model=MODEL,
        system=CRITIC_SYSTEM,
        user=user_prompt,
        schema=CRITIC_SCHEMA,
        temperature=0.15,
    )
    return CriticResult.model_validate(raw)
