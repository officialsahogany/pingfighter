# 경로 서브 재작업 완료 보고

- 기준: `docs/tower_serve_route_rework_goal.md` (`0b50f4300`)
- 정본: `docs/tower_ascent_run_map_plan.md` v1.6 §3.2·§3.14
- 판정: **GREEN**
- 푸시: 하지 않음

## 1. 완료 요약

전투 승리 뒤 별도 지도 조준 화면으로 빠지던 흐름을 폐지했다. 하이라이트
리플레이와 상자 지급이 끝난 같은 전투 씬에서 실제 플레이어 서브 공과 다음
노드 표적만 활성화된다. 명중까지 재서브할 수 있고, 명중 뒤에만 지도가 열려
선택 간선 이동을 보여 준다. 비전투 노드 업무 모달은 지도 이동 완료 뒤 도착한
노드에서만 열린다. 타워 플래그 ON 경로는 레거시 결과화면을 호출하지 않으며,
플래그 OFF 경로는 기존 결과화면 소유권을 유지한다.

## 2. 항목별 커밋 매핑

| 항목 | 로컬 커밋 | 결과 |
|---|---|---|
| 1. 별도 발사 화면 폐지 | `087bab2b51a68e59c57b6780a093cac653b0e48a` | 지도·조준선·선택구를 ROUTE_AIM에서 제거하고 전투 씬 위 표적으로 전환 |
| 2. 실제 서브로 선택 | `b9c1cad04235da66a51ee58fefff1d377479e2e1` | 기존 서브 생산자와 공 이동기를 사용하는 전용 부분 시뮬레이션 연결 |
| 3. 표적 표시 | `4aa6e488dd9baf657468fe86c762f3c4b140652e` | 2후보 좌우·1후보 중앙, 기존 노드 표시명, 실전 서브 안내 봉인 |
| 4. 업무 모달 시점 교정 | `57db655bada5c494fe8bc18bfbc65154e62bd6a2` | 지도 도착 뒤에만 NODE_MODAL 진입, 전투 노드는 COMBAT 복귀 |
| 5. 지도 이동 연출 전용화 | `f76e00e3667e4625f6edc70b0e0abfd5269dee24` | 지도 표면을 MAP_TRANSITION에서만 렌더 |
| 6. 결과화면 미등장 | `936242bc6961440215f468f63043e48cbe4ae68f` | 타워 ON 완료·실패 경로 모두 레거시 결과화면 대신 전투 재개 콜백 사용 |

v1.5 전제 씰 교정은 별도 추적 가능한 커밋으로 남겼다.

- `834f353fe3f78474b31ede0a6d0ac74af06f8ba4`: 상점·수련장·파계승·샘터·휴식
  씰을 실제 서브 명중 → 지도 이동 → 노드 도착 순서로 교정했다.
- `25582505e3543e3e451e509d02df1193dc38b585`: 하이라이트 완료 → 상자 시작 →
  상자 완료 → ROUTE_AIM 전 구간에서 레거시 결과화면 호출 0회를 봉인했다.

## 3. 핵심 계약 확인

- ROUTE_AIM 시작은 `begin_vertical_slice()`가 준비된 전투 보상을 커밋한 뒤다.
  따라서 `node_resolution_id`의 준비 → 상자 지급 커밋 → 서브 순서를 보존한다.
- 실제 런타임은 `round_flow_state`, `serve_flow_controller`,
  `battle_scene_ball_update_driver.serve_ball()`, `ball_motion_stepper.step()`을
  사용한다. 프로덕션 의존성이 하나라도 없으면 `missing_route_serve_contract`로
  실패 폐쇄한다.
- 서브 결과는 공의 실제 구간 이동과 표적 원의 swept collision으로 결정된다.
  명중 실패나 득실점 경계 도달 시 다음 플레이어 서브를 준비하며 시도 횟수
  제한은 없다.
- ROUTE_AIM 동안 일반 전투 물리 게이트는 계속 닫혀 있다. 보스 AI·득실점·
  전투 타이머·전투 RNG·루프 오디오는 진행하지 않는다.
- 도착 노드가 비전투 노드면 NODE_MODAL을 열고, 전투 노드면 flow를 닫아 기존
  전투 재개 콜백으로 돌아간다. 업무 종료 뒤에는 같은 flow에서 다시 ROUTE_AIM을
  시작한다.
- MAP_TRANSITION만 지도판을 그린다. ROUTE_AIM·NODE_MODAL·엔딩 오버레이는
  지도판을 렌더하지 않는다.
- 타워 ON에서 flow 시작 실패와 flow 정상 종료 모두 레거시 결과화면으로
  폴백하지 않는다. OFF에서는 기존 `stage_clear_result_screen` 호출 1회와 결과
  화면의 reset 소유권을 유지한다.

## 4. 공 소유권 체크리스트

| 경로 | 사용 여부 | 근거 |
|---|---:|---|
| 기존 플레이어 서브 준비·랜덤 발사 | 사용 | `serve_flow_controller.update()`와 `battle_scene_ball_update_driver.serve_ball()` |
| 기존 공 위치·속도·활성 상태 | 사용 | 전투 owner의 `ball_pos`, `ball_vel`, `ball_active` |
| 기존 벽·득실점 경계 이동 | 사용 | `ball_motion_stepper.step()` |
| 플레이어·보스 패들 충돌 | 제외 | 부분 시뮬레이션 컨텍스트에서 패들을 화면 밖/0 크기로 격리 |
| 보스 AI·점수 처리·스킬/아이템 충돌 | 제외 | 일반 전투 물리 사다리를 실행하지 않음 |
| 경로 표적 충돌 | 전용 | 실제 공의 이전/현재 위치 구간과 표적 hit radius로 판정 |
| 선택 종료·취소 정리 | 수행 | 공 활성/속도 정리, modal lifecycle leave, 재개 안전 훅 |

테스트의 `debug_serve_*`는 RefCounted/null owner용 결정론 픽스처일 뿐이다.
Node 기반 프로덕션 owner는 위 실전 의존성 경로만 허용한다.

## 5. 임시 튜닝 상수

새 발명 수치는 전부 `tower_ascent_tuning.gd`의 `TEMP_*`에만 있다.

| 상수 | 값 | 용도 |
|---|---:|---|
| `TEMP_ROUTE_TARGET_LEFT_X` | 220.0 | 2후보 왼쪽 표적 X |
| `TEMP_ROUTE_TARGET_RIGHT_X` | 540.0 | 2후보 오른쪽 표적 X |
| `TEMP_ROUTE_TARGET_CENTER_X` | 380.0 | 1후보 중앙 표적 X |
| `TEMP_ROUTE_TARGET_Y` | 165.0 | 표적 Y |
| `TEMP_ROUTE_TARGET_DRAW_RADIUS` | 30.0 | 표시 반지름 |
| `TEMP_ROUTE_TARGET_HIT_RADIUS` | 49.0 | 충돌 반지름 |
| `TEMP_ROUTE_TARGET_LABEL_WIDTH` | 184.0 | 노드명 라벨 폭 |
| `TEMP_ROUTE_TARGET_LABEL_HEIGHT` | 30.0 | 노드명 라벨 높이 |
| `TEMP_ROUTE_TARGET_LABEL_GAP` | 8.0 | 라벨-표적 간격 |

## 6. 검증 종단선

### 필수 자동 게이트

- 타워 스모크 32종 + 기존 소비자 회귀 8종:
  `Smoke summary: PASS=40 FAIL=0 TOTAL=40` / `All Godot smoke tests passed.`
- 변경 GDScript 23개 집중 경고 스캔:
  `gd_warning_scan: checked 23/23` / 경고 0.
- 헤드리스 로드:
  `[ApplicationQuitCoordinator] graceful headless shutdown complete` /
  `Godot headless load check passed.`
- 공유 `battle_scene_match_flow_driver.gd`는 타워 헝크만 올린 격리 staged tree
  `4642de64cba233491976a2f897859a563d2fe148`에서 관련 3종 스모크 GREEN을
  증명한 뒤 커밋했다. 패배 resolver·듀스 예고 WIP는 포함하지 않았다.
- `git diff --check`: 범위 변경 이상 없음.

### Vulkan·픽셀 QA

세 래퍼 모두 RTX 5070 Forward Mobile Vulkan, 760×750, BelowNormal,
`-AllowDuringPlay` 조건에서 GREEN이다.

- 경로 서브 4장: `captures=4`, `tower_ascent_vertical_slice_visual_qa: ok`
- 페이즈 C 노드 6장: `captures=6`, `tower_ascent_phase_c_node_visual_qa: ok`
- 페이즈 D 엔딩 6장: `captures=6`, `tower_ascent_phase_d_visual_qa: ok`

경로 서브 핵심 증거 SHA-256:

| 캡처 | SHA-256 | 육안 판정 |
|---|---|---|
| `route_targets.png` | `FF5D3712CF5491E67014BF9F64882476AEA0A1D67F6A72EBC07F075BFFE9997D` | 전투 배경 위 실제 노드명 좌우 표적, 지도·조준 UI 없음 |
| `route_serve.png` | `C849095ED163797D0D013940B2385EEB4AB5B48B218EB6ACF7BAAB551D4DAB31` | 프로덕션 BallRenderer의 공이 표적 사이로 비행 |
| `map_transition.png` | `EAA1EA45BEC8D9749E7D96BF832B662025DFCA9FDA224A99CC8C347B682BFBBF` | 선택 뒤에만 지도와 간선 이동 마커 표시 |
| `node_modal_arrival.png` | `1A94E48FB7584CA3A6F1024629243FAFDC7B3FB5E6DFAA605191DA12660B8A78` | 지도 종료 뒤 도착한 샘터 업무 모달 표시 |

### 전체 경고 baseline 분리

실수로 시작된 저장소 전체 3,717개 GDScript 스캔은 이번 범위 밖
`res://tests/perk_conversion_shop_stock_smoke.gd:37,38,53,54`의
`_build_pool()` 인자 수 드리프트에서 RED였다. 변경 23개 집중 스캔은 별도로
GREEN이며, 이 baseline 부채를 본 작업에서 수정하거나 커밋하지 않았다.

## 7. 최종 분류

- **fixed**: §1의 6항목 전부, v1.5 노드 즉시 모달 씰 6종, 하이라이트/상자
  결과화면 부정 레그.
- **deferred**: 범위 밖 전체 경고 baseline 1건
  (`perk_conversion_shop_stock_smoke.gd` 인자 수 드리프트). 사용자 라이브
  `run_tower_mode.ps1` 체감 확인은 지시문에 명시된 완료 후 검증 단계다.
- **blocked**: 0건.
- **unverified**: 필수 게이트 0건.

원본 워크트리의 다른 WIP와 사용자 Godot 편집기/플레이 세션은 보존했다.

## 8. 라이브 ROUTE_AIM 입력 정지 후속 수정 (2026-08-18)

### 원인과 수정

사용자 라이브 런에서 ROUTE_AIM 진입 뒤 플레이어 이동과 수동 서브가 모두
멈추는 결함이 확인됐다. 실제 물리 호출 경로는
`battle_scene_frame_controller.process_physics()` →
`battle_physics_gate_coordinator.should_block()` →
`tower_ascent_flow_owner.update_selective()`였고, 게이트는 의도대로 일반 전투
사다리를 반환 전에 차단했다. 그러나 선택적 flow가 서브 대기·공 이동만
갱신하고 플레이어 입력 스냅샷과 수평 이동을 전혀 틱하지 않은 것이 원인이다.

`tower_ascent_route_serve_runtime.gd`의 프로덕션 계약에 선택 캐릭터의 실제
input reader, `player_movement_state`, `battle_update_context`,
`battle_scene_player_control_config_builder`를 추가했다. ROUTE_AIM 한 물리 프레임은
이제 아래 순서를 명시적으로 소유한다.

1. 공유 input reader의 `get_snapshot()`을 정확히 한 번 호출한다.
2. 그 스냅샷의 방향과 실제 플레이어 이동 설정으로 위치·속도·애니메이션
   프레임을 갱신한다.
3. 기존 `serve_flow_controller`가 수동/자동 서브 에지를 처리한다.
4. 같은 프레임에 서브가 성립하면 기존 공 소유자와 `ball_motion_stepper`를
   즉시 틱한다.
5. 실제 공의 swept 구간으로 표적 명중을 판정하고 MAP_TRANSITION으로 넘긴다.

입력 스냅샷은 프레임당 한 번만 읽으므로 GRT-019의 same-frame idempotent 계약을
보존한다. 보스 AI·득실점 처리·전투 타이머·전투 RNG·전투 쿨다운의 일반
사다리는 계속 닫혀 있다. 새 이동 의존성 가운데 하나라도 없으면 기존과 같이
`missing_route_serve_contract`로 실패 폐쇄한다.

### GRT-053 프레임 경로 씰

`tower_ascent_route_serve_smoke.gd`의 주 회귀 레그를 직접 debug 발사 헬퍼가 아닌
실제 `battle_physics_gate_coordinator.should_block()` 관통 경로로 승격했다. 한
코디네이터 프레임 안에서 다음을 단언한다.

씰은 게이트 추출 WIP와 이 3파일 수정의 커밋 경계를 섞지 않도록
`battle_physics_gate_coordinator.gd`가 존재하면 추출 코디네이터를 관통하고,
격리된 3파일 커밋 트리처럼 아직 추출 파일이 없으면 커밋된
`battle_scene_frame_controller._process_tower_ascent_flow()`의 동일 프로덕션
분기로 관통한다. 현재 라이브 워크트리 재검증은 추출 코디네이터 경로를 탔다.

- 호출 순서: `input_snapshot → player_movement → serve_trigger → serve_ball → ball_step`
- 플레이어 X 위치 증가와 input snapshot 1회/이동 1회
- 실제 서브 생산자 호출 1회와 공 스텝 1회
- swept 표적 명중 뒤 `ROUTE_AIM → MAP_TRANSITION`
- 게이트 반환은 계속 `blocked=true`, modal pause fanout 1회
- 플레이어/보스 점수와 전투 쿨다운 불변

수정 전 이 레그는 이동·스냅샷·공 스텝·명중 전이에서 RED였고, 수정 뒤 GREEN이다.

### 후속 검증 종단선

- 집중 프레임 경로/GRT 회귀 3종:
  `Smoke summary: PASS=3 FAIL=0 TOTAL=3` / `All Godot smoke tests passed.`
  (`tower_ascent_route_serve`, `battle_physics_gate_coordinator_owner`,
  `player_input_reader_same_frame_edge`)
- 탑 전체 회귀 35종:
  `Smoke summary: PASS=35 FAIL=0 TOTAL=35` / `All Godot smoke tests passed.`
- 변경 GDScript 2개 집중 경고 스캔:
  `gd_warning_scan: checked 2/2` / 경고 0.
- 헤드리스 로드:
  `[ApplicationQuitCoordinator] graceful headless shutdown complete` /
  `Godot headless load check passed.`
- 실행 중인 사용자 게임 PID 38784는 종료하지 않았다. 모든 검증은
  `-AllowDuringPlay`, BelowNormal, 고유 로그 계약으로 병행했다.

후속 판정: **GREEN**. blocked 0건, 필수 자동 게이트 unverified 0건. 이미 떠 있는
게임 프로세스는 수정 전 스크립트를 유지하므로 다음 새 탑 런에서 체감을
재확인할 수 있다.
