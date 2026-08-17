extends SceneTree

const YanguiHoechunFieldRenderer := preload("res://scripts/items/mythic_item_yangui_hoechun_field_renderer.gd")

const VIEW_SIZE := Vector2i(760, 750)
const CAPTURE_PATH := "res://.tmp/yangui_hoechun_visual_qa.png"


class EffectProbe:
	extends Node2D

	var renderer: Object = YanguiHoechunFieldRenderer.new()
	var draw_calls := 0

	func _draw() -> void:
		draw_calls += 1
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color(0.018, 0.026, 0.047), true)
		for x in range(40, VIEW_SIZE.x, 40):
			draw_line(Vector2(float(x), 0.0), Vector2(float(x), float(VIEW_SIZE.y)), Color(0.20, 0.27, 0.36, 0.12), 1.0)
		for y in range(30, VIEW_SIZE.y, 40):
			draw_line(Vector2(0.0, float(y)), Vector2(float(VIEW_SIZE.x), float(y)), Color(0.20, 0.27, 0.36, 0.10), 1.0)
		var player_rect := Rect2(Vector2(302.5, 690.0), Vector2(155.0, 50.0))
		draw_rect(player_rect.grow(5.0), Color(1.0, 0.72, 0.12, 0.18), true)
		draw_rect(player_rect, Color(0.12, 0.16, 0.23, 1.0), true)
		draw_rect(player_rect, Color(1.0, 0.82, 0.30, 0.92), false, 3.0)
		renderer.draw_effect(self, Vector2.ZERO, {
			"visible": true,
			"wave_active": true,
			"origin": Vector2(380.0, 715.0),
			"left_front_x": 185.0,
			"right_front_x": 575.0,
			"progress": 0.56,
			"alpha": 0.96,
			"phase": 1.35,
			"half_height": 92.0,
			"hit_flash_ratio": 0.72,
			"hit_position": Vector2(185.0, 655.0),
		})
		draw_circle(Vector2(185.0, 655.0), 14.3, Color(0.98, 0.99, 1.0, 1.0))
		draw_circle(Vector2(181.0, 650.0), 4.0, Color(1.0, 0.90, 0.36, 0.88))


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.tmp"))
	if DisplayServer.get_name().to_lower().contains("headless"):
		print("yangui_hoechun_visual_qa: capture skipped under headless display server")
		print("yangui_hoechun_visual_qa: ok")
		quit(0)
		return
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	var probe := EffectProbe.new()
	viewport.add_child(probe)
	probe.queue_redraw()
	for _frame_index in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	if probe.draw_calls <= 0:
		push_error("양의회천 visual QA probe did not draw")
		quit(1)
		return
	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(CAPTURE_PATH) != OK:
		push_error("양의회천 visual QA capture failed")
		quit(1)
		return
	print("yangui_hoechun_visual_qa: ok")
	print(ProjectSettings.globalize_path(CAPTURE_PATH))
	quit(0)
