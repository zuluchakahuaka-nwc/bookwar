# BOOKWAR

**Languages:** [English](README.md) | [Русский](README.ru.md) | [中文](README.zh-CN.md) | [Español](README.es.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Português](README.pt-BR.md) | [العربية](README.ar.md) | [日本語](README.ja.md) | [हिन्दी](README.hi.md) | [한국어](README.ko.md)

**A grim-medieval role-playing game built on the 33 letters of the Russian alphabet — card battles, spells, and WebSocket multiplayer.**

> **Tech:** Godot 4.6 / GDScript · grim-dark medieval setting · real-time multiplayer over WebSocket (Node + ws relay). Native resolution 1280×720.

## About

BOOKWAR is an RPG whose entire progression is the Russian alphabet. The modern Russian alphabet has **33 letters**, so the game is structured as **33 levels of escalating difficulty**: each level is a hand-tuned region that unlocks new letters, and every letter is a playable combat card.

Letters are classified by their linguistic role:
- **Vowels** (А, О, Е, …) deal **attack** damage.
- **Consonants** (К, Т, Б, …) raise **shields / defense**.
- **Signs** (Ъ, Ь) act as **buffs** that amplify other cards.

Defeated monsters drop letters, which you spend in turn-based **card battles** and combine into **spells** (words). Each letter may be played only once per battle, so a deep inventory matters. The 33rd and final level — the *Well of Letters* — is a mass battle against the evil *Keeper of the Ban*.

## Features

- **33-level progression** keyed to the 33 letters of the Russian alphabet.
- **Turn-based card battles** — play letter cards, manage HP and shields, flee, or auto-battle.
- **Spells** — words assembled from collected letters, unlocked with in-game currency.
- **WebSocket multiplayer** — shared world, chat, letter trading, and PvP battle invites.
- **Grim-medieval setting** across 33 themed regions (Light Valley → Well of Letters).
- Cross-platform: runs in the Godot editor, exports to **HTML5** and **Android**.

## Requirements & Run

- **Godot 4.6** (the `.godot/` import cache regenerates on first open).

**From the editor:**
1. `git clone https://github.com/zuluchakahuaka-nwc/bookwar`
2. Open `project.godot` in Godot 4.6.
3. Press **F5** to run (main scene: `scenes/ui/main_menu.tscn`).

**Or export:** use the bundled `export_presets.cfg` (HTML5 / Android).

Default controls: **WASD** move · **E** interact · **I** inventory · **T** talk · **F** attack · **H** manual · **Space** pause.

## Multiplayer

Multiplayer is an optional WebSocket relay server (`multiplayer/server.js`, Node + `ws`, default port `4567`):

- **Host:** `node multiplayer/server.js`
- **Join (web build):** auto-connects to `wss://<host>/ws` (behind an nginx proxy). Override with `?mp=ws://host:port`.
- **Join (native):** falls back to `ws://localhost:4567` (edit `DIRECT_FALLBACK_URL` or pass a URL).

Protocol: one JSON object per WebSocket message (presence, position, chat, letters, trade, battle invites).

## Status

Work in progress / under active development. All 33 levels, combat, spells, and the relay server are implemented; balancing and content polish continue. The included `tests/` directory holds the in-engine test harness.

## License

MIT — see [LICENSE](LICENSE). Copyright © 2026 BOOKWAR.
