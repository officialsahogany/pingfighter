# 탑 지도 방여도 렌더링 수정 보고서

- 작업일: 2026-08-21
- 본 트리 기준 HEAD: `d182bf7929cc21f718e58b48549e7c1f59c7f79d`
- 격리 워크트리: `D:\main\bosspong_tower_scroll_fix_d182`
- 격리 브랜치: `codex/tower-map-scroll-render-fix-d182`
- 렌더 수정 커밋: `25f4af6de`
- 승인 후 경로 미세조정 커밋: `65d9eeb1f`
- 본 트리 통합·push: 하지 않음
- 아트 재생성·픽셀 수정: 하지 않음

## 판정 결과

반려된 네 렌더 문제를 수정했다. 핵심 판정 자료는 M키 전체 지도가 아니라
`MAP_TRANSITION` 생산 경로를 통과한 정확한 기본 카메라 배율 `2.15`의 Vulkan
캡처다. M키 전체 지도는 보조 자료로 별도 제출한다.

승인된 11개 PNG와 `.import`는 수정하지 않았다. 현재 승격본은 S1 승격 커밋의
Git blob과 11개 모두 동일하다. rev2 지형 밴드는 여전히 불투명 RGB이며 알파
합성 없이 그린다. 기존 카탈로그 선행 로드, 음성 캐시, 절차 지도 폴백도 그대로다.

## 반려 원인과 수정

### 1. 붓선

기존 배선은 72x320 브러시 한 장의 UV를 긴 곡선 전체에 연속 배분해, 화면에서는
커다란 얼룩처럼 늘어났다. 최초 수정에서 이를 `18x80` 쿼드로 나눴으나, 투명한
꼬리 구간까지 80px 간격으로 배치되어 미선택·선택 가능 경로가 점선 스탬프처럼
보였다. 최종 미세조정에서는 두 비금색 상태만 28 world px 보폭으로 겹쳐 배치한다.
각 쿼드는 곡선의 해당 구간 chord에 세로축을 직접 맞춰 회전하므로 개별 붓조각의
방향도 경로와 일치한다. 완료 금색은 승인된 기존 80px 간격 기하를 그대로 쓴다.

- 경로 폭: `18 world px` (`2.15x`에서 38.7px)
- 타일 길이: `80 world px` (`18 * 320 / 72`)
- 미선택·선택 가능 타일 보폭: `28 world px`
- 완료 금색 타일 보폭: 기존 `80 world px` 유지
- 상태: 미선택 / 선택 가능 / 완료 금박의 승인 텍스처 3종 유지
- `draw_set_transform` 사용 없음

끝점은 메달 반지름 안쪽(`art_size * 0.42`)으로 클램프하고, 경로 다음에 편액을
다시 그린 뒤 마지막에 메달을 그린다. 한쪽 노드가 현재 카메라 밖인 미선택·선택
가능 경로는 그리지 않아 3F 아래의 두 고아 붓자국을 제거했다. 완료 금색 기록은
기존처럼 카메라 경계를 넘어 이어질 수 있다.

### 2. 지형 밴드

기존 화면 맞춤 직사각형이 692px 밴드를 약 1600px 폭으로 늘렸다. 이제 모든
밴드를 정확히 `692x320 world px`로 그린다. 화면이 더 넓을 때는 692px 지도 열을
가운데 두고 나머지를 공용 종이색 여백으로 남긴다. 층 행 간격은 승인 계약의
160px이며, 밴드는 상하로 이어질 뿐 서로 알파 합성하지 않는다.

`MAP_TRANSITION`에서는 `TEMP_MAP_CAMERA_ZOOM=2.15`를 실제 기본 투영 배율로
적용한다. 기존 진입 애니메이션 `1.0→1.18`은 별도 배율로 보존했다. M키 전체
지도는 기본 배율 1.0으로 692px 지도 열을 중앙 정렬한다.

### 3. 노드 아이콘

전체화면 렌더에 남아 있던 `NODE_ART_TEXTURES` 사각 타일 경로를 제거하고,
승인된 지도 아이콘 presentation을 원형 메달 안에 그리도록 두 지도 경로를
통일했다. `floor_04_shell_02` 같은 셸 슬롯은 `shell_02`라는 미존재 아이콘을
고르지 않고 실제 stand-in 보스(`ponk` 등)의 승인 아이콘을 결정론적으로 고른다.

- 노드 아이콘: `32 world px` (`2.15x`에서 68.8px)
- 검은 사각 타일 없음
- 승인된 보스·비전투 아이콘의 원형 메달 합성 유지

### 4. 층 편액

620x48 원본을 화면 절반 너비로 늘리던 목표 크기를 제거했다. 좌우 장식 끝을
보존하는 3-slice 방식은 유지하되 층 표시 목표 크기를 `184x24 world px`로
고정했다. `2.15x` 화면에서는 약 `395.6x51.6px`로 읽히며 선반처럼 화면을
가로지르지 않는다.

## 자산·import 보존 증거

`res://assets/sprites/tower/map_scroll/`의 결과다.

- PNG: 11개
- `.import` sidecar: 11개
- sidecar가 가리키는 누락 `.ctex`: 0개
- S1 승격 커밋 `7625d9519` 대비 변경된 PNG: 0개
- RGB 692x320: 공용 종이 1종 + 지형 밴드 6종
- RGBA 72x320: 붓선 3종
- RGBA 620x48: 편액 1종

새 격리 워크트리에서는 라이브 에디터나 본 프로젝트에 `--import`를 실행하지
않았다. 이전 검증 워크트리의 같은 상대 경로에서 생성된 정확한 캐시를 복원했다.
헤드리스 로드 첫 시도에서 격리 캐시에 공용 폰트 `.fontdata` 두 개가 없는 것이
확인되어, 같은 검증 캐시의 두 파일만 복원했다. 최종 헤드리스 로드는 오류 없이
정상 종료했다.

## 자동 검증

### 범위 내 GREEN

- 집중 smoke 7종: `PASS=7 FAIL=0 TOTAL=7`
  - `tower_map_scroll_wiring_contract_smoke.gd`: `PASS=8`, `ok`
  - `tower_map_iconography_contract_smoke.gd`
  - `tower_map_camera_tracking_smoke.gd`
  - `tower_map_walker_zoom_intro_smoke.gd`
  - `tower_ascent_map_overlay_render_smoke.gd`
  - `tower_ascent_map_overlay_input_smoke.gd`
  - `tower_ascent_two_phase_graph_smoke.gd`
- 변경 GDScript 7개 warning scan: 경고 0
- headless load: graceful shutdown, 통과
- `git diff --check`: 통과
- Vulkan Forward Mobile 시각 QA: 통과
  - 해상도 `2020x1246`
  - 기본 인게임 지도 배율 `2.15`
  - 지도 world 폭 `692`
  - 캡처 9개
  - 경로 상태 표본: 미선택 30 / 완료 1 / 선택 가능 1
  - 밴드 누락 음성 다리: 절차 지도 폴백 확인
- 승인 후 경로 미세조정 재검증
  - 같은 집중 smoke 7종: `PASS=7 FAIL=0 TOTAL=7`
  - 변경 GDScript 4개 warning scan: 경고 0
  - headless load: graceful shutdown, 통과
  - 지도 자산 변경: 0개
  - 별도 Vulkan 캡처 폴더: `tower_map_scroll_route_refine`

전 저장소 전체 smoke 기준선은 이번 렌더 수정에서 다시 실행하지 않았다. 위 결과는
변경 생산 경로와 인접 회귀, warning, headless load, Vulkan 실화면에 한정한다.

## 판정 자료

### 최종 경로 미세조정

최종 증거는 기존 승인 캡처를 덮지 않는
`godot/.godot/codex_captures/tower_map_scroll_route_refine/`에 있다.

| 순서 | 파일 | 용도 | SHA-256 |
|---:|---|---|---|
| 1 | `01_live_gameplay_zoom_2_15.png` | 핵심 판정: 연속 비금색 경로와 3F 끝점 | `F4A0A6C43EDD75CE9DB0B34F72767B0FFEDE553959CF7EC102E8E60DFA19D1A2` |
| 2 | `03_live_m_key_overlay_floor01.png` | M키 전체 지도 연속성 | `C59E263BBD9CCC13A6957713A44813B596875A1DEAAB710AE897BA6A2E979C83` |
| 3 | `04_live_m_key_overlay_three_route_states.png` | 미선택·선택 가능 밀도와 금색 보존 | `3D92F03D7E100B21A6795E5AF643495747A6AB8730E37242957AB99E21E31481` |

### 이전 승인 렌더

증거는 추적하지 않는 격리 캐시
`godot/.godot/codex_captures/tower_map_scroll_render_fix/`에 있다. 표 순서가 제출
순서이며, 2.15배 인게임 화면을 먼저 둔다.

| 순서 | 파일 | 용도 | SHA-256 |
|---:|---|---|---|
| 1 | `01_live_gameplay_zoom_2_15.png` | 핵심 판정: 생산 `MAP_TRANSITION`, 정확한 2.15배 | `D355F64EC6CDCC5C22A945EEE39D42C45983B018F3DA2A94CFE7523D41DDF09B` |
| 2 | `02_approved_human_vs_gameplay_zoom_2_15.png` | 승인 인간계 원본과 2.15배 화면 나란히 비교 | `95A093AF84A1CD448C7B5BB5755F62424242FB83119999CE253526F3A2AD0088` |
| 3 | `03_live_m_key_overlay_floor01.png` | 보조 판정: M키 전체 지도, 중앙 정렬 | `B29AF6F38520E3F944D292BF04CA9134B80EC67319221184A49F8BB083199A42` |
| 4 | `04_live_m_key_overlay_three_route_states.png` | M키 지도에서 붓선 3상태·메달·편액 | `82B6FF0B11BFC9FDF3F7D940F0D15C8AEE5B0BF055897555302266085D3957A3` |
| 5 | `05_live_m_key_overlay_realm_boundary.png` | 계열 경계와 인접 밴드 | `EF6BB8B2CC86781AB40EABEC8CBA460A0288C10BFF36885880C41A7EA6C756A2` |
| 6 | `06_live_immortal_transition.png` | 신선계 2.15배 생산 경로 | `63CBA0A75334136FF2D0CD68C3B6A6293DD64976C23BA6D7C24351F3416B40F4` |
| 7 | `07_live_missing_band_procedural_fallback.png` | 승인 밴드 한 종 누락 폴백 | `5E279F98EF48D68CB33DF7955CE1D7EE6D97B32B5A69BFAA18AEB212A12D4C30` |
| 8 | `08_approved_human_vs_m_key_overlay.png` | 승인 인간계와 M키 보조 화면 비교 | `8581568228DC14C662188B0C3D347B81E03A79FB7D998CE418781F75FAC2E17D` |
| 9 | `09_approved_immortal_vs_live.png` | 승인 신선계와 생산 화면 비교 | `9FBE6B425CD7E9C8D64D9645975D10D4D94F9E23EC22EF68116DE5B404A9F078` |

승인 비교 이미지는 승격본의 원본 픽셀을 왼쪽에 놓고 같은 실행의 생산 렌더를
오른쪽에 놓았다. 런타임 modulate는 `Color.WHITE`이며 별도 색 보정은 없다.

## 인계 상태

- 범위 내 `blocked=0`, `unverified=0`.
- 본 트리 통합·push는 하지 않았다.
- 사용자 판정과 통합 지시를 기다린다.
