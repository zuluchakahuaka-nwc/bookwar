#!/usr/bin/env node
/**
 * recruit_bot.js — Бот для теста армии рекрутов
 * 
 * 1. Старт → сбор точек → много многоточий
 * 2. Вербоуем 3-5 ? монстров через диалог
 * 3. Идём к ! монстрам — армия сражается вместо героя
 * 4. Проверяем что рекруты побеждают / падают
 * 5. Скрины + логи каждого шага
 */

const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

const GODOT_URL = 'http://localhost:3000';
const SCREENSHOT_DIR = path.join(__dirname, '..', '..', 'screenshots');
const LOG_FILE = path.join(SCREENSHOT_DIR, 'recruit_bot_log.txt');

if (!fs.existsSync(SCREENSHOT_DIR)) fs.mkdirSync(SCREENSHOT_DIR, { recursive: true });
fs.writeFileSync(LOG_FILE, '');

let stepNum = 0;
function log(msg) {
  const ts = new Date().toISOString().substr(11, 8);
  const line = `[${ts}] ${msg}`;
  console.log(line);
  fs.appendFileSync(LOG_FILE, line + '\n');
}
async function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }
async function waitFrames(page, n) { for (let i = 0; i < n; i++) await page.evaluate(() => new Promise(r => requestAnimationFrame(r))); }

async function screenshot(page, label) {
  stepNum++;
  const name = `${String(stepNum).padStart(3, '0')}_${label}`;
  const fp = path.join(SCREENSHOT_DIR, `${name}.png`);
  await page.screenshot({ path: fp, fullPage: false });
  log(`📸 #${stepNum}: ${label}`);
  return fp;
}

async function getState(page) {
  return await page.evaluate(() => ({
    playerPos: window.gamePlayerPos || { x: 0, y: 0 },
    inventory: window.gameInventory || { letters: {}, dots: 0, punctuation: {} },
    hud: window.gameHUD || {},
    dialogueActive: window.gameDialogueActive || false,
    dialogueText: window.gameDialogueText || '',
    inCombat: window.gameInCombat || false,
    monsterStates: window.gameMonsterStates || [],
    victory: window.gameVictory || false,
    recruitCount: window.gameRecruitCount || 0,
    autoCombat: window.gameAutoCombat || null,
    fontApplied: window.gameFontApplied || false
  }));
}

async function holdKey(page, key, ms) {
  const canvas = await page.$('canvas');
  if (canvas) { const box = await canvas.boundingBox(); if (box) await page.mouse.click(box.x + box.width/2, box.y + box.height/2); }
  await sleep(50);
  await page.keyboard.down(key); await sleep(ms); await page.keyboard.up(key);
  await waitFrames(page, 5);
}

async function run() {
  log('========================================');
  log('  BOOKWAR — Бот армии рекрутов v1.0');
  log('========================================\n');

  const browser = await puppeteer.launch({
    headless: false,
    args: ['--no-sandbox', '--disable-web-security', '--disable-features=ntlm-auth', '--window-size=1280,800']
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 720 });

  // --- ЗАГРУЗКА ---
  log('Загрузка игры...');
  await page.goto(GODOT_URL, { waitUntil: 'networkidle0', timeout: 30000 });
  await page.waitForSelector('canvas', { timeout: 15000 });
  const canvas = await page.$('canvas');
  if (canvas) { const box = await canvas.boundingBox(); if (box) await page.mouse.click(box.x + 5, box.y + 5); }
  await sleep(3000);

  let state = await getState(page);
  await screenshot(page, 'menu');
  log(`Шрифт: ${state.fontApplied ? '✅' : '❌'}`);

  // --- НОВАЯ ИГРА ---
  log('\n=== Новая игра ===');
  await page.evaluate(() => { if (typeof window.gameClickNewGame === 'function') window.gameClickNewGame(); });
  await sleep(2000); await waitFrames(page, 30);
  state = await getState(page);
  log(`Регион: ${state.hud.region}, HP: ${state.hud.hp}, Позиция: (${Math.round(state.playerPos.x)}, ${Math.round(state.playerPos.y)})`);
  await screenshot(page, 'world_start');

  // --- ДАТЬ МНОГО ТОЧЕК ДЛЯ ВЕРБОВКИ ---
  log('\n=== Подготовка: даём 30 точек (10 многоточий) ===');
  await page.evaluate(() => { if (typeof window.gameTestAddDots === 'function') window.gameTestAddDots(30); });
  await sleep(500);
  state = await getState(page);
  const ellipsis = (state.inventory.punctuation || {})['...'] || 0;
  log(`Точек: ${state.inventory.dots}, Многоточий: ${ellipsis}`);
  await screenshot(page, 'ellipsis_ready');

  // --- ВЕРБОВКА: идём к ? монстрам и говорим ---
  log('\n=== Вербовка ? монстров ===');
  
  for (let recruitAttempt = 0; recruitAttempt < 8; recruitAttempt++) {
    state = await getState(page);
    const ell = (state.inventory.punctuation || {})['...'] || 0;
    if (ell === 0) {
      log('Многоточия кончились — добmore');
      await page.evaluate(() => { if (typeof window.gameTestAddDots === 'function') window.gameTestAddDots(15); });
      await sleep(300);
    }

    // Find an unrecruited ? monster
    const available = state.monsterStates.filter(m => 
      m.id === 'question' && m.allegiance !== 1 && m.state !== 'dead'
    );
    if (available.length === 0) {
      log('Нет доступных ? монстров для вербовки');
      break;
    }

    const target = available[0];
    log(`\nВербовка #${recruitAttempt + 1}: ${target.name} в (${Math.round(target.position.x)}, ${Math.round(target.position.y)}), state=${target.state}`);

    // Move to monster
    const dx = target.position.x - state.playerPos.x;
    const dy = target.position.y - state.playerPos.y;
    if (Math.abs(dx) > 30) {
      if (dx > 0) await holdKey(page, 'KeyD', Math.min(Math.abs(dx) / 200 * 1000, 4000));
      else await holdKey(page, 'KeyA', Math.min(Math.abs(dx) / 200 * 1000, 4000));
    }
    if (Math.abs(dy) > 30) {
      if (dy > 0) await holdKey(page, 'KeyS', Math.min(Math.abs(dy) / 200 * 1000, 3000));
      else await holdKey(page, 'KeyW', Math.min(Math.abs(dy) / 200 * 1000, 3000));
    }

    await sleep(500);
    state = await getState(page);

    // Trigger dialogue
    if (!state.dialogueActive) {
      log('  Нажимаю T...');
      await page.evaluate(() => { if (typeof window.gameTriggerDialogue === 'function') window.gameTriggerDialogue(); });
      await sleep(1000);
      state = await getState(page);
    }

    if (state.dialogueActive) {
      log(`  Реплика: «${state.dialogueText?.substr(0, 60)}»`);
      await screenshot(page, `recruit${recruitAttempt + 1}_dialogue`);

      // Walk away to close dialogue (triggers recruit roll)
      log('  Отхожу (закрытие диалога → бросок вербовки)...');
      await holdKey(page, 'KeyD', 400);
      await sleep(500);

      // Also try advancing if still active
      while (state.dialogueActive) {
        await page.evaluate(() => { if (typeof window.gameAdvanceDialogue === 'function') window.gameAdvanceDialogue(); });
        await sleep(800);
        state = await getState(page);
      }
    }

    state = await getState(page);
    log(`  Рекрутов: ${state.recruitCount}`);
  }

  state = await getState(page);
  log(`\n=== Итог вербовки ===`);
  log(`Рекрутов в армии: ${state.recruitCount}`);
  const recruited = state.monsterStates.filter(m => m.allegiance === 1);
  const neutral = state.monsterStates.filter(m => m.allegiance === 2);
  log(`Зелёных (recruited): ${recruited.length}, Серых (neutral): ${neutral.length}`);
  await screenshot(page, 'army_ready');

  // --- АРМИЯ В БОЮ: идём к ! монстрам ---
  log('\n=== АРМИЯ В БОЮ ===');

  for (let combatNum = 0; combatNum < 5; combatNum++) {
    state = await getState(page);
    if (state.recruitCount === 0) {
      log('Армия разбита! Больше некому сражаться.');
      break;
    }

    // Find nearest hostile ! monster
    const hostiles = state.monsterStates.filter(m => 
      m.id === 'exclamation' && m.allegiance === 0 && m.state !== 'dead'
    );
    if (hostiles.length === 0) {
      log('Нет враждебных ! монстров!');
      break;
    }

    // Find closest
    let closest = hostiles[0];
    let closestDist = Infinity;
    for (const m of hostiles) {
      const d = Math.hypot(m.position.x - state.playerPos.x, m.position.y - state.playerPos.y);
      if (d < closestDist) { closestDist = d; closest = m; }
    }

    log(`\nБой #${combatNum + 1}: ${closest.name} в (${Math.round(closest.position.x)}, ${Math.round(closest.position.y)})`);
    log(`  Дистанция: ${Math.round(closestDist)}, Рекрутов: ${state.recruitCount}`);

    // Walk towards it
    const dx = closest.position.x - state.playerPos.x;
    const dy = closest.position.y - state.playerPos.y;
    if (dx > 0) await holdKey(page, 'KeyD', Math.min(Math.abs(dx) / 200 * 1000, 5000));
    if (dx < 0) await holdKey(page, 'KeyA', Math.min(Math.abs(dx) / 200 * 1000, 5000));
    if (dy < -50) await holdKey(page, 'KeyW', Math.min(Math.abs(dy) / 200 * 1000, 3000));
    if (dy > 50) await holdKey(page, 'KeyS', Math.min(Math.abs(dy) / 200 * 1000, 3000));

    // Wait for auto-combat or regular combat
    await sleep(3000);
    state = await getState(page);

    if (state.autoCombat) {
      log(`  ⚔ АВТО-БОЙ! Армия: ${state.autoCombat.recruits} рекрутов`);
      log(`  Сила армии: ${state.autoCombat.armyPower} vs Сила врага: ${state.autoCombat.enemyPower}`);
      log(`  Результат: ${state.autoCombat.won ? '🏆 ПОБЕДА!' : '💀 Армия отступила...'}`);
      await screenshot(page, `army_combat${combatNum + 1}_${state.autoCombat.won ? 'WIN' : 'LOSS'}`);
      await sleep(2000);
    } else if (state.inCombat) {
      log('  ⚠ Обычный бой (рекрутов не было?) — бегство!');
      await page.evaluate(() => { if (typeof window.gameFleeBattle === 'function') window.gameFleeBattle(); });
      await sleep(2000);
    } else if (state.dialogueActive) {
      log(`  Диалог: «${state.dialogueText?.substr(0, 80)}»`);
      await screenshot(page, `army_combat${combatNum + 1}_result`);
      // Wait for auto-close
      await sleep(4000);
    } else {
      log('  Ничего не произошло — иду ближе...');
      await holdKey(page, 'KeyD', 2000);
      await sleep(2000);
      state = await getState(page);
      if (state.autoCombat) {
        log(`  ⚔ АВТО-БОЙ (повтор)! ${state.autoCombat.won ? 'WIN' : 'LOSS'}`);
        await screenshot(page, `army_combat${combatNum + 1}_retry`);
        await sleep(2000);
      } else if (state.inCombat) {
        log('  Обычный бой — бегство!');
        await page.evaluate(() => { if (typeof window.gameFleeBattle === 'function') window.gameFleeBattle(); });
        await sleep(2000);
      }
    }

    state = await getState(page);
    log(`  Рекрутов осталось: ${state.recruitCount}`);
  }

  // --- ИТОГИ ---
  log('\n========================================');
  log('  ИТОГИ ТЕСТА АРМИИ РЕКРУТОВ');
  log('========================================');
  state = await getState(page);
  log(`Рекрутов: ${state.recruitCount}`);
  log(`HP героя: ${state.hud.hp}`);
  log(`Буквы: ${Object.entries(state.inventory.letters || {}).map(([k,v]) => `${k}(${v})`).join(', ') || 'нет'}`);
  log(`Монстров всего: ${state.monsterStates.length}`);
  log(`Мертво: ${state.monsterStates.filter(m => m.state === 'dead').length}`);
  log(`Завербовано: ${state.monsterStates.filter(m => m.allegiance === 1).length}`);
  log(`Нейтрально: ${state.monsterStates.filter(m => m.allegiance === 2).length}`);
  log(`Враждебно: ${state.monsterStates.filter(m => m.allegiance === 0 && m.state !== 'dead').length}`);
  log(`Скриншотов: ${stepNum}`);
  log('========================================\n');

  await sleep(5000);
  await browser.close();
  log('Бот завершён.');
}

run().catch(err => { log(`❌ ОШИБКА: ${err.message}`); log(err.stack); process.exit(1); });
