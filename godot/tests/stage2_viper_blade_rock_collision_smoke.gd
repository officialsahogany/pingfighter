extends SceneTree

const Stage2PillarBackground := preload("res://scripts/stages/stage2/stage2_pillar_background.gd")
const ViperSkillRuntime := preload("res://scripts/characters/viper_skill_runtime.gd")


func _init() -> void:
	_test_air_blade_breaks_stage2_rock()
	_test_dark_blade_breaks_stage2_rock()
	_test_blade_rock_collision_is_stage2_only()
	print("stage2_viper_blade_rock_collision_smoke: ok")
	quit(0)


func _test_air_blade_breaks_stage2_rock() -> void:
	var background: Object = Stage2PillarBackground.new()
	background.rocks = [_build_landed_rock(1, Vector2(380.0, 520.0))]
	var runtime: Object = _launched_blade_runtime(false)
	runtime.apply_blade_rush_ball_motion(1.0, _scene(), _context(2), {"stage_background": background})
	_expect(int(background.get_rock_count()) == 0, "Air Blade projectile should destroy overlapping Stage 2 rocks")
	_expect(background.rock_fragments.size() > 0, "Air Blade rock destruction should use the normal fragment path")


func _test_dark_blade_breaks_stage2_rock() -> void:
	var background: Object = Stage2PillarBackground.new()
	background.rocks = [_build_landed_rock(2, Vector2(380.0, 520.0))]
	var runtime: Object = _launched_blade_runtime(true)
	runtime.apply_blade_rush_ball_motion(1.0, _scene(), _context(2), {"stage2_pillar_background": background})
	_expect(int(background.get_rock_count()) == 0, "Dark Blade projectile should destroy overlapping Stage 2 rocks")


func _test_blade_rock_collision_is_stage2_only() -> void:
	var background: Object = Stage2PillarBackground.new()
	background.rocks = [_build_landed_rock(3, Vector2(380.0, 520.0))]
	var runtime: Object = _launched_blade_runtime(false)
	runtime.apply_blade_rush_ball_motion(1.0, _scene(), _context(1), {"stage_background": background})
	_expect(int(background.get_rock_count()) == 1, "Blade projectile should not destroy rocks outside Stage 2 context")


func _launched_blade_runtime(dark_mode: bool) -> Object:
	var runtime: Object = ViperSkillRuntime.new()
	runtime.blade_dark_mode = dark_mode
	runtime._launch_blade_projectile(Vector2(302.5, 560.0), _context(2), {})
	return runtime


func _scene() -> Dictionary:
	return {
		"ball_pos": Vector2(60.0, 60.0),
		"ball_vel": Vector2(0.0, -12.0),
		"player_collision_cooldown": 0.0,
		"ball_impact_boost": 1.0,
	}


func _context(stage: int) -> Dictionary:
	return {
		"current_stage": stage,
		"ball_active": true,
		"ball_size": 28.6,
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"width": 760.0,
		"height": 750.0,
	}


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
	if condition:
		return
	push_error(message)
	quit(1)
