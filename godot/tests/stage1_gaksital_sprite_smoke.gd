extends SceneTree

const BattleResources := preload("res://scripts/resources/battle_resources.gd")
const Stage1BossActorRenderer := preload("res://scripts/stages/stage1/stage1_boss_actor_renderer.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_asset_import_siblings_exist()
	_verify_texture_loading_and_aliases()
	_verify_renderer_priority_and_grid()

	if _failures.is_empty():
		print("stage1_gaksital_sprite_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_asset_import_siblings_exist() -> void:
	for path in [
		"res://assets/sprites/stage1/gaksital/gaksital_boss_walk_right_front_sidestep_16f_autosprite_v3_pro.png.import",
		"res://assets/sprites/stage1/gaksital/gaksital_boss_walk_left_front_sidestep_16f_mirrored_from_right_v3_pro.png.import",
		"res://assets/sprites/stage1/gaksital/gaksital_boss_victory_round_8f_autosprite_v2_pro.png.import",
		"res://assets/sprites/stage1/gaksital/gaksital_boss_defeat_round_8f_autosprite_v2_pro.png.import",
	]:
		_expect(FileAccess.file_exists(path), "Gaksital sprite asset should have export-safe import metadata: %s" % path)


func _verify_texture_loading_and_aliases() -> void:
	var resources: Object = BattleResources.new()
	var textures: Dictionary = resources.load_all({
		"selected_character_type": "smasher",
		"current_stage": 1,
		"stage1_boss_variant": "gaksi",
		"include_result_sheets": true,
		"include_all_characters": false,
		"include_all_stages": false,
	})
	_expect(_texture_size(textures, "boss_walk_right_sheet") == Vector2(1024.0, 1024.0), "Gaksital right front-sidestep walk sheet should load as 1024x1024")
	_expect(_texture_size(textures, "boss_walk_left_sheet") == Vector2(1024.0, 1024.0), "Gaksital left front-sidestep walk sheet should load as 1024x1024")
	_expect(textures.get("boss_walk_left_sheet", null) != textures.get("boss_walk_right_sheet", null), "Gaksital left/right walk sheets should be separate baked textures")
	_expect(textures.get("boss_sprite_sheet", null) == textures.get("boss_walk_right_sheet", null), "Gaksital legacy walk alias should share the right walk texture")
	_expect(_texture_size(textures, "boss_idle_sheet") == Vector2(768.0, 768.0), "Gaksital idle sheet should load as 768x768")
	_expect(_texture_size(textures, "boss_attack_sheet") == Vector2(768.0, 768.0), "Gaksital attack sheet should load as 768x768")
	_expect(_texture_size(textures, "boss_victory_sheet") == Vector2(768.0, 768.0), "Gaksital round-victory sheet should load as 768x768")
	_expect(_texture_size(textures, "boss_defeat_sheet") == Vector2(768.0, 768.0), "Gaksital round-defeat sheet should load as 768x768")
	_expect(_texture_size(textures, "boss_fan_throw_sheet") == Vector2(1024.0, 1024.0), "Gaksital fan-throw sheet should still load as 1024x1024")
	_expect(not textures.has("boss_whip_sheet"), "Gaksital resources should not load Dalji whip")


func _verify_renderer_priority_and_grid() -> void:
	var renderer: Object = Stage1BossActorRenderer.new()
	var walk_left := _make_texture(1024, 1024)
	var walk_right := _make_texture(1024, 1024)
	var static_texture := _make_texture(768, 768)
	var victory_texture := _make_texture(768, 768)
	var defeat_texture := _make_texture(768, 768)
	var fan_throw_texture := _make_texture(1024, 1024)
	var context := {
		"stage1_boss_variant": "gaksi",
		"boss_walk_left_sheet": walk_left,
		"boss_walk_right_sheet": walk_right,
		"boss_sprite_sheet": walk_right,
		"boss_idle_sheet": static_texture,
		"boss_attack_sheet": static_texture,
		"boss_hit_sprite_sheet": static_texture,
		"boss_dash_sheet": static_texture,
		"boss_stun_sheet": static_texture,
		"boss_victory_sheet": victory_texture,
		"boss_defeat_sheet": defeat_texture,
		"boss_fan_throw_sheet": fan_throw_texture,
		"boss_is_walking": true,
		"boss_facing": 1,
		"boss_sprite_frame": 15,
	}
	var selected_right: Dictionary = renderer._select_sheet(context)
	_expect(selected_right.get("texture", null) == walk_right, "Gaksital facing-right walk should use the right front-sidestep texture")
	_expect(int(selected_right.get("frame_count", 0)) == 16, "Gaksital walk should keep 16 frames")
	_expect(int(selected_right.get("grid_cols", 0)) == 4, "Gaksital walk should use the 4x4 grid")
	_expect(renderer._get_cell_region(15, 256.0, 256.0, 4, 16) == Rect2(768.0, 768.0, 256.0, 256.0), "Gaksital walk frame 15 should slice the final 4x4 cell")

	var left_context: Dictionary = context.duplicate(true)
	left_context["boss_facing"] = -1
	var selected_left: Dictionary = renderer._select_sheet(left_context)
	_expect(selected_left.get("texture", null) == walk_left, "Gaksital facing-left walk should use the baked left mirror texture")

	var victory_context: Dictionary = context.duplicate(true)
	victory_context["boss_is_walking"] = false
	victory_context["boss_victory_active"] = true
	victory_context["boss_result_frame"] = 7
	var selected_victory: Dictionary = renderer._select_sheet(victory_context)
	_expect(selected_victory.get("texture", null) == victory_texture, "Gaksital victory should use the result static sheet")
	_expect(int(selected_victory.get("frame_count", 0)) == 8, "Gaksital result sheets should stop at 8 used frames")
	_expect(int(selected_victory.get("grid_cols", 0)) == 3, "Gaksital result sheets should use the 3x3 grid")
	_expect(renderer._get_cell_region(7, 256.0, 256.0, 3, 8) == Rect2(256.0, 512.0, 256.0, 256.0), "Gaksital result frame 7 should avoid the unused cell 8")

	var priority_context: Dictionary = victory_context.duplicate(true)
	priority_context["boss_defeat_active"] = true
	var selected_priority: Dictionary = renderer._select_sheet(priority_context)
	_expect(selected_priority.get("texture", null) == defeat_texture, "Gaksital defeat should outrank victory when both result flags are active")

	var fan_context: Dictionary = context.duplicate(true)
	fan_context["boss_is_walking"] = false
	fan_context["boss_fan_throw_active"] = true
	fan_context["boss_fan_throw_frame"] = 15
	var selected_fan: Dictionary = renderer._select_sheet(fan_context)
	_expect(selected_fan.get("texture", null) == fan_throw_texture, "Gaksital fan throw should keep its 16f skill sheet")
	_expect(int(selected_fan.get("grid_cols", 0)) == 4, "Gaksital fan throw should keep the 4x4 grid")


func _make_texture(width: int, height: int) -> ImageTexture:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)


func _texture_size(textures: Dictionary, key: String) -> Vector2:
	var texture := textures.get(key, null) as Texture2D
	return texture.get_size() if texture != null else Vector2.ZERO


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
