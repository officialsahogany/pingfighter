extends SceneTree

const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")
const CommandoFirearmPistolHitState := preload("res://scripts/characters/commando_firearm_pistol_hit_state.gd")
const CommandoFirearmProfileResolver := preload("res://scripts/characters/commando_firearm_profile_resolver.gd")
const CommandoFirearmProjectileSpawnState := preload("res://scripts/characters/commando_firearm_projectile_spawn_state.gd")
const CommandoFirearmSelectorRenderer := preload("res://scripts/hud/commando_firearm_selector_renderer.gd")
const CommandoFirearmTooltipRenderer := preload("res://scripts/hud/commando_firearm_tooltip_renderer.gd")
const CommandoWeaponController := preload("res://scripts/characters/commando_weapon_controller.gd")
const CharacterInfoOverlayLayoutUtils := preload("res://scripts/hud/character_info_overlay_layout_utils.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")

var _failures: Array[String] = []


class FakePerkState:
	extends RefCounted

	var level := 0

	func get_runtime_skill_level(skill_id: String) -> int:
		if skill_id == "pistol_enhance":
			return level
		return 0


func _init() -> void:
	_verify_spread_table_and_beretta_isolation()
	_verify_speed_table_and_beretta_isolation()
	_verify_knockback_table_and_hit_isolation()
	_verify_ammo_table_overflow_and_reapply()
	_verify_same_max_does_not_refill_spent_ammo()
	_verify_tooltip_uses_effective_base_magazine()
	_verify_icon_path_and_badge_policy()

	if _failures.is_empty():
		print("commando_pistol_enhance_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_spread_table_and_beretta_isolation() -> void:
	var runtime := CommandoFirearmRuntime.new()
	var perk_state := FakePerkState.new()
	var expected_spread := {
		0: CommandoFirearmRuntime.PISTOL_SPREAD_RADIANS,
		1: deg_to_rad(12.0),
		2: deg_to_rad(9.0),
		3: deg_to_rad(6.0),
		4: deg_to_rad(3.0),
		5: deg_to_rad(1.0),
		6: deg_to_rad(1.0),
		7: deg_to_rad(1.0),
	}
	for level in expected_spread.keys():
		perk_state.level = int(level)
		var options: Dictionary = runtime._build_firearm_spawn_options({"runtime_perk_state": perk_state})
		_expect(
			is_equal_approx(float(options.get("pistol_spread_radians", 0.0)), float(expected_spread[level])),
			"pistol_enhance Lv.%d should set base pistol spread to %.4f" % [level, float(expected_spread[level])]
		)
		_expect(
			is_equal_approx(float(options.get("beretta_spread_radians", 0.0)), CommandoFirearmRuntime.BERETTA_SPREAD_RADIANS),
			"pistol_enhance Lv.%d should not alter Beretta spread" % level
		)


func _verify_speed_table_and_beretta_isolation() -> void:
	var runtime := CommandoFirearmRuntime.new()
	var perk_state := FakePerkState.new()
	var weapon_profiles := {
		"pistol": {
			"kind": "bullet",
			"speed": CommandoFirearmRuntime.PISTOL_BULLET_SPEED,
		},
		"commando_pistol": {
			"kind": "bullet",
			"speed": CommandoFirearmRuntime.BERETTA_BULLET_SPEED,
		},
	}
	var expected_mult := {
		0: 1.0,
		1: 1.1,
		2: 1.2,
		3: 1.3,
		4: 1.4,
		5: 1.5,
		6: 1.5,
		7: 1.5,
	}
	for level in expected_mult.keys():
		perk_state.level = int(level)
		var options: Dictionary = runtime._build_firearm_spawn_options({"runtime_perk_state": perk_state})
		var speed_mult: float = float(expected_mult[level])
		_expect(
			is_equal_approx(float(options.get("base_pistol_speed_mult", 0.0)), speed_mult),
			"pistol_enhance Lv.%d should set base pistol speed multiplier to %.2f" % [level, speed_mult]
		)
		var base_state: Dictionary = _build_spawn_profile("pistol", weapon_profiles, options)
		var base_profile: Dictionary = _get_dict(base_state.get("profile", {}))
		_expect(
			is_equal_approx(float(base_profile.get("speed", 0.0)), CommandoFirearmRuntime.PISTOL_BULLET_SPEED * speed_mult),
			"pistol_enhance Lv.%d should set base pistol bullet speed to %.2f" % [level, CommandoFirearmRuntime.PISTOL_BULLET_SPEED * speed_mult]
		)
		var beretta_state: Dictionary = _build_spawn_profile("commando_pistol", weapon_profiles, options)
		var beretta_profile: Dictionary = _get_dict(beretta_state.get("profile", {}))
		_expect(
			is_equal_approx(float(beretta_profile.get("speed", 0.0)), CommandoFirearmRuntime.BERETTA_BULLET_SPEED),
			"pistol_enhance Lv.%d should leave Beretta bullet speed unchanged" % level
		)


func _verify_knockback_table_and_hit_isolation() -> void:
	var runtime := CommandoFirearmRuntime.new()
	var perk_state := FakePerkState.new()
	var expected_mult := {
		0: 1.0,
		1: 1.1,
		2: 1.2,
		3: 1.3,
		4: 1.4,
		5: 1.5,
		6: 1.5,
		7: 1.5,
	}
	for level in expected_mult.keys():
		perk_state.level = int(level)
		var options: Dictionary = runtime._build_firearm_spawn_options({"runtime_perk_state": perk_state})
		var knockback_mult: float = float(expected_mult[level])
		_expect(
			is_equal_approx(float(options.get("base_pistol_knockback_mult", 0.0)), knockback_mult),
			"pistol_enhance Lv.%d should set base pistol knockback multiplier to %.2f" % [level, knockback_mult]
		)
		var base_payload: Dictionary = CommandoFirearmPistolHitState.build_hit_payload(
			"pistol",
			0,
			0.99,
			0.0,
			0.0,
			1.0,
			CommandoFirearmRuntime.PISTOL_HIT_TUNING,
			knockback_mult
		)
		var base_fields: Dictionary = _get_dict(base_payload.get("result_fields", {}))
		_expect(
			is_equal_approx(float(base_fields.get("knockback_power", 0.0)), CommandoFirearmRuntime.PISTOL_BOSS_KNOCKBACK_POWER * knockback_mult),
			"pistol_enhance Lv.%d should scale base pistol normal-hit knockback" % level
		)
		var beretta_payload: Dictionary = CommandoFirearmPistolHitState.build_hit_payload(
			"commando_pistol",
			0,
			0.99,
			0.0,
			0.0,
			1.0,
			CommandoFirearmRuntime.PISTOL_HIT_TUNING,
			knockback_mult
		)
		var beretta_fields: Dictionary = _get_dict(beretta_payload.get("result_fields", {}))
		_expect(
			is_equal_approx(float(beretta_fields.get("knockback_power", 0.0)), CommandoFirearmRuntime.PISTOL_BOSS_KNOCKBACK_POWER),
			"pistol_enhance Lv.%d should leave Beretta normal-hit knockback unchanged" % level
		)

	var head_payload: Dictionary = CommandoFirearmPistolHitState.build_hit_payload(
		"pistol",
		0,
		0.0,
		1.0,
		0.0,
		1.0,
		CommandoFirearmRuntime.PISTOL_HIT_TUNING,
		1.5
	)
	var head_fields: Dictionary = _get_dict(head_payload.get("result_fields", {}))
	_expect(is_equal_approx(float(head_fields.get("knockback_power", 0.0)), 0.0), "pistol_enhance should not add knockback to pistol headshots")

	var leg_payload: Dictionary = CommandoFirearmPistolHitState.build_hit_payload(
		"pistol",
		0,
		0.5,
		0.0,
		1.0,
		1.0,
		CommandoFirearmRuntime.PISTOL_HIT_TUNING,
		1.5
	)
	var leg_fields: Dictionary = _get_dict(leg_payload.get("result_fields", {}))
	_expect(bool(leg_fields.get("knockback_without_stun", false)), "pistol_enhance should preserve legshot knockback-without-stun behavior")
	_expect(not leg_fields.has("knockback_power"), "pistol_enhance should not scale the legshot knockback lane")
	_verify_knockback_projectile_carry_is_base_pistol_only()


func _verify_knockback_projectile_carry_is_base_pistol_only() -> void:
	var origin := Vector2(380.0, 640.0)
	var target := Vector2(380.0, 120.0)
	var base_projectile: Dictionary = CommandoFirearmProjectileSpawnState.build_projectile(
		"pistol",
		"bullet",
		1,
		origin,
		target,
		Vector2.UP,
		25.0,
		0.0,
		origin,
		{},
		{},
		5,
		6,
		2.0,
		1.25,
		1.5
	)
	_expect(is_equal_approx(float(base_projectile.get("pistol_enhance_knockback_mult", 0.0)), 1.5), "base pistol projectile should carry pistol_enhance knockback multiplier")

	var beretta_projectile: Dictionary = CommandoFirearmProjectileSpawnState.build_projectile(
		"commando_pistol",
		"bullet",
		2,
		origin,
		target,
		Vector2.UP,
		30.0,
		0.0,
		origin,
		{},
		{},
		5,
		6,
		2.0,
		1.25,
		1.5
	)
	_expect(not beretta_projectile.has("pistol_enhance_knockback_mult"), "Beretta projectile should not carry pistol_enhance knockback multiplier")

	var slingshot_projectile: Dictionary = CommandoFirearmProjectileSpawnState.build_projectile(
		"pistol",
		"bullet",
		3,
		origin,
		target,
		Vector2.UP,
		25.0,
		0.0,
		origin,
		{"slingshot": true, "charge_level": 2},
		{},
		5,
		6,
		2.0,
		1.25,
		1.5
	)
	_expect(not slingshot_projectile.has("pistol_enhance_knockback_mult"), "slingshot projectile should not carry pistol_enhance knockback multiplier")


func _verify_ammo_table_overflow_and_reapply() -> void:
	var runtime := CommandoFirearmRuntime.new()
	var controller := CommandoWeaponController.new()
	var perk_state := FakePerkState.new()
	controller.unlock_permanent_weapon("commando_pistol", true)
	var expected_max := {
		0: 5,
		1: 5,
		2: 5,
		3: 6,
		4: 6,
		5: 7,
		6: 8,
		7: 9,
	}
	for level in expected_max.keys():
		perk_state.level = int(level)
		runtime.update_input({}, 0.0, {}, _deps(controller, perk_state))
		var base_weapon: Dictionary = controller.get_weapon_data("pistol")
		var beretta: Dictionary = controller.get_weapon_data("commando_pistol")
		_expect(int(base_weapon.get("ammo_max", -1)) == int(expected_max[level]), "pistol_enhance Lv.%d should set base max ammo to %d" % [level, int(expected_max[level])])
		_expect(int(base_weapon.get("ammo_current", -1)) <= int(expected_max[level]), "pistol_enhance Lv.%d should keep base current ammo within max" % level)
		_expect(int(beretta.get("ammo_max", -1)) == 12, "pistol_enhance Lv.%d should leave Beretta max ammo at 12" % level)

	perk_state.level = 7
	runtime.update_input({}, 0.0, {}, _deps(controller, perk_state))
	_expect(int(controller.get_weapon_data("pistol").get("ammo_current", -1)) == 9, "overflow level increase should top off base pistol ammo")
	perk_state.level = 0
	runtime.update_input({}, 0.0, {}, _deps(controller, perk_state))
	var clamped_base: Dictionary = controller.get_weapon_data("pistol")
	_expect(int(clamped_base.get("ammo_max", -1)) == 5, "dropping pistol_enhance should restore base pistol max ammo")
	_expect(int(clamped_base.get("ammo_current", -1)) == 5, "dropping pistol_enhance should clamp current ammo down to max")

	perk_state.level = 6
	runtime.update_input({}, 0.0, {}, _deps(controller, perk_state))
	_expect(int(controller.get_weapon_data("pistol").get("ammo_max", -1)) == 8, "Lv.6 should apply before reset smoke")
	controller.reset()
	_expect(int(controller.get_weapon_data("pistol").get("ammo_max", -1)) == 5, "controller reset should restore the raw base pistol template before reapply")
	runtime.update_input({}, 0.0, {}, _deps(controller, perk_state))
	_expect(int(controller.get_weapon_data("pistol").get("ammo_max", -1)) == 8, "per-frame sync should reapply pistol_enhance after controller reset")


func _verify_same_max_does_not_refill_spent_ammo() -> void:
	var runtime := CommandoFirearmRuntime.new()
	var controller := CommandoWeaponController.new()
	var perk_state := FakePerkState.new()
	perk_state.level = 5
	runtime.update_input({}, 0.0, {}, _deps(controller, perk_state))
	_expect(int(controller.get_weapon_data("pistol").get("ammo_current", -1)) == 7, "Lv.5 max increase should top off once")
	_expect(controller.consume_current_weapon_ammo(), "base pistol should spend ammo after pistol_enhance top-off")
	runtime.update_input({}, 0.0, {}, _deps(controller, perk_state))
	_expect(int(controller.get_weapon_data("pistol").get("ammo_current", -1)) == 6, "same pistol_enhance max should not refill spent ammo every frame")


func _verify_tooltip_uses_effective_base_magazine() -> void:
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)
	var selector := CommandoFirearmSelectorRenderer.new()
	var tooltip := CommandoFirearmTooltipRenderer.new()
	var controller := CommandoWeaponController.new()
	controller.set_base_pistol_ammo_max(7)
	var panel_state: Dictionary = selector.build_panel_state(Vector2(120.0, 280.0), 1.0, {"commando_weapon_controller": controller})
	var tooltip_state: Dictionary = tooltip.build_hover_state(
		panel_state,
		Vector2(760.0, 750.0),
		1.0,
		{
			"mouse_pos": _get_rect(panel_state.get("rect", Rect2())).get_center(),
			"skill_config_snapshot": {},
		}
	)
	_expect(str(tooltip_state.get("description", "")).find("7") >= 0, "base pistol tooltip description should mention the effective 7-round magazine")


func _verify_icon_path_and_badge_policy() -> void:
	var renderer := RuntimePerkIconRenderer.new()
	_expect(
		RuntimePerkIconRenderer.PERK_ICON_PATHS.get("pistol_enhance", "") == "res://assets/sprites/perks/soldier_pistol_enhance_perk_icon.png",
		"pistol_enhance should use the Soldier pistol enhance perk PNG"
	)
	_expect(renderer.has_icon("pistol_enhance"), "pistol_enhance should resolve a runtime perk icon")
	_expect(not renderer._needs_unlock_badge("pistol_enhance"), "pistol_enhance should not draw the weapon-unlock badge")
	_expect(not RuntimePerkIconRenderer.UNLOCK_ALIASES.has("pistol_enhance"), "pistol_enhance should not route through unlock aliases")
	_expect(not RuntimePerkIconRenderer.SKILL_ICON_PATHS.has("pistol_enhance"), "pistol_enhance should not route through skill icon paths")
	_expect(is_equal_approx(float(RuntimePerkIconRenderer.DRAW_SCALE.get("pistol_enhance", 0.0)), 1.06), "pistol_enhance should mirror Viper enhancer draw scale")
	_verify_icon_32px_cell_spacing(renderer)


func _verify_icon_32px_cell_spacing(renderer: Object) -> void:
	var cell_rect_cache: Array[Rect2] = []
	var icon_rect_cache: Array[Rect2] = []
	var center_x_cache: Array[float] = []
	var level_y_cache: Array[float] = []
	var visible_index_cache: Array[int] = []
	CharacterInfoOverlayLayoutUtils.refresh_perk_grid_layout_arrays(
		Rect2(Vector2.ZERO, Vector2(32.0, 32.0)),
		32.0,
		40.0,
		1,
		1,
		0.0,
		cell_rect_cache,
		icon_rect_cache,
		center_x_cache,
		level_y_cache,
		visible_index_cache
	)
	var source: Dictionary = renderer._get_icon_source("pistol_enhance")
	var texture: Texture2D = source.get("texture", null)
	if texture == null or icon_rect_cache.is_empty() or level_y_cache.is_empty():
		_failures.append("pistol_enhance 32px cell spacing smoke needs a loaded icon and layout rect")
		return
	var draw_rect: Rect2 = renderer._get_draw_rect(icon_rect_cache[0], "pistol_enhance", texture)
	_expect(min(draw_rect.size.x, draw_rect.size.y) >= 15.0, "pistol_enhance should remain legible in the 32px perk cell")
	_expect(draw_rect.end.y <= level_y_cache[0] - 7.0, "pistol_enhance 32px cell icon should leave room for Lv.1/Lv.5 labels")


func _deps(controller: Object, perk_state: Object) -> Dictionary:
	return {
		"commando_weapon_controller": controller,
		"runtime_perk_state": perk_state,
	}


func _get_rect(value: Variant) -> Rect2:
	if value is Rect2:
		return value
	return Rect2()


func _build_spawn_profile(weapon_id: String, weapon_profiles: Dictionary, options: Dictionary) -> Dictionary:
	return CommandoFirearmProfileResolver.build_spawn_profile_state(
		weapon_id,
		{},
		weapon_profiles,
		{},
		{},
		{},
		"pistol",
		CommandoFirearmRuntime.PISTOL_BULLET_SPEED,
		1.2,
		float(options.get("pistol_spread_radians", CommandoFirearmRuntime.PISTOL_SPREAD_RADIANS)),
		float(options.get("beretta_spread_radians", CommandoFirearmRuntime.BERETTA_SPREAD_RADIANS)),
		float(options.get("base_pistol_speed_mult", 1.0))
	)


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
