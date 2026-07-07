extends RefCounted

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")

const ITEM_KNEE_PADS := "knee_pads"
const FLASH_DURATION_FRAMES := 30.0
const PARTICLE_COUNT := 20
const SHAKE_AMOUNT := 0.08
const SHAKE_INTENSITY := 3.0


func is_equipped(runtime: Object) -> bool:
	return runtime.roll_query.has_equipped_item_name(runtime, ITEM_KNEE_PADS)


func get_charge_pct(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_value(runtime, ITEM_KNEE_PADS, "knee_charge_pct")
	if not is_equipped(runtime):
		return 0.0
	return clamp(runtime.roll_query.get_equipped_roll_sum(runtime, ITEM_KNEE_PADS, "knee_charge_pct"), 0.0, 500.0)


func try_apply_player_hit(
	runtime: Object,
	ball_pos: Vector2,
	special_gauge: float,
	context: Dictionary,
	deps: Dictionary
) -> Dictionary:
	if get_charge_pct(runtime) <= 0.0:
		runtime.knee_pads_half_dash_consumed = false
		return {}
	if not is_half_dash_window_active(runtime, deps):
		return {}
	if runtime.knee_pads_half_dash_consumed:
		return {}

	var charge_pct: float = get_charge_pct(runtime)
	var base_charge: float = resolve_base_charge(context)
	var charge_amount: float = max(0.0, base_charge * charge_pct / 100.0)
	charge_amount = runtime.apply_gold_digger_gauge_bonus(charge_amount)
	if charge_amount <= 0.0:
		return {}

	runtime.knee_pads_half_dash_consumed = true
	var gauge_max: float = max(0.0, float(context.get("gauge_max", context.get("special_gauge_max", 500.0))))
	var next_gauge: float = min(gauge_max, max(0.0, special_gauge) + charge_amount)
	if next_gauge > special_gauge:
		runtime.gauge_feedback.trigger_gauge_flash(runtime, deps)
	runtime.gauge_feedback.trigger_orb_gauge_spin(runtime, deps)
	start_effect(runtime, ball_pos, deps)
	var registry: Object = runtime._get_dict(deps).get("registry", null)
	runtime.audio_router.play_knee_pads_audio(runtime, registry)
	return {
		"special_gauge": next_gauge,
		"activated": true,
		"charge_amount": max(0.0, next_gauge - special_gauge),
	}


func clear_runtime(runtime: Object) -> void:
	runtime.knee_pads_half_dash_consumed = false
	runtime.knee_pads_flash_timer_frames = 0.0
	runtime.knee_pads_flash_center = Vector2.ZERO
	runtime.knee_pads_particles.clear()


func update_runtime(runtime: Object, fps_scale: float) -> void:
	if runtime.knee_pads_flash_timer_frames > 0.0:
		runtime.knee_pads_flash_timer_frames = max(0.0, runtime.knee_pads_flash_timer_frames - fps_scale)
	for i in range(runtime.knee_pads_particles.size() - 1, -1, -1):
		var particle: Dictionary = runtime._get_dict(runtime.knee_pads_particles[i])
		var life: float = float(particle.get("life", 0.0)) - fps_scale
		if life <= 0.0:
			runtime.knee_pads_particles.remove_at(i)
			continue
		var velocity: Vector2 = runtime._get_vector2(particle.get("velocity", Vector2.ZERO))
		var position: Vector2 = runtime._get_vector2(particle.get("position", Vector2.ZERO))
		velocity.y += 0.30 * fps_scale
		position += velocity * fps_scale
		particle["life"] = life
		particle["velocity"] = velocity
		particle["position"] = position
		particle["size"] = max(1.0, float(particle.get("size", 2.0)) - 0.10 * fps_scale)
		runtime.knee_pads_particles[i] = particle


func resolve_base_charge(context: Dictionary) -> float:
	var character_type: String = str(context.get("selected_character_type", "smasher")).strip_edges().to_lower()
	match character_type:
		"soldier", "commando":
			return 60.0
		"blacksmith", "baltor":
			return 30.0
	return 60.0


func is_half_dash_window_active(runtime: Object, deps: Dictionary) -> bool:
	var dash_state: Object = runtime._get_dict(deps).get("dash_state", null)
	if dash_state == null or not dash_state.has_method("get_snapshot"):
		runtime.knee_pads_half_dash_consumed = false
		return false
	var dash_snapshot: Dictionary = runtime._get_dict(dash_state.get_snapshot())
	if not bool(dash_snapshot.get("is_half", false)):
		runtime.knee_pads_half_dash_consumed = false
		return false
	var valid_window: bool = (
		bool(dash_snapshot.get("active", false))
		or bool(dash_snapshot.get("recovering", false))
		or float(dash_snapshot.get("timer", 0.0)) > 0.0
		or float(dash_snapshot.get("stun_timer", 0.0)) > 0.0
	)
	if not valid_window:
		runtime.knee_pads_half_dash_consumed = false
	return valid_window


func start_effect(runtime: Object, ball_pos: Vector2, deps: Dictionary) -> void:
	runtime.knee_pads_flash_center = ball_pos
	runtime.knee_pads_flash_timer_frames = FLASH_DURATION_FRAMES
	runtime.knee_pads_particles.clear()
	for _i in range(PARTICLE_COUNT):
		var angle: float = randf_range(0.0, TAU)
		var speed: float = randf_range(3.0, 8.0)
		var color: Color = [
			Color(1.0, 1.0, 0.0),
			Color(1.0, 220.0 / 255.0, 0.0),
			Color(1.0, 200.0 / 255.0, 100.0 / 255.0),
		][randi() % 3]
		runtime.knee_pads_particles.append({
			"position": ball_pos,
			"velocity": Vector2(cos(angle), sin(angle)) * speed,
			"life": 30.0,
			"max_life": 30.0,
			"color": color,
			"size": randf_range(2.0, 5.0),
		})
	var feedback: Object = runtime._get_dict(deps).get("feedback", null)
	if feedback != null:
		if feedback.has_method("max_screen_shake"):
			feedback.max_screen_shake(SHAKE_AMOUNT, SHAKE_INTENSITY)
		elif feedback.has_method("set_screen_shake"):
			feedback.set_screen_shake(SHAKE_AMOUNT, SHAKE_INTENSITY)


func _get_converted_perk_value(runtime: Object, perk_id: String, key: String) -> float:
	var level := 0
	if runtime != null and runtime.has_method("get_converted_perk_effect_level"):
		level = max(0, int(runtime.get_converted_perk_effect_level(perk_id)))
	if level <= 0:
		return 0.0
	return PerkConversionValues.get_value(perk_id, key, level)
