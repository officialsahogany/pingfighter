extends SceneTree

const LingpetGuardHitTagResolver := preload("res://scripts/lingpet/lingpet_guard_hit_tag_resolver.gd")

var _failures: Array[String] = []


class FakeMotionState:
	extends RefCounted

	var defense_intercept_active := false


class FakeRingDashState:
	extends RefCounted

	var position_override_active := false

	func has_companion_position_override() -> bool:
		return position_override_active


func _init() -> void:
	_verify_capture_contract()
	_verify_merge_and_defense_contract()
	_verify_runtime_delegates_guard_hit_tags()

	if _failures.is_empty():
		print("lingpet_guard_hit_tag_resolver_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_capture_contract() -> void:
	var resolver := LingpetGuardHitTagResolver.new()
	var motion := FakeMotionState.new()
	var ring_dash := FakeRingDashState.new()

	var empty_tags := resolver.capture(motion, ring_dash)
	_expect(not bool(empty_tags.get("defense_intercept", false)), "inactive defense intercept should capture false")
	_expect(not bool(empty_tags.get("ring_dash_block", false)), "inactive ring dash block should capture false")
	_expect(not resolver.has_defense_tag(empty_tags), "empty tags should not count as a defense hit")

	motion.defense_intercept_active = true
	ring_dash.position_override_active = true
	var active_tags := resolver.capture(motion, ring_dash)
	_expect(bool(active_tags.get("defense_intercept", false)), "active defense intercept should capture true")
	_expect(bool(active_tags.get("ring_dash_block", false)), "active ring dash override should capture true")
	_expect(resolver.has_defense_tag(active_tags), "any defense-style tag should count as a defense hit")

	var null_tags := resolver.capture(null, null)
	_expect(not resolver.has_defense_tag(null_tags), "null state capture should stay safely inactive")


func _verify_merge_and_defense_contract() -> void:
	var resolver := LingpetGuardHitTagResolver.new()
	var defense_only := {
		"defense_intercept": true,
		"ring_dash_block": false,
	}
	var ring_dash_only := {
		"defense_intercept": false,
		"ring_dash_block": true,
	}
	var merged := resolver.merge(defense_only, ring_dash_only)
	_expect(bool(merged.get("defense_intercept", false)), "merge should preserve a defense intercept from either side")
	_expect(bool(merged.get("ring_dash_block", false)), "merge should preserve a ring-dash block from either side")
	_expect(resolver.has_defense_tag(merged), "merged defense-style tags should trigger defense feedback")

	var no_tags := resolver.merge({}, {})
	_expect(not bool(no_tags.get("defense_intercept", false)), "missing defense intercept should merge false")
	_expect(not bool(no_tags.get("ring_dash_block", false)), "missing ring-dash block should merge false")
	_expect(not resolver.has_defense_tag(no_tags), "missing tags should not trigger defense feedback")


func _verify_runtime_delegates_guard_hit_tags() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var resolver_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_guard_hit_tag_resolver.gd")
	_expect(runtime_source.find("LingpetGuardHitTagResolver") >= 0, "egg runtime should preload the guard hit-tag resolver")
	_expect(runtime_source.find("_guard_hit_tag_resolver.capture") >= 0, "runtime capture wrapper should delegate")
	_expect(runtime_source.find("_guard_hit_tag_resolver.merge") >= 0, "runtime merge wrapper should delegate")
	_expect(runtime_source.find("_guard_hit_tag_resolver.has_defense_tag") >= 0, "runtime defense-tag wrapper should delegate")
	_expect(resolver_source.find("TAG_DEFENSE_INTERCEPT") >= 0 and resolver_source.find("TAG_RING_DASH_BLOCK") >= 0, "resolver should own the guard hit-tag keys")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
