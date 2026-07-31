# BOOKWAR

**Languages:** [English](README.md) | [Русский](README.ru.md) | [中文](README.zh-CN.md) | [Español](README.es.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Português](README.pt-BR.md) | [العربية](README.ar.md) | [日本語](README.ja.md) | [हिन्दी](README.hi.md) | [한국어](README.ko.md)

**Um RPG medieval sombrio construído sobre as 33 letras do alfabeto russo — batalhas de cartas, feitiços e multijogador via WebSocket.**

> **Tecnologia:** Godot 4.6 / GDScript · cenário medieval sombrio · multijogador em tempo real via WebSocket (relay em Node + ws). Resolução nativa 1280×720.

## Sobre

BOOKWAR é um RPG cuja progressão inteira gira em torno do alfabeto russo. O alfabeto russo moderno tem **33 letras**, então o jogo é estruturado em **33 níveis de dificuldade crescente**: cada nível é uma região ajustada à mão que desbloqueia novas letras, e cada letra é uma carta de combate jogável.

As letras são classificadas pelo seu papel linguístico:
- **Vogais** (А, О, Е, …) causam **dano** (ataque).
- **Consoantes** (К, Т, Б, …) concedem **escudo / defesa**.
- **Sinais** (Ъ, Ь) atuam como **aprimoramentos** que potencializam outras cartas.

Monstros derrotados soltam letras, que você gasta em **batalhas de cartas** por turnos e combina em **feitiços** (palavras). Cada letra só pode ser jogada uma vez por batalha, então um bom inventário é decisivo. O 33º e último nível — o *Poço das Letras* — é uma batalha em massa contra o perverso *Guardião da Proibição*.

## Recursos

- **Progressão de 33 níveis** vinculada às 33 letras do alfabeto russo.
- **Batalhas de cartas por turnos** — jogue cartas de letras, gerencie HP e escudos, fuja ou use o auto-combate.
- **Feitiços** — palavras formadas com as letras coletadas, desbloqueadas com a moeda do jogo.
- **Multijogador via WebSocket** — mundo compartilhado, chat, troca de letras e convites para duelos PvP.
- **Cenário medieval sombrio** em 33 regiões temáticas (Vale Claro → Poço das Letras).
- Multiplataforma: roda no editor da Godot, exporta para **HTML5** e **Android**.

## Requisitos e execução

- **Godot 4.6** (o cache de importação `.godot/` é regenerado na primeira abertura).

**Pelo editor:**
1. `git clone https://github.com/zuluchakahuaka-nwc/bookwar`
2. Abra `project.godot` no Godot 4.6.
3. Pressione **F5** para executar (cena principal: `scenes/ui/main_menu.tscn`).

**Ou exporte:** use o `export_presets.cfg` incluído (HTML5 / Android).

Controles padrão: **WASD** mover · **E** interagir · **I** inventário · **T** conversar · **F** atacar · **H** manual · **Space** pausar.

## Multijogador

O multijogador é um servidor de relay WebSocket opcional (`multiplayer/server.js`, Node + `ws`, porta padrão `4567`):

- **Hospedar:** `node multiplayer/server.js`
- **Entrar (build web):** conecta-se automaticamente a `wss://<host>/ws` (atrás de um proxy nginx). Sobrescreva com `?mp=ws://host:port`.
- **Entrar (nativo):** recai para `ws://localhost:4567` (edite `DIRECT_FALLBACK_URL` ou passe uma URL).

Protocolo: um objeto JSON por mensagem WebSocket (presença, posição, chat, letras, troca, convites de batalha).

## Status

Trabalho em andamento / em desenvolvimento ativo. Todos os 33 níveis, o combate, os feitiços e o relay estão implementados; o balanceamento e o polimento de conteúdo continuam. O diretório `tests/` contém a suíte de testes interna da engine.

## Licença

MIT — veja [LICENSE](LICENSE). Copyright © 2026 BOOKWAR.
