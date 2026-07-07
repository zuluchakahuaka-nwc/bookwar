// regression_balance.test.js — проверка инверсии баланса §20:
// После инверсии base_power = position (А=1 слабая, Я=33 сильная).
// Старая схема (base_power = 34-position) устарела (AGENTS.md §20.1).
const puppeteer = require('puppeteer');

const GODOT_URL = process.env.GODOT_URL || 'http://localhost:3000';
const sleep = ms => new Promise(r => setTimeout(r, ms));

describe('§20 inverted balance: base_power = position', () => {
  let browser, page;

  beforeAll(async () => {
    browser = await puppeteer.launch({
      headless: true,
      args: ['--no-sandbox','--disable-web-security','--disable-features=ntlm-auth']
    });
    page = await browser.newPage();
    await page.setViewport({ width: 1280, height: 720 });
    await page.goto(GODOT_URL, { waitUntil: 'domcontentloaded', timeout: 60000 });
    await page.waitForSelector('canvas', { timeout: 30000 });
    const c = await page.$('canvas');
    if (c) { const bx = await c.boundingBox(); if (bx) await page.mouse.click(bx.x+5, bx.y+5); }
    await sleep(3000);
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
  }, 120000);

  afterAll(async () => { if (browser) await browser.close(); });

  test('alphabet snapshot has 33 letters', async () => {
    const snap = await page.evaluate(() => window.gameAlphabet || []);
    expect(Array.isArray(snap)).toBe(true);
    expect(snap.length).toBe(33);
  }, 30000);

  test('А (position 1) has base_power=1 (weak)', async () => {
    const snap = await page.evaluate(() => window.gameAlphabet || []);
    const a = snap.find(l => l.char === 'А');
    expect(a).toBeTruthy();
    expect(a.position).toBe(1);
    expect(a.base_power).toBe(1);  // §20: инверсия — А слабая
  }, 30000);

  test('Я (position 33) has base_power=33 (strong)', async () => {
    const snap = await page.evaluate(() => window.gameAlphabet || []);
    const ya = snap.find(l => l.char === 'Я');
    expect(ya).toBeTruthy();
    expect(ya.position).toBe(33);
    expect(ya.base_power).toBe(33);  // §20: инверсия — Я сильная
  }, 30000);

  test('О (position 16) has base_power=16 (middle)', async () => {
    const snap = await page.evaluate(() => window.gameAlphabet || []);
    const o = snap.find(l => l.char === 'О');
    expect(o).toBeTruthy();
    expect(o.position).toBe(16);
    expect(o.base_power).toBe(16);
  }, 30000);

  test('all letters have base_power = position', async () => {
    const snap = await page.evaluate(() => window.gameAlphabet || []);
    for (const l of snap) {
      expect(l.base_power).toBe(l.position);
    }
  }, 30000);

  test('all letters have speed = position (unchanged by §20)', async () => {
    const snap = await page.evaluate(() => window.gameAlphabet || []);
    for (const l of snap) {
      expect(l.speed).toBe(l.position);
    }
  }, 30000);
});
