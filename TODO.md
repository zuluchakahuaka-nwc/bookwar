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

## 🔴 НА ЧЁМ ОСТАНОВИЛИСЬ — следующая сессия с этого места

### 1. BUG: `gameTriggerDialogue()` не работает в battle_scene
- **Где**: `tests/e2e/playthrough/walkthrough_map12.js` — бот не может открыть диалог после боя
- **Причина**: `_force_nearest_dialogue` вызывается в `world_map._process`, но если игрок в battle_scene — флаг не обрабатывается
- **Для живого игрока**: не критично (T-key только в мире), но e2e бот ломается
- **Файлы**: `scripts/world/world_map.gd:800`, `scripts/core/test_bridge.gd`
- **Решение**: либо ждать возврата в world_map, либо добавить bridge в battle_scene

### 2. Named creatures только на картах 2-10
- Карты 11-33 используют generic пул (dark_wolf/shadow_lurker/forest_creature)
- **Можно добавить**: по 1-2 named creatures для карт 11-20 и 21-33
- **Файлы**: `data/monsters.json` (новые entries), `scripts/characters/monster_base.gd::_build_named_creature` (новые case), `scripts/world/monster_spawner.gd::_enemy_pool_for_level`

### 3. Локализация — lore описания только на русском
- `REGION_LORE` в `constants.gd` — 33 описания на русском
- Можно вынести в i18n и перевести на en/es/de/fr/pt/ar/zh
- **Файлы**: `scripts/core/constants.gd::REGION_LORE`, `data/i18n/*.json`

### 4. Decorative terrain — Vision плохо видит декоры
- Декоры 10-15px слишком мелкие на скриншоте
- **Решение**: увеличить scale до 10-15 (сейчас 5.5-7.5) — пересмотреть `_spawn_terrain_decor`
- **Файлы**: `scripts/world/world_map.gd::_spawn_terrain_decor`

### 5. Мультиплеер — нет real-server e2e
- Сервер запущен локально, но position sync / trade / PvP не тестировались на 2+ клиентах
- **Что нужно**: 2 puppeteer-браузера одновременно, проверка что игроки видят друг друга
- **Файлы**: `tests/e2e/playthrough/` (новый тест), `scripts/multiplayer/world_mp_sync.gd`

### 6. Android — нет e2e на эмуляторе
- APK собран (152 МБ), но не запускался на AVD в этой сессии
- **Что нужно**: `ANDROID_VERSION/scripts/dev/test_android.ps1` — full pipeline
- **Скрипты есть**: build_apk, run_emulator, install_apk, screenshot, vision

### 7. Tactical combat §20.3 — не реализован
- Схема тела-экипировки (шлем/корпус/руки) с слотами под буквы
- Тумблер: автобой ВКЛ (card-based) / автобой ВЫКЛ (тактический)
- **Большая задача** — отдельная сессия
- **Файлы**: новый `scripts/combat/tactical_combat.gd` + UI

### 8. Voice chat (WebRTC) — не реализован
- AGENTS.md §7.2 — push-to-talk через WebRTC
- Требует отдельный сигнальный сервер
- **Большая задача**

### 9. Полный regression suite на CI
- Сейчас 34 теста, запуск вручную через `npx jest --runInBand`
- Можно настроить GitHub Actions / локальный CI скрипт
- **Файлы**: `.github/workflows/` (новый) или `scripts/dev/ci.ps1`

### 10. Книга мёртвых / Bestiary
- Список убитых монстров, найденных букв, пройденных регионов
- Можно добавить как вкладку в stats_screen
- **Файлы**: `scripts/ui/stats_screen.gd` (расширить)

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
- Локализация UI строк на it (сейчас минимальный набор)
- Полный lore на всех 9 локалей (сейчас lore только ru + en/es/de/fr/pt/ar/zh ключи есть в i18n)
- Region names per-locale (сейчас все карты используют русские region names)

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
