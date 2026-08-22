extends RefCounted

const BossSkillParryGate := preload("res://scripts/stages/common/boss_skill_parry_gate.gd")

const STAGE_ID := 2
const QUAKE_INITIAL_COOLDOWN_SEC := 40.0
const QUAKE_REPEAT_COOLDOWN_SEC := 40.0
const QUAKE_DURATION_SEC := 80.0 / 60.0
const WATER_CANNON_AUTO_COOLDOWN_SEC := 30.0
const WATER_CANNON_AFTER_ROCK_SPAWN_GRACE_SEC := 7.0
# 2026-07-31 7점제 재보정: 물대포 해금 3/5(60%) -> 4/7(57%).
# 원본 파이썬의 `round_wins >= 3` 게이트와 같은 조건이다 — Godot의
# `player_score`가 곧 랠리 승수 카운터라 별도 상수를 두지 않는다.
# (구 `WATER_CANNON_UNLOCK_ROUND_WINS := 3`은 소비자 0인 죽은 중복 계약이라
#  제거했다. 같은 개념을 두 상수로 두면 룰 개편 때 한쪽만 갱신된다.)
const WATER_CANNON_UNLOCK_PLAYER_SCORE := 4
# 고압 티어(격노 다음으로 높은 압박)는 5점제에서 player_score 5 = 듀스에서만
# 도달 가능한 특수 상태였다. 7점제에서 5를 그대로 두면 5·6점이 평범한 중후반이라
# 최고 압박이 상시화된다 -> WIN_GOAL과 같은 7로 올려 "듀스 전용"을 유지한다.
const HIGH_PRESSURE_PLAYER_SCORE := 7
const BOSS_GAUGE_MAX := 500.0
const BOSS_GAUGE_GAIN_ON_HIT := 60.0
const BOSS_GAUGE_ROUND_CARRY_RATIO := 0.80
const SPEED_DEFENSE_DURATION_SEC := 3.5
const SPEED_DEFENSE_INTERVAL_SEC := 25.0
const SPEED_DEFENSE_SERVE_GRACE_SEC := 3.0
const SPEED_DEFENSE_SPEED_MULTIPLIER := 1.7
const SPEED_DEFENSE_TURN_MULTIPLIER := 2.0
const SPEED_DEFENSE_INITIAL_SPEED_RATIO := 0.20
const SPEED_DEFENSE_TRAIL_FADE_PER_SEC := 4.8
const SPEED_DEFENSE_MAX_TRAILS := 10

var quake_cooldown := QUAKE_INITIAL_COOLDOWN_SEC
var quake_charge_total := QUAKE_INITIAL_COOLDOWN_SEC
var boss_special_gauge := 0.0
var boss_launch_guard_pending := false
var water_cannon_delay := WATER_CANNON_AUTO_COOLDOWN_SEC
var water_cannon_delay_total := WATER_CANNON_AUTO_COOLDOWN_SEC
var status := "charging"
var rng := RandomNumberGenerator.new()
var speed_defense_active := false
var speed_defense_timer := 0.0
var speed_defense_since_activation := 0.0
var speed_defense_serve_grace_timer := 0.0
var speed_defense_target_x := 0.0
var speed_defense_trails: Array = []
var was_waiting_for_serve := true


func _init() -> void:
	rng.seed = 2203


func reset() -> void:
	quake_cooldown = QUAKE_INITIAL_COOLDOWN_SEC
	quake_charge_total = QUAKE_INITIAL_COOLDOWN_SEC
	boss_special_gauge = 0.0
	boss_launch_guard_pending = false
	water_cannon_delay = WATER_CANNON_AUTO_COOLDOWN_SEC
	water_cannon_delay_total = WATER_CANNON_AUTO_COOLDOWN_SEC
	status = "charging"
	_reset_speed_defense(true)


func reset_round() -> void:
	boss_special_gauge = 0.0
	boss_launch_guard_pending = false
	water_cannon_delay_total = WATER_CANNON_AUTO_COOLDOWN_SEC
	status = _get_idle_status()
	_reset_speed_defense(false)


func update(delta: float, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	if int(context.get("current_stage", STAGE_ID)) != STAGE_ID:
		reset()
		return {}

	var stage_background: Object = deps.get("stage_background", null)
	if stage_background == null:
		status = "missing_background"
		return {}

	var clamped_delta: float = max(0.0, delta)
	_update_speed_defense_timers(clamped_delta, context)
	if not bool(context.get("ball_active", false)) or bool(context.get("waiting_for_serve", false)):
		was_waiting_for_serve = true
		status = "paused"
		return {}
	if was_waiting_for_serve:
		speed_defense_serve_grace_timer = SPEED_DEFENSE_SERVE_GRACE_SEC
		was_waiting_for_serve = false

	if _is_boss_skill_cooldown_paused(context):
		status = _get_cooldown_paused_status(stage_background)
		return {}

	_update_skill_cooldowns(clamped_delta)
	if _is_quake_active(stage_background):
		status = "quake"
		return {}
	if _is_water_cannon_active(stage_background):
		status = "water_cannon"
		return {}
	if _is_boss_rage_active(stage_background):
		status = "boss_rage"
		return {}
	if _update_quake_schedule(context, deps, stage_background):
		return {}
	if _update_water_cannon_schedule(context, deps, stage_background):
		return {}
	_update_speed_defense_activation(context, deps, stage_background)
	if speed_defense_active:
		status = "speed_defense"
	else:
		status = _get_idle_status(context)
	return {}


func get_boss_ai_context(stage_background: Object = null) -> Dictionary:
	var locked := false
	var phase := "idle"
	if stage_background != null:
		if stage_background.has_method("is_boss_movement_locked"):
			locked = bool(stage_background.is_boss_movement_locked())
		if stage_background.has_method("get_water_cannon_phase"):
			phase = str(stage_background.get_water_cannon_phase())
	return {
		"stage2_boss_movement_locked": locked,
		"stage2_water_cannon_phase": phase,
		"stage2_boss_skill_status": status,
		"stage2_speed_defense_active": speed_defense_active,
		"stage2_speed_defense_status_immunity_active": is_boss_status_immune(),
		"stage2_speed_defense_speed_multiplier": SPEED_DEFENSE_SPEED_MULTIPLIER if speed_defense_active else 1.0,
		"stage2_speed_defense_turn_multiplier": SPEED_DEFENSE_TURN_MULTIPLIER if speed_defense_active else 1.0,
		"stage2_speed_defense_initial_speed_ratio": SPEED_DEFENSE_INITIAL_SPEED_RATIO if speed_defense_active else 0.0,
	}


func register_boss_hit(_ball_vel: Vector2, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	if int(context.get("current_stage", STAGE_ID)) != STAGE_ID:
		return {}
	var stage_background: Object = _resolve_stage_background(deps)
	var water_cannon_interrupted := false
	if stage_background != null and stage_background.has_method("interrupt_water_cannon_charge_on_boss_hit"):
		water_cannon_interrupted = bool(stage_background.interrupt_water_cannon_charge_on_boss_hit())
	if water_cannon_interrupted:
		status = _get_idle_status(context)
	if speed_defense_active:
		_play_speed_defense_boss_hit_audio(deps)
	boss_launch_guard_pending = true
	return {
		"boss_special_gauge": boss_special_gauge,
		"stage2_boss_gauge_gain": 0.0,
		"stage2_quake_cast": false,
		"stage2_water_cannon_interrupted": water_cannon_interrupted,
	}


func get_hud_context(stage_background: Object = null, context: Dictionary = {}) -> Dictionary:
	var water_phase := _get_water_cannon_phase(stage_background)
	var quake_active := _is_quake_active(stage_background)
	var rage_active := _is_boss_rage_active(stage_background)
	var water_unlocked := _is_water_cannon_hud_unlocked(stage_background, context)
	return {
		"stage2_boss_skill_hud_active": true,
		"stage2_boss_skill_hud_boss_name": "청린귀",
		"stage2_boss_skill_hud_speech": _get_hud_speech(water_phase, quake_active, water_unlocked, rage_active),
		"stage2_boss_skill_hud_status": status,
		"stage2_boss_skill_hud_boss_gauge": boss_special_gauge,
		"stage2_boss_skill_hud_boss_gauge_max": BOSS_GAUGE_MAX,
		"stage2_boss_skill_hud_boss_gauge_progress": get_boss_gauge_progress(),
		"stage2_boss_skill_hud_skills": [
			_get_quake_hud_skill(quake_active, context),
			_get_water_cannon_hud_skill(water_phase, water_unlocked),
			_get_speed_defense_hud_skill(),
		],
	}


func get_pressure_snapshot(context: Dictionary = {}) -> Dictionary:
	var rock_range: Vector2i = _get_quake_rock_count_range(context)
	var water_range: Vector2 = _get_water_cannon_delay_range(context)
	return {
		"level": _get_pressure_level(context),
		"quake_repeat_cooldown": _get_quake_repeat_cooldown(context),
		"boss_gauge": boss_special_gauge,
		"boss_gauge_max": BOSS_GAUGE_MAX,
		"boss_gauge_progress": get_boss_gauge_progress(),
		"boss_gauge_gain_on_hit": _get_boss_gauge_gain_on_hit(context),
		"quake_cooldown_total": quake_charge_total,
		"water_delay_min": water_range.x,
		"water_delay_max": water_range.y,
		"rock_count": rock_range.y,
		"rock_count_min": rock_range.x,
		"rock_count_max": rock_range.y,
	}


func get_actor_draw_context() -> Dictionary:
	return {
		"stage2_speed_defense_active": speed_defense_active,
		"stage2_speed_defense_status_immunity_active": is_boss_status_immune(),
		"stage2_speed_defense_progress": _get_speed_defense_progress(),
		"stage2_speed_defense_trails": speed_defense_trails.duplicate(true),
	}


func get_status() -> String:
	return status


func is_speed_defense_active() -> bool:
	return speed_defense_active


func is_boss_status_immune() -> bool:
	return speed_defense_active


func get_quake_cooldown() -> float:
	return quake_cooldown


func get_boss_special_gauge() -> float:
	return boss_special_gauge


func get_boss_gauge_max() -> float:
	return BOSS_GAUGE_MAX


func get_boss_gauge_progress() -> float:
	return clamp(boss_special_gauge / BOSS_GAUGE_MAX, 0.0, 1.0)


func get_water_cannon_delay() -> float:
	return water_cannon_delay


func get_water_cannon_delay_total() -> float:
	return water_cannon_delay_total


func defer_water_cannon_after_rock_spawn(delay_sec: float = WATER_CANNON_AFTER_ROCK_SPAWN_GRACE_SEC) -> void:
	var delay: float = max(0.0, delay_sec)
	if delay <= 0.0:
		return
	var previous_delay: float = water_cannon_delay
	water_cannon_delay = max(water_cannon_delay, delay)
	if water_cannon_delay > previous_delay + 0.001:
		water_cannon_delay_total = max(0.1, water_cannon_delay)
	if status == "water_pending":
		status = _get_idle_status()


func _reset_speed_defense(reset_interval: bool) -> void:
	speed_defense_active = false
	speed_defense_timer = 0.0
	if reset_interval:
		speed_defense_since_activation = 0.0
	speed_defense_serve_grace_timer = SPEED_DEFENSE_SERVE_GRACE_SEC
	speed_defense_target_x = 0.0
	speed_defense_trails.clear()
	was_waiting_for_serve = true


func _update_skill_cooldowns(delta: float) -> void:
	quake_cooldown = max(0.0, quake_cooldown - delta)
	water_cannon_delay = max(0.0, water_cannon_delay - delta)
	speed_defense_since_activation = min(SPEED_DEFENSE_INTERVAL_SEC, speed_defense_since_activation + delta)


func _is_boss_skill_cooldown_paused(context: Dictionary) -> bool:
	return bool(context.get(
		"active_item_boss_skill_cooldown_paused",
		context.get("active_item_tear_gas_cooldown_pause_active", false)
	))


func _get_cooldown_paused_status(stage_background: Object) -> String:
	if speed_defense_active:
		return "speed_defense"
	if _is_quake_active(stage_background):
		return "quake"
	if _is_water_cannon_active(stage_background):
		return "water_cannon"
	if _is_boss_rage_active(stage_background):
		return "boss_rage"
	return "paused"


func _update_speed_defense_timers(delta: float, context: Dictionary) -> void:
	if not bool(context.get("waiting_for_serve", false)):
		speed_defense_serve_grace_timer = max(0.0, speed_defense_serve_grace_timer - delta)
	if speed_defense_active:
		speed_defense_timer = max(0.0, speed_defense_timer - delta)
		if speed_defense_timer <= 0.0:
			speed_defense_active = false
	_update_speed_defense_trails(delta, context)


func _update_speed_defense_trails(delta: float, context: Dictionary) -> void:
	for idx in range(speed_defense_trails.size() - 1, -1, -1):
		var trail: Dictionary = speed_defense_trails[idx]
		trail["alpha"] = max(0.0, float(trail.get("alpha", 0.0)) - SPEED_DEFENSE_TRAIL_FADE_PER_SEC * delta)
		if float(trail.get("alpha", 0.0)) <= 0.0:
			speed_defense_trails.remove_at(idx)
		else:
			speed_defense_trails[idx] = trail
	if speed_defense_active:
		_append_speed_defense_trail(context)


func _append_speed_defense_trail(context: Dictionary) -> void:
	var boss_pos: Vector2 = _get_vector2(context.get("boss_pos", Vector2.ZERO), Vector2.ZERO)
	var boss_width: float = float(context.get("boss_paddle_width", 100.0))
	var boss_hitbox_height: float = float(context.get("boss_hitbox_height", 40.0))
	speed_defense_trails.push_front({
		"center": boss_pos + Vector2(boss_width * 0.5, boss_hitbox_height * 0.5 + 31.0),
		"alpha": 0.70,
	})
	if speed_defense_trails.size() > SPEED_DEFENSE_MAX_TRAILS:
		speed_defense_trails.resize(SPEED_DEFENSE_MAX_TRAILS)


func _update_speed_defense_activation(context: Dictionary, deps: Dictionary, stage_background: Object) -> void:
	if speed_defense_active:
		return
	if speed_defense_serve_grace_timer > 0.0:
		return
	if speed_defense_since_activation < SPEED_DEFENSE_INTERVAL_SEC:
		return
	if _is_quake_active(stage_background) or _is_water_cannon_active(stage_background) or _is_boss_rage_active(stage_background):
		return
	if not bool(context.get("ball_active", false)) or bool(context.get("waiting_for_serve", false)):
		return
	var boss_pos: Vector2 = _get_vector2(context.get("boss_pos", Vector2.ZERO), Vector2.ZERO)
	var boss_width: float = float(context.get("boss_paddle_width", 100.0))
	var predicted_x: float = boss_pos.x + boss_width * 0.5
	_activate_speed_defense(predicted_x, deps, context)


func _activate_speed_defense(predicted_x: float, deps: Dictionary, context: Dictionary) -> void:
	speed_defense_active = true
	speed_defense_timer = SPEED_DEFENSE_DURATION_SEC
	speed_defense_since_activation = 0.0
	speed_defense_target_x = predicted_x
	_append_speed_defense_trail(context)
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_stage2_speed_defense_start"):
		audio.play_stage2_speed_defense_start()


func _play_speed_defense_boss_hit_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio == null:
		return
	if audio.has_method("play_stage2_speed_defense_hit"):
		audio.play_stage2_speed_defense_hit()


func _get_speed_defense_progress() -> float:
	if not speed_defense_active:
		return 0.0
	return clamp(speed_defense_timer / max(0.001, SPEED_DEFENSE_DURATION_SEC), 0.0, 1.0)


func _update_quake_schedule(context: Dictionary, deps: Dictionary, stage_background: Object) -> bool:
	if quake_cooldown > 0.0:
		return false
	if _is_stage_background_casting_busy(stage_background):
		status = "ready"
		return false
	if _activate_quake_from_cooldown(context, deps, stage_background):
		return true
	status = "ready"
	return false


func _update_water_cannon_schedule(
	context: Dictionary,
	deps: Dictionary,
	stage_background: Object
) -> bool:
	if not _is_water_cannon_unlocked(context):
		return false
	if water_cannon_delay > 0.0:
		return false
	if _is_stage_background_casting_busy(stage_background):
		status = "water_pending"
		return false
	if not _has_rocks(stage_background):
		status = "water_pending"
		return false
	status = "water_pending"
	if stage_background.has_method("activate_water_cannon"):
		if BossSkillParryGate.try_parry("water_cannon", "천수포", context, deps):
			status = "charging"
			water_cannon_delay = WATER_CANNON_AUTO_COOLDOWN_SEC
			water_cannon_delay_total = WATER_CANNON_AUTO_COOLDOWN_SEC
			return true
		if bool(stage_background.activate_water_cannon(context, deps)):
			status = "water_cannon"
			water_cannon_delay = WATER_CANNON_AUTO_COOLDOWN_SEC
			water_cannon_delay_total = WATER_CANNON_AUTO_COOLDOWN_SEC
			return true
	return false


func _get_quake_hud_skill(quake_active: bool, _context: Dictionary) -> Dictionary:
	var cooldown_total: float = max(0.1, quake_charge_total)
	var remaining: float = max(0.0, quake_cooldown)
	var skill_status := "casting" if quake_active else ("ready" if remaining <= 0.0 else "charging")
	var progress := 1.0 if quake_active else _cooldown_progress(remaining, cooldown_total)
	return {
		"id": "jungle_quake",
		"label": "지맥진동",
		"status": skill_status,
		"cooldown_remaining": remaining,
		"cooldown_total": cooldown_total,
		"progress": progress,
		"ready": skill_status == "ready",
		"cooldown_contract": "time",
		"initial_ready_allowed": false,
		"trigger_type": "auto",
		"gauge": boss_special_gauge,
		"gauge_max": BOSS_GAUGE_MAX,
		"color": Color(0.42, 0.92, 0.48, 1.0),
	}


func _get_water_cannon_hud_skill(water_phase: String, water_unlocked: bool) -> Dictionary:
	var remaining: float = max(0.0, water_cannon_delay)
	var total: float = max(0.1, WATER_CANNON_AUTO_COOLDOWN_SEC)
	var skill_status := "ready" if remaining <= 0.0 else "charging"
	var progress := _cooldown_progress(remaining, total)
	if water_phase in ["charging", "firing"]:
		skill_status = "casting"
		progress = 1.0
	elif not water_unlocked:
		skill_status = "locked"
		progress = 0.0
	elif status == "water_pending":
		skill_status = "ready"
		progress = 1.0
	return {
		"id": "water_cannon",
		"label": "용소격류",
		"status": skill_status,
		"cooldown_remaining": remaining,
		"cooldown_total": total,
		"progress": progress,
		"ready": skill_status == "ready",
		"cooldown_contract": "time",
		"initial_ready_allowed": false,
		"trigger_type": "auto",
		"color": Color(0.35, 0.78, 1.0, 1.0),
	}


func _get_speed_defense_hud_skill() -> Dictionary:
	var remaining: float = max(0.0, SPEED_DEFENSE_INTERVAL_SEC - speed_defense_since_activation)
	var skill_status := "waiting"
	var progress: float = _cooldown_progress(remaining, SPEED_DEFENSE_INTERVAL_SEC)
	var cooldown_remaining := remaining
	var cooldown_total := SPEED_DEFENSE_INTERVAL_SEC
	if speed_defense_active:
		skill_status = "casting"
		progress = 1.0
		cooldown_remaining = 0.0
		cooldown_total = SPEED_DEFENSE_INTERVAL_SEC
	elif speed_defense_serve_grace_timer > 0.0:
		skill_status = "locked"
		cooldown_remaining = speed_defense_serve_grace_timer
		cooldown_total = SPEED_DEFENSE_SERVE_GRACE_SEC
		progress = _cooldown_progress(cooldown_remaining, cooldown_total)
	elif remaining > 0.0:
		skill_status = "charging"
	else:
		skill_status = "ready"
		progress = 1.0
	return {
		"id": "speed_defense",
		"label": "용린호체",
		"status": skill_status,
		"cooldown_remaining": cooldown_remaining,
		"cooldown_total": cooldown_total,
		"progress": progress,
		"ready": skill_status == "ready",
		"cooldown_contract": "time",
		"initial_ready_allowed": false,
		"trigger_type": "auto",
		"color": Color(0.25, 0.82, 1.0, 1.0),
	}


func _cooldown_progress(remaining: float, total: float) -> float:
	if total <= 0.0:
		return 1.0
	return clamp(1.0 - max(0.0, remaining) / total, 0.0, 1.0)


func _get_boss_gauge_gain_on_hit(_context: Dictionary) -> float:
	return 0.0


func _get_hud_speech(water_phase: String, quake_active: bool, water_unlocked: bool, rage_active: bool = false) -> String:
	if speed_defense_active:
		return "용린호체!"
	if rage_active:
		return "분노 발구르기!"
	if water_phase == "charging":
		return "용소격류 충전!"
	if water_phase == "firing":
		return "용소격류 발사!"
	if quake_active:
		return "지맥진동!"
	if water_unlocked and water_cannon_delay <= 0.0:
		return "용소격류 준비!"
	if quake_cooldown <= 0.0:
		return "지맥진동 준비!"
	if speed_defense_since_activation >= SPEED_DEFENSE_INTERVAL_SEC:
		return "용린호체 준비!"
	if water_unlocked and water_cannon_delay > 0.0:
		return "용소격류 조준 중"
	return "용소의 지맥을 흔든다"


func _get_water_cannon_phase(stage_background: Object) -> String:
	if stage_background != null and stage_background.has_method("get_water_cannon_phase"):
		return str(stage_background.get_water_cannon_phase())
	return "idle"


func _is_quake_active(stage_background: Object) -> bool:
	if stage_background != null and stage_background.has_method("is_quake_active"):
		return bool(stage_background.is_quake_active())
	return false


func _is_boss_rage_active(stage_background: Object) -> bool:
	if stage_background != null and stage_background.has_method("is_boss_rage_active"):
		return bool(stage_background.is_boss_rage_active())
	return false


func _is_water_cannon_hud_unlocked(stage_background: Object, context: Dictionary) -> bool:
	return _is_water_cannon_active(stage_background) or _is_water_cannon_unlocked(context)


func _is_stage_background_casting_busy(stage_background: Object) -> bool:
	if stage_background == null:
		return false
	if _is_water_cannon_active(stage_background):
		return true
	if _is_boss_rage_active(stage_background):
		return true
	if stage_background.has_method("is_quake_active") and bool(stage_background.is_quake_active()):
		return true
	return false


func _is_water_cannon_active(stage_background: Object) -> bool:
	if stage_background == null or not stage_background.has_method("get_water_cannon_phase"):
		return false
	return str(stage_background.get_water_cannon_phase()) in ["charging", "firing"]


func _has_rocks(stage_background: Object) -> bool:
	if stage_background == null or not stage_background.has_method("get_rock_count"):
		return false
	return int(stage_background.get_rock_count()) > 0


func _is_water_cannon_unlocked(context: Dictionary) -> bool:
	return (
		bool(context.get("enraged_boss_active", false))
		or int(context.get("player_score", 0)) >= WATER_CANNON_UNLOCK_PLAYER_SCORE
	)


func _roll_water_cannon_delay(_context: Dictionary) -> float:
	return WATER_CANNON_AUTO_COOLDOWN_SEC


func _activate_quake_from_cooldown(context: Dictionary, deps: Dictionary, stage_background: Object) -> bool:
	if bool(context.get("waiting_for_serve", false)):
		return false
	if quake_cooldown > 0.0:
		return false
	if stage_background == null or not stage_background.has_method("activate_quake"):
		return false
	if BossSkillParryGate.try_parry("jungle_quake", "지맥진동", context, deps):
		boss_special_gauge = 0.0
		boss_launch_guard_pending = false
		quake_charge_total = QUAKE_REPEAT_COOLDOWN_SEC
		quake_cooldown = quake_charge_total
		defer_water_cannon_after_rock_spawn()
		status = "charging"
		return true
	var rock_count: int = _roll_quake_rock_count(context)
	if not bool(stage_background.activate_quake(
		QUAKE_DURATION_SEC,
		rock_count,
		false,
		boss_launch_guard_pending,
		deps
	)):
		return false
	boss_special_gauge = 0.0
	boss_launch_guard_pending = false
	quake_charge_total = QUAKE_REPEAT_COOLDOWN_SEC
	quake_cooldown = quake_charge_total
	defer_water_cannon_after_rock_spawn()
	status = "quake"
	return true


func _resolve_stage_background(deps: Dictionary) -> Object:
	var stage_background: Object = deps.get("stage_background", null)
	if stage_background != null and stage_background.has_method("activate_quake"):
		return stage_background
	stage_background = deps.get("stage2_pillar_background", null)
	if stage_background != null and stage_background.has_method("activate_quake"):
		return stage_background
	return null


func _get_quake_repeat_cooldown(_context: Dictionary) -> float:
	return QUAKE_REPEAT_COOLDOWN_SEC


func _get_water_cannon_delay_range(_context: Dictionary) -> Vector2:
	return Vector2(WATER_CANNON_AUTO_COOLDOWN_SEC, WATER_CANNON_AUTO_COOLDOWN_SEC)


func _get_idle_status(context: Dictionary = {}) -> String:
	if quake_cooldown <= 0.0:
		return "ready"
	if _is_water_cannon_unlocked(context) and water_cannon_delay <= 0.0:
		return "water_pending"
	if speed_defense_since_activation >= SPEED_DEFENSE_INTERVAL_SEC and speed_defense_serve_grace_timer <= 0.0:
		return "speed_ready"
	return "charging"


func _get_pressure_level(context: Dictionary) -> int:
	if bool(context.get("enraged_boss_active", false)):
		return 3
	var player_score: int = int(context.get("player_score", 0))
	var ai_mode: String = str(context.get("ai_mode", "champion"))
	if player_score >= HIGH_PRESSURE_PLAYER_SCORE:
		return 2
	if player_score >= WATER_CANNON_UNLOCK_PLAYER_SCORE:
		return 1
	if ai_mode == "mythic":
		return 1
	return 0


func _get_quake_rock_count(context: Dictionary) -> int:
	var rock_range: Vector2i = _get_quake_rock_count_range(context)
	return rock_range.y


func _roll_quake_rock_count(context: Dictionary) -> int:
	var rock_range: Vector2i = _get_quake_rock_count_range(context)
	return rng.randi_range(rock_range.x, rock_range.y)


func _get_quake_rock_count_range(context: Dictionary) -> Vector2i:
	match str(context.get("ai_mode", "champion")):
		"mythic":
			return Vector2i(4, 8) if bool(context.get("enraged_boss_active", false)) else Vector2i(2, 4)
		"champion", "limit":
			return Vector2i(2, 4)
		_:
			return Vector2i(1, 2)


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
