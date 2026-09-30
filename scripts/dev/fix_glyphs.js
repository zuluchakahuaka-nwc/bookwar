// One-shot: replace broken glyphs in 4 GDScript files (safe string ops).
'use strict';
const fs = require('fs');
const path = require('path');
const ROOT = path.join(__dirname, '..', '..');

const jobs = [
  ['scripts/world/world_map.gd', [
    ['emit("📜 " + qdesc)', 'emit("» " + qdesc)'],
  ]],
  ['scripts/combat/battle_manager.gd', [
    ['clear_btn.text = "✕ Очистить слоты"', 'clear_btn.text = "× Очистить слоты"'],
  ]],
  ['scripts/multiplayer/chat_overlay.gd', [
    ['_send_btn.text = "→"', '_send_btn.text = "›"'],
  ]],
  ['scripts/ui/quest_log.gd', [
    ['"questlog.can_hand_in", "✓ Можно сдать у NPC"', '"questlog.can_hand_in", "• Можно сдать у NPC"'],
  ]],
];

for (const [rel, pairs] of jobs) {
  const p = path.join(ROOT, rel);
  let c = fs.readFileSync(p, 'utf8');
  for (const [a, b] of pairs) {
    if (!c.includes(a)) { console.log('MISS:', rel, '«' + a.slice(0, 40) + '»'); continue; }
    c = c.split(a).join(b);
    console.log('OK:', rel, '->', b.slice(0, 44));
  }
  fs.writeFileSync(p, c);
}

// Verify: no bad glyphs in non-comment lines of any .gd
function walk(d) {
  let r = [];
  for (const f of fs.readdirSync(d)) {
    const p = path.join(d, f);
    const s = fs.statSync(p);
    if (s.isDirectory()) { if (!f.includes('_salvaged')) r = r.concat(walk(p)); }
    else if (f.endsWith('.gd')) r.push(p);
  }
  return r;
}
const BAD = /[⟶★✓✕📜←→]/;
let bad = 0;
for (const p of walk(path.join(ROOT, 'scripts'))) {
  const lines = fs.readFileSync(p, 'utf8').split('\n');
  lines.forEach((l, i) => {
    const t = l.trim();
    if (BAD.test(t) && !t.startsWith('#')) { bad++; console.log('STILL:', p + ':' + (i + 1), t.slice(0, 70)); }
  });
}
console.log('bad in code strings:', bad);
