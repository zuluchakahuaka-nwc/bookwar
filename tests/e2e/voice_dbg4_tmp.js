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
  const c1 = await setup('FinC1');
  const c2 = await setup('FinC2');
  await c1.p.evaluate(() => window.gameVoiceRequestMic());
  await c2.p.evaluate(() => window.gameVoiceRequestMic());
  await sleep(500);
  // Direct ws send from C1 bypassing all bridges — to verify C2 receives ANY msg
  const c1SocketInfo = await c1.p.evaluate(() => ({
    readyState: window._mpSocket ? window._mpSocket.readyState : 'no_socket',
    hasOnMessage: window._mpSocket ? typeof window._mpSocket.onmessage : 'no_socket',
    url: window._mpSocket ? window._mpSocket.url : null
  }));
  const c2SocketInfo = await c2.p.evaluate(() => ({
    readyState: window._mpSocket ? window._mpSocket.readyState : 'no_socket',
    hasOnMessage: window._mpSocket ? typeof window._mpSocket.onmessage : 'no_socket',
    listenersCount: window._mpSocket ? (typeof window._mpSocket.listeners !== 'function' ? 'n/a' : window._mpSocket.listeners('message').length) : 'no_socket'
  }));
  console.log('[c1] socket:', JSON.stringify(c1SocketInfo));
  console.log('[c2] socket:', JSON.stringify(c2SocketInfo));
  // Send direct chat from C1 to verify C2 receives
  await c1.p.evaluate(() => {
    if (window._mpSocket && window._mpSocket.readyState === 1) {
      window._mpSocket.send(JSON.stringify({ t: 'chat', text: 'voice_test_probe' }));
    }
  });
  await sleep(2000);
  const c2chat = await c2.p.evaluate(() => window.gameMPChatReceived || 'no_chat_signal');
  console.log('[c2] chat received after probe:', c2chat);
  for (const b of browsers) await b.close();
})();
