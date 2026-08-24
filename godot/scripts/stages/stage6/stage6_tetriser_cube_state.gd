extends RefCounted

const EVENT_NONE := 0
const EVENT_EXPLODED := 1

const CENTER := Vector2(380.0, 375.0)
const RADIUS := 90.0
const GRID_SIZE := 3
const SOLVE_DELAY_SEC := 1.0
const REBUILD_NEEDED := 5
const REBUILD_COUNT_REASONS := ["player", "dash"]
const PASS_MIN := 10
const PASS_MAX := 14
const MELT_VISUAL_SEC := 1.2
const PALETTE := [
	Color(1.0, 0.31, 0.31),
	Color(0.31, 0.70, 1.0),
	Color(1.0, 0.78, 0.24),
	Color(0.31, 0.90, 0.47),
	Color(1.0, 0.59, 0.0),
	Color(0.94, 0.94, 0.94),
]

var _cube: Dictionary = {}
var _visual_spin := 0.0
var _melt_visual_timer := 0.0
var _rng: RandomNumberGenerator


func _init(random_source: RandomNumberGenerator = null) -> void:
	if random_source == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	else:
		_rng = random_source
	reset()


func reset() -> void:
	_cube = {
		"active": true,
		"rebuild": false,
		"rebuild_progress": 0,
		"grid": _random_grid(),
		"passes": 0,
		"passes_to_solve": _rng.randi_range(PASS_MIN, PASS_MAX),
		"ball_inside": false,
		"solve_pending": false,
		"solve_timer": 0.0,
	}
	_visual_spin = 0.0
	_melt_visual_timer = 0.0


func update(delta: float, ball_pos: Vector2) -> int:
	if _cube.is_empty():
		reset()
	var safe_delta := maxf(0.0, delta)
	_visual_spin += safe_delta
	if _melt_visual_timer > 0.0:
		_melt_visual_timer = maxf(0.0, _melt_visual_timer - safe_delta)
	if bool(_cube.get("solve_pending", false)):
		_cube["solve_timer"] = float(_cube.get("solve_timer", 0.0)) - safe_delta
		if float(_cube.get("solve_timer", 0.0)) <= 0.0:
			_enter_rebuild(false)
			return EVENT_EXPLODED
		return EVENT_NONE
	if not bool(_cube.get("active", false)):
		return EVENT_NONE
	var inside := ball_pos.distance_to(CENTER) <= RADIUS
	if inside and not bool(_cube.get("ball_inside", false)):
		_on_ball_enter()
	_cube["ball_inside"] = inside
	return EVENT_NONE


func on_tetromino_destroyed(reason: String) -> bool:
	if not REBUILD_COUNT_REASONS.has(reason):
		return false
	if not bool(_cube.get("rebuild", false)):
		return false
	_cube["rebuild_progress"] = int(_cube.get("rebuild_progress", 0)) + 1
	if int(_cube.get("rebuild_progress", 0)) < REBUILD_NEEDED:
		return false
	reset()
	return true


func melt_by_laser() -> bool:
	if _cube.is_empty() or not bool(_cube.get("active", false)):
		return false
	_enter_rebuild(true)
	return true


func is_active() -> bool:
	return bool(_cube.get("active", false))


func is_rebuild() -> bool:
	return bool(_cube.get("rebuild", false))


func get_rebuild_progress() -> int:
	return int(_cube.get("rebuild_progress", 0))


func get_draw_data() -> Dictionary:
	if _cube.is_empty():
		return {}
	var solve_progress := 0.0
	if bool(_cube.get("solve_pending", false)):
		solve_progress = clampf(1.0 - float(_cube.get("solve_timer", 0.0)) / SOLVE_DELAY_SEC, 0.0, 1.0)
	var passes_to_solve := maxi(1, int(_cube.get("passes_to_solve", PASS_MAX)))
	var hit_progress := clampf(float(_cube.get("passes", 0)) / float(passes_to_solve), 0.0, 1.0)
	if bool(_cube.get("solve_pending", false)):
		hit_progress = 1.0
	var melt_progress := 0.0
	if _melt_visual_timer > 0.0:
		melt_progress = clampf(1.0 - _melt_visual_timer / MELT_VISUAL_SEC, 0.0, 1.0)
	return {
		"center": CENTER,
		"radius": RADIUS,
		"spin": _visual_spin,
		"hit_progress": hit_progress,
		"melt_progress": melt_progress,
		"grid": (_cube.get("grid", []) as Array).duplicate(),
		"grid_size": GRID_SIZE,
		"active": bool(_cube.get("active", false)),
		"rebuild": bool(_cube.get("rebuild", false)),
		"rebuild_progress": int(_cube.get("rebuild_progress", 0)),
		"rebuild_needed": REBUILD_NEEDED,
		"solve_pending": bool(_cube.get("solve_pending", false)),
		"solve_progress": solve_progress,
	}


func debug_pass_ball_through() -> void:
	_on_ball_enter()


func debug_force_solve_pending() -> void:
	_cube["passes"] = int(_cube.get("passes_to_solve", PASS_MIN))
	_on_ball_enter()


func _on_ball_enter() -> void:
	_cube["passes"] = int(_cube.get("passes", 0)) + 1
	if int(_cube.get("passes", 0)) >= int(_cube.get("passes_to_solve", PASS_MIN)):
		_cube["grid"] = _uniform_grid()
		_cube["solve_pending"] = true
		_cube["solve_timer"] = SOLVE_DELAY_SEC
	else:
		_cube["grid"] = _random_grid()


func _enter_rebuild(melted: bool) -> void:
	_cube["active"] = false
	_cube["rebuild"] = true
	_cube["rebuild_progress"] = 0
	_cube["solve_pending"] = false
	_cube["solve_timer"] = 0.0
	_melt_visual_timer = MELT_VISUAL_SEC if melted else 0.0


func _random_grid() -> Array:
	var grid: Array = []
	for _index in range(GRID_SIZE * GRID_SIZE):
		grid.append(PALETTE[_rng.randi_range(0, PALETTE.size() - 1)])
	if _grid_uniform(grid):
		var replacement_index := (PALETTE.find(grid[0]) + 1) % PALETTE.size()
		grid[_rng.randi_range(0, grid.size() - 1)] = PALETTE[replacement_index]
	return grid


func _uniform_grid() -> Array:
	var color: Color = PALETTE[_rng.randi_range(0, PALETTE.size() - 1)]
	var grid: Array = []
	for _index in range(GRID_SIZE * GRID_SIZE):
		grid.append(color)
	return grid


func _grid_uniform(grid: Array) -> bool:
	if grid.is_empty():
		return false
	for color in grid:
		if color != grid[0]:
			return false
	return true
