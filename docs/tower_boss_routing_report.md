# 탑 보스 배선 복구 완료 보고서

작성일: 2026-08-18
기준 커밋: `ea5f03c03a144f83777e6bfd3fb95dce673f46cf`
작업 브랜치: `codex/tower-boss-routing-ea5f03c03`
작업 트리: `D:\main\bosspong_tower_boss_routing_ea5f03c03`
원본 체크아웃: `D:\main\bosspong` (기존 dirty/untracked WIP 보존)
푸시: 하지 않음

## 결론

`docs/tower_boss_routing_goal.md`의 6개 작업 항목을 모두 구현하고 실제 프로덕션 경로와 Vulkan 화면으로 검증했다. 탑 지도에서 고른 보스가 기존 전투 전환/보스 선택 경로로 전달되며, 전투 복귀 후에도 노드별 해결 ID·런 진행 상태·지도 시드·스킵 보스 상태가 유지된다. 별건이었던 노드 모달 포인터 좌표계 오류도 기존 760×750 플레이필드 변환을 사용하도록 수정했다.

- fixed: 6개 작업 항목 및 검증 등록 완료
- deferred: 0건
- blocked: 0건
- unverified: 0건

## 작업 전 보호 조치

- 원본 HEAD `ea5f03c03`에서 별도 worktree와 전용 브랜치를 생성했다.
- 로그 백업: `D:\codex_backups\tower_boss_routing_20260818_162000`
  - user logs: 5개, 64,226,452 bytes
  - Godot logs: 15개, 15,436 bytes
  - repo logs: 400개, 816,722 bytes
- 원본의 실행 중 Godot 편집기/게임 프로세스를 종료하지 않았고 원본 WIP를 reset, checkout, stash, clean, stage하지 않았다.
- 검증 과정에 필요했던 비추적 캠프파이어 에셋 복제본은 SHA-256이 원본 체크아웃의 파일과 동일함을 확인한 뒤 작업 worktree에서만 제거했다. 원본 파일은 그대로 남아 있다.

## 구현 내용

### 1. 선택 보스를 실제 전투에 배선

- `tower_ascent_boss_registry.gd`에 `resolve_battle_encounter(slot_id)`를 추가해 슬롯 ID를 실제 `stage`, `boss_id`, `variant`, 표시명 및 fallback 정보로 해석한다.
- `tower_ascent_flow_ending_progress.gd`가 전투 노드 도착 시 해당 encounter를 해석해 전투 시작 콜백에 전달한다.
- `battle_scene_match_flow_driver.gd`와 `battle_scene_match_event_driver.gd`가 이 encounter를 기존 로딩 전환과 보스 선택 경로에 주입한다.
- 잘못된 슬롯은 오류를 숨기지 않고 진단 로그를 남긴 뒤 기존 호환 fallback으로 이동한다. 비탑/빈 encounter에서는 탑 전용 보스 상태를 비워 다른 전투에 누출되지 않게 했다.
- 보스 variant가 전환 중 반복되는 선택 동기화에도 유지되도록 했으며, 기존 패들 크기와 히트박스 계약을 보존했다.

### 2. 전투 노드별 해결 ID를 유일하게 발급

- 전투 준비 시 고정된 `combat_victory` ID 대신 실제 도착한 전투 노드 ID를 pending/resolution ID에 반영한다.
- 같은 런의 첫 번째와 두 번째 전투가 서로 다른 해결 ID를 받는 것을 동일 인스턴스 연속 호출 테스트로 봉인했다.

### 3. 전투 복귀 시 런 진행 상태 유지

- 전투 전후에 보존해야 할 필드를 명시적인 `REENTRY_PROGRESS_FIELDS` allowlist로 정의했다.
- 맵 위치, 해결/구매 이력, 인벤토리·경제·빌드·수호령·휴식·엔딩·도감·패배·RNG 상태와 스킵 보스 상태를 런 재진입 시 복원한다.
- `run_state.begin()`이 `active_phase_index`와 `skipped_boss_ids`를 포함하도록 정리했다.
- 단일 인스턴스에서 `prepare_vertical_slice_combat`를 두 번 호출해 reset 뒤 복원이 실제로 일어나는 경로를 검증했다.

### 4. 지도 시드의 런 전체 소유권 유지

- 전투 진입 완료 시 `_map_seed`를 0으로 되돌리던 처리를 제거했다.
- 두 번째 전투 준비 뒤에도 최초의 nonzero 시드가 그대로 유지되고 동일 런의 지도가 시드 0으로 재생성되지 않음을 검증했다.

### 5. 스킵 보스의 재등장 차단

- 분기에서 선택하지 않은 형제 보스를 `skipped_boss_ids`에 기록하고, 런 재진입과 그래프 재생성 뒤에도 유지한다.
- 이후 선택 가능한 보스 후보 캐시가 해당 스킵 보스를 제외하는 것을 프로덕션 resolver를 통해 검증했다.

### 6. 노드 모달 포인터 좌표계 수정

- `battle_scene_input_controller.gd`가 화면 마우스/터치 좌표를 기존 `battle_view_layout`의 offset/scale로 760×750 플레이필드 좌표로 투영한 뒤 모달에 전달한다.
- offset 700, scale 2 조건에서 상단 모서리 내부 `+2,+2`를 실제 클릭하는 테스트를 추가했다.
- 변환 전 화면 좌표는 의도적으로 대상 밖에 있으므로, 좌표 투영 코드가 제거되면 테스트가 실패한다. 중앙점만 누르는 공허한 테스트가 아니다.

## 회귀 봉인과 실패 의미

### `tower_boss_routing_smoke.gd`

- 선택한 슬롯이 registry에서 기대한 stage/boss/variant로 해석되는지 확인한다.
- 실제 match-flow 보스 전환 함수를 통과해 전투 드라이버에 같은 값이 들어가는지 확인한다.
- 잘못된 stage, variant, fallback 또는 선택 보스와 다른 실제 전투 보스가 나오면 실패한다.
- 동일 런에서 두 차례 전투 준비를 수행해 노드별 해결 ID, 진행 carryover, nonzero 시드 유지 및 스킵 보스 미등장을 함께 검증한다.

### `tower_node_modal_pointer_smoke.gd`

- letterbox offset/scale이 있는 실제 화면 좌표를 플레이필드 좌표로 변환한다.
- 상단 모서리 내부를 클릭해야만 선택이 성립하며, 예전의 변환되지 않은 좌표는 대상 밖임을 역방향으로도 확인한다.
- 변환 호출을 제거하거나 offset/scale 계산을 잘못하면 실패한다.

### 기존 vertical-slice smoke 보강

- 실제 routed combat return 계약에 맞게 두 번째 전투 진입을 수행한다.
- 단순 helper 반환값만 검사하지 않고 reset/re-entry 경로를 통과한다.

### CI 및 pre-push 등록

신규 두 smoke를 아래 focused 목록에 각각 정확히 한 번 등록했다.

- `.github/workflows/godot-ci.yml`
- `godot/tools/run_pre_push_checks.ps1`

등록 개수 감사 결과:

- `tower_boss_routing_smoke.gd`: CI 1회, pre-push 1회
- `tower_node_modal_pointer_smoke.gd`: CI 1회, pre-push 1회

## 실제 렌더 및 수동 재현 경로

`tower_ascent_boss_entry_visual_qa.gd`는 대상의 `set_stage()`를 직접 호출하지 않는다. registry 해석 → Stage 1 초기화 → 실제 match-flow route → 기존 stage transition loader를 거쳐 전투 화면이 완전히 올라온 뒤 캡처한다. 따라서 정지 원화나 테스트 전용 보스 주입이 아니라 실제 소비자 경로의 증거다.

`run_tower_mode.ps1`에는 기존 기본 동작을 보존하면서 `-ReplayBossSlot`, `-GodotExe`, `-ProjectPath` 옵션을 추가했다. `-ReplayBossSlot`은 동일한 실제 로더 QA를 호출하며 종료 시 환경을 복원한다.

실제 Windows Vulkan/Forward Mobile/RTX 5070 캡처:

1. Arachne 경로
   - slot: `floor_02_arachne`
   - resolved boss: `cheongringwi`
   - stage: `2`
   - variant: `arachne`
   - transition frames: `1399`
   - 캡처: `godot/.godot/codex_captures/tower_boss_routing/floor_02_arachne_battle_entry.png`
   - SHA-256: `08D338D60AA231637EE097ED289CEF7E701DA58EF225C420C99FA7F199266F2E`
   - terminal: `Tower-ascent boss-entry Vulkan visual QA passed: floor_02_arachne`

2. Alice 경로
   - slot: `floor_03_alice`
   - resolved boss: `yeonmyo`
   - stage: `3`
   - variant: `alice`
   - transition frames: 직접 wrapper `1302`, `run_tower_mode.ps1` replay `1318`
   - 캡처: `godot/.godot/codex_captures/tower_boss_routing/floor_03_alice_battle_entry.png`
   - SHA-256: `2A8EB069154168FE4646E98AF444B5366F63D867D7AAB27034404169E958594B`
   - terminal: `Tower-ascent boss-entry Vulkan visual QA passed: floor_03_alice`
   - replay terminal: `Tower mode live replay passed: floor_03_alice`

두 캡처를 육안 확인했으며 서로 다른 선택 경로가 서로 다른 실제 보스 전투 화면으로 진입하고, 화면 잘림 없이 전투 UI와 보스가 렌더됨을 확인했다.

원본 checkout에는 현재 대규모 dirty WIP와 실행 중 편집기가 있어, 최종 실제 렌더 검증에는 `D:\main\bosspong_tower_boss_routing_validation_20260818050846\godot` 검증 전용 합성 프로젝트를 사용했다. 원본의 현재 스크립트/필요 에셋을 복사한 뒤 이 작업의 변경 hunk만 덧씌웠고, 원본 `.godot` 캐시에는 importer를 실행하지 않았다. 이 합성 프로젝트는 검증 fixture일 뿐 커밋 대상이 아니다.

## 최종 검증

현재 구현 HEAD `8bcbef1c1` 기준 결과:

- 전체 탑 smoke suite: `PASS=38 FAIL=0 TOTAL=38`
- smoke wrapper terminal: `All Godot smoke tests passed.`
- 변경 GDScript focused warning scan: 10/10 통과
- warning terminal: `Godot warning scan passed with no GDScript warnings.`
- headless load: 정상 종료
- headless terminal: `Godot headless load check passed.`
- PowerShell parser: 통과
- `git diff --check ea5f03c03..HEAD`: 통과
- 변경 파일 감사: 작업 보고서 작성 전 13개, 모두 허용된 Godot/CI 경로
- 변경 Python 파일: 0개
- 실제 Vulkan 캡처: 2개 보스 경로 통과
- `run_tower_mode.ps1` 실제 replay: 통과

## 격리 커밋

1. `ced2e0a15` `fix(tower): route selected boss into battle transition`
2. `ff5eb8e94` `fix(tower): make combat resolution ids node unique`
3. `bd1c61f95` `fix(tower): carry run progress across combat returns`
4. `b229933e2` `fix(tower): retain map seed for the full run`
5. `edd939fe8` `test(tower): seal skipped boss route exclusion`
6. `e6d62d3ce` `fix(tower): project modal pointer into playfield`
7. `347236cb1` `test(tower): align vertical slice with routed combat return`
8. `bad90f2a6` `ci(tower): register boss routing seals`
9. `8bcbef1c1` `test(tower): replay routed bosses through live loader`

보고서 자체는 별도 문서 커밋으로 고정한다. 어떤 커밋도 원격에 push하지 않았다.
