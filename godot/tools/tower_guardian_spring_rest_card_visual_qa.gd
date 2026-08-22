extends SceneTree

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const RuntimePerkIconRenderer := preload(
	"res://scripts/hud/runtime_perk_icon_renderer.gd"
)
const RuntimePerkOverlayRenderer := preload(
	"res://scripts/hud/runtime_perk_overlay_renderer.gd"
)
const TowerAscentFlowRenderer := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
)
const TowerAscentGuardianSpringNode := preload(
	"res://scripts/tower_ascent/tower_ascent_guardian_spring_node.gd"
)
const TowerAscentNodeModalState := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_state.gd"
)
const TowerAscentRestNode := preload(
	"res://scripts/tower_ascent/tower_ascent_rest_node.gd"
)

const VIEW_SIZE := Vector2i(2020, 1246)
const OUTPUT_DIR := "res://.godot/codex_captures/tower_node_modal_s4"
const FRAME_NAMES := [
	"spring_before",
	"spring_page_2",
	"spring_after",
	"rest_before",
	"rest_after",
]


class QaRunState:
	extends RefCounted
	var muhon := 99
	var chance_gems := 1

	func export_economy() -> Dictionary:
		return {"muhon": muhon, "gold": 0, "chance_gems": chance_gems}

	func get_chance_gems() -> int:
		return chance_gems


class QaLingpetRuntime:
	extends RefCounted

	func build_guardian_enhance_live_candidates(_owner: Object = null) -> Array:
		return [{"type": "duration", "label": "지속시간 강화", "weight": 1.0}]


class QaRegistry:
	extends RefCounted
	var runtime: Object

	func _init(runtime_value: Object) -> void:
		runtime = runtime_value

	func get_instance(key: String) -> Object:
		return runtime if key == "lingpet_egg_runtime" else null


class QaOwner:
	extends RefCounted

	func set_tower_ascent_guardian_projection(
		_sealed_guardians: Array,
		_soul_summoning_owned: bool
	) -> void:
		pass


class CaptureFlow:
	extends RefCounted
	var modal_state: Object
	var card_renderer: Object
	var icon_renderer: Object
	var node_kind := "guardian_spring"

	func _init(state_value: Object, card_value: Object, icon_value: Object) -> void:
		modal_state = state_value
		card_renderer = card_value
		icon_renderer = icon_value

	func get_phase_name() -> String:
		return "NODE_MODAL"

	func get_node_modal_view_model(view_size: Vector2) -> Dictionary:
		return modal_state.build_view_model(view_size)

	func get_node_modal_kind() -> String:
		return node_kind

	func get_node_modal_render_context() -> Dictionary:
		return {"card_renderer": card_renderer, "icon_renderer": icon_renderer}


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


var _card_renderer := RuntimePerkOverlayRenderer.new()
var _icon_renderer := RuntimePerkIconRenderer.new()
var _modal := TowerAscentNodeModalState.new()
var _frames: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		push_error("tower_guardian_spring_rest_card_visual_qa requires a real window")
		quit(1)
		return
	if RenderingServer.get_rendering_device() == null:
		push_error("tower_guardian_spring_rest_card_visual_qa requires Vulkan")
		quit(1)
		return
	_card_renderer.prewarm_traditional_choice_assets()
	_prewarm_live_guardian_portraits()
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		push_error("S4 capture directory creation failed")
		quit(1)
		return

	var spring_fixture := _build_spring_fixture()
	var spring_actions: Array = spring_fixture.get("actions", [])
	if spring_actions.size() <= TowerAscentNodeModalState.CARD_PAGE_SIZE:
		push_error("S4 spring capture fixture did not overflow six cards")
		quit(1)
		return
	_modal.open(
		"s4-spring",
		"guardian_spring",
		{"muhon": 99, "gold": 0},
		spring_actions
	)
	_modal.set_clock_msec_for_tests(1000)
	var flow := CaptureFlow.new(_modal, _card_renderer, _icon_renderer)
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var canvas := CaptureCanvas.new(flow)
	viewport.add_child(canvas)

	_hover_first_card(1000, 1120)
	if not await _capture_frame(viewport, canvas, output_dir, "spring_before"):
		return
	var next_rect: Rect2 = _modal.build_view_model(Vector2(VIEW_SIZE)).get(
		"page_next_rect",
		Rect2()
	)
	var next_corner := next_rect.position + Vector2(2.0, 2.0)
	if (
		not _modal.begin_pointer_press(next_corner, Vector2(VIEW_SIZE))
		or not bool(_modal.release_pointer_at_position(
			next_corner,
			Vector2(VIEW_SIZE)
		).get("changed", false))
	):
		push_error("S4 visual fixture could not turn to spring page two")
		quit(1)
		return
	_hover_first_visible_card(1300, 1420)
	if not await _capture_frame(viewport, canvas, output_dir, "spring_page_2"):
		return

	_modal.set_visible_page(0)
	_modal.set_clock_msec_for_tests(2000)
	var first_action: Dictionary = spring_actions[0]
	_modal.record_action_feedback(first_action, {
		"accepted": true,
		"applied": true,
		"message": "수호령 강화 완료",
		"costs": {"muhon": 2},
		"balances_before": {"muhon": 99, "gold": 0},
		"balances": {"muhon": 97, "gold": 0},
	})
	_modal.set_balances({"muhon": 97, "gold": 0})
	_hover_first_card(2000, 2120)
	if not await _capture_frame(viewport, canvas, output_dir, "spring_after"):
		return

	flow.node_kind = "rest"
	var rest := TowerAscentRestNode.new()
	var rest_run_state := QaRunState.new()
	var rest_actions: Array[Dictionary] = rest.build_actions("s4-rest", rest_run_state)
	_modal.open("s4-rest", "rest", rest_run_state.export_economy(), rest_actions)
	_hover_first_card(3000, 3120)
	if not await _capture_frame(viewport, canvas, output_dir, "rest_before"):
		return
	rest_run_state.chance_gems = 2
	rest.restore_state([{"node_id": "s4-rest", "node_resolution_id": "s4-rest:done"}])
	var completed_actions: Array[Dictionary] = rest.build_actions("s4-rest", rest_run_state)
	_modal.set_actions(completed_actions)
	_modal.set_balances(rest_run_state.export_economy())
	_modal.set_clock_msec_for_tests(4000)
	_modal.record_action_feedback(completed_actions[0], {
		"accepted": true,
		"applied": true,
		"message": "기회의 보석 1개 회복",
		"balances_before": {"muhon": 99, "gold": 0, "chance_gems": 1},
		"balances": {"muhon": 99, "gold": 0, "chance_gems": 2},
	})
	_hover_first_card(4000, 4120)
	if not await _capture_frame(viewport, canvas, output_dir, "rest_after"):
		return

	if not _assert_visible_differences():
		quit(1)
		return
	if not _save_strip(
		output_dir,
		"spring_before_page_after_strip.png",
		["spring_before", "spring_page_2", "spring_after"]
	):
		quit(1)
		return
	if not _save_strip(output_dir, "rest_before_after_strip.png", ["rest_before", "rest_after"]):
		quit(1)
		return
	print("tower_guardian_spring_rest_card_visual_qa: evidence=%s" % output_dir)
	print("tower_guardian_spring_rest_card_visual_qa: captures=%d strips=2" % FRAME_NAMES.size())
	print("tower_guardian_spring_rest_card_visual_qa: ok")
	quit(0)


func _build_spring_fixture() -> Dictionary:
	var pet_ids := LingpetCatalog.get_debug_pet_ids()
	if pet_ids.size() < 4:
		return {}
	var active_pet_id := str(pet_ids[0])
	var sealed: Array[Dictionary] = []
	for index in range(1, pet_ids.size()):
		var pet_id := str(pet_ids[index])
		sealed.append({
			"pet_id": pet_id,
			"display_name": LingpetCatalog.get_display_name(pet_id),
		})
	var spring := TowerAscentGuardianSpringNode.new()
	spring.restore_state({
		"soul_summoning_owned": true,
		"soul_summoning_node_id": "earlier-spring",
		"active_guardian": {
			"pet_id": active_pet_id,
			"display_name": LingpetCatalog.get_display_name(active_pet_id),
		},
		"sealed_guardians": sealed,
	})
	var run_state := QaRunState.new()
	var actions: Array[Dictionary] = spring.build_actions(
		"s4-spring",
		41204,
		run_state,
		QaOwner.new(),
		QaRegistry.new(QaLingpetRuntime.new())
	)
	return {"actions": actions, "sealed_count": sealed.size()}


func _prewarm_live_guardian_portraits() -> void:
	var jobs_value: Variant = _icon_renderer.call("_build_prewarm_asset_jobs")
	if not (jobs_value is Array):
		return
	for job_value in jobs_value as Array:
		if job_value is Dictionary and str((job_value as Dictionary).get("type", "")) == "guardian_portrait":
			_icon_renderer.call("_run_prewarm_asset_job", job_value)


func _hover_first_card(start_msec: int, settled_msec: int) -> void:
	var rects := _modal.get_action_rects(Vector2(VIEW_SIZE))
	if rects.is_empty():
		return
	var corner := (rects[0] as Rect2).position + Vector2(2.0, 2.0)
	_modal.set_clock_msec_for_tests(start_msec)
	_modal.update_hover_at_position(corner, Vector2(VIEW_SIZE))
	_modal.set_clock_msec_for_tests(settled_msec)


func _hover_first_visible_card(start_msec: int, settled_msec: int) -> void:
	var rects := _modal.get_action_rects(Vector2(VIEW_SIZE))
	for rect_value in rects:
		var rect := rect_value as Rect2
		if not rect.has_area() or rect.is_equal_approx(_modal.build_view_model(
			Vector2(VIEW_SIZE)
		).get("action_rects", [])[-1] as Rect2):
			continue
		_modal.set_clock_msec_for_tests(start_msec)
		_modal.update_hover_at_position(rect.position + Vector2(2.0, 2.0), Vector2(VIEW_SIZE))
		_modal.set_clock_msec_for_tests(settled_msec)
		return


func _capture_frame(
	viewport: SubViewport,
	canvas: CanvasItem,
	output_dir: String,
	frame_name: String
) -> bool:
	canvas.queue_redraw()
	for _frame_index in range(3):
		await process_frame
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("empty S4 frame: %s" % frame_name)
		quit(1)
		return false
	var path := output_dir.path_join("%s.png" % frame_name)
	if image.save_png(path) != OK:
		push_error("failed to save S4 frame: %s" % path)
		quit(1)
		return false
	_frames[frame_name] = image.duplicate()
	print("[TowerNodeModalS4VisualQA] %s" % path)
	return true


func _save_strip(output_dir: String, file_name: String, frame_names: Array) -> bool:
	var cell_size := Vector2i(VIEW_SIZE.x / 2, VIEW_SIZE.y / 2)
	var strip := Image.create(
		cell_size.x * frame_names.size(),
		cell_size.y,
		false,
		Image.FORMAT_RGBA8
	)
	for index in range(frame_names.size()):
		var frame := (_frames.get(str(frame_names[index]), null) as Image).duplicate()
		frame.resize(cell_size.x, cell_size.y, Image.INTERPOLATE_LANCZOS)
		frame.convert(Image.FORMAT_RGBA8)
		strip.blit_rect(
			frame,
			Rect2i(Vector2i.ZERO, cell_size),
			Vector2i(index * cell_size.x, 0)
		)
	var path := output_dir.path_join(file_name)
	if strip.save_png(path) != OK:
		push_error("failed to save S4 strip: %s" % path)
		return false
	print("[TowerNodeModalS4VisualQA] %s" % path)
	return true


func _assert_visible_differences() -> bool:
	for comparison in [
		["spring_before", "spring_page_2", "spring page change"],
		["spring_before", "spring_after", "spring result"],
		["rest_before", "rest_after", "rest result"],
	]:
		var changed := _sampled_difference_count(
			_frames.get(str(comparison[0]), null),
			_frames.get(str(comparison[1]), null)
		)
		if changed < 80:
			push_error("S4 visual difference too small for %s: %d" % [str(comparison[2]), changed])
			return false
	return true


func _sampled_difference_count(first: Image, second: Image) -> int:
	if first == null or second == null or first.get_size() != second.get_size():
		return 0
	var changed := 0
	for y in range(0, first.get_height(), 6):
		for x in range(0, first.get_width(), 6):
			var first_color := first.get_pixel(x, y)
			var second_color := second.get_pixel(x, y)
			var difference := (
				absf(first_color.r - second_color.r)
				+ absf(first_color.g - second_color.g)
				+ absf(first_color.b - second_color.b)
				+ absf(first_color.a - second_color.a)
			)
			if difference > 0.05:
				changed += 1
	return changed
