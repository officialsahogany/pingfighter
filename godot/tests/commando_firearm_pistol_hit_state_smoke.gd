extends SceneTree

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


func _verify_runtime_delegates_pistol_hit_state() -> void:
	var runtime := CommandoFirearmRuntime.new()
	runtime.pistol_boss_hit_count = 2
	var result := {}
	runtime._apply_pistol_hit_effects(
		"commando_pistol",
		{"shot_roll": 0.05},
		_boss_context(),
		result
	)
	_expect(runtime.pistol_boss_hit_count == 0, "runtime pistol hit wrapper should store helper hit count")
	_expect(str(result.get("pistol_hit_kind", "")) == "headshot", "runtime pistol hit wrapper should merge helper fields")
	_expect(int(result.get("damage_units", 0)) == 2, "runtime pistol hit wrapper should apply damage delta")
	_expect(_get_array(runtime.pistol_feedbacks).size() == 1, "runtime pistol hit wrapper should keep feedback side effect")
	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	_expect(
		runtime_source.find("CommandoFirearmPistolHitState.apply_runtime_hit_effects") >= 0,
		"runtime should delegate pistol hit composition to the owner"
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


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
