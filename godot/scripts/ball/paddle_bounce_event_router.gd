extends RefCounted

const BallContextReader := preload("res://scripts/ball/ball_context_reader.gd")
const PaddleBounceRallyFeedbackRouter := preload("res://scripts/ball/paddle_bounce_rally_feedback_router.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")

const POWER_COUNTER_BASE_KNOCKBACK: float = 2.4 * 2.0
const POWER_COUNTER_KNOCKBACK_FRAMES: float = 18.0
const PADDLE_HIT_KNOCKBACK_BASE: float = 2.4
const PADDLE_HIT_KNOCKBACK_FRAMES: float = 36.0
const PADDLE_HIT_KNOCKBACK_DECAY: float = 0.85
const PADDLE_HIT_KNOCKBACK_INTENSITY_SCALE := [1.5, 2.2, 2.2, 3.8, 3.8, 5.5]

# Smasher contact-animation intensity, ported from Python
# `trigger_smasher_contact_animation(offset_x, intensity)` callers in
# `pingfighter.py` (~183390 normal, 183659 drive, 202524-area power-smash).
const PLAYER_HIT_INTENSITY_NORMAL: float = 1.0
const PLAYER_HIT_INTENSITY_DRIVE: float = 1.5
const PLAYER_HIT_INTENSITY_POWER_SMASH: float = 2.0

var rally_feedback_router: Object = PaddleBounceRallyFeedbackRouter.new()
var _character_runtime: Object = PlayerCharacterRuntime.new()


func register_player_hit(
	ball_pos: Vector2,
	hit_pos: float,
	drive_activated: bool,
	power_activated: bool,
	special_gauge: float,
	context: Dictionary,
	deps: Dictionary
) -> float:
	var power_state = deps.get("power_state", null)
	var horn_strawberry_transformed: bool = _is_horn_strawberry_transformed(deps)
	var combo_state = _get_smasher_combo_state(context, deps) if not horn_strawberry_transformed else null
	if combo_state != null and (power_state == null or not power_state.is_freeze_active()):
		combo_state.register_hit(ball_pos)

	var updated_gauge: float = special_gauge
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if (
		active_item_runtime != null
		and active_item_runtime.has_method("is_aipill_active")
		and bool(active_item_runtime.is_aipill_active())
	):
		if active_item_runtime.has_method("apply_aipill_guard_drain"):
			updated_gauge = float(active_item_runtime.apply_aipill_guard_drain(special_gauge, context, deps))
		_trigger_player_hit_anim(hit_pos, context, deps, _resolve_hit_intensity(drive_activated, false))
		return updated_gauge

	if not drive_activated and not power_activated and not _is_dash_gauge_gain_blocked(deps):
		var mythic_item_runtime: Object = deps.get("mythic_item_runtime", null)
		var gauge_gain: float = _get_horn_strawberry_gauge_on_hit(mythic_item_runtime) if horn_strawberry_transformed else float(context.get("gauge_charge_per_hit", 0.0))
		if not horn_strawberry_transformed:
			if combo_state != null:
				gauge_gain = combo_state.get_gauge_gain(gauge_gain)
			if mythic_item_runtime != null and mythic_item_runtime.has_method("calculate_bluetooth_ring_gauge_charge"):
				gauge_gain = float(mythic_item_runtime.calculate_bluetooth_ring_gauge_charge(gauge_gain))
			if mythic_item_runtime != null and mythic_item_runtime.has_method("apply_gold_digger_gauge_bonus"):
				gauge_gain = float(mythic_item_runtime.apply_gold_digger_gauge_bonus(gauge_gain))
			gauge_gain = _apply_lingpet_gauge_gain(gauge_gain, deps)
		updated_gauge = min(updated_gauge + gauge_gain, float(context.get("gauge_max", updated_gauge)))
		var feedback = deps.get("feedback", null)
		if feedback != null:
			feedback.trigger_gauge_flash()
	if power_activated:
		_set_pending_power_hit_anim(hit_pos, context, deps)
	else:
		_trigger_player_hit_anim(hit_pos, context, deps, _resolve_hit_intensity(drive_activated, false))
	return updated_gauge


func _get_smasher_combo_state(context: Dictionary, deps: Dictionary) -> Object:
	if not _is_selected_character(context, "smasher", "smasher"):
		return null
	return deps.get("combo_state", null)


func _is_selected_character(context: Dictionary, fallback: String, target: String) -> bool:
	var value: Variant = context.get("selected_character_type", fallback)
	if str(value).strip_edges() == "":
		return false
	return _character_runtime.normalize(value) == target


func _is_horn_strawberry_transformed(deps: Dictionary) -> bool:
	var mythic_item_runtime: Object = deps.get("mythic_item_runtime", null)
	return (
		mythic_item_runtime != null
		and mythic_item_runtime.has_method("is_horn_strawberry_transformed")
		and bool(mythic_item_runtime.is_horn_strawberry_transformed())
	)


func _get_horn_strawberry_gauge_on_hit(mythic_item_runtime: Object) -> float:
	if mythic_item_runtime != null and mythic_item_runtime.has_method("get_horn_strawberry_gauge_on_hit"):
		return max(0.0, float(mythic_item_runtime.get_horn_strawberry_gauge_on_hit()))
	return 0.0


func _apply_lingpet_gauge_gain(gauge_gain: float, deps: Dictionary) -> float:
	var lingpet_runtime: Object = deps.get("lingpet_egg_runtime", null)
	if lingpet_runtime != null and lingpet_runtime.has_method("get_gauge_gain_per_hit"):
		return max(0.0, float(lingpet_runtime.get_gauge_gain_per_hit(gauge_gain)))
	return max(0.0, gauge_gain)


func _resolve_hit_intensity(drive_activated: bool, power_activated: bool) -> float:
	if power_activated:
		return PLAYER_HIT_INTENSITY_POWER_SMASH
	if drive_activated:
		return PLAYER_HIT_INTENSITY_DRIVE
	return PLAYER_HIT_INTENSITY_NORMAL


func _is_dash_gauge_gain_blocked(deps: Dictionary) -> bool:
	var dash_state: Object = deps.get("dash_state", null)
	if dash_state == null:
		return false
	if dash_state.has_method("is_active") and bool(dash_state.is_active()):
		return true
	if dash_state.has_method("is_recovering") and bool(dash_state.is_recovering()):
		return true
	return false


func register_rally_feedback(
	ball_pos: Vector2,
	ball_vel: Vector2,
	is_player: bool,
	power_activated: bool,
	deps: Dictionary,
	context: Dictionary = {},
	special_gauge: float = -1.0,
	drive_activated: bool = false
) -> Dictionary:
	rally_feedback_router.register(ball_pos, ball_vel, is_player, power_activated, deps, context, drive_activated)
	var status_context: Dictionary = context.duplicate()
	if special_gauge >= 0.0:
		status_context["special_gauge"] = special_gauge
	if bool(status_context.get("suppress_paddle_hit_knockback", false)):
		return {}
	return _apply_paddle_hit_knockback(ball_pos, ball_vel, is_player, status_context, deps)


func apply_drive_boss_counter(
	ball_vel: Vector2,
	ball_spin_strength: float,
	drive_speed_increase: float,
	drive_ball_active: bool,
	drive_hit_boss: bool,
	deps: Dictionary
) -> Dictionary:
	var counter_state = deps.get("drive_counter_state", null)
	if counter_state == null:
		return {}
	var result: Dictionary = counter_state.apply_counter(
		ball_vel,
		ball_spin_strength,
		drive_speed_increase,
		drive_ball_active,
		drive_hit_boss
	)
	if bool(result.get("applied", false)):
		return result
	return {}


func end_power_smashing_on_boss_counter(
	ball_vel: Vector2,
	power_state: Object,
	deps: Dictionary = {},
	counter_origin: Vector2 = Vector2.ZERO,
	context: Dictionary = {}
) -> Vector2:
	if power_state == null or (not power_state.is_parabola_active() and not power_state.is_freeze_active()):
		return ball_vel
	var combo_consumed: int = int(power_state.get_combo_consumed())
	if power_state.get_original_speed() > 0.0:
		var current_speed: float = ball_vel.length()
		if current_speed > 0.0:
			ball_vel *= power_state.get_original_speed() / current_speed
	if combo_consumed >= 2:
		var counter_result: Dictionary = _trigger_power_smash_counter_knockback(ball_vel, combo_consumed, context, deps)
		if counter_result.has("special_gauge"):
			context["special_gauge"] = float(counter_result.get("special_gauge", context.get("special_gauge", 0.0)))
	if power_state.has_method("finish_after_boss_counter"):
		power_state.finish_after_boss_counter(counter_origin)
	else:
		power_state.reset(false)
	return ball_vel


func end_power_smashing_on_player_return(power_state: Object) -> void:
	if power_state == null:
		return
	if not power_state.has_method("is_parabola_active") or not bool(power_state.is_parabola_active()):
		return
	if power_state.has_method("is_ghost_shot_motion_active") and bool(power_state.is_ghost_shot_motion_active()):
		return
	if power_state.has_method("reset"):
		power_state.reset(false)


func trigger_boss_hit_anim(boss_vel: float, context: Dictionary, deps: Dictionary) -> void:
	var animation_state = deps.get("animation_state", null)
	if animation_state == null:
		return
	animation_state.trigger_boss_hit(boss_vel, bool(context.get("boss_has_hit_sprite", false)))


func _trigger_player_hit_anim(hit_pos: float, context: Dictionary, deps: Dictionary, intensity: float = PLAYER_HIT_INTENSITY_NORMAL) -> void:
	var animation_state = deps.get("animation_state", null)
	if animation_state == null:
		return
	# Pass the resolved intensity through the facade so player_actor_animation_state
	# can scale `hit_timer`, `shield_raise_timer`, and `left_raise_timer` together
	# (Python parity: drive holds the swing 1.5x longer, power-smash 2.0x).
	var hit_duration: float = float(context.get("player_hit_anim_duration", 0.36))
	animation_state.trigger_player_hit(hit_pos, bool(context.get("player_has_hit_sprite", false)), hit_duration, intensity)


func _set_pending_power_hit_anim(hit_pos: float, context: Dictionary, deps: Dictionary) -> void:
	var animation_state = deps.get("animation_state", null)
	if animation_state == null or not animation_state.has_method("set_player_pending_contact_offset"):
		return
	var paddle_width: float = max(1.0, float(context.get("paddle_width", 155.0)))
	var contact_offset: float = hit_pos * paddle_width * 0.5
	animation_state.set_player_pending_contact_offset(contact_offset)


func _trigger_power_smash_counter_knockback(
	ball_vel: Vector2,
	combo_consumed: int,
	context: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var immunity_result: Dictionary = _try_player_status_immunity(
		deps,
		context,
		"power_smash_counter_knockback",
		"knockback"
	)
	if bool(immunity_result.get("immune", false)):
		return immunity_result
	var movement_state: Object = deps.get("movement_state", null)
	if movement_state == null or not movement_state.has_method("start_knockback"):
		return {}
	var knockback_dir: float = 0.0
	if ball_vel.x > 0.0:
		knockback_dir = -1.0
	elif ball_vel.x < 0.0:
		knockback_dir = 1.0
	else:
		knockback_dir = -1.0 if randf() < 0.5 else 1.0
	var combo_mult: float = 1.0 + min(float(combo_consumed) * 0.30, 1.50)
	movement_state.start_knockback(
		knockback_dir * POWER_COUNTER_BASE_KNOCKBACK * combo_mult,
		POWER_COUNTER_KNOCKBACK_FRAMES
	)
	return {}


func _apply_paddle_hit_knockback(
	ball_pos: Vector2,
	ball_vel: Vector2,
	is_player: bool,
	context: Dictionary,
	deps: Dictionary
) -> Dictionary:
	if is_player and bool(context.get("viper_dual_glitch_clone_hit", false)):
		return {}
	var strength: float = _get_paddle_hit_knockback_strength(ball_vel, deps)
	var paddle_center_x: float = _get_paddle_center_x(is_player, context, ball_pos.x)
	var knockback_dir: float = -1.0 if ball_pos.x > paddle_center_x else 1.0
	var velocity: float = knockback_dir * strength
	if is_player:
		var immunity_result: Dictionary = _try_player_status_immunity(
			deps,
			context,
			"paddle_hit_knockback",
			"knockback"
		)
		if bool(immunity_result.get("immune", false)):
			return immunity_result
		var movement_state: Object = deps.get("movement_state", null)
		if movement_state != null and movement_state.has_method("start_knockback"):
			movement_state.start_knockback(
				velocity,
				PADDLE_HIT_KNOCKBACK_FRAMES,
				PADDLE_HIT_KNOCKBACK_DECAY,
				true,
				false
			)
	else:
		if _is_boss_status_immune(context, deps):
			return {}
		var ai_state: Object = deps.get("ai_state", null)
		if ai_state != null and ai_state.has_method("start_paddle_hit_knockback"):
			ai_state.start_paddle_hit_knockback(
				velocity,
				PADDLE_HIT_KNOCKBACK_FRAMES,
				PADDLE_HIT_KNOCKBACK_DECAY,
				true
			)
	return {}


func _get_paddle_hit_knockback_strength(ball_vel: Vector2, deps: Dictionary) -> float:
	var level: int = _get_display_intensity_level(ball_vel, deps)
	var clamped_level: int = int(clamp(level, 0, PADDLE_HIT_KNOCKBACK_INTENSITY_SCALE.size() - 1))
	var scale: float = float(PADDLE_HIT_KNOCKBACK_INTENSITY_SCALE[clamped_level])
	return PADDLE_HIT_KNOCKBACK_BASE * scale


func _get_display_intensity_level(ball_vel: Vector2, deps: Dictionary) -> int:
	var ball_intensity: Object = deps.get("ball_intensity", null)
	if ball_intensity != null:
		if ball_intensity.has_method("get_display_level"):
			return int(clamp(floor(float(ball_intensity.get_display_level())), 0.0, 5.0))
		if ball_intensity.has_method("get_target_level"):
			return int(clamp(int(ball_intensity.get_target_level()), 0, 5))
		if ball_intensity.has_method("calculate"):
			return int(clamp(floor(float(ball_intensity.calculate(ball_vel)) * 5.0), 0.0, 5.0))
	return _get_speed_intensity_level(ball_vel.length())


func _get_speed_intensity_level(speed: float) -> int:
	if speed >= 35.0:
		return 5
	if speed >= 28.0:
		return 4
	if speed >= 22.0:
		return 3
	if speed >= 16.0:
		return 2
	if speed >= 12.0:
		return 1
	return 0


func _get_paddle_center_x(is_player: bool, context: Dictionary, fallback_x: float) -> float:
	if is_player:
		var player_pos: Vector2 = BallContextReader.get_vector2(context, "player_pos", Vector2(fallback_x, 0.0))
		var center_x: float = player_pos.x + float(context.get("player_paddle_width", context.get("paddle_width", 0.0))) * 0.5
		var mirror_offset_x: float = float(context.get("player_paddle_mirror_offset_x", 0.0))
		if abs(mirror_offset_x) > 0.01:
			var mirror_center_x: float = center_x + mirror_offset_x
			if abs(fallback_x - mirror_center_x) < abs(fallback_x - center_x):
				return mirror_center_x
		return center_x
	var boss_pos: Vector2 = BallContextReader.get_vector2(context, "boss_pos", Vector2(fallback_x, 0.0))
	return boss_pos.x + float(context.get("boss_paddle_width", 0.0)) * 0.5


func _is_player_status_immune(deps: Dictionary) -> bool:
	return bool(_try_player_status_immunity(deps, {}, "", "").get("immune", false))


func _try_player_status_immunity(
	deps: Dictionary,
	context: Dictionary = {},
	source: String = "",
	effect_type: String = "knockback"
) -> Dictionary:
	var cleanse_state: Object = deps.get("smasher_cleanse_state", null)
	if cleanse_state != null and cleanse_state.has_method("is_immune"):
		if bool(cleanse_state.is_immune()):
			return {"immune": true}
	if source == "":
		return {"immune": false}
	var mythic_item_runtime: Object = deps.get("mythic_item_runtime", null)
	if mythic_item_runtime == null or not mythic_item_runtime.has_method("try_consume_celestial_armor_immunity"):
		return {"immune": false}
	var status_deps: Dictionary = deps.duplicate()
	status_deps["context"] = context
	if context.get("owner", null) is Object:
		status_deps["owner"] = context.get("owner", null)
	if not bool(mythic_item_runtime.try_consume_celestial_armor_immunity(source, effect_type, status_deps)):
		return {"immune": false}
	var result := {"immune": true}
	if context.has("special_gauge"):
		result["special_gauge"] = float(context.get("special_gauge", 0.0))
	return result


func _is_boss_status_immune(context: Dictionary, deps: Dictionary) -> bool:
	if int(context.get("current_stage", 0)) != 2:
		return false
	if bool(context.get("stage2_speed_defense_status_immunity_active", false)) or bool(context.get("stage2_speed_defense_active", false)):
		return true
	var stage2_skill_state: Object = deps.get("stage2_boss_skill_state", null)
	return (
		stage2_skill_state != null
		and stage2_skill_state.has_method("is_boss_status_immune")
		and bool(stage2_skill_state.is_boss_status_immune())
	)
