extends SceneTree

const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")

const VIEW_SIZE := Vector2i(1140, 790)
const CAPTURE_PATH := "res://.tmp/peerless_mugong_seal_qa.png"
const SPECS := [
	{"id": "megingjord", "name": "삼재개문", "accent": Color(0.80, 0.59, 0.22)},
	{"id": "transcendent_crown", "name": "만법귀일", "accent": Color(0.82, 0.64, 0.26)},
	{"id": "ragnarok_hammer", "name": "천뢰진경", "accent": Color(0.25, 0.56, 0.82)},
	{"id": "hermes_shoes", "name": "축지신행", "accent": Color(0.28, 0.58, 0.57)},
	{"id": "poseidon_trident", "name": "쌍룡회류", "accent": Color(0.18, 0.50, 0.60)},
	{"id": "sacred_laurel", "name": "팔엽금강", "accent": Color(0.34, 0.59, 0.36)},
	{"id": "heavenly_cape", "name": "천문개결", "accent": Color(0.48, 0.67, 0.76)},
	{"id": "horn_strawberry_mask", "name": "혼딸기강신", "accent": Color(0.72, 0.23, 0.26)},
	{"id": "odins_eye", "name": "윤회천안", "accent": Color(0.38, 0.29, 0.63)},
	{"id": "celestial_armor", "name": "부동금강체", "accent": Color(0.47, 0.58, 0.67)},
	{"id": "baal_boots", "name": "풍우식기결", "accent": Color(0.35, 0.53, 0.51)},
	{"id": "pandora_legacy", "name": "금기개함", "accent": Color(0.48, 0.24, 0.56)},
	{"id": "angel_blessing", "name": "천운삼괘", "accent": Color(0.78, 0.62, 0.27)},
	{"id": "yangui_hoechun", "name": "양의회천", "accent": Color(0.92, 0.70, 0.18)},
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
			var column := index % 4
			var row := index / 4
			var left := 28.0 + float(column) * 280.0
			var top := 48.0 + float(row) * 185.0
			var acquisition_rect := Rect2(Vector2(left, top), Vector2(88.0, 88.0))
			var owned_rect := Rect2(Vector2(left + 148.0, top + 27.0), Vector2(32.0, 32.0))
			_draw_slot(acquisition_rect, spec.get("accent", Color.WHITE), false)
			_draw_slot(owned_rect, spec.get("accent", Color.WHITE), true)
			draw_results.append(renderer.draw_icon(self, str(spec.get("id", "")), acquisition_rect.grow(-4.0), 1.0, true))
			draw_results.append(renderer.draw_icon(self, str(spec.get("id", "")), owned_rect, 1.0, true))
			if font != null:
				draw_string(font, Vector2(left, top - 15.0), str(spec.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, 150.0, 21, Color(0.95, 0.84, 0.61))
				draw_string(font, Vector2(left, top + 112.0), "절세 획득 80px", HORIZONTAL_ALIGNMENT_LEFT, 130.0, 13, Color(0.72, 0.68, 0.59))
				draw_string(font, Vector2(left + 130.0, top + 78.0), "보유", HORIZONTAL_ALIGNMENT_LEFT, 65.0, 13, Color(0.95, 0.79, 0.30))

	func _draw_slot(rect: Rect2, accent: Color, small: bool) -> void:
		var radius := rect.size.x * 0.5
		draw_circle(rect.get_center(), radius, Color(0.11, 0.074, 0.038, 0.97))
		draw_arc(rect.get_center(), radius, 0.0, TAU, 64, Color(0.76, 0.55, 0.18, 0.95), 2.1 if small else 3.1, true)
		draw_arc(rect.get_center(), radius - (2.5 if small else 5.0), 0.0, TAU, 64, Color(accent.r, accent.g, accent.b, 0.88), 1.0 if small else 1.8, true)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.tmp"))
	var renderer := RuntimePerkIconRenderer.new()
	for spec: Dictionary in SPECS:
		var perk_id := str(spec.get("id", ""))
		if not renderer.has_icon(perk_id) or not renderer.has_animated_icon(perk_id):
			push_error("Peerless Mugong seal and sheet should resolve before visual QA: %s" % perk_id)
			quit(1)
			return
	# RenderingServer.frame_post_draw is not emitted by the headless display
	# server for this SubViewport capture. Keep the asset/renderer contract
	# checks above in headless smoke runs; the real pixel capture runs windowed.
	if DisplayServer.get_name().to_lower().find("headless") >= 0:
		print("peerless_mugong_seal_visual_qa: capture skipped under headless display server")
		print("peerless_mugong_seal_visual_qa: ok")
		quit(0)
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
		push_error("All peerless Mugong seals should draw at acquisition and owned sizes")
		quit(1)
		return
	var image: Image = viewport.get_texture().get_image()
	if image.save_png(CAPTURE_PATH) != OK:
		push_error("Failed to save peerless Mugong visual QA capture")
		quit(1)
		return
	probe.queue_free()
	viewport.queue_free()
	await process_frame
	print("peerless_mugong_seal_visual_qa: ok")
	print(ProjectSettings.globalize_path(CAPTURE_PATH))
	quit(0)
