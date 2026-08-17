extends RefCounted

const ActiveItemAipillActions := preload("res://scripts/items/active_item_aipill_actions.gd")
const ActiveItemBrickWallActions := preload("res://scripts/items/active_item_brick_wall_actions.gd")
const ActiveItemGaugeActions := preload("res://scripts/items/active_item_gauge_actions.gd")
const ActiveItemHolyBarrierActions := preload("res://scripts/items/active_item_holy_barrier_actions.gd")
const ActiveItemDashBoostActions := preload("res://scripts/items/active_item_dash_boost_actions.gd")
const ActiveItemDurationBonus := preload("res://scripts/items/active_item_duration_bonus.gd")
const ActiveItemMagnetFieldActions := preload("res://scripts/items/active_item_magnet_field_actions.gd")
const ActiveItemPickupActions := preload("res://scripts/items/active_item_pickup_actions.gd")
const ActiveItemRegenerationPotionActions := preload("res://scripts/items/active_item_regeneration_potion_actions.gd")
const ActiveItemStopwatchActions := preload("res://scripts/items/active_item_stopwatch_actions.gd")
const ActiveItemTimedPaddleActivation := preload("res://scripts/items/active_item_timed_paddle_activation.gd")

var _aipill_actions: Object = ActiveItemAipillActions.new()
var _brick_wall_actions: Object = ActiveItemBrickWallActions.new()
var _gauge_actions: Object = ActiveItemGaugeActions.new()
var _holy_barrier_actions: Object = ActiveItemHolyBarrierActions.new()
var _dash_boost_actions: Object = ActiveItemDashBoostActions.new()
var _duration_bonus: Object = ActiveItemDurationBonus.new()
var _magnet_field_actions: Object = ActiveItemMagnetFieldActions.new()
var _pickup_actions: Object = ActiveItemPickupActions.new()
var _regeneration_potion_actions: Object = ActiveItemRegenerationPotionActions.new()
var _stopwatch_actions: Object = ActiveItemStopwatchActions.new()
var _timed_paddle_activation: Object = ActiveItemTimedPaddleActivation.new()


func apply_gauge_charge(
	_target: Object,
	item_data: Dictionary,
	owner: Object,
	registry: Object,
	gauge_runtime: Object,
	effect_feedback: Object
) -> bool:
	return _gauge_actions.apply_gauge_charge(item_data, owner, registry, gauge_runtime, effect_feedback)


func apply_life_elixir(
	target: Object,
	item_data: Dictionary,
	owner: Object,
	registry: Object,
	gauge_runtime: Object,
	player_center_reader: Object,
	life_elixir_particles: Object,
	effect_feedback: Object
) -> bool:
	return _gauge_actions.apply_life_elixir(
		item_data,
		owner,
		registry,
		_get_array_property(target, "pickup_particles"),
		gauge_runtime,
		player_center_reader,
		life_elixir_particles,
		effect_feedback
	)


func apply_lingpet_spirit_water(
	_target: Object,
	_item_data: Dictionary,
	owner: Object,
	registry: Object,
	effect_feedback: Object
) -> bool:
	var lingpet_runtime: Object = _get_cached_instance(registry, "lingpet_egg_runtime")
	if lingpet_runtime == null or not lingpet_runtime.has_method("use_spirit_water"):
		return false
	var result: Variant = lingpet_runtime.use_spirit_water(owner, registry)
	if not (result is Dictionary) or not bool((result as Dictionary).get("accepted", false)):
		return false
	if effect_feedback != null:
		effect_feedback.play_first_audio(registry, ["play_active_item"])
		effect_feedback.trigger_registry_feedback(registry, false, false, 0.015, 0.18)
	return true


func activate_lingpet_egg(
	_target: Object,
	owner: Object,
	registry: Object,
	effect_feedback: Object
) -> bool:
	var lingpet_runtime: Object = _get_instance(registry, "lingpet_egg_runtime")
	if lingpet_runtime == null or not lingpet_runtime.has_method("deploy_egg_from_item"):
		return false
	# deploy_egg_from_item returns false while another egg / acquisition choice is
	# unresolved, so the slot controller leaves the item in the slot.
	if not bool(lingpet_runtime.deploy_egg_from_item(owner, registry)):
		return false
	if effect_feedback != null:
		effect_feedback.play_first_audio(registry, ["play_active_item"])
		effect_feedback.trigger_registry_feedback(registry, false, false, 0.02, 0.22)
	return true


func activate_mystic_dice(
	_target: Object,
	owner: Object,
	registry: Object,
	effect_feedback: Object
) -> bool:
	var runtime_perk_state: Object = _get_instance(registry, "runtime_perk_state")
	if (
		runtime_perk_state == null
		or not runtime_perk_state.has_method("begin_mystic_dice_active_item")
		or not bool(runtime_perk_state.begin_mystic_dice_active_item(owner, registry))
	):
		return false
	if effect_feedback != null:
		effect_feedback.play_first_audio(registry, ["play_active_item"])
		effect_feedback.trigger_registry_feedback(registry, false, false, 0.015, 0.18)
	return true


func apply_ammo_box(
	target: Object,
	item_data: Dictionary,
	owner: Object,
	registry: Object,
	commando_supply_actions: Object,
	effect_feedback: Object
) -> bool:
	return commando_supply_actions.apply_ammo_box(
		target,
		item_data,
		owner,
		registry,
		effect_feedback
	)


func activate_doping_potion(
	target: Object,
	item_data: Dictionary,
	owner: Object,
	registry: Object,
	commando_supply_actions: Object,
	state_applier: Object,
	player_center_reader: Object,
	effect_feedback: Object
) -> bool:
	return commando_supply_actions.activate_doping_potion(
		target,
		item_data,
		owner,
		registry,
		state_applier,
		player_center_reader,
		effect_feedback
	)


func activate_vitamin_pill(
	target: Object,
	owner: Object,
	registry: Object,
	state_applier: Object,
	player_center_reader: Object,
	effect_feedback: Object
) -> bool:
	return _timed_paddle_activation.activate_vitamin_pill(
		target,
		registry,
		bool(target.get("vitamin_pill_active")),
		_read_player_center(player_center_reader, owner, _get_vector2_property(target, "vitamin_pill_player_center")),
		state_applier,
		effect_feedback
	)


func activate_strange_vial(
	target: Object,
	owner: Object,
	registry: Object,
	state_applier: Object,
	paddle_sync: Object,
	player_center_reader: Object,
	effect_feedback: Object,
	enlarge: bool
) -> bool:
	return _timed_paddle_activation.activate_strange_vial(
		target,
		owner,
		registry,
		bool(target.get("strange_vial_active")),
		_read_player_center(player_center_reader, owner, _get_vector2_property(target, "strange_vial_player_center")),
		enlarge,
		state_applier,
		paddle_sync,
		effect_feedback
	)


func activate_long_boost(
	target: Object,
	owner: Object,
	registry: Object,
	state_applier: Object,
	paddle_sync: Object,
	effect_feedback: Object
) -> bool:
	return _timed_paddle_activation.activate_long_boost(
		target,
		owner,
		registry,
		bool(target.get("long_boost_active")),
		state_applier,
		paddle_sync,
		effect_feedback
	)


const MILK_BOTTLE_SCALE_MAX := 1.60


func activate_milk_bottle(
	target: Object,
	item_data: Dictionary,
	owner: Object,
	registry: Object,
	paddle_sync: Object,
	effect_feedback: Object
) -> bool:
	_apply_milk_bottle_scale(target, item_data, owner, paddle_sync)
	if effect_feedback != null:
		effect_feedback.play_first_audio(registry, ["play_active_item"])
		effect_feedback.trigger_registry_feedback(registry, false, false, 2.0, 0.10)
	return true


func activate_cheese(
	target: Object,
	item_data: Dictionary,
	owner: Object,
	registry: Object,
	gauge_runtime: Object,
	paddle_sync: Object,
	effect_feedback: Object
) -> bool:
	# Cheese grants the milk-bottle paddle/character size buff AND restores the gauge.
	# apply_gauge_charge owns the pickup feedback (drink SFX + shake), so the shared
	# scale helper stays feedback-free to avoid a double cue.
	_apply_milk_bottle_scale(target, item_data, owner, paddle_sync)
	return apply_gauge_charge(target, item_data, owner, registry, gauge_runtime, effect_feedback)


func _apply_milk_bottle_scale(target: Object, item_data: Dictionary, owner: Object, paddle_sync: Object) -> void:
	target.set("milk_bottle_active", true)
	# Each use stacks the paddle growth by this bottle's increment (multiplier - 1.0),
	# accumulating on top of any active milk buff up to MILK_BOTTLE_SCALE_MAX (+60%).
	# Milk bottles and cheese share this single scale pool and cap.
	var increment: float = maxf(0.0, float(item_data.get("paddle_scale_multiplier", 1.20)) - 1.0)
	var current_scale: float = maxf(1.0, float(target.get("milk_bottle_scale")))
	target.set("milk_bottle_scale", clampf(current_scale + increment, 1.0, MILK_BOTTLE_SCALE_MAX))
	if paddle_sync != null and target.has_method("get_player_paddle_scale"):
		paddle_sync.sync_owner_state(owner, float(target.get_player_paddle_scale()))


func activate_aipill(target: Object, registry: Object, state_applier: Object, effect_feedback: Object) -> bool:
	return _aipill_actions.activate(target, registry, state_applier, effect_feedback)


func apply_regeneration_potion(
	target: Object,
	owner: Object,
	registry: Object,
	player_center_reader: Object,
	regeneration_potion_effect: Object,
	effect_feedback: Object
) -> bool:
	return _regeneration_potion_actions.apply(
		owner,
		registry,
		_get_array_property(target, "regeneration_potion_particles"),
		_get_array_property(target, "regeneration_potion_rings"),
		player_center_reader,
		regeneration_potion_effect,
		effect_feedback
	)


func activate_stopwatch(
	target: Object,
	owner: Object,
	registry: Object,
	player_center_reader: Object,
	stopwatch_runtime: Object,
	state_applier: Object,
	effect_feedback: Object
) -> bool:
	return _stopwatch_actions.activate(
		target,
		owner,
		registry,
		bool(target.get("stopwatch_active")),
		player_center_reader,
		stopwatch_runtime,
		state_applier,
		effect_feedback
	)


func activate_magnet_field(
	target: Object,
	owner: Object,
	registry: Object,
	player_center_reader: Object,
	magnet_field_runtime: Object,
	state_applier: Object,
	effect_feedback: Object
) -> bool:
	return _magnet_field_actions.activate(
		target,
		owner,
		registry,
		bool(target.get("magnet_field_active")),
		player_center_reader,
		magnet_field_runtime,
		state_applier,
		effect_feedback
	)


func activate_holy_barrier(
	target: Object,
	registry: Object,
	holy_barrier_runtime: Object,
	state_applier: Object,
	effect_feedback: Object
) -> bool:
	return _holy_barrier_actions.activate(
		target,
		registry,
		holy_barrier_runtime,
		state_applier,
		effect_feedback
	)


func activate_dash_boost(
	target: Object,
	owner: Object,
	registry: Object,
	player_center_reader: Object,
	dash_boost_runtime: Object,
	state_applier: Object,
	effect_feedback: Object
) -> bool:
	return _dash_boost_actions.activate(
		target,
		registry,
		dash_boost_runtime,
		_read_player_center(player_center_reader, owner, _get_vector2_property(target, "dash_boost_player_center")),
		state_applier,
		effect_feedback
	)


func activate_wall(
	target: Object,
	owner: Object,
	registry: Object,
	brick_wall_geometry: Object,
	brick_wall_installation: Object,
	brick_wall_particles: Object,
	state_applier: Object,
	effect_feedback: Object
) -> bool:
	return _brick_wall_actions.activate(
		target,
		owner,
		registry,
		bool(target.get("brick_wall_installing")),
		_get_array_property(target, "brick_particles"),
		brick_wall_geometry,
		brick_wall_installation,
		brick_wall_particles,
		state_applier,
		effect_feedback
	)


func trigger_pickup_effect(
	target: Object,
	field_item: Dictionary,
	display_name: String,
	item_color: Color,
	registry: Object,
	pickup_effect_state: Object,
	effect_feedback: Object
) -> void:
	_pickup_actions.trigger(
		target,
		field_item,
		display_name,
		item_color,
		registry,
		_get_array_property(target, "pickup_particles"),
		pickup_effect_state,
		effect_feedback
	)


func _read_player_center(player_center_reader: Object, owner: Object, fallback: Vector2) -> Vector2:
	if owner == null:
		return fallback
	return player_center_reader.get_player_center(owner)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _get_cached_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_cached_instance"):
		return null
	var value: Variant = registry.get_cached_instance(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _get_array_property(target: Object, key: String) -> Array[Dictionary]:
	var value: Variant = target.get(key)
	if value is Array:
		return value
	return []


func _get_vector2_property(target: Object, key: String) -> Vector2:
	var value: Variant = target.get(key)
	if value is Vector2:
		return value
	return Vector2.ZERO
