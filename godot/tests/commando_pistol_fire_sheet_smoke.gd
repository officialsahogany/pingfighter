extends SceneTree

const BattleDrawActorContext := preload("res://scripts/core/battle_draw_actor_context.gd")
const BattleResources := preload("res://scripts/resources/battle_resources.gd")
const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")

const PISTOL_FIRE_SHEET_PATH := "res://assets/sprites/characters/commando/commando_subculture_pistol_fire_sheet.png"

var _failures: Array[String] = []


func _init() -> void:
	_verify_sheet_loads_for_soldier()
	_verify_runtime_pistol_state_keys()
	_verify_actor_context_windup_phase()
	_verify_actor_context_post_shot_phase()
	_verify_actor_context_inactive_when_idle()
	_verify_pistol_fire_dest_size_matches_walk_idle_body()
	_verify_pistol_fire_flip_follows_movement_direction()

	if _failures.is_empty():
		print("commando_pistol_fire_sheet_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_sheet_loads_for_soldier() -> void:
	var resources := BattleResources.new()
	var textures: Dictionary = resources.load_all({
		"selected_character_type": "soldier",
		"current_stage": 1,
		"include_all_characters": false,
		"include_all_stages": false,
		"include_result_sheets": false,
	})
	_expect(
		textures.get("commando_player_pistol_fire_sheet", null) is Texture2D,
		"Commando pistol-fire sheet should load when soldier is selected"
	)
	var sheet: Texture2D = textures.get("commando_player_pistol_fire_sheet", null)
	if sheet != null:
		var size: Vector2 = sheet.get_size()
		_expect(size.x >= 4.0, "Pistol-fire sheet width should accommodate 4 columns")
		_expect(size.y >= 2.0, "Pistol-fire sheet height should accommodate 2 rows")


func _verify_runtime_pistol_state_keys() -> void:
	var runtime: Object = CommandoFirearmRuntime.new()
	var ctx: Dictionary = runtime.get_actor_draw_context()
	var pistol_state: Dictionary = ctx.get("commando_firearm_pistol_state", {})
	_expect(pistol_state.has("fire_delay_frames"), "Pistol state should expose fire_delay_frames")
	_expect(pistol_state.has("post_fire_animation_frames"), "Pistol state should expose post_fire_animation_frames (new key)")
	_expect(pistol_state.has("post_fire_animation_max_frames"), "Pistol state should expose post_fire_animation_max_frames (new key)")
	_expect(pistol_state.has("animation_active"), "Pistol state should expose animation_active (new key)")
	_expect(float(pistol_state.get("fire_delay_frames", -1.0)) == 0.0, "fire_delay_frames should default to 0")
	_expect(float(pistol_state.get("post_fire_animation_frames", -1.0)) == 0.0, "post_fire_animation_frames should default to 0")
	_expect(not bool(pistol_state.get("animation_active", true)), "animation_active should default to false")


func _verify_actor_context_windup_phase() -> void:
	# Mid-windup: fire_delay_frames = 12 (half of 24), post-shot = 0.
	# Progress = 1 - 12/24 = 0.5, frame_index = clamp(int(0.5 * 4), 0, 3) = 2.
	var actor_context: Dictionary = _build_actor_context_with_pistol_state({
		"fire_delay_frames": 12.0,
		"fire_delay_max_frames": 24.0,
		"post_fire_animation_frames": 0.0,
		"post_fire_animation_max_frames": 18.0,
	})
	_expect(bool(actor_context.get("commando_pistol_fire_active", false)), "Windup phase should mark fire animation active")
	var frame: int = int(actor_context.get("commando_pistol_fire_frame", -1))
	_expect(frame == 2, "Mid-windup should select sheet frame 2 (mid raise), got %d" % frame)


func _verify_actor_context_post_shot_phase() -> void:
	# Just-fired: fire_delay = 0, post_fire = full window (18). Progress = 0.0,
	# frame = 4 (muzzle flash) — exactly when gunshot.wav fires.
	var actor_context_just_fired: Dictionary = _build_actor_context_with_pistol_state({
		"fire_delay_frames": 0.0,
		"fire_delay_max_frames": 24.0,
		"post_fire_animation_frames": 18.0,
		"post_fire_animation_max_frames": 18.0,
	})
	_expect(bool(actor_context_just_fired.get("commando_pistol_fire_active", false)), "Post-shot phase should mark fire animation active")
	var first_post_frame: int = int(actor_context_just_fired.get("commando_pistol_fire_frame", -1))
	_expect(first_post_frame == 4, "Frame 4 (muzzle flash) must align with gunshot.wav, got %d" % first_post_frame)

	# Mid post-shot: post_fire = 9 (half of 18). Progress = 1 - 9/18 = 0.5,
	# frame_index = clamp(4 + int(0.5 * 4), 4, 7) = 6 (lowering).
	var actor_context_mid_post: Dictionary = _build_actor_context_with_pistol_state({
		"fire_delay_frames": 0.0,
		"fire_delay_max_frames": 24.0,
		"post_fire_animation_frames": 9.0,
		"post_fire_animation_max_frames": 18.0,
	})
	var mid_post_frame: int = int(actor_context_mid_post.get("commando_pistol_fire_frame", -1))
	_expect(mid_post_frame == 6, "Mid post-shot should select frame 6 (lowering), got %d" % mid_post_frame)


func _verify_actor_context_inactive_when_idle() -> void:
	var actor_context: Dictionary = _build_actor_context_with_pistol_state({
		"fire_delay_frames": 0.0,
		"fire_delay_max_frames": 24.0,
		"post_fire_animation_frames": 0.0,
		"post_fire_animation_max_frames": 18.0,
	})
	_expect(
		not bool(actor_context.get("commando_pistol_fire_active", true)),
		"Pistol fire should NOT be active when both fire_delay and post_fire timers are zero"
	)


# Regression guard for the size + identity drift cycle:
# v1 (96x128 dest x 134x96 body): "권총발사 시트가 기존 시트보다 사이즈가 2배정도 커짐"
# v2 (96x128 dest x 250x412 body): identity drift — beret was wrong color, no backpack
# v3 (80x107 dest x 266x395 body in 316x424 cell): backpack restored, custom dest size
# v4 (160x160 dest x 100 body in 160x160 cell): standardized to match idle/walk dimensions —
#     no rifle, entrenching tool added, body pre-fit to 100 px / feet at y=153 in source.
# The v4 contract is now: standard 640x320 sheet / cell 160x160 / dest 160x160 (same as idle/walk).
func _verify_pistol_fire_dest_size_matches_walk_idle_body() -> void:
	var actor_context: Dictionary = _build_actor_context_with_pistol_state({
		"fire_delay_frames": 12.0,
		"fire_delay_max_frames": 24.0,
		"post_fire_animation_frames": 0.0,
		"post_fire_animation_max_frames": 18.0,
	})
	var dest_size: Vector2 = actor_context.get("player_pistol_fire_draw_size", Vector2.ZERO)
	_expect(dest_size.x == 160.0, "Pistol-fire dest width must be 160 (idle/walk-matched standard), got %f" % dest_size.x)
	_expect(dest_size.y == 160.0, "Pistol-fire dest height must be 160 (idle/walk-matched standard), got %f" % dest_size.y)


func _verify_pistol_fire_flip_follows_movement_direction() -> void:
	var pistol_state := {
		"fire_delay_frames": 12.0,
		"fire_delay_max_frames": 24.0,
		"post_fire_animation_frames": 0.0,
		"post_fire_animation_max_frames": 18.0,
	}
	var left_context: Dictionary = _build_actor_context_with_pistol_state(pistol_state, -3.0)
	_expect(
		bool(left_context.get("commando_pistol_fire_flip_h", false)),
		"Commando pistol-fire sheet must flip while firing during left movement"
	)
	var right_context: Dictionary = _build_actor_context_with_pistol_state(pistol_state, 3.0)
	_expect(
		not bool(right_context.get("commando_pistol_fire_flip_h", true)),
		"Commando pistol-fire sheet must stay unflipped while firing during right movement"
	)


func _build_actor_context_with_pistol_state(pistol_state: Dictionary, player_speed: float = 0.0) -> Dictionary:
	var resources := BattleResources.new()
	var textures: Dictionary = resources.load_all({
		"selected_character_type": "soldier",
		"current_stage": 1,
		"include_all_characters": false,
		"include_all_stages": false,
		"include_result_sheets": false,
	})
	var fake_runtime := FakeCommandoFirearmRuntime.new(pistol_state)
	var draw_builder := BattleDrawActorContext.new()
	return draw_builder.build({
		"selected_character_type": "soldier",
		"textures": textures,
		"player_speed": player_speed,
	}, {
		"commando_firearm_runtime": fake_runtime,
	})


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


# Minimal stand-in that returns a controllable pistol_state without spinning up
# the real CommandoFirearmRuntime fire pipeline.
class FakeCommandoFirearmRuntime extends RefCounted:
	var _pistol_state: Dictionary

	func _init(pistol_state: Dictionary) -> void:
		_pistol_state = pistol_state.duplicate(true)

	func get_actor_draw_context() -> Dictionary:
		return {
			"commando_firearm_projectiles": [],
			"commando_firearm_muzzle_flashes": [],
			"commando_firearm_impact_flashes": [],
			"commando_firearm_lingering_effects": [],
			"commando_firearm_shell_casings": [],
			"commando_firearm_pistol_feedbacks": [],
			"commando_firearm_pistol_state": _pistol_state,
			"commando_firearm_slingshot_state": {},
			"commando_firearm_ak47_state": {},
			"commando_firearm_bazooka_state": {},
			"commando_firearm_net_gun_state": {},
			"commando_firearm_bowling_trap_state": {},
			"commando_firearm_suicide_drone_state": {},
			"commando_firearm_support_calls": [],
			"commando_firearm_bowling_traps": [],
		}
