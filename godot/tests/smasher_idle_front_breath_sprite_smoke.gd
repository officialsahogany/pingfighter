extends SceneTree

const BattleDrawActorContext := preload("res://scripts/core/battle_draw_actor_context.gd")
const BattleResources := preload("res://scripts/resources/battle_resources.gd")
const BattleUpdateEffectsSpriteContextBuilder := preload("res://scripts/core/battle_update_effects_sprite_context_builder.gd")

const IDLE_SHEET_PATH := "res://assets/sprites/characters/smasher/smasher_subculture_idle_sheet.png"


func _init() -> void:
	var direct_texture: Texture2D = load(IDLE_SHEET_PATH)
	_expect(direct_texture != null, "subculture idle sheet should load")
	_expect(direct_texture.get_size() == Vector2(640.0, 320.0), "subculture idle sheet should be 4x2 160px cells")

	var resources := BattleResources.new()
	var textures: Dictionary = resources.load_all({
		"selected_character_type": "smasher",
		"current_stage": 1,
		"include_all_characters": false,
		"include_all_stages": false,
		"include_result_sheets": false,
	})
	var idle_texture: Variant = textures.get("player_idle_back_sheet", null)
	_expect(idle_texture is Texture2D, "smasher idle priority texture should be loaded")
	var idle_texture_typed: Texture2D = idle_texture
	_expect(idle_texture_typed.get_size() == Vector2(640.0, 320.0), "smasher idle priority texture should use the 8-frame subculture sheet")
	var idle_fallback_texture: Variant = textures.get("player_idle_sprite_texture", null)
	_expect(idle_fallback_texture is Texture2D, "smasher idle fallback texture should be loaded")
	var idle_fallback_texture_typed: Texture2D = idle_fallback_texture
	_expect(idle_fallback_texture_typed.get_size() == Vector2(640.0, 320.0), "smasher idle fallback should use the same subculture sheet")

	var update_builder := BattleUpdateEffectsSpriteContextBuilder.new()
	var update_context: Dictionary = update_builder.build_context(textures, "smasher")
	_expect(int(update_context.get("player_idle_frame_count", 0)) == 8, "idle animation state should advance 8 frames")

	var draw_builder := BattleDrawActorContext.new()
	var actor_context: Dictionary = draw_builder.build({
		"selected_character_type": "smasher",
		"textures": textures,
	}, {})
	_expect(int(actor_context.get("player_idle_frame_count", 0)) == 8, "draw context should expose 8 idle frames")
	_expect(int(actor_context.get("player_idle_grid_cols", 0)) == 4, "draw context should expose 4 idle columns")
	_expect(int(actor_context.get("player_idle_grid_rows", 0)) == 2, "draw context should expose 2 idle rows")
	_expect(float(actor_context.get("player_idle_cell_width", 0.0)) == 160.0, "idle cell width should be 160")
	_expect(float(actor_context.get("player_idle_cell_height", 0.0)) == 160.0, "idle cell height should be 160")
	_expect(actor_context.get("player_idle_sprite_texture", null) == idle_texture, "draw context should prioritize the subculture standing idle sheet")

	print("smasher_idle_front_breath_sprite_smoke: ok")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
