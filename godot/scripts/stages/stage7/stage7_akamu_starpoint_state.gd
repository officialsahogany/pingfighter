extends RefCounted

const CommonStarpointVisualHost := preload("res://scripts/effects/common_starpoint_visual_host.gd")
const LingpetStarlightTrackingBridge := preload("res://scripts/stages/common/lingpet_starlight_tracking_bridge.gd")
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
const MAX_DROPS := 12
const MAX_PARTICLES := 96
const DEFAULT_PLAYER_PADDLE_SIZE := Vector2(155.0, 50.0)

var _rng: RandomNumberGenerator
var _drops: Array = []
var _particles: Array = []


func _init(source_rng: RandomNumberGenerator) -> void:
	_rng = source_rng


func clear() -> void:
	_drops.clear()
	_particles.clear()
	CommonStarpointVisualHost.hide_all_existing_hosts()


func has_runtime_state() -> bool:
	return not _drops.is_empty() or not _particles.is_empty()


func has_drops() -> bool:
	return not _drops.is_empty()


func spawn(pos: Vector2) -> void:
	_drops.append(StarpointPayloadFactory.build_drop(
		pos,
		_rng,
		false,
		DROP_SIZE,
		DROP_LIFETIME,
		0.05,
		0.1,
		"stage7_akamu_golden_clone"
	))
	_trim_array_from_front(_drops, MAX_DROPS)
	_spawn_particles(pos, PARTICLE_COUNT, 1.0)


func update(fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	_update_drops(maxf(0.0, fps_scale), context, deps)
	StarpointParticleState.update_particles(_particles, maxf(0.0, fps_scale))


func get_draw_list() -> Array:
	# Borrowed synchronously by the playfield renderer; state remains the sole
	# mutation owner and avoids a deep-copy allocation in every draw frame.
	return _drops


func get_particle_draw_list() -> Array:
	return _particles


func get_snapshot() -> Dictionary:
	return {
		"drop_count": _drops.size(),
		"particle_count": _particles.size(),
		"drops": _drops.duplicate(true),
		"particles": _particles.duplicate(true),
	}


func debug_patch_drop(index: int, values: Dictionary) -> bool:
	if index < 0 or index >= _drops.size():
		return false
	var drop: Dictionary = _drops[index]
	for key_value in values:
		drop[key_value] = values[key_value]
	_drops[index] = drop
	return true


func _update_drops(fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	if _drops.is_empty():
		return
	var player_rects: Array[Rect2] = StagePlayerInteractionRects.get_player_interaction_rects_from_context(
		context,
		deps,
		DEFAULT_PLAYER_PADDLE_SIZE
	)
	var play_left: float = StagePlayfieldBounds.get_left(context)
	var play_right: float = StagePlayfieldBounds.get_right(context, FIELD_WIDTH)
	var play_height: float = StagePlayfieldBounds.get_height(context, FIELD_HEIGHT)
	var dowsing_context: Dictionary = StarpointDowsingAttraction.resolve_context(context, deps)
	var dowsing_player_center: Vector2 = StarpointDowsingAttraction.resolve_player_center(context)
	var write_index := 0
	var drop_count := _drops.size()
	for index in range(drop_count):
		var drop_value: Variant = _drops[index]
		var drop: Dictionary = drop_value if drop_value is Dictionary else {}
		StarpointDowsingAttraction.apply_to_drop(
			drop,
			dowsing_context,
			dowsing_player_center,
			fps_scale
		)
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

		var tracking_result: Dictionary = LingpetStarlightTrackingBridge.update_drop(
			drop,
			fps_scale,
			context,
			deps
		)
		if bool(tracking_result.get("delivered", false)):
			var delivery_result := _try_collect_drop(drop, context, deps)
			if bool(delivery_result.get("accepted", false)):
				if bool(delivery_result.get("choice_opened", false)):
					StarpointCollectionCompaction.finish_in_place(
						_drops,
						index,
						write_index,
						drop_count
					)
					return
				continue
			# Missing reward dependencies are intentionally fail-loud: the delivered
			# drop remains visible instead of silently disappearing without payment.
			_drops[write_index] = drop
			write_index += 1
			continue
		if bool(tracking_result.get("claimed", false)):
			_drops[write_index] = drop
			write_index += 1
			continue

		if StarpointDropOverlapQuery.overlaps_any_circle_player(drop, player_rects, DROP_SIZE):
			var collection_result := _try_collect_drop(drop, context, deps)
			if bool(collection_result.get("accepted", false)):
				if bool(collection_result.get("choice_opened", false)):
					StarpointCollectionCompaction.finish_in_place(
						_drops,
						index,
						write_index,
						drop_count
					)
					return
				continue
		_drops[write_index] = drop
		write_index += 1
	if write_index < drop_count:
		_drops.resize(write_index)


func _try_collect_drop(drop: Dictionary, context: Dictionary, deps: Dictionary) -> Dictionary:
	var runtime_perk_state: Object = deps.get("runtime_perk_state", null)
	if runtime_perk_state == null or not runtime_perk_state.has_method("collect_star_points"):
		return {"accepted": false, "choice_opened": false}
	var choice_opened: bool = StarpointCollectionRewardPolicy.collect_starpoint_reward(context, deps)
	var pos: Vector2 = _as_vector2(drop.get("pos", Vector2.ZERO), Vector2.ZERO)
	_spawn_particles(pos, PARTICLE_COUNT + 10, 1.4)
	_play_collect_sound(deps)
	_request_owner_redraw(context)
	return {"accepted": true, "choice_opened": choice_opened}


func _spawn_particles(pos: Vector2, count: int, intensity: float) -> void:
	_particles.append_array(StarpointPayloadFactory.build_particles(
		pos,
		count,
		intensity,
		_rng,
		PARTICLE_LIFE
	))
	_trim_array_from_front(_particles, MAX_PARTICLES)


func _play_collect_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_starpoint_collect"):
		audio.play_starpoint_collect()


func _request_owner_redraw(context: Dictionary) -> void:
	var owner: Object = context.get("owner", null)
	if owner != null and owner.has_method("request_battle_redraw"):
		owner.request_battle_redraw()


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
