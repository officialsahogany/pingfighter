extends SceneTree

const LingpetCompanionBodyPresenceResolver := preload("res://scripts/lingpet/lingpet_companion_body_presence_resolver.gd")

var _failures: Array[String] = []


class FakeMotionState:
	extends RefCounted

	var motion_visible := false


class FakeRingDashState:
	extends RefCounted

	var hidden := false

	func is_companion_visual_hidden() -> bool:
		return hidden


func _init() -> void:
	_verify_hit_availability_priority()
	_verify_draw_visibility_priority()
	_verify_draw_motion_ratio_selection()
	_verify_click_reaction_availability()
	_verify_click_reaction_visibility()
	_verify_runtime_delegates_body_presence()

	if _failures.is_empty():
		print("lingpet_companion_body_presence_resolver_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_hit_availability_priority() -> void:
	var resolver := LingpetCompanionBodyPresenceResolver.new()
	_expect(
		not resolver.is_available_for_hit(true, true, true, true, true),
		"ring dash hidden should suppress hit availability before other override sources"
	)
	_expect(
		resolver.is_available_for_hit(true, false, false, false, false),
		"visible ring dash override should keep the companion available for hits"
	)
	_expect(
		resolver.is_available_for_hit(false, false, true, false, false),
		"active skill position override should keep the companion available for hits"
	)
	_expect(
		resolver.is_available_for_hit(false, false, false, true, false),
		"starlight override should keep the companion available for hits"
	)
	_expect(
		not resolver.is_available_for_hit(false, false, false, false, false),
		"hidden idle companion should not be available for hits"
	)


func _verify_draw_visibility_priority() -> void:
	var resolver := LingpetCompanionBodyPresenceResolver.new()
	_expect(
		not resolver.is_visible_for_draw(true, true, true, true, true),
		"ring dash hidden should suppress draw visibility before all visible sources"
	)
	_expect(
		resolver.is_visible_for_draw(false, false, true, false, false),
		"active skill position override should keep the companion visible"
	)
	_expect(
		resolver.is_visible_for_draw(false, false, false, true, false),
		"ring dash override should keep the companion visible when not hidden"
	)
	_expect(
		resolver.is_visible_for_draw(false, true, false, false, false),
		"motion visibility should keep the companion visible"
	)
	_expect(
		not resolver.is_visible_for_draw(false, false, false, false, false),
		"no visible source should hide the companion"
	)


func _verify_draw_motion_ratio_selection() -> void:
	var resolver := LingpetCompanionBodyPresenceResolver.new()
	_expect_float(
		resolver.get_draw_motion_speed_ratio(true, false, false, true, "patrol", 0.9, 0.25, 0.12),
		0.25,
		"active skill override should use real override movement"
	)
	_expect_float(
		resolver.get_draw_motion_speed_ratio(false, true, false, true, "patrol", 0.9, 0.25, 0.12),
		0.0,
		"ring dash override should freeze the walk cadence"
	)
	_expect_float(
		resolver.get_draw_motion_speed_ratio(false, false, true, true, "patrol", 0.9, 0.25, 0.12),
		0.25,
		"starlight override should use real horizontal movement"
	)
	_expect_float(
		resolver.get_draw_motion_speed_ratio(false, false, false, false, "patrol", 0.9, 0.25, 0.12),
		0.0,
		"hidden companion should freeze draw motion"
	)
	_expect_float(
		resolver.get_draw_motion_speed_ratio(false, false, false, true, "sortie_flight", 0.02, 0.0, 0.12),
		0.12,
		"sortie-flight companions should keep a minimum hover flap cadence"
	)
	_expect_float(
		resolver.get_draw_motion_speed_ratio(false, false, false, true, "patrol", 0.9, 0.25, 0.12),
		0.25,
		"ground patrol should use actual drawn movement instead of intended speed"
	)


func _verify_click_reaction_availability() -> void:
	var resolver := LingpetCompanionBodyPresenceResolver.new()
	var motion := FakeMotionState.new()
	var ring_dash := FakeRingDashState.new()

	motion.motion_visible = true
	ring_dash.hidden = false
	_expect(resolver.can_begin_click_reaction(motion, ring_dash), "visible non-hidden companion should accept click reaction")

	motion.motion_visible = false
	_expect(not resolver.can_begin_click_reaction(motion, ring_dash), "motion-hidden companion should reject click reaction")

	motion.motion_visible = true
	ring_dash.hidden = true
	_expect(not resolver.can_begin_click_reaction(motion, ring_dash), "ring-dash hidden companion should reject click reaction")

	_expect(not resolver.can_begin_click_reaction(null, ring_dash), "null motion state should reject click reaction")
	_expect(resolver.can_begin_click_reaction(motion, null), "null ring-dash state should not suppress visible click reaction")


func _verify_click_reaction_visibility() -> void:
	var resolver := LingpetCompanionBodyPresenceResolver.new()
	var ring_dash := FakeRingDashState.new()
	var texture := RefCounted.new()

	_expect(resolver.is_click_reaction_visible(true, texture, ring_dash), "active ready click reaction should be visible")
	_expect(not resolver.is_click_reaction_visible(false, texture, ring_dash), "inactive click reaction should not be visible")
	_expect(not resolver.is_click_reaction_visible(true, null, ring_dash), "click reaction without a ready texture should not be visible")

	ring_dash.hidden = true
	_expect(not resolver.is_click_reaction_visible(true, texture, ring_dash), "ring-dash hidden companion should hide click reaction")


func _verify_runtime_delegates_body_presence() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var owner_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_body_presence_resolver.gd")
	_expect(runtime_source.find("LingpetCompanionBodyPresenceResolver") >= 0, "egg runtime should preload the companion body presence resolver")
	_expect(runtime_source.find("_companion_body_presence_resolver.is_available_for_hit") >= 0, "runtime hit availability wrapper should delegate to the resolver")
	_expect(runtime_source.find("_companion_body_presence_resolver.get_draw_motion_speed_ratio") >= 0, "runtime draw motion ratio wrapper should delegate to the resolver")
	_expect(runtime_source.find("_companion_body_presence_resolver.is_visible_for_draw") >= 0, "runtime draw visibility wrapper should delegate to the resolver")
	_expect(runtime_source.find("_companion_body_presence_resolver.can_begin_click_reaction") >= 0, "runtime click-reaction availability gate should delegate to the resolver")
	_expect(runtime_source.find("_companion_body_presence_resolver.is_click_reaction_visible") >= 0, "runtime click-reaction visibility gate should delegate to the resolver")
	_expect(owner_source.find("sortie_flight") >= 0, "presence resolver should own sortie-flight hover cadence selection")
	_expect(owner_source.find("ring_dash_visual_hidden") >= 0, "presence resolver should own ring-dash hidden priority")
	_expect(owner_source.find("func can_begin_click_reaction") >= 0, "presence resolver should own click-reaction availability gating")
	_expect(owner_source.find("func is_click_reaction_visible") >= 0, "presence resolver should own click-reaction visibility gating")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_float(actual: float, expected: float, message: String, tolerance: float = 0.01) -> void:
	if absf(actual - expected) > tolerance:
		_failures.append("%s (expected %.3f, got %.3f)" % [message, expected, actual])
