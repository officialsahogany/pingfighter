extends SceneTree

const VictoryLootPhaseState := preload("res://scripts/core/victory_loot_phase_state.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const GAME_SIZE := Vector2(760.0, 750.0)
const OUTPUT_DIR := "res://../tmp/victory_loot_box_hwangyeokjeon"
const BOX_PATHS := [
	"res://assets/sprites/result_boxes/result_box_common_open_16f.png",
	"res://assets/sprites/result_boxes/result_box_mythic_open_16f.png",
	"res://assets/sprites/result_boxes/result_box_guaranteed_mythic_open_16f.png",
]
const BOX_KINDS := ["normal", "advanced", "guaranteed_mythic"]


class CaptureCanvas:
	extends Node2D

	var phase: String
	var open_progress: float
	var box_y: float
	var state: Object = VictoryLootPhaseState.new()

	func _init(new_phase: String, new_open_progress: float, new_box_y: float) -> void:
		phase = new_phase
		open_progress = new_open_progress
		box_y = new_box_y
		state.active = true
		state.elapsed_sec = 2.35
		state.boxes = []
		for index in range(BOX_KINDS.size()):
			state.boxes.append({
				"kind": BOX_KINDS[index],
				"phase": phase,
				"pos": Vector2(170.0 + float(index) * 210.0, box_y),
				"sway_phase": float(index) * 0.8,
				"open_progress": open_progress,
			})

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, GAME_SIZE), Color("111925"))
		for stripe_index in range(9):
			var stripe_y := 52.0 + float(stripe_index) * 74.0
			draw_line(Vector2(0.0, stripe_y), Vector2(GAME_SIZE.x, stripe_y), Color(0.77, 0.61, 0.27, 0.08), 1.0)
		draw_line(Vector2(22.0, 720.0), Vector2(738.0, 720.0), Color(0.90, 0.69, 0.30, 0.34), 2.0)
		draw_rect(Rect2(302.5, 716.0, 155.0, 24.0), Color(0.24, 0.53, 0.63, 0.9))
		state.draw(self)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		push_error("victory loot-box visual QA requires a windowed renderer")
		quit(1)
		return
	for path_value: Variant in BOX_PATHS:
		var path := str(path_value)
		if ProjectResourceLoader.load_texture(path) == null:
			push_error("victory loot-box texture failed to load: %s" % path)
			quit(1)
			return
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(output_dir)
	await _capture("drop", "drop", 0.0, 330.0, output_dir)
	await _capture("rest_closed", "rest", 0.0, 682.0, output_dir)
	await _capture("opening_mid", "opening", 0.55, 682.0, output_dir)
	await _capture("opening_final", "opening", 0.999, 682.0, output_dir)
	print("victory_loot_box_hwangyeokjeon_visual_qa: %s" % output_dir)
	print("victory_loot_box_hwangyeokjeon_visual_qa: ok")
	quit(0)


func _capture(name_suffix: String, phase: String, open_progress: float, box_y: float, output_dir: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(int(GAME_SIZE.x), int(GAME_SIZE.y))
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var canvas := CaptureCanvas.new(phase, open_progress, box_y)
	viewport.add_child(canvas)
	canvas.queue_redraw()
	for _frame_index in range(6):
		await process_frame
	var image: Image = viewport.get_texture().get_image()
	var output_path := "%s/%s.png" % [output_dir, name_suffix]
	var save_error: Error = image.save_png(output_path)
	if save_error != OK:
		push_error("victory loot-box capture save failed (%d): %s" % [save_error, output_path])
		quit(1)
		return
	print("[VictoryLootBoxCapture] %s" % output_path)
	get_root().remove_child(viewport)
	viewport.queue_free()
	await process_frame
