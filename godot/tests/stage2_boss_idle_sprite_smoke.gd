extends SceneTree

const BattleResources := preload("res://scripts/resources/battle_resources.gd")
const Stage2BossActorRenderer := preload("res://scripts/stages/stage2/stage2_boss_actor_renderer.gd")
const Stage2ActorDrawContextBuilder := preload("res://scripts/stages/stage2/stage2_actor_draw_context_builder.gd")

const IDLE_SHEET_PATH := "res://assets/sprites/stage2/stage2_boss_idle_combat_breath_autosprite_v2_8f.png"
const IDLE_SHEET_SIZE := Vector2(2048.0, 1024.0)
const IDLE_CELL_SIZE := Vector2(512.0, 512.0)
const QUAKE_STOMP_SHEET_PATH := "res://assets/sprites/stage2/stage2_boss_jungle_quake_stomp_autosprite_v1_16f.png"
const QUAKE_STOMP_SHEET_SIZE := Vector2(2048.0, 2048.0)
const QUAKE_DURATION_SEC := 80.0 / 60.0


func _init() -> void:
	var direct_texture: Texture2D = load(IDLE_SHEET_PATH)
	_expect(direct_texture != null, "Stage 2 combat breathing idle sheet should load")
	_expect(direct_texture.get_size() == IDLE_SHEET_SIZE, "Stage 2 idle sheet should be 4x2 512px cells")
	var direct_quake_texture: Texture2D = load(QUAKE_STOMP_SHEET_PATH)
	_expect(direct_quake_texture != null, "Stage 2 Jungle Quake stomp sheet should load")
	_expect(direct_quake_texture.get_size() == QUAKE_STOMP_SHEET_SIZE, "Stage 2 Jungle Quake stomp sheet should be 4x4 512px cells")

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
	var quake_texture: Variant = textures.get("boss_quake_stomp_sheet", null)
	_expect(quake_texture is Texture2D, "Stage 2 Jungle Quake stomp texture should be loaded through BattleResources")
	var quake_texture_typed: Texture2D = quake_texture
	_expect(quake_texture_typed.get_size() == QUAKE_STOMP_SHEET_SIZE, "Stage 2 Jungle Quake stomp resource should use the 16-frame sheet")
	_expect(quake_texture_typed.resource_path == QUAKE_STOMP_SHEET_PATH, "Stage 2 Jungle Quake stomp resource should use the accepted runtime sheet")

	var renderer := Stage2BossActorRenderer.new()
	var renderer_idle: Texture2D = renderer._get_idle_texture()
	_expect(renderer_idle != null, "Stage 2 boss actor renderer should load its direct idle texture")
	_expect(renderer_idle.get_size() == IDLE_SHEET_SIZE, "Stage 2 direct idle texture should use the new 8-frame sheet")
	_expect(renderer_idle.resource_path == IDLE_SHEET_PATH, "Stage 2 actor renderer should not use the legacy idle sheet")
	var renderer_quake: Texture2D = renderer._get_quake_stomp_texture()
	_expect(renderer_quake != null, "Stage 2 boss actor renderer should load its direct Jungle Quake stomp texture")
	_expect(renderer_quake.get_size() == QUAKE_STOMP_SHEET_SIZE, "Stage 2 direct Jungle Quake stomp texture should use 16 frames")
	_expect(renderer_quake.resource_path == QUAKE_STOMP_SHEET_PATH, "Stage 2 actor renderer should use the accepted Jungle Quake stomp sheet")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_boss_actor_renderer.gd")
	_expect(
		renderer_source.find("expression == \"neutral\" and not hit_active and _draw_idle_sheet") < 0,
		"Stage 2 score expression should not force the boss actor back to the legacy procedural body"
	)
	_expect(
		renderer_source.find("expression == \"neutral\" and not hit_active and _draw_walk_sheet") < 0,
		"Stage 2 score expression should not block the accepted walking sheet"
	)
	_expect(
		renderer_source.find("if not hit_active and _draw_idle_sheet") >= 0,
		"Stage 2 boss actor should keep using the idle sheet while score expressions are active"
	)
	_expect(
		renderer_source.find("stage2_quake_active") >= 0 and renderer_source.find("_draw_quake_stomp_sheet") >= 0,
		"Stage 2 boss actor should select the Jungle Quake stomp sheet while the quake is active"
	)
	var builder_context: Dictionary = Stage2ActorDrawContextBuilder.new().build_context(
		{},
		{},
		{"active": true, "timer": 0.5, "duration": QUAKE_DURATION_SEC}
	)
	_expect(bool(builder_context.get("stage2_quake_active", false)), "Stage 2 actor context should expose active quake state")
	_expect(is_equal_approx(float(builder_context.get("stage2_quake_duration", 0.0)), QUAKE_DURATION_SEC), "Stage 2 actor context should expose quake duration")
	_expect(
		renderer._get_quake_stomp_frame_index({"stage2_quake_timer": QUAKE_DURATION_SEC, "stage2_quake_duration": QUAKE_DURATION_SEC}) == 0,
		"Stage 2 Jungle Quake stomp should start from frame 0 at quake start"
	)
	_expect(
		renderer._get_quake_stomp_frame_index({"stage2_quake_timer": QUAKE_DURATION_SEC - 5.0 / 60.0, "stage2_quake_duration": QUAKE_DURATION_SEC}) == 1,
		"Stage 2 Jungle Quake stomp should advance one frame every five gameplay frames"
	)

	_expect(IDLE_SHEET_SIZE.x / 4.0 == IDLE_CELL_SIZE.x, "Stage 2 idle cell width should stay 512")
	_expect(IDLE_SHEET_SIZE.y / 2.0 == IDLE_CELL_SIZE.y, "Stage 2 idle cell height should stay 512")

	print("stage2_boss_idle_sprite_smoke: ok")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
