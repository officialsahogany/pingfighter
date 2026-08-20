# 필러 재화 HUD 가로 정렬 실행 보고

- 기준 HEAD: `7805939301ed77d1583cbcb986b21756ed21a822`
- 격리 워크트리: `C:\Users\woduq\.codex\tmp\bosspong_r4_integration_dcf`
- 작업 브랜치: `codex/pillar-currency-hud-layout-20260820`
- 통합/푸시: 하지 않음

## S1. 게이트와 생산 소유자 조사

| 표시 | 가시성 조건 | 생산 경로 | 결론 |
|---|---|---|---|
| 금화 | `stage1_pillar_hud_scene_drawer.gd:201`에서 필러 HUD를 그릴 때 별도 조건 없이 `_draw_gold_hud()` 호출. `:453-468`이 금액 컨텍스트를 만들고 공용 렌더러로 전달 | `stage1_pillar_hud_scene_drawer.gd` -> `stage1_pillar_ui_renderer.gd:338-339,344-372` | 모든 전투 필러 화면에서 표시 |
| 무혼 | `stage1_pillar_hud_scene_drawer.gd:592-612`가 캐시된 탑 소유자와 비어 있지 않은 `run_id`를 요구하고 `tower_muhon_hud_visible=true`를 공급. 렌더러 `:338-341`이 그 플래그일 때만 무혼을 추가 | 같은 생산 경로의 탑 런 분기 | 진행 중 탑 런에서만 표시 |

실재 조합은 두 가지다.

| 화면 | 금화 | 무혼 | S2 배치 규칙 |
|---|---:|---:|---|
| 일반 전투/탑 런 없음 | 표시 | 숨김 | 기존 단일 금화 위치와 크기를 유지한다. 공용 렌더러의 형제 화면 부정 레그다. |
| 탑 전투/유효한 `run_id` | 표시 | 표시 | 좌측 필러 안에서 같은 y의 두 항목을 가로 배치한다. |

무혼만 단독 표시되는 생산 조합은 없다. `draw_gold_hud()`가 금화를 먼저 그리고 같은
호출 안에서만 무혼을 조건부로 덧그리기 때문이다. 현재 `build_muhon_hud_rect()`는
`stage1_pillar_ui_renderer.gd:320-326`에서 금화 rect 아래에 세로 적층하므로 S2의 실제
수정 소유자는 이 공용 렌더러다. 탑 노드 모달의 `BALANCE_ROW_RECT` 작업은 별도
소유자이며 되돌리지 않는다.

## 슬라이스 상태

### S1 검증 메모

- 기준 HEAD에는 HUD 스모크의 의존 스크립트 두 곳에서 누락된 명시적 preload가 있었다. `right_pillar_portrait_renderer.gd`의 `PremiumPanelFrame`과 `perk_fusion_cold_boot_cinematic.gd`의 `WritheEmberMaterial`을 생산 소유자에 직접 preload해 기준 컴파일 부채를 보수했다.
- 집중 스모크: `ingame_gold_hud_smoke.gd`, `tower_battle_muhon_hud_smoke.gd` 모두 PASS, 래퍼 종단선 `All Godot smoke tests passed.` 확인.
- 집중 경고 스캔: 위 두 보수 파일 2개, GDScript warning 0.
- 전체 headless load는 두 작업 격리 워크트리에 공통으로 존재하는 LFS 포인터/누락 import cache 때문에 실패했다. 첫 오류는 `loading_cameo_dalji_hoop_roll_16f_autosprite_v1.png`가 PNG 대신 LFS 포인터라는 기준 환경 결함이며, S1 변경 경로와 무관하다. 이 상태를 GREEN으로 오인하지 않고 최종 공통 게이트에서 별도 추적한다.

### S4 Vulkan 픽셀 증거

- 실행: `godot/tools/run_pillar_currency_hud_visual_qa.ps1`
- 해상도/드라이버: 2020x1246, Forward Mobile, Vulkan, NVIDIA GeForce RTX 5070.
- 생산 경로: 캡처 스크립트가 `Stage1PillarHudSceneDrawer._draw_gold_hud()`를 호출하고, 실제 컨텍스트 공급을 거쳐 공용 `Stage1PillarUiRenderer`를 소비한다.
- 최대값 `99,999`에서 밝은 탑 6,855px, 어두운 탑 5,837px, 비탑 금화 단독 4,006px의 배경 대비 픽셀을 확인했다. 각 재화 rect 네 코너 중 3개 이상이 바뀌는 평면 프레임/직사각형 헤일로는 0건이다.
- 캡처 디렉터리: `godot/.godot/codex_artifacts/pillar_currency_hud/`
  - `tower_bright_2020x1246.png`
  - `tower_dark_2020x1246.png`
  - `non_tower_bright_2020x1246.png`
- 종단선: `pillar_currency_hud_visual_qa: captures=3`, `pillar_currency_hud_visual_qa: ok`, 래퍼 `Pillar currency HUD Vulkan visual QA passed`.

### 최종 공통 게이트

- 집중 스모크 `ingame_gold_hud_smoke.gd`, `tower_battle_muhon_hud_smoke.gd`: PASS=2, FAIL=0, 종단선 `All Godot smoke tests passed.`, `SCRIPT ERROR` 0건.
- 변경 GDScript 5개 집중 경고 스캔: warning 0.
- 전체 headless load: `[ApplicationQuitCoordinator] graceful headless shutdown complete` 뒤 `Godot headless load check passed.`
- 재사용 워크트리의 LFS 포인터 문제는 새 워크트리를 만들거나 import를 돌리지 않고 해결했다. 전체 로드 로그가 요구한 37개 LFS 객체만 OID/SHA-256 일치 확인 후 물질화하고, import 캐시 34개는 동일 소스 해시가 봉인된 광맥결 격리 워크트리에서 복사했다. 추적 diff는 생기지 않았다.
- 개정 씰 `tower_battle_muhon_hud_smoke.gd`는 CI와 pre-push 두 리터럴 목록에 각각 1회 등재되어 있다.
- `git diff --check` 통과. blocked 0, unverified 0.

| 슬라이스 | 상태 | 커밋 | 검증 |
|---|---|---|---|
| S1 게이트 조사 | 완료 | `3607f353e` | 기존 `tower_battle_muhon_hud_smoke` 및 기준 게이트 |
| S2 가로 배치 | 완료 | `3e7276411` | 최대값 `99,999` 2개, 2020x1246 환산 필러, 일반 전투 부정 레그 PASS |
| S3 테두리 제거 | 완료 | `5ef0ae239` | 두 프레임 helper·`PremiumPanelFrame` 제거, 두 문자열 outline 봉인 PASS |
| S4 씰과 캡처 | 완료 | 현재 S4 커밋 | 2020x1246 실제 폰트 폭·밝음/어두움 픽셀·비탑 부정 레그 PASS |
