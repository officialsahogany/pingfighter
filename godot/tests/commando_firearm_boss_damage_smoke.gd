extends SceneTree

const BattleSceneEffectsUpdateResultApplier := preload("res://scripts/core/battle_scene_effects_update_result_applier.gd")
const BattleSceneBossHealthFlow := preload("res://scripts/core/battle_scene_boss_health_flow.gd")
const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")

var _failures: Array[String] = []
var _score_events: Array[String] = []


class FakeOwner:
	extends RefCounted

	var data: Dictionary = {
		"boss_max_health": 5,
		"boss_current_health": 5,
		"boss_health_damage_units": 0,
		"boss_defeated_by_health": false,
		"commando_firearm_boss_damage_units_total": 0,
		"commando_firearm_last_damage_units": 0,
		"commando_firearm_last_damage_source": "",
	}

	func _get(property: StringName) -> Variant:
		return data.get(str(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		data[str(property)] = value
		return true


class FakeStatusEffectState:
	extends RefCounted

	var applied: Array = []

	func apply_status(target: String, status_id: String, duration_frames: float, data: Dictionary = {}, source: String = "") -> Dictionary:
		applied.append({
			"target": target,
			"status_id": status_id,
			"duration_frames": duration_frames,
			"data": data.duplicate(true),
			"source": source,
		})
		return {}


func _init() -> void:
	_verify_firearm_damage_result_reduces_configured_boss_health()
	_verify_damage_result_is_consumed_once()
	_verify_damage_accumulates_without_configured_health()
	_verify_ak47_accumulated_hits_emit_boss_damage()
	_verify_base_pistol_shares_original_pistol_combo_damage()
	_verify_pistol_combo_hits_emit_boss_damage()
	_verify_pistol_headshot_damage_can_stack_with_combo()
	_verify_pistol_legshot_counts_toward_combo_without_headshot_damage()

	if _failures.is_empty():
		print("commando_firearm_boss_damage_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_firearm_damage_result_reduces_configured_boss_health() -> void:
	var runtime := CommandoFirearmRuntime.new()
	var result: Dictionary = _register_hit_and_consume_result(runtime, "bazooka", 1)
	_expect(int(result.get("commando_firearm_boss_damage_units", 0)) == 2, "bazooka should emit two boss-health damage units")
	_expect(str(result.get("commando_firearm_last_damage_source", "")) == "commando_firearm_bazooka", "damage result should preserve bazooka source")

	var owner := FakeOwner.new()
	BattleSceneEffectsUpdateResultApplier.new().apply_effects_result(owner, result)
	_expect(int(owner.data.get("boss_current_health", -1)) == 3, "configured boss health should be reduced by Commando firearm damage")
	_expect(int(owner.data.get("boss_health_damage_units", -1)) == 2, "boss health damage counter should increase")
	_expect(int(owner.data.get("commando_firearm_boss_damage_units_total", -1)) == 2, "Commando firearm damage counter should increase")
	_expect(int(owner.data.get("commando_firearm_last_damage_units", -1)) == 2, "last Commando firearm damage units should be recorded")
	_expect(str(owner.data.get("boss_last_damage_source", "")) == "commando_firearm_bazooka", "boss last damage source should be recorded")
	_expect(not bool(owner.data.get("boss_defeated_by_health", true)), "boss should not be defeated while health remains")

	var finishing_result := {
		"commando_firearm_boss_damage_units": 3,
		"commando_firearm_last_damage_source": "commando_firearm_fire_support",
	}
	BattleSceneEffectsUpdateResultApplier.new().apply_effects_result(owner, finishing_result)
	_expect(int(owner.data.get("boss_current_health", -1)) == 0, "damage should clamp boss health at zero")
	_expect(bool(owner.data.get("boss_defeated_by_health", false)), "boss defeat flag should be set when configured health reaches zero")
	_score_events.clear()
	var health_flow := BattleSceneBossHealthFlow.new()
	_expect(health_flow.consume_defeat_score_event(owner, Callable(self, "_record_score_event")), "boss health defeat should emit a score event")
	_expect(_score_events == ["player"], "boss health defeat should score for the player")
	_expect(not bool(owner.data.get("boss_defeated_by_health", true)), "boss health defeat should be one-shot after score consumption")


func _verify_damage_result_is_consumed_once() -> void:
	var runtime := CommandoFirearmRuntime.new()
	var first_result: Dictionary = _register_hit_and_consume_result(runtime, "fire_support", 10)
	_expect(int(first_result.get("commando_firearm_boss_damage_units", 0)) == 1, "fire support bomb should emit one damage unit")

	var second_result: Dictionary = runtime.update_effects(0.0, 0, _context(), {})
	_expect(not second_result.has("commando_firearm_boss_damage_units"), "damage result should not be re-emitted on the next effects tick")


func _verify_damage_accumulates_without_configured_health() -> void:
	var owner := FakeOwner.new()
	owner.data["boss_max_health"] = 0
	owner.data["boss_current_health"] = 0
	BattleSceneEffectsUpdateResultApplier.new().apply_effects_result(owner, {
		"commando_firearm_boss_damage_units": 2,
		"commando_firearm_last_damage_source": "commando_firearm_bazooka",
	})
	_expect(int(owner.data.get("boss_current_health", -1)) == 0, "unconfigured boss health should stay untouched")
	_expect(int(owner.data.get("commando_firearm_boss_damage_units_total", -1)) == 2, "damage should still accumulate for later health/HUD handoff")
	_expect(not bool(owner.data.get("boss_defeated_by_health", true)), "unconfigured health should not raise the defeat flag")


func _verify_ak47_accumulated_hits_emit_boss_damage() -> void:
	var runtime := CommandoFirearmRuntime.new()
	for hit_index in range(19):
		var early_result: Dictionary = _register_hit_and_consume_result(runtime, "ak47", 100 + hit_index)
		_expect(not early_result.has("commando_firearm_boss_damage_units"), "AK-47 should not emit boss-health damage before the 20th hit")

	var result: Dictionary = _register_hit_and_consume_result(runtime, "ak47", 200)
	_expect(int(result.get("commando_firearm_boss_damage_units", 0)) == 1, "AK-47 should emit one boss-health damage unit on the 20th hit")
	_expect(str(result.get("commando_firearm_last_damage_source", "")) == "commando_firearm_ak47", "AK-47 accumulated damage should preserve its source")

	var owner := FakeOwner.new()
	BattleSceneEffectsUpdateResultApplier.new().apply_effects_result(owner, result)
	_expect(int(owner.data.get("boss_current_health", -1)) == 4, "AK-47 accumulated damage should reduce configured boss health by one")
	_expect(int(owner.data.get("commando_firearm_boss_damage_units_total", -1)) == 1, "AK-47 accumulated damage should increase the Commando damage counter")


func _verify_base_pistol_shares_original_pistol_combo_damage() -> void:
	var runtime := CommandoFirearmRuntime.new()
	for hit_index in range(2):
		var early_result: Dictionary = _register_hit_and_consume_result(runtime, "pistol", 250 + hit_index, {"shot_roll": 0.99})
		_expect(not early_result.has("commando_firearm_boss_damage_units"), "base pistol should not emit combo boss-health damage before the 3rd original pistol hit")
		_expect(is_equal_approx(float(early_result.get("commando_firearm_special_gauge_gain", 0.0)), 30.0), "base pistol normal hit should expose the original 30 gauge gain")
	var result: Dictionary = _register_hit_and_consume_result(runtime, "pistol", 253, {"shot_roll": 0.99})
	_expect(int(result.get("commando_firearm_boss_damage_units", 0)) == 1, "base pistol should share the original pistol 3-hit combo damage")
	_expect(str(result.get("commando_firearm_last_damage_source", "")) == "commando_firearm_pistol_combo", "base pistol combo damage should preserve the original pistol combo source")


func _verify_pistol_combo_hits_emit_boss_damage() -> void:
	var runtime := CommandoFirearmRuntime.new()
	for hit_index in range(2):
		var early_result: Dictionary = _register_hit_and_consume_result(runtime, "commando_pistol", 300 + hit_index, {"shot_roll": 0.99})
		_expect(not early_result.has("commando_firearm_boss_damage_units"), "pistol should not emit combo boss-health damage before the 3rd hit")
		_expect(is_equal_approx(float(early_result.get("commando_firearm_special_gauge_gain", 0.0)), 30.0), "normal pistol boss hit should expose Python 30 gauge gain")

	var result: Dictionary = _register_hit_and_consume_result(runtime, "commando_pistol", 303, {"shot_roll": 0.99})
	_expect(int(result.get("commando_firearm_boss_damage_units", 0)) == 1, "pistol should emit one boss-health damage unit on the 3rd hit")
	_expect(str(result.get("commando_firearm_last_damage_source", "")) == "commando_firearm_pistol_combo", "pistol combo damage should preserve combo source")

	var owner := FakeOwner.new()
	BattleSceneEffectsUpdateResultApplier.new().apply_effects_result(owner, result)
	_expect(int(owner.data.get("boss_current_health", -1)) == 4, "pistol combo damage should reduce configured boss health by one")


func _verify_pistol_headshot_damage_can_stack_with_combo() -> void:
	var runtime := CommandoFirearmRuntime.new()
	for hit_index in range(2):
		var early_result: Dictionary = _register_hit_and_consume_result(runtime, "commando_pistol", 400 + hit_index, {"shot_roll": 0.99})
		_expect(not early_result.has("commando_firearm_boss_damage_units"), "commando pistol should share the pistol combo counter")

	var result: Dictionary = _register_hit_and_consume_result(runtime, "commando_pistol", 403, {"shot_roll": 0.0})
	_expect(int(result.get("commando_firearm_boss_damage_units", 0)) == 2, "pistol headshot on the 3rd hit should stack headshot and combo damage")
	_expect(is_equal_approx(float(result.get("commando_firearm_special_gauge_gain", 0.0)), 50.0), "pistol headshot should expose Python 50 gauge gain")
	var sources: Array = result.get("commando_firearm_boss_damage_sources", [])
	_expect(sources.has("commando_firearm_pistol_headshot"), "pistol headshot source should be preserved")
	_expect(sources.has("commando_firearm_pistol_combo"), "pistol combo source should be preserved when stacked")
	_expect(str(result.get("commando_firearm_last_damage_source", "")) == "commando_firearm_pistol_combo", "stacked pistol damage should keep combo as the last source")

	var owner := FakeOwner.new()
	BattleSceneEffectsUpdateResultApplier.new().apply_effects_result(owner, result)
	_expect(int(owner.data.get("boss_current_health", -1)) == 3, "stacked pistol damage should reduce configured boss health by two")


func _verify_pistol_legshot_counts_toward_combo_without_headshot_damage() -> void:
	var runtime := CommandoFirearmRuntime.new()
	for hit_index in range(2):
		var early_result: Dictionary = _register_hit_and_consume_result(runtime, "commando_pistol", 500 + hit_index, {"shot_roll": 0.99})
		_expect(not early_result.has("commando_firearm_boss_damage_units"), "normal pistol setup hits should not damage before the 3rd hit")

	var result: Dictionary = _register_hit_and_consume_result(runtime, "commando_pistol", 503, {"shot_roll": 0.15})
	_expect(int(result.get("commando_firearm_boss_damage_units", 0)) == 1, "pistol legshot on the 3rd hit should emit combo damage only")
	_expect(is_equal_approx(float(result.get("commando_firearm_special_gauge_gain", 0.0)), 40.0), "pistol legshot combo hit should still expose Python 40 gauge gain")
	var sources: Array = result.get("commando_firearm_boss_damage_sources", [])
	_expect(sources.has("commando_firearm_pistol_combo"), "legshot combo source should be preserved")
	_expect(not sources.has("commando_firearm_pistol_headshot"), "legshot should not emit the immediate headshot damage source")
	_expect(str(result.get("commando_firearm_last_damage_source", "")) == "commando_firearm_pistol_combo", "legshot combo damage should keep combo as the last source")

	var owner := FakeOwner.new()
	BattleSceneEffectsUpdateResultApplier.new().apply_effects_result(owner, result)
	_expect(int(owner.data.get("boss_current_health", -1)) == 4, "legshot combo should reduce configured boss health by one")


func _register_hit_and_consume_result(runtime: Object, weapon_id: String, projectile_id: int, projectile_overrides: Dictionary = {}) -> Dictionary:
	var projectile := {
		"id": projectile_id,
		"weapon_id": weapon_id,
		"kind": weapon_id,
		"pos": Vector2(380.0, 88.0),
		"velocity": Vector2(0.0, -18.0),
		"radius": 8.0,
		"impact_radius": 36.0,
		"color": Color(1.0, 0.5, 0.2),
		"secondary": Color(1.0, 0.9, 0.3),
	}
	projectile.merge(projectile_overrides, true)
	runtime._register_projectile_hit(projectile, _context(), {"status_effect_state": FakeStatusEffectState.new()})
	return runtime.update_effects(0.0, 0, _context(), {})


func _context() -> Dictionary:
	return {
		"boss_pos": Vector2(330.0, 50.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"boss_vel": 0.0,
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _record_score_event(scoring_side: String) -> void:
	_score_events.append(scoring_side)
