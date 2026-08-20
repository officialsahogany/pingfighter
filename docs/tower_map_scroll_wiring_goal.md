# 탑 지도 방여도 승격·배선 /goal 지시문 (2026-08-20)

- **선행**: `docs/tower_map_scroll_art_brief_rev2.md`. **rev2 후보 6종이
  사용자 승인을 받았다.** 후보 A 의 종이·편액·붓선 3상태도 승인 상태다.
- **성격**: 아트가 아니라 **런타임 배선**이다. 아트를 다시 만들지 마라.
- **기준 HEAD**: 최신. ⚠ 본 트리에 미커밋 WIP이 3800건 있다. 격리 워크트리에서
  작업하고 `stash`·`checkout`·`reset`·통짜 `git add` 없이 통합 대기하라.
- ★**새 워크트리를 콜드로 만들지 마라.** 하나가 약 10GB다.
- **완료 보고**: `docs/tower_map_scroll_wiring_report.md`. 푸시 금지.
  **통합하지 말고 보고 후 대기하라.**

## 0. 승인된 자산 `[확인]`

### 지형 밴드 6종 — rev2

`docs/art_candidates/tower_map_scroll_rev2/`

| 파일 | 치수 |
|---|---|
| `human_realm_01_mountain_candidate_rev2.png` | 692x320 RGB |
| `human_realm_02_village_candidate_rev2.png` | 692x320 RGB |
| `human_realm_03_river_candidate_rev2.png` | 692x320 RGB |
| `immortal_realm_01_islands_candidate_rev2.png` | 692x320 RGB |
| `immortal_realm_02_cloud_cranes_candidate_rev2.png` | 692x320 RGB |
| `immortal_realm_03_pavilions_candidate_rev2.png` | 692x320 RGB |

★**불투명 RGB 다. 알파가 없다.** 승인된 종이 위에 직접 구운 타일이며
이음매는 알파 0 이 아니라 **종이색 수렴**으로 만들어져 있다.

### 후보 A 유지 자산 — 재생성 금지

`docs/art_candidates/tower_map_scroll/`

| 파일 | 치수 |
|---|---|
| `common_hanji_paper_candidate.png` | 692x320 RGB |
| `floor_gate_plaque_candidate.png` | 620x48 RGBA |
| `route_brush_unselected_candidate.png` | 72x320 RGBA |
| `route_brush_available_candidate.png` | 72x320 RGBA |
| `route_brush_completed_gold_candidate.png` | 72x320 RGBA |

## 1. 실측 계약 `[확인]`

| 값 | 실측 | 출처 |
|---|---|---|
| 플레이필드 | 760 x 750 | `flow_renderer.gd:60` |
| MAP_RECT | (34, 24) 692 x 702 | `flow_renderer.gd:61` |
| 행 간격 | 160px | `map_generator.gd` `590 - row*160` |
| 최하단 행 y | 590 | 같은 곳 |
| 총 층 | 12 | `TOWER_FLOOR_COUNT` |
| 층당 행 | 2 | `TEMP_OPTIONAL_ROWS_PER_FLOOR := 1` |
| 총 행 | 23 | `1 + 11*2` |
| 카메라 줌 | 2.15 | `TEMP_MAP_CAMERA_ZOOM` |
| 밴드 단위 | **320px = 행 2개** | 승인 사양 |

## 2. 교체 대상 절차 드로 `[확인]`

`godot/scripts/tower_ascent/tower_ascent_flow_renderer.gd`

| 줄 | 현행 | 대체 |
|---|---|---|
| 1108 | `draw_rect(MAP_RECT, PAPER, true)` | 종이 + 지형 밴드 타일 |
| 1109 | `draw_rect(MAP_RECT, INK, false, 4.0)` | 판정하라 |
| 1110 | `draw_rect(MAP_RECT.grow(-8.0), PAPER_DEEP, ...)` | 판정하라 |
| 1214 | `draw_line(from, to, INK_SOFT, 1.5)` | **붓선 브러시 3상태** |
| 1241 | `draw_string(font, ..., "%dF")` | **편액 + 숫자 오버레이** |

★**1107 의 전체 어둡게 깔기는 유지하라.** 지도 바깥 letterbox 처리다.

★**폴백을 없애지 마라.** 자산이 없거나 프리웜 전이면 현행 절차 드로로
떨어져야 한다. 화면이 죽으면 안 된다.

## 3. 슬라이스

| 순서 | 슬라이스 | 내용 |
|---|---|---|
| S1 | 자산 승격 | 파일 배치 + `.import` |
| S2 | 카탈로그·프리웜 | 로더 소유자 |
| S3 | 밴드 타일 렌더 | 종이 + 지형 |
| S4 | 붓선 경로 | ★얇은 직선 제거 |
| S5 | 층 편액 | `3F` 글자 대체 |
| S6 | 씰과 캡처 | 회귀 차단 |

## 4. 계약

### S1. 자산 승격

- 배치 경로는 기존 규약을 따르라. 노드 아이콘이
  `res://assets/sprites/tower/map_icons`, 비전투 배경이
  `res://assets/sprites/tower/noncombat` 다. **같은 계열로 정하고 근거를 적어라.**
- 파일명에서 `_candidate` 를 떼고 런타임 명명 규약에 맞춰라.
  rev2 밴드는 버전 접미사를 남겨 재작화 이력을 보존하라.
- ★**`.import` 사이드카와 `.ctex` 가 실제로 생성됐는지 확인하라.**
  `run_headless_load_check.ps1` 통과는 증거가 아니다. 로더의 raw-PNG 폴백이
  소스를 직접 디코딩해서 에디터·헤드리스는 정상으로 보이지만 **익스포트
  빌드에서 텍스처가 통째로 빠진다.**
- ★**에디터를 닫으라고 요구하지 마라.** 파일 교체 → 에디터 포커스 시 자동
  재임포트 → 폴링으로 완료 감지 순서다. 에디터가 열린 채로 헤드리스
  `--import` 를 돌리지 마라.
- ★**추적되지 않은 자산이 되지 않게 하라.** 격리 워크트리 빌드에서 통째로
  빠지는 사고가 있었다. 커밋에 PNG 와 `.import` 를 함께 넣어라.

### S2. 카탈로그와 프리웜

- ★**`tower_noncombat_node_background_catalog.gd` 가 선례다.** 그 형태를
  재사용하라. `prewarm_node_kind()` / `get_cached_resolution()` 구조다.
- ★**드로 경로에서 로드하지 마라**(GRT-003). 부팅·로딩·층 전환에서 프리웜하고
  드로는 non-instantiating peek 만 한다.
- ★**미존재 경로를 매 프레임 드로에 걸지 마라**(GRT-004). 리소스 로더는
  성공만 캐시한다. 없는 파일은 매 프레임 파일시스템을 다시 stat 하고
  경고 dedup 때문에 조용하다.
- ★**캐시 히트 경로에 깊은 복사를 두지 마라**(GRT-032). 선례가
  `duplicate(false)` 얕은 복사를 쓴다.
- ★**격자 선언**: 밴드는 시트가 아니라 개별 파일이지만, 붓선 3상태처럼
  상태별로 갈리는 자산은 **키와 파일의 대응을 명시 상수**로 선언하라.
  치수에서 추론하지 마라.

### S3. 밴드 타일 렌더

- 종이를 세로로 깔고 그 위에 층 계열에 맞는 지형 밴드를 얹는다.
- ★**밴드는 불투명 RGB 다.** 알파 합성을 기대하지 마라. 타일 자체가 종이를
  포함한다. 종이 타일은 **밴드가 없는 구간의 여백용**이다.
- 계열 판정은 `realm_kind` 다. `human_realm` / `immortal_realm` 두 값이며
  `map_generator.gd:347/371` 이 소유한다.
- ★**인접 층에 같은 변형을 쓰지 마라.** 계열당 3변형이고 12층이라 반복이
  반드시 생긴다. 3연 증거에서 반복이 눈에 띄었다. 층 인덱스로 결정론적으로
  변형을 고르되 **연속 두 밴드가 같지 않게** 하라. 프레젠테이션 난수를
  쓴다면 독립 `RandomNumberGenerator` 를 쓰고 게임플레이 RNG 를 소비하지 마라.
- ★**카메라 오프셋에 맞춰 타일 오프셋을 계산하라.** 세로 총 연장이 약
  3700 월드px 다. 화면 밖 밴드를 그리지 마라.
- ★**3700px 를 매 프레임 슬라이스하거나 스케일하지 마라.** 필요한 밴드만
  `draw_texture_rect_region` 으로 그린다.

### S4. 붓선 경로 ★

**후보 판정에서 지적된 항목이다.** 지형이 빽빽해져서 현행 1.5px 직선이
연필 자국처럼 묻힌다.

- 승인된 72x320 브러시 3상태를 실제로 그려라.
  - `route_brush_unselected` — 미선택
  - `route_brush_available` — 선택 가능
  - `route_brush_completed_gold` — 지나온 경로
- ★**세 상태를 알파로만 가르지 마라.** 별도 자산이 이미 있다. 그것을 써라.
- 노드 간 거리가 가변이므로 **세로로 타일하거나 늘려라.** 브러시가 세로
  320px 이므로 그 축이 경로 방향이다. 회전이 필요하면
  `draw_set_transform` 을 쓰되 ★**끝나고 아이덴티티로 리셋하지 마라.**
  상위 플레이필드 변환이 지워진다. 스테이지3 에서 같은 사고가 났다.
- ★**GRT-055**: `draw_line` 에는 라인 캡이 없다. 선으로 흉내 내지 마라.

### S5. 층 편액

- 620x48 편액을 깔고 층 숫자를 그 위에 그린다.
- ★**숫자는 자산에 없다.** 런타임이 얹는다.
- 좌우로 늘려도 읽히게 슬라이스하라.
- ★**한국어 카피에 엠대시 금지.** 새 문구가 생기면 7 로케일 등재.

### S6. 씰

- 승격된 PNG 전부에 **`.import` 사이드카가 존재**하는지 단언하라.
  파일 존재만 보지 말고 dest `.ctex` 까지 확인하라.
- 밴드 6종·종이·편액·붓선 3상태 **10개 키가 전부 해석**되는지 단언하라.
  하나라도 빠지면 RED 다.
- ★**드로 경로에서 로드가 일어나지 않는지** 단언하라(GRT-003).
  프리웜 전에는 폴백으로 떨어지는 부정 레그를 둬라.
- ★**인접 층 변형이 같지 않은지** 단언하라. 12층 전체를 훑어라.
- ★**경로 3상태가 서로 다른 텍스처를 쓰는지** 단언하라.
- ★**캔버스 변환이 경로 드로 전후로 유지되는지** 단언하라.
- **자산을 하나 지우면 RED 가 나는** 반증 레그를 남겨라.

## 5. 규율

- 슬라이스마다 헝크 분리 커밋 1개. 각 슬라이스는 **단독으로 씰 GREEN**이어야 한다.
- 신규·개정 씰은 `.github/workflows/godot-ci.yml`과
  `godot/tools/run_pre_push_checks.ps1` **두 리터럴 목록에 동시 등재**한다.
  현재 189개다. ⚠ **실패하는 씰을 넣지 마라.**
- ⚠ 씰 레그를 추가하면 그 파일의 `_leg_count` 류 상수를 **함께 갱신**하라.
- ⚠ `tower_ascent_flow_renderer.gd` 는 여러 작업이 공유한다.
  **최신 HEAD 기준으로 시작**하라.
- 내부 식별자와 저장 키는 호환 식별자다. 바꾸지 마라.
- 통과 판정은 배치 종단선 `All Godot smoke tests passed.` + `SCRIPT ERROR` 0건.
- 로그 백업 선행. 표준 래퍼 `-AllowDuringPlay`. 푸시 금지.

## 6. 검증

- 슬라이스별 씰 + `-Paths` 경고 + 헤드리스 + `git diff --check`.
- **Vulkan 캡처**, 실 해상도(2020x1246).
  - 인간계 층의 지도 (실제 2.15배 줌 상태)
  - 신선계 층의 지도
  - **계열이 바뀌는 경계 층**
  - 경로 3상태가 한 화면에 보이는 프레임
  - 층 편액과 숫자
  - 자산 누락 시 절차 폴백이 뜨는 부정 레그
- ★**승인 후보 이미지와 라이브 캡처를 나란히 비교하라.** 승인한 것이
  그대로 나오는지 본다. 배선 과정에서 밀도나 색이 달라지면 반려다.
- **라이브 체감은 사용자가 본 트리에서 한다.** 구조 게이트까지 하고
  라이브 항목은 unverified 로 명시해 보고하라.
- 판정 불가 지점이 나오면 중단·보고.

**완료 선언 조건**: S1~S6 구현·검증 + 승인본 대비 라이브 비교 +
게이트 blocked 0건 + 보고서 완성.
