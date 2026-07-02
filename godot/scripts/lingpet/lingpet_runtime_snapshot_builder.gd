extends RefCounted

const STATE_NONE := "none"
const STATE_COMPANION := "companion"

# Last values pushed to the owner by sync_owner. The per-tick sync used to
# issue ~83 unconditional owner.set() calls (plus per-tick array duplicates)
# and measured 0.32ms/tick standing — 38% of the whole lingpet update. Only
# keys whose value changed are pushed now; volatile keys (companion_pos,
# running cooldowns) pass naturally. The cache rebases when the owner
# instance changes (new battle scene) and on the loadout-invalidate boundary
# (pet adopt/switch, level-up, loadout apply, resets) via
# invalidate_sync_cache(). Container values are cached as detached copies so
# external mutation of an owner-held array/dict can never alias the cache.
var _pushed_owner_id := 0
var _pushed_values: Dictionary = {}
var _owner_static_surface_key: Array = []
var _owner_static_surface_build_count_for_tests := 0


func invalidate_sync_cache() -> void:
	_pushed_owner_id = 0
	_pushed_values = {}
	_owner_static_surface_key = []


func reset_owner_sync_build_counters_for_tests() -> void:
	_owner_static_surface_build_count_for_tests = 0


func get_owner_static_surface_build_count_for_tests() -> int:
	return _owner_static_surface_build_count_for_tests


# Public gated setters for owner keys that the egg runtime computes itself
# (appearance rate, affinity, bond) and syncs right after sync_owner in the
# same tick — they share the same change-gated last-pushed cache so they are
# also skipped on stable ticks.
func set_owner_value_gated(owner: Object, key: String, value: Variant) -> void:
	if owner == null:
		return
	_rebase_for_owner(owner)
	_set_single(owner, key, value)


func set_owner_pair_gated(owner: Object, lingpet_key: String, ringpet_key: String, value: Variant) -> void:
	if owner == null:
		return
	_rebase_for_owner(owner)
	_set_pair(owner, lingpet_key, ringpet_key, value)


func _rebase_for_owner(owner: Object) -> void:
	var owner_id: int = owner.get_instance_id()
	if owner_id != _pushed_owner_id:
		_pushed_owner_id = owner_id
		_pushed_values = {}
		_owner_static_surface_key = []


func build_runtime_snapshot(
	pet_id: String,
	state: String,
	required_hits: int,
	companion_pos: Vector2,
	catch_width: float,
	catch_height: float,
	active_skill: Dictionary,
	hatch_flash_timer: float,
	owned_pet_ids: Array,
	battle_slot_pet_ids: Array,
	active_slot_index: int,
	gauge_gain_bonus_pct: float,
	egg_state: Object,
	motion_state: Object,
	patrol_speed_default: float,
	patrol_speed_min: float,
	patrol_speed_max: float,
	defense_rate: float,
	body_hit_state: Object,
	hit_gauge_gain: float,
	skill_state: Object,
	skill_windup_seconds: float,
	skill_flash_seconds: float,
	skill_runtime_host: Object,
	second_active_skill: Dictionary = {},
	second_skill_state: Object = null,
	second_skill_windup_seconds: float = 0.0,
	loadouts_by_pet_id: Dictionary = {},
	active_skill_pool: Array[Dictionary] = [],
	passive_skill: Dictionary = {},
	passive_skill_pool: Array[Dictionary] = []
) -> Dictionary:
	var companion_active: bool = state == STATE_COMPANION
	var raw_skill_id := str(active_skill.get("id", ""))
	var skill_enabled := raw_skill_id != "" and bool(active_skill.get("enabled", true))
	var skill_active := companion_active and skill_enabled
	var skill_id := raw_skill_id if skill_active else ""
	var skill_name := str(active_skill.get("name", ""))
	var skill_description := str(active_skill.get("description", ""))
	var skill_cooldown := float(active_skill.get("cooldown", 0.0))
	var skill_level := int(active_skill.get("level", 1)) if skill_active else 0
	var skill_max_level := int(active_skill.get("max_level", 5)) if skill_active else 0
	var second_raw_skill_id := str(second_active_skill.get("id", ""))
	var second_skill_enabled := second_raw_skill_id != "" and bool(second_active_skill.get("enabled", true))
	var second_skill_active := companion_active and second_skill_enabled
	var second_skill_id := second_raw_skill_id if second_skill_active else ""
	var second_skill_name := str(second_active_skill.get("name", "")) if second_skill_active else ""
	var second_skill_description := str(second_active_skill.get("description", "")) if second_skill_active else ""
	var second_skill_cooldown := float(second_active_skill.get("cooldown", 0.0)) if second_skill_active else 0.0
	var second_skill_level := int(second_active_skill.get("level", 1)) if second_skill_active else 0
	var second_skill_max_level := int(second_active_skill.get("max_level", 5)) if second_skill_active else 0
	var passive_enabled := companion_active and not passive_skill.is_empty() and bool(passive_skill.get("enabled", true))
	var passive_id := str(passive_skill.get("id", "")) if passive_enabled else ""
	var passive_level := int(passive_skill.get("level", 1)) if passive_enabled else 0
	var passive_max_level := int(passive_skill.get("max_level", 5)) if passive_enabled else 0
	var player_speed_bonus_pct := maxf(0.0, float(passive_skill.get("player_speed_bonus_pct", 0.0))) if passive_enabled else 0.0
	var starpoint_tracking_chance_pct := maxf(0.0, float(passive_skill.get("starpoint_tracking_chance_pct", 0.0))) if passive_enabled else 0.0
	var ring_dash_chance_pct := maxf(0.0, float(passive_skill.get("ring_dash_chance_pct", 0.0))) if passive_enabled else 0.0
	var snapshot := {
		"pet_id": pet_id,
		"state": state,
		"required_hits": required_hits,
		"companion_pos": companion_pos,
		"companion_catch_width": catch_width,
		"companion_catch_height": catch_height,
		"companion_skill_id": skill_id if skill_active else "",
		"companion_skill_name": skill_name if skill_active else "",
		"companion_skill_description": skill_description if skill_active else "",
		"companion_skill_card_path": str(active_skill.get("card_texture_path", "")) if skill_active else "",
		"companion_skill_icon_path": str(active_skill.get("icon_texture_path", "")) if skill_active else "",
		"companion_skill_level": skill_level if skill_active else 0,
		"companion_skill_max_level": skill_max_level if skill_active else 0,
		"companion_skill_id_1": second_skill_id,
		"companion_skill_name_1": second_skill_name,
		"companion_skill_description_1": second_skill_description,
		"companion_skill_card_path_1": str(second_active_skill.get("card_texture_path", "")) if second_skill_active else "",
		"companion_skill_icon_path_1": str(second_active_skill.get("icon_texture_path", "")) if second_skill_active else "",
		"companion_skill_level_1": second_skill_level,
		"companion_skill_max_level_1": second_skill_max_level,
		"companion_active_skill_pool_ids": _get_skill_ids(active_skill_pool) if companion_active else [],
		"companion_passive_skill_id": passive_id,
		"companion_passive_skill_name": str(passive_skill.get("name", "")) if passive_enabled else "",
		"companion_passive_skill_description": str(passive_skill.get("description", "")) if passive_enabled else "",
		"companion_passive_skill_icon_path": str(passive_skill.get("icon_texture_path", "")) if passive_enabled else "",
		"companion_passive_skill_level": passive_level,
		"companion_passive_skill_max_level": passive_max_level,
		"companion_passive_skill_pool_ids": _get_skill_ids(passive_skill_pool) if companion_active else [],
		"companion_starpoint_tracking_chance_pct": starpoint_tracking_chance_pct,
		"companion_ring_dash_chance_pct": ring_dash_chance_pct,
		"hatch_flash_timer": hatch_flash_timer,
		"owned_pet_ids": owned_pet_ids.duplicate(),
		"battle_slot_pet_ids": battle_slot_pet_ids.duplicate(),
		"lingpet_slots": battle_slot_pet_ids.duplicate(),
		"lingpet_loadouts": loadouts_by_pet_id.duplicate(true),
		"ringpet_loadouts": loadouts_by_pet_id.duplicate(true),
		"active_slot_index": active_slot_index,
		"active_pet_id": pet_id if companion_active else "",
		"active_skill_id": skill_id if skill_active else "",
		"active_skill_level": skill_level if skill_active else 0,
		"passive_skill_id": passive_id,
		"passive_skill_level": passive_level,
		"companion_player_speed_bonus_pct": player_speed_bonus_pct,
		"gauge_gain_bonus_pct": gauge_gain_bonus_pct if companion_active else 0.0,
	}
	if egg_state != null:
		snapshot.merge(egg_state.get_snapshot(), true)
	if motion_state != null:
		snapshot.merge(motion_state.get_snapshot(
			patrol_speed_default,
			patrol_speed_min,
			patrol_speed_max,
			defense_rate if companion_active else 0.0
		), true)
	if body_hit_state != null:
		snapshot.merge(body_hit_state.get_snapshot(companion_active, hit_gauge_gain), true)
	if skill_state != null:
		snapshot.merge(skill_state.get_snapshot(skill_active, skill_id, skill_cooldown, skill_windup_seconds, skill_flash_seconds), true)
	snapshot.merge(_build_second_skill_state_snapshot(
		second_skill_state,
		second_skill_active,
		second_skill_id,
		second_skill_cooldown,
		second_skill_windup_seconds,
		skill_flash_seconds
	), true)
	if skill_runtime_host != null:
		snapshot.merge(skill_runtime_host.get_snapshot(), true)
	return snapshot


func build_save_snapshot(
	version: int,
	pet_id: String,
	state: String,
	hatch_hits: int,
	required_hits: int,
	egg_pos: Vector2,
	egg_color_index: int,
	companion_pos: Vector2,
	owned_pet_ids: Array,
	battle_slot_pet_ids: Array,
	active_slot_index: int,
	gauge_gain_bonus_pct: float,
	motion_state: Object,
	loadouts_by_pet_id: Dictionary = {},
	affinity_run_state: Dictionary = {}
) -> Dictionary:
	var companion_active: bool = state == STATE_COMPANION
	var snapshot := {
		"version": version,
		"pet_id": pet_id,
		"state": state,
		"hatch_hits": hatch_hits,
		"required_hits": required_hits,
		"egg_pos": egg_pos,
		"egg_color_index": egg_color_index,
		"companion_pos": companion_pos,
		"owned_pet_ids": owned_pet_ids.duplicate(),
		"battle_slot_pet_ids": battle_slot_pet_ids.duplicate(),
		"lingpet_slots": battle_slot_pet_ids.duplicate(),
		"lingpet_loadouts": loadouts_by_pet_id.duplicate(true),
		"ringpet_loadouts": loadouts_by_pet_id.duplicate(true),
		"active_slot_index": active_slot_index,
		"active_pet_id": pet_id if companion_active else "",
		"gauge_gain_bonus_pct": gauge_gain_bonus_pct if companion_active else 0.0,
		# Run-scoped affinity progression (per-pet affinity + run-global ring core tier
		# + chips + feed). Carried so an in-run save/restore round trip does not wipe it.
		"affinity_run_state": affinity_run_state.duplicate(true),
	}
	if motion_state != null:
		snapshot.merge(motion_state.get_save_snapshot(), true)
	return snapshot


func sync_owner(
	owner: Object,
	pet_id: String,
	state: String,
	hatch_hits: int,
	required_hits: int,
	egg_pos: Vector2,
	companion_pos: Vector2,
	patrol_speed_default: float,
	patrol_speed_min: float,
	patrol_speed_max: float,
	catch_width: float,
	catch_height: float,
	defense_rate: float,
	battle_slot_pet_ids: Array,
	active_slot_index: int,
	motion_state: Object,
	body_hit_state: Object,
	hit_gauge_gain: float,
	active_skill: Dictionary,
	skill_state: Object,
	second_active_skill: Dictionary,
	second_skill_state: Object,
	second_skill_windup_seconds: float,
	gauge_gain_bonus_pct: float,
	effect_text: String,
	loadouts_by_pet_id: Dictionary = {},
	passive_skill: Dictionary = {},
	sync_loadouts: bool = true
) -> void:
	if owner == null:
		return
	_rebase_for_owner(owner)
	var companion_active: bool = state == STATE_COMPANION
	var public_pet_id: String = pet_id if companion_active else ""
	var raw_skill_id := str(active_skill.get("id", ""))
	var skill_enabled := raw_skill_id != "" and bool(active_skill.get("enabled", true))
	var skill_active := companion_active and skill_enabled
	var skill_id := raw_skill_id if skill_active else ""
	var skill_name := str(active_skill.get("name", "")) if skill_active else ""
	var skill_cooldown := float(active_skill.get("cooldown", 0.0)) if skill_active else 0.0
	var skill_level := int(active_skill.get("level", 1)) if skill_active else 0
	var skill_max_level := int(active_skill.get("max_level", 5)) if skill_active else 0
	var second_raw_skill_id := str(second_active_skill.get("id", ""))
	var second_skill_enabled := second_raw_skill_id != "" and bool(second_active_skill.get("enabled", true))
	var second_skill_active := companion_active and second_skill_enabled
	var second_skill_id := second_raw_skill_id if second_skill_active else ""
	var second_skill_name := str(second_active_skill.get("name", "")) if second_skill_active else ""
	var second_skill_cooldown := float(second_active_skill.get("cooldown", 0.0)) if second_skill_active else 0.0
	var second_skill_level := int(second_active_skill.get("level", 1)) if second_skill_active else 0
	var second_skill_max_level := int(second_active_skill.get("max_level", 5)) if second_skill_active else 0
	var passive_enabled := companion_active and not passive_skill.is_empty() and bool(passive_skill.get("enabled", true))
	var passive_id := str(passive_skill.get("id", "")) if passive_enabled else ""
	var player_speed_bonus_pct := maxf(0.0, float(passive_skill.get("player_speed_bonus_pct", 0.0))) if companion_active else 0.0
	var static_surface_key := _build_owner_static_surface_key(
		public_pet_id,
		state,
		hatch_hits,
		required_hits,
		egg_pos,
		patrol_speed_default,
		patrol_speed_min,
		patrol_speed_max,
		catch_width,
		catch_height,
		defense_rate if companion_active else 0.0,
		battle_slot_pet_ids,
		active_slot_index,
		skill_id,
		skill_name,
		skill_cooldown,
		skill_level,
		skill_max_level,
		second_skill_id,
		second_skill_name,
		second_skill_cooldown,
		second_skill_level,
		second_skill_max_level,
		passive_id,
		passive_skill,
		passive_enabled,
		gauge_gain_bonus_pct if companion_active else 0.0,
		player_speed_bonus_pct,
		effect_text,
		loadouts_by_pet_id if sync_loadouts else {},
		sync_loadouts
	)
	if _should_sync_owner_static_surface(static_surface_key):
		_set_single(owner, "lingpet_id", public_pet_id)
		_set_single(owner, "active_lingpet_id", public_pet_id if companion_active else "")
		_set_single(owner, "current_lingpet_id", public_pet_id)
		_set_pair(owner, "lingpet_slots", "ringpet_slots", battle_slot_pet_ids)
		_set_pair(owner, "lingpet_slot_pet_ids", "ringpet_slot_pet_ids", battle_slot_pet_ids)
		if sync_loadouts:
			_set_pair(owner, "lingpet_loadouts", "ringpet_loadouts", loadouts_by_pet_id)
		_set_pair(owner, "lingpet_active_slot_index", "ringpet_active_slot_index", active_slot_index)
		_set_pair(owner, "lingpet_state", "ringpet_state", state)
		_set_pair(owner, "lingpet_hatch_hits", "ringpet_hatch_hits", hatch_hits)
		_set_pair(owner, "lingpet_hatch_required_hits", "ringpet_hatch_required_hits", required_hits)
		_set_single(owner, "lingpet_egg_pos", egg_pos)
		_set_pair(owner, "lingpet_companion_patrol_speed_default", "ringpet_companion_patrol_speed_default", patrol_speed_default)
		_set_pair(owner, "lingpet_companion_patrol_speed_min", "ringpet_companion_patrol_speed_min", patrol_speed_min)
		_set_pair(owner, "lingpet_companion_patrol_speed_max", "ringpet_companion_patrol_speed_max", patrol_speed_max)
		_set_pair(owner, "lingpet_companion_catch_width", "ringpet_companion_catch_width", catch_width)
		_set_pair(owner, "lingpet_companion_catch_height", "ringpet_companion_catch_height", catch_height)
		_set_pair(owner, "lingpet_companion_defense_rate", "ringpet_companion_defense_rate", defense_rate if companion_active else 0.0)
		_sync_skill_static_owner(owner, skill_id, skill_name, skill_cooldown, skill_active, skill_level, skill_max_level)
		_sync_second_skill_static_owner(owner, second_skill_id, second_skill_name, second_skill_cooldown, second_skill_active, second_skill_level, second_skill_max_level)
		_sync_passive_owner(owner, passive_id, passive_skill, passive_enabled)
		_set_pair(owner, "lingpet_gauge_gain_bonus_pct", "ringpet_gauge_gain_bonus_pct", gauge_gain_bonus_pct if companion_active else 0.0)
		_set_pair(owner, "lingpet_player_speed_bonus_pct", "ringpet_player_speed_bonus_pct", player_speed_bonus_pct)
		_set_single(owner, "lingpet_effect_text", effect_text)
	_set_pair(owner, "lingpet_companion_pos", "ringpet_companion_pos", companion_pos)
	_sync_motion_owner(owner, motion_state)
	_sync_body_hit_owner(owner, body_hit_state, hit_gauge_gain if companion_active else 0.0)
	_sync_skill_runtime_owner(owner, skill_state, skill_id, skill_active)
	_sync_second_skill_runtime_owner(owner, second_skill_state, second_skill_id, second_skill_active, second_skill_windup_seconds)


func _build_owner_static_surface_key(
	public_pet_id: String,
	state: String,
	hatch_hits: int,
	required_hits: int,
	egg_pos: Vector2,
	patrol_speed_default: float,
	patrol_speed_min: float,
	patrol_speed_max: float,
	catch_width: float,
	catch_height: float,
	defense_rate: float,
	battle_slot_pet_ids: Array,
	active_slot_index: int,
	skill_id: String,
	skill_name: String,
	skill_cooldown_duration: float,
	skill_level: int,
	skill_max_level: int,
	second_skill_id: String,
	second_skill_name: String,
	second_skill_cooldown_duration: float,
	second_skill_level: int,
	second_skill_max_level: int,
	passive_id: String,
	passive_skill: Dictionary,
	passive_enabled: bool,
	gauge_gain_bonus_pct: float,
	player_speed_bonus_pct: float,
	effect_text: String,
	loadouts_by_pet_id: Dictionary,
	sync_loadouts: bool
) -> Array:
	return [
		public_pet_id,
		state,
		hatch_hits,
		required_hits,
		egg_pos,
		patrol_speed_default,
		patrol_speed_min,
		patrol_speed_max,
		catch_width,
		catch_height,
		defense_rate,
		battle_slot_pet_ids,
		active_slot_index,
		skill_id,
		skill_name,
		skill_cooldown_duration,
		skill_level,
		skill_max_level,
		second_skill_id,
		second_skill_name,
		second_skill_cooldown_duration,
		second_skill_level,
		second_skill_max_level,
		passive_id,
		int(passive_skill.get("level", 1)) if passive_enabled else 0,
		int(passive_skill.get("max_level", 5)) if passive_enabled else 0,
		str(passive_skill.get("name", "")) if passive_enabled else "",
		str(passive_skill.get("description", "")) if passive_enabled else "",
		str(passive_skill.get("icon_texture_path", "")) if passive_enabled else "",
		maxf(0.0, float(passive_skill.get("starpoint_tracking_chance_pct", 0.0))) if passive_enabled else 0.0,
		maxf(0.0, float(passive_skill.get("ring_dash_chance_pct", 0.0))) if passive_enabled else 0.0,
		gauge_gain_bonus_pct,
		player_speed_bonus_pct,
		effect_text,
		sync_loadouts,
		loadouts_by_pet_id if sync_loadouts else {},
	]


func _should_sync_owner_static_surface(static_surface_key: Array) -> bool:
	if not _owner_static_surface_key.is_empty() and _owner_static_surface_key == static_surface_key:
		return false
	_owner_static_surface_key = static_surface_key.duplicate(true)
	_owner_static_surface_build_count_for_tests += 1
	return true


func _sync_motion_owner(owner: Object, motion_state: Object) -> void:
	if motion_state == null:
		_set_pair(owner, "lingpet_companion_defense_intercept_active", "ringpet_companion_defense_intercept_active", false)
		_set_pair(owner, "lingpet_companion_defense_intercept_target_x", "ringpet_companion_defense_intercept_target_x", 0.0)
		return
	_set_pair(owner, "lingpet_companion_defense_intercept_active", "ringpet_companion_defense_intercept_active", motion_state.defense_intercept_active)
	_set_pair(owner, "lingpet_companion_defense_intercept_target_x", "ringpet_companion_defense_intercept_target_x", motion_state.defense_intercept_target_x)


func _sync_body_hit_owner(owner: Object, body_hit_state: Object, hit_gauge_gain: float) -> void:
	if body_hit_state == null:
		_set_pair(owner, "lingpet_companion_contact_count", "ringpet_companion_contact_count", 0)
		_set_pair(owner, "lingpet_companion_last_contact_pos", "ringpet_companion_last_contact_pos", Vector2.ZERO)
		_set_pair(owner, "lingpet_companion_hit_cooldown", "ringpet_companion_hit_cooldown", 0.0)
		_set_pair(owner, "lingpet_companion_hit_gauge_gain", "ringpet_companion_hit_gauge_gain", hit_gauge_gain)
		_set_pair(owner, "lingpet_companion_hit_gauge_last_gain", "ringpet_companion_hit_gauge_last_gain", 0.0)
		_set_pair(owner, "lingpet_companion_hit_gauge_trigger_count", "ringpet_companion_hit_gauge_trigger_count", 0)
		return
	_set_pair(owner, "lingpet_companion_contact_count", "ringpet_companion_contact_count", body_hit_state.contact_count)
	_set_pair(owner, "lingpet_companion_last_contact_pos", "ringpet_companion_last_contact_pos", body_hit_state.last_contact_pos)
	_set_pair(owner, "lingpet_companion_hit_cooldown", "ringpet_companion_hit_cooldown", body_hit_state.cooldown)
	_set_pair(owner, "lingpet_companion_hit_gauge_gain", "ringpet_companion_hit_gauge_gain", hit_gauge_gain)
	_set_pair(owner, "lingpet_companion_hit_gauge_last_gain", "ringpet_companion_hit_gauge_last_gain", body_hit_state.gauge_last_gain)
	_set_pair(owner, "lingpet_companion_hit_gauge_trigger_count", "ringpet_companion_hit_gauge_trigger_count", body_hit_state.gauge_trigger_count)


func _sync_skill_static_owner(
	owner: Object,
	skill_id: String,
	skill_name: String,
	skill_cooldown_duration: float,
	skill_active: bool,
	skill_level: int,
	skill_max_level: int
) -> void:
	_set_pair(owner, "lingpet_skill_id", "ringpet_skill_id", skill_id)
	_set_pair(owner, "lingpet_active_skill_id", "ringpet_active_skill_id", skill_id)
	_set_pair(owner, "lingpet_active_skill_level", "ringpet_active_skill_level", skill_level if skill_active else 0)
	_set_pair(owner, "lingpet_active_skill_max_level", "ringpet_active_skill_max_level", skill_max_level if skill_active else 0)
	_set_pair(owner, "lingpet_skill_name", "ringpet_skill_name", skill_name)
	_set_pair(owner, "lingpet_skill_cooldown_duration", "ringpet_skill_cooldown_duration", skill_cooldown_duration)


func _sync_skill_runtime_owner(
	owner: Object,
	skill_state: Object,
	skill_id: String,
	skill_active: bool
) -> void:
	var cooldown := 0.0
	var ready := false
	var last_gain := 0.0
	var trigger_count := 0
	if skill_state != null:
		cooldown = skill_state.cooldown
		ready = skill_active and skill_id != "" and skill_state.cooldown <= 0.0
		last_gain = skill_state.last_gain
		trigger_count = skill_state.trigger_count
	_set_pair(owner, "lingpet_skill_cooldown", "ringpet_skill_cooldown", cooldown)
	_set_pair(owner, "lingpet_skill_ready", "ringpet_skill_ready", ready)
	_set_pair(owner, "lingpet_skill_last_gain", "ringpet_skill_last_gain", last_gain)
	_set_pair(owner, "lingpet_skill_trigger_count", "ringpet_skill_trigger_count", trigger_count)


func _sync_second_skill_static_owner(
	owner: Object,
	skill_id: String,
	skill_name: String,
	skill_cooldown_duration: float,
	skill_active: bool,
	skill_level: int,
	skill_max_level: int
) -> void:
	_set_pair(owner, "lingpet_second_skill_id", "ringpet_second_skill_id", skill_id if skill_active else "")
	_set_pair(owner, "lingpet_second_skill_name", "ringpet_second_skill_name", skill_name if skill_active else "")
	_set_pair(owner, "lingpet_second_active_skill_level", "ringpet_second_active_skill_level", skill_level if skill_active else 0)
	_set_pair(owner, "lingpet_second_skill_max_level", "ringpet_second_skill_max_level", skill_max_level if skill_active else 0)
	_set_pair(owner, "lingpet_second_skill_cooldown_duration", "ringpet_second_skill_cooldown_duration", skill_cooldown_duration if skill_active else 0.0)


func _sync_second_skill_runtime_owner(
	owner: Object,
	skill_state: Object,
	skill_id: String,
	skill_active: bool,
	skill_windup_seconds: float
) -> void:
	var cooldown := 0.0
	var ready := false
	var winding_up := false
	var windup_ratio := 0.0
	if skill_active and skill_state != null:
		cooldown = skill_state.cooldown
		ready = skill_id != "" and skill_state.cooldown <= 0.0
		winding_up = bool(skill_state.windup_active)
		windup_ratio = _skill_windup_ratio(skill_state, skill_windup_seconds, skill_active)
	_set_pair(owner, "lingpet_second_skill_cooldown", "ringpet_second_skill_cooldown", cooldown)
	_set_pair(owner, "lingpet_second_skill_ready", "ringpet_second_skill_ready", ready)
	_set_pair(owner, "lingpet_second_skill_winding_up", "ringpet_second_skill_winding_up", winding_up)
	_set_pair(owner, "lingpet_second_skill_windup_ratio", "ringpet_second_skill_windup_ratio", windup_ratio)


func _sync_passive_owner(owner: Object, passive_id: String, passive_skill: Dictionary, companion_active: bool) -> void:
	_set_pair(owner, "lingpet_passive_skill_id", "ringpet_passive_skill_id", passive_id)
	_set_pair(owner, "lingpet_passive_skill_level", "ringpet_passive_skill_level", int(passive_skill.get("level", 1)) if companion_active else 0)
	_set_pair(owner, "lingpet_passive_skill_max_level", "ringpet_passive_skill_max_level", int(passive_skill.get("max_level", 5)) if companion_active else 0)
	_set_pair(owner, "lingpet_passive_skill_name", "ringpet_passive_skill_name", str(passive_skill.get("name", "")) if companion_active else "")
	_set_pair(owner, "lingpet_passive_skill_description", "ringpet_passive_skill_description", str(passive_skill.get("description", "")) if companion_active else "")
	_set_pair(owner, "lingpet_passive_skill_icon_path", "ringpet_passive_skill_icon_path", str(passive_skill.get("icon_texture_path", "")) if companion_active else "")
	_set_pair(owner, "lingpet_starpoint_tracking_chance_pct", "ringpet_starpoint_tracking_chance_pct", maxf(0.0, float(passive_skill.get("starpoint_tracking_chance_pct", 0.0))) if companion_active else 0.0)
	_set_pair(owner, "lingpet_ring_dash_chance_pct", "ringpet_ring_dash_chance_pct", maxf(0.0, float(passive_skill.get("ring_dash_chance_pct", 0.0))) if companion_active else 0.0)


# Change-gated owner writes: a key whose value matches the last push is
# skipped entirely. Containers are detached on both sides (owner copy and
# cache copy) so neither side can mutate the other or the caller's live
# collection.
func _set_single(owner: Object, key: String, value: Variant) -> void:
	if _pushed_values.has(key) and _pushed_values[key] == value:
		return
	_pushed_values[key] = _detached_copy(value)
	owner.set(key, _detached_copy(value))


func _set_pair(owner: Object, lingpet_key: String, ringpet_key: String, value: Variant) -> void:
	if _pushed_values.has(lingpet_key) and _pushed_values[lingpet_key] == value:
		return
	_pushed_values[lingpet_key] = _detached_copy(value)
	var owner_value: Variant = _detached_copy(value)
	owner.set(lingpet_key, owner_value)
	owner.set(ringpet_key, owner_value)


func _detached_copy(value: Variant) -> Variant:
	if value is Array:
		return (value as Array).duplicate(true)
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return value


func _build_second_skill_state_snapshot(
	skill_state: Object,
	skill_active: bool,
	skill_id: String,
	skill_cooldown_duration: float,
	skill_windup_seconds: float,
	flash_seconds: float
) -> Dictionary:
	if skill_active and skill_state != null:
		return skill_state.get_snapshot(skill_active, skill_id, skill_cooldown_duration, skill_windup_seconds, flash_seconds, "_1")
	return {
		"companion_skill_cooldown_1": 0.0,
		"companion_skill_cooldown_duration_1": 0.0,
		"companion_skill_windup_seconds_1": 0.0,
		"companion_skill_windup_ratio_1": 0.0,
		"companion_skill_ready_1": false,
		"companion_skill_last_gain_1": 0.0,
		"companion_skill_trigger_count_1": 0,
		"companion_skill_flash_timer_1": 0.0,
		"companion_skill_flash_ratio_1": 0.0,
		"companion_skill_winding_up_1": false,
		"companion_skill_origin_1": Vector2.ZERO,
	}


func _skill_windup_ratio(skill_state: Object, skill_windup_seconds: float, skill_active: bool) -> float:
	if not skill_active or skill_state == null or not bool(skill_state.windup_active):
		return 0.0
	if skill_windup_seconds <= 0.0:
		return 1.0
	return clampf(float(skill_state.windup_elapsed) / skill_windup_seconds, 0.0, 1.0)


func _get_skill_ids(skills: Array[Dictionary]) -> Array[String]:
	var ids: Array[String] = []
	for skill in skills:
		var skill_id := str(skill.get("id", "")).strip_edges()
		if skill_id != "":
			ids.append(skill_id)
	return ids
