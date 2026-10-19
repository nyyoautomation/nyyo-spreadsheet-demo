#!/usr/bin/env bash
# From-scratch test of the shipped ZIP (build box; needs node 20+, npm, python3 + openpyxl, docker; pwsh optional).
#   tests/run_kit_test.sh [path/to/nyyo-sheets-kit.zip]
# Writes raw logs and checks to docs/kit-test-proof/. No real Google account is used: the Apps Script code runs
# against an in-memory stand-in (tests/shim), and "Google" is played by tests/fake_clasp/clasp, except where the
# real clasp 3.4.1 is used offline (install, file list, "not signed in").
set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"; ZIP="${1:-$REPO/dist/nyyo-sheets-kit.zip}"
PROOF="$REPO/docs/kit-test-proof"; rm -rf "$PROOF"; mkdir -p "$PROOF"
PWSH="$(command -v pwsh || echo /tmp/pwsh/pwsh)"
W="$(mktemp -d /tmp/sheetskit-test.XXXX)"; K="$W/nyyo-sheets-kit"; G="$W/google"
REAL_ID="1KitTestScriptIdAbCdEfGhIjKlMnOpQrStUvWxYz0123456789_-xy"
OTHER_ID="1SomeoneElsesProjectAbCdEfGhIjKlMnOpQrStUvWxYz012345678"
PASS=0; FAILN=0
check() { if eval "$2"; then echo "PASS  $1"; PASS=$((PASS+1)); else echo "FAIL  $1"; FAILN=$((FAILN+1)); fi; }
# run NAME CMD...: raw output to the proof file; the exit code is taken straight from the command (rc=$? right
# after it, before any echo), then written as the last line.
run() {
  local name="$1"; shift; local rc
  { echo "\$ $*"; echo; } > "$PROOF/$name"
  "$@" >> "$PROOF/$name" 2>&1; rc=$?
  sed -i 's/\x1b\[[0-9;]*m//g; s/\r$//' "$PROOF/$name"
  { echo; echo "[exit code $rc]"; } >> "$PROOF/$name"
  return 0
}
code() { sed -n 's/^\[exit code \([0-9]*\)\]$/\1/p' "$PROOF/$1"; }
h() { sha256sum "$1" | cut -d' ' -f1; }
FAKE=(env NYYO_CLASP="$REPO/tests/fake_clasp/clasp" FAKE_GOOGLE="$G" FAKE_SCRIPT_ID="$REAL_ID")
SH() { (cd "$K" && "${FAKE[@]}" ./setup.sh --no-open "$@" < /dev/null); }
PS() { (cd "$K" && "${FAKE[@]}" "$PWSH" -NoProfile -File ./setup.ps1 -NoOpen "$@" < /dev/null); }
remote_is_kit() {  # fake Google project holds exactly the kit files (manifest: same except time zone)
  [ "$(cd "$G/remote" && ls -1 | sort | tr '\n' ' ')" = "Clean.gs Config.gs Menu.gs Sheets.gs Triggers.gs appsscript.json " ] || return 1
  for f in Config.gs Clean.gs Sheets.gs Triggers.gs Menu.gs; do cmp -s "$K/apps-script/$f" "$G/remote/$f" || return 1; done
}
new_google() {  # a fresh spreadsheet's script: Google's empty starter Code.gs + a manifest in New York time
  rm -rf "$G"; mkdir -p "$G/remote"
  printf 'function myFunction() {\n  \n}\n' > "$G/remote/Code.gs"
  printf '{\n  "timeZone": "America/New_York",\n  "dependencies": {},\n  "exceptionLogging": "STACKDRIVER",\n  "runtimeVersion": "V8"\n}\n' > "$G/remote/appsscript.json"
}
tz_remote() { python3 -c "import json;print(json.load(open('$G/remote/appsscript.json'))['timeZone'])"; }

{
  echo "Date: $(date '+%b %-d, %Y, %H:%M %Z')"; echo "System: $(uname -sm)"
  echo "Node: $(node -v)   npm: $(npm -v)   Python: $(python3 -V 2>&1)"
  echo "PowerShell: $("$PWSH" -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' 2>/dev/null || echo none)"
  echo "Kit ZIP: $(basename "$ZIP") sha256 $(h "$ZIP")"
  echo "Scratch folder: $W (empty before unzip)"
} > "$PROOF/00_environment.txt"
(cd "$W" && unzip -q "$ZIP") && { echo; echo "unzipped:"; (cd "$K" && find . -type f | sort); } >> "$PROOF/00_environment.txt"

# 1. The Apps Script code, against the in-memory Google stand-in: the source files, then the shipped one-file version
run 01_unit_tests_source.txt node --test "$REPO/tests/unit.test.js"
run 02_unit_tests_shipped_bundle.txt env NYYO_BUNDLE="$K/NyyoSheetsKit.gs" node --test "$REPO/tests/unit.test.js"
cp "$K/NyyoSheetsKit.gs" "$W/bundle.js"
run 03_bundle_syntax.txt node --check "$W/bundle.js"

# 2. setup.sh without Google: copy-paste mode, no Node.js, no / bad Script ID
run 04_setup_sh_copy_paste.txt bash -c "cd '$K' && ./setup.sh --copy-paste --no-open < /dev/null"
B_SH="$(h "$K/output/NyyoSheetsKit.gs")"
NN="$W/no-node-bin"; mkdir -p "$NN"
for c in bash env sed tr mv cp rm mkdir cat uname grep find sort wc awk date cut sha256sum ls head dirname; do ln -sf "$(command -v $c)" "$NN/$c"; done
run 05_setup_sh_no_node_falls_back.txt env PATH="$NN" bash -c "cd '$K' && ./setup.sh --no-open < /dev/null"
run 06_setup_sh_no_script_id.txt SH
run 07_setup_sh_bad_script_id.txt SH --script-id "not-an-id"

# 3. Real clasp 3.4.1, offline: pinned install by npm ci, file list, refusal when not signed in
run 08_setup_sh_real_clasp_check.txt bash -c "cd '$K' && HOME='$W/home' ./setup.sh --no-open --check --script-id 'https://script.google.com/home/projects/$REAL_ID/edit' < /dev/null"
{ echo "\$ node_modules/.bin/clasp --version"; (cd "$K" && node_modules/.bin/clasp --version); echo "\$ npm ls @google/clasp"; (cd "$K" && npm ls @google/clasp 2>&1); } > "$PROOF/08b_real_clasp_version.txt"
run 09_setup_sh_real_clasp_not_signed_in.txt bash -c "cd '$K' && HOME='$W/home' ./setup.sh --no-open < /dev/null"

# 4. Fake Google: first run in a terminal (Script ID typed at the prompt, browser sign-in), then again
new_google; rm -f "$K/config/script-id.txt"
run 10_setup_sh_first_run_terminal.txt bash -c "(sleep 2; printf '%s\n' 'https://script.google.com/home/projects/$REAL_ID/edit'; sleep 25) | script -qec \"cd '$K' && env NYYO_CLASP='$REPO/tests/fake_clasp/clasp' FAKE_GOOGLE='$G' FAKE_SCRIPT_ID='$REAL_ID' ./setup.sh\" /dev/null"
R1_OK=0; remote_is_kit && R1_OK=1; TZ1="$(tz_remote)"; R1="$(cd "$G/remote" && cat * | sha256sum | cut -c1-16)"
SCOPES_OK=0; grep -q 'spreadsheets.currentonly' "$G/remote/appsscript.json" && SCOPES_OK=1
OPENED=0; grep -q 'open-container' "$G/calls.log" && OPENED=1
STARTER_BK=0; ls "$K"/output/backups/*/Code.gs >/dev/null 2>&1 && STARTER_BK=1
run 11_setup_sh_second_run.txt SH
R2="$(cd "$G/remote" && cat * | sha256sum | cut -c1-16)"; LAST_BK="$(ls -1d "$K"/output/backups/*/ | sort | tail -1)"
BK2_OK=0; [ -f "${LAST_BK}Config.gs" ] && BK2_OK=1
# 5. Someone else's code in the project: refused, then replaced on request (with a copy kept)
printf 'function myReport() { return 42; }\n' > "$G/remote/Report.gs"
R3="$(cd "$G/remote" && cat * | sha256sum | cut -c1-16)"
run 12_setup_sh_other_code_refused.txt SH
R4="$(cd "$G/remote" && cat * | sha256sum | cut -c1-16)"
BK3_OK=0; ls "$K"/output/backups/*/Report.gs >/dev/null 2>&1 && BK3_OK=1
run 13_setup_sh_replace_other_code.txt SH --replace-other-code
R5_OK=0; remote_is_kit && R5_OK=1; BK_REPLACE="$(ls -1d "$K"/output/backups/*/ | sort | tail -1)"
BK4_OK=0; [ -f "${BK_REPLACE}Report.gs" ] && BK4_OK=1
# 6. Google errors: Apps Script API off, a Script ID that is not yours
run 14_setup_sh_api_disabled.txt env FAKE_FAIL=api bash -c "cd '$K' && env NYYO_CLASP='$REPO/tests/fake_clasp/clasp' FAKE_GOOGLE='$G' FAKE_SCRIPT_ID='$REAL_ID' ./setup.sh --no-open < /dev/null"
run 15_setup_sh_wrong_script_id.txt SH --script-id "$OTHER_ID"
ID_AFTER_WRONG="$(cat "$K/config/script-id.txt")"; ID_PREV="$(cat "$K/config/script-id.txt.previous" 2>/dev/null)"
run 15b_setup_sh_back_to_right_id.txt SH --script-id "$REAL_ID"
R6_OK=0; remote_is_kit && R6_OK=1; N_BK="$(ls -1d "$K"/output/backups/*/ | wc -l)"
OLDEST_BK="$(ls -1d "$K"/output/backups/*/ | sort | head -1)"
{ for i in 1 2 3 4; do SH > /dev/null 2>&1; echo "extra run $i: exit $?"; done; echo "backup folders now:"; ls -1 "$K/output/backups"; } > "$PROOF/15d_setup_sh_backups_capped.txt"
N_BK2="$(ls -1d "$K"/output/backups/*/ | wc -l)"; OLDEST_GONE=0; [ ! -e "$OLDEST_BK" ] && OLDEST_GONE=1
cp "$G/calls.log" "$PROOF/15c_fake_google_calls_bash.txt"

# 7. PowerShell 7: copy-paste, fresh install (new node_modules), again, other code refused, no Script ID
if [ -x "$PWSH" ]; then
  run 16_setup_ps1_copy_paste.txt PS -CopyPaste
  B_PS="$(h "$K/output/NyyoSheetsKit.gs")"
  rm -rf "$K/node_modules" "$K/config/script-id.txt"* "$K/output"; new_google; touch "$G/logged_in"  # signed in already (clasp keeps it in the home folder)
  run 17_setup_ps1_first_run.txt PS -ScriptId "$REAL_ID"
  P1_OK=0; remote_is_kit && P1_OK=1; TZP="$(tz_remote)"; P1="$(cd "$G/remote" && cat * | sha256sum | cut -c1-16)"
  sleep 1
  run 18_setup_ps1_second_run.txt PS
  P2="$(cd "$G/remote" && cat * | sha256sum | cut -c1-16)"
  printf 'function myReport() { return 42; }\n' > "$G/remote/Report.gs"
  run 19_setup_ps1_other_code_refused.txt PS
  P3_OK=0; [ -f "$G/remote/Report.gs" ] && P3_OK=1
  rm -f "$K/config/script-id.txt"
  run 20_setup_ps1_no_script_id.txt PS
fi
cp "$G/calls.log" "$PROOF/20b_fake_google_calls_powershell.txt" 2>/dev/null

# 8. build_dist.sh refuses secrets, Google sign-in files, a buyer's Script ID and off-platform wording
C="$W/repo-copy"; mkdir -p "$C"; (cd "$REPO" && tar --exclude=.git --exclude=./dist --exclude=./node_modules --exclude=./output -cf - .) | (cd "$C" && tar -xf -)
FAKEKEY="AKIA""FAKEFAKEFAKE1234"; FAKEMAIL="kit-test""@""example.org"; FAKETOKEN="1//""0gFAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKE"
bd() { local rc; (cd "$C" && scripts/build_dist.sh 2>&1); rc=$?; echo "[exit code $rc]"; }
{
  echo "== A. clean copy"; bd; echo "zip sha256 of this copy: $(cat "$C/dist/nyyo-sheets-kit.zip.sha256" 2>/dev/null)"
  echo; echo "== B. a buyer's Script ID left in config/"
  echo "$REAL_ID" > "$C/config/script-id.txt"; bd; rm -f "$C/config/script-id.txt"
  echo; echo "== C. a Google sign-in file (clasp) left in config/"
  printf '{"tokens": {"default": {"refresh_token": "%s"}}}\n' "$FAKETOKEN" > "$C/config/.clasprc.json"; bd; rm -f "$C/config/.clasprc.json"
  echo; echo "== D. a fake AWS key pasted into INSTALL.md"
  cp "$C/INSTALL.md" "$W/INSTALL.bak"; echo "aws_access_key_id = $FAKEKEY" >> "$C/INSTALL.md"; bd; cp "$W/INSTALL.bak" "$C/INSTALL.md"
  echo; echo "== E. an e-mail address pasted into INSTALL.md"
  echo "Write to $FAKEMAIL" >> "$C/INSTALL.md"; bd; cp "$W/INSTALL.bak" "$C/INSTALL.md"
  echo; echo "== F. payment wording slipped into the How to use text (Sheets.gs)"
  sed -i "s/Questions? Ask in your order chat./Pay via PayPal to skip the queue./" "$C/apps-script/Sheets.gs"; bd
} > "$PROOF/21_build_dist_refusal.txt" 2>&1
CLEAN_ZIP_SHA="$(cat "$C/dist/nyyo-sheets-kit.zip.sha256" 2>/dev/null)"

# 9. Template = sample rows in the code
run 22_template_check.txt python3 - "$K" <<'PY'
import csv, json, re, sys
from openpyxl import load_workbook
K = sys.argv[1]
src = open(f"{K}/apps-script/Sheets.gs", encoding="utf-8").read()
sample = json.loads(re.search(r"var NYYO_SAMPLE_ = (\[.*?\n\]);", src, re.S).group(1).replace("'", '"'))
rows = list(csv.reader(open(f"{K}/template/sample-data.csv", encoding="utf-8", newline="")))
wb = load_workbook(f"{K}/template/nyyo-sheets-kit-template.xlsx")
x = [["" if v is None else str(v) for v in r] for r in wb["Data"].iter_rows(values_only=True)]
print("CSV header:", rows[0]); print("XLSX tabs:", wb.sheetnames)
print("sample rows in code:", len(sample), " CSV:", len(rows) - 1, " XLSX:", len(x) - 1)
ok = rows[0] == x[0] and all(r[:7] == s for r, s in zip(rows[1:], sample)) and [r[:7] for r in x[1:]] == [r[:7] for r in rows[1:]] and len(sample) == len(rows) - 1 == len(x) - 1
ok = ok and all(c.number_format == "@" for row in wb["Data"].iter_rows(min_row=2) for c in row)
print("identical, XLSX cells stored as text:", ok); sys.exit(0 if ok else 1)
PY

# ---- Checks ----
{
  echo "Checks ($(date '+%b %-d, %Y, %H:%M %Z'))"; echo
  check "Apps Script logic, source files: all unit tests pass (Node shim for SpreadsheetApp)" \
    "[ \$(code 01_unit_tests_source.txt) = 0 ] && grep -q '^# fail 0' '$PROOF/01_unit_tests_source.txt' && grep -q '^# pass 19' '$PROOF/01_unit_tests_source.txt'"
  check "same tests on the shipped one-file NyyoSheetsKit.gs: all pass" \
    "[ \$(code 02_unit_tests_shipped_bundle.txt) = 0 ] && grep -q '^# fail 0' '$PROOF/02_unit_tests_shipped_bundle.txt' && grep -q '^# pass 19' '$PROOF/02_unit_tests_shipped_bundle.txt'"
  check "one-file version is valid JavaScript (V8), contains all 5 kit files, @OnlyCurrentDoc kept" \
    "[ \$(code 03_bundle_syntax.txt) = 0 ] && [ \$(grep -c '^// ===== ' '$K/NyyoSheetsKit.gs') = 5 ] && grep -q '@OnlyCurrentDoc' '$K/NyyoSheetsKit.gs'"
  check "copy-paste file: setup.sh rebuilds it byte for byte = the shipped NyyoSheetsKit.gs, exit 0" \
    "[ \$(code 04_setup_sh_copy_paste.txt) = 0 ] && [ '$B_SH' = '$(h "$K/NyyoSheetsKit.gs")' ]"
  check "no Node.js: falls back to copy-paste with clear steps, exit 1 (warning), nothing sent" \
    "[ \$(code 05_setup_sh_no_node_falls_back.txt) = 1 ] && grep -q 'Node.js not found' '$PROOF/05_setup_sh_no_node_falls_back.txt' && grep -q 'nyyoSetup' '$PROOF/05_setup_sh_no_node_falls_back.txt'"
  check "no Script ID and no terminal: exit 3 with the command to run; a bad ID is refused (exit 3)" \
    "[ \$(code 06_setup_sh_no_script_id.txt) = 3 ] && grep -q -- '--script-id YOUR_SCRIPT_ID' '$PROOF/06_setup_sh_no_script_id.txt' && [ \$(code 07_setup_sh_bad_script_id.txt) = 3 ] && grep -q 'does not look like a Script ID' '$PROOF/07_setup_sh_bad_script_id.txt'"
  check "real clasp: npm ci installs exactly @google/clasp 3.4.1 from the lock file (hash-checked)" \
    "[ \$(code 08_setup_sh_real_clasp_check.txt) = 0 ] && grep -q '^3.4.1$' '$PROOF/08b_real_clasp_version.txt' && grep -q '@google/clasp@3.4.1' '$PROOF/08b_real_clasp_version.txt' && grep -q 'Installing clasp 3.4.1' '$PROOF/08_setup_sh_real_clasp_check.txt'"
  check "real clasp --check: Script ID read from an editor link; would push exactly the 6 kit files; nothing sent" \
    "[ \"\$(grep -cE '(Config|Clean|Sheets|Triggers|Menu)\.gs|appsscript\.json' '$PROOF/08_setup_sh_real_clasp_check.txt')\" -ge 6 ] && grep -q 'Nothing was sent to Google' '$PROOF/08_setup_sh_real_clasp_check.txt' && grep -q '$REAL_ID' '$PROOF/08_setup_sh_real_clasp_check.txt'"
  check "real clasp, not signed in, no terminal: exit 4 'Not signed in', clasp reused (not reinstalled)" \
    "[ \$(code 09_setup_sh_real_clasp_not_signed_in.txt) = 4 ] && grep -q 'Not signed in to Google yet' '$PROOF/09_setup_sh_real_clasp_not_signed_in.txt' && grep -q 'clasp already installed' '$PROOF/09_setup_sh_real_clasp_not_signed_in.txt'"
  check "first run in a terminal: Script ID typed as a link, saved, sign-in opened, kit pushed, exit 0" \
    "[ \$(code 10_setup_sh_first_run_terminal.txt) = 0 ] && grep -q 'Saved your Script ID' '$PROOF/10_setup_sh_first_run_terminal.txt' && grep -q 'A browser page opens' '$PROOF/10_setup_sh_first_run_terminal.txt' && [ '$R1_OK' = 1 ] && [ '$OPENED' = 1 ]"
  check "the project keeps its own time zone (America/New_York), the rest of the manifest is the kit's" \
    "[ '$TZ1' = America/New_York ] && [ '$SCOPES_OK' = 1 ]"
  check "Google's empty starter Code.gs is backed up, then replaced without asking" \
    "[ '$STARTER_BK' = 1 ] && grep -q 'Installed Nyyo Sheets kit' '$PROOF/10_setup_sh_first_run_terminal.txt'"
  check "second run: ID kept, clasp reused, backup holds the kit, project identical, exit 0" \
    "[ \$(code 11_setup_sh_second_run.txt) = 0 ] && grep -q 'clasp already installed' '$PROOF/11_setup_sh_second_run.txt' && ! grep -q 'Saved your Script ID' '$PROOF/11_setup_sh_second_run.txt' && [ '$BK2_OK' = 1 ] && [ '$R1' = '$R2' ]"
  check "other code in the project: refused (exit 3), project untouched, copy saved" \
    "[ \$(code 12_setup_sh_other_code_refused.txt) = 3 ] && grep -q 'already holds other code: Report.gs' '$PROOF/12_setup_sh_other_code_refused.txt' && [ '$R3' = '$R4' ] && [ '$BK3_OK' = 1 ]"
  check "--replace-other-code: replaced, copy of Report.gs kept in the backup, exit 0" \
    "[ \$(code 13_setup_sh_replace_other_code.txt) = 0 ] && [ '$R5_OK' = 1 ] && [ '$BK4_OK' = 1 ]"
  check "Apps Script API off: exit 4 and the settings link; Script ID not yours: exit 4 'cannot find'" \
    "[ \$(code 14_setup_sh_api_disabled.txt) = 4 ] && grep -q 'script.google.com/home/usersettings' '$PROOF/14_setup_sh_api_disabled.txt' && [ \$(code 15_setup_sh_wrong_script_id.txt) = 4 ] && grep -q 'cannot find that Script ID' '$PROOF/15_setup_sh_wrong_script_id.txt'"
  check "changing the Script ID keeps the old one in script-id.txt.previous; switching back works" \
    "[ '$ID_AFTER_WRONG' = '$OTHER_ID' ] && [ '$ID_PREV' = '$REAL_ID' ] && [ \$(code 15b_setup_sh_back_to_right_id.txt) = 0 ] && [ '$R6_OK' = 1 ]"
  check "every run makes its own new, empty backup folder (7 runs reached Google: 7 folders), even within the same second" "[ '$N_BK' -eq 7 ]"
  check "backups capped at the last 10 folders (4 more runs: 11 -> 10, the oldest removed)" "[ '$N_BK2' -eq 10 ] && [ '$OLDEST_GONE' = 1 ]"
  if [ -x "$PWSH" ]; then
    check "setup.ps1 (PowerShell 7) copy-paste file = setup.sh's, byte for byte" \
      "[ \$(code 16_setup_ps1_copy_paste.txt) = 0 ] && [ '$B_PS' = '$B_SH' ]"
    check "setup.ps1 fresh: npm ci of clasp 3.4.1, ID saved, kit pushed, time zone kept, exit 0" \
      "[ \$(code 17_setup_ps1_first_run.txt) = 0 ] && grep -q 'Installing clasp 3.4.1' '$PROOF/17_setup_ps1_first_run.txt' && [ '$P1_OK' = 1 ] && [ '$TZP' = America/New_York ]"
    check "setup.ps1 second run: clasp reused, project identical; other code refused (exit 3); no ID: exit 3" \
      "[ \$(code 18_setup_ps1_second_run.txt) = 0 ] && grep -q 'clasp already installed' '$PROOF/18_setup_ps1_second_run.txt' && [ '$P1' = '$P2' ] && [ \$(code 19_setup_ps1_other_code_refused.txt) = 3 ] && [ '$P3_OK' = 1 ] && [ \$(code 20_setup_ps1_no_script_id.txt) = 3 ]"
  fi
  check "build_dist.sh: clean copy builds the same ZIP; refuses a Script ID, a clasp sign-in file, a fake key, an e-mail, payment wording" \
    "[ \$(grep -c '^\[exit code 0\]' '$PROOF/21_build_dist_refusal.txt') = 1 ] && [ \$(grep -c '^\[exit code 1\]' '$PROOF/21_build_dist_refusal.txt') = 5 ] && [ \$(grep -c 'forbidden file' '$PROOF/21_build_dist_refusal.txt') = 2 ] && grep -q 'secret-like' '$PROOF/21_build_dist_refusal.txt' && [ \$(grep -c 'off-platform' '$PROOF/21_build_dist_refusal.txt') = 2 ] && [ '$CLEAN_ZIP_SHA' = '$(h "$ZIP")' ]"
  check "template CSV + XLSX hold exactly the sample rows of the code, XLSX cells kept as text" "[ \$(code 22_template_check.txt) = 0 ]"
  check "no Google sign-in file was ever written inside the kit folder" \
    "[ -z \"\$(cd '$K' && find . -name '.clasprc.json' -not -path './node_modules/*')\" ]"
  echo; echo "$PASS passed, $FAILN failed"
} > "$PROOF/23_checks.txt" 2>&1
sed -i "s#$W#<scratch>#g; s#$REPO#<repo>#g" "$PROOF"/*.txt; chmod 644 "$PROOF"/*
cat "$PROOF/23_checks.txt"
[ "$FAILN" = 0 ]
