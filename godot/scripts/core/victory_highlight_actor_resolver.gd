extends RefCounted

# Converts the final renderer-facing BattleDrawActorContext dictionary into a
# flat replay slot. The destination slot is preallocated by the recorder and is
# always mutated in place; this path runs on every captured render frame.

const DEFAULT_PLAYER_DRAW_SIZE := Vector2(160.0, 160.0)
const DEFAULT_BOSS_DRAW_SIZE := Vector2(160.0, 160.0)

const BOSS_POSE_DEFEAT := &"defeat"
const BOSS_POSE_VICTORY := &"victory"
const BOSS_POSE_STUN := &"stun"
const BOSS_POSE_DASH := &"dash"
const BOSS_POSE_ATTACK := &"attack"
const BOSS_POSE_WALK := &"walk"
const BOSS_POSE_IDLE_OR_INTERNAL := &"idle_or_renderer_internal"
const BOSS_POSE_SKILL_ARREST_ROPE := &"skill:arrest_rope"
const BOSS_POSE_SKILL_FAN_THROW := &"skill:fan_throw"
const BOSS_POSE_SKILL_PAENGI_WHIP := &"skill:paengi_top_whip"
const BOSS_POSE_SKILL_WHIP := &"skill:whip"
const BOSS_POSE_SKILL_QUAKE := &"skill:quake"
const BOSS_POSE_SKILL_SPEED_DEFENSE := &"skill:speed_defense"
const BOSS_POSE_SKILL_CURSE_CHEST := &"skill:curse_chest_throw"
const BOSS_POSE_SKILL_TEAR_SHOWER := &"skill:tear_shower_cast"

const BOSS_POSE_SOURCE_SHARED := &"shared_context"
const BOSS_POSE_SOURCE_STAGE_HINT := &"stage_hint"
const BOSS_POSE_SOURCE_AMBIGUOUS := &"ambiguous_renderer_internal"

const BOSS_RESOLUTION_SHEET := &"sheet"
const BOSS_RESOLUTION_SHEET_POSE_MISMATCH := &"sheet_pose_mismatch"
const BOSS_RESOLUTION_SILHOUETTE_UNSUPPORTED_POSE := &"silhouette_unsupported_pose"
const BOSS_RESOLUTION_SILHOUETTE_MISSING_TEXTURE := &"silhouette_missing_texture"
const BOSS_RESOLUTION_SILHOUETTE_MISSING_GRID := &"silhouette_missing_grid"


static func resolve_into(actor_context: Dictionary, slot: Dictionary) -> bool:
	_reset_actor_fields(slot)
	var player_ok: bool = _resolve_player(actor_context, slot)
	var boss_ok: bool = _resolve_boss(actor_context, slot)
	return player_ok and boss_ok


static func _resolve_player(context: Dictionary, slot: Dictionary) -> bool:
	var texture: Texture2D = null
	var frame := 0
	var frame_count := 1
	var grid_cols := 1
	var grid_rows := 1
	var cell_width := 0.0
	var cell_height := 0.0
	var draw_size: Vector2 = _get_vector2(context, "player_idle_draw_size", DEFAULT_PLAYER_DRAW_SIZE)
	var flip_h := false
	var direction: int = int(context.get("player_walk_direction", 1))
	var has_grid_contract := false

	if bool(context.get("commando_weapon_fire_active", false)):
		texture = _get_texture(context, "commando_weapon_fire_sheet")
		frame = int(context.get("commando_weapon_fire_frame", 0))
		frame_count = int(context.get("commando_weapon_fire_frame_count", 8))
		grid_cols = int(context.get("commando_weapon_fire_grid_cols", 4))
		grid_rows = int(context.get("commando_weapon_fire_grid_rows", 2))
		has_grid_contract = _has_positive_contract(context, [
			"commando_weapon_fire_frame_count",
			"commando_weapon_fire_grid_cols",
			"commando_weapon_fire_grid_rows",
		])
		draw_size = _get_vector2(context, "player_commando_weapon_fire_draw_size", DEFAULT_PLAYER_DRAW_SIZE)
		flip_h = bool(context.get("commando_weapon_fire_flip_h", false))
	elif bool(context.get("commando_pistol_fire_active", false)):
		texture = _get_texture(context, "commando_pistol_fire_sheet")
		frame = int(context.get("commando_pistol_fire_frame", 0))
		frame_count = int(context.get("commando_pistol_fire_frame_count", 8))
		grid_cols = int(context.get("commando_pistol_fire_grid_cols", 4))
		grid_rows = int(context.get("commando_pistol_fire_grid_rows", 2))
		has_grid_contract = _has_positive_contract(context, [
			"commando_pistol_fire_frame_count",
			"commando_pistol_fire_grid_cols",
			"commando_pistol_fire_grid_rows",
		])
		draw_size = _get_vector2(context, "player_pistol_fire_draw_size", DEFAULT_PLAYER_DRAW_SIZE)
		flip_h = bool(context.get("commando_pistol_fire_flip_h", false))
	elif bool(context.get("commando_attack_active", false)):
		texture = _get_texture(context, "commando_attack_sheet")
		frame = int(context.get("player_hit_frame", 0))
		frame_count = int(context.get("commando_attack_frame_count", 8))
		grid_cols = int(context.get("commando_attack_grid_cols", 4))
		grid_rows = int(context.get("commando_attack_grid_rows", 2))
		has_grid_contract = _has_positive_contract(context, [
			"commando_attack_frame_count",
			"commando_attack_grid_cols",
			"commando_attack_grid_rows",
		])
		draw_size = _get_vector2(context, "player_commando_attack_draw_size", DEFAULT_PLAYER_DRAW_SIZE)
		flip_h = bool(context.get("commando_attack_flip_h", false))
	elif bool(context.get("player_hit_active", false)):
		var attack_key := "player_attack_left_sheet" if direction < 0 else "player_attack_right_sheet"
		texture = _get_texture(context, attack_key)
		if texture == null:
			texture = _get_texture(context, "player_attack_sheet")
		frame = int(context.get("player_hit_frame", 0))
		frame_count = int(context.get("player_hit_frame_count", 8))
		grid_cols = int(context.get("player_directional_attack_grid_cols", 4))
		grid_rows = int(context.get("player_directional_attack_grid_rows", 2))
		cell_width = float(context.get("player_directional_attack_cell_width", 160.0))
		cell_height = float(context.get("player_directional_attack_cell_height", 160.0))
		has_grid_contract = _has_positive_contract(
			context,
			[
				"player_hit_frame_count",
				"player_directional_attack_grid_cols",
				"player_directional_attack_grid_rows",
			],
			["player_directional_attack_cell_width", "player_directional_attack_cell_height"]
		)
		draw_size = _get_vector2(context, "player_directional_attack_draw_size", DEFAULT_PLAYER_DRAW_SIZE)
		flip_h = texture == _get_texture(context, "player_attack_sheet") and direction < 0
	elif bool(context.get("dash_active", false)):
		var dash_key := "player_dash_left_texture" if direction < 0 else "player_dash_right_texture"
		texture = _get_texture(context, dash_key)
		frame = int(context.get("player_sprite_frame", 0))
		frame_count = int(context.get("player_directional_dash_frame_count", 8))
		grid_cols = int(context.get("player_directional_dash_grid_cols", 4))
		grid_rows = maxi(1, ceili(float(frame_count) / float(maxi(1, grid_cols))))
		cell_width = float(context.get("player_directional_dash_cell_width", 160.0))
		cell_height = float(context.get("player_directional_dash_cell_height", 160.0))
		has_grid_contract = _has_positive_contract(
			context,
			["player_directional_dash_frame_count", "player_directional_dash_grid_cols"],
			["player_directional_dash_cell_width", "player_directional_dash_cell_height"]
		)
		draw_size = _get_vector2(context, "player_directional_dash_draw_size", DEFAULT_PLAYER_DRAW_SIZE)
	else:
		var moving: bool = absf(float(context.get("player_speed", 0.0))) > 0.2
		if moving:
			var walk_key := "player_walk_left_texture" if direction < 0 else "player_walk_right_texture"
			texture = _get_texture(context, walk_key)
			frame = int(context.get("player_sprite_frame", 0))
			frame_count = int(context.get("player_directional_walk_frame_count", 8))
			grid_cols = int(context.get("player_directional_walk_grid_cols", 4))
			grid_rows = maxi(1, ceili(float(frame_count) / float(maxi(1, grid_cols))))
			cell_width = float(context.get("player_directional_walk_cell_width", 160.0))
			cell_height = float(context.get("player_directional_walk_cell_height", 160.0))
			has_grid_contract = _has_positive_contract(
				context,
				["player_directional_walk_frame_count", "player_directional_walk_grid_cols"],
				["player_directional_walk_cell_width", "player_directional_walk_cell_height"]
			)
			draw_size = _get_vector2(context, "player_directional_walk_draw_size", DEFAULT_PLAYER_DRAW_SIZE)
		if texture == null:
			texture = _get_texture(context, "player_idle_sprite_texture")
			frame = int(context.get("player_idle_frame", 0))
			frame_count = int(context.get("player_idle_frame_count", 8))
			grid_cols = int(context.get("player_idle_grid_cols", 1))
			grid_rows = int(context.get("player_idle_grid_rows", 1))
			cell_width = float(context.get("player_idle_cell_width", 160.0))
			cell_height = float(context.get("player_idle_cell_height", 160.0))
			has_grid_contract = _has_positive_contract(
				context,
				["player_idle_frame_count", "player_idle_grid_cols", "player_idle_grid_rows"],
				["player_idle_cell_width", "player_idle_cell_height"]
			)
			draw_size = _get_vector2(context, "player_idle_draw_size", DEFAULT_PLAYER_DRAW_SIZE)
		if texture == null:
			texture = _get_texture(context, "player_sprite_texture")
			frame = int(context.get("player_sprite_frame", 0))
			frame_count = int(context.get("player_sprite_frame_count", 6))
			grid_cols = maxi(1, frame_count)
			grid_rows = 1
			cell_width = float(context.get("player_sprite_frame_width", 250.0))
			cell_height = float(context.get("player_sprite_frame_height", 120.0))
			has_grid_contract = _has_positive_contract(
				context,
				["player_sprite_frame_count"],
				["player_sprite_frame_width", "player_sprite_frame_height"]
			)
			draw_size = _get_vector2(context, "player_sprite_draw_size", Vector2(250.0, 120.0))

	var player_pos: Vector2 = _get_vector2(context, "player_pos", Vector2.ZERO)
	var paddle_size: Vector2 = _get_vector2(context, "player_paddle_size", Vector2(155.0, 50.0))
	var paddle_scale: float = maxf(0.1, float(context.get("player_paddle_scale", 1.0)))
	draw_size *= paddle_scale
	var dest := Rect2(
		player_pos.x + paddle_size.x * 0.5 - draw_size.x * 0.5,
		player_pos.y + paddle_size.y - draw_size.y + 12.0,
		draw_size.x,
		draw_size.y
	)
	var can_draw_sheet: bool = texture != null and has_grid_contract
	slot["player_texture"] = texture if can_draw_sheet else null
	slot["player_src"] = _cell_region(texture, frame, frame_count, grid_cols, grid_rows, cell_width, cell_height) if can_draw_sheet else Rect2()
	slot["player_dest"] = dest
	slot["player_flip"] = flip_h if can_draw_sheet else false
	slot["player_modulate"] = _get_color(context, "player_sprite_modulate", Color.WHITE)
	return can_draw_sheet


static func _resolve_boss(context: Dictionary, slot: Dictionary) -> bool:
	_write_boss_pose_metadata(context, slot)
	var texture: Texture2D = null
	var frame := 0
	var frame_count := 1
	var grid_cols := 1
	var grid_rows := 1
	var flip_h := false
	var has_grid_contract := false

	# Only the walk branch has renderer-facing grid metadata. Every other pose
	# intentionally stays textureless so the replay renderer fails closed to a
	# silhouette instead of guessing a 4x4 atlas or borrowing another stage's
	# generic boss_sprite_sheet.
	var non_walk_pose_active: bool = (
		bool(context.get("boss_dash_active", false))
		or bool(context.get("boss_quake_stomp_active", false))
		or bool(context.get("boss_hit_active", false))
	)
	if not non_walk_pose_active and bool(context.get("boss_is_walking", false)):
		var facing: int = int(context.get("boss_facing", 1))
		texture = _get_texture(context, "boss_walk_left_sheet" if facing < 0 else "boss_walk_right_sheet")
		frame = int(context.get("boss_sprite_frame", 0))
		frame_count = int(context.get("boss_walk_frame_count", 8))
		grid_cols = int(context.get("boss_walk_grid_cols", 4))
		grid_rows = maxi(1, ceili(float(frame_count) / float(maxi(1, grid_cols))))
		has_grid_contract = _has_positive_contract(context, ["boss_walk_frame_count", "boss_walk_grid_cols"])

	var boss_pos: Vector2 = _get_vector2(context, "boss_pos", Vector2.ZERO)
	var paddle_size: Vector2 = _get_vector2(context, "boss_paddle_size", Vector2(100.0, 40.0))
	var hitbox_height: float = float(context.get("boss_hitbox_height", paddle_size.y))
	var draw_size: Vector2 = _get_vector2(context, "boss_sprite_draw_size", DEFAULT_BOSS_DRAW_SIZE)
	var center_y: float = (
		boss_pos.y
		+ hitbox_height * 0.5
		+ float(context.get("boss_visual_center_y_offset", 25.0))
		+ float(context.get("boss_whip_bob_offset", 0.0))
	)
	var can_draw_sheet: bool = texture != null and has_grid_contract
	var observed_pose: Variant = slot.get("boss_pose", BOSS_POSE_IDLE_OR_INTERNAL)
	if can_draw_sheet:
		slot["boss_resolution"] = (
			BOSS_RESOLUTION_SHEET
			if observed_pose == BOSS_POSE_WALK
			else BOSS_RESOLUTION_SHEET_POSE_MISMATCH
		)
	elif not non_walk_pose_active and bool(context.get("boss_is_walking", false)):
		slot["boss_resolution"] = (
			BOSS_RESOLUTION_SILHOUETTE_MISSING_TEXTURE
			if texture == null
			else BOSS_RESOLUTION_SILHOUETTE_MISSING_GRID
		)
	else:
		slot["boss_resolution"] = BOSS_RESOLUTION_SILHOUETTE_UNSUPPORTED_POSE
	slot["boss_texture"] = texture if can_draw_sheet else null
	slot["boss_src"] = _cell_region(texture, frame, frame_count, grid_cols, grid_rows, 0.0, 0.0) if can_draw_sheet else Rect2()
	slot["boss_dest"] = Rect2(
		boss_pos.x + paddle_size.x * 0.5 - draw_size.x * 0.5,
		center_y - draw_size.y * 0.5,
		draw_size.x,
		draw_size.y
	)
	slot["boss_flip"] = flip_h if can_draw_sheet else false
	slot["boss_modulate"] = _get_color(context, "boss_sprite_modulate", Color.WHITE)
	return can_draw_sheet


static func _write_boss_pose_metadata(context: Dictionary, slot: Dictionary) -> void:
	var current_stage: int = int(context.get("current_stage", 0))
	var stage7_cloud_phase: Variant = context.get("stage7_akamu_cloud_dash_phase", "") if current_stage == 7 else ""
	slot["stage_id"] = current_stage
	var stage1_variant: Variant = context.get("stage1_boss_variant", "") if current_stage == 1 else ""
	slot["stage1_boss_variant"] = stage1_variant if (stage1_variant is String or stage1_variant is StringName) else ""
	if bool(context.get("boss_defeat_active", false)):
		_set_boss_pose(slot, BOSS_POSE_DEFEAT, BOSS_POSE_SOURCE_SHARED, true)
		return
	if bool(context.get("boss_victory_active", false)):
		_set_boss_pose(slot, BOSS_POSE_VICTORY, BOSS_POSE_SOURCE_SHARED, true)
		return
	if (
		bool(context.get("boss_whip_post_stun_active", false))
		or bool(context.get("active_item_boss_stun_active", false))
		or bool(context.get("status_boss_stun_active", false))
		or bool(context.get("ragnarok_hammer_boss_stun_active", false))
		or bool(context.get("boss_electric_stun_active", false))
	):
		_set_boss_pose(slot, BOSS_POSE_STUN, BOSS_POSE_SOURCE_SHARED, true)
		return
	if bool(context.get("boss_dash_active", false)):
		_set_boss_pose(slot, BOSS_POSE_DASH, BOSS_POSE_SOURCE_SHARED, true)
		return
	if current_stage == 7:
		if (
			stage7_cloud_phase == "down"
			or stage7_cloud_phase == "up"
			or bool(context.get("stage7_akamu_superspeed_dash_active", false))
			or bool(context.get("stage7_akamu_escape_active", false))
		):
			_set_boss_pose(slot, BOSS_POSE_DASH, BOSS_POSE_SOURCE_STAGE_HINT, true)
			return
	if current_stage == 1:
		if (
			bool(context.get("boss_arrest_rope_active", false))
			or bool(context.get("stage1_pododaejang_arrest_rope_active", false))
		):
			_set_boss_pose(slot, BOSS_POSE_SKILL_ARREST_ROPE, BOSS_POSE_SOURCE_STAGE_HINT, true)
			return
		if bool(context.get("boss_fan_throw_active", false)):
			_set_boss_pose(slot, BOSS_POSE_SKILL_FAN_THROW, BOSS_POSE_SOURCE_STAGE_HINT, true)
			return
		if bool(context.get("boss_paengi_top_whip_active", false)):
			_set_boss_pose(slot, BOSS_POSE_SKILL_PAENGI_WHIP, BOSS_POSE_SOURCE_STAGE_HINT, true)
			return
		if bool(context.get("boss_whip_active", false)):
			_set_boss_pose(slot, BOSS_POSE_SKILL_WHIP, BOSS_POSE_SOURCE_STAGE_HINT, true)
			return
	elif current_stage == 2:
		if bool(context.get("stage2_quake_active", false)):
			_set_boss_pose(slot, BOSS_POSE_SKILL_QUAKE, BOSS_POSE_SOURCE_STAGE_HINT, true)
			return
		if bool(context.get("stage2_speed_defense_active", false)):
			_set_boss_pose(slot, BOSS_POSE_SKILL_SPEED_DEFENSE, BOSS_POSE_SOURCE_STAGE_HINT, true)
			return
	elif current_stage == 3:
		if bool(context.get("stage3_curse_chest_throw_anim_active", false)):
			_set_boss_pose(slot, BOSS_POSE_SKILL_CURSE_CHEST, BOSS_POSE_SOURCE_STAGE_HINT, true)
			return
		if bool(context.get("stage3_tear_shower_cast_active", false)):
			_set_boss_pose(slot, BOSS_POSE_SKILL_TEAR_SHOWER, BOSS_POSE_SOURCE_STAGE_HINT, true)
			return
	if bool(context.get("boss_quake_stomp_active", false)):
		_set_boss_pose(slot, BOSS_POSE_SKILL_QUAKE, BOSS_POSE_SOURCE_SHARED, true)
		return
	if (
		bool(context.get("stage5_hongryun_boss_throwing", false))
		or bool(context.get("stage7_akamu_boss_attack_active", false))
		or bool(context.get("stage7_akamu_clone_casting", false))
		or bool(context.get("stage7_akamu_shuriken_casting", false))
		or stage7_cloud_phase == "pre"
		or bool(context.get("stage8_minotaur_boss_attack_active", false))
	):
		_set_boss_pose(slot, BOSS_POSE_ATTACK, BOSS_POSE_SOURCE_STAGE_HINT, true)
		return
	if bool(context.get("boss_hit_active", false)):
		_set_boss_pose(slot, BOSS_POSE_ATTACK, BOSS_POSE_SOURCE_SHARED, true)
		return
	if bool(context.get("boss_is_walking", false)):
		_set_boss_pose(slot, BOSS_POSE_WALK, BOSS_POSE_SOURCE_SHARED, true)
		return
	_set_boss_pose(slot, BOSS_POSE_IDLE_OR_INTERNAL, BOSS_POSE_SOURCE_AMBIGUOUS, false)


static func _set_boss_pose(
	slot: Dictionary,
	pose: StringName,
	source: StringName,
	observable: bool
) -> void:
	slot["boss_pose"] = pose
	slot["boss_pose_source"] = source
	slot["boss_pose_observable"] = observable


static func _has_positive_contract(
	context: Dictionary,
	integer_keys: Array,
	float_keys: Array = []
) -> bool:
	for key_value in integer_keys:
		var key := str(key_value)
		if not context.has(key) or int(context.get(key, 0)) <= 0:
			return false
	for key_value in float_keys:
		var key := str(key_value)
		if not context.has(key) or float(context.get(key, 0.0)) <= 0.0:
			return false
	return true


static func _cell_region(
	texture: Texture2D,
	frame: int,
	frame_count: int,
	grid_cols: int,
	grid_rows: int,
	cell_width: float,
	cell_height: float
) -> Rect2:
	grid_cols = maxi(1, grid_cols)
	grid_rows = maxi(1, grid_rows)
	frame_count = maxi(1, frame_count)
	frame = clampi(frame, 0, frame_count - 1)
	if texture != null:
		var texture_size: Vector2 = texture.get_size()
		if cell_width <= 0.0:
			cell_width = texture_size.x / float(grid_cols)
		if cell_height <= 0.0:
			cell_height = texture_size.y / float(grid_rows)
	var column: int = frame % grid_cols
	@warning_ignore("integer_division")
	var row: int = int(frame / grid_cols)
	return Rect2(float(column) * cell_width, float(row) * cell_height, cell_width, cell_height)


static func _reset_actor_fields(slot: Dictionary) -> void:
	slot["player_texture"] = null
	slot["player_src"] = Rect2()
	slot["player_dest"] = Rect2()
	slot["player_flip"] = false
	slot["player_modulate"] = Color.WHITE
	slot["boss_texture"] = null
	slot["boss_src"] = Rect2()
	slot["boss_dest"] = Rect2()
	slot["boss_flip"] = false
	slot["boss_modulate"] = Color.WHITE
	slot["stage_id"] = 0
	slot["stage1_boss_variant"] = ""
	slot["boss_pose"] = BOSS_POSE_IDLE_OR_INTERNAL
	slot["boss_pose_source"] = BOSS_POSE_SOURCE_AMBIGUOUS
	slot["boss_pose_observable"] = false
	slot["boss_resolution"] = BOSS_RESOLUTION_SILHOUETTE_UNSUPPORTED_POSE


static func _get_texture(source: Dictionary, key: String) -> Texture2D:
	var value: Variant = source.get(key, null)
	return value as Texture2D if value is Texture2D else null


static func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	return value as Vector2 if value is Vector2 else fallback


static func _get_color(source: Dictionary, key: String, fallback: Color) -> Color:
	var value: Variant = source.get(key, fallback)
	return value as Color if value is Color else fallback
