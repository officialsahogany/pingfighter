extends RefCounted

const Stage2AudioRouter := preload("res://scripts/stages/stage2/stage2_audio_router.gd")
const Stage2CrisisRockWallPayloadFactory := preload("res://scripts/stages/stage2/stage2_crisis_rock_wall_payload_factory.gd")
const Stage2QuakeRockDropState := preload("res://scripts/stages/stage2/stage2_quake_rock_drop_state.gd")
const Stage2QuakeRockPayloadFactory := preload("res://scripts/stages/stage2/stage2_quake_rock_payload_factory.gd")
const Stage2QuakeRockSpawnFactory := preload("res://scripts/stages/stage2/stage2_quake_rock_spawn_factory.gd")

const MAX_ROCKS := 8
const ROCK_LIFE_SEC := -1.0
const QUAKE_ROCK_DROP_HEIGHT := 185.0
const QUAKE_ROCK_DROP_TIME_SEC := 0.42
const QUAKE_ROCK_DROP_STAGGER_SEC := 0.07
const QUAKE_ROCK_LAND_FLASH_SEC := 0.34
const QUAKE_ROCK_SIZE_SCALE := 0.50
const CRISIS_ROCK_WALL_Y_MIN := 12.0
const CRISIS_ROCK_WALL_Y_MID := 29.0
const CRISIS_ROCK_WALL_Y_MAX := 46.0
const CRISIS_WALL_CENTER_X := 380.0
const QUAKE_SPAWN_LEAF_STRENGTH := 0.28
const CRISIS_SPAWN_LEAF_STRENGTH := 0.90
const EXPIRE_LEAF_STRENGTH := 0.70
const LAND_LEAF_STRENGTH := 0.72

var rock_state: Object = null
var rock_query: Object = null
var ambient_state: Object = null
var water_visual_state: Object = null
var water_cannon_state: Object = null
var random_source: RandomNumberGenerator = null
var rock_visual_factory: Object = null
var rock_feedback_coordinator: Object = null
var quake_rock_payload_factory: Object = Stage2QuakeRockPayloadFactory.new()
var quake_rock_spawn_factory: Object = Stage2QuakeRockSpawnFactory.new()
var crisis_rock_wall_payload_factory: Object = Stage2CrisisRockWallPayloadFactory.new()


func configure(
	rock_state_ref: Object,
	rock_query_ref: Object,
	ambient_state_ref: Object,
	water_visual_state_ref: Object,
	water_cannon_state_ref: Object,
	random_source_ref: RandomNumberGenerator,
	rock_visual_factory_ref: Object,
	rock_feedback_coordinator_ref: Object
) -> void:
	rock_state = rock_state_ref
	rock_query = rock_query_ref
	ambient_state = ambient_state_ref
	water_visual_state = water_visual_state_ref
	water_cannon_state = water_cannon_state_ref
	random_source = random_source_ref
	rock_visual_factory = rock_visual_factory_ref
	rock_feedback_coordinator = rock_feedback_coordinator_ref


func spawn_quake_rocks(requested_count: int, deps: Dictionary = {}) -> int:
	if rock_state == null or random_source == null:
		return 0
	var rocks: Array = rock_state.rocks as Array
	var batch: Dictionary = quake_rock_spawn_factory.build_spawn_batch(
		rocks,
		requested_count,
		MAX_ROCKS,
		int(rock_state.next_id),
		random_source,
		rock_visual_factory,
		quake_rock_payload_factory,
		QUAKE_ROCK_SIZE_SCALE,
		ROCK_LIFE_SEC
	)
	var spawned_rocks: Array = batch.get("rocks", [])
	var targets: Array = batch.get("targets", [])
	for index in range(spawned_rocks.size()):
		var rock: Dictionary = spawned_rocks[index]
		var target_value: Variant = targets[index] if index < targets.size() else rock.get("target_pos", Vector2.ZERO)
		_emit_leaves(_get_vector2(target_value, Vector2.ZERO), QUAKE_SPAWN_LEAF_STRENGTH)
	rock_state.append_rocks(spawned_rocks)
	rock_state.next_id = int(batch.get("next_id", int(rock_state.next_id) + spawned_rocks.size()))
	Stage2AudioRouter.play_rock_spawn(deps)
	return spawned_rocks.size()


func spawn_crisis_rock_wall(crisis_rock_count: int, deps: Dictionary = {}) -> int:
	if rock_state == null or random_source == null:
		return 0
	if water_visual_state != null and water_visual_state.has_method("reset"):
		water_visual_state.reset()
	if water_cannon_state != null:
		if water_cannon_state.has_method("cancel"):
			water_cannon_state.cancel()
		water_cannon_state.delay = -1.0
	var rocks: Array = rock_state.rocks as Array
	var spawn_count := maxi(0, crisis_rock_count)
	for index in range(spawn_count):
		var next_rock_id: int = rock_state.claim_next_id()
		var rock: Dictionary = crisis_rock_wall_payload_factory.build_crisis_rock(
			next_rock_id,
			index,
			spawn_count,
			random_source,
			rock_visual_factory,
			CRISIS_ROCK_WALL_Y_MIN,
			CRISIS_ROCK_WALL_Y_MID,
			CRISIS_ROCK_WALL_Y_MAX,
			QUAKE_ROCK_DROP_HEIGHT,
			QUAKE_ROCK_SIZE_SCALE,
			QUAKE_ROCK_DROP_STAGGER_SEC,
			QUAKE_ROCK_DROP_TIME_SEC,
			ROCK_LIFE_SEC,
			rocks
		)
		rock_state.append_rock(rock)
	_emit_leaves(
		Vector2(CRISIS_WALL_CENTER_X, (CRISIS_ROCK_WALL_Y_MIN + CRISIS_ROCK_WALL_Y_MAX) * 0.5),
		CRISIS_SPAWN_LEAF_STRENGTH
	)
	var skill_state: Object = deps.get("stage2_boss_skill_state", null)
	if skill_state != null and skill_state.has_method("defer_water_cannon_after_rock_spawn"):
		skill_state.defer_water_cannon_after_rock_spawn()
	Stage2AudioRouter.play_rock_spawn(deps)
	return spawn_count


func advance_lifetime(rock: Dictionary, delta: float) -> bool:
	var life: float = float(rock.get("life", ROCK_LIFE_SEC))
	if life < 0.0:
		return false
	life -= max(0.0, delta)
	if life <= 0.0:
		var center: Vector2 = rock_query.get_center(rock) if rock_query != null else _get_vector2(rock.get("pos", Vector2.ZERO), Vector2.ZERO)
		_emit_leaves(center, EXPIRE_LEAF_STRENGTH)
		return true
	rock["life"] = life
	return false


func update_quake_rock_drop(rock: Dictionary, delta: float) -> bool:
	if rock_query == null:
		return false
	var target_pos: Vector2 = rock_query.get_target_pos(rock)
	var result: Dictionary = Stage2QuakeRockDropState.update_drop(
		rock,
		delta,
		target_pos,
		QUAKE_ROCK_LAND_FLASH_SEC,
		QUAKE_ROCK_DROP_TIME_SEC
	)
	var landed: bool = bool(result.get("landed", false))
	if landed:
		var land_position: Vector2 = _get_vector2(result.get("land_position", target_pos), target_pos)
		_emit_leaves(land_position, LAND_LEAF_STRENGTH)
	return landed


func _emit_leaves(center: Vector2, strength: float) -> void:
	if rock_feedback_coordinator == null or ambient_state == null or random_source == null:
		return
	rock_feedback_coordinator.emit_leaf_burst(center, strength, ambient_state, random_source)


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
