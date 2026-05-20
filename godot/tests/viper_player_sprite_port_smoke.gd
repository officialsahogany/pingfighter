extends SceneTree

const BallUpdateOwnerSnapshot := preload("res://scripts/ball/ball_update_owner_snapshot.gd")
const BattleDrawActorContext := preload("res://scripts/core/battle_draw_actor_context.gd")
const BattleResources := preload("res://scripts/resources/battle_resources.gd")
const BattleUpdateEffectsContext := preload("res://scripts/core/battle_update_effects_context.gd")


class FakeOwner:
	extends RefCounted

	var data: Dictionary = {}

	func _init(initial_data: Dictionary) -> void:
		data = initial_data.duplicate(true)

	func _get(property: StringName) -> Variant:
		return data.get(str(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		data[str(property)] = value
		return true


class FakeRegistry:
	func get_instance(_key: String) -> Object:
		return null


class FakeAnimationState:
	func get_draw_context() -> Dictionary:
		return {
			"player_sprite_frame": 3,
			"player_idle_frame": 2,
			"player_hit_active": true,
			"player_hit_frame": 1,
			"player_hit_side": -1,
			"player_anim_clock": 0.0,
		}


class FakeScoreboardState:
	var scoring_side: String
	var timer: float

	func _init(initial_scoring_side: String = "player", initial_timer: float = 0.35) -> void:
		scoring_side = initial_scoring_side
		timer = initial_timer

	func is_active() -> bool:
		return true

	func get_last_scoring_side() -> String:
		return scoring_side

	func get_player_points() -> int:
		return 1 if scoring_side == "player" else 0

	func get_boss_points() -> int:
		return 1 if scoring_side == "boss" else 0

	func get_timer() -> float:
		return timer


func _init() -> void:
	var resources: Object = BattleResources.new()
	var textures: Dictionary = resources.load_all()
	_expect(_has_texture(textures, "viper_player_sprite_texture"), "viper walk strip should load")
	_expect(_has_texture(textures, "viper_player_idle_sprite_texture"), "viper idle strip should load")
	_expect(_has_texture(textures, "viper_player_idle_sheet"), "viper subculture idle sheet should load")
	_expect(_has_texture(textures, "viper_player_walk_left_sheet"), "viper subculture left walk sheet should load")
	_expect(_has_texture(textures, "viper_player_walk_right_sheet"), "viper subculture right walk sheet should load")
	_expect(_has_texture(textures, "viper_player_attack_left_sheet"), "viper subculture left attack sheet should load")
	_expect(_has_texture(textures, "viper_player_attack_right_sheet"), "viper subculture right attack sheet should load")
	_expect(_has_texture(textures, "viper_player_wall_cling_left_sheet"), "viper subculture left wall cling sheet should load")
	_expect(_has_texture(textures, "viper_player_wall_cling_right_sheet"), "viper subculture right wall cling sheet should load")
	_expect(_has_texture(textures, "viper_player_wall_flight_left_sheet"), "viper subculture left wall flight sheet should load")
	_expect(_has_texture(textures, "viper_player_wall_flight_right_sheet"), "viper subculture right wall flight sheet should load")
	_expect(_has_texture(textures, "viper_player_flying_kick_left_sheet"), "viper subculture left flying kick sheet should load")
	_expect(_has_texture(textures, "viper_player_flying_kick_right_sheet"), "viper subculture right flying kick sheet should load")
	_expect(_has_texture(textures, "viper_player_tumble_sheet"), "viper subculture tumble sheet should load")
	_expect(_has_texture(textures, "viper_player_blade_fire_sheet"), "viper subculture blade fire sheet should load")
	_expect(_has_texture(textures, "viper_player_throw_sheet"), "viper subculture throw sheet should load")
	_expect(_has_texture(textures, "viper_player_hover_left_sheet"), "viper subculture left hover sheet should load")
	_expect(_has_texture(textures, "viper_player_hover_right_sheet"), "viper subculture right hover sheet should load")
	_expect(_has_texture(textures, "viper_player_up_kick_left_sheet"), "viper subculture left up-kick sheet should load")
	_expect(_has_texture(textures, "viper_player_up_kick_right_sheet"), "viper subculture right up-kick sheet should load")
	_expect(_has_texture(textures, "viper_player_stun_sheet"), "viper subculture stun sheet should load")
	_expect(_has_texture(textures, "viper_player_confusion_sheet"), "viper subculture confusion sheet should load")
	_expect(_has_texture(textures, "viper_player_venom_edge_dash_sheet"), "viper subculture venom edge dash sheet should load")
	_expect(_has_texture(textures, "viper_player_venom_edge_strike_sheet"), "viper subculture venom edge strike sheet should load (front-view eye-slash)")
	_expect(_has_texture(textures, "viper_player_hit_left_strip_texture"), "viper left hit strip should load")
	_expect(_has_texture(textures, "viper_player_hit_right_strip_texture"), "viper right hit strip should load")
	_expect(_texture_size(textures, "viper_player_sprite_texture") == Vector2(2000.0, 120.0), "viper walk strip should be 8x 250x120")
	_expect(_texture_size(textures, "viper_player_idle_sprite_texture") == Vector2(2000.0, 120.0), "viper idle strip should be 8x 250x120")
	_expect(_texture_size(textures, "viper_player_idle_sheet") == Vector2(640.0, 320.0), "viper subculture idle sheet should be 4x2 grid of 160x160 cells")
	_expect(_texture_size(textures, "viper_player_walk_left_sheet") == Vector2(640.0, 320.0), "viper subculture left walk sheet should be 4x2 grid of 160x160 cells")
	_expect(_texture_size(textures, "viper_player_walk_right_sheet") == Vector2(640.0, 320.0), "viper subculture right walk sheet should be 4x2 grid of 160x160 cells")
	_expect(_texture_size(textures, "viper_player_attack_left_sheet") == Vector2(640.0, 320.0), "viper subculture left attack sheet should be 4x2 grid of 160x160 cells")
	_expect(_texture_size(textures, "viper_player_attack_right_sheet") == Vector2(640.0, 320.0), "viper subculture right attack sheet should be 4x2 grid of 160x160 cells")
	_expect(_texture_size(textures, "viper_player_wall_cling_left_sheet") == Vector2(640.0, 320.0), "viper wall cling left sheet should be 4x2 grid of 160x160 cells")
	_expect(_texture_size(textures, "viper_player_wall_cling_right_sheet") == Vector2(640.0, 320.0), "viper wall cling right sheet should be 4x2 grid of 160x160 cells")
	_expect(_texture_size(textures, "viper_player_wall_flight_left_sheet") == Vector2(640.0, 320.0), "viper wall flight left sheet should be 4x2 grid of 160x160 cells")
	_expect(_texture_size(textures, "viper_player_wall_flight_right_sheet") == Vector2(640.0, 320.0), "viper wall flight right sheet should be 4x2 grid of 160x160 cells")
	_expect(_texture_size(textures, "viper_player_flying_kick_left_sheet") == Vector2(640.0, 320.0), "viper flying kick left sheet should be 4x2 grid of 160x160 cells")
	_expect(_texture_size(textures, "viper_player_flying_kick_right_sheet") == Vector2(640.0, 320.0), "viper flying kick right sheet should be 4x2 grid of 160x160 cells")
	_expect(_texture_size(textures, "viper_player_tumble_sheet") == Vector2(640.0, 320.0), "viper tumble sheet should be 4x2 grid of 160x160 cells")
	_expect(_texture_size(textures, "viper_player_blade_fire_sheet") == Vector2(640.0, 320.0), "viper blade fire sheet should be 4x2 grid of 160x160 cells")
	_expect(_texture_size(textures, "viper_player_throw_sheet") == Vector2(640.0, 320.0), "viper throw sheet should be 4x2 grid of 160x160 cells")
	_expect(_texture_size(textures, "viper_player_hover_left_sheet") == Vector2(640.0, 320.0), "viper hover left sheet should be 4x2 grid of 160x160 cells")
	_expect(_texture_size(textures, "viper_player_hover_right_sheet") == Vector2(640.0, 320.0), "viper hover right sheet should be 4x2 grid of 160x160 cells")
	_expect(_texture_size(textures, "viper_player_up_kick_left_sheet") == Vector2(640.0, 320.0), "viper up-kick left sheet should be 4x2 grid of 160x160 cells")
	_expect(_texture_size(textures, "viper_player_up_kick_right_sheet") == Vector2(640.0, 320.0), "viper up-kick right sheet should be 4x2 grid of 160x160 cells")
	_expect(_texture_size(textures, "viper_player_stun_sheet") == Vector2(640.0, 320.0), "viper stun sheet should be 4x2 grid of 160x160 cells")
	_expect(_texture_size(textures, "viper_player_confusion_sheet") == Vector2(640.0, 320.0), "viper confusion sheet should be 4x2 grid of 160x160 cells")
	_expect(_texture_size(textures, "viper_player_venom_edge_dash_sheet") == Vector2(640.0, 320.0), "viper venom edge dash sheet should be 4x2 grid of 160x160 cells")
	_expect(_texture_size(textures, "viper_player_venom_edge_strike_sheet") == Vector2(640.0, 320.0), "viper venom edge strike sheet should be 4x2 grid of 160x160 cells")
	_expect(_texture_size(textures, "viper_player_hit_left_strip_texture") == Vector2(1000.0, 120.0), "viper hit strips should be 4x 250x120")

	var viper_result_resources: Object = BattleResources.new()
	var viper_result_textures: Dictionary = viper_result_resources.load_all({
		"selected_character_type": "viper",
		"include_result_sheets": true,
	})
	_expect(_has_texture(viper_result_textures, "player_victory_sheet"), "viper round-victory sheet should load through the selected-character result path")
	_expect(_texture_size(viper_result_textures, "player_victory_sheet") == Vector2(1280.0, 1280.0), "viper round-victory sheet should be an 8x8 64-frame 160px-cell sheet")
	_expect(_has_texture(viper_result_textures, "player_defeat_sheet"), "viper round-defeat sheet should load through the selected-character result path")
	_expect(_texture_size(viper_result_textures, "player_defeat_sheet") == Vector2(1280.0, 1280.0), "viper round-defeat sheet should be an 8x8 64-frame 160px-cell sheet")

	var owner := FakeOwner.new({
		"battle_textures": textures,
		"selected_character_type": "viper",
		"current_stage": 1,
		"ai_mode": "champion",
		"ball_pos": Vector2(300.0, 300.0),
		"ball_vel": Vector2(0.0, 0.0),
		"ball_active": true,
		"player_speed": 3.0,
		"player_pos": Vector2(302.5, 700.0),
		"player_paddle_width": 155.0,
		"player_paddle_height": 50.0,
		"boss_pos": Vector2(330.0, 25.0),
	})
	var registry := FakeRegistry.new()

	var update_context: Dictionary = BattleUpdateEffectsContext.new().build_context(owner, registry)
	_expect(str(update_context.get("selected_character_type", "")) == "viper", "update context should stay on viper")
	_expect(bool(update_context.get("player_has_sprite", false)), "viper should advertise a runtime sprite")
	_expect(bool(update_context.get("player_has_idle_sprite", false)), "viper should advertise an idle sprite")
	_expect(bool(update_context.get("player_has_attack_sheet", false)), "viper should advertise its own subculture attack sheets")
	_expect(int(update_context.get("player_hit_frame_count", 0)) == 8, "viper kick attack should advertise 8 frames (4x2 grid)")
	_expect(int(update_context.get("player_sprite_frame_count", 0)) == 8, "viper walk should animate over 8 frames")

	var owner_snapshot: Dictionary = BallUpdateOwnerSnapshot.new().build(owner)
	_expect(bool(owner_snapshot.get("player_has_hit_sprite", false)), "viper hit strips should enable hit animation triggers")

	var actor_context: Dictionary = BattleDrawActorContext.new().build(
		{
			"textures": textures,
			"selected_character_type": "viper",
			"player_speed": 3.0,
			"player_pos": Vector2(302.5, 700.0),
			"player_paddle_size": Vector2(155.0, 50.0),
		},
		{"animation_state": FakeAnimationState.new()}
	)
	_expect(actor_context.get("player_sprite_texture", null) is Texture2D, "viper draw context should use the viper walk texture")
	_expect(actor_context.get("player_idle_sprite_texture", null) is Texture2D, "viper draw context should use the viper idle texture")
	_expect(actor_context.get("player_idle_sprite_texture", null) == textures.get("viper_player_idle_sheet", null), "viper draw context should prefer the new subculture idle sheet over the old strip")
	_expect(actor_context.get("player_walk_left_texture", null) == textures.get("viper_player_walk_left_sheet", null), "viper draw context should use the viper subculture left walk sheet")
	_expect(actor_context.get("player_walk_right_texture", null) == textures.get("viper_player_walk_right_sheet", null), "viper draw context should use the viper subculture right walk sheet")
	_expect(actor_context.get("player_attack_left_sheet", null) == textures.get("viper_player_attack_left_sheet", null), "viper draw context should use the viper subculture left attack sheet")
	_expect(actor_context.get("player_attack_right_sheet", null) == textures.get("viper_player_attack_right_sheet", null), "viper draw context should use the viper subculture right attack sheet")
	_expect(int(actor_context.get("player_directional_attack_grid_rows", 0)) == 2, "viper attack draw context should advertise 4x2 grid (rows=2)")
	_expect(actor_context.get("player_hit_left_strip_texture", null) is Texture2D, "viper draw context should use the viper left hit texture")
	_expect(actor_context.get("player_attack_sheet", null) == null, "viper draw context should not inherit smasher legacy attack texture")
	_expect(actor_context.get("viper_stun_sheet", null) == textures.get("viper_player_stun_sheet", null), "viper draw context should expose the stun sheet for renderer override")
	_expect(bool(actor_context.get("has_viper_stun_sheet", false)), "viper draw context should advertise stun sheet availability")
	_expect(actor_context.get("viper_confusion_sheet", null) == textures.get("viper_player_confusion_sheet", null), "viper draw context should expose the confusion sheet for renderer override")
	_expect(bool(actor_context.get("has_viper_confusion_sheet", false)), "viper draw context should advertise confusion sheet availability")
	_expect(actor_context.get("viper_venom_edge_strike_sheet", null) == textures.get("viper_player_venom_edge_strike_sheet", null), "viper draw context should expose the venom edge strike sheet for renderer override")
	_expect(bool(actor_context.get("has_viper_venom_edge_strike_sheet", false)), "viper draw context should advertise venom edge strike sheet availability")
	_expect(not bool(actor_context.get("viper_venom_edge_strike_active", false)), "viper venom edge strike should default to inactive when the skill has not been triggered")

	var result_actor_context: Dictionary = BattleDrawActorContext.new().build(
		{
			"textures": viper_result_textures,
			"selected_character_type": "viper",
			"current_stage": 1,
			"player_speed": 3.0,
			"player_pos": Vector2(302.5, 700.0),
			"player_paddle_size": Vector2(155.0, 50.0),
		},
		{
			"animation_state": FakeAnimationState.new(),
			"scoreboard_state": FakeScoreboardState.new(),
			"battle_resources": viper_result_resources,
		}
	)
	_expect(bool(result_actor_context.get("player_victory_active", false)), "viper player-victory result state should activate when the player scores")
	_expect(result_actor_context.get("player_victory_sheet", null) == viper_result_textures.get("player_victory_sheet", null), "viper result draw context should use the viper victory sheet")
	_expect(int(result_actor_context.get("player_victory_frame_count", 0)) == 64, "viper victory draw context should keep 64 frames")

	var defeat_actor_context: Dictionary = BattleDrawActorContext.new().build(
		{
			"textures": viper_result_textures,
			"selected_character_type": "viper",
			"current_stage": 1,
			"player_speed": 3.0,
			"player_pos": Vector2(302.5, 700.0),
			"player_paddle_size": Vector2(155.0, 50.0),
		},
		{
			"animation_state": FakeAnimationState.new(),
			"scoreboard_state": FakeScoreboardState.new("boss", 0.80),
			"battle_resources": viper_result_resources,
		}
	)
	_expect(bool(defeat_actor_context.get("player_defeat_active", false)), "viper player-defeat result state should activate when the boss scores")
	_expect(defeat_actor_context.get("player_defeat_sheet", null) == viper_result_textures.get("player_defeat_sheet", null), "viper result draw context should use the viper defeat sheet")
	_expect(int(defeat_actor_context.get("player_defeat_frame_count", 0)) == 64, "viper defeat draw context should keep 64 frames")
	_expect(int(defeat_actor_context.get("player_defeat_grid_cols", 0)) == 8, "viper defeat draw context should use the 8-column 64-frame sheet layout")

	print("viper_player_sprite_port_smoke: ok")
	quit(0)


func _has_texture(textures: Dictionary, key: String) -> bool:
	return textures.get(key, null) is Texture2D


func _texture_size(textures: Dictionary, key: String) -> Vector2:
	var texture: Variant = textures.get(key, null)
	if texture is Texture2D:
		return texture.get_size()
	return Vector2.ZERO


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
