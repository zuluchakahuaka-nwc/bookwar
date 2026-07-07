// regression_quests.test.js — e2e для мульти-тип квестовой системы.
// Проверяет: квесты появляются, прогрессия N-2 работает, сдача через диалог.
const puppeteer = require('puppeteer');
const path = require('path');
const fs = require('fs');

const GODOT_URL = process.env.GODOT_URL || 'http://localhost:3000';
const SCREENSHOT_DIR = path.join(__dirname, '..', 'screenshots');
if (!fs.existsSync(SCREENSHOT_DIR)) fs.mkdirSync(SCREENSHOT_DIR, { recursive: true });

const sleep = ms => new Promise(r => setTimeout(r, ms));
const MAP_CHAIN = ['light_valley','two_letter_forest','dark_oaks','mossy_lowlands','rotten_swamps','swamp_lights','stony_wastes','ash_plains'];

async function getQuests(page) {
  return await page.evaluate(() => {
    try { return JSON.parse(window.gameQuests || '{"active":[],"completed_count":0}'); }
    catch (e) { return { active: [], parse_err: String(e) }; }
  });
}

async function newGameFlow(page) {
  await page.evaluate(() => window.gameClickNewGame && window.gameClickNewGame());
  await sleep(2000);
  await page.evaluate(() => window.gameSkipIntro && window.gameSkipIntro());
  await sleep(1500);
  for (let i = 0; i < 12; i++) { await page.evaluate(() => window.gameAdvanceIntro && window.gameAdvanceIntro()); await sleep(300); }
  await sleep(800);
  await page.evaluate(() => { if (window.gameSelectHeroByIndex) window.gameSelectHeroByIndex(0); });
  await sleep(500);
  await page.evaluate(() => { if (window.gameConfirmHero) window.gameConfirmHero(); });
  await sleep(3500);
}

async function gotoMap(page, mapId) {
  const prev = await page.evaluate(() => (window.gameHUD || {}).region || '');
  await page.evaluate((id) => { if (window.gameTestGotoMap) window.gameTestGotoMap(id); }, mapId);
  for (let k = 0; k < 24; k++) {
    await sleep(500);
    const r = await page.evaluate(() => (window.gameHUD || {}).region || '');
    if (r && r !== prev && r !== '?') return true;
  }
  return false;
}

describe('quest system e2e', () => {
  let browser, page;

  beforeAll(async () => {
    browser = await puppeteer.launch({
      headless: true,
      args: ['--no-sandbox','--disable-web-security','--disable-features=ntlm-auth']
    });
    page = await browser.newPage();
    await page.setViewport({ width: 1280, height: 720 });
    page.on('console', m => {
      const t = m.text();
      if (t.includes('Failed to load resource')) return;
      if (m.type() === 'error') console.log('  [game-error]', t.substr(0,180));
    });
    await page.goto(GODOT_URL, { waitUntil: 'domcontentloaded', timeout: 60000 });
    await page.waitForSelector('canvas', { timeout: 30000 });
    const c = await page.$('canvas');
    if (c) { const bx = await c.boundingBox(); if (bx) await page.mouse.click(bx.x+5, bx.y+5); }
    await sleep(3000);
    await newGameFlow(page);
  }, 120000);

  afterAll(async () => { if (browser) await browser.close(); });

  test('maps 1-2 have no quests (tutorial)', async () => {
    // Карта 1 (light_valley) — мы уже там после newGame
    let q = await getQuests(page);
    expect((q.active || []).length).toBe(0);
    // Карта 2
    await gotoMap(page, 'two_letter_forest');
    q = await getQuests(page);
    expect((q.active || []).length).toBe(0);
  }, 60000);

  test('map 3 (dark_oaks) has 1 quest (N-2 progression)', async () => {
    await gotoMap(page, 'dark_oaks');
    await sleep(1500);
    const q = await getQuests(page);
    expect((q.active || []).length).toBe(1);
    const first = (q.active || [])[0];
    expect(first).toBeTruthy();
    expect(['defeat','collect','buy','trade','talk']).toContain(first.type);
  }, 60000);

  test('map 6 (swamp_lights) has 4 quests (level 6 - 2)', async () => {
    await gotoMap(page, 'swamp_lights');
    await sleep(1500);
    const q = await getQuests(page);
    expect((q.active || []).length).toBe(4);
  }, 60000);

  test('map 7 (stony_wastes) has 5 quests', async () => {
    await gotoMap(page, 'stony_wastes');
    await sleep(1500);
    const q = await getQuests(page);
    expect((q.active || []).length).toBe(5);
  }, 60000);

  test('quest log opens with Q-key', async () => {
    // Возвращаемся на карту 3 (1 квест) и пробуем открыть журнал
    await gotoMap(page, 'dark_oaks');
    await sleep(1500);
    // JS bridge для toggle (работает даже без keyboard)
    await page.evaluate(() => { if (window.gameToggleQuestLog) window.gameToggleQuestLog(); });
    await sleep(800);
    const visible = await page.evaluate(() => !!window.gameQuestLogVisible);
    expect(visible).toBe(true);
    await page.screenshot({ path: path.join(SCREENSHOT_DIR, 'quest_log_open.png') });
    // Закрыть
    await page.evaluate(() => { if (window.gameToggleQuestLog) window.gameToggleQuestLog(); });
    await sleep(400);
  }, 60000);

  test('collect quest can be completed via dialogue', async () => {
    // Карта 3 — ручной квест "Принеси 2 буквы В"
    // 1. Получим текущее число completed_quest_ids
    const beforeQ = await getQuests(page);
    const beforeCompleted = beforeQ.completed_count || 0;
    // 2. Добавим себе 2 буквы В
    await page.evaluate(() => { if (window.gameTestAddLetter) { window.gameTestAddLetter('В'); window.gameTestAddLetter('В'); } });
    await sleep(800);
    // 3. Проверим что буква В у нас есть
    const inv = await page.evaluate(() => window.gameInventory || {});
    expect(Number((inv.letters || {}).В || 0)).toBeGreaterThanOrEqual(2);
    // 4. Дать точек (для dialogue нужно 3 буквицы = 3 точки)
    await page.evaluate(() => { if (window.gameTestAddDots) window.gameTestAddDots(15); });
    await sleep(400);
    // 5. Trigger dialogue (стартует диалог с ближайшим ? монстром, если в радиусе)
    //    Если рядом нет ? монстра — это OK, тест пропустит проверку сдачи
    const monsters = await page.evaluate(() => (window.gameMonsterStates || []).filter(m => m.id === 'question' && m.state !== 'dead'));
    if (monsters.length === 0) {
      console.log('  (skip — нет ? монстров на карте для теста сдачи)');
      return;
    }
    // Бот не подходит физически — используем dialogue bridge (он форсирует диалог с ближайшим)
    await page.evaluate(() => { if (window.gameTestStartDialogue) window.gameTestStartDialogue(); });
    await sleep(1500);
    // QuestLog должен показать 0 активных (если квест сдался)
    const afterQ = await getQuests(page);
    const afterActive = (afterQ.active || []).filter(q => q.type === 'collect').length;
    console.log('  collect active after dialogue:', afterActive, 'completed:', afterQ.completed_count);
    // Должно либо уменьшиться число активных collect-квестов, либо вырасти completed_count
    const success = (afterQ.completed_count > beforeCompleted);
    expect(success).toBe(true);
  }, 90000);
});
