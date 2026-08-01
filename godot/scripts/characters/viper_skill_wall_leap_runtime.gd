extends RefCounted

const BossSlowTiers := preload("res://scripts/status/boss_slow_tiers.gd")

const SKILL_ID := "wall_leap_raid"
const STATE_IDLE := "idle"
const STATE_INFILTRATE_IN := "infiltrate_in"
const STATE_INFILTRATING := "infiltrating"
const STATE_FUSE := "fuse"
const STATE_RETURN := "return"

const ENTRY_MIN_GAUGE := 160.0
const ENTRY_COST := 100.0
const SLASH_COST := 60.0
const BLAST_COST := 150.0
const TWEEN_SECONDS := 0.22
const TWEEN_ARC_HEIGHT := 48.0
const FUSE_SECONDS := 0.70
const RMB_INPUT_LOCK_SECONDS := 0.25
const BALL_MOTION_MULTIPLIER := 0.50
const SLASH_RANGE_X := 110.0
const BLAST_RANGE_X := 50.0
const SLOW_FRAMES := 300.0
const SLOW_MULTIPLIER := BossSlowTiers.MEDIUM
const STUN_FRAMES := 180.0
const KNOCKBACK_VELOCITY := 19.0
const KNOCKBACK_FRAMES := 18.0
const KNOCKBACK_DECAY := 0.88
const RETURN_COLLISION_COOLDOWN := 6.0

var state := STATE_IDLE
var elapsed_seconds := 0.0
var entry_pos := Vector2.ZERO
var current_pos := Vector2.ZERO
var tween_start_pos := Vector2.ZERO
var tween_target_pos := Vector2.ZERO
var facing_dir := 1
var forced_return_reason := ""
var last_action := ""
var last_action_hit := false
var last_committed_cost := 0.0
var _landing_cooldown_pending := false
var _return_sound_pending := false


func try_update_or_activate(
	runtime: Object,
	delta: float,
	player_pos: Vector2,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary,
	input_snapshot: Dictionary,
	now_msec: int
) -> Dictionary:
	if state != STATE_IDLE:
		return _update_active(runtime, delta, player_pos, special_gauge, config, deps, input_snapshot, now_msec)
	if not bool(input_snapshot.get("secondary_action_just_pressed", false)):
		return {}
	if not _can_enter(runtime, special_gauge, config, deps, now_msec):
		return {}
	_begin_entry(player_pos, config, deps)
	_play_entry_sound(deps)
	return _handled_result(special_gauge - ENTRY_COST, true)


func is_active() -> bool:
	return state != STATE_IDLE


func is_input_owned() -> bool:
	return state != STATE_IDLE


func is_command_armable_from_owner(owner: Object, registry: Object) -> bool:
	if is_active():
		return true
	if owner == null or registry == null or not registry.has_method("get_cached_instance"):
		return false
	if str(owner.get("selected_character_type")).strip_edges().to_lower() != "viper":
		return false
	if owner.get("ball_active") != true or float(owner.get("special_gauge")) < ENTRY_MIN_GAUGE:
		return false
	var skill_config: Object = _peek(registry, "viper_skill_config")
	if skill_config == null or not skill_config.has_method("is_skill_equipped") or not bool(skill_config.is_skill_equipped(SKILL_ID)):
		return false
	var skill_state: Object = _peek(registry, "viper_skill_state")
	if skill_state != null and skill_state.has_method("get_configured_cooldown_remaining"):
		if float(skill_state.get_configured_cooldown_remaining(SKILL_ID, Time.get_ticks_msec(), skill_config)) > 0.0:
			return false
	var dash_state: Object = _peek(registry, "smasher_dash_state")
	if _dash_busy(dash_state):
		return false
	var jetpack_state: Object = _peek(registry, "viper_jetpack_state")
	if jetpack_state != null and jetpack_state.has_method("is_airborne") and bool(jetpack_state.is_airborne(10.0)):
		return false
	var status_effect_state: Object = _peek(registry, "status_effect_state")
	if status_effect_state != null:
		if status_effect_state.has_method("is_player_stun_active") and bool(status_effect_state.is_player_stun_active()):
			return false
		if status_effect_state.has_method("has_status") and bool(status_effect_state.has_status("player", "stun")):
			return false
	var mythic_runtime: Object = _peek(registry, "mythic_item_runtime")
	for lock_method in ["is_horn_strawberry_skills_locked", "is_horn_strawberry_control_locked", "is_odins_eye_skills_locked", "is_odins_eye_control_locked"]:
		if mythic_runtime != null and mythic_runtime.has_method(lock_method) and bool(mythic_runtime.call(lock_method)):
			return false
	var viper_runtime: Object = _peek(registry, "viper_skill_runtime")
	if viper_runtime != null:
		if viper_runtime.has_method("_has_viper_attack_motion_active") and bool(viper_runtime._has_viper_attack_motion_active()):
			return false
		if str(viper_runtime.get("chaos_state")) == "startup":
			return false
	return not is_ball_unavailable_from_owner(owner, registry)


func force_return(reason: String, deps: Dictionary = {}) -> bool:
	if state == STATE_IDLE or state == STATE_RETURN:
		return false
	forced_return_reason = reason
	_begin_return(deps)
	return true


func observe_ball_availability(context: Dictionary, deps: Dictionary) -> bool:
	if not is_active():
		return false
	if not is_ball_unavailable(context, deps):
		return false
	return force_return(str(context.get("ball_unavailable_reason", "ball_unavailable")), deps)


func observe_ball_availability_from_owner(owner: Object, registry: Object) -> bool:
	if not is_active() or not is_ball_unavailable_from_owner(owner, registry):
		return false
	return force_return("live_ball_unavailable", {"audio": _peek(registry, "game_audio")})


func is_ball_unavailable(context: Dictionary, deps: Dictionary) -> bool:
	if not bool(context.get("ball_active", true)) or bool(context.get("waiting_for_serve", false)):
		return true
	if bool(context.get("skip_ball_motion_step", false)):
		return true
	if bool(context.get("stopwatch_freeze_active", false)) or bool(context.get("perk_resume_freeze_active", false)):
		return true
	if bool(context.get("viper_dmk_freeze_active", false)) or bool(context.get("viper_nerve_strike_freeze_active", false)):
		return true
	var viper_runtime: Object = deps.get("viper_skill_runtime", null)
	if viper_runtime != null:
		if viper_runtime.get("dmk_freeze_active") == true or viper_runtime.get("nerve_strike_freeze_active") == true:
			return true
	var power_state: Object = deps.get("ball_power_freeze_state", deps.get("power_state", null))
	if power_state != null and power_state.has_method("is_freeze_active") and bool(power_state.is_freeze_active()):
		return true
	var stage3_state: Object = deps.get("stage3_boss_skill_state", null)
	if _stage3_gameplay_hold_active(stage3_state):
		return true
	var stage7_state: Object = deps.get("stage7_akamu_state", null)
	if stage7_state != null and stage7_state.has_method("is_gameplay_freeze_active") and bool(stage7_state.is_gameplay_freeze_active()):
		return true
	return false


func is_ball_unavailable_from_owner(owner: Object, registry: Object) -> bool:
	if owner == null:
		return true
	var context := {
		"ball_active": owner.get("ball_active") == true,
		"waiting_for_serve": _round_waiting(_peek(registry, "round_flow_state")),
		"viper_dmk_freeze_active": false,
		"viper_nerve_strike_freeze_active": false,
	}
	var viper_runtime: Object = _peek(registry, "viper_skill_runtime")
	if viper_runtime != null:
		context["viper_dmk_freeze_active"] = viper_runtime.get("dmk_freeze_active") == true
		context["viper_nerve_strike_freeze_active"] = viper_runtime.get("nerve_strike_freeze_active") == true
	var active_item_runtime: Object = _peek(registry, "active_item_runtime")
	if active_item_runtime != null and active_item_runtime.has_method("get_ball_collision_context"):
		context.merge(active_item_runtime.get_ball_collision_context(), true)
	var perk_state: Object = _peek(registry, "runtime_perk_state")
	if perk_state != null and perk_state.has_method("get_ball_collision_context"):
		context.merge(perk_state.get_ball_collision_context(), true)
	return is_ball_unavailable(context, {
		"power_state": _peek(registry, "smasher_power_smash_state"),
		"stage3_boss_skill_state": _peek(registry, "stage3_boss_skill_state"),
		"stage7_akamu_state": _peek(registry, "stage7_akamu_state"),
	})


func get_actor_draw_context() -> Dictionary:
	if not is_active():
		return {}
	return {
		"player_pos": current_pos,
		"player_sprite_modulate": Color(0.76, 0.90, 1.0, 0.56),
		"player_walk_direction": facing_dir,
		"viper_wall_leap_raid_active": true,
		"viper_wall_leap_raid_state": state,
	}


func get_ball_collision_context() -> Dictionary:
	if not is_active():
		return {"player_guard_available": true, "ball_motion_step_multiplier": 1.0}
	return {
		"player_guard_available": false,
		"ball_motion_step_multiplier": BALL_MOTION_MULTIPLIER if state in [STATE_INFILTRATING, STATE_FUSE] else 1.0,
		"viper_wall_leap_raid_active": true,
		"viper_wall_leap_raid_state": state,
	}


func get_boss_ai_context() -> Dictionary:
	var result := get_ball_collision_context()
	result.erase("player_guard_available")
	return result


func get_snapshot() -> Dictionary:
	return {
		"wall_leap_raid_state": state,
		"wall_leap_raid_active": is_active(),
		"wall_leap_raid_input_owned": is_input_owned(),
		"wall_leap_raid_player_guard_available": not is_active(),
		"wall_leap_raid_ball_motion_step_multiplier": BALL_MOTION_MULTIPLIER if state in [STATE_INFILTRATING, STATE_FUSE] else 1.0,
		"wall_leap_raid_entry_pos": entry_pos,
		"wall_leap_raid_current_pos": current_pos,
		"wall_leap_raid_facing_dir": facing_dir,
		"wall_leap_raid_elapsed_seconds": elapsed_seconds,
		"wall_leap_raid_forced_return_reason": forced_return_reason,
		"wall_leap_raid_last_action": last_action,
		"wall_leap_raid_last_action_hit": last_action_hit,
		"wall_leap_raid_last_committed_cost": last_committed_cost,
	}


func reset() -> void:
	state = STATE_IDLE
	elapsed_seconds = 0.0
	entry_pos = Vector2.ZERO
	current_pos = Vector2.ZERO
	tween_start_pos = Vector2.ZERO
	tween_target_pos = Vector2.ZERO
	facing_dir = 1
	forced_return_reason = ""
	last_action = ""
	last_action_hit = false
	last_committed_cost = 0.0
	_landing_cooldown_pending = false
	_return_sound_pending = false


func _can_enter(runtime: Object, special_gauge: float, config: Dictionary, deps: Dictionary, now_msec: int) -> bool:
	if str(config.get("selected_character_type", "viper")).strip_edges().to_lower() != "viper":
		return false
	if special_gauge < ENTRY_MIN_GAUGE or not bool(config.get("ball_active", true)):
		return false
	if runtime.visibility_query.is_control_locked(deps) or runtime.visibility_query.is_round_waiting_for_serve(deps):
		return false
	if runtime.visibility_query.is_dash_motion_busy(deps) or runtime.visibility_query.is_viper_airborne(deps):
		return false
	if runtime._has_viper_attack_motion_active() or runtime.chaos_state == "startup":
		return false
	var skill_config: Object = runtime.visibility_query.get_viper_skill_config(deps)
	return (
		runtime.visibility_query.is_skill_equipped(skill_config, SKILL_ID)
		and runtime.visibility_query.is_configured_skill_ready(SKILL_ID, deps, now_msec)
		and not is_ball_unavailable(config, deps)
	)


func _begin_entry(player_pos: Vector2, config: Dictionary, deps: Dictionary) -> void:
	state = STATE_INFILTRATE_IN
	elapsed_seconds = 0.0
	entry_pos = player_pos
	current_pos = player_pos
	tween_start_pos = player_pos
	var boss_pos: Vector2 = _vector2(config.get("boss_pos", Vector2(380.0, 40.0)), Vector2(380.0, 40.0))
	tween_target_pos = Vector2(player_pos.x, boss_pos.y)
	var player_width := maxf(1.0, float(config.get("paddle_width", config.get("player_paddle_width", 155.0))))
	var boss_width := maxf(1.0, float(config.get("boss_paddle_width", 100.0)))
	facing_dir = 1 if boss_pos.x + boss_width * 0.5 >= player_pos.x + player_width * 0.5 else -1
	forced_return_reason = ""
	last_action = "entry"
	last_action_hit = false
	last_committed_cost = ENTRY_COST
	_landing_cooldown_pending = false
	_suppress_primary_pointer_until_release(deps)


func _update_active(runtime: Object, delta: float, player_pos: Vector2, special_gauge: float, config: Dictionary, deps: Dictionary, input_snapshot: Dictionary, now_msec: int) -> Dictionary:
	var safe_delta := maxf(0.0, delta)
	if _return_sound_pending and _play_return_sound(deps):
		_return_sound_pending = false
	if state != STATE_RETURN and is_ball_unavailable(config, deps):
		force_return("player_update_ball_unavailable", deps)
	match state:
		STATE_INFILTRATE_IN:
			elapsed_seconds += safe_delta
			current_pos = _arc_position(tween_start_pos, tween_target_pos, elapsed_seconds / TWEEN_SECONDS)
			if elapsed_seconds >= TWEEN_SECONDS:
				state = STATE_INFILTRATING
				elapsed_seconds = 0.0
				current_pos = tween_target_pos
		STATE_INFILTRATING:
			elapsed_seconds += safe_delta
			_update_lateral_position(safe_delta, config, input_snapshot)
			if bool(input_snapshot.get("mouse_left_just_pressed", false)):
				if special_gauge < SLASH_COST:
					_trigger_gauge_flash(deps)
				else:
					var slash_hit := _commit_slash(config, deps)
					last_action = "slash"
					last_action_hit = slash_hit
					last_committed_cost = SLASH_COST
					_begin_return(deps)
					_play_slash_sound(deps)
					return _handled_result(special_gauge - SLASH_COST, false)
			if bool(input_snapshot.get("secondary_action_just_pressed", false)) and elapsed_seconds >= RMB_INPUT_LOCK_SECONDS:
				if special_gauge < BLAST_COST:
					_trigger_gauge_flash(deps)
				else:
					state = STATE_FUSE
					elapsed_seconds = 0.0
					last_action = "fuse"
					last_action_hit = false
					last_committed_cost = BLAST_COST
					return _handled_result(special_gauge - BLAST_COST, false)
		STATE_FUSE:
			elapsed_seconds += safe_delta
			_update_lateral_position(safe_delta, config, input_snapshot)
			if elapsed_seconds >= FUSE_SECONDS:
				last_action = "blast"
				last_action_hit = _commit_blast(config, deps)
				_play_blast_sound(deps)
				_begin_return(deps)
		STATE_RETURN:
			_suppress_primary_pointer_until_release(deps)
			elapsed_seconds += safe_delta
			current_pos = _arc_position(tween_start_pos, tween_target_pos, elapsed_seconds / TWEEN_SECONDS)
			if elapsed_seconds >= TWEEN_SECONDS:
				current_pos = entry_pos
				if _landing_cooldown_pending:
					runtime._trigger_configured_skill_cooldown(SKILL_ID, runtime.visibility_query.get_viper_skill_config(deps), deps, now_msec)
					runtime._trigger_orb_gauge_spin(deps, now_msec)
				_landing_cooldown_pending = false
				state = STATE_IDLE
				elapsed_seconds = 0.0
				return _handled_result(special_gauge, false, RETURN_COLLISION_COOLDOWN)
	return _handled_result(special_gauge, false)


func _begin_return(deps: Dictionary = {}) -> void:
	if state == STATE_RETURN:
		return
	state = STATE_RETURN
	elapsed_seconds = 0.0
	tween_start_pos = current_pos
	tween_target_pos = entry_pos
	_landing_cooldown_pending = true
	_return_sound_pending = not _play_return_sound(deps)


func _update_lateral_position(delta: float, config: Dictionary, input_snapshot: Dictionary) -> void:
	var direction := clampf(float(input_snapshot.get("direction", 0.0)), -1.0, 1.0)
	if absf(direction) <= 0.01:
		return
	facing_dir = 1 if direction > 0.0 else -1
	var speed := maxf(0.0, float(config.get("paddle_speed", 4.0))) * 60.0
	var width := maxf(1.0, float(config.get("width", 760.0)))
	var paddle_width := maxf(1.0, float(config.get("paddle_width", config.get("player_paddle_width", 155.0))))
	current_pos.x = clampf(current_pos.x + direction * speed * delta, 0.0, maxf(0.0, width - paddle_width))


func _commit_slash(config: Dictionary, deps: Dictionary) -> bool:
	var centers := _combat_centers(config)
	var player_center: Vector2 = centers.get("player", current_pos)
	var boss_center: Vector2 = centers.get("boss", Vector2.ZERO)
	var offset_x := boss_center.x - player_center.x
	if absf(offset_x) > SLASH_RANGE_X or signf(offset_x) != float(facing_dir):
		return false
	var status_effect_state: Object = deps.get("status_effect_state", null)
	if status_effect_state != null and status_effect_state.has_method("apply_status"):
		status_effect_state.apply_status("boss", "slow", SLOW_FRAMES, {"multiplier": SLOW_MULTIPLIER, "cleansable": true}, SKILL_ID)
	return true


func _commit_blast(config: Dictionary, deps: Dictionary) -> bool:
	var centers := _combat_centers(config)
	var player_center: Vector2 = centers.get("player", current_pos)
	var boss_center: Vector2 = centers.get("boss", Vector2.ZERO)
	if absf(boss_center.x - player_center.x) > BLAST_RANGE_X:
		return false
	var knockback_dir := signf(boss_center.x - player_center.x)
	if is_zero_approx(knockback_dir):
		knockback_dir = float(facing_dir)
	var knockback_vel := knockback_dir * KNOCKBACK_VELOCITY
	var status_effect_state: Object = deps.get("status_effect_state", null)
	if status_effect_state != null and status_effect_state.has_method("apply_status"):
		status_effect_state.apply_status("boss", "stun", STUN_FRAMES, {
			"knockback_vel": knockback_vel,
			"knockback_frames": KNOCKBACK_FRAMES,
			"knockback_decay_per_frame": KNOCKBACK_DECAY,
			"knockback_stop_threshold": 0.3,
			"knockback_active": true,
			"cleansable": true,
		}, SKILL_ID)
	return true


func _combat_centers(config: Dictionary) -> Dictionary:
	var player_size := _vector2(config.get("player_paddle_size", Vector2(float(config.get("paddle_width", 155.0)), float(config.get("paddle_height", 50.0)))), Vector2(155.0, 50.0))
	var boss_pos := _vector2(config.get("boss_pos", Vector2.ZERO), Vector2.ZERO)
	var boss_size := _vector2(config.get("boss_paddle_size", Vector2(float(config.get("boss_paddle_width", 100.0)), float(config.get("boss_hitbox_height", 40.0)))), Vector2(100.0, 40.0))
	return {"player": current_pos + player_size * 0.5, "boss": boss_pos + boss_size * 0.5}


func _handled_result(special_gauge: float, activated: bool, collision_cooldown: float = -1.0) -> Dictionary:
	var result := {
		"handled": true,
		"activated": activated,
		"skill_name": SKILL_ID,
		"player_pos": current_pos,
		"player_speed": 0.0,
		"special_gauge": maxf(0.0, special_gauge),
	}
	if collision_cooldown >= 0.0:
		result["player_collision_cooldown"] = collision_cooldown
	return result


func _arc_position(from: Vector2, to: Vector2, ratio: float) -> Vector2:
	var t := clampf(ratio, 0.0, 1.0)
	var travel := to - from
	if travel.is_zero_approx():
		return from
	# A quadratic side bow remains visible even though the approved landing X is
	# identical to the entry X. The endpoints stay exact and uncapped.
	var arc_normal := Vector2(-travel.y, travel.x).normalized()
	return from.lerp(to, t) + arc_normal * (4.0 * t * (1.0 - t) * TWEEN_ARC_HEIGHT)


func _suppress_primary_pointer_until_release(deps: Dictionary) -> void:
	var registry: Object = deps.get("registry", null)
	var input_reader: Object = _peek(registry, "viper_input_reader")
	if input_reader != null and input_reader.has_method("suppress_primary_pointer_until_release"):
		input_reader.suppress_primary_pointer_until_release()


func _trigger_gauge_flash(deps: Dictionary) -> void:
	var feedback: Object = deps.get("feedback", null)
	if feedback != null and feedback.has_method("trigger_gauge_flash"):
		feedback.trigger_gauge_flash()


func _play_entry_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_viper_backstep"):
		audio.play_viper_backstep()


func _play_return_sound(deps: Dictionary) -> bool:
	var audio: Object = deps.get("audio", null)
	if audio == null or not audio.has_method("play_viper_backstep"):
		return false
	audio.play_viper_backstep()
	return true


func _play_slash_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_viper_venom_attack"):
		audio.play_viper_venom_attack()


func _play_blast_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_grenade_explosion"):
		audio.play_grenade_explosion()


func _stage3_gameplay_hold_active(stage3_state: Object) -> bool:
	if stage3_state == null:
		return false
	if stage3_state.has_method("is_psychoball_hitstop_active") and bool(stage3_state.is_psychoball_hitstop_active()):
		return true
	if stage3_state.has_method("is_kuromi_awakening_active") and bool(stage3_state.is_kuromi_awakening_active()):
		return true
	return stage3_state.has_method("is_kuromi_ball_hidden") and bool(stage3_state.is_kuromi_ball_hidden())


func _round_waiting(round_state: Object) -> bool:
	return round_state != null and round_state.has_method("is_waiting_for_serve") and bool(round_state.is_waiting_for_serve())


func _dash_busy(dash_state: Object) -> bool:
	if dash_state == null or not dash_state.has_method("get_snapshot"):
		return false
	var snapshot: Variant = dash_state.get_snapshot()
	return snapshot is Dictionary and (bool(snapshot.get("active", false)) or bool(snapshot.get("recovering", false)))


func _peek(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_cached_instance"):
		return null
	var value: Variant = registry.get_cached_instance(key)
	if typeof(value) != TYPE_OBJECT or not is_instance_valid(value):
		return null
	return value as Object


func _vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
