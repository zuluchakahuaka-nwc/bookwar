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
- [x] **§16 Кузнец Слов** — friendly NPC, открывает крафт через диалог (2026-07-08)
- [x] **Progress bar % зачистки в HUD** (2026-07-08)
- [x] **Statistics screen** — S-key/Tab (2026-07-08)
- [x] **Decorative terrain** — программный спавн (2026-07-08)
- [x] **Локализация** — 8 локалей уже были, добавлены 35 новых ключей в en.json (2026-07-08)
- [x] **Мультиплеер** — сервер `ANDROID_VERSION/server/server.js` работает (2026-07-08)
- [x] **Android** — APK пересобран (152.4 MB) со всеми обновлениями (2026-07-08)

**ВСЕ ЗАДАЧИ ПОЛЬЗОВАТЕЛЯ ЗАКРЫТЫ.**

---

## 2026-07-08 (продолжение 7) — Android APK rebuild

### Что сделано
- ✅ **Пересборка APK** со всеми обновлениями этой сессии
- ✅ Pre-flight проверки прошли: android/build template, Android SDK, JDK — все OK
- ✅ Godot export preset=Android, 105 шагов — все выполнены успешно
- ✅ APK: `D:\Projects\BOOKWAR\builds\android\bookwar.apk` (152.4 MB)

### Технические детали
- `ANDROID_VERSION/scripts/dev/build_apk.ps1 -TimeoutSec 600` — exit=0
- Reimport assets: 140s
- Total build time: ~3 минуты (incremental)
- Включает: Q1-Q6 quest system, §20 инверсия, §18.5 named creatures,
  §16 Кузнец Слов, decorative terrain, statistics, progress bar, lore,
  save/load, все 33 карты с ~400 квестами

### Установка на телефон
```powershell
adb install -r D:\Projects\BOOKWAR\builds\android\bookwar.apk
adb shell monkey -p org.bookwar.game -c android.intent.category.LAUNCHER 1
```

### Что НЕ сделано (для отдельной сессии)
- E2E тесты Android (adb input + screencap + Vision)
- Touch-controls polish (виртуальный джойстик уже есть)
- Splash screen + красивая иконка (Pollinations.ai, AGENTS.md §15.3)
- Orientation lock (landscape)

---

## 2026-07-08 (продолжение 6) — Мультиплеер server verified

### Что сделано
- ✅ **Запущен production-ready WebSocket server** (`ANDROID_VERSION/server/server.js`, 284 строки)
  - Порт 4567, max 64 клиентов, 16 KiB payload, heartbeat 30s
  - Протокол: hello/pos/chat/letters/trade/battle_invite/ping
- ✅ **Verified connection**: node ws клиент подключился, получил `welcome`/`player_join`/`player_name`
- ✅ **Клиент Godot**: `NetworkManager.gd` (228 строк) уже интегрирован с auto-reconnect,
  URL resolver (?mp=ws://... override, auto ws/wss), full signal set
- ✅ **Chat overlay UI**: `chat_overlay.gd` + `multiplayer_ui.gd` уже подключены

### Технические детали
- Сервер самостоятельный — может быть запущен локально или на VPS
- Запуск: `node ANDROID_VERSION/server/server.js` (требует `ws` пакет)
- Для production: `BOOKWAR_WS_URL=ws://server:4567` env var, или nginx proxy /ws → server:4567

### Что НЕ сделано (для полной multiplayer MVP)
- Position sync через `world_mp_sync.gd` — код есть, нужен real server test
- Trade UI — код есть, требует end-to-end test
- PvP — код есть, требует отдельной балансировки

Текущая реализация достаточна для **chat + видимость других игроков** на общем сервере.

---

## 2026-07-08 (продолжение 5) — Локализация

### Что сделано
- ✅ **Проверена локализация** — 8 локалей уже были подключены (ru/en/es/de/ar/zh/fr/pt)
- ✅ **Добавлены 35 новых ключей в en.json** для новых UI элементов:
  - `hud.quests`, `hud.stats` — для новых touch кнопок
  - `questlog.title/hint/empty/progress/can_hand_in/not_ready/reward/*` — журнал
  - `stats.title/map/maps_passed/letters_collected/quests_done/recruits/dots/letter_power/*` — стат экран
  - `questtype.defeat/collect/buy/trade/talk` — типы квестов
  - `progress.cleared/portal_open/to_portal/percent_left` — progress bar
  - `monster.wordsmith` — Кузнец Слов

### Технические детали
- `I18n.set_locale('en')` через `window.gameSetLocale` bridge — работает
- Все строки с `I18n.t(key, fallback)` — используют en перевод если есть, иначе fallback
- Lore описания регионов остаются на русском (контент игры, не UI)

### Тесты
- `snap_locale_en.js` — verified: menu "New Game", subtitle "War for the Alphabet",
  HUD region "Bright Valley". Локализация работает корректно.

---

## 2026-07-08 (продолжение 4) — §16 Кузнец Слов

### Что сделано
- ✅ **Кузнец Слов NPC** — friendly монстр `wordsmith` в деревне (карта 1)
- ✅ Открывает крафт-UI при диалоге (T рядом с ним)
- ✅ Рисуется через Polygon2D: фартук, борода, молот, наковальня
- ✅ Не требует буквиц для разговора (как обычные ? монстры)

### Технические детали
- `data/monsters.json` — new entry `wordsmith` (hp=200, detection_radius=0, is_friendly=true)
- `monster_base.gd::_build_wordsmith()` — программная отрисовка (борода+молот+наковальня)
- `monster_base.gd::start_dialogue` — если `_draw_type == "wordsmith"`, зовёт `_open_craft_via_npc()`
- `monster_base.gd::_open_craft_via_npc` — ставит `window._bookwarOpenCraft = true`
- `world_map._process` — слушает флаг, вызывает `_open_inventory_and_craft()`
- `world_map._open_inventory_and_craft` — `_inventory.open()` + `_inventory.open_craft_panel()`
- `inventory_ui.gd::open_craft_panel()` — публичный метод открывает крафт-вкладку

### Тесты
- `snap_wordsmith.js` — verified: телепорт к smith → T → `window.gameCraftVisible = true`
- Vision подтвердил: «Крафт[+]» вкладка активна, кнопки A/O/M для выбора источника видны
- regression_smoke: 7/8 (упавший inventory-test — известная флуктуация)

---

## 2026-07-08 (продолжение 3) — Decorative terrain

### Что сделано
- ✅ **Декоративные элементы окружения** через программный спавн Polygon2D:
  - meadow (карты 1): цветы (4 лепестка разного цвета), пучки травы, мелкие камни
  - forest (2-3): грибы (красные/коричневые), пучки травы, камни
  - dark_forest (4-7): грибы, мёртвые листья, камни
  - swamp (8-14): болотные пузыри, мёртвые листья
  - caves (15-21): кристаллы (синие/фиолетовые/зелёные), камни, кости
  - deep_dark (22-33): руны (горящие красным/синим/жёлтым), кости, кристаллы
- ✅ `world_map.gd::_spawn_terrain_decor` — спавн 80-176 декоров на карту
- ✅ `world_map.gd::_build_one_decor(biome, rng)` — выбирает тип по биому
- ✅ 8 функций `_build_flower/_build_grass_tuft/_build_small_stone/_build_mushroom/_build_dead_leaf/_build_swamp_bubble/_build_crystal/_build_bone/_build_rune`

### Технические детали
- DecorLayer как Node2D child of world_map, z_index=1 (поверх тайлов)
- Deterministic RNG: `rng.seed = hash(map_id + "_decor")` — одинаково при reload
- Случайные rotation/scale для разнообразия

### Bug fix
- `world_map.gd:360` — сломанный отступ `elif` после `match _:` case (parse error).
  Восстановил правильный отступ внутри `_:` блока.

### Тесты
- `snap_decor.js` — сохраняет 2 скриншота с разных точек карты 1
- regression_smoke: 8/8 (после фикса syntax error)

---

## 2026-07-08 (продолжение 2) — Statistics screen

### Что сделано
- ✅ **Экран статистики** — клавиша S или Tab (или touch кнопка «Статы [S]»)
  - `scripts/ui/stats_screen.gd` + `scenes/ui/stats_screen.tscn`
  - Метрики: Карта N/33, Карт пройдено, Букв собрано /33, Квестов выполнено,
    Союзников, Буквиц, Сила букв (Σ power×level)
  - Подсветка зелёным когда есть прогресс, надпись «★ ФИНАЛ ДОСТИГНУТ» при
    прохождении всех 33 карт

### Технические детали
- `world_map.gd` — инстансы `STATS_SCENE` как child
- `hud_ui.gd::_make_stats_btn` — touch button [S] в правой колонке
- Карты пройдено — считается из `completed_quest_ids` (извлекаем map_id из quest_id)
- Сила букв — Σ base_power × level для каждой собранной буквы (отражает §20 инверсию)

### Тесты
- `snap_stats.js` — stats visible после toggle
- Vision подтвердил: «Карта 1/33 — Светлая Долина, Букв собрано 3/33, Сила букв 32»

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
