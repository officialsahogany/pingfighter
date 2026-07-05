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

R3 이전 코드에서는 영구/런 축이 섞여 있었다.

- `LingpetAffinityState.reset_all()`은 `_pets`, 강화칩, 먹이 사용 카운터를 지운다.
- R3 이전 `LingpetAffinityStore`는 별도 파일에 `best_levels`, `bond_points`, `[ring_core] tier`, `resolved_unlock_choices`를 저장했다.
- R3 이전 `egg_runtime`은 store의 best level로 headstart를 재생성하고, store의 ring core tier로 cap을 주입했다.

따라서 링코어만 T0로 내려도 다음 문제가 남는다.

- `best_levels`가 남으면 새 런에서 친밀도 headstart가 재생성될 수 있었다.
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

R3 이전 `LingpetAffinityStore`는 아래 섹션을 저장했다.

- `[best_levels]`
- `[bond_points]`
- `[ring_core]`
- `[resolved_unlock_choices]`

현재 schema v5 store는 meta-only다. 위 섹션들은 로드 시 무시되고, 다음
저장에서 제거되며, 친밀도 진행에 영향을 주면 안 된다.

현행 완료 상태:

- schema v5로 올렸고 기존 progression 섹션을 **로드 시 무시 + 다음 저장에서 제거**한다.
- 파일 파서는 meta-only migration / BOM 처리 용도로만 남고, `egg_runtime`은
  progression 값을 읽지 않는다.
- QA/디버그도 `load`/`save`/`get_schema_version`/`get_summary`의 meta-only
  표면만 사용한다. `best_levels`/`bond_points`/`ring_core`/
  `resolved_unlock_choices` progression getter/setter는 재도입하지 않는다.
- `lingpet_affinity_store`는 live `GameplayModuleRegistry` key가 아니다.
  필요한 곳은 `LingpetRingCoreRules.MAX_RING_CORE_TIER` /
  `LingpetRingCoreRules.get_ring_core_cap_for_tier()` 상수/helper를 직접 preload한다.

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

### 4-0. R3 이전 영구 터치포인트 전수 인벤토리

매 런 재설계에서 제거하거나 run-state로 재지정해야 했던 영구 터치포인트다.
아래 항목은 원인 추적용 과거 인벤토리이며, 현재 완료 상태는 §7의 R3~R6
기록과 smoke를 기준으로 판단한다.

**영구 write 경로**

- `plaza_lingpet_store_transactions.gd::_buy_ring_core_upgrade`:
  `affinity_store.upgrade_ring_core_tier(next_tier)`로 `[ring_core] tier`를 저장했다.
- `runtime_perk_state.gd::_apply_lingpet_ring_core_upgrade`:
  링코어 퍽 선택이 `lingpet_affinity_store.upgrade_ring_core_tier()`를 직접 호출했다. 플라자만 바꾸면 이 경로가 영구 T를 되살릴 수 있었다.
- `lingpet_egg_runtime.gd::_grant_tutorial_standard_ring_core_if_needed`:
  미카 튜토리얼 기본 코어가 store tier 1을 저장했다.
- `lingpet_egg_runtime.gd::_record_affinity_best_level_if_needed`:
  `store.set_best_level()`로 `[best_levels]`를 저장했다.
- `lingpet_egg_runtime.gd::_maybe_settle_affinity_bond_on_victory`:
  `store.add_bond_levels()`로 `[bond_points]`를 저장했다.
- `lingpet_affinity_store.gd::set_resolved_unlock_choice`:
  `[resolved_unlock_choices] pet.choice_key=skill_id`를 저장했다.

**영구 read/apply 경로**

- `lingpet_egg_runtime.gd::_resolve_affinity_ring_core_cap`:
  store tier/cap을 읽어 reward context cap으로 주입했다.
- `lingpet_egg_runtime.gd::_apply_affinity_headstart_from_store` 계열:
  store best level을 읽어 `apply_headstart_from_best`로 새 런 headstart를 재생성했다.
- `lingpet_egg_runtime.gd::_apply_persisted_unlock_choices`:
  store의 `[resolved_unlock_choices]`를 읽어 active/passive/second loadout에 적용했다.
- `lingpet_egg_runtime.gd` bond owner sync:
  store bond points/title을 owner key로 밀어 TAB snapshot에 전달했다.
- `character_info_overlay_lingpet_snapshot_builder.gd` / `character_info_overlay_lingpet_presenter.gd`:
  `lingpet_bond_points`, `lingpet_bond_title`을 읽어 subtitle/호칭 UI를 만들었다.

이 목록은 구현 때 smoke/source seal의 기준이다. 하나라도 남으면 "게임을 껐다 켜도 친밀도 축 일부가 살아남는" 회귀가 된다.

### 4-1. `lingpet_affinity_state.gd`

완료 상태:

- run-scope ring core tier 필드를 추가했고 pet data affinity cap과 분리했다.
- `reset_all()` / `reset_for_new_run()` 계열에서 ring core tier/cap을 초기화한다.
- run-state API(`get_run_ring_core_tier`, `get_run_ring_core_cap`,
  `upgrade_run_ring_core_tier`)가 현재 권위다.
- 강화칩/먹이 카운터와 함께 run-state export/import smoke로 봉인했다.

주의:

- cap gate의 "임시 상한은 포인트 보관, MAX 30만 overflow discard" 계약은 유지한다.
- ring core tier가 T0이면 cap 0이다.

### 4-2. `lingpet_affinity_store.gd`

완료 상태:

- schema v5 meta-only.
- 기존 `[ring_core]`, `[best_levels]`, `[bond_points]`,
  `[resolved_unlock_choices]`는 로드 시 무시되고 save 후 재생성되지 않는다.
- `_has_any_loaded_residue()`와 legacy `_load_*` helper는 제거됐다. 과거
  progression residue는 "살아있는 진행"으로 판정되지 않는다.
- `set_ring_core_tier`, `upgrade_ring_core_tier`, `set_best_level`,
  `add_bond_levels`, `set_resolved_unlock_choice`를 포함한 progression
  getter/setter API는 제거됐다. Caller는 run-state owner 경로를 사용해야 한다.

주의:

- 현재 사용자의 `user://lingpet_affinity.cfg`에 `[ring_core] tier=6` 같은 값이 있으면, v5 마이그레이션 후 무시되어야 한다.
- BOM/ConfigFile trap은 그대로 유지한다. 첫 섹션 `[meta]`가 깨지면 안 된다.

### 4-3. `lingpet_egg_runtime.gd`

완료 상태:

- ring-core cap은 store tier/cap이 아니라 `LingpetAffinityState` run-state에서
  온다.
- store best-level headstart 경로와 `apply_headstart_from_best` API는 제거됐다.
- Junior Mika tutorial tier 1 grant는 store mutation이 아니라 run-state mutation이다.
- `_record_affinity_best_level_if_needed`, store bond settlement,
  persisted unlock-choice store 적용 경로는 제거됐다.
- owner sync의 `lingpet_ring_core_tier` / `ringpet_ring_core_tier`는 run-state 값을
  노출한다.
- bond owner keys(`lingpet_bond_points`, `lingpet_bond_title` 등)는 제거됐다.

주의:

- registry thread 누락으로 cap이 MAX fail-open 되던 V3-3a 함정이 재발할 수 있다.
- store를 읽지 않더라도 cap preserve sentinel 패턴은 유지해야 한다.

### 4-4. `plaza_lingpet_store_transactions.gd`

완료 상태:

- action 1 ring core 구매는 store tier를 올리지 않고 현재 런 tier를 올린다.
- offer 라벨은 run-scope를 기준으로 계산한다.
- payment-first + refund 안전핀 유지

주의:

- 같은 광장 방문에서 첫 성공만 AP 1 소비하는 규칙은 기존 plaza_scene 계약 유지.
- 게임 재시작/새 런 후 구매 효과가 사라지는지 smoke 필요.

### 4-5. `runtime_perk_state.gd`

완료 상태:

- `_apply_lingpet_ring_core_upgrade`는 `LingpetAffinityStore.upgrade_ring_core_tier()`를
  호출하지 않는다.
- 링코어 퍽은 현재 런의 ring core tier를 올린다.
- 피드백 텍스트/blocked reason은 "이번 런" 의미와 맞다.

주의:

- 플라자 구매만 run-state로 바꾸고 퍽 경로를 놔두면, 퍽 선택으로 영구 `[ring_core] tier`가 다시 저장된다.
- `LingpetRingCoreRules.MAX_RING_CORE_TIER` 같은 tier 상수는 재사용 가능하지만, 상태 저장 대상은 store가 아니어야 한다.

### 4-6. TAB / 캐릭터 정보창

표시는 유지하되 의미만 변경한다.

- 링코어 전용 행: 현재 런 tier 표시
- 강화칩: 현재 런 chip count 표시
- 후보 대기 UI: 폐쇄 유지. 스킬 해금은 자동 결정.
- bond/호칭 subtitle은 영구 `[bond_points]`를 읽지 않게 한다. 제거하거나 현재 런 친밀도에서 파생되는 임시 표기로만 남긴다.
  → **R3b에서 제거 완료**: subtitle은 companion일 때 "동행 중" 고정,
  영구 bond/title 잔향은 snapshot_builder/presenter/schema에서 삭제.

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
- max tier: 퍽 blocked, 영구 store 불변.
- store가 없거나 registry가 비어도 영구 tier fail-open이 생기지 않는다.

### 6-5. tutorial

- Junior Mika 첫 egg spawn: run tier 1 지급, hatch affinity 전에 cap 5 적용.
- non-Mika: tier 자동 지급 없음.
- tier 2+ 상태에서 tutorial path 재진입: 하향 없음.
- 튜토리얼 지급 후 `user://lingpet_affinity.cfg`에 `[ring_core] tier=1`이 쓰이지 않는다.

### 6-6. best/bond/resolved API removal blockers

- `LingpetAffinityStore`에 `set_best_level`, `add_bond_levels`,
  `set_resolved_unlock_choice` API가 존재하지 않는다.
- `lingpet_egg_runtime_smoke` source seal이 `store.set_best_level`,
  `store.add_bond_levels`, `store.set_resolved_unlock_choice` 재도입을 막는다.
- unused legacy store fixture writer와 fake registry store 주입도 제거되어,
  테스트 더블이 영구 store 경로를 false-green으로 살릴 수 없다.

### 6-7. UI

- TAB ring core row는 run tier를 표시.
- 게임 재시작 후 T6가 표시되지 않는다.
- 강화칩은 매 런 0/5부터 시작.
- bond/호칭 subtitle이 과거 영구 bond를 표시하지 않는다.

## 7. 권장 구현 순서

1. **R1: state run-tier API** ✅ 완료 (commit 26d352aed)
   - `LingpetAffinityState`에 run ring core tier/cap 추가.
   - reset smoke.

2. **R2: runtime cap source switch** ✅ 완료 (commit eee6077b3)
   - `egg_runtime` cap 주입을 store에서 state로 이동.
   - tutorial grant를 run-state로 이동.
   - best/bond/resolved-choice store read/write를 끊는다.

3. **R3: store v5 migration/drop** ✅ 완료
   - v4 progression residue 무시/제거.
   - old save T6 resurrection 방지.
   - egg_runtime source-seal(store best/bond/resolved read/write 0) +
     egg_runtime_smoke(5함수 flip)/v3_2c_smoke(5 run-state rework + 3 삭제) GREEN.
   - 2026-06-30 후속 정리: public compat API는 최종 제거하고, store 내부
     `_best_levels`/`_bond_points`/`_ring_core_tier`/
     `_resolved_unlock_choices` backing state와 legacy `_load_*` helper도 제거.
     ring-core cap helper도 `lingpet_ring_core_rules.gd`로 분리했고,
     `lingpet_egg_runtime_smoke` source seal이 store progression API 재도입을 막는다.
   - `LingpetAffinityState`의 store-headstart API(`seed_best_level`,
     `apply_headstart_from_best`, `get_best_level(s)`)와 `best_level` run-state
     payload를 제거. `export_run_state`/`import_run_state`는 legacy
     `best_level`/`bond_points`/`bond_title` pet-data 키를 명시적으로 strip한다.
   - `LingpetEggRuntime.set_affinity_store_for_tests()` no-op compat hook도 제거.
     런타임은 store를 주입받거나 읽는 v4 경로를 더 이상 제공하지 않는다.
   - live gameplay module catalog에서도 `lingpet_affinity_store` key를 제거.
     store는 meta migration/helper 파일로 남고, registry runtime dependency가
     되지 않는다.
   - `lingpet_egg_runtime_smoke`는 `res://scripts` 전체를 스캔해
     `LingpetAffinityStore` preload/use와 `"lingpet_affinity_store"` module key
     재도입을 봉인한다.
   - 테스트 fixture 후속 정리(2026-06-30): egg/plaza smoke의
     `FakeRegistry({"lingpet_affinity_store": ...})` 주입을 제거. store 인스턴스는
     `LingpetAffinityStore` v5 migration/reload 테스트에만 남긴다. 미사용
     v1/v2/BOM/corrupt-bond affinity-store writer helper도 제거하고
     `lingpet_egg_runtime_smoke`에서 재도입을 봉인한다.

3b. **R3b: character_info 영구 bond/title 패널 표시 제거** ✅ 완료
   - per-run에서 영구 친밀도 축이 사라졌으므로, TAB 패널의 store-backed
     영구 bond/title 잔향을 제거(누락 touchpoint를 R3 직후에 닫음).
   - `character_info_overlay_lingpet_snapshot_builder.gd`: bond read + 호칭
     subtitle 제거 → subtitle "동행 중". `_companion_subtitle_for_bond` 삭제.
   - `character_info_overlay_lingpet_presenter.gd`: stats cache-hash의 bond 제거.
   - `battle_scene_state.gd`: DEFAULT_VALUES에서
     `lingpet/ringpet_bond_points` + `lingpet/ringpet_bond_title` 제거.
   - `lingpet_affinity_owner_surface.gd`: owner-facing affinity snapshot에서도
     `bond_points`/`bond_title` 생성과 `lingpet/ringpet_bond_*` write 제거.
   - run-state 표시(level/points/ring-core/chip/교감행)와 인게임 교감 피드백
     호칭(`egg_runtime.gd:1245` run-state)은 **분리 보존**.
   - character_info_live_stats_smoke + egg_runtime_smoke 패널 subtitle 어서션
     flip → GREEN. `lingpet_affinity_owner_surface_smoke`가 removed bond owner key
     비발행을 봉인. warning_scan 전역 클린.
   - 선택적 후속 정리 완료(2026-06-30): 미사용된 `"동행 중 · 친밀도 %s"`
     로컬라이즈 문자열, `BOND_TITLE_*`/`get_bond_title_for_points()` helper,
     bond-title exact-text 번역, 오래된 localization coverage 표면 제거.
   - 테스트 더블 정리 완료(2026-06-30): egg/plaza/overflow smoke의 `FakeOwner`
     계열에서 `lingpet/ringpet_bond_*` 필드를 제거해 old owner key write를 더
     이상 허용하지 않게 정리.
   - `character_info_live_stats_smoke`의 `FakeBondStore`도 제거. 해당 smoke는
     schema-gated owner의 run-state ring-core/affinity sync만 검증하고, store
     no-op compat hook은 `lingpet_egg_runtime_smoke`의 v5 meta-only seal이 담당.

4. **R4: plaza shop transaction switch** ✅ 완료
   - gold/AP 결제는 유지, upgrade target만 run state로 변경.
   - egg_runtime `upgrade_run_ring_core_tier`/`get_run_ring_core_tier`
     (add_enhancement_chip 미러) + plaza offer/buy run-state repoint +
     죽은 store 헬퍼 제거 + plaza_scene 실패 토스트 `missing_lingpet_runtime`.
   - smoke: run-state 구매 + 새-런 리셋 seal + post-payment refund 반증검증.
     `plaza_lingpet_store_menu_smoke`는 plaza transaction source가
     `lingpet_affinity_store`/`LingpetAffinityStore`를 다시 참조하지 않는지도 봉인한다.

5. **R5: perk ring-core transaction switch** ✅ 완료
   - 런 퍽의 ring-core upgrade target을 store에서 run state로 변경
     (`runtime_perk_state._apply_lingpet_ring_core_upgrade` →
     `egg_runtime.upgrade_run_ring_core_tier`, catalog offer도 run-state).
   - **false-green 깸**: 기존 smoke가 `FakeAffinityStore`(작동하는 가짜)로
     R3 store no-op을 마스킹 → 실제 `LingpetEggRuntime` run-state로 교체 +
     new-run reset seal. FIX 반증검증(run-state upgrade 깨면 smoke FAIL).
   - 비-KR 노출 정합: PERK_SUMMARY EN/ZH/JA/ES/PT_BR/RU의 "permanent/shared"
     → "this run / resets each run"(localize_perk_data override 경로) + scan seal.
   - 죽은 store 헬퍼 제거. 커밋 `edf00ff8a`(pistol_enhance·외부 localization
     WIP는 hunk 분리로 unstaged 보존).

6. **R6: UI smoke/pixel QA** ✅ 완료
   - TAB row, 캐릭터 정보창, ring core labels.
   - bond subtitle 제거/임시화 확인.
   - 2026-06-30: `character_info_lingpet_ring_core_visual_smoke.gd` 추가.
     Headless에서는 링코어 row rect/hover/cap-label 구조를 봉인하고, windowed
     실행에서는 SubViewport 픽셀 샘플로 T3 링코어 슬롯과 label text nonblank를
     캡처한다(`tmp/lingpet_ring_core_row_probe.png`). 자동 headless smoke 통과.
     windowed Vulkan 실행도 통과했고 캡처 육안 QA 완료
     (SHA256 `D0A1CAA9CCDA159D176DBD4A203103C5CA28B7C8357DAE3738A052183872A583`).
   - 2026-06-30 후속 정리: 캐릭터 선택 화면의 `LingpetAffinityStore.load()` /
     `get_ring_core_tier()` 기반 one-shot cache를 제거. 캐릭터 선택은 새 런
     이전 화면이므로 per-run ring-core tier를 들고 오지 않고, 빈 링코어 슬롯과
     공유 tier 아이콘 prewarm만 유지한다. `character_select_gamepad_navigation_smoke`
     source seal이 store cache 재도입을 막는다.

## 8. 커밋/리뷰 주의

이 변경은 V3-3 전체를 뒤집는 설계 변경이다. 한 커밋으로 밀지 말고 R1~R5로 자른다.

특히 다음 파일은 외부 WIP와 섞일 가능성이 높다.

- `lingpet_egg_runtime.gd`
- `plaza_lingpet_store_transactions.gd`
- `character_info_overlay_lingpet_presenter.gd`
- `lingpet_affinity_store.gd`

hunk 단위 선별과 staged diff 리뷰가 필요하다.

## 9. 트랩: 런 상태는 세이브 스냅샷에 실어 복원해야 한다 (2026-06-27)

**증상:** 링펫을 교체했다가 돌아오면 교감 레벨이 Lv.0, 링코어가 사라진다.

**근본 원인 (두 결함의 합작):**

- `lingpet_save_restore_applier.apply()`가 복원 맨 앞에서 **무조건 `host.reset_for_tests()`**
  를 호출한다. 이 테스트 헬퍼는 `_affinity_state.reset_for_new_run()`(=`reset_all()`)을 타고
  per-pet 교감(`_pets`)·`_run_ring_core_tier`·강화칩·먹이를 전부 0으로 민다.
- `lingpet_runtime_snapshot_builder.build_save_snapshot()`는 affinity 런 상태를 **하나도 담지
  않았다.** 그래서 복원이 비운 뒤 되살릴 데이터가 없다.

→ `apply_save_snapshot`이 도는 모든 in-run 지점(광장 알 구매 롤백, in-run 복원 등)에서
교감·링코어가 통째로 날아간다. 인-메모리 교체(`switch_lingpet_slot`)와 스테이지 전환
in-place 리셋(`match_reset`)은 런 상태를 보존하므로 버그가 아니다.

**해법 (2026-06-27 적용):** 런 상태를 스냅샷에 실어 복원 직후 다시 주입한다.

- `LingpetAffinityState.export_run_state()` / `import_run_state()` — `_pets`(deep,
  resolved_unlock_choices/reward_counts 포함)·chips·feed·`_run_ring_core_tier` 직렬화.
- `build_save_snapshot`에 `affinity_run_state` 키 추가, `get_save_snapshot`이 export 전달.
- 애플라이어가 `reset_for_tests()` **직후**(pet/state/loadout 복원 전) `host.import_affinity_run_state()`
  로 재주입 → 다운스트림 프로필/owner 싱크가 복원된 교감+링코어 cap을 그대로 표면화.

**per-run 불변식은 유지된다:** `save_runtime`→`save_snapshot`이 active-run(volatile) 스냅샷을
디스크에 **안 쓰고 파일을 clear**하므로(`_is_volatile_run_snapshot`) `affinity_run_state`는
디스크에 도달하지 않는다. 게임 재시작 시 파일이 비어 있어 런이 리셋된다.

**봉인:** `lingpet_affinity_run_state_save_restore_smoke.gd` — same-instance/fresh-instance
복원 보존 + **반증검증**(스냅샷에서 `affinity_run_state` 제거 시 복원 안 됨) + per-run-restart
불변식(volatile clear). 반증검증으로 import를 끄면 RED 확인 완료.

**일반화 규칙:** `LingpetAffinityState`에 새 run-scope 필드를 추가할 때마다 `export_run_state`/
`import_run_state`에도 넣어라. 안 그러면 in-run 세이브/복원 왕복에서 조용히 소실된다
(`reset_for_tests`가 프로덕션 복원 경로에서 호출된다는 점이 함정의 핵심).

## 10. 트랩: 보상 덱 수요 > 적용 가능 용량 → 조용한 "보상 없음" (2026-06-28)

**증상:** 교감 레벨을 후반까지 올리면 "다음: 보상 없음"이 뜨고, **링코어를 T4/T5로
올려도 계속 "보상 없음"**이다. (사용자 보고: T3 마리보가 Lv15부터, 시작 스킬레벨이
높은 펫일수록 더 일찍.)

**근본 원인:** 보상 덱은 30레벨인데 한 펫이 실제로 받을 수 있는 고유 보상 수가 30보다
적은 구조였다. 두 결함이 겹쳤다.

- **스탯 과수요:** 덱(과 원본 `CANONICAL_REWARD_TRACK`)이 스탯 카드 14장(방어4·기동5·
  게이지5)을 요구하지만 스탯 캡 합은 12(방어2·게이지4·기동6)다. → patrol 기준 최소 2개,
  flight(방어 보상 없음, 스탯 용량 10)은 4개가 구조적으로 "보상 없음"이 됐다. 시작 스킬
  레벨이 높을수록(부화 롤 1~3) 잉여 스킬 카드까지 죽어 더 빨리 고갈.
- **대체가 스탯 전용:** `_select_replacement_stat_reward_type`가 적용 불가 카드를 스탯으로만
  돌려서, 남아 있는 스킬 보너스 용량을 회수하지 못했다.
- **링코어 캡은 새 보상 종류를 추가하지 않는다.** 캡만 올리면 빈 레벨만 더 노출 → "올려도 그대로".

**해법 (하이브리드, 디자인 오너 승인):** 밸런스 수치(스탯 캡·덱 구성)는 건드리지 않고
로직으로 채운다.

- **스마트 대체** — `_select_replacement_reward_card`: 적용 불가 카드를 스탯 →
  남은 스킬 보너스(슬롯1, 그다음 해금된 슬롯2) → 그래도 없으면 `{}`(진짜 NO_REWARD) 순으로
  회수. base 1/1은 patrol/flight 모두 30레벨 전부 실제 보상(0 dry)으로 채워진다.
- **우아한 라벨** — `get_next_reward_display_label()`(state 단일 소스, owner_surface +
  grant_controller가 공유): Lv30 → "하트 공명", 진짜 고갈 → "최대 강화 완료",
  캡에 막힘(위에 보상 있음) → "링코어 강화 시 해금", 그 외 → 실제 보상 라벨.

**불변식 (재발 방지):**
- 보상 대체 폴백은 스탯만이 아니라 **남아 있는 모든 보상 용량(스킬 보너스 포함)**으로 회수해야
  한다. 스탯 전용 폴백으로 되돌리지 말 것.
- "다음 보상" 라벨은 **캡 경계 / 만렙 / 고갈**을 인지해야 한다. 잠긴 레벨의 보상을 도달
  가능한 것처럼 미리보기하면 안 된다(`get_next_reward`는 캡 무지 — 표시 라벨에서 처리).
- 덱 구성·스탯 캡·스킬 캡·`MAX_LEVEL`·이동타입별 보상 풀을 바꿀 때는 "적용 가능 용량 ≥
  도달 가능 레벨"인지 다시 확인하라. 봉인: `lingpet_affinity_state_smoke`
  `_verify_smart_fallback_fills_levels`(patrol/flight base 1/1 = 0 dry, 반증검증으로
  patrol 2 / flight 4 dry 재현) + `_verify_next_reward_display_label`(캡/만렙/고갈 라벨).
- 신규 표시 라벨 문자열("최대 강화 완료", "링코어 강화 시 해금")은 EN/ZH/JA/ES에 추가
  (RU/PT_BR는 EN alias) + `localization_coverage_smoke` surface 목록에 등록해 한글 노출 봉인.
  같이 발견된 기존 누락("2번째 액티브/패시브 스킬 +1")도 함께 추가했다.

**서브 트랩 (보상 seed 재랜덤화):** `reset_for_tests`는 `_affinity_context_coordinator.reset_for_new_run()`
도 태워 coordinator의 `_reward_seeds_by_pet_id` 캐시를 비운다. import로 pet의 `reward_seed`는
복원되지만, 직후 `_set_current_pet_id`→`sync_current_profile`→`configure`가 캐시 미스로 **새 랜덤
seed를 만들어** `configure_reward_context`에서 복원된 seed/`unlock_choice_seed_base`를 덮어쓴다
(보상 덱/언락 후보 셔플의 결정성이 깨짐). 해법: coordinator `_get_or_create_reward_seed`가
캐시 미스 시 `affinity_state.get_reward_seed(pet)`(복원된 seed)를 **먼저 채택**하고, 진짜로 seed가
없을 때만 랜덤 생성. 봉인=run_state smoke의 "preserve the reward seed" 단언 +
`lingpet_affinity_context_coordinator_smoke`
`_verify_restored_reward_seed_adoption_after_cache_reset`(반증검증: 채택 끄면
RED). 새 reset/restore 경로 추가 시 seed 캐시와 pet seed의 정합성을 항상 같이 점검할 것.
