#!/usr/bin/env node
/**
 * forest_bot.js — Бот для теста перехода на карту 2 «Лес Двубуквия»
 *
 * 1. Старт → новая игра → Светлая Долина
 * 2. gameTestGotoMap("two_letter_forest") → переход
 * 3. Проверка: регион = «Лес Двубуквия», монстры есть, предметы есть
 * 4. Скриншоты
 */

const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

const GODOT_URL = process.env.GODOT_URL || 'http://localhost:3000';
const SCREENSHOT_DIR = path.join(__dirname, '..', '..', 'screenshots');

if (!fs.existsSync(SCREENSHOT_DIR)) fs.mkdirSync(SCREENSHOT_DIR, { recursive: true });

let stepNum = 0;
function log(msg) {
  const ts = new Date().toISOString().substr(11, 8);
  console.log(`[${ts}] ${msg}`);
}
async function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }
async function waitFrames(page, n) { for (let i = 0; i < n; i++) await page.evaluate(() => new Promise(r => requestAnimationFrame(r))); }

async function screenshot(page, label) {
  stepNum++;
  const fp = path.join(SCREENSHOT_DIR, `${String(stepNum).padStart(3, '0')}_forest_${label}.png`);
  await page.screenshot({ path: fp, fullPage: false });
  log(`📸 #${stepNum}: ${label}`);
  return fp;
}

async function getState(page) {
  return await page.evaluate(() => ({
    playerPos: window.gamePlayerPos || { x: 0, y: 0 },
    inventory: window.gameInventory || { letters: {}, dots: 0, punctuation: {} },
    hud: window.gameHUD || {},
    monsterStates: window.gameMonsterStates || [],
    victory: window.gameVictory || false,
    portalSpawned: window.gamePortalSpawned || false,
    fontApplied: window.gameFontApplied || false
  }));
}

async function run() {
  log('========================================');
  log('  BOOKWAR — Бот Леса Двубуквия v1.0');
  log('========================================\n');

  const browser = await puppeteer.launch({
    headless: false,
    args: ['--no-sandbox', '--disable-web-security', '--disable-features=ntlm-auth', '--window-size=1280,800']
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 720 });

  page.on('console', msg => {
    const text = msg.text();
    if (msg.type() === 'error' || text.includes('Error')) {
      log(`  [GAME ERROR] ${text}`);
    }
  });

  // --- ЗАГРУЗКА ---
  log('Загрузка игры...');
  await page.goto(GODOT_URL, { waitUntil: 'networkidle0', timeout: 30000 });
  await page.waitForSelector('canvas', { timeout: 15000 });
  const canvas = await page.$('canvas');
  if (canvas) { const box = await canvas.boundingBox(); if (box) await page.mouse.click(box.x + 5, box.y + 5); }
  await sleep(3000);

  // --- НОВАЯ ИГРА ---
  log('=== Новая игра (Светлая Долина) ===');
  await page.evaluate(() => { if (typeof window.gameClickNewGame === 'function') window.gameClickNewGame(); });
  await sleep(2000); await waitFrames(page, 30);

  let state = await getState(page);
  log(`Регион: ${state.hud.region}, HP: ${state.hud.hp}, Монстров: ${state.monsterStates.length}`);
  await screenshot(page, 'valley_start');

  // --- ПЕРЕХОД НА ЛЕС ДВУБУКВИЯ ---
  log('\n=== Переход на Лес Двубуквия ===');
  await page.evaluate(() => { if (typeof window.gameTestGotoMap === 'function') window.gameTestGotoMap('two_letter_forest'); });
  await sleep(3000); await waitFrames(page, 30);

  state = await getState(page);
  log(`Регион: ${state.hud.region}`);
  log(`Монстров: ${state.monsterStates.length}`);
  log(`Буквы: ${Object.entries(state.inventory.letters || {}).map(([k,v]) => `${k}(${v})`).join(', ') || 'нет'}`);
  await screenshot(page, 'forest_loaded');

  // Проверки
  const regionOk = state.hud.region === 'Лес Двубуквия';
  const monstersOk = state.monsterStates.length > 0;
  log(`\n=== Результаты ===`);
  log(`Регион = «Лес Двубуквия»: ${regionOk ? '✅' : '❌ («' + state.hud.region + '»)'}`);
  log(`Монстры есть: ${monstersOk ? '✅ (' + state.monsterStates.length + ')' : '❌'}`);
  log(`HP героя: ${state.hud.hp}`);

  // Дать точки и попробовать диалог
  log('\n=== Тест диалога в лесу ===');
  await page.evaluate(() => { if (typeof window.gameTestAddDots === 'function') window.gameTestAddDots(30); });
  await sleep(500);

  // Двигаться к ближайшему монстру
  if (state.monsterStates.length > 0) {
    const m = state.monsterStates[0];
    log(`Ближайший монстр: ${m.name} в (${Math.round(m.position.x)}, ${Math.round(m.position.y)}), state=${m.state}`);

    // Try dialogue
    await page.evaluate(() => { if (typeof window.gameTriggerDialogue === 'function') window.gameTriggerDialogue(); });
    await sleep(2000);
    state = await getState(page);
    if (state.inventory && (state.inventory.punctuation || {})['...'] > 0) {
      log(`Многоточий: ${(state.inventory.punctuation || {})['...']}`);
    }
  }

  await screenshot(page, 'forest_dialogue_test');

  log('\n=== ИТОГ ===');
  log(`Переход на Лес Двубуквия: ${regionOk ? '✅ УСПЕХ' : '❌ ПРОВАЛ'}`);
  log(`Скриншотов: ${stepNum}`);

  await sleep(5000);
  await browser.close();
  log('Бот завершён.');
}

run().catch(err => { log(`❌ ОШИБКА: ${err.message}`); console.error(err.stack); process.exit(1); });
