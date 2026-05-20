extends SceneTree

const BattleSceneBattleInitializeLifecycle := preload("res://scripts/core/battle_scene_battle_initialize_lifecycle.gd")
const BattleSceneFlowController := preload("res://scripts/core/battle_scene_flow_controller.gd")

var _failures: Array[String] = []
var _modules: Dictionary = {}


class FakeBattleLifecycle:
	extends RefCounted

	var initialize_calls := 0
	var last_owner: Object
	var last_registry: Object
	var last_context: Dictionary = {}

	func initialize(owner: Object, registry: Object, context: Dictionary) -> void:
		initialize_calls += 1
		last_owner = owner
		last_registry = registry
		last_context = context.duplicate(true)


class FakeBattleInitializeLifecycle:
	extends RefCounted

	var calls := 0
	var last_play_stage_bgm := true

	func initialize_battle(
		_flow: Object,
		_owner: Object,
		_registry: Object,
		_module_getter: Callable,
		play_stage_bgm: bool = true
	) -> void:
		calls += 1
		last_play_stage_bgm = play_stage_bgm


func _init() -> void:
	_verify_initialize_calls_battle_lifecycle_and_latches()
	_verify_initialize_latches_without_battle_lifecycle()
	_verify_flow_controller_delegates_initialize_surface()

	if _failures.is_empty():
		print("battle_scene_battle_initialize_lifecycle_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_initialize_calls_battle_lifecycle_and_latches() -> void:
	var lifecycle: Object = BattleSceneBattleInitializeLifecycle.new()
	var flow: Object = BattleSceneFlowController.new()
	var owner := RefCounted.new()
	var registry := RefCounted.new()
	var battle_lifecycle := FakeBattleLifecycle.new()
	_modules = {"battle_scene_lifecycle": battle_lifecycle}

	lifecycle.initialize_battle(flow, owner, registry, Callable(self, "_get_module"), false)

	_expect(battle_lifecycle.initialize_calls == 1, "initialize should call battle scene lifecycle once")
	_expect(battle_lifecycle.last_owner == owner, "initialize should forward owner")
	_expect(battle_lifecycle.last_registry == registry, "initialize should forward registry")
	_expect(
		not bool(battle_lifecycle.last_context.get("play_stage_bgm_on_initialize", true)),
		"initialize should forward play-stage-BGM flag"
	)
	_expect(flow.is_battle_initialized(), "initialize should latch battle initialized")
	_expect(not bool(flow.get("_battle_bgm_started")), "initialize should latch false BGM start state")

	lifecycle.initialize_battle(flow, owner, registry, Callable(self, "_get_module"), true)

	_expect(battle_lifecycle.initialize_calls == 1, "initialize should keep one-shot guard")
	_expect(not bool(flow.get("_battle_bgm_started")), "guarded initialize should not rewrite BGM latch")


func _verify_initialize_latches_without_battle_lifecycle() -> void:
	var lifecycle: Object = BattleSceneBattleInitializeLifecycle.new()
	var flow: Object = BattleSceneFlowController.new()
	_modules = {}

	lifecycle.initialize_battle(flow, RefCounted.new(), RefCounted.new(), Callable(self, "_get_module"), true)

	_expect(flow.is_battle_initialized(), "initialize should latch even when battle lifecycle module is missing")
	_expect(bool(flow.get("_battle_bgm_started")), "initialize should preserve requested BGM latch without module")


func _verify_flow_controller_delegates_initialize_surface() -> void:
	var flow: Object = BattleSceneFlowController.new()
	var fake := FakeBattleInitializeLifecycle.new()
	flow.battle_initialize_lifecycle = fake

	flow.initialize_battle(RefCounted.new(), RefCounted.new(), Callable(self, "_get_module"), false)

	_expect(fake.calls == 1, "flow controller should delegate initialize_battle surface")
	_expect(not fake.last_play_stage_bgm, "flow controller should pass play-stage-BGM flag through")


func _get_module(key: String) -> Object:
	var value: Variant = _modules.get(key, null)
	if typeof(value) == TYPE_OBJECT:
		return value as Object
	return null


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
