extends SceneTree

const StatusEffectOverlayRenderer := preload("res://scripts/status/status_effect_overlay_renderer.gd")

const VIEW_SIZE := Vector2i(760, 300)
const CAPTURE_PATH := "res://.tmp/perk_fusion_static_field_visual_qa.png"


class StaticFieldProbe:
	extends Node2D

	var static_field_active := false
	var overlay: Object = null

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color(0.015, 0.022, 0.052), true)
		for line_index in range(8):
			var y := 30.0 + float(line_index) * 34.0
			draw_line(Vector2(0.0, y), Vector2(float(VIEW_SIZE.x), y), Color(0.08, 0.12, 0.24, 0.35), 1.0)
		var boss_pos := Vector2(330.0, 70.0)
		var boss_size := Vector2(100.0, 40.0)
		draw_circle(boss_pos + Vector2(50.0, 14.0), 34.0, Color(0.16, 0.10, 0.30, 0.96))
		draw_rect(Rect2(boss_pos, boss_size), Color(0.64, 0.30, 0.80, 1.0), true)
		draw_rect(Rect2(boss_pos, boss_size), Color(0.94, 0.70, 1.0, 0.96), false, 2.0)
		var context := {
			"active_item_boss_spider_slow_active": true,
			"active_item_boss_spider_slow_ratio": 0.72,
			"status_boss_slow_ratio": 0.72,
			"perk_fusion_static_field_active": static_field_active,
			"perk_fusion_static_field_ratio": 0.72,
			"perk_fusion_static_field_remaining_sec": 3.6,
			"perk_fusion_static_field_multiplier": 0.70,
			"boss_max_health": 100,
			"boss_current_health": 72,
		}
		overlay.draw_boss_status_overlays(
			self,
			context,
			boss_pos,
			boss_size,
			40.0,
			Vector2.ZERO
		)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.tmp"))
	if DisplayServer.get_name().to_lower().contains("headless"):
		print("perk_fusion_static_field_visual_qa: capture skipped under headless display server")
		print("perk_fusion_static_field_visual_qa: ok")
		quit(0)
		return

	var overlay := StatusEffectOverlayRenderer.new()
	var baseline_probe := StaticFieldProbe.new()
	baseline_probe.overlay = overlay
	var baseline_viewport := _build_viewport(baseline_probe)

	var active_probe := StaticFieldProbe.new()
	active_probe.overlay = overlay
	active_probe.static_field_active = true
	var active_viewport := _build_viewport(active_probe)

	baseline_probe.queue_redraw()
	active_probe.queue_redraw()
	for _frame_index in range(5):
		await process_frame
	await RenderingServer.frame_post_draw

	var baseline_image := baseline_viewport.get_texture().get_image()
	var active_image := active_viewport.get_texture().get_image()
	if baseline_image == null or active_image == null or baseline_image.is_empty() or active_image.is_empty():
		_fail("static-field visual QA viewports should produce non-empty images")
		return
	var changed_pixels := _count_changed_pixels(baseline_image, active_image)
	if changed_pixels < 900:
		_fail("static field should add a clearly readable electric field and badge (%d changed pixels)" % changed_pixels)
		return
	var badge_ink := _count_bright_pixels(active_image, Rect2i(270, 105, 220, 54))
	if badge_ink < 120:
		_fail("static-field activation badge should remain legible below the boss (%d bright pixels)" % badge_ink)
		return
	if active_image.save_png(CAPTURE_PATH) != OK:
		_fail("failed to save static-field visual QA capture")
		return

	baseline_probe.queue_free()
	baseline_viewport.queue_free()
	active_probe.queue_free()
	active_viewport.queue_free()
	await process_frame
	print("perk_fusion_static_field_visual_qa: ok")
	print(ProjectSettings.globalize_path(CAPTURE_PATH))
	quit(0)


func _build_viewport(probe: Node2D) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	get_root().add_child(viewport)
	viewport.add_child(probe)
	return viewport


func _count_changed_pixels(first: Image, second: Image) -> int:
	var changed := 0
	for y in range(VIEW_SIZE.y):
		for x in range(VIEW_SIZE.x):
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			if (
				absf(a.r - b.r)
				+ absf(a.g - b.g)
				+ absf(a.b - b.b)
				+ absf(a.a - b.a)
			) > 0.12:
				changed += 1
	return changed


func _count_bright_pixels(image: Image, roi: Rect2i) -> int:
	var bright := 0
	var clipped := roi.intersection(Rect2i(Vector2i.ZERO, VIEW_SIZE))
	for y in range(clipped.position.y, clipped.end.y):
		for x in range(clipped.position.x, clipped.end.x):
			var pixel := image.get_pixel(x, y)
			if pixel.a > 0.7 and pixel.b > 0.58 and pixel.g > 0.42:
				bright += 1
	return bright


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
