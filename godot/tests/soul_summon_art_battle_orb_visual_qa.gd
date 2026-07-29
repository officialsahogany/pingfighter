extends SceneTree

const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")
const SmasherSkillOrbSlotRenderer := preload("res://scripts/hud/smasher_skill_orb_slot_renderer.gd")

const VIEW_SIZE := Vector2i(160, 160)
const CAPTURE_PATH := "res://.tmp/soul_summon_art_battle_orb_qa.png"
const ORB_CENTER := Vector2(80.0, 80.0)


class OrbProbe:
	extends Node2D

	var renderer: Object = SmasherSkillOrbSlotRenderer.new()
	var draw_completed := false

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color(0.015, 0.025, 0.055), true)
		var positions: Array[Vector2] = [ORB_CENTER]
		renderer.draw(self, ORB_CENTER, 32.0, positions, 0.0, 1.0, {
			"equipped_skills": [CommonSkillCatalog.SOUL_SUMMON_ART_ID],
			"special_gauge": 500.0,
			"skill_costs": {CommonSkillCatalog.SOUL_SUMMON_ART_ID: 0.0},
			"skill_colors": {CommonSkillCatalog.SOUL_SUMMON_ART_ID: CommonSkillCatalog.SOUL_SUMMON_ART_COLOR},
			# Empty on purpose: this is the live Optimus/Blacksmith route and the
			# safety leg for a character texture map that has not landed yet.
			"skill_icons": {},
			"cooldown_seconds": {CommonSkillCatalog.SOUL_SUMMON_ART_ID: 0.0},
			"pillar_hud_static_lod": true,
		})
		draw_completed = true


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_dir := ProjectSettings.globalize_path("res://.tmp")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var probe := OrbProbe.new()
	var capture_viewport := SubViewport.new()
	capture_viewport.size = VIEW_SIZE
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	capture_viewport.transparent_bg = false
	get_root().add_child(capture_viewport)
	capture_viewport.add_child(probe)
	probe.queue_redraw()
	for _frame_index in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	if not probe.draw_completed:
		push_error("Soul Summoning Art battle-orb production draw must complete")
		quit(1)
		return
	var image := capture_viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(CAPTURE_PATH) != OK:
		push_error("Soul Summoning Art battle-orb visual QA capture must save")
		quit(1)
		return
	probe.queue_free()
	capture_viewport.queue_free()
	await process_frame
	print("soul_summon_art_battle_orb_visual_qa: ok")
	print(ProjectSettings.globalize_path(CAPTURE_PATH))
	quit(0)
