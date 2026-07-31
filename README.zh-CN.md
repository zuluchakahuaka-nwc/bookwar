# BOOKWAR

**Languages:** [English](README.md) | [Русский](README.ru.md) | [中文](README.zh-CN.md) | [Español](README.es.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Português](README.pt-BR.md) | [العربية](README.ar.md) | [日本語](README.ja.md) | [हिन्दी](README.hi.md) | [한국어](README.ko.md)

**一款基于俄语字母表 33 个字母构建的黑暗中世纪角色扮演游戏——卡牌战斗、法术，以及基于 WebSocket 的多人模式。**

> **技术：** Godot 4.6 / GDScript · 黑暗中世纪题材 · 基于 WebSocket 的实时多人模式（Node + ws 中继）。原生分辨率 1280×720。

## 关于

BOOKWAR 是一款完全围绕俄语字母表展开的 RPG。现代俄语字母表共有 **33 个字母**，因此游戏被设计为 **33 个难度递增的关卡**：每一关都是一张精心调校的区域地图，会解锁新的字母，而每个字母都是一张可参战的卡牌。

字母按其语言学作用分类：
- **元音**（А、О、Е……）造成 **伤害**（攻击）。
- **辅音**（К、Т、Б……）提供 **护盾 / 防御**。
- **符号**（Ъ、Ь）作为 **增益**，放大其他卡牌。

被击败的怪物会掉落字母，你在回合制 **卡牌战斗** 中消耗它们，并把它们组合成 **法术**（单词）。每个字母在每场战斗中只能打出一次，因此库存的深度至关重要。第 33 关——也就是最终关「字母之井」——是一场对抗邪恶「禁令守护者」的大规模战役。

## 特性

- **33 级进度**，与俄语字母表的 33 个字母一一对应。
- **回合制卡牌战斗**——打出字母卡，管理生命值与护盾，逃跑或开启自动战斗。
- **法术**——由收集到的字母拼成单词，用游戏内货币解锁。
- **基于 WebSocket 的多人模式**——共享世界、聊天、字母交易以及 PvP 决斗邀请。
- **黑暗中世纪氛围**，横跨 33 个主题区域（光明之谷 → 字母之井）。
- 跨平台：可在 Godot 编辑器中运行，也可导出至 **HTML5** 与 **Android**。

## 环境要求与运行

- **Godot 4.6**（首次打开时会重新生成 `.godot/` 导入缓存）。

**从编辑器运行：**
1. `git clone https://github.com/zuluchakahuaka-nwc/bookwar`
2. 在 Godot 4.6 中打开 `project.godot`。
3. 按 **F5** 运行（主场景：`scenes/ui/main_menu.tscn`）。

**或导出：** 使用自带的 `export_presets.cfg`（HTML5 / Android）。

默认操作：**WASD** 移动 · **E** 互动 · **I** 背包 · **T** 对话 · **F** 攻击 · **H** 手册 · **Space** 暂停。

## 多人模式

多人模式是一个可选的 WebSocket 中继服务器（`multiplayer/server.js`，Node + `ws`，默认端口 `4567`）：

- **开服：** `node multiplayer/server.js`
- **加入（网页版）：** 自动连接到 `wss://<host>/ws`（位于 nginx 反代之后）。可用 `?mp=ws://host:port` 覆盖。
- **加入（原生端）：** 回退到 `ws://localhost:4567`（修改 `DIRECT_FALLBACK_URL` 或传入 URL）。

协议：每条 WebSocket 消息一个 JSON 对象（在线状态、位置、聊天、字母、交易、战斗邀请）。

## 状态

开发中 / 持续开发中。全部 33 个关卡、战斗、法术和中继服务器均已实现；数值平衡与内容打磨仍在继续。`tests/` 目录包含引擎内置的测试框架。

## 许可证

MIT——见 [LICENSE](LICENSE)。Copyright © 2026 BOOKWAR。
