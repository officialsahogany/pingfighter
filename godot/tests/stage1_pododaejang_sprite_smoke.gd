extends SceneTree

const BattleDrawActorContext := preload("res://scripts/core/battle_draw_actor_context.gd")
const BattleResources := preload("res://scripts/resources/battle_resources.gd")
const Stage1BossActorRenderer := preload("res://scripts/stages/stage1/stage1_boss_actor_renderer.gd")

var _failures: Array[String] = []


class FakeScoreboardState:
	extends RefCounted

	var _timer := 0.0
	var _scoring_side := "player"

	func _init(timer: float, scoring_side: String) -> void:
		_timer = timer
		_scoring_side = scoring_side

	func is_active() -> bool:
		return true

	func get_last_scoring_side() -> String:
		return _scoring_side

	func get_timer() -> float:
		return _timer

	func get_player_points() -> int:
		return 1 if _scoring_side == "player" else 0

	func get_boss_points() -> int:
		return 1 if _scoring_side == "boss" else 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_asset_import_siblings_exist()
	_verify_texture_loading_and_aliases()
	_verify_renderer_priority_and_grid()
	_verify_draw_context_size_and_pojol_sheet()

	if _failures.is_empty():
		print("stage1_pododaejang_sprite_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_asset_import_siblings_exist() -> void:
	for path in [
		"res://assets/sprites/stage1/pododaejang/pododaejang_boss_walk_16f_autosprite_v1_pro.png.import",
		"res://assets/sprites/stage1/pododaejang/pododaejang_boss_idle_8f_autosprite_v1_pro.png.import",
		"res://assets/sprites/stage1/pododaejang/pododaejang_boss_attack_8f_autosprite_v1_pro.png.import",
		"res://assets/sprites/stage1/pododaejang/pododaejang_boss_dash_8f_autosprite_v1_pro.png.import",
		"res://assets/sprites/stage1/pododaejang/pododaejang_boss_stun_8f_autosprite_v1_pro.png.import",
		"res://assets/sprites/stage1/pododaejang/pododaejang_boss_victory_8f_autosprite_v1_pro.png.import",
		"res://assets/sprites/stage1/pododaejang/pododaejang_boss_defeat_8f_autosprite_v1_pro.png.import",
		"res://assets/sprites/stage1/pojol/pojol_patrol_walk_8f_autosprite_v1_pro.png.import",
	]:
		_expect(FileAccess.file_exists(path), "Pododaejang sprite asset should have export-safe import metadata: %s" % path)


func _verify_texture_loading_and_aliases() -> void:
	var resources: Object = BattleResources.new()
	var textures: Dictionary = resources.load_all({
		"selected_character_type": "smasher",
		"current_stage": 1,
		"stage1_boss_variant": "pododaejang",
		"include_result_sheets": true,
		"include_all_characters": false,
		"include_all_stages": false,
	})
	_expect(_texture_size(textures, "boss_walk_right_sheet") == Vector2(1024.0, 1024.0), "Pododaejang walk sheet should load as 1024x1024")
	_expect(textures.get("boss_walk_left_sheet", null) == textures.get("boss_walk_right_sheet", null), "Pododaejang left/right walk keys should share the front-facing sheet")
	_expect(textures.get("boss_sprite_sheet", null) == textures.get("boss_walk_right_sheet", null), "Pododaejang legacy walk alias should share the front-facing sheet")
	_expect(_texture_size(textures, "boss_idle_sheet") == Vector2(768.0, 768.0), "Pododaejang idle sheet should load as 768x768")
	_expect(_texture_size(textures, "boss_attack_sheet") == Vector2(768.0, 768.0), "Pododaejang arrest-rope attack sheet should load as 768x768")
	_expect(textures.get("boss_hit_sprite_sheet", null) == textures.get("boss_attack_sheet", null), "Pododaejang legacy hit alias should be attack, not stun")
	_expect(_texture_size(textures, "boss_stun_sheet") == Vector2(768.0, 768.0), "Pododaejang stun sheet should load separately")
	_expect(_texture_size(textures, "boss_victory_sheet") == Vector2(768.0, 768.0), "Pododaejang victory result sheet should load")
	_expect(_texture_size(textures, "boss_defeat_sheet") == Vector2(768.0, 768.0), "Pododaejang defeat result sheet should load")
	_expect(_texture_size(textures, "stage1_pojol_patrol_walk_sheet") == Vector2(768.0, 768.0), "Pojol patrol walk sheet should load with Pododaejang resources")
	_expect(not textures.has("boss_whip_sheet"), "Pododaejang resources should not load Dalji whip")
	_expect(not textures.has("boss_fan_throw_sheet"), "Pododaejang resources should not load Gaksital fan throw")


func _verify_renderer_priority_and_grid() -> void:
	var renderer: Object = Stage1BossActorRenderer.new()
	var walk_texture: Texture2D = _make_texture(1024, 1024)
	var static_texture: Texture2D = _make_texture(768, 768)
	var context := {
		"stage1_boss_variant": "podo",
		"boss_walk_left_sheet": walk_texture,
		"boss_walk_right_sheet": walk_texture,
		"boss_sprite_sheet": walk_texture,
		"boss_idle_sheet": static_texture,
		"boss_attack_sheet": static_texture,
		"boss_hit_sprite_sheet": static_texture,
		"boss_dash_sheet": static_texture,
		"boss_stun_sheet": static_texture,
		"boss_victory_sheet": static_texture,
		"boss_defeat_sheet": static_texture,
		"boss_is_walking": true,
		"boss_sprite_frame": 15,
	}
	var selected_walk: Dictionary = renderer._select_sheet(context)
	_expect(selected_walk.get("texture", null) == walk_texture, "Pododaejang walk should use the front-facing walk texture")
	_expect(int(selected_walk.get("frame_count", 0)) == 16, "Pododaejang walk should keep 16 frames")
	_expect(int(selected_walk.get("grid_cols", 0)) == 4, "Pododaejang walk should use the 4x4 grid")
	_expect(renderer._get_cell_region(15, 256.0, 256.0, 4, 16) == Rect2(768.0, 768.0, 256.0, 256.0), "Pododaejang walk frame 15 should slice the final 4x4 cell")

	var attack_context: Dictionary = context.duplicate(true)
	attack_context["boss_is_walking"] = false
	attack_context["boss_hit_active"] = true
	attack_context["boss_hit_frame"] = 7
	var selected_attack: Dictionary = renderer._select_sheet(attack_context)
	_expect(selected_attack.get("texture", null) == static_texture, "Pododaejang ball-contact should use the attack sheet")
	_expect(int(selected_attack.get("frame_count", 0)) == 8, "Pododaejang attack should stop at 8 used frames")
	_expect(int(selected_attack.get("grid_cols", 0)) == 3, "Pododaejang attack should use the 3x3 grid")
	_expect(renderer._get_cell_region(7, 256.0, 256.0, 3, 8) == Rect2(256.0, 512.0, 256.0, 256.0), "Pododaejang attack frame 7 should avoid the unused cell 8")

	var priority_context: Dictionary = attack_context.duplicate(true)
	priority_context["boss_victory_active"] = true
	priority_context["boss_defeat_active"] = true
	var selected_priority: Dictionary = renderer._select_sheet(priority_context)
	_expect(selected_priority.get("texture", null) == static_texture, "Pododaejang defeat should outrank victory and attack")

	var rope_context: Dictionary = context.duplicate(true)
	rope_context["boss_is_walking"] = false
	rope_context["stage1_pododaejang_arrest_rope_active"] = true
	rope_context["stage1_pododaejang_arrest_rope_frame"] = 6
	var selected_rope: Dictionary = renderer._select_sheet(rope_context)
	_expect(selected_rope.get("texture", null) == static_texture, "Pododaejang arrest-rope animation should use the attack sheet")
	_expect(int(selected_rope.get("frame", -1)) == 6, "Pododaejang arrest-rope should read its forwarded frame")


func _verify_draw_context_size_and_pojol_sheet() -> void:
	var context_builder: Object = BattleDrawActorContext.new()
	var walk_texture: Texture2D = _make_texture(1024, 1024)
	var static_texture: Texture2D = _make_texture(768, 768)
	var pojol_texture: Texture2D = _make_texture(768, 768)
	var actor_context: Dictionary = context_builder.build(
		{
			"current_stage": 1,
			"stage1_boss_variant": "pododaejang",
			"textures": {
				"boss_walk_left_sheet": walk_texture,
				"boss_walk_right_sheet": walk_texture,
				"boss_sprite_sheet": walk_texture,
				"boss_attack_sheet": static_texture,
				"boss_hit_sprite_sheet": static_texture,
				"stage1_pojol_patrol_walk_sheet": pojol_texture,
			},
		},
		{"scoreboard_state": FakeScoreboardState.new(0.4, "player")}
	)
	_expect(actor_context.get("stage1_boss_variant", "") == "podo", "Pododaejang draw context should normalize the variant")
	_expect(actor_context.get("boss_sprite_draw_size", Vector2.ZERO) == Vector2(115.2, 134.4), "Pododaejang draw size should stay at Dalji +20%")
	_expect(float(actor_context.get("boss_visual_center_y_offset", 0.0)) == 30.0, "Pododaejang visual center should use the larger body offset")
	_expect(actor_context.get("stage1_pojol_patrol_walk_sheet", null) == pojol_texture, "Pododaejang draw context should expose the pojol patrol sheet")
	_expect(bool(actor_context.get("boss_defeat_active", false)), "player scoring should activate Pododaejang defeat result context")


func _make_texture(width: int, height: int) -> Texture2D:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)


func _texture_size(textures: Dictionary, key: String) -> Vector2:
	var texture: Variant = textures.get(key, null)
	if texture is Texture2D:
		return texture.get_size()
	return Vector2.ZERO


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
