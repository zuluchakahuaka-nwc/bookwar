# BOOKWAR

**Languages:** [English](README.md) | [Русский](README.ru.md) | [中文](README.zh-CN.md) | [Español](README.es.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Português](README.pt-BR.md) | [العربية](README.ar.md) | [日本語](README.ja.md) | [हिन्दी](README.hi.md) | [한국어](README.ko.md)

**Un jeu de rôle médiéval sombre construit sur les 33 lettres de l'alphabet russe — batailles de cartes, sorts et multijoueur via WebSocket.**

> **Technique :** Godot 4.6 / GDScript · univers médiéval dark fantasy · multijoueur en temps réel via WebSocket (relais Node + ws). Résolution native 1280×720.

## À propos

BOOKWAR est un RPG dont toute la progression repose sur l'alphabet russe. L'alphabet russe moderne comporte **33 lettres** : le jeu est donc découpé en **33 niveaux de difficulté croissante**, chacun étant une région réglée à la main qui débloque de nouvelles lettres, chaque lettre étant une carte de combat jouable.

Les lettres sont classées selon leur rôle linguistique :
- **Voyelles** (А, О, Е, …) infligent des **dégâts** (attaque).
- **Consonnes** (К, Т, Б, …) apportent un **bouclier / défense**.
- **Signes** (Ъ, Ь) agissent comme des **bonus** amplifiant d'autres cartes.

Les monstres vaincus lâchent des lettres, que vous dépensez dans des **batailles de cartes** au tour par tour et combinez en **sorts** (mots). Chaque lettre ne se joue qu'une fois par combat : la richesse de l'inventaire est donc décisive. Le 33e et dernier niveau — le *Puits des Lettres* — est une bataille massive contre le malveillant *Gardien de l'Interdit*.

## Fonctionnalités

- **Progression en 33 niveaux** adossée aux 33 lettres de l'alphabet russe.
- **Batailles de cartes au tour par tour** — jouez des cartes-lettres, gérez PV et boucliers, fuyez ou activez l'auto-combat.
- **Sorts** — mots assemblés à partir des lettres collectées, débloqués avec la monnaie du jeu.
- **Multijoueur via WebSocket** — monde partagé, chat, échange de lettres et invitations aux duels PvP.
- **Ambiance médiévale sombre** à travers 33 régions thématiques (Vallée Lumineuse → Puits des Lettres).
- Multiplateforme : tourne dans l'éditeur Godot, exporte en **HTML5** et **Android**.

## Prérequis et lancement

- **Godot 4.6** (le cache d'import `.godot/` se régénère à la première ouverture).

**Depuis l'éditeur :**
1. `git clone https://github.com/zuluchakahuaka-nwc/bookwar`
2. Ouvrez `project.godot` dans Godot 4.6.
3. Appuyez sur **F5** pour lancer (scène principale : `scenes/ui/main_menu.tscn`).

**Ou exportez :** utilisez le `export_presets.cfg` fourni (HTML5 / Android).

Contrôles par défaut : **WASD** se déplacer · **E** interagir · **I** inventaire · **T** parler · **F** attaquer · **H** manuel · **Space** pause.

## Multijoueur

Le multijoueur repose sur un serveur relais WebSocket optionnel (`multiplayer/server.js`, Node + `ws`, port par défaut `4567`) :

- **Héberger :** `node multiplayer/server.js`
- **Rejoindre (build web) :** connexion auto à `wss://<host>/ws` (derrière un proxy nginx). Surchargé via `?mp=ws://host:port`.
- **Rejoindre (natif) :** repli sur `ws://localhost:4567` (modifiez `DIRECT_FALLBACK_URL` ou passez une URL).

Protocole : un objet JSON par message WebSocket (présence, position, chat, lettres, échange, invitations de combat).

## État

Travail en cours / développement actif. Les 33 niveaux, le combat, les sorts et le relais sont implémentés ; l'équilibrage et le polish du contenu continuent. Le dossier `tests/` contient le harnais de tests interne au moteur.

## Licence

MIT — voir [LICENSE](LICENSE). Copyright © 2026 BOOKWAR.
