extends SceneTree

const BattlePlayfieldEffectsDrawer := preload("res://scripts/core/battle_playfield_effects_drawer.gd")

var _failures: Array[String] = []


class RecordingRegistry:
	extends RefCounted

	var requested_keys: Array[String] = []

	func get_instance(key: String) -> Object:
		requested_keys.append(key)
		return null


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
	drawer.draw_smasher_wheel_effects(null, registry, Vector2.ZERO, smasher_context)
	_expect(registry.requested_keys.has("smasher_wheel_state"), "Smasher context should still request Smasher wheel state")

	registry.requested_keys.clear()
	drawer.draw_smasher_wheel_effects(null, registry, Vector2.ZERO, {"selected_character_type": "optimus"})
	_expect(not registry.requested_keys.has("smasher_wheel_state"), "explicit non-Smasher characters should skip Smasher wheel state")

	if _failures.is_empty():
		print("battle_playfield_effects_drawer_character_gate_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _has_any_requested(registry: RecordingRegistry, keys: Array[String]) -> bool:
	for key in keys:
		if registry.requested_keys.has(key):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
