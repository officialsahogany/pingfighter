extends SceneTree

const ViperSkillParticleDrawer := preload("res://scripts/characters/viper_skill_particle_drawer.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_hit_particle_lod_budgets()
	_verify_marshal_stack_forwards_lod()
	_verify_runtime_passes_draw_lod()

	if _failures.is_empty():
		print("viper_marshal_render_budget_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_hit_particle_lod_budgets() -> void:
	_expect(
		ViperSkillParticleDrawer.SEVERE_LOD_HIT_PARTICLE_DRAW_LIMIT <= 40,
		"marshal hit particles should keep a tight severe-LOD draw cap"
	)
	_expect(
		ViperSkillParticleDrawer.SEVERE_LOD_PHANTOM_HIT_PARTICLE_DRAW_LIMIT <= 52,
		"phantom marshal particles should keep a tight severe-LOD draw cap"
	)
	var source := FileAccess.get_file_as_string("res://scripts/characters/viper_skill_particle_drawer.gd")
	var body := _function_body(source, "func draw_hit_particle_list")
	_expect(body.find("effect_lod_scale: float = 1.0") >= 0, "hit-particle draw should accept effect LOD scale")
	_expect(body.find("var stride: int = _get_lod_particle_stride(effect_lod_scale)") >= 0, "hit-particle draw should use the shared LOD stride")
	_expect(body.find("SEVERE_LOD_PHANTOM_HIT_PARTICLE_DRAW_LIMIT if phantom else SEVERE_LOD_HIT_PARTICLE_DRAW_LIMIT") >= 0, "hit-particle draw should use separate marshal and phantom caps")
	_expect(body.find("if drawn_count >= draw_limit:") >= 0, "hit-particle draw should stop at the LOD cap")


func _verify_marshal_stack_forwards_lod() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/characters/viper_skill_kick_effect_renderer.gd")
	var body := _function_body(source, "func draw_marshal_effect_stack")
	_expect(body.find("effect_lod_scale: float = 1.0") >= 0, "marshal stack should accept effect LOD scale")
	_expect(_count_occurrences(body, "hit_particle_glow_size_threshold,\n\t\teffect_lod_scale") == 2, "marshal stack should forward LOD to both particle lists")


func _verify_runtime_passes_draw_lod() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/characters/viper_skill_draw_runtime.gd")
	var start := source.find("kick_effect_renderer.draw_marshal_effect_stack(")
	var end := source.find("_perf_end(perf_logger, \"viper.skill.marshal\"", start)
	var marshal_call_source := source.substr(start, end - start) if start >= 0 and end > start else ""
	_expect(marshal_call_source.find("clamped_lod_scale") >= 0, "Viper draw runtime should pass the current draw LOD into marshal rendering")


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next_func := source.find("\nfunc ", start + signature.length())
	if next_func < 0:
		return source.substr(start)
	return source.substr(start, next_func - start)


func _count_occurrences(source: String, needle: String) -> int:
	var count := 0
	var start := 0
	while true:
		var found := source.find(needle, start)
		if found < 0:
			return count
		count += 1
		start = found + needle.length()
	return count


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
