extends SceneTree

const WeatherEventState := preload("res://scripts/stages/common/weather_event_state.gd")
const WeatherEventRenderer := preload("res://scripts/stages/common/weather_event_renderer.gd")
const BattleDrawPlayfieldSceneContext := preload("res://scripts/core/battle_draw_playfield_scene_context.gd")
const BattleSceneWeatherUpdateDriver := preload("res://scripts/core/battle_scene_weather_update_driver.gd")


class FakeRegistry:
	extends RefCounted

	var weather: Object
	var renderer: Object

	func get_instance(key: String) -> Object:
		match key:
			"weather_event_state":
				return weather
			"weather_event_renderer":
				return renderer
		return null


class FakeWeather:
	extends RefCounted

	var visible := true
	var active := false

	func has_visible_effects() -> bool:
		return visible

	func is_weather_active() -> bool:
		return active


class FakeWeatherRenderer:
	extends RefCounted

	var draw_count := 0

	func draw(
		_weather: Object,
		_canvas: CanvasItem,
		_shake_offset: Vector2 = Vector2.ZERO,
		_effect_lod_scale: float = 1.0
	) -> void:
		draw_count += 1


class FakeOwner:
	extends RefCounted

	var weather_type := "rain"
	var weather_event_active := true
	var weather_event_context := {"active": true, "type": "rain"}

var _failures: Array[String] = []


func _init() -> void:
	_verify_state_render_lod_budgets()
	_verify_renderer_render_lod_budgets()
	_verify_renderer_prewarm_is_staged()
	_verify_inactive_weather_draw_is_skipped()
	_verify_owner_blank_weather_draw_is_skipped()
	_verify_playfield_context_includes_owner_weather()
	_verify_draw_context_route()

	if _failures.is_empty():
		print("weather_event_render_budget_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_state_render_lod_budgets() -> void:
	var weather := WeatherEventState.new()
	weather.weather_event_type = "rain"
	_expect(
		weather._get_render_particle_limit(1.0) == WeatherEventState.WEATHER_RENDER_PARTICLE_LIMIT,
		"state fallback should keep the full particle budget at normal quality"
	)
	_expect(
		weather._get_render_particle_limit(0.58) <= 24,
		"state fallback should use the severe particle budget at 72 FPS quality"
	)
	weather.weather_event_type = "gust"
	_expect(
		weather._get_render_particle_limit(0.58) <= 12,
		"state fallback should use the severe wind particle budget at 72 FPS quality"
	)
	_expect(
		weather._get_sand_render_stride(0.58) >= 5,
		"state fallback should stride sand segments under severe render LOD"
	)
	_expect(
		weather._get_particle_render_stride(0.58) >= 3,
		"state fallback should stride weather particles under severe render LOD"
	)


func _verify_renderer_render_lod_budgets() -> void:
	var renderer := WeatherEventRenderer.new()
	var fire_context := {"type": "fire"}
	var wind_context := {"type": "breeze"}
	var rain_context := {"type": "rain"}
	_expect(
		renderer._get_render_particle_limit(fire_context, 0.58) <= 18,
		"texture weather renderer should use the severe fire particle budget at 72 FPS quality"
	)
	_expect(
		renderer._get_render_particle_limit(wind_context, 0.58) <= 12,
		"texture weather renderer should use the severe wind particle budget at 72 FPS quality"
	)
	_expect(
		renderer._get_render_particle_limit(rain_context, 0.58) <= 24,
		"texture weather renderer should use the severe generic particle budget at 72 FPS quality"
	)
	_expect(
		renderer._get_detailed_render_limit(
			WeatherEventRenderer.FIRE_DETAILED_EXPLOSION_RENDER_LIMIT,
			WeatherEventRenderer.FIRE_DETAILED_EXPLOSION_RENDER_LIMIT_LOD,
			WeatherEventRenderer.FIRE_DETAILED_EXPLOSION_RENDER_LIMIT_SEVERE_LOD,
			0.58
		) <= 1,
		"texture weather renderer should reduce detailed fire explosion particles under severe render LOD"
	)
	_expect(
		renderer._get_sand_polygon_stride(0.58) >= 5,
		"texture weather renderer should decimate sand polygon vertices under severe render LOD"
	)
	_expect(
		renderer._get_particle_render_stride(0.58) >= 3,
		"texture weather renderer should stride particles under severe render LOD"
	)


func _verify_renderer_prewarm_is_staged() -> void:
	var renderer := WeatherEventRenderer.new()
	_expect(
		WeatherEventRenderer.PREWARM_TEXTURE_KEYS.size() >= 6,
		"texture weather renderer should expose its generated prewarm texture list"
	)
	for index in range(WeatherEventRenderer.PREWARM_TEXTURE_KEYS.size() - 1):
		_expect(not bool(renderer.prewarm_assets_step()), "weather renderer prewarm should not generate every texture in one loading tick")
	_expect(bool(renderer.prewarm_assets_step()), "weather renderer staged prewarm should finish after one pass through the texture list")


func _verify_inactive_weather_draw_is_skipped() -> void:
	var weather := WeatherEventState.new()
	_expect(not weather.has_visible_effects(), "inactive weather should report no visible draw work")
	weather.warning_timer_frames = 1.0
	_expect(weather.has_visible_effects(), "weather warning text should keep the draw path visible")
	weather.warning_timer_frames = 0.0
	weather.weather_particles.append({"weather_type": "rain"})
	_expect(weather.has_visible_effects(), "residual weather particles should keep the draw path visible")
	weather.weather_particles.clear()
	weather.sand_depths = [0.0, 0.6]
	_expect(weather.has_visible_effects(), "residual sand terrain should keep the draw path visible")


func _verify_owner_blank_weather_draw_is_skipped() -> void:
	var driver := BattleSceneWeatherUpdateDriver.new()
	var registry := FakeRegistry.new()
	var weather := FakeWeather.new()
	var renderer := FakeWeatherRenderer.new()
	registry.weather = weather
	registry.renderer = renderer

	driver.draw_weather(null, registry, Vector2.ZERO, {
		"weather_type": "",
		"weather_active": false,
		"weather_event_active": false,
		"weather_event_context": {},
	})
	_expect(renderer.draw_count == 0, "blank owner weather context should skip residual weather draw work")
	_expect(
		not driver.should_draw_weather(registry, {
			"weather_type": "",
			"weather_active": false,
			"weather_event_active": false,
			"weather_event_context": {},
		}),
		"blank owner weather context should skip the playfield weather perf sample"
	)

	weather.active = true
	driver.draw_weather(null, registry, Vector2.ZERO, {
		"weather_type": "",
		"weather_active": false,
		"weather_event_active": false,
		"weather_event_context": {},
	})
	_expect(renderer.draw_count == 0, "blank owner weather context should override stale active weather state")
	_expect(
		not driver.should_draw_weather(registry, {
			"weather_type": "",
			"weather_active": false,
			"weather_event_active": false,
			"weather_event_context": {},
		}),
		"blank owner weather context should skip the weather perf sample even when state is stale-active"
	)

	driver.draw_weather(null, registry, Vector2.ZERO, {
		"weather_type": "rain",
		"weather_active": true,
		"weather_event_active": true,
		"weather_event_context": {"active": true, "type": "rain"},
	})
	_expect(renderer.draw_count == 1, "active owner weather context should still reach the renderer")
	_expect(
		driver.should_draw_weather(registry, {
			"weather_type": "rain",
			"weather_active": true,
			"weather_event_active": true,
			"weather_event_context": {"active": true, "type": "rain"},
		}),
		"active owner weather context should keep the playfield weather perf sample"
	)

	driver.draw_weather(null, registry, Vector2.ZERO, {
		"weather_event_context": {"active": true, "type": "gust"},
	})
	_expect(renderer.draw_count == 2, "active nested weather context should still reach the renderer")


func _verify_playfield_context_includes_owner_weather() -> void:
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var context: Dictionary = BattleDrawPlayfieldSceneContext.new().build(owner, Vector2.ZERO, registry)
	_expect(str(context.get("weather_type", "")) == "rain", "playfield draw context should include owner weather type")
	_expect(bool(context.get("weather_active", false)), "playfield draw context should include owner weather active alias")
	_expect(bool(context.get("weather_event_active", false)), "playfield draw context should include owner weather active flag")
	var weather_context: Dictionary = context.get("weather_event_context", {})
	_expect(str(weather_context.get("type", "")) == "rain", "playfield draw context should include nested owner weather type")
	_expect(bool(weather_context.get("active", false)), "playfield draw context should include nested owner weather active state")


func _verify_draw_context_route() -> void:
	var scene_drawer_source := FileAccess.get_file_as_string("res://scripts/core/battle_playfield_scene_drawer.gd")
	var driver_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_weather_update_driver.gd")
	var prewarm_controller_source := FileAccess.get_file_as_string("res://scripts/core/battle_boot_resource_prewarm_controller.gd")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/stages/common/weather_event_renderer.gd")
	var state_source := FileAccess.get_file_as_string("res://scripts/stages/common/weather_event_state.gd")
	_expect(
		scene_drawer_source.find("_draw_weather_effects(canvas, registry, shake_offset, draw_context)") >= 0,
		"playfield scene drawer should pass draw_context into the weather draw path"
	)
	_expect(
		scene_drawer_source.find("_should_draw_weather_effects(registry, draw_context)") >= 0,
		"playfield scene drawer should skip the weather perf sample when no weather draw is visible"
	)
	_expect(
		driver_source.find("BattleRenderQuality.effect_scale(draw_context)") >= 0,
		"weather update driver should derive effect LOD from the shared render-quality helper"
	)
	_expect(
		driver_source.find("func should_draw_weather") >= 0,
		"weather update driver should expose a cheap visibility guard for the playfield draw fanout"
	)
	_expect(
		driver_source.find("not _has_visible_weather_effects(weather)") >= 0,
		"inactive weather should skip the draw path before renderer lookup"
	)
	_expect(
		driver_source.find("_should_skip_blank_context_weather(weather, draw_context)") >= 0,
		"blank owner weather context should skip residual weather renderer work"
	)
	_expect(
		driver_source.find("_method_accepts_argument_count_cache") >= 0
		and driver_source.find("_get_method_acceptance_cache_key") >= 0,
		"weather update driver should cache renderer method signature checks during active weather draw"
	)
	_expect(
		prewarm_controller_source.find("weather_renderer.has_method(\"prewarm_assets_step\")") >= 0,
		"stage-transition runtime prewarm should spread generated weather textures across loading ticks"
	)
	_expect(
		renderer_source.find("effect_lod_scale: float = 1.0") >= 0,
		"texture weather renderer should accept an effect LOD scale"
	)
	_expect(
		_function_body(renderer_source, "func _draw_sand_wall_polygon").find("if not _is_severe_lod_active(effect_lod_scale):") >= 0
		and _function_body(renderer_source, "func _draw_sand_wall_polygon").find("_build_sand_shadow_polygon") >= 0
		and _function_body(renderer_source, "func _draw_sand_wall_polygon").find("_build_sand_highlight_polyline") >= 0,
		"texture weather renderer should skip decorative sand shadow/highlight work under severe LOD"
	)
	_expect(
		state_source.find("effect_lod_scale: float = 1.0") >= 0,
		"weather state fallback draw should accept an effect LOD scale"
	)
	_expect(
		state_source.find("func has_visible_effects()") >= 0,
		"weather state should expose a fast visible-effect guard for inactive draw skips"
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
