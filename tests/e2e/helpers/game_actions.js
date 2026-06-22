const godot = require('./godot_page');

async function movePlayer(direction, distanceMs = 500) {
  const keyMap = { up: 'KeyW', down: 'KeyS', left: 'KeyA', right: 'KeyD' };
  const key = keyMap[direction];
  if (!key) throw new Error('Invalid direction: ' + direction);
  await godot.holdKey(key, distanceMs);
}

async function movePlayerTo(x, y) {
  const currentPos = await getPlayerPosition();
  const dx = x - currentPos.x;
  const dy = y - currentPos.y;
  if (dx > 0) await godot.holdKey('KeyD', Math.min(Math.abs(dx) * 2, 3000));
  if (dx < 0) await godot.holdKey('KeyA', Math.min(Math.abs(dx) * 2, 3000));
  if (dy > 0) await godot.holdKey('KeyS', Math.min(Math.abs(dy) * 2, 3000));
  if (dy < 0) await godot.holdKey('KeyW', Math.min(Math.abs(dy) * 2, 3000));
}

async function getPlayerPosition() {
  return await godot.evaluateInPage(() => {
    if (typeof window.gamePlayerPos !== 'undefined') {
      return window.gamePlayerPos;
    }
    return { x: 960, y: 640 };
  });
}

async function interact() {
  await godot.pressKey('KeyE', 100);
}

async function openInventory() {
  await godot.pressKey('KeyI', 100);
  await godot.waitFrames(10);
}

async function closeInventory() {
  await godot.pressKey('KeyI', 100);
  await godot.waitFrames(10);
}

async function openDialogue() {
  await godot.evaluateInPage(() => {
    if (typeof window.gameTriggerDialogue === 'function') {
      window.gameTriggerDialogue();
    }
  });
  await godot.waitFrames(10);
}

async function getInventoryContents() {
  return await godot.evaluateInPage(() => {
    return window.gameInventory || { letters: {}, dots: 0, punctuation: {} };
  });
}

async function getHUDText() {
  return await godot.evaluateInPage(() => {
    return window.gameHUD || { hp: '', dots: '', region: '' };
  });
}

async function getHPFromHUD() {
  const hud = await getHUDText();
  return hud.hp;
}

async function getDotsFromHUD() {
  const hud = await getHUDText();
  return hud.dots;
}

async function isMenuVisible() {
  return await godot.evaluateInPage(() => {
    return window.gameMenuVisible || false;
  });
}

async function startNewGame() {
  await godot.clickButton('Новая игра');
  await godot.waitFrames(30);
  // Character select screen — confirm default hero (index 0)
  await godot.waitForCondition(async () => {
    return await godot.evaluateInPage(() => !!(window.gameCharSelectLoaded));
  }, 10000);
  await godot.evaluateInPage(() => {
    if (typeof window.gameConfirmHero === 'function') window.gameConfirmHero();
  });
  await godot.waitFrames(40);
}

async function selectHeroByIndex(i) {
  await godot.evaluateInPage((idx) => {
    if (typeof window.gameSelectHeroByIndex === 'function') window.gameSelectHeroByIndex(idx);
  }, i);
  await godot.waitFrames(10);
}

async function confirmHero() {
  await godot.evaluateInPage(() => {
    if (typeof window.gameConfirmHero === 'function') window.gameConfirmHero();
  });
  await godot.waitFrames(40);
}

async function getHeroCount() {
  return await godot.evaluateInPage(() => window.gameHeroCount || 0);
}

async function waitForGameLoad() {
  await godot.waitForCondition(async () => {
    return await godot.evaluateInPage(() => {
      return typeof window.gameLoaded !== 'undefined' && window.gameLoaded;
    });
  }, 15000);
}

async function getDialogueText() {
  return await godot.evaluateInPage(() => {
    return window.gameDialogueText || '';
  });
}

async function advanceDialogue() {
  await godot.evaluateInPage(() => {
    if (typeof window.gameAdvanceDialogue === 'function') window.gameAdvanceDialogue();
  });
  await godot.waitFrames(10);
}

async function isDialogueActive() {
  return await godot.evaluateInPage(() => {
    return window.gameDialogueActive || false;
  });
}

async function isInCombat() {
  return await godot.evaluateInPage(() => {
    return window.gameInCombat || false;
  });
}

async function selectBattleCard(letter) {
  await godot.evaluateInPage((l) => {
    if (typeof window.gameSelectCard === 'function') {
      window.gameSelectCard(l);
    }
  }, letter);
  await godot.waitFrames(5);
}

async function confirmBattleTurn() {
  await godot.pressKey('Space', 100);
  await godot.waitFrames(30);
}

async function collectNearbyDots(count = 1) {
  for (let i = 0; i < count; i++) {
    await interact();
    await movePlayer('right', 200);
    await movePlayer('left', 100);
    await godot.waitFrames(5);
  }
}

async function snapshot(label) {
  return await godot.debugCapture(label);
}

async function screenshot(label) {
  return await godot.takeScreenshot(label);
}

async function getAlphabet() {
  return await godot.evaluateInPage(() => {
    return window.gameAlphabet || [];
  });
}

async function startTestCombat(name, hp, letters) {
  await godot.evaluateInPage((n, h, l) => {
    if (typeof window.gameStartTestCombat === 'function') {
      window.gameStartTestCombat(n, h, l);
    }
  }, name, hp, letters);
  await godot.waitFrames(10);
}

async function testAddLetter(letter) {
  await godot.evaluateInPage((l) => {
    if (typeof window.gameTestAddLetter === 'function') {
      window.gameTestAddLetter(l);
    }
  }, letter);
  await godot.waitFrames(5);
}

async function testAddDots(count) {
  await godot.evaluateInPage((c) => {
    if (typeof window.gameTestAddDots === 'function') {
      window.gameTestAddDots(c);
    }
  }, count);
  await godot.waitFrames(5);
}

async function testStartDialogue() {
  await godot.evaluateInPage(() => {
    if (typeof window.gameTestStartDialogue === 'function') {
      window.gameTestStartDialogue();
    }
  });
  await godot.waitFrames(15);
}

async function resetCombatLog() {
  await godot.evaluateInPage(() => {
    if (typeof window.gameResetCombatLog === 'function') {
      window.gameResetCombatLog();
    }
  });
}

async function confirmBattleTurnExplicit() {
  await godot.evaluateInPage(() => {
    if (typeof window.gameConfirmTurn === 'function') {
      window.gameConfirmTurn();
    }
  });
  await godot.waitFrames(40);
}

async function fleeBattle() {
  await godot.evaluateInPage(() => {
    if (typeof window.gameFleeBattle === 'function') {
      window.gameFleeBattle();
    }
  });
  await godot.waitFrames(20);
}

async function getCombatLogAll() {
  return await godot.evaluateInPage(() => {
    return window.gameCombatLogAll || [];
  });
}

async function getCombatState() {
  return await godot.evaluateInPage(() => {
    return window.gameCombatState || null;
  });
}

async function getBattleMessages() {
  return await godot.evaluateInPage(() => {
    return window.gameBattleMessages || [];
  });
}

async function getCombatTurnOrder() {
  return await godot.evaluateInPage(() => {
    return window.gameCombatTurnOrder || null;
  });
}

async function getMonsterStates() {
  return await godot.evaluateInPage(() => {
    return window.gameMonsterStates || [];
  });
}

async function getSpells() {
  return await godot.evaluateInPage(() => window.gameSpells || []);
}

async function unlockSpell(word) {
  await godot.evaluateInPage((w) => {
    if (typeof window.gameUnlockSpell === 'function') window.gameUnlockSpell(w);
  }, word);
  await godot.waitFrames(10);
}

async function castBattleSpell(word) {
  await godot.evaluateInPage((w) => {
    if (typeof window.gameCastSpell === 'function') window.gameCastSpell(w);
  }, word);
  await godot.waitFrames(5);
}

async function waitForCombat(timeout = 15000) {
  return await godot.waitForCondition(async () => {
    const c = await getCombatState();
    return c && c.is_active === true;
  }, timeout);
}

async function waitForWorld(timeout = 15000) {
  return await godot.waitForCondition(async () => {
    const inCombat = await isInCombat();
    return inCombat === false;
  }, timeout);
}

async function getCombatTimer() {
  return await godot.evaluateInPage(() => {
    return window.gameTurnTimer || 0;
  });
}

async function waitForCombatEnd(timeout = 30000) {
  return await godot.waitForCondition(async () => {
    const c = await getCombatState();
    return !c || c.is_active === false;
  }, timeout);
}

module.exports = {
  movePlayer,
  movePlayerTo,
  getPlayerPosition,
  interact,
  openInventory,
  closeInventory,
  openDialogue,
  getInventoryContents,
  getHUDText,
  getHPFromHUD,
  getDotsFromHUD,
  isMenuVisible,
  startNewGame,
  selectHeroByIndex,
  confirmHero,
  getHeroCount,
  waitForGameLoad,
  getDialogueText,
  advanceDialogue,
  isDialogueActive,
  isInCombat,
  selectBattleCard,
  confirmBattleTurn,
  collectNearbyDots,
  snapshot,
  screenshot,
  getAlphabet,
  startTestCombat,
  testAddLetter,
  testAddDots,
  testStartDialogue,
  resetCombatLog,
  confirmBattleTurnExplicit,
  fleeBattle,
  getCombatLogAll,
  getCombatState,
  getBattleMessages,
  getCombatTurnOrder,
  getMonsterStates,
  getSpells,
  unlockSpell,
  castBattleSpell,
  waitForCombat,
  waitForWorld,
  getCombatTimer,
  waitForCombatEnd
};
