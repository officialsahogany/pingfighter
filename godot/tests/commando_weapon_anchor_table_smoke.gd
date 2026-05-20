extends SceneTree

## Smoke test for the B2 weapon anchor table.
##
## The table now contains the first B2 frame-anchor calibration pass for
## idle_back / walk_left / walk_right plus the first six weapon-only pivots.

const CommandoWeaponAnchorTable := preload("res://scripts/characters/commando_weapon_anchor_table.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_table_constructs_cleanly()
	_verify_unknown_animation_returns_empty_anchor()
	_verify_unknown_weapon_returns_empty_pivot()
	_verify_configured_frame_anchors()
	_verify_walk_back_remains_unconfigured()
	_verify_configured_weapon_pivots()
	_verify_negative_or_oob_frame_index_clamps_safely()
	_verify_overlay_renderable_for_configured_idle_weapon()
	_verify_animation_state_constants_match_renderer_branches()
	_verify_weapon_id_constants_match_controller_keys()

	if _failures.is_empty():
		print("commando_weapon_anchor_table_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_table_constructs_cleanly() -> void:
	var table = CommandoWeaponAnchorTable.new()
	_expect(table != null, "CommandoWeaponAnchorTable.new() must return non-null instance")


func _verify_unknown_animation_returns_empty_anchor() -> void:
	var table = CommandoWeaponAnchorTable.new()
	var anchor: Dictionary = table.get_frame_anchor("__not_a_real_animation__", 0)
	_expect(
		anchor.is_empty(),
		"Unknown animation state must return empty anchor dict (got %s)" % str(anchor)
	)


func _verify_unknown_weapon_returns_empty_pivot() -> void:
	var table = CommandoWeaponAnchorTable.new()
	var pivot: Dictionary = table.get_weapon_pivot("__not_a_real_weapon__")
	_expect(
		pivot.is_empty(),
		"Unknown weapon id must return empty pivot dict (got %s)" % str(pivot)
	)


func _verify_configured_frame_anchors() -> void:
	var table = CommandoWeaponAnchorTable.new()
	for state in [
		CommandoWeaponAnchorTable.ANIMATION_IDLE_BACK,
		CommandoWeaponAnchorTable.ANIMATION_WALK_LEFT,
		CommandoWeaponAnchorTable.ANIMATION_WALK_RIGHT,
	]:
		var expected_primary := Vector2(80.0, 119.0) if state == CommandoWeaponAnchorTable.ANIMATION_IDLE_BACK else Vector2(80.0, 116.0)
		for frame_index in range(8):
			var anchor: Dictionary = table.get_frame_anchor(state, frame_index)
			_expect(
				not anchor.is_empty(),
				"Configured animation '%s' frame %d must return an anchor" % [state, frame_index]
			)
			_expect_vector2(
				anchor.get("primary", null),
				expected_primary,
				"%s frame %d primary anchor" % [state, frame_index]
			)
			_expect_vector2(
				anchor.get("secondary", null),
				Vector2.ZERO,
				"%s frame %d secondary anchor" % [state, frame_index]
			)
			_expect(
				float(anchor.get("rot", -999.0)) == 0.0,
				"%s frame %d rotation must start at 0.0" % [state, frame_index]
			)


func _verify_walk_back_remains_unconfigured() -> void:
	# `walk_back` is reserved for a future base-grip sheet. The current
	# runtime uses idle_back plus side walk sheets, so walk_back must still
	# fail closed.
	var table = CommandoWeaponAnchorTable.new()
	var anchor: Dictionary = table.get_frame_anchor(CommandoWeaponAnchorTable.ANIMATION_WALK_BACK, 0)
	_expect(
		anchor.is_empty(),
		"walk_back must stay empty until its base-grip sheet exists (got %s)" % str(anchor)
	)


func _verify_configured_weapon_pivots() -> void:
	var table = CommandoWeaponAnchorTable.new()
	var expected := {
		CommandoWeaponAnchorTable.WEAPON_PISTOL: {
			"texture_key": "commando_weapon_b2v2_pistol",
			"draw_size": Vector2(26.0, 42.0),
			"pivot_primary": Vector2(12.0, 41.0),
		},
		CommandoWeaponAnchorTable.WEAPON_AK47: {
			"texture_key": "commando_weapon_b2v2_ak47",
			"draw_size": Vector2(44.0, 110.0),
			"pivot_primary": Vector2(21.0, 109.0),
		},
		CommandoWeaponAnchorTable.WEAPON_BAZOOKA: {
			"texture_key": "commando_weapon_b2v2_bazooka",
			"draw_size": Vector2(32.0, 118.0),
			"pivot_primary": Vector2(15.0, 117.0),
		},
		CommandoWeaponAnchorTable.WEAPON_NET_GUN: {
			"texture_key": "commando_weapon_b2v2_net_gun",
			"draw_size": Vector2(42.0, 95.0),
			"pivot_primary": Vector2(20.0, 94.0),
		},
		CommandoWeaponAnchorTable.WEAPON_BOWLING_TRAP: {
			"texture_key": "commando_weapon_b2v2_bowling_trap",
			"draw_size": Vector2(32.0, 75.0),
			"pivot_primary": Vector2(15.0, 74.0),
		},
		CommandoWeaponAnchorTable.WEAPON_SUICIDE_DRONE: {
			"texture_key": "commando_weapon_b2v2_suicide_drone",
			"draw_size": Vector2(90.0, 90.0),
			"pivot_primary": Vector2(44.0, 89.0),
		},
	}
	for weapon_id in expected.keys():
		var pivot: Dictionary = table.get_weapon_pivot(str(weapon_id))
		_expect(
			not pivot.is_empty(),
			"Configured weapon '%s' must return pivot metadata" % str(weapon_id)
		)
		var expected_entry: Dictionary = expected[weapon_id]
		_expect(
			String(pivot.get("texture_key", "")) == String(expected_entry["texture_key"]),
			"%s texture key mismatch" % str(weapon_id)
		)
		_expect_vector2(pivot.get("draw_size", null), expected_entry["draw_size"], "%s draw_size" % str(weapon_id))
		_expect_vector2(pivot.get("pivot_primary", null), expected_entry["pivot_primary"], "%s pivot_primary" % str(weapon_id))


func _verify_negative_or_oob_frame_index_clamps_safely() -> void:
	# Configured animations must clamp negative or out-of-range indices
	# instead of crashing. Empty animations still return empty safely.
	var table = CommandoWeaponAnchorTable.new()
	var anchor_neg: Dictionary = table.get_frame_anchor(CommandoWeaponAnchorTable.ANIMATION_IDLE_BACK, -5)
	var anchor_huge: Dictionary = table.get_frame_anchor(CommandoWeaponAnchorTable.ANIMATION_IDLE_BACK, 9999)
	_expect_vector2(anchor_neg.get("primary", null), Vector2(80.0, 119.0), "Negative frame index clamps to first anchor")
	_expect_vector2(anchor_huge.get("primary", null), Vector2(80.0, 119.0), "OOB frame index clamps to last anchor")
	var walk_back_huge: Dictionary = table.get_frame_anchor(CommandoWeaponAnchorTable.ANIMATION_WALK_BACK, 9999)
	_expect(walk_back_huge.is_empty(), "OOB frame index on empty walk_back must return empty (got %s)" % str(walk_back_huge))


func _verify_overlay_renderable_for_configured_idle_weapon() -> void:
	var table = CommandoWeaponAnchorTable.new()
	var renderable: bool = table.is_overlay_renderable(
		CommandoWeaponAnchorTable.ANIMATION_IDLE_BACK,
		0,
		CommandoWeaponAnchorTable.WEAPON_AK47
	)
	_expect(
		renderable == true,
		"is_overlay_renderable must be true for configured idle_back + AK-47"
	)
	var walk_back_renderable: bool = table.is_overlay_renderable(
		CommandoWeaponAnchorTable.ANIMATION_WALK_BACK,
		0,
		CommandoWeaponAnchorTable.WEAPON_AK47
	)
	_expect(walk_back_renderable == false, "walk_back must remain non-renderable until anchors land")


func _verify_animation_state_constants_match_renderer_branches() -> void:
	# Lock the four animation state ids so a future rename in the renderer
	# does not silently desync the anchor table. The renderer branches on
	# (player_move_active, direction) which maps to these four states.
	_expect(CommandoWeaponAnchorTable.ANIMATION_IDLE_BACK == "idle_back", "idle_back state id changed")
	_expect(CommandoWeaponAnchorTable.ANIMATION_WALK_BACK == "walk_back", "walk_back state id changed")
	_expect(CommandoWeaponAnchorTable.ANIMATION_WALK_LEFT == "walk_left", "walk_left state id changed")
	_expect(CommandoWeaponAnchorTable.ANIMATION_WALK_RIGHT == "walk_right", "walk_right state id changed")


func _verify_weapon_id_constants_match_controller_keys() -> void:
	# Lock the six weapon ids so they stay in sync with
	# `commando_weapon_controller.WEAPON_DATA`. If a controller key is
	# renamed, the anchor table must follow or runtime will silently
	# fail to find the pivot for the equipped weapon.
	_expect(CommandoWeaponAnchorTable.WEAPON_PISTOL == "pistol", "pistol weapon id changed")
	_expect(CommandoWeaponAnchorTable.WEAPON_AK47 == "ak47", "ak47 weapon id changed")
	_expect(CommandoWeaponAnchorTable.WEAPON_BAZOOKA == "bazooka", "bazooka weapon id changed")
	_expect(CommandoWeaponAnchorTable.WEAPON_NET_GUN == "net_gun", "net_gun weapon id changed")
	_expect(CommandoWeaponAnchorTable.WEAPON_BOWLING_TRAP == "bowling_trap", "bowling_trap weapon id changed")
	_expect(CommandoWeaponAnchorTable.WEAPON_SUICIDE_DRONE == "suicide_drone", "suicide_drone weapon id changed")


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
