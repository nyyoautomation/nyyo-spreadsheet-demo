# Messy spreadsheet → clean table + dashboard

> **For non-technical clients — start here**
>
> **What it does:** Takes a messy Excel/CSV (duplicates, weird dates, `$1,200` vs `1200,5`, mixed status) and returns a clean table plus a small summary dashboard.
>
> **Try it (2 steps):**
> 1. Download [`cleanup_demo.xlsx`](./cleanup_demo.xlsx) and open tabs `BEFORE_messy` → `AFTER_clean` → `DASHBOARD`.
> 2. Or run `python clean_demo.py` and open `cleaned_sample.csv`.
>
> **Business benefit:** finance / ops stop fighting the sheet every week. Typical cleanup **$35–120** depending on size.

![Demo](docs/demo.gif)

**File:** [cleanup_demo.xlsx](./cleanup_demo.xlsx) · **CSV sample:** [cleaned_sample.csv](./cleaned_sample.csv)  
**Brand:** [Nyyo Automation](https://github.com/nyyoautomation)

[![Python](https://img.shields.io/badge/Python-3776AB?style=flat&logo=python&logoColor=white)](#)
[![pandas](https://img.shields.io/badge/openpyxl-Excel-150458?style=flat)](#)
[![Sheets](https://img.shields.io/badge/Google%20Sheets-34A853?style=flat&logo=googlesheets&logoColor=white)](#)

---

## What gets fixed

- Mixed date formats → ISO `YYYY-MM-DD`
- Currency symbols / locale decimal commas → float amounts
- Duplicate people (same email) → merged
- Inconsistent status / city casing → normalized
- Bad rows → flagged, not silently deleted

## Run

```bash
python clean_demo.py
```

## What’s for sale

| | |
|---|---|
| **Product** | Cleanup / formulas / light dashboard |
| **From** | **$35–$120** |
| **Includes** | Cleaned file · HOWTO · 1 revision · optional Apps Script |

First **100 rows** sample free so you can check quality.

→ [Packages & contact](https://github.com/nyyoautomation) · [LaborX — Nyyo Automation](https://laborx.com/freelancers/users/id475124)

## Hire me

1. Open an **issue** with: goal · deadline · budget  
2. Or message **[LaborX — Nyyo Automation](https://laborx.com/freelancers/users/id475124)**

Crypto: USDC / SOL / ETH / BTC.
