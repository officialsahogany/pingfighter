# 탑 승리 보상 픽 구현 보고서

작성일: 2026-08-18
기준 통합 HEAD: `6376b4e6e8f685629b3489a8a1b89dbb5d7bf846`

## 결론

기존 승리 전리품 상자 단계를 탑 전용 4장 보상 픽으로 교체했다. 승리 연출 뒤 보상
픽을 처리하고, 계속하기를 선택하면 경로 조준으로 이어진다. 비전초식 만석 스왑,
무공합일 모달 복귀, 다중 구매, 같은 진입의 고정 카드/고정 가격, F9 디버그 승리 경로,
탑 전용 보물지도 배율까지 프로덕션 소비자와 함께 검증했다.

blocked 0건, unverified 0건이다.

## 구현 범위

### 승리 보상 픽

- 진입 시 한 번만 4장을 굴리고 슬롯과 소진 상태를 캐시한다.
- 1번 슬롯은 조건이 맞으면 비전초식, 그다음 낮은 확률의 절세무공, 나머지는
  무공·수련·무공합일 기본 풀을 사용한다. 동일 카드 중복은 허용하지 않는다.
- 가격은 수련 1, 무공 2, 초식/비전초식 3, 무공합일 3, 절세무공 TEMP 5 무혼이다.
- 구매 뒤 남은 무혼으로 추가 구매할 수 있고, 계속하기는 남은 카드를 버리고 경로
  조준으로 진행한다.
- 효과는 `reward_bundle`이 아니라 트랜잭션 `apply_once` 콜백으로 적용하며 동일
  해소 ID의 중복 적용을 막는다.
- 초식 슬롯 만석인 비전초식 카드는 스왑 후보를 함께 제시한다. 확정 시 구매와 교체를
  원자적으로 처리하고, 취소하면 픽 화면과 재고가 그대로 복원된다.
- 건너뛴 보스 ID와 소진된 비전초식 ID는 `TowerAscentRunState`에 저장해 같은 런의
  다음 승리에서도 유지한다.
- 기존 무공합일 모달을 재사용하고, 완료 또는 취소 후 픽 카드·소진 플래그·가격이
  변하지 않은 채 복귀한다.
- 7개 언어 카피를 추가했다.

### 경제와 노드

- 수련장은 수련 카드 6장, 방문당 구매 최대 2회다.
- 파계승은 무공 3장과 초식 3장, 총 6장을 표시하며 별도 방문 상한이 없다.
- 6장 노드는 기존 4장 픽과 다른 2열 레이아웃을 사용한다.
- 노드 가격도 같은 무혼 기준에 맞췄다. 목록 밖 항목은 기존 비율을 보존해 초식 스왑
  TEMP 4, 초식 제거 TEMP 5, 샘터 강화 TEMP 2로 조정했다.
- 보물지도는 탑의 일반 드롭/필드 스폰 배율에서는 1.0으로 고정하고 보상 픽 전용
  절세무공 확률에만 기존 150% 곡선을 적용한다. 탑 플래그가 꺼진 기존 소비자는
  변하지 않는다.

### 레거시와 4천왕 경계

- 3% 신화 잭팟 및 결과 화면 정산 등 이전 절세무공 보상 lane을 제거했다.
- 액티브 아이템은 보상 픽 카드 풀에서 제외했다.
- 4천왕의 이전 `final_chest`는 제거하고, 그룹 보스 슬롯 뒤 단일
  `reward_pick_hook` 데이터 경계만 남겼다. 실제 4천왕 연전 배선은 이 목표 범위가
  아니므로 별도 연전 배선 작업으로 유지한다.
- 7·8층에는 현재 무혼 생산자가 0개다. 이번 구현의 결함이나 차단 사유는 아니지만,
  보상 픽 경제를 라이브 밸런싱하기 전에 별도 생산자 설계가 필요하다.

## 커밋

- `2e3323f2d feat(tower): replace victory loot with reward picks`
- `7e798fc67 feat(tower): align node prices and six-card shops`
- `f64f9a2ef refactor(tower): retire legacy mythic reward lanes`
- `d9e65c0c4 test(tower): seal reward pick production paths`
- 선행 회귀 수정: `31bffad8d fix(tower): restore real-shell slice activation`

## 검증

집중 스모크 7종을 통합 트리에서 다시 실행했다.

- `treasure_map_perk_port_smoke`
- `tower_reward_pick_smoke`
- `common_mugong_item_rebrand_smoke`
- `mythic_perk_offer_chance_smoke`
- `runtime_perk_overflow_description_smoke`
- `tower_ascent_chest_contract_smoke`
- `item_field_spawn_pool_smoke`

결과는 `PASS=7 FAIL=0 TOTAL=7`이다. `item_field_spawn_pool_smoke`의 ObjectDB
누수 경고는 기존 비옵트인 기준선이며 테스트 실패는 아니다.

추가 게이트:

- 탑 전체 스모크: `PASS=39 FAIL=0 TOTAL=39`
- 변경 GDScript 42개 경고 스캔: 경고 0
- headless load: PASS
- CI와 pre-push 스모크 목록: 각 158개, 차이 0
- `git diff --check`: PASS

Vulkan Forward Mobile / NVIDIA GeForce RTX 5070에서 4장 기본 화면과 비전초식
화면을 실렌더링했다. 카드 겹침이나 잘림은 없었다. 긴 비전초식 제목과 상세 문구는
할당된 카드 폭에서 말줄임되지만 카드 정체와 가격은 식별 가능하다.

- `godot/.godot/codex_captures/tower_reward_pick/four_card_reward_pick.png`
  (`SHA-256 8B77C8D30A9B04B48FD85FA8A05587EDC2B26304B5A0A1E3B806D7B833103DFC`)
- `godot/.godot/codex_captures/tower_reward_pick/vision_reward_pick.png`
  (`SHA-256 685C9B7563F9D84FD24A5218168B783ABA88376AC670F2163A3A9EBAFB6AEC4A`)
- 6장 노드: `godot/.godot/codex_captures/tower_ascent_phase_c/training.png`,
  `godot/.godot/codex_captures/tower_ascent_phase_c/fallen_monk.png`

F9는 별도 지름길 보상을 만들지 않고 동일 승리 보상 픽/경로 흐름을 사용하도록
회귀 테스트에 포함했다. 실제 `run_tower_mode.ps1` 첫 승리 재현과 실물 셸 첫·두 번째
승리 증거는 `docs/tower_slice_activation_regression_report.md`에 기록했다.

## WIP 보존과 통합

격리 worktree `D:\main\bosspong_tower_reward_pick_41667ab59`에서 구현하고 로컬
커밋으로 분리했다. 메인 트리와 겹친 5개 파일은 역패치, fast-forward, 재적용 순서로
통합했으며 stash, checkout, reset, broad add를 사용하지 않았다.

통합 전후 WIP 변경 줄 멀티셋은 각각 267줄이며 차이는 0줄이다. 보존 패치는
`D:\codex_backups\tower_reward_pick_20260818_152540`에 남겨 두었다. 사용자 소유
편집기와 게임은 종료하지 않았다. 원격 push는 수행하지 않았다.
