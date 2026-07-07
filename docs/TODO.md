# TODO — BOOKWAR (на следующую сессию)

> Ревизия: 2026-07-07. Проверено через code-audit + e2e (15/48 suites fail, 36/148 tests fail)
> + mcp-cli Vision (game world / intro screen рендерят кириллицу корректно).
> Сделанные задачи убраны. §0.12 cleanup.ps1 — отдельная сессия.

---

## 🔴 КРИТИЧНО — тест-сьют ломается (GATE 2 провален)

### T0. Многие тесты ждут мир, а получают intro/char-select (15 suites FAIL)
- **Что**: После build'а игра показывает **8-главную легенду** (L1, `intro.tscn`) перед миром
  и/или **экран выбора героя** (50 героев). Старые e2e-тесты ждут `window.gameInWorld` сразу
  после new game → `waitForWorld` timeout.
- **Признаки**: `component/combat.test.js:119`, `component/char_select_avatars.test.js`,
  множество `waitForCondition timed out` в разных suites.
- **Решение (варианты)**:
  - (a) В `helpers/game_actions.js` → `startNewGame()` прокликивать «Пропустить легенду >>»
    и/или выбирать героя по умолчанию.
  - (b) Test-bridge `window.gameSkipIntro()` + `window.gameAutoPickHero()` — мгновенный
    переход в мир для тестов.
- **Файлы**: `tests/e2e/helpers/game_actions.js`, `tests/e2e/helpers/godot_page.js`,
  `scripts/ui/intro.gd`, `scripts/ui/main_menu.gd`.

---

## ⚠️ ОСТАВШИЕСЯ ЗАДАЧИ

### Task 4 — Рекрут-монстр бьёт ближайшего `!`, а не босса
- **Статус**: НЕ СДЕЛАНО.
- **Что**: `_find_nearest_hostile(400.0)` (`scripts/characters/monster_base.gd:466`)
  ищет в радиусе 400px без приоритета боссам.
- **Решение**: В `_find_nearest_hostile()` (`monster_base.gd:494-508`) приоритизировать
  монстров с `boss:true` / `is_boss:true`. Опционально — расширить радиус до босса.

### Task 6 — Подсказки `?` монстров показываются, но не отдельным сообщением
- **Статус**: ЧАСТИЧНО. `_get_letter_direction_hint()` реализован (`monster_base.gd:739-800`),
  текст ХОРОШИЙ (направление + ориентир + расстояние через `I18n.t_fmt("dir.hint", ...)`).
  Но сейчас добавляется к сообщению вербовки (`monster_base.gd:624-625`) — игрок видит всё
  одним блоком, не отдельным всплытием.
- **Решение**: Дублировать подсказку отдельным toast через HUD (`hud_ui.gd._toast_label`,
  строки 44-78) после закрытия окна вербовки.

### Task 7 — Флаг `_is_auto_combat_dialogue` для защиты от двойной обработки
- **Статус**: НЕ СДЕЛАНО. Флаг есть только в этом TODO (`docs/TODO.md:41`), в коде отсутствует.
- **Что**: `_close_auto_combat_dialogue()` (`scripts/world/world_map.gd:548-552`) закрывает
  диалог авто-боя → `_on_global_dialogue_ended()` (`monster_base.gd:590-592`) срабатывает
  на ВСЕХ монстров в состоянии "dialogue" → повторный `_try_recruit()`.
- **Решение**: Завести флаг `_is_auto_combat_dialogue: bool` в `world_map.gd`, ставить перед
  `end_dialogue()`, проверять в `monster_base._on_global_dialogue_ended()`.

### Task 9 — `pickup.test.js` flake (точки не spawn'ятся рядом со стартом)
- **Статус**: НЕ СДЕЛАНО.
- **Что**: `_spawn_light_valley_items()` (`scripts/world/world_map.gd:302-317`) spawn'ит
  40 точек в радиусе ±600px от старта. Гарантированные 3 спавна рядом — это БУКВЫ (А/О/М),
  не точки. Тест `movePlayer('right', 800)` уводит игрока x≈2016 за правый край скопления точек.
- **Решение (варианты)**:
  - (a) В `_spawn_light_valley_items()` добавить 3-5 гарантированных точек в радиусе 100px
    от старта.
  - (b) Через test-bridge `window.gameTestAddDot(5)` выдавать точки в setup'е теста.

### Task 10 — Дополнить AGENTS.md
- **Статус**: ЧАСТИЧНО.
  - §17.12 (? monster hints system) — **МОЖНО ДОБАВИТЬ** (код есть в `monster_base.gd:739-800`).
  - §17.13 (combat cooldown после проигрыша) — **МОЖНО ДОБАВИТЬ** (код есть:
    `battle_manager.gd:330-334`, `game_state.gd:12`, `world_map.gd:100-101`).
  - §17.4 (условие победы) — **УСТАРЕЛО**: AGENTS.md:1711-1721 всё ещё требует подходить ко
    всем монстрам (`_approached`), а код `_check_victory()` (`world_map.gd:712-745`) уже
    не проверяет этот флаг → обновить §17.4.

---

## ✅ СДЕЛАНО (проверено 2026-07-07)

- **Task 1** — Победа на карте 1 — `_check_victory()` (`world_map.gd:712-745`) использует
  новое условие (нет активных hostile-монстров), `_spawn_portal()` спавнится при progress≥0.50.
- **Task 2** — Победа на карте 2 — `_check_victory()` обобщён, `MAP_CHAIN` (`constants.gd:87-97`)
  содержит **33 карты**, переход работает через `_do_portal_transition()` (`world_map.gd:835-848`).
- **Task 3** — Сила босса 154 — цепочка данных корректна: `monsters.json:91` letters `[А,Е,Б,В,Г]`,
  `monster_spawner.gd:173-177` выставляет monster_id="two_tongue" до `_ready()`,
  `monster_base._load_monster_data()` (`:336-339`) правильно грузит → Σ=33+28+32+31+30=154.
- **Task 5** — Сообщение вербовки видно игроку — `_try_recruit()` (`monster_base.gd:629`)
  испускает `GameState.recruit_message`, HUD слушает (`hud_ui.gd:29`) и показывает в диалоговом
  боксе с авто-скрытием через 6с (`hud_ui.gd:280-298`).
- **Task 8** — Очистка скриншотов — `scripts/dev/cleanup.ps1` существует, добавлено в
  AGENTS.md §0.12 как обязательное правило старта сессии.

---

*Следующий шаг: T0 (починить тест-сьют) → затем Task 7 (auto-combat flag) → Task 4 (boss priority).*
