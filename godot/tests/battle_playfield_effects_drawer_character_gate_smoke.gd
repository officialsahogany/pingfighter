extends SceneTree

const BattlePlayfieldEffectsDrawer := preload("res://scripts/core/battle_playfield_effects_drawer.gd")

var _failures: Array[String] = []


class RecordingRegistry:
	extends RefCounted

	var requested_keys: Array[String] = []

	func get_instance(key: String) -> Object:
		requested_keys.append(key)
		return null


class Draw2:
	extends RefCounted

	func draw(_canvas: CanvasItem, _context: Dictionary) -> void:
		pass


class Draw3:
	extends RefCounted

	func draw(_canvas: CanvasItem, _context: Dictionary, _perf_logger: Object = null) -> void:
		pass


func _init() -> void:
	var drawer: Object = BattlePlayfieldEffectsDrawer.new()
	var registry := RecordingRegistry.new()
	var viper_context := {"selected_character_type": "viper"}
	var smasher_context := {"selected_character_type": "smasher"}

	drawer.draw_power_smash_effects(null, registry, RefCounted.new(), Vector2.ZERO, viper_context)
	drawer.draw_magnum_grip_effects(null, registry, viper_context, Vector2.ZERO)
	drawer.draw_dash_spirit_effects(null, registry, Vector2.ZERO, viper_context)
	drawer.draw_shield_kiting_effects(null, registry, Vector2.ZERO, viper_context)
	drawer.draw_plasma_effects(null, registry, Vector2.ZERO, viper_context)
	drawer.draw_recovery_effects(null, registry, Vector2.ZERO, viper_context)
	drawer.draw_cleanse_effects(null, registry, Vector2.ZERO, viper_context)
	drawer.draw_warp_gate_effects(null, registry, Vector2.ZERO, viper_context)
	drawer.draw_smasher_wheel_effects(null, registry, Vector2.ZERO, viper_context)
	_expect(not _has_any_requested(registry, [
		"smasher_skill_feedback_renderer",
		"smasher_magnum_grip_state",
		"smasher_dash_spirit_state",
		"smasher_shield_kiting_state",
		"smasher_plasma_state",
		"smasher_recovery_state",
		"smasher_cleanse_state",
		"smasher_warp_gate_state",
		"smasher_wheel_state",
	]), "non-Smasher context should skip Smasher-only playfield effect lookups")

	registry.requested_keys.clear()
	drawer.draw_viper_skill_effects(null, registry, Vector2.ZERO, smasher_context)
	_expect(not registry.requested_keys.has("viper_skill_runtime"), "Smasher context should skip Viper skill effect lookup")

	registry.requested_keys.clear()
	drawer.draw_commando_supply_drop_effects(null, registry, Vector2.ZERO, viper_context)
	_expect(not registry.requested_keys.has("commando_supply_drop_state"), "Viper context should skip Commando supply-drop lookup")

	registry.requested_keys.clear()
	drawer.draw_viper_skill_effects(null, registry, Vector2.ZERO, viper_context)
	_expect(registry.requested_keys.has("viper_skill_runtime"), "Viper context should still request Viper skill runtime")

	registry.requested_keys.clear()
	drawer.draw_commando_supply_drop_effects(null, registry, Vector2.ZERO, {"selected_character_type": "commando"})
	_expect(registry.requested_keys.has("commando_supply_drop_state"), "Commando alias should still request supply-drop state")

	registry.requested_keys.clear()
	drawer.draw_blacksmith_thor_shield_effects(null, registry, Vector2.ZERO, {"selected_character_type": " Kohaku "})
	_expect(registry.requested_keys.has("blacksmith_thor_shield_state"), "Kohaku alias should still request Blacksmith shield state")

	registry.requested_keys.clear()
	drawer.draw_smasher_wheel_effects(null, registry, Vector2.ZERO, smasher_context)
	_expect(registry.requested_keys.has("smasher_wheel_state"), "Smasher context should still request Smasher wheel state")

	registry.requested_keys.clear()
	drawer.draw_smasher_wheel_effects(null, registry, Vector2.ZERO, {"selected_character_type": "optimus"})
	_expect(not registry.requested_keys.has("smasher_wheel_state"), "explicit non-Smasher characters should skip Smasher wheel state")

	registry.requested_keys.clear()
	drawer.draw_smasher_wheel_effects(null, registry, Vector2.ZERO, {"selected_character_type": "unknown"})
	_expect(not registry.requested_keys.has("smasher_wheel_state"), "unknown nonblank character ids should keep skipping Smasher wheel state")
	_verify_draw_arity_cache(drawer)

	if _failures.is_empty():
		print("battle_playfield_effects_drawer_character_gate_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_draw_arity_cache(drawer: Object) -> void:
	var draw2 := Draw2.new()
	var draw3 := Draw3.new()
	_expect(drawer._get_method_argument_count(draw3, "draw") >= 3, "playfield effects drawer should read draw arity")
	_expect(drawer.get("_method_argument_count_cache").size() == 1, "playfield effects drawer should cache direct arity lookup")
	_expect(drawer._get_method_argument_count(draw3, "draw") >= 3, "playfield effects drawer should reuse draw arity")
	_expect(drawer.get("_method_argument_count_cache").size() == 1, "playfield effects drawer should not grow direct arity cache on repeat")
	_expect(not drawer._method_accepts_argument_count(draw2, "draw", 3), "playfield effects drawer should reject short draw signatures")
	_expect(drawer._method_accepts_argument_count(draw3, "draw", 3), "playfield effects drawer should accept perf-aware draw signatures")
	_expect(drawer.get("_method_acceptance_cache").size() == 2, "playfield effects drawer should cache acceptance by renderer instance")
	_expect(drawer._method_accepts_argument_count(draw3, "draw", 3), "playfield effects drawer should reuse accepted draw signatures")
	_expect(drawer.get("_method_acceptance_cache").size() == 2, "playfield effects drawer should not grow acceptance cache on repeat")


func _has_any_requested(registry: RecordingRegistry, keys: Array[String]) -> bool:
	for key in keys:
		if registry.requested_keys.has(key):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
