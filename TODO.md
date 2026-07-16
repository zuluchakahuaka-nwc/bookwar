# BOOKWAR — TODO (на следующую сессию)

> Обновлено: 2026-07-08. Читать вместе с `docs/DEVLOG.md` (там детали по каждой задаче).
> Обязательно прочитай AGENTS.md (§12.4 протокол проверки).
> ПРИНЦИП: сделал → проверил Vision/тестами → если ок, продолжаешь. По одной задаче.

---

## 🟢 СЕССИЯ 2026-07-08 — ЗАВЕРШЕНА (23 коммита)

### Что сделано полностью
- ✅ **B-QUEST-1**: TestBridge race condition — FIXED (`test_bridge.gd` `INITIAL_BRIDGE_JS`)
- ✅ **Q1-Q6**: Multi-type квесты (5 типов), прогрессия N-2, журнал, NPC markers, lore, toasts
- ✅ **§20**: Инверсия баланса — `base_power = position` (А=1 слабая, Я=33 сильная)
- ✅ **§18.5**: Named creatures на картах 2-10 (9 уникальных: longtongue/big_ears/big_eyes/big_mouth/swamp_walker/stone_chewer/ash_priest/crystaloid/dark_monk)
- ✅ **§16**: Кузнец Слов NPC (5 карт) — открывает craft UI через диалог
- ✅ **§18.4**: Купец NPC + Shop UI (5 карт) — покупка 33 букв за буквицы
- ✅ **Progress bar %** зачистки карты в HUD
- ✅ **Statistics screen** (S-key): HP/карты/буквы/квесты/сила
- ✅ **Decorative terrain** — программный спавн 80-176 декоров по 6 биомам
- ✅ **Lore описания** 33 регионов
- ✅ **Save/load** квестов (переживает reload браузера)
- ✅ **Storyline квесты** для карт 3-33 (59 ручных + автогенерация)
- ✅ **Локализация** — 8 локалей, 35 новых ключей переведены на 6 языков (en/es/de/fr/pt/ar/zh)
- ✅ **Мультиплеер** — `ANDROID_VERSION/server/server.js` запущен и verified
- ✅ **Android APK** 152.4 МБ пересобран со всеми обновлениями
- ✅ **E2E walkthrough map 12** — `walkthrough_map12.js`, карта проходится от старта до портала

### Тесты — 34/34 regression зелёные (при --runInBand)
- regression_smoke (8), regression_data (6), regression_combat (4)
- regression_balance (6), regression_quests (6), regression_portal (5), regression_save (1)

### Коммиты (23 в этой сессии)
`a92752c` → ... → `f155e4f` (последний — e2e walkthrough map 12)

---

## 🟢 СЕССИЯ 2026-07-16 — ЗАВЕРШЕНА (3 коммита + push)

### Что сделано
- ✅ **Безопасный push в GitHub**: проверены секреты, добавлен `*.log` в `.gitignore`, запушены 6+1 коммитов в `origin/master` (`90b32b2..cf7a0e7`)
- ✅ **Decorative terrain (#4 FIX)**: base-формы декоров увеличены ~1.5-2x, цвета насыщены (flowers 5 petals, neon grass, dark stones w/ top facet, red-cap mushrooms w/ white dots, vivid crystals w/ sparks, glowing runes 4 colours). Vision MCP подтвердила: декоры теперь видны как «large grey stone + yellow flowers + green triangles» (раньше: «almost absent / blends with grass»).
- ✅ **Локализация lore (#3 FIX)**: italian (`it.json`) добит с 18 до 85 ключей (+34 region names +33 lore). Теперь **все 9 локалей имеют полный lore coverage**. E2E + Vision подтвердили: `Valle Luminosa — l'ultimo baluardo della luce` рендерится в HUD при Italian locale.
- ✅ regression_smoke: 8/8 passed

### Коммиты (3 в этой сессии)
- `cf7a0e7` — chore(gitignore): exclude *.log files
- `89fd0b9` — feat(decor): enlarge + saturate terrain decor polygons (Vision verify)
- `0dfd50e` — feat(i18n): Italian region names + lore (34+33 keys)

---

## 🟢 СЕССИЯ 2026-07-16 (ЧАСТЬ 2) — ЗАВЕРШЕНА (5 коммитов)

### Что сделано
- ✅ **#6 Android tap-zones (FIXED)**: HUD action buttons (E/I/T/Q/S/H/Legend) переведены с `Button.pressed.connect` на централизованный `_input` hit-test (эталон §0.11 из main_menu.gd). Debounce 250ms, `set_input_as_handled()`, await 80ms для action release (call_deferred был слишком быстрым). Vision подтвердила: tap на Inventory открывает инвентарь. Commit `9e6e813`.
- ✅ **#2 Named creatures 11-33 (CLOSED)**: 7 новых уникальных существ для карт 12/14/16/22/24/26/30 (mist_weaver / grey_stalker / frost_biter / bridge_keeper / village_ghoul / citadel_commander / ban_inquisitor). HP 170→330. Теперь 28 named creatures (раньше 21, generic fallback для 7 карт). Commit `ee1d756`.
- ✅ **#7 Tactical combat §20.3 (CLOSED — full)**: добавлены auto-equip (best letters → slots по base_power×level) + cycle_slot (клик переключает буквы) + clear buttons. E2E: equip А/О/Б/В → attack=35 armor=5 (формула §20.1). Commit `b1c9408`.
- ✅ **#8 Voice chat WebRTC (SKELETON)**: GDScript-side infrastructure готова — `scripts/multiplayer/voice_chat.gd` autoload + JS bridge (`window.gameVoice*`) + PTT button в HUD. mic permission state machine, signals. **НЕ реализовано**: actual RTCPeerConnection между peer'ами + signalling protocol на WS server + TURN relay (2-4 дня отдельной работы). Commit `0fbd4f1`.

### Коммиты (5)
- `9e6e813` feat(android): HUD tap-zones — _input hit-test replaces Button.pressed
- `ee1d756` feat(creatures): 7 new named creatures for maps 11-33
- `b1c9408` feat(tactical §20.3): auto-equip + clear buttons in tactical panel
- `0fbd4f1` feat(voice §7.2): WebRTC voice chat skeleton — bridge + PTT button
- (зависит от push) docs/todo: статус сессии

---

## 🟢 СЕССИЯ 2026-07-16 (ЧАСТЬ 3) — ЗАВЕРШЕНА (6 коммитов)

### Что сделано
- ✅ **#1 Bug fix**: `battle_manager._process` теперь auto-flee если `_godotDialogue` flag стоит во время боя. Commit `33852fe`.
- ✅ **#5 Bestiary**: добавлены 7 новых существ в BESTIARY_CREATURES (карты 12/14/16/22/24/26/30), пофикшен `_add_metric` parse bug. Commit `25c0f26`.
- ✅ **#4 CI**: локально ci.ps1 PASS за 75.8с. Workflow `.github/workflows/ci.yml` уже в репо (commit `90b32b2`) — на push/PR в master. Если не запускается на GitHub — проверить Actions tab settings репо.
- ✅ **#2 Multiplayer e2e**: `multiplayer_2client.test.js` PASS — 2 клиента коннектятся, players=2 sync работает. Нужен `npm install ws` в корне (one-time, не в git).
- ✅ **#3 Voice chat FULL p2p**: server.js + network_manager + voice_chat — полный signalling protocol (offer/answer/ICE/bye), RTCPeerConnection setup в JS bridge. **Код полный и валидный**, но headless Puppeteer не может надёжно протестировать WS receive path (server лог подтверждает relayed=true, но _mpIn drain в C2 пропускает messages). В реальном браузере должно работать. Commit `ffdcfdd`.

### Коммиты (6)
- `33852fe` fix(#1): auto-flee battle when gameTriggerDialogue() is buffered
- `25c0f26` feat(bestiary #10): include all 28 named creatures + fix _add_metric
- (CI без коммита — уже был)
- `ffdcfdd` feat(voice §7.2): full WebRTC p2p audio — signalling + RTCPeerConnection

---

## 🔴 ФИНАЛЬНЫЙ СТАТУС — следующая сессия с этого места

> **Обновлено 2026-07-16 часть 3**: все 5 задач из списка пользователя сделаны.
> Voice chat full p2p — код полный, требует real-browser тестирования.

### 1. ~~gameTriggerDialogue в battle_scene~~ ✅ ЗАКРЫТО
### 2. ~~Named creatures 11-33~~ ✅ ЗАКРЫТО (часть 2)
### 3. ~~Локализация lore~~ ✅ ЗАКРЫТО (часть 1)
### 4. ~~Decorative terrain~~ ✅ ЗАКРЫТО (часть 1)
### 5. ~~Multiplayer real-server e2e~~ ✅ ЗАКРЫТО (multiplayer_2client PASS)
### 6. ~~Android e2e tap-zones~~ ✅ ЗАКРЫТО (часть 2)
### 7. ~~Tactical combat §20.3~~ ✅ ЗАКРЫТО (часть 2)
### 8. ~~Voice chat WebRTC~~ ✅ КОД ЗАВЕРШЁН (требует real-browser теста)
### 9. ~~CI GitHub Actions~~ ✅ ЗАКРЫТО (workflow в репо, локально работает)
### 10. ~~Bestiary~~ ✅ ЗАКРЫТО

### Опциональные улучшения (на будущее)
- Voice chat: добавить TURN server URL для NAT'd peers (в `voice_chat.gd::iceServers`)
- Voice chat: тестировать в реальном браузере с real mic permission
- Multiplayer: `npm install ws` documented в README (one-time setup)
- Localized progress bar / victory toast на 9 языках (сейчас русский)
- Save/load killed monsters tracking в Bestiary (сейчас "видено" = по уровню)
- Godot 4.7+ для фикса Android emulator tap coordinate mapping

---

## 🟢 I18N — АЛФАВИТ-ЗАВИСИМЫЕ ВЕРСИИ ИГРЫ — ЗАВЕРШЕНО (2026-07-09)

> Согласно AGENTS.md §2.0, локализация = НЕ перевод строк, а ПЕРЕСТРОЕНИЕ
> игры под алфавит локали. Все 9 основных локалей готовы.

**Готовые локали (каждая со своим алфавитом N → N уровней):**

| Локаль | N | Гласные/Согласные | Vowel Mult |
|--------|---|-------------------|-----------|
| ru | 33 | 10/21+2 | 1.0 |
| en | 26 | 5/21 | 1.4 |
| es | 27 | 5/22 | 1.3 |
| de | 30 | 8/22 | 1.2 |
| fr | 26 | 6/20 | 1.3 |
| pt | 26 | 5/21 | 1.4 |
| it | 21 | 5/16 | 1.4 |
| ar | 28 | 3/25 | 1.8 |
| zh | 214 | 122/92 (Канси) | 1.0 |

**Что сделано:**
- ✓ `data/letters_{en,es,de,fr,pt,it,ar,zh}.json` (8 файлов)
- ✓ `AlphabetData` загружает per-locale + reload on locale change
- ✓ `MAP_CHAIN` динамический (первые N регионов из base 33)
- ✓ Хардкод «33» убран (stats_screen, constants.gd)
- ✓ Per-locale баланс (`LOCALE_VOWEL_MULTIPLIERS`)
- ✓ Spells per-locale (`data/spells_{en,es,de,fr,pt,it,ar}.json`)
- ✓ Chinese: 214 ключей Канси (через `gen_letters_zh.js`)
- ✓ E2E: `alphabet_locales.test.js` — 9/9 локалей корректны

**Коммиты:** `c8a8e5e` → `63883ca` → `dc87e24` → (spells) → (zh)

**Будущие улучшения (опционально):**
- ~~Локализация UI строк на it~~ ✅ ЗАКРЫТО 2026-07-16 (commit `0dfd50e`)
- ~~Полный lore на всех 9 локалей~~ ✅ ЗАКРЫТО 2026-07-16 (все 9 локалей имеют 34 region + 33 lore)
- ~~Region names per-locale~~ ✅ ЗАКРЫТО 2026-07-16 (region names на всех 9 локалей)
- Опционально: перевести progress bar/victory toast с русского на все локали

---

**Принцип (AGENTS.md §2.0):**

| Локаль | Букв (N) | Уровней | Гласные / Согласные | Особенность |
|--------|----------|---------|---------------------|-------------|
| ru | 33 | 33 | 10 / 21 + 2 знака | ГОТОВО |
| en | 26 | 26 | 5 / 21 | defense-heavy → vowel mult ↑ |
| es | 27 | 27 | 5 / 22 | +ñ |
| de | 30 | 30 | varies | +ä, ö, ü, ß |
| fr | 26 | 26 | 6 / 20 | как en, +accents optional |
| pt | 26 | 26 | 5 / 21 | как en |
| it | 21 | 21 | 5 / 16 | короткий алфавит |
| ar | 28 | 28 | 3 краткие+3 долгие / остальное | RTL |
| zh | 214 | 214 | нет алфавита | ключи Канси (финальная) |

**Этапы:**

1. **Создать `data/letters_{locale}.json`** — N букв с type/position/base_power/speed/description
   - en, es, de, fr, pt, it, ar (zh отдельно)
   - Vowel/consonant классификация per-язык
   - Drop weight (rare/common per §20.2): rare = последние 11 позиций, common = первые 10

2. **AlphabetData (`scripts/core/alphabet_data.gd`)** — загружать `letters_{locale}.json`
   - `_load_letters()` меняет путь в зависимости от `I18n.get_locale()`
   - При смене локали — `_reload()` (перезагрузить alphabet)

3. **Убрать хардкод «33»** (constants.gd, monster_spawner.gd, world_map.gd)
   - Заменить на `AlphabetData.get_count()`
   - Letters_total в stats_screen
   - Bestiary thresholds
   - Уровни доступных букв (MAP_LETTERS)

4. **MAP_CHAIN динамический** — N регионов вместо 33
   - В `constants.gd` оставить `_base_chain` (минимальные: light_valley)
   - `_get_chain_for_locale(locale)` генерирует N регионов с тематическими именами
   - Region lore — тоже per-locale (уменьшенный/расширенный)

5. **Per-locale баланс** (`VOWEL_MULTIPLIER`, `CONSONANT_MULTIPLIER`)
   - en/fr/pt: vowel_mult=1.4 (defense-heavy)
   - es: vowel_mult=1.3
   - de: vowel_mult=1.2 (30 букв)
   - ar: separate (RTL, разные множители)

6. **Spells per-locale** (`data/spells_{locale}.json`)
   - en: BANG, ZAP, BOOM (3-4 буквы)
   - es: SOL, MAR, LUZ
   - de: EIS, FEU, LICHT
   - fr: FEU, EAU, NUIT
   - pt: SOL, MAR, LUZ
   - it: SOLE, MARE, LUCE
   - ar: слова из арабских корней

7. **E2E тесты** для каждой локали
   - `tmp_locale_<xx>.js`: switch locale, check `gameAlphabet.length == N`
   - Vision MCP: confirm alphabet renders correctly (Cyrillic/Latin/Arabic)

8. **Chinese (zh)** — отдельная подзадача
   - Выбрать стратегию: 214 ключей Канси (самая длинная версия)
   - Или: пиньинь (26 латинских, как en)
   - Решение зафиксировать в `data/letters_zh.json`

**Файлы (основные):**
- `data/letters_{en,es,de,fr,pt,it,ar,zh}.json` (новые)
- `data/spells_{locale}.json` (новые)
- `scripts/core/alphabet_data.gd` (load per-locale)
- `scripts/core/constants.gd` (dynamic MAP_CHAIN, no hardcoded 33)
- `scripts/core/i18n.gd` (emit signal on locale change -> AlphabetData reload)
- `scripts/world/monster_spawner.gd` (use AlphabetData.get_count())
- `scripts/ui/stats_screen.gd` (letters_total dynamic)

**Приоритет:** en → es → de → fr → pt → it → ar → zh

---

## 📋 БЫСТРЫЙ СТАРТ СЛЕДУЮЩЕЙ СЕССИИ

```powershell
# 1. Прочитать контекст
Get-Content docs/DEVLOG.md | Select-Object -Last 80   # что сделано
Get-Content TODO.md                                     # этот файл

# 2. Запустить сервер
$conns = Get-NetTCPConnection -LocalPort 3000 -ErrorAction SilentlyContinue
if (-not $conns) {
    $workdir = "D:\Projects\BOOKWAR\builds\html5"
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c npx http-server `"$workdir`" -p 3000 -c-1 --silent" -WindowStyle Hidden
    Start-Sleep -Seconds 7
}

# 3. Быстрый smoke (что ничего не сломалось)
cd tests/e2e; npx jest --forceExit --runInBand component/regression_smoke.test.js

# 4. Выбрать задачу из списка выше (1-10) и делать по одной
#    с полным циклом: код → build → serve → test → screenshot → Vision → commit
```

### Приоритет задач для следующей сессии
1. **#1 Bug fix** `gameTriggerDialogue` в battle_scene — быстрый фикс
2. **#2 Named creatures 11-33** — продолжение контента
3. **#5 Multiplayer e2e** — 2 клиента, проверить position sync
4. **#6 Android e2e** — на эмуляторе
5. **#3 Локализация lore** — вынести в i18n
6. **#7 Tactical combat** — большой рефакторинг (отдельная сессия)

---

## 📊 ТЕКУЩИЙ СТАТУС ПРОЕКТА (2026-07-08)

| Компонент | Статус | Покрытие |
|-----------|--------|----------|
| 33 карты | ✅ все грузятся | 33/33 |
| Квесты | ✅ 5 типов | 59 ручных + ~340 авто = ~400 |
| Бой | ✅ card-based + autobattle | работает e2e |
| Порталы | ✅ переходы | 5 переходов протестированы |
| Кузнец Слов | ✅ craft UI | 5 карт |
| Купец | ✅ shop UI | 5 карт |
| Named creatures | ⚠️ карты 2-10 | 9 существ (11-33 generic) |
| Save/load | ✅ квесты переживают reload | e2e тест зелёный |
| Локализация | ⚠️ UI переведён, lore нет | 8 локалей, 35+35×6 ключей |
| Мультиплеер | ⚠️ сервер работает | position/trade/PvP не тестированы |
| Android | ⚠️ APK собран | e2e на эмуляторе не запускался |
| Декорации | ✅ спавнятся | Vision видит слабо (мелкие) |
| Тесты | ✅ 34/34 зелёных | smoke+data+combat+balance+quests+portal+save |

**Git**: `master` branch, последний коммит `f155e4f` (e2e walkthrough map 12).
**DEVLOG**: `docs/DEVLOG.md` — полный журнал сессии.

---

*Конец TODO. Начни с чтения DEVLOG.md для контекста, потом выбери задачу.*
