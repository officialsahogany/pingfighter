extends SceneTree

const BallStatusOverlayRenderer := preload("res://scripts/ball/ball_status_overlay_renderer.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_overlay_render_budgets()
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
	_expect(BallStatusOverlayRenderer._FIRE_WEATHER_TRAIL_RENDER_LIMIT <= 12, "Fire-weather ball trail should cap rendered entries")
	_expect(BallStatusOverlayRenderer._FIRE_WEATHER_PRIMARY_ARC_POINTS <= 36, "Fire-weather primary arc should use the reduced point budget")
	_expect(BallStatusOverlayRenderer._POSEIDON_PRIMARY_ARC_POINTS <= 48, "Poseidon primary arc should use the reduced point budget")


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
