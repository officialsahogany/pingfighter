extends SceneTree

const BattleDrawActorContext := preload("res://scripts/core/battle_draw_actor_context.gd")
const BattleResources := preload("res://scripts/resources/battle_resources.gd")
const CommandoWeaponAnchorTable := preload("res://scripts/characters/commando_weapon_anchor_table.gd")

const WEAPON_EXPECTATIONS := {
	"pistol": {
		"texture_key": "commando_weapon_b2v2_pistol",
		"draw_size": Vector2(26.0, 42.0),
		"pivot": Vector2(12.0, 41.0),
	},
	"ak47": {
		"texture_key": "commando_weapon_b2v2_ak47",
		"draw_size": Vector2(44.0, 110.0),
		"pivot": Vector2(21.0, 109.0),
	},
	"bazooka": {
		"texture_key": "commando_weapon_b2v2_bazooka",
		"draw_size": Vector2(32.0, 118.0),
		"pivot": Vector2(15.0, 117.0),
	},
	"net_gun": {
		"texture_key": "commando_weapon_b2v2_net_gun",
		"draw_size": Vector2(42.0, 95.0),
		"pivot": Vector2(20.0, 94.0),
	},
	"bowling_trap": {
		"texture_key": "commando_weapon_b2v2_bowling_trap",
		"draw_size": Vector2(32.0, 75.0),
		"pivot": Vector2(15.0, 74.0),
	},
	"suicide_drone": {
		"texture_key": "commando_weapon_b2v2_suicide_drone",
		"draw_size": Vector2(90.0, 90.0),
		"pivot": Vector2(44.0, 89.0),
	},
}

var _failures: Array[String] = []


func _init() -> void:
	_verify_b2_weapon_textures_load()
	_verify_actor_context_for_all_weapons()
	_verify_side_walk_animation_state_mapping()
	_verify_non_commando_and_unknown_weapon_fail_closed()

	if _failures.is_empty():
		print("commando_weapon_b2_renderer_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_b2_weapon_textures_load() -> void:
	var textures: Dictionary = _load_commando_textures()
	for weapon_id in WEAPON_EXPECTATIONS.keys():
		var expected: Dictionary = WEAPON_EXPECTATIONS[weapon_id]
		var texture_key: String = String(expected["texture_key"])
		_expect(
			textures.get(texture_key, null) is Texture2D,
			"B2 texture cache must include %s for %s" % [texture_key, weapon_id]
		)


func _verify_actor_context_for_all_weapons() -> void:
	for weapon_id in WEAPON_EXPECTATIONS.keys():
		var expected: Dictionary = WEAPON_EXPECTATIONS[weapon_id]
		var ctx: Dictionary = _build_actor_context("soldier", str(weapon_id), {})
		_expect(
			bool(ctx.get("commando_weapon_b2_renderable", false)),
			"%s must be B2-renderable in idle_back" % str(weapon_id)
		)
		_expect(ctx.get("commando_weapon_b2_texture", null) is Texture2D, "%s B2 texture should resolve" % str(weapon_id))
		_expect(String(ctx.get("commando_weapon_b2_animation_state", "")) == CommandoWeaponAnchorTable.ANIMATION_IDLE_BACK, "%s should map to idle_back when stationary" % str(weapon_id))
		_expect(int(ctx.get("commando_weapon_b2_frame_index", -1)) == 0, "%s idle frame index should default to 0" % str(weapon_id))
		_expect_vector2(ctx.get("commando_weapon_b2_anchor", null), Vector2(80.0, 119.0), "%s B2 anchor" % str(weapon_id))
		_expect_vector2(ctx.get("commando_weapon_b2_draw_size", null), expected["draw_size"], "%s draw_size" % str(weapon_id))
		_expect_vector2(ctx.get("commando_weapon_b2_pivot_primary", null), expected["pivot"], "%s pivot" % str(weapon_id))
		_expect(not bool(ctx.get("commando_weapon_b2_flip_h", true)), "%s idle_back must not flip_h" % str(weapon_id))


func _verify_side_walk_animation_state_mapping() -> void:
	var right_ctx: Dictionary = _build_actor_context("soldier", "ak47", {
		"player_speed": 2.0,
	})
	_expect(String(right_ctx.get("commando_weapon_b2_animation_state", "")) == CommandoWeaponAnchorTable.ANIMATION_WALK_RIGHT, "Positive speed should map to walk_right")
	_expect(bool(right_ctx.get("commando_weapon_b2_renderable", false)), "walk_right AK-47 should be renderable")
	_expect_vector2(right_ctx.get("commando_weapon_b2_anchor", null), Vector2(80.0, 116.0), "walk_right AK-47 anchor")
	_expect(not bool(right_ctx.get("commando_weapon_b2_flip_h", true)), "walk_right AK-47 must not flip_h")

	var left_ctx: Dictionary = _build_actor_context("soldier", "ak47", {
		"player_speed": -2.0,
	})
	_expect(String(left_ctx.get("commando_weapon_b2_animation_state", "")) == CommandoWeaponAnchorTable.ANIMATION_WALK_LEFT, "Negative speed should map to walk_left")
	_expect(bool(left_ctx.get("commando_weapon_b2_renderable", false)), "walk_left AK-47 should be renderable")
	_expect_vector2(left_ctx.get("commando_weapon_b2_anchor", null), Vector2(80.0, 116.0), "walk_left AK-47 anchor")
	_expect(bool(left_ctx.get("commando_weapon_b2_flip_h", false)), "walk_left AK-47 must flip_h")


func _verify_non_commando_and_unknown_weapon_fail_closed() -> void:
	var smasher_ctx: Dictionary = _build_actor_context("smasher", "ak47", {})
	_expect(not bool(smasher_ctx.get("commando_weapon_b2_renderable", false)), "Smasher must not render Commando B2 weapon")
	_expect(smasher_ctx.get("commando_weapon_b2_texture", null) == null, "Smasher must not emit Commando B2 texture")

	var unknown_ctx: Dictionary = _build_actor_context("soldier", "__not_a_real_weapon__", {})
	_expect(not bool(unknown_ctx.get("commando_weapon_b2_renderable", false)), "Unknown Commando weapon must fail closed")
	_expect(unknown_ctx.get("commando_weapon_b2_texture", null) == null, "Unknown Commando weapon must not emit B2 texture")


func _load_commando_textures() -> Dictionary:
	var resources := BattleResources.new()
	return resources.load_all({
		"selected_character_type": "soldier",
		"current_stage": 1,
		"include_all_characters": false,
		"include_all_stages": false,
		"include_result_sheets": false,
	})


func _build_actor_context(character_type: String, weapon_id: String, extra_context: Dictionary) -> Dictionary:
	var textures: Dictionary = _load_commando_textures()
	var draw_builder := BattleDrawActorContext.new()
	var context := {
		"selected_character_type": character_type,
		"textures": textures,
	}
	context.merge(extra_context, true)
	return draw_builder.build(context, {
		"commando_weapon_controller": FakeWeaponController.new(weapon_id),
	})


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_vector2(actual: Variant, expected: Vector2, label: String) -> void:
	if not (actual is Vector2):
		_failures.append("%s: expected Vector2, got %s" % [label, str(actual)])
		return
	var v: Vector2 = actual
	if abs(v.x - expected.x) > 0.001 or abs(v.y - expected.y) > 0.001:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(v)])


class FakeWeaponController extends RefCounted:
	var current_weapon_id: String

	func _init(weapon_id: String) -> void:
		current_weapon_id = weapon_id
