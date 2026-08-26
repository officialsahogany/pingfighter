# 지시문 X6 — [P0] 전투 중 M키 지도가 잘못된 시드로 그래프를 선생성해 런 전체를 오염시킨다

- **발행**: 관제탑 2026-08-26. 기준선 = 본 트리 `f838df056`.
  **격리 워크트리 + 격리 브랜치.** 본 트리 편집·통합·푸시 금지.
- **증상 신고**: "달지를 클리어했는데 승리 보상에 각시탈 비전초식
  `부채던지기 비급`(무혼 3)이 나온다."
- **판정**: 보상 결함이 **아니다.** 비전 오퍼의 보스 게이트는 존재하고 정상
  동작한다. 진짜 결함은 **지도 시드 권위 구멍**이고, 피해 범위가 보상보다
  훨씬 넓다 — **1층 지도 그래프 전체가 선택 화면과 다른 시드로 만들어진다.**

---

## ★진범 (라이브 로그 백트레이스로 확정 · 관제탑이 직접 확인)

로그: `C:\Users\woduq\AppData\Roaming\Godot\app_userdata\pingfighter\logs\godot.log`

**4행 — 선택 시점은 정상이다**

```
[TowerAscent] floor1_identity map_seed=1998965459 opening_variant=dalji gate_slot=floor_01_dalji
```

**220행 — 그런데 그래프 노드는 각시탈이다**

```
WARNING: [TowerAscent] boss identity mismatch node=floor_01_gatekeeper
  issues=["opening_gate_mismatch=floor_01_gatekeeper:opening_1:dalji:gate_1:gaksi"]
   GDScript backtrace (most recent call first):
       [0] _warn_boss_identity_mismatch  (tower_ascent_flow_state.gd:432)
       [1] prepare_vertical_slice_combat (tower_ascent_flow_map_progress.gd:95)
       [2] open_map_overlay              (tower_ascent_flow_runtime.gd:138)
       [3] handle_open_shortcut          (battle_tower_map_overlay_input_router.gd:22)
       [4] handle_unhandled_input        (battle_scene_input_controller.gd:103)
       [5] _unhandled_input              (battle_scene_shell.gd:218)
```

**즉 플레이어가 전투 중 M키를 눌러 지도를 연 것이 그래프를 선생성했다.**

### 체인

1. `battle_tower_map_overlay_input_router.gd:26` — `open_map_overlay`에
   `{"current_stage": N}` **만** 넘긴다. **`map_seed`가 없다.**
   ⚠`git log -S'map_seed' -- <이 파일>` 결과 **0건** = 이 파일은 `map_seed`를
   가진 적이 한 번도 없다.
2. `tower_ascent_flow_runtime.gd:138` — `_graph_nodes`가 비었으면 그 컨텍스트로
   `prepare_vertical_slice_combat`을 호출한다.
3. `tower_ascent_flow_map_progress.gd:80` —
   `_map_seed = int(context.get("map_seed", ... _derive_map_seed(run_id, current_stage)))`
   컨텍스트에 시드가 없으니 **조용히 전혀 다른 시드로 도망간다.**
   `tower_ascent_flow_state.gd:463` `_derive_map_seed = absi(hash("%s:%d:%s"))` —
   선택 시드 `1998965459`와 무관하다.
   ⚠run_state가 시작 전이면 `run_id` 자체가 `vertical-slice-<ticks_msec>`라
   **비결정적**이다.
4. 그 시드로 `floor_01_gatekeeper`가 `floor_01_gaksital`(gate_1:gaksi)로 배정된다.
5. **★고착** — `tower_ascent_flow_map_progress.gd:38` `if _prepared: return true`.
   이후 승리 경로(`battle_scene_match_flow_driver.gd:288` → `:411~413`)가
   **올바른 `map_seed`를 싣고 와도 조기 반환되어 무시된다.**
   잘못된 시드 그래프가 **런 전체에 영구화**된다.
6. 보상 픽은 `_current_node_id`의 `boss_slot_id`만 읽으므로
   (`tower_ascent_flow_map_progress.gd:341~353`, `:365~375`)
   각시탈 비급을 **규칙대로** 제시한다.
7. 불일치는 **감지된다.** 그런데 `tower_ascent_flow_state.gd:432`
   `_warn_boss_identity_mismatch`가 `push_warning` 한 줄만 하고
   **교정도 거부도 하지 않는다.**

## ★피해 범위 — 보상이 아니라 지도 전체다

사용자가 본 것은 잘못된 비급 카드 하나지만, 실제로는 **그 런의 1층 지도
그래프 전체가 선택 화면이 약속한 것과 다른 시드로 만들어져 있다.**
노드 배치·보스 슬롯·경로가 전부 어긋난다. 보상 카드는 그 결과의 한 증상일 뿐이다.

그리고 **런 내내 지속된다**(5번 고착).

## 회귀 아님 — GRT-058의 정확한 변종

- 지목했던 후보 4개 커밋(`87e497d77` W1 / `efaf3ffc9` W5 / `6ae64d487` W3 /
  `a325ffc29` Q4) **어느 것도 원인이 아니다.**
- 관련 `.gd` 전부 working tree clean → **미커밋 WIP 탓도 아니다.**
- 도입: **`979477726` `기능(탑): M 지도 개폐와 물리차단 수명주기`(2026-08-18)** —
  이 진입점이 처음부터 `map_seed`를 안 실었다.
- **`12820a6aa` `fix(tower): 1층 보스 정체성 단일 시드 통일 (피드백4 I2)`(2026-08-24)**
  가 "시드 = 단일 권위"를 세울 때 승리 경로(`_build_tower_flow_context`)와
  `resolve_stage1_boss_variant`만 배선하고 **M 오버레이 문은 상속시키지 않았다.**
- ⚠**GRT-058**: "새 진입점은 형제 모달의 훅을 상속하지 않는다"의 정확한 변종이다.
- `8e0421767`(S8, 1층 선택형 보스)이 1층 전투 노드를 1개→3개로 늘려
  이 결함의 **가시성**을 크게 높였다(원인은 아니다).

## 반증 완료 (재조사 금지)

- ✔**보스 게이트는 존재하고 정상 동작한다.**
  `tower_ascent_boss_reward_catalog.gd:10` `VISION_UNLOCK_BY_BOSS_SLOT` =
  `{floor_01_dalji, floor_01_gaksital, floor_02_cheongringwi, floor_03_yeonmyo}`.
- ✔**설계 의도가 명문화돼 있다.** 같은 파일 `:7~9` 주석:
  "선택된 지도 보스 슬롯이 보스별 보상의 유일한 권위이며, 스테이지/대역 보스
  ID는 표시·라우팅 호환 필드이므로 **다른 보스의 비전을 나오게 해선 안 된다.**"
  → "무차별이 의도" 가설은 **기각**이다.
- ✔**보스 무관 오퍼 풀은 없다.** `_build_basic_pool`은 무공·융합만 담는다.
  비전 레인의 유일한 생산 소스는
  `tower_reward_pick_offer_builder.gd:62` `_build_vision_choice`이고
  `:70`에서 `reward_pick_kind = "vision"`, `:30` `TEMP_VISION_COST := 3`
  (관측된 무혼 3과 일치)로 확정된다.
- ✔**"비급" 라벨의 출처**는 rarity 필드가 아니라
  `common_skill_catalog.gd:485` `"is_skill_manual": true` →
  `runtime_perk_overlay_renderer.gd:5042`.
- ✔**2층 이후 노드는 이 괴리가 없다.**
  `tower_ascent_flow_ending_progress.gd:361~376`이 도착 노드에서 encounter를
  재구성해 노드 = 전투가 구조적으로 보장된다. 결함은 **런의 첫 전투 한 판**에
  국한된다.
- ✔**잘못 얻은 비급은 정상 발동한다.** 죽은 보상이 아니라 **밸런스 결함**이다.
- ✔**세이브 스코프는 런 한정**이다. `runtime_skill_levels`는 디스크에 저장되지
  않고 `runtime_perk_reset_state`가 리셋에서 비운다. 마이그레이션 불필요.

## 수리 (우선순위 순)

### [P0] 1 — 시드 권위 구멍을 닫아라

**최소안**: `battle_tower_map_overlay_input_router.handle_open_shortcut`이
`battle_scene_match_flow_driver._get_tower_map_seed`와 **같은 값**을 컨텍스트에
싣는다.

**★권장안**: 진입점마다 시드 조회를 복제하지 말고,
`prepare_vertical_slice_combat`이 컨텍스트에 `map_seed`가 없을 때
`_derive_map_seed`로 **조용히 도망가는 대신**
`/root/GameSelectionState.tower_map_seed`를 정본으로 읽게 하라.
그래야 **다음 진입점이 또 생겨도 상속된다.** 이 결함의 재발을 구조적으로 막는
유일한 형태다.

⚠`_derive_map_seed` 폴백을 남길 거면 **경고가 아니라 명시적 실패**로 만들거나,
최소한 그 런에서 vision 오퍼 레인을 비활성화하라(잘못된 비급을 주느니 안 주는
편이 낫다).

### [P1] 2 — 고착을 풀어라

`tower_ascent_flow_map_progress.gd:38` `if _prepared: return true` 가
**"이미 준비됨"만 보고 어떤 시드로 준비됐는지 검사하지 않는다.**

준비된 `_map_seed`와 요청 시드가 다르면 **재생성하거나 최소한 `push_error`로
실패**시켜라. 지금은 첫 준비가 무엇이든 그것이 런 전체의 진실이 된다.

⚠재생성을 택하면 **이미 진행된 노드 상태·방문 이력이 날아가는지** 확인하라.
날아가면 재생성이 아니라 실패 쪽이 맞다.

### [P2] 3 — 경고를 계약으로 승격하라

`tower_ascent_flow_state.gd:432` `_warn_boss_identity_mismatch`가 warn-only다.
1층 `opening_gate_mismatch`는 **실패 처리하거나 관문 노드를 개막 변형으로
교정**해야 한다.

⚠`repair_boss_node_identity` / `reseed_gatekeeper_boss_node_identity`가
**이미 존재하는데 프로덕션 호출자가 0건**이다. 죽은 API를 되살리는 것이
정답인지, 새로 만드는 것이 정답인지 판단해 보고하라.

⚠**교정을 택하면 시점이 결정적이다.** `owner.stage1_boss_variant`를 게이트
슬롯 값으로 정정하는 방식은 **반드시 `battle_resources` 프리웜 이전**이어야
한다. 프리웜 이후에 신원만 바꾸면 잘못된 보스 시트를 먼저 로드하고
**GRT-042**(전환 프레임 스톨) + 보스 스프라이트 오로드가 터진다.

### [P3] 4 — 오퍼 측 최후 방어선

`_build_vision_choice`는 **이미 `owner`를 인자로 받는다**
(`tower_reward_pick_offer_builder.gd:130~136`).
**추가 배선 없이** `owner.current_stage` + `owner.stage1_boss_variant` /
`stage_boss_variant`를 `StageBossVariantCatalog`로 슬롯 정규화해
노드 `boss_slot_id`와 대조하고 **불일치면 fail-closed** 할 수 있다.

> **값은 이미 도착해 있고, 읽히지 않을 뿐이다.**

⚠조회 수 단언(`tower_reward_pick_smoke:871`/`:883`)이 살아 있다.
새 `get_snapshot()` / `get_perk_slot_status()` 호출을 늘리지 마라.

## 함께 확인할 잠재 우회로 2건 (정적 판독 · 이번 사고의 원인은 아님)

`resolve_stage1_boss_variant`에 시드 게이트를 **완전히 우회하는 두 갈래**가
따로 있다. 이번 로그의 원인은 아니지만 같은 괴리를 만들 수 있다.

1. `battle_scene_selection_startup_lifecycle.gd:123~125` —
   `selection.stage1_boss_variant_explicit == true` 이면 시드 게이트를 아예
   조회하지 않고 고정 변형을 반환한다.
   ⚠`battle_scene_match_event_driver._sync_selection_stage()`가
   **모든 탑 1층 노드 전환에서 `explicit=true`로 고정**한다(`:483~490`).
   `stage_debug_picker.gd:462`도 같은 플래그를 세운다.
2. `battle_scene_selection_startup_lifecycle.gd:143~148` —
   `tower_map_seed == 0` 이면 `push_warning` 후 옛 룰렛
   (`select_random_stage1_boss_variant`)으로 무작위 1/3 선택한다.
   시드는 `request_tower_start_card_entry()`에서만 발급되므로 그 경로를 타지
   않은 진입은 0이다.

**둘 다 닫을지, 이번엔 P0만 닫고 별건으로 남길지 판단해 보고하라.**

⚠**제3의 사본**: `tower_ascent_chest_context_builder.gd:65~77`도 동일한
`stage1_boss_variant` 기반 분기를 별도로 갖고 있다(수직 슬라이스 OFF 경로).
권위를 고칠 때 이 사본을 빠뜨리면 **반쪽 착지(GRT-031)** 다.

## 씰 요구

1. **★진범 씰(필수)**: `map_seed` 없는 컨텍스트로 `open_map_overlay` →
   `prepare_vertical_slice_combat`을 태운 뒤, 이후 올바른 `map_seed`로 준비를
   요청하면 **그래프가 그 시드를 따르는지** 단언하라.
   현행 구현으로 되돌리면 RED가 되는지 **반증**하라.
2. **신원 교차검증 씰(필수)**: 시작 관문 노드의 `boss_slot_id`에서 파생한
   `canonical_encounter_key`와 실제 교전 encounter key가 다른 픽스처에서
   `_build_vision_choice()`가 `{}`를 반환함을 단언하라.
   ⚠**지금 이 경로를 덮는 씰이 저장소에 하나도 없다.**
3. **`floor_one_boss_identity_smoke.gd` 레그 확장**(기존 `:277` 계약의 구멍):
   - `selection.stage1_boss_variant_explicit=true` 픽스처에서
     `resolve_stage1_boss_variant()`가 시드 게이트 변형과 같은지 단언, 다르면 RED
   - `tower_map_seed=0` 픽스처에서 "경고만 내고 넘어가지 않음"
     (정정 또는 vision 레인 비활성) 단언
4. **레거시 승리상자 경로 교차 단언**:
   `victory_loot_phase_state._get_boss_vision_offer_id`는
   `owner.stage1_boss_variant`를, 탑 보상픽은 `node.boss_slot_id`를 읽는다.
   **서로 다른 소스인데 이를 잇는 씰이 없다.** 같은 보스 판정을 내는지 단언하라.
5. **비결정성 씰**: run_state 시작 전 `_derive_map_seed`가
   `vertical-slice-<ticks_msec>`를 쓰는 경로가 남아 있다면, 같은 입력에서
   두 번 준비했을 때 같은 그래프가 나오는지 단언하라.
6. **CI/pre-push 락스텝**: 신규 스모크는 `godot-ci.yml`과
   `run_pre_push_checks.ps1` **양쪽 동시 등재**(현재 244/244).

## 별건 발견 2건 (이 지시문 범위 밖 · 보고만 하라)

1. **★`VISION_UNLOCK_BY_BOSS_SLOT` 커버리지 공백.**
   `floor_02_molewang` / `floor_02_arachne` / `floor_03_teddy_bear` /
   `floor_03_alice` **4개 슬롯에 매핑이 없다.**
   그 슬롯이 층 관문으로 뽑히면 **청린귀·연묘 비전이 그 런에서 획득 불가**가
   된다. W3(`6ae64d487`)가 2·3층 보스 다양성을 보장하면서 이 슬롯이 뽑힐
   빈도를 올렸으므로 노출이 커졌다.
   (테이블 공백은 확인됨, 빈도 증가는 추론.)
   → 매핑을 추가할지(변형도 같은 비전을 준다) 의도적 공백으로 문서화할지
   **관제탑 결정 대기**. 임의로 채우지 마라.
2. **지도 첫 열기 374ms 스파이크.** 같은 로그에
   `draw.scene.tower_fullscreen_map avg=373.96ms max=373.96ms n=1`.
   콜드 오픈 비용이다. GRT-042/GRT-043 계열로 별도 추적한다.

## ⚠병행 작업 충돌

현재 5개 세션이 동시에 돌고 있다.

- **X4(`vision_modifier_movement_latch`)와 파일이 겹치지 않는다.**
  X4는 `vision_modifier_input_proxy.gd` / `vision_input_exclusive_policy.gd` /
  `battle_scene_actor_update_driver.gd` 입력 계층이고, 이 지시문은
  `battle_tower_map_overlay_input_router.gd` / `tower_ascent_flow_*` /
  `tower_reward_pick_offer_builder.gd` 다.
- ⚠**★X4를 이 버그의 수리로 계상하지 마라.**
  X4가 착지하면 각시탈은 좌우 차단 대상에서 빠져 "엉뚱한 비급을 얻으면 이동이
  막힌다"는 **관측 증상만 사라지고**, 잘못된 지급 자체는 **무증상으로 잠복**한다.
  역방향 위험도 있다 — 잘못 얻은 비전이 **청린귀**면 X4 이후에도 좌우 차단이
  그대로 걸린다.
- ⚠**X1(수호의 샘터)이 `battle_scene_input_controller.gd:207~232`
  오버레이 화이트리스트를 건드린다.** 이 지시문은 같은 파일의 `:103`
  호출 체인을 지나가지만 편집하지 않는 것이 정상이다.
  편집이 필요해지면 **관제탑에 먼저 보고하라.**

## 게이트·보고

포커스드 스모크(+RED 반증) → `run_warning_scan.ps1 -Paths <touched>` →
`run_headless_load_check.ps1` → `git diff --check` →
**라이브 1판(1층 전투 중 M키를 눌러 지도를 연 뒤 승리해 보상 확인)**.

⚠**헤드리스/스모크/스캔 실행 전 `godot/logs`를 통째로 복사하라.**
⚠래퍼는 `-AllowDuringPlay` 선언 + PID/타임스탬프 고유 `--log-file`.
**사용자의 게임·에디터를 절대 종료하지 마라.**
⚠`gaksital_vision_input_exclusivity_smoke`는 HEAD에서 이미 RED 2건
(`:739`, `:771`, 원인 = 미커밋 `smasher_overdrive_state.gd`). 실패 집합이
정확히 그 2건인지 바이트 대조하라.
⚠`dalji_vision_chosik_smoke.gd`는 pre-push 미등재 · nightly 전용이다.
focused CI GREEN을 이 계열의 근거로 삼지 마라.

보고: 커밋 해시 · 채택한 시드 권위 형태(최소안 vs 권장안)와 근거 ·
씰 종단선 **원문** · RED 반증 출력 · 고착 해제 방식(재생성 vs 실패)과
노드 상태 보존 확인 · 우회로 2건 처리 여부 · `chest_context_builder` 사본 처리 ·
**라이브 1판에서 M키를 눌렀을 때 mismatch 경고가 사라졌는지** · 미해결.
