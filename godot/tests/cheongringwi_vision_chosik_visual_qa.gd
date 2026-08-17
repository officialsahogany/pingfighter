extends SceneTree

const CheongringwiVisionChosikRenderer := preload("res://scripts/characters/cheongringwi_vision_chosik_renderer.gd")
const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const SmasherSkillOrbSlotRenderer := preload("res://scripts/hud/smasher_skill_orb_slot_renderer.gd")
const SmasherSkillOrbTooltipRenderer := preload("res://scripts/hud/smasher_skill_orb_tooltip_renderer.gd")
const Stage2PillarAssets := preload("res://scripts/stages/stage2/stage2_pillar_assets.gd")
const Stage2QuakeCoordinator := preload("res://scripts/stages/stage2/stage2_quake_coordinator.gd")

const VIEW_SIZE := Vector2i(1100, 750)
const CAPTURE_PATH := "res://.tmp/cheongringwi_vision_chosik_visual_qa.png"


class VisionProbe:
	extends Node2D

	var effect_renderer: Object = CheongringwiVisionChosikRenderer.new()
	var orb_renderer: Object = SmasherSkillOrbSlotRenderer.new()
	var tooltip_renderer: Object = SmasherSkillOrbTooltipRenderer.new()
	var perk_icon_renderer: Object = RuntimePerkIconRenderer.new()
	var rock_texture: Texture2D = ProjectResourceLoader.load_texture(Stage2PillarAssets.ROCK_TEXTURE_PATH)
	var rock_debris_texture: Texture2D = ProjectResourceLoader.load_texture(Stage2PillarAssets.ROCK_DEBRIS_TEXTURE_PATH)
	var draw_completed := false
	var manual_draw_completed := false

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color(0.035, 0.030, 0.020), true)
		draw_rect(Rect2(Vector2(760.0, 0.0), Vector2(340.0, 750.0)), Color(0.018, 0.026, 0.046), true)
		draw_line(Vector2(760.0, 0.0), Vector2(760.0, 750.0), Color(0.84, 0.68, 0.22, 0.34), 2.0)
		for y in range(70, VIEW_SIZE.y, 80):
			draw_line(Vector2(0.0, float(y)), Vector2(760.0, float(y)), Color(0.74, 0.66, 0.28, 0.09), 1.0)

		var manual_rect := Rect2(Vector2(22.0, 24.0), Vector2(164.0, 164.0))
		draw_rect(manual_rect.grow(4.0), Color(0.78, 0.68, 0.26, 0.18), true)
		draw_rect(manual_rect, Color(0.018, 0.050, 0.082, 0.96), true)
		manual_draw_completed = perk_icon_renderer.draw_icon(
			self,
			CommonSkillCatalog.CHEONGRINGWI_VISION_DRAGON_TORRENT_UNLOCK_ID,
			manual_rect.grow(-8.0),
			1.0,
			true
		)

		var boss_rect := Rect2(Vector2(315.0, 72.0), Vector2(130.0, 44.0))
		draw_rect(boss_rect.grow(7.0), Color(0.20, 0.75, 1.0, 0.16), true)
		draw_rect(boss_rect, Color(0.06, 0.16, 0.24), true)
		draw_rect(boss_rect, Color(0.34, 0.88, 1.0), false, 3.0)
		var player_rect := Rect2(Vector2(302.5, 686.0), Vector2(155.0, 50.0))
		draw_rect(player_rect, Color(0.04, 0.18, 0.29), true)
		draw_rect(player_rect, Color(0.56, 0.96, 1.0), false, 3.0)

		effect_renderer.draw(self, {
			"phase": "quake",
			"quake_timer": 0.82,
			"quake_duration": Stage2QuakeCoordinator.DEFAULT_DURATION_SEC,
			"width": 760.0,
			"height": 750.0,
			"rock_texture": rock_texture,
			"rock_source_regions": Stage2PillarAssets.ROCK_SOURCE_REGION_DATA,
			"rock_debris_texture": rock_debris_texture,
			"rock_debris_source_regions": Stage2PillarAssets.ROCK_DEBRIS_SOURCE_REGION_DATA,
			"rock_fragment_life_sec": 45.0 / 60.0,
			"rocks": [
				{"pos": Vector2(105.0, 190.0), "target_pos": Vector2(105.0, 420.0), "drop_delay": 0.0, "falling": true, "fall_progress": 0.48, "shadow_scale": 0.58, "radius": 30.0, "visual_radius": 38.0, "rock_seed": 22070, "style_type": "dark_granite"},
				{"pos": Vector2(225.0, 310.0), "target_pos": Vector2(225.0, 310.0), "drop_delay": 0.0, "falling": false, "shadow_scale": 1.0, "radius": 29.0, "visual_radius": 36.0, "rock_seed": 22207, "style_type": "reddish_stone", "flash": 0.18},
				{"pos": Vector2(344.0, 128.0), "target_pos": Vector2(344.0, 520.0), "drop_delay": 0.0, "falling": true, "fall_progress": 0.30, "shadow_scale": 0.44, "radius": 34.0, "visual_radius": 42.0, "rock_seed": 22344, "style_type": "yellowish_stone"},
				{"pos": Vector2(580.0, 246.0), "target_pos": Vector2(580.0, 586.0), "drop_delay": 0.0, "falling": true, "fall_progress": 0.58, "shadow_scale": 0.66, "radius": 31.0, "visual_radius": 39.0, "rock_seed": 22618, "style_type": "gray_stone"},
			],
			"rock_fragments": [
				{"pos": Vector2(456.0, 432.0), "size": 9.0, "life": 0.70, "max_life": 0.75, "rotation": 0.18, "sprite_index": 1},
				{"pos": Vector2(473.0, 422.0), "size": 7.0, "life": 0.67, "max_life": 0.75, "rotation": 0.82, "sprite_index": 3},
				{"pos": Vector2(490.0, 438.0), "size": 10.0, "life": 0.64, "max_life": 0.75, "rotation": 1.24, "sprite_index": 5},
				{"pos": Vector2(442.0, 450.0), "size": 6.0, "life": 0.61, "max_life": 0.75, "rotation": 1.78, "sprite_index": 8},
				{"pos": Vector2(479.0, 457.0), "size": 8.0, "life": 0.58, "max_life": 0.75, "rotation": 2.18, "sprite_index": 11},
				{"pos": Vector2(504.0, 459.0), "size": 6.0, "life": 0.55, "max_life": 0.75, "rotation": 2.64, "sprite_index": 14},
			],
			"impacts": [
				{"pos": Vector2(470.0, 445.0), "radius": 44.0, "life": 0.29, "max_life": 0.34},
			],
		}, Vector2.ZERO)
		var ball_pos := Vector2(460.0, 406.0)
		draw_circle(ball_pos, 14.3, Color(0.97, 0.99, 1.0))
		draw_line(ball_pos, ball_pos + Vector2(-14.0, -58.0), Color(0.92, 0.76, 0.30, 0.92), 3.0, true)

		var orb_positions: Array[Vector2] = [Vector2(700.0, 690.0)]
		orb_renderer.draw(self, Vector2(700.0, 690.0), 31.0, orb_positions, 1.27, 1.0, {
			"equipped_skills": [CommonSkillCatalog.CHEONGRINGWI_VISION_DRAGON_TORRENT_ID],
			"special_gauge": 300.0,
			"skill_costs": {CommonSkillCatalog.CHEONGRINGWI_VISION_DRAGON_TORRENT_ID: 250.0},
			"skill_colors": {CommonSkillCatalog.CHEONGRINGWI_VISION_DRAGON_TORRENT_ID: CommonSkillCatalog.CHEONGRINGWI_VISION_DRAGON_TORRENT_COLOR},
			"skill_icons": {},
			"cooldown_seconds": {CommonSkillCatalog.CHEONGRINGWI_VISION_DRAGON_TORRENT_ID: 40.0},
			"skill_cooldown_remaining_ratios": {CommonSkillCatalog.CHEONGRINGWI_VISION_DRAGON_TORRENT_ID: 0.0},
			"skill_ready_overrides": {CommonSkillCatalog.CHEONGRINGWI_VISION_DRAGON_TORRENT_ID: true},
			"pillar_hud_static_lod": true,
		})
		tooltip_renderer._draw_tooltip(self, {
			"scale_factor": 1.0,
			"view_size": Vector2(VIEW_SIZE),
			"game_offset": Vector2(780.0, 0.0),
			"mouse_pos": Vector2(950.0, 375.0),
			"selected_character_type": "smasher",
			"special_gauge": 300.0,
			"skill_cooldown_remaining_ratios": {CommonSkillCatalog.CHEONGRINGWI_VISION_DRAGON_TORRENT_ID: 0.36},
		}, CommonSkillCatalog.get_skill_data(CommonSkillCatalog.CHEONGRINGWI_VISION_DRAGON_TORRENT_ID))
		draw_completed = true


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.tmp"))
	if DisplayServer.get_name().to_lower().contains("headless"):
		print("cheongringwi_vision_chosik_visual_qa: screenshot skipped under headless display server")
		print("cheongringwi_vision_chosik_visual_qa: ok")
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
		push_error("Cheongringwi Vision Chosik production render did not complete")
		quit(1)
		return
	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(CAPTURE_PATH) != OK:
		push_error("Cheongringwi Vision Chosik visual QA capture failed")
		quit(1)
		return
	print("cheongringwi_vision_chosik_visual_qa: ok")
	print(ProjectSettings.globalize_path(CAPTURE_PATH))
	quit(0)
