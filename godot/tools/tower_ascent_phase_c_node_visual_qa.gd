extends SceneTree

const BattlePlayfieldSceneDrawer := preload(
	"res://scripts/core/battle_playfield_scene_drawer.gd"
)
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentFlowRenderer := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
)
const TowerAscentNodeModalState := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_state.gd"
)

const GAME_SIZE := Vector2i(760, 750)
const OUTPUT_DIR := "res://.godot/codex_captures/tower_ascent_phase_c"
const CAPTURE_SPECS := [
	{
		"file": "common_shell.png",
		"kind": "common_shell",
		"actions": [],
	},
	{
		"file": "shop.png",
		"kind": "shop",
		"actions": [
			{"label": "일반 액티브 진열 A", "cost_text": "60 골드", "enabled": true},
			{"label": "일반 액티브 진열 B", "cost_text": "60 골드", "enabled": true},
			{"label": "일반 액티브 진열 C", "cost_text": "60 골드", "enabled": true},
			{"label": "프리미엄 액티브 진열", "cost_text": "180 골드", "enabled": true},
			{"label": "액티브 캡슐", "cost_text": "80 골드", "enabled": true},
			{"label": "기회의 보석", "cost_text": "150 골드", "enabled": false, "unavailable_reason": "골드 150 필요, 30 부족"},
		],
	},
	{
		"file": "training.png",
		"kind": "training",
		"actions": [
			{"label": "체질 수련 선택지 A", "cost_text": "5 무혼", "enabled": true},
			{"label": "체질 수련 선택지 B", "cost_text": "5 무혼", "enabled": true},
			{"label": "무공 서가 선택지 A", "cost_text": "10 무혼", "enabled": true},
			{"label": "무공 서가 선택지 B", "cost_text": "10 무혼", "enabled": false, "unavailable_reason": "무혼 10 필요, 2 부족"},
		],
	},
	{
		"file": "fallen_monk.png",
		"kind": "fallen_monk",
		"actions": [
			{"label": "초식 습득 선택지", "cost_text": "8 무혼", "enabled": true},
			{"label": "초식 교환 선택지", "cost_text": "10 무혼", "enabled": true},
			{"label": "초식 제거 선택지", "cost_text": "12 무혼", "enabled": false, "unavailable_reason": "무혼 12 필요, 4 부족"},
		],
	},
	{
		"file": "guardian_spring.png",
		"kind": "guardian_spring",
		"actions": [
			{"label": "수호령 강화", "cost_text": "6 무혼", "enabled": true},
			{"label": "봉인 수호령 교체", "cost_text": "무료", "enabled": true},
			{"label": "봉인 수호령 흡수", "cost_text": "무료", "enabled": true},
		],
	},
	{
		"file": "rest.png",
		"kind": "rest",
		"actions": [
			{"label": "기회의 보석 1개 회복", "cost_text": "무료", "enabled": true},
		],
	},
]


class CaptureFlow:
	extends RefCounted

	var source_flow: Object
	var modal_state: Object = TowerAscentNodeModalState.new()
	var renderer: Object = TowerAscentFlowRenderer.new()
	var capture_kind := "common_shell"

	func _init(new_source_flow: Object, kind: String, actions: Array) -> void:
		source_flow = new_source_flow
		capture_kind = kind
		modal_state.open(
			str(source_flow.get_current_node_id()),
			kind,
			{"gold": 120, "muhon": 8, "chance_gems": 2},
			actions
		)

	func is_active() -> bool:
		return true

	func get_phase_name() -> String:
		return "NODE_MODAL"

	func get_header_subtitle() -> String:
		return "페이즈 C 노드 실기능 검증 · %s" % capture_kind

	func get_node_modal_view_model() -> Dictionary:
		return modal_state.build_view_model()

	func get_graph_nodes() -> Array:
		return source_flow.get_graph_nodes()

	func get_graph_edges() -> Array:
		return source_flow.get_graph_edges()

	func get_graph_floors() -> Array:
		return source_flow.get_graph_floors()

	func get_route_target_ids() -> Array:
		return source_flow.get_route_target_ids()

	func get_current_node_id() -> String:
		return source_flow.get_current_node_id()

	func get_selected_target_id() -> String:
		return ""

	func draw(canvas: CanvasItem) -> void:
		renderer.draw(canvas, self)


class CaptureRegistry:
	extends RefCounted

	var flow_owner: Object

	func _init(new_flow_owner: Object) -> void:
		flow_owner = new_flow_owner

	func get_instance(_key: String) -> Variant:
		return null

	func get_cached_instance(key: String) -> Variant:
		if key == "tower_ascent_flow_owner":
			return flow_owner
		return null


class ProductionPlayfieldCanvas:
	extends Node2D

	var registry: Object
	var drawer: Object = BattlePlayfieldSceneDrawer.new()
	var ball_active := false
	var ball_visual_type := "pingpong"

	func _init(new_registry: Object) -> void:
		registry = new_registry

	func _draw() -> void:
		drawer.draw(self, registry, Vector2.ZERO, 760.0, 750.0, 0.0)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		push_error("tower_ascent_phase_c_node_visual_qa requires a real window")
		quit(1)
		return
	if RenderingServer.get_rendering_device() == null:
		push_error("tower_ascent_phase_c_node_visual_qa requires a Vulkan rendering device")
		quit(1)
		return
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(output_dir)
	if mkdir_error != OK:
		push_error("phase-C node capture directory creation failed: %d" % mkdir_error)
		quit(1)
		return
	for index in range(CAPTURE_SPECS.size()):
		if not await _capture_node(CAPTURE_SPECS[index], output_dir, index):
			return
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	print("tower_ascent_phase_c_node_visual_qa: evidence=%s" % output_dir)
	print("tower_ascent_phase_c_node_visual_qa: captures=%d" % CAPTURE_SPECS.size())
	print("tower_ascent_phase_c_node_visual_qa: ok")
	quit(0)


func _capture_node(spec: Dictionary, output_dir: String, index: int) -> bool:
	var source_flow := TowerAscentFlowOwner.new()
	if not source_flow.begin_vertical_slice(null, Callable(), {
		"run_id": "phase-c-visual-%d" % index,
		"current_stage": 4,
		"map_seed": 83521,
	}):
		push_error("phase-C node visual fixture could not begin")
		quit(1)
		return false
	var actions: Array = []
	for action_index in range((spec.get("actions", []) as Array).size()):
		var action := ((spec.get("actions", []) as Array)[action_index] as Dictionary).duplicate(true)
		action["id"] = "visual:%d" % action_index
		actions.append(action)
	var capture_flow := CaptureFlow.new(source_flow, str(spec.get("kind", "common_shell")), actions)
	var viewport := SubViewport.new()
	viewport.size = GAME_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var canvas := ProductionPlayfieldCanvas.new(CaptureRegistry.new(capture_flow))
	viewport.add_child(canvas)
	canvas.queue_redraw()
	for _frame_index in range(6):
		await process_frame
	var image: Image = viewport.get_texture().get_image()
	var output_path := output_dir.path_join(str(spec.get("file", "capture.png")))
	if image == null or image.is_empty() or image.save_png(output_path) != OK:
		push_error("phase-C node visual QA capture failed: %s" % output_path)
		quit(1)
		return false
	print("[TowerAscentPhaseCVisualQA] %s" % output_path)
	get_root().remove_child(viewport)
	viewport.queue_free()
	await process_frame
	return true
