# BOOKWAR

**Languages:** [English](README.md) | [Русский](README.ru.md) | [中文](README.zh-CN.md) | [Español](README.es.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Português](README.pt-BR.md) | [العربية](README.ar.md) | [日本語](README.ja.md) | [हिन्दी](README.hi.md) | [한국어](README.ko.md)

**Ein düster-mittelalterliches Rollenspiel, das auf den 33 Buchstaben des russischen Alphabets basiert — Kartenschlachten, Zauber und Mehrspieler über WebSocket.**

> **Technik:** Godot 4.6 / GDScript · düster-mittelalterliche Stimmung · Echtzeit-Mehrspieler über WebSocket (Relay auf Node + ws). Native Auflösung 1280×720.

## Über das Spiel

BOOKWAR ist ein RPG, dessen gesamter Fortschritt auf dem russischen Alphabet beruht. Das moderne russische Alphabet hat **33 Buchstaben**, daher ist das Spiel in **33 Stufen steigender Schwierigkeit** gegliedert: Jede Stufe ist eine hand-abgestimmte Region, die neue Buchstaben freischaltet, und jeder Buchstabe ist eine spielbare Kampfkarte.

Die Buchstaben werden nach ihrer sprachlichen Rolle eingeteilt:
- **Selbstlaute/Vokale** (А, О, Е, …) verursachen **Schaden** (Angriff).
- **Mitlaute/Konsonanten** (К, Т, Б, …) gewähren **Schild / Verteidigung**.
- **Zeichen** (Ъ, Ь) wirken als **Buffs**, die andere Karten verstärken.

Besiegte Monster lassen Buchstaben fallen, die du in rundenbasierten **Kartenschlachten** einsetzt und zu **Zaubern** (Wörtern) kombinierst. Jeder Buchstabe ist nur einmal pro Kampf spielbar, daher zählt ein starkes Inventar. Die 33. und letzte Stufe — der *Brunnen der Buchstaben* — ist eine Massenschlacht gegen den bösen *Hüter des Banns*.

## Features

- **33-stufige Progression**, gebunden an die 33 Buchstaben des russischen Alphabets.
- **Rundenbasierte Kartenschlachten** — spiele Buchstabenkarten, verwalte LP und Schilde, fliehe oder nutze Auto-Kampf.
- **Zauber** — aus gesammelten Buchstaben gebildete Wörter, freischaltbar mit Ingame-Währung.
- **WebSocket-Mehrspieler** — gemeinsame Welt, Chat, Buchstabenhandel und PvP-Kampfeinladungen.
- **Düster-mittelalterliches Setting** über 33 thematische Regionen (Lichtes Tal → Brunnen der Buchstaben).
- Plattformübergreifend: läuft im Godot-Editor, exportiert nach **HTML5** und **Android**.

## Voraussetzungen & Start

- **Godot 4.6** (der Import-Cache `.godot/` wird beim ersten Öffnen neu erzeugt).

**Aus dem Editor:**
1. `git clone https://github.com/zuluchakahuaka-nwc/bookwar`
2. `project.godot` in Godot 4.6 öffnen.
3. **F5** drücken zum Starten (Hauptszene: `scenes/ui/main_menu.tscn`).

**Oder exportieren:** das mitgelieferte `export_presets.cfg` verwenden (HTML5 / Android).

Standardsteuerung: **WASD** bewegen · **E** interagieren · **I** Inventar · **T** sprechen · **F** angreifen · **H** Handbuch · **Space** Pause.

## Mehrspieler

Mehrspieler ist ein optionaler WebSocket-Relay-Server (`multiplayer/server.js`, Node + `ws`, Standard-Port `4567`):

- **Hosten:** `node multiplayer/server.js`
- **Beitreten (Web-Build):** verbindet sich automatisch mit `wss://<host>/ws` (hinter einem nginx-Proxy). Überschreibbar per `?mp=ws://host:port`.
- **Beitreten (nativ):** Fallback auf `ws://localhost:4567` (`DIRECT_FALLBACK_URL` anpassen oder URL übergeben).

Protokoll: ein JSON-Objekt pro WebSocket-Nachricht (Präsenz, Position, Chat, Buchstaben, Handel, Kampfeinladungen).

## Status

In Arbeit / in aktiver Entwicklung. Alle 33 Level, Kampf, Zauber und der Relay-Server sind implementiert; Balancing und Content-Politur laufen weiter. Das Verzeichnis `tests/` enthält das engine-interne Test-Framework.

## Lizenz

MIT — siehe [LICENSE](LICENSE). Copyright © 2026 BOOKWAR.
