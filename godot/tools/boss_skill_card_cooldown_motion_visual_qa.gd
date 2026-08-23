extends SceneTree

const BossSkillCardHudSpec := preload("res://scripts/stages/common/boss_skill_card_hud_spec.gd")
const Stage2BossSkillHudRenderer := preload("res://scripts/stages/stage2/stage2_boss_skill_hud_renderer.gd")
const Stage2BossVariantSkillState := preload("res://scripts/stages/stage2/stage2_boss_variant_skill_state.gd")
const Stage3BossSkillHudRenderer := preload("res://scripts/stages/stage3/stage3_boss_skill_hud_renderer.gd")
const Stage3BossVariantSkillState := preload("res://scripts/stages/stage3/stage3_boss_variant_skill_state.gd")
const Stage7AkamuBossSkillHudRenderer := preload("res://scripts/stages/stage7/stage7_akamu_boss_skill_hud_renderer.gd")
const Stage7AkamuState := preload("res://scripts/stages/stage7/stage7_akamu_state.gd")

const VIEW_SIZE := Vector2i(2020, 1246)
const LOGICAL_GAME_SIZE := Vector2(760.0, 750.0)
const VARIANT_SPECS := [
	{"id": "molewang", "stage": 2},
	{"id": "arachne", "stage": 2},
	{"id": "teddy_bear", "stage": 3},
	{"id": "alice", "stage": 3},
	{"id": "akamu", "stage": 7},
]
const CAPTURE_COUNT := 5
const SAMPLE_STEP_SEC := 1.0
const UPDATE_DELTA_SEC := 0.05
const OUTPUT_SCALE := 2
const STRIP_GAP_PX := 8
const OUTPUT_DIR := "res://.godot/codex_captures/boss_skill_card_cooldown_motion"
const BACKGROUND_COLOR := Color("101317")
const PROGRESS_EPSILON := 0.0001
const PIXEL_MOTION_EPSILON := 0.0001

var failures: Array[String] = []
var saved_paths: Array[String] = []


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
		_fail("boss skillcard cooldown motion QA requires a real window")
		return
	if RenderingServer.get_rendering_device() == null:
		_fail("boss skillcard cooldown motion QA requires a Vulkan rendering device")
		return
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		_fail("could not create boss skillcard cooldown motion capture directory")
		return
	for spec_value in VARIANT_SPECS:
		await _capture_variant(spec_value as Dictionary, output_dir)
	if failures.is_empty():
		for path in saved_paths:
			print("[BossSkillCardCooldownMotionQA] evidence=%s" % path)
		print("[BossSkillCardCooldownMotionQA] BOSSES=5 STRIPS=5 FRAMES_PER_STRIP=%d VULKAN=true" % CAPTURE_COUNT)
		print("boss_skill_card_cooldown_motion_visual_qa: ok")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _capture_variant(spec: Dictionary, output_dir: String) -> void:
	var variant_id := str(spec.get("id", ""))
	var stage := int(spec.get("stage", 0))
	var state: Object
	var renderer: Object
	match stage:
		2:
			state = Stage2BossVariantSkillState.new()
			renderer = Stage2BossSkillHudRenderer.new()
		3:
			state = Stage3BossVariantSkillState.new()
			renderer = Stage3BossSkillHudRenderer.new()
		7:
			state = Stage7AkamuState.new()
			renderer = Stage7AkamuBossSkillHudRenderer.new()
		_:
			_fail("unsupported visual QA stage: %d" % stage)
			return
	renderer.prewarm_assets()
	state.reset()
	var live_context := _build_live_context(stage, variant_id)
	var _selection_result: Dictionary = state.update(0.0, live_context, {})
	if stage in [2, 3]:
		_expect(str(state.active_variant) == variant_id, "%s visual QA must select its production variant state" % variant_id)
	_prime_optional_activation_gauge(state, live_context, variant_id)

	var images: Array[Image] = []
	var progress_samples: Array[Dictionary] = []
	var crop_rect := Rect2i()
	for frame_index in range(CAPTURE_COUNT):
		var hud_context := _build_screen_hud_context(state, live_context, stage)
		var time_progress := _time_progress_map(hud_context, stage)
		_expect(not time_progress.is_empty(), "%s must publish at least one time-based cooldown" % variant_id)
		if not progress_samples.is_empty():
			var previous: Dictionary = progress_samples[-1]
			for skill_id in previous:
				_expect(
					float(time_progress.get(skill_id, -1.0)) > float(previous.get(skill_id, -1.0)) + PROGRESS_EPSILON,
					"%s/%s progress must increase between visual frames %d and %d"
					% [variant_id, skill_id, frame_index - 1, frame_index]
				)
		progress_samples.append(time_progress)
		if frame_index == 0:
			crop_rect = _build_rail_crop_rect(renderer, hud_context, stage)
			_expect(crop_rect.has_area(), "%s must resolve a production card-rail crop" % variant_id)
		var frame_image := await _capture_frame(renderer, hud_context, crop_rect)
		_expect(frame_image != null and not frame_image.is_empty(), "%s frame %d must capture Vulkan pixels" % [variant_id, frame_index])
		if frame_image != null and not frame_image.is_empty():
			images.append(frame_image)
		if frame_index < CAPTURE_COUNT - 1:
			_advance_live_state(state, live_context, SAMPLE_STEP_SEC)

	if images.size() != CAPTURE_COUNT:
		return
	var adjacent_differences: Array[float] = []
	for index in range(1, images.size()):
		var difference := _mean_rgb_difference(images[index - 1], images[index])
		adjacent_differences.append(difference)
		_expect(difference > PIXEL_MOTION_EPSILON, "%s frames %d/%d must contain visible cooldown-fill motion" % [variant_id, index - 1, index])
	var strip := _compose_strip(images)
	var output_path := output_dir.path_join("%s_cooldown_motion_strip_%df.png" % [variant_id, CAPTURE_COUNT])
	var save_error := strip.save_png(output_path)
	_expect(save_error == OK, "%s cooldown motion strip must save" % variant_id)
	if save_error == OK:
		saved_paths.append(output_path)
	print(
		"[BossSkillCardCooldownMotionQA] variant=%s frames=%d first=%s last=%s adjacent_rgb_delta=%s"
		% [variant_id, CAPTURE_COUNT, JSON.stringify(progress_samples[0]), JSON.stringify(progress_samples[-1]), JSON.stringify(adjacent_differences)]
	)


func _prime_optional_activation_gauge(state: Object, live_context: Dictionary, variant_id: String) -> void:
	var hud_context: Dictionary = state.get_hud_context(null, live_context)
	var gauge_max := float(hud_context.get("stage3_boss_skill_hud_boss_gauge_max", 0.0))
	if variant_id == "teddy_bear":
		state.teddy_bear_state.boss_special_gauge = gauge_max
	elif variant_id == "alice":
		state.alice_state.boss_special_gauge = gauge_max


func _build_live_context(stage: int, variant_id: String) -> Dictionary:
	return {
		"current_stage": stage,
		"stage_boss_variant": variant_id,
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


func _build_screen_hud_context(state: Object, live_context: Dictionary, stage: int) -> Dictionary:
	var context: Dictionary = state.get_hud_context(null, live_context)
	var scale := minf(float(VIEW_SIZE.x) / LOGICAL_GAME_SIZE.x, float(VIEW_SIZE.y) / LOGICAL_GAME_SIZE.y)
	var game_size := LOGICAL_GAME_SIZE * scale
	context["current_stage"] = stage
	context["view_size"] = Vector2(VIEW_SIZE)
	context["game_size"] = game_size
	context["game_offset"] = (Vector2(VIEW_SIZE) - game_size) * 0.5
	context["commando_firearm_panel_rect"] = Rect2()
	context["stage3_boss_skill_hud_show_boss_gauge"] = false
	return context


func _time_progress_map(context: Dictionary, stage: int) -> Dictionary:
	var key := _skills_key(stage)
	var result := {}
	for value in _as_array(context.get(key, [])):
		if value is Dictionary and str(value.get("cooldown_contract", "")) == "time":
			result[str(value.get("id", ""))] = float(value.get("progress", -1.0))
	return result


func _advance_live_state(state: Object, live_context: Dictionary, duration_sec: float) -> void:
	var ticks := ceili(duration_sec / UPDATE_DELTA_SEC)
	for _index in range(ticks):
		state.update(UPDATE_DELTA_SEC, live_context, {})


func _build_rail_crop_rect(renderer: Object, context: Dictionary, stage: int) -> Rect2i:
	var key := _skills_key(stage)
	var entries := _as_array(context.get(key, [])).duplicate(false)
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
	var start_y := BossSkillCardHudSpec.resolve_stack_start_y(
		game_offset,
		game_size.y,
		total_h,
		margin_y,
		card_x,
		card_size.x,
		scale_factor,
		Rect2()
	)
	var rail_rect := Rect2(Vector2(card_x, start_y), Vector2(card_size.x, total_h)).grow(4.0)
	var bounds := Rect2(Vector2.ZERO, Vector2(VIEW_SIZE))
	rail_rect = rail_rect.intersection(bounds)
	return Rect2i(
		Vector2i(floori(rail_rect.position.x), floori(rail_rect.position.y)),
		Vector2i(ceili(rail_rect.size.x), ceili(rail_rect.size.y))
	)


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
	await _wait_frames(4)
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


func _skills_key(stage: int) -> String:
	match stage:
		2:
			return "stage2_boss_skill_hud_skills"
		3:
			return "stage3_boss_skill_hud_skills"
		7:
			return "stage7_boss_skill_hud_skills"
	return ""


func _compose_strip(images: Array[Image]) -> Image:
	var frame_size := images[0].get_size() * OUTPUT_SCALE
	var strip_size := Vector2i(
		frame_size.x * images.size() + STRIP_GAP_PX * (images.size() - 1),
		frame_size.y
	)
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


func _wait_frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _as_array(value: Variant) -> Array:
	return value if value is Array else []


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
