extends RefCounted

const GAUGE_COST := 300.0
const COOLDOWN_SEC := 20.0
const CHARGING_SEC := 0.43
const IMPACT_SEC := 0.20
const RETURNING_SEC := 0.50
const STUN_SEC := 1.50
# Boss stun length is intentionally decoupled from the state-machine STUN phase
# (STUN_SEC is only the player's post-charge settle window). This is how long the boss
# stays frozen after the headbutt impact. Design-tuned 1.5s -> 3.0s.
const BOSS_STUN_SEC := 3.0
# Godot-tuned strong knockback: close to 5.6x the shipped normal paddle hit.
const BOSS_KNOCKBACK := 73.0
const BOSS_STUN_FRAMES := BOSS_STUN_SEC * 60.0
const BOSS_KNOCKBACK_FRAMES := 36.0
const BOSS_KNOCKBACK_DECAY := 0.86
const SUPPRESS_WINDOW_FRAMES := 4.0
const TRAIL_LIFE_SEC := 0.28
# Python impact shake: screen_shake_timer=24 frames, intensity=35 px. Converted with
# the grenade/dynamite precedent (Python 40f/35 -> Godot amount 40/30, intensity 9.0).
const IMPACT_SHAKE_AMOUNT := 24.0 / 30.0
const IMPACT_SHAKE_INTENSITY := 9.0
const SOURCE := "horn_strawberry_horn_charge"

const PHASE_NONE := ""
const PHASE_CHARGING := "charging"
const PHASE_IMPACT := "impact"
const PHASE_RETURNING := "returning"
const PHASE_STUN := "stun"

var active := false
var phase := PHASE_NONE
var phase_timer_sec := 0.0
var phase_duration_sec := 0.0
var cooldown_sec := 0.0
var player_origin := Vector2.ZERO
var player_center := Vector2.ZERO
var target_center := Vector2.ZERO
var current_offset := Vector2.ZERO
var trails: Array[Dictionary] = []
var impact_flash_timer_sec := 0.0
var last_hit_count := 0
var suppress_paddle_hit_knockback_frames := 0.0
var suppress_boss_vel := 0.0
var _input_prev_down := false


func reset() -> void:
	active = false
	phase = PHASE_NONE
	phase_timer_sec = 0.0
	phase_duration_sec = 0.0
	cooldown_sec = 0.0
	player_origin = Vector2.ZERO
	player_center = Vector2.ZERO
	target_center = Vector2.ZERO
	current_offset = Vector2.ZERO
	trails.clear()
	impact_flash_timer_sec = 0.0
	last_hit_count = 0
	suppress_paddle_hit_knockback_frames = 0.0
	suppress_boss_vel = 0.0
	_input_prev_down = false


func can_use(current_gauge: float) -> bool:
	return not active and cooldown_sec <= 0.0 and current_gauge + 0.001 >= GAUGE_COST


func update_input(input_snapshot: Dictionary, owner: Object, runtime: Object, registry: Object, blocked: bool = false) -> bool:
	var input_down: bool = bool(input_snapshot.get("up_pressed", false))
	var just_pressed: bool = bool(input_snapshot.get("up_just_pressed", false))
	if not input_snapshot.has("up_just_pressed"):
		just_pressed = input_down and not _input_prev_down
	_input_prev_down = input_down
	if blocked or not just_pressed:
		return false
	var current_gauge: float = _get_owner_gauge(runtime, owner)
	if not can_use(current_gauge):
		return false
	if owner != null:
		owner.set("special_gauge", max(0.0, current_gauge - GAUGE_COST))
	_start_charge(owner)
	_play_audio(runtime, registry, "_play_horn_strawberry_horn_charge_audio")
	_trigger_feedback(registry)
	return true


func update(delta: float, owner: Object, registry: Object, runtime: Object = null) -> void:
	var safe_delta: float = max(0.0, delta)
	cooldown_sec = max(0.0, cooldown_sec - safe_delta)
	if suppress_paddle_hit_knockback_frames > 0.0:
		suppress_paddle_hit_knockback_frames = max(0.0, suppress_paddle_hit_knockback_frames - safe_delta * 60.0)
	if impact_flash_timer_sec > 0.0:
		impact_flash_timer_sec = max(0.0, impact_flash_timer_sec - safe_delta)
	_update_trails(safe_delta)
	if not active:
		current_offset = Vector2.ZERO
		return
	phase_timer_sec = max(0.0, phase_timer_sec - safe_delta)
	_update_phase_offset()
	if phase_timer_sec > 0.0:
		return
	match phase:
		PHASE_CHARGING:
			_enter_phase(PHASE_IMPACT, IMPACT_SEC)
			_apply_boss_impact(owner, registry, runtime)
		PHASE_IMPACT:
			_enter_phase(PHASE_RETURNING, RETURNING_SEC)
		PHASE_RETURNING:
			_enter_phase(PHASE_STUN, STUN_SEC)
		PHASE_STUN:
			active = false
			phase = PHASE_NONE
			phase_timer_sec = 0.0
			phase_duration_sec = 0.0
			current_offset = Vector2.ZERO


func consume_boss_hit_suppression(_ball_pos: Vector2, _ball_vel: Vector2, _context: Dictionary, _deps: Dictionary = {}) -> Dictionary:
	if suppress_paddle_hit_knockback_frames <= 0.0 or abs(suppress_boss_vel) <= 0.001:
		return {}
	suppress_paddle_hit_knockback_frames = 0.0
	return {
		"boss_vel": suppress_boss_vel,
		"horn_strawberry_horn_charge_hit": true,
		"horn_strawberry_horn_charge_consumed": true,
		"suppress_paddle_hit_knockback": true,
	}


func is_control_locked() -> bool:
	return active and (phase == PHASE_CHARGING or phase == PHASE_IMPACT)


func has_runtime_update_work() -> bool:
	return (
		active
		or cooldown_sec > 0.0
		or suppress_paddle_hit_knockback_frames > 0.0
		or impact_flash_timer_sec > 0.0
		or not trails.is_empty()
	)


func has_visible_effects() -> bool:
	return active or impact_flash_timer_sec > 0.0 or not trails.is_empty()


func get_context() -> Dictionary:
	return {
		"active": active,
		"phase": phase,
		"phase_timer_sec": phase_timer_sec,
		"phase_duration_sec": phase_duration_sec,
		"cooldown_sec": cooldown_sec,
		"cooldown_max_sec": COOLDOWN_SEC,
		"gauge_cost": GAUGE_COST,
		"charging_sec": CHARGING_SEC,
		"impact_sec": IMPACT_SEC,
		"returning_sec": RETURNING_SEC,
		"stun_sec": STUN_SEC,
		"player_center": player_center,
		"target_center": target_center,
		"current_offset": current_offset,
		"trails": trails.duplicate(true),
		"impact_flash_timer_sec": impact_flash_timer_sec,
		"last_hit_count": last_hit_count,
		"boss_knockback": BOSS_KNOCKBACK,
		"suppress_paddle_hit_knockback_frames": suppress_paddle_hit_knockback_frames,
	}


func _start_charge(owner: Object) -> void:
	active = true
	cooldown_sec = COOLDOWN_SEC
	player_origin = _get_player_center(owner)
	player_center = player_origin
	target_center = _get_charge_target_center(owner)
	current_offset = Vector2.ZERO
	trails.clear()
	_enter_phase(PHASE_CHARGING, CHARGING_SEC)


func _enter_phase(next_phase: String, duration_sec: float) -> void:
	phase = next_phase
	phase_duration_sec = max(0.001, duration_sec)
	phase_timer_sec = phase_duration_sec


func _update_phase_offset() -> void:
	if not active:
		current_offset = Vector2.ZERO
		return
	var progress: float = 1.0 - clamp(phase_timer_sec / max(0.001, phase_duration_sec), 0.0, 1.0)
	var target_offset := Vector2(
		target_center.x - player_origin.x,
		clamp(target_center.y - player_origin.y, -640.0, -80.0)
	)
	match phase:
		PHASE_CHARGING:
			current_offset = target_offset * _ease_in_cubic(progress)
		PHASE_IMPACT:
			current_offset = target_offset
		PHASE_RETURNING:
			current_offset = target_offset * (1.0 - _ease_out_cubic(progress))
		PHASE_STUN:
			current_offset = Vector2.ZERO
		_:
			current_offset = Vector2.ZERO
	player_center = player_origin + current_offset


func _apply_boss_impact(owner: Object, registry: Object, _runtime: Object) -> void:
	var boss_rect: Rect2 = _get_boss_rect(owner)
	if boss_rect.size.x <= 0.0 or boss_rect.size.y <= 0.0:
		return
	target_center = _get_charge_target_center(owner)
	var direction: float = 1.0 if player_origin.x <= target_center.x else -1.0
	if abs(player_origin.x - target_center.x) <= 0.01:
		direction = 1.0 if target_center.x < 380.0 else -1.0
	var knockback_vel: float = direction * BOSS_KNOCKBACK
	_clear_ai_paddle_hit_knockback(registry)
	var status_state: Object = _get_instance(registry, "status_effect_state")
	var applied_status := false
	if status_state != null and status_state.has_method("apply_status"):
		status_state.apply_status(
			"boss",
			"stun",
			BOSS_STUN_FRAMES,
			{
				"knockback_vel": knockback_vel,
				"knockback_active": abs(knockback_vel) > 0.001,
				"knockback_frames": BOSS_KNOCKBACK_FRAMES,
				"knockback_decay_per_frame": BOSS_KNOCKBACK_DECAY,
				"knockback_stop_threshold": 0.3,
				"suppress_paddle_hit_knockback": true,
				"suppress_stun_stars": false,
			},
			SOURCE
		)
		applied_status = true
	var ai_state: Object = _get_instance(registry, "boss_ai_state")
	if not applied_status and ai_state != null and ai_state.has_method("start_paddle_hit_knockback"):
		ai_state.start_paddle_hit_knockback(knockback_vel, BOSS_KNOCKBACK_FRAMES, BOSS_KNOCKBACK_DECAY, true)
	suppress_paddle_hit_knockback_frames = SUPPRESS_WINDOW_FRAMES
	suppress_boss_vel = knockback_vel
	impact_flash_timer_sec = IMPACT_SEC
	last_hit_count += 1
	_trigger_feedback(registry)
	_trigger_impact_shake(registry)


func _update_trails(delta: float) -> void:
	if active and (phase == PHASE_CHARGING or phase == PHASE_RETURNING):
		trails.append({
			"position": player_center,
			"timer_sec": TRAIL_LIFE_SEC,
			"life_sec": TRAIL_LIFE_SEC,
			"phase": phase,
		})
	if trails.is_empty():
		return
	var alive: Array[Dictionary] = []
	for trail in trails:
		var next_trail: Dictionary = trail.duplicate(true)
		next_trail["timer_sec"] = max(0.0, float(next_trail.get("timer_sec", 0.0)) - delta)
		if float(next_trail.get("timer_sec", 0.0)) > 0.0:
			alive.append(next_trail)
	trails = alive


func _get_owner_gauge(runtime: Object, owner: Object) -> float:
	if runtime == null:
		return 0.0
	return max(0.0, float(runtime._safe_owner_get(owner, "special_gauge", 0.0)))


func _get_player_center(owner: Object) -> Vector2:
	if owner == null:
		return Vector2(380.0, 700.0)
	var pos: Vector2 = _as_vector2(owner.get("player_pos"), Vector2(300.0, 700.0))
	var width: float = _get_owner_float(owner, "player_paddle_width", 155.0)
	var height: float = _get_owner_float(owner, "player_paddle_height", 50.0)
	return pos + Vector2(width * 0.5, height * 0.5)


func _get_boss_center(owner: Object) -> Vector2:
	var rect: Rect2 = _get_boss_rect(owner)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return Vector2(380.0, 55.0)
	return rect.position + rect.size * 0.5


func _get_charge_target_center(owner: Object) -> Vector2:
	var rect: Rect2 = _get_boss_rect(owner)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return Vector2(380.0, 60.0)
	var player_height: float = _get_owner_float(owner, "player_paddle_height", 50.0)
	return Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + player_height * 0.5)


func _get_boss_rect(owner: Object) -> Rect2:
	if owner == null:
		return Rect2(Vector2(330.0, 35.0), Vector2(100.0, 40.0))
	var pos: Vector2 = _as_vector2(owner.get("boss_pos"), Vector2(330.0, 35.0))
	var width: float = _get_owner_float(owner, "boss_paddle_width", 100.0)
	var height: float = _get_owner_float(owner, "boss_hitbox_height", 40.0)
	return Rect2(pos, Vector2(max(1.0, width), max(1.0, height)))


func _clear_ai_paddle_hit_knockback(registry: Object) -> void:
	var ai_state: Object = _get_instance(registry, "boss_ai_state")
	if ai_state != null and ai_state.has_method("clear_paddle_hit_knockback"):
		ai_state.clear_paddle_hit_knockback()


func _trigger_feedback(registry: Object) -> void:
	var feedback: Object = _get_instance(registry, "battle_feedback_state")
	if feedback != null and feedback.has_method("trigger_gauge_flash"):
		feedback.trigger_gauge_flash()


func _trigger_impact_shake(registry: Object) -> void:
	var feedback: Object = _get_instance(registry, "battle_feedback_state")
	if feedback == null:
		return
	if feedback.has_method("max_screen_shake"):
		feedback.max_screen_shake(IMPACT_SHAKE_AMOUNT, IMPACT_SHAKE_INTENSITY)
	elif feedback.has_method("set_screen_shake"):
		feedback.set_screen_shake(IMPACT_SHAKE_AMOUNT, IMPACT_SHAKE_INTENSITY)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _play_audio(runtime: Object, registry: Object, method_name: String) -> void:
	if runtime == null:
		return
	var audio_router: Object = runtime.get("audio_router")
	if audio_router != null and audio_router.has_method("play_named"):
		audio_router.play_named(runtime, registry, method_name)


func _get_owner_float(owner: Object, key: String, fallback: float) -> float:
	if owner == null:
		return fallback
	var value: Variant = owner.get(key)
	if value == null:
		return fallback
	return float(value)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _ease_in_cubic(t: float) -> float:
	var clamped: float = clamp(t, 0.0, 1.0)
	return clamped * clamped * clamped


func _ease_out_cubic(t: float) -> float:
	var clamped: float = clamp(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - clamped, 3.0)
