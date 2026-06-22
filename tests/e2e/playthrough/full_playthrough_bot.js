#!/usr/bin/env node
/**
 * full_playthrough_bot.js — Полное прохождение обеих карт
 *
 * Карта 1: Светлая Долина — сбор точек, диалоги, вербовка, бой, победа, портал
 * Карта 2: Лес Двубуквия — исследование, бой с боссом Двуязыкий
 *
 * Скриншот каждого ключевого момента для Vision-анализа.
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
  const fp = path.join(SCREENSHOT_DIR, `${String(stepNum).padStart(3, '0')}_${label}.png`);
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
    portalSpawned: window.gamePortalSpawned || false,
    autoCombat: window.gameAutoCombat || null,
    recruitCount: window.gameRecruitCount || 0,
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

async function moveTo(page, state, targetX, targetY, threshold = 40) {
  let dx = targetX - state.playerPos.x;
  let dy = targetY - state.playerPos.y;
  let attempts = 0;
  while ((Math.abs(dx) > threshold || Math.abs(dy) > threshold) && attempts < 15) {
    if (Math.abs(dx) > threshold) {
      if (dx > 0) await holdKey(page, 'KeyD', Math.min(Math.abs(dx) / 200 * 1000, 3000));
      else await holdKey(page, 'KeyA', Math.min(Math.abs(dx) / 200 * 1000, 3000));
    }
    if (Math.abs(dy) > threshold) {
      if (dy > 0) await holdKey(page, 'KeyS', Math.min(Math.abs(dy) / 200 * 1000, 2000));
      else await holdKey(page, 'KeyW', Math.min(Math.abs(dy) / 200 * 1000, 2000));
    }
    state = await getState(page);
    dx = targetX - state.playerPos.x;
    dy = targetY - state.playerPos.y;
    attempts++;
  }
  return state;
}

async function run() {
  log('=================================================');
  log('  BOOKWAR — Полное прохождение (2 карты)');
  log('=================================================\n');

  const browser = await puppeteer.launch({
    headless: false,
    args: ['--no-sandbox', '--disable-web-security', '--disable-features=ntlm-auth', '--window-size=1280,800']
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 720 });

  page.on('console', msg => {
    const text = msg.text();
    if (msg.type() === 'error' || text.includes('Error') || text.includes('SCRIPT ERROR')) {
      log(`  ⚠ [GAME ERROR] ${text}`);
    }
  });

  // ========== ЗАГРУЗКА ==========
  log('Загрузка игры...');
  await page.goto(GODOT_URL, { waitUntil: 'networkidle0', timeout: 30000 });
  await page.waitForSelector('canvas', { timeout: 15000 });
  const canvas = await page.$('canvas');
  if (canvas) { const box = await canvas.boundingBox(); if (box) await page.mouse.click(box.x + 5, box.y + 5); }
  await sleep(3000);

  let state = await getState(page);
  log(`Шрифт: ${state.fontApplied ? '✅' : '❌'}`);
  await screenshot(page, 'menu');

  // ========== НОВАЯ ИГРА ==========
  log('\n=== КАРТА 1: Светлая Долина ===');
  await page.evaluate(() => { if (typeof window.gameClickNewGame === 'function') window.gameClickNewGame(); });
  await sleep(2000); await waitFrames(page, 30);
  state = await getState(page);
  log(`Регион: ${state.hud.region}, HP: ${state.hud.hp}, Монстров: ${state.monsterStates.length}`);
  await screenshot(page, 'valley_start');

  // ========== СБОР ТОЧЕК ==========
  log('\n--- Сбор точек ---');
  await page.evaluate(() => { if (typeof window.gameTestAddDots === 'function') window.gameTestAddDots(30); });
  await sleep(500);
  state = await getState(page);
  const ellipsis = (state.inventory.punctuation || {})['...'] || 0;
  log(`Точек: ${state.inventory.dots}, Многоточий: ${ellipsis}`);

  // ========== ВЕРБОВКА ==========
  log('\n--- Вербовка ? монстров ---');
  let recruitedTotal = 0;
  for (let i = 0; i < 6; i++) {
    state = await getState(page);
    const ell = (state.inventory.punctuation || {})['...'] || 0;
    if (ell === 0) {
      await page.evaluate(() => { if (typeof window.gameTestAddDots === 'function') window.gameTestAddDots(15); });
      await sleep(300);
    }
    const available = state.monsterStates.filter(m => m.id === 'question' && m.allegiance !== 1 && m.state !== 'dead');
    if (available.length === 0) { log('Нет доступных ? монстров'); break; }

    const target = available[0];
    log(`Вербовка #${i+1}: ${target.name} в (${Math.round(target.position.x)}, ${Math.round(target.position.y)})`);
    state = await moveTo(page, state, target.position.x, target.position.y, 60);

    if (!state.dialogueActive) {
      await page.evaluate(() => { if (typeof window.gameTriggerDialogue === 'function') window.gameTriggerDialogue(); });
      await sleep(1500);
      state = await getState(page);
    }
    if (state.dialogueActive) {
      log(`  Реплика: «${state.dialogueText?.substr(0, 50)}»`);
      // Advance through dialogue lines
      while (state.dialogueActive) {
        await page.evaluate(() => { if (typeof window.gameAdvanceDialogue === 'function') window.gameAdvanceDialogue(); });
        await sleep(1000);
        state = await getState(page);
      }
    }
    // Walk away to trigger recruit roll
    await holdKey(page, 'KeyD', 300);
    await sleep(500);
    state = await getState(page);
    log(`  Рекрутов: ${state.recruitCount}`);
    if (state.recruitCount > recruitedTotal) {
      recruitedTotal = state.recruitCount;
    }
  }
  state = await getState(page);
  log(`Итого рекрутов: ${state.recruitCount}`);
  await screenshot(page, 'valley_army');

  // ========== АРМИЯ В БОЮ ==========
  log('\n--- Армия в бою с ! монстрами ---');
  for (let i = 0; i < 4; i++) {
    state = await getState(page);
    if (state.recruitCount === 0) { log('Армия разбита!'); break; }
    const hostiles = state.monsterStates.filter(m => m.id === 'exclamation' && m.allegiance === 0 && m.state !== 'dead');
    if (hostiles.length === 0) { log('Нет враждебных !'); break; }

    let closest = hostiles[0], closestDist = Infinity;
    for (const m of hostiles) {
      const d = Math.hypot(m.position.x - state.playerPos.x, m.position.y - state.playerPos.y);
      if (d < closestDist) { closestDist = d; closest = m; }
    }
    log(`Бой #${i+1}: ${closest.name} (${Math.round(closestDist)}px), рекрутов: ${state.recruitCount}`);
    state = await moveTo(page, state, closest.position.x, closest.position.y, 40);
    await sleep(2500);
    state = await getState(page);

    if (state.autoCombat) {
      log(`  ⚔ Армия ${state.autoCombat.armyPower} vs ${state.autoCombat.enemyPower} → ${state.autoCombat.won ? '🏆' : '💀'}`);
      await screenshot(page, `valley_combat${i+1}_${state.autoCombat.won ? 'WIN' : 'LOSS'}`);
      await sleep(2500);
    } else if (state.dialogueActive) {
      log(`  Диалог: «${state.dialogueText?.substr(0, 60)}»`);
      await screenshot(page, `valley_combat${i+1}_result`);
      await sleep(3500);
    }
    state = await getState(page);
    log(`  Рекрутов: ${state.recruitCount}`);
  }

  // ========== ПОБЕДА И ПОРТАЛ ==========
  log('\n--- Проверка победы ---');
  state = await getState(page);
  log(`Победа: ${state.victory}, Портал: ${state.portalSpawned}`);

  // If not victory yet, force-goto forest
  if (!state.victory) {
    log('Победа ещё не достигнута — используем тестовый переход');
  }
  await screenshot(page, 'valley_end');

  // ========== ПЕРЕХОД НА ЛЕС ==========
  log('\n=== КАРТА 2: Лес Двубуквия ===');
  await page.evaluate(() => { if (typeof window.gameTestGotoMap === 'function') window.gameTestGotoMap('two_letter_forest'); });
  await sleep(3000); await waitFrames(page, 30);
  state = await getState(page);
  log(`Регион: ${state.hud.region}`);
  log(`Монстров: ${state.monsterStates.length}`);
  log(`HP: ${state.hud.hp}`);
  const forestLetters = Object.entries(state.inventory.letters || {}).map(([k,v]) => `${k}(${v})`).join(', ');
  log(`Буквы: ${forestLetters || 'нет'}`);
  await screenshot(page, 'forest_start');

  // ========== ИССЛЕДОВАНИЕ ЛЕСА ==========
  log('\n--- Исследование леса ---');
  // Move around to see forest layout
  state = await getState(page);
  await holdKey(page, 'KeyD', 1500);
  state = await getState(page);
  await screenshot(page, 'forest_explore_right');
  log(`Позиция: (${Math.round(state.playerPos.x)}, ${Math.round(state.playerPos.y)})`);

  await holdKey(page, 'KeyW', 1500);
  state = await getState(page);
  await screenshot(page, 'forest_explore_north');
  log(`Позиция: (${Math.round(state.playerPos.x)}, ${Math.round(state.playerPos.y)})`);

  await holdKey(page, 'KeyA', 1500);
  state = await getState(page);
  await screenshot(page, 'forest_explore_left');
  log(`Позиция: (${Math.round(state.playerPos.x)}, ${Math.round(state.playerPos.y)})`);

  // ========== ДИАЛОГ В ЛЕСУ ==========
  log('\n--- Диалог с монстром в лесу ---');
  await page.evaluate(() => { if (typeof window.gameTestAddDots === 'function') window.gameTestAddDots(15); });
  await sleep(300);
  state = await getState(page);
  const forestMonsters = state.monsterStates.filter(m => m.state !== 'dead');
  if (forestMonsters.length > 0) {
    const m = forestMonsters[0];
    log(`Монстр: ${m.name} (${m.id}), state=${m.state}`);
    state = await moveTo(page, state, m.position.x, m.position.y, 60);
    await page.evaluate(() => { if (typeof window.gameTriggerDialogue === 'function') window.gameTriggerDialogue(); });
    await sleep(1500);
    state = await getState(page);
    if (state.dialogueActive) {
      log(`Реплика: «${state.dialogueText?.substr(0, 70)}»`);
      await screenshot(page, 'forest_dialogue');
      while (state.dialogueActive) {
        await page.evaluate(() => { if (typeof window.gameAdvanceDialogue === 'function') window.gameAdvanceDialogue(); });
        await sleep(1000);
        state = await getState(page);
      }
    }
  }

  // ========== БОСС ДВУЯЗЫКИЙ ==========
  log('\n--- Поиск босса Двуязыкого ---');
  state = await getState(page);
  // Find the two_tongue boss (should be in deep ring)
  const allMonsters = state.monsterStates;
  let boss = null;
  for (const m of allMonsters) {
    // Boss has higher HP or is two_tongue
    if (m.name === 'Двуязыкий' || m.id === 'two_tongue') {
      boss = m;
      break;
    }
  }
  // If boss not found by name, find the one furthest from start
  if (!boss && allMonsters.length > 0) {
    let maxDist = 0;
    for (const m of allMonsters) {
      if (m.state === 'dead') continue;
      const d = Math.hypot(m.position.x - 1216, m.position.y - 1536);
      if (d > maxDist) { maxDist = d; boss = m; }
    }
  }
  if (boss) {
    log(`Босс: ${boss.name} в (${Math.round(boss.position.x)}, ${Math.round(boss.position.y)}), HP: ${boss.hp}`);
    state = await moveTo(page, state, boss.position.x, boss.position.y, 50);
    await screenshot(page, 'forest_boss_found');

    // Try combat
    await sleep(2000);
    state = await getState(page);
    if (state.autoCombat) {
      log(`  ⚔ Армия ${state.autoCombat.armyPower} vs Босс ${state.autoCombat.enemyPower} → ${state.autoCombat.won ? '🏆' : '💀'}`);
      await screenshot(page, `forest_boss_combat_${state.autoCombat.won ? 'WIN' : 'LOSS'}`);
    } else if (state.inCombat) {
      log('  Обычный бой с боссом!');
      await screenshot(page, 'forest_boss_battle');
    } else if (state.dialogueActive) {
      log(`  Диалог с боссом: «${state.dialogueText?.substr(0, 70)}»`);
      await screenshot(page, 'forest_boss_dialogue');
    } else {
      log('  Босс не среагировал — подхожу ближе');
      await holdKey(page, 'KeyD', 1000);
      await sleep(2000);
      state = await getState(page);
      if (state.autoCombat) {
        log(`  ⚔ ${state.autoCombat.won ? '🏆' : '💀'} (army ${state.autoCombat.armyPower} vs ${state.autoCombat.enemyPower})`);
        await screenshot(page, `forest_boss_combat2_${state.autoCombat.won ? 'WIN' : 'LOSS'}`);
      }
    }
  } else {
    log('Босс не найден!');
  }

  // ========== ИТОГ ==========
  state = await getState(page);
  log('\n=================================================');
  log('  ИТОГ ПОЛНОГО ПРОХОЖДЕНИЯ');
  log('=================================================');
  log(`Карта 1: Светлая Долина — ${state.victory || state.portalSpawned ? '✅ пройдена' : '⚠ не завершена'}`);
  log(`Карта 2: Лес Двубуквия — регион: ${state.hud.region}`);
  log(`HP героя: ${state.hud.hp}`);
  log(`Рекрутов: ${state.recruitCount}`);
  log(`Буквы: ${Object.entries(state.inventory.letters || {}).map(([k,v]) => `${k}(${v})`).join(', ') || 'нет'}`);
  log(`Монстров в лесу: ${state.monsterStates.length}`);
  log(`Мертво: ${state.monsterStates.filter(m => m.state === 'dead').length}`);
  log(`Скриншотов: ${stepNum}`);
  log('=================================================\n');

  await sleep(5000);
  await browser.close();
  log('Бот завершён.');
}

run().catch(err => { log(`❌ ОШИБКА: ${err.message}`); console.error(err.stack); process.exit(1); });
