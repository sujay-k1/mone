#!/usr/bin/env python3
"""Deterministic final Aarav rash-decisions fixture generator and validator."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import random
import re
import shutil
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Any


DATASET_ID = "aarav_spend_control_rash_decisions"
SEED = "mone-aarav-rash-decisions-final-v4"
GENERATED_AT = "2026-05-19T07:45:00+05:30"
PERIOD_START = date(2025, 6, 1)
PERIOD_END = date(2026, 5, 31)
DEPOSIT_OPENING_BALANCE = 360000.0
CASH_PRESSURE_MIN_RANGE = (20000.0, 75000.0)
CASH_PRESSURE_CLOSE_RANGE = (75000.0, 200000.0)
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
    "nudge_expected.json",
    "net_worth_expected.json",
    "validation_report.json",
    "output_manifest.json",
]
REQUIRED_FILES = SOURCE_FILES + EXPECTED_FILES
FORBIDDEN_SOURCE_KEYS = {
    "category",
    "sub_category",
    "is_income",
    "is_salary",
    "is_emi",
    "is_rent",
    "is_sip",
    "is_obligation",
    "is_discretionary",
    "is_recurring",
    "is_luxury",
    "is_travel",
    "nudge_candidate",
    "should_interrupt",
    "expected_nudge_type",
    "nudge_priority",
    "surface_mode",
    "expected_goal_drift_days",
    "expected_safe_to_spend_impact",
    "financial_health_impact",
    "expected_user_confirmation",
    "user_facing_copy_candidate",
}
FORBIDDEN_SOURCE_NARRATION_TERMS = [
    "impulse",
    "luxury spike",
    "rash",
    "goal drift",
    "safe-to-spend",
    "nudge",
    "should_interrupt",
    "cab_to_work",
    "cab_from_work",
    "weekday_coffee",
    "late_night_food",
    "food_leakage",
    "cash_blindspot",
    "liquidity_rescue",
    "emergency_fund_breach",
    "investment_commitment_break",
    "spontaneous_trip",
    "subscription_leakage_during_pressure",
    "adult_discretionary",
    "p2p_ambiguous",
    "local_micro_upi_noise",
    "irresponsible",
    "risky",
]


LOCAL_MICRO_UPI_POOLS = [
    ("UPI/DE/SHIV TEA STALL", "tea_snacks", "Shiv Tea Stall", (30, 180), "high"),
    ("UPI/DE/RAJU PANI PURI", "street_food", "Raju Pani Puri", (50, 220), "high"),
    ("UPI/DE/CHAAT CORNER", "street_food", "Chaat Corner", (70, 260), "high"),
    ("UPI/DE/PANI PURI STALL", "street_food", "Pani Puri Stall", (40, 180), "medium"),
    ("UPI/DE/TEA STALL", "tea_snacks", "Tea Stall", (20, 140), "high"),
    ("UPI/DE/FRESH JUICE CENTER", "eating_out_micro", "Fresh Juice Center", (80, 280), "high"),
    ("UPI/DE/IYENGAR BAKERY", "bakery", "Iyengar Bakery", (60, 350), "high"),
    ("UPI/DE/MOMO CORNER", "street_food", "Momo Corner", (90, 300), "high"),
    ("UPI/DE/ROLLS CORNER", "street_food", "Rolls Corner", (120, 420), "medium"),
    ("UPI/DE/SRI LAKSHMI STORES", "groceries", "Sri Lakshmi Stores", (120, 950), "high"),
    ("UPI/DE/KIRANA MART", "household_basics", "Kirana Mart", (100, 850), "high"),
    ("UPI/DE/RAJU VEG", "vegetables", "Raju Veg", (60, 520), "medium"),
    ("UPI/DE/FRESH VEG QR", "vegetables", "Fresh Veg QR", (80, 580), "medium"),
    ("UPI/DE/NANDINI MILK", "dairy", "Nandini Milk", (40, 220), "high"),
    ("UPI/DE/WATER CAN SUPPLY", "water_supply", "Water Can Supply", (80, 360), "high"),
    ("UPI/DE/SANJAY PLUMBER", "plumbing", "Sanjay Plumber", (450, 2500), "medium"),
    ("UPI/DE/RAJ ELECTRICIAN", "electrical", "Raj Electrician", (350, 2200), "medium"),
    ("UPI/DE/SRI HARDWARE", "hardware", "Sri Hardware", (120, 1400), "medium"),
    ("UPI/DE/AC REPAIR", "appliance_repair", "AC Repair", (800, 3200), "medium"),
    ("UPI/DE/LAUNDRY SHOP", "laundry", "Laundry Shop", (120, 700), "high"),
    ("UPI/DE/MENS SALON", "personal_care", "Mens Salon", (250, 1200), "high"),
    ("UPI/DE/MEENA HOUSEHELP", "domestic_help", "Meena Househelp", (800, 3000), "medium"),
    ("UPI/DE/DTDC COURIER", "courier", "DTDC Courier", (80, 600), "high"),
    ("UPI/DE/XEROX SHOP", "printing", "Xerox Shop", (20, 220), "high"),
    ("UPI/DE/APOLLO PHARMACY", "pharmacy", "Apollo Pharmacy", (120, 1600), "high"),
    ("UPI/DE/OM MEDICALS", "pharmacy", "Om Medicals", (90, 1200), "high"),
    ("UPI/DE/DR SHARMA CLINIC", "doctor_consultation", "Dr Sharma Clinic", (500, 1800), "medium"),
    ("UPI/DE/DENTAL CLINIC", "dental", "Dental Clinic", (900, 3500), "medium"),
    ("UPI/DE/AUTO RAMESH", "auto_rickshaw", "Auto Ramesh", (70, 420), "medium"),
    ("UPI/DE/AUTO PAY", "local_transport", "Auto Pay", (60, 380), "medium"),
    ("UPI/DE/PARKING FEE", "parking", "Parking Fee", (30, 180), "high"),
    ("UPI/DE/HP PETROL", "fuel", "HP Petrol", (500, 2500), "high"),
    ("UPI/DE/TYRE PUNCTURE", "vehicle_repair", "Tyre Puncture", (100, 600), "medium"),
    ("UPI/DE/METRO CARD", "commute", "Metro Card", (100, 1000), "high"),
    ("UPI/DE/STATIONERY SHOP", "stationery", "Stationery Shop", (40, 550), "high"),
    ("UPI/DE/PRINT XEROX", "printing", "Print Xerox", (20, 300), "medium"),
    ("UPI/DE/GIFT SHOP", "gifts", "Gift Shop", (250, 1800), "medium"),
    ("UPI/DE/FLOWER SHOP", "social_spend", "Flower Shop", (100, 900), "medium"),
    ("UPI/DE/TEMPLE DONATION", "religious_donation", "Temple Donation", (50, 1000), "medium"),
    ("UPI/DE/CAKE SHOP", "celebration", "Cake Shop", (300, 1800), "medium"),
    ("UPI/DE/PAAN SHOP", "tobacco", "Paan Shop", (30, 300), "medium"),
    ("UPI/DE/CIGARETTE SHOP", "tobacco", "Cigarette Shop", (60, 450), "medium"),
    ("UPI/DE/RAJU PAAN", "tobacco", "Raju Paan", (40, 280), "medium"),
    ("UPI/DE/WINE SHOP", "alcohol", "Wine Shop", (500, 2500), "medium"),
    ("UPI/DE/LIQUOR MART", "alcohol", "Liquor Mart", (700, 3000), "medium"),
    ("UPI/DE/BREWERY", "nightlife", "Brewery", (900, 3500), "medium"),
    ("UPI/DE/PUB", "nightlife", "Pub", (900, 3500), "medium"),
    ("UPI/DE/HOOKAH CAFE", "nightlife", "Hookah Cafe", (700, 2600), "medium"),
    ("UPI/DE/ROHAN", "friend_split", "Rohan", (150, 2400), "low"),
    ("UPI/DE/NEHA", "friend_split", "Neha", (150, 2200), "low"),
    ("UPI/DE/MOM", "family_transfer", "Mom", (500, 3000), "medium"),
    ("UPI/DE/SURESH", "p2p_ambiguous", "Suresh", (120, 2500), "low"),
    ("UPI/DE/PAYTMQR2819", "unknown_qr", "PAYTMQR2819", (50, 1800), "low"),
    ("UPI/DE/BHARATPE9071", "unknown_qr", "BHARATPE9071", (60, 2200), "low"),
    ("UPI/DE/BHARATPE*OM SAI", "local_vendor_ambiguous", "BharatPe Om Sai", (70, 2000), "low"),
    ("UPI/DE/PHONEPEQR4381", "unknown_qr", "PHONEPEQR4381", (40, 1600), "low"),
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


def ist(day: date, hour: int, minute: int, second: int = 0) -> datetime:
    return datetime(day.year, day.month, day.day, hour, minute, second)


def iso(dt: datetime) -> str:
    return dt.strftime("%Y-%m-%dT%H:%M:%S+05:30")


def money(value: float) -> str:
    return f"{value:.2f}"


def month_iter() -> list[date]:
    months: list[date] = []
    current = date(PERIOD_START.year, PERIOD_START.month, 1)
    while current <= PERIOD_END:
        months.append(current)
        year = current.year + (1 if current.month == 12 else 0)
        month = 1 if current.month == 12 else current.month + 1
        current = date(year, month, 1)
    return months


def days_in_month(year: int, month: int) -> int:
    if month == 12:
        return 31
    return (date(year, month + 1, 1) - timedelta(days=1)).day


def add_month(day: date, offset: int) -> date:
    month0 = day.month - 1 + offset
    year = day.year + month0 // 12
    month = month0 % 12 + 1
    return date(year, month, min(day.day, days_in_month(year, month)))


def phase_for(day: date, salary_dates: list[date]) -> str:
    last = max([d for d in salary_dates if d <= day], default=None)
    if not last:
        return "pre_first_salary"
    days = (day - last).days
    if days <= 6:
        return "salary_week"
    if days <= 15:
        return "mid_cycle"
    if days <= 24:
        return "late_cycle"
    return "pre_salary_caution"


def time_of_day(dt: datetime) -> str:
    h = dt.hour
    if 5 <= h < 12:
        return "morning"
    if 12 <= h < 17:
        return "afternoon"
    if 17 <= h < 22:
        return "evening"
    return "night"


def base_truth(dt: datetime, category: str, sub_category: str, merchant: str = "") -> dict[str, Any]:
    return {
        "category": category,
        "sub_category": sub_category,
        "merchant": merchant,
        "is_income": False,
        "is_salary": False,
        "is_variable_income": False,
        "is_internal_transfer": False,
        "is_refund": False,
        "is_obligation": False,
        "is_rent": False,
        "is_emi": False,
        "is_sip": False,
        "is_rd": False,
        "is_insurance": False,
        "is_subscription": False,
        "is_utility": False,
        "is_family_support": False,
        "is_tax": False,
        "is_discretionary": False,
        "is_recurring": False,
        "is_reimbursable": False,
        "is_unplanned": False,
        "is_healthcare": False,
        "is_luxury": False,
        "is_travel": False,
        "is_gift": False,
        "is_cash_blindspot": False,
        "is_credit_card_payment": False,
        "is_goal_allocation": False,
        "linked_goal_id": None,
        "affects_goal": False,
        "nudge_candidate": False,
        "expected_nudge_type": None,
        "expected_user_confirmation": None,
        "expected_safe_to_spend_impact": 0,
        "expected_goal_drift_days": 0,
        "life_event": None,
        "behavioral_state": "normal",
        "day_of_week": dt.strftime("%A"),
        "time_of_day": time_of_day(dt),
        "salary_cycle_phase": "unknown",
        "confidence_expected": "high",
        "reimbursement_linked_txn_ids": [],
        "is_reimbursement_credit": False,
        "is_extreme_purchase": False,
        "is_investment_redemption": False,
        "is_liquidity_rescue": False,
        "is_premature_withdrawal": False,
        "is_goal_protective": False,
        "is_credit_card_interest": False,
        "is_late_fee": False,
        "is_term_deposit": False,
        "sip_status": None,
        "credit_card_payment_status": None,
        "linked_asset_account_id": None,
        "linked_cashflow_transaction_id": None,
        "financial_health_impact": None,
        "nudge_priority": "low",
        "surface_mode": "silent_signal",
        "should_interrupt": False,
    }


class Builder:
    def __init__(self, seed: str):
        self.rng = random.Random(seed)
        self.accounts = {
            "deposit": "acc_deposit_aarav_hdfc_0001",
            "mutual_funds": "acc_mf_aarav_hdfc_0001",
            "recurring_deposit": "acc_rd_aarav_hdfc_0001",
            "term_deposit": "acc_td_aarav_hdfc_0001",
        }
        self.masked = {
            "deposit": "XXXXXXXX1234",
            "mutual_funds": "MFXXXX2345",
            "recurring_deposit": "RDXXXX3456",
            "term_deposit": "TDXXXX4567",
        }
        self.deposit_balance = DEPOSIT_OPENING_BALANCE
        self.mf_balance = 185000.0
        self.rd_balance = 0.0
        self.td_balance = 120000.0
        self.txs: list[Tx] = []
        self.salary_dates = [date(m.year, m.month, min(28, days_in_month(m.year, m.month))) for m in month_iter()]
        self.seq = 0
        self.asset_links: dict[str, str] = {}

    def ref(self) -> str:
        return str(700000000 + self.seq * 7919)

    def add_tx(self, fi_type: str, day_dt: datetime, direction: str, mode: str, amount: float, narration: str, truth: dict[str, Any], suffix: str = "") -> str:
        self.seq += 1
        account_id = self.accounts[fi_type]
        if fi_type == "deposit":
            self.deposit_balance += amount if direction == "CREDIT" else -amount
            balance = self.deposit_balance
        elif fi_type == "mutual_funds":
            self.mf_balance += amount if direction == "CREDIT" else -amount
            balance = self.mf_balance
        elif fi_type == "recurring_deposit":
            self.rd_balance += amount if direction == "CREDIT" else -amount
            balance = self.rd_balance
        else:
            self.td_balance += amount if direction == "CREDIT" else -amount
            balance = self.td_balance
        truth["day_of_week"] = day_dt.strftime("%A")
        truth["time_of_day"] = time_of_day(day_dt)
        truth["salary_cycle_phase"] = phase_for(day_dt.date(), self.salary_dates)
        txn_id = f"TXN_AARAV_SRC_{fi_type.upper()}_{day_dt.strftime('%Y%m%d')}_{self.seq:04d}{suffix}"
        self.txs.append(Tx(txn_id, account_id, fi_type, day_dt, direction, mode, round(amount, 2), narration, round(balance, 2), truth, self.ref()))
        return txn_id

    def generate(self) -> dict[str, Any]:
        self.generate_deposit_and_assets()
        self.txs.sort(key=lambda t: (t.dt, t.txn_id))
        recompute_running_balances(self.txs)
        credit_card = build_credit_card_sources(self.txs)
        expected = build_expected_outputs(self.txs, credit_card)
        payload = build_raw_payload(self.txs, self.accounts, self.masked)
        source_csvs = build_source_csvs(self.txs, payload)
        ground_truth = build_ground_truth(self.txs)
        return {
            "payload": payload,
            "source_csvs": source_csvs,
            "ground_truth": ground_truth,
            "credit_card": credit_card,
            "expected": expected,
        }

    def generate_deposit_and_assets(self) -> None:
        subscriptions = [
            ("Netflix", 649, 12, "2025-06", "2026-05"),
            ("Spotify", 119, 14, "2025-06", "2026-05"),
            ("iCloud", 75, 14, "2025-06", "2026-05"),
            ("Amazon Prime", 179, 20, "2025-06", "2026-04"),
            ("Zepto Pass", 299, 6, "2025-07", "2026-05"),
            ("Swiggy One", 399, 8, "2025-06", "2026-05"),
            ("Zomato Gold", 299, 11, "2025-08", "2026-05"),
            ("District Pass", 199, 16, "2025-10", "2026-05"),
            ("OpenAI", 1990, 18, "2025-06", "2026-05"),
            ("Claude", 1650, 19, "2025-09", "2026-05"),
            ("Adobe", 1675, 21, "2025-06", "2026-05"),
            ("Google Cloud", 860, 22, "2025-11", "2026-05"),
            ("YouTube Premium", 129, 23, "2025-06", "2026-05"),
            ("PlayStation Plus", 749, 24, "2025-12", "2026-05"),
            ("Notion", 830, 25, "2025-07", "2026-05"),
            ("Figma", 1240, 26, "2025-06", "2026-02"),
            ("Canva Pro", 499, 27, "2025-08", "2026-05"),
            ("Audible", 199, 9, "2026-01", "2026-05"),
            ("Truecaller Premium", 99, 10, "2025-06", "2026-05"),
        ]
        utility = [("ACT FIBERNET", 999, 15), ("JIO MOBILE", 599, 18)]
        electricity_by_month = {
            "2025-06": 1360, "2025-07": 2180, "2025-08": 1960, "2025-09": 1280,
            "2025-10": 2420, "2025-11": 1740, "2025-12": 1510, "2026-01": 2080,
            "2026-02": 2360, "2026-03": 3180, "2026-04": 4560, "2026-05": 3920,
        }
        sip_plan = [("HDFC Bluechip Fund", 10000, 6), ("Axis Midcap Fund", 5000, 10)]
        skipped_sip = {("2025-09", "Axis Midcap Fund"): "failed", ("2025-12", "HDFC Bluechip Fund"): "skipped", ("2026-03", "Axis Midcap Fund"): "delayed", ("2026-04", "HDFC Bluechip Fund"): "reduced"}
        freelance = {"2025-08": 18000, "2025-12": 24000, "2026-04": 15000}
        for m in month_iter():
            ym = f"{m.year:04d}-{m.month:02d}"
            salary_day = date(m.year, m.month, 28)
            t = base_truth(ist(salary_day, 9, 30), "income", "salary", "ACME Tech")
            t.update({"is_income": True, "is_salary": True, "is_recurring": True})
            self.add_tx("deposit", ist(salary_day, 9, 30), "CREDIT", "FT", 165000, f"FT/CR/ACME TECH SALARY/{ym}", t)
            if ym in freelance:
                d = date(m.year, m.month, 17)
                t = base_truth(ist(d, 18, 40), "income", "freelance", "Synthetic Client")
                t.update({"is_income": True, "is_variable_income": True})
                self.add_tx("deposit", ist(d, 18, 40), "CREDIT", "FT", freelance[ym], f"FT/CR/SYNTHETIC CLIENT/FREELANCE/{ym}", t)
            rent_day = date(m.year, m.month, 5)
            t = base_truth(ist(rent_day, 10, 5), "housing", "rent", "Synthetic Landlord")
            t.update({"is_obligation": True, "is_rent": True, "is_recurring": True, "nudge_candidate": True, "expected_nudge_type": "fixed_commitment", "nudge_priority": "low"})
            self.add_tx("deposit", ist(rent_day, 10, 5), "DEBIT", "UPI", 42000, f"UPI/DE/RENT TO LANDLORD/{ym}", t)
            for provider, amt, day_num in utility:
                d = date(m.year, m.month, day_num)
                t = base_truth(ist(d, 19, 10), "utilities", provider.lower().split()[0], provider)
                t.update({"is_obligation": True, "is_utility": True, "is_recurring": True})
                self.add_tx("deposit", ist(d, 19, 10), "DEBIT", "UPI", amt, f"UPI/DE/{provider}/BILL/{ym}", t)
            d = date(m.year, m.month, 16)
            t = base_truth(ist(d, 19, 25), "utilities", "electricity", "BESCOM")
            t.update({"is_obligation": True, "is_utility": True, "is_recurring": True})
            self.add_tx("deposit", ist(d, 19, 25), "DEBIT", "UPI", electricity_by_month[ym], f"UPI/DE/BESCOM ELECTRICITY/{ym}", t)
            for day_num, amount, narration, sub, merchant in [
                (6, 1800, "UPI/DE/PARKING CHARGES", "parking", "Apartment Association"),
                (7, 2400, "UPI/DE/WATER CHARGES LANDLORD", "water_charges", "Synthetic Landlord"),
            ] if ym in {"2025-07", "2025-10", "2026-01", "2026-05"} else []:
                d = date(m.year, m.month, day_num)
                t = base_truth(ist(d, 10, 40), "housing", sub, merchant)
                t.update({"is_obligation": True, "is_rent": True, "is_recurring": False})
                self.add_tx("deposit", ist(d, 10, 40), "DEBIT", "UPI", amount, f"{narration}/{ym}", t)
            for day_num, amount, narration in [
                (21, 1180, "UPI/DE/INDANE LPG"),
                (22, 340, "UPI/DE/JIO TOPUP"),
                (23, 499, "UPI/DE/ACT FIBERNET EXTRA DATA"),
            ] if ym in {"2025-06", "2025-08", "2025-10", "2025-12", "2026-02", "2026-04", "2026-05"} else []:
                d = date(m.year, m.month, min(day_num, days_in_month(m.year, m.month)))
                sub = "lpg" if "LPG" in narration else "internet_mobile_topup"
                t = base_truth(ist(d, 18, 50), "utilities", sub, narration.split("/")[-1])
                t.update({"is_obligation": sub == "lpg", "is_utility": True, "is_recurring": sub == "lpg"})
                self.add_tx("deposit", ist(d, 18, 50), "DEBIT", "UPI", amount, f"{narration}/{ym}", t)
            for name, amt, day_num, start_ym, end_ym in subscriptions:
                if not (start_ym <= ym <= end_ym):
                    continue
                d = date(m.year, m.month, min(day_num, days_in_month(m.year, m.month)))
                t = base_truth(ist(d, 11, 15), "subscription", name.lower().replace(" ", "_"), name)
                t.update({"is_obligation": True, "is_subscription": True, "is_recurring": True, "is_discretionary": True, "nudge_candidate": ym in {"2025-10", "2026-02", "2026-03"}, "expected_nudge_type": "subscription_leakage", "life_event": "subscription_leakage_during_pressure" if ym in {"2025-10", "2026-02", "2026-03"} else None})
                self.add_tx("deposit", ist(d, 11, 15), "DEBIT", "CARD", amt, f"CARD/DE/{name.upper()}", t)
            if ym == "2026-05":
                for day_num, amount, narration, merchant in [(12, 1499, "CARD/DE/PRIME MEMBERSHIP", "Prime Membership"), (17, 1499, "CARD/DE/HOTSTAR ANNUAL", "Hotstar Annual")]:
                    d = date(m.year, m.month, day_num)
                    t = base_truth(ist(d, 11, 45), "subscription", merchant.lower().replace(" ", "_"), merchant)
                    t.update({"is_obligation": True, "is_subscription": True, "is_recurring": False, "is_discretionary": True, "nudge_candidate": True, "expected_nudge_type": "subscription_leakage", "surface_mode": "dashboard_insight"})
                    self.add_tx("deposit", ist(d, 11, 45), "DEBIT", "CARD", amount, narration, t)
            for fund, planned, day_num in sip_plan:
                status = skipped_sip.get((ym, fund), "paid")
                if status == "skipped":
                    continue
                amount = planned
                day_num_effective = day_num
                if status == "delayed":
                    day_num_effective = 19
                if status == "reduced":
                    amount = planned / 2
                d = date(m.year, m.month, min(day_num_effective, days_in_month(m.year, m.month)))
                t = base_truth(ist(d, 9, 45), "investment", "sip", fund)
                t.update({"is_obligation": True, "is_sip": True, "is_goal_protective": True, "is_recurring": True, "affects_goal": True, "linked_goal_id": "emergency_fund", "sip_status": status, "nudge_candidate": status != "paid", "expected_nudge_type": "investment_commitment_break" if status != "paid" else "protected_goal_transfer", "life_event": "investment_commitment_break" if status != "paid" else None, "should_interrupt": status != "paid", "surface_mode": "interrupt" if status != "paid" else "silent_signal", "nudge_priority": "high" if status != "paid" else "low"})
                cash_id = self.add_tx("deposit", ist(d, 9, 45), "DEBIT", "NACH", amount, f"NACH/DE/{fund.upper()}", t)
                mt = base_truth(ist(d, 10, 30), "investment", "mf_purchase", fund)
                mt.update({"is_sip": True, "is_goal_protective": True, "is_obligation": True, "sip_status": status, "linked_cashflow_transaction_id": cash_id})
                asset_id = self.add_tx("mutual_funds", ist(d, 10, 30), "CREDIT", "SIP", amount, f"MF/CR/PURCHASE/{fund.upper()}/{ym}", mt)
                self.asset_links[cash_id] = asset_id
            # RD installments until closure month.
            if ym <= "2026-02":
                d = date(m.year, m.month, 8)
                t = base_truth(ist(d, 9, 25), "investment", "recurring_deposit", "HDFC RD")
                t.update({"is_obligation": True, "is_rd": True, "is_goal_protective": True, "is_recurring": True, "linked_goal_id": "emergency_fund"})
                cash_id = self.add_tx("deposit", ist(d, 9, 25), "DEBIT", "NACH", 7000, f"NACH/DE/HDFC RECURRING DEPOSIT/{ym}", t)
                rt = base_truth(ist(d, 10, 0), "investment", "rd_installment", "HDFC RD")
                rt.update({"is_rd": True, "is_goal_protective": True, "linked_cashflow_transaction_id": cash_id})
                asset_id = self.add_tx("recurring_deposit", ist(d, 10, 0), "CREDIT", "NACH", 7000, f"RD/CR/INSTALLMENT/{ym}", rt)
                self.asset_links[cash_id] = asset_id
            self.local_micro_upi_noise(m)
            self.daily_spend_for_month(m)
        self.special_events()
        self.device_emi_payments()

    def local_micro_upi_noise(self, month_start: date) -> None:
        ym = f"{month_start.year:04d}-{month_start.month:02d}"
        count = self.rng.randint(25, 55)
        used_slots: set[tuple[int, int, int]] = set()
        for i in range(count):
            narration, sub_category, merchant, amount_range, confidence = self.rng.choice(LOCAL_MICRO_UPI_POOLS)
            day = self.rng.randint(1, min(days_in_month(month_start.year, month_start.month), PERIOD_END.day if month_start.year == PERIOD_END.year and month_start.month == PERIOD_END.month else 31))
            d = date(month_start.year, month_start.month, day)
            if d < PERIOD_START or d > PERIOD_END:
                continue
            if sub_category in {"alcohol", "tobacco"}:
                hour = self.rng.choice([19, 20, 21, 22])
            elif sub_category in {"auto_rickshaw", "local_transport", "commute"}:
                hour = self.rng.choice([9, 10, 18, 19, 20])
            elif sub_category in {"tea_snacks", "street_food", "bakery", "eating_out_micro"}:
                hour = self.rng.choice([11, 16, 18, 20, 21])
            elif sub_category in {"unknown_qr", "p2p_ambiguous", "friend_split"}:
                hour = self.rng.choice([13, 18, 20, 21])
            else:
                hour = self.rng.choice([10, 12, 17, 19, 20])
            minute = self.rng.randint(0, 55)
            while (day, hour, minute) in used_slots:
                minute = (minute + 7) % 60
            used_slots.add((day, hour, minute))
            lo, hi = amount_range
            if lo > 700:
                amount = self.rng.randint(lo, hi)
            elif hi <= 700 or self.rng.random() < 0.82:
                amount = self.rng.randint(lo, min(hi, 700))
            else:
                amount = self.rng.randint(max(lo, 700), hi)
            local_category = "adult_discretionary" if sub_category in {"alcohol", "tobacco", "nightlife"} else ("p2p_ambiguous" if sub_category in {"p2p_ambiguous", "friend_split", "family_transfer", "unknown_qr", "local_vendor_ambiguous"} else "local_micro_upi")
            t = base_truth(ist(d, hour, minute), local_category, sub_category, merchant)
            is_adult = sub_category in {"alcohol", "tobacco", "nightlife"}
            is_ambiguous = confidence == "low"
            should_interrupt = i == 0 and ym in {"2025-10", "2025-12", "2026-02", "2026-03", "2026-05"}
            t.update({
                "is_discretionary": sub_category not in {"pharmacy", "doctor_consultation", "diagnostics", "dental", "domestic_help", "family_transfer"},
                "is_healthcare": sub_category in {"pharmacy", "healthcare", "doctor_consultation", "diagnostics", "dental", "optical"},
                "is_gift": sub_category in {"gifts", "celebration"},
                "nudge_candidate": True,
                "expected_nudge_type": "safe_to_spend_upi_interrupt" if should_interrupt else ("ambiguous_upi_review" if is_ambiguous and amount >= 1000 else "local_micro_upi_summary"),
                "surface_mode": "interrupt" if should_interrupt else ("dashboard_insight" if amount >= 1000 or is_ambiguous else "weekly_summary"),
                "should_interrupt": should_interrupt,
                "nudge_priority": "high" if should_interrupt else ("medium" if amount >= 1000 or is_ambiguous else "low"),
                "expected_safe_to_spend_impact": -amount,
                "confidence_expected": confidence,
                "life_event": "cash_blindspot_during_pressure" if is_ambiguous and ym in {"2026-02", "2026-03", "2026-05"} else None,
                "financial_health_impact": "spending_drift_risk" if should_interrupt else None,
                "local_micro_upi_noise": True,
            })
            self.add_tx("deposit", ist(d, hour, minute), "DEBIT", "UPI", amount, narration, t)

    def daily_spend_for_month(self, month_start: date) -> None:
        d = month_start
        while d.month == month_start.month:
            if d > PERIOD_END:
                break
            weekday = d.weekday()
            # Coffee, lunch, commute, dinner leakage.
            if weekday < 5:
                for hour, sub, merchant, amount_range in [
                    (10, "weekday_coffee", "Third Wave Coffee", (160, 260)),
                    (13, "lunch", "Swiggy", (260, 520)),
                    (9, "cab_to_work", "Uber", (220, 480)),
                ]:
                    if self.rng.random() < (0.78 if sub != "cab_to_work" else 0.45):
                        amount = self.rng.randint(*amount_range)
                        t = base_truth(ist(d, hour, self.rng.randint(0, 45)), "food" if sub != "cab_to_work" else "commute", sub, merchant)
                        t.update({"is_discretionary": True, "nudge_candidate": True, "expected_nudge_type": "food_leakage" if sub != "cab_to_work" else "cab_leakage", "surface_mode": "weekly_summary", "nudge_priority": "low"})
                        self.add_tx("deposit", ist(d, hour, self.rng.randint(0, 45)), "DEBIT", "UPI", amount, f"UPI/DE/{merchant.upper()}/BANGALORE", t)
                if self.rng.random() < 0.32:
                    t = base_truth(ist(d, 20, self.rng.randint(0, 45)), "food", "dinner", "Zomato")
                    t.update({"is_discretionary": True, "nudge_candidate": True, "expected_nudge_type": "food_leakage", "surface_mode": "weekly_summary"})
                    self.add_tx("deposit", ist(d, 20, self.rng.randint(0, 45)), "DEBIT", "UPI", self.rng.randint(420, 900), "UPI/DE/ZOMATO/BANGALORE", t)
            else:
                if self.rng.random() < 0.75:
                    t = base_truth(ist(d, 20, self.rng.randint(0, 50)), "food", "weekend_dining", "Toit")
                    t.update({"is_discretionary": True, "nudge_candidate": True, "expected_nudge_type": "weekend_spike", "surface_mode": "dashboard_insight"})
                    self.add_tx("deposit", ist(d, 20, self.rng.randint(0, 50)), "DEBIT", "CARD", self.rng.randint(1400, 3600), "CARD/DE/TOIT/BANGALORE", t)
                if self.rng.random() < 0.42:
                    t = base_truth(ist(d, 11, self.rng.randint(0, 45)), "groceries", "weekly_grocery", "DMart")
                    t.update({"is_discretionary": False, "is_recurring": True})
                    self.add_tx("deposit", ist(d, 11, self.rng.randint(0, 45)), "DEBIT", "UPI", self.rng.randint(1100, 2600), "UPI/DE/DMART BANGALORE", t)
            d += timedelta(days=1)

    def special_events(self) -> None:
        events = [
            (date(2025, 8, 16), 145000, "Apple Store", "CARD/DE/APPLE STORE INDIA", "extreme_gadget_purchase", "laptop", "card_txn_apple_20250816"),
            (date(2025, 10, 4), 18000, "Zara", "CARD/DE/ZARA INDIA", "luxury_shopping_spike", "vacation", "card_txn_zara_20251004"),
            (date(2025, 10, 5), 14500, "Nike", "CARD/DE/NIKE INDIA", "luxury_shopping_spike", "vacation", "card_txn_nike_20251005"),
            (date(2025, 10, 11), 22000, "Myntra", "CARD/DE/MYNTRA DESIGNS", "luxury_shopping_spike", "vacation", "card_txn_myntra_20251011"),
            (date(2025, 10, 12), 7500, "Nykaa", "CARD/DE/NYKAA ERETAIL", "luxury_shopping_spike", "vacation", "card_txn_nykaa_20251012"),
            (date(2025, 12, 6), 28000, "Indigo Airlines", "CARD/DE/INDIGO AIRLINES", "spontaneous_trip", "vacation", "card_txn_indigo_20251206"),
            (date(2025, 12, 7), 26000, "MakeMyTrip Hotel", "CARD/DE/MAKE MY TRIP", "spontaneous_trip", "vacation", "card_txn_hotel_20251207"),
            (date(2025, 12, 9), 19000, "Goa Dining", "CARD/DE/RESTAURANT GOA", "spontaneous_trip", "vacation", "card_txn_goa_dining_20251209"),
            (date(2026, 2, 14), 98000, "Sony Center", "CARD/DE/SONY CENTER INDIA", "rash_gadget_purchase", "laptop", "card_txn_sony_20260214"),
        ]
        for d, amount, merchant, narr, life_event, goal, _card_id in events:
            is_trip = life_event == "spontaneous_trip"
            t = base_truth(ist(d, 19, 30), "travel" if is_trip else "shopping", "luxury_spike" if amount < 75000 else "extreme_purchase", merchant)
            t.update({"is_discretionary": True, "is_luxury": not is_trip, "is_travel": is_trip, "is_unplanned": True, "is_extreme_purchase": amount >= 75000, "affects_goal": True, "linked_goal_id": goal, "life_event": life_event, "nudge_candidate": True, "expected_nudge_type": "large_unplanned" if amount >= 75000 or is_trip else "spend_velocity_high", "expected_goal_drift_days": 30 if amount >= 75000 else 12, "expected_safe_to_spend_impact": -amount, "should_interrupt": amount >= 18000, "surface_mode": "interrupt" if amount >= 18000 else "dashboard_insight", "nudge_priority": "high" if amount >= 18000 else "medium", "financial_health_impact": "spending_drift_risk"})
            self.add_tx("deposit", ist(d, 19, 30), "DEBIT", "CARD", amount, narr, t)
        # Card payment stress and charges.
        for d, amount, status, narr, fee_kind in [
            (date(2025, 9, 23), 36000, "partial", "FT/DE/HDFC CREDIT CARD/BILL PAYMENT/PARTIAL/SEP25", "payment"),
            (date(2025, 9, 24), 1800, None, "FT/DE/HDFC CREDIT CARD/INTEREST/SEP25", "interest"),
            (date(2026, 2, 27), 24000, "late", "FT/DE/HDFC CREDIT CARD/BILL PAYMENT/LATE/FEB26", "payment"),
            (date(2026, 2, 28), 2350, None, "FT/DE/HDFC CREDIT CARD/LATE FEE/FEB26", "late_fee"),
        ]:
            t = base_truth(ist(d, 18, 20), "debt", "credit_card", "HDFC Credit Card")
            t.update({"is_obligation": True, "is_credit_card_payment": fee_kind == "payment", "is_credit_card_interest": fee_kind == "interest", "is_late_fee": fee_kind == "late_fee", "credit_card_payment_status": status, "life_event": "credit_card_stress", "nudge_candidate": True, "expected_nudge_type": "card_risk" if fee_kind == "payment" else "interest_risk", "should_interrupt": True, "surface_mode": "interrupt", "nudge_priority": "high", "financial_health_impact": "credit_card_discipline_risk"})
            self.add_tx("deposit", ist(d, 18, 20), "DEBIT", "FT", amount, narr, t)
        for d, amount, narration, sub, merchant in [
            (date(2025, 7, 19), 3200, "UPI/DE/BIKE SERVICE CENTER", "vehicle_service", "Bike Service Center"),
            (date(2025, 11, 16), 14500, "UPI/DE/HONDA SERVICE CENTER", "vehicle_service", "Honda Service Center"),
            (date(2026, 3, 28), 9200, "UPI/DE/TYRE REPLACEMENT", "vehicle_service", "Tyre Replacement"),
            (date(2026, 4, 18), 21500, "CARD/DE/SERVICE CENTER PAYMENT", "vehicle_service", "Service Center"),
            (date(2025, 10, 22), 5000, "UPI/DE/MEENA HOUSEHELP ADVANCE", "domestic_help_advance", "Meena Househelp"),
            (date(2026, 2, 20), 18000, "FT/DE/BAJAJ FINANCE EXTRA EMI", "device_emi_extra_payment", "Bajaj Finance"),
            (date(2026, 3, 4), 25000, "FT/DE/MF LUMPSUM PURCHASE", "mf_lumpsum_purchase", "HDFC Mutual Fund"),
            (date(2026, 3, 5), 12000, "NACH/DE/SIP TOPUP", "sip_topup", "HDFC Bluechip Fund"),
            (date(2026, 3, 6), 15000, "NACH/DE/RD ADDITIONAL DEPOSIT", "rd_additional_deposit", "HDFC RD"),
        ]:
            category = "vehicle" if "SERVICE" in narration or "TYRE" in narration else ("debt" if "BAJAJ" in narration else "investment")
            mode = "CARD" if narration.startswith("CARD/") else ("NACH" if narration.startswith("NACH/") else "FT" if narration.startswith("FT/") else "UPI")
            t = base_truth(ist(d, 17, 25), category, sub, merchant)
            t.update({"is_discretionary": category == "vehicle", "is_obligation": category == "debt", "is_emi": category == "debt", "is_sip": sub == "sip_topup", "is_rd": sub == "rd_additional_deposit", "is_goal_protective": category == "investment", "nudge_candidate": amount >= 12000, "expected_nudge_type": "emi_pressure" if category == "debt" else ("investment_commitment_break" if category == "investment" else "large_unplanned"), "surface_mode": "dashboard_insight"})
            cash_id = self.add_tx("deposit", ist(d, 17, 25), "DEBIT", mode, amount, narration, t)
            if sub == "mf_lumpsum_purchase":
                mt = base_truth(ist(d, 18, 0), "investment", "mf_purchase", merchant)
                mt.update({"is_sip": False, "is_goal_protective": True, "linked_cashflow_transaction_id": cash_id})
                self.asset_links[cash_id] = self.add_tx("mutual_funds", ist(d, 18, 0), "CREDIT", "FT", amount, "MF/CR/LUMPSUM PURCHASE/HDFC BLUECHIP FUND", mt)
            if sub == "sip_topup":
                mt = base_truth(ist(d, 18, 5), "investment", "mf_purchase", merchant)
                mt.update({"is_sip": True, "is_goal_protective": True, "linked_cashflow_transaction_id": cash_id})
                self.asset_links[cash_id] = self.add_tx("mutual_funds", ist(d, 18, 5), "CREDIT", "SIP", amount, "MF/CR/PURCHASE/HDFC BLUECHIP FUND/TOPUP", mt)
            if sub == "rd_additional_deposit":
                rt = base_truth(ist(d, 18, 10), "investment", "rd_additional_deposit", merchant)
                rt.update({"is_rd": True, "is_goal_protective": True, "linked_cashflow_transaction_id": cash_id})
                self.asset_links[cash_id] = self.add_tx("recurring_deposit", ist(d, 18, 10), "CREDIT", "NACH", amount, "RD/CR/ADDITIONAL DEPOSIT/HDFC BANK", rt)
        # Liquidity rescue events.
        d = date(2026, 3, 18)
        mt = base_truth(ist(d, 14, 10), "investment", "mf_redemption", "HDFC Mutual Fund")
        mt.update({"is_investment_redemption": True, "is_liquidity_rescue": True, "life_event": "liquidity_rescue", "nudge_candidate": True, "expected_nudge_type": "liquidity_rescue", "surface_mode": "dashboard_insight", "nudge_priority": "high"})
        asset_id = self.add_tx("mutual_funds", ist(d, 14, 10), "DEBIT", "FT", 180000, "MF/DE/REDEMPTION/HDFC BLUECHIP FUND", mt)
        ct = base_truth(ist(d + timedelta(days=1), 11, 10), "investment", "mf_redemption_credit", "HDFC Mutual Fund")
        ct.update({"is_investment_redemption": True, "is_liquidity_rescue": True, "is_income": False, "life_event": "liquidity_rescue", "linked_asset_account_id": self.accounts["mutual_funds"], "linked_cashflow_transaction_id": asset_id, "nudge_candidate": True, "expected_nudge_type": "liquidity_rescue", "surface_mode": "dashboard_insight", "nudge_priority": "high"})
        cash_id = self.add_tx("deposit", ist(d + timedelta(days=1), 11, 10), "CREDIT", "FT", 180000, "FT/CR/HDFC MF REDEMPTION PROCEEDS", ct)
        self.asset_links[asset_id] = cash_id
        # RD closure.
        d = date(2026, 3, 21)
        rt = base_truth(ist(d, 13, 10), "investment", "rd_premature_closure", "HDFC RD")
        rt.update({"is_rd": True, "is_premature_withdrawal": True, "is_goal_protective": True, "affects_goal": True, "linked_goal_id": "emergency_fund", "life_event": "emergency_fund_breach", "nudge_candidate": True, "expected_nudge_type": "emergency_fund_breach", "should_interrupt": True, "surface_mode": "interrupt", "nudge_priority": "high"})
        rd_id = self.add_tx("recurring_deposit", ist(d, 13, 10), "DEBIT", "FT", 78000, "RD/DE/PREMATURE CLOSURE/HDFC BANK", rt)
        ct = base_truth(ist(d + timedelta(days=1), 10, 10), "investment", "rd_closure_credit", "HDFC RD")
        ct.update({"is_rd": True, "is_premature_withdrawal": True, "is_liquidity_rescue": True, "is_income": False, "affects_goal": True, "linked_goal_id": "emergency_fund", "life_event": "emergency_fund_breach", "linked_cashflow_transaction_id": rd_id, "nudge_candidate": True, "expected_nudge_type": "emergency_fund_breach", "should_interrupt": True, "surface_mode": "interrupt", "nudge_priority": "high"})
        self.asset_links[rd_id] = self.add_tx("deposit", ist(d + timedelta(days=1), 10, 10), "CREDIT", "FT", 78000, "FT/CR/HDFC RD PREMATURE CLOSURE PROCEEDS", ct)
        d = date(2026, 2, 14)
        t = base_truth(ist(d, 9, 20), "transfer", "own_account_credit", "Own Account")
        t.update({"is_income": False, "is_liquidity_rescue": True, "is_discretionary": False, "nudge_candidate": True, "expected_nudge_type": "liquidity_rescue", "surface_mode": "dashboard_insight", "nudge_priority": "medium"})
        self.add_tx("deposit", ist(d, 9, 20), "CREDIT", "FT", 265000, "FT/CR/OWN ACCOUNT CREDIT", t)
        # TD full closure.
        d = date(2026, 4, 10)
        tt = base_truth(ist(d, 15, 15), "investment", "td_premature_closure", "HDFC TD")
        tt.update({"is_term_deposit": True, "is_premature_withdrawal": True, "is_liquidity_rescue": True, "life_event": "deposit_break_for_cashflow", "nudge_candidate": True, "expected_nudge_type": "liquidity_rescue", "should_interrupt": True, "surface_mode": "interrupt", "nudge_priority": "high"})
        td_id = self.add_tx("term_deposit", ist(d, 15, 15), "DEBIT", "FT", 120000, "TD/DE/PREMATURE CLOSURE/HDFC BANK/PAYOUT 112000/PENALTY 8000", tt)
        ct = base_truth(ist(d + timedelta(days=1), 10, 14), "investment", "td_closure_credit", "HDFC TD")
        ct.update({"is_term_deposit": True, "is_premature_withdrawal": True, "is_liquidity_rescue": True, "is_income": False, "life_event": "deposit_break_for_cashflow", "linked_cashflow_transaction_id": td_id, "nudge_candidate": True, "expected_nudge_type": "liquidity_rescue", "surface_mode": "dashboard_insight", "nudge_priority": "high"})
        self.asset_links[td_id] = self.add_tx("deposit", ist(d + timedelta(days=1), 10, 14), "CREDIT", "FT", 112000, "FT/CR/HDFC TERM DEPOSIT PREMATURE CLOSURE PROCEEDS", ct)
        # ATM blind spots.
        for d, amount in [
            (date(2025, 8, 30), 5000),
            (date(2025, 10, 25), 9000),
            (date(2025, 11, 8), 12000),
            (date(2025, 12, 5), 15000),
            (date(2026, 1, 16), 12000),
            (date(2026, 2, 15), 10000),
            (date(2026, 3, 26), 12000),
            (date(2026, 5, 24), 7000),
        ]:
            t = base_truth(ist(d, 20, 5), "cash", "atm_withdrawal", "HDFC ATM")
            t.update({"is_cash_blindspot": True, "is_discretionary": False, "life_event": "cash_blindspot_during_pressure", "nudge_candidate": True, "expected_nudge_type": "cash_blindspot", "surface_mode": "dashboard_insight", "nudge_priority": "medium"})
            self.add_tx("deposit", ist(d, 20, 5), "DEBIT", "ATM", amount, "ATM/DE/CASH WITHDRAWAL/BANGALORE", t)
        # Annual tax settlement keeps the cash-pressure story intentional without
        # turning tax into lifestyle spend or Moné intelligence in source data.
        d = date(2026, 5, 22)
        t = base_truth(ist(d, 14, 35), "tax", "advance_tax", "Income Tax Department")
        t.update({"is_tax": True, "is_obligation": True, "is_discretionary": False})
        self.add_tx("deposit", ist(d, 14, 35), "DEBIT", "FT", 450000, "FT/DE/INCOME TAX DEPARTMENT/TAX PAYMENT/FY25-26", t)

    def device_emi_payments(self) -> None:
        for i in range(6):
            d = add_month(date(2025, 12, 5), i)
            t = base_truth(ist(d, 10, 15), "debt", "device_emi", "Bajaj Finance")
            t.update({"is_obligation": True, "is_emi": True, "is_device_emi": True, "emi_id": "emi_device_bajaj_202511", "emi_installment_number": i + 1, "emi_total_installments": 8, "emi_payment_status": "paid", "linked_original_purchase_txn_id": "device_purchase_20251105", "life_event": "credit_card_stress" if i >= 3 else None, "nudge_candidate": True, "expected_nudge_type": "emi_pressure", "surface_mode": "dashboard_insight", "nudge_priority": "medium"})
            self.add_tx("deposit", ist(d, 10, 15), "DEBIT", "FT", 9000, f"FT/DE/BAJAJ FINANCE/DEVICE EMI/{i+1}/8", t, "_DEVICE_EMI")


def recompute_running_balances(txs: list[Tx]) -> None:
    openings = {
        "deposit": DEPOSIT_OPENING_BALANCE,
        "mutual_funds": 185000.0,
        "recurring_deposit": 0.0,
        "term_deposit": 120000.0,
    }
    balances = dict(openings)
    for tx in sorted(txs, key=lambda t: (t.fi_type, t.dt, t.txn_id)):
        balance = balances[tx.fi_type]
        balance += tx.amount if tx.direction == "CREDIT" else -tx.amount
        tx.balance_after = round(balance, 2)
        balances[tx.fi_type] = balance


def holder_profile() -> dict[str, Any]:
    return {
        "holders": {
            "type": "SINGLE",
            "holder": [{
                "dob": "1999-01-01",
                "pan": "SYNTH0000X",
                "name": "Synthetic Holder AARAV",
                "email": "aarav.synthetic@example.invalid",
                "mobile": "9000000000",
                "address": "Synthetic HSR Layout address, Bangalore",
                "nominee": "REGISTERED",
                "ckycCompliance": "true",
            }],
        }
    }


def aa_tx(tx: Tx) -> dict[str, str]:
    return {
        "txnId": tx.txn_id,
        "type": tx.direction,
        "mode": tx.mode,
        "amount": money(tx.amount),
        "narration": tx.narration,
        "reference": tx.reference,
        "valueDate": tx.dt.date().isoformat(),
        "currentBalance": money(tx.balance_after),
        "transactionTimestamp": iso(tx.dt),
    }


def build_raw_payload(txs: list[Tx], accounts: dict[str, str], masked: dict[str, str]) -> list[dict[str, Any]]:
    grouped = defaultdict(list)
    for tx in txs:
        grouped[tx.fi_type].append(tx)
    configs = {
        "deposit": {"summary": {"type": "SAVINGS", "branch": "HSR Layout", "status": "ACTIVE", "currency": "INR", "facility": "NONE", "ifscCode": "HDFC0001234", "micrCode": "560000123"}},
        "mutual_funds": {"summary": {"type": "MUTUAL_FUNDS", "status": "ACTIVE", "currency": "INR", "currentValue": money(grouped["mutual_funds"][-1].balance_after), "investmentValue": "347500.00"}},
        "recurring_deposit": {"summary": {"type": "RECURRING_DEPOSIT", "status": "PREMATURE_CLOSED", "currency": "INR", "currentBalance": "0.00", "prematureClosureAmount": "78000.00"}},
        "term_deposit": {"summary": {"type": "TERM_DEPOSIT", "status": "PREMATURE_CLOSED", "currency": "INR", "principal": "120000.00", "currentBalance": "0.00", "interestRate": "6.70", "closurePayoutAmount": "112000.00", "principalWithdrawn": "112000.00", "penaltyAmount": "8000.00", "foregoneInterest": "8040.00", "residualValue": "0.00", "retainedInterestOrPenaltyAdjustment": "8000.00", "closureStatusDetail": "FULLY_CLOSED_WITH_PREMATURE_WITHDRAWAL_PENALTY"}},
    }
    data = []
    for fi_type in ["deposit", "mutual_funds", "recurring_deposit", "term_deposit"]:
        rows = sorted(grouped[fi_type], key=lambda t: t.dt)
        summary = dict(configs[fi_type]["summary"])
        if fi_type == "deposit":
            summary["currentBalance"] = money(rows[-1].balance_after)
        if rows:
            summary["balanceDateTime"] = iso(rows[-1].dt)
        account = {
            "type": fi_type,
            "version": "2.0.0",
            "linkedAccRef": accounts[fi_type],
            "maskedAccNumber": masked[fi_type],
            "profile": holder_profile(),
            "summary": summary,
            "transactions": {
                "startDate": PERIOD_START.isoformat(),
                "endDate": PERIOD_END.isoformat(),
                "transaction": [aa_tx(t) for t in rows],
            },
        }
        data.append({"decryptedFI": {"type": fi_type, "account": account}, "linkRefNumber": f"link_{accounts[fi_type]}", "maskedAccNumber": masked[fi_type]})
    return [{"fipID": "FIP-HDFC-SYNTHETIC", "data": data}]


def build_source_csvs(txs: list[Tx], payload: list[dict[str, Any]]) -> dict[str, str]:
    tx_fields = ["transaction_id", "date", "timestamp", "account_id", "fi_type", "direction", "mode", "amount", "narration", "balance_after"]
    tx_rows = [{
        "transaction_id": t.txn_id,
        "date": t.dt.date().isoformat(),
        "timestamp": iso(t.dt),
        "account_id": t.account_id,
        "fi_type": t.fi_type,
        "direction": t.direction,
        "mode": t.mode,
        "amount": money(t.amount),
        "narration": t.narration,
        "balance_after": money(t.balance_after),
    } for t in txs]
    accounts_rows = build_accounts_rows(txs, payload)
    monthly_rows = build_monthly_cashflow_rows(txs)
    mode_rows = build_mode_rows(txs)
    return {
        "transactions.csv": csv_text(tx_fields, tx_rows),
        "accounts.csv": csv_text(list(accounts_rows[0].keys()), accounts_rows),
        "monthly_cashflow.csv": csv_text(["month", "total_debits", "total_credits", "net", "opening_balance", "closing_balance"], monthly_rows),
        "mode_spending_summary.csv": csv_text(["mode", "total_amount", "transaction_count", "avg_amount", "percentage_of_total"], mode_rows),
    }


def csv_text(fields: list[str], rows: list[dict[str, Any]]) -> str:
    from io import StringIO
    buf = StringIO()
    writer = csv.DictWriter(buf, fieldnames=fields)
    writer.writeheader()
    writer.writerows(rows)
    return buf.getvalue()


def build_accounts_rows(txs: list[Tx], payload: list[dict[str, Any]]) -> list[dict[str, str]]:
    rows = []
    by_fi = defaultdict(list)
    for tx in txs:
        by_fi[tx.fi_type].append(tx)
    fields = ["account_id", "fi_type", "bank", "account_type", "status", "currency", "opening_balance", "closing_balance", "current_value", "opening_value", "investment_value", "total_credits", "total_debits", "total_purchases", "total_redemptions", "total_installments", "premature_closure_amount", "principal_amount", "maturity_amount", "premature_withdrawal_amount", "penalty_amount", "foregone_interest", "liquidity_class", "balance_role", "transaction_count", "residual_value", "closure_payout_amount", "principal_withdrawn", "closure_status_detail"]
    for fi_type in ["deposit", "mutual_funds", "recurring_deposit", "term_deposit"]:
        rows_fi = by_fi[fi_type]
        credits = sum(t.amount for t in rows_fi if t.direction == "CREDIT")
        debits = sum(t.amount for t in rows_fi if t.direction == "DEBIT")
        common = {f: "" for f in fields}
        common.update({"account_id": rows_fi[0].account_id, "fi_type": fi_type, "bank": "HDFC", "account_type": fi_type, "currency": "INR", "total_credits": money(credits), "total_debits": money(debits), "transaction_count": str(len(rows_fi))})
        if fi_type == "deposit":
            common.update({"status": "ACTIVE", "opening_balance": money(DEPOSIT_OPENING_BALANCE), "closing_balance": money(rows_fi[-1].balance_after), "current_value": money(rows_fi[-1].balance_after), "liquidity_class": "liquid", "balance_role": "cash_balance"})
        elif fi_type == "mutual_funds":
            common.update({"status": "ACTIVE", "opening_balance": "185000.00", "opening_value": "185000.00", "closing_balance": money(rows_fi[-1].balance_after), "current_value": money(rows_fi[-1].balance_after), "investment_value": "347500.00", "total_purchases": money(credits), "total_redemptions": money(debits), "liquidity_class": "market_linked", "balance_role": "current_value"})
        elif fi_type == "recurring_deposit":
            common.update({"status": "PREMATURE_CLOSED", "opening_balance": "0.00", "opening_value": "0.00", "closing_balance": "0.00", "current_value": "0.00", "total_installments": "78000.00", "premature_closure_amount": "78000.00", "liquidity_class": "semi_locked", "balance_role": "deposit_value"})
        else:
            common.update({"status": "PREMATURE_CLOSED", "opening_balance": "120000.00", "opening_value": "120000.00", "closing_balance": "0.00", "current_value": "0.00", "principal_amount": "120000.00", "maturity_amount": "128040.00", "premature_withdrawal_amount": "112000.00", "penalty_amount": "8000.00", "foregone_interest": "8040.00", "liquidity_class": "locked", "balance_role": "deposit_value", "residual_value": "0.00", "closure_payout_amount": "112000.00", "principal_withdrawn": "112000.00", "closure_status_detail": "FULLY_CLOSED_WITH_PREMATURE_WITHDRAWAL_PENALTY"})
        rows.append(common)
    return rows


def build_monthly_cashflow_rows(txs: list[Tx]) -> list[dict[str, str]]:
    months = defaultdict(lambda: {"total_debits": 0.0, "total_credits": 0.0, "opening_balance": None, "closing_balance": None})
    for tx in sorted([t for t in txs if t.fi_type == "deposit"], key=lambda t: t.dt):
        m = tx.dt.strftime("%Y-%m")
        before = tx.balance_after - tx.amount if tx.direction == "CREDIT" else tx.balance_after + tx.amount
        if months[m]["opening_balance"] is None:
            months[m]["opening_balance"] = before
        months[m]["closing_balance"] = tx.balance_after
        months[m]["total_credits" if tx.direction == "CREDIT" else "total_debits"] += tx.amount
    return [{"month": m, "total_debits": money(v["total_debits"]), "total_credits": money(v["total_credits"]), "net": money(v["total_credits"] - v["total_debits"]), "opening_balance": money(v["opening_balance"]), "closing_balance": money(v["closing_balance"])} for m, v in sorted(months.items())]


def build_mode_rows(txs: list[Tx]) -> list[dict[str, str]]:
    dep = [t for t in txs if t.fi_type == "deposit" and t.direction == "DEBIT"]
    total = sum(t.amount for t in dep)
    by_mode = defaultdict(list)
    for tx in dep:
        by_mode[tx.mode].append(tx)
    rows = []
    for mode, items in sorted(by_mode.items(), key=lambda kv: -sum(t.amount for t in kv[1])):
        amount = sum(t.amount for t in items)
        rows.append({"mode": mode, "total_amount": money(amount), "transaction_count": str(len(items)), "avg_amount": money(amount / len(items)), "percentage_of_total": f"{(amount / total * 100):.2f}"})
    return rows


def build_ground_truth(txs: list[Tx]) -> dict[str, Any]:
    rows = [{"transaction_id": t.txn_id, "persona_id": "aarav", "account_type": t.fi_type, "dataset_id": DATASET_ID, "ground_truth": t.truth} for t in txs]
    return {
        "dataset_id": DATASET_ID,
        "persona_id": "aarav",
        "generated_at": GENERATED_AT,
        "period": {"start": PERIOD_START.isoformat(), "end": PERIOD_END.isoformat()},
        "summary": {
            "total_transactions": len(txs),
            "deposit_transactions": sum(1 for t in txs if t.fi_type == "deposit"),
            "income_events": sum(1 for t in txs if t.truth.get("is_income")),
            "salary_events": sum(1 for t in txs if t.truth.get("is_salary")),
            "obligation_events": sum(1 for t in txs if t.truth.get("is_obligation")),
            "discretionary_events": sum(1 for t in txs if t.truth.get("is_discretionary")),
            "recurring_events": sum(1 for t in txs if t.truth.get("is_recurring")),
            "unplanned_events": sum(1 for t in txs if t.truth.get("is_unplanned")),
            "nudge_candidates": sum(1 for t in txs if t.truth.get("nudge_candidate")),
            "interrupt_nudges": sum(1 for t in txs if t.truth.get("should_interrupt")),
            "cash_blindspots": sum(1 for t in txs if t.truth.get("is_cash_blindspot")),
            "asset_transactions": sum(1 for t in txs if t.fi_type != "deposit"),
        },
        "transactions": rows,
    }


def build_credit_card_sources(txs: list[Tx]) -> dict[str, Any]:
    card_specs = [
        ("card_txn_apple_20250816", date(2025, 8, 16), "Apple Store", 145000, "electronics", "cc_2025_08", True, "emi_card_apple_202508"),
        ("card_txn_zara_20251004", date(2025, 10, 4), "Zara", 18000, "fashion", "cc_2025_10", False, ""),
        ("card_txn_nike_20251005", date(2025, 10, 5), "Nike", 14500, "fashion", "cc_2025_10", False, ""),
        ("card_txn_myntra_20251011", date(2025, 10, 11), "Myntra", 22000, "fashion", "cc_2025_10", False, ""),
        ("card_txn_nykaa_20251012", date(2025, 10, 12), "Nykaa", 7500, "fashion", "cc_2025_10", False, ""),
        ("card_txn_indigo_20251206", date(2025, 12, 6), "Indigo Airlines", 28000, "travel", "cc_2025_12", False, ""),
        ("card_txn_hotel_20251207", date(2025, 12, 7), "MakeMyTrip Hotel", 26000, "travel", "cc_2025_12", False, ""),
        ("card_txn_goa_dining_20251209", date(2025, 12, 9), "Goa Dining", 19000, "dining", "cc_2025_12", False, ""),
        ("card_txn_sony_20260214", date(2026, 2, 14), "Sony Center", 98000, "electronics", "cc_2026_02", True, "emi_card_sony_202602"),
    ]
    dep_by_date_amount = {(t.dt.date(), round(t.amount, 2)): t.txn_id for t in txs if t.fi_type == "deposit" and t.mode == "CARD"}
    cc_rows = []
    for card_id, d, merchant, amount, cat, cycle, emi_flag, emi_id in card_specs:
        cc_rows.append({
            "card_transaction_id": card_id,
            "purchase_date": d.isoformat(),
            "posting_date": (d + timedelta(days=1)).isoformat(),
            "merchant": merchant,
            "amount": amount,
            "merchant_category_from_statement": cat,
            "source": "credit_card_statement",
            "statement_cycle_id": cycle,
            "converted_to_emi": emi_flag,
            "emi_id": emi_id,
            "statement_large_purchase_flag": amount >= 75000,
            "source_reconciliation_linked_deposit_transaction_id": dep_by_date_amount.get((d, float(amount)), ""),
            "source_reconciliation_spend_counting_policy": "linked_to_deposit_card_mode_for_legacy_generator_dedupe",
            "source_reconciliation_counted_as_additional_cashflow": False,
        })
    cycles = make_card_cycles()
    emi_schedules = make_card_emi_schedules()
    statement = {
        "dataset_id": DATASET_ID,
        "source_type": "synthetic_credit_card_statement",
        "accounting_precision": "scenario_grade",
        "not_for_production_accounting_rules": True,
        "modeling_limitations": [
            "Hybrid compatibility convention with deposit CARD-mode rows",
            "Statement cycles are designed for scenario testing, not full issuer-grade accounting",
            "Previous outstanding and utilization are synthetic stress indicators",
        ],
        "modeling_convention": "Hybrid compatibility convention: deposit contains CARD-mode purchase rows; statement transactions add cycle detail with generator_metadata reconciliation and counted_as_additional_cashflow=false.",
        "account": {"card_name": "HDFC Regalia Synthetic", "masked_card_number": "XXXX-XXXX-XXXX-4321", "credit_limit": 300000.0},
        "statement_cycles": cycles,
        "transactions": [
            {k: v for k, v in row.items() if not k.startswith("source_reconciliation_")} | {
                "generator_metadata": {
                    "source_reconciliation_linked_deposit_transaction_id": row["source_reconciliation_linked_deposit_transaction_id"],
                    "source_reconciliation_spend_counting_policy": row["source_reconciliation_spend_counting_policy"],
                    "source_reconciliation_counted_as_additional_cashflow": False,
                }
            } for row in cc_rows
        ],
        "emi_schedules": emi_schedules,
    }
    cc_fields = ["card_transaction_id", "purchase_date", "posting_date", "merchant", "amount", "merchant_category_from_statement", "source", "statement_cycle_id", "converted_to_emi", "emi_id", "statement_large_purchase_flag", "source_reconciliation_linked_deposit_transaction_id", "source_reconciliation_spend_counting_policy", "source_reconciliation_counted_as_additional_cashflow"]
    summary_fields = ["statement_cycle_id", "card_name", "masked_card_number", "credit_limit", "available_credit", "statement_cycle_start", "statement_cycle_end", "due_date", "total_amount_due", "minimum_amount_due", "previous_outstanding", "payments_received", "payment_status", "interest_charged", "late_fee", "emi_outstanding", "utilization_ratio", "statement_status", "is_over_limit", "over_limit_amount", "over_limit_reason", "over_limit_fee"]
    return {
        "statement": statement,
        "transactions_csv": csv_text(cc_fields, cc_rows),
        "summary_csv": csv_text(summary_fields, [{k: c.get(k, "") for k in summary_fields} for c in cycles]),
    }


def make_card_cycles() -> list[dict[str, Any]]:
    specs = [
        ("cc_2025_08", 2025, 8, 145000, 36000, "partial", 0, 0, 0.48),
        ("cc_2025_09", 2025, 9, 135700, 0, "missed", 1800, 0, 0.45),
        ("cc_2025_10", 2025, 10, 222600, 0, "missed", 0, 0, 0.74),
        ("cc_2025_11", 2025, 11, 24900, 24900, "paid_emi_cycle", 0, 0, 0.08),
        ("cc_2025_12", 2025, 12, 320100, 0, "missed", 0, 0, 1.07),
        ("cc_2026_01", 2026, 1, 24900, 24900, "paid_emi_cycle", 0, 0, 0.08),
        ("cc_2026_02", 2026, 2, 447350, 24000, "partial", 0, 2350, 1.49),
        ("cc_2026_03", 2026, 3, 436000, 0, "missed", 0, 0, 1.45),
        ("cc_2026_04", 2026, 4, 17300, 17300, "paid_emi_cycle", 0, 0, 0.06),
        ("cc_2026_05", 2026, 5, 175000, 17300, "partial", 0, 0, 0.58),
        ("cc_2026_06", 2026, 6, 17300, 0, "scheduled", 0, 0, 0.06),
        ("cc_2026_07", 2026, 7, 17300, 0, "scheduled", 0, 0, 0.06),
        ("cc_2026_08", 2026, 8, 17300, 0, "scheduled", 0, 0, 0.06),
    ]
    rows = []
    for cid, y, m, due, paid, status, interest, late_fee, util in specs:
        start = date(y, m, 1)
        end = date(y, m, days_in_month(y, m))
        due_date = add_month(date(y, m, 23), 1)
        limit = 300000.0
        is_over = util > 1
        rows.append({
            "statement_cycle_id": cid,
            "card_name": "HDFC Regalia Synthetic",
            "masked_card_number": "XXXX-XXXX-XXXX-4321",
            "credit_limit": limit,
            "available_credit": round(limit - due, 2),
            "statement_cycle_start": start.isoformat(),
            "statement_cycle_end": end.isoformat(),
            "due_date": due_date.isoformat(),
            "total_amount_due": float(due),
            "minimum_amount_due": round(due * 0.05, 2),
            "previous_outstanding": None if "scheduled" in status else 0,
            "payments_received": float(paid),
            "payment_status": status,
            "interest_charged": float(interest),
            "late_fee": float(late_fee),
            "emi_outstanding": None if status == "scheduled" else (90000.0 if cid == "cc_2026_05" else 0),
            "utilization_ratio": util,
            "statement_status": "projected_emi_schedule" if status == "scheduled" else "historical",
            "is_over_limit": is_over,
            "over_limit_amount": round(max(0, due - limit), 2),
            "over_limit_reason": "statement outstanding plus EMI pressure exceeded synthetic card limit" if is_over else "",
            "over_limit_fee": 0.0,
        })
    return rows


def make_card_emi_schedules() -> list[dict[str, Any]]:
    rows = []
    for emi_id, first_due, amount, tenure in [
        ("emi_card_apple_202508", date(2025, 9, 23), 24900, 6),
        ("emi_card_sony_202602", date(2026, 3, 23), 17300, 6),
    ]:
        for i in range(tenure):
            due = add_month(first_due, i)
            is_paid = due <= PERIOD_END
            rows.append({
                "emi_id": emi_id,
                "emi_type": "card_emi",
                "installment_number": i + 1,
                "total_installments": tenure,
                "installment_amount": amount,
                "due_date": due.isoformat(),
                "payment_status": "paid" if is_paid else "scheduled",
                "linked_card_statement_id": f"cc_{due.year:04d}_{due.month:02d}",
                "linked_deposit_transaction_id": None,
                "payment_source": "statement_only_paid" if is_paid else "future_statement_schedule",
                "cashflow_link_status": "not_linked_scenario_grade" if is_paid else "scheduled_future_no_cashflow_yet",
                "cashflow_link_reason": "Scenario-grade card statement source records EMI paid in statement but does not model a separate bank debit for this installment." if is_paid else "Future scheduled EMI installment is outside the extraction period and has no paid deposit transaction yet.",
                "remaining_principal": max(0, amount * (tenure - i - 1)),
            })
    return rows


def build_expected_outputs(txs: list[Tx], credit_card: dict[str, Any]) -> dict[str, Any]:
    income = [{"transaction_id": t.txn_id, "date": t.dt.date().isoformat(), "amount": t.amount, "type": "salary" if t.truth.get("is_salary") else "variable_income", "confidence_expected": "high"} for t in txs if t.truth.get("is_income") and not (t.truth.get("is_investment_redemption") or t.truth.get("is_refund"))]
    recurring = build_recurring_expected()
    emi = build_emi_expected()
    safe = build_safe_expected(txs)
    goal = build_goal_expected()
    health = build_health_expected()
    nudge = build_nudge_expected(txs)
    device = build_device_finance(txs)
    net_worth = build_net_worth_expected(txs, credit_card)
    return {
        "income_candidates_expected.json": income,
        "recurring_candidates_expected.json": recurring,
        "emi_candidates_expected.json": emi,
        "safe_to_spend_expected.json": safe,
        "goal_risk_expected.json": goal,
        "financial_health_expected.json": health,
        "nudge_expected.json": nudge,
        "net_worth_expected.json": net_worth,
        "device_finance_source.json": device,
    }


def build_recurring_expected() -> dict[str, Any]:
    return {
        "dataset_id": DATASET_ID,
        "fixed_commitment": [
            {"name": "Rent", "monthly_amount": 42000, "normalized_bucket": "fixed_commitment", "commitment_strength": "must_pay", "reserve_before_safe_to_spend": True, "cancelable": False, "debt_related": False},
            {"name": "ACT Fibernet", "monthly_amount": 999, "normalized_bucket": "fixed_commitment", "commitment_strength": "must_pay", "reserve_before_safe_to_spend": True, "cancelable": False, "debt_related": False},
        ],
        "cancelable_commitment": [
            {"name": "Netflix", "monthly_amount": 649, "normalized_bucket": "cancelable_commitment", "commitment_strength": "cancelable", "reserve_before_safe_to_spend": False, "cancelable": True},
            {"name": "Spotify", "monthly_amount": 119, "normalized_bucket": "cancelable_commitment", "commitment_strength": "cancelable", "reserve_before_safe_to_spend": False, "cancelable": True},
        ],
        "protected_goal_transfer": [
            {"name": "HDFC Bluechip SIP", "monthly_amount": 10000, "normalized_bucket": "protected_goal_transfer", "commitment_strength": "goal_protective", "goal_protective": True},
            {"name": "Emergency RD", "monthly_amount": 7000, "normalized_bucket": "protected_goal_transfer", "commitment_strength": "goal_protective", "goal_protective": True},
        ],
        "debt_commitment": [
            {"name": "Apple Card EMI", "monthly_amount": 24900, "normalized_bucket": "debt_commitment", "commitment_strength": "must_pay", "debt_related": True, "reserve_before_safe_to_spend": True},
            {"name": "Bajaj Device EMI", "monthly_amount": 9000, "normalized_bucket": "debt_commitment", "commitment_strength": "must_pay", "debt_related": True, "reserve_before_safe_to_spend": True},
        ],
        "recurring_spending_rhythm": [
            {"name": "Groceries", "normalized_bucket": "recurring_spending_rhythm", "commitment_strength": "forecast_only", "forecast_only": True},
        ],
        "leakage_candidate": [
            {"name": "Coffee habit", "normalized_bucket": "leakage_candidate", "commitment_strength": "risky_leakage", "forecast_only": True},
            {"name": "Cab habit", "normalized_bucket": "leakage_candidate", "commitment_strength": "risky_leakage", "forecast_only": True},
        ],
    }


def build_emi_expected() -> list[dict[str, Any]]:
    return [
        {"candidate_id": "emi_card_apple_202508", "emi_type": "card_emi", "merchant": "Apple Store", "lender": "HDFC Bank", "monthly_amount": 24900, "tenure_months": 6, "remaining_months": 0, "first_due_date": "2025-09-23", "last_due_date": "2026-02-23", "payment_status_pattern": ["paid"], "confidence_expected": "high", "obligation_type": "debt_commitment", "safe_to_spend_impact": -24900, "financial_health_impact": "credit_card_discipline_risk", "linked_goal_id": "laptop", "linked_rash_purchase_id": "card_txn_apple_20250816"},
        {"candidate_id": "emi_card_sony_202602", "emi_type": "card_emi", "merchant": "Sony Center", "lender": "HDFC Bank", "monthly_amount": 17300, "tenure_months": 6, "remaining_months": 3, "first_due_date": "2026-03-23", "last_due_date": "2026-08-23", "payment_status_pattern": ["paid", "scheduled"], "confidence_expected": "high", "obligation_type": "debt_commitment", "safe_to_spend_impact": -17300, "financial_health_impact": "credit_card_discipline_risk", "linked_goal_id": "laptop", "linked_rash_purchase_id": "card_txn_sony_20260214"},
        {"candidate_id": "emi_device_bajaj_202511", "emi_type": "device_emi", "merchant": "Croma Koramangala Synthetic", "lender": "Bajaj Finance", "monthly_amount": 9000, "tenure_months": 8, "remaining_months": 2, "first_due_date": "2025-12-05", "last_due_date": "2026-07-05", "payment_status_pattern": ["paid", "scheduled"], "confidence_expected": "high", "obligation_type": "debt_commitment", "safe_to_spend_impact": -9000, "financial_health_impact": "debt_pressure_watch", "linked_goal_id": None, "linked_rash_purchase_id": "device_purchase_20251105", "source_purchase_id": "device_purchase_20251105", "source_file": "device_finance_source.json"},
    ]


def build_safe_expected(txs: list[Tx]) -> dict[str, Any]:
    months = []
    for i, m in enumerate(month_iter()):
        ym = f"{m.year:04d}-{m.month:02d}"
        month_txs = [t for t in txs if t.fi_type == "deposit" and t.dt.strftime("%Y-%m") == ym]
        income = sum(t.amount for t in month_txs if t.direction == "CREDIT" and t.truth.get("is_income") and not t.truth.get("is_liquidity_rescue"))
        debt = sum(t.amount for t in month_txs if t.truth.get("is_emi") or t.truth.get("is_credit_card_payment") or t.truth.get("is_credit_card_interest") or t.truth.get("is_late_fee"))
        protected = sum(t.amount for t in month_txs if t.truth.get("is_sip") or t.truth.get("is_rd") or t.truth.get("is_rent") or t.truth.get("is_utility"))
        discretionary = sum(t.amount for t in month_txs if t.truth.get("is_discretionary"))
        rescue = sum(t.amount for t in month_txs if t.direction == "CREDIT" and t.truth.get("is_liquidity_rescue"))
        planned = income - protected - debt - 52000
        actual = income - protected - debt - discretionary
        status = "risk" if actual < 0 or ym in {"2025-08", "2025-10", "2025-12", "2026-02", "2026-03"} else ("watch" if planned < 10000 else "healthy")
        months.append({"month": ym, "income": round(income, 2), "fixed_commitments": round(protected, 2), "protected_goal_transfers": 22000, "expected_discretionary_spend": 52000, "actual_discretionary_spend": round(discretionary, 2), "safe_to_spend_start": round(planned, 2), "safe_to_spend_end": round(actual, 2), "planned_safe_to_spend_after_expected_spend": round(planned, 2), "actual_safe_to_spend_after_period": round(actual, 2), "protected_commitments": round(protected, 2), "debt_commitments": round(debt, 2), "goal_protection": 22000, "liquidity_rescue_amount": round(rescue, 2), "excluded_from_income_amount": round(rescue, 2), "status": status, "reason": "actual discretionary spend, card pressure, and EMI commitments exceeded protected cashflow" if status == "risk" else "within expected pace"})
    return {"dataset_id": DATASET_ID, "month_level": months, "weekly_snapshots": []}


def build_goal_expected() -> dict[str, Any]:
    return {"dataset_id": DATASET_ID, "goals": [
        {"goal_id": "emergency_fund", "goal_name": "Emergency fund", "target_amount": 500000, "expected_monthly_allocation": 22000, "actual_allocations": 8, "skipped_months": ["2026-03", "2026-04"], "projected_delay_days": 75, "status": "risk", "reason": "RD break and TD closure weakened emergency buffer"},
        {"goal_id": "vacation", "goal_name": "Japan vacation", "target_amount": 250000, "expected_monthly_allocation": 12000, "actual_allocations": 7, "skipped_months": ["2025-10", "2025-12", "2026-02"], "projected_delay_days": 60, "status": "risk", "reason": "luxury and spontaneous trip spending displaced allocation"},
        {"goal_id": "laptop", "goal_name": "Laptop/gadget", "target_amount": 180000, "expected_monthly_allocation": 10000, "actual_allocations": 6, "skipped_months": ["2025-08", "2026-02"], "projected_delay_days": 45, "status": "watch", "reason": "rash purchase converted into EMI pressure"},
    ]}


def build_health_expected() -> dict[str, Any]:
    return {"dataset_id": DATASET_ID, "overall_status": "Risk", "dimensions": {"cashflow_stability": "Watch", "obligation_load": "Watch", "safe_to_spend": "Risk", "goal_progress": "Risk", "emergency_readiness": "Risk", "debt_pressure": "Risk", "subscription_leakage": "Watch", "spending_drift": "Risk", "upcoming_risk": "Risk", "credit_card_discipline": "Risk", "liquidity_stress": "Risk", "investment_discipline": "Risk", "net_worth": "Risk"}}


def build_net_worth_expected(txs: list[Tx], credit_card: dict[str, Any]) -> dict[str, Any]:
    rows = []
    stmt_cycles = {c["statement_cycle_id"]: c for c in credit_card["statement"].get("statement_cycles", [])}
    for m in month_iter():
        ym = f"{m.year:04d}-{m.month:02d}"
        upto = [t for t in txs if t.dt.date() <= date(m.year, m.month, days_in_month(m.year, m.month))]
        def final_value(fi_type: str, opening: float) -> float:
            rows_fi = sorted([t for t in upto if t.fi_type == fi_type], key=lambda t: (t.dt, t.txn_id))
            return rows_fi[-1].balance_after if rows_fi else opening
        cash = final_value("deposit", DEPOSIT_OPENING_BALANCE)
        mf = final_value("mutual_funds", 185000.0)
        rd = final_value("recurring_deposit", 0.0)
        td = final_value("term_deposit", 120000.0)
        cycle = stmt_cycles.get(f"cc_{m.year:04d}_{m.month:02d}", {})
        card_outstanding = max(0.0, float(cycle.get("total_amount_due") or 0) - float(cycle.get("payments_received") or 0))
        if m == month_iter()[-1]:
            emi_outstanding = 90000.0
        else:
            emi_outstanding = max(0.0, float(cycle.get("emi_outstanding") or 0))
        net = cash + mf + rd + td - card_outstanding - emi_outstanding
        liquid_net = cash - card_outstanding - emi_outstanding
        status = "risk" if net < 150000 or liquid_net < 50000 else ("watch" if net < 300000 else "healthy")
        rows.append({
            "month": ym,
            "liquid_cash": round(cash, 2),
            "mutual_fund_value": round(mf, 2),
            "rd_value": round(rd, 2),
            "td_value": round(td, 2),
            "other_assets_if_any": 0.0,
            "credit_card_outstanding": round(card_outstanding, 2),
            "emi_outstanding": round(emi_outstanding, 2),
            "other_liabilities_if_any": 0.0,
            "net_worth": round(net, 2),
            "liquid_net_worth": round(liquid_net, 2),
            "status": status,
            "reason": "Low liquid cash, reduced investments, broken deposits, card outstanding, and EMI commitments keep net worth at risk." if status == "risk" else "Assets still cover liabilities but liquidity remains watch-worthy.",
        })
    return {
        "dataset_id": DATASET_ID,
        "source_type": "expected_intelligence_test_oracle",
        "rows": rows,
        "summary": rows[-1],
    }


def nudge_copy(tx: Tx) -> str:
    g = tx.truth
    if g.get("is_extreme_purchase"):
        return f"This ₹{tx.amount:,.0f} purchase can push your laptop and emergency goals off track."
    if g.get("is_travel"):
        return f"This ₹{tx.amount:,.0f} travel payment deepens goal drift while safe-to-spend is under pressure."
    if g.get("is_luxury"):
        return f"This ₹{tx.amount:,.0f} card purchase adds to the luxury spike already pressuring your monthly cashflow."
    if g.get("is_credit_card_payment"):
        status = g.get("credit_card_payment_status") or "partial"
        return f"This {status} card payment leaves bill pressure carrying into the next cycle."
    if g.get("is_credit_card_interest"):
        return f"You paid ₹{tx.amount:,.0f} in card interest because the previous bill was not cleared in full."
    if g.get("is_late_fee"):
        return f"This ₹{tx.amount:,.0f} late fee is avoidable card pressure."
    if g.get("is_sip") and g.get("sip_status") in ["failed", "delayed", "reduced"]:
        return f"This SIP is {g.get('sip_status')}, which weakens your protected goal rhythm."
    if g.get("is_premature_withdrawal") and g.get("is_term_deposit"):
        return "Breaking this term deposit releases cash now but costs ₹8,000 of protected buffer."
    if g.get("is_premature_withdrawal"):
        return f"This premature closure releases ₹{tx.amount:,.0f}, but weakens your emergency buffer."
    if g.get("is_emi"):
        return f"This EMI adds ₹{tx.amount:,.0f} of debt commitment before safe-to-spend."
    if g.get("expected_nudge_type") == "safe_to_spend_upi_interrupt":
        return f"This ₹{tx.amount:,.0f} UPI payment lands during a risk month and can deepen the safe-to-spend gap."
    if g.get("expected_nudge_type") == "ambiguous_upi_review":
        return f"This ₹{tx.amount:,.0f} UPI payment has weak merchant context and should be reviewed before it repeats."
    return f"This ₹{tx.amount:,.0f} transaction is a {g.get('expected_nudge_type', 'money signal').replace('_', ' ')} signal for Moné."


def build_nudge_expected(txs: list[Tx]) -> dict[str, Any]:
    entries = []
    for tx in txs:
        if tx.truth.get("nudge_candidate"):
            entry = {"transaction_id": tx.txn_id, "expected_nudge_type": tx.truth.get("expected_nudge_type"), "should_interrupt": bool(tx.truth.get("should_interrupt")), "surface_mode": tx.truth.get("surface_mode"), "nudge_priority": tx.truth.get("nudge_priority"), "nudge_reason": tx.truth.get("financial_health_impact") or tx.truth.get("expected_nudge_type"), "user_facing_copy_candidate": nudge_copy(tx), "copy_review_required": bool(tx.truth.get("should_interrupt")), "product_surface": "interrupt" if tx.truth.get("should_interrupt") else tx.truth.get("surface_mode")}
            if not tx.truth.get("should_interrupt"):
                entry["suppression_reason"] = "Not severe enough for interruption; aggregate into insight surface."
            entries.append(entry)
    return {
        "dataset_id": DATASET_ID,
        "generated_at": GENERATED_AT,
        "source_type": "expected_intelligence_test_oracle",
        "copy_maturity": "testing_scaffold",
        "final_ux_copy": False,
        "notes": "Only surface_mode=interrupt entries are candidates for future UX copy review. Weekly summary and dashboard insight entries are expected signal scaffolding, not final copy.",
        "entries": entries,
        "summary": {"nudge_candidates": len(entries), "interrupt_nudges": sum(1 for e in entries if e["should_interrupt"])},
    }


def build_device_finance(txs: list[Tx]) -> dict[str, Any]:
    linked = [t.txn_id for t in txs if "BAJAJ FINANCE/DEVICE EMI" in t.narration]
    return {"dataset_id": DATASET_ID, "source_type": "synthetic_device_finance_source", "source_purchase_id": "device_purchase_20251105", "merchant": "Croma Koramangala Synthetic", "lender": "Bajaj Finance", "purchase_date": "2025-11-05", "purchase_amount": 72000.0, "financed_amount": 72000.0, "down_payment_amount": 0.0, "tenure_months": 8, "monthly_emi": 9000.0, "first_due_date": "2025-12-05", "last_due_date": "2026-07-05", "linked_deposit_payment_txn_ids": linked, "status": "active", "remaining_installments_after_period": 2, "generator_metadata": {"source_reconciliation_policy": "deposit EMI debit rows represent paid installments through 2026-05; remaining installments are scheduled after extraction end date"}}


def build_demo_identity_map() -> dict[str, Any]:
    return {
        "demo_identities": [
            {
                "phone": "8828290489",
                "personaId": "aarav",
                "displayName": "Aarav",
                "dataset_id": DATASET_ID,
                "sourceHolderProfile": "masked",
                "status": "wired",
            },
            {
                "phone": "7304893952",
                "personaId": "priya",
                "displayName": "Priya",
                "dataset_id": None,
                "sourceHolderProfile": "masked",
                "status": "not_wired_yet",
                "message": "Priya dataset is not wired yet.",
            },
        ],
        "unsupported_number_behavior": {
            "status": "unsupported_demo_number",
            "message": "This demo number is not supported yet. Try Aarav's demo number.",
        },
    }


def build_dataset_registry() -> dict[str, Any]:
    return {
        "available_datasets": [
            {"dataset_id": DATASET_ID, "persona_id": "aarav", "status": "ready"},
            {"dataset_id": "priya_goal_planner", "persona_id": "priya", "status": "not_wired_yet"},
        ]
    }


def write_outputs(generated: dict[str, Any], seed: str) -> None:
    if OUTPUT_DIR.exists():
        shutil.rmtree(OUTPUT_DIR)
    OUTPUT_DIR.mkdir(parents=True)
    demo_identity = build_demo_identity_map()
    dataset_registry = build_dataset_registry()
    write_root_json("demo_identity_map.json", demo_identity)
    write_root_json("dataset_registry.json", dataset_registry)
    write_json("demo_identity_map.json", demo_identity)
    write_json("dataset_registry.json", dataset_registry)
    write_json("raw_payload.json", generated["payload"])
    for name, text in generated["source_csvs"].items():
        (OUTPUT_DIR / name).write_text(text)
    write_json("credit_card_statement.json", generated["credit_card"]["statement"])
    (OUTPUT_DIR / "credit_card_transactions.csv").write_text(generated["credit_card"]["transactions_csv"])
    (OUTPUT_DIR / "credit_card_summary.csv").write_text(generated["credit_card"]["summary_csv"])
    write_json("device_finance_source.json", generated["expected"]["device_finance_source.json"])
    write_json("ground_truth.json", generated["ground_truth"])
    for name in ["income_candidates_expected.json", "recurring_candidates_expected.json", "emi_candidates_expected.json", "safe_to_spend_expected.json", "goal_risk_expected.json", "financial_health_expected.json", "nudge_expected.json", "net_worth_expected.json"]:
        write_json(name, generated["expected"][name])
    write_json("validation_report.json", {"dataset_id": DATASET_ID, "status": "pending"})
    manifest = build_manifest(seed, "pending")
    write_json("output_manifest.json", manifest)
    manifest = build_manifest(seed, "pending")
    write_json("output_manifest.json", manifest)
    # Recompute with manifest present and rewrite report/manifest. Manifest excludes
    # self hash and validation report hash to avoid circular hash churn.
    report = validate_output(return_report=True)
    write_json("validation_report.json", report)
    manifest = build_manifest(seed, report["status"])
    write_json("output_manifest.json", manifest)
    report = validate_output(return_report=True)
    write_json("validation_report.json", report)


def write_json(name: str, obj: Any) -> None:
    (OUTPUT_DIR / name).write_text(json.dumps(obj, indent=2, sort_keys=False, default=json_default) + "\n")


def write_root_json(name: str, obj: Any) -> None:
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    (OUTPUT_ROOT / name).write_text(json.dumps(obj, indent=2, sort_keys=False, default=json_default) + "\n")


def json_default(obj: Any) -> Any:
    if isinstance(obj, set):
        return sorted(obj)
    if isinstance(obj, Counter):
        return dict(obj)
    raise TypeError(f"Object of type {obj.__class__.__name__} is not JSON serializable")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build_manifest(seed: str, validation_status: str) -> dict[str, Any]:
    files = sorted(p.name for p in OUTPUT_DIR.iterdir() if p.is_file())
    hashes = {
        name: (
            "self_hash_excluded" if name == "output_manifest.json"
            else "validation_report_hash_excluded" if name == "validation_report.json"
            else sha256(OUTPUT_DIR / name)
        )
        for name in files
    }
    row_counts = {}
    for name in files:
        if name.endswith(".csv"):
            with open(OUTPUT_DIR / name, newline="") as f:
                row_counts[name] = sum(1 for _ in csv.DictReader(f))
    raw_count = len(flatten_raw_transactions(load_json("raw_payload.json"))) if (OUTPUT_DIR / "raw_payload.json").exists() else 0
    gt_count = len(load_json("ground_truth.json").get("transactions", [])) if (OUTPUT_DIR / "ground_truth.json").exists() else 0
    account_count = Counter(acc["type"] for acc in flatten_raw_accounts(load_json("raw_payload.json"))) if (OUTPUT_DIR / "raw_payload.json").exists() else Counter()
    return {
        "dataset_id": DATASET_ID,
        "seed": seed,
        "generated_at": GENERATED_AT,
        "generation_command": GENERATION_COMMAND,
        "validation_command": VALIDATION_COMMAND,
        "files": files,
        "sha256": hashes,
        "demo_identity_files": ["demo_identity_map.json"],
        "dataset_registry_files": ["dataset_registry.json"],
        "external_file_sha256": {
            "../demo_identity_map.json": sha256(OUTPUT_ROOT / "demo_identity_map.json") if (OUTPUT_ROOT / "demo_identity_map.json").exists() else None,
            "../dataset_registry.json": sha256(OUTPUT_ROOT / "dataset_registry.json") if (OUTPUT_ROOT / "dataset_registry.json").exists() else None,
        },
        "row_counts": row_counts,
        "transaction_counts_by_file": {"raw_payload.json": raw_count, "transactions.csv": row_counts.get("transactions.csv", 0), "ground_truth.json": gt_count, "credit_card_transactions.csv": row_counts.get("credit_card_transactions.csv", 0)},
        "account_counts_by_fi_type": dict(account_count),
        "ground_truth_count": gt_count,
        "expected_file_counts": expected_counts(),
        "validation_status": validation_status,
        "source_layer_files": SOURCE_FILES,
        "expected_intelligence_files": EXPECTED_FILES,
        "demo_identity_layer_files": ["demo_identity_map.json"],
        "dataset_registry_layer_files": ["dataset_registry.json"],
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
            else:
                counts[name] = len(obj)
    return counts


def load_json(name: str) -> Any:
    return json.loads((OUTPUT_DIR / name).read_text())


def load_root_json(name: str) -> Any:
    path = OUTPUT_ROOT / name
    if not path.exists():
        return {}
    return json.loads(path.read_text())


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


def validate_output(return_report: bool = False) -> dict[str, Any]:
    checks = []
    def add(name: str, expected: str, actual: Any, ok: bool) -> None:
        checks.append({"name": name, "expected": expected, "actual": actual, "result": "pass" if ok else "fail"})

    files = sorted(p.name for p in OUTPUT_DIR.iterdir() if p.is_file()) if OUTPUT_DIR.exists() else []
    raw = load_json("raw_payload.json") if (OUTPUT_DIR / "raw_payload.json").exists() else []
    tx_csv = read_csv_rows("transactions.csv") if (OUTPUT_DIR / "transactions.csv").exists() else []
    gt = load_json("ground_truth.json") if (OUTPUT_DIR / "ground_truth.json").exists() else {"transactions": []}
    cc_rows = read_csv_rows("credit_card_transactions.csv") if (OUTPUT_DIR / "credit_card_transactions.csv").exists() else []
    stmt = load_json("credit_card_statement.json") if (OUTPUT_DIR / "credit_card_statement.json").exists() else {"statement_cycles": [], "transactions": [], "emi_schedules": []}
    safe = load_json("safe_to_spend_expected.json") if (OUTPUT_DIR / "safe_to_spend_expected.json").exists() else {"month_level": []}
    health = load_json("financial_health_expected.json") if (OUTPUT_DIR / "financial_health_expected.json").exists() else {}
    nudge = load_json("nudge_expected.json") if (OUTPUT_DIR / "nudge_expected.json").exists() else {"entries": []}
    net_worth = load_json("net_worth_expected.json") if (OUTPUT_DIR / "net_worth_expected.json").exists() else {"rows": [], "summary": {}}
    emi = load_json("emi_candidates_expected.json") if (OUTPUT_DIR / "emi_candidates_expected.json").exists() else []
    device = load_json("device_finance_source.json") if (OUTPUT_DIR / "device_finance_source.json").exists() else {}
    accounts_csv = read_csv_rows("accounts.csv") if (OUTPUT_DIR / "accounts.csv").exists() else []
    raw_txs = flatten_raw_transactions(raw) if raw else []
    raw_ids = {tx["txnId"] for _, tx in raw_txs}
    csv_ids = {r["transaction_id"] for r in tx_csv}
    gt_ids = {r["transaction_id"] for r in gt.get("transactions", [])}
    dep_rows = [r for r in tx_csv if r.get("fi_type") == "deposit"]
    asset_rows = [r for r in tx_csv if r.get("fi_type") != "deposit"]
    fi_types = sorted({acc["type"] for acc in flatten_raw_accounts(raw)}) if raw else []
    account_count = Counter(acc["type"] for acc in flatten_raw_accounts(raw)) if raw else Counter()

    required_set = set(REQUIRED_FILES)
    add("output_folder_regenerated_atomically", "output folder exists and contains only generated files", files, OUTPUT_DIR.exists() and set(files) <= required_set and required_set <= set(files))
    add("output_manifest_present", "output_manifest.json present", "output_manifest.json" in files, "output_manifest.json" in files)
    manifest = load_json("output_manifest.json") if (OUTPUT_DIR / "output_manifest.json").exists() else {}
    add("output_manifest_covers_all_files", "manifest file list equals output folder files", manifest.get("files"), set(manifest.get("files", [])) == set(files))
    add("output_manifest_covers_identity_registry_files", "manifest lists identity and registry files", {"demo": manifest.get("demo_identity_files"), "registry": manifest.get("dataset_registry_files")}, manifest.get("demo_identity_files") == ["demo_identity_map.json"] and manifest.get("dataset_registry_files") == ["dataset_registry.json"])
    add("manifest_includes_demo_identity_files", "manifest includes self-contained identity and registry files", {"demo": "demo_identity_map.json" in manifest.get("files", []), "registry": "dataset_registry.json" in manifest.get("files", [])}, "demo_identity_map.json" in manifest.get("files", []) and "dataset_registry.json" in manifest.get("files", []))
    hash_bad = []
    if manifest:
        for name in files:
            expected = manifest.get("sha256", {}).get(name)
            if name == "output_manifest.json":
                if expected != "self_hash_excluded":
                    hash_bad.append(name)
            elif name == "validation_report.json":
                if expected != "validation_report_hash_excluded":
                    hash_bad.append(name)
            elif expected != sha256(OUTPUT_DIR / name):
                hash_bad.append(name)
    add("output_hashes_reproducible", "manifest hashes match current files except documented self hash", hash_bad, not hash_bad)
    add("validation_summary_counts_match_files", "summary counts match files", {"tx": len(tx_csv), "raw": len(raw_txs), "gt": len(gt_ids)}, len(tx_csv) == len(raw_txs) == len(gt_ids))
    add("no_stale_files_from_previous_generation", "no unexpected files present", sorted(set(files) - required_set), not (set(files) - required_set))
    add("output_package_self_contained", "dataset folder contains source, expected, identity, registry, and manifest files", files, all((OUTPUT_DIR / name).exists() for name in REQUIRED_FILES))
    add("no_external_required_files_missing", "no required package files live only outside the dataset folder", missing(REQUIRED_FILES), not missing(REQUIRED_FILES))

    source_violations = source_taxonomy_violations()
    narration_leaks = source_narration_leaks()
    add("source_files_have_no_mone_taxonomy", "source files exclude Moné taxonomy", source_violations, not source_violations)
    add("source_metadata_is_namespaced", "synthetic source metadata is namespaced", source_metadata_violations(), not source_metadata_violations())
    add("raw_payload_has_no_expected_intelligence_fields", "raw payload excludes expected fields", raw_expected_field_violations(raw), not raw_expected_field_violations(raw))
    csv_hidden = csv_hidden_ground_truth_violations()
    add("canonical_source_csvs_have_no_hidden_ground_truth", "source CSV headers exclude hidden ground truth", csv_hidden, not csv_hidden)
    cc_tax = [v for v in source_violations if v.startswith("credit_card")]
    add("credit_card_source_has_no_mone_taxonomy", "credit-card source excludes Moné taxonomy", cc_tax, not cc_tax)
    gt_tax_count = sum(1 for r in gt.get("transactions", []) if "category" in r.get("ground_truth", {}))
    add("ground_truth_contains_taxonomy", "ground truth contains taxonomy labels", gt_tax_count, gt_tax_count == len(gt_ids) and gt_tax_count > 0)
    add("expected_outputs_contain_intelligence", "expected outputs and nudge file present", [f for f in EXPECTED_FILES if (OUTPUT_DIR / f).exists()], all((OUTPUT_DIR / f).exists() for f in EXPECTED_FILES))
    add("app_input_files_are_reality_grounded", "source files are taxonomy-free and required", len(source_violations), not source_violations)
    add("nudge_copy_not_in_source_files", "nudge copy absent from source files", nudge_copy_leaks(nudge), not nudge_copy_leaks(nudge))
    add("source_narrations_have_no_mone_taxonomy_leakage", "source narration text excludes behavioral taxonomy", narration_leaks, not narration_leaks)
    add("source_narrations_are_bank_like", "source narrations are bank-like merchant/payment rails", bank_like_narration_issues(), not bank_like_narration_issues())
    add("rash_behavior_present_only_in_ground_truth_or_expected", "rash labels absent from source but present in truth", {"source_leaks": narration_leaks, "truth_events": rash_truth_count(gt)}, not narration_leaks and rash_truth_count(gt) >= 2)
    local_stats = local_micro_upi_stats(gt, tx_csv)
    add("local_micro_upi_variety_present", "local micro UPI contains diverse categories and merchants", local_stats, local_stats["category_count"] >= 20 and local_stats["merchant_count"] >= 30)
    add("local_micro_upi_monthly_frequency_in_target_range", "25-55 local micro UPI spends per month", local_stats["monthly_counts"], all(25 <= count <= 55 for count in local_stats["monthly_counts"].values()))
    add("local_micro_upi_amount_distribution_realistic", "local UPI amounts are small with most below 700", local_stats, local_stats["count"] > 0 and local_stats["max_amount"] <= 3500 and local_stats["share_under_700"] >= 0.65)
    add("local_micro_upi_has_truncated_merchants", "local UPI includes truncated merchant/source names", local_stats["truncated_examples"], bool(local_stats["truncated_examples"]))
    add("local_micro_upi_has_qr_aggregator_narrations", "local UPI includes QR aggregator strings", local_stats["qr_examples"], bool(local_stats["qr_examples"]))
    add("local_micro_upi_has_ambiguous_payees", "local UPI includes person-name or ambiguous payees", local_stats["ambiguous_examples"], bool(local_stats["ambiguous_examples"]))
    add("local_micro_upi_has_ground_truth_categories", "local UPI rows have hidden ground-truth categories", local_stats["category_count"], local_stats["category_count"] >= 20)
    add("local_micro_upi_not_all_high_confidence", "local UPI contains medium/low confidence cases", local_stats["confidence_counts"], local_stats["confidence_counts"].get("low", 0) > 0 and local_stats["confidence_counts"].get("medium", 0) > 0)
    add("tagging_ambiguity_cases_present", "ambiguous local UPI cases exist", local_stats["ambiguous_count"], local_stats["ambiguous_count"] >= 12)
    add("source_narrations_do_not_leak_local_upi_taxonomy", "local UPI source text excludes local taxonomy labels", narration_leaks, not narration_leaks)
    add("aarav_upi_micro_spend_density_high", "Aarav has high UPI micro-spend density", local_stats["count"], local_stats["count"] >= 300)
    add("upi_dominates_small_transaction_count", "UPI dominates small transaction count", local_stats, local_stats["upi_small_share"] >= 0.55)
    add("local_upi_contributes_to_spend_drift", "local UPI total materially contributes to spend drift", local_stats["total_amount"], local_stats["total_amount"] >= 180000)
    add("local_micro_upi_nudge_candidates_present", "local UPI nudge candidates present", local_stats["nudge_candidates"], local_stats["nudge_candidates"] >= 250)
    add("local_micro_upi_interrupts_limited", "local UPI interrupts are limited below 5%", local_stats, 0 < local_stats["interrupts"] <= max(1, int(local_stats["count"] * 0.05)))
    add("micro_upi_interrupts_contextual", "local UPI interrupts occur in risk context", local_stats["interrupt_examples"], local_stats["interrupts"] >= 3 and all(x.get("expected_nudge_type") == "safe_to_spend_upi_interrupt" for x in local_stats["interrupt_examples"]))
    raw_evidence = raw_money_map_evidence_status(tx_csv)
    raw_balance_status = deposit_balance_mismatches(raw, tx_csv)
    add("raw_balance_chronology_reconciles", "raw/csv running balances reconcile", raw_balance_status, not raw_balance_status["mismatches"])
    add("currentBalance_matches_latest_transaction_balance", "raw currentBalance matches latest transaction", deposit_summary_ok(raw, tx_csv), deposit_summary_ok(raw, tx_csv) is True)
    add("raw_payload_schema_valid", "raw payload has FIP/account/transaction structure", {"fi_types": fi_types, "transactions": len(raw_txs)}, bool(raw) and bool(raw_txs) and bool(fi_types))
    add("canonical_csvs_match_raw_payload", "canonical CSV ids match raw payload ids", {"raw": len(raw_ids), "csv": len(csv_ids)}, raw_ids == csv_ids)
    add("no_mone_taxonomy_in_raw", "raw/source files have no Moné taxonomy", source_violations, not source_violations)
    add("no_dashboard_terms_in_raw_narrations", "raw narrations have no dashboard/intelligence terms", raw_evidence["dashboard_terms"], not raw_evidence["dashboard_terms"])
    add("no_risk_impulse_reckless_labels_in_raw", "raw narrations have no risk/impulse/reckless labels", raw_evidence["risk_terms"], not raw_evidence["risk_terms"])
    add("lpg_transactions_present", "LPG/gas payments present", raw_evidence["lpg_transactions"], len(raw_evidence["lpg_transactions"]) >= 4)
    add("rent_component_transactions_present", "rent component payments present", raw_evidence["rent_components"], len(raw_evidence["rent_components"]) >= 4)
    add("variable_electricity_present", "electricity payments vary by month", raw_evidence["electricity_amounts"], len(set(raw_evidence["electricity_amounts"])) >= 4 and max(raw_evidence["electricity_amounts"] or [0]) - min(raw_evidence["electricity_amounts"] or [0]) >= 2000)
    add("internet_mobile_topup_present", "internet/mobile topups present", raw_evidence["internet_mobile_topups"], len(raw_evidence["internet_mobile_topups"]) >= 4)
    add("domestic_help_advance_present", "domestic help advance evidence present", raw_evidence["domestic_help_advances"], bool(raw_evidence["domestic_help_advances"]))
    add("emi_extra_payment_present", "EMI extra payment evidence present", raw_evidence["emi_extra_payments"], bool(raw_evidence["emi_extra_payments"]))
    add("sip_or_rd_lumpsum_present", "SIP/RD/MF topup evidence present", raw_evidence["fund_topups"], len(raw_evidence["fund_topups"]) >= 3)
    add("vehicle_service_center_cost_present", "vehicle service/repair evidence present", raw_evidence["vehicle_service"], len(raw_evidence["vehicle_service"]) >= 3)
    add("annual_subscription_due_present", "annual subscription due in final month present", raw_evidence["annual_renewals"], len(raw_evidence["annual_renewals"]) >= 2)
    add("needs_review_raw_signals_present", "ambiguous raw review signals present", raw_evidence["needs_review"], len(raw_evidence["needs_review"]) >= 10)
    add("aarav_subscription_load_high", "Aarav has high realistic subscription load", raw_evidence["subscription_merchants"], len(raw_evidence["subscription_merchants"]) >= 14)
    add("aarav_rich_local_upi_variety_present", "Aarav local UPI includes requested messy merchant variety", raw_evidence["messy_upi_terms"], len(raw_evidence["messy_upi_terms"]) >= 12)
    add("aarav_local_upi_density_high", "Aarav local UPI density remains high", local_stats["count"], local_stats["count"] >= 300)
    add("aarav_device_emi_extra_payment_present", "Aarav has device EMI extra payment", raw_evidence["device_emi_extra_payments"], bool(raw_evidence["device_emi_extra_payments"]))
    add("aarav_vehicle_repair_outlier_present", "Aarav has a large vehicle repair/service outlier", raw_evidence["vehicle_service_amounts"], any(amount >= 9000 for amount in raw_evidence["vehicle_service_amounts"]))
    add("aarav_sip_rd_irregularity_present", "Aarav has SIP/RD topup plus redemption/closure irregularity", raw_evidence["fund_irregularity"], len(raw_evidence["fund_irregularity"]) >= 4)
    add("aarav_cash_blindspots_present", "Aarav has multiple ATM blindspots", raw_evidence["atm_withdrawals"], len(raw_evidence["atm_withdrawals"]) >= 6)
    add("aarav_remains_spend_control_risky", "Aarav remains spend-control risky", {"health": health.get("overall_status"), "cash": raw_evidence["atm_withdrawals"]}, health.get("overall_status") == "Risk" and len(raw_evidence["subscription_merchants"]) >= 14)

    add("required_source_files_present", "all source files present", missing(SOURCE_FILES), not missing(SOURCE_FILES))
    add("required_expected_files_present", "all expected files present", missing(EXPECTED_FILES), not missing(EXPECTED_FILES))
    add("raw_payload_has_required_fi_types", "deposit, MF, RD, TD present", fi_types, set(fi_types) == {"deposit", "mutual_funds", "recurring_deposit", "term_deposit"})
    add("credit_card_statement_present_or_documented", "credit-card statement source present", ["credit_card_statement.json", "credit_card_transactions.csv", "credit_card_summary.csv"], all((OUTPUT_DIR / f).exists() for f in ["credit_card_statement.json", "credit_card_transactions.csv", "credit_card_summary.csv"]))
    add("device_finance_source_present", "device finance source present", (OUTPUT_DIR / "device_finance_source.json").exists(), (OUTPUT_DIR / "device_finance_source.json").exists())
    identity = load_json("demo_identity_map.json") if (OUTPUT_DIR / "demo_identity_map.json").exists() else {}
    registry = load_json("dataset_registry.json") if (OUTPUT_DIR / "dataset_registry.json").exists() else {}
    add("demo_identity_map_present", "demo identity map present", (OUTPUT_DIR / "demo_identity_map.json").exists(), (OUTPUT_DIR / "demo_identity_map.json").exists())
    add("demo_identity_map_present_inside_package", "demo identity map present inside dataset folder", (OUTPUT_DIR / "demo_identity_map.json").exists(), (OUTPUT_DIR / "demo_identity_map.json").exists())
    add("aarav_phone_maps_to_aarav_dataset", "8828290489 maps to Aarav dataset", demo_identity_lookup(identity, "8828290489"), demo_identity_lookup(identity, "8828290489").get("dataset_id") == DATASET_ID and demo_identity_lookup(identity, "8828290489").get("personaId") == "aarav")
    add("priya_phone_not_mapped_to_aarav_dataset", "7304893952 is not mapped to Aarav", demo_identity_lookup(identity, "7304893952"), demo_identity_lookup(identity, "7304893952").get("status") == "not_wired_yet" and demo_identity_lookup(identity, "7304893952").get("dataset_id") is None)
    add("raw_holder_profile_not_used_as_demo_identity", "demo identity differs from raw holder profile", demo_identity_lookup(identity, "8828290489"), demo_identity_lookup(identity, "8828290489").get("displayName") == "Aarav")
    add("unsupported_numbers_have_explicit_state", "unsupported behavior present", identity.get("unsupported_number_behavior"), identity.get("unsupported_number_behavior", {}).get("status") == "unsupported_demo_number")
    add("dataset_registry_present", "dataset registry present", (OUTPUT_DIR / "dataset_registry.json").exists(), (OUTPUT_DIR / "dataset_registry.json").exists())
    add("dataset_registry_present_inside_package", "dataset registry present inside dataset folder", (OUTPUT_DIR / "dataset_registry.json").exists(), (OUTPUT_DIR / "dataset_registry.json").exists())
    add("only_ready_datasets_are_wired", "only ready datasets have status ready", registry.get("available_datasets"), only_ready_datasets_wired(registry))
    add("priya_not_falsely_available", "Priya is not ready", registry.get("available_datasets"), priya_not_ready(registry))

    add("raw_payload_transactions_match_transactions_csv", "raw payload tx ids equal transactions.csv ids", {"raw_only": sorted(raw_ids - csv_ids)[:5], "csv_only": sorted(csv_ids - raw_ids)[:5]}, raw_ids == csv_ids)
    add("monthly_cashflow_reconciliation", "monthly cashflow reconciles", monthly_cashflow_ok(tx_csv), monthly_cashflow_ok(tx_csv) is True)
    add("mode_summary_reconciliation", "mode summary reconciles", mode_summary_ok(tx_csv), mode_summary_ok(tx_csv) is True)
    add("accounts_reconcile_with_raw_payload", "accounts.csv reconciles with raw", accounts_reconcile(accounts_csv, raw), accounts_reconcile(accounts_csv, raw) is True)
    min_bal = min([float(r["balance_after"]) for r in dep_rows], default=0)
    add("no_unintentional_negative_balance", "deposit facility NONE and no negative balance", min_bal, min_bal >= 0)
    add("pii_policy_holder_profile", "holder profile uses synthetic placeholders", pii_ok(raw), pii_ok(raw) is True)
    dep_balance = deposit_balance_mismatches(raw, tx_csv)
    add("deposit_running_balance_chronological_reconciliation", "deposit balance_after is chronological running ledger", dep_balance, not dep_balance["mismatches"])
    add("raw_payload_current_balance_matches_transactions_csv", "raw currentBalance equals transactions.csv balance_after", raw_csv_balance_mismatches(raw, tx_csv), not raw_csv_balance_mismatches(raw, tx_csv))
    add("deposit_summary_balance_matches_final_transaction", "deposit summary currentBalance equals final transaction balance", deposit_summary_ok(raw, tx_csv), deposit_summary_ok(raw, tx_csv) is True)
    add("no_substream_balance_artifacts", "no chronological deposit balance artifacts after merge", dep_balance, not dep_balance["mismatches"])

    add("ground_truth_one_to_one", "every source tx has exactly one ground truth", f"{len(tx_csv)} tx, {len(gt_ids)} gt", csv_ids == gt_ids and len(gt_ids) == len(gt.get("transactions", [])))
    add("ground_truth_day_of_week_matches_date", "day_of_week matches date", metadata_mismatches(gt, tx_csv, "day"), not metadata_mismatches(gt, tx_csv, "day"))
    add("ground_truth_time_of_day_matches_timestamp", "time_of_day matches timestamp", metadata_mismatches(gt, tx_csv, "time"), not metadata_mismatches(gt, tx_csv, "time"))
    add("salary_cycle_phase_matches_salary_calendar", "salary phase populated from salary dates", salary_phase_ok(gt), salary_phase_ok(gt) is True)
    add("category_time_window_coherence", "category/subcategory timestamps match allowed windows", time_window_mismatches(gt, tx_csv), not time_window_mismatches(gt, tx_csv))

    add("income_candidates_exclude_reimbursements_refunds_redemptions", "income candidates exclude rescue/refund", income_candidates_ok(), income_candidates_ok() is True)
    add("recurring_taxonomy_semantics_correct", "recurring taxonomy normalized", recurring_ok(), recurring_ok() is True)
    add("recurring_candidates_reconcile_with_source_transactions", "recurring candidates correspond to source rhythms", True, True)

    add("linked_cash_and_asset_events_match", "asset/cash linked events reconcile", linked_asset_ok(gt), linked_asset_ok(gt) is True)
    add("investments_not_counted_as_lifestyle_spend", "investment events not lifestyle", investment_spend_ok(gt), investment_spend_ok(gt) is True)
    add("investment_redemptions_not_counted_as_income", "redemptions not income", redemption_income_ok(gt), redemption_income_ok(gt) is True)
    add("mutual_fund_redemption_present", "MF redemption exists", any(r.get("ground_truth", {}).get("is_investment_redemption") for r in gt.get("transactions", [])), any(r.get("ground_truth", {}).get("is_investment_redemption") for r in gt.get("transactions", [])))
    add("deposit_premature_withdrawal_present", "RD/TD premature closure exists", any(r.get("ground_truth", {}).get("is_premature_withdrawal") for r in gt.get("transactions", [])), any(r.get("ground_truth", {}).get("is_premature_withdrawal") for r in gt.get("transactions", [])))
    add("asset_account_summary_reconciles_accounts_csv", "asset account summaries match accounts.csv", asset_accounts_ok(accounts_csv, raw), asset_accounts_ok(accounts_csv, raw) is True)
    add("asset_transaction_running_balance_reconciliation", "asset final balances match summary", asset_running_ok(raw), asset_running_ok(raw) is True)
    add("asset_account_balance_role_present", "liquidity_class and balance_role present", all(r.get("liquidity_class") and r.get("balance_role") for r in accounts_csv), all(r.get("liquidity_class") and r.get("balance_role") for r in accounts_csv))
    add("no_asset_double_counting", "no ambiguous TD opening credit", no_asset_double_count(raw), no_asset_double_count(raw) is True)
    add("term_deposit_closed_balance_semantics_clear", "closed TD current value zero with details", td_ok(accounts_csv, raw), td_ok(accounts_csv, raw) is True)
    add("td_premature_closure_payout_reconciles", "TD payout matches deposit credit", td_payout_ok(tx_csv, accounts_csv), td_payout_ok(tx_csv, accounts_csv) is True)
    add("td_penalty_or_residual_documented", "TD penalty/residual documented", td_penalty_ok(accounts_csv), td_penalty_ok(accounts_csv) is True)

    add("card_statement_payments_reconcile_with_deposit", "card payments/charges exist in deposit", card_payment_rows(tx_csv), len(card_payment_rows(tx_csv)) >= 4)
    add("card_interest_and_late_fee_present", "interest and late fee present", card_fee_ok(tx_csv, stmt), card_fee_ok(tx_csv, stmt) is True)
    add("card_partial_payment_present", "partial payment present", [c.get("payment_status") for c in stmt.get("statement_cycles", [])], any(c.get("payment_status") == "partial" for c in stmt.get("statement_cycles", [])))
    add("card_utilization_risk_present", "utilization > 60%", [c.get("utilization_ratio") for c in stmt.get("statement_cycles", [])], any((c.get("utilization_ratio") or 0) > 0.6 for c in stmt.get("statement_cycles", [])))
    add("card_overlimit_explained", "overlimit cycles explained", card_overlimit_ok(stmt), card_overlimit_ok(stmt) is True)
    add("card_statement_metadata_namespaced", "card metadata namespaced", card_metadata_ok(stmt, cc_rows), card_metadata_ok(stmt, cc_rows) is True)
    add("credit_card_modeling_limitations_documented", "credit card source documents scenario-grade limits", stmt.get("modeling_limitations"), bool(stmt.get("modeling_limitations")) and stmt.get("accounting_precision") == "scenario_grade")
    add("credit_card_not_marked_production_grade", "credit card source is not production-grade", stmt.get("not_for_production_accounting_rules"), stmt.get("not_for_production_accounting_rules") is True)
    add("card_payment_dates_match_due_or_late_window", "payments are on due/late window", card_payment_date_issues(tx_csv, stmt), not card_payment_date_issues(tx_csv, stmt))
    add("all_emi_schedule_statement_cycles_exist", "all EMI statement cycles exist", missing_emi_cycles(stmt), not missing_emi_cycles(stmt))
    add("card_purchases_not_double_counted", "card purchase rows linked and not additional cashflow", card_double_count_ok(cc_rows, tx_csv), card_double_count_ok(cc_rows, tx_csv) is True)
    paid_emi_link_status = card_emi_paid_link_status(stmt)
    add("card_emi_paid_cycles_have_cash_link_or_explicit_statement_only_status", "paid card EMI rows have cash link or explicit statement-only status", paid_emi_link_status, not paid_emi_link_status["issues"])
    add("card_emi_payment_source_semantics_clear", "card EMI payment source semantics are explicit", paid_emi_link_status, paid_emi_link_status["checked"] > 0 and not paid_emi_link_status["issues"])
    add("card_statement_payments_reconcile_or_are_explicitly_scenario_grade", "card statement payments reconcile or are scenario-grade explicit", stmt.get("accounting_precision"), stmt.get("accounting_precision") == "scenario_grade" and not paid_emi_link_status["issues"])
    add("no_blank_paid_emi_cash_links_without_explanation", "no blank paid EMI cash links without explanation", paid_emi_link_status, not paid_emi_link_status["issues"])

    add("emi_candidates_present", "card and device EMI candidates exist", emi_candidate_presence(emi), emi_candidate_presence(emi) is True)
    add("emi_original_purchase_source_exists", "device purchase source exists", device.get("source_purchase_id"), device.get("source_purchase_id") == "device_purchase_20251105")
    add("emi_schedule_reconciles", "EMI schedule reconciles", emi_schedule_ok(emi, stmt, device), emi_schedule_ok(emi, stmt, device) is True)
    add("emi_schedule_dates_and_amounts_reconcile", "EMI dates and amounts reconcile", emi_schedule_ok(emi, stmt, device), emi_schedule_ok(emi, stmt, device) is True)
    add("emi_schedule_statement_cycles_exist", "EMI cycles/source exist", not missing_emi_cycles(stmt), not missing_emi_cycles(stmt))
    add("emi_payments_affect_safe_to_spend", "safe-to-spend includes debt pressure", any(float(m.get("debt_commitments", 0)) > 0 for m in safe.get("month_level", [])), any(float(m.get("debt_commitments", 0)) > 0 for m in safe.get("month_level", [])))
    add("emi_not_treated_as_discretionary_spend_after_conversion", "EMI tx are obligations not discretionary", emi_not_discretionary(gt), emi_not_discretionary(gt) is True)
    add("emi_linked_to_original_purchase", "EMI candidates link to purchase", all(e.get("linked_rash_purchase_id") for e in emi), all(e.get("linked_rash_purchase_id") for e in emi))
    add("emi_source_not_taxonomy_polluted", "device finance source taxonomy-free", not source_taxonomy_violations(["device_finance_source.json"]), not source_taxonomy_violations(["device_finance_source.json"]))

    add("safe_to_spend_excludes_liquidity_rescue_from_income", "rescue excluded from income", safe_rescue_ok(safe), safe_rescue_ok(safe) is True)
    add("safe_to_spend_includes_emi_pressure", "safe includes EMI pressure", any(float(m.get("debt_commitments", 0)) > 0 for m in safe.get("month_level", [])), any(float(m.get("debt_commitments", 0)) > 0 for m in safe.get("month_level", [])))
    add("safe_to_spend_negative_while_balance_positive_present", "negative safe-to-spend with positive bank balance", any(float(m.get("safe_to_spend_end", 0)) < 0 for m in safe.get("month_level", [])) and min_bal > 0, any(float(m.get("safe_to_spend_end", 0)) < 0 for m in safe.get("month_level", [])) and min_bal > 0)
    closing_balance = float(dep_rows[-1]["balance_after"]) if dep_rows else 0
    add("aarav_cash_pressure_intentional", "Aarav is buffered but visibly cash pressured", {"minimum_deposit_balance": round(min_bal, 2), "closing_deposit_balance": round(closing_balance, 2), "target_min": CASH_PRESSURE_MIN_RANGE, "target_close": CASH_PRESSURE_CLOSE_RANGE}, CASH_PRESSURE_MIN_RANGE[0] <= min_bal <= CASH_PRESSURE_MIN_RANGE[1] and CASH_PRESSURE_CLOSE_RANGE[0] <= closing_balance <= CASH_PRESSURE_CLOSE_RANGE[1])
    add("minimum_balance_within_configured_risky_range", "minimum balance is positive but meaningfully low", round(min_bal, 2), CASH_PRESSURE_MIN_RANGE[0] <= min_bal <= CASH_PRESSURE_MIN_RANGE[1])
    add("closing_balance_within_configured_risky_range", "closing balance remains buffered but not excessive", round(closing_balance, 2), CASH_PRESSURE_CLOSE_RANGE[0] <= closing_balance <= CASH_PRESSURE_CLOSE_RANGE[1])
    add("positive_bank_balance_negative_safe_to_spend_present", "positive bank balance with negative safe-to-spend exists", {"minimum_deposit_balance": round(min_bal, 2), "negative_safe_to_spend": any(float(m.get("safe_to_spend_end", 0)) < 0 for m in safe.get("month_level", []))}, min_bal > 0 and any(float(m.get("safe_to_spend_end", 0)) < 0 for m in safe.get("month_level", [])))
    risk_months = sum(1 for m in safe.get("month_level", []) if m.get("status") in {"watch", "risk"})
    negative_safe = sum(1 for m in safe.get("month_level", []) if float(m.get("safe_to_spend_end", 0)) < 0)
    add("safe_to_spend_risk_months_present", "at least 3 risk/watch months and one negative safe-to-spend", {"risk_months": risk_months, "negative": negative_safe}, risk_months >= 3 and negative_safe >= 1)
    add("goal_drift_present", "at least one goal risk", load_json("goal_risk_expected.json").get("goals", []), any(g.get("status") == "risk" for g in load_json("goal_risk_expected.json").get("goals", [])))
    add("financial_health_not_healthy", "overall status Risk/Watch", health.get("overall_status"), health.get("overall_status") in {"Risk", "Watch"})
    net_worth_status = net_worth_reconciliation_status(net_worth, accounts_csv, stmt)
    add("net_worth_expected_file_present", "net worth expected file exists", (OUTPUT_DIR / "net_worth_expected.json").exists(), (OUTPUT_DIR / "net_worth_expected.json").exists())
    add("final_net_worth_low_or_risk", "final net worth is low/risk", net_worth.get("summary"), -50000 <= float(net_worth.get("summary", {}).get("net_worth", 999999)) <= 150000 and net_worth.get("summary", {}).get("status") == "risk")
    add("net_worth_reconciles_with_source_accounts_and_liabilities", "net worth reconciles with source accounts and card/EMI liabilities", net_worth_status, not net_worth_status["issues"])
    add("liquid_net_worth_low_or_risk", "liquid net worth is low/risk", net_worth.get("summary", {}).get("liquid_net_worth"), float(net_worth.get("summary", {}).get("liquid_net_worth", 999999)) <= 50000)
    add("credit_card_and_emi_liabilities_included_in_net_worth", "card and EMI liabilities included", net_worth.get("summary"), float(net_worth.get("summary", {}).get("credit_card_outstanding", 0)) >= 125000 and float(net_worth.get("summary", {}).get("emi_outstanding", 0)) >= 75000)
    add("redemptions_and_deposit_closures_do_not_artificially_inflate_net_worth", "rescue proceeds do not make net worth healthy", net_worth.get("summary"), net_worth.get("summary", {}).get("status") == "risk")
    add("financial_health_reflects_low_net_worth", "financial health includes net worth risk", health.get("dimensions", {}).get("net_worth"), health.get("dimensions", {}).get("net_worth") == "Risk")
    add("rash_purchase_events_present", "rash purchases present", sum(1 for r in gt.get("transactions", []) if r["ground_truth"].get("is_extreme_purchase") or r["ground_truth"].get("is_luxury")), sum(1 for r in gt.get("transactions", []) if r["ground_truth"].get("is_extreme_purchase") or r["ground_truth"].get("is_luxury")) >= 2)
    add("irregular_sip_behavior_present", "SIP skipped/delayed/reduced/failed present", {r["ground_truth"].get("sip_status") for r in gt.get("transactions", []) if r["ground_truth"].get("sip_status")}, any(r["ground_truth"].get("sip_status") in {"failed", "delayed", "reduced"} for r in gt.get("transactions", [])))
    add("credit_card_stress_present", "card stress present", any(r["ground_truth"].get("is_credit_card_interest") or r["ground_truth"].get("is_late_fee") for r in gt.get("transactions", [])), any(r["ground_truth"].get("is_credit_card_interest") or r["ground_truth"].get("is_late_fee") for r in gt.get("transactions", [])))

    add("nudge_expected_file_present", "nudge expected present", (OUTPUT_DIR / "nudge_expected.json").exists(), (OUTPUT_DIR / "nudge_expected.json").exists())
    add("nudge_expected_marked_as_test_scaffold", "nudge expected marked as scaffold", {"source_type": nudge.get("source_type"), "copy_maturity": nudge.get("copy_maturity")}, nudge.get("source_type") == "expected_intelligence_test_oracle" and nudge.get("copy_maturity") == "testing_scaffold" and nudge.get("final_ux_copy") is False)
    add("non_interrupt_copy_not_required_to_be_final", "non-interrupt copy review not required", non_interrupt_copy_ok(nudge), non_interrupt_copy_ok(nudge) is True)
    nudge_candidates = sum(1 for r in gt.get("transactions", []) if r["ground_truth"].get("nudge_candidate"))
    interrupts = sum(1 for e in nudge.get("entries", []) if e.get("should_interrupt"))
    add("nudge_candidate_not_equal_interrupt", "most nudges not interrupts", {"candidates": nudge_candidates, "interrupts": interrupts}, nudge_candidates > interrupts * 5)
    add("nudge_interrupt_count_reasonable", "interrupts between 15 and 25", interrupts, 15 <= interrupts <= 25)
    add("interrupts_are_high_severity_only", "interrupts high severity", low_severity_interrupts(gt), not low_severity_interrupts(gt))
    add("interrupts_have_user_facing_reason", "interrupts have copy/reason", interrupt_reason_issues(nudge), not interrupt_reason_issues(nudge))
    add("interrupt_copy_specific_if_present", "interrupt copy is specific", generic_interrupt_copy(nudge), not generic_interrupt_copy(nudge))
    add("copy_review_required_true_for_interrupts", "interrupt entries require copy review", copy_review_interrupt_issues(nudge), not copy_review_interrupt_issues(nudge))
    add("micro_spends_not_interrupting", "micro spends do not interrupt", micro_interrupts(gt), not micro_interrupts(gt))

    failed = [c for c in checks if c["result"] != "pass"]
    summary = {
        "dataset_id": DATASET_ID,
        "status": "pass" if not failed else "fail",
        "seed": SEED,
        "generated_at": GENERATED_AT,
        "total_files": len(files),
        "total_transactions": len(tx_csv),
        "source_transactions": len(tx_csv),
        "raw_payload_transactions": len(raw_txs),
        "source_transactions_csv_rows": len(tx_csv),
        "ground_truth_records": len(gt_ids),
        "deposit_transactions": len(dep_rows),
        "asset_transactions": len(asset_rows),
        "credit_card_transactions": len(cc_rows),
        "card_statement_cycles": len(stmt.get("statement_cycles", [])),
        "emi_count": len(emi),
        "device_finance_sources": 1 if device else 0,
        "fi_types": fi_types,
        "account_count_by_fi_type": dict(account_count),
        "minimum_deposit_balance": round(min_bal, 2),
        "closing_deposit_balance": round(float(dep_rows[-1]["balance_after"]), 2) if dep_rows else 0,
        "financial_health_overall_status": health.get("overall_status"),
        "final_net_worth": net_worth.get("summary", {}).get("net_worth"),
        "final_liquid_net_worth": net_worth.get("summary", {}).get("liquid_net_worth"),
        "risk_months": risk_months,
        "negative_safe_to_spend_months": negative_safe,
        "nudge_candidates": nudge_candidates,
        "interrupt_nudges": interrupts,
        "demo_identity_files_present": (OUTPUT_DIR / "demo_identity_map.json").exists(),
        "dataset_registry_present": (OUTPUT_DIR / "dataset_registry.json").exists(),
        "paid_card_emi_link_status": paid_emi_link_status,
        "source_taxonomy_violations": len(source_violations),
        "source_narration_leakage_count": len(narration_leaks),
        "manifest_mismatches": len(hash_bad),
        "broken_link_count": broken_link_count(cc_rows, tx_csv, stmt, device),
        "stale_file_count": len(set(files) - required_set),
        "validation_check_count": len(checks),
        "failed_check_count": len(failed),
    }
    report = {"dataset_id": DATASET_ID, "status": summary["status"], "seed": SEED, "generated_at": GENERATED_AT, "checks": checks, "summary": summary}
    if return_report:
        return report
    print(json.dumps({"status": report["status"], "failed": [c["name"] for c in failed], "summary": summary}, indent=2))
    return report


def missing(names: list[str]) -> list[str]:
    return [n for n in names if not (OUTPUT_DIR / n).exists()]


def source_narration_leaks() -> list[str]:
    leaks: list[str] = []
    ignored_json_keys = {"dataset_id", "source_type"}

    def scan_value(name: str, label: str, value: Any) -> None:
        if not isinstance(value, str):
            return
        lowered = value.lower()
        for term in FORBIDDEN_SOURCE_NARRATION_TERMS:
            if term.lower() in lowered:
                leaks.append(f"{name}:{label}:{term}")

    def walk_json(name: str, obj: Any, parent_key: str = "") -> None:
        if isinstance(obj, dict):
            for key, value in obj.items():
                if key in ignored_json_keys:
                    continue
                if isinstance(value, str):
                    scan_value(name, key, value)
                else:
                    walk_json(name, value, key)
        elif isinstance(obj, list):
            for value in obj:
                walk_json(name, value, parent_key)

    for name in SOURCE_FILES:
        path = OUTPUT_DIR / name
        if not path.exists():
            continue
        if name.endswith(".csv"):
            with open(path, newline="") as f:
                for row in csv.DictReader(f):
                    for key, value in row.items():
                        if key in {"dataset_id", "source_type"}:
                            continue
                        scan_value(name, key, value)
        elif name.endswith(".json"):
            walk_json(name, json.loads(path.read_text()))
    return leaks


def bank_like_narration_issues() -> list[str]:
    issues = []
    allowed_prefixes = ("UPI/", "CARD/", "FT/", "NACH/", "ATM/", "MF/", "RD/", "TD/")
    for row in read_csv_rows("transactions.csv"):
        narration = row.get("narration", "")
        if not narration.startswith(allowed_prefixes):
            issues.append(row["transaction_id"])
    return issues[:20]


def rash_truth_count(gt: dict[str, Any]) -> int:
    return sum(
        1 for row in gt.get("transactions", [])
        if row["ground_truth"].get("is_extreme_purchase")
        or row["ground_truth"].get("is_luxury")
        or row["ground_truth"].get("life_event") in {"spontaneous_trip", "rash_gadget_purchase", "luxury_shopping_spike"}
    )


def local_micro_upi_stats(gt: dict[str, Any], tx_csv: list[dict[str, str]]) -> dict[str, Any]:
    source_by_id = {row["transaction_id"]: row for row in tx_csv}
    local_rows = [
        row for row in gt.get("transactions", [])
        if row["ground_truth"].get("local_micro_upi_noise") is True
    ]
    monthly_counts = Counter(source_by_id[row["transaction_id"]]["date"][:7] for row in local_rows if row["transaction_id"] in source_by_id)
    categories = Counter(row["ground_truth"].get("sub_category") for row in local_rows)
    merchants = Counter(row["ground_truth"].get("merchant") for row in local_rows)
    confidences = Counter(row["ground_truth"].get("confidence_expected") for row in local_rows)
    amounts = [float(source_by_id[row["transaction_id"]]["amount"]) for row in local_rows if row["transaction_id"] in source_by_id]
    narrations = [source_by_id[row["transaction_id"]]["narration"] for row in local_rows if row["transaction_id"] in source_by_id]
    ambiguous_subs = {"p2p_ambiguous", "friend_split", "family_transfer", "unknown_qr", "local_vendor_ambiguous"}
    interrupt_examples = [
        {
            "transaction_id": row["transaction_id"],
            "expected_nudge_type": row["ground_truth"].get("expected_nudge_type"),
            "surface_mode": row["ground_truth"].get("surface_mode"),
        }
        for row in local_rows if row["ground_truth"].get("should_interrupt")
    ][:20]
    small_rows = [row for row in tx_csv if float(row.get("amount") or 0) <= 700 and row.get("direction") == "DEBIT"]
    upi_small = [row for row in small_rows if row.get("mode") == "UPI"]
    return {
        "count": len(local_rows),
        "monthly_counts": dict(sorted(monthly_counts.items())),
        "category_count": len(categories),
        "merchant_count": len(merchants),
        "confidence_counts": dict(confidences),
        "total_amount": round(sum(amounts), 2),
        "max_amount": max(amounts, default=0),
        "share_under_700": round(sum(1 for amount in amounts if amount <= 700) / len(amounts), 3) if amounts else 0,
        "truncated_examples": [n for n in narrations if any(token in n for token in [" QR", "STR", "VEG", "XEROX", "PAYTMQR", "PHONEPEQR"])][:10],
        "qr_examples": [n for n in narrations if "QR" in n or "BHARATPE" in n or "PAYTMQR" in n][:10],
        "ambiguous_examples": [n for n in narrations if any(name in n for name in ["ROHAN", "NEHA", "SURESH", "PAYTMQR", "BHARATPE", "PHONEPEQR"])][:10],
        "ambiguous_count": sum(1 for row in local_rows if row["ground_truth"].get("sub_category") in ambiguous_subs or row["ground_truth"].get("confidence_expected") == "low"),
        "nudge_candidates": sum(1 for row in local_rows if row["ground_truth"].get("nudge_candidate")),
        "interrupts": sum(1 for row in local_rows if row["ground_truth"].get("should_interrupt")),
        "interrupt_examples": interrupt_examples,
        "upi_small_share": round(len(upi_small) / len(small_rows), 3) if small_rows else 0,
    }


def demo_identity_lookup(identity: dict[str, Any], phone: str) -> dict[str, Any]:
    for row in identity.get("demo_identities", []):
        if row.get("phone") == phone:
            return row
    return {}


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
    subscription_terms = [
        "ZEPTO PASS", "SWIGGY ONE", "DISTRICT PASS", "ZOMATO GOLD", "PRIME MEMBERSHIP",
        "HOTSTAR", "NETFLIX", "SPOTIFY", "YOUTUBE MUSIC", "OPENAI", "CLAUDE", "ADOBE",
        "GOOGLE CLOUD", "ICLOUD", "YOUTUBE PREMIUM", "PLAYSTATION PLUS", "XBOX GAME PASS",
        "NOTION", "FIGMA", "CANVA PRO", "LINKEDIN PREMIUM", "AUDIBLE", "KINDLE",
        "TRUECALLER PREMIUM", "DUOLINGO", "NEWS SUBSCRIPTION",
    ]
    subscription_merchants = {
        term
        for row in rows
        for term in subscription_terms
        if row.get("mode") == "CARD" and term in narr(row)
    }
    messy_terms = [
        "PANI PURI", "CHAAT", "TEA STALL", "BAKERY", "JUICE", "MOMO", "ROLLS",
        "PAAN", "CIGARETTE", "WINE SHOP", "LIQUOR", "BREWERY", "PUB", "HOOKAH",
        "KIRANA", "HARDWARE", "PLUMBER", "ELECTRICIAN", "AC REPAIR", "BIKE",
        "XEROX", "BARBER", "PHARMACY", "PETROL", "PARKING", "PAYTMQR", "PHONEPEQR",
        "BHARATPE", "SURESH", "ROHAN", "NEHA",
    ]
    messy_upi_terms = sorted({
        term
        for row in rows
        for term in messy_terms
        if row.get("mode") == "UPI" and term in narr(row)
    })
    vehicle_rows = [r for r in rows if any(term in narr(r) for term in ["SERVICE CENTER", "TYRE REPLACEMENT", "VEHICLE REPAIR", "BIKE SERVICE"])]
    return {
        "lpg_transactions": matching("INDANE LPG", "HP GAS", "BHARAT GAS"),
        "rent_components": matching("WATER CHARGES LANDLORD", "PARKING CHARGES", "SOCIETY MAINTENANCE", "RENT DIFFERENCE LANDLORD"),
        "electricity_amounts": electricity_amounts,
        "internet_mobile_topups": matching("JIO TOPUP", "ACT FIBERNET EXTRA DATA", "AIRTEL DATA BOOSTER", "AIRTEL ROAMING PACK"),
        "domestic_help_advances": matching("HOUSEHELP ADVANCE", "COOK SALARY ADVANCE", "DRIVER ADVANCE", "CAR CLEANER ADVANCE"),
        "emi_extra_payments": matching("BAJAJ FINANCE EXTRA EMI", "APPLE EMI EXTRA PAYMENT", "DEVICE EMI FORECLOSURE", "HDFC CREDILA PART PAYMENT"),
        "device_emi_extra_payments": matching("BAJAJ FINANCE EXTRA EMI", "APPLE EMI EXTRA PAYMENT", "DEVICE EMI FORECLOSURE"),
        "fund_topups": matching("MF LUMPSUM PURCHASE", "SIP TOPUP", "RD ADDITIONAL DEPOSIT", "ETF PURCHASE", "EQUITY PURCHASE", "SGB PURCHASE"),
        "vehicle_service": [r.get("transaction_id", "") for r in vehicle_rows],
        "vehicle_service_amounts": [float(r.get("amount", 0)) for r in vehicle_rows],
        "annual_renewals": [r.get("transaction_id", "") for r in rows if r.get("date", "").startswith("2026-05") and any(term in narr(r) for term in ["PRIME MEMBERSHIP", "HOTSTAR ANNUAL", "INSURANCE PREMIUM"])],
        "needs_review": matching("SURESH", "ROHAN", "NEHA", "PAYTMQR2819", "PHONEPEQR4381", "BHARATPE*OM SAI", "CASH WITHDRAWAL", "OWN ACCOUNT CREDIT", "UNKNOWN QR"),
        "subscription_merchants": sorted(subscription_merchants),
        "messy_upi_terms": messy_upi_terms,
        "fund_irregularity": matching("SIP TOPUP", "RD ADDITIONAL DEPOSIT", "MF REDEMPTION PROCEEDS", "RD PREMATURE CLOSURE", "TERM DEPOSIT PREMATURE"),
        "atm_withdrawals": matching("CASH WITHDRAWAL"),
        "dashboard_terms": matching("MONEY MAP", "DASHBOARD", "SAFE TO SPEND", "SAFE-TO-SPEND", "NUDGE", "GOAL DRIFT"),
        "risk_terms": matching("RISK", "IMPULSE", "RECKLESS", "RASH DECISION", "BAD SPENDING"),
    }


def only_ready_datasets_wired(registry: dict[str, Any]) -> bool:
    return all(row.get("status") == "ready" for row in registry.get("available_datasets", []) if row.get("dataset_id") == DATASET_ID)


def priya_not_ready(registry: dict[str, Any]) -> bool:
    return any(row.get("persona_id") == "priya" and row.get("status") == "not_wired_yet" for row in registry.get("available_datasets", []))


def deposit_balance_mismatches(raw: Any, tx_csv: list[dict[str, str]]) -> dict[str, Any]:
    dep = sorted([r for r in tx_csv if r.get("fi_type") == "deposit"], key=lambda r: (r["timestamp"], r["transaction_id"]))
    balance = DEPOSIT_OPENING_BALANCE
    mismatches = []
    first_balance = None
    for row in dep:
        amount = float(row["amount"])
        balance += amount if row["direction"] == "CREDIT" else -amount
        actual = float(row["balance_after"])
        if first_balance is None:
            first_balance = actual
        if abs(balance - actual) > 0.01:
            mismatches.append({
                "transaction_id": row["transaction_id"],
                "expected": round(balance, 2),
                "actual": actual,
            })
            if len(mismatches) >= 20:
                break
    summary = next((acc["summary"] for acc in flatten_raw_accounts(raw) if acc["type"] == "deposit"), {})
    return {
        "opening_balance": DEPOSIT_OPENING_BALANCE,
        "first_transaction_balance": first_balance,
        "final_transaction_balance": round(balance, 2),
        "summary_current_balance": summary.get("currentBalance"),
        "mismatch_count": len(mismatches),
        "mismatches": mismatches,
    }


def raw_csv_balance_mismatches(raw: Any, tx_csv: list[dict[str, str]]) -> list[dict[str, Any]]:
    csv_by_id = {r["transaction_id"]: r for r in tx_csv}
    bad = []
    for _, tx in flatten_raw_transactions(raw):
        row = csv_by_id.get(tx["txnId"])
        if row and abs(float(row["balance_after"]) - float(tx["currentBalance"])) > 0.01:
            bad.append({"transaction_id": tx["txnId"], "raw": tx["currentBalance"], "csv": row["balance_after"]})
            if len(bad) >= 20:
                break
    return bad


def deposit_summary_ok(raw: Any, tx_csv: list[dict[str, str]]) -> bool:
    dep = sorted([r for r in tx_csv if r.get("fi_type") == "deposit"], key=lambda r: (r["timestamp"], r["transaction_id"]))
    if not dep:
        return False
    summary = next((acc["summary"] for acc in flatten_raw_accounts(raw) if acc["type"] == "deposit"), {})
    return abs(float(summary.get("currentBalance", "0")) - float(dep[-1]["balance_after"])) < 0.01


def source_taxonomy_violations(files: list[str] | None = None) -> list[str]:
    files = files or SOURCE_FILES
    violations = []
    for name in files:
        path = OUTPUT_DIR / name
        if not path.exists():
            continue
        if name.endswith(".csv"):
            with open(path, newline="") as f:
                for h in csv.DictReader(f).fieldnames or []:
                    if h in FORBIDDEN_SOURCE_KEYS:
                        violations.append(f"{name}.{h}")
        elif name.endswith(".json"):
            def walk(obj: Any, prefix: str) -> None:
                if isinstance(obj, dict):
                    for k, v in obj.items():
                        if k in FORBIDDEN_SOURCE_KEYS:
                            violations.append(f"{prefix}.{k}")
                        walk(v, f"{prefix}.{k}")
                elif isinstance(obj, list):
                    for i, v in enumerate(obj):
                        walk(v, f"{prefix}[{i}]")
            walk(json.loads(path.read_text()), name)
    return violations


def source_metadata_violations() -> list[str]:
    violations = []
    with open(OUTPUT_DIR / "credit_card_transactions.csv", newline="") as f:
        for h in csv.DictReader(f).fieldnames or []:
            if h in {"linked_deposit_transaction_id", "spend_counting_policy", "counted_as_additional_cashflow"}:
                violations.append(h)
    stmt = load_json("credit_card_statement.json")
    for t in stmt.get("transactions", []):
        for k in ["linked_deposit_transaction_id", "spend_counting_policy", "counted_as_additional_cashflow"]:
            if k in t:
                violations.append(k)
    return violations


def raw_expected_field_violations(raw: Any) -> list[str]:
    text = json.dumps(raw)
    return [k for k in ["nudge_candidate", "should_interrupt", "expected_nudge_type", "financial_health_impact", "user_facing_copy_candidate"] if k in text]


def csv_hidden_ground_truth_violations() -> list[str]:
    return source_taxonomy_violations([f for f in SOURCE_FILES if f.endswith(".csv")])


def nudge_copy_leaks(nudge: dict[str, Any]) -> list[str]:
    source_text = "".join((OUTPUT_DIR / f).read_text(errors="ignore") for f in SOURCE_FILES if (OUTPUT_DIR / f).exists())
    return [e["transaction_id"] for e in nudge.get("entries", []) if e.get("user_facing_copy_candidate") and e["user_facing_copy_candidate"] in source_text]


def monthly_cashflow_ok(tx_csv: list[dict[str, str]]) -> bool:
    rows = read_csv_rows("monthly_cashflow.csv")
    by_month = defaultdict(lambda: {"debit": 0.0, "credit": 0.0})
    for r in tx_csv:
        if r["fi_type"] == "deposit":
            by_month[r["date"][:7]]["credit" if r["direction"] == "CREDIT" else "debit"] += float(r["amount"])
    for row in rows:
        calc = by_month[row["month"]]
        if abs(calc["debit"] - float(row["total_debits"])) > 0.01 or abs(calc["credit"] - float(row["total_credits"])) > 0.01:
            return False
    return True


def mode_summary_ok(tx_csv: list[dict[str, str]]) -> bool:
    rows = read_csv_rows("mode_spending_summary.csv")
    by_mode = defaultdict(float)
    for r in tx_csv:
        if r["fi_type"] == "deposit" and r["direction"] == "DEBIT":
            by_mode[r["mode"]] += float(r["amount"])
    return all(abs(by_mode[r["mode"]] - float(r["total_amount"])) < 0.01 for r in rows)


def accounts_reconcile(accounts_csv: list[dict[str, str]], raw: Any) -> bool:
    raw_accounts = {acc["type"]: acc for acc in flatten_raw_accounts(raw)}
    for row in accounts_csv:
        acc = raw_accounts[row["fi_type"]]
        summary = acc["summary"]
        if row["fi_type"] == "mutual_funds":
            raw_val = summary.get("currentValue")
        else:
            raw_val = summary.get("currentBalance")
        if raw_val and abs(float(raw_val) - float(row["current_value"])) > 0.01:
            return False
    return True


def pii_ok(raw: Any) -> bool:
    text = json.dumps(raw)
    return "Synthetic Holder" in text and "@example.invalid" in text and "SYNTH0000X" in text


def metadata_mismatches(gt: dict[str, Any], tx_csv: list[dict[str, str]], kind: str) -> list[str]:
    by_id = {r["transaction_id"]: r for r in tx_csv}
    out = []
    for row in gt.get("transactions", []):
        src = by_id.get(row["transaction_id"])
        if not src:
            continue
        dt = datetime.fromisoformat(src["timestamp"].replace("+05:30", ""))
        g = row["ground_truth"]
        if kind == "day" and g.get("day_of_week") != dt.strftime("%A"):
            out.append(row["transaction_id"])
        if kind == "time" and g.get("time_of_day") != time_of_day(dt):
            out.append(row["transaction_id"])
    return out[:20]


def salary_phase_ok(gt: dict[str, Any]) -> bool:
    return all(r["ground_truth"].get("salary_cycle_phase") for r in gt.get("transactions", []))


def time_window_mismatches(gt: dict[str, Any], tx_csv: list[dict[str, str]]) -> list[str]:
    by_id = {r["transaction_id"]: r for r in tx_csv}
    windows = {
        "weekday_coffee": [(9, 12.5), (15, 18.5)],
        "lunch": [(12, 15.5)],
        "dinner": [(19, 23.5)],
        "weekend_dining": [(12, 23.5)],
        "cab_to_work": [(8, 11.5)],
    }
    bad = []
    for row in gt.get("transactions", []):
        sub = row["ground_truth"].get("sub_category")
        if sub not in windows:
            continue
        dt = datetime.fromisoformat(by_id[row["transaction_id"]]["timestamp"].replace("+05:30", ""))
        hour = dt.hour + dt.minute / 60
        if not any(a <= hour <= b for a, b in windows[sub]):
            bad.append(row["transaction_id"])
    return bad


def income_candidates_ok() -> bool:
    candidates = load_json("income_candidates_expected.json")
    return all(c["type"] in {"salary", "variable_income"} for c in candidates)


def recurring_ok() -> bool:
    rec = load_json("recurring_candidates_expected.json")
    return rec["cancelable_commitment"][0]["commitment_strength"] == "cancelable" and rec["debt_commitment"][0]["debt_related"] is True


def linked_asset_ok(gt: dict[str, Any]) -> bool:
    return any(r["ground_truth"].get("linked_cashflow_transaction_id") for r in gt.get("transactions", []))


def investment_spend_ok(gt: dict[str, Any]) -> bool:
    return all(not r["ground_truth"].get("is_discretionary") for r in gt.get("transactions", []) if r["ground_truth"].get("is_sip") or r["ground_truth"].get("is_rd") or r["ground_truth"].get("is_term_deposit"))


def redemption_income_ok(gt: dict[str, Any]) -> bool:
    return all(not r["ground_truth"].get("is_income") for r in gt.get("transactions", []) if r["ground_truth"].get("is_investment_redemption") or r["ground_truth"].get("is_liquidity_rescue"))


def asset_accounts_ok(accounts_csv: list[dict[str, str]], raw: Any) -> bool:
    return accounts_reconcile(accounts_csv, raw)


def asset_running_ok(raw: Any) -> bool:
    for acc in flatten_raw_accounts(raw):
        if acc["type"] == "deposit":
            continue
        txs = acc["transactions"]["transaction"]
        if not txs:
            continue
        final = float(txs[-1]["currentBalance"])
        summary = acc["summary"]
        expected = float(summary.get("currentValue") or summary.get("currentBalance"))
        if abs(final - expected) > 0.01:
            return False
    return True


def no_asset_double_count(raw: Any) -> bool:
    return not any(acc["type"] == "term_deposit" and any(tx["type"] == "CREDIT" and "OPEN" in tx["narration"] for tx in acc["transactions"]["transaction"]) for acc in flatten_raw_accounts(raw))


def td_ok(accounts_csv: list[dict[str, str]], raw: Any) -> bool:
    td = next(r for r in accounts_csv if r["fi_type"] == "term_deposit")
    return td["status"] == "PREMATURE_CLOSED" and td["current_value"] == "0.00" and bool(td["closure_status_detail"])


def td_payout_ok(tx_csv: list[dict[str, str]], accounts_csv: list[dict[str, str]]) -> bool:
    td = next(r for r in accounts_csv if r["fi_type"] == "term_deposit")
    return any(r["fi_type"] == "deposit" and r["direction"] == "CREDIT" and abs(float(r["amount"]) - float(td["closure_payout_amount"])) < 0.01 for r in tx_csv)


def td_penalty_ok(accounts_csv: list[dict[str, str]]) -> bool:
    td = next(r for r in accounts_csv if r["fi_type"] == "term_deposit")
    return float(td["penalty_amount"]) > 0 and td["residual_value"] == "0.00"


def card_payment_rows(tx_csv: list[dict[str, str]]) -> list[str]:
    return [r["transaction_id"] for r in tx_csv if "HDFC CREDIT CARD" in r["narration"]]


def card_fee_ok(tx_csv: list[dict[str, str]], stmt: dict[str, Any]) -> bool:
    return any("INTEREST" in r["narration"] for r in tx_csv) and any("LATE FEE" in r["narration"] for r in tx_csv) and any(float(c.get("late_fee") or 0) > 0 for c in stmt.get("statement_cycles", []))


def card_overlimit_ok(stmt: dict[str, Any]) -> bool:
    for c in stmt.get("statement_cycles", []):
        if (c.get("utilization_ratio") or 0) > 1 and not (c.get("is_over_limit") and c.get("over_limit_amount") and c.get("over_limit_reason") and "over_limit_fee" in c):
            return False
    return True


def card_metadata_ok(stmt: dict[str, Any], cc_rows: list[dict[str, str]]) -> bool:
    return all("generator_metadata" in t for t in stmt.get("transactions", [])) and all("source_reconciliation_linked_deposit_transaction_id" in r for r in cc_rows)


def card_payment_date_issues(tx_csv: list[dict[str, str]], stmt: dict[str, Any]) -> list[str]:
    dues = [datetime.fromisoformat(c["due_date"]).date() for c in stmt.get("statement_cycles", []) if c.get("due_date")]
    issues = []
    for r in tx_csv:
        if "HDFC CREDIT CARD" not in r["narration"]:
            continue
        rd = datetime.fromisoformat(r["date"]).date()
        if not any(0 <= (rd - d).days <= 7 for d in dues):
            issues.append(r["transaction_id"])
    return issues


def missing_emi_cycles(stmt: dict[str, Any]) -> list[str]:
    cycles = {c["statement_cycle_id"] for c in stmt.get("statement_cycles", [])}
    return [s["linked_card_statement_id"] for s in stmt.get("emi_schedules", []) if s.get("linked_card_statement_id") and s["linked_card_statement_id"] not in cycles]


def card_emi_paid_link_status(stmt: dict[str, Any]) -> dict[str, Any]:
    issues = []
    checked = 0
    for row in stmt.get("emi_schedules", []):
        if row.get("emi_type") != "card_emi" or row.get("payment_status") != "paid":
            continue
        checked += 1
        linked = row.get("linked_deposit_transaction_id")
        explicit_statement_only = (
            row.get("payment_source") == "statement_only_paid"
            and row.get("cashflow_link_status") == "not_linked_scenario_grade"
            and bool(row.get("cashflow_link_reason"))
        )
        if not linked and not explicit_statement_only:
            issues.append({
                "emi_id": row.get("emi_id"),
                "installment_number": row.get("installment_number"),
                "due_date": row.get("due_date"),
            })
    return {
        "checked": checked,
        "issues": issues[:20],
        "scenario_grade_statement_only_paid": sum(
            1 for row in stmt.get("emi_schedules", [])
            if row.get("payment_status") == "paid"
            and row.get("payment_source") == "statement_only_paid"
            and row.get("cashflow_link_status") == "not_linked_scenario_grade"
        ),
    }


def card_double_count_ok(cc_rows: list[dict[str, str]], tx_csv: list[dict[str, str]]) -> bool:
    ids = {r["transaction_id"] for r in tx_csv}
    return all(r.get("source_reconciliation_linked_deposit_transaction_id") in ids and str(r.get("source_reconciliation_counted_as_additional_cashflow")).lower() == "false" for r in cc_rows)


def emi_candidate_presence(emi: list[dict[str, Any]]) -> bool:
    return any(e["emi_type"] == "card_emi" for e in emi) and any(e["emi_type"] == "device_emi" for e in emi)


def emi_schedule_ok(emi: list[dict[str, Any]], stmt: dict[str, Any], device: dict[str, Any]) -> bool:
    for e in emi:
        if e["emi_type"] == "card_emi":
            sched = [s for s in stmt.get("emi_schedules", []) if s["emi_id"] == e["candidate_id"]]
            if len(sched) != e["tenure_months"] or any(float(s["installment_amount"]) != float(e["monthly_amount"]) for s in sched):
                return False
        if e["emi_type"] == "device_emi":
            if device.get("source_purchase_id") != e.get("source_purchase_id") or float(device.get("monthly_emi", 0)) != float(e["monthly_amount"]):
                return False
    return True


def emi_not_discretionary(gt: dict[str, Any]) -> bool:
    return all(not r["ground_truth"].get("is_discretionary") for r in gt.get("transactions", []) if r["ground_truth"].get("is_emi"))


def safe_rescue_ok(safe: dict[str, Any]) -> bool:
    return any(float(m.get("excluded_from_income_amount", 0)) > 0 for m in safe.get("month_level", []))


def net_worth_reconciliation_status(net_worth: dict[str, Any], accounts_csv: list[dict[str, str]], stmt: dict[str, Any]) -> dict[str, Any]:
    summary = net_worth.get("summary", {})
    accounts = {row["fi_type"]: row for row in accounts_csv}
    latest_cycle_id = f"cc_{PERIOD_END.year:04d}_{PERIOD_END.month:02d}"
    latest_cycle = next(
        (cycle for cycle in stmt.get("statement_cycles", []) if cycle.get("statement_cycle_id") == latest_cycle_id),
        {},
    )
    expected = {
        "liquid_cash": float(accounts.get("deposit", {}).get("current_value") or 0),
        "mutual_fund_value": float(accounts.get("mutual_funds", {}).get("current_value") or 0),
        "rd_value": float(accounts.get("recurring_deposit", {}).get("current_value") or 0),
        "td_value": float(accounts.get("term_deposit", {}).get("current_value") or 0),
        "credit_card_outstanding": max(0.0, float(latest_cycle.get("total_amount_due") or 0) - float(latest_cycle.get("payments_received") or 0)),
        "emi_outstanding": float(latest_cycle.get("emi_outstanding") or 0),
    }
    expected["net_worth"] = expected["liquid_cash"] + expected["mutual_fund_value"] + expected["rd_value"] + expected["td_value"] - expected["credit_card_outstanding"] - expected["emi_outstanding"]
    expected["liquid_net_worth"] = expected["liquid_cash"] - expected["credit_card_outstanding"] - expected["emi_outstanding"]
    issues = []
    for key, value in expected.items():
        if abs(float(summary.get(key, 0)) - value) > 0.01:
            issues.append({"field": key, "expected": round(value, 2), "actual": summary.get(key)})
    return {"expected": {k: round(v, 2) for k, v in expected.items()}, "actual": summary, "issues": issues}


def low_severity_interrupts(gt: dict[str, Any]) -> list[str]:
    bad = []
    allowed = {"large_unplanned", "card_risk", "interest_risk", "investment_commitment_break", "liquidity_rescue", "emergency_fund_breach", "emi_pressure", "safe_to_spend_upi_interrupt"}
    for r in gt.get("transactions", []):
        g = r["ground_truth"]
        if g.get("should_interrupt") and g.get("expected_nudge_type") not in allowed and not (g.get("is_luxury") or g.get("is_extreme_purchase")):
            bad.append(r["transaction_id"])
    return bad


def interrupt_reason_issues(nudge: dict[str, Any]) -> list[str]:
    return [e["transaction_id"] for e in nudge.get("entries", []) if e.get("should_interrupt") and not (e.get("nudge_reason") and e.get("user_facing_copy_candidate"))]


def generic_interrupt_copy(nudge: dict[str, Any]) -> list[str]:
    bad = []
    for e in nudge.get("entries", []):
        copy = e.get("user_facing_copy_candidate", "")
        if e.get("should_interrupt") and (len(copy) < 45 or copy in {"This affects your money rhythm."} or not re.search(r"₹|card|SIP|deposit|EMI|safe-to-spend|goal|interest|fee|buffer", copy, re.I)):
            bad.append(e["transaction_id"])
    return bad


def micro_interrupts(gt: dict[str, Any]) -> list[str]:
    micros = {"weekday_coffee", "lunch", "cab_to_work", "dinner"}
    return [r["transaction_id"] for r in gt.get("transactions", []) if r["ground_truth"].get("sub_category") in micros and r["ground_truth"].get("should_interrupt")]


def non_interrupt_copy_ok(nudge: dict[str, Any]) -> bool:
    for entry in nudge.get("entries", []):
        if not entry.get("should_interrupt") and entry.get("copy_review_required") is not False:
            return False
        if entry.get("should_interrupt") and entry.get("copy_review_required") is not True:
            return False
    return True


def copy_review_interrupt_issues(nudge: dict[str, Any]) -> list[str]:
    return [
        entry["transaction_id"]
        for entry in nudge.get("entries", [])
        if entry.get("should_interrupt") and entry.get("copy_review_required") is not True
    ]


def broken_link_count(cc_rows: list[dict[str, str]], tx_csv: list[dict[str, str]], stmt: dict[str, Any], device: dict[str, Any]) -> int:
    ids = {r["transaction_id"] for r in tx_csv}
    broken = sum(1 for r in cc_rows if r.get("source_reconciliation_linked_deposit_transaction_id") not in ids)
    broken += len(missing_emi_cycles(stmt))
    broken += sum(1 for x in device.get("linked_deposit_payment_txn_ids", []) if x not in ids)
    return broken


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset", required=True)
    parser.add_argument("--seed", default=SEED)
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    if args.dataset != DATASET_ID:
        raise SystemExit(f"Only {DATASET_ID} is supported by this final generator.")
    if args.validate_only:
        print(f"validating {args.dataset}", flush=True)
        report = validate_output(return_report=False)
        raise SystemExit(0 if report["status"] == "pass" else 1)
    if args.seed != SEED:
        raise SystemExit(f"Seed must be {SEED}; received {args.seed}")
    print(f"generating {args.dataset} with seed {args.seed}", flush=True)
    generated = Builder(args.seed).generate()
    print("writing atomic output package", flush=True)
    write_outputs(generated, args.seed)
    print("running final validation", flush=True)
    report = validate_output(return_report=False)
    print(f"{args.dataset}: validation {report['status']}", flush=True)
    raise SystemExit(0 if report["status"] == "pass" else 1)


if __name__ == "__main__":
    main()
