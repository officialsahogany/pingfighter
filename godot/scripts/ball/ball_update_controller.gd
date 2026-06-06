extends RefCounted

const BallContextReader := preload("res://scripts/ball/ball_context_reader.gd")
const BallFrameMotionController := preload("res://scripts/ball/ball_frame_motion_controller.gd")
const BallMotionEventProcessor := preload("res://scripts/ball/ball_motion_event_processor.gd")
const BallRenderInterpolation := preload("res://scripts/ball/ball_render_interpolation.gd")
const ViperAirborneLod := preload("res://scripts/core/viper_airborne_lod.gd")

const STAGE5_HONGRYUN_GUARD_X_SHRINK := 24.0
const STAGE5_HONGRYUN_GUARD_Y_SHRINK := 8.0
const STAGE5_HONGRYUN_GUARD_PADDING_SCALE := 0.5
const STAGE5_HONGRYUN_GUARD_UPWARD_BALL_FACTOR := 0.35
const JUNIOR_POWER_SMASH_SPEED_CAP_MULT := 1.30

var frame_motion_controller: Object = BallFrameMotionController.new()
var motion_event_processor: Object = BallMotionEventProcessor.new()


func update(delta: float, context: Dictionary, deps: Dictionary, callbacks: Dictionary = {}) -> Dictionary:
	var perf_logger: Object = deps.get("perf_logger", null)
	var frame_context_start: int = _perf_begin(perf_logger)
	var frame_context: Dictionary = _build_frame_context(context, deps)
	var frame_deps: Dictionary = _resolve_stage_deps(frame_context, deps)
	var scene: Dictionary = _build_scene_snapshot(frame_context)
	BallRenderInterpolation.begin_physics_step(scene)
	_perf_end(perf_logger, "ball.update.frame_context", frame_context_start)
	var fps_scale: float = delta * 60.0
	if str(frame_context.get("selected_character_type", "smasher")) != "smasher":
		frame_deps["combo_state"] = null
		frame_deps["power_state"] = null
	var power_state: Object = frame_deps.get("power_state", null)

	if _is_stage3_psychoball_hitstop_active(frame_context, frame_deps):
		return _snapshot_result(scene)

	if power_state != null and power_state.is_freeze_active():
		frame_motion_controller.update_power_freeze(delta, scene, frame_context, frame_deps)
		return _snapshot_result(scene)

	if bool(frame_context.get("viper_dmk_freeze_active", false)) or bool(frame_context.get("viper_nerve_strike_freeze_active", false)):
		return _snapshot_result(scene)

	if bool(frame_context.get("stopwatch_freeze_active", false)) or bool(frame_context.get("perk_resume_freeze_active", false)):
		scene["ball_vel"] = Vector2.ZERO
		return _snapshot_result(scene)

	if not bool(frame_context.get("ball_active", false)):
		return {}
	_apply_stage5_ball_motion_hijack(scene, frame_context, frame_deps)

	var power_smashing_parabola_active: bool = power_state != null and power_state.is_parabola_active()
	var ball_speed_recovery_active: bool = (
		bool(frame_context.get("stopwatch_recovery_active", false))
		or bool(frame_context.get("perk_resume_recovery_active", false))
	)
	var motion_apply_start: int = _perf_begin(perf_logger)
	frame_motion_controller.update_serve_collision_cooldowns(scene, fps_scale)
	if not power_smashing_parabola_active and not ball_speed_recovery_active:
		frame_motion_controller.apply_ball_speed_limits(scene, frame_deps)

	frame_motion_controller.apply_impact_decay(scene, fps_scale, frame_deps)
	frame_motion_controller.apply_ball_spin(scene, fps_scale, frame_deps)
	frame_motion_controller.apply_power_motion(scene, fps_scale, frame_context, frame_deps)
	frame_motion_controller.apply_viper_chaos_spear(scene, fps_scale, frame_context, frame_deps)
	if bool(scene.get("skip_ball_motion_step", false)):
		var stage5_hongryun_guarded: bool = _try_release_stage5_hongryun_player_paddle_hit(scene, frame_context, frame_deps, callbacks)
		if not stage5_hongryun_guarded:
			stage5_hongryun_guarded = _try_release_stage5_hongryun_holy_barrier(scene, frame_context, frame_deps)
		if not stage5_hongryun_guarded:
			var stage5_score_event: String = _try_resolve_stage5_hongryun_floor_miss(scene, frame_context, frame_deps)
			if stage5_score_event != "":
				return _snapshot_result(scene, {"score_event": stage5_score_event})
			if not _try_release_viper_chaos_player_paddle_hit(scene, frame_context, frame_deps, callbacks):
				if not _try_update_poseidon_capture(scene, fps_scale, frame_context, frame_deps):
					_tick_shield_kiting_during_motion_skip(scene, fps_scale, frame_context, frame_deps)
					_update_ball_effects(scene, fps_scale, frame_context, frame_deps)
					return _snapshot_result(scene)
				frame_context.merge(scene, true)
		frame_context.merge(scene, true)
		if bool(scene.get("skip_ball_motion_step", false)):
			_tick_shield_kiting_during_motion_skip(scene, fps_scale, frame_context, frame_deps)
			_update_ball_effects(scene, fps_scale, frame_context, frame_deps)
			return _snapshot_result(scene)
	frame_motion_controller.apply_stage1_dalji_whip(scene, fps_scale, frame_context, frame_deps)
	frame_motion_controller.apply_stage1_dalji_spinning_top(scene, fps_scale, frame_context, frame_deps)
	frame_motion_controller.apply_magnum_grip(scene, fps_scale, frame_context, frame_deps)
	frame_motion_controller.apply_active_item_magnet_field(scene, fps_scale, frame_context, frame_deps)
	frame_motion_controller.apply_poseidon_trident(scene, fps_scale, frame_context, frame_deps)
	frame_motion_controller.apply_weather_motion(scene, fps_scale, frame_deps)
	_perf_end(perf_logger, "ball.update.motion_apply", motion_apply_start)
	if bool(scene.get("skip_ball_motion_step", false)):
		_tick_shield_kiting_during_motion_skip(scene, fps_scale, frame_context, frame_deps)
		_update_ball_effects(scene, fps_scale, frame_context, frame_deps)
		return _snapshot_result(scene)
	_apply_stage_background_ball_motion(scene, frame_context, frame_deps, fps_scale)
	var stage1_dalji_whip_controls_speed: bool = bool(scene.get("stage1_dalji_whip_controls_speed", false))

	if power_smashing_parabola_active and not _is_speed_limit_disabled(frame_context):
		frame_motion_controller.apply_power_smash_speed_limit(
			scene,
			_get_power_smash_effective_speed_cap(scene, frame_context, frame_deps)
		)
	elif not stage1_dalji_whip_controls_speed and not ball_speed_recovery_active:
		frame_motion_controller.apply_ball_speed_limits(scene, frame_deps)

	frame_motion_controller.apply_laurel_leaf_shield_collision(scene, frame_context, frame_deps)
	scene["previous_ball_pos"] = _get_vector2(scene, "ball_pos", Vector2.ZERO)
	var motion_step_start: int = _perf_begin(perf_logger)
	var score_event: String = motion_event_processor.step_motion(scene, fps_scale, frame_context, frame_deps, callbacks)
	_perf_end(perf_logger, "ball.update.motion_step", motion_step_start)
	if score_event == "rematch":
		return _snapshot_result(scene, {"round_restart_event": "rematch"})
	if score_event != "":
		return _snapshot_result(scene, {"score_event": score_event})
	var stage_collision_start: int = _perf_begin(perf_logger)
	_process_stage_background_collision(scene, frame_context, frame_deps)
	_process_stage1_balloon_collision(scene, frame_context, frame_deps)
	_process_commando_supply_drop_collision(scene, frame_context, frame_deps)
	_process_commando_firearm_collision(scene, frame_context, frame_deps)
	_process_stage6_tetromino_collision(scene, frame_context, frame_deps)
	frame_motion_controller.apply_smasher_wheel_collision(scene, frame_context, frame_deps)
	frame_motion_controller.apply_shield_kiting_collision(scene, fps_scale, frame_context, frame_deps)
	frame_motion_controller.apply_dash_spirit_collision(scene, frame_context, frame_deps)
	_perf_end(perf_logger, "ball.update.stage_collision", stage_collision_start)
	if power_smashing_parabola_active and not _is_speed_limit_disabled(frame_context):
		frame_motion_controller.apply_power_smash_speed_limit(
			scene,
			_get_power_smash_effective_speed_cap(scene, frame_context, frame_deps)
		)
	elif not stage1_dalji_whip_controls_speed and not ball_speed_recovery_active:
		frame_motion_controller.apply_ball_speed_limits(scene, frame_deps)

	var effects_start: int = _perf_begin(perf_logger)
	_update_ball_effects(scene, fps_scale, frame_context, frame_deps)
	_perf_end(perf_logger, "ball.update.effects", effects_start)
	return _snapshot_result(scene)


func _snapshot_result(scene: Dictionary, extra: Dictionary = {}) -> Dictionary:
	BallRenderInterpolation.finalize_physics_step(scene)
	var result: Dictionary = {"snapshot": scene}
	result.merge(extra, true)
	return result


func _is_stage3_psychoball_hitstop_active(context: Dictionary, deps: Dictionary) -> bool:
	if int(context.get("current_stage", 1)) != 3:
		return false
	var stage3_boss_skill_state: Object = deps.get("stage3_boss_skill_state", null)
	return (
		stage3_boss_skill_state != null
		and stage3_boss_skill_state.has_method("is_psychoball_hitstop_active")
		and bool(stage3_boss_skill_state.is_psychoball_hitstop_active())
	)


func _apply_stage5_ball_motion_hijack(scene: Dictionary, context: Dictionary, deps: Dictionary) -> void:
	if int(context.get("current_stage", 1)) != 5:
		return
	var stage5_hongryun_state: Object = deps.get("stage5_hongryun_state", null)
	if stage5_hongryun_state == null or not stage5_hongryun_state.has_method("should_skip_ball_motion_step"):
		return
	scene["skip_ball_motion_step"] = bool(stage5_hongryun_state.should_skip_ball_motion_step())


func _try_release_stage5_hongryun_player_paddle_hit(
	scene: Dictionary,
	context: Dictionary,
	deps: Dictionary,
	callbacks: Dictionary
) -> bool:
	if int(context.get("current_stage", 1)) != 5:
		return false
	var stage5_hongryun_state: Object = deps.get("stage5_hongryun_state", null)
	if stage5_hongryun_state == null:
		return false
	if stage5_hongryun_state.has_method("is_inferno_active") and not bool(stage5_hongryun_state.is_inferno_active()):
		return false
	var contact: Dictionary = _get_stage5_hongryun_player_paddle_contact(scene, context)
	if contact.is_empty():
		return false

	var ball_pos: Vector2 = _get_vector2(scene, "ball_pos", Vector2.ZERO)
	if stage5_hongryun_state.has_method("resolve_inferno_player_guard"):
		var paddle_x: float = float(contact.get("paddle_x", INF))
		var paddle_w: float = float(contact.get("paddle_w", 0.0))
		var guard_result: Dictionary = stage5_hongryun_state.resolve_inferno_player_guard(ball_pos, deps, paddle_x, paddle_w)
		scene.merge(guard_result, true)

	var controller: Object = deps.get("paddle_bounce_controller", null)
	if controller != null and controller.has_method("bounce"):
		var paddle_context: Dictionary = context.duplicate()
		paddle_context.merge(scene, true)
		var scene_vel: Vector2 = _get_vector2(scene, "ball_vel", Vector2.ZERO)
		var context_vel: Vector2 = _get_vector2(context, "ball_vel", scene_vel)
		if context_vel.length() > scene_vel.length():
			paddle_context["ball_vel"] = context_vel
		var bounce_result: Dictionary = controller.bounce(
			float(contact.get("paddle_x", 0.0)),
			float(contact.get("paddle_w", context.get("paddle_width", 155.0))),
			true,
			paddle_context,
			deps,
			callbacks
		)
		if not bounce_result.is_empty():
			scene.merge(bounce_result, true)
		else:
			_apply_chaos_player_contact_fallback(scene, context, contact)
	else:
		_apply_chaos_player_contact_fallback(scene, context, contact)
	scene["skip_ball_motion_step"] = false
	scene["player_collision_cooldown"] = max(6.0, float(scene.get("player_collision_cooldown", 0.0)))
	if not bool(scene.get("stage5_hongryun_inferno_glance_bounce", false)):
		scene["stage5_hongryun_inferno_guarded"] = true
	return true


func _try_release_stage5_hongryun_holy_barrier(
	scene: Dictionary,
	context: Dictionary,
	deps: Dictionary
) -> bool:
	# 홀리베리어(바닥 무적)는 normal step_motion()의 check_holy_barrier()로 공을
	# 받아내지만, 홍련폭염 trail 공은 ball_hold로 step_motion()을 통째로 우회하므로
	# 그 차단 경로가 닿지 않는다. trail 공이 베리어 띠에 닿으면 여기서 명시적으로
	# 위로 반사하고 inferno를 종료해 normal physics로 되돌린다 (가드/미스 경로와
	# 동일 패턴). 이 가드가 없으면 무적 바닥을 무시하고 floor-miss로 새서 패배한다.
	if int(context.get("current_stage", 1)) != 5:
		return false
	if not bool(context.get("holy_barrier_active", false)):
		return false
	var stage5_hongryun_state: Object = deps.get("stage5_hongryun_state", null)
	if stage5_hongryun_state == null:
		return false
	if stage5_hongryun_state.has_method("is_inferno_active") and not bool(stage5_hongryun_state.is_inferno_active()):
		return false
	if (
		stage5_hongryun_state.has_method("get_ball_hijack_reason")
		and str(stage5_hongryun_state.get_ball_hijack_reason()) != "hongryun_inferno_trail"
	):
		return false
	var ball_size: float = max(1.0, float(context.get("ball_size", 28.6)))
	var ball_pos: Vector2 = _get_vector2(scene, "ball_pos", Vector2.ZERO)
	var ball_vel: Vector2 = _get_vector2(scene, "ball_vel", Vector2.ZERO)
	var width: float = float(context.get("width", 760.0))
	var barrier_y: float = float(context.get("holy_barrier_y", 725.0))
	var barrier_height: float = float(context.get("holy_barrier_height", 20.0))
	var ball_rect := Rect2(ball_pos.x - ball_size * 0.5, ball_pos.y - ball_size * 0.5, ball_size, ball_size)
	var barrier_rect := Rect2(0.0, barrier_y, width, barrier_height)
	if not barrier_rect.intersects(ball_rect):
		return false

	# trail 공은 항상 위(보스 쪽)에서 베리어로 하강해 들어오므로 순간 ball_vel.y가
	# 진동으로 음수여도 -abs()로 위쪽 반사를 보장한다. 속도 게이트를 두면 베리어 띠
	# 하단 프레임에서 놓쳐 floor-miss로 새는 한 프레임 구멍이 생기므로 두지 않는다.
	ball_pos.y = barrier_y - ball_size * 0.5
	scene["ball_pos"] = ball_pos
	scene["ball_vel"] = Vector2(ball_vel.x, -abs(ball_vel.y))
	if stage5_hongryun_state.has_method("resolve_inferno_holy_barrier"):
		var block_result: Dictionary = stage5_hongryun_state.resolve_inferno_holy_barrier(ball_pos, deps)
		scene.merge(block_result, true)
	scene["skip_ball_motion_step"] = false
	scene["player_collision_cooldown"] = max(6.0, float(scene.get("player_collision_cooldown", 0.0)))

	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if active_item_runtime != null and active_item_runtime.has_method("notify_holy_barrier_hit"):
		active_item_runtime.notify_holy_barrier_hit(Vector2(ball_pos.x, barrier_y))
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_wall_hit"):
		audio.play_wall_hit(abs(ball_vel.y))
	return true


func _try_resolve_stage5_hongryun_floor_miss(scene: Dictionary, context: Dictionary, deps: Dictionary) -> String:
	if int(context.get("current_stage", 1)) != 5:
		return ""
	var stage5_hongryun_state: Object = deps.get("stage5_hongryun_state", null)
	if stage5_hongryun_state == null:
		return ""
	if stage5_hongryun_state.has_method("is_inferno_active") and not bool(stage5_hongryun_state.is_inferno_active()):
		return ""
	if (
		stage5_hongryun_state.has_method("get_ball_hijack_reason")
		and str(stage5_hongryun_state.get_ball_hijack_reason()) != "hongryun_inferno_trail"
	):
		return ""
	var ball_size: float = max(1.0, float(context.get("ball_size", 28.6)))
	var field_height: float = max(1.0, float(context.get("height", 750.0)))
	var ball_pos: Vector2 = _get_vector2(scene, "ball_pos", Vector2.ZERO)
	if ball_pos.y + ball_size * 0.5 < field_height - 0.01:
		return ""
	if stage5_hongryun_state.has_method("resolve_inferno_player_miss"):
		var miss_result: Dictionary = stage5_hongryun_state.resolve_inferno_player_miss(ball_pos, deps)
		scene.merge(miss_result, true)
	else:
		scene["skip_ball_motion_step"] = false
		scene["stage5_hongryun_inferno_missed_player"] = true
	return "boss"


func _get_stage5_hongryun_player_paddle_contact(scene: Dictionary, context: Dictionary) -> Dictionary:
	var ball_size: float = max(1.0, float(context.get("ball_size", 28.6)))
	var ball_pos: Vector2 = _get_vector2(scene, "ball_pos", Vector2.ZERO)
	var ball_rect := Rect2(ball_pos - Vector2(ball_size, ball_size) * 0.5, Vector2(ball_size, ball_size))
	var hitbox_padding: float = float(context.get("hitbox_padding", 5.0))
	var guard_padding: float = max(0.0, hitbox_padding * STAGE5_HONGRYUN_GUARD_PADDING_SCALE)
	var player_pos: Vector2 = _get_vector2(context, "player_pos", Vector2.ZERO)
	var player_size: Vector2 = _get_vector2(
		context,
		"player_paddle_size",
		Vector2(float(context.get("paddle_width", 155.0)), float(context.get("paddle_height", 50.0)))
	)
	if player_size.x <= 0.0 or player_size.y <= 0.0:
		return {}
	var x_shrink: float = min(STAGE5_HONGRYUN_GUARD_X_SHRINK, player_size.x * 0.22)
	var y_shrink: float = min(STAGE5_HONGRYUN_GUARD_Y_SHRINK, player_size.y * 0.22)
	var base_rect := Rect2(
		player_pos.x + x_shrink - guard_padding,
		player_pos.y + y_shrink - guard_padding,
		max(1.0, player_size.x - x_shrink * 2.0 + guard_padding * 2.0),
		max(1.0, player_size.y - y_shrink * 2.0 + guard_padding * 2.0)
	)
	var catch_rect := base_rect
	catch_rect.position.y -= ball_size * STAGE5_HONGRYUN_GUARD_UPWARD_BALL_FACTOR
	catch_rect.size.y += ball_size * STAGE5_HONGRYUN_GUARD_UPWARD_BALL_FACTOR
	var collision_rect: Rect2 = _resolve_viper_chaos_player_collision_rect(catch_rect, ball_rect, context)
	if not collision_rect.intersects(ball_rect):
		return {}
	return {
		"paddle_x": player_pos.x,
		"paddle_w": player_size.x,
	}


func _try_update_poseidon_capture(
	scene: Dictionary,
	fps_scale: float,
	context: Dictionary,
	deps: Dictionary
) -> bool:
	var mythic_item_runtime: Object = deps.get("mythic_item_runtime", null)
	if mythic_item_runtime == null or not mythic_item_runtime.has_method("apply_poseidon_wave_to_ball"):
		return false
	if not _is_poseidon_capture_active(mythic_item_runtime):
		return false
	frame_motion_controller.apply_poseidon_trident(scene, fps_scale, context, deps)
	return true


func _tick_shield_kiting_during_motion_skip(
	scene: Dictionary,
	fps_scale: float,
	context: Dictionary,
	deps: Dictionary
) -> void:
	if str(context.get("selected_character_type", "smasher")) != "smasher":
		return
	var shield_kiting_state: Object = deps.get("smasher_shield_kiting_state", null)
	if shield_kiting_state == null or not shield_kiting_state.has_method("update_and_collide"):
		return
	var shield_context: Dictionary = context.duplicate()
	shield_context.merge(scene, true)
	frame_motion_controller.apply_shield_kiting_collision(scene, fps_scale, shield_context, deps)


func _is_poseidon_capture_active(mythic_item_runtime: Object) -> bool:
	if mythic_item_runtime.has_method("get_poseidon_context"):
		var poseidon_context: Variant = mythic_item_runtime.get_poseidon_context()
		if poseidon_context is Dictionary:
			return bool(poseidon_context.get("capture_active", false))
	if mythic_item_runtime.has_method("get_snapshot"):
		var snapshot: Variant = mythic_item_runtime.get_snapshot()
		if snapshot is Dictionary:
			return bool(snapshot.get("poseidon_trident_capture_active", false))
	return false


func _try_release_viper_chaos_player_paddle_hit(
	scene: Dictionary,
	context: Dictionary,
	deps: Dictionary,
	callbacks: Dictionary
) -> bool:
	if str(context.get("selected_character_type", "smasher")) != "viper":
		return false
	var viper_skill_runtime: Object = deps.get("viper_skill_runtime", null)
	if viper_skill_runtime == null or not viper_skill_runtime.has_method("get_snapshot"):
		return false
	var viper_snapshot: Dictionary = viper_skill_runtime.get_snapshot()
	if str(viper_snapshot.get("chaos_state", "")) != "blackhole":
		return false
	var contact: Dictionary = _get_viper_chaos_player_paddle_contact(scene, context)
	if contact.is_empty():
		return false
	if viper_skill_runtime.has_method("release_chaos_blackhole_from_hit"):
		viper_skill_runtime.release_chaos_blackhole_from_hit(deps, context)
	elif viper_skill_runtime.has_method("register_player_ball_contact"):
		viper_skill_runtime.register_player_ball_contact(deps, context)

	var controller: Object = deps.get("paddle_bounce_controller", null)
	if controller != null and controller.has_method("bounce"):
		var paddle_context: Dictionary = context.duplicate()
		paddle_context.merge(scene, true)
		var scene_vel: Vector2 = _get_vector2(scene, "ball_vel", Vector2.ZERO)
		var context_vel: Vector2 = _get_vector2(context, "ball_vel", scene_vel)
		if context_vel.length() > scene_vel.length():
			paddle_context["ball_vel"] = context_vel
		var bounce_result: Dictionary = controller.bounce(
			float(contact.get("paddle_x", 0.0)),
			float(contact.get("paddle_w", context.get("paddle_width", 155.0))),
			true,
			paddle_context,
			deps,
			callbacks
		)
		if not bounce_result.is_empty():
			scene.merge(bounce_result, true)
		else:
			_apply_chaos_player_contact_fallback(scene, context, contact)
	else:
		_apply_chaos_player_contact_fallback(scene, context, contact)
	scene["skip_ball_motion_step"] = false
	scene["player_collision_cooldown"] = max(6.0, float(scene.get("player_collision_cooldown", 0.0)))
	return true


func _get_viper_chaos_player_paddle_contact(scene: Dictionary, context: Dictionary) -> Dictionary:
	var ball_size: float = max(1.0, float(context.get("ball_size", 28.6)))
	var ball_pos: Vector2 = _get_vector2(scene, "ball_pos", Vector2.ZERO)
	var ball_rect := Rect2(ball_pos - Vector2(ball_size, ball_size) * 0.5, Vector2(ball_size, ball_size))
	var hitbox_padding: float = float(context.get("hitbox_padding", 5.0))
	var player_pos: Vector2 = _get_vector2(context, "player_pos", Vector2.ZERO)
	var player_size: Vector2 = _get_vector2(
		context,
		"player_paddle_size",
		Vector2(float(context.get("paddle_width", 155.0)), float(context.get("paddle_height", 50.0)))
	)
	if player_size.x <= 0.0 or player_size.y <= 0.0:
		return {}
	var base_rect := Rect2(
		player_pos.x - hitbox_padding,
		player_pos.y - hitbox_padding,
		player_size.x + hitbox_padding * 2.0,
		player_size.y + hitbox_padding * 2.0
	)
	var collision_rect: Rect2 = _resolve_viper_chaos_player_collision_rect(base_rect, ball_rect, context)
	if not collision_rect.intersects(ball_rect):
		return {}
	return {
		"paddle_x": collision_rect.position.x + hitbox_padding,
		"paddle_w": player_size.x,
	}


func _resolve_viper_chaos_player_collision_rect(base_rect: Rect2, ball_rect: Rect2, context: Dictionary) -> Rect2:
	var mirror_offset_x: float = float(context.get("player_paddle_mirror_offset_x", 0.0))
	if abs(mirror_offset_x) <= 0.01:
		return base_rect
	var mirror_rect := Rect2(base_rect.position + Vector2(mirror_offset_x, 0.0), base_rect.size)
	var base_hit: bool = base_rect.intersects(ball_rect)
	var mirror_hit: bool = mirror_rect.intersects(ball_rect)
	if mirror_hit and not base_hit:
		return mirror_rect
	if base_hit and not mirror_hit:
		return base_rect
	if mirror_hit and base_hit:
		var ball_center: Vector2 = ball_rect.get_center()
		if abs(ball_center.x - mirror_rect.get_center().x) < abs(ball_center.x - base_rect.get_center().x):
			return mirror_rect
	return base_rect


func _apply_chaos_player_contact_fallback(scene: Dictionary, context: Dictionary, contact: Dictionary) -> void:
	var ball_vel: Vector2 = _get_vector2(scene, "ball_vel", Vector2.ZERO)
	var context_vel: Vector2 = _get_vector2(context, "ball_vel", ball_vel)
	if context_vel.length() > ball_vel.length():
		ball_vel = context_vel
	var paddle_x: float = float(contact.get("paddle_x", 0.0))
	var paddle_w: float = max(1.0, float(contact.get("paddle_w", context.get("paddle_width", 155.0))))
	var ball_pos: Vector2 = _get_vector2(scene, "ball_pos", Vector2.ZERO)
	var hit_pos: float = clamp((ball_pos.x - (paddle_x + paddle_w * 0.5)) / (paddle_w * 0.5), -1.0, 1.0)
	var max_angle: float = float(context.get("max_bounce_angle", 60.0))
	var launch_dir := Vector2(0.0, -1.0).rotated(deg_to_rad(hit_pos * max_angle)).normalized()
	var min_speed: float = float(context.get("min_ball_speed", 3.0))
	var max_speed: float = float(context.get("max_ball_speed", 20.0))
	if _is_speed_limit_disabled(context):
		max_speed = INF
	var speed: float = clamp(max(ball_vel.length(), min_speed), min_speed, max_speed)
	scene["ball_vel"] = launch_dir * speed


func _process_stage1_balloon_collision(scene: Dictionary, context: Dictionary, deps: Dictionary) -> void:
	var balloon_event: Object = deps.get("stage1_balloon_event", null)
	if balloon_event == null or not balloon_event.has_method("resolve_ball_collision"):
		return
	balloon_event.resolve_ball_collision(scene, context, deps)


func _process_commando_supply_drop_collision(scene: Dictionary, context: Dictionary, deps: Dictionary) -> void:
	var supply_drop_state: Object = deps.get("commando_supply_drop_state", null)
	if supply_drop_state == null or not supply_drop_state.has_method("resolve_ball_collision"):
		return
	supply_drop_state.resolve_ball_collision(scene, context, deps)


func _process_commando_firearm_collision(scene: Dictionary, context: Dictionary, deps: Dictionary) -> void:
	var firearm_runtime: Object = deps.get("commando_firearm_runtime", null)
	if firearm_runtime == null or not firearm_runtime.has_method("resolve_ball_collision"):
		return
	firearm_runtime.resolve_ball_collision(scene, context, deps)


func _process_stage_background_collision(scene: Dictionary, context: Dictionary, deps: Dictionary) -> void:
	var stage_background: Object = deps.get("stage_background", null)
	if stage_background == null or not stage_background.has_method("resolve_ball_collision"):
		return
	stage_background.resolve_ball_collision(scene, context, deps)


func _process_stage6_tetromino_collision(scene: Dictionary, context: Dictionary, deps: Dictionary) -> void:
	if int(context.get("current_stage", 1)) != 6:
		return
	var stage6_tetriser_state: Object = deps.get("stage6_tetriser_state", null)
	if stage6_tetriser_state == null or not stage6_tetriser_state.has_method("resolve_ball_collision"):
		return
	stage6_tetriser_state.resolve_ball_collision(scene, context, deps)


func _apply_stage_background_ball_motion(
	scene: Dictionary,
	context: Dictionary,
	deps: Dictionary,
	fps_scale: float
) -> void:
	var stage_background: Object = deps.get("stage_background", null)
	if stage_background == null:
		return
	if stage_background.has_method("apply_ball_motion"):
		stage_background.apply_ball_motion(scene, context, deps, fps_scale)
		return
	if stage_background.has_method("apply_quake_ball_motion"):
		stage_background.apply_quake_ball_motion(scene, context, deps, fps_scale)


func _build_frame_context(context: Dictionary, deps: Dictionary) -> Dictionary:
	var frame_context: Dictionary = context.duplicate()
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if active_item_runtime != null and active_item_runtime.has_method("get_ball_collision_context"):
		frame_context.merge(active_item_runtime.get_ball_collision_context(), true)
	var mythic_item_runtime: Object = deps.get("mythic_item_runtime", null)
	if mythic_item_runtime != null and mythic_item_runtime.has_method("get_ball_collision_context"):
		frame_context.merge(mythic_item_runtime.get_ball_collision_context(), true)
	var viper_jetpack_state: Object = deps.get("viper_jetpack_state", null)
	if (
		str(frame_context.get("selected_character_type", "smasher")) == "viper"
		and viper_jetpack_state != null
		and viper_jetpack_state.has_method("get_ball_collision_context")
	):
		frame_context.merge(viper_jetpack_state.get_ball_collision_context(
			_get_vector2(frame_context, "player_pos", Vector2.ZERO),
			_get_vector2(frame_context, "player_paddle_size", Vector2(155.0, 50.0))
		), true)
	var viper_skill_runtime: Object = deps.get("viper_skill_runtime", null)
	if (
		str(frame_context.get("selected_character_type", "smasher")) == "viper"
		and viper_skill_runtime != null
		and viper_skill_runtime.has_method("get_ball_collision_context")
	):
		frame_context.merge(viper_skill_runtime.get_ball_collision_context(), true)
	var runtime_perk_state: Object = deps.get("runtime_perk_state", null)
	if runtime_perk_state != null and runtime_perk_state.has_method("get_ball_resume_context"):
		frame_context.merge(runtime_perk_state.get_ball_resume_context(), true)
	var dash_state: Object = deps.get("dash_state", null)
	if dash_state != null and dash_state.has_method("get_ball_collision_context"):
		frame_context.merge(dash_state.get_ball_collision_context(), true)
	var warp_gate_state: Object = deps.get("smasher_warp_gate_state", null)
	if warp_gate_state != null and warp_gate_state.has_method("get_ball_collision_context"):
		frame_context.merge(warp_gate_state.get_ball_collision_context(
			_get_vector2(frame_context, "player_pos", Vector2.ZERO),
			_get_vector2(frame_context, "player_paddle_size", Vector2(155.0, 50.0))
		), true)
	return frame_context


func _build_scene_snapshot(context: Dictionary) -> Dictionary:
	return {
		"ball_pos": _get_vector2(context, "ball_pos", Vector2.ZERO),
		"ball_pos_prev": _get_vector2(
			context,
			"ball_pos_prev",
			_get_vector2(context, "ball_pos", Vector2.ZERO)
		),
		"ball_interp_reset_requested": bool(context.get("ball_interp_reset_requested", false)),
		"ball_interp_last_physics_usec": int(context.get("ball_interp_last_physics_usec", 0)),
		"ball_render_interpolation_enabled": bool(context.get("ball_render_interpolation_enabled", true)),
		"ball_vel": _get_vector2(context, "ball_vel", Vector2.ZERO),
		"skip_ball_motion_step": bool(context.get("skip_ball_motion_step", false)),
		"ball_impact_boost": float(context.get("ball_impact_boost", 1.0)),
		"ball_boost_decay_rate": float(context.get("ball_boost_decay_rate", 0.975)),
		"ball_min_boost": float(context.get("ball_min_boost", 0.70)),
		"ball_serve_origin": str(context.get("ball_serve_origin", "")),
		"rally_speed_cap_bonus": float(context.get("rally_speed_cap_bonus", 0.0)),
		"player_collision_cooldown": float(context.get("player_collision_cooldown", 0.0)),
		"boss_collision_cooldown": float(context.get("boss_collision_cooldown", 0.0)),
		"vertical_bounce_count": int(context.get("vertical_bounce_count", 0)),
		"ball_spin_strength": float(context.get("ball_spin_strength", 0.0)),
		"ball_spin_direction": int(context.get("ball_spin_direction", 0)),
		"drive_ball_active": bool(context.get("drive_ball_active", false)),
		"drive_hit_boss": bool(context.get("drive_hit_boss", false)),
		"drive_speed_increase": float(context.get("drive_speed_increase", 0.0)),
		"drive_text_timer_frames": float(context.get("drive_text_timer_frames", 0.0)),
		"special_gauge": float(context.get("special_gauge", 0.0)),
		"player_speed": float(context.get("player_speed", 0.0)),
		"boss_vel": float(context.get("boss_vel", 0.0)),
		"commando_bowling_trap_guard_armed": bool(context.get("commando_bowling_trap_guard_armed", false)),
		"commando_bowling_trap_guard_source": str(context.get("commando_bowling_trap_guard_source", "")),
		"commando_bowling_trap_guard_knockback_power": float(context.get("commando_bowling_trap_guard_knockback_power", 0.0)),
		"commando_bowling_trap_guard_stun_frames": float(context.get("commando_bowling_trap_guard_stun_frames", 0.0)),
		"commando_bowling_trap_guard_restore_speed": float(context.get("commando_bowling_trap_guard_restore_speed", 0.0)),
		"commando_suicide_drone_ball_boost_active": bool(context.get("commando_suicide_drone_ball_boost_active", false)),
		"commando_suicide_drone_ball_restore_speed": float(context.get("commando_suicide_drone_ball_restore_speed", 0.0)),
		"commando_suicide_drone_ball_boosted_speed": float(context.get("commando_suicide_drone_ball_boosted_speed", 0.0)),
		"viper_knockback_overlay_active": bool(context.get("viper_knockback_overlay_active", false)),
		"ai_mode": str(context.get("ai_mode", "champion")),
		"speed_limit_disabled": bool(context.get("speed_limit_disabled", false)),
		"max_ball_speed": float(context.get("max_ball_speed", 26.0)),
		"power_smash_max_ball_speed": float(context.get("power_smash_max_ball_speed", 35.0)),
		"impact_boost_max_ball_speed": float(context.get("impact_boost_max_ball_speed", 26.0)),
		"fire_weather_max_ball_speed": float(context.get("fire_weather_max_ball_speed", 35.0)),
		"fire_weather_speed_cap_active": bool(context.get("fire_weather_speed_cap_active", false)),
		"smasher_wheel_speed_cap": float(context.get("smasher_wheel_speed_cap", 0.0)),
	}


func _resolve_stage_deps(context: Dictionary, deps: Dictionary) -> Dictionary:
	var resolved: Dictionary = deps.duplicate()
	var current_stage: int = int(context.get("current_stage", 1))
	var router: Object = deps.get("stage_runtime_router", null)
	var stage_background: Object = null
	if router != null and router.has_method("get_module_key"):
		var key: String = str(router.get_module_key(current_stage, "stage_background"))
		if key != "":
			stage_background = deps.get(key, null)
	if stage_background == null:
		stage_background = deps.get("stage_background", null)
	resolved["stage_background"] = stage_background
	return resolved


func _update_ball_effects(scene: Dictionary, fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	var ball_effects: Object = deps.get("ball_effects", null)
	var ball_intensity: Object = deps.get("ball_intensity", null)
	if ball_effects == null or ball_intensity == null:
		return
	var ball_pos: Vector2 = _get_vector2(scene, "ball_pos", Vector2.ZERO)
	var ball_vel: Vector2 = _get_vector2(scene, "ball_vel", Vector2.ZERO)
	var ball_radius: float = max(
		float(context.get("ball_size", 28.6)) * 0.5,
		float(context.get("ball_render_radius", float(context.get("ball_size", 28.6)) * 0.5))
	)
	var effect_lod_scale: float = ViperAirborneLod.effect_scale(context)
	ball_effects.update_ghost_trail(ball_pos, ball_radius, fps_scale)
	ball_intensity.update_transition(ball_vel, fps_scale)
	ball_effects.update_intensity_particles(
		ball_pos,
		ball_vel,
		fps_scale,
		ball_intensity.calculate(ball_vel),
		ball_intensity.get_current_colors(),
		effect_lod_scale
	)


func _get_power_smash_effective_speed_cap(scene: Dictionary, context: Dictionary, deps: Dictionary = {}) -> float:
	var speed_cap: float = float(context.get("power_smash_max_ball_speed", 35.0))
	if _normalize_league_mode(str(context.get("ai_mode", "champion"))) == "junior":
		speed_cap *= JUNIOR_POWER_SMASH_SPEED_CAP_MULT
	var impact_boost: float = max(1.0, float(scene.get("ball_impact_boost", 1.0)))
	if impact_boost > 1.001:
		speed_cap = max(speed_cap, float(context.get("impact_boost_max_ball_speed", 26.0)))
	speed_cap = max(speed_cap, _get_magnum_grip_speed_cap(deps))
	speed_cap = max(speed_cap, _get_viper_blade_speed_cap(deps))
	if bool(context.get("fire_weather_speed_cap_active", false)):
		speed_cap = min(speed_cap, float(context.get("fire_weather_max_ball_speed", 35.0)))
	return speed_cap


func _normalize_league_mode(ai_mode: String) -> String:
	var normalized: String = ai_mode.strip_edges().to_lower().replace(" ", "").replace("_", "").replace("-", "")
	if normalized == "junior" or normalized == "juniorleague":
		return "junior"
	if normalized == "mythic" or normalized == "mythicleague":
		return "mythic"
	return "champion"


func _is_speed_limit_disabled(context: Dictionary) -> bool:
	return (
		bool(context.get("speed_limit_disabled", false))
		or bool(context.get("commando_suicide_drone_ball_boost_active", false))
	)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return BallContextReader.get_vector2(source, key, fallback)


func _get_magnum_grip_speed_cap(deps: Dictionary) -> float:
	var magnum_state: Object = deps.get("smasher_magnum_grip_state", null)
	if magnum_state == null:
		return 0.0
	var cap := 0.0
	if magnum_state.has_method("get_release_hit_speed_cap"):
		cap = max(cap, float(magnum_state.get_release_hit_speed_cap()))
	if magnum_state.has_method("get_pending_release_hit_speed_cap"):
		cap = max(cap, float(magnum_state.get_pending_release_hit_speed_cap()))
	return cap


func _get_viper_blade_speed_cap(deps: Dictionary) -> float:
	var viper_skill_runtime: Object = deps.get("viper_skill_runtime", null)
	if viper_skill_runtime == null or not viper_skill_runtime.has_method("get_blade_hit_speed_cap"):
		return 0.0
	return float(viper_skill_runtime.get_blade_hit_speed_cap())


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
