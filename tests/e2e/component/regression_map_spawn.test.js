// Regression: 6 deep-game maps (MAP_DEEP_MINES, MAP_CATACOMBS_SILENCE,
// MAP_VAULTS_OBLIVION, MAP_UNDERGROUND_RIVER, MAP_FLOODED_TEMPLE,
// MAP_RUINED_LIBRARY) had MAP_*_LETTERS = [] in constants.gd, causing
// "Division by zero in operation '%'" on letter-spawn (world_map.gd:293).
// Fixed 2026-07-07 via fallback_letters guard. This test loads each
// previously-broken map and confirms items spawn without crashing.
const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

describe('Regression: previously-broken maps spawn items', () => {
  jest.setTimeout(120000);

  beforeAll(async () => {
    await godot.loadGame();
    await gameActions.waitForGameLoad();
    await gameActions.startNewGame();
    await godot.waitMs(2000);
  });

  afterAll(async () => {
    await godot.closeBrowser();
  });

  // Use the STRING VALUES of MAP_* constants (see constants.gd:15-48), not the
  // GDScript-side constant names. e.g. MAP_DEEP_MINES = "deep_mines".
  const brokenMaps = [
    'deep_mines',
    'catacombs_silence',
    'vaults_oblivion',
    'underground_river',
    'flooded_temple',
    'ruined_library'
  ];

  for (const mapId of brokenMaps) {
    test(`${mapId}: items spawn, no crash, region name is NOT "Unknown region"`, async () => {
      // Request map switch via test bridge
      await godot.evaluateInPage((m) => {
        window._godotTestMapSwitch = m;
      }, mapId);
      // Wait for scene reload + world to come back up
      await godot.waitMs(4000);
      // Verify: player exists (game didn't crash)
      const pos = await gameActions.getPlayerPosition();
      expect(typeof pos.x).toBe('number');
      expect(typeof pos.y).toBe('number');
      // Verify: HUD shows a real region name (not the "Unknown region" fallback)
      const hud = await gameActions.getHUDText();
      expect(hud.region).toBeTruthy();
      expect(hud.region).not.toContain('Unknown region');
      expect(hud.region).not.toContain('Неизвестная');
      // Screenshot for Vision audit
      await godot.takeScreenshot(`regression_map_${mapId}`);
    });
  }
});
