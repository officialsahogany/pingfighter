extends SceneTree

const RuntimePerkDebugPicker := preload("res://scripts/hud/runtime_perk_debug_picker.gd")

const VIEW_SIZE := Vector2(900.0, 720.0)
const CAPTURE_PATH := "res://../.tmp/runtime_perk_debug_picker_tooltip.png"


class TooltipProbe:
	extends Control

	var picker: Object = null
	var entry: Dictionary = {}
	var all_entries: Array = []
	var panel_rect := Rect2()
	var card_rect := Rect2()
	var view_size := Vector2.ZERO
	var show_tooltip := false

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.010, 0.014, 0.022, 1.0))
		draw_rect(panel_rect, Color(0.035, 0.045, 0.070, 1.0))
		draw_rect(panel_rect, Color(0.30, 0.78, 1.0, 0.90), false, 2.0)
		picker._draw_tabs(self, ThemeDB.fallback_font, panel_rect, all_entries, Vector2(-9999.0, -9999.0))
		picker._draw_card(self, ThemeDB.fallback_font, card_rect, entry, true, {}, null)
		if show_tooltip:
			picker._draw_hover_tooltip(self, ThemeDB.fallback_font, entry, 1, card_rect, view_size)


var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		print("runtime_perk_debug_picker_tooltip_render_smoke: capture skipped under headless display server")
		print("runtime_perk_debug_picker_tooltip_render_smoke: ok")
		quit(0)
		return

	var picker := RuntimePerkDebugPicker.new()
	picker.target_level = 1
	var entry := {
		"id": "unlock_dalji_vision_chain_top",
		"name": "달지 비전 · 연환팽이 비급",
		"max_level": 1,
		"unlocks_skill": "dalji_vision_chain_top",
		"vision_chosik": true,
		"debug_group": "vision",
		"icon_color": Color(0.46, 0.91, 0.86),
		"detail": "달지의 비전초식 연환팽이를 습득합니다.",
		"descriptions": {1: "공용 비전초식 비급"},
	}
	var all_entries: Array = [
		{"id": "unlock_smasher_wheel", "unlocks_skill": "smasher_wheel", "character_restriction": "smasher"},
		{"id": "soldier_unlock_net_gun", "unlocks_skill": "net_gun", "character_restriction": "soldier"},
		{"id": "unlock_wall_leap_raid", "unlocks_skill": "wall_leap_raid", "character_restriction": "viper"},
		entry,
		{"id": "common_swiftness", "debug_group": "common"},
		{"id": "odins_eye", "rarity": "mythic", "debug_group": "converted_mythic"},
	]
	picker.selected_tab_index = 3
	var panel_rect: Rect2 = picker._get_panel_rect(VIEW_SIZE, 1)
	var card_layout: Dictionary = picker._build_grid_layout(panel_rect, 1)
	var card_rect: Rect2 = picker._get_card_rect(0, panel_rect, card_layout)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(int(VIEW_SIZE.x), int(VIEW_SIZE.y))
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var probe := TooltipProbe.new()
	probe.size = VIEW_SIZE
	probe.picker = picker
	probe.entry = entry
	probe.all_entries = all_entries
	probe.panel_rect = panel_rect
	probe.card_rect = card_rect
	probe.view_size = VIEW_SIZE
	viewport.add_child(probe)

	var without_tooltip: Image = await _capture(viewport, probe)
	probe.show_tooltip = true
	var with_tooltip: Image = await _capture(viewport, probe)
	if without_tooltip == null or with_tooltip == null:
		_failures.append("tooltip render capture should produce non-empty images")
	else:
		var selected_tab_rect: Rect2 = picker._get_tab_rect(3, panel_rect)
		var inactive_tab_rect: Rect2 = picker._get_tab_rect(0, panel_rect)
		var selected_fill: Color = without_tooltip.get_pixel(int(selected_tab_rect.position.x + 7.0), int(selected_tab_rect.position.y + 7.0))
		var inactive_fill: Color = without_tooltip.get_pixel(int(inactive_tab_rect.position.x + 7.0), int(inactive_tab_rect.position.y + 7.0))
		_expect(selected_fill.b > inactive_fill.b + 0.08, "selected 비전초식 tab should render with a distinct blue fill")
		var content: Dictionary = picker._build_hover_tooltip_content(entry, 1)
		var layout: Dictionary = picker._get_hover_tooltip_layout(ThemeDB.fallback_font, content, VIEW_SIZE)
		var tooltip_rect: Rect2 = picker._get_hover_tooltip_rect(card_rect, layout.get("size", Vector2.ZERO), VIEW_SIZE)
		var changed_pixels := _count_changed_pixels(without_tooltip, with_tooltip, tooltip_rect)
		_expect(changed_pixels > 1200, "hover should render a substantial tooltip panel, got %d changed pixels" % changed_pixels)
		var output_path := ProjectSettings.globalize_path(CAPTURE_PATH)
		DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
		if with_tooltip.save_png(output_path) == OK:
			print("runtime_perk_debug_picker_tooltip_render_smoke: evidence %s" % output_path)

	probe.queue_free()
	viewport.queue_free()
	if _failures.is_empty():
		print("runtime_perk_debug_picker_tooltip_render_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _capture(viewport: SubViewport, probe: TooltipProbe) -> Image:
	probe.queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var texture: ViewportTexture = viewport.get_texture()
	if texture == null:
		return null
	var image: Image = texture.get_image()
	return null if image == null or image.is_empty() else image


func _count_changed_pixels(before: Image, after: Image, region: Rect2) -> int:
	var start_x := maxi(0, int(floor(region.position.x)))
	var start_y := maxi(0, int(floor(region.position.y)))
	var end_x := mini(after.get_width(), int(ceil(region.end.x)))
	var end_y := mini(after.get_height(), int(ceil(region.end.y)))
	var changed := 0
	for y in range(start_y, end_y):
		for x in range(start_x, end_x):
			var before_color: Color = before.get_pixel(x, y)
			var after_color: Color = after.get_pixel(x, y)
			if absf(before_color.r - after_color.r) + absf(before_color.g - after_color.g) + absf(before_color.b - after_color.b) > 0.08:
				changed += 1
	return changed


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
