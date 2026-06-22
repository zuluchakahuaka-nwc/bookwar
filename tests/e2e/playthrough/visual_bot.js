#!/usr/bin/env node
/**
 * visual_bot.js — Визуальный бот для BOOKWAR
 * 
 * Запускает НЕ-headless браузер, чтобы пользователь ВИДЕЛ как бот играет.
 * Каждое действие: скриншот + лог.
 * Полное прохождение 1 уровня: старт → сбор точек → диалог → бой → победа.
 */

const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

const GODOT_URL = process.env.GODOT_URL || 'http://localhost:3000';
const SCREENSHOT_DIR = path.join(__dirname, '..', '..', 'screenshots');
const LOG_FILE = path.join(SCREENSHOT_DIR, 'bot_log.txt');

if (!fs.existsSync(SCREENSHOT_DIR)) fs.mkdirSync(SCREENSHOT_DIR, { recursive: true });
fs.writeFileSync(LOG_FILE, ''); // Clear previous log

let stepNum = 0;

function log(msg) {
  const ts = new Date().toISOString().substr(11, 8);
  const line = `[${ts}] ${msg}`;
  console.log(line);
  fs.appendFileSync(LOG_FILE, line + '\n');
}

async function sleep(ms) {
  return new Promise(r => setTimeout(r, ms));
}

async function waitFrames(page, count) {
  for (let i = 0; i < count; i++) {
    await page.evaluate(() => new Promise(r => requestAnimationFrame(r)));
  }
}

async function screenshot(page, label) {
  stepNum++;
  const name = `${String(stepNum).padStart(3, '0')}_${label}`;
  const filepath = path.join(SCREENSHOT_DIR, `${name}.png`);
  await page.screenshot({ path: filepath, fullPage: false });
  log(`📸 Скриншот #${stepNum}: ${label} → ${path.basename(filepath)}`);
  return filepath;
}

async function getState(page) {
  return await page.evaluate(() => ({
    loaded: window.gameLoaded || false,
    menuVisible: window.gameMenuVisible || false,
    playerPos: window.gamePlayerPos || { x: 0, y: 0 },
    inventory: window.gameInventory || { letters: {}, dots: 0, punctuation: {} },
    hud: window.gameHUD || { hp: '', dots: '', region: '' },
    dialogueActive: window.gameDialogueActive || false,
    dialogueText: window.gameDialogueText || '',
    inCombat: window.gameInCombat || false,
    monsterStates: window.gameMonsterStates || [],
    victory: window.gameVictory || false,
    combatState: window.gameCombatState || null,
    fontApplied: window.gameFontApplied || false,
    fontError: window.gameFontError || ''
  }));
}

async function holdKey(page, key, ms) {
  const canvas = await page.$('canvas');
  if (canvas) {
    const box = await canvas.boundingBox();
    if (box) await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
  }
  await sleep(50);
  await page.keyboard.down(key);
  await sleep(ms);
  await page.keyboard.up(key);
  await waitFrames(page, 5);
}

async function pressKey(page, key, duration = 100) {
  const canvas = await page.$('canvas');
  if (canvas) {
    const box = await canvas.boundingBox();
    if (box) await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
  }
  await sleep(50);
  await page.keyboard.down(key);
  await sleep(duration);
  await page.keyboard.up(key);
  await waitFrames(page, 5);
}

async function printState(state) {
  log(`  Состояние:`);
  log(`    Позиция: (${Math.round(state.playerPos.x)}, ${Math.round(state.playerPos.y)})`);
  log(`    HP: ${state.hud.hp}`);
  log(`    Точки: ${state.hud.dots}`);
  log(`    Регион: ${state.hud.region}`);
  const inv = state.inventory;
  const letters = Object.keys(inv.letters || {}).length > 0
    ? Object.entries(inv.letters).map(([k, v]) => `${k}(${v})`).join(', ')
    : 'нет';
  log(`    Буквы: ${letters}`);
  log(`    Точки: ${inv.dots || 0}, Многоточия: ${(inv.punctuation || {})['...'] || 0}`);
  log(`    Диалог: ${state.dialogueActive ? `«${state.dialogueText?.substr(0, 60)}»` : 'нет'}`);
  log(`    Бой: ${state.inCombat}`);
  log(`    Монстров на карте: ${state.monsterStates.length}`);
  if (state.combatState) {
    log(`    Бой — Враг: ${state.combatState.enemy_name} HP:${state.combatState.enemy_hp}/${state.combatState.enemy_max_hp}`);
    log(`    Бой — Игрок HP:${state.combatState.player_hp}/${state.combatState.player_max_hp}`);
  }
  log(`    Победа: ${state.victory}`);
}

async function run() {
  log('========================================');
  log('  BOOKWAR — Визуальный бот v1.0');
  log('========================================\n');

  // --- ЗАПУСК БРАУЗЕРА (НЕ headless!) ---
  log('🌐 Запуск браузера (НЕ headless — вы увидите игру)...');
  const browser = await puppeteer.launch({
    headless: false,
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-web-security',
      '--disable-features=ntlm-auth',
      '--window-size=1280,800'
    ]
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 720 });

  // Console listener
  page.on('console', msg => {
    const text = msg.text();
    if (msg.type() === 'error' || text.includes('Error') || text.includes('error')) {
      log(`  [GAME ERROR] ${text}`);
    }
  });

  // --- ШАГ 1: ЗАГРУЗКА ИГРЫ ---
  log('\n=== ШАГ 1: Загрузка игры ===');
  await page.goto(GODOT_URL, { waitUntil: 'networkidle0', timeout: 30000 });
  await page.waitForSelector('canvas', { timeout: 15000 });
  const canvas = await page.$('canvas');
  if (canvas) {
    const box = await canvas.boundingBox();
    if (box) await page.mouse.click(box.x + 5, box.y + 5);
  }
  await sleep(3000); // Wait for Godot to load
  log('✅ Страница загружена');

  let state = await getState(page);
  await screenshot(page, 'menu_start');
  await printState(state);

  // Check font
  if (state.fontApplied) {
    log('✅ Шрифт Ruslan Display применён');
  } else if (state.fontError) {
    log(`⚠️ Ошибка шрифта: ${state.fontError}`);
  }

  // --- ШАГ 2: НАЖАТЬ "НОВАЯ ИГРА" ---
  log('\n=== ШАГ 2: Новая игра ===');
  await page.evaluate(() => {
    if (typeof window.gameClickNewGame === 'function') window.gameClickNewGame();
  });
  await sleep(2000);
  await waitFrames(page, 30);
  
  state = await getState(page);
  log(`Меню видно: ${state.menuVisible}`);
  log(`Регион: ${state.hud.region}`);
  await screenshot(page, 'world_spawn');
  await printState(state);

  // --- ШАГ 3: СБОР ТОЧЕК (движение вправо) ---
  log('\n=== ШАГ 3: Сбор точек — движение вправо ===');
  
  // Move right to collect dots (they're in a grid to the right of spawn)
  for (let i = 0; i < 3; i++) {
    log(`Движение вправо #${i + 1}...`);
    await holdKey(page, 'KeyD', 600);
    state = await getState(page);
    log(`  Точки: ${state.inventory.dots}, Позиция: (${Math.round(state.playerPos.x)}, ${Math.round(state.playerPos.y)})`);
  }
  await screenshot(page, 'dots_collected_right');
  await printState(state);

  // --- ШАГ 4: ПРОВЕРКА ИНВЕНТАРЯ ---
  log('\n=== ШАГ 4: Проверка инвентаря ===');
  const inv = state.inventory;
  const dotsCollected = inv.dots || 0;
  const ellipsis = (inv.punctuation || {})['...'] || 0;
  const lettersCollected = Object.keys(inv.letters || {});
  log(`Собрано: точек=${dotsCollected}, многоточий=${ellipsis}, букв=${lettersCollected.join(',') || 'нет'}`);

  if (ellipsis === 0 && dotsCollected < 3) {
    log('⚠️ Недостаточно точек. Добавляю 12 точек (4 многоточия)...');
    await page.evaluate(() => {
      if (typeof window.gameTestAddDots === 'function') window.gameTestAddDots(12);
    });
    await sleep(500);
    state = await getState(page);
    log(`После добавления: точек=${state.inventory.dots}, многоточий=${(state.inventory.punctuation || {})['...'] || 0}`);
  }

  // Add some letters for combat
  if (!state.inventory.letters || Object.keys(state.inventory.letters).length === 0) {
    log('⚠️ Нет букв. Добавляю А и Б через тестовый мост для боя...');
    await page.evaluate(() => {
      if (typeof window.gameTestAddLetter === 'function') {
        window.gameTestAddLetter('А');
        window.gameTestAddLetter('Б');
        window.gameTestAddLetter('О');
      }
    });
    await sleep(500);
    state = await getState(page);
  }
  await screenshot(page, 'inventory_ready');
  await printState(state);

  // --- ШАГ 5: ДВИЖЕНИЕ К ? МОНСТРУ ---
  log('\n=== ШАГ 5: Поиск ? монстра ===');
  
  // Check monster states
  state = await getState(page);
  const qMonsters = state.monsterStates.filter(m => m.id === 'question' || m.symbol === '?');
  const eMonsters = state.monsterStates.filter(m => m.id === 'exclamation' || m.symbol === '!');
  log(`? монстров: ${qMonsters.length}, ! монстров: ${eMonsters.length}`);

  if (qMonsters.length > 0) {
    const target = qMonsters[0];
    log(`Цель: ${target.name} в (${Math.round(target.position.x)}, ${Math.round(target.position.y)})`);
    log(`  state=${target.state}, allegiance=${target.allegiance}`);

    // Move towards it
    const playerPos = state.playerPos;
    const dx = target.position.x - playerPos.x;
    const dy = target.position.y - playerPos.y;
    log(`Игрок в (${Math.round(playerPos.x)}, ${Math.round(playerPos.y)}), цель в (${Math.round(target.position.x)}, ${Math.round(target.position.y)})`);
    log(`Δ = (${Math.round(dx)}, ${Math.round(dy)})`);

    // Move right
    if (dx > 0) {
      log('Иду вправо к монстру...');
      await holdKey(page, 'KeyD', Math.min(Math.abs(dx) / 200 * 1000, 4000));
    }
    if (dy < -50) {
      log('Иду вверх к монстру...');
      await holdKey(page, 'KeyW', Math.min(Math.abs(dy) / 200 * 1000, 3000));
    }
    if (dy > 50) {
      log('Иду вниз к монстру...');
      await holdKey(page, 'KeyS', Math.min(Math.abs(dy) / 200 * 1000, 3000));
    }

    await screenshot(page, 'near_question_monster');
    state = await getState(page);
    await printState(state);
  }

  // --- ШАГ 6: ДИАЛОГ С ? МОНСТРОМ (многошаговый) ---
  log('\n=== ШАГ 6: Диалог с ? монстром — многошаговый ===');
  
  state = await getState(page);
  let ellipsisBefore = (state.inventory.punctuation || {})['...'] || 0;
  log(`Многоточий до диалога: ${ellipsisBefore}`);

  if (!state.dialogueActive) {
    log('Нажимаю T для начала диалога...');
    await page.evaluate(() => {
      if (typeof window.gameTriggerDialogue === 'function') window.gameTriggerDialogue();
    });
    await sleep(1000);
    state = await getState(page);
    log(`Диалог активен: ${state.dialogueActive}`);
    if (state.dialogueActive) {
      log(`Реплика 1: «${state.dialogueText}»`);
      ellipsisBefore = (state.inventory.punctuation || {})['...'] || 0;
      log(`Многоточий после реплики 1: ${ellipsisBefore}`);
    }
  }
  await screenshot(page, 'dialogue_step1');

  // Advance through all dialogue lines
  let stepCount = 1;
  while (state.dialogueActive) {
    stepCount++;
    log(`\nПродвигаю диалог (E) — шаг ${stepCount}...`);
    ellipsisBefore = (state.inventory.punctuation || {})['...'] || 0;
    
    await page.evaluate(() => {
      if (typeof window.gameAdvanceDialogue === 'function') window.gameAdvanceDialogue();
    });
    await sleep(1000);
    state = await getState(page);
    
    const ellipsisAfter = (state.inventory.punctuation || {})['...'] || 0;
    log(`Диалог активен: ${state.dialogueActive}`);
    
    if (state.dialogueActive) {
      log(`Реплика ${stepCount}: «${state.dialogueText}»`);
      log(`Многоточий: ${ellipsisBefore} → ${ellipsisAfter} (потрачено ${ellipsisBefore - ellipsisAfter})`);
      await screenshot(page, `dialogue_step${stepCount}`);
    } else {
      log(`Диалог завершён на шаге ${stepCount}`);
      if (state.dialogueText) log(`Последний текст: «${state.dialogueText?.substr(0, 80)}»`);
      await screenshot(page, 'dialogue_ended');
    }
  }
  await printState(state);

  // --- ШАГ 7: ДВИЖЕНИЕ К ! МОНСТРУ ---
  log('\n=== ШАГ 7: Поиск ! монстра ===');
  
  state = await getState(page);
  const activeEMonsters = state.monsterStates.filter(m => 
    (m.id === 'exclamation') && m.allegiance === 0 && m.state !== 'dead'
  );
  log(`Активных ! монстров: ${activeEMonsters.length}`);

  if (activeEMonsters.length > 0) {
    // Pick closest one
    const playerPos = state.playerPos;
    let closest = null;
    let closestDist = Infinity;
    for (const m of activeEMonsters) {
      const d = Math.hypot(m.position.x - playerPos.x, m.position.y - playerPos.y);
      if (d < closestDist) {
        closestDist = d;
        closest = m;
      }
    }
    log(`Ближайший !: ${closest.name} в (${Math.round(closest.position.x)}, ${Math.round(closest.position.y)}), дистанция=${Math.round(closestDist)}`);

    // Move towards it
    const dx = closest.position.x - playerPos.x;
    const dy = closest.position.y - playerPos.y;
    log(`Иду к ! монстру...`);
    if (dx > 0) await holdKey(page, 'KeyD', Math.min(Math.abs(dx) / 200 * 1000, 5000));
    if (dx < 0) await holdKey(page, 'KeyA', Math.min(Math.abs(dx) / 200 * 1000, 5000));
    if (dy < -50) await holdKey(page, 'KeyW', Math.min(Math.abs(dy) / 200 * 1000, 3000));
    if (dy > 50) await holdKey(page, 'KeyS', Math.min(Math.abs(dy) / 200 * 1000, 3000));

    await screenshot(page, 'near_exclamation_monster');
    state = await getState(page);
    await printState(state);
  }

  // --- ШАГ 8: ПОПЫТКА ДИАЛОГА С ! МОНСТРОМ (T) ---
  log('\n=== ШАГ 8: Попытка диалога с ! монстром (T) ===');
  state = await getState(page);
  
  // Check if we have ellipsis
  const hasEllipsis = (state.inventory.punctuation || {})['...'] > 0;
  log(`Есть многоточие: ${hasEllipsis}`);
  
  if (!state.inCombat && !state.dialogueActive) {
    if (hasEllipsis) {
      log('Нажимаю T для дипломатии с ! монстром...');
      await page.evaluate(() => {
        if (typeof window.gameTriggerDialogue === 'function') window.gameTriggerDialogue();
      });
      await sleep(1500);
      state = await getState(page);
      log(`Диалог: ${state.dialogueActive ? 'АКТИВЕН' : 'нет'}`);
      if (state.dialogueText) log(`Текст: «${state.dialogueText?.substr(0, 80)}»`);
      await screenshot(page, 'diplomacy_with_exclamation');
      
      if (state.dialogueActive) {
        log('Закрываю диалог (E)...');
        await pressKey(page, 'KeyE', 100);
        await sleep(1000);
        state = await getState(page);
      }
    } else {
      log('Нет многоточия — пропускаю дипломатию');
    }
  }
  await printState(state);

  // --- ШАГ 9: БОЙ (если ! монстр догнал) ---
  log('\n=== ШАГ 9: Бой ===');
  
  // Wait a moment for combat to trigger
  await sleep(2000);
  state = await getState(page);
  log(`В бою: ${state.inCombat}`);

  if (state.inCombat) {
    log('⚔️ БОЙ НАЧАЛСЯ!');
    await screenshot(page, 'combat_start');
    await printState(state);

    // Combat loop
    let round = 0;
    const maxRounds = 5;
    while (state.inCombat && round < maxRounds) {
      round++;
      log(`\n--- Бой: Раунд ${round} ---`);

      // Check combat state
      if (state.combatState) {
        log(`  Враг: ${state.combatState.enemy_name} HP:${state.combatState.enemy_hp}/${state.combatState.enemy_max_hp}`);
        log(`  Игрок: HP:${state.combatState.player_hp}/${state.combatState.player_max_hp}`);
        log(`  Активен: ${state.combatState.is_active}`);
      }

      // Select a letter
      const letters = Object.keys(state.inventory.letters || {});
      if (letters.length > 0) {
        // Pick a vowel for attack if available
        const vowels = letters.filter(l => 'АЕЁИОУЫЭЮЯ'.includes(l));
        const consonants = letters.filter(l => 'БВГДЖЗЙКЛМНПРСТФХЦЧШЩ'.includes(l));
        
        let pick;
        if (vowels.length > 0) {
          pick = vowels[0];
          log(`  Выбираю гласную: ${pick} (атака)`);
        } else if (consonants.length > 0) {
          pick = consonants[0];
          log(`  Выбираю согласную: ${pick} (защита)`);
        } else {
          pick = letters[0];
          log(`  Выбираю букву: ${pick}`);
        }

        await page.evaluate((l) => {
          if (typeof window.gameSelectCard === 'function') window.gameSelectCard(l);
        }, pick);
        await sleep(300);
        await screenshot(page, `combat_round${round}_selected_${pick}`);

        // Confirm turn
        log(`  Подтверждаю ход...`);
        await page.evaluate(() => {
          if (typeof window.gameConfirmTurn === 'function') window.gameConfirmTurn();
        });
        await sleep(2000);
      } else {
        log('  ⚠️ Нет букв для боя! Пропускаю ход...');
        await page.evaluate(() => {
          if (typeof window.gameConfirmTurn === 'function') window.gameConfirmTurn();
        });
        await sleep(2000);
      }

      await screenshot(page, `combat_round${round}_result`);
      state = await getState(page);
      log(`  Бой продолжается: ${state.inCombat}`);
      
      if (state.combatState) {
        log(`  Враг HP: ${state.combatState.enemy_hp}/${state.combatState.enemy_max_hp}`);
        log(`  Игрок HP: ${state.combatState.player_hp}/${state.combatState.player_max_hp}`);
      }
    }

    if (state.inCombat) {
      log('Бой затянулся — бегство!');
      await page.evaluate(() => {
        if (typeof window.gameFleeBattle === 'function') window.gameFleeBattle();
      });
      await sleep(2000);
    }

    await screenshot(page, 'combat_end');
    state = await getState(page);
    log(`После боя: HP=${state.hud.hp}, в бою=${state.inCombat}`);
  } else {
    log('Бой не начался. Иду к ! монстру ближе...');
    await holdKey(page, 'KeyD', 2000);
    await sleep(2000);
    state = await getState(page);
    log(`В бою: ${state.inCombat}`);
    
    if (state.inCombat) {
      log('⚔️ БОЙ НАЧАЛСЯ (повтор)!');
      await screenshot(page, 'combat_start_retry');
      
      // Quick combat
      const letters = Object.keys(state.inventory.letters || {});
      if (letters.length > 0) {
        await page.evaluate((l) => {
          if (typeof window.gameSelectCard === 'function') window.gameSelectCard(l);
        }, letters[0]);
        await sleep(300);
        await page.evaluate(() => {
          if (typeof window.gameConfirmTurn === 'function') window.gameConfirmTurn();
        });
        await sleep(2000);
        await screenshot(page, 'combat_retry_round1');
      }
    }
  }

  // --- ШАГ 10: ПРОВЕРКА ПОБЕДЫ ---
  log('\n=== ШАГ 10: Проверка победы ===');
  state = await getState(page);
  log(`Победа: ${state.victory}`);
  
  // Try to approach remaining monsters
  const remaining = state.monsterStates.filter(m => m.state !== 'dead' && !m.approached);
  log(`Неapproached монстров: ${remaining.length}`);
  
  if (remaining.length > 0 && !state.victory) {
    log('Иду к оставшимся монстрам для победы...');
    for (const m of remaining.slice(0, 3)) {
      const dx = m.position.x - state.playerPos.x;
      const dy = m.position.y - state.playerPos.y;
      log(`  Иду к ${m.name} (${Math.round(m.position.x)}, ${Math.round(m.position.y)})`);
      if (dx > 0) await holdKey(page, 'KeyD', Math.min(Math.abs(dx) / 200 * 1000, 3000));
      if (dx < 0) await holdKey(page, 'KeyA', Math.min(Math.abs(dx) / 200 * 1000, 3000));
      if (dy < -50) await holdKey(page, 'KeyW', Math.min(Math.abs(dy) / 200 * 1000, 3000));
      if (dy > 50) await holdKey(page, 'KeyS', Math.min(Math.abs(dy) / 200 * 1000, 3000));
      
      // If combat starts, flee quickly
      await sleep(500);
      state = await getState(page);
      if (state.inCombat) {
        log('  Бой! Бегство...');
        await page.evaluate(() => {
          if (typeof window.gameFleeBattle === 'function') window.gameFleeBattle();
        });
        await sleep(2000);
      }
    }
    await sleep(1500); // Wait for victory check
    state = await getState(page);
    log(`Победа: ${state.victory}`);
  }

  await screenshot(page, 'final_state');
  await printState(state);

  // --- ИТОГИ ---
  log('\n========================================');
  log('  ИТОГИ ПРОХОЖДЕНИЯ');
  log('========================================');
  state = await getState(page);
  log(`Скриншотов сделано: ${stepNum}`);
  log(`Позиция игрока: (${Math.round(state.playerPos.x)}, ${Math.round(state.playerPos.y)})`);
  log(`HP: ${state.hud.hp}`);
  log(`Точки: ${state.hud.dots}`);
  log(`Буквы: ${Object.entries(state.inventory.letters || {}).map(([k,v]) => `${k}(${v})`).join(', ') || 'нет'}`);
  log(`Победа: ${state.victory ? 'ДА' : 'НЕТ'}`);
  log(`Монстров всего: ${state.monsterStates.length}`);
  log(`Монстров мертво: ${state.monsterStates.filter(m => m.state === 'dead').length}`);
  log(`Монстров завербовано: ${state.monsterStates.filter(m => m.allegiance === 1).length}`);
  log(`Монстров нейтрально: ${state.monsterStates.filter(m => m.allegiance === 2).length}`);
  log(`\nЛог сохранён: ${LOG_FILE}`);
  log(`Скриншоты: ${SCREENSHOT_DIR}`);
  log('========================================\n');

  // Keep browser open for a few seconds so user can see
  log('Браузер останется открытым 5 секунд...');
  await sleep(5000);
  
  await browser.close();
  log('Браузер закрыт. Бот завершён.');
}

run().catch(err => {
  log(`❌ КРИТИЧЕСКАЯ ОШИБКА: ${err.message}`);
  log(err.stack);
  process.exit(1);
});
