extends SceneTree

const Stage1PillarBackground := preload("res://scripts/stages/stage1/stage1_pillar_background.gd")
const Stage1PillarSceneDrawer := preload("res://scripts/stages/stage1/stage1_pillar_scene_drawer.gd")

var _failures: Array[String] = []


class FakeBallIntensity:
	extends RefCounted

	var display_intensity := 0.0
	var rally_tier := 0
	var theater_calls := 0

	func _init(new_display_intensity: float, new_rally_tier: int) -> void:
		display_intensity = new_display_intensity
		rally_tier = new_rally_tier

	func get_display_intensity() -> float:
		return display_intensity

	func get_rally_tier() -> int:
		return rally_tier

	func get_theater_intensity() -> float:
		theater_calls += 1
		return 1.0


class FakeRegistry:
	extends RefCounted

	var ball_intensity: Object = null
	var requested_keys: Array[String] = []

	func _init(new_ball_intensity: Object = null) -> void:
		ball_intensity = new_ball_intensity

	func get_instance(key: String) -> Object:
		requested_keys.append(key)
		if key == "ball_intensity":
			return ball_intensity
		return null


func _init() -> void:
	_verify_scene_drawer_builds_local_stage1_snapshot()
	_verify_background_crescendo_values_are_bounded_and_lod_scaled()
	_verify_missing_director_is_exact_noop_params()

	if _failures.is_empty():
		print("stage1_pillar_crescendo_director_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_scene_drawer_builds_local_stage1_snapshot() -> void:
	var drawer := Stage1PillarSceneDrawer.new()
	var intensity := FakeBallIntensity.new(1.4, 9)
	var registry := FakeRegistry.new(intensity)
	var snapshot: Dictionary = drawer._build_stage1_crescendo_snapshot(registry)
	_expect(registry.requested_keys == ["ball_intensity"], "Stage 1 crescendo snapshot should fetch only ball_intensity from registry")
	_expect(is_equal_approx(float(snapshot.get("display_intensity", -1.0)), 1.0), "display intensity should clamp to 0..1")
	_expect(int(snapshot.get("rally_tier", -1)) == 5, "rally tier should clamp to 0..5")
	_expect(intensity.theater_calls == 0, "Stage 1 pillar crescendo should not read theater/stakes intensity")

	var missing_snapshot: Dictionary = drawer._build_stage1_crescendo_snapshot(FakeRegistry.new())
	_expect(missing_snapshot.is_empty(), "missing ball_intensity should produce an empty no-op snapshot")


func _verify_background_crescendo_values_are_bounded_and_lod_scaled() -> void:
	var background := Stage1PillarBackground.new()
	var low_snapshot := {
		"display_intensity": 0.0,
		"rally_tier": 0,
	}
	var high_snapshot := {
		"display_intensity": 1.0,
		"rally_tier": 5,
	}
	var tier1_snapshot := {
		"display_intensity": 1.0,
		"rally_tier": 1,
	}
	var tier2_snapshot := {
		"display_intensity": 1.0,
		"rally_tier": 2,
	}

	_expect(is_equal_approx(background._get_crescendo_mood_alpha_boost(low_snapshot, 1.0), 0.0), "zero director values should not raise mood alpha")
	var high_mood: float = background._get_crescendo_mood_alpha_boost(high_snapshot, 1.0)
	_expect(high_mood > 0.0, "high director values should raise mood alpha")
	_expect(high_mood <= Stage1PillarBackground.CRESCENDO_MOOD_ALPHA_MAX, "mood alpha boost should stay within the agreed cap")
	_expect(
		background._get_crescendo_mood_alpha_boost(high_snapshot, 0.5) < high_mood,
		"quality_scale should reduce crescendo mood alpha"
	)

	_expect(is_equal_approx(background._get_crescendo_shine_alpha_multiplier(low_snapshot, 1.0), 1.0), "zero director values should keep shine alpha unchanged")
	var high_shine: float = background._get_crescendo_shine_alpha_multiplier(high_snapshot, 1.0)
	_expect(high_shine > 1.0, "high director values should raise shine alpha")
	_expect(high_shine <= 1.0 + Stage1PillarBackground.CRESCENDO_SHINE_ALPHA_BOOST_MAX, "shine alpha multiplier should stay bounded")

	_expect(is_equal_approx(background._get_crescendo_cloud_motion_multiplier(tier1_snapshot, 1.0), 1.0), "tier 1 should not activate cloud parallax boost")
	_expect(background._get_crescendo_cloud_motion_multiplier(tier2_snapshot, 1.0) > 1.0, "tier 2 should activate subtle cloud parallax boost")
	_expect(background._get_crescendo_tree_motion_offset(tier1_snapshot, 1.0, 1.0, 1.0) == Vector2.ZERO, "tier 1 should not activate tree parallax")
	_expect(background._get_crescendo_tree_motion_offset(tier2_snapshot, 1.0, 1.0, 1.0).length() <= Stage1PillarBackground.CRESCENDO_TREE_OFFSET_MAX_PIXELS, "tree parallax should stay tiny")


func _verify_missing_director_is_exact_noop_params() -> void:
	var background := Stage1PillarBackground.new()
	var empty_snapshot := {}
	_expect(is_equal_approx(background._get_crescendo_mood_alpha_boost(empty_snapshot, 1.0), 0.0), "empty snapshot should keep mood draw parameters unchanged")
	_expect(is_equal_approx(background._get_crescendo_shine_alpha_multiplier(empty_snapshot, 1.0), 1.0), "empty snapshot should keep shine draw parameters unchanged")
	_expect(is_equal_approx(background._get_crescendo_cloud_motion_multiplier(empty_snapshot, 1.0), 1.0), "empty snapshot should keep cloud motion parameters unchanged")
	_expect(background._get_crescendo_tree_motion_offset(empty_snapshot, 1.0, 1.0, 1.0) == Vector2.ZERO, "empty snapshot should keep tree offsets unchanged")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
