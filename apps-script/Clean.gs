/** Cleaning rules (pure functions: no spreadsheet access, unit-tested on their own). */

function nyyoNormText_(v) {
  return String(v === null || v === undefined ? '' : v).replace(/\s+/g, ' ').trim();
}

function nyyoNormName_(v) {
  return nyyoNormText_(v).toLowerCase().replace(/(^|[\s'-])([a-z\u00e0-\u00ff])/g, function (m, p, c) {
    return p + c.toUpperCase();
  });
}

function nyyoNormKey_(v) {
  return nyyoNormText_(v).toUpperCase();
}

function nyyoNormPhone_(v) {
  var digits = nyyoNormText_(v).replace(/\D/g, '');
  return digits.length >= 6 ? digits : '';
}

function nyyoPad_(n) { return (n < 10 ? '0' : '') + n; }

function nyyoValidYmd_(y, m, d) {
  if (y < 1900 || y > 2100 || m < 1 || m > 12 || d < 1) return null;
  var days = [31, (y % 4 === 0 && y % 100 !== 0) || y % 400 === 0 ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  if (d > days[m - 1]) return null;
  return y + '-' + nyyoPad_(m) + '-' + nyyoPad_(d);
}

var NYYO_MONTHS_ = { jan: 1, feb: 2, mar: 3, apr: 4, may: 5, jun: 6, jul: 7, aug: 8, sep: 9, oct: 10, nov: 11, dec: 12 };

/**
 * Any date -> 'YYYY-MM-DD', or null when it cannot be read safely.
 * Date cells are read in the spreadsheet's time zone. Text is tried in this order:
 * 2025-01-15, 01/15/2025 (month first), 15/01/2025 (day first), 2025/01/15, 15-01-2025, Jan 15 2025, 15/01/25.
 */
function nyyoParseDate_(v, tz) {
  if (v instanceof Date) {
    if (isNaN(v.getTime())) return null;
    return Utilities.formatDate(v, tz || 'Etc/UTC', 'yyyy-MM-dd');
  }
  var s = nyyoNormText_(v), m;
  if (!s) return null;
  if ((m = /^(\d{4})-(\d{1,2})-(\d{1,2})$/.exec(s))) return nyyoValidYmd_(+m[1], +m[2], +m[3]);
  if ((m = /^(\d{1,2})\/(\d{1,2})\/(\d{4})$/.exec(s))) {
    return nyyoValidYmd_(+m[3], +m[1], +m[2]) || nyyoValidYmd_(+m[3], +m[2], +m[1]);
  }
  if ((m = /^(\d{4})\/(\d{1,2})\/(\d{1,2})$/.exec(s))) return nyyoValidYmd_(+m[1], +m[2], +m[3]);
  if ((m = /^(\d{1,2})-(\d{1,2})-(\d{4})$/.exec(s))) return nyyoValidYmd_(+m[3], +m[2], +m[1]);
  if ((m = /^([A-Za-z]{3})[a-z]*\.? (\d{1,2}),? (\d{4})$/.exec(s))) {
    var mon = NYYO_MONTHS_[m[1].toLowerCase()];
    return mon ? nyyoValidYmd_(+m[3], mon, +m[2]) : null;
  }
  if ((m = /^(\d{1,2})\/(\d{1,2})\/(\d{2})$/.exec(s))) return nyyoValidYmd_(2000 + +m[3], +m[2], +m[1]);
  return null;
}

/** '$1,200.50', '2,100.00 USD', '450,75', '1 350', 1200.5 -> number rounded to cents, or null. */
function nyyoParseAmount_(v) {
  if (typeof v === 'number') return isFinite(v) ? Math.round(v * 100) / 100 : null;
  var s = nyyoNormText_(v).replace(/[^0-9,.\-]/g, '');
  if (!s) return null;
  if ((s.match(/,/g) || []).length === 1 && s.indexOf('.') === -1) s = s.replace(',', '.');
  else s = s.replace(/,/g, '');
  if (!/^-?\d+(\.\d+)?$/.test(s)) return null;
  return Math.round(parseFloat(s) * 100) / 100;
}

/** Finds each wanted column by header name. Returns { name: index } and throws on a missing required column. */
function nyyoColumnMap_(header, required) {
  var map = {};
  for (var i = 0; i < header.length; i++) {
    var h = nyyoNormText_(header[i]).toLowerCase();
    if (h && !(h in map)) map[h] = i;
  }
  var missing = required.filter(function (r) { return !(r in map); });
  if (missing.length) throw new Error('Missing column(s) in the Data tab: ' + missing.join(', ') + '. Run "1. Set up" to add them.');
  return map;
}

/**
 * The cleaning itself. rows = Data values without the header.
 * Returns { rows: [[...cleanHeaders]], kept, merged, review, skipped }.
 * Rows with no name are skipped (empty lines). Rows with a bad date, amount or status are kept at the
 * bottom with a note, never deleted. Duplicates (same key) are merged into the first one.
 */
function nyyoCleanRows_(header, rows, cfg, tz) {
  var need = ['name', 'phone', 'signup_date', 'amount_usd', 'status', 'city', cfg.keyColumn];
  var col = nyyoColumnMap_(header, need);
  var byKey = {}, order = [], review = [], skipped = 0, merged = 0;
  rows.forEach(function (r) {
    var name = nyyoNormName_(r[col.name]);
    if (!name) { skipped++; return; }
    var rec = {
      client_id: nyyoNormKey_(r[col[cfg.keyColumn]]),
      name: name,
      phone: nyyoNormPhone_(r[col.phone]),
      signup_date: nyyoParseDate_(r[col.signup_date], tz),
      amount_usd: nyyoParseAmount_(r[col.amount_usd]),
      status: nyyoNormText_(r[col.status]).toLowerCase(),
      city: nyyoNormName_(r[col.city]),
      notes: ''
    };
    var problems = [];
    if (rec.signup_date === null) problems.push('date');
    if (rec.amount_usd === null) problems.push('amount');
    if (cfg.statuses.indexOf(rec.status) === -1) problems.push('status');
    if (problems.length) {
      rec.notes = 'NEEDS REVIEW: ' + problems.join(', ');
      review.push(rec);
      return;
    }
    var key = rec.client_id || (rec.name.toLowerCase() + '|' + rec.phone);
    if (byKey[key]) { byKey[key].notes = 'merged duplicate rows'; merged++; return; }
    byKey[key] = rec;
    order.push(key);
  });
  var kept = order.map(function (k) { return byKey[k]; });
  var sortBy = cfg.sortBy || [];
  kept.sort(function (a, b) {
    for (var i = 0; i < sortBy.length; i++) {
      var x = String(a[sortBy[i]]).toLowerCase(), y = String(b[sortBy[i]]).toLowerCase();
      if (x < y) return -1;
      if (x > y) return 1;
    }
    return 0;
  });
  var out = kept.concat(review).map(function (rec) {
    return cfg.cleanHeaders.map(function (h) {
      var v = rec[h];
      return v === null || v === undefined ? '' : v;
    });
  });
  return { rows: out, kept: kept.length, merged: merged, review: review.length, skipped: skipped };
}

/** Dashboard figures from the cleaned rows. */
function nyyoSummary_(cleanRows, cfg) {
  var c = {}; cfg.cleanHeaders.forEach(function (h, i) { c[h] = i; });
  var s = { clients: 0, review: 0, paid: 0, pending: 0, paidCount: 0, pendingCount: 0, cities: {} };
  cleanRows.forEach(function (r) {
    if (String(r[c.notes]).indexOf('NEEDS REVIEW') === 0) { s.review++; return; }
    s.clients++;
    var amt = Number(r[c.amount_usd]) || 0;
    if (r[c.status] === 'paid') { s.paid += amt; s.paidCount++; }
    if (r[c.status] === 'pending') { s.pending += amt; s.pendingCount++; }
    var city = r[c.city] || '(no city)';
    if (!s.cities[city]) s.cities[city] = { count: 0, amount: 0 };
    s.cities[city].count++;
    s.cities[city].amount += amt;
  });
  s.paid = Math.round(s.paid * 100) / 100;
  s.pending = Math.round(s.pending * 100) / 100;
  Object.keys(s.cities).forEach(function (k) { s.cities[k].amount = Math.round(s.cities[k].amount * 100) / 100; });
  return s;
}
