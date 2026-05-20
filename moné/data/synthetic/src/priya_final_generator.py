#!/usr/bin/env python3
"""Deterministic Priya responsibility-burden fixture generator and validator."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import random
import shutil
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Any


DATASET_ID = "priya_goal_planner_responsibility_burden"
SEED = "mone-priya-responsibility-burden-v3"
GENERATED_AT = "2026-05-19T09:45:00+05:30"
PERIOD_START = date(2025, 6, 1)
PERIOD_END = date(2026, 5, 31)
DATA_AS_OF_DATE = date(2026, 5, 31)
ROOT = Path(__file__).resolve().parents[3]
OUTPUT_ROOT = ROOT / "data/synthetic/output"
OUTPUT_DIR = OUTPUT_ROOT / DATASET_ID
GENERATION_COMMAND = f"python3 data/synthetic/src/run_all.py --dataset {DATASET_ID} --seed {SEED}"
VALIDATION_COMMAND = f"python3 data/synthetic/src/validate_against_ground_truth.py --dataset {DATASET_ID}"

SOURCE_FILES = [
    "raw_payload.json",
    "accounts.csv",
    "transactions.csv",
    "monthly_cashflow.csv",
    "mode_spending_summary.csv",
    "credit_card_statement.json",
    "credit_card_transactions.csv",
    "credit_card_summary.csv",
    "device_finance_source.json",
    "demo_identity_map.json",
    "dataset_registry.json",
]
EXPECTED_FILES = [
    "ground_truth.json",
    "income_candidates_expected.json",
    "recurring_candidates_expected.json",
    "emi_candidates_expected.json",
    "safe_to_spend_expected.json",
    "goal_risk_expected.json",
    "financial_health_expected.json",
    "net_worth_expected.json",
    "nudge_expected.json",
    "validation_report.json",
    "output_manifest.json",
]
REQUIRED_FILES = SOURCE_FILES + EXPECTED_FILES
FORBIDDEN_SOURCE_KEYS = {
    "category", "sub_category", "is_income", "is_salary", "is_rent", "is_emi",
    "is_obligation", "is_discretionary", "is_recurring", "is_family_support",
    "is_healthcare", "nudge_candidate", "should_interrupt", "expected_nudge_type",
    "safe_to_spend", "goal_drift", "financial_health_impact",
    "expected_user_confirmation", "user_facing_copy_candidate",
}
FORBIDDEN_NARRATION_TERMS = [
    "irresponsible", "impulse", "risky",
    "luxury spike", "food leakage", "cab_to_work", "weekday_coffee",
    "late_night_food", "goal drift", "safe-to-spend", "nudge", "liquidity rescue",
    "emergency fund breach", "adult_discretionary", "p2p_ambiguous",
    "local_micro_upi_noise", "family_support", "healthcare_buffer_pressure",
]


@dataclass
class Tx:
    txn_id: str
    account_id: str
    fi_type: str
    dt: datetime
    direction: str
    mode: str
    amount: float
    narration: str
    balance_after: float
    truth: dict[str, Any]
    reference: str


def days_in_month(year: int, month: int) -> int:
    if month == 12:
        return 31
    return (date(year, month + 1, 1) - timedelta(days=1)).day


def month_iter() -> list[date]:
    months: list[date] = []
    current = date(PERIOD_START.year, PERIOD_START.month, 1)
    while current <= PERIOD_END:
        months.append(current)
        current = date(current.year + (1 if current.month == 12 else 0), 1 if current.month == 12 else current.month + 1, 1)
    return months


def add_month(day: date, offset: int) -> date:
    month0 = day.month - 1 + offset
    year = day.year + month0 // 12
    month = month0 % 12 + 1
    return date(year, month, min(day.day, days_in_month(year, month)))


def ist(day: date, hour: int, minute: int) -> datetime:
    return datetime(day.year, day.month, day.day, hour, minute, 0)


def iso(dt: datetime) -> str:
    return dt.strftime("%Y-%m-%dT%H:%M:%S+05:30")


def money(value: float) -> str:
    return f"{value:.2f}"


def csv_text(fields: list[str], rows: list[dict[str, Any]]) -> str:
    from io import StringIO

    s = StringIO()
    writer = csv.DictWriter(s, fieldnames=fields)
    writer.writeheader()
    for row in rows:
        writer.writerow({field: row.get(field, "") for field in fields})
    return s.getvalue()


def time_of_day(dt: datetime) -> str:
    if 5 <= dt.hour < 12:
        return "morning"
    if 12 <= dt.hour < 17:
        return "afternoon"
    if 17 <= dt.hour < 22:
        return "evening"
    return "night"


def salary_phase(day: date, salary_dates: list[date]) -> str:
    last = max([d for d in salary_dates if d <= day], default=None)
    if not last:
        return "pre_first_salary"
    delta = (day - last).days
    if delta <= 6:
        return "salary_week"
    if delta <= 15:
        return "mid_cycle"
    if delta <= 24:
        return "late_cycle"
    return "pre_salary_caution"


def base_truth(dt: datetime, category: str, sub_category: str, merchant: str = "") -> dict[str, Any]:
    return {
        "category": category,
        "sub_category": sub_category,
        "merchant": merchant,
        "is_income": False,
        "is_salary": False,
        "is_bonus": False,
        "is_interest": False,
        "is_reimbursement_credit": False,
        "is_internal_transfer": False,
        "is_spending": True,
        "is_obligation": False,
        "is_rent": False,
        "is_emi": False,
        "is_education_loan_emi": False,
        "is_debt_commitment": False,
        "is_discretionary": False,
        "is_recurring": False,
        "is_family_support": False,
        "is_parent_support": False,
        "is_sibling_support": False,
        "is_domestic_help": False,
        "is_healthcare": False,
        "is_insurance": False,
        "is_premium": False,
        "is_claim": False,
        "is_investment": False,
        "is_goal_allocation": False,
        "is_cash_blindspot": False,
        "is_credit_card_payment": False,
        "is_utility": False,
        "is_travel": False,
        "is_festival": False,
        "is_explainable_large_spend": False,
        "affects_goal": False,
        "linked_goal_id": None,
        "nudge_candidate": False,
        "expected_nudge_type": None,
        "surface_mode": "silent_signal",
        "should_interrupt": False,
        "nudge_priority": "low",
        "user_facing_tone": "gentle",
        "confidence_expected": "high",
        "expected_safe_to_spend_impact": 0,
        "financial_health_impact": None,
        "day_of_week": dt.strftime("%A"),
        "time_of_day": time_of_day(dt),
        "salary_cycle_phase": "unknown",
    }


def normalize_nudge_truth(truth: dict[str, Any]) -> None:
    if not truth.get("nudge_candidate"):
        truth["expected_nudge_type"] = None
        truth["should_interrupt"] = False
        truth["surface_mode"] = "silent_signal"
        truth["nudge_priority"] = "low"
        return
    if truth.get("surface_mode") is None:
        truth["surface_mode"] = "dashboard_insight"
    if not truth.get("should_interrupt"):
        truth["should_interrupt"] = False


PRIYA_LOCAL_UPI = [
    ("UPI/DE/RAJU VEG", "vegetables", "Raju Veg", (60, 520), "medium"),
    ("UPI/DE/FRESH VEG QR", "vegetables", "Fresh Veg QR", (80, 620), "medium"),
    ("UPI/DE/FRUIT SHOP", "fruits", "Fruit Shop", (90, 700), "high"),
    ("UPI/DE/NATURAL FRUITS", "fruits", "Natural Fruits", (120, 850), "high"),
    ("UPI/DE/SRI LAKSHMI STORES", "groceries", "Sri Lakshmi Stores", (150, 1400), "high"),
    ("UPI/DE/KIRANA MART", "household_basics", "Kirana Mart", (110, 1200), "high"),
    ("UPI/DE/NANDINI MILK", "household_basics", "Nandini Milk", (40, 250), "high"),
    ("UPI/DE/WATER CAN SUPPLY", "household_basics", "Water Can Supply", (90, 420), "high"),
    ("UPI/DE/OM MEDICALS", "pharmacy", "Om Medicals", (120, 1600), "high"),
    ("UPI/DE/APOLLO PHARMACY", "pharmacy", "Apollo Pharmacy", (160, 1900), "high"),
    ("UPI/DE/DR SHARMA CLINIC", "doctor_consultation", "Dr Sharma Clinic", (700, 1800), "medium"),
    ("UPI/DE/DIAGNOSTIC CENTER", "diagnostics", "Diagnostic Center", (900, 3500), "medium"),
    ("UPI/DE/SANJAY PLUMBER", "plumbing", "Sanjay Plumber", (500, 2500), "medium"),
    ("UPI/DE/RAJ ELECTRICIAN", "electrical", "Raj Electrician", (400, 2400), "medium"),
    ("UPI/DE/SRI HARDWARE", "hardware", "Sri Hardware", (120, 1500), "medium"),
    ("UPI/DE/RO SERVICE", "household_service", "RO Service", (600, 2200), "medium"),
    ("UPI/DE/MEENA HOUSEHELP", "domestic_help", "Meena Househelp", (1500, 3500), "high"),
    ("UPI/DE/COOK PAYMENT", "domestic_help", "Cook Payment", (1000, 3000), "high"),
    ("UPI/DE/CAR CLEANER", "domestic_help", "Car Cleaner", (400, 1200), "high"),
    ("UPI/DE/STATIONERY SHOP", "stationery", "Stationery Shop", (40, 650), "high"),
    ("UPI/DE/XEROX SHOP", "printing", "Xerox Shop", (20, 300), "medium"),
    ("UPI/DE/PRINT CENTER", "printing", "Print Center", (40, 550), "medium"),
    ("UPI/DE/AUTO RAMESH", "local_transport", "Auto Ramesh", (70, 450), "medium"),
    ("UPI/DE/AUTO PAY", "local_transport", "Auto Pay", (60, 420), "medium"),
    ("UPI/DE/PARKING FEE", "local_transport", "Parking Fee", (30, 220), "high"),
    ("UPI/DE/METRO CARD", "local_transport", "Metro Card", (100, 900), "high"),
    ("UPI/DE/SHIV TEA STALL", "tea_snacks", "Shiv Tea Stall", (40, 220), "high"),
    ("UPI/DE/IYENGAR BAKERY", "tea_snacks", "Iyengar Bakery", (80, 500), "high"),
    ("UPI/DE/CHAAT CORNER", "street_food", "Chaat Corner", (70, 320), "medium"),
    ("UPI/DE/GIFT PALACE", "gifts", "Gift Palace", (300, 2200), "medium"),
    ("UPI/DE/CAKE SHOP", "gifts", "Cake Shop", (400, 2000), "medium"),
    ("UPI/DE/FLOWER SHOP", "festival", "Flower Shop", (120, 1000), "medium"),
    ("UPI/DE/PUJA STORE", "festival", "Puja Store", (100, 1500), "medium"),
    ("UPI/DE/PAYTMQR2819", "unknown_qr", "PAYTMQR2819", (60, 1800), "low"),
    ("UPI/DE/BHARATPE*OM SAI", "local_vendor_ambiguous", "BharatPe Om Sai", (90, 2100), "low"),
    ("UPI/DE/PHONEPEQR4381", "unknown_qr", "PHONEPEQR4381", (50, 1700), "low"),
    ("UPI/DE/SURESH", "p2p_ambiguous", "Suresh", (200, 2500), "low"),
    ("UPI/DE/ROHAN", "p2p_ambiguous", "Rohan", (250, 2200), "low"),
    ("UPI/DE/NEHA", "p2p_ambiguous", "Neha", (250, 2000), "low"),
    ("UPI/DE/MOM", "family_transfer", "Mom", (500, 3000), "medium"),
    ("UPI/DE/PAPA", "family_transfer", "Papa", (500, 3000), "medium"),
    ("UPI/DE/BREWERY", "nightlife", "Brewery", (900, 2600), "medium"),
]


class Builder:
    def __init__(self, seed: str):
        self.rng = random.Random(seed)
        self.accounts = {
            "deposit": "acc_deposit_priya_hdfc_0001",
            "mutual_funds": "acc_mf_priya_hdfc_0001",
            "recurring_deposit": "acc_rd_priya_hdfc_0001",
            "term_deposit": "acc_td_priya_hdfc_0001",
            "insurance_policies": "acc_ins_priya_family_0001",
        }
        self.masked = {
            "deposit": "XXXXXXXX7788",
            "mutual_funds": "MFXXXX7788",
            "recurring_deposit": "RDXXXX7788",
            "term_deposit": "TDXXXX7788",
            "insurance_policies": "INXXXX7788",
        }
        self.balances = {
            "deposit": 410000.0,
            "mutual_funds": 840000.0,
            "recurring_deposit": 90000.0,
            "term_deposit": 450000.0,
            "insurance_policies": 160000.0,
        }
        self.opening_balances = dict(self.balances)
        self.seq = 0
        self.txs: list[Tx] = []
        self.salary_dates = [date(m.year, m.month, 28) for m in month_iter()]
        self.asset_links: dict[str, str] = {}

    def ref(self) -> str:
        return str(910000000 + self.seq * 6113)

    def add_tx(self, fi_type: str, dt: datetime, direction: str, mode: str, amount: float, narration: str, truth: dict[str, Any], suffix: str = "") -> str:
        self.seq += 1
        amount = round(float(amount), 2)
        self.balances[fi_type] += amount if direction == "CREDIT" else -amount
        truth["day_of_week"] = dt.strftime("%A")
        truth["time_of_day"] = time_of_day(dt)
        truth["salary_cycle_phase"] = salary_phase(dt.date(), self.salary_dates)
        normalize_nudge_truth(truth)
        txn_id = f"TXN_PRIYA_SRC_{fi_type.upper()}_{dt.strftime('%Y%m%d')}_{self.seq:04d}{suffix}"
        self.txs.append(Tx(txn_id, self.accounts[fi_type], fi_type, dt, direction, mode, amount, narration, round(self.balances[fi_type], 2), truth, self.ref()))
        return txn_id

    def generate(self) -> dict[str, Any]:
        self.generate_transactions()
        self.txs.sort(key=lambda t: (t.dt, t.txn_id))
        recompute_running_balances(self.txs, self.opening_balances)
        credit_card = build_credit_card_sources(self.txs)
        expected = build_expected_outputs(self.txs, credit_card)
        payload = build_raw_payload(self.txs, self.accounts, self.masked, self.opening_balances)
        source_csvs = build_source_csvs(self.txs, payload)
        return {
            "payload": payload,
            "source_csvs": source_csvs,
            "ground_truth": build_ground_truth(self.txs),
            "credit_card": credit_card,
            "expected": expected,
        }

    def generate_transactions(self) -> None:
        sibling_months = {"2025-07": 18000, "2025-10": 32000, "2026-01": 14000, "2026-04": 25000}
        pressure_months = {"2025-10", "2026-01", "2026-03", "2026-05"}
        for m in month_iter():
            ym = f"{m.year:04d}-{m.month:02d}"
            salary_day = date(m.year, m.month, 28)
            t = base_truth(ist(salary_day, 9, 15), "income", "salary", "Banyan Product Labs")
            t.update({"is_income": True, "is_salary": True, "is_recurring": True, "is_spending": False})
            self.add_tx("deposit", ist(salary_day, 9, 15), "CREDIT", "FT", 260000 + self.rng.randint(-8000, 9000), f"FT/CR/BANYAN PRODUCT LABS SALARY/{ym}", t)
            if ym == "2026-03":
                t = base_truth(ist(date(2026, 3, 20), 14, 10), "income", "annual_bonus", "Banyan Product Labs")
                t.update({"is_income": True, "is_bonus": True, "is_spending": False, "nudge_candidate": True, "expected_nudge_type": "goal_acceleration_opportunity", "surface_mode": "dashboard_insight"})
                self.add_tx("deposit", ist(date(2026, 3, 20), 14, 10), "CREDIT", "FT", 300000, "FT/CR/BANYAN PRODUCT LABS PERFORMANCE BONUS", t)
            if ym in {"2025-09", "2026-02"}:
                d = date(m.year, m.month, 18)
                t = base_truth(ist(d, 16, 20), "transfer", "work_reimbursement", "Banyan Product Labs")
                t.update({"is_reimbursement_credit": True, "is_income": False, "is_spending": False})
                self.add_tx("deposit", ist(d, 16, 20), "CREDIT", "FT", 12400 if ym == "2025-09" else 18500, f"FT/CR/OFFICE EXPENSE REIMBURSEMENT/{ym}", t)
            if m.month in {6, 9, 12, 3}:
                d = date(m.year, m.month, 30 if m.month != 6 else 29)
                t = base_truth(ist(d, 10, 30), "income", "interest_income", "HDFC Bank")
                t.update({"is_interest": True, "is_income": True, "is_spending": False})
                self.add_tx("deposit", ist(d, 10, 30), "CREDIT", "FT", 3200 + self.rng.randint(0, 900), f"FT/CR/SAVINGS INTEREST/{ym}", t)
            self.monthly_obligations(m, ym)
            self.subscription_rows(m, ym)
            if ym in sibling_months:
                d = date(m.year, m.month, 16)
                t = base_truth(ist(d, 18, 35), "family", "sibling_support", "Sibling")
                t.update({"is_family_support": True, "is_sibling_support": True, "is_obligation": True, "nudge_candidate": True, "expected_nudge_type": "family_support_impact", "surface_mode": "dashboard_insight", "financial_health_impact": "family_responsibility_load"})
                self.add_tx("deposit", ist(d, 18, 35), "DEBIT", "FT", sibling_months[ym], f"FT/DE/ANIKET ICICI/{ym}", t)
            self.self_transfer_cluster(m, ym)
            self.local_micro_upi_noise(m, pressure_months)
            self.cash_withdrawals(m, ym)
            self.asset_and_goal_flows(m, ym)
        self.special_events()
        self.card_payment_rows()

    def monthly_obligations(self, m: date, ym: str) -> None:
        electricity_by_month = {
            "2025-06": 1580, "2025-07": 2260, "2025-08": 1880, "2025-09": 1320,
            "2025-10": 2740, "2025-11": 1680, "2025-12": 1460, "2026-01": 1940,
            "2026-02": 2210, "2026-03": 3150, "2026-04": 4620, "2026-05": 3840,
        }
        obligations = [
            (3, "UPI", 68000, "UPI/DE/RENT TO LANDLORD", "housing", "rent", "Synthetic Landlord", {"is_rent": True}),
            (8, "NACH", 24500, "NACH/DE/HDFC CREDILA EDUCATION LOAN", "debt", "education_loan_emi", "HDFC Credila", {"is_emi": True, "is_education_loan_emi": True, "is_debt_commitment": True}),
            (9, "FT", 35000, "FT/DE/PAPA SBI", "family", "parents_support", "Parents", {"is_family_support": True, "is_parent_support": True}),
            (12, "UPI", 8500, "UPI/DE/MEENA HOUSEHELP", "household", "domestic_help", "Meena Househelp", {"is_domestic_help": True}),
            (15, "UPI", 2499, "UPI/DE/ACT FIBERNET BILL", "utilities", "broadband", "ACT Fibernet", {"is_utility": True}),
            (17, "UPI", electricity_by_month[ym], "UPI/DE/BESCOM ELECTRICITY", "utilities", "electricity", "BESCOM", {"is_utility": True}),
            (19, "UPI", 899, "UPI/DE/AIRTEL MOBILE", "utilities", "mobile", "Airtel", {"is_utility": True}),
            (22, "UPI", 6200, "UPI/DE/APARTMENT MAINTENANCE", "housing", "apartment_maintenance", "Apartment Association", {"is_utility": True}),
        ]
        for day_num, mode, amount, narration, category, sub, merchant, flags in obligations:
            d = date(m.year, m.month, min(day_num, days_in_month(m.year, m.month)))
            t = base_truth(ist(d, 10, 5), category, sub, merchant)
            t.update({"is_obligation": True, "is_recurring": True, "is_discretionary": False, "expected_safe_to_spend_impact": -amount, "nudge_candidate": sub in {"education_loan_emi", "parents_support"}, "expected_nudge_type": "education_loan_pressure" if sub == "education_loan_emi" else "family_support_impact", "surface_mode": "dashboard_insight", **flags})
            self.add_tx("deposit", ist(d, 10, 5), "DEBIT", mode, amount, f"{narration}/{ym}", t)
        extras_by_month = {
            "2025-06": [(24, "UPI", 1120, "UPI/DE/INDANE LPG", "utilities", "lpg", "Indane LPG", {"is_utility": True})],
            "2025-07": [(4, "UPI", 2500, "UPI/DE/PARKING CHARGES", "housing", "parking", "Apartment Association", {"is_rent": True})],
            "2025-08": [(24, "UPI", 1180, "UPI/DE/HP GAS", "utilities", "lpg", "HP Gas", {"is_utility": True})],
            "2025-09": [(21, "UPI", 399, "UPI/DE/ACT FIBERNET EXTRA DATA", "utilities", "broadband_topup", "ACT Fibernet", {"is_utility": True})],
            "2025-10": [(4, "UPI", 3200, "UPI/DE/WATER CHARGES LANDLORD", "housing", "water_charges", "Synthetic Landlord", {"is_rent": True}), (23, "UPI", 1150, "UPI/DE/INDANE LPG", "utilities", "lpg", "Indane LPG", {"is_utility": True})],
            "2025-11": [(20, "UPI", 299, "UPI/DE/AIRTEL DATA BOOSTER", "utilities", "mobile_topup", "Airtel", {"is_utility": True})],
            "2025-12": [(24, "UPI", 1210, "UPI/DE/HP GAS", "utilities", "lpg", "HP Gas", {"is_utility": True})],
            "2026-01": [(4, "UPI", 4500, "UPI/DE/RENT DIFFERENCE LANDLORD", "housing", "rent_difference", "Synthetic Landlord", {"is_rent": True})],
            "2026-02": [(23, "UPI", 1090, "UPI/DE/INDANE LPG", "utilities", "lpg", "Indane LPG", {"is_utility": True})],
            "2026-03": [(20, "UPI", 799, "UPI/DE/AIRTEL ROAMING PACK", "utilities", "mobile_topup", "Airtel", {"is_utility": True})],
            "2026-04": [(23, "UPI", 1240, "UPI/DE/HP GAS", "utilities", "lpg", "HP Gas", {"is_utility": True})],
            "2026-05": [(4, "UPI", 6500, "UPI/DE/SOCIETY MAINTENANCE", "housing", "society_maintenance", "Apartment Association", {"is_rent": True})],
        }
        for day_num, mode, amount, narration, category, sub, merchant, flags in extras_by_month.get(ym, []):
            d = date(m.year, m.month, min(day_num, days_in_month(m.year, m.month)))
            t = base_truth(ist(d, 10, 35), category, sub, merchant)
            t.update({"is_obligation": True, "is_recurring": sub == "lpg", "is_discretionary": False, "expected_safe_to_spend_impact": -amount, **flags})
            self.add_tx("deposit", ist(d, 10, 35), "DEBIT", mode, amount, f"{narration}/{ym}", t)

    def subscription_rows(self, m: date, ym: str) -> None:
        subscriptions = [
            (5, 75, "CARD/DE/ICLOUD", "iCloud"),
            (7, 130, "CARD/DE/GOOGLE ONE", "Google One"),
            (13, 129, "CARD/DE/YOUTUBE PREMIUM", "YouTube Premium"),
            (18, 119, "CARD/DE/SPOTIFY", "Spotify"),
            (20, 650, "CARD/DE/LINKEDIN PREMIUM", "LinkedIn Premium"),
            (25, 249, "CARD/DE/NEWSPAPER DIGITAL", "Newspaper Digital"),
        ]
        if ym == "2026-05":
            subscriptions.append((11, 1499, "CARD/DE/PRIME MEMBERSHIP", "Prime Membership"))
        for day_num, amount, narration, merchant in subscriptions:
            d = date(m.year, m.month, min(day_num, days_in_month(m.year, m.month)))
            t = base_truth(ist(d, 8, 45), "subscription", merchant.lower().replace(" ", "_"), merchant)
            t.update({"is_subscription": True, "is_recurring": True, "is_discretionary": True, "nudge_candidate": ym in {"2026-01", "2026-05"} and amount >= 249, "expected_nudge_type": "safe_to_spend_watch", "surface_mode": "weekly_summary"})
            self.add_tx("deposit", ist(d, 8, 45), "DEBIT", "CARD", amount, narration, t)

    def self_transfer_cluster(self, m: date, ym: str) -> None:
        if ym in {"2025-07", "2025-10", "2026-01", "2026-03", "2026-05"}:
            d = date(m.year, m.month, 24)
            t = base_truth(ist(d, 12, 20), "transfer", "self_account_transfer", "Own Account")
            t.update({"is_internal_transfer": True, "is_income": False, "is_spending": False, "nudge_candidate": True, "expected_nudge_type": "self_transfer_review", "surface_mode": "weekly_summary"})
            self.add_tx("deposit", ist(d, 12, 20), "CREDIT", "FT", 30000, f"FT/CR/ICICI SAVINGS TRANSFER/{ym}", t)
        if ym in {"2025-08", "2025-11", "2026-04"}:
            d = date(m.year, m.month, 6)
            t = base_truth(ist(d, 13, 10), "transfer", "self_account_transfer", "Own Account")
            t.update({"is_internal_transfer": True, "is_income": False, "is_spending": False})
            self.add_tx("deposit", ist(d, 13, 10), "DEBIT", "FT", 22000, f"FT/DE/HDFC SAVINGS TRANSFER/{ym}", t)

    def local_micro_upi_noise(self, m: date, pressure_months: set[str]) -> None:
        ym = f"{m.year:04d}-{m.month:02d}"
        count = self.rng.randint(12, 30)
        used: set[tuple[int, int, int]] = set()
        for i in range(count):
            narration, sub, merchant, (lo, hi), confidence = self.rng.choice(PRIYA_LOCAL_UPI)
            day = self.rng.randint(1, days_in_month(m.year, m.month))
            d = date(m.year, m.month, day)
            if d > PERIOD_END:
                continue
            hour = self.rng.choice([8, 10, 12, 17, 18, 19, 20])
            minute = self.rng.randint(0, 55)
            while (day, hour, minute) in used:
                minute = (minute + 5) % 60
            used.add((day, hour, minute))
            if lo > 900:
                amount = self.rng.randint(lo, hi)
            elif hi <= 900 or self.rng.random() < 0.82:
                amount = self.rng.randint(lo, min(hi, 900))
            else:
                amount = self.rng.randint(max(lo, 901), hi)
            category = "healthcare" if sub in {"pharmacy", "doctor_consultation", "diagnostics"} else ("family" if sub == "family_transfer" else ("local_micro_upi" if sub not in {"unknown_qr", "p2p_ambiguous", "local_vendor_ambiguous"} else "ambiguous_upi"))
            should_interrupt = ym in pressure_months and i == 0 and amount >= 650
            t = base_truth(ist(d, hour, minute), category, sub, merchant)
            t.update({
                "is_discretionary": sub in {"street_food", "tea_snacks", "gifts", "festival", "nightlife", "p2p_ambiguous", "unknown_qr", "local_vendor_ambiguous"},
                "is_healthcare": sub in {"pharmacy", "doctor_consultation", "diagnostics"},
                "is_family_support": sub == "family_transfer",
                "is_domestic_help": sub == "domestic_help",
                "is_obligation": sub in {"domestic_help", "pharmacy", "doctor_consultation", "diagnostics", "household_service"},
                "nudge_candidate": True,
                "expected_nudge_type": "safe_to_spend_watch" if should_interrupt else ("ambiguous_upi_review" if confidence == "low" else "local_micro_upi_summary"),
                "surface_mode": "interrupt" if should_interrupt else ("dashboard_insight" if confidence == "low" or amount > 1200 else "weekly_summary"),
                "should_interrupt": should_interrupt,
                "nudge_priority": "high" if should_interrupt else ("medium" if confidence == "low" else "low"),
                "expected_safe_to_spend_impact": -amount,
                "confidence_expected": confidence,
                "financial_health_impact": "liquidity_stress_watch" if should_interrupt else None,
                "local_micro_upi_noise": True,
            })
            self.add_tx("deposit", ist(d, hour, minute), "DEBIT", "UPI", amount, narration, t)

    def cash_withdrawals(self, m: date, ym: str) -> None:
        for i in range(self.rng.randint(1, 3)):
            d = date(m.year, m.month, self.rng.choice([6, 13, 21, 26]))
            t = base_truth(ist(d, 11, 40 + i), "cash", "cash_withdrawal", "ATM")
            t.update({"is_cash_blindspot": True, "confidence_expected": "medium", "nudge_candidate": True, "expected_nudge_type": "cash_withdrawal_blindspot", "surface_mode": "weekly_summary"})
            self.add_tx("deposit", ist(d, 11, 40 + i), "DEBIT", "ATM", self.rng.choice([3000, 5000, 7000, 10000]), f"ATM/DE/CASH WITHDRAWAL/{ym}", t)

    def asset_and_goal_flows(self, m: date, ym: str) -> None:
        for day_num, amount, fund, goal_id in [(6, 28000, "ICICI PRUDENTIAL BLUECHIP", "long_term_investment"), (14, 12000, "NPS TIER I", "retirement")]:
            d = date(m.year, m.month, day_num)
            t = base_truth(ist(d, 9, 45), "investment", "sip", fund)
            t.update({"is_obligation": True, "is_investment": True, "is_goal_allocation": True, "is_recurring": True, "affects_goal": True, "linked_goal_id": goal_id})
            cash_id = self.add_tx("deposit", ist(d, 9, 45), "DEBIT", "NACH", amount, f"NACH/DE/{fund}/{ym}", t)
            mt = base_truth(ist(d, 10, 30), "investment", "mf_purchase", fund)
            mt.update({"is_investment": True, "is_goal_allocation": True, "linked_goal_id": goal_id, "linked_cashflow_transaction_id": cash_id, "is_spending": False})
            asset_id = self.add_tx("mutual_funds", ist(d, 10, 30), "CREDIT", "SIP", amount, f"MF/CR/PURCHASE/{fund}/{ym}", mt)
            self.asset_links[cash_id] = asset_id
        if ym <= "2026-02":
            d = date(m.year, m.month, 11)
            t = base_truth(ist(d, 9, 35), "investment", "recurring_deposit", "HDFC RD")
            t.update({"is_obligation": True, "is_investment": True, "is_goal_allocation": True, "is_recurring": True, "linked_goal_id": "emergency_fund"})
            cash_id = self.add_tx("deposit", ist(d, 9, 35), "DEBIT", "NACH", 18000, f"NACH/DE/HDFC RECURRING DEPOSIT/{ym}", t)
            rt = base_truth(ist(d, 10, 0), "investment", "rd_installment", "HDFC RD")
            rt.update({"is_investment": True, "linked_cashflow_transaction_id": cash_id, "is_spending": False})
            asset_id = self.add_tx("recurring_deposit", ist(d, 10, 0), "CREDIT", "NACH", 18000, f"RD/CR/INSTALLMENT/{ym}", rt)
            self.asset_links[cash_id] = asset_id
        if ym == "2026-03":
            for day_num, mode, amount, narration, sub, merchant in [
                (21, "FT", 60000, "FT/DE/HDFC CREDILA PART PAYMENT", "education_loan_part_payment", "HDFC Credila"),
                (22, "FT", 85000, "FT/DE/MF LUMPSUM PURCHASE", "mf_lumpsum_purchase", "ICICI Prudential"),
                (23, "NACH", 30000, "NACH/DE/RD ADDITIONAL DEPOSIT", "rd_additional_deposit", "HDFC RD"),
            ]:
                d = date(m.year, m.month, day_num)
                t = base_truth(ist(d, 10, 25), "investment" if "purchase" in sub or "deposit" in sub else "debt", sub, merchant)
                t.update({"is_obligation": sub == "education_loan_part_payment", "is_investment": sub != "education_loan_part_payment", "is_goal_allocation": sub != "education_loan_part_payment", "is_debt_commitment": sub == "education_loan_part_payment", "is_discretionary": False, "affects_goal": sub != "education_loan_part_payment"})
                cash_id = self.add_tx("deposit", ist(d, 10, 25), "DEBIT", mode, amount, narration, t)
                if sub == "mf_lumpsum_purchase":
                    mt = base_truth(ist(d, 11, 0), "investment", "mf_purchase", merchant)
                    mt.update({"is_investment": True, "is_goal_allocation": True, "linked_cashflow_transaction_id": cash_id, "is_spending": False})
                    self.asset_links[cash_id] = self.add_tx("mutual_funds", ist(d, 11, 0), "CREDIT", "FT", amount, "MF/CR/LUMPSUM PURCHASE/ICICI PRUDENTIAL", mt)
                if sub == "rd_additional_deposit":
                    rt = base_truth(ist(d, 11, 5), "investment", "rd_additional_deposit", merchant)
                    rt.update({"is_investment": True, "linked_cashflow_transaction_id": cash_id, "is_spending": False})
                    self.asset_links[cash_id] = self.add_tx("recurring_deposit", ist(d, 11, 5), "CREDIT", "NACH", amount, "RD/CR/ADDITIONAL DEPOSIT/HDFC", rt)

    def special_events(self) -> None:
        events = [
            (date(2025, 8, 21), "CARD", 28000, "CARD/DE/HOSPITAL PAYMENT", "healthcare", "parent_healthcare_support", "Hospital", {"is_healthcare": True, "is_family_support": True, "is_explainable_large_spend": True, "nudge_candidate": True, "expected_nudge_type": "healthcare_buffer_pressure", "surface_mode": "interrupt", "should_interrupt": True, "nudge_priority": "high"}),
            (date(2025, 9, 10), "UPI", 18500, "UPI/DE/DIAGNOSTIC CENTER", "healthcare", "diagnostics", "Diagnostic Center", {"is_healthcare": True, "is_explainable_large_spend": True}),
            (date(2025, 10, 17), "CARD", 46500, "CARD/DE/MYNTRA", "family", "festival_gifts", "Myntra", {"is_festival": True, "is_explainable_large_spend": True, "nudge_candidate": True, "expected_nudge_type": "goal_drift_watch", "surface_mode": "interrupt", "should_interrupt": True, "nudge_priority": "high"}),
            (date(2025, 10, 19), "FT", 22000, "FT/DE/MOM HDFC", "family", "parents_support", "Parents", {"is_family_support": True, "is_parent_support": True, "is_explainable_large_spend": True}),
            (date(2025, 12, 8), "CARD", 72000, "CARD/DE/INDIGO AIRLINES", "travel", "planned_travel", "Indigo Airlines", {"is_travel": True, "is_explainable_large_spend": True, "affects_goal": True, "linked_goal_id": "family_trip", "nudge_candidate": True, "expected_nudge_type": "goal_drift_watch", "surface_mode": "interrupt", "should_interrupt": True, "nudge_priority": "high"}),
            (date(2025, 12, 9), "CARD", 54000, "CARD/DE/MAKE MY TRIP HOTEL", "travel", "planned_travel", "MakeMyTrip", {"is_travel": True, "is_explainable_large_spend": True, "affects_goal": True, "linked_goal_id": "family_trip"}),
            (date(2026, 1, 16), "CARD", 62000, "CARD/DE/CROMA", "household", "home_appliance", "Croma", {"is_explainable_large_spend": True, "nudge_candidate": True, "expected_nudge_type": "liquidity_pressure", "surface_mode": "interrupt", "should_interrupt": True, "nudge_priority": "high"}),
            (date(2026, 2, 7), "UPI", 26500, "UPI/DE/SANJAY PLUMBER", "household", "home_repair", "Sanjay Plumber", {"is_explainable_large_spend": True, "is_obligation": True}),
            (date(2026, 2, 13), "UPI", 12000, "UPI/DE/MEENA HOUSEHELP ADVANCE", "household", "domestic_help_advance", "Meena Househelp", {"is_domestic_help": True, "is_obligation": True, "is_explainable_large_spend": True}),
            (date(2026, 3, 6), "UPI", 7800, "UPI/DE/HONDA SERVICE CENTER", "vehicle", "vehicle_service", "Honda Service Center", {"is_explainable_large_spend": True}),
            (date(2026, 4, 4), "CARD", 38000, "CARD/DE/IRCTC", "travel", "family_travel", "IRCTC", {"is_travel": True, "is_explainable_large_spend": True, "nudge_candidate": True, "expected_nudge_type": "goal_drift_watch", "surface_mode": "interrupt", "should_interrupt": True, "nudge_priority": "high"}),
        ]
        for d, mode, amount, narration, category, sub, merchant, flags in events:
            t = base_truth(ist(d, 18, 20), category, sub, merchant)
            t.update({"expected_safe_to_spend_impact": -amount, **flags})
            self.add_tx("deposit", ist(d, 18, 20), "DEBIT", mode, amount, narration, t)
        for d, amount, narration, sub in [
            (date(2025, 7, 5), 31000, "NACH/DE/HDFC ERGO HEALTH PREMIUM", "health_insurance"),
            (date(2025, 11, 6), 42000, "NACH/DE/MAX LIFE TERM PREMIUM", "term_insurance"),
            (date(2026, 2, 5), 26000, "NACH/DE/CARE HEALTH PREMIUM", "parent_health_topup"),
        ]:
            t = base_truth(ist(d, 9, 30), "insurance", sub, "Insurance Policy")
            t.update({"is_insurance": True, "is_premium": True, "is_obligation": True, "is_recurring": True, "nudge_candidate": True, "expected_nudge_type": "insurance_premium_due", "surface_mode": "dashboard_insight"})
            cash_id = self.add_tx("deposit", ist(d, 9, 30), "DEBIT", "NACH", amount, narration, t)
            it = base_truth(ist(d, 10, 5), "insurance", "policy_value", "Insurance Policy")
            it.update({"is_insurance": True, "is_spending": False, "linked_cashflow_transaction_id": cash_id})
            self.add_tx("insurance_policies", ist(d, 10, 5), "CREDIT", "POLICY", amount * 0.35, "INS/CR/POLICY VALUE", it)
        d = date(2025, 9, 22)
        t = base_truth(ist(d, 12, 5), "insurance", "insurance_claim", "HDFC Ergo")
        t.update({"is_insurance": True, "is_claim": True, "is_income": False, "is_spending": False})
        self.add_tx("deposit", ist(d, 12, 5), "CREDIT", "FT", 18000, "FT/CR/INSURANCE CLAIM CREDIT", t)
        d = date(2025, 12, 7)
        t = base_truth(ist(d, 9, 20), "transfer", "self_account_transfer", "Own Savings Account")
        t.update({"is_internal_transfer": True, "is_income": False, "is_spending": False, "nudge_candidate": True, "expected_nudge_type": "self_transfer_review", "surface_mode": "dashboard_insight"})
        self.add_tx("deposit", ist(d, 9, 20), "CREDIT", "FT", 80000, "FT/CR/ICICI SAVINGS TRANSFER", t)
        d = date(2025, 12, 17)
        t = base_truth(ist(d, 9, 20), "transfer", "self_account_transfer", "Own Savings Account")
        t.update({"is_internal_transfer": True, "is_income": False, "is_spending": False, "nudge_candidate": True, "expected_nudge_type": "self_transfer_review", "surface_mode": "dashboard_insight"})
        self.add_tx("deposit", ist(d, 9, 20), "CREDIT", "FT", 70000, "FT/CR/OWN ACCOUNT TRANSFER", t)
        d = date(2026, 1, 15)
        t = base_truth(ist(d, 9, 20), "transfer", "self_account_transfer", "Own Savings Account")
        t.update({"is_internal_transfer": True, "is_income": False, "is_spending": False, "nudge_candidate": True, "expected_nudge_type": "self_transfer_review", "surface_mode": "dashboard_insight"})
        self.add_tx("deposit", ist(d, 9, 20), "CREDIT", "FT", 100000, "FT/CR/ICICI SAVINGS TRANSFER", t)
        d = date(2026, 3, 18)
        t = base_truth(ist(d, 12, 5), "investment", "mf_redemption", "ICICI Prudential")
        t.update({"is_investment": True, "is_income": False, "is_spending": False, "nudge_candidate": True, "expected_nudge_type": "liquidity_pressure", "surface_mode": "dashboard_insight"})
        self.add_tx("mutual_funds", ist(d, 11, 30), "DEBIT", "REDEMPTION", 90000, "MF/DE/REDEMPTION/ICICI PRUDENTIAL", dict(t))
        self.add_tx("deposit", ist(d, 12, 5), "CREDIT", "FT", 90000, "FT/CR/MF REDEMPTION PROCEEDS", t)
        d = date(2026, 3, 25)
        t = base_truth(ist(d, 10, 5), "investment", "td_maturity_proceeds", "HDFC FD")
        t.update({"is_investment": True, "is_internal_transfer": True, "is_income": False, "is_spending": False})
        self.add_tx("term_deposit", ist(d, 9, 30), "DEBIT", "FD_CLOSURE", 450000, "FD/DE/MATURITY CLOSURE/HDFC", dict(t))
        self.add_tx("deposit", ist(d, 10, 5), "CREDIT", "FT", 450000, "FT/CR/FD MATURITY PROCEEDS", t)
        d = date(2026, 5, 29)
        t = base_truth(ist(d, 15, 15), "transfer", "self_account_transfer", "Own Investment Account")
        t.update({"is_internal_transfer": True, "is_income": False, "is_spending": False, "nudge_candidate": True, "expected_nudge_type": "self_transfer_review", "surface_mode": "dashboard_insight"})
        cash_id = self.add_tx("deposit", ist(d, 15, 15), "DEBIT", "FT", 850000, "FT/DE/SELF ACCOUNT TRANSFER", t)
        mt = base_truth(ist(d, 15, 40), "transfer", "self_account_transfer", "Own Investment Account")
        mt.update({"is_internal_transfer": True, "is_income": False, "is_spending": False, "linked_cashflow_transaction_id": cash_id})
        self.add_tx("mutual_funds", ist(d, 15, 40), "CREDIT", "FT", 850000, "MF/CR/OWN ACCOUNT FUNDING", mt)

    def card_payment_rows(self) -> None:
        for d, amount, status in [
            (date(2025, 9, 23), 42000, "full"),
            (date(2025, 11, 24), 56000, "full"),
            (date(2026, 1, 23), 84000, "partial"),
            (date(2026, 2, 24), 38000, "partial"),
            (date(2026, 4, 23), 48000, "full"),
        ]:
            t = base_truth(ist(d, 10, 20), "debt", "credit_card_payment", "HDFC Bank")
            t.update({"is_obligation": True, "is_credit_card_payment": True, "is_debt_commitment": True, "credit_card_payment_status": status, "nudge_candidate": status == "partial", "expected_nudge_type": "credit_card_bill_pressure", "surface_mode": "dashboard_insight", "card_payment_timing": "due_window"})
            self.add_tx("deposit", ist(d, 10, 20), "DEBIT", "FT", amount, "FT/DE/HDFC CREDIT CARD PAYMENT", t)


def recompute_running_balances(txs: list[Tx], openings: dict[str, float]) -> None:
    balances = dict(openings)
    for tx in sorted(txs, key=lambda t: (t.fi_type, t.dt, t.txn_id)):
        balances[tx.fi_type] += tx.amount if tx.direction == "CREDIT" else -tx.amount
        tx.balance_after = round(balances[tx.fi_type], 2)


def build_raw_payload(txs: list[Tx], accounts: dict[str, str], masked: dict[str, str], openings: dict[str, float]) -> list[dict[str, Any]]:
    by_fi: dict[str, list[Tx]] = defaultdict(list)
    for tx in txs:
        by_fi[tx.fi_type].append(tx)
    payload = []
    for fi_type in ["deposit", "mutual_funds", "recurring_deposit", "term_deposit", "insurance_policies"]:
        rows = sorted(by_fi.get(fi_type, []), key=lambda t: (t.dt, t.txn_id))
        current = rows[-1].balance_after if rows else openings[fi_type]
        account = {
            "maskedAccNumber": masked[fi_type],
            "type": fi_type,
            "version": "1.1",
            "linkedAccRef": accounts[fi_type],
            "summary": {
                "currentBalance": money(current),
                "currentValue": money(current),
                "status": "ACTIVE" if current > 0 else ("MATURED_CLOSED" if fi_type == "term_deposit" else "ACTIVE"),
                "balanceDateTime": GENERATED_AT,
            },
            "profile": {"holders": {"holder": [{"name": "Synthetic Holder PRIYA", "mobile": "9000000000", "email": "synthetic.priya@example.invalid", "pan": "ABCDE0000P", "address": "Synthetic Bangalore address"}]}},
            "transactions": {"startDate": PERIOD_START.isoformat(), "endDate": PERIOD_END.isoformat(), "transaction": []},
        }
        for tx in rows:
            account["transactions"]["transaction"].append({
                "txnId": tx.txn_id,
                "type": tx.direction,
                "mode": tx.mode,
                "amount": money(tx.amount),
                "currentBalance": money(tx.balance_after),
                "transactionTimestamp": iso(tx.dt),
                "valueDate": tx.dt.date().isoformat(),
                "narration": tx.narration,
                "reference": tx.reference,
            })
        payload.append({
            "fipId": f"synthetic_{fi_type}_fip",
            "generator_metadata": {
                "fixture_generated_at": GENERATED_AT,
                "data_period_start": PERIOD_START.isoformat(),
                "data_period_end": PERIOD_END.isoformat(),
                "data_as_of_date": DATA_AS_OF_DATE.isoformat(),
                "seed": SEED,
            },
            "data": [{"decryptedFI": {"account": account}}],
        })
    return payload


def build_source_csvs(txs: list[Tx], payload: list[dict[str, Any]]) -> dict[str, str]:
    fields = ["transaction_id", "date", "timestamp", "account_id", "fi_type", "direction", "mode", "amount", "narration", "balance_after"]
    tx_rows = [{
        "transaction_id": t.txn_id, "date": t.dt.date().isoformat(), "timestamp": iso(t.dt),
        "account_id": t.account_id, "fi_type": t.fi_type, "direction": t.direction,
        "mode": t.mode, "amount": money(t.amount), "narration": t.narration, "balance_after": money(t.balance_after),
    } for t in sorted(txs, key=lambda x: (x.dt, x.txn_id))]
    accounts = []
    for fip in payload:
        acc = fip["data"][0]["decryptedFI"]["account"]
        fi_type = acc["type"]
        summary = acc["summary"]
        accounts.append({
            "account_id": acc["linkedAccRef"], "fi_type": fi_type, "masked_account_number": acc["maskedAccNumber"],
            "account_status": summary["status"], "current_balance": summary["currentBalance"], "current_value": summary["currentValue"],
            "liquidity_class": "liquid" if fi_type == "deposit" else ("semi_liquid" if fi_type == "mutual_funds" else "protected_or_locked"),
            "balance_role": "spendable_cash" if fi_type == "deposit" else "asset_value",
        })
    monthly = []
    by_month = defaultdict(list)
    for tx in txs:
        by_month[tx.dt.strftime("%Y-%m")].append(tx)
    for ym in sorted(by_month):
        rows = [t for t in by_month[ym] if t.fi_type == "deposit"]
        monthly.append({"month": ym, "credits": money(sum(t.amount for t in rows if t.direction == "CREDIT")), "debits": money(sum(t.amount for t in rows if t.direction == "DEBIT")), "net_cashflow": money(sum(t.amount if t.direction == "CREDIT" else -t.amount for t in rows)), "transaction_count": len(rows)})
    mode_rows = []
    for (ym, mode), rows in sorted(defaultdict(list, {k: v for k, v in group_by([(t.dt.strftime("%Y-%m"), t.mode, t) for t in txs if t.fi_type == "deposit"]).items()}).items()):
        mode_rows.append({"month": ym, "mode": mode, "transaction_count": len(rows), "total_debits": money(sum(t.amount for t in rows if t.direction == "DEBIT")), "total_credits": money(sum(t.amount for t in rows if t.direction == "CREDIT"))})
    return {
        "transactions.csv": csv_text(fields, tx_rows),
        "accounts.csv": csv_text(["account_id", "fi_type", "masked_account_number", "account_status", "current_balance", "current_value", "liquidity_class", "balance_role"], accounts),
        "monthly_cashflow.csv": csv_text(["month", "credits", "debits", "net_cashflow", "transaction_count"], monthly),
        "mode_spending_summary.csv": csv_text(["month", "mode", "transaction_count", "total_debits", "total_credits"], mode_rows),
    }


def group_by(rows: list[tuple[str, str, Tx]]) -> dict[tuple[str, str], list[Tx]]:
    grouped: dict[tuple[str, str], list[Tx]] = defaultdict(list)
    for ym, mode, tx in rows:
        grouped[(ym, mode)].append(tx)
    return grouped


def build_ground_truth(txs: list[Tx]) -> dict[str, Any]:
    return {
        "dataset_id": DATASET_ID,
        "persona_id": "priya",
        "generated_at": GENERATED_AT,
        "period": {"start": PERIOD_START.isoformat(), "end": PERIOD_END.isoformat()},
        "summary": {
            "total_transactions": len(txs),
            "income_events": sum(1 for t in txs if t.truth.get("is_income")),
            "local_micro_upi_events": sum(1 for t in txs if t.truth.get("local_micro_upi_noise")),
            "family_support_events": sum(1 for t in txs if t.truth.get("is_family_support")),
            "education_loan_emi_events": sum(1 for t in txs if t.truth.get("is_education_loan_emi")),
            "cash_blindspots": sum(1 for t in txs if t.truth.get("is_cash_blindspot")),
            "nudge_candidates": sum(1 for t in txs if t.truth.get("nudge_candidate")),
            "interrupt_nudges": sum(1 for t in txs if t.truth.get("should_interrupt")),
        },
        "transactions": [{"transaction_id": t.txn_id, "persona_id": "priya", "account_type": t.fi_type, "dataset_id": DATASET_ID, "ground_truth": t.truth} for t in txs],
    }


def build_credit_card_sources(txs: list[Tx]) -> dict[str, Any]:
    card_specs = [
        ("priya_card_hospital_20250821", date(2025, 8, 21), "Hospital Payment", 28000, "healthcare", "cc_2025_08"),
        ("priya_card_myntra_20251017", date(2025, 10, 17), "Myntra", 46500, "apparel_family", "cc_2025_10"),
        ("priya_card_indigo_20251208", date(2025, 12, 8), "Indigo Airlines", 72000, "travel", "cc_2025_12"),
        ("priya_card_hotel_20251209", date(2025, 12, 9), "MakeMyTrip Hotel", 54000, "travel", "cc_2025_12"),
        ("priya_card_croma_20260116", date(2026, 1, 16), "Croma", 62000, "household_appliance", "cc_2026_01"),
        ("priya_card_train_20260404", date(2026, 4, 4), "IRCTC", 38000, "family_travel", "cc_2026_04"),
    ]
    dep = {(t.dt.date(), round(t.amount, 2)): t.txn_id for t in txs if t.fi_type == "deposit" and t.mode == "CARD"}
    rows = []
    for card_id, d, merchant, amount, mcat, cycle in card_specs:
        rows.append({
            "card_transaction_id": card_id,
            "purchase_date": d.isoformat(),
            "posting_date": (d + timedelta(days=1)).isoformat(),
            "merchant": merchant,
            "amount": amount,
            "merchant_category_from_statement": mcat,
            "source": "credit_card_statement",
            "statement_cycle_id": cycle,
            "converted_to_emi": merchant == "Croma",
            "emi_id": "emi_home_appliance_202601" if merchant == "Croma" else "",
            "statement_large_purchase_flag": amount >= 50000,
            "source_reconciliation_linked_deposit_transaction_id": dep.get((d, float(amount)), ""),
            "source_reconciliation_spend_counting_policy": "linked_to_deposit_card_mode_for_dedupe",
            "source_reconciliation_counted_as_additional_cashflow": False,
        })
    cycles = []
    cycle_specs = {
        "cc_2025_08": (42000, 42000, "full", 0.18),
        "cc_2025_10": (56000, 56000, "full", 0.24),
        "cc_2025_12": (134000, 84000, "partial", 0.57),
        "cc_2026_01": (78000, 38000, "partial", 0.34),
        "cc_2026_03": (48000, 48000, "full", 0.20),
        "cc_2026_04": (38000, 0, "scheduled", 0.16),
        "cc_2026_05": (54000, 0, "scheduled", 0.23),
    }
    cycle_month = date(2025, 6, 1)
    while cycle_month <= date(2026, 7, 1):
        cid = f"cc_{cycle_month.year:04d}_{cycle_month.month:02d}"
        due, paid, status, util = cycle_specs.get(cid, (0, 0, "no_activity", 0.0))
        y, m = cycle_month.year, cycle_month.month
        cycles.append({
            "statement_cycle_id": cid,
            "card_name": "HDFC Diners Synthetic",
            "masked_card_number": "XXXX-XXXX-XXXX-7788",
            "credit_limit": 235000.0,
            "available_credit": round(235000 - due, 2),
            "statement_cycle_start": date(y, m, 1).isoformat(),
            "statement_cycle_end": date(y, m, days_in_month(y, m)).isoformat(),
            "due_date": add_month(date(y, m, 23), 1).isoformat(),
            "total_amount_due": float(due),
            "minimum_amount_due": round(due * 0.05, 2),
            "previous_outstanding": 0.0,
            "payments_received": float(paid),
            "payment_status": status,
            "interest_charged": 1200.0 if status == "partial" and cid == "cc_2026_01" else 0.0,
            "late_fee": 0.0,
            "emi_outstanding": 42000.0 if cid >= "cc_2026_01" else 0.0,
            "utilization_ratio": util,
            "statement_status": "historical",
            "is_over_limit": False,
            "over_limit_amount": 0.0,
            "over_limit_reason": "",
            "over_limit_fee": 0.0,
        })
        cycle_month = add_month(cycle_month, 1)
    emi_schedules = []
    for i in range(6):
        due = add_month(date(2026, 2, 23), i)
        paid = due <= PERIOD_END
        emi_schedules.append({
            "emi_id": "emi_home_appliance_202601",
            "emi_type": "card_emi",
            "installment_number": i + 1,
            "total_installments": 6,
            "installment_amount": 10500,
            "due_date": due.isoformat(),
            "payment_status": "paid" if paid else "scheduled",
            "linked_card_statement_id": f"cc_{due.year:04d}_{due.month:02d}",
            "linked_deposit_transaction_id": None,
            "payment_source": "statement_only_paid" if paid else "future_statement_schedule",
            "cashflow_link_status": "not_linked_scenario_grade" if paid else "scheduled_future_no_cashflow_yet",
            "cashflow_link_reason": "Scenario-grade card statement records household appliance EMI as paid in statement without a separate modeled bank debit." if paid else "Future scheduled EMI installment is outside extraction period.",
            "remaining_principal": max(0, 10500 * (6 - i - 1)),
        })
    statement = {
        "dataset_id": DATASET_ID,
        "source_type": "synthetic_credit_card_statement",
        "accounting_precision": "scenario_grade",
        "not_for_production_accounting_rules": True,
        "spend_counting_policy": {
            "card_statement_purchases_are_primary_card_source": True,
            "deposit_card_mode_purchase_rows_are_legacy_dedupe_links": True,
            "deposit_card_bill_payment_rows_are_cashflow_events": True,
            "count_card_purchases_as_additional_deposit_cashflow": False,
        },
        "modeling_limitations": [
            "Hybrid compatibility convention with deposit CARD-mode rows",
            "Statement cycles are scenario-testing inputs, not full issuer-grade accounting",
            "Previous outstanding and utilization are synthetic pressure indicators",
        ],
        "account": {"card_name": "HDFC Diners Synthetic", "masked_card_number": "XXXX-XXXX-XXXX-7788", "credit_limit": 235000.0},
        "statement_cycles": cycles,
        "transactions": [{k: v for k, v in row.items() if not k.startswith("source_reconciliation_")} | {"generator_metadata": {"source_reconciliation_linked_deposit_transaction_id": row["source_reconciliation_linked_deposit_transaction_id"], "source_reconciliation_spend_counting_policy": row["source_reconciliation_spend_counting_policy"], "source_reconciliation_counted_as_additional_cashflow": False}} for row in rows],
        "emi_schedules": emi_schedules,
    }
    return {
        "statement": statement,
        "transactions_csv": csv_text(["card_transaction_id", "purchase_date", "posting_date", "merchant", "amount", "merchant_category_from_statement", "source", "statement_cycle_id", "converted_to_emi", "emi_id", "statement_large_purchase_flag", "source_reconciliation_linked_deposit_transaction_id", "source_reconciliation_spend_counting_policy", "source_reconciliation_counted_as_additional_cashflow"], rows),
        "summary_csv": csv_text(["statement_cycle_id", "card_name", "masked_card_number", "credit_limit", "available_credit", "statement_cycle_start", "statement_cycle_end", "due_date", "total_amount_due", "minimum_amount_due", "previous_outstanding", "payments_received", "payment_status", "interest_charged", "late_fee", "emi_outstanding", "utilization_ratio", "statement_status", "is_over_limit", "over_limit_amount", "over_limit_reason", "over_limit_fee"], cycles),
    }


def build_expected_outputs(txs: list[Tx], credit_card: dict[str, Any]) -> dict[str, Any]:
    return {
        "income_candidates_expected.json": build_income_expected(txs),
        "recurring_candidates_expected.json": build_recurring_expected(),
        "emi_candidates_expected.json": build_emi_expected(),
        "safe_to_spend_expected.json": build_safe_expected(txs),
        "goal_risk_expected.json": build_goal_expected(txs),
        "financial_health_expected.json": build_health_expected(),
        "net_worth_expected.json": build_net_worth_expected(txs, credit_card),
        "nudge_expected.json": build_nudge_expected(txs),
        "device_finance_source.json": build_device_finance_source(),
    }


def build_income_expected(txs: list[Tx]) -> list[dict[str, Any]]:
    rows = []
    for tx in txs:
        if tx.truth.get("is_income") and not tx.truth.get("is_reimbursement_credit") and not tx.truth.get("is_internal_transfer"):
            rows.append({"transaction_id": tx.txn_id, "date": tx.dt.date().isoformat(), "amount": tx.amount, "type": "salary" if tx.truth.get("is_salary") else ("bonus" if tx.truth.get("is_bonus") else "interest_dividend"), "confidence_expected": "high"})
    return rows


def build_recurring_expected() -> dict[str, Any]:
    return {
        "dataset_id": DATASET_ID,
        "fixed_commitment": [
            {"name": "Rent", "monthly_amount": 68000, "normalized_bucket": "fixed_commitment", "commitment_strength": "must_pay"},
            {"name": "Parents support", "monthly_amount": 35000, "normalized_bucket": "family_obligation", "commitment_strength": "must_pay"},
            {"name": "Domestic help", "monthly_amount": 8500, "normalized_bucket": "household_commitment", "commitment_strength": "must_pay"},
        ],
        "debt_commitment": [
            {"name": "HDFC Credila education loan", "monthly_amount": 24500, "normalized_bucket": "debt_commitment", "commitment_strength": "must_pay", "obligation_type": "education_loan"},
            {"name": "Household appliance card EMI", "monthly_amount": 10500, "normalized_bucket": "debt_commitment", "commitment_strength": "must_pay", "obligation_type": "household_emi"},
        ],
        "protected_goal_transfer": [
            {"name": "ICICI Prudential SIP", "monthly_amount": 28000, "normalized_bucket": "protected_goal_transfer", "goal_protective": True},
            {"name": "Emergency RD", "monthly_amount": 18000, "normalized_bucket": "protected_goal_transfer", "goal_protective": True},
        ],
        "insurance_commitment": [
            {"name": "Family health and term protection", "normalized_bucket": "protection_commitment", "commitment_strength": "must_pay"},
        ],
    }


def build_emi_expected() -> list[dict[str, Any]]:
    return [
        {"candidate_id": "emi_education_loan_hdfc_credila", "emi_type": "education_loan_emi", "lender": "HDFC Credila", "monthly_amount": 24500, "tenure_months_remaining": 36, "first_due_date": "2025-06-08", "last_due_date": "2028-05-08", "payment_status_pattern": "regular", "confidence_expected": "high", "obligation_type": "debt_commitment", "safe_to_spend_impact": "high", "financial_health_impact": "debt_pressure", "is_responsibility_debt": True},
        {"candidate_id": "emi_home_appliance_202601", "emi_type": "card_emi", "merchant": "Croma", "lender": "HDFC Bank", "monthly_amount": 10500, "tenure_months": 6, "remaining_months": 2, "first_due_date": "2026-02-23", "last_due_date": "2026-07-23", "payment_status_pattern": ["paid", "scheduled"], "confidence_expected": "high", "obligation_type": "household_responsibility_debt", "safe_to_spend_impact": -10500, "financial_health_impact": "debt_pressure_watch"},
    ]


def build_safe_expected(txs: list[Tx]) -> dict[str, Any]:
    rows = []
    risk_months = {"2025-08", "2025-10", "2025-12", "2026-01"}
    healthy_months = {"2026-03", "2026-05"}
    capacity_by_status = {
        "risk": -72000,
        "watch": -18000,
        "healthy": 42000,
    }
    risk_reasons = {
        "2025-08": "Parent healthcare support compresses monthly capacity.",
        "2025-10": "Festival and sibling support create a material shortfall.",
        "2025-12": "Planned travel and card payment pressure create a material shortfall.",
        "2026-01": "Household appliance and partial card payment make the month high pressure.",
    }
    for m in month_iter():
        ym = f"{m.year:04d}-{m.month:02d}"
        mt = [t for t in txs if t.fi_type == "deposit" and t.dt.strftime("%Y-%m") == ym]
        income = sum(t.amount for t in mt if t.truth.get("is_income"))
        excluded = sum(t.amount for t in mt if t.direction == "CREDIT" and (t.truth.get("is_reimbursement_credit") or t.truth.get("is_internal_transfer") or t.truth.get("is_claim")))
        must_pay = sum(t.amount for t in mt if t.truth.get("is_obligation") or t.truth.get("is_emi") or t.truth.get("is_rent"))
        family = sum(t.amount for t in mt if t.truth.get("is_family_support"))
        education_loan = sum(t.amount for t in mt if t.truth.get("is_education_loan_emi"))
        insurance = sum(t.amount for t in mt if t.truth.get("is_insurance") and t.truth.get("is_premium"))
        fixed = must_pay + family
        protected = sum(t.amount for t in mt if t.truth.get("is_goal_allocation") or t.truth.get("is_investment"))
        discretionary = sum(t.amount for t in mt if t.truth.get("is_discretionary"))
        status = "risk" if ym in risk_months else ("healthy" if ym in healthy_months else "watch")
        actual_capacity = capacity_by_status[status] + (month_iter().index(m) % 3) * 7000
        if status == "watch":
            actual_capacity = -24000 + (month_iter().index(m) % 4) * 12000
        if status == "healthy":
            actual_capacity = 42000 + (month_iter().index(m) % 2) * 18000
        planned_capacity = actual_capacity + (18000 if status != "risk" else 12000)
        reason = risk_reasons.get(ym, "Responsibilities, education loan EMI, family support, and goal commitments compress monthly flexibility.")
        rows.append({
            "month": ym,
            "income": round(income, 2),
            "excluded_from_income_amount": round(excluded, 2),
            "fixed_commitments": round(fixed, 2),
            "must_pay_commitments": round(must_pay, 2),
            "family_responsibility_commitments": round(family, 2),
            "education_loan_commitments": round(education_loan, 2),
            "insurance_commitments": round(insurance, 2),
            "protected_goal_transfers": round(protected, 2),
            "goal_protection": round(protected, 2),
            "expected_discretionary_spend": 42000,
            "actual_discretionary_spend": round(discretionary, 2),
            "discretionary_capacity": round(actual_capacity, 2),
            "debt_commitments": 35000 if ym >= "2026-02" else 24500,
            "planned_safe_to_spend_after_expected_spend": round(planned_capacity, 2),
            "actual_safe_to_spend_after_period": round(actual_capacity, 2),
            "safe_to_spend_end": round(actual_capacity, 2),
            "liquidity_rescue_amount": 0,
            "status": status,
            "reason": reason,
        })
    return {
        "dataset_id": DATASET_ID,
        "fixture_generated_at": GENERATED_AT,
        "data_period_start": PERIOD_START.isoformat(),
        "data_period_end": PERIOD_END.isoformat(),
        "data_as_of_date": DATA_AS_OF_DATE.isoformat(),
        "month_level": rows,
        "weekly_snapshots": [],
    }


def build_goal_expected(txs: list[Tx]) -> dict[str, Any]:
    return {"dataset_id": DATASET_ID, "goals": [
        {"goal_id": "emergency_fund", "goal_name": "Emergency fund", "target_amount": 800000, "deadline": "2026-12-31", "monthly_allocation_needed": 30000, "actual_allocations": 9, "skipped_or_reduced_months": ["2025-10", "2026-01", "2026-03"], "projected_delay_days": 45, "status": "Watch", "reason": "Family support and healthcare events reduced allocation capacity."},
        {"goal_id": "parents_healthcare_buffer", "goal_name": "Parents healthcare buffer", "target_amount": 500000, "deadline": "2026-09-30", "monthly_allocation_needed": 25000, "actual_allocations": 6, "skipped_or_reduced_months": ["2025-08", "2025-10", "2026-02"], "projected_delay_days": 75, "status": "Risk", "reason": "Parent healthcare support and insurance premiums raised near-term pressure."},
        {"goal_id": "family_trip", "goal_name": "Japan family trip", "target_amount": 420000, "deadline": "2027-03-31", "monthly_allocation_needed": 18000, "actual_allocations": 7, "skipped_or_reduced_months": ["2025-12", "2026-01"], "projected_delay_days": 55, "status": "Watch", "reason": "Planned travel booking pulled forward cash needs."},
        {"goal_id": "home_upgrade", "goal_name": "Home upgrade fund", "target_amount": 300000, "deadline": "2026-11-30", "monthly_allocation_needed": 16000, "actual_allocations": 8, "skipped_or_reduced_months": ["2026-01", "2026-02"], "projected_delay_days": 40, "status": "Watch", "reason": "Household appliance and repair expenses temporarily reduced headroom."},
        {"goal_id": "long_term_investment", "goal_name": "Long-term investment target", "target_amount": 2500000, "deadline": "2030-12-31", "monthly_allocation_needed": 40000, "actual_allocations": 12, "skipped_or_reduced_months": [], "projected_delay_days": 0, "status": "Healthy", "reason": "SIP discipline remains intact despite responsibility load."},
        {"goal_id": "education_loan_payoff", "goal_name": "Education-loan payoff acceleration", "target_amount": 250000, "deadline": "2027-05-31", "monthly_allocation_needed": 12000, "actual_allocations": 5, "skipped_or_reduced_months": ["2025-10", "2026-01", "2026-03"], "projected_delay_days": 60, "status": "Watch", "reason": "Monthly EMI is regular, but acceleration capacity is constrained by family and healthcare commitments."},
    ]}


def build_health_expected() -> dict[str, Any]:
    return {"dataset_id": DATASET_ID, "overall_status": "Watch", "dimensions": {"cashflow_stability": "Watch", "obligation_load": "Risk", "safe_to_spend": "Watch", "goal_progress": "Watch", "emergency_readiness": "Watch", "debt_pressure": "Watch", "spending_drift": "Watch", "credit_card_discipline": "Watch", "liquidity_stress": "Watch", "investment_discipline": "Healthy", "family_responsibility_load": "Risk", "insurance_readiness": "Healthy", "net_worth": "Watch", "liquid_net_worth": "Watch"}, "reason": "Priya is responsibility-heavy: fixed commitments and education debt leave limited flexible room."}


def build_net_worth_expected(txs: list[Tx], credit_card: dict[str, Any]) -> dict[str, Any]:
    cycles = {c["statement_cycle_id"]: c for c in credit_card["statement"]["statement_cycles"]}
    rows = []
    for m in month_iter():
        ym = f"{m.year:04d}-{m.month:02d}"
        upto = [t for t in txs if t.dt.date() <= date(m.year, m.month, days_in_month(m.year, m.month))]
        def final(fi_type: str, opening: float) -> float:
            rows_fi = sorted([t for t in upto if t.fi_type == fi_type], key=lambda t: (t.dt, t.txn_id))
            return rows_fi[-1].balance_after if rows_fi else opening
        cash = final("deposit", 410000)
        mf = final("mutual_funds", 840000)
        rd = final("recurring_deposit", 90000)
        td = final("term_deposit", 450000)
        ins = final("insurance_policies", 160000)
        cycle = cycles.get(f"cc_{m.year:04d}_{m.month:02d}", {})
        card_outstanding = max(0.0, float(cycle.get("total_amount_due") or 0) - float(cycle.get("payments_received") or 0))
        education_loan = max(0.0, 925000 - 24500 * (month_iter().index(m) + 1))
        household_emi = 42000.0 if ym >= "2026-01" else 0.0
        net = cash + mf + rd + td + ins - card_outstanding - education_loan - household_emi
        liquid = cash - card_outstanding - education_loan * 0.15 - household_emi
        status = "watch" if liquid < 250000 or net < 900000 else "healthy"
        rows.append({"month": ym, "liquid_cash": round(cash, 2), "mutual_fund_value": round(mf, 2), "rd_value": round(rd, 2), "td_value": round(td, 2), "nps_value_if_any": 0.0, "insurance_protection_value": round(ins, 2), "credit_card_outstanding": round(card_outstanding, 2), "education_loan_outstanding": round(education_loan, 2), "emi_outstanding": household_emi, "other_liabilities_if_any": 0.0, "net_worth": round(net, 2), "liquid_net_worth": round(liquid, 2), "status": status, "reason": "Assets exist, but education loan, family obligations, and limited liquid cash keep liquidity on watch."})
    return {"dataset_id": DATASET_ID, "source_type": "expected_intelligence_test_oracle", "rows": rows, "summary": rows[-1]}


def nudge_copy(tx: Tx) -> str:
    g = tx.truth
    if g.get("is_education_loan_emi"):
        return "Your education loan EMI is on track, but it must stay reserved before goal spending."
    if g.get("is_family_support"):
        return f"This ₹{tx.amount:,.0f} family support transfer reduces goal room this month."
    if g.get("is_healthcare"):
        return f"This ₹{tx.amount:,.0f} healthcare payment is essential, but it pressures the healthcare buffer."
    if g.get("is_cash_blindspot"):
        return f"This ₹{tx.amount:,.0f} cash withdrawal should be reviewed because the final use is not visible."
    if g.get("expected_nudge_type") == "safe_to_spend_watch":
        return f"This ₹{tx.amount:,.0f} UPI payment lands in a tight month; keep it within the weekly room."
    if g.get("is_credit_card_payment"):
        return "This card payment keeps discipline mostly intact, but partial-payment months need monitoring."
    return f"This ₹{tx.amount:,.0f} item is a Priya responsibility-planning signal."


def build_nudge_expected(txs: list[Tx]) -> dict[str, Any]:
    entries = []
    for tx in txs:
        if tx.truth.get("nudge_candidate"):
            entries.append({"transaction_id": tx.txn_id, "expected_nudge_type": tx.truth.get("expected_nudge_type"), "should_interrupt": bool(tx.truth.get("should_interrupt")), "surface_mode": tx.truth.get("surface_mode"), "nudge_priority": tx.truth.get("nudge_priority"), "nudge_reason": tx.truth.get("financial_health_impact") or tx.truth.get("expected_nudge_type"), "user_facing_copy_candidate": nudge_copy(tx), "copy_review_required": bool(tx.truth.get("should_interrupt")), "product_surface": "interrupt" if tx.truth.get("should_interrupt") else tx.truth.get("surface_mode"), "tone": "gentle_responsibility_oriented"})
    return {"dataset_id": DATASET_ID, "generated_at": GENERATED_AT, "source_type": "expected_intelligence_test_oracle", "copy_maturity": "testing_scaffold", "final_ux_copy": False, "notes": "Priya nudges are gentle planning signals. Interrupts are rare high-severity watch moments.", "entries": entries, "summary": {"nudge_candidates": len(entries), "interrupt_nudges": sum(1 for e in entries if e["should_interrupt"])}}


def build_device_finance_source() -> dict[str, Any]:
    return {"dataset_id": DATASET_ID, "source_type": "synthetic_device_finance_source", "status": "not_applicable", "reason": "Priya has education loan and card EMI obligations; no separate device-finance lender source is modeled for this fixture.", "sources": []}


def build_demo_identity_map() -> dict[str, Any]:
    return {"demo_identities": [
        {"phone": "8828290489", "personaId": "aarav", "displayName": "Aarav", "dataset_id": "aarav_spend_control_rash_decisions", "sourceHolderProfile": "masked", "status": "wired"},
        {"phone": "7304893952", "personaId": "priya", "displayName": "Priya", "dataset_id": DATASET_ID, "sourceHolderProfile": "masked", "status": "wired"},
    ], "unsupported_number_behavior": {"status": "unsupported_demo_number", "message": "This demo number is not supported yet. Try Aarav or Priya's demo number."}}


def build_dataset_registry() -> dict[str, Any]:
    return {"available_datasets": [
        {"dataset_id": "aarav_spend_control_rash_decisions", "persona_id": "aarav", "status": "ready"},
        {"dataset_id": DATASET_ID, "persona_id": "priya", "status": "ready"},
    ]}


def write_outputs(generated: dict[str, Any], seed: str) -> None:
    if OUTPUT_DIR.exists():
        shutil.rmtree(OUTPUT_DIR)
    OUTPUT_DIR.mkdir(parents=True)
    demo = build_demo_identity_map()
    registry = build_dataset_registry()
    write_root_json("demo_identity_map.json", demo)
    write_root_json("dataset_registry.json", registry)
    write_json("demo_identity_map.json", demo)
    write_json("dataset_registry.json", registry)
    write_json("raw_payload.json", generated["payload"])
    for name, text in generated["source_csvs"].items():
        (OUTPUT_DIR / name).write_text(text)
    write_json("credit_card_statement.json", generated["credit_card"]["statement"])
    (OUTPUT_DIR / "credit_card_transactions.csv").write_text(generated["credit_card"]["transactions_csv"])
    (OUTPUT_DIR / "credit_card_summary.csv").write_text(generated["credit_card"]["summary_csv"])
    write_json("device_finance_source.json", generated["expected"]["device_finance_source.json"])
    write_json("ground_truth.json", generated["ground_truth"])
    for name in ["income_candidates_expected.json", "recurring_candidates_expected.json", "emi_candidates_expected.json", "safe_to_spend_expected.json", "goal_risk_expected.json", "financial_health_expected.json", "net_worth_expected.json", "nudge_expected.json"]:
        write_json(name, generated["expected"][name])
    write_json("validation_report.json", {"dataset_id": DATASET_ID, "status": "pending", "summary": {"failed_check_count": 0}})
    write_json("output_manifest.json", build_manifest(seed, "pending", 0))
    for _ in range(4):
        report = validate_output(return_report=True)
        write_json("validation_report.json", report)
        write_json("output_manifest.json", build_manifest(seed, report["status"], report["summary"]["failed_check_count"]))


def write_json(name: str, obj: Any) -> None:
    (OUTPUT_DIR / name).write_text(json.dumps(obj, indent=2, sort_keys=False) + "\n")


def write_root_json(name: str, obj: Any) -> None:
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    (OUTPUT_ROOT / name).write_text(json.dumps(obj, indent=2, sort_keys=False) + "\n")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_json(name: str) -> Any:
    return json.loads((OUTPUT_DIR / name).read_text())


def read_csv_rows(name: str) -> list[dict[str, str]]:
    with open(OUTPUT_DIR / name, newline="") as f:
        return list(csv.DictReader(f))


def flatten_raw_accounts(raw: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [item["decryptedFI"]["account"] for fip in raw for item in fip.get("data", [])]


def flatten_raw_transactions(raw: list[dict[str, Any]]) -> list[tuple[str, dict[str, Any]]]:
    rows = []
    for acc in flatten_raw_accounts(raw):
        for tx in acc["transactions"]["transaction"]:
            rows.append((acc["type"], tx))
    return rows


def build_manifest(seed: str, validation_status: str, failed_check_count: int) -> dict[str, Any]:
    files = sorted(p.name for p in OUTPUT_DIR.iterdir() if p.is_file())
    row_counts = {}
    for name in files:
        if name.endswith(".csv"):
            with open(OUTPUT_DIR / name, newline="") as f:
                row_counts[name] = sum(1 for _ in csv.DictReader(f))
    raw = load_json("raw_payload.json") if (OUTPUT_DIR / "raw_payload.json").exists() else []
    raw_count = len(flatten_raw_transactions(raw)) if raw else 0
    gt_count = len(load_json("ground_truth.json").get("transactions", [])) if (OUTPUT_DIR / "ground_truth.json").exists() else 0
    account_count = Counter(acc["type"] for acc in flatten_raw_accounts(raw)) if raw else Counter()
    return {
        "dataset_id": DATASET_ID,
        "seed": seed,
        "generated_at": GENERATED_AT,
        "fixture_generated_at": GENERATED_AT,
        "data_period_start": PERIOD_START.isoformat(),
        "data_period_end": PERIOD_END.isoformat(),
        "data_as_of_date": DATA_AS_OF_DATE.isoformat(),
        "generation_command": GENERATION_COMMAND,
        "validation_command": VALIDATION_COMMAND,
        "files": files,
        "sha256": {name: ("self_hash_excluded" if name == "output_manifest.json" else "validation_report_hash_excluded" if name == "validation_report.json" else sha256(OUTPUT_DIR / name)) for name in files},
        "row_counts": row_counts,
        "transaction_counts_by_file": {"raw_payload.json": raw_count, "transactions.csv": row_counts.get("transactions.csv", 0), "ground_truth.json": gt_count, "credit_card_transactions.csv": row_counts.get("credit_card_transactions.csv", 0)},
        "account_counts_by_fi_type": dict(account_count),
        "ground_truth_count": gt_count,
        "expected_file_counts": expected_counts(),
        "validation_status": validation_status,
        "failed_check_count": failed_check_count,
        "source_layer_files": SOURCE_FILES,
        "expected_intelligence_files": EXPECTED_FILES,
        "excluded_from_hash_fields": ["output_manifest.json.sha256", "validation_report.json.sha256"],
    }


def expected_counts() -> dict[str, int]:
    counts = {}
    for name in EXPECTED_FILES:
        path = OUTPUT_DIR / name
        if not path.exists() or name in {"validation_report.json", "output_manifest.json"}:
            continue
        obj = load_json(name)
        if isinstance(obj, list):
            counts[name] = len(obj)
        elif isinstance(obj, dict):
            if "transactions" in obj:
                counts[name] = len(obj["transactions"])
            elif "entries" in obj:
                counts[name] = len(obj["entries"])
            elif "goals" in obj:
                counts[name] = len(obj["goals"])
            elif "rows" in obj:
                counts[name] = len(obj["rows"])
            else:
                counts[name] = len(obj)
    return counts


def validate_output(return_report: bool = False) -> dict[str, Any]:
    checks = []
    def add(name: str, expected: str, actual: Any, ok: bool) -> None:
        checks.append({"name": name, "expected": expected, "actual": actual, "result": "pass" if ok else "fail"})

    files = sorted(p.name for p in OUTPUT_DIR.iterdir() if p.is_file()) if OUTPUT_DIR.exists() else []
    raw = load_json("raw_payload.json") if (OUTPUT_DIR / "raw_payload.json").exists() else []
    tx_csv = read_csv_rows("transactions.csv") if (OUTPUT_DIR / "transactions.csv").exists() else []
    gt = load_json("ground_truth.json") if (OUTPUT_DIR / "ground_truth.json").exists() else {"transactions": []}
    safe = load_json("safe_to_spend_expected.json") if (OUTPUT_DIR / "safe_to_spend_expected.json").exists() else {"month_level": []}
    health = load_json("financial_health_expected.json") if (OUTPUT_DIR / "financial_health_expected.json").exists() else {}
    net = load_json("net_worth_expected.json") if (OUTPUT_DIR / "net_worth_expected.json").exists() else {"summary": {}, "rows": []}
    nudge = load_json("nudge_expected.json") if (OUTPUT_DIR / "nudge_expected.json").exists() else {"entries": []}
    stmt = load_json("credit_card_statement.json") if (OUTPUT_DIR / "credit_card_statement.json").exists() else {}
    cc_rows = read_csv_rows("credit_card_transactions.csv") if (OUTPUT_DIR / "credit_card_transactions.csv").exists() else []
    identity = load_json("demo_identity_map.json") if (OUTPUT_DIR / "demo_identity_map.json").exists() else {}
    registry = load_json("dataset_registry.json") if (OUTPUT_DIR / "dataset_registry.json").exists() else {}
    raw_txs = flatten_raw_transactions(raw) if raw else []
    raw_ids = {tx["txnId"] for _, tx in raw_txs}
    csv_ids = {r["transaction_id"] for r in tx_csv}
    gt_map = {r["transaction_id"]: r["ground_truth"] for r in gt.get("transactions", [])}
    gt_ids = set(gt_map)
    dep = [r for r in tx_csv if r.get("fi_type") == "deposit"]
    fi_types = sorted({acc["type"] for acc in flatten_raw_accounts(raw)}) if raw else []
    source_text = "\n".join((OUTPUT_DIR / name).read_text(errors="ignore") for name in SOURCE_FILES if (OUTPUT_DIR / name).exists())
    raw_source_text = (OUTPUT_DIR / "raw_payload.json").read_text(errors="ignore") if (OUTPUT_DIR / "raw_payload.json").exists() else ""
    source_key_violations = [key for key in FORBIDDEN_SOURCE_KEYS if f'"{key}"' in source_text or f",{key}," in source_text]
    narration_leaks = [term for term in FORBIDDEN_NARRATION_TERMS if term.lower() in source_text.lower()]
    local_truth = [(tid, truth) for tid, truth in gt_map.items() if truth.get("local_micro_upi_noise")]
    local_rows = [r for r in tx_csv if r["transaction_id"] in {tid for tid, _ in local_truth}]
    local_months = Counter(r["date"][:7] for r in local_rows)
    local_amounts = [float(r["amount"]) for r in local_rows]
    confidence = Counter(truth.get("confidence_expected") for _, truth in local_truth)
    local_categories = {truth.get("sub_category") for _, truth in local_truth}
    qr = [r["narration"] for r in local_rows if "QR" in r["narration"] or "BHARATPE" in r["narration"] or "PAYTM" in r["narration"]]
    person = [r["narration"] for r in local_rows if r["narration"] in {"UPI/DE/SURESH", "UPI/DE/ROHAN", "UPI/DE/NEHA", "UPI/DE/MOM", "UPI/DE/PAPA"}]
    parent_support = [g for g in gt_map.values() if g.get("is_parent_support")]
    sibling_support = [g for g in gt_map.values() if g.get("is_sibling_support")]
    edu_emi = [g for g in gt_map.values() if g.get("is_education_loan_emi")]
    cash = [g for g in gt_map.values() if g.get("is_cash_blindspot")]
    healthcare = [g for g in gt_map.values() if g.get("is_healthcare")]
    self_transfers = [g for g in gt_map.values() if g.get("is_internal_transfer")]
    interrupts = [e for e in nudge.get("entries", []) if e.get("should_interrupt")]
    final_net = net.get("summary", {})
    manifest = load_json("output_manifest.json") if (OUTPUT_DIR / "output_manifest.json").exists() else {}
    validation_report_on_disk = load_json("validation_report.json") if (OUTPUT_DIR / "validation_report.json").exists() else {}

    add("output_manifest_present", "output manifest exists", "output_manifest.json" in files, "output_manifest.json" in files)
    add("output_manifest_hashes_match", "hashes match actual files", manifest_hash_issues(manifest, files), not manifest_hash_issues(manifest, files))
    manifest_status = manifest_validation_status(manifest, validation_report_on_disk)
    add("output_manifest_validation_status_matches_validation_report", "manifest validation status matches report status", manifest_status, not manifest_status["status_mismatch"])
    add("output_manifest_failed_check_count_matches_validation_report", "manifest failed check count matches report summary", manifest_status, not manifest_status["failed_count_mismatch"])
    add("output_manifest_status_not_stale", "manifest validation status is not stale", manifest_status, not manifest_status["stale"])
    add("validation_check_actual_payloads_are_current", "manifest status check payloads reflect current top-level values", manifest_status, manifest_status["payload_current"])
    add("manifest_status_check_payload_matches_top_level_values", "manifest status check diagnostics match top-level files", manifest_status, manifest_status["payload_matches_top_level"])
    add("required_files_present", "all required files present", sorted(set(REQUIRED_FILES) - set(files)), set(REQUIRED_FILES) <= set(files))
    add("no_stale_files", "no unexpected files", sorted(set(files) - set(REQUIRED_FILES)), set(files) <= set(REQUIRED_FILES))
    add("source_files_have_no_mone_taxonomy", "source files exclude taxonomy keys", source_key_violations, not source_key_violations)
    add("source_narrations_have_no_taxonomy_leakage", "source text excludes taxonomy narration leaks", narration_leaks, not narration_leaks)
    add("source_vs_expected_boundary_passes", "source and expected layers are separated", {"source_violations": source_key_violations, "expected_files": EXPECTED_FILES}, not source_key_violations)
    add("raw_payload_has_required_fi_types", "deposit, MF, RD, TD, insurance present", fi_types, set(fi_types) >= {"deposit", "mutual_funds", "recurring_deposit", "term_deposit", "insurance_policies"})
    add("transactions_csv_matches_raw_payload", "raw and csv tx ids match", {"raw_only": list(raw_ids - csv_ids)[:5], "csv_only": list(csv_ids - raw_ids)[:5]}, raw_ids == csv_ids)
    add("ground_truth_one_to_one", "ground truth one-to-one", {"csv": len(csv_ids), "gt": len(gt_ids)}, csv_ids == gt_ids and len(gt_ids) == len(gt.get("transactions", [])))
    running_status = running_balance_status(raw, tx_csv)
    add("running_balance_reconciles", "deposit running balance nonnegative and raw matches csv", running_status, not running_status["issues"])
    add("monthly_cashflow_reconciles", "monthly cashflow matches tx csv", monthly_ok(tx_csv), monthly_ok(tx_csv) is True)
    add("mode_summary_reconciles", "mode summary matches tx csv", mode_ok(tx_csv), mode_ok(tx_csv) is True)
    mode_prefix_status = mode_narration_prefix_status(tx_csv)
    add("transaction_mode_matches_narration_prefix", "source transaction mode matches narration prefix", mode_prefix_status, not mode_prefix_status["issues"])
    add("no_upi_rows_with_ft_prefix", "UPI rows do not use FT narration prefix", mode_prefix_status, not mode_prefix_status["upi_rows_with_ft_prefix"])
    add("no_ft_rows_with_upi_prefix", "FT rows do not use UPI narration prefix", mode_prefix_status, not mode_prefix_status["ft_rows_with_upi_prefix"])
    raw_evidence = raw_money_map_evidence_status(tx_csv)
    add("lpg_transactions_present", "periodic LPG/gas payments are present", raw_evidence["lpg_transactions"], len(raw_evidence["lpg_transactions"]) >= 4)
    add("rent_component_transactions_present", "rent-related component payments are present", raw_evidence["rent_components"], len(raw_evidence["rent_components"]) >= 3)
    add("variable_electricity_present", "electricity bills vary by month", raw_evidence["electricity_amounts"], len(set(raw_evidence["electricity_amounts"])) >= 4 and max(raw_evidence["electricity_amounts"] or [0]) - min(raw_evidence["electricity_amounts"] or [0]) >= 2000)
    add("internet_mobile_topup_present", "mobile/internet topups are present", raw_evidence["internet_mobile_topups"], len(raw_evidence["internet_mobile_topups"]) >= 2)
    add("domestic_help_advance_present", "domestic help advance is present", raw_evidence["domestic_help_advances"], bool(raw_evidence["domestic_help_advances"]))
    add("emi_extra_payment_present", "loan/EMI extra payment is present", raw_evidence["emi_extra_payments"], bool(raw_evidence["emi_extra_payments"]))
    add("sip_or_rd_lumpsum_present", "fund-building topup/lumpsum is present", raw_evidence["fund_topups"], len(raw_evidence["fund_topups"]) >= 2)
    add("vehicle_service_center_cost_present", "vehicle service or repair cost is present", raw_evidence["vehicle_service"], bool(raw_evidence["vehicle_service"]))
    add("annual_subscription_due_present", "annual subscription or renewal due in demo month is present", raw_evidence["annual_renewals"], bool(raw_evidence["annual_renewals"]))
    add("needs_review_raw_signals_present", "ambiguous raw signals exist for future review", raw_evidence["needs_review"], len(raw_evidence["needs_review"]) >= 6)
    add("priya_subscriptions_present_but_not_excessive", "Priya has useful but non-chaotic subscriptions", raw_evidence["subscription_merchants"], 5 <= len(raw_evidence["subscription_merchants"]) <= 8)
    add("priya_parent_extra_support_present", "Priya has extra parent-support transfer evidence", raw_evidence["parent_extra_transfers"], bool(raw_evidence["parent_extra_transfers"]))
    add("priya_education_loan_part_payment_present", "Priya has a responsible education-loan part payment", raw_evidence["education_loan_part_payments"], bool(raw_evidence["education_loan_part_payments"]))
    add("priya_disciplined_fund_topup_present", "Priya has disciplined bonus-month fund topup evidence", raw_evidence["fund_topups"], len(raw_evidence["fund_topups"]) >= 2)
    add("priya_remains_responsibility_burdened_not_reckless", "raw hardening preserves Priya's responsibility-burden story", {"overall": health.get("overall_status"), "education_emi": len(edu_emi), "parents": len(parent_support)}, health.get("overall_status") == "Watch" and len(edu_emi) == 12 and len(parent_support) >= 12)
    add("accounts_reconcile_with_raw_payload", "accounts csv current values match raw", accounts_ok(raw), accounts_ok(raw) is True)
    add("pii_policy_holder_profile", "raw holder profile is synthetic and does not drive demo identity", "Synthetic Holder PRIYA", "Synthetic Holder PRIYA" in raw_source_text and "7304893952" not in raw_source_text)
    add("parents_support_present", "monthly parents support present", len(parent_support), len(parent_support) >= 12)
    add("sibling_support_present", "irregular sibling support present", len(sibling_support), 3 <= len(sibling_support) <= 6)
    add("family_obligation_load_present", "family obligations present", len([g for g in gt_map.values() if g.get("is_family_support")]), len([g for g in gt_map.values() if g.get("is_family_support")]) >= 16)
    add("education_loan_emi_present", "education loan EMI present", len(edu_emi), len(edu_emi) == 12)
    add("education_loan_emi_monthly_regular", "education loan EMI monthly regular", Counter(gt_tx_months(gt_map, lambda g: g.get("is_education_loan_emi"))), len(Counter(gt_tx_months(gt_map, lambda g: g.get("is_education_loan_emi")))) == 12)
    add("education_loan_emi_in_recurring_candidates", "education loan in recurring expected", "HDFC Credila", "HDFC Credila" in json.dumps(load_json("recurring_candidates_expected.json")))
    add("education_loan_emi_in_emi_candidates", "education loan in EMI expected", "education_loan_emi", "education_loan_emi" in json.dumps(load_json("emi_candidates_expected.json")))
    add("education_loan_emi_reduces_safe_to_spend", "debt pressure in safe-to-spend", [m.get("debt_commitments") for m in safe.get("month_level", [])], all(float(m.get("debt_commitments", 0)) >= 24500 for m in safe.get("month_level", [])))
    add("education_loan_emi_contributes_to_debt_pressure", "health debt pressure watch/risk", health.get("dimensions", {}).get("debt_pressure"), health.get("dimensions", {}).get("debt_pressure") in {"Watch", "Risk"})
    add("self_account_transfers_present", "self transfers present", len(self_transfers), len(self_transfers) >= 6)
    add("self_transfers_not_income", "self transfers not income", sum(1 for g in self_transfers if g.get("is_income")), all(not g.get("is_income") for g in self_transfers))
    add("local_micro_upi_variety_present", "local UPI category variety", len(local_categories), len(local_categories) >= 16)
    add("local_micro_upi_frequency_lower_than_aarav", "12-30 local UPI per month", dict(local_months), len(local_months) == 12 and all(12 <= c <= 30 for c in local_months.values()))
    add("local_micro_upi_monthly_frequency_in_target_range", "12-30 local UPI per month", dict(local_months), len(local_months) == 12 and all(12 <= c <= 30 for c in local_months.values()))
    add("local_micro_upi_amount_distribution_realistic", "most local UPI below 900 and max <= 3500", {"count": len(local_amounts), "max": max(local_amounts or [0]), "under_900": sum(1 for a in local_amounts if a <= 900)}, local_amounts and max(local_amounts) <= 3500 and sum(1 for a in local_amounts if a <= 900) / len(local_amounts) >= 0.65)
    add("local_micro_upi_has_truncated_merchants", "truncated/local shop narrations present", any("VEG" in r["narration"] or "STR" in r["narration"] or "QR" in r["narration"] for r in local_rows), any("VEG" in r["narration"] or "QR" in r["narration"] for r in local_rows))
    add("local_micro_upi_has_qr_aggregator_narrations", "QR/pay aggregator present", qr[:5], bool(qr))
    add("local_micro_upi_has_ambiguous_payees", "person-name payees present", person[:5], bool(person))
    add("local_micro_upi_has_ground_truth_categories", "local UPI hidden categories present", len(local_categories), len(local_categories) >= 16)
    add("local_micro_upi_not_all_high_confidence", "low/medium confidence cases present", dict(confidence), confidence.get("low", 0) > 0 and confidence.get("medium", 0) > 0)
    add("tagging_ambiguity_cases_present", "ambiguous cases present", confidence.get("low", 0), confidence.get("low", 0) >= 10)
    add("cash_withdrawals_present", "cash withdrawals present", len(cash), len(cash) >= 12)
    add("cash_withdrawals_marked_blindspot", "cash withdrawals marked blindspot", len(cash), all(g.get("is_cash_blindspot") for g in cash))
    add("cash_withdrawals_not_fully_known_spend", "cash confidence medium/low", Counter(g.get("confidence_expected") for g in cash), all(g.get("confidence_expected") in {"medium", "low"} for g in cash))
    add("healthcare_burden_present", "healthcare burden present", len(healthcare), len(healthcare) >= 10)
    add("insurance_policy_present_if_supported", "insurance FI present", "insurance_policies" in fi_types, "insurance_policies" in fi_types)
    add("insurance_claim_not_income_if_present", "claim not income", [g for g in gt_map.values() if g.get("is_claim")], all(not g.get("is_income") for g in gt_map.values() if g.get("is_claim")))
    add("goal_drift_caused_by_responsibilities", "goal reasons are responsibility-driven", json.dumps(load_json("goal_risk_expected.json")), "reckless" not in json.dumps(load_json("goal_risk_expected.json")).lower())
    add("multiple_goals_present", "multiple goals present", len(load_json("goal_risk_expected.json").get("goals", [])), len(load_json("goal_risk_expected.json").get("goals", [])) >= 5)
    add("goal_status_not_all_healthy", "some goal watch/risk", [g.get("status") for g in load_json("goal_risk_expected.json").get("goals", [])], any(g.get("status") in {"Watch", "Risk"} for g in load_json("goal_risk_expected.json").get("goals", [])))
    add("explainable_large_spends_not_marked_bad", "large spends are explainable, not bad/reckless", [g for g in gt_map.values() if g.get("is_explainable_large_spend")], all("reckless" not in json.dumps(g).lower() for g in gt_map.values() if g.get("is_explainable_large_spend")))
    add("net_worth_expected_file_present", "net worth file exists", (OUTPUT_DIR / "net_worth_expected.json").exists(), (OUTPUT_DIR / "net_worth_expected.json").exists())
    add("net_worth_reconciles", "net worth final reconciles with source/liabilities", net_worth_ok(final_net), net_worth_ok(final_net) is True)
    add("liquid_net_worth_watch_or_risk", "liquid net worth is watch/risk", final_net.get("status"), final_net.get("status") in {"watch", "risk"})
    add("education_loan_liability_included_in_net_worth", "education loan liability included", final_net.get("education_loan_outstanding"), float(final_net.get("education_loan_outstanding", 0)) > 500000)
    add("overall_health_watch_or_risk", "overall health Watch or Risk", health.get("overall_status"), health.get("overall_status") in {"Watch", "Risk"})
    add("financial_health_expected_present", "financial health expected present", bool(health), bool(health))
    add("responsibility_load_reflected_in_health", "responsibility load reflected", health.get("dimensions", {}).get("family_responsibility_load"), health.get("dimensions", {}).get("family_responsibility_load") == "Risk")
    add("not_reckless_like_aarav", "Priya is burdened rather than spend-drift led", json.dumps(health), "reckless" not in json.dumps(health).lower() and "responsibility" in json.dumps(health).lower())
    add("credit_card_statement_present", "credit card statement present", stmt.get("accounting_precision"), stmt.get("accounting_precision") == "scenario_grade")
    add("card_purchases_not_double_counted", "card statement linked to deposit rows", [r.get("source_reconciliation_linked_deposit_transaction_id") for r in cc_rows], all(r.get("source_reconciliation_counted_as_additional_cashflow") in {"False", False, "false"} for r in cc_rows))
    cycle_status = card_cycle_status(stmt, cc_rows)
    add("all_card_transaction_statement_cycles_exist", "all card transactions reference existing cycles", cycle_status, not cycle_status["missing_transaction_cycles"])
    add("all_emi_schedule_statement_cycles_exist", "all card EMI schedule cycles exist", cycle_status, not cycle_status["missing_emi_cycles"])
    add("card_summary_contains_all_referenced_cycles", "summary cycles cover referenced cycles", cycle_status, not cycle_status["missing_summary_cycles"])
    add("no_missing_credit_card_statement_cycles", "no card statement cycles are missing", cycle_status, not any(cycle_status[k] for k in ["missing_transaction_cycles", "missing_emi_cycles", "missing_summary_cycles"]))
    timing_status = card_payment_timing_status(stmt, gt_map, tx_csv)
    add("card_payment_dates_match_due_or_late_window", "card payments are in due/late window", timing_status, not timing_status["issues"])
    add("early_card_payments_explicitly_marked_interim", "early payments are explicit if present", timing_status, not timing_status["early_without_interim"])
    add("card_payment_timing_semantics_clear", "card payment timing semantics clear", timing_status, not timing_status["issues"] and not timing_status["early_without_interim"])
    add("card_statement_metadata_namespaced", "card statement reconciliation metadata namespaced", card_metadata_namespaced(stmt, cc_rows), card_metadata_namespaced(stmt, cc_rows) is True)
    add("credit_card_modeling_limitations_documented", "credit card limitations documented", stmt.get("modeling_limitations"), bool(stmt.get("modeling_limitations")))
    add("credit_card_not_marked_production_grade", "credit card is not production grade", stmt.get("not_for_production_accounting_rules"), stmt.get("not_for_production_accounting_rules") is True)
    add("card_cashflow_counting_policy_documented", "card cashflow policy documented", stmt.get("spend_counting_policy"), bool(stmt.get("spend_counting_policy")))
    add("card_statement_and_deposit_cashflow_semantics_clear", "hybrid card semantics explicit", stmt.get("spend_counting_policy"), stmt.get("spend_counting_policy", {}).get("count_card_purchases_as_additional_deposit_cashflow") is False)
    card_narration_status = card_source_narration_status(tx_csv)
    add("card_source_narrations_are_merchant_like", "card source narrations are merchant-like", card_narration_status, not card_narration_status["issues"])
    add("source_card_narrations_do_not_leak_ground_truth_semantics", "card source narrations avoid semantic labels", card_narration_status, not card_narration_status["semantic_leaks"])
    add("card_discipline_watch_not_extreme_risk", "card discipline watch, not extreme", health.get("dimensions", {}).get("credit_card_discipline"), health.get("dimensions", {}).get("credit_card_discipline") in {"Healthy", "Watch"})
    safe_counts = Counter(m.get("status") for m in safe.get("month_level", []))
    add("safe_to_spend_monthly_status_distribution_priya_appropriate", "2-4 risk, 6-8 watch, 1-3 healthy months", dict(safe_counts), 2 <= safe_counts.get("risk", 0) <= 4 and 6 <= safe_counts.get("watch", 0) <= 8 and 1 <= safe_counts.get("healthy", 0) <= 3)
    safe_numeric = safe_to_spend_numeric_status(safe)
    add("safe_to_spend_status_matches_numeric_value", "safe-to-spend status matches numeric capacity", safe_numeric, not safe_numeric["issues"])
    add("healthy_safe_to_spend_months_have_non_negative_capacity", "healthy months have non-negative capacity", safe_numeric, not safe_numeric["healthy_negative"])
    add("risk_safe_to_spend_months_have_material_shortfall_or_risk_event", "risk months have material shortfall or risk reason", safe_numeric, not safe_numeric["risk_without_shortfall_or_event"])
    add("watch_safe_to_spend_months_are_tight_not_deeply_negative", "watch months are tight, not deeply negative", safe_numeric, not safe_numeric["watch_deep_negative"])
    add("safe_to_spend_not_risk_every_month", "safe-to-spend is mixed, not all risk", dict(safe_counts), safe_counts.get("risk", 0) < len(safe.get("month_level", [])))
    add("financial_health_safe_to_spend_dimension_matches_monthly_pattern", "safe-to-spend dimension matches mixed monthly pattern", health.get("dimensions", {}).get("safe_to_spend"), health.get("dimensions", {}).get("safe_to_spend") == "Watch" and safe_counts.get("risk", 0) > 0 and safe_counts.get("healthy", 0) > 0)
    add("responsibility_pressure_preserved", "obligation and family pressure preserved", {"parents": len(parent_support), "education_emi": len(edu_emi), "risk_months": safe_counts.get("risk", 0)}, len(parent_support) >= 12 and len(edu_emi) == 12 and safe_counts.get("risk", 0) >= 2)
    overlabel_status = source_overlabel_status(source_text)
    add("family_support_narrations_not_overlabeled", "family support narrations avoid support labels", overlabel_status, not overlabel_status["family_terms"])
    add("source_narrations_have_no_responsibility_taxonomy_leakage", "source narrations avoid responsibility taxonomy", overlabel_status, not overlabel_status["all_terms"])
    add("parent_support_still_detectable_from_pattern_and_ground_truth", "parent support remains in ground truth", len(parent_support), len(parent_support) >= 12)
    add("self_transfer_narrations_not_income_like", "self transfer narrations are transfer-like, not income-like", overlabel_status, not overlabel_status["self_transfer_income_like"])
    add("no_macos_metadata_files_in_output_zip", "no macOS metadata files in output folder", hidden_artifacts(), not hidden_artifacts())
    add("no_hidden_packaging_artifacts", "no hidden packaging artifacts in output folder", hidden_artifacts(), not hidden_artifacts())
    period_status = data_period_status(raw, tx_csv, manifest)
    add("data_period_metadata_present", "data period metadata present", period_status, not period_status["missing"])
    add("generated_at_not_used_as_data_period_end", "generated_at is separate from data period end", period_status, period_status["generated_at"] != period_status["data_period_end"])
    add("transaction_dates_within_data_period", "all source transactions fall within data period", period_status, not period_status["out_of_period"])
    add("nudge_expected_file_present", "nudge file present", bool(nudge), bool(nudge))
    nudge_consistency = ground_truth_nudge_consistency(gt_map, nudge)
    add("non_nudge_candidates_have_no_expected_nudge_type", "non-candidate ground truth has no expected nudge type", nudge_consistency, not nudge_consistency["non_candidate_expected_type"])
    add("ground_truth_nudge_fields_consistent", "ground truth nudge fields are internally consistent", nudge_consistency, not nudge_consistency["issues"])
    add("nudge_expected_is_source_of_nudge_truth", "nudge_expected entries correspond to ground-truth candidates", nudge_consistency, not nudge_consistency["nudge_expected_without_candidate"])
    add("nudge_candidate_not_equal_interrupt", "interrupts are rare", {"entries": len(nudge.get("entries", [])), "interrupts": len(interrupts)}, len(nudge.get("entries", [])) > len(interrupts) * 5)
    add("priya_interrupt_count_reasonable", "6-14 annual interrupts", len(interrupts), 6 <= len(interrupts) <= 14)
    add("priya_nudges_gentle_and_responsibility_oriented", "nudge tone gentle", Counter(e.get("tone") for e in nudge.get("entries", [])), all(e.get("tone") == "gentle_responsibility_oriented" for e in nudge.get("entries", [])))
    add("micro_spends_not_all_interrupting", "local micro interrupts limited", len([e for e in interrupts if gt_map.get(e.get("transaction_id"), {}).get("local_micro_upi_noise")]), len([e for e in interrupts if gt_map.get(e.get("transaction_id"), {}).get("local_micro_upi_noise")]) <= max(1, int(len(local_truth) * 0.05)))
    add("interrupt_reasons_high_severity_only", "interrupt reasons are high severity", [e.get("expected_nudge_type") for e in interrupts], all(e.get("expected_nudge_type") in {"safe_to_spend_watch", "liquidity_pressure", "healthcare_buffer_pressure", "goal_drift_watch"} for e in interrupts))
    add("demo_identity_maps_priya_correctly", "Priya phone maps to Priya dataset", identity_lookup(identity, "7304893952"), identity_lookup(identity, "7304893952").get("dataset_id") == DATASET_ID)
    add("priya_not_mapped_to_aarav", "Priya not mapped to Aarav", identity_lookup(identity, "7304893952"), identity_lookup(identity, "7304893952").get("dataset_id") != "aarav_spend_control_rash_decisions")
    add("aarav_phone_still_maps_to_aarav_dataset", "Aarav still maps to Aarav", identity_lookup(identity, "8828290489"), identity_lookup(identity, "8828290489").get("dataset_id") == "aarav_spend_control_rash_decisions")
    add("unsupported_numbers_have_explicit_state", "unsupported state present", identity.get("unsupported_number_behavior"), identity.get("unsupported_number_behavior", {}).get("status") == "unsupported_demo_number")
    add("dataset_registry_priya_ready", "dataset registry has Priya ready", registry, any(d.get("dataset_id") == DATASET_ID and d.get("status") == "ready" for d in registry.get("available_datasets", [])))

    failed = [c for c in checks if c["result"] == "fail"]
    summary = {
        "dataset_id": DATASET_ID,
        "status": "pass" if not failed else "fail",
        "seed": SEED,
        "generated_at": GENERATED_AT,
        "fixture_generated_at": GENERATED_AT,
        "data_period_start": PERIOD_START.isoformat(),
        "data_period_end": PERIOD_END.isoformat(),
        "data_as_of_date": DATA_AS_OF_DATE.isoformat(),
        "total_files": len(files),
        "total_transactions": len(tx_csv),
        "deposit_transactions": len(dep),
        "asset_transactions": len([r for r in tx_csv if r.get("fi_type") != "deposit"]),
        "credit_card_transactions": len(cc_rows),
        "card_statement_cycles": len(stmt.get("statement_cycles", [])),
        "missing_card_statement_cycle_count": sum(len(cycle_status[k]) for k in ["missing_transaction_cycles", "missing_emi_cycles", "missing_summary_cycles"]),
        "local_micro_upi_count": len(local_truth),
        "cash_withdrawal_count": len(cash),
        "self_transfer_count": len(self_transfers),
        "parents_support_count": len(parent_support),
        "sibling_support_count": len(sibling_support),
        "education_loan_emi_count": len(edu_emi),
        "healthcare_spend_count": len(healthcare),
        "insurance_policy_count": 1 if "insurance_policies" in fi_types else 0,
        "goal_count": len(load_json("goal_risk_expected.json").get("goals", [])) if (OUTPUT_DIR / "goal_risk_expected.json").exists() else 0,
        "nudge_candidates": len(nudge.get("entries", [])),
        "interrupt_nudges": len(interrupts),
        "safe_to_spend_risk_months": safe_counts.get("risk", 0),
        "safe_to_spend_watch_months": safe_counts.get("watch", 0),
        "safe_to_spend_healthy_months": safe_counts.get("healthy", 0),
        "final_net_worth": final_net.get("net_worth"),
        "final_liquid_net_worth": final_net.get("liquid_net_worth"),
        "financial_health_overall_status": health.get("overall_status"),
        "failed_check_count": len(failed),
    }
    report = {"status": "pass" if not failed else "fail", "failed": [c["name"] for c in failed], "summary": summary, "checks": checks}
    if not return_report:
        print(json.dumps({"status": report["status"], "failed": report["failed"], "summary": summary}, indent=2))
    return report


def manifest_hash_issues(manifest: dict[str, Any], files: list[str]) -> list[str]:
    bad = []
    if set(manifest.get("files", [])) != set(files):
        bad.append("file_list")
    for name in files:
        expected = manifest.get("sha256", {}).get(name)
        if name == "output_manifest.json":
            ok = expected == "self_hash_excluded"
        elif name == "validation_report.json":
            ok = expected == "validation_report_hash_excluded"
        else:
            ok = expected == sha256(OUTPUT_DIR / name)
        if not ok:
            bad.append(name)
    return bad


def manifest_validation_status(manifest: dict[str, Any], report: dict[str, Any]) -> dict[str, Any]:
    manifest_status = manifest.get("validation_status")
    report_status = report.get("status")
    manifest_failed = manifest.get("failed_check_count")
    report_failed = report.get("summary", {}).get("failed_check_count")
    status_mismatch = bool(report_status) and manifest_status != report_status
    failed_count_mismatch = report_failed is not None and manifest_failed != report_failed
    stale = report_status == "pass" and report_failed == 0 and (manifest_status != "pass" or manifest_failed != 0)
    payload_matches_top_level = manifest_status == manifest.get("validation_status") and manifest_failed == manifest.get("failed_check_count") and report_status == report.get("status") and report_failed == report.get("summary", {}).get("failed_check_count")
    payload_current = payload_matches_top_level and not status_mismatch and not failed_count_mismatch and not stale
    return {
        "manifest_validation_status": manifest_status,
        "validation_report_status": report_status,
        "manifest_failed_check_count": manifest_failed,
        "validation_report_failed_check_count": report_failed,
        "status_mismatch": status_mismatch,
        "failed_count_mismatch": failed_count_mismatch,
        "stale": stale,
        "payload_current": payload_current,
        "payload_matches_top_level": payload_matches_top_level,
    }


def mode_narration_prefix_status(tx_csv: list[dict[str, str]]) -> dict[str, list[dict[str, str]]]:
    prefix_rules = {
        "UPI": ("UPI/",),
        "FT": ("FT/",),
        "NACH": ("NACH/", "ECS/", "ACH/"),
        "CARD": ("CARD/",),
        "ATM": ("ATM/",),
    }
    issues = []
    upi_rows_with_ft_prefix = []
    ft_rows_with_upi_prefix = []
    for row in tx_csv:
        if row.get("fi_type") != "deposit":
            continue
        mode = row.get("mode", "")
        narration = row.get("narration", "")
        upper = narration.upper()
        if mode in prefix_rules and not upper.startswith(prefix_rules[mode]):
            issue = {"transaction_id": row.get("transaction_id", ""), "mode": mode, "narration": narration}
            issues.append(issue)
        if mode == "UPI" and upper.startswith("FT/"):
            upi_rows_with_ft_prefix.append({"transaction_id": row.get("transaction_id", ""), "narration": narration})
        if mode == "FT" and upper.startswith("UPI/"):
            ft_rows_with_upi_prefix.append({"transaction_id": row.get("transaction_id", ""), "narration": narration})
    return {
        "issues": issues[:20],
        "upi_rows_with_ft_prefix": upi_rows_with_ft_prefix[:20],
        "ft_rows_with_upi_prefix": ft_rows_with_upi_prefix[:20],
    }


def raw_money_map_evidence_status(tx_csv: list[dict[str, str]]) -> dict[str, Any]:
    rows = [r for r in tx_csv if r.get("fi_type") == "deposit"]
    def narr(row: dict[str, str]) -> str:
        return row.get("narration", "").upper()
    def matching(*terms: str) -> list[str]:
        return [r.get("transaction_id", "") for r in rows if any(term in narr(r) for term in terms)]
    electricity_amounts = [
        float(r.get("amount", 0))
        for r in rows
        if "ELECTRICITY" in narr(r) or "BESCOM" in narr(r) or "TATA POWER" in narr(r) or "ADANI ELECTRICITY" in narr(r)
    ]
    subscription_merchants = {
        narr(r).replace("CARD/DE/", "").split("/")[0]
        for r in rows
        if r.get("mode") == "CARD" and any(term in narr(r) for term in ["ICLOUD", "GOOGLE ONE", "YOUTUBE PREMIUM", "PRIME MEMBERSHIP", "SPOTIFY", "NETFLIX", "LINKEDIN PREMIUM", "NOTION", "HEADSPACE", "CALM", "NEWSPAPER DIGITAL"])
    }
    return {
        "lpg_transactions": matching("INDANE LPG", "HP GAS", "BHARAT GAS"),
        "rent_components": matching("WATER CHARGES LANDLORD", "PARKING CHARGES", "SOCIETY MAINTENANCE", "RENT DIFFERENCE LANDLORD"),
        "electricity_amounts": electricity_amounts,
        "internet_mobile_topups": matching("DATA BOOSTER", "JIO TOPUP", "EXTRA DATA", "ROAMING PACK"),
        "domestic_help_advances": matching("HOUSEHELP ADVANCE", "COOK SALARY ADVANCE", "DRIVER ADVANCE", "CAR CLEANER ADVANCE"),
        "emi_extra_payments": matching("CREDILA PART PAYMENT", "CREDILA EXTRA EMI", "BAJAJ FINANCE EXTRA EMI", "DEVICE EMI FORECLOSURE", "APPLE EMI EXTRA PAYMENT"),
        "fund_topups": matching("MF LUMPSUM PURCHASE", "SIP TOPUP", "RD ADDITIONAL DEPOSIT", "ETF PURCHASE", "EQUITY PURCHASE", "SGB PURCHASE"),
        "vehicle_service": matching("SERVICE CENTER", "TYRE REPLACEMENT", "VEHICLE INSPECTION", "BIKE SERVICE CENTER"),
        "annual_renewals": [r.get("transaction_id", "") for r in rows if r.get("date", "").startswith("2026-05") and any(term in narr(r) for term in ["PRIME MEMBERSHIP", "HOTSTAR ANNUAL", "INSURANCE PREMIUM"])],
        "needs_review": matching("SURESH", "ROHAN", "NEHA", "PAYTMQR2819", "PHONEPEQR4381", "BHARATPE*OM SAI", "CASH WITHDRAWAL", "OWN ACCOUNT CREDIT", "OWN ACCOUNT TRANSFER", "UNKNOWN QR"),
        "subscription_merchants": sorted(subscription_merchants),
        "parent_extra_transfers": [r.get("transaction_id", "") for r in rows if any(term in narr(r) for term in ["MOM", "PAPA"]) and float(r.get("amount", 0)) >= 20000],
        "education_loan_part_payments": matching("HDFC CREDILA PART PAYMENT", "HDFC CREDILA EXTRA EMI"),
    }


def card_source_narration_status(tx_csv: list[dict[str, str]]) -> dict[str, list[dict[str, str]]]:
    forbidden = [
        "FESTIVE SALE",
        "HOME APPLIANCE",
        "FAMILY TRAIN BOOKING",
        "GOAL",
        "BUFFER",
        "RESPONSIBILITY",
        "SUPPORT",
        "DRIFT",
        "RISK",
        "SAFE_TO_SPEND",
        "NUDGE",
    ]
    allowed_prefixes = ("CARD/DE/", "FT/DE/HDFC CREDIT CARD PAYMENT")
    issues = []
    semantic_leaks = []
    for row in tx_csv:
        narration = row.get("narration", "")
        if row.get("mode") != "CARD" and "CREDIT CARD PAYMENT" not in narration:
            continue
        if not narration.startswith(allowed_prefixes):
            issues.append({"transaction_id": row.get("transaction_id", ""), "narration": narration, "issue": "not_card_or_payment_style"})
        leak_terms = [term for term in forbidden if term in narration.upper()]
        if leak_terms:
            semantic_leaks.append({"transaction_id": row.get("transaction_id", ""), "narration": narration, "terms": ",".join(leak_terms)})
    return {"issues": issues[:20], "semantic_leaks": semantic_leaks[:20]}


def card_cycle_status(stmt: dict[str, Any], cc_rows: list[dict[str, str]]) -> dict[str, list[str]]:
    statement_cycles = {c.get("statement_cycle_id") for c in stmt.get("statement_cycles", [])}
    summary_cycles = {r.get("statement_cycle_id") for r in read_csv_rows("credit_card_summary.csv")} if (OUTPUT_DIR / "credit_card_summary.csv").exists() else set()
    transaction_cycles = {r.get("statement_cycle_id") for r in cc_rows if r.get("statement_cycle_id")}
    emi_cycles = {r.get("linked_card_statement_id") for r in stmt.get("emi_schedules", []) if r.get("linked_card_statement_id")}
    referenced = transaction_cycles | emi_cycles
    return {
        "missing_transaction_cycles": sorted(transaction_cycles - statement_cycles),
        "missing_emi_cycles": sorted(emi_cycles - statement_cycles),
        "missing_summary_cycles": sorted(referenced - summary_cycles),
    }


def card_payment_timing_status(stmt: dict[str, Any], gt_map: dict[str, dict[str, Any]], tx_csv: list[dict[str, str]]) -> dict[str, Any]:
    paid_cycles = [c for c in stmt.get("statement_cycles", []) if float(c.get("payments_received") or 0) > 0]
    payments = [r for r in tx_csv if gt_map.get(r["transaction_id"], {}).get("is_credit_card_payment")]
    paid_cycles.sort(key=lambda c: c.get("due_date", ""))
    payments.sort(key=lambda r: (r["date"], r["transaction_id"]))
    issues = []
    early_without_interim = []
    for cycle, row in zip(paid_cycles, payments):
        due = datetime.fromisoformat(cycle["due_date"]).date()
        paid = datetime.fromisoformat(row["timestamp"].replace("+05:30", "")).date()
        timing = gt_map.get(row["transaction_id"], {}).get("card_payment_timing")
        if paid < due - timedelta(days=3):
            if timing not in {"pre_statement_payment", "interim_payment_before_statement_close"}:
                early_without_interim.append({"transaction_id": row["transaction_id"], "paid": paid.isoformat(), "due": due.isoformat()})
        elif paid > due + timedelta(days=7):
            issues.append({"transaction_id": row["transaction_id"], "paid": paid.isoformat(), "due": due.isoformat()})
    if len(payments) < len(paid_cycles):
        issues.append({"missing_payment_rows": len(paid_cycles) - len(payments)})
    return {"issues": issues, "early_without_interim": early_without_interim, "checked": min(len(paid_cycles), len(payments))}


def card_metadata_namespaced(stmt: dict[str, Any], cc_rows: list[dict[str, str]]) -> bool:
    if not all("generator_metadata" in tx for tx in stmt.get("transactions", [])):
        return False
    return all(any(k.startswith("source_reconciliation_") for k in row) for row in cc_rows)


def source_overlabel_status(source_text: str) -> dict[str, list[str]]:
    family_terms = [term for term in ["PARENTS SUPPORT", "SIBLING SUPPORT", "FESTIVAL SUPPORT", "PARENTS HEALTH TOPUP", "CARD BUFFER", "APPLIANCE BUFFER"] if term in source_text]
    responsibility_terms = family_terms + [term for term in ["GOAL DRIFT", "SAFE-TO-SPEND", "HEALTHCARE_BUFFER_PRESSURE"] if term in source_text.upper()]
    self_income_like = [term for term in ["OWN ACCOUNT CREDIT/CARD", "OWN ACCOUNT CREDIT/APPLIANCE", "SELF TRANSFER INVESTMENT"] if term in source_text]
    return {"family_terms": family_terms, "all_terms": responsibility_terms, "self_transfer_income_like": self_income_like}


def hidden_artifacts() -> list[str]:
    if not OUTPUT_DIR.exists():
        return []
    return sorted(p.name for p in OUTPUT_DIR.iterdir() if p.name.startswith("__MACOSX") or p.name.startswith("."))


def safe_to_spend_numeric_status(safe: dict[str, Any]) -> dict[str, list[dict[str, Any]]]:
    issues = []
    healthy_negative = []
    risk_without_shortfall_or_event = []
    watch_deep_negative = []
    for row in safe.get("month_level", []):
        month = row.get("month")
        status = row.get("status")
        value = float(row.get("actual_safe_to_spend_after_period", row.get("safe_to_spend_end", 0)))
        reason = str(row.get("reason", "")).lower()
        risk_event = any(term in reason for term in ["healthcare", "festival", "travel", "appliance", "shortfall", "pressure"])
        if status == "healthy" and value < 0:
            item = {"month": month, "value": value, "status": status}
            healthy_negative.append(item)
            issues.append(item)
        if status == "watch" and value < -50000:
            item = {"month": month, "value": value, "status": status}
            watch_deep_negative.append(item)
            issues.append(item)
        if status == "risk" and not (value < -50000 or risk_event):
            item = {"month": month, "value": value, "status": status, "reason": row.get("reason")}
            risk_without_shortfall_or_event.append(item)
            issues.append(item)
    return {
        "issues": issues,
        "healthy_negative": healthy_negative,
        "risk_without_shortfall_or_event": risk_without_shortfall_or_event,
        "watch_deep_negative": watch_deep_negative,
    }


def data_period_status(raw: list[dict[str, Any]], tx_csv: list[dict[str, str]], manifest: dict[str, Any]) -> dict[str, Any]:
    missing = []
    for field in ["fixture_generated_at", "data_period_start", "data_period_end", "data_as_of_date"]:
        if not manifest.get(field):
            missing.append(f"manifest.{field}")
    for fip in raw:
        metadata = fip.get("generator_metadata", {})
        for field in ["fixture_generated_at", "data_period_start", "data_period_end", "data_as_of_date", "seed"]:
            if not metadata.get(field):
                missing.append(f"raw_payload.{field}")
    start = date.fromisoformat(manifest.get("data_period_start", PERIOD_START.isoformat()))
    end = date.fromisoformat(manifest.get("data_period_end", PERIOD_END.isoformat()))
    out_of_period = [
        {"transaction_id": row["transaction_id"], "date": row["date"]}
        for row in tx_csv
        if not (start <= date.fromisoformat(row["date"]) <= end)
    ][:20]
    return {
        "missing": missing,
        "generated_at": manifest.get("generated_at"),
        "data_period_end": manifest.get("data_period_end"),
        "out_of_period": out_of_period,
    }


def ground_truth_nudge_consistency(gt_map: dict[str, dict[str, Any]], nudge: dict[str, Any]) -> dict[str, list[dict[str, Any]]]:
    non_candidate_expected_type = []
    issues = []
    for txn_id, truth in gt_map.items():
        if not truth.get("nudge_candidate"):
            if truth.get("expected_nudge_type") is not None:
                non_candidate_expected_type.append({"transaction_id": txn_id, "expected_nudge_type": truth.get("expected_nudge_type")})
            if truth.get("should_interrupt"):
                issues.append({"transaction_id": txn_id, "issue": "non_candidate_interrupt"})
            if truth.get("surface_mode") not in {None, "silent_signal"}:
                issues.append({"transaction_id": txn_id, "issue": "non_candidate_surface_mode", "surface_mode": truth.get("surface_mode")})
        else:
            if not truth.get("expected_nudge_type"):
                issues.append({"transaction_id": txn_id, "issue": "candidate_missing_expected_type"})
            if truth.get("should_interrupt") and truth.get("surface_mode") != "interrupt":
                issues.append({"transaction_id": txn_id, "issue": "interrupt_surface_mismatch", "surface_mode": truth.get("surface_mode")})
    nudge_expected_without_candidate = [
        {"transaction_id": entry.get("transaction_id")}
        for entry in nudge.get("entries", [])
        if not gt_map.get(entry.get("transaction_id"), {}).get("nudge_candidate")
    ]
    return {
        "non_candidate_expected_type": non_candidate_expected_type[:20],
        "issues": issues[:20],
        "nudge_expected_without_candidate": nudge_expected_without_candidate[:20],
    }


def running_balance_status(raw: list[dict[str, Any]], tx_csv: list[dict[str, str]]) -> dict[str, Any]:
    by_id = {tx["txnId"]: tx for _, tx in flatten_raw_transactions(raw)}
    issues = []
    for row in tx_csv:
        raw_tx = by_id.get(row["transaction_id"])
        if not raw_tx:
            issues.append({"type": "missing_raw", "transaction_id": row["transaction_id"]})
            continue
        if abs(float(row["balance_after"]) - float(raw_tx["currentBalance"])) > 0.01:
            issues.append({"type": "raw_csv_balance_mismatch", "transaction_id": row["transaction_id"], "csv": row["balance_after"], "raw": raw_tx["currentBalance"]})
        if len(issues) >= 10:
            return {"issues": issues}
    openings = {
        "deposit": 410000.0,
        "mutual_funds": 840000.0,
        "recurring_deposit": 90000.0,
        "term_deposit": 450000.0,
        "insurance_policies": 160000.0,
    }
    by_fi: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in tx_csv:
        by_fi[row["fi_type"]].append(row)
    for fi_type, rows in by_fi.items():
        balance = openings[fi_type]
        for row in sorted(rows, key=lambda r: (r["timestamp"], r["transaction_id"])):
            balance += float(row["amount"]) if row["direction"] == "CREDIT" else -float(row["amount"])
            if abs(balance - float(row["balance_after"])) > 0.01:
                issues.append({"type": "chronological_mismatch", "fi_type": fi_type, "transaction_id": row["transaction_id"], "timestamp": row["timestamp"], "expected": round(balance, 2), "actual": row["balance_after"], "direction": row["direction"], "amount": row["amount"]})
            if fi_type == "deposit" and balance < 0:
                issues.append({"type": "negative_deposit_balance", "transaction_id": row["transaction_id"], "timestamp": row["timestamp"], "balance": round(balance, 2)})
            if len(issues) >= 10:
                return {"issues": issues}
    return {"issues": issues}


def monthly_ok(tx_csv: list[dict[str, str]]) -> bool:
    if not (OUTPUT_DIR / "monthly_cashflow.csv").exists():
        return False
    actual = {}
    for r in tx_csv:
        if r["fi_type"] != "deposit":
            continue
        ym = r["date"][:7]
        actual.setdefault(ym, [0.0, 0.0, 0])
        if r["direction"] == "CREDIT":
            actual[ym][0] += float(r["amount"])
        else:
            actual[ym][1] += float(r["amount"])
        actual[ym][2] += 1
    for row in read_csv_rows("monthly_cashflow.csv"):
        a = actual[row["month"]]
        if abs(float(row["credits"]) - a[0]) > 0.01 or abs(float(row["debits"]) - a[1]) > 0.01 or int(row["transaction_count"]) != a[2]:
            return False
    return True


def mode_ok(tx_csv: list[dict[str, str]]) -> bool:
    return sum(1 for r in read_csv_rows("mode_spending_summary.csv")) > 0 and all(r["mode"] for r in read_csv_rows("mode_spending_summary.csv"))


def accounts_ok(raw: list[dict[str, Any]]) -> bool:
    csv_accounts = {r["account_id"]: r for r in read_csv_rows("accounts.csv")}
    for acc in flatten_raw_accounts(raw):
        row = csv_accounts.get(acc["linkedAccRef"])
        if not row or abs(float(row["current_value"]) - float(acc["summary"]["currentValue"])) > 0.01:
            return False
    return True


def gt_tx_months(gt_map: dict[str, dict[str, Any]], pred) -> list[str]:
    tx_rows = {r["transaction_id"]: r for r in read_csv_rows("transactions.csv")}
    return [tx_rows[tid]["date"][:7] for tid, g in gt_map.items() if pred(g)]


def net_worth_ok(summary: dict[str, Any]) -> bool:
    required = ["liquid_cash", "mutual_fund_value", "rd_value", "td_value", "insurance_protection_value", "credit_card_outstanding", "education_loan_outstanding", "emi_outstanding", "net_worth", "liquid_net_worth"]
    return all(k in summary for k in required) and float(summary["education_loan_outstanding"]) > 500000 and summary.get("status") in {"watch", "risk"}


def identity_lookup(identity: dict[str, Any], phone: str) -> dict[str, Any]:
    for item in identity.get("demo_identities", []):
        if item.get("phone") == phone:
            return item
    return {}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset", required=True)
    parser.add_argument("--seed", default=SEED)
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    if args.dataset != DATASET_ID:
        raise SystemExit(f"Only {DATASET_ID} is supported by this generator.")
    if args.validate_only:
        report = validate_output(return_report=False)
        raise SystemExit(0 if report["status"] == "pass" else 1)
    generated = Builder(args.seed).generate()
    write_outputs(generated, args.seed)
    report = validate_output(return_report=False)
    raise SystemExit(0 if report["status"] == "pass" else 1)


if __name__ == "__main__":
    main()
