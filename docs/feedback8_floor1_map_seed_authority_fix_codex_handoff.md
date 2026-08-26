# 지시문 X6-수정 — [P0] fail-closed 전환이 CI를 깨고, 비전 보상 레인을 통째로 죽였다

- **발행**: 관제탑 2026-08-26. 대상: 브랜치
  `codex/feedback8-floor1-map-seed-authority-20260826`(워크트리
  `D:\codex_tmp\bosspong_feedback8_seedauthority_x6_f838`)의 `08d0fa6a7` 위
  **추가 커밋**. amend/rebase 금지. 본 트리 편집·푸시·통합 금지.
- **판정**: **REJECT.** ★**시드 권위 형태(권장안: prepare 가
  `/root/GameSelectionState.tower_map_seed` 를 읽는다)는 옳은 선택이고 M키 진범도
  진짜로 닫혔다.** 그러나 fail-closed 전환이 **P0 세 건**을 만들었다.
  **두 리뷰 레인이 독립적으로 재현**했고 반증도 실패했다.
- ⚠**이대로 착지하면 "엉뚱한 비전이 나오는 버그"를 "비전이 아예 안 나오는 버그"로
  바꾸는 것이다.** 게다가 CI 가 빨개진다.

## ★먼저 읽어라 (새 세션이면 필수)

1. **원 지시문**: `docs/feedback8_floor1_map_seed_authority_codex_handoff.md`
2. **직전 구현**: `git -C D:\codex_tmp\bosspong_feedback8_seedauthority_x6_f838 -c safe.directory='*' show 08d0fa6a7`
3. 워크트리는 **이미 존재한다. 새로 만들지 마라.**
4. 본 트리 현재 HEAD 는 `6d436de71` 이고 **읽기 전용**이다.
   ⚠기준선 `f838df056` 이후 `dc18abdca`(X5)·`c4bcc2429`(CI 복구) 등이 착지했다.

---

## [P0] I1 — CI·pre-push 등재 씰 `tower_boss_routing_smoke.gd` 가 RED 다

**본 트리 HEAD 에서는 GREEN 인데 X6 에서 RED 다.** 양쪽 직접 실행 대조 확인.

**RED 반증**: 손댄 두 파일(`tower_ascent_flow_map_progress.gd`,
`tower_ascent_flow_state.gd`)만 `f838df056` 블롭으로 되돌리면
`tower_boss_routing_smoke: ok` / `PASS=1 FAIL=0` 이 나온다. 바이트 동일 복구 확인.

### 원인 둘

1. **seed 0 거부.** `_find_mixed_boss_choice_seed()` 가 `for seed in range(0, 256)`
   을 스윕해 **0 을 정당하게 반환**한다. `:215` 가
   `prepare_vertical_slice_combat(null, {"run_id":"skip-reentry", "map_seed": 0})`
   을 부르는데 새 `_resolve_prepare_map_seed` 가 `context_seed <= 0` 을
   `invalid_context_map_seed` 로 보고 push_error 한다.
   → `missing_authoritative_map_seed` 로 이어지고 **단언 6건 실패 + exit 1**.
   ⚠**세션이 이미 이 계열을 만나 `tower_ascent_enraged_marking_smoke.gd` 의
   `range(0,4096)` → `range(1,4096)` 을 고쳤다. 그런데 저장소를 훑어 나머지
   seed-0 픽스처를 찾지 않았다.**
2. **push_error 가 러너를 죽인다.** `_verify_arrival_routes_through_production_selector`
   (`:77`)가 게이트가 달지가 아닌 시드를 **탐색하는 정상 루프**에서
   `opening_boss_identity_mismatch` push_error 를 뿜는다.
   `run_smoke_tests.ps1` 은 `^\s*(SCRIPT ERROR|ERROR:|FATAL:)` 에 걸리면
   **exit 0 이어도 실패로 승격**한다(`godot_output_classifier.ps1`).
   **그 레그 하나만으로 스모크가 죽는다.**

### 수리

- **seed 0**: 0 을 정당한 생성 시드로 유지하고 **"없음"을 별도 센티널이나
  `context.has("map_seed")` 로 구분**하라. 픽스처를 `range(1, ...)` 로 미루는 것은
  **미봉이다** — 프로덕션에서 seed 0 이 나올 수 있다면(아래 I5 참조) 계약 자체가 틀렸다.
- **push_error → 상태 반환**: `opening_boss_identity_mismatch` 거부를
  push_error 가 아니라 **호출자가 로그할 상태 Dictionary** 로 돌려라.
  정당한 try-and-skip 탐색이 러너를 죽이면 안 된다.
- ★**저장소 전체에서 seed-0 픽스처와 identity-mismatch 탐색 루프를 전수로 훑어라.**
  ⚠`tower_ascent_boss_avoidance_smoke.gd`(나이틀리)도 **같은 원인으로 RED** 다.

## [P0] I2 — ★비전 보상 레인이 라이브에서 통째로 죽는다 (GRT-017)

`tower_reward_pick_offer_builder.gd:330` 신규 `_get_owner_value` 가
`owner.get_property_list()` 를 순회한다.

**프로덕션 owner 는 `scenes/main.tscn` → `scenes/main.gd` 이고 그것은
`extends "res://scripts/core/battle_scene_shell.gd"` 한 줄이다.**
`battle_scene_shell.gd` 는 `scene_state` / `gameplay_modules` /
`_battle_redraw_requested` 만 선언하고, `current_stage` ·
`stage1_boss_variant` · `stage_boss_variant` 는 `battle_scene_state.gd`
`DEFAULT_VALUES` 에 있고 **`_get`/`_set` 으로만 도달한다**
(shell `:121`, `:128`). `_get_property_list()` 오버라이드가 **없다.**

**엔진 동작 실측**: `var` 로 선언한 프로퍼티는 property list 에 있고,
`_get` 으로만 노출한 것은 `owner.get("current_stage")` 로 값은 나오지만
**property list 에는 없다.**

### 결과 (실 빌더 프로브)

```
shell_like.get(stage1_boss_variant) = dalji
_get_owner_value(current_stage, -1)  = -1          ← 폴백
_owner_boss_identity_matches_slot(shell_like, "floor_01_dalji") = false
```

→ `current_stage`=0 → `variant_property`="stage_boss_variant" →
`owner_variant`="" → `get_boss_slot_id_for_stage_variant(0,"")`="" →
`owner_slot_id.is_empty()` → **false 반환** →
`_build_vision_choice` 가 `:140` 에서 **`{}` 를 반환한다.**

**`floor_01_dalji` · `floor_01_gaksital` · `floor_02_cheongringwi` ·
`floor_03_yeonmyo` 전부. 네 비전이 타워 보상 픽으로 영영 안 나온다.**

⚠**씰은 GREEN 이다.** `tower_reward_pick_smoke.gd:69~73` 의 FakeOwner 가
실제 `var` 를 선언하기 때문에 이 결함을 **원천적으로 볼 수 없다.**

### 수리

**프로덕션 경로가 이미 쓰는 관용구로 바꿔라** —
`victory_loot_phase_state.gd:981`:

```gdscript
var value: Variant = owner.get(key)
return fallback if value == null else value
```

**씰**: 픽스처 owner 가 **`var` 선언이 아니라 `_get`/`_set` 으로 노출하는
shell 형태**인 레그를 추가하라. 그래야 실제 owner 스키마에 대해 증명된다.
⚠**GRT-017**(owner-field schema trap)의 정확한 재현이다.

⚠`tower_ascent_chest_context_builder._get_object_value` 도 **같은 결함**을
갖는다. 지시문이 "제3의 사본" 이라 부른 그것이다. 함께 고쳐라.

## [P0] I3 — fail-closed 게이트가 우회된다 (두 번째 M키)

`tower_ascent_flow_map_progress.gd:102` 가 `_build_generated_graph(current_stage)`
를 부르고, 그것이 `_activate_graph_phase(0,false)` 를 통해
`_graph_nodes.assign(nodes)` 를 **먼저 수행한다**(`:867`).

그 다음 `:112~114` 의 opening-identity 하드 거부가 **`_graph_nodes` 도
`_map_seed` 도 지우지 않고** false 를 반환한다.

`tower_ascent_flow_runtime.open_map_overlay` 는 `_graph_nodes.is_empty()` 일
때만 prepare 한다(`:135`).

→ **첫 M 누름은 거부되지만 거부된 그래프가 남는다. 두 번째 M 누름이 그것을 연다.**
실 `BattleTowerMapOverlayInputRouter` 로 헤드리스 재현 확인.

**수리**: 거부 시 `_graph_nodes` 와 `_map_seed` 를 **반드시 비워라.**
또는 identity 검사를 그래프 materialize **이전**으로 옮겨라.
**씰**: 거부 후 두 번째 open 시도가 여전히 거부되는지 단언하라.

## [P1] I4 — 지시문에 없던 게임플레이 변경: 변형 보스 4종 비전 보상 제거

원 지시문은 별건 발견 1을
**"관제탑 결정 대기 · 임의로 채우지 마라 · 보고만 하라"** 라고 명시했다.

세션은 테이블을 채우지는 않았지만, `victory_loot_phase_state._get_boss_vision_offer_id`
와 `tower_ascent_chest_context_builder._get_boss_vision_offer_id` 를
`VISION_UNLOCK_BY_BOSS_SLOT` 기반으로 **다시 써서 커버리지를 좁혔다.**

결과: **2·3층 변형 보스(지굴왕·거미각시·포웅귀·옥토선자) 격파 시 비전 초식
보상이 완전히 사라진다.** 라이브 타워 경로에도 적용된다. 프로브로 재현됨.

**수리**: 그 두 함수의 **기존 커버리지를 복원**하라. 3사본 통일 자체는 좋지만
**규칙을 바꾸지 말고 형태만 통일하라.** 커버리지 변경은 관제탑 결정 사항이다.

## [P1] I5 — 레거시(Tower OFF) 캠페인에서 2·3스테이지 비전 보상이 사라진다

`owner.stage_boss_variant` 가 스테이지 전환 때 갱신되지 않아
청린귀 용린노도 / 연묘 봉혼궤가 조용히 사라진다. 프로브 재현.

⚠**`cheongringwi_vision_chosik_smoke.gd` 픽스처에
`stage_boss_variant='cheongringwi'` 를 추가한 것이 이 회귀를 가린다.**
프로덕션 레거시 경로의 실제 값은 `'dalji'` 다.
**픽스처를 프로덕션 값으로 되돌리고 회귀를 드러내라.**

## [P1] I6 — `tower_map_seed == 0` 이 정당한 프로덕션 경로에서 도달한다

**온라인 로비**가 `request_tower_start_card_entry()` 를 **한 번도 부르지 않고**
`res://scenes/main.tscn` 에 진입한다. 그러면 `tower_map_seed` 가 0 이다.

지시문이 "그 경로를 타지 않은 진입은 0" 이라고 적었는데,
**세션은 그것을 "도달 불가" 로 읽고 하드 실패로 만들었다. 도달 가능하다.**

⚠연쇄: **I7** — `stage1_boss_variant_explicit` 우선권이 vertical slice ON
(프로덕션 기본값)에서 삭제돼, **온라인 로비의 1스테이지 보스가 항상 달지로 고정**된다.

**수리**: 온라인 로비 경로에 권위 시드를 발급하거나, 그 경로를 명시적으로
레거시 분기로 보내라. **하드 실패는 답이 아니다.**

## [P2] I8 — prepared-seed-mismatch 씰이 항진명제다

순수 리졸버 `_resolve_prepare_map_seed` 를 **직접 호출**하고 상태가 변형되지
않았다고 단언한다. 순수 함수니 당연히 안 변한다.
**실제 `prepare_vertical_slice_combat` 을 관통**시켜라.

## [P3] I9 — 신규 씰에 레그 계수 단언이 없다

`tower_map_seed_authority_smoke.gd` 는 레그가 조용히 스킵돼도 `ok` 를 출력한다.
실행된 레그 수를 단언하라(GRT-040 계열 예방).

## [P3] I10 — 성능

`_owner_boss_identity_matches_slot` 이 보상 오퍼 1회당 **레지스트리 전층 스캔
약 5회 + `get_property_list` 순회 2회**를 새로 추가하고,
`TowerAscentBossRegistry` 인스턴스를 2개 할당해 12층 전 보스 슬롯을 두 번
딥카피한다. I2 수리로 `get_property_list` 는 사라지지만 스캔은 남는다.
캐시하거나 인덱스를 쓰라.

## 확인된 무결 (재작업 금지)

- ★**시드 권위 형태가 옳다.** `GameSelectionState.tower_map_seed` 를 정본으로
  읽는 권장안을 택했고 **M키 진범이 진짜로 닫혔다.**
- **신규 씰 자체는 실효 씰이다** — 고의 파손 시 exit 1, 원복 해시 일치.
- **1스테이지 3사본 파리티는 정확하다.**
- **경고 스캔 · 헤드리스 로드 · 나머지 관련 스모크 33종 GREEN.**
- ✔**CI 항목 소실 없음.** X6 에 `yangui_hoechun_wave_contract_smoke.gd` 가
  빠져 있지만 **3-way 머지에서는 소실되지 않는다**(관제탑이 확인).

## 통합 충돌 (관제탑 실측)

| 조합 | 결과 |
|---|---|
| HEAD `6d436de71` × X6 `08d0fa6a7` | **무충돌** (트리 `7b02e171`) |
| HEAD × X1 `031d59beb` | 무충돌 |
| HEAD × X4 `60ba17525` | 충돌 2 (CI 파일) |
| HEAD × W4 `63859a498` | 충돌 3 |

## 게이트·보고

⚠**I1 · I2 · I3 를 먼저 닫아라.** 그 셋이 착지 차단 사유다.

포커스드 스모크 + **`tower_boss_routing_smoke` 와 `tower_ascent_boss_avoidance_smoke`
반드시 포함** → `run_warning_scan.ps1 -Paths <touched>` →
`run_headless_load_check.ps1` → `git diff --check` → 픽셀 QA.

⚠**헤드리스/스모크/스캔 실행 전 `godot/logs`를 통째로 복사하라**(없으면 그렇게 보고).
⚠래퍼는 `-AllowDuringPlay` 선언 + PID/타임스탬프 고유 `--log-file`.
**사용자의 게임·에디터를 절대 종료하지 마라.**

보고: 추가 커밋 해시 · **seed 0 계약을 어떻게 재설계했는지** ·
**shell 형태 owner 픽스처 레그 결과** · **두 번째 M 누름 거부 재현** ·
I4 커버리지 복원 확인 · I5 픽스처 되돌림 후 드러난 회귀 · I6 온라인 로비 처리 ·
seed-0 픽스처 전수 스윕 결과 · 미해결.
