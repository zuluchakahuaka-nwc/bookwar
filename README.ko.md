# BOOKWAR

**Languages:** [English](README.md) | [Русский](README.ru.md) | [中文](README.zh-CN.md) | [Español](README.es.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Português](README.pt-BR.md) | [العربية](README.ar.md) | [日本語](README.ja.md) | [हिन्दी](README.hi.md) | [한국어](README.ko.md)

**러시아어 알파벳 33자로 구성된 어두운 중세풍 롤플레잉 게임 — 카드 배틀, 주문, 그리고 WebSocket 기반 멀티플레이.**

> **기술:** Godot 4.6 / GDScript · 다크 중세 배경 · WebSocket 기반 실시간 멀티플레이(Node + ws 릴레이). 기본 해상도 1280×720.

## 소개

BOOKWAR은 진행의 모든 것이 러시아어 알파벳에 결부된 RPG입니다. 현대 러시아어 알파벳은 **33자**이므로, 게임은 **난이도가 점진적으로 높아지는 33개 레벨**로 구성됩니다. 각 레벨은 새로운 글자를 여는 수작업 지역이며, 각 글자는 플레이 가능한 전투 카드가 됩니다.

글자는 언어적 역할에 따라 분류됩니다:
- **모음**(А, О, Е…)은 **피해**(공격)를 줍니다.
- **자음**(К, Т, Б…)은 **방패 / 방어**를 부여합니다.
- **기호**(Ъ, Ь)는 다른 카드를 증폭하는 **버프**로 작용합니다.

쓰러뜨린 몬스터는 글자를 떨어뜨리고, 이를 턴제 **카드 배틀**에 사용하며 **주문**(단어)으로 조합합니다. 글자는 전투당 한 번만 낼 수 있어 소지품이 중요합니다. 33번째이자 마지막 레벨인 「글자의 우물」은 사악한 「금지의 수호자」를 상대로 한 대규모 전투입니다.

## 특징

- 러시아어 알파벳 33자에 대응하는 **33레벨 진행**.
- **턴제 카드 배틀** — 글자 카드를 내고, HP와 방패를 관리하며, 도주하거나 자동 전투를 켭니다.
- **주문** — 모은 글자로 단어를 만들어 게임 내 화폐로 해금합니다.
- **WebSocket 멀티플레이** — 공유 세계, 채팅, 글자 거래, PvP 결투 초대.
- 33개의 테마 지역(빛의 계곡 → 글자의 우물)에 펼쳐지는 **다크 중세 배경**.
- 크로스 플랫폼: Godot 에디터에서 실행, **HTML5**와 **Android**로 내보내기.

## 요구 사항 및 실행

- **Godot 4.6**(처음 열 때 `.godot/` 가져오기 캐시가 재생성됩니다).

**에디터에서:**
1. `git clone https://github.com/zuluchakahuaka-nwc/bookwar`
2. Godot 4.6에서 `project.godot`을 엽니다.
3. **F5**를 눌러 실행(메인 씬: `scenes/ui/main_menu.tscn`).

**또는 내보내기:** 포함된 `export_presets.cfg`를 사용하세요(HTML5 / Android).

기본 조작: **WASD** 이동 · **E** 상호작용 · **I** 소지품 · **T** 대화 · **F** 공격 · **H** 설명서 · **Space** 일시 정지.

## 멀티플레이

멀티플레이는 선택적 WebSocket 릴레이 서버(`multiplayer/server.js`, Node + `ws`, 기본 포트 `4567`)입니다:

- **호스트:** `node multiplayer/server.js`
- **참여(웹 빌드):** `wss://<host>/ws`에 자동 연결(nginx 프록시 뒤). `?mp=ws://host:port`로 재정의.
- **참여(네이티브):** `ws://localhost:4567`로 폴백(`DIRECT_FALLBACK_URL` 편집 또는 URL 전달).

프로토콜: WebSocket 메시지당 JSON 객체 1개(프레젠스, 위치, 채팅, 글자, 거래, 배틀 초대).

## 상태

개발 중 / 활발히 개발 중. 33개 레벨 전체, 전투, 주문, 릴레이 서버가 구현되었으며 밸런스와 콘텐츠 다듬기가 계속됩니다. `tests/` 디렉터리에 엔진 내장 테스트 하네스가 있습니다.

## 라이선스

MIT — [LICENSE](LICENSE) 참조. Copyright © 2026 BOOKWAR.
