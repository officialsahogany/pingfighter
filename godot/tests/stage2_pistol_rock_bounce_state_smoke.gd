extends SceneTree

const Stage2PillarBackground := preload("res://scripts/stages/stage2/stage2_pillar_background.gd")
const Stage2PistolRockBounceState := preload("res://scripts/stages/stage2/stage2_pistol_rock_bounce_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_bounce_limit()
	_verify_hit_side_resolution()
	_verify_projectile_payload()
	_verify_background_delegates_pistol_bounce_state()

	if _failures.is_empty():
		print("stage2_pistol_rock_bounce_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_bounce_limit() -> void:
	_expect(not Stage2PistolRockBounceState.is_bounce_limit_reached({"rock_bounces": 1}), "pistol bounce state should allow bounces below the limit")
	_expect(Stage2PistolRockBounceState.is_bounce_limit_reached({"rock_bounces": 2}), "pistol bounce state should stop at the legacy two-bounce limit")


func _verify_hit_side_resolution() -> void:
	var rock_rect := Rect2(Vector2(100.0, 100.0), Vector2(40.0, 40.0))
	_expect(
		Stage2PistolRockBounceState.get_hit_side(Rect2(Vector2(95.0, 112.0), Vector2(10.0, 10.0)), rock_rect, Vector2(100.0, 117.0), Vector2.RIGHT, true) == "left",
		"pistol bounce state should choose the shallowest left overlap"
	)
	_expect(
		Stage2PistolRockBounceState.get_hit_side(Rect2(Vector2(112.0, 95.0), Vector2(10.0, 10.0)), rock_rect, Vector2(117.0, 100.0), Vector2.DOWN, true) == "top",
		"pistol bounce state should choose the shallowest top overlap"
	)
	_expect(
		Stage2PistolRockBounceState.get_hit_side(Rect2(), rock_rect, Vector2(80.0, 120.0), Vector2.RIGHT, false) == "left",
		"pistol bounce state should infer the side from relative position when only segment collision hits"
	)


func _verify_projectile_payload() -> void:
	var rock_rect := Rect2(Vector2(280.0, 280.0), Vector2(40.0, 40.0))
	var projectile := {
		"id": 80,
		"pos": Vector2(300.0, 260.0),
		"velocity": Vector2(0.0, 25.0),
		"rock_bounces": 0,
	}
	var bounced: Dictionary = Stage2PistolRockBounceState.build_projectile(
		projectile,
		Vector2(300.0, 260.0),
		Vector2(0.0, 25.0),
		5.0,
		rock_rect,
		"top"
	)
	_expect(int(bounced.get("rock_bounces", 0)) == 1, "pistol bounce state should increment rock bounce count")
	_expect(Vector2(bounced.get("pos", Vector2.ZERO)).y < rock_rect.position.y, "pistol bounce state should move the bullet outside the rock")
	_expect(is_equal_approx(Vector2(bounced.get("velocity", Vector2.ZERO)).y, -22.0), "pistol bounce state should preserve 0.88 velocity damping")
	_expect(is_equal_approx(float(bounced.get("speed", 0.0)), 22.0), "pistol bounce state should refresh projectile speed")
	_expect(str(bounced.get("stage2_rock_bounce_side", "")) == "top", "pistol bounce state should stamp the hit side")


func _verify_background_delegates_pistol_bounce_state() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_pillar_background.gd")
	_expect(source.find("Stage2PistolRockBounceState.is_bounce_limit_reached") >= 0, "background should delegate pistol bounce limits")
	_expect(source.find("Stage2PistolRockBounceState.get_hit_side") >= 0, "background should delegate pistol bounce side selection")
	_expect(source.find("Stage2PistolRockBounceState.build_projectile") >= 0, "background should delegate pistol bounce payload construction")
	_expect(source.find("func _get_pistol_rock_hit_side") < 0, "background should not keep pistol rock hit-side policy")
	_expect(source.find("func _build_pistol_rock_bounce_projectile") < 0, "background should not keep pistol bounce payload construction")

	var background := Stage2PillarBackground.new()
	background.rocks = [_build_landed_rock(8, Vector2(300.0, 300.0))]
	var result: Dictionary = background.resolve_pistol_projectile_rock_bounce({
		"id": 800,
		"pos": Vector2(300.0, 276.0),
		"prev_pos": Vector2(300.0, 260.0),
		"velocity": Vector2(0.0, 25.0),
		"speed": 25.0,
		"radius": 5.0,
	}, {}, {"current_stage": 2})
	_expect(bool(result.get("bounced", false)), "background should still expose pistol rock bounce results")
	var projectile: Dictionary = result.get("projectile", {})
	_expect(str(projectile.get("stage2_rock_bounce_side", "")) == "top", "background bounce result should keep the delegated hit side")


func _build_landed_rock(rock_id: int, center: Vector2) -> Dictionary:
	return {
		"id": rock_id,
		"pos": center,
		"target_pos": center,
		"quake_offset": Vector2.ZERO,
		"falling": false,
		"drop_delay": 0.0,
		"radius": 20.0,
		"visual_radius": 40.0,
		"hp": 1,
		"life": -1.0,
		"flash": 0.0,
		"water_target_flash": 0.0,
		"phase": 0.0,
		"seed": rock_id,
		"style_type": "gray_stone",
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
