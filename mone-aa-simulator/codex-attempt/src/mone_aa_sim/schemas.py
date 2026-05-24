from typing import List, Literal
from pydantic import BaseModel, Field, model_validator


class MonthlyBudgetProfile(BaseModel):
    monthly_salary_inr: int = Field(ge=1)
    monthly_rent_inr: int = Field(ge=0)
    monthly_fixed_obligations_inr: int = Field(ge=0)
    monthly_discretionary_low_inr: int = Field(ge=0)
    monthly_discretionary_high_inr: int = Field(ge=0)
    normal_month_total_spend_low_inr: int = Field(ge=0)
    normal_month_total_spend_high_inr: int = Field(ge=0)
    normal_month_surplus_after_discretionary_low_inr: int
    normal_month_surplus_after_discretionary_high_inr: int
    stress_month_extra_spend_inr: int = Field(ge=0)
    stress_month_survival_mechanisms: List[str]

    @model_validator(mode="after")
    def validate_budget_math(self) -> "MonthlyBudgetProfile":
        if self.monthly_rent_inr > self.monthly_fixed_obligations_inr:
            raise ValueError("monthly_fixed_obligations_inr must include rent.")

        if self.monthly_discretionary_low_inr > self.monthly_discretionary_high_inr:
            raise ValueError(
                "monthly_discretionary_low_inr cannot exceed monthly_discretionary_high_inr."
            )

        expected_low = (
            self.monthly_fixed_obligations_inr + self.monthly_discretionary_low_inr
        )
        expected_high = (
            self.monthly_fixed_obligations_inr + self.monthly_discretionary_high_inr
        )

        if self.normal_month_total_spend_low_inr != expected_low:
            raise ValueError(
                "normal_month_total_spend_low_inr must equal fixed obligations plus discretionary low."
            )

        if self.normal_month_total_spend_high_inr != expected_high:
            raise ValueError(
                "normal_month_total_spend_high_inr must equal fixed obligations plus discretionary high."
            )

        expected_surplus_after_low = self.monthly_salary_inr - expected_low
        expected_surplus_after_high = self.monthly_salary_inr - expected_high

        if (
            self.normal_month_surplus_after_discretionary_low_inr
            != expected_surplus_after_low
        ):
            raise ValueError(
                "normal_month_surplus_after_discretionary_low_inr must equal salary minus normal_month_total_spend_low_inr."
            )

        if (
            self.normal_month_surplus_after_discretionary_high_inr
            != expected_surplus_after_high
        ):
            raise ValueError(
                "normal_month_surplus_after_discretionary_high_inr must equal salary minus normal_month_total_spend_high_inr."
            )

        return self


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
    budget_profile: MonthlyBudgetProfile

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

    @model_validator(mode="after")
    def validate_financial_coherence(self) -> "PersonaBible":
        if self.typical_credit_card_outstanding_low_inr > (
            self.typical_credit_card_outstanding_high_inr
        ):
            raise ValueError(
                "typical_credit_card_outstanding_low_inr cannot exceed high."
            )

        if self.typical_credit_card_outstanding_high_inr > self.credit_card_limit_inr:
            raise ValueError(
                "typical_credit_card_outstanding_high_inr cannot exceed the card limit."
            )

        budget = self.budget_profile
        mirrored_fields = {
            "monthly_salary_inr": self.monthly_salary_inr,
            "monthly_rent_inr": self.monthly_rent_inr,
            "monthly_fixed_obligations_inr": self.monthly_fixed_obligations_inr,
            "monthly_discretionary_low_inr": self.monthly_discretionary_low_inr,
            "monthly_discretionary_high_inr": self.monthly_discretionary_high_inr,
        }
        for field_name, expected in mirrored_fields.items():
            actual = getattr(budget, field_name)
            if actual != expected:
                raise ValueError(
                    f"budget_profile.{field_name} must match top-level {field_name}."
                )

        return self


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
