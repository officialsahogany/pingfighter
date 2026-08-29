extends SceneTree

const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const VictoryLootPhaseState := preload("res://scripts/core/victory_loot_phase_state.gd")

const VIEW_SIZE := Vector2i(760, 360)
const CAPTURE_PATH := "res://.tmp/dalji_vision_reward_box_visual_qa.png"


class VisionBoxProbe:
	extends Node2D

	var loot_state: Object = VictoryLootPhaseState.new()
	var draw_completed := false

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color(0.015, 0.027, 0.044), true)
		for y in range(40, VIEW_SIZE.y, 64):
			draw_line(Vector2(0.0, float(y)), Vector2(float(VIEW_SIZE.x), float(y)), Color(0.30, 0.70, 0.68, 0.055), 1.0)
		for x in range(72, VIEW_SIZE.x, 96):
			draw_line(Vector2(float(x), 0.0), Vector2(float(x), float(VIEW_SIZE.y)), Color(0.30, 0.70, 0.68, 0.04), 1.0)

		var samples := [
			{"pos": Vector2(145.0, 176.0), "phase": "rest", "open_progress": 0.0},
			{"pos": Vector2(380.0, 176.0), "phase": "opening", "open_progress": 0.52},
			{"pos": Vector2(615.0, 176.0), "phase": "opening", "open_progress": 0.99},
		]
		for sample_value: Variant in samples:
			var sample := sample_value as Dictionary
			var box := {
				"kind": "normal",
				"pos": sample.get("pos", Vector2.ZERO),
				"sway_phase": 0.0,
				"open_progress": float(sample.get("open_progress", 0.0)),
				"boss_vision_offer_id": CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_UNLOCK_ID,
			}
			loot_state._draw_box(self, box, str(sample.get("phase", "rest")), Vector2.ZERO)
		draw_completed = true


func _init() -> void:
	ProjectResourceLoader.load_imported_texture(
		VictoryLootPhaseState.DALJI_VISION_BOX_SHEET_PATH,
		"Missing Dalji Vision reward box sheet at %s",
		"Failed to load Dalji Vision reward box sheet at %s"
	)
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	var probe := VisionBoxProbe.new()
	viewport.add_child(probe)
	probe.queue_redraw()
	for _frame_index in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	if not probe.draw_completed:
		push_error("Dalji Vision reward box production render did not complete")
		quit(1)
		return
	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(CAPTURE_PATH) != OK:
		push_error("Dalji Vision reward box visual QA capture failed")
		quit(1)
		return
	print("dalji_vision_reward_box_visual_qa: ok")
	print(ProjectSettings.globalize_path(CAPTURE_PATH))
	quit(0)
