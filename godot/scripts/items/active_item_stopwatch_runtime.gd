extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")

const STOPWATCH_DURATION_FRAMES := 120.0
const STOPWATCH_RECOVERY_FRAMES := 60.0
const STOPWATCH_FLASH_FRAMES := 10.0
const STOPWATCH_MIN_SAFE_DISTANCE := 35.0
const STOPWATCH_CLOCK_ADVANCE_PER_FRAME := 0.1
# Why: when recovery finishes on the exact frame the ball is overlapping the
# player paddle moving upward (e.g., the ball ping-ponged inside the paddle
# during the slow recovery), `stopwatch_recovery_active` flips to false on
# the same frame the final-recovery velocity sets the ball to full upward
# speed. The collision detector's upward-catch special case turns off, so
# the ball passes UP through the paddle. This grace window keeps the upward
# catch alive for a short window after recovery ends so the paddle still
# caches the ball.
const STOPWATCH_POST_RECOVERY_GRACE_FRAMES := 12.0


func build_activation_state(owner: Object, registry: Object, player_center: Vector2) -> Dictionary:
	if owner == null:
		return {"activated": false}

	var ball_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "ball_pos", Vector2.ZERO)
	if abs(ball_pos.x - player_center.x) <= STOPWATCH_MIN_SAFE_DISTANCE and abs(ball_pos.y - player_center.y) <= STOPWATCH_MIN_SAFE_DISTANCE:
		return {"activated": false, "blocked_by_safe_distance": true}

	var perk_resume_vel: Vector2 = _consume_perk_resume_velocity(registry)
	var original_ball_vel := perk_resume_vel if perk_resume_vel.length() > 0.01 else BattleSceneOwnerReader.get_vector2(owner, "ball_vel", Vector2.ZERO)
	owner.set("ball_vel", Vector2.ZERO)
	reset_collision_cooldowns(owner)

	return {
		"activated": true,
		"active": true,
		"timer_frames": STOPWATCH_DURATION_FRAMES,
		"initial_timer_frames": STOPWATCH_DURATION_FRAMES,
		"recovery_timer_frames": 0.0,
		"post_recovery_grace_frames": 0.0,
		"original_ball_vel": original_ball_vel,
		"flash_timer_frames": STOPWATCH_FLASH_FRAMES,
		"clock_angle": 0.0,
	}


func clear_state(clock_angle: float = 0.0, post_recovery_grace_frames: float = 0.0) -> Dictionary:
	return _with_update_actions({
		"active": false,
		"timer_frames": 0.0,
		"initial_timer_frames": 0.0,
		"recovery_timer_frames": 0.0,
		"post_recovery_grace_frames": post_recovery_grace_frames,
		"original_ball_vel": Vector2.ZERO,
		"flash_timer_frames": 0.0,
		"clock_angle": clock_angle,
	})


func update_state(
	active: bool,
	timer_frames: float,
	initial_timer_frames: float,
	recovery_timer_frames: float,
	post_recovery_grace_frames: float,
	original_ball_vel: Vector2,
	flash_timer_frames: float,
	clock_angle: float,
	owner_exists: bool,
	delta: float
) -> Dictionary:
	var fps_scale: float = delta * 60.0
	if not active:
		var next_grace_frames: float = max(0.0, post_recovery_grace_frames - fps_scale)
		return _with_update_actions({
			"active": false,
			"timer_frames": 0.0,
			"initial_timer_frames": 0.0,
			"recovery_timer_frames": 0.0,
			"post_recovery_grace_frames": next_grace_frames,
			"original_ball_vel": original_ball_vel,
			"flash_timer_frames": 0.0,
			"clock_angle": clock_angle,
			"fps_scale": fps_scale,
		})

	var next_clock_angle: float = clock_angle + STOPWATCH_CLOCK_ADVANCE_PER_FRAME * fps_scale
	var next_flash_timer: float = max(0.0, flash_timer_frames - fps_scale)
	if not owner_exists:
		var owner_missing_state: Dictionary = clear_state(next_clock_angle, post_recovery_grace_frames)
		owner_missing_state["fps_scale"] = fps_scale
		return owner_missing_state

	if timer_frames > 0.0:
		var next_timer: float = max(0.0, timer_frames - fps_scale)
		var next_recovery_timer: float = STOPWATCH_RECOVERY_FRAMES if next_timer <= 0.0 else recovery_timer_frames
		return _with_update_actions({
			"active": true,
			"timer_frames": next_timer,
			"initial_timer_frames": initial_timer_frames,
			"recovery_timer_frames": next_recovery_timer,
			"post_recovery_grace_frames": 0.0,
			"original_ball_vel": original_ball_vel,
			"flash_timer_frames": next_flash_timer,
			"clock_angle": next_clock_angle,
			"fps_scale": fps_scale,
			"freeze_ball": true,
		})

	if recovery_timer_frames > 0.0:
		var next_recovery: float = max(0.0, recovery_timer_frames - fps_scale)
		var recovery_state: Dictionary
		if next_recovery <= 0.0:
			# Hand the upward-catch grace off to the post-recovery branch so
			# the paddle can still bounce a ball that is overlapping the
			# paddle and moving up on the frame recovery completes.
			recovery_state = clear_state(next_clock_angle, STOPWATCH_POST_RECOVERY_GRACE_FRAMES)
		else:
			recovery_state = _with_update_actions({
				"active": true,
				"timer_frames": 0.0,
				"initial_timer_frames": initial_timer_frames,
				"recovery_timer_frames": next_recovery,
				"post_recovery_grace_frames": 0.0,
				"original_ball_vel": original_ball_vel,
				"flash_timer_frames": next_flash_timer,
				"clock_angle": next_clock_angle,
			})
		recovery_state["fps_scale"] = fps_scale
		recovery_state["apply_recovery_velocity"] = true
		recovery_state["apply_final_recovery_velocity"] = next_recovery <= 0.0
		recovery_state["recovery_timer_for_velocity"] = next_recovery
		recovery_state["recovery_original_ball_vel"] = original_ball_vel
		recovery_state["reset_collision_cooldowns"] = int(ceil(next_recovery)) % 10 == 0
		return recovery_state

	var exhausted_state: Dictionary = clear_state(next_clock_angle, post_recovery_grace_frames)
	exhausted_state["fps_scale"] = fps_scale
	return exhausted_state


func apply_update(
	target: Object,
	owner: Object,
	active: bool,
	timer_frames: float,
	initial_timer_frames: float,
	recovery_timer_frames: float,
	post_recovery_grace_frames: float,
	original_ball_vel: Vector2,
	flash_timer_frames: float,
	clock_angle: float,
	delta: float,
	state_applier: Object,
	owner_effects: Object
) -> void:
	var state: Dictionary = update_state(
		active,
		timer_frames,
		initial_timer_frames,
		recovery_timer_frames,
		post_recovery_grace_frames,
		original_ball_vel,
		flash_timer_frames,
		clock_angle,
		owner != null,
		delta
	)
	owner_effects.apply_update_actions(owner, state, original_ball_vel)
	state_applier.apply_stopwatch_state(target, state)


func reset_collision_cooldowns(owner: Object) -> void:
	if owner == null:
		return
	owner.set("player_collision_cooldown", 0.0)
	owner.set("boss_collision_cooldown", 0.0)


func _with_update_actions(state: Dictionary) -> Dictionary:
	state["freeze_ball"] = bool(state.get("freeze_ball", false))
	state["apply_recovery_velocity"] = bool(state.get("apply_recovery_velocity", false))
	state["apply_final_recovery_velocity"] = bool(state.get("apply_final_recovery_velocity", false))
	state["reset_collision_cooldowns"] = bool(state.get("reset_collision_cooldowns", false))
	state["recovery_timer_for_velocity"] = float(state.get("recovery_timer_for_velocity", 0.0))
	state["recovery_original_ball_vel"] = state.get("recovery_original_ball_vel", Vector2.ZERO)
	state["post_recovery_grace_frames"] = float(state.get("post_recovery_grace_frames", 0.0))
	state["fps_scale"] = float(state.get("fps_scale", 0.0))
	return state


func _consume_perk_resume_velocity(registry: Object) -> Vector2:
	var runtime_perk_state: Object = _get_instance(registry, "runtime_perk_state")
	if runtime_perk_state == null or not runtime_perk_state.has_method("consume_resume_velocity_for_stopwatch"):
		return Vector2.ZERO
	var result: Variant = runtime_perk_state.consume_resume_velocity_for_stopwatch()
	if result is Dictionary:
		return _get_vector2(result, "ball_vel", Vector2.ZERO)
	return Vector2.ZERO


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
