#!/usr/bin/env bash
# Nyyo Sheets kit - install the Apps Script automations into your own Google Sheet (Mac / Linux).
# Free 1-click install kit, MIT licence. Nyyo Automation.
#
#   ./setup.sh                          installs the kit into your Sheet with clasp (asks for your Script ID once)
#   ./setup.sh --script-id ID_OR_LINK   same, giving the Script ID (or the Apps Script editor link) up front
#   ./setup.sh --copy-paste             no Node.js needed: makes output/NyyoSheetsKit.gs to paste by hand
#   ./setup.sh --check                  checks the kit and your settings; sends nothing to Google
#
# Options: --replace-other-code (your Apps Script project already holds other code), --no-open, --help
# Safe to run again: your Script ID is kept, the install is reused, the project's current code is backed up
# in output/backups/ before every push, and other code is never replaced unless you ask.
set -euo pipefail

KIT_VERSION="1.0.0"
KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
ORDER="Config.gs Clean.gs Sheets.gs Triggers.gs Menu.gs"
say()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die()  { local code="$1"; shift; printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit "$code"; }
usage() { sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

MODE=clasp; CHECK=0; OPEN=1; REPLACE=0; NEW_ID=""
while [ $# -gt 0 ]; do
  case "$1" in
    --copy-paste) MODE=copy ;;
    --check) CHECK=1 ;;
    --no-open) OPEN=0 ;;
    --replace-other-code) REPLACE=1 ;;
    --script-id) [ $# -ge 2 ] || die 3 "--script-id needs a value"; NEW_ID="$2"; shift ;;
    -h|--help) usage ;;
    *) die 3 "Unknown option: $1 (see ./setup.sh --help)" ;;
  esac; shift
done
cd "$KIT_DIR"
for f in $ORDER appsscript.json; do [ -f "apps-script/$f" ] || die 3 "Kit file apps-script/$f is missing: run this script from the unzipped kit folder."; done
mkdir -p output config

# ---- 1. The one-file version (always made: it is also the fallback) ----
BUNDLE="output/NyyoSheetsKit.gs"
{
  printf '/**\n * Nyyo Sheets kit %s - one-file copy-paste version, built from apps-script/ by setup.\n' "$KIT_VERSION"
  printf ' * Paste ALL of this into Extensions > Apps Script (replace what is there), click Save,\n'
  printf ' * choose nyyoSetup next to Run, click Run and allow access. Then reload the spreadsheet tab.\n */\n'
  for f in $ORDER; do printf '\n// ===== %s =====\n' "$f"; tr -d '\r' < "apps-script/$f"; done
} > "$BUNDLE.tmp" && mv -f "$BUNDLE.tmp" "$BUNDLE"
say "Copy-paste file ready: $BUNDLE"

copy_paste_help() {
  local copied=""
  if command -v pbcopy >/dev/null 2>&1; then pbcopy < "$BUNDLE" && copied=1
  elif command -v wl-copy >/dev/null 2>&1; then wl-copy < "$BUNDLE" && copied=1
  elif command -v xclip >/dev/null 2>&1; then xclip -selection clipboard < "$BUNDLE" && copied=1; fi
  [ -n "$copied" ] && say "The code is now in your clipboard." || say "Open $BUNDLE and copy all of it (Cmd/Ctrl + A, then Cmd/Ctrl + C)."
  say "In your Google Sheet: Extensions > Apps Script, select everything in Code.gs, paste, click Save."
  say "Choose nyyoSetup next to Run, click Run and allow access (INSTALL.md, Step 5). Then reload the Sheet: menu 'Nyyo kit'."
  if [ "$OPEN" = 1 ] && [ -t 1 ] && [ "$(uname -s)" = Darwin ]; then open -e "$BUNDLE" || true; fi
}
if [ "$MODE" = copy ]; then copy_paste_help; exit 0; fi

# ---- 2. Node.js (for clasp, Google's Apps Script tool). Without it: copy-paste instead ----
NODE_OK=0
if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
  NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
  if [ "$NODE_MAJOR" -ge 20 ] 2>/dev/null; then NODE_OK=1; else warn "Node.js $(node -v) is too old (20 or newer is needed)."; fi
else
  warn "Node.js not found."
fi
if [ "$NODE_OK" = 0 ]; then
  warn "Using the copy-paste install instead (2 minutes by hand). For the automatic one, install Node.js (INSTALL.md, Step 1) and run ./setup.sh again."
  copy_paste_help; exit 1
fi

# ---- 3. Your Script ID (asked once, kept in config/script-id.txt) ----
ID_FILE="config/script-id.txt"
parse_id() {
  local v; v="$(printf '%s' "$1" | tr -d '[:space:]')"
  case "$v" in *"/projects/"*) v="${v#*/projects/}"; v="${v%%/*}" ;; *"/d/"*) v="${v#*/d/}"; v="${v%%/*}" ;; esac
  v="${v%%\?*}"; v="${v%%#*}"
  printf '%s' "$v" | grep -Eq '^[A-Za-z0-9_-]{25,120}$' || return 1
  printf '%s' "$v"
}
SCRIPT_ID=""
if [ -n "$NEW_ID" ]; then
  SCRIPT_ID="$(parse_id "$NEW_ID")" || die 3 "That does not look like a Script ID: copy it from Apps Script > Project Settings > IDs (INSTALL.md, Step 3)."
elif [ -f "$ID_FILE" ]; then
  SCRIPT_ID="$(parse_id "$(cat "$ID_FILE")")" || die 3 "config/script-id.txt does not hold a valid Script ID. Run ./setup.sh --script-id YOUR_ID"
elif [ -t 0 ]; then
  say "Open your Sheet > Extensions > Apps Script > Project Settings (gear icon) and copy the Script ID."
  printf 'Paste the Script ID (or the Apps Script page link) here, then press Enter: '
  read -r answer || true
  SCRIPT_ID="$(parse_id "$answer")" || die 3 "That does not look like a Script ID (INSTALL.md, Step 3). Run ./setup.sh again."
else
  die 3 "No Script ID yet: run ./setup.sh --script-id YOUR_SCRIPT_ID (INSTALL.md, Step 3)."
fi
if [ "$(cat "$ID_FILE" 2>/dev/null)" != "$SCRIPT_ID" ]; then
  [ -f "$ID_FILE" ] && cp -f "$ID_FILE" "$ID_FILE.previous"
  printf '%s\n' "$SCRIPT_ID" > "$ID_FILE.tmp" && mv -f "$ID_FILE.tmp" "$ID_FILE"
  say "Saved your Script ID in $ID_FILE."
fi

# ---- 4. clasp, pinned in package-lock.json (installed once in node_modules, checked by hash) ----
hash_file() { { command -v sha256sum >/dev/null 2>&1 && sha256sum "$1" || shasum -a 256 "$1"; } | cut -c1-16; }
DEPS_HASH="$(hash_file package-lock.json)"
if [ "$(cat node_modules/.nyyo-deps 2>/dev/null)" = "$DEPS_HASH" ] && [ -x node_modules/.bin/clasp ]; then say "clasp already installed."
else
  say "Installing clasp $( sed -n 's/.*"@google\/clasp": "\([0-9.]*\)".*/\1/p' package.json) (first time only: about 1 minute)..."
  npm ci --ignore-scripts --no-audit --no-fund --update-notifier=false --loglevel=error >/dev/null || die 4 "Install failed. Check your internet connection and run ./setup.sh again."
  echo "$DEPS_HASH" > node_modules/.nyyo-deps
fi
CLASP="${NYYO_CLASP:-$KIT_DIR/node_modules/.bin/clasp}"

# ---- 5. Stage exactly the files to push ----
PUSH="output/push"; rm -rf "$PUSH"; mkdir -p "$PUSH"
for f in $ORDER appsscript.json; do tr -d '\r' < "apps-script/$f" > "$PUSH/$f"; done
write_project() { printf '{"scriptId": "%s", "rootDir": ".", "scriptExtensions": [".gs"]}\n' "$SCRIPT_ID" > "$1/.clasp.json"; }
write_project "$PUSH"
google_error() {  # $1 = log file
  if grep -qi 'Apps Script API' "$1"; then die 4 "Turn on the Apps Script API at https://script.google.com/home/usersettings , wait a minute, then run ./setup.sh again."
  elif grep -Eqi 'not found|404|does not have permission|permission denied|403' "$1"; then die 4 "Google cannot find that Script ID for your account. Check the ID (INSTALL.md, Step 3) and that you signed in with the account that owns the Sheet."
  elif grep -Eqi 'invalid_grant|credentials|log ?in' "$1"; then die 4 "Your Google sign-in has expired: run node_modules/.bin/clasp logout, then ./setup.sh again."
  else die 4 "Google returned an error (shown above). See INSTALL.md, Troubleshooting."; fi
}
if [ "$CHECK" = 1 ]; then
  say "Check only: these files would be sent to your Apps Script project $SCRIPT_ID"
  (cd "$PUSH" && "$CLASP" show-file-status) || die 4 "clasp could not read the kit files."
  say "Check finished. Nothing was sent to Google."; exit 0
fi

# ---- 6. Google sign-in (once; clasp keeps it in your home folder, outside this kit) ----
if "$CLASP" show-authorized-user 2>&1 | grep -qi 'not logged in'; then
  [ -t 0 ] || die 4 "Not signed in to Google yet: run ./setup.sh in a Terminal window so the sign-in page can open."
  say "A browser page opens: sign in with the Google account that owns the Sheet and click Allow."
  "$CLASP" login || die 4 "Google sign-in did not finish. Run ./setup.sh again."
fi

# ---- 7. Back up what is in the project now, and never replace other code silently ----
STAMP="$(date '+%Y%m%d-%H%M%S')"; n=1; BK="$(printf 'output/backups/%s-%02d' "$STAMP" "$n")"
while [ -e "$BK" ]; do n=$((n+1)); BK="$(printf 'output/backups/%s-%02d' "$STAMP" "$n")"; done  # always a new, empty folder
mkdir -p "$BK"; write_project "$BK"
LOG="output/last-google-reply.txt"
set +e; (cd "$BK" && "$CLASP" pull) > "$LOG" 2>&1; RC=$?; set -e
cat "$LOG"
[ "$RC" = 0 ] || google_error "$LOG"
rm -f "$BK/.clasp.json"
OTHER=""
for f in $(cd "$BK" && find . -type f ! -name appsscript.json | sed 's#^\./##' | sort); do
  case " $ORDER " in *" $f "*) continue ;; esac
  if [ "$f" = Code.gs ] && [ "$(tr -d '[:space:]' < "$BK/$f")" = "functionmyFunction(){}" ]; then continue; fi  # Google's empty starter file
  OTHER="$OTHER $f"
done
if [ -n "$OTHER" ] && [ "$REPLACE" = 0 ]; then
  die 3 "Your Apps Script project already holds other code:$OTHER. Nothing was changed (copy saved in $BK). Use a new Sheet, or run ./setup.sh --replace-other-code to replace it (the copy stays)."
fi
[ -n "$OTHER" ] && warn "Replacing other code:$OTHER (a copy is in $BK)."
# keep the time zone already set on the project (it decides the hour of the daily refresh)
if [ -f "$BK/appsscript.json" ]; then
  node -e 'const fs=require("fs");const [b,p]=process.argv.slice(1);try{const tz=JSON.parse(fs.readFileSync(b,"utf8")).timeZone;if(tz){const m=JSON.parse(fs.readFileSync(p,"utf8"));m.timeZone=tz;fs.writeFileSync(p,JSON.stringify(m,null,2)+"\n");}}catch(e){}' "$BK/appsscript.json" "$PUSH/appsscript.json"
fi
N_BK="$(ls -1d output/backups/*/ 2>/dev/null | wc -l | tr -d ' ')"
ls -1d output/backups/*/ 2>/dev/null | sort | awk -v n="$N_BK" 'NR <= n - 10' | while read -r old; do rm -rf "$old"; done  # keep the last 10

# ---- 8. Push ----
say "Sending the kit to your Apps Script project..."
set +e; (cd "$PUSH" && "$CLASP" push --force) > "$LOG" 2>&1; RC=$?; set -e
cat "$LOG"
[ "$RC" = 0 ] || google_error "$LOG"
echo
say "Installed Nyyo Sheets kit $KIT_VERSION in your Apps Script project."
say "Next, in your Sheet: reload the tab, then menu Nyyo kit > 1. Set up (Google asks for access the first time: INSTALL.md, Step 5)."
if [ "$OPEN" = 1 ] && [ -t 1 ]; then (cd "$PUSH" && "$CLASP" open-container >/dev/null 2>&1) || true; fi
exit 0
