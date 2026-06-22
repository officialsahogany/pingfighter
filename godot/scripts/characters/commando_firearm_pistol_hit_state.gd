extends RefCounted

const CommandoFirearmHitGeometry := preload("res://scripts/characters/commando_firearm_hit_geometry.gd")
const CommandoFirearmPistolFeedbackState := preload("res://scripts/characters/commando_firearm_pistol_feedback_state.gd")
const CommandoFirearmValueUtils := preload("res://scripts/characters/commando_firearm_value_utils.gd")


static func build_hit_payload(
	weapon_id: String,
	current_hit_count: int,
	shot_roll: float,
	head_chance: float,
	leg_chance: float,
	doping_multiplier: float,
	tuning: Dictionary,
	base_pistol_knockback_mult: float = 1.0
) -> Dictionary:
	var result_fields: Dictionary = {}
	var next_hit_count: int = max(0, current_hit_count) + 1
	var damage_units_delta := 0
	var damage_sources: Array[String] = []
	var hit_kind := "normal"
	var feedback_hit_kind := ""
	var gauge_gain: float = float(tuning.get("normal_gauge_gain", 30.0))
	if shot_roll < head_chance:
		hit_kind = "headshot"
		feedback_hit_kind = hit_kind
		gauge_gain = float(tuning.get("head_gauge_gain", 50.0))
		result_fields["stun_frames"] = _get_head_stun_frames(weapon_id, tuning)
		result_fields["stun_source"] = "commando_firearm_pistol_headshot"
		result_fields["knockback_power"] = 0.0
		result_fields["knockback_velocity_scale"] = 0.0
		result_fields["knockback_vel"] = 0.0
		result_fields["knockback_active"] = false
		result_fields["commando_firearm_pistol_feedback_timer_frames"] = float(tuning.get("hit_text_timer_frames", 60.0))
		damage_units_delta += 1
		damage_sources.append("commando_firearm_pistol_headshot")
	elif shot_roll < head_chance + leg_chance:
		hit_kind = "legshot"
		feedback_hit_kind = hit_kind
		gauge_gain = float(tuning.get("leg_gauge_gain", 40.0))
		result_fields["stun_frames"] = 0.0
		result_fields["slow_frames"] = float(tuning.get("leg_slow_frames", 132.0))
		result_fields["slow_multiplier"] = float(tuning.get("leg_slow_multiplier", 0.7))
		result_fields["slow_source"] = "commando_firearm_pistol_legshot"
		result_fields["knockback_without_stun"] = true
		result_fields["knockback_frames"] = 18.0
		result_fields["commando_firearm_pistol_feedback_timer_frames"] = float(tuning.get("hit_text_timer_frames", 60.0))
	else:
		var knockback_mult := 1.0
		if weapon_id != "commando_pistol":
			knockback_mult = max(0.0, base_pistol_knockback_mult)
		result_fields["knockback_power"] = float(tuning.get("normal_knockback_power", 8.0)) * knockback_mult
		result_fields["knockback_velocity_scale"] = 0.0
		result_fields["knockback_frames"] = float(tuning.get("normal_knockback_frames", 18.0))
		result_fields["knockback_decay_per_frame"] = float(tuning.get("normal_knockback_decay_per_frame", 0.85))

	if next_hit_count >= max(1, int(tuning.get("combo_hit_threshold", 3))):
		next_hit_count = 0
		damage_units_delta += 1
		damage_sources.append("commando_firearm_pistol_combo")
		result_fields["pistol_combo_damage_ready"] = true

	result_fields["pistol_boss_hit_count"] = next_hit_count
	result_fields["pistol_shot_roll"] = shot_roll
	result_fields["pistol_head_chance"] = head_chance
	result_fields["pistol_leg_chance"] = leg_chance
	result_fields["doping_potion_active"] = doping_multiplier > 1.0
	result_fields["doping_potion_head_leg_multiplier"] = doping_multiplier
	result_fields["pistol_hit_kind"] = hit_kind
	result_fields["commando_firearm_pistol_hit_kind"] = hit_kind
	result_fields["commando_firearm_special_gauge_gain"] = gauge_gain
	result_fields["commando_firearm_special_gauge_source"] = "commando_firearm_pistol_%s" % hit_kind
	return {
		"next_hit_count": next_hit_count,
		"result_fields": result_fields,
		"feedback_hit_kind": feedback_hit_kind,
		"damage_units_delta": damage_units_delta,
		"damage_sources": damage_sources,
	}


static func apply_hit_payload(
	hit_payload: Dictionary,
	result: Dictionary,
	feedbacks: Array,
	context: Dictionary,
	field_width: float,
	field_height: float,
	hit_text_timer_frames: float,
	headshot_label: String,
	legshot_label: String,
	feedback_limit: int
) -> Dictionary:
	result.merge(CommandoFirearmValueUtils.get_dict(hit_payload.get("result_fields", {})), true)
	append_feedback_from_payload(
		hit_payload,
		feedbacks,
		context,
		field_width,
		field_height,
		hit_text_timer_frames,
		headshot_label,
		legshot_label,
		feedback_limit
	)
	var damage_units_delta: int = int(hit_payload.get("damage_units_delta", 0))
	if damage_units_delta > 0:
		result["damage_units"] = max(0, int(result.get("damage_units", 0))) + damage_units_delta
		result["damage_sources"] = CommandoFirearmValueUtils.get_array(hit_payload.get("damage_sources", []))
	return {
		"next_hit_count": int(hit_payload.get("next_hit_count", 0)),
		"damage_units_delta": damage_units_delta,
		"feedback_hit_kind": str(hit_payload.get("feedback_hit_kind", "")),
	}


static func apply_runtime_hit_effects(
	weapon_id: String,
	projectile: Dictionary,
	context: Dictionary,
	result: Dictionary,
	current_hit_count: int,
	feedbacks: Array,
	base_weapon_id: String,
	doping_head_leg_multiplier: float,
	head_shot_chance: float,
	leg_shot_chance: float,
	tuning: Dictionary,
	field_width: float,
	field_height: float,
	hit_text_timer_frames: float,
	headshot_label: String,
	legshot_label: String,
	feedback_limit: int
) -> Dictionary:
	if not CommandoFirearmValueUtils.is_pistol_weapon(weapon_id, base_weapon_id):
		return {}
	var shot_roll: float = CommandoFirearmValueUtils.get_pistol_shot_roll(projectile, context)
	var doping_multiplier: float = CommandoFirearmValueUtils.get_pistol_hit_doping_multiplier(
		projectile,
		context,
		doping_head_leg_multiplier
	)
	var base_pistol_knockback_mult: float = max(0.0, float(projectile.get("pistol_enhance_knockback_mult", 1.0)))
	var hit_chances: Dictionary = CommandoFirearmValueUtils.get_pistol_hit_chances(
		context,
		doping_multiplier,
		head_shot_chance,
		leg_shot_chance
	)
	var hit_payload: Dictionary = build_hit_payload(
		weapon_id,
		current_hit_count,
		shot_roll,
		float(hit_chances.get("head_chance", 0.0)),
		float(hit_chances.get("leg_chance", 0.0)),
		doping_multiplier,
		tuning,
		base_pistol_knockback_mult
	)
	return apply_hit_payload(
		hit_payload,
		result,
		feedbacks,
		context,
		field_width,
		field_height,
		hit_text_timer_frames,
		headshot_label,
		legshot_label,
		feedback_limit
	)


static func append_feedback_from_payload(
	hit_payload: Dictionary,
	feedbacks: Array,
	context: Dictionary,
	field_width: float,
	field_height: float,
	hit_text_timer_frames: float,
	headshot_label: String,
	legshot_label: String,
	feedback_limit: int
) -> void:
	var feedback_hit_kind: String = str(hit_payload.get("feedback_hit_kind", ""))
	if feedback_hit_kind == "":
		return
	CommandoFirearmPistolFeedbackState.append_feedback(
		feedbacks,
		feedback_hit_kind,
		CommandoFirearmHitGeometry.get_boss_rect(context, field_width),
		Vector2(field_width, field_height),
		hit_text_timer_frames,
		headshot_label,
		legshot_label,
		feedback_limit
	)


static func _get_head_stun_frames(weapon_id: String, tuning: Dictionary) -> float:
	if weapon_id == "commando_pistol":
		return float(tuning.get("commando_head_stun_frames", 108.0))
	return float(tuning.get("base_head_stun_frames", 90.0))
