extends SceneTree

const BattleResources := preload("res://scripts/resources/battle_resources.gd")
const Stage2BossActorRenderer := preload("res://scripts/stages/stage2/stage2_boss_actor_renderer.gd")

const IDLE_SHEET_PATH := "res://assets/sprites/stage2/stage2_boss_idle_combat_breath_autosprite_v2_8f.png"
const IDLE_SHEET_SIZE := Vector2(2048.0, 1024.0)
const IDLE_CELL_SIZE := Vector2(512.0, 512.0)


func _init() -> void:
	var direct_texture: Texture2D = load(IDLE_SHEET_PATH)
	_expect(direct_texture != null, "Stage 2 combat breathing idle sheet should load")
	_expect(direct_texture.get_size() == IDLE_SHEET_SIZE, "Stage 2 idle sheet should be 4x2 512px cells")

	var resources := BattleResources.new()
	var textures: Dictionary = resources.load_all({
		"selected_character_type": "smasher",
		"current_stage": 2,
		"include_all_characters": false,
		"include_all_stages": false,
		"include_result_sheets": false,
	})
	var idle_texture: Variant = textures.get("boss_idle_sheet", null)
	_expect(idle_texture is Texture2D, "Stage 2 boss idle texture should be loaded through BattleResources")
	var idle_texture_typed: Texture2D = idle_texture
	_expect(idle_texture_typed.get_size() == IDLE_SHEET_SIZE, "Stage 2 boss idle resource should use the new 8-frame sheet")
	_expect(idle_texture_typed.resource_path == IDLE_SHEET_PATH, "Stage 2 boss idle resource should not use the legacy idle sheet")

	var renderer := Stage2BossActorRenderer.new()
	var renderer_idle: Texture2D = renderer._get_idle_texture()
	_expect(renderer_idle != null, "Stage 2 boss actor renderer should load its direct idle texture")
	_expect(renderer_idle.get_size() == IDLE_SHEET_SIZE, "Stage 2 direct idle texture should use the new 8-frame sheet")
	_expect(renderer_idle.resource_path == IDLE_SHEET_PATH, "Stage 2 actor renderer should not use the legacy idle sheet")

	_expect(IDLE_SHEET_SIZE.x / 4.0 == IDLE_CELL_SIZE.x, "Stage 2 idle cell width should stay 512")
	_expect(IDLE_SHEET_SIZE.y / 2.0 == IDLE_CELL_SIZE.y, "Stage 2 idle cell height should stay 512")

	print("stage2_boss_idle_sprite_smoke: ok")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
