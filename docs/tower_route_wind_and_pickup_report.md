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

- 작업 시작 시 최신 본 트리 HEAD: `58c36edc88190d247ec3a4d49d85e382c26ba7ca`
- 무풍 숨김과 픽업 정본: `7d47f516a`, 위 기준 HEAD의 조상임을 확인했다.
- 웜 워크트리: `D:\main\bosspong_tower_audition_689b`
- 브랜치: `codex/tower-wind-v4-runtime-7d47-20260821`
- 이전 작업 브랜치 `codex/tower-route-wind-pickup-b573-20260821`은
  `eb6af0f5a`에서 그대로 보존했다.
- 본 트리 수정·스테이징·통합·푸시: 없음

작업 도중 본 트리는 동시 작업으로 `d3860ce15`까지 전진했다. 새 본 트리 커밋은 이
격리 브랜치에 통합하지 않았고, 본 트리 파일도 건드리지 않았다. 작업 시작 시 최신
HEAD에 이미 들어 있던 `7d47f516a` 위에서 시작했으므로 오늘의 경로 화면 수정과
무풍 숨김 게이트를 되돌리지 않았다.

| 커밋 | 슬라이스 |
|---|---|
| `f8180ed39` | v4a/v4b 실제 `112x36` 승인 후보 provenance |
| `837643727` | 승인 v4b 아틀라스, `.import`, 런타임 배선, 절차 폴백 |
| `fccf3103d` | 자산/ctex, 무풍 게이트, 누락 폴백, Vulkan 픽셀 씰 |

## 무풍 풍향계 숨김

- 임계값은 `INDICATOR_VISIBLE_STRENGTH_THRESHOLD = 0.01`로 한 곳에 선언했다
  (`tower_ascent_route_wind_policy.gd:10`, `44-49`).
- 렌더러는 무풍일 때 게이지 모델과 바람 모델을 만들기 전에 반환한다.
  build-then-discard가 아니다(`tower_ascent_flow_renderer.gd:2878-2885`).
- 페이드는 넣지 않았다. 경로 바람은 진입당 한 번 정해져 서브가 끝날 때까지 고정되므로
  프레임 간 점멸 원인이 없다. 페이드는 무풍 의미 전달을 늦추고 숨은 상태의 드로 비용도
  남긴다.
- 신규 부정 레그는 무풍에서 게이지 모델 0, 바람 모델 0, 캔버스 드로 호출 0을 단언한다
  (`tower_route_wind_and_pickup_smoke.gd:178-186`).

## 풍향계 v4b 승인과 런타임 승격

현행 런타임 계약을 먼저 측정했다.

| 항목 | 실측 값 |
|---|---|
| 런타임 슬롯 | `112x36 px` |
| 조준 원 반지름 | `58 px` |
| 조준 원과 풍향계 간격 | `14 px` |
| 앵커 | 조준 원 오른쪽 세로 중앙, 화면 경계를 넘으면 같은 간격으로 왼쪽 배치 |
| 표시 상태 | `좌/우 x 약/보통/강 = 6개` |
| 숨김 상태 | 무풍 1개 |

v3는 2026-08-21 사용자 판정으로 반려했다. 원본의 황동, 비취, 주사 팔레트는
맞지만 실제 `112x36`에서는 나침반 장미가 노이즈가 되고 작은 구슬 3개의
켜짐/꺼짐이 약했다. 나침반이 한쪽을 차지해 좌우 반전 몸체도 어색했다.

반려 사유를 한 번에 분리하기 위해 내장 ImageGen 편집 모드로 같은 중앙 대칭 몸체의
3상태 후보 두 개를 만들었다. 둘 다 위에서부터 `왼쪽/보통`, `무풍`,
`오른쪽/보통`이며 모든 상태에 개별 실제 `112x36` 컷이 있다.

| 후보 | 세기 표시 | 무풍 | 실제 크기 판정 |
|---|---|---|---|
| v4a 굵은 눈금 | 방향 쪽 3칸을 약 1, 보통 2, 강 3칸 점등 | 6칸 소등, 중앙 황동 마름모 | **반려**. 6칸 테두리와 끝 장식이 v4b보다 복잡하다 |
| v4b 채워지는 띠 | 중앙에서 방향 쪽 반구간을 1/3, 2/3, 끝까지 충전 | 빈 띠, 중앙 주사 마름모 | **승인 및 승격**. 화살과 충전 영역이 큰 한 덩어리로 읽힌다 |

- 실제 크기 비교:
  `docs/art_candidates/tower_route_wind_vane/tower_route_wind_vane_imagegen_v4_actual_comparison_232x108.png`
  - 왼쪽 열 v4a, 오른쪽 열 v4b, 각 상태 자산은 정확히 `112x36`
  - SHA-256 `BA4809D9700842DC135FCE0EA06D58FDE1E817795370706B7F5B597C259C21F6`
- v4a 실제 크기 세로 묶음:
  `docs/art_candidates/tower_route_wind_vane/tower_route_wind_vane_imagegen_v4a_ticks_actual_strip_112x108.png`
  - SHA-256 `67ECA7C4BCBAD4C6BBD9FAEF580B5AD7DA927412D58A1F5AACD16B17F841967E`
- v4b 실제 크기 세로 묶음:
  `docs/art_candidates/tower_route_wind_vane/tower_route_wind_vane_imagegen_v4b_band_actual_strip_112x108.png`
  - SHA-256 `4435BB4D6FAF0F5A9938A253DFD777F4E99E6BBBCDC6F07D4C31DA070E4BDA02`

팔레트는 먹색 옻칠, 탁한 비취, 작은 주사, 노화 황동이며 네온은 사용하지 않았다.
나침반 장미는 제거했고 구름 문양은 대칭 모서리의 작은 장식으로 줄였다. v4a는
반려했고 v4b만 런타임으로 승격했다.

승격 자산은
`godot/assets/sprites/tower/route_wind_vane_imagegen_v4b_atlas.png`의
`784x36`, `7x1`, 셀당 `112x36` 아틀라스다. 프레임 순서는 `무풍`,
`좌 약/보통/강`, `우 약/보통/강`이다. PNG SHA-256은
`05C7285E4BE8863E7B25C07F5722AF7A88AF503DA7ECC044B45AC2AA56E12B33`이다.

### 세기와 방향 배선 판정

- **세기는 완성 프레임 6장을 고른다.** 한 장의 띠를 런타임에서 잘라 채우면 승인된
  끝단, 비취 광택, 황동 테두리의 픽셀이 세기마다 달라질 수 있다. 메모리 증가는
  `784x36` RGBA 한 장으로 작고, 각 세기의 실제 크기 픽셀을 고정하는 편이 안전하다.
- 렌더러는 `draw_texture_rect_region()`에 픽셀 단위 source rect를 전달한다.
  셰이더나 정규화 UV로 띠를 자르지 않으므로 GRT-033의 framebuffer/정규화 UV
  변환 경로가 없다.
- **좌우는 반전하지 않고 별도 셀을 사용한다.** 중앙 대칭 실루엣은 유지하되 황동
  하이라이트와 비취 끝단 조명이 뒤집히지 않게 승인 픽셀을 그대로 쓴다.
- 무풍 셀은 향후 표시 가능성을 검증하기 위해 아틀라스에 남겼지만, 실제 제품 경로는
  GRT-043 조기 반환으로 계속 숨긴다.

`.import` 사이드카 SHA-256은
`E7BE43D736E5CEBC98C536792264D0C8DB31B4B7012D8E85025CE0B752A19CC8`이고,
`CompressedTexture2D`로 remap된 `.ctex`는 격리 캐시에 실제 생성됐다. `.ctex`는
`27,956 bytes`, SHA-256
`DCBE764767DADE5149C2CF4C80E88986F9EFA42EB3DD2460E4BB8BE9236A42FF`다.
런타임은 import된 텍스처가 없거나 크기가 계약과 다르면 기존 절차 드로어로 즉시
폴백한다. raw PNG를 직접 디코딩하는 제품 폴백은 두지 않았다.

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
`EXPECTED_LEG_COUNT = 9`이며 다음을 단언한다
(`godot/tests/tower_route_wind_and_pickup_smoke.gd:26`, `133-143`).

- 임계값과 GRT-043 무풍 모델/드로우 0
- PNG와 `.import` 존재, `.import`가 가리키는 `.ctex` 존재
- 런타임 자산이 raw `ImageTexture`가 아닌 `CompressedTexture2D`이고 `784x36`임
- 7개 프레임 매핑과 바람 상태의 texture-region 드로우
- 자산 강제 누락 시 texture 드로우 0, 절차 드로우 1 이상
- 금화 2~5, 무혼 2~5, 복주머니 1
- 픽업/표적/직선 통로 최소 간격
- 선분 충돌
- 실제 런 경제 잔액 증가와 같은 ID 이중 적립 금지
- 복주머니 빈 슬롯 수락과 만석 거부
- 재서브 배치 유지와 화면 종료 정리

CI와 pre-push 리터럴 목록은 각각 `197`개이며 차이는 `0`, 신규 씰은 각 목록에
정확히 한 번씩 있다.

최신 기준 최종 터미널 증거:

```text
tower_route_wind_and_pickup_smoke: ok PASS=9
Smoke summary: PASS=1 FAIL=0 TOTAL=1
All Godot smoke tests passed.

Smoke summary: PASS=7 FAIL=0 TOTAL=7
All Godot smoke tests passed.

gd_warning_scan: scanning 3 scripts
gd_warning_scan: checked 3/3
Godot warning scan passed with no GDScript warnings.

[ApplicationQuitCoordinator] graceful headless shutdown complete
Godot headless load check passed.

Vulkan 1.4.325 - Forward Mobile - Using Device #0: NVIDIA - NVIDIA GeForce RTX 5070
tower_route_serve_wind_target_visual_qa: ok ... gold=11 muhon=21 pickups=8 captures=18
Tower route wind pickup and target Vulkan visual QA passed.
```

`git diff --check`도 통과했고 위 실행들에서 `SCRIPT ERROR`는 0건이다.

### 2020x1246 Vulkan 캡처

모두 `godot/.godot/codex_captures/tower_route_wind_and_pickup/` 아래에서 최종
브랜치로 새로 생성한 Forward Mobile/Vulkan 캡처다.

| 증거 | 파일 | SHA-256 |
|---|---|---|
| 좌풍 승인 자산 | `route_wind_asset_left_2020x1246.png` | `5DBA746A28FBD824D66D125C40F4E9421C1D5420AD853BCE7620EA3DFE6A25C4` |
| 무풍 authored 셀, QA 전용 노출 | `route_wind_asset_calm_2020x1246.png` | `1177BDDCDC5F9F8CC59A0DCAA90CDE09105804A401917A66AB933C29DFFF1EA3` |
| 우풍 승인 자산 | `route_wind_asset_right_2020x1246.png` | `1F8EF88A5C76CD58A8B86506F4D58E69C36F1EEF95BAD36A239395B650CA35BB` |
| 자산 누락 절차 폴백 | `route_wind_procedural_fallback_2020x1246.png` | `A03A8F62255D66DF71D0E01E33401D1922CD9B7DEA070D8B459325EA1698F248` |
| 제품 무풍, 패널 숨김 | `route_wind_calm.png` | `E6C63781EB666FA12B3376AC52A192F794B96E002460F8086D706D74E9BD800E` |
| 획득 직후 HUD `10/20 -> 11/21` | `route_pickups_after_currency_2020x1246.png` | `C9FD495F17A20F510FD70C42C3186AAC472AF262103C4A64360CD4676A3C57CA` |
| 실제 서브 공 비행 | `route_live_ball_in_flight_2020x1246.png` | `3E8D982ACF787BCC565EDC09D6FABD20552E698F1E2EC9719F9A515D23A81A82` |
| 표적 확정 뒤 픽업 정리 | `route_cleanup_after_target_2020x1246.png` | `7B8A0FC573609C1F4F37827111DF0D4B4212B1F4820E066829A176365182B079` |

실제 제품 논리 슬롯은 계속 `112x36`이다. 2020x1246 창의 제품 playfield 배율을
그대로 적용하면 framebuffer footprint는 `186x59`이며 QA 확대는 넣지 않았다.
같은 footprint를 잘라 자동 비교한 해시는 다음과 같다.

| 실제 HUD footprint | 파일 | SHA-256 |
|---|---|---|
| 좌풍 | `route_wind_asset_left_actual_hud_crop.png` | `E4545262F36EFE70E0DDE2DC0E323433CB388E3760CF5DD4507BF60C38630A8D` |
| 무풍 authored 셀 | `route_wind_asset_calm_actual_hud_crop.png` | `782E943EA0F40466D01788F2C0C1B066F89FBF6DB73B0BBCA2DC3815E59D8655` |
| 우풍 | `route_wind_asset_right_actual_hud_crop.png` | `049BE445B4141114AD5005E71AA19C42CA56077E2CC9F381F4BB3ACAF4F13D54` |
| 절차 폴백 | `route_wind_procedural_fallback_actual_hud_crop.png` | `F0C9042CA4AF1C0BBDC491E445C42EB23BD7EEA846785BADF3AE37FBD19F2FBC` |

좌풍/무풍은 `1,729`, 좌풍/우풍은 `2,618`, 무풍/우풍은 `1,809` 픽셀이
서로 달랐다. 우풍 승인 자산과 절차 폴백은 `9,038` 픽셀이 달랐다. 모두 최소
`80` 픽셀 차이 씰을 넘었다. 제품 무풍 캡처는 패널이 완전히 숨은 별도 부정 레그다.
캡처와 자동 픽셀 판정으로 풀 `760x750` 코트 테두리, 플레이어 패들, 실제 공,
표적 아이콘도 유지됨을 확인했다. 이전 보스/스테이지 오브젝트와 스킬 레일은 0이다.

## 최종 게이트

- blocked: `0`
- 풍향계 v3 후보: **반려**
- 풍향계 v4a 후보: **반려**
- 풍향계 v4b 후보: **승인 및 런타임 승격 완료**
- `.import`/`.ctex`: **존재와 import 로드 경로 확인 완료**
- 자산 누락 절차 폴백: **GREEN**
- GRT-043 무풍 숨김 무손상: **GREEN**
- 사용자 본 트리 라이브 1판: **unverified 1**
- 통합/푸시: 미수행

이 브랜치와 웜 워크트리에서 명시적 승인 또는 통합 지시를 기다린다.
