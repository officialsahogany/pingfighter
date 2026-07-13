extends RefCounted

const ANIM_SECONDS := 0.70
const SWING_PREP_SECONDS := 0.50
const SWING_MAIN_SECONDS := 0.50
const RETRACT_HIT_GRACE_SECONDS := 2.0 / 60.0
# Original parity: BLACKSMITH_UMBRELLA_GAUGE_HIT_COOLDOWN_FRAMES = 0.5s — one
# durability point per half second, so fast balls cannot shred the shield.
const HIT_COOLDOWN_MSEC := 500
# Original parity: BLACKSMITH_UMBRELLA_RECOVER_INTERVAL_BASE_FRAMES = 6s per
# durability point, ticking only while the shield stays folded.
const RECOVER_INTERVAL_SECONDS := 6.0
const DAMAGE_FLASH_SECONDS := 0.18
const HIT_PULSE_SECONDS := 0.22
const MOVE_MULTIPLIER := 0.25
const SHIELD_DURABILITY_MAX := 5
const SHIELD_GAUGE_GAIN := 60.0
const BASE_SHIELD_WIDTH := 220.0
const BASE_SHIELD_HEIGHT := 66.0
const ORIGINAL_RAISE_DONE_RATIO := 0.45
const ORIGINAL_OPEN_START_RATIO := 0.35
const ORIGINAL_OPEN_SPAN_RATIO := 0.65
const VISUAL_REFERENCE_PADDLE_WIDTH := 155.0
const VISUAL_FOLDED_WIDTH := 72.0
const VISUAL_OPEN_WIDTH_BONUS := 238.0
const VISUAL_FOLDED_HEIGHT := 18.0
const VISUAL_OPEN_HEIGHT_BONUS := 42.0
const VISUAL_FORWARD_BASE := 26.0
const VISUAL_FORWARD_OPEN_BONUS := 48.0
const VISUAL_FOLDED_BACK_OFFSET := 5.0
const VISUAL_CLOSED_TILT_DEGREES := 75.0
const INTEGRATED_STRETCH_FOLDED_WIDTH := 96.0
const INTEGRATED_STRETCH_OPEN_WIDTH := 310.0
const INTEGRATED_STRETCH_FOLDED_HEIGHT := 92.0
const INTEGRATED_STRETCH_OPEN_HEIGHT := 122.0
const INTEGRATED_STRETCH_HAND_CLOSED := Vector2(-58.0, -20.0)
# Open-state hand lift. The player sprite (BLACKSMITH_PLAYER_DRAW_SIZE) is drawn
# with its top at ~player_pos.y - 66 and Kohaku's raised shield/hand sits ~25-30%
# down from that top (~player_pos.y - 34), so the overlay lift is tuned to seat the
# stretched shield ONTO her raised hand instead of floating it ~66px overhead.
# This drives both the picture and the (now unified) collision rect, so it must
# stay aligned with the deploy-sheet hand height.
const INTEGRATED_STRETCH_HAND_OPEN := Vector2(-18.0, -64.0)
const INTEGRATED_STRETCH_CENTER_CLOSED := Vector2(-12.0, -2.0)
const INTEGRATED_STRETCH_CENTER_OPEN := Vector2(12.0, -20.0)
# Stretch-shield PNG alpha bbox: the visible shield fills the full draw width but
# only ~69% of the draw height (centered, with transparent top/bottom margins).
# The ball-collision rect scales its height by this so the hitbox tracks the
# painted shield instead of the padded canvas. Source: blacksmith_thor_shield_stretch_imagegen_v1.png
# alpha bbox (0,30,512,162) on a 512x192 canvas -> 132/192 = 0.688.
const INTEGRATED_STRETCH_VISIBLE_HEIGHT_RATIO := 0.688
const SHIELD_OUTLINE_SEGMENTS := 20

var umbrella_open := false
var umbrella_anim_timer := 0.0
var umbrella_retracting := false
var umbrella_anim_direction := 1
var umbrella_gauge := SHIELD_DURABILITY_MAX
var umbrella_damage_flash_timer := 0.0
var umbrella_hit_pulse_timer := 0.0
var umbrella_swing_active := false
var umbrella_swing_timer := 0.0
var umbrella_swing_direction := 0
var umbrella_recharge_timer := 0.0
var _swing_sound_pending := false
var _audio_ref: Object = null
var _last_hit_msec := -100000
var _last_player_pos := Vector2(302.5, 700.0)
var _last_player_size := Vector2(155.0, 50.0)
var _runtime_perk_modal_pause_started_msec := -1


func reset() -> void:
	umbrella_open = false
	umbrella_anim_timer = 0.0
	umbrella_retracting = false
	umbrella_anim_direction = 1
	umbrella_gauge = SHIELD_DURABILITY_MAX
	umbrella_damage_flash_timer = 0.0
	umbrella_hit_pulse_timer = 0.0
	umbrella_swing_active = false
	umbrella_swing_timer = 0.0
	umbrella_swing_direction = 0
	umbrella_recharge_timer = 0.0
	_swing_sound_pending = false
	_last_hit_msec = -100000
	_runtime_perk_modal_pause_started_msec = -1


func force_close_for_character_skill_lock() -> void:
	# Transform locks replace the character kit without replenishing durability.
	# Clear every transient shield surface so it cannot reappear after detransform.
	umbrella_open = false
	umbrella_anim_timer = 0.0
	umbrella_retracting = false
	umbrella_anim_direction = 1
	umbrella_damage_flash_timer = 0.0
	umbrella_hit_pulse_timer = 0.0
	umbrella_swing_active = false
	umbrella_swing_timer = 0.0
	umbrella_swing_direction = 0
	umbrella_recharge_timer = 0.0
	_swing_sound_pending = false
	_last_hit_msec = -100000
	_runtime_perk_modal_pause_started_msec = -1


func reset_round(_deps: Dictionary = {}) -> void:
	reset()


func pause_runtime_perk_modal_time(current_msec: int) -> void:
	if _runtime_perk_modal_pause_started_msec >= 0 or _last_hit_msec <= 0:
		return
	_runtime_perk_modal_pause_started_msec = maxi(0, current_msec)


func resume_runtime_perk_modal_time(current_msec: int) -> void:
	if _runtime_perk_modal_pause_started_msec < 0:
		return
	var pause_started_msec: int = _runtime_perk_modal_pause_started_msec
	_runtime_perk_modal_pause_started_msec = -1
	var paused_duration_msec: int = maxi(0, current_msec - pause_started_msec)
	if paused_duration_msec > 0 and _last_hit_msec > 0:
		_last_hit_msec += paused_duration_msec


func update_input(
	delta: float,
	input_snapshot: Dictionary,
	current_msec: int,
	special_gauge: float,
	player_pos: Vector2,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	_last_player_pos = player_pos
	_last_player_size = Vector2(
		max(1.0, float(config.get("paddle_width", _last_player_size.x))),
		max(1.0, float(config.get("paddle_height", _last_player_size.y)))
	)
	if deps.get("audio", null) != null:
		_audio_ref = deps.get("audio", null)
	var input_locked: bool = bool(config.get("player_skill_input_locked", false))
	if input_locked:
		if bool(config.get("horn_strawberry_skill_input_locked", false)):
			force_close_for_character_skill_lock()
		_tick_timers(delta)
		return _build_owner_snapshot(special_gauge)

	if bool(input_snapshot.get("up_just_pressed", false)):
		if umbrella_open or umbrella_retracting:
			# Original parity: manual fold input is ignored until the deploy
			# animation finishes (anim_timer == 0 gate in pingfighter.py).
			# Accepting it mid-open would snap the fold timer to a mismatched
			# ratio and visibly teleport the shield pose.
			if is_guard_ready():
				_start_close(deps)
		elif umbrella_gauge <= 0:
			# Original parity: at 0 durability the deploy is refused with a
			# damage flash; durability only returns via the folded recharge.
			umbrella_damage_flash_timer = max(
				umbrella_damage_flash_timer,
				DAMAGE_FLASH_SECONDS * 0.75
			)
		else:
			_start_open(deps)

	_tick_timers(delta)
	var swing_direction: int = int(input_snapshot.get("blacksmith_swing_direction", 0))
	if (
		is_guard_ready()
		and swing_direction != 0
		and bool(input_snapshot.get("action_just_pressed", false))
	):
		_start_swing(swing_direction, current_msec, deps)
	return _build_owner_snapshot(special_gauge)


func update_effects(_fps_scale: float, context: Dictionary = {}, _deps: Dictionary = {}) -> Dictionary:
	# Timers tick ONLY on the player-control path (update_input). The normal
	# frame flow calls BOTH update_player_control and update_effects every
	# physics frame, so ticking here too ran every animation at double speed
	# (nominal 0.70s deploy finished in ~0.35s). Modal pause branches that run
	# update_effects alone intentionally freeze the shield, matching the
	# original game's frozen main loop during modals.
	_last_player_pos = _get_vector2(context, "player_pos", _last_player_pos)
	_last_player_size = _get_vector2(context, "player_paddle_size", _last_player_size)
	return _build_owner_snapshot(float(context.get("special_gauge", 0.0)))


func needs_effect_update() -> bool:
	return has_visible_effects() or umbrella_damage_flash_timer > 0.0 or umbrella_hit_pulse_timer > 0.0


func has_visible_effects() -> bool:
	return get_open_ratio() > 0.01 or umbrella_swing_active or umbrella_hit_pulse_timer > 0.0


func is_guard_active() -> bool:
	return (
		umbrella_open
		or (umbrella_retracting and umbrella_anim_timer > 0.0)
	)


func is_guard_ready() -> bool:
	return umbrella_open and not umbrella_retracting and umbrella_anim_timer <= 0.0


func get_player_speed_multiplier() -> float:
	# Original parity: the paddle is fully rooted while the deploy / retract
	# animation runs (umbrella_lock_active zeroed current_speed); the 25%
	# guard crawl applies only once fully deployed.
	if umbrella_anim_timer > 0.0 and (umbrella_open or umbrella_retracting):
		return 0.0
	return MOVE_MULTIPLIER if is_guard_active() else 1.0


func get_ball_collision_context(context: Dictionary = {}) -> Dictionary:
	if not context.is_empty():
		_last_player_pos = _get_vector2(context, "player_pos", _last_player_pos)
		_last_player_size = _get_vector2(context, "player_paddle_size", _last_player_size)
	if not is_guard_active():
		return {}
	var rect: Rect2 = _get_shield_rect()
	var open_ratio: float = get_open_ratio()
	return {
		"blacksmith_thor_shield_active": true,
		"blacksmith_thor_shield_rect": rect,
		"blacksmith_thor_shield_paddle_w": rect.size.x,
		"blacksmith_umbrella_open": umbrella_open,
		"blacksmith_umbrella_anim_timer": umbrella_anim_timer,
		"blacksmith_umbrella_retracting": umbrella_retracting,
		"blacksmith_umbrella_anim_direction": umbrella_anim_direction,
		"blacksmith_umbrella_open_ratio": open_ratio,
		"blacksmith_thor_shield_open_ratio": open_ratio,
		"blacksmith_umbrella_raise_amount": get_raise_amount(),
		"blacksmith_umbrella_shield_open_amount": get_shield_open_amount(),
		"blacksmith_umbrella_visual_state": get_visual_state(),
		"blacksmith_umbrella_folded": is_folded(),
		"blacksmith_umbrella_deployed": is_deployed(),
		"blacksmith_umbrella_swing_active": umbrella_swing_active,
		"blacksmith_umbrella_gauge": umbrella_gauge,
		"blacksmith_umbrella_gauge_gain": SHIELD_GAUGE_GAIN,
	}


func notify_ball_hit(
	ball_pos: Vector2,
	ball_vel: Vector2,
	gauge_before_player_hit: float,
	gauge_after_player_hit: float,
	context: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var current_msec: int = int(context.get("current_msec", Time.get_ticks_msec()))
	if current_msec - _last_hit_msec < HIT_COOLDOWN_MSEC:
		return {}
	_last_hit_msec = current_msec
	umbrella_damage_flash_timer = DAMAGE_FLASH_SECONDS
	umbrella_hit_pulse_timer = HIT_PULSE_SECONDS
	umbrella_gauge = max(0, umbrella_gauge - 1)
	if umbrella_gauge <= 0:
		_start_close(deps)
	var gauge_max: float = max(1.0, float(context.get("gauge_max", context.get("special_gauge_max", 500.0))))
	var next_special_gauge: float = max(
		gauge_after_player_hit,
		min(gauge_max, gauge_before_player_hit + _get_effective_gauge_gain(context))
	)
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_thor_shield_block"):
		audio.play_thor_shield_block()
	elif audio != null and audio.has_method("play_wall_hit"):
		audio.play_wall_hit(max(8.0, abs(ball_vel.y)))
	var feedback: Object = deps.get("feedback", null)
	if feedback != null and feedback.has_method("max_screen_shake"):
		feedback.max_screen_shake(0.018, 0.55)
	var result: Dictionary = _build_owner_snapshot(next_special_gauge)
	result["blacksmith_thor_shield_hit"] = true
	result["blacksmith_thor_shield_hit_pos"] = ball_pos
	result["suppress_paddle_hit_knockback"] = true
	result["paddle_hit_pulse_kind"] = "blacksmith_thor_shield"
	result["paddle_hit_pulse_intensity"] = 0.74
	return result


func draw(canvas: CanvasItem, shake_offset: Vector2, draw_context: Dictionary = {}) -> void:
	if canvas == null or not has_visible_effects():
		return
	var stretch_texture: Texture2D = null
	var stretch_texture_variant: Variant = draw_context.get("blacksmith_thor_shield_stretch_texture", null)
	if stretch_texture_variant is Texture2D:
		stretch_texture = stretch_texture_variant
	var flash: float = clamp(umbrella_damage_flash_timer / DAMAGE_FLASH_SECONDS, 0.0, 1.0)
	var pulse: float = clamp(umbrella_hit_pulse_timer / HIT_PULSE_SECONDS, 0.0, 1.0)
	var raise_amount: float = get_raise_amount()
	var open_amount: float = get_shield_open_amount()
	var visual_scale: float = max(0.72, _last_player_size.x / VISUAL_REFERENCE_PADDLE_WIDTH)
	var pivot: Vector2 = _last_player_pos + Vector2(_last_player_size.x * 0.5, 8.0) + shake_offset
	var direction := Vector2(0.0, -1.0)
	var axis_right := Vector2(1.0, 0.0)
	var axis_down := Vector2(0.0, 1.0)
	var swing_pre_blend: float = _get_swing_pre_blend()
	var swing_main_blend: float = _get_swing_main_blend()
	var swing_dir: float = -1.0 if umbrella_swing_direction < 0 else 1.0
	var close_factor: float = 1.0 - open_amount
	var tilt_angle: float = pow(close_factor, 0.6) * deg_to_rad(VISUAL_CLOSED_TILT_DEGREES)
	if swing_pre_blend > 0.0 and swing_main_blend <= 0.0:
		tilt_angle -= swing_pre_blend * deg_to_rad(35.0) * swing_dir
	if swing_main_blend > 0.0:
		tilt_angle += (swing_pre_blend * 0.5 + swing_main_blend) * deg_to_rad(80.0) * swing_dir
	if abs(tilt_angle) > 0.0001:
		var cos_t: float = cos(tilt_angle)
		var sin_t: float = sin(tilt_angle)
		var rotated_right: Vector2 = axis_right * cos_t - axis_down * sin_t
		var rotated_down: Vector2 = axis_right * sin_t + axis_down * cos_t
		if rotated_right.length_squared() > 0.000001:
			axis_right = rotated_right.normalized()
		if rotated_down.length_squared() > 0.000001:
			axis_down = rotated_down.normalized()

	var forward_offset: float = (
		VISUAL_FORWARD_BASE * (0.25 + raise_amount * 0.75)
		+ open_amount * VISUAL_FORWARD_OPEN_BONUS
		- close_factor * VISUAL_FOLDED_BACK_OFFSET
	) * visual_scale
	var swing_bias: float = close_factor * 14.0 * swing_dir * visual_scale
	var vertical_bias := 0.0
	if swing_main_blend > 0.0:
		swing_bias = (close_factor * 14.0 - (24.0 * swing_pre_blend + 50.0 * swing_main_blend)) * swing_dir * visual_scale
		vertical_bias = (-6.0 * swing_pre_blend + 24.0 * swing_main_blend) * visual_scale
	elif swing_pre_blend > 0.0:
		swing_bias = (close_factor * 14.0 + 18.0 * swing_pre_blend) * swing_dir * visual_scale
		vertical_bias = -10.0 * swing_pre_blend * visual_scale
	var shield_width: float = (
		VISUAL_FOLDED_WIDTH
		+ open_amount * VISUAL_OPEN_WIDTH_BONUS
	) * visual_scale * (1.0 + 0.18 * swing_main_blend)
	var shield_height: float = (
		VISUAL_FOLDED_HEIGHT
		+ open_amount * VISUAL_OPEN_HEIGHT_BONUS
	) * visual_scale * (1.0 + 0.22 * swing_pre_blend + 0.35 * swing_main_blend)
	var shield_center: Vector2 = pivot + direction * forward_offset + axis_right * swing_bias + axis_down * vertical_bias
	# The stretch-shield PNG is the only shield body now (the procedural canopy
	# fallback was intentionally removed after the "회색 캐노피" regression). Gate the
	# draw on the stretch texture itself, NOT on the overhead deploy sheet: the deploy
	# sheet is a separate player-overlay animation, and coupling the body render to it
	# silently hid the shield whenever the stretch texture was absent from the runtime
	# texture cache. If the stretch art is missing there is no body to draw, so bail
	# before the accent arcs to avoid orphaned glints with no shield behind them.
	if stretch_texture == null:
		return
	var integrated_metrics: Dictionary = _get_integrated_thor_shield_overlay_metrics(shake_offset)
	shield_center = _get_vector2(integrated_metrics, "shield_center", shield_center)
	axis_right = _get_vector2(integrated_metrics, "axis_right", axis_right)
	axis_down = _get_vector2(integrated_metrics, "axis_down", axis_down)
	shield_width = max(1.0, float(integrated_metrics.get("shield_width", shield_width)))
	shield_height = max(1.0, float(integrated_metrics.get("shield_height", shield_height)))
	_draw_integrated_thor_shield_stretch_texture(canvas, integrated_metrics, stretch_texture, flash, pulse)
	if pulse > 0.0:
		var pulse_color := Color(1.0, 0.88, 0.42, 0.32 * pulse)
		_draw_ellipse_arc(canvas, shield_center, Vector2(shield_width * (0.44 + 0.10 * pulse), shield_height * (0.90 + 0.18 * pulse)), PI, TAU, pulse_color, 3.0)
	if umbrella_swing_active:
		var slash_center := shield_center + axis_right * (swing_dir * shield_width * 0.30) - axis_down * (shield_height * 0.22)
		var slash_radius := Vector2(shield_width * 0.40, shield_height * 0.92)
		_draw_ellipse_arc(canvas, slash_center, slash_radius, PI * 1.05, PI * 1.95, Color(1.0, 0.88, 0.40, 0.58), 4.0)
		_draw_ellipse_arc(canvas, slash_center, slash_radius * 0.72, PI * 1.08, PI * 1.92, Color(0.58, 0.86, 1.0, 0.28), 2.0)


func get_open_ratio() -> float:
	if umbrella_retracting:
		return clamp(umbrella_anim_timer / ANIM_SECONDS, 0.0, 1.0)
	if umbrella_open:
		if umbrella_anim_timer <= 0.0:
			return 1.0
		return clamp(1.0 - umbrella_anim_timer / ANIM_SECONDS, 0.0, 1.0)
	return 0.0


func get_raise_amount() -> float:
	return clamp(get_open_ratio() / ORIGINAL_RAISE_DONE_RATIO, 0.0, 1.0)


func get_shield_open_amount() -> float:
	return clamp((get_open_ratio() - ORIGINAL_OPEN_START_RATIO) / ORIGINAL_OPEN_SPAN_RATIO, 0.0, 1.0)


func get_visual_state() -> String:
	if umbrella_swing_active:
		return "swinging"
	if umbrella_retracting:
		return "closing"
	if umbrella_open and umbrella_anim_timer > 0.0:
		return "opening"
	if umbrella_open:
		return "open"
	return "closed"


func is_folded() -> bool:
	return not umbrella_open and not umbrella_retracting and get_open_ratio() <= 0.01


func is_deployed() -> bool:
	return umbrella_open and not umbrella_retracting and get_open_ratio() >= 0.99


func get_swing_ratio() -> float:
	if not umbrella_swing_active:
		return 0.0
	var total: float = SWING_PREP_SECONDS + SWING_MAIN_SECONDS
	return clamp(1.0 - umbrella_swing_timer / total, 0.0, 1.0)


func get_snapshot() -> Dictionary:
	return _build_owner_snapshot(0.0)


func _tick_timers(delta: float) -> void:
	if umbrella_anim_timer > 0.0:
		umbrella_anim_timer = max(0.0, umbrella_anim_timer - delta)
		if umbrella_anim_timer <= 0.0 and umbrella_retracting:
			umbrella_open = false
			umbrella_retracting = false
			umbrella_anim_direction = 1
	if umbrella_swing_active:
		umbrella_swing_timer = max(0.0, umbrella_swing_timer - delta)
		if _swing_sound_pending and get_swing_ratio() >= 0.5:
			# Original parity: swing.wav fires at the main-swing phase after
			# the 0.5s prep, not at input time.
			_swing_sound_pending = false
			_play_audio({}, "play_thor_shield_swing")
		if umbrella_swing_timer <= 0.0:
			umbrella_swing_active = false
			umbrella_swing_direction = 0
			_swing_sound_pending = false
	if umbrella_damage_flash_timer > 0.0:
		umbrella_damage_flash_timer = max(0.0, umbrella_damage_flash_timer - delta)
	if umbrella_hit_pulse_timer > 0.0:
		umbrella_hit_pulse_timer = max(0.0, umbrella_hit_pulse_timer - delta)
	if umbrella_open or umbrella_retracting or umbrella_gauge >= SHIELD_DURABILITY_MAX:
		umbrella_recharge_timer = 0.0
	elif delta > 0.0:
		umbrella_recharge_timer += delta
		if umbrella_recharge_timer >= RECOVER_INTERVAL_SECONDS:
			umbrella_recharge_timer = 0.0
			umbrella_gauge = min(SHIELD_DURABILITY_MAX, umbrella_gauge + 1)


func _start_open(deps: Dictionary = {}) -> void:
	umbrella_open = true
	umbrella_retracting = false
	umbrella_anim_direction = 1
	umbrella_anim_timer = ANIM_SECONDS
	umbrella_recharge_timer = 0.0
	_play_audio(deps, "play_thor_shield_open")


func _start_close(deps: Dictionary = {}) -> void:
	if not umbrella_open or umbrella_retracting:
		return
	# Fold from the CURRENT open ratio: while retracting, get_open_ratio() is
	# timer / ANIM_SECONDS, so seeding the timer with ratio * ANIM_SECONDS keeps
	# the pose continuous even on forced closes (durability depletion while the
	# deploy animation is still running). Seeding the full ANIM_SECONDS here
	# snapped a partially-open shield to fully-open before folding.
	var close_ratio: float = get_open_ratio()
	umbrella_open = true
	umbrella_retracting = true
	umbrella_anim_direction = -1
	umbrella_anim_timer = max(ANIM_SECONDS * close_ratio, RETRACT_HIT_GRACE_SECONDS)
	umbrella_swing_active = false
	umbrella_swing_timer = 0.0
	umbrella_swing_direction = 0
	_swing_sound_pending = false
	_play_audio(deps, "play_thor_shield_close")


func _start_swing(direction: int, _current_msec: int, _deps: Dictionary) -> void:
	umbrella_swing_active = true
	umbrella_swing_timer = SWING_PREP_SECONDS + SWING_MAIN_SECONDS
	umbrella_swing_direction = direction
	_swing_sound_pending = true


func _play_audio(deps: Dictionary, method: String) -> void:
	var audio: Object = deps.get("audio", null)
	if audio == null:
		audio = _audio_ref
	if audio != null and audio.has_method(method):
		audio.call(method)


func _get_shield_rect() -> Rect2:
	# Derive the ball-collision rect from the SAME integrated overlay metrics that
	# draw() renders the stretch-shield PNG with, so the judged range tracks the
	# visible shield (position, length, swing shift) exactly. Previously the rect
	# came from an independent paddle-baseline formula (BASE_SHIELD_* at
	# player_pos.y+8) while the art is drawn lifted overhead via the integrated
	# metrics, so the hitbox sat ~120px below the picture. No shake offset here:
	# the hitbox should not jitter with screen shake even though the art does.
	var metrics: Dictionary = _get_integrated_thor_shield_overlay_metrics()
	var center: Vector2 = _get_vector2(
		metrics,
		"shield_center",
		_last_player_pos + Vector2(_last_player_size.x * 0.5, 8.0)
	)
	var draw_width: float = max(18.0, float(metrics.get("shield_width", BASE_SHIELD_WIDTH)))
	var draw_height: float = max(18.0, float(metrics.get("shield_height", BASE_SHIELD_HEIGHT)))
	var visible_height: float = max(18.0, draw_height * INTEGRATED_STRETCH_VISIBLE_HEIGHT_RATIO)
	return Rect2(
		center.x - draw_width * 0.5,
		center.y - visible_height * 0.5,
		draw_width,
		visible_height
	)


func _get_effective_gauge_gain(context: Dictionary) -> float:
	return max(0.0, float(context.get("blacksmith_umbrella_gauge_gain", SHIELD_GAUGE_GAIN)))


func _build_owner_snapshot(special_gauge: float) -> Dictionary:
	var open_ratio: float = get_open_ratio()
	return {
		"special_gauge": special_gauge,
		"blacksmith_umbrella_open": umbrella_open,
		"blacksmith_umbrella_anim_timer": umbrella_anim_timer,
		"blacksmith_umbrella_retracting": umbrella_retracting,
		"blacksmith_umbrella_anim_direction": umbrella_anim_direction,
		"blacksmith_umbrella_open_ratio": open_ratio,
		"blacksmith_thor_shield_open_ratio": open_ratio,
		"blacksmith_umbrella_raise_amount": get_raise_amount(),
		"blacksmith_umbrella_shield_open_amount": get_shield_open_amount(),
		"blacksmith_umbrella_visual_state": get_visual_state(),
		"blacksmith_umbrella_folded": is_folded(),
		"blacksmith_umbrella_deployed": is_deployed(),
		"blacksmith_umbrella_swing_active": umbrella_swing_active,
		"blacksmith_umbrella_swing_direction": umbrella_swing_direction,
		"blacksmith_umbrella_swing_timer": umbrella_swing_timer,
		"blacksmith_umbrella_gauge": umbrella_gauge,
		"blacksmith_umbrella_gauge_max": SHIELD_DURABILITY_MAX,
		"blacksmith_umbrella_gauge_gain": SHIELD_GAUGE_GAIN,
		"blacksmith_umbrella_damage_flash_timer": umbrella_damage_flash_timer,
		"blacksmith_umbrella_hit_pulse_timer": umbrella_hit_pulse_timer,
	}


func _draw_original_thor_shield_plate(
	canvas: CanvasItem,
	shield_center: Vector2,
	axis_right: Vector2,
	axis_down: Vector2,
	shield_width: float,
	shield_height: float,
	open_amount: float,
	flash: float,
	pulse: float,
	progress: float
) -> void:
	var outline_local: Array[Vector2] = _build_shield_outline_local(shield_width, shield_height, open_amount)
	var outline_world: PackedVector2Array = _local_points_to_world(outline_local, shield_center, axis_right, axis_down)
	var base_color: Color = _rgb(132.0 + 12.0 * open_amount, 118.0 + 18.0 * open_amount, 102.0 + 20.0 * open_amount, 220.0 + 20.0 * pulse)
	var shadow_color: Color = _rgb(82.0 + 8.0 * open_amount, 68.0 + 10.0 * open_amount, 54.0 + 12.0 * open_amount, 238.0)
	var highlight_color: Color = _rgb(164.0 + 8.0 * open_amount, 150.0 + 12.0 * open_amount, 134.0 + 16.0 * open_amount, 235.0)
	var flash_color := Color(1.0, 0.84, 0.50, 0.95)
	base_color = base_color.lerp(flash_color, flash * 0.55)
	shadow_color = shadow_color.lerp(Color(1.0, 0.78, 0.40, 1.0), flash * 0.45)
	highlight_color = highlight_color.lerp(Color(1.0, 0.95, 0.78, 1.0), flash * 0.65)
	for layer in range(2):
		var layer_ratio: float = float(layer) / 2.0
		var layer_points: PackedVector2Array = _scaled_local_points_to_world(
			outline_local,
			shield_center,
			axis_right,
			axis_down,
			1.0 - float(layer) * 0.018,
			1.0 - float(layer) * 0.035
		)
		canvas.draw_colored_polygon(layer_points, base_color.lerp(highlight_color, layer_ratio))
	_draw_closed_polyline(canvas, outline_world, shadow_color, 4.0)
	var inner_outline: PackedVector2Array = _scaled_local_points_to_world(outline_local, shield_center, axis_right, axis_down, 0.95, 0.90)
	_draw_closed_polyline(canvas, inner_outline, _rgb(188.0, 174.0, 158.0, 220.0), 2.0)
	_draw_shield_bands(canvas, shield_center, axis_right, axis_down, shield_width, shield_height, open_amount, flash)
	_draw_shield_runes(canvas, shield_center, axis_right, axis_down, shield_width, shield_height, open_amount, progress)
	_draw_shield_rivets(canvas, shield_center, axis_right, axis_down, shield_width, shield_height, open_amount)
	_draw_shield_straps(canvas, shield_center, axis_right, axis_down, shield_width, shield_height)
	_draw_shield_hammer_ornament(canvas, shield_center, axis_right, axis_down, shield_width, shield_height, open_amount, flash)
	_draw_shield_damage_cracks(canvas, shield_center, axis_right, axis_down, shield_width, shield_height, flash)


func _get_integrated_thor_shield_overlay_metrics(shake_offset: Vector2 = Vector2.ZERO) -> Dictionary:
	var progress: float = get_open_ratio()
	var raise_amount: float = get_raise_amount()
	var open_amount: float = get_shield_open_amount()
	var lift: float = _ease_out_cubic(raise_amount)
	var spread: float = _ease_out_back(open_amount)
	var visual_scale: float = max(0.72, _last_player_size.x / VISUAL_REFERENCE_PADDLE_WIDTH)
	var pivot: Vector2 = _last_player_pos + Vector2(_last_player_size.x * 0.5, 8.0) + shake_offset
	var swing_pre_blend: float = _get_swing_pre_blend()
	var swing_main_blend: float = _get_swing_main_blend()
	var swing_dir: float = -1.0 if umbrella_swing_direction < 0 else 1.0
	var axis_right := Vector2(1.0, 0.0)
	var axis_down := Vector2(0.0, 1.0)
	var tilt_angle: float = pow(1.0 - spread, 0.58) * deg_to_rad(VISUAL_CLOSED_TILT_DEGREES)
	if swing_pre_blend > 0.0 and swing_main_blend <= 0.0:
		tilt_angle -= swing_pre_blend * deg_to_rad(28.0) * swing_dir
	if swing_main_blend > 0.0:
		tilt_angle += (swing_pre_blend * 0.35 + swing_main_blend) * deg_to_rad(64.0) * swing_dir
	if abs(tilt_angle) > 0.0001:
		var cos_t: float = cos(tilt_angle)
		var sin_t: float = sin(tilt_angle)
		axis_right = (Vector2(1.0, 0.0) * cos_t - Vector2(0.0, 1.0) * sin_t).normalized()
		axis_down = (Vector2(1.0, 0.0) * sin_t + Vector2(0.0, 1.0) * cos_t).normalized()

	var hand_local: Vector2 = INTEGRATED_STRETCH_HAND_CLOSED.lerp(INTEGRATED_STRETCH_HAND_OPEN, lift)
	var hand_anchor: Vector2 = pivot + hand_local * visual_scale
	hand_anchor += Vector2(
		swing_dir * (20.0 * swing_pre_blend + 62.0 * swing_main_blend),
		-8.0 * swing_pre_blend + 20.0 * swing_main_blend
	) * visual_scale
	var shield_width: float = lerp(
		INTEGRATED_STRETCH_FOLDED_WIDTH,
		INTEGRATED_STRETCH_OPEN_WIDTH,
		spread
	) * visual_scale * (1.0 + 0.12 * swing_main_blend)
	var shield_height: float = lerp(
		INTEGRATED_STRETCH_FOLDED_HEIGHT,
		INTEGRATED_STRETCH_OPEN_HEIGHT,
		spread
	) * visual_scale * (1.0 + 0.12 * swing_pre_blend + 0.22 * swing_main_blend)
	var center_offset: Vector2 = INTEGRATED_STRETCH_CENTER_CLOSED.lerp(
		INTEGRATED_STRETCH_CENTER_OPEN,
		spread
	) * visual_scale
	var shield_center: Vector2 = hand_anchor + center_offset
	var grip_anchor: Vector2 = shield_center + Vector2(0.0, shield_height * (0.23 + 0.03 * spread))
	return {
		"progress": progress,
		"open_amount": open_amount,
		"spread": spread,
		"visual_scale": visual_scale,
		"shield_center": shield_center,
		"axis_right": axis_right,
		"axis_down": axis_down,
		"shield_width": shield_width,
		"shield_height": shield_height,
		"hand_anchor": hand_anchor,
		"grip_anchor": grip_anchor,
	}


func _draw_integrated_thor_shield_stretch_texture(
	canvas: CanvasItem,
	metrics: Dictionary,
	stretch_texture: Texture2D,
	flash: float,
	pulse: float
) -> void:
	var shield_center: Vector2 = _get_vector2(metrics, "shield_center", Vector2.ZERO)
	var shield_width: float = max(1.0, float(metrics.get("shield_width", 1.0)))
	var shield_height: float = max(1.0, float(metrics.get("shield_height", 1.0)))
	var axis_right: Vector2 = _get_vector2(metrics, "axis_right", Vector2(1.0, 0.0))
	var axis_down: Vector2 = _get_vector2(metrics, "axis_down", Vector2(0.0, 1.0))
	var spread: float = clamp(float(metrics.get("spread", 0.0)), 0.0, 1.0)
	var draw_alpha: float = clamp(0.26 + spread * 0.74 + pulse * 0.10, 0.0, 1.0)
	var tint := Color(1.0, 1.0, 1.0, draw_alpha).lerp(Color(1.0, 0.92, 0.62, draw_alpha), flash * 0.32)
	# Draw the shield PNG along the metrics tilt axes so the folded / closing
	# pose actually leans (VISUAL_CLOSED_TILT_DEGREES) instead of staying an
	# axis-aligned rectangle. UVs are the full normalized [0,1] quad.
	var half_right: Vector2 = axis_right * shield_width * 0.5
	var half_down: Vector2 = axis_down * shield_height * 0.5
	var quad := PackedVector2Array([
		shield_center - half_right - half_down,
		shield_center + half_right - half_down,
		shield_center + half_right + half_down,
		shield_center - half_right + half_down,
	])
	var uvs := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(1.0, 1.0),
		Vector2(0.0, 1.0),
	])
	var colors := PackedColorArray([tint, tint, tint, tint])
	_draw_integrated_thor_shield_handle(canvas, metrics, false)
	canvas.draw_polygon(quad, colors, uvs, stretch_texture)
	_draw_shield_damage_cracks(
		canvas,
		shield_center,
		axis_right,
		axis_down,
		shield_width * 0.82,
		shield_height * INTEGRATED_STRETCH_VISIBLE_HEIGHT_RATIO,
		flash
	)
	_draw_integrated_thor_shield_handle(canvas, metrics, true)


func _draw_integrated_thor_shield_handle(canvas: CanvasItem, metrics: Dictionary, foreground: bool) -> void:
	var hand_anchor: Vector2 = _get_vector2(metrics, "hand_anchor", Vector2.ZERO)
	var grip_anchor: Vector2 = _get_vector2(metrics, "grip_anchor", hand_anchor)
	var spread: float = clamp(float(metrics.get("spread", 0.0)), 0.0, 1.0)
	if foreground:
		canvas.draw_circle(grip_anchor, 6.0 + 3.0 * spread, _rgb(72.0, 54.0, 34.0, 235.0))
		canvas.draw_circle(grip_anchor, 4.0 + 2.0 * spread, _rgb(220.0, 194.0, 128.0, 240.0))
		canvas.draw_circle(hand_anchor, 4.0, _rgb(245.0, 218.0, 150.0, 215.0))
		return
	canvas.draw_line(hand_anchor + Vector2(2.0, 2.0), grip_anchor + Vector2(2.0, 2.0), _rgb(48.0, 36.0, 26.0, 210.0), 7.0, true)
	canvas.draw_line(hand_anchor, grip_anchor, _rgb(178.0, 134.0, 74.0, 230.0), 4.0, true)


func _build_shield_outline_local(shield_width: float, shield_height: float, open_amount: float) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for index in range(SHIELD_OUTLINE_SEGMENTS + 1):
		var t: float = float(index) / float(SHIELD_OUTLINE_SEGMENTS)
		var x: float = (t - 0.5) * shield_width
		var outer_curve: float = 0.5 + 0.15 * open_amount
		var y: float = -sin(t * PI) * shield_height * outer_curve - shield_height * 0.08
		points.append(Vector2(x, y))
	for index in range(SHIELD_OUTLINE_SEGMENTS, -1, -1):
		var t: float = float(index) / float(SHIELD_OUTLINE_SEGMENTS)
		var x: float = (t - 0.5) * shield_width
		var inner_wave: float = 0.08 + 0.28 * open_amount
		var thickness: float = 0.18 + 0.42 * (1.0 - sin(t * PI)) * (0.6 + 0.4 * open_amount)
		var y: float = -sin(t * PI) * shield_height * inner_wave + shield_height * thickness
		points.append(Vector2(x, y))
	return points


func _draw_shield_bands(
	canvas: CanvasItem,
	shield_center: Vector2,
	axis_right: Vector2,
	axis_down: Vector2,
	shield_width: float,
	shield_height: float,
	open_amount: float,
	flash: float
) -> void:
	var band_thickness: float = shield_height * (0.24 + 0.18 * open_amount)
	var upper_points: Array[Vector2] = []
	var lower_points: Array[Vector2] = []
	for index in range(12):
		var t: float = float(index) / 11.0
		var x: float = (t - 0.5) * shield_width * 0.90
		var upper_y: float = -sin(t * PI) * shield_height * 0.5 - shield_height * 0.15 - band_thickness * 0.3
		var thickness: float = 0.25 + 0.45 * (1.0 - sin(t * PI))
		var lower_y: float = -sin(t * PI) * shield_height * 0.05 + shield_height * (thickness - 0.1) + band_thickness * 0.2
		upper_points.append(Vector2(x, upper_y))
		lower_points.append(Vector2((t - 0.5) * shield_width * 0.95, lower_y))
	var upper_color: Color = _rgb(194.0, 170.0, 130.0, 232.0).lerp(Color(1.0, 0.90, 0.55, 0.95), flash * 0.45)
	var lower_color: Color = _rgb(164.0, 140.0, 110.0, 226.0).lerp(Color(1.0, 0.84, 0.48, 0.92), flash * 0.40)
	_draw_local_polyline(canvas, upper_points, shield_center, axis_right, axis_down, upper_color, 5.0)
	_draw_local_polyline(canvas, lower_points, shield_center, axis_right, axis_down, lower_color, 5.0)
	_draw_local_polyline(canvas, upper_points, shield_center, axis_right, axis_down, _rgb(80.0, 68.0, 48.0, 235.0), 2.0)
	_draw_local_polyline(canvas, lower_points, shield_center, axis_right, axis_down, _rgb(70.0, 58.0, 40.0, 235.0), 2.0)


func _draw_shield_runes(
	canvas: CanvasItem,
	shield_center: Vector2,
	axis_right: Vector2,
	axis_down: Vector2,
	shield_width: float,
	shield_height: float,
	open_amount: float,
	progress: float
) -> void:
	var detail_alpha: float = clamp(0.20 + open_amount * 0.80 + progress * 0.18, 0.0, 1.0)
	var time_value: float = float(Time.get_ticks_msec()) / 1000.0
	for rune_index in range(-1, 2):
		var phase_offset: float = float(rune_index) * 0.7
		var pulse_intensity: float = (sin(time_value * 2.0 + phase_offset) + 1.0) * 0.5
		var rune_color: Color = _rgb(210.0, 188.0, 130.0, 165.0 + 80.0 * pulse_intensity).lerp(
			_rgb(255.0, 235.0, 180.0, 245.0),
			pulse_intensity * 0.55
		)
		rune_color.a *= detail_alpha
		var rune_x: float = float(rune_index) * shield_width * 0.22
		var t: float = rune_x / shield_width + 0.5
		var curve_y: float = -sin(t * PI) * shield_height * 0.4
		var top: Vector2 = _to_world(Vector2(rune_x, curve_y - shield_height * 0.25), shield_center, axis_right, axis_down)
		var bottom: Vector2 = _to_world(Vector2(rune_x, curve_y + shield_height * 0.25), shield_center, axis_right, axis_down)
		canvas.draw_line(top, bottom, rune_color, 3.5, true)
		var left_tick: Vector2 = _to_world(Vector2(rune_x - shield_width * 0.05, curve_y), shield_center, axis_right, axis_down)
		var right_tick: Vector2 = _to_world(Vector2(rune_x + shield_width * 0.05, curve_y), shield_center, axis_right, axis_down)
		canvas.draw_line(left_tick, right_tick, rune_color, 2.6, true)


func _draw_shield_rivets(
	canvas: CanvasItem,
	shield_center: Vector2,
	axis_right: Vector2,
	axis_down: Vector2,
	shield_width: float,
	shield_height: float,
	open_amount: float
) -> void:
	var rivet_shadow := _rgb(64.0, 50.0, 34.0, 220.0)
	var rivet_highlight := _rgb(182.0 + 22.0 * open_amount, 160.0 + 20.0 * open_amount, 130.0 + 18.0 * open_amount, 238.0)
	for row in range(2):
		for column in range(4):
			var t: float = float(column) / 3.0
			var x: float = (t - 0.5) * shield_width * 0.8
			var base_curve_y: float = -sin(t * PI) * shield_height * 0.5
			var y: float = base_curve_y + (float(row) - 0.5) * shield_height * 0.7
			var pos: Vector2 = _to_world(Vector2(x, y), shield_center, axis_right, axis_down)
			var radius: float = max(2.2, shield_height * 0.065)
			canvas.draw_circle(pos, radius + 1.0, rivet_shadow)
			canvas.draw_circle(pos, radius, rivet_highlight)


func _draw_shield_straps(
	canvas: CanvasItem,
	shield_center: Vector2,
	axis_right: Vector2,
	axis_down: Vector2,
	shield_width: float,
	shield_height: float
) -> void:
	for side in [-1.0, 1.0]:
		var start_t: float = 0.42 * side + 0.5
		var end_t: float = 0.68 * side + 0.5
		var mid_t: float = (start_t + end_t) * 0.5
		var strap_points: Array[Vector2] = [
			Vector2(-shield_width * 0.42 * side, -sin(start_t * PI) * shield_height * 0.5 + shield_height * 0.35),
			Vector2(-shield_width * 0.55 * side, -sin(mid_t * PI) * shield_height * 0.55),
			Vector2(-shield_width * 0.68 * side, -sin(end_t * PI) * shield_height * 0.6 - shield_height * 0.2),
		]
		_draw_local_polyline(canvas, strap_points, shield_center, axis_right, axis_down, _rgb(96.0, 78.0, 60.0, 220.0), 4.0)


func _draw_shield_hammer_ornament(
	canvas: CanvasItem,
	shield_center: Vector2,
	axis_right: Vector2,
	axis_down: Vector2,
	shield_width: float,
	shield_height: float,
	open_amount: float,
	flash: float
) -> void:
	var hammer_length: float = shield_width * 0.45
	var hammer_thickness: float = max(4.0, shield_height * 0.18)
	var hammer_pts: Array[Vector2] = [
		Vector2(-hammer_length * 0.5, -hammer_thickness * 0.5),
		Vector2(-hammer_length * 0.15, -hammer_thickness * 0.5),
		Vector2(hammer_length * 0.15, -hammer_thickness * 0.5),
		Vector2(hammer_length * 0.5, hammer_thickness * 0.1),
		Vector2(hammer_length * 0.15, hammer_thickness * 0.5),
		Vector2(-hammer_length * 0.15, hammer_thickness * 0.5),
	]
	var shadow_pts: Array[Vector2] = []
	for point in hammer_pts:
		shadow_pts.append(point + Vector2(2.0, 2.0))
	canvas.draw_colored_polygon(_local_points_to_world(shadow_pts, shield_center, axis_right, axis_down), _rgb(70.0, 56.0, 36.0, 210.0))
	canvas.draw_colored_polygon(_local_points_to_world(hammer_pts, shield_center, axis_right, axis_down), _rgb(218.0, 200.0, 152.0, 235.0).lerp(Color(1.0, 0.92, 0.62, 0.96), flash * 0.45))
	_draw_closed_polyline(canvas, _local_points_to_world(hammer_pts, shield_center, axis_right, axis_down), _rgb(90.0, 76.0, 56.0, 230.0), 2.0)
	var shine_pts: Array[Vector2] = [
		Vector2(-hammer_length * 0.38, -hammer_thickness * 0.30),
		Vector2(-hammer_length * 0.10, -hammer_thickness * 0.30),
		Vector2(hammer_length * 0.10, -hammer_thickness * 0.28),
		Vector2(hammer_length * 0.30, 0.0),
	]
	_draw_local_polyline(canvas, shine_pts, shield_center, axis_right, axis_down, _rgb(238.0, 220.0, 172.0, 210.0 + 20.0 * open_amount), 2.0)


func _draw_shield_damage_cracks(
	canvas: CanvasItem,
	shield_center: Vector2,
	axis_right: Vector2,
	axis_down: Vector2,
	shield_width: float,
	shield_height: float,
	flash: float
) -> void:
	var damage_stage: int = clampi(SHIELD_DURABILITY_MAX - umbrella_gauge, 0, 5)
	if damage_stage <= 0:
		return
	var crack_color: Color = _rgb(186.0 + damage_stage * 6.0, 178.0 + damage_stage * 5.0, 168.0 + damage_stage * 5.0, 230.0).lerp(Color(1.0, 0.96, 0.86, 1.0), flash)
	var crack_shadow := _rgb(58.0, 46.0, 38.0, 230.0)
	var crack_segments: Array[Array] = [
		[Vector2(-0.14, -0.15), Vector2(-0.03, 0.10)],
		[Vector2(0.08, -0.26), Vector2(0.00, 0.05)],
		[Vector2(-0.02, 0.03), Vector2(0.15, 0.26)],
		[Vector2(0.18, -0.04), Vector2(0.29, 0.12)],
		[Vector2(-0.22, 0.12), Vector2(-0.08, 0.24)],
	]
	var crack_count: int = min(damage_stage, crack_segments.size())
	for index in range(crack_count):
		var segment: Array = crack_segments[index]
		var start_norm: Vector2 = segment[0]
		var end_norm: Vector2 = segment[1]
		var start_pos: Vector2 = _to_world(Vector2(start_norm.x * shield_width, start_norm.y * shield_height), shield_center, axis_right, axis_down)
		var end_pos: Vector2 = _to_world(Vector2(end_norm.x * shield_width, end_norm.y * shield_height), shield_center, axis_right, axis_down)
		canvas.draw_line(start_pos, end_pos, crack_shadow, 3.0, true)
		canvas.draw_line(start_pos, end_pos, crack_color, 1.6, true)


func _get_swing_pre_blend() -> float:
	if not umbrella_swing_active:
		return 0.0
	var swing_ratio: float = get_swing_ratio()
	if swing_ratio < 0.5:
		var prep_ratio: float = clamp(swing_ratio / 0.5, 0.0, 1.0)
		return 1.0 - pow(1.0 - prep_ratio, 3.0)
	return 1.0


func _get_swing_main_blend() -> float:
	if not umbrella_swing_active:
		return 0.0
	return clamp((get_swing_ratio() - 0.5) / 0.5, 0.0, 1.0)


func _ease_out_cubic(value: float) -> float:
	var t: float = clamp(value, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


func _ease_out_back(value: float) -> float:
	var t: float = clamp(value, 0.0, 1.0)
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return clamp(1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0), 0.0, 1.0)


func _to_world(local: Vector2, center: Vector2, axis_right: Vector2, axis_down: Vector2) -> Vector2:
	return center + axis_right * local.x + axis_down * local.y


func _local_points_to_world(
	local_points: Array[Vector2],
	center: Vector2,
	axis_right: Vector2,
	axis_down: Vector2
) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point in local_points:
		points.append(_to_world(point, center, axis_right, axis_down))
	return points


func _scaled_local_points_to_world(
	local_points: Array[Vector2],
	center: Vector2,
	axis_right: Vector2,
	axis_down: Vector2,
	scale_x: float,
	scale_y: float
) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point in local_points:
		points.append(_to_world(Vector2(point.x * scale_x, point.y * scale_y), center, axis_right, axis_down))
	return points


func _draw_local_polyline(
	canvas: CanvasItem,
	local_points: Array[Vector2],
	center: Vector2,
	axis_right: Vector2,
	axis_down: Vector2,
	color: Color,
	width: float
) -> void:
	if local_points.size() < 2:
		return
	canvas.draw_polyline(_local_points_to_world(local_points, center, axis_right, axis_down), color, width, true)


func _draw_closed_polyline(canvas: CanvasItem, points: PackedVector2Array, color: Color, width: float) -> void:
	if points.size() < 2:
		return
	var closed := PackedVector2Array()
	for point in points:
		closed.append(point)
	closed.append(points[0])
	canvas.draw_polyline(closed, color, width, true)


func _rgb(r: float, g: float, b: float, a: float = 255.0) -> Color:
	return Color(
		clamp(r, 0.0, 255.0) / 255.0,
		clamp(g, 0.0, 255.0) / 255.0,
		clamp(b, 0.0, 255.0) / 255.0,
		clamp(a, 0.0, 255.0) / 255.0
	)


func _draw_ellipse_arc(
	canvas: CanvasItem,
	center: Vector2,
	radius: Vector2,
	start_angle: float,
	end_angle: float,
	color: Color,
	width: float
) -> void:
	var points := PackedVector2Array()
	var segments := 36
	for index in range(segments + 1):
		var t: float = float(index) / float(segments)
		var angle: float = lerp(start_angle, end_angle, t)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	canvas.draw_polyline(points, color, width, true)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
