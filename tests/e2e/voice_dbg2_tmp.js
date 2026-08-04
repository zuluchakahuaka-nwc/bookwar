const puppeteer = require('puppeteer');
const sleep = ms => new Promise(r => setTimeout(r, ms));
(async () => {
  const browsers = [];
  async function setup(name) {
    const b = await puppeteer.launch({ headless: true, args: ['--no-sandbox','--disable-web-security','--disable-features=ntlm-auth','--use-fake-ui-for-media-stream','--use-fake-device-for-media-stream'] });
    browsers.push(b);
    const p = await b.newPage();
    await p.setViewport({ width: 1280, height: 720 });
    const ctx = b.defaultBrowserContext();
    try { await ctx.overridePermissions('http://localhost:3000', ['microphone']); } catch(_) {}
    await p.goto('http://localhost:3000', { waitUntil: 'domcontentloaded' });
    await p.waitForSelector('canvas', { timeout: 30000 });
    await sleep(5000);
    await p.evaluate(() => window.gameClickNewGame());
    await sleep(2000);
    await p.evaluate(() => window.gameSkipIntro());
    await sleep(1500);
    for (let i = 0; i < 14; i++) { await p.evaluate(() => window.gameAdvanceIntro()); await sleep(150); }
    await sleep(500);
    await p.evaluate(() => window.gameSelectHeroByIndex(0));
    await sleep(400);
    await p.evaluate(() => window.gameConfirmHero());
    await sleep(3500);
    await p.evaluate((n) => { window._godotMPName = n; }, name);
    await p.evaluate(() => { window._mpWantConnect = 'ws://localhost:4567'; });
    await sleep(4000);
    return { p, name };
  }
  const c1 = await setup('Dbg2C1');
  const c2 = await setup('Dbg2C2');
  await c1.p.evaluate(() => window.gameVoiceRequestMic());
  await c2.p.evaluate(() => window.gameVoiceRequestMic());
  await sleep(500);
  // Patch C2 ws.onmessage to log raw incoming
  await c2.p.evaluate(() => {
    window._dbgMpRaw = [];
    const orig = window._mpWsOnMessage;
    // we can't easily patch since it's set in eval. Instead, hook _mpIn via Proxy
    const origPush = Array.prototype.push;
    window._mpIn = new Proxy([], {
      set(target, prop, val) {
        if (prop === 'length' || typeof prop !== 'string') return Reflect.set(target, prop, val);
        if (val && typeof val === 'string' && val.indexOf('voice') >= 0) {
          window._dbgMpRaw.push(val.substring(0, 200));
        }
        return Reflect.set(target, prop, val);
      }
    });
  });
  // C1 calls
  await c1.p.evaluate(() => window.gameVoiceCallPeer('Dbg2C2'));
  await sleep(5000);
  const raw = await c2.p.evaluate(() => window._dbgMpRaw || []);
  console.log('[c2] voice msgs received via _mpIn:', raw.length);
  raw.forEach((m, i) => console.log('  [' + i + ']', m.substring(0, 150)));
  for (const b of browsers) await b.close();
})();
