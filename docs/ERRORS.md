# BOOKWAR — Журнал ошибок и исправлений

> Все баги, найденные и исправленные в проекте. Обновляется при каждом фиксе.

---

## Сессия 2026-06-15

### BUG-001: `class_name` конфликтует с Autoload именами

**Файл**: autoload-скрипты (`game_state.gd`, `inventory.gd`, и др.)
**Симптом**: Autoload-синглтоны не загружаются при запуске.
**Причина**: `class_name GameState` в скрипте, зарегистрированном как autoload `GameState`, конфликтует в Godot 4.6 — имя класса и имя автозагрузчика совпадают.
**Фикс**: Убраны `class_name` со всех autoload-скриптов.
**Статус**: Исправлено.

---

### BUG-002: `instance=ExtResource("path")` вместо числового ID

**Файл**: `world_map.tscn`
**Симптом**: Сцена не загружается, ошибка парсинга.
**Причина**: Использован текстовый путь вместо числового ID в `instance=`.
**Фикс**: Заменено на числовой ID (e.g., `instance=ExtResource("6")`).
**Статус**: Исправлено.

---

### BUG-003: `TileSetAtlasSource.create_tile()` принимает `Vector2i`, не `Rect2i`

**Файл**: `map_generator.gd`
**Симптом**: Тайлы не создаются, runtime error.
**Причина**: Передавался `Rect2i` вместо `Vector2i`.
**Фикс**: Изменён тип аргумента.
**Статус**: Исправлено.

---

### BUG-004: `Array[Dictionary]` типизация вызывает silent runtime error

**Файл**: несколько скриптов
**Симптом**: Присвоение JSON-данных в `Array[Dictionary]` тихо падает.
**Причина**: Godot 4.x строго типизирует массивы, но JSON-парсер возвращает нетипизированный `Array`.
**Фикс**: Упрощено до `Array` без типизации.
**Статус**: Исправлено.

---

### BUG-005: Точки (dots) не спавнятся на карте

**Файл**: `world_map.gd`
**Симптом**: Нет точек на карте после старта игры.
**Причина**: Отсутствовала функция `_spawn_light_valley_items()`.
**Фикс**: Добавлена функция, спавнящая точки и стартовые буквы (А, О, М).
**Статус**: Исправлено.

---

### BUG-006: `get_overlapping_bodies()` не находит монстров

**Файл**: `player.gd`
**Симптом**: Игрок не может взаимодействовать с монстрами.
**Причина**: Несовпадение collision layers между игроком и монстрами.
**Фикс**: Настроены collision layers/masks.
**Статус**: Исправлено.

---

### BUG-007: Диалоги не активируются через Puppeteer

**Файл**: `player.gd`, `test_bridge.gd`
**Симптом**: В e2e-тестах диалог не стартует.
**Причина**: Keyboard input из Puppeteer не доходит до Godot canvas.
**Фикс**: Добавлен JS bridge `gameTriggerDialogue()` + `gameTestStartDialogue()`.
**Статус**: Исправлено.

---

### BUG-008: `pressKey` не фокусирует canvas

**Файл**: `godot_page.js`
**Симптом**: Нажатия клавиш не доходят до игры.
**Причина**: Puppeteer отправляет события на страницу, а не на canvas.
**Фикс**: Добавлен canvas click перед нажатием.
**Статус**: Исправлено.

---

### BUG-009 (B1): Инвентарь не закрывается на повторное нажатие I

**Файл**: `inventory_ui.gd`
**Симптом**: Инвентарь открывается, но не закрывается.
**Причина**: `_input()` не вызывал `set_input_as_handled()`, событие проходило дальше.
**Фикс**: Добавлен `set_input_as_handled()` в `_input()`.
**Статус**: Исправлено. Regression-тест: `regression_bugfix_b1_b3.test.js`.

---

### BUG-010 (B2): Бой невидим — сообщения и HP не обновляются

**Файл**: `battle_scene.gd`, `hud_ui.gd`
**Симптом**: В бою нет видимой обратной связи.
**Причина**: MessageLabel positioned off-screen, ActionLogLabel отсутствует, `_emit_state()` не вызывался в signal handlers.
**Фикс**: Repositioned labels, added ActionLogLabel, connected signals to `_emit_state()`.
**Статус**: Исправлено. Regression-тест: `regression_bugfix_b1_b3.test.js`.

---

### BUG-011 (B3): Монстры атакуют во время диалога

**Файл**: `monster_base.gd`
**Симптом**: Монстр атакует даже когда игрок в диалоге.
**Причина**: Отсутствовала проверка `GameState.is_in_dialogue` в attack/chase logic.
**Фикс**: Добавлен guard `if GameState.is_in_dialogue: return` в `_try_attack()`, `_process_chase()`, `_on_detection_body_entered()`.
**Статус**: Исправлено. Regression-тест: `regression_bugfix_b1_b3.test.js`.

---

### BUG-012: Mouse умирает после закрытия инвентаря

**Файл**: `inventory_ui.gd`
**Симптом**: После закрытия инвентаря курсор мыши исчезает.
**Причина**: При закрытии устанавливался `MOUSE_MODE_CAPTURED` вместо `MOUSE_MODE_VISIBLE`.
**Фикс**: Заменён `Input.mouse_mode = Input.MOUSE_MODE_VISIBLE` при закрытии.
**Статус**: Исправлено.

---

### BUG-013: `world_map.gd._process()` — undefined variable `combat`

**Файл**: `world_map.gd` (строки 68-71)
**Симптом**: B3 тест падает — `dialogueActive = false`. Runtime error в `_process()`.
**Причина**: Ботнутое слияние блоков dialogue-test и combat-test в один `if`. После `_force_nearest_dialogue()` шёл код `combat.get(...)`, но переменная `combat` не определена. GDScript runtime error ломает весь `_process()`.
**Фикс**: Разделены на два независимых блока:
  ```gdscript
  if _test_bridge.consume_test_dialogue():
      _force_nearest_dialogue()
  for combat: Dictionary in _test_bridge.drain_test_combat_queue():
      ...
  ```
**Статус**: Исправлено. Проверено: B1-B3 regression 4/4 зелёные.

---

### BUG-014: `monster_base.gd` — необъявленный сигнал `state_changed`

**Файл**: `monster_base.gd` (строка 205)
**Симптом**: **0 монстров в игре.** B3 падает. Все dependent-скрипты (`player.gd`, `interactable.gd`) тоже не компилируются.
**Причина**: При полном переписывании `monster_base.gd` в `_set_state()` использован `state_changed.emit(_state)`, но сигнал объявлен как `monster_state_changed`. GDScript parse error: `Identifier "state_changed" not declared`.
**Каскад**: MonsterBase не компилируется → Player не компилируется (depends on MonsterBase) → Interactable не компилируется (depends on Player) → `interactable.gd` не загружается → предметы не работают → монстры не спавнятся.
**Фикс**: `state_changed.emit(_state)` → `monster_state_changed.emit(self)`.
**Статус**: Исправлено. Проверено: 17 монстров спавнятся, 89/89 тестов зелёные.

---

*Журнал ведётся с 2026-06-15. Ошибки нумеруются последовательно.*
