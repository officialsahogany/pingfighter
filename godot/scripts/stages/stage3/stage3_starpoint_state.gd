extends RefCounted

const CommonStarpointVisualHost := preload("res://scripts/effects/common_starpoint_visual_host.gd")
const LingpetStarlightTrackingBridge := preload("res://scripts/stages/common/lingpet_starlight_tracking_bridge.gd")
const StarpointBonusDropPolicy := preload("res://scripts/stages/common/starpoint_bonus_drop_policy.gd")
const StarpointCollectionCompaction := preload("res://scripts/stages/common/starpoint_collection_compaction.gd")
const StarpointCollectionRewardPolicy := preload("res://scripts/stages/common/starpoint_collection_reward_policy.gd")
const StarpointDowsingAttraction := preload("res://scripts/stages/common/starpoint_dowsing_attraction.gd")
const StarpointDropMotionState := preload("res://scripts/stages/common/starpoint_drop_motion_state.gd")
const StarpointDropOverlapQuery := preload("res://scripts/stages/common/starpoint_drop_overlap_query.gd")
const StarpointParticleState := preload("res://scripts/stages/common/starpoint_particle_state.gd")
const StarpointPayloadFactory := preload("res://scripts/stages/common/starpoint_payload_factory.gd")
const StageActorDrawContextArrays := preload("res://scripts/stages/common/stage_actor_draw_context_arrays.gd")
const StagePlayerInteractionRects := preload("res://scripts/stages/common/stage_player_interaction_rects.gd")
const StagePlayfieldBounds := preload("res://scripts/stages/common/stage_playfield_bounds.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const STARPOINT_DROP_SIZE := 12.0
const STARPOINT_DROP_LIFETIME := 600.0
const STARPOINT_DROP_ACCELERATION := 0.25
const STARPOINT_DROP_MAX_FALL_SPEED := 12.0
const STARPOINT_DROP_BOUNCE_DAMPING := 0.7
const STARPOINT_PARTICLE_COUNT := 20
const STARPOINT_PARTICLE_LIFE := 60.0
const STAR_DETECTOR_BONUS_DROP_OFFSET_CHOICES := [-36.0, -24.0, 24.0, 36.0]
const MAX_STAGE3_STARPOINT_DROPS := 10
const MAX_STAGE3_STARPOINT_PARTICLES := 120

# Stage 3 Menhera-tail starpoint lifecycle owner. The shared stage RNG is
# borrowed and never consumed during construction; spawn calls retain their
# original position -> drop payload -> particles -> detector-bonus order.

var _rng: RandomNumberGenerator
var _drops: Array = []
var _particles: Array = []


func _init(rng: RandomNumberGenerator) -> void:
	_rng = rng


func clear() -> void:
	_drops.clear()
	_particles.clear()


func has_runtime_state() -> bool:
	return not _drops.is_empty() or not _particles.is_empty()


func hide_all_existing_visual_hosts() -> void:
	CommonStarpointVisualHost.hide_all_existing_hosts()


func spawn_tail_drop(ball_pos: Vector2, deps: Dictionary, context: Dictionary) -> void:
	var drop_pos := Vector2(
		clamp(
			ball_pos.x + float(_rng.randi_range(-30, 30)),
			StagePlayfieldBounds.get_left(context) + STARPOINT_DROP_SIZE,
			StagePlayfieldBounds.get_right(context, FIELD_WIDTH) - STARPOINT_DROP_SIZE
		),
		clamp(
			ball_pos.y + float(_rng.randi_range(-30, 30)),
			STARPOINT_DROP_SIZE,
			StagePlayfieldBounds.get_height(context, FIELD_HEIGHT) - STARPOINT_DROP_SIZE
		)
	)
	spawn_drop_at(drop_pos, deps, context, true, false, "menhera_tail")


func spawn_drop_at(
	pos: Vector2,
	deps: Dictionary = {},
	context: Dictionary = {},
	allow_star_detector_bonus: bool = true,
	star_detector_bonus: bool = false,
	source_type: String = "menhera_tail"
) -> void:
	_drops.append(StarpointPayloadFactory.build_drop(
		pos,
		_rng,
		star_detector_bonus,
		STARPOINT_DROP_SIZE,
		STARPOINT_DROP_LIFETIME,
		0.05,
		0.1,
		source_type
	))
	if _drops.size() > MAX_STAGE3_STARPOINT_DROPS:
		_trim_array_from_front(_drops, MAX_STAGE3_STARPOINT_DROPS)
	_spawn_particles(pos, STARPOINT_PARTICLE_COUNT + (6 if star_detector_bonus else 0), 1.2 if star_detector_bonus else 1.0)
	if allow_star_detector_bonus:
		_spawn_star_detector_bonus_drops(pos, deps, context)


func update(fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	_update_drops(fps_scale, context, deps)
	StarpointParticleState.update_particles(_particles, fps_scale)


func get_actor_draw_context(copy_arrays: bool = false) -> Dictionary:
	return {
		"stage3_starpoint_drops": StageActorDrawContextArrays.snapshot(_drops, copy_arrays, true),
		"stage3_starpoint_particles": StageActorDrawContextArrays.snapshot(_particles, copy_arrays, true),
	}


func get_snapshot() -> Dictionary:
	return get_actor_draw_context(true)


func get_drop_count() -> int:
	return _drops.size()


func get_particle_count() -> int:
	return _particles.size()


func _spawn_star_detector_bonus_drops(pos: Vector2, deps: Dictionary, context: Dictionary) -> void:
	var bonus_count: int = StarpointBonusDropPolicy.roll_star_detector_bonus_drop_count(deps, context)
	for _idx in range(bonus_count):
		var bonus_pos := Vector2(
			clamp(
				pos.x + float(STAR_DETECTOR_BONUS_DROP_OFFSET_CHOICES[_rng.randi_range(0, STAR_DETECTOR_BONUS_DROP_OFFSET_CHOICES.size() - 1)]),
				StagePlayfieldBounds.get_left(context) + STARPOINT_DROP_SIZE,
				StagePlayfieldBounds.get_right(context, FIELD_WIDTH) - STARPOINT_DROP_SIZE
			),
			clamp(
				pos.y + float(STAR_DETECTOR_BONUS_DROP_OFFSET_CHOICES[_rng.randi_range(0, STAR_DETECTOR_BONUS_DROP_OFFSET_CHOICES.size() - 1)]),
				STARPOINT_DROP_SIZE,
				StagePlayfieldBounds.get_height(context, FIELD_HEIGHT) - STARPOINT_DROP_SIZE
			)
		)
		spawn_drop_at(bonus_pos, deps, context, false, true, "menhera_tail")


func _update_drops(fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	if _drops.is_empty():
		return
	var player_rect := Rect2(
		_as_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO),
		_as_vector2(context.get("player_paddle_size", Vector2(155.0, 50.0)), Vector2(155.0, 50.0))
	)
	var player_rects: Array[Rect2] = StagePlayerInteractionRects.get_player_interaction_rects(player_rect, deps)
	var play_left: float = StagePlayfieldBounds.get_left(context)
	var play_right: float = StagePlayfieldBounds.get_right(context, FIELD_WIDTH)
	var play_height: float = StagePlayfieldBounds.get_height(context, FIELD_HEIGHT)
	var dowsing_context: Dictionary = StarpointDowsingAttraction.resolve_context(context, deps)
	var dowsing_player_center: Vector2 = StarpointDowsingAttraction.resolve_player_center(context)
	var drop_count := _drops.size()
	var next_drops: Array = []
	for index in range(drop_count):
		var drop_value: Variant = _drops[index]
		var drop: Dictionary = drop_value if drop_value is Dictionary else {}
		StarpointDowsingAttraction.apply_to_drop(drop, dowsing_context, dowsing_player_center, fps_scale)
		if not StarpointDropMotionState.update_drop(
			drop,
			fps_scale,
			play_left,
			play_right,
			play_height,
			STARPOINT_DROP_SIZE,
			STARPOINT_DROP_MAX_FALL_SPEED,
			STARPOINT_DROP_ACCELERATION,
			STARPOINT_DROP_BOUNCE_DAMPING
		):
			continue

		var starlight_tracking_result := LingpetStarlightTrackingBridge.update_drop(drop, fps_scale, context, deps)
		if bool(starlight_tracking_result.get("delivered", false)):
			if _collect_drop(drop, context, deps):
				_drops = StarpointCollectionCompaction.build_preserved_after_modal(_drops, next_drops, index, drop_count)
				return
			if _drops.size() < drop_count:
				return
			continue
		if bool(starlight_tracking_result.get("claimed", false)):
			next_drops.append(drop)
			continue

		if StarpointDropOverlapQuery.overlaps_any_circle_player(drop, player_rects, STARPOINT_DROP_SIZE):
			if _collect_drop(drop, context, deps):
				_drops = StarpointCollectionCompaction.build_preserved_after_modal(_drops, next_drops, index, drop_count)
				return
			if _drops.size() < drop_count:
				return
			continue
		next_drops.append(drop)
	_drops = next_drops


func _collect_drop(drop: Dictionary, context: Dictionary, deps: Dictionary) -> bool:
	var opened_choice: bool = StarpointCollectionRewardPolicy.collect_starpoint_reward(context, deps)
	var pos: Vector2 = _as_vector2(drop.get("pos", Vector2.ZERO), Vector2.ZERO)
	_spawn_particles(pos, STARPOINT_PARTICLE_COUNT + 10, 1.4)
	_play_collect_sound(deps)
	StarpointCollectionRewardPolicy.request_owner_redraw(context)
	return opened_choice


func _spawn_particles(pos: Vector2, count: int, intensity: float) -> void:
	_particles.append_array(StarpointPayloadFactory.build_particles(
		pos,
		count,
		intensity,
		_rng,
		STARPOINT_PARTICLE_LIFE
	))
	if _particles.size() > MAX_STAGE3_STARPOINT_PARTICLES:
		_trim_array_from_front(_particles, MAX_STAGE3_STARPOINT_PARTICLES)


func _play_collect_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_starpoint_collect"):
		audio.play_starpoint_collect()


func _trim_array_from_front(source: Array, max_size: int) -> void:
	var overflow: int = source.size() - max_size
	if overflow <= 0:
		return
	var write_idx: int = 0
	for read_idx in range(overflow, source.size()):
		source[write_idx] = source[read_idx]
		write_idx += 1
	source.resize(write_idx)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
