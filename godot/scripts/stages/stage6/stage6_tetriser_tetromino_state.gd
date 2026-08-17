extends RefCounted

# Stage 6 falling/settled tetromino lifecycle.
#
# Owns the shared-RNG spawn timer, shape/motion rolls, assembly, discrete fall,
# drift/rotation, settle/evaporation transitions, collision queries, and copied
# draw/debug snapshots. The host synchronously handles emitted gameplay events
# so starpoint RNG, debris, EMP, status, and audio side effects keep their
# original frame and random-consumption order.

const EVENT_CELL_EVAPORATED := "cell_evaporated"
const EVENT_SUPER_LANDED := "super_landed"

const MIN_INTERVAL_SEC := 5.0
const MAX_INTERVAL_SEC := 10.0
const GAUGE_COST := 30.0
const CELL_SIZE := 20.0
const ASSEMBLY_TOTAL_SEC := 1.0
const ASSEMBLY_STEP_SEC := 0.25
const FALL_STEP_SEC := 0.110
const DRIFT_CHANCE := 0.40
const ROTATE_CHANCE := 0.35
const MOTION_START_MIN_SEC := 0.5
const MOTION_START_MAX_SEC := 1.2
const ROTATE_INTERVAL_MIN_SEC := 0.200
const ROTATE_INTERVAL_MAX_SEC := 0.340
const SETTLED_LIFETIME_SEC := 1.5
const EVAPORATE_CELL_INTERVAL_SEC := 0.16
const SUPER_CELL_SCALE := 1.7
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const SPAWN_TOP_Y := 92.0
const SPAWN_MARGIN_X := 40.0
const MAX_ACTIVE := 14
const GOLDEN_STARPOINT_CHANCE := 0.03

const SHAPES := {
	"I": [Vector2(0, 0), Vector2(1, 0), Vector2(2, 0), Vector2(3, 0)],
	"O": [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)],
	"T": [Vector2(0, 0), Vector2(1, 0), Vector2(2, 0), Vector2(1, 1)],
	"S": [Vector2(1, 0), Vector2(2, 0), Vector2(0, 1), Vector2(1, 1)],
	"Z": [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(2, 1)],
	"J": [Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(2, 1)],
	"L": [Vector2(2, 0), Vector2(0, 1), Vector2(1, 1), Vector2(2, 1)],
}
const COLORS := {
	"I": Color(0.30, 0.80, 0.95),
	"O": Color(0.95, 0.83, 0.30),
	"T": Color(0.72, 0.40, 0.92),
	"S": Color(0.40, 0.86, 0.45),
	"Z": Color(0.93, 0.36, 0.38),
	"J": Color(0.36, 0.50, 0.93),
	"L": Color(0.95, 0.58, 0.27),
}
const FALLING_SHAPE_KEYS := ["T", "L", "Z", "I", "O"]
const SOLID_STATES := ["falling", "settled"]
const FALLBACK_COLOR := Color(0.6, 0.7, 1.0)

var _blocks: Array[Dictionary] = []
var _timer_sec: float = 0.0
var _timer_total_sec: float = MAX_INTERVAL_SEC
var _rng: RandomNumberGenerator
var _shape_keys: Array = FALLING_SHAPE_KEYS.duplicate()


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


# Returns the exact boss-gauge cost consumed by a successful spawn.
func update_scheduler(delta: float, context: Dictionary, available_gauge: float, super_active: bool) -> float:
	_timer_sec -= delta
	if _timer_sec > 0.0:
		return 0.0
	if available_gauge < GAUGE_COST or _blocks.size() >= MAX_ACTIVE:
		_timer_sec = 1.0
		return 0.0
	spawn(context, super_active)
	arm_timer()
	return GAUGE_COST


func spawn(context: Dictionary = {}, super_active: bool = false) -> void:
	var shape_name: String = String(_shape_keys[_rng.randi_range(0, _shape_keys.size() - 1)])
	var cells: Array = _rotate_cells(SHAPES[shape_name], _rng.randi_range(0, 3))
	var cell_size: float = CELL_SIZE * (SUPER_CELL_SCALE if super_active else 1.0)
	var width_px: float = _cells_dims(cells).x * cell_size
	var min_x: float = SPAWN_MARGIN_X
	var max_x: float = maxf(min_x, FIELD_WIDTH - width_px - SPAWN_MARGIN_X)
	var boss_center_x: float = _boss_center_x_from_context(context)
	var origin_x: float = clampf(boss_center_x - width_px * 0.5, min_x, max_x)
	_blocks.append({
		"shape": shape_name,
		"state": "assembling",
		"cells": cells,
		"origin": Vector2(origin_x, SPAWN_TOP_Y),
		"assembly_elapsed": 0.0,
		"visible_cells": 1,
		"step_accum": 0.0,
		"cell_size": cell_size,
		"super": super_active,
		"drift_cells_remaining": _roll_drift_budget(),
		"drift_start_delay": 0.0,
		"drift_elapsed": 0.0,
		"drift_cooldown_steps": 0,
		"rotate_times_remaining": _roll_rotate_budget(),
		"rotate_start_delay": 0.0,
		"rotate_timer_sec": 0.0,
		"rotate_interval_sec": _random_rotate_interval(),
		"rotate_dir": _random_rotate_dir(),
		"golden": _rng.randf() < GOLDEN_STARPOINT_CHANCE,
		"star_dropped": false,
	})


# `event_sink` is called at the original mutation point. In particular, a
# golden super landing may consume shared RNG before a later block's rotation.
func update_lifecycle(delta: float, external_settled_rects: Array, event_sink: Callable = Callable()) -> void:
	var settled_rects: Array = _collect_settled_cell_rects()
	settled_rects.append_array(external_settled_rects)
	for block in _blocks.duplicate():
		if not _blocks.has(block):
			continue
		match String(block.get("state", "")):
			"assembling":
				_update_assembling(block, delta)
			"falling":
				_update_falling(block, delta, settled_rects, event_sink)
			"settled":
				_update_settled(block, delta)
			"evaporating":
				_update_evaporating(block, delta, event_sink)


func find_solid_hit(ball_rect: Rect2) -> Dictionary:
	for block in _blocks:
		if not SOLID_STATES.has(String(block.get("state", ""))):
			continue
		var origin: Vector2 = block["origin"]
		var cell_size: float = float(block.get("cell_size", CELL_SIZE))
		for cell in block["cells"]:
			var cell_rect := Rect2(origin + cell * cell_size, Vector2(cell_size, cell_size))
			if ball_rect.intersects(cell_rect):
				return {"item": block, "cell_rect": cell_rect}
	return {}


func find_solid_matching(test: Callable) -> Array:
	var matches: Array = []
	for block in _blocks:
		if not SOLID_STATES.has(String(block.get("state", ""))):
			continue
		var origin: Vector2 = block["origin"]
		var cell_size: float = float(block.get("cell_size", CELL_SIZE))
		for cell in block["cells"]:
			var cell_rect := Rect2(origin + cell * cell_size, Vector2(cell_size, cell_size))
			if bool(test.call(cell_rect)):
				matches.append(block)
				break
	return matches


func remove_block(block: Dictionary) -> bool:
	if not _blocks.has(block):
		return false
	_blocks.erase(block)
	return true


# Visits blocks in live order before clearing, preserving starpoint RNG order.
func clear_all_blocks(visitor: Callable = Callable()) -> void:
	for block in _blocks:
		if visitor.is_valid():
			visitor.call(block)
	_blocks.clear()


func get_draw_list() -> Array:
	var out: Array = []
	for block in _blocks:
		var shape_name: String = String(block.get("shape", "T"))
		out.append({
			"shape": shape_name,
			"state": block.get("state", "falling"),
			"origin": block.get("origin", Vector2.ZERO),
			"cells": (block.get("cells", []) as Array).duplicate(),
			"visible_cells": int(block.get("visible_cells", 4)),
			"cell_size": float(block.get("cell_size", CELL_SIZE)),
			"super": bool(block.get("super", false)),
			"color": COLORS.get(shape_name, FALLBACK_COLOR),
		})
	return out


func get_block_color(block: Dictionary) -> Color:
	return COLORS.get(String(block.get("shape", "T")), FALLBACK_COLOR)


func has_blocks() -> bool:
	return not _blocks.is_empty()


func get_count() -> int:
	return _blocks.size()


func get_states() -> Array:
	var out: Array = []
	for block in _blocks:
		out.append(String(block.get("state", "")))
	return out


func get_timer_remaining() -> float:
	return _timer_sec


func get_timer_total() -> float:
	return _timer_total_sec


func debug_set_timer(value: float) -> void:
	_timer_sec = value


func debug_spawn_at(origin: Vector2, shape: String = "O", super_flag: bool = false, golden: bool = false) -> void:
	var cells: Array = (SHAPES.get(shape, SHAPES["O"]) as Array).duplicate()
	_blocks.append({
		"shape": shape,
		"state": "falling",
		"cells": cells,
		"origin": origin,
		"assembly_elapsed": ASSEMBLY_TOTAL_SEC,
		"visible_cells": cells.size(),
		"step_accum": 0.0,
		"cell_size": CELL_SIZE * (SUPER_CELL_SCALE if super_flag else 1.0),
		"super": super_flag,
		"drift_cells_remaining": 0,
		"drift_start_delay": 0.0,
		"drift_elapsed": 0.0,
		"drift_cooldown_steps": 0,
		"rotate_times_remaining": 0,
		"rotate_start_delay": 0.0,
		"rotate_timer_sec": 0.0,
		"rotate_interval_sec": ROTATE_INTERVAL_MIN_SEC,
		"rotate_dir": 1,
		"golden": golden,
		"star_dropped": false,
	})


func debug_configure_first_motion(motion: Dictionary) -> void:
	if _blocks.is_empty():
		return
	for key in motion.keys():
		_blocks[0][key] = motion[key]


func debug_get_first_origin() -> Vector2:
	if _blocks.is_empty():
		return Vector2.ZERO
	return _blocks[0].get("origin", Vector2.ZERO)


func debug_get_first_cells() -> Array:
	if _blocks.is_empty():
		return []
	return (_blocks[0].get("cells", []) as Array).duplicate()


func debug_get_first_motion() -> Dictionary:
	if _blocks.is_empty():
		return {}
	var block: Dictionary = _blocks[0]
	return {
		"step_accum": float(block.get("step_accum", 0.0)),
		"drift_cells_remaining": int(block.get("drift_cells_remaining", 0)),
		"rotate_times_remaining": int(block.get("rotate_times_remaining", 0)),
		"rotate_timer_sec": float(block.get("rotate_timer_sec", 0.0)),
	}


func _update_assembling(block: Dictionary, delta: float) -> void:
	var elapsed: float = float(block["assembly_elapsed"]) + delta
	block["assembly_elapsed"] = elapsed
	var cell_count: int = (block["cells"] as Array).size()
	block["visible_cells"] = clampi(int(elapsed / ASSEMBLY_STEP_SEC) + 1, 1, cell_count)
	if elapsed >= ASSEMBLY_TOTAL_SEC:
		_begin_falling(block)
		block["visible_cells"] = cell_count


func _update_falling(block: Dictionary, delta: float, settled_rects: Array, event_sink: Callable) -> void:
	var step_accum: float = float(block.get("step_accum", 0.0)) + delta
	while step_accum >= FALL_STEP_SEC and String(block.get("state", "")) == "falling":
		step_accum -= FALL_STEP_SEC
		_advance_motion_budget(block, FALL_STEP_SEC)
		_try_step_drift(block, settled_rects)
		_try_step_rotation(block, settled_rects)
		var origin: Vector2 = block["origin"]
		var cell_size: float = float(block.get("cell_size", CELL_SIZE))
		var next_origin: Vector2 = origin + Vector2(0.0, cell_size)
		var settle_result: Dictionary = _fall_step_settle_result(block, origin, next_origin, settled_rects)
		if bool(settle_result.get("settle", false)):
			block["origin"] = settle_result.get("origin", origin)
			block["step_accum"] = step_accum
			if bool(block.get("super", false)):
				_emit_super_landed(block, event_sink)
				return
			_mark_settled(block)
			return
		block["origin"] = next_origin
	block["step_accum"] = step_accum


func _begin_falling(block: Dictionary) -> void:
	block["state"] = "falling"
	block["step_accum"] = 0.0
	block["drift_elapsed"] = 0.0
	block["rotate_timer_sec"] = 0.0
	block["drift_start_delay"] = _rng.randf_range(MOTION_START_MIN_SEC, MOTION_START_MAX_SEC) if int(block.get("drift_cells_remaining", 0)) != 0 else 0.0
	block["rotate_start_delay"] = _rng.randf_range(MOTION_START_MIN_SEC, MOTION_START_MAX_SEC) if int(block.get("rotate_times_remaining", 0)) > 0 else 0.0


func _mark_settled(block: Dictionary) -> void:
	block["state"] = "settled"
	block["settled_elapsed"] = 0.0
	block["evaporate_elapsed"] = 0.0
	block["visible_cells"] = (block.get("cells", []) as Array).size()


func _update_settled(block: Dictionary, delta: float) -> void:
	var elapsed: float = float(block.get("settled_elapsed", 0.0)) + delta
	block["settled_elapsed"] = elapsed
	if elapsed >= SETTLED_LIFETIME_SEC:
		block["state"] = "evaporating"
		block["evaporate_elapsed"] = 0.0
		block["visible_cells"] = (block.get("cells", []) as Array).size()


func _update_evaporating(block: Dictionary, delta: float, event_sink: Callable) -> void:
	var cells: Array = block.get("cells", [])
	if cells.is_empty():
		_blocks.erase(block)
		return
	var cell_size: float = float(block.get("cell_size", CELL_SIZE))
	var elapsed: float = float(block.get("evaporate_elapsed", 0.0)) + delta
	while elapsed >= EVAPORATE_CELL_INTERVAL_SEC and not cells.is_empty():
		elapsed -= EVAPORATE_CELL_INTERVAL_SEC
		var evaporated_cell: Vector2 = cells.pop_front()
		_emit_event(event_sink, {
			"type": EVENT_CELL_EVAPORATED,
			"origin": block.get("origin", Vector2.ZERO) + evaporated_cell * cell_size,
			"cells": [Vector2.ZERO],
			"color": get_block_color(block),
			"cell_size": cell_size,
		})
	block["cells"] = cells
	block["visible_cells"] = min(int(block.get("visible_cells", cells.size())), cells.size())
	block["evaporate_elapsed"] = elapsed
	if cells.is_empty():
		_blocks.erase(block)


func _emit_super_landed(block: Dictionary, event_sink: Callable) -> void:
	var cells: Array = block.get("cells", [])
	if cells.is_empty():
		_blocks.erase(block)
		return
	var origin: Vector2 = block.get("origin", Vector2.ZERO)
	var cell_size: float = float(block.get("cell_size", CELL_SIZE))
	_emit_event(event_sink, {
		"type": EVENT_SUPER_LANDED,
		"block": block,
		"center": _block_cells_center(origin, cells, cell_size),
	})
	_blocks.erase(block)


func _emit_event(event_sink: Callable, event: Dictionary) -> void:
	if event_sink.is_valid():
		event_sink.call(event)


func _fall_step_settle_result(block: Dictionary, origin: Vector2, next_origin: Vector2, settled_rects: Array) -> Dictionary:
	var cell_size: float = float(block.get("cell_size", CELL_SIZE))
	var bottom_now: float = -INF
	for cell in block["cells"]:
		bottom_now = maxf(bottom_now, origin.y + cell.y * cell_size + cell_size)
	for cell in block["cells"]:
		var rect := Rect2(next_origin + cell * cell_size, Vector2(cell_size, cell_size))
		if rect.position.y + rect.size.y >= FIELD_HEIGHT:
			var dy: float = maxf(0.0, FIELD_HEIGHT - bottom_now)
			return {"settle": true, "origin": origin + Vector2(0.0, dy)}
		for settled in settled_rects:
			if rect.intersects(settled):
				return {"settle": true, "origin": origin}
	return {"settle": false, "origin": next_origin}


func _advance_motion_budget(block: Dictionary, step_sec: float) -> void:
	block["drift_elapsed"] = float(block.get("drift_elapsed", 0.0)) + step_sec
	if int(block.get("rotate_times_remaining", 0)) > 0:
		block["rotate_timer_sec"] = float(block.get("rotate_timer_sec", 0.0)) + step_sec


func _try_step_drift(block: Dictionary, settled_rects: Array) -> void:
	var drift: int = int(block.get("drift_cells_remaining", 0))
	if drift == 0 or float(block.get("drift_elapsed", 0.0)) < float(block.get("drift_start_delay", 0.0)):
		return
	var cooldown: int = int(block.get("drift_cooldown_steps", 0))
	if cooldown > 0:
		block["drift_cooldown_steps"] = max(0, cooldown - 1)
		return
	var cell_size: float = float(block.get("cell_size", CELL_SIZE))
	var dx: float = -cell_size if drift < 0 else cell_size
	var next_origin: Vector2 = block["origin"] + Vector2(dx, 0.0)
	if _is_cell_layout_valid(next_origin, block["cells"], cell_size, settled_rects):
		block["origin"] = next_origin
		block["drift_cells_remaining"] = drift - (-1 if drift < 0 else 1)
		block["drift_cooldown_steps"] = 1
	else:
		block["drift_cells_remaining"] = 0


func _try_step_rotation(block: Dictionary, settled_rects: Array) -> void:
	var remaining: int = int(block.get("rotate_times_remaining", 0))
	if remaining <= 0 or float(block.get("drift_elapsed", 0.0)) < float(block.get("rotate_start_delay", 0.0)):
		return
	var timer: float = float(block.get("rotate_timer_sec", 0.0))
	var interval: float = maxf(0.001, float(block.get("rotate_interval_sec", ROTATE_INTERVAL_MIN_SEC)))
	if timer < interval:
		return
	var rotated: Dictionary = _rotate_cells_around_center(
		block["origin"],
		block["cells"],
		float(block.get("cell_size", CELL_SIZE)),
		int(block.get("rotate_dir", 1))
	)
	var next_origin: Vector2 = rotated.get("origin", block["origin"])
	var next_cells: Array = rotated.get("cells", block["cells"])
	if _is_cell_layout_valid(next_origin, next_cells, float(block.get("cell_size", CELL_SIZE)), settled_rects):
		block["origin"] = next_origin
		block["cells"] = next_cells
		block["rotate_times_remaining"] = remaining - 1
		block["rotate_interval_sec"] = _random_rotate_interval()
		block["rotate_dir"] = _random_rotate_dir()
		block["rotate_timer_sec"] = 0.0
	else:
		block["rotate_timer_sec"] = maxf(0.0, timer - interval * 0.5)


func _rotate_cells_around_center(origin: Vector2, cells: Array, cell_size: float, dir_sign: int) -> Dictionary:
	if cells.is_empty():
		return {"origin": origin, "cells": cells}
	var center := _block_cells_center(origin, cells, cell_size)
	var top_lefts: Array = []
	var min_pos := Vector2(INF, INF)
	for cell in cells:
		var cell_center: Vector2 = origin + cell * cell_size + Vector2(cell_size * 0.5, cell_size * 0.5)
		var offset: Vector2 = cell_center - center
		var rotated_offset := Vector2(offset.y, -offset.x) if dir_sign >= 0 else Vector2(-offset.y, offset.x)
		var top_left: Vector2 = center + rotated_offset - Vector2(cell_size * 0.5, cell_size * 0.5)
		top_left = Vector2(round(top_left.x), round(top_left.y))
		top_lefts.append(top_left)
		min_pos.x = minf(min_pos.x, top_left.x)
		min_pos.y = minf(min_pos.y, top_left.y)
	var rotated_cells: Array = []
	for top_left in top_lefts:
		rotated_cells.append(Vector2(
			round((top_left.x - min_pos.x) / cell_size),
			round((top_left.y - min_pos.y) / cell_size)
		))
	return {"origin": min_pos, "cells": rotated_cells}


func _is_cell_layout_valid(origin: Vector2, cells: Array, cell_size: float, settled_rects: Array) -> bool:
	for cell in cells:
		var rect := Rect2(origin + cell * cell_size, Vector2(cell_size, cell_size))
		if rect.position.x < 0.0 or rect.position.x + rect.size.x > FIELD_WIDTH:
			return false
		if rect.position.y < 0.0 or rect.position.y + rect.size.y > FIELD_HEIGHT:
			return false
		for settled in settled_rects:
			if rect.intersects(settled):
				return false
	return true


func _collect_settled_cell_rects() -> Array:
	var rects: Array = []
	for block in _blocks:
		if String(block.get("state", "")) != "settled":
			continue
		var origin: Vector2 = block["origin"]
		var cell_size: float = float(block.get("cell_size", CELL_SIZE))
		for cell in block["cells"]:
			rects.append(Rect2(origin + cell * cell_size, Vector2(cell_size, cell_size)))
	return rects


func _roll_drift_budget() -> int:
	if _rng.randf() >= DRIFT_CHANCE:
		return 0
	var choices := [-2, -1, 1, 2]
	return int(choices[_rng.randi_range(0, choices.size() - 1)])


func _roll_rotate_budget() -> int:
	if _rng.randf() >= ROTATE_CHANCE:
		return 0
	return _rng.randi_range(1, 2)


func _random_rotate_interval() -> float:
	return _rng.randf_range(ROTATE_INTERVAL_MIN_SEC, ROTATE_INTERVAL_MAX_SEC)


func _random_rotate_dir() -> int:
	return -1 if _rng.randf() < 0.5 else 1


func _boss_center_x_from_context(context: Dictionary) -> float:
	var boss_pos: Vector2 = context.get("boss_pos", Vector2(330.0, 25.0))
	var boss_size: Vector2 = context.get("boss_paddle_size", Vector2(100.0, 40.0))
	return boss_pos.x + boss_size.x * 0.5


func _block_cells_center(origin: Vector2, cells: Array, cell_size: float) -> Vector2:
	var center := Vector2.ZERO
	for cell in cells:
		center += origin + cell * cell_size + Vector2(cell_size * 0.5, cell_size * 0.5)
	return center / maxf(1.0, float(cells.size()))


func _rotate_cells(cells: Array, times: int) -> Array:
	var out: Array = cells.duplicate()
	for _i in range(posmod(times, 4)):
		var rotated: Array = []
		var min_x := INF
		var min_y := INF
		for cell in out:
			var rotated_cell := Vector2(-cell.y, cell.x)
			rotated.append(rotated_cell)
			min_x = minf(min_x, rotated_cell.x)
			min_y = minf(min_y, rotated_cell.y)
		for index in range(rotated.size()):
			rotated[index] = rotated[index] - Vector2(min_x, min_y)
		out = rotated
	return out


func _cells_dims(cells: Array) -> Vector2:
	var max_x := 0.0
	var max_y := 0.0
	for cell in cells:
		max_x = maxf(max_x, cell.x)
		max_y = maxf(max_y, cell.y)
	return Vector2(max_x + 1.0, max_y + 1.0)
