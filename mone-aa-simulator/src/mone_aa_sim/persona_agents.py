import json
import os

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
- The monthly budget must make arithmetic sense.
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

Evaluate:
- persona realism
- Bangalore/city realism
- budget arithmetic
- financial behavior realism
- whether the persona can generate boring months and one stress month
- whether the persona is too flat, too dramatic, too stereotyped, or too convenient
- whether credit behavior is plausible for the income and account universe

Do not use:
- looks good overall
- minor issue
- minimal changes
- plausible enough
- can be fixed later

Return only JSON matching the schema.
"""


def create_persona(persona_id: str) -> PersonaBible:
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
- monthly_discretionary_high_inr can be high, but must not imply impossible survival every month.
- credit behavior must match salary, rent, obligations, and lifestyle.
- boring_month_behavior must describe ordinary months.
- stress_month_behavior must describe only one or two plausible difficult months.

Return only the persona bible JSON.
"""

    raw = call_ollama_json(
        model=MODEL,
        system=CREATOR_SYSTEM,
        user=user_prompt,
        schema=PERSONA_SCHEMA,
        temperature=0.45,
    )
    return PersonaBible.model_validate(raw)


def critique_persona(persona: PersonaBible) -> CriticResult:
    user_prompt = f"""
Critique this persona bible.

Persona:
{json.dumps(persona.model_dump(), indent=2)}

Remember:
- Do not be agreeable.
- Do not suggest cosmetic fixes.
- If rejecting for budget mismatch, cite the actual numbers.
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
