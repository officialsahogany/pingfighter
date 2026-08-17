# 퍽 클러스터 D안 스냅샷 커밋 작전 보고서

- 최종 지시문: `docs/perk_cluster_commit_goal.md` (`541773c84`, 4차 개정 §1-D)
- 기준 HEAD: `541773c8403688af78ba14164663a2115303d335`
- 결과: **GREEN — 통합 스냅샷 착지 및 완료 조건 충족**
- 코드 내용 수정: 없음. 세 번째 동결에 있던 WIP 바이트만 복사·검증·커밋했다.
- 스냅샷 커밋: `c2cc477a6202028a5b06f1a15b62dbc3b5cb3e2f`
- 푸시: 없음

## 1. 백업 위치·파일 수

최종 채택에 사용한 세 번째 동결은 다음과 같다.

- 백업: `D:\codex_tmp\perk_cluster_backup_20260817_135015`
- 브랜치: `fix/plaza-lingpet-egg-full-roster-test`
- HEAD: `541773c8403688af78ba14164663a2115303d335`
- `git status --porcelain -uall`: 6,130개
  - 실제 파일: 6,112개
  - 삭제 경로: 18개
- 백업 크기: 12,040,002,938 bytes (약 11.213 GiB)
- 상태 SHA-256:
  `01385e73d4237297f325d499c8d9a404141f789ab37f4392d72a99df390942c0`
- 소스 매니페스트 SHA-256:
  `7b2b8df8f5c2140172ed17edd6e8e8b97f98b3ccd40b6c63f11fbccb5b56d7b3`

착지 직전 원본을 다시 전수 검사했다. 6,112개 파일은 크기·SHA-256 불일치
0건, 삭제 18개 재등장 0건, 상태 목록 차이 0건, index 0건이었다. 첫 검사에서
UTF-8 JSONL을 Windows PowerShell 기본 인코딩으로 읽어 한국어 경로 5개를
잘못 판정한 결과는 폐기했고, UTF-8을 명시한
`main_freeze_recheck_pre_adopt_utf8.json`만 채택 증거로 사용했다.

앞선 두 동결은 채택하지 않았다.

- `D:\codex_tmp\perk_cluster_backup_20260817_090013`: Godot import sidecar 드리프트
- `D:\codex_tmp\perk_cluster_backup_20260817_090548`: 사용자 세린 Live2D 작업 드리프트

두 경우 모두 원본 변경을 발견한 즉시 폐기하고 커밋하지 않았다. 사용자가 세린
작업과 에디터 재임포트 종료를 확인한 뒤 세 번째 동결을 새로 시작했다.

## 2. 폐쇄 판별 과정

증거 루트는 `D:\codex_tmp\perk_cluster_d4_20260817_140000`, 기준선 격리 트리는
`D:\main\bosspong_perk_cluster_baseline_d4`, 최종 후보 격리 트리는
`D:\main\bosspong_perk_cluster_snapshot_d4`다. 기존 detached 후보
`8d6fcc967`·`2ca275f8b`는 증거용으로만 보존하고 채택하지 않았다.

1. 체질 수련 5파일에서 시작해 런타임 퍽 모듈 분리, 팔자윷, 융합,
   청린귀 비전 초식·양의회춘의 동결 WIP를 따라갔다.
2. v1 2,555개와 v2 1,381개 탐색 후보는 범위가 넓어 폐기하고, v3에서
   퍽 도메인 중심 786개로 경계를 다시 세웠다.
3. v4~v14는 파스·로드·씰 실패가 직접 가리킨 파일만 추가했다. v15의
   1,009개에서 최초 strict 해시·상태 일치를 증명했다.
4. 집중 배터리, Phase C 수용 배터리, 타워 회귀가 가리킨 실제 오디오·HUD·
   스테이지·결과·캐릭터 의존을 v16~v19에 추가했다.
5. 460개 GDScript 집중 경고 스캔이 가리킨 누락 4파일만 v20~v22에 추가해
   최종 경계를 1,076개로 닫았다.

최종 매니페스트 구성은 에셋 459, 스크립트 359, 테스트 242, 도구 13,
셰이더 3개다. 확장 중 신규 로직·수치·테스트 기대값은 작성하지 않았다.
`perk_conversion_gate_batch4_smoke.gd`의 GRT-054 교정은 Claude 별도 수정
트랙에서 이미 동결된 바이트이며, 이번 작전은 그 출처를 보존해 실었다.

최종 매니페스트:

- JSON: `candidate_manifest_v22.json` — 1,076개,
  SHA-256 `ccbf9ca7680b16bf50e517c2cf7f534f8f02109df8bcd5a251b1c042baa13d89`
- CSV: `candidate_manifest_v22.csv`,
  SHA-256 `2ab61b4e258a5a7f700063c57af49bd4f9a68644b4fe5f1ff7396288241ca031`
- GDScript: 460개
- 최종 후보 상태: 매니페스트 1,076개와 Git 상태 1,076개가 정확히 일치,
  누락·추가·크기·해시 불일치 0건

LFS 실파일과 `.import`가 요구하는 캐시는 동일 조건 검증을 위해 격리 프로젝트에만
물질화했다. 기준선·후보는 동일 테스트 소스와 필요한 import 캐시를 사용했고,
헤드리스 로드에 필요했던 `NeoDunggeunmoPro.ttf` 캐시도 메인 `.godot`에서
읽기 전용으로 격리 후보에 복사했다. 사용자 에디터의 `.godot`에는 쓰지 않았고,
캐시·로그는 매니페스트와 커밋에서 제외했다.

## 3. 커밋 목록

| 커밋 | 트랙·내용 | 파일 수 | 합승 여부·사유 |
|---|---|---:|---|
| `c2cc477a6202028a5b06f1a15b62dbc3b5cb3e2f` | 런타임 퍽 모듈 분리, 팔자윷, 융합, 체질 수련, 청린귀 비전 초식·양의회춘 및 실패가 증명한 실제 의존 | 1,076 | 합승. 네 차례 차분 반증으로 선별 커밋이 원본 PASS를 깨뜨림이 증명돼 §1-D 통합 스냅샷으로 전환 |
| 본 보고서의 후속 문서 커밋 | 작전 증거·부채·경계 기록 | 1 | 코드 스냅샷과 분리 |

스냅샷 커밋의 부모는 기준 HEAD와 정확히 일치한다. 격리 후보에서 exact-path
매니페스트만 스테이징했고, 커밋 변경 경로도 1,076/1,076 일치했다. 메인에는
fast-forward 참조 이동과 `read-tree`로 index만 정렬해 착지시켰으며 워크트리
바이트는 건드리지 않았다. 착지 후 1,076개는 모두 clean이고 동결 해시와
일치했다. index는 비어 있다.

## 4. 씰 배터리·정적 게이트 종단선

최종 v22 후보에서 실행한 결과다.

| 게이트 | 결과 | 종단선·판정 |
|---|---:|---|
| 동일 124종 기준선 | 113 PASS / 11 RED | 등록 기준선. `baseline_124_frozen_retry3.log` |
| 동일 124종 후보 | 113 PASS / 11 RED | PASS 113 전부 보존, 신규·악화 RED 0, 서명 차이 0 |
| 집중 클러스터 | 14/14 PASS | `All Godot smoke tests passed.` + exit 0 |
| Phase C 수용 | 6/6 PASS | `All Godot smoke tests passed.` + exit 0 |
| 타워 회귀 | 23/23 PASS | `All Godot smoke tests passed.` + exit 0 |
| GDScript 집중 경고 | 460/460 | 120+120+120+100 네 청크 모두 `Godot warning scan passed with no GDScript warnings.` + exit 0 |
| 헤드리스 로드 | PASS | `Godot headless load check passed.` + exit 0 |
| `git diff --check` | PASS | 스테이징 전·cached 모두 exit 0 |

초기 기준선의 48 PASS / 76 RED, 첫 물질화 뒤 104 PASS / 20 RED는 import
환경이 덜 닫힌 실행이라 채택하지 않았다. 추가 물질화 뒤 113/11을 두 번
재현했고 최종 retry3만 기준선으로 고정했다. 124종 래퍼 자체는 등록 부채
11종 때문에 exit 1이 정상이며, 채택 판정은
`candidate_v22_differential_proof.json`의 다음 차분으로 했다.

- 기준선/후보 테스트: 각각 124개
- 기준선 PASS 보존: 113/113
- 누락·추가 테스트: 0/0
- 신규·회귀 RED: 0
- 기준선 PASS 손실: 0
- 실패 서명 차이: 0
- 판정: `accepted: true`

## 5. 경계 판정

| 대상 | 판정 | 근거 |
|---|---|---|
| 실제 퍽 런타임·팔자윷·융합·체질 수련·청린귀/양의회춘 | 포함 | 작전의 핵심 몸통 |
| 오디오·HUD·스테이지·결과·코만도 일부 | 포함 | 파스·로드·씰 RED가 직접 가리킨 실제 의존만 포함. 독립 트랙 전체를 자동 확대하지 않음 |
| `stage_clear_result_reward_plan_builder.gd` | 제외 | 7점제 혼재 WIP. 최종 매니페스트 0건이며 Phase A 대조 계약 유지 |
| 세린 Live2D·수호령·기타 캐릭터/아트 WIP | 제외 | 최종 폐쇄와 무관. 사용자 완료 작업도 워크트리에 그대로 보존 |
| 문서 전반 | 스냅샷에서 제외 | 코드·에셋·테스트 커밋과 분리. 본 보고서만 후속 exact-path 커밋 |
| `.godot`, 빌드·검증 캐시, 로그, 백업·격리 산출물 | 제외 | §1-D-3 금지 대상 |
| 기준선 11 RED 수리 | 제외·후속 | 커밋 작전 중 코드 수정 금지. 별도 수리 지시문으로 이관 |

경계가 저장소 전체로 번지지는 않았다. 6,130개 동결 상태 중 의존이 증명된
1,076개만 스냅샷에 포함했다.

## 6. Phase C 항목 3 수용 기준 증명

exact-path로 1,076개를 스테이징한 격리 후보에서 다음 6종을 다시 실행했다.

- `tower_ascent_training_node_smoke`
- `physique_training_category_smoke`
- `runtime_perk_choice_apply_flow_smoke`
- `tower_ascent_shop_node_smoke`
- `tower_ascent_node_modal_shell_smoke`
- `tower_ascent_vertical_slice_smoke`

결과는 `PASS=6 FAIL=0 TOTAL=6`, `All Godot smoke tests passed.` 및 exit 0이다.
같은 스테이징 트리에서 관련 집중 회귀 14종도 `PASS=14 FAIL=0 TOTAL=14`,
동일 종단선 및 exit 0이었다. 따라서 이 작전의 존재 이유인 “Phase C 항목 3의
격리 스테이징 트리 성립”을 충족했다. 항목 3 자체의 실제 커밋은 Phase C
지시문 소관이라 이번 스냅샷에 넣지 않았다.

## 7. 잔여 미커밋 WIP

스냅샷 착지 직후 잔여 상태는 5,054개다.

- 수정: 1,139개
- 미추적: 3,897개
- 삭제: 18개
- index: 0개

이는 세 번째 동결 6,130개에서 스냅샷 1,076개만 제거한 정확한 차집합이다.
주요 다음 후보는 세린 Live2D를 포함한 캐릭터/아트 완성분, 수호령, 코만도
물자·화기, 결과 화면 7점제 등이며, 이번 작전은 이들을 스테이징·정리·삭제하지
않았다. 다음 순서는 Phase C 항목 3 재개와 기준선 11종 부채 수리 트랙이다.

## 8. 기준선 11 RED 부채 등록

등록된 RED는 이번 목표의 blocked로 세지 않는다. 후속 지시문 예고 경로는
`docs/perk_cluster_baseline_debt_repair_goal.md`이며 아직 작성하지 않았다.

| 씰 | 고정 실패 서명 요약 | 소유 트랙 |
|---|---|---|
| `mystic_dice_active_item_smoke` | Mystic Dice 아이콘 32px 계약 | 팔자윷 액티브 아이템·아이콘 |
| `perk_fusion_cold_boot_cinematic_smoke` | 수호령 강화 사운드 3종 누락 경고, ObjectDB leak, 81 resources in use | 융합 콜드부트·오디오 수명 |
| `perk_fusion_cold_boot_timeline_smoke` | ObjectDB leak, 81 resources in use | 융합 콜드부트 타임라인 수명 |
| `perk_fusion_display_consumer_smoke` | 융합 TAB 재료 섹션 헤더 2개 유지 계약 | 융합 표시·TAB 소비자 |
| `perk_fusion_localization_smoke` | es/pt-BR/ru 무공 용어와 one-off 태그 라우팅 | 융합 다국어 |
| `perk_fusion_value_hooks_smoke` | Golden Trajectory의 canonical visible gold feedback | 융합 값 훅·골드 피드백 |
| `runtime_perk_callback_map_smoke` | callback-map 공용 이관 계약 | 런타임 퍽 모듈 분리 |
| `runtime_perk_character_context_smoke` | Optimus no-config·owner fallback 계약 | 런타임 퍽 캐릭터 컨텍스트 |
| `runtime_perk_general_icon_static_smoke` | 일반 퍽 정적 PNG 등록·draw source 계약 | 런타임 퍽 일반 아이콘 |
| `runtime_perk_payload_access_smoke` | 공용 payload 접근자 이관 계약 | 런타임 퍽 모듈 분리 |
| `runtime_perk_runtime_state_access_smoke` | 공용 runtime-state 접근자 이관 계약 | 런타임 퍽 모듈 분리 |

## 9. 최종 상태 분류

- fixed:
  - D안 최종 경계 1,076개를 해시 매니페스트로 고정하고 통합 스냅샷 착지
  - 원본 PASS 113/113 보존, 신규·악화 RED 0, 실패 서명 차이 0
  - Phase C 수용 6/6, 집중 14/14, 타워 23/23, 경고 460/460,
    헤드리스·diff check GREEN
  - 메인 WIP 전수 백업·착지 전 재검증·착지 후 스냅샷 해시 일치
- deferred:
  - Phase C 항목 3 실제 커밋 재개
  - `docs/perk_cluster_baseline_debt_repair_goal.md` 작성 및 11종 수리
  - 각 콘텐츠 트랙의 라이브 QA·아트 잔여(이번 커밋 수용 기준 아님)
- blocked: 없음. 위 11종은 §3에 따라 등록된 기준선 부채다.
- unverified: 없음.

완료 조건 ① 격리 수용 GREEN, ② 차분 증명 통과, ③ 11종 부채 등록,
④ 신규 blocked/unverified 0건, ⑤ 보고서 완성을 모두 충족한다.
