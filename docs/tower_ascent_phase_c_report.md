# 승천탑 페이즈 C 진행 보고서

- 기준 지시문: `docs/tower_ascent_phase_c_goal.md` (`878317a16`, 차단 대응 개정 `ab417e63b`)
- 정본: `docs/tower_ascent_run_map_plan.md` v1.4 (`967f526db`)
- 기능 HEAD: `c34351ee4`
- 푸시: 하지 않음
- 판정: **조건부 완료 — 항목 1·2·4~7 구현·검증 완료, 항목 3은 선행 퍽 클러스터 랜딩 대기**
- 최종 완료 선언: 하지 않음

## 1. 커밋 목록

| 항목 | 커밋 | 상태 | 구현 요약 |
|---:|---|---|---|
| 1 | `caa0d404c` | fixed | 전투 중 비전투 노드 공통 모달, 물리 차단, 액션·잔액·업무 종료 UI와 ROUTE_AIM 복귀를 연결했다. |
| 2 | `aafc7ed6b` | fixed | 상점 6칸 재고, 골드 원자 결제, 액티브 지급, 캡슐·기회의 보석 상한, 재고·구매 스냅샷을 연결했다. |
| 3 | 없음 | blocked | 수련장 코드는 작업 트리에 보존했으나, 커밋되지 않은 체질 수련·퍽 모듈화 선행 트랙 없이는 독립 커밋 트리가 성립하지 않는다. |
| 4 | `6bb98f6e9` | fixed | 파계승의 초식 습득·교환·제거를 기존 런타임 퍽 공개 진입점, 방문별 1회 제한, 무혼 트랜잭션에 연결했다. |
| 5 | `ff2668292` | fixed | 수호의 샘터 최초 영혼소환술, 이후 강화·교체·흡수, 봉인 탭, 도감 발견 커밋을 실제 수호령 알 경로에 연결했다. |
| 6 | `b6e287527` | fixed | 휴식 노드당 기회의 보석 1개 무료 복원, 상한 3, 멱등 트랜잭션과 스냅샷 복구를 연결했다. |
| 7 | `c34351ee4` | fixed | 공통 셸과 5종 노드의 실제 Vulkan 6장 캡처 래퍼·계약 스모크를 추가했다. |

각 완료 항목은 별도 로컬 커밋으로 남겼고, 공유 파일은 exact-path 또는 exact-blob 스테이징과 격리 트리 검증을 거쳤다. 항목 7은 격리 커밋 `4e779153d`와 메인 커밋 `c34351ee4`의 트리 `8790eca8e780ab46ae3de7ca3ff80079b71d6429`가 정확히 일치한다.

## 2. 게이트 결과

### 2.1 최종 종단선

- 페이즈 A·B 회귀와 완료된 C 항목을 묶은 타워 스모크: `PASS=22 FAIL=0 TOTAL=22`.
- 필수 종단선: `All Godot smoke tests passed.`
- 페이즈 C 커밋 범위의 GDScript 집중 경고 스캔: `28/28`, 경고 0건.
- 메인 작업 트리 헤드리스 로드: `Godot headless load check passed.`
- `git diff --check 878317a16..c34351ee4`: PASS.
- 항목 7 Vulkan 래퍼: NVIDIA GeForce RTX 5070, Vulkan Forward Mobile, `captures=6`, `ok`, exit 0.

최종 22종 묶음에는 공통 모달·상점·파계승·샘터·휴식·시각 QA 계약과 페이즈 A·B의 run state, snapshot, 지도 결정론, 12층 구조, 보스 회피·광폭화, 상자, 무혼, 해금, 보석, rarity, OFF 경로, 수직 슬라이스 회귀가 포함된다.

### 2.2 항목별 핵심 반증

- 항목 1: 모달 활성 중 전투 정지·물리 차단, 중복 fanout 방지, 모달 종료 전 ROUTE_AIM 진입 금지, 플래그 OFF를 검증했다.
- 항목 2: 잔액 부족·슬롯/보석 상한·매진에서는 트랜잭션 0건, 동일 `node_resolution_id` 재호출 지급 0건, 플래그 OFF 레거시 무손상을 검증했다.
- 항목 4: 습득·교환·제거 각 방문 1회, 무혼 부족, 중복 ID, 기존 퍽/초식 오너 적용과 플래그 OFF를 검증했다.
- 항목 5: 최초 방문 무료 1회, 이후 강화 비용 6, 교체·흡수 무료, 봉인 수호령 표시 전용, 도감 즉시 기록, 중복 ID, 실제 알 런타임 경로를 검증했다. 항목 5 격리 트리 회귀는 `11/11 PASS`였다.
- 항목 6: 노드당 무료 복원 1회, 보석 상한 3, 중복 ID, 스냅샷 왕복, 플래그 OFF를 검증했다. 격리 트리 회귀는 `6/6 PASS`였다.
- 항목 7: 변경 파일 경고 `2/2`, 계약 스모크 `1/1`, 메인·격리 Vulkan 6장과 동일 SHA-256을 확인했다.

### 2.3 선재·외부 RED 분리

- 전체 경고 스캔은 `res://tests/perk_conversion_shop_stock_smoke.gd`의 `_build_pool()` 인자 수 불일치에서 RED다. 페이즈 B 때부터 존재한 퍽 전환 트랙 결함이며, C 변경 경로 28개 집중 스캔은 GREEN이다.
- 현재 메인 작업 트리의 `lingpet_main_egg_overflow_smoke`는 동시 진행 중인 비교 카드 WIP 때문에 RED지만, 항목 5 exact-tree 격리 회귀에서는 같은 테스트를 포함해 `11/11 PASS`했다. 샘터 커밋 결함으로 귀속하지 않는다.
- 항목 7 격리 트리의 전체 헤드리스는 `GIT_LFS_SKIP_SMUDGE=1` 체크아웃의 이미지·오디오 포인터 때문에 RED였다. 같은 커밋 트리를 메인에 반영한 뒤 실제 자산으로 헤드리스 PASS를 확인했다.

### 2.4 항목 3 차단 반증

현재 작업 트리에서는 아래 6종이 `PASS=6 FAIL=0 TOTAL=6`이다.

- `tower_ascent_training_node_smoke`
- `physique_training_category_smoke`
- `runtime_perk_choice_apply_flow_smoke`
- `tower_ascent_shop_node_smoke`
- `tower_ascent_node_modal_shell_smoke`
- `tower_ascent_vertical_slice_smoke`

그러나 격리 커밋 후보에서는 `res://scripts/characters/physique_training_catalog.gd` 부재로 파스 RED가 재현됐다. 신규 체질 수련 5파일과 이를 연결하는 `runtime_perk_state.gd`·`runtime_perk_catalog.gd` 변경은 모듈 분리·팔자윷·융합 등 여러 미커밋 트랙과 혼재한다. 헝크만 떼면 코드 그래프가 성립하지 않으므로 항목 3 변경은 커밋하지 않고 보존했다.

페이즈 C 전용 보존 파일은 다음과 같다.

- 수정: `tower_ascent_flow_owner.gd`, `tower_ascent_node_modal_localization.gd`, `tower_ascent_tuning.gd`
- 신규: `tower_ascent_training_offer_builder.gd`와 UID, `tower_ascent_training_node_smoke.gd`와 UID

## 3. `TEMP_PHASE_C_*` 상수 최종 목록

### 3.1 커밋됨

| 상수 | 값 |
|---|---:|
| `TEMP_PHASE_C_SHOP_COMMON_ACTIVE_PRICE` | 60 |
| `TEMP_PHASE_C_SHOP_LEGENDARY_ACTIVE_PRICE` | 180 |
| `TEMP_PHASE_C_SHOP_MYTHIC_ACTIVE_PRICE` | 300 |
| `TEMP_PHASE_C_SHOP_CAPSULE_PRICE` | 80 |
| `TEMP_PHASE_C_SHOP_CHANCE_GEM_PRICE` | 150 |
| `TEMP_PHASE_C_MONK_CHOSIK_ACQUIRE_COST` | 8 |
| `TEMP_PHASE_C_MONK_CHOSIK_SWAP_COST` | 10 |
| `TEMP_PHASE_C_MONK_CHOSIK_REMOVE_COST` | 12 |
| `TEMP_PHASE_C_MONK_ACQUIRE_PER_VISIT` | 1 |
| `TEMP_PHASE_C_MONK_SWAP_PER_VISIT` | 1 |
| `TEMP_PHASE_C_MONK_REMOVE_PER_VISIT` | 1 |
| `TEMP_PHASE_C_SPRING_ENHANCE_COST` | 6 |
| `TEMP_PHASE_C_REST_RESTORE_PER_NODE` | 1 |

상자 골드·무혼 지급량은 페이즈 A 오너를 재사용했으며 중복 상수를 만들지 않았다.

### 3.2 항목 3 작업 트리에만 보존됨

| 상수 | 값 |
|---|---:|
| `TEMP_PHASE_C_TRAINING_STAT_COST` | 5 |
| `TEMP_PHASE_C_TRAINING_MUGONG_COST` | 10 |
| `TEMP_PHASE_C_TRAINING_USES_PER_VISIT` | 2 |

지시문 §2와 다른 값은 발명하지 않았다.

## 4. 로컬라이제이션 키와 번역 공백

- 커밋됨: 공통 셸, 상점, 파계승, 수호의 샘터, 휴식의 제목·설명·액션·비용·부족·완료·비활성 사유.
- 항목 3 작업 트리 전용: 수련장 능력치 수련·무공 제련·방문 횟수·부족·완료 문구.
- 한국어 플레이어 문구만 채웠다. 다른 언어 번역은 후속 트랙으로 deferred다.
- 신규 한국어 문구에는 엠대시를 사용하지 않았다.

## 5. Vulkan 캡처와 육안 검수

공통 경로: `godot/.godot/codex_captures/tower_ascent_phase_c/`

| 캡처 | 파일 | 육안 판정 |
|---|---|---|
| 공통 셸 | `common_shell.png` | 프레임·지도 분리·업무 종료 버튼·잔액 영역 정상 |
| 상점 | `shop.png` | 7행이 클리핑 없이 들어오고 가격·매진·비활성 상태 구분 가능 |
| 수련장 | `training.png` | 두 액션과 비용·방문 제한 레이아웃 정상. 항목 3의 런타임 완료 증거는 아님 |
| 파계승 | `fallen_monk.png` | 습득·교환·제거와 무혼 부족 사유 가독성 정상 |
| 수호의 샘터 | `guardian_spring.png` | 영혼소환술·강화·교체·흡수와 봉인 탭 상태 가독성 정상 |
| 휴식 | `rest.png` | 무료 보석 복원·상한/사용 완료 상태 가독성 정상 |

여섯 장 모두 겹침·클리핑·지도 관통이 없고, 비활성 행과 활성 행이 구분된다. 메인 캡처와 항목 7 격리 캡처의 파일별 SHA-256이 모두 일치한다.

## 6. 상태 구분

### fixed

- 항목 1 공통 모달 셸.
- 항목 2 상점 노드.
- 항목 4 파계승 노드.
- 항목 5 수호의 샘터 노드.
- 항목 6 휴식 노드.
- 항목 7 노드별 Vulkan 시각 QA.

### deferred

- 다른 언어 번역.
- `TEMP_PHASE_C_*` 임시값의 최종 밸런스 확정.
- 페이즈 D·E와 정본 §6 미결 결정.
- 전체 경고 스캔의 퍽 전환 파스 오류와 현재 비교 카드 WIP 회귀는 각 소유 트랙.

### blocked

- 항목 3 수련장 노드의 독립 커밋. 선행 체질 수련·퍽 클러스터를 먼저 통합 커밋해야 한다.

### unverified

- 완료 항목에는 없음.
- 항목 3은 원인이 재현된 blocked이며 단순 미검증으로 분류하지 않는다.

## 7. `stage_clear_result_reward_plan_builder.gd` 대조

- `878317a16..c34351ee4` 페이즈 C 커밋은 이 파일을 수정하지 않았다.
- 페이즈 A 교정 `07c5ba932`와 동시 진행 중인 7점제 WIP의 헝크 경계 주의는 그대로 유효하다.
- 항목 3 재개 시에도 이 파일을 건드릴 이유가 없으며, 변경이 생기면 별도 충돌 감사가 필요하다.

## 8. 다음 단계

1. C 조건부 완료 뒤 퍽 클러스터를 별도 통합 프로젝트로 정리한다.
2. 체질 수련·모듈 분리 선행 트랙을 트랙별 씰과 독립 커밋으로 랜딩한다.
3. 보존 중인 항목 3을 다시 exact-path 스테이징하고 격리 트리에서 수련·기존 퍽·OFF 회귀를 재실행한다.
4. 항목 3 독립 커밋과 보고서 최종 갱신이 GREEN일 때만 페이즈 C 최종 완료를 선언한다.

## 9. 완료 조건 확인

| 조건 | 결과 |
|---|---|
| 항목 1·2·4~7 구현 | PASS |
| 항목 1·2·4~7 번호별 독립 로컬 커밋 | PASS |
| 완료 항목 필수 게이트 blocked/unverified | 0 / 0 |
| 항목 3 | BLOCKED, 원인·반증·보존 범위 기록 완료 |
| 보고서 | 조건부 완료 상태까지 완성 |
| 페이즈 C 조건부 완료 선언 | 허용 |
| 페이즈 C 최종 완료 선언 | 금지 |

따라서 개정 지시문 `ab417e63b`의 1단계 조건을 충족했으며, 페이즈 C는 **조건부 완료**다.
