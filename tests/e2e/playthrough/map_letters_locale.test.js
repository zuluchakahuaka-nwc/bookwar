// e2e: map letter spawns are locale-aware (§2.0). Light Valley spawns the
// same position slots {1,14,16} in every locale's own alphabet:
// ru -> А,М,О (identity, regression guard) | hy -> Ա,Ծ,Հ.
const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

async function checkLocale(locale, mustHave) {
  await godot.loadGame();
  await gameActions.waitForGameLoad();
  await godot.getPage().evaluate((l) => window.gameSetLocale && window.gameSetLocale(l), locale);
  await godot.waitForCondition(
    () => godot.getPage().evaluate(() => window.gameLocale),
    10000, 300
  );
  await godot.waitMs(800); // AlphabetData reload via locale_changed
  await gameActions.startNewGame();
  await godot.waitForCondition(
    () => godot.getPage().evaluate(() => Array.isArray(window.gameMapLetterChars) && window.gameMapLetterChars.length > 0),
    30000, 400
  );
  const snap = await godot.getPage().evaluate(() => ({
    locale: window.gameLocale,
    chars: window.gameMapLetterChars,
    inventoryLetters: Object.keys((window.gameInventory || {}).letters || {}),
    alphabet: (window.gameAlphabet || []).map(a => a.char)
  }));
  // The first valley letter spawns ~20px from the player start — auto-pickup
  // grabs it instantly, so "spawned" = still-on-map ∪ already-collected.
  const spawned = [...new Set([...snap.chars, ...snap.inventoryLetters])].filter(c => snap.alphabet.includes(c));
  const allInAlphabet = snap.chars.every(c => snap.alphabet.includes(c));
  const hasMust = mustHave.every(c => spawned.includes(c));
  const ok = snap.locale === locale && allInAlphabet && hasMust && spawned.length >= 3;
  console.log(`${locale}: locale=${snap.locale} onMap=[${snap.chars.join(',')}] collected=[${snap.inventoryLetters.join(',')}] allInAlphabet=${allInAlphabet} mustHave=[${mustHave.join(',')}]present=${hasMust} ${ok ? 'OK' : 'FAIL'}`);
  await godot.closeBrowser();
  return ok;
}

(async () => {
  const ruOk = await checkLocale('ru', ['А', 'М', 'О']);
  const hyOk = await checkLocale('hy', ['Ա', 'Ծ', 'Հ']);
  process.exit(ruOk && hyOk ? 0 : 1);
})();
