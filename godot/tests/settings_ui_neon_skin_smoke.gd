extends SceneTree

const Overlay := preload("res://scripts/hud/pause_menu_overlay.gd")

var _failures: Array[String] = []
var _probe: NeonSkinProbe = null
var _frame_count := 0


class NeonSkinProbe:
	extends Node2D

	var overlay: Object = Overlay.new()
	var draw_count := 0
	var component_draw_count := 0

	func _draw() -> void:
		draw_count += 1
		overlay._draw_neon_line(self, Vector2(8.0, 8.0), Vector2(160.0, 8.0), Overlay.NEON_CYAN, 1.5)
		overlay._draw_panel(self, Rect2(8.0, 18.0, 56.0, 24.0), Overlay.PANEL_COLOR, Overlay.PANEL_BORDER, 2.0)
		overlay._draw_panel(self, Rect2(72.0, 18.0, 56.0, 24.0), Overlay.PANEL_COLOR, Overlay.PANEL_BORDER, 2.0, true, true)
		overlay._draw_tab(self, Overlay.FONT_BODY, Rect2(8.0, 50.0, 58.0, 28.0), "탭", true)
		overlay._draw_tab(self, Overlay.FONT_BODY, Rect2(72.0, 50.0, 58.0, 28.0), "탭", false)
		overlay._draw_button(self, Overlay.FONT_BODY, Rect2(8.0, 84.0, 96.0, 30.0), "선택", true, Vector2(-99.0, -99.0))
		overlay._draw_toggle_setting_row(
			self,
			Overlay.FONT_BODY,
			Rect2(8.0, 120.0, 156.0, 40.0),
			Rect2(138.0, 130.0, 16.0, 16.0),
			"토글",
			"네온",
			true,
			false,
			Vector2(-99.0, -99.0)
		)
		component_draw_count += 1


func _init() -> void:
	get_root().size = Vector2i(180, 180)
	_probe = NeonSkinProbe.new()
	_probe.name = "SettingsUiNeonSkinProbe"
	get_root().add_child(_probe)
	_probe.queue_redraw()


func _process(_delta: float) -> bool:
	_frame_count += 1
	if _frame_count < 3:
		return false
	_verify_contract()

	if _failures.is_empty():
		print("settings_ui_neon_skin_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
	return true


func _verify_contract() -> void:
	var overlay: Object = Overlay.new()
	_expect(Overlay.FONT_BODY != null, "settings UI body font should preload")
	_expect(Overlay.FONT_TECH != null, "settings UI tech font should preload")
	_expect(overlay._get_ui_font() == Overlay.FONT_BODY, "default settings UI font should be NanumSquareB")
	_expect(overlay._get_ui_font(true) == Overlay.FONT_TECH, "tech settings UI font should be NeoDunggeunmoPro")
	_expect(_color_equal(Overlay.PANEL_COLOR, Color(0.04, 0.06, 0.10, 0.92)), "settings UI panel color should stay on the Lingpia navy token")
	_expect(_color_equal(Overlay.PANEL_BORDER, Color(0.36, 0.78, 0.98, 0.90)), "settings UI panel border should stay on the Lingpia cyan token")
	_expect(_color_equal(Overlay.SECTION_COLOR, Color(0.02, 0.04, 0.08, 0.55)), "settings UI section color should keep the slice-1 readability alpha")
	_expect(_color_equal(Overlay.NEON_CYAN, Color(0.36, 0.78, 0.98)), "settings UI neon cyan token should stay stable")
	_expect(_probe != null and _probe.draw_count > 0, "settings UI neon line probe should draw through a live _draw callback")
	_expect(_probe != null and _probe.component_draw_count > 0, "settings UI neon component probe should draw through a live _draw callback")


func _color_equal(actual: Color, expected: Color) -> bool:
	return (
		is_equal_approx(actual.r, expected.r)
		and is_equal_approx(actual.g, expected.g)
		and is_equal_approx(actual.b, expected.b)
		and is_equal_approx(actual.a, expected.a)
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
