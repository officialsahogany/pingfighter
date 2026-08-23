extends SceneTree

const BossSkillCardHudSpec := preload("res://scripts/stages/common/boss_skill_card_hud_spec.gd")
const BossSkillTriggerClass := preload("res://scripts/stages/common/boss_skill_trigger_class.gd")
const Stage1DaljiBossSkillCooldownState := preload("res://scripts/stages/stage1/stage1_dalji_boss_skill_cooldown_state.gd")
const Stage1DaljiBossSkillHudRenderer := preload("res://scripts/stages/stage1/stage1_dalji_boss_skill_hud_renderer.gd")
const Stage2BossSkillState := preload("res://scripts/stages/stage2/stage2_boss_skill_state.gd")
const Stage2BossSkillHudRenderer := preload("res://scripts/stages/stage2/stage2_boss_skill_hud_renderer.gd")

const SCALE_FACTOR := 4.0
const CARD_SIZE := Vector2i(168, 64)
const DRAW_RECT := Rect2(Vector2(8.0, 8.0), Vector2(152.0, 48.0))
const OUTPUT_DIR := "res://.godot/codex_captures/boss_skill_card_trigger_marker"
const OUTPUT_NAME := "dalji_hit_wait_vs_cheongringwi_instant_vulkan.png"
const PIXEL_EPSILON := 2

var _failures: Array[String] = []


class CardCanvas:
	extends Node2D

	var renderer: Object
	var skill: Dictionary
	var renderer_kind := "dalji"

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(CARD_SIZE)), Color("110e0c"), true)
		if renderer_kind == "dalji":
			renderer._draw_card(self, DRAW_RECT, skill, SCALE_FACTOR, 1.25)
		else:
			renderer._draw_card(self, DRAW_RECT, skill, SCALE_FACTOR, ThemeDB.fallback_font)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		_fail("trigger marker visual QA requires a real window")
	if RenderingServer.get_rendering_device() == null:
		_fail("trigger marker visual QA requires a Vulkan rendering device")
	if not _failures.is_empty():
		_finish()
		return

	var dalji_state := Stage1DaljiBossSkillCooldownState.new()
	var cheongringwi_state := Stage2BossSkillState.new()
	var dalji_renderer := Stage1DaljiBossSkillHudRenderer.new()
	var cheongringwi_renderer := Stage2BossSkillHudRenderer.new()
	dalji_renderer.prewarm_assets()
	cheongringwi_renderer.prewarm_assets()

	var dalji_hit := _find_skill(dalji_state.get_hud_context(), "stage1_dalji_boss_skill_hud_skills", "whip")
	var dalji_instant := _find_skill(dalji_state.get_hud_context(), "stage1_dalji_boss_skill_hud_skills", "spinning_top")
	var cheongringwi_instant := _find_skill(cheongringwi_state.get_hud_context(), "stage2_boss_skill_hud_skills", "water_cannon")
	_expect(str(dalji_hit.get("trigger_type", "")) == BossSkillTriggerClass.TRIGGER_ON_BOSS_HIT, "Dalji hit-wait card must come from the production trigger declaration")
	_expect(str(dalji_instant.get("trigger_type", "")) == BossSkillTriggerClass.TRIGGER_INSTANT, "Dalji instant card must come from the production trigger declaration")
	_expect(str(cheongringwi_instant.get("trigger_type", "")) == BossSkillTriggerClass.TRIGGER_INSTANT, "Cheongringwi card must come from the production instant declaration")
	_prime_ready(dalji_hit)
	_prime_ready(dalji_instant)
	_prime_ready(cheongringwi_instant)

	var hit_image := await _capture_card(dalji_renderer, dalji_hit, "dalji")
	var hit_unmarked_skill := dalji_hit.duplicate(true)
	hit_unmarked_skill["trigger_type"] = BossSkillTriggerClass.TRIGGER_INSTANT
	var hit_unmarked_image := await _capture_card(dalji_renderer, hit_unmarked_skill, "dalji")
	var dalji_instant_image := await _capture_card(dalji_renderer, dalji_instant, "dalji")
	var dalji_instant_baseline := dalji_instant.duplicate(true)
	dalji_instant_baseline.erase("trigger_type")
	var dalji_instant_baseline_image := await _capture_card(dalji_renderer, dalji_instant_baseline, "dalji")
	var cheongringwi_image := await _capture_card(cheongringwi_renderer, cheongringwi_instant, "cheongringwi")
	var cheongringwi_baseline := cheongringwi_instant.duplicate(true)
	cheongringwi_baseline.erase("trigger_type")
	var cheongringwi_baseline_image := await _capture_card(cheongringwi_renderer, cheongringwi_baseline, "cheongringwi")
	for image_value in [hit_image, hit_unmarked_image, dalji_instant_image, dalji_instant_baseline_image, cheongringwi_image, cheongringwi_baseline_image]:
		(image_value as Image).convert(Image.FORMAT_RGBA8)

	var marker_bounds := BossSkillCardHudSpec.get_trigger_marker_bounds(DRAW_RECT, SCALE_FACTOR).grow(3.0)
	var hit_delta := _compare_images(hit_image, hit_unmarked_image, marker_bounds)
	_expect(int(hit_delta.get("changed", 0)) > 0, "hit-trigger declaration must produce visible marker pixels")
	_expect(int(hit_delta.get("outside", 0)) == 0, "Dalji pixels outside the marker bounds must remain unchanged")
	var dalji_instant_delta := _compare_images(dalji_instant_image, dalji_instant_baseline_image, Rect2())
	_expect(int(dalji_instant_delta.get("changed", 0)) == 0, "Dalji instant card must remain pixel-identical when marker metadata is absent")
	var cheongringwi_delta := _compare_images(cheongringwi_image, cheongringwi_baseline_image, Rect2())
	_expect(int(cheongringwi_delta.get("changed", 0)) == 0, "Cheongringwi instant card must remain pixel-identical when marker metadata is absent")

	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		_fail("could not create trigger marker capture directory")
	else:
		var comparison := Image.create(CARD_SIZE.x * 2 + 16, CARD_SIZE.y, false, Image.FORMAT_RGBA8)
		comparison.fill(Color("110e0c"))
		comparison.blit_rect(hit_image, Rect2i(Vector2i.ZERO, hit_image.get_size()), Vector2i.ZERO)
		comparison.blit_rect(cheongringwi_image, Rect2i(Vector2i.ZERO, cheongringwi_image.get_size()), Vector2i(CARD_SIZE.x + 16, 0))
		var output_path := output_dir.path_join(OUTPUT_NAME)
		_expect(comparison.save_png(output_path) == OK, "side-by-side trigger marker Vulkan capture must save")
		print("[BossSkillCardTriggerMarkerQA] evidence=%s" % output_path)
	print(
		"[BossSkillCardTriggerMarkerQA] HIT_CHANGED_PIXELS=%d OUTSIDE_MARKER_CHANGED_PIXELS=%d DALJI_INSTANT_DELTA=%d CHEONGRINGWI_INSTANT_DELTA=%d VULKAN=true"
		% [hit_delta.get("changed", 0), hit_delta.get("outside", 0), dalji_instant_delta.get("changed", 0), cheongringwi_delta.get("changed", 0)]
	)
	_finish()


func _capture_card(renderer: Object, skill: Dictionary, renderer_kind: String) -> Image:
	var viewport := SubViewport.new()
	viewport.size = CARD_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var canvas := CardCanvas.new()
	canvas.renderer = renderer
	canvas.skill = skill
	canvas.renderer_kind = renderer_kind
	viewport.add_child(canvas)
	canvas.queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	await process_frame
	return image


func _compare_images(actual: Image, baseline: Image, allowed_bounds: Rect2) -> Dictionary:
	if actual == null or baseline == null or actual.get_size() != baseline.get_size():
		_fail("pixel regression images must have equal non-empty dimensions")
		return {"changed": 0, "outside": 0}
	var changed := 0
	var outside := 0
	for y in range(actual.get_height()):
		for x in range(actual.get_width()):
			var a := actual.get_pixel(x, y)
			var b := baseline.get_pixel(x, y)
			var delta := maxi(
				absi(int(round(a.r * 255.0)) - int(round(b.r * 255.0))),
				maxi(
					absi(int(round(a.g * 255.0)) - int(round(b.g * 255.0))),
					absi(int(round(a.b * 255.0)) - int(round(b.b * 255.0)))
				)
			)
			if delta <= PIXEL_EPSILON:
				continue
			changed += 1
			if allowed_bounds.has_area() and not allowed_bounds.has_point(Vector2(x, y)):
				outside += 1
	return {"changed": changed, "outside": outside}


func _prime_ready(skill: Dictionary) -> void:
	skill["status"] = "ready"
	skill["ready"] = true
	skill["active"] = false
	skill["progress"] = 1.0
	skill["cooldown_remaining"] = 0.0


func _find_skill(context: Dictionary, key: String, skill_id: String) -> Dictionary:
	for value in context.get(key, []):
		if value is Dictionary and str((value as Dictionary).get("id", "")) == skill_id:
			return (value as Dictionary).duplicate(true)
	return {}


func _finish() -> void:
	if _failures.is_empty():
		print("boss_skill_card_trigger_marker_visual_qa: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _fail(message: String) -> void:
	_failures.append(message)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)
