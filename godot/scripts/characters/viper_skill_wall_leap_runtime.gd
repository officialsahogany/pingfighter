extends RefCounted

const BossSlowTiers := preload("res://scripts/status/boss_slow_tiers.gd")
const BattleViperSpritePaths := preload("res://scripts/resources/battle_viper_sprite_paths.gd")
const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ImpactShockwaveTextureCache := preload("res://scripts/effects/impact_shockwave_texture_cache.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const SKILL_ID := "wall_leap_raid"
const STATE_IDLE := "idle"
const STATE_INFILTRATE_IN := "infiltrate_in"
const STATE_INFILTRATING := "infiltrating"
const STATE_SLASH := "slash"
const STATE_BLADE_FLIGHT := "blade_flight"
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
const SLASH_FRAME_SECONDS := 0.032
const SLASH_FRAME_COUNT := 8
const SLASH_IMPACT_FRAME := 3
const SLASH_ANIMATION_SECONDS := SLASH_FRAME_SECONDS * SLASH_FRAME_COUNT
const BLADE_SPEED_PER_FRAME := 14.0
const BLADE_MAX_RANGE_X := 360.0
const BLADE_SPAWN_FORWARD_OFFSET := 52.0
const BLADE_SPAWN_VERTICAL_OFFSET := 77.0
const INFILTRATION_VISUAL_MIN_Y := 118.0
const BLADE_BURST_SECONDS := 0.12
const BLADE_TRAIL_DRAW_SIZE := Vector2(176.0, 56.0)
const BLADE_BURST_DRAW_SIZE := Vector2(126.0, 96.0)
const BLADE_TRAIL_SOURCE_RECT := Rect2(0.0, 264.0, 954.0, 301.0)
const BLADE_BURST_SOURCE_RECT := Rect2(14.0, 96.0, 1007.0, 767.0)
const BLAST_RANGE_X := 50.0
const BLAST_VFX_SECONDS := 0.46
const BLAST_CORE_SECONDS := 0.09
const BLAST_RAY_COUNT := 12
const BLAST_SPARKLE_COUNT := 8
const BLAST_SHAKE_AMOUNT := 0.12
const BLAST_SHAKE_HIT_INTENSITY := 7.0
const BLAST_SHAKE_MISS_INTENSITY := 5.2
const SLOW_FRAMES := 300.0
const SLOW_MULTIPLIER := BossSlowTiers.MEDIUM
const STUN_FRAMES := 180.0
const KNOCKBACK_VELOCITY := 19.0
const KNOCKBACK_FRAMES := 18.0
const KNOCKBACK_DECAY := 0.88
const RETURN_COLLISION_COOLDOWN := 6.0

const ATTACK_LEFT_SHEET_PATH := BattleViperSpritePaths.VIPER_PLAYER_ATTACK_LEFT_SHEET_PATH
const ATTACK_RIGHT_SHEET_PATH := BattleViperSpritePaths.VIPER_PLAYER_ATTACK_RIGHT_SHEET_PATH
const BLADE_TRAIL_TEXTURE_PATH := "res://assets/sprites/characters/viper/air_blade/viper_air_blade_trail_imagegen_v1.png"
const BLADE_BURST_TEXTURE_PATH := "res://assets/sprites/characters/viper/air_blade/viper_air_blade_slash_burst_imagegen_v1.png"
const PREWARM_PATHS := [
	ATTACK_LEFT_SHEET_PATH,
	ATTACK_RIGHT_SHEET_PATH,
	BLADE_TRAIL_TEXTURE_PATH,
	BLADE_BURST_TEXTURE_PATH,
]

var state := STATE_IDLE
var elapsed_seconds := 0.0
var entry_pos := Vector2.ZERO
var current_pos := Vector2.ZERO
var tween_start_pos := Vector2.ZERO
var tween_target_pos := Vector2.ZERO
var facing_dir := 1
var lateral_motion_dir := 0
var slash_animation_elapsed_seconds := 0.0
var slash_presentation_active := false
var blade_active := false
var blade_pos := Vector2.ZERO
var blade_previous_pos := Vector2.ZERO
var blade_origin_player_center_x := 0.0
var blade_direction := 1
var blade_burst_active := false
var blade_burst_elapsed_seconds := 0.0
var blade_burst_pos := Vector2.ZERO
var blade_burst_direction := 1
var fuse_visual_center := Vector2.ZERO
var blast_vfx_active := false
var blast_vfx_elapsed_seconds := 0.0
var blast_vfx_origin := Vector2.ZERO
var blast_vfx_hit := false
var blast_vfx_hit_pos := Vector2.ZERO
var forced_return_reason := ""
var last_action := ""
var last_action_hit := false
var last_committed_cost := 0.0
var _landing_cooldown_pending := false
var _return_sound_pending := false
var _asset_prewarm_step_index := 0
var _blade_trail_texture: Texture2D
var _blade_burst_texture: Texture2D


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
	_update_presentation_effects(maxf(0.0, delta))
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


func has_visible_effects() -> bool:
	return is_active() or blade_burst_active or blast_vfx_active


func is_input_owned() -> bool:
	return state != STATE_IDLE


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	if _asset_prewarm_step_index < PREWARM_PATHS.size():
		var path: String = str(PREWARM_PATHS[_asset_prewarm_step_index])
		var texture: Texture2D = ProjectResourceLoader.load_texture(path)
		if path == BLADE_TRAIL_TEXTURE_PATH:
			_blade_trail_texture = texture
		elif path == BLADE_BURST_TEXTURE_PATH:
			_blade_burst_texture = texture
		_asset_prewarm_step_index += 1
		return false
	if _asset_prewarm_step_index == PREWARM_PATHS.size():
		if not ImpactFlareTextureCache.prewarm_step():
			return false
		_asset_prewarm_step_index += 1
		return false
	if _asset_prewarm_step_index == PREWARM_PATHS.size() + 1:
		if not ImpactShockwaveTextureCache.prewarm_step():
			return false
		_asset_prewarm_step_index += 1
		return false
	if _asset_prewarm_step_index >= PREWARM_PATHS.size() + 2:
		_asset_prewarm_step_index = 0
		return true
	return false


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
	var context := {
		"player_pos": current_pos,
		"player_speed": float(lateral_motion_dir),
		"player_sprite_modulate": Color(0.76, 0.90, 1.0, 0.56),
		"player_walk_direction": facing_dir,
		"viper_wall_leap_raid_visual_y_offset": maxf(0.0, INFILTRATION_VISUAL_MIN_Y - current_pos.y),
		"viper_wall_leap_raid_active": true,
		"viper_wall_leap_raid_state": state,
	}
	if _is_slash_animation_visible():
		context.merge({
			"player_hit_active": true,
			"player_hit_center": false,
			"player_hit_side": facing_dir,
			"player_hit_frame": _get_slash_animation_frame(),
			"player_hit_frame_count": SLASH_FRAME_COUNT,
			"player_hit_timer": maxf(0.0, SLASH_ANIMATION_SECONDS - slash_animation_elapsed_seconds),
			"player_hit_anim_duration": SLASH_ANIMATION_SECONDS,
			"player_hit_effective_anim_duration": SLASH_ANIMATION_SECONDS,
			"player_hit_lunge_x": 0.0,
			"player_hit_lunge_y": 0.0,
			"player_hit_scale_x": 0.0,
			"player_hit_scale_y": 0.0,
		}, true)
	return context


func get_ball_collision_context() -> Dictionary:
	if not is_active():
		return {"player_guard_available": true, "ball_motion_step_multiplier": 1.0}
	return {
		"player_guard_available": false,
		"ball_motion_step_multiplier": BALL_MOTION_MULTIPLIER if _uses_infiltration_ball_slow() else 1.0,
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
		"wall_leap_raid_ball_motion_step_multiplier": BALL_MOTION_MULTIPLIER if _uses_infiltration_ball_slow() else 1.0,
		"wall_leap_raid_entry_pos": entry_pos,
		"wall_leap_raid_current_pos": current_pos,
		"wall_leap_raid_facing_dir": facing_dir,
		"wall_leap_raid_lateral_motion_dir": lateral_motion_dir,
		"wall_leap_raid_slash_frame": _get_slash_animation_frame(),
		"wall_leap_raid_slash_elapsed_seconds": slash_animation_elapsed_seconds,
		"wall_leap_raid_slash_presentation_active": slash_presentation_active,
		"wall_leap_raid_blade_active": blade_active,
		"wall_leap_raid_blade_pos": blade_pos,
		"wall_leap_raid_blade_previous_pos": blade_previous_pos,
		"wall_leap_raid_blade_origin_player_center_x": blade_origin_player_center_x,
		"wall_leap_raid_blade_direction": blade_direction,
		"wall_leap_raid_blade_burst_active": blade_burst_active,
		"wall_leap_raid_blade_burst_pos": blade_burst_pos,
		"wall_leap_raid_fuse_visual_center": fuse_visual_center,
		"wall_leap_raid_blast_vfx_active": blast_vfx_active,
		"wall_leap_raid_blast_vfx_elapsed_seconds": blast_vfx_elapsed_seconds,
		"wall_leap_raid_blast_vfx_origin": blast_vfx_origin,
		"wall_leap_raid_blast_vfx_hit": blast_vfx_hit,
		"wall_leap_raid_blast_vfx_hit_pos": blast_vfx_hit_pos,
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
	lateral_motion_dir = 0
	slash_animation_elapsed_seconds = 0.0
	slash_presentation_active = false
	blade_active = false
	blade_pos = Vector2.ZERO
	blade_previous_pos = Vector2.ZERO
	blade_origin_player_center_x = 0.0
	blade_direction = 1
	blade_burst_active = false
	blade_burst_elapsed_seconds = 0.0
	blade_burst_pos = Vector2.ZERO
	blade_burst_direction = 1
	fuse_visual_center = Vector2.ZERO
	_clear_blast_vfx()
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
	lateral_motion_dir = 0
	_clear_blade_action_state()
	_clear_blade_burst()
	_clear_blast_vfx()
	fuse_visual_center = Vector2.ZERO
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
			lateral_motion_dir = 0
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
					state = STATE_SLASH
					elapsed_seconds = 0.0
					slash_animation_elapsed_seconds = 0.0
					slash_presentation_active = true
					lateral_motion_dir = 0
					blade_direction = facing_dir
					last_action = "slash"
					last_action_hit = false
					last_committed_cost = SLASH_COST
					return _handled_result(special_gauge - SLASH_COST, false)
			if bool(input_snapshot.get("secondary_action_just_pressed", false)) and elapsed_seconds >= RMB_INPUT_LOCK_SECONDS:
				if special_gauge < BLAST_COST:
					_trigger_gauge_flash(deps)
				else:
					state = STATE_FUSE
					elapsed_seconds = 0.0
					fuse_visual_center = _combat_centers(config).get("player", current_pos)
					last_action = "fuse"
					last_action_hit = false
					last_committed_cost = BLAST_COST
					return _handled_result(special_gauge - BLAST_COST, false)
		STATE_FUSE:
			elapsed_seconds += safe_delta
			_update_lateral_position(safe_delta, config, input_snapshot)
			fuse_visual_center = _combat_centers(config).get("player", current_pos)
			if elapsed_seconds >= FUSE_SECONDS:
				last_action = "blast"
				last_action_hit = _commit_blast(config, deps)
				_play_blast_sound(deps)
				_begin_return(deps, false, config)
		STATE_SLASH:
			lateral_motion_dir = 0
			elapsed_seconds += safe_delta
			slash_animation_elapsed_seconds += safe_delta
			if slash_animation_elapsed_seconds >= SLASH_FRAME_SECONDS * float(SLASH_IMPACT_FRAME):
				_spawn_blade(config, deps)
		STATE_BLADE_FLIGHT:
			lateral_motion_dir = 0
			elapsed_seconds += safe_delta
			slash_animation_elapsed_seconds = minf(SLASH_ANIMATION_SECONDS, slash_animation_elapsed_seconds + safe_delta)
			_update_blade_flight(safe_delta, config, deps)
		STATE_RETURN:
			lateral_motion_dir = 0
			if slash_presentation_active:
				slash_animation_elapsed_seconds = minf(SLASH_ANIMATION_SECONDS, slash_animation_elapsed_seconds + safe_delta)
				if slash_animation_elapsed_seconds >= SLASH_ANIMATION_SECONDS:
					slash_presentation_active = false
			_suppress_primary_pointer_until_release(deps)
			elapsed_seconds += safe_delta
			current_pos = _arc_position(tween_start_pos, tween_target_pos, elapsed_seconds / TWEEN_SECONDS)
			if elapsed_seconds >= TWEEN_SECONDS:
				current_pos = tween_target_pos
				if _landing_cooldown_pending:
					runtime._trigger_configured_skill_cooldown(SKILL_ID, runtime.visibility_query.get_viper_skill_config(deps), deps, now_msec)
					runtime._trigger_orb_gauge_spin(deps, now_msec)
				_landing_cooldown_pending = false
				state = STATE_IDLE
				elapsed_seconds = 0.0
				return _handled_result(special_gauge, false, RETURN_COLLISION_COOLDOWN)
	return _handled_result(special_gauge, false)


func _begin_return(deps: Dictionary = {}, preserve_slash_animation: bool = false, ball_return_config: Dictionary = {}) -> void:
	if state == STATE_RETURN:
		return
	_clear_blade_action_state(not preserve_slash_animation)
	fuse_visual_center = Vector2.ZERO
	state = STATE_RETURN
	elapsed_seconds = 0.0
	lateral_motion_dir = 0
	tween_start_pos = current_pos
	tween_target_pos = _ball_aligned_return_pos(ball_return_config) if not ball_return_config.is_empty() else entry_pos
	_landing_cooldown_pending = true
	_return_sound_pending = not _play_return_sound(deps)


func _update_lateral_position(delta: float, config: Dictionary, input_snapshot: Dictionary) -> void:
	var direction := clampf(float(input_snapshot.get("direction", 0.0)), -1.0, 1.0)
	if absf(direction) <= 0.01:
		lateral_motion_dir = 0
		return
	facing_dir = 1 if direction > 0.0 else -1
	lateral_motion_dir = facing_dir
	var speed := maxf(0.0, float(config.get("paddle_speed", 4.0))) * 60.0
	var width := maxf(1.0, float(config.get("width", 760.0)))
	var paddle_width := maxf(1.0, float(config.get("paddle_width", config.get("player_paddle_width", 155.0))))
	current_pos.x = clampf(current_pos.x + direction * speed * delta, 0.0, maxf(0.0, width - paddle_width))


func _spawn_blade(config: Dictionary, deps: Dictionary) -> void:
	if state != STATE_SLASH:
		return
	var centers := _combat_centers(config)
	var player_center: Vector2 = centers.get("player", current_pos)
	blade_origin_player_center_x = player_center.x
	blade_direction = facing_dir
	blade_previous_pos = player_center
	blade_pos = Vector2(
		player_center.x + float(blade_direction) * BLADE_SPAWN_FORWARD_OFFSET,
		player_center.y + BLADE_SPAWN_VERTICAL_OFFSET
	)
	blade_active = true
	state = STATE_BLADE_FLIGHT
	elapsed_seconds = 0.0
	_start_blade_burst(blade_pos, blade_direction)
	_play_slash_sound(deps)
	if _blade_segment_hits_boss(player_center.x, blade_pos.x, config):
		_commit_blade_hit(config, deps)


func _update_blade_flight(delta: float, config: Dictionary, deps: Dictionary) -> void:
	if state != STATE_BLADE_FLIGHT or not blade_active:
		return
	var width := maxf(1.0, float(config.get("width", 760.0)))
	var range_limit_x := blade_origin_player_center_x + float(blade_direction) * BLADE_MAX_RANGE_X
	var wall_limit_x := width if blade_direction > 0 else 0.0
	var intended_x := blade_pos.x + float(blade_direction) * BLADE_SPEED_PER_FRAME * delta * 60.0
	var next_x: float
	if blade_direction > 0:
		next_x = minf(intended_x, minf(range_limit_x, wall_limit_x))
	else:
		next_x = maxf(intended_x, maxf(range_limit_x, wall_limit_x))
	blade_previous_pos = blade_pos
	blade_pos.x = next_x
	if _blade_segment_hits_boss(blade_previous_pos.x, blade_pos.x, config):
		_commit_blade_hit(config, deps)
		return
	if is_equal_approx(blade_pos.x, range_limit_x) or is_equal_approx(blade_pos.x, wall_limit_x):
		_finish_blade_flight(false, config, deps)


func _blade_segment_hits_boss(from_x: float, to_x: float, config: Dictionary) -> bool:
	var centers := _combat_centers(config)
	var boss_center: Vector2 = centers.get("boss", Vector2.ZERO)
	var offset_from_origin := boss_center.x - blade_origin_player_center_x
	if signf(offset_from_origin) != float(blade_direction) or absf(offset_from_origin) > BLADE_MAX_RANGE_X:
		return false
	var segment_min := minf(from_x, to_x)
	var segment_max := maxf(from_x, to_x)
	return boss_center.x >= segment_min and boss_center.x <= segment_max


func _commit_blade_hit(config: Dictionary, deps: Dictionary) -> void:
	if not blade_active:
		return
	var centers := _combat_centers(config)
	var boss_center: Vector2 = centers.get("boss", blade_pos)
	var status_effect_state: Object = deps.get("status_effect_state", null)
	if status_effect_state != null and status_effect_state.has_method("apply_status"):
		status_effect_state.apply_status("boss", "slow", SLOW_FRAMES, {"multiplier": SLOW_MULTIPLIER, "cleansable": true}, SKILL_ID)
	last_action_hit = true
	blade_pos.x = boss_center.x
	_finish_blade_flight(true, config, deps)


func _finish_blade_flight(hit: bool, config: Dictionary, deps: Dictionary) -> void:
	if not blade_active:
		return
	var impact_pos := blade_pos
	var impact_direction := blade_direction
	blade_active = false
	_begin_return(deps, true, config)
	_start_blade_burst(impact_pos, impact_direction)
	if not hit:
		last_action_hit = false


func draw_effects(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return
	_draw_fuse_telegraph(canvas, shake_offset)
	_draw_blast_vfx(canvas, shake_offset)
	if blade_active and _blade_trail_texture != null:
		var tip := blade_pos + shake_offset
		var trail_rect := _blade_tip_rect(tip, blade_direction, BLADE_TRAIL_DRAW_SIZE)
		var glow_rect := trail_rect.grow(5.0)
		_draw_directional_texture_region(
			canvas,
			_blade_trail_texture,
			BLADE_TRAIL_SOURCE_RECT,
			glow_rect,
			blade_direction,
			Color(0.35, 0.72, 1.0, 0.28)
		)
		_draw_directional_texture_region(
			canvas,
			_blade_trail_texture,
			BLADE_TRAIL_SOURCE_RECT,
			trail_rect,
			blade_direction,
			Color(0.82, 0.95, 1.0, 0.96)
		)
	if blade_burst_active and _blade_burst_texture != null:
		var ratio := clampf(blade_burst_elapsed_seconds / BLADE_BURST_SECONDS, 0.0, 1.0)
		var scale := lerpf(0.72, 1.12, ratio)
		var burst_size := BLADE_BURST_DRAW_SIZE * scale
		var burst_rect := Rect2(blade_burst_pos + shake_offset - burst_size * 0.5, burst_size)
		_draw_directional_texture_region(
			canvas,
			_blade_burst_texture,
			BLADE_BURST_SOURCE_RECT,
			burst_rect,
			blade_burst_direction,
			Color(0.72, 0.91, 1.0, (1.0 - ratio) * 0.92)
		)


func _update_blade_burst(delta: float) -> void:
	if not blade_burst_active:
		return
	blade_burst_elapsed_seconds += delta
	if blade_burst_elapsed_seconds >= BLADE_BURST_SECONDS:
		_clear_blade_burst()


func _update_presentation_effects(delta: float) -> void:
	_update_blade_burst(delta)
	if not blast_vfx_active:
		return
	blast_vfx_elapsed_seconds += delta
	if blast_vfx_elapsed_seconds >= BLAST_VFX_SECONDS:
		_clear_blast_vfx()


func _draw_fuse_telegraph(canvas: CanvasItem, shake_offset: Vector2) -> void:
	if state != STATE_FUSE or fuse_visual_center == Vector2.ZERO:
		return
	var ratio := clampf(elapsed_seconds / FUSE_SECONDS, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(ratio * TAU * 4.0)
	var center := fuse_visual_center + shake_offset
	ImpactFlareTextureCache.draw_glow(canvas, center, lerpf(30.0, 52.0, ratio), Color(0.24, 0.86, 1.0), 0.18 + ratio * 0.24)
	ImpactShockwaveTextureCache.draw_full_ring(canvas, center, lerpf(68.0, 29.0, ratio), Color(0.54, 0.94, 1.0), 0.34 + pulse * 0.20)
	ImpactShockwaveTextureCache.draw_full_ring(canvas, center, lerpf(43.0, 20.0, ratio), Color(0.72, 0.38, 1.0), 0.18 + ratio * 0.28)
	for index in range(4):
		var angle := TAU * float(index) / 4.0 - ratio * TAU * 1.5
		var orbit_pos := center + Vector2.from_angle(angle) * lerpf(52.0, 23.0, ratio)
		ImpactFlareTextureCache.draw_sparkle(canvas, orbit_pos, 7.0 + pulse * 3.0, Color(0.76, 0.94, 1.0), 0.42 + ratio * 0.36)


func _draw_blast_vfx(canvas: CanvasItem, shake_offset: Vector2) -> void:
	if not blast_vfx_active:
		return
	var ratio := clampf(blast_vfx_elapsed_seconds / BLAST_VFX_SECONDS, 0.0, 1.0)
	var core_ratio := clampf(blast_vfx_elapsed_seconds / BLAST_CORE_SECONDS, 0.0, 1.0)
	var fade := pow(1.0 - ratio, 1.35)
	var flash := pow(1.0 - core_ratio, 2.2)
	var center := blast_vfx_origin + shake_offset
	ImpactFlareTextureCache.draw_glow(canvas, center, lerpf(54.0, 126.0, ratio), Color(0.20, 0.86, 1.0), fade * 0.72)
	ImpactFlareTextureCache.draw_glow(canvas, center, lerpf(28.0, 74.0, ratio), Color(0.72, 0.32, 1.0), fade * 0.54)
	ImpactFlareTextureCache.draw_burst(canvas, center, lerpf(58.0, 148.0, ratio), Color(0.58, 0.94, 1.0), fade * 0.92)
	if flash > 0.0:
		canvas.draw_circle(center, lerpf(25.0, 10.0, core_ratio), Color(0.95, 1.0, 1.0, flash * 0.96))
	_draw_blast_ring(canvas, center, ratio, 0.0, Color(0.52, 0.96, 1.0), 36.0, 142.0)
	_draw_blast_ring(canvas, center, ratio, 0.16, Color(0.72, 0.34, 1.0), 28.0, 112.0)
	for index in range(BLAST_RAY_COUNT):
		var angle := TAU * float(index) / float(BLAST_RAY_COUNT) + 0.17
		var ray_scale := 0.78 + 0.22 * sin(float(index) * 1.91)
		var direction := Vector2.from_angle(angle)
		var inner := center + direction * lerpf(16.0, 46.0, ratio)
		var outer := center + direction * lerpf(72.0, 168.0 * ray_scale, ratio)
		canvas.draw_line(inner, outer, Color(0.68, 0.94, 1.0, fade * 0.72), lerpf(4.2, 1.0, ratio), true)
	for index in range(BLAST_SPARKLE_COUNT):
		var sparkle_angle := TAU * float(index) / float(BLAST_SPARKLE_COUNT) - 0.31
		var sparkle_pos := center + Vector2.from_angle(sparkle_angle) * lerpf(42.0, 154.0, ratio)
		ImpactFlareTextureCache.draw_sparkle(canvas, sparkle_pos, lerpf(15.0, 6.0, ratio), Color(0.84, 0.98, 1.0), fade * 0.88)
	if blast_vfx_hit:
		var hit_center := blast_vfx_hit_pos + shake_offset
		ImpactFlareTextureCache.draw_glow(canvas, hit_center, lerpf(34.0, 74.0, ratio), Color(0.82, 0.38, 1.0), fade * 0.60)
		ImpactFlareTextureCache.draw_burst(canvas, hit_center, lerpf(30.0, 82.0, ratio), Color(0.96, 0.98, 1.0), fade * 0.74)


func _draw_blast_ring(canvas: CanvasItem, center: Vector2, ratio: float, delay: float, color: Color, from_radius: float, to_radius: float) -> void:
	var phase := clampf((ratio - delay) / maxf(0.001, 1.0 - delay), 0.0, 1.0)
	if ratio < delay or phase >= 1.0:
		return
	ImpactShockwaveTextureCache.draw_full_ring(canvas, center, lerpf(from_radius, to_radius, phase), color, pow(1.0 - phase, 1.4) * 0.92)


func _start_blade_burst(position: Vector2, direction: int) -> void:
	blade_burst_active = true
	blade_burst_elapsed_seconds = 0.0
	blade_burst_pos = position
	blade_burst_direction = -1 if direction < 0 else 1


func _clear_blade_burst() -> void:
	blade_burst_active = false
	blade_burst_elapsed_seconds = 0.0
	blade_burst_pos = Vector2.ZERO
	blade_burst_direction = 1


func _start_blast_vfx(origin: Vector2, hit_pos: Vector2, hit: bool) -> void:
	blast_vfx_active = true
	blast_vfx_elapsed_seconds = 0.0
	blast_vfx_origin = origin
	blast_vfx_hit = hit
	blast_vfx_hit_pos = hit_pos if hit else origin


func _clear_blast_vfx() -> void:
	blast_vfx_active = false
	blast_vfx_elapsed_seconds = 0.0
	blast_vfx_origin = Vector2.ZERO
	blast_vfx_hit = false
	blast_vfx_hit_pos = Vector2.ZERO


func _clear_blade_action_state(clear_slash_clock: bool = true) -> void:
	if clear_slash_clock:
		slash_animation_elapsed_seconds = 0.0
		slash_presentation_active = false
	blade_active = false
	blade_pos = Vector2.ZERO
	blade_previous_pos = Vector2.ZERO
	blade_origin_player_center_x = 0.0
	blade_direction = 1


func _is_slash_animation_visible() -> bool:
	return (
		state in [STATE_SLASH, STATE_BLADE_FLIGHT, STATE_RETURN]
		and slash_presentation_active
		and slash_animation_elapsed_seconds < SLASH_ANIMATION_SECONDS
	)


func _get_slash_animation_frame() -> int:
	return clampi(int(floor(slash_animation_elapsed_seconds / SLASH_FRAME_SECONDS)), 0, SLASH_FRAME_COUNT - 1)


func _uses_infiltration_ball_slow() -> bool:
	return state in [STATE_INFILTRATING, STATE_FUSE, STATE_SLASH, STATE_BLADE_FLIGHT]


func _blade_tip_rect(tip: Vector2, direction: int, size: Vector2) -> Rect2:
	var x := tip.x - size.x if direction > 0 else tip.x
	return Rect2(Vector2(x, tip.y - size.y * 0.5), size)


func _draw_directional_texture_region(
	canvas: CanvasItem,
	texture: Texture2D,
	source_rect: Rect2,
	target_rect: Rect2,
	direction: int,
	modulate: Color
) -> void:
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var points := PackedVector2Array([
		target_rect.position,
		Vector2(target_rect.end.x, target_rect.position.y),
		target_rect.end,
		Vector2(target_rect.position.x, target_rect.end.y),
	])
	var uv_min := Vector2(source_rect.position.x / texture_size.x, source_rect.position.y / texture_size.y)
	var uv_max := Vector2(source_rect.end.x / texture_size.x, source_rect.end.y / texture_size.y)
	var flip_h := direction < 0
	var uvs := PackedVector2Array([
		Vector2(uv_max.x, uv_min.y) if flip_h else Vector2(uv_min.x, uv_min.y),
		Vector2(uv_min.x, uv_min.y) if flip_h else Vector2(uv_max.x, uv_min.y),
		Vector2(uv_min.x, uv_max.y) if flip_h else Vector2(uv_max.x, uv_max.y),
		Vector2(uv_max.x, uv_max.y) if flip_h else Vector2(uv_min.x, uv_max.y),
	])
	var colors := PackedColorArray([modulate, modulate, modulate, modulate])
	canvas.draw_polygon(points, colors, uvs, texture)


func _commit_blast(config: Dictionary, deps: Dictionary) -> bool:
	var centers := _combat_centers(config)
	var player_center: Vector2 = centers.get("player", current_pos)
	var boss_center: Vector2 = centers.get("boss", Vector2.ZERO)
	var hit := absf(boss_center.x - player_center.x) <= BLAST_RANGE_X
	_start_blast_vfx(player_center, boss_center, hit)
	_trigger_blast_feedback(deps, hit)
	if not hit:
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


func _trigger_blast_feedback(deps: Dictionary, hit: bool) -> void:
	var feedback: Object = deps.get("feedback", null)
	if feedback == null:
		return
	var intensity := BLAST_SHAKE_HIT_INTENSITY if hit else BLAST_SHAKE_MISS_INTENSITY
	if feedback.has_method("max_screen_shake"):
		feedback.max_screen_shake(BLAST_SHAKE_AMOUNT, intensity)
	elif feedback.has_method("set_screen_shake"):
		feedback.set_screen_shake(BLAST_SHAKE_AMOUNT, intensity)


func _combat_centers(config: Dictionary) -> Dictionary:
	var player_size := _vector2(config.get("player_paddle_size", Vector2(float(config.get("paddle_width", 155.0)), float(config.get("paddle_height", 50.0)))), Vector2(155.0, 50.0))
	var boss_pos := _vector2(config.get("boss_pos", Vector2.ZERO), Vector2.ZERO)
	var boss_size := _vector2(config.get("boss_paddle_size", Vector2(float(config.get("boss_paddle_width", 100.0)), float(config.get("boss_hitbox_height", 40.0)))), Vector2(100.0, 40.0))
	return {"player": current_pos + player_size * 0.5, "boss": boss_pos + boss_size * 0.5}


func _ball_aligned_return_pos(config: Dictionary) -> Vector2:
	if not config.has("ball_pos") or not (config.get("ball_pos") is Vector2):
		return entry_pos
	var ball_center: Vector2 = config.get("ball_pos", Vector2.ZERO)
	var paddle_width := maxf(1.0, float(config.get("paddle_width", config.get("player_paddle_width", 155.0))))
	var width := maxf(paddle_width, float(config.get("width", 760.0)))
	var target_x := clampf(ball_center.x - paddle_width * 0.5, 0.0, width - paddle_width)
	return Vector2(target_x, entry_pos.y)


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
