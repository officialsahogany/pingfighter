# 링펫 해금→로드아웃 배선 (V3-2c) 슬라이스 플랜 — v1.1

친밀도(교감) 해금 시스템의 **첫 프로덕션 소비자**를 만든다. V3-1이 친밀도 상태머신에 2중1
해금 백엔드(`set_unlock_choice_candidates`/`get_pending_unlock_choices`/`choose_skill_unlock`/
`get_resolved_unlock_choices`)를 **완전 구현했으나 호출자가 0개인 고아 상태**다. 이 슬라이스가
그 백엔드를 (1) **no-skill-at-hatch**(부화 즉시 스킬 0), (2) **후보 시딩**(액티브=펫 풀,
패시브=공용풀 시드 랜덤 2), (3) **임시 자동선택**, (4) **resolved→로드아웃 배선**으로 연결한다.

- **분담:** 이 문서 = 디자인 노트(신호 계약) + 슬라이스 브리프. GDScript 배선은 사용자/Codex,
  Claude 적대 리뷰. ([[feedback_design_slice_review_division]])
- **작성일:** 2026-06-14
- **단일 소스:** `docs/lingpet_affinity_system_plan.md` §13(링코어 게이트, v5.1) — 이 슬라이스 = **V3-2c**
  (§13-9 line 1002 "`pick_skill_loadout` 자동 배정 제거 + `resolved_unlock_choices`→로드아웃").
- **자매 슬라이스:** V3-1(SEALED, 상태머신) · V3-2a(완료, 로드아웃 배열화) · **V3-2b**(2슬롯 런타임,
  `docs/lingpet_second_active_slot_v3_2b_slice_plan.md`) · V3-2c-UI(2중1 피커, 후속) · V3-3(링코어 영구
  스토어/플라자 샵) · 자산(금색 카드/아이콘) · V3-6(수치 튜닝).
- **선결조건 충족(이 슬라이스가 닫음):** Solar Bolt 슬라이스의 precondition A(unlock-choice→active_skill_id
  소비자 부재)를 여기서 해소. ([[project_lingpet_solar_bolt_port]])

> **사용자 결정(2026-06-14):** (Q1) **백엔드 + 임시 자동선택** — 이번 슬라이스는 배선만, 진짜 2중1
> 피커(비모달 TAB/플라자)는 후속이 자동선택을 대체. (Q2) **액티브+패시브 동시**, 패시브 후보 =
> 공용 패시브풀에서 펫별 결정론적 시드 랜덤 2.

---

## §0 구현 결정

| # | 결정 | 값 | 근거 |
|---|---|---|---|
| D1 | 부화 = 스킬 0 | 해치 시 `active_skill_ids=[]` + 패시브 빈 상태 | §13-2 locked. 런타임은 빈 id 이미 안전 처리 |
| D2 | 해금 트랙 | 액티브 Lv.1 / 패시브 Lv.2 / 2nd 액티브 Lv.22 / 2nd 패시브 Lv.25 (덱에 이미 배치) | V3-1 `_build_reward_deck` 고정 슬롯 |
| D3 | 후보 시딩 | 액티브 = `get_active_skill_pool(pet)` ids / 패시브 = `COMMON_PASSIVE_SKILL_POOL`에서 **펫별 결정론적 시드 랜덤 2** | Q2. 카탈로그에 펫별 패시브 풀 없음 |
| D4 | 2nd 패시브 후보 | 첫 패시브 selected **제외**한 2개 | 중복 제시 방지 |
| D5 | 선택 해결 | **임시 자동선택 = candidates[0]**(결정론적). QA 디버그 오버라이드 제공. 진짜 피커 = 후속(V3-2c-UI)이 대체 | Q1=A |
| D6 | 1-엔트리 액티브 풀 (**milkring/nekuring**, volty 아님) | **신규 백엔드 `resolve_single_unlock(pet,type,only_id)`** — unlocked 플래그 + `resolved[key]={selected:only_id}` 직접 기록(pending 없음). reconcile가 pool 크기 1이면 호출 | `set_unlock_choice_candidates`<2 silent + `choose_skill_unlock(real_id)`=invalid_selection → 단일 id는 현 백엔드로 **영영 해금 불가**. 새 API 필수(affinity_state 추가) |
| D7 | resolved→로드아웃 | `set_pet_loadout` → **`_invalidate_current_loadout_cache`** → `_apply_current_loadout(owner,true,false)`. 새 owner 키 0 | Lazy Applied-Key 트랩. 기존 `lingpet_active_skill_id` 등 재사용 |
| D8 | 루미온 카탈로그 노출 | 단일 `active_skill` → `active_skill_pool [thunder_orb(=pool[0]), solar_bolt]`. solar_bolt 카드/아이콘 = **임시 placeholder(thunder_orb 재사용), step-3 자산 슬라이스에서 스왑** | "active_skill_pool 노출" + `_validate_active_skill`가 텍스처 존재 요구 |
| D9 | 스코프 (v1.1 정정) | **1st 액티브 + 1st 패시브 완전 배선.** 2nd 액티브/패시브 unlock은 **affinity 플래그만 기록, 로드아웃 slot-1에 절대 안 씀**(reconcile이 `second_active_id`/`second_passive_id` = `""` 전달) | **2슬롯 런타임이 이미 LIVE**(`_is_second_active_slot_enabled` egg_runtime:1328, 스모크 4381-4405). slot-1에 id 쓰면 Lv.22에서 **즉시 발동**. V3-2b 안전가드(ball-owner `resource_class` 상호배제·slot-1 position override) **미완** → 무가드 발동=소프트락. slot-1 비워 게이트 false 유지 |
| D10 | 펫 전환 / 디버그 | 전환 시 reconcile가 **활성 펫의** `resolved_unlock_choices`에서 슬롯 재도출(per-pet). F7 `debug_grant_and_activate_pet`는 unlock 게이트 우회(직접 배정 유지) | affinity_state는 per-pet. 디버그는 별도 표면 |
| D11 | no-skill 컴패니언 | 존재·패트롤 O, 자동캐스트 X(이미 안전). 레일/TAB는 빈 액티브에 **"미해금" 상태** 표기 | 빈 name 그대로 두면 공백 렌더 |

함의: 이 슬라이스는 **펫-불문 코어 배선**(no-skill-at-hatch + 해금→로드아웃) + **루미온 풀 노출**이다.
임시 자동선택이라 **체감 동작은 오늘과 유사**(해치 직후 Lv.1 도달 시 액티브 자동 해금)하되 구조는
unlock 카드 경로로 정정된다. 진짜 "플레이어가 2중1 선택"은 V3-2c-UI에서.

---

## §1 동작 모델

```
부화 → 스킬 0 (active_skill_ids=[], 패시브 빈)
   ↓ (해치 SOURCE_HATCH 친밀도 + 이후 교감/타구로 레벨업)
친밀도 Lv.1 도달 → 덱이 active_unlock 카드 award
   ↓ affinity_state가 pending_unlock_choices["active"] 자동 기록 (_record_pending_unlock_choice)
reconcile(매 loadout-apply / 레벨업 후):
   1. 후보 시딩: set_unlock_choice_candidates(pet,"active", 액티브풀 ids)  [멱등]
                 set_unlock_choice_candidates(pet,"passive", 시드랜덤2)   [멱등]
   2. pending 있으면 → 임시 자동선택: choose_skill_unlock(pet, type, candidates[0])
   3. resolved 읽어 로드아웃 빌드 → 변경 시 set_pet_loadout → invalidate → apply
친밀도 Lv.2 → passive_unlock → 동일 흐름 → passive_skill_id 채움
친밀도 Lv.22/25 → 2nd 액티브/패시브 unlock 기록 (런타임 발동은 V3-2b)
```

**효과 레벨:** `current_profile._get_effective_active_skill_level(slot)` = `base + affinity bonus`
(`active_skill_bonus` slot0 / `second_active_skill_bonus` slot1 — **둘 다 이미 wired**). 패시브 slot0 =
`passive_skill_bonus`. **GAP: 2nd 패시브 효과레벨 헬퍼 부재**(`current_profile.gd:338`) → §10 후속.

---

## §2 신호 계약 — affinity_state ↔ loadout

**메커니즘:** `lingpet_egg_runtime`가 reconcile 오너. affinity_state(읽기/해결) → loadout(쓰기) →
owner sync(기존 키). 새 owner 키 0개.

**affinity_state READ (`LingpetAffinityState`):**
```
get_cumulative_rewards(pet)  : {active_unlocked, passive_unlocked, second_*_unlocked,
                                 active_skill_bonus, passive_skill_bonus, second_*_skill_bonus, ...}
get_pending_unlock_choices(pet)  : {choice_key → {type, candidates, selected:"", rejected:[]}}
get_resolved_unlock_choices(pet) : {choice_key → {selected, rejected, candidates, type}}
  # choice_key ∈ {active, passive, second_active, second_passive}
```

**affinity_state WRITE (이 슬라이스가 호출 — 현재 호출자 0):**
```
set_unlock_choice_candidates(pet, reward_type, candidates: Array[String])  # 멱등 시딩, <2면 silent
choose_skill_unlock(pet, reward_type, selected_id) -> {accepted, choice|blocked_reason}
```

**loadout WRITE (기존 경로):**
```
lingpet_loadout_state.set_pet_loadout(owner, pet, active_id, passive_id, level, second_active_id?, ...)
  → sync_owner → owner.set("lingpet_active_skill_id"/"lingpet_skill_name"/...) [전부 DEFAULT_VALUES 기선언]
lingpet_egg_runtime._invalidate_current_loadout_cache()   # Lazy Applied-Key 트랩 필수
lingpet_egg_runtime._apply_current_loadout(owner, true, false)
```

**프로듀서→컨슈머:** affinity 레벨업/해치/펫전환 → `_apply_current_loadout` 진입 시 `_reconcile_unlock_choices(owner)`
(신규) → 시딩·자동선택·로드아웃 빌드 → set_pet_loadout → invalidate → apply → `_current_profile`가 라이브
gameplay 읽기(`get_active_skill(0)`). 레일/TAB는 synced snapshot에서 자동 갱신.

---

## §3 후보 선택 규칙 (D3/D4)

**액티브 후보:** `LingpetCatalog.get_active_skill_pool(pet_id)`의 id들. 루미온 = `[lumion_thunder_orb,
lumion_solar_bolt]`(D8 노출 후). pool 크기 1이면 D6 단일-후보 직접 해결.

**패시브 후보 (시드 랜덤 2):**
```gdscript
# 펫별 결정론적: 같은 펫은 항상 같은 2후보 (런마다 안 흔들림)
var pool := LingpetCatalog.get_passive_skill_pool(pet_id)   # = COMMON_PASSIVE_SKILL_POOL
var rng := RandomNumberGenerator.new()
rng.seed = hash(pet_id)                                     # Math.random/Time 금지 (결정론)
var shuffled := pool.duplicate(); _seeded_shuffle(shuffled, rng)
var first_passive_candidates := [shuffled[0], shuffled[1]]
# 2nd 패시브(Lv.25): 첫 패시브 selected 제외 후 시드 랜덤 2
var chosen_first := get_resolved_unlock_choices(pet)["passive"]["selected"]
var remaining := pool.filter(func(id): return id != chosen_first)
_seeded_shuffle(remaining, rng); var second_passive_candidates := [remaining[0], remaining[1]]
```

**합성 폴백 차단(중요):** `_record_pending_unlock_choice`는 후보 미시딩 시 `<pet>_<key>_a/_b`
합성 id로 폴백(`affinity_state.gd:964`). reconcile은 **unlock 카드가 award되기 전(또는 같은 틱에 먼저)
반드시 `set_unlock_choice_candidates`를 호출**해 실제 후보가 들어가게 한다 — 시딩이 레벨업 처리보다
먼저 또는 award 직후 자동선택 전에 실행되어야 함.

---

## §4 owner 스키마 — **새 키 불필요**

- `lingpet_active_skill_id` / `lingpet_skill_name` / `lingpet_loadouts` / second-active 키 = 전부
  `battle_scene_state.DEFAULT_VALUES` 기선언. 슬롯-0 스킬 스왑은 기존 로드아웃 경로라 추가 0.
- 해금 상태는 affinity_state(per-pet) 내부 — owner 미러 불요.
> **회귀 가드:** "미해금" UI 표기에 새 키가 필요하면 `DEFAULT_VALUES`에 선언(Owner-Field Schema Trap).
> 가능하면 빈 `lingpet_active_skill_id`로부터 UI가 파생(추가 키 0)하게.

---

## §5 리셋 / 세이브 (휘발성 주의)

- **로드아웃 = 휘발성, 해금 선택도 in-memory (v1.1 정정).** `lingpet_save_store`는 hatched/companion을
  `clear_snapshot`. **`resolved_unlock_choices`는 영속 안 됨** — `lingpet_affinity_store`는 `best_levels`
  + `bond_points`만 저장(unlock 키 없음), `resolved`는 `LingpetAffinityState._pets`(in-memory)에만 있고
  `reset_for_new_run`이 클리어. **런 경계 생존 메커니즘 = 헤드스타트 재도출**: 매 런 헤드스타트가
  `best_level` 기반으로 unlock 카드를 **재award → reconcile이 결정론적 candidates[0]로 재해결 → 같은 스킬**.
  즉 이 슬라이스(임시 자동선택)는 일관적. **단 진짜 2중1 플레이어 선택의 런-경계 영속은 V3-3** 필요
  (affinity_store에 선택 결과 저장 키 추가). 매 진입/전환에 reconcile이 affinity_state에서 재도출(로드아웃 영속 의존 금지).
- **Lazy Applied-Key 트랩:** resolve 후 `_invalidate_current_loadout_cache()` 안 부르면
  `_apply_current_loadout`가 `_applied_loadout_key != ""`에 early-return → 새 스킬 영영 안 올라감.
- 기존 세이브 펫(active_skill_id 보유) = `normalize_active_skill_id`로 유지(no-skill 변경은 신규 해치만,
  forward-only). 이미 배정된 펫은 재롤 안 됨(`ensure_pet_loadout` 저장본 반환).

---

## §6 코드 배선 슬라이스

**신규/주요 터치:**
1. **`lingpet_egg_runtime.gd`** — `_reconcile_unlock_choices(owner)` 신규. **`_apply_current_loadout`의
   `_pet_id==""` 가드 직후 = 첫 줄**(:1430~ early-return :1436/:1441 **위**)에서 호출 — 그렇지 않으면
   레벨업 후 reflect 경로(`_sync_owner`가 key=="" 일 때만 재적용, :977-978)에서 영영 안 돌아 pending이
   미해결로 남음. **비용 게이트는 boolean reward counts(`get_cumulative_rewards`)로**, deep-copy하는
   `get_pending_unlock_choices`(:221) 매프레임 호출 금지. mid-rally 레벨업은 **다음 update에 1프레임 지연**
   반영(`_add_affinity_points`는 :2244에서 캐시 invalidate만 함). 해치 콜 `:946`은 no-skill(빈 액티브)로.
2. **no-skill-at-hatch — 재주입 4컷 (v1.1: 3 → 4):**
   - 해치 로드아웃 빌더 빈 액티브 emit — `pick_skill_loadout`/`build_default_loadout`에 "스킬 없음" 분기
     (`active_skill_ids:[]`, `active_skill_id:""`) 또는 `ensure_pet_loadout` 액티브 스킵.
   - `current_profile._apply_default_loadout_if_needed`(:300-309) pool[0] 재주입 **게이트**.
   - `loadout_state._normalize_loadout` fill_missing(:290-297) 재주입 **게이트**.
   - **(v1.1 신규) `LingpetCatalog.get_active_skill(pet,"",lvl)` 빈-id 폴백→pool[0]**(catalog:1047-1049):
     빈 id면 `{}` 반환하도록 게이트, **또는** `_get_current_active_skill()`/스냅샷 빌더가 `get_skill_id(0)==""`
     를 no-skill로 보고 빈 스킬 필드 emit(`get_active_skill` 호출 전). 안 하면 빈 로드아웃이어도
     레일/TAB가 pool[0]을 "장착됨"으로 표시 → 미해금(D11) 안 나옴. **스모크는 스냅샷
     (`companion_skill_id==""`)에 단언**(로드아웃 배열만 보면 버그가 green으로 통과).
3. **`lingpet_catalog.gd`** — 루미온 단일 `active_skill`(:468-479) → `active_skill_pool`(D8). solar_bolt
   엔트리: **`runtime_kind:"solar_bolt"`**(REQUIRED_ACTIVE_SKILL_KEYS — 누락 시 `_validate_active_skill_data`
   헤드리스 실패), name "천둥 낙뢰", cooldown 22, refire_chance_pct 50, **card_texture_path = 임시
   thunder_orb 재사용**(검증은 path 존재만 보고 uniqueness/중복-id 미검사 → 안전), icon은 선택. 단일
   `active_skill` 키를 풀로 옮길 때 stale `active_skill` 잔존 금지(양쪽 이중 검증). 1-엔트리 풀 펫 D6 경로.
4b. **`lingpet_affinity_state.gd` 신규 API** — `resolve_single_unlock(pet,type,only_id)`(D6): unlocked 플래그
   + `resolved_unlock_choices[key]={selected:only_id, rejected:[], candidates:[only_id]}` 직접 기록(pending
   없음, ≥2 우회). 1-엔트리 풀 펫의 유일 해금 경로.
4. **레일/TAB 미해금 표기(D11)** — `lingpet_rail_card`/`character_info_overlay_lingpet_presenter`가 빈
   active id에 "미해금/없음" 렌더(공백 방지).
5. **QA 디버그 오버라이드 + F7 충돌(D5/D10, v1.1):** F7 `debug_grant_and_activate_pet`는 `:451`
   set_pet_loadout(강제 스킬) → `:455` 헤드스타트(unlock 카드 award + pending 기록) → `:456`
   `_apply_current_loadout(true,true)` 순. reconcile이 apply에 걸리면 **방금 기록된 pending을
   candidates[0]로 자동해결해 F7 강제 스킬을 덮어씀.** → **일회성 `_skip_unlock_reconcile` 플래그**를
   debug_grant가 세팅(apply 후 클리어)하거나, 명시적 디버그 오버라이드 시 reconcile no-op. 또한 이 플래그가
   QA가 임시 자동선택을 특정 후보(solar_bolt)로 강제하는 통로도 됨(두 후보 인게임 검증). S10은 **F7 강제 id가
   헤드스타트+apply 후에도 생존**(solar_bolt 강제 → update 후 slot0==solar_bolt)을 단언.

**reconcile 의사코드:**
```gdscript
func _reconcile_unlock_choices(owner) -> void:
    var pet := _pet_id
    _seed_unlock_candidates(pet)                     # D3, 멱등
    var pending := _affinity.get_pending_unlock_choices(pet)
    for key in pending:                              # D5 임시 자동선택
        var cands: Array = pending[key]["candidates"]
        if cands.size() >= 1:
            _affinity.choose_skill_unlock(pet, pending[key]["type"], _auto_pick(cands))  # candidates[0] or debug override
    var resolved := _affinity.get_resolved_unlock_choices(pet)
    var active_id := str(resolved.get("active", {}).get("selected", ""))
    var passive_id := str(resolved.get("passive", {}).get("selected", ""))
    # (v1.1) 2nd id는 affinity 플래그로만 기록 — 로드아웃 slot-1엔 절대 안 씀(D9).
    # 2슬롯 런타임이 LIVE라 id를 쓰면 Lv.22 즉시 발동 + 안전가드 미완(소프트락).
    if _loadout_differs(active_id, passive_id):
        _loadout_state.set_pet_loadout(owner, pet, active_id, passive_id, ...,
            second_active_skill_id="", second_passive_skill_id="")   # slot-1 비움
        _invalidate_current_loadout_cache()
        _apply_current_loadout(owner, true, false)
```

---

## §7 자산

| 자산 | 상태 |
|---|---|
| solar_bolt 카드/아이콘 | **임시 = thunder_orb 재사용**(`_validate_active_skill` 통과용). step-3 금색 imagegen 슬라이스에서 스왑 |
| "미해금" 표기 | 텍스트/기존 UI 재사용(신규 자산 불요) |
| 2중1 피커 UI | **이 슬라이스 범위 아님**(V3-2c-UI 후속) |

---

## §8 스모크 브리프 `lingpet_unlock_loadout_v3_2c_smoke.gd`

| ID | 단언 |
|---|---|
| S1 | 해치 직후 `active_skill_ids` 빈 + **스냅샷 `companion_skill_id==""`/`companion_skill_name==""`**(pool[0] 폴백 안 뜸) + 패시브 빈. **변이: best_level≥3** → 헤드스타트로 해치 시 이미 active 해금(no-skill 윈도우 = first-hatch best<3 한정) |
| S2 | Lv.1 도달 → active pending(후보=펫 풀 ids, **합성 _a/_b 아님**) → 자동선택 → 로드아웃 slot0 = candidates[0], 캐스트 가능 |
| S3 | Lv.2 도달 → passive pending(후보=공용풀 시드 랜덤 2) → 자동선택 → passive 채움 |
| S4 | 패시브 후보 **펫별 결정론적**(같은 펫 반복 호출 동일 2개), 2nd 패시브가 첫 패시브 selected 제외 |
| S5 | 1-엔트리 풀 펫 **(nekuring + milkring)** → `resolve_single_unlock` 직접 해결: `selected`==실제 카탈로그 id(합성 `_a/_b` X, `invalid_selection` X), `active_unlocked` + 로드아웃 채움 |
| S6 | 펫 전환 → reconcile가 **활성 펫의** resolved에서 슬롯 재도출(per-pet 격리) |
| S7 | 기존 세이브 펫(active_skill_id 보유) 로드 → 유지(재롤 X), normalize 통과 |
| S8 | **(v1.1 정정) Lazy 트랩 — 스킬 랜딩엔 redundant:** reconcile이 `true` 반환 → `_applied_loadout_key!=""` early-return 우회 + owner 키도 `set_pet_loadout→sync_owner`로 세팅돼 invalidate 없이도 스킬 랜딩. invalidate는 **스냅샷 last-pushed 캐시(egg:1610-1617)** 전용 → S8은 그 캐시 stale-vs-rebase를 단언(스킬 랜딩 아님). 또는 S8-seals-Lazy 주장 철회 |
| S9 | 새 owner 키 0(schema-gated owner 라운드트립) |
| S10 | F7 debug-grant(solar_bolt 강제) → 헤드스타트+apply(reconcile) 후에도 **slot0==solar_bolt 생존**(`_skip_unlock_reconcile`로 자동선택이 안 덮음) |
| S11 | Lv.22+ 2nd 액티브 unlock **플래그만** → `active_skill_ids` 길이 1 + `_get_active_slot_count()==1` + `get_skill_id(1)==""` + `_is_second_active_slot_enabled` **false**(slot-1 미발동). Lv.25+ 2nd 패시브도 `get_passive_skill_ids` 길이 1 |
| S12 | no-skill 컴패니언(first-hatch Lv.1 전) → 존재·패트롤 O·자동캐스트 X·**스냅샷 빈 스킬 필드**·레일 "미해금" 표기, 크래시 X |

- 스키마-게이트 owner(`BattleSceneState` 위임) 사용 — plain dict FakeOwner 금지.
- **§13-10(line 1017-1020) 하드 체크 — V3 모델로 재작성(verbatim 복구 금지, v1.1):** 미뤘던 3개
  프로파일-합성 assertion은 OLD 자동-레벨 모델(Lv.1 후 active level==2, Lv.2 후 passive==2, boosted Lv.13)
  을 기대했음. V3에선 **Lv.1=active_unlock(레벨 +1 없음 → 효과 active level 1 유지)**, 첫 ACTIVE_SKILL +1은
  **Lv.5(canonical)**, 효과레벨=base+bonus, boosted fixture는 **현 커브상 Lv.12**(13 아님, smoke:4274). 현
  커브에 맞춰 재도출, HEAD 버전 붙여넣기 금지.

---

## §9 트랩 체크리스트

- [ ] **Lazy Applied-Key 재적용 트랩(최우선):** resolve→`_invalidate_current_loadout_cache`→apply.
  미invalidate 시 `_applied_loadout_key!=""` early-return으로 새 스킬 영영 안 올라감. **봉인 S8.**
  ([[feedback_godot_dynamic_set_payload_guard]] 인접)
- [ ] **합성 후보 폴백 오염:** unlock award 전(또는 자동선택 전) `set_unlock_choice_candidates` 시딩 필수,
  안 그러면 `<pet>_<key>_a/_b` 가짜 id. **봉인 S2.**
- [ ] **Owner-Field Schema:** 기존 키 재사용, 새 키 0. "미해금"도 빈 id 파생. **봉인 S9.**
- [ ] **휘발성 세이브:** 로드아웃 미영속 → 매 진입 affinity_state에서 재도출, 로드아웃 영속 가정 금지.
  **봉인 S6/S7.**
- [ ] **결정론(시드):** 패시브 후보 `hash(pet_id)` 시드, `Math.random`/`Time` 금지. **봉인 S4.**
- [ ] **1-엔트리 풀:** `set_unlock_choice_candidates` <2 silent return → 단일-후보 직접 해결. **봉인 S5.**
- [ ] **per-pet 격리:** 전환 시 활성 펫 resolved만. **봉인 S6.**
- [ ] **deferred 프로파일-합성 assertion 복구:** §13-10 line 1017-1020. **하드 체크리스트.**
- [ ] **자산 검증:** solar_bolt 임시 카드/아이콘이 `_validate_active_skill` 통과(헤드리스 로드).
- [ ] **2nd 패시브 효과레벨 GAP:** `current_profile.gd:338` 헬퍼 부재 — 이 슬라이스는 1st만 완전, 2nd 패시브
  레벨은 V3-2b/후속(명시).
- [ ] **(v1.1) 4번째 no-skill 재주입:** `get_active_skill(pet,"",lvl)` pool[0] 폴백(catalog:1047) →
  스냅샷이 pool[0] 표시. 게이트 + **스냅샷 단언**. **봉인 S1/S12.**
- [ ] **(v1.1) slot-1 미발동 가드:** 2슬롯 런타임 LIVE + 안전가드 미완 → reconcile이 `second_*_id` 절대 안 씀,
  slot-1 빈 채로 게이트 false. **봉인 S11.**
- [ ] **(v1.1) 1-엔트리 단일 해금:** `resolve_single_unlock` 신규 API 없으면 영영 해금 불가. **봉인 S5.**
- [ ] **(v1.1) reconcile 배치:** `_apply_current_loadout` 첫 줄(early-return 위), 비용은 boolean count로 게이트.
- [ ] **(v1.1) F7 충돌:** `_skip_unlock_reconcile`로 디버그 강제 스킬 보호. **봉인 S10.**

---

## §10 완료 결정 / 오픈

**확정:** D1~D11 + Q1/Q2.

**스코프 밖(후속):**
- **V3-2c-UI** — 비모달 2중1 피커(TAB/플라자), 임시 자동선택 대체.
- **V3-2b** — 2 액티브 동시 발동 런타임(slot-1 캐스트/쿨다운/HUD) + 2nd 패시브 효과레벨 헬퍼.
- **자산(step-3)** — solar_bolt 금색 카드/아이콘 imagegen + 네이밍 디컨플릭트(천둥 뇌구↔낙뢰) + 임시 placeholder 스왑.
- **V3-6** — 요구치/쿨타임/클릭 수치 튜닝(12스테이지 풀런 기준).

**오픈(착수 시 확인):**
1. 1-엔트리 풀 펫(milkring/volty): 단일-후보 직접 해결 vs 풀 백필 2 — 권장 직접 해결(콘텐츠 작업 0).
2. 임시 자동선택 = candidates[0](pool 순서) — 루미온은 thunder_orb 자동픽. QA는 디버그로 solar_bolt 강제.
3. "미해금" 표기 문구/위치(레일/TAB) — 기존 UI 톤 따름.

---

## 부록 — 핵심 코드 앵커 (스카우트 확정)

| 항목 | file:line |
|---|---|
| 해치 스킬 배정 | `lingpet_egg_runtime.gd:946` `_apply_current_loadout(owner,true,true)` |
| 랜덤픽 | `lingpet_loadout_state.gd:100` → `lingpet_catalog.pick_skill_loadout:1134` → `_pick_skill_from_pool:1515` |
| pool[0] 재주입 | `current_profile.gd:300-309` / `loadout_state.gd:290-297` |
| 빈 id 안전 처리 | `egg_runtime.gd:1784` `if skill_id=="": continue` / controller arm / dispatcher `SKILL_KIND_NONE` |
| resolved 쓰기 | `loadout_state.set_pet_loadout:109` → `egg_runtime._invalidate_current_loadout_cache:1449` → `_apply_current_loadout:1429` |
| 2중1 백엔드 | `affinity_state.gd:203/221/229/237` (seed/pending/resolved/choose) |
| 효과레벨 | `current_profile.gd:333-339` (active slot0/1 OK, 2nd passive 부재) |
| 루미온 카탈로그 | `lingpet_catalog.gd:468-479` (단일 active_skill → 풀 전환) |
| 합성 폴백 | `affinity_state.gd:964` `_default_unlock_candidates` |
| 휘발 세이브 | `lingpet_save_store.gd` clear_snapshot / 영구 = `lingpet_affinity_store.gd`(best_level+bond만) |
| 2슬롯 런타임 LIVE | `egg_runtime.gd:1328` `_is_second_active_slot_enabled` / smoke 4381-4405 |
| get_active_skill 빈-id 폴백 | `lingpet_catalog.gd:1047-1049` (pool[0]) |
| reconcile 배치/레벨업 invalidate | `egg_runtime.gd:1430-1442`(early-return) / `:2244`(level-up invalidate) / `:977-978`(sync 재적용) |
| F7 debug-grant | `egg_runtime.gd:450-456` (set_pet_loadout→headstart award→apply) |
| 헤드스타트 재award | `affinity_state.gd:354-360` (best_level 기반 매 런) |

---

## 적대적 리뷰 로그

> **2026-06-14 — 리뷰 2렌즈(코드충돌/순서 + 디자인/정확성), v1.0 → v1.1.** 적용:
> - **(must) 4번째 no-skill 재주입:** `get_active_skill(pet,"",lvl)`→pool[0](catalog:1047). 컷 3→4 + 스모크
>   스냅샷 단언(S1/S12). 안 하면 빈 로드아웃이어도 레일/TAB가 pool[0] 표시, 미해금 안 뜸.
> - **(must) 2슬롯 런타임 LIVE:** `_is_second_active_slot_enabled`(egg:1328) 살아있음 — slot-1에 id 쓰면
>   Lv.22 즉시 발동 + 안전가드 미완(소프트락). D9 재작성: 2nd unlock=플래그만, reconcile이 `second_*_id=""`.
>   §6 pseudocode에서 second 인자 제거. S11=slot-1 빈/게이트 false 단언.
> - **(must) 1-엔트리 풀 단일 해금:** 현 백엔드로 단일 id 영영 해금 불가(`choose_skill_unlock`=invalid_selection).
>   신규 `resolve_single_unlock` API(§6 4b). 센서스 정정 = milkring+nekuring(volty 아님). S5 두 펫 단언.
> - **(should) §5 영속 거짓:** resolved는 in-memory(affinity_store는 best_level+bond만), 헤드스타트 재award로
>   런-경계 재도출. 진짜 2중1 영속=V3-3. §5 reword.
> - **(should) reconcile 배치:** `_apply_current_loadout` 첫 줄(early-return 위), boolean count로 비용 게이트,
>   mid-rally 레벨업 1프레임 지연.
> - **(should) F7 충돌:** `_skip_unlock_reconcile` 플래그로 디버그 강제 스킬 보호. S10 재정의.
> - **(should) solar_bolt `runtime_kind` 누락:** REQUIRED_ACTIVE_SKILL_KEYS — 추가(§6 #3). 카드 path 재사용은
>   uniqueness 미검사라 안전, icon 선택.
> - **(should) deferred assertion = V3 모델 재작성:** Lv.1=unlock만(레벨 유지), 첫 +1 Lv.5, boosted Lv.12. verbatim 금지.
> - **(note 검증):** 공용 패시브풀 5엔트리 → 2nd 제외 후 2 OK / `hash(pet_id)` 결정론(덱 seed와 별개) /
>   cap fail-open=MAX라 V3-3 의존 없이 지금 테스트 가능 / 피커 제거 시 pending이 펫을 skill-less로 방치(임시
>   자동선택을 failsafe로 유지).

> **2026-06-14 — 구현 리뷰 3렌즈(스모크-씰 + 정확성/트랩 + 누수/회귀), v1.1 배선 검증.**
> - **ObjectDB 누수 = 양성(테스트-로컬), 런타임 순환 아님 (실증):** RefCounted 1개·refcount **0**(순환이면
>   ≥2개 refcount≥1), 50사이클에도 1개(bounded), reconcile/resolve_single_unlock이 람다·시그널·역참조 0개
>   추가. 원인 = `LingpetSkillRuntimeHost.reset()`가 lazy skill 모듈 멤버를 null 안 함 → SceneTree 종료 시
>   1개 orphan. **매 전투 누수 없음.** 선택적: 테스트 cleanup에서 멤버 null(`dispose()`).
> - **(must-BLOCKER) S10 RED — F7 보호 깨짐:** `_skip_unlock_reconcile`가 **one-shot**(egg:1451-1452 매
>   apply마다 소비+false). debug_grant(:461)가 즉시 소비 → Lv.1 update()의 reconcile이 강제 solar_bolt를
>   thunder_orb로 덮어씀. **V3-2c 스모크 실측 RED**(`expected lumion_solar_bolt, got lumion_thunder_orb`,
>   3/3). **무빙 HEAD**: 커밋 `a49f51f21`(플라자, V3-2c 무관)이 egg_runtime을 건드림 + uncommitted WIP →
>   사용자 통과 보고 이후 변형. **수정: 플래그를 sticky**(egg:1452 매-apply 리셋 제거, 펫전환 :554에서만
>   클리어). [[project_godot_wip_branch_moving_head]] — git 상태 재스냅샷 필요.
> - **(must) deferred 프로파일-합성 assertion = `pass` 스텁**(egg_runtime_smoke:4914-4915, 호출
>   :4250/:4276/:4341) — §13-10 HARD CHECK 위반, V3 커브→효과레벨 커버리지 0. **재작성**: Lv.1 효과
>   active level==1(unlock만), 첫 +1 Lv.5, boosted Lv.12. 스텁 삭제. (합성 픽스처는 보상 직접 주입이라 커브 우회 — 대체 불가.)
> - **(should) S8 redundant:** 위 §8 정정 — invalidate는 스냅샷 캐시 전용.
> - **(should) plain-dict FakeOwner 사용** — §8 위반. schema-gated owner(BattleSceneState 위임)로 S9 추가.
> - **(should) S6/S7 미테스트**(펫전환 격리·세이브 비재롤) / **S2 cast 가능 미검증**(owner id만, arm/dispatch 미확인).
> - **(should) stale 레거시 `active_skill` 키 잔존** — 루미온(:469-480)+milkring이 `active_skill_pool`과
>   공존(slice §6#3 "잔존 금지" 위반). 풀이 우선이라 런타임 무해하나 dead data+이중검증 → 레거시 키 제거.
> - **(note):** S11은 위험 변이(distinct 2nd skill)를 transitive로 잡음(slot_count==1) — 직접
>   `_is_second_active_slot_enabled()==false` 단언 추가 권장. get_active_skill 빈-id 게이트는 end-to-end 정상(소비자 `.get()` 안전).

> **2026-06-14 (2차 재검증) — 두 must-fix 봉인, 단 sticky 수정이 반복 클로버됨.**
> - **must-fix B(deferred assertion):** SEALED — `_defer_v3_profile_synthesis_assertions` 스텁 grep **0건**,
>   V3 모델 단언으로 교체됨(Lv.1 unlock만/Lv.5 첫+1/Lv.12 boosted).
> - **must-fix A(sticky 플래그):** 현 트리에서 **또 one-shot으로 되돌아가 있었음**(egg:462
>   `_skip_unlock_reconcile = false`가 debug apply 직후 즉시 클리어). V3-2c 스모크 **RED 실측**(3회째 동일
>   회귀). egg:462의 그 한 줄을 제거(sticky = 펫전환 :555/빈-펫 :1470에서만 클리어)하니 스모크 **GREEN 실증**.
> - **무빙 HEAD 원인:** 세션 중 플라자 커밋 다수 landing(`a49f51f21`→`f241f66b0`→`e11b15408`) + egg_runtime.gd가
>   uncommitted `M`이라, 사용자의 sticky 수정이 외부 커밋/버퍼 overwrite로 **3회 reverted**. 
> - **잠금 필요:** V3-2c 파일(egg_runtime.gd sticky + egg_runtime_smoke.gd assertion + untracked v3_2c smoke)을
>   **커밋해 고정**하지 않으면 또 클로버됨. 무관 WIP 섞임 주의(스코프 커밋). [[project_godot_wip_branch_moving_head]]
> - leak = 양성(테스트-로컬, bounded) 재확인 — 런타임 fix 불요.
