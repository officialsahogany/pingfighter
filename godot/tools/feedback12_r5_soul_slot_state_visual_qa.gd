extends SceneTree

const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")
const SmasherSkillOrbSlotRenderer := preload(
	"res://scripts/hud/smasher_skill_orb_slot_renderer.gd"
)

const VIEW_SIZE := Vector2i(2020, 1246)
const SLOT_CENTER := Vector2(1010.0, 623.0)
const ICON_RADIUS := 66.0
const SOUL_ID := CommonSkillCatalog.SOUL_SUMMON_ART_ID
const FILL_ONLY_STYLE := "filled_recovery"


class CaptureCanvas:
	extends Node2D

	var slot_ready := false
	var cooldown_ratio := 0.0
	var sample_time := 0.0
	var renderer: Object = SmasherSkillOrbSlotRenderer.new()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color(0.025, 0.036, 0.057), true)
		for y in range(0, VIEW_SIZE.y, 36):
			draw_rect(
				Rect2(0.0, float(y), float(VIEW_SIZE.x), 18.0),
				Color(0.08, 0.13, 0.18, 0.10),
				true
			)
		draw_circle(SLOT_CENTER, 118.0, Color(0.055, 0.075, 0.105, 0.97))
		var positions: Array[Vector2] = [SLOT_CENTER]
		renderer.draw(
			self,
			SLOT_CENTER,
			ICON_RADIUS,
			positions,
			sample_time,
			2.2,
			{
				"equipped_skills": [SOUL_ID],
				"special_gauge": 100.0,
				"skill_costs": {SOUL_ID: 0.0},
				"skill_colors": {SOUL_ID: CommonSkillCatalog.SOUL_SUMMON_ART_COLOR},
				"cooldown_seconds": {SOUL_ID: 0.0},
				"skill_ready_overrides": {SOUL_ID: slot_ready},
				"skill_cooldown_remaining_ratios": {SOUL_ID: cooldown_ratio},
				"skill_cooldown_visual_styles": {SOUL_ID: FILL_ONLY_STYLE},
				"pillar_hud_static_lod": false,
				"socket_overlap": 1.0,
			}
		)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("feedback12 R5 visual QA requires a windowed Vulkan renderer")
		quit(1)
		return
	if RenderingServer.get_current_rendering_method() != "mobile":
		push_error("feedback12 R5 visual QA requires the mobile rendering method")
		quit(1)
		return
	var output_dir := ProjectSettings.globalize_path(
		"res://.godot/codex_artifacts/feedback12_r5_soul_slot_state"
	)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="):
			output_dir = argument.substr("--output-dir=".length())
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		push_error("failed to create feedback12 R5 capture directory: %s" % output_dir)
		quit(1)
		return

	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var blocked := await _capture_case(viewport, false, 0.000033, 0.25)
	var ready := await _capture_case(viewport, true, 0.0, 1.37)
	var ctrl_cooling := await _capture_case(viewport, false, 0.72, 0.83)
	if blocked == null or ready == null or ctrl_cooling == null:
		viewport.queue_free()
		quit(1)
		return
	var blocked_path := output_dir.path_join("feedback12_r5_blocked_29_999_2020x1246.png")
	var ready_path := output_dir.path_join("feedback12_r5_ready_30_000_2020x1246.png")
	var cooling_path := output_dir.path_join("feedback12_r5_ctrl_cooling_2020x1246.png")
	if (
		blocked.save_png(blocked_path) != OK
		or ready.save_png(ready_path) != OK
		or ctrl_cooling.save_png(cooling_path) != OK
	):
		push_error("failed to save feedback12 R5 captures")
		viewport.queue_free()
		quit(1)
		return
	var ready_contrast_pixels := _count_luminance_advantage(blocked, ready, 52.0, 0.08)
	var cooling_delta_pixels := _count_color_delta(blocked, ctrl_cooling, 67.0, 0.045)
	if ready_contrast_pixels < 850:
		push_error("30-percent ready contrast was too weak: %d pixels" % ready_contrast_pixels)
		viewport.queue_free()
		quit(1)
		return
	if cooling_delta_pixels < 260:
		push_error("Ctrl filled-recovery state was not visually distinct: %d pixels" % cooling_delta_pixels)
		viewport.queue_free()
		quit(1)
		return
	print("feedback12_r5_soul_slot_state_visual_qa: ready_contrast_pixels=%d" % ready_contrast_pixels)
	print("feedback12_r5_soul_slot_state_visual_qa: cooling_delta_pixels=%d" % cooling_delta_pixels)
	print("feedback12_r5_soul_slot_state_visual_qa: captures=3")
	print("feedback12_r5_soul_slot_state_visual_qa: output_dir=%s" % output_dir)
	print("feedback12_r5_soul_slot_state_visual_qa: ok")
	viewport.queue_free()
	quit(0)


func _capture_case(
	viewport: SubViewport,
	ready: bool,
	cooldown_ratio: float,
	sample_time: float
) -> Image:
	var canvas := CaptureCanvas.new()
	canvas.slot_ready = ready
	canvas.cooldown_ratio = cooldown_ratio
	canvas.sample_time = sample_time
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


func _count_luminance_advantage(darker: Image, brighter: Image, radius: float, delta: float) -> int:
	var count := 0
	for y in range(int(SLOT_CENTER.y - radius), int(SLOT_CENTER.y + radius) + 1):
		for x in range(int(SLOT_CENTER.x - radius), int(SLOT_CENTER.x + radius) + 1):
			if Vector2(float(x), float(y)).distance_to(SLOT_CENTER) > radius:
				continue
			if brighter.get_pixel(x, y).get_luminance() - darker.get_pixel(x, y).get_luminance() >= delta:
				count += 1
	return count


func _count_color_delta(first: Image, second: Image, radius: float, delta: float) -> int:
	var count := 0
	for y in range(int(SLOT_CENTER.y - radius), int(SLOT_CENTER.y + radius) + 1):
		for x in range(int(SLOT_CENTER.x - radius), int(SLOT_CENTER.x + radius) + 1):
			if Vector2(float(x), float(y)).distance_to(SLOT_CENTER) > radius:
				continue
			var first_color := first.get_pixel(x, y)
			var second_color := second.get_pixel(x, y)
			var rgb_delta := (
				absf(first_color.r - second_color.r)
				+ absf(first_color.g - second_color.g)
				+ absf(first_color.b - second_color.b)
			)
			if rgb_delta >= delta:
				count += 1
	return count
