const puppeteer = require('puppeteer');

(async () => {
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-features=ntlm-auth']
  });
  const page = await browser.newPage();
  await page.goto('http://localhost:3000', {waitUntil: 'networkidle0', timeout: 30000});
  await page.waitForSelector('canvas', {timeout: 15000});
  await new Promise(r => setTimeout(r, 5000));
  const status = await page.evaluate(() => ({
    fontApplied: window.gameFontApplied,
    fontError: window.gameFontError,
    loaded: window.gameLoaded
  }));
  console.log(JSON.stringify(status, null, 2));
  await browser.close();
})();
