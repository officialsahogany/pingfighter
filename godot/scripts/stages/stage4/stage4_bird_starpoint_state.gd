extends RefCounted

const LingpetStarlightTrackingBridge := preload("res://scripts/stages/common/lingpet_starlight_tracking_bridge.gd")
const StarpointBonusDropPolicy := preload("res://scripts/stages/common/starpoint_bonus_drop_policy.gd")
const StarpointCollectionCompaction := preload("res://scripts/stages/common/starpoint_collection_compaction.gd")
const StarpointCollectionRewardPolicy := preload("res://scripts/stages/common/starpoint_collection_reward_policy.gd")
const StarpointDowsingAttraction := preload("res://scripts/stages/common/starpoint_dowsing_attraction.gd")
const StarpointDropMotionState := preload("res://scripts/stages/common/starpoint_drop_motion_state.gd")
const StarpointDropOverlapQuery := preload("res://scripts/stages/common/starpoint_drop_overlap_query.gd")
const StarpointParticleState := preload("res://scripts/stages/common/starpoint_particle_state.gd")
const StarpointPayloadFactory := preload("res://scripts/stages/common/starpoint_payload_factory.gd")
const StagePlayerInteractionRects := preload("res://scripts/stages/common/stage_player_interaction_rects.gd")
const StagePlayfieldBounds := preload("res://scripts/stages/common/stage_playfield_bounds.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const DROP_SIZE := 12.0
const DROP_LIFETIME := 600.0
const DROP_ACCELERATION := 0.25
const DROP_MAX_FALL_SPEED := 12.0
const DROP_BOUNCE_DAMPING := 0.7
const PARTICLE_COUNT := 20
const PARTICLE_LIFE := 60.0
const BONUS_DROP_OFFSET_CHOICES := [-36.0, -24.0, 24.0, 36.0]
const MAX_DROPS := 12
const MAX_PARTICLES := 96
const DEFAULT_PLAYER_PADDLE_SIZE := Vector2(155.0, 50.0)

# Retains Stage 4 bird-event starpoint collections and owns their full
# spawn -> motion -> attraction/tracking -> collection -> particle lifecycle.
# The facade injects its existing RNG so extraction does not alter random-call
# order between bird payloads, starpoint payloads, and detector bonus offsets.
var drops: Array = []
var particles: Array = []
var rng: RandomNumberGenerator


func _init(source_rng: RandomNumberGenerator = null) -> void:
	if source_rng != null:
		rng = source_rng
	else:
		rng = RandomNumberGenerator.new()
		rng.randomize()


func clear() -> bool:
	var had_runtime_state := has_runtime_state()
	drops.clear()
	particles.clear()
	return had_runtime_state


func has_runtime_state() -> bool:
	return not drops.is_empty() or not particles.is_empty()


func spawn_crow_drop(pos: Vector2, deps: Dictionary, context: Dictionary) -> void:
	var drop_pos := Vector2(
		clamp(
			pos.x,
			StagePlayfieldBounds.get_left(context) + DROP_SIZE,
			StagePlayfieldBounds.get_right(context, FIELD_WIDTH) - DROP_SIZE
		),
		clamp(
			pos.y,
			DROP_SIZE,
			StagePlayfieldBounds.get_height(context, FIELD_HEIGHT) - DROP_SIZE
		)
	)
	spawn_drop_at(drop_pos, deps, context, true, false, "crow")


func spawn_drop_at(
	pos: Vector2,
	deps: Dictionary = {},
	context: Dictionary = {},
	allow_star_detector_bonus: bool = true,
	star_detector_bonus: bool = false,
	source_type: String = "crow"
) -> void:
	drops.append(StarpointPayloadFactory.build_drop(
		pos,
		rng,
		star_detector_bonus,
		DROP_SIZE,
		DROP_LIFETIME,
		0.05,
		0.1,
		source_type
	))
	_trim_array_from_front(drops, MAX_DROPS)
	spawn_particles(pos, PARTICLE_COUNT + (6 if star_detector_bonus else 0), 1.2 if star_detector_bonus else 1.0)
	if allow_star_detector_bonus:
		spawn_star_detector_bonus_drops(pos, deps, context)


func spawn_star_detector_bonus_drops(pos: Vector2, deps: Dictionary, context: Dictionary) -> void:
	var bonus_count: int = StarpointBonusDropPolicy.roll_star_detector_bonus_drop_count(deps, context)
	for _index in range(bonus_count):
		var bonus_pos := Vector2(
			clamp(
				pos.x + float(BONUS_DROP_OFFSET_CHOICES[rng.randi_range(0, BONUS_DROP_OFFSET_CHOICES.size() - 1)]),
				StagePlayfieldBounds.get_left(context) + DROP_SIZE,
				StagePlayfieldBounds.get_right(context, FIELD_WIDTH) - DROP_SIZE
			),
			clamp(
				pos.y + float(BONUS_DROP_OFFSET_CHOICES[rng.randi_range(0, BONUS_DROP_OFFSET_CHOICES.size() - 1)]),
				DROP_SIZE,
				StagePlayfieldBounds.get_height(context, FIELD_HEIGHT) - DROP_SIZE
			)
		)
		spawn_drop_at(bonus_pos, deps, context, false, true, "crow")


func update_drops(fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	if drops.is_empty():
		return
	var player_rect := Rect2(
		_as_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO),
		_as_vector2(context.get("player_paddle_size", DEFAULT_PLAYER_PADDLE_SIZE), DEFAULT_PLAYER_PADDLE_SIZE)
	)
	var player_rects: Array[Rect2] = StagePlayerInteractionRects.get_player_interaction_rects(player_rect, deps)
	var play_left: float = StagePlayfieldBounds.get_left(context)
	var play_right: float = StagePlayfieldBounds.get_right(context, FIELD_WIDTH)
	var play_height: float = StagePlayfieldBounds.get_height(context, FIELD_HEIGHT)
	var dowsing_context: Dictionary = StarpointDowsingAttraction.resolve_context(context, deps)
	var dowsing_player_center: Vector2 = StarpointDowsingAttraction.resolve_player_center(context)
	var write_index := 0
	var drop_count := drops.size()
	for index in range(drop_count):
		var drop_value: Variant = drops[index]
		var drop: Dictionary = drop_value if drop_value is Dictionary else {}
		StarpointDowsingAttraction.apply_to_drop(drop, dowsing_context, dowsing_player_center, fps_scale)
		if not StarpointDropMotionState.update_drop(
			drop,
			fps_scale,
			play_left,
			play_right,
			play_height,
			DROP_SIZE,
			DROP_MAX_FALL_SPEED,
			DROP_ACCELERATION,
			DROP_BOUNCE_DAMPING
		):
			continue

		var starlight_tracking_result := LingpetStarlightTrackingBridge.update_drop(drop, fps_scale, context, deps)
		if bool(starlight_tracking_result.get("delivered", false)):
			if collect_drop(drop, context, deps):
				StarpointCollectionCompaction.finish_in_place(drops, index, write_index, drop_count)
				return
			if drops.size() < drop_count:
				return
			continue
		if bool(starlight_tracking_result.get("claimed", false)):
			drops[write_index] = drop
			write_index += 1
			continue

		if StarpointDropOverlapQuery.overlaps_any_circle_player(drop, player_rects, DROP_SIZE):
			if collect_drop(drop, context, deps):
				StarpointCollectionCompaction.finish_in_place(drops, index, write_index, drop_count)
				return
			if drops.size() < drop_count:
				return
			continue
		drops[write_index] = drop
		write_index += 1
	if write_index < drop_count:
		drops.resize(write_index)


func collect_drop(drop: Dictionary, context: Dictionary, deps: Dictionary) -> bool:
	var opened_choice: bool = StarpointCollectionRewardPolicy.collect_starpoint_reward(context, deps)
	var pos: Vector2 = _as_vector2(drop.get("pos", Vector2.ZERO), Vector2.ZERO)
	spawn_particles(pos, PARTICLE_COUNT + 10, 1.4)
	_play_collect_sound(deps)
	StarpointCollectionRewardPolicy.request_owner_redraw(context)
	return opened_choice


func spawn_particles(pos: Vector2, count: int, intensity: float) -> void:
	particles.append_array(StarpointPayloadFactory.build_particles(
		pos,
		count,
		intensity,
		rng,
		PARTICLE_LIFE
	))
	_trim_array_from_front(particles, MAX_PARTICLES)


func update_particles(fps_scale: float) -> void:
	StarpointParticleState.update_particles(particles, fps_scale)


func _play_collect_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_starpoint_collect"):
		audio.play_starpoint_collect()


func _trim_array_from_front(source: Array, max_size: int) -> void:
	if max_size <= 0:
		source.clear()
		return
	var overflow := source.size() - max_size
	if overflow <= 0:
		return
	var write_index := 0
	for read_index in range(overflow, source.size()):
		source[write_index] = source[read_index]
		write_index += 1
	source.resize(write_index)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
