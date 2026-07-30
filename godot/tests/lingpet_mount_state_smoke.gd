extends SceneTree

# 수호령 탑승 (socket composition lane C pilot) seal: proximity + right-click
# mount toggle, overdrive-chord reservation, lane-Y-keeping follow, forced
# dismount paths, and the rider-lift draw-context chain.

const LingpetMountState := preload("res://scripts/lingpet/lingpet_mount_state.gd")
const BattleDrawContext := preload("res://scripts/core/battle_draw_context.gd")
const LingpetCompanionDrawContextBuilder := preload("res://scripts/lingpet/lingpet_companion_draw_context_builder.gd")

var _failures: Array[String] = []


class FakeInputProbe extends RefCounted:
	var rmb := false
	var down := false

	func is_rmb_pressed() -> bool:
		return rmb

	func is_down_pressed() -> bool:
		return down


class FakeOwner extends RefCounted:
	# DECLARED owner keys only. `player_paddle_size` is NOT in
	# BattleSceneState.DEFAULT_VALUES, and the old fixture offered it -- which
	# masked the schema miss this seal now catches.
	var player_pos := Vector2(300.0, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0


class FakeLingpetRuntime extends RefCounted:
	var lift := 34.0

	func get_mount_rider_lift_px() -> float:
		return lift


class FakeRegistry extends RefCounted:
	var instances: Dictionary = {}

	func get_cached_instance(name: String) -> Object:
		return instances.get(name, null)

	func get_instance(name: String) -> Object:
		return instances.get(name, null)


func _init() -> void:
	_verify_proximity_rmb_mounts()
	_verify_held_rmb_is_edge_not_level()
	_verify_far_click_does_not_mount()
	_verify_overdrive_chord_is_reserved()
	_verify_rmb_dismounts()
	_verify_position_override_keeps_lane_y()
	_verify_expanded_paddle_uses_declared_width_key()
	_verify_unsupported_pet_and_pet_switch_dismount()
	_verify_inactive_companion_forces_dismount()
	_verify_reset_clears_mount()
	_verify_rider_lift_values()
	_verify_scene_context_lift_chain()
	_verify_mounted_carry_sheet_swap()

	if _failures.is_empty():
		print("lingpet_mount_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _make_state(probe: FakeInputProbe) -> Object:
	var state: Object = LingpetMountState.new()
	state.set_pet_id("onimaru")
	state.set_input_probe(probe)
	return state


func _player_center(owner: FakeOwner) -> float:
	return owner.player_pos.x + owner.player_paddle_width * 0.5


func _verify_expanded_paddle_uses_declared_width_key() -> void:
	var probe := FakeInputProbe.new()
	var owner := FakeOwner.new()
	# NON-DEFAULT width: the anchor read the undeclared `player_paddle_size` and
	# always resolved to 155, parking the anchor 32.5px left of the real center.
	owner.player_paddle_width = 220.0
	var state := _make_state(probe)
	var center: float = _player_center(owner)
	_expect(is_equal_approx(center, 410.0), "fixture sanity: expanded paddle center should be 410")
	# 70px from the TRUE center is inside the 78px window, but 102.5px from the
	# stale 155-based anchor -- so a schema miss cannot mount here.
	var near_pos := Vector2(center + 70.0, 655.0)
	probe.rmb = true
	var result: Dictionary = state.advance(owner, near_pos, true)
	_expect(bool(result.get("mounted", false)), "expanded paddle must mount from the TRUE visual center (declared width key)")
	var follow: Vector2 = state.get_companion_position_override(owner, near_pos)
	_expect(is_equal_approx(follow.x, center), "mounted follow must anchor to the expanded center, not the 155 fallback")


func _verify_proximity_rmb_mounts() -> void:
	var probe := FakeInputProbe.new()
	var owner := FakeOwner.new()
	var state := _make_state(probe)
	var near_pos := Vector2(_player_center(owner) + 40.0, 660.0)
	probe.rmb = true
	var result: Dictionary = state.advance(owner, near_pos, true)
	_expect(bool(result.get("mounted", false)) and bool(result.get("toggled", false)), "near right-click should mount")


func _verify_held_rmb_is_edge_not_level() -> void:
	var probe := FakeInputProbe.new()
	var owner := FakeOwner.new()
	var state := _make_state(probe)
	var near_pos := Vector2(_player_center(owner), 660.0)
	probe.rmb = true
	state.advance(owner, near_pos, true)
	var held: Dictionary = state.advance(owner, near_pos, true)
	_expect(bool(held.get("mounted", false)) and not bool(held.get("toggled", false)), "held right-click must not re-toggle (edge, not level)")


func _verify_far_click_does_not_mount() -> void:
	var probe := FakeInputProbe.new()
	var owner := FakeOwner.new()
	var state := _make_state(probe)
	var far_pos := Vector2(_player_center(owner) + 200.0, 660.0)
	probe.rmb = true
	var result: Dictionary = state.advance(owner, far_pos, true)
	_expect(not bool(result.get("mounted", false)), "right-click far from the companion should not mount")


func _verify_overdrive_chord_is_reserved() -> void:
	var probe := FakeInputProbe.new()
	var owner := FakeOwner.new()
	var state := _make_state(probe)
	var near_pos := Vector2(_player_center(owner), 660.0)
	probe.rmb = true
	probe.down = true
	var result: Dictionary = state.advance(owner, near_pos, true)
	_expect(not bool(result.get("mounted", false)), "S+right-click (Smasher Overdrive chord) must never mount")


func _verify_rmb_dismounts() -> void:
	var probe := FakeInputProbe.new()
	var owner := FakeOwner.new()
	var state := _make_state(probe)
	var near_pos := Vector2(_player_center(owner), 660.0)
	probe.rmb = true
	state.advance(owner, near_pos, true)
	probe.rmb = false
	state.advance(owner, near_pos, true)
	probe.rmb = true
	var result: Dictionary = state.advance(owner, near_pos, true)
	_expect(not bool(result.get("mounted", true)) and bool(result.get("toggled", false)), "right-click while mounted should dismount")


func _verify_position_override_keeps_lane_y() -> void:
	var probe := FakeInputProbe.new()
	var owner := FakeOwner.new()
	var state := _make_state(probe)
	# Non-base lane Y so a Y-copy bug cannot hide (teleport locomotion trap).
	var pet_pos := Vector2(_player_center(owner) + 30.0, 641.5)
	probe.rmb = true
	state.advance(owner, pet_pos, true)
	_expect(bool(state.has_companion_position_override()), "mounted state should own a companion position override")
	owner.player_pos.x = 520.0
	# X-follow SNAPS to the rider: any follow inertia visibly separates the
	# pair at move speed (the rider is glued to the physics paddle).
	var follow: Vector2 = state.get_companion_position_override(owner, pet_pos)
	_expect(is_equal_approx(follow.x, _player_center(owner)), "mounted companion X must snap to the player center (no separating inertia)")
	_expect(is_equal_approx(follow.y, 641.5), "mounted ground pet must KEEP its lane Y (X changes only)")


func _verify_unsupported_pet_and_pet_switch_dismount() -> void:
	var probe := FakeInputProbe.new()
	var owner := FakeOwner.new()
	var unsupported: Object = LingpetMountState.new()
	unsupported.set_pet_id("maribo")
	unsupported.set_input_probe(probe)
	probe.rmb = true
	var result: Dictionary = unsupported.advance(owner, Vector2(_player_center(owner), 660.0), true)
	_expect(not bool(result.get("mounted", false)), "unsupported pet should never mount")

	var state := _make_state(probe)
	probe.rmb = false
	state.advance(owner, Vector2(_player_center(owner), 660.0), true)
	probe.rmb = true
	state.advance(owner, Vector2(_player_center(owner), 660.0), true)
	state.set_pet_id("maribo")
	_expect(not bool(state.is_mounted()), "switching to an unsupported pet should force a dismount")


func _verify_inactive_companion_forces_dismount() -> void:
	var probe := FakeInputProbe.new()
	var owner := FakeOwner.new()
	var state := _make_state(probe)
	probe.rmb = true
	state.advance(owner, Vector2(_player_center(owner), 660.0), true)
	probe.rmb = false
	var result: Dictionary = state.advance(owner, Vector2(_player_center(owner), 660.0), false)
	_expect(not bool(result.get("mounted", true)) and bool(result.get("toggled", false)), "inactive companion (skill override / despawn) should force a dismount")


func _verify_reset_clears_mount() -> void:
	var probe := FakeInputProbe.new()
	var owner := FakeOwner.new()
	var state := _make_state(probe)
	probe.rmb = true
	state.advance(owner, Vector2(_player_center(owner), 660.0), true)
	state.reset()
	_expect(not bool(state.is_mounted()), "reset() must clear the mount (round-boundary leak trap)")


func _verify_rider_lift_values() -> void:
	var probe := FakeInputProbe.new()
	var owner := FakeOwner.new()
	var state := _make_state(probe)
	_expect(float(state.get_rider_lift_px()) == 0.0, "unmounted rider lift should be 0")
	probe.rmb = true
	state.advance(owner, Vector2(_player_center(owner), 660.0), true)
	var lift_at_mount: float = float(state.get_rider_lift_px())
	state.advance(owner, Vector2(_player_center(owner), 660.0), true, false, 0.5)
	var lift_settled: float = float(state.get_rider_lift_px())
	_expect(lift_settled > 0.0, "mounted rider lift should be positive after the hop progresses")
	_expect(lift_settled > lift_at_mount, "hop-on should animate the lift upward over time, not snap")


func _verify_scene_context_lift_chain() -> void:
	var builder := BattleDrawContext.new()
	var registry := FakeRegistry.new()
	registry.instances["lingpet_egg_runtime"] = FakeLingpetRuntime.new()
	var scene_context: Dictionary = builder.build_scene_context(FakeOwner.new(), Vector2.ZERO, registry)
	_expect(is_equal_approx(float(scene_context.get("player_mount_rider_lift_px", -1.0)), 34.0), "scene context should read the rider lift from the cached lingpet runtime")
	var actor_context: Dictionary = builder.build_actor_context({
		"selected_character_type": "smasher",
		"player_mount_rider_lift_px": 34.0,
	}, {})
	_expect(is_equal_approx(float(actor_context.get("player_mount_rider_lift_px", -1.0)), 34.0), "actor context should pass the rider lift through to stage renderers")

	var bare_context: Dictionary = builder.build_scene_context(FakeOwner.new(), Vector2.ZERO, FakeRegistry.new())
	_expect(float(bare_context.get("player_mount_rider_lift_px", -1.0)) == 0.0, "missing lingpet runtime should resolve to zero lift (fail-closed)")


class FakeProfile extends RefCounted:
	var carry_texture: Texture2D = null
	var body_texture: Texture2D = null

	func get_visual_texture(visual_key: String, _fallback: Variant = null) -> Texture2D:
		if visual_key == "companion_carry":
			return carry_texture
		if visual_key in ["companion_idle", "companion_move_left", "companion_move_right", "companion_walk"]:
			return body_texture
		return null


func _verify_mounted_carry_sheet_swap() -> void:
	var builder: Object = LingpetCompanionDrawContextBuilder.new()
	var carry := _make_texture()
	var body := _make_texture()
	var profile := FakeProfile.new()
	profile.carry_texture = carry
	profile.body_texture = body

	var mounted: Dictionary = builder.build_config({"current_profile": profile, "mount_carry_active": true})
	for key in ["idle_texture", "move_left_texture", "move_right_texture", "walk_texture"]:
		_expect(mounted.get(key, null) == carry, "mounted %s should swap to the shoulder-carry sheet" % key)

	var unmounted: Dictionary = builder.build_config({"current_profile": profile, "mount_carry_active": false})
	_expect(unmounted.get("idle_texture", null) == body, "unmounted companion should keep its normal body sheets")

	var no_carry := FakeProfile.new()
	no_carry.body_texture = body
	var fallback: Dictionary = builder.build_config({"current_profile": no_carry, "mount_carry_active": true})
	_expect(fallback.get("idle_texture", null) == body, "pets without an authored carry sheet should keep normal sheets (fail-closed)")


func _make_texture() -> Texture2D:
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
