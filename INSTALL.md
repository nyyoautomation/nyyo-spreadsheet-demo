# Google Sheets kit: one-command install (Mac, Windows, Linux)

This free kit puts a ready-made **Apps Script** automation into **your own Google Sheet**. It is the free 1-click
install kit that comes with the spreadsheet cleanup & automation gig. You don't need to know how to code: copy and
paste the commands below.

What you get in your spreadsheet, under a new **Nyyo kit** menu:

| Tab | What the kit does with it |
|---|---|
| **Data** | Your rows (one per client). The kit **only reads** it, and stamps `last_updated` on rows you edit. |
| **Clean** | Rebuilt from Data: trimmed names, ISO dates (`2025-01-15`), plain amounts (`$1,200.50` -> `1200.5`), digits-only phones, lower-case status, duplicates merged, rows it cannot read kept at the bottom with a `NEEDS REVIEW` note. Sorted by date, then name. |
| **Dashboard** | Clean clients, duplicates merged, rows to review, paid / pending count and total in USD, clients and USD by city. |
| **How to use** | A short guide inside the spreadsheet. |
| **Change log** | One line per action (when, what, details). Keeps the last 500. |

Optional: **a daily refresh** (Clean + Dashboard rebuilt every morning) that you turn on and off from the menu.

- **Time needed:** about 10 minutes the first time, most of it Google's sign-in screens. Then a few seconds.
- **Cost:** free. Open-source parts only (Google's own `clasp` tool 3.4.1, pinned with every dependency in
  `package-lock.json` and checked by hash when installed). A free Google account is enough.
- **Private:** the code runs inside your spreadsheet, under your Google account. Nothing is sent to Nyyo
  Automation. The script can only open **the spreadsheet it is installed in** (`@OnlyCurrentDoc`): it cannot read
  your Drive, your other files or your mailbox.
- **Safe to run again:** every menu item and `setup` can be run as often as you like. Set up never deletes a tab, a
  row or a column; the cleaning never writes to Data; an empty Data tab never wipes a good Clean tab; the daily
  refresh is always exactly one trigger; and before each install `setup` saves a copy of the project's current code
  in `output/backups/` and refuses to replace code that is not the kit's unless you ask.

There are **two ways** to install. Pick one:

- **Way A, automatic (recommended):** one command sends the kit into your spreadsheet. Needs Node.js (Step 1).
- **Way B, copy-paste:** nothing to install on your computer. You paste one file into Google's editor (Step B).

---

## Step 0. Open the spreadsheet you want to use

- **To try the kit first (recommended):** go to https://sheets.new to make a new, empty Google Sheet. On the
  first Set up the kit fills a **Data** tab with 10 messy sample rows so you can see it work.
- **Or start from the template:** in a new Google Sheet, **File > Import > Upload**, pick
  `template/nyyo-sheets-kit-template.xlsx`, choose **Replace spreadsheet**, click **Import data**.
  (`template/sample-data.csv` holds the same rows; if you import the CSV, untick **Convert text to numbers, dates,
  and formulas** so the messy values stay as typed.)
- **Or use your own sheet:** name its tab **Data** and give it these column titles in row 1, in any order:
  `client_id, name, phone, signup_date, amount_usd, status, city`. Set up adds any missing ones (and
  `last_updated`) at the end. It never renames, moves or deletes your columns. Try a copy first:
  **File > Make a copy**.

## Step 1. Install Node.js (Way A only)

Node.js runs `clasp`, the official Google tool that uploads Apps Script code.

### Mac
1. Go to https://nodejs.org and download the **LTS** version (the `.pkg` installer for macOS).
2. Open the downloaded file and click **Continue** until **Install**. Type your Mac password when asked.
3. Check it: open **Terminal** (Cmd + Space, type `Terminal`, Enter), type `node -v` and press Enter.
   You should see `v20` or higher (for example `v22.11.0`).

### Windows 10/11
1. Go to https://nodejs.org, download the **LTS** Windows installer (`.msi`), run it and keep the default options.
2. Close and reopen any PowerShell window, then check with `node -v` (`v20` or higher).

### Linux (Ubuntu / Debian)
Install Node.js 20 or newer from https://nodejs.org/en/download (the distribution's own package is often too
old). Check with `node -v`.

## Step 2. Unzip the kit and open a terminal in its folder

1. Unzip `nyyo-sheets-kit.zip`. You get a folder `nyyo-sheets-kit`.
2. Open a terminal in that folder:
   - **Mac:** open **Terminal**. Type `cd ` (with a space at the end), drag the `nyyo-sheets-kit` folder into the
     Terminal window, press **Enter**.
   - **Windows:** open the folder in File Explorer, click the address bar, type `powershell`, press **Enter**.
   - **Linux:** right-click inside the folder > **Open in Terminal**.

## Step 3. Two things from Google (Way A only, once)

1. **Turn on the Apps Script API** for your account: open https://script.google.com/home/usersettings , click
   **Google Apps Script API** and switch it **On**. (This lets `clasp` upload code. It changes nothing else.)
2. **Copy your Script ID:** in your spreadsheet, click **Extensions > Apps Script**. A new tab opens on the
   spreadsheet's own (empty) script. Click the **gear icon** (Project Settings) on the left. Under **IDs**, click
   **Copy** next to **Script ID**. It is a long code that often starts with `1`. Keep that tab open.
   You can also copy the address of that Apps Script page: the kit finds the ID in it.

## Step 4. Run the kit

### Mac / Linux
```bash
./setup.sh
```
### Windows
```powershell
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

What happens the first time:
1. It makes the one-file version `output/NyyoSheetsKit.gs` (used by Way B and as a fallback).
2. It asks for your **Script ID**: paste it, press Enter. It is kept in `config/script-id.txt`, so it is asked only
   once. (Or give it up front: `./setup.sh --script-id YOUR_ID`, Windows `.\setup.ps1 -ScriptId YOUR_ID`.)
3. It installs `clasp` into the kit folder (about 1 minute, about 280 MB in `node_modules`).
4. A browser page opens to **sign in to Google**. Use the account that owns the spreadsheet. The page says
   *clasp wants to access your Google Account* and lists Apps Script, Drive and other permissions: these are for
   `clasp` on **your** computer, to upload the code. The sign-in is saved in your home folder (`~/.clasprc.json`),
   not in the kit. You can remove it any time: `node_modules/.bin/clasp logout` (and at
   https://myaccount.google.com/permissions ).
5. It saves a copy of what is in the script now (`output/backups/<date-time>-01/`), then uploads the kit:
   `Config.gs`, `Clean.gs`, `Sheets.gs`, `Triggers.gs`, `Menu.gs` and `appsscript.json`.
   You should see `Installed Nyyo Sheets kit 1.0.0 in your Apps Script project.`

Then go to **Step 5**.

> Want to see what would be sent first? `./setup.sh --check` lists the files and contacts nobody.

## Step B. Copy-paste install (no Node.js)

1. On your computer: run `./setup.sh --copy-paste` (Windows: `.\setup.ps1 -CopyPaste`). It copies the code to your
   clipboard when it can. Or simply open the file **`NyyoSheetsKit.gs`** at the top of the kit folder with any text
   editor (Mac: TextEdit; Windows: Notepad) and copy all of it (Cmd/Ctrl + A, then Cmd/Ctrl + C).
2. In your spreadsheet: **Extensions > Apps Script**. Click inside `Code.gs`, select everything (Cmd/Ctrl + A) and
   paste the kit over it (Cmd/Ctrl + V). Click the **Save** icon (or Cmd/Ctrl + S).
3. In the toolbar, next to **Run**, choose **nyyoSetup** in the list, then click **Run**. Google asks for access the
   first time: follow **Step 5, points 2 to 5**. When the log shows *Execution completed*, go back to your
   spreadsheet and reload the page.

## Step 5. First Set up in your spreadsheet (both ways)

1. Go back to the spreadsheet tab and **reload the page** (Cmd + R on Mac, F5 on Windows). After a few seconds a
   **Nyyo kit** menu appears next to **Help**. Click **Nyyo kit > 1. Set up (safe to run again)**.
2. **Authorization required** appears: click **Continue** (or **Review permissions**) and choose your account.
3. **Google hasn't verified this app** appears. This is normal for a script that lives only in your own
   spreadsheet: Google shows it for every script that is not a published add-on. Click **Advanced**, then
   **Go to ... (unsafe)**. (The name shown is the name of your Apps Script project, often "Untitled project".)
4. Google lists what the script may do. With this kit there are exactly three:
   - *See, edit, create and delete only the specific Google Sheets spreadsheets that this application has been
     installed in*: the current spreadsheet only;
   - *Display and run third-party web content in prompts and sidebars inside Google applications*: the menu and the
     small notices at the bottom right;
   - *Allow this application to run when you are not present*: only used if you turn on the daily refresh.
5. Click **Allow**. If nothing seems to happen, click **Nyyo kit > 1. Set up** once more (the first click is
   sometimes used up by the permission screen).

You should now have the tabs **Data**, **Clean**, **Dashboard**, **How to use** and **Change log**. With the sample
rows, a notice says `6 clean row(s), 2 duplicate(s) merged, 1 to review, 1 empty-name row(s) skipped.`

## Using it

- **Your own data:** put your rows in **Data** (paste, type or import), then **Nyyo kit > 2. Clean + refresh
  dashboard**. To remove the sample rows first: select rows 2 to 11 in Data, right-click > **Delete rows**.
- **Load sample data** only works when Data has no rows: it never mixes sample rows into yours.
- **last_updated:** when you edit a cell in Data, the `last_updated` cell of that row gets the date and time. Typing in
  `last_updated` yourself is left alone.
- **Daily refresh:** **Nyyo kit > Turn on daily refresh** rebuilds Clean and Dashboard every day around 6:00 (the
  hour is `dailyRefreshHour` in `Config.gs`; the time zone is the script's, see Troubleshooting). Clicking it again
  never adds a second one. **Turn off daily refresh** removes it.
- **Change the rules:** in **Extensions > Apps Script > Config.gs** you can rename tabs, choose the column that
  identifies a client (`keyColumn`), accepted statuses, sort order and the daily hour. Save, then run Set up again.
- **Update the kit:** run `./setup.sh` again (Way A), or paste the new `NyyoSheetsKit.gs` (Way B). Your tabs and
  rows stay as they are.
- **Uninstall:** **Nyyo kit > Turn off daily refresh**, then in **Extensions > Apps Script** delete the kit files (or
  all the code in `Code.gs` for Way B) and save. The tabs stay; delete them by hand if you want.

---

## Troubleshooting

**The permission screen keeps coming back, or "Authorization failed" / an error page during sign-in.**
Google sometimes mixes up accounts when you are signed in to several at once. Open the spreadsheet in a private
(incognito) window signed in to one account only, and run Set up there. Then it works in your normal window too.

**"Google hasn't verified this app".**
Expected (see Step 5, point 3). The code is the kit's code, in your own spreadsheet, readable in
Extensions > Apps Script. Click **Advanced > Go to ... (unsafe) > Allow**.

**"This app is blocked" (work or school Google account).**
Your organization's admin does not allow unverified scripts. Use a personal Google account, or ask your admin to
allow Apps Script for your account.

**The Nyyo kit menu does not appear.**
Reload the spreadsheet page and wait 5 to 10 seconds. Check in Extensions > Apps Script that the kit files are
there (Way A) or that `Code.gs` starts with `Nyyo Sheets kit` (Way B), and that you clicked Save. You can also run
**nyyoSetup** from the editor (choose it next to Run).

**Way A: "Turn on the Apps Script API".**
Do Step 3, point 1, wait a minute, then run `./setup.sh` again.

**Way A: "Google cannot find that Script ID for your account".**
Copy the ID again from Project Settings (Step 3, point 2) and run `./setup.sh --script-id YOUR_ID`. Make sure the
browser sign-in used the Google account that owns the spreadsheet. To switch accounts:
`node_modules/.bin/clasp logout`, then `./setup.sh`.

**Way A: "Your Apps Script project already holds other code".**
That spreadsheet already has a script (yours or someone else's). Nothing was changed, and a copy of it is in
`output/backups/`. Use a new spreadsheet, or, if you are sure, run `./setup.sh --replace-other-code`
(Windows: `-ReplaceOtherCode`): the kit replaces that code and the copy stays in `output/backups/`.

**Way A: "Node.js not found" or "too old".**
Install Node.js 20 or newer (Step 1), then close and reopen the terminal. Meanwhile `setup` falls back to Way B and
tells you what to paste.

**Way A: "Install failed".**
Check your internet connection. Behind a company proxy, npm may need your proxy settings. Run `./setup.sh` again:
it starts the install over.

**Windows: "running scripts is disabled on this system".**
Use the full command from Step 4 (`powershell -ExecutionPolicy Bypass -File .\setup.ps1`): it allows this script
for this run only.

**Mac: "permission denied: ./setup.sh".**
Run `chmod +x setup.sh` once, or start it with `bash setup.sh`.

**The daily refresh does not run.**
In **Extensions > Apps Script**, click the **clock icon (Triggers)**: you should see one trigger for
`nyyoDailyRefresh`, time-driven, day timer. **Executions** (list icon) shows each run and any error. The hour
follows the script's time zone (Project Settings > *Time zone*; Way A keeps the one your project already had).
A trigger runs as the person who turned it on: turn it on with your own account. Google may run it up to about
15 minutes off the hour.

**last_updated is not stamped.**
It reacts to edits made by a person in the **Data** tab. Changes made by formulas, imports, other scripts or the API
do not count (Google does not report them to scripts). The column title must be exactly `last_updated`.

**Dates come out wrong or end up in NEEDS REVIEW.**
Text dates are read as month first when both readings are possible (`03/04/2025` = March 4). Cells that Google
Sheets already shows as dates are read in the spreadsheet's time zone (File > Settings). If your sheet uses day
first, set File > Settings > **Locale** to your country before importing, so Google turns them into real dates.

**Phone numbers lost their leading 0.**
Google Sheets turned them into numbers when they were typed or imported. Format the phone column as
**Format > Number > Plain text** before pasting, or import the XLSX template, which keeps text as text.

**"Missing column(s) in the Data tab".**
A column title was renamed or deleted. Run **Nyyo kit > 1. Set up**: it adds the missing column at the end (then
fill it), or rename your column back to the name in the message.

**"Data has no rows: Clean and Dashboard kept as they were".**
The kit found no rows under the header in Data, so it did not touch the other tabs. Add rows and run step 2 again.

**Something else.**
Extensions > Apps Script > **Executions** shows the last runs and their errors. The **Change log** tab shows what the
kit did and when.

Questions? Ask in your order chat.
