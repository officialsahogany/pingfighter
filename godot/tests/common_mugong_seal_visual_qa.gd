extends SceneTree

const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")

const VIEW_SIZE := Vector2i(860, 455)
const CAPTURE_PATH := "res://.tmp/common_mugong_seal_qa.png"
const SPECS := [
	{"id": "common_bulk_up", "name": "철산공", "accent": Color(0.73, 0.30, 0.18)},
	{"id": "common_swiftness", "name": "유운보", "accent": Color(0.28, 0.55, 0.52)},
	{"id": "common_expansion", "name": "광맥결", "accent": Color(0.48, 0.30, 0.67)},
	{"id": "perk_boost_charge", "name": "축기결", "accent": Color(0.25, 0.48, 0.70)},
	{"id": "perk_laurel_shield", "name": "오엽호신", "accent": Color(0.35, 0.55, 0.30)},
]


class IconProbe:
	extends Node2D

	var renderer: Object = null
	var draw_results: Array[bool] = []

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color(0.026, 0.020, 0.015), true)
		draw_results.clear()
		var font := ThemeDB.fallback_font
		for index in SPECS.size():
			var spec: Dictionary = SPECS[index]
			var column := index % 3
			var row := index / 3
			var left := 28.0 + float(column) * 280.0
			var top := 58.0 + float(row) * 215.0
			var acquisition_rect := Rect2(Vector2(left, top), Vector2(96.0, 96.0))
			var owned_rect := Rect2(Vector2(left + 150.0, top + 31.0), Vector2(32.0, 32.0))
			_draw_slot(acquisition_rect, spec.get("accent", Color.WHITE), false)
			_draw_slot(owned_rect, spec.get("accent", Color.WHITE), true)
			draw_results.append(renderer.draw_icon(self, str(spec.get("id", "")), acquisition_rect.grow(-8.0), 1.0, true))
			draw_results.append(renderer.draw_icon(self, str(spec.get("id", "")), owned_rect, 1.0, true))
			if font != null:
				draw_string(font, Vector2(left, top - 23.0), str(spec.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, 120.0, 23, Color(0.94, 0.84, 0.63))
				draw_string(font, Vector2(left, top + 123.0), "획득 카드 80px", HORIZONTAL_ALIGNMENT_LEFT, 125.0, 14, Color(0.72, 0.68, 0.59))
				draw_string(font, Vector2(left + 133.0, top + 87.0), "보유 Lv.5", HORIZONTAL_ALIGNMENT_LEFT, 95.0, 13, Color(0.95, 0.79, 0.30))

	func _draw_slot(rect: Rect2, accent: Color, small: bool) -> void:
		var radius := rect.size.x * 0.5
		draw_circle(rect.get_center(), radius, Color(0.12, 0.085, 0.045, 0.96))
		draw_arc(rect.get_center(), radius, 0.0, TAU, 64, Color(accent.r, accent.g, accent.b, 0.90), 1.5 if small else 2.4, true)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_dir := ProjectSettings.globalize_path("res://.tmp")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var renderer := RuntimePerkIconRenderer.new()
	for spec: Dictionary in SPECS:
		if not renderer.has_icon(str(spec.get("id", ""))):
			push_error("Common Mugong seal should resolve before visual QA: %s" % str(spec.get("id", "")))
			quit(1)
			return
	var probe := IconProbe.new()
	probe.renderer = renderer
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	get_root().add_child(viewport)
	viewport.add_child(probe)
	probe.queue_redraw()
	for _frame_index in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	if probe.draw_results.size() != SPECS.size() * 2 or probe.draw_results.has(false):
		push_error("All common Mugong seals should draw at acquisition and owned sizes")
		quit(1)
		return
	var image: Image = viewport.get_texture().get_image()
	if image.save_png(CAPTURE_PATH) != OK:
		push_error("Failed to save common Mugong visual QA capture")
		quit(1)
		return
	probe.queue_free()
	viewport.queue_free()
	await process_frame
	print("common_mugong_seal_visual_qa: ok")
	print(ProjectSettings.globalize_path(CAPTURE_PATH))
	quit(0)
