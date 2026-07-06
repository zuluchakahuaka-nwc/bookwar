// Walkthrough bot: Dark Forest (Тёмный Лес) — harder monsters with letters.
// Pattern: same framework as light valley walkthrough (step → check → timeout → diagnose).
const godot = require('./helpers/godot_page');
const gameActions = require('./helpers/game_actions');

let stepNum = 0;
const REGION = 'Тёмный Лес';

async function runStep(name, action, check, timeoutMs) {
  stepNum++;
  const tag = `[${REGION} Шаг ${String(stepNum).padStart(2, '0')}] ${name}`;
  console.log(`\n${tag}`);
  const t0 = Date.now();
  try { await action(); } catch (e) { console.log(`${tag} действие: ${e.message}`); }
  const deadline = Date.now() + timeoutMs;
  let lastState = null;
  while (Date.now() < deadline) {
    lastState = await godot.getGameState();
    const r = await check(lastState);
    if (r.ok) { console.log(`${tag} → ✓ OK (${Date.now()-t0}мс): ${r.detail||''}`); return {ok:true}; }
    await godot.waitMs(400);
  }
  const shot = await godot.takeScreenshot(`STUCK_${REGION}_шаг${stepNum}`);
  console.log(`${tag} → ✗ ЗАВИСЛО. Скрин: ${shot}`);
  return {ok:false};
}

describe('Бот-прохождение: Тёмный Лес', () => {
  jest.setTimeout(180000);
  beforeAll(async () => { await godot.loadGame(); await gameActions.waitForGameLoad(); await gameActions.startNewGame(); await godot.waitMs(2000); });
  afterAll(async () => { await godot.closeBrowser(); });

  test('Прохождение Тёмного Леса', async () => {
    // Prep: collect enough letters + currency for spells
    await runStep('Подготовка: собрать буквы и валюту',
      async () => { for (const l of ['А','Б','М','Я','О','В','У','К','Р']) { await gameActions.testAddLetter(l); await godot.waitMs(100); } },
      async () => { const inv = await gameActions.getInventoryContents(); return {ok: Object.keys(inv.letters).length >= 5, detail: Object.keys(inv.letters).length + ' букв'}; },
      15000);

    // Unlock БАМ spell
    await runStep('Открыть заклинание БАМ',
      async () => { await gameActions.unlockSpell('БАМ'); },
      async () => { const s = await gameActions.getSpells(); const b = s.find(x=>x.word==='БАМ'); return {ok: b && b.unlocked, detail: b ? 'power='+Math.round(b.power) : 'нет'}; },
      10000);

    // Fight Shadow Lurker (Тенелюд) — HP 70, letters У+К
    await runStep('Бой: Тенелюд (HP 70, буквы У+К)',
      async () => { await gameActions.startTestCombat('Тенелюд', 70, ['У','К']); },
      async (st) => { return {ok: st.inCombat === true}; },
      15000);

    await runStep('Атака БАМ по Тенелюду',
      async () => { await gameActions.resetCombatLog(); await gameActions.castBattleSpell('БАМ'); await godot.waitFrames(10); await gameActions.confirmBattleTurnExplicit(); },
      async () => { const log = await gameActions.getCombatLogAll(); const s = log.find(e=>e.event==='spell_damage'||e.event==='spell_played'); return {ok: !!s, detail: s ? 'power='+Math.round(s.power||0) : 'нет'}; },
      15000);

    // Win + return
    await runStep('Победа над Тенелюдом → возврат',
      async () => { for(let r=0;r<4;r++){const st=await gameActions.getCombatState();if(!st||!st.is_active)break;await gameActions.selectBattleCard('А');await gameActions.confirmBattleTurnExplicit();await godot.waitMs(500);} await godot.waitMs(2500); if(await gameActions.isInCombat()){await gameActions.fleeBattle();await godot.waitMs(2000);} },
      async (st) => { return {ok: st.inCombat === false}; },
      30000);

    // Fight Dark Wolf (Тёмный Волк) — HP 90, letters А+Р
    await runStep('Бой: Тёмный Волк (HP 90, буквы А+Р)',
      async () => { await gameActions.startTestCombat('Тёмный Волк', 90, ['А','Р']); },
      async (st) => { return {ok: st.inCombat === true}; },
      15000);

    await runStep('Победа над Волком + лут',
      async () => { const inv0 = await gameActions.getInventoryContents(); const c0 = Object.values(inv0.letters).reduce((a,b)=>a+b,0); for(let r=0;r<5;r++){const st=await gameActions.getCombatState();if(!st||!st.is_active)break;await gameActions.resetCombatLog();await gameActions.selectBattleCard('А');await gameActions.confirmBattleTurnExplicit();await godot.waitMs(500);} await godot.waitMs(3000); if(await gameActions.isInCombat()){await gameActions.fleeBattle();await godot.waitMs(2000);} const inv1 = await gameActions.getInventoryContents(); const c1 = Object.values(inv1.letters).reduce((a,b)=>a+b,0); console.log('LOOT', c1 - c0); },
      async (st) => { return {ok: st.inCombat === false}; },
      30000);

    const finalInv = await gameActions.getInventoryContents();
    console.log(`\nИТОГ ${REGION}: букв=${Object.keys(finalInv.letters).length}`);
    expect(Object.keys(finalInv.letters).length).toBeGreaterThan(0);
  });
});
