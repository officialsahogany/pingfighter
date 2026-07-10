extends RefCounted

const EAT_DURATION_SEC := 0.8
const GAUGE_COST := 50.0
const PADDLE_GROWTH_BONUS_PCT := 0.20
const STEM_BURST_COUNT := 3
const STEM_BURST_INTERVAL_SEC := 0.08
const STEM_SPREAD_DEGREES := 10.0
const EAT_COOLDOWN_SEC := 0.8
const STEM_BASE_SPEED := 7.0
const STEM_SPEED_MULT := 2.5
const STEM_LIFE_SEC := 3.0
const STEM_SIZE := 20.0
const STEM_STUN_SEC := 0.3
const STEM_KNOCKBACK := 32.2
const STEM_KNOCKBACK_FRAMES := 18.0
const STEM_KNOCKBACK_DECAY := 0.86
# Python stem-hit shake: screen_shake_timer=12 frames, intensity=15 px. Converted with
# the grenade/dynamite precedent (Python 40f/35 -> Godot amount 40/30, intensity 9.0).
const STEM_HIT_SHAKE_AMOUNT := 12.0 / 30.0
const STEM_HIT_SHAKE_INTENSITY := 15.0 * 9.0 / 35.0
const STEM_SOURCE := "horn_strawberry_stem"

var eating := false
var eat_timer_sec := 0.0
var cooldown_sec := 0.0
var projectiles: Array[Dictionary] = []
var head_bob_timer_sec := 0.0
var last_hit_count := 0
var _queued_stem_shots := 0
var _stem_burst_timer_sec := 0.0
var _stem_burst_origin := Vector2.ZERO
var _input_prev_down := false
var _next_projectile_id := 1


func reset() -> void:
	eating = false
	eat_timer_sec = 0.0
	cooldown_sec = 0.0
	projectiles.clear()
	head_bob_timer_sec = 0.0
	last_hit_count = 0
	_queued_stem_shots = 0
	_stem_burst_timer_sec = 0.0
	_stem_burst_origin = Vector2.ZERO
	_input_prev_down = false


func can_use(current_gauge: float) -> bool:
	return not eating and cooldown_sec <= 0.0 and current_gauge + 0.001 >= GAUGE_COST


func update_input(input_snapshot: Dictionary, owner: Object, runtime: Object, registry: Object) -> bool:
	var input_down: bool = _is_eat_input_down(input_snapshot)
	var just_pressed: bool = bool(input_snapshot.get("action_just_pressed", false))
	if not input_snapshot.has("action_just_pressed"):
		just_pressed = input_down and not _input_prev_down
	_input_prev_down = input_down
	if not just_pressed:
		return false
	var current_gauge: float = _get_owner_gauge(runtime, owner)
	if not can_use(current_gauge):
		return false
	if owner != null:
		owner.set("special_gauge", max(0.0, current_gauge - GAUGE_COST))
	eating = true
	eat_timer_sec = EAT_DURATION_SEC
	runtime.add_horn_strawberry_eat_paddle_growth(owner, registry, PADDLE_GROWTH_BONUS_PCT)
	_play_audio(runtime, registry, "_play_horn_strawberry_eat_audio")
	return true


func update(delta: float, owner: Object, registry: Object, runtime: Object = null) -> void:
	var safe_delta: float = max(0.0, delta)
	if eating:
		eat_timer_sec = max(0.0, eat_timer_sec - safe_delta)
		if eat_timer_sec <= 0.0:
			eating = false
			cooldown_sec = EAT_COOLDOWN_SEC
			_recover_dash_token(registry)
			_play_audio(runtime, registry, "_stop_horn_strawberry_eat_audio")
			_start_stem_burst(_get_player_stem_origin(owner), runtime, registry)
			head_bob_timer_sec = 0.4
			return
	else:
		cooldown_sec = max(0.0, cooldown_sec - safe_delta)

	if head_bob_timer_sec > 0.0:
		head_bob_timer_sec = max(0.0, head_bob_timer_sec - safe_delta)

	if _queued_stem_shots > 0:
		_stem_burst_timer_sec -= safe_delta
		while _queued_stem_shots > 0 and _stem_burst_timer_sec <= 0.0:
			_fire_stem(_stem_burst_origin, runtime, registry)
			_queued_stem_shots -= 1
			_stem_burst_timer_sec += STEM_BURST_INTERVAL_SEC

	_update_projectiles(safe_delta)
	_resolve_boss_hits(owner, registry, runtime)


func has_runtime_update_work() -> bool:
	return (
		eating
		or cooldown_sec > 0.0
		or not projectiles.is_empty()
		or _queued_stem_shots > 0
		or head_bob_timer_sec > 0.0
	)


func has_visible_effects() -> bool:
	return eating or not projectiles.is_empty() or head_bob_timer_sec > 0.0


func get_context() -> Dictionary:
	return {
		"eating": eating,
		"eat_timer_sec": eat_timer_sec,
		"eat_duration_sec": EAT_DURATION_SEC,
		"cooldown_sec": cooldown_sec,
		"cooldown_max_sec": EAT_COOLDOWN_SEC,
		"gauge_cost": GAUGE_COST,
		"paddle_growth_bonus_pct": PADDLE_GROWTH_BONUS_PCT,
		"projectiles": projectiles.duplicate(true),
		"projectile_count": projectiles.size(),
		"queued_stem_shots": _queued_stem_shots,
		"head_bob_timer_sec": head_bob_timer_sec,
		"last_hit_count": last_hit_count,
	}


func _is_eat_input_down(input_snapshot: Dictionary) -> bool:
	return (
		bool(input_snapshot.get("action_pressed", false))
		or bool(input_snapshot.get("action_just_pressed", false))
	)


func _get_owner_gauge(runtime: Object, owner: Object) -> float:
	if runtime == null:
		return 0.0
	return max(0.0, float(runtime._safe_owner_get(owner, "special_gauge", 0.0)))


func _get_player_stem_origin(owner: Object) -> Vector2:
	if owner == null:
		return Vector2(380.0, 680.0)
	var player_pos: Vector2 = _as_vector2(owner.get("player_pos"), Vector2(300.0, 700.0))
	var paddle_width: float = max(1.0, float(owner.get("player_paddle_width") if owner.get("player_paddle_width") != null else 155.0))
	return Vector2(player_pos.x + paddle_width * 0.5, player_pos.y - 20.0)


func _start_stem_burst(origin: Vector2, runtime: Object, registry: Object) -> void:
	_stem_burst_origin = origin
	_fire_stem(origin, runtime, registry)
	_queued_stem_shots = max(0, STEM_BURST_COUNT - 1)
	_stem_burst_timer_sec = STEM_BURST_INTERVAL_SEC


func _fire_stem(origin: Vector2, runtime: Object, registry: Object) -> void:
	var shot_index: int = projectiles.size() + _queued_stem_shots
	var angle_deg: float = 0.0
	if STEM_BURST_COUNT > 1:
		var spread_slot: int = clamp(shot_index, 0, STEM_BURST_COUNT - 1)
		angle_deg = lerp(-STEM_SPREAD_DEGREES, STEM_SPREAD_DEGREES, float(spread_slot) / float(STEM_BURST_COUNT - 1))
	var angle_rad: float = deg_to_rad(angle_deg)
	var speed: float = STEM_BASE_SPEED * STEM_SPEED_MULT
	projectiles.append({
		"id": _next_projectile_id,
		"position": origin,
		"velocity": Vector2(sin(angle_rad) * speed, -cos(angle_rad) * speed),
		"rotation": angle_rad,
		"rot_speed": 5.0,
		"life_sec": STEM_LIFE_SEC,
		"size": STEM_SIZE,
		"stun_duration_sec": STEM_STUN_SEC,
		"knockback": STEM_KNOCKBACK,
	})
	_next_projectile_id += 1
	_play_audio(runtime, registry, "_play_horn_strawberry_stem_fire_audio")


func _update_projectiles(delta: float) -> void:
	if projectiles.is_empty():
		return
	var alive: Array[Dictionary] = []
	for projectile in projectiles:
		var next_projectile: Dictionary = projectile.duplicate(true)
		var position: Vector2 = _as_vector2(next_projectile.get("position", Vector2.ZERO), Vector2.ZERO)
		var velocity: Vector2 = _as_vector2(next_projectile.get("velocity", Vector2.ZERO), Vector2.ZERO)
		position += velocity * delta * 60.0
		next_projectile["position"] = position
		next_projectile["rotation"] = float(next_projectile.get("rotation", 0.0)) + float(next_projectile.get("rot_speed", 0.0)) * delta * 60.0
		next_projectile["life_sec"] = max(0.0, float(next_projectile.get("life_sec", 0.0)) - delta)
		if float(next_projectile.get("life_sec", 0.0)) > 0.0 and position.y > -20.0:
			alive.append(next_projectile)
	projectiles = alive


func _resolve_boss_hits(owner: Object, registry: Object, runtime: Object) -> void:
	if projectiles.is_empty():
		return
	var boss_rect: Rect2 = _get_boss_rect(owner)
	if boss_rect.size.x <= 0.0 or boss_rect.size.y <= 0.0:
		return
	var survivors: Array[Dictionary] = []
	for projectile in projectiles:
		var projectile_rect := Rect2(
			_as_vector2(projectile.get("position", Vector2.ZERO), Vector2.ZERO) - Vector2(STEM_SIZE * 0.5, STEM_SIZE * 0.5),
			Vector2(STEM_SIZE, STEM_SIZE)
		)
		if projectile_rect.intersects(boss_rect):
			_apply_boss_hit(projectile, boss_rect, registry, runtime)
		else:
			survivors.append(projectile)
	projectiles = survivors


func _apply_boss_hit(projectile: Dictionary, boss_rect: Rect2, registry: Object, runtime: Object) -> void:
	last_hit_count += 1
	_play_audio(runtime, registry, "_play_horn_strawberry_stem_hit_audio")
	var projectile_pos: Vector2 = _as_vector2(projectile.get("position", Vector2.ZERO), Vector2.ZERO)
	var boss_center_x: float = boss_rect.position.x + boss_rect.size.x * 0.5
	var direction: float = 1.0 if projectile_pos.x < boss_center_x else -1.0
	var knockback_vel: float = direction * max(0.0, float(projectile.get("knockback", STEM_KNOCKBACK)))
	var status_state: Object = _get_instance(registry, "status_effect_state")
	var applied_status := false
	if status_state != null and status_state.has_method("apply_status"):
		status_state.apply_status(
			"boss",
			"stun",
			max(0.0, float(projectile.get("stun_duration_sec", STEM_STUN_SEC))) * 60.0,
			{
				"knockback_vel": knockback_vel,
				"knockback_active": abs(knockback_vel) > 0.001,
				"knockback_frames": STEM_KNOCKBACK_FRAMES,
				"knockback_decay_per_frame": STEM_KNOCKBACK_DECAY,
				"knockback_stop_threshold": 0.3,
				"suppress_paddle_hit_knockback": true,
				"suppress_stun_stars": false,
			},
			STEM_SOURCE
		)
		applied_status = true
	var ai_state: Object = _get_instance(registry, "boss_ai_state")
	if not applied_status and ai_state != null and ai_state.has_method("start_paddle_hit_knockback"):
		ai_state.start_paddle_hit_knockback(knockback_vel, STEM_KNOCKBACK_FRAMES, STEM_KNOCKBACK_DECAY, true)
	var feedback: Object = _get_instance(registry, "battle_feedback_state")
	if feedback != null:
		if feedback.has_method("max_screen_shake"):
			feedback.max_screen_shake(STEM_HIT_SHAKE_AMOUNT, STEM_HIT_SHAKE_INTENSITY)
		elif feedback.has_method("set_screen_shake"):
			feedback.set_screen_shake(STEM_HIT_SHAKE_AMOUNT, STEM_HIT_SHAKE_INTENSITY)


func _recover_dash_token(registry: Object) -> void:
	var dash_state: Object = _get_instance(registry, "smasher_dash_state")
	if dash_state == null:
		return
	var token_state: Variant = dash_state.get("token_state")
	if not (token_state is Object):
		return
	var max_tokens: int = max(1, int(token_state.get("dash_tokens_max")))
	var current_tokens: int = max(0, int(token_state.get("dash_tokens")))
	var next_tokens: int = min(max_tokens, current_tokens + 1)
	token_state.set("dash_tokens", next_tokens)
	if next_tokens >= max_tokens:
		token_state.set("dash_charge_timer", 0.0)


func _get_boss_rect(owner: Object) -> Rect2:
	if owner == null:
		return Rect2()
	var boss_pos: Vector2 = _as_vector2(owner.get("boss_pos"), Vector2.ZERO)
	var boss_size: Vector2 = _as_vector2(owner.get("boss_paddle_size"), Vector2.ZERO)
	if boss_size == Vector2.ZERO:
		var boss_width: float = max(1.0, float(owner.get("boss_paddle_width") if owner.get("boss_paddle_width") != null else 100.0))
		var boss_height: float = max(1.0, float(owner.get("boss_hitbox_height") if owner.get("boss_hitbox_height") != null else 40.0))
		boss_size = Vector2(boss_width, boss_height)
	return Rect2(boss_pos, boss_size)


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


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
