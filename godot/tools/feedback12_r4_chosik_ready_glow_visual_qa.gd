extends SceneTree

const SmasherSkillOrbSlotRenderer := preload(
	"res://scripts/hud/smasher_skill_orb_slot_renderer.gd"
)

const VIEW_SIZE := Vector2i(2020, 1246)
const SLOT_CENTER := Vector2(1010.0, 623.0)
const ICON_RADIUS := 66.0
const GLOW_COMPARE_RADIUS_MIN := 67.0
const GLOW_COMPARE_RADIUS_MAX := 84.0
const GLOW_LUMINANCE_DELTA := 0.006


class CaptureCanvas:
	extends Node2D

	var slot_ready := false
	var renderer: Object = SmasherSkillOrbSlotRenderer.new()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color(0.035, 0.045, 0.065), true)
		for y in range(0, VIEW_SIZE.y, 36):
			draw_rect(
				Rect2(0.0, float(y), float(VIEW_SIZE.x), 18.0),
				Color(0.10, 0.14, 0.19, 0.11),
				true
			)
		draw_circle(SLOT_CENTER, 118.0, Color(0.08, 0.10, 0.14, 0.96))
		var positions: Array[Vector2] = [SLOT_CENTER]
		renderer.draw(
			self,
			SLOT_CENTER,
			ICON_RADIUS,
			positions,
			1.37,
			2.2,
			{
				"equipped_skills": ["feedback12_r4_ready_probe"],
				"special_gauge": 100.0,
				"skill_costs": {"feedback12_r4_ready_probe": 20.0},
				"skill_colors": {"feedback12_r4_ready_probe": Color(0.27, 0.84, 0.66)},
				"cooldown_seconds": {"feedback12_r4_ready_probe": 0.0},
				"skill_ready_overrides": {"feedback12_r4_ready_probe": slot_ready},
				"skill_cooldown_remaining_ratios": {"feedback12_r4_ready_probe": 0.0},
				"pillar_hud_static_lod": false,
				"socket_overlap": 1.0,
			}
		)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("feedback12 R4 visual QA requires a windowed Vulkan renderer")
		quit(1)
		return
	if RenderingServer.get_current_rendering_method() != "mobile":
		push_error("feedback12 R4 visual QA requires the mobile rendering method")
		quit(1)
		return
	var output_dir := ProjectSettings.globalize_path(
		"res://.godot/codex_artifacts/feedback12_r4_chosik_ready_glow"
	)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="):
			output_dir = argument.substr("--output-dir=".length())
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		push_error("failed to create feedback12 R4 capture directory: %s" % output_dir)
		quit(1)
		return

	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var unavailable := await _capture_case(viewport, false)
	var ready := await _capture_case(viewport, true)
	if unavailable == null or ready == null:
		viewport.queue_free()
		quit(1)
		return
	var unavailable_path := output_dir.path_join("feedback12_r4_unavailable_2020x1246.png")
	var ready_path := output_dir.path_join("feedback12_r4_ready_2020x1246.png")
	if unavailable.save_png(unavailable_path) != OK or ready.save_png(ready_path) != OK:
		push_error("failed to save feedback12 R4 captures")
		viewport.queue_free()
		quit(1)
		return
	var glow_pixels := _count_ready_glow_pixels(unavailable, ready)
	if glow_pixels < 180:
		push_error("ready glow contrast was too weak in the outer fill band: %d pixels" % glow_pixels)
		viewport.queue_free()
		quit(1)
		return
	print("feedback12_r4_chosik_ready_glow_visual_qa: outer_glow_pixels=%d" % glow_pixels)
	print("feedback12_r4_chosik_ready_glow_visual_qa: captures=2")
	print("feedback12_r4_chosik_ready_glow_visual_qa: output_dir=%s" % output_dir)
	print("feedback12_r4_chosik_ready_glow_visual_qa: ok")
	viewport.queue_free()
	quit(0)


func _capture_case(viewport: SubViewport, ready: bool) -> Image:
	var canvas := CaptureCanvas.new()
	canvas.slot_ready = ready
	viewport.add_child(canvas)
	canvas.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.remove_child(canvas)
	canvas.queue_free()
	await process_frame
	return image


func _count_ready_glow_pixels(unavailable: Image, ready: Image) -> int:
	var count := 0
	var min_x := int(SLOT_CENTER.x - GLOW_COMPARE_RADIUS_MAX)
	var max_x := int(SLOT_CENTER.x + GLOW_COMPARE_RADIUS_MAX)
	var min_y := int(SLOT_CENTER.y - GLOW_COMPARE_RADIUS_MAX)
	var max_y := int(SLOT_CENTER.y + GLOW_COMPARE_RADIUS_MAX)
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var distance := Vector2(float(x), float(y)).distance_to(SLOT_CENTER)
			if distance < GLOW_COMPARE_RADIUS_MIN or distance > GLOW_COMPARE_RADIUS_MAX:
				continue
			if (
				ready.get_pixel(x, y).get_luminance()
				- unavailable.get_pixel(x, y).get_luminance()
				>= GLOW_LUMINANCE_DELTA
			):
				count += 1
	return count
