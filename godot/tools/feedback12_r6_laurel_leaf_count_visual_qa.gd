extends SceneTree

const LaurelLeafShieldState := preload(
	"res://scripts/characters/laurel_leaf_shield_state.gd"
)

const VIEW_SIZE := Vector2i(2020, 1246)
const SHIELD_CENTER := Vector2(1010.0, 623.0)
const CAPTURE_CASES := [
	{"rank": 1, "logical": 1, "display": 1},
	{"rank": 2, "logical": 3, "display": 2},
	{"rank": 3, "logical": 5, "display": 3},
]


class CaptureCanvas:
	extends Node2D

	var logical_leaf_count := 1
	var state: Object = null

	func _ready() -> void:
		seed(0x6A17E1)
		state = LaurelLeafShieldState.new()
		state.activate(logical_leaf_count)
		state.owner_center = SHIELD_CENTER

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color(0.025, 0.035, 0.055), true)
		for y in range(0, VIEW_SIZE.y, 42):
			draw_rect(
				Rect2(0.0, float(y), float(VIEW_SIZE.x), 20.0),
				Color(0.09, 0.12, 0.17, 0.09),
				true
			)
		draw_circle(SHIELD_CENTER, 76.0, Color(0.08, 0.10, 0.14, 0.96))
		state.draw(self, Vector2.ZERO, 0.0)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("feedback12 R6 visual QA requires a windowed Vulkan renderer")
		quit(1)
		return
	if RenderingServer.get_current_rendering_method() != "mobile":
		push_error("feedback12 R6 visual QA requires the mobile rendering method")
		quit(1)
		return
	var output_dir := ProjectSettings.globalize_path(
		"res://.godot/codex_artifacts/feedback12_r6_laurel_leaf_count"
	)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="):
			output_dir = argument.substr("--output-dir=".length())
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		push_error("failed to create feedback12 R6 capture directory: %s" % output_dir)
		quit(1)
		return

	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var gold_pixel_counts: Array[int] = []
	for case_value in CAPTURE_CASES:
		var case_data: Dictionary = case_value
		var image := await _capture_case(viewport, int(case_data.get("logical", 0)))
		if image == null:
			viewport.queue_free()
			quit(1)
			return
		var display_count := int(case_data.get("display", 0))
		var capture_path := output_dir.path_join(
			"feedback12_r6_rank_%d_leaves_%d_2020x1246.png" % [
				int(case_data.get("rank", 0)),
				display_count,
			]
		)
		if image.save_png(capture_path) != OK:
			push_error("failed to save feedback12 R6 capture: %s" % capture_path)
			viewport.queue_free()
			quit(1)
			return
		gold_pixel_counts.append(_count_gold_pixels(image))
	if (
		gold_pixel_counts.size() != 3
		or gold_pixel_counts[1] <= gold_pixel_counts[0] * 1.35
		or gold_pixel_counts[2] <= gold_pixel_counts[1] * 1.18
	):
		push_error("Laurel 1/2/3 presentation did not produce increasing leaf silhouettes: %s" % str(gold_pixel_counts))
		viewport.queue_free()
		quit(1)
		return
	print("feedback12_r6_laurel_leaf_count_visual_qa: gold_pixels=%s" % str(gold_pixel_counts))
	print("feedback12_r6_laurel_leaf_count_visual_qa: captures=3")
	print("feedback12_r6_laurel_leaf_count_visual_qa: output_dir=%s" % output_dir)
	print("feedback12_r6_laurel_leaf_count_visual_qa: ok")
	viewport.queue_free()
	quit(0)


func _capture_case(viewport: SubViewport, logical_leaf_count: int) -> Image:
	var canvas := CaptureCanvas.new()
	canvas.logical_leaf_count = logical_leaf_count
	viewport.add_child(canvas)
	canvas.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.remove_child(canvas)
	canvas.queue_free()
	await process_frame
	return image


func _count_gold_pixels(image: Image) -> int:
	var count := 0
	for y in range(int(SHIELD_CENTER.y - 95.0), int(SHIELD_CENTER.y + 95.0) + 1):
		for x in range(int(SHIELD_CENTER.x - 245.0), int(SHIELD_CENTER.x + 245.0) + 1):
			var color := image.get_pixel(x, y)
			if (
				color.r >= 0.24
				and color.g >= 0.16
				and color.r >= color.b * 1.45
				and color.g >= color.b * 1.18
			):
				count += 1
	return count
