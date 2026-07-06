// Capture all console logs from BOOKWAR HTML5 game
const puppeteer = require('puppeteer');

(async () => {
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-features=ntlm-auth', '--disable-web-security']
  });
  const page = await browser.newPage();

  const logs = [];
  page.on('console', msg => {
    logs.push(`[${msg.type()}] ${msg.text()}`);
  });
  page.on('pageerror', err => logs.push(`[PAGE_ERROR] ${err.message}`));
  page.on('requestfailed', req => {
    if (!req.url().includes('duckduckgo')) {
      logs.push(`[REQ_FAIL] ${req.url()} - ${req.failure()?.errorText}`);
    }
  });

  console.log('[capture] loading game...');
  await page.goto('http://localhost:3000/index.html', { waitUntil: 'load', timeout: 30000 });
  await new Promise(r => setTimeout(r, 8000));

  // Check game state
  const state = await page.evaluate(() => ({
    loaded: !!window.gameLoaded,
    menuVisible: !!window.gameMenuVisible,
    pckSize: window.godotPckSize || 'n/a'
  }));
  console.log('[capture] state:', JSON.stringify(state));

  // Print all collected logs
  console.log('\n=== GAME CONSOLE LOGS ===');
  for (const line of logs) console.log(line);
  console.log(`\n=== Total: ${logs.length} log entries ===`);

  await browser.close();
})();
