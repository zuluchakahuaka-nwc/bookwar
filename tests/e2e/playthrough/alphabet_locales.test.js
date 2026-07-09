// e2e: verify alphabet loads per-locale with correct letter count.
// §2.0: N letters -> N levels. Confirm each locale reports correct N.
const puppeteer = require('puppeteer');
const sleep = ms => new Promise(r => setTimeout(r, ms));

const EXPECTED = {
  ru: 33,
  en: 26,
  es: 27,
  de: 30,
  fr: 26,
  pt: 26,
  it: 21,
  ar: 28,
  zh: 214,  // §I18N: 214 ключей Канси — самая длинная версия игры
};

(async () => {
  const browser = await puppeteer.launch({ headless: true, args: ['--no-sandbox', '--disable-web-security', '--disable-features=ntlm-auth'] });
  const page = await browser.newPage();
  await page.goto('http://localhost:3000', { waitUntil: 'domcontentloaded' });
  await page.waitForSelector('canvas', { timeout: 30000 });
  await sleep(5000);

  const results = [];
  for (const [locale, expectedN] of Object.entries(EXPECTED)) {
    await page.evaluate((l) => window.gameSetLocale && window.gameSetLocale(l), locale);
    await sleep(1500); // allow AlphabetData reload via signal
    const snapshot = await page.evaluate(() => ({
      count: (window.gameAlphabet || []).length,
      locale: window.gameLocale,
      firstChar: (window.gameAlphabet || [])[0]?.char || '',
      lastChar: (window.gameAlphabet || [])[window.gameAlphabet?.length - 1]?.char || ''
    }));
    const ok = snapshot.count === expectedN;
    results.push({ locale, expected: expectedN, got: snapshot.count, ok, sample: `${snapshot.firstChar}..${snapshot.lastChar}` });
    console.log(`${locale.padEnd(4)} expected=${expectedN} got=${snapshot.count} ${ok ? 'OK' : 'FAIL'} (${snapshot.sample})`);
  }

  const failed = results.filter(r => !r.ok);
  console.log('\n=== SUMMARY ===');
  console.log(`Passed: ${results.length - failed.length} / ${results.length}`);
  if (failed.length > 0) {
    console.log('Failed:', JSON.stringify(failed, null, 2));
  }
  await browser.close();
  process.exit(failed.length > 0 ? 1 : 0);
})();
