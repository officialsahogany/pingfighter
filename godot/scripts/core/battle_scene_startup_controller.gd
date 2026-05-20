extends RefCounted

const BattleSceneReadyLifecycle := preload("res://scripts/core/battle_scene_ready_lifecycle.gd")
const BattleSceneSelectionStartupLifecycle := preload("res://scripts/core/battle_scene_selection_startup_lifecycle.gd")
const BattleSceneTeardownLifecycle := preload("res://scripts/core/battle_scene_teardown_lifecycle.gd")

var ready_lifecycle: Object = BattleSceneReadyLifecycle.new()
var selection_startup_lifecycle: Object = BattleSceneSelectionStartupLifecycle.new()
var teardown_lifecycle: Object = BattleSceneTeardownLifecycle.new()


func ready(owner: Node, registry: Object, module_getter: Callable, callbacks: Dictionary) -> void:
	ready_lifecycle.ready(self, owner, registry, module_getter, callbacks)


func exit_tree(owner: Node, registry: Object, cached_module_getter: Callable, callbacks: Dictionary) -> void:
	teardown_lifecycle.exit_tree(owner, registry, cached_module_getter, callbacks)


func _apply_selection_state(owner: Object) -> void:
	selection_startup_lifecycle.apply_selection_state(owner)


func _consume_skip_battle_logo_once(owner: Object) -> bool:
	if owner == null or not owner.has_method("get_node_or_null"):
		return false
	var selection_state: Node = owner.get_node_or_null("/root/GameSelectionState")
	if selection_state != null and selection_state.has_method("consume_skip_battle_logo_once"):
		return bool(selection_state.consume_skip_battle_logo_once())
	return false


func _normalize_league_mode(mode: String) -> String:
	return selection_startup_lifecycle.normalize_league_mode(mode)


func _normalize_runtime_character_id(value: Variant) -> String:
	return selection_startup_lifecycle.normalize_runtime_character_id(value)


func _configure_battle_window(owner: Object, module_getter: Callable) -> void:
	if owner == null or not owner.has_method("get_window"):
		return
	var view_layout: Object = _get_module(module_getter, "battle_view_layout")
	if view_layout != null and view_layout.has_method("configure_window"):
		view_layout.configure_window(owner.get_window())


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
