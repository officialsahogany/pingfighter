extends SceneTree

const ActiveItemThrowRenderer := preload("res://scripts/items/active_item_throw_renderer.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_rotated_texture_region_guard()

	if _failures.is_empty():
		print("active_item_throw_rotated_texture_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_rotated_texture_region_guard() -> void:
	_expect(ActiveItemThrowRenderer != null, "renderer script should preload")
	var source := FileAccess.get_file_as_string("res://scripts/items/active_item_throw_renderer.gd")
	var body := _function_body(source, "func _draw_rotated_texture_region")
	_expect(body.find("if draw_size.x <= 0.0 or draw_size.y <= 0.0") >= 0, "rotated texture draw should skip empty draw sizes")
	_expect(body.find("var texture_size: Vector2 = texture.get_size()") >= 0, "rotated texture draw should read texture size")
	_expect(body.find("if texture_size.x <= 0.0 or texture_size.y <= 0.0") >= 0, "rotated texture draw should skip empty textures")
	_expect(body.find("var texture_size: Vector2 = texture.get_size()") < body.find("var angle: float = deg_to_rad(angle_degrees)"), "texture guard should run before corner math")
	_expect(body.find("_rotated_local(center, corner, angle)") >= 0, "rotated texture draw should use shared corner rotation helper")
	_expect(body.find("offset.x * cos_a") < 0, "rotated texture draw should not keep duplicated rotation math")
	_expect(source.find("func _rotated_local(center: Vector2, local: Vector2, angle: float) -> Vector2:") >= 0, "shared rotation helper should exist")


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
