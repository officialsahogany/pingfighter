# 비전투 노드 복귀 후 경로 선택 공 미표시 P0 완료 보고

## 판정

- **P0 원인을 확정하고 격리 워크트리에서 수정·검증했다.** 기준은
  `f3f1683dffd479ceb3f06fe68c3c1b0faee6dc74`, 작업 브랜치는
  `codex/tower-noncombat-return-selector-p0-f3f168`, 워크트리는
  `D:\main\bosspong_tower_live_feedback_r3_887a` 이다.
- 본 트리에는 통합·푸시하지 않았다. 본 트리의 사용자 라이브 확인은
  **unverified 1건**으로 남긴다. 자동화 게이트의 **blocked는 0건**이다.
- 격리 브랜치 로컬 커밋은 구현 `e9ec60788`과 씰 `2da141426`으로 분리했다.

## 먼저: 무엇이 경로 선택 공을 그리는가

경로 선택 때 날아가는 물리 공은 Tower flow가 직접 그리지 않는다.

- `godot/scripts/tower_ascent/tower_ascent_flow_renderer.gd:107` 은
  `ROUTE_AIM`에서 `_draw_route_aim()`을 호출하고, 그 구현
  (`:1869`)은 경로 표적·조준 게이지·바람·안내를 그린다.
- 물리 공은 공용 전장 경로의
  `godot/scripts/core/battle_playfield_scene_drawer.gd:182`가
  `ball_drawer.draw_ball()`을 호출해 그린다.
- 그 아래 실제 공 렌더러 진입점은
  `godot/scripts/ball/ball_renderer.gd:57`의 `draw_current()`이다.

따라서 회귀 당시 선택 공은 **flow 소유가 아니라 전체 battle playfield 소유**였다.
`f4adbea3b`가 유지 비전투 배경에서 전체 playfield를 생략하면서 이전 보스와 함께
이 공도 생략되었다.

## 두 용의자 실측

실제 휴식처를 선택해 일을 수행한 뒤 종료 입력을 태운 smoke와 Vulkan QA에서
다음 값을 직접 출력했다.

| 시점 | 실제 phase | retained kind | `uses_playfield_flow_phase` |
|---|---|---|---:|
| 휴식처 안 | `NODE_MODAL` | `rest` | `false` |
| 볼일 종료 후 | `ROUTE_AIM` | `rest` | `true` |

결론은 다음과 같다.

1. **가 — 유지 상태가 안 풀린다:** 상태는 실제로 `rest`로 유지된다. 그러나 이는
   비전투 방 배경을 경로 선택 동안 계속 보존하는 현재 계약이며, 전투 노드를 고를
   때 `tower_ascent_flow_map_progress.gd:466`에서 해제된다. 여기서 조기 clear하면
   이전 전장/보스가 다시 드러나므로 원인 수정점이 아니다.
2. **나 — 페이즈 정책이 배제한다:** 아니다. `FLOW_PHASES`는 screen-space
   페이즈 목록이고 `uses_playfield_flow_phase()`는 그 반대편을 판정한다.
   실제 `ROUTE_AIM` 값은 `true`였다.
3. **확정 원인:** 유지 배경 때문에 전체 playfield를 끄는 게이트는 정상 동작했고,
   flow overlay도 정상 호출됐다. 다만 물리 선택 공이 그 전체 playfield 내부에
   중첩 소유되어 있어서 함께 사라졌다.

## 수정

- `godot/scripts/core/battle_playfield_scene_drawer.gd:40`에 기존 production
  context/deps와 `ball_drawer.draw_ball()`을 그대로 재사용하는 좁은
  `draw_tower_route_selector_ball()` 슬라이스를 추가했다.
- `godot/scripts/core/battle_scene_drawer.gd:179`의 유지 배경 전용 경로는 실제
  phase가 `ROUTE_AIM`일 때만 캐시된 playfield drawer의 그 좁은 슬라이스를
  호출한 뒤 기존 flow overlay를 그린다. 전체 `_draw_playfield_scene()`은 계속
  생략되므로 이전 보스·전장·조명은 되살아나지 않는다.
- `NODE_MODAL`, 비탑 경로 및 전투 복귀의 기존 전체 playfield 경로에는 이 추가
  호출이 없다. 새 경로도 `get_instance()`로 콜드 생성하지 않고 캐시된 production
  owner만 사용한다.

## RED / GREEN 반증과 픽셀 씰

Vulkan Forward Mobile, 실제 `2020x1246` SubViewport에서
`휴식처 선택 -> 휴식 수행 -> 종료 -> production route serve 공 발사 -> ROUTE_AIM`
순서로 태웠다. 공이 있는 프레임과 같은 상태에서 공만 끈 짝 프레임을 비교했다.

| 증거 | phase / retained | 선택 공 draw | 전체 playfield draw | 선택 공 밝은 변화 픽셀 | 이전 보스 sentinel |
|---|---|---:|---:|---:|---:|
| RED: 새 선택 공 호출을 임시로 비활성화 | `ROUTE_AIM` / `rest` | 0 | 0 | **0** | 0 |
| GREEN | `ROUTE_AIM` / `rest` | 8 | 0 | **339** | 0 |

- GREEN의 전체 변화 마스크는 5,792픽셀이며, 시간 변화 배경을 제외하기 위해
  ball-on/off 차이 중 RGB 각 채널이 0.82 이상인 밝은 변화 픽셀 **339개**를
  선택 공 픽셀로 셌다. 공 위치는 `(515.3784, 531.3923)`, 검사 crop은
  `[P: (459, 80), S: (1100, 1086)]`이었다.
- 발사는 테스트 플래그가 아니라 production
  `tower_ascent_route_serve_runtime._serve_live_ball`을 통과했다. 캡처 시점은
  `ball_active=true`, `waiting=false`, `selector_launched=true`였다.
- RED는 production 수정 한 줄을 `apply_patch`로 일시 무효화해 0픽셀 실패를
  확인한 후 같은 방식으로 즉시 복구했다. 실패 로그는
  `godot/.godot/codex_logs/tower_noncombat_return_selector_visual_qa_46604_20260820165125963.log`
  에 보존했다.

캡처 세 장은 모두 `2020x1246`이다.

- `godot/.godot/codex_captures/tower_noncombat_return_selector/rest_node_modal_no_previous_boss.png`
  — 휴식처 내부, 이전 보스 0픽셀.
- `godot/.godot/codex_captures/tower_noncombat_return_selector/rest_return_route_selector.png`
  — 휴식처 종료 후 경로 선택 중 실제 파란 공, 밝은 변화 339픽셀.
- `godot/.godot/codex_captures/tower_noncombat_return_selector/combat_return_restored.png`
  — 전투 노드 선택 뒤 retained kind가 빈 문자열로 해제되고 전체 playfield draw
  8회, 전투 sentinel 13,110픽셀로 정상 복귀.

## 자동 씰과 목록

개정한 `tower_noncombat_node_background_retention_smoke.gd`는 다음을 함께 고정한다.

- 실제 휴식처 볼일 종료 전후 phase/retained/policy 실측.
- `ROUTE_AIM`에서는 selector-only 1회, full playfield 0회.
- `NODE_MODAL`에서는 selector-only 0회이고 이전 전장이 계속 억제됨.
- 전투 노드 선택 시 retained 배경 해제 후 full playfield 정상 복귀.
- 비탑 fallback은 정상 full playfield를 유지하고, 캐시 미스가 콜드 생성을 하지 않음.

이 smoke는 이미 두 리터럴 목록에 모두 있다.

- `.github/workflows/godot-ci.yml:79`
- `godot/tools/run_pre_push_checks.ps1:83`

기준 HEAD에서 두 목록은 각각 **192개**이고 차집합은 0이다. goal 문서의 190개는
현재 기준 HEAD와 2개 차이 나는 오래된 수치다. 기존 씰 개정이므로 목록 수는
증가하지 않았고 별도 `_leg_count` 상수도 없다.

## 검증 결과

- focused smoke 3종
  (`tower_noncombat_node_background_retention_smoke.gd`,
  `tower_ascent_rest_node_smoke.gd`, `tower_ascent_route_serve_smoke.gd`):
  **PASS=3, FAIL=0, TOTAL=3**, 종단선 `All Godot smoke tests passed.`
- touched-file warning scan: 통과, GDScript 경고 0.
- `run_headless_load_check.ps1`: 통과,
  `[ApplicationQuitCoordinator] graceful headless shutdown complete`.
- `run_tower_noncombat_return_selector_visual_qa.ps1`: 캡처 3장, `ok`, 통과.
  최종 GREEN 출력에는 `SCRIPT ERROR` 및 분류된 serious error가 없었다.
- `git diff --check`: 통과.

정확한 `f3f1683df` 기준은 본 트리의 동시 WIP에 이미 들어간 ball sub-renderer
추가 인자와 어긋난다. 시각 QA는 그 WIP를 가져오지 않고, 같은 production
sub-renderer에 구형 기준 인자를 위임하는 harness 전용 adapter만 사용했다.
최종 GREEN에서 어댑터 teardown 오류는 없었다. 출력된 missing phantom state,
unknown preset/baekrin module, 종료 시 ObjectDB leak 경고는 이 수정과 무관한
기준선 경고이며 serious/script error 판정에는 포함되지 않았다.

## 격리·캐시·남은 게이트

- 새 콜드 워크트리를 만들지 않고 기존 warm worktree를 재사용했다.
- live 본 트리의 source와 `.import` 해시가 정확히 같은 누락 import cache만
  warm worktree에 복사했다. editor/headless importer는 실행하지 않았고 추적
  asset 변경도 없다.
- 작업 전 로그는
  `D:\codex_backups\tower_noncombat_return_selector_20260821_011826`에 백업했다.
- blocked: **0**.
- unverified: **1** — 본 트리 통합 후 사용자가 수행할 라이브 확인. 현재는
  통합하지 않고 대기한다.
