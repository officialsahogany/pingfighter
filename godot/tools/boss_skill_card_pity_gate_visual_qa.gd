extends SceneTree

const BossSkillCardHudSpec := preload("res://scripts/stages/common/boss_skill_card_hud_spec.gd")
const Stage3BossSkillHudRenderer := preload("res://scripts/stages/stage3/stage3_boss_skill_hud_renderer.gd")
const Stage3BossVariantSkillState := preload("res://scripts/stages/stage3/stage3_boss_variant_skill_state.gd")

const VIEW_SIZE := Vector2i(2020, 1246)
const LOGICAL_GAME_SIZE := Vector2(760.0, 750.0)
const CAPTURE_COUNT := 6
const OUTPUT_SCALE := 2
const STRIP_GAP_PX := 8
const OUTPUT_DIR := "res://.godot/codex_captures/boss_skill_card_pity_gate"
const OUTPUT_FILE := "teddy_cotton_throw_gauge_to_activation_strip_6f.png"
const BACKGROUND_COLOR := Color("101317")
const PIXEL_MOTION_EPSILON := 0.0001
const EXPECTED_PROGRESS := [0.0, 0.25, 0.50, 0.75, 1.0, 1.0]
const EXPECTED_STATUS := ["charging", "charging", "charging", "charging", "ready", "casting"]

var _failures: Array[String] = []


class SkillCardCanvas:
	extends Node2D

	var renderer: Object
	var context: Dictionary = {}

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), BACKGROUND_COLOR, true)
		renderer.draw(self, context)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		_fail("boss skillcard pity-gate QA requires a real window")
		return
	if RenderingServer.get_rendering_device() == null:
		_fail("boss skillcard pity-gate QA requires a Vulkan rendering device")
		return

	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		_fail("could not create boss skillcard pity-gate capture directory")
		return

	var state := Stage3BossVariantSkillState.new()
	var renderer := Stage3BossSkillHudRenderer.new()
	renderer.prewarm_assets()
	state.reset()
	var live_context := _build_live_context()
	state.update(0.0, live_context, {})
	_expect(state.active_variant == "teddy_bear", "visual QA must route through the production Teddy variant owner")
	var teddy: Object = state.teddy_bear_state
	_prepare_ready_history(state, teddy, live_context)

	var images: Array[Image] = []
	var progress_samples: Array[float] = []
	var status_samples: Array[String] = []
	var trigger_samples: Array[bool] = [false]
	var crop_rect := Rect2i()
	var high_seed := _find_high_roll_seed()
	for frame_index in range(CAPTURE_COUNT):
		var hud_context := _build_screen_hud_context(state, live_context)
		var card := _find_skill(hud_context, "cotton_throw")
		var progress := float(card.get("progress", -1.0))
		var status := str(card.get("status", ""))
		progress_samples.append(progress)
		status_samples.append(status)
		_expect(absf(progress - float(EXPECTED_PROGRESS[frame_index])) <= 0.0001, "frame %d must expose the expected cooldown/gauge fill" % frame_index)
		_expect(status == str(EXPECTED_STATUS[frame_index]), "frame %d must expose status=%s" % [frame_index, EXPECTED_STATUS[frame_index]])
		if frame_index == 0:
			crop_rect = _build_rail_crop_rect(renderer, hud_context)
			_expect(crop_rect.has_area(), "visual QA must resolve the production Stage 3 card rail")
		var frame_image := await _capture_frame(renderer, hud_context, crop_rect)
		_expect(frame_image != null and not frame_image.is_empty(), "frame %d must capture Vulkan pixels" % frame_index)
		if frame_image != null and not frame_image.is_empty():
			images.append(frame_image)
		if frame_index < CAPTURE_COUNT - 1:
			teddy.rng.seed = high_seed
			var hit_result: Dictionary = state.register_boss_hit(Vector2(4.0, 8.0), live_context, {})
			trigger_samples.append(bool(hit_result.get("teddy_cotton_throw_triggered", false)))

	_expect(trigger_samples == [false, false, false, false, false, true], "Teddy must remain untriggered through the ready frame and activate on the immediately following hit")
	_expect(teddy.cotton_throw_pity_failures == 0, "visual activation must reset the production pity counter")
	_expect(teddy.cotton_throw_windup > 0.0, "final frame must be the actual production cotton-throw activation")
	if images.size() == CAPTURE_COUNT:
		var adjacent_differences: Array[float] = []
		for index in range(1, images.size()):
			var difference := _mean_rgb_difference(images[index - 1], images[index])
			adjacent_differences.append(difference)
			_expect(difference > PIXEL_MOTION_EPSILON, "frames %d/%d must contain visible card-state motion" % [index - 1, index])
		var strip := _compose_strip(images)
		var output_path := output_dir.path_join(OUTPUT_FILE)
		_expect(strip.save_png(output_path) == OK, "continuous pity-gate strip must save")
		print(
			"[BossSkillPityGateVulkanQA] frames=%d progress=%s status=%s triggered=%s adjacent_rgb_delta=%s"
			% [CAPTURE_COUNT, JSON.stringify(progress_samples), JSON.stringify(status_samples), JSON.stringify(trigger_samples), JSON.stringify(adjacent_differences)]
		)
		print("[BossSkillPityGateVulkanQA] evidence=%s" % output_path)

	if _failures.is_empty():
		print("[BossSkillPityGateVulkanQA] TEDDY_GAUGE_FILL=true READY_THEN_NEXT_HIT_ACTIVATION=true VULKAN=true")
		print("boss_skill_card_pity_gate_visual_qa: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _prepare_ready_history(state: Object, teddy: Object, live_context: Dictionary) -> void:
	# Five production-eligible failures establish the legitimate pre-capture
	# history. Another skill may then drain the shared gauge while pity remains;
	# model that state by returning only the gauge to zero before frame 0.
	teddy.cotton_throw_cooldown = 0.0
	teddy.cotton_bomb_cooldown = 999.0
	teddy.deadly_hug_cooldown = 999.0
	teddy.heart_beam_cooldown = 999.0
	var high_seed := _find_high_roll_seed()
	for expected_failures in range(1, 6):
		teddy.boss_special_gauge = 150.0
		teddy.rng.seed = high_seed
		var result: Dictionary = state.register_boss_hit(Vector2(4.0, 8.0), live_context, {})
		_expect(not bool(result.get("teddy_cotton_throw_triggered", false)), "pre-capture eligible roll %d must fail" % expected_failures)
		_expect(teddy.cotton_throw_pity_failures == expected_failures, "pre-capture pity history must advance exactly once")
	teddy.boss_special_gauge = 0.0


func _find_high_roll_seed() -> int:
	var probe := RandomNumberGenerator.new()
	for candidate in range(1, 100000):
		probe.seed = candidate
		if probe.randf() > 0.999:
			return candidate
	return 0


func _build_live_context() -> Dictionary:
	return {
		"current_stage": 3,
		"stage_boss_variant": "teddy_bear",
		"ball_active": true,
		"waiting_for_serve": false,
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"player_pos": Vector2(302.0, 680.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"ball_pos": Vector2(380.0, 375.0),
		"ball_vel": Vector2(4.0, 8.0),
		"ball_size": 28.6,
	}


func _build_screen_hud_context(state: Object, live_context: Dictionary) -> Dictionary:
	var context: Dictionary = state.get_hud_context(null, live_context)
	var scale := minf(float(VIEW_SIZE.x) / LOGICAL_GAME_SIZE.x, float(VIEW_SIZE.y) / LOGICAL_GAME_SIZE.y)
	var game_size := LOGICAL_GAME_SIZE * scale
	context["current_stage"] = 3
	context["view_size"] = Vector2(VIEW_SIZE)
	context["game_size"] = game_size
	context["game_offset"] = (Vector2(VIEW_SIZE) - game_size) * 0.5
	context["commando_firearm_panel_rect"] = Rect2()
	context["stage3_boss_skill_hud_show_boss_gauge"] = false
	return context


func _find_skill(context: Dictionary, skill_id: String) -> Dictionary:
	for value in context.get("stage3_boss_skill_hud_skills", []):
		if value is Dictionary and str((value as Dictionary).get("id", "")) == skill_id:
			return value as Dictionary
	return {}


func _build_rail_crop_rect(renderer: Object, context: Dictionary) -> Rect2i:
	var entries: Array = context.get("stage3_boss_skill_hud_skills", []).duplicate(false)
	entries.sort_custom(Callable(renderer, "_sort_entries"))
	if entries.is_empty():
		return Rect2i()
	var game_offset: Vector2 = context.get("game_offset", Vector2.ZERO)
	var game_size: Vector2 = context.get("game_size", Vector2.ZERO)
	var metrics: Dictionary = renderer.get_debug_card_metrics(game_offset.x)
	var scale_factor := float(metrics.get("scale_factor", 1.0))
	var card_size: Vector2 = metrics.get("card_size", Vector2(38.0, 12.0))
	var card_gap := float(metrics.get("card_gap", 2.0))
	var margin_x := float(metrics.get("margin_x", 3.0))
	var margin_y := float(metrics.get("margin_y", 5.0))
	var total_h := float(entries.size()) * (card_size.y + card_gap) - card_gap
	var card_x := maxf(1.0, game_offset.x - card_size.x - margin_x)
	var start_y := BossSkillCardHudSpec.resolve_stack_start_y(game_offset, game_size.y, total_h, margin_y, card_x, card_size.x, scale_factor, Rect2())
	var rail_rect := Rect2(Vector2(card_x, start_y), Vector2(card_size.x, total_h)).grow(4.0)
	rail_rect = rail_rect.intersection(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)))
	return Rect2i(Vector2i(floori(rail_rect.position.x), floori(rail_rect.position.y)), Vector2i(ceili(rail_rect.size.x), ceili(rail_rect.size.y)))


func _capture_frame(renderer: Object, context: Dictionary, crop_rect: Rect2i) -> Image:
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var canvas := SkillCardCanvas.new()
	canvas.renderer = renderer
	canvas.context = context
	viewport.add_child(canvas)
	canvas.queue_redraw()
	for _index in range(4):
		await process_frame
	var texture := viewport.get_texture()
	var full_image: Image = null if texture == null else texture.get_image()
	var cropped: Image = null
	if full_image != null and not full_image.is_empty():
		if full_image.get_format() != Image.FORMAT_RGBA8:
			full_image.convert(Image.FORMAT_RGBA8)
		cropped = full_image.get_region(crop_rect)
	viewport.queue_free()
	await process_frame
	return cropped


func _compose_strip(images: Array[Image]) -> Image:
	var frame_size := images[0].get_size() * OUTPUT_SCALE
	var strip_size := Vector2i(frame_size.x * images.size() + STRIP_GAP_PX * (images.size() - 1), frame_size.y)
	var strip := Image.create(strip_size.x, strip_size.y, false, Image.FORMAT_RGBA8)
	strip.fill(Color("080a0d"))
	for index in range(images.size()):
		var scaled := images[index].duplicate()
		scaled.resize(frame_size.x, frame_size.y, Image.INTERPOLATE_NEAREST)
		var target_x := index * (frame_size.x + STRIP_GAP_PX)
		strip.blit_rect(scaled, Rect2i(Vector2i.ZERO, frame_size), Vector2i(target_x, 0))
		if index < images.size() - 1:
			strip.fill_rect(Rect2i(target_x + frame_size.x, 0, STRIP_GAP_PX, frame_size.y), Color("e7b84b"))
	return strip


func _mean_rgb_difference(first: Image, second: Image) -> float:
	if first.get_size() != second.get_size():
		return 0.0
	var total := 0.0
	var count := 0
	for y in range(first.get_height()):
		for x in range(first.get_width()):
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			total += (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) / 3.0
			count += 1
	return total / maxf(1.0, float(count))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
