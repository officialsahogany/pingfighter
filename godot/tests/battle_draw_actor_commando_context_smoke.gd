extends SceneTree

# expect-zero-object-leaks

const OWNER_PATH := "res://scripts/core/battle_draw_actor_commando_context.gd"
const FACADE_PATH := "res://scripts/core/battle_draw_actor_context.gd"

var _failures: Array[String] = []


class SnapshotState:
	extends RefCounted

	var snapshot: Dictionary

	func _init(value: Dictionary) -> void:
		snapshot = value

	func get_snapshot() -> Dictionary:
		return snapshot


class SupplyPropertyState:
	extends RefCounted

	var radio_motion := true


class ReloadPropertyState:
	extends RefCounted

	var active := true
	var phase := "radio"


func _init() -> void:
	_verify_owner_boundary()
	if FileAccess.file_exists(OWNER_PATH):
		_verify_animation_and_anchor_policy()
		_verify_weapon_fire_policy()
		_verify_weapon_flip_policy()
		_verify_radio_motion_policy()
		_verify_legacy_overlay_calibration()

	if _failures.is_empty():
		print("battle_draw_actor_commando_context_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_owner_boundary() -> void:
	_expect(FileAccess.file_exists(OWNER_PATH), "Commando actor projection should have a focused context owner")
	if not FileAccess.file_exists(OWNER_PATH):
		return
	var facade_source := FileAccess.get_file_as_string(FACADE_PATH)
	var owner_source := FileAccess.get_file_as_string(OWNER_PATH)
	_expect(facade_source.contains("BattleDrawActorCommandoContext"), "actor context should preload the focused Commando owner")
	_expect(facade_source.contains("commando_context.get_weapon_fire_sheet("), "weapon fire sheet projection should delegate")
	_expect(facade_source.contains("commando_context.get_b2_animation_state("), "B2 animation projection should delegate")
	_expect(facade_source.contains("commando_context.get_overlay_texture_key("), "legacy overlay calibration should delegate")
	_expect(not facade_source.contains("func _get_commando_"), "actor context should not retain concrete Commando helper methods")
	_expect(not facade_source.contains("func _is_commando_"), "actor context should not retain Commando radio policy")
	_expect(not facade_source.contains("_COMMANDO_WEAPON_OVERLAY_TABLE"), "actor context should not retain the Commando overlay calibration table")
	_expect(not facade_source.contains("CommandoWeaponAnchorTable"), "Commando anchor-table lifetime should belong to the focused owner")
	_expect(owner_source.contains("const WEAPON_OVERLAY_TABLE"), "focused owner should retain the legacy overlay calibration table")


func _verify_animation_and_anchor_policy() -> void:
	var owner: Object = _new_owner()
	_expect(owner.get_b2_animation_state(false, 0.0, false, 1) == "", "non-Commando actor should expose no B2 animation")
	_expect(owner.get_b2_animation_state(true, 0.0, false, 1) == "idle_back", "stationary Commando should use idle_back")
	_expect(owner.get_b2_animation_state(true, -1.0, false, -1) == "walk_left", "negative Commando motion should use walk_left")
	_expect(owner.get_b2_animation_state(true, 1.0, false, 1) == "walk_right", "positive Commando motion should use walk_right")
	_expect(owner.get_b2_animation_state(true, 0.0, true, -1) == "walk_left", "dash motion should keep directional walk animation")
	var animation := {"player_idle_frame": 6, "player_sprite_frame": 3}
	_expect(owner.get_b2_frame_index("idle_back", animation) == 6, "idle B2 frame should follow player_idle_frame")
	for state in ["walk_back", "walk_left", "walk_right"]:
		_expect(owner.get_b2_frame_index(state, animation) == 3, "%s B2 frame should follow player_sprite_frame" % state)
	_expect(owner.get_b2_frame_index("", animation) == 0, "unknown B2 state should fail closed to frame zero")
	var frame_anchor: Dictionary = owner.get_frame_anchor("idle_back", 0)
	var weapon_pivot: Dictionary = owner.get_weapon_pivot("ak47")
	_expect(not frame_anchor.is_empty(), "focused owner should expose the existing Commando frame anchor table")
	_expect(not weapon_pivot.is_empty(), "focused owner should expose the existing Commando weapon pivot table")
	_expect(owner.resolve_b2_anchor({"primary": Vector2(1.0, 2.0)}, {"anchor_overrides": {"walk_left": Vector2(3.0, 4.0)}}, "walk_left") == Vector2(3.0, 4.0), "weapon animation override should beat the primary frame anchor")
	_expect(owner.resolve_b2_anchor({"primary": Vector2(1.0, 2.0)}, {}, "idle_back") == Vector2(1.0, 2.0), "missing weapon override should use the primary frame anchor")


func _verify_weapon_fire_policy() -> void:
	var owner: Object = _new_owner()
	var cases := {
		"ak47": "commando_player_ak47_fire_sheet",
		"bazooka": "commando_player_bazooka_fire_sheet",
		"net_gun": "commando_player_net_gun_fire_sheet",
		"bowling_trap": "commando_player_bowling_trap_place_sheet",
		"suicide_drone": "commando_player_suicide_drone_control_sheet",
	}
	var textures: Dictionary = {}
	for weapon_id in cases:
		textures[cases[weapon_id]] = _make_texture()
	for weapon_id in cases:
		_expect(owner.get_weapon_fire_sheet(textures, weapon_id) == textures[cases[weapon_id]], "%s should resolve its authored weapon-fire sheet" % weapon_id)
	_expect(owner.get_weapon_fire_sheet(textures, "pistol") == null, "pistol should remain on its dedicated separate sheet path")
	_expect(owner.get_weapon_fire_frame({"frame_count": 8, "timer_max_frames": 8.0, "timer_frames": 8.0}) == 0, "weapon-fire animation should begin at frame zero")
	_expect(owner.get_weapon_fire_frame({"frame_count": 8, "timer_max_frames": 8.0, "timer_frames": 4.0}) == 4, "half-consumed weapon-fire timer should select frame four")
	_expect(owner.get_weapon_fire_frame({"frame_count": 8, "timer_max_frames": 8.0, "timer_frames": 0.0}) == 7, "completed weapon-fire timer should clamp to the final frame")


func _verify_weapon_flip_policy() -> void:
	var owner: Object = _new_owner()
	var player_pos := Vector2(100.0, 700.0)
	var player_size := Vector2(100.0, 40.0)
	_expect(not owner.get_weapon_fire_flip_h(false, "ak47", -1, player_pos, player_size, {}), "inactive weapon sheet should never flip")
	_expect(owner.get_weapon_fire_flip_h(true, "ak47", -1, player_pos, player_size, {}), "left-moving weapon sheet should flip")
	_expect(not owner.get_weapon_fire_flip_h(true, "ak47", 1, player_pos, player_size, {}), "right-moving weapon sheet should retain authored facing")
	var left_drone := {"commando_firearm_suicide_drone_state": {"active": true, "pos": Vector2(120.0, 600.0)}}
	var right_drone := {"commando_firearm_suicide_drone_state": {"active": true, "pos": Vector2(180.0, 600.0)}}
	_expect(owner.get_weapon_fire_flip_h(true, "suicide_drone", 1, player_pos, player_size, left_drone), "drone left of player center should flip the control sheet")
	_expect(not owner.get_weapon_fire_flip_h(true, "suicide_drone", -1, player_pos, player_size, right_drone), "drone right of player center should retain authored facing")


func _verify_radio_motion_policy() -> void:
	var owner: Object = _new_owner()
	_expect(owner.is_supply_radio_motion({"commando_supply_drop_state": SnapshotState.new({"radio_motion": true})}), "supply snapshot should expose radio motion")
	_expect(owner.is_supply_radio_motion({"commando_supply_drop_state": SupplyPropertyState.new()}), "legacy supply property should remain a fallback")
	_expect(owner.is_reload_radio_motion({"commando_reload_delivery_state": SnapshotState.new({"radio_visible": true, "radio_alpha": 0.5})}), "visible reload radio snapshot should activate the radio sheet")
	_expect(not owner.is_reload_radio_motion({"commando_reload_delivery_state": SnapshotState.new({"radio_visible": true, "radio_alpha": 0.0})}), "zero-alpha reload radio should not activate the sheet")
	_expect(owner.is_reload_radio_motion({"commando_reload_delivery_state": ReloadPropertyState.new()}), "legacy reload phase should remain a fallback")
	_expect(owner.is_fire_support_radio_motion({"commando_firearm_support_calls": [{"weapon_id": "fire_support", "state": "calling"}]}), "calling fire support should activate radio motion")
	_expect(not owner.is_fire_support_radio_motion({"commando_firearm_support_calls": [{"weapon_id": "airstrike", "state": "calling"}]}), "unrelated support calls should not activate Commando radio motion")
	_expect(owner.get_radio_call_frame({"current_msec": 0}) == 0, "radio animation should begin at frame zero")
	_expect(owner.get_radio_call_frame({"current_msec": 109}) == 0, "radio frame should hold for the authored 110ms")
	_expect(owner.get_radio_call_frame({"current_msec": 110}) == 1, "radio animation should advance after 110ms")
	_expect(owner.get_radio_call_frame({"current_msec": 880}) == 0, "radio animation should wrap after eight frames")


func _verify_legacy_overlay_calibration() -> void:
	var owner: Object = _new_owner()
	var expected := {
		"ak47": ["commando_weapon_overlay_ak47", Vector2(40.0, 102.0), Vector2(20.0, 102.0), Vector2(60.0, 102.0), Vector2(100.0, 30.0), true],
		"bazooka": ["commando_weapon_overlay_bazooka", Vector2(35.0, 95.0), Vector2(15.0, 95.0), Vector2(55.0, 95.0), Vector2(110.0, 42.0), true],
		"net_gun": ["commando_weapon_overlay_net_gun", Vector2(47.0, 95.0), Vector2(27.0, 95.0), Vector2(67.0, 95.0), Vector2(85.0, 47.0), true],
		"bowling_trap": ["commando_weapon_overlay_bowling_trap", Vector2(75.0, 75.0), Vector2(70.0, 75.0), Vector2(80.0, 75.0), Vector2(31.0, 75.0), false],
		"suicide_drone": ["commando_weapon_overlay_suicide_drone", Vector2(35.0, 60.0), Vector2(15.0, 60.0), Vector2(55.0, 60.0), Vector2(91.0, 95.0), false],
	}
	for weapon_id in expected:
		var spec: Array = expected[weapon_id]
		_expect(owner.get_overlay_texture_key(weapon_id) == spec[0], "%s overlay texture key should remain calibrated" % weapon_id)
		_expect(owner.get_overlay_anchor_back(weapon_id) == spec[1], "%s back anchor should remain calibrated" % weapon_id)
		_expect(owner.get_overlay_anchor_left(weapon_id) == spec[2], "%s left anchor should remain calibrated" % weapon_id)
		_expect(owner.get_overlay_anchor_right(weapon_id) == spec[3], "%s right anchor should remain calibrated" % weapon_id)
		_expect(owner.get_overlay_draw_size(weapon_id) == spec[4], "%s overlay size should remain calibrated" % weapon_id)
		_expect(owner.get_overlay_flip_h_for_walk_left(weapon_id) == spec[5], "%s overlay flip policy should remain calibrated" % weapon_id)
	_expect(owner.get_overlay_texture_key("pistol") == "", "pistol should have no legacy replacement overlay")
	_expect(owner.get_overlay_draw_size("pistol") == Vector2.ZERO, "unknown overlay should fail closed")


func _new_owner() -> Object:
	var owner_script: Script = load(OWNER_PATH)
	return owner_script.new()


func _make_texture() -> Texture2D:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
