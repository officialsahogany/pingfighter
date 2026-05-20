extends SceneTree

const Stage4BrazierMonkEvent := preload("res://scripts/stages/stage4/stage4_brazier_monk_event.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_render_budgets()
	_verify_recent_start_helper()
	_verify_state_payload_stays_full_size()
	_verify_draw_paths_use_render_caps()
	_verify_sprite_flip_preserves_playfield_transform()

	if _failures.is_empty():
		print("stage4_brazier_monk_render_budget_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_render_budgets() -> void:
	_expect(Stage4BrazierMonkEvent.MONK_HIT_EFFECT_RENDER_LIMIT <= 24, "monk hit effects should cap decorative rendering")
	_expect(Stage4BrazierMonkEvent.MONK_DEATH_PARTICLE_RENDER_LIMIT <= 56, "monk death particles should cap decorative rendering")

	var event := Stage4BrazierMonkEvent.new()
	var status: Dictionary = event.get_asset_status()
	_expect(int(status.get("monk_hit_effect_render_limit", 0)) == Stage4BrazierMonkEvent.MONK_HIT_EFFECT_RENDER_LIMIT, "asset status should expose the hit-effect render cap")
	_expect(int(status.get("monk_death_particle_render_limit", 0)) == Stage4BrazierMonkEvent.MONK_DEATH_PARTICLE_RENDER_LIMIT, "asset status should expose the death-particle render cap")


func _verify_recent_start_helper() -> void:
	var event := Stage4BrazierMonkEvent.new()
	var values: Array = []
	for index in range(90):
		values.append(index)
	_expect(event._recent_start(values, 56) == 34, "recent-start helper should draw only the newest capped entries")
	_expect(event._recent_start(values, 100) == 0, "recent-start helper should draw from zero when under budget")
	_expect(event._recent_start(values, 0) == values.size(), "zero render budget should draw nothing")


func _verify_state_payload_stays_full_size() -> void:
	var event := Stage4BrazierMonkEvent.new()
	_expect(event.spawn_smoke_grenade_monks_from_brazier() == 5, "test setup should spawn all five smoke monks")
	event.explode_all_monks()
	var snapshot: Dictionary = event.get_debug_snapshot()
	var particle_count: int = int(snapshot.get("death_particle_count", 0))
	_expect(particle_count > Stage4BrazierMonkEvent.MONK_DEATH_PARTICLE_RENDER_LIMIT, "monk explosion state should remain larger than the render cap")
	var context: Dictionary = event.get_actor_draw_context()
	_expect(_as_array(context.get("stage4_monk_death_particles", [])).size() == particle_count, "actor draw context should keep the full logical particle payload")


func _verify_draw_paths_use_render_caps() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/stages/stage4/stage4_brazier_monk_event.gd")
	_expect(source != "", "Stage 4 brazier monk event source should be readable")
	_expect(
		_function_body(source, "func draw").find("_recent_start(hit_effects, MONK_HIT_EFFECT_RENDER_LIMIT)") >= 0,
		"monk hit-effect draw should cap decorative rendering"
	)
	_expect(
		_function_body(source, "func draw").find("_recent_start(death_particles, MONK_DEATH_PARTICLE_RENDER_LIMIT)") >= 0,
		"monk death-particle draw should cap decorative rendering"
	)


func _verify_sprite_flip_preserves_playfield_transform() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/stages/stage4/stage4_brazier_monk_event.gd")
	_expect(source != "", "Stage 4 brazier monk event source should be readable for transform hygiene")
	_expect(
		source.find("draw_set_transform") < 0,
		"Stage 4 monk sprite flip must not reset the transformed playfield canvas"
	)
	_expect(
		source.find("draw_polygon(points, colors, uvs, texture)") >= 0,
		"Stage 4 monk sprite flip should mirror by UVs inside the existing playfield transform"
	)


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next_func := source.find("\nfunc ", start + signature.length())
	if next_func < 0:
		return source.substr(start)
	return source.substr(start, next_func - start)


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
