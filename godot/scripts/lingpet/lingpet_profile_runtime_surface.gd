extends RefCounted

var _runtime_surface_profile_id := 0
var _runtime_surface_cache_key: Array = []
var _runtime_surface_cache: Dictionary = {}
var _runtime_surface_build_count_for_tests := 0


func reset_runtime_surface_build_count_for_tests() -> void:
	_runtime_surface_build_count_for_tests = 0


func get_runtime_surface_build_count_for_tests() -> int:
	return _runtime_surface_build_count_for_tests


func get_required_hits(current_profile: Object, fallback: int) -> int:
	if current_profile == null or not current_profile.has_method("get_required_hits"):
		return maxi(0, fallback)
	return maxi(0, int(current_profile.call("get_required_hits", fallback)))


func get_catch_width(current_profile: Object, fallback: float) -> float:
	return get_stat_value(current_profile, "catch_width", fallback)


func get_catch_height(current_profile: Object, fallback: float) -> float:
	return get_stat_value(current_profile, "catch_height", fallback)


func get_stat_value(current_profile: Object, stat_key: String, fallback: float) -> float:
	if current_profile == null or not current_profile.has_method("get_stat"):
		return fallback
	return float(current_profile.call("get_stat", stat_key, fallback))


func get_hit_gauge_gain(current_profile: Object, fallback: float) -> float:
	if current_profile == null or not current_profile.has_method("get_hit_gauge_gain"):
		return fallback
	return float(current_profile.call("get_hit_gauge_gain", fallback))


func get_gauge_gain_bonus_pct(current_profile: Object, fallback: float = 0.0) -> float:
	if current_profile == null or not current_profile.has_method("get_gauge_gain_bonus_pct"):
		return fallback
	return float(current_profile.call("get_gauge_gain_bonus_pct", fallback))


func get_player_speed_bonus_pct(current_profile: Object, fallback: float = 0.0) -> float:
	if current_profile == null or not current_profile.has_method("get_player_speed_bonus_pct"):
		return fallback
	return float(current_profile.call("get_player_speed_bonus_pct", fallback))


func get_passive_skill(current_profile: Object, slot_index: int = 0) -> Dictionary:
	if current_profile == null or not current_profile.has_method("get_passive_skill"):
		return {}
	var passive_skill: Variant = current_profile.call("get_passive_skill") if slot_index <= 0 else current_profile.call("get_passive_skill", slot_index)
	if passive_skill is Dictionary:
		return passive_skill
	return {}


func get_passive_skills(current_profile: Object) -> Array[Dictionary]:
	if current_profile == null:
		return []
	if current_profile.has_method("get_passive_skills"):
		return _dictionary_array_from_variant(current_profile.call("get_passive_skills"))
	var primary := get_passive_skill(current_profile)
	var result: Array[Dictionary] = []
	if not primary.is_empty():
		result.append(primary)
	return result


func get_passive_skill_by_id(current_profile: Object, passive_id: String) -> Dictionary:
	if current_profile == null:
		return {}
	if current_profile.has_method("get_passive_skill_by_id"):
		var passive_skill: Variant = current_profile.call("get_passive_skill_by_id", passive_id)
		if passive_skill is Dictionary:
			return passive_skill
	var normalized := passive_id.strip_edges().to_lower()
	if normalized == "":
		return {}
	for passive in get_passive_skills(current_profile):
		if str(passive.get("id", "")).strip_edges().to_lower() == normalized:
			return passive
	return {}


func get_motion_style(current_profile: Object, fallback: String = "") -> String:
	if current_profile == null or not current_profile.has_method("get_motion_style"):
		return fallback
	return str(current_profile.call("get_motion_style"))


func get_active_skill_pool(current_profile: Object) -> Array[Dictionary]:
	if current_profile == null or not current_profile.has_method("get_active_skill_pool"):
		return []
	return _dictionary_array_from_variant(current_profile.call("get_active_skill_pool"))


func get_passive_skill_pool(current_profile: Object) -> Array[Dictionary]:
	if current_profile == null or not current_profile.has_method("get_passive_skill_pool"):
		return []
	return _dictionary_array_from_variant(current_profile.call("get_passive_skill_pool"))


func build_runtime_surface(
	current_profile: Object,
	required_hits_fallback: int,
	catch_width_fallback: float,
	catch_height_fallback: float,
	hit_gauge_gain_fallback: float
) -> Dictionary:
	var cache_key := _build_runtime_surface_cache_key(
		current_profile,
		required_hits_fallback,
		catch_width_fallback,
		catch_height_fallback,
		hit_gauge_gain_fallback
	)
	var profile_id := current_profile.get_instance_id() if current_profile != null else 0
	if profile_id != 0 and not cache_key.is_empty():
		if _runtime_surface_profile_id == profile_id and _runtime_surface_cache_key == cache_key:
			return _runtime_surface_cache
	var surface := {
		"required_hits": get_required_hits(current_profile, required_hits_fallback),
		"catch_width": get_catch_width(current_profile, catch_width_fallback),
		"catch_height": get_catch_height(current_profile, catch_height_fallback),
		"hit_gauge_gain": get_hit_gauge_gain(current_profile, hit_gauge_gain_fallback),
		"gauge_gain_bonus_pct": get_gauge_gain_bonus_pct(current_profile),
		"passive_skill": get_passive_skill(current_profile),
		"passive_skills": get_passive_skills(current_profile),
	}
	_runtime_surface_build_count_for_tests += 1
	if profile_id != 0 and not cache_key.is_empty():
		_runtime_surface_profile_id = profile_id
		_runtime_surface_cache_key = cache_key.duplicate(true)
		_runtime_surface_cache = surface
	return surface


func _build_runtime_surface_cache_key(
	current_profile: Object,
	required_hits_fallback: int,
	catch_width_fallback: float,
	catch_height_fallback: float,
	hit_gauge_gain_fallback: float
) -> Array:
	if current_profile == null or not current_profile.has_method("get_runtime_surface_cache_key"):
		return []
	var raw_key: Variant = current_profile.call("get_runtime_surface_cache_key")
	if not (raw_key is Array):
		return []
	var key: Array = (raw_key as Array).duplicate(true)
	key.append(required_hits_fallback)
	key.append(catch_width_fallback)
	key.append(catch_height_fallback)
	key.append(hit_gauge_gain_fallback)
	return key


func _dictionary_array_from_variant(raw_values: Variant) -> Array[Dictionary]:
	var values: Array[Dictionary] = []
	if not (raw_values is Array):
		return values
	for raw_value in raw_values:
		if raw_value is Dictionary:
			values.append(raw_value)
	return values
