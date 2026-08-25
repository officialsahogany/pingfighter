extends SceneTree

const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")
const GaksitalVisionChosikState := preload("res://scripts/characters/gaksital_vision_chosik_state.gd")
const Stage1GaksitalFanProjectileContract := preload(
	"res://scripts/stages/stage1/stage1_gaksital_fan_projectile_contract.gd"
)
const Stage1BossActorRenderer := preload(
	"res://scripts/stages/stage1/stage1_boss_actor_renderer.gd"
)
const StatusEffectState := preload("res://scripts/status/status_effect_state.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const SmasherSkillOrbSlotRenderer := preload(
	"res://scripts/hud/smasher_skill_orb_slot_renderer.gd"
)
const SmasherSkillOrbTooltipRenderer := preload(
	"res://scripts/hud/smasher_skill_orb_tooltip_renderer.gd"
)

const VIEW_SIZE := Vector2i(1100, 750)
const CAPTURE_PATH := "res://.tmp/gaksital_vision_fan_throw_visual_qa.png"
const BOSS_POS := Vector2(330.0, 58.0)
const BOSS_SIZE := Vector2(100.0, 40.0)


class VisionProbe:
	extends Node2D

	var vision_state: Object = GaksitalVisionChosikState.new()
	var boss_renderer: Object = Stage1BossActorRenderer.new()
	var status_state: Object = StatusEffectState.new()
	var orb_renderer: Object = SmasherSkillOrbSlotRenderer.new()
	var tooltip_renderer: Object = SmasherSkillOrbTooltipRenderer.new()
	var perk_icon_renderer: Object = RuntimePerkIconRenderer.new()
	var draw_completed := false
	var manual_draw_completed := false

	func _init() -> void:
		var projectile_texture := ProjectResourceLoader.load_texture(
			Stage1GaksitalFanProjectileContract.PROJECTILE_TEXTURE_PATH
		)
		vision_state.set_projectile_texture_for_tests(projectile_texture)
		vision_state.fans = [
			_build_fan(Vector2(380.0, 575.0), -0.36),
			_build_fan(Vector2(378.0, 405.0), 0.42),
			_build_fan(Vector2(382.0, 238.0), 1.16),
		]
		vision_state.hit_effect_timer = 15.0
		vision_state.hit_effect_pos = Vector2(380.0, 104.0)
		status_state.apply_status(
			"boss",
			"stun",
			Stage1GaksitalFanProjectileContract.STUN_FRAMES,
			Stage1GaksitalFanProjectileContract.build_boss_stun_status_data(
				Stage1GaksitalFanProjectileContract.KNOCKBACK_POWER,
				CommonSkillCatalog.GAKSITAL_VISION_FAN_THROW_ID
			),
			CommonSkillCatalog.GAKSITAL_VISION_FAN_THROW_ID
		)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color(0.025, 0.018, 0.025), true)
		draw_rect(Rect2(Vector2.ZERO, Vector2(760.0, 750.0)), Color(0.085, 0.055, 0.050), true)
		for y in range(70, 750, 85):
			draw_line(Vector2(0.0, float(y)), Vector2(760.0, float(y)), Color(0.90, 0.46, 0.20, 0.09), 1.0)
		for x in range(70, 760, 85):
			draw_line(Vector2(float(x), 0.0), Vector2(float(x), 750.0), Color(0.90, 0.46, 0.20, 0.06), 1.0)
		draw_line(Vector2(760.0, 0.0), Vector2(760.0, 750.0), Color(0.95, 0.62, 0.25, 0.42), 2.0)

		var player_rect := Rect2(Vector2(302.5, 680.0), Vector2(155.0, 50.0))
		draw_rect(player_rect.grow(5.0), Color(1.0, 0.34, 0.18, 0.12), true)
		draw_rect(player_rect, Color(0.23, 0.08, 0.06), true)
		draw_rect(player_rect, CommonSkillCatalog.GAKSITAL_VISION_FAN_THROW_COLOR, false, 3.0)
		vision_state.draw(self)

		var boss_context := {
			"current_stage": 1,
			"stage1_boss_variant": "gaksi",
			"boss_pos": BOSS_POS,
			"boss_paddle_size": BOSS_SIZE,
			"boss_hitbox_height": BOSS_SIZE.y,
			"boss_visual_center_y_offset": 25.0,
			"paddle_hologram_should_draw": true,
			"paddle_hologram_active": false,
		}
		boss_context.merge(status_state.get_actor_draw_context(), true)
		boss_renderer.draw(self, boss_context, Vector2.ZERO)

		var manual_rect := Rect2(Vector2(790.0, 28.0), Vector2(118.0, 118.0))
		draw_rect(manual_rect.grow(5.0), Color(0.95, 0.50, 0.20, 0.22), true)
		draw_rect(manual_rect, Color(0.11, 0.045, 0.035), true)
		manual_draw_completed = perk_icon_renderer.draw_icon(
			self,
			CommonSkillCatalog.GAKSITAL_VISION_FAN_THROW_UNLOCK_ID,
			manual_rect.grow(-9.0),
			1.0,
			true
		)

		var orb_positions: Array[Vector2] = [Vector2(1018.0, 686.0)]
		orb_renderer.draw(self, Vector2(1018.0, 686.0), 31.0, orb_positions, 0.7, 1.0, {
			"equipped_skills": [CommonSkillCatalog.GAKSITAL_VISION_FAN_THROW_ID],
			"special_gauge": 100.0,
			"skill_costs": {CommonSkillCatalog.GAKSITAL_VISION_FAN_THROW_ID: 80.0},
			"skill_colors": {CommonSkillCatalog.GAKSITAL_VISION_FAN_THROW_ID: CommonSkillCatalog.GAKSITAL_VISION_FAN_THROW_COLOR},
			"skill_icons": {},
			"cooldown_seconds": {CommonSkillCatalog.GAKSITAL_VISION_FAN_THROW_ID: 5.0},
			"skill_cooldown_remaining_ratios": {CommonSkillCatalog.GAKSITAL_VISION_FAN_THROW_ID: 0.0},
			"skill_ready_overrides": {CommonSkillCatalog.GAKSITAL_VISION_FAN_THROW_ID: true},
			"pillar_hud_static_lod": true,
		})
		tooltip_renderer._draw_tooltip(self, {
			"scale_factor": 1.0,
			"view_size": Vector2(VIEW_SIZE),
			"game_offset": Vector2(780.0, 0.0),
			"mouse_pos": Vector2(950.0, 390.0),
			"selected_character_type": "smasher",
			"special_gauge": 100.0,
			"skill_cooldown_remaining_ratios": {CommonSkillCatalog.GAKSITAL_VISION_FAN_THROW_ID: 0.0},
		}, CommonSkillCatalog.get_skill_data(CommonSkillCatalog.GAKSITAL_VISION_FAN_THROW_ID))
		draw_completed = true

	func _build_fan(pos: Vector2, spin: float) -> Dictionary:
		var fan := Stage1GaksitalFanProjectileContract.build_projectile(
			pos,
			Vector2.UP
		)
		fan["spin"] = spin
		return fan


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.tmp"))
	if DisplayServer.get_name().to_lower().contains("headless"):
		push_error("Gaksital Vision visual QA requires a non-headless display server")
		quit(1)
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
		push_error("Gaksital Vision production render did not complete")
		quit(1)
		return
	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(CAPTURE_PATH) != OK:
		push_error("Gaksital Vision visual QA capture failed")
		quit(1)
		return
	print("[GaksitalVisionFanThrowVisualSeal] renderer=Vulkan flying_fans=3 boss_stun_stars=3")
	print("gaksital_vision_fan_throw_visual_qa: ok")
	print(ProjectSettings.globalize_path(CAPTURE_PATH))
	quit(0)
