// Level 3 test: Dark Oaks with Знак and Звук — sorcerer's evil lieutenants.
const godot = require('./helpers/godot_page');
const gameActions = require('./helpers/game_actions');

const STEP_DIR = require('path').join(__dirname, '..', 'screenshots');
require('fs').mkdirSync(STEP_DIR, { recursive: true });

describe('Level 3: Dark Oaks — Знак and Звук', () => {
  jest.setTimeout(120000);

  beforeAll(async () => {
    await godot.loadGame();
    await gameActions.waitForGameLoad();
  });

  afterAll(async () => {
    await godot.closeBrowser();
  });

  test('01 switch to dark_oaks map', async () => {
    // Start new game with default hero (character select auto-confirms)
    await gameActions.startNewGame();
    await godot.waitMs(2000);
    // Switch to dark_oaks via test bridge
    await godot.evaluateInPage(() => {
      if (typeof window.gameTestGotoMap === 'function') {
        window.gameTestGotoMap('dark_oaks');
      }
    });
    await godot.waitMs(3000);
    const hud = await gameActions.getHUDText();
    console.log('L3 HUD region:', hud.region);
    await godot.takeScreenshot('l3_01_dark_oaks');
  });

  test('02 Знак and Звук are on the map', async () => {
    await godot.waitMs(1000);
    const monsters = await gameActions.getMonsterStates();
    const znak = monsters.find(m => m.id === 'znak');
    const zvuk = monsters.find(m => m.id === 'zvuk');
    console.log('L3 monsters:', monsters.length, 'znak:', !!znak, 'zvuk:', !!zvuk);
    if (znak) console.log('  Знак name:', znak.name, 'hp:', znak.hp, 'drawn:', znak.drawn);
    if (zvuk) console.log('  Звук name:', zvuk.name, 'hp:', zvuk.hp, 'drawn:', zvuk.drawn);
    expect(znak).toBeDefined();
    expect(zvuk).toBeDefined();
    expect(znak.name).toBe('Знак');
    expect(zvuk.name).toBe('Звук');
  });

  test('03 teleport near Знак and screenshot', async () => {
    // Read Знак's position and teleport the player close enough to see it on camera
    // but outside detection_radius (260) so combat doesn't trigger immediately
    const monsters = await gameActions.getMonsterStates();
    const znak = monsters.find(m => m.id === 'znak');
    if (znak && znak.position) {
      console.log('Знак position:', znak.position);
      const tx = znak.position.x - 180;
      const ty = znak.position.y;
      await godot.evaluateInPage(`window.gameTestTeleport(${tx}, ${ty})`);
      await godot.waitMs(1500);
      // If combat started, flee and try again from further
      if (await gameActions.isInCombat()) {
        await gameActions.fleeBattle();
        await godot.waitMs(2000);
        const tx2 = znak.position.x - 300;
        await godot.evaluateInPage(`window.gameTestTeleport(${tx2}, ${ty})`);
        await godot.waitMs(1500);
      }
    }
    await godot.takeScreenshot('l3_03_near_znak');
    const monsters2 = await gameActions.getMonsterStates();
    const znak2 = monsters2.find(m => m.id === 'znak');
    if (znak2) console.log('Знак dist from player after teleport:', znak2.position);
  });

  test('04 fight Знак via autobattle', async () => {
    // Give the player strong letters to win the fight
    await gameActions.testAddLetter('А');
    await gameActions.testAddLetter('Е');
    await gameActions.testAddLetter('О');
    await godot.waitMs(300);
    // Keep approaching and engage
    let engaged = false;
    for (let i = 0; i < 8; i++) {
      if (await gameActions.isInCombat()) { engaged = true; break; }
      await gameActions.movePlayer('right', 400);
      await godot.waitMs(200);
    }
    if (engaged) {
      console.log('L3: In combat with Знак/Звук!');
      // Enable autobattle
      await godot.evaluateInPage(() => {
        if (typeof window.gameAutoBattle === 'function') window.gameAutoBattle();
      });
      await godot.waitMs(8000);
      await godot.takeScreenshot('l3_04_combat');
    } else {
      console.log('L3: Could not reach enemy in time, taking distant screenshot');
      await godot.takeScreenshot('l3_04_distant');
    }
  });

  test('05 final state', async () => {
    if (await gameActions.isInCombat()) {
      await gameActions.fleeBattle();
      await godot.waitMs(2000);
    }
    const monsters = await gameActions.getMonsterStates();
    console.log('L3 final monsters:', monsters.map(m => ({ id: m.id, name: m.name, state: m.state })));
    await godot.takeScreenshot('l3_05_final');
  });
});
