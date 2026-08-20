# 수련탑 파계층 수련 6카드 UI 수행 보고

- 기준 HEAD: `40375e15aeb4515e1f3d60655817fdd58dd106e3`
- 격리 워크트리: `C:\Users\woduq\.codex\tmp\bosspong_tower_start_card_amend2_0c60`
- 작업 브랜치: `codex/tower-training-node-card-ui-40375`
- 상태: **S1~S4 완료**
- 통합: 하지 않음
- 푸시: 하지 않음

## 사용자 정정 계약

- 비천보·유운보·철산공·태허심법·격기심법은 기존 정본대로 `max_count = -1`이다. 유한 상한을 새로 만들지 않았다.
- 무제한 체질 수련은 현재 단계만 `Lv.N`으로 표시한다. 존재하지 않는 최대치나 `/` 표기를 만들지 않았다.
- 유한 정본이 실재하는 수납술 수련은 `현재 / 3`, 무공은 `현재 / max_level`로 표시한다.
- 최대 도달 거부 부정 레그는 유한 무공으로 검증했다. 따라서 “정본 부재로 생략”에는 해당하지 않는다.
- 방문당 2회 제한은 완전히 폐지했다. 수련 카드 구매에 남는 공통 제한은 무혼 잔액뿐이며, 유한 항목은 해당 항목 자체의 정본 최대치도 지킨다.
- 파계승은 수련 노드 규칙을 적용하지 않았다. 기존 방문 무제한·개별 재고 소진 계약과 소스를 보존했다.

## S1 — 정본 및 생산 경로 판정

수련 선택지는 `tower_ascent_training_offer_builder.gd`가 체질 3장과 무공 최대 3장을 합쳐 만든다. 체질 정본은 `physique_training_catalog.gd`, 무공 최대 단계 정본은 실제 선택지의 `max_level`이다.

기존 세로형 보상 카드 렌더러는 이름·등급까지만 카드 안에 배치하고 설명을 카드 바깥에 그리므로 3×2 수련 카드에 직접 사용할 수 없었다. 별도 병렬 렌더러를 만들지 않고 기존 정본 `RuntimePerkOverlayRenderer` 안에 소형 카드 어댑터를 추가하는 것으로 판정했다. 전통 문양 크롬, 아이콘 렌더러, 단계 문자열, 픽셀 폭 줄바꿈은 기존 공용 구현을 그대로 재사용한다.

## S2 — 3×2 카드 UI

- 수련 모달의 처음 6개 행동을 실제 3열×2행 카드로 배치하고, 작업 종료는 별도 하단 푸터로 분리했다.
- 카드마다 실제 선택지 아이콘, 이름, 현재 단계 또는 현재/최대, 설명을 표시한다.
- 카드 전체 사각형이 클릭 영역이며 위쪽 모서리도 같은 선택지를 가리킨다.
- 카드 폭을 넘는 설명은 말줄임표를 사용해 최대 3줄로 제한한다. GRT-021의 행수 판정은 실제 추가된 설명 행을 정확히 센다.
- 모달은 760×750 플레이필드 안에 유지된다.

S2 커밋: `c76b9b9085fe2bac459ff54fbd8b57aac8d4b207`

## S3 — 반복 투자와 거부 경로

- `TEMP_PHASE_C_TRAINING_USES_PER_VISIT`와 모든 방문당 사용 횟수 소비자를 삭제했다.
- 한 카드를 구매한 뒤 제거하거나 `training_choice_used`로 막던 경로를 삭제하고, 구매 직후 현재 상태로 선택지를 다시 투영한다.
- 같은 무공 카드를 한 방문에서 3회 연속 구매할 수 있고, 매번 무혼과 단계가 정확히 갱신된다.
- 자동 거래 ID에 구매 이력 길이를 포함해 동일 카드 반복 클릭이 중복 거래로 오인되지 않게 했다.
- 버튼의 press/release 한 쌍은 정확히 한 번만 구매한다.
- 유한 최대치 도달은 결제 전에 `training_maximum_reached`로 거부하며 무혼을 차감하지 않는다.
- 무혼 부족은 `insufficient_muhon`으로 거부하며 상태와 잔액을 바꾸지 않는다.

S3 커밋: `1c6a308ff`

## S4 — 회귀 씰과 Vulkan 실화면 증거

`tower_ascent_phase_c_node_visual_qa`를 2020×1246 Forward Mobile Vulkan 캡처 9장으로 확장했다.

1. `common_shell.png`
2. `shop.png`
3. `training.png`
4. `training_three_purchases.png`
5. `training_maximum.png`
6. `training_insufficient_muhon.png`
7. `fallen_monk.png`
8. `guardian_spring.png`
9. `rest.png`

`training_three_purchases.png`는 정적 목업이 아니다. 창 모드 Vulkan에서 실제 `TowerAscentFlowOwner` 생산 경로로 수련 노드에 들어가 같은 무공을 3회 구매한 뒤 캡처한다. 실행 중 다음을 단언한다.

- 구매 이력 3건
- 무혼 `30 -> 24`
- 해당 무공 단계 `3 / 5`
- 같은 카드가 계속 활성 상태

별도 캡처에서 유한 최대 단계 `5 / 5` 거부·무혼 무차감과 무혼 0일 때의 구매 거부·상태 무변경을 확인한다. 카드 실제 픽셀 세부가 존재하는지도 캡처 계약에서 검사한다.

자동 회귀 씰은 다음을 포함한다.

- 3×2 카드 좌표와 카드 전체 히트박스
- 정확히 6장일 때 6장 모두 렌더·클릭 가능
- 동일 카드 3회 이상 반복 투자
- 방문당 2회 제한 소비자 부재
- 무제한 5종의 `max_count=-1` 및 `Lv.7` 표기
- 유한 수납술 `2 / 3`, 실제 무공 `max_level` 표기
- 유한 최대치 도달 전 결제 거부·잔액 무변경
- 무혼 부족 거부·잔액 및 상태 무변경
- 파계승 방문 무제한·개별 재고 소진 회귀

새 시각 계약 스모크는 CI와 pre-push의 명시적 목록 양쪽에 같은 항목으로 등록했다.

## 검증 결과

모든 검증은 격리 워크트리에서 수행했다.

- 집중 스모크: `Smoke summary: PASS=5 FAIL=0 TOTAL=5`
- 집중 스모크 종단: `All Godot smoke tests passed.`
- 변경 GDScript 경고 스캔: `Godot warning scan passed with no GDScript warnings.`
- 헤드리스 로드: `Godot headless load check passed.`
- Vulkan QA: `tower_ascent_phase_c_node_visual_qa: captures=9`
- Vulkan 실제 생산 경로: `tower_ascent_phase_c_node_visual_qa: live_runs=1`
- Vulkan 종단: `tower_ascent_phase_c_node_visual_qa: ok`
- 래퍼 종단: `Tower-ascent Phase-C node Vulkan visual QA passed.`
- `git diff --check`: GREEN

캡처를 직접 확인한 결과 수련 기본·3회 투자·최대 도달·무혼 부족과 파계승 화면에서 카드, 아이콘, 단계, 설명, 비활성 사유 및 푸터가 겹치지 않고 플레이필드 안에 들어왔다.

최종 캡처와 격리 실행 로그는 작업 트리 밖에 보관했다.

- 경로: `C:\Users\woduq\.codex\backups\tower_training_node_card_ui_final_20260820_152654`
- 파일: 31개(그중 PNG 9개), 5,391,619바이트
- 상대 경로와 개별 해시를 정렬한 매니페스트의 집계 SHA-256: `54E1A93B5559CD35C6195FBD04BE541209043B6337DED92A24B141EB5C88AEA4`

## 완료 상태

- 완료: S1 정본 판정, S2 카드 UI, S3 반복 투자, S4 자동·실화면 씰
- 차단: 0건
- 미검증: 0건
- 관련 없는 기준선 실패: 0건
- 본 트리 통합: 하지 않음
- 원격 푸시: 하지 않음

이 보고 후 격리 브랜치 상태로 대기한다.
