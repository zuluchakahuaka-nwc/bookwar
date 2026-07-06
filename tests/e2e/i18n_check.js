// Localization + prologue title-card verification.
// Loads the game, screenshots the menu in several locales, then enters the
// prologue and screenshots the title splash. Output paths are printed so the
// agent can feed them to Vision-MCP.
const godot = require('./helpers/godot_page');

const sleep = (ms) => new Promise(r => setTimeout(r, ms));

(async () => {
  const shots = [];
  try {
    await godot.initBrowser();
    const page = godot.getPage();
    await godot.clearConsoleLog();
    // Pretend intro already seen so the menu stays (no auto-legend on first launch).
    await page.evaluateOnNewDocument(() => {
      try { localStorage.setItem('bookwar_intro_seen', '1'); } catch(e){}
    });
    // Use domcontentloaded (networkidle0 never settles due to <audio> streaming).
    await page.goto(godot.GODOT_URL, { waitUntil: 'domcontentloaded', timeout: 30000 });
    // Wait for the engine to report it loaded.
    await godot.waitForCondition(async () => await page.evaluate(() => !!window.gameLoaded), 40000, 400);
    console.log('game loaded');
    const canvas = await page.$('canvas');
    if (canvas) {
      const box = await canvas.boundingBox();
      if (box) await page.mouse.click(box.x + 5, box.y + 5);
    }
    await sleep(1200);
    const st0 = await page.evaluate(() => ({
      locale: window.gameLocale,
      menuVisible: window.gameMenuVisible,
      introActive: window.gameIntroActive,
      fontApplied: window.gameFontApplied,
      hasSetLocale: typeof window.gameSetLocale === 'function'
    }));
    console.log('state after load:', JSON.stringify(st0));
    await godot.waitForCondition(async () => await page.evaluate(() => window.gameMenuVisible === true), 15000, 400);
    await sleep(600);

    const initialLocale = await page.evaluate(() => window.gameLocale);
    console.log('initial locale:', initialLocale);
    // Force a stable locale regardless of OS detection: set to ru for the base shot.
    await page.evaluate(() => window.gameSetLocale('ru'));
    await sleep(600);
    shots.push({ name: 'menu_ru', path: await godot.takeCanvasScreenshot('loc_menu_ru') });

    for (const loc of ['en', 'es', 'de', 'fr', 'pt', 'zh', 'ar']) {
      await page.evaluate((l) => window.gameSetLocale(l), loc);
      await sleep(600);
      const got = await page.evaluate(() => window.gameLocale);
      const cov = await page.evaluate(() => window.gameFontCoverage);
      if (got !== loc) console.log(`WARN: locale did not switch to ${loc} (got ${got})`);
      console.log(`  ${loc}: coverage=${JSON.stringify(cov)}`);
      shots.push({ name: `menu_${loc}`, path: await godot.takeCanvasScreenshot(`loc_menu_${loc}`) });
    }

    // --- Prologue title card ---
    // Back to ru, then click New Game → legend intro with title splash.
    await page.evaluate(() => window.gameSetLocale('ru'));
    await sleep(500);
    // Mark intro NOT seen so it plays.
    await page.evaluate(() => { try { localStorage.removeItem('bookwar_intro_seen'); } catch(e){} });
    await page.evaluate(() => { if (window.gameClickNewGame) window.gameClickNewGame(); });
    await sleep(1500); // let intro scene load + title card fade in
    const introActive = await page.evaluate(() => window.gameIntroActive);
    console.log('intro active:', introActive);
    // Title card shot (should show BOOKWAR + tagline).
    shots.push({ name: 'prologue_title_ru', path: await godot.takeCanvasScreenshot('prologue_title_ru') });
    // Switch the title card to a couple locales (intro reads I18n at build; but
    // the title card text was set once. Switching locale now won't re-render the
    // already-built card. So we just capture the ru title card.)
    // Dismiss title card + advance a couple panels.
    await page.evaluate(() => { if (window.gameAdvanceIntro) window.gameAdvanceIntro(); });
    await sleep(800);
    shots.push({ name: 'prologue_panel1_ru', path: await godot.takeCanvasScreenshot('prologue_panel1_ru') });
    await page.evaluate(() => { if (window.gameAdvanceIntro) window.gameAdvanceIntro(); });
    await sleep(700);
    shots.push({ name: 'prologue_panel2_ru', path: await godot.takeCanvasScreenshot('prologue_panel2_ru') });

    // Switch the prologue panels to zh and ar to verify font rendering.
    await page.evaluate(() => window.gameSetLocale('zh'));
    await sleep(500);
    await page.evaluate(() => { if (window.gameAdvanceIntro) window.gameAdvanceIntro(); });
    await sleep(700);
    shots.push({ name: 'prologue_panel_zh', path: await godot.takeCanvasScreenshot('prologue_panel_zh') });

    await page.evaluate(() => window.gameSetLocale('ar'));
    await sleep(500);
    await page.evaluate(() => { if (window.gameAdvanceIntro) window.gameAdvanceIntro(); });
    await sleep(700);
    shots.push({ name: 'prologue_panel_ar', path: await godot.takeCanvasScreenshot('prologue_panel_ar') });

    const consoleLog = await godot.getConsoleLog();
    const hasErrors = /ERROR|PAGE_ERROR/i.test(consoleLog);
    console.log('console has errors:', hasErrors);
    if (hasErrors) console.log(consoleLog.slice(-800));

    console.log('=== SCREENSHOTS ===');
    for (const s of shots) console.log(`${s.name}\t${s.path}`);
    console.log('RESULT=' + (hasErrors ? 'WARN' : 'OK'));
  } catch (e) {
    console.log('TEST_FAILED:', e.message);
    try { await godot.debugCapture('i18n_failure'); } catch (_) {}
  } finally {
    await godot.closeBrowser();
  }
})();
