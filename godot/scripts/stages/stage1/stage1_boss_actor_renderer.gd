extends RefCounted

const Stage1ContextReader := preload("res://scripts/stages/stage1/stage1_context_reader.gd")

# Stage 1 Dalji boss render contract:
# - Walk: separate left/right sheets, 1376x768, 4x2 grid, cell 344x384, 8 frames each.
# - Idle: 1536x1024, 4x2 grid, cell 384x512, 8-frame breathing loop.
# - Ball-contact hit: attack sheet, 1536x1024, 4x2 grid, cell 384x512, 8-frame loop.
# Drawing canvas matches Python's BOSS_IMG_STAGE1 (96 x 112) so the chibi body
# locks to ~89gp across every state — see CLAUDE.md "Cross-boss size standard"
# and "Current Stage 1 Dalji walk facing policy".
const DEFAULT_BOSS_VISUAL_CENTER_Y_OFFSET := 25.0
const DEFAULT_BOSS_DRAW_SIZE := Vector2(96.0, 112.0)
const WALK_CELL_WIDTH := 344.0
const WALK_CELL_HEIGHT := 384.0
const STATIC_CELL_WIDTH := 384.0
const STATIC_CELL_HEIGHT := 512.0
const SHEET_GRID_COLS := 4
const SHEET_GRID_ROWS := 2


func draw(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var boss_pos: Vector2 = _as_vector2(context.get("boss_pos", Vector2.ZERO), Vector2.ZERO)
	var boss_paddle_size: Vector2 = _as_vector2(context.get("boss_paddle_size", Vector2(110.0, 18.0)), Vector2(110.0, 18.0))
	var boss_hitbox_height: float = float(context.get("boss_hitbox_height", boss_paddle_size.y))
	var boss_shadow_rect := Rect2(
		boss_pos.x + boss_paddle_size.x * 0.5 - 42.0 + shake_offset.x,
		boss_pos.y + boss_hitbox_height - 6.0 + shake_offset.y,
		84.0,
		12.0
	)
	canvas.draw_rect(boss_shadow_rect, Color(0.0, 0.0, 0.0, 0.16), true)

	var sheet_selection: Dictionary = _select_sheet(context)
	var sheet: Variant = sheet_selection.get("texture", null)
	if sheet is Texture2D:
		var boss_draw_size: Vector2 = _as_vector2(context.get("boss_sprite_draw_size", DEFAULT_BOSS_DRAW_SIZE), DEFAULT_BOSS_DRAW_SIZE)
		var boss_visual_center_y: float = (
			boss_pos.y
			+ boss_hitbox_height * 0.5
			+ float(context.get("boss_visual_center_y_offset", DEFAULT_BOSS_VISUAL_CENTER_Y_OFFSET))
			+ float(context.get("boss_whip_bob_offset", 0.0))
		)
		var boss_visual_rect := Rect2(
			boss_pos.x + boss_paddle_size.x * 0.5 - boss_draw_size.x * 0.5 + shake_offset.x,
			boss_visual_center_y - boss_draw_size.y * 0.5 + shake_offset.y,
			boss_draw_size.x,
			boss_draw_size.y
		)
		var region: Rect2 = _get_cell_region(
			int(sheet_selection.get("frame", 0)),
			float(sheet_selection.get("cell_width", WALK_CELL_WIDTH)),
			float(sheet_selection.get("cell_height", WALK_CELL_HEIGHT))
		)
		canvas.draw_texture_rect_region(sheet, boss_visual_rect, region, Color.WHITE, false, true)
	else:
		_draw_boss_fallback(canvas, context, boss_pos, boss_paddle_size, shake_offset)


func _select_sheet(context: Dictionary) -> Dictionary:
	# Priority: Dalji whip skill > ball-contact attack > walk (left or right by facing) > idle.
	# `boss_*_sheet` keys come from battle_resources / battle_draw_actor_context.
	if bool(context.get("boss_whip_active", false)) or bool(context.get("boss_whip_deactivation_active", false)):
		var whip_sheet: Variant = context.get("boss_whip_sheet", null)
		if whip_sheet is Texture2D:
			return {
				"texture": whip_sheet,
				"frame": int(context.get("boss_whip_frame", 0)),
				"cell_width": STATIC_CELL_WIDTH,
				"cell_height": STATIC_CELL_HEIGHT,
			}

	if bool(context.get("boss_whip_post_stun_active", false)):
		var stun_sheet: Variant = context.get("boss_stun_sheet", null)
		if stun_sheet is Texture2D:
			return {
				"texture": stun_sheet,
				"frame": int(context.get("boss_whip_post_stun_frame", 0)),
				"cell_width": STATIC_CELL_WIDTH,
				"cell_height": STATIC_CELL_HEIGHT,
			}

	if bool(context.get("boss_hit_active", false)):
		var hit_sheet: Variant = context.get("boss_attack_sheet", null)
		if not (hit_sheet is Texture2D):
			hit_sheet = context.get("boss_hit_sprite_sheet", null)
		if hit_sheet is Texture2D:
			return {
				"texture": hit_sheet,
				"frame": int(context.get("boss_hit_frame", 0)),
				"cell_width": STATIC_CELL_WIDTH,
				"cell_height": STATIC_CELL_HEIGHT,
			}

	if bool(context.get("boss_is_walking", false)):
		var facing: int = int(context.get("boss_facing", 1))
		var walk_sheet: Variant = context.get("boss_walk_left_sheet", null) if facing < 0 else context.get("boss_walk_right_sheet", null)
		if walk_sheet is Texture2D:
			return {
				"texture": walk_sheet,
				"frame": int(context.get("boss_sprite_frame", 0)),
				"cell_width": WALK_CELL_WIDTH,
				"cell_height": WALK_CELL_HEIGHT,
			}

	var idle_sheet: Variant = context.get("boss_idle_sheet", null)
	if idle_sheet is Texture2D:
		return {
			"texture": idle_sheet,
			"frame": int(context.get("boss_idle_frame", 0)),
			"cell_width": STATIC_CELL_WIDTH,
			"cell_height": STATIC_CELL_HEIGHT,
		}

	# Final fallback: legacy single boss_sprite_sheet (right-walk anchor).
	var legacy_sheet: Variant = context.get("boss_sprite_sheet", null)
	if legacy_sheet is Texture2D:
		return {
			"texture": legacy_sheet,
			"frame": int(context.get("boss_sprite_frame", 0)),
			"cell_width": WALK_CELL_WIDTH,
			"cell_height": WALK_CELL_HEIGHT,
		}

	return {"texture": null}


func _get_cell_region(frame: int, cell_width: float, cell_height: float) -> Rect2:
	var clamped: int = clamp(frame, 0, SHEET_GRID_COLS * SHEET_GRID_ROWS - 1)
	var col: int = clamped % SHEET_GRID_COLS
	var row: int = int(clamped / SHEET_GRID_COLS)
	return Rect2(float(col) * cell_width, float(row) * cell_height, cell_width, cell_height)


func _draw_boss_fallback(canvas: CanvasItem, context: Dictionary, boss_pos: Vector2, boss_paddle_size: Vector2, shake_offset: Vector2) -> void:
	var boss_color: Color = _as_color(context.get("boss_color", Color(1.0, 0.25, 0.25)), Color(1.0, 0.25, 0.25))
	var boss_color_light: Color = _as_color(context.get("boss_color_light", Color(1.0, 0.45, 0.35)), Color(1.0, 0.45, 0.35))
	canvas.draw_rect(Rect2(boss_pos + shake_offset, boss_paddle_size), boss_color)
	canvas.draw_rect(
		Rect2(
			boss_pos.x + 2.0 + shake_offset.x,
			boss_pos.y + boss_paddle_size.y - boss_paddle_size.y / 3.0 + shake_offset.y,
			boss_paddle_size.x - 4.0,
			boss_paddle_size.y / 3.0
		),
		boss_color_light
	)


func _as_vector2(value, fallback: Vector2) -> Vector2:
	return Stage1ContextReader.as_vector2(value, fallback)


func _as_color(value, fallback: Color) -> Color:
	return Stage1ContextReader.as_color(value, fallback)
