// e2e: first-launch language picker — no saved locale → picker shows, click
// Հայերեն → engine boots in Armenian. Also proves ?locale= bypasses it.
const puppeteer = require('puppeteer');
const sleep = ms => new Promise(r => setTimeout(r, ms));

async function launch(clean) {
  const browser = await puppeteer.launch({ headless: true, args: ['--no-sandbox', '--disable-web-security', '--disable-features=ntlm-auth'] });
  const page = await browser.newPage();
  if (clean) {
    await page.evaluateOnNewDocument(() => {
      try { localStorage.removeItem('bookwar_locale'); localStorage.removeItem('bookwar_intro_seen'); } catch (e) {}
    });
  }
  return { browser, page };
}

(async () => {
  const results = {};

  // Case 1: clean profile → picker visible before engine start
  {
    const { browser, page } = await launch(true);
    await page.goto('http://localhost:3000/', { waitUntil: 'domcontentloaded' });
    await sleep(1500);
    const picker = await page.evaluate(() => {
      const p = document.getElementById('lang-picker');
      return { visible: !!(p && p.classList.contains('visible')), buttons: document.querySelectorAll('.lp-btn').length, engineStarted: !!window.engine };
    });
    results.pickerVisible = picker.visible && picker.buttons === 10;
    results.engineNotStarted = !picker.engineStarted;
    console.log('picker:', JSON.stringify(picker));
    // Click Հայերեն (last button)
    const clicked = await page.evaluate(() => {
      const btns = Array.from(document.querySelectorAll('.lp-btn'));
      const hy = btns.find(b => b.textContent.includes('Հայերեն'));
      if (hy) { hy.click(); return true; }
      return false;
    });
    await sleep(500);
    const localeSaved = await page.evaluate(() => localStorage.getItem('bookwar_locale'));
    await page.waitForSelector('canvas', { timeout: 30000 });
    await sleep(6000);
    const st = await page.evaluate(() => ({
      locale: window.gameLocale,
      alphabet: (window.gameAlphabet || []).length
    }));
    results.clickBootsHy = clicked && localeSaved === 'hy' && st.locale === 'hy' && st.alphabet === 39;
    console.log('after click:', JSON.stringify(st), 'saved:', localeSaved);
    await browser.close();
  }

  // Case 2: ?locale=hy bypasses the picker entirely
  {
    const { browser, page } = await launch(true);
    await page.goto('http://localhost:3000/?locale=hy', { waitUntil: 'domcontentloaded' });
    await sleep(1200);
    const picker = await page.evaluate(() => {
      const p = document.getElementById('lang-picker');
      return !!(p && p.classList.contains('visible'));
    });
    results.urlBypassesPicker = !picker;
    console.log('url picker visible:', picker);
    await browser.close();
  }

  console.log('RESULTS:', JSON.stringify(results, null, 1));
  const ok = results.pickerVisible && results.engineNotStarted !== false && results.clickBootsHy && results.urlBypassesPicker;
  console.log(ok ? 'ALL OK' : 'FAIL');
  process.exit(ok ? 0 : 1);
})();
