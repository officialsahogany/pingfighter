extends RefCounted

const ACTIVE_SKILL_FLOAT_DEFAULTS := {
	"roar_radius": -1.0,
	"ball_boost": -1.0,
}


func build(
	state: String,
	companion_state: String,
	owner: Object,
	registry: Object,
	skill_id: String,
	skill_state: Object,
	skill_runtime_host: Object,
	windup_seconds: float,
	ball_active: bool,
	ball_pos: Vector2,
	ball_vel: Vector2,
	ball_size: float,
	switch_transition_active: bool,
	companion_visible: bool,
	companion_pos: Vector2,
	companion_radius: float,
	companion_catch_height: float,
	active_skill: Dictionary,
	active_skill_level_fallback: int,
	slot_index: int,
	active_skill_ids: Array[String],
	skill_states: Array,
	companion_exhausted: bool = false
) -> Dictionary:
	var context := {
		"state": state,
		"companion_state": companion_state,
		"owner": owner,
		"registry": registry,
		"skill_id": skill_id,
		"skill_state": skill_state,
		"skill_runtime_host": skill_runtime_host,
		"windup_seconds": windup_seconds,
		"ball_active": ball_active,
		"ball_pos": ball_pos,
		"ball_vel": ball_vel,
		"ball_size": ball_size,
		"switch_transition_active": switch_transition_active,
		"companion_visible": companion_visible,
		"companion_pos": companion_pos,
		"companion_radius": companion_radius,
		"companion_catch_height": companion_catch_height,
		"active_skill_level": int(active_skill.get("level", active_skill_level_fallback)),
		"slot_index": slot_index,
		"active_skill_ids": active_skill_ids,
		"skill_states": skill_states,
		"companion_exhausted": companion_exhausted,
	}
	for raw_key in ACTIVE_SKILL_FLOAT_DEFAULTS.keys():
		var key := str(raw_key)
		context[key] = float(active_skill.get(key, ACTIVE_SKILL_FLOAT_DEFAULTS[key]))
	return context
