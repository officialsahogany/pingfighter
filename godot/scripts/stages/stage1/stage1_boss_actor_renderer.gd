extends RefCounted

const Stage1ContextReader := preload("res://scripts/stages/stage1/stage1_context_reader.gd")
const BossHealthBarRenderer := preload("res://scripts/status/boss_health_bar_renderer.gd")
const PaddleHologramGlitchRenderer := preload("res://scripts/effects/paddle_hologram_glitch_renderer.gd")
const ElectricStunVisual := preload("res://scripts/status/boss_electric_stun_visual.gd")
const ElectrocutionFieldHost := preload("res://scripts/effects/boss_electrocution_field_fx_host.gd")

# Stage 1 Dalji boss render contract:
# - Walk: separate left/right run sheets, 1376x1536, 4x4 grid, cell 344x384, 16 frames each.
# - Idle: 1536x1024, 4x2 grid, cell 384x512, 8-frame breathing loop.
# - Ball-contact hit: attack sheet, 1536x1024, 4x2 grid, cell 384x512, 8-frame loop.
# - Paengi top-whip: 4096x2048, 8x4 grid, cell 512x512, 32-frame one-shot.
# - Victory / defeat: result sheets, 1536x1024, 4x2 grid, cell 384x512, play once.
# Drawing canvas matches Python's BOSS_IMG_STAGE1 (96 x 112) so the chibi body
# locks to ~89gp across every state — see CLAUDE.md "Cross-boss size standard"
# and "Current Stage 1 Dalji walk facing policy".
const DEFAULT_BOSS_VISUAL_CENTER_Y_OFFSET := 25.0
const DEFAULT_BOSS_DRAW_SIZE := Vector2(96.0, 112.0)
const WALK_CELL_WIDTH := 344.0
const WALK_CELL_HEIGHT := 384.0
const STATIC_CELL_WIDTH := 384.0
const STATIC_CELL_HEIGHT := 512.0
const STATIC_FRAME_COUNT := 8
const STATIC_GRID_COLS := 4
const PAENGI_TOP_WHIP_CELL_SIZE := 512.0
const PAENGI_TOP_WHIP_FRAME_COUNT := 32
const PAENGI_TOP_WHIP_GRID_COLS := 8
const WALK_FRAME_COUNT := 16
const WALK_GRID_COLS := 4
const GAKSITAL_STATIC_CELL_SIZE := 256.0
const GAKSITAL_STATIC_FRAME_COUNT := 8
const GAKSITAL_STATIC_GRID_COLS := 3
const GAKSITAL_WALK_FRAME_COUNT := 16
const GAKSITAL_WALK_GRID_COLS := 4
const GAKSITAL_FAN_THROW_FRAME_COUNT := 16
const GAKSITAL_FAN_THROW_GRID_COLS := 4
const PODODAEJANG_CELL_SIZE := 256.0
const PODODAEJANG_STATIC_FRAME_COUNT := 8
const PODODAEJANG_STATIC_GRID_COLS := 3
const PODODAEJANG_WALK_FRAME_COUNT := 16
const PODODAEJANG_WALK_GRID_COLS := 4
const GROUND_SHADOW_ALPHAS := [0.075, 0.12]
const GROUND_SHADOW_SEGMENTS := 12
const SPIDER_WAVE_SEGMENTS := 20
const STUN_STAR_FILL_COLORS := [
	Color(1.0, 1.0, 100.0 / 255.0, 1.0),
	Color(1.0, 1.0, 100.0 / 255.0, 1.0),
	Color(1.0, 1.0, 100.0 / 255.0, 1.0),
	Color(1.0, 1.0, 100.0 / 255.0, 1.0),
	Color(1.0, 1.0, 100.0 / 255.0, 1.0),
	Color(1.0, 1.0, 100.0 / 255.0, 1.0),
	Color(1.0, 1.0, 100.0 / 255.0, 1.0),
	Color(1.0, 1.0, 100.0 / 255.0, 1.0),
	Color(1.0, 1.0, 100.0 / 255.0, 1.0),
	Color(1.0, 1.0, 100.0 / 255.0, 1.0),
]

var _unit_ellipse_points_cache: Dictionary = {}
var _unit_star_points := PackedVector2Array()
var _question_size_cache: Dictionary = {}
var boss_health_bar_renderer: Object = BossHealthBarRenderer.new()


func draw(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	# Ball-spawn-intro paddle hologram gate. Same contract as the player
	# renderer: the boss is fully hidden until the materialize window opens
	# and renders through a glitch reveal during it.
	if not bool(context.get("paddle_hologram_should_draw", true)):
		return
	var paddle_hologram_active: bool = bool(context.get("paddle_hologram_active", false))
	var paddle_hologram_progress: float = float(context.get("paddle_hologram_progress", 1.0))
	var paddle_hologram_plan: Dictionary = {}
	if paddle_hologram_active:
		paddle_hologram_plan = PaddleHologramGlitchRenderer.compute_pass_plan(
			paddle_hologram_progress, Time.get_ticks_msec()
		)
		if bool(paddle_hologram_plan.get("flicker_hidden", false)):
			# Whole boss skips this frame. Health bar / status decorations
			# stay off too — they read as "the boss is not present yet".
			return
	var boss_pos: Vector2 = _as_vector2(context.get("boss_pos", Vector2.ZERO), Vector2.ZERO)
	var boss_paddle_size: Vector2 = _as_vector2(context.get("boss_paddle_size", Vector2(110.0, 18.0)), Vector2(110.0, 18.0))
	var boss_hitbox_height: float = float(context.get("boss_hitbox_height", boss_paddle_size.y))
	var emp_offset: Vector2 = _get_emp_status_jitter(context) + ElectricStunVisual.body_jitter(context)
	var emp_modulate: Color = _get_emp_status_modulate(context) * ElectricStunVisual.body_modulate(context)
	var electro_center := Vector2(
		boss_pos.x + boss_paddle_size.x * 0.5,
		boss_pos.y + boss_hitbox_height * 0.5 + float(context.get("boss_visual_center_y_offset", DEFAULT_BOSS_VISUAL_CENTER_Y_OFFSET))
	) + shake_offset
	ElectrocutionFieldHost.drive_from_context(canvas, electro_center, context)

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
		boss_visual_rect.position += emp_offset
		_draw_ground_shadow(canvas, boss_visual_rect)
		var region: Rect2 = _get_cell_region(
			int(sheet_selection.get("frame", 0)),
			float(sheet_selection.get("cell_width", WALK_CELL_WIDTH)),
			float(sheet_selection.get("cell_height", WALK_CELL_HEIGHT)),
			int(sheet_selection.get("grid_cols", STATIC_GRID_COLS)),
			int(sheet_selection.get("frame_count", STATIC_FRAME_COUNT))
		)
		var flip_h: bool = bool(sheet_selection.get("flip_h", false))
		if bool(context.get("boss_whip_deactivation_active", false)):
			_draw_whip_deactivation(
				canvas,
				sheet,
				region,
				boss_visual_rect.get_center(),
				boss_draw_size,
				float(context.get("boss_whip_deactivation_angle_degrees", 0.0))
			)
		elif paddle_hologram_active:
			_draw_boss_with_hologram_passes(canvas, sheet, region, boss_visual_rect, emp_modulate, flip_h, paddle_hologram_plan)
		elif flip_h:
			_draw_flipped_texture_region(canvas, sheet, region, boss_visual_rect, emp_modulate)
		else:
			canvas.draw_texture_rect_region(sheet, boss_visual_rect, region, emp_modulate, false, true)
		_draw_boss_emp_status_overlay(canvas, boss_visual_rect, context)
		if paddle_hologram_active:
			PaddleHologramGlitchRenderer.draw_overlays(canvas, boss_visual_rect, paddle_hologram_plan)
	else:
		_draw_boss_fallback(canvas, context, boss_pos, boss_paddle_size, shake_offset)
		_draw_boss_emp_status_overlay(
			canvas,
			Rect2(boss_pos + shake_offset + emp_offset, boss_paddle_size),
			context
		)

	if bool(context.get("active_item_boss_stun_active", false)) and not bool(context.get("active_item_boss_stun_stars_suppressed", false)):
		_draw_boss_stun_stars(canvas, boss_pos, boss_paddle_size, shake_offset)
	if bool(context.get("active_item_boss_confusion_active", false)):
		_draw_boss_confusion_questions(canvas, boss_pos, boss_paddle_size, boss_hitbox_height, shake_offset)
	if bool(context.get("active_item_boss_soap_active", false)):
		_draw_boss_soap_indicator(canvas, boss_pos, boss_paddle_size, boss_hitbox_height, shake_offset, float(context.get("active_item_boss_soap_ratio", 1.0)))
	if bool(context.get("active_item_boss_spider_slow_active", false)):
		_draw_boss_spider_slow_wave(canvas, boss_pos, boss_paddle_size, boss_hitbox_height, shake_offset, float(context.get("active_item_boss_spider_slow_ratio", 1.0)))
	if bool(context.get("active_item_boss_tear_gas_pause_active", false)):
		_draw_boss_cooldown_pause_marker(canvas, boss_pos, boss_paddle_size, boss_hitbox_height, shake_offset)
	boss_health_bar_renderer.draw(canvas, context, boss_pos, boss_paddle_size, boss_hitbox_height, shake_offset)


# Cyan ghost (left-shifted) + magenta ghost (right-shifted) + main pass for
# the boss sheet. Mirrors the player renderer's multi-pass logic but talks
# directly to `draw_texture_rect_region` / `_draw_flipped_texture_region`
# since the boss sheet is one texture region, not the multi-layer sprite the
# player renderer composites.
func _draw_boss_with_hologram_passes(
	canvas: CanvasItem,
	sheet: Texture2D,
	region: Rect2,
	boss_visual_rect: Rect2,
	emp_modulate: Color,
	flip_h: bool,
	plan: Dictionary
) -> void:
	var color_shift_x: float = float(plan.get("color_shift_x", 0.0))
	if bool(plan.get("ghosts_active", false)) and color_shift_x > 0.001:
		var cyan_modulate: Color = _multiply_color(emp_modulate, plan.get("cyan_modulate", Color.WHITE))
		var cyan_rect := Rect2(
			boss_visual_rect.position + Vector2(-color_shift_x, 0.0),
			boss_visual_rect.size
		)
		_draw_boss_sheet(canvas, sheet, region, cyan_rect, cyan_modulate, flip_h)

		var magenta_modulate: Color = _multiply_color(emp_modulate, plan.get("magenta_modulate", Color.WHITE))
		var magenta_rect := Rect2(
			boss_visual_rect.position + Vector2(color_shift_x, 0.0),
			boss_visual_rect.size
		)
		_draw_boss_sheet(canvas, sheet, region, magenta_rect, magenta_modulate, flip_h)

	var main_modulate: Color = PaddleHologramGlitchRenderer.combine_modulate(emp_modulate, plan)
	_draw_boss_sheet(canvas, sheet, region, boss_visual_rect, main_modulate, flip_h)


func _draw_boss_sheet(
	canvas: CanvasItem,
	sheet: Texture2D,
	region: Rect2,
	target_rect: Rect2,
	modulate: Color,
	flip_h: bool
) -> void:
	if flip_h:
		_draw_flipped_texture_region(canvas, sheet, region, target_rect, modulate)
	else:
		canvas.draw_texture_rect_region(sheet, target_rect, region, modulate, false, true)


func _multiply_color(a: Color, b) -> Color:
	var rhs: Color = b if b is Color else Color.WHITE
	return Color(a.r * rhs.r, a.g * rhs.g, a.b * rhs.b, a.a * rhs.a)


func _select_sheet(context: Dictionary) -> Dictionary:
	if _is_gaksital_variant(context):
		return _select_gaksital_sheet(context)
	if _is_pododaejang_variant(context):
		return _select_pododaejang_sheet(context)
	return _select_dalji_sheet(context)


func _select_pododaejang_sheet(context: Dictionary) -> Dictionary:
	# Priority: defeat > victory > stun > dash > arrest-rope/ball-contact
	# attack > walk > idle. Pododaejang uses a single front-facing walk sheet
	# for both directions; the 8-frame AutoSprite sheets are 3x3 with cell 8
	# unused, so stop at frame 7.
	if bool(context.get("boss_defeat_active", false)):
		var defeat_sheet: Variant = context.get("boss_defeat_sheet", null)
		if defeat_sheet is Texture2D:
			return _pododaejang_static_selection(defeat_sheet, int(context.get("boss_result_frame", 0)))

	if bool(context.get("boss_victory_active", false)):
		var victory_sheet: Variant = context.get("boss_victory_sheet", null)
		if victory_sheet is Texture2D:
			return _pododaejang_static_selection(victory_sheet, int(context.get("boss_result_frame", 0)))

	if bool(context.get("boss_whip_post_stun_active", false)):
		var post_stun_sheet: Variant = context.get("boss_stun_sheet", null)
		if post_stun_sheet is Texture2D:
			return _pododaejang_static_selection(post_stun_sheet, int(context.get("boss_whip_post_stun_frame", 0)))

	if bool(context.get("active_item_boss_stun_active", false)):
		var item_stun_sheet: Variant = context.get("boss_stun_sheet", null)
		if item_stun_sheet is Texture2D:
			return _pododaejang_static_selection(item_stun_sheet, int(context.get("active_item_boss_stun_frame", 0)))

	if bool(context.get("boss_dash_active", false)):
		var dash_sheet: Variant = context.get("boss_dash_sheet", null)
		if dash_sheet is Texture2D:
			return _pododaejang_static_selection(dash_sheet, int(context.get("boss_dash_frame", 0)))

	if _is_pododaejang_arrest_rope_sheet_active(context):
		var rope_sheet: Variant = context.get("boss_attack_sheet", null)
		if not (rope_sheet is Texture2D):
			rope_sheet = context.get("boss_hit_sprite_sheet", null)
		if rope_sheet is Texture2D:
			return _pododaejang_static_selection(rope_sheet, _get_pododaejang_arrest_rope_frame(context))

	if bool(context.get("boss_hit_active", false)):
		var hit_sheet: Variant = context.get("boss_attack_sheet", null)
		if not (hit_sheet is Texture2D):
			hit_sheet = context.get("boss_hit_sprite_sheet", null)
		if hit_sheet is Texture2D:
			return _pododaejang_static_selection(hit_sheet, int(context.get("boss_hit_frame", 0)))

	if bool(context.get("boss_is_walking", false)):
		var walk_sheet: Variant = context.get("boss_walk_right_sheet", null)
		if not (walk_sheet is Texture2D):
			walk_sheet = context.get("boss_walk_left_sheet", null)
		if walk_sheet is Texture2D:
			return {
				"texture": walk_sheet,
				"frame": int(context.get("boss_sprite_frame", 0)),
				"cell_width": PODODAEJANG_CELL_SIZE,
				"cell_height": PODODAEJANG_CELL_SIZE,
				"grid_cols": PODODAEJANG_WALK_GRID_COLS,
				"frame_count": PODODAEJANG_WALK_FRAME_COUNT,
			}

	var idle_sheet: Variant = context.get("boss_idle_sheet", null)
	if idle_sheet is Texture2D:
		return _pododaejang_static_selection(idle_sheet, int(context.get("boss_idle_frame", 0)))

	var legacy_sheet: Variant = context.get("boss_sprite_sheet", null)
	if legacy_sheet is Texture2D:
		return {
			"texture": legacy_sheet,
			"frame": int(context.get("boss_sprite_frame", 0)),
			"cell_width": PODODAEJANG_CELL_SIZE,
			"cell_height": PODODAEJANG_CELL_SIZE,
			"grid_cols": PODODAEJANG_WALK_GRID_COLS,
			"frame_count": PODODAEJANG_WALK_FRAME_COUNT,
		}
	return {"texture": null}


func _select_gaksital_sheet(context: Dictionary) -> Dictionary:
	# Priority: defeat > victory > stun > dash > fan-throw windup > ball-contact attack > walk > idle.
	# Gaksital atlas grids are sheet-local: 4x4 for walk / fan_throw, 3x3 for the other 8f sheets.
	if bool(context.get("boss_defeat_active", false)):
		var defeat_sheet: Variant = context.get("boss_defeat_sheet", null)
		if defeat_sheet is Texture2D:
			return _gaksital_static_selection(defeat_sheet, int(context.get("boss_result_frame", 0)))

	if bool(context.get("boss_victory_active", false)):
		var victory_sheet: Variant = context.get("boss_victory_sheet", null)
		if victory_sheet is Texture2D:
			return _gaksital_static_selection(victory_sheet, int(context.get("boss_result_frame", 0)))

	if bool(context.get("boss_whip_post_stun_active", false)):
		var post_stun_sheet: Variant = context.get("boss_stun_sheet", null)
		if post_stun_sheet is Texture2D:
			return _gaksital_static_selection(post_stun_sheet, int(context.get("boss_whip_post_stun_frame", 0)))

	if bool(context.get("active_item_boss_stun_active", false)):
		var item_stun_sheet: Variant = context.get("boss_stun_sheet", null)
		if item_stun_sheet is Texture2D:
			return _gaksital_static_selection(item_stun_sheet, int(context.get("active_item_boss_stun_frame", 0)))

	if bool(context.get("boss_dash_active", false)):
		var dash_sheet: Variant = context.get("boss_dash_sheet", null)
		if dash_sheet is Texture2D:
			var dash_selection: Dictionary = _gaksital_static_selection(dash_sheet, int(context.get("boss_dash_frame", 0)))
			dash_selection["flip_h"] = int(context.get("boss_dash_direction", 1)) < 0
			return dash_selection

	if bool(context.get("boss_fan_throw_active", false)):
		var fan_throw_sheet: Variant = context.get("boss_fan_throw_sheet", null)
		if fan_throw_sheet is Texture2D:
			return {
				"texture": fan_throw_sheet,
				"frame": int(context.get("boss_fan_throw_frame", 0)),
				"cell_width": GAKSITAL_STATIC_CELL_SIZE,
				"cell_height": GAKSITAL_STATIC_CELL_SIZE,
				"grid_cols": GAKSITAL_FAN_THROW_GRID_COLS,
				"frame_count": GAKSITAL_FAN_THROW_FRAME_COUNT,
			}

	if bool(context.get("boss_hit_active", false)):
		var hit_sheet: Variant = context.get("boss_attack_sheet", null)
		if not (hit_sheet is Texture2D):
			hit_sheet = context.get("boss_hit_sprite_sheet", null)
		if hit_sheet is Texture2D:
			return _gaksital_static_selection(hit_sheet, int(context.get("boss_hit_frame", 0)))

	if bool(context.get("boss_is_walking", false)):
		var facing: int = int(context.get("boss_facing", 1))
		var walk_sheet: Variant = context.get("boss_walk_left_sheet", null) if facing < 0 else context.get("boss_walk_right_sheet", null)
		if walk_sheet is Texture2D:
			return {
				"texture": walk_sheet,
				"frame": int(context.get("boss_sprite_frame", 0)),
				"cell_width": GAKSITAL_STATIC_CELL_SIZE,
				"cell_height": GAKSITAL_STATIC_CELL_SIZE,
				"grid_cols": GAKSITAL_WALK_GRID_COLS,
				"frame_count": GAKSITAL_WALK_FRAME_COUNT,
			}

	var idle_sheet: Variant = context.get("boss_idle_sheet", null)
	if idle_sheet is Texture2D:
		return _gaksital_static_selection(idle_sheet, int(context.get("boss_idle_frame", 0)))

	var legacy_sheet: Variant = context.get("boss_sprite_sheet", null)
	if legacy_sheet is Texture2D:
		return {
			"texture": legacy_sheet,
			"frame": int(context.get("boss_sprite_frame", 0)),
			"cell_width": GAKSITAL_STATIC_CELL_SIZE,
			"cell_height": GAKSITAL_STATIC_CELL_SIZE,
			"grid_cols": GAKSITAL_WALK_GRID_COLS,
			"frame_count": GAKSITAL_WALK_FRAME_COUNT,
		}

	return {"texture": null}


func _gaksital_static_selection(texture: Texture2D, frame: int) -> Dictionary:
	return {
		"texture": texture,
		"frame": frame,
		"cell_width": GAKSITAL_STATIC_CELL_SIZE,
		"cell_height": GAKSITAL_STATIC_CELL_SIZE,
		"grid_cols": GAKSITAL_STATIC_GRID_COLS,
		"frame_count": GAKSITAL_STATIC_FRAME_COUNT,
	}


func _pododaejang_static_selection(texture: Texture2D, frame: int) -> Dictionary:
	return {
		"texture": texture,
		"frame": frame,
		"cell_width": PODODAEJANG_CELL_SIZE,
		"cell_height": PODODAEJANG_CELL_SIZE,
		"grid_cols": PODODAEJANG_STATIC_GRID_COLS,
		"frame_count": PODODAEJANG_STATIC_FRAME_COUNT,
	}


func _is_pododaejang_arrest_rope_sheet_active(context: Dictionary) -> bool:
	return (
		bool(context.get("boss_arrest_rope_active", false))
		or bool(context.get("stage1_pododaejang_arrest_rope_active", false))
	)


func _get_pododaejang_arrest_rope_frame(context: Dictionary) -> int:
	if context.has("boss_arrest_rope_frame"):
		return int(context.get("boss_arrest_rope_frame", 0))
	if context.has("stage1_pododaejang_arrest_rope_frame"):
		return int(context.get("stage1_pododaejang_arrest_rope_frame", 0))
	return int(context.get("boss_hit_frame", 0))


func _select_dalji_sheet(context: Dictionary) -> Dictionary:
	# Priority: defeat > victory > stun > dash > paengi top-whip > Dalji whip skill > ball-contact attack > walk > idle.
	# `boss_*_sheet` keys come from battle_resources / battle_draw_actor_context.
	if bool(context.get("boss_defeat_active", false)):
		var defeat_sheet: Variant = context.get("boss_defeat_sheet", null)
		if defeat_sheet is Texture2D:
			return {
				"texture": defeat_sheet,
				"frame": int(context.get("boss_result_frame", 0)),
				"cell_width": STATIC_CELL_WIDTH,
				"cell_height": STATIC_CELL_HEIGHT,
				"grid_cols": STATIC_GRID_COLS,
				"frame_count": STATIC_FRAME_COUNT,
			}

	if bool(context.get("boss_victory_active", false)):
		var victory_sheet: Variant = context.get("boss_victory_sheet", null)
		if victory_sheet is Texture2D:
			return {
				"texture": victory_sheet,
				"frame": int(context.get("boss_result_frame", 0)),
				"cell_width": STATIC_CELL_WIDTH,
				"cell_height": STATIC_CELL_HEIGHT,
				"grid_cols": STATIC_GRID_COLS,
				"frame_count": STATIC_FRAME_COUNT,
			}

	if bool(context.get("boss_whip_post_stun_active", false)):
		var stun_sheet: Variant = context.get("boss_stun_sheet", null)
		if stun_sheet is Texture2D:
			return {
				"texture": stun_sheet,
				"frame": int(context.get("boss_whip_post_stun_frame", 0)),
				"cell_width": STATIC_CELL_WIDTH,
				"cell_height": STATIC_CELL_HEIGHT,
				"grid_cols": STATIC_GRID_COLS,
				"frame_count": STATIC_FRAME_COUNT,
			}

	if bool(context.get("active_item_boss_stun_active", false)):
		var item_stun_sheet: Variant = context.get("boss_stun_sheet", null)
		if item_stun_sheet is Texture2D:
			return {
				"texture": item_stun_sheet,
				"frame": int(context.get("active_item_boss_stun_frame", 0)),
				"cell_width": STATIC_CELL_WIDTH,
				"cell_height": STATIC_CELL_HEIGHT,
				"grid_cols": STATIC_GRID_COLS,
				"frame_count": STATIC_FRAME_COUNT,
			}

	if bool(context.get("boss_dash_active", false)):
		var dash_sheet: Variant = context.get("boss_dash_sheet", null)
		if dash_sheet is Texture2D:
			return {
				"texture": dash_sheet,
				"frame": int(context.get("boss_dash_frame", 0)),
				"cell_width": STATIC_CELL_WIDTH,
				"cell_height": STATIC_CELL_HEIGHT,
				"grid_cols": STATIC_GRID_COLS,
				"frame_count": STATIC_FRAME_COUNT,
				"flip_h": int(context.get("boss_dash_direction", 1)) < 0,
			}

	if bool(context.get("boss_paengi_top_whip_active", false)):
		var paengi_sheet: Variant = context.get("boss_paengi_top_whip_sheet", null)
		if paengi_sheet is Texture2D:
			return {
				"texture": paengi_sheet,
				"frame": int(context.get("boss_paengi_top_whip_frame", 0)),
				"cell_width": PAENGI_TOP_WHIP_CELL_SIZE,
				"cell_height": PAENGI_TOP_WHIP_CELL_SIZE,
				"grid_cols": PAENGI_TOP_WHIP_GRID_COLS,
				"frame_count": PAENGI_TOP_WHIP_FRAME_COUNT,
			}

	if bool(context.get("boss_whip_active", false)):
		var whip_sheet: Variant = context.get("boss_whip_sheet", null)
		if whip_sheet is Texture2D:
			return {
				"texture": whip_sheet,
				"frame": int(context.get("boss_whip_frame", 0)),
				"cell_width": STATIC_CELL_WIDTH,
				"cell_height": STATIC_CELL_HEIGHT,
				"grid_cols": STATIC_GRID_COLS,
				"frame_count": STATIC_FRAME_COUNT,
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
				"grid_cols": STATIC_GRID_COLS,
				"frame_count": STATIC_FRAME_COUNT,
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
				"grid_cols": int(context.get("boss_walk_grid_cols", WALK_GRID_COLS)),
				"frame_count": int(context.get("boss_walk_frame_count", WALK_FRAME_COUNT)),
			}

	var idle_sheet: Variant = context.get("boss_idle_sheet", null)
	if idle_sheet is Texture2D:
		return {
			"texture": idle_sheet,
			"frame": int(context.get("boss_idle_frame", 0)),
			"cell_width": STATIC_CELL_WIDTH,
			"cell_height": STATIC_CELL_HEIGHT,
			"grid_cols": STATIC_GRID_COLS,
			"frame_count": STATIC_FRAME_COUNT,
		}

	# Final fallback: legacy single boss_sprite_sheet (right-walk anchor).
	var legacy_sheet: Variant = context.get("boss_sprite_sheet", null)
	if legacy_sheet is Texture2D:
		return {
			"texture": legacy_sheet,
			"frame": int(context.get("boss_sprite_frame", 0)),
			"cell_width": WALK_CELL_WIDTH,
			"cell_height": WALK_CELL_HEIGHT,
			"grid_cols": int(context.get("boss_walk_grid_cols", WALK_GRID_COLS)),
			"frame_count": int(context.get("boss_walk_frame_count", WALK_FRAME_COUNT)),
		}

	return {"texture": null}


func _is_gaksital_variant(context: Dictionary) -> bool:
	var variant: String = str(context.get("stage1_boss_variant", "dalji")).strip_edges().to_lower()
	return variant in ["gaksi", "gaksital", "talkwangdae", "talchum"]


func _is_pododaejang_variant(context: Dictionary) -> bool:
	var variant: String = str(context.get("stage1_boss_variant", "dalji")).strip_edges().to_lower()
	return variant in ["podo", "pododaejang", "podo_daejang"]


func _draw_ground_shadow(canvas: CanvasItem, visual_rect: Rect2) -> void:
	var shadow_width: float = visual_rect.size.x * 0.58
	var shadow_height: float = max(6.0, visual_rect.size.y * 0.075)
	var center := Vector2(
		visual_rect.get_center().x,
		visual_rect.position.y + visual_rect.size.y * 0.86
	)
	var layer_count: int = GROUND_SHADOW_ALPHAS.size()
	for layer in range(layer_count):
		var layer_t: float = float(layer_count - 1 - layer)
		var grow_x: float = layer_t * 5.0
		var grow_y: float = layer_t * 1.4
		var alpha: float = GROUND_SHADOW_ALPHAS[layer]
		var rect := Rect2(
			center - Vector2((shadow_width + grow_x) * 0.5, (shadow_height + grow_y) * 0.5),
			Vector2(shadow_width + grow_x, shadow_height + grow_y)
		)
		canvas.draw_colored_polygon(
			_build_ellipse_points(rect, GROUND_SHADOW_SEGMENTS),
			Color(0.0, 0.0, 0.0, alpha)
		)


func _build_ellipse_points(rect: Rect2, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var center: Vector2 = rect.get_center()
	var radius := rect.size * 0.5
	var segment_count: int = max(8, segments)
	var unit_points: PackedVector2Array = _get_unit_ellipse_points(segment_count)
	for point in unit_points:
		points.append(center + Vector2(point.x * radius.x, point.y * radius.y))
	return points


func _get_unit_ellipse_points(segments: int) -> PackedVector2Array:
	if _unit_ellipse_points_cache.has(segments):
		return _unit_ellipse_points_cache[segments]
	var points := PackedVector2Array()
	for i in range(segments):
		var angle: float = TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)))
	_unit_ellipse_points_cache[segments] = points
	return points


func _get_cell_region(frame: int, cell_width: float, cell_height: float, grid_cols: int, frame_count: int) -> Rect2:
	var safe_grid_cols: int = max(1, grid_cols)
	var safe_frame_count: int = max(1, frame_count)
	var clamped: int = clamp(frame, 0, safe_frame_count - 1)
	var col: int = clamped % safe_grid_cols
	@warning_ignore("integer_division")
	var row: int = int(clamped / safe_grid_cols)
	return Rect2(float(col) * cell_width, float(row) * cell_height, cell_width, cell_height)


func _draw_boss_stun_stars(
	canvas: CanvasItem,
	boss_pos: Vector2,
	boss_paddle_size: Vector2,
	shake_offset: Vector2
) -> void:
	var current_msec: int = Time.get_ticks_msec()
	var rotation_angle: float = fmod(float(current_msec) * 0.36, 360.0)
	var boss_center_x: float = boss_pos.x + boss_paddle_size.x * 0.5 + shake_offset.x
	var star_center_y: float = boss_pos.y - 15.0 + shake_offset.y
	var orbit_radius: float = 20.0
	for i in range(3):
		var angle: float = deg_to_rad(rotation_angle + float(i) * 120.0)
		var center := Vector2(
			boss_center_x + orbit_radius * cos(angle),
			star_center_y + orbit_radius * sin(angle) * 0.5
		)
		_draw_stun_star_glow(canvas, center, 8.0)
		_draw_stun_star(canvas, center, 8.0)


func _draw_boss_emp_status_overlay(canvas: CanvasItem, visual_rect: Rect2, context: Dictionary) -> void:
	var intensity: float = _get_emp_status_intensity(context)
	if intensity <= 0.0:
		return
	var center: Vector2 = visual_rect.get_center()
	var now: float = float(Time.get_ticks_msec())
	var pulse: float = 0.5 + 0.5 * sin(now * 0.020)
	var aura_rect := Rect2(
		center - Vector2(visual_rect.size.x * 0.44, visual_rect.size.y * 0.42),
		Vector2(visual_rect.size.x * 0.88, visual_rect.size.y * 0.76)
	)
	canvas.draw_colored_polygon(
		_build_ellipse_points(aura_rect.grow(7.0 + pulse * 3.0), 24),
		Color(0.05, 0.86, 1.0, 0.10 * intensity)
	)
	_draw_ellipse_outline(canvas, aura_rect.grow(4.0 + pulse * 5.0), Color(0.28, 0.96, 1.0, 0.42 * intensity), 2.2)
	_draw_ellipse_outline(canvas, aura_rect.grow(-6.0 + pulse * 2.0), Color(0.86, 1.0, 1.0, 0.26 * intensity), 1.3)
	for idx in range(4):
		var angle: float = now * 0.011 + TAU * float(idx) / 4.0
		var start: Vector2 = center + Vector2(cos(angle), sin(angle) * 0.46) * (visual_rect.size.x * 0.25)
		var mid: Vector2 = center + Vector2(cos(angle + 0.38), sin(angle + 0.38) * 0.54) * (visual_rect.size.x * 0.37)
		var end: Vector2 = center + Vector2(cos(angle + 0.82), sin(angle + 0.82) * 0.50) * (visual_rect.size.x * 0.48)
		canvas.draw_polyline(PackedVector2Array([start, mid, end]), Color(0.10, 0.58, 1.0, 0.28 * intensity), 3.0, false)
		canvas.draw_polyline(PackedVector2Array([start, mid, end]), Color(0.84, 1.0, 1.0, 0.82 * intensity), 1.2, false)
	for idx in range(5):
		var spark_angle: float = now * 0.016 + TAU * float(idx) / 5.0
		var spark_pos: Vector2 = center + Vector2(cos(spark_angle), sin(spark_angle) * 0.58) * (visual_rect.size.x * 0.36 + pulse * 5.0)
		canvas.draw_circle(spark_pos, 1.7 + pulse, Color(0.88, 1.0, 1.0, 0.64 * intensity))


func _get_emp_status_intensity(context: Dictionary) -> float:
	if not bool(context.get("viper_emp_slip_active", false)):
		return 0.0
	var ratio: float = clamp(float(context.get("viper_emp_slip_ratio", 1.0)), 0.0, 1.0)
	return clamp(0.36 + ratio * 0.64, 0.0, 1.0)


func _get_emp_status_jitter(context: Dictionary) -> Vector2:
	var intensity: float = _get_emp_status_intensity(context)
	if intensity <= 0.0:
		return Vector2.ZERO
	var now: float = float(Time.get_ticks_msec())
	return Vector2(
		(sin(now * 0.054) + sin(now * 0.091) * 0.55) * 2.2 * intensity,
		sin(now * 0.073) * 1.2 * intensity
	)


func _get_emp_status_modulate(context: Dictionary) -> Color:
	var intensity: float = _get_emp_status_intensity(context)
	if intensity <= 0.0:
		return Color.WHITE
	var pulse: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.026)
	return Color(
		lerp(1.0, 0.62, 0.34 * intensity),
		lerp(1.0, 1.12, 0.28 * intensity + pulse * 0.06),
		lerp(1.0, 1.28, 0.34 * intensity + pulse * 0.08),
		1.0
	)


func _draw_stun_star_glow(canvas: CanvasItem, center: Vector2, radius: float) -> void:
	canvas.draw_circle(center, radius * 2.0, Color(1.0, 0.92, 0.20, 0.14))
	canvas.draw_circle(center, radius * 1.35, Color(1.0, 1.0, 0.52, 0.20))


func _draw_stun_star(canvas: CanvasItem, center: Vector2, radius: float) -> void:
	if _unit_star_points.is_empty():
		_unit_star_points = _build_unit_stun_star_points()
	var points := PackedVector2Array()
	for point in _unit_star_points:
		points.append(center + point * radius)
	canvas.draw_polygon(points, STUN_STAR_FILL_COLORS)
	for j in range(points.size()):
		canvas.draw_line(
			points[j],
			points[(j + 1) % points.size()],
			Color(1.0, 200.0 / 255.0, 0.0, 1.0),
			1.0
		)


func _build_unit_stun_star_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	for j in range(10):
		var point_angle: float = deg_to_rad(float(j) * 36.0 - 90.0)
		var point_radius: float = 1.0 if j % 2 == 0 else 0.4
		points.append(Vector2(cos(point_angle), sin(point_angle)) * point_radius)
	return points


func _draw_boss_confusion_questions(
	canvas: CanvasItem,
	boss_pos: Vector2,
	boss_paddle_size: Vector2,
	boss_hitbox_height: float,
	shake_offset: Vector2
) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var current_msec: int = Time.get_ticks_msec()
	var orbit_rotation: float = float(current_msec) * 0.005
	var orbit_center := Vector2(
		boss_pos.x + boss_paddle_size.x * 0.5 + shake_offset.x,
		boss_pos.y + boss_hitbox_height * 0.5 - 25.0 + shake_offset.y
	)
	var orbit_radius: float = 40.0
	for i in range(3):
		var angle: float = orbit_rotation + float(i) * TAU / 3.0
		var center := Vector2(
			orbit_center.x + orbit_radius * cos(angle),
			orbit_center.y + orbit_radius * sin(angle) * 0.5
		)
		var size_factor: float = 0.8 + 0.2 * sin(angle)
		var color: Color = Color(1.0, 1.0, 100.0 / 255.0, 1.0)
		if sin(float(current_msec) * 0.01 + float(i)) <= 0.0:
			color = Color(1.0, 200.0 / 255.0, 50.0 / 255.0, 1.0)
		_draw_centered_question(canvas, font, center, max(18, int(28.0 * size_factor)), color, Color(50.0 / 255.0, 50.0 / 255.0, 0.0, 1.0), Vector2(2.0, 2.0))

	var center_color: Color = Color(1.0, 1.0, 150.0 / 255.0, 1.0)
	if sin(float(current_msec) * 0.015) <= 0.0:
		center_color = Color(1.0, 220.0 / 255.0, 100.0 / 255.0, 1.0)
	_draw_centered_question(canvas, font, orbit_center, 45, center_color, Color(100.0 / 255.0, 100.0 / 255.0, 50.0 / 255.0, 1.0), Vector2(3.0, 3.0))


func _draw_centered_question(
	canvas: CanvasItem,
	font: Font,
	center: Vector2,
	font_size: int,
	color: Color,
	shadow_color: Color,
	shadow_offset: Vector2
) -> void:
	var text := "?"
	var text_size: Vector2 = _get_question_text_size(font, font_size)
	var pos := center - text_size * 0.5 + Vector2(0.0, text_size.y * 0.75)
	canvas.draw_string(font, pos + shadow_offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, shadow_color)
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _get_question_text_size(font: Font, font_size: int) -> Vector2:
	if _question_size_cache.has(font_size):
		return _question_size_cache[font_size]
	var text_size: Vector2 = font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	_question_size_cache[font_size] = text_size
	return text_size


func _draw_boss_soap_indicator(
	canvas: CanvasItem,
	boss_pos: Vector2,
	boss_paddle_size: Vector2,
	boss_hitbox_height: float,
	shake_offset: Vector2,
	ratio: float
) -> void:
	var clamped_ratio: float = clamp(ratio, 0.0, 1.0)
	var bar_width: float = 60.0
	var bar_height: float = 4.0
	var bar_pos := Vector2(
		boss_pos.x + boss_paddle_size.x * 0.5 - bar_width * 0.5 + shake_offset.x,
		boss_pos.y + boss_hitbox_height * 0.5 - 38.0 + shake_offset.y
	)
	canvas.draw_rect(Rect2(bar_pos - Vector2.ONE, Vector2(bar_width + 2.0, bar_height + 2.0)), Color(40.0 / 255.0, 40.0 / 255.0, 60.0 / 255.0, 0.88))
	canvas.draw_rect(Rect2(bar_pos, Vector2(bar_width * clamped_ratio, bar_height)), Color(lerp(100.0 / 255.0, 200.0 / 255.0, clamped_ratio), lerp(180.0 / 255.0, 240.0 / 255.0, clamped_ratio), 1.0, 1.0))

	var current_msec: int = Time.get_ticks_msec()
	if clamped_ratio > 0.25 or int(float(current_msec) * 0.012) % 2 == 0:
		var bubble_center := bar_pos + Vector2(-12.0, 2.0)
		canvas.draw_circle(bubble_center, 5.0, Color(200.0 / 255.0, 230.0 / 255.0, 1.0, 0.9), false, 1.4)
		canvas.draw_circle(bubble_center + Vector2(-1.4, -1.4), 1.8, Color(1.0, 1.0, 1.0, 0.85))
		canvas.draw_circle(bubble_center + Vector2(8.0, -4.0), 3.2, Color(220.0 / 255.0, 240.0 / 255.0, 1.0, 0.7), false, 1.1)


func _draw_boss_spider_slow_wave(
	canvas: CanvasItem,
	boss_pos: Vector2,
	boss_paddle_size: Vector2,
	boss_hitbox_height: float,
	shake_offset: Vector2,
	ratio: float
) -> void:
	var clamped_ratio: float = clamp(ratio, 0.0, 1.0)
	var intensity: float = 0.45 + 0.55 * clamped_ratio
	var center := Vector2(
		boss_pos.x + boss_paddle_size.x * 0.5 + shake_offset.x,
		boss_pos.y + boss_hitbox_height * 0.5 - 18.0 + shake_offset.y
	)
	var time_phase: float = float(Time.get_ticks_msec()) * 0.006
	for i in range(4):
		var wave_ratio: float = float(i) / 3.0
		var wave_width: float = 66.0 * (1.0 - wave_ratio * 0.12)
		var wave_height: float = 18.0 + wave_ratio * 9.0
		var y_offset: float = -20.0 - float(i) * 7.0 + sin(time_phase + float(i) * 0.8) * 2.5
		var alpha: float = (0.20 - wave_ratio * 0.035) * intensity
		_draw_ellipse_outline(
			canvas,
			Rect2(center + Vector2(-wave_width * 0.5, y_offset), Vector2(wave_width, wave_height)),
			Color(110.0 / 255.0, 170.0 / 255.0, 1.0, alpha),
			2.0
		)
	canvas.draw_line(
		center + Vector2(-44.0, -12.0),
		center + Vector2(44.0, -12.0),
		Color(110.0 / 255.0, 170.0 / 255.0, 1.0, 0.18 * intensity),
		3.0
	)


func _draw_boss_cooldown_pause_marker(
	canvas: CanvasItem,
	boss_pos: Vector2,
	boss_paddle_size: Vector2,
	boss_hitbox_height: float,
	shake_offset: Vector2
) -> void:
	var center := Vector2(
		boss_pos.x + boss_paddle_size.x * 0.5 + shake_offset.x,
		boss_pos.y + boss_hitbox_height * 0.5 - 54.0 + shake_offset.y
	)
	var phase: float = float(Time.get_ticks_msec()) * 0.006
	var pulse: float = 0.55 + 0.45 * sin(phase)
	canvas.draw_circle(center, 19.0 + pulse * 3.0, Color(0.56, 0.75, 0.42, 0.16))
	canvas.draw_circle(center, 16.0, Color(0.12, 0.16, 0.12, 0.62))
	canvas.draw_arc(center, 18.0, -PI * 0.5 + phase, PI * 1.5 + phase, 32, Color(0.78, 0.95, 0.52, 0.76), 2.5)
	var bar_color := Color(0.84, 1.0, 0.64, 0.92)
	canvas.draw_rect(Rect2(center + Vector2(-6.0, -8.0), Vector2(4.0, 16.0)), bar_color)
	canvas.draw_rect(Rect2(center + Vector2(2.0, -8.0), Vector2(4.0, 16.0)), bar_color)


func _draw_ellipse_outline(canvas: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var points: PackedVector2Array = _build_ellipse_points(rect, SPIDER_WAVE_SEGMENTS)
	if points.size() < 2:
		return
	for i in range(points.size()):
		canvas.draw_line(points[i], points[(i + 1) % points.size()], color, width)


func _draw_whip_deactivation(
	canvas: CanvasItem,
	texture: Texture2D,
	source_rect: Rect2,
	center: Vector2,
	draw_size: Vector2,
	angle_degrees: float
) -> void:
	for index in range(2):
		var ghost_angle: float = angle_degrees - float(index + 1) * 30.0
		var ghost_alpha: float = 0.20 - float(index) * 0.08
		_draw_rotated_texture_region(
			canvas,
			texture,
			source_rect,
			center,
			draw_size,
			ghost_angle,
			Color(1.0, 1.0, 1.0, ghost_alpha)
		)
	_draw_rotated_texture_region(canvas, texture, source_rect, center, draw_size, angle_degrees, Color.WHITE)


func _draw_rotated_texture_region(
	canvas: CanvasItem,
	texture: Texture2D,
	source_rect: Rect2,
	center: Vector2,
	draw_size: Vector2,
	angle_degrees: float,
	modulate: Color
) -> void:
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	var half_size: Vector2 = draw_size * 0.5
	var radians: float = deg_to_rad(angle_degrees)
	var cos_a: float = cos(radians)
	var sin_a: float = sin(radians)
	var offsets := [
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	]
	var points := PackedVector2Array()
	for offset in offsets:
		points.append(center + Vector2(
			offset.x * cos_a - offset.y * sin_a,
			offset.x * sin_a + offset.y * cos_a
		))

	var uv_min := Vector2(source_rect.position.x / texture_size.x, source_rect.position.y / texture_size.y)
	var uv_max := Vector2(source_rect.end.x / texture_size.x, source_rect.end.y / texture_size.y)
	var uvs := PackedVector2Array([
		Vector2(uv_min.x, uv_min.y),
		Vector2(uv_max.x, uv_min.y),
		Vector2(uv_max.x, uv_max.y),
		Vector2(uv_min.x, uv_max.y),
	])
	var colors := PackedColorArray([modulate, modulate, modulate, modulate])
	canvas.draw_polygon(points, colors, uvs, texture)


func _draw_flipped_texture_region(
	canvas: CanvasItem,
	texture: Texture2D,
	source_rect: Rect2,
	target_rect: Rect2,
	modulate: Color
) -> void:
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	var points := PackedVector2Array([
		target_rect.position,
		Vector2(target_rect.end.x, target_rect.position.y),
		target_rect.end,
		Vector2(target_rect.position.x, target_rect.end.y),
	])
	var uv_min := Vector2(source_rect.position.x / texture_size.x, source_rect.position.y / texture_size.y)
	var uv_max := Vector2(source_rect.end.x / texture_size.x, source_rect.end.y / texture_size.y)
	var uvs := PackedVector2Array([
		Vector2(uv_max.x, uv_min.y),
		Vector2(uv_min.x, uv_min.y),
		Vector2(uv_min.x, uv_max.y),
		Vector2(uv_max.x, uv_max.y),
	])
	var colors := PackedColorArray([modulate, modulate, modulate, modulate])
	canvas.draw_polygon(points, colors, uvs, texture)


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
