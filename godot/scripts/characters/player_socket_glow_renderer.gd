extends RefCounted

# Perk-driven under-board glow anchored to per-frame sprite sockets.
#
# Pilot for the socket composition contract: when the gating perk is owned
# (published to draw context as `player_socket_glow_perk_level`), a layered
# jade wisp-fire glow is drawn at the character's foot/board sockets, tracking
# the body frame-by-frame through PlayerSpriteSocketCatalog. No character art
# is baked -- the effect composes onto any base sheet that has socket data.
#
# Command building is separated from canvas execution so smokes can assert
# the real output (positions / colors / gating) without a live canvas, same
# as player_customization_overlay_renderer.build_draw_commands.

const PlayerSpriteSocketCatalog := preload("res://scripts/characters/player_sprite_socket_catalog.gd")

const GLOW_PERK_LEVEL_CONTEXT_KEY := "player_socket_glow_perk_level"
const DEBUG_OVERLAY_CONTEXT_KEY := "player_socket_debug_overlay_enabled"
const GLOW_SOCKET_IDS := ["foot_l", "foot_r"]

# 환격전 무협 톤: 옥빛 도깨비불 -- deep jade halo fading into a pale mint
# core. Executed with an ADDITIVE canvas material (see draw_under_glow), so
# layer alphas act as luminance and the stacked circles read as one soft
# spirit-fire orb instead of flat alpha discs.
const GLOW_LAYERS := [
	{"radius_scale": 1.0, "y_offset_ratio": 0.30, "color": Color(0.05, 0.30, 0.22, 0.30)},
	{"radius_scale": 0.78, "y_offset_ratio": 0.22, "color": Color(0.08, 0.42, 0.31, 0.34)},
	{"radius_scale": 0.56, "y_offset_ratio": 0.14, "color": Color(0.13, 0.56, 0.42, 0.40)},
	{"radius_scale": 0.36, "y_offset_ratio": 0.06, "color": Color(0.30, 0.78, 0.60, 0.48)},
	{"radius_scale": 0.18, "y_offset_ratio": 0.0, "color": Color(0.72, 1.0, 0.88, 0.62)},
]
const GLOW_BASE_RADIUS_RATIO := 0.085
# Effective-level overflow stays opt-out per repo policy: keep scaling past
# Lv.5, with a sanity clamp far above any reachable level.
const GLOW_LEVEL_RADIUS_GAIN := 0.06
const GLOW_LEVEL_ALPHA_GAIN := 0.05
const GLOW_LEVEL_SANITY_MAX := 9
const GLOW_PULSE_SPEED := 5.2
const GLOW_PULSE_DEPTH := 0.18
const GLOW_SOCKET_PHASE_STEP := 2.2

const DEBUG_MARKER_HALF_PX := 5.0
const DEBUG_MARKER_COLOR := Color(1.0, 0.35, 0.35, 0.95)

static var _additive_material: CanvasItemMaterial = null


static func _get_additive_material() -> CanvasItemMaterial:
	if _additive_material == null:
		_additive_material = CanvasItemMaterial.new()
		_additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _additive_material


func draw_under_glow(
	canvas: CanvasItem,
	context: Dictionary,
	motion_id: String,
	frame_index: int,
	direction: String,
	dest_rect: Rect2,
	cell_size: Vector2 = Vector2.ZERO
) -> void:
	if canvas == null:
		return
	var commands: Array = build_draw_commands(context, motion_id, frame_index, direction, dest_rect, cell_size)
	if commands.is_empty():
		return
	# Additive blend so stacked jade layers read as luminous spirit-fire.
	# Same swap-and-restore pattern as the stage1 silhouette rim material.
	var prev_material: Material = canvas.material
	canvas.material = _get_additive_material()
	for command in commands:
		if command is Dictionary:
			canvas.draw_circle(
				(command as Dictionary).get("pos", Vector2.ZERO),
				float((command as Dictionary).get("radius", 0.0)),
				(command as Dictionary).get("color", Color.WHITE)
			)
	canvas.material = prev_material


func draw_debug_markers(
	canvas: CanvasItem,
	context: Dictionary,
	motion_id: String,
	frame_index: int,
	direction: String,
	dest_rect: Rect2,
	cell_size: Vector2 = Vector2.ZERO
) -> void:
	if canvas == null:
		return
	for command in build_debug_marker_commands(context, motion_id, frame_index, direction, dest_rect, cell_size):
		if command is Dictionary:
			canvas.draw_line(
				(command as Dictionary).get("from", Vector2.ZERO),
				(command as Dictionary).get("to", Vector2.ZERO),
				(command as Dictionary).get("color", DEBUG_MARKER_COLOR),
				1.0
			)


func build_draw_commands(
	context: Dictionary,
	motion_id: String,
	frame_index: int,
	direction: String,
	dest_rect: Rect2,
	cell_size: Vector2 = Vector2.ZERO
) -> Array:
	var commands: Array = []
	var level: int = int(context.get(GLOW_PERK_LEVEL_CONTEXT_KEY, 0))
	if level <= 0:
		return commands
	var sockets: Dictionary = _resolve_sockets(context, motion_id, frame_index, direction, dest_rect, cell_size)
	if sockets.is_empty():
		return commands
	var clamped_level: int = clampi(level, 1, GLOW_LEVEL_SANITY_MAX)
	var base_radius: float = dest_rect.size.x * GLOW_BASE_RADIUS_RATIO * (1.0 + GLOW_LEVEL_RADIUS_GAIN * float(clamped_level - 1))
	var level_alpha: float = minf(1.0, 0.8 + GLOW_LEVEL_ALPHA_GAIN * float(clamped_level))
	var anim_clock: float = float(context.get("player_anim_clock", 0.0))
	var socket_index: int = 0
	for socket_id in GLOW_SOCKET_IDS:
		if not sockets.has(socket_id):
			socket_index += 1
			continue
		var pos: Vector2 = sockets[socket_id]
		var pulse: float = 1.0 - GLOW_PULSE_DEPTH * 0.5 * (1.0 + sin(anim_clock * GLOW_PULSE_SPEED + float(socket_index) * GLOW_SOCKET_PHASE_STEP))
		for layer in GLOW_LAYERS:
			var layer_dict: Dictionary = layer
			var color: Color = layer_dict.get("color", Color.WHITE)
			commands.append({
				"socket_id": socket_id,
				"pos": pos + Vector2(0.0, base_radius * float(layer_dict.get("y_offset_ratio", 0.0))),
				"radius": base_radius * float(layer_dict.get("radius_scale", 1.0)),
				"color": Color(color.r, color.g, color.b, color.a * pulse * level_alpha),
			})
		socket_index += 1
	return commands


func build_debug_marker_commands(
	context: Dictionary,
	motion_id: String,
	frame_index: int,
	direction: String,
	dest_rect: Rect2,
	cell_size: Vector2 = Vector2.ZERO
) -> Array:
	var commands: Array = []
	if not bool(context.get(DEBUG_OVERLAY_CONTEXT_KEY, false)):
		return commands
	var sockets: Dictionary = _resolve_sockets(context, motion_id, frame_index, direction, dest_rect, cell_size)
	for socket_id in sockets:
		var pos: Vector2 = sockets[socket_id]
		commands.append({
			"socket_id": socket_id,
			"from": pos + Vector2(-DEBUG_MARKER_HALF_PX, 0.0),
			"to": pos + Vector2(DEBUG_MARKER_HALF_PX, 0.0),
			"color": DEBUG_MARKER_COLOR,
		})
		commands.append({
			"socket_id": socket_id,
			"from": pos + Vector2(0.0, -DEBUG_MARKER_HALF_PX),
			"to": pos + Vector2(0.0, DEBUG_MARKER_HALF_PX),
			"color": DEBUG_MARKER_COLOR,
		})
	return commands


func _resolve_sockets(
	context: Dictionary,
	motion_id: String,
	frame_index: int,
	direction: String,
	dest_rect: Rect2,
	cell_size: Vector2
) -> Dictionary:
	var character_id: String = str(context.get("selected_character_type", "smasher")).strip_edges().to_lower()
	# Cell-basis guard: authored socket coordinates only apply to the sheet
	# family they were measured from. Legacy fallback sheets (250x120 strip,
	# 344x384 attack) fail this check and skip, rather than glowing at a
	# guessed spot.
	if cell_size != Vector2.ZERO:
		var authored_cell: Vector2 = PlayerSpriteSocketCatalog.get_cell_size(character_id)
		if authored_cell == Vector2.ZERO or not cell_size.is_equal_approx(authored_cell):
			return {}
	return PlayerSpriteSocketCatalog.resolve_screen_sockets(
		character_id,
		motion_id,
		direction,
		frame_index,
		dest_rect
	)
