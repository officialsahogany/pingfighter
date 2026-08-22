extends RefCounted

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const GAUGE_COST := 120.0
const TRIGGER_CHANCE := 0.35
const PRECAST_SEC := 0.40
const DASH_SEC := 0.316
const EXPAND_SEC := 0.280
const SOLID_SEC := 3.0
const FADE_TO_SEMI_SEC := 2.0
const VISIBLE_SEC := 5.0
const FINAL_FADE_SEC := 3.0
const TOTAL_SEC := EXPAND_SEC + VISIBLE_SEC + FINAL_FADE_SEC
const SEMI_ALPHA := 100.0 / 255.0
const COOLDOWN_MIN_SEC := 10.0
const COOLDOWN_MAX_SEC := 20.0
# A deterministic midpoint preserves the existing 10-20 second recharge
# envelope without consuming the authoritative combat RNG during reset.
const INITIAL_COOLDOWN_SEC := (COOLDOWN_MIN_SEC + COOLDOWN_MAX_SEC) * 0.5
const INVULN_BUFFER_SEC := 0.180
const LOGICAL_SIZE := Vector2(235.0, 56.0)
const SPAWN_Y_OFFSET := 80.0
const INTANGIBLE_SOURCE := "stage7_cloud_dash"

var dash_active := false
var dash_phase := ""
var phase_elapsed_sec := 0.0
var origin_boss_pos := Vector2.ZERO
var target_boss_pos := Vector2.ZERO
var home_boss_pos := Vector2.ZERO
var boss_size := Vector2(100.0, 40.0)
var cooldown_remaining_sec := INITIAL_COOLDOWN_SEC
var cooldown_total_sec := INITIAL_COOLDOWN_SEC
var invuln_buffer_remaining_sec := 0.0
var field_active := false
var field_elapsed_sec := 0.0
var field_center := Vector2.ZERO
var draw_context: Dictionary = {}
var aura_draw_context: Dictionary = {}


func reset_full() -> void:
	clear_round_transients()
	cooldown_remaining_sec = INITIAL_COOLDOWN_SEC
	cooldown_total_sec = INITIAL_COOLDOWN_SEC


func clear_round_transients() -> void:
	dash_active = false
	dash_phase = ""
	phase_elapsed_sec = 0.0
	origin_boss_pos = Vector2.ZERO
	target_boss_pos = Vector2.ZERO
	home_boss_pos = Vector2.ZERO
	boss_size = Vector2(100.0, 40.0)
	invuln_buffer_remaining_sec = 0.0
	field_active = false
	field_elapsed_sec = 0.0
	field_center = Vector2.ZERO
	draw_context.clear()
	aura_draw_context.clear()


func has_runtime_state() -> bool:
	return (
		dash_active
		or cooldown_remaining_sec > 0.0
		or invuln_buffer_remaining_sec > 0.0
		or field_active
		or not draw_context.is_empty()
		or not aura_draw_context.is_empty()
	)


func set_cooldown_remaining(value: float, total: float = -1.0) -> void:
	cooldown_remaining_sec = maxf(0.0, value)
	cooldown_total_sec = maxf(
		0.001,
		total if total >= 0.0 else maxf(value, COOLDOWN_MIN_SEC)
	)


func tick_cooldown(delta: float) -> void:
	cooldown_remaining_sec = maxf(0.0, cooldown_remaining_sec - delta)


func get_snapshot() -> Dictionary:
	return {
		"trigger_chance": TRIGGER_CHANCE,
		"dash_active": dash_active,
		"phase": dash_phase,
		"phase_elapsed_sec": phase_elapsed_sec,
		"phase_progress": get_phase_progress(),
		"boss_pos": get_boss_pos() if dash_active else home_boss_pos,
		"origin_boss_pos": origin_boss_pos,
		"target_boss_pos": target_boss_pos,
		"home_boss_pos": home_boss_pos,
		"cooldown_remaining_sec": cooldown_remaining_sec,
		"cooldown_total_sec": cooldown_total_sec,
		"invuln_buffer_remaining_sec": invuln_buffer_remaining_sec,
		"field_active": field_active,
		"field_elapsed_sec": field_elapsed_sec,
		"field_center": field_center,
		"field_alpha": get_field_alpha(),
	}


func build_hud_skill(boss_gauge: float, skill_paused: bool, blocked_by_other_skill: bool) -> Dictionary:
	var active: bool = dash_active or field_active
	var cooldown_total: float = maxf(0.001, cooldown_total_sec)
	var ready: bool = (
		not skill_paused
		and cooldown_remaining_sec <= 0.0
		and boss_gauge >= GAUGE_COST
		and not active
		and not blocked_by_other_skill
	)
	var cloud_status := "charging"
	if active:
		cloud_status = "active"
	elif skill_paused:
		cloud_status = "paused"
	elif ready:
		cloud_status = "ready"
	var field_remaining: float = maxf(0.0, TOTAL_SEC - field_elapsed_sec) if field_active else 0.0
	return {
		"id": "stage7_cloud",
		"name": "구름장막",
		"color": Color(0.42, 0.66, 0.72),
		"cost": GAUGE_COST,
		"progress": clampf(1.0 - cooldown_remaining_sec / cooldown_total, 0.0, 1.0),
		"cooldown_remaining": cooldown_remaining_sec,
		"cooldown_total": cooldown_total,
		"cooldown_contract": "time",
		"initial_ready_allowed": false,
		"next_activation_remaining": maxf(
			cooldown_remaining_sec,
			maxf(field_remaining, maxf(0.0, GAUGE_COST - boss_gauge))
		),
		"ready": ready,
		"active": active,
		"implemented": true,
		"status": cloud_status,
		"phase": dash_phase if dash_active else ("field" if field_active else ""),
	}


func try_start(
	context: Dictionary,
	boss_gauge: float,
	force_roll: bool,
	free_cast: bool,
	bypass_cooldown: bool,
	blocked_by_other_skill: bool,
	rng: RandomNumberGenerator
) -> Dictionary:
	if (
		dash_active
		or field_active
		or blocked_by_other_skill
		or bool(context.get("lingpet_puppet_grab_active", false))
		or (not bypass_cooldown and cooldown_remaining_sec > 0.0)
		or (not free_cast and boss_gauge < GAUGE_COST)
	):
		return {}
	if not force_roll and rng.randf() > TRIGGER_CHANCE:
		return {}

	var boss_pos: Vector2 = _as_vector2(
		context.get("boss_pos", Vector2(330.0, 25.0)),
		Vector2(330.0, 25.0)
	)
	var context_boss_size: Vector2 = _as_vector2(
		context.get("boss_paddle_size", Vector2(
			float(context.get("boss_paddle_width", 100.0)),
			float(context.get("boss_hitbox_height", 40.0))
		)),
		Vector2(100.0, 40.0)
	)
	var player_pos: Vector2 = _as_vector2(
		context.get("player_pos", Vector2(302.5, 690.0)),
		Vector2(302.5, 690.0)
	)
	var player_size: Vector2 = _as_vector2(
		context.get("player_paddle_size", Vector2(155.0, 50.0)),
		Vector2(155.0, 50.0)
	)
	var player_rect := Rect2(player_pos, player_size)
	var field_width: float = float(context.get("width", FIELD_WIDTH))
	var field_height: float = float(context.get("height", FIELD_HEIGHT))
	var center_x: float = field_width * 0.5
	var origin_center_y: float = boss_pos.y + context_boss_size.y * 0.5
	var target_center_y: float = maxf(origin_center_y, player_rect.get_center().y - 40.0)
	target_center_y = minf(field_height - context_boss_size.y * 0.5, target_center_y)

	boss_size = context_boss_size
	origin_boss_pos = Vector2(center_x - boss_size.x * 0.5, boss_pos.y)
	home_boss_pos = origin_boss_pos
	target_boss_pos = Vector2(center_x - boss_size.x * 0.5, target_center_y - boss_size.y * 0.5)
	dash_active = true
	dash_phase = "pre"
	phase_elapsed_sec = 0.0
	invuln_buffer_remaining_sec = 0.0
	cooldown_total_sec = float(rng.randi_range(
		int(COOLDOWN_MIN_SEC * 1000.0),
		int(COOLDOWN_MAX_SEC * 1000.0)
	)) / 1000.0
	cooldown_remaining_sec = cooldown_total_sec
	draw_context.clear()
	_sync_precast_aura()
	return {
		"boss_gauge": boss_gauge if free_cast else maxf(0.0, boss_gauge - GAUGE_COST),
		"attack_target_x": center_x,
	}


func advance(delta: float, deps: Dictionary = {}) -> Dictionary:
	var events: Dictionary = {}
	_update_field(delta)
	if not dash_active:
		if invuln_buffer_remaining_sec > 0.0:
			invuln_buffer_remaining_sec = maxf(0.0, invuln_buffer_remaining_sec - delta)
			if invuln_buffer_remaining_sec <= 0.000001:
				invuln_buffer_remaining_sec = 0.0
				events["intangibility_expired"] = true
		return events

	phase_elapsed_sec += delta
	_sync_precast_aura()
	match dash_phase:
		"pre":
			if phase_elapsed_sec + 0.000001 >= PRECAST_SEC:
				dash_phase = "down"
				phase_elapsed_sec = 0.0
		"down":
			if phase_elapsed_sec + 0.000001 >= DASH_SEC:
				phase_elapsed_sec = 0.0
				dash_phase = "up"
				_start_field(deps)
		"up":
			if phase_elapsed_sec + 0.000001 >= DASH_SEC:
				phase_elapsed_sec = 0.0
				dash_active = false
				dash_phase = ""
				invuln_buffer_remaining_sec = INVULN_BUFFER_SEC
				aura_draw_context.clear()
				events["released"] = true
				events["release_pos"] = home_boss_pos
	return events


func cancel_for_superspeed() -> Dictionary:
	var result := {
		"interrupted_dash": dash_active,
		"release_pos": home_boss_pos,
	}
	dash_active = false
	dash_phase = ""
	phase_elapsed_sec = 0.0
	invuln_buffer_remaining_sec = 0.0
	field_active = false
	field_elapsed_sec = 0.0
	field_center = Vector2.ZERO
	draw_context.clear()
	aura_draw_context.clear()
	return result


func get_phase_progress() -> float:
	match dash_phase:
		"pre":
			return clampf(phase_elapsed_sec / PRECAST_SEC, 0.0, 1.0)
		"down", "up":
			return clampf(phase_elapsed_sec / DASH_SEC, 0.0, 1.0)
	return 0.0


func get_boss_pos() -> Vector2:
	match dash_phase:
		"pre":
			return origin_boss_pos
		"down":
			return origin_boss_pos.lerp(target_boss_pos, get_phase_progress())
		"up":
			return target_boss_pos.lerp(home_boss_pos, get_phase_progress())
	return home_boss_pos


func get_field_alpha() -> float:
	if not field_active:
		return 0.0
	var elapsed: float = field_elapsed_sec
	if elapsed <= SOLID_SEC:
		return 1.0
	if elapsed <= VISIBLE_SEC:
		return lerpf(1.0, SEMI_ALPHA, (elapsed - SOLID_SEC) / FADE_TO_SEMI_SEC)
	var final_fade_start: float = VISIBLE_SEC + EXPAND_SEC
	if elapsed <= final_fade_start:
		return SEMI_ALPHA
	return SEMI_ALPHA * clampf(
		1.0 - (elapsed - final_fade_start) / FINAL_FADE_SEC,
		0.0,
		1.0
	)


func _start_field(deps: Dictionary) -> void:
	field_active = true
	field_elapsed_sec = 0.0
	field_center = target_boss_pos + boss_size * 0.5 + Vector2(0.0, SPAWN_Y_OFFSET)
	_sync_draw_context()
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_stage7_akamu_cloud"):
		audio.play_stage7_akamu_cloud()


func _update_field(delta: float) -> void:
	if not field_active:
		return
	field_elapsed_sec += delta
	if field_elapsed_sec + 0.000001 >= TOTAL_SEC:
		field_active = false
		field_elapsed_sec = 0.0
		field_center = Vector2.ZERO
		draw_context.clear()
		return
	_sync_draw_context()


func _sync_draw_context() -> void:
	if not field_active:
		draw_context.clear()
		return
	draw_context = {
		"active": true,
		"center": field_center,
		"logical_size": LOGICAL_SIZE,
		"alpha": get_field_alpha(),
		"expand_progress": clampf(field_elapsed_sec / EXPAND_SEC, 0.0, 1.0),
		"elapsed_sec": field_elapsed_sec,
	}


func _sync_precast_aura() -> void:
	if not dash_active or not (dash_phase in ["pre", "down", "up"]):
		aura_draw_context.clear()
		return
	var progress: float = get_phase_progress()
	var pulse_sec: float = phase_elapsed_sec
	match dash_phase:
		"down":
			pulse_sec += PRECAST_SEC
		"up":
			pulse_sec += PRECAST_SEC + DASH_SEC
	aura_draw_context = {
		"active": true,
		"kind": "cloud_precast",
		"center": get_boss_pos() + boss_size * 0.5,
		"radius": 54.0 + 18.0 * progress,
		"alpha": 0.34 + 0.30 * progress,
		"progress": progress,
		"pulse_sec": pulse_sec,
	}


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
