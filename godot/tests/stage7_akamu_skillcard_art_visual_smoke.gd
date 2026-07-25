extends SceneTree

const Stage7AkamuPillarBackground := preload("res://scripts/stages/stage7/stage7_akamu_pillar_background.gd")
const Stage7AkamuBossSkillHudRenderer := preload("res://scripts/stages/stage7/stage7_akamu_boss_skill_hud_renderer.gd")

const LOGICAL_GAME_SIZE := Vector2(760.0, 750.0)
const VIEW_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const OUT_DIR := "res://../tmp"

var _failures: Array[String] = []
var _saved_paths: Array[String] = []


class SkillCardRailProbe:
	extends Node2D

	var background: Object
	var renderer: Object
	var context: Dictionary = {}
	var draw_cards := false
	var draw_count := 0

	func _draw() -> void:
		draw_count += 1
		background.draw(
			self,
			context.get("view_size", Vector2.ZERO),
			context.get("game_offset", Vector2.ZERO),
			context.get("game_size", Vector2.ZERO),
			LOGICAL_GAME_SIZE.x,
			null,
			1.0
		)
		if draw_cards:
			renderer.draw(self, context)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var display_name := DisplayServer.get_name().to_lower()
	var background := Stage7AkamuPillarBackground.new()
	background.prewarm_assets()
	for view_size in VIEW_SIZES:
		await _verify_resolution(background, view_size)
	var suffix := " (pixel capture skipped under headless display server)" if display_name.find("headless") >= 0 else ""
	_finish("stage7_akamu_skillcard_art_visual_smoke: ok%s" % suffix)


func _verify_resolution(background: Object, view_size: Vector2i) -> void:
	var renderer := Stage7AkamuBossSkillHudRenderer.new()
	renderer.prewarm_assets()
	var context := _build_context(view_size)
	var layout: Dictionary = renderer.build_card_layout(context)
	var entries := _as_array(layout.get("entries", []))
	var rects := _as_array(layout.get("rects", []))
	_expect(entries.size() == 4 and rects.size() == 4, "%s should lay out four Stage 7 skill cards" % view_size)
	if entries.size() != 4 or rects.size() != 4:
		return

	var viewport := SubViewport.new()
	viewport.size = view_size
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)

	var probe := SkillCardRailProbe.new()
	probe.background = background
	probe.renderer = renderer
	probe.context = context
	viewport.add_child(probe)

	probe.draw_cards = false
	probe.queue_redraw()
	await _wait_frames(4)
	_expect(probe.draw_count > 0, "%s should execute the Stage 7 pillar draw pass" % view_size)
	if DisplayServer.get_name().to_lower().find("headless") >= 0:
		var background_draw_count := probe.draw_count
		probe.draw_cards = true
		probe.queue_redraw()
		await _wait_frames(3)
		_expect(
			probe.draw_count > background_draw_count,
			"%s should execute the real Stage 7 skill-card draw pass under headless smoke" % view_size
		)
		viewport.queue_free()
		await process_frame
		return
	var background_image := _capture_image(viewport)
	_expect(background_image != null, "%s should capture the Stage 7 pillar background" % view_size)
	if background_image == null:
		viewport.queue_free()
		return

	var no_badge_context := context.duplicate(true)
	_set_skill_value(no_badge_context, "stage7_clone", "active_count", 0)
	probe.context = no_badge_context
	probe.draw_cards = true
	probe.queue_redraw()
	await _wait_frames(3)
	var no_badge_image := _capture_image(viewport)

	probe.context = context
	probe.queue_redraw()
	await _wait_frames(3)
	var half_wipe_image := _capture_image(viewport)
	_expect(no_badge_image != null and half_wipe_image != null, "%s should capture the real skill-card rail" % view_size)
	if no_badge_image == null or half_wipe_image == null:
		viewport.queue_free()
		return

	for index in range(entries.size()):
		var card_rect := _as_rect2(rects[index])
		var card_id := str((entries[index] as Dictionary).get("id", "unknown"))
		_expect(
			_mean_rgb_difference(background_image, half_wipe_image, card_rect.grow(-2.0)) > 0.035,
			"%s %s should visibly replace the live pillar pixels" % [view_size, card_id]
		)

	var clone_rect := _find_entry_rect(entries, rects, "stage7_clone")
	var clone_badge_rect := Rect2(
		Vector2(clone_rect.position.x + clone_rect.size.x * 0.58, clone_rect.position.y),
		Vector2(clone_rect.size.x * 0.42, clone_rect.size.y)
	)
	_expect(
		_max_rgb_difference(no_badge_image, half_wipe_image, clone_badge_rect) > 0.18,
		"%s clone ×4 badge should remain visible over the generated card art" % view_size
	)

	var full_wipe_context := context.duplicate(true)
	_set_skill_value(full_wipe_context, "stage7_shuriken", "progress", 1.0)
	probe.context = full_wipe_context
	probe.queue_redraw()
	await _wait_frames(3)
	var full_wipe_image := _capture_image(viewport)
	_expect(full_wipe_image != null, "%s should capture the full-wipe comparison" % view_size)
	if full_wipe_image != null:
		var shuriken_rect := _find_entry_rect(entries, rects, "stage7_shuriken")
		var left_rect := Rect2(
			Vector2(shuriken_rect.position.x + shuriken_rect.size.x * 0.08, shuriken_rect.position.y + 2.0),
			Vector2(shuriken_rect.size.x * 0.34, maxf(1.0, shuriken_rect.size.y - 4.0))
		)
		var right_rect := Rect2(
			Vector2(shuriken_rect.position.x + shuriken_rect.size.x * 0.58, shuriken_rect.position.y + 2.0),
			Vector2(shuriken_rect.size.x * 0.34, maxf(1.0, shuriken_rect.size.y - 4.0))
		)
		_expect(
			_mean_rgb_difference(half_wipe_image, full_wipe_image, left_rect) < 0.025,
			"%s shuriken left half should already be fully revealed at 50 percent" % view_size
		)
		_expect(
			_mean_rgb_difference(half_wipe_image, full_wipe_image, right_rect) > 0.035,
			"%s shuriken right half should brighten only after the cooldown wipe advances" % view_size
		)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var out_path := "%s/stage7_akamu_skillcards_%dx%d.png" % [OUT_DIR, view_size.x, view_size.y]
	var save_error := half_wipe_image.save_png(ProjectSettings.globalize_path(out_path))
	_expect(save_error == OK, "%s should save the runtime skill-card screenshot" % view_size)
	if save_error == OK:
		_saved_paths.append(ProjectSettings.globalize_path(out_path))

	viewport.queue_free()
	await process_frame


func _build_context(view_size: Vector2i) -> Dictionary:
	var scale := minf(float(view_size.x) / LOGICAL_GAME_SIZE.x, float(view_size.y) / LOGICAL_GAME_SIZE.y)
	var game_size := LOGICAL_GAME_SIZE * scale
	var game_offset := (Vector2(view_size) - game_size) * 0.5
	return {
		"current_stage": 7,
		"view_size": Vector2(view_size),
		"game_offset": game_offset,
		"game_size": game_size,
		"time_seconds": 1.25,
		"stage7_boss_skill_hud_active": true,
		"stage7_boss_skill_hud_skills": [
			{
				"id": "stage7_clone", "name": "그림자분신", "color": Color(0.56, 0.48, 0.86),
				"progress": 0.25, "active": true, "active_count": 4,
				"ready": false, "status": "active", "next_activation_remaining": 6.0,
			},
			{
				"id": "stage7_shuriken", "name": "표창", "color": Color(0.72, 0.78, 0.88),
				"progress": 0.5, "active": false, "ready": false,
				"status": "charging", "next_activation_remaining": 8.0,
			},
			{
				"id": "stage7_cloud", "name": "구름장막", "color": Color(0.42, 0.66, 0.72),
				"progress": 0.2, "active": false, "ready": true,
				"status": "ready", "next_activation_remaining": 0.0,
			},
			{
				"id": "stage7_superspeed", "name": "극정호신", "color": Color(0.96, 0.46, 0.18),
				"progress": 0.8, "active": false, "ready": false,
				"status": "locked", "next_activation_remaining": 250.0,
			},
		],
	}


func _set_skill_value(context: Dictionary, skill_id: String, key: String, value: Variant) -> void:
	for skill_value in _as_array(context.get("stage7_boss_skill_hud_skills", [])):
		if skill_value is Dictionary and str((skill_value as Dictionary).get("id", "")) == skill_id:
			(skill_value as Dictionary)[key] = value
			return


func _find_entry_rect(entries: Array, rects: Array, skill_id: String) -> Rect2:
	for index in range(mini(entries.size(), rects.size())):
		if entries[index] is Dictionary and str((entries[index] as Dictionary).get("id", "")) == skill_id:
			return _as_rect2(rects[index])
	return Rect2()


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
	var bounds := _clamp_rect_to_image(rect, first)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return 0.0
	var step_x := maxi(1, int(bounds.size.x / 36.0))
	var step_y := maxi(1, int(bounds.size.y / 18.0))
	var total := 0.0
	var count := 0
	for y in range(int(bounds.position.y), int(bounds.end.y), step_y):
		for x in range(int(bounds.position.x), int(bounds.end.x), step_x):
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			total += (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) / 3.0
			count += 1
	return total / maxf(1.0, float(count))


func _max_rgb_difference(first: Image, second: Image, rect: Rect2) -> float:
	var bounds := _clamp_rect_to_image(rect, first)
	var maximum := 0.0
	for y in range(int(bounds.position.y), int(bounds.end.y)):
		for x in range(int(bounds.position.x), int(bounds.end.x)):
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			maximum = maxf(maximum, (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) / 3.0)
	return maximum


func _clamp_rect_to_image(rect: Rect2, image: Image) -> Rect2:
	var start := Vector2(
		clampf(floorf(rect.position.x), 0.0, float(image.get_width())),
		clampf(floorf(rect.position.y), 0.0, float(image.get_height()))
	)
	var finish := Vector2(
		clampf(ceilf(rect.end.x), start.x, float(image.get_width())),
		clampf(ceilf(rect.end.y), start.y, float(image.get_height()))
	)
	return Rect2(start, finish - start)


func _wait_frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _as_rect2(value: Variant) -> Rect2:
	if value is Rect2:
		return value
	return Rect2()


func _finish(ok_message: String) -> void:
	if _failures.is_empty():
		print(ok_message)
		for path in _saved_paths:
			print("runtime_probe=%s" % path)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
