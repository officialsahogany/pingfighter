extends RefCounted

const EXPLOSION_METHOD := "resolve_explosion_rock_collision"
const PISTOL_ROCK_BOUNCE_METHOD := "resolve_pistol_projectile_rock_bounce"


static func destroy_projectile_impact_rocks(
	projectile: Dictionary,
	context: Dictionary,
	deps: Dictionary,
	weapon_id: String,
	explosion_radius: float
) -> int:
	if not (weapon_id in ["bazooka", "fire_support"]):
		return 0
	if int(context.get("current_stage", deps.get("current_stage", 1))) != 2:
		return 0
	var stage_context: Dictionary = context.duplicate()
	stage_context["current_stage"] = 2
	stage_context["source"] = "commando_firearm_%s" % weapon_id
	var center: Vector2 = _get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
	var hit_count := 0
	for rock_target in _get_stage2_rock_method_targets(deps, EXPLOSION_METHOD):
		hit_count += max(0, int(rock_target.call(EXPLOSION_METHOD, center, explosion_radius, deps, stage_context)))
	return hit_count


static func apply_pistol_rock_bounce(
	projectile: Dictionary,
	context: Dictionary,
	deps: Dictionary,
	is_pistol_projectile: bool
) -> Dictionary:
	if not is_pistol_projectile:
		return {}
	if int(context.get("current_stage", deps.get("current_stage", 1))) != 2:
		return {}
	var stage_context: Dictionary = context.duplicate()
	stage_context["current_stage"] = 2
	for rock_target in _get_stage2_rock_method_targets(deps, PISTOL_ROCK_BOUNCE_METHOD):
		var bounce_result: Dictionary = _get_dict(rock_target.call(PISTOL_ROCK_BOUNCE_METHOD, projectile, deps, stage_context))
		if bool(bounce_result.get("consumed", false)):
			return {"consumed": true}
		if not bool(bounce_result.get("bounced", false)):
			continue
		projectile.clear()
		projectile.merge(_get_dict(bounce_result.get("projectile", projectile)), true)
		return {"bounced": true}
	return {}


static func _get_stage2_rock_method_targets(deps: Dictionary, method_name: String) -> Array:
	var targets: Array = []
	_append_method_target(targets, deps.get("stage_background", null), method_name)
	_append_method_target(targets, deps.get("stage2_pillar_background", null), method_name)
	var registry_value: Variant = deps.get("registry", null)
	var registry: Object = registry_value if registry_value is Object else null
	_append_method_target(targets, _get_instance(registry, "stage2_pillar_background"), method_name)
	var router: Object = _get_instance(registry, "stage_runtime_router")
	if router != null and router.has_method("get_instance"):
		_append_method_target(targets, router.get_instance(registry, 2, "stage_background"), method_name)
	return targets


static func _append_method_target(targets: Array, candidate: Variant, method_name: String) -> void:
	if not (candidate is Object):
		return
	var candidate_obj: Object = candidate
	if not candidate_obj.has_method(method_name):
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


static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


static func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
