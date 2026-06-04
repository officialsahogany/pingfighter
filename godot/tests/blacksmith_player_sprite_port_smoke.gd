extends SceneTree

const BattleDrawActorContext := preload("res://scripts/core/battle_draw_actor_context.gd")
const BattleResources := preload("res://scripts/resources/battle_resources.gd")
const BattleUpdateEffectsSpriteContextBuilder := preload("res://scripts/core/battle_update_effects_sprite_context_builder.gd")
const BallUpdateOwnerSnapshot := preload("res://scripts/ball/ball_update_owner_snapshot.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")
const Stage1PlayerSpriteRenderer := preload("res://scripts/stages/stage1/stage1_player_sprite_renderer.gd")

const IDLE_SHEET_PATH := "res://assets/sprites/characters/blacksmith/blacksmith_idle_back_autosprite_v3_custom_4x2_160_clean.png"
const WALK_LEFT_SHEET_PATH := "res://assets/sprites/characters/blacksmith/blacksmith_sprint_dash_left_25deg_custom_v3_selected_mirror_from_right_4x2_160_clean.png"
const WALK_RIGHT_SHEET_PATH := "res://assets/sprites/characters/blacksmith/blacksmith_sprint_dash_right_25deg_custom_v3_selected_4x2_160_clean.png"
const ATTACK_LEFT_SHEET_PATH := "res://assets/sprites/characters/blacksmith/blacksmith_attack_left_shield_bash_autosprite_v1_4x2_160_clean.png"
const ATTACK_RIGHT_SHEET_PATH := "res://assets/sprites/characters/blacksmith/blacksmith_attack_right_hammer_smash_autosprite_v3_rear_only_4x2_160_clean.png"
const RUNTIME_SHEET_SIZE := Vector2(640.0, 320.0)
const BLACKSMITH_DRAW_SIZE := Vector2(128.0, 128.0)

var _failures: Array[String] = []


func _init() -> void:
	var idle_direct: Texture2D = load(IDLE_SHEET_PATH)
	var walk_left_direct: Texture2D = load(WALK_LEFT_SHEET_PATH)
	var walk_right_direct: Texture2D = load(WALK_RIGHT_SHEET_PATH)
	var attack_left_direct: Texture2D = load(ATTACK_LEFT_SHEET_PATH)
	var attack_right_direct: Texture2D = load(ATTACK_RIGHT_SHEET_PATH)
	_expect(_is_runtime_sheet(idle_direct), "Blacksmith idle sheet should load as 4x2 160px runtime cells")
	_expect(_is_runtime_sheet(walk_left_direct), "Blacksmith left-walk sheet should load as 4x2 160px runtime cells")
	_expect(_is_runtime_sheet(walk_right_direct), "Blacksmith right-walk sheet should load as 4x2 160px runtime cells")
	_expect(_is_runtime_sheet(attack_left_direct), "Blacksmith left shield-bash attack sheet should load as 4x2 160px runtime cells")
	_expect(_is_runtime_sheet(attack_right_direct), "Blacksmith right hammer-smash attack sheet should load as 4x2 160px runtime cells")

	var runtime := PlayerCharacterRuntime.new()
	var render_context: Dictionary = runtime.get_player_render_context("blacksmith")
	_expect(not bool(render_context.get("use_smasher_sprite_textures", true)), "Blacksmith should use dedicated sprite textures")

	var resources := BattleResources.new()
	var textures: Dictionary = resources.load_all({
		"selected_character_type": "blacksmith",
		"current_stage": 1,
		"include_all_characters": false,
		"include_all_stages": false,
		"include_result_sheets": false,
	})
	var idle_texture: Variant = textures.get("blacksmith_player_idle_sheet", null)
	var walk_left_texture: Variant = textures.get("blacksmith_player_walk_left_sheet", null)
	var walk_right_texture: Variant = textures.get("blacksmith_player_walk_right_sheet", null)
	var attack_left_texture: Variant = textures.get("blacksmith_player_attack_left_sheet", null)
	var attack_right_texture: Variant = textures.get("blacksmith_player_attack_right_sheet", null)
	_expect(_is_runtime_sheet(idle_texture), "BattleResources should load the Blacksmith idle sheet")
	_expect(_is_runtime_sheet(walk_left_texture), "BattleResources should load the Blacksmith left-walk sheet")
	_expect(_is_runtime_sheet(walk_right_texture), "BattleResources should load the Blacksmith right-walk sheet")
	_expect(_is_runtime_sheet(attack_left_texture), "BattleResources should load the Blacksmith shield-bash attack sheet")
	_expect(_is_runtime_sheet(attack_right_texture), "BattleResources should load the Blacksmith hammer-smash attack sheet")
	_expect(textures.get("player_idle_back_sheet", null) == null, "Blacksmith selected load should not expose Smasher idle fallback")

	var update_builder := BattleUpdateEffectsSpriteContextBuilder.new()
	var update_context: Dictionary = update_builder.build_context(textures, "kohaku")
	_expect(str(update_context.get("selected_character_type", "")) == "blacksmith", "sprite context should normalize Kohaku alias to Blacksmith")
	_expect(bool(update_context.get("player_has_sprite", false)), "Blacksmith walk sheets should enable player sprite")
	_expect(bool(update_context.get("player_has_idle_sprite", false)), "Blacksmith idle sheet should enable idle sprite")
	_expect(int(update_context.get("player_sprite_frame_count", 0)) == 8, "Blacksmith walk sheets should use 8 runtime frames")
	_expect_close(float(update_context.get("player_sprite_animation_speed", 0.0)), 0.050, "Blacksmith walk sheets should keep 0.050 cadence")
	_expect(int(update_context.get("player_idle_frame_count", 0)) == 8, "Blacksmith idle sheet should use 8 frames")
	_expect_close(float(update_context.get("player_idle_animation_speed", 0.0)), 0.15, "Blacksmith idle sheet should keep 0.15 cadence")
	_expect(bool(update_context.get("player_has_attack_sheet", false)), "Blacksmith should expose dedicated ball-contact attack sheets")
	_expect(int(update_context.get("player_hit_frame_count", 0)) == 8, "Blacksmith attack sheets should use 8 hit frames")
	_expect(bool(update_context.get("player_hit_linear_frames", false)), "Blacksmith attack sheets should use linear authored frames")

	var draw_builder := BattleDrawActorContext.new()
	var actor_context: Dictionary = draw_builder.build({
		"selected_character_type": "blacksmith",
		"textures": textures,
	}, {})
	_expect(str(actor_context.get("selected_character_type", "")) == "blacksmith", "draw context should keep Blacksmith selected")
	_expect(actor_context.get("player_sprite_texture", null) == idle_texture, "draw context should use Blacksmith idle as base sprite texture")
	_expect(actor_context.get("player_idle_sprite_texture", null) == idle_texture, "draw context should use Blacksmith idle sheet for idle")
	_expect(actor_context.get("player_walk_left_texture", null) == walk_left_texture, "draw context should use Blacksmith left-walk sheet")
	_expect(actor_context.get("player_walk_right_texture", null) == walk_right_texture, "draw context should use Blacksmith right-walk sheet")
	_expect(actor_context.get("player_attack_left_sheet", null) == attack_left_texture, "draw context should expose Blacksmith left shield-bash attack sheet")
	_expect(actor_context.get("player_attack_right_sheet", null) == attack_right_texture, "draw context should expose Blacksmith right hammer-smash attack sheet")
	_expect(int(actor_context.get("player_idle_frame_count", 0)) == 8, "draw context should expose 8 Blacksmith idle frames")
	_expect(int(actor_context.get("player_idle_grid_cols", 0)) == 4, "draw context should expose 4 Blacksmith idle columns")
	_expect(int(actor_context.get("player_idle_grid_rows", 0)) == 2, "draw context should expose 2 Blacksmith idle rows")
	_expect(float(actor_context.get("player_idle_cell_width", 0.0)) == 160.0, "Blacksmith idle cell width should be 160")
	_expect(float(actor_context.get("player_idle_cell_height", 0.0)) == 160.0, "Blacksmith idle cell height should be 160")
	_expect(int(actor_context.get("player_directional_walk_frame_count", 0)) == 8, "draw context should expose 8 Blacksmith walk frames")
	_expect(int(actor_context.get("player_directional_walk_grid_cols", 0)) == 4, "draw context should expose 4 Blacksmith walk columns")
	_expect(actor_context.get("player_idle_draw_size", Vector2.ZERO) == BLACKSMITH_DRAW_SIZE, "Blacksmith idle draw size should be reduced by 20%")
	_expect(actor_context.get("player_directional_walk_draw_size", Vector2.ZERO) == BLACKSMITH_DRAW_SIZE, "Blacksmith walk draw size should be reduced by 20%")
	_expect(actor_context.get("player_directional_attack_draw_size", Vector2.ZERO) == BLACKSMITH_DRAW_SIZE, "Blacksmith attack draw size should match the reduced SD scale")

	var owner_snapshot := BallUpdateOwnerSnapshot.new()
	var owner_context: Dictionary = owner_snapshot.build(FakeOwner.new(textures))
	_expect(bool(owner_context.get("player_has_hit_sprite", false)), "Blacksmith attack sheets should allow ball-contact hit animation to trigger")

	var renderer := Stage1PlayerSpriteRenderer.new()
	var left_hit_context: Dictionary = draw_builder.build({
		"selected_character_type": "blacksmith",
		"textures": textures,
	}, {"animation_state": FakeAnimationState.new(true, -1)})
	var right_hit_context: Dictionary = draw_builder.build({
		"selected_character_type": "blacksmith",
		"textures": textures,
	}, {"animation_state": FakeAnimationState.new(true, 1)})
	_expect(int(left_hit_context.get("player_hit_frame_count", 0)) == 8, "left-hit draw context should expose 8 Blacksmith hit frames")
	_expect(int(left_hit_context.get("player_directional_attack_grid_rows", 0)) == 2, "left-hit draw context should use a 4x2 attack grid")
	_expect(renderer.call("_get_player_directional_attack_texture", left_hit_context) == attack_left_texture, "left-of-center ball contact should select the shield-bash attack sheet")
	_expect(renderer.call("_get_player_directional_attack_texture", right_hit_context) == attack_right_texture, "right-of-center ball contact should select the hammer-smash attack sheet")

	if _failures.is_empty():
		print("blacksmith_player_sprite_port_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _is_runtime_sheet(value: Variant) -> bool:
	if not (value is Texture2D):
		return false
	var texture: Texture2D = value
	return texture.get_size() == RUNTIME_SHEET_SIZE


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.001, message)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)


class FakeOwner extends RefCounted:
	var battle_textures: Dictionary
	var selected_character_type := "blacksmith"

	func _init(textures: Dictionary) -> void:
		battle_textures = textures


class FakeAnimationState extends RefCounted:
	var _hit_active: bool
	var _hit_side: int

	func _init(hit_active: bool, hit_side: int) -> void:
		_hit_active = hit_active
		_hit_side = hit_side

	func get_draw_context() -> Dictionary:
		return {
			"player_hit_active": _hit_active,
			"player_hit_timer": 0.18 if _hit_active else 0.0,
			"player_hit_side": _hit_side,
			"player_hit_center": false,
			"player_hit_frame": 4,
		}
