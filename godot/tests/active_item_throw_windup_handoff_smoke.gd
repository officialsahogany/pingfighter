extends SceneTree

const ActiveItemThrowRenderer := preload("res://scripts/items/active_item_throw_renderer.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_windup_preview_converges_to_launch_point()
	_verify_item_specific_launch_anchor_matches_live_spawn_offsets()
	_verify_windup_preview_still_animates_mid_windup()
	_verify_windup_preview_angle_hands_off_to_zero()

	if _failures.is_empty():
		print("active_item_throw_windup_handoff_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


# Regression: the wind-up preview must end exactly at the launch point at
# release, because the live projectile spawns there. The old code lifted the
# preview and lerped it ~18% toward the target by release, so the projectile
# visibly "flew a bit then restarted from the hand" (a ~150px snap) on every
# throw item.
func _verify_windup_preview_converges_to_launch_point() -> void:
	var renderer: Object = ActiveItemThrowRenderer.new()
	var start_pos := Vector2(377.5, 715.0)

	var at_start: Vector2 = renderer._get_windup_preview_position(start_pos, 0.0)
	var at_release: Vector2 = renderer._get_windup_preview_position(start_pos, 1.0)

	_expect(at_start.is_equal_approx(start_pos), "wind-up preview should begin at the launch point (no pop-in)")
	_expect(at_release.is_equal_approx(start_pos), "wind-up preview should converge to the launch point at release (no hand-off snap)")
	# The bug also drifted x toward the target; the preview must never move
	# horizontally away from the launch point at any progress.
	for step in range(0, 21):
		var progress: float = float(step) / 20.0
		var pos: Vector2 = renderer._get_windup_preview_position(start_pos, progress)
		_expect(is_equal_approx(pos.x, start_pos.x), "wind-up preview should not drift horizontally at progress %.2f" % progress)


func _verify_item_specific_launch_anchor_matches_live_spawn_offsets() -> void:
	var renderer: Object = ActiveItemThrowRenderer.new()
	var pending_throw_center := Vector2(377.5, 725.0)
	var low_live_spawn := Vector2(377.5, 715.0)

	for item_name in ["banana", "dynamite", "soap"]:
		var anchor: Vector2 = renderer._get_windup_preview_launch_position(pending_throw_center, item_name)
		_expect(
			anchor.is_equal_approx(low_live_spawn),
			"%s wind-up preview anchor should match its +15y live spawn offset" % item_name
		)
		_expect(
			renderer._get_windup_preview_position(anchor, 1.0).is_equal_approx(low_live_spawn),
			"%s wind-up preview should hand off exactly at its live spawn point" % item_name
		)

	for item_name in ["grenade", "flare", "molotov", "tear_gas", "boomerang"]:
		var anchor: Vector2 = renderer._get_windup_preview_launch_position(pending_throw_center, item_name)
		_expect(
			anchor.is_equal_approx(pending_throw_center),
			"%s wind-up preview anchor should preserve the default +25y throw center" % item_name
		)


func _verify_windup_preview_still_animates_mid_windup() -> void:
	var renderer: Object = ActiveItemThrowRenderer.new()
	var start_pos := Vector2(377.5, 715.0)

	var mid: Vector2 = renderer._get_windup_preview_position(start_pos, 0.5)
	_expect(mid.y < start_pos.y - 5.0, "wind-up preview should still lift the item mid-windup (not a dead still frame)")


func _verify_windup_preview_angle_hands_off_to_zero() -> void:
	var renderer: Object = ActiveItemThrowRenderer.new()

	var angle_release: float = renderer._get_windup_preview_angle(1.0)
	var angle_mid: float = renderer._get_windup_preview_angle(0.5)
	_expect(is_equal_approx(angle_release, 0.0), "wind-up preview angle should return to 0 at release to match the live projectile")
	_expect(absf(angle_mid) > 5.0, "wind-up preview angle should still rotate mid-windup")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
