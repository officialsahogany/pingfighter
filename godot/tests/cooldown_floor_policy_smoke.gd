extends SceneTree

# 최종 합성 쿨다운 하한(5%) 계약 씰 (2026-07-11 감사 합의).
# 계약: 기본 쿨다운이 양수면 모든 효과(퍽/연마/융합/천사의 주사위/신화 배수)
# 적용 후 최종 쿨다운은 기본값의 5% 미만으로 내려가지 않는다 (최대 95% 감소).
# 기본값이 의도적으로 0인 스킬·아이템은 계속 0이다.
# 커버 레그:
#  A. 스킬 배수 합성 — 단련×엔젤 붕괴(runtime 0) + 천상의 망토(item 0.85)에서
#     4개 캐릭터 config 최종 배수/쿨초가 5% 하한에 걸린다 (스냅샷 동일값 포함).
#  B. 아이템 msec — 숙련×주사위×엔젤 붕괴(퍽 체인 0) + Master 기어(신화 ×0.5)
#     에서 슬롯 컨트롤러 / 전투 HUD / TAB 3표면이 동일한 하한값을 읽는다.
#  C. 바이퍼 사독 경로 정확 0 경계 — 유효 0 입력은 기본값 복귀가 아니라
#     base×5%로 보정(불연속 제거), config 누락만 fallback.
#  D. 의도적 base 0 예외 — 스킬/아이템 모두 0 유지.
#  E. 카탈로그 하한 선언 문구(단련·숙련 detail) 봉인.

const ActiveItemCooldownComposer := preload("res://scripts/items/active_item_cooldown_composer.gd")
const ActiveItemHudState := preload("res://scripts/hud/active_item_hud_state.gd")
const ActiveItemSlotController := preload("res://scripts/items/active_item_slot_controller.gd")
const BlacksmithSkillConfig := preload("res://scripts/characters/blacksmith_skill_config.gd")
const CharacterInfoOverlayOwnerState := preload("res://scripts/hud/character_info_overlay_owner_state.gd")
const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const CooldownFloorPolicy := preload("res://scripts/characters/cooldown_floor_policy.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")
const ViperSkillConfig := preload("res://scripts/characters/viper_skill_config.gd")
const ViperSkillScaling := preload("res://scripts/characters/viper_skill_scaling.gd")

var _failures: Array[String] = []


class FakeCollapsedPerkState:
	extends RefCounted

	func get_active_item_cooldown_msec(_base_cooldown_msec: int) -> int:
		return 0


class FakeReducingPerkState:
	extends RefCounted

	func get_active_item_cooldown_msec(base_cooldown_msec: int) -> int:
		return int(round(float(base_cooldown_msec) * 0.4))


class FakeHalvingMythicRuntime:
	extends RefCounted

	func get_active_item_cooldown_msec(base_cooldown_msec: int) -> int:
		return int(float(base_cooldown_msec) * 0.5)


class FakeRegistry:
	extends RefCounted

	var runtime_perk_state: Object = null
	var mythic_item_runtime: Object = null

	func get_instance(key: String) -> Object:
		match key:
			"runtime_perk_state":
				return runtime_perk_state
			"mythic_item_runtime":
				return mythic_item_runtime
		return null


class FakeZeroCooldownSkillConfig:
	extends RefCounted

	func get_cooldown_seconds(_skill_name: String) -> float:
		return 0.0


class FakeFixedCooldownSkillConfig:
	extends RefCounted

	var cooldown_seconds := 0.0

	func get_cooldown_seconds(_skill_name: String) -> float:
		return cooldown_seconds


func _init() -> void:
	_verify_skill_config_multiplier_floor()
	_verify_skill_config_floor_boundary_continuity()
	_verify_active_item_three_surfaces_share_floored_value()
	_verify_active_item_normal_values_unchanged()
	_verify_viper_exact_zero_boundary()
	_verify_intentional_base_zero_stays_zero()
	_verify_catalog_floor_wording()

	if _failures.is_empty():
		print("cooldown_floor_policy_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error("cooldown_floor_policy_smoke FAIL: %s" % failure)
	quit(1)


# ---- Leg A: 스킬 배수 합성 (Training+Angel 붕괴 + Cape) ----
func _verify_skill_config_multiplier_floor() -> void:
	var configs := {
		"smasher": SmasherSkillConfig.new(),
		"viper": ViperSkillConfig.new(),
		"commando": CommandoSkillConfig.new(),
	}
	for label in configs.keys():
		var config: Object = configs[label]
		# 단련×엔젤 합성(runtime 배수)이 0까지 붕괴, 천상의 망토(item 배수) 0.85.
		config.set_runtime_cooldown_multiplier(0.0)
		config.set_item_cooldown_multiplier(0.85)
		var snapshot: Dictionary = config.get_snapshot()
		var snapshot_multiplier: float = float(snapshot.get("cooldown_multiplier", -1.0))
		_expect(
			absf(snapshot_multiplier - CooldownFloorPolicy.FINAL_COOLDOWN_MULTIPLIER_FLOOR) < 0.0001,
			"%s snapshot cooldown_multiplier should floor at 0.05 (got %f)" % [label, snapshot_multiplier]
		)
		var cooldown_seconds: Dictionary = config.COOLDOWN_SECONDS
		for skill_name in cooldown_seconds.keys():
			var base_seconds: float = float(cooldown_seconds[skill_name])
			if base_seconds <= 0.0:
				continue
			var final_seconds: float = float(config.get_cooldown_seconds(str(skill_name)))
			_expect(
				absf(final_seconds - base_seconds * 0.05) < 0.0001,
				"%s %s should floor at base*0.05 (base %f, got %f)" % [label, str(skill_name), base_seconds, final_seconds]
			)
	# 블랙스미스 placeholder config도 같은 합성 정책을 공유한다.
	var blacksmith := BlacksmithSkillConfig.new()
	blacksmith.set_runtime_cooldown_multiplier(0.0)
	blacksmith.set_item_cooldown_multiplier(0.85)
	_expect(
		absf(float(blacksmith.get_effective_cooldown_multiplier()) - 0.05) < 0.0001,
		"blacksmith effective multiplier should floor at 0.05"
	)


func _verify_skill_config_floor_boundary_continuity() -> void:
	# 하한 직전/직후에서 값이 단조 감소로 수렴하고 절대 튀지 않는다.
	var config := SmasherSkillConfig.new()
	config.set_item_cooldown_multiplier(1.0)
	config.set_runtime_cooldown_multiplier(0.06)
	var above_floor: float = float(config.get_cooldown_seconds("drive"))
	config.set_runtime_cooldown_multiplier(0.001)
	var at_floor: float = float(config.get_cooldown_seconds("drive"))
	_expect(absf(above_floor - 15.0 * 0.06) < 0.0001, "0.06 multiplier should pass through unfloored")
	_expect(absf(at_floor - 15.0 * 0.05) < 0.0001, "collapsed multiplier should clamp to base*0.05")
	_expect(at_floor <= above_floor, "floored value must not jump above the pre-floor neighbor")


# ---- Leg B: 아이템 msec 3표면 동일값 (Mastery+Dice+Angel 붕괴 + Master 기어) ----
func _verify_active_item_three_surfaces_share_floored_value() -> void:
	var base_msec := 7000
	var expected_msec: int = int(ceilf(float(base_msec) * 0.05))
	var perk_state := FakeCollapsedPerkState.new()
	var mythic_runtime := FakeHalvingMythicRuntime.new()
	var registry := FakeRegistry.new()
	registry.runtime_perk_state = perk_state
	registry.mythic_item_runtime = mythic_runtime

	var composer_msec: int = ActiveItemCooldownComposer.compose_effective_cooldown_msec(base_msec, perk_state, mythic_runtime)
	_expect(composer_msec == expected_msec, "composer should floor 7000ms to %dms (got %d)" % [expected_msec, composer_msec])

	var slot_controller := ActiveItemSlotController.new()
	var item_data := {"cooldown_msec": base_msec}
	var gameplay_msec: int = slot_controller._get_effective_active_item_cooldown_msec(item_data, registry)
	var hud_state := ActiveItemHudState.new()
	var hud_msec: int = hud_state.get_active_item_cooldown_msec(item_data, registry)
	var tab_msec: int = CharacterInfoOverlayOwnerState.active_item_cooldown_from_base(
		base_msec,
		[perk_state, null, mythic_runtime, null],
		Callable(CharacterInfoOverlayOwnerState, "apply_stat_chain")
	)
	_expect(gameplay_msec == expected_msec, "slot controller should floor to %dms (got %d)" % [expected_msec, gameplay_msec])
	_expect(hud_msec == gameplay_msec, "battle HUD must read the same floored value as gameplay (%d vs %d)" % [hud_msec, gameplay_msec])
	_expect(tab_msec == gameplay_msec, "TAB info panel must read the same floored value as gameplay (%d vs %d)" % [tab_msec, gameplay_msec])


func _verify_active_item_normal_values_unchanged() -> void:
	# 하한이 정상 범위 수치를 왜곡하지 않는다 (60% 감소 → 그대로 통과).
	var perk_state := FakeReducingPerkState.new()
	var normal_msec: int = ActiveItemCooldownComposer.compose_effective_cooldown_msec(7000, perk_state, null)
	_expect(normal_msec == 2800, "normal 60%% reduction should pass through unfloored (got %d)" % normal_msec)


# ---- Leg C: 바이퍼 사독 경로 정확 0 경계 ----
func _verify_viper_exact_zero_boundary() -> void:
	var scaling := ViperSkillScaling.new()
	var zero_config := FakeZeroCooldownSkillConfig.new()
	var floored: float = _four_poisons_cooldown(scaling, zero_config)
	_expect(
		absf(floored - 40.0 * 0.05) < 0.0001,
		"valid zero configured cooldown should floor to base*0.05, not reset to base (got %f)" % floored
	)
	var near_zero_config := FakeFixedCooldownSkillConfig.new()
	near_zero_config.cooldown_seconds = 0.01
	var near_zero: float = _four_poisons_cooldown(scaling, near_zero_config)
	_expect(
		absf(near_zero - 40.0 * 0.05) < 0.0001,
		"near-zero configured cooldown should land on the same floor (continuity, got %f)" % near_zero
	)
	var mid_config := FakeFixedCooldownSkillConfig.new()
	mid_config.cooldown_seconds = 3.0
	var mid: float = _four_poisons_cooldown(scaling, mid_config)
	_expect(absf(mid - 3.0) < 0.0001, "3.0s configured cooldown should pass through (got %f)" % mid)
	_expect(near_zero <= mid, "cooldown must decrease monotonically toward the floor (no discontinuity)")
	var missing: float = _four_poisons_cooldown(scaling, null)
	_expect(absf(missing - 40.0) < 0.0001, "missing config must still fall back to the base cooldown (got %f)" % missing)


func _four_poisons_cooldown(scaling: Object, skill_config: Object) -> float:
	return float(scaling.get_four_poisons_additive_cooldown_seconds(
		"nerve_strike",
		skill_config,
		40.0,
		0,
		[0],
		0,
		0,
		"nerve_strike",
		"dive_strike",
		"chaos_spear",
		"dual_glitch"
	))


# ---- Leg D: 의도적 base 0 예외 ----
func _verify_intentional_base_zero_stays_zero() -> void:
	_expect(CooldownFloorPolicy.floor_final_msec(0, 0) == 0, "base 0 msec must stay 0")
	_expect(
		absf(CooldownFloorPolicy.floor_final_seconds(0.0, 0.0)) < 0.0001,
		"base 0 seconds must stay 0"
	)
	var perk_state := FakeCollapsedPerkState.new()
	var mythic_runtime := FakeHalvingMythicRuntime.new()
	var zero_item_msec: int = ActiveItemCooldownComposer.compose_effective_cooldown_msec(0, perk_state, mythic_runtime)
	_expect(zero_item_msec == 0, "base-0 active item cooldown must stay 0 (got %d)" % zero_item_msec)
	var smasher := SmasherSkillConfig.new()
	smasher.set_runtime_cooldown_multiplier(0.0)
	_expect(
		absf(float(smasher.get_cooldown_seconds("__unknown_skill__"))) < 0.0001,
		"unknown/base-0 skill cooldown must stay 0 even with the multiplier floored"
	)
	var blacksmith := BlacksmithSkillConfig.new()
	blacksmith.set_runtime_cooldown_multiplier(0.0)
	_expect(
		absf(float(blacksmith.get_cooldown_seconds("anything"))) < 0.0001,
		"blacksmith placeholder base-0 cooldown must stay 0"
	)


# ---- Leg E: 카탈로그 하한 선언 문구 ----
func _verify_catalog_floor_wording() -> void:
	var catalog := RuntimePerkCatalog.new()
	for perk_id in ["common_training", "item_cooldown_mastery"]:
		var data: Dictionary = catalog.get_perk_data(perk_id)
		var detail: String = str(data.get("detail", ""))
		_expect(
			detail.find("5% 미만") >= 0 and detail.find("95%") >= 0,
			"%s detail should declare the 5%% final-cooldown floor (got: %s)" % [perk_id, detail]
		)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
