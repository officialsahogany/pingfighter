extends SceneTree

const ViperHoverSheetOverride := preload("res://scripts/core/viper_hover_sheet_override.gd")
const PlayerControlConfigBuilder := preload("res://scripts/core/battle_scene_player_control_config_builder.gd")
const BattleDrawActorContext := preload("res://scripts/core/battle_draw_actor_context.gd")

var _failures: Array[String] = []


class FakeContextBuilder:
	extends RefCounted

	func build_player_control_config(_character_type: String) -> Dictionary:
		return {}


class FakeOwner:
	extends Node

	var battle_textures: Dictionary = {}

	func _init() -> void:
		var dummy_texture := PlaceholderTexture2D.new()
		dummy_texture.size = Vector2(16.0, 16.0)
		battle_textures["viper_player_hover_left_sheet"] = dummy_texture
		battle_textures["viper_player_hover_right_sheet"] = dummy_texture


func _init() -> void:
	_verify_default_off()
	_verify_env_force_disable()
	_verify_flag_path_constant()

	if _failures.is_empty():
		print("viper_hover_sheet_override_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_default_off() -> void:
	ViperHoverSheetOverride.reset_cache_for_test()
	OS.set_environment(ViperHoverSheetOverride.ENV_KEY, "")
	_expect(not ViperHoverSheetOverride.is_hover_sheet_force_disabled(), "override should be off when env var is empty and no flag file exists")
	var owner := FakeOwner.new()
	var builder := PlayerControlConfigBuilder.new()
	var config: Dictionary = builder.build_config(owner, null, "viper", FakeContextBuilder.new())
	_expect(bool(config.get("viper_jetpack_hover_sheet_fx", false)), "with hover textures loaded and override off, hover_sheet_fx should be on")
	owner.free()


func _verify_env_force_disable() -> void:
	ViperHoverSheetOverride.reset_cache_for_test()
	OS.set_environment(ViperHoverSheetOverride.ENV_KEY, "1")
	_expect(ViperHoverSheetOverride.is_hover_sheet_force_disabled(), "override should switch on when env var is '1'")
	var owner := FakeOwner.new()
	var builder := PlayerControlConfigBuilder.new()
	var config: Dictionary = builder.build_config(owner, null, "viper", FakeContextBuilder.new())
	_expect(not bool(config.get("viper_jetpack_hover_sheet_fx", true)), "override should force hover_sheet_fx off even when textures are loaded")
	owner.free()
	OS.set_environment(ViperHoverSheetOverride.ENV_KEY, "")
	ViperHoverSheetOverride.reset_cache_for_test()


func _verify_flag_path_constant() -> void:
	_expect(ViperHoverSheetOverride.FLAG_PATH == "res://viper_force_particle_fx.flag", "flag path constant should stay stable so external tooling can drop the flag")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
