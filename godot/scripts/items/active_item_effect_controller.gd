extends RefCounted

const ActiveItemEffectStateApplier := preload("res://scripts/items/active_item_effect_state_applier.gd")
const ActiveItemPaddleSync := preload("res://scripts/items/active_item_paddle_sync.gd")
const ActiveItemHolyBarrierParticles := preload("res://scripts/items/active_item_holy_barrier_particles.gd")
const ActiveItemHolyBarrierRuntime := preload("res://scripts/items/active_item_holy_barrier_runtime.gd")
const ActiveItemDashBoostParticles := preload("res://scripts/items/active_item_dash_boost_particles.gd")
const ActiveItemDashBoostRuntime := preload("res://scripts/items/active_item_dash_boost_runtime.gd")
const ActiveItemGyeongsinhwanParticles := preload("res://scripts/items/active_item_gyeongsinhwan_particles.gd")
const ActiveItemMagnetFieldParticles := preload("res://scripts/items/active_item_magnet_field_particles.gd")
const ActiveItemMagnetFieldRuntime := preload("res://scripts/items/active_item_magnet_field_runtime.gd")
const ActiveItemAipillRuntime := preload("res://scripts/items/active_item_aipill_runtime.gd")
const ActiveItemPickupEffectState := preload("res://scripts/items/active_item_pickup_effect_state.gd")
const ActiveItemBrickWallGeometry := preload("res://scripts/items/active_item_brick_wall_geometry.gd")
const ActiveItemTrampolineRuntime := preload("res://scripts/items/active_item_trampoline_runtime.gd")
const ActiveItemCampfireRuntime := preload("res://scripts/items/active_item_campfire_runtime.gd")
const ActiveItemBrickWallParticles := preload("res://scripts/items/active_item_brick_wall_particles.gd")
const ActiveItemBrickWallInstallation := preload("res://scripts/items/active_item_brick_wall_installation.gd")
const ActiveItemPlayerCenterReader := preload("res://scripts/items/active_item_player_center_reader.gd")
const ActiveItemRegenerationPotionEffect := preload("res://scripts/items/active_item_regeneration_potion_effect.gd")
const ActiveItemTimedPaddleEffects := preload("res://scripts/items/active_item_timed_paddle_effects.gd")
const ActiveItemLifeElixirParticles := preload("res://scripts/items/active_item_life_elixir_particles.gd")
const ActiveItemEffectFeedback := preload("res://scripts/items/active_item_effect_feedback.gd")
const ActiveItemGaugeRuntime := preload("res://scripts/items/active_item_gauge_runtime.gd")
const ActiveItemStopwatchRuntime := preload("res://scripts/items/active_item_stopwatch_runtime.gd")
const ActiveItemStopwatchOwnerEffects := preload("res://scripts/items/active_item_stopwatch_owner_effects.gd")
const ActiveItemEffectReset := preload("res://scripts/items/active_item_effect_reset.gd")
const ActiveItemTransientEffectUpdater := preload("res://scripts/items/active_item_transient_effect_updater.gd")
const ActiveItemEffectUpdateDriver := preload("res://scripts/items/active_item_effect_update_driver.gd")
const ActiveItemEffectQuery := preload("res://scripts/items/active_item_effect_query.gd")
const ActiveItemEffectActionFacade := preload("res://scripts/items/active_item_effect_action_facade.gd")
const ActiveItemEffectInteractionFacade := preload("res://scripts/items/active_item_effect_interaction_facade.gd")
const ActiveItemCommandoSupplyActions := preload("res://scripts/items/active_item_commando_supply_actions.gd")
const ElixirOfMasteryRuntime := preload("res://scripts/items/elixir_of_mastery_runtime.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const PLAYER_BASE_PADDLE_WIDTH := 155.0
const PLAYER_BASE_PADDLE_HEIGHT := 50.0
const BRICK_WALL_DESTROY_HITS := 2

var regeneration_potion_particles: Array[Dictionary] = []
var regeneration_potion_rings: Array[Dictionary] = []
var holy_barrier_particles: Array[Dictionary] = []
var pickup_particles: Array[Dictionary] = []
var pickup_effect: Dictionary = {}
var aipill_active: bool = false
var aipill_phase: float = 0.0
var aipill_flash_timer_frames: float = 0.0
var long_boost_active: bool = false
var long_boost_timer_frames: float = 0.0
var long_boost_initial_timer_frames: float = 0.0
var long_boost_scale: float = 1.0
var milk_bottle_active: bool = false
var milk_bottle_scale: float = 1.0
var vitamin_pill_active: bool = false
var vitamin_pill_timer_frames: float = 0.0
var vitamin_pill_initial_timer_frames: float = 0.0
var vitamin_pill_phase: float = 0.0
var vitamin_pill_flash_timer_frames: float = 0.0
var vitamin_pill_player_center: Vector2 = Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT - PLAYER_BASE_PADDLE_HEIGHT * 0.5)
var vitamin_pill_particle_accumulator_frames: float = 0.0
var vitamin_pill_particles: Array[Dictionary] = []
var strange_vial_active: bool = false
var strange_vial_timer_frames: float = 0.0
var strange_vial_initial_timer_frames: float = 0.0
var strange_vial_effect_type: String = ""
var strange_vial_scale: float = 1.0
var strange_vial_target_scale: float = 1.0
var strange_vial_speed_multiplier: float = 1.0
var strange_vial_target_speed_multiplier: float = 1.0
var strange_vial_phase: float = 0.0
var strange_vial_flash_timer_frames: float = 0.0
var strange_vial_player_center: Vector2 = Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT - PLAYER_BASE_PADDLE_HEIGHT * 0.5)
var doping_potion_active: bool = false
var doping_potion_timer_frames: float = 0.0
var doping_potion_initial_timer_frames: float = 0.0
var doping_potion_phase: float = 0.0
var doping_potion_flash_timer_frames: float = 0.0
var doping_potion_player_center: Vector2 = Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT - PLAYER_BASE_PADDLE_HEIGHT * 0.5)
var doping_potion_use_count: int = 0
var stopwatch_active: bool = false
var stopwatch_timer_frames: float = 0.0
var stopwatch_initial_timer_frames: float = 0.0
var stopwatch_recovery_timer_frames: float = 0.0
var stopwatch_post_recovery_grace_frames: float = 0.0
var stopwatch_original_ball_vel: Vector2 = Vector2.ZERO
var stopwatch_flash_timer_frames: float = 0.0
var stopwatch_clock_angle: float = 0.0
var magnet_field_active: bool = false
var magnet_field_timer_frames: float = 0.0
var magnet_field_initial_timer_frames: float = 0.0
var magnet_field_phase: float = 0.0
var magnet_field_player_center: Vector2 = Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT - PLAYER_BASE_PADDLE_HEIGHT * 0.5)
var magnet_field_particle_accumulator_frames: float = 0.0
var magnet_field_particles: Array[Dictionary] = []
var holy_barrier_active: bool = false
var holy_barrier_timer_frames: float = 0.0
var holy_barrier_initial_timer_frames: float = 0.0
var holy_barrier_glow_phase: float = 0.0
var holy_barrier_particle_accumulator_frames: float = 0.0
var dash_boost_active: bool = false
var dash_boost_timer_frames: float = 0.0
var dash_boost_initial_timer_frames: float = 0.0
var dash_boost_glow_phase: float = 0.0
var dash_boost_particle_accumulator_frames: float = 0.0
var dash_boost_player_center: Vector2 = Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT - PLAYER_BASE_PADDLE_HEIGHT * 0.5)
var dash_boost_particles: Array[Dictionary] = []
var brick_walls: Array[Dictionary] = []
var pending_brick_wall: Dictionary = {}
var brick_wall_installing: bool = false
var brick_wall_install_timer_frames: float = 0.0
var brick_wall_install_initial_frames: float = 0.0
var brick_particles: Array[Dictionary] = []
var trampolines: Array[Dictionary] = []
var trampoline_particles: Array[Dictionary] = []
var campfires: Array[Dictionary] = []
var campfire_particles: Array[Dictionary] = []
var campfire_player_in_range: bool = false
var campfire_vigor_accumulator: float = 0.0
var campfire_cooldown_bonus_msec_carry: float = 0.0
var _state_applier: Object = ActiveItemEffectStateApplier.new()
var _paddle_sync: Object = ActiveItemPaddleSync.new()
var _holy_barrier_particles: Object = ActiveItemHolyBarrierParticles.new()
var _holy_barrier_runtime: Object = ActiveItemHolyBarrierRuntime.new()
var _dash_boost_particles: Object = ActiveItemDashBoostParticles.new()
var _dash_boost_runtime: Object = ActiveItemDashBoostRuntime.new()
var _gyeongsinhwan_particles: Object = ActiveItemGyeongsinhwanParticles.new()
var _magnet_field_particles: Object = ActiveItemMagnetFieldParticles.new()
var _magnet_field_runtime: Object = ActiveItemMagnetFieldRuntime.new()
var _aipill_runtime: Object = ActiveItemAipillRuntime.new()
var _pickup_effect_state: Object = ActiveItemPickupEffectState.new()
var _brick_wall_geometry: Object = ActiveItemBrickWallGeometry.new()
var _brick_wall_particles: Object = ActiveItemBrickWallParticles.new()
var _brick_wall_installation: Object = ActiveItemBrickWallInstallation.new()
var _trampoline_runtime: Object = ActiveItemTrampolineRuntime.new()
var _campfire_runtime: Object = ActiveItemCampfireRuntime.new()
var _player_center_reader: Object = ActiveItemPlayerCenterReader.new()
var _regeneration_potion_effect: Object = ActiveItemRegenerationPotionEffect.new()
var _timed_paddle_effects: Object = ActiveItemTimedPaddleEffects.new()
var _life_elixir_particles: Object = ActiveItemLifeElixirParticles.new()
var _effect_feedback: Object = ActiveItemEffectFeedback.new()
var _gauge_runtime: Object = ActiveItemGaugeRuntime.new()
var _stopwatch_runtime: Object = ActiveItemStopwatchRuntime.new()
var _stopwatch_owner_effects: Object = ActiveItemStopwatchOwnerEffects.new()
var _effect_reset: Object = ActiveItemEffectReset.new()
var _transient_effect_updater: Object = ActiveItemTransientEffectUpdater.new()
var _effect_update_driver: Object = ActiveItemEffectUpdateDriver.new()
var _effect_query: Object = ActiveItemEffectQuery.new()
var _effect_action_facade: Object = ActiveItemEffectActionFacade.new()
var _effect_interaction_facade: Object = ActiveItemEffectInteractionFacade.new()
var _commando_supply_actions: Object = ActiveItemCommandoSupplyActions.new()
var _elixir_of_mastery_runtime: Object = ElixirOfMasteryRuntime.new()


func _init() -> void:
	_effect_update_driver.configure({
		"state_applier": _state_applier,
		"paddle_sync": _paddle_sync,
		"player_center_reader": _player_center_reader,
		"aipill_runtime": _aipill_runtime,
		"stopwatch_runtime": _stopwatch_runtime,
		"stopwatch_owner_effects": _stopwatch_owner_effects,
		"magnet_field_runtime": _magnet_field_runtime,
		"magnet_field_particles": _magnet_field_particles,
		"timed_paddle_effects": _timed_paddle_effects,
		"gyeongsinhwan_particles": _gyeongsinhwan_particles,
		"holy_barrier_runtime": _holy_barrier_runtime,
		"holy_barrier_particles": _holy_barrier_particles,
		"dash_boost_runtime": _dash_boost_runtime,
		"dash_boost_particles": _dash_boost_particles,
		"brick_wall_installation": _brick_wall_installation,
		"brick_wall_particles": _brick_wall_particles,
		"trampoline_runtime": _trampoline_runtime,
		"transient_effect_updater": _transient_effect_updater,
		"regeneration_potion_effect": _regeneration_potion_effect,
		"pickup_effect_state": _pickup_effect_state,
		"commando_supply_actions": _commando_supply_actions,
	})


func reset() -> void:
	_effect_reset.apply(
		self,
		_state_applier,
		_aipill_runtime,
		_timed_paddle_effects,
		_stopwatch_runtime,
		_magnet_field_runtime,
		_holy_barrier_runtime,
		_dash_boost_runtime,
		_brick_wall_installation,
		_commando_supply_actions
	)


func update(
	owner: Object,
	delta: float,
	warp_gate_state: Object = null,
	mythic_item_runtime: Object = null,
	perf_logger: Object = null
) -> void:
	_effect_update_driver.apply_update(self, owner, delta, warp_gate_state, mythic_item_runtime, perf_logger)


func apply_gauge_charge(item_data: Dictionary, owner: Object, registry: Object) -> bool:
	return _effect_action_facade.apply_gauge_charge(self, item_data, owner, registry, _gauge_runtime, _effect_feedback)


func apply_life_elixir(item_data: Dictionary, owner: Object, registry: Object) -> bool:
	return _effect_action_facade.apply_life_elixir(
		self, item_data, owner, registry, _gauge_runtime,
		_player_center_reader, _life_elixir_particles, _effect_feedback
	)


func apply_lingpet_spirit_water(item_data: Dictionary, owner: Object, registry: Object) -> bool:
	return _effect_action_facade.apply_lingpet_spirit_water(
		self,
		item_data,
		owner,
		registry,
		_effect_feedback
	)


func activate_lingpet_egg(owner: Object, registry: Object) -> bool:
	return _effect_action_facade.activate_lingpet_egg(
		self,
		owner,
		registry,
		_effect_feedback
	)


func activate_mystic_dice(owner: Object, registry: Object) -> bool:
	return _effect_action_facade.activate_mystic_dice(
		self,
		owner,
		registry,
		_effect_feedback
	)


func apply_ammo_box(item_data: Dictionary, owner: Object, registry: Object) -> bool:
	return _effect_action_facade.apply_ammo_box(
		self,
		item_data,
		owner,
		registry,
		_commando_supply_actions,
		_effect_feedback
	)


func activate_doping_potion(item_data: Dictionary, owner: Object, registry: Object) -> bool:
	return _effect_action_facade.activate_doping_potion(
		self,
		item_data,
		owner,
		registry,
		_commando_supply_actions,
		_state_applier,
		_player_center_reader,
		_effect_feedback
	)


func activate_vitamin_pill(owner: Object, registry: Object) -> bool:
	var activated: bool = _effect_action_facade.activate_vitamin_pill(
		self,
		owner,
		registry,
		_state_applier,
		_player_center_reader,
		_effect_feedback
	)
	if activated:
		vitamin_pill_particle_accumulator_frames = 0.0
		vitamin_pill_particles.clear()
	return activated


func activate_strange_vial(owner: Object, registry: Object) -> bool:
	return _effect_action_facade.activate_strange_vial(
		self,
		owner,
		registry,
		_state_applier,
		_paddle_sync,
		_player_center_reader,
		_effect_feedback,
		randf() < 0.5
	)


func activate_long_boost(owner: Object, registry: Object) -> bool:
	return _effect_action_facade.activate_long_boost(
		self,
		owner,
		registry,
		_state_applier,
		_paddle_sync,
		_effect_feedback
	)


func activate_milk_bottle(item_data: Dictionary, owner: Object, registry: Object) -> bool:
	return _effect_action_facade.activate_milk_bottle(
		self,
		item_data,
		owner,
		registry,
		_paddle_sync,
		_effect_feedback
	)


func activate_cheese(item_data: Dictionary, owner: Object, registry: Object) -> bool:
	return _effect_action_facade.activate_cheese(self, item_data, owner, registry, _gauge_runtime, _paddle_sync, _effect_feedback)


func activate_aipill(_owner: Object, registry: Object) -> bool:
	var activated: bool = bool(_effect_action_facade.activate_aipill(self, registry, _state_applier, _effect_feedback))
	if activated:
		_aipill_runtime.reset_gangsin_cancel_down_hold()
	return activated


func clear_aipill() -> void:
	_state_applier.apply_aipill_state(self, _aipill_runtime.clear_state())


func apply_regeneration_potion(owner: Object, registry: Object) -> bool:
	return _effect_action_facade.apply_regeneration_potion(
		self,
		owner,
		registry,
		_player_center_reader,
		_regeneration_potion_effect,
		_effect_feedback
	)


func activate_stopwatch(owner: Object, registry: Object) -> bool:
	return _effect_action_facade.activate_stopwatch(
		self,
		owner,
		registry,
		_player_center_reader,
		_stopwatch_runtime,
		_state_applier,
		_effect_feedback
	)


func activate_magnet_field(owner: Object, registry: Object) -> bool:
	return _effect_action_facade.activate_magnet_field(
		self,
		owner,
		registry,
		_player_center_reader,
		_magnet_field_runtime,
		_state_applier,
		_effect_feedback
	)


func activate_holy_barrier(_owner: Object, registry: Object) -> bool:
	return _effect_action_facade.activate_holy_barrier(
		self,
		registry,
		_holy_barrier_runtime,
		_state_applier,
		_effect_feedback
	)


func activate_dash_boost(owner: Object, registry: Object) -> bool:
	return _effect_action_facade.activate_dash_boost(
		self,
		owner,
		registry,
		_player_center_reader,
		_dash_boost_runtime,
		_state_applier,
		_effect_feedback
	)


func activate_wall(owner: Object, registry: Object) -> bool:
	return _effect_action_facade.activate_wall(
		self,
		owner,
		registry,
		_brick_wall_geometry,
		_brick_wall_installation,
		_brick_wall_particles,
		_state_applier,
		_effect_feedback
	)


func activate_trampoline(owner: Object, registry: Object) -> bool:
	if owner == null:
		return false
	var mythic_item_runtime: Object = null
	if registry != null and registry.has_method("get_instance"):
		mythic_item_runtime = registry.get_instance("mythic_item_runtime")
	var trampoline: Dictionary = _trampoline_runtime.build_spawn_trampoline(owner, mythic_item_runtime)
	trampolines.append(trampoline)
	_trampoline_runtime.spawn_install_particles(trampoline_particles, trampoline.get("rect", Rect2()))
	_effect_feedback.trigger_registry_feedback(registry, false, false, 0.02, 0.7)
	_effect_feedback.play_first_audio(registry, ["play_active_item"])
	return true


func activate_campfire(owner: Object, registry: Object) -> bool:
	if owner == null:
		return false
	var campfire: Dictionary = _campfire_runtime.build_spawn_campfire(owner, registry)
	campfires.append(campfire)
	_campfire_runtime.spawn_install_particles(campfire_particles, campfire.get("rect", Rect2()))
	_effect_feedback.trigger_registry_feedback(registry, false, false, 0.018, 0.55)
	_effect_feedback.play_first_audio(registry, ["play_active_item"])
	return true


func update_campfires(owner: Object, registry: Object, delta: float) -> void:
	if not needs_campfire_update():
		campfire_player_in_range = false
		campfire_vigor_accumulator = 0.0
		campfire_cooldown_bonus_msec_carry = 0.0
		return
	var result: Dictionary = _campfire_runtime.update(
		campfires,
		campfire_particles,
		owner,
		registry,
		delta,
		campfire_vigor_accumulator,
		campfire_cooldown_bonus_msec_carry
	)
	campfire_player_in_range = bool(result.get("player_in_range", false))
	campfire_vigor_accumulator = float(result.get("vigor_accumulator", 0.0))
	campfire_cooldown_bonus_msec_carry = float(result.get("cooldown_bonus_msec_carry", 0.0))
	if int(result.get("dash_destroyed_count", 0)) > 0:
		_effect_feedback.trigger_registry_feedback(registry, false, false, 0.035, 1.0)
		_effect_feedback.play_first_audio(registry, ["play_molotov_explosion", "play_brick_wall_destroy"])


func needs_campfire_update() -> bool:
	return not campfires.is_empty() or not campfire_particles.is_empty()


func can_store_item(item_name: String) -> bool:
	return _effect_query.can_store_item(self, item_name)


func trigger_pickup_effect(
	field_item: Dictionary,
	display_name: String,
	item_color: Color,
	registry: Object
) -> void:
	_effect_action_facade.trigger_pickup_effect(
		self, field_item, display_name, item_color, registry,
		_pickup_effect_state, _effect_feedback
	)


func sync_long_boost_owner_state(owner: Object, warp_gate_state: Object = null, mythic_item_runtime: Object = null) -> void:
	_paddle_sync.sync_owner_state(owner, get_player_paddle_scale(), warp_gate_state, mythic_item_runtime)


func get_player_paddle_scale() -> float:
	return _effect_query.get_player_paddle_scale(self)


func get_player_paddle_width(base_width: float = PLAYER_BASE_PADDLE_WIDTH) -> float:
	return _effect_query.get_player_paddle_width(self, base_width)


func get_player_paddle_height(base_height: float = PLAYER_BASE_PADDLE_HEIGHT) -> float:
	return _effect_query.get_player_paddle_height(self, base_height)


func get_pickup_effect() -> Dictionary:
	return _effect_query.get_pickup_effect(self)


func has_pickup_effect() -> bool:
	return _effect_query.has_pickup_effect(self)


func has_field_effects() -> bool:
	return _effect_query.has_field_effects(self)


func get_pickup_particles() -> Array[Dictionary]:
	return _effect_query.get_pickup_particles(self)


func get_regeneration_potion_particles() -> Array[Dictionary]:
	return _effect_query.get_regeneration_potion_particles(self)


func get_regeneration_potion_rings() -> Array[Dictionary]:
	return _effect_query.get_regeneration_potion_rings(self)


func get_magnet_field_particles() -> Array[Dictionary]:
	return _effect_query.get_magnet_field_particles(self)


func get_holy_barrier_particles() -> Array[Dictionary]:
	return _effect_query.get_holy_barrier_particles(self)


func get_dash_boost_particles() -> Array[Dictionary]:
	return _effect_query.get_dash_boost_particles(self)


func get_vitamin_pill_particles() -> Array[Dictionary]:
	return _effect_query.get_vitamin_pill_particles(self)


func get_field_effect_draw_context() -> Dictionary:
	return _effect_query.get_field_effect_draw_context(self)


func get_brick_wall_context() -> Dictionary:
	return _effect_query.get_brick_wall_context(self)


func get_long_boost_timer_context() -> Dictionary:
	return _effect_query.get_long_boost_timer_context(self)


func get_vitamin_pill_timer_context() -> Dictionary:
	return _effect_query.get_vitamin_pill_timer_context(self)


func get_strange_vial_timer_context() -> Dictionary:
	return _effect_query.get_strange_vial_timer_context(self)


func get_doping_potion_context() -> Dictionary:
	return _effect_query.get_doping_potion_context(self)


func get_player_speed_multiplier() -> float:
	return _effect_query.get_player_speed_multiplier(self)


func get_aipill_context() -> Dictionary:
	return _effect_query.get_aipill_context(self)


func get_stopwatch_context() -> Dictionary:
	return _effect_query.get_stopwatch_context(self)


func get_magnet_field_context() -> Dictionary:
	return _effect_query.get_magnet_field_context(self)


func get_holy_barrier_context() -> Dictionary:
	return _effect_query.get_holy_barrier_context(self)


func get_holy_barrier_collision_context() -> Dictionary:
	return _effect_query.get_holy_barrier_collision_context(self)


func get_dash_boost_context() -> Dictionary:
	return _effect_query.get_dash_boost_context(self)


func get_dash_boost_timer_context() -> Dictionary:
	return _effect_query.get_dash_boost_timer_context(self)
func get_player_stat_breakdown(stat_key: String) -> Array:
	return _effect_query.get_player_stat_breakdown(self, stat_key)




func get_brick_wall_collision_context() -> Dictionary:
	return _effect_query.get_brick_wall_collision_context(self)


func get_trampoline_collision_context() -> Dictionary:
	return {
		"trampolines": trampolines,
	}


func get_trampoline_context() -> Dictionary:
	if trampolines.is_empty() and trampoline_particles.is_empty():
		return {}
	return {
		"trampolines": trampolines,
		"particles": trampoline_particles,
	}


func get_campfire_collision_context() -> Dictionary:
	return _campfire_runtime.build_collision_context(campfires)


func get_campfire_context() -> Dictionary:
	return _campfire_runtime.build_draw_context(
		campfires,
		campfire_particles,
		campfire_player_in_range
	)


func get_stopwatch_ball_context() -> Dictionary:
	return _effect_query.get_stopwatch_ball_context(self)


func is_time_frozen() -> bool:
	return _effect_query.is_time_frozen(self)


func is_aipill_active() -> bool:
	return _effect_query.is_aipill_active(self)


func is_stopwatch_active() -> bool:
	return _effect_query.is_stopwatch_active(self)


func is_doping_potion_active() -> bool:
	return _effect_query.is_doping_potion_active(self)


func is_holy_barrier_active() -> bool:
	return _effect_query.is_holy_barrier_active(self)


func is_dash_boost_active() -> bool:
	return _effect_query.is_dash_boost_active(self)


func is_milk_bottle_active() -> bool:
	return bool(milk_bottle_active)


func get_dash_cost_multiplier() -> float:
	return _dash_boost_runtime.get_cost_multiplier(_effect_query.is_dash_boost_active(self))


func get_dash_cooldown_multiplier() -> float:
	return (
		_dash_boost_runtime.get_cooldown_multiplier(_effect_query.is_dash_boost_active(self))
		* _campfire_runtime.get_dash_cooldown_multiplier(campfire_player_in_range)
	)


func get_dash_boost_remaining_ratio() -> float:
	return _effect_query.get_dash_boost_remaining_ratio(self)


func get_dash_boost_remaining_time() -> float:
	return _effect_query.get_dash_boost_remaining_time(self)


func force_stopwatch_recovery_upward(min_upward_speed: float = 7.65) -> void:
	_effect_interaction_facade.force_stopwatch_recovery_upward(self, min_upward_speed, _stopwatch_owner_effects)


func is_magnet_field_active() -> bool:
	return _effect_query.is_magnet_field_active(self)


func is_wall_installing() -> bool:
	return _effect_query.is_wall_installing(self)


func apply_magnet_field_ball_pull(fps_scale: float, context: Dictionary) -> Dictionary:
	return _effect_interaction_facade.apply_magnet_field_ball_pull(self, fps_scale, context)


func notify_holy_barrier_hit(impact_pos: Vector2) -> void:
	_effect_interaction_facade.notify_holy_barrier_hit(self, impact_pos, _holy_barrier_particles)


func notify_brick_wall_hit(wall_index: int, impact_pos: Vector2) -> Dictionary:
	return _effect_interaction_facade.notify_brick_wall_hit(self, wall_index, impact_pos, BRICK_WALL_DESTROY_HITS)


func notify_trampoline_hit(trampoline_index: int, ball_pos: Vector2, ball_vel: Vector2) -> Dictionary:
	return _trampoline_runtime.apply_contact(trampolines, trampoline_particles, trampoline_index, ball_pos, ball_vel)


func notify_campfire_hit(campfire_index: int, impact_pos: Vector2) -> Dictionary:
	var result: Dictionary = _campfire_runtime.destroy_on_ball_hit(
		campfires,
		campfire_particles,
		campfire_index,
		impact_pos
	)
	if campfires.is_empty():
		campfire_player_in_range = false
		campfire_vigor_accumulator = 0.0
		campfire_cooldown_bonus_msec_carry = 0.0
	return result


func apply_aipill_player_control(player_pos: Vector2, player_speed: float, config: Dictionary, delta: float) -> Dictionary:
	return _effect_interaction_facade.apply_aipill_player_control(self, player_pos, player_speed, config, delta)


func apply_aipill_guard_drain(special_gauge: float, context: Dictionary, deps: Dictionary) -> float:
	return _effect_interaction_facade.apply_aipill_guard_drain(
		self,
		special_gauge,
		context,
		deps,
		_state_applier,
		_effect_feedback
	)


func apply_aipill_ball_hit_speed_boost(
	ball_vel: Vector2,
	was_active_on_contact: bool = false,
	gangsin_bonus_pct: float = 0.0
) -> Dictionary:
	return _effect_interaction_facade.apply_aipill_ball_hit_speed_boost(
		self,
		ball_vel,
		was_active_on_contact,
		gangsin_bonus_pct
	)


func cancel_aipill_if_neural_helmet_direction_pressed(
	mythic_item_runtime: Object,
	direction_pressed: bool = true
) -> bool:
	return _effect_interaction_facade.cancel_aipill_if_neural_helmet_direction_pressed(
		self,
		mythic_item_runtime,
		direction_pressed,
		_state_applier,
		_aipill_runtime
	)


func update_aipill_gangsin_down_hold_cancel(
	mythic_item_runtime: Object,
	down_pressed: bool,
	delta: float
) -> bool:
	var cancel_enabled := (
		mythic_item_runtime != null
		and mythic_item_runtime.has_method("can_cancel_aipill_with_gangsin_down_hold")
		and bool(mythic_item_runtime.can_cancel_aipill_with_gangsin_down_hold())
	)
	var hold_completed: bool = bool(_aipill_runtime.advance_gangsin_cancel_down_hold(
		aipill_active,
		cancel_enabled,
		down_pressed,
		delta
	))
	return _effect_interaction_facade.cancel_aipill_if_gangsin_down_hold_completed(
		self,
		mythic_item_runtime,
		hold_completed,
		_state_applier,
		_aipill_runtime
	)


func _get_stopwatch_recovery_speed_ratio() -> float:
	return _effect_query.get_stopwatch_recovery_speed_ratio(self)


@warning_ignore("unused_parameter")
func activate_elixir_of_mastery(owner: Object, registry: Object) -> bool:
	if _elixir_of_mastery_runtime.cinematic_active:
		return false
	if registry == null or not registry.has_method("get_instance"):
		return false
	var perk_state: Object = registry.get_instance("runtime_perk_state")
	var perk_catalog: Object = registry.get_instance("runtime_perk_catalog")
	if perk_state == null or perk_catalog == null:
		return false
	if not perk_catalog.has_method("get_all_perk_data") or not perk_state.has_method("apply_choice"):
		return false
	var runtime_skill_levels: Dictionary = perk_state.runtime_skill_levels if "runtime_skill_levels" in perk_state else {}
	var all_perk_data: Dictionary = perk_catalog.get_all_perk_data()
	var capacity_safe_pool: Dictionary = {}
	for skill_id_value in all_perk_data.keys():
		var skill_id := str(skill_id_value)
		var perk_data_value: Variant = all_perk_data.get(skill_id_value, {})
		if not (perk_data_value is Dictionary):
			continue
		var perk_data := perk_data_value as Dictionary
		var target_level := ElixirOfMasteryRuntime.get_mastery_target_level(skill_id, perk_data)
		if target_level <= 0:
			continue
		if perk_catalog.has_method("get_perk_slot_apply_status"):
			var status_value: Variant = perk_catalog.call(
				"get_perk_slot_apply_status",
				perk_data,
				runtime_skill_levels,
				registry,
				target_level
			)
			if not (status_value is Dictionary) or not bool((status_value as Dictionary).get("accepted", false)):
				continue
		capacity_safe_pool[skill_id] = perk_data.duplicate(true)
	var all_skill_pools: Array = [capacity_safe_pool]
	var apply_func: Callable = func(skill_id: String) -> void:
		var perk_data: Dictionary = perk_catalog.get_perk_data(skill_id) if perk_catalog.has_method("get_perk_data") else {}
		if perk_data.is_empty():
			return
		var choice: Dictionary = perk_data.duplicate(true)
		choice["id"] = skill_id
		perk_state.apply_choice(choice, owner, registry)
	return _elixir_of_mastery_runtime.activate(runtime_skill_levels, all_skill_pools, apply_func)


func get_elixir_of_mastery_runtime() -> Object:
	return _elixir_of_mastery_runtime


func is_elixir_cinematic_active() -> bool:
	return _elixir_of_mastery_runtime.cinematic_active


func update_elixir_cinematic(dt: float) -> void:
	_elixir_of_mastery_runtime.update(dt)


func handle_elixir_confirm() -> bool:
	return _elixir_of_mastery_runtime.handle_confirm()
