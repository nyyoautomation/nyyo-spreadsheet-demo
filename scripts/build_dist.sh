#!/usr/bin/env bash
# Build dist/nyyo-sheets-kit.zip from the repo. Refuses to package anything that looks like a secret, a Google
# sign-in file, a buyer's own settings/output, or off-platform contact, payment or delivery wording.
#   scripts/build_dist.sh          (needs python3 + openpyxl and Docker for gitleaks)
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"; cd "$REPO"
GL_IMAGE="zricethezav/gitleaks:v8.30.1@sha256:c00b6bd0aeb3071cbcb79009cb16a60dd9e0a7c60e2be9ab65d25e6bc8abbb7f"
OUT="$REPO/dist/nyyo-sheets-kit.zip"
STAGE="$(mktemp -d)"; trap 'rm -rf "$STAGE"' EXIT
D="$STAGE/nyyo-sheets-kit"; mkdir -p "$D"

python3 scripts/make_template.py
FILES="setup.sh setup.ps1 INSTALL.md LICENSE package.json package-lock.json config/README.md
apps-script/appsscript.json apps-script/Config.gs apps-script/Clean.gs apps-script/Sheets.gs apps-script/Triggers.gs
apps-script/Menu.gs template/sample-data.csv template/nyyo-sheets-kit-template.xlsx"
for f in $FILES; do mkdir -p "$D/$(dirname "$f")"; cp "$f" "$D/$f"; done
# anything extra a developer dropped into the shipped folders gets copied too, so the checks below see it
for dir in apps-script config template; do
  find "$dir" -type f -print0 | while IFS= read -r -d '' f; do
    [ -e "$D/$f" ] || { mkdir -p "$D/$(dirname "$f")"; cp "$f" "$D/$f"; }; done
done
# the one-file copy-paste version, made by the kit's own setup.sh (so shipped file = what setup makes)
(cd "$D" && bash ./setup.sh --copy-paste --no-open >/dev/null) && mv "$D/output/NyyoSheetsKit.gs" "$D/NyyoSheetsKit.gs" && rmdir "$D/output" 2>/dev/null || true
[ -s "$D/NyyoSheetsKit.gs" ] || { echo "refusing: the copy-paste file was not built"; exit 1; }
sed -i 's/\r$//; s/$/\r/' "$D/setup.ps1"          # Windows line endings for the PowerShell script
chmod 755 "$D/setup.sh"

# 1. Forbidden files (secrets, Google sign-in, the buyer's own settings, outputs, installed packages)
BAD="$(cd "$D" && find . \( -name '.env' -o -name '.env.*' -o -name '*.pem' -o -name '*.key' -o -name '*.p12' -o -name '*.pfx' \
  -o -name 'id_rsa*' -o -name 'id_ed25519*' -o -name '*.kdbx' -o -name '.clasprc.json' -o -name '.clasp.json' \
  -o -name 'client_secret*.json' -o -name 'credentials*.json' -o -name 'service-account*.json' -o -name 'script-id.txt*' \
  -o -path './output' -o -path './output/*' -o -path './node_modules' -o -path './node_modules/*' \) -print)"
[ -z "$BAD" ] || { echo "refusing: forbidden file(s) in kit:"; echo "$BAD"; exit 1; }

# 2. gitleaks on the staged kit (pinned image)
docker info >/dev/null 2>&1 || { echo "refusing: Docker is needed to run the gitleaks check"; exit 1; }
rc=0; docker run --rm --user "$(id -u):$(id -g)" -v "$D:/scan:ro" "$GL_IMAGE" dir /scan --no-banner --redact -v --exit-code 3 -l warn || rc=$?
[ "$rc" = 3 ] && { echo "refusing: gitleaks found secret-like strings in the kit (values redacted above)"; exit 1; }
[ "$rc" = 0 ] || { echo "refusing: the gitleaks check failed to run (exit $rc)"; exit 1; }
echo "gitleaks check of the staged kit: no leaks"

# 3. Regex second net (keys, Google OAuth / service-account JSON, refresh tokens)
if grep -rEn --exclude='*.xlsx' '(AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{30,}|sk_(live|test)_[A-Za-z0-9]{10,}|sk-(proj-)?[A-Za-z0-9_-]{30,}|xox[abpr]-[0-9A-Za-z-]{10,}|AIza[0-9A-Za-z_-]{35}|ya29\.[0-9A-Za-z_-]{20,}|1//[0-9A-Za-z_-]{30,}|GOCSPX-[0-9A-Za-z_-]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY|"(private_key(_id)?|refresh_token|client_secret)"[[:space:]]*:)' "$D"; then
  echo "refusing: secret-like string in kit"; exit 1
fi

# 4. Marketplace rule: no off-platform contact, payment or delivery-time wording in the kit (XLSX text checked too)
WORDS='([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}|supertea[m]|usdc|\bcrypto(currenc(y|ies))?\b|wallet|bnb chain|paypal|stripe|open an issue|hire me|telegram|whatsapp|\bdelivery\b|€|\bfrance\b)'
X="$STAGE/xlsx-text"; mkdir -p "$X"; (cd "$X" && unzip -q -o "$D/template/nyyo-sheets-kit-template.xlsx")
if grep -rEni --exclude='*.xlsx' "$WORDS" "$D" "$X"; then
  echo "refusing: off-platform contact, payment or delivery wording in kit (lines above)"; exit 1
fi
rm -rf "$X"

rm -f "$OUT"; mkdir -p dist
python3 - "$STAGE" "$OUT" <<'PY'
import os, sys, zipfile
stage, out = sys.argv[1], sys.argv[2]
files = sorted(os.path.relpath(os.path.join(r, f), stage) for r, _, fs in os.walk(stage) for f in fs)
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for rel in files:
        full = os.path.join(stage, rel)
        zi = zipfile.ZipInfo(rel, date_time=(2026, 10, 19, 0, 0, 0))   # fixed date: same input, same ZIP
        zi.external_attr = (os.stat(full).st_mode & 0xFFFF) << 16
        zi.create_system = 3  # Unix, so the executable bit on setup.sh survives unzip on Mac/Linux
        zi.compress_type = zipfile.ZIP_DEFLATED
        with open(full, "rb") as fh: z.writestr(zi, fh.read())
PY
unzip -l "$OUT" | tail -n1
sha256sum "$OUT" | cut -d' ' -f1 > "$OUT.sha256"; echo "sha256 $(cat "$OUT.sha256")"
