# 퍽 클러스터 커밋 작전 보고서

- 기준 지시문: `docs/perk_cluster_commit_goal.md` (`dc5aa40cf`)
- 기준 HEAD: `dc5aa40cfbeed35a5d70d2a0b65888c625c11650`
- 판정: **BLOCKED — 관련 씰 RED로 코드·클러스터 커밋 중단**
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

클러스터 커밋은 **0개**다. 관련 씰 RED가 발생했으므로 지시문 §3에 따라 후보
코드를 고치거나 부분 커밋하지 않았다.

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
- 메인 최신 WIP 관련 묶음 중 GREEN 5종:
  - `bag_expansion_mugong_removal_smoke`
  - `revival_mugong_removal_smoke`
  - `speedgear_mugong_removal_smoke`
  - `posture_correction_mugong_merge_smoke`
  - `perk_conversion_values_smoke`

### RED — 중단 원인

메인 최신 WIP에서 관련 씰 6종을 한 래퍼로 실행했으며, 5종 통과 후 다음 1종이
실패했다.

- 씰: `res://tests/perk_conversion_gate_batch4_smoke.gd`
- 실패: `Revival consumer fixture should be at fatal boss score`
- 종단선: `Smoke summary: PASS=5 FAIL=1 TOTAL=6`
- 래퍼 결과: `Godot smoke suite failed: 1 of 6 tests failed` / exit 1

이 실패는 코드 수정이 금지된 커밋 작전에서 발견한 실제 최신 WIP 드리프트다.
지시문에 따라 테스트 기대값을 손보거나 런타임을 고쳐 GREEN으로 만들지 않았다.

### 미실행 게이트

관련 씰 RED에서 즉시 중단했으므로 다음 최종 게이트는 실행하지 않았다.

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

페이즈 C 항목 3 보존 파일을 포함한 격리 트리에서 핵심 2종은 GREEN이었다. 그러나
최종 클러스터 후보에 필요한 관련 회귀 씰이 RED이므로 수용 기준은 **미충족**이다.
클러스터 커밋과 페이즈 C 항목 3 커밋을 만들지 않았다.

## 7. 잔여 미커밋 WIP

메인 체크아웃의 기존 대형 WIP는 그대로 보존됐다. 격리 트리에는 최소 폐쇄 후보와
검증 전용 fixture가 남아 있으나, 메인 인덱스나 커밋에는 반영하지 않았다. 다음
재개 전에 RED 씰의 런타임 소유자와 fixture 상태를 별도 수정 트랙에서 해결한 뒤,
이 작전은 새 기준 HEAD에서 처음부터 격리 검증해야 한다.

## 8. 상태 분류

- fixed: 없음 — 코드 내용 수정 금지 작전
- deferred: 집중 경고, 헤드리스 로드, A·B·C 회귀, 커밋 객체 격리 검증
- blocked: `perk_conversion_gate_batch4_smoke`의 부활 소비자 fatal-score fixture 실패
- unverified: 최종 커밋 후보 HEAD 및 페이즈 C 항목 3 커밋 객체

완료 선언 조건의 `blocked/unverified 0건`을 충족하지 못했으므로 목표 완료로 처리하지
않는다.
