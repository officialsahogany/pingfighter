extends RefCounted

# Stage 6 Tetriser edge-wall lifecycle.
#
# Owns the fixed cooldown, shared-RNG piece generation, assembly/install/
# evaporation transitions, collision queries, and copied draw/debug snapshots.
# The host retains boss-gauge accounting plus starpoint, debris, reflection, and
# audio side effects.

const INTERVAL_SEC := 30.0
const COST := 50.0
const CELL_SIZE := 20.0
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const COLS := 4
const PIECES_PER_SIDE := 10
const ASSEMBLY_TOTAL_SEC := 1.0
const ASSEMBLY_STEP_SEC := 0.25
const LIFETIME_SEC := 6.0
const NATURAL_EVAPORATE_CELL_INTERVAL_SEC := 0.16
const HIT_EVAPORATE_CELL_INTERVAL_SEC := 0.111
const GOLDEN_STARPOINT_CHANCE := 0.03
const FALLBACK_COLOR := Color(0.6, 0.7, 1.0)

var _blocks: Array[Dictionary] = []
var _timer_sec: float = INTERVAL_SEC
var _timer_total_sec: float = INTERVAL_SEC
var _rng: RandomNumberGenerator
var _shape_catalog: Dictionary
var _color_catalog: Dictionary
var _shape_keys: Array


func _init(
	random_source: RandomNumberGenerator,
	shape_catalog: Dictionary,
	color_catalog: Dictionary,
	shape_keys: Array
) -> void:
	_rng = random_source
	_shape_catalog = shape_catalog
	_color_catalog = color_catalog
	_shape_keys = shape_keys.duplicate()
	arm_timer()


func clear_blocks() -> void:
	_blocks.clear()


func arm_timer() -> void:
	_timer_sec = INTERVAL_SEC
	_timer_total_sec = INTERVAL_SEC


# Returns the exact boss-gauge cost consumed by a successful spawn.
func update_scheduler(delta: float, available_gauge: float) -> float:
	_timer_sec -= delta
	if _timer_sec > 0.0:
		return 0.0
	if available_gauge < COST:
		_timer_sec = 1.0
		return 0.0
	spawn_wall()
	arm_timer()
	return COST


# Returns debris payloads for cells removed during this tick. Event collection
# preserves the old block order and per-piece pop-front order.
func update_lifetime(delta: float) -> Array:
	var debris_events: Array = []
	if _blocks.is_empty():
		return debris_events
	for block in _blocks.duplicate():
		if not _blocks.has(block):
			continue
		match String(block.get("state", "")):
			"assembling":
				_update_assembling(block, delta)
			"installed":
				_update_installed(block, delta)
			"evaporating":
				_update_evaporating(block, delta, debris_events)
	return debris_events


func spawn_wall() -> void:
	_blocks.clear()
	var grid_width: float = float(COLS) * CELL_SIZE
	_spawn_side(0.0)
	_spawn_side(FIELD_WIDTH - grid_width)


func begin_evaporation(block: Dictionary, fast: bool) -> bool:
	if not _blocks.has(block) or String(block.get("state", "")) == "evaporating":
		return false
	block["state"] = "evaporating"
	block["evaporate_elapsed"] = 0.0
	block["evaporate_interval"] = HIT_EVAPORATE_CELL_INTERVAL_SEC if fast else NATURAL_EVAPORATE_CELL_INTERVAL_SEC
	block["visible_cells"] = (block.get("cells", []) as Array).size()
	return true


func find_installed_hit(ball_rect: Rect2) -> Dictionary:
	for block in _blocks:
		if String(block.get("state", "")) != "installed":
			continue
		var origin: Vector2 = block.get("origin", Vector2.ZERO)
		var cell_size: float = float(block.get("cell_size", CELL_SIZE))
		for cell in block.get("cells", []):
			var cell_rect := Rect2(origin + cell * cell_size, Vector2(cell_size, cell_size))
			if ball_rect.intersects(cell_rect):
				return {"item": block, "cell_rect": cell_rect}
	return {}


func find_installed_matching(test: Callable) -> Array:
	var matches: Array = []
	for block in _blocks:
		if String(block.get("state", "")) != "installed":
			continue
		var origin: Vector2 = block.get("origin", Vector2.ZERO)
		var cell_size: float = float(block.get("cell_size", CELL_SIZE))
		for cell in block.get("cells", []):
			var cell_rect := Rect2(origin + cell * cell_size, Vector2(cell_size, cell_size))
			if bool(test.call(cell_rect)):
				matches.append(block)
				break
	return matches


func get_installed_cell_rects() -> Array:
	var rects: Array = []
	for block in _blocks:
		if String(block.get("state", "")) != "installed":
			continue
		var origin: Vector2 = block.get("origin", Vector2.ZERO)
		var cell_size: float = float(block.get("cell_size", CELL_SIZE))
		for cell in block.get("cells", []):
			rects.append(Rect2(origin + cell * cell_size, Vector2(cell_size, cell_size)))
	return rects


# Transfers live block dictionaries to the host for cross-domain starpoint and
# debris finalization, then relinquishes all wall ownership.
func take_all_blocks() -> Array:
	var taken: Array = _blocks.duplicate()
	_blocks.clear()
	return taken


func get_draw_list() -> Array:
	var out: Array = []
	for block in _blocks:
		var cells: Array = block.get("cells", [])
		var visible_cells: int = mini(int(block.get("visible_cells", cells.size())), cells.size())
		var cell_size: float = float(block.get("cell_size", CELL_SIZE))
		var alpha: float = 0.5 if String(block.get("state", "")) == "assembling" else 1.0
		for index in range(visible_cells):
			out.append({
				"origin": block.get("origin", Vector2.ZERO) + cells[index] * cell_size,
				"color": block.get("color", FALLBACK_COLOR),
				"state": block.get("state", "installed"),
				"alpha": alpha,
			})
	return out


func has_blocks() -> bool:
	return not _blocks.is_empty()


func get_timer_remaining() -> float:
	return _timer_sec


func get_timer_total() -> float:
	return _timer_total_sec


func get_piece_count() -> int:
	return _blocks.size()


func get_cell_count() -> int:
	var count: int = 0
	for block in _blocks:
		count += (block.get("cells", []) as Array).size()
	return count


func get_collidable_cell_count() -> int:
	var count: int = 0
	for block in _blocks:
		if String(block.get("state", "")) == "installed":
			count += (block.get("cells", []) as Array).size()
	return count


func get_states() -> Array:
	var out: Array = []
	for block in _blocks:
		out.append(String(block.get("state", "")))
	return out


func debug_force_scheduler_ready() -> void:
	_timer_sec = 0.0


func debug_spawn_cell_at(origin: Vector2, golden: bool = false) -> void:
	_blocks.append({
		"kind": "wall",
		"wall_generated": true,
		"state": "installed",
		"cells": [Vector2.ZERO],
		"origin": origin,
		"visible_cells": 1,
		"cell_size": CELL_SIZE,
		"color": FALLBACK_COLOR,
		"golden": golden,
		"star_dropped": false,
	})


func _spawn_side(origin_x: float) -> void:
	var occupied := {}
	var rows: int = maxi(1, int(FIELD_HEIGHT / CELL_SIZE))
	var origin_bottom_y: float = FIELD_HEIGHT - CELL_SIZE
	for _piece_index in range(PIECES_PER_SIDE):
		var shape_name: String = String(_shape_keys[_rng.randi_range(0, _shape_keys.size() - 1)])
		var base_cells: Array = _shape_catalog.get(shape_name, _shape_catalog.get("T", []))
		var cells: Array = _rotate_cells(base_cells, _rng.randi_range(0, 3))
		var dimensions: Vector2 = _cells_dims(cells)
		var width_cells: int = maxi(1, int(dimensions.x))
		var max_y: int = maxi(0, int(dimensions.y) - 1)
		var start_col: int = _rng.randi_range(0, maxi(0, COLS - width_cells))
		var row: int = 0
		while true:
			var blocked := false
			for cell in cells:
				var next_x: int = start_col + int(cell.x)
				var next_y: int = row + int(cell.y) + 1
				if next_y >= rows or occupied.has(_grid_key(next_x, next_y)):
					blocked = true
					break
			if blocked:
				break
			row += 1
			if row + max_y >= rows - 1:
				break
		for cell in cells:
			occupied[_grid_key(start_col + int(cell.x), row + int(cell.y))] = true
		var screen_cells: Array = _screen_cells(cells, max_y)
		var origin := Vector2(
			origin_x + float(start_col) * CELL_SIZE,
			origin_bottom_y - float(row + max_y) * CELL_SIZE - CELL_SIZE
		)
		_blocks.append({
			"kind": "wall",
			"wall_generated": true,
			"shape": shape_name,
			"state": "assembling",
			"cells": screen_cells,
			"origin": origin,
			"assembly_elapsed": 0.0,
			"settled_elapsed": 0.0,
			"evaporate_elapsed": 0.0,
			"visible_cells": 0,
			"cell_size": CELL_SIZE,
			"color": _color_catalog.get(shape_name, FALLBACK_COLOR),
			"golden": _rng.randf() < GOLDEN_STARPOINT_CHANCE,
			"star_dropped": false,
		})


func _update_assembling(block: Dictionary, delta: float) -> void:
	var elapsed: float = float(block.get("assembly_elapsed", 0.0)) + delta
	block["assembly_elapsed"] = elapsed
	var cell_count: int = (block.get("cells", []) as Array).size()
	block["visible_cells"] = clampi(int(elapsed / ASSEMBLY_STEP_SEC), 0, cell_count)
	if elapsed >= ASSEMBLY_TOTAL_SEC:
		block["state"] = "installed"
		block["visible_cells"] = cell_count
		block["settled_elapsed"] = 0.0


func _update_installed(block: Dictionary, delta: float) -> void:
	var elapsed: float = float(block.get("settled_elapsed", 0.0)) + delta
	block["settled_elapsed"] = elapsed
	if elapsed >= LIFETIME_SEC:
		begin_evaporation(block, false)


func _update_evaporating(block: Dictionary, delta: float, debris_events: Array) -> void:
	var cells: Array = block.get("cells", [])
	if cells.is_empty():
		_blocks.erase(block)
		return
	var cell_size: float = float(block.get("cell_size", CELL_SIZE))
	var interval: float = maxf(0.001, float(block.get("evaporate_interval", NATURAL_EVAPORATE_CELL_INTERVAL_SEC)))
	var elapsed: float = float(block.get("evaporate_elapsed", 0.0)) + delta
	while elapsed >= interval and not cells.is_empty():
		elapsed -= interval
		var evaporated_cell: Vector2 = cells.pop_front()
		debris_events.append({
			"origin": block.get("origin", Vector2.ZERO) + evaporated_cell * cell_size,
			"cells": [Vector2.ZERO],
			"color": block.get("color", FALLBACK_COLOR),
			"cell_size": cell_size,
		})
	block["cells"] = cells
	block["visible_cells"] = mini(int(block.get("visible_cells", cells.size())), cells.size())
	block["evaporate_elapsed"] = elapsed
	if cells.is_empty():
		_blocks.erase(block)


func _grid_key(col: int, row: int) -> String:
	return "%d:%d" % [col, row]


func _screen_cells(cells: Array, max_y: int) -> Array:
	var out: Array = []
	for cell in cells:
		out.append(Vector2(cell.x, float(max_y) - cell.y))
	return out


func _rotate_cells(cells: Array, times: int) -> Array:
	var points: Array = cells.duplicate()
	for _index in range(posmod(times, 4)):
		var rotated: Array = []
		var min_x: float = INF
		var min_y: float = INF
		for point in points:
			var rotated_point := Vector2(-point.y, point.x)
			rotated.append(rotated_point)
			min_x = minf(min_x, rotated_point.x)
			min_y = minf(min_y, rotated_point.y)
		var shifted: Array = []
		for point in rotated:
			shifted.append(Vector2(point.x - min_x, point.y - min_y))
		points = shifted
	return points


func _cells_dims(cells: Array) -> Vector2:
	var max_x: float = 0.0
	var max_y: float = 0.0
	for point in cells:
		max_x = maxf(max_x, point.x)
		max_y = maxf(max_y, point.y)
	return Vector2(max_x + 1.0, max_y + 1.0)
