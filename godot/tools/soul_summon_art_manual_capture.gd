extends SceneTree

const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const OUT_PATH := "D:/tmp/bosspong_guardian_transition_qa/soul_summon_art_manual.png"
const VIEW_SIZE := Vector2i(520, 270)


class CaptureCanvas:
	extends Node2D

	var icon_renderer: Object

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color(0.025, 0.055, 0.075), true)
		draw_string(ThemeDB.fallback_font, Vector2(62.0, 48.0), "COMMON CHOSIK MANUAL", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Color(0.78, 0.96, 0.88))
		var manual_card := Rect2(60.0, 72.0, 160.0, 160.0)
		var orb_card := Rect2(300.0, 72.0, 160.0, 160.0)
		_draw_card(manual_card, Color(0.20, 0.78, 0.62), "MANUAL")
		_draw_card(orb_card, Color(0.36, 0.82, 0.94), "BATTLE ORB")
		icon_renderer.draw_icon(self, "unlock_soul_summon_art", manual_card.grow(-28.0), 1.0, true)
		icon_renderer.draw_icon(self, "soul_summon_art", orb_card.grow(-28.0), 1.0, true)

	func _draw_card(rect: Rect2, accent: Color, label: String) -> void:
		draw_rect(rect, Color(0.04, 0.10, 0.13, 0.96), true)
		draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.72), false, 2.0)
		draw_string(ThemeDB.fallback_font, Vector2(rect.position.x + 28.0, rect.end.y - 10.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, accent)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("soul_summon_art_manual_capture requires a windowed renderer")
		quit(1)
		return
	if RenderingServer.get_current_rendering_method() != "mobile":
		push_error("Vulkan mobile renderer required")
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(OUT_PATH.get_base_dir()) != OK:
		push_error("failed to create capture directory")
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas := CaptureCanvas.new()
	canvas.icon_renderer = RuntimePerkIconRenderer.new()
	viewport.add_child(canvas)
	canvas.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(OUT_PATH) != OK:
		push_error("failed to save capture")
		quit(1)
		return
	print("[SoulSummonManualCapture] %s" % OUT_PATH)
	quit(0)
