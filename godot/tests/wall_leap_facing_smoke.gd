extends SceneTree

const Support := preload("res://tests/wall_leap_test_support.gd")
const Stage1PlayerSpriteRenderer := preload("res://scripts/stages/stage1/stage1_player_sprite_renderer.gd")

const WALK_LEFT_PATH := "res://assets/sprites/characters/viper/viper_subculture_left_walk_sheet.png"
const WALK_RIGHT_PATH := "res://assets/sprites/characters/viper/viper_subculture_right_walk_sheet.png"
const ATTACK_LEFT_PATH := "res://assets/sprites/characters/viper/viper_subculture_left_attack_sheet.png"
const ATTACK_RIGHT_PATH := "res://assets/sprites/characters/viper/viper_subculture_right_attack_sheet.png"
const BLADE_TRAIL_PATH := "res://assets/sprites/characters/viper/air_blade/viper_air_blade_trail_imagegen_v1.png"
const BLADE_BURST_PATH := "res://assets/sprites/characters/viper/air_blade/viper_air_blade_slash_burst_imagegen_v1.png"

var _support := Support.new()
var _renderer := Stage1PlayerSpriteRenderer.new()
var _failures: Array[String] = []
var _walk_left: Texture2D
var _walk_right: Texture2D
var _attack_left: Texture2D
var _attack_right: Texture2D


func _init() -> void:
	_load_actor_sheets()
	_verify_runtime_prewarm_contract()
	_verify_walk_direction_and_idle_latch()
	_verify_slash_sheet_and_blade_direction(-1)
	_verify_slash_sheet_and_blade_direction(1)
	_finish()


func _load_actor_sheets() -> void:
	_walk_left = load(WALK_LEFT_PATH) as Texture2D
	_walk_right = load(WALK_RIGHT_PATH) as Texture2D
	_attack_left = load(ATTACK_LEFT_PATH) as Texture2D
	_attack_right = load(ATTACK_RIGHT_PATH) as Texture2D
	_expect(_walk_left != null and _walk_right != null, "both authored Viper walk sheets must load")
	_expect(_attack_left != null and _attack_right != null, "both authored Viper sword-swing sheets must load")


func _verify_runtime_prewarm_contract() -> void:
	var fixture: Dictionary = _support.make_fixture()
	fixture["runtime"].prewarm_assets()
	for path in [ATTACK_LEFT_PATH, ATTACK_RIGHT_PATH, BLADE_TRAIL_PATH, BLADE_BURST_PATH]:
		_expect(ResourceLoader.has_cached(path), "runtime prewarm must cache %s before first visible use" % path)


func _verify_walk_direction_and_idle_latch() -> void:
	var fixture: Dictionary = _support.make_fixture()
	_support.enter(fixture)
	_support.advance_to_infiltrating(fixture)

	_support.route_once(fixture, {"direction": -1.0})
	var left_context: Dictionary = fixture["runtime"].get_actor_draw_context()
	_expect(int(left_context.get("player_walk_direction", 0)) == -1, "left infiltration input must select the authored left-facing walk sheet")
	_expect(float(left_context.get("player_speed", 0.0)) < -0.2, "left infiltration input must advertise active leftward actor motion")
	var left_resolved := _resolve(left_context, true)
	_expect(left_resolved.get("texture", null) == _walk_left, "the production Stage1 sprite router must resolve the left walk sheet")
	_expect(not bool(left_resolved.get("flip_h", true)), "left movement must use its authored sheet without mirroring")

	_support.route_once(fixture, {})
	var idle_latch: Dictionary = fixture["runtime"].get_actor_draw_context()
	_expect(int(idle_latch.get("player_walk_direction", 0)) == -1, "no-input infiltration must retain the last facing latch")
	_expect(is_zero_approx(float(idle_latch.get("player_speed", 1.0))), "no-input infiltration must stop walk animation while preserving facing")

	_support.route_once(fixture, {"direction": 1.0})
	var right_context: Dictionary = fixture["runtime"].get_actor_draw_context()
	_expect(int(right_context.get("player_walk_direction", 0)) == 1, "right infiltration input must select the authored right-facing walk sheet")
	_expect(float(right_context.get("player_speed", 0.0)) > 0.2, "right infiltration input must advertise active rightward actor motion")
	var right_resolved := _resolve(right_context, true)
	_expect(right_resolved.get("texture", null) == _walk_right, "the production Stage1 sprite router must resolve the right walk sheet")
	_expect(not bool(right_resolved.get("flip_h", true)), "right movement must use its authored sheet without mirroring")


func _verify_slash_sheet_and_blade_direction(direction: int) -> void:
	var fixture: Dictionary = _support.make_fixture()
	_support.enter(fixture)
	_support.advance_to_infiltrating(fixture)
	_support.route_once(fixture, {"direction": float(direction)})
	_support.route_once(fixture, {})
	_support.route_once(fixture, {"mouse_left_pressed": true, "mouse_left_just_pressed": true})

	var windup_context: Dictionary = fixture["runtime"].get_actor_draw_context()
	_expect(bool(windup_context.get("player_hit_active", false)), "SLASH must expose the shared directional attack-sheet route")
	_expect(int(windup_context.get("player_hit_side", 0)) == direction, "sword swing side must equal the latched movement facing")
	var windup_resolved := _resolve(windup_context, false)
	var expected_attack: Texture2D = _attack_left if direction < 0 else _attack_right
	_expect(windup_resolved.get("texture", null) == expected_attack, "Stage1 sprite router must resolve the matching authored sword-swing sheet")
	_expect(not bool(windup_resolved.get("flip_h", true)), "sword swing must not mirror the opposite attack sheet")

	_support.advance_frames(fixture, 6)
	var impact_context: Dictionary = fixture["runtime"].get_actor_draw_context()
	var impact_snapshot: Dictionary = fixture["runtime"].get_snapshot()
	var impact_resolved := _resolve(impact_context, false)
	_expect(int(impact_context.get("player_hit_frame", -1)) == 3, "impact must occur on authored sword-swing frame 3")
	_expect(impact_resolved.get("texture", null) == expected_attack, "impact frame must remain on the matching directional attack sheet")
	_expect((impact_resolved.get("region", Rect2()) as Rect2).position == Vector2(480.0, 0.0), "frame 3 must slice cell 3 of the 4x2 160px sheet")
	_expect(str(impact_snapshot.get("wall_leap_raid_state", "")) == "blade_flight", "impact frame must hand off to BLADE_FLIGHT")
	_expect(int(impact_snapshot.get("wall_leap_raid_blade_direction", 0)) == direction, "blade direction must equal the sword-sheet direction")
	var blade_pos: Vector2 = impact_snapshot.get("wall_leap_raid_blade_pos", Vector2.ZERO)
	var blade_origin_x := float(impact_snapshot.get("wall_leap_raid_blade_origin_player_center_x", 0.0))
	_expect(signf(blade_pos.x - blade_origin_x) == float(direction), "blade must spawn on the forward side of the latched swing")
	_expect(is_equal_approx(float(impact_context.get("viper_wall_leap_raid_visual_y_offset", -1.0)), 93.0), "infiltration presentation must keep the 160px actor sheet inside the playfield")
	_expect(is_equal_approx(blade_pos.y, 127.0), "blade wave must leave from the authored frame-3 sword-hand lane")


func _resolve(runtime_context: Dictionary, move_active: bool) -> Dictionary:
	var context := {
		"selected_character_type": "viper",
		"player_walk_left_texture": _walk_left,
		"player_walk_right_texture": _walk_right,
		"player_attack_left_sheet": _attack_left,
		"player_attack_right_sheet": _attack_right,
		"player_directional_walk_cell_width": 160.0,
		"player_directional_walk_cell_height": 160.0,
		"player_directional_walk_grid_cols": 4,
		"player_directional_walk_frame_count": 8,
		"player_directional_attack_cell_width": 160.0,
		"player_directional_attack_cell_height": 160.0,
		"player_directional_attack_grid_cols": 4,
		"player_directional_attack_grid_rows": 2,
	}
	context.merge(runtime_context, true)
	return _renderer.resolve_current_sprite(
		context,
		Rect2(Vector2.ZERO, Vector2(160.0, 160.0)),
		move_active,
		Vector2.ZERO,
		Vector2(155.0, 50.0),
		Vector2.ZERO
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("wall_leap_facing_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
