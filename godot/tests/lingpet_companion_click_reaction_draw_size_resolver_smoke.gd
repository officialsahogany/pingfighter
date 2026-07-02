extends SceneTree

const LingpetCompanionClickReactionDrawSizeResolver := preload("res://scripts/lingpet/lingpet_companion_click_reaction_draw_size_resolver.gd")

var _failures: Array[String] = []


class FakeProfile:
	extends RefCounted

	var values: Dictionary = {}

	func _init(initial_values: Dictionary = {}) -> void:
		values = initial_values.duplicate(true)

	func get_visual_layout_value(key: String, fallback: Variant = 0.0) -> Variant:
		return values.get(key, fallback)


func _init() -> void:
	_verify_draw_size_resolution_order()
	_verify_runtime_delegates_click_reaction_draw_size_resolver()

	if _failures.is_empty():
		print("lingpet_companion_click_reaction_draw_size_resolver_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_draw_size_resolution_order() -> void:
	var resolver := LingpetCompanionClickReactionDrawSizeResolver.new()
	_expect_vector2(
		resolver.resolve(FakeProfile.new({"click_reaction_draw_size": 83.2, "companion_walk_draw_size": 104.0}), 98.0),
		Vector2(83.2, 83.2),
		"click-reaction draw size override should win over companion walk size"
	)
	_expect_vector2(
		resolver.resolve(FakeProfile.new({"companion_walk_draw_size": 104.0}), 98.0),
		Vector2(104.0, 104.0),
		"companion walk draw size should be the secondary fallback"
	)
	_expect_vector2(
		resolver.resolve(FakeProfile.new({"click_reaction_draw_size": -1.0, "companion_walk_draw_size": 0.0}), 98.0),
		Vector2(98.0, 98.0),
		"non-positive configured sizes should fall back to sprite default"
	)
	_expect_vector2(
		resolver.resolve(null, 98.0),
		Vector2(98.0, 98.0),
		"missing profile should fall back to sprite default"
	)


func _verify_runtime_delegates_click_reaction_draw_size_resolver() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var resolver_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_click_reaction_draw_size_resolver.gd")
	_expect(runtime_source.find("LingpetCompanionClickReactionDrawSizeResolver") >= 0, "egg runtime should preload the click-reaction draw-size resolver")
	_expect(runtime_source.find("func _get_companion_click_reaction_draw_size") < 0, "runtime should not reintroduce the single-use click-reaction draw-size wrapper")
	_expect(runtime_source.find("_companion_click_reaction_draw_size_resolver.resolve") >= 0, "runtime draw path should call the draw-size resolver directly")
	_expect(resolver_source.find("CLICK_REACTION_DRAW_SIZE_KEY") >= 0 and resolver_source.find("click_reaction_draw_size") >= 0, "resolver should own the click-reaction draw-size key")
	_expect(resolver_source.find("COMPANION_WALK_DRAW_SIZE_KEY") >= 0 and resolver_source.find("companion_walk_draw_size") >= 0, "resolver should own the companion walk-size fallback key")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_vector2(actual: Vector2, expected: Vector2, message: String, tolerance: float = 0.01) -> void:
	if actual.distance_to(expected) > tolerance:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
