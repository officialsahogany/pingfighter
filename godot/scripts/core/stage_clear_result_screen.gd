extends RefCounted

const StageClearResultHandlerRegistry := preload("res://scripts/core/stage_clear_result_handler_registry.gd")

const RESULT_SCENE_PATH := "res://scenes/stage_clear_result.tscn"
const STARPOINT_CHOICE_REWARD_DELAY := 0.65

var active: bool = false
var player_score: int = 0
var boss_score: int = 0
var current_stage: int = 1
var _pending_reset_callback: Callable = Callable()
var _pending_exit_callback: Callable = Callable()
var _pending_owner: Object
var _pending_registry: Object
var _scene_node: Control
var _spawn_pending: bool = false
var _handler_registry: Object = StageClearResultHandlerRegistry.new()
var _services: Dictionary = {}
var _stage_start_snapshot: Dictionary = {}
var _last_stage_reward_snapshot: Dictionary = {}


func _init() -> void:
	_handler_registry.apply_to_screen(self)


func _get(property: StringName) -> Variant:
	return _services.get(str(property), null)


func _set(property: StringName, value: Variant) -> bool:
	var key: String = str(property)
	if _handler_registry.has_service_field(key):
		_services[key] = value
		return true
	return false


func show_from_scoreboard(
	owner: Object,
	registry: Object,
	reset_game_callback: Callable,
	exit_to_menu_callback: Callable = Callable()
) -> bool:
	return _service("_show_flow_handler").show_from_screen(
		self,
		owner,
		registry,
		reset_game_callback,
		exit_to_menu_callback,
		STARPOINT_CHOICE_REWARD_DELAY
	)


func is_active() -> bool:
	return active


func is_scene_ready() -> bool:
	return _has_result_scene()


func reset() -> void:
	_service("_screen_state_handler").reset_screen_state(
		self,
		_service("_reward_grant_handler"),
		_service("_plaza_progress_handler"),
		_service("_starpoint_choice_handler"),
		_scene_node,
		Callable(_service("_scene_shell_handler"), "free_screen_result_scene").bind(self),
		_service("_plaza_scene_handler")
	)


func update(delta: float) -> void:
	_service("_update_flow_handler").update_screen_flow_from_screen(
		self,
		delta,
		STARPOINT_CHOICE_REWARD_DELAY
	)


func handle_input(event: InputEvent, _owner: Object, _registry: Object, _view_size: Vector2) -> bool:
	return _service("_input_flow_handler").handle_input_from_screen(self, event)


func draw(canvas: CanvasItem, _owner: Object, _registry: Object, view_size: Vector2) -> void:
	if not active or _has_result_scene() or _service("_plaza_scene_handler").has_scene() or canvas == null:
		return
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.015, 0.018, 0.028, 0.94))


func get_reward_plan() -> Dictionary:
	return _service("_reward_plan_builder").build_reward_plan(player_score, boss_score)


func get_status() -> Dictionary:
	return _service("_screen_status_handler").build_status_from_screen(self, RESULT_SCENE_PATH)


func prepare_stage_start(owner: Object, registry: Object, stage_id: int = -1) -> void:
	var next_stage: int = stage_id
	if next_stage <= 0:
		next_stage = _service("_runtime_context_handler").get_current_stage(owner)
	_stage_start_snapshot = _service("_stage_snapshot_builder").build_progress_snapshot(owner, registry, next_stage)


func set_plaza_save_path_for_test(path: String) -> void:
	var plaza_save_store: Object = _service("_plaza_save_store")
	if plaza_save_store != null and plaza_save_store.has_method("set_save_path"):
		plaza_save_store.set_save_path(path)


func set_background_plaza_prewarm_enabled_for_test(enabled: bool) -> void:
	_service("_plaza_scene_handler").set_background_prewarm_enabled(enabled)


func set_reward_resolver_for_test(reward_resolver: Object) -> void:
	_service("_reward_grant_handler").set_reward_resolver_for_test(reward_resolver)


func get_plaza_save_summary() -> Dictionary:
	var plaza_save_store: Object = _service("_plaza_save_store")
	if plaza_save_store == null or not plaza_save_store.has_method("get_summary"):
		return {}
	return plaza_save_store.get_summary()


func get_cached_plaza_save_summary() -> Dictionary:
	return _service("_plaza_progress_handler").get_cached_summary()


func prewarm_assets(_owner: Object = null, _registry: Object = null) -> Dictionary:
	return _service("_prewarm_flow_handler").prewarm_assets_from_screen(_owner, _registry, self)


func prewarm_scene_shell() -> bool:
	return _service("_prewarm_flow_handler").prewarm_scene_shell_from_screen(self)


func prewarm_assets_step(_owner: Object = null, _registry: Object = null) -> bool:
	return _service("_prewarm_flow_handler").prewarm_assets_step_from_screen(_owner, _registry, self)


func prewarm_assets_threaded_step(_owner: Object = null, _registry: Object = null) -> bool:
	return _service("_prewarm_flow_handler").prewarm_assets_step_from_screen(_owner, _registry, self, true)


func _has_result_scene() -> bool:
	return _scene_node != null and is_instance_valid(_scene_node)


func _service(field_name: String) -> Object:
	var value: Variant = _services.get(field_name, null)
	return value if value is Object else null
