// e2e: spells_<locale>.json loads per-locale (§16, §2.0). hy smoke + ru control.
// push_spell_snapshot() runs in world_map._ready, so we enter the world via the
// standard startNewGame flow after selecting the locale.
const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

async function checkLocale(locale) {
  await godot.loadGame();
  await gameActions.waitForGameLoad();
  await godot.getPage().evaluate((l) => window.gameSetLocale && window.gameSetLocale(l), locale);
  await godot.waitForCondition(
    () => godot.getPage().evaluate(() => window.gameLocale),
    10000, 300
  );
  await godot.waitMs(800); // SpellData reload via locale_changed signal
  await gameActions.startNewGame();
  await godot.waitForCondition(
    () => godot.getPage().evaluate(() => (window.gameSpells || []).length > 0),
    30000, 400
  );
  const snap = await godot.getPage().evaluate(() => ({
    locale: window.gameLocale,
    count: (window.gameSpells || []).length,
    words: (window.gameSpells || []).map(s => s.word),
    lettersOk: (window.gameSpells || []).every(s => (s.letters || []).every(l => (window.gameAlphabet || []).some(a => a.char === l)))
  }));
  const ok = snap.locale === locale && snap.count >= 8 && snap.lettersOk;
  console.log(`${locale}: locale=${snap.locale} count=${snap.count} words=${snap.words.join(',')} lettersInAlphabet=${snap.lettersOk} ${ok ? 'OK' : 'FAIL'}`);
  await godot.closeBrowser();
  return ok;
}

(async () => {
  const ruOk = await checkLocale('ru');
  const hyOk = await checkLocale('hy');
  process.exit(ruOk && hyOk ? 0 : 1);
})();
