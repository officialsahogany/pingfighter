extends SceneTree

const SkillOrbTooltipHoverState := preload("res://scripts/hud/skill_orb_tooltip_hover_state.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var selected_character_type := "soldier"
	var current_stage := 1

	func get_viewport_rect() -> Rect2:
		return Rect2(Vector2.ZERO, Vector2(760.0, 750.0))


class FakeRegistry:
	extends RefCounted

	var requested_keys: Array[String] = []
	var cached_keys: Array[String] = []

	func get_instance(key: String) -> Object:
		requested_keys.append(key)
		return null

	func get_cached_instance(key: String) -> Object:
		cached_keys.append(key)
		return null


func _init() -> void:
	var hover_state := SkillOrbTooltipHoverState.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var result: Dictionary = hover_state.update_hover_state(owner, registry)
	_expect(result.is_empty(), "invalid mouse position should produce no hover result")
	_expect(not registry.requested_keys.has("smasher_skill_orb_tooltip_renderer"), "physics hover should not lazy-create the full tooltip renderer")
	_expect(not registry.requested_keys.has("battle_draw_context"), "physics hover should not build the pillar draw context")

	if _failures.is_empty():
		print("skill_orb_tooltip_hover_state_perf_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
