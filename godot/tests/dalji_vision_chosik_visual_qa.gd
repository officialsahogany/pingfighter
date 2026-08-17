extends SceneTree

const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")
const DaljiVisionChosikRenderer := preload("res://scripts/characters/dalji_vision_chosik_renderer.gd")
const SmasherSkillOrbSlotRenderer := preload("res://scripts/hud/smasher_skill_orb_slot_renderer.gd")
const SmasherSkillOrbTooltipRenderer := preload("res://scripts/hud/smasher_skill_orb_tooltip_renderer.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")

const VIEW_SIZE := Vector2i(1100, 750)
const CAPTURE_PATH := "res://.tmp/dalji_vision_chosik_visual_qa.png"


class VisionProbe:
	extends Node2D

	var effect_renderer: Object = DaljiVisionChosikRenderer.new()
	var orb_renderer: Object = SmasherSkillOrbSlotRenderer.new()
	var tooltip_renderer: Object = SmasherSkillOrbTooltipRenderer.new()
	var perk_icon_renderer: Object = RuntimePerkIconRenderer.new()
	var draw_completed := false
	var manual_draw_completed := false

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color(0.018, 0.033, 0.055), true)
		draw_rect(Rect2(Vector2(760.0, 0.0), Vector2(340.0, 750.0)), Color(0.025, 0.029, 0.040), true)
		draw_line(Vector2(760.0, 0.0), Vector2(760.0, 750.0), Color(0.56, 0.93, 0.86, 0.28), 2.0)
		var manual_card_rect := Rect2(Vector2(22.0, 24.0), Vector2(164.0, 164.0))
		draw_rect(manual_card_rect.grow(4.0), Color(0.91, 0.73, 0.30, 0.16), true)
		draw_rect(manual_card_rect, Color(0.025, 0.045, 0.065, 0.96), true)
		manual_draw_completed = perk_icon_renderer.draw_icon(
			self,
			CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_UNLOCK_ID,
			manual_card_rect.grow(-8.0),
			1.0,
			true
		)
		for y in range(70, VIEW_SIZE.y, 80):
			draw_line(Vector2(0.0, float(y)), Vector2(float(VIEW_SIZE.x), float(y)), Color(0.25, 0.53, 0.57, 0.08), 1.0)
		var boss_rect := Rect2(Vector2(315.0, 72.0), Vector2(130.0, 44.0))
		draw_rect(boss_rect.grow(7.0), Color(0.86, 0.67, 0.24, 0.16), true)
		draw_rect(boss_rect, Color(0.16, 0.21, 0.25), true)
		draw_rect(boss_rect, Color(0.91, 0.73, 0.30), false, 3.0)
		var player_rect := Rect2(Vector2(302.5, 686.0), Vector2(155.0, 50.0))
		draw_rect(player_rect, Color(0.09, 0.24, 0.28), true)
		draw_rect(player_rect, Color(0.54, 0.98, 0.91), false, 3.0)
		effect_renderer.draw(self, {
			"cast_remaining": 0.18,
			"player_anchor": Vector2(380.0, 698.0),
			"visual_time": 1.27,
			"active_duration_ratio": 3.4 / 7.0,
			"active_duration_remaining_sec": 3.4,
			"tops": [
				{
					"x": 280.0,
					"y": 418.0,
					"vx": -3.8,
					"vy": -7.0,
					"age": 0.74,
					"lifetime": 7.0,
					"rotation": 148.0,
					"tilt": 0.0,
					"alpha": 255.0,
					"boost_timer": 0.0,
					"is_golden": false,
				},
				{
					"x": 470.0,
					"y": 342.0,
					"vx": 3.8,
					"vy": -6.2,
					"age": 0.92,
					"lifetime": 7.0,
					"rotation": 296.0,
					"tilt": 0.0,
					"alpha": 255.0,
					"boost_timer": 8.0,
					"is_golden": false,
				},
			],
		}, Vector2.ZERO)
		var reflected_ball_pos := Vector2(450.0, 300.0)
		draw_circle(reflected_ball_pos, 14.3, Color(0.96, 0.99, 1.0))
		draw_line(reflected_ball_pos, reflected_ball_pos + Vector2(18.0, -42.0), Color(0.73, 1.0, 0.94, 0.9), 3.0, true)
		var orb_positions: Array[Vector2] = [Vector2(700.0, 690.0)]
		orb_renderer.draw(self, Vector2(700.0, 690.0), 31.0, orb_positions, 1.27, 1.0, {
			"equipped_skills": [CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_ID],
			"special_gauge": 240.0,
			"skill_costs": {CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_ID: CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_COST},
			"skill_colors": {CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_ID: CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_COLOR},
			"skill_icons": {},
			"cooldown_seconds": {CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_ID: CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_COOLDOWN},
			"skill_cooldown_remaining_ratios": {CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_ID: 0.0},
			"skill_ready_overrides": {CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_ID: true},
			"pillar_hud_static_lod": true,
		})
		tooltip_renderer._draw_tooltip(self, {
			"scale_factor": 1.0,
			"view_size": Vector2(VIEW_SIZE),
			"game_offset": Vector2(780.0, 0.0),
			"mouse_pos": Vector2(950.0, 375.0),
			"selected_character_type": "smasher",
			"special_gauge": 240.0,
			"skill_cooldown_remaining_ratios": {CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_ID: 0.36},
		}, CommonSkillCatalog.get_skill_data(CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_ID))
		draw_completed = true


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.tmp"))
	if DisplayServer.get_name().to_lower().contains("headless"):
		print("dalji_vision_chosik_visual_qa: screenshot skipped under headless display server")
		print("dalji_vision_chosik_visual_qa: ok")
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
	if not probe.draw_completed:
		push_error("Dalji Vision Chosik production render did not complete")
		quit(1)
		return
	if not probe.manual_draw_completed:
		push_error("Dalji Vision Chosik manual-book production icon did not render")
		quit(1)
		return
	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(CAPTURE_PATH) != OK:
		push_error("Dalji Vision Chosik visual QA capture failed")
		quit(1)
		return
	print("dalji_vision_chosik_visual_qa: ok")
	print(ProjectSettings.globalize_path(CAPTURE_PATH))
	quit(0)
