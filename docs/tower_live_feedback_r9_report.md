# 탑 라이브 피드백 r9 수행 보고서

## 결론

요청한 네 슬라이스를 기준 HEAD `673416041`에서 각각 독립 커밋으로 완료했다.
범위 내 스모크, 경고 스캔, 헤드리스 로드, Vulkan 2020x1246 캡처,
`git diff --check`가 모두 GREEN이다. 범위 blocker는 0건이다.

- 격리 워크트리: `D:\main\bosspong_tower_live_feedback_r3_887a`
- 격리 브랜치: `codex/tower-live-feedback-r9-673416041`
- 기준 커밋: `673416041`
- 보고서 작성 전 구현 HEAD: `25546e49c`
- 본 트리 통합: 하지 않음
- 푸시: 하지 않음
- 사용자 Godot 게임 또는 에디터 종료: 하지 않음
- 사용자 본 트리 라이브 확인: 미검증

작업 도중 본 트리는 동시 작업으로 `5f772a0a6`까지 이동했다. 이 작업은 사용자
지정 기준 `673416041`에서 시작했고 새 본 트리에 재기반하거나 통합하지 않았다.
따라서 착지 전에는 새 본 트리와의 충돌 및 소비자 드리프트를 다시 확인해야 한다.

## 커밋

| 슬라이스 | 커밋 | 내용 |
|---|---|---|
| 1 | `6e274e842` | 청린귀 외 Stage 2 변형의 6점 위기 바위낙하 차단 |
| 2 | `19836ae0a` | 활주구슬 보상 픽 비용만 무혼 3으로 변경 |
| 3 | `2b6c19dd2` | 경로 바람에 날씨 바람 상태와 렌더러 재사용 |
| 4 | `25546e49c` | 이동 지도 종이 면을 실제 화면 끝까지 확장 |

## 1. 바위낙하 원인 확정과 수정

### 6점 트리거와 실제 생산 경로

Fable이 찾은 `stage2_boss_skill_state.gd`의 지진 경로와 별개로, 점수 기반
바위낙하는 공통 Stage 2 배경 갱신 경로가 소유한다.

1. `battle_effects_update_controller.gd:238`가 Stage 2 공통
   `stage_background.update(delta, context, effect_deps)`를 매 프레임 호출한다.
2. `stage2_pillar_background.gd:1400`이
   `boss_rage_coordinator.reserve_crisis(context)`를 호출한다.
3. `stage2_boss_rage_coordinator.gd:11`의
   `CRISIS_PLAYER_SCORE := 6`이 실제 점수 트리거다.
4. 이 6은 주석에 기록된 GRT-054 관계대로 7점제 재보정에서 파생된 값이다.
   기존 5점제의 4/5 임계값을 6/7로 옮겼고 듀스 발동선과 같은 점수를 유지한다.
5. 최종 스톰프는 `stage2_boss_rage_coordinator.gd:175`에서 실제
   `spawn_crisis_rock_wall`을 호출하고, `:135`에서
   `stage2_rock_lifecycle_coordinator`에 실제 payload 생성을 위임한다.

원인은 변형 skill state가 아니라 모든 Stage 2 보스가 공유하는 배경 코디네이터가
`stage_boss_variant`를 보지 않았던 것이다. 그래서 지굴왕과 거미각시가
`super.update()`를 호출하지 않아도 별도 공통 배경 경로에서 위기가 예약됐다.

수정은 `stage2_boss_rage_coordinator.gd:70-76`의 예약 입구에서만 했다.
Stage 2 변형을 공용 카탈로그로 정규화하고 기본 변형 청린귀가 아니면 예약을
거부한다. 청린귀의 점수 상수, 분노 타임라인, 실제 lifecycle payload 생성은
바꾸지 않았다.

### 씰 결과

`stage2_variant_crisis_rockfall_smoke.gd`의 실제 payload 결과는 다음과 같다.

| 변형과 조건 | 실제 낙하 payload |
|---|---:|
| 지굴왕, 플레이어 6점 | 0 |
| 거미각시, 플레이어 6점 | 0 |
| 청린귀 champion, 플레이어 6점 | 3 |
| 청린귀 mythic, 플레이어 6점 | 5 |
| 청린귀, 플레이어 5점 | 0 |
| 청린귀, 플레이어 7점 직접 진입 | 0 |

물바주포 형제 레그는 청린귀의 실제 위기 payload 생성 뒤
`defer_water_cannon_after_rock_spawn`이 정확히 1회 호출됨을 단언했다.
영구 씰은 `PASS=8`이고 두 리터럴 목록에 함께 등록했다.

Vulkan 증거는
`.godot/codex_captures/tower_live_feedback_r9/stage2_score6_rockfall_variants.png`다.
일회성 QA가 동일한 생산 코디네이터, 실제 rock lifecycle, 생산 바위 렌더러를
사용해 0/0/3을 다시 확인했다. 증거용 QA 소스는 커밋하지 않고 원복했다.

참고로 기준 HEAD의 기존 `stage2_water_cannon_interrupt_smoke.gd`는 현재
Stage 2 상태 모듈 일부가 정적 셸인 기존 결함 때문에 `SCRIPT ERROR`를 낸다.
이 실패는 새 변형 게이트 이전에도 존재하는 범위 밖 baseline이며, 위의 실제
물바주포 defer 레그를 범위 GREEN 근거로 사용했다.

## 2. 활주구슬 비용

활주구슬 `dash_amplification`은 `reward_pick_kind=mugong`이다. 기존 kind 단위
가격만 바꾸면 모든 일반 무공이 함께 오르므로 ID 전용 분기가 필요했다.

- `tower_reward_pick_offer_builder.gd:29`: 활주구슬 전용 비용 3
- `tower_reward_pick_offer_builder.gd:116-124`: training과 fusion 분기 뒤
  `dash_amplification` ID만 3, 다른 mugong은 종전 2
- `tower_reward_pick_smoke.gd:487-505`: 활주구슬 3과 다른 무공 2를 각각 단언
- `tower_ascent_run_map_plan.md:394-399`: v1.10 단가 통일 계약의 명시적 예외와
  최대 활주 +1, 구슬당 슬롯 1칸이라는 이유 기록

Vulkan 증거
`.godot/codex_captures/tower_reward_pick/four_card_reward_pick.png`에서
`활주구슬` 카드가 `무혼 3`으로 표시된다. 기존 프로덕션 보상 픽 QA에
생산 비용 resolver로 활주구슬을 일시 주입해 캡처했고 QA 토글은 원복했다.

## 3. 경로 바람 이펙트

### 기존 날씨 바람 소유 구조

| 역할 | 소유자와 위치 | 재사용 내용 |
|---|---|---|
| 상태와 payload | `weather_event_state.gd:196-257`, 기존 생성은 `:983-1009` | 기존 breeze/gust 상태, 같은 `_make_particle` 경로, 별도 표시 RNG |
| 단계 목표 수 | `weather_event_state.gd:24-28` | 미풍 28, 강풍 34, 경로 약풍 14 |
| 텍스처 프리웜 | `weather_event_renderer.gd:78-79` | 기존 `wind_ribbon` 캐시 |
| 파티클 렌더 | `weather_event_renderer.gd:104-122`, `:456-583` | 같은 바람 파티클 구조와 같은 리본 드로 |
| 경로 표시 상태 수명 | `tower_ascent_route_serve_runtime.gd:116-132`, `:272-278` | 경로 진입, 틱, 종료, 취소 정리 |
| 경로 소비와 클립 | `tower_ascent_flow_renderer.gd:2838-2860` | 공용 렌더러와 `Rect2(0, 0, 760, 750)` 플레이필드 클립 |

경로 세기 대응은 약 14, 중 28, 강 34다. 중은 실제 미풍 목표 수를, 강은
실제 강풍 목표 수를 그대로 쓴다. 강만 `gust`, 약과 중은 `breeze` 구조를 쓴다.
무풍은 표시 상태를 reset해 payload와 draw를 모두 0으로 만든다.
영구 씰이 단언한 안정화 뒤 payload 수는 약/중/강 `14/28/34`, 렌더 예산을
적용한 draw 수는 `14/28/32`로 모두 단계가 다르다.

표시 전용 RNG를 따로 두어 게임 RNG를 전진시키지 않는다. 실제 날씨
`force_start_weather_event`는 표시 override를 지우므로 기존 미풍과 강풍의
상태, 물리, 목표 수를 보존한다.

경로 바람 물리는 바꾸지 않았다. 기존처럼 조준 범위에만 bias를 더하고,
발사 뒤 공에는 힘을 가하지 않는다. 강풍과 무풍의 동일 입력 발사 후 공 위치가
같다는 역방향 씰이 GREEN이다.

Vulkan 2020x1246 QA는 20개 캡처를 생성했다.

- `route_wind_calm.png`: 무풍 payload 및 draw 0
- `route_wind_weak_right.png`: 약풍
- `route_wind_medium_right.png`: 중풍
- `route_wind_max_right.png`, `route_wind_max_left.png`: 강풍 양방향
- 픽셀 변화량은 약 < 중 < 강
- GRT-045 플레이필드 밖 letterbox 변화 픽셀: 0

증거 디렉터리는
`.godot/codex_captures/tower_route_wind_and_pickup/`이다.

## 4. 필러 끝 판정과 전체 화면 지도

### 판정

"필러 배경 끝까지"는 플레이필드 760x750이 아니라 필러를 포함한 실제 화면
전체로 판정했다. 근거는 다음과 같다.

- 프로젝트 규칙상 760x750 플레이필드는 전체 게임 캔버스이고 필러는 그 밖의
  screen letterbox에 있다. 플레이필드 끝은 필러 끝이 아니다.
- `tower_ascent_screen_space_surface_policy.gd:3`은 `MAP_OVERLAY`와
  `MAP_TRANSITION`을 screen-space surface로 분류한다.
- `tower_ascent_flow_renderer.gd:228-258`의 `draw_fullscreen_map`과
  `draw_fullscreen_surface`가 실제 뷰포트 rect를 소비한다.
- Fable이 지목한 `MAP_RECT(34,24,692,702)`은 `:1323` 이후의 레거시
  플레이필드 지도 경로에 남아 있다. 이동과 카메라 줌의 생산 화면은
  `draw_fullscreen_map` 경로이므로 이 상수를 키우는 수정은 잘못된 소유자를
  건드린다.

따라서 판정이 갈리지 않았고 질문을 위해 중단할 필요가 없었다.

### 구현과 씰

`tower_ascent_flow_renderer.gd:482-493`에서 종이 `panel_rect`만 전달받은 실제
`viewport_rect` 전체로 넓혔다. 기존 outer margin으로 만든
`safe_content_bounds`는 그대로 유지해 지도 콘텐츠와 카메라 계산을 이동시키지
않았다.

- 지도 종이 렌더 rect: 실제 전달 뷰포트와 정확히 같음
- 2020x1246 네 모서리 종이 픽셀: 모두 존재
- 지도 콘텐츠, 노드, 경로, 편액: 기존 safe bounds 유지
- 선택 가능한 후보: 전부 현재 camera visible-world 안
- 승인 밴드: 모든 floor가 692x320, 가로 늘림 없음
- 하단, 중간 자유 추적, 상단 카메라 클램프: GREEN
- 역방향 760x750 fixture: 전달된 작은 뷰포트를 그대로 따르며 하드코딩 없음
- 이동과 카메라 인트로: 72 Hz 실주행 5개 transition GREEN
- 경계 최대 배율 차이: 0.000103
- 경계 최대 중심 차이: 0.038px

Vulkan 증거는 다음 경로에 있다.

- `.godot/codex_captures/tower_map_camera_tracking/map_camera_floor01_lower.png`
- `.godot/codex_captures/tower_map_camera_tracking/map_camera_floor05_middle.png`
- `.godot/codex_captures/tower_map_camera_tracking/map_camera_floor09_upper.png`
- `.godot/codex_captures/tower_map_camera_tracking/map_camera_walker_zoom_full_transition_strip.png`
- `.godot/codex_captures/tower_map_camera_tracking/map_camera_walker_zoom_intro_dense_strip.png`

지도 최신 배선, 곡선 경로, 픽업, 풍향계 코드는 되돌리지 않았다.

## 최종 검증

집중 배치 8종 결과:

```text
stage2_variant_crisis_rockfall_smoke: ok PASS=8
tower_reward_pick_smoke: ok
tower_route_wind_and_pickup_smoke: ok PASS=13
weather_event_state_smoke: ok
weather_event_render_budget_smoke: ok
tower_map_camera_tracking_smoke: ok
tower_ascent_map_overlay_render_smoke: ok
tower_map_scroll_wiring_contract_smoke: PASS=8
Smoke summary: PASS=8 FAIL=0 TOTAL=8
All Godot smoke tests passed.
```

추가 게이트:

- 변경 GDScript 13개 focused warning scan: 경고 0, 오류 0
- `run_headless_load_check.ps1`: 통과, graceful shutdown 종단선 확인
- 두 리터럴 스모크 목록: CI 200, pre-push 200, 차이 0
- `git diff --check` 기준 커밋 전체: 통과
- §1 일회성 Vulkan QA: payload 0/0/3, 통과
- §2 보상 픽 Vulkan QA: 캡처 3, 통과
- §3 경로 바람 Vulkan QA: 캡처 20, 통과
- §4 지도 Vulkan 및 실주행 QA: 캡처 6, transition 5, 통과

격리 캐시 준비를 위해 HEAD LFS OID와 파일 SHA-256이 같은 지도 및 풍향계
소스 12개를 이 워크트리에만 물질화했다. `git lfs status`에서 각 항목의 LFS
OID와 파일 OID가 같고 스테이징된 항목은 0이다. 구현 커밋에는 들어가지 않았다.

최종 판정은 `blocked=0`이다. 본 트리 통합과 사용자 라이브 체감은 의도적으로
수행하지 않았으며 다음 지시를 기다린다.
