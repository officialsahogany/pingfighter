extends RefCounted

const StageClearResultPlazaProgressHandler := preload("res://scripts/core/stage_clear_result_plaza_progress_handler.gd")
const StageClearResultPlazaScenePrewarmState := preload("res://scripts/core/stage_clear_result_plaza_scene_prewarm_state.gd")
const BattlePsoPrewarmer := preload("res://scripts/core/battle_pso_prewarmer.gd")

const PLAZA_SCENE_PATH := "res://scenes/plaza.tscn"

var _plaza_node: Control
var _plaza_scene_packed: PackedScene
var _prewarm_state: Object = StageClearResultPlazaScenePrewarmState.new()


func reset() -> void:
	free_scene()
	_prewarm_state.reset()


func set_background_prewarm_enabled(enabled: bool) -> void:
	_prewarm_state.set_background_prewarm_enabled(enabled)


func has_scene() -> bool:
	return _plaza_node != null and is_instance_valid(_plaza_node)


func get_status() -> Dictionary:
	var status := {
		"plaza_scene_path": PLAZA_SCENE_PATH,
		"plaza_active": has_scene(),
		"plaza_scene_ready": has_scene(),
		"plaza_status": _plaza_node.get_status() if has_scene() and _plaza_node.has_method("get_status") else {},
	}
	status.merge(_prewarm_state.get_status(), true)
	return status


func update(delta: float) -> void:
	if has_scene() and _plaza_node.has_method("update_plaza"):
		_plaza_node.update_plaza(delta)


func handle_input(event: InputEvent) -> void:
	if has_scene() and _plaza_node.has_method("handle_plaza_input"):
		_plaza_node.handle_plaza_input(event)


func prewarm_assets_step(current_stage: int, owner: Object = null) -> bool:
	return bool(_prewarm_state.prewarm_assets_step(current_stage, owner))


func ensure_assets_ready(current_stage: int, owner: Object = null) -> bool:
	return bool(_prewarm_state.ensure_assets_ready(current_stage, owner))


func build_scene_config(
	current_stage: int,
	plaza_save_store: Object,
	owner: Object,
	registry: Object,
	selected_character_type: String,
	play_arrival_transition: bool = true
) -> Dictionary:
	return {
		"current_stage": maxi(1, current_stage),
		"plaza_save_path": StageClearResultPlazaProgressHandler.get_plaza_save_path(plaza_save_store),
		"runtime_owner": owner,
		"runtime_registry": registry,
		"selected_character_type": selected_character_type,
		"play_arrival_transition": play_arrival_transition,
	}


func spawn_scene(owner: Object, config: Dictionary, finish_callback: Callable) -> bool:
	if not (owner is Node):
		return false
	# Texture2D cache completion alone is not spawn readiness. The retained
	# 7x3 MIX/ADD layers must have rendered off-screen and crossed two actual
	# frame_post_draw flushes through BattlePsoPrewarmer first.
	if not BattlePsoPrewarmer.is_hwangyeok_gpu_prewarm_complete():
		return false
	free_scene()
	var packed: PackedScene = _get_plaza_scene_packed()
	if packed == null:
		push_warning("Missing plaza scene at %s" % PLAZA_SCENE_PATH)
		return false
	var instance: Node = packed.instantiate()
	if not (instance is Control):
		if instance != null:
			instance.queue_free()
		push_warning("Plaza scene root must be Control: %s" % PLAZA_SCENE_PATH)
		return false
	_plaza_node = instance as Control
	_plaza_node.name = "PlazaScene"
	_plaza_node.process_mode = Node.PROCESS_MODE_ALWAYS
	_plaza_node.z_index = 1200
	_plaza_node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if _plaza_node.has_method("configure"):
		_plaza_node.configure(config, finish_callback, true)
	(owner as Node).add_child(_plaza_node)
	return true


func free_scene() -> void:
	if _plaza_node != null and is_instance_valid(_plaza_node):
		# Retained CanvasItems must be hidden synchronously. queue_free() does not
		# flush until the frame boundary and can otherwise conceal a missing
		# plaza-exit cleanup route in state-only tests.
		if _plaza_node.has_method("clear_transient_canvas_items"):
			_plaza_node.clear_transient_canvas_items()
		_plaza_node.queue_free()
	_plaza_node = null


func _get_plaza_scene_packed() -> PackedScene:
	if _plaza_scene_packed != null:
		return _plaza_scene_packed
	_plaza_scene_packed = load(PLAZA_SCENE_PATH) as PackedScene
	return _plaza_scene_packed
