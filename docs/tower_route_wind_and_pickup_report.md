# 경로 서브 풍향계·재화 픽업 완료 보고 (2026-08-21)

## 판정

**설계대로다. 비행 중 바람 힘은 추가하지 않는다.**

경로 바람은 날씨 이벤트 바람과 이름만 같고 플레이 책임이 다르다. 현행의
조준 범위 편향을 유지하며, 발사된 공의 속도에는 경로 바람을 적용하지 않는다.

| 구분 | 상태 소유자와 입력 | 공에 미치는 영향 | 적용 시점 | 판정 근거 |
|---|---|---|---|---|
| 날씨 이벤트 바람 | `weather_event_state.gd:30-35`의 `BREEZE/GUST_WIND_FORCE_BALL` | `ball_vel.x`에 매 틱 횡력을 더한다 | `apply_ball_weather_motion()`의 `weather_event_state.gd:517-529` | 전투 중 계속 변하는 날씨 물리다 |
| 경로 바람 | `tower_ascent_route_wind_policy.gd:18-37`이 진입당 게임플레이 RNG로 한 번 굴린 `bias_degrees` | 조준 왕복 범위 중앙만 좌우로 옮긴다 | `tower_ascent_route_serve_runtime.gd:235-251`에서 발사 전 게이지에 적용 | 타이밍 조준의 불확실성을 만드는 경로 서브 규칙이다 |

경로 공은 발사 순간의 게이지 각도로 초기 속도를 정한다
(`tower_ascent_route_serve_runtime.gd:221-231`). 이후 실제 물리 스텝
(`tower_ascent_route_serve_runtime.gd:301-318`)에는 경로 바람 모델이 전달되지
않는다.

이 구조는 `docs/tower_ascent_run_map_plan.md:161-198`의 실제 서브, 왕복 각도
게이지, 자유 좌우 이동, 상단 벽 반사 계약과 맞는다. 더 직접적으로 앞선 사용자 확정
정본은 "바람은 각도 게이지를 편향시키고 발사 후 공 궤적은 휘게 하지 않는다"고
명시한다(`docs/tower_route_serve_wind_target_goal.md:5-7`). 날씨 힘을 추가하면
보이는 게이지를 보고 보정한 초기 조건이 발사 뒤 다시 바뀌므로, 현재 확정 조작 계약을
깨는 변경이 된다.

## 작업 격리와 기준

- 사용자 지정 기준 HEAD: `b57329dd17d78c94dbaf306c2d5dbd95ad585e78`
- 웜 워크트리: `D:\main\bosspong_tower_audition_689b`
- 브랜치: `codex/tower-route-wind-pickup-b573-20260821`
- 기존 웜 브랜치 `codex/tower-route-wind-pickup-20260821`은 그대로 보존했다.
- 본 트리 수정·스테이징·통합·푸시: 없음

작업 종료 스냅샷에서 본 트리 HEAD는 동시 작업으로 `d1747a65d`까지 전진했다.
추가된 두 커밋은 Stage 3 스킬카드, 보류 문서, CI/pre-push 목록만 변경하며 경로
런타임 파일과는 겹치지 않는다. 이 격리 브랜치의 사용자 지정 기준은 계속
`b57329dd1`이고, 새 본 트리 변경은 통합하지 않았다. 추후 통합 시 양쪽 씰 목록을
락스텝으로 합쳐야 한다.

기존 웜 작업의 구현 슬라이스를 새 기준 브랜치에 순서대로 재적용한 뒤 최신 기준에서
전부 다시 검사했다. 사용자 지정 HEAD의 두 최신 커밋과 오늘 들어온 경로 화면 수정을
되돌리지 않았다.

| 커밋 | 슬라이스 |
|---|---|
| `d44ced280` | 무풍 풍향계 숨김, GRT-043 조기 게이트, 신규 스모크 등록 |
| `bbf111e09` | 경로 재화/복주머니 롤·배치·충돌·획득·정리 구현 |
| `c1968bf51` | 풍향계 ImageGen v2 비교 후보 추가 |
| `50a62222e` | 2020x1246 Vulkan 픽업·경제 HUD·공·정리 증거 확장 |
| `6b51de822` | 내장 ImageGen v3 권장 후보와 실제 112x36 검토본 추가 |
| `d274fbefb` | 액티브 unlock store를 보존하면서 세로 슬라이스 픽스처 회귀 차단 |

## 무풍 풍향계 숨김

- 임계값은 `INDICATOR_VISIBLE_STRENGTH_THRESHOLD = 0.01`로 한 곳에 선언했다
  (`tower_ascent_route_wind_policy.gd:10`, `44-49`).
- 렌더러는 무풍일 때 게이지 모델과 바람 모델을 만들기 전에 반환한다.
  build-then-discard가 아니다(`tower_ascent_flow_renderer.gd:2799-2817`).
- 페이드는 넣지 않았다. 경로 바람은 진입당 한 번 정해져 서브가 끝날 때까지 고정되므로
  프레임 간 점멸 원인이 없다. 페이드는 무풍 의미 전달을 늦추고 숨은 상태의 드로 비용도
  남긴다.
- 신규 부정 레그는 무풍에서 게이지 모델 0, 바람 모델 0, 캔버스 드로 호출 0을 단언한다
  (`tower_route_wind_and_pickup_smoke.gd:163-172`).

## 풍향계 ImageGen 승인 후보

현행 런타임 계약을 먼저 측정했다.

| 항목 | 실측 값 |
|---|---|
| 런타임 슬롯 | `112x36 px` |
| 조준 원 반지름 | `58 px` |
| 조준 원과 풍향계 간격 | `14 px` |
| 앵커 | 조준 원 오른쪽 세로 중앙, 화면 경계를 넘으면 같은 간격으로 왼쪽 배치 |
| 표시 상태 | `좌/우 x 약/보통/강 = 6개` |
| 숨김 상태 | 무풍 1개 |

측정과 생성 프롬프트는
`docs/art_candidates/tower_route_wind_vane/README.md:15-23`, `59-70`에 기록했다.

- 권장 후보 원본:
  `docs/art_candidates/tower_route_wind_vane/tower_route_wind_vane_imagegen_v3_source.png`
  - 내장 ImageGen 편집 모드, `2070x760`, RGBA
  - 알파 bbox `(25,37)-(2038,744)`, 알파 `0/255`, 네 모서리 투명
  - SHA-256 `CA0CF6FA823411D22C4EC5DB874C091F462617E45293BED76B7E6A951D20B5D6`
- 실제 슬롯 검토본:
  `docs/art_candidates/tower_route_wind_vane/tower_route_wind_vane_imagegen_v3_preview_112x36.png`
  - 오브젝트 `103x36`, 최종 알파 bbox `(7,3)-(105,30)`
  - 오른쪽 화살표와 켜진 세기 셀 2개, 꺼진 셀 1개가 실제 크기에서도 분리된다.
  - SHA-256 `70DC0B2A084DFF04E35A78BE08F49FEA9458EC04D669AAA46C0151DE70FFD68C`

팔레트는 먹색 옻칠, 탁한 비취, 작은 주홍, 노화 황동이며 네온은 사용하지 않았다.
상태는 **미승인 후보**다. `godot/assets/` 승격, 6개 상태 제작, 렌더러 연결,
`.import`/`.ctex` 생성은 하지 않았다. 승인 뒤에도 6개 상태를 고정 앵커로 제작하고
실제 `112x36`에서 다시 심사해야 한다.

## 경로 재화 픽업

### RNG와 수량

- 픽업은 런 경제와 장비 상태를 실제로 바꾸므로 연출 RNG가 아니라 기존 게임플레이
  RNG를 사용한다. 같은 입력 RNG 상태는 보상 종류와 위치를 재현한다
  (`tower_ascent_route_pickup_state.gd:39-101`).
- 금화 2~5개, 무혼 2~5개, 랜덤 액티브 아이템 복주머니 1개다.
- 진입당 픽업 RNG를 한 번만 전진시킨다. 서브 실패와 재서브에서는 같은 배치와 남은
  픽업을 유지하고 다시 굴리지 않는다.
- 픽업에 앞서 경로 바람 RNG가 소비되며, 이어진 픽업 RNG의 최종 상태가 같은
  `_gameplay_rng_state` 소유자에 다시 저장된다
  (`tower_ascent_flow_map_progress.gd:429-450`).

### 배치와 충돌

배치 상수는 `tower_ascent_tuning.gd:65-75`에 모았다.

- 픽업 중심 최소 간격: `58`
- 표적 아이콘 중심 최소 간격: `86`
- 패들 원점에서 표적까지의 직선 통로 최소 간격: `38`

배치기는 모든 기존 픽업, 표적 아이콘, 두 표적으로 향하는 직선 통로를 검사한다
(`tower_ascent_route_pickup_state.gd:169-215`). 공의 이전 위치와 현재 위치를 잇는
선분으로 충돌을 판정해 고속 통과를 놓치지 않는다
(`tower_ascent_route_serve_runtime.gd:301-318`, `419-441`).

### 획득, 만석, 이중 획득, 정리

- 금화는 기존 `collect_gold`, 무혼은 기존 `collect_muhon`으로 즉시 런 경제 잔액에
  적립한다(`tower_ascent_flow_map_progress.gd:491-516`).
- 복주머니는 기존 필드 획득 소유자인
  `active_item_runtime.collect_item_by_name`을 재사용한다
  (`tower_ascent_flow_map_progress.gd:517-532`).
- 슬롯이 가득 차면 기존 필드 획득 규칙대로 지급을 거부하고 복주머니는 남는다.
  빈 슬롯이 생긴 뒤 다시 접촉하면 획득할 수 있다.
- 지급에 성공한 ID만 `consumed`가 된다. 이미 소비된 ID는 지급 전에 거르므로 공이
  관통하거나 반사되어 다시 닿아도 두 번 적립되지 않는다
  (`tower_ascent_route_pickup_state.gd:122-137`,
  `tower_ascent_flow_map_progress.gd:491-534`).
- 표적 확정 직후 `finish_selection()`과 함께 남은 픽업을 지우며
  (`tower_ascent_flow_map_progress.gd:536-550`), 전체 flow reset/cancel 경계에서도
  픽업 상태를 reset한다(`tower_ascent_flow_state.gd:201-204`).

표현은 기존 금화 드로어, 공용 무혼 fallback, 기존 복주머니 아이콘을 재사용했다.
새 픽업 아트나 임시 도형 경로를 추가하지 않았다
(`tower_ascent_flow_renderer.gd:2761-2792`).

## 회귀 발견과 수정

최초 최신 기준 회귀 실행은 `PASS=5 FAIL=1`이었다. 신규 픽업 전용 씰은
GREEN이었지만 `tower_ascent_vertical_slice_smoke.gd`의 픽스처가 정식 unlock
store를 만들지 않아 액티브 후보가 비었고, 신규 픽업 초기화가 경로 진입 전체를
거부했다.

이를 기존 실패로 분리하지 않고 이번 변경의 회귀로 고쳤다.

- null 또는 `RefCounted` 픽스처 owner에만 카탈로그 fallback을 허용했다
  (`tower_ascent_route_pickup_state.gd:25-36`).
- 실제 전투 `Node`는 정식 unlock filtering을 그대로 통과해야 한다.
- 실 셸 픽스처에는 명시적인 unlock store를 넣었다
  (`tower_ascent_vertical_slice_smoke.gd:349-355`, `386-390`).
- 수정 뒤 실패했던 세로 슬라이스와 전체 집중 세트가 GREEN이다.

## 씰과 검증

신규 씰 `tower_route_wind_and_pickup_smoke.gd`는 고정
`EXPECTED_LEG_COUNT = 7`이며 다음을 단언한다
(`godot/tests/tower_route_wind_and_pickup_smoke.gd:26`, `118-132`).

- 임계값과 GRT-043 무풍 모델/드로우 0
- 금화 2~5, 무혼 2~5, 복주머니 1
- 픽업/표적/직선 통로 최소 간격
- 선분 충돌
- 실제 런 경제 잔액 증가와 같은 ID 이중 적립 금지
- 복주머니 빈 슬롯 수락과 만석 거부
- 재서브 배치 유지와 화면 종료 정리

CI와 pre-push 리터럴 목록은 각각 `197`개이며 차이는 `0`, 신규 씰은 각 목록에
정확히 한 번씩 있다. 사용자 지정 기준 HEAD의 목록은 각각 `196`개였으므로 신규
씰 한 개만 증가했다.

최신 기준 최종 터미널 증거:

```text
tower_route_wind_and_pickup_smoke: ok PASS=7
Smoke summary: PASS=6 FAIL=0 TOTAL=6
All Godot smoke tests passed.

gd_warning_scan: scanning 11 scripts
gd_warning_scan: checked 11/11
Godot warning scan passed with no GDScript warnings.

[ApplicationQuitCoordinator] graceful headless shutdown complete
Godot headless load check passed.

Vulkan 1.4.325 - Forward Mobile - Using Device #0: NVIDIA - NVIDIA GeForce RTX 5070
tower_route_serve_wind_target_visual_qa: ok ... gold=11 muhon=21 pickups=8 captures=10
Tower route wind pickup and target Vulkan visual QA passed.
```

`git diff --check`도 통과했고 위 실행들에서 `SCRIPT ERROR`는 0건이다.

### 2020x1246 Vulkan 캡처

모두 `godot/.godot/codex_captures/tower_route_wind_and_pickup/` 아래에서 최종
브랜치로 새로 생성한 Forward Mobile/Vulkan 캡처다.

| 증거 | 파일 | SHA-256 |
|---|---|---|
| 무풍, 패널 숨김 | `route_wind_calm.png` | `E6C63781EB666FA12B3376AC52A192F794B96E002460F8086D706D74E9BD800E` |
| 우강풍, 패널 표시, 전체 픽업 | `route_wind_max_right.png` | `A03A8F62255D66DF71D0E01E33401D1922CD9B7DEA070D8B459325EA1698F248` |
| 획득 직후 HUD `10/20 -> 11/21` | `route_pickups_after_currency_2020x1246.png` | `C9FD495F17A20F510FD70C42C3186AAC472AF262103C4A64360CD4676A3C57CA` |
| 실제 서브 공 비행 | `route_live_ball_in_flight_2020x1246.png` | `3E8D982ACF787BCC565EDC09D6FABD20552E698F1E2EC9719F9A515D23A81A82` |
| 표적 확정 뒤 픽업 정리 | `route_cleanup_after_target_2020x1246.png` | `7B8A0FC573609C1F4F37827111DF0D4B4212B1F4820E066829A176365182B079` |

캡처와 자동 픽셀 판정으로 풀 `760x750` 코트 테두리, 플레이어 패들, 실제 공,
표적 아이콘이 유지됨을 확인했다. 이전 보스/스테이지 오브젝트와 스킬 레일은 0이다.

## 최종 게이트

- blocked: `0`
- 풍향계 v3 후보 승인: **대기 중**
- 풍향계 런타임 승격: 승인 전 미수행
- 사용자 본 트리 라이브 1판: **unverified 1**
- 통합/푸시: 미수행

이 브랜치와 웜 워크트리에서 명시적 승인 또는 통합 지시를 기다린다.
