extends SceneTree

const LingpetRuntimeVectorResolver := preload("res://scripts/lingpet/lingpet_runtime_vector_resolver.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var player_pos := Vector2(100.0, 600.0)
	var player_paddle_width := 160.0
	var player_paddle_height := 40.0


func _init() -> void:
	_verify_vector2_fallback()
	_verify_owner_player_paddle_center()
	_verify_starlight_delivery_uses_context_or_owner_paddle_center()
	_verify_runtime_delegates_vector_resolution()

	if _failures.is_empty():
		print("lingpet_runtime_vector_resolver_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_vector2_fallback() -> void:
	var resolver := LingpetRuntimeVectorResolver.new()
	_expect_vector2(resolver.vector2_or_fallback(Vector2(2.0, 3.0), Vector2(9.0, 9.0)), Vector2(2.0, 3.0), "Vector2 value should pass through")
	_expect_vector2(resolver.vector2_or_fallback("not-a-vector", Vector2(9.0, 8.0)), Vector2(9.0, 8.0), "non-Vector2 value should use fallback")


func _verify_owner_player_paddle_center() -> void:
	var resolver := LingpetRuntimeVectorResolver.new()
	var owner := FakeOwner.new()
	_expect_vector2(
		resolver.get_owner_player_paddle_center(owner),
		Vector2(180.0, 620.0),
		"owner paddle center should combine player_pos and paddle size"
	)
	_expect_vector2(
		resolver.get_owner_player_paddle_center(null, Vector2(12.0, 34.0)),
		Vector2(12.0, 34.0),
		"missing owner should use the caller fallback for owner-targeted VFX"
	)
	owner.player_paddle_width = -9.0
	owner.player_paddle_height = 0.0
	_expect_vector2(
		resolver.get_owner_player_paddle_center(owner),
		Vector2(100.5, 600.5),
		"owner paddle center should clamp invalid paddle sizes to one pixel"
	)


func _verify_starlight_delivery_uses_context_or_owner_paddle_center() -> void:
	var resolver := LingpetRuntimeVectorResolver.new()
	var owner := FakeOwner.new()
	_expect_vector2(
		resolver.get_starlight_tracking_delivery_pos({"owner": owner}),
		Vector2(180.0, 620.0),
		"owner-backed delivery should target the player paddle center"
	)
	_expect_vector2(
		resolver.get_starlight_tracking_delivery_pos({
			"owner": owner,
			"player_pos": Vector2(10.0, 20.0),
			"player_paddle_size": Vector2(30.0, 50.0),
		}),
		Vector2(25.0, 45.0),
		"context player pos/size should override owner-backed defaults"
	)
	_expect_vector2(
		resolver.get_starlight_tracking_delivery_pos({}),
		Vector2(77.5, 25.0),
		"missing owner/context should fall back to the historical default paddle center"
	)


func _verify_runtime_delegates_vector_resolution() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var owner_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_runtime_vector_resolver.gd")
	var applier_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_save_restore_applier.gd")
	_expect(runtime_source.find("LingpetRuntimeVectorResolver") >= 0, "egg runtime should preload the runtime vector resolver")
	_expect(runtime_source.find("_vector_resolver.vector2_or_fallback") >= 0, "runtime position override coercion should use the vector resolver directly")
	_expect(runtime_source.find("func _get_vector2_from_variant") < 0, "runtime should not keep the old private Vector2 coercion wrapper")
	_expect(applier_source.find("LingpetRuntimeVectorResolver") >= 0, "save-restore applier should use the vector resolver for companion position restore")
	_expect(runtime_source.find("_vector_resolver.get_starlight_tracking_delivery_pos") >= 0, "runtime Starlight delivery should use the vector resolver directly")
	_expect(runtime_source.find("func _get_starlight_tracking_delivery_pos") < 0, "runtime should not keep the old private Starlight delivery wrapper")
	_expect(runtime_source.find("_vector_resolver.get_owner_player_paddle_center") >= 0, "runtime item-egg absorb target should use the vector resolver directly")
	_expect(runtime_source.find("func _get_item_egg_absorb_target") < 0, "runtime should not keep a single-use item-egg absorb-target wrapper")
	_expect(owner_source.find("DEFAULT_PLAYER_PADDLE_SIZE") >= 0, "vector resolver should own the default player paddle size")
	_expect(owner_source.find("BattleSceneOwnerReader.get_value") >= 0, "vector resolver should own owner-backed paddle value reads")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_vector2(actual: Vector2, expected: Vector2, message: String, tolerance: float = 0.01) -> void:
	if actual.distance_to(expected) > tolerance:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
