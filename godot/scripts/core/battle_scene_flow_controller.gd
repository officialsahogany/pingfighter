extends RefCounted

const BattleSceneBattleInitializeLifecycle := preload("res://scripts/core/battle_scene_battle_initialize_lifecycle.gd")
const BattleSceneStageIntroFlowLifecycle := preload("res://scripts/core/battle_scene_stage_intro_flow_lifecycle.gd")

var _battle_initialized: bool = false
@warning_ignore("unused_private_class_variable")
var _battle_bgm_started: bool = false
var _stage_landing_intro_started: bool = false
var _ball_spawn_intro_started: bool = false

var battle_initialize_lifecycle: Object = BattleSceneBattleInitializeLifecycle.new()
var stage_intro_flow_lifecycle: Object = BattleSceneStageIntroFlowLifecycle.new()


func initialize_battle(owner: Object, registry: Object, module_getter: Callable, play_stage_bgm: bool = true) -> void:
	battle_initialize_lifecycle.initialize_battle(self, owner, registry, module_getter, play_stage_bgm)


func begin_stage_landing_intro(
	owner: Object,
	registry: Object,
	module_getter: Callable,
	cached_module_getter: Callable
) -> void:
	stage_intro_flow_lifecycle.begin_stage_landing_intro(
		self,
		owner,
		registry,
		module_getter,
		cached_module_getter
	)


func begin_ball_spawn_intro(owner: Object, registry: Object, module_getter: Callable) -> void:
	stage_intro_flow_lifecycle.begin_ball_spawn_intro(self, owner, registry, module_getter)


func is_battle_initialized() -> bool:
	return _battle_initialized


func is_stage_landing_intro_started() -> bool:
	return _stage_landing_intro_started


func is_ball_spawn_intro_started() -> bool:
	return _ball_spawn_intro_started


func _start_battle_bgm(owner: Object, module_getter: Callable) -> void:
	stage_intro_flow_lifecycle.start_battle_bgm(self, owner, module_getter)


func _get_module(module_getter: Callable, key: String) -> Object:
	if not module_getter.is_valid():
		return null
	var value: Variant = module_getter.call(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _queue_redraw(owner: Object) -> void:
	if owner != null and owner.has_method("queue_redraw"):
		owner.queue_redraw()
