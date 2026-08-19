# 시작 카드(§3.17) 착수 전 실사 감사 (2026-08-19)

- 대상: 정본 §3.17 시작 카드. 기준 HEAD = 946f17755(R4 랜딩 직후).
- 방법: 진입점 · 화면 재사용 경계 · 카드 풀/지급 · 상태/프리웜 4영역 병렬 실사
  → 종합. 종합 단계에서 **영역 간 충돌 4건을 코드로 직접 재확인해 정정**했다
  (§1-0). 그 정정이 지시문의 전제다.

## 0. 부수 발견 — 파계승 무공 브랜치의 해금 필터 누락

실사 중 **기존 결함 1건**이 드러났다. 파계승 노드의 초식 브랜치는 해금 필터를
통과하는데 **무공 브랜치는 통과하지 않는다**. 정본 §3.10이 선언한 "모든 획득
소비자가 동일한 단일 필터를 관통한다"의 위반이며, 해금되지 않은 무공이 파계승
오퍼에 뜰 수 있다는 뜻이다.

시작 카드가 같은 후보 술어를 재사용하므로, 술어를 공용 모듈로 추출하는 S0에서
이 누락을 **같은 헝크로** 수리한다. 별건으로 미루면 두 소비자가 서로 다른 필터를
쓰는 상태가 굳는다.

## 1. 사용자 확답 2건에 대한 판정

감사가 남긴 확답 2건은 아래로 확정한다.

- **Q1 "기초 무공·초식"의 정의 → A안 확정.** 사용자 원문이
  "절세무공은 제외하고 기초 무공, 초식으로 한정"이었고, 코드에 등급 축이
  존재하지 않으므로(퍽 도메인 전체에 `tier`/`grade` 필드 0건, `rarity`는
  mythic 단일값) A안이 그 문장을 신규 스키마 없이 구현하는 유일한 해석이다.
  정본 §3.17의 "기초" 문구를 **"절세무공을 제외한 무공·초식"** 으로 정정한다.
  진짜 등급 축은 무공 약 100종 등급 부여 + 오퍼 경로 6곳 이관이 필요한 별도
  슬라이스이며, 액티브 아이템 등급(§3.16)과 함께 묶는 것이 효율적이다.
- **Q2 초식 후보 0장일 때 → (a) 무공 3장으로 대체.** 장수 계약을 지키고 진행
  차단이 없다. 총 후보가 3장에 미달하는 극단에서만 화면을 열지 않고 건너뛴다.

---

## 1-0. 실사 충돌 직접 판정 (근거 있는 것만 확정)

착수 전에 A/B/C/D가 서로 어긋난 지점 4건을 직접 코드로 확인해 정정한다. 아래 판정을 Codex 지시문의 전제로 삼는다.

1. **런은 카드 시점에 이미 시작되어 있다.** C의 "`_run_state.has_started()=false`"는 오판이다. `battle_boot_resource_prewarm_controller.gd:429` 공통 스텝 11이 `prewarm_tower_ascent_muhon_collection` → `prewarm_muhon_collection` → `ensure_run_started`(`tower_ascent_flow_economy_progress.gd:32-49`)로 `_run_state.begin("tower-run-%d" % Time.get_ticks_msec())`를 부른다(직접 확인). 미시작인 것은 런이 아니라 `_prepared`(지도/노드)다. D가 정본이다.
2. **따라서 시드 소스가 이미 존재한다.** C가 "run_id도 map_seed도 없다"고 본 것은 1번의 귀결이라 함께 무효다. `run_id`는 카드 시점에 살아 있고 `export_snapshot_fields`(`tower_ascent_run_state.gd:82-88`)에 실려 재현 가능하다. 결정론 시드를 `Time.get_ticks_msec()` 직접 사용으로 만들 필요가 없다.
3. **카드 화면에서 스테이지 BGM은 아직 꺼져 있다.** C의 "카드가 전투 BGM 위에 뜬다"는 성립하지 않는다. 부트 워밍 step 19가 `initialize_battle.call(false)`(`battle_boot_warmup_controller.gd:198-199`)로 초기화하므로 `_battle_bgm_started=false`이고, `battle_scene_intro_frame_controller.gd:78-81`의 `initialize_battle` 호출은 `is_battle_initialized`가 이미 true라 도달하지 않는다(직접 확인). 스테이지 BGM 소유자는 `battle_scene_stage_intro_flow_lifecycle.gd:84` `start_battle_bgm` 단독이다. A가 정본이다.
4. **삽입 seam은 `begin_stage_landing_intro` 내부 한미량 블록 직전이다.** C가 지목한 `intro_frame_controller.gd:81~82` 사이는 디스패처 층이라 무장 소유가 분산된다. 한미량(24-33)과 S7(38-45) 두 선례가 모두 `begin_stage_landing_intro` 안에서 무장하고 `_stage_landing_intro_started`를 세우지 않은 채 early-return하며, `_battle_initialized` 가드도 이미 이 함수가 갖고 있다(직접 확인). A를 채택한다. 단 update/draw/input 분기는 두 실사가 일치하는 대로 프레임 컨트롤러와 pre-intro 라우터에 둔다.

추가 확정 1건: **초식 후보에 절세무공은 구조적으로 없다.** B가 미확인으로 남긴 항목이다. `runtime_perk_catalog.gd`에서 `"rarity": "mythic"`은 1081~1224 라인의 `CONVERTED_MYTHIC_PERKS` 14종에만 있고, `unlocks_skill` 보유 항목은 344~706 라인의 SMASHER/VIPER/SOLDIER 블록에만 있어 교집합이 0이다(직접 확인). 초식 후보 루프에 별도 mythic 배제는 필요 없으나, 계약 명시용으로 술어에는 넣어 둔다(비용 0, 신규 mythic이 초식을 해금하게 되는 날 자동 방어).

---

### 1. 착지 순서와 근거

전체를 6슬라이스로 자른다. 각 슬라이스는 단독으로 씰이 GREEN이고, 다음 슬라이스 없이도 프로덕션이 오늘과 동일하게 동작해야 한다(플래그 OFF 또는 미배선 상태로 무해).

**S0. 후보 술어 공용화 + 파계승 해금 필터 누락 동반 수리**
- 내용: `tower_ascent_fallen_monk_node.gd:729-751 _is_mugong_candidate()`와 :281-315 초식 후보 수집을 `scripts/tower_ascent/tower_ascent_perk_candidate_policy.gd`로 추출하고 파계승이 위임하도록 바꾼다. 같은 헝크에서 파계승 무공 브랜치(:290-295)에 누락된 `TowerAscentUnlockFilter.is_content_unlocked(registry, CONTENT_RUNTIME_PERK, id)`를 넣는다.
- 근거: 두 번째 소비자가 생기는 시점이 추출의 정확한 시점이다. 복붙하면 절세무공 신규 추가 시 한쪽만 갱신되는 이중 정본이 된다(C 확인). 해금 필터 누락은 §3.17이 선언한 "다른 경로와 동일한 단일 필터" 계약과 같은 위반 1건이므로 헝크 분리 대상이 아니다(C 확인). 이 슬라이스는 시작 카드 없이도 기존 파계승 씰로 단독 검증된다.

**S1. 오퍼 빌더 + 상태 모듈 (화면 배선 없음, 헤드리스 전용)**
- 내용: `tower_start_card_offer_builder.gd`, `tower_start_card_state.gd` 신설. 3장 생성, 폴백 매트릭스, 결정론 시드, `apply_choice` 지급, 실패/만석 leg까지 전부 여기서 끝낸다. 카탈로그 등록만 하고 어떤 프레임 경로에도 붙이지 않는다.
- 근거: 이 슬라이스의 위험(재고 폴백, 만석 leg, 시드 결정론, 해금 필터 양방향)은 전부 순수 로직이라 화면 없이 반증이 싸다. 화면과 섞으면 RED가 났을 때 원인이 렌더인지 풀인지 분리되지 않는다.

**S2. 6곳 락스텝 배선 (검은 화면 + 임시 카드 자리표시)**
- 내용: begin 분기, process_idle update 분기, draw 분기, readiness 술어, pre-intro 입력 라우터, 모달 게이트 항목, 모듈 카탈로그 등록, teardown 등록을 한 헝크에 랜딩. 이 단계의 draw는 검은 배경 + 최소 텍스트로 두고 카드 렌더는 붙이지 않는다.
- 근거: 6곳은 하나라도 빠지면 화면이 로딩에 덮이거나(draw 누락) 입력이 전투로 새거나(라우터 누락) 모바일 컨트롤이 살아 있다(readiness 누락). 전부 같은 계약의 조각이므로 분리하면 GRT-031 반쪽 랜딩이다. 반대로 카드 렌더까지 같이 넣으면 헝크가 커져 어느 분기가 화면을 먹는지 이분이 안 된다.

**S3. 렌더 계층 (`draw_tower_start_card` + 검은 배경 + 가격 제거 + 7언어)**
- 내용: S2의 자리표시를 실제 카드 렌더로 교체. 로컬라이제이션 전용 파일 신설.
- 근거: S2가 끝나면 "프레임을 선점하는가"는 이미 증명되어 있으므로, 이 슬라이스의 실패 모드는 순수 픽셀(가격 잔재, 배경 알파, stats_band 하한)로 좁혀진다. 픽셀 QA를 여기 한 번에 몰 수 있다.

**S4. 잔존 계약 (run_progress 신규 필드 + 첫 prepare 관통)**
- 내용: 선택 결과와 소비 플래그를 `TowerAscentRunState` run_progress에 등재하고, `tower_ascent_vertical_slice_smoke.gd:376-424`의 실 셸 레그 안에서 첫 `prepare_vertical_slice_combat`를 관통시켜 잔존을 단언.
- 근거: 이 씰은 실 `BattleSceneShell` 레그가 필요해 가장 비싸다(D). S1~S3이 서 있어야 "무엇을 잔존시킬 것인가"가 확정되므로 뒤에 둔다. 앞당기면 필드 이름만 두 번 바꾸게 된다.

**S5. 라이브 QA + 콜드 진입 실측**
- 내용: 플래그 ON 실플레이 3캐릭터 각 1회, 카드 진입 프레임 소요 실측, Vulkan 픽셀 캡처, 프롤로그 있는 경로(한미량)와 없는 경로(세린/코만도) 양쪽.
- 근거: 구조 GREEN은 픽셀 클립과 콜드 스톨을 증명하지 못한다(GRT-045, GRT-042).

착지 순서 요약: S0 → S1 → S2 → S3 → S4 → S5. S0과 S1은 순서를 바꿔도 되지만, S0을 먼저 하면 S1이 술어를 복붙할 유혹 자체가 사라진다.

---

### 2. 구현 계약

#### 2.1 "기초 무공·초식"의 정의 기준 (코드 근거)

**등급 필드는 존재하지 않는다.** 퍽 카탈로그에서 `rarity`는 `CONVERTED_MYTHIC_PERKS` 14종의 `"mythic"` 단일값이고, `tier`/`grade`/`perk_grade` 계열 필드는 퍽 도메인 전체에 0건이다(C 확인, 본 판정에서 재확인). 남은 분류 축은 `tree` 값 12종과 플래그(`unlocks_skill`, `is_instant`, `is_physique_training`, `is_lingpet_guardian_enhance`, `vision_chosik`, `is_skill_manual`)뿐이며, `tree`는 아이콘/그룹 표시용이라 등급 의미가 없다.

따라서 **채택 정의(A안)**: "기초 무공·초식" = **절세무공(rarity mythic)과 특수 카테고리를 제외한 전 무공·초식**. 술어는 아래 두 개로 고정한다.

- 무공: `_is_mugong_candidate()`(`tower_ascent_fallen_monk_node.gd:729-751`) 그대로. `rarity == "mythic"` 배제 + `character_restriction` 불일치 배제 + `is_instant`/`is_gold_conversion`/`is_physique_training`/`is_mystic_dice`/`is_perk_fusion`/`is_lingpet_guardian_enhance` 6플래그 배제 + `runtime_levels[id] >= max_level` 포화 배제. **여기에 해금 필터 호출을 추가**한다(S0).
- 초식: 파계승 :288-308 술어 그대로. `unlocks_skill != ""` && `character_restriction`이 현재 캐릭터와 일치 && `runtime_levels[id] == 0` && 해금 필터 통과 && `skill_config.get_skill_data(unlocks_skill)` 비어있지 않음. `restriction.is_empty()` 조기 탈락이 영혼소환술(`common_unlock`)과 보스 비전초식(`vision_chosik`)을 자동 배제하므로 §3.17의 "기초 초식 한정"과 정확히 일치한다. 명시성 확보용으로 `rarity != "mythic"` 한 줄을 추가한다(현재는 항상 참, 비용 0).

**대안(B안)과 유지보수 비용**: 진짜 등급 축을 원하면 `mugong_grade` 스키마를 카탈로그에 정식화해야 한다. 비용은 (a) 무공 100종 가까이에 등급 값 부여, (b) 기존 오퍼 경로 6곳(`get_choices` 3회, 수련 빌더, 보상 픽 basic/supreme, 파계승, 상점, 신화 그랜트 헬퍼)이 전부 같은 필드를 읽도록 이관, (c) 등급이 빠진 항목의 기본값 정책과 그 부정 레그 씰, (d) 이후 신규 무공마다 등급 지정 강제 규약. 이것은 §3.16의 액티브 아이템 등급 작업과 같은 성격의 **별도 슬라이스**이며 시작 카드 안에서 즉흥으로 하지 않는다. 특히 `tree` 화이트리스트로 대체하는 것은 금지한다(item 17종 안에 최상급이 섞여 있어 등급 대리 지표가 되지 못한다).

**결정 요청**: 이 A안이 기획 의도와 같은지만 확인받는다(§6-1).

#### 2.2 오퍼 빌더 계약

- 신규 파일 `scripts/tower_ascent/tower_start_card_offer_builder.gd`. `TowerRewardPickOfferBuilder`를 상속하거나 그 `CARD_COUNT := 4`를 공유하지 않는다. `tower_reward_pick_state.gd:87-89`의 크기 검증과 `tower_ascent_flow_economy_progress.gd:77`의 리터럴 `slot_index < 4` 가드는 건드리지 않는다.
- 후보 수집은 `catalog.get_all_perk_data()`를 **정확히 1회** 호출하고 그 dict에서 직접 꺼낸다. `get_perk_data(id)` 반복 호출 금지(호출마다 전 카탈로그 병합 + 딥카피 + 로컬라이즈, C 확인).
- `get_choices()` 경로 사용 금지. 초식 등장이 `OPEN_CHOSIK_OFFER_CHANCE = 0.35` 굴림에 걸려 "초식 1장 확정"이 성립하지 않고, `randf()`/`shuffle()`로 전역 게임플레이 RNG를 소모한다(C 확인, AGENTS.md 프레젠테이션 RNG 계약 위반).
- RNG는 전용 `RandomNumberGenerator` 인스턴스. 시드 = `hash("%s:%s:start_card:%d" % [run_id, character_id, TEMP_START_CARD_OFFER_VERSION])`. `run_id`는 카드 시점에 존재하며 스냅샷에 실려 있으므로 별도 시드 보관 필드를 만들지 않는다(1-0 판정 2).
- 중복 방지: 무공 2장 사이만 막으면 된다(초식은 `unlocks_skill` 보유, 무공은 미보유라 교집합 0). 파계승식 유일 id 배열 + `sort()` 후 전용 RNG 셔플 방식 하나만 쓴다. `seen` dict 방식과 혼용 금지.
- 반환 계약: `{"accepted": bool, "reason": String, "choices": Array[Dictionary]}`. `reward_pick_cost` / `reward_pick_price_text` 키는 **싣지 않는다**.

**폴백 매트릭스(all-or-nothing 복제 금지)**: 보상 픽은 재고 부족 시 화면 자체가 안 뜨고 파계승은 오퍼를 통째로 버리는데, 시작 카드에서 그것은 곧 진행 차단이다.

| 상황 | 처리 |
|---|---|
| 초식 1 + 무공 2 충족 | 정상 3장 |
| 초식 후보 0 (또는 초식 슬롯 만석) | 무공 3장 |
| 무공 후보 1 | 초식 2장 + 무공 1장 |
| 총 후보 < TEMP_START_CARD_TOTAL_COUNT | **화면을 열지 않고** 카드 페이즈를 건너뛰어 오늘과 동일한 인트로 체인으로 즉시 진행 |

카드 0장 화면은 금지한다. 마지막 행은 "건너뛰었는데 프롤로그/랜딩이 정상 시작되는가"까지 단언해야 GRT-031을 피한다.

#### 2.3 무장과 소비 원장 (두 축을 분리한다)

두 실사가 하나로 뭉뚱그린 것을 분리해 판정한다.

- **무장(이번 씬 진입에 카드를 띄울 것인가)** = `GameSelectionState`의 transient 토큰. `game_selection_state.gd:129-140`의 프롤로그 토큰 옆에 별도 키를 추가하고 `character_select_screen.gd:878-885 _store_selection`에서 함께 무장, 카드 begin에서 1회 소비. 근거: 디버그 스테이지 직행, 온라인 직행, 패배 후 재진입에서 자동으로 뜨지 않는다. 런 스코프에 두면 `stage_id != 1` 진입에서도 무장 판정을 별도로 짜야 한다.
- **결과 원장(무엇을 골랐는가, 첫 prepare를 넘어 살아남는가)** = `TowerAscentRunState`의 run_progress 신규 필드. 근거: flow owner의 어떤 필드에 써도 1층 첫 승리의 `prepare_vertical_slice_combat`에서 소실된다. `restore_existing_progress` 게이트가 `_current_node_id`/`_graph_nodes` 공백 때문에 false라 27필드 `REENTRY_PROGRESS_FIELDS`가 **한 필드도 채워지지 않고**, `_reset_runtime_state()`가 `_build_state`/`_resolution_ids`/`_reward_pick_history`를 비우며 `_run_state.reset()`까지 부른다(D 확인). `_run_state.begin()`의 progress 인자로 재주입되는 경로만 생존한다.

run_progress 확장 형태(직접 확인한 현재 스키마: `active_phase_index`, `skipped_boss_ids`, `burned_vision_boss_ids`):

```
"start_card": {
    "consumed": bool,
    "picked_perk_id": String,
    "picked_kind": String,      # "chosik" | "mugong"
    "offer_ids": PackedStringArray,
}
```

`begin()`의 `_import_*` 계열과 `export_snapshot_fields()`의 `run_progress`에 락스텝으로 추가한다. **`SNAPSHOT_SCHEMA_VERSION`(현재 9)은 올리지 않는다.** 근거: 추가는 가법적이고 구 스냅샷은 키 부재로 복원된다. 단 **키 부재의 기본값은 `consumed = true`(이미 소비됨)로 잡는다.** 기본값을 false로 두면 구 세이브 복원 시 카드가 다시 무장될 수 있고, 그 방향의 오류가 훨씬 나쁘다.

**멱등키**: `_resolution_ids`(`tower_ascent_flow_state.gd:200`)는 첫 prepare에서 clear되므로 쓰지 않는다. `apply_once` 트랜잭션도 쓰지 않는다(무료라 차감/롤백이 없다). 멱등은 위 `consumed` 불리언 하나로 충분하며, 그것이 run_progress에 실려 첫 prepare를 넘는다.

#### 2.4 삽입 6곳과 순서 제약 (S2, 한 헝크)

모든 지점에서 `TowerAscentFeatureFlags.is_vertical_slice_enabled()`를 `_get_module(...)`보다 **먼저** 평가한다. 인트로 경로의 `_get_module`은 `battle_scene_shell.gd:91` → `gameplay_modules.get_instance(key)`로 콜드 생성하므로, 플래그 OFF에서 모듈만 만들어도 GRT-042형 전환 프레임 비용이 legacy에 얹힌다(A 확인). 선례는 `battle_physics_gate_coordinator.gd:123`, `battle_boot_resource_prewarm_controller.gd:444`, `battle_scene_modal_gate_controller.gd:129-132`.

1. **begin** = `battle_scene_stage_intro_flow_lifecycle.gd`의 한미량 블록 직전(21~24 사이). `start_card.begin(owner, registry)`가 true면 `_queue_redraw` 후 return. `_stage_landing_intro_started`를 세우지 않고 `start_battle_bgm`도 부르지 않는다.
2. **update** = `battle_scene_intro_frame_controller.gd`의 한미량 update 분기(45-55)보다 위, **로딩 완료 홀드(58-64)보다 반드시 위**. 아래로 내려가면 전체화면 draw가 로딩 호스트를 가려 가시성 타이머가 매 프레임 재시작하고 영구 정지한다(40-44 주석의 실측 사고). 한미량의 `_completed_this_frame`(56-57) 패턴을 복제해 완료 프레임에 로딩 홀드가 되살아나지 않게 한다.
3. **draw** = 같은 파일 `draw_intro_or_boot`의 **152줄 로딩 폴백보다 위**, 한미량 분기와 같은 층. 순서는 `_hide_loading_screen` → `_draw_black(canvas, view_size)` → 카드 렌더 → `return true`.
4. **readiness** = `battle_scene_readiness_controller.gd:4-15 is_intro_or_warmup_blocking`에 `is_start_card_pending` OR 추가, `is_mobile_touch_scene_ready`(18-33)에 `and not is_start_card_pending`.
5. **input** = `battle_pre_intro_stage_input_router.gd:22`의 한미량 분기 **앞**. 이 라우터는 `battle_scene_input_controller.gd:67`에서 `_is_intro_or_warmup_blocking` 조기반환(78)보다 먼저 도는 유일한 경로다. 카드 활성 중 입력을 전량 소비하고 `_mark_handled`한다.
6. **모달 게이트** = `battle_scene_modal_gate_controller.gd:136` 앞에 항목 추가. 직접 물리 게이트가 아니라 `should_block_mobile_controls`(14-18)와 `runtime_perk_angel_blessing_runtime_state.gd:446` 공유 소비자용이다.

추가로 `gameplay_stage_module_catalog.gd:28` 인근에 모듈 등록, `battle_scene_teardown_lifecycle.gd:17-21` 옆에 `tear_down` 등록.

**열기 게이트**: `_is_boot_warmup_finished(module_getter)`(`battle_scene_intro_frame_controller.gd:186-190`)를 명시적으로 요구한다. 미완이면 카드를 열지 않고 로딩 화면을 유지한다. 근거: `ProjectResourceLoader.prewarm_texture_threaded_step`의 단일 공유 슬롯 경쟁(GRT-005). 카드 화면 자체는 새 스레드 텍스처 프리웜을 **시작하지 않고** 부트 캐시 소비 전용이다.

#### 2.5 지급 경로와 실패 leg

- 지급은 `runtime_perk_state.apply_choice(choice, owner, registry)` 단일 호출. `current_choice_context`를 `{"source": "tower_start_card", "grant_scope": "tower_run"}`으로 세팅하고 이전 컨텍스트를 복원하는 왕복까지 보상 픽(`tower_reward_pick_state.gd:387-397`)과 동일하게 한다.
- 새 source 문자열이 기존 문자열 분기 소비자에 걸리는지 확인한다: `runtime_perk_angel_blessing_acquisition_lifecycle.gd:8-9 RESULT_CHOICE_SOURCES`/`RESULT_GRANT_SCOPE`, `runtime_perk_physique_training_runtime_state.gd:148 offer_source`. 어느 분기에도 안 걸리는 것이 기대 동작이며, 걸려야 한다면 명시 등재한다.
- `apply_reward_pick_purchase` / `finalize_reward_pick` / `get_reward_pick_context` / `apply_once` 는 **호출하지 않는다**. 셋 다 `_prepared`를 요구해 이 시점에 무조건 거절된다. `prepare_vertical_slice_combat`를 앞당겨 부르는 우회도 금지한다(지도 생성과 `node_resolution_id` 유일성 축을 건드린다).
- **반환값 판정**: `accepted`만 보지 않는다. 초식 만석이면 `{accepted:false, pending_swap_started:true}`가 돌아와 교체 서브모달이 구동자 없이 무장된 채 프롤로그로 넘어간다. `pending_swap_started`가 true면 `runtime_perk_state.cancel_pending_unlock_swap(owner)`로 명시 취소한 뒤 실패 처리한다. 다만 만석은 후보 생성 단계의 `is_shared_slot_full()` 검사로 이미 차단되므로 이 leg는 fail-closed 이중 방어다(런 시작 시 여유 슬롯: 한미량 3, 세린 2, 코만도 3).
- **지급 실패 시**: 카드를 비활성화하고 다른 카드를 고를 수 있게 두지 말고, 즉시 카드 페이즈를 종료해 인트로 체인으로 진행한다. 무한 대기 화면을 만들지 않는다.

#### 2.6 종료 조건 (1장 선택 즉시)

- 보상 픽의 자동 종료 술어 `_has_no_affordable_unspent_card()`는 재사용 금지. `muhon >= maxi(0, cost)` 판정이라 cost 0이면 항상 affordable이고 무료 모드에서 **영원히 발화하지 않는다**.
- `_picks_remaining = TEMP_START_CARD_PICK_LIMIT(=1)`. 확정 시 (a) `_select_next_available_slot` 계열 호출 금지, (b) 나머지 두 장은 **배열에서 제거하지 말고** `enabled=false` + 페이드로 무력화(GRT-030), (c) 흡수 이펙트 배열이 비는 프레임에 종료. `TEMP_REWARD_PICK_EMPTY_BOARD_HOLD_SEC` 0.60초 홀드는 쓰지 않는다.
- 계속하기 버튼과 SPACE/ESC 종료는 §3.17의 재추첨/스킵 없음 계약상 UI에서 제거한다. 다만 **fail-safe는 남긴다**: 지급 실패, 후보 부족, 카드 활성 상태가 `TEMP_START_CARD_FAILSAFE_TIMEOUT_SEC`를 넘긴 경우 자동으로 종료해 인트로 체인으로 넘긴다. 근거: 이 화면이 걸리면 게임 진행이 완전히 막힌다. 이것은 플레이어가 누르는 스킵이 아니므로 "재추첨 없음"과 충돌하지 않는다.
- 흡수 연출 타깃은 `owner.player_pos` 계열이 아니라 화면 중앙 하단 고정을 쓴다. 랜딩 인트로 전이라 패들 좌표가 최종 위치가 아니다.

#### 2.7 렌더/레이아웃/카피 (S3)

- 진입점은 **별도 함수** `draw_tower_start_card()`를 신설한다(B의 (B)안). `draw_tower_reward_pick`에 플래그를 추가하는 (A)안은 R4 직후 보상 픽 회귀 리스크를 만든다. 대신 내부 sub-drawer(`_draw_card`, `_draw_per_card_descriptions`, `_draw_status_panel`, `_draw_stats_band`)는 **반드시 공유**한다. 별도 드로어를 새로 쓰면 두 화면이 서서히 갈라진다.
- 레이아웃은 `RuntimePerkChoiceLayout.build_layout(view_size, TEMP_START_CARD_TOTAL_COUNT, stats_band_requested, panel_gap_min, footer_reserve)` 직접 호출. `panel_gap_min = -1.0`(기본 위임, 가격 스트립이 없으므로 32px 예약 반납), `footer_reserve = TEMP_START_CARD_FOOTER_RESERVE_PX(=0.0)`(계속하기 버튼 제거). 3장은 표준 퍽 모달 `BASE_CHOICE_COUNT = 3`이 매 판 도는 검증된 경로다.
- `view_size`는 GRT-044대로 `canvas.get_viewport_rect().size`를 1순위로, context 값은 fallback으로만. `Vector2(FIELD_WIDTH, FIELD_HEIGHT)`를 넘기는 `victory_loot_phase_state.gd:300-302`의 죽은 분기를 참조 구현으로 삼지 않는다(넘기면 layout_scale이 약 0.61로 떨어져 카드가 60% 크기로 그려진다).
- 배경은 `RuntimePerkTraditionalChrome.draw_backdrop` 호출을 **하지 않고** `canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0,0,0,1))` 불투명 검정으로 대체한다. `draw_backdrop`은 퍽 모달과 보상 픽 공용이라 그 상수를 흔들면 두 화면이 같이 바뀐다. 배경 알파는 `TEMP_START_CARD_BACKDROP_ALPHA(=1.0)` 고정으로 진입 램프를 태우지 않는다(첫 프레임에 아래가 비치면 안 된다). draw 분기의 `_draw_black`과 이 채움이 이중이 되지 않게 한 곳에서만 칠한다.
- 가격 표면 4곳 중 3곳 제거: 카드 하단 가격 스트립(`runtime_perk_overlay_renderer.gd:553-567` 대응 블록 자체를 호출하지 않음, 문자열만 비우면 바탕 rect가 빈 검은 띠로 남는다), 잔고 배지(504-517), hint 문구. 비활성 딤(566-567)은 `enabled`가 항상 true라 자동 무해화되지만, 위 2.6의 선택 후 무력화에는 이 딤을 재사용한다.
- 유지: 제목 현판, 파티클, 카드 본체/설명/성급, 슬롯 원장, 능력치 띠. 슬롯 원장·능력치 띠·호버는 owner/registry/runtime_perk_state에만 의존하고 런 상태와 무관하므로 그대로 켠다. 배선 조건: 매 update `capture_stats_context(owner, registry)`, reset에서 `capture_stats_context(null, null)`, 호버는 전용 필드(`runtime_state.get_status_hover_mouse_pos()` 재사용 금지), 세션 하이라이트용 자체 session id.
- 카피는 전용 파일 `tower_start_card_localization.gd` 신설. 보상 픽 8키는 하나도 그대로 쓸 수 없다("승리 보상", "무혼", "구매 완료", "카드를 여러 장 살 수 있습니다" 전부 계약 위반). 최소 3키(제목, 안내, 선택 확정 피드백)를 7언어(ko/en/zh/ja/es/pt-BR/ru) 전부 채운다. 한국어 카피에 엠대시 금지.

#### 2.8 오디오/물리/모달 계약

- **BGM**: 카드 분기는 `start_battle_bgm`을 호출하지 않는다. 검은 카드 화면이 메뉴 BGM(조선의 달북) 위에서 돌고, 카드 종료 후 기존 한미량/S7/랜딩 분기가 오늘과 동일한 핸드오프를 수행한다. 카드에서 스테이지 BGM을 먼저 켜면 서막 덕킹 타임라인(`stage1_han_miryang_prologue_presentation.gd:618-648`)이 카드 체류 시간만큼 어긋난다. `stage1_han_miryang_prologue_smoke.gd:226`이 `start_battle_bgm(flow, owner, module_getter)` 문자열을 요구하므로 그 줄을 옮기거나 지우지 않는다.
- **물리**: 이 창은 `is_stage_landing_intro_started` 게이트로 이미 전면 차단되어 있고 `enter_modal_block` 팬아웃 바깥이다. `tower_ascent_modal_lifecycle.gd:13-32 enter()`를 재사용하지 않는다. 재사용하면 `_capture_resume_pre_choice_velocity`와 `_try_arm_resume_safety`가 **아직 서브되지 않은 공에** resume-safety를 무장시켜 볼 스폰 인트로와 충돌한다.
- **루프 오디오**: 카드는 새 루프 오디오를 붙이지 않는다. 이 시점에 정지할 쿨다운도 루프도 존재하지 않는다는 사실을 **결정으로 기록**한다. 만약 붙인다면 같은 커밋에서 `gameplay_loop_audio_cleanup.gd` STOP_METHODS에 등재한다(GRT-034).
- **프롤로그 독립성**: 카드 게이트를 `is_entry_eligible`(스매셔 전용)이나 `consume_character_prologue_entry_request()`에 얹지 않는다. 얹으면 5캐릭터 중 4종(세린/코만도 및 미해금 2종)에서 카드가 조용히 사라진다. 카드 확정을 마우스 다운으로 처리해도 같은 클릭의 릴리스는 다음 프레임 프롤로그 라우터의 `_end_skip_hold`가 빈 토큰에 false를 돌려주므로 오발 스킵이 없다(A 확인).

---

### 3. 신규 TEMP 상수

`scripts/tower_ascent/tower_ascent_tuning.gd`에 기존 `TEMP_REWARD_PICK_*` 규약과 같은 형태로 둔다.

| 상수 | 제안값 | 의미 / 근거 |
|---|---|---|
| `TEMP_START_CARD_TOTAL_COUNT` | 3 | 화면 카드 수. 보상 픽 `CARD_COUNT=4`를 상속하지 않는다 |
| `TEMP_START_CARD_CHOSIK_COUNT` | 1 | 초식 lane 목표 장수 |
| `TEMP_START_CARD_MUGONG_COUNT` | 2 | 무공 lane 목표 장수 |
| `TEMP_START_CARD_PICK_LIMIT` | 1 | 선택 가능 횟수. 잔고 술어를 대체하는 종료 조건 |
| `TEMP_START_CARD_MIN_TOTAL_CANDIDATES` | 3 | 이 미만이면 화면을 열지 않고 건너뛴다 |
| `TEMP_START_CARD_OFFER_VERSION` | 1 | 시드 해시 구성 요소. 풀 규칙 변경 시 증가 |
| `TEMP_START_CARD_FOOTER_RESERVE_PX` | 0.0 | 계속하기 버튼 제거분 |
| `TEMP_START_CARD_BACKDROP_ALPHA` | 1.0 | 불투명 검정 고정, 진입 램프 미적용 |
| `TEMP_START_CARD_INTRO_ANIM_SEC` | 0.28 | 카드 진입 트윈. 보상 픽 값과 별도 축 |
| `TEMP_START_CARD_ABSORB_DURATION_SEC` | 0.78 | 흡수 연출. 보상 픽 동값이지만 독립 상수로 둔다 |
| `TEMP_START_CARD_FAILSAFE_TIMEOUT_SEC` | 20.0 | 카드가 걸렸을 때 자동 종료. 진행 차단 방지 |
| `TEMP_START_CARD_COLD_BUILD_BUDGET_MS` | 8.0 | 오퍼 생성 콜드 프레임 예산. S5 계측 게이트 기준 |

값은 전부 잠정이며 라이브 체감 후 조정 대상이다. 특히 `TEMP_START_CARD_FAILSAFE_TIMEOUT_SEC`는 실패 경로 전용이라 정상 플레이에서 관측되지 않아야 한다.

---

### 4. 씰 계약

공통 규율 4가지를 먼저 못박는다.

- **레그 센티넬**: 각 씰 함수는 시작에 레그 카운터를 올리고 종료에 기대 개수를 단언한다. `_verify_*`가 조용히 조기 return해 공허 GREEN이 되는 것을 막는다(GRT-040 계열).
- **RefCounted fixture 단독 통과는 증거가 아니다**: 잔존 계약은 반드시 실 `BattleSceneShell` 레그에서 관통한다. `tower_ascent_flow_map_progress.gd:41-44` 주석이 "부트 프리웜을 건너뛰는 RefCounted fixture는 계속 GREEN"이라고 명시하고 있다.
- **시드 고정**: 오퍼 관련 레그는 전부 고정 `run_id`로 돌린다. 무작위 시드는 1/N false-GREEN을 만든다.
- **반증은 격리 worktree에서**: 각 반증 레그는 실제로 한 줄을 되돌려 RED를 확인하고, 확인 후 즉시 복원한다. 되돌림 상태를 다른 검증과 섞지 않는다.

#### 4.1 신규 씰 `godot/tests/tower_start_card_smoke.gd`

| 레그 | 단언 | 반증(이 한 줄을 되돌리면 RED) |
|---|---|---|
| L1 구성 | 3장, 초식 1 + 무공 2, id 중복 0 | lane 목표 장수를 무시하고 무공 3장 반환 |
| L2 절세무공 배제 | `rarity=="mythic"` 퍽이 후보에 0건 | `_is_mugong_candidate`의 mythic 배제 줄 제거 |
| L3 해금 필터 양방향 | `unlock_store.set_unlocked(..., false)` 후 해당 초식 미등장, `true`로 되돌리면 등장 | 초식 루프의 `is_content_unlocked` 호출 제거 |
| L3b 무공 해금 필터 | L3과 동일 형태를 **무공 후보**로 반복 | S0에서 추가한 무공 브랜치 필터 호출 제거 |
| L4 시드 결정론 | 같은 run_id + character로 2회 생성 시 id 배열 동일, run_id를 바꾸면 달라짐 | 전용 RNG를 전역 `randf()`로 교체 |
| L5 전역 RNG 불변 | 오퍼 생성 전후로 게임플레이 RNG 상태 동일 | 빌더에 `choices.shuffle()` 삽입 |
| L6 만석 fixture | 초식 슬롯을 강제로 채운 뒤 초식 카드 미등장, 무공 3장 대체 | `is_shared_slot_full` 검사 제거 |
| L7 폴백 3종 | 초식 0 → 무공 3, 무공 1 → 초식 2, 총 후보 2 → `accepted=false, reason="start_card_skipped"` | 폴백 분기 제거 시 각각 RED |
| L8 지급 | 선택 후 `runtime_skill_levels`(무공) 또는 `equipped_skills`(초식)에 반영, `current_choice_context` 원복 확인 | 컨텍스트 복원 줄 제거 |
| L9 1회 제한 | 1장 확정 후 두 번째 클릭이 no-op, 카드 배열 크기 3 유지(shift 없음) | 나머지 카드를 배열에서 `remove_at` |
| L10 pending_swap 취소 | 만석을 강제로 뚫어 `pending_swap_started=true`를 유도했을 때 `cancel_pending_unlock_swap`이 호출됨 | 취소 호출 제거 |
| L11 7언어 | 신규 키 전부가 7언어에 존재하고 빈 문자열 아님, 한국어 카피에 `—` 0건 | 한 언어 항목 제거 |
| L12 가격 미노출 | 뷰모델에 `reward_pick_cost`/`reward_pick_price_text`/`balance_text` 키 부재 | 오퍼 빌더에 가격 키 추가 |

#### 4.2 배선 씰 (S2, 실 셸 필요)

| 레그 | 단언 | 반증 |
|---|---|---|
| W1 플래그 OFF no-op | 플래그 OFF로 `begin_stage_landing_intro` 관통 시 (i) 가짜 registry의 `get_instance("tower_start_card_state")` 호출 수 0, (ii) 같은 프레임에 `_stage_landing_intro_started == true` | 플래그 검사를 `_get_module` 뒤로 이동 |
| W2 프레임 선점 | 카드 활성 프레임에 `process_idle`이 true 반환, `draw_intro_or_boot`가 true 반환, 로딩 화면 draw 호출 0 | draw 분기를 152줄 폴백 아래로 이동 |
| W3 로딩 홀드 미재시작 | 카드 활성 5프레임 후 종료했을 때 로딩 가시성 타이머가 재시작되지 않음 | update 분기를 로딩 완료 홀드 아래로 이동 |
| W4 물리 게이트 양방향 | leaf 직접 호출이 아니라 `battle_physics_gate_coordinator.should_block`을 관통해 카드 활성 프레임 true, 종료 후 false | readiness 술어 확장 제거 |
| W5 입력 격리 | 카드 활성 중 pre-intro 라우터가 입력을 소비하고 `_mark_handled`, 전투 입력 컨트롤러 도달 0 | 라우터 분기를 한미량 뒤로 이동 |
| W6 BGM 미시작 | 카드 활성 전 구간 `_battle_bgm_started == false`, 카드 종료 후 기존 경로에서 정확히 1회 true | 카드 분기에 `start_battle_bgm` 추가 |
| W7 프롤로그 독립 | `runtime_character_id == "viper"`(프롤로그 없음)에서도 카드가 뜨고, 카드 종료 후 랜딩이 정상 시작 | 카드 게이트를 `is_entry_eligible`에 얹음 |
| W8 건너뛰기 관통 | 후보 부족으로 카드를 건너뛴 경우 한미량 서막/랜딩이 오늘과 동일하게 시작 | 건너뛰기 분기에서 return true |
| W9 부트 게이트 | 부트 워밍 미완 상태에서 카드가 열리지 않음 | `_is_boot_warmup_finished` 게이트 제거 |
| W10 teardown | 씬 이탈 후 카드 모듈 상태가 비고 owner 참조가 남지 않음 | `capture_stats_context(null, null)` 제거 |

#### 4.3 기존 씰 갱신

- `tower_ascent_vertical_slice_smoke.gd:376-424`의 실 셸 레그 안에 **잔존 레그**를 추가한다: (a) `prewarm_muhon_collection` → (b) 시작 카드 선택 적용 → (c) **첫** `prepare_vertical_slice_combat` → (d) run_progress의 `start_card.picked_perk_id`와 `runtime_perk_state` 반영이 모두 잔존. 반증은 run_progress 등재를 제거했을 때 RED. **두 번째 prepare로 대체하지 않는다**: 2회차는 지도가 있어 `restore_existing_progress`가 true라 GREEN이면서 라이브는 RED다.
- 같은 파일 `:552-571`의 스냅샷 필수 필드 목록에 신규 키를 락스텝 추가.
- `stage1_han_miryang_prologue_smoke.gd:228-230`은 상대 인덱스만 보므로 앞에 끼워도 GREEN이 유지된다(GRT-035 회피 확인 완료). 그래도 랜딩 후 이 씰을 재실행해 확인한다.
- `tower_reward_pick_smoke.gd:470`의 4장 계약 씰은 **무변경**이어야 한다. 변경이 필요해졌다면 보상 픽을 건드렸다는 뜻이므로 설계를 되돌린다.
- `battle_boot_resource_prewarm_smoke`는 신규 프리웜 스텝을 추가하지 않으므로 라벨 락스텝 갱신이 없어야 한다. 갱신이 필요해지면 그 자체가 설계 이탈 신호다.

#### 4.4 CI 등재 경고

`tower_ascent_run_state_smoke`, `tower_ascent_unlock_filter_smoke`, `tower_ascent_snapshot_recovery_smoke`, `tower_ascent_muhon_collection_smoke`는 **CI/pre-push 밖(나이틀리 전용)**이다(D 확인). 이 슬라이스가 run_state 스키마와 해금 필터를 동시에 건드리므로, 최소한 CI 등재 씰인 `tower_ascent_vertical_slice_smoke` 안에 동등한 단언을 심는다. 신규 `tower_start_card_smoke`는 `.github/workflows/godot-ci.yml`과 `godot/tools/run_pre_push_checks.ps1` **양쪽에 락스텝으로** 추가한다.

#### 4.5 게이트

`.gd` 편집마다 `./tools/run_warning_scan.ps1 -Paths <touched>`, 슬라이스마다 `./tools/run_headless_load_check.ps1`, `git diff --check`, S3/S5에서 acceptance 해상도 Vulkan 픽셀 캡처. 모든 래퍼는 `-AllowDuringPlay` 선언분을 쓰고 PID 고유 로그 경로를 쓴다. **헤드리스/스모크/경고스캔 전에 `logs` 디렉터리를 통째로 복사**한다.

---

### 5. 함정 예방 (GRT 대조)

**GRT-003 (핫패스 지연 초기화) / GRT-042 (프리웜 경량값 위해 무거운 모듈 콜드 생성)**
- 카드 삽입 지점은 부트 워밍 12스텝이 전부 끝난 뒤다. 공통 스텝 3 `perk_overlay`가 아이콘/장식 아틀라스/한지를, 스텝 5가 `runtime_perk_catalog`를 이미 워밍했다. **새 프리웜 스텝을 추가하지 않는다**(추가하면 `battle_boot_resource_prewarm_smoke` 라벨 락스텝이 딸려 온다).
- 플래그 검사를 반드시 `_get_module`보다 앞에. 인트로 경로의 `_get_module`은 콜드 생성이라 플래그 OFF legacy에 전환 프레임 비용이 얹힌다.
- `get_all_perk_data()` 1회 호출, `get_perk_data(id)` 반복 금지. 오퍼 생성은 `_draw`/`_process` 밖 1회지만 **콜드 진입 프레임**이므로 S5에서 `TEMP_START_CARD_COLD_BUILD_BUDGET_MS` 대비 실측을 게이트에 넣는다.

**GRT-021 (스탯 패널 행 예산) / GRT-022 (공유 레이아웃 빌더 요소 추가)**
- draw와 `get_card_rects`/`get_card_index_at`이 **동일 인자**로 같은 `build_layout`을 관통한다. 특히 `stats_band_requested`가 세 경로에서 같은 값이어야 한다. 그린 자리와 클릭 자리가 갈라지면 반증은 상단 모서리에서 먼저 드러난다.
- `footer_reserve=0`, `panel_gap_min=-1.0`으로 약 108px이 반환되지만, acceptance 해상도에서 `stats_budget`이 `STATS_BAND_MIN_HEIGHT` 아래로 떨어지면 띠가 **조용히 꺼진다**. S3 픽셀 QA에 이 확인을 명시 항목으로 넣는다.

**GRT-030 (슬롯 인덱스 HUD 상태 배열 shift)**
- 1장 확정 후 나머지 카드를 배열에서 제거하지 않는다. `enabled=false` + 딤으로만 무력화한다. 제거하면 흡수 이펙트/호버/세션 하이라이트가 참조하는 인덱스가 밀린다. L9 레그가 배열 크기 3 유지를 단언한다.

**GRT-058 (물리차단 모달 개폐 계약) / GRT-034 (모달 게이트가 루프 오디오 유지를 건너뜀)**
- GRT-058이 요구하는 것은 형제 훅의 자동 상속이 아니라 **명시적 판정**이다. 카드가 물리를 막는 근거는 모달 플래그 OR가 아니라 `is_intro_or_warmup_blocking` 확장이며, 씰은 `battle_physics_gate_coordinator.should_block`을 관통해 양방향을 단언한다(W4).
- `tower_ascent_modal_lifecycle.enter()` 재사용 금지(resume-safety가 미서브 공에 무장된다).
- 루프 오디오 "없음"을 결정으로 기록한다. 붙이는 순간 같은 커밋에서 `gameplay_loop_audio_cleanup.gd` 등재.

**GRT-017 (owner 필드 스키마 트랩)**
- 시작 카드는 owner에 새 런타임 필드를 만들지 않는다. 지급은 `runtime_perk_state`가, 원장은 run_progress가 소유한다. 만약 owner에 투영 필드를 추가하게 되면 캐릭터 정보 패널 표시 경로를 같은 커밋에서 갱신한다.

**GRT-004 (예약 에셋 프레임당 재stat)**
- 카드가 새 텍스처 경로를 도입하지 않는다. 아이콘/한지/장식은 전부 부트 캐시 소비 전용이며, `_prewarm_card_assets` 계열을 카드 열기 시점에 호출하지 않는다. 누락 에셋 폴백 경로가 매 프레임 파일 존재를 재확인하는 형태가 되지 않도록, 아이콘 미해결은 1회 판정 후 결과를 카드 상태에 캐시한다.

**추가 대조**
- **GRT-031(반쪽 랜딩)**: S2의 6곳은 한 헝크. 특히 "건너뛰기" 경로도 표시(안 뜸)와 브리지(프롤로그/랜딩 정상 시작)를 함께 단언(W8).
- **GRT-035(형제 씰 절대 인덱스)**: 한미량 씰이 상대 인덱스만 본다는 것을 확인했으나, 신규 분기 삽입 후 해당 씰을 재실행해 확인한다.
- **GRT-044(스크린 리드 오버레이 컨텍스트 폴백 사이징)**: `view_size`는 `canvas.get_viewport_rect().size` 1순위.
- **GRT-045(플레이필드 클립)**: 카드는 전체화면이므로 플레이필드 클립 호스트에 얹지 않는다. 구조 GREEN과 별개로 실제 캡처로 확인.
- **GRT-047(어두운 아트 × 발광 예산)**: 검은 배경 위에서는 금색 파티클과 한지 카드의 대비가 반투명 백드롭 때와 다르다. ADD 계열이 더할 빛을 잃거나 반대로 과발광한다. S3 픽셀 QA 필수 항목.
- **GRT-005(스레드 텍스처 공유 슬롯)**: 부트 워밍 완료 게이트(W9).
- **GRT-032(프레임당 카탈로그 조회)**: 오퍼는 1회 생성 후 상태에 고정. update에서 카탈로그를 다시 뒤지지 않는다.
- **GRT-040(스모크 임의 프로퍼티 대입 조용한 abort)**: 씰에서 카드 상태를 `set()`으로 임의 주입하지 않고 생산 진입점(`begin`/`handle_input`)만 통과시킨다. 레그 센티넬로 조기 abort를 잡는다.

---

### 6. 사용자 확답 필요

정말 필요한 것만 2건이다. 나머지는 위에서 근거와 함께 직접 판정했다.

**Q1. "기초 무공·초식"의 정의를 A안으로 확정해도 되는가.**
A안 = "절세무공(mythic)과 특수 카테고리(즉발/수련/수호령강화/융합/골드전환/팔자윷)를 제외한 전 무공, 그리고 캐릭터 전용 초식 전부". 코드에 등급 축이 없으므로 이것이 신규 스키마 없이 구현 가능한 유일한 해석이다. 진짜 등급 축을 원하면 무공 약 100종 등급 부여 + 오퍼 경로 6곳 이관이 필요한 별도 슬라이스가 되고, 시작 카드는 그 슬라이스를 기다려야 한다. **A안으로 진행하되 기획 문구를 "절세무공을 제외한 무공·초식"으로 수정하는 것을 권장한다.**

**Q2. 초식 후보가 0장인 세이브에서 "무공 3장"으로 채워도 되는가.**
해금이 좁게 잠긴 세이브나 초식 슬롯 만석에서 실제로 발생한다. 대안은 (a) 무공 3장 대체, (b) 2장만 표시, (c) 화면 건너뛰기. §3.17의 "3장" 계약과 "1장만 선택" 계약 중 무엇이 우선인지의 문제다. **(a)를 기본 제안한다**(장수 계약 유지, 진행 차단 없음). 반대면 (c)로 바꾼다.

참고로 아래는 확답 없이 판정했다. 뒤집고 싶으면 지적해 달라.
- 패배/이탈 후 캐릭터 선택을 다시 통과하면 카드가 다시 뜬다(새 런이므로 정당).
- 카드 화면에서는 메뉴 BGM이 계속 흐른다(스테이지 BGM 미시작이 오늘의 실제 상태이고 §3.17 의도와도 맞다).
- 계속하기/ESC 스킵은 없애되 진행 차단 방지용 자동 fail-safe 종료는 남긴다.
- 이 슬라이스는 이어하기(스냅샷 복원) 미지원이며 세션 내에서만 유지된다.

---

### 7. 후속으로 미룰 것

1. **무공 등급 축 스키마 정식화**. Q1이 B안으로 결정되면 별도 슬라이스. 액티브 아이템 등급(§3.16)과 같은 성격이므로 함께 묶는 것이 효율적이다.
2. **초식 장착의 이어하기 직렬화**. `build_unlock_save_snapshot()`은 `runtime_skill_levels`만 담고 `skill_config.equipped_skills`를 담지 않는다. 파계승은 이를 2키 구조(`fallen_monk_runtime_snapshot` + `fallen_monk_skill_config_snapshot`)로 우회하고 있다. §5 런 스냅샷 '빌드' 항목의 정식 직렬화 경계는 미착수 부채이며, 시작 카드는 이 부채를 **새로 만들지도 해결하지도 않는다**. 다만 §5 필수 필드 목록에 시작 카드 선택 id를 등재만 해 둔다(구현은 후속).
3. **폴백 `reset_game` 경로가 퍽을 지우는 기존 부채**. `_finish_tower_victory_flow`와 encounter 공백/전환 실패 분기가 전체 `reset_game`을 불러 `runtime_perk_state`를 리셋한다. 시작 카드가 만드는 부채가 아니므로 이번 슬라이스에서 고치지 않되, 라이브 QA에서 그 분기를 밟으면 시작 카드 결과도 함께 사라진다는 점을 인지한다.
4. **파계승의 all-or-nothing 오퍼 폐기 정책**. 후보 6장 미달 시 액션 0개가 되는 구조는 시작 카드와 달리 진행 차단이 아니므로 이번에 손대지 않는다.
5. **나이틀리 전용 3씰의 CI/pre-push 등재**. `tower_ascent_run_state_smoke`, `tower_ascent_unlock_filter_smoke`, `tower_ascent_snapshot_recovery_smoke`. 이번에는 `tower_ascent_vertical_slice_smoke` 안에 동등 단언을 심는 우회로 대응하고, 등재는 별도 하네스 작업으로 뺀다.
6. **감사 문서 정정**. `docs/tower_reward_pick_preflight_audit.md:49-61`의 P1-B는 현재 코드와 어긋난다. 정확한 진술은 "allowlist는 27필드로 넓어졌지만 지도가 없는 첫 prepare에서는 `restore_existing_progress` 게이트가 닫혀 전부 미적용"이다. 또 `docs/tower_live_feedback_r4_preflight_audit.md` §0의 두 항목(플레이필드 축소, REVEAL 클릭 흡수)은 이미 수정되어 있다. 문서 갱신은 S4 커밋에 동반한다.
7. **`_draw_tower_reward_pick` 죽은 플레이필드 분기 정리**. `victory_loot_phase_state.gd:300-302`는 프로덕션 도달 불가이고 `get_status_for_tests`만 플레이필드 좌표를 본다. 참조 구현으로 오인될 위험이 있으므로 정리 대상이지만 시작 카드와 별개 헝크다.