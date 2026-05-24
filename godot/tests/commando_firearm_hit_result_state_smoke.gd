extends SceneTree

const CommandoFirearmHitResultState := preload("res://scripts/characters/commando_firearm_hit_result_state.gd")
const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_hit_result_state()
	_verify_runtime_still_applies_hit_result_status()

	if _failures.is_empty():
		print("commando_firearm_hit_result_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_hit_result_state() -> void:
	var base: Dictionary = CommandoFirearmHitResultState.build_base_result("commando_firearm_bazooka", 2)
	_expect(str(base.get("source", "")) == "commando_firearm_bazooka", "base hit result should preserve source")
	_expect(int(base.get("damage_units", 0)) == 2, "base hit result should preserve damage units")
	_expect(is_equal_approx(CommandoFirearmHitResultState.get_stun_frames({"stun_frames": 42.0}, {}), 42.0), "stun frame helper should read profile frames")
	_expect(is_equal_approx(CommandoFirearmHitResultState.get_stun_frames({"stun_frames": 42.0}, {"stun_frames": 18.0}), 18.0), "stun frame helper should prefer result overrides")
	_expect(is_equal_approx(CommandoFirearmHitResultState.get_slow_frames({"slow_frames": 24.0}, {"slow_frames": 12.0}), 12.0), "slow frame helper should prefer result overrides")
	_expect(CommandoFirearmHitResultState.get_stun_source({"stun_source": "headshot"}, "base") == "headshot", "stun source helper should read explicit sources")
	_expect(CommandoFirearmHitResultState.get_slow_source({}, "base") == "base_slow", "slow source helper should build default slow sources")
	_expect(is_equal_approx(CommandoFirearmHitResultState.get_slow_multiplier({"slow_multiplier": 0.75}, {}), 0.75), "slow multiplier helper should read profile multipliers")
	_expect(is_equal_approx(CommandoFirearmHitResultState.get_slow_multiplier({}, {"slow_multiplier": 2.0}), 1.0), "slow multiplier helper should clamp high overrides")

	var stun_data: Dictionary = CommandoFirearmHitResultState.build_stun_status_data(
		22.0,
		"headshot",
		{
			"knockback_frames": 18.0,
			"knockback_decay_per_frame": 0.85,
		}
	)
	_expect(bool(stun_data.get("knockback_active", false)), "stun status data should mark active knockback")
	_expect(is_equal_approx(float(stun_data.get("knockback_frames", 0.0)), 18.0), "stun status data should preserve knockback frames")
	_expect(str(stun_data.get("source", "")) == "headshot", "stun status data should preserve source")
	var stun_result := {}
	CommandoFirearmHitResultState.apply_stun_result_fields(
		stun_result,
		24.0,
		18.0,
		{"knockback_frames": 12.0, "knockback_decay_per_frame": 0.8}
	)
	_expect(is_equal_approx(float(stun_result.get("stun_frames", 0.0)), 24.0), "stun field helper should write stun frames")
	_expect(is_equal_approx(float(stun_result.get("knockback_decay_per_frame", 0.0)), 0.8), "stun field helper should preserve decay frames")

	var slow_data: Dictionary = CommandoFirearmHitResultState.build_slow_status_data(0.45, "legshot")
	_expect(is_equal_approx(float(slow_data.get("multiplier", 0.0)), 0.45), "slow status data should preserve multiplier")
	_expect(str(slow_data.get("source", "")) == "legshot", "slow status data should preserve source")
	var slow_result := {}
	CommandoFirearmHitResultState.apply_slow_result_fields(slow_result, 36.0, 0.55)
	_expect(is_equal_approx(float(slow_result.get("slow_frames", 0.0)), 36.0), "slow field helper should write slow frames")
	_expect(is_equal_approx(float(slow_result.get("slow_multiplier", 0.0)), 0.55), "slow field helper should write slow multipliers")

	var runtime_status := FakeStatusEffectState.new()
	var runtime_result: Dictionary = CommandoFirearmHitResultState.build_base_result("commando_firearm_test", 1)
	CommandoFirearmHitResultState.apply_runtime_status_results(
		runtime_result,
		{"stun_frames": 18.0, "slow_frames": 12.0, "slow_multiplier": 0.5, "knockback_power": 8.0},
		{"pos": Vector2(100.0, 100.0), "velocity": Vector2.RIGHT},
		{"boss_pos": Vector2(130.0, 60.0), "boss_paddle_width": 100.0, "boss_hitbox_height": 40.0},
		{"status_effect_state": runtime_status},
		"commando_firearm_test",
		CommandoFirearmRuntime.FIELD_WIDTH
	)
	_expect(bool(runtime_result.get("stun_applied", false)), "runtime status helper should apply stun status")
	_expect(bool(runtime_result.get("slow_applied", false)), "runtime status helper should apply slow status")
	_expect(runtime_status.calls.size() == 2, "runtime status helper should emit stun and slow status calls")


func _verify_runtime_still_applies_hit_result_status() -> void:
	var runtime := CommandoFirearmRuntime.new()
	var status_state := FakeStatusEffectState.new()
	var result: Dictionary = runtime._apply_weapon_hit_result(
		"commando_pistol",
		{
			"weapon_id": "commando_pistol",
			"pos": Vector2(380.0, 80.0),
			"velocity": Vector2(0.0, -16.0),
			"shot_roll": 0.01,
		},
		{
			"commando_pistol_head_chance": 0.10,
			"commando_pistol_leg_chance": 0.12,
			"boss_pos": Vector2(330.0, 50.0),
			"boss_paddle_width": 100.0,
			"boss_hitbox_height": 40.0,
		},
		{"status_effect_state": status_state}
	)
	_expect(str(result.get("pistol_hit_kind", "")) == "headshot", "runtime hit result should still classify headshots")
	_expect(status_state.calls.size() == 1, "runtime hit result should still apply one stun status")
	var status_call: Dictionary = status_state.calls[0]
	_expect(str(status_call.get("status_id", "")) == "stun", "runtime hit result should still apply stun")
	_expect(str((status_call.get("data", {}) as Dictionary).get("source", "")) == "commando_firearm_pistol_headshot", "runtime stun data should preserve headshot source")


class FakeStatusEffectState:
	extends RefCounted

	var calls: Array = []

	func apply_status(target: String, status_id: String, duration_frames: float, data: Dictionary, source: String) -> void:
		calls.append({
			"target": target,
			"status_id": status_id,
			"duration_frames": duration_frames,
			"data": data.duplicate(true),
			"source": source,
		})


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
