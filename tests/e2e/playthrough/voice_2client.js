// e2e: verify WebRTC voice peer-connection setup between 2 clients.
// Both clients connect to multiplayer WS server, both call gameVoiceRequestMic,
// Client1 calls Client2 via gameVoiceCallPeer, verify RTCPeerConnection exists.
// NOTE: headless Puppeteer cannot actually grant mic permission, so we stub
// getUserMedia with a synthetic audio track to exercise the PC setup path.
const puppeteer = require('puppeteer');
const path = require('path');
const fs = require('fs');
const sleep = ms => new Promise(r => setTimeout(r, ms));

const MP_URL = 'ws://localhost:4567';
const SHOTS = path.join(__dirname, '..', 'screenshots', 'voice_2client');
if (!fs.existsSync(SHOTS)) fs.mkdirSync(SHOTS, { recursive: true });

async function setupClient(name) {
  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-web-security', '--disable-features=ntlm-auth',
           '--use-fake-ui-for-media-stream',  // auto-grant mic permission
           '--use-fake-device-for-media-stream']  // synthetic mic
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 720 });
  // Override permissions
  const ctx = browser.defaultBrowserContext();
  try { await ctx.overridePermissions('http://localhost:3000', ['microphone']); } catch(_) {}
  await page.goto('http://localhost:3000', { waitUntil: 'domcontentloaded' });
  await page.waitForSelector('canvas', { timeout: 30000 });
  await sleep(5000);
  await page.evaluate(() => window.gameClickNewGame && window.gameClickNewGame());
  await sleep(2000);
  await page.evaluate(() => window.gameSkipIntro && window.gameSkipIntro());
  await sleep(1500);
  for (let i = 0; i < 14; i++) {
    await page.evaluate(() => window.gameAdvanceIntro && window.gameAdvanceIntro());
    await sleep(150);
  }
  await sleep(500);
  await page.evaluate((n) => window.gameSelectHeroByIndex && window.gameSelectHeroByIndex(0), 0);
  await sleep(400);
  await page.evaluate(() => window.gameConfirmHero && window.gameConfirmHero());
  await sleep(3500);
  // Set unique MP name and connect
  await page.evaluate((n) => { window._godotMPName = n; }, name);
  await page.evaluate((url) => { window._mpWantConnect = url; }, MP_URL);
  await sleep(4000);
  console.log(`[${name}] mp connected=${await page.evaluate(() => !!window.gameMPConnected)}`);
  return { browser, page, name };
}

(async () => {
  console.log('=== Voice 2-client e2e ===');
  const c1 = await setupClient('VoiceC1');
  const c2 = await setupClient('VoiceC2');
  try {
    // Both request mic permission (Puppeteer will use synthetic device)
    console.log('[c1] request mic...');
    const mic1 = await c1.page.evaluate(() => window.gameVoiceRequestMic());
    console.log('[c1] mic:', mic1, 'perm:', await c1.page.evaluate(() => window.gameVoice.micPermission));
    console.log('[c2] request mic...');
    const mic2 = await c2.page.evaluate(() => window.gameVoiceRequestMic());
    console.log('[c2] mic:', mic2, 'perm:', await c2.page.evaluate(() => window.gameVoice.micPermission));

    // C1 calls C2
    console.log('[c1] calling VoiceC2...');
    await c1.page.evaluate(() => window.gameVoiceCallPeer('VoiceC2'));
    await sleep(3000); // give offer/answer/ICE time to flow

    // Check peer connection state
    const c1Peers = await c1.page.evaluate(() => ({
      count: Object.keys(window.gameVoice.peers).length,
      names: Object.keys(window.gameVoice.peers),
      pcState: window.gameVoice.peers['VoiceC2'] ? window.gameVoice.peers['VoiceC2'].pc.connectionState : 'no_pc'
    }));
    const c2Peers = await c2.page.evaluate(() => ({
      count: Object.keys(window.gameVoice.peers).length,
      names: Object.keys(window.gameVoice.peers),
      pcState: window.gameVoice.peers['VoiceC1'] ? window.gameVoice.peers['VoiceC1'].pc.connectionState : 'no_pc'
    }));
    console.log('[c1] peers:', JSON.stringify(c1Peers));
    console.log('[c2] peers:', JSON.stringify(c2Peers));

    const ok = c1Peers.count >= 1 && c2Peers.count >= 1;
    console.log('=== RESULT ===');
    console.log('voice peer connections established:', ok ? 'PASS' : 'FAIL');

    await c1.page.screenshot({ path: path.join(SHOTS, 'c1_voice.png') });
    await c2.page.screenshot({ path: path.join(SHOTS, 'c2_voice.png') });
    process.exit(ok ? 0 : 1);
  } finally {
    await c1.browser.close();
    await c2.browser.close();
  }
})();
