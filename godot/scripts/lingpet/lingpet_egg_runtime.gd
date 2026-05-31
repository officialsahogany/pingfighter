extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const MARIBO_EGG_TEXTURE := preload("res://assets/sprites/lingpet/maribo_egg_v002.png")
const MARIBO_EGG_TEXTURE_CRACK_1 := preload("res://assets/sprites/lingpet/maribo_egg_v002_crack1.png")
const MARIBO_EGG_TEXTURE_CRACK_2 := preload("res://assets/sprites/lingpet/maribo_egg_v002_crack2.png")
# AutoSprite back-view walk sheet (player-side view). Runtime-ready 640x640 PNG,
# 5 cols x 5 rows = 25 frames, 128px cells. Source provenance:
# godot/lingpet/maribo/maribo_walk_back_autosprite_v001.png (256px native cells).
# Idle is DERIVED from this sheet (no separate idle asset): the patrol-paused
# state holds COMPANION_IDLE_FRAME and the breathing bob is code-driven.
const MARIBO_COMPANION_WALK_SHEET := preload("res://assets/sprites/lingpet/maribo_companion_walk.png")

const PET_ID := "maribo"
const STATE_NONE := "none"
const STATE_EGG := "egg"
const STATE_COMPANION := "companion"
const REQUIRED_HITS := 2
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const EGG_RADIUS := 28.0
const EGG_TEXTURE_DRAW_SIZE := Vector2(88.0, 88.0)
const EGG_TEXTURE_TOP_OFFSET_RATIO := 0.48
const EGG_FLOOR_MARGIN := 18.0
const EGG_PLAYER_NUDGE_RADIUS := 40.0
const EGG_PLAYER_NUDGE_STRENGTH := 0.32
const EGG_PLAYER_NUDGE_MAX_VX := 0.75
const EGG_PLAYER_NUDGE_MAX_STEP := 0.45
const EGG_PLAYER_NUDGE_DAMPING := 0.62
const EGG_PLAYER_WOBBLE_DAMPING := 0.72
const EGG_PLAYER_WOBBLE_SPRING := 0.35
const EGG_PLAYER_WOBBLE_MAX_DEGREES := 8.0
const EGG_PLAYER_WOBBLE_VISUAL_PIXELS := 1.6
const BALL_RADIUS_FALLBACK := 14.3
const HIT_COOLDOWN_SECONDS := 0.20
const EGG_PADDLE_BOUNCE_DEFAULT_MAX_ANGLE := 60.0
const EGG_PADDLE_BOUNCE_DEFAULT_MIN_SPEED := 3.0
const EGG_PADDLE_BOUNCE_DEFAULT_MAX_SPEED := 20.0
const HATCH_FLASH_SECONDS := 0.50
const EGG_CRACK_LIGHT_MAIN_WIDTH := 2.1
const EGG_CRACK_LIGHT_GLOW_WIDTH := 6.0
const HATCH_BREAK_SHARD_COUNT := 9
const HATCH_BREAK_SHARD_DISTANCE := 44.0
const HATCH_BREAK_SHARD_GRAVITY := 20.0
const SAVE_SNAPSHOT_VERSION := 1
const MARIBO_GAUGE_GAIN_BONUS_PCT := 10.0
const MARIBO_GAUGE_GAIN_MULTIPLIER := 1.0 + MARIBO_GAUGE_GAIN_BONUS_PCT / 100.0
const COMPANION_RADIUS := 16.0
# Walk-sheet grid + playback. Sheet geometry MUST match the asset (5x5, 25
# frames, square cells). draw_texture_rect_region reads cell size from the
# texture at runtime, so only the column/row/frame counts are hardcoded here.
const COMPANION_SHEET_COLS := 5
const COMPANION_SHEET_ROWS := 5
const COMPANION_SHEET_FRAME_COUNT := 25
const COMPANION_IDLE_FRAME := 12
const COMPANION_WALK_FPS := 14.0
const COMPANION_SPRITE_DRAW_SIZE := Vector2(82.0, 82.0)
const COMPANION_SPRITE_Y_OFFSET := -6.0
const COMPANION_PATROL_SPEED := 120.0
const COMPANION_PATROL_SPEED_MIN := 70.0
const COMPANION_PATROL_SPEED_MAX := 135.0
const COMPANION_PATROL_EDGE_MARGIN := 42.0
const COMPANION_PATROL_LANE_Y_OFFSET := 0.5
const COMPANION_PATROL_PAUSE_MIN := 0.4
const COMPANION_PATROL_PAUSE_MAX := 1.2
const COMPANION_PATROL_CHANGE_INTERVAL_MIN := 0.45
const COMPANION_PATROL_CHANGE_INTERVAL_MAX := 1.40
const COMPANION_PATROL_SURPRISE_CHANCE_PER_SECOND := 0.30
const COMPANION_PATROL_SEED_MOD := 2147483647
const COMPANION_COLLISION_RADIUS := 22.0
const COMPANION_HIT_COOLDOWN_SECONDS := 0.42
const COMPANION_HIT_FLASH_SECONDS := 0.28
const COMPANION_BOUNCE_SPEED_MULTIPLIER := 0.96
const COMPANION_SKILL_ID := "maribo_resonance"
const COMPANION_SKILL_NAME := "공명 충전"
const COMPANION_SKILL_COOLDOWN_SECONDS := 6.0
const COMPANION_SKILL_FLASH_SECONDS := 0.45
const COMPANION_SKILL_GAUGE_GAIN := 40.0
const COMPANION_SKILL_BURST_PARTICLES := 8
const COMPANION_CARD_READY_SPARK_COUNT := 4
# Fullscreen acquisition cut-in (original outsourced artwork reveal) shown once
# when the egg hatches into the companion. It PAUSES gameplay: while active it is
# registered as a battle modal (battle_scene_modal_gate_controller), so the whole
# update driver is gated -- the ball freezes in place WITHOUT zeroing ball_vel,
# so play resumes cleanly on dismiss (no freeze-actor snapshot trap). The reveal
# animation plays over ACQUIRE_CUTIN_REVEAL_SECONDS and then HOLDS, waiting for a
# click/confirm to dismiss and resume. The clock is advanced from the ungated
# idle pump (process_idle -> advance_acquire_cutin), NOT from the gated update(),
# otherwise it would deadlock. Art + draw live in
# scripts/hud/lingpet_acquire_cutin_overlay_host.gd.
const ACQUIRE_CUTIN_REVEAL_SECONDS := 1.4

var _state := STATE_NONE
var _pet_id := PET_ID
var _hatch_hits := 0
var _egg_pos := Vector2.ZERO
var _egg_nudge_vx := 0.0
var _egg_wobble_angle := 0.0
var _egg_wobble_vel := 0.0
var _companion_pos := Vector2.ZERO
var _companion_patrol_dir := 0.0
var _companion_patrol_pause := 0.0
var _companion_patrol_change_timer := 0.0
var _companion_patrol_seed := 0
var _companion_patrol_speed := 0.0
var _companion_patrol_lane_y := 0.0
var _companion_patrol_min_x := 0.0
var _companion_patrol_max_x := 0.0
var _companion_last_contact_pos := Vector2.ZERO
var _companion_skill_origin := Vector2.ZERO
var _companion_contact_count := 0
var _owned_pet_ids: Array[String] = []
var _ball_was_inside := false
var _companion_ball_was_inside := false
var _hit_cooldown := 0.0
var _companion_hit_cooldown := 0.0
var _companion_skill_cooldown := 0.0
var _hatch_flash_timer := 0.0
var _companion_hit_flash_timer := 0.0
var _companion_skill_flash_timer := 0.0
var _companion_skill_trigger_count := 0
var _companion_skill_last_gain := 0.0
var _acquire_cutin_active := false
var _acquire_cutin_elapsed := 0.0
var _has_synced_none := false


func update(delta: float, owner: Object, registry: Object = null) -> bool:
	if owner == null:
		return false
	_hit_cooldown = maxf(0.0, _hit_cooldown - maxf(0.0, delta))
	_companion_hit_cooldown = maxf(0.0, _companion_hit_cooldown - maxf(0.0, delta))
	_companion_skill_cooldown = maxf(0.0, _companion_skill_cooldown - maxf(0.0, delta))
	_hatch_flash_timer = maxf(0.0, _hatch_flash_timer - maxf(0.0, delta))
	_companion_hit_flash_timer = maxf(0.0, _companion_hit_flash_timer - maxf(0.0, delta))
	_companion_skill_flash_timer = maxf(0.0, _companion_skill_flash_timer - maxf(0.0, delta))

	if _state == STATE_NONE:
		if _is_maribo_owned(owner):
			_adopt_owned_maribo(owner)
			return true
		if _should_spawn_first_maribo_egg(owner):
			_spawn_egg(owner)
			return true
		if not _has_synced_none:
			_sync_owner(owner)
			_has_synced_none = true
			return false
		return false

	if _state == STATE_EGG:
		_update_egg_player_contact(delta, owner)
		var changed: bool = _resolve_ball_hit(owner)
		_sync_owner(owner)
		return changed

	if _state == STATE_COMPANION:
		_update_companion_motion(delta, owner)
		_resolve_companion_ball_hit(owner, registry)
		_sync_owner(owner)
	return false


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO, _draw_context: Dictionary = {}) -> void:
	if canvas == null:
		return
	if _state == STATE_EGG:
		_draw_egg(canvas, _egg_pos + shake_offset)
	elif _state == STATE_COMPANION:
		_draw_companion(canvas, _companion_pos + shake_offset)
		if _hatch_flash_timer > 0.0:
			_draw_hatch_flash(canvas, _egg_pos + shake_offset)


func has_visible_effects() -> bool:
	return _state == STATE_EGG or _state == STATE_COMPANION or _hatch_flash_timer > 0.0 or _acquire_cutin_active


func is_acquire_cutin_active() -> bool:
	return _acquire_cutin_active


# Advanced from the ungated idle pump (process_idle), so the reveal keeps
# animating while the gated update driver is paused by the modal gate.
func advance_acquire_cutin(delta: float) -> void:
	if not _acquire_cutin_active:
		return
	_acquire_cutin_elapsed += maxf(0.0, delta)


func get_acquire_cutin_progress() -> float:
	if ACQUIRE_CUTIN_REVEAL_SECONDS <= 0.0:
		return 1.0
	return clampf(_acquire_cutin_elapsed / ACQUIRE_CUTIN_REVEAL_SECONDS, 0.0, 1.0)


# The reveal has finished playing and the cut-in is now holding for a
# click/confirm to dismiss. Input is swallowed before this point so an early
# click cannot skip the reveal or leak into gameplay.
func is_acquire_cutin_awaiting_dismiss() -> bool:
	return _acquire_cutin_active and _acquire_cutin_elapsed >= ACQUIRE_CUTIN_REVEAL_SECONDS


func dismiss_acquire_cutin() -> bool:
	if not _acquire_cutin_active:
		return false
	_acquire_cutin_active = false
	_acquire_cutin_elapsed = 0.0
	return true


func has_pillar_card() -> bool:
	return _state == STATE_EGG or _state == STATE_COMPANION


func is_maribo_companion_active() -> bool:
	return _pet_id == PET_ID and _state == STATE_COMPANION


func get_gauge_gain_per_hit(base_gain: float) -> float:
	var gain: float = maxf(0.0, base_gain)
	if not is_maribo_companion_active():
		return gain
	return floor(gain * MARIBO_GAUGE_GAIN_MULTIPLIER)


func get_snapshot() -> Dictionary:
	return {
		"pet_id": _pet_id,
		"state": _state,
		"hatch_hits": _hatch_hits,
		"required_hits": REQUIRED_HITS,
		"egg_pos": _egg_pos,
		"egg_nudge_vx": _egg_nudge_vx,
		"egg_wobble_angle": _egg_wobble_angle,
		"egg_wobble_vel": _egg_wobble_vel,
		"companion_pos": _companion_pos,
		"companion_patrol_dir": _companion_patrol_dir,
		"companion_patrol_pause": _companion_patrol_pause,
		"companion_patrol_change_timer": _companion_patrol_change_timer,
		"companion_patrol_seed": _companion_patrol_seed,
		"companion_patrol_speed": _companion_patrol_speed,
		"companion_patrol_lane_y": _companion_patrol_lane_y,
		"companion_patrol_min_x": _companion_patrol_min_x,
		"companion_patrol_max_x": _companion_patrol_max_x,
		"companion_contact_count": _companion_contact_count,
		"companion_last_contact_pos": _companion_last_contact_pos,
		"companion_hit_cooldown": _companion_hit_cooldown,
		"companion_hit_flash_timer": _companion_hit_flash_timer,
		"companion_skill_id": COMPANION_SKILL_ID if is_maribo_companion_active() else "",
		"companion_skill_name": COMPANION_SKILL_NAME if is_maribo_companion_active() else "",
		"companion_skill_cooldown": _companion_skill_cooldown,
		"companion_skill_cooldown_duration": COMPANION_SKILL_COOLDOWN_SECONDS,
		"companion_skill_ready": is_maribo_companion_active() and _companion_skill_cooldown <= 0.0,
		"companion_skill_last_gain": _companion_skill_last_gain,
		"companion_skill_trigger_count": _companion_skill_trigger_count,
		"companion_skill_flash_timer": _companion_skill_flash_timer,
		"companion_skill_origin": _companion_skill_origin,
		"hit_cooldown": _hit_cooldown,
		"hatch_flash_timer": _hatch_flash_timer,
		"owned_pet_ids": _owned_pet_ids.duplicate(),
		"gauge_gain_bonus_pct": MARIBO_GAUGE_GAIN_BONUS_PCT if is_maribo_companion_active() else 0.0,
	}


func get_save_snapshot() -> Dictionary:
	return {
		"version": SAVE_SNAPSHOT_VERSION,
		"pet_id": _pet_id,
		"state": _state,
		"hatch_hits": _hatch_hits,
		"required_hits": REQUIRED_HITS,
		"egg_pos": _egg_pos,
		"companion_pos": _companion_pos,
		"companion_patrol_dir": _companion_patrol_dir,
		"companion_patrol_pause": _companion_patrol_pause,
		"companion_patrol_change_timer": _companion_patrol_change_timer,
		"companion_patrol_seed": _companion_patrol_seed,
		"companion_patrol_speed": _companion_patrol_speed,
		"companion_patrol_lane_y": _companion_patrol_lane_y,
		"owned_pet_ids": _owned_pet_ids.duplicate(),
		"active_pet_id": _pet_id if _state == STATE_COMPANION else "",
		"gauge_gain_bonus_pct": MARIBO_GAUGE_GAIN_BONUS_PCT if is_maribo_companion_active() else 0.0,
	}


func build_save_snapshot() -> Dictionary:
	return get_save_snapshot()


func apply_save_snapshot(snapshot: Dictionary, owner: Object = null) -> Dictionary:
	reset_for_tests()
	var restore_reason := "ok"
	if snapshot.is_empty():
		if owner != null:
			_sync_owner(owner)
		return {
			"restored": false,
			"reason": "empty_snapshot",
		}

	_pet_id = str(snapshot.get("pet_id", PET_ID))
	_owned_pet_ids = _normalize_pet_id_array(snapshot.get("owned_pet_ids", []))
	if str(snapshot.get("active_pet_id", "")) == PET_ID and not _owned_pet_ids.has(PET_ID):
		_owned_pet_ids.append(PET_ID)

	var restored_state: String = _normalize_lingpet_state(str(snapshot.get("state", STATE_NONE)))
	if restored_state == STATE_COMPANION or _owned_pet_ids.has(PET_ID) or (owner != null and _is_maribo_owned(owner)):
		_state = STATE_COMPANION
		_pet_id = PET_ID
		_hatch_hits = REQUIRED_HITS
		var companion_fallback := Vector2.ZERO
		_companion_pos = _get_vector2_from_variant(snapshot.get("companion_pos", companion_fallback), companion_fallback)
		_restore_companion_patrol(snapshot)
		if owner != null:
			_initialize_companion_patrol(owner, _companion_pos == Vector2.ZERO)
	elif restored_state == STATE_EGG:
		restore_reason = "egg_reset_on_entry"
		if owner != null and _should_spawn_first_maribo_egg(owner):
			_spawn_egg(owner)
		else:
			_state = STATE_NONE
			_pet_id = PET_ID
			_hatch_hits = 0
			_egg_nudge_vx = 0.0
			_egg_wobble_angle = 0.0
			_egg_wobble_vel = 0.0
			_companion_pos = Vector2.ZERO
	else:
		_state = STATE_NONE
		_pet_id = PET_ID
		_hatch_hits = 0
		_egg_nudge_vx = 0.0
		_egg_wobble_angle = 0.0
		_egg_wobble_vel = 0.0
		_companion_pos = Vector2.ZERO
	if owner != null:
		if _state == STATE_COMPANION:
			_mark_maribo_owned(owner)
		_sync_owner(owner)
	return {
		"restored": true,
		"reason": restore_reason,
		"state": _state,
		"owned_pet_ids": _owned_pet_ids.duplicate(),
	}


func restore_save_snapshot(snapshot: Dictionary, owner: Object = null) -> Dictionary:
	return apply_save_snapshot(snapshot, owner)


func reset_for_tests() -> void:
	_state = STATE_NONE
	_pet_id = PET_ID
	_hatch_hits = 0
	_egg_pos = Vector2.ZERO
	_egg_nudge_vx = 0.0
	_egg_wobble_angle = 0.0
	_egg_wobble_vel = 0.0
	_companion_pos = Vector2.ZERO
	_reset_companion_patrol()
	_companion_last_contact_pos = Vector2.ZERO
	_companion_skill_origin = Vector2.ZERO
	_companion_contact_count = 0
	_owned_pet_ids.clear()
	_ball_was_inside = false
	_companion_ball_was_inside = false
	_hit_cooldown = 0.0
	_companion_hit_cooldown = 0.0
	_companion_skill_cooldown = 0.0
	_hatch_flash_timer = 0.0
	_companion_hit_flash_timer = 0.0
	_companion_skill_flash_timer = 0.0
	_companion_skill_trigger_count = 0
	_companion_skill_last_gain = 0.0
	_acquire_cutin_active = false
	_acquire_cutin_elapsed = 0.0
	_has_synced_none = false


func _spawn_egg(owner: Object) -> void:
	_state = STATE_EGG
	_pet_id = PET_ID
	_hatch_hits = 0
	_egg_pos = _resolve_egg_spawn_pos(owner)
	_egg_nudge_vx = 0.0
	_egg_wobble_angle = 0.0
	_egg_wobble_vel = 0.0
	_companion_pos = Vector2.ZERO
	_reset_companion_patrol()
	_companion_last_contact_pos = Vector2.ZERO
	_companion_skill_origin = Vector2.ZERO
	_companion_contact_count = 0
	_ball_was_inside = false
	_companion_ball_was_inside = false
	_hit_cooldown = 0.0
	_companion_hit_cooldown = 0.0
	_companion_skill_cooldown = 0.0
	_hatch_flash_timer = 0.0
	_companion_hit_flash_timer = 0.0
	_companion_skill_flash_timer = 0.0
	_companion_skill_trigger_count = 0
	_companion_skill_last_gain = 0.0
	_acquire_cutin_active = false
	_acquire_cutin_elapsed = 0.0
	_has_synced_none = false
	_sync_owner(owner)


func _resolve_ball_hit(owner: Object) -> bool:
	if not bool(_get_owner_value(owner, "ball_active", false)):
		_ball_was_inside = false
		return false

	var ball_pos: Vector2 = _get_owner_vector2(owner, "ball_pos", Vector2.ZERO)
	var ball_radius: float = maxf(1.0, float(_get_owner_value(owner, "ball_size", BALL_RADIUS_FALLBACK * 2.0)) * 0.5)
	var hit_radius: float = EGG_RADIUS + ball_radius
	var inside: bool = ball_pos.distance_squared_to(_egg_pos) <= hit_radius * hit_radius
	var hit_now: bool = inside and not _ball_was_inside and _hit_cooldown <= 0.0
	_ball_was_inside = inside
	if not hit_now:
		return false

	if _is_player_serve_ball(owner):
		_hit_cooldown = HIT_COOLDOWN_SECONDS
		_apply_soft_bounce(owner, ball_pos, hit_radius)
		return false

	_hatch_hits = mini(REQUIRED_HITS, _hatch_hits + 1)
	_hit_cooldown = HIT_COOLDOWN_SECONDS
	_apply_soft_bounce(owner, ball_pos, hit_radius)
	if _hatch_hits >= REQUIRED_HITS:
		_state = STATE_COMPANION
		_companion_pos = _egg_pos
		_initialize_companion_patrol(owner, false)
		_egg_nudge_vx = 0.0
		_egg_wobble_angle = 0.0
		_egg_wobble_vel = 0.0
		_companion_last_contact_pos = Vector2.ZERO
		_companion_skill_origin = Vector2.ZERO
		_companion_contact_count = 0
		_companion_ball_was_inside = false
		_companion_hit_cooldown = 0.0
		_companion_hit_flash_timer = 0.0
		_companion_skill_cooldown = 0.0
		_companion_skill_flash_timer = 0.0
		_companion_skill_trigger_count = 0
		_companion_skill_last_gain = 0.0
		_hatch_flash_timer = HATCH_FLASH_SECONDS
		_ball_was_inside = false
		_acquire_cutin_active = true
		_acquire_cutin_elapsed = 0.0
		_mark_maribo_owned(owner)
	return true


func _is_player_serve_ball(owner: Object) -> bool:
	return str(_get_owner_value(owner, "ball_serve_origin", "")).strip_edges().to_lower() == "player"


func _apply_soft_bounce(owner: Object, ball_pos: Vector2, hit_radius: float) -> void:
	_apply_egg_paddle_bounce(owner, ball_pos, hit_radius)


func _apply_egg_paddle_bounce(owner: Object, ball_pos: Vector2, hit_radius: float) -> void:
	var half_width: float = maxf(1.0, EGG_TEXTURE_DRAW_SIZE.x * 0.5)
	var hit_pos: float = clampf((ball_pos.x - _egg_pos.x) / half_width, -1.0, 1.0)
	var max_angle: float = float(_get_owner_value(owner, "max_bounce_angle", EGG_PADDLE_BOUNCE_DEFAULT_MAX_ANGLE))
	var launch_dir := Vector2(0.0, -1.0).rotated(deg_to_rad(hit_pos * max_angle)).normalized()
	var ball_vel: Vector2 = _get_owner_vector2(owner, "ball_vel", Vector2.ZERO)
	var min_speed: float = maxf(0.0, float(_get_owner_value(owner, "min_ball_speed", EGG_PADDLE_BOUNCE_DEFAULT_MIN_SPEED)))
	var max_speed: float = maxf(min_speed, float(_get_owner_value(owner, "max_ball_speed", maxf(EGG_PADDLE_BOUNCE_DEFAULT_MAX_SPEED, ball_vel.length()))))
	var speed: float = clampf(maxf(ball_vel.length(), min_speed), min_speed, max_speed)
	owner.set("ball_vel", launch_dir * speed)
	owner.set("ball_pos", Vector2(
		clampf(ball_pos.x, EGG_TEXTURE_DRAW_SIZE.x * 0.5, FIELD_WIDTH - EGG_TEXTURE_DRAW_SIZE.x * 0.5),
		_egg_pos.y - hit_radius - 1.0
	))


func _apply_soft_bounce_at(
	owner: Object,
	center: Vector2,
	ball_pos: Vector2,
	hit_radius: float,
	speed_multiplier: float
) -> void:
	var normal: Vector2 = ball_pos - center
	if normal.length_squared() <= 0.001:
		normal = Vector2(0.0, -1.0)
	else:
		normal = normal.normalized()

	var ball_vel: Vector2 = _get_owner_vector2(owner, "ball_vel", Vector2.ZERO)
	if ball_vel.length_squared() > 0.001 and ball_vel.dot(normal) < 0.0:
		var bounced: Vector2 = ball_vel.bounce(normal) * maxf(0.0, speed_multiplier)
		if bounced.length_squared() > 0.001:
			owner.set("ball_vel", bounced)
	var separated_pos: Vector2 = center + normal * (hit_radius + 1.0)
	owner.set("ball_pos", separated_pos)


func _update_egg_player_contact(delta: float, owner: Object) -> void:
	if _egg_pos == Vector2.ZERO:
		return
	var safe_delta: float = maxf(0.0, delta)
	var frame_scale: float = clampf(safe_delta * 60.0, 0.0, 2.0)
	var player_pos: Vector2 = _get_owner_vector2(owner, "player_pos", Vector2(FIELD_WIDTH * 0.5 - 77.5, FIELD_HEIGHT - 50.0))
	var player_size := Vector2(
		maxf(1.0, float(_get_owner_value(owner, "player_paddle_width", 155.0))),
		maxf(1.0, float(_get_owner_value(owner, "player_paddle_height", 50.0)))
	)
	var player_center: Vector2 = player_pos + player_size * 0.5
	var prox: Vector2 = player_center - _egg_pos
	var dist: float = prox.length()
	if frame_scale > 0.0 and dist < EGG_PLAYER_NUDGE_RADIUS and dist > 1.0:
		var push_dir: float = -prox.x / dist
		if absf(push_dir) < 0.12:
			push_dir = -1.0 if player_center.x >= _egg_pos.x else 1.0
		var push_strength: float = (1.0 - dist / EGG_PLAYER_NUDGE_RADIUS) * EGG_PLAYER_NUDGE_STRENGTH * frame_scale
		_egg_nudge_vx = clampf(_egg_nudge_vx + push_dir * push_strength, -EGG_PLAYER_NUDGE_MAX_VX, EGG_PLAYER_NUDGE_MAX_VX)
		_egg_wobble_vel += push_dir * push_strength * 2.0
	if frame_scale > 0.0:
		if absf(_egg_nudge_vx) > 0.05:
			var nudge_step: float = clampf(_egg_nudge_vx, -EGG_PLAYER_NUDGE_MAX_STEP, EGG_PLAYER_NUDGE_MAX_STEP)
			_egg_pos.x = clampf(_egg_pos.x + nudge_step, EGG_TEXTURE_DRAW_SIZE.x * 0.5, FIELD_WIDTH - EGG_TEXTURE_DRAW_SIZE.x * 0.5)
			_egg_nudge_vx *= pow(EGG_PLAYER_NUDGE_DAMPING, frame_scale)
		else:
			_egg_nudge_vx = 0.0
		_egg_wobble_vel += -_egg_wobble_angle * EGG_PLAYER_WOBBLE_SPRING * frame_scale
		_egg_wobble_vel *= pow(EGG_PLAYER_WOBBLE_DAMPING, frame_scale)
		_egg_wobble_angle = clampf(_egg_wobble_angle + _egg_wobble_vel, -EGG_PLAYER_WOBBLE_MAX_DEGREES, EGG_PLAYER_WOBBLE_MAX_DEGREES)


func _sync_owner(owner: Object) -> void:
	var pet_id: String = _pet_id if _state != STATE_NONE else ""
	owner.set("lingpet_id", pet_id)
	owner.set("active_lingpet_id", pet_id if _state == STATE_COMPANION else "")
	owner.set("current_lingpet_id", pet_id)
	owner.set("lingpet_state", _state)
	owner.set("ringpet_state", _state)
	owner.set("lingpet_hatch_hits", _hatch_hits)
	owner.set("ringpet_hatch_hits", _hatch_hits)
	owner.set("lingpet_hatch_required_hits", REQUIRED_HITS)
	owner.set("ringpet_hatch_required_hits", REQUIRED_HITS)
	owner.set("lingpet_egg_pos", _egg_pos)
	owner.set("lingpet_companion_pos", _companion_pos)
	owner.set("ringpet_companion_pos", _companion_pos)
	owner.set("lingpet_companion_contact_count", _companion_contact_count)
	owner.set("ringpet_companion_contact_count", _companion_contact_count)
	owner.set("lingpet_companion_last_contact_pos", _companion_last_contact_pos)
	owner.set("ringpet_companion_last_contact_pos", _companion_last_contact_pos)
	owner.set("lingpet_companion_hit_cooldown", _companion_hit_cooldown)
	owner.set("ringpet_companion_hit_cooldown", _companion_hit_cooldown)
	owner.set("lingpet_skill_id", COMPANION_SKILL_ID if _state == STATE_COMPANION else "")
	owner.set("ringpet_skill_id", COMPANION_SKILL_ID if _state == STATE_COMPANION else "")
	owner.set("lingpet_skill_name", COMPANION_SKILL_NAME if _state == STATE_COMPANION else "")
	owner.set("ringpet_skill_name", COMPANION_SKILL_NAME if _state == STATE_COMPANION else "")
	owner.set("lingpet_skill_cooldown", _companion_skill_cooldown)
	owner.set("ringpet_skill_cooldown", _companion_skill_cooldown)
	owner.set("lingpet_skill_cooldown_duration", COMPANION_SKILL_COOLDOWN_SECONDS)
	owner.set("ringpet_skill_cooldown_duration", COMPANION_SKILL_COOLDOWN_SECONDS)
	owner.set("lingpet_skill_ready", _state == STATE_COMPANION and _companion_skill_cooldown <= 0.0)
	owner.set("ringpet_skill_ready", _state == STATE_COMPANION and _companion_skill_cooldown <= 0.0)
	owner.set("lingpet_skill_last_gain", _companion_skill_last_gain)
	owner.set("ringpet_skill_last_gain", _companion_skill_last_gain)
	owner.set("lingpet_skill_trigger_count", _companion_skill_trigger_count)
	owner.set("ringpet_skill_trigger_count", _companion_skill_trigger_count)
	owner.set("lingpet_effect_text", _get_effect_text())


func _adopt_owned_maribo(owner: Object) -> void:
	_state = STATE_COMPANION
	_pet_id = PET_ID
	_hatch_hits = REQUIRED_HITS
	_companion_pos = Vector2.ZERO
	_initialize_companion_patrol(owner, true)
	_companion_last_contact_pos = Vector2.ZERO
	_companion_skill_origin = Vector2.ZERO
	_companion_contact_count = 0
	_companion_ball_was_inside = false
	_companion_hit_cooldown = 0.0
	_companion_hit_flash_timer = 0.0
	_companion_skill_cooldown = 0.0
	_companion_skill_flash_timer = 0.0
	_companion_skill_trigger_count = 0
	_companion_skill_last_gain = 0.0
	_hatch_flash_timer = 0.0
	_ball_was_inside = false
	_mark_maribo_owned(owner)
	_sync_owner(owner)


func _mark_maribo_owned(owner: Object) -> void:
	if owner == null:
		return
	if not _owned_pet_ids.has(PET_ID):
		_owned_pet_ids.append(PET_ID)
	for key in ["lingpet_owned_pet_ids", "owned_lingpet_ids", "owned_ringpet_ids"]:
		_ensure_owner_array_contains(owner, key, PET_ID)
	for key in ["lingpet_collection", "ringpet_collection", "owned_lingpets", "owned_ringpets"]:
		_ensure_owner_dict_true(owner, key, PET_ID)


func _get_effect_text() -> String:
	if _state == STATE_EGG:
		return "공에 %d회 맞히면 공명으로 마리보가 깨어납니다." % REQUIRED_HITS
	if _state == STATE_COMPANION:
		return "공을 받아칠 때 게이지 획득량 +10% / 마리보가 공에 닿으면 공명 충전으로 게이지 +40"
	return ""


func _should_spawn_first_maribo_egg(owner: Object) -> bool:
	return (
		_normalize_league_mode(str(_get_owner_value(owner, "ai_mode", "champion"))) == "junior"
		and _normalize_character_type(_get_owner_value(owner, "selected_character_type", "smasher")) == "smasher"
		and not _is_maribo_owned(owner)
	)


func _is_maribo_owned(owner: Object) -> bool:
	if _owned_pet_ids.has(PET_ID):
		return true
	for key in ["lingpet_owned_pet_ids", "owned_lingpet_ids", "owned_ringpet_ids"]:
		var ids: Variant = _get_owner_value(owner, key, [])
		if ids is Array and (ids as Array).has(PET_ID):
			return true
	for key in ["lingpet_collection", "ringpet_collection", "owned_lingpets", "owned_ringpets"]:
		var collection: Variant = _get_owner_value(owner, key, {})
		if collection is Dictionary and bool((collection as Dictionary).get(PET_ID, false)):
			return true
	var state: String = str(_get_owner_value(owner, "lingpet_state", STATE_NONE))
	var id: String = str(_get_owner_value(owner, "lingpet_id", ""))
	return id == PET_ID and (state == STATE_COMPANION or state == "hatched")


func _ensure_owner_array_contains(owner: Object, key: String, pet_id: String) -> void:
	var ids_value: Variant = _get_owner_value(owner, key, [])
	var ids: Array = []
	if ids_value is Array:
		ids = ids_value.duplicate()
	if not ids.has(pet_id):
		ids.append(pet_id)
	owner.set(key, ids)


func _ensure_owner_dict_true(owner: Object, key: String, pet_id: String) -> void:
	var collection_value: Variant = _get_owner_value(owner, key, {})
	var collection: Dictionary = {}
	if collection_value is Dictionary:
		collection = collection_value.duplicate(true)
	collection[pet_id] = true
	owner.set(key, collection)


func _normalize_pet_id_array(value: Variant) -> Array[String]:
	var normalized: Array[String] = []
	if not (value is Array):
		return normalized
	for item in value:
		var pet_id: String = str(item).strip_edges()
		if pet_id != "" and not normalized.has(pet_id):
			normalized.append(pet_id)
	return normalized


func _normalize_lingpet_state(value: String) -> String:
	var normalized: String = value.strip_edges().to_lower()
	if normalized == STATE_EGG or normalized == "hatching" or normalized == "알":
		return STATE_EGG
	if normalized == STATE_COMPANION or normalized == "active" or normalized == "owned" or normalized == "hatched" or normalized == "동행":
		return STATE_COMPANION
	return STATE_NONE


func _get_vector2_from_variant(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _resolve_egg_spawn_pos(owner: Object) -> Vector2:
	var player_pos: Vector2 = _get_owner_vector2(owner, "player_pos", Vector2(FIELD_WIDTH * 0.5 - 77.5, FIELD_HEIGHT - 50.0))
	var player_size := Vector2(
		maxf(1.0, float(_get_owner_value(owner, "player_paddle_width", 155.0))),
		maxf(1.0, float(_get_owner_value(owner, "player_paddle_height", 50.0)))
	)
	var center_x: float = player_pos.x + player_size.x * 0.5
	var side_sign: float = -1.0 if center_x >= FIELD_WIDTH * 0.5 else 1.0
	var x: float = center_x + side_sign * (player_size.x * 0.5 + EGG_RADIUS + 18.0)
	var y: float = FIELD_HEIGHT - EGG_RADIUS - EGG_FLOOR_MARGIN
	return Vector2(
		clampf(x, EGG_RADIUS + 14.0, FIELD_WIDTH - EGG_RADIUS - 14.0),
		clampf(y, EGG_RADIUS + 28.0, FIELD_HEIGHT - EGG_RADIUS - EGG_FLOOR_MARGIN)
	)


func _update_companion_motion(delta: float, owner: Object) -> void:
	if _companion_patrol_seed <= 0 or _companion_patrol_min_x <= 0.0 or _companion_patrol_max_x <= _companion_patrol_min_x:
		_initialize_companion_patrol(owner, _companion_pos == Vector2.ZERO)
	else:
		_sync_companion_patrol_lane(owner)
	if _companion_pos == Vector2.ZERO:
		_initialize_companion_patrol(owner, true)
		return

	var safe_delta: float = maxf(0.0, delta)
	_companion_pos.y = _companion_patrol_lane_y
	if safe_delta <= 0.0:
		return
	if _companion_patrol_pause > 0.0:
		_companion_patrol_pause = maxf(0.0, _companion_patrol_pause - safe_delta)
		return

	_companion_patrol_change_timer = maxf(0.0, _companion_patrol_change_timer - safe_delta)
	var next_x: float = _companion_pos.x + _companion_patrol_dir * _companion_patrol_speed * safe_delta
	if next_x <= _companion_patrol_min_x:
		_companion_pos.x = _companion_patrol_min_x
		_companion_patrol_dir = 1.0
		_companion_patrol_pause = _next_companion_patrol_range(COMPANION_PATROL_PAUSE_MIN, COMPANION_PATROL_PAUSE_MAX)
		_companion_patrol_speed = _next_companion_patrol_speed()
		_companion_patrol_change_timer = _next_companion_patrol_range(COMPANION_PATROL_CHANGE_INTERVAL_MIN, COMPANION_PATROL_CHANGE_INTERVAL_MAX)
	elif next_x >= _companion_patrol_max_x:
		_companion_pos.x = _companion_patrol_max_x
		_companion_patrol_dir = -1.0
		_companion_patrol_pause = _next_companion_patrol_range(COMPANION_PATROL_PAUSE_MIN, COMPANION_PATROL_PAUSE_MAX)
		_companion_patrol_speed = _next_companion_patrol_speed()
		_companion_patrol_change_timer = _next_companion_patrol_range(COMPANION_PATROL_CHANGE_INTERVAL_MIN, COMPANION_PATROL_CHANGE_INTERVAL_MAX)
	else:
		_companion_pos.x = next_x
		var surprise_chance: float = 1.0 - pow(1.0 - COMPANION_PATROL_SURPRISE_CHANCE_PER_SECOND, safe_delta)
		if _next_companion_patrol_unit() < surprise_chance:
			_companion_patrol_dir *= -1.0
			_companion_patrol_pause = _next_companion_patrol_range(COMPANION_PATROL_PAUSE_MIN, COMPANION_PATROL_PAUSE_MAX)
			_companion_patrol_speed = _next_companion_patrol_speed()
			_companion_patrol_change_timer = _next_companion_patrol_range(COMPANION_PATROL_CHANGE_INTERVAL_MIN, COMPANION_PATROL_CHANGE_INTERVAL_MAX)
		elif _companion_patrol_change_timer <= 0.0:
			_choose_next_companion_patrol_action()


func _initialize_companion_patrol(owner: Object, randomize_x: bool) -> void:
	_sync_companion_patrol_lane(owner)
	if _companion_patrol_seed <= 0:
		_companion_patrol_seed = _build_companion_patrol_seed(owner)
	if randomize_x or _companion_pos == Vector2.ZERO:
		_companion_pos = Vector2(
			_next_companion_patrol_range(_companion_patrol_min_x, _companion_patrol_max_x),
			_companion_patrol_lane_y
		)
	else:
		_companion_pos = Vector2(
			clampf(_companion_pos.x, _companion_patrol_min_x, _companion_patrol_max_x),
			_companion_patrol_lane_y
		)
	if is_zero_approx(_companion_patrol_dir):
		_companion_patrol_dir = -1.0 if _next_companion_patrol_unit() < 0.5 else 1.0
	_companion_patrol_speed = clampf(
		_companion_patrol_speed if _companion_patrol_speed > 0.0 else _next_companion_patrol_speed(),
		COMPANION_PATROL_SPEED_MIN,
		COMPANION_PATROL_SPEED_MAX
	)
	_companion_patrol_pause = maxf(0.0, _companion_patrol_pause)
	if _companion_patrol_change_timer <= 0.0:
		_companion_patrol_change_timer = _next_companion_patrol_range(COMPANION_PATROL_CHANGE_INTERVAL_MIN, COMPANION_PATROL_CHANGE_INTERVAL_MAX)


func _sync_companion_patrol_lane(owner: Object) -> void:
	var lane: Dictionary = _resolve_companion_patrol_lane(owner)
	_companion_patrol_lane_y = float(lane.get("y", FIELD_HEIGHT - 50.0))
	_companion_patrol_min_x = float(lane.get("min_x", COMPANION_PATROL_EDGE_MARGIN))
	_companion_patrol_max_x = float(lane.get("max_x", FIELD_WIDTH - COMPANION_PATROL_EDGE_MARGIN))
	if _companion_pos != Vector2.ZERO:
		_companion_pos.x = clampf(_companion_pos.x, _companion_patrol_min_x, _companion_patrol_max_x)
		_companion_pos.y = _companion_patrol_lane_y


func _resolve_companion_patrol_lane(owner: Object) -> Dictionary:
	var player_pos: Vector2 = _get_owner_vector2(owner, "player_pos", Vector2(FIELD_WIDTH * 0.5 - 77.5, FIELD_HEIGHT - 50.0))
	var player_size := Vector2(
		maxf(1.0, float(_get_owner_value(owner, "player_paddle_width", 155.0))),
		maxf(1.0, float(_get_owner_value(owner, "player_paddle_height", 50.0)))
	)
	var lane_y: float = player_pos.y + player_size.y * COMPANION_PATROL_LANE_Y_OFFSET
	var min_x: float = maxf(COMPANION_PATROL_EDGE_MARGIN, COMPANION_RADIUS + 10.0)
	var max_x: float = minf(FIELD_WIDTH - COMPANION_PATROL_EDGE_MARGIN, FIELD_WIDTH - COMPANION_RADIUS - 10.0)
	return {
		"y": clampf(lane_y, COMPANION_RADIUS + 20.0, FIELD_HEIGHT - COMPANION_RADIUS - 20.0),
		"min_x": min_x,
		"max_x": max_x,
	}


func _restore_companion_patrol(snapshot: Dictionary) -> void:
	var restored_dir: float = float(snapshot.get("companion_patrol_dir", _companion_patrol_dir))
	if restored_dir > 0.0:
		_companion_patrol_dir = 1.0
	elif restored_dir < 0.0:
		_companion_patrol_dir = -1.0
	else:
		_companion_patrol_dir = 0.0
	if is_zero_approx(_companion_patrol_dir):
		_companion_patrol_dir = 1.0
	_companion_patrol_pause = maxf(0.0, float(snapshot.get("companion_patrol_pause", 0.0)))
	_companion_patrol_change_timer = maxf(0.0, float(snapshot.get("companion_patrol_change_timer", 0.0)))
	_companion_patrol_seed = maxi(0, int(snapshot.get("companion_patrol_seed", 0)))
	_companion_patrol_speed = clampf(
		float(snapshot.get("companion_patrol_speed", COMPANION_PATROL_SPEED)),
		COMPANION_PATROL_SPEED_MIN,
		COMPANION_PATROL_SPEED_MAX
	)
	_companion_patrol_lane_y = float(snapshot.get("companion_patrol_lane_y", _companion_patrol_lane_y))


func _reset_companion_patrol() -> void:
	_companion_patrol_dir = 0.0
	_companion_patrol_pause = 0.0
	_companion_patrol_change_timer = 0.0
	_companion_patrol_seed = 0
	_companion_patrol_speed = 0.0
	_companion_patrol_lane_y = 0.0
	_companion_patrol_min_x = 0.0
	_companion_patrol_max_x = 0.0


func _choose_next_companion_patrol_action() -> void:
	var roll: float = _next_companion_patrol_unit()
	if roll < 0.30:
		_companion_patrol_pause = _next_companion_patrol_range(COMPANION_PATROL_PAUSE_MIN, COMPANION_PATROL_PAUSE_MAX)
	elif roll < 0.65:
		_companion_patrol_dir *= -1.0
		_companion_patrol_pause = _next_companion_patrol_range(COMPANION_PATROL_PAUSE_MIN, COMPANION_PATROL_PAUSE_MAX)
	elif roll < 0.82:
		_companion_patrol_dir *= -1.0
	_companion_patrol_speed = _next_companion_patrol_speed()
	_companion_patrol_change_timer = _next_companion_patrol_range(COMPANION_PATROL_CHANGE_INTERVAL_MIN, COMPANION_PATROL_CHANGE_INTERVAL_MAX)


func _next_companion_patrol_range(min_value: float, max_value: float) -> float:
	var unit: float = _next_companion_patrol_unit()
	return lerpf(min_value, max_value, unit)


func _next_companion_patrol_speed() -> float:
	return _next_companion_patrol_range(COMPANION_PATROL_SPEED_MIN, COMPANION_PATROL_SPEED_MAX)


func _next_companion_patrol_unit() -> float:
	if _companion_patrol_seed <= 0:
		_companion_patrol_seed = 991
	_companion_patrol_seed = int((_companion_patrol_seed * 1103515245 + 12345) % COMPANION_PATROL_SEED_MOD)
	return float(_companion_patrol_seed % 10000) / 10000.0


func _build_companion_patrol_seed(owner: Object) -> int:
	var player_pos: Vector2 = _get_owner_vector2(owner, "player_pos", Vector2(FIELD_WIDTH * 0.5 - 77.5, FIELD_HEIGHT - 50.0))
	var raw_seed: int = int(absf(round(
		player_pos.x * 13.0
		+ player_pos.y * 17.0
		+ _companion_pos.x * 19.0
		+ _companion_pos.y * 23.0
		+ float(_companion_skill_trigger_count + 1) * 97.0
	)))
	return maxi(1, raw_seed % COMPANION_PATROL_SEED_MOD)


func _resolve_companion_ball_hit(owner: Object, registry: Object = null) -> bool:
	if not bool(_get_owner_value(owner, "ball_active", false)):
		_companion_ball_was_inside = false
		return false
	if _companion_pos == Vector2.ZERO:
		_initialize_companion_patrol(owner, true)

	var ball_pos: Vector2 = _get_owner_vector2(owner, "ball_pos", Vector2.ZERO)
	var ball_radius: float = maxf(1.0, float(_get_owner_value(owner, "ball_size", BALL_RADIUS_FALLBACK * 2.0)) * 0.5)
	var hit_radius: float = COMPANION_COLLISION_RADIUS + ball_radius
	var inside: bool = ball_pos.distance_squared_to(_companion_pos) <= hit_radius * hit_radius
	var hit_now: bool = inside and not _companion_ball_was_inside and _companion_hit_cooldown <= 0.0
	_companion_ball_was_inside = inside
	if not hit_now:
		return false

	_companion_contact_count += 1
	_companion_last_contact_pos = ball_pos
	_companion_hit_cooldown = COMPANION_HIT_COOLDOWN_SECONDS
	_companion_hit_flash_timer = COMPANION_HIT_FLASH_SECONDS
	_apply_soft_bounce_at(
		owner,
		_companion_pos,
		ball_pos,
		hit_radius,
		COMPANION_BOUNCE_SPEED_MULTIPLIER
	)
	_try_activate_companion_skill(owner, registry)
	return true


func _try_activate_companion_skill(owner: Object, registry: Object = null) -> bool:
	if _state != STATE_COMPANION or _companion_skill_cooldown > 0.0:
		return false
	var gauge_max: float = maxf(1.0, float(_get_owner_value(owner, "special_gauge_max", 500.0)))
	var current_gauge: float = clampf(float(_get_owner_value(owner, "special_gauge", 0.0)), 0.0, gauge_max)
	if current_gauge >= gauge_max:
		_companion_skill_last_gain = 0.0
		return false
	var next_gauge: float = minf(gauge_max, current_gauge + COMPANION_SKILL_GAUGE_GAIN)
	var applied_gain: float = maxf(0.0, next_gauge - current_gauge)
	if applied_gain <= 0.0:
		_companion_skill_last_gain = 0.0
		return false
	owner.set("special_gauge", next_gauge)
	_companion_skill_last_gain = applied_gain
	_companion_skill_trigger_count += 1
	_companion_skill_cooldown = COMPANION_SKILL_COOLDOWN_SECONDS
	_companion_skill_flash_timer = COMPANION_SKILL_FLASH_SECONDS
	_companion_skill_origin = _companion_pos
	_trigger_companion_skill_feedback(registry)
	return true


func _trigger_companion_skill_feedback(registry: Object) -> void:
	if registry == null:
		return
	var feedback: Object = _get_registry_instance(registry, "battle_feedback_state")
	if feedback != null and feedback.has_method("trigger_gauge_flash"):
		feedback.trigger_gauge_flash()
	var orb_hud_state: Object = _get_registry_instance(registry, "orb_hud_state")
	if orb_hud_state != null and orb_hud_state.has_method("trigger_gauge_spin"):
		orb_hud_state.trigger_gauge_spin(Time.get_ticks_msec())


func draw_pillar_card(canvas: CanvasItem, rect: Rect2, time_seconds: float = 0.0, scale_factor: float = 1.0) -> void:
	if canvas == null or not has_pillar_card() or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var safe_scale: float = maxf(0.5, scale_factor)
	var pulse: float = 0.5 + sin(time_seconds * 6.0) * 0.5
	var hit_flash: float = maxf(_get_companion_hit_flash_ratio(), _get_companion_skill_flash_ratio())
	var border_color := Color(0.30, 1.0, 0.78, 0.88) if _state == STATE_COMPANION else Color(0.42, 0.88, 1.0, 0.86)
	var fill_color := Color(0.025, 0.042, 0.078, 0.92)
	canvas.draw_rect(rect, fill_color, true)
	canvas.draw_rect(rect, Color(border_color.r, border_color.g, border_color.b, 0.18 + 0.10 * pulse + 0.22 * hit_flash), false, maxf(3.0, 4.0 * safe_scale), true)
	canvas.draw_rect(rect, border_color, false, maxf(1.0, 1.35 * safe_scale), true)

	var stripe_rect := Rect2(rect.position, Vector2(maxf(3.0, 4.0 * safe_scale), rect.size.y))
	canvas.draw_rect(stripe_rect, Color(border_color.r, border_color.g, border_color.b, 0.50), true)

	var icon_center := Vector2(rect.position.x + rect.size.x * 0.52, rect.position.y + rect.size.y * 0.36)
	var icon_radius: float = minf(rect.size.x, rect.size.y) * 0.24
	if _state == STATE_EGG:
		_draw_pillar_egg_icon(canvas, icon_center, icon_radius)
	else:
		_draw_pillar_companion_icon(canvas, icon_center, icon_radius)

	var progress: float = _get_pillar_card_progress()
	var bar_size := Vector2(rect.size.x * 0.62, maxf(3.0, 4.0 * safe_scale))
	var bar_rect := Rect2(
		Vector2(rect.position.x + rect.size.x * 0.22, rect.position.y + rect.size.y * 0.76),
		bar_size
	)
	canvas.draw_rect(bar_rect, Color(0.0, 0.0, 0.0, 0.42), true)
	if progress > 0.0:
		canvas.draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * progress, bar_rect.size.y)), Color(border_color.r, border_color.g, border_color.b, 0.88), true)
	for i in range(REQUIRED_HITS):
		var pip_x: float = bar_rect.position.x + bar_rect.size.x * (float(i) + 0.5) / float(REQUIRED_HITS)
		var filled: bool = _state == STATE_COMPANION or i < _hatch_hits
		canvas.draw_circle(
			Vector2(pip_x, bar_rect.end.y + maxf(4.0, 5.0 * safe_scale)),
			maxf(1.5, 2.2 * safe_scale),
			Color(border_color.r, border_color.g, border_color.b, 0.86 if filled else 0.26)
		)
	if _state == STATE_COMPANION:
		_draw_pillar_skill_status(canvas, rect, icon_center, icon_radius, progress, hit_flash, safe_scale)


func _get_pillar_card_progress() -> float:
	if _state == STATE_COMPANION:
		if COMPANION_SKILL_COOLDOWN_SECONDS <= 0.0:
			return 1.0
		return clampf(1.0 - _companion_skill_cooldown / COMPANION_SKILL_COOLDOWN_SECONDS, 0.0, 1.0)
	return clampf(float(_hatch_hits) / float(REQUIRED_HITS), 0.0, 1.0)


func _get_companion_hit_flash_ratio() -> float:
	if _state != STATE_COMPANION or COMPANION_HIT_FLASH_SECONDS <= 0.0:
		return 0.0
	return clampf(_companion_hit_flash_timer / COMPANION_HIT_FLASH_SECONDS, 0.0, 1.0)


func _get_companion_skill_flash_ratio() -> float:
	if _state != STATE_COMPANION or COMPANION_SKILL_FLASH_SECONDS <= 0.0:
		return 0.0
	return clampf(_companion_skill_flash_timer / COMPANION_SKILL_FLASH_SECONDS, 0.0, 1.0)


func _draw_pillar_skill_status(
	canvas: CanvasItem,
	rect: Rect2,
	icon_center: Vector2,
	icon_radius: float,
	progress: float,
	flash_ratio: float,
	scale_factor: float
) -> void:
	if _companion_skill_cooldown > 0.0:
		var overlay_height: float = icon_radius * 2.0 * (1.0 - progress)
		var overlay_rect := Rect2(
			Vector2(icon_center.x - icon_radius, icon_center.y - icon_radius),
			Vector2(icon_radius * 2.0, overlay_height)
		)
		canvas.draw_rect(overlay_rect, Color(0.0, 0.0, 0.0, 0.34), true)
	else:
		for i in range(COMPANION_CARD_READY_SPARK_COUNT):
			var angle: float = TAU * float(i) / float(COMPANION_CARD_READY_SPARK_COUNT) + flash_ratio * 0.4
			var spark_pos: Vector2 = icon_center + Vector2(cos(angle), sin(angle)) * (icon_radius + 5.0 * scale_factor)
			canvas.draw_circle(spark_pos, maxf(1.2, 1.8 * scale_factor), Color(1.0, 0.94, 0.30, 0.78))
	var badge_center := Vector2(rect.end.x - maxf(6.0, 8.0 * scale_factor), rect.position.y + maxf(6.0, 8.0 * scale_factor))
	var badge_radius: float = maxf(2.5, 3.8 * scale_factor)
	var badge_alpha: float = 0.52 + 0.34 * maxf(flash_ratio, 1.0 if _companion_skill_cooldown <= 0.0 else 0.0)
	canvas.draw_circle(badge_center, badge_radius, Color(1.0, 0.86, 0.24, badge_alpha))
	canvas.draw_circle(badge_center, badge_radius * 0.42, Color(1.0, 1.0, 0.82, 0.80))


func _draw_egg(canvas: CanvasItem, center: Vector2) -> void:
	var hit_ratio: float = clampf(float(_hatch_hits) / float(REQUIRED_HITS), 0.0, 1.0)
	var pulse: float = 0.5 + sin(float(Time.get_ticks_msec()) * 0.006) * 0.5
	var glow_alpha: float = 0.16 + 0.10 * pulse + 0.12 * hit_ratio
	var wobble_radians: float = deg_to_rad(_egg_wobble_angle)
	var visual_center: Vector2 = center + Vector2(sin(wobble_radians) * EGG_PLAYER_WOBBLE_VISUAL_PIXELS, absf(sin(wobble_radians)) * 1.2)
	canvas.draw_circle(visual_center + Vector2(0.0, 3.0), EGG_RADIUS + 16.0, Color(0.25, 0.85, 1.0, glow_alpha))
	var texture_rect := Rect2(
		visual_center - Vector2(EGG_TEXTURE_DRAW_SIZE.x * 0.5, EGG_TEXTURE_DRAW_SIZE.y * EGG_TEXTURE_TOP_OFFSET_RATIO),
		EGG_TEXTURE_DRAW_SIZE
	)
	canvas.draw_texture_rect(_get_egg_texture_for_hits(), texture_rect, false)
	_draw_egg_crack_light(canvas, texture_rect, pulse)


func _get_egg_texture_for_hits() -> Texture2D:
	# Crack stage scales with REQUIRED_HITS: 0 = intact, the final pre-hatch hit
	# shows the heavily-cracked CRACK_2, earlier hits the lighter CRACK_1. With
	# REQUIRED_HITS == 2 the single intermediate hit lands on CRACK_2 (dramatic
	# "about to hatch"); with 3 it is CRACK_1 -> CRACK_2, matching the old look.
	if _hatch_hits <= 0:
		return MARIBO_EGG_TEXTURE
	if _hatch_hits >= REQUIRED_HITS - 1:
		return MARIBO_EGG_TEXTURE_CRACK_2
	return MARIBO_EGG_TEXTURE_CRACK_1


func _draw_egg_crack_light(canvas: CanvasItem, texture_rect: Rect2, pulse: float) -> void:
	if _hatch_hits <= 0:
		return
	var stage_boost: float = clampf(float(_hatch_hits - 1) * 0.22, 0.0, 0.34)
	var leak_alpha: float = clampf(0.46 + 0.24 * pulse + stage_boost, 0.0, 0.92)
	var main_crack: Array[Vector2] = [
		Vector2(0.50, 0.15),
		Vector2(0.46, 0.26),
		Vector2(0.51, 0.36),
		Vector2(0.45, 0.49),
		Vector2(0.49, 0.63),
	]
	_draw_egg_crack_light_path(canvas, texture_rect, main_crack, leak_alpha, 1.0)
	var side_crack: Array[Vector2] = [
		Vector2(0.69, 0.24),
		Vector2(0.66, 0.35),
		Vector2(0.70, 0.48),
	]
	_draw_egg_crack_light_path(canvas, texture_rect, side_crack, leak_alpha * 0.72, 0.74)
	if _hatch_hits >= 2:
		var lower_crack: Array[Vector2] = [
			Vector2(0.50, 0.56),
			Vector2(0.47, 0.68),
			Vector2(0.52, 0.80),
		]
		_draw_egg_crack_light_path(canvas, texture_rect, lower_crack, leak_alpha * 0.82, 0.86)


func _draw_egg_crack_light_path(
	canvas: CanvasItem,
	texture_rect: Rect2,
	path_ratios: Array[Vector2],
	alpha: float,
	width_scale: float
) -> void:
	if path_ratios.size() < 2:
		return
	var points := PackedVector2Array()
	for ratio: Vector2 in path_ratios:
		points.append(texture_rect.position + Vector2(texture_rect.size.x * ratio.x, texture_rect.size.y * ratio.y))
	var glow_width: float = EGG_CRACK_LIGHT_GLOW_WIDTH * width_scale
	var core_width: float = EGG_CRACK_LIGHT_MAIN_WIDTH * width_scale
	canvas.draw_polyline(points, Color(0.20, 1.0, 1.0, 0.20 * alpha), glow_width, true)
	canvas.draw_polyline(points, Color(1.0, 0.92, 0.36, 0.50 * alpha), core_width, true)
	canvas.draw_polyline(points, Color(1.0, 1.0, 0.86, 0.82 * alpha), maxf(0.75, core_width * 0.38), true)
	for i in range(points.size()):
		if i % 2 == 0:
			canvas.draw_circle(points[i], maxf(1.0, core_width * 0.44), Color(0.78, 1.0, 1.0, 0.34 * alpha))


func _draw_companion(canvas: CanvasItem, center: Vector2) -> void:
	# Code-driven bob doubles as the idle "breathing" motion when the patrol is
	# paused, and adds a little life on top of the walk-sheet's own step bob.
	var bob: float = sin(float(Time.get_ticks_msec()) * 0.0048) * 2.6
	var c: Vector2 = center + Vector2(0.0, bob)
	var glow_alpha: float = 0.17 + 0.07 * sin(float(Time.get_ticks_msec()) * 0.006)
	var hit_flash: float = _get_companion_hit_flash_ratio()
	var skill_flash: float = _get_companion_skill_flash_ratio()
	canvas.draw_circle(c, COMPANION_RADIUS + 13.0, Color(0.22, 1.0, 0.78, glow_alpha))
	_draw_companion_sprite(canvas, c)
	if skill_flash > 0.0:
		var skill_radius: float = lerpf(COMPANION_RADIUS + 18.0, COMPANION_RADIUS + 54.0, 1.0 - skill_flash)
		canvas.draw_circle(c, skill_radius, Color(1.0, 0.96, 0.36, 0.16 * skill_flash))
		canvas.draw_arc(c, skill_radius * 0.82, 0.0, TAU, 40, Color(1.0, 0.92, 0.38, 0.70 * skill_flash), 2.6, true)
		_draw_companion_skill_burst(canvas, c, skill_flash)
	if hit_flash > 0.0:
		var flash_radius: float = lerpf(COMPANION_RADIUS + 8.0, COMPANION_RADIUS + 34.0, 1.0 - hit_flash)
		canvas.draw_circle(c, flash_radius, Color(0.70, 1.0, 0.92, 0.22 * hit_flash))
		canvas.draw_arc(c, flash_radius * 0.86, 0.0, TAU, 36, Color(0.88, 1.0, 0.76, 0.58 * hit_flash), 2.0, true)


func _draw_companion_sprite(canvas: CanvasItem, c: Vector2) -> void:
	var tex: Texture2D = MARIBO_COMPANION_WALK_SHEET
	if tex == null:
		return
	var cols: int = maxi(1, COMPANION_SHEET_COLS)
	var rows: int = maxi(1, COMPANION_SHEET_ROWS)
	var cell_w: float = float(tex.get_width()) / float(cols)
	var cell_h: float = float(tex.get_height()) / float(rows)
	var frame: int = _get_companion_sprite_frame()
	var col: int = frame % cols
	var row: int = floori(float(frame) / float(cols))
	var src := Rect2(float(col) * cell_w, float(row) * cell_h, cell_w, cell_h)
	var dest := Rect2(
		c - COMPANION_SPRITE_DRAW_SIZE * 0.5 + Vector2(0.0, COMPANION_SPRITE_Y_OFFSET),
		COMPANION_SPRITE_DRAW_SIZE
	)
	canvas.draw_texture_rect_region(tex, dest, src)


func _get_companion_sprite_frame() -> int:
	# Paused patrol -> hold the upright "rest" frame as idle (breathing comes
	# from the code bob). Moving -> cycle the full walk strip.
	if _companion_patrol_pause > 0.0:
		return clampi(COMPANION_IDLE_FRAME, 0, COMPANION_SHEET_FRAME_COUNT - 1)
	var elapsed: float = float(Time.get_ticks_msec()) / 1000.0
	return int(elapsed * COMPANION_WALK_FPS) % COMPANION_SHEET_FRAME_COUNT


func _draw_companion_skill_burst(canvas: CanvasItem, center: Vector2, flash_ratio: float) -> void:
	var expansion: float = 1.0 - flash_ratio
	var phase_offset: float = float(_companion_skill_trigger_count % 5) * 0.17
	for i in range(COMPANION_SKILL_BURST_PARTICLES):
		var angle: float = TAU * float(i) / float(COMPANION_SKILL_BURST_PARTICLES) + phase_offset
		var dir := Vector2(cos(angle), sin(angle))
		var ray_start: Vector2 = center + dir * lerpf(10.0, 20.0, expansion)
		var ray_end: Vector2 = center + dir * lerpf(22.0, 52.0, expansion)
		var alpha: float = 0.62 * flash_ratio
		canvas.draw_line(ray_start, ray_end, Color(1.0, 0.90, 0.28, alpha), maxf(1.0, 2.2 * flash_ratio), true)
		canvas.draw_circle(ray_end, maxf(1.2, 2.6 * flash_ratio), Color(1.0, 1.0, 0.72, alpha))


func _draw_pillar_egg_icon(canvas: CanvasItem, center: Vector2, radius: float) -> void:
	canvas.draw_circle(center, radius + 4.0, Color(0.35, 0.90, 1.0, 0.18))
	_draw_filled_ellipse(
		canvas,
		Rect2(center - Vector2(radius * 0.72, radius * 0.98), Vector2(radius * 1.44, radius * 1.96)),
		Color(1.0, 0.80, 0.96, 0.96)
	)
	canvas.draw_arc(center, radius * 0.86, 0.0, TAU, 24, Color(0.45, 0.96, 1.0, 0.78), 1.4, true)
	if _hatch_hits > 0:
		var crack_color := Color(0.18, 0.10, 0.24, 0.72)
		canvas.draw_line(center + Vector2(-2.0, -radius * 0.62), center + Vector2(3.0, -radius * 0.10), crack_color, 1.2, true)
		canvas.draw_line(center + Vector2(3.0, -radius * 0.10), center + Vector2(-1.0, radius * 0.34), crack_color, 1.2, true)
	if _hatch_hits >= 2:
		canvas.draw_line(center + Vector2(5.0, -radius * 0.18), center + Vector2(-4.0, radius * 0.22), Color(0.18, 0.10, 0.24, 0.72), 1.2, true)


func _draw_pillar_companion_icon(canvas: CanvasItem, center: Vector2, radius: float) -> void:
	canvas.draw_circle(center, radius + 5.0, Color(0.25, 1.0, 0.78, 0.18))
	canvas.draw_arc(center, radius + 3.0, -0.15, TAU - 0.15, 24, Color(0.52, 1.0, 0.94, 0.58), 1.5, true)
	canvas.draw_circle(center + Vector2(-radius * 0.52, -radius * 0.08), radius * 0.38, Color(0.50, 0.92, 1.0, 0.56))
	canvas.draw_circle(center + Vector2(radius * 0.52, -radius * 0.08), radius * 0.38, Color(0.50, 0.92, 1.0, 0.56))
	canvas.draw_circle(center, radius * 0.82, Color(0.96, 0.64, 0.92, 0.96))
	canvas.draw_circle(center + Vector2(-radius * 0.24, -radius * 0.12), maxf(1.0, radius * 0.10), Color(0.05, 0.08, 0.13, 0.92))
	canvas.draw_circle(center + Vector2(radius * 0.24, -radius * 0.12), maxf(1.0, radius * 0.10), Color(0.05, 0.08, 0.13, 0.92))


func _draw_filled_ellipse(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var points := PackedVector2Array()
	var center: Vector2 = rect.get_center()
	var radius := Vector2(rect.size.x * 0.5, rect.size.y * 0.5)
	for i in range(32):
		var angle: float = TAU * float(i) / 32.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	canvas.draw_colored_polygon(points, color)


func _draw_hatch_flash(canvas: CanvasItem, center: Vector2) -> void:
	var t: float = clampf(_hatch_flash_timer / HATCH_FLASH_SECONDS, 0.0, 1.0)
	_draw_hatch_shell_burst(canvas, center, t)
	var radius: float = lerpf(18.0, 74.0, 1.0 - t)
	canvas.draw_circle(center, radius, Color(1.0, 0.76, 0.94, 0.24 * t))
	canvas.draw_arc(center, radius * 0.72, 0.0, TAU, 48, Color(0.44, 1.0, 1.0, 0.58 * t), 3.0, true)


func _draw_hatch_shell_burst(canvas: CanvasItem, center: Vector2, timer_ratio: float) -> void:
	var burst_progress: float = clampf(1.0 - timer_ratio, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - burst_progress, 2.0)
	var fade: float = clampf(timer_ratio * 1.18, 0.0, 1.0)
	var egg_center: Vector2 = center + Vector2(0.0, -EGG_TEXTURE_DRAW_SIZE.y * 0.06)
	for i in range(HATCH_BREAK_SHARD_COUNT):
		var unit: float = float(i) / float(HATCH_BREAK_SHARD_COUNT)
		var angle: float = -PI * 0.92 + unit * PI * 1.84
		var drift: float = sin(float(i) * 2.17) * 0.18
		var dir := Vector2(cos(angle + drift), sin(angle + drift))
		var travel: float = HATCH_BREAK_SHARD_DISTANCE * (0.45 + 0.55 * _hatch_shard_unit(i + 2)) * eased
		var gravity := Vector2(0.0, HATCH_BREAK_SHARD_GRAVITY * burst_progress * burst_progress)
		var shard_center: Vector2 = egg_center + dir * travel + gravity
		var size: float = lerpf(8.5, 4.0, burst_progress) * (0.78 + 0.34 * _hatch_shard_unit(i + 11))
		var rotation: float = angle + burst_progress * lerpf(-1.7, 1.7, _hatch_shard_unit(i + 19))
		var shell_color: Color = Color(1.0, 0.74, 0.93, 0.82 * fade)
		if i % 3 == 1:
			shell_color = Color(0.62, 0.95, 1.0, 0.74 * fade)
		elif i % 3 == 2:
			shell_color = Color(1.0, 0.91, 0.98, 0.78 * fade)
		_draw_hatch_shell_shard(canvas, shard_center, size, rotation, shell_color, fade)
		if i % 2 == 0:
			var sparkle_pos: Vector2 = egg_center + dir * (travel + 8.0)
			canvas.draw_circle(sparkle_pos, maxf(1.0, size * 0.22), Color(0.92, 1.0, 1.0, 0.58 * fade))


func _draw_hatch_shell_shard(canvas: CanvasItem, center: Vector2, size: float, rotation: float, fill_color: Color, fade: float) -> void:
	var points := PackedVector2Array()
	var local_points := [
		Vector2(-0.68, 0.46),
		Vector2(-0.18, -0.72),
		Vector2(0.70, -0.22),
		Vector2(0.32, 0.64),
	]
	for local: Vector2 in local_points:
		points.append(center + local.rotated(rotation) * size)
	canvas.draw_colored_polygon(points, fill_color)
	var outline := PackedVector2Array()
	for point: Vector2 in points:
		outline.append(point)
	outline.append(points[0])
	canvas.draw_polyline(outline, Color(0.18, 0.11, 0.24, 0.36 * fade), 1.0, true)


func _hatch_shard_unit(index: int) -> float:
	var shard_seed: int = int((index * 1103515245 + 12345) % 10000)
	return float(shard_seed) / 10000.0


func _normalize_league_mode(mode: String) -> String:
	var normalized: String = mode.strip_edges().to_lower().replace(" ", "").replace("_", "").replace("-", "")
	if normalized == "junior" or normalized == "juniorleague":
		return "junior"
	if normalized == "mythic" or normalized == "mythicleague":
		return "mythic"
	return "champion"


func _normalize_character_type(value: Variant) -> String:
	var normalized: String = str(value).strip_edges().to_lower()
	if normalized == "soldier" or normalized == "commando":
		return "soldier"
	if normalized == "viper":
		return "viper"
	if normalized == "optimus" or normalized == "io":
		return "optimus"
	return "smasher"


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	return BattleSceneOwnerReader.get_value(owner, key, fallback)


func _get_owner_vector2(owner: Object, key: String, fallback: Vector2) -> Vector2:
	return BattleSceneOwnerReader.get_vector2(owner, key, fallback)


func _get_registry_instance(registry: Object, key: String) -> Object:
	if registry == null:
		return null
	if registry.has_method("get_cached_instance"):
		var cached: Variant = registry.get_cached_instance(key)
		if typeof(cached) == TYPE_OBJECT and is_instance_valid(cached):
			return cached as Object
	if registry.has_method("get_instance"):
		var value: Variant = registry.get_instance(key)
		if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
			return value as Object
	return null
