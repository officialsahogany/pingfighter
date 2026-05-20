extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")

const FEEDBACK_SHAKE_AMOUNT := 0.06
const FEEDBACK_SHAKE_DURATION := 1.6


func apply_gauge_charge(
	item_data: Dictionary,
	owner: Object,
	registry: Object,
	gauge_runtime: Object,
	effect_feedback: Object
) -> bool:
	var gauge_result: Dictionary = _build_gauge_charge_result(item_data, owner, registry, gauge_runtime)
	owner.set("special_gauge", float(gauge_result.get("special_gauge", 0.0)))

	effect_feedback.trigger_registry_feedback(registry, true, false, FEEDBACK_SHAKE_AMOUNT, FEEDBACK_SHAKE_DURATION)
	effect_feedback.play_first_audio(registry, ["play_drink"])

	return true


func apply_life_elixir(
	item_data: Dictionary,
	owner: Object,
	registry: Object,
	particles: Array[Dictionary],
	gauge_runtime: Object,
	player_center_reader: Object,
	life_elixir_particles: Object,
	effect_feedback: Object
) -> bool:
	var elixir_data: Dictionary = gauge_runtime.build_life_elixir_item_data(item_data)
	var applied: bool = apply_gauge_charge(elixir_data, owner, registry, gauge_runtime, effect_feedback)
	if applied:
		life_elixir_particles.spawn_particles(particles, player_center_reader.get_player_center(owner))
	return applied


func _build_gauge_charge_result(
	item_data: Dictionary,
	owner: Object,
	registry: Object,
	gauge_runtime: Object
) -> Dictionary:
	var fallback_gauge_max: float = gauge_runtime.get_item_gauge_max(item_data)
	var owner_gauge_max: float = float(BattleSceneOwnerReader.get_value(owner, "special_gauge_max", fallback_gauge_max))
	return gauge_runtime.build_gauge_charge_result(
		item_data,
		float(BattleSceneOwnerReader.get_value(owner, "special_gauge", 0.0)),
		owner_gauge_max,
		_get_instance(registry, "mythic_item_runtime")
	)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
