extends RefCounted

const BallContextReader := preload("res://scripts/ball/ball_context_reader.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")

const OVERDRIVE_REFLECTION_EVENTS := {
	"wall": true,
	"sand_terrain": true,
	"brick_wall": true,
	"trampoline": true,
	"campfire": true,
	"horn_strawberry_field": true,
	"lingpet_bone_barrier": true,
	"holy_barrier": true,
	"adversity_armor": true,
	"player_paddle": true,
	"boss_paddle": true,
}

var _character_runtime: Object = PlayerCharacterRuntime.new()


func step_motion(
	scene: Dictionary,
	fps_scale: float,
	context: Dictionary,
	deps: Dictionary,
	callbacks: Dictionary
) -> String:
	var motion_stepper = deps.get("motion_stepper", null)
	if motion_stepper == null:
		return ""

	var step_result: Dictionary = motion_stepper.step(
		_get_vector2(scene, "ball_pos", Vector2.ZERO),
		_get_vector2(scene, "ball_vel", Vector2.ZERO) * float(scene.get("ball_impact_boost", 1.0)) * fps_scale * float(context.get("ball_motion_step_multiplier", 1.0)),
		_get_vector2(scene, "ball_vel", Vector2.ZERO),
		_build_step_context(context, scene, deps)
	)
	scene["ball_pos"] = _get_vector2(step_result, "ball_pos", _get_vector2(scene, "ball_pos", Vector2.ZERO))

	var event: String = str(step_result.get("event", "none"))
	var outcome := ""
	var overdrive_reflection: bool = OVERDRIVE_REFLECTION_EVENTS.has(event)
	if event == "wall":
		if _process_wall(step_result, scene, context, deps):
			outcome = "rematch"
	elif event == "sand_terrain":
		_process_sand_terrain(step_result, scene, deps)
	elif event == "brick_wall":
		_process_brick_wall(step_result, scene, context, deps)
	elif event == "trampoline":
		_process_trampoline(step_result, scene, context, deps)
	elif event == "campfire":
		_process_campfire(step_result, scene, context, deps)
	elif event == "horn_strawberry_field":
		_process_horn_strawberry_field(step_result, scene, deps)
	elif event == "lingpet_bone_barrier":
		_process_lingpet_bone_barrier(step_result, scene, deps)
	elif event == "holy_barrier":
		_process_holy_barrier(step_result, scene, context, deps)
	elif event == "adversity_armor":
		_process_adversity_armor(step_result, scene, deps)
	elif event == "stage7_wind_aura":
		_process_stage7_wind_aura(step_result, scene)
	elif event == "player_paddle" or event == "boss_paddle":
		# 패들 이벤트의 오버드라이브 반사는 이벤트명 선판정이 아니라 실제
		# 반사 커밋 여부로 게이트한다 — 무형화 무시·컨트롤러 부재·빈 결과에서
		# 가짜 반사 통지가 나가지 않도록.
		overdrive_reflection = _process_paddle(step_result, scene, context, deps, callbacks)
		if bool(step_result.get("warp_gate_afterimage_hit", false)):
			overdrive_reflection = false
	elif event == "player_scored":
		_close_perk_fusion_overload_cap(scene)
		if _process_stage2_quake_boss_backstop(scene, context, deps):
			overdrive_reflection = true
		else:
			outcome = "player"
	elif event == "boss_scored":
		_close_perk_fusion_overload_cap(scene)
		outcome = "boss"
	if overdrive_reflection:
		_notify_smasher_overdrive_reflection(
			scene,
			_get_vector2(step_result, "impact_pos", _get_vector2(scene, "ball_pos", Vector2.ZERO)),
			deps
		)
	return outcome


func _process_sand_terrain(step_result: Dictionary, scene: Dictionary, deps: Dictionary) -> void:
	scene["ball_pos"] = _get_vector2(step_result, "ball_pos", _get_vector2(scene, "ball_pos", Vector2.ZERO))
	scene["ball_vel"] = _get_vector2(step_result, "ball_vel", _get_vector2(scene, "ball_vel", Vector2.ZERO))
	var impact_speed: float = float(step_result.get("impact_speed", scene["ball_vel"].length()))
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_wall_hit"):
		audio.play_wall_hit(impact_speed)
	var ball_effects: Object = deps.get("ball_effects", null)
	if ball_effects != null and ball_effects.has_method("register_hit_pulse"):
		ball_effects.register_hit_pulse(
			_get_vector2(step_result, "impact_pos", _get_vector2(scene, "ball_pos", Vector2.ZERO)),
			_get_vector2(scene, "ball_vel", Vector2.ZERO),
			0.42,
			"sand_terrain"
		)


func _process_stage7_wind_aura(step_result: Dictionary, scene: Dictionary) -> void:
	scene["ball_pos"] = _get_vector2(step_result, "ball_pos", _get_vector2(scene, "ball_pos", Vector2.ZERO))
	scene["ball_vel"] = _get_vector2(step_result, "ball_vel", _get_vector2(scene, "ball_vel", Vector2.ZERO))


func _build_step_context(context: Dictionary, scene: Dictionary, deps: Dictionary) -> Dictionary:
	var step_context: Dictionary = {
		"ball_size": float(context.get("ball_size", 28.6)),
		"width": float(context.get("width", 760.0)),
		"height": float(context.get("height", 750.0)),
		"max_step_distance": float(context.get("max_step_distance", 12.0)),
		"player_pos": _get_vector2(context, "player_pos", Vector2.ZERO),
		"player_paddle_size": _get_vector2(context, "player_paddle_size", Vector2.ZERO),
		"boss_pos": _get_vector2(context, "boss_pos", Vector2.ZERO),
		"boss_paddle_size": _get_vector2(context, "boss_paddle_size", Vector2.ZERO),
		"hitbox_padding": float(context.get("hitbox_padding", 5.0)),
		"viper_dark_blade_rising_contact_active": bool(context.get("viper_dark_blade_rising_contact_active", false)),
		"warp_gate_active": bool(context.get("warp_gate_active", false)),
		"player_paddle_mirror_offset_x": float(context.get("player_paddle_mirror_offset_x", 0.0)),
		"warp_gate_afterimage_rects": context.get("warp_gate_afterimage_rects", []),
		"dash_acceleration_active": bool(context.get("dash_acceleration_active", false)),
		"dash_acceleration_width_bonus": maxf(0.0, float(context.get("dash_acceleration_width_bonus", 0.0))),
		"dash_acceleration_height_bonus": maxf(0.0, float(context.get("dash_acceleration_height_bonus", 0.0))),
		"player_collision_cooldown": float(scene.get("player_collision_cooldown", 0.0)),
		"player_guard_available": bool(context.get("player_guard_available", true)),
		"boss_collision_cooldown": float(scene.get("boss_collision_cooldown", 0.0)),
		"stopwatch_score_blocking": bool(context.get("stopwatch_score_blocking", false)),
		"stopwatch_recovery_active": bool(context.get("stopwatch_recovery_active", false)),
		"perk_resume_score_blocking": bool(context.get("perk_resume_score_blocking", false)),
		"lingpet_star_coil_freeze_boss_skill_cd": bool(context.get(
			"lingpet_star_coil_freeze_boss_skill_cd",
			false
		)),
		"weather_event_state": deps.get("weather_event_state", null),
	}
	step_context["stage7_akamu_state"] = deps.get(
		"stage7_akamu_state",
		context.get("stage7_akamu_state", null)
	)
	step_context["stage7_akamu_audio"] = deps.get(
		"audio",
		context.get("stage7_akamu_audio", null)
	)
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if active_item_runtime != null and active_item_runtime.has_method("get_ball_collision_context"):
		step_context.merge(active_item_runtime.get_ball_collision_context(), true)
	if (
		step_context.get("stage7_akamu_state", null) != null
		and active_item_runtime != null
		and active_item_runtime.has_method("get_boss_ai_context")
	):
		var active_item_boss_context: Dictionary = active_item_runtime.get_boss_ai_context()
		if active_item_boss_context.has("active_item_tear_gas_cooldown_pause_active"):
			step_context["active_item_tear_gas_cooldown_pause_active"] = active_item_boss_context[
				"active_item_tear_gas_cooldown_pause_active"
			]
		if active_item_boss_context.has("active_item_boss_skill_cooldown_paused"):
			step_context["active_item_boss_skill_cooldown_paused"] = active_item_boss_context[
				"active_item_boss_skill_cooldown_paused"
			]
	var mythic_item_runtime: Object = deps.get("mythic_item_runtime", null)
	if mythic_item_runtime != null and mythic_item_runtime.has_method("get_ball_collision_context"):
		step_context.merge(mythic_item_runtime.get_ball_collision_context(), true)
	var lingpet_egg_runtime: Object = deps.get("lingpet_egg_runtime", null)
	if lingpet_egg_runtime != null and lingpet_egg_runtime.has_method("get_ball_collision_context"):
		step_context.merge(lingpet_egg_runtime.get_ball_collision_context(), true)
	if context.has("player_guard_available"):
		step_context["player_guard_available"] = bool(context.get("player_guard_available", true))
	if context.has("viper_dual_glitch_state"):
		step_context["viper_dual_glitch_state"] = str(context.get("viper_dual_glitch_state", "idle"))
	if context.has("viper_dual_glitch_clone_rects"):
		step_context["viper_dual_glitch_clone_rects"] = context.get("viper_dual_glitch_clone_rects", [])
	var viper_skill_runtime: Object = deps.get("viper_skill_runtime", null)
	if (
		not step_context.has("viper_dual_glitch_clone_rects")
		and _is_selected_character(context, "smasher", "viper")
		and viper_skill_runtime != null
		and viper_skill_runtime.has_method("get_ball_collision_context")
	):
		var viper_collision_context: Dictionary = viper_skill_runtime.get_ball_collision_context()
		if viper_collision_context.has("player_guard_available"):
			step_context["player_guard_available"] = bool(viper_collision_context.get("player_guard_available", true))
		if viper_collision_context.has("viper_dual_glitch_state"):
			step_context["viper_dual_glitch_state"] = str(viper_collision_context.get("viper_dual_glitch_state", "idle"))
		if viper_collision_context.has("viper_dual_glitch_clone_rects"):
			step_context["viper_dual_glitch_clone_rects"] = viper_collision_context.get("viper_dual_glitch_clone_rects", [])
	if _is_selected_character(context, "smasher", "blacksmith"):
		var blacksmith_shield_state: Object = deps.get("blacksmith_thor_shield_state", null)
		if blacksmith_shield_state != null and blacksmith_shield_state.has_method("get_ball_collision_context"):
			step_context.merge(blacksmith_shield_state.get_ball_collision_context(step_context), true)
	return step_context


func _is_selected_character(context: Dictionary, fallback: String, target: String) -> bool:
	var value: Variant = context.get("selected_character_type", fallback)
	if str(value).strip_edges() == "":
		return false
	return _character_runtime.normalize(value) == target


func _process_wall(step_result: Dictionary, scene: Dictionary, context: Dictionary, deps: Dictionary) -> bool:
	var controller = deps.get("wall_bounce_controller", null)
	if controller == null:
		return false
	var impact_pos: Vector2 = _get_vector2(step_result, "impact_pos", _get_vector2(scene, "ball_pos", Vector2.ZERO))
	var result: Dictionary = controller.process(
		_get_vector2(scene, "ball_vel", Vector2.ZERO),
		float(scene.get("ball_impact_boost", 1.0)),
		str(step_result.get("side", "")),
		impact_pos,
		float(context.get("height", 750.0)),
		{
			"audio": deps.get("audio", null),
			"impact_effects": deps.get("impact_effects", null),
			"ball_effects": deps.get("ball_effects", null),
			"stage_background": deps.get("stage_background", null),
			"feedback": deps.get("feedback", null),
			"dalji_vision_chosik_state": deps.get("dalji_vision_chosik_state", null),
		}
	)
	scene.merge(result, true)
	if not bool(result.get("rematch_requested", false)):
		_record_highlight_wall_hit(impact_pos, deps)
		_notify_power_smash_wall_bounce(step_result, deps)
		_apply_chargebag_wall_gauge(scene, context, deps)
		# 황금 궤적: 해소된 벽 바운스마다 정확 1회 — 0 지급이어도 부산물
		# 런타임의 캡/쿼리 상태는 전진한다(캡 클램프·라운드 잔여는 런타임
		# award 트랜잭션이 소유).
		var fusion_runtime: Object = deps.get("runtime_perk_state", null)
		if fusion_runtime != null and fusion_runtime.has_method("award_perk_fusion_wall_bounce_gold"):
			var awarded_gold: int = int(fusion_runtime.award_perk_fusion_wall_bounce_gold({}, deps))
			# 패들 타구 골드와 같은 볼 스냅샷 채널로 누적값을 반환해야 HUD와
			# 스테이지 클리어 정산 owner가 다음 타구를 기다리지 않고 갱신된다.
			if awarded_gold > 0 and fusion_runtime.has_method("get_runtime_perk_gold_total"):
				scene["runtime_perk_gold"] = int(fusion_runtime.get_runtime_perk_gold_total())
	return bool(result.get("rematch_requested", false))


func _process_holy_barrier(step_result: Dictionary, scene: Dictionary, context: Dictionary, deps: Dictionary) -> void:
	var ball_vel: Vector2 = _get_vector2(scene, "ball_vel", Vector2.ZERO)
	var reflected_vel := Vector2(ball_vel.x, -abs(ball_vel.y))
	var whip_state: Object = deps.get("stage1_dalji_whip_skill_state", null)
	if whip_state != null and whip_state.has_method("register_player_hit"):
		var whip_result: Dictionary = whip_state.register_player_hit(reflected_vel, context)
		if not whip_result.is_empty():
			reflected_vel = _get_vector2(whip_result, "ball_vel", reflected_vel)
			scene["ball_impact_boost"] = float(whip_result.get("ball_impact_boost", scene.get("ball_impact_boost", 1.0)))
			scene["ball_boost_decay_rate"] = float(whip_result.get("ball_boost_decay_rate", scene.get("ball_boost_decay_rate", 0.975)))
			scene["ball_min_boost"] = float(whip_result.get("ball_min_boost", scene.get("ball_min_boost", 0.70)))
			if bool(whip_result.get("whip_deactivated", false)):
				scene["stage1_dalji_whip_controls_speed"] = false
	scene["ball_vel"] = reflected_vel
	scene["ball_pos"] = _get_vector2(step_result, "ball_pos", _get_vector2(scene, "ball_pos", Vector2.ZERO))

	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_wall_hit"):
		audio.play_wall_hit(abs(ball_vel.y))

	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if active_item_runtime != null and active_item_runtime.has_method("notify_holy_barrier_hit"):
		active_item_runtime.notify_holy_barrier_hit(_get_vector2(step_result, "impact_pos", _get_vector2(scene, "ball_pos", Vector2.ZERO)))
	_register_ball_hit_pulse(step_result, scene, deps, "holy_barrier", 0.72)


func _process_horn_strawberry_field(step_result: Dictionary, scene: Dictionary, deps: Dictionary) -> void:
	var original_vel: Vector2 = _get_vector2(scene, "ball_vel", Vector2.ZERO)
	var built := bool(step_result.get("built", true))
	scene["ball_vel"] = _get_vector2(step_result, "ball_vel", original_vel)
	scene["ball_pos"] = _get_vector2(step_result, "ball_pos", _get_vector2(scene, "ball_pos", Vector2.ZERO))

	var mythic_item_runtime: Object = deps.get("mythic_item_runtime", null)
	if mythic_item_runtime != null and mythic_item_runtime.has_method("notify_horn_strawberry_field_hit"):
		mythic_item_runtime.notify_horn_strawberry_field_hit(
			int(step_result.get("barrier_id", 0)),
			_get_vector2(step_result, "impact_pos", _get_vector2(scene, "ball_pos", Vector2.ZERO)),
			deps
		)
	_register_ball_hit_pulse(step_result, scene, deps, "horn_strawberry_field", 0.72 if built else 0.38)


func _process_lingpet_bone_barrier(step_result: Dictionary, scene: Dictionary, deps: Dictionary) -> void:
	var original_vel: Vector2 = _get_vector2(scene, "ball_vel", Vector2.ZERO)
	var built := bool(step_result.get("built", true))
	var next_vel := _get_vector2(step_result, "ball_vel", original_vel)
	scene["ball_vel"] = next_vel
	scene["ball_pos"] = _get_vector2(step_result, "ball_pos", _get_vector2(scene, "ball_pos", Vector2.ZERO))

	var lingpet_runtime: Object = deps.get("lingpet_egg_runtime", null)
	if lingpet_runtime != null and lingpet_runtime.has_method("notify_lingpet_bone_barrier_hit"):
		lingpet_runtime.notify_lingpet_bone_barrier_hit(
			int(step_result.get("barrier_id", 0)),
			_get_vector2(step_result, "impact_pos", _get_vector2(scene, "ball_pos", Vector2.ZERO)),
			next_vel,
			built,
			deps.get("registry", null)
		)
	_register_ball_hit_pulse(step_result, scene, deps, "lingpet_bone_barrier", 0.72 if built else 0.38)


func _process_adversity_armor(step_result: Dictionary, scene: Dictionary, deps: Dictionary) -> void:
	var ball_vel: Vector2 = _get_vector2(scene, "ball_vel", Vector2.ZERO)
	var reflected_y: float = -max(abs(ball_vel.y), 8.0)
	scene["ball_vel"] = Vector2(ball_vel.x, reflected_y)
	scene["ball_pos"] = _get_vector2(step_result, "ball_pos", _get_vector2(scene, "ball_pos", Vector2.ZERO))
	var mythic_item_runtime: Object = deps.get("mythic_item_runtime", null)
	# 역경의갑주 배리어는 built 상태를 쓰지 않는다(무적 게이팅만; 펄스 0.78 고정).
	# 형제 처리기(뿔딸기 장판·링펫 뼈 배리어)에서 복붙된 4번째 built 인자는
	# 3인자 계약(impact_pos, ball_vel, deps)에 없어 런타임 크래시였다.
	if mythic_item_runtime != null and mythic_item_runtime.has_method("notify_adversity_armor_barrier_hit"):
		mythic_item_runtime.notify_adversity_armor_barrier_hit(
			_get_vector2(step_result, "impact_pos", _get_vector2(scene, "ball_pos", Vector2.ZERO)),
			ball_vel,
			deps
		)
	_register_ball_hit_pulse(step_result, scene, deps, "adversity_armor", 0.78)


func _process_brick_wall(step_result: Dictionary, scene: Dictionary, context: Dictionary, deps: Dictionary) -> void:
	var ball_vel: Vector2 = _get_vector2(scene, "ball_vel", Vector2.ZERO)
	scene["ball_vel"] = Vector2(ball_vel.x * 0.8, -abs(ball_vel.y))
	scene["ball_pos"] = _get_vector2(step_result, "ball_pos", _get_vector2(scene, "ball_pos", Vector2.ZERO))

	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	var hit_result: Dictionary = {}
	if active_item_runtime != null and active_item_runtime.has_method("notify_brick_wall_hit"):
		hit_result = active_item_runtime.notify_brick_wall_hit(
			int(step_result.get("wall_index", -1)),
			_get_vector2(step_result, "impact_pos", _get_vector2(scene, "ball_pos", Vector2.ZERO))
		)

	var audio: Object = deps.get("audio", null)
	if audio != null:
		if bool(hit_result.get("destroyed", false)) and audio.has_method("play_brick_wall_destroy"):
			audio.play_brick_wall_destroy()
		elif audio.has_method("play_wall_hit"):
			audio.play_wall_hit(abs(ball_vel.y))

	if bool(hit_result.get("destroyed", false)):
		var feedback: Object = deps.get("feedback", null)
		if feedback != null and feedback.has_method("max_screen_shake"):
			feedback.max_screen_shake(0.035, 1.1)
	_apply_chargebag_wall_gauge(scene, context, deps)
	_register_ball_hit_pulse(step_result, scene, deps, "brick_wall", 0.58)


func _process_trampoline(step_result: Dictionary, scene: Dictionary, context: Dictionary, deps: Dictionary) -> void:
	var ball_vel: Vector2 = _get_vector2(scene, "ball_vel", Vector2.ZERO)
	var ball_pos: Vector2 = _get_vector2(step_result, "ball_pos", _get_vector2(scene, "ball_pos", Vector2.ZERO))
	# Any trampoline contact is a successful player-side floor save: release
	# the Dalji whip like the holy barrier / lingpet guard precedents, or the
	# still-active whip flips the launch back down every frame (launch-nullify
	# recapture loop that defers the floor loss until the mat expires). Keep
	# the trampoline's own velocities — the whip guard-counter clamp would
	# swallow the slingshot launch overspeed.
	var whip_state: Object = deps.get("stage1_dalji_whip_skill_state", null)
	if whip_state != null and whip_state.has_method("register_player_hit"):
		var whip_result: Dictionary = whip_state.register_player_hit(ball_vel, context)
		if bool(whip_result.get("whip_deactivated", false)):
			scene["stage1_dalji_whip_controls_speed"] = false
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	var hit_result: Dictionary = {}
	if active_item_runtime != null and active_item_runtime.has_method("notify_trampoline_hit"):
		hit_result = active_item_runtime.notify_trampoline_hit(
			int(step_result.get("trampoline_index", -1)),
			ball_pos,
			ball_vel
		)
	scene["ball_pos"] = ball_pos

	var audio: Object = deps.get("audio", null)
	var phase: String = str(hit_result.get("phase", ""))
	if phase == "catch" or phase == "sinking" or phase == "hold":
		scene["ball_vel"] = _get_vector2(hit_result, "ball_vel", ball_vel)
		if phase == "catch" and audio != null and audio.has_method("play_trampoline_catch"):
			audio.play_trampoline_catch()
		return

	# "launch" — and the defensive fallback when the runtime is missing.
	var launch_velocity: Vector2 = _get_vector2(hit_result, "bounce_velocity", Vector2(ball_vel.x, -max(abs(ball_vel.y), 9.0)))
	scene["ball_vel"] = launch_velocity
	# The slingshot launch may exceed the global ball speed cap by up to 30%;
	# raise the cap key consumed by ball_frame_motion_controller so the
	# per-frame clamp does not silently swallow the overspeed. The frames TTL
	# keeps the opened cap alive across the frame boundary (schema + snapshot
	# whitelist) until ball_frame_motion_controller ticks it out.
	scene["trampoline_launch_speed_cap"] = max(
		float(scene.get("trampoline_launch_speed_cap", 0.0)),
		launch_velocity.length()
	)
	scene["trampoline_launch_speed_cap_frames"] = max(
		float(scene.get("trampoline_launch_speed_cap_frames", 0.0)),
		float(hit_result.get("launch_speed_cap_frames", 0.0))
	)
	if audio != null:
		if audio.has_method("play_trampoline_bounce"):
			audio.play_trampoline_bounce(abs(_get_vector2(scene, "ball_vel", Vector2.ZERO).y))
		elif audio.has_method("play_wall_hit"):
			audio.play_wall_hit(abs(ball_vel.y))
	_register_ball_hit_pulse(step_result, scene, deps, "trampoline", 0.66)


func _process_campfire(step_result: Dictionary, scene: Dictionary, context: Dictionary, deps: Dictionary) -> void:
	var ball_vel: Vector2 = _get_vector2(scene, "ball_vel", Vector2.ZERO)
	var ball_pos: Vector2 = _get_vector2(step_result, "ball_pos", _get_vector2(scene, "ball_pos", Vector2.ZERO))
	# Like the other player-side floor saves, extinguishing the campfire must
	# release Dalji's ball control so it cannot flip the committed reflection
	# back downward on the next frame.
	var whip_state: Object = deps.get("stage1_dalji_whip_skill_state", null)
	if whip_state != null and whip_state.has_method("register_player_hit"):
		var whip_result: Dictionary = whip_state.register_player_hit(ball_vel, context)
		if bool(whip_result.get("whip_deactivated", false)):
			scene["stage1_dalji_whip_controls_speed"] = false

	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	var hit_result: Dictionary = {}
	if active_item_runtime != null and active_item_runtime.has_method("notify_campfire_hit"):
		hit_result = active_item_runtime.notify_campfire_hit(
			int(step_result.get("campfire_index", -1)),
			_get_vector2(step_result, "impact_pos", ball_pos)
		)

	scene["ball_pos"] = ball_pos
	scene["ball_vel"] = Vector2(ball_vel.x * 0.85, -maxf(absf(ball_vel.y), 8.0))
	var destroyed: bool = bool(hit_result.get("destroyed", false))
	var audio: Object = deps.get("audio", null)
	if audio != null:
		if destroyed and audio.has_method("play_molotov_explosion"):
			audio.play_molotov_explosion()
		elif destroyed and audio.has_method("play_brick_wall_destroy"):
			audio.play_brick_wall_destroy()
		elif audio.has_method("play_wall_hit"):
			audio.play_wall_hit(absf(ball_vel.y))
	if destroyed:
		var feedback: Object = deps.get("feedback", null)
		if feedback != null and feedback.has_method("max_screen_shake"):
			feedback.max_screen_shake(0.035, 1.0)
	_register_ball_hit_pulse(step_result, scene, deps, "campfire", 0.68)


func _process_paddle(
	step_result: Dictionary,
	scene: Dictionary,
	context: Dictionary,
	deps: Dictionary,
	callbacks: Dictionary
) -> bool:
	var controller = deps.get("paddle_bounce_controller", null)
	if controller == null:
		return false
	if not bool(step_result.get("is_player", false)) and _is_stage7_boss_ball_intangible(context, deps):
		# 아카무 무형화: 보스 패들 접촉 이벤트를 정상 반사 처리 전에 통째로
		# 무시한다(속도 보존·훅 미호출·점수 이벤트 없음).
		return false
	var wall_controller = deps.get("wall_bounce_controller", null)
	if wall_controller != null and wall_controller.has_method("register_paddle_hit"):
		wall_controller.register_paddle_hit()
	var paddle_context: Dictionary = context.duplicate()
	paddle_context.merge(scene, true)
	for key in [
		"warp_gate_afterimage_hit",
		"warp_gate_afterimage_id",
		"viper_dual_glitch_clone_hit",
		"viper_dual_glitch_clone_index",
		"viper_dual_glitch_clone_side",
		"blacksmith_thor_shield_hit",
		"blacksmith_thor_shield_rect",
		"blacksmith_thor_shield_gauge_gain",
		"blacksmith_umbrella_open",
		"blacksmith_umbrella_gauge_gain",
	]:
		if step_result.has(key):
			paddle_context[key] = step_result[key]
	var is_afterimage_hit := bool(step_result.get("warp_gate_afterimage_hit", false))
	var bounce_deps: Dictionary = _build_afterimage_bounce_deps(deps) if is_afterimage_hit else deps
	var result: Dictionary = controller.bounce(
		float(step_result.get("paddle_x", 0.0)),
		float(step_result.get("paddle_w", context.get("paddle_width", 155.0))),
		bool(step_result.get("is_player", false)),
		paddle_context,
		bounce_deps,
		callbacks
	)
	scene.merge(result, true)
	if result.is_empty():
		return false
	if bool(step_result.get("is_player", false)):
		_record_highlight_paddle_hit(true, step_result, result, context, deps)
		if is_afterimage_hit:
			_consume_warp_gate_afterimage(step_result, scene, context, deps)
			return true
		# 풍운천선무 회선 권리는 이번 초식의 반격 공에만 붙는다. 같은 접촉이
		# 실제 천선무 타격이었으면(= controller.bounce 안에서 consume_ball_hit 가
		# 벽력추진은 활주 패들 접촉에서 직접 추첨하므로, 이 선행 훅은 기존
		# 저장 데이터와 호출부를 위한 무해한 호환 알림으로만 남긴다.
		if not bool(result.get("smasher_wheel_hit", false)):
			_release_smasher_wheel_rebound_arm(deps)
		_apply_perk_fusion_thunder_drive_after_dash_bounce(
			step_result,
			scene,
			context,
			deps
		)
		_try_activate_perk_fusion_spellbreaker_guard(step_result, scene, context, deps)
		_notify_perk_fusion_paddle_skill_edges(result, deps)
		# 벽력유성 발사: 우클릭 유지 상태로 받아친 타구가 곧 발사다. 위 훅들이
		# 끝난 뒤(= scene["ball_vel"]가 이번 타구의 최종 나가는 속도로 확정된
		# 뒤) 시도해야 "맞은 각도로 발사" 계약이 성립한다.
		_try_launch_smasher_overdrive(scene, context, deps)
		# 허공환영 발사: 벽력유성과 같은 접촉-발동 계열이지만 좌클릭+↓ 커맨드라
		# 버튼이 겹치지 않는다. 환영은 이번 타구의 최종 나가는 속도를 복제하므로
		# 위 훅들이 모두 끝난 뒤에 시도해야 실제 공과 같은 각/속력으로 갈라진다.
		_try_launch_smasher_void_phantom(scene, context, deps)
		return true
	if not bool(result.get("normal_boss_bounce_committed", false)):
		return false
	_record_highlight_paddle_hit(false, step_result, result, context, deps)
	_restore_perk_fusion_thunder_drive_after_boss_guard(scene, deps)
	_restore_dalji_vision_wall_boost_after_boss_guard(scene, deps)
	# 보스가 가드하면 벽력추진 효과 종료. 커밋된 정상 보스 반사만 인정한다
	# (아카무 무형화 / 빈 결과는 위에서 이미 걸러졌다). reset() 이후의
	# _notify_smasher_overdrive_reflection 은 비활성 조기반환이라 무해하다.
	_notify_smasher_overdrive_boss_guard(deps)
	# 풍운천선무는 반대로 보스 가드에서 끝나지 않는다: 반격 공이 곧장 낙하하는
	# 대신 회선으로 감겨 내려갔다가 다시 솟구친다(발동당 1회). 같은
	# normal_boss_bounce_committed 판정을 공유한다.
	_notify_smasher_wheel_boss_guard(scene, context, deps)
	_notify_stage7_boss_paddle_hit(scene, context, deps)
	return true


func _record_highlight_wall_hit(impact_pos: Vector2, deps: Dictionary) -> void:
	var recorder: Object = deps.get("victory_highlight_recorder", null)
	if recorder != null and recorder.has_method("record_wall_hit"):
		recorder.record_wall_hit(impact_pos)


func _record_highlight_paddle_hit(
	is_player: bool,
	step_result: Dictionary,
	result: Dictionary,
	context: Dictionary,
	deps: Dictionary
) -> void:
	var recorder: Object = deps.get("victory_highlight_recorder", null)
	if recorder == null:
		return
	var impact_pos: Vector2 = _get_vector2(step_result, "impact_pos", Vector2.ZERO)
	var skill_tag: String = _resolve_highlight_skill_tag(step_result, result, context) if is_player else ""
	if is_player and recorder.has_method("record_player_hit"):
		recorder.record_player_hit(impact_pos, skill_tag)
	elif not is_player and recorder.has_method("record_boss_hit"):
		recorder.record_boss_hit(impact_pos, skill_tag)


func _resolve_highlight_skill_tag(
	step_result: Dictionary,
	result: Dictionary,
	context: Dictionary
) -> String:
	if bool(step_result.get("warp_gate_afterimage_hit", false)):
		return "warp_gate"
	var explicit_tag: String = str(result.get("skill_tag", context.get("last_player_skill_tag", "")))
	if not explicit_tag.is_empty():
		return explicit_tag
	if bool(result.get("smasher_wheel_hit", false)):
		return "smasher_wheel"
	if bool(step_result.get("viper_dual_glitch_clone_hit", false)):
		return "viper_dual_glitch"
	if bool(result.get("commando_bowling_trap_guard_hit", false)):
		return "commando_bowling_trap"
	if bool(step_result.get("blacksmith_thor_shield_hit", false)):
		return "blacksmith_thor_shield"
	if bool(context.get("dash_active", false)):
		return "dash"
	return ""


func _build_afterimage_bounce_deps(deps: Dictionary) -> Dictionary:
	var bounce_deps: Dictionary = deps.duplicate()
	bounce_deps["player_skill_input_locked"] = true
	# 잔영은 일반 반사 물리만 빌린다. 이미 대기 중인 한미량 초식도 이 가상
	# 패들 접촉을 실제 플레이어 접촉으로 소비하면 안 된다.
	for key in [
		"power_state",
		"skill_state",
		"smasher_cleanse_state",
		"smasher_magnum_grip_state",
		"smasher_wheel_state",
		"smasher_void_phantom_state",
	]:
		bounce_deps.erase(key)
	return bounce_deps


func _consume_warp_gate_afterimage(
	step_result: Dictionary,
	scene: Dictionary,
	context: Dictionary,
	deps: Dictionary
) -> void:
	var state: Object = deps.get("smasher_warp_gate_state", null)
	if state == null or not state.has_method("consume_afterimage_hit"):
		return
	var impact_pos: Vector2 = _get_vector2(
		step_result,
		"impact_pos",
		_get_vector2(scene, "ball_pos", Vector2.ZERO)
	)
	state.consume_afterimage_hit(
		int(step_result.get("warp_gate_afterimage_id", -1)),
		impact_pos,
		int(context.get("warp_gate_afterimage_time_msec", -1))
	)


# 실제 활주 중 플레이어 패들 반사 직후 15%를 한 번 추첨한다.
# 성공 시 발동 직전 유효속도를 보관하고 +80% 캡을 열며, 정상 보스 가드에서 복구한다.
func _apply_perk_fusion_thunder_drive_after_dash_bounce(
	step_result: Dictionary,
	scene: Dictionary,
	context: Dictionary,
	deps: Dictionary
) -> void:
	if not _is_player_dash_active(deps):
		return
	var fusion_runtime: Object = deps.get("runtime_perk_state", null)
	if (
		fusion_runtime == null
		or not fusion_runtime.has_method("can_trigger_perk_fusion_dash_paddle_speed_boost")
		or not bool(fusion_runtime.can_trigger_perk_fusion_dash_paddle_speed_boost())
		or not fusion_runtime.has_method("try_trigger_perk_fusion_dash_paddle_speed_boost")
	):
		return
	# 유효속도 공간 계약: 커밋된 랠리 보정 캡으로 먼저 정규화한 뒤 ×배수 —
	# 그래야 임팩트 부스트 유무와 무관하게 결과가 정확히 "유효캡 × 배수"다.
	var boost: float = maxf(1.0, float(scene.get("ball_impact_boost", 1.0)))
	var effective_cap: float = float(scene.get("max_ball_speed", 26.0))
	if boost > 1.001:
		effective_cap = float(scene.get("impact_boost_max_ball_speed", effective_cap))
	var velocity: Vector2 = _get_vector2(scene, "ball_vel", Vector2.ZERO)
	var effective_speed: float = velocity.length() * boost
	var restore_effective_speed := minf(effective_speed, effective_cap)
	if restore_effective_speed <= 0.001:
		return
	var roll_unit := randf()
	if context.has("perk_fusion_thunder_drive_roll_unit"):
		roll_unit = clampf(float(context.get("perk_fusion_thunder_drive_roll_unit", 1.0)), 0.0, 1.0)
	var activation: Dictionary = fusion_runtime.try_trigger_perk_fusion_dash_paddle_speed_boost(
		roll_unit,
		restore_effective_speed
	)
	if not bool(activation.get("triggered", false)):
		return
	var multiplier := maxf(1.0, float(activation.get("speed_multiplier", 1.0)))
	var target_effective := restore_effective_speed * multiplier
	scene["ball_vel"] = velocity.normalized() * (target_effective / boost)
	scene["perk_fusion_overload_speed_cap"] = target_effective
	scene["perk_fusion_overload_speed_cap_frames"] = 180.0
	_trigger_perk_fusion_thunder_drive_vfx(step_result, scene, deps)


func _restore_perk_fusion_thunder_drive_after_boss_guard(
	scene: Dictionary,
	deps: Dictionary
) -> void:
	var restore_effective_speed := 0.0
	var fusion_runtime: Object = deps.get("runtime_perk_state", null)
	if (
		fusion_runtime != null
		and fusion_runtime.has_method("consume_perk_fusion_boss_guard_restore_effective_speed")
	):
		restore_effective_speed = maxf(
			0.0,
			float(fusion_runtime.consume_perk_fusion_boss_guard_restore_effective_speed())
		)
	if restore_effective_speed > 0.001:
		var velocity: Vector2 = _get_vector2(scene, "ball_vel", Vector2.ZERO)
		if velocity.length_squared() > 0.0001:
			var boost := maxf(1.0, float(scene.get("ball_impact_boost", 1.0)))
			scene["ball_vel"] = velocity.normalized() * (restore_effective_speed / boost)
	_close_perk_fusion_overload_cap(scene)


func _restore_dalji_vision_wall_boost_after_boss_guard(
	scene: Dictionary,
	deps: Dictionary
) -> void:
	var state: Object = deps.get("dalji_vision_chosik_state", null)
	if (
		state == null
		or not state.has_method("consume_boss_guard_wall_speed_restore_effective_speed")
	):
		return
	var restore_effective_speed := maxf(
		0.0,
		float(state.consume_boss_guard_wall_speed_restore_effective_speed())
	)
	if restore_effective_speed <= 0.001:
		return
	var velocity := _get_vector2(scene, "ball_vel", Vector2.ZERO)
	if velocity.length_squared() <= 0.0001:
		return
	var impact_boost := maxf(1.0, float(scene.get("ball_impact_boost", 1.0)))
	scene["ball_vel"] = velocity.normalized() * (restore_effective_speed / impact_boost)


func _try_activate_perk_fusion_spellbreaker_guard(
	step_result: Dictionary,
	scene: Dictionary,
	context: Dictionary,
	deps: Dictionary
) -> void:
	var fusion_runtime: Object = deps.get("runtime_perk_state", null)
	if (
		fusion_runtime == null
		or not fusion_runtime.has_method("can_activate_perk_fusion_spellbreaker_guard")
		or not bool(fusion_runtime.can_activate_perk_fusion_spellbreaker_guard())
		or not fusion_runtime.has_method("try_activate_perk_fusion_spellbreaker_guard")
	):
		return
	var roll_unit := randf()
	if context.has("perk_fusion_spellbreaker_guard_roll_unit"):
		roll_unit = clampf(float(context.get("perk_fusion_spellbreaker_guard_roll_unit", 1.0)), 0.0, 1.0)
	var player_pos := _get_vector2(context, "player_pos", Vector2(302.5, 700.0))
	var player_size := Vector2(
		maxf(1.0, float(context.get("player_paddle_width", 155.0))),
		maxf(1.0, float(context.get("player_paddle_height", 50.0)))
	)
	var activation: Dictionary = fusion_runtime.try_activate_perk_fusion_spellbreaker_guard(
		roll_unit,
		player_pos + player_size * 0.5
	)
	if not bool(activation.get("triggered", false)):
		return
	var impact_pos := _get_vector2(
		step_result,
		"impact_pos",
		_get_vector2(step_result, "ball_pos", _get_vector2(scene, "ball_pos", player_pos))
	)
	var ball_effects: Object = deps.get("ball_effects", null)
	if ball_effects != null and ball_effects.has_method("register_hit_pulse"):
		ball_effects.register_hit_pulse(impact_pos, _get_vector2(scene, "ball_vel", Vector2.ZERO), 0.9, "spellbreaker_guard")


func _is_player_dash_active(deps: Dictionary) -> bool:
	var dash_state: Object = deps.get("dash_state", null)
	if dash_state == null:
		return false
	if dash_state.has_method("is_active"):
		return bool(dash_state.is_active())
	if dash_state.has_method("get_snapshot"):
		var snapshot: Dictionary = dash_state.get_snapshot()
		return bool(snapshot.get("active", false))
	return false


func _trigger_perk_fusion_thunder_drive_vfx(
	step_result: Dictionary,
	scene: Dictionary,
	deps: Dictionary
) -> void:
	var impact_pos := _get_vector2(
		step_result,
		"impact_pos",
		_get_vector2(step_result, "ball_pos", _get_vector2(scene, "ball_pos", Vector2.ZERO))
	)
	var velocity := _get_vector2(scene, "ball_vel", Vector2.ZERO)
	var ball_effects: Object = deps.get("ball_effects", null)
	if ball_effects != null and ball_effects.has_method("register_hit_pulse"):
		ball_effects.register_hit_pulse(impact_pos, velocity, 1.0, "thunder_drive")
	var impact_effects: Object = deps.get("impact_effects", null)
	if impact_effects == null:
		return
	if impact_effects.has_method("create_thunder_drive_burst"):
		impact_effects.create_thunder_drive_burst(impact_pos, velocity)
		return
	if impact_effects.has_method("create_energy_explosion"):
		impact_effects.create_energy_explosion(impact_pos, 0.9, 1.0)
	if impact_effects.has_method("spawn_hit_particles"):
		impact_effects.spawn_hit_particles(
			impact_pos,
			Color(0.36, 0.92, 1.0),
			velocity,
			1.0,
			velocity.length()
		)


func _close_perk_fusion_overload_cap(scene: Dictionary) -> void:
	scene["perk_fusion_overload_speed_cap"] = 0.0
	scene["perk_fusion_overload_speed_cap_frames"] = 0.0


# 패들 소유 파워스매싱/드라이브 활성화 에지 → 융합 스킬 사용 훅(잔향 등)
# 1회 통지. 에지 플래그는 패들 컨트롤러 결과가 소유한다.
func _notify_perk_fusion_paddle_skill_edges(result: Dictionary, deps: Dictionary) -> void:
	if not bool(result.get("power_activated", false)) and not bool(result.get("drive_activated", false)):
		return
	var fusion_runtime: Object = deps.get("runtime_perk_state", null)
	if fusion_runtime != null and fusion_runtime.has_method("notify_perk_fusion_skill_used"):
		fusion_runtime.notify_perk_fusion_skill_used()


func _is_stage7_boss_ball_intangible(context: Dictionary, deps: Dictionary) -> bool:
	if int(context.get("current_stage", 1)) != 7:
		return false
	var state: Object = deps.get("stage7_akamu_state", null)
	return (
		state != null
		and state.has_method("is_boss_ball_intangible")
		and bool(state.is_boss_ball_intangible())
	)


func _notify_stage7_boss_paddle_hit(scene: Dictionary, context: Dictionary, deps: Dictionary) -> void:
	if int(context.get("current_stage", 1)) != 7:
		return
	var state: Object = deps.get("stage7_akamu_state", null)
	if state == null or not state.has_method("handle_boss_paddle_hit"):
		return
	state.handle_boss_paddle_hit(scene, context, deps)


func _process_stage2_quake_boss_backstop(scene: Dictionary, context: Dictionary, deps: Dictionary) -> bool:
	var stage_background: Object = deps.get("stage_background", null)
	if stage_background == null or not stage_background.has_method("resolve_quake_boss_backstop"):
		return false
	return bool(stage_background.resolve_quake_boss_backstop(scene, context, deps))


func _apply_chargebag_wall_gauge(scene: Dictionary, context: Dictionary, deps: Dictionary) -> void:
	var mythic_item_runtime: Object = deps.get("mythic_item_runtime", null)
	if mythic_item_runtime == null or not mythic_item_runtime.has_method("apply_chargebag_wall_bounce_gauge"):
		return
	var current_gauge: float = float(scene.get("special_gauge", context.get("special_gauge", 0.0)))
	var wall_context: Dictionary = context.duplicate()
	wall_context.merge(scene, true)
	if not wall_context.has("gauge_max"):
		wall_context["gauge_max"] = float(context.get("gauge_max", context.get("special_gauge_max", 500.0)))
	if not wall_context.has("gauge_charge_per_hit"):
		wall_context["gauge_charge_per_hit"] = float(context.get("gauge_charge_per_hit", 50.0))
	if not wall_context.has("selected_character_type"):
		wall_context["selected_character_type"] = str(context.get("selected_character_type", "smasher"))
	var next_gauge: float = float(mythic_item_runtime.apply_chargebag_wall_bounce_gauge(current_gauge, wall_context, deps))
	if not is_equal_approx(next_gauge, current_gauge):
		scene["special_gauge"] = next_gauge


func _notify_power_smash_wall_bounce(step_result: Dictionary, deps: Dictionary) -> void:
	var power_state: Object = deps.get("power_state", null)
	if power_state == null or not power_state.has_method("notify_wall_bounce"):
		return
	power_state.notify_wall_bounce(str(step_result.get("side", "")))


func _notify_smasher_overdrive_reflection(scene: Dictionary, impact_pos: Vector2, deps: Dictionary) -> void:
	var state: Object = deps.get("smasher_overdrive_state", null)
	if state == null or not state.has_method("notify_ball_reflected"):
		return
	state.notify_ball_reflected(_get_vector2(scene, "ball_vel", Vector2.ZERO), impact_pos)


# 벽력유성은 "우클릭 유지 + 플레이어 타구" 시점에 발사된다(파워스매싱과 동일한
# 접촉-시점 발동 계약). 게이지 차감은 스냅샷되는 scene dict 에 반영해야 한다 —
# ball_update_controller 가 프레임 끝에 scene 의 모든 키를 owner 로 되쓰므로
# owner 만 갱신하면 그대로 환불된다(볼-패스 owner-스냅샷 스탯 환불 트랩).
func _try_launch_smasher_overdrive(scene: Dictionary, context: Dictionary, deps: Dictionary) -> void:
	var state: Object = deps.get("smasher_overdrive_state", null)
	if state == null or not state.has_method("try_launch_on_player_hit"):
		return
	if str(context.get("selected_character_type", "smasher")) != "smasher":
		return
	var launch_context: Dictionary = context.duplicate()
	launch_context.merge(scene, true)
	var result: Dictionary = state.try_launch_on_player_hit(
		_get_vector2(scene, "ball_vel", Vector2.ZERO),
		launch_context,
		deps
	)
	if not bool(result.get("launched", false)):
		return
	if result.has("special_gauge"):
		scene["special_gauge"] = float(result.get("special_gauge", scene.get("special_gauge", 0.0)))
	var fusion_runtime: Object = deps.get("runtime_perk_state", null)
	if fusion_runtime != null and fusion_runtime.has_method("notify_perk_fusion_skill_used"):
		fusion_runtime.notify_perk_fusion_skill_used()


# 허공환영도 볼-패스 접촉 발동이라 게이지 차감은 스냅샷되는 scene dict 에
# 반영해야 한다 — owner 만 갱신하면 프레임 끝 apply_snapshot 이 되쓰면서
# 환불된다(볼-패스 owner-스냅샷 스탯 환불 트랩).
func _try_launch_smasher_void_phantom(scene: Dictionary, context: Dictionary, deps: Dictionary) -> void:
	var state: Object = deps.get("smasher_void_phantom_state", null)
	if state == null or not state.has_method("try_launch_on_player_hit"):
		return
	if str(context.get("selected_character_type", "smasher")) != "smasher":
		return
	var launch_context: Dictionary = context.duplicate()
	launch_context.merge(scene, true)
	var result: Dictionary = state.try_launch_on_player_hit(
		_get_vector2(scene, "ball_vel", Vector2.ZERO),
		launch_context,
		deps
	)
	if not bool(result.get("launched", false)):
		return
	if result.has("ball_pos"):
		scene["ball_pos"] = _get_vector2(result, "ball_pos", _get_vector2(scene, "ball_pos", Vector2.ZERO))
	# 기만 비행 감속(-40%). 게이지와 같은 이유로 scene 에 써야 한다 — owner 만
	# 갱신하면 프레임 끝 apply_snapshot 이 원래 속도로 되쓴다. 원속 복원은 보스
	# 가드 반사(paddle_bounce_controller)가 소유한다.
	if result.has("ball_vel"):
		scene["ball_vel"] = _get_vector2(result, "ball_vel", _get_vector2(scene, "ball_vel", Vector2.ZERO))
	if result.has("skip_ball_motion_step"):
		scene["skip_ball_motion_step"] = bool(result.get("skip_ball_motion_step", false))
	if result.has("special_gauge"):
		scene["special_gauge"] = float(result.get("special_gauge", scene.get("special_gauge", 0.0)))
	var fusion_runtime: Object = deps.get("runtime_perk_state", null)
	if fusion_runtime != null and fusion_runtime.has_method("notify_perk_fusion_skill_used"):
		fusion_runtime.notify_perk_fusion_skill_used()


func _notify_smasher_overdrive_boss_guard(deps: Dictionary) -> void:
	var state: Object = deps.get("smasher_overdrive_state", null)
	if state == null or not state.has_method("notify_boss_guard"):
		return
	state.notify_boss_guard()


# ⚠️덕타이핑 동적 호출이라 파서가 인자 수를 검증하지 못한다. 형제 훅
# (_notify_smasher_overdrive_boss_guard 는 무인자)에서 호출문을 복붙하지 말 것 —
# 이쪽은 (ball_pos, context, deps) 3인자 계약이다.
func _notify_smasher_wheel_boss_guard(scene: Dictionary, context: Dictionary, deps: Dictionary) -> void:
	if str(context.get("selected_character_type", "smasher")) != "smasher":
		return
	var state: Object = deps.get("smasher_wheel_state", null)
	if state == null or not state.has_method("notify_boss_guard_rebound"):
		return
	var result: Dictionary = state.notify_boss_guard_rebound(
		_get_vector2(scene, "ball_pos", Vector2.ZERO),
		{
			# 가드 직후의 리턴 속도가 회선의 "원래 속도" 기준점이다 —
			# 여기서 감속했다가 회선 끝에 이 값으로 되돌아온다.
			"ball_vel": _get_vector2(scene, "ball_vel", Vector2.ZERO),
			"ball_impact_boost": float(scene.get("ball_impact_boost", 1.0)),
			"width": float(context.get("width", 760.0)),
			"height": float(context.get("height", 750.0)),
		},
		deps
	)
	if result.is_empty():
		return
	scene.merge(result, true)


func _release_smasher_wheel_rebound_arm(deps: Dictionary) -> void:
	var state: Object = deps.get("smasher_wheel_state", null)
	if state == null or not state.has_method("notify_player_bounce_rebound_release"):
		return
	state.notify_player_bounce_rebound_release()


func _register_ball_hit_pulse(
	step_result: Dictionary,
	scene: Dictionary,
	deps: Dictionary,
	kind: String,
	intensity: float
) -> void:
	var ball_effects: Object = deps.get("ball_effects", null)
	if ball_effects == null or not ball_effects.has_method("register_hit_pulse"):
		return
	ball_effects.register_hit_pulse(
		_get_vector2(step_result, "impact_pos", _get_vector2(scene, "ball_pos", Vector2.ZERO)),
		_get_vector2(scene, "ball_vel", Vector2.ZERO),
		intensity,
		kind
	)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return BallContextReader.get_vector2(source, key, fallback)
