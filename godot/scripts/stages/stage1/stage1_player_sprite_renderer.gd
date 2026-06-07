extends RefCounted

const Stage1ContextReader := preload("res://scripts/stages/stage1/stage1_context_reader.gd")
const PlayerCustomizationOverlayRenderer := preload("res://scripts/characters/player_customization_overlay_renderer.gd")
const ViperAirborneRenderToggles := preload("res://scripts/core/viper_airborne_render_toggles.gd")
const CharacterTopdownRimShader := preload("res://shaders/character_topdown_rim.gdshader")

const DEFAULT_PLAYER_DIRECTIONAL_WALK_GRID_COLS := 4
const DEFAULT_PLAYER_DIRECTIONAL_WALK_FRAME_COUNT := 8
const DEFAULT_PLAYER_DIRECTIONAL_DASH_GRID_COLS := 4
const DEFAULT_PLAYER_DIRECTIONAL_DASH_FRAME_COUNT := 8
const SMASHER_DASH_SEQUENCE_START_FRAME := 2
const SMASHER_DASH_HOLD_FRAME := 5
const SMASHER_DASH_HOLD_START_PROGRESS := 0.66
const WHEEL_SPIN_PREWARM_DEST_RECT := Rect2(Vector2(-4096.0, -4096.0), Vector2(1.0, 1.0))
const WHEEL_SPIN_PREWARM_TINT := Color(1.0, 1.0, 1.0, 0.01)
const DEFAULT_PLAYER_SILHOUETTE_RIM_INTENSITY := 0.65
const PLAYER_SILHOUETTE_RIM_OFFSET_PX := 2.0

static var _character_rim_shader_ready: bool = false

var customization_overlay_renderer: Object = PlayerCustomizationOverlayRenderer.new()
var _wheel_spin_prewarmed_texture: Texture2D
var _silhouette_rim_material: ShaderMaterial


static func prewarm_assets() -> void:
	_prewarm_shared_assets()


func prewarm_runtime_assets() -> void:
	_prewarm_shared_assets()


static func _prewarm_shared_assets() -> void:
	_character_rim_shader_ready = CharacterTopdownRimShader is Shader


func clear_transient_canvas_items() -> void:
	pass


func draw(
	canvas: CanvasItem,
	context: Dictionary,
	player_visual_rect: Rect2,
	player_move_active: bool,
	player_pos: Vector2,
	paddle_size: Vector2,
	shake_offset: Vector2
) -> void:
	_prewarm_wheel_spin_sheet_draw(canvas, context)
	if bool(context.get("player_victory_active", false)):
		var victory_texture = context.get("player_victory_sheet", null)
		if victory_texture is Texture2D:
			var victory_texture_typed: Texture2D = victory_texture
			_draw_texture_region(
				canvas,
				victory_texture_typed,
				player_visual_rect,
				_get_player_victory_sprite_region(context),
				context
			)
			return

	if bool(context.get("player_defeat_active", false)):
		var defeat_texture = context.get("player_defeat_sheet", null)
		if defeat_texture is Texture2D:
			var defeat_texture_typed: Texture2D = defeat_texture
			_draw_texture_region(
				canvas,
				defeat_texture_typed,
				player_visual_rect,
				_get_player_defeat_sprite_region(context),
				context
			)
			return

	# Venom Edge eye-slash strike: the viper sprite plays AT the boss's
	# position, NOT the player's, because she has appeared behind the boss
	# to slash. This is drawn before the boss (the boss layer renders after
	# the player layer in stage1_actor_renderer.draw), so the boss's body
	# automatically covers viper's lower torso/legs while her head, arms,
	# and X-cut slash effect remain visible above the boss. This is a
	# per-skill exception to the normal "draw at player_visual_rect" rule.
	if bool(context.get("viper_venom_edge_strike_active", false)) and bool(context.get("has_viper_venom_edge_strike_sheet", false)):
		var strike_texture = context.get("viper_venom_edge_strike_sheet", null)
		if strike_texture is Texture2D:
			var strike_texture_typed: Texture2D = strike_texture
			var boss_pos: Vector2 = Stage1ContextReader.as_vector2(context.get("boss_pos", Vector2.ZERO), Vector2.ZERO)
			var boss_paddle_size: Vector2 = Stage1ContextReader.as_vector2(context.get("boss_paddle_size", Vector2.ZERO), Vector2.ZERO)
			# Sprite ~2x boss paddle height so viper head + X-slash stay visible
			# above the boss, while viper legs sit behind the boss paddle.
			var strike_w: float = max(boss_paddle_size.x, 60.0)
			var strike_h: float = max(boss_paddle_size.y * 2.0, 80.0)
			var strike_rect := Rect2(
				boss_pos.x + boss_paddle_size.x * 0.5 - strike_w * 0.5 + shake_offset.x,
				boss_pos.y + boss_paddle_size.y - strike_h + shake_offset.y,
				strike_w,
				strike_h
			)
			_draw_texture_region(canvas, strike_texture_typed, strike_rect, _get_viper_venom_edge_strike_sprite_region(context), context)
			return

	# Venom Edge stationary (post-arrival, pre-strike) — viper holds Cell 1 of
	# the strike sheet at the boss's position, facing the camera. Same boss-
	# anchored rect math as the strike branch so the boss covers viper's
	# legs while her face stays visible above. Strike branch above takes
	# priority when both flags are active.
	if bool(context.get("viper_venom_edge_stationary_active", false)) and bool(context.get("has_viper_venom_edge_strike_sheet", false)):
		var stationary_texture = context.get("viper_venom_edge_strike_sheet", null)
		if stationary_texture is Texture2D:
			var stationary_texture_typed: Texture2D = stationary_texture
			var boss_pos: Vector2 = Stage1ContextReader.as_vector2(context.get("boss_pos", Vector2.ZERO), Vector2.ZERO)
			var boss_paddle_size: Vector2 = Stage1ContextReader.as_vector2(context.get("boss_paddle_size", Vector2.ZERO), Vector2.ZERO)
			var stationary_w: float = max(boss_paddle_size.x, 60.0)
			var stationary_h: float = max(boss_paddle_size.y * 2.0, 80.0)
			var stationary_rect := Rect2(
				boss_pos.x + boss_paddle_size.x * 0.5 - stationary_w * 0.5 + shake_offset.x,
				boss_pos.y + boss_paddle_size.y - stationary_h + shake_offset.y,
				stationary_w,
				stationary_h
			)
			_draw_texture_region(canvas, stationary_texture_typed, stationary_rect, _get_viper_venom_edge_stationary_sprite_region(context), context)
			return

	if bool(context.get("status_player_stun_active", false)) and bool(context.get("has_viper_stun_sheet", false)):
		var stun_texture = context.get("viper_stun_sheet", null)
		if stun_texture is Texture2D:
			var stun_texture_typed: Texture2D = stun_texture
			_draw_texture_region(canvas, stun_texture_typed, player_visual_rect, _get_viper_stun_sprite_region(context), context)
			return

	if bool(context.get("status_player_confusion_active", false)) and bool(context.get("has_viper_confusion_sheet", false)):
		var confusion_texture = context.get("viper_confusion_sheet", null)
		if confusion_texture is Texture2D:
			var confusion_texture_typed: Texture2D = confusion_texture
			_draw_texture_region(canvas, confusion_texture_typed, player_visual_rect, _get_viper_confusion_sprite_region(context), context)
			return

	if bool(context.get("player_wheel_spin_active", false)):
		var wheel_spin_texture = context.get("player_wheel_spin_sheet", null)
		if wheel_spin_texture is Texture2D:
			var wheel_spin_texture_typed: Texture2D = wheel_spin_texture
			_draw_texture_region(
				canvas,
				wheel_spin_texture_typed,
				player_visual_rect,
				_get_player_wheel_spin_sprite_region(context),
				context
			)
			return

	if bool(context.get("viper_tumble_active", false)) and bool(context.get("has_viper_tumble_sheet", false)):
		var tumble_texture = context.get("viper_tumble_sheet", null)
		if tumble_texture is Texture2D:
			var tumble_texture_typed: Texture2D = tumble_texture
			_draw_texture_region(canvas, tumble_texture_typed, player_visual_rect, _get_viper_tumble_sprite_region(context), context)
			return

	if bool(context.get("viper_blade_fire_active", false)) and bool(context.get("has_viper_blade_fire_sheet", false)):
		var blade_fire_texture = context.get("viper_blade_fire_sheet", null)
		if blade_fire_texture is Texture2D:
			var blade_fire_texture_typed: Texture2D = blade_fire_texture
			_draw_texture_region(canvas, blade_fire_texture_typed, player_visual_rect, _get_viper_blade_fire_sprite_region(context), context)
			return

	var viper_throw_active: bool = bool(context.get("viper_chaos_throw_active", false)) or bool(context.get("active_item_throw_windup_active", false))
	if viper_throw_active and bool(context.get("has_viper_throw_sheet", false)):
		var throw_texture = context.get("viper_throw_sheet", null)
		if throw_texture is Texture2D:
			var throw_texture_typed: Texture2D = throw_texture
			_draw_texture_region(canvas, throw_texture_typed, player_visual_rect, _get_viper_throw_sprite_region(context), context)
			return

	# Hover sheet plays for the full airborne window (jetpack thrust active OR
	# still above the floor while falling), so the visual stays in the hover
	# pose during gravity descent and direction changes instead of snapping
	# to standing/walking the moment thrust stops. Yields to:
	#   - player_hit_active: attack / up-kick branches own ball-contact poses
	#   - marshal/core_flip kick phases (wall_flight / wall_cling / flying_kick):
	#     those skill states have their own dedicated sheets below; hover would
	#     otherwise intercept whenever the kick begins from an airborne state
	#     because viper_jetpack_airborne stays true while offset_y is non-zero
	var hover_yields_to_kick: bool = (
		bool(context.get("viper_marshal_wall_flight_active", false))
		or bool(context.get("viper_marshal_wall_cling_active", false))
		or bool(context.get("viper_flying_kick_active", false))
	)
	if (
		bool(context.get("viper_jetpack_airborne", false))
		and not bool(context.get("player_hit_active", false))
		and not hover_yields_to_kick
		and bool(context.get("has_viper_hover_sheet", false))
		and not ViperAirborneRenderToggles.is_hover_sheet_draw_disabled()
	):
		var hover_texture = _get_viper_hover_texture(context)
		if hover_texture is Texture2D:
			var hover_texture_typed: Texture2D = hover_texture
			_draw_texture_region(canvas, hover_texture_typed, player_visual_rect, _get_viper_hover_sprite_region(context), context)
			return

	if bool(context.get("viper_flying_kick_active", false)) and bool(context.get("has_viper_flying_kick_sheet", false)):
		var flying_kick_texture = _get_viper_flying_kick_texture(context)
		if flying_kick_texture is Texture2D:
			var flying_kick_texture_typed: Texture2D = flying_kick_texture
			_draw_texture_region(canvas, flying_kick_texture_typed, player_visual_rect, _get_viper_flying_kick_sprite_region(context), context)
			return

	if bool(context.get("viper_marshal_wall_flight_active", false)) and bool(context.get("has_viper_wall_flight_sheet", false)):
		var wall_flight_texture = _get_viper_wall_flight_texture(context)
		if wall_flight_texture is Texture2D:
			var wall_flight_texture_typed: Texture2D = wall_flight_texture
			_draw_texture_region(canvas, wall_flight_texture_typed, player_visual_rect, _get_viper_wall_flight_sprite_region(context), context)
			return

	if bool(context.get("viper_marshal_wall_cling_active", false)) and bool(context.get("has_viper_wall_cling_sheet", false)):
		var wall_cling_texture = _get_viper_wall_cling_texture(context)
		if wall_cling_texture is Texture2D:
			var wall_cling_texture_typed: Texture2D = wall_cling_texture
			_draw_texture_region(canvas, wall_cling_texture_typed, player_visual_rect, _get_viper_wall_cling_sprite_region(context), context)
			return

	# Commando weapon firing / placement / control animations. These authored
	# sheets replace the failed weapon overlay approach: the weapon, grip hands,
	# arms, and body pose are drawn together for the trigger window only.
	if bool(context.get("commando_weapon_fire_active", false)):
		var weapon_fire_texture = context.get("commando_weapon_fire_sheet", null)
		if weapon_fire_texture is Texture2D:
			var weapon_fire_texture_typed: Texture2D = weapon_fire_texture
			_draw_texture_region(
				canvas,
				weapon_fire_texture_typed,
				player_visual_rect,
				_get_commando_weapon_fire_sprite_region(context, weapon_fire_texture_typed),
				context,
				bool(context.get("commando_weapon_fire_flip_h", false))
			)
			return

	# Commando pistol-fire animation overrides the ball-contact / idle / walk
	# branches while the windup or post-shot timers are running. The cell layout
	# is locked to the 4x2 grid produced by the Gemini pistol-fire sheet, and
	# the cell index comes from `battle_draw_actor_context.gd` so the muzzle
	# flash frame stays aligned with `_play_fire_audio()` (gunshot.wav).
	if bool(context.get("commando_pistol_fire_active", false)):
		var pistol_fire_texture = context.get("commando_pistol_fire_sheet", null)
		if pistol_fire_texture is Texture2D:
			var pistol_fire_texture_typed: Texture2D = pistol_fire_texture
			_draw_texture_region(
				canvas,
				pistol_fire_texture_typed,
				player_visual_rect,
				_get_commando_pistol_fire_sprite_region(context, pistol_fire_texture_typed),
				context,
				bool(context.get("commando_pistol_fire_flip_h", false))
			)
			return

	# Commando ball-strike attack: muay-thai clothesline-style squat-uppercut.
	# Triggered while `player_hit_active` is running; commando_attack_active is
	# already gated against the pistol-fire branch in actor context so they
	# never compete. Frame index reuses `player_hit_frame` since the actor
	# context advertises `player_hit_frame_count = 8` for commando.
	if bool(context.get("commando_attack_active", false)):
		var commando_attack_texture = context.get("commando_attack_sheet", null)
		if commando_attack_texture is Texture2D:
			var commando_attack_texture_typed: Texture2D = commando_attack_texture
			_draw_texture_region(
				canvas,
				commando_attack_texture_typed,
				player_visual_rect,
				_get_commando_attack_sprite_region(context),
				context,
				bool(context.get("commando_attack_flip_h", false))
			)
			return

	if bool(context.get("player_hit_active", false)) and bool(context.get("player_hit_center", false)) and bool(context.get("has_viper_up_kick_sheet", false)):
		var up_kick_texture = _get_viper_up_kick_texture(context)
		if up_kick_texture is Texture2D:
			var up_kick_texture_typed: Texture2D = up_kick_texture
			_draw_texture_region(canvas, up_kick_texture_typed, player_visual_rect, _get_viper_up_kick_sprite_region(context), context)
			return

	if bool(context.get("player_hit_active", false)):
		var directional_attack_texture = _get_player_directional_attack_texture(context)
		if directional_attack_texture is Texture2D:
			var directional_attack_texture_typed: Texture2D = directional_attack_texture
			_draw_texture_with_customization_overlays(
				canvas,
				directional_attack_texture_typed,
				player_visual_rect,
				_get_player_directional_attack_sprite_region(context),
				context,
				"attack",
				int(context.get("player_hit_frame", 0)),
				_get_hit_direction(context),
				{
					"grid_cols": int(context.get("player_directional_attack_grid_cols", PLAYER_DIRECTIONAL_ATTACK_GRID_COLS)),
					"grid_rows": int(context.get("player_directional_attack_grid_rows", PLAYER_DIRECTIONAL_ATTACK_GRID_ROWS)),
					"frame_count": int(context.get("player_hit_frame_count", PLAYER_DIRECTIONAL_ATTACK_GRID_COLS * PLAYER_DIRECTIONAL_ATTACK_GRID_ROWS)),
					"cell_width": float(context.get("player_directional_attack_cell_width", 160.0)),
					"cell_height": float(context.get("player_directional_attack_cell_height", 160.0)),
				}
			)
			return

		# Legacy Smasher attack sheet: 4x2 grid, 8 frames, cell 344x384.
		var attack_texture = context.get("player_attack_sheet", null)
		if attack_texture is Texture2D:
			var attack_texture_typed: Texture2D = attack_texture
			_draw_texture_with_customization_overlays(
				canvas,
				attack_texture_typed,
				player_visual_rect,
				_get_player_attack_sprite_region(context),
				context,
				"attack",
				int(context.get("player_hit_frame", 0)),
				_get_hit_direction(context),
				{
					"grid_cols": PLAYER_ATTACK_GRID_COLS,
					"grid_rows": PLAYER_ATTACK_GRID_ROWS,
					"frame_count": PLAYER_ATTACK_GRID_COLS * PLAYER_ATTACK_GRID_ROWS,
					"cell_width": float(context.get("player_attack_cell_width", 344.0)),
					"cell_height": float(context.get("player_attack_cell_height", 384.0)),
				}
			)
			return
		var hit_texture = context.get("player_hit_left_strip_texture", null) if int(context.get("player_hit_side", 1)) < 0 else context.get("player_hit_right_strip_texture", null)
		if hit_texture is Texture2D:
			var hit_strip_texture: Texture2D = hit_texture
			_draw_texture_region(canvas, hit_strip_texture, player_visual_rect, _get_player_hit_sprite_region(context), context)
			return
		var hit_pose_texture = context.get("player_hit_sprite_texture", null)
		if hit_pose_texture is Texture2D:
			var hit_pose_texture_typed: Texture2D = hit_pose_texture
			_draw_texture_region(canvas, hit_pose_texture_typed, player_visual_rect, Rect2(Vector2.ZERO, hit_pose_texture_typed.get_size()), context)
			return

	if bool(context.get("blacksmith_thor_shield_deploy_active", false)):
		var thor_shield_texture = context.get("blacksmith_thor_shield_deploy_sheet", null)
		if thor_shield_texture is Texture2D:
			var thor_shield_texture_typed: Texture2D = thor_shield_texture
			_draw_texture_with_customization_overlays(
				canvas,
				thor_shield_texture_typed,
				player_visual_rect,
				_get_blacksmith_thor_shield_deploy_sprite_region(context),
				context,
				"thor_shield",
				int(context.get("blacksmith_thor_shield_deploy_frame", 0)),
				"back",
				{
					"grid_cols": int(context.get("blacksmith_thor_shield_deploy_grid_cols", 4)),
					"grid_rows": int(context.get("blacksmith_thor_shield_deploy_grid_rows", 4)),
					"frame_count": int(context.get("blacksmith_thor_shield_deploy_frame_count", 16)),
					"cell_width": float(context.get("blacksmith_thor_shield_deploy_cell_width", 160.0)),
					"cell_height": float(context.get("blacksmith_thor_shield_deploy_cell_height", 160.0)),
				},
				true
			)
			return

	var idle_texture = context.get("player_idle_sprite_texture", null)
	if not player_move_active and idle_texture is Texture2D:
		var idle_texture_typed: Texture2D = idle_texture
		_draw_texture_with_customization_overlays(
			canvas,
			idle_texture_typed,
			player_visual_rect,
			_get_player_idle_sprite_region(context),
			context,
			"idle",
			int(context.get("player_idle_frame", 0)),
			"back",
			{
				"grid_cols": int(context.get("player_idle_grid_cols", 1)),
				"grid_rows": int(context.get("player_idle_grid_rows", 1)),
				"frame_count": int(context.get("player_idle_frame_count", 1)),
				"cell_width": float(context.get("player_idle_cell_width", 160.0)),
				"cell_height": float(context.get("player_idle_cell_height", 160.0)),
			},
			true
		)
		return

	if player_move_active:
		if bool(context.get("dash_active", false)) and bool(context.get("has_player_directional_dash_sheet", false)):
			var directional_dash_texture = _get_player_directional_dash_texture(context)
			if directional_dash_texture is Texture2D:
				var directional_dash_texture_typed: Texture2D = directional_dash_texture
				var directional_dash_frame: int = _get_player_directional_dash_frame(context)
				_draw_texture_with_customization_overlays(
					canvas,
					directional_dash_texture_typed,
					player_visual_rect,
					_get_player_directional_dash_region(context, directional_dash_frame),
					context,
					"dash",
					directional_dash_frame,
					_get_walk_direction(context),
					{
						"grid_cols": int(context.get("player_directional_dash_grid_cols", DEFAULT_PLAYER_DIRECTIONAL_DASH_GRID_COLS)),
						"grid_rows": 2,
						"frame_count": int(context.get("player_directional_dash_frame_count", DEFAULT_PLAYER_DIRECTIONAL_DASH_FRAME_COUNT)),
						"cell_width": float(context.get("player_directional_dash_cell_width", 160.0)),
						"cell_height": float(context.get("player_directional_dash_cell_height", 160.0)),
					},
					true
				)
				return

		var directional_walk_texture = _get_player_directional_walk_texture(context)
		if directional_walk_texture is Texture2D:
			var directional_walk_texture_typed: Texture2D = directional_walk_texture
			_draw_texture_with_customization_overlays(
				canvas,
				directional_walk_texture_typed,
				player_visual_rect,
				_get_player_directional_walk_region(context),
				context,
				_get_move_motion_id(context),
				int(context.get("player_sprite_frame", 0)),
				_get_walk_direction(context),
				{
					"grid_cols": int(context.get("player_directional_walk_grid_cols", DEFAULT_PLAYER_DIRECTIONAL_WALK_GRID_COLS)),
					"grid_rows": 2,
					"frame_count": int(context.get("player_directional_walk_frame_count", DEFAULT_PLAYER_DIRECTIONAL_WALK_FRAME_COUNT)),
					"cell_width": float(context.get("player_directional_walk_cell_width", 160.0)),
					"cell_height": float(context.get("player_directional_walk_cell_height", 160.0)),
				},
				true
			)
			return

	var sprite_texture = context.get("player_sprite_texture", null)
	if sprite_texture is Texture2D:
		var walk_texture_typed: Texture2D = sprite_texture
		_draw_texture_with_customization_overlays(
			canvas,
			walk_texture_typed,
			player_visual_rect,
			_get_player_sprite_region(context),
			context,
			_get_move_motion_id(context),
			int(context.get("player_sprite_frame", 0)),
			_get_walk_direction(context),
			{
				"grid_cols": max(1, int(context.get("player_sprite_frame_count", 6))),
				"grid_rows": 1,
				"frame_count": max(1, int(context.get("player_sprite_frame_count", 6))),
				"cell_width": float(context.get("player_sprite_frame_width", 250.0)),
				"cell_height": float(context.get("player_sprite_frame_height", 120.0)),
			},
			true
		)
		return

	draw_fallback(canvas, context, player_pos, paddle_size, shake_offset)


func _get_player_victory_sprite_region(context: Dictionary) -> Rect2:
	var cell_w: float = float(context.get("player_victory_cell_width", 160.0))
	var cell_h: float = float(context.get("player_victory_cell_height", 160.0))
	var grid_cols: int = max(1, int(context.get("player_victory_grid_cols", 4)))
	var max_frame: int = max(0, int(context.get("player_victory_frame_count", 16)) - 1)
	var frame: int = clamp(int(context.get("player_victory_frame", 0)), 0, max_frame)
	var col: int = frame % grid_cols
	@warning_ignore("integer_division")
	var row: int = int(frame / grid_cols)
	return Rect2(float(col) * cell_w, float(row) * cell_h, cell_w, cell_h)


func _get_player_defeat_sprite_region(context: Dictionary) -> Rect2:
	var cell_w: float = float(context.get("player_defeat_cell_width", 160.0))
	var cell_h: float = float(context.get("player_defeat_cell_height", 160.0))
	var grid_cols: int = max(1, int(context.get("player_defeat_grid_cols", 4)))
	var max_frame: int = max(0, int(context.get("player_defeat_frame_count", 16)) - 1)
	var frame: int = clamp(int(context.get("player_defeat_frame", 0)), 0, max_frame)
	var col: int = frame % grid_cols
	@warning_ignore("integer_division")
	var row: int = int(frame / grid_cols)
	return Rect2(float(col) * cell_w, float(row) * cell_h, cell_w, cell_h)


func _get_player_wheel_spin_sprite_region(context: Dictionary) -> Rect2:
	var cell_w: float = float(context.get("player_wheel_spin_cell_width", 160.0))
	var cell_h: float = float(context.get("player_wheel_spin_cell_height", 160.0))
	var grid_cols: int = max(1, int(context.get("player_wheel_spin_grid_cols", 8)))
	var max_frame: int = max(0, int(context.get("player_wheel_spin_frame_count", 64)) - 1)
	var frame: int = clamp(int(context.get("player_wheel_spin_frame", 32)), 0, max_frame)
	var col: int = frame % grid_cols
	@warning_ignore("integer_division")
	var row: int = int(frame / grid_cols)
	return Rect2(float(col) * cell_w, float(row) * cell_h, cell_w, cell_h)


func _prewarm_wheel_spin_sheet_draw(canvas: CanvasItem, context: Dictionary) -> void:
	if canvas == null:
		return
	var wheel_spin_texture = context.get("player_wheel_spin_sheet", null)
	if not (wheel_spin_texture is Texture2D):
		return
	var wheel_spin_texture_typed: Texture2D = wheel_spin_texture
	if _wheel_spin_prewarmed_texture == wheel_spin_texture_typed:
		return
	canvas.draw_texture_rect_region(
		wheel_spin_texture_typed,
		WHEEL_SPIN_PREWARM_DEST_RECT,
		_get_player_wheel_spin_prewarm_source_rect(context),
		WHEEL_SPIN_PREWARM_TINT,
		false,
		true
	)
	_wheel_spin_prewarmed_texture = wheel_spin_texture_typed


func _get_player_wheel_spin_prewarm_source_rect(context: Dictionary) -> Rect2:
	return _get_player_wheel_spin_sprite_region(context)


func draw_fallback(
	canvas: CanvasItem,
	context: Dictionary,
	player_pos: Vector2,
	paddle_size: Vector2,
	shake_offset: Vector2
) -> void:
	var player_color: Color = _as_color(context.get("player_color", Color(0.25, 0.45, 1.0)), Color(0.25, 0.45, 1.0))
	var player_color_light: Color = _as_color(context.get("player_color_light", Color(0.40, 0.60, 1.0)), Color(0.40, 0.60, 1.0))
	if bool(context.get("dash_recovering", false)):
		var stun_tint: Color = _get_dash_recovery_modulate()
		player_color = _multiply_rgb(player_color, stun_tint)
		player_color_light = _multiply_rgb(player_color_light, stun_tint)
	if bool(context.get("active_item_aipill_active", false)):
		player_color = _multiply_rgb(player_color, Color(0.62, 1.0, 1.25, 1.0))
		player_color_light = _multiply_rgb(player_color_light, Color(0.72, 1.0, 1.25, 1.0))
	var explicit_modulate: Color = _as_color(context.get("player_sprite_modulate", Color.WHITE), Color.WHITE)
	player_color = _multiply_rgb(player_color, explicit_modulate)
	player_color_light = _multiply_rgb(player_color_light, explicit_modulate)
	if _is_optimus_context(context):
		_draw_optimus_placeholder(
			canvas,
			context,
			player_pos,
			paddle_size,
			shake_offset,
			player_color,
			player_color_light
		)
		if bool(context.get("active_item_aipill_active", false)):
			_draw_ai_glitch_fallback(canvas, context, player_pos, paddle_size, shake_offset)
		return
	canvas.draw_rect(Rect2(player_pos + shake_offset, paddle_size), player_color)
	canvas.draw_rect(
		Rect2(player_pos.x + 2.0 + shake_offset.x, player_pos.y + 2.0 + shake_offset.y, paddle_size.x - 4.0, paddle_size.y / 3.0),
		player_color_light
	)
	if bool(context.get("active_item_aipill_active", false)):
		_draw_ai_glitch_fallback(canvas, context, player_pos, paddle_size, shake_offset)


func _is_optimus_context(context: Dictionary) -> bool:
	return str(context.get("selected_character_type", "")).strip_edges().to_lower() == "optimus"


func _draw_optimus_placeholder(
	canvas: CanvasItem,
	context: Dictionary,
	player_pos: Vector2,
	paddle_size: Vector2,
	shake_offset: Vector2,
	player_color: Color,
	player_color_light: Color
) -> void:
	var origin := player_pos + shake_offset
	var energy_ratio: float = clampf(float(context.get("player_energy_ratio", context.get("optimus_energy_ratio", 1.0))), 0.0, 1.0)
	var body_rect := Rect2(origin, paddle_size)
	var body_alpha: float = 0.36 + energy_ratio * 0.22
	canvas.draw_rect(body_rect, Color(player_color.r, player_color.g, player_color.b, body_alpha))

	var inset_x: float = min(12.0, paddle_size.x * 0.12)
	var inset_y: float = min(10.0, paddle_size.y * 0.16)
	var inner_rect := Rect2(
		origin + Vector2(inset_x, inset_y),
		Vector2(max(1.0, paddle_size.x - inset_x * 2.0), max(1.0, paddle_size.y - inset_y * 2.0))
	)
	canvas.draw_rect(inner_rect, Color(player_color_light.r, player_color_light.g, player_color_light.b, 0.26 + energy_ratio * 0.24), false, 2.0)

	var center := body_rect.get_center()
	var core_radius: float = clampf(min(paddle_size.x, paddle_size.y) * 0.16, 7.0, 24.0)
	canvas.draw_circle(center, core_radius * 1.65, Color(0.35, 0.95, 1.0, 0.10 + energy_ratio * 0.18))
	canvas.draw_circle(center, core_radius, Color(player_color_light.r, player_color_light.g, player_color_light.b, 0.58 + energy_ratio * 0.28))
	canvas.draw_circle(center, core_radius * 0.45, Color(1.0, 1.0, 1.0, 0.55 + energy_ratio * 0.35))

	var rail_height: float = clampf(paddle_size.y * 0.12, 4.0, 14.0)
	canvas.draw_rect(
		Rect2(origin.x + inset_x, origin.y + inset_y, inner_rect.size.x, rail_height),
		Color(1.0, 1.0, 1.0, 0.20 + energy_ratio * 0.18)
	)
	canvas.draw_rect(
		Rect2(origin.x + inset_x, origin.y + paddle_size.y - inset_y - rail_height, inner_rect.size.x, rail_height),
		Color(0.05, 0.22, 0.35, 0.28)
	)

	var pod_width: float = clampf(paddle_size.x * 0.08, 4.0, 14.0)
	var pod_height: float = max(6.0, paddle_size.y * 0.52)
	var pod_y: float = center.y - pod_height * 0.5
	canvas.draw_rect(
		Rect2(origin.x + inset_x * 0.35, pod_y, pod_width, pod_height),
		Color(player_color_light.r, player_color_light.g, player_color_light.b, 0.34 + energy_ratio * 0.22)
	)
	canvas.draw_rect(
		Rect2(origin.x + paddle_size.x - inset_x * 0.35 - pod_width, pod_y, pod_width, pod_height),
		Color(player_color_light.r, player_color_light.g, player_color_light.b, 0.34 + energy_ratio * 0.22)
	)


func _get_player_idle_sprite_region(context: Dictionary) -> Rect2:
	var grid_cols: int = int(context.get("player_idle_grid_cols", 1))
	var grid_rows: int = int(context.get("player_idle_grid_rows", 1))
	if grid_cols > 1 and grid_rows > 1:
		var cell_w: float = float(context.get("player_idle_cell_width", 160.0))
		var cell_h: float = float(context.get("player_idle_cell_height", 160.0))
		var max_frame: int = max(0, grid_cols * grid_rows - 1)
		var frame: int = clamp(int(context.get("player_idle_frame", 0)), 0, max_frame)
		var col: int = frame % grid_cols
		@warning_ignore("integer_division")
		var row: int = int(frame / grid_cols)
		return Rect2(float(col) * cell_w, float(row) * cell_h, cell_w, cell_h)
	var frame_x: float = float(context.get("player_sprite_frame_width", 250.0)) * float(context.get("player_idle_frame", 0))
	return Rect2(frame_x, 0.0, float(context.get("player_sprite_frame_width", 250.0)), float(context.get("player_sprite_frame_height", 120.0)))


func _get_player_hit_sprite_region(context: Dictionary) -> Rect2:
	var frame_x: float = float(context.get("player_hit_frame_width", 250.0)) * float(context.get("player_hit_frame", 0))
	return Rect2(frame_x, 0.0, float(context.get("player_hit_frame_width", 250.0)), float(context.get("player_hit_frame_height", 120.0)))


func _get_blacksmith_thor_shield_deploy_sprite_region(context: Dictionary) -> Rect2:
	var cell_w: float = float(context.get("blacksmith_thor_shield_deploy_cell_width", 160.0))
	var cell_h: float = float(context.get("blacksmith_thor_shield_deploy_cell_height", 160.0))
	var grid_cols: int = max(1, int(context.get("blacksmith_thor_shield_deploy_grid_cols", 4)))
	var frame_count: int = max(1, int(context.get("blacksmith_thor_shield_deploy_frame_count", 16)))
	var frame: int = clamp(int(context.get("blacksmith_thor_shield_deploy_frame", 0)), 0, frame_count - 1)
	var col: int = frame % grid_cols
	@warning_ignore("integer_division")
	var row: int = int(frame / grid_cols)
	return Rect2(float(col) * cell_w, float(row) * cell_h, cell_w, cell_h)


# Directional Smasher attack sheets: 4x4 grids, 16 frames total, default
# cell 160x160. Maps `player_hit_frame` (0..15) onto the same row-major
# layout used by the generated PNGs.
const PLAYER_DIRECTIONAL_ATTACK_GRID_COLS := 4
const PLAYER_DIRECTIONAL_ATTACK_GRID_ROWS := 4


func _get_viper_up_kick_texture(context: Dictionary) -> Variant:
	var side: int = int(context.get("player_hit_side", context.get("player_walk_direction", 1)))
	var primary_key := "viper_up_kick_left_sheet" if side < 0 else "viper_up_kick_right_sheet"
	var fallback_key := "viper_up_kick_right_sheet" if side < 0 else "viper_up_kick_left_sheet"
	var texture = context.get(primary_key, null)
	if texture is Texture2D:
		return texture
	return context.get(fallback_key, null)


func _get_viper_up_kick_sprite_region(context: Dictionary) -> Rect2:
	var cell_w: float = float(context.get("viper_up_kick_cell_width", 160.0))
	var cell_h: float = float(context.get("viper_up_kick_cell_height", 160.0))
	var grid_cols: int = max(1, int(context.get("viper_up_kick_grid_cols", 4)))
	var frame_count: int = max(1, int(context.get("viper_up_kick_frame_count", 8)))
	var hit_frame: int = int(context.get("player_hit_frame", 0))
	var frame: int = clamp(hit_frame, 0, frame_count - 1)
	var col: int = frame % grid_cols
	@warning_ignore("integer_division")
	var row: int = int(frame / grid_cols)
	return Rect2(float(col) * cell_w, float(row) * cell_h, cell_w, cell_h)


func _get_viper_hover_texture(context: Dictionary) -> Variant:
	var direction: int = int(context.get("player_walk_direction", 1))
	var primary_key := "viper_hover_left_sheet" if direction < 0 else "viper_hover_right_sheet"
	var fallback_key := "viper_hover_right_sheet" if direction < 0 else "viper_hover_left_sheet"
	var texture = context.get(primary_key, null)
	if texture is Texture2D:
		return texture
	return context.get(fallback_key, null)


func _get_viper_hover_sprite_region(context: Dictionary) -> Rect2:
	var cell_w: float = float(context.get("viper_hover_cell_width", 160.0))
	var cell_h: float = float(context.get("viper_hover_cell_height", 160.0))
	var grid_cols: int = max(1, int(context.get("viper_hover_grid_cols", 4)))
	var frame_count: int = max(1, int(context.get("viper_hover_frame_count", 8)))
	var time_ms: int = Time.get_ticks_msec()
	@warning_ignore("integer_division")
	var frame: int = (time_ms / 100) % frame_count
	var col: int = frame % grid_cols
	@warning_ignore("integer_division")
	var row: int = int(frame / grid_cols)
	return Rect2(float(col) * cell_w, float(row) * cell_h, cell_w, cell_h)


# Stun sheet: 8 looping frames, 80ms/cell (640ms full cycle) — fast crackle
# matches the electricity-flicker read used by Dalji boss stun.
func _get_viper_stun_sprite_region(context: Dictionary) -> Rect2:
	var cell_w: float = float(context.get("viper_stun_cell_width", 160.0))
	var cell_h: float = float(context.get("viper_stun_cell_height", 160.0))
	var grid_cols: int = max(1, int(context.get("viper_stun_grid_cols", 4)))
	var frame_count: int = max(1, int(context.get("viper_stun_frame_count", 8)))
	var time_ms: int = Time.get_ticks_msec()
	@warning_ignore("integer_division")
	var frame: int = (time_ms / 80) % frame_count
	var col: int = frame % grid_cols
	@warning_ignore("integer_division")
	var row: int = int(frame / grid_cols)
	return Rect2(float(col) * cell_w, float(row) * cell_h, cell_w, cell_h)


# Confusion sheet: 8 looping frames, 150ms/cell (1.2s full cycle) — slower
# wobble pace so the lean-left → lean-right body sway reads as disoriented.
func _get_viper_confusion_sprite_region(context: Dictionary) -> Rect2:
	var cell_w: float = float(context.get("viper_confusion_cell_width", 160.0))
	var cell_h: float = float(context.get("viper_confusion_cell_height", 160.0))
	var grid_cols: int = max(1, int(context.get("viper_confusion_grid_cols", 4)))
	var frame_count: int = max(1, int(context.get("viper_confusion_frame_count", 8)))
	var time_ms: int = Time.get_ticks_msec()
	@warning_ignore("integer_division")
	var frame: int = (time_ms / 150) % frame_count
	var col: int = frame % grid_cols
	@warning_ignore("integer_division")
	var row: int = int(frame / grid_cols)
	return Rect2(float(col) * cell_w, float(row) * cell_h, cell_w, cell_h)


# Venom Edge eye-slash strike: NOT time-driven (unlike stun/confusion loops).
# Frame index is supplied by viper_skill_runtime.gd via the
# `viper_venom_edge_strike_frame` context key — that runtime advances the
# frame counter while the strike state machine is active and clears it back
# to 0 when the 8-frame strike completes. Cells 4-5 contain the bright
# X-cut peak which is the gameplay impact frame.
func _get_viper_venom_edge_strike_sprite_region(context: Dictionary) -> Rect2:
	var cell_w: float = float(context.get("viper_venom_edge_strike_cell_width", 160.0))
	var cell_h: float = float(context.get("viper_venom_edge_strike_cell_height", 160.0))
	var grid_cols: int = max(1, int(context.get("viper_venom_edge_strike_grid_cols", 4)))
	var frame_count: int = max(1, int(context.get("viper_venom_edge_strike_frame_count", 8)))
	var frame: int = clamp(int(context.get("viper_venom_edge_strike_frame", 0)), 0, frame_count - 1)
	var col: int = frame % grid_cols
	@warning_ignore("integer_division")
	var row: int = int(frame / grid_cols)
	return Rect2(float(col) * cell_w, float(row) * cell_h, cell_w, cell_h)


# Stationary pose: always Cell 1 (index 0) of the strike sheet — the
# arrival-pose frame where viper stands front-facing with arms drawn back
# at sides, before any slash motion begins.
func _get_viper_venom_edge_stationary_sprite_region(context: Dictionary) -> Rect2:
	var cell_w: float = float(context.get("viper_venom_edge_strike_cell_width", 160.0))
	var cell_h: float = float(context.get("viper_venom_edge_strike_cell_height", 160.0))
	return Rect2(0.0, 0.0, cell_w, cell_h)


func _get_viper_throw_sprite_region(context: Dictionary) -> Rect2:
	var cell_w: float = float(context.get("viper_throw_cell_width", 160.0))
	var cell_h: float = float(context.get("viper_throw_cell_height", 160.0))
	var grid_cols: int = max(1, int(context.get("viper_throw_grid_cols", 4)))
	var frame_count: int = max(1, int(context.get("viper_throw_frame_count", 8)))
	var time_ms: int = Time.get_ticks_msec()
	@warning_ignore("integer_division")
	var frame: int = (time_ms / 60) % frame_count
	var col: int = frame % grid_cols
	@warning_ignore("integer_division")
	var row: int = int(frame / grid_cols)
	return Rect2(float(col) * cell_w, float(row) * cell_h, cell_w, cell_h)


func _get_viper_blade_fire_sprite_region(context: Dictionary) -> Rect2:
	var cell_w: float = float(context.get("viper_blade_fire_cell_width", 160.0))
	var cell_h: float = float(context.get("viper_blade_fire_cell_height", 160.0))
	var grid_cols: int = max(1, int(context.get("viper_blade_fire_grid_cols", 4)))
	var frame_count: int = max(1, int(context.get("viper_blade_fire_frame_count", 8)))
	var time_ms: int = Time.get_ticks_msec()
	@warning_ignore("integer_division")
	var frame: int = (time_ms / 60) % frame_count
	var col: int = frame % grid_cols
	@warning_ignore("integer_division")
	var row: int = int(frame / grid_cols)
	return Rect2(float(col) * cell_w, float(row) * cell_h, cell_w, cell_h)


func _get_viper_tumble_sprite_region(context: Dictionary) -> Rect2:
	var cell_w: float = float(context.get("viper_tumble_cell_width", 160.0))
	var cell_h: float = float(context.get("viper_tumble_cell_height", 160.0))
	var grid_cols: int = max(1, int(context.get("viper_tumble_grid_cols", 4)))
	var frame_count: int = max(1, int(context.get("viper_tumble_frame_count", 8)))
	var time_ms: int = Time.get_ticks_msec()
	@warning_ignore("integer_division")
	var frame: int = (time_ms / 80) % frame_count
	var col: int = frame % grid_cols
	@warning_ignore("integer_division")
	var row: int = int(frame / grid_cols)
	return Rect2(float(col) * cell_w, float(row) * cell_h, cell_w, cell_h)


func _get_viper_flying_kick_texture(context: Dictionary) -> Variant:
	var dir: int = int(context.get("viper_flying_kick_dir", 0))
	var primary_key := "viper_flying_kick_left_sheet" if dir < 0 else "viper_flying_kick_right_sheet"
	var fallback_key := "viper_flying_kick_right_sheet" if dir < 0 else "viper_flying_kick_left_sheet"
	var texture = context.get(primary_key, null)
	if texture is Texture2D:
		return texture
	return context.get(fallback_key, null)


func _get_viper_flying_kick_sprite_region(context: Dictionary) -> Rect2:
	var cell_w: float = float(context.get("viper_flying_kick_cell_width", 160.0))
	var cell_h: float = float(context.get("viper_flying_kick_cell_height", 160.0))
	var grid_cols: int = max(1, int(context.get("viper_flying_kick_grid_cols", 4)))
	var frame_count: int = max(1, int(context.get("viper_flying_kick_frame_count", 8)))
	var time_ms: int = Time.get_ticks_msec()
	@warning_ignore("integer_division")
	var frame: int = (time_ms / 70) % frame_count
	var col: int = frame % grid_cols
	@warning_ignore("integer_division")
	var row: int = int(frame / grid_cols)
	return Rect2(float(col) * cell_w, float(row) * cell_h, cell_w, cell_h)


func _get_viper_wall_flight_texture(context: Dictionary) -> Variant:
	var side: int = int(context.get("viper_marshal_wall_side", 1))
	var primary_key := "viper_wall_flight_left_sheet" if side < 0 else "viper_wall_flight_right_sheet"
	var fallback_key := "viper_wall_flight_right_sheet" if side < 0 else "viper_wall_flight_left_sheet"
	var texture = context.get(primary_key, null)
	if texture is Texture2D:
		return texture
	return context.get(fallback_key, null)


func _get_viper_wall_flight_sprite_region(context: Dictionary) -> Rect2:
	var cell_w: float = float(context.get("viper_wall_flight_cell_width", 160.0))
	var cell_h: float = float(context.get("viper_wall_flight_cell_height", 160.0))
	var grid_cols: int = max(1, int(context.get("viper_wall_flight_grid_cols", 4)))
	var frame_count: int = max(1, int(context.get("viper_wall_flight_frame_count", 8)))
	var time_ms: int = Time.get_ticks_msec()
	@warning_ignore("integer_division")
	var frame: int = (time_ms / 80) % frame_count
	var col: int = frame % grid_cols
	@warning_ignore("integer_division")
	var row: int = int(frame / grid_cols)
	return Rect2(float(col) * cell_w, float(row) * cell_h, cell_w, cell_h)


func _get_viper_wall_cling_texture(context: Dictionary) -> Variant:
	var side: int = int(context.get("viper_marshal_wall_side", 1))
	var primary_key := "viper_wall_cling_left_sheet" if side < 0 else "viper_wall_cling_right_sheet"
	var fallback_key := "viper_wall_cling_right_sheet" if side < 0 else "viper_wall_cling_left_sheet"
	var texture = context.get(primary_key, null)
	if texture is Texture2D:
		return texture
	return context.get(fallback_key, null)


func _get_viper_wall_cling_sprite_region(context: Dictionary) -> Rect2:
	var cell_w: float = float(context.get("viper_wall_cling_cell_width", 160.0))
	var cell_h: float = float(context.get("viper_wall_cling_cell_height", 160.0))
	var grid_cols: int = max(1, int(context.get("viper_wall_cling_grid_cols", 4)))
	var time_ms: int = Time.get_ticks_msec()
	@warning_ignore("integer_division")
	var frame: int = 3 + ((time_ms / 250) % 2)
	var col: int = frame % grid_cols
	@warning_ignore("integer_division")
	var row: int = int(frame / grid_cols)
	return Rect2(float(col) * cell_w, float(row) * cell_h, cell_w, cell_h)


func _get_player_directional_attack_texture(context: Dictionary) -> Variant:
	var side: int = int(context.get("player_hit_side", context.get("player_walk_direction", 1)))
	var primary_key := "player_attack_left_sheet" if side < 0 else "player_attack_right_sheet"
	var fallback_key := "player_attack_right_sheet" if side < 0 else "player_attack_left_sheet"
	var texture = context.get(primary_key, null)
	if texture is Texture2D:
		return texture
	return context.get(fallback_key, null)


func _get_player_directional_attack_sprite_region(context: Dictionary) -> Rect2:
	var cell_w: float = float(context.get("player_directional_attack_cell_width", 160.0))
	var cell_h: float = float(context.get("player_directional_attack_cell_height", 160.0))
	var grid_cols: int = max(1, int(context.get("player_directional_attack_grid_cols", PLAYER_DIRECTIONAL_ATTACK_GRID_COLS)))
	var grid_rows: int = max(1, int(context.get("player_directional_attack_grid_rows", PLAYER_DIRECTIONAL_ATTACK_GRID_ROWS)))
	var max_frame: int = grid_cols * grid_rows - 1
	var frame: int = clamp(int(context.get("player_hit_frame", 0)), 0, max_frame)
	var col: int = frame % grid_cols
	@warning_ignore("integer_division")
	var row: int = int(frame / grid_cols)
	return Rect2(float(col) * cell_w, float(row) * cell_h, cell_w, cell_h)


# Legacy Smasher attack sheet: 4x2 grid (4 columns x 2 rows), 8 frames total, default
# cell 344x384. Maps `player_hit_frame` (0..7) onto the grid: row = frame // 4,
# col = frame % 4. Defaults match the shipped 1376x768 PNG.
const PLAYER_ATTACK_GRID_COLS := 4
const PLAYER_ATTACK_GRID_ROWS := 2


func _get_player_attack_sprite_region(context: Dictionary) -> Rect2:
	var cell_w: float = float(context.get("player_attack_cell_width", 344.0))
	var cell_h: float = float(context.get("player_attack_cell_height", 384.0))
	var max_frame: int = PLAYER_ATTACK_GRID_COLS * PLAYER_ATTACK_GRID_ROWS - 1
	var frame: int = clamp(int(context.get("player_hit_frame", 0)), 0, max_frame)
	var col: int = frame % PLAYER_ATTACK_GRID_COLS
	@warning_ignore("integer_division")
	var row: int = int(frame / PLAYER_ATTACK_GRID_COLS)
	return Rect2(float(col) * cell_w, float(row) * cell_h, cell_w, cell_h)


# Commando pistol-fire sheet: 4x2 grid, 8 frames, back view. Cell size is
# derived from the actual texture so the helper works regardless of the
# source PNG resolution (current ship asset is 1264x848 -> cell 316x424).
# Frame 0..3 = windup (raise the pistol), 4 = muzzle flash, 5 = smoke,
# 6 = lowering, 7 = return to ready.
func _get_commando_pistol_fire_sprite_region(context: Dictionary, texture: Texture2D) -> Rect2:
	var grid_cols: int = max(1, int(context.get("commando_pistol_fire_grid_cols", 4)))
	var grid_rows: int = max(1, int(context.get("commando_pistol_fire_grid_rows", 2)))
	var max_frame: int = max(0, int(context.get("commando_pistol_fire_frame_count", grid_cols * grid_rows)) - 1)
	var frame: int = clamp(int(context.get("commando_pistol_fire_frame", 0)), 0, max_frame)
	var col: int = frame % grid_cols
	@warning_ignore("integer_division")
	var row: int = int(frame / grid_cols)
	var texture_size: Vector2 = texture.get_size()
	var cell_w: float = texture_size.x / float(grid_cols)
	var cell_h: float = texture_size.y / float(grid_rows)
	return Rect2(float(col) * cell_w, float(row) * cell_h, cell_w, cell_h)


func _get_commando_weapon_fire_sprite_region(context: Dictionary, texture: Texture2D) -> Rect2:
	var grid_cols: int = max(1, int(context.get("commando_weapon_fire_grid_cols", 4)))
	var grid_rows: int = max(1, int(context.get("commando_weapon_fire_grid_rows", 2)))
	var max_frame: int = max(0, int(context.get("commando_weapon_fire_frame_count", grid_cols * grid_rows)) - 1)
	var frame: int = clamp(int(context.get("commando_weapon_fire_frame", 0)), 0, max_frame)
	var col: int = frame % grid_cols
	@warning_ignore("integer_division")
	var row: int = int(frame / grid_cols)
	var texture_size: Vector2 = texture.get_size()
	var cell_w: float = texture_size.x / float(grid_cols)
	var cell_h: float = texture_size.y / float(grid_rows)
	return Rect2(float(col) * cell_w, float(row) * cell_h, cell_w, cell_h)


# Commando ball-strike attack sheet: 640x320 PNG, 4x2 grid, 8 frames at
# cell 160x160, back view. Squat-uppercut sequence: F0 standing ready,
# F1-F3 squat coil, F4-F5 rising uppercut (F5 ball-contact peak),
# F6-F7 follow-through and recover. The frame index comes from
# `player_hit_frame` because the actor context advertises a hit frame
# count of 8 when the commando attack sheet is loaded.
func _get_commando_attack_sprite_region(context: Dictionary) -> Rect2:
	var cell_w: float = float(context.get("commando_attack_cell_width", 160.0))
	var cell_h: float = float(context.get("commando_attack_cell_height", 160.0))
	var grid_cols: int = max(1, int(context.get("commando_attack_grid_cols", 4)))
	var max_frame: int = max(0, int(context.get("commando_attack_frame_count", 8)) - 1)
	var frame: int = clamp(int(context.get("player_hit_frame", 0)), 0, max_frame)
	var col: int = frame % grid_cols
	@warning_ignore("integer_division")
	var row: int = int(frame / grid_cols)
	return Rect2(float(col) * cell_w, float(row) * cell_h, cell_w, cell_h)


func _get_player_directional_walk_texture(context: Dictionary) -> Variant:
	var direction: int = int(context.get("player_walk_direction", 1))
	var texture_key := "player_walk_left_texture" if direction < 0 else "player_walk_right_texture"
	return context.get(texture_key, null)


func _get_player_directional_dash_texture(context: Dictionary) -> Variant:
	var direction: int = int(context.get("player_walk_direction", 1))
	var primary_key := "player_dash_left_texture" if direction < 0 else "player_dash_right_texture"
	var fallback_key := "player_dash_right_texture" if direction < 0 else "player_dash_left_texture"
	var texture = context.get(primary_key, null)
	if texture is Texture2D:
		return texture
	return context.get(fallback_key, null)


func _get_player_directional_dash_region(context: Dictionary, frame_override: int = -1) -> Rect2:
	var cell_w: float = float(context.get("player_directional_dash_cell_width", 160.0))
	var cell_h: float = float(context.get("player_directional_dash_cell_height", 160.0))
	var grid_cols: int = max(1, int(context.get("player_directional_dash_grid_cols", DEFAULT_PLAYER_DIRECTIONAL_DASH_GRID_COLS)))
	var max_frame: int = max(0, int(context.get("player_directional_dash_frame_count", DEFAULT_PLAYER_DIRECTIONAL_DASH_FRAME_COUNT)) - 1)
	var frame: int = clamp(frame_override if frame_override >= 0 else _get_player_directional_dash_frame(context), 0, max_frame)
	var col: int = frame % grid_cols
	@warning_ignore("integer_division")
	var row: int = int(frame / grid_cols)
	return Rect2(float(col) * cell_w, float(row) * cell_h, cell_w, cell_h)


func _get_player_directional_dash_frame(context: Dictionary) -> int:
	var max_frame: int = max(0, int(context.get("player_directional_dash_frame_count", DEFAULT_PLAYER_DIRECTIONAL_DASH_FRAME_COUNT)) - 1)
	var fallback_frame: int = clamp(int(context.get("player_sprite_frame", 0)), 0, max_frame)
	if not _should_use_smasher_dash_hold_sequence(context, max_frame):
		return fallback_frame
	var elapsed_frames: float = max(0.0, float(context.get("dash_elapsed_frames", 0.0)))
	var remaining_frames: float = max(0.0, float(context.get("dash_timer", 0.0)))
	var total_frames: float = elapsed_frames + remaining_frames
	if total_frames <= 0.001:
		return fallback_frame
	var progress: float = clamp(elapsed_frames / total_frames, 0.0, 1.0)
	var start_frame: int = min(SMASHER_DASH_SEQUENCE_START_FRAME, max_frame)
	var hold_frame: int = min(SMASHER_DASH_HOLD_FRAME, max_frame)
	if hold_frame <= start_frame:
		return fallback_frame
	if progress >= SMASHER_DASH_HOLD_START_PROGRESS:
		return hold_frame
	var lead_progress: float = clamp(progress / SMASHER_DASH_HOLD_START_PROGRESS, 0.0, 0.999)
	var span: int = max(1, hold_frame - start_frame + 1)
	return clamp(start_frame + int(floor(lead_progress * float(span))), start_frame, hold_frame)


func _should_use_smasher_dash_hold_sequence(context: Dictionary, max_frame: int) -> bool:
	if max_frame < SMASHER_DASH_HOLD_FRAME:
		return false
	if not bool(context.get("dash_active", false)):
		return false
	var character_type: String = str(context.get("selected_character_type", "smasher"))
	return character_type == "smasher"


func _get_player_directional_walk_region(context: Dictionary) -> Rect2:
	var cell_w: float = float(context.get("player_directional_walk_cell_width", 160.0))
	var cell_h: float = float(context.get("player_directional_walk_cell_height", 160.0))
	var grid_cols: int = max(1, int(context.get("player_directional_walk_grid_cols", DEFAULT_PLAYER_DIRECTIONAL_WALK_GRID_COLS)))
	var max_frame: int = max(0, int(context.get("player_directional_walk_frame_count", DEFAULT_PLAYER_DIRECTIONAL_WALK_FRAME_COUNT)) - 1)
	var frame: int = clamp(int(context.get("player_sprite_frame", 0)), 0, max_frame)
	var col: int = frame % grid_cols
	@warning_ignore("integer_division")
	var row: int = int(frame / grid_cols)
	return Rect2(float(col) * cell_w, float(row) * cell_h, cell_w, cell_h)


func _get_player_sprite_region(context: Dictionary) -> Rect2:
	var frame_x: float = float(context.get("player_sprite_frame_width", 250.0)) * float(context.get("player_sprite_frame", 0))
	return Rect2(frame_x, 0.0, float(context.get("player_sprite_frame_width", 250.0)), float(context.get("player_sprite_frame_height", 120.0)))


func _draw_texture_with_customization_overlays(
	canvas: CanvasItem,
	texture: Texture2D,
	dest_rect: Rect2,
	source_rect: Rect2,
	context: Dictionary,
	motion_id: String,
	frame_index: int,
	direction: String,
	metadata: Dictionary,
	enable_silhouette_rim: bool = false
) -> void:
	var overlay_metadata: Dictionary = metadata.duplicate(true)
	overlay_metadata["direction"] = direction
	var base_plan: Dictionary = customization_overlay_renderer.build_base_plan(
		motion_id,
		frame_index,
		dest_rect,
		source_rect,
		context,
		overlay_metadata
	)
	customization_overlay_renderer.draw_layer(canvas, context, base_plan, "back")
	_draw_texture_region(canvas, texture, dest_rect, source_rect, context, false, enable_silhouette_rim)
	customization_overlay_renderer.draw_layer(canvas, context, base_plan, "front")


func _get_hit_direction(context: Dictionary) -> String:
	return "left" if int(context.get("player_hit_side", context.get("player_walk_direction", 1))) < 0 else "right"


func _get_walk_direction(context: Dictionary) -> String:
	return "left" if int(context.get("player_walk_direction", 1)) < 0 else "right"


func _get_move_motion_id(context: Dictionary) -> String:
	return "dash" if bool(context.get("dash_active", false)) else "walk"


func _draw_texture_region(
	canvas: CanvasItem,
	texture: Texture2D,
	dest_rect: Rect2,
	source_rect: Rect2,
	context: Dictionary,
	flip_h: bool = false,
	enable_silhouette_rim: bool = false
) -> void:
	var sprite_modulate: Color = _get_player_sprite_modulate(context)
	var angle_degrees: float = float(context.get("player_sprite_rotation_degrees", 0.0))
	if bool(context.get("active_item_aipill_active", false)) and abs(angle_degrees) <= 0.01 and not flip_h:
		_draw_ai_glitch_texture_region(canvas, texture, dest_rect, source_rect, context, sprite_modulate)
		return
	if abs(angle_degrees) <= 0.01:
		if flip_h:
			_draw_flipped_texture_region(canvas, texture, source_rect, dest_rect, sprite_modulate)
		else:
			if enable_silhouette_rim and _silhouette_rim_should_apply(context, texture, dest_rect):
				_draw_with_silhouette_rim(canvas, texture, dest_rect, source_rect, context, sprite_modulate)
			else:
				canvas.draw_texture_rect_region(texture, dest_rect, source_rect, sprite_modulate, false, true)
		return
	_draw_rotated_texture_region(canvas, texture, source_rect, dest_rect.get_center(), dest_rect.size, angle_degrees, sprite_modulate, flip_h)


func _silhouette_rim_should_apply(context: Dictionary, texture: Texture2D, dest_rect: Rect2) -> bool:
	if texture == null:
		return false
	if not bool(context.get("stage1_player_silhouette_rim_enabled", true)):
		return false
	if bool(context.get("active_item_aipill_active", false)):
		return false
	var intensity: float = clamp(
		float(context.get("stage1_player_rim_intensity", DEFAULT_PLAYER_SILHOUETTE_RIM_INTENSITY)),
		0.0,
		1.0
	)
	if intensity <= 0.001 or dest_rect.size.x <= 0.0 or dest_rect.size.y <= 0.0:
		return false
	return true


func _draw_with_silhouette_rim(
	canvas: CanvasItem,
	texture: Texture2D,
	dest_rect: Rect2,
	source_rect: Rect2,
	context: Dictionary,
	sprite_modulate: Color
) -> void:
	if canvas == null:
		return
	var material: ShaderMaterial = _get_silhouette_rim_material()
	if material == null:
		canvas.draw_texture_rect_region(texture, dest_rect, source_rect, sprite_modulate, false, true)
		return
	var intensity: float = clamp(
		float(context.get("stage1_player_rim_intensity", DEFAULT_PLAYER_SILHOUETTE_RIM_INTENSITY)),
		0.0,
		1.0
	)
	material.set_shader_parameter("rim_intensity", intensity)
	material.set_shader_parameter("rim_color", _as_color(
		context.get("stage1_player_rim_color", Color(0.85, 0.95, 1.0, 1.0)),
		Color(0.85, 0.95, 1.0, 1.0)
	))
	material.set_shader_parameter("rim_offset_px", float(context.get(
		"stage1_player_rim_offset_px",
		PLAYER_SILHOUETTE_RIM_OFFSET_PX
	)))
	material.set_shader_parameter("sprite_pixel_size", Vector2(
		max(1.0, float(texture.get_width())),
		max(1.0, float(texture.get_height()))
	))
	var prev_material: Material = canvas.material
	canvas.material = material
	canvas.draw_texture_rect_region(texture, dest_rect, source_rect, sprite_modulate, false, true)
	canvas.material = prev_material


func _get_silhouette_rim_material() -> ShaderMaterial:
	if _silhouette_rim_material != null:
		return _silhouette_rim_material
	var material := ShaderMaterial.new()
	material.shader = CharacterTopdownRimShader
	material.set_shader_parameter("rim_intensity", DEFAULT_PLAYER_SILHOUETTE_RIM_INTENSITY)
	material.set_shader_parameter("rim_color", Color(0.85, 0.95, 1.0, 1.0))
	material.set_shader_parameter("rim_offset_px", PLAYER_SILHOUETTE_RIM_OFFSET_PX)
	_silhouette_rim_material = material
	return _silhouette_rim_material


func _draw_ai_glitch_texture_region(
	canvas: CanvasItem,
	texture: Texture2D,
	dest_rect: Rect2,
	source_rect: Rect2,
	context: Dictionary,
	sprite_modulate: Color
) -> void:
	var phase: float = float(context.get("active_item_aipill_phase", 0.0))
	canvas.draw_texture_rect_region(texture, dest_rect, source_rect, sprite_modulate, false, true)

	var slice_count := 9
	var dest_slice_h: float = max(4.0, dest_rect.size.y / float(slice_count))
	var source_slice_h: float = source_rect.size.y * dest_slice_h / max(1.0, dest_rect.size.y)
	for i in range(slice_count):
		var slice_y: float = min(dest_rect.size.y, float(i) * dest_slice_h)
		if slice_y >= dest_rect.size.y:
			break
		var slice_h: float = min(dest_slice_h, dest_rect.size.y - slice_y)
		var source_h: float = source_rect.size.y * slice_h / max(1.0, dest_rect.size.y)
		var shift: float = round(sin(phase + float(i) * 0.6) * 5.0)
		var dest_slice := Rect2(
			dest_rect.position + Vector2(shift, slice_y),
			Vector2(dest_rect.size.x, slice_h)
		)
		var source_slice := Rect2(
			source_rect.position + Vector2(0.0, float(i) * source_slice_h),
			Vector2(source_rect.size.x, source_h)
		)
		var tint_alpha: float = (50.0 + float(i % 3) * 25.0) / 255.0
		_draw_clipped_ai_glitch_slice(
			canvas,
			texture,
			dest_slice,
			source_slice,
			dest_rect,
			Color(40.0 / 255.0, 220.0 / 255.0, 1.0, min(180.0 / 255.0, tint_alpha))
		)


func _draw_clipped_ai_glitch_slice(
	canvas: CanvasItem,
	texture: Texture2D,
	dest_slice: Rect2,
	source_slice: Rect2,
	clip_rect: Rect2,
	tint: Color
) -> void:
	var clipped_x: float = max(dest_slice.position.x, clip_rect.position.x)
	var clipped_end_x: float = min(dest_slice.end.x, clip_rect.end.x)
	if clipped_end_x <= clipped_x:
		return
	var x_offset_ratio: float = (clipped_x - dest_slice.position.x) / max(1.0, dest_slice.size.x)
	var width_ratio: float = (clipped_end_x - clipped_x) / max(1.0, dest_slice.size.x)
	var clipped_dest := Rect2(
		Vector2(clipped_x, dest_slice.position.y),
		Vector2(clipped_end_x - clipped_x, dest_slice.size.y)
	)
	var clipped_source := Rect2(
		source_slice.position + Vector2(source_slice.size.x * x_offset_ratio, 0.0),
		Vector2(source_slice.size.x * width_ratio, source_slice.size.y)
	)
	canvas.draw_texture_rect_region(texture, clipped_dest, clipped_source, tint, false, true)


func _draw_ai_glitch_fallback(
	canvas: CanvasItem,
	context: Dictionary,
	player_pos: Vector2,
	paddle_size: Vector2,
	shake_offset: Vector2
) -> void:
	var phase: float = float(context.get("active_item_aipill_phase", 0.0))
	var glow_rect := Rect2(player_pos + shake_offset + Vector2(-4.0, -4.0), paddle_size + Vector2(8.0, 8.0))
	canvas.draw_rect(glow_rect, Color(0.0, 0.85, 1.0, 0.12), false, 2.0)
	for y in range(0, int(paddle_size.y), 6):
		var shift: float = sin(phase + float(y) * 0.22) * 4.0
		var line_rect := Rect2(
			player_pos + shake_offset + Vector2(shift, float(y)),
			Vector2(paddle_size.x, 1.0)
		)
		canvas.draw_rect(line_rect, Color(0.55, 1.0, 1.0, 0.35))


func _draw_rotated_texture_region(
	canvas: CanvasItem,
	texture: Texture2D,
	source_rect: Rect2,
	center: Vector2,
	draw_size: Vector2,
	angle_degrees: float,
	sprite_modulate: Color,
	flip_h: bool = false
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
		Vector2(uv_max.x, uv_min.y) if flip_h else Vector2(uv_min.x, uv_min.y),
		Vector2(uv_min.x, uv_min.y) if flip_h else Vector2(uv_max.x, uv_min.y),
		Vector2(uv_min.x, uv_max.y) if flip_h else Vector2(uv_max.x, uv_max.y),
		Vector2(uv_max.x, uv_max.y) if flip_h else Vector2(uv_min.x, uv_max.y),
	])
	var colors := PackedColorArray([sprite_modulate, sprite_modulate, sprite_modulate, sprite_modulate])
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


func _as_color(value, fallback: Color) -> Color:
	return Stage1ContextReader.as_color(value, fallback)


func _get_player_sprite_modulate(context: Dictionary) -> Color:
	var modulate := Color.WHITE
	if bool(context.get("soul_burst_dash_active", false)):
		modulate = _multiply_rgb(modulate, Color(0.82, 0.42, 1.18, 1.0))
	if bool(context.get("dash_recovering", false)):
		modulate = _multiply_rgb(modulate, _get_dash_recovery_modulate())
	modulate = _multiply_rgb(modulate, _as_color(context.get("player_sprite_modulate", Color.WHITE), Color.WHITE))
	return modulate


func _get_dash_recovery_modulate() -> Color:
	var pulse: float = 0.6 + 0.4 * sin(float(Time.get_ticks_msec()) * 0.02)
	return Color(
		(180.0 * pulse) / 255.0,
		(120.0 * pulse) / 255.0,
		(200.0 * pulse) / 255.0,
		1.0
	)


func _multiply_rgb(color: Color, modulate: Color) -> Color:
	return Color(color.r * modulate.r, color.g * modulate.g, color.b * modulate.b, color.a * modulate.a)
