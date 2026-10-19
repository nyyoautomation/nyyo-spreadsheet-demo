/** Spreadsheet side: tabs, setup, refresh, change log. Every action is safe to run again. */

var NYYO_SAMPLE_ = [
  ['C-1001', '  alice smith ', '555-0101', '01/15/2025', '$1,200.50', 'paid', 'boston'],
  ['C-1002', 'Bob Jones', '+1 555 0102', '2025-01-20', '800', 'PAID', 'Boston'],
  ['c-1001 ', 'alice smith', '5550101', '15/01/2025', '1200.5', 'Paid', 'BOSTON'],
  ['', 'Carol Nguyen', '555.0103', 'Feb 3 2025', '950 USD ', 'pending', 'denver'],
  ['C-1004', '  DANIEL  LEE', '(555) 010-4', '2025/02/10', '2,100.00 USD', 'paid ', 'seattle'],
  ['C-1005', 'Eve Martin', 'n/a', '32/13/2025', 'abc', 'unknown', ''],
  ['C-1002', 'Bob Jones', '555-0102', '20-01-2025', '800.00', 'paid', 'boston'],
  ['C-1006', 'Fatima Zahra', '+44 7700 900123', '2025-03-01', '450,75', 'pending', 'Austin'],
  ['C-1007', '', '555', '2025-03-05', '0', 'paid', 'Miami'],
  ['C-1008', 'Hugo Blanc', '05550109', '05/03/25', '1 350', 'PAID', 'chicago']
];

/** Text of the "How to use" tab (a function, so it never depends on the order the files load in). */
function nyyoHowto_() {
  return [
  ['Nyyo Sheets kit ' + NYYO.version + ' - how to use'],
  [''],
  ['1. Put your rows in the "Data" tab (one row per client). Keep the header row. Column order does not matter.'],
  ['2. Menu Nyyo kit > "2. Clean + refresh dashboard". The "Clean" and "Dashboard" tabs are rebuilt from Data.'],
  ['   Your Data tab is never changed by the cleaning: it only reads it.'],
  ['3. Rows with a date, amount or status the kit cannot read are kept at the bottom of "Clean" with a'],
  ['   "NEEDS REVIEW" note. Fix them in Data, then run step 2 again.'],
  ['4. Duplicates (same client_id, or same name + phone when client_id is empty) are merged into one row.'],
  ['5. When you edit a row in Data, its "last_updated" cell gets the date and time automatically.'],
  ['6. Optional: Nyyo kit > "Turn on daily refresh" runs step 2 every morning. "Turn off daily refresh" stops it.'],
  [''],
  ['Accepted dates: 2025-01-15, 01/15/2025, 15/01/2025, 2025/01/15, 15-01-2025, Jan 15 2025, 15/01/25, or a date cell.'],
  ['Accepted amounts: 1200.5, $1,200.50, 2,100.00 USD, 450,75 (comma decimals), 1 350.'],
  ['Every action is written to the "Change log" tab. Running any menu item again is safe.'],
  ['This tab is rewritten by "1. Set up": write your own notes in another tab.'],
  [''],
  ['Questions? Ask in your order chat.']
  ];
}

function nyyoSs_() { return SpreadsheetApp.getActiveSpreadsheet(); }
function nyyoTz_(ss) { return (ss && ss.getSpreadsheetTimeZone && ss.getSpreadsheetTimeZone()) || Session.getScriptTimeZone() || 'Etc/UTC'; }
function nyyoNow_(ss) { return Utilities.formatDate(new Date(), nyyoTz_(ss), 'yyyy-MM-dd HH:mm:ss'); }

function nyyoToast_(msg) {
  try { nyyoSs_().toast(msg, 'Nyyo kit', 6); } catch (e) { /* no UI when run by a trigger */ }
  try { console.log(msg); } catch (e) { /* ignore */ }
  return msg;
}

/** Gets a tab, creating it (empty) only when it does not exist yet. */
function nyyoTab_(ss, name) {
  var sh = ss.getSheetByName(name);
  return sh ? { sheet: sh, created: false } : { sheet: ss.insertSheet(name), created: true };
}

function nyyoLog_(action, details) {
  var ss = nyyoSs_();
  var t = nyyoTab_(ss, NYYO.tabs.log), sh = t.sheet;
  if (t.created || sh.getLastRow() === 0) {
    sh.getRange(1, 1, 1, 3).setValues([['when', 'action', 'details']]).setFontWeight('bold');
    sh.setFrozenRows(1);
  }
  sh.appendRow([nyyoNow_(ss), action, details]);
  var extra = sh.getLastRow() - 1 - NYYO.logMaxRows;
  if (extra > 0) sh.deleteRows(2, extra);
}

/** Data header: adds missing kit columns at the end of row 1. Never renames, moves or deletes a column. */
function nyyoEnsureDataHeader_(sh) {
  var lastCol = Math.max(sh.getLastColumn(), 1);
  var header = sh.getLastRow() ? sh.getRange(1, 1, 1, lastCol).getValues()[0] : [];
  var have = header.map(function (h) { return nyyoNormText_(h).toLowerCase(); });
  var used = have.filter(function (h) { return h; }).length;
  var missing = NYYO.headers.filter(function (h) { return have.indexOf(h) === -1; });
  if (missing.length) {
    var start = used ? lastCol + 1 : 1;
    sh.getRange(1, start, 1, missing.length).setValues([missing]);
  }
  sh.getRange(1, 1, 1, sh.getLastColumn()).setFontWeight('bold');
  sh.setFrozenRows(1);
  return missing;
}

function nyyoDataRows_(sh) {
  var lastRow = sh.getLastRow(), lastCol = sh.getLastColumn();
  if (lastRow < 1 || lastCol < 1) return { header: [], rows: [] };
  var all = sh.getRange(1, 1, lastRow, lastCol).getValues();
  var rows = all.slice(1).filter(function (r) { return r.some(function (c) { return nyyoNormText_(c) !== ''; }); });
  return { header: all[0], rows: rows };
}

/** Writes the sample rows into Data, only when Data has no rows yet. */
function nyyoLoadSampleInto_(sh) {
  if (nyyoDataRows_(sh).rows.length) return false;
  var col = nyyoColumnMap_(sh.getRange(1, 1, 1, sh.getLastColumn()).getValues()[0], NYYO.headers);
  var width = sh.getLastColumn();
  var order = ['client_id', 'name', 'phone', 'signup_date', 'amount_usd', 'status', 'city'];
  var out = NYYO_SAMPLE_.map(function (r) {
    var row = []; for (var i = 0; i < width; i++) row.push('');
    order.forEach(function (h, i) { row[col[h]] = r[i]; });
    return row;
  });
  var tsCol = col[NYYO.timestampColumn];
  sh.getRange(2, 1, out.length, width).setNumberFormat('@').setValues(out);
  if (tsCol !== undefined) sh.getRange(2, tsCol + 1, out.length, 1).setNumberFormat('General');
  return true;
}

/** Menu "1. Set up": creates what is missing, rewrites "How to use", then cleans. Safe to run again. */
function nyyoSetup() {
  var ss = nyyoSs_(), done = [];
  var data = nyyoTab_(ss, NYYO.tabs.data);
  var missing = nyyoEnsureDataHeader_(data.sheet);
  if (data.created) done.push('created tab ' + NYYO.tabs.data);
  else if (missing.length) done.push('added column(s) ' + missing.join(', '));
  if (data.created && nyyoLoadSampleInto_(data.sheet)) done.push('loaded ' + NYYO_SAMPLE_.length + ' sample rows');
  [NYYO.tabs.clean, NYYO.tabs.dashboard].forEach(function (n) { if (nyyoTab_(ss, n).created) done.push('created tab ' + n); });
  var howto = nyyoTab_(ss, NYYO.tabs.howto), text = nyyoHowto_();
  if (howto.created) done.push('created tab ' + NYYO.tabs.howto);
  howto.sheet.clearContents();
  howto.sheet.getRange(1, 1, text.length, 1).setValues(text);
  howto.sheet.getRange(1, 1).setFontWeight('bold');
  nyyoLog_('setup', done.length ? done.join('; ') : 'nothing to create (already set up)');
  var r = nyyoRefresh();
  return nyyoToast_('Set up done. ' + (done.length ? done.join('; ') + '. ' : 'Nothing to create. ') + r);
}

/** Menu "Load sample data": only when the Data tab has no rows. */
function nyyoLoadSample() {
  var ss = nyyoSs_(), data = nyyoTab_(ss, NYYO.tabs.data);
  nyyoEnsureDataHeader_(data.sheet);
  if (!nyyoLoadSampleInto_(data.sheet)) return nyyoToast_('Data already has rows: sample not loaded (nothing changed).');
  nyyoLog_('sample', 'loaded ' + NYYO_SAMPLE_.length + ' sample rows');
  return nyyoToast_('Sample rows loaded. ' + nyyoRefresh());
}

/** Menu "2. Clean + refresh dashboard". Reads Data, rebuilds Clean and Dashboard. Never writes to Data. */
function nyyoRefresh() {
  var ss = nyyoSs_();
  var dataSh = ss.getSheetByName(NYYO.tabs.data);
  if (!dataSh) return nyyoToast_('No "' + NYYO.tabs.data + '" tab yet: run "1. Set up" first.');
  var d = nyyoDataRows_(dataSh);
  if (!d.rows.length) {
    nyyoLog_('refresh', 'skipped: Data has no rows (Clean and Dashboard kept as they were)');
    return nyyoToast_('Data has no rows: Clean and Dashboard kept as they were.');
  }
  var res;
  try {
    res = nyyoCleanRows_(d.header, d.rows, NYYO, nyyoTz_(ss));
  } catch (e) {
    nyyoLog_('refresh', 'stopped: ' + e.message);
    return nyyoToast_(e.message);
  }
  // everything is computed before anything is cleared, so an error never leaves an empty tab
  var clean = nyyoTab_(ss, NYYO.tabs.clean).sheet;
  clean.clearContents();
  var table = [NYYO.cleanHeaders].concat(res.rows);
  clean.getRange(1, 1, table.length, NYYO.cleanHeaders.length).setNumberFormat('@').setValues(table);
  var amountCol = NYYO.cleanHeaders.indexOf('amount_usd') + 1;
  if (res.rows.length) clean.getRange(2, amountCol, res.rows.length, 1).setNumberFormat('0.00');
  clean.getRange(1, 1, 1, NYYO.cleanHeaders.length).setFontWeight('bold');
  clean.setFrozenRows(1);
  nyyoWriteDashboard_(ss, res);
  var msg = res.kept + ' clean row(s), ' + res.merged + ' duplicate(s) merged, ' + res.review + ' to review, ' +
    res.skipped + ' empty-name row(s) skipped.';
  nyyoLog_('refresh', msg);
  return msg;
}

function nyyoWriteDashboard_(ss, res) {
  var s = nyyoSummary_(res.rows, NYYO);
  var sh = nyyoTab_(ss, NYYO.tabs.dashboard).sheet;
  var rows = [
    ['Dashboard', 'value'],
    ['Last refresh', nyyoNow_(ss)],
    ['Clean clients', s.clients],
    ['Duplicates merged', res.merged],
    ['Rows to review', s.review],
    ['Paid (count)', s.paidCount],
    ['Paid (USD)', s.paid],
    ['Pending (count)', s.pendingCount],
    ['Pending (USD)', s.pending],
    ['', ''],
    ['City', 'clients / USD']
  ];
  Object.keys(s.cities).sort().forEach(function (k) { rows.push([k, s.cities[k].count + ' / ' + s.cities[k].amount.toFixed(2)]); });
  sh.clearContents();
  sh.getRange(1, 1, rows.length, 2).setValues(rows);
  sh.getRange(1, 1, 1, 2).setFontWeight('bold');
  sh.getRange(11, 1, 1, 2).setFontWeight('bold');
  return s;
}
