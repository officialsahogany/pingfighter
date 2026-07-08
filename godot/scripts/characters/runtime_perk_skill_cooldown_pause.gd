extends RefCounted

var active := false
var owner: Object = null
var registry: Object = null


func pause_from_runtime_state(runtime_state: Object, next_owner: Object, next_registry: Object) -> void:
	var helper: Object = _get_state_object(runtime_state, "_skill_cooldown_pause")
	if helper != null and helper.has_method("pause"):
		helper.pause(next_owner, next_registry)


func resume_from_runtime_state(runtime_state: Object) -> void:
	var helper: Object = _get_state_object(runtime_state, "_skill_cooldown_pause")
	if helper != null and helper.has_method("resume"):
		helper.resume()


func reset() -> void:
	resume()


func pause(next_owner: Object, next_registry: Object) -> void:
	if active or next_owner == null or next_registry == null:
		return
	var skill_tooltip_driver: Object = _get_instance(next_registry, "battle_scene_skill_tooltip_driver")
	if skill_tooltip_driver == null or not skill_tooltip_driver.has_method("pause_skill_cooldowns"):
		return
	skill_tooltip_driver.pause_skill_cooldowns(next_owner, next_registry)
	active = true
	owner = next_owner
	registry = next_registry


func resume() -> void:
	if not active:
		return
	var pause_owner: Object = owner
	var pause_registry: Object = registry
	active = false
	owner = null
	registry = null
	var skill_tooltip_driver: Object = _get_instance(pause_registry, "battle_scene_skill_tooltip_driver")
	if skill_tooltip_driver != null and skill_tooltip_driver.has_method("resume_skill_cooldowns"):
		skill_tooltip_driver.resume_skill_cooldowns(pause_owner, pause_registry)


func is_active() -> bool:
	return active


func _get_instance(source_registry: Object, key: String) -> Object:
	if source_registry == null or key == "" or not source_registry.has_method("get_instance"):
		return null
	return source_registry.get_instance(key)


func _get_state_object(runtime_state: Object, field_name: String) -> Object:
	if runtime_state == null:
		return null
	var value: Variant = runtime_state.get(field_name)
	if value is Object:
		return value
	return null
