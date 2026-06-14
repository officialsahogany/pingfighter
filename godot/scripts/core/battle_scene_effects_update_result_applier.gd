extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")


func apply_effects_result(owner: Object, result: Dictionary) -> void:
	if owner == null:
		return

	owner.set("drive_text_timer_frames", float(result.get(
		"drive_text_timer_frames",
		_get_owner_value(owner, "drive_text_timer_frames", 0.0)
	)))
	if result.has("special_gauge"):
		owner.set("special_gauge", float(result.get(
			"special_gauge",
			_get_owner_value(owner, "special_gauge", 0.0)
		)))
	if result.has("player_pos"):
		var player_pos: Variant = result.get("player_pos", _get_owner_value(owner, "player_pos", Vector2.ZERO))
		if player_pos is Vector2:
			owner.set("player_pos", player_pos)
	if result.has("boss_pos"):
		var boss_pos: Variant = result.get("boss_pos", _get_owner_value(owner, "boss_pos", Vector2.ZERO))
		if boss_pos is Vector2:
			owner.set("boss_pos", boss_pos)
	if result.has("boss_vel"):
		owner.set("boss_vel", float(result.get(
			"boss_vel",
			_get_owner_value(owner, "boss_vel", 0.0)
		)))
	if result.has("ball_pos"):
		var ball_pos: Variant = result.get("ball_pos", _get_owner_value(owner, "ball_pos", Vector2.ZERO))
		if ball_pos is Vector2:
			owner.set("ball_pos", ball_pos)
	if result.has("ball_vel"):
		var ball_vel: Variant = result.get("ball_vel", _get_owner_value(owner, "ball_vel", Vector2.ZERO))
		if ball_vel is Vector2:
			owner.set("ball_vel", ball_vel)
	if result.has("skip_ball_motion_step"):
		owner.set("skip_ball_motion_step", bool(result.get("skip_ball_motion_step", false)))
	if result.has("ball_impact_boost"):
		owner.set("ball_impact_boost", float(result.get(
			"ball_impact_boost",
			_get_owner_value(owner, "ball_impact_boost", 1.0)
		)))
	if result.has("stage3_kuromi_ball_hidden"):
		owner.set("stage3_kuromi_ball_hidden", bool(result.get("stage3_kuromi_ball_hidden", false)))
	if result.has("commando_firearm_boss_damage_units"):
		_apply_commando_firearm_boss_damage(owner, result)
	if result.has("commando_bowling_trap_guard_armed"):
		_apply_commando_bowling_trap_guard_state(owner, result)
	if result.has("commando_suicide_drone_ball_boost_active"):
		_apply_commando_suicide_drone_ball_boost_state(owner, result)
	if result.has("lingpet_wild_roar_ball_boost_active"):
		_apply_lingpet_wild_roar_ball_boost_state(owner, result)
	_apply_blacksmith_umbrella_result(owner, result)


func _apply_commando_firearm_boss_damage(owner: Object, result: Dictionary) -> void:
	var damage_units: int = max(0, int(result.get("commando_firearm_boss_damage_units", 0)))
	if damage_units <= 0:
		return

	var total_damage: int = max(0, int(_get_owner_value(owner, "commando_firearm_boss_damage_units_total", 0))) + damage_units
	var health_damage: int = max(0, int(_get_owner_value(owner, "boss_health_damage_units", 0))) + damage_units
	var source: String = str(result.get("commando_firearm_last_damage_source", "commando_firearm"))

	owner.set("commando_firearm_boss_damage_units_total", total_damage)
	owner.set("commando_firearm_last_damage_units", damage_units)
	owner.set("commando_firearm_last_damage_source", source)
	owner.set("boss_health_damage_units", health_damage)
	owner.set("boss_last_damage_source", source)

	var current_health: int = int(_get_owner_value(owner, "boss_current_health", 0))
	if current_health <= 0:
		return
	var next_health: int = max(0, current_health - damage_units)
	owner.set("boss_current_health", next_health)
	if next_health <= 0 and int(_get_owner_value(owner, "boss_max_health", 0)) > 0:
		owner.set("boss_defeated_by_health", true)


func _apply_commando_bowling_trap_guard_state(owner: Object, result: Dictionary) -> void:
	var armed: bool = bool(result.get("commando_bowling_trap_guard_armed", false))
	owner.set("commando_bowling_trap_guard_armed", armed)
	owner.set("commando_bowling_trap_guard_source", str(result.get("commando_bowling_trap_guard_source", "")))
	owner.set("commando_bowling_trap_guard_knockback_power", float(result.get(
		"commando_bowling_trap_guard_knockback_power",
		_get_owner_value(owner, "commando_bowling_trap_guard_knockback_power", 0.0)
	)))
	owner.set("commando_bowling_trap_guard_stun_frames", float(result.get(
		"commando_bowling_trap_guard_stun_frames",
		_get_owner_value(owner, "commando_bowling_trap_guard_stun_frames", 0.0)
	)))
	owner.set("commando_bowling_trap_guard_restore_speed", float(result.get(
		"commando_bowling_trap_guard_restore_speed",
		_get_owner_value(owner, "commando_bowling_trap_guard_restore_speed", 0.0)
	)))


func _apply_commando_suicide_drone_ball_boost_state(owner: Object, result: Dictionary) -> void:
	owner.set("commando_suicide_drone_ball_boost_active", bool(result.get(
		"commando_suicide_drone_ball_boost_active",
		_get_owner_value(owner, "commando_suicide_drone_ball_boost_active", false)
	)))
	owner.set("commando_suicide_drone_ball_restore_speed", float(result.get(
		"commando_suicide_drone_ball_restore_speed",
		_get_owner_value(owner, "commando_suicide_drone_ball_restore_speed", 0.0)
	)))
	owner.set("commando_suicide_drone_ball_boosted_speed", float(result.get(
		"commando_suicide_drone_ball_boosted_speed",
		_get_owner_value(owner, "commando_suicide_drone_ball_boosted_speed", 0.0)
	)))


func _apply_lingpet_wild_roar_ball_boost_state(owner: Object, result: Dictionary) -> void:
	owner.set("lingpet_wild_roar_ball_boost_active", bool(result.get(
		"lingpet_wild_roar_ball_boost_active",
		_get_owner_value(owner, "lingpet_wild_roar_ball_boost_active", false)
	)))
	owner.set("lingpet_wild_roar_ball_restore_speed", float(result.get(
		"lingpet_wild_roar_ball_restore_speed",
		_get_owner_value(owner, "lingpet_wild_roar_ball_restore_speed", 0.0)
	)))


func _apply_blacksmith_umbrella_result(owner: Object, result: Dictionary) -> void:
	for key in [
		"blacksmith_umbrella_open",
		"blacksmith_umbrella_anim_timer",
		"blacksmith_umbrella_retracting",
		"blacksmith_umbrella_anim_direction",
		"blacksmith_umbrella_open_ratio",
		"blacksmith_thor_shield_open_ratio",
		"blacksmith_umbrella_raise_amount",
		"blacksmith_umbrella_shield_open_amount",
		"blacksmith_umbrella_visual_state",
		"blacksmith_umbrella_folded",
		"blacksmith_umbrella_deployed",
		"blacksmith_umbrella_swing_active",
		"blacksmith_umbrella_swing_direction",
		"blacksmith_umbrella_swing_timer",
		"blacksmith_umbrella_gauge",
		"blacksmith_umbrella_gauge_max",
		"blacksmith_umbrella_gauge_gain",
		"blacksmith_umbrella_damage_flash_timer",
		"blacksmith_umbrella_hit_pulse_timer",
	]:
		if result.has(key):
			owner.set(key, result[key])


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	return BattleSceneOwnerReader.get_value(owner, key, fallback)
