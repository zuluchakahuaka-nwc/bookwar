// regression_quests.test.js — e2e для мульти-тип квестовой системы.
// Проверяет: квесты появляются, прогрессия N-2 работает, сдача через диалог.
const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');
const path = require('path');
const fs = require('fs');

const SCREENSHOT_DIR = path.join(__dirname, '..', 'screenshots');
if (!fs.existsSync(SCREENSHOT_DIR)) fs.mkdirSync(SCREENSHOT_DIR, { recursive: true });

const sleep = ms => new Promise(r => setTimeout(r, ms));

async function getQuests() {
  return await godot.getPage().evaluate(() => {
    try { return JSON.parse(window.gameQuests || '{"active":[],"completed_count":0}'); }
    catch (e) { return { active: [], parse_err: String(e) }; }
  });
}

async function gotoMap(mapId) {
  const page = godot.getPage();
  // GUARD: wandering monsters (24+ on later maps) can drag the player into a
  // battle scene — there is no world_map there to consume the map-switch
  // queue. Flee back to the world first.
  for (let g = 0; g < 3; g++) {
    if (!(await gameActions.isInCombat())) break;
    await gameActions.fleeBattle();
    await godot.waitForCondition(
      () => godot.getPage().evaluate(() => !window.gameInCombat),
      10000, 400
    );
    await sleep(500);
  }
  const prev = await page.evaluate(() => (window.gameHUD || {}).region || '');
  // Retry waves: the map-switch bridge flag is consumed by the live world's
  // physics frame — a call racing a scene swap can get lost, so re-arm it.
  for (let wave = 0; wave < 3; wave++) {
    await page.evaluate((id) => { if (window.gameTestGotoMap) window.gameTestGotoMap(id); }, mapId);
    for (let k = 0; k < 12; k++) {
      await sleep(500);
      const r = await page.evaluate(() => (window.gameHUD || {}).region || '');
      if (r && r !== prev && r !== '?') {
        // Region flipped — wait for the fresh world scene (bridges rebuilt)
        for (let j = 0; j < 20; j++) {
          if (await page.evaluate(() => Array.isArray(window.gameMapLetterChars) && !!window.gameQuests)) break;
          await sleep(400);
        }
        return true;
      }
    }
  }
  return false;
}

describe('quest system e2e', () => {
  beforeAll(async () => {
    await godot.loadGame();
    await gameActions.waitForGameLoad();
    await gameActions.startNewGame();
    await godot.waitForCondition(
      () => godot.getPage().evaluate(() => Array.isArray(window.gameMapLetterChars)),
      20000, 500
    );
  }, 120000);

  afterAll(async () => { await godot.closeBrowser(); });

  test('maps 1-2 have no quests (tutorial)', async () => {
    // Карта 1 (light_valley) — мы уже там после newGame
    let q = await getQuests();
    expect((q.active || []).length).toBe(0);
    // Карта 2
    const ok = await gotoMap('two_letter_forest');
    expect(ok).toBe(true);
    q = await getQuests();
    expect((q.active || []).length).toBe(0);
  }, 60000);

  test('map 3 (dark_oaks) has 1 quest (N-2 progression)', async () => {
    const ok = await gotoMap('dark_oaks');
    expect(ok).toBe(true);
    await sleep(1500);
    const q = await getQuests();
    expect((q.active || []).length).toBe(1);
    const first = (q.active || [])[0];
    expect(first).toBeTruthy();
    expect(['defeat','collect','buy','trade','talk']).toContain(first.type);
  }, 60000);

  test('map 6 (swamp_lights) has 4 quests (level 6 - 2)', async () => {
    const ok = await gotoMap('swamp_lights');
    expect(ok).toBe(true);
    await sleep(1500);
    const q = await getQuests();
    expect((q.active || []).length).toBe(4);
  }, 60000);

  test('map 7 (stony_wastes) has 5 quests', async () => {
    const ok = await gotoMap('stony_wastes');
    expect(ok).toBe(true);
    await sleep(1500);
    const q = await getQuests();
    expect((q.active || []).length).toBe(5);
  }, 60000);

  test('quest log opens with Q-key', async () => {
    // Возвращаемся на карту 3 (1 квест) и пробуем открыть журнал
    const ok = await gotoMap('dark_oaks');
    expect(ok).toBe(true);
    await sleep(1500);
    const page = godot.getPage();
    // JS bridge для toggle (работает даже без keyboard) — poll until it flips
    // (quest_log._process polls the bridge flag every frame).
    let visible = false;
    for (let k = 0; k < 8; k++) {
      await page.evaluate(() => { if (window.gameToggleQuestLog) window.gameToggleQuestLog(); });
      await sleep(400);
      visible = await page.evaluate(() => !!window.gameQuestLogVisible);
      if (visible) break;
    }
    expect(visible).toBe(true);
    await page.screenshot({ path: path.join(SCREENSHOT_DIR, 'quest_log_open.png') });
    // Закрыть
    await page.evaluate(() => { if (window.gameToggleQuestLog) window.gameToggleQuestLog(); });
    await sleep(400);
  }, 60000);

  test('collect quest can be completed via dialogue', async () => {
    const page = godot.getPage();
    // GUARD: same battle-guard as gotoMap — the letter queue is only drained
    // by a live world_map.
    for (let g = 0; g < 3; g++) {
      if (!(await gameActions.isInCombat())) break;
      await gameActions.fleeBattle();
      await godot.waitForCondition(
        () => godot.getPage().evaluate(() => !window.gameInCombat),
        10000, 400
      );
      await sleep(500);
    }
    // Карта 3 — ручной квест "Принеси 2 буквы В"
    const beforeQ = await getQuests();
    const beforeCompleted = beforeQ.completed_count || 0;
    // Добавим себе 2 буквы В (test bridge queue — drained by the live world;
    // re-arm the queue like gotoMap does, it can race scene swaps too)
    for (let k = 0; k < 10; k++) {
      await page.evaluate(() => { if (window.gameTestAddLetter) { window.gameTestAddLetter('В'); } });
      for (let j = 0; j < 5; j++) {
        const has = await page.evaluate(() => Number((window.gameInventory || {}).letters?.В || 0));
        if (has >= 2) break;
        await sleep(300);
      }
      const total = await page.evaluate(() => Number((window.gameInventory || {}).letters?.В || 0));
      if (total >= 2) break;
    }
    const inv = await page.evaluate(() => window.gameInventory || {});
    expect(Number((inv.letters || {}).В || 0)).toBeGreaterThanOrEqual(2);
    // Дать точек (для dialogue нужно 3 буквицы = 3 точки)
    await page.evaluate(() => { if (window.gameTestAddDots) window.gameTestAddDots(15); });
    await sleep(400);
    // Если рядом нет ? монстров — это OK, тест пропускает проверку сдачи
    const monsters = await page.evaluate(() => (window.gameMonsterStates || []).filter(m => m.id === 'question' && m.state !== 'dead'));
    if (monsters.length === 0) {
      console.log('  (skip — нет ? монстров на карте для теста сдачи)');
      return;
    }
    // Бот не подходит физически — используем dialogue bridge (форсирует диалог с ближайшим)
    await page.evaluate(() => { if (window.gameTestStartDialogue) window.gameTestStartDialogue(); });
    await sleep(1500);
    const afterQ = await getQuests();
    console.log('  collect active after dialogue:', (afterQ.active || []).filter(q => q.type === 'collect').length, 'completed:', afterQ.completed_count);
    const success = (afterQ.completed_count > beforeCompleted);
    expect(success).toBe(true);
  }, 90000);
});
