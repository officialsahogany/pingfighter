extends SceneTree

const WeatherEventState := preload("res://scripts/stages/common/weather_event_state.gd")
const WeatherEventRenderer := preload("res://scripts/stages/common/weather_event_renderer.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")


class FakeOwner:
	var current_stage := 1
	var ai_mode := "champion"
	var arena_mode_enabled := false
	var weather_type := ""
	var weather_event_active := false
	var weather_event_context: Dictionary = {}
	var selected_character_type := "smasher"
	var special_gauge := 120.0
	var special_gauge_max := 500.0
	var player_pos := Vector2(300.0, 700.0)
	var boss_pos := Vector2(330.0, 25.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var boss_paddle_width := 100.0


class FakeMovementState:
	var knockback_count := 0
	var last_velocity := 0.0
	var last_frames := 0.0

	func start_knockback(velocity: float, frames: float = 18.0, _decay: float = 0.92, _replace: bool = false, _cleansable: bool = true) -> bool:
		knockback_count += 1
		last_velocity = velocity
		last_frames = frames
		return true


class FakeStatusEffectState:
	var calls: Array[Dictionary] = []

	func apply_status(target: String, status_id: String, duration_frames: float, data: Dictionary = {}, source: String = "") -> Dictionary:
		calls.append({
			"target": target,
			"status_id": status_id,
			"duration_frames": duration_frames,
			"data": data.duplicate(true),
			"source": source,
		})
		return {}


class FakeDashState:
	var snapshot := {
		"active": false,
		"direction": 0,
	}
	var cancel_count := 0

	func get_snapshot() -> Dictionary:
		return snapshot

	func cancel_active_without_recovery() -> bool:
		cancel_count += 1
		snapshot["active"] = false
		snapshot["timer"] = 0.0
		return true


class FakeWarpGateState:
	var active := true
	var wrap_count := 0

	func is_active() -> bool:
		return active

	func wrap_player_position(player_pos: Vector2, paddle_size: Vector2, special_gauge: float, _deps: Dictionary = {}) -> Dictionary:
		var wrapped := false
		if player_pos.x + paddle_size.x <= 0.0:
			player_pos.x += 760.0
			wrapped = true
		elif player_pos.x >= 760.0:
			player_pos.x -= 760.0
			wrapped = true
		if wrapped:
			wrap_count += 1
		return {
			"player_pos": player_pos,
			"special_gauge": special_gauge,
			"wrapped": wrapped,
		}


class FakeRegistry:
	var movement_state := FakeMovementState.new()
	var status_effect_state := FakeStatusEffectState.new()
	var dash_state := FakeDashState.new()
	var warp_gate_state: Object = null
	var requested_keys: Array[String] = []

	func get_instance(key: String) -> Object:
		requested_keys.append(key)
		match key:
			"player_movement_state":
				return movement_state
			"status_effect_state":
				return status_effect_state
			"smasher_dash_state":
				return dash_state
			"smasher_warp_gate_state":
				return warp_gate_state
		return null


func _init() -> void:
	var owner := FakeOwner.new()
	var weather: Object = WeatherEventState.new()
	var renderer: Object = WeatherEventRenderer.new()
	var registry := FakeRegistry.new()

	LanguageSettings.set_language(LanguageSettings.LANGUAGE_SPANISH)
	_expect(weather._get_start_text("breeze", -1) == "Una brisa sopla hacia la izquierda", "breeze start text should localize to Spanish")
	_expect(weather._get_start_text("gust", 1) == "Una ráfaga fuerte empuja hacia la derecha", "gust start text should localize to Spanish")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL)
	_expect(weather._get_start_text("breeze", -1) == "Uma brisa sopra para a esquerda", "breeze start text should localize to Brazilian Portuguese")
	_expect(weather._get_start_text("gust", 1) == "Uma rajada forte empurra para a direita", "gust start text should localize to Brazilian Portuguese")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_RUSSIAN)
	_expect(weather._get_start_text("breeze", -1) == "Легкий ветер дует влево", "breeze start text should localize to Russian")
	_expect(weather._get_start_text("gust", 1) == "Сильный порыв несет вправо", "gust start text should localize to Russian")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)

	owner.selected_character_type = "viper"
	var inactive_player_result := {
		"player_pos": owner.player_pos,
	}
	weather.apply_player_motion_effects_to_result(inactive_player_result, owner, registry, 1.0)
	weather.apply_boss_motion_effects_to_result({"boss_pos": owner.boss_pos}, owner, registry, 1.0)
	_expect(registry.requested_keys.is_empty(), "inactive weather should not query motion deps for non-Smasher actors")

	owner.selected_character_type = "smasher"
	var inactive_warp_registry := FakeRegistry.new()
	inactive_warp_registry.warp_gate_state = FakeWarpGateState.new()
	var inactive_warp_result := {
		"player_pos": Vector2(762.0, owner.player_pos.y),
		"player_paddle_width": owner.player_paddle_width,
		"player_paddle_height": owner.player_paddle_height,
		"special_gauge": owner.special_gauge,
	}
	weather.apply_player_motion_effects_to_result(inactive_warp_result, owner, inactive_warp_registry, 1.0)
	_expect(inactive_warp_registry.warp_gate_state.wrap_count == 1, "inactive weather should preserve Smasher warp-gate wrapping")
	_expect(_get_vec(inactive_warp_result, "player_pos").x < 20.0, "inactive warp-gate wrapping should land on the opposite side")

	var breeze: Dictionary = weather.force_start_weather_event("breeze", 2, -1, owner, null)
	_expect(bool(breeze.get("started", false)), "breeze should start through the forced weather API")
	_expect(str(owner.weather_type) == "breeze", "weather should sync the active type to the owner")
	_expect(int(weather.get_weather_direction()) == -1, "forced breeze direction should be preserved")

	var player_result := {
		"player_pos": owner.player_pos,
	}
	weather.apply_player_wind_to_result(player_result, owner, 1.0)
	_expect(_get_vec(player_result, "player_pos").x < owner.player_pos.x, "left breeze should push the player left")

	var boss_wind_result := {
		"boss_pos": owner.boss_pos,
		"boss_vel": 3.5,
	}
	weather.apply_boss_wind_to_result(boss_wind_result, owner, 1.0)
	_expect(_get_vec(boss_wind_result, "boss_pos").x < owner.boss_pos.x, "left breeze should drift the boss left")
	_expect(
		is_equal_approx(float(boss_wind_result.get("boss_vel", 0.0)), 3.5),
		"wind drift should not contaminate boss AI velocity"
	)

	var ball_scene := {
		"ball_vel": Vector2.ZERO,
	}
	weather.apply_ball_weather_motion(ball_scene, 1.0)
	_expect(_get_vec(ball_scene, "ball_vel").x < 0.0, "left breeze should add leftward ball velocity")

	weather.force_start_weather_event("breeze", 1, 1, owner, null)
	weather.weather_particles.clear()
	weather.update(owner, null, 1.0 / 60.0)
	_expect_wind_particles_follow_direction(weather, 1, "right breeze")

	weather.force_start_weather_event("gust", 1, -1, owner, null)
	weather.weather_particles.clear()
	weather.update(owner, null, 1.0 / 60.0)
	_expect_wind_particles_follow_direction(weather, -1, "left gust")

	weather.force_start_weather_event("fire", 1, 1, owner, null)
	var boosted: Vector2 = weather.apply_fire_hit_speed(Vector2(0.0, -10.0))
	_expect(boosted.length() > 10.5, "fire weather should boost hit speed with the doubled exchange rate")
	weather.update(owner, null, 1.0)
	_expect(float(owner.special_gauge) <= 115.0, "fire weather should drain roughly 5 gauge per second")

	weather.force_start_weather_event("rain", 1, 1, owner, null)
	_expect(is_equal_approx(float(weather.get_player_speed_multiplier()), 0.70), "rain should expose the 30% movement slow")

	weather.force_start_weather_event("ice", 1, 1, owner, null)
	var ice_config := {
		"paddle_accel": 1.0,
		"paddle_decel": 1.0,
		"paddle_turn_decel": 1.0,
	}
	weather.apply_player_movement_config(ice_config)
	_expect(is_equal_approx(float(ice_config["paddle_accel"]), 0.25), "ice should reduce player acceleration")
	_expect(is_equal_approx(float(ice_config["paddle_decel"]), 0.05), "ice should make player deceleration slippery")
	_expect(is_equal_approx(float(ice_config["paddle_turn_decel"]), 0.20), "ice should reduce direction-change control")
	registry.dash_state.snapshot = {"active": true, "direction": 1, "timer": 15.0}
	var ice_dash_result := {
		"player_pos": owner.player_pos + Vector2(28.0, 0.0),
		"player_paddle_width": owner.player_paddle_width,
		"player_speed": 0.0,
	}
	weather.apply_player_motion_effects_to_result(ice_dash_result, owner, registry, 1.0)
	_expect(registry.dash_state.cancel_count == 1, "ice dash slide should cancel the active dash immediately")
	_expect(
		is_equal_approx(_get_vec(ice_dash_result, "player_pos").x, owner.player_pos.x + 25.0),
		"ice dash slide should replace the dash decel frame instead of adding after it"
	)
	var ice_slide_next_result := {
		"player_pos": _get_vec(ice_dash_result, "player_pos"),
		"player_paddle_width": owner.player_paddle_width,
		"player_speed": 0.0,
	}
	registry.dash_state.snapshot = {"active": false, "direction": 1, "timer": 0.0}
	weather.apply_player_motion_effects_to_result(ice_slide_next_result, owner, registry, 1.0)
	_expect(
		_get_vec(ice_slide_next_result, "player_pos").x > _get_vec(ice_dash_result, "player_pos").x,
		"ice dash slide should continue smoothly after the dash is cancelled"
	)
	weather.force_start_weather_event("ice", 1, 1, owner, null)
	var warp_registry := FakeRegistry.new()
	warp_registry.warp_gate_state = FakeWarpGateState.new()
	warp_registry.dash_state.snapshot = {"active": true, "direction": 1, "timer": 15.0}
	owner.player_pos = Vector2(742.0, 700.0)
	var warp_ice_result := {
		"player_pos": owner.player_pos + Vector2(18.0, 0.0),
		"player_paddle_width": owner.player_paddle_width,
		"player_paddle_height": owner.player_paddle_height,
		"player_speed": 0.0,
		"special_gauge": owner.special_gauge,
	}
	weather.apply_player_motion_effects_to_result(warp_ice_result, owner, warp_registry, 1.0)
	_expect(warp_registry.warp_gate_state.wrap_count == 1, "ice dash slide should wrap through an active warp gate instead of clamping at the wall")
	_expect(_get_vec(warp_ice_result, "player_pos").x < 20.0, "ice dash slide through the right warp gate should land on the left side")
	_expect(bool(weather.get_weather_context().get("ice_player_slide_active", false)), "warp-gate ice slide should keep sliding after wrapping")
	owner.player_pos = Vector2(300.0, 700.0)

	weather.force_start_weather_event("hail", 1, 1, owner, null)
	weather.weather_particles = [{
		"x": owner.player_pos.x + 20.0,
		"y": owner.player_pos.y + 12.0,
		"vx": 0.0,
		"vy": 0.0,
		"life": 60.0,
		"max_life": 60.0,
		"size": 14.0,
		"kind": "hail",
		"weather_type": "hail",
		"color": Color.WHITE,
	}]
	weather.update(owner, registry, 1.0 / 60.0)
	_expect(registry.movement_state.knockback_count == 1, "hail should knock the player back on collision")
	_expect(is_equal_approx(registry.movement_state.last_frames, 6.0), "hail stun window should be about 0.1 seconds")
	_expect(registry.status_effect_state.calls.size() == 1, "hail should also apply shared player stun for stun-star overlay")
	if not registry.status_effect_state.calls.is_empty():
		var hail_status: Dictionary = registry.status_effect_state.calls[0]
		_expect(str(hail_status.get("target", "")) == "player", "hail shared stun should target the player")
		_expect(str(hail_status.get("status_id", "")) == "stun", "hail shared status should be stun")
		_expect(is_equal_approx(float(hail_status.get("duration_frames", 0.0)), 6.0), "hail shared stun duration should match the knockback stun window")
	var hail_hit_particles: Array = weather.harvest_particles("hail")
	_expect(_count_particles_by_kind(hail_hit_particles, "hail_burst") >= 1, "hail hit should spawn a visible shatter burst")
	_expect(_count_particles_by_kind(hail_hit_particles, "hail_shard") >= 8, "hail hit should spawn readable ice shards")

	registry.dash_state.snapshot = {"active": true, "direction": 1}
	weather.hail_player_hit_cooldown_frames = 0.0
	weather.weather_particles = [{
		"x": owner.player_pos.x + 24.0,
		"y": owner.player_pos.y + 12.0,
		"vx": 0.0,
		"vy": 0.0,
		"life": 60.0,
		"max_life": 60.0,
		"size": 14.0,
		"kind": "hail",
		"weather_type": "hail",
		"color": Color.WHITE,
	}]
	weather.update(owner, registry, 1.0 / 60.0)
	_expect(int(weather.get_weather_context().get("hail_destroy_count", 0)) >= 1, "dashing through hail should destroy the hailstone")
	_expect(registry.movement_state.knockback_count == 1, "dash-destroyed hail should not knock the player back")
	var dash_destroy_particles: Array = weather.harvest_particles("hail")
	_expect(_count_particles_by_kind(dash_destroy_particles, "hail_burst") >= 1, "dash hail destroy should spawn a shatter burst")
	_expect(_count_particles_by_kind(dash_destroy_particles, "hail_shard") >= 16, "dash hail destroy should spawn stronger ice shards")

	weather.force_start_weather_event("sand", 1, 1, owner, null)
	_expect(float(weather.get_sand_total_depth()) > 0.0, "sand weather should build persistent sand terrain")
	_expect(weather.harvest_particles("sand").size() > 0, "sand weather should expose harvestable terrain particles")
	var left_wall := []
	for _i in range(52):
		left_wall.append(30.0)
	weather.sand_wall_depths["left"] = left_wall
	var sand_result: Dictionary = weather.resolve_sand_ball_collision(Vector2(18.0, 380.0), Vector2(-8.0, 0.0), 28.6, {})
	_expect(not sand_result.is_empty(), "sand terrain should collide with a ball near the side wall")
	_expect(_get_vec(sand_result, "ball_vel").x > 0.0, "sand terrain should reflect incoming ball velocity")
	var visual_snapshot: Dictionary = renderer.build_visual_snapshot(weather)
	_expect(int(visual_snapshot.get("sand_segment_count", 0)) > 0, "weather renderer should see sand terrain segments")
	_expect(int(visual_snapshot.get("sand_draw_segment_count", 0)) > 0, "weather renderer should draw coalesced sand terrain segments")
	_expect(
		int(visual_snapshot.get("sand_draw_segment_count", 0)) <= int(visual_snapshot.get("sand_segment_count", 0)),
		"sand rendering should not expand the collision segment count into extra draw work"
	)
	_expect(
		int(visual_snapshot.get("sand_draw_segment_count", 0)) <= WeatherEventRenderer.SAND_RENDER_SEGMENT_LIMIT_PER_SIDE * 4,
		"sand terrain rendering should stay within its draw segment budget"
	)
	_expect(int(visual_snapshot.get("particle_count", 0)) > 0, "weather renderer should consume harvestable weather particles")
	weather.force_end_weather_event(owner, null)
	_expect(float(weather.get_sand_total_depth()) <= 0.001, "ending sand weather should clear persistent sand terrain")

	weather.force_start_weather_event("rain", 1, 1, owner, null)
	weather.weather_particles.clear()
	for index in range(140):
		weather.weather_particles.append({
			"x": float(index % 20) * 36.0,
			"y": float(floori(float(index) / 20.0)) * 34.0,
			"vx": 0.0,
			"vy": 0.0,
			"life": 60.0,
			"max_life": 60.0,
			"length": 16.0,
			"kind": "rain",
			"weather_type": "rain",
			"color": Color.WHITE,
		})
	var capped_snapshot: Dictionary = renderer.build_visual_snapshot(weather)
	_expect(int(capped_snapshot.get("particle_count", 0)) == 140, "weather state should keep full particle state for update/gameplay")
	_expect(
		int(capped_snapshot.get("rendered_particle_count", 0)) == WeatherEventRenderer.WEATHER_RENDER_PARTICLE_LIMIT,
		"weather renderer should cap rendered weather particles"
	)
	_expect(WeatherEventRenderer.WEATHER_RENDER_PARTICLE_LIMIT <= 72, "weather renderer particle cap should stay bounded for frame pacing")
	_expect(WeatherEventState.WEATHER_RENDER_PARTICLE_LIMIT <= 72, "weather fallback draw particle cap should stay bounded for frame pacing")
	_expect(WeatherEventRenderer.WIND_RENDER_PARTICLE_LIMIT <= 32, "wind weather renderer should use a tighter particle cap")
	_expect(WeatherEventState.WIND_RENDER_PARTICLE_LIMIT <= 32, "wind fallback draw particle cap should stay bounded")
	_expect(WeatherEventState.BREEZE_VISUAL_PARTICLE_TARGET <= 28, "breeze ambient particles should stay within the wind frame budget")
	_expect(WeatherEventState.GUST_VISUAL_PARTICLE_TARGET <= 34, "gust ambient particles should stay within the wind frame budget")
	_expect(WeatherEventRenderer.FIRE_RENDER_PARTICLE_LIMIT <= 48, "fire weather renderer should use a tighter particle cap")
	_expect(WeatherEventRenderer.FIRE_DETAILED_EXPLOSION_RENDER_LIMIT <= 8, "fire explosion rendering should cap detailed particles")
	_expect(WeatherEventRenderer.FIRE_DETAILED_SPARK_RENDER_LIMIT <= 8, "fire spark rendering should cap detailed particles")
	_expect(WeatherEventRenderer.SAND_RENDER_SEGMENT_BUCKET_SIZE >= 4, "sand terrain renderer should coalesce visual segments for frame pacing")
	_expect(WeatherEventRenderer.SAND_RENDER_SEGMENT_LIMIT_PER_SIDE <= 18, "sand terrain renderer should cap per-side draw segments")
	_expect(WeatherEventState.FIRE_WEATHER_PARTICLE_TARGET <= 44, "fire weather ambient particles should stay within the frame budget")
	_expect(WeatherEventState.FIRE_HIT_EXPLOSION_PARTICLES <= 14, "fire hit explosion particle count should stay within the frame budget")
	_expect(WeatherEventState.FIRE_HIT_SPARK_PARTICLES <= 8, "fire hit spark particle count should stay within the frame budget")
	_expect(WeatherEventState.FIRE_VISUAL_PARTICLE_CAP <= 72, "fire weather should trim old visual particles after hit bursts")
	weather.force_start_weather_event("fire", 1, 1, owner, null)
	weather.weather_particles.clear()
	for index in range(100):
		weather.weather_particles.append({
			"x": float(index % 20) * 36.0,
			"y": float(floori(float(index) / 20.0)) * 34.0,
			"vx": 0.0,
			"vy": -1.0,
			"life": 60.0,
			"max_life": 60.0,
			"size": 4.0,
			"kind": "fire",
			"weather_type": "fire",
			"color": Color.WHITE,
		})
	var fire_capped_snapshot: Dictionary = renderer.build_visual_snapshot(weather)
	_expect(
		int(fire_capped_snapshot.get("rendered_particle_count", 0)) == WeatherEventRenderer.FIRE_RENDER_PARTICLE_LIMIT,
		"fire weather renderer should use the fire-specific particle cap"
	)
	weather.force_start_weather_event("gust", 1, 1, owner, null)
	weather.weather_particles.clear()
	for index in range(80):
		weather.weather_particles.append({
			"x": float(index % 20) * 36.0,
			"y": float(floori(float(index) / 20.0)) * 34.0,
			"vx": 4.0,
			"vy": 0.0,
			"life": 60.0,
			"max_life": 60.0,
			"size": 2.0,
			"kind": "wind",
			"weather_type": "gust",
			"color": Color.WHITE,
		})
	var wind_capped_snapshot: Dictionary = renderer.build_visual_snapshot(weather)
	_expect(
		int(wind_capped_snapshot.get("rendered_particle_count", 0)) == WeatherEventRenderer.WIND_RENDER_PARTICLE_LIMIT,
		"wind weather renderer should use the wind-specific particle cap"
	)
	weather.force_start_weather_event("fire", 1, 1, owner, null)
	weather.weather_particles.clear()
	for index in range(WeatherEventState.FIRE_VISUAL_PARTICLE_CAP):
		weather.weather_particles.append({
			"x": float(index % 20) * 36.0,
			"y": float(floori(float(index) / 20.0)) * 34.0,
			"vx": 0.0,
			"vy": -1.0,
			"life": 60.0,
			"max_life": 60.0,
			"size": 4.0,
			"kind": "fire",
			"weather_type": "fire",
			"color": Color.WHITE,
		})
	weather.apply_fire_paddle_hit_knockback(true, Vector2(380.0, 360.0), {}, {})
	_expect(weather.weather_particles.size() <= WeatherEventState.FIRE_VISUAL_PARTICLE_CAP, "fire hit burst should trim old fire particles")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_JAPANESE)
	_expect(weather._get_start_text("breeze", -1) == "そよ風が左へ吹きます", "breeze start text should localize to Japanese")
	_expect(weather._get_start_text("gust", 1) == "強風が右へ吹き荒れます", "gust start text should localize to Japanese")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_SPANISH)
	_expect(weather._get_start_text("breeze", -1) == "Una brisa sopla hacia la izquierda", "breeze start text should localize to Spanish")
	_expect(weather._get_start_text("gust", 1) == "Una ráfaga fuerte empuja hacia la derecha", "gust start text should localize to Spanish")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL)
	_expect(weather._get_start_text("breeze", -1) == "Uma brisa sopra para a esquerda", "breeze start text should localize to Brazilian Portuguese")
	_expect(weather._get_start_text("gust", 1) == "Uma rajada forte empurra para a direita", "gust start text should localize to Brazilian Portuguese")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_RUSSIAN)
	_expect(weather._get_start_text("breeze", -1) == "Легкий ветер дует влево", "breeze start text should localize to Russian")
	_expect(weather._get_start_text("gust", 1) == "Сильный порыв несет вправо", "gust start text should localize to Russian")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)

	print("weather_event_state_smoke: ok")
	quit(0)


func _get_vec(source: Dictionary, key: String) -> Vector2:
	var value: Variant = source.get(key, Vector2.ZERO)
	if value is Vector2:
		return value
	return Vector2.ZERO


func _count_particles_by_kind(particles: Array, kind: String) -> int:
	var count := 0
	for value in particles:
		if not (value is Dictionary):
			continue
		if str(value.get("kind", "")) == kind:
			count += 1
	return count


func _expect_wind_particles_follow_direction(weather: Object, direction: int, message_prefix: String) -> void:
	var particles: Array = weather.get_render_particles()
	_expect(not particles.is_empty(), "%s should spawn wind particles" % message_prefix)
	var found_wind := false
	for value in particles:
		if not (value is Dictionary):
			continue
		var particle: Dictionary = value
		if str(particle.get("kind", "")) != "wind":
			continue
		found_wind = true
		var vx: float = float(particle.get("vx", 0.0))
		_expect(vx * float(direction) > 0.0, "%s wind ribbons should move in the event direction" % message_prefix)
		var x: float = float(particle.get("x", 0.0))
		if direction > 0:
			_expect(x < 0.0, "%s wind should enter from the left edge only" % message_prefix)
		else:
			_expect(x > WeatherEventState.FIELD_WIDTH, "%s wind should enter from the right edge only" % message_prefix)
	_expect(found_wind, "%s should include wind particles" % message_prefix)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
