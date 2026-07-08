# DEVLOG — Журнал разработки BOOKWAR

> Живая хроника. Каждая запись — отдельная завершённая задача с датой, файлами и результатом.
> Обновляется по мере работы. Для контекста проекта читай AGENTS.md.

---

## 2026-07-08 — RPG-система + баланс + контент

### Базовая подготовка
- ✅ Backup git tag `pre-quests-baseline`
- ✅ Cleanup 321 МБ скриншотов (AGENTS.md §0.12)
- ✅ Автобот `walkthrough33_bot.js` — 33 карты за 41с

### Bug fixes
- ✅ **B-QUEST-1**: TestBridge race condition — после 6+ подряд scene changes Godot терял
  bridge state. Фикс: `INITIAL_BRIDGE_JS` в `test_bridge.gd` не перезаписывает
  существующие `window.gameHUD` и др. bridges при re-init. Результат: 33/33 карт стабильно грузятся.

### Квестовая система (Q1-Q6, AGENTS.md §18.3)
- ✅ **Q1**: 5 типов квестов (defeat/collect/buy/trade/talk) через `data/quests.json`
  и `scripts/core/quest_data.gd` autoload
- ✅ **Q2**: Прогрессия N-2 — карты 1-2 без квестов (обучение), карта N≥3 имеет N-2 квеста
- ✅ **Q3**: Журнал квестов `scripts/ui/quest_log.gd` (Q-key + touch button)
  с прогрессом N/M и зелёной подсветкой готовых к сдаче
- ✅ **Q4**: NPC auto-hand-in — диалог с `?` монстром автоматически сдаёт выполнимые квесты
- ✅ **Q5**: Динамическая ширина карт 80→112 (`BookwarConst.get_map_width`)
- ✅ **Q6**: Lore-описания для всех 33 регионов (`REGION_LORE` Dictionary)

### Visual polish
- ✅ NPC маркеры «!»/«?» над головами `?` монстров (жёлтые/зелёные)
- ✅ Toast фидбек прогресса «⚔ 1/3», «📦 2/2»
- ✅ HUD lore-строка под именем региона + touch кнопка «Квесты [Q]»

### §20 Инверсия баланса (AGENTS.md §20)
- ✅ `data/letters.json` — все 33 буквы: `base_power = position` (А=1 слабая, Я=33 сильная)
- ✅ Старая схема `34-position` устарела. Late-alphabet буквы (Ю Э Я Ъ Ы Ь) теперь мощные.
- ✅ `regression_balance.test.js` — 6 тестов проверяют все 33 буквы

### §18.5 Named creatures (AGENTS.md §18.5)
- ✅ 4 новых существа через Polygon2D:
  - Карта 2: Длинноязыкий — длинный красный язык
  - Карта 3: Слушач — огромные уши (2× голова)
  - Карта 4: Зрячий — гигантские жёлтые глаза
  - Карта 5: Жор — огромный рот с зубами
- ✅ `monster_spawner.gd::_enemy_pool_for_level` возвращает named creature для карт 2-5

### Storyline контент
- ✅ **59 ручных сюжетных квестов** для карт 3-33 (каждый регион имеет минимум 1 квест):
  - Карты 3-5: dark_oaks, mossy_lowlands, rotten_swamps (6 квестов)
  - Карты 6-10: swamp_lights → dark_cathedral (13 квестов)
  - Карты 11-20: forgotten_ruins → underground_river (18 квестов)
  - Карты 21-33: flooded_temple → well_of_letters FINALE (22 квеста)
- ✅ Уникальные NPC: Огонник, Каменяр, Падший Жрец, Гном-Кузнец, Чёрный Лодочник,
  Лейтенанты Знак/Звук, Хранитель Запрета, Дух Алфавита, и др.

### Save/Load
- ✅ `save_manager.gd` — persist `completed_quest_ids`, `quest_defeat_progress`, `completed_quests`
- ✅ `main_menu.gd::_on_continue` + новый JS bridge `gameClickContinue`
- ✅ `regression_save.test.js` — квест переживает reload браузера через Continue

### Тестирование
- ✅ `regression_smoke` (8), `regression_data` (6), `regression_combat` (4),
  `regression_balance` (6), `regression_quests` (6), `regression_portal` (5),
  `regression_save` (1) — **36 тестов всего**, все проходят индивидуально.
- ⚠️ Параллельные запуски иногда падают на loading 112MB index.pck — не баг игры,
  артефакт puppeteer. Решение: `--runInBand`.

### Коммиты (11 штук)
`a92752c` → `8baf122` → `7f543dd` → `b6b5fff` → `e96ce2d` → `6b7b504` →
`a92d2f5` → `39ce0ae` → `66295a6` → `80c6e29` → `10b3d51`

### Что осталось (после 2026-07-08)
- [ ] §16 Кузнец Слов как полноценный NPC (крафт через диалог)
- [x] **Progress bar % зачистки в HUD** — `hud_ui.gd::_build_progress_bar` (2026-07-08)
- [ ] Statistics screen (букв собрано, квестов выполнено)
- [ ] Decorative terrain (камни/деревья на карте)
- [ ] Мультиплеер (Этап 6 — WebSocket сервер)
- [ ] Android-версия (ANDROID_VERSION подпроект)
- [ ] Localisation (en/es/de/ar/zh — AGENTS.md §2.0)

---

## 2026-07-08 (продолжение) — Progress bar HUD

### Что сделано
- ✅ **Progress bar % зачистки** в HUD внизу слева (под lore-описанием)
  - `hud_ui.gd::_build_progress_bar` — ColorRect-based bar (фон + fill)
  - `hud_ui.gd::_process` — poll `window.gameLevelProgress` ~3 раза/сек
  - Цвет: зелёный <50%, жёлтый 50-99%, голубой 100%
  - Текст справа: «45%  (до портала 5%)» / «73%  ⟶ портал открыт!» / «100%  ✓ зачищено»

### Технические детали
- `world_map._level_progress()` уже считает composite прогресс (монстры + предметы)
- `window.gameLevelProgress` уже обновлялся в `_check_victory` — теперь HUD его читает

### Тесты
- `snap_progress.js` — start: 32% (предметы собраны при спавне), after clearRegion: 73% (монстры нейтрализованы, остались предметы)
- Vision подтвердил: bar жёлтый, текст «73% ⟶ портал открыт!» виден

---

## Шаблон записи

```
## YYYY-MM-DD — Краткое название

### Что сделано
- ✅ **Задача**: файлы, эффект

### Технические детали
- Имя функции / константы / структуры данных

### Тесты
- Имя файла теста, сколько asserts

### Коммит(ы)
- `хэш` — краткое описание
```
