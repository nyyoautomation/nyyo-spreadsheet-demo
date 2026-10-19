// Minimal in-memory stand-in for the Google Apps Script services the kit uses
// (SpreadsheetApp, ScriptApp, LockService, Utilities, Session). Test-only: it records calls so tests
// can check what the kit would do in a real spreadsheet. Not a full emulator.
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');


class Range {
  constructor(sheet, row, col, nr, nc) {
    if (row < 1 || col < 1 || nr < 1 || nc < 1) throw new Error(`Invalid range ${row},${col},${nr},${nc}`);
    Object.assign(this, { sheet, row, col, nr, nc });
  }
  getSheet() { return this.sheet; }
  getRow() { return this.row; }
  getColumn() { return this.col; }
  getNumRows() { return this.nr; }
  getNumColumns() { return this.nc; }
  getValues() {
    const out = [];
    for (let r = 0; r < this.nr; r++) {
      const row = [];
      for (let c = 0; c < this.nc; c++) row.push(this.sheet._get(this.row + r, this.col + c));
      out.push(row);
    }
    return out;
  }
  getValue() { return this.sheet._get(this.row, this.col); }
  setValues(v) {
    if (!Array.isArray(v) || v.length !== this.nr || v.some((r) => !Array.isArray(r) || r.length !== this.nc)) {
      throw new Error(`The number of rows or columns in the data does not match the range (${this.nr}x${this.nc})`);
    }
    v.forEach((r, i) => r.forEach((x, j) => this.sheet._set(this.row + i, this.col + j, x)));
    this.sheet.ss._calls.push(['setValues', this.sheet.name, this.row, this.col, this.nr, this.nc]);
    return this;
  }
  setValue(x) { this.sheet._set(this.row, this.col, x); return this; }
  setFontWeight() { return this; }
  setNumberFormat(f) { this.sheet.ss._calls.push(['setNumberFormat', this.sheet.name, this.row, this.col, f]); return this; }
}

class Sheet {
  constructor(ss, name) { this.ss = ss; this.name = name; this.cells = []; this.frozen = 0; }
  getName() { return this.name; }
  getParent() { return this.ss; }
  _get(r, c) { const row = this.cells[r - 1]; const v = row ? row[c - 1] : undefined; return v === undefined || v === null ? '' : v; }
  _set(r, c, v) { while (this.cells.length < r) this.cells.push([]); const row = this.cells[r - 1]; while (row.length < c) row.push(''); row[c - 1] = v; }
  _trim() { // last row/col = last non-empty cell, like Sheets
    for (const row of this.cells) while (row.length && (row[row.length - 1] === '' || row[row.length - 1] === undefined)) row.pop();
    while (this.cells.length && this.cells[this.cells.length - 1].length === 0) this.cells.pop();
  }
  getLastRow() { this._trim(); return this.cells.length; }
  getLastColumn() { this._trim(); return this.cells.reduce((m, r) => Math.max(m, r.length), 0); }
  getRange(row, col, nr = 1, nc = 1) { return new Range(this, row, col, nr, nc); }
  getDataRange() { return new Range(this, 1, 1, Math.max(this.getLastRow(), 1), Math.max(this.getLastColumn(), 1)); }
  clearContents() { this.cells = []; this.ss._calls.push(['clearContents', this.name]); return this; }
  clear() { return this.clearContents(); }
  setFrozenRows(n) { this.frozen = n; return this; }
  appendRow(vals) { const r = this.getLastRow() + 1; vals.forEach((v, i) => this._set(r, i + 1, v)); return this; }
  deleteRows(start, n) { this.cells.splice(start - 1, n); return this; }
  values() { this._trim(); return this.cells.map((r) => { const w = this.getLastColumn(); const o = r.slice(); while (o.length < w) o.push(''); return o; }); }
}

class Spreadsheet {
  constructor(tz) { this.sheets = [new Sheet(this, 'Sheet1')]; this.tz = tz; this.toasts = []; this._calls = []; }
  getSheetByName(n) { return this.sheets.find((s) => s.name === n) || null; }
  getSheets() { return this.sheets.slice(); }
  insertSheet(n) {
    if (this.getSheetByName(n)) throw new Error(`A sheet with the name "${n}" already exists.`);
    const s = new Sheet(this, n); this.sheets.push(s); return s;
  }
  getSpreadsheetTimeZone() { return this.tz; }
  toast(msg) { this.toasts.push(String(msg)); }
}

function formatDate(d, tz, fmt) {
  const p = Object.fromEntries(new Intl.DateTimeFormat('en-US', {
    timeZone: tz, year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit', hourCycle: 'h23',
  }).formatToParts(d).map((x) => [x.type, x.value]));
  return fmt.replace('yyyy', p.year).replace('MM', p.month).replace('dd', p.day).replace('HH', p.hour).replace('mm', p.minute).replace('ss', p.second);
}

/** Builds a fresh fake Google environment and loads the kit's code into it. */
function load(codeFiles, opts = {}) {
  const ss = new Spreadsheet(opts.tz || 'Etc/UTC');
  const triggers = [];
  const menus = [];
  let lockHeld = false;
  const ctx = {
    console: { log: () => {} },
    SpreadsheetApp: {
      getActiveSpreadsheet: () => ss, getActive: () => ss,
      getUi: () => ({
        createMenu(title) {
          const m = { title, items: [], addItem(label, fn) { this.items.push([label, fn]); return this; }, addSeparator() { this.items.push(['---']); return this; }, addToUi() { menus.push(this); } };
          return m;
        },
      }),
    },
    ScriptApp: {
      getProjectTriggers: () => triggers.slice(),
      deleteTrigger: (t) => { const i = triggers.indexOf(t); if (i >= 0) triggers.splice(i, 1); },
      newTrigger(fn) {
        const spec = { fn };
        const b = { timeBased() { spec.type = 'time'; return b; }, everyDays(n) { spec.everyDays = n; return b; }, atHour(h) { spec.atHour = h; return b; },
          create() { const t = { ...spec, getHandlerFunction: () => fn }; triggers.push(t); return t; } };
        return b;
      },
    },
    LockService: { getDocumentLock: () => ({ tryLock: () => { if (lockHeld) return false; lockHeld = true; return true; }, releaseLock: () => { lockHeld = false; } }) },
    Utilities: { formatDate },
    Session: { getScriptTimeZone: () => opts.tz || 'Etc/UTC' },
  };
  vm.createContext(ctx);
  for (const f of codeFiles) vm.runInContext(fs.readFileSync(f, 'utf8'), ctx, { filename: path.basename(f) });
  return { ctx, ss, triggers, menus, setLock: (v) => { lockHeld = v; } };
}

module.exports = { load, Spreadsheet, Sheet, Range, formatDate };
