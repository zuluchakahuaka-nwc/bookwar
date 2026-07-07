# ANDROID_VERSION — СТАТУС ПОРТА

**Дата**: 2026-06-23
**Этап**: MVP собран и запущен на эмуляторе

## ЧТО РАБОТАЕТ

- ✅ BOOKWAR APK собирается (147 MB, debug)
- ✅ Устанавливается на эмулятор Test_API34 (API 34, arm64-v8a)
- ✅ Запускается с Compatibility renderer (OpenGL ES 3.1 через GPU host)
- ✅ Главное меню отображается корректно:
  - Заголовок: **BOOKWAR**
  - Подзаголовок: **Война за алфавит**
  - 4 кнопки: Новая игра / Легенда / Как играть / Выход
  - Инструкции клавиш внизу
- ✅ Кириллица рендерится правильно
- ✅ mcp-cli (GLM-4.6V) проверяет скриншоты — качество высокое

## ЧТО ОСТАЛОСЬ

### High priority
- [ ] **BLOCKED**: Tap координаты трансформируются неправильно
  - Симптом: `adb shell input tap 270 1200` → Godot `TOUCH_EVENT pos=(200, 400)` (ожидалась ~game center)
  - Touch events доходят до `_input()` (подтверждено логами)
  - Buttons не активируются — координаты taps не попадают в `get_global_rect()` кнопок
  - **Причина**: Богот 4.6.3 + Compatibility renderer на Android эмуляторе масштабирует canvas нестандартно. Расчётная трансформация (1080x2400 → 1280x720) не совпадает с фактической.
  - Что пробовал: `Input.emulate_mouse_from_touch = true`, явный `_input` handler с `btn.get_global_rect().has_point(event.position)`, разные координаты, long swipes
  - **Workaround на будущее**:
    1. Запустить Богот 4.7+ где этот баг м.б. починен
    2. Либо сделать **серию taps** в разных координатах и найти правильный mapping через logcat
    3. Либо UI без buttons — tap zones через `Control._gui_input` на отдельных full-screen Control nodes
- [ ] Адаптировать UI под сенсор (если taps заработают):
  - Скрыть "WASD/E/I/T" инструкции на touch devices
  - Виртуальный джойстик (TouchScreenButton) слева снизу
  - Кнопки E/I/T/пробел справа снизу
- [ ] E2E тесты Android (adb input + screencap + Vision через mcp-cli)
- [ ] Релизный APK

### Medium
- [ ] Сгенерировать красивую иконку через Pollinations (вместо текущей placeholder)
- [ ] Splash screen
- [ ] Ориентация lock (landscape)
- [ ] Обновить AGENTS.md — раздел Android (полная инструкция)

### Отложено пользователем
- [x] ~~Мультиплеер серверная часть (сервер 45)~~ — ждём SSH доступ

## КЛЮЧЕВЫЕ ФАЙЛЫ

- `D:\Projects\BOOKWAR\ANDROID_VERSION\scripts\dev\` — dev-скрипты:
  - `build_apk.ps1` — сборка APK
  - `run_emulator.ps1` — запуск эмулятора (GPU host)
  - `install_apk.ps1` — установка + launch через monkey
  - `screenshot.ps1` — adb screencap
  - `vision.ps1` — обёртка mcp-cli
  - `test_android.ps1` — full pipeline
  - `install_template_mouse.py` — UI automation для Godot Install Android Build Template
- `D:\Projects\BOOKWAR\builds\android\bookwar.apk` — собранный APK
- `D:\Projects\BOOKWAR\export_presets.cfg` — preset.1 = Android
- `D:\Projects\BOOKWAR\android\` — gradle build template
- `D:\Projects\BOOKWAR\android\.build_version` — версия 4.6.3.stable (важна!)

## НАСТРОЙКИ ОКРУЖЕНИЯ (критичные)

- Godot: `D:\Godot\Godot_v4.6.3-stable_win64.exe`
- Android SDK: `D:\Android\Sdk`
- JAVA_HOME: `D:\Program Files\Android\Android Studio\jbr` (Java 21)
- Keystore: `~\.android\debug.keystore` (alias=androiddebugkey, pass=android)
- Editor settings: `%APPDATA%\Godot\editor_settings-4.6.tres` (SDK + keystore paths)
- Local gradle: `D:\AndroidStudioData\gradle\wrapper\dists\gradle-8.12-all\...\gradle-8.12-all.zip`
- Wrapper props: `D:\Projects\BOOKWAR\android\build\gradle\wrapper\gradle-wrapper.properties` (file:// URL)

## ГЛАВНЫЕ ОТКРЫТИЯ (БАГИ GODOT 4.6.3)

1. **`can_export()` возвращает false без объяснения** — UI показывает preset валидным, CLI падает с "configuration errors" без деталей. Workaround: включить ETC2/ASTC через `project.godot` → `[rendering] textures/vram_compression/import_etc2_astc=true`
2. **`.build_version` файл** — Godot требует `android/.build_version` с версией типа `4.6.3.stable`, без него export падает
3. **Local gradle** — gradle-wrapper скачивает gradle-8.11.1 с services.gradle.org (timeout). Workaround: указать `file:///` URL на локальный gradle 8.12 от Android Studio
4. **Install Android Build Template** — НЕ создаётся автоматически при CLI export. Только через UI меню Project → Install Android Build Template (нужен pywinauto + UIA click)
5. **Vulkan на эмуляторе** — SwiftShader падает с `GL_MAX_FRAGMENT_UNIFORM_VECTORS exceeded`. Workaround: `-gpu host` + renderer `gl_compatibility`

## СЛЕДУЮЩИЙ ШАГ

Tap на "Новая игра" → проверить запуск игровой сцены → если работает, добавить сенсор-controls.
