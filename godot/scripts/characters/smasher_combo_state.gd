extends RefCounted

const SmasherComboEffectState := preload("res://scripts/characters/smasher_combo_effect_state.gd")
const SmasherComboProgressState := preload("res://scripts/characters/smasher_combo_progress_state.gd")
const SmasherComboRules := preload("res://scripts/characters/smasher_combo_rules.gd")

var effect_state: Object = SmasherComboEffectState.new()
var progress_state: Object = SmasherComboProgressState.new()
var rules: Object = SmasherComboRules.new()


func reset_combo() -> void:
	progress_state.reset_combo()


func clear_effects() -> void:
	effect_state.reset()
	progress_state.clear_gauge_smooth()


func start_dash_combo_grace() -> void:
	progress_state.start_dash_combo_grace()


func update_timers(fps_scale: float) -> void:
	progress_state.update_timers(fps_scale)
	effect_state.update(fps_scale)


func register_hit(pos: Vector2) -> void:
	var new_combo_count: int = progress_state.register_hit()
	if new_combo_count >= progress_state.get_min_skill_count():
		start_effect(pos, new_combo_count)


func start_effect(pos: Vector2, new_combo_count: int) -> void:
	var combo_color: Color = get_combo_color(new_combo_count)
	effect_state.start(pos, new_combo_count, combo_color)


func get_effective_combo() -> int:
	return progress_state.get_effective_combo()


func get_gauge_bonus_pct(check_combo_count: int) -> float:
	return rules.get_gauge_bonus_pct(check_combo_count, progress_state.get_min_skill_count())


func get_gauge_gain(base_gain: float) -> float:
	return rules.get_gauge_gain(base_gain, progress_state.get_combo_count(), progress_state.get_min_skill_count())


func get_combo_color(check_combo_count: int) -> Color:
	return rules.get_combo_color(check_combo_count)


func get_combo_glow_color(check_combo_count: int) -> Color:
	return rules.get_combo_glow_color(check_combo_count)


func get_combo_count() -> int:
	return progress_state.get_combo_count()


func get_dash_combo_grace_timer() -> float:
	return progress_state.get_dash_combo_grace_timer()


func get_dash_combo_grace_count() -> int:
	return progress_state.get_dash_combo_grace_count()


func is_effect_active() -> bool:
	return effect_state.is_active()


func get_effect_timer_frames() -> float:
	return effect_state.get_timer_frames()


func get_effect_pos() -> Vector2:
	return effect_state.get_pos()


func get_effect_count() -> int:
	return effect_state.get_count()


func get_particles() -> Array[Dictionary]:
	return effect_state.get_particles()


func get_gauge_smooth() -> float:
	return progress_state.get_gauge_smooth()


func get_min_skill_count() -> int:
	return progress_state.get_min_skill_count()


func get_effect_duration_frames() -> float:
	return effect_state.get_effect_duration_frames()


func get_dash_combo_grace_frames() -> float:
	return progress_state.get_dash_combo_grace_frames()


func get_gauge_max_count() -> float:
	return progress_state.get_gauge_max_count()
