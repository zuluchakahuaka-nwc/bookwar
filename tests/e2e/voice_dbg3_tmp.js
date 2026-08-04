const puppeteer = require('puppeteer');
const sleep = ms => new Promise(r => setTimeout(r, ms));
(async () => {
  const browsers = [];
  async function setup(name) {
    const b = await puppeteer.launch({ headless: true, args: ['--no-sandbox','--disable-web-security','--disable-features=ntlm-auth','--use-fake-ui-for-media-stream','--use-fake-device-for-media-stream'] });
    browsers.push(b);
    const p = await b.newPage();
    p.on('console', m => console.log('[JS ' + name + ']', m.text()));
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
  const c1 = await setup('Dbg3C1');
  const c2 = await setup('Dbg3C2');
  await c1.p.evaluate(() => window.gameVoiceRequestMic());
  await c2.p.evaluate(() => window.gameVoiceRequestMic());
  await sleep(500);
  // C1 calls
  await c1.p.evaluate(() => window.gameVoiceCallPeer('Dbg3C2'));
  // Poll C2 _mpIn state for 5s
  for (let i = 0; i < 10; i++) {
    await sleep(500);
    const s = await c2.p.evaluate(() => ({
      mpInLen: window._mpIn ? window._mpIn.length : -1,
      mpState: window._mpState,
      mpWsExists: !!window._mpWs,
      peersCount: window.gameVoice ? Object.keys(window.gameVoice.peers).length : -1
    }));
    console.log('t=' + (i*0.5) + 's', JSON.stringify(s));
    if (s.peersCount > 0) break;
  }
  for (const b of browsers) await b.close();
})();
