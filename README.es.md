# BOOKWAR

**Languages:** [English](README.md) | [Русский](README.ru.md) | [中文](README.zh-CN.md) | [Español](README.es.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Português](README.pt-BR.md) | [العربية](README.ar.md) | [日本語](README.ja.md) | [हिन्दी](README.hi.md) | [한국어](README.ko.md)

**Un juego de rol medieval sombrío construido sobre las 33 letras del alfabeto ruso — batallas de cartas, hechizos y multijugador por WebSocket.**

> **Tecnología:** Godot 4.6 / GDScript · ambientación medieval oscura · multijugador en tiempo real por WebSocket (relay en Node + ws). Resolución nativa 1280×720.

## Acerca de

BOOKWAR es un RPG cuyo avance completo se basa en el alfabeto ruso. El alfabeto ruso moderno tiene **33 letras**, por lo que el juego se estructura en **33 niveles de dificultad creciente**: cada nivel es una región afinada a mano que desbloquea nuevas letras, y cada letra es una carta de combate jugable.

Las letras se clasifican por su papel lingüístico:
- **Vocales** (А, О, Е, …) infligen **daño** (ataque).
- **Consonantes** (К, Т, Б, …) otorgan **escudo / defensa**.
- **Signos** (Ъ, Ь) funcionan como **mejoras** que potencian otras cartas.

Los monstruos derrotados sueltan letras, que gastas en **batallas de cartas** por turnos y combinas en **hechizos** (palabras). Cada letra solo puede jugarse una vez por batalla, así que el inventario es clave. El nivel 33, el final —el *Pozo de las Letras*— es una batalla masiva contra el malvado *Guardián de la Prohibición*.

## Características

- **Progresión de 33 niveles** basada en las 33 letras del alfabeto ruso.
- **Batallas de cartas por turnos** — juega cartas de letras, gestiona HP y escudos, huye o usa el autobatalla.
- **Hechizos** — palabras formadas con las letras recolectadas, desbloqueables con moneda del juego.
- **Multijugador por WebSocket** — mundo compartido, chat, intercambio de letras e invitaciones a batallas PvP.
- **Ambientación medieval sombría** en 33 regiones temáticas (Valle Claro → Pozo de las Letras).
- Multiplataforma: corre en el editor de Godot, exporta a **HTML5** y **Android**.

## Requisitos y ejecución

- **Godot 4.6** (la caché de importación `.godot/` se regenera al abrir).

**Desde el editor:**
1. `git clone https://github.com/zuluchakahuaka-nwc/bookwar`
2. Abre `project.godot` en Godot 4.6.
3. Pulsa **F5** para ejecutar (escena principal: `scenes/ui/main_menu.tscn`).

**O exporta:** usa el `export_presets.cfg` incluido (HTML5 / Android).

Controles por defecto: **WASD** mover · **E** interactuar · **I** inventario · **T** hablar · **F** atacar · **H** manual · **Space** pausa.

## Multijugador

El multijugador es un servidor relay opcional por WebSocket (`multiplayer/server.js`, Node + `ws`, puerto por defecto `4567`):

- **Host:** `node multiplayer/server.js`
- **Unirse (build web):** se conecta automáticamente a `wss://<host>/ws` (tras un proxy nginx). Sobreescribible con `?mp=ws://host:port`.
- **Unirse (nativo):** recurre a `ws://localhost:4567` (edita `DIRECT_FALLBACK_URL` o pasa una URL).

Protocolo: un objeto JSON por mensaje WebSocket (presencia, posición, chat, letras, intercambio, invitaciones de batalla).

## Estado

Trabajo en progreso / en desarrollo activo. Los 33 niveles, el combate, los hechizos y el relay están implementados; el balance y el pulido de contenido continúan. El directorio `tests/` contiene el arnés de pruebas interno del motor.

## Licencia

MIT — ver [LICENSE](LICENSE). Copyright © 2026 BOOKWAR.
