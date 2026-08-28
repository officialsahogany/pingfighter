extends RefCounted

const POWER_SMASH_CONTACT_INTENSITY := 2.0


func update_freeze(delta: float, ball_pos: Vector2, context: Dictionary, deps: Dictionary) -> Dictionary:
	var power_state = deps.get("power_state", null)
	if power_state == null:
		return {}
	if not power_state.is_freeze_active():
		return {}

	if power_state.is_freeze_ball_locked():
		ball_pos = power_state.get_freeze_ball_pos()

	var launched: bool = power_state.update_freeze(delta, float(context.get("freeze_duration", 0.0)))
	if launched:
		_trigger_pending_power_hit_anim(context, deps)
		var audio = deps.get("audio", null)
		if audio != null:
			audio.play_power_smash_launch()

		var combo_consumed: int = int(power_state.get_combo_consumed())
		var feedback = deps.get("feedback", null)
		if feedback != null and combo_consumed >= 2:
			# 원본 파워스매싱 파리티: (15 + 콤보*2)프레임 동안 ±(10 + 콤보*2)를
			# 감쇠 없이 유지한다. 기본 감쇠 채널은 진폭에 남은 타이머를 곱해
			# 같은 상수로도 최고 진폭이 1/3 토막 나므로 지속 채널로 보낸다.
			feedback.max_sustained_screen_shake(
				float(15 + combo_consumed * 2) / 60.0,
				10.0 + float(combo_consumed * 2)
			)

	return {
		"ball_pos": ball_pos,
	}


func apply_motion(ball_vel: Vector2, fps_scale: float, context: Dictionary, deps: Dictionary) -> Dictionary:
	var power_state = deps.get("power_state", null)
	if power_state == null:
		return {}
	if power_state.has_method("is_ghost_shot_motion_active") and bool(power_state.is_ghost_shot_motion_active()):
		var scene_value: Variant = context.get("scene", {})
		if scene_value is Dictionary and power_state.has_method("apply_ghost_shot_motion"):
			return power_state.apply_ghost_shot_motion(scene_value, fps_scale, context, deps)
	# 콤보증폭칩: projection/융합/개광결까지 해석된 감쇄 완화 실효값을
	# motion 경로에 전달한다. 여기서 progression 원본을 다시 읽으면 개광결이 탈락한다.
	var initial_boost_decay_reduction := 0.0
	var runtime_perk_state: Object = deps.get("runtime_perk_state", null)
	if runtime_perk_state != null and runtime_perk_state.has_method("get_combo_amplifier_chip_bonus"):
		initial_boost_decay_reduction = float(
			runtime_perk_state.get_combo_amplifier_chip_bonus().get(
				"initial_boost_decay_reduction",
				0.0
			)
		)
	return {
		"ball_vel": power_state.apply_motion(
			ball_vel,
			fps_scale,
			float(context.get("gravity_effect", 0.0)),
			float(context.get("boost_duration", 0.0)),
			initial_boost_decay_reduction
		),
	}


func _trigger_pending_power_hit_anim(context: Dictionary, deps: Dictionary) -> void:
	var animation_state = deps.get("animation_state", null)
	if animation_state == null:
		return
	if not animation_state.has_method("has_player_pending_contact_offset"):
		return
	if not bool(animation_state.has_player_pending_contact_offset()):
		return
	var contact_offset: float = float(animation_state.consume_player_pending_contact_offset())
	animation_state.trigger_player_hit(
		contact_offset,
		bool(context.get("player_has_hit_sprite", false)),
		float(context.get("player_hit_anim_duration", 0.40)),
		POWER_SMASH_CONTACT_INTENSITY
	)
