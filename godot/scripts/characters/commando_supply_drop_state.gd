extends RefCounted

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ImpactShockwaveTextureCache := preload("res://scripts/effects/impact_shockwave_texture_cache.gd")
const GrenadeExplosionDrawer := preload("res://scripts/effects/grenade_explosion_drawer.gd")
const CommandoSupplyDropFxHost := preload("res://scripts/characters/commando_supply_drop_fx_host.gd")
const CommandoSupplyDropPayloadResolver := preload("res://scripts/characters/commando_supply_drop_payload_resolver.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const HOLD_REQUIRED_SECONDS := 1.0
const HOLD_GAUGE_THRESHOLD_SECONDS := 0.3
const HOLD_GAUGE_WIDTH := 80.0
const HOLD_GAUGE_HEIGHT := 12.0
const HOLD_GAUGE_TOP_OFFSET := 40.0
const PLAYER_SERVE_HOLD_ALLOWED_SECONDS := 6.0
const POST_SERVE_HOLD_LOCK_SECONDS := 3.0
const DROP_DELAY_SECONDS := 1.15
const DROP_EFFECT_SECONDS := 0.55
const FRAME_SECONDS := 1.0 / 60.0
const PYTHON_AIRCRAFT_ARRIVAL_MIN_FRAMES := 90
const PYTHON_AIRCRAFT_ARRIVAL_MAX_FRAMES := 300
const PYTHON_SPAWN_DELAY_FRAMES := 48
const PYTHON_AIRCRAFT_SPEED_PX_PER_FRAME := 2.0
const PYTHON_INITIAL_DROP_MIN_FRAMES := 12
const PYTHON_INITIAL_DROP_MAX_FRAMES := 150
const PYTHON_BURST_DROP_FRAMES := 10
const PYTHON_BURST_COOLDOWN_MIN_FRAMES := 90
const PYTHON_BURST_COOLDOWN_MAX_FRAMES := 180
const PYTHON_DELAYED_DROP_MIN_FRAMES := 120
const PYTHON_DELAYED_DROP_MAX_FRAMES := 210
const PYTHON_NORMAL_FAST_MIN_FRAMES := 10
const PYTHON_NORMAL_FAST_MAX_FRAMES := 30
const PYTHON_NORMAL_MID_MIN_FRAMES := 40
const PYTHON_NORMAL_MID_MAX_FRAMES := 80
const PYTHON_NORMAL_SLOW_MIN_FRAMES := 100
const PYTHON_NORMAL_SLOW_MAX_FRAMES := 180
# Match the fire-support stealth lane: the aircraft starts at the screen edge
# beyond the centered game canvas, while payloads remain clamped to the canvas.
const AIRCRAFT_START_X := -360.0
const AIRCRAFT_END_X := 1120.0
const AIRCRAFT_ALTITUDE_Y := 56.0
const AIRCRAFT_SPEED_PIXELS_PER_SECOND := PYTHON_AIRCRAFT_SPEED_PX_PER_FRAME / FRAME_SECONDS
const AIRCRAFT_COLLISION_SIZE := Vector2(96.0, 44.0)
const AIRCRAFT_TILT_SHEET_LEFT_PATH := "res://assets/sprites/effects/commando_supply_aircraft/commando_supply_aircraft_tilt_sheet_autosprite_v1_left.png"
const AIRCRAFT_TILT_SHEET_RIGHT_PATH := "res://assets/sprites/effects/commando_supply_aircraft/commando_supply_aircraft_tilt_sheet_autosprite_v1_right.png"
const AIRCRAFT_TILT_FRAME_COUNT := 16
const AIRCRAFT_TILT_GRID_COLS := 4
const AIRCRAFT_TILT_GRID_ROWS := 4
const AIRCRAFT_TILT_FRAME_INTERVAL := 0.06
const AIRCRAFT_TILT_DRAW_SIZE := Vector2(148.0, 148.0)
const AIRCRAFT_CRASH_SHEET_LEFT_PATH := "res://assets/sprites/effects/commando_supply_aircraft/commando_supply_aircraft_crash_sheet_autosprite_v1_left.png"
const AIRCRAFT_CRASH_SHEET_RIGHT_PATH := "res://assets/sprites/effects/commando_supply_aircraft/commando_supply_aircraft_crash_sheet_autosprite_v1_right.png"
const AIRCRAFT_CRASH_FRAME_COUNT := 16
const AIRCRAFT_CRASH_GRID_COLS := 4
const AIRCRAFT_CRASH_GRID_ROWS := 4
# Wounded-plane descent: slower than the original 0.82s snap so the shoot-down
# reads as a real spiral crash. Single tunable lever = AIRCRAFT_CRASH_SECONDS;
# the 16-frame burning sheet stretches to span the whole descent (interval is
# derived, so it always stays in sync with the fall duration).
const AIRCRAFT_CRASH_SECONDS := 1.5
const AIRCRAFT_CRASH_FRAME_INTERVAL := AIRCRAFT_CRASH_SECONDS / float(AIRCRAFT_CRASH_FRAME_COUNT)
const AIRCRAFT_CRASH_DRAW_SIZE := Vector2(148.0, 148.0)
const AIRCRAFT_INVULNERABLE_SECONDS := 0.25
const AIRCRAFT_CRASH_GROUND_Y := 660.0
const AIRCRAFT_CRASH_DRIFT_X := 96.0
# Ground-impact feedback when the wounded plane finally hits the floor.
const AIRCRAFT_CRASH_IMPACT_SHAKE_AMOUNT := 0.20
const AIRCRAFT_CRASH_IMPACT_SHAKE_INTENSITY := 7.0
# Grenade-class ground blast: drawn via the shared GrenadeExplosionDrawer
# airstrike style for the whole window; the same radius gates ball AND player
# knockback so the visual matches the felt hazard.
const AIRCRAFT_CRASH_BLAST_SECONDS := GrenadeExplosionDrawer.FIRE_SUPPORT_EXPLOSION_DURATION_FRAMES / 60.0
const AIRCRAFT_CRASH_KNOCKBACK_RADIUS := GrenadeExplosionDrawer.GRENADE_EXPLOSION_RADIUS
const AIRCRAFT_CRASH_KNOCKBACK_POWER := 16.0
const AIRCRAFT_CRASH_KNOCKBACK_SPEED_CEILING := 22.0
const AIRCRAFT_CRASH_KNOCKBACK_MIN_UP_BIAS := 0.35
# Player paddle shove: bomb-surprise precedent is ~15.6 px/frame @10f. Live QA
# tuned this up to 2x the original 18.0 — total travel ~207px with the 0.85
# decay curve (velocity is the single distance lever; frames/decay set feel).
const AIRCRAFT_CRASH_PLAYER_KNOCKBACK_VELOCITY := 36.0
const AIRCRAFT_CRASH_PLAYER_KNOCKBACK_FRAMES := 12.0
const AIRCRAFT_CRASH_PLAYER_KNOCKBACK_DECAY := 0.85
const AIRCRAFT_HIT_BALL_Y_DAMPING := 0.5
const AIRCRAFT_DEFAULT_HITBOX_PADDING := 5.0
const PAYLOAD_SPAWN_OFFSET := Vector2(0.0, 104.0)
const PAYLOAD_INTERVAL_SECONDS := CommandoSupplyDropPayloadResolver.PAYLOAD_INTERVAL_SECONDS
const COLLECTIBLE_DROP_BOX_SIZE := Vector2(40.0, 30.0)
const SUPPLY_PAYLOAD_SPRITE_PATH := "res://assets/sprites/effects/commando_supply_drop/commando_supply_parachute_crate_imagegen_v1.png"
const SUPPLY_PAYLOAD_DRAW_SIZE := Vector2(84.0, 84.0)
const SUPPLY_PAYLOAD_DRAW_OFFSET := Vector2(0.0, -14.0)
const COLLECTIBLE_DROP_SAFE_MARGIN := 32.0
const COLLECTIBLE_DROP_FALL_SPEED := 168.0
const COLLECTIBLE_DROP_SWAY_SPEED := 4.2
const COLLECTIBLE_DROP_SWAY_AMOUNT := 13.0
const COLLECTIBLE_DROP_DESPAWN_MARGIN := 50.0
const DEFAULT_PLAY_WIDTH := 760.0
const DEFAULT_PLAY_HEIGHT := 800.0
const MIN_PAYLOAD_COUNT := CommandoSupplyDropPayloadResolver.MIN_PAYLOAD_COUNT
const MAX_PAYLOAD_COUNT := CommandoSupplyDropPayloadResolver.MAX_PAYLOAD_COUNT
const DROP_TIMING_PATTERNS := CommandoSupplyDropPayloadResolver.DROP_TIMING_PATTERNS
const DEFAULT_FIELD_ITEM_DROP_CANDIDATES := CommandoSupplyDropPayloadResolver.DEFAULT_FIELD_ITEM_DROP_CANDIDATES
const DEFAULT_RENTAL_CANDIDATES := CommandoSupplyDropPayloadResolver.DEFAULT_RENTAL_CANDIDATES
const DEFAULT_RENTAL_WEAPON_DROP_WEIGHTS := CommandoSupplyDropPayloadResolver.DEFAULT_RENTAL_WEAPON_DROP_WEIGHTS
const DEFAULT_FIELD_ITEM_ID := CommandoSupplyDropPayloadResolver.DEFAULT_FIELD_ITEM_ID
const SAVE_SNAPSHOT_VERSION := 1

static var _aircraft_tilt_sheet_cache: Dictionary = {}
static var _aircraft_tilt_sheet_checked: Dictionary = {}
static var _aircraft_crash_sheet_cache: Dictionary = {}
static var _aircraft_crash_sheet_checked: Dictionary = {}
static var _supply_payload_texture: Texture2D = null
static var _supply_payload_texture_checked := false

var hold_time := 0.0
var pending_hold_time := 0.0
var active := false
var timer := 0.0
var radio_motion := false
var radio_timer := 0.0
var radio_duration := 0.35
var hold_radio_audio_active := false
var hold_gauge_player_pos := Vector2(302.0, 654.0)
var hold_gauge_player_size := Vector2(155.0, 50.0)
var aircraft_spawned := false
var aircraft_arrival_delay := 0.0
var aircraft_audio_active := false
var aircraft_direction := "left_to_right"
var aircraft_pos := Vector2(AIRCRAFT_START_X, AIRCRAFT_ALTITUDE_Y)
var aircraft_crashing := false
var aircraft_crash_elapsed := 0.0
var aircraft_crash_timer := 0.0
var aircraft_crash_rotation := 0.0
var aircraft_crash_start_pos := Vector2.ZERO
var aircraft_crash_target_pos := Vector2.ZERO
var aircraft_exploded := false
var aircraft_crash_source := ""
var flight_elapsed := 0.0
var flight_duration := DROP_DELAY_SECONDS
var drop_timing_pattern := "normal"
var drop_effects: Array[Dictionary] = []
var collectible_drops: Array[Dictionary] = []
var explosion_effects: Array[Dictionary] = []
var pending_drop: Dictionary = {}
var pending_drops: Array[Dictionary] = []
var pending_drop_delays: Array[float] = []
var fx_host = null
var fx_host_add_pending := false
# One-shot radial blast queued when the plane finishes its crash. Armed on the
# player-control update path (no ball access there) and consumed on the next
# ball frame inside resolve_ball_collision.
var _pending_crash_ball_impulse := false
var _crash_ball_impulse_center := Vector2.ZERO
# Grenade-class ground blast window: while the timer runs the explosion is
# drawn at crash_blast_center and a player paddle entering the radius is
# shoved once (covers both "standing next to the crash" and "walking into
# the blast while it is still erupting").
var crash_blast_timer := 0.0
var crash_blast_center := Vector2.ZERO
var _crash_blast_player_knocked := false


func reset() -> void:
	hold_time = 0.0
	pending_hold_time = 0.0
	active = false
	timer = 0.0
	radio_motion = false
	radio_timer = 0.0
	hold_radio_audio_active = false
	hold_gauge_player_pos = Vector2(302.0, 654.0)
	hold_gauge_player_size = Vector2(155.0, 50.0)
	aircraft_spawned = false
	aircraft_arrival_delay = 0.0
	aircraft_audio_active = false
	aircraft_direction = "left_to_right"
	aircraft_pos = Vector2(AIRCRAFT_START_X, AIRCRAFT_ALTITUDE_Y)
	aircraft_crashing = false
	aircraft_crash_elapsed = 0.0
	aircraft_crash_timer = 0.0
	aircraft_crash_rotation = 0.0
	aircraft_crash_start_pos = Vector2.ZERO
	aircraft_crash_target_pos = Vector2.ZERO
	aircraft_exploded = false
	aircraft_crash_source = ""
	_pending_crash_ball_impulse = false
	_crash_ball_impulse_center = Vector2.ZERO
	crash_blast_timer = 0.0
	crash_blast_center = Vector2.ZERO
	_crash_blast_player_knocked = false
	flight_elapsed = 0.0
	flight_duration = DROP_DELAY_SECONDS
	drop_timing_pattern = "normal"
	drop_effects.clear()
	collectible_drops.clear()
	explosion_effects.clear()
	pending_drop.clear()
	pending_drops.clear()
	pending_drop_delays.clear()
	_tear_down_fx_host(false)


func reset_round(deps: Dictionary = {}) -> void:
	_stop_hold_radio_audio(deps)
	_stop_aircraft_audio(deps)
	# Drop any crash blast that was armed but never consumed (e.g. the plane hit
	# the ground on the same frame the ball scored) so it can't fire on the next
	# round's serve. NOT cleared in cancel_transient(): that runs every
	# not-holding frame and would eat a legitimately armed impulse before the
	# ball path consumes it.
	_pending_crash_ball_impulse = false
	_crash_ball_impulse_center = Vector2.ZERO
	crash_blast_timer = 0.0
	crash_blast_center = Vector2.ZERO
	_crash_blast_player_knocked = false
	cancel_transient(deps)


func cancel_transient(_deps: Dictionary = {}) -> void:
	hold_time = 0.0
	pending_hold_time = 0.0
	radio_motion = false
	radio_timer = 0.0
	# Python parity: releasing the hold never cuts a busy radio channel
	# (non-forced stop_radio_loop skips a busy channel) -- the sample
	# finishes naturally. Only round / battle cleanup force-stops.
	_release_hold_radio_audio_gate()


func update(delta: float, deps: Dictionary = {}) -> Dictionary:
	var safe_delta: float = max(0.0, delta)
	_update_drop_effects(safe_delta)
	_update_collectible_drops(safe_delta, deps)
	_update_explosion_effects(safe_delta)
	if crash_blast_timer > 0.0:
		crash_blast_timer = max(0.0, crash_blast_timer - safe_delta)
		# Re-check every blast frame so a paddle WALKING INTO the erupting blast
		# still gets shoved, not only one parked there at the explosion instant.
		_try_apply_crash_blast_player_knockback(deps)
	if radio_motion:
		radio_timer = max(0.0, radio_timer - safe_delta)
		if radio_timer <= 0.0:
			radio_motion = false
			# Python parity (supply_drop.py tick_radio_animation): tail expiry
			# only re-arms the one-playback gate; the ~3.5s radio sample keeps
			# playing to its natural end. During the hold phase
			# _sync_hold_feedback re-arms radio_timer before this decrement,
			# so gate on active.
			if active:
				_release_hold_radio_audio_gate()
	if aircraft_crashing:
		return _merge_update_results(_update_aircraft_crash(safe_delta, deps), _resolve_collectible_pickups(deps))
	var lifecycle_result: Dictionary = {}
	if active:
		var flight_delta := safe_delta
		if not aircraft_spawned:
			var arrival_result: Dictionary = _update_aircraft_arrival(safe_delta, deps)
			if not aircraft_spawned:
				return _merge_update_results(arrival_result, _resolve_collectible_pickups(deps))
			flight_delta = max(0.0, float(arrival_result.get("remaining_delta_after_aircraft_spawn", 0.0)))
			lifecycle_result = arrival_result
		var previous_flight_elapsed: float = flight_elapsed
		flight_elapsed += flight_delta
		_update_aircraft_visual()
		var obstacle_result: Dictionary = _resolve_aircraft_obstacle_collision_from_deps(deps)
		if not obstacle_result.is_empty():
			return _merge_update_results(obstacle_result, _resolve_collectible_pickups(deps))
		var payload_timer_delta: float = _get_payload_drop_timer_delta(previous_flight_elapsed, flight_elapsed, deps)
		if payload_timer_delta > 0.0:
			timer -= payload_timer_delta
		if (payload_timer_delta > 0.0 or _is_aircraft_over_payload_drop_zone(deps)) and timer <= 0.0 and not pending_drops.is_empty():
			lifecycle_result = _merge_update_results(lifecycle_result, _resolve_ready_drops(deps))
		if active and aircraft_spawned and _is_aircraft_offscreen():
			_complete_aircraft_flight(deps)
	return _merge_update_results(lifecycle_result, _resolve_collectible_pickups(deps))


func update_input(input_snapshot: Dictionary, delta: float, special_gauge: float, skill_config: Object, skill_state: Object, deps: Dictionary = {}) -> Dictionary:
	if active:
		return update(delta, deps)
	var current_msec: int = _get_current_msec(deps)
	var holding: bool = _is_supply_drop_hold_pressed(input_snapshot)
	if not holding:
		cancel_transient(deps)
		return update(delta, deps)
	if not _can_accept_supply_hold(deps, current_msec):
		cancel_transient(deps)
		return update(delta, deps)
	if not _is_supply_drop_activation_ready(special_gauge, skill_config, skill_state, deps, current_msec):
		_accumulate_pending_hold(delta, deps)
		return update(delta, deps)
	_cache_hold_gauge_anchor(deps)
	if pending_hold_time > 0.0:
		hold_time = max(hold_time, pending_hold_time)
		pending_hold_time = 0.0
	hold_time += delta
	if hold_time < HOLD_REQUIRED_SECONDS:
		_sync_hold_feedback(deps)
		return update(delta, deps)
	if not _can_activate(special_gauge, skill_config, skill_state, current_msec):
		cancel_transient(deps)
		return update(delta, deps)
	hold_time = 0.0
	pending_hold_time = 0.0
	active = true
	aircraft_spawned = false
	aircraft_arrival_delay = _get_aircraft_arrival_delay(deps)
	timer = aircraft_arrival_delay
	radio_motion = true
	radio_timer = radio_duration
	aircraft_audio_active = false
	aircraft_crashing = false
	aircraft_crash_elapsed = 0.0
	aircraft_crash_timer = 0.0
	aircraft_crash_rotation = 0.0
	aircraft_exploded = false
	aircraft_crash_source = ""
	aircraft_direction = _get_aircraft_direction(deps)
	flight_elapsed = 0.0
	aircraft_pos = _get_aircraft_start_pos()
	pending_drops = _build_pending_drops(deps)
	drop_timing_pattern = _get_drop_timing_pattern(deps)
	pending_drop_delays = _build_pending_drop_delays(deps, pending_drops.size(), drop_timing_pattern)
	flight_duration = _get_aircraft_travel_duration()
	pending_drop = pending_drops[0].duplicate(true) if not pending_drops.is_empty() else {}
	# Python parity (start_supply_radio_loop channel-busy dedupe): a hold radio
	# sample that is already playing continues to its natural end; replaying
	# the same radio.wav here made the radio cue audibly fire twice per
	# activation.
	if not hold_radio_audio_active:
		_play_audio_method(deps, "play_commando_supply_radio")
	if aircraft_arrival_delay <= 0.0:
		_spawn_aircraft(deps)
	return {
		"activated": true,
		"skill_name": "supply_drop",
		"aircraft_arrival_delay": aircraft_arrival_delay,
		"special_gauge_delta": -float(skill_config.get_skill_cost("supply_drop") if skill_config != null and skill_config.has_method("get_skill_cost") else 350.0),
	}


func get_snapshot() -> Dictionary:
	return {
		"hold_time": hold_time,
		"pending_hold_time": pending_hold_time,
		"active": active,
		"timer": timer,
		"radio_motion": radio_motion,
		"radio_timer": radio_timer,
		"radio_duration": radio_duration,
		"hold_gauge_visible": _is_hold_gauge_visible(),
		"hold_progress": _get_hold_gauge_progress(),
		"hold_gauge_rect": _get_hold_gauge_rect(),
		"hold_radio_audio_active": hold_radio_audio_active,
		"aircraft_spawned": aircraft_spawned,
		"aircraft_arrival_delay": aircraft_arrival_delay,
		"aircraft_audio_active": aircraft_audio_active,
		"aircraft_direction": aircraft_direction,
		"aircraft_pos": aircraft_pos,
		"aircraft_rect": get_aircraft_collision_rect(),
		"aircraft_crashing": aircraft_crashing,
		"aircraft_crash_elapsed": aircraft_crash_elapsed,
		"aircraft_crash_timer": aircraft_crash_timer,
		"aircraft_crash_rotation": aircraft_crash_rotation,
		"aircraft_crash_start_pos": aircraft_crash_start_pos,
		"aircraft_crash_target_pos": aircraft_crash_target_pos,
		"aircraft_exploded": aircraft_exploded,
		"aircraft_crash_source": aircraft_crash_source,
		"crash_blast_timer": crash_blast_timer,
		"crash_blast_center": crash_blast_center,
		"crash_blast_player_knocked": _crash_blast_player_knocked,
		"flight_elapsed": flight_elapsed,
		"flight_duration": flight_duration,
		"drop_timing_pattern": drop_timing_pattern,
		"drop_effects": drop_effects.duplicate(true),
		"collectible_drops": collectible_drops.duplicate(true),
		"explosion_effects": explosion_effects.duplicate(true),
		"pending_drop": pending_drop.duplicate(true),
		"pending_drops": pending_drops.duplicate(true),
		"pending_drop_delays": pending_drop_delays.duplicate(),
	}


func get_save_snapshot() -> Dictionary:
	var snapshot: Dictionary = get_snapshot()
	snapshot["version"] = SAVE_SNAPSHOT_VERSION
	return snapshot


func build_save_snapshot() -> Dictionary:
	return get_save_snapshot()


func apply_save_snapshot(snapshot: Dictionary, deps: Dictionary = {}) -> Dictionary:
	_stop_hold_radio_audio(deps)
	_stop_aircraft_audio(deps)
	reset()
	if snapshot.is_empty():
		return {
			"restored": false,
			"reason": "empty_snapshot",
		}

	hold_time = max(0.0, float(snapshot.get("hold_time", 0.0)))
	pending_hold_time = max(0.0, float(snapshot.get("pending_hold_time", 0.0)))
	active = bool(snapshot.get("active", false))
	timer = max(0.0, float(snapshot.get("timer", 0.0)))
	radio_motion = bool(snapshot.get("radio_motion", false))
	radio_timer = max(0.0, float(snapshot.get("radio_timer", 0.0)))
	radio_duration = max(0.0, float(snapshot.get("radio_duration", radio_duration)))
	aircraft_spawned = bool(snapshot.get(
		"aircraft_spawned",
		active and (
			bool(snapshot.get("aircraft_audio_active", false))
			or bool(snapshot.get("aircraft_crashing", false))
			or float(snapshot.get("flight_elapsed", 0.0)) > 0.0
		)
	))
	aircraft_arrival_delay = max(0.0, float(snapshot.get("aircraft_arrival_delay", 0.0)))
	aircraft_direction = "right_to_left" if str(snapshot.get("aircraft_direction", "left_to_right")) == "right_to_left" else "left_to_right"
	aircraft_pos = _get_vector2(snapshot.get("aircraft_pos", aircraft_pos), aircraft_pos)
	aircraft_crashing = bool(snapshot.get("aircraft_crashing", false))
	aircraft_crash_elapsed = max(0.0, float(snapshot.get("aircraft_crash_elapsed", 0.0)))
	aircraft_crash_timer = max(0.0, float(snapshot.get("aircraft_crash_timer", 0.0)))
	aircraft_crash_rotation = float(snapshot.get("aircraft_crash_rotation", 0.0))
	aircraft_crash_start_pos = _get_vector2(snapshot.get("aircraft_crash_start_pos", aircraft_pos), aircraft_pos)
	aircraft_crash_target_pos = _get_vector2(snapshot.get("aircraft_crash_target_pos", aircraft_crash_target_pos), aircraft_crash_target_pos)
	aircraft_exploded = bool(snapshot.get("aircraft_exploded", false))
	aircraft_crash_source = str(snapshot.get("aircraft_crash_source", ""))
	crash_blast_timer = max(0.0, float(snapshot.get("crash_blast_timer", 0.0)))
	crash_blast_center = _get_vector2(snapshot.get("crash_blast_center", Vector2.ZERO), Vector2.ZERO)
	_crash_blast_player_knocked = bool(snapshot.get("crash_blast_player_knocked", false))
	flight_elapsed = max(0.0, float(snapshot.get("flight_elapsed", 0.0)))
	flight_duration = max(_get_aircraft_travel_duration(), float(snapshot.get("flight_duration", DROP_DELAY_SECONDS)))
	drop_timing_pattern = _normalize_drop_timing_pattern(str(snapshot.get("drop_timing_pattern", "normal")))
	drop_effects = _duplicate_dictionary_array(snapshot.get("drop_effects", []))
	collectible_drops = _duplicate_dictionary_array(snapshot.get("collectible_drops", []))
	explosion_effects = _duplicate_dictionary_array(snapshot.get("explosion_effects", []))
	pending_drop = _duplicate_dictionary(snapshot.get("pending_drop", {}))
	pending_drops = _duplicate_dictionary_array(snapshot.get("pending_drops", []))
	pending_drop_delays = _duplicate_float_array(snapshot.get("pending_drop_delays", []))
	while pending_drop_delays.size() < pending_drops.size():
		pending_drop_delays.append(PAYLOAD_INTERVAL_SECONDS)
	aircraft_audio_active = bool(snapshot.get("aircraft_audio_active", false)) and active and aircraft_spawned and not aircraft_crashing
	if aircraft_audio_active:
		_play_audio_method(deps, "play_commando_supply_aircraft_loop")
	return {
		"restored": true,
		"active": active,
		"pending_payloads": pending_drops.size(),
		"collectible_count": collectible_drops.size(),
	}


func restore_save_snapshot(snapshot: Dictionary, deps: Dictionary = {}) -> Dictionary:
	return apply_save_snapshot(snapshot, deps)


func is_aircraft_audio_active() -> bool:
	return aircraft_audio_active


func is_hold_radio_audio_active() -> bool:
	return hold_radio_audio_active


func build_hold_gauge_status() -> Dictionary:
	var progress: float = _get_hold_gauge_progress()
	return {
		"visible": _is_hold_gauge_visible(),
		"progress": progress,
		"percent": int(round(progress * 100.0)),
		"rect": _get_hold_gauge_rect(),
		"player_pos": hold_gauge_player_pos,
		"player_size": hold_gauge_player_size,
	}


func build_aircraft_sprite_status() -> Dictionary:
	var active_path: String = _get_aircraft_tilt_sheet_path(aircraft_direction)
	var active_sheet: Texture2D = _get_aircraft_tilt_sheet(aircraft_direction)
	var left_sheet: Texture2D = _get_aircraft_tilt_sheet("right_to_left")
	var right_sheet: Texture2D = _get_aircraft_tilt_sheet("left_to_right")
	var crash_active_path: String = AIRCRAFT_CRASH_SHEET_LEFT_PATH if aircraft_direction == "right_to_left" else AIRCRAFT_CRASH_SHEET_RIGHT_PATH
	var crash_active_sheet: Texture2D = _get_aircraft_crash_sheet(aircraft_direction)
	var crash_left_sheet: Texture2D = _get_aircraft_crash_sheet("right_to_left")
	var crash_right_sheet: Texture2D = _get_aircraft_crash_sheet("left_to_right")
	return {
		"sheet_pipeline": true,
		"active_path": active_path,
		"active_loaded": active_sheet != null,
		"left_loaded": left_sheet != null,
		"right_loaded": right_sheet != null,
		"frame": _get_aircraft_tilt_frame(),
		"frame_count": AIRCRAFT_TILT_FRAME_COUNT,
		"grid_cols": AIRCRAFT_TILT_GRID_COLS,
		"grid_rows": AIRCRAFT_TILT_GRID_ROWS,
		"frame_interval": AIRCRAFT_TILT_FRAME_INTERVAL,
		"draw_size": AIRCRAFT_TILT_DRAW_SIZE,
		"crash_sheet_pipeline": true,
		"crash_active_path": crash_active_path,
		"crash_active_loaded": crash_active_sheet != null,
		"crash_left_loaded": crash_left_sheet != null,
		"crash_right_loaded": crash_right_sheet != null,
		"crash_frame": _get_aircraft_crash_frame(),
		"crash_frame_count": AIRCRAFT_CRASH_FRAME_COUNT,
		"crash_grid_cols": AIRCRAFT_CRASH_GRID_COLS,
		"crash_grid_rows": AIRCRAFT_CRASH_GRID_ROWS,
		"crash_frame_interval": AIRCRAFT_CRASH_FRAME_INTERVAL,
		"crash_draw_size": AIRCRAFT_CRASH_DRAW_SIZE,
		"speed_pixels_per_second": AIRCRAFT_SPEED_PIXELS_PER_SECOND,
		"travel_duration": _get_aircraft_travel_duration(),
	}


func build_payload_sprite_status() -> Dictionary:
	var payload_texture: Texture2D = _get_supply_payload_texture()
	return {
		"sprite_pipeline": true,
		"path": SUPPLY_PAYLOAD_SPRITE_PATH,
		"active_loaded": payload_texture != null,
		"draw_size": SUPPLY_PAYLOAD_DRAW_SIZE,
		"draw_offset": SUPPLY_PAYLOAD_DRAW_OFFSET,
		"texture_size": payload_texture.get_size() if payload_texture != null else Vector2.ZERO,
	}


func has_visible_effects() -> bool:
	return (active and aircraft_spawned) or aircraft_crashing or crash_blast_timer > 0.0 or radio_motion or _is_hold_gauge_visible() or not drop_effects.is_empty() or not collectible_drops.is_empty() or not explosion_effects.is_empty() or _is_fx_host_visible()


func prewarm_assets() -> void:
	prewarm_vfx_assets()


func draw(
	canvas: CanvasItem,
	shake_offset: Vector2 = Vector2.ZERO,
	layout_context: Dictionary = {}
) -> void:
	if canvas == null:
		return
	prewarm_vfx_assets()
	_sync_fx_host(canvas, shake_offset, layout_context)
	_draw_hold_gauge(canvas, shake_offset)
	_draw_supply_texture_layers(canvas, shake_offset)
	if crash_blast_timer > 0.0:
		# Grenade-class ground blast (shared airstrike-style drawer); particle
		# effects layer on top of it.
		GrenadeExplosionDrawer.draw_zone(canvas, _build_crash_blast_zone(), shake_offset)
	for effect in explosion_effects:
		_draw_explosion_effect(canvas, effect, shake_offset)
	if active and aircraft_spawned:
		_draw_aircraft(canvas, aircraft_pos + shake_offset, aircraft_direction, 0.0, false)
	elif aircraft_crashing:
		_draw_aircraft(canvas, aircraft_pos + shake_offset, aircraft_direction, aircraft_crash_rotation, true)
	for effect in drop_effects:
		_draw_drop_effect(canvas, effect, shake_offset)
	for drop in collectible_drops:
		_draw_collectible_drop(canvas, drop, shake_offset)


static func prewarm_vfx_assets() -> void:
	ImpactFlareTextureCache.prewarm()
	ImpactShockwaveTextureCache.prewarm()
	GrenadeExplosionDrawer.prewarm_assets()
	CommandoSupplyDropFxHost.prewarm_assets()
	_get_aircraft_tilt_sheet("left_to_right")
	_get_aircraft_tilt_sheet("right_to_left")
	_get_aircraft_crash_sheet("left_to_right")
	_get_aircraft_crash_sheet("right_to_left")
	_get_supply_payload_texture()


func build_vfx_remaster_plan() -> Dictionary:
	prewarm_vfx_assets()
	var host_status: Dictionary = CommandoSupplyDropFxHost.build_pipeline_status()
	var aircraft_sprite_status: Dictionary = build_aircraft_sprite_status()
	var explosion_layer_count: int = min(explosion_effects.size(), 24)
	var visible_effect_count: int = drop_effects.size() + collectible_drops.size() + explosion_effects.size()
	if active and aircraft_spawned:
		visible_effect_count += 1
	if aircraft_crashing:
		visible_effect_count += 1
	var plan := {
		"godot_native_vfx_remaster": true,
		"texture_piece_pipeline": true,
		"shader_host_pipeline": bool(host_status.get("shader_host_pipeline", false)),
		"gpu_particle_pipeline": bool(host_status.get("gpu_particle_pipeline", false)),
		"tween_pipeline": true,
		"direct_draw_fallback": true,
		"aircraft_sprite_sheet_pipeline": true,
		"aircraft_sprite_sheet_loaded": bool(aircraft_sprite_status.get("active_loaded", false)),
		"aircraft_sprite_frame_count": AIRCRAFT_TILT_FRAME_COUNT,
		"aircraft_crash_sprite_sheet_pipeline": true,
		"aircraft_crash_sprite_sheet_loaded": bool(aircraft_sprite_status.get("crash_active_loaded", false)),
		"aircraft_crash_sprite_frame_count": AIRCRAFT_CRASH_FRAME_COUNT,
		"aircraft_speed_pixels_per_second": AIRCRAFT_SPEED_PIXELS_PER_SECOND,
		"collectible_payload_sprite_pipeline": true,
		"collectible_payload_sprite_loaded": bool(build_payload_sprite_status().get("active_loaded", false)),
		"aircraft_spawned": aircraft_spawned,
		"aircraft_arrival_delay": aircraft_arrival_delay,
		"aircraft_arrival_timer": timer if active and not aircraft_spawned else 0.0,
		"aircraft_texture_layers": 3 if (active and aircraft_spawned) or aircraft_crashing else 0,
		"drop_texture_layers": drop_effects.size() * 3,
		"collectible_texture_layers": collectible_drops.size() * 3,
		"parachute_texture_layers": (drop_effects.size() + collectible_drops.size()) * 3,
		"crash_texture_layers": explosion_layer_count,
		"visible_effect_count": visible_effect_count,
		"fx_host_attached": _is_valid_fx_host() and (fx_host as Node).get_parent() != null,
		"fx_host_active": _is_valid_fx_host() and bool((fx_host as CanvasItem).visible),
	}
	for key in host_status.keys():
		plan[key] = host_status[key]
	return plan


func get_aircraft_collision_rect() -> Rect2:
	return Rect2(aircraft_pos - AIRCRAFT_COLLISION_SIZE * 0.5, AIRCRAFT_COLLISION_SIZE)


func resolve_ball_collision(scene: Dictionary, context: Dictionary, deps: Dictionary = {}) -> bool:
	# Consume the post-crash ground blast before the shoot-down gate: once the
	# plane is crashing/exploded _can_aircraft_be_hit() returns false, so the
	# impulse must be applied ahead of that early-out.
	_apply_pending_crash_ball_impulse(scene, context)
	if not _can_aircraft_be_hit(context, deps):
		return false
	var ball_pos: Vector2 = _get_vector2(scene.get("ball_pos", Vector2.ZERO), Vector2.ZERO)
	var previous_ball_pos: Vector2 = _get_vector2(
		scene.get("previous_ball_pos", context.get("ball_pos", ball_pos)),
		ball_pos
	)
	var ball_radius: float = max(1.0, float(context.get("ball_size", 28.6)) * 0.5)
	if not _ball_path_hits_aircraft(previous_ball_pos, ball_pos, ball_radius):
		return false

	if not shoot_down_aircraft(deps, "ball"):
		return false
	var ball_vel: Vector2 = _get_vector2(scene.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
	if abs(ball_vel.y) <= 0.001:
		ball_vel.y = 4.0
	else:
		ball_vel.y *= -AIRCRAFT_HIT_BALL_Y_DAMPING
	scene["ball_vel"] = ball_vel
	scene["commando_supply_aircraft_hit"] = true
	return true


func resolve_obstacle_collision(context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	if not _can_aircraft_hit_obstacles():
		return {}
	var aircraft_rect: Rect2 = get_aircraft_collision_rect()
	if _player_paddle_hits_aircraft(aircraft_rect, context):
		if shoot_down_aircraft(deps, "player_paddle"):
			return {
				"aircraft_collision": true,
				"source": "player_paddle",
				"aircraft_crashing": true,
			}
		return {}

	var brick_hit: Dictionary = _find_aircraft_brick_hit(aircraft_rect, context)
	if not brick_hit.is_empty():
		if shoot_down_aircraft(deps, "brick_wall"):
			return {
				"aircraft_collision": true,
				"source": "brick_wall",
				"wall_index": int(brick_hit.get("wall_index", -1)),
				"impact_pos": _get_vector2(brick_hit.get("impact_pos", aircraft_pos), aircraft_pos),
				"aircraft_crashing": true,
			}
	return {}


func shoot_down_aircraft(deps: Dictionary = {}, source: String = "unknown") -> bool:
	if not active or not aircraft_spawned or aircraft_crashing or aircraft_exploded:
		return false
	active = false
	timer = 0.0
	aircraft_spawned = false
	pending_drop.clear()
	pending_drops.clear()
	pending_drop_delays.clear()
	aircraft_crashing = true
	aircraft_exploded = false
	aircraft_crash_source = source
	aircraft_crash_elapsed = 0.0
	aircraft_crash_timer = AIRCRAFT_CRASH_SECONDS
	aircraft_crash_rotation = 0.0
	aircraft_crash_start_pos = aircraft_pos
	var drift_sign := 1.0 if aircraft_direction != "right_to_left" else -1.0
	aircraft_crash_target_pos = Vector2(
		clamp(aircraft_pos.x + AIRCRAFT_CRASH_DRIFT_X * drift_sign, 42.0, 718.0),
		AIRCRAFT_CRASH_GROUND_Y
	)
	_stop_aircraft_audio(deps)
	_spawn_aircraft_hit_effects(aircraft_pos)
	return true


func _can_hold_for_activation(
	special_gauge: float,
	skill_config: Object,
	skill_state: Object,
	deps: Dictionary,
	current_msec: int
) -> bool:
	return (
		_can_accept_supply_hold(deps, current_msec)
		and _is_supply_drop_activation_ready(special_gauge, skill_config, skill_state, deps, current_msec)
	)


func _can_accept_supply_hold(deps: Dictionary, current_msec: int) -> bool:
	if not _is_commando_selected(deps):
		return false
	if _is_original_skill_blocked(deps):
		return false
	if _is_transform_skill_blocked(deps):
		return false
	if _is_emergency_supply_suppressing(deps, current_msec):
		return false
	return true


func _is_supply_drop_activation_ready(
	special_gauge: float,
	skill_config: Object,
	skill_state: Object,
	deps: Dictionary,
	current_msec: int
) -> bool:
	if not _is_round_state_allowing_supply_drop(deps, current_msec):
		return false
	return _can_activate(special_gauge, skill_config, skill_state, current_msec)


func _accumulate_pending_hold(delta: float, _deps: Dictionary) -> void:
	pending_hold_time = min(HOLD_REQUIRED_SECONDS, max(pending_hold_time, hold_time) + max(0.0, delta))
	hold_time = 0.0
	_release_hold_radio_audio_gate()


func _can_activate(special_gauge: float, skill_config: Object, skill_state: Object, current_msec: int) -> bool:
	var cost := 350.0
	var cooldown := 40.0
	if skill_config != null:
		if skill_config.has_method("get_skill_cost"):
			cost = float(skill_config.get_skill_cost("supply_drop"))
		if skill_config.has_method("get_cooldown_seconds"):
			cooldown = float(skill_config.get_cooldown_seconds("supply_drop"))
	if special_gauge < cost:
		return false
	if skill_state != null and skill_state.has_method("get_cooldown_remaining"):
		return float(skill_state.get_cooldown_remaining("supply_drop", current_msec, cooldown)) <= 0.0
	return true


func _is_supply_drop_hold_pressed(input_snapshot: Dictionary) -> bool:
	return (
		bool(input_snapshot.get("down_pressed", false))
		or bool(input_snapshot.get("supply_drop_hold_pressed", false))
		or bool(input_snapshot.get("commando_supply_drop_hold_pressed", false))
	)


func _is_commando_selected(deps: Dictionary) -> bool:
	if not deps.has("selected_character_type"):
		return true
	var character_type: String = str(deps.get("selected_character_type", "")).strip_edges().to_lower()
	return character_type == "soldier" or character_type == "commando"


func _is_original_skill_blocked(deps: Dictionary) -> bool:
	for key in [
		"commando_original_skills_blocked",
		"soldier_original_skills_blocked",
		"original_skills_blocked",
		"character_original_skills_blocked",
		"commando_skills_blocked",
		"character_skills_blocked",
	]:
		if bool(deps.get(key, false)):
			return true
	return false


func _is_transform_skill_blocked(deps: Dictionary) -> bool:
	for key in [
		"odins_eye_transformed",
		"horn_strawberry_transformed",
		"commando_transformed",
		"character_transformed",
		"original_skill_transform_active",
	]:
		if bool(deps.get(key, false)):
			return true
	for source_key in ["mythic_item_runtime", "legendary_item_runtime", "active_item_runtime"]:
		var source: Object = deps.get(source_key, null)
		if _object_reports_any_true(source, [
			"is_odins_eye_transformed",
			"is_horn_strawberry_transformed",
			"is_original_skill_transform_active",
		]):
			return true
	return false


func _is_emergency_supply_suppressing(deps: Dictionary, current_msec: int) -> bool:
	var emergency_state: Object = deps.get("commando_emergency_supply_state", null)
	if emergency_state == null:
		return false
	if emergency_state.has_method("is_supply_drop_hold_suppressed"):
		return bool(emergency_state.is_supply_drop_hold_suppressed(current_msec))
	if emergency_state.has_method("get_snapshot"):
		var snapshot: Dictionary = _get_dictionary(emergency_state.get_snapshot())
		return current_msec < int(snapshot.get("suppress_until_msec", 0))
	return false


func _is_round_state_allowing_supply_drop(deps: Dictionary, current_msec: int) -> bool:
	if bool(deps.get("commando_supply_drop_ignore_round_gate", false)):
		return true
	var round_state: Object = deps.get("round_state", null)
	if round_state == null:
		return true
	var waiting_for_serve := false
	if round_state.has_method("is_waiting_for_serve"):
		waiting_for_serve = bool(round_state.is_waiting_for_serve())
	var player_serves := false
	if round_state.has_method("does_player_serve"):
		player_serves = bool(round_state.does_player_serve())
	var snapshot: Dictionary = _get_round_snapshot(round_state)
	if waiting_for_serve:
		if not player_serves:
			return false
		return float(snapshot.get("serve_timer", 0.0)) >= PLAYER_SERVE_HOLD_ALLOWED_SECONDS

	var lock_seconds: float = max(0.0, float(deps.get("commando_supply_drop_post_serve_lock_seconds", POST_SERVE_HOLD_LOCK_SECONDS)))
	if lock_seconds <= 0.0:
		return true
	var round_start_msec: int = _get_round_start_msec(round_state, snapshot)
	if round_start_msec <= 0:
		return true
	return float(max(0, current_msec - round_start_msec)) >= lock_seconds * 1000.0


func _get_round_snapshot(round_state: Object) -> Dictionary:
	if round_state != null and round_state.has_method("get_snapshot"):
		return _get_dictionary(round_state.get_snapshot())
	return {}


func _get_round_start_msec(round_state: Object, snapshot: Dictionary) -> int:
	if round_state != null and round_state.has_method("get_round_start_time_msec"):
		return int(round_state.get_round_start_time_msec())
	return int(snapshot.get("round_start_time_msec", 0))


func _get_current_msec(deps: Dictionary) -> int:
	return int(deps.get("current_msec", Time.get_ticks_msec()))


func _cache_hold_gauge_anchor(deps: Dictionary) -> void:
	var context_value: Variant = deps.get("commando_supply_drop_collision_context", {})
	if not (context_value is Dictionary):
		return
	var context: Dictionary = context_value
	hold_gauge_player_pos = _get_vector2(context.get("player_pos", hold_gauge_player_pos), hold_gauge_player_pos)
	hold_gauge_player_size = _get_vector2(
		context.get(
			"player_paddle_size",
			Vector2(
				float(context.get("paddle_width", hold_gauge_player_size.x)),
				float(context.get("paddle_height", hold_gauge_player_size.y))
			)
		),
		hold_gauge_player_size
	)


func _sync_hold_feedback(deps: Dictionary) -> void:
	if not _is_hold_gauge_visible():
		return
	radio_motion = true
	radio_timer = max(radio_timer, radio_duration)
	_start_hold_radio_audio(deps)


func _is_hold_gauge_visible() -> bool:
	return not active and hold_time >= HOLD_GAUGE_THRESHOLD_SECONDS


func _get_hold_gauge_progress() -> float:
	if hold_time < HOLD_GAUGE_THRESHOLD_SECONDS:
		return 0.0
	var denom: float = max(0.001, HOLD_REQUIRED_SECONDS - HOLD_GAUGE_THRESHOLD_SECONDS)
	return clamp((hold_time - HOLD_GAUGE_THRESHOLD_SECONDS) / denom, 0.0, 1.0)


func _get_hold_gauge_rect() -> Rect2:
	var player_center_x: float = hold_gauge_player_pos.x + hold_gauge_player_size.x * 0.5
	var gauge_y: float = hold_gauge_player_pos.y - HOLD_GAUGE_TOP_OFFSET
	return Rect2(
		Vector2(player_center_x - HOLD_GAUGE_WIDTH * 0.5, gauge_y),
		Vector2(HOLD_GAUGE_WIDTH, HOLD_GAUGE_HEIGHT)
	)


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func _object_reports_any_true(source: Object, method_names: Array) -> bool:
	if source == null:
		return false
	for method_name in method_names:
		var callable_name := str(method_name)
		if source.has_method(callable_name) and bool(source.call(callable_name)):
			return true
	return false


func _build_pending_drops(deps: Dictionary) -> Array[Dictionary]:
	return CommandoSupplyDropPayloadResolver.build_pending_drops(deps)


func _get_payload_count(deps: Dictionary) -> int:
	return CommandoSupplyDropPayloadResolver.get_payload_count(deps)


func _build_pending_drop_delays(deps: Dictionary, payload_count: int, timing_pattern: String) -> Array[float]:
	return CommandoSupplyDropPayloadResolver.build_pending_drop_delays(deps, payload_count, timing_pattern)


func _normalize_configured_drop_delays(configured_delays: Array, payload_count: int) -> Array[float]:
	return CommandoSupplyDropPayloadResolver.normalize_configured_drop_delays(configured_delays, payload_count)


func _build_python_drop_delay_schedule(timing_pattern: String, payload_count: int) -> Array[float]:
	return CommandoSupplyDropPayloadResolver.build_python_drop_delay_schedule(timing_pattern, payload_count)


func _get_python_normal_next_drop_frames() -> int:
	return CommandoSupplyDropPayloadResolver.get_python_normal_next_drop_frames()


func _get_drop_timing_pattern(deps: Dictionary) -> String:
	return CommandoSupplyDropPayloadResolver.get_drop_timing_pattern(deps)


func _normalize_drop_timing_pattern(value: String) -> String:
	return CommandoSupplyDropPayloadResolver.normalize_drop_timing_pattern(value)


func _build_pending_drop(deps: Dictionary, reserved_weapons: Dictionary = {}, payload_index: int = 0) -> Dictionary:
	return CommandoSupplyDropPayloadResolver.build_pending_drop(deps, reserved_weapons, payload_index)


func _build_weighted_drop_candidates(deps: Dictionary, reserved_weapons: Dictionary) -> Array[Dictionary]:
	return CommandoSupplyDropPayloadResolver.build_weighted_drop_candidates(deps, reserved_weapons)


func _get_field_item_drop_candidates(deps: Dictionary) -> Array[Dictionary]:
	return CommandoSupplyDropPayloadResolver.get_field_item_drop_candidates(deps)


func _is_field_item_candidate_available(item_id: String, _deps: Dictionary) -> bool:
	return CommandoSupplyDropPayloadResolver.is_field_item_candidate_available(item_id, _deps)


func _has_any_permanent_weapon(deps: Dictionary) -> bool:
	return CommandoSupplyDropPayloadResolver.has_any_permanent_weapon(deps)


func _get_permanent_owned_from_deps(deps: Dictionary) -> Dictionary:
	return CommandoSupplyDropPayloadResolver.get_permanent_owned_from_deps(deps)


func _get_forced_pending_drop(deps: Dictionary, payload_index: int) -> Dictionary:
	return CommandoSupplyDropPayloadResolver.get_forced_pending_drop(deps, payload_index)


func _get_payload_roll(deps: Dictionary, payload_index: int) -> float:
	return CommandoSupplyDropPayloadResolver.get_payload_roll(deps, payload_index)


func _reserve_drop_weapon(drop: Dictionary, reserved_weapons: Dictionary) -> void:
	CommandoSupplyDropPayloadResolver.reserve_drop_weapon(drop, reserved_weapons)


func _resolve_ready_drops(deps: Dictionary) -> Dictionary:
	if aircraft_crashing or aircraft_exploded:
		return {}
	var resolved_drops: Array[Dictionary] = []
	while timer <= 0.0 and not pending_drops.is_empty():
		resolved_drops.append(_resolve_next_drop(deps))
		if pending_drops.is_empty():
			break
		timer += _peek_next_drop_delay()
	if pending_drops.is_empty():
		pending_drop.clear()
	else:
		pending_drop = pending_drops[0].duplicate(true)
	if resolved_drops.is_empty():
		return {}
	return {
		"drop_resolved": true,
		"drop": resolved_drops[0],
		"drops": resolved_drops,
		"pending_payloads": pending_drops.size(),
	}


func _resolve_next_drop(deps: Dictionary) -> Dictionary:
	var drop_value: Variant = pending_drops.pop_front()
	if not pending_drop_delays.is_empty():
		pending_drop_delays.pop_front()
	var drop: Dictionary = drop_value.duplicate(true) if drop_value is Dictionary else {}
	var drop_position: Vector2 = _get_payload_spawn_position(deps)
	drop["drop_position"] = drop_position
	drop["collectible_pending"] = true
	drop["drop_spawned"] = true
	_spawn_collectible_drop(drop)
	_spawn_drop_effect(drop)
	_play_audio_method(deps, "play_commando_supply_drop")
	pending_drop = pending_drops[0].duplicate(true) if not pending_drops.is_empty() else {}
	return drop


func _peek_next_drop_delay() -> float:
	if pending_drop_delays.is_empty():
		return PAYLOAD_INTERVAL_SECONDS
	return max(0.0, float(pending_drop_delays[0]))


func _spawn_field_item(item_id: String, deps: Dictionary, position: Vector2) -> bool:
	if item_id == "":
		return false
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if active_item_runtime != null:
		if active_item_runtime.has_method("spawn_field_item"):
			return bool(active_item_runtime.spawn_field_item(item_id, position))
		var field_spawn_controller_value: Variant = active_item_runtime.get("field_spawn_controller")
		if field_spawn_controller_value is Object:
			var field_spawn_controller: Object = field_spawn_controller_value
			if field_spawn_controller.has_method("debug_spawn_item_at"):
				return bool(field_spawn_controller.debug_spawn_item_at(item_id, position))
			if field_spawn_controller.has_method("debug_spawn_item"):
				return bool(field_spawn_controller.debug_spawn_item(item_id))
	var direct_field_spawn: Object = deps.get("active_item_field_spawn_controller", null)
	if direct_field_spawn != null and direct_field_spawn.has_method("debug_spawn_item_at"):
		return bool(direct_field_spawn.debug_spawn_item_at(item_id, position))
	if direct_field_spawn != null and direct_field_spawn.has_method("debug_spawn_item"):
		return bool(direct_field_spawn.debug_spawn_item(item_id))
	return false


func _spawn_collectible_drop(drop: Dictionary) -> void:
	var drop_position: Vector2 = _get_vector2(drop.get("drop_position", _get_payload_spawn_position()), _get_payload_spawn_position())
	var collectible: Dictionary = drop.duplicate(true)
	var payload_index: int = int(collectible.get("payload_index", collectible_drops.size()))
	collectible["pos"] = drop_position
	collectible["base_x"] = drop_position.x
	collectible["elapsed"] = 0.0
	collectible["sway_phase"] = float(payload_index) * 0.83
	collectible["vy"] = COLLECTIBLE_DROP_FALL_SPEED + float(payload_index) * 8.0
	collectible["rotation"] = 0.0
	collectible["active"] = true
	collectible_drops.append(collectible)


func _update_collectible_drops(delta: float, deps: Dictionary) -> void:
	if collectible_drops.is_empty():
		return
	var play_width: float = max(1.0, float(deps.get("play_width", deps.get("width", DEFAULT_PLAY_WIDTH))))
	var play_height: float = max(1.0, float(deps.get("play_height", deps.get("height", DEFAULT_PLAY_HEIGHT))))
	var next_drops: Array[Dictionary] = []
	for drop in collectible_drops:
		var next_drop: Dictionary = drop.duplicate(true)
		var elapsed: float = float(next_drop.get("elapsed", 0.0)) + delta
		var pos: Vector2 = _get_vector2(next_drop.get("pos", next_drop.get("drop_position", Vector2.ZERO)), Vector2.ZERO)
		var base_x: float = float(next_drop.get("base_x", pos.x))
		var sway_phase: float = float(next_drop.get("sway_phase", 0.0))
		pos.x = clamp(
			base_x + sin(elapsed * COLLECTIBLE_DROP_SWAY_SPEED + sway_phase) * COLLECTIBLE_DROP_SWAY_AMOUNT,
			COLLECTIBLE_DROP_SAFE_MARGIN,
			play_width - COLLECTIBLE_DROP_SAFE_MARGIN
		)
		pos.y += float(next_drop.get("vy", COLLECTIBLE_DROP_FALL_SPEED)) * delta
		next_drop["pos"] = pos
		next_drop["elapsed"] = elapsed
		next_drop["rotation"] = float(next_drop.get("rotation", 0.0)) + delta * 120.0
		if pos.y <= play_height + COLLECTIBLE_DROP_DESPAWN_MARGIN:
			next_drops.append(next_drop)
	collectible_drops = next_drops


func _resolve_collectible_pickups(deps: Dictionary) -> Dictionary:
	if collectible_drops.is_empty():
		return {}
	var context: Dictionary = _get_aircraft_obstacle_context(deps)
	var player_rect: Rect2 = _get_player_paddle_rect(context)
	if player_rect.size.x <= 0.0 or player_rect.size.y <= 0.0:
		return {}

	var next_drops: Array[Dictionary] = []
	var picked_drops: Array[Dictionary] = []
	var rejected_count := 0
	for drop in collectible_drops:
		var next_drop: Dictionary = drop.duplicate(true)
		if not _collectible_drop_hits_player(next_drop, player_rect):
			next_drops.append(next_drop)
			continue
		var collect_result: Dictionary = _collect_drop(next_drop, deps)
		if bool(collect_result.get("keep_collectible", false)):
			rejected_count += 1
			next_drops.append(next_drop)
			continue
		var picked_drop: Dictionary = next_drop.duplicate(true)
		picked_drop.merge(collect_result, true)
		picked_drops.append(picked_drop)
	collectible_drops = next_drops

	if picked_drops.is_empty() and rejected_count <= 0:
		return {}
	var result := {
		"pickup_resolved": not picked_drops.is_empty(),
		"picked_drops": picked_drops,
		"collectible_count": collectible_drops.size(),
	}
	if not picked_drops.is_empty():
		result["picked_drop"] = picked_drops[0]
	if rejected_count > 0:
		result["pickup_rejected"] = true
		result["rejected_pickups"] = rejected_count
	return result


func _collect_drop(drop: Dictionary, deps: Dictionary) -> Dictionary:
	var drop_type: String = str(drop.get("type", ""))
	if drop_type == "rental_weapon":
		var weapon_id: String = str(drop.get("weapon_id", ""))
		var granted := false
		var weapon_controller: Object = deps.get("commando_weapon_controller", null)
		if weapon_controller != null and weapon_controller.has_method("add_rental_weapon"):
			var stage: int = int(deps.get("current_stage", 1))
			granted = bool(weapon_controller.add_rental_weapon(weapon_id, stage, -1, true, true))
		if granted:
			_play_audio_method(deps, "play_commando_weapon_change")
		_play_first_audio_method(deps, ["play_item_get", "play_commando_supply_drop"])
		return {
			"type": drop_type,
			"weapon_id": weapon_id,
			"rental_granted": granted,
		}
	if drop_type == "field_item":
		return _collect_field_item_drop(drop, deps)
	return {
		"type": drop_type,
		"unknown_drop": true,
	}


func _collect_field_item_drop(drop: Dictionary, deps: Dictionary) -> Dictionary:
	var item_id: String = str(drop.get("item_id", ""))
	if item_id == "":
		return {
			"type": "field_item",
			"field_item_collected": false,
		}
	var pos: Vector2 = _get_vector2(drop.get("pos", drop.get("drop_position", Vector2.ZERO)), Vector2.ZERO)
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	var owner: Object = deps.get("owner", null)
	var registry: Object = deps.get("registry", null)
	if active_item_runtime != null and owner != null:
		if active_item_runtime.has_method("collect_item_by_name"):
			var collected: bool = bool(active_item_runtime.collect_item_by_name(item_id, pos, owner, registry))
			if collected:
				return {
					"type": "field_item",
					"item_id": item_id,
					"field_item_collected": true,
				}
			return {
				"type": "field_item",
				"item_id": item_id,
				"field_item_collected": false,
				"pickup_rejected": true,
				"keep_collectible": true,
			}
		if active_item_runtime.has_method("grant_item_to_slot"):
			var granted: bool = bool(active_item_runtime.grant_item_to_slot(item_id, owner, registry, false))
			if granted:
				_play_first_audio_method(deps, ["play_item_get", "play_commando_supply_drop"])
				return {
					"type": "field_item",
					"item_id": item_id,
					"field_item_collected": true,
				}
			return {
				"type": "field_item",
				"item_id": item_id,
				"field_item_collected": false,
				"pickup_rejected": true,
				"keep_collectible": true,
			}
	var spawned: bool = _spawn_field_item(item_id, deps, pos)
	return {
		"type": "field_item",
		"item_id": item_id,
		"field_item_collected": false,
		"field_item_spawned": spawned,
		"keep_collectible": not spawned,
	}


func _collectible_drop_hits_player(drop: Dictionary, player_rect: Rect2) -> bool:
	return player_rect.intersects(_get_collectible_drop_rect(drop))


func _get_collectible_drop_rect(drop: Dictionary) -> Rect2:
	var pos: Vector2 = _get_vector2(drop.get("pos", drop.get("drop_position", Vector2.ZERO)), Vector2.ZERO)
	return Rect2(pos - COLLECTIBLE_DROP_BOX_SIZE * 0.5, COLLECTIBLE_DROP_BOX_SIZE)


func _merge_update_results(result: Dictionary, pickup_result: Dictionary) -> Dictionary:
	if result.is_empty():
		return pickup_result
	if pickup_result.is_empty():
		return result
	var merged: Dictionary = result.duplicate(true)
	for key in pickup_result.keys():
		merged[key] = pickup_result[key]
	return merged


func _dict_has_key(value: Variant, key: String) -> bool:
	return value is Dictionary and (value as Dictionary).has(key)


func _start_hold_radio_audio(deps: Dictionary) -> void:
	if hold_radio_audio_active:
		return
	hold_radio_audio_active = true
	_play_first_audio_method(deps, ["play_commando_supply_radio_loop", "play_commando_supply_radio"])


func _release_hold_radio_audio_gate() -> void:
	# Python parity (supply_drop.py): a started radio sample always plays to
	# its natural end; this only re-arms the one-playback-per-hold-session
	# gate. Use _stop_hold_radio_audio for round / battle force-stops.
	hold_radio_audio_active = false


func _stop_hold_radio_audio(deps: Dictionary) -> void:
	# Force-stop (Python stop_radio_loop force=True): cuts the channel even
	# when the playback gate was already released, so a still-playing sample
	# never leaks across round / save-load boundaries.
	hold_radio_audio_active = false
	_play_audio_method(deps, "stop_commando_supply_radio_loop")


func _stop_aircraft_audio(deps: Dictionary) -> void:
	if not aircraft_audio_active:
		return
	aircraft_audio_active = false
	_play_audio_method(deps, "stop_commando_supply_aircraft_loop")


func _play_audio_method(deps: Dictionary, method_name: String) -> void:
	var audio: Object = deps.get("audio", deps.get("game_audio", null))
	if audio == null or not audio.has_method(method_name):
		return
	audio.call(method_name)


func _play_first_audio_method(deps: Dictionary, method_names: Array[String]) -> void:
	var audio: Object = deps.get("audio", deps.get("game_audio", null))
	if audio == null:
		return
	for method_name in method_names:
		if audio.has_method(method_name):
			audio.call(method_name)
			return


func _get_aircraft_arrival_delay(deps: Dictionary) -> float:
	if deps.has("commando_supply_drop_aircraft_arrival_delay"):
		return max(0.0, float(deps.get("commando_supply_drop_aircraft_arrival_delay", 0.0)))
	if deps.has("commando_supply_drop_aircraft_arrival_delay_frames"):
		return max(0.0, float(deps.get("commando_supply_drop_aircraft_arrival_delay_frames", 0.0))) * FRAME_SECONDS
	return float(randi_range(PYTHON_AIRCRAFT_ARRIVAL_MIN_FRAMES, PYTHON_AIRCRAFT_ARRIVAL_MAX_FRAMES)) * FRAME_SECONDS


func _get_aircraft_direction(deps: Dictionary) -> String:
	var configured_direction := str(deps.get("commando_supply_drop_direction", ""))
	if configured_direction == "left_to_right" or configured_direction == "right_to_left":
		return configured_direction
	return "left_to_right" if randi_range(0, 1) == 0 else "right_to_left"


func _update_aircraft_arrival(delta: float, deps: Dictionary) -> Dictionary:
	if aircraft_spawned:
		return {"remaining_delta_after_aircraft_spawn": max(0.0, delta)}
	var safe_delta: float = max(0.0, delta)
	var previous_timer: float = timer
	timer = max(0.0, timer - safe_delta)
	if previous_timer > safe_delta:
		return {
			"aircraft_pending": true,
			"aircraft_arrival_timer": timer,
		}
	var remaining_delta: float = max(0.0, safe_delta - previous_timer)
	_spawn_aircraft(deps)
	return {
		"aircraft_spawned": true,
		"remaining_delta_after_aircraft_spawn": remaining_delta,
	}


func _spawn_aircraft(deps: Dictionary) -> void:
	if aircraft_spawned or not active:
		return
	aircraft_spawned = true
	flight_elapsed = 0.0
	flight_duration = _get_aircraft_travel_duration()
	timer = _peek_next_drop_delay()
	_update_aircraft_visual()
	if not aircraft_audio_active:
		aircraft_audio_active = true
		_play_audio_method(deps, "play_commando_supply_aircraft_loop")


func _get_aircraft_start_pos() -> Vector2:
	var start_x := AIRCRAFT_START_X
	if aircraft_direction == "right_to_left":
		start_x = AIRCRAFT_END_X
	return Vector2(start_x, AIRCRAFT_ALTITUDE_Y)


func _update_aircraft_visual() -> void:
	var progress: float = clamp(flight_elapsed / max(0.001, _get_aircraft_travel_duration()), 0.0, 1.0)
	var start_x := AIRCRAFT_START_X
	var end_x := AIRCRAFT_END_X
	if aircraft_direction == "right_to_left":
		start_x = AIRCRAFT_END_X
		end_x = AIRCRAFT_START_X
	aircraft_pos = Vector2(lerpf(start_x, end_x, progress), AIRCRAFT_ALTITUDE_Y)


func _get_aircraft_travel_duration() -> float:
	return absf(AIRCRAFT_END_X - AIRCRAFT_START_X) / max(1.0, AIRCRAFT_SPEED_PIXELS_PER_SECOND)


func _is_aircraft_offscreen() -> bool:
	return flight_elapsed >= _get_aircraft_travel_duration()


func _is_aircraft_over_payload_drop_zone(deps: Dictionary = {}) -> bool:
	var bounds: Vector2 = _get_payload_drop_gate_bounds(deps)
	var payload_x: float = aircraft_pos.x + PAYLOAD_SPAWN_OFFSET.x
	return payload_x >= bounds.x and payload_x <= bounds.y


func _get_payload_drop_timer_delta(previous_elapsed: float, current_elapsed: float, deps: Dictionary = {}) -> float:
	var window: Vector2 = _get_payload_drop_zone_elapsed_window(deps)
	var start_elapsed: float = max(previous_elapsed, window.x)
	var end_elapsed: float = min(current_elapsed, window.y)
	return max(0.0, end_elapsed - start_elapsed)


func _get_payload_drop_zone_elapsed_window(deps: Dictionary = {}) -> Vector2:
	var bounds: Vector2 = _get_payload_drop_gate_bounds(deps)
	var enter_elapsed := 0.0
	var exit_elapsed := 0.0
	var speed: float = max(1.0, AIRCRAFT_SPEED_PIXELS_PER_SECOND)
	if aircraft_direction == "right_to_left":
		enter_elapsed = (AIRCRAFT_END_X - (bounds.y - PAYLOAD_SPAWN_OFFSET.x)) / speed
		exit_elapsed = (AIRCRAFT_END_X - (bounds.x - PAYLOAD_SPAWN_OFFSET.x)) / speed
	else:
		enter_elapsed = ((bounds.x - PAYLOAD_SPAWN_OFFSET.x) - AIRCRAFT_START_X) / speed
		exit_elapsed = ((bounds.y - PAYLOAD_SPAWN_OFFSET.x) - AIRCRAFT_START_X) / speed
	var travel_duration: float = _get_aircraft_travel_duration()
	enter_elapsed = clamp(enter_elapsed, 0.0, travel_duration)
	exit_elapsed = clamp(exit_elapsed, 0.0, travel_duration)
	if exit_elapsed < enter_elapsed:
		return Vector2(enter_elapsed, enter_elapsed)
	return Vector2(enter_elapsed, exit_elapsed)


func _get_payload_drop_gate_bounds(deps: Dictionary = {}) -> Vector2:
	var play_width: float = max(1.0, float(deps.get("play_width", deps.get("width", DEFAULT_PLAY_WIDTH))))
	var min_x: float = clamp(float(deps.get("commando_supply_drop_aircraft_center_min_x", 0.0)), 0.0, play_width)
	var max_x: float = clamp(float(deps.get("commando_supply_drop_aircraft_center_max_x", play_width)), 0.0, play_width)
	if max_x < min_x:
		var center_x: float = play_width * 0.5
		return Vector2(center_x, center_x)
	return Vector2(min_x, max_x)


func _complete_aircraft_flight(deps: Dictionary) -> void:
	active = false
	timer = 0.0
	aircraft_spawned = false
	pending_drop.clear()
	pending_drops.clear()
	pending_drop_delays.clear()
	_stop_aircraft_audio(deps)


func _resolve_aircraft_obstacle_collision_from_deps(deps: Dictionary) -> Dictionary:
	return resolve_obstacle_collision(_get_aircraft_obstacle_context(deps), deps)


func _get_aircraft_obstacle_context(deps: Dictionary) -> Dictionary:
	var context_value: Variant = deps.get("commando_supply_drop_collision_context", {})
	var context: Dictionary = context_value.duplicate(true) if context_value is Dictionary else {}
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if active_item_runtime != null and active_item_runtime.has_method("get_ball_collision_context"):
		var active_item_context: Dictionary = active_item_runtime.get_ball_collision_context()
		if not active_item_context.is_empty():
			context.merge(active_item_context, true)
	return context


func _can_aircraft_hit_obstacles() -> bool:
	return active and aircraft_spawned and not aircraft_crashing and not aircraft_exploded and flight_elapsed >= AIRCRAFT_INVULNERABLE_SECONDS


func _player_paddle_hits_aircraft(aircraft_rect: Rect2, context: Dictionary) -> bool:
	var player_rect: Rect2 = _get_player_paddle_rect(context)
	return player_rect.size.x > 0.0 and player_rect.size.y > 0.0 and aircraft_rect.intersects(player_rect)


func _get_player_paddle_rect(context: Dictionary) -> Rect2:
	if context.has("player_paddle_rect"):
		return _get_rect2(context.get("player_paddle_rect", Rect2()), Rect2())
	var player_pos: Vector2 = _get_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO)
	var player_size: Vector2 = _get_vector2(
		context.get("player_paddle_size", Vector2.ZERO),
		Vector2(
			float(context.get("paddle_width", 0.0)),
			float(context.get("paddle_height", 0.0))
		)
	)
	if player_size.x <= 0.0 or player_size.y <= 0.0:
		return Rect2()
	var hitbox_padding: float = float(context.get("hitbox_padding", AIRCRAFT_DEFAULT_HITBOX_PADDING))
	var player_rect := Rect2(
		player_pos.x - hitbox_padding,
		player_pos.y - hitbox_padding,
		player_size.x + hitbox_padding * 2.0,
		player_size.y + hitbox_padding * 2.0
	)
	if bool(context.get("dash_acceleration_active", false)):
		var height_bonus: float = max(0.0, float(context.get("dash_acceleration_height_bonus", 0.0)))
		player_rect.position.y -= height_bonus * 0.5
		player_rect.size.y += height_bonus
	return player_rect


func _find_aircraft_brick_hit(aircraft_rect: Rect2, context: Dictionary) -> Dictionary:
	var walls: Array = context.get("brick_walls", [])
	if walls.is_empty():
		return {}
	for i in range(walls.size()):
		var wall_value: Variant = walls[i]
		var wall_rect := Rect2()
		if wall_value is Dictionary:
			wall_rect = _get_rect2((wall_value as Dictionary).get("rect", Rect2()), Rect2())
		elif wall_value is Rect2:
			wall_rect = wall_value
		if wall_rect.size.x <= 0.0 or wall_rect.size.y <= 0.0:
			continue
		if not wall_rect.intersects(aircraft_rect):
			continue
		return {
			"wall_index": i,
			"impact_pos": aircraft_rect.get_center().lerp(wall_rect.get_center(), 0.5),
		}
	return {}


func _get_rect2(value: Variant, fallback: Rect2) -> Rect2:
	return value if value is Rect2 else fallback


func _duplicate_dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _duplicate_dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (value is Array):
		return result
	for entry in value:
		if entry is Dictionary:
			result.append((entry as Dictionary).duplicate(true))
	return result


func _duplicate_float_array(value: Variant) -> Array[float]:
	var result: Array[float] = []
	if not (value is Array):
		return result
	for entry in value:
		result.append(max(0.0, float(entry)))
	return result


func _update_aircraft_crash(delta: float, deps: Dictionary) -> Dictionary:
	var safe_delta: float = max(0.0, delta)
	aircraft_crash_elapsed += safe_delta
	aircraft_crash_timer = max(0.0, AIRCRAFT_CRASH_SECONDS - aircraft_crash_elapsed)
	var progress: float = clamp(aircraft_crash_elapsed / max(0.001, AIRCRAFT_CRASH_SECONDS), 0.0, 1.0)
	var eased := progress * progress
	aircraft_pos = aircraft_crash_start_pos.lerp(aircraft_crash_target_pos, eased)
	var rotation_sign := 1.0 if aircraft_direction != "right_to_left" else -1.0
	aircraft_crash_rotation = rotation_sign * lerpf(0.0, PI * 1.15, progress)
	if safe_delta > 0.0:
		_spawn_aircraft_smoke_effect(aircraft_pos)
	if progress >= 1.0:
		_finish_aircraft_crash(deps)
		return {"aircraft_exploded": true}
	return {"aircraft_crashing": true}


func _finish_aircraft_crash(deps: Dictionary) -> void:
	if not aircraft_crashing:
		return
	aircraft_crashing = false
	aircraft_exploded = true
	aircraft_crash_timer = 0.0
	aircraft_crash_elapsed = AIRCRAFT_CRASH_SECONDS
	_spawn_aircraft_explosion_effects(aircraft_pos)
	_apply_crash_impact_screen_shake(deps)
	_arm_crash_ball_impulse(aircraft_pos)
	crash_blast_timer = AIRCRAFT_CRASH_BLAST_SECONDS
	crash_blast_center = aircraft_pos
	_crash_blast_player_knocked = false
	# Explosion-instant shove for a paddle already parked inside the radius; the
	# per-frame blast tick in update() covers later walk-ins.
	_try_apply_crash_blast_player_knockback(deps)
	_stop_aircraft_audio(deps)
	_play_first_audio_method(deps, ["play_grenade_explosion", "play_commando_supply_drop"])


func _apply_crash_impact_screen_shake(deps: Dictionary) -> void:
	var feedback: Object = deps.get("feedback", null)
	if feedback == null or not feedback.has_method("max_screen_shake"):
		return
	feedback.max_screen_shake(AIRCRAFT_CRASH_IMPACT_SHAKE_AMOUNT, AIRCRAFT_CRASH_IMPACT_SHAKE_INTENSITY)


func _arm_crash_ball_impulse(center: Vector2) -> void:
	_pending_crash_ball_impulse = true
	_crash_ball_impulse_center = center


func _try_apply_crash_blast_player_knockback(deps: Dictionary) -> void:
	if _crash_blast_player_knocked or crash_blast_timer <= 0.0:
		return
	var context: Dictionary = _get_aircraft_obstacle_context(deps)
	var player_rect: Rect2 = _get_player_paddle_rect(context)
	if player_rect.size.x <= 0.0 or player_rect.size.y <= 0.0:
		return
	# Closest-point distance so grazing the blast edge with the paddle tip counts.
	var closest := Vector2(
		clamp(crash_blast_center.x, player_rect.position.x, player_rect.end.x),
		clamp(crash_blast_center.y, player_rect.position.y, player_rect.end.y)
	)
	if closest.distance_to(crash_blast_center) > AIRCRAFT_CRASH_KNOCKBACK_RADIUS:
		return
	var movement_state: Object = _get_player_movement_state(deps)
	if movement_state == null or not movement_state.has_method("start_knockback"):
		return
	# One-shot per blast: shove once, don't force-field the paddle for the
	# whole window (bomb-surprise player knockback precedent).
	_crash_blast_player_knocked = true
	var dx: float = player_rect.get_center().x - crash_blast_center.x
	var direction: float = signf(dx)
	if absf(dx) < 1.0:
		direction = 1.0 if aircraft_direction != "right_to_left" else -1.0
	movement_state.start_knockback(
		direction * AIRCRAFT_CRASH_PLAYER_KNOCKBACK_VELOCITY,
		AIRCRAFT_CRASH_PLAYER_KNOCKBACK_FRAMES,
		AIRCRAFT_CRASH_PLAYER_KNOCKBACK_DECAY,
		true,
		true
	)


func _get_player_movement_state(deps: Dictionary) -> Object:
	var movement_state: Object = deps.get("movement_state", null)
	if movement_state != null:
		return movement_state
	var registry: Object = deps.get("registry", null)
	if registry == null:
		return null
	# Non-instantiating peek first (hot-path lazy-init trap): the movement state
	# always exists mid-battle, so a peek miss just means "no knockback target".
	if registry.has_method("get_cached_instance"):
		return registry.get_cached_instance("player_movement_state")
	if registry.has_method("get_instance"):
		return registry.get_instance("player_movement_state")
	return null


func _build_crash_blast_zone() -> Dictionary:
	return {
		"active": true,
		"position": crash_blast_center,
		"radius": AIRCRAFT_CRASH_KNOCKBACK_RADIUS,
		"explosion_style": GrenadeExplosionDrawer.FIRE_SUPPORT_EXPLOSION_STYLE,
		"max_duration_frames": AIRCRAFT_CRASH_BLAST_SECONDS * 60.0,
		"duration_frames": crash_blast_timer * 60.0,
	}


func _apply_pending_crash_ball_impulse(scene: Dictionary, _context: Dictionary) -> void:
	if not _pending_crash_ball_impulse:
		return
	# One-shot: consume on the first ball frame after the crash regardless of
	# whether the ball is inside the blast so it can never fire twice.
	_pending_crash_ball_impulse = false
	var ball_pos: Vector2 = _get_vector2(scene.get("ball_pos", Vector2.ZERO), Vector2.ZERO)
	var to_ball: Vector2 = ball_pos - _crash_ball_impulse_center
	var dist: float = to_ball.length()
	if dist > AIRCRAFT_CRASH_KNOCKBACK_RADIUS:
		return
	var falloff: float = 1.0 - dist / max(1.0, AIRCRAFT_CRASH_KNOCKBACK_RADIUS)
	var dir: Vector2 = to_ball / dist if dist > 0.001 else Vector2(0.0, -1.0)
	# Always launch with an upward bias so a blast near the floor can never spike
	# the ball straight down into the player's goal.
	if dir.y > -AIRCRAFT_CRASH_KNOCKBACK_MIN_UP_BIAS:
		dir.y = -AIRCRAFT_CRASH_KNOCKBACK_MIN_UP_BIAS
		dir = dir.normalized()
	var ball_vel: Vector2 = _get_vector2(scene.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
	var new_vel: Vector2 = ball_vel + dir * (AIRCRAFT_CRASH_KNOCKBACK_POWER * falloff)
	# ball_vel is px/frame; never exceed the ceiling, but never slow a ball that
	# is already faster (rally speed-cap bonus) below its own speed.
	var ceiling: float = max(ball_vel.length(), AIRCRAFT_CRASH_KNOCKBACK_SPEED_CEILING)
	if new_vel.length() > ceiling:
		new_vel = new_vel.normalized() * ceiling
	scene["ball_vel"] = new_vel


func _can_aircraft_be_hit(context: Dictionary, deps: Dictionary) -> bool:
	if not active or not aircraft_spawned or aircraft_crashing or aircraft_exploded:
		return false
	if flight_elapsed < AIRCRAFT_INVULNERABLE_SECONDS:
		return false
	var last_hit_by: String = str(context.get("last_hit_by", ""))
	if last_hit_by == "":
		var ball_intensity: Object = deps.get("ball_intensity", null)
		if ball_intensity != null and ball_intensity.has_method("get_last_hit_by"):
			last_hit_by = str(ball_intensity.get_last_hit_by())
	return last_hit_by == "" or last_hit_by == "player"


func _ball_path_hits_aircraft(from_pos: Vector2, to_pos: Vector2, ball_radius: float) -> bool:
	var aircraft_rect: Rect2 = get_aircraft_collision_rect().grow(ball_radius)
	if aircraft_rect.has_point(from_pos) or aircraft_rect.has_point(to_pos):
		return true
	var movement: Vector2 = to_pos - from_pos
	if movement.length_squared() <= 0.001:
		return false
	var top_left := aircraft_rect.position
	var top_right := Vector2(aircraft_rect.end.x, aircraft_rect.position.y)
	var bottom_right := aircraft_rect.end
	var bottom_left := Vector2(aircraft_rect.position.x, aircraft_rect.end.y)
	var edges := [
		[top_left, top_right],
		[top_right, bottom_right],
		[bottom_right, bottom_left],
		[bottom_left, top_left],
	]
	for edge in edges:
		var intersection: Variant = Geometry2D.segment_intersects_segment(from_pos, to_pos, edge[0], edge[1])
		if intersection != null:
			return true
	return false


func _spawn_drop_effect(drop: Dictionary) -> void:
	drop_effects.append({
		"type": str(drop.get("type", "")),
		"item_id": str(drop.get("item_id", drop.get("weapon_id", ""))),
		"life": DROP_EFFECT_SECONDS,
		"duration": DROP_EFFECT_SECONDS,
		"pos": _get_vector2(drop.get("drop_position", _get_payload_spawn_position()), _get_payload_spawn_position()),
		"vy": 84.0,
	})


func _update_drop_effects(delta: float) -> void:
	if drop_effects.is_empty():
		return
	var next_effects: Array[Dictionary] = []
	for effect in drop_effects:
		var next_effect: Dictionary = effect.duplicate(true)
		next_effect["life"] = max(0.0, float(next_effect.get("life", 0.0)) - delta)
		var pos: Vector2 = _get_vector2(next_effect.get("pos", Vector2.ZERO), Vector2.ZERO)
		pos.y += float(next_effect.get("vy", 0.0)) * delta
		next_effect["pos"] = pos
		if float(next_effect.get("life", 0.0)) > 0.0:
			next_effects.append(next_effect)
	drop_effects = next_effects


func _spawn_aircraft_hit_effects(pos: Vector2) -> void:
	for i in range(12):
		var angle: float = TAU * float(i) / 12.0
		var speed: float = 58.0 + float(i % 4) * 12.0
		explosion_effects.append({
			"kind": "spark",
			"pos": pos + Vector2(float((i % 3) - 1) * 5.0, float((i % 2) - 1) * 4.0),
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"radius": 3.5 + float(i % 3),
			"life": 0.34,
			"duration": 0.34,
			"color": Color(1.0, 0.48 + float(i % 2) * 0.22, 0.08, 0.92),
		})
	for i in range(7):
		explosion_effects.append({
			"kind": "smoke",
			"pos": pos + Vector2(float(i - 3) * 5.5, 4.0 + float(i % 2) * 4.0),
			"vel": Vector2(-12.0 + float(i) * 4.0, -28.0 - float(i % 3) * 8.0),
			"radius": 9.0 + float(i % 3) * 2.0,
			"life": 0.72,
			"duration": 0.72,
			"color": Color(0.16, 0.16, 0.14, 0.64),
		})


func _spawn_aircraft_smoke_effect(pos: Vector2) -> void:
	var back_sign := -1.0 if aircraft_direction != "right_to_left" else 1.0
	explosion_effects.append({
		"kind": "smoke",
		"pos": pos + Vector2(24.0 * back_sign, 8.0),
		"vel": Vector2(18.0 * back_sign, -34.0),
		"radius": 11.0,
		"life": 0.62,
		"duration": 0.62,
		"color": Color(0.10, 0.10, 0.09, 0.68),
	})


func _spawn_aircraft_explosion_effects(pos: Vector2) -> void:
	# Debris / spark / smoke motion layers only — the big fireball, overpressure
	# flash, shockwave rings, and mushroom column come from the shared
	# GrenadeExplosionDrawer blast zone drawn while crash_blast_timer runs.
	for i in range(18):
		var angle: float = TAU * float(i) / 18.0
		var speed: float = 84.0 + float(i % 5) * 16.0
		explosion_effects.append({
			"kind": "spark",
			"pos": pos,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"radius": 5.0 + float(i % 4),
			"life": 0.58,
			"duration": 0.58,
			"color": Color(1.0, 0.32 + float(i % 3) * 0.18, 0.04, 0.96),
		})
	for i in range(14):
		var angle: float = TAU * float(i) / 14.0
		explosion_effects.append({
			"kind": "smoke",
			"pos": pos + Vector2(cos(angle), sin(angle)) * 10.0,
			"vel": Vector2(cos(angle) * 38.0, sin(angle) * 20.0 - 42.0),
			"radius": 15.0 + float(i % 4) * 3.0,
			"life": 0.96,
			"duration": 0.96,
			"color": Color(0.12, 0.11, 0.10, 0.72),
		})
	for i in range(10):
		var angle: float = TAU * float(i) / 10.0 + 0.18
		explosion_effects.append({
			"kind": "debris",
			"pos": pos,
			"vel": Vector2(cos(angle) * 74.0, sin(angle) * 48.0 - 22.0),
			"radius": 3.0 + float(i % 2),
			"life": 0.82,
			"duration": 0.82,
			"color": Color(0.21, 0.22, 0.17, 0.95),
		})


func _update_explosion_effects(delta: float) -> void:
	if explosion_effects.is_empty():
		return
	var next_effects: Array[Dictionary] = []
	for effect in explosion_effects:
		var next_effect: Dictionary = effect.duplicate(true)
		next_effect["life"] = max(0.0, float(next_effect.get("life", 0.0)) - delta)
		var pos: Vector2 = _get_vector2(next_effect.get("pos", Vector2.ZERO), Vector2.ZERO)
		var vel: Vector2 = _get_vector2(next_effect.get("vel", Vector2.ZERO), Vector2.ZERO)
		vel.y += 38.0 * delta
		pos += vel * delta
		next_effect["pos"] = pos
		next_effect["vel"] = vel * pow(0.92, delta * 60.0)
		if float(next_effect.get("life", 0.0)) > 0.0:
			next_effects.append(next_effect)
	explosion_effects = next_effects


func _sync_fx_host(
	canvas: CanvasItem,
	shake_offset: Vector2,
	layout_context: Dictionary = {}
) -> void:
	if not _has_supply_vfx_layers():
		_tear_down_fx_host(false)
		return
	var host: Object = _get_or_create_fx_host(canvas)
	if host == null or not host.has_method("sync_state"):
		return
	host.sync_state(get_snapshot(), shake_offset, true, layout_context)


func _get_or_create_fx_host(canvas: CanvasItem) -> Object:
	if canvas == null:
		return null
	if _is_valid_fx_host():
		return fx_host
	if not (canvas is Node):
		return null
	var parent: Node = canvas as Node
	var existing: Node = parent.get_node_or_null("CommandoSupplyDropFxHost")
	if existing != null and is_instance_valid(existing) and not existing.is_queued_for_deletion():
		fx_host = existing
		fx_host_add_pending = false
		return fx_host
	fx_host = CommandoSupplyDropFxHost.new()
	fx_host.name = "CommandoSupplyDropFxHost"
	fx_host.visible = false
	var host_node: Node = fx_host as Node
	if host_node == null:
		return null
	if not fx_host_add_pending:
		fx_host_add_pending = true
		parent.call_deferred("add_child", host_node)
	return fx_host


func _tear_down_fx_host(free_host: bool = false) -> void:
	if not _is_valid_fx_host():
		fx_host = null
		return
	if fx_host.has_method("tear_down"):
		fx_host.tear_down(free_host)
	elif free_host and fx_host is Node:
		(fx_host as Node).queue_free()
	if free_host:
		fx_host = null
		fx_host_add_pending = false


func _is_valid_fx_host() -> bool:
	return fx_host != null and is_instance_valid(fx_host) and fx_host is Node and not (fx_host as Node).is_queued_for_deletion()


func _is_fx_host_visible() -> bool:
	if not _is_valid_fx_host():
		return false
	return bool((fx_host as Node).visible)


func _has_supply_vfx_layers() -> bool:
	return (active and aircraft_spawned) or aircraft_crashing or crash_blast_timer > 0.0 or not drop_effects.is_empty() or not collectible_drops.is_empty() or not explosion_effects.is_empty()


func _draw_hold_gauge(canvas: CanvasItem, shake_offset: Vector2) -> void:
	if not _is_hold_gauge_visible():
		return
	var progress: float = _get_hold_gauge_progress()
	var gauge_rect: Rect2 = _get_hold_gauge_rect()
	gauge_rect.position += shake_offset
	canvas.draw_rect(gauge_rect.grow(2.0), Color(0.0, 0.0, 0.0, 0.70))
	canvas.draw_rect(gauge_rect, Color(0.04, 0.06, 0.06, 0.92))
	canvas.draw_rect(gauge_rect.grow(1.0), Color(1.0, 1.0, 1.0, 0.92), false, 2.0)

	var fill_width: int = int(floor(gauge_rect.size.x * progress))
	if fill_width > 0:
		for index in range(fill_width):
			var ratio: float = float(index) / max(1.0, gauge_rect.size.x)
			var fill_color := Color(1.0 - ratio * 0.20, 200.0 / 255.0 + (55.0 / 255.0) * ratio, 0.0, 0.95)
			var x: float = gauge_rect.position.x + float(index)
			canvas.draw_line(
				Vector2(x, gauge_rect.position.y),
				Vector2(x, gauge_rect.position.y + gauge_rect.size.y - 1.0),
				fill_color,
				1.0
			)

	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var font_size := 13
	var percent_text: String = "%d%%" % int(round(progress * 100.0))
	var text_size: Vector2 = font.get_string_size(percent_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var text_pos := Vector2(
		gauge_rect.get_center().x - text_size.x * 0.5,
		gauge_rect.position.y + (gauge_rect.size.y - text_size.y) * 0.5 + font.get_ascent(font_size)
	)
	canvas.draw_string_outline(font, text_pos, percent_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 1, Color.BLACK)
	canvas.draw_string(font, text_pos, percent_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color.WHITE)


func _draw_supply_texture_layers(canvas: CanvasItem, shake_offset: Vector2) -> void:
	for effect in explosion_effects:
		_draw_explosion_texture_layer(canvas, effect, shake_offset)
	if active and aircraft_spawned:
		_draw_aircraft_texture_layer(canvas, aircraft_pos + shake_offset, aircraft_direction, 0.0, false)
	elif aircraft_crashing:
		_draw_aircraft_texture_layer(canvas, aircraft_pos + shake_offset, aircraft_direction, aircraft_crash_rotation, true)
	for effect in drop_effects:
		_draw_parachute_texture_layer(canvas, effect, shake_offset, true)
	for drop in collectible_drops:
		_draw_parachute_texture_layer(canvas, drop, shake_offset, false)


func _draw_aircraft_texture_layer(
	canvas: CanvasItem,
	pos: Vector2,
	direction: String,
	rotation: float,
	crashing: bool
) -> void:
	var nose_sign := 1.0 if direction != "right_to_left" else -1.0
	var core_color := Color(0.52, 0.82, 1.0, 1.0)
	var warn_color := Color(1.0, 0.62, 0.20, 1.0) if crashing else Color(1.0, 0.78, 0.32, 1.0)
	var tail_pos := _aircraft_point(pos, -48.0, 8.0, nose_sign, rotation)
	var cockpit_pos := _aircraft_point(pos, 14.0, 5.0, nose_sign, rotation)
	ImpactFlareTextureCache.draw_glow(canvas, tail_pos, 58.0 if crashing else 44.0, warn_color, 0.12 if crashing else 0.07)
	ImpactShockwaveTextureCache.draw_full_ring(canvas, pos, 58.0 if crashing else 46.0, core_color, 0.09 if crashing else 0.07)
	ImpactFlareTextureCache.draw_sparkle(canvas, cockpit_pos, 26.0, core_color, 0.12)


func _draw_parachute_texture_layer(canvas: CanvasItem, drop: Dictionary, shake_offset: Vector2, fading: bool) -> void:
	var pos: Vector2 = _get_vector2(drop.get("pos", drop.get("drop_position", Vector2.ZERO)), Vector2.ZERO) + shake_offset
	var alpha: float = 0.52
	if fading:
		var duration: float = max(0.001, float(drop.get("duration", DROP_EFFECT_SECONDS)))
		alpha = clamp(float(drop.get("life", 0.0)) / duration, 0.0, 1.0) * 0.42
	var payload_type: String = str(drop.get("type", ""))
	var payload_color := Color(0.54, 0.90, 1.0, 1.0) if payload_type == "field_item" else Color(0.95, 0.82, 0.44, 1.0)
	var canopy_pos := pos + Vector2(0.0, -28.0)
	var box_pos := pos + Vector2(0.0, 8.0)
	ImpactFlareTextureCache.draw_glow(canvas, box_pos, 46.0, payload_color, alpha * 0.16)
	ImpactShockwaveTextureCache.draw_full_ring(canvas, canopy_pos, 34.0, payload_color, alpha * 0.16)
	ImpactFlareTextureCache.draw_sparkle(canvas, box_pos, 24.0, Color(1.0, 0.96, 0.64, 1.0), alpha * 0.24)


func _draw_explosion_texture_layer(canvas: CanvasItem, effect: Dictionary, shake_offset: Vector2) -> void:
	var duration: float = max(0.001, float(effect.get("duration", 0.5)))
	var alpha: float = clamp(float(effect.get("life", 0.0)) / duration, 0.0, 1.0)
	if alpha <= 0.0:
		return
	var pos: Vector2 = _get_vector2(effect.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var radius: float = max(2.0, float(effect.get("radius", 4.0))) * (1.15 - alpha * 0.15)
	var base_color: Color = _get_color(effect, "color", Color(1.0, 0.48, 0.10, 1.0))
	var kind: String = str(effect.get("kind", "spark"))
	if kind == "smoke":
		ImpactFlareTextureCache.draw_glow(canvas, pos, radius * 4.6, Color(0.30, 0.30, 0.28, 1.0), alpha * 0.045)
		return
	if kind == "debris":
		ImpactFlareTextureCache.draw_sparkle(canvas, pos, radius * 3.2, base_color, alpha * 0.16)
		return
	ImpactFlareTextureCache.draw_burst(canvas, pos, radius * 4.0, base_color, alpha * 0.18)
	ImpactShockwaveTextureCache.draw_full_ring(canvas, pos, radius * 3.2, Color(1.0, 0.88, 0.32, 1.0), alpha * 0.12)


func _draw_aircraft_sprite(canvas: CanvasItem, pos: Vector2, direction: String, rotation: float, crashing: bool) -> bool:
	if crashing:
		var crash_sheet: Texture2D = _get_aircraft_crash_sheet(direction)
		if crash_sheet == null:
			return false
		var crash_source_rect: Rect2 = _get_aircraft_crash_source_rect(crash_sheet, _get_aircraft_crash_frame())
		_draw_texture_region_rotated(canvas, crash_sheet, crash_source_rect, pos, AIRCRAFT_CRASH_DRAW_SIZE, rotation, Color.WHITE)
		return true
	if absf(rotation) > 0.001:
		return false
	var sheet: Texture2D = _get_aircraft_tilt_sheet(direction)
	if sheet == null:
		return false
	var source_rect: Rect2 = _get_aircraft_tilt_source_rect(sheet, _get_aircraft_tilt_frame())
	var dest_rect := Rect2(pos - AIRCRAFT_TILT_DRAW_SIZE * 0.5, AIRCRAFT_TILT_DRAW_SIZE)
	canvas.draw_texture_rect_region(sheet, dest_rect, source_rect, Color.WHITE, false, true)
	return true


func _get_aircraft_tilt_frame() -> int:
	var frame: int = int(floor(max(0.0, flight_elapsed) / AIRCRAFT_TILT_FRAME_INTERVAL))
	return frame % AIRCRAFT_TILT_FRAME_COUNT


func _get_aircraft_crash_frame() -> int:
	var frame: int = int(floor(max(0.0, aircraft_crash_elapsed) / AIRCRAFT_CRASH_FRAME_INTERVAL))
	return clampi(frame, 0, AIRCRAFT_CRASH_FRAME_COUNT - 1)


static func _get_aircraft_tilt_sheet(direction: String) -> Texture2D:
	var path: String = _get_aircraft_tilt_sheet_path(direction)
	if bool(_aircraft_tilt_sheet_checked.get(path, false)):
		var cached: Variant = _aircraft_tilt_sheet_cache.get(path, null)
		if cached is Texture2D:
			return cached
		return null
	_aircraft_tilt_sheet_checked[path] = true
	var texture: Texture2D = ProjectResourceLoader.load_texture(path, "", "")
	_aircraft_tilt_sheet_cache[path] = texture
	return texture


static func _get_aircraft_tilt_sheet_path(direction: String) -> String:
	return AIRCRAFT_TILT_SHEET_LEFT_PATH if direction == "right_to_left" else AIRCRAFT_TILT_SHEET_RIGHT_PATH


static func _get_aircraft_crash_sheet(direction: String) -> Texture2D:
	var path: String = _get_aircraft_crash_sheet_path(direction)
	if bool(_aircraft_crash_sheet_checked.get(path, false)):
		var cached: Variant = _aircraft_crash_sheet_cache.get(path, null)
		if cached is Texture2D:
			return cached
		return null
	_aircraft_crash_sheet_checked[path] = true
	var texture: Texture2D = ProjectResourceLoader.load_texture(path, "", "")
	_aircraft_crash_sheet_cache[path] = texture
	return texture


static func _get_aircraft_crash_sheet_path(direction: String) -> String:
	return AIRCRAFT_CRASH_SHEET_LEFT_PATH if direction == "right_to_left" else AIRCRAFT_CRASH_SHEET_RIGHT_PATH


static func _get_aircraft_tilt_source_rect(sheet: Texture2D, frame: int) -> Rect2:
	var frame_index: int = clampi(frame, 0, AIRCRAFT_TILT_FRAME_COUNT - 1)
	var texture_size: Vector2 = sheet.get_size()
	var cell_w: float = texture_size.x / float(AIRCRAFT_TILT_GRID_COLS)
	var cell_h: float = texture_size.y / float(AIRCRAFT_TILT_GRID_ROWS)
	var col: int = frame_index % AIRCRAFT_TILT_GRID_COLS
	@warning_ignore("integer_division")
	var row: int = int(frame_index / AIRCRAFT_TILT_GRID_COLS)
	return Rect2(float(col) * cell_w, float(row) * cell_h, cell_w, cell_h)


static func _get_aircraft_crash_source_rect(sheet: Texture2D, frame: int) -> Rect2:
	var frame_index: int = clampi(frame, 0, AIRCRAFT_CRASH_FRAME_COUNT - 1)
	var texture_size: Vector2 = sheet.get_size()
	var cell_w: float = texture_size.x / float(AIRCRAFT_CRASH_GRID_COLS)
	var cell_h: float = texture_size.y / float(AIRCRAFT_CRASH_GRID_ROWS)
	var col: int = frame_index % AIRCRAFT_CRASH_GRID_COLS
	@warning_ignore("integer_division")
	var row: int = int(frame_index / AIRCRAFT_CRASH_GRID_COLS)
	return Rect2(float(col) * cell_w, float(row) * cell_h, cell_w, cell_h)


static func _get_supply_payload_texture() -> Texture2D:
	if _supply_payload_texture_checked:
		return _supply_payload_texture
	_supply_payload_texture_checked = true
	_supply_payload_texture = ProjectResourceLoader.load_texture(SUPPLY_PAYLOAD_SPRITE_PATH, "", "")
	return _supply_payload_texture


static func _draw_texture_region_rotated(
	canvas: CanvasItem,
	texture: Texture2D,
	source: Rect2,
	center: Vector2,
	size: Vector2,
	rotation: float,
	color: Color
) -> void:
	if texture == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var half := size * 0.5
	var corners := [
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	]
	var points := PackedVector2Array()
	for corner in corners:
		points.append(center + corner.rotated(rotation))
	# CanvasItem.draw_polygon() UVs must be normalized [0,1]. Passing the atlas
	# pixel source_rect straight through clamps every UV past 1.0 to the sheet's
	# transparent edge texel, so the whole crashing-plane quad renders invisible
	# with no error (the flying plane uses draw_texture_rect_region and was fine).
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var uv_min := Vector2(source.position.x / texture_size.x, source.position.y / texture_size.y)
	var uv_max := Vector2(source.end.x / texture_size.x, source.end.y / texture_size.y)
	var uvs := PackedVector2Array([
		Vector2(uv_min.x, uv_min.y),
		Vector2(uv_max.x, uv_min.y),
		Vector2(uv_max.x, uv_max.y),
		Vector2(uv_min.x, uv_max.y),
	])
	canvas.draw_polygon(points, PackedColorArray([color, color, color, color]), uvs, texture)


func _draw_aircraft(canvas: CanvasItem, pos: Vector2, direction: String, rotation: float = 0.0, crashing: bool = false) -> void:
	if _draw_aircraft_sprite(canvas, pos, direction, rotation, crashing):
		return
	var nose_sign := 1.0 if direction != "right_to_left" else -1.0
	var body_color := Color(0.47, 0.50, 0.38, 0.92)
	var wing_color := Color(0.35, 0.43, 0.30, 0.88)
	var glass_color := Color(0.70, 0.88, 0.95, 0.86)
	var dark := Color(0.10, 0.12, 0.10, 0.9)
	var body := [
		_aircraft_point(pos, -34.0, 5.0, nose_sign, rotation),
		_aircraft_point(pos, 34.0, 1.0, nose_sign, rotation),
		_aircraft_point(pos, 42.0, 11.0, nose_sign, rotation),
		_aircraft_point(pos, -38.0, 15.0, nose_sign, rotation),
	]
	canvas.draw_colored_polygon(PackedVector2Array(body), body_color)
	canvas.draw_line(
		_aircraft_point(pos, -46.0, 0.0, nose_sign, rotation),
		_aircraft_point(pos, 18.0, -3.0, nose_sign, rotation),
		wing_color,
		8.0
	)
	canvas.draw_line(
		_aircraft_point(pos, -18.0, 14.0, nose_sign, rotation),
		_aircraft_point(pos, 22.0, 28.0, nose_sign, rotation),
		wing_color,
		4.0
	)
	var cockpit := [
		_aircraft_point(pos, 5.0, 2.0, nose_sign, rotation),
		_aircraft_point(pos, 21.0, 2.0, nose_sign, rotation),
		_aircraft_point(pos, 21.0, 11.0, nose_sign, rotation),
		_aircraft_point(pos, 5.0, 11.0, nose_sign, rotation),
	]
	canvas.draw_colored_polygon(PackedVector2Array(cockpit), glass_color)
	canvas.draw_line(
		_aircraft_point(pos, 43.0, 8.0, nose_sign, rotation),
		_aircraft_point(pos, 55.0, 1.0, nose_sign, rotation),
		dark,
		2.0
	)
	canvas.draw_line(
		_aircraft_point(pos, 43.0, 8.0, nose_sign, rotation),
		_aircraft_point(pos, 55.0, 15.0, nose_sign, rotation),
		dark,
		2.0
	)


func _draw_explosion_effect(canvas: CanvasItem, effect: Dictionary, shake_offset: Vector2) -> void:
	var pos: Vector2 = _get_vector2(effect.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var duration: float = max(0.001, float(effect.get("duration", 0.5)))
	var alpha: float = clamp(float(effect.get("life", 0.0)) / duration, 0.0, 1.0)
	var base_color: Color = effect.get("color", Color(1.0, 0.5, 0.1, 1.0)) if effect.get("color", null) is Color else Color(1.0, 0.5, 0.1, 1.0)
	base_color.a *= alpha
	var radius: float = max(1.0, float(effect.get("radius", 4.0))) * (1.15 - alpha * 0.15)
	if str(effect.get("kind", "")) == "debris":
		canvas.draw_rect(Rect2(pos - Vector2(radius, radius) * 0.5, Vector2(radius, radius)), base_color)
	else:
		canvas.draw_circle(pos, radius, base_color)


func _aircraft_point(pos: Vector2, local_x: float, local_y: float, nose_sign: float, rotation: float) -> Vector2:
	return pos + Vector2(local_x * nose_sign, local_y).rotated(rotation)


func _draw_drop_effect(canvas: CanvasItem, effect: Dictionary, shake_offset: Vector2) -> void:
	var pos: Vector2 = _get_vector2(effect.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var duration: float = max(0.001, float(effect.get("duration", DROP_EFFECT_SECONDS)))
	var alpha: float = clamp(float(effect.get("life", 0.0)) / duration, 0.0, 1.0)
	if _draw_supply_payload_sprite(canvas, pos, alpha):
		return
	var color := Color(0.58, 0.62, 0.42, alpha)
	var line_color := Color(0.20, 0.22, 0.18, alpha)
	canvas.draw_arc(pos + Vector2(0.0, -26.0), 28.0, PI, TAU, 18, color, 5.0)
	canvas.draw_line(pos + Vector2(-22.0, -20.0), pos + Vector2(-12.0, -2.0), line_color, 1.5)
	canvas.draw_line(pos + Vector2(22.0, -20.0), pos + Vector2(12.0, -2.0), line_color, 1.5)
	canvas.draw_rect(Rect2(pos + Vector2(-15.0, -2.0), Vector2(30.0, 22.0)), Color(0.42, 0.43, 0.28, alpha))
	canvas.draw_rect(Rect2(pos + Vector2(-15.0, -2.0), Vector2(30.0, 22.0)), line_color, false, 2.0)


func _draw_supply_payload_sprite(canvas: CanvasItem, pos: Vector2, alpha: float) -> bool:
	var texture: Texture2D = _get_supply_payload_texture()
	if texture == null:
		return false
	var clamped_alpha: float = clamp(alpha, 0.0, 1.0)
	if clamped_alpha <= 0.0:
		return true
	var draw_center := pos + SUPPLY_PAYLOAD_DRAW_OFFSET
	var dest_rect := Rect2(draw_center - SUPPLY_PAYLOAD_DRAW_SIZE * 0.5, SUPPLY_PAYLOAD_DRAW_SIZE)
	canvas.draw_texture_rect(texture, dest_rect, false, Color(1.0, 1.0, 1.0, clamped_alpha))
	return true


func _draw_collectible_drop(canvas: CanvasItem, drop: Dictionary, shake_offset: Vector2) -> void:
	var effect: Dictionary = drop.duplicate(true)
	effect["pos"] = _get_vector2(drop.get("pos", drop.get("drop_position", Vector2.ZERO)), Vector2.ZERO)
	effect["life"] = 1.0
	effect["duration"] = 1.0
	_draw_drop_effect(canvas, effect, shake_offset)


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback


func _get_color(entry: Dictionary, key: String, fallback: Color) -> Color:
	var value: Variant = entry.get(key, fallback)
	if value is Color:
		return value
	return fallback


func _get_payload_spawn_position(deps: Dictionary = {}) -> Vector2:
	var bounds: Vector2 = _get_payload_center_background_bounds(deps)
	return Vector2(
		clamp(aircraft_pos.x + PAYLOAD_SPAWN_OFFSET.x, bounds.x, bounds.y),
		clamp(aircraft_pos.y + PAYLOAD_SPAWN_OFFSET.y, 15.0, 735.0)
	)


func _get_payload_center_background_bounds(deps: Dictionary = {}) -> Vector2:
	var play_width: float = max(1.0, float(deps.get("play_width", deps.get("width", DEFAULT_PLAY_WIDTH))))
	var min_x: float = clamp(
		float(deps.get("commando_supply_drop_center_min_x", COLLECTIBLE_DROP_SAFE_MARGIN)),
		0.0,
		play_width
	)
	var max_x: float = clamp(
		float(deps.get("commando_supply_drop_center_max_x", play_width - COLLECTIBLE_DROP_SAFE_MARGIN)),
		0.0,
		play_width
	)
	if max_x < min_x:
		var center_x: float = play_width * 0.5
		return Vector2(center_x, center_x)
	return Vector2(min_x, max_x)
