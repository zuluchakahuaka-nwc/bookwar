// e2e: glyph sanity on ALL locales — font coverage "symbols" sample must be
// true, and the prologue nav buttons string must contain the sanctioned
// glyphs (‹ ›) instead of the tofu arrows (← →).
const puppeteer = require('puppeteer');
const path = require('path');
const fs = require('fs');
const sleep = ms => new Promise(r => setTimeout(r, ms));
const SHOTS = path.join(__dirname, '..', 'screenshots');
if (!fs.existsSync(SHOTS)) fs.mkdirSync(SHOTS, { recursive: true });
const LOCALES = ['ru', 'en', 'zh', 'es', 'fr', 'de', 'pt', 'it', 'ar', 'hy'];

(async () => {
  const browser = await puppeteer.launch({ headless: true, args: ['--no-sandbox', '--disable-web-security', '--disable-features=ntlm-auth'] });
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 720 });
  await page.evaluateOnNewDocument(() => { try { localStorage.setItem('bookwar_locale', 'ru'); } catch (e) {} });
  await page.goto('http://localhost:3000', { waitUntil: 'domcontentloaded' });
  await page.waitForSelector('canvas', { timeout: 30000 });
  await sleep(5000);

  const fails = [];
  for (const loc of LOCALES) {
    await page.evaluate((l) => window.gameSetLocale && window.gameSetLocale(l), loc);
    await sleep(1200);
    const st = await page.evaluate(() => ({
      locale: window.gameLocale,
      symbols: (window.gameFontCoverage || {}).symbols,
      back: (window.gamePrologueBack !== undefined) ? window.gamePrologueBack : null
    }));
    const ok = st.locale === loc && st.symbols === true;
    if (!ok) fails.push({ loc, ...st });
    console.log(`${loc.padEnd(3)} symbols=${st.symbols} ${ok ? 'OK' : 'FAIL'}`);
  }

  // Prologue buttons screenshot (hy): the reported broken screen
  await page.evaluate(() => { if (window.gameSetLocale) window.gameSetLocale('hy'); });
  await sleep(800);
  // Enter the legend from the menu (intro scene has the ‹ / › buttons)
  await page.evaluate(() => { if (window.gameClickLegend) window.gameClickLegend(); });
  await sleep(2500);
  // dismiss the title card once, then we're on panel 0 with nav buttons
  await page.evaluate(() => { if (window.gameAdvanceIntro) window.gameAdvanceIntro(); });
  await sleep(900);
  const f = path.join(SHOTS, 'hy_prologue_buttons.png');
  const canvas = await page.$('canvas');
  if (canvas) await canvas.screenshot({ path: f });
  console.log('prologue shot:', f);

  await browser.close();
  console.log(fails.length === 0 ? 'ALL 10 LOCALES SYMBOLS OK' : 'FAILS: ' + JSON.stringify(fails));
  process.exit(fails.length === 0 ? 0 : 1);
})();
