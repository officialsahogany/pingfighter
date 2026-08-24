extends RefCounted

const TetriserCombatFeedbackState := preload("res://scripts/stages/stage6/stage6_tetriser_combat_feedback_state.gd")
const TetriserCubeState := preload("res://scripts/stages/stage6/stage6_tetriser_cube_state.gd")
const TetriserGuardState := preload("res://scripts/stages/stage6/stage6_tetriser_guard_state.gd")
const TetriserSuperState := preload("res://scripts/stages/stage6/stage6_tetriser_super_state.gd")
const TetriserTetrominoState := preload("res://scripts/stages/stage6/stage6_tetriser_tetromino_state.gd")
const TetriserWallState := preload("res://scripts/stages/stage6/stage6_tetriser_wall_state.gd")

# Synchronous cross-owner reactions for Stage 6 block, cube, and laser events.
# The host still decides the per-frame call order; this owner preserves the
# exact side-effect order inside each event and never advances time on its own.

var _tetromino_state: Object
var _guard_state: Object
var _wall_state: Object
var _cube_state: Object
var _starpoint_state: Object
var _super_state: Object
var _combat_feedback: Object
var _player_explosion_applier: Object


func _init(
	tetromino_state: Object,
	guard_state: Object,
	wall_state: Object,
	cube_state: Object,
	starpoint_state: Object,
	super_state: Object,
	combat_feedback: Object,
	player_explosion_applier: Object
) -> void:
	_tetromino_state = tetromino_state
	_guard_state = guard_state
	_wall_state = wall_state
	_cube_state = cube_state
	_starpoint_state = starpoint_state
	_super_state = super_state
	_combat_feedback = combat_feedback
	_player_explosion_applier = player_explosion_applier


func handle_tetromino_lifecycle_event(event: Dictionary, context: Dictionary, deps: Dictionary) -> void:
	match String(event.get("type", "")):
		TetriserTetrominoState.EVENT_CELL_EVAPORATED:
			_combat_feedback.emit_debris(
				event.get("origin", Vector2.ZERO),
				event.get("cells", []),
				event.get("color", TetriserTetrominoState.FALLBACK_COLOR),
				float(event.get("cell_size", TetriserTetrominoState.CELL_SIZE))
			)
		TetriserTetrominoState.EVENT_SUPER_LANDED:
			var block: Dictionary = event.get("block", {})
			var center: Vector2 = event.get("center", Vector2.ZERO)
			var cell_size: float = float(block.get("cell_size", TetriserTetrominoState.CELL_SIZE))
			_starpoint_state.maybe_spawn_for_block(block)
			_combat_feedback.emit_debris(
				block.get("origin", Vector2.ZERO),
				block.get("cells", []),
				_tetromino_state.get_block_color(block),
				cell_size
			)
			_combat_feedback.emit_emp(center)
			_combat_feedback.queue_sound(TetriserCombatFeedbackState.SOUND_BREAK)
			_player_explosion_applier.apply(center, cell_size, true, context, deps)


func destroy_tetromino(block: Dictionary, reason: String = "") -> void:
	_starpoint_state.maybe_spawn_for_block(block)
	_combat_feedback.emit_debris(
		block.get("origin", Vector2.ZERO),
		block.get("cells", []),
		_tetromino_state.get_block_color(block),
		float(block.get("cell_size", TetriserTetrominoState.CELL_SIZE))
	)
	_tetromino_state.remove_block(block)
	_combat_feedback.queue_sound(TetriserCombatFeedbackState.SOUND_BREAK)
	_cube_state.on_tetromino_destroyed(reason)


func destroy_wall_piece(block: Dictionary) -> bool:
	_starpoint_state.maybe_spawn_for_block(block)
	if not _wall_state.begin_evaporation(block, true):
		return false
	_combat_feedback.queue_sound(TetriserCombatFeedbackState.SOUND_BREAK)
	return true


func destroy_guard_block(block: Dictionary) -> bool:
	if not _guard_state.remove_block(block):
		return false
	handle_extracted_guard(block)
	return true


func handle_extracted_guard(block: Dictionary) -> void:
	_combat_feedback.emit_debris(
		block.get("origin", Vector2.ZERO),
		block.get("cells", []),
		TetriserGuardState.COLOR,
		TetriserTetrominoState.CELL_SIZE
	)
	_combat_feedback.queue_sound(TetriserCombatFeedbackState.SOUND_BREAK)


func handle_super_tetromino_bounce(_block: Dictionary) -> void:
	_combat_feedback.queue_sound(TetriserCombatFeedbackState.SOUND_BIG)


func update_cube(delta: float, ball_pos: Vector2) -> void:
	var event_id := int(_cube_state.update(delta, ball_pos))
	if event_id != TetriserCubeState.EVENT_EXPLODED:
		return
	_clear_tetrominoes_with_debris()
	_clear_wall_blocks_with_debris()
	_starpoint_state.spawn(TetriserCubeState.CENTER)
	_combat_feedback.emit_debris(
		TetriserCubeState.CENTER - Vector2(TetriserCubeState.RADIUS, TetriserCubeState.RADIUS),
		[Vector2.ZERO],
		Color(1.0, 0.85, 0.4),
		TetriserCubeState.RADIUS * 2.0
	)
	_combat_feedback.emit_emp(TetriserCubeState.CENTER)


func update_laser(delta: float) -> void:
	var event_id: int = int(_super_state.update_laser(delta, _cube_state.is_active()))
	if event_id == TetriserSuperState.LASER_EVENT_FIRED:
		_combat_feedback.queue_sound(TetriserCombatFeedbackState.SOUND_LASER)
		_melt_cube_by_laser()


func _clear_tetrominoes_with_debris(play_break_sound: bool = true) -> void:
	if not _tetromino_state.has_blocks():
		return
	_tetromino_state.clear_all_blocks(Callable(self, "_emit_cleared_tetromino_side_effects"))
	if play_break_sound:
		_combat_feedback.queue_sound(TetriserCombatFeedbackState.SOUND_BREAK)


func _emit_cleared_tetromino_side_effects(block: Dictionary) -> void:
	_starpoint_state.maybe_spawn_for_block(block)
	_combat_feedback.emit_debris(
		block.get("origin", Vector2.ZERO),
		block.get("cells", []),
		_tetromino_state.get_block_color(block),
		float(block.get("cell_size", TetriserTetrominoState.CELL_SIZE))
	)


func _clear_wall_blocks_with_debris(play_break_sound: bool = true) -> void:
	var blocks: Array = _wall_state.take_all_blocks()
	if blocks.is_empty():
		return
	for block in blocks:
		_starpoint_state.maybe_spawn_for_block(block)
		_combat_feedback.emit_debris(
			block.get("origin", Vector2.ZERO),
			block.get("cells", []),
			block.get("color", TetriserWallState.FALLBACK_COLOR),
			float(block.get("cell_size", TetriserTetrominoState.CELL_SIZE))
		)
	if play_break_sound:
		_combat_feedback.queue_sound(TetriserCombatFeedbackState.SOUND_BREAK)


func _melt_cube_by_laser() -> void:
	if not _cube_state.is_active():
		return
	_clear_tetrominoes_with_debris(false)
	_clear_wall_blocks_with_debris(false)
	_combat_feedback.emit_emp(TetriserCubeState.CENTER)
	_cube_state.melt_by_laser()
