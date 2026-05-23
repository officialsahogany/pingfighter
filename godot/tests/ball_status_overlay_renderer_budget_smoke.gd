extends SceneTree

const BallRenderer := preload("res://scripts/ball/ball_renderer.gd")
const BallStatusOverlayRenderer := preload("res://scripts/ball/ball_status_overlay_renderer.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_overlay_render_budgets()
	_verify_fire_weather_overlay_size_guard()
	_verify_clear_resets_overlay_trails()
	_verify_ball_renderer_clears_status_overlay()
	_verify_ragnarok_draw_is_deterministic()
	_verify_timed_trail_trim_keeps_recent_entries()

	if _failures.is_empty():
		print("ball_status_overlay_renderer_budget_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_overlay_render_budgets() -> void:
	_expect(BallStatusOverlayRenderer._RAGNAROK_BOLT_COUNT <= 5, "Ragnarok ball bolts should stay within the render budget")
	_expect(BallStatusOverlayRenderer._RAGNAROK_BRANCH_COUNT <= 2, "Ragnarok ball branches should stay within the render budget")
	_expect(BallStatusOverlayRenderer._RAGNAROK_ORBIT_PARTICLE_COUNT <= 10, "Ragnarok ball orbit particles should stay within the render budget")
	_expect(BallStatusOverlayRenderer._RAGNAROK_TRAIL_RENDER_LIMIT <= 12, "Ragnarok ball trail should cap rendered entries")
	_expect(BallStatusOverlayRenderer._FIRE_WEATHER_TRAIL_RENDER_LIMIT <= 8, "Fire-weather ball trail should cap rendered entries")
	_expect(BallStatusOverlayRenderer._FIRE_WEATHER_PRIMARY_ARC_POINTS <= 36, "Fire-weather primary arc should use the reduced point budget")
	_expect(BallStatusOverlayRenderer._POSEIDON_PRIMARY_ARC_POINTS <= 48, "Poseidon primary arc should use the reduced point budget")


func _verify_fire_weather_overlay_size_guard() -> void:
	_expect(BallStatusOverlayRenderer._FIRE_WEATHER_TRAIL_LIFE_MSEC <= 260.0, "Fire-weather ball trail should not linger into an oversized comet")
	_expect(BallStatusOverlayRenderer._FIRE_WEATHER_TRAIL_RADIUS_MAX_MULT <= 0.72, "Fire-weather trail circles should stay smaller than the ball aura")
	_expect(BallStatusOverlayRenderer._FIRE_WEATHER_OUTER_RADIUS_MULT <= 1.30, "Fire-weather outer aura should stay close to the normal ball radius")
	_expect(BallStatusOverlayRenderer._FIRE_WEATHER_SECONDARY_ARC_RADIUS_MULT <= 1.32, "Fire-weather orbit arcs should stay close to the normal ball radius")

	var source := FileAccess.get_file_as_string("res://scripts/ball/ball_status_overlay_renderer.gd")
	var body := _function_body(source, "func _draw_fire_weather_ball_overlay")
	_expect(body != "", "Fire-weather ball overlay body should be readable")
	_expect(body.find("radius + 21.0") < 0, "Fire-weather overlay should not use the old oversized fixed outer radius")
	_expect(body.find("radius + 15.0") < 0, "Fire-weather overlay should not use the old oversized fixed arc radius")
	_expect(body.find("0.55 + 0.85 * t") < 0, "Fire-weather trail should not use the old large trail-radius formula")
	_expect(body.find("ball_speed > 0.5") >= 0, "Fire-weather trail should not accumulate while the ball is stationary")


func _verify_clear_resets_overlay_trails() -> void:
	var renderer := BallStatusOverlayRenderer.new()
	renderer._fire_weather_trail.append({"pos": Vector2(10.0, 20.0), "time": 1.0})
	renderer._ragnarok_trail.append({"pos": Vector2(30.0, 40.0), "time": 1.0})
	renderer._fire_weather_active_last_frame = true
	renderer._ragnarok_active_last_frame = true
	renderer.clear()
	_expect(renderer._fire_weather_trail.is_empty(), "clear should empty the fire-weather trail")
	_expect(renderer._ragnarok_trail.is_empty(), "clear should empty the Ragnarok trail")
	_expect(not renderer._fire_weather_active_last_frame, "clear should reset the fire-weather active flag")
	_expect(not renderer._ragnarok_active_last_frame, "clear should reset the Ragnarok active flag")


func _verify_ball_renderer_clears_status_overlay() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ball/ball_renderer.gd")
	var body := _function_body(source, "func clear")
	_expect(body.find("status_overlay_renderer.clear()") >= 0, "Ball renderer clear should reset status overlay trails on round reset")
	var renderer := BallRenderer.new()
	renderer.status_overlay_renderer._fire_weather_trail.append({"pos": Vector2(1.0, 2.0), "time": 1.0})
	renderer.clear()
	_expect(renderer.status_overlay_renderer._fire_weather_trail.is_empty(), "Ball renderer clear should empty the fire-weather trail")


func _verify_ragnarok_draw_is_deterministic() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ball/ball_status_overlay_renderer.gd")
	var body := _function_body(source, "func _draw_ragnarok_hammer_ball_overlay")
	_expect(body != "", "Ragnarok ball overlay body should be readable")
	_expect(body.find("randf") < 0, "Ragnarok ball overlay should not call randf during draw")
	_expect(body.find("randi") < 0, "Ragnarok ball overlay should not call randi during draw")
	_expect(body.find("_trim_timed_trail_in_place") >= 0, "Ragnarok ball overlay should use capped in-place trail trimming")


func _verify_timed_trail_trim_keeps_recent_entries() -> void:
	var renderer := BallStatusOverlayRenderer.new()
	var trail: Array = []
	for index in range(20):
		trail.append({"pos": Vector2(float(index), 0.0), "time": float(index * 10)})

	renderer._trim_timed_trail_in_place(trail, 200.0, 1000.0, 6)
	_expect(trail.size() == 6, "trail trim should keep no more than the render cap")
	_expect(_entry_x(trail, 0) == 14.0, "trail trim should keep the oldest entry inside the recent cap")
	_expect(_entry_x(trail, 5) == 19.0, "trail trim should keep the newest entry")

	renderer._trim_timed_trail_in_place(trail, 260.0, 90.0, 12)
	_expect(trail.size() == 2, "trail trim should remove entries older than the lifetime")
	_expect(_entry_x(trail, 0) == 18.0, "lifetime trim should preserve recent survivors in order")
	_expect(_entry_x(trail, 1) == 19.0, "lifetime trim should preserve the newest survivor")


func _entry_x(trail: Array, index: int) -> float:
	if index < 0 or index >= trail.size():
		return -1.0
	var entry: Dictionary = trail[index]
	var pos: Vector2 = entry.get("pos", Vector2(-1.0, 0.0))
	return pos.x


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
