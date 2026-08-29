extends SceneTree

const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const SmasherSkillOrbSlotRenderer := preload("res://scripts/hud/smasher_skill_orb_slot_renderer.gd")
const SmasherSkillOrbTooltipRenderer := preload("res://scripts/hud/smasher_skill_orb_tooltip_renderer.gd")
const YeonmyoVisionChosikRenderer := preload("res://scripts/characters/yeonmyo_vision_chosik_renderer.gd")

const VIEW_SIZE := Vector2i(1100, 750)
const CAPTURE_PATH := "res://.tmp/yeonmyo_vision_bonghongwe_visual_qa.png"
const TRANSFORM_PROBE_OFFSET := Vector2(80.0, 40.0)
const TRANSFORM_PROBE_SCALE := Vector2(1.2, 1.2)
const TRANSFORM_SENTINEL_LOCAL_CENTER := Vector2(500.0, 500.0)
const TRANSFORM_SENTINEL_EXPECTED_PIXEL := Vector2i(680, 640)
const TRANSFORM_SENTINEL_UNTRANSFORMED_PIXEL := Vector2i(500, 500)
const TRANSFORM_SENTINEL_COLOR := Color(1.0, 0.02, 0.82, 1.0)


class VisionProbe:
	extends Node2D
	var effect_renderer: Object = YeonmyoVisionChosikRenderer.new()
	var orb_renderer: Object = SmasherSkillOrbSlotRenderer.new()
	var tooltip_renderer: Object = SmasherSkillOrbTooltipRenderer.new()
	var perk_icon_renderer: Object = RuntimePerkIconRenderer.new()
	var draw_completed := false
	var manual_draw_completed := false

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color(0.025, 0.018, 0.032), true)
		draw_rect(Rect2(Vector2(760.0, 0.0), Vector2(340.0, 750.0)), Color(0.020, 0.026, 0.045), true)
		draw_line(Vector2(760.0, 0.0), Vector2(760.0, 750.0), Color(0.72, 0.40, 0.84, 0.36), 2.0)
		for y in range(90, 750, 90):
			draw_line(Vector2(0.0, float(y)), Vector2(760.0, float(y)), Color(0.62, 0.34, 0.72, 0.08), 1.0)

		var manual_rect := Rect2(Vector2(22.0, 24.0), Vector2(150.0, 150.0))
		draw_rect(manual_rect.grow(4.0), Color(0.64, 0.32, 0.78, 0.18), true)
		draw_rect(manual_rect, Color(0.04, 0.02, 0.07, 0.96), true)
		manual_draw_completed = perk_icon_renderer.draw_icon(
			self,
			CommonSkillCatalog.YEONMYO_VISION_BONGHONGWE_UNLOCK_ID,
			manual_rect.grow(-8.0),
			1.0,
			true
		)

		var boss_rect := Rect2(Vector2(410.0, 44.0), Vector2(100.0, 40.0))
		draw_rect(boss_rect, Color(0.20, 0.12, 0.25), true)
		draw_rect(boss_rect, Color(0.84, 0.62, 0.92), false, 3.0)
		for trail_index in range(5):
			var x := 392.0 - float(trail_index) * 28.0
			draw_line(Vector2(x, 64.0), Vector2(x + 20.0, 64.0), Color(0.72, 0.36, 0.86, 0.58 - float(trail_index) * 0.08), 4.0, true)

		effect_renderer.draw(self, {
			"phase": "open",
			"chest_pos": Vector2(380.0, 64.0),
			"landing_elapsed": 0.34,
			"landing_settle_duration": 0.34,
			"smoke_elapsed": 1.4,
			"smoke_emit_duration": 3.0,
			"smoke_fade_duration": 2.0,
			"visual_time": 1.4,
		}, Vector2.ZERO)
		draw_string(ThemeDB.fallback_font, Vector2(274.0, 178.0), "대시 교차 → 3초 혼란", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(0.93, 0.78, 0.98))

		# A detached moving shadow plus vertical height/rotation should read as a
		# thrown heavy prop. There is deliberately no player-to-chest tether.
		effect_renderer.draw(self, {
			"phase": "throw",
			"chest_pos": Vector2(250.0, 430.0),
			"throw_ground_pos": Vector2(250.0, 545.0),
			"throw_height": 115.0,
			"throw_rotation": 2.35,
			"throw_scale": 1.09,
		}, Vector2.ZERO)
		draw_rect(Rect2(Vector2(290.0, 650.0), Vector2(150.0, 48.0)), Color(0.18, 0.12, 0.24), true)
		draw_rect(Rect2(Vector2(290.0, 650.0), Vector2(150.0, 48.0)), Color(0.80, 0.58, 0.88), false, 3.0)

		var orb_positions: Array[Vector2] = [Vector2(700.0, 690.0)]
		orb_renderer.draw(self, Vector2(700.0, 690.0), 31.0, orb_positions, 1.2, 1.0, {
			"equipped_skills": [CommonSkillCatalog.YEONMYO_VISION_BONGHONGWE_ID],
			"special_gauge": 260.0,
			"skill_costs": {CommonSkillCatalog.YEONMYO_VISION_BONGHONGWE_ID: 200.0},
			"skill_colors": {CommonSkillCatalog.YEONMYO_VISION_BONGHONGWE_ID: CommonSkillCatalog.YEONMYO_VISION_BONGHONGWE_COLOR},
			"skill_icons": {},
			"cooldown_seconds": {CommonSkillCatalog.YEONMYO_VISION_BONGHONGWE_ID: 35.0},
			"skill_cooldown_remaining_ratios": {CommonSkillCatalog.YEONMYO_VISION_BONGHONGWE_ID: 0.0},
			"skill_ready_overrides": {CommonSkillCatalog.YEONMYO_VISION_BONGHONGWE_ID: true},
			"pillar_hud_static_lod": true,
		})
		tooltip_renderer._draw_tooltip(self, {
			"scale_factor": 1.0,
			"view_size": Vector2(VIEW_SIZE),
			"game_offset": Vector2(780.0, 0.0),
			"mouse_pos": Vector2(950.0, 375.0),
			"selected_character_type": "smasher",
			"special_gauge": 260.0,
			"skill_cooldown_remaining_ratios": {CommonSkillCatalog.YEONMYO_VISION_BONGHONGWE_ID: 0.28},
		}, CommonSkillCatalog.get_skill_data(CommonSkillCatalog.YEONMYO_VISION_BONGHONGWE_ID))

		# Pixel regression probe for the production nesting contract. The sentinel
		# is deliberately drawn after the renderer while a parent transform is
		# active. A renderer-side identity reset moves it to (500, 500).
		draw_set_transform(TRANSFORM_PROBE_OFFSET, 0.0, TRANSFORM_PROBE_SCALE)
		effect_renderer.draw(self, {
			"phase": "closed",
			"chest_pos": Vector2(440.0, 470.0),
			"landing_elapsed": 0.34,
			"landing_settle_duration": 0.34,
		}, Vector2.ZERO)
		draw_rect(
			Rect2(TRANSFORM_SENTINEL_LOCAL_CENTER - Vector2(5.0, 5.0), Vector2(10.0, 10.0)),
			TRANSFORM_SENTINEL_COLOR,
			true
		)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_completed = true


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.tmp"))
	if DisplayServer.get_name().to_lower().contains("headless"):
		print("yeonmyo_vision_bonghongwe_visual_qa: screenshot skipped under headless display server")
		print("yeonmyo_vision_bonghongwe_visual_qa: ok")
		quit(0)
		return
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	var probe := VisionProbe.new()
	viewport.add_child(probe)
	probe.queue_redraw()
	for _frame_index in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	if not probe.draw_completed or not probe.manual_draw_completed:
		push_error("Yeonmyo Vision production render did not complete")
		quit(1)
		return
	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Yeonmyo Vision visual QA capture failed")
		quit(1)
		return
	if not _is_transform_sentinel(image.get_pixelv(TRANSFORM_SENTINEL_EXPECTED_PIXEL)):
		push_error("Yeonmyo Vision renderer replaced the parent playfield transform")
		quit(1)
		return
	if _is_transform_sentinel(image.get_pixelv(TRANSFORM_SENTINEL_UNTRANSFORMED_PIXEL)):
		push_error("Yeonmyo Vision transform sentinel leaked into untransformed coordinates")
		quit(1)
		return
	if image.save_png(CAPTURE_PATH) != OK:
		push_error("Yeonmyo Vision visual QA capture failed")
		quit(1)
		return
	print("yeonmyo_vision_bonghongwe_visual_qa: ok")
	print(ProjectSettings.globalize_path(CAPTURE_PATH))
	quit(0)


func _is_transform_sentinel(color: Color) -> bool:
	return color.r > 0.85 and color.g < 0.20 and color.b > 0.65 and color.a > 0.90
