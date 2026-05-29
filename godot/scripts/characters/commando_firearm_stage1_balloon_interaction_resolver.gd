extends RefCounted

const BALLOON_HIT_METHOD := "resolve_commando_bullet_collision"
const BULLET_POP_WEAPON_IDS := ["pistol", "commando_pistol", "ak47"]


static func pop_balloon_for_projectile(
	projectile: Dictionary,
	context: Dictionary,
	deps: Dictionary,
	weapon_id: String,
	base_weapon_id: String
) -> Dictionary:
	if not _is_balloon_pop_weapon(weapon_id, base_weapon_id):
		return {}
	if int(context.get("current_stage", deps.get("current_stage", 1))) != 1:
		return {}

	var stage_context := context.duplicate()
	stage_context["current_stage"] = 1
	for target in _get_stage1_balloon_targets(deps):
		var pop_result: Dictionary = _get_dict(target.call(BALLOON_HIT_METHOD, projectile, stage_context, deps))
		if not bool(pop_result.get("commando_firearm_balloon_popped", false)):
			continue
		return pop_result
	return {}


static func _is_balloon_pop_weapon(weapon_id: String, base_weapon_id: String) -> bool:
	if weapon_id == base_weapon_id:
		return true
	return weapon_id in BULLET_POP_WEAPON_IDS


static func _get_stage1_balloon_targets(deps: Dictionary) -> Array:
	var targets: Array = []
	_append_method_target(targets, deps.get("stage1_balloon_event", null))
	var registry_value: Variant = deps.get("registry", null)
	var registry: Object = registry_value if registry_value is Object else null
	_append_method_target(targets, _get_instance(registry, "stage1_balloon_event"))
	return targets


static func _append_method_target(targets: Array, candidate: Variant) -> void:
	if not (candidate is Object):
		return
	var candidate_obj: Object = candidate
	if not candidate_obj.has_method(BALLOON_HIT_METHOD):
		return
	var candidate_id: int = candidate_obj.get_instance_id()
	for existing in targets:
		if not (existing is Object):
			continue
		var existing_obj: Object = existing
		if existing_obj.get_instance_id() == candidate_id:
			return
	targets.append(candidate_obj)


static func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or key == "" or not registry.has_method("get_instance"):
		return null
	var value: Variant = registry.get_instance(key)
	return value if value is Object else null


static func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
