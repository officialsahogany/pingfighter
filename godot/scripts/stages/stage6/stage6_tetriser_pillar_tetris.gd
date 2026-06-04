extends RefCounted

# Stage 6 Tetriser self-playing pillar arcade wells.
#
# Ringpia remaster of the old Tetris side-board feeling: NEXT signs, black wells,
# beveled stone frames, bottom score plinths, and classic tetromino colors.
# The CrystalShieldSystem boss skill from pillar_tetriser.py is intentionally not
# ported here (deferred follow-up).
#
# Placement difference vs Python: the original drew the boards inside the on-screen
# 80px pillars (game x=0..80 / 680..760). In the Godot port the playfield is the FULL
# 760-wide game canvas, so the Tetris wells live in the screen LETTERBOX margins
# (outside game_offset..game_offset+game_size) as a backdrop behind the pillar HUD.

# Layout / render constants (outer scope; used only by the renderer below).
const MIN_MARGIN_WIDTH := 72.0
const TARGET_COLUMNS := 10
const TARGET_ROWS := 20
const BLOCK_MIN := 9.0
const BLOCK_MAX := 40.0
const INSET := 18.0
const TOP_RESERVED := 92.0
const BOTTOM_RESERVED := 132.0
const STACK_ALPHA := 0.64
const FALLING_ALPHA := 0.94
const NEXT_ALPHA := 0.88
const LOD_THRESHOLD := 0.45

const WELL_BG := Color(0.0, 0.0, 0.0, 0.96)
const STONE := Color(0.56, 0.56, 0.68, 1.0)
const STONE_DARK := Color(0.22, 0.22, 0.38, 1.0)
const STONE_LIGHT := Color(0.78, 0.80, 0.92, 1.0)
const PURPLE_EDGE := Color(0.36, 0.32, 0.82, 1.0)
const PANEL_BG := Color(0.08, 0.08, 0.26, 0.96)
const RING_CYAN := Color(0.04, 0.84, 1.0, 1.0)
const RING_GOLD := Color(1.0, 0.68, 0.14, 1.0)
const CLASSIC_COLORS := {
	"I": Color(0.12, 0.74, 0.92, 1.0),
	"O": Color(0.98, 0.78, 0.16, 1.0),
	"T": Color(0.62, 0.28, 0.92, 1.0),
	"S": Color(0.18, 0.78, 0.30, 1.0),
	"Z": Color(0.92, 0.16, 0.22, 1.0),
	"J": Color(0.18, 0.36, 0.92, 1.0),
	"L": Color(0.95, 0.50, 0.12, 1.0),
}


# One self-playing well. Game-logic constants live here so the inner class can
# reference them by bare name (GDScript inner classes cannot see outer-scope consts).
class PillarTetrisGame:
	extends RefCounted

	const FALL_SPEED := 0.4
	const MOVE_DELAY := 0.2
	const ROTATE_DELAY := 0.4
	const CLEAR_DURATION := 0.3
	const MOVE_CHANCE := 0.4
	const ROTATE_CHANCE := 0.25
	const PIECE_TYPES := ["I", "O", "T", "S", "Z", "J", "L"]
	const TETROMINOS := {
		"I": [
			[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)],
			[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)],
			[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)],
			[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)],
		],
		"O": [
			[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
			[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
			[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
			[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
		],
		"T": [
			[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)],
			[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2)],
			[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
			[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2)],
		],
		"S": [
			[Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)],
			[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2)],
			[Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)],
			[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2)],
		],
		"Z": [
			[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)],
			[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2)],
			[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)],
			[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2)],
		],
		"J": [
			[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
			[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, 2)],
			[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1)],
			[Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 2), Vector2i(1, 2)],
		],
		"L": [
			[Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
			[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)],
			[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1)],
			[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2)],
		],
	}

	var cols := 0
	var rows := 0
	var block_size := 18.0
	var board: Array = []          # rows of (true or null)
	var current: Dictionary = {}
	var next_type := "T"
	var fall_timer := 0.0
	var move_timer := 0.0
	var rotate_timer := 0.0
	var clear_timer := 0.0
	var clearing_lines: Array = []
	var rainbow_time := 0.0
	var score := 0
	var lines_cleared := 0
	var rng := RandomNumberGenerator.new()
	var is_ready := false

	func setup(p_cols: int, p_rows: int, p_block: float, p_seed: int) -> void:
		cols = maxi(4, p_cols)
		rows = maxi(8, p_rows)
		block_size = p_block
		rng.seed = p_seed
		board = []
		for _y in range(rows):
			board.append(_empty_row())
		clearing_lines = []
		clear_timer = 0.0
		next_type = PIECE_TYPES[rng.randi_range(0, PIECE_TYPES.size() - 1)]
		_spawn()
		is_ready = true

	func _empty_row() -> Array:
		var row: Array = []
		for _x in range(cols):
			row.append(null)
		return row

	func _spawn() -> void:
		var piece_type := next_type
		next_type = PIECE_TYPES[rng.randi_range(0, PIECE_TYPES.size() - 1)]
		current = {
			"type": piece_type,
			"rotation": 0,
			"x": rng.randi_range(0, maxi(0, cols - 4)),
			"y": -2,
		}

	func cells(piece: Dictionary) -> Array:
		var rot: int = int(piece.get("rotation", 0)) % 4
		var shape: Array = TETROMINOS[piece.get("type", "T")][rot]
		var out: Array = []
		var px: int = int(piece.get("x", 0))
		var py: int = int(piece.get("y", 0))
		for cell in shape:
			out.append(Vector2i(px + cell.x, py + cell.y))
		return out

	func _valid(piece: Dictionary, dx: int, dy: int, dr: int) -> bool:
		var test := {
			"type": piece.get("type", "T"),
			"rotation": (int(piece.get("rotation", 0)) + dr) % 4,
			"x": int(piece.get("x", 0)) + dx,
			"y": int(piece.get("y", 0)) + dy,
		}
		for cell in cells(test):
			if cell.x < 0 or cell.x >= cols:
				return false
			if cell.y >= rows:
				return false
			if cell.y >= 0 and board[cell.y][cell.x] != null:
				return false
		return true

	func _lock() -> void:
		if current.is_empty():
			return
		for cell in cells(current):
			if cell.y >= 0 and cell.y < rows and cell.x >= 0 and cell.x < cols:
				board[cell.y][cell.x] = str(current.get("type", "T"))
		_check_lines()
		# Top-out reset keeps the decorative well perpetually playing.
		if _top_filled():
			_reset_board()
			return
		_spawn()

	func _top_filled() -> bool:
		for x in range(cols):
			if board[0][x] != null:
				return true
		return false

	func _reset_board() -> void:
		for y in range(rows):
			for x in range(cols):
				board[y][x] = null
		clearing_lines = []
		clear_timer = 0.0
		score = 0
		lines_cleared = 0
		_spawn()

	func _check_lines() -> void:
		clearing_lines = []
		for y in range(rows):
			var full := true
			for x in range(cols):
				if board[y][x] == null:
					full = false
					break
			if full:
				clearing_lines.append(y)
		if not clearing_lines.is_empty():
			clear_timer = CLEAR_DURATION

	func _clear_lines() -> void:
		var sorted_lines: Array = clearing_lines.duplicate()
		sorted_lines.sort()
		sorted_lines.reverse()
		var cleared_count := sorted_lines.size()
		for y in sorted_lines:
			board.remove_at(y)
			board.insert(0, _empty_row())
		lines_cleared += cleared_count
		score += [0, 100, 300, 500, 800][clampi(cleared_count, 0, 4)]
		clearing_lines = []

	func update(dt: float) -> void:
		if not is_ready:
			return
		rainbow_time += dt
		if not clearing_lines.is_empty():
			clear_timer -= dt
			if clear_timer <= 0.0:
				_clear_lines()
			return
		if current.is_empty():
			_spawn()
			return
		move_timer += dt
		if move_timer >= MOVE_DELAY:
			move_timer = 0.0
			if rng.randf() < MOVE_CHANCE:
				var dir := 1 if rng.randf() < 0.5 else -1
				if _valid(current, dir, 0, 0):
					current["x"] = int(current["x"]) + dir
		rotate_timer += dt
		if rotate_timer >= ROTATE_DELAY:
			rotate_timer = 0.0
			if rng.randf() < ROTATE_CHANCE and _valid(current, 0, 0, 1):
				current["rotation"] = (int(current["rotation"]) + 1) % 4
		fall_timer += dt
		if fall_timer >= FALL_SPEED:
			fall_timer = 0.0
			if _valid(current, 0, 1, 0):
				current["y"] = int(current["y"]) + 1
			else:
				_lock()

	func get_visual_drop_offset() -> float:
		if current.is_empty() or not clearing_lines.is_empty():
			return 0.0
		if not _valid(current, 0, 1, 0):
			return 0.0
		var progress := clampf(fall_timer / FALL_SPEED, 0.0, 0.98)
		return progress * block_size


var _left := PillarTetrisGame.new()
var _right := PillarTetrisGame.new()
var _last_msec := 0


func prewarm_assets() -> void:
	pass


func prewarm_assets_step() -> bool:
	return true


func reset() -> void:
	_left = PillarTetrisGame.new()
	_right = PillarTetrisGame.new()
	_last_msec = 0


func draw(
	canvas: CanvasItem,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	quality_scale: float = 1.0
) -> void:
	if canvas == null:
		return
	if view_size.x <= 0.0 or game_size.x <= 0.0:
		return
	if quality_scale <= LOD_THRESHOLD:
		return   # drop the decorative pillar Tetris only under severe LOD
	var dt := _consume_dt()

	var left_w := game_offset.x
	var right_x := game_offset.x + game_size.x
	var right_w := view_size.x - right_x

	if left_w >= MIN_MARGIN_WIDTH:
		_ensure_game(_left, left_w, view_size.y, 12345)
		_left.update(dt)
		_draw_game(canvas, _left, 0.0, left_w, view_size.y)
	if right_w >= MIN_MARGIN_WIDTH:
		_ensure_game(_right, right_w, view_size.y, 67890)
		_right.update(dt)
		_draw_game(canvas, _right, right_x, right_w, view_size.y)


func _ensure_game(game: PillarTetrisGame, margin_w: float, margin_h: float, seed_value: int) -> void:
	var available_h := maxf(240.0, margin_h - TOP_RESERVED - BOTTOM_RESERVED)
	var block := clampf(minf((margin_w - INSET * 4.0) / float(TARGET_COLUMNS), available_h / float(TARGET_ROWS)), BLOCK_MIN, BLOCK_MAX)
	var game_cols := TARGET_COLUMNS
	var game_rows := TARGET_ROWS
	if game.is_ready and game.cols == game_cols and game.rows == game_rows:
		return
	game.setup(game_cols, game_rows, block, seed_value)


func _draw_game(canvas: CanvasItem, game: PillarTetrisGame, margin_x: float, margin_w: float, margin_h: float) -> void:
	if not game.is_ready:
		return
	var block := game.block_size
	var board_w := float(game.cols) * block
	var board_h := float(game.rows) * block
	var origin_x := margin_x + (margin_w - board_w) * 0.5
	var origin_y := clampf(TOP_RESERVED, 42.0, maxf(42.0, margin_h - board_h - BOTTOM_RESERVED))
	var well_rect := Rect2(Vector2(origin_x, origin_y), Vector2(board_w, board_h))

	_draw_well_shell(canvas, well_rect, margin_x, margin_w, margin_h, game)
	for y in range(game.rows):
		for x in range(game.cols):
			if game.board[y][x] == null:
				continue
			var flashing: bool = game.clearing_lines.has(y)
			_draw_cell(canvas, game, origin_x, origin_y, x, y, STACK_ALPHA, flashing, 0.0, str(game.board[y][x]))
	if not game.current.is_empty() and game.clearing_lines.is_empty():
		var visual_drop := game.get_visual_drop_offset()
		for cell in game.cells(game.current):
			var cell_top := origin_y + float(cell.y) * block + visual_drop
			if cell_top > -block and cell_top < margin_h:
				_draw_cell(canvas, game, origin_x, origin_y, cell.x, cell.y, FALLING_ALPHA, false, visual_drop, str(game.current.get("type", "T")))
	_draw_next_preview(canvas, game, margin_x, margin_w, well_rect)
	_draw_score_plinth(canvas, game, margin_x, margin_w, margin_h, well_rect)


func _draw_cell(
	canvas: CanvasItem,
	game: PillarTetrisGame,
	origin_x: float,
	origin_y: float,
	gx: int,
	gy: int,
	alpha: float,
	flashing: bool,
	visual_y_offset: float = 0.0,
	piece_type: String = "T"
) -> void:
	var block := game.block_size
	var rect := Rect2(origin_x + float(gx) * block, origin_y + float(gy) * block + visual_y_offset, block - 1.0, block - 1.0)
	var color: Color
	if flashing:
		var flash := clampf(game.clear_timer / PillarTetrisGame.CLEAR_DURATION, 0.0, 1.0)
		color = Color(1.0, 1.0, 1.0, alpha * (0.4 + 0.6 * flash))
	else:
		color = _piece_color(piece_type, alpha, game.rainbow_time, gx, gy)
	canvas.draw_rect(rect, color)
	var highlight := Rect2(rect.position, Vector2(rect.size.x, maxf(1.0, rect.size.y * 0.20)))
	canvas.draw_rect(highlight, Color(1.0, 1.0, 1.0, alpha * 0.23))
	canvas.draw_rect(rect, Color(0.0, 0.0, 0.0, 0.34), false, 1.0)


func _draw_next_preview(canvas: CanvasItem, game: PillarTetrisGame, margin_x: float, margin_w: float, well_rect: Rect2) -> void:
	if game.next_type == "":
		return
	var shape: Array = PillarTetrisGame.TETROMINOS[game.next_type][0]
	var mini_size := clampf(game.block_size * 0.62, 9.0, 20.0)
	var min_x := 99
	var min_y := 99
	var max_x := -99
	var max_y := -99
	for cell in shape:
		min_x = mini(min_x, cell.x)
		min_y = mini(min_y, cell.y)
		max_x = maxi(max_x, cell.x)
		max_y = maxi(max_y, cell.y)
	var preview_w := float(max_x - min_x + 1) * mini_size
	var start_x := margin_x + (margin_w - preview_w) * 0.5
	var label_y := maxf(22.0, well_rect.position.y - 43.0)
	var start_y := label_y + 9.0
	var font: Font = ThemeDB.fallback_font
	if font != null:
		var label_color: Color = Color(1.0, 0.10, 0.16, 0.96) if margin_x <= 0.0 else Color(0.72, 0.66, 1.0, 0.96)
		canvas.draw_string(font, Vector2(margin_x + maxf(4.0, margin_w * 0.08), label_y), "NEXT", HORIZONTAL_ALIGNMENT_LEFT, margin_w, 16, label_color)
	for cell in shape:
		var px := start_x + float(cell.x - min_x) * mini_size
		var py := start_y + float(cell.y - min_y) * mini_size
		var color: Color = _piece_color(game.next_type, NEXT_ALPHA, game.rainbow_time, cell.x, cell.y)
		canvas.draw_rect(Rect2(px, py, mini_size - 1.0, mini_size - 1.0), color)
		canvas.draw_rect(Rect2(px, py, mini_size - 1.0, mini_size - 1.0), Color(0.0, 0.0, 0.0, 0.28), false, 1.0)


func _draw_well_shell(canvas: CanvasItem, well_rect: Rect2, margin_x: float, margin_w: float, margin_h: float, game: PillarTetrisGame) -> void:
	var shell := well_rect.grow(13.0)
	canvas.draw_rect(shell.grow(6.0), Color(0.0, 0.0, 0.0, 0.78))
	canvas.draw_rect(shell, STONE_DARK)
	canvas.draw_rect(shell.grow(-4.0), STONE)
	canvas.draw_rect(well_rect.grow(4.0), PURPLE_EDGE, false, 4.0, true)
	canvas.draw_rect(well_rect, WELL_BG)
	var inner_line := Color(0.78, 0.78, 1.0, 0.42)
	canvas.draw_line(well_rect.position, Vector2(well_rect.end.x, well_rect.position.y), inner_line, 2.0, true)
	canvas.draw_line(well_rect.position, Vector2(well_rect.position.x, well_rect.end.y), inner_line, 2.0, true)
	var cell_gap := game.block_size
	var grid_color := Color(0.18, 0.25, 0.55, 0.12)
	for x in range(1, game.cols):
		var gx := well_rect.position.x + float(x) * cell_gap
		canvas.draw_line(Vector2(gx, well_rect.position.y), Vector2(gx, well_rect.end.y), grid_color, 1.0, true)
	for y in range(1, game.rows):
		var gy := well_rect.position.y + float(y) * cell_gap
		canvas.draw_line(Vector2(well_rect.position.x, gy), Vector2(well_rect.end.x, gy), grid_color, 1.0, true)
	_draw_side_stats_hint(canvas, margin_x, margin_w, margin_h, well_rect)


func _draw_side_stats_hint(canvas: CanvasItem, margin_x: float, margin_w: float, _margin_h: float, well_rect: Rect2) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null or margin_w < 130.0:
		return
	var label: String = "STATS"
	var label_x: float = margin_x + margin_w * 0.5 - 28.0
	var label_y: float = well_rect.position.y + well_rect.size.y * 0.34
	canvas.draw_string(font, Vector2(label_x + 1.0, label_y + 1.0), label, HORIZONTAL_ALIGNMENT_LEFT, 90.0, 14, Color(0.0, 0.0, 0.0, 0.65))
	canvas.draw_string(font, Vector2(label_x, label_y), label, HORIZONTAL_ALIGNMENT_LEFT, 90.0, 14, Color(0.90, 0.92, 1.0, 0.55))


func _draw_score_plinth(canvas: CanvasItem, game: PillarTetrisGame, margin_x: float, margin_w: float, margin_h: float, well_rect: Rect2) -> void:
	var plinth_h := clampf(BOTTOM_RESERVED - 18.0, 90.0, 118.0)
	var plinth_w := minf(maxf(well_rect.size.x + 44.0, margin_w * 0.90), margin_w - 14.0)
	var rect := Rect2(Vector2(margin_x + (margin_w - plinth_w) * 0.5, margin_h - plinth_h - 10.0), Vector2(plinth_w, plinth_h))
	canvas.draw_rect(rect.grow(5.0), Color(0.0, 0.0, 0.0, 0.72))
	canvas.draw_rect(rect, PANEL_BG)
	canvas.draw_rect(rect, PURPLE_EDGE, false, 2.0, true)
	canvas.draw_line(rect.position, Vector2(rect.end.x, rect.position.y), STONE_LIGHT, 1.0, true)
	var stripe_w := maxf(5.0, rect.size.x * 0.045)
	canvas.draw_rect(Rect2(rect.position + Vector2(6.0, 7.0), Vector2(stripe_w, rect.size.y - 14.0)), Color(0.95, 0.08, 0.10, 0.88))
	var font: Font = ThemeDB.fallback_font
	if font != null:
		var x: float = rect.position.x + stripe_w + 13.0
		var y: float = rect.position.y + 21.0
		canvas.draw_string(font, Vector2(x, y), "SCORE %d" % int(game.score), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, 14, Color(1.0, 0.16, 0.18, 0.94))
		canvas.draw_string(font, Vector2(x, y + 21.0), "LINES %d" % int(game.lines_cleared), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, 14, Color(0.72, 0.78, 1.0, 0.92))
		canvas.draw_string(font, Vector2(x, y + 42.0), "RINGPIA 6", HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, 13, Color(RING_CYAN.r, RING_CYAN.g, RING_CYAN.b, 0.86))
	var ring_center := rect.position + Vector2(rect.size.x - 22.0, rect.size.y - 20.0)
	canvas.draw_arc(ring_center, 16.0, _time_phase(game) * 0.7, _time_phase(game) * 0.7 + PI * 1.4, 28, Color(RING_CYAN.r, RING_CYAN.g, RING_CYAN.b, 0.58), 2.0, true)
	canvas.draw_arc(ring_center, 10.0, -_time_phase(game), -_time_phase(game) + PI * 1.2, 24, Color(RING_GOLD.r, RING_GOLD.g, RING_GOLD.b, 0.46), 2.0, true)


func _piece_color(piece_type: String, alpha: float, rainbow_time: float, gx: int, gy: int) -> Color:
	var base: Color = Color(0.58, 0.64, 1.0, 1.0)
	if CLASSIC_COLORS.has(piece_type):
		base = CLASSIC_COLORS[piece_type]
	var pulse := 0.92 + 0.08 * sin(rainbow_time * 4.0 + float(gx) * 0.7 + float(gy) * 0.33)
	return Color(base.r * pulse, base.g * pulse, base.b * pulse, alpha)


func _time_phase(game: PillarTetrisGame) -> float:
	return game.rainbow_time


func _consume_dt() -> float:
	var now := Time.get_ticks_msec()
	if _last_msec <= 0:
		_last_msec = now
		return 1.0 / 60.0
	var dt := clampf(float(now - _last_msec) / 1000.0, 0.0, 0.1)
	_last_msec = now
	return dt
