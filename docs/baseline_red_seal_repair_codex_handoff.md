# 지시문 U1 — [P0] 푸시를 막고 있는 기저 RED 씰 2종 수리

- **발행**: 관제탑 2026-08-25. 기준 HEAD `6fbd9cab5`. CI/pre-push 락스텝 238.
- **격리 워크트리**: `D:\codex_tmp\bosspong_baselinered_6fbd` (브랜치
  `codex/baseline-red-seal-repair-20260825`).
- **금지**: 본 트리 편집·푸시·통합. 보고 후 대기.
- ⚠**디스크**: D:에 여유가 약 50GB뿐이고 워크트리 1개가 약 10GB를 쓴다.
  워크트리는 **1개만** 만들고 작업 후 반드시 제거하라.

## 왜 P0인가

`.github/workflows/godot-ci.yml`과 `godot/tools/run_pre_push_checks.ps1`에
**양쪽 등재된** 씰 2종이 본 트리에서 RED다. 관제탑이 HEAD에서 직접
실행해 확인했다. **이 상태로는 푸시가 막힌다.**

두 건 모두 **씰 스테일이 주원인이고 제품은 대체로 건강하다.**
관제탑 프로브가 실 런타임을 시드만 고쳐 구동한 결과 진짜 계약 단언은
전부 통과했다. 제품을 "고치려" 들지 마라.

---

## [P0-A] `tower_noncombat_node_background_retention_smoke` — 순수 씰 스테일

- 등재: `godot-ci.yml:92` / `run_pre_push_checks.ps1:96`.
- 실패 2건(둘 다 `:144`):
  - `rest return phase probe must expose rest`
  - `the reached optional node must expose a combat exit`
- **둘 다 계약 단언이 아니라 픽스처 전제**다. 하드코딩된 `map_seed`가
  생성기 변화와 어긋난 것뿐이다.
- 회귀 지점: **`8e0421767`**(1층을 선택형 보스 조우 구간으로 확장, S8,
  2026-08-23). 마지막 GREEN은 `98fa51ad5`이고 그 커밋이 이 씰 파일을
  마지막으로 만진 커밋이기도 하다.
- 기전:
  1. S8이 1층 관문과 옛 `floor_02_route_01` 사이에 4행을 끼워 넣었다
     (`FLOOR_ONE_EXPANSION_ROW_ROLES`, `map_generator.gd:37~42`).
     이제 `initial_route_candidate_ids`를 채우는 행은
     `floor_01_expansion_route_01`이고, 그 종류는 **독립 난수 스트림**에서
     뽑힌다(`floor_one_rng.seed = (map_seed ^ 0x31464C52) & 0x7fffffff`,
     `map_generator.gd:65~68`). 그래서 seed 4의 첫 행이
     `[rest, guardian_spring]` → `[guardian_spring, shop]`으로 바뀌었다.
  2. S8이 `_has_floor_one_boss_avoidance_path()`(`map_generator.gd:396`,
     `:613`)를 도입했다. seed 2에서 guardian_spring 레인이 **바로 그
     보스 회피 레인**이라 출구가 `rest` 하나뿐이다. 즉 "도착한 노드는
     항상 전투 출구를 갖는다"는 전제를 **생성기가 의도적으로 거짓으로
     만든다.**
- ⚠**커버리지 구멍(진짜 문제)**: `:159~160` `if rest_target.is_empty(): return`과
  `:240~241` `if combat_target.is_empty(): return`가 레그 전체를 조용히
  중단시킨다. 저장소 전체에서 `get_retained_noncombat_node_background_kind`
  와 `build_noncombat_node_background_model`을 만지는 테스트는 이 파일뿐이라,
  **유지 배경 해제 계약이 2026-08-23부터 무단언 상태**다(GRT-040 계열).

### 작업

1. **정본 시드 유도 채택**: 레그 1의 `"map_seed": 4` 리터럴을
   `TowerAscentNodeArrivalTestFixture.find_initial_route_seed("rest")`로
   교체하라. 실측 결과 1을 반환하고 레그 전체가 HEAD에서 통과한다.
   ※이 헬퍼는 `bc5890dd1`이 도입해 6개 노드 스모크를 쓸었는데
   **이 파일만 빠졌다.** 그 스윕을 마저 하는 것이다.
2. **레그 2용 헬퍼 신설**: `find_initial_route_seed`만으로는 부족하다
   (guardian_spring → 2를 주는데 seed 2가 바로 회피 레인이다).
   `godot/tests/tower_ascent_node_arrival_test_fixture.gd`에
   `find_initial_route_seed_with_combat_exit(expected_kind: String) -> int`
   를 **추가**하라 — 같은 1..512 범위를 훑되, 해당 후보가
   `TowerAscentMapGenerator.NONCOMBAT_NODE_KINDS`에 없는 종류의 출구
   간선을 하나 이상 가질 것을 추가 요구한다.
   ⚠**기존 `find_initial_route_seed`의 동작을 바꾸지 마라.** 이 픽스처는
   9개 파일이 공유한다. 반드시 **추가** 함수로.
   실측 유효 시드: 4, 7, 16, 21, 24, 29. seed 4가 `:199~248`을 끝까지 통과.
3. **조용한 중단 제거**: 시드 유도 자체를 하드 게이트로 만들어라.
   유도된 시드가 0이면 **누락된 픽스처 형태를 지명하며 실패**시켜라.
   `:158`/`:239` 문구도 픽스처 전제 실패로 바꿔라
   (예: "no map seed exposes a rest node in the first route row",
   "no map seed exposes a guardian_spring whose reached node owns a
   combat exit"). 지금 문구는 제품 계약처럼 읽힌다.
4. ⚠**제품을 고치지 마라.** 단일 출구 보스 회피 레인은 S8의 설계
   불변식이며 `tower_ascent_floor_one_expansion_contract_smoke.gd`가
   GREEN으로 봉인하고 있다.
5. `:203` "deterministic fixture must expose guardian_spring"는 현재
   seed 2에서 **우연히** 통과 중이다(8e0421767에서 RED였다가
   `649151be4`에서 회복). 레그 2 시드를 재유도할 때 이 단언도 **같이
   재앵커**하라.

---

## [P0-B] `tower_map_camera_drag_contract_smoke` — 씰 스테일 5 + 제품 결정 1

- 등재: `godot-ci.yml:86` / `run_pre_push_checks.ps1:90`.
- 실패 6건 전부 `:42`. **첫 실패가 나머지를 연쇄로 무너뜨리는 구조**다.
- 회귀 지점: **`19b520caf`**("Adjust tower map default zoom and route
  wind", 2026-08-24). 마지막 GREEN은 그 부모 `f6b549eff`(코드 경로
  분석으로 도출, 실행 미검증).
- 기전: 지도 기본 프레이밍이 4노치 아웃 서라운드로 바뀌면서 두루마리
  폭이 화면보다 좁아졌다. 가로 팬이 **중앙 핀 고정**이 되어
  "walking closeup must expose horizontal drag range"(가로 드래그 범위
  min<max)가 성립하지 않는다. 이는 S6 족자 서라운드 설계대로이며
  **잃은 기능이 아니다.**
- 플레이어 영향(실측 판정): 지도를 못 움직이거나 화면 밖으로 나가는
  수준이 **아니다.** 실제 손실은 노드 이동 전환(약 1.6초) 중 드래그로
  시점을 고정해도 자동 줌 램프가 그 아래에서 계속 확대돼 화면이 밀리고,
  투영 폭이 뷰포트 폭을 넘는 순간 가로축이 "중앙 고정 → 수동 오프셋"으로
  한 번 튀는 것이다.

### 작업 A — 씰 재정렬 (5건)

6. `:128`의 픽스처를
   `_new_transition_fixture("map-drag-bounds", 0.0)` →
   `_new_transition_fixture("map-drag-bounds", TowerAscentTuning.TEMP_MAP_TRANSITION_TRAVEL_SEC)`
   로 옮겨 형제 씰(`tower_fullscreen_map_cover_contract_smoke`의
   "walking travel-end closeup")과 샘플 지점을 일치시켜라. 그래야
   "walking closeup"이라는 이름과 실제 프레이밍이 다시 맞는다.
7. **사라진 옛 계약을 버리지 말고 승격하라.** travel 시작점(0.0)을
   **새 양성 레그**로 만들어라: `subcover_active == true`,
   `camera.horizontal_world_fits == true`,
   `offset.x == view.center.x − world.center.x * zoom`(중앙 핀),
   세로 클램프는 여전히 동작. 이러면 "기본=서라운드 4노치 아웃 /
   클로즈업=cover" 두 프레이밍이 한 씰에 봉인된다.
8. **반증 레그**: `render_zoom`을 cover로 강제한 모델에서 가로 범위가
   다시 열리는지(min < max) 확인해 6)이 공허 GREEN이 아님을 증명하라.

### 작업 B — 제품 결정 1건 (**관제탑 확정: (ii) 월드 앵커 보존**)

9. "manual drag must outrank automatic walker tracking and remain where
   released"가 깨지는 것은 `_manual_camera_offset`이 **원시 스크린
   오프셋**이라 자동 줌 램프 아래에서 의미가 보존되지 않기 때문이다.
   **(ii)안으로 확정한다**: 자동 줌이 바뀔 때마다
   `TowerAscentMapCameraModel.cursor_anchored_offset`을 뷰 중앙 기준으로
   재적용해 오프셋을 다시 써 넣어라. **휠 경로가 이미 쓰는 해법**이라
   새 개념을 만들지 않고, 줌인 연출은 유지되면서 시점만 안 밀린다.
   - 기각한 대안: (i) 줌 램프 정지 — 이동 연출을 죽인다.
     (iii) 설계상 수용 — 사용자가 드래그로 고정한 시점이 밀리는 체감이
     남는다.
10. 씰의 비교 기준을 **raw offset → 월드 앵커**(`visible_world_rect`
    중심 동일성)로 바꿔라. 줌이 움직이는 새 설계에 견고하다.
11. 제품 수리 접촉면: `tower_ascent_flow_renderer.gd`
    (`build_fullscreen_map_model` 762~856),
    `tower_ascent_map_drag_state.gd`(오프셋 재앵커 API 신설),
    `tower_ascent_flow_runtime.gd`(재앵커 호출부). 형제 씰
    `tower_map_wheel_zoom_contract_smoke` /
    `tower_map_camera_tracking_smoke` /
    `tower_fullscreen_map_cover_contract_smoke`가 같은 카메라 모델을
    읽으므로 **락스텝 재실행 필수**.

---

## [P1] 같은 계열 전수 스윕

12. 하드코딩 `map_seed` 리터럴이 남아 생성기 변화에 스테일해질 씰이
    **더 있는지 전수 조사**하라. `bc5890dd1`이 6개를 쓸었지만 이번에
    누락이 하나 드러났다. `godot/tests/` 전체에서 `map_seed` 리터럴을
    찾아, 1층 구성표에 의존하는 것들을 `find_initial_route_seed*` 계열로
    돌리거나 최소한 목록으로 보고하라.
    ⚠근거 정본: `tower_ascent_node_arrival_test_fixture.gd:17~39`의 주석
    ("노드 스모크의 map_seed 리터럴은 생성기 버전이 바뀔 때마다 1층
    구성표와 조용히 어긋난다 … GRT-054 형제").

## 참고 — 이 지시문 범위 밖의 기저 RED 2종

미등재라 푸시를 막지 않는다. 손대지 말고 목록만 유지하라.

- `tower_ascent_flow_owner_refactor_smoke` (2건)
- `tower_audition_build_smoke` — 보류된 "내보낸 빌드 지도 생성 16.5%
  실패"(`docs/tower_map_deferred_findings_2026_08_25.md`)와 같은 건이다.

## 게이트·보고

두 씰 + 형제 카메라 씰 5종(`cover_contract`·`camera_tracking`·
`wheel_zoom`·`walker_zoom_intro`·`map_overlay_render`) + 노드 스모크 6종을
한 배치로 → `-Paths` 경고 → 헤드리스 로드 → `git diff --check`.
**RED 반증**: 시드를 4/2로 되돌리고, 드래그 픽스처를 0.0으로 되돌려
새 메시지가 실제로 발화하는지 확인 후 복원.
보고=워크트리·커밋 해시·씰 종단선 원문·(9)의 재앵커 구현 지점·
(12) 전수 스윕 결과 목록·미해결. **워크트리 제거까지 하고 보고하라.**
