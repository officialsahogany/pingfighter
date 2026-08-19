extends RefCounted

# Stage 7's battle-facing presentation state.
#
# Gameplay owners decide when skills start and end. This owner only tracks the
# short boss attack pose and projects the current status string in one explicit
# priority order for actor/HUD consumers.

const BOSS_ATTACK_ANIM_SEC := 0.20

var status := "charging"
var boss_attack_remaining_sec := 0.0
var boss_attack_source := ""
var boss_attack_target_x := 0.0


func reset_full() -> void:
	clear_round_transients()


func clear_round_transients() -> void:
	status = "charging"
	boss_attack_remaining_sec = 0.0
	boss_attack_source = ""
	boss_attack_target_x = 0.0


func set_status(value: String) -> void:
	status = value


func trigger_boss_attack(source: String, target_x: float) -> void:
	boss_attack_remaining_sec = BOSS_ATTACK_ANIM_SEC
	boss_attack_source = source
	boss_attack_target_x = target_x


func update_boss_attack(delta: float) -> void:
	boss_attack_remaining_sec = maxf(0.0, boss_attack_remaining_sec - delta)
	if boss_attack_remaining_sec <= 0.0:
		boss_attack_source = ""


func refresh_status(context: Dictionary) -> String:
	return refresh_status_fields(
		bool(context.get("gameplay_freeze_active", false)),
		str(context.get("gameplay_freeze_reason", "")),
		bool(context.get("escape_active", false)),
		bool(context.get("cloud_dash_active", false)),
		str(context.get("cloud_dash_phase", "")),
		bool(context.get("superspeed_active", false)),
		bool(context.get("skill_cooldown_paused", false)),
		bool(context.get("clone_casting", false)),
		bool(context.get("shuriken_casting", false)),
		bool(context.get("live_clones", false)),
		bool(context.get("shuriken_active", false)),
		int(context.get("shuriken_gauge_ticks_left", 0)),
		bool(context.get("cloud_field_active", false)),
		bool(context.get("wind_aura_depleted", false)),
		bool(context.get("awakened", false))
	)


func refresh_status_fields(
	gameplay_freeze_active: bool,
	gameplay_freeze_reason: String,
	escape_active: bool,
	cloud_dash_active: bool,
	cloud_dash_phase: String,
	superspeed_active: bool,
	skill_cooldown_paused: bool,
	clone_casting: bool,
	shuriken_casting: bool,
	live_clones: bool,
	shuriken_active: bool,
	shuriken_gauge_ticks_left: int,
	cloud_field_active: bool,
	wind_aura_depleted: bool,
	awakened: bool
) -> String:
	if gameplay_freeze_active:
		status = gameplay_freeze_reason + "_freeze"
	elif escape_active:
		status = "escape_active"
	elif cloud_dash_active:
		status = "cloud_" + cloud_dash_phase
	elif superspeed_active:
		status = "superspeed_active"
	elif skill_cooldown_paused:
		status = "paused"
	elif clone_casting:
		status = "clone_casting"
	elif shuriken_casting:
		status = "shuriken_casting"
	elif boss_attack_remaining_sec > 0.0 and boss_attack_source == "boss_paddle_hit":
		status = "boss_hit"
	elif live_clones:
		status = "clone_active"
	elif shuriken_active:
		status = "shuriken_active"
	elif shuriken_gauge_ticks_left > 0:
		status = "shuriken_debuff"
	elif cloud_field_active:
		status = "cloud_active"
	elif wind_aura_depleted:
		status = "wind_aura_recharging"
	elif awakened:
		status = "awakened"
	else:
		status = "charging"
	return status


func has_runtime_state() -> bool:
	return status != "charging" or boss_attack_remaining_sec > 0.0


func get_snapshot() -> Dictionary:
	return {
		"status": status,
		"boss_attack_active": boss_attack_remaining_sec > 0.0,
		"boss_attack_remaining_sec": boss_attack_remaining_sec,
		"boss_attack_total_sec": BOSS_ATTACK_ANIM_SEC,
		"boss_attack_source": boss_attack_source,
		"boss_attack_target_x": boss_attack_target_x,
	}
