#!/usr/bin/env python3
"""
Nyyo Automation — Spreadsheet cleanup demo
Takes a messy CSV/XLSX-like table and produces normalized rows:
- trim + title-case names
- lowercase emails
- digits-only phones
- ISO dates
- float amounts (strip currency symbols / European decimal commas)
- merge duplicates by email
- flag invalid rows instead of silently dropping money data
"""
from __future__ import annotations

import csv
import re
from datetime import datetime
from pathlib import Path

RAW = [
    ["  alice smith ", "Alice.Smith@Email.COM", "555-0101", "01/15/2025", "$1,200.50", "paid", "boston"],
    ["Bob Jones", "bob@test.com", "+1 555 0102", "2025-01-20", "800", "PAID", "Boston"],
    ["alice smith", "alice.smith@email.com", "5550101", "15/01/2025", "1200.5", "Paid", "BOSTON"],
    ["Carol Nguyen", "", "555.0103", "Feb 3 2025", "950 USD ", "pending", "denver"],
    ["  DANIEL  LEE", "DAN@X.IO", "(555) 010-4", "2025/02/10", "2,100.00 USD", "paid ", "seattle"],
    ["Eve Martin", "eve@x.io", "n/a", "32/13/2025", "abc", "unknown", ""],
    ["Bob Jones", "bob@test.com", "555-0102", "20-01-2025", "800.00", "paid", "boston"],
    ["Fatima Zahra", "f.zahra@mail.io", "+44 7700 900123", "2025-03-01", "450,75", "pending", "Austin"],
    ["", "ghost@x.com", "555", "2025-03-05", "0", "paid", "Miami"],
    ["Hugo Blanc", "hugo@blanc.io", "05550109", "05/03/25", "1 350", "PAID", "chicago"],
]


def norm_name(s: str) -> str:
    return " ".join(s.split()).title()


def norm_email(s: str) -> str:
    return s.strip().lower()


def norm_phone(s: str) -> str:
    digits = re.sub(r"\D", "", s or "")
    return digits if len(digits) >= 6 else ""


def parse_date(s: str):
    s = (s or "").strip()
    for fmt in ("%Y-%m-%d", "%m/%d/%Y", "%d/%m/%Y", "%Y/%m/%d", "%d-%m-%Y", "%b %d %Y", "%d/%m/%y"):
        try:
            return datetime.strptime(s, fmt).date().isoformat()
        except ValueError:
            continue
    return None


def parse_amount(s: str):
    s = (s or "").strip()
    s = s.replace("\u20ac", "").replace("$", "").replace("USD", "").replace(" ", "")
    s = s.replace(",", ".") if s.count(",") == 1 and s.count(".") == 0 else s.replace(",", "")
    try:
        return round(float(re.sub(r"[^0-9.\-]", "", s)), 2)
    except ValueError:
        return None


def clean(rows: list[list[str]]) -> list[dict]:
    by_email: dict[str, dict] = {}
    order: list[str] = []
    flagged = []
    for name, email, phone, date, amount, status, city in rows:
        name_n = norm_name(name)
        if not name_n:
            continue  # drop blank-name
        email_n = norm_email(email)
        phone_n = norm_phone(phone)
        date_n = parse_date(date)
        amount_n = parse_amount(amount)
        status_n = (status or "").strip().lower() or None
        city_n = (city or "").strip().title()
        notes = []
        if date_n is None or amount_n is None or status_n not in {"paid", "pending"}:
            notes.append("INVALID: needs manual review")
            flagged.append(
                {
                    "name": name_n,
                    "email": email_n,
                    "phone_e164_like": phone_n,
                    "signup_date": date_n,
                    "amount_usd": amount_n,
                    "status": status_n,
                    "city": city_n,
                    "notes": "; ".join(notes),
                }
            )
            continue
        key = email_n or f"{name_n}|{phone_n}"
        if key in by_email:
            by_email[key]["notes"] = "merged duplicate rows"
            # keep earliest date, sum amounts if both paid? for demo keep first amount
            continue
        by_email[key] = {
            "name": name_n,
            "email": email_n,
            "phone_e164_like": phone_n,
            "signup_date": date_n,
            "amount_usd": amount_n,
            "status": status_n,
            "city": city_n,
            "notes": "",
        }
        order.append(key)
    return [by_email[k] for k in order] + flagged


def main() -> None:
    rows = clean(RAW)
    out = Path("cleaned_sample.csv")
    fields = ["name", "email", "phone_e164_like", "signup_date", "amount_usd", "status", "city", "notes"]
    with out.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        w.writerows(rows)
    print(f"Wrote {len(rows)} rows → {out.resolve()}")


if __name__ == "__main__":
    main()
