extends SceneTree

const CommandoFirearmOriginGeometry := preload("res://scripts/characters/commando_firearm_origin_geometry.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_origin_geometry()
	_verify_removed_runtime_origin_geometry_bridges()

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
	var spawn_geometry: Dictionary = CommandoFirearmOriginGeometry.build_firearm_spawn_geometry_state(
		"commando_pistol",
		config,
		{"angle_offset": 0.0},
		field_size,
		cell_size,
		foot_offset,
		pistol_source,
		bazooka_source,
		net_source,
		"pistol"
	)
	var spawn_origin: Vector2 = _get_vector2(spawn_geometry.get("origin", Vector2.ZERO))
	var spawn_target: Vector2 = _get_vector2(spawn_geometry.get("target", Vector2.ZERO))
	var spawn_aim_origin: Vector2 = _get_vector2(spawn_geometry.get("aim_origin", Vector2.ZERO))
	var spawn_direction: Vector2 = _get_vector2(spawn_geometry.get("direction", Vector2.ZERO))
	_expect(spawn_origin == Vector2(535.5, 638.0), "spawn geometry state should preserve resolved origin")
	_expect(spawn_target == Vector2(380.0, 80.0), "spawn geometry state should preserve resolved target")
	_expect(spawn_aim_origin == spawn_origin, "spawn geometry state should preserve aim origin")
	_expect(spawn_direction.is_equal_approx((spawn_target - spawn_aim_origin).normalized()), "spawn geometry state should preserve resolved fire direction")


func _verify_removed_runtime_origin_geometry_bridges() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	var fire_spawn_source := FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_fire_spawn_state.gd")
	for bridge_name in [
		"_get_player_muzzle_pos",
		"_get_firearm_origin",
		"_get_firearm_aim_origin",
		"_get_bazooka_muzzle_pos",
		"_get_net_gun_projectile_pos",
		"_get_net_gun_aim_origin",
		"_get_pistol_fire_muzzle_pos",
		"_get_commando_fire_sheet_world_pos",
		"_get_player_pos_from_config",
		"_get_player_paddle_width_from_config",
		"_get_player_paddle_height_from_config",
		"_get_player_paddle_scale_from_config",
		"_get_boss_target_pos",
	]:
		_expect(source.find("func %s" % bridge_name) < 0, "runtime should not keep origin geometry bridge %s" % bridge_name)
	_expect(
		source.find("CommandoFirearmFireSpawnState.spawn_runtime_firearm_effect") >= 0,
		"runtime should delegate firearm effect spawning to the fire-spawn owner"
	)
	_expect(
		fire_spawn_source.find("CommandoFirearmOriginGeometry.build_firearm_spawn_geometry_state") >= 0,
		"fire-spawn owner should delegate spawn geometry state construction to origin geometry"
	)
	_expect(
		source.find("CommandoFirearmOriginGeometry.get_firearm_origin") < 0,
		"runtime should not call the lower-level firearm origin helper directly"
	)
	_expect(
		source.find("CommandoFirearmOriginGeometry.get_boss_target_pos") < 0,
		"runtime should not call the lower-level boss target helper directly"
	)
	_expect(
		source.find("CommandoFirearmOriginGeometry.get_firearm_aim_origin") < 0,
		"runtime should not call the lower-level aim origin helper directly"
	)
	_expect(
		source.find("CommandoFirearmProjectileSpawnState.get_fire_direction") < 0,
		"runtime should not call the lower-level fire direction helper directly"
	)


func _get_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
