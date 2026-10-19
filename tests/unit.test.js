// Unit tests of the Apps Script code against the in-memory stand-in (tests/shim/sheets_shim.js).
//   node --test tests/unit.test.js            (tests the source files in apps-script/)
//   NYYO_BUNDLE=path/NyyoSheetsKit.gs node --test tests/unit.test.js   (tests the one-file copy-paste bundle)
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const { load } = require('./shim/sheets_shim');

const ROOT = path.join(__dirname, '..');
const ORDER = fs.readFileSync(path.join(ROOT, 'scripts/bundle-order.txt'), 'utf8').split('\n').filter(Boolean);
const FILES = process.env.NYYO_BUNDLE ? [process.env.NYYO_BUNDLE] : ORDER.map((f) => path.join(ROOT, 'apps-script', f));
const env = (opts) => load(FILES, opts);
const csv = (file) => fs.readFileSync(file, 'utf8').trim().split('\n').map((l) => {
  const out = []; let cur = ''; let q = false;
  for (const ch of l) { if (ch === '"') q = !q; else if (ch === ',' && !q) { out.push(cur); cur = ''; } else cur += ch; }
  out.push(cur); return out;
});
const asText = (rows) => rows.map((r) => r.map((v) => (v === '' ? '' : String(v))));
const tab = (e, n) => e.ss.getSheetByName(n);
const logActions = (e) => tab(e, 'Change log').values().slice(1).map((r) => r[1]);

test('date rules: every accepted format, and impossible dates are refused', () => {
  const { ctx } = env();
  const p = (v) => ctx.nyyoParseDate_(v, 'Etc/UTC');
  assert.equal(p('2025-01-15'), '2025-01-15');
  assert.equal(p('01/15/2025'), '2025-01-15');   // month first
  assert.equal(p('15/01/2025'), '2025-01-15');   // day first (month 15 impossible)
  assert.equal(p('03/04/2025'), '2025-03-04');   // ambiguous: month first wins, like the Python demo
  assert.equal(p('2025/02/10'), '2025-02-10');
  assert.equal(p('20-01-2025'), '2025-01-20');
  assert.equal(p('Feb 3 2025'), '2025-02-03');
  assert.equal(p('February 3, 2025'), '2025-02-03');
  assert.equal(p('05/03/25'), '2025-03-05');
  for (const bad of ['32/13/2025', '2025-02-30', '2023-02-29', 'Foo 3 2025', '', 'n/a', '13/13/13']) assert.equal(p(bad), null, bad);
  assert.equal(p('2024-02-29'), '2024-02-29');
});

test('date cells (real Date values from Sheets) are read in the spreadsheet time zone', () => {
  const { ctx } = env();
  const d = vm.runInContext('new Date(Date.UTC(2025, 0, 15, 23, 30))', ctx);
  assert.equal(ctx.nyyoParseDate_(d, 'Etc/UTC'), '2025-01-15');
  assert.equal(ctx.nyyoParseDate_(d, 'Asia/Tokyo'), '2025-01-16');
  assert.equal(ctx.nyyoParseDate_(vm.runInContext('new Date(NaN)', ctx), 'Etc/UTC'), null);
});

test('amount rules', () => {
  const { ctx } = env();
  const a = ctx.nyyoParseAmount_;
  assert.equal(a('$1,200.50'), 1200.5);
  assert.equal(a('2,100.00 USD'), 2100);
  assert.equal(a('450,75'), 450.75);
  assert.equal(a('1 350'), 1350);
  assert.equal(a('950 USD '), 950);
  assert.equal(a(1200.499), 1200.5);
  assert.equal(a(-12), -12);
  for (const bad of ['abc', '', '1.2.3', 'n/a']) assert.equal(a(bad), null, bad);
});

test('names, phones, keys', () => {
  const { ctx } = env();
  assert.equal(ctx.nyyoNormName_('  DANIEL  LEE'), 'Daniel Lee');
  assert.equal(ctx.nyyoNormName_("mary-jane o'neil"), "Mary-Jane O'Neil");
  assert.equal(ctx.nyyoNormPhone_('(555) 010-4'), '5550104');
  assert.equal(ctx.nyyoNormPhone_('555'), '');
  assert.equal(ctx.nyyoNormPhone_(5550101), '5550101');
  assert.equal(ctx.nyyoNormKey_(' c-1001 '), 'C-1001');
});

test('first install on a blank spreadsheet: tabs, sample, clean result exactly as expected', () => {
  const e = env();
  e.ctx.nyyoSetup();
  for (const n of ['Data', 'Clean', 'Dashboard', 'How to use', 'Change log']) assert.ok(tab(e, n), n);
  assert.deepEqual(tab(e, 'Data').values()[0], ['client_id', 'name', 'phone', 'signup_date', 'amount_usd', 'status', 'city', 'last_updated']);
  assert.equal(tab(e, 'Data').values().length, 11);
  assert.deepEqual(asText(tab(e, 'Clean').values()), csv(path.join(ROOT, 'tests/expected_clean.csv')));
  assert.match(e.ss.toasts.at(-1), /6 clean row\(s\), 2 duplicate\(s\) merged, 1 to review, 1 empty-name row\(s\) skipped/);
  assert.equal(tab(e, 'Sheet1').values().length, 0, 'the default tab is left alone');
});

test('the kit and the Python demo (clean_demo.py output) agree on every cleaned value', () => {
  const e = env(); e.ctx.nyyoSetup();
  const kit = tab(e, 'Clean').values().slice(1);
  const py = csv(path.join(ROOT, 'cleaned_sample.csv')).slice(1);
  assert.equal(kit.length, py.length);
  const num = (v) => (v === '' ? '' : Number(v));
  kit.forEach((k, i) => {
    const p = py[i];  // python: name,email,phone,signup_date,amount_usd,status,city,notes
    assert.deepEqual([k[1], String(k[2]), k[3], num(k[4]), k[5], k[6]], [p[0], p[2], p[3], num(p[4]), p[5], p[6]], `row ${i + 2}`);
  });
});

test('dashboard figures', () => {
  const e = env(); e.ctx.nyyoSetup();
  const d = Object.fromEntries(tab(e, 'Dashboard').values().map((r) => [r[0], r[1]]));
  assert.equal(d['Clean clients'], 6);
  assert.equal(d['Duplicates merged'], 2);
  assert.equal(d['Rows to review'], 1);
  assert.equal(d['Paid (count)'], 4);
  assert.equal(d['Paid (USD)'], 5450.5);
  assert.equal(d['Pending (USD)'], 1400.75);
  assert.equal(d.Boston, '2 / 2000.50');
  assert.match(d['Last refresh'], /^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d$/);
});

test('re-running Set up and Refresh is safe: no new tabs, Data untouched, same Clean, How to use not duplicated', () => {
  const e = env(); e.ctx.nyyoSetup();
  const data1 = JSON.stringify(tab(e, 'Data').values());
  const clean1 = JSON.stringify(tab(e, 'Clean').values());
  const howto1 = JSON.stringify(tab(e, 'How to use').values());
  const tabs1 = e.ss.getSheets().map((s) => s.getName());
  e.ctx.nyyoSetup(); e.ctx.nyyoRefresh(); e.ctx.nyyoSetup();
  assert.deepEqual(e.ss.getSheets().map((s) => s.getName()), tabs1);
  assert.equal(JSON.stringify(tab(e, 'Data').values()), data1);
  assert.equal(JSON.stringify(tab(e, 'Clean').values()), clean1);
  assert.equal(JSON.stringify(tab(e, 'How to use').values()), howto1);
  assert.match(e.ss.toasts.at(-1), /Nothing to create/);
});

test('the cleaning never writes to the Data tab', () => {
  const e = env(); e.ctx.nyyoSetup();
  e.ss._calls.length = 0;
  e.ctx.nyyoRefresh();
  assert.ok(!e.ss._calls.some((c) => c[1] === 'Data'), JSON.stringify(e.ss._calls.filter((c) => c[1] === 'Data')));
});

test('existing buyer sheet: own column order and extra columns kept, missing kit columns added at the end, no sample loaded', () => {
  const e = env();
  const d = e.ss.insertSheet('Data');
  const rows = [['Name', 'City', 'Notes from me', 'Client_ID', 'Status', 'Amount_USD', 'Signup_Date', 'Phone'],
    ['zoe park', 'reno', 'vip', 'Z-1', 'paid', '10', '2025-05-01', '5551234'],
    ['Zoe Park', 'Reno', '', 'z-1', 'paid', '10', '05/01/2025', '555-1234']];
  rows.forEach((r) => d.appendRow(r));
  e.ctx.nyyoSetup();
  const v = tab(e, 'Data').values();
  assert.deepEqual(v[0], [...rows[0], 'last_updated']);
  assert.equal(v.length, 3, 'no sample rows added to a Data tab that has rows');
  assert.deepEqual(v[1].slice(0, 8), rows[1]);
  const c = tab(e, 'Clean').values();
  assert.equal(c.length, 2);
  assert.deepEqual(c[1], ['Z-1', 'Zoe Park', '5551234', '2025-05-01', 10, 'paid', 'Reno', 'merged duplicate rows']);
  assert.ok(logActions(e).includes('setup'));
});

test('empty Data: Clean and Dashboard kept as they were (an empty result never replaces a good one)', () => {
  const e = env(); e.ctx.nyyoSetup();
  const clean1 = JSON.stringify(tab(e, 'Clean').values());
  const dash1 = JSON.stringify(tab(e, 'Dashboard').values());
  const d = tab(e, 'Data'); const header = d.values()[0];
  d.clearContents(); d.appendRow(header);
  assert.match(e.ctx.nyyoRefresh(), /Data has no rows/);
  assert.equal(JSON.stringify(tab(e, 'Clean').values()), clean1);
  assert.equal(JSON.stringify(tab(e, 'Dashboard').values()), dash1);
});

test('missing required column: clear message, nothing cleared', () => {
  const e = env(); e.ctx.nyyoSetup();
  const clean1 = JSON.stringify(tab(e, 'Clean').values());
  const d = tab(e, 'Data'); d._set(1, 5, 'amount');  // buyer renamed amount_usd
  assert.match(e.ctx.nyyoRefresh(), /Missing column\(s\) in the Data tab: amount_usd/);
  assert.equal(JSON.stringify(tab(e, 'Clean').values()), clean1);
});

test('Load sample: refuses when Data has rows, works on an empty Data tab', () => {
  const e = env(); e.ctx.nyyoSetup();
  const before = JSON.stringify(tab(e, 'Data').values());
  assert.match(e.ctx.nyyoLoadSample(), /already has rows/);
  assert.equal(JSON.stringify(tab(e, 'Data').values()), before);
  const d = tab(e, 'Data'); const header = d.values()[0]; d.clearContents(); d.appendRow(header);
  assert.match(e.ctx.nyyoLoadSample(), /Sample rows loaded/);
  assert.equal(tab(e, 'Data').values().length, 11);
});

test('onEdit stamps last_updated on edited Data rows only', () => {
  const e = env(); e.ctx.nyyoSetup();
  const d = tab(e, 'Data');
  e.ctx.onEdit({ range: d.getRange(3, 2, 2, 1) });           // rows 3-4, name column
  const v = d.values();
  assert.match(String(v[2][7]), /^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d$/);
  assert.match(String(v[3][7]), /^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d$/);
  assert.equal(v[1][7], '');
  assert.equal(v[4][7], '');
  d._set(5, 8, 'typed by hand');
  e.ctx.onEdit({ range: d.getRange(5, 8) });                 // editing the stamp itself: left alone
  assert.equal(d.values()[4][7], 'typed by hand');
  e.ctx.onEdit({ range: d.getRange(1, 1) });                 // header: nothing stamped
  assert.equal(d.values()[0][7], 'last_updated');
  const c1 = JSON.stringify(tab(e, 'Clean').values());
  e.ctx.onEdit({ range: tab(e, 'Clean').getRange(2, 2) });   // other tab: nothing
  assert.equal(JSON.stringify(tab(e, 'Clean').values()), c1);
  e.ctx.onEdit({}); e.ctx.onEdit(undefined);                 // run by hand from the editor: no crash
});

test('daily refresh: exactly one trigger however many clicks, off removes it, lock prevents overlap', () => {
  const e = env(); e.ctx.nyyoSetup();
  e.ctx.nyyoEnableDailyRefresh(); e.ctx.nyyoEnableDailyRefresh(); e.ctx.nyyoEnableDailyRefresh();
  assert.equal(e.triggers.length, 1);
  assert.deepEqual({ fn: e.triggers[0].fn, type: e.triggers[0].type, everyDays: e.triggers[0].everyDays, atHour: e.triggers[0].atHour },
    { fn: 'nyyoDailyRefresh', type: 'time', everyDays: 1, atHour: 6 });
  assert.match(e.ctx.nyyoDailyRefresh(), /6 clean row/);
  e.setLock(true); assert.equal(e.ctx.nyyoDailyRefresh(), 'busy'); e.setLock(false);
  e.ctx.nyyoDisableDailyRefresh(); e.ctx.nyyoDisableDailyRefresh();
  assert.equal(e.triggers.length, 0);
});

test('menu: every item points to a function that exists', () => {
  const e = env(); e.ctx.onOpen();
  assert.equal(e.menus.length, 1);
  assert.equal(e.menus[0].title, 'Nyyo kit');
  const items = e.menus[0].items.filter((i) => i[0] !== '---');
  assert.equal(items.length, 6);
  for (const [, fn] of items) assert.equal(typeof e.ctx[fn], 'function', fn);
});

test('change log is capped (oldest rows removed)', () => {
  const e = env(); e.ctx.nyyoSetup();
  e.ctx.NYYO.logMaxRows = 5;
  for (let i = 0; i < 9; i++) e.ctx.nyyoRefresh();
  assert.equal(tab(e, 'Change log').values().length, 6);
  assert.equal(tab(e, 'Change log').values()[0][0], 'when');
});

test('works in other time zones', () => {
  const e = env({ tz: 'America/Los_Angeles' }); e.ctx.nyyoSetup();
  assert.deepEqual(asText(tab(e, 'Clean').values()), csv(path.join(ROOT, 'tests/expected_clean.csv')));
});

test('scopes: manifest asks only for this spreadsheet, the menu and triggers', () => {
  const m = JSON.parse(fs.readFileSync(path.join(ROOT, 'apps-script/appsscript.json'), 'utf8'));
  assert.deepEqual(m.oauthScopes.sort(), ['https://www.googleapis.com/auth/script.container.ui',
    'https://www.googleapis.com/auth/script.scriptapp', 'https://www.googleapis.com/auth/spreadsheets.currentonly']);
  const code = FILES.map((f) => fs.readFileSync(f, 'utf8')).join('\n');
  assert.match(code, /@OnlyCurrentDoc/);
  for (const svc of ['UrlFetchApp', 'MailApp', 'GmailApp', 'DriveApp', 'SpreadsheetApp.openById', 'SpreadsheetApp.openByUrl']) assert.ok(!code.includes(svc), svc);
});
