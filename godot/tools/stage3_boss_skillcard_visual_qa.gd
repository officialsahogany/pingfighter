extends SceneTree

const BossSkillCardHudSpec := preload("res://scripts/stages/common/boss_skill_card_hud_spec.gd")
const Stage3BossSkillHudRenderer := preload("res://scripts/stages/stage3/stage3_boss_skill_hud_renderer.gd")
const Stage3BossVariantSkillState := preload("res://scripts/stages/stage3/stage3_boss_variant_skill_state.gd")

const VIEW_SIZE := Vector2i(2020, 1246)
const LOGICAL_GAME_SIZE := Vector2(760.0, 750.0)
const VARIANTS := ["yeonmyo", "teddy_bear", "alice"]
const OUTPUT_DIR := "res://.godot/codex_captures/stage3_skillcards"
const BACKGROUND_COLOR := Color("101317")

var failures: Array[String] = []
var saved_paths: Array[String] = []


class SkillCardCanvas:
	extends Node2D

	var renderer: Object
	var context: Dictionary = {}
	var draw_cards := false
	var draw_count := 0

	func _draw() -> void:
		draw_count += 1
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), BACKGROUND_COLOR, true)
		if draw_cards:
			renderer.draw(self, context)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		_fail("Stage 3 skillcard visual QA requires a real window")
		return
	if RenderingServer.get_rendering_device() == null:
		_fail("Stage 3 skillcard visual QA requires a Vulkan rendering device")
		return
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		_fail("could not create Stage 3 skillcard capture directory")
		return
	for variant_id in VARIANTS:
		await _capture_variant(variant_id, output_dir)
	await _capture_fallback(output_dir)
	if failures.is_empty():
		for path in saved_paths:
			print("[Stage3BossSkillcardVisualQA] evidence=%s" % path)
		print("stage3_boss_skillcard_visual_qa: ok")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _capture_variant(variant_id: String, output_dir: String) -> void:
	var renderer := Stage3BossSkillHudRenderer.new()
	renderer.prewarm_assets()
	var context := _build_live_context(variant_id)
	var card_rects := _build_card_rects(renderer, context)
	var expected_count := _as_array(context.get("stage3_boss_skill_hud_skills", [])).size()
	_expect(card_rects.size() == expected_count, "%s must lay out every live skill card" % variant_id)
	var capture := await _render_context(renderer, context)
	var background_image: Image = capture.get("background", null)
	var card_image: Image = capture.get("cards", null)
	if background_image == null or card_image == null:
		_expect(false, "%s must produce a Vulkan card-rail capture" % variant_id)
		return
	for rect_value in card_rects:
		var rect: Rect2 = rect_value
		_expect(
			_mean_rgb_difference(background_image, card_image, rect.grow(-3.0)) > 0.035,
			"%s must visibly replace every production card rect with atlas pixels" % variant_id
		)
	var output_path := output_dir.path_join("stage3_skillcards_%s_2020x1246.png" % variant_id)
	var save_error := card_image.save_png(output_path)
	_expect(save_error == OK, "%s Vulkan capture must save" % variant_id)
	if save_error == OK:
		saved_paths.append(output_path)


func _capture_fallback(output_dir: String) -> void:
	var renderer := Stage3BossSkillHudRenderer.new()
	renderer.prewarm_assets()
	var known_context := _build_live_context("yeonmyo")
	var fallback_context := known_context.duplicate(true)
	var fallback_skills := _as_array(fallback_context.get("stage3_boss_skill_hud_skills", []))
	if fallback_skills.is_empty() or not (fallback_skills[0] is Dictionary):
		_expect(false, "fallback fixture requires a live Yeonmyo skill entry")
		return
	(fallback_skills[0] as Dictionary)["id"] = "missing_runtime_skill"
	(fallback_skills[0] as Dictionary)["status"] = "ready"
	(fallback_skills[0] as Dictionary)["ready"] = true
	(fallback_skills[0] as Dictionary)["progress"] = 1.0
	var known_capture := await _render_context(renderer, known_context)
	var fallback_capture := await _render_context(renderer, fallback_context)
	var known_image: Image = known_capture.get("cards", null)
	var fallback_image: Image = fallback_capture.get("cards", null)
	var background_image: Image = fallback_capture.get("background", null)
	var rects := _build_card_rects(renderer, fallback_context)
	if known_image == null or fallback_image == null or background_image == null or rects.is_empty():
		_expect(false, "fallback fixture must produce comparable Vulkan captures")
		return
	var fallback_rect: Rect2 = rects[0]
	_expect(
		_mean_rgb_difference(background_image, fallback_image, fallback_rect.grow(-3.0)) > 0.025,
		"missing Stage 3 skillcard art must still draw the procedural color fallback"
	)
	_expect(
		_mean_rgb_difference(known_image, fallback_image, fallback_rect.grow(-3.0)) > 0.025,
		"missing-id fallback pixels must differ visibly from canonical atlas art"
	)
	var output_path := output_dir.path_join("stage3_skillcards_fallback_2020x1246.png")
	var save_error := fallback_image.save_png(output_path)
	_expect(save_error == OK, "fallback Vulkan capture must save")
	if save_error == OK:
		saved_paths.append(output_path)


func _build_live_context(variant_id: String) -> Dictionary:
	var state := Stage3BossVariantSkillState.new()
	var state_context := {
		"current_stage": 3,
		"stage_boss_variant": variant_id,
		"ball_active": false,
		"waiting_for_serve": true,
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"player_pos": Vector2(302.0, 680.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"ball_pos": Vector2(380.0, 375.0),
		"ball_vel": Vector2(4.0, 8.0),
		"ball_size": 28.6,
	}
	var _update_result: Dictionary = state.update(0.0, state_context, {})
	_expect(str(state.active_variant) == variant_id, "visual QA must route the live %s state" % variant_id)
	var context: Dictionary = state.get_hud_context(null, state_context)
	var scale := minf(float(VIEW_SIZE.x) / LOGICAL_GAME_SIZE.x, float(VIEW_SIZE.y) / LOGICAL_GAME_SIZE.y)
	var game_size := LOGICAL_GAME_SIZE * scale
	context["current_stage"] = 3
	context["view_size"] = Vector2(VIEW_SIZE)
	context["game_size"] = game_size
	context["game_offset"] = (Vector2(VIEW_SIZE) - game_size) * 0.5
	context["commando_firearm_panel_rect"] = Rect2()
	return context


func _build_card_rects(renderer: Object, context: Dictionary) -> Array[Rect2]:
	var entries := _as_array(context.get("stage3_boss_skill_hud_skills", [])).duplicate(false)
	entries.sort_custom(Callable(renderer, "_sort_entries"))
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
	var rects: Array[Rect2] = []
	for index in range(entries.size()):
		rects.append(Rect2(Vector2(card_x, start_y + float(index) * (card_size.y + card_gap)), card_size))
	return rects


func _render_context(renderer: Object, context: Dictionary) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var canvas := SkillCardCanvas.new()
	canvas.renderer = renderer
	canvas.context = context
	viewport.add_child(canvas)
	canvas.draw_cards = false
	canvas.queue_redraw()
	await _wait_frames(4)
	var background_image := _capture_image(viewport)
	canvas.draw_cards = true
	canvas.queue_redraw()
	await _wait_frames(4)
	var card_image := _capture_image(viewport)
	viewport.queue_free()
	await process_frame
	return {"background": background_image, "cards": card_image}


func _capture_image(viewport: SubViewport) -> Image:
	var texture := viewport.get_texture()
	if texture == null:
		return null
	var image := texture.get_image()
	if image == null or image.is_empty():
		return null
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image


func _mean_rgb_difference(first: Image, second: Image, rect: Rect2) -> float:
	var bounds := Rect2(Vector2.ZERO, Vector2(first.get_size())).intersection(rect)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return 0.0
	var step_x := maxi(1, int(bounds.size.x / 48.0))
	var step_y := maxi(1, int(bounds.size.y / 18.0))
	var total := 0.0
	var count := 0
	for y in range(int(bounds.position.y), int(bounds.end.y), step_y):
		for x in range(int(bounds.position.x), int(bounds.end.x), step_x):
			var first_pixel := first.get_pixel(x, y)
			var second_pixel := second.get_pixel(x, y)
			total += (
				absf(first_pixel.r - second_pixel.r)
				+ absf(first_pixel.g - second_pixel.g)
				+ absf(first_pixel.b - second_pixel.b)
			) / 3.0
			count += 1
	return total / maxf(1.0, float(count))


func _wait_frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
