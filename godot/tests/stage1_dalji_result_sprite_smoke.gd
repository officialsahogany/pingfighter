extends SceneTree

const BattleDrawActorContext := preload("res://scripts/core/battle_draw_actor_context.gd")
const BattleResources := preload("res://scripts/resources/battle_resources.gd")
const BattleUpdateEffectsContext := preload("res://scripts/core/battle_update_effects_context.gd")
const Stage1BossActorRenderer := preload("res://scripts/stages/stage1/stage1_boss_actor_renderer.gd")
const Stage1DaljiSpinningTopRenderer := preload("res://scripts/stages/stage1/stage1_dalji_spinning_top_renderer.gd")
const Stage1PlayerSpriteRenderer := preload("res://scripts/stages/stage1/stage1_player_sprite_renderer.gd")

const SMASHER_REAR_IDLE_PATH := "res://assets/sprites/smasher/hanmiryang_rear_cloud_idle_autosprite_v1_4x2_160_clean.png"
const SMASHER_REAR_MOVE_LEFT_PATH := "res://assets/sprites/smasher/hanmiryang_rear_cloud_glide_left_autosprite_v1_mirror_4x2_160_clean.png"
const SMASHER_REAR_MOVE_RIGHT_PATH := "res://assets/sprites/smasher/hanmiryang_rear_cloud_glide_right_autosprite_v1_4x2_160_clean.png"
const SMASHER_DASH_LEFT_PATH := "res://assets/sprites/smasher/hanmiryang_rear_cloud_dash_left_autosprite_v1_mirror_4x2_160_clean.png"
const SMASHER_DASH_RIGHT_PATH := "res://assets/sprites/smasher/hanmiryang_rear_cloud_dash_right_autosprite_v1_4x2_160_clean.png"
const SMASHER_ATTACK_LEFT_PATH := "res://assets/sprites/smasher/smasher_attack_left_sheet_16f.png"
const SMASHER_ATTACK_RIGHT_PATH := "res://assets/sprites/smasher/smasher_attack_right_sheet_16f.png"


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


class FakeScoreboardState:
	var player_points: int
	var boss_points: int
	var timer: float
	var active: bool
	var pending_game_reset: bool
	var last_scoring_side: String

	func _init(
		new_player_points: int,
		new_boss_points: int,
		new_timer: float,
		new_last_scoring_side: String,
		new_active: bool = true,
		new_pending_game_reset: bool = false
	) -> void:
		player_points = new_player_points
		boss_points = new_boss_points
		timer = new_timer
		last_scoring_side = new_last_scoring_side
		active = new_active
		pending_game_reset = new_pending_game_reset

	func is_active() -> bool:
		return active

	func has_pending_game_reset() -> bool:
		return pending_game_reset

	func get_last_scoring_side() -> String:
		return last_scoring_side

	func get_player_points() -> int:
		return player_points

	func get_boss_points() -> int:
		return boss_points

	func get_timer() -> float:
		return timer


class FakeAnimationState:
	var context: Dictionary = {}

	func _init(initial_context: Dictionary) -> void:
		context = initial_context.duplicate(true)

	func get_draw_context() -> Dictionary:
		return context.duplicate(true)


class FakeResultResources:
	var ensure_calls := 0
	var sync_calls := 0

	func ensure_result_textures(
		_character_type: String,
		_current_stage: int,
		_result_context: Dictionary
	) -> Dictionary:
		ensure_calls += 1
		return {}

	func sync_cached_result_textures(
		_character_type: String,
		_current_stage: int,
		_result_context: Dictionary
	) -> Dictionary:
		sync_calls += 1
		return {}


func _init() -> void:
	var resources: Object = BattleResources.new()
	var textures: Dictionary = resources.load_all({
		"current_stage": 1,
		"include_result_sheets": true,
		"include_all_stages": false,
		"include_all_characters": false,
		"selected_character_type": "smasher",
	})
	_expect(_has_texture(textures, "boss_victory_sheet"), "Dalji victory sheet should load")
	_expect(_has_texture(textures, "boss_defeat_sheet"), "Dalji defeat sheet should load")
	_expect(_has_texture(textures, "boss_walk_left_sheet"), "Dalji 16-frame left walk sheet should load")
	_expect(_has_texture(textures, "boss_walk_right_sheet"), "Dalji 16-frame right walk sheet should load")
	_expect(_has_texture(textures, "boss_paengi_top_whip_sheet"), "Dalji 32-frame paengi top-whip sheet should load")
	_expect(_has_texture(textures, "player_victory_sheet"), "Smasher round-victory sheet should load")
	_expect(_has_texture(textures, "player_defeat_sheet"), "Smasher round-defeat sheet should load")
	_expect(_has_texture(textures, "player_idle_back_sheet"), "Smasher idle-back sheet should load")
	_expect(_has_texture(textures, "player_walk_left_texture"), "Smasher left walk sheet should load")
	_expect(_has_texture(textures, "player_walk_right_texture"), "Smasher right walk sheet should load")
	_expect(_has_texture(textures, "player_dash_left_texture"), "Smasher left cloud dash sheet should load")
	_expect(_has_texture(textures, "player_dash_right_texture"), "Smasher right cloud dash sheet should load")
	_expect(_has_texture(textures, "player_attack_left_sheet"), "Smasher left-contact shield attack sheet should load")
	_expect(_has_texture(textures, "player_attack_right_sheet"), "Smasher right-contact racket attack sheet should load")
	_expect(_texture_size(textures, "boss_victory_sheet") == Vector2(1536.0, 1024.0), "Dalji victory sheet should keep the 4x2 static-sheet size")
	_expect(_texture_size(textures, "boss_defeat_sheet") == Vector2(1536.0, 1024.0), "Dalji defeat sheet should keep the 4x2 static-sheet size")
	_expect(_texture_size(textures, "boss_walk_left_sheet") == Vector2(1376.0, 1536.0), "Dalji left run should use the 4x4 16-frame runtime-sheet size")
	_expect(_texture_size(textures, "boss_walk_right_sheet") == Vector2(1376.0, 1536.0), "Dalji right run should use the 4x4 16-frame runtime-sheet size")
	_expect(_texture_size(textures, "boss_paengi_top_whip_sheet") == Vector2(4096.0, 2048.0), "Dalji paengi top-whip sheet should use the 8x4 32-frame runtime-sheet size")
	_expect(_texture_size(textures, "player_victory_sheet") == Vector2(1120.0, 1120.0), "Smasher victory sheet should keep the hanmiryang 7-column 49-frame result-sheet size")
	_expect(_texture_size(textures, "player_defeat_sheet") == Vector2(640.0, 640.0), "Smasher defeat sheet should keep the 4x4 result-sheet size")
	_expect(_texture_size(textures, "player_idle_back_sheet") == Vector2(640.0, 320.0), "Smasher idle should use the hanmiryang 4x2 8-frame runtime-sheet size")
	_expect(_texture_size(textures, "player_idle_sprite_texture") == Vector2(640.0, 320.0), "Smasher idle fallback should use the same hanmiryang sheet")
	_expect(_texture_size(textures, "player_walk_left_texture") == Vector2(640.0, 320.0), "Smasher left walk should keep the 4x2 8-frame runtime-sheet size")
	_expect(_texture_size(textures, "player_walk_right_texture") == Vector2(640.0, 320.0), "Smasher right walk should keep the 4x2 8-frame runtime-sheet size")
	_expect(_texture_size(textures, "player_dash_left_texture") == Vector2(640.0, 320.0), "Smasher left dash should keep the 4x2 8-frame runtime-sheet size")
	_expect(_texture_size(textures, "player_dash_right_texture") == Vector2(640.0, 320.0), "Smasher right dash should keep the 4x2 8-frame runtime-sheet size")
	_expect(_texture_size(textures, "player_attack_left_sheet") == Vector2(640.0, 640.0), "Smasher left-contact shield attack should use a 4x4 16-frame runtime sheet")
	_expect(_texture_size(textures, "player_attack_right_sheet") == Vector2(640.0, 640.0), "Smasher right-contact racket attack should use a 4x4 16-frame runtime sheet")
	var expected_smasher_idle: Texture2D = load(SMASHER_REAR_IDLE_PATH) as Texture2D
	var expected_smasher_left_walk: Texture2D = load(SMASHER_REAR_MOVE_LEFT_PATH) as Texture2D
	var expected_smasher_right_walk: Texture2D = load(SMASHER_REAR_MOVE_RIGHT_PATH) as Texture2D
	var expected_smasher_left_dash: Texture2D = load(SMASHER_DASH_LEFT_PATH) as Texture2D
	var expected_smasher_right_dash: Texture2D = load(SMASHER_DASH_RIGHT_PATH) as Texture2D
	var expected_smasher_left_attack: Texture2D = load(SMASHER_ATTACK_LEFT_PATH) as Texture2D
	var expected_smasher_right_attack: Texture2D = load(SMASHER_ATTACK_RIGHT_PATH) as Texture2D
	_expect(textures.get("player_idle_back_sheet", null) == expected_smasher_idle, "Smasher idle should load the hanmiryang rear-cloud idle sheet")
	_expect(textures.get("player_idle_sprite_texture", null) == expected_smasher_idle, "Smasher idle fallback should share the hanmiryang rear-cloud idle sheet")
	_expect(textures.get("player_walk_left_texture", null) == expected_smasher_left_walk, "Smasher left walk should load the hanmiryang rear-cloud glide sheet")
	_expect(textures.get("player_walk_right_texture", null) == expected_smasher_right_walk, "Smasher right walk should load the hanmiryang rear-cloud glide sheet")
	_expect(textures.get("player_dash_left_texture", null) == expected_smasher_left_dash, "Smasher left dash should load the hanmiryang cloud dash sheet")
	_expect(textures.get("player_dash_right_texture", null) == expected_smasher_right_dash, "Smasher right dash should load the hanmiryang cloud dash sheet")
	_expect(textures.get("player_attack_left_sheet", null) == expected_smasher_left_attack, "Smasher left contact should load the shield-smash attack sheet")
	_expect(textures.get("player_attack_right_sheet", null) == expected_smasher_right_attack, "Smasher right contact should load the racket-smash attack sheet")

	var update_context: Dictionary = BattleUpdateEffectsContext.new().build_context(
		FakeOwner.new({
			"battle_textures": textures,
			"selected_character_type": "smasher",
			"current_stage": 1,
			"player_speed": 3.0,
		}),
		FakeRegistry.new()
	)
	_expect(int(update_context.get("player_sprite_frame_count", 0)) == 8, "Smasher directional walk should animate over 8 frames")
	_expect(abs(float(update_context.get("player_sprite_animation_speed", 0.0)) - 0.050) < 0.0001, "Smasher directional walk should keep the 0.050s runtime cadence")
	_expect(bool(update_context.get("player_has_dash_sheet", false)), "Smasher should expose cloud dash sheets")
	_expect(int(update_context.get("player_dash_frame_count", 0)) == 8, "Smasher dash sheets should animate over 8 frames")
	_expect(int(update_context.get("player_idle_frame_count", 0)) == 8, "Smasher idle should animate over 8 frames")
	_expect(abs(float(update_context.get("player_idle_animation_speed", 0.0)) - 0.15) < 0.0001, "Smasher idle-back should keep the 0.15s runtime cadence")
	_expect(int(update_context.get("player_hit_frame_count", 0)) == 16, "Smasher attack sheets should animate over 16 frames")
	_expect(bool(update_context.get("player_hit_linear_frames", false)), "Smasher attack sheets should use authored linear frames")
	_expect(int(update_context.get("boss_sprite_frame_count", 0)) == 16, "Dalji run should animate over 16 frames")
	_expect(abs(float(update_context.get("boss_sprite_animation_speed", 0.0)) - 0.050) < 0.0001, "Dalji run should keep the old loop duration with 16 frames")

	var context_builder: Object = BattleDrawActorContext.new()
	var player_sprite_renderer: Object = Stage1PlayerSpriteRenderer.new()
	var left_hit_context: Dictionary = context_builder.build(
		{"textures": textures, "selected_character_type": "smasher"},
		{"animation_state": FakeAnimationState.new({"player_hit_active": true, "player_hit_side": -1})}
	)
	var right_hit_context: Dictionary = context_builder.build(
		{"textures": textures, "selected_character_type": "smasher"},
		{"animation_state": FakeAnimationState.new({"player_hit_active": true, "player_hit_side": 1})}
	)
	_expect(int(left_hit_context.get("player_hit_frame_count", 0)) == 16, "left-contact draw context should expose 16 Smasher hit frames")
	_expect(int(left_hit_context.get("player_directional_attack_grid_rows", 0)) == 4, "Smasher directional attack grid should stay 4x4")
	_expect(player_sprite_renderer.call("_get_player_directional_attack_texture", left_hit_context) == expected_smasher_left_attack, "left-of-center ball contact should select the shield-smash sheet")
	_expect(player_sprite_renderer.call("_get_player_directional_attack_texture", right_hit_context) == expected_smasher_right_attack, "right-of-center ball contact should select the racket-smash sheet")
	var left_dash_context: Dictionary = context_builder.build(
		{
			"textures": textures,
			"selected_character_type": "smasher",
			"player_speed": -3.0,
			"dash_snapshot": {"active": true, "direction": -1.0, "elapsed_frames": 11.0, "timer": 4.0},
		},
		{}
	)
	var right_dash_context: Dictionary = context_builder.build(
		{
			"textures": textures,
			"selected_character_type": "smasher",
			"player_speed": 3.0,
			"dash_snapshot": {"active": true, "direction": 1.0},
		},
		{}
	)
	_expect(bool(left_dash_context.get("has_player_directional_dash_sheet", false)), "left dash draw context should expose Smasher dash sheets")
	_expect(int(left_dash_context.get("player_directional_dash_frame_count", 0)) == 8, "Smasher dash draw context should expose 8 frames")
	_expect(int(left_dash_context.get("player_directional_dash_grid_cols", 0)) == 4, "Smasher dash draw context should expose the 4-column grid")
	_expect(left_dash_context.get("player_dash_left_texture", null) == expected_smasher_left_dash, "draw context should expose Smasher left dash sheet")
	_expect(right_dash_context.get("player_dash_right_texture", null) == expected_smasher_right_dash, "draw context should expose Smasher right dash sheet")
	_expect(player_sprite_renderer.call("_get_player_directional_dash_texture", left_dash_context) == expected_smasher_left_dash, "left dash should select the mirrored cloud dash sheet")
	_expect(player_sprite_renderer.call("_get_player_directional_dash_texture", right_dash_context) == expected_smasher_right_dash, "right dash should select the authored cloud dash sheet")
	_expect(int(left_dash_context.get("dash_elapsed_frames", 0.0)) == 11, "Smasher dash context should expose elapsed frames for pose hold timing")
	var late_dash_region: Rect2 = player_sprite_renderer.call("_get_player_directional_dash_region", left_dash_context)
	_expect(late_dash_region.position == Vector2(160.0, 160.0), "late Smasher dash should hold on 1-based frame #6")
	var defeat_context: Dictionary = context_builder.build(
		{"textures": textures},
		{"scoreboard_state": FakeScoreboardState.new(2, 2, 2.0, "player")}
	)
	_expect(bool(defeat_context.get("boss_defeat_active", false)), "player round win should activate Dalji defeat even on a tied score")
	_expect(not bool(defeat_context.get("boss_victory_active", false)), "player round win should not activate Dalji victory")
	_expect(bool(defeat_context.get("player_victory_active", false)), "player round win should activate Smasher victory on non-final rounds")
	_expect(not bool(defeat_context.get("player_defeat_active", false)), "player round win should not activate Smasher defeat")
	_expect(int(defeat_context.get("boss_result_frame", -1)) == 7, "result animation should hold on the final frame")
	_expect(int(defeat_context.get("player_victory_frame", -1)) == 48, "Smasher 49-frame victory should hold on its final frame")
	_expect(int(defeat_context.get("player_victory_grid_cols", -1)) == 7, "Smasher victory should use the hanmiryang 7-column grid")
	_expect(int(defeat_context.get("player_idle_frame_count", -1)) == 8, "Smasher idle draw context should expose 8 frames")
	_expect(int(defeat_context.get("player_idle_grid_cols", -1)) == 4, "Smasher idle-back draw context should expose the 4-column grid")
	_expect(int(defeat_context.get("player_idle_grid_rows", -1)) == 2, "Smasher idle draw context should expose the 2-row grid")
	_expect(int(defeat_context.get("player_directional_walk_frame_count", -1)) == 8, "Smasher directional walk draw context should expose 8 frames")
	_expect(int(defeat_context.get("player_directional_walk_grid_cols", -1)) == 4, "Smasher directional walk draw context should expose the 4-column grid")
	_expect(int(defeat_context.get("boss_walk_frame_count", -1)) == 16, "Dalji run draw context should expose 16 frames")
	_expect(int(defeat_context.get("boss_walk_grid_cols", -1)) == 4, "Dalji run draw context should expose the 4-column grid")

	var deferred_result_textures: Dictionary = textures.duplicate()
	deferred_result_textures.erase("boss_defeat_sheet")
	deferred_result_textures.erase("boss_victory_sheet")
	deferred_result_textures.erase("player_victory_sheet")
	deferred_result_textures.erase("player_defeat_sheet")
	var fake_result_resources := FakeResultResources.new()
	var deferred_context: Dictionary = context_builder.build(
		{"textures": deferred_result_textures},
		{
			"scoreboard_state": FakeScoreboardState.new(2, 2, 0.2, "player"),
			"battle_resources": fake_result_resources,
		}
	)
	_expect(fake_result_resources.ensure_calls == 0, "result draw context should not synchronously ensure missing result textures")
	_expect(fake_result_resources.sync_calls == 1, "result draw context may only sync already-cached result textures")
	_expect(deferred_context.get("boss_defeat_sheet", null) == null, "missing deferred boss result sheet should remain unloaded in draw")
	_expect(deferred_context.get("player_victory_sheet", null) == null, "missing deferred player result sheet should remain unloaded in draw")

	var victory_context: Dictionary = context_builder.build(
		{"textures": textures},
		{"scoreboard_state": FakeScoreboardState.new(4, 3, 0.55, "boss")}
	)
	_expect(bool(victory_context.get("boss_victory_active", false)), "boss round win should activate Dalji victory even while behind overall")
	_expect(not bool(victory_context.get("boss_defeat_active", false)), "boss round win should not activate Dalji defeat")
	_expect(bool(victory_context.get("player_defeat_active", false)), "boss round win should activate Smasher defeat on non-final rounds")
	_expect(not bool(victory_context.get("player_victory_active", false)), "boss round win should not activate Smasher victory")
	_expect(int(victory_context.get("boss_result_frame", -1)) == 3, "result animation should advance at Python's 0.18s cadence")
	_expect(int(victory_context.get("player_defeat_frame", -1)) == 6, "Smasher defeat should keep its 0.09s-per-frame cadence")

	var renderer: Object = Stage1BossActorRenderer.new()
	var selected_defeat: Dictionary = renderer._select_sheet(defeat_context)
	_expect(selected_defeat.get("texture", null) == textures.get("boss_defeat_sheet", null), "renderer should pick defeat before normal states")
	_expect(float(selected_defeat.get("cell_width", 0.0)) == 384.0, "defeat should use static Dalji cell width")

	var priority_context: Dictionary = victory_context.duplicate(true)
	priority_context["boss_defeat_active"] = true
	var selected_priority: Dictionary = renderer._select_sheet(priority_context)
	_expect(selected_priority.get("texture", null) == textures.get("boss_defeat_sheet", null), "defeat should outrank victory if both flags exist")

	var walk_context: Dictionary = defeat_context.duplicate(true)
	walk_context["boss_defeat_active"] = false
	walk_context["boss_victory_active"] = false
	walk_context["boss_is_walking"] = true
	walk_context["boss_facing"] = -1
	walk_context["boss_sprite_frame"] = 15
	var selected_walk: Dictionary = renderer._select_sheet(walk_context)
	_expect(selected_walk.get("texture", null) == textures.get("boss_walk_left_sheet", null), "renderer should pick Dalji left walk while moving left")
	_expect(int(selected_walk.get("frame_count", 0)) == 16, "Dalji run renderer selection should keep all 16 frames")
	_expect(int(selected_walk.get("grid_cols", 0)) == 4, "Dalji run renderer selection should use the 4-column grid")
	var final_walk_region: Rect2 = renderer._get_cell_region(
		15,
		float(selected_walk.get("cell_width", 0.0)),
		float(selected_walk.get("cell_height", 0.0)),
		int(selected_walk.get("grid_cols", 0)),
		int(selected_walk.get("frame_count", 0))
	)
	_expect(final_walk_region == Rect2(1032.0, 1152.0, 344.0, 384.0), "Dalji frame 15 should slice from the last 4x4 cell")

	var paengi_context: Dictionary = defeat_context.duplicate(true)
	paengi_context["boss_defeat_active"] = false
	paengi_context["boss_victory_active"] = false
	paengi_context["boss_paengi_top_whip_active"] = true
	paengi_context["boss_paengi_top_whip_frame"] = 31
	var selected_paengi: Dictionary = renderer._select_sheet(paengi_context)
	_expect(selected_paengi.get("texture", null) == textures.get("boss_paengi_top_whip_sheet", null), "renderer should pick Dalji 32-frame paengi sheet during spinning-top cast")
	_expect(int(selected_paengi.get("frame_count", 0)) == 32, "Dalji paengi renderer selection should expose all 32 frames")
	_expect(int(selected_paengi.get("grid_cols", 0)) == 8, "Dalji paengi renderer selection should use the 8-column grid")
	var final_paengi_region: Rect2 = renderer._get_cell_region(
		31,
		float(selected_paengi.get("cell_width", 0.0)),
		float(selected_paengi.get("cell_height", 0.0)),
		int(selected_paengi.get("grid_cols", 0)),
		int(selected_paengi.get("frame_count", 0))
	)
	_expect(final_paengi_region == Rect2(3584.0, 1536.0, 512.0, 512.0), "Dalji paengi frame 31 should slice from the last 8x4 cell")

	var spinning_top_renderer: Object = Stage1DaljiSpinningTopRenderer.new()
	var paengi_anchor_context: Dictionary = paengi_context.duplicate(true)
	paengi_anchor_context["boss_pos"] = Vector2(200.0, 100.0)
	paengi_anchor_context["boss_paddle_size"] = Vector2(110.0, 18.0)
	paengi_anchor_context["boss_hitbox_height"] = 18.0
	paengi_anchor_context["boss_sprite_draw_size"] = Vector2(96.0, 112.0)
	paengi_anchor_context["boss_visual_center_y_offset"] = 25.0
	# v2 paengi sheet: frame 0 = windup (switch raised up-left), frame 26 =
	# recovery (switch lowered forward down-right). The whip line must anchor to
	# the per-frame stick tip through the visual rect, not the boss hitbox center.
	paengi_anchor_context["boss_paengi_top_whip_frame"] = 0
	var tip0: Vector2 = spinning_top_renderer._get_whip_start(paengi_anchor_context, Vector2.ZERO)
	paengi_anchor_context["boss_paengi_top_whip_frame"] = 26
	var tip26: Vector2 = spinning_top_renderer._get_whip_start(paengi_anchor_context, Vector2.ZERO)
	var boss_center_start := Vector2(255.0, 109.0)
	# PAENGI_STICK_TIP_SOURCE_POINTS[26] = (350, 348) in 512 px source-cell coords.
	var expected_tip26 := Vector2(
		207.0 + 350.0 / 512.0 * 96.0,
		78.0 + 348.0 / 512.0 * 112.0
	)
	_expect(tip0.distance_to(tip26) > 30.0, "paengi whip line stick tip should be frame-specific (windup vs recovery differ)")
	_expect(tip26.distance_to(boss_center_start) > 40.0, "paengi whip line should not collapse to the boss hitbox center")
	_expect(tip26.distance_to(expected_tip26) < 0.01, "paengi whip line should map the frame-specific stick tip through the visual rect")

	if _failed:
		# A failed _expect already pushed the error and requested quit(1);
		# without this gate the unconditional ok + quit(0) below would
		# override the exit code and print a vacuous GREEN.
		quit(1)
		return
	print("stage1_dalji_result_sprite_smoke: ok")
	quit(0)


func _has_texture(textures: Dictionary, key: String) -> bool:
	return textures.get(key, null) is Texture2D


func _texture_size(textures: Dictionary, key: String) -> Vector2:
	var texture: Variant = textures.get(key, null)
	if texture is Texture2D:
		return texture.get_size()
	return Vector2.ZERO


var _failed := false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
	quit(1)
