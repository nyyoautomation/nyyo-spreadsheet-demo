# Google Sheets kit: test report

Tested on **Oct 20, 2026** on the build box: Linux x86_64, Node.js 20.19, npm 11,
Python 3.13, PowerShell 7.4 (Linux). Raw output of every step: [`kit-test-proof/`](kit-test-proof/). The test is
scripted: `tests/run_kit_test.sh` (repo only), and the result is in [23_checks.txt](kit-test-proof/23_checks.txt).

**No real Google account was used.** Three stand-ins replace Google, each kept as small as possible:
- `tests/shim/sheets_shim.js`: an in-memory spreadsheet with the parts of `SpreadsheetApp`, `ScriptApp`
  (triggers), `LockService`, `Utilities` and `Session` the kit calls. The kit's real `.gs` files run in it.
- `tests/fake_clasp/clasp`: plays Google's side of `clasp` (an Apps Script project kept in a folder, sign-in,
  "API not enabled", "project not found"). Used only where a real account would be needed.
- The **real** `clasp` 3.4.1 is used wherever it works offline: installed from the lock file with `npm ci`, listing
  the exact files it would push, and refusing to push when not signed in.

## From scratch
1. The shipped ZIP was unzipped into an **empty folder** (no `node_modules`, no Script ID, no `output`).
2. **Apps Script logic:** 19 unit tests on the source files, then the same 19 on the shipped one-file
   `NyyoSheetsKit.gs` (the copy-paste version).
3. **setup.sh:** copy-paste mode; no Node.js on the PATH; no Script ID; a bad Script ID; `--check` with the real
   clasp (Script ID given as an editor link); the real clasp when not signed in.
4. **Fake Google:** a fresh spreadsheet's script (Google's empty `Code.gs`, New York time zone). First run in a
   terminal (`script` pseudo-terminal): the Script ID is typed at the prompt, the sign-in opens, the kit is pushed.
   Then: again; someone else's `Report.gs` added (refused, then `--replace-other-code`); Apps Script API off; a
   Script ID that is not yours, then back; 4 more runs to check that backups are capped.
5. **setup.ps1** under PowerShell 7: copy-paste, a fresh install (new `node_modules` via `npm ci`), again, other
   code refused, no Script ID.
6. **build_dist.sh** on a throwaway copy of the repo: clean build, then 5 things that must be refused.
7. **Template:** the XLSX and CSV against the sample rows in the code.

## Results (25 of 25 checks passed)
| Check | Result |
|---|---|
| Cleaning rules | 7 date formats + date cells read in the spreadsheet's time zone; impossible dates (`32/13/2025`, `2023-02-29`) refused; `$1,200.50`, `2,100.00 USD`, `450,75`, `1 350` read right; names, phones, IDs normalized |
| Sample sheet | **6 clean rows, 2 duplicates merged, 1 row to review, 1 empty-name row skipped**, exactly [`tests/expected_clean.csv`](../tests/expected_clean.csv); every cleaned value **equals the Python demo's** `cleaned_sample.csv` |
| Dashboard | 6 clients, 4 paid = 5,450.50 USD, pending 1,400.75 USD, by city |
| Running again | Set up x3 + Refresh: same tabs, Data byte for byte, same Clean, How to use not duplicated |
| Data never written by the cleaning | No write call on the Data tab during a refresh |
| Buyer's own sheet | Own column order and extra columns kept, missing kit columns added at the end, no sample mixed in |
| Empty Data / renamed column | Clean and Dashboard **kept as they were**; clear message naming the missing column |
| `last_updated` (onEdit) | Stamps only the edited Data rows; leaves the header, other tabs and a hand-typed stamp alone |
| Daily refresh | 3 clicks = **1 trigger** (daily, 6:00); off removes it; the lock blocks an overlapping run |
| Permissions | Manifest asks for exactly 3 scopes (this spreadsheet only, menu, triggers); `@OnlyCurrentDoc`; no Drive, mail or web requests in the code |
| One-file version | Valid JavaScript; rebuilt by `setup.sh` and by `setup.ps1` **byte for byte identical** to the shipped file |
| No Node.js | Falls back to copy-paste with the steps, exit code 1 |
| Real clasp | `npm ci` installs exactly `@google/clasp@3.4.1` from `package-lock.json` (hash-checked); `--check` lists the 6 kit files and sends nothing; not signed in: exit code 4 with what to do |
| Fake Google | First run pushes the 6 files and **keeps the project's time zone**; Google's empty starter file is backed up then replaced; second run identical; other code **refused** (exit 3, project untouched, copy saved) unless `--replace-other-code` (copy kept); API off and wrong ID: exit 4 with the fix; old Script ID kept as `.previous` |
| Backups | Every run gets its own new folder, even several in one second; capped at the last 10 |
| PowerShell 7 | Same results as bash: fresh install, re-run, refusal of other code, no Script ID |
| `scripts/build_dist.sh` | Clean copy builds the **same ZIP** (reproducible); **refuses** a buyer's Script ID, a clasp sign-in file with a token, a fake AWS key, an e-mail address and payment wording (see [21_build_dist_refusal.txt](kit-test-proof/21_build_dist_refusal.txt)) |
| Template | XLSX and CSV hold exactly the 10 sample rows of the code; XLSX cells stored as text |

## Not tested
- **A real Google account:** the real `clasp login` and `clasp push`, Google's permission and "unverified app"
  screens, the real `onOpen` menu, real triggers and real `onEdit` events. They were checked against the stand-ins
  above, which follow Google's documented behaviour but are not Google.
- **Real Mac and Windows machines:** Terminal on macOS, Windows PowerShell 5.1 and `clasp.cmd` on Windows (the
  script avoids PowerShell 7-only syntax), clipboard copy and opening TextEdit / Notepad.
- Importing the XLSX / CSV into Google Sheets (checked with openpyxl only), and very large sheets (tested on small
  samples; Apps Script has a 6-minute limit per run).
