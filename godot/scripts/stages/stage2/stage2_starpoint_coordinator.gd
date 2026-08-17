extends RefCounted

const LingpetStarlightTrackingBridge := preload("res://scripts/stages/common/lingpet_starlight_tracking_bridge.gd")
const Stage2AudioRouter := preload("res://scripts/stages/stage2/stage2_audio_router.gd")
const StarpointBonusDropPolicy := preload("res://scripts/stages/common/starpoint_bonus_drop_policy.gd")
const StarpointCollectionCompaction := preload("res://scripts/stages/common/starpoint_collection_compaction.gd")
const StarpointCollectionRewardPolicy := preload("res://scripts/stages/common/starpoint_collection_reward_policy.gd")
const StarpointDowsingAttraction := preload("res://scripts/stages/common/starpoint_dowsing_attraction.gd")
const StarpointDropMotionState := preload("res://scripts/stages/common/starpoint_drop_motion_state.gd")
const StarpointDropOverlapQuery := preload("res://scripts/stages/common/starpoint_drop_overlap_query.gd")
const StarpointParticleState := preload("res://scripts/stages/common/starpoint_particle_state.gd")
const StarpointPayloadFactory := preload("res://scripts/stages/common/starpoint_payload_factory.gd")

const DROP_SIZE := 12.0
const DROP_LIFETIME := 600.0
const DROP_ACCELERATION := 0.25
const DROP_MAX_FALL_SPEED := 12.0
const DROP_BOUNCE_DAMPING := 0.7
const BONUS_DROP_OFFSET_CHOICES := [-36.0, -24.0, 24.0, 36.0]
const PARTICLE_COUNT := 20
const PARTICLE_LIFE := 60.0
const DEFAULT_PLAYER_PADDLE_SIZE := Vector2(155.0, 50.0)

# The shared Stage 2 RNG is borrowed. Construction/configuration must never
# consume it; spawn calls preserve primary drop -> particles -> bonus order.
var starpoint_state: Object = null
var random_source: RandomNumberGenerator = null
var collision_geometry: Object = null
var playfield_bounds: Object = null
var obstacle_visual_renderer: Object = null


func configure(
	starpoint_state_ref: Object,
	random_source_ref: RandomNumberGenerator,
	collision_geometry_ref: Object,
	playfield_bounds_ref: Object,
	obstacle_visual_renderer_ref: Object
) -> void:
	starpoint_state = starpoint_state_ref
	random_source = random_source_ref
	collision_geometry = collision_geometry_ref
	playfield_bounds = playfield_bounds_ref
	obstacle_visual_renderer = obstacle_visual_renderer_ref


func spawn_drop_at(
	pos: Vector2,
	deps: Dictionary = {},
	context: Dictionary = {},
	allow_star_detector_bonus: bool = true,
	star_detector_bonus: bool = false
) -> void:
	if starpoint_state == null or random_source == null:
		return
	starpoint_state.append_drop(StarpointPayloadFactory.build_drop(
		pos,
		random_source,
		star_detector_bonus,
		DROP_SIZE,
		DROP_LIFETIME
	))
	spawn_particles(pos, PARTICLE_COUNT + (6 if star_detector_bonus else 0), 1.2 if star_detector_bonus else 1.0)
	if allow_star_detector_bonus:
		spawn_star_detector_bonus_drops(pos, deps, context)


func spawn_star_detector_bonus_drops(pos: Vector2, deps: Dictionary, context: Dictionary) -> void:
	if random_source == null or playfield_bounds == null:
		return
	var bonus_count: int = StarpointBonusDropPolicy.roll_star_detector_bonus_drop_count(deps, context)
	for _index in range(bonus_count):
		var bonus_pos := Vector2(
			clamp(
				pos.x + float(BONUS_DROP_OFFSET_CHOICES[random_source.randi() % BONUS_DROP_OFFSET_CHOICES.size()]),
				playfield_bounds.get_left(context) + DROP_SIZE,
				playfield_bounds.get_right(context) - DROP_SIZE
			),
			clamp(
				pos.y + float(BONUS_DROP_OFFSET_CHOICES[random_source.randi() % BONUS_DROP_OFFSET_CHOICES.size()]),
				DROP_SIZE,
				playfield_bounds.get_height(context) - DROP_SIZE
			)
		)
		spawn_drop_at(bonus_pos, deps, context, false, true)


func update_drops(fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	if starpoint_state == null:
		return
	if int(context.get("current_stage", 1)) != 2:
		var had_starpoints: bool = starpoint_state.clear()
		if had_starpoints and obstacle_visual_renderer != null:
			obstacle_visual_renderer.hide_all_starpoint_drops()
		return
	var drops: Array = starpoint_state.drops as Array
	if drops.is_empty():
		return
	var player_rects: Array[Rect2] = collision_geometry.get_player_interaction_rects_from_context(
		context,
		deps,
		DEFAULT_PLAYER_PADDLE_SIZE
	)
	var play_left: float = playfield_bounds.get_left(context)
	var play_right: float = playfield_bounds.get_right(context)
	var play_height: float = playfield_bounds.get_height(context)
	var dowsing_context: Dictionary = StarpointDowsingAttraction.resolve_context(context, deps)
	var dowsing_player_center: Vector2 = StarpointDowsingAttraction.resolve_player_center(context)
	var write_index := 0
	var drop_count := drops.size()
	for index in range(drop_count):
		var drop: Dictionary = drops[index]
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
	var pos: Vector2 = _get_vector2(drop.get("pos", Vector2.ZERO), Vector2.ZERO)
	spawn_particles(pos, PARTICLE_COUNT + 10, 1.4)
	Stage2AudioRouter.play_starpoint_collect(deps)
	StarpointCollectionRewardPolicy.request_owner_redraw(context)
	return opened_choice


func spawn_particles(pos: Vector2, count: int, intensity: float) -> void:
	if starpoint_state == null or random_source == null:
		return
	starpoint_state.append_particles(StarpointPayloadFactory.build_particles(
		pos,
		count,
		intensity,
		random_source,
		PARTICLE_LIFE
	))


func update_particles(fps_scale: float) -> void:
	if starpoint_state != null:
		StarpointParticleState.update_particles(starpoint_state.particles as Array, fps_scale)


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
