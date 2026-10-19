/** The "Nyyo kit" menu. It appears each time the spreadsheet is opened (reload the tab after installing). */

function onOpen() {
  SpreadsheetApp.getUi()
    .createMenu('Nyyo kit')
    .addItem('1. Set up (safe to run again)', 'nyyoSetup')
    .addItem('2. Clean + refresh dashboard', 'nyyoRefresh')
    .addSeparator()
    .addItem('Load sample data (empty Data tab only)', 'nyyoLoadSample')
    .addItem('Turn on daily refresh', 'nyyoEnableDailyRefresh')
    .addItem('Turn off daily refresh', 'nyyoDisableDailyRefresh')
    .addSeparator()
    .addItem('About this kit', 'nyyoAbout')
    .addToUi();
}

function onInstall(e) { onOpen(e); }

function nyyoAbout() {
  return nyyoToast_('Nyyo Sheets kit ' + NYYO.version + ' (MIT). Guide: the "How to use" tab. Questions? Ask in your order chat.');
}
