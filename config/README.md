# config

`setup.sh` / `setup.ps1` keep your Apps Script **Script ID** here, in `script-id.txt`, the first time you give it.
It is not a password: it only says which Apps Script project to update. Your Google sign-in is not stored in this
folder (clasp keeps it in your home folder; `node_modules/.bin/clasp logout` removes it).

To point the kit at another spreadsheet: `./setup.sh --script-id NEW_ID` (Windows: `.\setup.ps1 -ScriptId NEW_ID`).
The old ID is kept as `script-id.txt.previous`.
