extends RefCounted

const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")
const DaljiVisionChosikRenderer := preload("res://scripts/characters/dalji_vision_chosik_renderer.gd")
const Stage1DaljiSpinningTopMotion := preload("res://scripts/stages/stage1/stage1_dalji_spinning_top_motion.gd")
const Stage1DaljiSpinningTopPayloadFactory := preload("res://scripts/stages/stage1/stage1_dalji_spinning_top_payload_factory.gd")

const SKILL_ID := CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_ID
const COST := CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_COST
const BASE_COOLDOWN_SEC := CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_COOLDOWN
const CAST_DURATION_SEC := 0.4
const TOP_LIFETIME_SEC := 7.0
const TOP_FADE_SEC := 0.4
const TOP_COLLISION_RADIUS := 20.0
const TOP_COLLISION_COOLDOWN_SEC := 0.14
const TOP_HIT_PUSH_SPEED := 12.0
const TOP_HIT_BOOST_FRAMES := 12.0
const TOP_HIT_SPEED_BOOST := 3.0
const TOP_BALL_SPEED_MULT := 1.50
const WALL_REBOUND_SPEED_MULT := 1.30
const WALL_REBOUND_UPWARD_RATIO_MIN := 0.36
const WALL_REBOUND_UPWARD_RATIO_MAX := 0.68
const WALL_BOOST_PENDING_FRAMES := 120.0
const BOOSTED_BALL_SPEED_CAP_FRAMES := 240.0
const FIELD_WIDTH := 760.0
const WALLWARD_CURVE_VERTICAL_RATIO := 0.85
const WALLWARD_CURVE_ESTIMATED_X_RATIO := 0.82
const WALLWARD_CURVE_MIN_FRAMES := 10.0
const WALLWARD_CURVE_MAX_FRAMES := 80.0

var cooldown_remaining := 0.0
var cooldown_duration := BASE_COOLDOWN_SEC
var cast_remaining := 0.0
var command_step := 0
var _last_up_pressed := false
var tops: Array = []
var player_anchor := Vector2.ZERO
var visual_time := 0.0
var renderer: Object = DaljiVisionChosikRenderer.new()
var _reflection_roll_for_tests: Callable = Callable()
var _pending_wall_boost_side := ""
var _pending_wall_boost_frames := 0.0
var _pending_wall_upward_ratio := WALL_REBOUND_UPWARD_RATIO_MIN
var _pending_pre_top_speed := 0.0
var _wall_curve_vertical_sign := 1.0
var _wall_curve_elapsed_frames := 0.0
var _wall_curve_duration_frames := WALLWARD_CURVE_MIN_FRAMES
var _boosted_ball_speed_cap := 0.0
var _boosted_ball_speed_cap_frames := 0.0
var _boss_guard_restore_effective_speed := 0.0


func update(
	delta: float,
	input_snapshot: Dictionary,
	modifier_pressed: bool,
	player_pos: Vector2,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var safe_delta := maxf(0.0, delta)
	visual_time += safe_delta
	cooldown_remaining = maxf(0.0, cooldown_remaining - safe_delta)
	cast_remaining = maxf(0.0, cast_remaining - safe_delta)
	player_anchor = player_pos + Vector2(
		float(config.get("paddle_width", 155.0)) * 0.5,
		float(config.get("paddle_height", 50.0)) * 0.25
	)
	_advance_tops(safe_delta, config)
	var up_pressed := bool(input_snapshot.get("up_pressed", false))
	var up_edge := up_pressed and not _last_up_pressed
	_last_up_pressed = up_pressed
	if not modifier_pressed:
		_reset_command()
		return {"activated": false, "movement_locked": is_movement_locked()}
	if not _can_listen_for_command(config, deps):
		_reset_command()
		return {"activated": false, "movement_locked": is_movement_locked()}
	if not up_edge:
		return {"activated": false, "movement_locked": is_movement_locked()}
	_reset_command()
	return _activate(config, deps)


func apply_ball_motion(
	ball_pos: Vector2,
	ball_vel: Vector2,
	ball_size: float,
	_boss_pos: Vector2,
	_boss_width: float,
	_boss_height: float,
	last_hit_by: String
) -> Dictionary:
	# Both rally sides can strike the player's tops. Keep unknown/owner-less
	# projections out so scripted ball holds cannot arm a false bank shot.
	var normalized_last_hit_by := last_hit_by.strip_edges().to_lower()
	if normalized_last_hit_by not in ["player", "boss"]:
		return {}
	var collision_distance := TOP_COLLISION_RADIUS + maxf(1.0, ball_size) * 0.5
	for index in range(tops.size()):
		var top := _get_top(index)
		if (
			top.is_empty()
			or not bool(top.get("launched", false))
			or float(top.get("collision_cooldown", 0.0)) > 0.0
			or float(top.get("tilt", 0.0)) > 45.0
		):
			continue
		var top_pos := Vector2(float(top.get("x", 0.0)), float(top.get("y", 0.0)))
		var contact_delta := ball_pos - top_pos
		if contact_delta.length_squared() >= collision_distance * collision_distance:
			continue
		var bank_roll := clampf(_roll_reflection(), 0.0, 1.0)
		var target_side := "left" if bank_roll < 0.5 else "right"
		var side_phase := bank_roll * 2.0 if bank_roll < 0.5 else (bank_roll - 0.5) * 2.0
		var speed := ball_vel.length()
		if speed <= 0.01:
			speed = 8.0
		# Preserve the speed from before the first linked-top contact. A ball can
		# touch the second top before reaching its wall, and the eventual boss
		# guard must remove every accumulated +50% top boost together.
		if _pending_pre_top_speed <= 0.001:
			_pending_pre_top_speed = speed
		speed *= TOP_BALL_SPEED_MULT
		_pending_wall_boost_side = target_side
		_pending_wall_boost_frames = WALL_BOOST_PENDING_FRAMES
		_pending_wall_upward_ratio = lerpf(
			WALL_REBOUND_UPWARD_RATIO_MIN,
			WALL_REBOUND_UPWARD_RATIO_MAX,
			side_phase
		)
		_wall_curve_vertical_sign = 1.0 if top_pos.y < 375.0 else -1.0
		_wall_curve_elapsed_frames = 0.0
		var target_wall_x := 0.0 if target_side == "left" else FIELD_WIDTH
		var distance_to_wall := absf(target_wall_x - top_pos.x)
		_wall_curve_duration_frames = clampf(
			distance_to_wall / maxf(0.001, speed * WALLWARD_CURVE_ESTIMATED_X_RATIO),
			WALLWARD_CURVE_MIN_FRAMES,
			WALLWARD_CURVE_MAX_FRAMES
		)
		var reflection_direction := _get_wallward_curve_direction(target_side, 0.0)
		_open_boosted_ball_speed_cap(speed)

		var push_direction := Vector2.DOWN
		if contact_delta.length_squared() > 0.001:
			push_direction = -contact_delta.normalized()
		top["vx"] = push_direction.x * TOP_HIT_PUSH_SPEED
		top["vy"] = push_direction.y * TOP_HIT_PUSH_SPEED * 0.5
		top["speed_boost"] = TOP_HIT_SPEED_BOOST
		top["boost_timer"] = TOP_HIT_BOOST_FRAMES
		top["launch_boost"] = false
		top["collision_cooldown"] = TOP_COLLISION_COOLDOWN_SEC
		tops[index] = top
		return {
			"ball_pos": top_pos + reflection_direction * (collision_distance + 1.0),
			"ball_vel": reflection_direction * speed,
			"dalji_vision_reflected": true,
			"dalji_vision_impact_pos": top_pos,
		}
	return {}


func consume_wall_rebound_speed_boost(
	ball_vel: Vector2,
	side: String,
	pre_wall_speed: float = -1.0,
	impact_boost: float = 1.0
) -> Dictionary:
	var normalized_side := side.strip_edges().to_lower()
	if (
		_pending_wall_boost_frames <= 0.0
		or _pending_wall_boost_side == ""
		or normalized_side != _pending_wall_boost_side
	):
		return {}
	_pending_wall_boost_side = ""
	_pending_wall_boost_frames = 0.0
	_clear_wallward_curve()
	var source_speed := pre_wall_speed if pre_wall_speed >= 0.0 else ball_vel.length()
	var pre_top_speed := _pending_pre_top_speed if _pending_pre_top_speed > 0.001 else source_speed
	_pending_pre_top_speed = 0.0
	_boss_guard_restore_effective_speed = pre_top_speed * maxf(1.0, impact_boost)
	var boosted_speed := source_speed * WALL_REBOUND_SPEED_MULT
	var away_from_wall_sign := 1.0 if normalized_side == "left" else -1.0
	var boosted_velocity := Vector2(
		away_from_wall_sign,
		-_pending_wall_upward_ratio
	).normalized() * boosted_speed
	_pending_wall_upward_ratio = WALL_REBOUND_UPWARD_RATIO_MIN
	_open_boosted_ball_speed_cap(boosted_velocity.length())
	return {
		"ball_vel": boosted_velocity,
		"dalji_vision_wall_rebound_boosted": true,
	}


func apply_wallward_curve(ball_vel: Vector2, fps_scale: float) -> Vector2:
	if _pending_wall_boost_side == "" or _pending_wall_boost_frames <= 0.0:
		return ball_vel
	var speed := ball_vel.length()
	if speed <= 0.001:
		return ball_vel
	_wall_curve_elapsed_frames = minf(
		_wall_curve_duration_frames,
		_wall_curve_elapsed_frames + maxf(0.0, fps_scale)
	)
	var progress := clampf(
		_wall_curve_elapsed_frames / maxf(0.001, _wall_curve_duration_frames),
		0.0,
		1.0
	)
	return _get_wallward_curve_direction(_pending_wall_boost_side, progress) * speed


func consume_boss_guard_wall_speed_restore_effective_speed() -> float:
	var restore_speed := maxf(0.0, _boss_guard_restore_effective_speed)
	if restore_speed <= 0.001:
		return 0.0
	_boss_guard_restore_effective_speed = 0.0
	_boosted_ball_speed_cap = 0.0
	_boosted_ball_speed_cap_frames = 0.0
	return restore_speed


func advance_ball_motion_modifiers(fps_scale: float) -> void:
	var safe_scale := maxf(0.0, fps_scale)
	if _pending_wall_boost_frames > 0.0:
		_pending_wall_boost_frames = maxf(0.0, _pending_wall_boost_frames - safe_scale)
		if _pending_wall_boost_frames <= 0.0:
			_pending_wall_boost_side = ""
			_pending_wall_upward_ratio = WALL_REBOUND_UPWARD_RATIO_MIN
			_pending_pre_top_speed = 0.0
			_clear_wallward_curve()
	if _boosted_ball_speed_cap_frames > 0.0:
		_boosted_ball_speed_cap_frames = maxf(0.0, _boosted_ball_speed_cap_frames - safe_scale)
		if _boosted_ball_speed_cap_frames <= 0.0:
			_boosted_ball_speed_cap = 0.0
			_boss_guard_restore_effective_speed = 0.0


func get_boosted_ball_speed_cap() -> float:
	if _boosted_ball_speed_cap_frames <= 0.0:
		return 0.0
	return maxf(0.0, _boosted_ball_speed_cap)


func is_movement_locked() -> bool:
	return cast_remaining > 0.0


func is_ready(special_gauge: float, equipped: bool = true) -> bool:
	return equipped and cooldown_remaining <= 0.0 and special_gauge >= COST and cast_remaining <= 0.0


func get_cooldown_ratio() -> float:
	return clampf(cooldown_remaining / maxf(0.001, cooldown_duration), 0.0, 1.0)


func has_visible_effects() -> bool:
	return cast_remaining > 0.0 or not tops.is_empty()


func draw(
	canvas: CanvasItem,
	shake_offset: Vector2 = Vector2.ZERO,
	timer_stack: Object = null
) -> void:
	if renderer != null and has_visible_effects():
		renderer.draw(canvas, get_snapshot(), shake_offset, timer_stack)


func get_active_duration_ratio() -> float:
	return clampf(get_active_duration_remaining_sec() / TOP_LIFETIME_SEC, 0.0, 1.0)


func get_active_duration_remaining_sec() -> float:
	var remaining_sec := 0.0
	for top_value: Variant in tops:
		if not (top_value is Dictionary):
			continue
		var top := top_value as Dictionary
		var lifetime := maxf(0.001, float(top.get("lifetime", TOP_LIFETIME_SEC)))
		remaining_sec = maxf(remaining_sec, lifetime - float(top.get("age", 0.0)))
	return maxf(0.0, remaining_sec)


func get_snapshot() -> Dictionary:
	return {
		"cooldown_remaining": cooldown_remaining,
		"cooldown_ratio": get_cooldown_ratio(),
		"cast_remaining": cast_remaining,
		"command_step": command_step,
		"tops": tops.duplicate(true),
		"player_anchor": player_anchor,
		"visual_time": visual_time,
		"active_duration_ratio": get_active_duration_ratio(),
		"active_duration_remaining_sec": get_active_duration_remaining_sec(),
		"pending_wall_boost_side": _pending_wall_boost_side,
		"pending_wall_boost_frames": _pending_wall_boost_frames,
		"pending_pre_top_speed": _pending_pre_top_speed,
		"wall_curve_elapsed_frames": _wall_curve_elapsed_frames,
		"wall_curve_duration_frames": _wall_curve_duration_frames,
		"boosted_ball_speed_cap": get_boosted_ball_speed_cap(),
		"boss_guard_restore_effective_speed": _boss_guard_restore_effective_speed,
	}


func reset_round() -> void:
	cast_remaining = 0.0
	_reset_command()
	_last_up_pressed = false
	tops.clear()
	_clear_ball_motion_modifiers()


func reset_cooldowns() -> void:
	cooldown_remaining = 0.0


func reduce_all_cooldowns_by_fraction(reduction_fraction: float, _time_now: int = -1) -> int:
	var fraction := clampf(reduction_fraction, 0.0, 0.95)
	if fraction <= 0.0 or cooldown_remaining <= 0.0:
		return 0
	cooldown_remaining = maxf(0.0, cooldown_remaining - cooldown_duration * fraction)
	return 1


func advance_cooldowns_by_msec(bonus_msec: int, _time_now: int = -1) -> int:
	var bonus_seconds := float(maxi(0, bonus_msec)) / 1000.0
	if bonus_seconds <= 0.0 or cooldown_remaining <= 0.0:
		return 0
	cooldown_remaining = maxf(0.0, cooldown_remaining - bonus_seconds)
	return 1


func reset() -> void:
	reset_round()
	cooldown_remaining = 0.0
	cooldown_duration = BASE_COOLDOWN_SEC
	visual_time = 0.0
	_last_up_pressed = false
	_reflection_roll_for_tests = Callable()


func set_reflection_roll_for_tests(callback: Callable) -> void:
	_reflection_roll_for_tests = callback


func _get_wallward_curve_direction(side: String, progress: float) -> Vector2:
	var side_sign := -1.0 if side == "left" else 1.0
	var vertical_ratio := (
		_wall_curve_vertical_sign
		* cos(clampf(progress, 0.0, 1.0) * PI)
		* WALLWARD_CURVE_VERTICAL_RATIO
	)
	return Vector2(side_sign, vertical_ratio).normalized()


func _clear_wallward_curve() -> void:
	_wall_curve_vertical_sign = 1.0
	_wall_curve_elapsed_frames = 0.0
	_wall_curve_duration_frames = WALLWARD_CURVE_MIN_FRAMES


func _can_listen_for_command(config: Dictionary, deps: Dictionary) -> bool:
	if cast_remaining > 0.0 or cooldown_remaining > 0.0:
		return false
	if not bool(config.get("ball_active", false)) or bool(config.get("player_skill_input_locked", false)):
		return false
	var skill_config: Object = deps.get("skill_config", null)
	if skill_config == null or not skill_config.has_method("is_skill_equipped"):
		return false
	if not bool(skill_config.is_skill_equipped(SKILL_ID)):
		return false
	return float(config.get("special_gauge", 0.0)) >= COST


func _activate(config: Dictionary, deps: Dictionary) -> Dictionary:
	cast_remaining = CAST_DURATION_SEC
	var cooldown := BASE_COOLDOWN_SEC
	var skill_config: Object = deps.get("skill_config", null)
	if skill_config != null and skill_config.has_method("get_cooldown_seconds"):
		cooldown = maxf(0.0, float(skill_config.get_cooldown_seconds(SKILL_ID)))
	cooldown_remaining = cooldown
	cooldown_duration = maxf(0.001, cooldown)
	_spawn_tops(player_anchor, maxf(1.0, float(config.get("height", 750.0))))
	var next_gauge := maxf(0.0, float(config.get("special_gauge", 0.0)) - COST)
	var owner: Object = deps.get("owner", null)
	if owner != null:
		owner.set("special_gauge", next_gauge)
	var audio: Object = deps.get("audio", null)
	var dash_state: Object = deps.get("dash_state", null)
	if dash_state != null and dash_state.has_method("cancel_active_without_recovery"):
		dash_state.cancel_active_without_recovery()
	var movement_state: Object = deps.get("movement_state", null)
	if movement_state != null and movement_state.has_method("reset"):
		movement_state.reset()
	if audio != null and audio.has_method("stop_dash_delay"):
		audio.stop_dash_delay()
	if audio != null and audio.has_method("play_whip"):
		audio.play_whip()
	return {"activated": true, "movement_locked": true, "special_gauge": next_gauge}


func _open_boosted_ball_speed_cap(speed: float) -> void:
	_boosted_ball_speed_cap = maxf(_boosted_ball_speed_cap, maxf(0.0, speed))
	_boosted_ball_speed_cap_frames = BOOSTED_BALL_SPEED_CAP_FRAMES


func _clear_ball_motion_modifiers() -> void:
	_pending_wall_boost_side = ""
	_pending_wall_boost_frames = 0.0
	_pending_wall_upward_ratio = WALL_REBOUND_UPWARD_RATIO_MIN
	_pending_pre_top_speed = 0.0
	_clear_wallward_curve()
	_boosted_ball_speed_cap = 0.0
	_boosted_ball_speed_cap_frames = 0.0
	_boss_guard_restore_effective_speed = 0.0


func _spawn_tops(origin: Vector2, field_height: float) -> void:
	tops.clear()
	for index in range(2):
		var offset_x := -18.0 if index == 0 else 18.0
		var top := Stage1DaljiSpinningTopPayloadFactory.build_top(
			origin,
			offset_x,
			index,
			-Stage1DaljiSpinningTopMotion.INITIAL_ROAM_SPEED,
			0.0
		)
		# Spawn inside the exact roaming band. Production player anchors can put
		# origin.y - 48 below this band, causing two launch frames to clamp and
		# flip vertically before the top actually rises.
		top["y"] = minf(
			origin.y - 48.0,
			field_height - Stage1DaljiSpinningTopMotion.BOTTOM_MARGIN
		)
		top["is_golden"] = false
		top["age"] = 0.0
		top["lifetime"] = TOP_LIFETIME_SEC
		top["collision_cooldown"] = 0.0
		Stage1DaljiSpinningTopMotion.apply_launch(top, index, -1.0)
		tops.append(top)


func _advance_tops(delta: float, config: Dictionary) -> void:
	var fps_scale := delta * 60.0
	var width := maxf(1.0, float(config.get("width", 760.0)))
	var height := maxf(1.0, float(config.get("height", 750.0)))
	for index in range(tops.size() - 1, -1, -1):
		var top := _get_top(index)
		if top.is_empty():
			tops.remove_at(index)
			continue
		var age := float(top.get("age", 0.0)) + delta
		var lifetime := float(top.get("lifetime", TOP_LIFETIME_SEC))
		if age >= lifetime:
			tops.remove_at(index)
			continue
		top["age"] = age
		top["collision_cooldown"] = maxf(0.0, float(top.get("collision_cooldown", 0.0)) - delta)
		top["alpha"] = 255.0 * clampf((lifetime - age) / TOP_FADE_SEC, 0.0, 1.0)
		Stage1DaljiSpinningTopMotion.update_running_top(
			top,
			fps_scale,
			width,
			height,
			-1.0,
			true
		)
		tops[index] = top


func _get_top(index: int) -> Dictionary:
	if index < 0 or index >= tops.size() or not (tops[index] is Dictionary):
		return {}
	return tops[index] as Dictionary


func _roll_reflection() -> float:
	if _reflection_roll_for_tests.is_valid():
		return clampf(float(_reflection_roll_for_tests.call()), 0.0, 1.0)
	return randf()


func _reset_command() -> void:
	command_step = 0
