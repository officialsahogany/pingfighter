# 탑 슬라이스 미활성 회귀 /goal 지시문 (2026-08-18) — 긴급

- **증상 (사용자 라이브)**: `run_tower_mode.ps1` 실행 시 승리 후 **경로 서브
  화면과 노드 지도 화면이 둘 다 나오지 않고** 곧바로 다음 스테이지로 넘어간다.
  보스 배선 목표(`2ea679eff`) 통합 이후 발생했다.
- **완료 보고**: `docs/tower_slice_activation_regression_report.md`. 푸시 금지.

## 1. Fable이 확보한 증거 (재확인 후 착수할 것)

1. **플로우가 한 번도 활성화되지 않는다.** 최신 라이브 로그
   (`%APPDATA%/Godot/app_userdata/pingfighter/logs/godot.log`)에서
   `physics.frame.gate.tower_ascent_flow`의 153개 샘플 전체가 **최소 7.5us /
   최대 12.9us**다(비활성 상태의 게이트 통과 비용). 같은 로그에서 `stage=1`과
   `stage=2`가 모두 관측되므로 **첫 승리에서 이미 탑이 건너뛰어지고** 레거시
   진행으로 다음 스테이지에 갔다.
2. **통합 직전에는 정상이었다.** `godot2026-08-18T11.24.25.log`의 같은 지표는
   **390us / 373us**(활성)다. 즉 이 회귀는 보스 배선 통합으로 생겼다.
3. **플래그는 켜져 있다.** `run_tower_mode.ps1`의 기본(인자 없음) 경로는
   종전과 동일하게 `TOWER_ASCENT_VERTICAL_SLICE=1`을 세우고 실행한다.
4. **호출 경로는 살아 있다.** `battle_scene_match_flow_driver.gd`에서
   `_try_start_victory_presentation`(:282)이 `_prepare_tower_ascent_vertical_slice`
   (:285)를 부르고, `_continue_after_victory_presentation`(:343)과 승리 분기
   (:149)가 `_try_start_tower_ascent_vertical_slice`를 부른다. 이 함수는 플래그
   확인 후 `flow_owner.begin_vertical_slice(...)` 결과를 그대로 반환한다.
5. **따라서 `begin_vertical_slice`가 false를 반환하고 있다.**
   `tower_ascent_flow_runtime.gd:4-33`의 false 반환 지점은 다섯이며 **전부
   무음**이다(로그에 에러·경고가 한 줄도 없다):
   `_active` / `prepare_vertical_slice_combat` 실패 / `_modal_lifecycle.enter`
   거부 / `_complete_prepared_combat_resolution` 실패 / `_enter_route_aim` 실패.
6. **스모크가 못 잡은 이유(가장 중요)**: `tower_ascent_vertical_slice_smoke`는
   `FakeOwner`로 구동한다. 라이브 owner는 `battle_scene_shell.gd`(Node2D)이며
   전투 키를 `_get`/`_set` 메타 메서드로만 노출한다. **이것은 커밋
   `f78ee1f1f`에서 이미 한 번 실물화된 동일 계열의 함정이다**(그때도 스모크
   GREEN·라이브 무효). 픽스처 GREEN을 근거로 삼지 말 것.
7. 통합에서 이 경로에 닿는 변경: `tower_ascent_flow_map_progress.gd`(+166),
   `tower_ascent_flow_ending_progress.gd`(+28),
   `battle_scene_match_flow_driver.gd`(+24),
   `battle_scene_input_controller.gd`(+50).

## 2. 작업 항목

1. **원인 특정 (진단 우선)**: 다섯 후보 중 어디서 false가 나는지 **런타임
   증거로** 특정한다. 정적 분석 단정 금지. 임시 계측을 넣더라도 최종 커밋에는
   남기지 말고, 대신 **무음 실패를 없애는 구조적 조치**를 남긴다 — 이 경로의
   각 거부 지점은 최소한 `push_warning`으로 사유를 남겨야 한다. 이번 회귀가
   로그 한 줄 없이 발생한 것 자체가 결함이다.
2. **수정**: 특정된 원인을 고친다. 보스 배선(도착 노드 → 실제 전투)과 유일
   해소 id, 진행 캐리오버, 지도 시드 유지는 **되돌리지 말 것**. 회귀는 그
   기능들을 유지한 채 고친다.
3. **실물 셸 씰 (필수)**: `tower_ascent_vertical_slice_smoke`의 승리 사이클
   레그를 **실제 `BattleSceneShell`(Node2D, 메타 `_get`/`_set`) owner**로
   구동하는 레그로 보강한다. `FakeOwner` 레그는 남겨도 되지만, 실물 셸에서
   **첫 승리에 `begin_vertical_slice`가 true를 반환하고 ROUTE_AIM에 진입**하는
   것을 단언하는 레그가 반드시 있어야 한다. 이 레그가 수정 전 코드에서 RED가
   되는지 반증으로 확인하고 보고서에 인용한다.
4. **연속 2전 레그**: 첫 승리뿐 아니라 **같은 런의 두 번째 승리**에서도
   활성화되는지 봉인한다(재진입 캐리오버가 도입되었으므로 1회 통과가 2회를
   보장하지 않는다).

## 3. 규율

- ⚠ **본 트리에 사용자 미커밋 WIP이 있다.** 특히
  `godot/scripts/core/battle_scene_match_flow_driver.gd`에 25삽입·116삭제 규모의
  진행 중 리팩터가 있다. 격리 워크트리에서 작업하고, 통합 시 이 WIP을 절대
  건드리지 말 것. `git stash`·`git checkout`·통짜 `git add` 금지.
- 로그 백업 선행. 표준 래퍼 `-AllowDuringPlay`. 커밋 분리·푸시 금지.
- 검증: 탑 회귀 세트 전체 + 신규 실물 셸 레그 + `-Paths` 경고 + 헤드리스 +
  **`run_tower_mode.ps1` 실플레이로 첫 승리에서 서브 화면이 나오는 것을 확인**
  (Vulkan 캡처 1장 이상). 라이브 로그에서
  `physics.frame.gate.tower_ascent_flow`가 300us대로 올라오는 것을 인용한다.
- 판정 불가 지점이 나오면 중단·보고.

**완료 선언 조건**: §2의 4항목 구현·검증 + 게이트 blocked/unverified 0건 +
보고서 완성.
