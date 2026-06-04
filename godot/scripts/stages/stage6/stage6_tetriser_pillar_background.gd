extends RefCounted

# Stage 6 테트리서 pillar background.
#
# Faithful procedural port of Python backgrounds/animated_background_stage7.py
# (AnimatedBackgroundStage7) — the atmospheric "테트리스 아레나 / 요새 내부"
# overlay: 4 pulsing torch glows, a sweeping light band, drifting light motes,
# and a blue-purple arena border frame.
#
# The central pseudo-3D cube from the Python class is NOT drawn here: in the
# Godot port the cube is a gameplay object owned by stage6_tetriser_state.gd
# and rendered by stage6_tetriser_playfield_renderer.gd (_draw_cube). Drawing
# it here too would double it.
#
# Coordinate convention matches the stage5 홍련 background sibling: the canvas
# is screen-pixel space, view_size is the full screen, game_offset/game_size
# describe the game canvas region. Python logical coords (760x750 Godot canvas)
# map via to_screen(p) = game_offset + (p / LOGICAL) * game_size.

const LOGICAL := Vector2(760.0, 750.0)

const BG_COLOR := Color(0.07, 0.10, 0.18, 1.0)
const PILLAR_TINT := Color(0.03, 0.045, 0.085, 1.0)

# Torch centers in logical space (Python torch_positions, remapped to 760-wide).
const TORCH_POSITIONS: Array[Vector2] = [
	Vector2(96.0, 176.0),
	Vector2(664.0, 176.0),
	Vector2(96.0, 530.0),
	Vector2(664.0, 530.0),
]
const TORCH_BLUE := Color(120.0 / 255.0, 200.0 / 255.0, 1.0, 1.0)
const TORCH_WARM := Color(1.0, 180.0 / 255.0, 120.0 / 255.0, 1.0)
const TORCH_CORE := Color(1.0, 236.0 / 255.0, 200.0 / 255.0, 1.0)

# Sweeping light band (Python prerendered 200x180 gradient).
const BAND_LOGICAL_SIZE := Vector2(200.0, 180.0)
const BAND_TEX_WIDTH := 192
const BAND_SWEEP_SPEED := 120.0   # logical px/sec (Python time*120)

const MOTE_COUNT := 12
const MOTE_COLOR := Color(170.0 / 255.0, 220.0 / 255.0, 1.0, 1.0)

# Arena border frame (Python _draw_border).
const BORDER_THICKNESS := 10.0
const BORDER_BASE := Color(40.0 / 255.0, 50.0 / 255.0, 80.0 / 255.0, 1.0)
const BORDER_INNER := Color(60.0 / 255.0, 80.0 / 255.0, 120.0 / 255.0, 1.0)
const BORDER_GLOW := Color(120.0 / 255.0, 170.0 / 255.0, 1.0, 1.0)

const LOD_THRESHOLD := 0.7
const SEVERE_LOD_THRESHOLD := 0.6

var _time := 0.0
var _last_draw_msec := 0
var _motes: Array = []
var _band_texture: Texture2D = null
var _ready := false


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	if _ready:
		return true
	_build_motes()
	_band_texture = _build_band_texture()
	_ready = true
	return true


func reset() -> void:
	_time = 0.0
	_last_draw_msec = 0
	_motes.clear()
	_ready = false


func update(_delta: float, _context: Dictionary = {}, _deps: Dictionary = {}) -> void:
	# Time + motes advance via _consume_draw_delta() in draw() so this stays a
	# no-op (advancing here too would double the animation rate).
	pass


func draw(
	canvas: CanvasItem,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	_field_width: float,
	_perf_logger: Object = null,
	quality_scale: float = 1.0
) -> bool:
	if canvas == null:
		return false
	_ensure_ready()
	var dt := _consume_draw_delta()
	_time += dt
	_advance_motes(dt)

	var target_size := view_size
	if target_size.x <= 0.0 or target_size.y <= 0.0:
		target_size = game_offset * 2.0 + game_size
	if target_size.x <= 0.0 or target_size.y <= 0.0:
		target_size = LOGICAL
	if game_size.x <= 0.0 or game_size.y <= 0.0:
		game_offset = Vector2.ZERO
		game_size = target_size

	# Base fill (full screen) + subtle letterbox darkening for arena separation.
	canvas.draw_rect(Rect2(Vector2.ZERO, target_size), BG_COLOR)
	_draw_pillar_tint(canvas, target_size, game_offset, game_size)

	var s := game_size.x / LOGICAL.x   # uniform scale for radii / sizes
	var severe := quality_scale <= SEVERE_LOD_THRESHOLD
	var low := quality_scale <= LOD_THRESHOLD

	_draw_torches(canvas, game_offset, game_size, s, low)
	_draw_light_band(canvas, game_offset, game_size)
	if not severe:
		_draw_motes(canvas, game_offset, game_size, s)
	_draw_border(canvas, game_offset, game_size, s)
	return true


func draw_pillar_background_overlay(
	_canvas: CanvasItem,
	_view_size: Vector2,
	_game_offset: Vector2,
	_game_size: Vector2,
	_field_width: float,
	_perf_logger: Object = null,
	_quality_scale: float = 1.0
) -> void:
	pass


# ------------------------------------------------------------------
# atmosphere layers
# ------------------------------------------------------------------
func _draw_pillar_tint(canvas: CanvasItem, target_size: Vector2, game_offset: Vector2, game_size: Vector2) -> void:
	var left_w := maxf(0.0, game_offset.x)
	if left_w > 0.0:
		canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(left_w, target_size.y)), PILLAR_TINT)
	var right_x := game_offset.x + game_size.x
	var right_w := maxf(0.0, target_size.x - right_x)
	if right_w > 0.0:
		canvas.draw_rect(Rect2(Vector2(right_x, 0.0), Vector2(right_w, target_size.y)), PILLAR_TINT)


func _draw_torches(canvas: CanvasItem, game_offset: Vector2, game_size: Vector2, s: float, low: bool) -> void:
	for index in range(TORCH_POSITIONS.size()):
		var logical: Vector2 = TORCH_POSITIONS[index]
		var pos := _to_screen(logical, game_offset, game_size)
		var wobble := 0.4 + 0.3 * sin(_time * 6.0 + float(index) * 1.7)
		var base_radius := (28.0 + 2.0 * sin(_time * 4.3 + float(index))) * s
		# Two prismatic layers (blue then warm), Python prism_palette.
		for layer in range(2):
			var color := TORCH_BLUE if layer == 0 else TORCH_WARM
			var layer_radius := base_radius * (1.0 + float(layer) * 0.35)
			var alpha := (70.0 + 35.0 * wobble - float(layer) * 12.0) / 255.0
			if alpha > 0.0:
				canvas.draw_circle(pos + Vector2(0.0, -4.0 * s), layer_radius, Color(color.r, color.g, color.b, alpha))
		# Warm core.
		var core_alpha := (180.0 + 50.0 * wobble) / 255.0
		canvas.draw_circle(pos + Vector2(0.0, -6.0 * s), 14.0 * s, Color(TORCH_CORE.r, TORCH_CORE.g, TORCH_CORE.b, core_alpha))
		# Halo ring only when bright (and skip under LOD).
		if not low and wobble > 0.5:
			var halo_radius := base_radius * 1.8
			var halo_alpha := (50.0 + 40.0 * wobble) / 255.0
			canvas.draw_arc(pos + Vector2(0.0, -6.0 * s), halo_radius, 0.0, TAU, 28, Color(TORCH_BLUE.r, TORCH_BLUE.g, TORCH_BLUE.b, halo_alpha), 2.0 * s, true)


func _draw_light_band(canvas: CanvasItem, game_offset: Vector2, game_size: Vector2) -> void:
	if _band_texture == null:
		return
	var span := LOGICAL.x + BAND_LOGICAL_SIZE.x
	var sweep := fmod(_time * BAND_SWEEP_SPEED, span) - BAND_LOGICAL_SIZE.x
	var band_top := LOGICAL.y * 0.5 - BAND_LOGICAL_SIZE.y * 0.5
	var screen_pos := _to_screen(Vector2(sweep, band_top), game_offset, game_size)
	var scale := game_size / LOGICAL
	var screen_size := Vector2(BAND_LOGICAL_SIZE.x * scale.x, BAND_LOGICAL_SIZE.y * scale.y)
	canvas.draw_texture_rect(_band_texture, Rect2(screen_pos, screen_size), false, Color(1.0, 1.0, 1.0, 0.85))


func _draw_motes(canvas: CanvasItem, game_offset: Vector2, game_size: Vector2, s: float) -> void:
	for mote in _motes:
		var wobble := sin(_time * 3.0 + float(mote.get("phase", 0.0)))
		var radius := (float(mote.get("radius", 3.0)) + wobble * 0.4) * s
		var alpha := (80.0 + 40.0 * wobble) / 255.0
		var pos := _to_screen(Vector2(float(mote.get("x", 0.0)), float(mote.get("y", 0.0))), game_offset, game_size)
		canvas.draw_circle(pos, maxf(1.0, radius), Color(MOTE_COLOR.r, MOTE_COLOR.g, MOTE_COLOR.b, alpha))


func _draw_border(canvas: CanvasItem, game_offset: Vector2, game_size: Vector2, s: float) -> void:
	var t := BORDER_THICKNESS * s
	var origin := game_offset
	var size := game_size
	# Main frame (top / bottom / left / right).
	canvas.draw_rect(Rect2(origin, Vector2(size.x, t)), BORDER_BASE)
	canvas.draw_rect(Rect2(origin + Vector2(0.0, size.y - t), Vector2(size.x, t)), BORDER_BASE)
	canvas.draw_rect(Rect2(origin, Vector2(t, size.y)), BORDER_BASE)
	canvas.draw_rect(Rect2(origin + Vector2(size.x - t, 0.0), Vector2(t, size.y)), BORDER_BASE)
	# Inner highlight lines (depth).
	var it := maxf(1.0, 2.0 * s)
	canvas.draw_rect(Rect2(origin + Vector2(t, t), Vector2(size.x - 2.0 * t, it)), BORDER_INNER)
	canvas.draw_rect(Rect2(origin + Vector2(t, size.y - t - it), Vector2(size.x - 2.0 * t, it)), BORDER_INNER)
	canvas.draw_rect(Rect2(origin + Vector2(t, t), Vector2(it, size.y - 2.0 * t)), BORDER_INNER)
	canvas.draw_rect(Rect2(origin + Vector2(size.x - t - it, t), Vector2(it, size.y - 2.0 * t)), BORDER_INNER)
	# Corner glow accents.
	var cr := 5.0 * s
	canvas.draw_circle(origin + Vector2(t * 0.5, t * 0.5), cr, BORDER_GLOW)
	canvas.draw_circle(origin + Vector2(size.x - t * 0.5, t * 0.5), cr, BORDER_GLOW)
	canvas.draw_circle(origin + Vector2(t * 0.5, size.y - t * 0.5), cr, BORDER_GLOW)
	canvas.draw_circle(origin + Vector2(size.x - t * 0.5, size.y - t * 0.5), cr, BORDER_GLOW)


# ------------------------------------------------------------------
# setup / helpers
# ------------------------------------------------------------------
func _ensure_ready() -> void:
	if not _ready:
		prewarm_assets()


func _build_motes() -> void:
	# Deterministic spread (no RNG) so motion is reproducible across runs/tests.
	_motes.clear()
	for i in range(MOTE_COUNT):
		var fi := float(i)
		_motes.append({
			"x": 140.0 + fmod(fi * 71.0, 480.0),
			"y": 285.0 + fmod(fi * 53.0, 200.0),
			"speed": 12.0 + fmod(fi * 7.0, 14.0),
			"phase": fmod(fi * 1.7, TAU),
			"radius": 2.0 + fmod(fi * 1.3, 2.0),
		})


func _build_band_texture() -> Texture2D:
	# Horizontal symmetric falloff (Python: alpha = 70 * intensity^1.8, blue).
	# Built once at prewarm; a 1-row image stretched vertically at draw time.
	var image := Image.create(BAND_TEX_WIDTH, 1, false, Image.FORMAT_RGBA8)
	var half := float(BAND_TEX_WIDTH) * 0.5
	for x in range(BAND_TEX_WIDTH):
		var intensity := maxf(0.0, 1.0 - absf(float(x) - half) / half)
		var alpha := pow(intensity, 1.8)
		image.set_pixel(x, 0, Color(120.0 / 255.0, 186.0 / 255.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)


func _advance_motes(dt: float) -> void:
	for mote in _motes:
		var x := float(mote.get("x", 0.0)) + float(mote.get("speed", 16.0)) * dt
		var y := float(mote.get("y", 0.0)) + sin(_time * 2.0 + float(mote.get("phase", 0.0))) * 0.5
		if x > LOGICAL.x + 40.0:
			x = -40.0
			# Reset to a deterministic band row derived from phase (no RNG).
			y = 285.0 + fmod(float(mote.get("phase", 0.0)) * 97.0, 200.0)
		mote["x"] = x
		mote["y"] = y


func _to_screen(logical: Vector2, game_offset: Vector2, game_size: Vector2) -> Vector2:
	return game_offset + Vector2(logical.x / LOGICAL.x * game_size.x, logical.y / LOGICAL.y * game_size.y)


func _consume_draw_delta() -> float:
	var now := Time.get_ticks_msec()
	if _last_draw_msec <= 0:
		_last_draw_msec = now
		return 1.0 / 60.0
	var delta := clampf(float(now - _last_draw_msec) / 1000.0, 0.0, 0.1)
	_last_draw_msec = now
	return delta
