extends SceneTree

const CommandoFirearmHitGeometry := preload("res://scripts/characters/commando_firearm_hit_geometry.gd")
const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_geometry_helpers()
	_verify_runtime_delegates_hit_geometry()

	if _failures.is_empty():
		print("commando_firearm_hit_geometry_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_geometry_helpers() -> void:
	var boss_rect: Rect2 = CommandoFirearmHitGeometry.get_boss_rect({
		"boss_pos": Vector2(330.0, 50.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
	}, 760.0)
	_expect(boss_rect == Rect2(Vector2(330.0, 50.0), Vector2(100.0, 40.0)), "boss rect should use live position and hitbox size")

	var fallback_boss_rect: Rect2 = CommandoFirearmHitGeometry.get_boss_rect({}, 760.0)
	_expect(fallback_boss_rect == Rect2(Vector2(330.0, 60.0), Vector2(100.0, 40.0)), "boss rect should keep the runtime fallback")

	var projectile := {
		"pos": Vector2(100.0, 50.0),
		"radius": 4.0,
		"impact_radius": 36.0,
	}
	var profile := {
		"hitbox_size": Vector2(12.0, 8.0),
		"hitbox_offset": Vector2(2.0, -1.0),
		"impact_radius": 24.0,
	}
	var hitbox: Rect2 = CommandoFirearmHitGeometry.get_projectile_hitbox_rect(projectile, profile)
	_expect(hitbox == Rect2(Vector2(96.0, 45.0), Vector2(12.0, 8.0)), "projectile hitbox should preserve size and offset math")
	_expect(is_equal_approx(CommandoFirearmHitGeometry.get_explosion_radius(projectile, profile), 36.0), "projectile impact radius should beat profile fallback")

	projectile["explosion_radius"] = 55.0
	_expect(is_equal_approx(CommandoFirearmHitGeometry.get_explosion_radius(projectile, profile), 55.0), "projectile explosion radius should take priority")

	var rect := Rect2(Vector2(10.0, 10.0), Vector2(20.0, 20.0))
	_expect(CommandoFirearmHitGeometry.expand_rect(rect, Vector2(3.0, 4.0)) == Rect2(Vector2(7.0, 6.0), Vector2(26.0, 28.0)), "expanded rect should grow symmetrically")
	_expect(CommandoFirearmHitGeometry.circle_intersects_rect(Vector2(5.0, 20.0), 5.0, rect), "circle touching the rect edge should intersect")
	_expect(not CommandoFirearmHitGeometry.circle_intersects_rect(Vector2(4.0, 20.0), 5.0, rect), "circle outside the rect edge should miss")
	_expect(CommandoFirearmHitGeometry.circle_contains_rect_center(Vector2(20.0, 20.0), 1.0, rect), "circle center helper should hit when the rect center is inside")
	_expect(not CommandoFirearmHitGeometry.circle_contains_rect_center(Vector2(5.0, 20.0), 5.0, rect), "circle center helper should miss when only the rect edge touches")
	_expect(CommandoFirearmHitGeometry.segment_intersects_rect(Vector2(0.0, 20.0), Vector2(40.0, 20.0), rect), "segment crossing rect should intersect")
	_expect(not CommandoFirearmHitGeometry.segment_intersects_rect(Vector2(0.0, 5.0), Vector2(40.0, 5.0), rect), "segment above rect should miss")

	var net_profile := {
		"hitbox_size": Vector2(12.0, 12.0),
		"boss_inflate": Vector2(60.0, 40.0),
		"segment_radius": 6.0,
	}
	var net_boss_rect := Rect2(Vector2(330.0, 50.0), Vector2(100.0, 40.0))
	_expect(CommandoFirearmHitGeometry.net_projectile_hits_boss({
		"pos": Vector2(275.0, 70.0),
		"radius": 6.0,
	}, net_profile, net_boss_rect), "net projectile should hit the expanded boss capture box")
	_expect(CommandoFirearmHitGeometry.net_projectile_hits_boss({
		"prev_pos": Vector2(200.0, 70.0),
		"pos": Vector2(300.0, 70.0),
		"velocity": Vector2(100.0, 0.0),
		"radius": 6.0,
	}, net_profile, net_boss_rect), "net projectile segment should hit the expanded boss capture box")
	_expect(not CommandoFirearmHitGeometry.net_projectile_hits_boss({
		"prev_pos": Vector2(100.0, 10.0),
		"pos": Vector2(140.0, 10.0),
		"velocity": Vector2(40.0, 0.0),
		"radius": 6.0,
	}, net_profile, net_boss_rect), "net projectile away from the expanded boss box should miss")
	_expect(CommandoFirearmHitGeometry.net_projectile_passed_target({
		"prev_pos": Vector2(370.0, 70.0),
		"pos": Vector2(420.0, 70.0),
	}, Vector2(380.0, 70.0)), "net projectile should expire after passing near its target")
	_expect(not CommandoFirearmHitGeometry.net_projectile_passed_target({
		"prev_pos": Vector2(260.0, 70.0),
		"pos": Vector2(300.0, 70.0),
	}, Vector2(380.0, 70.0)), "net projectile should not pass target while still approaching")
	_expect(CommandoFirearmHitGeometry.projectile_hitbox_hits_boss({
		"weapon_id": "ak47",
		"pos": Vector2(328.0, 70.0),
		"radius": 3.0,
	}, {
		"hitbox_size": Vector2(6.0, 6.0),
	}, net_boss_rect), "bullet hitbox should intersect the boss rect")
	_expect(not CommandoFirearmHitGeometry.projectile_hitbox_hits_boss({
		"weapon_id": "ak47",
		"pos": Vector2(320.0, 70.0),
		"radius": 3.0,
	}, {
		"hitbox_size": Vector2(6.0, 6.0),
	}, net_boss_rect), "bullet hitbox outside the boss rect should miss")
	_expect(CommandoFirearmHitGeometry.projectile_hitbox_hits_boss({
		"weapon_id": "net_gun",
		"pos": Vector2(275.0, 70.0),
		"radius": 6.0,
	}, net_profile, net_boss_rect), "projectile hitbox helper should route net gun through expanded capture geometry")
	_expect(CommandoFirearmHitGeometry.target_reached_hitbox_hits_boss({
		"weapon_id": "bazooka",
		"pos": Vector2(380.0, 70.0),
		"explosion_radius": 36.0,
	}, {}, net_boss_rect), "target-reached bazooka helper should hit when the boss center is inside the blast")
	_expect(not CommandoFirearmHitGeometry.target_reached_hitbox_hits_boss({
		"weapon_id": "bazooka",
		"pos": Vector2(200.0, 70.0),
		"explosion_radius": CommandoFirearmRuntime.BAZOOKA_EXPLOSION_RADIUS,
	}, {}, Rect2(Vector2(350.0, 50.0), Vector2(100.0, 40.0))), "target-reached bazooka helper should require boss center inside the blast")
	_expect(not CommandoFirearmHitGeometry.target_reached_hitbox_hits_boss({
		"weapon_id": "fire_support",
		"pos": Vector2(200.0, 70.0),
		"explosion_radius": 155.0,
	}, {}, Rect2(Vector2(350.0, 50.0), Vector2(100.0, 40.0))), "target-reached fire support helper should require boss center inside the blast")
	_expect(not CommandoFirearmHitGeometry.target_reached_hitbox_hits_boss({
		"weapon_id": "suicide_drone",
		"pos": Vector2(200.0, 70.0),
		"explosion_radius": 155.0,
	}, {}, Rect2(Vector2(350.0, 50.0), Vector2(100.0, 40.0))), "target-reached suicide drone helper should require boss center inside the blast")
	_expect(not CommandoFirearmHitGeometry.target_reached_hitbox_hits_boss({
		"weapon_id": "ak47",
		"pos": Vector2(330.0, 70.0),
	}, {}, net_boss_rect), "target-reached helper should ignore non-explosive bullet weapons")
	var support_profile := {
		"impact_radius": 36.0,
	}
	var support_falling := {
		"weapon_id": "fire_support",
		"pos": Vector2(360.0, 70.0),
		"target_y": 82.0,
	}
	_expect(not CommandoFirearmHitGeometry.support_bomb_reached_target_y(support_falling, support_profile, net_boss_rect), "support bomb above target Y should keep falling")
	_expect(not support_falling.has("support_target_y_reached"), "support bomb above target Y should not set reached flag")
	var support_hit := {
		"weapon_id": "fire_support",
		"pos": Vector2(360.0, 90.0),
		"target_y": 82.0,
	}
	_expect(CommandoFirearmHitGeometry.support_bomb_reached_target_y(support_hit, support_profile, net_boss_rect), "support bomb reaching target Y should test explosion radius against boss center")
	_expect(is_equal_approx(float(CommandoFirearmHitGeometry.get_vector2(support_hit.get("pos", Vector2.ZERO), Vector2.ZERO).y), 82.0), "support bomb reached helper should clamp pos.y to target_y")
	_expect(is_equal_approx(float(support_hit.get("support_target_y_reached", 0.0)), 1.0), "support bomb reached helper should set reached flag")
	var support_edge_only := {
		"weapon_id": "fire_support",
		"pos": Vector2(200.0, 90.0),
		"target_y": 70.0,
	}
	_expect(not CommandoFirearmHitGeometry.support_bomb_reached_target_y(support_edge_only, {
		"impact_radius": 155.0,
	}, Rect2(Vector2(350.0, 50.0), Vector2(100.0, 40.0))), "support bomb blast should miss when only the boss edge is inside radius")
	_expect(CommandoFirearmHitGeometry.projectile_reached_target({
		"pos": Vector2(100.0, 100.0),
		"velocity": Vector2(10.0, 0.0),
		"radius": 5.0,
	}, Vector2(112.0, 100.0)), "projectile target reach should use velocity plus radius step")
	_expect(not CommandoFirearmHitGeometry.projectile_reached_target({
		"pos": Vector2(100.0, 100.0),
		"velocity": Vector2(10.0, 0.0),
		"radius": 5.0,
	}, Vector2(130.0, 100.0)), "projectile target reach should miss beyond the step")
	_expect(CommandoFirearmHitGeometry.projectile_reached_target({
		"pos": Vector2(100.0, 100.0),
		"velocity": Vector2.ZERO,
		"radius": 5.0,
	}, Vector2(108.0, 100.0)), "stationary projectile target reach should use radius plus margin")
	_expect(CommandoFirearmHitGeometry.projectile_out_of_bounds({
		"pos": Vector2(-81.0, 100.0),
	}, Vector2(760.0, 750.0)), "projectile out-of-bounds should use the left margin")
	_expect(not CommandoFirearmHitGeometry.projectile_out_of_bounds({
		"pos": Vector2(-80.0, 100.0),
	}, Vector2(760.0, 750.0)), "projectile out-of-bounds should keep exact margin inside")
	_expect(CommandoFirearmHitGeometry.projectile_out_of_bounds({
		"pos": Vector2(841.0, 100.0),
	}, Vector2(760.0, 750.0)), "projectile out-of-bounds should use field width plus margin")
	var rocket_profile := {
		"kind": "rocket",
		"explosion_radius": CommandoFirearmRuntime.BAZOOKA_EXPLOSION_RADIUS,
	}
	var wall_projectile := {
		"weapon_id": "bazooka",
		"pos": Vector2(360.0, 18.0),
	}
	_expect(CommandoFirearmHitGeometry.is_explosive_wall_impact(wall_projectile, rocket_profile, 760.0), "rocket touching the back wall should count as explosive wall impact")
	CommandoFirearmHitGeometry.clamp_explosive_wall_impact(wall_projectile, rocket_profile, 760.0)
	_expect(is_equal_approx(float(CommandoFirearmHitGeometry.get_vector2(wall_projectile.get("pos", Vector2.ZERO), Vector2.ZERO).y), 20.0), "wall impact clamp should pin rocket burst to the back wall")
	_expect(CommandoFirearmHitGeometry.explosive_wall_impact_hits_boss(wall_projectile, rocket_profile, net_boss_rect, 760.0), "wall impact helper should use explosion radius against boss rect")
	var edge_only_wall_projectile := {
		"weapon_id": "bazooka",
		"pos": Vector2(200.0, 18.0),
	}
	CommandoFirearmHitGeometry.clamp_explosive_wall_impact(edge_only_wall_projectile, rocket_profile, 760.0)
	_expect(not CommandoFirearmHitGeometry.explosive_wall_impact_hits_boss(edge_only_wall_projectile, rocket_profile, Rect2(Vector2(350.0, 0.0), Vector2(100.0, 40.0)), 760.0), "bazooka wall blast should miss when only the boss edge is inside radius")
	var side_wall_projectile := {
		"weapon_id": "bazooka",
		"pos": Vector2(766.0, 80.0),
	}
	CommandoFirearmHitGeometry.clamp_explosive_wall_impact(side_wall_projectile, rocket_profile, 760.0)
	_expect(is_equal_approx(float(CommandoFirearmHitGeometry.get_vector2(side_wall_projectile.get("pos", Vector2.ZERO), Vector2.ZERO).x), 750.0), "side wall impact clamp should pin rocket burst inside field width")
	_expect(not CommandoFirearmHitGeometry.is_explosive_wall_impact({
		"weapon_id": "ak47",
		"pos": Vector2(360.0, 18.0),
	}, {"kind": "bullet"}, 760.0), "non-rocket projectiles should not count as explosive wall impacts")

	var knockback_profile := {
		"knockback_power": 8.0,
		"knockback_velocity_scale": 0.5,
	}
	_expect(CommandoFirearmHitGeometry.get_hit_knockback_direction(Vector2(300.0, 70.0), Vector2.ZERO, Vector2(380.0, 70.0)) == 1, "left-side hits should push right")
	_expect(CommandoFirearmHitGeometry.get_hit_knockback_direction(Vector2(460.0, 70.0), Vector2.ZERO, Vector2(380.0, 70.0)) == -1, "right-side hits should push left")
	_expect(CommandoFirearmHitGeometry.get_hit_knockback_direction(Vector2(380.0, 70.0), Vector2(-2.0, 0.0), Vector2(380.0, 70.0)) == -1, "center hits should fall back to projectile velocity direction")
	_expect(is_equal_approx(CommandoFirearmHitGeometry.get_hit_knockback_velocity(knockback_profile, Vector2(300.0, 70.0), Vector2(6.0, 0.0), Vector2(380.0, 70.0)), 11.0), "knockback velocity should add horizontal velocity-scaled power")
	_expect(is_equal_approx(CommandoFirearmHitGeometry.get_hit_knockback_velocity({"knockback_power": 0.0}, Vector2(300.0, 70.0), Vector2.ZERO, Vector2(380.0, 70.0)), 0.0), "zero-power knockback should stay zero")
	var merged_profile: Dictionary = CommandoFirearmHitGeometry.get_result_hit_profile(knockback_profile, {
		"knockback_power": 3.0,
		"knockback_velocity_scale": 0.25,
	})
	_expect(is_equal_approx(float(merged_profile.get("knockback_power", 0.0)), 3.0), "result hit profile should override knockback power")
	_expect(is_equal_approx(float(merged_profile.get("knockback_velocity_scale", 0.0)), 0.25), "result hit profile should override velocity scale")
	_expect(is_equal_approx(float(knockback_profile.get("knockback_power", 0.0)), 8.0), "result hit profile should not mutate the source profile")


func _verify_runtime_delegates_hit_geometry() -> void:
	var runtime := CommandoFirearmRuntime.new()
	var boss_rect: Rect2 = runtime._get_boss_rect({
		"boss_pos": Vector2(330.0, 50.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
	})
	_expect(boss_rect == CommandoFirearmHitGeometry.get_boss_rect({
		"boss_pos": Vector2(330.0, 50.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
	}, 760.0), "runtime boss rect wrapper should delegate to hit geometry")

	var projectile := {"pos": Vector2(100.0, 50.0), "radius": 4.0}
	var profile := {"hitbox_size": Vector2(12.0, 8.0), "hitbox_offset": Vector2(2.0, -1.0)}
	_expect(runtime._get_projectile_hitbox_rect(projectile, profile) == CommandoFirearmHitGeometry.get_projectile_hitbox_rect(projectile, profile), "runtime projectile hitbox wrapper should delegate to hit geometry")
	_expect(runtime._segment_intersects_rect(Vector2(0.0, 20.0), Vector2(40.0, 20.0), Rect2(Vector2(10.0, 10.0), Vector2(20.0, 20.0))), "runtime segment wrapper should delegate to hit geometry")
	_expect(not runtime._circle_contains_rect_center(Vector2(5.0, 20.0), 5.0, Rect2(Vector2(10.0, 10.0), Vector2(20.0, 20.0))), "runtime center-circle wrapper should delegate to hit geometry")
	_expect(runtime._net_projectile_hits_boss({
		"pos": Vector2(275.0, 70.0),
		"radius": 6.0,
	}, {
		"hitbox_size": Vector2(12.0, 12.0),
		"boss_inflate": Vector2(60.0, 40.0),
		"segment_radius": 6.0,
	}, Rect2(Vector2(330.0, 50.0), Vector2(100.0, 40.0))), "runtime net boss hit wrapper should delegate to hit geometry")
	_expect(runtime._net_projectile_passed_target({
		"prev_pos": Vector2(370.0, 70.0),
		"pos": Vector2(420.0, 70.0),
	}, Vector2(380.0, 70.0)), "runtime net target-pass wrapper should delegate to hit geometry")
	_expect(runtime._projectile_hitbox_hits_boss({
		"weapon_id": "ak47",
		"pos": Vector2(328.0, 70.0),
		"radius": 3.0,
	}, {
		"hitbox_size": Vector2(6.0, 6.0),
	}, Rect2(Vector2(330.0, 50.0), Vector2(100.0, 40.0))), "runtime projectile hitbox wrapper should delegate to hit geometry")
	_expect(runtime._get_direct_hit_impact_reason({
		"weapon_id": "ak47",
		"pos": Vector2(328.0, 70.0),
		"radius": 3.0,
	}, {
		"hitbox_size": Vector2(6.0, 6.0),
	}, Rect2(Vector2(330.0, 50.0), Vector2(100.0, 40.0))) == "target", "runtime direct hit reason should return target on immediate hitbox contact")
	_expect(runtime._get_direct_hit_impact_reason({
		"weapon_id": "ak47",
		"pos": Vector2(300.0, 70.0),
		"radius": 3.0,
	}, {
		"hitbox_size": Vector2(6.0, 6.0),
	}, Rect2(Vector2(330.0, 50.0), Vector2(100.0, 40.0))) == "", "runtime direct hit reason should stay empty when the hitbox misses")
	_expect(runtime._target_reached_hitbox_hits_boss({
		"weapon_id": "bazooka",
		"pos": Vector2(380.0, 70.0),
		"explosion_radius": 36.0,
	}, {}, Rect2(Vector2(330.0, 50.0), Vector2(100.0, 40.0))), "runtime target-reached wrapper should delegate to hit geometry")
	_expect(not runtime._target_reached_hitbox_hits_boss({
		"weapon_id": "suicide_drone",
		"pos": Vector2(200.0, 70.0),
		"explosion_radius": 155.0,
	}, {}, Rect2(Vector2(350.0, 50.0), Vector2(100.0, 40.0))), "runtime target-reached drone helper should require boss center inside the blast")
	var runtime_support_hit := {
		"weapon_id": "fire_support",
		"pos": Vector2(360.0, 90.0),
		"target_y": 82.0,
	}
	_expect(runtime._support_bomb_reached_target_y(runtime_support_hit, {
		"impact_radius": 36.0,
	}, Rect2(Vector2(330.0, 50.0), Vector2(100.0, 40.0))), "runtime support-bomb target-Y wrapper should delegate to hit geometry")
	_expect(is_equal_approx(float(runtime_support_hit.get("support_target_y_reached", 0.0)), 1.0), "runtime support-bomb wrapper should preserve reached flag side effect")
	_expect(runtime._projectile_reached_target({
		"pos": Vector2(100.0, 100.0),
		"velocity": Vector2(10.0, 0.0),
		"radius": 5.0,
	}, Vector2(112.0, 100.0)), "runtime target reach wrapper should delegate to hit geometry")
	_expect(runtime._projectile_out_of_bounds({
		"pos": Vector2(841.0, 100.0),
	}), "runtime out-of-bounds wrapper should delegate to hit geometry")
	_expect(runtime._get_projectile_terminal_impact_reason({
		"life_frames": 0.0,
		"pos": Vector2(100.0, 100.0),
	}) == "expired", "runtime terminal impact reason should expire depleted projectiles")
	_expect(runtime._get_projectile_terminal_impact_reason({
		"life_frames": 12.0,
		"pos": Vector2(841.0, 100.0),
	}) == "out_of_bounds", "runtime terminal impact reason should catch out-of-bounds projectiles")
	_expect(runtime._get_projectile_terminal_impact_reason({
		"life_frames": 0.0,
		"pos": Vector2(841.0, 100.0),
	}) == "expired", "runtime terminal impact reason should preserve life-expired priority")
	_expect(runtime._get_projectile_terminal_impact_reason({
		"life_frames": 12.0,
		"pos": Vector2(100.0, 100.0),
	}) == "", "runtime terminal impact reason should stay empty for live in-bounds projectiles")
	var runtime_wall_projectile := {
		"weapon_id": "bazooka",
		"pos": Vector2(360.0, 18.0),
	}
	_expect(runtime._is_explosive_wall_impact(runtime_wall_projectile, {"kind": "rocket"}), "runtime wall impact wrapper should delegate to hit geometry")
	runtime._clamp_explosive_wall_impact(runtime_wall_projectile, {"kind": "rocket"})
	_expect(is_equal_approx(float(CommandoFirearmHitGeometry.get_vector2(runtime_wall_projectile.get("pos", Vector2.ZERO), Vector2.ZERO).y), 20.0), "runtime wall clamp wrapper should delegate to hit geometry")
	_expect(runtime._explosive_wall_impact_hits_boss(runtime_wall_projectile, {
		"kind": "rocket",
		"explosion_radius": CommandoFirearmRuntime.BAZOOKA_EXPLOSION_RADIUS,
	}, Rect2(Vector2(330.0, 50.0), Vector2(100.0, 40.0))), "runtime wall impact boss-hit wrapper should delegate to hit geometry")
	var runtime_wall_hit_projectile := {
		"weapon_id": "bazooka",
		"pos": Vector2(360.0, 18.0),
	}
	_expect(runtime._get_explosive_wall_impact_reason(runtime_wall_hit_projectile, {
		"kind": "rocket",
		"explosion_radius": CommandoFirearmRuntime.BAZOOKA_EXPLOSION_RADIUS,
	}, Rect2(Vector2(330.0, 50.0), Vector2(100.0, 40.0))) == "target", "runtime wall impact reason should return target when the clamped blast hits boss")
	_expect(is_equal_approx(float(CommandoFirearmHitGeometry.get_vector2(runtime_wall_hit_projectile.get("pos", Vector2.ZERO), Vector2.ZERO).y), 20.0), "runtime wall impact reason should preserve clamp side effects")
	var runtime_wall_miss_projectile := {
		"weapon_id": "bazooka",
		"pos": Vector2(-5.0, 500.0),
	}
	_expect(runtime._get_explosive_wall_impact_reason(runtime_wall_miss_projectile, {
		"kind": "rocket",
		"explosion_radius": 20.0,
	}, Rect2(Vector2(330.0, 50.0), Vector2(100.0, 40.0))) == "wall", "runtime wall impact reason should return wall when the blast misses boss")
	_expect(is_equal_approx(float(CommandoFirearmHitGeometry.get_vector2(runtime_wall_miss_projectile.get("pos", Vector2.ZERO), Vector2.ZERO).x), 10.0), "runtime wall impact reason should clamp side-wall bursts")
	_expect(runtime._get_explosive_wall_impact_reason({
		"weapon_id": "ak47",
		"pos": Vector2(360.0, 18.0),
	}, {"kind": "bullet"}, Rect2(Vector2(330.0, 50.0), Vector2(100.0, 40.0))) == "", "runtime wall impact reason should ignore non-explosive projectiles")
	_expect(runtime._get_hit_knockback_direction(Vector2(300.0, 70.0), Vector2.ZERO, {
		"boss_pos": Vector2(330.0, 50.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
	}) == 1, "runtime knockback direction wrapper should delegate to hit geometry")
	_expect(is_equal_approx(runtime._get_hit_knockback_velocity({
		"knockback_power": 8.0,
		"knockback_velocity_scale": 0.5,
	}, Vector2(300.0, 70.0), Vector2(6.0, 0.0), {
		"boss_pos": Vector2(330.0, 50.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
	}), 11.0), "runtime knockback velocity wrapper should delegate to hit geometry")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
