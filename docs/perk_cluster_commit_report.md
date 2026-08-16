# 퍽 클러스터 커밋 작전 보고서

- 기준 지시문: `docs/perk_cluster_commit_goal.md` (`dc5aa40cf`)
- 기준 HEAD: `dc5aa40cfbeed35a5d70d2a0b65888c625c11650`
- 재개 HEAD: `24b00188c338b5cb9e2f7f44dc9b3db4a748514f`
- 판정: **BLOCKED — 최소 폐쇄가 명시적 비범위인 청린귀 트랙을 요구해 중단**
- 푸시: 없음

## 1. 전수 백업

- 위치: `D:\codex_tmp\perk_cluster_backup_20260817_042021`
- `git status --porcelain -uall` 항목: 6,124개
  - 수정: 1,501개
  - 미추적: 4,605개
  - 삭제: 18개
- 실제 복사 파일: 6,106개
- 삭제 경로 기록: 18개
- 백업 용량: 약 11.161 GiB
- SHA-256 검증: 6,106 / 6,106 일치
- 백업 전후 HEAD: 동일
- 백업 전후 상태 목록: 변경 0개 (`stable=True`)
- 증거 파일: `_status_initial.csv`, `_status_final.csv`, `_head_initial.txt`,
  `_head_final.txt`, `_sha256_manifest.csv`, `_backup_summary.txt`

## 2. 최소 폐쇄 탐색

시작점은 지시문이 지정한 체질 수련 신규 5파일과 각 UID, 체질 수련 아이콘
11종의 PNG·import 파일이었다.

격리 워크트리 `D:\main\bosspong_perk_cluster_isolated`에서 기준 HEAD 위에 다음
기존 WIP만 선택적으로 재현했다.

1. 체질 수련 정본 상태·카탈로그·오퍼 플래너·런타임 모듈과 전용 씰
2. 체질 수련이 기대하는 `runtime_perk_*` 분리 모듈과 선택·스냅샷·표시 연결
3. 기존 설계상 함께 은퇴한 신비한 주사위의 무공 오퍼 경로와 액티브 아이템 전환 연결
4. 수련 완성도와 광택 증폭 연결
5. 가시 갑옷·부활·속도기어·건곤낭 은퇴 및 자세 교정 병합에 필요한 기존 WIP
6. 페이즈 C 항목 3 보존분 7파일

`runtime_perk_catalog.gd`, `runtime_perk_overlay_renderer.gd`,
`language_settings_data.gd`처럼 다른 트랙이 섞인 공유 파일은 전체 복사하지 않고,
현재 메인 WIP에 이미 존재하는 관련 헝크만 격리 트리에 옮겼다. 이 과정에서 새
게임플레이 판단이나 수치를 만들지 않았다.

## 3. 커밋 목록

클러스터 커밋은 **0개**다. 최초 씰 RED 해소 후 작전을 재개했으나, 최소 격리
후보가 명시적 커밋 금지 범위를 요구하는 두 번째 차단을 만났으므로 후보 코드를
고치거나 부분 커밋하지 않았다.

보고서 작성 전까지 메인 인덱스는 비어 있었고, 격리 실험이 메인 소스 파일이나
인덱스를 변경하지 않았음을 확인했다.

## 4. 검증 종단선

### GREEN

- 격리 트리:
  - `physique_training_category_smoke: ok`
  - `tower_ascent_training_node_smoke: ok`
  - `Smoke summary: PASS=2 FAIL=0 TOTAL=2`
  - `All Godot smoke tests passed.` / exit 0
- 격리 트리:
  - `posture_correction_mugong_merge_smoke: ok`
  - `Smoke summary: PASS=1 FAIL=0 TOTAL=1`
  - `All Godot smoke tests passed.` / exit 0
- 격리 트리 개별 관련 씰:
  - `training_mastery_mugong_smoke` GREEN
  - `physique_training_icon_art_smoke` GREEN
  - `dowsing_goggles_port_smoke` GREEN
  - `perk_choice_per_card_description_smoke` GREEN
- 메인 최신 WIP 관련 묶음 6종 독립 재검증 GREEN:
  - `bag_expansion_mugong_removal_smoke`
  - `revival_mugong_removal_smoke`
  - `speedgear_mugong_removal_smoke`
  - `posture_correction_mugong_merge_smoke`
  - `perk_conversion_values_smoke`
  - `perk_conversion_gate_batch4_smoke`
  - `Smoke summary: PASS=6 FAIL=0 TOTAL=6`
  - `All Godot smoke tests passed.` / exit 0
- 교정된 `perk_conversion_gate_batch4_smoke`를 복사한 최소 격리 후보:
  - `perk_conversion_gate_batch4_smoke: ok`

### 최초 RED 해소 이력

최초 중단 원인은 `perk_conversion_gate_batch4_smoke`의 다음 실패였다.

- 씰: `res://tests/perk_conversion_gate_batch4_smoke.gd`
- 실패: `Revival consumer fixture should be at fatal boss score`
- 종단선: `Smoke summary: PASS=5 FAIL=1 TOTAL=6`
- 래퍼 결과: `Godot smoke suite failed: 1 of 6 tests failed` / exit 1

Claude 별도 수정 트랙에서 이를 GRT-054 계열의 5점제 fixture 리터럴 잔재로
진단했고, `MatchScoreState.WIN_GOAL - 1` 및 `MatchScoreState.WIN_GOAL` 파생으로
교정했다. 이 작전은 해당 교정을 만들지 않았으며, 재개 시 교정된 기존 WIP를
그대로 복사했다. 위 6종 독립 재검증으로 첫 차단이 해소됐음을 확인했다.

### 현재 RED — 두 번째 중단 원인

은퇴 트랙의 `perk_conversion_values.gd`를 포함한 최소 격리 후보에서 현재
`perk_conversion_values_smoke`를 실행하면 정확 개수 단언 2건이 실패한다.

- 최소 후보 `RuntimePerkCatalog.CONVERTED_PERKS`: 25개
- 메인 전체 WIP 및 현재 씰 기대값: 23개
- 차이: `gravitybelt`, `smartphone`의 별도 상승무공 승격 WIP
- 최소 후보 `CONVERSION_SOURCE_TO_PERK`: 38개
- 메인 전체 WIP 및 현재 씰 기대값: 39개
- 결정적 차이: `yangui_hoechun`

현재 씰 파일을 그대로 커밋해 GREEN으로 만들려면 청린귀 비전 초식 소유의
`yangui_hoechun` 매핑을 가져와야 한다. 이는 지시문 §1의 명시적 커밋 금지 범위다.
반대로 최소 후보 값 25/38에 맞춰 씰 기대값을 새로 작성하는 것은 기존 WIP 커밋만
허용한 이번 작전에서의 코드 내용 수정이다. 두 선택 모두 금지되어 의존 폭발로
판정하고 중단했다.

### 미실행 게이트

최소 격리 후보의 두 번째 관련 씰 RED에서 중단했으므로 다음 최종 게이트는
실행하지 않았다.

- 최종 후보 HEAD 기준 집중 경고 스캔
- 헤드리스 로드
- 전체 후보 `git diff --check`
- 페이즈 A·B·C 회귀 묶음
- 커밋 객체 단위 격리 검증

## 5. 경계 판정

다음 WIP는 최소 폐쇄 밖으로 판정했고 복사·스테이징·커밋하지 않았다.

- 코만도 물자·화기 리팩터
- 청린귀 비전 초식
- `stage_clear_result_reward_plan_builder.gd`의 7점제 혼재분
- 무관 HUD·스테이지·수호령 작업
- 검증용으로 격리 트리에만 복사한 `.godot` 캐시·폰트·무관 아이콘 리소스

## 6. 수용 기준 증명

페이즈 C 항목 3 보존 파일을 포함한 격리 트리에서 핵심 2종은 GREEN이었고, 최초
GRT-054 차단도 해소됐다. 그러나 최종 최소 폐쇄에 필요한 변환 값 회귀 씰이
명시적 비범위 트랙 없이 GREEN이 되지 않으므로 수용 기준은 **미충족**이다.
클러스터 커밋과 페이즈 C 항목 3 커밋을 만들지 않았다.

## 7. 잔여 미커밋 WIP

메인 체크아웃의 기존 대형 WIP는 그대로 보존됐다. 격리 트리에는 최소 폐쇄 후보와
검증 전용 fixture가 남아 있으나, 메인 인덱스나 커밋에는 반영하지 않았다. 다음
재개 전에 `perk_conversion_values_smoke`의 트랙별 개수 소유권을 분리하거나,
청린귀 트랙을 포함하지 않는 은퇴 트랙 전용 기대값을 별도 수정 트랙에서 확정해야
한다. 그 뒤 이 작전은 새 기준 HEAD에서 격리 검증을 재개해야 한다.

## 8. 상태 분류

- fixed: 최초 GRT-054 fixture 드리프트 — Claude 별도 수정 트랙 출처, 메인 6/6 GREEN
- deferred: 집중 경고, 헤드리스 로드, A·B·C 회귀, 커밋 객체 격리 검증
- blocked: `perk_conversion_values_smoke`가 명시적 비범위 `yangui_hoechun` 매핑을 요구
- unverified: 최종 커밋 후보 HEAD 및 페이즈 C 항목 3 커밋 객체

완료 선언 조건의 `blocked/unverified 0건`을 충족하지 못했으므로 목표 완료로 처리하지
않는다.
