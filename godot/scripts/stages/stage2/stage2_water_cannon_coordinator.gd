extends RefCounted

const Stage2AudioRouter := preload("res://scripts/stages/stage2/stage2_audio_router.gd")
const Stage2WaterCannonGeometry := preload("res://scripts/stages/stage2/stage2_water_cannon_geometry.gd")
const Stage2WaterCannonImpactCoordinator := preload("res://scripts/stages/stage2/stage2_water_cannon_impact_coordinator.gd")
const Stage2WaterFragmentHitResolver := preload("res://scripts/stages/stage2/stage2_water_fragment_hit_resolver.gd")
const Stage2WaterFragmentPlayerHitApplier := preload("res://scripts/stages/stage2/stage2_water_fragment_player_hit_applier.gd")
const Stage2WaterTrailPayloadFactory := preload("res://scripts/stages/stage2/stage2_water_trail_payload_factory.gd")

const CHARGE_SEC := 0.80
const FIRE_SEC := 0.50
const TRAIL_LIFE_SEC := 0.38
const TRAIL_MAX_COUNT := 32
const DEFAULT_PLAYER_PADDLE_SIZE := Vector2(155.0, 50.0)
const FRAGMENT_HIT_FLASH_SEC := Stage2WaterFragmentPlayerHitApplier.HIT_FLASH_SEC
const CHARGE_WARNING_EXTRA_SEC := 0.22
const FIRE_WARNING_SEC := 0.78
const CANCEL_WARNING_SEC := 0.62

# The shared Stage 2 RNG is borrowed. Configuration must not consume it.
var rock_state: Object = null
var rock_query: Object = null
var water_cannon_state: Object = null
var water_visual_state: Object = null
var random_source: RandomNumberGenerator = null
var skill_warning_state: Object = null
var collision_geometry: Object = null
var fragment_hit_flash_state: Object = null
var rock_feedback_coordinator: Object = null
var ambient_state: Object = null
var rock_fragment_state: Object = null
var geometry: Object = Stage2WaterCannonGeometry.new()
var impact_coordinator: Object = Stage2WaterCannonImpactCoordinator.new()
var trail_payload_factory: Object = Stage2WaterTrailPayloadFactory.new()
var player_hit_applier: Object = Stage2WaterFragmentPlayerHitApplier.new()


func configure(
	rock_state_ref: Object,
	rock_query_ref: Object,
	water_cannon_state_ref: Object,
	water_visual_state_ref: Object,
	random_source_ref: RandomNumberGenerator,
	skill_warning_state_ref: Object,
	collision_geometry_ref: Object,
	fragment_hit_flash_state_ref: Object,
	rock_feedback_coordinator_ref: Object,
	ambient_state_ref: Object,
	rock_fragment_state_ref: Object
) -> void:
	rock_state = rock_state_ref
	rock_query = rock_query_ref
	water_cannon_state = water_cannon_state_ref
	water_visual_state = water_visual_state_ref
	random_source = random_source_ref
	skill_warning_state = skill_warning_state_ref
	collision_geometry = collision_geometry_ref
	fragment_hit_flash_state = fragment_hit_flash_state_ref
	rock_feedback_coordinator = rock_feedback_coordinator_ref
	ambient_state = ambient_state_ref
	rock_fragment_state = rock_fragment_state_ref


func activate(context: Dictionary = {}) -> bool:
	if rock_state == null or rock_query == null or water_cannon_state == null or random_source == null:
		return false
	var rocks: Array = rock_state.rocks as Array
	if str(water_cannon_state.phase) != "idle" or rocks.is_empty():
		return false
	var resolved_target_id: int = rock_query.select_random_id(rocks, random_source)
	if resolved_target_id < 0:
		return false
	var target_rock: Dictionary = rock_query.get_by_id(rocks, resolved_target_id)
	if target_rock.is_empty():
		return false
	if not water_cannon_state.activate(
		resolved_target_id,
		geometry.get_boss_cannon_start_from_context(context),
		rock_query.get_center(target_rock),
		CHARGE_SEC
	):
		return false
	rock_state.mark_water_target_by_id(int(water_cannon_state.target_id))
	_trigger_warning("water_charge", "용소격류 조준!", CHARGE_SEC + CHARGE_WARNING_EXTRA_SEC)
	return true


func update(delta: float, context: Dictionary, deps: Dictionary) -> Dictionary:
	var events := _empty_events()
	if rock_state == null or rock_query == null or water_cannon_state == null:
		return events
	var rocks: Array = rock_state.rocks as Array
	if str(water_cannon_state.phase) == "idle":
		if deps.get("stage2_boss_skill_state", null) != null:
			return events
		if float(water_cannon_state.delay) <= 0.0:
			return events
		if int(context.get("current_stage", 1)) != 2 or not bool(context.get("ball_active", false)) or rocks.is_empty():
			return events
		if water_cannon_state.advance_idle_delay(delta):
			activate(context)
		return events

	var target_index: int = rock_query.get_index_by_id(rocks, int(water_cannon_state.target_id))
	if target_index < 0:
		cancel()
		return events

	var target_rock: Dictionary = rocks[target_index]
	water_cannon_state.set_geometry(
		geometry.get_boss_cannon_start_from_context(context),
		rock_query.get_center(target_rock)
	)
	events = water_cannon_state.advance_active(delta, FIRE_SEC)
	rock_state.mark_water_target_by_id(int(water_cannon_state.target_id))
	if bool(events.get("started_firing", false)):
		_trigger_warning("water_fire", "용소격류 발사!", FIRE_WARNING_SEC)
		Stage2AudioRouter.play_hydro(deps)
		return events
	if bool(events.get("emit_trail", false)):
		_append_trail(water_cannon_state.current as Vector2, float(water_cannon_state.progress))
	return events


func advance_visuals(delta: float) -> void:
	if water_visual_state != null:
		water_visual_state.advance(delta)


func resolve_fragment_player_hits(context: Dictionary, deps: Dictionary) -> void:
	if water_visual_state == null or collision_geometry == null:
		return
	var water_splashes: Array = water_visual_state.splashes as Array
	if int(context.get("current_stage", 1)) != 2 or water_splashes.is_empty():
		return
	var player_rects: Array[Rect2] = collision_geometry.get_player_interaction_rects_from_context(
		context,
		deps,
		DEFAULT_PLAYER_PADDLE_SIZE
	)
	if player_rects.is_empty():
		return
	var hits: Array = Stage2WaterFragmentHitResolver.resolve_hits(
		water_splashes,
		player_rects,
		collision_geometry
	)
	for hit_value in hits:
		var hit: Dictionary = hit_value
		player_hit_applier.apply(
			int(hit.get("index", -1)),
			hit.get("splash", {}),
			_get_vector2(hit.get("pos", Vector2.ZERO), Vector2.ZERO),
			hit.get("hit_rect", Rect2()),
			water_splashes,
			fragment_hit_flash_state,
			deps,
			context
		)


func finish_impact(deps: Dictionary, golden_reward_callback: Callable, debris_region_count: int) -> Dictionary:
	return impact_coordinator.finish_impact(
		rock_state,
		rock_query,
		water_cannon_state,
		water_visual_state,
		rock_feedback_coordinator,
		ambient_state,
		rock_fragment_state,
		random_source,
		skill_warning_state,
		deps,
		golden_reward_callback,
		debris_region_count
	)


func cancel() -> void:
	_clear_target_flash()
	if water_cannon_state != null:
		water_cannon_state.cancel()


func interrupt_charge_on_boss_hit() -> bool:
	if water_cannon_state == null or str(water_cannon_state.phase) != "charging":
		return false
	cancel()
	_trigger_warning("water_cancel", "용소격류 중단!", CANCEL_WARNING_SEC)
	return true


func _clear_target_flash() -> void:
	if rock_state == null or rock_query == null or water_cannon_state == null:
		return
	var target_id: int = int(water_cannon_state.target_id)
	if target_id < 0:
		return
	var target_index: int = rock_query.get_index_by_id(rock_state.rocks as Array, target_id)
	if target_index >= 0:
		rock_state.clear_water_target_flash_at(target_index)


func _append_trail(pos: Vector2, progress: float) -> void:
	if water_visual_state == null or random_source == null:
		return
	water_visual_state.append_trail(
		trail_payload_factory.build_trail(pos, progress, random_source, TRAIL_LIFE_SEC),
		TRAIL_MAX_COUNT
	)


func _trigger_warning(kind: String, text: String, duration: float) -> void:
	if skill_warning_state != null and skill_warning_state.has_method("trigger"):
		skill_warning_state.trigger(kind, text, duration)


func _empty_events() -> Dictionary:
	return {
		"started_firing": false,
		"emit_trail": false,
		"finished": false,
	}


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
