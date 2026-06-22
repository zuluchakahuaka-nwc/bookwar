const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

async function openCharSelect() {
  await godot.clickButton('Новая игра');
  await godot.waitForCondition(async () => {
    return await godot.evaluateInPage(() => !!(window.gameCharSelectLoaded));
  }, 10000);
  await godot.waitFrames(10);
}

async function selectConfirmAndRead(idx) {
  await gameActions.selectHeroByIndex(idx);
  await godot.waitFrames(15);
  const selectedName = await godot.evaluateInPage(() => window.gameSelectedHeroName);
  await gameActions.confirmHero();
  await godot.waitMs(3000);
  const appliedName = await godot.evaluateInPage(() => window.gameAppliedHeroName || '');
  const appliedShirt = await godot.evaluateInPage(() => window.gameAppliedShirt || '');
  return { selectedName, appliedName, appliedShirt };
}

describe('Hero Identity Persistence', () => {
  afterEach(async () => {
    await godot.closeBrowser();
  });

  test('hero 0 (default) — applied matches selection', async () => {
    await godot.loadGame();
    await gameActions.waitForGameLoad();
    await openCharSelect();
    const r = await selectConfirmAndRead(0);
    console.log('  idx=0  Selected:', r.selectedName, '| Applied:', r.appliedName, '| Shirt:', r.appliedShirt);
    expect(r.appliedName).toBe(r.selectedName);
    expect(r.appliedName.length).toBeGreaterThan(0);
  }, 60000);

  test('hero 7 — applied matches selection', async () => {
    await godot.loadGame();
    await gameActions.waitForGameLoad();
    await openCharSelect();
    const r = await selectConfirmAndRead(7);
    console.log('  idx=7  Selected:', r.selectedName, '| Applied:', r.appliedName, '| Shirt:', r.appliedShirt);
    expect(r.appliedName).toBe(r.selectedName);
    expect(r.appliedName.length).toBeGreaterThan(0);
  }, 60000);

  test('hero 30 — applied matches selection', async () => {
    await godot.loadGame();
    await gameActions.waitForGameLoad();
    await openCharSelect();
    const r = await selectConfirmAndRead(30);
    console.log('  idx=30 Selected:', r.selectedName, '| Applied:', r.appliedName, '| Shirt:', r.appliedShirt);
    expect(r.appliedName).toBe(r.selectedName);
    expect(r.appliedName.length).toBeGreaterThan(0);
  }, 60000);

  test('hero 49 (last) — applied matches selection', async () => {
    await godot.loadGame();
    await gameActions.waitForGameLoad();
    await openCharSelect();
    const r = await selectConfirmAndRead(49);
    console.log('  idx=49 Selected:', r.selectedName, '| Applied:', r.appliedName, '| Shirt:', r.appliedShirt);
    expect(r.appliedName).toBe(r.selectedName);
    expect(r.appliedName.length).toBeGreaterThan(0);
  }, 60000);

  test('different heroes have different shirt colors', async () => {
    await godot.loadGame();
    await gameActions.waitForGameLoad();
    await openCharSelect();
    const r0 = await selectConfirmAndRead(0);
    await godot.closeBrowser();

    await godot.loadGame();
    await gameActions.waitForGameLoad();
    await openCharSelect();
    const r40 = await selectConfirmAndRead(40);

    console.log('  hero0 shirt:', r0.appliedShirt, '| hero40 shirt:', r40.appliedShirt);
    expect(r0.appliedShirt).not.toBe(r40.appliedShirt);
    expect(r0.appliedShirt.length).toBeGreaterThan(0);
    expect(r40.appliedShirt.length).toBeGreaterThan(0);
  }, 90000);
});
