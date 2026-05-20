extends SceneTree

const RUNTIME_SOURCE_PATH := "res://scripts/characters/viper_skill_runtime.gd"
const SPEAR_RENDERER_SOURCE_PATH := "res://scripts/characters/viper_skill_chaos_spear_effect_renderer.gd"


func _init() -> void:
	var runtime_source := FileAccess.get_file_as_string(RUNTIME_SOURCE_PATH).replace("\r\n", "\n")
	_expect(not runtime_source.is_empty(), "should read viper skill runtime source")
	var renderer_source := FileAccess.get_file_as_string(SPEAR_RENDERER_SOURCE_PATH).replace("\r\n", "\n")
	_expect(not renderer_source.is_empty(), "should read Viper chaos spear renderer source")

	var start := runtime_source.find("func _draw_chaos_spear(")
	_expect(start >= 0, "should find _draw_chaos_spear")
	var next_func := runtime_source.find("\n\nfunc ", start + 1)
	_expect(next_func > start, "should find end of _draw_chaos_spear")
	var facade_body := runtime_source.substr(start, next_func - start)
	_expect(
		facade_body.find("chaos_spear_effect_renderer.draw_chaos_spear") >= 0,
		"chaos spear facade should delegate to the renderer"
	)

	start = renderer_source.find("func draw_chaos_spear(")
	_expect(start >= 0, "should find draw_chaos_spear renderer")
	next_func = renderer_source.find("\n\nfunc ", start + 1)
	if next_func < 0:
		next_func = renderer_source.length()
	var spear_body := renderer_source.substr(start, next_func - start)

	_expect(
		spear_body.find("draw_set_transform") < 0,
		"chaos spear body draw must not replace the active playfield transform"
	)
	_expect(
		spear_body.find("glow_center + dir * cos") >= 0,
		"chaos spear glow should use transformed polygon points directly"
	)

	print("chaos_spear_draw_transform_smoke: ok")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
