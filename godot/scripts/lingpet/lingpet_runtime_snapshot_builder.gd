extends RefCounted

const STATE_NONE := "none"
const STATE_COMPANION := "companion"


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
	skill_runtime_host: Object
) -> Dictionary:
	var companion_active: bool = state == STATE_COMPANION
	var skill_enabled := bool(active_skill.get("enabled", true))
	var skill_active := companion_active and skill_enabled
	var skill_id := str(active_skill.get("id", ""))
	var skill_name := str(active_skill.get("name", ""))
	var skill_description := str(active_skill.get("description", ""))
	var skill_cooldown := float(active_skill.get("cooldown", 0.0))
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
		"hatch_flash_timer": hatch_flash_timer,
		"owned_pet_ids": owned_pet_ids.duplicate(),
		"battle_slot_pet_ids": battle_slot_pet_ids.duplicate(),
		"lingpet_slots": battle_slot_pet_ids.duplicate(),
		"active_slot_index": active_slot_index,
		"active_pet_id": pet_id if companion_active else "",
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
	companion_pos: Vector2,
	owned_pet_ids: Array,
	battle_slot_pet_ids: Array,
	active_slot_index: int,
	gauge_gain_bonus_pct: float,
	motion_state: Object
) -> Dictionary:
	var companion_active: bool = state == STATE_COMPANION
	var snapshot := {
		"version": version,
		"pet_id": pet_id,
		"state": state,
		"hatch_hits": hatch_hits,
		"required_hits": required_hits,
		"egg_pos": egg_pos,
		"companion_pos": companion_pos,
		"owned_pet_ids": owned_pet_ids.duplicate(),
		"battle_slot_pet_ids": battle_slot_pet_ids.duplicate(),
		"lingpet_slots": battle_slot_pet_ids.duplicate(),
		"active_slot_index": active_slot_index,
		"active_pet_id": pet_id if companion_active else "",
		"gauge_gain_bonus_pct": gauge_gain_bonus_pct if companion_active else 0.0,
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
	gauge_gain_bonus_pct: float,
	effect_text: String
) -> void:
	if owner == null:
		return
	var companion_active: bool = state == STATE_COMPANION
	var public_pet_id: String = pet_id if companion_active else ""
	var skill_enabled := bool(active_skill.get("enabled", true))
	var skill_active := companion_active and skill_enabled
	var skill_id := str(active_skill.get("id", "")) if skill_active else ""
	var skill_name := str(active_skill.get("name", "")) if skill_active else ""
	var skill_cooldown := float(active_skill.get("cooldown", 0.0)) if skill_active else 0.0
	owner.set("lingpet_id", public_pet_id)
	owner.set("active_lingpet_id", public_pet_id if companion_active else "")
	owner.set("current_lingpet_id", public_pet_id)
	_set_pair(owner, "lingpet_slots", "ringpet_slots", battle_slot_pet_ids.duplicate())
	_set_pair(owner, "lingpet_slot_pet_ids", "ringpet_slot_pet_ids", battle_slot_pet_ids.duplicate())
	_set_pair(owner, "lingpet_active_slot_index", "ringpet_active_slot_index", active_slot_index)
	_set_pair(owner, "lingpet_state", "ringpet_state", state)
	_set_pair(owner, "lingpet_hatch_hits", "ringpet_hatch_hits", hatch_hits)
	_set_pair(owner, "lingpet_hatch_required_hits", "ringpet_hatch_required_hits", required_hits)
	owner.set("lingpet_egg_pos", egg_pos)
	_set_pair(owner, "lingpet_companion_pos", "ringpet_companion_pos", companion_pos)
	_set_pair(owner, "lingpet_companion_patrol_speed_default", "ringpet_companion_patrol_speed_default", patrol_speed_default)
	_set_pair(owner, "lingpet_companion_patrol_speed_min", "ringpet_companion_patrol_speed_min", patrol_speed_min)
	_set_pair(owner, "lingpet_companion_patrol_speed_max", "ringpet_companion_patrol_speed_max", patrol_speed_max)
	_set_pair(owner, "lingpet_companion_catch_width", "ringpet_companion_catch_width", catch_width)
	_set_pair(owner, "lingpet_companion_catch_height", "ringpet_companion_catch_height", catch_height)
	_set_pair(owner, "lingpet_companion_defense_rate", "ringpet_companion_defense_rate", defense_rate if companion_active else 0.0)
	_sync_motion_owner(owner, motion_state)
	_sync_body_hit_owner(owner, body_hit_state, hit_gauge_gain if companion_active else 0.0)
	_sync_skill_owner(owner, skill_state, skill_id, skill_name, skill_cooldown, skill_active)
	_set_pair(owner, "lingpet_gauge_gain_bonus_pct", "ringpet_gauge_gain_bonus_pct", gauge_gain_bonus_pct if companion_active else 0.0)
	owner.set("lingpet_effect_text", effect_text)


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


func _sync_skill_owner(
	owner: Object,
	skill_state: Object,
	skill_id: String,
	skill_name: String,
	skill_cooldown_duration: float,
	companion_active: bool
) -> void:
	var cooldown := 0.0
	var ready := false
	var last_gain := 0.0
	var trigger_count := 0
	if skill_state != null:
		cooldown = skill_state.cooldown
		ready = companion_active and skill_id != "" and skill_state.cooldown <= 0.0
		last_gain = skill_state.last_gain
		trigger_count = skill_state.trigger_count
	_set_pair(owner, "lingpet_skill_id", "ringpet_skill_id", skill_id)
	_set_pair(owner, "lingpet_skill_name", "ringpet_skill_name", skill_name)
	_set_pair(owner, "lingpet_skill_cooldown", "ringpet_skill_cooldown", cooldown)
	_set_pair(owner, "lingpet_skill_cooldown_duration", "ringpet_skill_cooldown_duration", skill_cooldown_duration)
	_set_pair(owner, "lingpet_skill_ready", "ringpet_skill_ready", ready)
	_set_pair(owner, "lingpet_skill_last_gain", "ringpet_skill_last_gain", last_gain)
	_set_pair(owner, "lingpet_skill_trigger_count", "ringpet_skill_trigger_count", trigger_count)


func _set_pair(owner: Object, lingpet_key: String, ringpet_key: String, value: Variant) -> void:
	owner.set(lingpet_key, value)
	owner.set(ringpet_key, value)
