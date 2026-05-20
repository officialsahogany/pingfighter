extends SceneTree

const BattleDrawActorContext := preload("res://scripts/core/battle_draw_actor_context.gd")
const BattleResources := preload("res://scripts/resources/battle_resources.gd")
const BattleUpdateEffectsSpriteContextBuilder := preload("res://scripts/core/battle_update_effects_sprite_context_builder.gd")
const Stage1PlayerActorRenderer := preload("res://scripts/stages/stage1/stage1_player_actor_renderer.gd")

const ATTACK_SHEET_PATH := "res://assets/sprites/characters/commando/commando_subculture_attack_sheet.png"

var _failures: Array[String] = []


func _init() -> void:
	_verify_sheet_loads_for_soldier()
	_verify_sheet_grid_matches_8_frame_4x2_layout()
	_verify_attack_draw_size_preserves_square_cell_for_commando()
	_verify_actor_context_active_on_hit()
	_verify_attack_flip_follows_ball_contact_side()
	_verify_actor_context_inactive_when_idle()
	_verify_actor_context_inactive_when_pistol_firing()
	_verify_actor_context_inactive_for_smasher()
	_verify_hit_frame_count_is_8_for_commando()
	_verify_effects_builder_advertises_8_frames_for_commando()

	if _failures.is_empty():
		print("commando_attack_sheet_smoke: ok")
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
		textures.get("commando_player_attack_sheet", null) is Texture2D,
		"Commando attack sheet should load when soldier is selected"
	)


func _verify_sheet_grid_matches_8_frame_4x2_layout() -> void:
	var sheet: Texture2D = load(ATTACK_SHEET_PATH)
	if sheet == null:
		_failures.append("Could not load attack sheet PNG")
		return
	var size: Vector2 = sheet.get_size()
	# 4x2 grid at cell 160x160 = 640x320
	_expect(int(size.x) == 640, "Attack sheet width should be 640 (4 cols * 160), got %d" % int(size.x))
	_expect(int(size.y) == 320, "Attack sheet height should be 320 (2 rows * 160), got %d" % int(size.y))


func _verify_attack_draw_size_preserves_square_cell_for_commando() -> void:
	var actor_context: Dictionary = _build_actor_context_with_hit_state(true, false, "soldier")
	var dest_size: Vector2 = actor_context.get("player_commando_attack_draw_size", Vector2.ZERO)
	_expect(dest_size.x == 160.0, "Commando attack dest width must be 160, got %f" % dest_size.x)
	_expect(dest_size.y == 160.0, "Commando attack dest height must be 160, got %f" % dest_size.y)

	var renderer := Stage1PlayerActorRenderer.new()
	var resolved_size: Vector2 = renderer.call("_get_player_hit_draw_size", actor_context, Vector2(250.0, 120.0))
	_expect(
		resolved_size == Vector2(160.0, 160.0),
		"Commando attack renderer must not squash the 160x160 source cell into the 250x120 fallback"
	)


func _verify_actor_context_active_on_hit() -> void:
	var actor_context: Dictionary = _build_actor_context_with_hit_state(true, false, "soldier")
	_expect(
		bool(actor_context.get("commando_attack_active", false)),
		"commando_attack_active must be true while soldier is mid-hit"
	)
	_expect(
		actor_context.get("commando_attack_sheet", null) is Texture2D,
		"commando_attack_sheet should be a Texture2D in the actor context"
	)


func _verify_attack_flip_follows_ball_contact_side() -> void:
	var left_context: Dictionary = _build_actor_context_with_hit_state(true, false, "soldier", -1)
	_expect(
		bool(left_context.get("commando_attack_flip_h", false)),
		"Commando attack sheet must flip horizontally when the ball hits left of paddle center"
	)
	var right_context: Dictionary = _build_actor_context_with_hit_state(true, false, "soldier", 1)
	_expect(
		not bool(right_context.get("commando_attack_flip_h", true)),
		"Commando attack sheet must stay unflipped when the ball hits right of paddle center"
	)


func _verify_actor_context_inactive_when_idle() -> void:
	var actor_context: Dictionary = _build_actor_context_with_hit_state(false, false, "soldier")
	_expect(
		not bool(actor_context.get("commando_attack_active", true)),
		"commando_attack_active must be false when player_hit_active is false"
	)


func _verify_actor_context_inactive_when_pistol_firing() -> void:
	# Commando attack must yield to the pistol-fire branch so they don't both
	# fire at once. The mutual-exclusion guard lives in battle_draw_actor_context.gd.
	var actor_context: Dictionary = _build_actor_context_with_hit_state(true, true, "soldier")
	_expect(
		not bool(actor_context.get("commando_attack_active", true)),
		"commando_attack_active must be false while commando_pistol_fire_active is true"
	)


func _verify_actor_context_inactive_for_smasher() -> void:
	var actor_context: Dictionary = _build_actor_context_with_hit_state(true, false, "smasher")
	_expect(
		not bool(actor_context.get("commando_attack_active", true)),
		"commando_attack_active must be false for non-soldier characters"
	)


func _verify_hit_frame_count_is_8_for_commando() -> void:
	var actor_context: Dictionary = _build_actor_context_with_hit_state(true, false, "soldier")
	var frame_count: int = int(actor_context.get("player_hit_frame_count", -1))
	_expect(
		frame_count == 8,
		"player_hit_frame_count must be 8 for commando attack (got %d)" % frame_count
	)


func _verify_effects_builder_advertises_8_frames_for_commando() -> void:
	var resources := BattleResources.new()
	var textures: Dictionary = resources.load_all({
		"selected_character_type": "soldier",
		"current_stage": 1,
		"include_all_characters": false,
		"include_all_stages": false,
		"include_result_sheets": false,
	})
	var builder := BattleUpdateEffectsSpriteContextBuilder.new()
	var ctx: Dictionary = builder.build_context(textures, "soldier")
	_expect(
		int(ctx.get("player_hit_frame_count", -1)) == 8,
		"Effects sprite builder must advertise 8 hit frames for commando, got %d" % int(ctx.get("player_hit_frame_count", -1))
	)
	# The full-swing punch reads as a real wind-up arc only when the hit
	# animation runs at the directional 0.72s pace (8 frames -> 90ms/frame).
	# Falling back to the legacy 0.40s would compress the swing to 50ms/frame
	# which the user reported as "공격모션이 너무 빨라". Lock the duration here
	# so future refactors do not silently regress the speed.
	var duration: float = float(ctx.get("player_hit_anim_duration", 0.0))
	_expect(
		abs(duration - 0.72) < 0.001,
		"Commando hit anim duration must be 0.72s for a readable full-swing, got %f" % duration
	)
	# Same guard on the draw-actor path (different code site, same value).
	var draw_actor_context: Dictionary = _build_actor_context_with_hit_state(true, false, "soldier")
	var draw_duration: float = float(draw_actor_context.get("player_hit_anim_duration", 0.0))
	_expect(
		abs(draw_duration - 0.72) < 0.001,
		"Commando draw-actor hit anim duration must be 0.72s, got %f" % draw_duration
	)


func _build_actor_context_with_hit_state(
	hit_active: bool,
	pistol_firing: bool,
	character_type: String,
	hit_side: int = -1
) -> Dictionary:
	var resources := BattleResources.new()
	var textures: Dictionary = resources.load_all({
		"selected_character_type": character_type,
		"current_stage": 1,
		"include_all_characters": false,
		"include_all_stages": false,
		"include_result_sheets": false,
	})
	var fake_animation_state := FakeAnimationState.new(hit_active, hit_side)
	var deps: Dictionary = {
		"animation_state": fake_animation_state,
	}
	if pistol_firing:
		deps["commando_firearm_runtime"] = FakePistolFiringRuntime.new()
	var draw_builder := BattleDrawActorContext.new()
	return draw_builder.build({
		"selected_character_type": character_type,
		"textures": textures,
	}, deps)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


# Minimal animation state stand-in: returns just `player_hit_active` so the
# actor-context builder can decide whether the commando attack branch should
# fire. Other animation fields fall back to defaults.
class FakeAnimationState extends RefCounted:
	var _hit_active: bool
	var _hit_side: int

	func _init(hit_active: bool, hit_side: int = -1) -> void:
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


# Pistol-firing runtime stand-in: fire_delay > 0 makes the actor context
# evaluate `commando_pistol_fire_active = true`, which must suppress
# commando_attack_active.
class FakePistolFiringRuntime extends RefCounted:
	func get_actor_draw_context() -> Dictionary:
		return {
			"commando_firearm_projectiles": [],
			"commando_firearm_muzzle_flashes": [],
			"commando_firearm_impact_flashes": [],
			"commando_firearm_lingering_effects": [],
			"commando_firearm_shell_casings": [],
			"commando_firearm_pistol_feedbacks": [],
			"commando_firearm_pistol_state": {
				"fire_delay_frames": 12.0,
				"fire_delay_max_frames": 24.0,
				"post_fire_animation_frames": 0.0,
				"post_fire_animation_max_frames": 18.0,
			},
			"commando_firearm_slingshot_state": {},
			"commando_firearm_ak47_state": {},
			"commando_firearm_bazooka_state": {},
			"commando_firearm_net_gun_state": {},
			"commando_firearm_bowling_trap_state": {},
			"commando_firearm_suicide_drone_state": {},
			"commando_firearm_support_calls": [],
			"commando_firearm_bowling_traps": [],
		}
