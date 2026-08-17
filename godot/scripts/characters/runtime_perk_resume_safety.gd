extends RefCounted

const RuntimePerkPayloadAccess := preload("res://scripts/characters/runtime_perk_payload_access.gd")
const RuntimePerkRegistryLookup := preload("res://scripts/characters/runtime_perk_registry_lookup.gd")
const RuntimePerkRuntimeStateAccess := preload("res://scripts/characters/runtime_perk_runtime_state_access.gd")

const FREEZE_FRAMES := 10.0
const RECOVERY_FRAMES := 60.0
const MIN_SPEED_RATIO := 0.30

var freeze_timer_frames := 0.0
var recovery_timer_frames := 0.0
var original_ball_vel := Vector2.ZERO
var pre_choice_ball_vel := Vector2.ZERO
var has_original_ball_vel := false
var has_pre_choice_ball_vel := false

var _registry_lookup: Object = RuntimePerkRegistryLookup.new()


func capture_pre_choice_velocity_from_runtime_state(runtime_state: Object, owner: Object) -> void:
	var helper: Object = RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_resume_safety")
	if helper != null and helper.has_method("capture_pre_choice_velocity"):
		helper.capture_pre_choice_velocity(owner)


func try_arm_from_runtime_state(runtime_state: Object, owner: Object, registry: Object) -> void:
	var helper: Object = RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_resume_safety")
	if helper != null and helper.has_method("try_arm"):
		helper.try_arm(owner, registry)


func update_from_runtime_state(runtime_state: Object, owner: Object, registry: Object, delta: float) -> void:
	_refresh_viper_ignition_aura_owner_sync_if_needed(runtime_state, owner, registry)
	var helper: Object = RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_resume_safety")
	if helper != null and helper.has_method("update"):
		helper.update(owner, registry, delta)


func get_context_from_runtime_state(runtime_state: Object) -> Dictionary:
	var helper: Object = RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_resume_safety")
	if helper != null and helper.has_method("get_context"):
		var value: Variant = helper.get_context()
		if value is Dictionary:
			return value
	return {}


func consume_velocity_for_stopwatch_from_runtime_state(runtime_state: Object) -> Dictionary:
	var helper: Object = RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_resume_safety")
	if helper != null and helper.has_method("consume_velocity_for_stopwatch"):
		var value: Variant = helper.consume_velocity_for_stopwatch()
		if value is Dictionary:
			return value
	return {}


func clear_active_from_runtime_state(runtime_state: Object) -> void:
	var helper: Object = RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_resume_safety")
	if helper != null and helper.has_method("clear_active"):
		helper.clear_active()


func clear_pre_choice_from_runtime_state(runtime_state: Object) -> void:
	var helper: Object = RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_resume_safety")
	if helper != null and helper.has_method("clear_pre_choice"):
		helper.clear_pre_choice()


func reset() -> void:
	clear_active()
	clear_pre_choice()


func clear_active() -> void:
	freeze_timer_frames = 0.0
	recovery_timer_frames = 0.0
	original_ball_vel = Vector2.ZERO
	has_original_ball_vel = false


func clear_pre_choice() -> void:
	pre_choice_ball_vel = Vector2.ZERO
	has_pre_choice_ball_vel = false


func capture_pre_choice_velocity(owner: Object) -> void:
	if has_pre_choice_ball_vel:
		return
	var resume_vel: Vector2 = RuntimePerkPayloadAccess.as_finite_vector2(RuntimePerkPayloadAccess.get_value(owner, "ball_vel", Vector2.ZERO))
	if resume_vel.length() < 0.5:
		return
	pre_choice_ball_vel = resume_vel
	has_pre_choice_ball_vel = true


func try_arm(owner: Object, registry: Object) -> void:
	var resume_vel := Vector2.ZERO
	if has_pre_choice_ball_vel:
		resume_vel = RuntimePerkPayloadAccess.as_finite_vector2(pre_choice_ball_vel)
	else:
		resume_vel = RuntimePerkPayloadAccess.as_finite_vector2(RuntimePerkPayloadAccess.get_value(owner, "ball_vel", Vector2.ZERO))
	clear_pre_choice()

	if resume_vel.length() < 0.5:
		return
	if resume_vel.y <= 0.0:
		return
	if _is_stopwatch_active(registry):
		return
	var round_state: Object = _registry_lookup.get_instance(registry, "round_flow_state")
	if round_state != null and round_state.has_method("is_waiting_for_serve") and bool(round_state.is_waiting_for_serve()):
		return
	if freeze_timer_frames > 0.0 or recovery_timer_frames > 0.0:
		return

	original_ball_vel = resume_vel
	has_original_ball_vel = true
	freeze_timer_frames = FREEZE_FRAMES
	recovery_timer_frames = 0.0
	if owner != null:
		owner.set("ball_vel", Vector2.ZERO)
		owner.set(
			"player_collision_cooldown",
			max(float(RuntimePerkPayloadAccess.get_value(owner, "player_collision_cooldown", 0.0)), FREEZE_FRAMES + 4.0)
		)


func update(owner: Object, registry: Object, delta: float) -> void:
	if freeze_timer_frames <= 0.0 and recovery_timer_frames <= 0.0:
		return
	if _is_stopwatch_active(registry):
		reset()
		return
	# Release the moment the ball is moving UP. The safety only ever arms for a
	# ball descending toward the player, so once a paddle bounce or an attack
	# skill sends the ball upward there is nothing left to protect.
	var live_ball_vel: Vector2 = RuntimePerkPayloadAccess.as_finite_vector2(RuntimePerkPayloadAccess.get_value(owner, "ball_vel", Vector2.ZERO))
	if live_ball_vel.y < -0.01:
		reset()
		return

	var fps_scale: float = max(0.001, delta * 60.0)
	if freeze_timer_frames > 0.0:
		freeze_timer_frames = max(0.0, freeze_timer_frames - fps_scale)
		if owner != null:
			owner.set("ball_vel", Vector2.ZERO)
			owner.set(
				"player_collision_cooldown",
				max(float(RuntimePerkPayloadAccess.get_value(owner, "player_collision_cooldown", 0.0)), freeze_timer_frames + 4.0)
			)
		if freeze_timer_frames <= 0.0:
			# 프리즈 동안 ball_update_controller는 쿨다운 감소보다 먼저 조기 반환하므로
			# player_collision_cooldown이 한 프레임도 줄지 않는다. 그래서 arm 시점의
			# 의도(FREEZE_FRAMES + 4 = 총 14프레임 차단)가 실제로는 프리즈 10 + 14 =
			# 약 24프레임으로 부풀고, 그 뒷구간은 공이 다시 움직이는데 패들만 못 닿는
			# "막을 수도 없고 득점 차단도 없는" 창이 된다. 프리즈가 끝나는 순간
			# 남은 차단을 의도한 +4프레임으로 정규화한다.
			if owner != null:
				owner.set(
					"player_collision_cooldown",
					min(float(RuntimePerkPayloadAccess.get_value(owner, "player_collision_cooldown", 0.0)), 4.0)
				)
			recovery_timer_frames = RECOVERY_FRAMES
			_apply_recovery_velocity(owner, MIN_SPEED_RATIO)
		return

	if recovery_timer_frames > 0.0:
		recovery_timer_frames = max(0.0, recovery_timer_frames - fps_scale)
		var recovery_ratio: float = 1.0 - (recovery_timer_frames / max(1.0, RECOVERY_FRAMES))
		_apply_recovery_velocity(owner, max(MIN_SPEED_RATIO, recovery_ratio))
		if recovery_timer_frames <= 0.0:
			_apply_recovery_velocity(owner, 1.0)
			has_original_ball_vel = false
			original_ball_vel = Vector2.ZERO


func get_context() -> Dictionary:
	return {
		"perk_resume_score_blocking": freeze_timer_frames > 0.0,
		"perk_resume_freeze_active": freeze_timer_frames > 0.0,
		"perk_resume_recovery_active": recovery_timer_frames > 0.0,
		"perk_resume_recovery_speed_ratio": _get_recovery_speed_ratio(),
		"perk_resume_original_ball_vel": original_ball_vel if has_original_ball_vel else Vector2.ZERO,
	}


func consume_velocity_for_stopwatch() -> Dictionary:
	var resume_vel := Vector2.ZERO
	if has_original_ball_vel:
		resume_vel = original_ball_vel
	elif has_pre_choice_ball_vel:
		resume_vel = pre_choice_ball_vel
	if resume_vel.length() <= 0.01:
		return {}
	reset()
	return {"ball_vel": resume_vel}


func _apply_recovery_velocity(owner: Object, speed_ratio: float) -> void:
	if owner == null or not has_original_ball_vel:
		return
	var original_speed: float = original_ball_vel.length()
	if original_speed <= 0.01:
		return
	var current_vel: Vector2 = RuntimePerkPayloadAccess.as_finite_vector2(RuntimePerkPayloadAccess.get_value(owner, "ball_vel", Vector2.ZERO))
	var direction: Vector2
	if current_vel.length() > 0.01:
		direction = current_vel.normalized()
	elif original_ball_vel.length() > 0.01:
		direction = original_ball_vel.normalized()
	else:
		direction = Vector2(0.0, 1.0)
	owner.set("ball_vel", direction * original_speed * clamp(speed_ratio, 0.0, 1.0))


func _get_recovery_speed_ratio() -> float:
	if recovery_timer_frames <= 0.0:
		return 1.0
	var recovery_ratio: float = 1.0 - (recovery_timer_frames / max(1.0, RECOVERY_FRAMES))
	return max(MIN_SPEED_RATIO, recovery_ratio)


func _is_stopwatch_active(registry: Object) -> bool:
	var active_item_runtime: Object = _registry_lookup.get_instance(registry, "active_item_runtime")
	if active_item_runtime == null:
		return false
	if active_item_runtime.has_method("get_ball_collision_context"):
		var context: Dictionary = active_item_runtime.get_ball_collision_context()
		return bool(context.get("stopwatch_score_blocking", false))
	return false


func _refresh_viper_ignition_aura_owner_sync_if_needed(
	runtime_state: Object,
	owner: Object,
	registry: Object
) -> void:
	var dynamic_effects: Object = RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_dynamic_effects")
	if dynamic_effects != null and dynamic_effects.has_method("refresh_viper_ignition_aura_owner_sync_if_needed_from_runtime_state"):
		dynamic_effects.refresh_viper_ignition_aura_owner_sync_if_needed_from_runtime_state(runtime_state, registry, owner)
