# 링펫 친밀도 매 런 리셋 재설계 노트

작성일: 2026-06-20

## 0. 확정 결정

**링펫 친밀도 축 전체를 매 런 리셋한다.**

기존 V3-3 설계는 링코어를 `user://lingpet_affinity.cfg`의 `[ring_core] tier`에 저장하는 계정 공용 영구 파츠로 두었다. 이 방식은 게임을 껐다 켜도 T6가 유지된다. 이제 목표는 반대다:

- 링코어 tier는 영구 progression이 아니라 **런 빌드 상태**다.
- 강화칩은 기존처럼 런 상태다.
- 친밀도 레벨/포인트/스킬 해금/2번째 슬롯 점유도 런 상태다.
- 기존 `best_levels`, `bond_points`, `resolved_unlock_choices` 기반 영구 잔향은 제거 또는 무시한다.
- 링펫 소유/컬렉션 자체는 별도 축이다. 이 문서는 링펫 **친밀도/링코어/해금 빌드**만 다룬다.

즉, "이번 런에서 어떤 링펫을 얼마나 키웠고 어떤 링코어를 샀는가"는 새 런에서 초기화된다.

## 1. 왜 단순히 `[ring_core] tier=0`만 하면 안 되는가

현재 코드에서 영구/런 축이 섞여 있다.

- `LingpetAffinityState.reset_all()`은 `_pets`, 강화칩, 먹이 사용 카운터를 지운다.
- `LingpetAffinityStore`는 별도 파일에 `best_levels`, `bond_points`, `[ring_core] tier`, `resolved_unlock_choices`를 저장한다.
- `egg_runtime`은 store의 best level로 headstart를 재생성하고, store의 ring core tier로 cap을 주입한다.

따라서 링코어만 T0로 내려도 다음 문제가 남는다.

- `best_levels`가 남으면 새 런에서 친밀도 headstart가 재생성된다.
- `resolved_unlock_choices`가 남으면 지난 런의 스킬 선택이 새 런에 섞인다.
- `bond_points`가 남으면 UI/호칭이 영구 성장처럼 보인다.
- 골드샵 링코어 구매가 store에 쓰면 다음 실행에서 다시 살아난다.

매 런 리셋으로 가려면 store의 친밀도 progression 섹션 전체를 런 상태와 분리해야 한다.

## 2. 최종 상태 모델

### 2-1. 런 상태: `LingpetAffinityState`

런 중 다음 값을 소유한다.

- pet별 `affinity_level`, `affinity_points`
- pet별 reward history/counts
- ring core tier/cap
- enhancement chip count
- feed uses this run
- resolved unlock choices
- active/passive/second slot 해금 결과

`reset_all()` 또는 새 런 시작 경계에서 위 값은 전부 초기화된다.

### 2-2. 영구 저장: affinity progression 금지

`LingpetAffinityStore`는 현재 아래 섹션을 저장한다.

- `[best_levels]`
- `[bond_points]`
- `[ring_core]`
- `[resolved_unlock_choices]`

매 런 재설계 후에는 이 섹션들이 친밀도 진행에 영향을 주면 안 된다.

권장 방향:

- schema v5로 올리고 기존 progression 섹션을 **로드 시 무시 + 다음 저장에서 제거**한다.
- 일시 호환을 위해 파일 파서는 남기되, `egg_runtime`이 progression 값을 읽지 않게 한다.
- QA/디버그용 read API는 남겨도 되지만, 런타임 cap/해금/헤드스타트의 소스가 되면 안 된다.

### 2-3. 골드샵 링코어 구매

링코어 구매는 유지하되 의미를 바꾼다.

- 기존: 골드로 영구 tier 상승.
- 변경: 골드로 **이번 런의 tier 상승**.

구매 UI 라벨은 "영구 강화"로 읽히면 안 된다. 예:

- `링코어 강화 T2 300G`
- 보조 설명: `이번 런 동안 친밀도 상한 증가`

구매 트랜잭션은 여전히 gold/AP 무결성을 지켜야 한다.

- 결제 실패: gold/AP/tier 불변
- tier upgrade 실패: refund
- max tier: payment 전 차단

다만 upgrade 대상은 `LingpetAffinityStore.upgrade_ring_core_tier()`가 아니라 런 상태의 ring core tier여야 한다.

## 3. 새 런 / 게임 재시작 경계

### 3-1. 새 런 시작

새 런 시작 시:

- 친밀도 pet state clear
- ring core tier = 0
- enhancement chips = 0
- feed uses = 0
- resolved unlock choices = {}
- loadout unlock reconcile는 빈 상태에서 시작

미카 튜토리얼 기본 코어 정책은 재결정:

- 추천: Junior Mika 첫 알 스폰 시 매 런 tier 1을 지급한다.
- 이유: 무코어 T0는 "링펫은 있으나 친밀도/스킬이 죽은 상태"라 초반 튜토리얼 체감이 나쁘다.
- 단, 이 지급은 store에 저장하지 않고 런 상태에만 적용한다.

### 3-2. 게임 재시작

게임을 껐다 켜면 기존 런이 종료된 것으로 본다.

- 링코어 tier는 T0 또는 튜토리얼 조건 충족 시 T1부터 다시 시작한다.
- 지난 실행의 T6는 복원되지 않는다.
- 지난 실행의 스킬 해금/2번째 슬롯/친밀도 포인트도 복원되지 않는다.

## 4. 코드 영향 범위

### 4-0. 영구 터치포인트 전수 인벤토리

매 런 재설계에서 반드시 제거하거나 run-state로 재지정해야 하는 영구 터치포인트다.

**영구 write 경로**

- `plaza_lingpet_store_transactions.gd::_buy_ring_core_upgrade`:
  `affinity_store.upgrade_ring_core_tier(next_tier)`로 `[ring_core] tier`를 저장한다.
- `runtime_perk_state.gd::_apply_lingpet_ring_core_upgrade`:
  링코어 퍽 선택이 `lingpet_affinity_store.upgrade_ring_core_tier()`를 직접 호출한다. 플라자만 바꾸면 이 경로가 영구 T를 되살린다.
- `lingpet_egg_runtime.gd::_grant_tutorial_standard_ring_core_if_needed`:
  미카 튜토리얼 기본 코어가 store tier 1을 저장한다.
- `lingpet_egg_runtime.gd::_record_affinity_best_level_if_needed`:
  `store.set_best_level()`로 `[best_levels]`를 저장한다.
- `lingpet_egg_runtime.gd::_maybe_settle_affinity_bond_on_victory`:
  `store.add_bond_levels()`로 `[bond_points]`를 저장한다.
- `lingpet_affinity_store.gd::set_resolved_unlock_choice`:
  `[resolved_unlock_choices] pet.choice_key=skill_id`를 저장한다. 현재 picker surface는 닫혔지만 API/write path는 남아 있으므로 v5에서 비활성화 또는 run-state 전환이 필요하다.

**영구 read/apply 경로**

- `lingpet_egg_runtime.gd::_resolve_affinity_ring_core_cap`:
  store tier/cap을 읽어 reward context cap으로 주입한다.
- `lingpet_egg_runtime.gd::_apply_affinity_headstart_from_store` 계열:
  store best level을 읽어 `apply_headstart_from_best`로 새 런 headstart를 재생성한다.
- `lingpet_egg_runtime.gd::_apply_persisted_unlock_choices`:
  store의 `[resolved_unlock_choices]`를 읽어 active/passive/second loadout에 적용한다.
- `lingpet_egg_runtime.gd` bond owner sync:
  store bond points/title을 owner key로 밀어 TAB snapshot에 전달한다.
- `character_info_overlay_lingpet_snapshot_builder.gd` / `character_info_overlay_lingpet_presenter.gd`:
  `lingpet_bond_points`, `lingpet_bond_title`을 읽어 subtitle/호칭 UI를 만든다. bond 축을 제거하면 이 표기도 run-state 또는 빈 표기로 정리해야 한다.

이 목록은 구현 때 smoke/source seal의 기준이다. 하나라도 남으면 "게임을 껐다 켜도 친밀도 축 일부가 살아남는" 회귀가 된다.

### 4-1. `lingpet_affinity_state.gd`

필요 작업:

- run-scope ring core tier 필드 추가 또는 기존 pet data cap과 별도 owner 값 정리
- `reset_all()`에서 ring core tier/cap도 명시 초기화
- `get_ring_core_tier()`, `get_ring_core_cap()` 같은 런 상태 API 추가 검토
- 강화칩/먹이 카운터와 동일하게 run-scope 스모크 봉인

주의:

- cap gate의 "임시 상한은 포인트 보관, MAX 30만 overflow discard" 계약은 유지한다.
- ring core tier가 T0이면 cap 0이다.

### 4-2. `lingpet_affinity_store.gd`

필요 작업:

- schema v5
- 기존 `[ring_core]`, `[best_levels]`, `[bond_points]`, `[resolved_unlock_choices]` 로드 무시 또는 migration drop
- `_has_any_loaded_residue()`에서 과거 progression residue가 "살아있는 진행"으로 판정되지 않게 조정
- save 후 파일에 progression 섹션이 재생성되지 않는지 smoke
- `set_ring_core_tier`, `upgrade_ring_core_tier`, `set_best_level`, `add_bond_levels`, `set_resolved_unlock_choice`의 v5 의미를 결정한다.
  - 추천: affinity progression store는 저장을 하지 않는 no-op 또는 debug-only로 축소한다.
  - 단, caller가 성공으로 오해하면 안 되는 경로는 명확한 blocked summary를 돌려야 한다.

주의:

- 현재 사용자의 `user://lingpet_affinity.cfg`에 `[ring_core] tier=6` 같은 값이 있으면, v5 마이그레이션 후 무시되어야 한다.
- BOM/ConfigFile trap은 그대로 유지한다. 첫 섹션 `[meta]`가 깨지면 안 된다.

### 4-3. `lingpet_egg_runtime.gd`

필요 작업:

- `_resolve_affinity_ring_core_cap(registry)`가 store tier를 읽지 않게 변경
- `_configure_affinity_reward_context`에 run-state cap 주입
- store best level 기반 `apply_headstart_from_best` 경로 제거 또는 debug-only로 격리
- tutorial tier 1 grant를 store mutation이 아니라 run-state mutation으로 변경
- `_record_affinity_best_level_if_needed`의 store write 제거
- `_maybe_settle_affinity_bond_on_victory`의 store write 제거
- `_apply_persisted_unlock_choices`가 store의 resolved choices를 새 런 loadout에 적용하지 않게 제거 또는 run-state 전용으로 전환
- owner sync의 `lingpet_ring_core_tier` / `ringpet_ring_core_tier`는 run-state 값 노출
- bond owner keys(`lingpet_bond_points`, `lingpet_bond_title` 등)는 제거, 0/빈값, 또는 run-state-only 표기로 통일

주의:

- registry thread 누락으로 cap이 MAX fail-open 되던 V3-3a 함정이 재발할 수 있다.
- store를 읽지 않더라도 cap preserve sentinel 패턴은 유지해야 한다.

### 4-4. `plaza_lingpet_store_transactions.gd`

필요 작업:

- action 1 ring core 구매가 store tier를 올리지 않고 현재 런 tier를 올리게 변경
- offer 라벨은 run-scope임을 암시
- payment-first + refund 안전핀 유지

주의:

- 같은 광장 방문에서 첫 성공만 AP 1 소비하는 규칙은 기존 plaza_scene 계약 유지.
- 게임 재시작/새 런 후 구매 효과가 사라지는지 smoke 필요.

### 4-5. `runtime_perk_state.gd`

필요 작업:

- `_apply_lingpet_ring_core_upgrade`가 `LingpetAffinityStore.upgrade_ring_core_tier()`를 호출하지 않게 변경
- 링코어 퍽은 현재 런의 ring core tier를 올려야 한다.
- 피드백 텍스트/blocked reason은 "이번 런" 의미와 맞아야 한다.

주의:

- 플라자 구매만 run-state로 바꾸고 퍽 경로를 놔두면, 퍽 선택으로 영구 `[ring_core] tier`가 다시 저장된다.
- `LingpetAffinityStore.MAX_RING_CORE_TIER` 같은 tier 상수는 재사용 가능하지만, 상태 저장 대상은 store가 아니어야 한다.

### 4-6. TAB / 캐릭터 정보창

표시는 유지하되 의미만 변경한다.

- 링코어 전용 행: 현재 런 tier 표시
- 강화칩: 현재 런 chip count 표시
- 후보 대기 UI: 폐쇄 유지. 스킬 해금은 자동 결정.
- bond/호칭 subtitle은 영구 `[bond_points]`를 읽지 않게 한다. 제거하거나 현재 런 친밀도에서 파생되는 임시 표기로만 남긴다.

## 5. 마이그레이션 정책

기존 저장 파일이 있어도 새 런 설계에서는 다음처럼 처리한다.

- `[ring_core] tier`: 무시 또는 v5 저장 시 제거
- `[best_levels]`: 무시 또는 제거
- `[bond_points]`: 무시 또는 제거
- `[resolved_unlock_choices]`: 무시 또는 제거

권장 smoke:

1. v4 파일에 `tier=6`, best 30, bond, resolved choice를 넣는다.
2. v5 store load.
3. egg runtime 새 실행.
4. TAB/owner ring core tier는 0 또는 튜토리얼 T1이다.
5. active/passive loadout은 과거 resolved choice를 쓰지 않는다.
6. TAB subtitle/호칭은 과거 bond points를 쓰지 않는다.
7. 저장 후 cfg에 progression 섹션이 다시 쓰이지 않는다.

## 6. 스모크 계획

### 6-1. state

- `reset_all()` 후 ring core tier/cap/chip/feed/affinity/resolved choices 모두 0/empty.
- T0 cap 0에서 point bank 보관.
- run tier 상승 후 bank가 cap까지 즉시 반영.
- 새 `LingpetAffinityState` 인스턴스는 이전 인스턴스 tier를 보지 않는다.

### 6-2. store migration

- v4 permanent ring core T6 파일을 로드해도 runtime tier T6가 되지 않는다.
- v4 best/resolved choices가 새 런 loadout에 반영되지 않는다.
- v4 bond points/title이 TAB subtitle에 반영되지 않는다.
- save roundtrip 후 obsolete 섹션 제거 또는 ignored 상태 유지가 명확하다.

### 6-3. plaza transaction

- 구매 성공: gold/AP 차감 + run tier 상승.
- 재시작/새 런: tier 초기화.
- 실패: gold/AP/tier 불변.
- max tier: payment 전 차단.

### 6-4. perk ring-core upgrade

- 링코어 퍽 성공: 현재 런 tier 상승.
- 링코어 퍽 성공 후 `user://lingpet_affinity.cfg`에 `[ring_core] tier`가 쓰이지 않는다.
- max tier: 퍽 blocked 또는 no-op, 영구 store 불변.
- store가 없거나 registry가 비어도 영구 tier fail-open이 생기지 않는다.

### 6-5. tutorial

- Junior Mika 첫 egg spawn: run tier 1 지급, hatch affinity 전에 cap 5 적용.
- non-Mika: tier 자동 지급 없음.
- tier 2+ 상태에서 tutorial path 재진입: 하향 없음.
- 튜토리얼 지급 후 `user://lingpet_affinity.cfg`에 `[ring_core] tier=1`이 쓰이지 않는다.

### 6-6. best/bond/resolved write blockers

- hatch/level-up 이후 `set_best_level` write가 발생하지 않는다.
- victory 이후 `add_bond_levels` write가 발생하지 않는다.
- unlock 자동 선택 이후 `set_resolved_unlock_choice` write가 발생하지 않는다.

### 6-7. UI

- TAB ring core row는 run tier를 표시.
- 게임 재시작 후 T6가 표시되지 않는다.
- 강화칩은 매 런 0/5부터 시작.
- bond/호칭 subtitle이 과거 영구 bond를 표시하지 않는다.

## 7. 권장 구현 순서

1. **R1: state run-tier API**
   - `LingpetAffinityState`에 run ring core tier/cap 추가.
   - reset smoke.

2. **R2: runtime cap source switch**
   - `egg_runtime` cap 주입을 store에서 state로 이동.
   - tutorial grant를 run-state로 이동.
   - best/bond/resolved-choice store read/write를 끊는다.

3. **R3: store v5 migration/drop**
   - v4 progression residue 무시/제거.
   - old save T6 resurrection 방지.

4. **R4: plaza shop transaction switch**
   - gold/AP 결제는 유지, upgrade target만 run state로 변경.

5. **R5: perk ring-core transaction switch**
   - 런 퍽의 ring-core upgrade target을 store에서 run state로 변경.
   - V3-4 링코어 퍽 smoke 갱신.

6. **R6: UI smoke/pixel QA**
   - TAB row, 캐릭터 정보창, ring core labels.
   - bond subtitle 제거/임시화 확인.

## 8. 커밋/리뷰 주의

이 변경은 V3-3 전체를 뒤집는 설계 변경이다. 한 커밋으로 밀지 말고 R1~R5로 자른다.

특히 다음 파일은 외부 WIP와 섞일 가능성이 높다.

- `lingpet_egg_runtime.gd`
- `plaza_lingpet_store_transactions.gd`
- `character_info_overlay_lingpet_presenter.gd`
- `lingpet_affinity_store.gd`

hunk 단위 선별과 staged diff 리뷰가 필요하다.
