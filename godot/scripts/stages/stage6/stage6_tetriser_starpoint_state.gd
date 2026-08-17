extends RefCounted

# Stage 6 Tetriser starpoint-drop lifecycle.
#
# The owner keeps the shared stage RNG, golden-block one-shot gate, drop motion,
# dowsing attraction, player collection, stage-leave cleanup, and copied draw
# snapshots together. Callers still decide which combat events spawn a drop.

const TetriserTetrominoState := preload("res://scripts/stages/stage6/stage6_tetriser_tetromino_state.gd")
const StarpointPayloadFactory := preload("res://scripts/stages/common/starpoint_payload_factory.gd")
const StarpointDropMotionState := preload("res://scripts/stages/common/starpoint_drop_motion_state.gd")
const StarpointDropOverlapQuery := preload("res://scripts/stages/common/starpoint_drop_overlap_query.gd")
const StarpointCollectionRewardPolicy := preload("res://scripts/stages/common/starpoint_collection_reward_policy.gd")
const StarpointDowsingAttraction := preload("res://scripts/stages/common/starpoint_dowsing_attraction.gd")

const STAGE_ID := 6
const DROP_SIZE := 12.0
const DROP_LIFETIME := 600.0
const DROP_ACCELERATION := 0.25
const DROP_MAX_FALL_SPEED := 12.0
const DROP_BOUNCE_DAMPING := 0.7
const FIELD_WIDTH := TetriserTetrominoState.FIELD_WIDTH
const FIELD_HEIGHT := TetriserTetrominoState.FIELD_HEIGHT
const DEFAULT_CELL_SIZE := TetriserTetrominoState.CELL_SIZE
const FALLBACK_POSITION := Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT * 0.5)

var _rng: RandomNumberGenerator
var _drops: Array[Dictionary] = []


func _init(random_source: RandomNumberGenerator) -> void:
	_rng = random_source


func clear() -> void:
	_drops.clear()


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
		"stage6_tetriser"
	))


func maybe_spawn_for_block(block: Dictionary) -> bool:
	if not bool(block.get("golden", false)):
		return false
	if bool(block.get("star_dropped", false)):
		return false
	block["star_dropped"] = true
	var cells: Array = block.get("cells", [])
	var cell_size: float = float(block.get("cell_size", DEFAULT_CELL_SIZE))
	if cells.is_empty():
		spawn(block.get("origin", FALLBACK_POSITION))
		return true
	spawn(_block_cells_center(block.get("origin", Vector2.ZERO), cells, cell_size))
	return true


func update(fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	if int(context.get("current_stage", STAGE_ID)) != STAGE_ID:
		clear()
		return
	if _drops.is_empty():
		return

	var player_rects: Array[Rect2] = _get_player_interaction_rects(context)
	var dowsing_context: Dictionary = StarpointDowsingAttraction.resolve_context(context, deps)
	var dowsing_player_center: Vector2 = StarpointDowsingAttraction.resolve_player_center(context)
	var write_index := 0
	var drop_count := _drops.size()
	for index in range(drop_count):
		var drop: Dictionary = _drops[index]
		StarpointDowsingAttraction.apply_to_drop(drop, dowsing_context, dowsing_player_center, fps_scale)
		if not StarpointDropMotionState.update_drop(
			drop,
			fps_scale,
			0.0,
			FIELD_WIDTH,
			FIELD_HEIGHT,
			DROP_SIZE,
			DROP_MAX_FALL_SPEED,
			DROP_ACCELERATION,
			DROP_BOUNCE_DAMPING
		):
			continue
		if StarpointDropOverlapQuery.overlaps_any_circle_player(drop, player_rects, DROP_SIZE):
			if _collect_drop(context, deps):
				continue
		_drops[write_index] = drop
		write_index += 1
	if write_index < drop_count:
		_drops.resize(write_index)


func get_draw_list() -> Array:
	return _drops.duplicate(true)


func get_count() -> int:
	return _drops.size()


func get_snapshot() -> Array:
	return _drops.duplicate(true)


func _collect_drop(context: Dictionary, deps: Dictionary) -> bool:
	var collected: bool = StarpointCollectionRewardPolicy.collect_starpoint_reward(context, deps)
	if not collected:
		# Without the real runtime perk deps the policy intentionally no-ops; keep
		# the drop alive so wiring smokes catch a missing live dependency path.
		return false
	StarpointCollectionRewardPolicy.request_owner_redraw(context)
	return true


func _get_player_interaction_rects(context: Dictionary) -> Array[Rect2]:
	var player_pos: Vector2 = context.get("player_pos", Vector2(302.5, 690.0))
	var player_size: Vector2 = context.get("player_paddle_size", Vector2(155.0, 50.0))
	return [Rect2(player_pos, player_size)]


func _block_cells_center(origin: Vector2, cells: Array, cell_size: float) -> Vector2:
	var center := Vector2.ZERO
	for cell in cells:
		center += origin + cell * cell_size + Vector2(cell_size * 0.5, cell_size * 0.5)
	return center / maxf(1.0, float(cells.size()))
