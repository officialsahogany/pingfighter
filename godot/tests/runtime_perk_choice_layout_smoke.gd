extends SceneTree

const RuntimePerkChoiceLayout := preload("res://scripts/characters/runtime_perk_choice_layout.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

var _failures: Array[String] = []


class FakeRuntimeState:
	var particles: Array = []
	var current_choices: Array = []
	var animation_time := 0.0


func _init() -> void:
	_verify_card_hit_index_helper()
	_verify_particle_state_application_helper()
	_verify_runtime_state_particle_delegation()

	if _failures.is_empty():
		print("runtime_perk_choice_layout_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_card_hit_index_helper() -> void:
	var helper := RuntimePerkChoiceLayout.new()
	var view_size := Vector2(1280.0, 900.0)
	var rects: Array = helper.get_card_rects(view_size, 3, 0.5)
	_expect(rects.size() == 3, "choice layout helper should build one rect per choice")
	_expect(
		helper.get_card_index_at(_get_rect2(rects[1]).get_center(), view_size, 3, 0.5) == 1,
		"choice layout helper should resolve the hovered card index"
	)
	_expect(
		helper.get_card_index_at(Vector2(-200.0, -200.0), view_size, 3, 0.5) == -1,
		"choice layout helper should reject positions outside all cards"
	)
	var viewport_rect := Rect2(Vector2.ZERO, view_size)
	for choice_count: int in [3, 4, 5]:
		var count_rects: Array = helper.get_card_rects(view_size, choice_count, 0.5)
		_expect(count_rects.size() == choice_count, "%d-card auxiliary layout should preserve every choice" % choice_count)
		for index: int in range(count_rects.size()):
			var card_rect := _get_rect2(count_rects[index])
			_expect(viewport_rect.encloses(card_rect), "%d-card layout should stay inside the viewport" % choice_count)
			if index > 0:
				_expect(not card_rect.intersects(_get_rect2(count_rects[index - 1])), "%d-card layout should not overlap adjacent cards" % choice_count)

	var state := FakeRuntimeState.new()
	state.current_choices = [{"id": "a"}, {"id": "b"}, {"id": "c"}]
	state.animation_time = 0.5
	var state_layout: Dictionary = helper.build_layout_from_runtime_state(state, view_size)
	var state_rects: Array = helper.get_card_rects_from_runtime_state(state, view_size)
	_expect(_get_vector2(state_layout.get("card_size", Vector2.ZERO)).x > 0.0, "runtime-state layout facade should build card geometry")
	_expect(state_rects.size() == 3, "runtime-state rect facade should read current choice count")
	_expect(
		helper.get_card_index_at_from_runtime_state(state, _get_rect2(state_rects[1]).get_center(), view_size) == 1,
		"runtime-state hit facade should resolve hovered card index"
	)
	_expect(helper.get_card_rects_from_runtime_state(null, view_size).is_empty(), "runtime-state rect facade should reject missing state")
	_expect(helper.get_card_index_at_from_runtime_state(null, Vector2.ZERO, view_size) == -1, "runtime-state hit facade should reject missing state")


func _verify_particle_state_application_helper() -> void:
	var helper := RuntimePerkChoiceLayout.new()
	var state := FakeRuntimeState.new()
	var built_particles: Array = helper.build_particles(3)
	_expect(built_particles.size() == 3, "choice layout helper should build the requested particle placeholders")

	var apply_result: Dictionary = helper.apply_particles_state_update(state, built_particles)
	_expect(bool(apply_result.get("accepted", false)), "choice layout helper should apply particle state")
	_expect(int(apply_result.get("particle_count", -1)) == 3, "choice layout helper should report applied particle count")
	_expect(state.particles.size() == 3, "choice layout helper should write particles to runtime state")
	built_particles[0]["mutated_after_apply"] = true
	_expect(not bool(_get_dict(state.particles[0]).get("mutated_after_apply", false)), "choice layout helper should deep-copy particle state")
	_expect(not bool(helper.apply_particles_state_update(null, built_particles).get("accepted", true)), "choice layout helper should reject null state")

	state.particles.clear()
	var rebuild_result: Dictionary = helper.rebuild_particles_from_runtime_state(state, 4)
	_expect(bool(rebuild_result.get("accepted", false)), "choice layout helper should rebuild particles through runtime-state facade")
	_expect(int(rebuild_result.get("particle_count", -1)) == 4, "choice layout runtime-state facade should report rebuilt particle count")
	_expect(state.particles.size() == 4, "choice layout runtime-state facade should write rebuilt particles")
	_expect(not bool(helper.rebuild_particles_from_runtime_state(null, 4).get("accepted", true)), "choice layout runtime-state facade should reject null state")


func _verify_runtime_state_particle_delegation() -> void:
	var state := RuntimePerkState.new()
	state._build_particles()
	_expect(state.particles.size() == RuntimePerkState.PARTICLE_COUNT, "runtime state should build modal particles through layout helper")

	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var card_index_body: String = _function_body(state_source, "func _get_card_index_at(")
	var card_rects_body: String = _function_body(state_source, "func get_card_rects(")
	var layout_body: String = _function_body(state_source, "func build_layout(")
	var particles_body: String = _function_body(state_source, "func _build_particles(")
	_expect(state_source.find("_choice_layout.get_card_index_at_from_runtime_state") >= 0, "runtime state should delegate runtime-state card hit-index lookup")
	_expect(state_source.find("_choice_layout.get_card_rects_from_runtime_state") >= 0, "runtime state should delegate runtime-state card rect lookup")
	_expect(state_source.find("_choice_layout.build_layout_from_runtime_state") >= 0, "runtime state should delegate runtime-state layout build")
	_expect(state_source.find("_choice_layout.rebuild_particles_from_runtime_state") >= 0, "runtime state should delegate runtime-state particle rebuild")
	_expect(card_index_body.find("for index in range") < 0, "runtime state should not inline card hit-index scanning")
	_expect(card_index_body.find("current_choices.size()") < 0, "runtime state card hit-index wrapper should not read choice count inline")
	_expect(card_index_body.find("animation_time") < 0, "runtime state card hit-index wrapper should not read animation time inline")
	_expect(card_rects_body.find("current_choices.size()") < 0, "runtime state card rect wrapper should not read choice count inline")
	_expect(card_rects_body.find("animation_time") < 0, "runtime state card rect wrapper should not read animation time inline")
	_expect(layout_body.find("current_choices.size()") < 0, "runtime state layout wrapper should not read choice count inline")
	_expect(particles_body.find("_choice_layout.apply_particles_state_update") < 0, "runtime state should not apply particle fields inline")
	_expect(particles_body.find("_choice_layout.build_particles") < 0, "runtime state should not build particle arrays inline")
	_expect(state_source.find("particles = _choice_layout.build_particles") < 0, "runtime state should not assign particle arrays inline")


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\n\nfunc ", start + signature.length())
	if next < 0:
		next = source.length()
	return source.substr(start, next - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _get_rect2(value: Variant) -> Rect2:
	if value is Rect2:
		return value
	return Rect2()


func _get_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO
