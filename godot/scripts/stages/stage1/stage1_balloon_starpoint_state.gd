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

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const DROP_SIZE := 12.0
const DROP_LIFETIME := 600.0
const DROP_ACCELERATION := 0.25
const DROP_MAX_FALL_SPEED := 12.0
const DROP_BOUNCE_DAMPING := 0.7
const BONUS_DROP_OFFSET_CHOICES := [-36.0, -24.0, 24.0, 36.0]
const PARTICLE_COUNT := 10
const PARTICLE_LIFE := 60.0
const DEFAULT_PLAYER_PADDLE_SIZE := Vector2(155.0, 50.0)

# Retains the Stage 1 balloon-event starpoint collections and owns their full
# spawn -> motion -> attraction/tracking -> collection -> particle lifecycle.
# It intentionally uses the global RNG because the legacy facade did; creation
# and bounds configuration consume no random values.
var drops: Array = []
var particles: Array = []
var play_left := 0.0
var play_right := FIELD_WIDTH
var play_height := FIELD_HEIGHT


func configure_bounds(left: float, right: float, height: float) -> void:
	play_left = left
	play_right = right
	play_height = height


func clear() -> bool:
	var had_runtime_state := has_runtime_state()
	drops.clear()
	particles.clear()
	return had_runtime_state


func has_runtime_state() -> bool:
	return not drops.is_empty() or not particles.is_empty()


func spawn_drop_at(
	pos: Vector2,
	deps: Dictionary = {},
	context: Dictionary = {},
	allow_star_detector_bonus: bool = true,
	star_detector_bonus: bool = false
) -> void:
	# Stage 1 keeps the iridescent pink star on a slower "drifting jewel" tumble.
	drops.append(StarpointPayloadFactory.build_drop(
		pos,
		null,
		star_detector_bonus,
		DROP_SIZE,
		DROP_LIFETIME,
		0.02,
		0.045
	))
	spawn_particles(pos, PARTICLE_COUNT + (6 if star_detector_bonus else 0), 1.2 if star_detector_bonus else 1.0)
	if allow_star_detector_bonus:
		spawn_star_detector_bonus_drops(pos, deps, context)


func spawn_star_detector_bonus_drops(pos: Vector2, deps: Dictionary, context: Dictionary) -> void:
	var bonus_count: int = StarpointBonusDropPolicy.roll_star_detector_bonus_drop_count(deps, context)
	for _index in range(bonus_count):
		var bonus_pos := Vector2(
			clamp(
				pos.x + float(BONUS_DROP_OFFSET_CHOICES[randi() % BONUS_DROP_OFFSET_CHOICES.size()]),
				play_left + DROP_SIZE,
				play_right - DROP_SIZE
			),
			clamp(
				pos.y + float(BONUS_DROP_OFFSET_CHOICES[randi() % BONUS_DROP_OFFSET_CHOICES.size()]),
				DROP_SIZE,
				play_height - DROP_SIZE
			)
		)
		spawn_drop_at(bonus_pos, deps, context, false, true)


func update_drops(fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	if drops.is_empty():
		return

	var player_rect := Rect2(
		_get_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO),
		_get_vector2(context.get("player_paddle_size", DEFAULT_PLAYER_PADDLE_SIZE), DEFAULT_PLAYER_PADDLE_SIZE)
	)
	var player_rects: Array[Rect2] = StagePlayerInteractionRects.get_player_interaction_rects(player_rect, deps)
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

		if StarpointDropOverlapQuery.overlaps_any_rect_player(drop, player_rects, DROP_SIZE):
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
	var opened_choice: bool = StarpointCollectionRewardPolicy.collect_starpoint_reward(context, deps, false)
	var pos: Vector2 = _get_vector2(drop.get("pos", Vector2.ZERO), Vector2.ZERO)
	spawn_particles(pos, PARTICLE_COUNT + 10, 1.4)
	_play_collect_sound(deps)
	StarpointCollectionRewardPolicy.request_owner_redraw(context)
	return opened_choice


func spawn_particles(pos: Vector2, count: int, intensity: float) -> void:
	particles.append_array(StarpointPayloadFactory.build_particles(
		pos,
		count,
		intensity,
		null,
		PARTICLE_LIFE
	))


func update_particles(fps_scale: float) -> void:
	StarpointParticleState.update_particles(particles, fps_scale)


func _play_collect_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_starpoint_collect"):
		audio.play_starpoint_collect()


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
