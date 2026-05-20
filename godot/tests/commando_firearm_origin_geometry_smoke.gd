extends SceneTree

const CommandoFirearmOriginGeometry := preload("res://scripts/characters/commando_firearm_origin_geometry.gd")
const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_origin_geometry()
	_verify_runtime_delegates_origin_geometry()

	if _failures.is_empty():
		print("commando_firearm_origin_geometry_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_origin_geometry() -> void:
	var field_size := Vector2(760.0, 750.0)
	var config := {
		"player_pos": Vector2(420.0, 654.0),
		"paddle_width": 155.0,
		"paddle_height": 50.0,
	}
	var pistol_source := Vector2(118.0, 82.0)
	var bazooka_source := Vector2(134.0, 69.0)
	var net_source := Vector2(106.0, 82.0)
	var cell_size := Vector2(160.0, 160.0)
	var foot_offset := 12.0

	_expect(
		CommandoFirearmOriginGeometry.get_player_pos_from_config({}, field_size) == Vector2(380.0, 680.0),
		"default player position should match the runtime fallback"
	)
	_expect(
		CommandoFirearmOriginGeometry.get_player_muzzle_pos(config, field_size) == Vector2(497.5, 671.0),
		"generic player muzzle should use paddle center and capped height offset"
	)
	_expect(
		CommandoFirearmOriginGeometry.get_commando_fire_sheet_world_pos(config, pistol_source, field_size, cell_size, foot_offset) == Vector2(535.5, 638.0),
		"pistol authored muzzle should match the live delayed-fire anchor"
	)
	_expect(
		CommandoFirearmOriginGeometry.get_commando_fire_sheet_world_pos(config, bazooka_source, field_size, cell_size, foot_offset) == Vector2(551.5, 625.0),
		"bazooka authored muzzle should preserve its source anchor"
	)
	_expect(
		CommandoFirearmOriginGeometry.get_commando_fire_sheet_world_pos(config, net_source, field_size, cell_size, foot_offset) == Vector2(523.5, 638.0),
		"net gun authored muzzle should preserve its source anchor"
	)

	var scaled_config := config.duplicate(true)
	scaled_config["player_paddle_scale"] = 1.25
	_expect(
		CommandoFirearmOriginGeometry.get_commando_fire_sheet_world_pos(scaled_config, pistol_source, field_size, cell_size, foot_offset) == Vector2(545.0, 618.5),
		"explicit player scale should resize the authored muzzle sheet anchor"
	)

	_expect(is_equal_approx(CommandoFirearmOriginGeometry.get_player_paddle_width_from_config({"paddle_width": -5.0}), 1.0), "paddle width should clamp to at least one pixel")
	_expect(is_equal_approx(CommandoFirearmOriginGeometry.get_player_paddle_height_from_config({"paddle_height": 0.0}), 1.0), "paddle height should clamp to at least one pixel")
	_expect(is_equal_approx(CommandoFirearmOriginGeometry.get_player_paddle_scale_from_config({"player_paddle_scale": 0.05}, 155.0), 0.1), "paddle scale should clamp to the runtime minimum")

	var boss_target: Vector2 = CommandoFirearmOriginGeometry.get_boss_target_pos({
		"boss_pos": Vector2(330.0, 50.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
	}, 760.0)
	_expect(boss_target == Vector2(380.0, 70.0), "boss target should use the center of the configured boss hitbox")
	_expect(
		CommandoFirearmOriginGeometry.get_firearm_origin("commando_pistol", config, {}, field_size, cell_size, foot_offset, pistol_source, bazooka_source, net_source, "pistol") == Vector2(535.5, 638.0),
		"firearm origin should use the authored pistol source for Commando pistol shots"
	)
	_expect(
		CommandoFirearmOriginGeometry.get_firearm_origin("pistol", config, {"slingshot": true}, field_size, cell_size, foot_offset, pistol_source, bazooka_source, net_source, "pistol") == Vector2(497.5, 671.0),
		"firearm origin should use the generic muzzle for slingshot profile shots"
	)
	_expect(
		CommandoFirearmOriginGeometry.get_firearm_origin("bazooka", config, {"vertical_launch": true}, field_size, cell_size, foot_offset, pistol_source, bazooka_source, net_source, "pistol") == Vector2(551.5, 625.0),
		"firearm origin should use the authored bazooka source for vertical launches"
	)
	_expect(
		CommandoFirearmOriginGeometry.get_firearm_origin("net_gun", config, {}, field_size, cell_size, foot_offset, pistol_source, bazooka_source, net_source, "pistol") == Vector2(523.5, 638.0),
		"firearm origin should use the authored net-gun source"
	)
	_expect(
		CommandoFirearmOriginGeometry.get_firearm_aim_origin("net_gun", Vector2(12.0, 34.0)) == Vector2(12.0, 34.0),
		"firearm aim origin should preserve the resolved origin"
	)


func _verify_runtime_delegates_origin_geometry() -> void:
	var runtime := CommandoFirearmRuntime.new()
	var config := {
		"player_pos": Vector2(420.0, 654.0),
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"boss_pos": Vector2(330.0, 50.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
	}
	var field_size := Vector2(760.0, 750.0)
	var cell_size := Vector2(160.0, 160.0)
	var foot_offset := 12.0

	_expect(runtime._get_player_muzzle_pos(config) == CommandoFirearmOriginGeometry.get_player_muzzle_pos(config, field_size), "runtime generic muzzle wrapper should delegate")
	_expect(runtime._get_pistol_fire_muzzle_pos(config) == CommandoFirearmOriginGeometry.get_commando_fire_sheet_world_pos(config, Vector2(118.0, 82.0), field_size, cell_size, foot_offset), "runtime pistol muzzle wrapper should delegate")
	_expect(runtime._get_bazooka_muzzle_pos(config) == CommandoFirearmOriginGeometry.get_commando_fire_sheet_world_pos(config, Vector2(134.0, 69.0), field_size, cell_size, foot_offset), "runtime bazooka muzzle wrapper should delegate")
	_expect(runtime._get_net_gun_projectile_pos(config) == CommandoFirearmOriginGeometry.get_commando_fire_sheet_world_pos(config, Vector2(106.0, 82.0), field_size, cell_size, foot_offset), "runtime net gun muzzle wrapper should delegate")
	_expect(runtime._get_player_pos_from_config(config) == CommandoFirearmOriginGeometry.get_player_pos_from_config(config, field_size), "runtime player-position wrapper should delegate")
	_expect(runtime._get_boss_target_pos(config) == CommandoFirearmOriginGeometry.get_boss_target_pos(config, 760.0), "runtime boss target wrapper should delegate")
	_expect(runtime._get_firearm_origin("commando_pistol", config, {}) == runtime._get_pistol_fire_muzzle_pos(config), "runtime firearm origin wrapper should delegate pistol origin")
	_expect(runtime._get_firearm_origin("pistol", config, {"slingshot": true}) == runtime._get_player_muzzle_pos(config), "runtime firearm origin wrapper should delegate slingshot fallback origin")
	_expect(runtime._get_firearm_origin("bazooka", config, {"vertical_launch": true}) == runtime._get_bazooka_muzzle_pos(config), "runtime firearm origin wrapper should delegate bazooka origin")
	_expect(runtime._get_firearm_origin("net_gun", config, {}) == runtime._get_net_gun_projectile_pos(config), "runtime firearm origin wrapper should delegate net-gun origin")
	_expect(runtime._get_firearm_aim_origin("net_gun", config, Vector2(12.0, 34.0)) == Vector2(12.0, 34.0), "runtime firearm aim-origin wrapper should delegate")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
