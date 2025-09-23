AGENTS.md — Engineering Guide for Codex & Other Agents
======================================================

Scope
-----
This file distills the practical guidance (informed by CLAUDE.md) for any coding agent working on this repository (with Codex CLI as the primary client). It defines responsibilities, invariants, and change‑management rules so that automated edits remain safe, reversible, and performant.

Project Overview
----------------
PingFighter is a Python/Pygame arcade boss‑pong game. The codebase mixes legacy and modularized systems, with ongoing refactors. Cross‑platform packaging (PyInstaller) is supported. Most gameplay lives in `pingfighter.py`, but new systems are moving into modular folders.

Agent Responsibilities
----------------------
1) Be surgical: prefer small, localized patches with clear intent and easy rollback.
2) Preserve gameplay invariants (see below) and performance at 60 FPS.
3) Respect resource packing rules so dev run and PyInstaller both work.
4) Avoid large structural changes unless explicitly requested.
5) Prefer feature flags/toggles over breaking behavior; default to safe fallbacks.

Critical Invariants
-------------------
- Resource loading must go through `resource_path(relative_path)`.
- Game must not freeze the main loop; heavy work needs amortization or guards.
- Collision & gauge rules:
  - While “Stopwatch” is active (time frozen), disable paddle collision & gauge gain.
  - After stopwatch recovery, enforce upward trajectory lock only as specified (and clear it on boss hit / round reset).
- Round/Stage transitions must reset transient state:
  - Stopwatch/Smartphone flags, timers, and locks (e.g., `stopwatch_forced_upward`, `stopwatch_upward_lock_timer`).
  - Dash, stun, knockback, temporary FX/particles that should not leak across rounds.
- Any gameplay slow/slowdown effect must reuse the shared slow-wave visual (`create_slow_wave_surface`) so movement debuffs stay consistent.

Resource & Packaging
--------------------
- Always load assets via `resource_path()`; never use raw relative paths.
- Keep newly added assets in appropriate folders; avoid renaming existing assets casually.
- When adding fonts/images/sounds, ensure dev + PyInstaller environments are both supported.

Item Integration
----------------
- 아이템 아이콘은 32x32 기준으로 `items/`에 저장하고 `items.load_item_icons()` 매핑에 등록한다. 새로운 이미지는 기존 스타일(예: `legendary/` 전설 효과, 일반 아이콘의 색감/윤곽선)을 참고해 무드에 맞게 제작하며, 모든 로드는 `resource_path()` 경유를 유지한다.
- 신규 아이템을 `items.ITEM_TYPES`, `items.unlocked_items`, `items.spawn_random_item()` 필터, `items.reset_items()` 초기화 목록에 추가해 확률/해금/중복 방지 상태가 연결되도록 한다. 패시브 전용 상태 플래그가 필요한 경우 `game_logic/item_manager.ItemManager.item_states`와 `_is_item_limited()`에도 동일한 키를 추가한다.
- 패시브 아이템은 단일 획득만 허용되므로 `gacha.init_gacha()`의 중복 필터에 신규 키를 반영하고, 필요 시 `items` 모듈 내부의 `*_obtained` 플래그를 재사용한다. 가챠 후보 리스트(`available_items`)에 빠짐없이 포함했는지 확인한다.
- 효과 구현 시 `pingfighter.store_passive_item()` 또는 `store_active_item()`에 분기와 리셋 로직을 추가하고, `game_logic/item_system.ItemSystem.item_definitions`(UI/툴팁)·`effects/item_acquisition.py`(획득 연출)·관련 사용 함수에 동일한 네이밍으로 연결한다. 게임 복귀·사망·스테이지 리셋 시 `items.reset_items()`과 `ItemManager.reset()`이 모든 버프/슬롯/보유 목록을 비우도록 신규 상태 값을 반드시 초기화한다.
- 메인 메뉴 단축키 2번으로 진입하는 아이템 관리자 화면은 `passive_item_list`·`active_item_slot`과 `ItemManager` 데이터를 그대로 참조하므로, 신규 아이템이 해당 리스트에 들어오면 UI 탭(패시브/액티브)과 슬롯에도 자동 노출되게 동일한 자료구조를 사용한다. 별도 표시 규칙이 필요하면 `pingfighter` 아이템 관리자 렌더 함수에서만 최소 수정으로 처리한다.
- 새 아이템 추가 후에는 필드 드롭 → 획득 이펙트 → 탭/슬롯 반영 → 가챠 등장/제외 → 사망 또는 메인 메뉴 복귀 시 초기화 순서를 직접 확인해 중복 스폰, 잔여 버프, UI 싱크 미스가 없는지 테스트한다.
- 전설 아이템은 `legendary_items._draw_common_legendary_frame()` 기반 템플릿을 사용해 사각 프레임·파란 원형 펄싱·금색 코너 장식을 공유하고, 개별 아이콘/주요 이펙트만 서브클래스에서 오버레이한다.

Coding Standards
----------------
- Python 3.10+ style, readable names, minimal global churn.
- Prefer pure functions and narrow, explicit mutations.
- Keep logging/prints behind debug guards when noisy.
- For big switches/if‑else on state, extract helpers with clear contracts.

Performance Rules
-----------------
- Rendering: avoid per‑frame surface creation/scaling; pre‑compute or cache.
- Physics/AI: keep per‑frame math cheap; use cooldowns/timers/locks to prevent thrash.
- Avoid tight loops over large ranges in the main thread; use sampling windows.

Stopwatch & Smartphone (Smartphone‑triggered Stopwatch)
-------------------------------------------------------
- During freeze: no paddle collision or gauge gain.
- Recovery:
  - Gradual speed restoration; maintain direction unless explicitly overridden.
  - If triggered by Smartphone, force upward (boss) direction at recovery end and keep a short upward‑lock.
  - Upward‑lock must be cleared on boss paddle contact and on round reset/next round.

Error Handling & Safety
----------------------
- Prefer early returns and explicit guards over implicit state transitions.
- When new globals are required, declare them next to related globals and `global` in functions that mutate them.
- Avoid catching broad Exceptions unless forwarding a clear message or re‑raising with context.

Testing & Validation
--------------------
- Small patches: sanity‑test by running the game, observing FPS/inputs, and checking crash logs.
- Use debug prints sparingly; wrap behind conditions or temporary flags and remove before finalizing large changes.
- If adding new configuration or feature flags, default them to off or conservative behavior.

MCP / External Tools
--------------------
- MCP is supported via external runner in `mcp/` (Codex doesn’t auto‑attach).
- Do not hard‑code secrets; use `mcp/.env` (git‑ignored) or environment variables.

Secrets & Security
------------------
- Never commit API keys or tokens; scrub tokens from git remotes and scripts.
- Prefer `os.getenv("NAME")` for runtime configuration; provide `.env.example` when helpful.

Change Management
-----------------
- Use one `apply_patch` per logical change; include concise commit‑style titles in PR/commit messages (if used externally).
- Add brief comments when changing gameplay‑critical logic (e.g., stopwatch locks), focusing on intent and invariants.
- Do not rename files or functions casually; preserve public interfaces unless explicitly approved.

Quick Checklist for PR‑Quality Patches
--------------------------------------
1) Resource paths use `resource_path`.
2) No stopwatch/gauge violations; rounds reset transient state.
3) No busy loops or heavy allocations in the frame loop.
4) Debug prints are temporary or gated.
5) Minimal blast radius; rollback is trivial.


Workspace Notes
---------------
- Primary working directory: /Volumes/T7/윈도우용최신/game/bosspong
- 답변 언어: 한국어 전용 (추가 요청 전까지)
