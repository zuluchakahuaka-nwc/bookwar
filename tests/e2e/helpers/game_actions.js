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
  await godot.pressKey('Space', 100);
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
  waitForGameLoad,
  getDialogueText,
  advanceDialogue,
  isDialogueActive,
  isInCombat,
  selectBattleCard,
  confirmBattleTurn,
  collectNearbyDots,
  snapshot,
  screenshot
};
