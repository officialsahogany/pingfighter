extends SceneTree

const ActiveItemThrowRenderer := preload("res://scripts/items/active_item_throw_renderer.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_flare_zone_draw_budget()

	if _failures.is_empty():
		print("active_item_throw_flare_budget_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_flare_zone_draw_budget() -> void:
	_expect(ActiveItemThrowRenderer.FLARE_FLASH_LAYERS <= 1, "flare flash should cap bright ring layers")
	_expect(ActiveItemThrowRenderer.FLARE_GLOW_LAYERS <= 1, "flare glow should cap ambient ring layers")
	var source := FileAccess.get_file_as_string("res://scripts/items/active_item_throw_renderer.gd")
	var body := _function_body(source, "func _draw_flare_zones")
	_expect(body.find("for i in range(FLARE_FLASH_LAYERS)") >= 0, "flare flash should use the named budget constant")
	_expect(body.find("for i in range(FLARE_GLOW_LAYERS)") >= 0, "flare glow should use the named budget constant")
	_expect(body.find("for i in range(5)") < 0, "flare flash should not regress to five bright rings")
	_expect(body.find("for i in range(3)") < 0, "flare glow should not regress to three ambient rings")
	_expect(body.find("if intensity > 0.85") >= 0, "flare cross flash should stay gated to high intensity")


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
