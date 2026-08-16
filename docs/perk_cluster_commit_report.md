# 퍽 클러스터 커밋 작전 보고서

- 최종 기준 지시문: `docs/perk_cluster_commit_goal.md` (`7f4e48753` 3차 개정)
- 3차 재개 시 메인 HEAD: `7f4e4875385cf7245aba8ee2d1ff20a8e00170ba`
- 판정: **BLOCKED — 동일 조건 차분 게이트에서 원본 PASS 50종이 신규 RED로 악화**
- 코드 수정: 없음
- 메인 브랜치 반영 코드 커밋: 없음
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
- 백업 전후 HEAD 및 상태 목록: 동일
- 증거 파일: `_status_initial.csv`, `_status_final.csv`, `_head_initial.txt`,
  `_head_final.txt`, `_sha256_manifest.csv`, `_backup_summary.txt`

## 2. 폐쇄 탐색과 2차 개정 반영

체질 수련 5파일에서 출발해 기존 WIP만 격리 복사했으며, 파스·씰 의존을 따라
모듈 분리, 팔자윷, 융합, 체질 수련을 후보 폐쇄로 구성했다. 2차 개정 뒤에는
공유 개수 씰이 요구하는 청린귀 비전 초식·양의회천도 조건부 폐쇄로 승격했다.

전용 씰은 실제로 존재했다.

- `cheongringwi_vision_chosik_smoke.gd`
- `yangui_hoechun_runtime_smoke.gd`

두 씰은 격리 후보에서 `PASS=2 FAIL=0 TOTAL=2`,
`All Godot smoke tests passed.` 및 exit 0으로 GREEN이었다. 따라서 2차 개정의
조건부 포함 요건은 충족했다. 이 과정에서 제3의 결합 트랙으로 폐쇄를 확장하지
않았고, 새 gameplay 판단·수치·테스트 기대값도 만들지 않았다.

## 3. 후보 커밋과 채택 여부

격리 워크트리 `D:\main\bosspong_perk_cluster_cheongproof2`에는 기존 WIP를 그대로
분리한 다음 두 **검증 후보 커밋 객체**가 남아 있다.

1. `8d6fcc96724de24c3792bf7cc547770c67a1ecfa`
   - `feat(perk): 청린귀 비전 초식과 양의회천 폐쇄 커밋`
   - 69파일, +4,062 / -89
   - 전용 2종 씰, 집중 경고, 헤드리스 로드, `git diff --check` GREEN
2. `2ca275f8ba7ca702101e624f1bf10ef0d182d7fb`
   - `refactor(perk): 체질 수련·팔자윷·융합 폐쇄 통합 커밋`
   - 90파일, +5,085 / -334
   - 공유 파일의 동일 헝크 때문에 세 트랙을 더 잘게 나누면 각 중간 트리가
     성립하지 않아 함께 적재한 후보

두 번째 후보까지의 집중 배터리와 페이즈 C 수용 기준은 GREEN이었지만, §5의
최종 광역 씰 배터리가 RED였다. 지시문은 모든 중간 커밋도 자체로 성립하는
GREEN 트리여야 하므로 이 객체들은 **메인 브랜치에 채택하지 않았다**. 메인
인덱스도 비어 있다. 후보 워크트리에만 남은 LFS 실파일 및 페이즈 C 파일은
검증용이며 후보 커밋에 포함하지 않았다.

## 4. GREEN 증거

### 집중 클러스터 배터리

다음 14종은 최종 격리 후보에서 `PASS=14 FAIL=0 TOTAL=14`,
`All Godot smoke tests passed.` 및 exit 0이었다.

- `bag_expansion_mugong_removal_smoke`
- `revival_mugong_removal_smoke`
- `speedgear_mugong_removal_smoke`
- `posture_correction_mugong_merge_smoke`
- `perk_conversion_values_smoke`
- `perk_conversion_gate_batch4_smoke`
- `physique_training_category_smoke`
- `physique_training_icon_art_smoke`
- `training_mastery_mugong_smoke`
- `dowsing_goggles_port_smoke`
- `perk_choice_per_card_description_smoke`
- `mystic_dice_offer_rotation_smoke`
- `cheongringwi_vision_chosik_smoke`
- `yangui_hoechun_runtime_smoke`

### 페이즈 C 항목 3 수용 기준

페이즈 C 보존 7파일을 exact-path로 추가한 격리 스테이징 트리에서 다음 6종이
`PASS=6 FAIL=0 TOTAL=6`, 종단선 및 exit 0이었다.

- `tower_ascent_training_node_smoke`
- `physique_training_category_smoke`
- `runtime_perk_choice_apply_flow_smoke`
- `tower_ascent_shop_node_smoke`
- `tower_ascent_node_modal_shell_smoke`
- `tower_ascent_vertical_slice_smoke`

또한 전체 `tower_ascent_*_smoke.gd` 23종은 `PASS=23 FAIL=0 TOTAL=23`, 종단선 및
exit 0이었다. 검증 뒤 exact-path 스테이징은 제거했고 index 0개를 확인했다.

### 정적·로드 게이트

- 후보 변경 `.gd` 74개 집중 경고 스캔: GREEN
- 후보 HEAD 헤드리스 로드: GREEN
- 후보 커밋 범위 `git diff --check`: GREEN

## 5. 최종 RED와 중단 근거

지시문 §3의 파일명 패턴을 합집합으로 실행한 첫 격리 후보 배터리는 104종 중
`PASS=79 FAIL=25 TOTAL=104`였다. 일부는 Git LFS 포인터를 이미지·오디오로 읽은
검증 환경 오류였으므로, 격리 워크트리에만 원본 체크아웃의 실파일을 물질화해
환경성과 코드성을 분리했다. 그 뒤에도 `game_audio.gd` 필드 부재와 런타임 접근자
계약 미완성 같은 실제 코드 RED가 남았다.

폐쇄 파일을 더 추측해 싣기 전에 현재 원본 WIP 자체를 같은 패턴으로 재검증했다.
원본에는 격리 후보보다 신규 씰이 더 있어 합집합이 124종이었고 결과는 다음과
같았다.

- `Smoke summary: PASS=113 FAIL=11 TOTAL=124`
- `Godot smoke suite failed: 11 of 124 tests failed`
- 래퍼 exit 1

실패 씰은 다음 11종이다.

1. `mystic_dice_active_item_smoke` — 아이콘 32px 계약 RED
2. `perk_fusion_cold_boot_cinematic_smoke` — ok marker 뒤 81 resources in use
3. `perk_fusion_cold_boot_timeline_smoke` — ok marker 뒤 81 resources in use
4. `perk_fusion_display_consumer_smoke` — TAB 재료 섹션 헤더 계약 RED
5. `perk_fusion_localization_smoke` — es/pt-BR/ru 용어와 one-off 태그 라우팅 RED
6. `perk_fusion_value_hooks_smoke` — Golden Trajectory 가시 골드 피드백 경로 RED
7. `runtime_perk_callback_map_smoke` — callback-map 이관 계약 다수 RED
8. `runtime_perk_character_context_smoke` — 공용 캐릭터 컨텍스트 이관 계약 RED
9. `runtime_perk_general_icon_static_smoke` — 일반 퍽 정적 아이콘 계약 RED
10. `runtime_perk_payload_access_smoke` — 공용 payload 접근자 이관 계약 RED
11. `runtime_perk_runtime_state_access_smoke` — 공용 runtime-state 접근자 이관 계약 다수 RED

이는 격리 복사 실수만의 문제가 아니다. 명명된 모듈 분리·팔자윷·융합을 모두
포함한 현재 원본 WIP 자체가 동일 씰에서 RED이므로, GREEN으로 만들려면 기존 WIP를
그대로 커밋하는 범위를 넘어 코드·자산·씰 내용을 수정해야 한다. 지시문은
`씰 RED면 고치지 말고 중단`을 요구하므로 여기서 작전을 중단한다.

## 6. 경계 판정

- 포함 가능성이 확인된 명명 트랙: 모듈 분리, 팔자윷, 융합, 체질 수련,
  청린귀 비전 초식·양의회천
- 계속 제외한 WIP: 코만도 물자·화기 리팩터,
  `stage_clear_result_reward_plan_builder.gd`의 7점제 혼재분, 무관 HUD·스테이지·수호령 작업
- 제3 폐쇄 확장: 없음
- RED 해소용 즉흥 코드·자산·테스트 수정: 없음

## 7. 잔여 미커밋 WIP

메인 체크아웃의 기존 dirty/untracked WIP는 보존했다. 3차 재개 시 메인 HEAD는
`7f4e48753`이며, 코드 후보는 detached 격리 워크트리에만 있다. 다음 재개 전에
위 11종을 소유 트랙에서 GREEN으로 만든 뒤, 같은 124종 합집합 배터리를 원본
WIP에서 먼저 재실행해야 한다. 그 종단선이 GREEN일 때만 후보 커밋 시리즈를 다시
조립·채택할 수 있다.

## 8. 상태 분류

- fixed:
  - GRT-054 fixture 드리프트 — Claude 별도 수정 트랙 출처, 관련 6종 GREEN
  - 2차 개정의 청린귀·양의회천 전용 씰 존재 및 2/2 GREEN 확인
- deferred:
  - 메인 브랜치용 최종 클러스터 커밋 시리즈
  - 페이즈 C 항목 3 실제 커밋 재개
  - 최종 A·B 전체 회귀 및 커밋 객체별 전수 재검증
- blocked:
  - 3차 개정 동일 조건 차분 게이트: 원본 PASS 113종 중 후보 PASS 보존 63종,
    신규 RED 50종
- unverified:
  - 없음. 실행하지 않은 후속 게이트는 RED 선행조건 때문에 deferred로 분류

완료 선언 조건의 `blocked 0건`을 충족하지 못했으므로 목표를 완료로 처리하지 않는다.

## 9. 3차 개정 동일 조건 차분 게이트

2차 개정의 “광역 전부 GREEN” 요구는 3차 개정에서 철회되었다. 따라서 앞 절의
원본 11 RED 자체는 더 이상 채택 차단 사유가 아니며, 이번 재개에서는 원본과 후보의
차분만 판정했다.

### 고정 기준선과 물질화

- 고정 테스트 목록: 124종
- 후보 테스트 파일 SHA-256: 기준선과 **124 / 124 일치**
- 후보 시작점: `2ca275f8ba7ca702101e624f1bf10ef0d182d7fb`
- 격리 워크트리: `D:\main\bosspong_perk_cluster_diffproof3`
- LFS 포인터 물질화: 430파일, 원본 체크아웃과 SHA-256 불일치 0건
- import 캐시: 위 물질화 파일의 `.import`가 지시하는 원본 캐시만 격리
  프로젝트에 복제했다. 사용자 편집기·게임 프로세스와 메인 `.godot` 캐시는
  수정하지 않았다.
- 전체 실행 로그:
  `D:\codex_tmp\perk_cluster_diff_gate_20260817_073233\candidate3_124_full.log`

### 허용된 폐쇄 누락 보완

다음 보완은 모두 이미 명명된 “모듈 분리 / 신비의 주사위 / 융합” 트랙 안에서
원본 WIP의 함수·파일을 그대로 격리한 것이다. 새 로직·수치·테스트 기대값은
작성하지 않았다.

- 신규 feature-state owner 5파일과 대응 facade 배선:
  Angel Blessing, choice pipeline, display projection, Mystic Dice, unlock pipeline
- 융합 owner의 실제 호출 서명에 필요한
  `perk_fusion_byproduct_catalog.gd`,
  `perk_fusion_outcome_rules.gd`
- 소유자 경계 집중 스모크: 첫 실행 4/5 GREEN, 위 두 융합 의존 보완 뒤
  나머지 1종 GREEN — 누적 **5 / 5 GREEN**

### 차분 결과

- 원본 WIP: `PASS=113 FAIL=11 TOTAL=124`
- 후보: `PASS=64 FAIL=60 TOTAL=124`
- 원본 113 PASS 중 후보에서도 PASS: **63**
- 원본 PASS에서 후보 RED로 악화: **50**
- 원본 11 RED 중 후보에도 남은 RED: 10
- 원본 RED에서 후보 PASS로 개선: 1
  (`runtime_perk_general_icon_static_smoke.gd`)

따라서 “원본 113 PASS 전부 보존 + 신규·악화 RED 0” 조건을 충족하지 못했다.
특히 다음 신규 RED는 명명된 다섯 트랙 밖의 별도 선택 UI/HUD 트랙을 요구한다.

- `runtime_perk_choice_stats_band_render_capture_smoke.gd`
- `runtime_perk_choice_stats_band_smoke.gd`
- `runtime_perk_traditional_choice_ui_smoke.gd`

이들을 후보 폐쇄에 추가하면 지시문 §1의 **3차 폐쇄 확장 금지**를 위반한다.
따라서 더 넓히거나 코드를 고치지 않고 중단했다. detached 후보
`8d6fcc967`·`2ca275f8b`는 메인 브랜치에 **채택하지 않았고**, 메인 index도
비어 있다.

## 10. 기준선 11 RED 부채 등록

등록된 기준선 RED는 이번 차단 원인이 아니며, 아래 소유 트랙의 후속 수리 대상으로
남긴다. 후속 지시문 예고 경로는
`docs/perk_cluster_baseline_debt_repair_goal.md`이며 아직 작성하지 않았다.

| 씰 | 고정 실패 서명 요약 | 소유 트랙 |
|---|---|---|
| `mystic_dice_active_item_smoke` | 아이콘 32px 계약 | 신비의 주사위 액티브 아이템·아이콘 |
| `perk_fusion_cold_boot_cinematic_smoke` | ok 뒤 81 resources in use | 융합 콜드부트 리소스 수명 |
| `perk_fusion_cold_boot_timeline_smoke` | ok 뒤 81 resources in use | 융합 콜드부트 타임라인 수명 |
| `perk_fusion_display_consumer_smoke` | TAB 재료 섹션 헤더 | 융합 표시·TAB 소비자 |
| `perk_fusion_localization_smoke` | es/pt-BR/ru 용어·one-off 태그 | 융합 다국어 |
| `perk_fusion_value_hooks_smoke` | Golden Trajectory 가시 골드 피드백 | 융합 값 훅·골드 피드백 |
| `runtime_perk_callback_map_smoke` | callback-map 이관 계약 | 모듈 분리 |
| `runtime_perk_character_context_smoke` | 캐릭터 컨텍스트 이관 계약 | 모듈 분리 |
| `runtime_perk_general_icon_static_smoke` | 일반 퍽 정적 아이콘 계약 | 모듈 분리·일반 아이콘 |
| `runtime_perk_payload_access_smoke` | payload 접근자 이관 계약 | 모듈 분리 |
| `runtime_perk_runtime_state_access_smoke` | runtime-state 접근자 이관 계약 | 모듈 분리 |

## 11. 3차 재개 최종 상태

- fixed:
  - 5개 feature-state owner의 누락 facade 폐쇄와 융합 서명 의존을 격리 후보에서
    증명
  - 동일 테스트 파일·LFS·import 조건을 재현
- deferred:
  - detached 후보 채택
  - 페이즈 C 항목 3 재개
  - 기준선 11 RED 후속 수리 지시문 작성
- blocked:
  - 차분 게이트 신규 RED 50종
  - 그중 명명 트랙 밖 선택 UI/HUD 트랙을 요구하는 3종
- unverified:
  - 없음. 차분 게이트 이후의 채택·최종 회귀는 선행조건 실패로 실행 대상이
    아니므로 deferred다.

3차 개정 완료 조건의 차분 증명과 신규 blocked 0건을 충족하지 못했다. 후보를
채택하지 않았으며 목표를 완료로 처리하지 않는다.
