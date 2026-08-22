# 탑 노드 모달 UI 전면 개선 진행 보고

## S4 선행 별도 슬라이스 — NPC 노드 미니 점수판 수명

### 판정과 소유 경로

- 구현 기준 본 트리 HEAD: `90d11e7ac2c7acf84d034965c82f0fbd2f3a19c1`.
- 격리 브랜치: `codex/tower-node-modal-scoreboard-90d11e7ac`. 본 트리에 통합하거나
  푸시하지 않았다.
- 새 아트는 **필요 없다**. 이 슬라이스는 기존 미니 점수판의 화면 수명만 고치며
  제품 아트·임시 도형·노드 모달 아트 배선을 추가하지 않는다.
- 숨김 목록은 생산 비전투 노드 다섯 종류 `shop`, `training`, `fallen_monk`,
  `guardian_spring`, `rest`다. 다섯 종류가 공통으로 점유하는 활성 탑
  `NODE_MODAL` 동안만 숨긴다. `common_shell` 호환 fixture도 같은 경계라 누출되지
  않는다. 전투 `COMBAT`, 지도·경로 선택, flow가 없거나 비활성인 비탑 일반
  캠페인에서는 표시한다.
- 근거는 물리차단 NPC 모달이 열린 동안 전투 점수는 의사결정 정보가 아니고 실제로
  모달 제목 위에 겹치는 반면, 지도·경로 선택은 그 모달 수명이 아니며 공용 필러 HUD
  전체를 바꾸라는 요구가 아니기 때문이다. 따라서 "비전투 구간 전부"가 아니라
  "다섯 비전투 노드 모달이 실제로 열린 동안"을 가장 좁은 정본으로 삼았다.
- 실제 호출은 `stage1_pillar_hud_scene_drawer.gd`가 매 HUD draw마다
  `stage1_top_mini_scoreboard_scene_drawer.gd`로 내려오고, 그 드로어가 이미 prewarm된
  `tower_ascent_flow_owner`의 cached instance만 읽는다. 활성 `NODE_MODAL` 판정은
  `scoreboard_renderer.gd`에 presentation visibility로 전달된다.
- 단순 draw skip으로 끝내지 않았다. `scoreboard_top_mini_retained_host.gd`는 이전
  draw command를 보유하므로 부착 호스트와 deferred pending 호스트를 모두
  `visible=false`로 만들고 `_draw`/`render_to`도 차단한다. 즉시 fallback도 같은
  effective visibility 앞에서 반환한다. 기존 stage-transition loading의 external
  visibility와 모달 presentation visibility는 AND로 합성되어 어느 한쪽만 먼저
  풀려도 점수판이 깜빡여 나타나지 않는다.

### 별도 슬라이스 검증

- 개정 `scoreboard_top_mini_retained_host_smoke.gd`가 deferred 부착 전 숨김,
  활성 `NODE_MODAL` retained·즉시 경로 0회, external/modal 이유 합성 양방향,
  `COMBAT` 7|2 복귀, 비탑 flow 없음·비활성 표시를 봉인했다.
- `scoreboard_top_mini_stakes_director_smoke.gd`, `tower_node_modal_pointer_smoke.gd`,
  `tower_ascent_node_modal_shell_smoke.gd`도 GREEN이라 기존 stakes, GRT-022 입력,
  GRT-058 물리차단 모달 개폐가 유지된다.
- Forward Mobile Vulkan, NVIDIA GeForce RTX 5070, 2020×1246에서 동일 수련장
  반증 `node_modal_control_visible`, 생산 `node_modal_hidden`, `combat_restored`,
  `non_tower_visible` 4장과 4프레임 비교 strip을 캡처했다. 반증 프레임에는 제목
  위 `7 | 2`가 있고 생산 모달에는 없으며 전투·비탑 프레임에는 복귀한다. 증거는
  `godot/.godot/codex_captures/tower_node_modal_scoreboard_s4/`다.
- 신규 씰은 없다. 기존 씰 개정이므로 CI와 pre-push 리터럴 목록은 함께
  **201개**를 유지한다.
- 범위 밖 `battle_scene_stage_transition_loading_smoke.gd`는 이 슬라이스가 건드리지
  않은 lingpet affinity battle budget 카운터 두 건에서 RED다. 점수판 로딩
  visibility 합성은 개정 retained 씰의 external-first/presentation-first 양방향으로
  별도 GREEN이며, 이 기준선 결함을 점수판 슬라이스에서 고치지 않았다.
- 설계안 §3.6의 샘터·휴식 및 나머지 표현 어댑터는 이 커밋에 포함하지 않았다.
  미니 점수판 슬라이스 보고 뒤 대기하고, 승인된 다음 슬라이스에서만 시작한다.

## S3 공용 호버와 거래 영수증 착지

### 기준, 아트, 시계 판정

- 구현 기준 본 트리 HEAD: `2141f618f943babd4f07325b12b73fbe8537a9df`.
- 격리 브랜치: `codex/tower-node-modal-s3-2141f618f`. 본 트리에 통합하지 않았다.
- 새 아트 판정은 **불필요 유지**다. 기존 카드 종이·아이콘·노드 배경과 텍스트,
  코드 네이티브 금선·광륜을 재사용했으며 후보 생성이나 임시 아트 배선은 없다.
- 120ms 진입, 90ms 해제, 420ms 성공, 160ms 거부는 **벽시계**
  `Time.get_ticks_msec()`를 정본으로 삼는다. `NODE_MODAL`이 전투 물리를 막아도 표현
  마감은 실제 경과시간대로 진행되어야 하고, 물리 catch-up 횟수와 시각 피드백을
  결합하면 같은 입력도 프레임 상황에 따라 다른 길이로 보이기 때문이다. 테스트만
  명시 시각을 주입한다.
- 호버·영수증에는 난수를 쓰지 않는다. 진동은 벽시계 진행률의 결정적 사인 곡선이라
  gameplay RNG와 독립 표현 RNG 모두 소비 0회다.

### 공용 계약과 노드별 연결

1. `TowerAscentNodeModalState`가 action ID별 호버 보간과 짧은
   `interaction_receipt`를 소유한다. `get_action_rects()`는 호버·press·영수증 전후
   같은 rect를 반환하며, 내용만 안에서 최대 5px 들리거나 press 때 정확히 2px
   내려간다.
2. 거래 성공 영수증은 `tower_ascent_node_action_transaction.gd`가 반환한
   `costs`, `rewards`, `balances_before`, `balances`를 그대로 복사한다. 가격이나
   조정값으로 잔액을 다시 계산하지 않는다. 실패·취소에는 재화 delta가 없다.
3. `draw_tower_node_card()` 하나가 안쪽 금선·그림자, 1.08배 아이콘, 노드 accent
   이름표, 다른 카드 10% dim, 하단 3행 정보, 성공 인장·광륜, 거부 진동을 그린다.
   상점, 수련장, 파계승은 각 생산 행동 빌더의 `payload.presentation`만 추가했다.
4. GRT-021의 호버 하단 예산은 최장 한국어 거부 문구에서 실제 append 3행이며 거부
   행이 남는 것을 단언한다. 신규 문구 8개는 7개 지원 locale block 모두에 있다.
5. GRT-043 무호버 fast path는 per-card 시각 딕셔너리를 만들지 않고 기존 드로어
   호출로 돌아간다. 집중 씰이 수련 실상태 조회 0회, 호버 layout 조립 0회, 신규
   동적 레이어 0회를 단언한다. 호버 중 같은 상세 layout과 수련 투영은 signature
   캐시가 한 번만 만든다.

### S3 단독 검증

- 집중 스모크 8개: `tower_node_modal_feedback_smoke.gd`, 기존 포인터·모달 셸·배경,
  상점·수련장·파계승 생산 씰, 수련 능력치 프리뷰 씰 모두 GREEN.
  종단은 `Smoke summary: PASS=8 FAIL=0 TOTAL=8`,
  `All Godot smoke tests passed.`다.
- GRT-022 반증은 2020×1246 카드 상단 모서리 `+2px`이며 hover/press 전후 rect가
  완전히 같다. GRT-058은 기존 생산 모달 셸과 포인터 씰의 진입·해제 양방향이
  함께 GREEN이다.
- touched GDScript 10개 경고 0건. 헤드리스 로드는
  `[ApplicationQuitCoordinator] graceful headless shutdown complete`와
  `Godot headless load check passed.`로 끝났다.
- 신규 씰은 CI와 pre-push 리터럴 목록에 함께 등재했다. 두 목록 모두 200개에서
  **201개**가 됐다.
- Forward Mobile Vulkan, NVIDIA GeForce RTX 5070, 2020×1246에서 idle, hover
  0/60/120ms, press, 성공 0/210/419ms, 거부 0/40/159ms와 상점·파계승 hover를
  합계 13장으로 캡처했다. hover·성공·거부는 각각 시작·중간·끝 3프레임 스트립도
  저장했다. 증거 경로는
  `godot/.godot/codex_captures/tower_node_modal_feedback_s3/`다.
- 격리 Vulkan 픽셀은 확인했지만 사용자가 통합한 본 트리의 직접 플레이 체감은
  **unverified**다.

## S2 공용 포인터 상태 착지

### 아트 선판정

- 판정: **S2에는 새 아트가 필요 없다.** S2는 공용 모달 상태와 생산 입력 계약만
  바꾸며 드로어, 카드 외형, 배경, 아이콘을 바꾸지 않는다.
- 카드 아래 정보를 채우는 S3도 현재 계약상 기존 아이콘과 텍스트·수치로 구성할 수
  있다. 새 장식 아트가 필요해지는 경우는 S5 시작 전에 다시 후보 승인 게이트를 연다.
- 임시 도형과 임시 장식은 추가하지 않았다.

### 기준과 범위

- 구현 기준 HEAD: `5cf3434980c4e1c9f071b8f35d58b3255ff443e0`
- 격리 브랜치: `codex/tower-node-modal-s2-5cf343498`
- 변경 범위:
  - `tower_ascent_node_modal_state.gd`: 키보드 선택, 호버, 눌림 상태 분리,
    고정 action rect 기반 press/release-inside, action ID 보존 갱신.
  - `tower_ascent_flow_node_progress.gd`: `MouseMotion`, 좌버튼 release-inside,
    터치 release-inside 생산 라우팅.
  - `tower_node_modal_pointer_smoke.gd`: 760×750과 2020×1246 상단 모서리,
    drag 취소, 이중 release 0회, 초점 분리, action ID 보존, GRT-058 역방향 씰.
- 비변경 범위: `tower_ascent_flow_renderer.gd`,
  `runtime_perk_overlay_renderer.gd`, 지도 배선·경로, 픽업, 풍향계, 카드 외형,
  GRT-021의 실제 최장 문구 3행 제한.

### 착지 계약

1. 키보드 선택은 포인터 호버와 분리된다. 마우스를 카드에 올려도 Enter/Space의
   대상은 유지된다.
2. 호버와 눌림은 `get_action_rects()`가 반환한 고정 rect 안에서만 성립한다.
   포인터 상태가 rect의 위치·크기·개수를 바꾸지 않는다.
3. 좌클릭과 터치는 카드 안에서 누르고 같은 카드 안에서 놓을 때만 정확히 한 번
   실행한다. 밖으로 끌어 놓기, 밖에서 누른 뒤 안에서 놓기, 반복 release는 0회다.
4. `set_actions()`는 더 이상 `open()`을 호출하지 않는다. 키보드 선택과 호버를
   action ID로 복원하고 상태 문구와 모달 정체성을 보존하며 진행 중 press만 취소한다.
5. 기존 `selected_index` view-model 키는 키보드 초점의 호환 투영으로 남기고,
   `keyboard_selected_index`, `hovered_index`, `pressed_index`를 추가했다.

### S2 단독 검증

- 집중 스모크:
  - `tower_node_modal_pointer_smoke.gd`: **GREEN**. 카드 상단 모서리로 GRT-022
    화면 좌표 반증, 공용 포인터 상태, 실제 `TowerAscentFlowOwner` 입력 경로,
    GRT-021 실제 최장 문구 3행, GRT-058 capture/pause/loop-stop 및
    resume/safety/물리 차단 해제를 한 종단에서 봉인했다.
  - `tower_noncombat_node_background_contract_smoke.gd`: **GREEN**. 비전투 노드
    배경·공용 배경 계약 비회귀.
  - 종단: `Smoke summary: PASS=2 FAIL=0 TOTAL=2`,
    `All Godot smoke tests passed.`
- touched 경고 스캔: 3개 GDScript, 경고 0건.
- 헤드리스 로드: `[ApplicationQuitCoordinator] graceful headless shutdown complete`,
  `Godot headless load check passed.`
- 목록: 기존 `tower_node_modal_pointer_smoke.gd`가 CI와 pre-push 리터럴 목록에
  이미 함께 등재되어 있어 목록·개수 변경은 없다.
- 렌더 변경이 없으므로 S2에서 새 Vulkan 픽셀 캡처는 만들지 않았다. 사용자 본 트리
  라이브 체감은 **unverified**다.

### 분리한 기준선 RED

기존 `tower_ascent_node_modal_shell_smoke.gd` 전체 실행은 S2 변경 전에 진입하는
route-serve 경로에서 `weather_event_state.gd`에 없는
`clear_presentation_wind()`와 `update_presentation_wind()`를 호출해 `SCRIPT ERROR`가
발생한다. 이는 정확한 `5cf343498` 기준선의 범위 밖 결함이며 S2에서 풍향계 경로를
되돌리거나 보정하지 않았다. 대신 같은 생산 수명주기 소유자와 생산 close 경로를
포인터 집중 씰 안에서 격리해 GRT-058의 양방향 계약을 GREEN으로 재봉인했다.

## 0. S1 당시 게이트 판정

- 판정: **설계 승인 대기**. 이번 단계에서 구현과 아트 생성은 시작하지 않았다.
- 감사 기준 HEAD: `252d6810856016f9287786b79a4f3c7dd13d1bad`
- 감사 기준 브랜치: `fix/plaza-lingpet-egg-full-roster-test`
- 산출물 격리 워크트리: `C:\Users\woduq\.codex\tmp\bosspong_tower_start_card_amend2_0c60`
- 산출물 워크트리 브랜치/HEAD: `codex/tower-training-node-card-ui-40375` / `aceaa5feb9d5f5d436ade509c4bb919bfea8a8df`
- 주의: 위 워크트리는 콜드 생성하지 않고 보고서 보관용으로만 재사용했다. 코드 감사와
  줄 번호는 미커밋 범위 변경이 없는 최신 본 트리 HEAD를 기준으로 했다.
- 본 트리 통합, 커밋, 푸시, 코드·아트·테스트 목록 변경: 없음.

결론부터 말하면 현행은 "모든 행동을 마우스로 클릭할 수 있는 기능형 모달"까지는
왔지만, "마우스를 올려 읽고, 누른 결과를 즉시 이해하는 게임형 UI"에는 도달하지
못했다. 상점·수련장·파계승은 공용 카드 그리드를 쓰지만 포인터 호버가 없고,
수호의 샘터·휴식은 여전히 글자 행이다. 네 핵심 화면의 다음 구현은 공용 카드
드로어를 유지하면서 포인터 상태, 거래 영수증, 노드별 표현 어댑터를 추가하는
방향이 맞다.

## 1. 범위와 생산 경로

플레이어가 도달하는 비전투 노드 종류는 아래 다섯 개다.

- `tower_ascent_map_generator.gd:25-32`: `shop`, `training`, `fallen_monk`,
  `guardian_spring`, `rest`를 비전투 노드 정본으로 선언한다.
- `tower_ascent_flow_node_progress.gd:89-105`: 다섯 종류의 행동 실행을 같은
  `NODE_MODAL` 경계에서 라우팅한다.
- `tower_ascent_flow_node_progress.gd:192-203`: 종류별 행동 빌더를 한 곳에서
  선택한다.
- `common_shell`은 알 수 없는 종류와 소형 fixture를 위한 호환 폴백이며 지도에
  배치되는 여섯 번째 노드가 아니다(`tower_ascent_node_modal_state.gd:35-38`).

화면과 입력의 공통 경로는 이미 단일화되어 있다.

1. `battle_scene_input_controller.gd:180-211`가 활성 탑 흐름을 먼저 잡고,
   `NODE_MODAL`에는 플레이필드 역투영을 하지 않은 화면 좌표를 넘긴다.
2. `tower_ascent_flow_runtime.gd:205-241`가 활성 `NODE_MODAL`의 모든 입력을
   소비한다.
3. `tower_ascent_flow_node_progress.gd:131-161`가 키보드, 좌클릭, 터치를 공용
   모달 상태에 전달한다.
4. `tower_ascent_node_modal_state.gd:102-135`의 같은 레이아웃 결과가 클릭 rect와
   렌더 rect 양쪽에 들어간다.
5. `tower_ascent_flow_renderer.gd:174-213`가 노드 배경을 먼저 그리고,
   `:2432-2534`가 공용 모달과 행동을 그린다.

## 2. S1 전수 감사표

| 노드 | 현행 행동/표현 | 마우스·터치 | 키보드 | 포인터 호버 | 모달 안 아트 | 장소 배경 | 현재 결과 피드백 | 근거 |
|---|---|---|---|---|---|---|---|---|
| 상점 | 3 일반 + 1 귀물 + 캡슐 + 기회의 보석, 3×2 공용 카드 | 카드 전체 좌클릭 즉시 구매, 터치 가능, 업무 종료 클릭 가능 | 위/아래, Enter/Space, Esc | **없음**. 첫 카드가 기본 선택색일 뿐 포인터와 무관 | 실제 액티브 아이콘 4종, 캡슐·보석 벡터 심볼 | 전용 bitmap | 구매 뒤 잔액·매진·하단 상태 문구만 즉시 갱신 | 재고 `tower_ascent_shop_inventory.gd:20-22,48-92`; 카드 payload `tower_ascent_flow_economy_progress.gd:165-267`; 드로어 `runtime_perk_overlay_renderer.gd:648-802` |
| 수련장 | 체질 수련 6장, 3×2 공용 카드 | 카드 전체 좌클릭 즉시 수련, 터치 가능, 반복 구매 가능 | 동일 | **없음**. 일반 선택/보상 픽의 능력치 호버 프리뷰도 이 모달에는 연결되지 않음 | 실제 체질 수련 아이콘 | 전용 bitmap | 현재 단계·무혼·최대/부족 문구만 갱신 | 6장 정본 `tower_ascent_training_offer_builder.gd:16-20,42-55`; 액션 `tower_ascent_flow_economy_progress.gd:430-506`; 프리뷰 호버 경로는 `runtime_perk_overlay_renderer.gd:2928-2985` |
| 파계승 | 초식/무공/제거 후보 합계 6장, 3×2 공용 카드 | 카드 전체 좌클릭 즉시 적용, 터치 가능 | 동일 | **없음** | 실제 퍽·무공 아이콘 | 전용 bitmap | 소비된 선택지가 사라지고 무혼·하단 상태 문구 갱신 | 카드 수 `tower_ascent_fallen_monk_node.gd:25-32,114-174`; 카드 payload `:351-435` |
| 수호의 샘터 | 영혼소환술 또는 강화 1개 + 봉인 수호령당 교체/흡수 2행 | 모든 글자 행 좌클릭 즉시 실행, 터치 가능 | 동일 | **없음** | **없음**. 수호령 초상·봉인·강화 결과를 모달 안에서 보여주지 않음 | 전용 bitmap | 행 목록과 무혼·하단 상태 문구만 갱신 | 행동 구성 `tower_ascent_guardian_spring_node.gd:135-176,255-378`; 카드군 제외 `tower_ascent_node_modal_state.gd:13`; 글자 행 폴백 `tower_ascent_flow_renderer.gd:2527-2534,2663-2706` |
| 휴식 | 기회의 보석 회복 1행 + 업무 종료 | 두 행 좌클릭 즉시 실행, 터치 가능 | 동일 | **없음** | **없음** | 기존 procedural 캠프 | 보석 수·완료/가득 참 문구만 갱신 | 행동 `tower_ascent_rest_node.gd:30-63`; 공용 행 rect `tower_ascent_node_modal_state.gd:130-135` |

### 2.1 마우스 판정

- **클릭 가능 여부: 다섯 노드 모두 GREEN.** 종류별 분기가 입력에 없고, 공용
  `select_at_position()`이 행동 rect를 고른 뒤 즉시 `_confirm_node_modal_action()`을
  호출한다(`tower_ascent_flow_node_progress.gd:149-161`).
- **마우스 우선 사용성: RED.** 입력 핸들러는 `InputEventKey`,
  `InputEventMouseButton`, `InputEventScreenTouch`만 처리한다(`:131-161`).
  `InputEventMouseMotion` 경로와 `_hovered_index`, `_pressed_index` 상태가 없다
  (`tower_ascent_node_modal_state.gd:21-26`).
- 카드의 `selected` 테두리는 존재한다(`runtime_perk_overlay_renderer.gd:679-680`).
  그러나 열 때 `_selected_index = 0`으로 고정되므로(`tower_ascent_node_modal_state.gd:51`)
  포인터가 화면 밖에 있어도 첫 카드가 선택된 것처럼 보인다.
- 좌클릭은 **누르는 순간** 선택과 실행을 같이 한다. 눌렀다가 카드 밖으로 끌어
  취소하는 버튼 계약, press 상태, release-inside 판정이 없다.
- 화면 좌표와 카드 상단 모서리 히트테스트는 현행 씰이 보호한다.
  `tower_node_modal_pointer_smoke.gd:275-317`은 상점·수련장·파계승 6카드와
  푸터를, `:173-194`는 실 뷰포트의 단일 행을 검사한다. 샘터는 같은 행 경로를
  공유하지만 종류별 포인터 레그는 따로 없다.

### 2.2 아트와 장소 정체성 판정

- 4개 bitmap과 휴식 procedural 배경은 이미 서로 다른 정체성을 가진다
  (`tower_noncombat_node_background_catalog.gd:7-30`). 이번 2020×1246 Vulkan
  캡처에서도 상점·수련장·파계승·샘터의 장소는 명확히 달랐다.
- 그러나 배경 위에 공용 불투명 종이 패널을 다시 채운다
  (`tower_ascent_flow_renderer.gd:203-213,2448-2451`). 실화면에서는 장소 아트가
  주로 좌우 여백에만 남고, 선택이 일어나는 중앙은 다섯 화면 모두 같은 종이판이다.
- 상점·수련장·파계승 카드는 작은 원형 아이콘, 이름표, 최대 3줄 설명, 가격을
  위쪽에 모으고 카드 아래 절반 이상을 비워 둔다
  (`runtime_perk_overlay_renderer.gd:625-774`). 정보량보다 카드가 훨씬 커서
  그림 카드라기보다 긴 빈 문서처럼 읽힌다.
- 샘터와 휴식은 배경 외 모달 내 아트가 0이며, 넓은 빈 종이판 중앙에 글자 행만
  놓인다. 사용자 표현인 "단순 버튼 상하 이동 UI"가 정확히 남아 있는 두 화면이다.

### 2.3 선택·구매·재화 피드백 판정

- 거래 정본은 이미 결과에 `costs`, `rewards`, 최종 `balances`를 반환한다
  (`tower_ascent_node_action_transaction.gd:37-56`). 애니메이션용으로 값을 다시
  계산할 필요는 없다.
- 각 종류는 성공 뒤 행동과 잔액을 다시 만들고 하단 상태 문구를 바꾼다. 예를 들어
  상점은 `tower_ascent_flow_economy_progress.gd:425-428`, 수련은 `:689-692`,
  샘터·휴식은 `tower_ascent_flow_node_progress.gd:275-304`를 사용한다.
- 현재 `set_actions()`가 내부에서 `open()`을 다시 호출해 선택 인덱스와 준비
  상태를 초기화한다(`tower_ascent_node_modal_state.gd:51-54,64-65`). 호출자가
  최종 상태 문구를 다시 쓰므로 텍스트는 남지만, 어느 카드가 방금 실행됐는지
  유지할 상태가 없다.
- 성공 연출, 눌림, 카드 획득/매진 스탬프의 전환, 재화 `이전 → 이후`, 증감 숫자,
  실패 흔들림, 결과 초점이 없다. 구매는 되었지만 플레이어가 읽는 증거는 멀리
  떨어진 잔액 숫자와 화면 맨 아래 한 줄뿐이다.

### 2.4 구조상 추가 결함

- 샘터의 행동 수는 활성 수호령 강화 1개에 봉인 수호령마다 교체·흡수 2개가
  늘어난다(`tower_ascent_guardian_spring_node.gd:159-176`). 봉인 목록 저장에는
  화면용 상한이 없다(`:74-109,629-643`).
- 글자 행 레이아웃은 행동 수만큼 43px 간격으로 계속 rect를 만든다
  (`tower_ascent_node_modal_state.gd:130-135`). 스크롤·페이지·클리핑이 없으므로
  봉인 수호령이 늘면 하단 상태/모달 밖으로 넘칠 수 있다.
- 카드 설명의 3행 제한과 실제 append 행 수 씰은 현행 GREEN이다
  (`runtime_perk_overlay_renderer.gd:625-645`,
  `tower_node_modal_pointer_smoke.gd:320-339`). 개편하면서 설명 영역을 줄이면
  이 안전망을 실제 최장 문구로 다시 봉인해야 한다.

## 3. 설계안: 공용 노드 작업대 v2

### 3.1 한 문장 방향

**기존 장소 배경을 더 많이 드러내고, 모든 행동을 같은 카드 드로어로 표현하며,
고정된 카드 rect 안에서 호버 → 눌림 → 결과 영수증을 읽게 한다.**

상점 전용, 수련장 전용 식의 병렬 드로어는 만들지 않는다. 네 핵심 화면
(상점·수련장·파계승·수호의 샘터)은 `draw_tower_node_card()`를 계속 공유하고,
휴식도 같은 드로어의 `hero` 표현 모드를 사용한다.

### 3.2 공용 상태와 입력 계약

`TowerAscentNodeModalState`가 다음 표현 상태를 단일 소유한다.

- `keyboard_selected_index`: 위/아래/좌/우와 Enter/Space를 위한 초점.
- `hovered_index`: `InputEventMouseMotion`에서만 갱신, 카드 밖이면 `-1`.
- `pressed_index`: 좌버튼 press에서 무장하고 같은 rect 안 release에서만 1회 실행.
- `visible_page`: 샘터의 6장 초과 행동을 위한 페이지. 마우스 휠·좌우 버튼·키보드
  PageUp/PageDown을 같은 상태에 연결한다.
- `interaction_receipt`: 실행한 action ID, 성공/거부, 비용·보상, 이전/최종 잔액,
  시작 시각. 게임 상태를 소유하지 않는 짧은 표현 데이터다.

시각 우선순위는 `pressed > hovered > keyboard focus > idle`로 고정한다. 마우스가
움직였다고 키보드 초점을 파괴하지 않으며, 터치는 hover 없이 press/release 계약만
사용한다. 업무 종료도 같은 hover·press·release를 적용한다.

`set_actions()`는 `open()`을 재호출하지 않고 행동만 교체하도록 분리한다. 거래 뒤
같은 action ID를 찾아 초점과 영수증을 유지하고, 사라진 재고는 마지막 rect 위에
성공 스탬프를 잠깐 남긴 뒤 다음 상태로 정착시킨다.

### 3.3 GRT-022를 지키는 레이아웃

- `build_screen_layout()`이 모달, 재화줄, 카드, 푸터, 페이지 버튼의 **유일한 rect
  정본**을 반환한다. 그리기와 `select_at_position()`은 같은 결과만 소비한다.
- 호버 때 카드 바깥 rect 자체를 옮기거나 키우지 않는다. 고정 rect 안에서 그림과
  이름표를 4~6px 들어 올리고, 안쪽 광륜·그림자·테두리로 떠오르는 느낌을 만든다.
  따라서 그린 카드 외곽과 클릭 외곽이 갈라지지 않는다.
- 760×750 기준 `MODAL_RECT` 밖으로 카드나 툴팁을 내보내지 않는다. 2020×1246
  화면에서도 현행 content scale/offset을 따라 플레이필드 중앙 안에 머문다.
- 반증은 각 종류·페이지의 카드 상단 모서리 `+2px`에서 하고, 기존 중심점 검사는
  승인 근거로 쓰지 않는다.

### 3.4 카드 호버 연출

호버 진입 120ms, 해제 90ms를 기본안으로 한다.

- 고정 외곽 안쪽의 금선 밝기와 그림자를 올린다.
- 아이콘/초상을 약 8% 확대하고 이름표를 노드 accent 색으로 바꾼다.
- 나머지 카드는 8~12%만 낮춰 현재 목표를 읽게 하되 비활성 카드처럼 만들지 않는다.
- 호버 카드의 남는 하단 공간에 `현재 → 결과`, 작동 대상, 비용, 거부 사유를
  펼친다. 긴 설명을 새 창으로 띄우지 않고 카드 내부 정보 밀도를 높인다.
- 수련 능력치 투영과 같은 비싼 조회는 hover 카드가 있을 때만 실행한다. 무호버
  프레임은 조회 0회·신규 동적 레이어 0회로 봉인한다(GRT-043).

### 3.5 클릭과 거래 영수증

- press: 카드 내용이 안쪽으로 2px 눌리고 테두리가 짧게 수축한다.
- release-inside 성공: 권위 상태는 즉시 커밋하고, 420ms 동안 해당 카드에 완료
  인장·획득 광륜·작은 결과 문구를 덧그린다.
- release-outside: 취소하고 어떤 거래도 만들지 않는다.
- 비활성 카드: 160ms 짧은 좌우 진동과 카드 안 거부 사유 강조만 실행한다.
- 반복 수련처럼 카드가 남는 경우에는 단계 숫자와 설명을 새 실상태로 바꾸되,
  영수증이 같은 카드 위에 남아 방금 오른 단계를 보여 준다.

재화줄은 항상 현재 잔액을 보이고, 거래 직후에는 결과 딕셔너리의 실값으로
`무혼 8 → 6`, `-2` 또는 `금화 120 → 60`, `-60`을 짧게 보여 준다. 실패·취소는
증감 0이며 숫자 애니메이션을 시작하지 않는다. 재화 출처는 계속 탑 런 상태 하나다.

### 3.6 노드별 표현 어댑터

모든 어댑터는 행동의 `payload.presentation` 같은 데이터만 만들고, 최종 그림은
공용 `draw_tower_node_card()`가 담당한다. 렌더러 안에 노드별 거래 규칙을 넣지 않는다.

#### 상점

- 아이템 아이콘을 현재보다 크게 보여 주고 일반/귀물/캡슐/보석 배지를 분리한다.
- 호버하면 효과 설명과 가격, 보유 불가 사유를 카드 아래 공간에 펼친다.
- 성공하면 `구매 완료` 인장과 실제 금화 감소를 같은 카드·재화줄에서 연결한다.
- 매진은 검은 막 하나가 아니라 아이콘은 남기고 인장과 낮아진 채도로 기억시킨다.

#### 수련장

- 현재 단계, 다음 단계, 한 번 적용 뒤 변하는 핵심 수치를 카드 안에 함께 둔다.
- 계산은 기존 `RuntimePerkTrainingStatPreview`의 실제 적용 투영 경로를 재사용한다.
  10행 전체 능력치 띠를 억지로 붙이지 않고, 호버 카드의 관련 행 한 개만 소형
  `현재 → 예상` 게이지로 그린다.
- 수납술·조식심법처럼 기존 연속 게이지 대상이 아닌 선택지는 슬롯/쿨타임 수치
  문구를 표시하되 별도 가짜 수식을 만들지 않는다.

#### 파계승

- 카드 상단에 `습득`, `교환`, `제거`, `무공` 작업 배지를 붙인다.
- 교환은 기존 초식과 새 초식을 좌우 비교하고, 제거는 사라질 슬롯을 명시한다.
- 비용과 결과를 같은 카드에서 읽게 하여 이름만 다른 여섯 문서를 벗어난다.

#### 수호의 샘터

- 현재 글자 행을 수호령 초상 카드로 바꾼다. 영혼소환술, 활성 수호령 강화,
  봉인 수호령 교체·흡수 모두 같은 공용 카드 드로어를 쓴다.
- 카드에는 수호령 초상, 활성/봉인 표식, 작업 배지, 예상 결과, 비용을 넣는다.
- 행동이 6장을 넘으면 3×2 페이지로 나누고 페이지 버튼·마우스 휠·키보드 이동을
  모두 지원한다. `업무 종료`는 페이지와 무관하게 고정한다.

#### 휴식

- 단일 회복 행동을 작은 글자 행 대신 중앙 hero 카드로 표현한다.
- 기존 기회의 보석 심볼과 procedural 캠프를 사용해 `현재 보석 → 회복 뒤 보석`을
  보여 준다. 이미 사용/가득 참이면 같은 카드가 완료 상태로 바뀐다.

### 3.7 노드 정체성과 아트 경계

- 기존 4 bitmap과 휴식 procedural 배경을 그대로 정본으로 쓴다. 중앙 종이판은
  헤더·카드·푸터가 분리된 반투명 작업대로 바꿔 배경의 중심 특징이 보이게 한다.
- 공용 geometry는 같게 유지하되 accent만 상점 청동, 수련장 적갈, 파계승 먹회색,
  샘터 비취, 휴식 남청으로 매핑한다. 색상 매핑도 한 theme catalog가 소유한다.
- 첫 구현은 기존 아이템/퍽/체질/수호령 아트와 배경만 재사용할 수 있다. 따라서
  S1에서는 새 이미지를 생성하지 않았다.
- 별도 장식 프레임 아트가 필요하다고 승인되면
  `.claude/skills/ui-hud-generation/SKILL.md` 절차로 후보만 먼저 제시하고 다시
  승인을 받는다. 후보 승인 전 런타임 배선은 하지 않는다.

## 4. 승인 뒤 구현 슬라이스

각 슬라이스는 헝크가 섞이지 않는 단독 커밋 1개와 자체 GREEN을 전제로 한다.

1. **S2 공용 포인터 상태**: hover/press/release, 초점 분리, action ID 보존,
   공용 layout/hit-test 씰. 외형은 최소 변경.
2. **S3 공용 카드 v2**: 고정 rect 내부 호버 연출, 결과 영수증, 재화 이전/이후,
   상점·수련장·파계승 어댑터.
3. **S4 샘터·휴식 카드화**: 수호령 presentation payload, 3×2 페이지, hero 휴식
   카드. 별도 드로어 금지.
4. **S5 노드 theme 작업대**: 기존 배경 노출, accent, 공용 반투명 chrome.
   새 생성 아트가 필요하면 이 슬라이스 전에 별도 후보 승인 게이트.
5. **S6 씰·실화면 증거**: 다섯 노드 idle/hover/pressed/result 캡처와 부정 레그,
   최종 보고. 사용자가 보는 본 트리 라이브 체감은 `unverified`로 남긴다.

## 5. 승인 뒤 필수 검증 계약

### 입력·레이아웃

- 다섯 노드의 모든 활성 행동, 비활성 행동, 업무 종료를 실제 생산 입력 경로로
  좌클릭/터치한다.
- hover 진입·이탈, press 후 밖으로 drag, release-inside 1회 실행, 이중 실행 0을
  단언한다.
- 760×750과 2020×1246에서 카드 상단 모서리, 페이지 버튼, hero 카드가 그려진
  rect와 같은 hit rect를 쓴다.
- 샘터 0/1/2/4개 봉인 수호령 fixture로 빈 상태, 1페이지, 2페이지, 마지막 페이지를
  검증하고 모달 밖 rect가 0개임을 단언한다.

### 텍스트·로케일

- 각 표현 모드의 최장 한국어와 7개 지원 로케일 최장 문구에서 실제 append 행 수,
  말줄임 여부, 카드·푸터 침범 0을 단언한다(GRT-021).
- 새 문구는 한국어 fallback에만 두지 않고 7개 locale block에 모두 등재한다.
- 신규 한국어 문구에 엠대시 `—`가 0개인지 유지한다.

### 성능·수명주기

- 무호버에서 수련 투영, 수호령 상세 조립, 동적 광륜 호출이 각각 0회인지 검사한다.
- hover 중에도 gameplay RNG 호출은 0이며 벽시계/독립 표현 시계만 쓴다.
- 기존 `NODE_MODAL` 진입점을 재사용하고 새 물리차단 모달을 만들지 않는다.
  열기 1회 capture/pause/loop stop, 닫기 1회 resume/safety, reset 누수 0을 실제
  수명주기 경로로 다시 봉인한다(GRT-058).

### 거래·피드백

- 상점 금화, 수련/파계승/샘터 무혼, 휴식 기회의 보석 각각에서
  `before → after`와 거래 결과 `balances`가 일치해야 한다.
- 부족/최대/매진/이미 사용/drag 취소는 권위 상태와 재화를 바꾸지 않고 실패
  피드백만 낸다.
- 반복 수련 3회는 같은 카드에서 단계와 영수증을 세 번 정확히 갱신한다.

### 저장·목록·렌더

- 신규 또는 개정 씰은 CI와 pre-push 두 리터럴 목록에 동시에 등재하고, 현재
  195개 기준에서 실제 개수와 상수를 함께 갱신한다.
- 집중 씰 종단 `All Godot smoke tests passed.`와 `SCRIPT ERROR` 0건,
  touched `-Paths` 경고 0건, 헤드리스 로드, `git diff --check`를 요구한다.
- Forward Mobile Vulkan 2020×1246에서 다섯 노드의 idle·hover·pressed·성공/거부
  상태를 캡처한다. 배경은 유지되고 카드/툴팁/페이지가 플레이필드 밖으로 나가지
  않아야 한다.

## 6. 이번 S1 증거

- 집중 스모크 3개:
  - `tower_node_modal_pointer_smoke.gd`
  - `tower_ascent_node_modal_shell_smoke.gd`
  - `tower_noncombat_node_background_contract_smoke.gd`
- 결과: `Smoke summary: PASS=3 FAIL=0 TOTAL=3`
- 종단: `All Godot smoke tests passed.`
- `SCRIPT ERROR`: 0건. 셸 스모크의 두 경고는 의도한 fail-closed 부정 레그다.
- Vulkan: Godot 4.6.2, Forward Mobile, NVIDIA GeForce RTX 5070, 2020×1246,
  12장 + 실제 수련 생산 경로 1회.
- Vulkan 종단:
  - `tower_ascent_phase_c_node_visual_qa: captures=12`
  - `tower_ascent_phase_c_node_visual_qa: live_runs=1`
  - `tower_ascent_phase_c_node_visual_qa: ok`
- 캡처 경로:
  `D:\main\bosspong\godot\.godot\codex_captures\tower_ascent_phase_c\`
- 최신 본 트리에서 사용자가 직접 다섯 화면을 조작한 체감 판정: **unverified**.

## 7. 승인 요청

권장안은 **기존 아트 우선 공용 작업대 v2**다. 먼저 기존 배경·아이콘·수호령
초상만 재사용해 S2~S4의 마우스 사용성과 결과 피드백을 완성하고, 새 장식 아트는
실제 공용 레이아웃을 본 뒤 필요할 때만 별도 후보 게이트로 연다.

승인 전에는 구현하지 않는다.
