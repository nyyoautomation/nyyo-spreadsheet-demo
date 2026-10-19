/**
 * Nyyo Sheets kit 1.0.0 - free 1-click install kit (MIT licence), Nyyo Automation.
 * Clean a messy "Data" tab into a "Clean" tab, build a "Dashboard", stamp edited rows,
 * and (optional) refresh everything once a day. Everything stays in your own spreadsheet.
 *
 * @OnlyCurrentDoc  (the kit can only open the spreadsheet it is installed in)
 *
 * Settings you may change: tab names, which column identifies a client, accepted statuses,
 * sort order and the hour of the daily refresh. Column order in "Data" does not matter:
 * columns are found by their header name (upper or lower case both work).
 */
var NYYO = {
  version: '1.0.0',
  tabs: { data: 'Data', clean: 'Clean', dashboard: 'Dashboard', howto: 'How to use', log: 'Change log' },
  // Columns of the Data tab. The kit adds any that are missing at the end, never removes one.
  headers: ['client_id', 'name', 'phone', 'signup_date', 'amount_usd', 'status', 'city', 'last_updated'],
  keyColumn: 'client_id',        // duplicates = same client_id (or same name + phone when client_id is empty)
  statuses: ['paid', 'pending'], // any other status is flagged for review, never deleted
  timestampColumn: 'last_updated',
  sortBy: ['signup_date', 'name'],
  dailyRefreshHour: 6,           // 0-23, in the spreadsheet's time zone
  logMaxRows: 500,
  cleanHeaders: ['client_id', 'name', 'phone', 'signup_date', 'amount_usd', 'status', 'city', 'notes']
};
