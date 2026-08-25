# 탑 지도 열람 오버레이 완료 보고

- 기준 지시문: `docs/tower_map_overlay_goal.md` (`537f3aed4`)
- 정본: `docs/tower_ascent_run_map_plan.md` v1.6 §3.1
- 구현 판정: **GREEN**
- blocked: **0건**
- unverified: **0건**
- 푸시: 하지 않음

## 1. 구현 결과

### 1-1. 입력·개폐와 물리차단 모달

- 탑 플래그 ON의 전투 중 `M` 입력은 전용 입력 라우터를 통해 지도 오버레이를
  연다. 열린 뒤에는 `M` 또는 `ESC`가 닫기를 소유한다.
- 새 열기 라우트는 기존 오버레이 라우터 뒤에 있다. 일시정지 메뉴와 기존
  선택·업무 모달이 먼저 입력을 소비하므로 지도와 중첩되지 않는다.
- 전투 중 열기는 기존 `TowerAscentModalLifecycle`을 그대로 사용한다.
  - 열기: 볼 속도 캡처, 스킬·액티브 쿨다운 pause fanout, 중앙 루프 오디오 정지.
  - 닫기: 쿨다운 resume, 볼 프리즈와 즉시 실점 차단 무장.
- 이미 `ROUTE_AIM` 또는 `MAP_TRANSITION`이 물리차단 수명주기를 소유한 경우
  지도는 그 수명주기를 빌린다. 지도만 닫을 때 combat resume을 잘못 호출하지
  않고 원래 위상으로 돌아간다.
- 첫 전투에서 아직 지도가 생성되지 않았으면 최초 `M` 입력이 동일 결정론
  생성기를 한 번 준비한다. 이후 개폐는 런 스냅샷을 바꾸지 않는 열람 전용이다.

### 1-2. 전도 공개 표시

- 기존 `MAP_TRANSITION` 지도 렌더러를 `MAP_OVERLAY`에서도 재사용한다.
- 제목은 정확히 `지도`, 닫기 안내는 `M 또는 ESC로 닫기`다.
- 생성된 12층·34노드를 모두 표시하고 각 노드 옆에 정본 종류명을 붙인다.
  - 전투, 광폭화, 상점, 수련장, 파계승, 수호의 샘터, 휴식.
- 현재 위치는 진홍 이중 링과 `현재` 표기로 강조한다.
- 완료 노드는 금색, 미방문 노드는 종이색으로 구분한다. 각 노드의 종류·상태
  표기는 유지하되 하단 범례 띠는 표시하지 않는다.
- 회피로 소멸한 보스는 X와 `소멸`, 10~12층은 `잠금` 표기를 유지한다.
- 오버레이에는 선택·클릭·경로 확정 진입점이 없다.

### 1-3. HUD 힌트

- 탑 플래그 ON 전투 화면 좌하단에 `M 지도`를 표시한다.
- 지도·경로·노드 모달 등 탑 표면이 이미 화면을 소유하면 힌트를 숨긴다.
- 힌트 드로는 `tower_ascent_flow_owner`를 캐시 조회만 하며, hot draw에서
  모듈을 생성하지 않는다.
- 제목·닫기·노드 종류·상태·HUD 힌트를
  `tower_ascent_map_overlay_localization.gd` 키 카탈로그에 등록했다. 미번역
  지원 언어는 기존 탑 카탈로그 관례대로 한국어 정본으로 폴백한다.

### 1-4. 플래그 OFF 무손상 및 M 충돌 감사

- `godot/scripts/**`, `godot/scenes/**`, `godot/project.godot`의 `KEY_M`,
  `physical_keycode == KEY_M`, `keycode == KEY_M`를 감사했다.
- 선행 M 키 바인딩은 없었다.
- 플래그 OFF 부정 레그에서 M은 지도를 열지 않고 redraw도 요청하지 않으며,
  `tower_ascent_flow_owner`의 생성형 `get_instance`를 호출하지 않는다.

## 2. 커밋 매핑

| 커밋 | 지시문 항목 | 내용 |
|---|---|---|
| `979477726` | §1-1, §1-4 | M/ESC 개폐, 기존 모달 우선순위, GRT-058 수명주기, OFF 무생성 부정 레그 |
| `ab7cc6a39` | §1-2 | 전도 공개 지도, 7종 종류명, 현재·완료·미방문·소멸·잠금 표시, 로컬라이제이션 |
| `8e0abdaab` | §1-3 | 전투 HUD `M 지도` 힌트와 hot-draw 캐시 계약 |
| `7f6cbb9b6` | §2 가시 검증 | 실제 전투 드로어 기반 Vulkan 캡처 하네스 |

첫 커밋은 공유 파일 `battle_scene_input_controller.gd`의 지도 헝크만 스테이징한
후, 격리 후보 `f18d988a2`(tree `6bb45acc2f2925d37e0c4f9f204d5f9fe0639654`)
에서 집중 스모크 4/4 GREEN을 증명했다.

## 3. TEMP 튜닝 표

최종 제품 수치가 아니라 지도 정보 계층과 760×750 가독성을 검증하기 위한
단일 튜닝 오너다.

| 상수 | 값 | 용도 |
|---|---:|---|
| `TEMP_MAP_OVERLAY_NODE_RADIUS` | 8.0 | 열람 지도 노드 반지름 |
| `TEMP_MAP_OVERLAY_CURRENT_RING_RADIUS` | 14.0 | 현재 위치 외곽 링 |
| `TEMP_MAP_OVERLAY_NODE_LABEL_FONT_SIZE` | 10 | 노드 종류·상태 글자 크기 |
| `TEMP_MAP_OVERLAY_NODE_LABEL_OFFSET_X` | 11.0 | 종류 라벨 수평 간격 |
| `TEMP_MAP_OVERLAY_NODE_LABEL_WIDTH` | 110.0 | 종류 라벨 폭 |
| `TEMP_MAP_OVERLAY_STATE_LABEL_WIDTH` | 48.0 | 현재·완료·소멸·잠금 라벨 폭 |
| `TEMP_MAP_HINT_RECT` | `(18, 698, 98, 30)` | 좌하단 HUD 힌트 영역 |
| `TEMP_MAP_HINT_FONT_SIZE` | 14 | HUD 힌트 글자 크기 |

## 4. 검증 증거

검증은 사용자 플레이 PID 38784가 실행 중인 상태에서 수행했다. 모든 표준
래퍼가 `-AllowDuringPlay`를 선언했고 실제 Godot 검증 프로세스는 BelowNormal
우선순위로 확인됐다.

| 게이트 | 결과 | 종단선·근거 |
|---|---|---|
| 개폐·모달 집중 스모크 | GREEN 4/4 | `All Godot smoke tests passed.` |
| 표시·힌트 집중 스모크 | GREEN 5/5 | `All Godot smoke tests passed.` |
| 전체 탑 회귀 | GREEN 35/35 | `Smoke summary: PASS=35 FAIL=0 TOTAL=35`, `All Godot smoke tests passed.` |
| touched `-Paths` 경고 | GREEN 14/14 | `Godot warning scan passed with no GDScript warnings.` |
| 헤드리스 로드 | GREEN | `Godot headless load check passed.` |
| Vulkan 가시 QA | GREEN 1장 | `tower_ascent_map_overlay_visual_qa: captures=1`, `Tower-ascent map-overlay Vulkan visual QA passed.` |
| 범위 diff | GREEN | `git diff --check 537f3aed4..HEAD` exit 0 |

Vulkan 증거:
`godot/.godot/codex_captures/tower_map_overlay/map_overlay_combat.png`

760×750 실제 전투 드로어 캡처를 육안 검사했다. 제목·닫기 안내·12층 눈금·전
노드 라벨·간선·현재 이중 링·완료·소멸 X·잠금이 프레임 안에 있고, 하단에는
범례 문구나 빈 띠가 없으며 클리핑이나 판독 불가 겹침도 없었다.

첫 Vulkan 실행은 캡처 후 픽스처가 모달/레지스트리 참조를 놓지 않아
`57 resources still in use`로 RED였다. 런타임 변경 없이 하네스 종료에서
`close_map_overlay()`와 viewport·참조 해제를 추가했고, 같은 래퍼를 재실행해
종료 경고 0과 GREEN 종단선을 확인했다.

## 5. 범위 분류

- fixed: 지시문 §1의 4항목 전부.
- deferred: 0건.
- blocked: 0건.
- unverified: 0건.
- 선행 WIP 보존: `battle_scene_input_controller.gd`의 기존
  `request_battle_redraw()` 우선 헝크는 이번 커밋들에 싣지 않았고 워크트리에
  그대로 남겼다. 지도 구현과 검증 결과에는 영향이 없다.
