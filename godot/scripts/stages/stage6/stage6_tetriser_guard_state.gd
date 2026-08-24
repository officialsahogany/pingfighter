extends RefCounted

# Stage 6 Tetriser guard-bar lifecycle.
#
# Owns the shared-RNG spawn timer, side balancing, assembly/slide transitions,
# active collision lookup, removal, and immutable draw/debug snapshots. The host
# keeps boss-gauge accounting plus shared ball reflection, debris, and audio.

const MIN_INTERVAL_SEC := 7.0
const MAX_INTERVAL_SEC := 15.0
const COST_SINGLE := 50.0
const COST_PAIR := 100.0
const MAX_ACTIVE := 4
const CELL_SIZE := 20.0
const SLIDE_SEC := 0.32
const ASSEMBLY_TOTAL_SEC := 1.0
const ASSEMBLY_STEP_SEC := 0.25
const ASSEMBLY_MOVE_SEC := 0.20
const GAP_Y := 40.0
const SPAWN_OFFSET_Y := 8.0
const FIELD_WIDTH := 760.0
const CELLS := [Vector2(0, 0), Vector2(1, 0), Vector2(2, 0), Vector2(3, 0)]
const COLOR := Color(0.58, 0.66, 0.78)

var _blocks: Array[Dictionary] = []
var _timer_sec: float = 0.0
var _timer_total_sec: float = MAX_INTERVAL_SEC
var _rng: RandomNumberGenerator


func _init(random_source: RandomNumberGenerator = null) -> void:
	if random_source == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	else:
		_rng = random_source
	arm_timer()


func clear_blocks() -> void:
	_blocks.clear()


func arm_timer() -> void:
	_timer_sec = _rng.randf_range(MIN_INTERVAL_SEC, MAX_INTERVAL_SEC)
	_timer_total_sec = _timer_sec


# Returns the exact gauge cost consumed by a spawn. The host applies the cost
# after this call so boss_gauge remains the public compatibility surface.
func update_scheduler(delta: float, context: Dictionary, available_gauge: float) -> float:
	_timer_sec -= delta
	if _timer_sec > 0.0:
		return 0.0
	var room: int = MAX_ACTIVE - _blocks.size()
	if room <= 0:
		_timer_sec = 1.0
		return 0.0
	if room >= 2 and available_gauge >= COST_PAIR:
		_spawn_block("left", context)
		_spawn_block("right", context)
		arm_timer()
		return COST_PAIR
	if available_gauge >= COST_SINGLE:
		_spawn_block(_fewer_side(), context)
		arm_timer()
		return COST_SINGLE
	_timer_sec = 1.0
	return 0.0


func update_motion(delta: float) -> void:
	for block in _blocks:
		match String(block.get("state", "")):
			"assembling":
				_update_assembling(block, delta)
			"sliding":
				_update_sliding(block, delta)


func find_active_hit(ball_rect: Rect2) -> Dictionary:
	for block in _blocks:
		if String(block.get("state", "")) != "active":
			continue
		var origin: Vector2 = block.get("origin", Vector2.ZERO)
		for cell in block.get("cells", []):
			var cell_rect := Rect2(origin + cell * CELL_SIZE, Vector2(CELL_SIZE, CELL_SIZE))
			if ball_rect.intersects(cell_rect):
				return {"item": block, "cell_rect": cell_rect}
	return {}


func remove_block(block: Dictionary) -> bool:
	if not _blocks.has(block):
		return false
	_blocks.erase(block)
	return true


# Preserves the host's old collect-then-remove sweep ordering for dash, smoke,
# and explosion destruction. Returned dictionaries remain valid debris payloads.
func extract_active_matching(test: Callable) -> Array:
	var removed: Array = []
	for block in _blocks:
		if String(block.get("state", "")) != "active":
			continue
		var origin: Vector2 = block.get("origin", Vector2.ZERO)
		for cell in block.get("cells", []):
			var cell_rect := Rect2(origin + cell * CELL_SIZE, Vector2(CELL_SIZE, CELL_SIZE))
			if bool(test.call(cell_rect)):
				removed.append(block)
				break
	for block in removed:
		_blocks.erase(block)
	return removed


func get_draw_list() -> Array:
	var out: Array = []
	for block in _blocks:
		var block_cells: Array = block.get("cells", [])
		out.append({
			"state": block.get("state", "active"),
			"origin": block.get("origin", Vector2.ZERO),
			"cells": block_cells.duplicate(),
			"visible_cells": int(block.get("visible_cells", block_cells.size())),
			"color": COLOR,
		})
	return out


func has_blocks() -> bool:
	return not _blocks.is_empty()


func get_count() -> int:
	return _blocks.size()


func get_timer_remaining() -> float:
	return _timer_sec


func get_timer_total() -> float:
	return _timer_total_sec


func get_states() -> Array:
	var out: Array = []
	for block in _blocks:
		out.append(String(block.get("state", "")))
	return out


func get_visible_counts() -> Array:
	var out: Array = []
	for block in _blocks:
		var block_cells: Array = block.get("cells", [])
		out.append(int(block.get("visible_cells", block_cells.size())))
	return out


func debug_force_scheduler_ready() -> void:
	_timer_sec = 0.0


func debug_spawn_active_at(origin: Vector2, side: String = "left") -> void:
	_blocks.append({
		"kind": "guard",
		"state": "active",
		"side": side,
		"cells": CELLS.duplicate(),
		"final_cells": CELLS.duplicate(),
		"visible_cells": CELLS.size(),
		"origin": origin,
		"start_origin": origin,
		"final_origin": origin,
		"slide_elapsed": SLIDE_SEC,
	})


func _fewer_side() -> String:
	return "left" if _count_side("left") <= _count_side("right") else "right"


func _count_side(side: String) -> int:
	var count: int = 0
	for block in _blocks:
		if String(block.get("side", "left")) == side:
			count += 1
	return count


func _spawn_block(side: String, context: Dictionary) -> void:
	var boss_pos: Vector2 = context.get("boss_pos", Vector2(330.0, 25.0))
	var boss_size: Vector2 = context.get("boss_paddle_size", Vector2(100.0, 40.0))
	var center_x: float = boss_pos.x + boss_size.x * 0.5
	var level: int = _count_side(side)
	var base_top: float = maxf(12.0, boss_pos.y - CELL_SIZE - SPAWN_OFFSET_Y)
	var top: float = maxf(12.0, base_top - float(level) * GAP_Y)
	var start_origin: Vector2
	var final_origin: Vector2
	if side == "left":
		start_origin = Vector2(center_x - CELL_SIZE * 4.0, top)
		final_origin = Vector2(maxf(12.0, boss_pos.x - CELL_SIZE * 4.0 - 6.0), top)
	else:
		start_origin = Vector2(center_x, top)
		final_origin = Vector2(minf(FIELD_WIDTH - CELL_SIZE * 4.0 - 12.0, boss_pos.x + boss_size.x + 6.0), top)
	var assembly_cells: Array = []
	for guard_cell in CELLS:
		var cell_pos: Vector2 = guard_cell
		assembly_cells.append(cell_pos + Vector2(_rng.randf_range(-8.0, 8.0) / CELL_SIZE, 0.0))
	_blocks.append({
		"kind": "guard",
		"state": "assembling",
		"side": side,
		"cells": assembly_cells,
		"assembly_start_cells": assembly_cells.duplicate(),
		"final_cells": CELLS.duplicate(),
		"visible_cells": 0,
		"origin": start_origin,
		"start_origin": start_origin,
		"final_origin": final_origin,
		"assembly_elapsed": 0.0,
		"slide_elapsed": 0.0,
	})


func _update_assembling(block: Dictionary, delta: float) -> void:
	var final_cells: Array = block.get("final_cells", CELLS)
	var start_cells: Array = block.get("assembly_start_cells", block.get("cells", final_cells))
	var cell_count: int = final_cells.size()
	var elapsed: float = float(block.get("assembly_elapsed", 0.0)) + delta
	block["assembly_elapsed"] = elapsed
	block["visible_cells"] = clampi(int(elapsed / ASSEMBLY_STEP_SEC), 0, cell_count)
	var current_cells: Array = []
	for idx in range(cell_count):
		var start_cell: Vector2 = start_cells[idx]
		var final_cell: Vector2 = final_cells[idx]
		var move_start: float = float(idx + 1) * ASSEMBLY_STEP_SEC - ASSEMBLY_MOVE_SEC
		var move_t: float = clampf((elapsed - move_start) / ASSEMBLY_MOVE_SEC, 0.0, 1.0)
		current_cells.append(start_cell.lerp(final_cell, move_t))
	block["cells"] = current_cells
	if elapsed >= ASSEMBLY_TOTAL_SEC:
		block["state"] = "sliding"
		block["visible_cells"] = cell_count
		block["cells"] = final_cells.duplicate()
		block["slide_elapsed"] = 0.0


func _update_sliding(block: Dictionary, delta: float) -> void:
	var elapsed: float = float(block["slide_elapsed"]) + delta
	block["slide_elapsed"] = elapsed
	var t: float = clampf(elapsed / SLIDE_SEC, 0.0, 1.0)
	var ease_t: float = 1.0 - (1.0 - t) * (1.0 - t)
	var start_origin: Vector2 = block["start_origin"]
	var final_origin: Vector2 = block["final_origin"]
	block["origin"] = start_origin.lerp(final_origin, ease_t)
	if t >= 1.0:
		block["state"] = "active"
		block["origin"] = final_origin
		block["cells"] = block.get("final_cells", CELLS).duplicate()
