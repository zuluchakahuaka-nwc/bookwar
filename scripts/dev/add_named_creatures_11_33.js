// Add 7 new named creatures to data/monsters.json
// Run: node scripts/dev/add_named_creatures_11_33.js
const fs = require('fs');
const path = 'D:/Projects/BOOKWAR/data/monsters.json';

const NEW_CREATURES = [
  {
    id: 'mist_weaver', name: 'Туманный Ткач', symbol: 'mw',
    hp: 170, behavior: 'aggressive', detection_radius: 220, attack_radius: 80, speed: 55,
    letters: ['Т', 'М'], punctuation: [], draw_type: 'mist_weaver', draw: true,
    drop_table: [
      { item: 'letter', chance: 0.85, count: 1 },
      { item: 'dot', chance: 0.75, count: 4 }
    ],
    dialogue_options: [
      { text: 'Туман скрывает правду. Я плету твои страхи.', result: 'slow' },
      { text: 'Каждый вдох — ложь. Уходи, пока дышишь.', result: 'slow' }
    ]
  },
  {
    id: 'grey_stalker', name: 'Серый Сталкер', symbol: 'gs',
    hp: 190, behavior: 'aggressive', detection_radius: 260, attack_radius: 85, speed: 75,
    letters: ['С', 'Р'], punctuation: [], draw_type: 'grey_stalker', draw: true,
    drop_table: [
      { item: 'letter', chance: 0.85, count: 1 },
      { item: 'dot', chance: 0.7, count: 4 }
    ],
    dialogue_options: [
      { text: 'Я вижу тебя сквозь серость. Беги — догоню.', result: 'slow' },
      { text: 'Лес молчит, потому что я его голос.', result: 'slow' }
    ]
  },
  {
    id: 'frost_biter', name: 'Ледяной Кусака', symbol: 'fb',
    hp: 210, behavior: 'aggressive', detection_radius: 200, attack_radius: 90, speed: 50,
    letters: ['З', 'Л'], punctuation: [], draw_type: 'frost_biter', draw: true,
    drop_table: [
      { item: 'letter', chance: 0.9, count: 1 },
      { item: 'dot', chance: 0.8, count: 5 }
    ],
    dialogue_options: [
      { text: 'Мой укус заморозит даже твоё имя.', result: 'slow' },
      { text: 'Слова замерзают на твоих губах.', result: 'slow' }
    ]
  },
  {
    id: 'bridge_keeper', name: 'Страж Моста', symbol: 'bk',
    hp: 240, behavior: 'aggressive', detection_radius: 240, attack_radius: 95, speed: 55,
    letters: ['Б', 'Р', 'М'], punctuation: [], draw_type: 'bridge_keeper', draw: true,
    drop_table: [
      { item: 'letter', chance: 0.95, count: 2 },
      { item: 'dot', chance: 0.85, count: 5 }
    ],
    dialogue_options: [
      { text: 'Через этот мост не проходят дважды.', result: 'slow' },
      { text: 'Я смотрю двумя лицами — назад и вперёд.', result: 'slow' }
    ]
  },
  {
    id: 'village_ghoul', name: 'Деревенский Гуль', symbol: 'vg',
    hp: 260, behavior: 'aggressive', detection_radius: 230, attack_radius: 100, speed: 65,
    letters: ['В', 'Г', 'Д'], punctuation: [], draw_type: 'village_ghoul', draw: true,
    drop_table: [
      { item: 'letter', chance: 0.9, count: 2 },
      { item: 'dot', chance: 0.8, count: 6 }
    ],
    dialogue_options: [
      { text: 'Я помню имена всех, кто здесь жил.', result: 'slow' },
      { text: 'Голод вечен. Буквы — лишь приправа.', result: 'slow' }
    ]
  },
  {
    id: 'citadel_commander', name: 'Командир Цитадели', symbol: 'cc',
    hp: 290, behavior: 'aggressive', detection_radius: 250, attack_radius: 100, speed: 60,
    letters: ['К', 'Ц', 'Т', 'Р'], punctuation: [], draw_type: 'citadel_commander', draw: true,
    drop_table: [
      { item: 'letter', chance: 0.95, count: 2 },
      { item: 'dot', chance: 0.85, count: 6 }
    ],
    dialogue_options: [
      { text: 'Мои солдаты пали, но я держу строй.', result: 'slow' },
      { text: 'Буквы — враги порядка. Я — порядок.', result: 'slow' }
    ]
  },
  {
    id: 'ban_inquisitor', name: 'Инквизитор Запрета', symbol: 'bi',
    hp: 330, behavior: 'aggressive', detection_radius: 280, attack_radius: 105, speed: 60,
    letters: ['З', 'П', 'Р', 'Б'], punctuation: [], draw_type: 'ban_inquisitor', draw: true,
    drop_table: [
      { item: 'letter', chance: 1.0, count: 2 },
      { item: 'dot', chance: 0.9, count: 7 }
    ],
    dialogue_options: [
      { text: 'Каждое слово — ересь. Каждый шёпот — приговор.', result: 'slow' },
      { text: 'Палаты Запрета помнят твоё имя. Я забрал его.', result: 'slow' }
    ]
  }
];

const j = JSON.parse(fs.readFileSync(path, 'utf8'));
const existingIds = new Set(j.monsters.map(m => m.id));
let added = 0;
for (const c of NEW_CREATURES) {
  if (existingIds.has(c.id)) {
    console.log('SKIP (already exists):', c.id);
    continue;
  }
  j.monsters.push(c);
  added++;
}
fs.writeFileSync(path, JSON.stringify(j, null, 2) + '\n', 'utf8');
console.log('Added', added, 'new creatures. Total monsters:', j.monsters.length);
const named = j.monsters.filter(m => m.draw_type && !['znak', 'zvuk', 'wordsmith', 'merchant'].includes(m.draw_type));
console.log('Named creatures total:', named.length);
named.forEach(m => console.log('  -', m.id.padEnd(22), 'hp=' + m.hp));
