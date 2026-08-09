extends RefCounted

var _surface_cache: Dictionary = {}
var _surface_cache_valid := false
var _surface_cache_process_frame := -1
var _surface_cache_physics_frame := -1
var _surface_build_count_for_tests := 0
var _static_surface_cache: Dictionary = {}
var _static_surface_key: Array = []
var _static_surface_build_count_for_tests := 0


func get_surface(
	state: String,
	guardian_summoned: bool,
	current_profile: Object,
	mount_state: Object,
	active_skill_slot_resolver: Object,
	companion_skill_persistence: Object,
	companion_skill_states: Array,
	skill_runtime_host: Object,
	skill_runtime_surface: Object,
	default_windup_seconds: float,
	flash_seconds: float
) -> Dictionary:
	var process_frame := int(Engine.get_process_frames())
	var physics_frame := int(Engine.get_physics_frames())
	if (
		_surface_cache_valid
		and _surface_cache_process_frame == process_frame
		and _surface_cache_physics_frame == physics_frame
	):
		return _surface_cache
	_surface_cache = _build_surface_uncached(
		state,
		guardian_summoned,
		current_profile,
		mount_state,
		active_skill_slot_resolver,
		companion_skill_persistence,
		companion_skill_states,
		skill_runtime_host,
		skill_runtime_surface,
		default_windup_seconds,
		flash_seconds
	)
	_surface_cache_valid = true
	_surface_cache_process_frame = process_frame
	_surface_cache_physics_frame = physics_frame
	return _surface_cache


func build_interaction_permit_projection(
	current_profile: Object,
	mount_state: Object
) -> Dictionary:
	var projection: Dictionary = {}
	var mounted := false
	if mount_state != null and mount_state.has_method("is_mounted"):
		mounted = bool(mount_state.is_mounted())
	for slot_index in range(2):
		var suffix := "" if slot_index == 0 else "_1"
		var slot_is_permit := false
		if current_profile != null and current_profile.has_method("is_interaction_permit_for_slot"):
			slot_is_permit = bool(current_profile.is_interaction_permit_for_slot(slot_index))
		projection["companion_skill_activation_model%s" % suffix] = "interaction_permit" if slot_is_permit else "launch"
		projection["companion_skill_interaction_available%s" % suffix] = slot_is_permit
		projection["companion_skill_interaction_active%s" % suffix] = slot_is_permit and mounted
	return projection


func invalidate_frame_cache() -> void:
	_surface_cache_valid = false
	_surface_cache = {}


func reset_build_counters_for_tests() -> void:
	_surface_build_count_for_tests = 0
	_static_surface_build_count_for_tests = 0
	invalidate_frame_cache()


func get_surface_build_count_for_tests() -> int:
	return _surface_build_count_for_tests


func get_static_surface_build_count_for_tests() -> int:
	return _static_surface_build_count_for_tests


func _build_surface_uncached(
	state: String,
	guardian_summoned: bool,
	current_profile: Object,
	mount_state: Object,
	active_skill_slot_resolver: Object,
	companion_skill_persistence: Object,
	companion_skill_states: Array,
	skill_runtime_host: Object,
	skill_runtime_surface: Object,
	default_windup_seconds: float,
	flash_seconds: float
) -> Dictionary:
	_surface_build_count_for_tests += 1
	if skill_runtime_surface == null:
		return build_interaction_permit_projection(current_profile, mount_state)
	var active_slot_count := int(skill_runtime_surface.get_active_slot_count(
		current_profile,
		active_skill_slot_resolver,
		skill_runtime_host
	))
	var primary_surface: Dictionary = skill_runtime_surface.get_active_surface_for_slot(
		current_profile,
		active_skill_slot_resolver,
		companion_skill_persistence,
		companion_skill_states,
		skill_runtime_host,
		default_windup_seconds,
		0,
		active_slot_count
	)
	var second_surface: Dictionary = skill_runtime_surface.get_second_active_surface(
		current_profile,
		active_skill_slot_resolver,
		companion_skill_persistence,
		companion_skill_states,
		skill_runtime_host,
		default_windup_seconds,
		active_slot_count
	)
	var permit_projection := build_interaction_permit_projection(current_profile, mount_state)
	var surface := _get_static_surface(
		state,
		guardian_summoned,
		primary_surface,
		second_surface,
		active_slot_count,
		permit_projection
	)
	var primary_active := _is_slot_active(guardian_summoned, primary_surface, active_slot_count, 0)
	var second_active := _is_slot_active(guardian_summoned, second_surface, active_slot_count, 1)
	_merge_slot_dynamic(surface, primary_surface, "", primary_active, flash_seconds)
	_merge_slot_dynamic(surface, second_surface, "_1", second_active, flash_seconds)
	var primary_skill_id := str(primary_surface.get("skill_id", "")) if primary_active else ""
	_merge_skill_runtime_snapshot(surface, skill_runtime_host, primary_skill_id)
	var second_skill_id := str(second_surface.get("skill_id", "")) if second_active else ""
	if second_skill_id != "" and second_skill_id != primary_skill_id:
		_merge_skill_runtime_snapshot(surface, skill_runtime_host, second_skill_id)
	# Empty-slot dynamic defaults must not overwrite the shared permit projection.
	surface.merge(permit_projection, true)
	return surface


func _get_static_surface(
	state: String,
	guardian_summoned: bool,
	primary_surface: Dictionary,
	second_surface: Dictionary,
	active_slot_count: int,
	permit_projection: Dictionary
) -> Dictionary:
	var primary_active := _is_slot_active(guardian_summoned, primary_surface, active_slot_count, 0)
	var second_active := _is_slot_active(guardian_summoned, second_surface, active_slot_count, 1)
	var static_key := [
		state,
		active_slot_count,
		_build_slot_static_key(primary_surface, primary_active, permit_projection, ""),
		_build_slot_static_key(second_surface, second_active, permit_projection, "_1"),
	]
	if not _static_surface_key.is_empty() and _static_surface_key == static_key:
		return _static_surface_cache.duplicate()
	var surface: Dictionary = {}
	_merge_slot_static(surface, primary_surface, "", primary_active)
	_merge_slot_static(surface, second_surface, "_1", second_active)
	_static_surface_key = static_key.duplicate(true)
	_static_surface_cache = surface
	_static_surface_build_count_for_tests += 1
	return surface.duplicate()


func _build_slot_static_key(
	skill_surface: Dictionary,
	active: bool,
	permit_projection: Dictionary,
	suffix: String
) -> Array:
	var active_skill := _as_dictionary(skill_surface.get("active_skill", {}))
	return [
		active,
		str(active_skill.get("id", "")) if active else "",
		str(active_skill.get("name", "")) if active else "",
		str(active_skill.get("description", "")) if active else "",
		float(active_skill.get("cooldown", 0.0)) if active else 0.0,
		str(active_skill.get("card_texture_path", "")) if active else "",
		str(permit_projection.get("companion_skill_activation_model%s" % suffix, "launch")),
		bool(permit_projection.get("companion_skill_interaction_available%s" % suffix, false)),
		bool(permit_projection.get("companion_skill_interaction_active%s" % suffix, false)),
	]


func _merge_slot_static(
	surface: Dictionary,
	skill_surface: Dictionary,
	suffix: String,
	active: bool
) -> void:
	var active_skill := _as_dictionary(skill_surface.get("active_skill", {}))
	surface["companion_skill_id%s" % suffix] = str(active_skill.get("id", "")) if active else ""
	surface["companion_skill_name%s" % suffix] = str(active_skill.get("name", "")) if active else ""
	surface["companion_skill_description%s" % suffix] = str(active_skill.get("description", "")) if active else ""
	surface["companion_skill_card_path%s" % suffix] = str(active_skill.get("card_texture_path", "")) if active else ""
	surface["companion_skill_cooldown_duration%s" % suffix] = float(active_skill.get("cooldown", 0.0)) if active else 0.0


func _merge_slot_dynamic(
	surface: Dictionary,
	skill_surface: Dictionary,
	suffix: String,
	active: bool,
	flash_seconds: float
) -> void:
	var skill_state: Object = skill_surface.get("skill_state", null) as Object
	var active_skill := _as_dictionary(skill_surface.get("active_skill", {}))
	var skill_id := str(active_skill.get("id", "")) if active else ""
	var cooldown_duration := float(active_skill.get("cooldown", 0.0)) if active else 0.0
	var windup_seconds := float(skill_surface.get("windup_seconds", 0.0)) if active else 0.0
	if skill_state != null and skill_state.has_method("get_snapshot"):
		var raw_snapshot: Variant = skill_state.get_snapshot(
			active,
			skill_id,
			cooldown_duration,
			windup_seconds,
			flash_seconds,
			suffix
		)
		if raw_snapshot is Dictionary:
			surface.merge(raw_snapshot as Dictionary, true)
			return
	surface.merge(_empty_skill_state_snapshot(suffix), true)


func _merge_skill_runtime_snapshot(
	surface: Dictionary,
	skill_runtime_host: Object,
	skill_id: String
) -> void:
	var normalized := skill_id.strip_edges()
	if normalized == "":
		return
	if skill_runtime_host == null or not skill_runtime_host.has_method("get_snapshot_for_skill_id"):
		return
	var raw_snapshot: Variant = skill_runtime_host.get_snapshot_for_skill_id(normalized)
	if raw_snapshot is Dictionary:
		surface.merge(raw_snapshot as Dictionary, true)


func _is_slot_active(
	guardian_summoned: bool,
	skill_surface: Dictionary,
	active_slot_count: int,
	slot_index: int
) -> bool:
	if not guardian_summoned or slot_index >= active_slot_count:
		return false
	var active_skill := _as_dictionary(skill_surface.get("active_skill", {}))
	return str(active_skill.get("id", "")) != "" and bool(active_skill.get("enabled", true))


func _empty_skill_state_snapshot(suffix: String) -> Dictionary:
	return {
		"companion_skill_cooldown%s" % suffix: 0.0,
		"companion_skill_cooldown_duration%s" % suffix: 0.0,
		"companion_skill_windup_seconds%s" % suffix: 0.0,
		"companion_skill_windup_ratio%s" % suffix: 0.0,
		"companion_skill_ready%s" % suffix: false,
		"companion_skill_last_gain%s" % suffix: 0.0,
		"companion_skill_trigger_count%s" % suffix: 0,
		"companion_skill_flash_timer%s" % suffix: 0.0,
		"companion_skill_flash_ratio%s" % suffix: 0.0,
		"companion_skill_winding_up%s" % suffix: false,
		"companion_skill_origin%s" % suffix: Vector2.ZERO,
		"companion_skill_activation_model%s" % suffix: "launch",
		"companion_skill_interaction_available%s" % suffix: false,
		"companion_skill_interaction_active%s" % suffix: false,
	}


func _as_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value as Dictionary
	return {}
