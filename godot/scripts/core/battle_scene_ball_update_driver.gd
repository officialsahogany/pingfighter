extends RefCounted

const BattleSceneBallSnapshotApplier := preload("res://scripts/core/battle_scene_ball_snapshot_applier.gd")

var _owner: Object
var _registry: Object
var _snapshot_applier: Object = BattleSceneBallSnapshotApplier.new()


func reset_ball(owner: Object, registry: Object) -> void:
	var controller: Object = _get_instance(registry, "ball_round_controller")
	var context_builder: Object = _get_instance(registry, "ball_update_context")
	if owner == null or controller == null or context_builder == null:
		return
	var result: Dictionary = controller.reset_ball(
		context_builder.build_reset_config(owner),
		_get_ball_round_deps(registry),
		{"apply_ball_snapshot": Callable(self, "_apply_current_owner_snapshot").bind(owner)}
	)
	_snapshot_applier.apply_reset_result(owner, result)


func serve_ball(owner: Object, registry: Object) -> void:
	var controller: Object = _get_instance(registry, "ball_round_controller")
	var context_builder: Object = _get_instance(registry, "ball_update_context")
	if owner == null or controller == null or context_builder == null:
		return
	var round_deps: Dictionary = _get_ball_round_deps(registry)
	round_deps["owner"] = owner
	round_deps["registry"] = registry
	controller.serve_ball(
		context_builder.build_serve_config(owner),
		round_deps,
		{"apply_ball_snapshot": Callable(self, "_apply_current_owner_snapshot").bind(owner)}
	)


func prewarm_update(owner: Object, registry: Object) -> void:
	var controller: Object = _get_instance(registry, "ball_update_controller")
	var context_builder: Object = _get_instance(registry, "ball_update_context")
	if owner == null or controller == null or context_builder == null:
		return
	context_builder.build_update_context(owner)
	context_builder.build_update_deps(registry)


func update_ball(owner: Object, registry: Object, delta: float, score_callback: Callable = Callable()) -> void:
	var controller: Object = _get_instance(registry, "ball_update_controller")
	var context_builder: Object = _get_instance(registry, "ball_update_context")
	if owner == null or controller == null or context_builder == null:
		return
	_owner = owner
	_registry = registry
	var result: Dictionary = controller.update(
		delta,
		context_builder.build_update_context(owner),
		context_builder.build_update_deps(registry),
		{
			"reset_drive_input": Callable(self, "_reset_drive_input_frames"),
			"clear_drive_ball": Callable(self, "_clear_drive_ball_state"),
		}
	)
	var snapshot: Variant = result.get("snapshot", {})
	if snapshot is Dictionary:
		_snapshot_applier.apply_snapshot(owner, snapshot)
	var score_event: String = str(result.get("score_event", ""))
	if score_event != "" and score_callback.is_valid():
		score_callback.call(score_event)
	_owner = null
	_registry = null


func reset_drive_input_frames(registry: Object) -> void:
	var bridge: Object = _get_instance(registry, "ball_scene_bridge")
	if bridge != null:
		bridge.reset_drive_input_frames(registry)


func _reset_drive_input_frames() -> void:
	reset_drive_input_frames(_registry)


func _clear_drive_ball_state(clear_spin: bool = false) -> void:
	var bridge: Object = _get_instance(_registry, "ball_scene_bridge")
	if bridge != null:
		_snapshot_applier.apply_snapshot(_owner, bridge.clear_drive_ball_state(_registry, clear_spin))


func _get_ball_round_deps(registry: Object) -> Dictionary:
	var context_builder: Object = _get_instance(registry, "ball_update_context")
	if context_builder == null:
		return {}
	return context_builder.build_round_deps(registry)


func _apply_current_owner_snapshot(snapshot: Dictionary, owner: Object) -> void:
	_snapshot_applier.apply_snapshot(owner, snapshot)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
