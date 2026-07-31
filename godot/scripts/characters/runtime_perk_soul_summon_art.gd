extends RefCounted

const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")


static func apply_acquired(owner: Object, registry: Object) -> Dictionary:
	var runtime: Object = _get_instance(registry, "lingpet_egg_runtime")
	if runtime == null:
		return {"dropped": false, "skipped_reason": "missing_lingpet_runtime"}
	if not runtime.has_method("deploy_soul_summon_egg"):
		return {"dropped": false, "skipped_reason": "missing_drop_surface"}
	var result: Variant = runtime.deploy_soul_summon_egg(owner, registry)
	if result is Dictionary:
		return result
	return {"dropped": bool(result), "skipped_reason": "" if bool(result) else "deploy_rejected"}


static func apply_removed(owner: Object, registry: Object) -> Dictionary:
	var runtime: Object = _get_instance(registry, "lingpet_egg_runtime")
	if runtime == null or not runtime.has_method("on_soul_summon_art_removed"):
		return {"stowed": false, "skipped_reason": "missing_lingpet_runtime"}
	var result: Variant = runtime.on_soul_summon_art_removed(owner, registry)
	if result is Dictionary:
		return result
	return {"stowed": bool(result)}


static func is_soul_summon_skill(skill_id: String) -> bool:
	return skill_id == CommonSkillCatalog.SOUL_SUMMON_ART_ID


static func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
