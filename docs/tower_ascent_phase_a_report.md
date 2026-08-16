# 탑 등정 페이즈 A 완료 보고서

- 지시문: `docs/tower_ascent_phase_a_goal.md` @ `55ff4fa0e`
- 정본: `docs/tower_ascent_run_map_plan.md` v1.4 @ `967f526db`
- 수직 슬라이스 기준점: `7ebf521ad`
- 구현 범위: `4a1c1cc77..07c5ba932` (8개 항목 커밋 + 항목 6 교정 1개)
- 검증 런타임: Godot `4.6.2.stable.official.71f334935`
- 종합 판정: **GREEN** — 필수 게이트 `blocked=0`, `unverified=0`
- 외부 상태: push하지 않았고, 사용자 Godot 편집기·플레이 프로세스를 종료하지 않았다.

## 1. 커밋 목록

| 항목 | 커밋 | 한 줄 |
|---:|---|---|
| 1 | `4a1c1cc77` | `feat(godot): 탑 등정 런 상태 정식화` |
| 2 | `7a70d38d7` | `feat(godot): 탑 노드 보상 트랜잭션 실전화` |
| 3 | `104406535` | `feat(godot): 탑 기회의 보석을 런 상태로 이관` |
| 4 | `f9e55cd59` | `feat(godot): 탑 해금 스토어와 단일 필터 연결` |
| 5 | `16515fafd` | `feat(godot): 수호령 최초 발견 도감을 영속화` |
| 6 | `dc8a8134c` | `feat(godot): 탑 승리 상자를 3종 계약으로 전환` |
| 7 | `fc46b104f` | `feat(godot): 탑 스타포인트를 런 무혼으로 적립` |
| 8 | `3360dd863` | `feat(godot): 액티브 등급과 판당 스폰 예산 정식화` |
| 6 교정 | `07c5ba932` | `fix(godot): 7점제 상자 임계값을 정본에 연결` |

`git rev-list --count 55ff4fa0e..07c5ba932` 결과는 `9`다. §1의 각 항목은
독립 커밋이고, 보고서 역검증에서 잡은 GRT-054 결함은 history rewrite 없이 항목 6
교정 커밋으로 분리했다. 전부 로컬 커밋이고 push는 수행하지 않았다.

## 2. 게이트 결과

### 2.1 항목별 기능·역방향 게이트

| 항목 | 주 기능 증거 | 역방향·소비자 증거 | 판정 |
|---:|---|---|---|
| 1 | `tower_ascent_run_state_smoke` — run id, schema, 경제 필드, snapshot 안정 경계 | `tower_ascent_phase_a_off_path_smoke`, `tower_ascent_vertical_slice_smoke` | PASS |
| 2 | `tower_ascent_node_resolution_transaction_smoke` — prepare/apply/commit, 동일 id 재실행, pending 재개 | run-state 및 vertical-slice 회귀 | PASS |
| 3 | `tower_ascent_chance_gem_defeat_smoke` — 3개 시작, 재도전 차감, 0개 패배 종료 | OFF에서 plaza 보석 경로 유지 | PASS |
| 4 | `tower_ascent_unlock_filter_smoke` — 독립 store, 기본 전부 해금, 단일 필터 | `plaza_shop_stock_smoke`, `plaza_gacha_menu_smoke`, OFF 회귀 | PASS |
| 5 | `guardian_codex_store_smoke` — 최초 공개 즉시 영속 commit, 멱등 id, 런 상태와 분리 | 패배 후 first-seen 유지, 빈/중복 id 부정 레그 | PASS |
| 6 | `tower_ascent_chest_contract_smoke` — 3 kind, 항상 1개, 가중치, 적격·다운시프트 | `stage_clear_reward_resolver_smoke`, OFF의 점수 비례 상자·독립 mythic kind 유지 | PASS |
| 7 | `tower_ascent_muhon_collection_smoke` — 타워 수집량을 `run_state.muhon`에 적립 | `runtime_perk_starpoint_collection_flow_smoke`, OFF 즉시 선택 유지, owner 부재 fail-closed | PASS |
| 8 | `tower_ascent_active_item_rarity_budget_smoke` — 단일 rarity, 4채널 필터, 판당 cap·재굴림 | field scheduler/queue, stage-clear resolver, OFF 무제한 스폰 회귀 | PASS |

최종 종단 배치는 아래 17개를 한 wrapper 호출로 실행했다.

- 페이즈 A 10종: run state, node transaction, chance gem defeat, unlock filter,
  guardian codex, chest contract, muhon collection, rarity/budget, OFF path,
  vertical slice
- 주요 소비자 7종: stage-clear reward-plan builder, stage-clear reward resolver,
  runtime starpoint flow,
  active-item field scheduler, active-item field queue, plaza shop stock,
  plaza gacha menu

래퍼 종단선:

```text
Smoke summary: PASS=17 FAIL=0 TOTAL=17
All Godot smoke tests passed.
```

### 2.2 경고·로드·diff·격리 스테이징

- `55ff4fa0e..07c5ba932`에서 변경된 `.gd` 40개를 `-Paths`로 전수 스캔했다.

```text
gd_warning_scan: scanning 40 scripts
gd_warning_scan: checked 40/40
gd_warning_scan: done
Godot warning scan passed with no GDScript warnings.
```

- 실제 작업 트리 헤드리스 로드:

```text
[ApplicationQuitCoordinator] graceful headless shutdown complete
Godot headless load check passed.
```

- 플레이 중 신정책을 사용했다. 각 wrapper는 활성 게임 PID를 확인하고
  `Verified process priority: BelowNormal`을 출력했으며, 고유 로그 경로와
  `finally` 우선순위 복구 계약을 그대로 탔다.
- 검증 전 사용자 로그 5개를
  `D:\codex_tmp\tower_ascent_phase_a_logs_20260816T220500`에 복사했다.
- `git diff --check 55ff4fa0e..07c5ba932`: PASS.
- 최종 기능 커밋 직전 index tree는
  `6b342e7aaf5ab2021ffeebf9ebd1dc16689617dd`로 다시 일치시켰다.
- 공유 파일의 동시 WIP는 line/hunk 단위로 제외했다. 주요 격리 증거:
  - 항목 6: staged-tree 핵심 smoke `3/3` PASS
  - 항목 7: staged-tree 신규/OFF/run-state smoke `3/3` PASS
  - 항목 8: staged-tree 핵심 smoke `4/4`, staged warning `9/9` PASS
  - 항목 6 GRT-054 교정: staged-tree smoke `3/3`, warning `3/3` PASS.
    `WIN_GOAL` 참조를 리터럴 `5`로 되돌린 counterproof는 두 점수 씰 모두 RED,
    원복 뒤 같은 배치가 다시 GREEN이었다.
- 항목 8의 격리 기준 catalog는 당시 커밋 HEAD의 33개 항목만 포함한다. 작업
  체크아웃의 동시 아이템 WIP(34개)는 stage하지 않았고, 런타임 rarity 정규화는
  현재 작업 체크아웃의 전 항목에도 적용됨을 별도 working-tree smoke로 확인했다.

## 3. 임시 튜닝 표

아래 15개만 정본 미확정 수치다. 모두
`godot/scripts/tower_ascent/tower_ascent_tuning.gd` 한곳에 있다.

| 상수 | 임시값 | 근거 |
|---|---|---|
| `CHEST_NORMAL_BASE_WEIGHT` | `75.0` | 일반상자를 기본 다수로 두는 구조 검증용 |
| `CHEST_SUPREME_ART_BASE_WEIGHT` | `20.0` | 절세무공상자 가중 경로 검증용 |
| `CHEST_SECRET_CHOSIK_BASE_WEIGHT` | `5.0` | 희소 비전초식상자 경로 검증용 |
| `CHEST_FLOOR_NORMAL_WEIGHT_REDUCTION` | `1.5` | 층 상승 시 일반 비중 감소 구조 검증용 |
| `CHEST_FLOOR_SUPREME_WEIGHT_BONUS` | `1.0` | 층 상승 시 상급 비중 증가 구조 검증용 |
| `CHEST_FLOOR_SECRET_WEIGHT_BONUS` | `0.5` | 층 상승 시 비전 비중 증가 구조 검증용 |
| `CHEST_RISK_NORMAL_WEIGHT_REDUCTION` | `8.0` | 위험도가 등급 가중에 반영되는 구조 검증용 |
| `CHEST_RISK_SUPREME_WEIGHT_BONUS` | `5.0` | 위험 상급 보정 구조 검증용 |
| `CHEST_RISK_SECRET_WEIGHT_BONUS` | `3.0` | 위험 비전 보정 구조 검증용 |
| `TEMP_FIELD_ACTIVE_RARITIES` | `["common"]` | 필드 채널 rarity 필터 구조 검증용 |
| `TEMP_NORMAL_CHEST_ACTIVE_RARITIES` | `["common", "rare"]` | 일반상자 채널 필터 구조 검증용 |
| `TEMP_SHOP_REGULAR_ACTIVE_RARITIES` | `["common", "rare"]` | 일반 선반 채널 필터 구조 검증용 |
| `TEMP_SHOP_PREMIUM_ACTIVE_RARITIES` | `["legendary", "mythic"]` | 프리미엄 선반 채널 필터 구조 검증용 |
| `TEMP_REGULAR_SPAWN_BUDGET_MIN` | `0` | 판당 총량 owner와 0-cap 부정 레그 검증용 |
| `TEMP_REGULAR_SPAWN_BUDGET_MAX` | `1` | 재굴림·cap 소진 구조를 최소 범위로 검증용 |

다음 수치는 임시 발명값이 아니라 정본 확정값이다.

- `TOWER_NORMAL_MYTHIC_JACKPOT_CHANCE = 0.03`: §3.6의 현행 3%를 일반상자
  내부 잭팟으로 흡수하는 계약.
- `DEFAULT_CHANCE_GEMS = MAX_CHANCE_GEMS = 3`: §3.8의 런 시작·상한 계약.
- snapshot/store schema version `1`: 신규 저장 포맷의 최초 버전 식별자.

## 4. 감사 목록

### 4.1 `collect_star_points()` 생산자 전수 감사

`godot/scripts/**/*.gd`의 직접 호출을 전수 검색했다. 아래 다섯 생산자와 두
중앙 owner/facade가 전부다.

| 생산자·owner | 위치 | 의미 |
|---|---|---|
| 필드 드랍 수집 정책 | `stages/common/starpoint_collection_reward_policy.gd:18` | 필드 무혼 1개 수집 |
| 신화 무공 지급 helper | `characters/mythic_perk_grant_helper.gd:332` | 미보유 신화 무공이 없을 때 스타포인트 폴백 |
| 결과 상자 resolver | `core/stage_clear_reward_resolver.gd:513` | 결과상자 스타포인트·신화 폴백·예약 비전 오퍼 |
| 광장 아카데미 거래 | `plaza/plaza_academy_transactions.gd:52` | 레거시 수업 후 선택 개방 |
| 전투 scene API | `core/battle_scene_api.gd:59` | `battle_scene_shell.collect_star_point()`의 호환 facade |
| runtime state facade | `characters/runtime_perk_state.gd:932` | 모든 생산자를 중앙 flow로 위임 |
| 의미론 owner | `characters/runtime_perk_starpoint_collection_flow.gd:52` | 타워/레거시 분기, 적립·모달 계약 소유 |

결론:

- 타워 ON의 일반 수집은 중앙 flow에서 `tower_ascent_flow_owner.collect_muhon()`을
  거쳐 `run_state.muhon`에만 적립하며 전투 중 선택 모달을 열지 않는다.
- 예약된 boss-vision offer는 기존 콘텐츠 선택 의미론을 보존하는 명시적 예외다.
- 타워 owner가 없으면 레거시 모달로 새지 않고 fail-closed한다.
- 플래그 OFF는 기존 스타포인트 누적과 즉시 무공 선택 경로를 그대로 유지한다.
- `starpoint` 호환 ID, 리소스, 셰이더, 공용 무혼 비주얼 host는 이름과 경로를
  유지했다. 광범위 rename은 없다.

### 4.2 GRT-054 승리 점수 파생 임계값 소비자 감사

직접 정본 참조(`WIN_GOAL`, `DEUCE_TRIGGER`, `DEUCE_GOAL_BASE`)와 비영점 점수
리터럴 비교를 함께 검색했다. 비영점 점수 리터럴 비교는 0건이며, 다음 소비자가
모두 canonical score owner 또는 snapshot 값을 읽는다.

| 분류 | 소비자 |
|---|---|
| 정본·사다리 | `core/match_score_state.gd`, `core/match_score_event_controller.gd`, `core/round_flow_state.gd` |
| 상자 수량 | `core/stage_clear_result_reward_plan_builder.gd:43-55` |
| 디버그 강제 승리 | `core/battle_pre_intro_stage_input_router.gd:8` |
| 패배·재도전 | `tower_ascent/tower_ascent_defeat_resolver.gd:106`, `core/battle_defeat_flow_resolver.gd`, `core/defeat_settlement_screen.gd`, `core/battle_playfield_overlay_drawer.gd` |
| HUD·렌더 | `hud/scoreboard_state.gd`, `hud/scoreboard_renderer.gd`, `hud/scoreboard_top_mini_renderer.gd`, `hud/scoreboard_overlay_renderer.gd`, `hud/scoreboard_overlay_footer_renderer.gd`, `hud/serve_wait_indicator_renderer.gd` |

상자 경로의 핵심 판정은 OFF에서 교정 커밋 `07c5ba932` 이후
`winning_score > MatchScoreState.WIN_GOAL`로 듀스 승리를 판별한다. 타워 ON은
점수와 무관하게 상자 수량 1을 먼저 반환한다. 따라서 WIN_GOAL 변경 시 타워
상자가 점수 비례 경로로 접히지 않으며, OFF의 압승 3 / 일반 2 / 듀스 1도
`tower_ascent_phase_a_off_path_smoke`와 기존 reward-plan 회귀로 보존된다.

보스 각성 점수는 GRT-054 기준의 독립 튜닝값이므로 이 페이즈에서 자동 파생하거나
변경하지 않았다.

## 5. 설계 충돌·미결·미검증 구분

### fixed

- [fixed] §1의 8항목 전부 구현·독립 커밋·검증 완료.
- [fixed] 항목 6 격리 중 발견한 boss-vision 동시 WIP 의존은 catalog의 실제
  가용성을 동적으로 확인하고, 부재 시 상급→일반으로 fail-closed하도록 고쳤다.
  격리 staged tree도 외부 WIP 없이 GREEN이다.
- [fixed] 보고서 역검증에서 커밋된 항목 6에 남은 `winning_score > 5`와 약한
  OFF 씰을 발견했다. `07c5ba932`에서 canonical `WIN_GOAL`로 연결하고 정규 승리
  전 구간 불변식 및 RED counterproof를 추가했다.
- [fixed] 타워 플래그 OFF의 점수 비례 상자, plaza 보석, 스타포인트 즉시 선택
  세 경로를 단일 OFF smoke와 관련 소비자 회귀에서 보존했다.

### deferred

- [deferred] §3의 15개 임시값 제품 튜닝. 정본 §6 결정 전에는 상수값만 바꿀 수
  있고 owner·schema·필터를 다시 나누면 안 된다.
- [deferred] 해금 재화·단가·초기 해금 정책. Phase A는 기본 전부 해금과 단일
  필터 owner까지만 구현했다.
- [deferred] plaza 기회의 보석 마이그레이션·은퇴, 광장 시설 철거, 수호령 친밀도
  폐지는 지시문의 명시적 비범위다.
- [deferred] Phase B 지도/12층/껍데기 보스, Phase C 노드 실기능·UI·아트,
  Phase D 9층 판정·결산·신규 보스.
- [deferred, baseline RED] `perk_conversion_mythic_perk_channel_smoke`는
  `flag-ON field spawn should remove mythic item candidates`에서 실패한다. 항목 7
  감사 때 항목 8 이전에도 같은 지점에서 RED였고, perk-conversion 동시 WIP의
  기대값이다. 페이즈 A rarity/field/OFF 스모크는 GREEN이다.
- [deferred, baseline RED] `lingpet_egg_runtime_smoke`는 Maribo/Serabi/Lunabi 등
  roster asset/import 및 진행 중 profile/body-surface 추출 계약 13건에서 실패한다.
  항목 5 커밋의 `lingpet_egg_runtime.gd` 변경은 공개 시점 recorder 호출 3곳과
  helper 1개뿐이며, guardian codex 전용 멱등·영속 smoke는 GREEN이다.

### 설계 충돌

- 없음. 정본과 구현 현실이 갈려 구현을 중단한 항목은 없다.

### blocked

- 0건.

### unverified

- 0건.

범위 밖 baseline RED는 필수 페이즈 A 게이트로 세지 않았고, 해당 소유 트랙의
동시 WIP를 건드리지 않았다.

## 6. 다음 페이즈 인계

- Phase B는 `tower_ascent_run_state`와 node transaction snapshot을 정본 owner로
  사용해 지도·층 밴드·12층 구조를 올린다. 노드 완료 뒤 commit된 안정 경계에서만
  저장한다.
- Phase C의 필드/상자/상점 UI는 `tower_ascent_unlock_filter`와
  `tower_ascent_active_item_acquisition_policy`를 우회하지 않는다. 상점 선반은
  `tower_ascent_shop_shelf_builder`를 실제 노드 모달 소비자에 연결한다.
- 상자·rarity·spawn 수치 확정 시 `tower_ascent_tuning.gd`만 조정하고, 같은
  의미의 채널별 별도 rarity 필드를 만들지 않는다.
- 모든 노드 보상은 `node_resolution_id` prepare/apply/commit 파이프라인을 타며,
  지도 전환 전에 commit을 끝낸다.
- `run_state.gold`, `run_state.muhon`, `run_state.chance_gems`는 plaza 영속 wallet과
  섞지 않는다. guardian 최초 발견만 meta store에 즉시 영속한다.
- 다음 페이즈도 기능 플래그 OFF 무손상, 플레이 중 BelowNormal wrapper,
  exact-hunk staging, 격리 staged-tree smoke 규율을 유지한다.

## 7. 완료 조건 대조

| 완료 조건 | 결과 |
|---|---|
| 8항목 구현 | 8/8 |
| 번호별 독립 로컬 커밋 | 8/8 |
| 필수 focused/negative smoke | PASS |
| 변경 파일 warning scan | 40/40 PASS |
| headless load | PASS |
| diff check | PASS |
| 보고서 완성 | 완료 |
| 필수 게이트 blocked/unverified | `0/0` |

**페이즈 A 완료 선언 조건을 충족한다.**
