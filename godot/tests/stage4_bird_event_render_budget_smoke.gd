extends SceneTree

const Stage4BirdEvent := preload("res://scripts/stages/stage4/stage4_bird_event.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_render_budgets()
	_verify_recent_start_helper()
	_verify_bird_directional_facing()
	_verify_draw_paths_use_render_caps()

	if _failures.is_empty():
		print("stage4_bird_event_render_budget_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_render_budgets() -> void:
	_expect(Stage4BirdEvent.GOLD_DUST_RENDER_LIMIT <= 36, "gold dust should cap rendered decorative particles per bird")
	_expect(Stage4BirdEvent.GOLD_DUST_RENDER_LIMIT_LOD <= 18, "gold dust should use a tighter shared render-quality LOD cap")
	_expect(Stage4BirdEvent.CROW_FRAGMENT_RENDER_LIMIT <= 24, "star-bird fragments should cap rendered decorative pieces")
	_expect(Stage4BirdEvent.CROW_FRAGMENT_RENDER_LIMIT_LOD <= 12, "star-bird fragments should use a tighter shared render-quality LOD cap")
	_expect(Stage4BirdEvent.CROW_PARTICLE_RENDER_LIMIT <= 32, "star-bird debris particles should cap rendered decorative pieces")
	_expect(Stage4BirdEvent.CROW_PARTICLE_RENDER_LIMIT_LOD <= 16, "star-bird debris particles should use a tighter shared render-quality LOD cap")
	_expect(Stage4BirdEvent.STARPOINT_PARTICLE_RENDER_LIMIT <= 48, "starpoint particles should cap rendered decorative pieces")
	_expect(Stage4BirdEvent.STARPOINT_PARTICLE_RENDER_LIMIT_LOD <= 24, "starpoint particles should use a tighter shared render-quality LOD cap")

	var event := Stage4BirdEvent.new()
	var status: Dictionary = event.get_asset_status()
	_expect(bool(status.get("shared_render_quality_lod_supported", false)), "asset status should expose shared render-quality LOD support")
	_expect(int(status.get("star_bird_gold_dust_render_limit", 0)) == Stage4BirdEvent.GOLD_DUST_RENDER_LIMIT, "asset status should expose the gold-dust render cap")
	_expect(int(status.get("star_bird_gold_dust_render_limit_lod", 0)) == Stage4BirdEvent.GOLD_DUST_RENDER_LIMIT_LOD, "asset status should expose the gold-dust LOD render cap")
	_expect(int(status.get("starpoint_particle_render_limit", 0)) == Stage4BirdEvent.STARPOINT_PARTICLE_RENDER_LIMIT, "asset status should expose the starpoint render cap")
	_expect(int(status.get("starpoint_particle_render_limit_lod", 0)) == Stage4BirdEvent.STARPOINT_PARTICLE_RENDER_LIMIT_LOD, "asset status should expose the starpoint LOD render cap")


func _verify_recent_start_helper() -> void:
	var event := Stage4BirdEvent.new()
	var values: Array = []
	for index in range(100):
		values.append(index)
	_expect(event._recent_start(values, 24) == 76, "recent-start helper should draw only the newest capped entries")
	_expect(event._recent_start(values, 120) == 0, "recent-start helper should draw from zero when under budget")
	_expect(event._recent_start(values, 0) == values.size(), "zero render budget should draw nothing")


func _verify_bird_directional_facing() -> void:
	var event := Stage4BirdEvent.new()
	_expect(event._get_bird_facing_sign({"vx": -2.0}) < 0.0, "right-to-left star-birds should face left")
	_expect(event._should_flip_bird_sheet({"vx": -2.0}), "right-to-left star-birds should flip the right-facing sheet")
	_expect(event._get_bird_facing_sign({"vx": 2.0}) > 0.0, "left-to-right star-birds should face right")
	_expect(not event._should_flip_bird_sheet({"vx": 2.0}), "left-to-right star-birds should keep the right-facing sheet")


func _verify_draw_paths_use_render_caps() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/stages/stage4/stage4_bird_event.gd")
	_expect(source != "", "stage4 bird event source should be readable")
	_expect(
		_function_body(source, "func draw").find("_get_render_quality_scale(context)") >= 0,
		"star-bird draw should calculate the shared render-quality LOD scale"
	)
	_expect(
		_function_body(source, "func draw").find("CROW_FRAGMENT_RENDER_LIMIT_LOD") >= 0,
		"star-bird draw should cap fragment rendering"
	)
	_expect(
		_function_body(source, "func draw").find("CROW_PARTICLE_RENDER_LIMIT_LOD") >= 0,
		"star-bird draw should cap debris-particle rendering"
	)
	_expect(
		_function_body(source, "func _draw_gold_dust").find("GOLD_DUST_RENDER_LIMIT_LOD") >= 0
		and _function_body(source, "func _draw_gold_dust").find("not lod_active") >= 0,
		"gold-dust draw should cap per-bird decorative rendering"
	)
	_expect(
		_function_body(source, "func _draw_starpoint_particles").find("STARPOINT_PARTICLE_RENDER_LIMIT_LOD") >= 0,
		"starpoint-particle draw should cap decorative rendering"
	)
	_expect(
		_function_body(source, "func _get_render_quality_scale").find("BattleRenderQuality.effect_scale(context)") >= 0,
		"star-bird LOD should reuse the shared render-quality helper"
	)


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next_func := source.find("\nfunc ", start + signature.length())
	if next_func < 0:
		return source.substr(start)
	return source.substr(start, next_func - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
