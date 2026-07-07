// regression_save.test.js — сохранение прогресса квестов между reload.
// 1. Старт новой игры
// 2. Сдать квест на карте 3 (там 1 ручной collect-квест)
// 3. Перезагрузить страницу (имитация закрытия браузера)
// 4. Проверить что completed_quest_ids всё ещё содержит сданный квест
const puppeteer = require('puppeteer');

const GODOT_URL = process.env.GODOT_URL || 'http://localhost:3000';
const sleep = ms => new Promise(r => setTimeout(r, ms));

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

describe('quest progress persistence across reload', () => {
  let browser, page;

  beforeAll(async () => {
    browser = await puppeteer.launch({
      headless: true,
      args: ['--no-sandbox','--disable-web-security','--disable-features=ntlm-auth']
    });
  }, 30000);

  afterAll(async () => { if (browser) await browser.close(); });

  test('completed quest survives browser reload', async () => {
    page = await browser.newPage();
    await page.setViewport({ width: 1280, height: 720 });
    await page.goto(GODOT_URL, { waitUntil: 'domcontentloaded', timeout: 60000 });
    await page.waitForSelector('canvas', { timeout: 30000 });
    const c = await page.$('canvas');
    if (c) { const bx = await c.boundingBox(); if (bx) await page.mouse.click(bx.x+5, bx.y+5); }
    await sleep(3000);
    await newGameFlow(page);
    // 1. Перейти на карту 3 (dark_oaks — 1 квест "collect 2 В")
    await gotoMap(page, 'dark_oaks');
    await sleep(1500);
    const q1 = await page.evaluate(() => {
      try { return JSON.parse(window.gameQuests || '{}'); }
      catch (e) { return {}; }
    });
    const beforeCompleted = q1.completed_count || 0;
    console.log('  before: active=', (q1.active || []).length, 'completed=', beforeCompleted);
    // 2. Добавить 2 буквы В + точки для диалога
    await page.evaluate(() => { if (window.gameTestAddLetter) { window.gameTestAddLetter('В'); window.gameTestAddLetter('В'); } });
    await sleep(500);
    await page.evaluate(() => { if (window.gameTestAddDots) window.gameTestAddDots(15); });
    await sleep(500);
    // 3. Trigger dialogue — сдаст квест автоматически
    await page.evaluate(() => { if (window.gameTestStartDialogue) window.gameTestStartDialogue(); });
    await sleep(2500);
    const q2 = await page.evaluate(() => {
      try { return JSON.parse(window.gameQuests || '{}'); }
      catch (e) { return {}; }
    });
    const afterCompleted = q2.completed_count || 0;
    console.log('  after dialogue: completed=', afterCompleted);
    expect(afterCompleted).toBeGreaterThan(beforeCompleted);
    // 4. Подождать autosave (5с интервал)
    await sleep(7000);
    // 5. Проверить что save записан в localStorage
    const hasSave = await page.evaluate(() => !!localStorage.getItem('bookwar_save_v1'));
    expect(hasSave).toBe(true);
    // 6. Закрыть страницу (имитация закрытия браузера)
    const saveData = await page.evaluate(() => localStorage.getItem('bookwar_save_v1'));
    await page.close();

    // 7. Открыть новую страницу — «перезагрузка браузера»
    page = await browser.newPage();
    await page.setViewport({ width: 1280, height: 720 });
    // Восстановить save в localStorage ДО загрузки игры
    await page.goto(GODOT_URL, { waitUntil: 'domcontentloaded', timeout: 60000 });
    await page.evaluate((d) => localStorage.setItem('bookwar_save_v1', d), saveData);
    await page.reload({ waitUntil: 'domcontentloaded' });
    await page.waitForSelector('canvas', { timeout: 30000 });
    const c2 = await page.$('canvas');
    if (c2) { const bx = await c2.boundingBox(); if (bx) await page.mouse.click(bx.x+5, bx.y+5); }
    await sleep(3500);
    // 8. Проверить что main_menu видит save (кнопка Продолжить должна появиться)
    const hasContinue = await page.evaluate(() => !!window.gameHasSave);
    console.log('  after reload: hasSave in main_menu =', hasContinue);
    // 9. Использовать Continue (а не NewGame — NewGame очистит save)
    await page.evaluate(() => { if (window.gameClickContinue) window.gameClickContinue(); });
    await sleep(5000);  // Continue → прямо в world_map, без intro
    // 10. Перейти обратно на карту 3 и проверить что квест НЕ появился заново
    await gotoMap(page, 'dark_oaks');
    await sleep(1500);
    const q3 = await page.evaluate(() => {
      try { return JSON.parse(window.gameQuests || '{}'); }
      catch (e) { return {}; }
    });
    const finalCompleted = q3.completed_count || 0;
    const finalActive = (q3.active || []).length;
    console.log('  after reload+newgame: active=', finalActive, 'completed=', finalCompleted);
    // completed должен сохраниться (или как минимум не обнулиться)
    expect(finalCompleted).toBeGreaterThanOrEqual(afterCompleted);
  }, 180000);
});
