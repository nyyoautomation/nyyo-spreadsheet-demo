# Messy spreadsheet → clean table + dashboard

> **For non-technical clients — start here**
>
> **What it does:** Takes a messy Excel/CSV (duplicates, weird dates, `$1,200` vs `1200,5`, mixed status) and returns a clean table plus a small summary dashboard.
>
> **Try it (2 steps):**
> 1. Download [`cleanup_demo.xlsx`](./cleanup_demo.xlsx) and open tabs `BEFORE_messy` → `AFTER_clean` → `DASHBOARD`.
> 2. Or run `python clean_demo.py` and open `cleaned_sample.csv`.
>
> **Business benefit:** finance / ops stop fighting the sheet every week. Typical cleanup from **$45** (then $159 / $399 depending on size). Delivery: 1 / 3 / 5 days by tier.

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

## FREE · 1-click install kit included: the automation in your own Google Sheet
Included free with every package that includes Apps Script (Standard and Pro). A ready-made Apps Script automation that installs into **your** Google Sheet with
one command, or by pasting one file: a **Nyyo kit** menu cleans a messy **Data** tab into a **Clean** tab (same rules
as this demo), builds a **Dashboard**, stamps `last_updated` on edited rows and, if you want, refreshes everything
once a day. A sample sheet template (XLSX + CSV) is included so you can see it work first.

1. Download [`dist/nyyo-sheets-kit.zip`](https://github.com/nyyoautomation/nyyo-spreadsheet-demo/raw/main/dist/nyyo-sheets-kit.zip) and unzip it.
2. Mac / Linux: `./setup.sh` · Windows: `powershell -ExecutionPolicy Bypass -File .\setup.ps1` (sends the code with
   Google's own `clasp` tool). No Node.js? Paste `NyyoSheetsKit.gs` into **Extensions > Apps Script** instead.
3. In your Sheet: reload, then **Nyyo kit > 1. Set up**.

- **Minimal access:** `@OnlyCurrentDoc`, so the script can open only the spreadsheet it is installed in (no Drive,
  no mailbox, no outside requests). Three permissions in total, each explained in the guide.
- **Safe to run again:** Set up never deletes a tab, row or column; the cleaning never writes to your Data tab; an
  empty Data tab never wipes a good result; the daily refresh is always one trigger; `setup` backs up the project's
  current code before each install and never replaces other code unless you ask.
- **Pinned:** `clasp` 3.4.1 with every dependency locked by hash in `package-lock.json`.

Beginner guide (Mac first), permissions screen, "unverified app" warning and triggers: **[INSTALL.md](INSTALL.md)**.
Test proof: [docs/TESTING.md](docs/TESTING.md). Licence: MIT ([LICENSE](LICENSE)).

| Path | Contents |
|---|---|
| `setup.sh`, `setup.ps1` | One-command install (Mac/Linux, Windows) or `--copy-paste` / `-CopyPaste` |
| `apps-script/` | The kit's Apps Script files and manifest (`Config.gs` holds the settings you may change) |
| `NyyoSheetsKit.gs` (in the ZIP) | The same code in one file, for copy-paste |
| `template/` | Sample sheet: `nyyo-sheets-kit-template.xlsx` and `sample-data.csv` |
| `tests/`, `docs/kit-test-proof/` | Unit tests with a stand-in for Google Sheets, from-scratch test and its raw output |
| `scripts/build_dist.sh` | Builds the ZIP; refuses to package keys, Google sign-in files or your own settings |
| `dist/` | The kit ZIP and its SHA-256 |

Questions? Ask in your order chat.

## What’s for sale

| | |
|---|---|
| **Product** | Cleanup / formulas / light dashboard |
| **From** | **$45 / $159 / $399** |
| **Includes** | Cleaned file · HOWTO · 1 revision · optional Apps Script |

FREE “How to use” tab + change log with every cleanup.

→ Available on LaborX · [Profile & packages](https://github.com/nyyoautomation)

## How to order

Available on LaborX · [Profile & packages](https://github.com/nyyoautomation)

Questions? Ask in your order chat.

