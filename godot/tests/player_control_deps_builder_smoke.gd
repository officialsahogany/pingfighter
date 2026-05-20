extends SceneTree

const PlayerControlDepsBuilder := preload("res://scripts/core/battle_update_player_control_deps_builder.gd")
const BattleUpdateActorContext := preload("res://scripts/core/battle_update_actor_context.gd")

var _failures: Array[String] = []


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init() -> void:
		for key in [
			"smasher_input_reader",
			"viper_input_reader",
			"smasher_dash_state",
			"smasher_drive_input_state",
			"smasher_skill_state",
			"viper_skill_state",
			"smasher_skill_config",
			"viper_skill_config",
			"viper_skill_runtime",
			"viper_jetpack_state",
			"optimus_energy_state",
			"smasher_power_smash_state",
			"smasher_plasma_state",
			"smasher_recovery_state",
			"smasher_cleanse_state",
			"smasher_warp_gate_state",
			"smasher_wheel_state",
			"smasher_magnum_grip_state",
			"smasher_dash_spirit_state",
			"smasher_shield_kiting_state",
			"player_movement_state",
			"smasher_combo_state",
			"runtime_perk_state",
			"orb_hud_state",
			"active_item_runtime",
			"mythic_item_runtime",
			"round_flow_state",
			"game_audio",
			"battle_feedback_state",
		]:
			instances[key] = RefCounted.new()

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	var builder: Object = PlayerControlDepsBuilder.new()
	var registry := FakeRegistry.new()

	_verify_config(builder)
	_verify_smasher_deps(builder.build_deps(registry, "smasher"), registry, "direct builder")
	_verify_viper_deps(builder.build_deps(registry, "viper"), registry, "direct builder")
	_verify_optimus_deps(builder.build_deps(registry, "optimus"), registry, "direct builder")
	_verify_smasher_deps(BattleUpdateActorContext.new().build_player_control_deps(registry, "smasher"), registry, "actor context facade")
	_verify_viper_deps(BattleUpdateActorContext.new().build_player_control_deps(registry, "viper"), registry, "actor context facade")
	_verify_optimus_deps(BattleUpdateActorContext.new().build_player_control_deps(registry, "optimus"), registry, "actor context facade")

	var null_deps: Dictionary = builder.build_deps(null, "smasher")
	_expect(null_deps.get("registry", RefCounted.new()) == null, "null registry should be preserved in deps")
	_expect(null_deps.get("input_reader", RefCounted.new()) == null, "null registry should produce null input reader")
	_expect(null_deps.get("smasher_warp_gate_state", RefCounted.new()) == null, "null registry should produce null Smasher state deps")

	if _failures.is_empty():
		print("player_control_deps_builder_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_config(builder: Object) -> void:
	var smasher_config: Dictionary = builder.build_config("smasher")
	var viper_config: Dictionary = builder.build_config("viper")
	var optimus_config: Dictionary = builder.build_config("optimus")
	var fallback_config: Dictionary = builder.build_config("unknown")

	_expect(float(smasher_config.get("play_left", -1.0)) == 0.0, "Smasher config should include play left")
	_expect(float(smasher_config.get("play_right", 0.0)) == 760.0, "Smasher config should include play right")
	_expect(float(smasher_config.get("paddle_width", 0.0)) == 155.0, "Smasher config should include base paddle width")
	_expect(str(smasher_config.get("selected_character_type", "")) == "smasher", "Smasher config should include selected character type")
	_expect(float(smasher_config.get("paddle_speed", 0.0)) == 6.0, "Smasher config should include Smasher speed")
	_expect(float(viper_config.get("paddle_speed", 0.0)) == 4.0, "Viper config should include Viper speed")
	_expect(str(viper_config.get("selected_character_type", "")) == "viper", "Viper config should include selected character type")
	_expect(float(optimus_config.get("paddle_speed", 0.0)) == 4.0, "Optimus config should include Optimus speed")
	_expect(float(optimus_config.get("paddle_decel", 0.0)) == 0.25, "Optimus config should include Optimus deceleration")
	_expect(str(optimus_config.get("selected_character_type", "")) == "optimus", "Optimus config should include selected character type")
	_expect(float(fallback_config.get("paddle_speed", 0.0)) == 6.0, "Unknown character config should fall back to Smasher")


func _verify_smasher_deps(deps: Dictionary, registry: FakeRegistry, source: String) -> void:
	_expect(deps.get("registry", null) == registry, "%s should preserve registry in Smasher deps" % source)
	_expect(deps.get("input_reader", null) == registry.instances["smasher_input_reader"], "%s should use Smasher input reader" % source)
	_expect(deps.get("dash_state", null) == registry.instances["smasher_dash_state"], "%s should use shared dash state" % source)
	_expect(deps.get("drive_input_state", null) == registry.instances["smasher_drive_input_state"], "%s should include Drive input" % source)
	_expect(deps.get("skill_state", null) == registry.instances["smasher_skill_state"], "%s should include Smasher skill state" % source)
	_expect(deps.get("skill_config", null) == registry.instances["smasher_skill_config"], "%s should include Smasher skill config" % source)
	_expect(deps.get("combo_state", null) == registry.instances["smasher_combo_state"], "%s should include combo state" % source)
	_expect(deps.get("viper_skill_runtime", null) == null, "%s should not include Viper runtime for Smasher" % source)
	_expect(deps.get("viper_jetpack_state", null) == null, "%s should not include Viper jetpack for Smasher" % source)
	for key in [
		"power_state",
		"smasher_plasma_state",
		"smasher_recovery_state",
		"smasher_cleanse_state",
		"smasher_warp_gate_state",
		"smasher_wheel_state",
		"smasher_magnum_grip_state",
		"smasher_dash_spirit_state",
		"smasher_shield_kiting_state",
	]:
		_expect(deps.get(key, null) == registry.instances[_get_registry_key_for_dep(key)], "%s should include %s for Smasher" % [source, key])
	_verify_shared_deps(deps, registry, source)


func _verify_viper_deps(deps: Dictionary, registry: FakeRegistry, source: String) -> void:
	_expect(deps.get("registry", null) == registry, "%s should preserve registry in Viper deps" % source)
	_expect(deps.get("input_reader", null) == registry.instances["viper_input_reader"], "%s should use Viper input reader" % source)
	_expect(deps.get("dash_state", null) == registry.instances["smasher_dash_state"], "%s should keep shared dash state for Viper" % source)
	_expect(deps.get("drive_input_state", null) == null, "%s should not include Smasher Drive input for Viper" % source)
	_expect(deps.get("skill_state", null) == registry.instances["viper_skill_state"], "%s should include Viper skill state" % source)
	_expect(deps.get("skill_config", null) == registry.instances["viper_skill_config"], "%s should include Viper skill config" % source)
	_expect(deps.get("viper_skill_runtime", null) == registry.instances["viper_skill_runtime"], "%s should include Viper runtime" % source)
	_expect(deps.get("viper_jetpack_state", null) == registry.instances["viper_jetpack_state"], "%s should include Viper jetpack" % source)
	_expect(deps.get("combo_state", null) == null, "%s should not include combo state for Viper" % source)
	for key in [
		"power_state",
		"smasher_plasma_state",
		"smasher_recovery_state",
		"smasher_cleanse_state",
		"smasher_warp_gate_state",
		"smasher_wheel_state",
		"smasher_magnum_grip_state",
		"smasher_dash_spirit_state",
		"smasher_shield_kiting_state",
	]:
		_expect(deps.get(key, RefCounted.new()) == null, "%s should not include %s for Viper" % [source, key])
	_verify_shared_deps(deps, registry, source)


func _verify_optimus_deps(deps: Dictionary, registry: FakeRegistry, source: String) -> void:
	_expect(deps.get("registry", null) == registry, "%s should preserve registry in Optimus deps" % source)
	_expect(deps.get("input_reader", null) == registry.instances["smasher_input_reader"], "%s should use shared Smasher input reader for Optimus core movement" % source)
	_expect(deps.get("dash_state", null) == registry.instances["smasher_dash_state"], "%s should keep shared dash state for Optimus" % source)
	_expect(deps.get("optimus_energy_state", null) == registry.instances["optimus_energy_state"], "%s should include Optimus energy state" % source)
	_expect(deps.get("drive_input_state", null) == null, "%s should not include Smasher Drive input for Optimus" % source)
	_expect(deps.get("skill_state", null) == null, "%s should not include Smasher skill state for Optimus" % source)
	_expect(deps.get("skill_config", null) == null, "%s should not include Smasher skill config for Optimus" % source)
	_expect(deps.get("combo_state", null) == null, "%s should not include combo state for Optimus" % source)
	_expect(deps.get("viper_skill_runtime", null) == null, "%s should not include Viper runtime for Optimus" % source)
	_expect(deps.get("viper_jetpack_state", null) == null, "%s should not include Viper jetpack for Optimus" % source)
	for key in [
		"power_state",
		"smasher_plasma_state",
		"smasher_recovery_state",
		"smasher_cleanse_state",
		"smasher_warp_gate_state",
		"smasher_wheel_state",
		"smasher_magnum_grip_state",
		"smasher_dash_spirit_state",
		"smasher_shield_kiting_state",
	]:
		_expect(deps.get(key, RefCounted.new()) == null, "%s should not include %s for Optimus" % [source, key])
	_verify_shared_deps(deps, registry, source)


func _verify_shared_deps(deps: Dictionary, registry: FakeRegistry, source: String) -> void:
	for key in [
		"movement_state",
		"runtime_perk_state",
		"orb_hud_state",
		"active_item_runtime",
		"mythic_item_runtime",
		"round_state",
		"audio",
		"feedback",
	]:
		var instance_key: String = key
		match key:
			"movement_state":
				instance_key = "player_movement_state"
			"round_state":
				instance_key = "round_flow_state"
			"audio":
				instance_key = "game_audio"
			"feedback":
				instance_key = "battle_feedback_state"
		_expect(deps.get(key, null) == registry.instances[instance_key], "%s should include shared %s" % [source, key])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _get_registry_key_for_dep(dep_key: String) -> String:
	if dep_key == "power_state":
		return "smasher_power_smash_state"
	return dep_key
