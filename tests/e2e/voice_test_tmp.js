const puppeteer = require('puppeteer');
const sleep = ms => new Promise(r => setTimeout(r, ms));
(async () => {
  const b = await puppeteer.launch({ headless: true, args: ['--no-sandbox','--disable-web-security','--disable-features=ntlm-auth'] });
  const p = await b.newPage();
  await p.setViewport({ width: 1280, height: 720 });
  await p.goto('http://localhost:3000', { waitUntil: 'domcontentloaded', timeout: 60000 });
  await p.waitForSelector('canvas', { timeout: 30000 });
  await sleep(5000);
  const c = await p.$('canvas'); const bx = await c.boundingBox();
  await p.mouse.click(bx.x + bx.width/2, bx.y + bx.height/2);
  await sleep(500);
  await p.evaluate(() => window.gameClickNewGame && window.gameClickNewGame());
  await sleep(2000);
  await p.evaluate(() => window.gameSkipIntro && window.gameSkipIntro());
  await sleep(1500);
  for (let i = 0; i < 14; i++) { await p.evaluate(() => window.gameAdvanceIntro && window.gameAdvanceIntro()); await sleep(150); }
  await sleep(500);
  await p.evaluate(() => { if (window.gameSelectHeroByIndex) window.gameSelectHeroByIndex(0); });
  await sleep(400);
  await p.evaluate(() => { if (window.gameConfirmHero) window.gameConfirmHero(); });
  await sleep(3000);
  // Check Voice JS bridge is installed
  const voiceBridge = await p.evaluate(() => ({
    hasWindow: typeof window.gameVoice !== 'undefined',
    requestMicExists: typeof window.gameVoiceRequestMic === 'function',
    setPTTExists: typeof window.gameVoiceSetPTT === 'function',
    stopMicExists: typeof window.gameVoiceStopMic === 'function',
    supported: typeof window.gameVoiceIsSupported === 'function' ? window.gameVoiceIsSupported() : null,
    initialState: window.gameVoice
  }));
  console.log('Voice bridge:', JSON.stringify({
    hasWindow: voiceBridge.hasWindow,
    requestMicExists: voiceBridge.requestMicExists,
    setPTTExists: voiceBridge.setPTTExists,
    stopMicExists: voiceBridge.stopMicExists,
    supported: voiceBridge.supported
  }));
  // Try setting PTT directly
  if (voiceBridge.setPTTExists) {
    await p.evaluate(() => window.gameVoiceSetPTT(true));
    await sleep(800);
    const pttState = await p.evaluate(() => ({
      pttActive: window.gameVoicePTT,
      micPerm: window.gameVoiceMicPerm,
      enabled: window.gameVoiceEnabled
    }));
    console.log('After setPTT(true):', JSON.stringify(pttState));
  }
  // Now click the Voice button in HUD - vw*0.86 vh*0.38
  // center = 0.86*1280+82.5=1182, 0.38*720+55=328.6
  await p.mouse.click(bx.x + 1182, bx.y + 329);
  await sleep(800);
  const afterClick = await p.evaluate(() => ({
    dispatch: window.gameDispatch,
    pttActive: window.gameVoicePTT
  }));
  console.log('After Voice btn click:', JSON.stringify(afterClick));
  const ok = voiceBridge.hasWindow && voiceBridge.setPTTExists && afterClick.dispatch === 'voice';
  console.log('Voice chat result:', ok ? 'PASS' : 'FAIL');
  await b.close();
  process.exit(ok ? 0 : 1);
})();
