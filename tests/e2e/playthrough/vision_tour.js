// vision_tour.js — screenshot every menu, manual, and all 33 map levels
// (with a short run-around on each), plus test battles in ru & hy.
// Outputs the screenshot list for GLM-4.6V (Vision) batch analysis.
const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

const MAPS = [
  'light_valley', 'two_letter_forest', 'dark_oaks', 'mossy_lowlands',
  'rotten_swamps', 'swamp_lights', 'stony_wastes', 'ash_plains',
  'crystal_grottos', 'dark_cathedral', 'forgotten_ruins', 'misty_grove',
  'grey_forest', 'wind_pass', 'ice_pincers', 'mountain_caves', 'deep_mines',
  'catacombs_silence', 'vaults_oblivion', 'underground_river',
  'flooded_temple', 'ruined_library', 'broken_bridge', 'abandoned_village',
  'old_citadel', 'shadow_fortress', 'black_tower', 'throne_void',
  'hall_mirrors', 'labyrinth_fear', 'chambers_ban', 'throne_keeper',
  'well_of_letters'
];

const shots = [];
const sleep = ms => new Promise(r => setTimeout(r, ms));

// Robust new-game entry with per-step logging (helper startNewGame proved flaky here).
async function enterWorld() {
  await godot.getPage().evaluate(() => { if (window.gameClickNewGame) window.gameClickNewGame(); });
  await godot.waitMs(2500);
  // Skip the legend intro if it plays.
  for (let t = 0; t < 5; t++) {
    const skipped = await godot.getPage().evaluate(() => {
      if (typeof window.gameSkipIntro === 'function') { window.gameSkipIntro(); return true; }
      return false;
    });
    if (skipped) break;
    await godot.waitMs(1500);
  }
  // Wait for char select or an already-loaded world.
  await godot.waitForCondition(
    () => godot.getPage().evaluate(() => !!(window.gameCharSelectLoaded || Array.isArray(window.gameMapLetterChars))),
    20000, 500
  );
  await godot.getPage().evaluate(() => { if (window.gameConfirmHero) window.gameConfirmHero(); });
  // Wait for the world map (letters bridge present).
  await godot.waitForCondition(
    () => godot.getPage().evaluate(() => Array.isArray(window.gameMapLetterChars)),
    25000, 500
  );
}

// Resilient bridge-click: try N times; return false instead of crashing the tour.
async function clickAndWait(bridgeCall, flagFn, tries = 3, waitMsPerTry = 4000) {
  for (let t = 0; t < tries; t++) {
    await godot.getPage().evaluate(bridgeCall);
    let ok = false;
    try {
      await godot.waitForCondition(flagFn, waitMsPerTry, 300);
      ok = true;
    } catch (e) { ok = false; }
    if (ok) return true;
  }
  return false;
}

async function runAround() {
  // "побегать по карте" — short jog in 4 directions like a player scouting.
  await gameActions.movePlayer('right', 250);
  await gameActions.movePlayer('up', 250);
  await gameActions.movePlayer('left', 250);
  await gameActions.movePlayer('down', 250);
}

(async () => {
  // ---- Part 1: menus & manual (ru) ----
  await godot.loadGame();
  await gameActions.waitForGameLoad();
  await godot.waitMs(1500);
  shots.push({ name: 'menu_ru', path: await godot.takeCanvasScreenshot('tour_menu_ru') });

  // Manual from the menu
  console.log('tour: opening manual...');
  const manualOk = await clickAndWait(
    () => { if (window.gameClickManual) window.gameClickManual(); },
    () => godot.getPage().evaluate(() => !!window.gameManualVisible)
  );
  console.log('tour: manual open', manualOk ? 'OK' : 'FAIL');
  shots.push({ name: `manual_ru_p1_${manualOk ? 'ok' : 'fail'}`, path: await godot.takeCanvasScreenshot('tour_manual_ru_p1') });
  // Page through the manual a couple of times (E/advance or arrows)
  for (const key of ['ArrowRight', 'ArrowRight']) {
    await godot.pressKey(key, 80);
    await godot.waitMs(400);
  }
  shots.push({ name: 'manual_ru_p3', path: await godot.takeCanvasScreenshot('tour_manual_ru_p3') });
  await godot.getPage().evaluate(() => { if (window.gameClickManual) window.gameClickManual(); });
  await godot.waitMs(600);

  // ---- Part 2: enter world, tour all 33 maps ----
  // Make sure the manual overlay is closed before leaving the menu.
  await clickAndWait(
    () => { if (window.gameClickManual) window.gameClickManual(); },
    () => godot.getPage().evaluate(() => !window.gameManualVisible),
    3, 2500
  );
  console.log('tour: manual closed, starting new game...');
  await enterWorld();
  const worldOk = await godot.getPage().evaluate(() => Array.isArray(window.gameMapLetterChars));
  console.log('tour: world entered', worldOk ? 'OK' : 'FAIL');
  shots.push({ name: `world_ru_entry_${worldOk ? 'ok' : 'fail'}`, path: await godot.takeCanvasScreenshot('tour_world_ru_entry') });
  const fails = [];
  for (let i = 0; i < MAPS.length; i++) {
    const m = MAPS[i];
    console.log(`tour: map ${i + 1}/33 ${m}...`);
    await godot.getPage().evaluate((mid) => { if (window.gameTestGotoMap) window.gameTestGotoMap(mid); }, m);
    // Wait for the map to load: region bridge updates + letters snapshot
    let ok = false;
    try {
      await godot.waitForCondition(
        () => godot.getPage().evaluate(() => Array.isArray(window.gameMapLetterChars)),
        12000, 400
      );
      ok = true;
    } catch (e) { ok = false; }
    if (!ok) { fails.push(m); continue; }
    await godot.waitMs(1200);
    await runAround();
    await godot.waitMs(400);
    const label = String(i + 1).padStart(2, '0');
    shots.push({ name: `map_${label}_${m}`, path: await godot.takeCanvasScreenshot(`tour_map_${label}_${m}`) });
  }
  console.log('MAP_LOAD_FAILS:', JSON.stringify(fails));

  // ---- Part 3: test battle (ru) ----
  console.log('tour: test battle ru...');
  const battleRuOk = await clickAndWait(
    () => { if (window.gameStartTestCombat) window.gameStartTestCombat('TourFoe', 40, ['Б', 'А', 'М']); },
    () => godot.getPage().evaluate(() => !!window.gameInCombat),
    2, 6000
  );
  console.log('tour: battle ru', battleRuOk ? 'OK' : 'FAIL');
  shots.push({ name: `battle_ru_${battleRuOk ? 'ok' : 'fail'}`, path: await godot.takeCanvasScreenshot('tour_battle_ru') });
  await godot.closeBrowser();

  // ---- Part 4: hy locale (menu + valley + battle) ----
  await godot.loadGame();
  await gameActions.waitForGameLoad();
  await godot.waitMs(1000);
  await godot.getPage().evaluate(() => { if (window.gameSetLocale) window.gameSetLocale('hy'); });
  await godot.waitMs(800);
  shots.push({ name: 'menu_hy', path: await godot.takeCanvasScreenshot('tour_menu_hy') });
  console.log('tour: hy manual...');
  const manualHyOk = await clickAndWait(
    () => { if (window.gameClickManual) window.gameClickManual(); },
    () => godot.getPage().evaluate(() => !!window.gameManualVisible)
  );
  console.log('tour: hy manual', manualHyOk ? 'OK' : 'FAIL');
  shots.push({ name: `manual_hy_p1_${manualHyOk ? 'ok' : 'fail'}`, path: await godot.takeCanvasScreenshot('tour_manual_hy_p1') });
  await godot.getPage().evaluate(() => { if (window.gameClickManual) window.gameClickManual(); });
  await clickAndWait(
    () => { if (window.gameClickManual) window.gameClickManual(); },
    () => godot.getPage().evaluate(() => !window.gameManualVisible),
    3, 2500
  );
  console.log('tour: hy manual closed, starting new game...');
  await enterWorld();
  await godot.waitMs(1500);
  await runAround();
  shots.push({ name: 'map_hy_valley', path: await godot.takeCanvasScreenshot('tour_map_hy_valley') });
  console.log('tour: test battle hy...');
  const battleHyOk = await clickAndWait(
    () => { if (window.gameStartTestCombat) window.gameStartTestCombat('Մենամարտ', 40, ['Հ', 'Ր', 'Ա']); },
    () => godot.getPage().evaluate(() => !!window.gameInCombat),
    2, 6000
  );
  console.log('tour: battle hy', battleHyOk ? 'OK' : 'FAIL');
  shots.push({ name: `battle_hy_${battleHyOk ? 'ok' : 'fail'}`, path: await godot.takeCanvasScreenshot('tour_battle_hy') });
  await godot.closeBrowser();

  console.log('=== TOUR SHOTS ===');
  for (const s of shots) console.log(`${s.name}\t${s.path}`);
  console.log(`TOTAL=${shots.length} FAILMAPS=${fails.length}`);
})().catch(e => { console.error('TOUR_FAILED:', e.message); process.exit(1); });
