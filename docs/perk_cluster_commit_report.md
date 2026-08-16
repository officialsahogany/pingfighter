# 퍽 클러스터 커밋 작전 보고서

- 최종 기준 지시문: `docs/perk_cluster_commit_goal.md` (`cc2833915` 2차 개정)
- 재개 시 메인 HEAD: `cc2833915a9ad769d013db87848c64c30659bde0`
- 판정: **BLOCKED — 명명된 클러스터의 현재 원본 WIP 씰 배터리 자체가 RED**
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

메인 체크아웃의 기존 dirty/untracked WIP는 보존했다. 메인 HEAD는 재개 시점의
`cc2833915`이며, 코드 후보는 detached 격리 워크트리에만 있다. 다음 재개 전에
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
  - 현재 원본 WIP의 명명 클러스터 씰 배터리 11/124 RED
- unverified:
  - 없음. 실행하지 않은 후속 게이트는 RED 선행조건 때문에 deferred로 분류

완료 선언 조건의 `blocked 0건`을 충족하지 못했으므로 목표를 완료로 처리하지 않는다.
