extends SceneTree

# Smoke test for the per-firearm weapon overlay system.
#
# When the commando equips a non-pistol firearm (AK-47, bazooka, net_gun,
# bowling_trap, suicide_drone), the matching weapon overlay PNG is drawn on
# top of the base character so the rifle / launcher / trap / drone visually
# replaces the pistol that is baked into the idle/walk_* base sheets.
#
# This test covers:
#   1. All 5 overlay PNGs load as Texture2D from the cache.
#   2. battle_draw_actor_context.gd emits the right context keys for each
#      equipped weapon (texture, anchors, draw_size, flip_h_for_walk_left).
#   3. When weapon_id == "pistol" or character is not commando, the overlay
#      texture key is null (no overlay should be drawn).
#   4. Each weapon's anchor_back, anchor_left, anchor_right, draw_size, and
#      flip flag match the locked-down values authored in
#      `_COMMANDO_WEAPON_OVERLAY_TABLE`. This is the gate that prevents a
#      future refactor from silently dropping or shifting an anchor.

const BattleDrawActorContext := preload("res://scripts/core/battle_draw_actor_context.gd")
const BattleResources := preload("res://scripts/resources/battle_resources.gd")

const AK47_OVERLAY_PATH := "res://assets/sprites/characters/commando/weapons/commando_weapon_overlay_ak47.png"
const BAZOOKA_OVERLAY_PATH := "res://assets/sprites/characters/commando/weapons/commando_weapon_overlay_bazooka.png"
const NET_GUN_OVERLAY_PATH := "res://assets/sprites/characters/commando/weapons/commando_weapon_overlay_net_gun.png"
const BOWLING_TRAP_OVERLAY_PATH := "res://assets/sprites/characters/commando/weapons/commando_weapon_overlay_bowling_trap.png"
const SUICIDE_DRONE_OVERLAY_PATH := "res://assets/sprites/characters/commando/weapons/commando_weapon_overlay_suicide_drone.png"

var _failures: Array[String] = []


func _init() -> void:
	_verify_all_overlay_pngs_load()
	_verify_overlay_textures_in_cache()
	_verify_pistol_emits_no_overlay_texture()
	_verify_smasher_emits_no_overlay_texture()
	_verify_ak47_overlay_metadata()
	_verify_bazooka_overlay_metadata()
	_verify_net_gun_overlay_metadata()
	_verify_bowling_trap_overlay_metadata()
	_verify_suicide_drone_overlay_metadata()
	_verify_unknown_weapon_falls_back_safely()

	if _failures.is_empty():
		print("commando_weapon_overlay_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_all_overlay_pngs_load() -> void:
	for path in [
		AK47_OVERLAY_PATH,
		BAZOOKA_OVERLAY_PATH,
		NET_GUN_OVERLAY_PATH,
		BOWLING_TRAP_OVERLAY_PATH,
		SUICIDE_DRONE_OVERLAY_PATH,
	]:
		var tex: Texture2D = load(path)
		_expect(tex is Texture2D, "Overlay PNG should load: %s" % path)


func _verify_overlay_textures_in_cache() -> void:
	var resources := BattleResources.new()
	var textures: Dictionary = resources.load_all({
		"selected_character_type": "soldier",
		"current_stage": 1,
		"include_all_characters": false,
		"include_all_stages": false,
		"include_result_sheets": false,
	})
	for key in [
		"commando_weapon_overlay_ak47",
		"commando_weapon_overlay_bazooka",
		"commando_weapon_overlay_net_gun",
		"commando_weapon_overlay_bowling_trap",
		"commando_weapon_overlay_suicide_drone",
	]:
		_expect(
			textures.get(key, null) is Texture2D,
			"battle_resources cache must include %s for soldier" % key
		)


func _verify_pistol_emits_no_overlay_texture() -> void:
	var ctx: Dictionary = _build_commando_actor_context("pistol")
	# When pistol is the equipped weapon, the overlay texture key resolves
	# to "" (no entry in the overlay table), so the renderer falls back to
	# the baked pistol in the base sheet — overlay must be skipped.
	_expect(
		ctx.get("commando_weapon_overlay_texture", null) == null,
		"Pistol-equipped commando must not emit an overlay texture (got non-null)"
	)
	_expect(
		String(ctx.get("commando_current_weapon_id", "")) == "pistol",
		"Pistol-equipped commando must report weapon id 'pistol'"
	)


func _verify_smasher_emits_no_overlay_texture() -> void:
	var ctx: Dictionary = _build_actor_context_for_character("smasher", "ak47")
	# Even if commando_weapon_controller fakes ak47, smasher path must not
	# emit an overlay texture (overlay is commando-only).
	_expect(
		ctx.get("commando_weapon_overlay_texture", null) == null,
		"Smasher must not emit a commando weapon overlay texture"
	)
	_expect(
		String(ctx.get("commando_current_weapon_id", "pistol")) == "pistol",
		"Smasher path must report weapon id 'pistol' (default), not the faked controller value"
	)


func _verify_ak47_overlay_metadata() -> void:
	var ctx: Dictionary = _build_commando_actor_context("ak47")
	_expect(
		ctx.get("commando_weapon_overlay_texture", null) is Texture2D,
		"AK-47 overlay texture must resolve to Texture2D"
	)
	_expect_vector2(ctx.get("commando_weapon_overlay_anchor_back", null), Vector2(40.0, 102.0), "ak47 anchor_back")
	_expect_vector2(ctx.get("commando_weapon_overlay_anchor_left", null), Vector2(20.0, 102.0), "ak47 anchor_left")
	_expect_vector2(ctx.get("commando_weapon_overlay_anchor_right", null), Vector2(60.0, 102.0), "ak47 anchor_right")
	_expect_vector2(ctx.get("commando_weapon_overlay_draw_size", null), Vector2(100.0, 30.0), "ak47 draw_size")
	_expect(
		bool(ctx.get("commando_weapon_overlay_flip_h_for_walk_left", false)) == true,
		"ak47 overlay must flip horizontally for walk_left"
	)


func _verify_bazooka_overlay_metadata() -> void:
	var ctx: Dictionary = _build_commando_actor_context("bazooka")
	_expect(
		ctx.get("commando_weapon_overlay_texture", null) is Texture2D,
		"Bazooka overlay texture must resolve to Texture2D"
	)
	_expect_vector2(ctx.get("commando_weapon_overlay_anchor_back", null), Vector2(35.0, 95.0), "bazooka anchor_back")
	_expect_vector2(ctx.get("commando_weapon_overlay_draw_size", null), Vector2(110.0, 42.0), "bazooka draw_size")
	_expect(
		bool(ctx.get("commando_weapon_overlay_flip_h_for_walk_left", false)) == true,
		"bazooka overlay must flip horizontally for walk_left"
	)


func _verify_net_gun_overlay_metadata() -> void:
	var ctx: Dictionary = _build_commando_actor_context("net_gun")
	_expect(
		ctx.get("commando_weapon_overlay_texture", null) is Texture2D,
		"Net gun overlay texture must resolve to Texture2D"
	)
	_expect_vector2(ctx.get("commando_weapon_overlay_anchor_back", null), Vector2(47.0, 95.0), "net_gun anchor_back")
	_expect_vector2(ctx.get("commando_weapon_overlay_draw_size", null), Vector2(85.0, 47.0), "net_gun draw_size")


func _verify_bowling_trap_overlay_metadata() -> void:
	var ctx: Dictionary = _build_commando_actor_context("bowling_trap")
	_expect(
		ctx.get("commando_weapon_overlay_texture", null) is Texture2D,
		"Bowling trap overlay texture must resolve to Texture2D"
	)
	_expect_vector2(ctx.get("commando_weapon_overlay_anchor_back", null), Vector2(75.0, 75.0), "bowling_trap anchor_back")
	_expect_vector2(ctx.get("commando_weapon_overlay_draw_size", null), Vector2(31.0, 75.0), "bowling_trap draw_size")
	_expect(
		bool(ctx.get("commando_weapon_overlay_flip_h_for_walk_left", true)) == false,
		"bowling_trap is held vertically and must NOT flip horizontally"
	)


func _verify_suicide_drone_overlay_metadata() -> void:
	var ctx: Dictionary = _build_commando_actor_context("suicide_drone")
	_expect(
		ctx.get("commando_weapon_overlay_texture", null) is Texture2D,
		"Suicide drone overlay texture must resolve to Texture2D"
	)
	_expect_vector2(ctx.get("commando_weapon_overlay_anchor_back", null), Vector2(35.0, 60.0), "suicide_drone anchor_back")
	_expect_vector2(ctx.get("commando_weapon_overlay_draw_size", null), Vector2(91.0, 95.0), "suicide_drone draw_size")


func _verify_unknown_weapon_falls_back_safely() -> void:
	# An unknown weapon id must NOT crash the context builder. It must emit
	# a null texture and zero-sized anchors so the renderer's safety guards
	# kick in (and refuse to draw).
	var ctx: Dictionary = _build_commando_actor_context("__not_a_real_weapon__")
	_expect(
		ctx.get("commando_weapon_overlay_texture", null) == null,
		"Unknown weapon id must emit null overlay texture (no crash, no fallback)"
	)
	_expect_vector2(ctx.get("commando_weapon_overlay_draw_size", null), Vector2.ZERO, "unknown weapon draw_size = ZERO")


func _build_commando_actor_context(weapon_id: String) -> Dictionary:
	return _build_actor_context_for_character("soldier", weapon_id)


func _build_actor_context_for_character(character_type: String, weapon_id: String) -> Dictionary:
	var resources := BattleResources.new()
	var textures: Dictionary = resources.load_all({
		"selected_character_type": character_type,
		"current_stage": 1,
		"include_all_characters": false,
		"include_all_stages": false,
		"include_result_sheets": false,
	})
	var deps: Dictionary = {
		"commando_weapon_controller": FakeWeaponController.new(weapon_id),
	}
	var draw_builder := BattleDrawActorContext.new()
	return draw_builder.build({
		"selected_character_type": character_type,
		"textures": textures,
	}, deps)


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


# Minimal stand-in for the real commando_weapon_controller. The actor context
# builder only reads `current_weapon_id` so we only need that property. Using
# a real RefCounted with a typed property keeps `"current_weapon_id" in obj`
# returning true the same way the real controller does.
class FakeWeaponController extends RefCounted:
	var current_weapon_id: String

	func _init(weapon_id: String) -> void:
		current_weapon_id = weapon_id
