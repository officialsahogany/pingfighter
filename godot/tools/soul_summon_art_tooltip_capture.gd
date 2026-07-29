extends SceneTree

# Windowed Vulkan proof for the production Chosik tooltip renderer. The capture
# uses CommonSkillCatalog metadata and the shared renderer instead of a hand-
# drawn facsimile, so the Ctrl/R3 keycaps and activation accent stay sealed to
# the live tooltip path.

const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")
const SmasherSkillOrbTooltipRenderer := preload("res://scripts/hud/smasher_skill_orb_tooltip_renderer.gd")

const VIEW_SIZE := Vector2i(420, 420)
const OUT_PATH := "D:/tmp/bosspong_guardian_transition_qa/soul_summon_art_tooltip.png"


class TooltipCanvas:
	extends Node2D

	var tooltip_renderer: Object

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color(0.035, 0.055, 0.085), true)
		var hover_context := {
			"scale_factor": 1.0,
			"view_size": Vector2(VIEW_SIZE),
			"game_offset": Vector2.ZERO,
			"mouse_pos": Vector2(210.0, 210.0),
			"selected_character_type": "smasher",
		}
		tooltip_renderer._draw_tooltip(self, hover_context, CommonSkillCatalog.get_skill_data())


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("soul_summon_art_tooltip_capture requires a windowed renderer")
		quit(1)
		return
	if RenderingServer.get_current_rendering_method() != "mobile":
		push_error("Vulkan mobile renderer required")
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(OUT_PATH.get_base_dir()) != OK:
		push_error("failed to create capture directory")
		quit(1)
		return

	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas := TooltipCanvas.new()
	canvas.tooltip_renderer = SmasherSkillOrbTooltipRenderer.new()
	viewport.add_child(canvas)
	for _frame_index in range(3):
		canvas.queue_redraw()
		await process_frame
	await RenderingServer.frame_post_draw

	var rows: Array = canvas.tooltip_renderer._get_control_rows(CommonSkillCatalog.SOUL_SUMMON_ART_ID, "smasher")
	if rows.size() != 1 or (rows[0] as Array).size() != 5 or (rows[0] as Array)[-1] != ["accent", "발동"]:
		push_error("production Soul Summoning Art control row is incomplete")
		quit(1)
		return
	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(OUT_PATH) != OK:
		push_error("failed to save tooltip capture")
		quit(1)
		return
	print("[SoulSummonTooltipCapture] %s" % OUT_PATH)
	quit(0)
