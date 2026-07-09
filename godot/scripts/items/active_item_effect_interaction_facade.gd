extends RefCounted

const ActiveItemAipillActions := preload("res://scripts/items/active_item_aipill_actions.gd")
const ActiveItemBrickWallHitRuntime := preload("res://scripts/items/active_item_brick_wall_hit_runtime.gd")
const ActiveItemMagnetFieldPull := preload("res://scripts/items/active_item_magnet_field_pull.gd")

var _aipill_actions: Object = ActiveItemAipillActions.new()
var _brick_wall_hit_runtime: Object = ActiveItemBrickWallHitRuntime.new()
var _magnet_field_pull: Object = ActiveItemMagnetFieldPull.new()


func force_stopwatch_recovery_upward(
	target: Object,
	min_upward_speed: float,
	stopwatch_owner_effects: Object
) -> void:
	target.set(
		"stopwatch_original_ball_vel",
		stopwatch_owner_effects.force_recovery_velocity_upward(
			bool(target.get("stopwatch_active")),
			_get_vector2_property(target, "stopwatch_original_ball_vel"),
			min_upward_speed
		)
	)


func apply_magnet_field_ball_pull(target: Object, fps_scale: float, context: Dictionary) -> Dictionary:
	return _magnet_field_pull.apply_ball_pull(bool(target.get("magnet_field_active")), fps_scale, context)


func notify_holy_barrier_hit(
	target: Object,
	impact_pos: Vector2,
	holy_barrier_particles_helper: Object
) -> void:
	if not bool(target.get("holy_barrier_active")):
		return
	holy_barrier_particles_helper.spawn_hit_particles(
		_get_array_property(target, "holy_barrier_particles"),
		impact_pos
	)


func notify_brick_wall_hit(
	target: Object,
	wall_index: int,
	impact_pos: Vector2,
	destroy_hits: int
) -> Dictionary:
	return _brick_wall_hit_runtime.apply_hit(
		_get_array_property(target, "brick_walls"),
		_get_array_property(target, "brick_particles"),
		wall_index,
		impact_pos,
		destroy_hits
	)


func apply_aipill_player_control(
	target: Object,
	player_pos: Vector2,
	_player_speed: float,
	config: Dictionary,
	delta: float
) -> Dictionary:
	return _aipill_actions.apply_player_control(bool(target.get("aipill_active")), player_pos, config, delta)


func apply_aipill_guard_drain(
	target: Object,
	special_gauge: float,
	context: Dictionary,
	deps: Dictionary,
	state_applier: Object,
	effect_feedback: Object
) -> float:
	return _aipill_actions.apply_guard_drain(
		target,
		special_gauge,
		context,
		deps,
		bool(target.get("aipill_active")),
		_get_float_property(target, "aipill_phase"),
		state_applier,
		effect_feedback
	)


# was_active_on_contact: 게이지 소진으로 알약이 이번 히트에서 꺼졌어도, 접촉
# "시점"에 발동 중이었다면 부스트는 유효해야 하므로 호출측 캡처 값을 함께 받는다.
func apply_aipill_ball_hit_speed_boost(
	target: Object,
	ball_vel: Vector2,
	was_active_on_contact: bool
) -> Dictionary:
	return _aipill_actions.apply_ball_hit_speed_boost(
		was_active_on_contact or bool(target.get("aipill_active")),
		ball_vel
	)


func cancel_aipill_if_neural_helmet_direction_pressed(
	target: Object,
	mythic_item_runtime: Object,
	direction_pressed: bool,
	state_applier: Object,
	aipill_runtime: Object
) -> bool:
	if not bool(target.get("aipill_active")) or not direction_pressed:
		return false
	if (
		mythic_item_runtime == null
		or not mythic_item_runtime.has_method("should_cancel_aipill_on_direction_key")
		or not bool(mythic_item_runtime.should_cancel_aipill_on_direction_key())
	):
		return false
	state_applier.apply_aipill_state(target, aipill_runtime.clear_state())
	return true


func _get_array_property(target: Object, key: String) -> Array[Dictionary]:
	var value: Variant = target.get(key)
	if value is Array:
		return value
	return []


func _get_float_property(target: Object, key: String, fallback: float = 0.0) -> float:
	var value: Variant = target.get(key)
	if value is float or value is int:
		return float(value)
	return fallback


func _get_vector2_property(target: Object, key: String, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	var value: Variant = target.get(key)
	if value is Vector2:
		return value
	return fallback
