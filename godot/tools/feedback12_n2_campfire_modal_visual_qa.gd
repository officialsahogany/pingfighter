extends SceneTree

const ActiveItemRuntime := preload(
	"res://scripts/items/active_item_runtime.gd"
)
const TowerAscentFlowRenderer := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
)
const TowerAscentNodeModalState := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_state.gd"
)
const TowerAscentRestNode := preload(
	"res://scripts/tower_ascent/tower_ascent_rest_node.gd"
)

const VIEW_SIZE := Vector2i(760, 750)
const OUTPUT_DIR := "res://.godot/codex_captures/feedback12_nodes/n2"
const FRAME_NAMES: Array[String] = [
	"dormant_campfire",
	"intro_flame",
	"three_choice_menu",
	"banana_rainbow_result",
]
const MIN_NONBLANK_PIXELS := 100000
const MIN_PAIR_DIFF_PIXELS := 5000
const PIXEL_DELTA_THRESHOLD := 8


class QaRunState:
	extends RefCounted

	func export_economy() -> Dictionary:
		return {"muhon": 4, "gold": 0, "chance_gems": 0}


class QaOwner:
	extends RefCounted
	var active_item_slots: Array[Dictionary] = [{"name": "banana"}]


class QaRegistry:
	extends RefCounted
	var active_item_runtime: Object = ActiveItemRuntime.new()

	func get_instance(key: String) -> Object:
		return active_item_runtime if key == "active_item_runtime" else null

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)


class CaptureFlow:
	extends RefCounted
	var modal_state: Object

	func _init(state_value: Object) -> void:
		modal_state = state_value

	func get_phase_name() -> String:
		return "NODE_MODAL"

	func get_node_modal_view_model(view_size: Vector2) -> Dictionary:
		return modal_state.build_view_model(view_size)

	func get_node_modal_kind() -> String:
		return "rest"

	func get_node_modal_render_context() -> Dictionary:
		return {}


class CaptureCanvas:
	extends Node2D
	var flow: Object
	var renderer := TowerAscentFlowRenderer.new()

	func _init(flow_value: Object) -> void:
		flow = flow_value

	func _draw() -> void:
		renderer.draw_fullscreen_node_modal(
			self,
			flow,
			Rect2(Vector2.ZERO, Vector2(VIEW_SIZE))
		)


var _modal := TowerAscentNodeModalState.new()
var _viewport: SubViewport
var _canvas: CaptureCanvas
var _frames: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		_fail("feedback12_n2_campfire_modal_visual_qa requires a real window")
		return
	if RenderingServer.get_rendering_device() == null:
		_fail("feedback12_n2_campfire_modal_visual_qa requires Vulkan")
		return
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		_fail("N2 campfire capture directory creation failed")
		return

	var rest_node := TowerAscentRestNode.new()
	var run_state := QaRunState.new()
	var owner := QaOwner.new()
	var registry := QaRegistry.new()
	var actions: Array[Dictionary] = rest_node.build_actions(
		"feedback12-n2-campfire-visual",
		run_state,
		owner,
		registry
	)
	if actions.size() != 3:
		_fail("N2 campfire visual fixture did not build exactly three choices")
		return
	for action in actions:
		if not bool(action.get("enabled", false)):
			_fail("N2 campfire visual fixture contains a disabled choice")
			return

	_modal.open(
		"feedback12-n2-campfire-visual",
		"rest",
		run_state.export_economy(),
		actions
	)
	_modal.configure_campfire_presentation()
	var flow := CaptureFlow.new(_modal)
	_viewport = SubViewport.new()
	_viewport.size = VIEW_SIZE
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(_viewport)
	_canvas = CaptureCanvas.new(flow)
	_viewport.add_child(_canvas)

	if not _require_phase("dormant"):
		return
	if not await _capture("dormant_campfire"):
		return

	var dormant_model := _modal.build_view_model(Vector2(VIEW_SIZE))
	var campfire_model_value: Variant = dormant_model.get("campfire_presentation", {})
	if not (campfire_model_value is Dictionary):
		_fail("N2 campfire visual model is missing")
		return
	var fire_rect: Rect2 = (campfire_model_value as Dictionary).get(
		"fire_rect",
		Rect2()
	)
	var fire_center := fire_rect.get_center()
	if (
		not fire_rect.has_area()
		or fire_center.distance_to(Vector2(VIEW_SIZE) * 0.5) > 75.0
		or not _modal.begin_pointer_press(fire_center, Vector2(VIEW_SIZE))
	):
		_fail(
			"N2 central campfire geometry or press is invalid: center=%s"
			% str(fire_center)
		)
		return
	var released: Dictionary = _modal.release_pointer_at_position(
		fire_center,
		Vector2(VIEW_SIZE)
	)
	if (
		str(released.get("_modal_control", "")) != "campfire_ignite"
		or not _modal.ignite_campfire()
	):
		_fail("N2 central campfire release did not ignite production state")
		return
	_modal.advance_campfire_presentation(0.45)
	if not _require_phase("intro"):
		return
	if not await _capture("intro_flame"):
		return

	for _step in range(8):
		if str(_modal.get_campfire_presentation_debug_state().get("phase", "")) == "menu":
			break
		_modal.advance_campfire_presentation(0.5)
	if not _require_phase("menu"):
		return
	var menu_model := _modal.build_view_model(Vector2(VIEW_SIZE))
	var menu_presentation: Dictionary = menu_model.get(
		"campfire_presentation",
		{}
	)
	var visible_choice_rects := 0
	for rect_value in menu_presentation.get("action_rects", []):
		if rect_value is Rect2 and (rect_value as Rect2).has_area():
			visible_choice_rects += 1
	if visible_choice_rects != 3:
		_fail("N2 campfire menu did not expose exactly three rendered choice rects")
		return
	if not await _capture("three_choice_menu"):
		return

	if not _modal.begin_campfire_result(
		"rest:cook_banana",
		rest_node.build_presentation_lines("rest:cook_banana")
	):
		_fail("N2 banana result presentation did not start")
		return
	for _step in range(3):
		_modal.advance_campfire_presentation(0.5)
	if not _require_phase("result"):
		return
	var result_model := _modal.build_view_model(Vector2(VIEW_SIZE))
	var result_presentation: Dictionary = result_model.get(
		"campfire_presentation",
		{}
	)
	if not bool(result_presentation.get("rainbow_glow", false)):
		_fail("N2 banana result did not expose the production rainbow glow")
		return
	if not await _capture("banana_rainbow_result"):
		return

	var metrics := _assert_pixel_seals()
	if metrics.is_empty():
		return
	print("feedback12_n2_campfire_modal_visual_qa: evidence=%s" % output_dir)
	print(
		"feedback12_n2_campfire_modal_visual_qa: fire_center=%.1f,%.1f"
		% [fire_center.x, fire_center.y]
	)
	print(
		"feedback12_n2_campfire_modal_visual_qa: frames=4 size=760x750 min_nonblank_pixels=%d min_pair_diff_pixels=%d pairs=6"
		% [
			int(metrics.get("min_nonblank_pixels", 0)),
			int(metrics.get("min_pair_diff_pixels", 0)),
		]
	)
	print(
		"feedback12_n2_campfire_modal_visual_qa: captures=dormant_campfire.png,intro_flame.png,three_choice_menu.png,banana_rainbow_result.png"
	)
	print("feedback12_n2_campfire_modal_visual_qa: ok")
	quit(0)


func _capture(frame_name: String) -> bool:
	_canvas.queue_redraw()
	for _frame_index in range(4):
		await process_frame
	var image := _viewport.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("empty N2 campfire frame: %s" % frame_name)
		return false
	image.convert(Image.FORMAT_RGBA8)
	if image.get_size() != VIEW_SIZE:
		_fail(
			"N2 campfire frame has wrong size: %s %s"
			% [frame_name, str(image.get_size())]
		)
		return false
	var output_path := ProjectSettings.globalize_path(
		"%s/%s.png" % [OUTPUT_DIR, frame_name]
	)
	if image.save_png(output_path) != OK:
		_fail("failed to save N2 campfire frame: %s" % output_path)
		return false
	_frames[frame_name] = image.duplicate()
	print("[Feedback12N2CampfireModalVisualQA] %s" % output_path)
	return true


func _require_phase(expected_phase: String) -> bool:
	var actual_phase := str(
		_modal.get_campfire_presentation_debug_state().get("phase", "")
	)
	if actual_phase == expected_phase:
		return true
	_fail(
		"N2 campfire phase mismatch: expected=%s actual=%s"
		% [expected_phase, actual_phase]
	)
	return false


func _assert_pixel_seals() -> Dictionary:
	var min_nonblank_pixels := VIEW_SIZE.x * VIEW_SIZE.y
	for frame_name in FRAME_NAMES:
		var frame: Image = _frames.get(frame_name, null)
		if frame == null or frame.get_size() != VIEW_SIZE:
			_fail("N2 pixel seal is missing frame: %s" % frame_name)
			return {}
		var nonblank_pixels := _count_nonblank_pixels(frame)
		min_nonblank_pixels = mini(min_nonblank_pixels, nonblank_pixels)
		if nonblank_pixels < MIN_NONBLANK_PIXELS:
			_fail(
				"N2 frame is visually blank: %s nonblank=%d"
				% [frame_name, nonblank_pixels]
			)
			return {}
	var min_pair_diff_pixels := VIEW_SIZE.x * VIEW_SIZE.y
	for first_index in range(FRAME_NAMES.size()):
		for second_index in range(first_index + 1, FRAME_NAMES.size()):
			var first_name := FRAME_NAMES[first_index]
			var second_name := FRAME_NAMES[second_index]
			var changed_pixels := _count_changed_pixels(
				_frames.get(first_name, null),
				_frames.get(second_name, null)
			)
			min_pair_diff_pixels = mini(min_pair_diff_pixels, changed_pixels)
			print(
				"[Feedback12N2CampfireModalVisualQA] pair=%s:%s changed_pixels=%d"
				% [first_name, second_name, changed_pixels]
			)
			if changed_pixels < MIN_PAIR_DIFF_PIXELS:
				_fail(
					"N2 frames are not visibly distinct: %s %s changed=%d"
					% [first_name, second_name, changed_pixels]
				)
				return {}
	return {
		"min_nonblank_pixels": min_nonblank_pixels,
		"min_pair_diff_pixels": min_pair_diff_pixels,
	}


func _count_nonblank_pixels(image: Image) -> int:
	var result := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if maxf(color.r, maxf(color.g, color.b)) > (4.0 / 255.0):
				result += 1
	return result


func _count_changed_pixels(first: Image, second: Image) -> int:
	if first == null or second == null or first.get_size() != second.get_size():
		return 0
	var result := 0
	for y in range(first.get_height()):
		for x in range(first.get_width()):
			var first_color := first.get_pixel(x, y)
			var second_color := second.get_pixel(x, y)
			var delta := int(round(maxf(
				absf(first_color.r - second_color.r),
				maxf(
					absf(first_color.g - second_color.g),
					absf(first_color.b - second_color.b)
				)
			) * 255.0))
			if delta >= PIXEL_DELTA_THRESHOLD:
				result += 1
	return result


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
