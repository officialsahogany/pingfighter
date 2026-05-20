extends SceneTree

const Stage1BalloonEvent := preload("res://scripts/stages/stage1/stage1_balloon_event.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_render_budgets()
	_verify_recent_start_helper()
	_verify_draw_paths_use_render_caps()

	if _failures.is_empty():
		print("stage1_balloon_event_render_budget_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_render_budgets() -> void:
	_expect(Stage1BalloonEvent.POP_EFFECT_RENDER_LIMIT <= 12, "Stage 1 balloon pop effects should keep a tight foreground cap")
	_expect(Stage1BalloonEvent.POP_EFFECT_FALLBACK_NORMAL_PARTICLES <= 10, "normal balloon fallback pop particles should stay compact")
	_expect(Stage1BalloonEvent.POP_EFFECT_FALLBACK_SPECIAL_PARTICLES <= 12, "special balloon fallback pop particles should stay compact")
	_expect(Stage1BalloonEvent.STARPOINT_PARTICLE_COUNT <= 10, "Stage 1 starpoint bursts should keep a small particle payload")
	_expect(Stage1BalloonEvent.STARPOINT_PARTICLE_RENDER_LIMIT <= 12, "Stage 1 starpoint particles should keep a tight foreground cap")
	_expect(Stage1BalloonEvent.SPECIAL_BALLOON_GLOW_LAYERS <= 1, "special balloon glow should keep a small layer count")
	_expect(Stage1BalloonEvent.STARPOINT_DROP_GLOW_LAYERS <= 1, "starpoint drop glow should keep a small layer count")
	_expect(Stage1BalloonEvent.STARPOINT_DROP_STAR_POINTS <= 8, "starpoint drop star polygons should keep a small point count")
	_expect(Stage1BalloonEvent.DOOR_RING_LAYERS <= 2, "balloon machine door should keep a small ring count")
	_expect(Stage1BalloonEvent.DOOR_RING_SEGMENTS <= 18, "balloon machine door arcs should keep a small segment count")
	_expect(Stage1BalloonEvent.MACHINE_CORE_ARC_SEGMENTS <= 14, "balloon machine core arcs should keep a small segment count")
	_expect(Stage1BalloonEvent.MACHINE_JOINT_ARC_SEGMENTS <= 6, "balloon machine joint arcs should keep a small segment count")
	_expect(Stage1BalloonEvent.MACHINE_BARREL_COUNT <= 4, "balloon machine should keep a small barrel count")
	_expect(Stage1BalloonEvent.MACHINE_BARREL_ARC_SEGMENTS <= 6, "balloon machine barrel arcs should keep a small segment count")
	_expect(Stage1BalloonEvent.BALLOON_TEXTURE_PREWARM_STEPS <= 5, "balloon event textures should prewarm across a small fixed step count")

	var event := Stage1BalloonEvent.new()
	var status: Dictionary = event.get_render_budget_status()
	_expect(int(status.get("pop_effect_render_limit", 0)) == Stage1BalloonEvent.POP_EFFECT_RENDER_LIMIT, "render budget status should expose the pop-effect cap")
	_expect(int(status.get("pop_effect_fallback_normal_particles", 0)) == Stage1BalloonEvent.POP_EFFECT_FALLBACK_NORMAL_PARTICLES, "render budget status should expose the normal pop fallback particle cap")
	_expect(int(status.get("pop_effect_fallback_special_particles", 0)) == Stage1BalloonEvent.POP_EFFECT_FALLBACK_SPECIAL_PARTICLES, "render budget status should expose the special pop fallback particle cap")
	_expect(int(status.get("starpoint_particle_count", 0)) == Stage1BalloonEvent.STARPOINT_PARTICLE_COUNT, "render budget status should expose the starpoint particle payload cap")
	_expect(int(status.get("starpoint_particle_render_limit", 0)) == Stage1BalloonEvent.STARPOINT_PARTICLE_RENDER_LIMIT, "render budget status should expose the starpoint-particle cap")
	_expect(int(status.get("special_balloon_glow_layers", 0)) == Stage1BalloonEvent.SPECIAL_BALLOON_GLOW_LAYERS, "render budget status should expose the special-balloon glow cap")
	_expect(int(status.get("starpoint_drop_glow_layers", 0)) == Stage1BalloonEvent.STARPOINT_DROP_GLOW_LAYERS, "render budget status should expose the starpoint-drop glow cap")
	_expect(int(status.get("starpoint_drop_star_points", 0)) == Stage1BalloonEvent.STARPOINT_DROP_STAR_POINTS, "render budget status should expose the starpoint-drop polygon point cap")
	_expect(int(status.get("door_ring_layers", 0)) == Stage1BalloonEvent.DOOR_RING_LAYERS, "render budget status should expose the door ring count")
	_expect(int(status.get("door_ring_segments", 0)) == Stage1BalloonEvent.DOOR_RING_SEGMENTS, "render budget status should expose the door arc segment count")
	_expect(int(status.get("machine_core_arc_segments", 0)) == Stage1BalloonEvent.MACHINE_CORE_ARC_SEGMENTS, "render budget status should expose the machine core arc segment count")
	_expect(int(status.get("machine_joint_arc_segments", 0)) == Stage1BalloonEvent.MACHINE_JOINT_ARC_SEGMENTS, "render budget status should expose the machine joint arc segment count")
	_expect(int(status.get("machine_barrel_count", 0)) == Stage1BalloonEvent.MACHINE_BARREL_COUNT, "render budget status should expose the machine barrel count")
	_expect(int(status.get("machine_barrel_arc_segments", 0)) == Stage1BalloonEvent.MACHINE_BARREL_ARC_SEGMENTS, "render budget status should expose the machine barrel arc segment count")
	_expect(int(status.get("balloon_texture_prewarm_steps", 0)) == Stage1BalloonEvent.BALLOON_TEXTURE_PREWARM_STEPS, "render budget status should expose the balloon texture prewarm step count")


func _verify_recent_start_helper() -> void:
	var event := Stage1BalloonEvent.new()
	var values: Array = []
	for index in range(100):
		values.append(index)
	_expect(event._recent_start(values, 48) == 52, "recent-start helper should draw only the newest capped entries")
	_expect(event._recent_start(values, 120) == 0, "recent-start helper should draw from zero when under budget")
	_expect(event._recent_start(values, 0) == values.size(), "zero render budget should draw nothing")


func _verify_draw_paths_use_render_caps() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_balloon_event.gd")
	_expect(source != "", "Stage 1 balloon event source should be readable")
	_expect(
		_function_body(source, "func _draw_pop_effects").find("_recent_start(pop_effects, POP_EFFECT_RENDER_LIMIT)") >= 0,
		"balloon pop draw should cap decorative rendering"
	)
	_expect(
		_function_body(source, "func _draw_starpoint_particles").find("_recent_start(starpoint_particles, STARPOINT_PARTICLE_RENDER_LIMIT)") >= 0,
		"starpoint particle draw should cap decorative rendering"
	)
	_expect(
		_function_body(source, "func _update_machine").find("_prewarm_active_event_assets()") >= 0,
		"balloon machine update should spread event texture prewarm before shooting"
	)
	_expect(
		_function_body(source, "func draw_foreground").find("_ensure_textures()") < 0,
		"balloon foreground draw should not force all texture loads during door or machine appearance"
	)
	_expect(
		_function_body(source, "func _get_balloon_texture").find("_ensure_textures()") < 0,
		"balloon sprite loader should only load the requested shell texture"
	)
	_expect(
		_function_body(source, "func _get_body_yaw_texture").find("_ensure_textures()") < 0,
		"balloon body-yaw loader should only load the requested body texture"
	)
	_expect(
		_function_body(source, "func _draw_pop_effects").find("balloon_pop_sheet = _load_texture(BALLOON_POP_SHEET_PATH)") >= 0,
		"balloon pop draw should lazily load only the pop sheet fallback"
	)
	_expect(
		_function_body(source, "func _draw_starpoint_drops").find("range(STARPOINT_DROP_STAR_POINTS)") >= 0,
		"starpoint drop draw should use the polygon point budget"
	)
	_expect(
		_function_body(source, "func _draw_starpoint_drops").find("draw_polyline") >= 0,
		"starpoint drop outlines should use one polyline draw instead of per-edge draw calls"
	)
	_expect(
		source.find("func draw_foreground(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO, perf_logger: Object = null)") >= 0,
		"balloon foreground draw should accept the shared perf logger"
	)
	_expect(
		source.find("func draw_background(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO, perf_logger: Object = null)") >= 0,
		"balloon background draw should accept the shared perf logger"
	)
	for label in [
		"stage1.balloon_bg.door",
		"stage1.balloon_bg.machine",
		"stage1.balloon_fg.balloons",
		"stage1.balloon_fg.pop_effects",
		"stage1.balloon_fg.star_particles",
		"stage1.balloon_fg.star_drops",
	]:
		_expect(source.find(label) >= 0, "balloon draw should report " + label)
	var scene_drawer_source := FileAccess.get_file_as_string("res://scripts/core/battle_playfield_scene_drawer.gd")
	_expect(
		scene_drawer_source.find("balloon_event.draw_background(canvas, shake_offset, perf_logger)") >= 0,
		"playfield scene drawer should forward BattlePerf to balloon background"
	)
	_expect(
		scene_drawer_source.find("balloon_event.draw_foreground(canvas, shake_offset, perf_logger)") >= 0,
		"playfield scene drawer should forward BattlePerf to balloon foreground"
	)


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next_func := source.find("\nfunc ", start + signature.length())
	if next_func < 0:
		return source.substr(start)
	return source.substr(start, next_func - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
