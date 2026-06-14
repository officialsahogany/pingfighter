# V3-2b — 링펫 2번째 액티브 슬롯 런타임 (발동/쿨다운 실사용)

친밀도 시스템 v3 (§13, `docs/lingpet_affinity_system_plan.md`)의 V3-2b 슬라이스.
**범위 = 런타임이 2번째 액티브 슬롯을 실제로 발동/쿨다운/렌더하게 만드는 것.**
데이터 모델(V3-2a)·친밀도 상태(V3-1)는 봉인됨; 이 슬라이스는 그 위에 런타임을 올린다.

분담: **디자인 노트/신호 계약/트랩/smoke = Claude (이 문서). GDScript 배선 = 사용자.
적대적 리뷰 = Claude.** 코드 자동 작성 금지(분담 패턴 `feedback-design-slice-review-division`).

근거: 14-에이전트 워크플로(현재 단일-슬롯 런타임 정밀 매핑 + 5 설계 차원 + 22 적대 트랩),
2026-06-14. 라인 번호는 워크플로 시점 스냅샷이라 배선 전 grep 재확인.

---

## 0. 경계 (V3-2b가 하는 것 / 미루는 것)

| 슬라이스 | 책임 |
|---|---|
| **V3-2b (이 문서)** | 2 skill_state 인스턴스, slot-indexed 발동 경로, resource-class 충돌 중재, per-slot 쿨다운/windup/save-load, prewarm 둘 다, unlock 게이트, draw cast-pose 슬롯 선택, owner `_second_skill_*` 키 **존재 + 라이브 값** |
| V3-2c | 부화 2-of-1 선택 → slot-1 점유 결정 (어떤 스킬이 slot 1에 들어갈지). V3-2b 키를 소비, 신규 스키마 없음 |
| V3-2d | TAB/HUD slot-1 행 **draw 레이아웃** (V3-2b가 노출한 `_second_skill_*` 키의 순수 reader) |

핵심: V3-2b는 slot-1 키가 **존재하고 올바른 라이브 값을 운반**하게 만들어, 2c/2d가 안정 계약 위에서 작업하게 한다.

---

## 1. 아키텍처 결정 (5 차원 verdict)

### 1.1 컨트롤러/호스트는 거의 그대로, egg_runtime이 슬롯 루프
- `lingpet_companion_skill_controller`는 **stateless 순수 결정 함수** — 모든 상태를 `params.skill_state`에서 읽음. **1 인스턴스, 슬롯당 1회 호출**. 시그니처 불변 (slot_index 안 넣음 — 호출자가 올바른 state 객체를 넘김으로써 슬롯 선택). 2 컨트롤러 인스턴스 = 순수 중복, **기각**.
- `lingpet_skill_runtime_host`는 이미 **skill_kind별 멀티-스킬 레지스트리**(17 모듈, kind 키). `update`/`launch`/`can_arm`/`is_launch_blocked`/`has_companion_position_override` 전부 skill_id 디스패치라 2슬롯에 그대로 구성됨. **1 호스트** (2 호스트 = 17 lazy 캐시 중복, **기각**). 호스트 변경은 **추가 2개뿐**: ① `get_active_position_override_owner`(아래 1.4), ② `would_share_module`(아래 1.5).
- `lingpet_egg_runtime._update_companion_skill_effects`가 **THE 통합 지점**: `for slot in range(_get_active_slot_count())` 루프, 슬롯별 params 빌드, 컨트롤러 1회 호출, ARM/LAUNCH 분기.

### 1.2 per-slot 상태 = 2 LingpetCompanionSkillState 인스턴스 (eager)
- `_companion_skill_state` (단일) → `_companion_skill_states := [State.new(), State.new()]` **둘 다 field-init에서 즉시 생성**. 상태 객체는 무거운 리소스 0(순수 RefCounted 값 가방)이라 eager 생성 **무료** + Hot-Path Lazy Init 트랩과 무관(그 트랩은 호스트의 스킬 모듈/512px 시트 — 이미 prewarm으로 완화).
- **per-slot 독립**: cooldown / windup_active / windup_elapsed / flash_timer / origin. slot-0 launch가 slot-1을 쿨다운시키면 안 되고, slot-0 windup이 slot-1 arm을 막으면 안 됨 — **별개 객체라 자동 보장**(controller `_should_arm`이 넘겨받은 state의 자기 필드만 검사).
- **`scalar→array[2]` 한 객체 안 변환은 기각**: 모든 메서드 본문 + 모든 호출부 필드 접근을 재작성 → 회귀면 폭증. 2 객체는 메서드 본문을 바이트-동일하게 유지하는 최소 diff.
- **예외 — `trigger_count`는 pet-shared 유지**: 모션 patrol seed로 소비됨(`_companion_motion_state.update`/`resume_sortie_loiter`/`initialize`). per-slot로 쪼개면 "마지막 발동 슬롯"에 따라 patrol seeding이 갈라짐. 둘 중 어느 슬롯 발동이든 **단일 공유 카운터**를 증가. 스냅샷 root에 1개.

### 1.3 발동 정책 = 클래스 인지 상호배제 + slot-0 우선
모든 skill_id를 `resource_class`로 분류(실제 writer를 grep해서 도출, 이름 추론 금지):

| class | skill_ids | 단일 소유 자원 |
|---|---|---|
| **BALL_OWNER** | hydro_sphere, wild_roar, solar_bolt, ghost_summon | `skip_ball_motion_step`, `ball_vel` |
| **POS_OVERRIDE** | headbutt, bomb_surprise, gatling_burst, puppet_grab, doll_curse, banana_slice, wild_roar | `_companion_pos` |
| **FREE** | moon_orbit, bubble_trap, milk_production, thunder_orb, dragon_breath, dragon_wing, soul_clone | 없음 |

> **wild_roar는 BALL_OWNER ∩ POS_OVERRIDE 둘 다.** 분류는 **set membership**, 게이트는 **set intersection(클래스 교집합)** 체크 — 단일-클래스 동등 비교면 wild_roar가 under-protect됨.

중재 규칙 (**ARM/windup edge에서, launch 아님**):
- 한 슬롯은 자기가 필요로 하는 exclusive 클래스를 **다른 슬롯이 현재 보유**(windup-or-active)하면 ARM 불가.
- **FREE × anything = 동시 가능** (FREE는 단일 소유 자원 미접촉).
- **같은 클래스(또는 교집합) = 상호배제, slot-0 우선.** 같은 프레임 동시 적격이면 slot 0가 ARM, slot 1은 NONE 반환 후 다음 프레임 재평가. **패배 슬롯은 취소/쿨다운 소모 안 됨** — 그냥 대기(`_should_arm`이 이미 막힐 때 NONE 반환하는 것과 동일).
- **WINDUP edge에서 게이트하는 이유**: position-override write가 windup 중 발생, owned-ball handoff가 launch에서 발생. Chaos-Spear 교훈 = 양 state machine을 진행시키고 늦게 해소하면 stuck flag 남음. arm에서 막으면 패배자가 공유 자원을 아예 안 건드려 unwind할 게 없음.

### 1.4 position-override 단일 owner query
`_companion_pos`는 **단일 필드 유지**(몸은 하나 — 2 위치 물리적으로 무의미). 호스트에 신규
`get_active_position_override_owner(slot_skill_ids: Array, fallback: Vector2) -> {has, skill_id, slot_index, pos}`:
순서대로 스캔, 첫 `has_companion_position_override`=true 반환(slot 0 우선). **launch-time apply + draw-side walk/idle gate + body-hit + visibility 전부 이 단일 primitive 소비** → write와 gate가 같은 owning skill을 참조(불일치 불가). 기존 scalar `has_companion_position_override(skill_id)`는 유지(신규 메서드가 위임), ring_dash/starlight 등 기존 callsite 무손상.

### 1.5 같은 skill_kind 이중장착 방어
호스트는 **skill_KIND별 모듈 1개** 캐시(skill_id 아님). `get_skill_kind`은 many-to-one(카탈로그 runtime-kind가 여러 id를 한 kind로). 두 슬롯이 같은 kind면 **같은 stateful 인스턴스 공유 → 손상**(예: ghost_summon `launch()`가 첫 줄에서 `reset()` → 트윈의 in-flight ghosts/`_saved_ball_vel` 소거 → 잡힌 공이 ZERO로 release). 신규 `would_share_module(a, b) := get_skill_kind(a)==get_skill_kind(b) and kind!=NONE`; `_get_active_slot_count()`이 같은 kind면 **slot 1을 빈 것으로 취급(count=1)**. (진짜 per-(kind,slot) 캐싱은 미래 동일-패밀리 동시장착이 필요할 때의 큰 작업으로 유예.)

### 1.6 unlock 게이트 = AND (현재 런타임에 게이트 0개)
> grep `second_active_unlocked|second_active_skill` in egg_runtime = **0 매치**. 런타임 스킬 경로에 친밀도 읽기가 **전혀 없음** — unlock은 현재 순전히 데이터/owner-스키마 개념(V3-2a). 게이트를 **처음부터 추가**해야 함.

slot-1 적격 = **두 독립 사실의 논리 AND**:
- (a) `_current_profile.affinity_rewards.second_active_unlocked == true` — **캐시된 invalidation-gated 프로파일에서** 읽음 (fresh `get_cumulative_rewards` 아님, owner mirror 아님).
- (b) `active_slot_count >= 2 AND active_skill_ids[1] != ""` (장착 존재).

둘 중 하나라도 false면 slot-1 루프 iteration을 `continue`(controller.update 전 — 모듈 인스턴스화 0, phantom arm 0). **한쪽만 게이트하면 누수**: 로드아웃이 이전 unlock/마이그레이션/디버그로 slot-1 id를 운반하는데 라이브 친밀도가 Lv.22 미만인 경우(예: 갓 교체된 벤치 펫) slot 1이 Lv.22 전 발동.

### 1.7 owner/HUD 노출 (2 surface, 둘 다 필요)
| surface | 키 | 생산자 | 소비자 |
|---|---|---|---|
| INTERNAL snapshot (un-prefixed `companion_skill_*`) | `companion_skill_cooldown_1`/`_ready_1`/`_winding_up_1`/`_flash_ratio_1`/`_id_1`/`_name_1` | `LingpetCompanionSkillState.get_snapshot(slot_suffix)` | HUD rail card |
| OWNER 스키마 (`lingpet_*`+`ringpet_*` 페어) | `lingpet_/ringpet_second_skill_cooldown`/`_cooldown_duration`/`_ready`/`_winding_up`/`_windup_ratio`/`_id`/`_name`/`_max_level` | `_sync_second_skill_owner` (신규, `_sync_skill_owner` 미러) | TAB 패널 (V3-2d) |

- 모든 신규 owner 키는 **`lingpet_/ringpet_` 페어로 `battle_scene_state.DEFAULT_VALUES`에 선언** — 미선언 set()은 silent no-op(Owner-Field Schema Trap), 페어 fallback이 단일-키 누락을 가림. 구조 봉인 `_verify_snapshot_sync_keys_are_schema_declared`가 미선언 set 리터럴을 빌드에서 실패시킴(forcing function).
- windup은 **미리 계산된 0..1 `_windup_ratio`로 노출**(raw elapsed 아님 — 소비자가 per-slot windup_seconds 재나눗셈/0-나눗셈 안 하게).
- slot 1이 locked/empty면 모든 `_second_*` 키가 **스키마 기본값(""/0.0/false) sync** → 패널/HUD가 행을 깨끗이 숨김(slot-0의 companion_active=false 패턴과 동일).
- `get_snapshot(slot_suffix="")`: suffix=""는 오늘의 bare 키 유지(HUD/TAB back-compat), "_1"은 `_1` 패밀리.
- **`last_gain`/`trigger_count`의 slot-1 페어는 실 consumer가 읽을 때만 선언**(현재 rail card/TAB builder는 안 읽음 — dead data 금지). V3-2d 확정 후 결정.

---

## 2. 신호 계약 (심볼별)

| 심볼 | 종류 | 계약 |
|---|---|---|
| `_companion_skill_states` | state_field | egg_runtime: 정확히 2개 `LingpetCompanionSkillState`, field-init eager. [0]=주, [1]=2번째. lazy 생성 금지. 모든 reset/advance가 둘 다 loop; 컨트롤러는 슬롯당 `_companion_skill_states[slot]` 전달. |
| `_companion_skill_trigger_count` | state_field | **pet-shared 스칼라** (per-slot 아님). 어느 슬롯 launch 성공이든 증가. patrol seed로 소비. 스냅샷 root에 1개. 비대칭(쿨다운=per-slot, trigger=shared)을 **필드에 주석** + smoke로 봉인. |
| `_get_active_slot_count()` | method (신규) | 2 반환 조건: `second_active_unlocked` AND `second_active_skill_id != ""` AND NOT `would_share_module(slot0, slot1)`. 아니면 1. update/arm/launch/prewarm 루프 bound. |
| `_get_skill_id_for_slot(slot)` | method (신규) | slot 0 = `_current_profile.get_skill_id()`(불변). slot 1 = profile second_active_skill_id, locked면 "". 형제 `_get_active_skill_for_slot`/`_get_skill_windup_seconds_for_slot` 동일 패턴. |
| `resource_class` | catalog/dispatcher | skill_id → {BALL_OWNER, POS_OVERRIDE, FREE} **집합** 분류. 실제 writer(`owner.set("ball_vel")`/`skip_ball_motion_step`/`has_companion_position_override`)에서 도출, callsite마다 재타이핑 금지. arm-gate가 읽는 단일 소스. |
| `would_share_module(a, b)` | method (신규, host or dispatcher static) | `get_skill_kind(a)==get_skill_kind(b) and kind!=NONE`. true면 egg_runtime이 slot 1을 빈 것 취급. |
| `get_active_position_override_owner(ids, fallback)` | method (신규, host) | `{has, skill_id, slot_index, pos}`. 순서 스캔 첫 override-owner(slot 0 우선). launch apply + draw walk-ratio/visibility/hit gate 전부 소비. |
| `_should_arm` | method | 시그니처 불변. 넘겨받은 slot state의 자기 windup_active/cooldown + host.can_arm/is_launch_blocked만 검사. **신규 cross-slot exclusive-resource 게이트**가 egg_runtime 루프에서 추가(컨트롤러 안 아님). per-slot windup 독립은 별개 state로 자동. |
| `is_launch_blocked` | method | **per-skill_id 유지** — 같은 mid-sequence 스킬 재-arm 차단 전용. **cross-slot 권위 아님**(다른 슬롯 스킬 arm을 못 막음). slot 중재에 의존 금지. |
| `_update_companion_skill_effects` | method | 슬롯 루프 + 게이트 지점. slot 0 먼저 평가·**커밋**, 그 다음 slot 1을 slot-0의 갱신된 라이브 상태에 대해 평가(프레임-시작 스냅샷 아님 — §3 트랩 #6). 루프 후 override를 **1회** apply(단일 owner query). unlock AND로 slot-1 게이트. |
| `_launch_companion_skill(owner, registry, slot)` | method | slot 파라미터 추가. launch_context dict와 cooldown을 **그 슬롯의** active-skill dict에서 빌드(slot-0 dict 아님). slot-1 effective level을 slot-0와 같은 `_get_effective_active_skill_level`/passive-reduction 경로로. |
| `_prewarm_current_skill_runtime` | method | both-slots 루프: `for slot in range(_get_active_slot_count()): host.prewarm(_get_skill_id_for_slot(slot))`. 같은 boot/loadout-apply 사이트. |
| `_build_loadout_key` | method | **이미** slot-1 폴드됨(active_skill_ids/levels/active_slot_count + affinity reward signature가 unlock 인코딩) — V3-2a/V3-1 완료, **신규 작업 없음**. 단 모든 slot-1 mutation 경로가 `_invalidate_current_loadout_cache()` 호출해야 early-return(1283) 우회(Lazy Applied-Key 트랩). |
| `second_active_unlocked` | state_field | `_current_profile.affinity_rewards` bool, Lv.22 reward. slot-1 ticking + `_second_*` owner write 게이트. 캐시 프로파일에서만 읽음. |
| `get_snapshot(slot_suffix="")` | method | optional suffix. ""=bare 키(back-compat), "_1"=`_1` 패밀리. |
| `_sync_second_skill_owner` | method (신규, snapshot_builder) | `_sync_skill_owner` 미러, `lingpet_/ringpet_second_skill_*` 페어를 change-gated `_set_pair`로. `second_active_unlocked`일 때만, 아니면 스키마 기본값. |
| `lingpet_/ringpet_second_skill_*` | owner_key (신규) | DEFAULT_VALUES 페어 선언. cooldown(0.0)/cooldown_duration(40.0)/ready(false)/winding_up(false)/windup_ratio(0.0)/id("")/name("")/max_level(0). origin은 owner 노출 금지(internal snapshot만 — per-tick Vector2 compare 회피). |

---

## 3. 트랩 브리프 (severity별, smoke 포함)

각 smoke는 **버그 코드에서 FAIL해야 함**(반증검증). 성공-only 페어링(두 FREE 동시 발동)은 게이트 유무와 무관히 통과 → 버그를 가림. CLAUDE.md per-frame-roll/owned-ball smoke 규율 따름: in-place 토글로 게이트 끄고 손상 재현 확인.

### BLOCKER
1. **shared single skill_state → 슬롯 붕괴** *(certain)*. slot-0 launch가 slot-1 쿨다운, slot-0 windup이 slot-1 arm 차단 → Lv.22 unlock이 장식. **Guard**: 2 eager 인스턴스. **Smoke**: slot 0 launch(쿨다운>0) 후 같은 프레임 slot_1.cooldown==0 AND can_arm()==true; slot-0 windup 중 slot-1 `_should_arm` 적격. 공유-인스턴스에서 FAIL.
2. **두 BALL_OWNER가 skip_ball_motion_step/ball_vel race** *(certain)*. 한쪽 release가 다른 쪽 hold 소거 → 영구 정지 softlock; 또는 wild_roar가 zeroed ball_vel 반사. **Guard**: arm-edge resource-class 게이트, BALL_OWNER 최대 1 보유, slot-0 우선. **Smoke**: 두 BALL_OWNER 동시 적격 → 정확히 1 arm, skip_ball_motion_step 단일 owner, 패배자 NONE, 승자 release 후 ball_vel != ZERO. 게이트 토글-off로 ball_vel ZERO 종료 확인.

### HIGH
3. **두 POS_OVERRIDE가 _companion_pos fight** *(certain)*. teleport/jitter + walk/idle gate 불일치 → 파킹 펫 treadmill. **Guard**: 단일 owner query, POS_OVERRIDE 상호배제. **Smoke**: slot0=headbutt, slot1=puppet_grab 동시 적격 → 정확히 1 보유, `_companion_pos` 멀티프레임 A↔B 진동 없음. per-slot apply에서 FAIL.
4. **within-frame 평가 순서** *(likely)*. 둘 다 프레임-시작 상태에 게이트 → 둘 다 통과 arm(간헐적 더블-arm). **Guard**: slot 0 먼저 평가·**커밋**(windup_active/owner-lock mutate), 그 다음 slot 1을 갱신 상태에 대해. **Smoke**: 같은 exclusive 클래스 동시 적격 단일 `_update` 호출 → 정확히 1 arm. 프레임-시작 게이트 구현에서 FAIL.
5. **slot-1 launch_context/effective-level이 slot-0 dict에서** *(likely)*. 잘못된 banana/clone count/쿨다운/duration, 친밀도/passive 스케일 누락. **Guard**: slot-indexed 헬퍼, slot의 dict에서 빌드. **Smoke**: slot 1에 slot 0와 다른 카탈로그 튜닝 스킬 장착·launch → applied cooldown/context가 slot-1 카탈로그값. `_get_current_active_skill()`에서 빌드하면 FAIL.
6. **reset가 slot 0만 → windup 누수** *(certain)*. mid-windup 라운드 종료 시 slot-1 windup_active 다음 라운드로 stuck → slot 1 영영 재-arm 불가 or 스테일 launch. **Guard**: reset_round/_reset_skill_runtime_transients/reset_all이 둘 다 loop. **Smoke**: slot 1 windup arm → reset_round → slot_1.windup_active==false AND cooldown 불변. index 0만 reset하는 in-place edit으로 FAIL 확인.
7. **stored cooldown advance가 flat key만 → 벤치 펫 slot-1 동결** *(certain)*. `_advance_stored_companion_skill_cooldowns`가 단일 `cooldown` mutate; 스냅샷 pet_id-only. **Guard**: 스냅샷 per-slot 중첩 `{slot_0,slot_1}`, 둘 다 감소, 레거시 flat→slot_0(slot_1 cold). **Smoke**: 벤치 스냅샷 slot_0=10/slot_1=20, 3s advance, 둘 다 감소 확인; 레거시 flat 로드→slot_0 매핑. flat-key advance에서 FAIL.
8. **lazy applied-key gate가 slot-1 변경 무시** *(certain)*. early-return(1283)이 key recompute 전 → slot-1 mutation이 `_invalidate` 없으면 무시. **Guard**: 모든 slot-1 writer가 `_invalidate_current_loadout_cache()`. **Smoke**: invalidate 없이 slot-1 id 변경·apply → 스테일 잔존(early-return이 삼킴); invalidate 후 재-apply → 신규 로드 + host.prewarm 호출.
9. **prewarm slot 0만 → slot-1 첫 발동 100ms+ hitch** *(certain)*. 512px 모듈이 첫 arm에 cold-load. **Guard**: prewarm both-slots 루프, loadout-apply 사이트. **Smoke**: slot-1 장착·apply 후 host slot-1 모듈 non-null. slot-0-only 루프에서 FAIL.
10. **unlock 게이트 부재 → slot 1이 Lv.22 전 발동** *(certain)*. 런타임에 친밀도 읽기 0. **Guard**: §1.6 AND 게이트. **Smoke**: slot-1 id 있고 `second_active_unlocked==false`인 펫 다수 프레임 → slot-1 state cooldown=0/windup=false, host가 slot-1 skill_id 디스패치 안 함; unlock 토글-true로 arm. (id 부재가 아니라 게이트가 막았음을 증명.)
11. **draw-context가 slot-0에 하드와이어 → slot-1 cast 포즈 미렌더** *(certain)*. `_draw_companion`이 slot-0 skill_id+skill_state를 builder에 전달 → slot-1 puppet/curse가 effect는 재생하나 몸은 patrol-walk. **Guard**: 프레임당 "active visual slot" 1회 결정(windup_active true OR cast_pose_progress>=0인 슬롯, slot-0 우선) → 그 슬롯 skill_id+state를 build_config에. **Smoke**: slot 0 idle, slot 1 puppet_grab mid-windup → build_config가 cast_pose_active==true + non-null cast_texture. slot-0-only에서 FAIL.
12. **walk/idle ratio gate가 slot-0 override만 → slot-1 파킹 시 treadmill** *(certain)*. **Guard**: §1.4 단일 owner query, 어느 슬롯이든 override 보유 시 `_companion_override_move_ratio` 반환. **Smoke**: slot-1 headbutt가 펫 파킹(x 고정), `_get_companion_draw_motion_speed_ratio()` ~0.0. slot-0-only gate에서 FAIL(양의 patrol ratio).
13. **wild_roar 이중 클래스 under-protect** *(likely)*. 단일-클래스 lookup이면 wild_roar+hydro_sphere 동시 windup → owned-ball 손상. **Guard**: 클래스를 **집합**으로, 게이트는 교집합 체크. **Smoke**: wild_roar + hydro_sphere 동시 적격 → 1 arm, skip_ball_motion_step 단일 owner. POS_OVERRIDE 단일-태그면 FAIL.

### MEDIUM
14. **같은 skill_kind 이중장착 → 공유 모듈 손상** *(likely)*. **Guard**: §1.5 `would_share_module`, slot 1 빈 것 취급. **Smoke**: 두 id가 같은 kind → `_get_active_slot_count()`==1, slot 1 디스patch 안 함. 가드 제거 시 FAIL.
15. **strike-animator 단일 → slot-1 strike 미렌더** *(likely)*. `_trigger_companion_skill_strike_if_requested`가 slot-0 id로만 호출 → slot-1 strike request 미소비. **Guard**: 슬롯별 호출 + 단일 animator 중재(slot-0 strike 우선). **Smoke**: slot 0 non-strike, slot 1 strike-skill request set → 1프레임 후 animator.strike_active==true. slot-0-only 호출에서 FAIL.
16. **ghost_summon owner-less cancel이 stage3_kuromi_ball_hidden 누수** *(likely)*. round cleanup이 owner=null → `_clear_owner_ball_hold` early-return → `skip_ball_motion_step`(build_common_snapshot이 정규화) 외 `stage3_kuromi_ball_hidden`은 안 지워짐. **Guard**: (a) build_common_snapshot에 `stage3_kuromi_ball_hidden: false` 추가, 또는 (b) ghost_summon에 owner-less cancel 견디는 self-heal 소유 플래그(puppet_grab `_owns_boss` 패턴). 2슬롯이라 per-owning-skill로. **Smoke**: ghost_summon mid-hold(둘 다 true)→cancel(null)→reset_ball→둘 다 false. 현 정규화에서 FAIL.

### LOW
17. **F7 picker는 현재 안전** *(certain)*. 현 F7 setter(defense/appearance/move_speed)는 loadout/second_active 미변경. 미래 F7 skill-picker만 주의: unlock 플래그도 set(디버그 bypass)하거나 AND 게이트가 억제. **Smoke(regression-lock)**: 현 F7 override setter들이 `_debug_*_override` 3개만 건드리고 loadout/active_skill/second_active 미변경 단언.

---

## 4. 백본 sub-step (사용자 배선 순서)

각 단계 독립 smoke 봉인. 단계 끝에 `run_smoke_tests.ps1` + `run_warning_scan.ps1` + `run_headless_load_check.ps1`.

### 2b-i — per-slot 토대 (게이트 없이 FREE 동작) ✅ 봉인 완료 (2026-06-14)
2 skill_state 인스턴스(eager) · slot-indexed 헬퍼(`_get_skill_id_for_slot`/`_get_active_skill_for_slot`/`_get_skill_windup_seconds_for_slot`) · `_get_active_slot_count`(unlock AND + would_share_module) · `_update_companion_skill_effects` 슬롯 루프 · `_launch_companion_skill(slot)` slot-indexed context/cooldown · reset_round/reset_all/advance 둘 다 loop · save-load 중첩+양쪽 advance+레거시 flat→slot_0 · prewarm 둘 다 · 모든 slot-1 mutation `_invalidate` · `trigger_count` pet-shared 유지.
→ **봉인 목표**: 두 FREE 스킬(red_dragon dragon_breath + dragon_wing)이 독립 쿨다운으로 동시 발동, slot-1 unlock AND 게이트, 벤치 펫 양쪽 쿨다운 advance, slot-1 튜닝 정확. (트랩 1,5,6,7,8,9,10,14,15)

**봉인 상태 (14-에이전트 적대 리뷰 + 사용자 반증검증):** 6 가드 전부 구현,
blocker #1(shared state) 반증검증됨(`smoke 4395-4398`이 slot-1 launch 후
slot0.cooldown==0/slot1.cooldown>10·둘 다 windup 동시를 OUTCOME 단언 → 공유
인스턴스에서 FAIL). `trigger_count` pet-shared 유지(patrol seed). **2b-i 단독
ship 안전** — slot 1이 프로덕션 도달 불가(F7 picker가 second_active 미배선,
부화 V3-2c 미머지, 친밀도 Lv.22 현 스테이지로 도달 불가)라 충돌 중재 부재가
softlock 창을 안 엶. **반증 smoke 2건 추가**(`smoke 4416-4461`): ① would_share_module
same-kind(`active_skill_ids=[breath,breath]` 직접 주입으로 dedup 우회 → slot_count==1·
slot 1 미발동, 가드 제거 시 "expected 1 got 2" FAIL 직접 확인), ② 레거시 flat
스냅샷 마이그레이션(flat→slot_0 advance 20→17·slot_1 cold·trigger_count 보존).
**오탐 기각**: `_get_skill_id_for_slot:1302 slot_index <= 0`은 의도된 slot0/음수
방어(`< 0`으로 바꾸면 slot 0이 게이트에 걸려 "" 반환 위험).

> **note (미래 강화)**: same-kind 반증 smoke는 현재 카탈로그에 다른-id-같은-
> runtime_kind 쌍이 없어 같은-id 직접 주입으로 가드를 검증한다. 가드 로직
> (`would_share_module`은 id 무관 kind만 비교)은 동일 경로를 타므로 커버리지
> 충분. 미래에 다른-id-같은-kind 쌍이 카탈로그에 추가되면 end-to-end 케이스로
> 강화 권장(지금 불필요).

### 2b-ii — 충돌 중재 (BALL_OWNER/POS_OVERRIDE 안전 직렬화) ✅ 봉인 완료 (2026-06-14)
`resource_class` 집합 분류(writer grep) · arm-edge cross-slot 게이트(교집합, slot-0 우선) · slot-0-first 평가·커밋 순서 · `get_active_position_override_owner` 단일 query · draw active-visual-slot 선택 · walk-ratio 양슬롯 · strike 슬롯별+중재.
→ **봉인 목표**: 두 BALL_OWNER/두 POS_OVERRIDE 동시 적격 시 1만 arm, 단일 owner, 패배자 무손상 대기, slot-1 cast 포즈/treadmill 정상. (트랩 2,3,4,11,12,13,16)

**봉인 상태 (10-에이전트 적대 리뷰 + 사용자 반증검증):** 핵심 가드 전부 합격.
**within-frame 순서(trap #4)**가 핵심 — slot 0 `arm_windup`이 동기적으로 windup_active를
mutate(deferred/queue 아님)한 뒤 slot 1이 그 갱신 상태를 읽음, 둘 다 BALL_OWNER 동시
첫-arm(neither pre-winding) smoke가 1만 arm을 단언 → race 닫힘. `has_companion_position_override`는
모든 스킬이 **활성 phase 상태**(holding) 반환(puppet `_active`/doll·bomb·gatling `_phase!=IDLE`/
wild_roar `PHASE_ROAR`/headbutt `_active or _impact_timer>0`)이라 arm gate가 유휴 슬롯을
over-block 안 함(capability 우려=오탐 기각). draw active-visual-slot(`_get_active_visual_slot_index`)·
walk/idle·body-hit·visibility 전부 batch owner query 소비. **부수 should-fix 해결**: debug
reconcile-skip을 `_apply_current_loadout` 진입 즉시 1회 소비(빈 pet early-return 포함 모든
경로)로 stale skip 길 차단, 반증검증 smoke(`4448` 같은-펫 Lv.2 passive reconcile + owner sync,
임시 stale 재현 FAIL 확인). **오탐 2건 기각**: line 2008 capability(위), strike "slot-0 only
DROPPED"(실제 line 1980 루프-내 슬롯별 호출).

> **선택 cleanup (봉인 blocker 아님)**: line 2070 `_apply_companion_skill_position_override(skill_id)`
> = dead code(호출처 없음), line 2051-2052 = line 1981 batch apply와 idempotent 중복(같은
> owner pos 두 번 write, 무해). 미래 혼란 방지 차 정리 권장. smoke 갭(nice-to-have):
> loser-resumes-after-release 멀티프레임, strike slot-1, BALL_OWNER loser cooldown 불변 명시.

### 2b-iii — owner/HUD 노출 (라이브 값, draw는 2d) ✅ 봉인 완료 (2026-06-14)
`get_snapshot(slot_suffix)` · internal `companion_skill_*_1` 키 · `lingpet_/ringpet_second_skill_*` 페어 DEFAULT_VALUES 선언 · `_sync_second_skill_owner`(unlock 게이트, 기본값 sync) · `_windup_ratio` 0..1.
→ **봉인 목표**: schema-gated owner로 slot-1 라이브 쿨다운(카탈로그 base와 divergent)이 패널에 도달, 미선언 키 제거 시 snapshot-sync seal FAIL. (트랩 — owner schema)

**봉인 상태 (적대 리뷰 4축 직접 확인 합격):** ① owner sync — 8키 페어
(id/name/max_level/cooldown/cooldown_duration/ready/winding_up/windup_ratio) 전부
DEFAULT_VALUES 선언 + `_sync_second_skill_owner`가 **locked 시 unconditional 기본값
push**(skip 아님 → Lv.22→sub-Lv.22 전환 stale 차단) + 전부 scalar `_set_pair`(change-gated,
origin은 internal-only) + windup_ratio 0..1 + dead-data 없음(last_gain/trigger_count/origin의
second owner 페어 미선언). ② schema seal `_verify_snapshot_sync_keys_are_schema_declared`는
**동적 소스 regex 스캔**(하드코딩 리스트 아님 → 미래 키 자동 커버), lingpet_·ringpet_ 양쪽
매칭(단일-키 페어 누락도 잡음), 미선언 제거 시 FAIL=반증검증. ③ back-compat — `get_snapshot(suffix="")`이
slot-0 bare 키셋 완전 보존(키 변경/누락 0). ④ reconcile-skip sticky 수정(2b-ii 후속): debug_grant
460 set→461 apply→**462 즉시 false 복원**, 460 유일 set + 462/555/1470 복원으로 모든 경로 stale
차단, one-shot 반증검증 smoke(같은 펫 Lv.2 reconcile 재생).

> **V3-2d 진입 시 체크 (봉인 blocker 아님)**: ① `second_skill_cooldown_duration` 기본값 0.0
> (slot-0는 40.0) — locked 분모 0=행 숨김 의도이나 V3-2d가 두 슬롯 progress bar 분모를 같은
> 방식으로 다루는지 확인. ② winding_up/windup_ratio 경로 비대칭 — slot-0는 internal snapshot만,
> slot-1은 owner+internal. V3-2d가 두 슬롯 windup을 어느 경로로 읽는지 일치시킬 것.

---

## 5. 미해결 설계 질문 (배선 전 1개 확정 권장)

- **동시 windup 정책**: per-slot state 분리는 두 슬롯이 같은 창에서 windup/launch를 **허용**(예: 두 sortie_flight가 center+visible can_arm 동시 통과). resource-class 게이트는 같은-클래스만 직렬화 — **다른-클래스(예: FREE+FREE, FREE+BALL_OWNER)는 동시 windup 가능**. 이게 의도면 그대로; "한 번에 1 windup만" 원하면 egg_runtime 루프에 명시적 cross-slot busy 체크 추가(state 공유 아님). **→ 사용자/기획 확정 필요.** 권장: 클래스 게이트만으로 출시 후 체감 starvation 시 재방문.
- **slot-1 starvation**: slot-0 같은-클래스 스킬의 쿨다운이 짧으면 slot-1 같은-클래스가 영구 지연 가능. 실 로드아웃 데이터로 판단(선제 fairness fallback 금지).

---

## 6. 단일 소스 / 링크
- 친밀도 v3 전체: `docs/lingpet_affinity_system_plan.md` §13-9 (V3-2 sub-slice).
- 관련 트랩 (CLAUDE.md): Hot-Path Lazy Init / Owner-Field Schema / Lazy Applied-Key Re-Apply / Companion Walk/Idle Ratio / owned-ball skip_ball_motion_step / Boss-Paddle-Scripting 단일-owner.
- 분담 패턴: 메모리 `feedback-design-slice-review-division`.
