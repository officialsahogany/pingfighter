# 승천탑 페이즈 B 완료 보고서

- 기준 지시문: `docs/tower_ascent_phase_b_goal.md` (`387c06c11`)
- 정본: `docs/tower_ascent_run_map_plan.md` v1.4
- 구현 범위: 페이즈 B §1의 7항목
- 최종 기능 HEAD: `3b528842a`
- 지원 UID HEAD: `929dc2697`
- 푸시: 하지 않음
- 판정: **GREEN — 필수 게이트 blocked 0건 / unverified 0건**

## 1. 커밋 목록

| 항목 | 커밋 | 구현 요약 |
|---|---|---|
| 1 | `c4bef99d8` | 지도 전용 `RandomNumberGenerator`, 생성기 버전, 동일 시드 결정성을 가진 지도 생성기 코어를 실전화하고 고정 4노드 fixture를 교체했다. |
| 2 | `4cfcb8a0a` | 전체 그래프 snapshot 저장·복구, schema/version/storage 검증, 기회의 보석 재도전 시 지도 불변을 연결했다. |
| 3 | `ba0329aa5` | 12층, 층별 선택 행·강제 문지기 행, 9층 표준 루트 전투 예산 분석과 불변식을 생성 결과에 적용했다. |
| 4 | `2604a1dbf` | 12층 보스 풀 33슬롯, 이식 상태, 껍데기·신규 설계 슬롯, 기존 보스 stand-in 매핑을 등록했다. |
| 5 | `638aa57d6` | 우회한 보스 ID를 `tower_ascent_run_state` snapshot에 보존하고 이후 후보·복구 그래프에서 제외했다. |
| 6 | `12fe3050f` | 지도 생성 시 광폭화 마킹을 1회 확정하고, 현재 노드 risk를 페이즈 A 상자 가중치 계약에 연결했다. 실제 광폭화 전투 효과는 넣지 않았다. |
| 7 | `3b528842a` | 렌더러를 생성된 12층 그래프·다음 2후보·선택 간선 기반으로 전환하고 Vulkan 캡처 QA를 갱신했다. |
| 지원 | `929dc2697` | 페이즈 B 신규 GDScript 11개의 고유 `.gd.uid`를 등록했다. |

각 번호는 별도 로컬 커밋이다. `git log --reverse 387c06c11..929dc2697`에서 위 순서를 확인했고 원격에는 푸시하지 않았다.

## 2. 게이트 결과

### 2.1 항목별 기능·부정 레그

| 항목 | 대표 smoke | 주요 단언 | 결과 |
|---|---|---|---|
| 1 | `tower_ascent_map_generator_smoke` | 동일 seed+version 동일 그래프, 차분 seed 차분 그래프, gameplay RNG state·다음 수 불변, flag OFF 무손상 | PASS |
| 2 | `tower_ascent_snapshot_recovery_smoke` | 전체 그래프 왕복 동일, 필수 필드·schema 검증, 잘못된 storage/version/seed 거부, 재도전 지도 불변 | PASS |
| 3 | `tower_ascent_12_floor_map_smoke` | 12층 행 구조, 층 경계 문지기 강제, 다음 행 2택, 9층 표준 루트 전투 수 10~12 | PASS |
| 4 | `tower_ascent_boss_registry_smoke` | 12층 33슬롯, 기존 이름만 사용, 미포팅 4종·껍데기·9/11/12층 범위, 모든 비이식 슬롯 stand-in | PASS |
| 5 | `tower_ascent_boss_avoidance_smoke` | 선택하지 않은 보스만 멱등 우회 기록, snapshot 복구, 이후 후보 제외, 비전투 우회 오염 없음 | PASS |
| 6 | `tower_ascent_enraged_marking_smoke` | 확정 광폭화 + 일반 보스별 정확히 1회 10% roll 증거, snapshot 안정성, 상자 risk 가중치, OFF 무손상 | PASS |
| 7 | `tower_ascent_data_driven_renderer_smoke` | 전체 12층/34노드 소비, 활성 후보 정확히 2개, 생성 label/좌표/선택 간선 사용, 고정 fixture ID 제거 | PASS |

커밋 독립성은 각 커밋 객체에서 `godot/project.godot`, 해당 커밋의 전체 `godot/scripts`, 해당 smoke와 검증 래퍼만 추출한 격리 프로젝트로 다시 증명했다. 항목 1~7이 각각 `PASS=1 FAIL=0 TOTAL=1`이었다. 항목 7은 커밋 전 실제 index tree 격리 워크트리에서도 렌더러·vertical-slice·boss-avoidance `3/3` PASS했다.

각 번호의 커밋 직전에도 해당 기능/부정 smoke, 변경 `.gd` 집중 경고, 헤드리스 로드, scoped `git diff --check`를 통과시킨 뒤 exact-path 또는 exact-hunk만 stage했다. 공유 문서의 동시 WIP는 커밋하지 않았다.

최종 종단선은 페이즈 B 7개 + 페이즈 A/OFF 10개 + 기존 소비자 7개를 한 래퍼에서 실행했다.

```text
Smoke summary: PASS=24 FAIL=0 TOTAL=24
All Godot smoke tests passed.
```

기존 소비자 7개는 `stage_clear_result_reward_plan_builder_smoke`, `stage_clear_reward_resolver_smoke`, `runtime_perk_starpoint_collection_flow_smoke`, `active_item_field_spawn_scheduler_smoke`, `active_item_field_spawn_queue_smoke`, `plaza_shop_stock_smoke`, `plaza_gacha_menu_smoke`다. 일반 전투/결과 흐름은 `tower_ascent_vertical_slice_smoke`와 OFF smoke를 함께 통과했다.

### 2.2 경고·로드·diff·Vulkan

- 변경 GDScript 19개 집중 경고 스캔:

```text
gd_warning_scan: scanning 19 scripts
gd_warning_scan: checked 19/19
gd_warning_scan: done
Godot warning scan passed with no GDScript warnings.
```

- 헤드리스 로드:

```text
[ApplicationQuitCoordinator] graceful headless shutdown complete
Godot headless load check passed.
```

- 커밋 범위 `git diff --check 387c06c11..929dc2697`: PASS.
- 최종 index: 비어 있음.
- 검증 전 기존 Godot 사용자 로그 5개는 `D:\codex_tmp\tower_ascent_phase_b_logs_20260816T235047`에 백업했다.
- Vulkan Forward Mobile, NVIDIA GeForce RTX 5070에서 아래 3장을 새로 캡처했고 직접 육안 검사했다.
  - `.godot/codex_captures/tower_ascent_phase_b/node_modal.png`: 12층 전체 지도 위 검증 모달 가독성·클리핑 정상.
  - `.godot/codex_captures/tower_ascent_phase_b/route_aim.png`: 생성 데이터의 다음 후보 2개만 대형 표적이며 label·점선 궤적·안내문 정상.
  - `.godot/codex_captures/tower_ascent_phase_b/map_transition.png`: 선택한 생성 노드와 해당 간선 위 이동 마커가 일치.

```text
tower_ascent_vertical_slice_visual_qa: ok
Tower-ascent vertical-slice Vulkan visual QA passed.
```

렌더 핫패스는 전체 그래프 model을 매 `_draw`마다 deep-copy하지 않는다. flow owner가 그래프 변경 시 활성 후보와 조준 표적 cache를 갱신하고 renderer는 안정된 그래프 배열과 cache를 읽는다.

### 2.3 전체 스캔 baseline

전체 3,658개 스크립트 경고 스캔은 **범위 밖 baseline RED**다. `res://tests/perk_conversion_shop_stock_smoke.gd:37,38,53,54`가 현재 `plaza_shop_stock.gd::_build_pool(catalog, legendary, registry)`의 세 번째 인자를 전달하지 않아 parse error가 발생했고, 스캔은 2,700~3,150 chunk에서 fail-loud로 중단했다.

- `git diff 387c06c11..929dc2697 --` 두 파일: 변경 0개.
- 두 파일의 현재 작업 트리 상태: clean.
- Phase B 집중 경고 19/19와 관련 plaza 소비자 smoke 2개는 GREEN.

따라서 이 RED는 페이즈 B 필수 게이트가 아니라 perk-conversion 동시 트랙의 선재 정합성 부채로 `deferred` 처리했다. 범위를 넓혀 수정하지 않았다.

## 3. 그래프 직렬화 방식

선택: **전체 그래프 저장** (`map_graph_storage = "full_graph"`).

이유:

1. snapshot은 `map_seed`와 `map_generator_version`만이 아니라 이미 확정된 노드 종류, 보스 슬롯, 광폭화 roll 증거, route lock·skip 상태와 좌표를 그대로 복구해야 한다.
2. seed+결정 재생은 생성기 버전·호출 순서·후속 튜닝 변화에 따라 같은 런이 달라질 위험이 있고, 정본이 재시작 보석에서 지도 재굴림을 금지한다.
3. 전체 그래프 왕복 smoke가 원본과 복구본의 그래프 동등성, 잘못된 version/storage 거부, 보석 재도전 전후 graph·seed 불변을 직접 단언한다.

현재 계약:

- `TowerAscentMapGenerator.GENERATOR_VERSION = "tower_map_v5_enraged_marking"`
- `TowerAscentRunState.SNAPSHOT_SCHEMA_VERSION = 3`
- 지도 RNG는 map generator 내부 전용 인스턴스이며 authoritative gameplay RNG를 전진시키지 않는다.

## 4. 신규 튜닝 표

페이즈 A의 기존 임시 상수 15개는 그대로 유지했다. 페이즈 B가 같은 `tower_ascent_tuning.gd`에 추가한 임시 상수는 아래 7개 항목이다.

| 상수 | 임시값 | 근거·소비자 |
|---|---:|---|
| `TEMP_OPTIONAL_ROWS_PER_FLOOR` | `1` | 각 2~12층에 선택 행 1개를 두는 구조 검증값 |
| `TEMP_STANDARD_EXTRA_COMBAT_ROWS_MIN` | `1` | 9층 표준 루트에서 전투 선택 행 수 하한 |
| `TEMP_STANDARD_EXTRA_COMBAT_ROWS_MAX` | `3` | 9층 표준 루트에서 전투 선택 행 수 상한 |
| `TEMP_STANDARD_COMBAT_BUDGET_MIN` | `10` | 9층까지 문지기 9회 + 추가 전투 최소 1회 |
| `TEMP_STANDARD_COMBAT_BUDGET_MAX` | `12` | 9층까지 문지기 9회 + 추가 전투 최대 3회 |
| `TEMP_NODE_TYPE_WEIGHTS` | `shop 2, training 2, fallen_monk 1, guardian_spring 1, rest 2` | 선택 행 비전투 종류의 임시 가중치. 정본 수치 미확정이라 단일 표에만 존재 |
| `TEMP_BOSS_STANDIN_BY_SLOT` | 아래 §5의 23개 비이식 슬롯 매핑 | 신규 전투 킷 없이 기존 Godot 보스를 대역으로 연결하기 위한 호환 표 |

`NORMAL_BOSS_ENRAGED_CHANCE = 0.10`은 임시 발명값이 아니라 정본 §3.5의 확정 기본 확률이라 별도 canonical 상수로 두었다. 리그별 보정과 실제 전투 강화 수치는 후속 결정 사항이다.

## 5. 보스 슬롯·대역 매핑

| 층 | 등록 슬롯 | 상태 | 실행 대역 |
|---:|---|---|---|
| 1 | `floor_01_dalji`, `floor_01_gaksital`, `floor_01_podo` | ported 3 | 각각 stage 1 `dalji` / `gaksital` / `podo` |
| 2 | `floor_02_cheongringwi` | ported | stage 2 `cheongringwi` |
| 2 | `floor_02_molewang`, `floor_02_arachne` | unported 2 | 둘 다 stage 2 `cheongringwi` |
| 3 | `floor_03_yeonmyo` | ported | stage 3 `yeonmyo` |
| 3 | `floor_03_teddy_bear`, `floor_03_alice` | unported 2 | 둘 다 stage 3 `yeonmyo` |
| 4 | `floor_04_ponk` | ported | stage 4 `ponk` |
| 4 | `floor_04_shell_01`, `floor_04_shell_02` | shell 2 | 둘 다 stage 4 `ponk` |
| 5 | `floor_05_hongryun` | ported | stage 5 `hongryun` |
| 5 | `floor_05_shell_01`, `floor_05_shell_02` | shell 2 | 둘 다 stage 5 `hongryun` |
| 6 | `floor_06_tetriser` | ported | stage 6 `tetriser` |
| 6 | `floor_06_shell_01`, `floor_06_shell_02` | shell 2 | 둘 다 stage 6 `tetriser` |
| 7 | `floor_07_akamu_rigo` | ported | stage 7 `akamu_rigo` |
| 7 | `floor_07_shell_01`, `floor_07_shell_02` | shell 2 | 둘 다 stage 7 `akamu_rigo` |
| 8 | `floor_08_minotaur` | ported | stage 8 `minotaur` |
| 8 | `floor_08_shell_01`, `floor_08_shell_02` | shell 2 | 둘 다 stage 8 `minotaur` |
| 9 | `floor_09_fake_ending` | new-design, locked | stage 8 `minotaur` |
| 10 | `floor_10_shell_01`, `_02`, `_03` | shell 3, route-locked | stage 6 `tetriser` / stage 7 `akamu_rigo` / stage 8 `minotaur` |
| 11 | `floor_11_king_01`, `_02`, `_03`, `_04` | new-design 4, sequence metadata locked | stage 4 `ponk` / stage 5 `hongryun` / stage 6 `tetriser` / stage 7 `akamu_rigo` |
| 12 | `floor_12_true_ending` | new-design, route-locked | stage 8 `minotaur` |

합계는 33슬롯이며, 비이식·shell·new-design 23슬롯 모두 대역이 있다. 미포팅 4종의 정본 명칭(두더지왕, 아라크네, 테디베어, 엘리스) 외 신규 보스명·아트·킷은 발명하지 않았다. shell의 player-facing 이름은 모두 `임시 보스`다. 11층은 4슬롯 연전 메타데이터만 등록했고 실제 연전 encounter는 잠가 두었다.

## 6. 상태 구분

### fixed

- 7개 범위 항목 전부 구현·독립 커밋·집중/부정 smoke 완료.
- 지도 seed 결정성, gameplay RNG 비오염, 전체 그래프 snapshot 복구, 보석 재도전 불변.
- 12층/34노드 생성 구조와 9층 표준 루트 전투 예산 10~12 불변식.
- 33 보스 슬롯, 23 stand-in, 회피 목록 snapshot·필터.
- 생성 시 광폭화 1회 마킹과 상자 risk 연동.
- 생성 그래프 주도 renderer, 2개 활성 후보, 선택 간선 이동, Vulkan 픽셀 증거.
- 렌더 핫패스 그래프 deep-copy 제거, 신규 GDScript UID 11개 등록, 아키텍처·소유권 문서의 탑 헝크 갱신.

### deferred

- 페이즈 C: 실제 상점·수련장·파계승·상자·수호의 샘터·휴식 노드 내용, UI·아트.
- 페이즈 D: 9층/진엔딩 판정, 결산·기록·리그, 10~12층 해제 조건과 실제 진행.
- 미포팅/신규/껍데기 보스의 실제 아트·킷, 11층 4천왕 연전 encounter.
- 광폭화 보스의 실제 전투 강화 효과와 리그별 보정.
- §6 미결 수치와 `TEMP_*`의 제품 튜닝 확정.
- 전역 경고 baseline의 `perk_conversion_shop_stock_smoke.gd` 인자 정합성은 해당 동시 트랙 소유.

### blocked

- 없음.

### unverified

- 없음.

설계 충돌은 발견되지 않았다. 정본 미결을 대신 결정하지 않았고 모든 미정 수치는 단일 튜닝 표 또는 locked metadata로 격리했다.

## 7. `stage_clear_result_reward_plan_builder.gd` 대조

- `git log 387c06c11..929dc2697 -- godot/scripts/core/stage_clear_result_reward_plan_builder.gd`: 결과 없음.
- Phase B는 이 파일을 수정·stage·commit하지 않았다.
- 현재 작업 트리의 이 파일은 ` M`이며 페이즈 A 교정과 동시 진행 7점제 score-rule WIP가 섞인 사용자 소유 변경으로 그대로 보존했다.
- 관련 `stage_clear_result_reward_plan_builder_smoke`와 `stage_clear_reward_resolver_smoke`는 최종 24개 묶음에서 PASS했다.

## 8. 다음 페이즈 인계

- 페이즈 C는 `tower_ascent_flow_owner`가 공개하는 생성 graph/current node/활성 후보/risk context를 소비하고, 지도·회피·광폭화 정책을 UI 쪽에서 재생성하지 않는다.
- 비전투 노드의 실제 모달 트랜잭션은 기존 `node_resolution_id` prepare/apply/commit 경계와 full-graph snapshot 안정 경계를 유지한다.
- 10~12층과 11층 연전은 현재 locked metadata다. 페이즈 D의 정본 조건 없이 해제하지 않는다.
- `TEMP_*` 변경은 `tower_ascent_tuning.gd` 한곳에서만 하고, 보스 대역을 실제 콘텐츠로 교체할 때 slot ID와 snapshot 호환성을 보존한다.
- 전역 warning baseline RED는 Phase C 착수 조건이 아니지만, perk-conversion 소유 트랙에서 별도로 고쳐야 한다.

## 9. 완료 조건 확인

| 조건 | 결과 |
|---|---|
| §1의 7항목 구현 | PASS |
| 번호별 독립 로컬 커밋 | PASS |
| 번호별 커밋 객체 격리 smoke | 7/7 PASS |
| flag OFF·일반 흐름·기존 소비자 회귀 | 17/17 PASS |
| 최종 전체 묶음 | 24/24 PASS |
| 변경 파일 warning scan | 19/19 PASS |
| headless load | PASS |
| Vulkan 캡처·육안 QA | PASS |
| commit-range diff check | PASS |
| 필수 gate blocked/unverified | 0/0 |
| 보고서 완성 | PASS |

페이즈 B 완료 조건을 충족한다.
