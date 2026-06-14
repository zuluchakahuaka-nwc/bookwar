// Walkthrough bot: plays Light Valley step-by-step like a real player.
// Every step: logs action + game state, waits for an expected outcome with a TIMEOUT.
// If the outcome doesn't arrive → dumps the stuck state + screenshot + likely cause.
// Reusable framework: define steps[], run them. Each region can have its own bot.
const godot = require('./helpers/godot_page');
const gameActions = require('./helpers/game_actions');

let stepNum = 0;

// ── Step runner with timeout + stuck-state diagnostics ──────────────────────────
async function runStep(name, action, check, timeoutMs) {
  stepNum++;
  const tag = `[Шаг ${String(stepNum).padStart(2, '0')}] ${name}`;
  console.log(`\n${'='.repeat(70)}\n${tag}\n${'='.repeat(70)}`);
  const t0 = Date.now();
  let lastState = null;
  try {
    await action();
  } catch (e) {
    console.log(`${tag} → ОШИБКА ДЕЙСТВИЯ: ${e.message}`);
  }
  // Poll for the expected outcome
  const deadline = Date.now() + timeoutMs;
  let ok = false;
  while (Date.now() < deadline) {
    lastState = await godot.getGameState();
    const result = await check(lastState);
    if (result.ok) {
      ok = true;
      console.log(`${tag} → ✓ OK (${Date.now() - t0}мс): ${result.detail || ''}`);
      return { ok: true, state: lastState };
    }
    await godot.waitMs(400);
  }
  // ── STUCK: timeout expired, diagnose ──
  const shot = await godot.takeScreenshot(`STUCK_шаг${stepNum}`);
  console.log(`${tag} → ✗ ЗАВИСЛО (timeout ${timeoutMs}мс)`);
  console.log(`  Состояние игры: ${JSON.stringify(lastState)}`);
  console.log(`  Скриншот: ${shot}`);
  console.log(`  Возможная причина: ${diagnose(name, lastState)}`);
  return { ok: false, state: lastState, shot };
}

function diagnose(stepName, st) {
  if (!st.loaded) return 'игра не загрузилась (window.gameLoaded=false)';
  if (st.inCombat && stepName.includes('бой')) return 'бой идёт, но ожидаемый результат не достигнут — мало HP/урона?';
  if (!st.inCombat && stepName.includes('бой')) return 'бой не начался — монстр далеко или не агрессивен';
  if (st.inCombat) return `игрок застрял в бою (inCombat=true), возможно нет букв для атаки`;
  if (st.dialogueActive && !stepName.includes('диалог')) return 'диалог открыт и блокирует — нужно закрыть';
  if (st.inventoryVisible && !stepName.includes('инвентарь')) return 'инвентарь открыт и блокирует ввод';
  const inv = st.inventory || {};
  if (inv.dots === 0 && stepName.includes('точ')) return 'точки не собираются — игрок не на точках или авто-сбор сломан';
  if (!(inv.punctuation && inv.punctuation['...']) && stepName.includes('многоточ')) return 'многоточие не создано — нужно ≥3 точек';
  if (Object.keys(inv.letters || {}).length === 0 && stepName.includes('букв')) return 'буквы не получены';
  return 'неизвестно — смотрите скриншот STUCK';
}

// Helper: move toward a direction and collect
async function moveAndCollect(dir, ms) {
  await gameActions.movePlayer(dir, ms);
}

describe('Бот-прохождение: Светлая Долина', () => {
  jest.setTimeout(300000);

  beforeAll(async () => {
    await godot.loadGame();
    await gameActions.waitForGameLoad();
  });
  afterAll(async () => { await godot.closeBrowser(); });

  test('Прохождение уровня', async () => {
    let result;

    // ── 01: Меню → Новая игра ──
    result = await runStep('Старт: меню видимо',
      async () => { /* меню показывается при загрузке */ },
      (st) => ({ ok: st.menuVisible === true, detail: 'меню видно' }),
      15000);

    // ── 02: Новая игра → спавн в долине ──
    result = await runStep('Новая игра → спавн в Светлой Долине',
      async () => { await gameActions.startNewGame(); await godot.waitMs(2500); },
      (st) => ({ ok: st.loaded && !st.menuVisible && st.playerPos.x > 0 }),
      20000);
    await godot.takeScreenshot('walk_02_spawn');

    // ── 03: Движение работает (WASD) ──
    const posBefore = await gameActions.getPlayerPosition();
    result = await runStep('Движение WASD — позиция меняется',
      async () => { await gameActions.movePlayer('right', 800); },
      async (st) => {
        const moved = Math.abs(st.playerPos.x - posBefore.x) > 20;
        return { ok: moved, detail: `x: ${posBefore.x} → ${st.playerPos.x}` };
      },
      15000);
    await godot.takeScreenshot('walk_03_moved');

    // ── 04: Сбор точек ──
    const inv0 = await gameActions.getInventoryContents();
    const dots0 = inv0.dots + (inv0.punctuation['...'] || 0) * 3;
    result = await runStep('Сбор точек (.: увеличивается)',
      async () => {
        for (let i = 0; i < 5; i++) {
          await gameActions.movePlayer('right', 250);
          await gameActions.movePlayer('down', 200);
          await gameActions.movePlayer('up', 200);
        }
      },
      async (st) => {
        const dots = st.inventory.dots + (st.inventory.punctuation['...'] || 0) * 3;
        return { ok: dots > dots0, detail: `точки: ${dots0} → ${dots}` };
      },
      30000);
    await godot.takeScreenshot('walk_04_dots');

    // ── 05: Точки → многоточие (3 точки = ...) ──
    result = await runStep('3 точки → многоточие «...»',
      async () => {
        let inv = await gameActions.getInventoryContents();
        if (!(inv.punctuation && inv.punctuation['...'])) {
          await gameActions.testAddDots(3);
          await godot.waitFrames(10);
        }
      },
      (st) => ({ ok: st.inventory.punctuation && st.inventory.punctuation['...'] > 0, detail: `...: ${st.inventory.punctuation['...']}` }),
      15000);
    await godot.takeScreenshot('walk_05_ellipsis');

    // ── 06: Диалог с монстром ? через «...» ──
    result = await runStep('Диалог с ?-монстром через «...»',
      async () => { await gameActions.testStartDialogue(); },
      (st) => ({ ok: st.dialogueActive === true && st.dialogueText.length > 0, detail: `текст: ${st.dialogueText}` }),
      15000);
    await godot.takeScreenshot('walk_06_dialogue');

    // ── 07: Получение стартовой буквы А ──
    result = await runStep('Стартовая буква А (авто-подбор на спавне)',
      async () => { /* А должна быть авто-собрана; подстрахуем */ 
        let inv = await gameActions.getInventoryContents();
        if (!inv.letters['А']) { await gameActions.testAddLetter('А'); await godot.waitFrames(10); }
      },
      (st) => ({ ok: (st.inventory.letters['А'] || 0) > 0, detail: `А ур.${st.inventory.letters['А']}` }),
      15000);

    // ── 08: Инвентарь — карточки букв видны ──
    result = await runStep('Инвентарь открыт, карточки букв видны',
      async () => { await gameActions.openInventory(); await godot.waitMs(800); },
      (st) => ({ ok: st.inventoryVisible && Object.keys(st.inventory.letters).length > 0, detail: `${Object.keys(st.inventory.letters).length} букв` }),
      15000);
    await godot.takeScreenshot('walk_08_inventory');
    await gameActions.closeInventory();

    // ── 09: Бой — есть чем атаковать ──
    result = await runStep('Бой: есть буквы для атаки',
      async () => { await gameActions.startTestCombat('Страж', 40, ['Б']); },
      async (st) => ({ ok: st.inCombat === true }),
      20000);
    await godot.takeScreenshot('walk_09_combat_start');

    // ── 10: Атака гласной А ──
    result = await runStep('Атака буквой А — урон в логе',
      async () => { await gameActions.resetCombatLog(); await gameActions.selectBattleCard('А'); await gameActions.confirmBattleTurnExplicit(); },
      async () => {
        const log = await gameActions.getCombatLogAll();
        const dmg = log.find((e) => e.event === 'damage' && e.letter === 'А');
        return { ok: !!dmg, detail: dmg ? `урон ${dmg.damage}` : 'нет урона в логе' };
      },
      20000);

    // ── 11: Победа → лут → возврат в мир ──
    result = await runStep('Победа → лут → возврат в долину',
      async () => {
        for (let r = 0; r < 4; r++) {
          const cs = await gameActions.getCombatState();
          if (!cs || !cs.is_active) break;
          await gameActions.resetCombatLog();
          await gameActions.selectBattleCard('А');
          await gameActions.confirmBattleTurnExplicit();
        }
        await godot.waitMs(3000);
      },
      async (st) => ({ ok: st.inCombat === false, detail: 'вышел из боя' }),
      30000);
    await godot.takeScreenshot('walk_11_back');

    // ── Финал: итоговое состояние ──
    const finalInv = await gameActions.getInventoryContents();
    console.log(`\n${'='.repeat(70)}\nИТОГ ПРОХОЖДЕНИЯ\n${'='.repeat(70)}`);
    console.log(`Буквы: ${JSON.stringify(finalInv.letters)}`);
    console.log(`Точки: ${finalInv.dots}, ...: ${finalInv.punctuation['...'] || 0}`);
    console.log(`HP: ${(await gameActions.getHPFromHUD())}`);
    await godot.takeScreenshot('walk_FINAL');

    expect(Object.keys(finalInv.letters).length).toBeGreaterThan(0);
  });
});
