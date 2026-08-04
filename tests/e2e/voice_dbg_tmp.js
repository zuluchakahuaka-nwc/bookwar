const puppeteer = require('puppeteer');
const sleep = ms => new Promise(r => setTimeout(r, ms));
(async () => {
  const browsers = [];
  async function setup(name) {
    const b = await puppeteer.launch({ headless: true, args: ['--no-sandbox','--disable-web-security','--disable-features=ntlm-auth','--use-fake-ui-for-media-stream','--use-fake-device-for-media-stream'] });
    browsers.push(b);
    const p = await b.newPage();
    const errs = [];
    p.on('console', m => errs.push(m.text()));
    p.on('pageerror', e => errs.push('PAGEERR: ' + e.message));
    await p.setViewport({ width: 1280, height: 720 });
    const ctx = b.defaultBrowserContext();
    try { await ctx.overridePermissions('http://localhost:3000', ['microphone']); } catch(_) {}
    await p.goto('http://localhost:3000', { waitUntil: 'domcontentloaded' });
    await p.waitForSelector('canvas', { timeout: 30000 });
    await sleep(5000);
    await p.evaluate(() => window.gameClickNewGame && window.gameClickNewGame());
    await sleep(2000);
    await p.evaluate(() => window.gameSkipIntro && window.gameSkipIntro());
    await sleep(1500);
    for (let i = 0; i < 14; i++) { await p.evaluate(() => window.gameAdvanceIntro && window.gameAdvanceIntro()); await sleep(150); }
    await sleep(500);
    await p.evaluate(() => window.gameSelectHeroByIndex(0));
    await sleep(400);
    await p.evaluate(() => window.gameConfirmHero());
    await sleep(3500);
    await p.evaluate((n) => { window._godotMPName = n; }, name);
    await p.evaluate((url) => { window._mpWantConnect = url; }, 'ws://localhost:4567');
    await sleep(4000);
    return { p, errs, name };
  }
  const c1 = await setup('DbgC1');
  const c2 = await setup('DbgC2');
  await c1.p.evaluate(() => window.gameVoiceRequestMic());
  await c2.p.evaluate(() => window.gameVoiceRequestMic());
  await sleep(500);
  // Check C2 has the handler installed
  const c2bridge = await c2.p.evaluate(() => ({
    hasHandleOffer: typeof window.gameVoiceHandleOffer === 'function',
    hasHandleAnswer: typeof window.gameVoiceHandleAnswer === 'function',
    hasHandleIce: typeof window.gameVoiceHandleIce === 'function',
    voiceObjExists: typeof window.gameVoice !== 'undefined'
  }));
  console.log('[c2] bridge:', JSON.stringify(c2bridge));
  // C1 calls C2
  await c1.p.evaluate(() => window.gameVoiceCallPeer('DbgC2'));
  await sleep(4000);
  // Check what C2 received via _mpIn drain
  const c2state = await c2.p.evaluate(() => ({
    peersCount: Object.keys(window.gameVoice.peers).length,
    error: window.gameVoice.error,
    voiceObjPeers: window.gameVoice.peers
  }));
  console.log('[c2] state:', JSON.stringify(c2state).substring(0, 500));
  console.log('[c2] page errors:', c2.errs.filter(e => e.includes('voice') || e.includes('PAGEERR')).slice(-5));
  for (const b of browsers) await b.close();
})();
