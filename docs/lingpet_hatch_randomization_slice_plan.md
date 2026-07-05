# 링펫 부화 랜덤화 + 교감 해금 조건화 슬라이스 플랜

상태: 구현 랜딩(2026-06-30 확인) · **부분 superseded**. H1/H2/H3는
`lingpet_hatch_randomization_smoke.gd`와 `lingpet_egg_runtime_smoke.gd` 계열로 봉인됐다.
H4(2번째 해금 재배치)는 폐기됐고 현행 second unlock 확률 롤 계약을 따른다. 분담 =
기존 V3 관례(디자인 노트 = 본 문서, GDScript 배선 + 적대 리뷰는 슬라이스별로).
선행 컨텍스트 = `docs/lingpet_affinity_system_plan.md`(교감 시스템 본체,
per-run R1~R5 완료) + 메모리 `project-lingpet-affinity-system`.

> **2026-06-30 현재 구현 정정:** 이 문서의 2번째 해금 재배치안(D3/H4: Lv16~25 랜덤
> 또는 Lv16/17 핀)은 폐기됐다. 현재 2번째 액티브/패시브 해금은 덱 고정 카드가 아니라,
> `LingpetAffinityState.SECOND_UNLOCK_SKILL_LEVEL_SUM_REQUIREMENT == 5` 충족 후
> 레벨업마다 `SECOND_UNLOCK_ROLL_CHANCE_PCT == 30` 결정론적 롤로 주어진다.
> 부화 시작 스킬/스탯 랜덤화 아이디어를 재개하더라도 2번째 해금 계약은
> `docs/lingpet_affinity_system_plan.md` §16과 `lingpet_affinity_state.gd`를 따른다.

> **2026-07-01 현재 구현 정정 — 부화 패시브 정체성 랜덤 추첨:** 부화 시
> 패시브 **정체성**이 더 이상 공용 풀 0번(`lingpet_resonance_boost` = 공명
> 증폭)에 고정되지 않는다. `LingpetCatalog.pick_skill_loadout`이
> `COMMON_PASSIVE_SKILL_POOL`에서 **균등 랜덤 1종**을 뽑아 부화 패시브로 준다
> (`_roll_hatch_passive_id`). 풀에 새 패시브를 추가하면 별도 배선 없이 자동으로
> 부화 추첨 대상이 된다. 레벨/보유 롤(없음 25% / Lv.1~3 각 25%)과 액티브 채널(펫
> 기본 액티브 = `active_pool[0]`)은 D1 그대로다. H2 조건화는 무손상: 코디네이터가
> 로드아웃의 `passive_skill_id`를 `passive_present_id`로 이미 넘기므로(coordinator
> L31/L48) 뽑힌 랜덤 패시브가 그대로 첫 패시브 해금 resolved로 기록돼 교감 덱이
> 덮어쓰지 않는다. 봉인 = `lingpet_hatch_randomization_smoke`의 풀 멤버십 +
> "시드 스윕에서 전 패시브 등장(pool[0] 고정 아님)" 단정(pool[0] 고정으로 되돌리면
> `got 1` FAIL로 반증검증됨). 라이브 부화 게이지 단정은 공명 전용 효과라
> `lingpet_egg_runtime_smoke`에서 `selected_passive_id == "lingpet_resonance_boost"`
> 분기로만 게이지 상승을 요구하도록 조건화했다.

v1.0 → v1.1 변경: 7-에이전트 적대 검증(wf hatch-randomization-design-verify)
결과 반영 — BLOCKER 2건 해소 + should-fix 2건 정정(§8 검증 로그).

---

## 0. 한 줄 정의

부화 시점에 링펫의 시작 스킬·스탯을 **조금 랜덤화**하고(스킬 보유/레벨,
이동·방어·출현 스탯), 교감 보상 덱의 **1번째 스킬 해금을 "없을 때만"
조건부**로 바꾼다. 2번째 스킬 해금 재배치안은 폐기됐고, 현행 확률 롤
계약을 유지한다. 교감 per-run 리셋과 일관되게 **모든 부화 롤은 매 런 새로** 나온다.

---

## 1. 확정 결정 (2026-06-26, 사용자 AskUserQuestion — 재론 금지)

| # | 결정 | 값 |
|---|---|---|
| D1 | 부화 스킬 보유 확률 | **보유에 무게**: 액티브·패시브 **각각 독립** 롤, `없음 25% / Lv.1·Lv.2·Lv.3 각 25%`. 대부분 스킬을 들고 시작, 교감 해금은 "없음" 펫의 안전망. |
| D2 | 부화 스탯 롤 ↔ 교감 기동의 합성 | **같은 천장 공유**: 부화 롤 = 해당 스탯 **교감 최대 보너스(=천장)의 0~100% 헤드스타트**. `get_stat`에서 `min(부화 헤드스타트 + 교감 보너스, 천장)`. 최대치 불변, 시작값에만 변주. |
| D3 | 2번째 액티브/패시브 해금 등장 | **폐기.** 이 슬라이스는 2번째 해금 등장 레벨을 바꾸지 않는다. 현행은 1차 스킬 유효 레벨 합 ≥5 후 레벨업마다 30% 결정론적 롤. |

수치는 전부 플레이스홀더(`docs/lingpet_affinity_system_plan.md` V3-6 income
QA와 함께 튜닝). 본 문서는 구조 + 트랩 + 스모크 계약.

---

## 2. 구현 전 동작(검증 완료) — 무엇을 바꿨나

- **부화 = hatch-zero**: `LingpetCatalog.pick_skill_loadout(pet_id, rng)`
  (catalog.gd:1444)가 `rng`를 **무시**하고 `build_empty_loadout`(액티브/패시브
  id="" · level 0 · slot_count 0)을 반환. 호출 = `lingpet_loadout_state.
  ensure_pet_loadout`(89-106, `randomize_missing=true` 경로, line 100).
- **교감 Lv.1 = 액티브 해금 / Lv.2 = 패시브 해금이 "첫 스킬을 부여"**
  (affinity_state.gd `_build_reward_deck` 990-991, 덱 고정 슬롯). 실제 스킬 배정은
  reconciler(`lingpet_unlock_loadout_reconciler.reconcile`)가 resolved choice로 수행.
- **2번째 해금 현행**: `_build_reward_deck`에는 SECOND_*_UNLOCK 고정 카드가 없다.
  1차 액티브+패시브 유효 스킬레벨 합이 5 이상이면 이후 레벨업마다 30% 결정론적
  롤로 second_active/second_passive unlock이 award된다.
- **base_level 인프라는 이미 존재**: `configure_reward_context`(221-258)가
  로드아웃의 `active/passive_skill_level`을 base로 읽고
  (`lingpet_affinity_context_coordinator.configure` 28-29), `_available_*_
  skill_bonus_slots = SKILL_LEVEL_MAX - base`(1085-1090)로 스킬+1 카드 여유를
  자동 축소. 초과분은 dead-draw로 스탯 대체(`_resolve_effective_reward_card`
  870-887). **→ 부화 스킬 레벨을 올려도 교감 스킬+1 카드 수가 자동 정합.**
- **스탯 보너스 적용점**: `lingpet_current_profile.get_stat`(64-98). speed는
  `patrol_speed_*` 분기(67-72, `_is_patrol_motion_style` 게이트 + 30% 캡, 세 키
  동시 적용=실이동 반영), defense는 `defense_rate` 분기(77-82, patrol 게이트 +
  0.80 클램프), appearance는 `appearance_rate` 분기(88-93, flight 게이트, 6스택×
  0.05=0.30 암묵 천장). **모션스타일 게이트가 이미 보너스 위에 있어, 같은 분기
  안에 부화 롤을 넣으면 죽은스탯 자동 회피.**

---

## 3. 데이터 모델 변경

펫별(per pet_id) 신규 데이터 (전부 run-scope, 영속 금지):

| 데이터 | 저장 위치 | 비고 |
|---|---|---|
| 부화 시작 스킬·레벨 | **로드아웃 기존 필드** (`active_skill_id/level/slot_count`, `passive_*`) | **신규 필드 없음** → `_normalize_loadout` 화이트리스트 수술 불요 |
| `hatch_mobility_headstart` (0.0~1.0) | **affinity_state pet_data** | 기동 천장 대비 헤드스타트 비율(patrol=speed, flight=appearance) |
| `hatch_defense_headstart` (0.0~1.0) | **affinity_state pet_data** | 방어 천장 대비(patrol 전용; flight=0 미사용) |

**★ v1.1 정정 (BLOCKER 2 해소)**: 부화 **스탯 롤**은 로드아웃이 아니라
`lingpet_affinity_state` pet_data에 저장한다. 이유: `_normalize_loadout`은 반환
dict를 **명시적으로 재구성**(loadout_state 332-347)하고 all-empty 시
`build_empty_loadout`(catalog 1449-1461)을 반환하므로, 로드아웃에 새 필드를 넣으면
**모든 라운드트립 + "둘 다 없음" 부화에서 침묵 소실**한다(검증 C5 CONFIRMED). 반면
affinity_state pet_data는 이미 per-pet run-state로 round-trip하고 프로파일에
sync되므로 깔끔하다. **부화 스킬 롤은 로드아웃 기존 필드만 쓰므로 정규화 무관.**

- affinity_state는 "순수 로직" 유지: 신규 `set_hatch_stat_roll(pet_id, mobility,
  defense)` / `get_hatch_stat_roll(pet_id)`는 owner/registry를 모르는 순수 setter.
- 프로파일 sync: `lingpet_affinity_context_coordinator.sync_current_profile`이
  `set_affinity_state` 옆에서 `current_profile.set_hatch_stat_roll(...)` 호출.
  `get_stat`은 프로파일 멤버에서 읽음.

---

## 4. 슬라이스 분해

아래는 원래 슬라이스 분해다. 현재 H1/H2/H3는 랜딩됐고, H4는 폐기됐다.
역사적 권장 순서는 H1 → H2 → H4 → H3였지만, 현행 유지보수 기준은
H1/H2/H3 smoke와 second unlock 확률 롤 smoke를 따로 본다.

### 슬라이스 H1 — 부화 스킬 롤 (`pick_skill_loadout` 랜덤화)

- `LingpetCatalog.pick_skill_loadout(pet_id, rng)`를 재작성:
  - 액티브: `rng` 25% → 없음(id="", level 0, **slot_count 0**); 75% → 펫의 **기본
    액티브 스킬**(`get_active_skill(pet_id)`)을 `level = rng.randi_range(1, 3)`로,
    **slot_count 1**.
  - 패시브: 레벨은 동일 규칙·**독립 롤**. **정체성은 2026-07-01부터 공용 풀
    랜덤 추첨**(`_roll_hatch_passive_id` = `COMMON_PASSIVE_SKILL_POOL`에서
    `rng.randi_range(0, size-1)`), `get_passive_skill(pet_id)`(=pool[0] 고정) 아님.
  - `rng == null`이면 새 RNG 생성(라이브), 테스트는 시드 주입.
- **트랩 H1-a (필수) — "없음" 롤은 slot_count 0 이어야 한다**: `_normalize_loadout`
  fill_missing 분기(loadout_state 290-297)는 `skill_ids.is_empty() and slot_count
  > 0`이면 **기본 스킬을 주입**한다. "없음"인데 slot_count를 1로 두면 디폴트 스킬이
  들어가 버린다. 없음 = id "" + slot_count 0 (검증 C5: 둘 다 없음이면 306-308이
  `build_empty_loadout` 반환 → `picked.is_empty()` false → 디폴트 폴백 미발동, 즉
  스킬-없는 펫 부화 가능 CONFIRMED).
- **트랩 H1-b (2026-07-01 정정)**: **액티브**는 여전히 펫 기본 스킬 고정
  (`get_active_skill` = `active_pool[0]`, build_default_loadout과 일관). **패시브
  정체성은 이제 공용 풀 랜덤 추첨**이라 `build_default_loadout`(pool[0])과
  의도적으로 갈린다 — 이 분기는 정상이다. `_normalize_loadout` fill_missing은
  `slot_count>0 && 빈 id`일 때만 발동하므로(loadout_state 417-422) 부화 롤
  (present=slot 1 비어있지 않음 / none=slot 0)에는 걸리지 않아 랜덤 패시브가
  안전히 통과한다.
- **스모크** (`lingpet_hatch_randomization_smoke.gd::_verify_catalog_hatch_skill_roll_distribution`):
  시드 N개 분포(없음/Lv1~3
  각 ~25%, 액티브·패시브 독립), "없음" 롤이 빈 슬롯·slot_count 0, 보유 롤이 Lv.1~3·
  slot_count 1, 시드 고정 재현. 반증검증: "없음"에 slot_count 1을 두면 디폴트 스킬
  주입으로 FAIL.

### 슬라이스 H2 — 교감 해금 조건화 ("스킬 없을 때만 우선 적용")

목표: 부화 시 이미 그 스킬을 보유한 펫은 (1) 교감 1번째 해금 카드가 dead-draw로
스탯 대체되고, (2) reconciler가 그 첫 스킬을 **다른 스킬로 덮어쓰지 않게** 한다.

**★ v1.1 정정 (BLOCKER 1 해소) — `resolve_single_unlock` 재사용, reconciler 무수정.**

검증 C1(REFUTED)이 드러낸 함정: 단순히 `active_unlocked=true`만 사전세팅하면,
reconciler `_seed_unlock_choice_candidates`(reconciler 124-172)가 그것만 보고
후보를 시드·자동해석해 **부화 첫 스킬을 다른 스킬로 덮어쓴다**(유일 게이트 =
166행 `resolved.has(choice_key)`). 해결:

- 부화로 첫 스킬을 보유한 펫은 그 스킬을 **resolved unlock choice로 기록**한다 —
  `affinity_state.resolve_single_unlock(pet_id, REWARD_TYPE_ACTIVE_UNLOCK,
  hatched_active_id)` (affinity_state 382-414). 이 한 호출이:
  - `_apply_reward_type_to_counts` → `active_unlocked = true` (→ 덱 Lv.1 카드가
    `_can_apply_reward_card`에서 `not active_unlocked`=false → **dead-draw로 스탯**),
  - `resolved_unlock_choices["active"] = hatched_id` 기록 (→ reconciler 166행
    게이트가 시드 스킵, 해석값=부화 스킬이라 `loadout_matches`로 **덮어쓰기 없음**).
  - 부수효과(양호): `_get_second_active_unlock_candidate_ids`(reconciler 200-208)가
    primary(부화 스킬)를 2번째 액티브 후보에서 자동 제외 → 중복 방지.
- 패시브도 동일(`REWARD_TYPE_PASSIVE_UNLOCK`, `hatched_passive_id`).
- **호출 지점**: `configure_reward_context`에 신규 인자 `active_present_id:
  String = ""`, `passive_present_id: String = ""` 추가. 비어있지 않고 **아직
  resolved 안 됐으면**(`not get_resolved_unlock_choices(pet_id).has(key)`)
  `resolve_single_unlock` 호출. 코디네이터 `configure`(14-53)가 로드아웃의
  `active_skill_id`/`passive_skill_id`를 읽어 전달.
- **순서 안전성(검증 C6 + reconcile 순서)**: `_apply_current_loadout`에서 reconcile
  (egg 1492-1493)가 configure(egg 1504)보다 **먼저** 실행된다. 첫 부화 패스의
  reconcile는 `active_unlocked`가 아직 false라 no-op(덮어쓰기 없음) → 그 패스의
  configure가 `resolve_single_unlock`으로 unlocked+resolved를 원자적으로 세팅 →
  **다음** 패스부터 reconcile가 166행 게이트로 보호. unlocked를 resolved와 분리해
  세팅하는 창이 없으므로 안전. (가드 `not resolved.has(key)`로 매-configure 재호출
  churn 방지.)
- **트랩 H2-a (정정, 검증 C2) — slot-1 스킬+1 카드도 unlock 게이트 있음**:
  `_can_apply_skill_bonus` slot-1 액티브(1101-1104)는 `active_unlocked==true`를
  **요구**한다(slot-2는 `second_active_unlocked`, 1096-1100). v1.0의 "slot-1 게이트
  없음" 서술은 오류. 보유 부화 펫은 `resolve_single_unlock`으로 `active_unlocked=
  true`라 +1 카드가 정상 적용된다(부화 Lv.3 → +1 2장 → Lv.5). 없음 부화 펫은 Lv.1
  해금이 먼저 unlocked를 켠 뒤 +1 카드가 적용되므로 순서상 안전.
- **스모크** (`lingpet_hatch_randomization_smoke.gd::_verify_present_skill_conditions_first_unlock`):
  (a) 부화-보유(액티브 Lv.2) 펫 → Lv.1 카드=스탯(해금 아님)·
  `active_unlocked` true·reconcile 후 첫 액티브 id **불변**(덮어쓰기 0). (b) 부화-
  없음 펫 → Lv.1 정상 해금(기존 동작 보존). (c) 부화 Lv.3 보유 → +1 2장으로 Lv.5
  (H2-a). 반증검증: `resolve_single_unlock`을 빼고 `active_unlocked`만 세팅 →
  reconcile가 첫 스킬을 후보[0]으로 덮어써 FAIL(BLOCKER 1 재현).

### 슬라이스 H4 — 2번째 해금 랜덤 등장 (폐기, 현재 구현 대상 아님)

목표(D3)의 과거안은 고정 Lv.22/25 → Lv.16~25 사이 랜덤(결정적) 배치였고,
이후 한때 Lv16/17 핀 고정으로 대체됐으나, 둘 다 2026-06-30 현행 계약이 아니다.
현재 정책은 덱에 SECOND_*_UNLOCK 카드를 넣지 않고, 1차 액티브+패시브 유효
스킬레벨 합 ≥5 충족 후 레벨업마다 30% 결정론적 롤로 2번째 해금을 award한다.

현행 봉인:
- `lingpet_affinity_state.gd`의 `SECOND_UNLOCK_SKILL_LEVEL_SUM_REQUIREMENT`,
  `SECOND_UNLOCK_ROLL_CHANCE_PCT`, `_maybe_roll_second_unlock_card`.
- `lingpet_affinity_state_smoke.gd`가 live deck에 fixed second unlock card 0개,
  prereq 미충족 시 unlock 없음, prereq 충족 후 probabilistic roll, single-active pet
  phantom second-active 방지를 봉인한다.

### 슬라이스 H3 — 부화 스탯 롤 (같은 천장 공유, affinity_state 저장)

목표(D2): 부화가 기동(speed/appearance)·방어 스탯에 **0~천장** 헤드스타트를
주고, 교감 기동·방어 카드가 **같은 천장까지** 나머지를 채운다.

- H1 부화 시 두 헤드스타트 비율 롤(`rng`) → `affinity_state.set_hatch_stat_roll`
  (§3, **로드아웃 아님**). `hatch_mobility_headstart`, `hatch_defense_headstart`
  ∈ [0,1].
  - **모션스타일 라우팅**: patrol = mobility(speed)+defense 둘 다; flight =
    mobility(appearance)만, **defense 헤드스타트 = 0**(미사용 죽은스탯 금지).
- 프로파일 sync(코디네이터)가 `current_profile.set_hatch_stat_roll(...)` →
  `get_stat`에서 소비(검증 C4 CONFIRMED: 아래 천장은 기존 동작과 no-op 양립):
  - **speed**(71): `speed_bonus_pct += minf(hatch_speed_pct + mobility_stacks*5,
    AFFINITY_MOBILITY_SPEED_CAP_PCT=30)`, `hatch_speed_pct = headstart*30`.
  - **appearance**(92): `appearance_bonus += minf(hatch_appearance +
    mobility_stacks*0.05, AFFINITY_FLIGHT_APPEARANCE_CAP)`, 신규 상수 0.30
    (=6×0.05, 현재 암묵 천장 명시화, affinity-only 펫엔 no-op), `hatch_appearance
    = headstart*0.30`.
  - **defense**(81): `defense_bonus += minf(hatch_defense + defense_stacks*0.04,
    DEFENSE_STACK_CAP=0.08)`, `hatch_defense = headstart*0.08`; 최종 `clampf(base
    + defense_bonus, 0, 0.80)` 유지.
- **튜닝 노트(blocker 아님) — 방어 헤드스타트 폭**: 방어 천장(교감 최대 +0.08)은
  speed +30%보다 절대값이 작다. base 방어율 ~0.27 기준 +0.08 ≈ 상대 +30%라 의도와
  대략 부합하지만, 더 큰 변주를 원하면 `AFFINITY_PATROL_DEFENSE_BONUS`/스택수/별도
  hatch 폭 상향(별도 튜닝, D2 천장 공유 골격 불변).
- **트랩 H3-a — speed 세 키 동시**: `patrol_speed_min/max/default` 세 분기가 같은
  보너스를 받아야 실이동 변화(현재 67행이 묶음, 검증 C4 CONFIRMED — 회귀 가드만).
- **트랩 H3-b — 인터셉트 180 캡 불변**: 방어 인터셉트 속도는 교감/부화 속도 무관.
  툴팁 "순찰 이동 속도" 스코프.
- **스모크**(`lingpet_hatch_randomization_smoke.gd::_verify_hatch_stat_roll_projection_and_caps`,
  `lingpet_egg_runtime_smoke` item-egg hatch roll coverage): (a) patrol 펫 부화 speed 헤드스타트가 실제 순찰
  step 속도 변화(min/max 동반) + 교감 풀스택 합이 30% 천장 **초과 안 함**(공유).
  (b) flight 펫 appearance 헤드스타트 적용 + defense 헤드스타트 0. (c) defense
  헤드스타트 + 교감 2스택 합이 0.08 천장 공유. 반증검증: `min` 천장 제거 시 합이
  천장 초과로 FAIL.

---

## 5. 통합 순서 + 교차 트랩

역사적 권장 순서: **H1 → H2 → H4 → H3**. 현재는 H4가 폐기됐으므로 H1/H2/H3
구현과 second unlock 확률 롤 계약을 분리해서 검증한다.
- H1(catalog 순수), H2(coordinator+state+reconcile 상호작용), H3(state+coordinator+profile).
  H1이 시작 스킬을 정하므로 H2/H3 스모크는 H1 롤 결과를 픽스처로 받는다.
- **교차 트랩 — 덱 재빌드 + resolve 타이밍**: 덱은 `configure_reward_context`의
  `context_changed and history.is_empty()`에서 재빌드(255-256). H2의
  `resolve_single_unlock`도 같은 configure에서(덱 award 이전, 첫 add_points 전)
  적용돼야 Lv.1 카드가 dead-draw된다. configure는 add_points 경로
  (_add_affinity_points 2330)에서도 매번 호출되므로 active_present_id는 빈 로드아웃
  인자라도 코디네이터가 loadout_state에서 읽어 채운다(일관).
- **per-run 일관**: 모든 부화 롤(스킬+스탯)은 `reset_for_new_run`/새 전투씬
  인스턴스에서 재생성(영속 0). 잔향/헤드스타트(best_level)는 v5에서 휴면이라 무관.
- **owner 스키마**: 부화 스킬은 로드아웃, 스탯/해금은 affinity_state 경유라 신규
  owner 키 불요. TAB가 부화 시작값을 별도 표기하려면(선택) `DEFAULT_VALUES` 선언
  필수 — **본 범위 밖, 후속**(§7).

---

## 6. 스모크 요약 (반증검증 필수)

| 슬라이스 | 핵심 반증검증 |
|---|---|
| H1 | 시드 분포(없음/Lv1~3 각 ~25%, 독립); "없음"에 slot_count 1 두면 디폴트 주입으로 FAIL |
| H2 | 보유 펫 Lv.1=스탯·reconcile 후 첫 스킬 id 불변; `resolve_single_unlock` 빼고 `active_unlocked`만 세팅 시 첫 스킬 덮어써 FAIL(BLOCKER 1 재현) |
| H4 | **폐기됨.** live deck에는 fixed second unlock card가 0개이고, 현행은 1차 액티브+패시브 유효 레벨 합 ≥5 이후 레벨업마다 30% 결정론적 롤. 봉인: `lingpet_affinity_state_smoke.gd`의 fixed-card 0 / prereq / probabilistic roll / single-active phantom 방지 |
| H3 | 부화+교감 합이 천장(speed 30%/appearance 0.30/defense 0.08) **초과 안 함**; `min` 천장 제거 시 FAIL; flight defense 헤드스타트 0 |

---

## 7. 비범위 / 후속

- 플레이어가 부화 스킬·시작 레벨을 고르는 UI(현재 자동 롤만). 부화 스킬을 resolved
  choice/run-state로 기록하므로, 과거 V3-2c-UI player picker를 재개할 때만 관계를 별도 결정
  (현행 picker 없음; 부화 스킬은 "이미 가진" 것, 교감 해금은 새로 버는 대상).
- TAB 패널 "부화 시작값" 표기(현재 합성 레벨·스탯만 표시).
- 방어 헤드스타트 폭 확대(§H3 튜닝 노트) — 별도 밸런스 슬라이스.
- 다중후보 펫의 "어느 스킬을 들고 부화하나" 랜덤화(현재 기본 스킬 고정).
- V3-6 income/수치 튜닝(스테이지 완성 후, affinity 플랜과 동시).

---

## 8. 적대 검증 로그 (2026-06-26, wf hatch-randomization-design-verify, 7에이전트)

v1.0 하중 주장 6건 검증. NO-GO → v1.1 정정 후 GO 가능.

| 주장 | 판정 | 반영 |
|---|---|---|
| C1 reconciler가 부화 첫 스킬 보호 | 🔴 REFUTED(BLOCKER) | H2를 `resolve_single_unlock`(unlocked+resolved 원자) 재사용으로 재설계, reconciler 무수정 |
| C2 slot-1 스킬+1 unlock 게이트 없음 | 🟡 REFUTED(should-fix) | H2-a 서술 정정(slot-1도 `active_unlocked` 요구; resolve_single_unlock이 충족) |
| C3 덱 밴드 재배치 가능 | ✅ CONFIRMED | 과거 H4 설계 근거였으나 2026-06-30 현행 계약에서는 폐기 |
| C4 appearance 0.30 캡 no-op + speed 실이동 | ✅ CONFIRMED | H3 그대로 |
| C5 "둘 다 없음" 생존 + 스탯 롤 소실 | 🔴 CONFIRMED(설계결함) | 스탯 롤 저장을 로드아웃→affinity_state로 이전(§3), 로드아웃 정규화 수술 회피 |
| C6 프리시드 타이밍 안전 | ✅ CONFIRMED(should-fix) | H2 순서 안전성 명시(reconcile<configure, resolve_single_unlock 원자) |

BLOCKER 2건(C1·C5) 모두 v1.1에서 코드 무손상 경로로 해소. 배선 진행 가능.
