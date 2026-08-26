# 지시문 X2 — [P1] 수호의 샘터 첫 수호령이 액티브·패시브 스킬 없이 시작한다

- **발행**: 관제탑 2026-08-26. 대상: 본 트리 `d:\main\bosspong` HEAD `ea3d864bb`
  기준 **격리 워크트리 + 격리 브랜치**. 본 트리 편집·통합·푸시 금지.
- **병행 가능**: 이 지시문이 편집할 파일은 X1(샘터 기능)·X3(샘터 연출)과
  **겹치지 않는다**(`lingpet_egg_runtime.gd` 계열). W1·W3·W5와도 겹치지 않는다.
  선행 조건 없이 바로 착수 가능하다.
- ⚠단 `tower_ascent_guardian_spring_node.gd:877` **한 줄**은 X1이 같은 파일을
  건드린다. 그 줄만 편집하고 다른 곳은 손대지 마라. 통합 시 헝크 거리를
  확보하기 위해서다.

---

## 관측

> 수호의 샘터에서 "손바닥을 대본다"로 처음 획득한 수호령은 **액티브 스킬,
> 패시브 스킬이 없다.**

## 확정된 진범 (프로브 실측 · 추측 아님)

**차단이 이중이라 어느 한쪽만 고치면 여전히 빈다.**

체인:

```
_apply_first_pick (tower_ascent_guardian_spring_node.gd:877~883)
  → grant_and_activate_tower_spring_guardian (lingpet_egg_runtime.gd:1640~1650)
  → _grant_and_activate_pet(pet_id, owner, true, "", "", registry)   ← 스킬 인자 전부 빈 문자열
  → has_explicit_loadout = false (:1702~1707)
```

1. **★진범 1** — `lingpet_egg_runtime.gd:1725`: 신규 펫이면
   `set_pet_loadout_and_invalidate(owner, pet, "", "", 0, 0, _snapshot_builder)`로
   **빈 로드아웃을 선점 저장한다.**
   - `_slot_count_for_pair("", "")` → 0 (`lingpet_loadout_state.gd:519~524`)
   - `_normalize_loadout`의 fill_missing 기본채움은 `slot_count > 0`일 때만
     동작(`:415~422`) → 스킵 → `:431~434`가 `build_empty_loadout()` 반환
   - ⚠이건 **NON-empty Dictionary**라 `set_pet_loadout:214~215`의
     `is_empty() → build_default_loadout()` 폴백이 **절대 안 걸린다.**
     즉 "기본값을 채워라"는 의도가 "빈 로드아웃을 확정하라"로 뒤집힌다.
2. **★진범 2** — `lingpet_egg_runtime.gd:1734`:
   `_apply_current_loadout(owner, true, false, registry)` — `randomize_missing=false`.
   부화 경로(`:2741`, `:2825`)는 **true**다.
   그리고 `ensure_pet_loadout`은 저장된 로드아웃이 있으면
   `lingpet_loadout_state.gd:161~166`에서 즉시 반환해
   `:167`의 `pick_skill_loadout` / `build_default_loadout` 분기에
   **도달조차 하지 않는다.**
3. 결과: `sync_owner`(`:364~379`)가 owner의 액티브/패시브 id를 `""`·레벨 0으로
   publish하고, 스냅샷 빌더가 그대로 빈 값을 표시한다.

**대조군 (둘 다 정상 동작)**

- 알 부화: `_finish_regular_hatch` → `_apply_current_loadout(owner, true, **true**, registry)`
- 살핀다(엘리트) 구매: `begin_tower_spring_overflow_compare`(`:1397`)가
  오퍼의 `base_loadout`을 `set_pet_loadout_and_invalidate`로 **명시 write**
  (`tower_guardian_spring_offer_builder.gd:78`이 `LingpetCatalog.build_default_loadout(pet_id)`로 만든다)

**첫 픽만 producer가 없다.** `build_first_pick_candidates`
(`tower_guardian_spring_offer_builder.gd:30`)가 만드는 후보 dict는
`pet_id` / `display_name` / `art_path` 뿐 — **로드아웃 필드가 아예 없다.**
GRT-031(반쪽 착지) 계열이다.

## 확인된 사실 (재조사 금지)

- ✔**WIP 탓이 아니다.** `egg_runtime`·`catalog`·`current_profile`은 더티지만
  diff 헝크가 판정부(`1683~1753`)를 비껴간다. 커밋된 HEAD의 결함이다.
- ✔**세이브 마이그레이션 불필요.** `_is_volatile_run_snapshot`이 companion
  스냅샷을 디스크에서 지운다 — 수호령은 **런 스코프**다.
- ✔**강화 경로는 정상**이다. 빈 로드아웃이면 "스킬 +1" 카드가 빠지는 대신
  "액티브/패시브 추가 해금"이 열리고, 해금 적용 시 reconciler가 slot_count를
  1로 되살린다.
- ✔**GRT-024 배선 불필요.** `lingpet_runtime_snapshot_builder.gd:230~257`이
  `companion_skill_*`와 `*_1`, `companion_passive_skill_*`/`_1`을 **모두 같은
  로드아웃에서 파생**한다. 로드아웃만 채우면 두 표시면이 자동으로 따라온다.
- ✔런타임·HUD·교체 비교창은 스킬 0개를 **정식 상태로 이미 다룬다**(에러 없음).
  부화 롤도 `_roll_hatch_skill_level = randi_range(0,3)`로 1/16 확률(6.25%)로
  같은 상태를 만든다. **깨지는 곳은 없고, 다만 첫 픽만 항상 0개다.**

## 사용자 확정 사양

> 액티브 스킬 **1개**, 패시브 스킬 **1개**를 각각 **Lv.1**로 지니고 시작한다.
> 액티브는 **후보 2개 중 1개**, 패시브는 **패시브 풀 중 랜덤 1개**.

## ★수리 범위 — 좁혀라 (씰 충돌 회피)

**샘터 첫 픽 하나만 고쳐라.**

`lingpet_egg_runtime.gd:1640~1650`의 `grant_and_activate_tower_spring_guardian`이
빈 문자열 대신 **명시 로드아웃**을 `_grant_and_activate_pet`에 넘기게 하라.
그러면 `has_explicit_loadout`이 true가 되어 `:1709~1721` 브랜치를 타고,
`_normalize_loadout`의 빈-슬롯 계약도 v3_2c 씰도 **건드리지 않는다.**

⚠**절대 하지 마라**: `_grant_and_activate_pet`의 else 브랜치나
`lingpet_loadout_state._normalize_loadout`(`:431~434`)을 고치는 것.
그러면 부화 롤 level-0 채널, 비교창 '없음' 계약, 강화 해금 후보 개방,
그리고 아래 두 씰이 **한꺼번에** 걸린다.

- `godot/tests/lingpet_unlock_loadout_v3_2c_smoke.gd:180~193`
  `_verify_no_skill_activation_snapshot()` — 픽스처가
  `debug_grant_and_activate_pet(pet, owner, false, "", "", registry)`로
  **탑 샘터 첫 픽과 완전히 같은 인자 모양**을 태워 빈 결과를 요구한다.
- 같은 파일 `:214~232`
  `_verify_empty_primary_set_does_not_reinject_defaults()` — `set_pet_loadout(..., "", "", 0, 0)`
  → slot_count 0을 **요구**한다.

이 둘은 공허 GREEN이 아니라 **의도 봉인**이다. 범위를 좁히면 손댈 필요가 없다.

## 롤 규칙 (정확히 이대로)

### 액티브

- 후보는 `lingpet_unlock_loadout_reconciler.gd:96`
  `get_active_unlock_candidate_ids`의 `first_raw_candidates(ids, 2)` 규칙을
  따른다(후보 2개 → 1개 무작위).
- ⚠**후보가 2개가 아닌 수호령이 있다.** 15종 중 4종:
  - `lunabi`(`lingpet_catalog.gd:291`) — 단일 `active_skill`
  - `onimaru`(`:1172`) — 단일
  - `rahoset`(`:1263`) — 단일
  - `orosha`(`:1357`) — pool 항목 1개
  **후보가 1개면 그것을 확정하라.** "2개 중 1개"를 하드 가정하지 마라.
- 나머지 11종은 pool에 정확히 2개다(`:231` 마리보 등). `:252` `effect_text`가
  이미 `"창해수창 또는 수옥결계 중 획득 시 선택된 액티브"`로 2중1 계약을
  선언하고 있다.

### 패시브

- `get_passive_skill_pool(_pet_id)`(`lingpet_catalog.gd:1641`)는 **pet_id를
  무시한다.** 패시브 풀은 종별이 아니라 **수호령 공통 풀 6종**이다
  (기맥공명 · 잔광영액 · 순풍보법 · 무혼추적 · 축지호위 · 장생호흡,
  정의는 `:110~190`). 균등 추첨 1개.

### 레벨

- **항상 Lv.1.** ⚠**`pick_skill_loadout`을 그대로 재사용하지 마라.**
  그 안의 `_roll_hatch_skill_level`(`:1754`)은 `randi_range(0, 3)`이라
  **0이 나오면 스킬이 없다(25%).** 사용자 사양은 "항상 Lv.1"이다.
- `SKILL_LEVEL_MAX := 5`(`:102`), `clamp_skill_level`(`:1527`)은 1..5.
  즉 Lv.는 **스킬 성급**이고 별도의 "수호령 레벨" 필드는 로드아웃/런타임
  어디에도 없다. 강화 보상 `active_skill_bonus`가 이 성급을 올린다.

### ★RNG

- 샘터는 강화 롤에 **전용 `RandomNumberGenerator` +
  `hash(RNG_VERSION:map_seed:node_id:sequence)` 시드**를 쓴다
  (`tower_ascent_guardian_spring_node.gd:991`). **첫 픽 로드아웃 롤도 이
  패턴을 따라라.**
- ⚠**`lingpet_guardian_run_state.gd:404` `resolve_random_unlock`을 재사용하지
  마라.** 그것은 전역 `randi()`를 써서 권위 RNG를 전진시킨다. 저장소 규칙
  위반이고 런 재현성이 깨진다.

### 개체값(기동/방어 헤드스타트) — 제외

- `lingpet_hatch_stat_roll_state.gd:131`의 개체값 롤도 현재 첫 픽에는 안
  걸린다(applier `:50~55`가 `randomize_missing=true`일 때만 `ensure_roll` 호출).
- **이건 그대로 둔다.** 문서 정본(S3 지시문)이 첫 픽 3종을
  **"전원 무강화 기본체"** 로 규정한다. Lv.1 스킬 1+1은 기본체가 원래
  갖는 것이지만, 부화 보너스인 개체값 헤드스타트는 기본체가 아니다.
  보고에 이 결정을 명시하고, 판단이 다르면 되물어라.

## 씰 요구

1. **★공백 메우기(필수)**: `tower_guardian_spring_runtime_path_smoke.gd`의
   first_pick 레그(`:149~208`)는 **실제 `LingpetEggRuntime`을 이미 태우면서도
   applied/cutin/입력만 보고 로드아웃을 한 줄도 안 본다** — 이 레그에 한해
   공허 GREEN이다. 픽스처 추가 비용 0으로 단언을 넣어라:
   `runtime.get_snapshot()["lingpet_loadouts"][pet_id]`의
   `active_skill_ids` / `passive_skill_ids` 크기와 `slot_count`를 확정
   기대치로 못박아라.
2. **음성 대조군**: 같은 스모크에서 **유료 browse/replace 경로로 획득한
   수호령은 스킬이 있어야 한다**를 함께 단언해 첫 픽만 특수함을 고정하라
   (기존 `:306~322` 로드아웃 대조 레그 재사용 가능).
3. **RED 반증(필수)**: 명시 로드아웃 전달을 되돌리면 `slot_count == 0`으로
   RED가 되는지 확인하고 **원상복구**하라.
4. **후보 1개 수호령 레그**: `lunabi` / `onimaru` / `rahoset` / `orosha` 중
   최소 1종으로 "후보가 1개여도 액티브가 채워진다"를 단언하라.
5. **레벨 레그**: 롤 결과 액티브·패시브 레벨이 **항상 1**임을 반복 시드로
   단언하라(부화 롤의 25% level-0 채널을 물려받지 않았음을 증명).
6. **RNG 분리 레그**: 첫 픽 롤이 전역 `randi()`를 전진시키지 않음을
   차등 시드 대조로 단언하라.
7. ⚠**가짜 런타임 스텁으로는 봉인 불가.**
   `tower_guardian_spring_chosik_bridge_smoke.gd:87`과
   `tower_guardian_spring_stage3_smoke.gd:68`의 FakeRuntime은 로드아웃 코드를
   **안 탄다.** 여기에 단언을 추가해도 공허하다.
   **실제 `LingpetEggRuntime`을 쓰는 레그에만 넣어라.**
8. **기존 씰 GREEN 유지**: `lingpet_unlock_loadout_v3_2c_smoke`(두 레그 무개정
   확인), `tower_guardian_spring_runtime_path_smoke`,
   `tower_ascent_guardian_spring_node_smoke`.
9. **CI/pre-push 락스텝**: 신규 스모크를 만들면 양쪽 동시 등재(현재 243/243).

## 함께 보고할 것 (수리 범위 밖 · 별건 후보)

- **오표기 (현재 라이브)**: 캐릭터정보 패널 본문이 카탈로그 `effect_text`를
  그대로 써서 **없는 스킬을 약속한다**(`lingpet_effect_text_resolver.gd:11`).
  스킬을 채우면 첫 픽에서는 가려지지만 텍스트 리졸버 자체는 여전히
  로드아웃을 모른다. 부화 1/16 경로에서는 그대로 남는다.
- **유령 패시브 잠복 (GRT 신설 후보)**:
  `character_info_overlay_lingpet_card_specs.gd:101`의
  `elif gauge_bonus_pct > 0.0` 분기와 `LingpetCatalog.get_passive_skill`의
  `pool[0]` 폴백(`:1636~1637`)이 겹치면, 패시브가 없는데 '기맥공명' 카드가
  그려질 수 있다. 지금은 모든 펫의 base `gauge_gain_bonus_pct`가 0.0이라 안
  터지지만, **어느 펫에 base를 0보다 크게 주는 순간 즉시 발현한다.**
  `get_active_skill`은 이미 sentinel 분리가 돼 있는데 `get_passive_skill`만
  안 돼 있다.
- **진행 중인 런**: 수리 후에도 이미 스킬 0개인 수호령은 그 런에서 빈 상태가
  유지된다(정규화가 빈 상태를 보존). 세션 간 마이그레이션은 불필요하지만
  런 중간 마이그레이션을 넣을지 여부는 관제탑 판단 대기 — **넣지 말고
  보고만 하라.**

## 게이트·보고

포커스드 스모크(+RED 반증) → `run_warning_scan.ps1 -Paths <touched>` →
`run_headless_load_check.ps1` → `git diff --check`.

⚠**헤드리스/스모크/스캔 실행 전 `godot/logs`를 통째로 복사하라.**
⚠래퍼는 `-AllowDuringPlay` 선언 + PID/타임스탬프 고유 `--log-file`.
**사용자의 게임·에디터를 절대 종료하지 마라.**

보고: 커밋 해시 · 씰 종단선 **원문** · RED 반증 출력 · 후보 1개 수호령
처리 방식 · 개체값 제외 결정에 대한 의견 · 미해결.
