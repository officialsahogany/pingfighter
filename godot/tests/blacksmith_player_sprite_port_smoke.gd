extends SceneTree

const BattleDrawActorContext := preload("res://scripts/core/battle_draw_actor_context.gd")
const BattleDrawContext := preload("res://scripts/core/battle_draw_context.gd")
const BattleResources := preload("res://scripts/resources/battle_resources.gd")
const BattleUpdateEffectsSpriteContextBuilder := preload("res://scripts/core/battle_update_effects_sprite_context_builder.gd")
const BallUpdateOwnerSnapshot := preload("res://scripts/ball/ball_update_owner_snapshot.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")
const Stage1PlayerSpriteRenderer := preload("res://scripts/stages/stage1/stage1_player_sprite_renderer.gd")

const IDLE_SHEET_PATH := "res://assets/sprites/characters/blacksmith/blacksmith_idle_back_autosprite_v3_custom_4x2_160_clean.png"
const WALK_LEFT_SHEET_PATH := "res://assets/sprites/characters/blacksmith/blacksmith_sprint_dash_left_25deg_custom_v3_selected_mirror_from_right_4x2_160_clean.png"
const WALK_RIGHT_SHEET_PATH := "res://assets/sprites/characters/blacksmith/blacksmith_sprint_dash_right_25deg_custom_v3_selected_4x2_160_clean.png"
const DASH_LEFT_SHEET_PATH := "res://assets/sprites/characters/blacksmith/blacksmith_dash_slide_tackle_rear_left_hold_v4_mirror_from_right_4x2_160_clean.png"
const DASH_RIGHT_SHEET_PATH := "res://assets/sprites/characters/blacksmith/blacksmith_dash_slide_tackle_rear_right_hold_v4_4x2_160_clean.png"
const ATTACK_LEFT_SHEET_PATH := "res://assets/sprites/characters/blacksmith/blacksmith_attack_left_shield_bash_autosprite_v2_16f_4x4_160_clean.png"
const ATTACK_RIGHT_SHEET_PATH := "res://assets/sprites/characters/blacksmith/blacksmith_attack_right_hammer_smash_autosprite_v4_16f_4x4_160_clean.png"
const THOR_SHIELD_DEPLOY_SHEET_PATH := "res://assets/sprites/characters/blacksmith/blacksmith_thor_shield_overhead_autosprite_v3_hybrid_4x4_160_clean.png"
const THOR_SHIELD_STRETCH_TEXTURE_PATH := "res://assets/sprites/characters/blacksmith/blacksmith_thor_shield_stretch_imagegen_v1.png"
const VICTORY_SHEET_PATH := "res://assets/sprites/characters/blacksmith/blacksmith_victory_rear_autosprite_v1_49f_7x7_160_clean.png"
const DEFEAT_SHEET_PATH := "res://assets/sprites/characters/blacksmith/blacksmith_defeat_rear_autosprite_v1_49f_7x7_160_clean.png"
const RUNTIME_SHEET_SIZE := Vector2(640.0, 320.0)
const RUNTIME_ATTACK_SHEET_SIZE := Vector2(640.0, 640.0)
const RUNTIME_THOR_SHIELD_STRETCH_SIZE := Vector2(512.0, 192.0)
const RUNTIME_RESULT_49_SHEET_SIZE := Vector2(1120.0, 1120.0)
const BLACKSMITH_DRAW_SIZE := Vector2(128.0, 128.0)

var _failures: Array[String] = []


func _init() -> void:
	var idle_direct: Texture2D = load(IDLE_SHEET_PATH)
	var walk_left_direct: Texture2D = load(WALK_LEFT_SHEET_PATH)
	var walk_right_direct: Texture2D = load(WALK_RIGHT_SHEET_PATH)
	var dash_left_direct: Texture2D = load(DASH_LEFT_SHEET_PATH)
	var dash_right_direct: Texture2D = load(DASH_RIGHT_SHEET_PATH)
	var attack_left_direct: Texture2D = load(ATTACK_LEFT_SHEET_PATH)
	var attack_right_direct: Texture2D = load(ATTACK_RIGHT_SHEET_PATH)
	var thor_shield_deploy_direct: Texture2D = load(THOR_SHIELD_DEPLOY_SHEET_PATH)
	var thor_shield_stretch_direct: Texture2D = load(THOR_SHIELD_STRETCH_TEXTURE_PATH)
	var victory_direct: Texture2D = load(VICTORY_SHEET_PATH)
	var defeat_direct: Texture2D = load(DEFEAT_SHEET_PATH)
	_expect(_is_runtime_sheet(idle_direct), "Blacksmith idle sheet should load as 4x2 160px runtime cells")
	_expect(_is_runtime_sheet(walk_left_direct), "Blacksmith left-run sheet should load as 4x2 160px runtime cells")
	_expect(_is_runtime_sheet(walk_right_direct), "Blacksmith right-run sheet should load as 4x2 160px runtime cells")
	_expect(_is_runtime_sheet(dash_left_direct), "Blacksmith left-dash sheet should load as 4x2 160px runtime cells")
	_expect(_is_runtime_sheet(dash_right_direct), "Blacksmith right-dash sheet should load as 4x2 160px runtime cells")
	_expect(_is_attack_runtime_sheet(attack_left_direct), "Blacksmith left shield-bash attack sheet should load as 4x4 160px runtime cells")
	_expect(_is_attack_runtime_sheet(attack_right_direct), "Blacksmith right hammer-smash attack sheet should load as 4x4 160px runtime cells")
	_expect(_is_attack_runtime_sheet(thor_shield_deploy_direct), "Blacksmith Thor Shield deploy sheet should load as 4x4 160px runtime cells")
	_expect(_is_thor_shield_stretch_texture(thor_shield_stretch_direct), "Blacksmith Thor Shield stretch texture should load as the 512x192 imagegen prop")
	_expect(_is_result_49_runtime_sheet(victory_direct), "Blacksmith victory sheet should load as a 7x7 49-frame runtime sheet")
	_expect(_is_result_49_runtime_sheet(defeat_direct), "Blacksmith defeat sheet should load as a 7x7 49-frame runtime sheet")

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
	var dash_left_texture: Variant = textures.get("blacksmith_player_dash_left_sheet", null)
	var dash_right_texture: Variant = textures.get("blacksmith_player_dash_right_sheet", null)
	var attack_left_texture: Variant = textures.get("blacksmith_player_attack_left_sheet", null)
	var attack_right_texture: Variant = textures.get("blacksmith_player_attack_right_sheet", null)
	var thor_shield_deploy_texture: Variant = textures.get("blacksmith_player_thor_shield_deploy_sheet", null)
	var thor_shield_stretch_texture: Variant = textures.get("blacksmith_thor_shield_stretch_texture", null)
	_expect(_is_runtime_sheet(idle_texture), "BattleResources should load the Blacksmith idle sheet")
	_expect(_is_runtime_sheet(walk_left_texture), "BattleResources should load the Blacksmith left-run sheet")
	_expect(_is_runtime_sheet(walk_right_texture), "BattleResources should load the Blacksmith right-run sheet")
	_expect(_is_runtime_sheet(dash_left_texture), "BattleResources should load the Blacksmith left-dash sheet")
	_expect(_is_runtime_sheet(dash_right_texture), "BattleResources should load the Blacksmith right-dash sheet")
	_expect(_is_attack_runtime_sheet(attack_left_texture), "BattleResources should load the 16-frame Blacksmith shield-bash attack sheet")
	_expect(_is_attack_runtime_sheet(attack_right_texture), "BattleResources should load the 16-frame Blacksmith hammer-smash attack sheet")
	_expect(_is_attack_runtime_sheet(thor_shield_deploy_texture), "BattleResources should load the 16-frame Blacksmith Thor Shield deploy sheet")
	_expect(_is_thor_shield_stretch_texture(thor_shield_stretch_texture), "BattleResources should load the imagegen Blacksmith Thor Shield stretch prop")
	_expect(textures.get("player_idle_back_sheet", null) == null, "Blacksmith selected load should not expose Smasher idle fallback")

	var result_resources := BattleResources.new()
	var result_textures: Dictionary = result_resources.load_all({
		"selected_character_type": "kohaku",
		"current_stage": 1,
		"include_all_characters": false,
		"include_all_stages": false,
		"include_result_sheets": true,
	})
	var victory_texture: Variant = result_textures.get("player_victory_sheet", null)
	var defeat_texture: Variant = result_textures.get("player_defeat_sheet", null)
	_expect(_is_result_49_runtime_sheet(victory_texture), "BattleResources should load the Blacksmith victory result sheet")
	_expect(_is_result_49_runtime_sheet(defeat_texture), "BattleResources should load the Blacksmith defeat result sheet")

	var update_builder := BattleUpdateEffectsSpriteContextBuilder.new()
	var update_context: Dictionary = update_builder.build_context(textures, "kohaku")
	_expect(str(update_context.get("selected_character_type", "")) == "blacksmith", "sprite context should normalize Kohaku alias to Blacksmith")
	_expect(bool(update_context.get("player_has_sprite", false)), "Blacksmith walk sheets should enable player sprite")
	_expect(bool(update_context.get("player_has_idle_sprite", false)), "Blacksmith idle sheet should enable idle sprite")
	_expect(int(update_context.get("player_sprite_frame_count", 0)) == 8, "Blacksmith run sheets should use 8 runtime frames")
	_expect_close(float(update_context.get("player_sprite_animation_speed", 0.0)), 0.050, "Blacksmith run sheets should keep 0.050 cadence")
	_expect(bool(update_context.get("player_has_dash_sheet", false)), "Blacksmith should expose dedicated dash sheets")
	_expect(int(update_context.get("player_dash_frame_count", 0)) == 8, "Blacksmith dash sheets should use 8 runtime frames")
	_expect(int(update_context.get("player_idle_frame_count", 0)) == 8, "Blacksmith idle sheet should use 8 frames")
	_expect_close(float(update_context.get("player_idle_animation_speed", 0.0)), 0.15, "Blacksmith idle sheet should keep 0.15 cadence")
	_expect(bool(update_context.get("player_has_attack_sheet", false)), "Blacksmith should expose dedicated ball-contact attack sheets")
	_expect(int(update_context.get("player_hit_frame_count", 0)) == 16, "Blacksmith attack sheets should use 16 hit frames")
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
	_expect(actor_context.get("player_dash_left_texture", null) == dash_left_texture, "draw context should expose Blacksmith left-dash sheet")
	_expect(actor_context.get("player_dash_right_texture", null) == dash_right_texture, "draw context should expose Blacksmith right-dash sheet")
	_expect(actor_context.get("player_attack_left_sheet", null) == attack_left_texture, "draw context should expose Blacksmith left shield-bash attack sheet")
	_expect(actor_context.get("player_attack_right_sheet", null) == attack_right_texture, "draw context should expose Blacksmith right hammer-smash attack sheet")
	_expect(actor_context.get("blacksmith_thor_shield_deploy_sheet", null) == thor_shield_deploy_texture, "draw context should expose Blacksmith Thor Shield deploy sheet")
	_expect(bool(actor_context.get("has_blacksmith_thor_shield_deploy_sheet", false)), "draw context should mark the Thor Shield deploy sheet available")
	_expect(actor_context.get("blacksmith_thor_shield_stretch_texture", null) == thor_shield_stretch_texture, "draw context should expose the imagegen Thor Shield stretch prop")
	_expect(bool(actor_context.get("has_blacksmith_thor_shield_stretch_texture", false)), "draw context should mark the imagegen Thor Shield stretch prop available")
	_expect(int(actor_context.get("player_idle_frame_count", 0)) == 8, "draw context should expose 8 Blacksmith idle frames")
	_expect(int(actor_context.get("player_idle_grid_cols", 0)) == 4, "draw context should expose 4 Blacksmith idle columns")
	_expect(int(actor_context.get("player_idle_grid_rows", 0)) == 2, "draw context should expose 2 Blacksmith idle rows")
	_expect(float(actor_context.get("player_idle_cell_width", 0.0)) == 160.0, "Blacksmith idle cell width should be 160")
	_expect(float(actor_context.get("player_idle_cell_height", 0.0)) == 160.0, "Blacksmith idle cell height should be 160")
	_expect(int(actor_context.get("player_directional_walk_frame_count", 0)) == 8, "draw context should expose 8 Blacksmith run frames")
	_expect(int(actor_context.get("player_directional_walk_grid_cols", 0)) == 4, "draw context should expose 4 Blacksmith walk columns")
	_expect(bool(actor_context.get("has_player_directional_dash_sheet", false)), "draw context should expose dedicated Blacksmith dash sheets")
	_expect(int(actor_context.get("player_directional_dash_frame_count", 0)) == 8, "draw context should expose 8 Blacksmith dash frames")
	_expect(int(actor_context.get("player_directional_dash_grid_cols", 0)) == 4, "draw context should expose 4 Blacksmith dash columns")
	_expect(actor_context.get("player_idle_draw_size", Vector2.ZERO) == BLACKSMITH_DRAW_SIZE, "Blacksmith idle draw size should be reduced by 20%")
	_expect(actor_context.get("player_directional_walk_draw_size", Vector2.ZERO) == BLACKSMITH_DRAW_SIZE, "Blacksmith walk draw size should be reduced by 20%")
	_expect(actor_context.get("player_directional_dash_draw_size", Vector2.ZERO) == BLACKSMITH_DRAW_SIZE, "Blacksmith dash draw size should match the reduced SD scale")
	_expect(actor_context.get("player_directional_attack_draw_size", Vector2.ZERO) == BLACKSMITH_DRAW_SIZE, "Blacksmith attack draw size should match the reduced SD scale")
	_expect(actor_context.get("blacksmith_thor_shield_deploy_draw_size", Vector2.ZERO) == BLACKSMITH_DRAW_SIZE, "Blacksmith Thor Shield deploy draw size should match the reduced SD scale")

	var shield_open_context: Dictionary = draw_builder.build({
		"selected_character_type": "blacksmith",
		"textures": textures,
		"blacksmith_umbrella_open": true,
		"blacksmith_umbrella_open_ratio": 1.0,
	}, {})
	var shield_mid_context: Dictionary = draw_builder.build({
		"selected_character_type": "blacksmith",
		"textures": textures,
		"blacksmith_umbrella_open": true,
		"blacksmith_umbrella_open_ratio": 0.50,
	}, {})
	var shield_close_context: Dictionary = draw_builder.build({
		"selected_character_type": "blacksmith",
		"textures": textures,
		"blacksmith_umbrella_open": true,
		"blacksmith_umbrella_retracting": true,
		"blacksmith_umbrella_anim_timer": 0.0,
	}, {})
	_expect(bool(shield_open_context.get("blacksmith_thor_shield_deploy_active", false)), "open Thor Shield should activate the integrated deploy sprite")
	_expect(int(shield_open_context.get("blacksmith_thor_shield_deploy_frame", -1)) == 15, "open Thor Shield should hold the final integrated deploy frame")
	_expect(int(shield_mid_context.get("blacksmith_thor_shield_deploy_frame", -1)) == 8, "mid Thor Shield open ratio should select the middle integrated deploy frame")
	_expect(int(shield_close_context.get("blacksmith_thor_shield_deploy_frame", -1)) == 0, "fully retracted Thor Shield should select the folded integrated deploy frame")

	var live_draw_builder := BattleDrawContext.new()
	var live_owner := FakeOwner.new(textures)
	var live_registry := FakeRegistry.new({
		"blacksmith_thor_shield_state": FakeThorShieldState.new({
			"blacksmith_umbrella_open": true,
			"blacksmith_umbrella_open_ratio": 1.0,
			"blacksmith_thor_shield_open_ratio": 1.0,
			"blacksmith_umbrella_visual_state": "open",
		}),
	})
	var live_scene_context: Dictionary = live_draw_builder.build_scene_context(live_owner, Vector2.ZERO, live_registry)
	var live_actor_context: Dictionary = live_draw_builder.build_actor_context(live_scene_context, {})
	_expect(bool(live_scene_context.get("blacksmith_umbrella_open", false)), "live scene draw context should carry Blacksmith Thor Shield state snapshot")
	_expect(float(live_scene_context.get("blacksmith_umbrella_open_ratio", 0.0)) == 1.0, "live scene draw context should carry Blacksmith Thor Shield state ratio")
	_expect(bool(live_actor_context.get("blacksmith_thor_shield_deploy_active", false)), "live actor draw context should activate the AutoSprite Thor Shield deploy sheet from the state module")
	_expect(int(live_actor_context.get("blacksmith_thor_shield_deploy_frame", -1)) == 15, "live actor draw context should map state-open Thor Shield to the final deploy frame")

	var result_actor_context: Dictionary = draw_builder.build({
		"selected_character_type": "kohaku",
		"textures": result_textures,
		"current_stage": 1,
	}, {"scoreboard_state": FakeScoreboardState.new("player", 0.40)})
	_expect(bool(result_actor_context.get("player_victory_active", false)), "Blacksmith player victory should activate during player-win result state")
	_expect(result_actor_context.get("player_victory_sheet", null) == victory_texture, "draw context should expose the Blacksmith victory sheet")
	_expect(int(result_actor_context.get("player_victory_frame_count", 0)) == 49, "Blacksmith victory sheet should use 49 authored result frames")
	_expect(int(result_actor_context.get("player_victory_grid_cols", 0)) == 7, "Blacksmith victory sheet should use a 7-column result grid")
	_expect(result_actor_context.get("player_victory_draw_size", Vector2.ZERO) == BLACKSMITH_DRAW_SIZE, "Blacksmith victory draw size should match the reduced SD scale")

	var defeat_actor_context: Dictionary = draw_builder.build({
		"selected_character_type": "kohaku",
		"textures": result_textures,
		"current_stage": 1,
	}, {"scoreboard_state": FakeScoreboardState.new("boss", 0.40)})
	_expect(bool(defeat_actor_context.get("player_defeat_active", false)), "Blacksmith player defeat should activate during boss-win result state")
	_expect(defeat_actor_context.get("player_defeat_sheet", null) == defeat_texture, "draw context should expose the Blacksmith defeat sheet")
	_expect(int(defeat_actor_context.get("player_defeat_frame_count", 0)) == 49, "Blacksmith defeat sheet should use 49 authored result frames")
	_expect(int(defeat_actor_context.get("player_defeat_grid_cols", 0)) == 7, "Blacksmith defeat sheet should use a 7-column result grid")
	_expect(defeat_actor_context.get("player_defeat_draw_size", Vector2.ZERO) == BLACKSMITH_DRAW_SIZE, "Blacksmith defeat draw size should match the reduced SD scale")

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
	var left_dash_context: Dictionary = draw_builder.build({
		"selected_character_type": "blacksmith",
		"textures": textures,
		"dash_snapshot": {"active": true, "direction": -1.0},
	}, {})
	var right_dash_context: Dictionary = draw_builder.build({
		"selected_character_type": "blacksmith",
		"textures": textures,
		"dash_snapshot": {"active": true, "direction": 1.0},
	}, {})
	_expect(int(left_hit_context.get("player_hit_frame_count", 0)) == 16, "left-hit draw context should expose 16 Blacksmith hit frames")
	_expect(int(left_hit_context.get("player_directional_attack_grid_rows", 0)) == 4, "left-hit draw context should use a 4x4 attack grid")
	_expect(renderer.call("_get_player_directional_attack_texture", left_hit_context) == attack_left_texture, "left-of-center ball contact should select the shield-bash attack sheet")
	_expect(renderer.call("_get_player_directional_attack_texture", right_hit_context) == attack_right_texture, "right-of-center ball contact should select the hammer-smash attack sheet")
	_expect(renderer.call("_get_player_directional_dash_texture", left_dash_context) == dash_left_texture, "left dash should select the Blacksmith shield-side dash sheet")
	_expect(renderer.call("_get_player_directional_dash_texture", right_dash_context) == dash_right_texture, "right dash should select the Blacksmith hammer-side dash sheet")
	_expect(renderer.call("_get_blacksmith_thor_shield_deploy_sprite_region", shield_open_context) == Rect2(480.0, 480.0, 160.0, 160.0), "open Thor Shield should sample the final 4x4 deploy cell")
	_expect(renderer.call("_get_blacksmith_thor_shield_deploy_sprite_region", shield_mid_context) == Rect2(0.0, 320.0, 160.0, 160.0), "mid Thor Shield should sample the row-major middle deploy cell")
	_expect(renderer.call("_get_player_defeat_sprite_region", defeat_actor_context.merged({"player_defeat_frame": 48}, true)) == Rect2(960.0, 960.0, 160.0, 160.0), "Blacksmith final defeat frame should sample the last 7x7 result cell")

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


func _is_attack_runtime_sheet(value: Variant) -> bool:
	if not (value is Texture2D):
		return false
	var texture: Texture2D = value
	return texture.get_size() == RUNTIME_ATTACK_SHEET_SIZE


func _is_thor_shield_stretch_texture(value: Variant) -> bool:
	if not (value is Texture2D):
		return false
	var texture: Texture2D = value
	return texture.get_size() == RUNTIME_THOR_SHIELD_STRETCH_SIZE


func _is_result_49_runtime_sheet(value: Variant) -> bool:
	if not (value is Texture2D):
		return false
	var texture: Texture2D = value
	return texture.get_size() == RUNTIME_RESULT_49_SHEET_SIZE


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.001, message)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)


class FakeOwner extends RefCounted:
	var battle_textures: Dictionary
	var selected_character_type := "blacksmith"
	var blacksmith_umbrella_open := false
	var blacksmith_umbrella_anim_timer := 0.0
	var blacksmith_umbrella_retracting := false
	var blacksmith_umbrella_anim_direction := 1
	var blacksmith_umbrella_open_ratio := 0.0
	var blacksmith_thor_shield_open_ratio := 0.0
	var blacksmith_umbrella_raise_amount := 0.0
	var blacksmith_umbrella_shield_open_amount := 0.0
	var blacksmith_umbrella_visual_state := "closed"
	var blacksmith_umbrella_folded := true
	var blacksmith_umbrella_deployed := false
	var blacksmith_umbrella_swing_active := false
	var blacksmith_umbrella_swing_direction := 0
	var blacksmith_umbrella_swing_timer := 0.0
	var blacksmith_umbrella_gauge := 5
	var blacksmith_umbrella_gauge_max := 5
	var blacksmith_umbrella_gauge_gain := 60.0
	var blacksmith_umbrella_damage_flash_timer := 0.0
	var blacksmith_umbrella_hit_pulse_timer := 0.0

	func _init(textures: Dictionary) -> void:
		battle_textures = textures


class FakeRegistry extends RefCounted:
	var instances: Dictionary

	func _init(instance_map: Dictionary = {}) -> void:
		instances = instance_map

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		return value if value is Object else null


class FakeThorShieldState extends RefCounted:
	var snapshot: Dictionary

	func _init(snapshot_value: Dictionary) -> void:
		snapshot = snapshot_value

	func get_snapshot() -> Dictionary:
		return snapshot.duplicate(true)


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


class FakeScoreboardState extends RefCounted:
	var _scoring_side: String
	var _timer: float

	func _init(scoring_side: String, timer: float) -> void:
		_scoring_side = scoring_side
		_timer = timer

	func is_active() -> bool:
		return true

	func get_last_scoring_side() -> String:
		return _scoring_side

	func get_player_points() -> int:
		return 1 if _scoring_side == "player" else 0

	func get_boss_points() -> int:
		return 1 if _scoring_side == "boss" else 0

	func get_timer() -> float:
		return _timer
