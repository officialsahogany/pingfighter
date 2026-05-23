extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	_verify_shared_projectile_trail_budget()

	if _failures.is_empty():
		print("active_item_throw_renderer_budget_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_shared_projectile_trail_budget() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/items/active_item_throw_renderer.gd")
	var slip_source := FileAccess.get_file_as_string("res://scripts/items/active_item_throw_slip_renderer.gd")
	_expect(source != "", "active item throw renderer source should be readable")
	_expect(slip_source != "", "active item throw slip renderer source should be readable")
	var grenade_body := _function_body(source, "func _draw_grenades")
	var flare_body := _function_body(source, "func _draw_flares")
	var trail_body := _function_body(source, "func _draw_projectile_trail")
	var slip_trail_body := _function_body(slip_source, "func _draw_projectile_trail")
	_expect(grenade_body.find("_draw_projectile_trail(") >= 0, "grenade draw should use the shared trail budget helper")
	_expect(flare_body.find("_draw_projectile_trail(") >= 0, "flare draw should use the shared trail budget helper")
	_expect(trail_body.find("var stride: int = 2 if trail_count > 5 else 1") >= 0, "projectile trail helper should thin long trails")
	_expect(trail_body.find("for i in range(0, trail_count, stride):") >= 0, "projectile trail helper should apply the stride")
	_expect(
		_function_body(source, "func draw").find("_slip_renderer.draw_bananas") >= 0,
		"throw renderer should delegate banana projectile drawing to the slip renderer"
	)
	_expect(
		_function_body(source, "func draw").find("_slip_renderer.draw_soaps") >= 0,
		"throw renderer should delegate soap projectile drawing to the slip renderer"
	)
	_expect(slip_trail_body.find("var stride: int = 2 if trail_count > 5 else 1") >= 0, "slip projectile trail helper should thin long trails")
	_expect(slip_trail_body.find("for i in range(0, trail_count, stride):") >= 0, "slip projectile trail helper should apply the stride")


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
