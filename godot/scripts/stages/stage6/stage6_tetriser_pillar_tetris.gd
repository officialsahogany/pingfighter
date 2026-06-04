extends RefCounted

# Stage 6 테트리서 self-playing pillar Tetris (visual deco).
#
# Faithful behavior port of pillar_tetriser.py TetrisGame + TetriserPillarBackground
# (auto-play: 40% left/right nudge, 25% rotate, 0.4s gravity, smooth visual
# fall interpolation, classic line clears, rainbow prism coloring, NEXT preview).
# The CrystalShieldSystem boss skill from the same Python file is intentionally
# NOT ported here (deferred follow-up).
#
# Placement difference vs Python: the original drew the boards inside the on-screen
# 80px pillars (game x=0..80 / 680..760). In the Godot port the playfield is the FULL
# 760-wide game canvas, so the Tetris wells live in the screen LETTERBOX margins
# (outside game_offset..game_offset+game_size) as a backdrop behind the pillar HUD.

# Layout / render constants (outer scope; used only by the renderer below).
const MIN_MARGIN_WIDTH := 52.0
const TARGET_COLUMNS := 6
const BLOCK_MIN := 14.0
const BLOCK_MAX := 30.0
const INSET := 6.0
const STACK_ALPHA := 0.5
const FALLING_ALPHA := 0.82
const NEXT_ALPHA := 0.7
const LOD_THRESHOLD := 0.45


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
				board[cell.y][cell.x] = true
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
		for y in sorted_lines:
			board.remove_at(y)
			board.insert(0, _empty_row())
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
	var block := clampf(margin_w / float(TARGET_COLUMNS), BLOCK_MIN, BLOCK_MAX)
	var game_cols := maxi(4, int((margin_w - INSET * 2.0) / block))
	var game_rows := maxi(8, int(margin_h / block))
	if game.is_ready and game.cols == game_cols and game.rows == game_rows:
		return
	game.setup(game_cols, game_rows, block, seed_value)


func _draw_game(canvas: CanvasItem, game: PillarTetrisGame, margin_x: float, margin_w: float, margin_h: float) -> void:
	if not game.is_ready:
		return
	var block := game.block_size
	var board_w := float(game.cols) * block
	var origin_x := margin_x + (margin_w - board_w) * 0.5
	var origin_y := minf(0.0, margin_h - float(game.rows) * block)   # anchor well to pillar bottom

	for y in range(game.rows):
		for x in range(game.cols):
			if game.board[y][x] == null:
				continue
			var flashing: bool = game.clearing_lines.has(y)
			_draw_cell(canvas, game, origin_x, origin_y, x, y, STACK_ALPHA, flashing)
	if not game.current.is_empty() and game.clearing_lines.is_empty():
		var visual_drop := game.get_visual_drop_offset()
		for cell in game.cells(game.current):
			var cell_top := origin_y + float(cell.y) * block + visual_drop
			if cell_top > -block and cell_top < margin_h:
				_draw_cell(canvas, game, origin_x, origin_y, cell.x, cell.y, FALLING_ALPHA, false, visual_drop)
	_draw_next_preview(canvas, game, margin_x, margin_w)


func _draw_cell(
	canvas: CanvasItem,
	game: PillarTetrisGame,
	origin_x: float,
	origin_y: float,
	gx: int,
	gy: int,
	alpha: float,
	flashing: bool,
	visual_y_offset: float = 0.0
) -> void:
	var block := game.block_size
	var rect := Rect2(origin_x + float(gx) * block, origin_y + float(gy) * block + visual_y_offset, block - 1.0, block - 1.0)
	var color: Color
	if flashing:
		var flash := clampf(game.clear_timer / PillarTetrisGame.CLEAR_DURATION, 0.0, 1.0)
		color = Color(1.0, 1.0, 1.0, alpha * (0.4 + 0.6 * flash))
	else:
		var hue := fmod(float(gx) * 0.3 + float(gy) * 0.2 + game.rainbow_time * 0.5, 1.0)
		color = Color.from_hsv(hue, 0.6, 1.0, alpha)
	canvas.draw_rect(rect, color)
	canvas.draw_rect(rect, Color(color.r, color.g, color.b, minf(1.0, alpha + 0.25)), false, 1.0)


func _draw_next_preview(canvas: CanvasItem, game: PillarTetrisGame, margin_x: float, margin_w: float) -> void:
	if game.next_type == "":
		return
	var shape: Array = PillarTetrisGame.TETROMINOS[game.next_type][0]
	var mini_size := clampf(game.block_size * 0.55, 8.0, 16.0)
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
	var start_y := 14.0
	var hue_base := fmod(game.rainbow_time * 0.5, 1.0)
	for cell in shape:
		var px := start_x + float(cell.x - min_x) * mini_size
		var py := start_y + float(cell.y - min_y) * mini_size
		var hue := fmod(hue_base + float(cell.x) * 0.2 + float(cell.y) * 0.15, 1.0)
		canvas.draw_rect(Rect2(px, py, mini_size - 1.0, mini_size - 1.0), Color.from_hsv(hue, 0.7, 1.0, NEXT_ALPHA))


func _consume_dt() -> float:
	var now := Time.get_ticks_msec()
	if _last_msec <= 0:
		_last_msec = now
		return 1.0 / 60.0
	var dt := clampf(float(now - _last_msec) / 1000.0, 0.0, 0.1)
	_last_msec = now
	return dt
