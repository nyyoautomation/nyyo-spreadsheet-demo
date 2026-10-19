/** Automations: last_updated stamp on edit (simple trigger) and the optional daily refresh (installable trigger). */

/** Simple trigger: runs by itself when someone edits the Data tab. Stamps the edited rows' last_updated cell. */
function onEdit(e) {
  if (!e || !e.range) return;
  var sh = e.range.getSheet();
  if (sh.getName() !== NYYO.tabs.data) return;
  var top = e.range.getRow(), n = e.range.getNumRows();
  if (top === 1) { top = 2; n--; }  // header edits are not stamped
  if (n < 1) return;
  var header = sh.getRange(1, 1, 1, sh.getLastColumn()).getValues()[0]
    .map(function (h) { return nyyoNormText_(h).toLowerCase(); });
  var ts = header.indexOf(NYYO.timestampColumn) + 1;
  if (!ts) return;
  var c1 = e.range.getColumn(), c2 = c1 + e.range.getNumColumns() - 1;
  if (c1 === ts && c2 === ts) return;  // editing the stamp itself: leave it alone (no loop)
  var now = nyyoNow_(sh.getParent ? sh.getParent() : nyyoSs_());
  var vals = []; for (var i = 0; i < n; i++) vals.push([now]);
  sh.getRange(top, ts, n, 1).setValues(vals);
}

function nyyoKitTriggers_() {
  return ScriptApp.getProjectTriggers().filter(function (t) { return t.getHandlerFunction() === 'nyyoDailyRefresh'; });
}

/** Menu "Turn on daily refresh": exactly one daily trigger, however many times you click. */
function nyyoEnableDailyRefresh() {
  var old = nyyoKitTriggers_();
  old.forEach(function (t) { ScriptApp.deleteTrigger(t); });
  ScriptApp.newTrigger('nyyoDailyRefresh').timeBased().everyDays(1).atHour(NYYO.dailyRefreshHour).create();
  nyyoLog_('daily refresh', 'on, around ' + NYYO.dailyRefreshHour + ':00' + (old.length ? ' (replaced ' + old.length + ' older trigger(s))' : ''));
  return nyyoToast_('Daily refresh is on (around ' + NYYO.dailyRefreshHour + ':00, spreadsheet time zone).');
}

/** Menu "Turn off daily refresh". */
function nyyoDisableDailyRefresh() {
  var old = nyyoKitTriggers_();
  old.forEach(function (t) { ScriptApp.deleteTrigger(t); });
  nyyoLog_('daily refresh', 'off (' + old.length + ' trigger(s) removed)');
  return nyyoToast_('Daily refresh is off.');
}

/** Run by the daily trigger. The lock stops two refreshes from overlapping. */
function nyyoDailyRefresh() {
  var lock = LockService.getDocumentLock();
  if (!lock.tryLock(30000)) return 'busy';
  try { return nyyoRefresh(); } finally { lock.releaseLock(); }
}
