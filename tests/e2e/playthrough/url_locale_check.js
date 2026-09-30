// sanity: does ?locale=hy really boot the game in Armenian?
const puppeteer = require('puppeteer');
const sleep = ms => new Promise(r => setTimeout(r, ms));
(async () => {
  const browser = await puppeteer.launch({ headless: true, args: ['--no-sandbox', '--disable-web-security', '--disable-features=ntlm-auth'] });
  const page = await browser.newPage();
  // Pre-seed a RUPLICATE ru preference to prove the URL override wins
  await page.evaluateOnNewDocument(() => { try { localStorage.setItem('bookwar_locale', 'ru'); } catch (e) {} });
  await page.goto('http://localhost:3000/?locale=hy', { waitUntil: 'domcontentloaded' });
  await page.waitForSelector('canvas', { timeout: 30000 });
  await sleep(6000);
  const st = await page.evaluate(() => ({
    locale: window.gameLocale,
    alphabetCount: (window.gameAlphabet || []).length,
    firstLetter: (window.gameAlphabet || [])[0]?.char,
    coverage: window.gameFontCoverage,
    menuVisible: window.gameMenuVisible
  }));
  console.log(JSON.stringify(st, null, 1));
  await browser.close();
  const ok = st.locale === 'hy' && st.alphabetCount === 39 && st.firstLetter === 'Ա' && st.coverage && st.coverage.armenian === true;
  console.log(ok ? 'OK: boots in Armenian (39 letters, glyphs covered)' : 'FAIL');
  process.exit(ok ? 0 : 1);
})();
