# 경로 선택 화면 잔재 정리 완료 보고 (2026-08-21)

## 1. 구성 판정

`docs/tower_ascent_run_map_plan.md` §3.2의 “별도 발사 화면 없음·실제 플레이어의 실제 서브”를 유지하되, 이 목표의 더 최신이고 구체적인 **이전 보스 0픽셀** 계약을 우선했다. 따라서 §3.2의 “패배 보스 시트 유지” 한 항목은 이번 화면 정리에서 대체된다. 같은 전투 씬/실제 런타임을 계속 사용하지만, 전투 씬의 전체 시각 패스를 다시 그린다는 뜻은 아니다.

| 구성 요소 | 판정 | 생산 소유자 / 이유 |
|---|---|---|
| 필러 배경·공용 필러 HUD | 유지 | 기존 pillar scene/HUD 패스. 점수, 재화, 플레이어 상태, 액티브 아이템 등 경로 서브에 필요한 공용 정보는 유지한다. |
| 플레이필드 테두리 | 복원 | `battle_playfield_scene_drawer.draw_tower_route_playfield_border()`만 개별 호출한다. 이동 공의 760×750 경계를 명확히 보인다. |
| 플레이어 캐릭터 | 복원 | 현재 스테이지 actor renderer가 이미 소유한 사전 예열 `player_renderer`만 재사용한다. 플레이어가 직접 실제 서브를 한다는 §3.2 정체성을 유지한다. |
| 표적·실제 노드명·각도 게이지·안내 | 유지 | 기존 `tower_ascent_flow_owner.draw()` 경로를 그대로 유지한다. |
| 실제 선택 공 | 유지 | 기존 `draw_tower_route_selector_ball()` → 생산 ball drawer 경로를 그대로 유지한다. 별도 가짜 공을 만들지 않는다. |
| 이전 보스·스테이지 아레나·풍선/장애물·전투 조명/오버레이 | 제거 | 전체 `_draw_playfield_scene()`를 경로 화면에서 호출하지 않는다. 이 패스는 필요한 것보다 훨씬 넓은 전투 소유 집합이다. |
| 이전 보스 스킬카드 레일/보스 전용 게이지 | 제거 | Tower flow가 활성인 동안 Stage 1 공용 Dalji/Gaksi 레일과 Stage 2~8 전용 레일을 억제한다. 전투/비탑에서는 기존 경로로 복귀한다. |
| detached actor FX·전투 loop audio | 제거/정지 | 경로 플레이어를 그리기 전에 현재 actor renderer의 transient host를 명시 정리한다. Tower 진입은 기존 modal lifecycle의 전역 gameplay loop-audio cleanup을 통과함을 씰로 확인했다. |

## 2. 원인과 소유자

### 초기 Stage 1 경로 화면

기존 `_should_draw_tower_battle_playfield()`는 “렌더 가능한 비전투 배경이 보존됨”일 때만 전체 전투 패스를 막았다. 전투 직후 최초 `ROUTE_AIM`에는 보존 배경이 없으므로 전체 `_draw_playfield_scene()`이 다시 열렸고, 이전 보스와 Stage 1 오브젝트가 함께 그려졌다.

Stage 1 풍선의 실제 드로우 소유 경로는 다음과 같다.

- `godot/scripts/core/battle_playfield_scene_drawer.gd:218` — full draw의 `_draw_stage1_balloon_background()` 호출
- `godot/scripts/core/battle_playfield_scene_drawer.gd:261` — full draw의 `_draw_stage1_balloon_foreground()` 호출
- `godot/scripts/core/battle_playfield_scene_drawer.gd:776`, `:813` — Stage 1 balloon event로 위임하는 두 소유 함수
- `godot/scripts/stages/stage1/stage1_balloon_event.gd:797` — 실제 개별 풍선 `_draw_balloon()`

수정 후 active `ROUTE_AIM`은 보존 배경 유무와 관계없이 full draw를 막는다. 대신 `battle_scene_drawer.gd:221-243`에서 테두리, 플레이어, 선택 공을 이름으로 지목해 순서대로 호출한 뒤 Tower 표적/게이지를 그린다.

### 수련장 복귀의 달지 스킬 레일

비전투 배경이 full playfield를 막아도 post-playfield pillar HUD는 계속 그려졌다. Stage 1 공용 active-item HUD는 기본적으로 Dalji/Gaksi boss rail까지 포함했고, 각 후속 스테이지 pillar drawer도 자기 boss rail을 별도로 붙였다.

- 공통 억제 컨텍스트 주입: `godot/scripts/core/battle_scene_drawer.gd:515`
- Stage 1 Dalji/Gaksi rail gate: `godot/scripts/stages/stage1/stage1_pillar_hud_scene_drawer.gd:206`
- Stage 2~8 전용 rail gates: 각 `stage*_pillar_scene_drawer.gd`의 `suppress_boss_skill_hud` 검사

골드/무혼·액티브 아이템 HUD는 gate 이전에 계속 그리며, 보스 전용 레일만 빠진다. active Tower flow가 끝나면 플래그가 false가 되어 전투와 비탑 캠페인의 보스 레일이 원상 복귀한다.

### 빠진 테두리·플레이어와 detached 소유권

이전 좁은 경로는 `draw_tower_route_selector_ball()` 하나만 호출했다. 다음의 작은 생산 슬라이스를 추가했다.

- `godot/scripts/core/battle_playfield_scene_drawer.gd:43` — code-native 경로 테두리
- `godot/scripts/core/battle_playfield_scene_drawer.gd:57` — 생산 draw/actor context를 구축하는 플레이어 전용 진입점
- `godot/scripts/core/battle_playfield_effects_drawer.gd:48` — 현재 stage actor renderer의 transient host를 먼저 clear하고, 기존 prewarmed `player_renderer`만 호출

플레이어 복원 때문에 stage actor 전체를 다시 부르지 않으며 boss renderer, stage playfield renderer, firearm combat renderer를 그리지 않는다. Tower modal lifecycle은 `godot/scripts/tower_ascent/tower_ascent_modal_lifecycle.gd:27`에서 `GameplayLoopAudioCleanup.stop_all(audio)`를 호출한다. 신규 씰은 Stage 2/5 loop 정지 메서드가 실제 호출되는 역을 확인했다.

## 3. 씰과 픽셀 증거

새 focused seal `tower_route_screen_cleanup_smoke.gd`를 CI와 pre-push 두 리터럴 목록에 동시에 추가했다. 두 목록은 **193 → 194**로 동일하다. 별도 `_leg_count` 상수는 이 목록에 없어서 갱신 대상이 없었다. 기존 `tower_noncombat_node_background_retention_smoke.gd`도 초기(보존 배경 없음) `ROUTE_AIM`과 테두리/플레이어/공 세 슬라이스를 검사하도록 개정했다.

비헤드리스 래퍼 `run_tower_noncombat_return_selector_visual_qa.ps1`는 2020×1246 Vulkan Forward Mobile에서 5장을 캡처한다. 성공 실행에는 `SCRIPT ERROR`가 없었고 wrapper classifier가 GREEN을 반환했다.

| 레그 | 단언 결과 |
|---|---|
| Stage 1 최초 경로 | `full_draw=0`; 테두리 호출 8, paired delta 57,288px; 플레이어 호출 8, paired delta 2,844px; 이전 보스 0px; 이전 stage object 0px; boss rail 호출/픽셀 0/0 |
| 수련장 복귀 경로 | 실제 `production_route_serve_runtime._serve_live_ball`; selector 호출 8, bright delta 909px; `full_draw=0`; 이전 보스 0px; 이전 stage object 0px; boss rail 0px |
| 전투 복귀 reverse | full draw 8; boss sentinel 13,225px; stage-object sentinel 10,816px; boss rail 4,096px |
| 비탑 일반 캠페인 reverse | full draw 8; boss/stage sentinels threshold 통과; boss rail 4,096px |

캡처:

- `godot/.godot/codex_captures/tower_noncombat_return_selector/stage1_initial_route_clean.png`
- `godot/.godot/codex_captures/tower_noncombat_return_selector/training_node_modal_no_previous_boss.png`
- `godot/.godot/codex_captures/tower_noncombat_return_selector/training_return_route_clean.png`
- `godot/.godot/codex_captures/tower_noncombat_return_selector/combat_return_restored.png`
- `godot/.godot/codex_captures/tower_noncombat_return_selector/nontower_campaign_unchanged.png`

## 4. 검증 결과

| 게이트 | 결과 |
|---|---|
| focused smokes | `PASS=2 FAIL=0 TOTAL=2`, 종단선 `All Godot smoke tests passed.` |
| touched-file warning scan | 15/15, GDScript warning 0 |
| headless load | PASS, graceful shutdown |
| Vulkan 2020×1246 visual QA | PASS, captures=5, `SCRIPT ERROR` 0 |
| `git diff --check` | PASS |
| repository-wide nightly discovery | **baseline-blocked (scoped gate 아님)** — 1,404개 중 397번째 `gravity_accel_cast_no_loop_bleed_smoke.gd`가 존재하지 않는 `game_audio.lingpet_gravity_accel_cast_sfx` 접근으로 `_init()`에서 중단되어 `quit()`에 도달하지 못함. 앞서 AI Pill API, bag expansion, active-item localization, Stage 2 rock 등 비관련 baseline 실패도 확인됨. 자동화가 만든 격리 세션만 Ctrl+C로 종료했고 사용자 프로세스는 건드리지 않음. |
| 사용자 본 트리 live 확인 | **unverified** — 격리 작업트리만 검증했으며 사용자 dirty tree에는 통합하지 않음 |

## 5. 격리·커밋·최종 상태

- 격리 작업트리: `D:\codex_tmp\bosspong-fusion-owner-20260810`
- 브랜치: `codex/tower-route-screen-cleanup-20260821`
- 기준 HEAD: `a8a5c8d45b1a4f32b79b7c1297d9afc005356496`
- 생산 수정: `36d53bed0` (`fix(tower): clean route screen composition`)
- 씰/QA: `7635e5527` (`test(tower): seal route screen cleanup pixels`)
- push/통합: 하지 않음
- 사용자 메인 작업트리: 수정하지 않음
- 작업 시작 전 warm worktree의 충돌 가능 untracked 8개는 `D:\codex_tmp\bosspong-fusion-owner-preserved-20260821-0330`에 보존함
- 보존된 triage 로그: `godot/.godot/codex_logs/tower_noncombat_return_selector_visual_qa_44764_20260821022110203.log`, `tower_noncombat_return_selector_visual_qa_22016_20260821022202852.log`, `smoke_gravity_accel_cast_no_loop_bleed_smoke_58800_20260821023351811.log`

필수 scoped 구현/검증 blocker는 **0건**이다. focused batch는 요구 종단선과 `SCRIPT ERROR` 0건을 만족했다. repository-wide nightly baseline hang은 이번 변경의 통과 판정과 분리했으며, 사용자 본 tree의 live 확인만 의도대로 `unverified`다. 통합 지시를 기다린다.
