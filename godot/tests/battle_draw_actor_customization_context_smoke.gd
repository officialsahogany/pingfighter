extends SceneTree

# expect-zero-object-leaks

const OWNER_PATH := "res://scripts/core/battle_draw_actor_customization_context.gd"
const FACADE_PATH := "res://scripts/core/battle_draw_actor_context.gd"

var _failures: Array[String] = []


func _init() -> void:
	_verify_owner_boundary()
	if FileAccess.file_exists(OWNER_PATH):
		_verify_texture_projection_and_priority()
		_verify_optimus_default_slots()
		_verify_runtime_perk_part_injection()
		_verify_smasher_debug_slot_policy()

	if _failures.is_empty():
		print("battle_draw_actor_customization_context_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_owner_boundary() -> void:
	_expect(FileAccess.file_exists(OWNER_PATH), "actor customization projection should have a focused context owner")
	if not FileAccess.file_exists(OWNER_PATH):
		return
	var facade_source := FileAccess.get_file_as_string(FACADE_PATH)
	var owner_source := FileAccess.get_file_as_string(OWNER_PATH)
	_expect(facade_source.contains("BattleDrawActorCustomizationContext"), "actor context should preload the customization owner")
	_expect(facade_source.contains("customization_context.get_overlay_textures("), "actor context should delegate overlay texture projection")
	_expect(facade_source.contains("customization_context.get_overlay_slots("), "actor context should delegate overlay slot projection")
	for removed_method in [
		"func _get_player_customization_overlay_textures",
		"func _get_player_customization_overlay_slots",
		"func _inject_optimus_default_overlay_slots",
		"func _build_smasher_debug_paddle_overlay_slot",
	]:
		_expect(not facade_source.contains(removed_method), "actor context should not retain %s" % removed_method)
	_expect(owner_source.contains("RuntimePerkVisualPartCatalog.inject_overlay_slots"), "focused owner should retain perk-part slot injection")
	_expect(not owner_source.contains("func build("), "focused owner should return the two existing dictionaries without an extra wrapper payload")


func _verify_texture_projection_and_priority() -> void:
	var owner: Object = _new_owner()
	var custom_optimus := _make_texture(Color(0.8, 0.1, 0.2, 1.0))
	var cached_optimus := _make_texture(Color(0.1, 0.8, 0.2, 1.0))
	var debug_sheet := _make_texture(Color(0.1, 0.2, 0.8, 1.0))
	var coin_sheet := _make_texture(Color(0.9, 0.8, 0.2, 1.0))
	var source_textures := {
		"optimus_overlay_paddle": custom_optimus,
		"user_marker": "keep",
	}
	var result: Dictionary = owner.get_overlay_textures(
		{"player_customization_overlay_textures": source_textures},
		{
			"optimus_overlay_paddle": cached_optimus,
			"optimus_overlay_core_glow": "not_a_texture",
			"smasher_debug_paddle_overlay_sheet": debug_sheet,
			"perk_visual_part_lucky_coin": coin_sheet,
		}
	)
	_expect(result.get("optimus_overlay_paddle") == custom_optimus, "user overlay texture should keep priority over the battle cache")
	_expect(result.get("smasher_debug_paddle_overlay_sheet") == debug_sheet, "debug paddle texture should project from the battle cache")
	_expect(result.get("perk_visual_part_lucky_coin") == coin_sheet, "runtime perk part texture should project from the battle cache")
	_expect(not result.has("optimus_overlay_core_glow"), "non-Texture2D cache values should fail closed")
	_expect(str(result.get("user_marker", "")) == "keep", "caller-provided overlay entries should remain intact")
	result.erase("user_marker")
	_expect(source_textures.has("user_marker"), "texture projection should not mutate the caller dictionary")


func _verify_optimus_default_slots() -> void:
	var owner: Object = _new_owner()
	var overlay_textures := {
		"optimus_overlay_paddle": _make_texture(Color.RED),
		"optimus_overlay_core_glow": _make_texture(Color.GREEN),
		"optimus_overlay_back": _make_texture(Color.BLUE),
		"optimus_overlay_accessory": _make_texture(Color.YELLOW),
		"optimus_overlay_outfit_accent": _make_texture(Color.MAGENTA),
	}
	var custom_accessory := {"texture_key": "user_accessory", "dest_offset": Vector2(4.0, 5.0)}
	var source_slots := {"accessory": custom_accessory}
	var slots: Dictionary = owner.get_overlay_slots(
		{"player_customization_overlay_slots": source_slots},
		overlay_textures,
		"optimus"
	)
	for slot_id in ["paddle", "core_glow", "back", "accessory", "outfit_accent"]:
		_expect(slots.has(slot_id), "Optimus should expose default %s overlay when its texture is loaded" % slot_id)
	_expect((slots.get("accessory") as Dictionary).has("dest_offset"), "existing user accessory should beat the Optimus default")
	var paddle: Dictionary = slots.get("paddle", {})
	var core_glow: Dictionary = slots.get("core_glow", {})
	_expect(bool(paddle.get("scale_from_player_paddle", false)), "Optimus paddle slot should scale from player paddle size")
	_expect(bool(core_glow.get("alpha_from_energy_ratio", false)), "Optimus core glow should follow energy ratio")
	_expect(int(paddle.get("grid_cols", 0)) == 4 and int(paddle.get("frame_count", 0)) == 8, "Optimus default slot should keep the authored 4x2 eight-frame grid")
	_expect(str(paddle.get("mirror_policy", "")) == "mirror_ok", "Optimus default slot should preserve mirrored left-facing policy")
	slots.erase("accessory")
	_expect(source_slots.has("accessory"), "slot projection should not mutate the caller dictionary")


func _verify_runtime_perk_part_injection() -> void:
	var owner: Object = _new_owner()
	var coin_sheet := _make_texture(Color(1.0, 0.85, 0.2, 1.0))
	var context := {"player_perk_visual_part_levels": {"item_luck": 2}}
	var slots: Dictionary = owner.get_overlay_slots(
		context,
		{"perk_visual_part_lucky_coin": coin_sheet},
		"smasher"
	)
	_expect(slots.has("accessory"), "owned item_luck should inject its accessory slot")
	var accessory: Dictionary = slots.get("accessory", {})
	_expect(str(accessory.get("texture_key", "")) == "perk_visual_part_lucky_coin", "item_luck slot should reference the loaded coin texture")
	_expect(str(accessory.get("socket_id", "")) == "head_top", "item_luck part should preserve its head-top socket")
	var missing_texture: Dictionary = owner.get_overlay_slots(context, {}, "smasher")
	_expect(not missing_texture.has("accessory"), "owned perk without a loaded texture should fail closed")
	var user_accessory := {"texture_key": "user"}
	var user_priority: Dictionary = owner.get_overlay_slots(
		{
			"player_perk_visual_part_levels": {"item_luck": 2},
			"player_customization_overlay_slots": {"accessory": user_accessory},
		},
		{"perk_visual_part_lucky_coin": coin_sheet},
		"smasher"
	)
	_expect(str((user_priority.get("accessory") as Dictionary).get("texture_key", "")) == "user", "user accessory should beat runtime perk injection")


func _verify_smasher_debug_slot_policy() -> void:
	var owner: Object = _new_owner()
	var debug_sheet := _make_texture(Color.CYAN)
	var textures := {"smasher_debug_paddle_overlay_sheet": debug_sheet}
	var enabled := {"player_customization_debug_overlay_enabled": true}
	var slots: Dictionary = owner.get_overlay_slots(enabled, textures, "smasher")
	_expect(slots.has("paddle"), "enabled Smasher debug mode should inject the paddle slot")
	var paddle: Dictionary = slots.get("paddle", {})
	_expect(str(paddle.get("mirror_policy", "")) == "mirror_ok", "debug paddle should mirror its right-facing sheet")
	var motions: Dictionary = paddle.get("motions", {})
	for motion in ["idle", "walk", "dash", "attack"]:
		_expect(motions.has(motion), "debug paddle should define %s motion routing" % motion)
	_expect(owner.get_overlay_slots({}, textures, "smasher").is_empty(), "disabled debug mode should not inject the paddle")
	_expect(owner.get_overlay_slots(enabled, textures, "viper").is_empty(), "debug paddle should remain Smasher-only")
	_expect(owner.get_overlay_slots(enabled, {}, "smasher").is_empty(), "debug paddle should require a loaded Texture2D")
	var user_paddle := {"texture_key": "user_paddle"}
	var user_slots: Dictionary = owner.get_overlay_slots(
		{
			"player_customization_debug_overlay_enabled": true,
			"player_customization_overlay_slots": {"paddle": user_paddle},
		},
		textures,
		"smasher"
	)
	_expect(str((user_slots.get("paddle") as Dictionary).get("texture_key", "")) == "user_paddle", "user paddle should beat the debug fallback")


func _new_owner() -> Object:
	var owner_script: Script = load(OWNER_PATH)
	return owner_script.new()


func _make_texture(color: Color) -> Texture2D:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
