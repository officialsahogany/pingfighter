extends SceneTree

const CommandoFirearmHitResultState := preload("res://scripts/characters/commando_firearm_hit_result_state.gd")
const CommandoFirearmPistolHitState := preload("res://scripts/characters/commando_firearm_pistol_hit_state.gd")
const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_pistol_hit_state()
	_verify_runtime_delegates_pistol_hit_state()

	if _failures.is_empty():
		print("commando_firearm_pistol_hit_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_pistol_hit_state() -> void:
	var normal_payload: Dictionary = CommandoFirearmPistolHitState.build_hit_payload(
		"commando_pistol",
		0,
		0.99,
		0.10,
		0.12,
		1.0,
		CommandoFirearmRuntime.PISTOL_HIT_TUNING
	)
	var normal_fields: Dictionary = _get_dict(normal_payload.get("result_fields", {}))
	_expect(int(normal_payload.get("next_hit_count", 0)) == 1, "normal pistol hit should increment combo count")
	_expect(str(normal_fields.get("pistol_hit_kind", "")) == "normal", "normal pistol hit should expose normal hit kind")
	_expect(is_equal_approx(float(normal_fields.get("commando_firearm_special_gauge_gain", 0.0)), 30.0), "normal pistol hit should grant normal gauge")
	_expect(is_equal_approx(float(normal_fields.get("knockback_power", 0.0)), 8.0), "normal pistol hit should carry knockback power")
	_expect(int(normal_payload.get("damage_units_delta", -1)) == 0, "normal non-combo pistol hit should not emit damage")

	var enhanced_base_payload: Dictionary = CommandoFirearmPistolHitState.build_hit_payload(
		"pistol",
		0,
		0.99,
		0.0,
		0.0,
		1.0,
		CommandoFirearmRuntime.PISTOL_HIT_TUNING,
		2.5
	)
	var enhanced_base_fields: Dictionary = _get_dict(enhanced_base_payload.get("result_fields", {}))
	_expect(is_equal_approx(float(enhanced_base_fields.get("knockback_power", 0.0)), 20.0), "base pistol normal hit should scale pistol_enhance knockback power")

	var beretta_with_enhance_payload: Dictionary = CommandoFirearmPistolHitState.build_hit_payload(
		"commando_pistol",
		0,
		0.99,
		0.0,
		0.0,
		1.0,
		CommandoFirearmRuntime.PISTOL_HIT_TUNING,
		2.5
	)
	var beretta_with_enhance_fields: Dictionary = _get_dict(beretta_with_enhance_payload.get("result_fields", {}))
	_expect(is_equal_approx(float(beretta_with_enhance_fields.get("knockback_power", 0.0)), 8.0), "Beretta normal hit should ignore pistol_enhance knockback power")

	var head_payload: Dictionary = CommandoFirearmPistolHitState.build_hit_payload(
		"commando_pistol",
		2,
		0.05,
		0.10,
		0.12,
		1.0,
		CommandoFirearmRuntime.PISTOL_HIT_TUNING
	)
	var head_fields: Dictionary = _get_dict(head_payload.get("result_fields", {}))
	_expect(int(head_payload.get("next_hit_count", -1)) == 0, "combo threshold should reset pistol hit count")
	_expect(str(head_fields.get("pistol_hit_kind", "")) == "headshot", "headshot payload should expose hit kind")
	_expect(is_equal_approx(float(head_fields.get("stun_frames", 0.0)), 108.0), "commando pistol headshot should use stronger stun")
	_expect(str(head_payload.get("feedback_hit_kind", "")) == "headshot", "headshot payload should request feedback")
	_expect(int(head_payload.get("damage_units_delta", 0)) == 2, "headshot on combo threshold should stack headshot and combo damage")
	var head_sources: Array = _get_array(head_payload.get("damage_sources", []))
	_expect(head_sources.has("commando_firearm_pistol_headshot") and head_sources.has("commando_firearm_pistol_combo"), "headshot combo payload should preserve both damage sources")

	var leg_payload: Dictionary = CommandoFirearmPistolHitState.build_hit_payload(
		"pistol",
		0,
		0.15,
		0.10,
		0.12,
		2.0,
		CommandoFirearmRuntime.PISTOL_HIT_TUNING
	)
	var leg_fields: Dictionary = _get_dict(leg_payload.get("result_fields", {}))
	_expect(str(leg_fields.get("pistol_hit_kind", "")) == "legshot", "legshot payload should expose hit kind")
	_expect(is_equal_approx(float(leg_fields.get("slow_frames", 0.0)), 132.0), "legshot payload should carry slow frames")
	_expect(is_equal_approx(float(leg_fields.get("slow_multiplier", 0.0)), 0.7), "legshot payload should carry slow multiplier")
	_expect(bool(leg_fields.get("doping_potion_active", false)), "pistol hit payload should expose active doping multiplier")
	_expect(str(leg_payload.get("feedback_hit_kind", "")) == "legshot", "legshot payload should request feedback")

	var result := {}
	var feedbacks: Array = []
	var apply_result: Dictionary = CommandoFirearmPistolHitState.apply_hit_payload(
		head_payload,
		result,
		feedbacks,
		_boss_context(),
		760.0,
		750.0,
		36.0,
		"헤드샷!",
		"레그샷!",
		6
	)
	_expect(int(apply_result.get("next_hit_count", -1)) == 0, "pistol hit apply owner should return the next hit count")
	_expect(str(result.get("pistol_hit_kind", "")) == "headshot", "pistol hit apply owner should merge result fields")
	_expect(int(result.get("damage_units", 0)) == 2, "pistol hit apply owner should apply damage units")
	_expect(feedbacks.size() == 1, "pistol hit apply owner should append requested feedback")

	var runtime_result := {}
	var runtime_feedbacks: Array = []
	var runtime_apply_result: Dictionary = CommandoFirearmPistolHitState.apply_runtime_hit_effects(
		"commando_pistol",
		{
			"active_item_doping_potion_active": true,
			"active_item_doping_potion_head_leg_multiplier": 2.0,
		},
		_boss_context().merged({"commando_pistol_shot_roll": 0.21}, true),
		runtime_result,
		0,
		runtime_feedbacks,
		"pistol",
		2.0,
		0.10,
		0.12,
		CommandoFirearmRuntime.PISTOL_HIT_TUNING,
		760.0,
		750.0,
		60.0,
		"?ㅻ뱶??",
		"?덇렇??",
		4
	)
	_expect(int(runtime_apply_result.get("next_hit_count", -1)) == 1, "runtime pistol hit owner should return hit count")
	_expect(str(runtime_result.get("pistol_hit_kind", "")) == "legshot", "runtime pistol hit owner should apply doped hit chances")
	_expect(is_equal_approx(float(runtime_result.get("pistol_head_chance", 0.0)), 0.20), "runtime pistol hit owner should expose doped head chance")
	_expect(runtime_feedbacks.size() == 1, "runtime pistol hit owner should append feedback")

	var enhanced_runtime_result := {}
	var enhanced_runtime_feedbacks: Array = []
	var enhanced_runtime_apply_result: Dictionary = CommandoFirearmPistolHitState.apply_runtime_hit_effects(
		"pistol",
		{"pistol_enhance_knockback_mult": 2.5},
		_boss_context().merged({"commando_pistol_shot_roll": 0.99}, true),
		enhanced_runtime_result,
		0,
		enhanced_runtime_feedbacks,
		"pistol",
		2.0,
		0.0,
		0.0,
		CommandoFirearmRuntime.PISTOL_HIT_TUNING,
		760.0,
		750.0,
		60.0,
		"head",
		"leg",
		4
	)
	_expect(int(enhanced_runtime_apply_result.get("next_hit_count", -1)) == 1, "runtime base pistol knockback owner should return hit count")
	_expect(is_equal_approx(float(enhanced_runtime_result.get("knockback_power", 0.0)), 20.0), "runtime base pistol normal hit should consume pistol_enhance knockback multiplier")

	var beretta_runtime_result := {}
	var beretta_runtime_feedbacks: Array = []
	CommandoFirearmPistolHitState.apply_runtime_hit_effects(
		"commando_pistol",
		{"pistol_enhance_knockback_mult": 2.5},
		_boss_context().merged({"commando_pistol_shot_roll": 0.99}, true),
		beretta_runtime_result,
		0,
		beretta_runtime_feedbacks,
		"pistol",
		2.0,
		0.0,
		0.0,
		CommandoFirearmRuntime.PISTOL_HIT_TUNING,
		760.0,
		750.0,
		60.0,
		"head",
		"leg",
		4
	)
	_expect(is_equal_approx(float(beretta_runtime_result.get("knockback_power", 0.0)), 8.0), "runtime Beretta normal hit should ignore pistol_enhance knockback multiplier")


func _verify_runtime_delegates_pistol_hit_state() -> void:
	var runtime := CommandoFirearmRuntime.new()
	runtime.pistol_boss_hit_count = 2
	var result: Dictionary = _apply_runtime_weapon_hit_result(
		runtime,
		"commando_pistol",
		{"weapon_id": "commando_pistol", "shot_roll": 0.05, "pos": Vector2(380.0, 80.0), "velocity": Vector2(0.0, -16.0)},
		_boss_context().merged({"commando_pistol_head_chance": 0.10, "commando_pistol_leg_chance": 0.12}, true),
		{}
	)
	_expect(runtime.pistol_boss_hit_count == 0, "runtime pistol hit wrapper should store helper hit count")
	_expect(str(result.get("pistol_hit_kind", "")) == "headshot", "runtime pistol hit wrapper should merge helper fields")
	_expect(int(result.get("damage_units", 0)) == 2, "runtime pistol hit wrapper should apply damage delta")
	_expect(_get_array(runtime.pistol_feedbacks).size() == 1, "runtime pistol hit wrapper should keep feedback side effect")
	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	var impact_source: String = FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_projectile_impact_state.gd")
	_expect(
		runtime_source.find("CommandoFirearmProjectileImpactState.register_runtime_projectile_hit") >= 0,
		"runtime should delegate projectile-hit registration to the owner"
	)
	_expect(
		impact_source.find("CommandoFirearmHitResultState.apply_runtime_weapon_hit_result") >= 0,
		"projectile impact owner should delegate weapon hit-result composition to the owner"
	)
	_expect(
		runtime_source.find("func _apply_weapon_hit_result(") < 0,
		"runtime should not keep the weapon hit-result bridge after hit-result ownership moves"
	)
	_expect(
		runtime_source.find("func _apply_pistol_hit_effects") < 0,
		"runtime should not keep the pistol hit bridge after hit-result ownership moves"
	)


func _boss_context() -> Dictionary:
	return {
		"boss_pos": Vector2(330.0, 50.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
	}


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _apply_runtime_weapon_hit_result(
	runtime: Object,
	weapon_id: String,
	projectile: Dictionary,
	context: Dictionary,
	deps: Dictionary
) -> Dictionary:
	return CommandoFirearmHitResultState.apply_runtime_weapon_hit_result(
		runtime,
		weapon_id,
		projectile,
		context,
		deps,
		CommandoFirearmRuntime.WEAPON_HIT_RESULTS,
		CommandoFirearmRuntime.HIT_RESULT_PROFILE_OVERRIDES,
		CommandoFirearmRuntime.BASE_WEAPON_ID,
		CommandoFirearmRuntime.SLINGSHOT_STUN_MULT,
		CommandoFirearmRuntime.SLINGSHOT_KNOCKBACK_MULT,
		CommandoFirearmRuntime.DOPING_POTION_HEAD_LEG_MULTIPLIER,
		CommandoFirearmRuntime.PISTOL_HEAD_SHOT_CHANCE,
		CommandoFirearmRuntime.PISTOL_LEG_SHOT_CHANCE,
		CommandoFirearmRuntime.PISTOL_HIT_TUNING,
		Vector2(CommandoFirearmRuntime.FIELD_WIDTH, CommandoFirearmRuntime.FIELD_HEIGHT),
		CommandoFirearmRuntime.PISTOL_HIT_TEXT_TIMER_FRAMES,
		"head",
		"leg",
		CommandoFirearmRuntime.PISTOL_FEEDBACK_LIMIT,
		CommandoFirearmRuntime.AK47_BOSS_DAMAGE_HIT_THRESHOLD
	)


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
