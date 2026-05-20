extends RefCounted


func initialize_battle(
	flow: Object,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	play_stage_bgm: bool = true
) -> void:
	if flow == null or bool(flow.get("_battle_initialized")):
		return
	var lifecycle: Object = _get_module(module_getter, "battle_scene_lifecycle")
	if lifecycle != null:
		lifecycle.initialize(owner, registry, {"play_stage_bgm_on_initialize": play_stage_bgm})
	flow.set("_battle_initialized", true)
	flow.set("_battle_bgm_started", play_stage_bgm)


func _get_module(module_getter: Callable, key: String) -> Object:
	if not module_getter.is_valid():
		return null
	var value: Variant = module_getter.call(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null
