# 지시문 Z2 — [P1] 탑 수련 퍽 오퍼가 캐릭터와 무관하게 항상 스매셔로 생성된다

- **발행**: 관제탑 2026-08-26. 기준선 = 본 트리 `ea31a7436`.
  **격리 워크트리 + 격리 브랜치.** 본 트리 편집·통합·푸시 금지.
- **성격**: X6 착지 검증 중 관제탑이 찾은 **선재 결함**이다. 최근 착지 8건과
  무관하다. 기준선 `f838df056` 에도 본 트리 HEAD 에도 있다.
- **크기**: 수리 자체는 작다(한 함수). **스윕이 본체다.**

---

## 관측 (관제탑 직접 확인)

`godot/scripts/tower_ascent/tower_ascent_training_offer_builder.gd:313`

```gdscript
var character_type := str(_get_object_value(owner, "selected_character_type", "smasher"))
```

이 값이 바로 아래에서 `perk_catalog.get_choices(character_type, ...)` 로 들어간다.

`:408~414` 의 `_get_object_value` 가 **`owner.get_property_list()` 를 순회**한다.

```gdscript
func _get_object_value(owner: Object, key: String, fallback: Variant) -> Variant:
	if owner == null:
		return fallback
	for property in owner.get_property_list():
		if str(property.get("name", "")) == key:
			return owner.get(key)
	return fallback
```

## 왜 항상 폴백인가 (GRT-017)

- 프로덕션 owner = `scenes/main.tscn` → `scenes/main.gd`, 그것은
  `extends "res://scripts/core/battle_scene_shell.gd"` 한 줄이다.
- `battle_scene_shell.gd` 가 선언한 `var` 는 **정확히 셋**이다 —
  `scene_state`, `gameplay_modules`, `_battle_redraw_requested`.
  ⚠**`selected_character_type` 은 없다.**
- 그 필드는 `godot/scripts/core/battle_scene_state.gd:99` 의 `DEFAULT_VALUES`
  에 있고 **`_get`/`_set` 으로만 도달**한다. `_get_property_list()` 오버라이드는 없다.
- Godot 은 `_get` 으로만 노출한 이름을 **property list 에 넣지 않는다.**
  `owner.get("selected_character_type")` 는 값을 주지만 순회로는 못 찾는다.

**결과: 항상 `"smasher"` 폴백.**

## 도달 경로 (확인됨)

`tower_reward_pick_offer_builder.gd:225` 가
`_training_builder.build_offer(..., owner, ...)` 로 **같은 owner 를 그대로
넘긴다**(`:38` 에서 인스턴스를 들고 있다).

**즉 바이퍼·코만도·블랙스미스·옵티머스로 플레이해도 탑 수련 노드의 퍽 오퍼가
스매셔 기준으로 생성된다.**

## 이미 같은 결함이 두 번 잡혔다

X6-수정(`6cc32d3ec`)이 **똑같은 패턴 두 사본**을 고쳤다.

- `tower_reward_pick_offer_builder.gd` — 비전 보상 레인이 통째로 죽어 있었다
- `tower_ascent_chest_context_builder.gd`

**정본 관용구는 `victory_loot_phase_state.gd:981` 이다:**

```gdscript
var value: Variant = owner.get(key)
return fallback if value == null else value
```

## 수리

1. `_get_object_value` 를 위 관용구로 교체하라.
2. ★**저장소 전수 스윕(본체).** `get_property_list()` 로 owner/target 을
   읽는 곳을 **전부** 찾아 각각 판정하라.
   ⚠관제탑이 확인한 남은 후보:
   `godot/scripts/ui/stage_clear_result_scene_field_applier.gd:43`
   (`target.get_property_list()`). 그것이 같은 계열인지, 다른 종류의 target
   (선언형 노드)이라 무해한지 **판정해 보고하라.**
   ⚠다른 형태도 찾아라 — `has_method` 로 게이트한 뒤 property list 를 보는 것,
   `property_list` 를 캐시해 두는 것 등.
3. 판정 결과를 **표로** 보고하라 — 파일:라인 / owner 종류 / 결함 여부 / 조치.

## 씰 요구

1. ★**shell 형태 픽스처(필수).** 픽스처 owner 가 `var` 선언이 아니라
   **`_get`/`_set` 으로 노출**하는 형태여야 한다.
   ⚠`var` 를 선언한 FakeOwner 로는 이 결함을 **원천적으로 볼 수 없다.**
   X6 에서 씰이 GREEN 인 채로 비전 레인이 죽어 있던 이유가 정확히 그것이다.
2. **비스매셔 레그**: shell 형태 owner 에 `selected_character_type` 을
   스매셔가 아닌 값으로 두고, 수련 오퍼가 **그 캐릭터의 퍽**으로 생성됨을 단언하라.
   ⚠`get_choices` 반환에서 캐릭터 전용 퍽이 실제로 나오는지 봐야 한다.
   "호출됐다" 로는 부족하다.
3. **RED 반증**: `get_property_list()` 순회로 되돌리면 그 레그가 RED 가 되는지
   확인하고 **원상복구**하라.
4. 신규 씰을 만들면 `godot-ci.yml` 과 `run_pre_push_checks.ps1` **양쪽 동시 등재**.
   ⚠**현재 247/247 이다. 통째 교체하지 말고 필요한 줄만 추가하라.**
   최근 통째 교체로 형제 씰이 소실된 사고가 있었다.

## 게이트·보고

포커스드 스모크(+RED 반증) → `run_warning_scan.ps1 -Paths <touched>` →
`run_headless_load_check.ps1` → `git diff --check`.

⚠**헤드리스/스모크/스캔 실행 전 `godot/logs`를 통째로 복사하라**(없으면 그렇게 보고).
⚠래퍼는 `-AllowDuringPlay` 선언 + PID/타임스탬프 고유 `--log-file`.
**사용자의 게임·에디터를 절대 종료하지 마라.**

보고: 커밋 해시 · **전수 스윕 결과표** · shell 형태 픽스처 레그 종단선 ·
RED 반증 출력 · 미해결.

## 알려진 선재 RED (이 작업 탓 아님)

- 전체 경고 스캔 RED — 파스 오류 경로 테스트 17 + 도구 2.
  CI 등재 3건(`character_info_stat_source_attribution_smoke`,
  `lingpet_mokrin_transform_registration_smoke`,
  `perk_fusion_cold_boot_cinematic_smoke`)은 도입 시점부터 무효였다.
- `tower_ascent_flow_owner_refactor_smoke` — `tower_ascent_flow_runtime.gd`
  710줄 vs 500줄 예산.
