from typing import List, Literal
from pydantic import BaseModel


class PersonaBible(BaseModel):
    persona_id: Literal["aarav", "priya"]

    full_name: str
    age: int
    city: str
    neighborhood: str
    job_title: str
    employer_name: str

    monthly_salary_inr: int
    monthly_rent_inr: int
    monthly_fixed_obligations_inr: int
    monthly_discretionary_low_inr: int
    monthly_discretionary_high_inr: int
    credit_card_limit_inr: int
    typical_credit_card_outstanding_low_inr: int
    typical_credit_card_outstanding_high_inr: int

    work_pattern: str
    commute_pattern: str
    family_obligations: List[str]
    friend_network: List[str]
    relationship_context: str
    health_tendencies: List[str]
    vices: List[str]
    food_habits: List[str]
    shopping_habits: List[str]
    travel_habits: List[str]

    financial_temperament: str
    credit_behavior: str
    savings_discipline: str
    risk_tolerance: str
    recurring_obligations: List[str]
    stress_responses: List[str]

    monthly_survival_logic: str
    stress_month_behavior: str
    boring_month_behavior: str
    realism_notes: List[str]


class BlockingDefect(BaseModel):
    code: str
    evidence: str
    why_blocking: str


class CriticResult(BaseModel):
    decision: Literal[
        "PASS",
        "REGENERATE_THIS_STAGE",
        "SEND_BACK_TO_PREVIOUS_STAGE",
        "REJECT_ASSUMPTION",
    ]
    blocking_defects: List[BlockingDefect]
    why_this_fails_realism_or_raw_aa_validity: List[str]
    required_regeneration_scope: str
    non_blocking_observations: List[str]
