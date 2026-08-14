extends SceneTree

const WeatherEventState := preload("res://scripts/stages/common/weather_event_state.gd")
const WeatherEventRenderer := preload("res://scripts/stages/common/weather_event_renderer.gd")
const BattleDrawPlayfieldSceneContext := preload("res://scripts/core/battle_draw_playfield_scene_context.gd")
const BattleSceneWeatherUpdateDriver := preload("res://scripts/core/battle_scene_weather_update_driver.gd")
const BattleRenderQuality := preload("res://scripts/core/battle_render_quality.gd")
const BattleViewLayout := preload("res://scripts/core/battle_view_layout.gd")
const WeatherEventRenderBudget := preload("res://scripts/stages/common/weather_event_render_budget.gd")
const WeatherEventPayloadFactory := preload("res://scripts/stages/common/weather_event_payload_factory.gd")


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


class FakeSandDashState:
	extends RefCounted

	var snapshot := {"active": false, "direction": 0.0}

	func get_snapshot() -> Dictionary:
		return snapshot


class FakeSandOwner:
	extends RefCounted

	var player_pos := Vector2(300.0, 700.0)
	var player_paddle_width := 155.0
	var boss_pos := Vector2(330.0, 25.0)
	var boss_paddle_width := 100.0


class FakeSandBossAiState:
	extends RefCounted

	var snapshot := {"active": false}

	func get_dash_token_snapshot() -> Dictionary:
		return snapshot


class FakeSandRegistry:
	extends RefCounted

	var dash_state := FakeSandDashState.new()
	var boss_ai_state := FakeSandBossAiState.new()

	func get_instance(key: String) -> Object:
		if key == "smasher_dash_state":
			return dash_state
		if key == "boss_ai_state":
			return boss_ai_state
		return null

var _failures: Array[String] = []


func _init() -> void:
	_verify_state_render_lod_budgets()
	_verify_renderer_render_lod_budgets()
	_verify_hail_core_survives_debris_burst_window()
	_verify_renderer_prewarm_is_staged()
	_verify_inactive_weather_draw_is_skipped()
	_verify_owner_blank_weather_draw_is_skipped()
	_verify_playfield_context_includes_owner_weather()
	_verify_sand_kickup_spray_emission_gates()
	_verify_sand_kickup_spray_stays_in_budget()
	_verify_sand_kickup_spray_uses_isolated_rng()
	_verify_sand_kickup_spray_render_continuity()
	_verify_sand_kickup_spray_mirrors_and_walks()
	_verify_sand_kickup_spray_respects_drawn_surface()
	_verify_sand_kickup_spray_stays_on_eroded_ground()
	_verify_sand_particles_survive_weather_end()
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
		weather._get_render_particle_limit(0.58) >= 24,
		"state fallback should keep wind near-full under render LOD so the flow stays continuous"
	)
	_expect(
		weather._get_sand_render_stride(0.58) >= 5,
		"state fallback should stride sand segments under severe render LOD"
	)
	_expect(
		weather._get_particle_render_stride(0.58) >= 3,
		"state fallback should stride weather particles under severe render LOD"
	)
	_expect(
		weather._get_particle_render_stride_for_type("gust", 0.58) == 1
		and weather._get_particle_render_stride_for_type("breeze", 0.58) == 1,
		"state fallback should never stride-decimate wind (index-based stride flickers the sparse wind flow)"
	)
	_expect(
		weather._get_particle_render_stride_for_type("hail", 0.58) == 1,
		"state fallback should never stride-decimate hail (max 3 stones -> stride flips which one draws each frame, so a hailstone blinks in/out mid-fall)"
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
		renderer._get_render_particle_limit(wind_context, 0.58) >= 24,
		"texture weather renderer should keep wind near-full under render LOD so the flow stays continuous"
	)
	_expect(
		renderer._get_particle_render_stride_for_context({"type": "breeze"}, 0.58) == 1
		and renderer._get_particle_render_stride_for_context({"type": "gust"}, 0.58) == 1,
		"texture weather renderer should never stride-decimate wind (index-based stride flickers the sparse wind flow)"
	)
	_expect(
		renderer._get_particle_render_stride_for_context({"type": "hail"}, 0.58) == 1,
		"texture weather renderer should never stride-decimate hail (max 3 stones -> stride flips which one draws each frame, so a hailstone blinks in/out mid-fall)"
	)
	_expect(
		renderer._get_particle_render_stride_for_context({"type": "rain"}, 0.58) >= 3,
		"texture weather renderer should still stride non-wind particles under severe render LOD"
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


func _verify_hail_core_survives_debris_burst_window() -> void:
	# A single hail impact appends 17~98 short-lived impact/burst/shard/dust particles
	# to the BACK of the array, so the newest-N render window would evict the <=3 falling
	# core "hail" stones sitting at the FRONT -> the stone vanishes mid-air and later
	# "reappears" once the debris dies. Build that exact array: 3 core hail followed by a
	# 40-particle debris burst, then prove all 3 core stay render candidates while the
	# debris beyond the window is still budget-culled.
	var WeatherEventRenderBudget := preload("res://scripts/stages/common/weather_event_render_budget.gd")
	var particles: Array = []
	for _c in range(3):
		particles.append({"kind": "hail", "weather_type": "hail"})
	var debris_kinds := ["hail_impact", "hail_shard", "hail_burst"]
	for d in range(40):
		var debris_kind: String = debris_kinds[d % 3]
		particles.append({"kind": debris_kind, "weather_type": "hail"})

	var render_limit: int = WeatherEventRenderBudget.get_weather_particle_limit("hail", 0.58)
	var particle_start: int = max(0, particles.size() - render_limit)
	var stride: int = WeatherEventRenderBudget.get_particle_render_stride_for_type("hail", 0.58)
	_expect(
		particle_start > 3,
		"scenario must push the newest-N window past the 3 front core hail (else the test proves nothing)"
	)

	var core_rendered := 0
	var debris_rendered := 0
	var debris_culled := 0
	for index in range(particles.size()):
		var kind := str(particles[index].get("kind", ""))
		var skipped: bool = WeatherEventRenderBudget.should_skip_windowed_particle(
			"hail", kind, index, particle_start, stride
		)
		if kind == "hail":
			if not skipped:
				core_rendered += 1
		elif skipped:
			debris_culled += 1
		else:
			debris_rendered += 1

	_expect(
		core_rendered == 3,
		"all 3 falling core hail stones must stay render candidates even when a 40-particle debris burst overflows the newest-N window (core must never be evicted by transient debris)"
	)
	_expect(
		debris_culled > 0,
		"transient hail debris beyond the newest-N window must still be budget-culled (core-always-render must not disable the window for debris / perf)"
	)
	# Non-hail weather has no core exemption, so the window still cuts the front.
	_expect(
		WeatherEventRenderBudget.should_skip_windowed_particle("rain", "rain", 0, 10, 1),
		"non-core weather particles below the newest-N window must still be skipped"
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


# Builds a sand event whose bottom wall depth is fully controlled, so erosion output is
# deterministic without depending on the random wall generator.
func _build_sand_weather_fixture(depth: float) -> WeatherEventState:
	var weather := WeatherEventState.new()
	weather.force_start_weather_event("sand", 1, 1, null, null)
	var depths: Array = []
	for _index in range(weather._get_sand_segment_count("bottom")):
		depths.append(depth)
	weather.sand_wall_depths["bottom"] = depths
	weather.sand_depths = depths
	weather.weather_particles.clear()
	return weather


func _count_sand_particles(weather: Object) -> int:
	var total := 0
	for value in weather.weather_particles:
		if value is Dictionary and str(value.get("kind", "")) == "sand":
			total += 1
	return total


# Drives one physics frame of the real production entry point.
func _drive_sand_dash_frame(
	weather: Object,
	owner: Object,
	registry: Object,
	next_x: float,
	dashing: bool
) -> void:
	registry.dash_state.snapshot = {
		"active": dashing,
		"direction": signf(next_x - owner.player_pos.x),
	}
	weather.apply_player_motion_effects_to_result(
		{"player_pos": Vector2(next_x, owner.player_pos.y)},
		owner,
		registry,
		1.0
	)
	owner.player_pos = Vector2(next_x, owner.player_pos.y)


func _verify_sand_kickup_spray_emission_gates() -> void:
	var owner := FakeSandOwner.new()
	var registry := FakeSandRegistry.new()

	# Positive leg: a real dash across a loaded dune throws grains.
	var loaded := _build_sand_weather_fixture(40.0)
	owner.player_pos = Vector2(300.0, 700.0)
	_drive_sand_dash_frame(loaded, owner, registry, 328.0, true)
	_expect(
		_count_sand_particles(loaded) > 0,
		"dashing across sand must throw kick-up grains (the dash erosion return value was discarded before, so the wall silently lost depth with zero visual mass leaving it)"
	)

	# Negative leg: identical dash over BARE floor must stay silent. Sand clusters only
	# cover a few of the 56 segments, so keying on "is dashing" would puff over nothing.
	var bare := _build_sand_weather_fixture(0.0)
	owner.player_pos = Vector2(300.0, 700.0)
	_drive_sand_dash_frame(bare, owner, registry, 328.0, true)
	_expect(
		_count_sand_particles(bare) == 0,
		"dashing where the dune has no depth must throw nothing: the eroded total, not the dash flag, is the only proof sand was actually there"
	)

	# Negative leg: a wall-pinned dash still carves depth with zero displacement, and a
	# stationary sand fountain there reads as a bug. Erosion is measured WITHIN the same
	# fixture — the side walls come from the global random generator, so comparing totals
	# across two fixtures would be a coin flip, not an assertion.
	var pinned := _build_sand_weather_fixture(40.0)
	owner.player_pos = Vector2(0.0, 700.0)
	var pinned_depth_before: float = float(pinned.get_sand_total_depth())
	_drive_sand_dash_frame(pinned, owner, registry, 0.0, true)
	_expect(
		float(pinned.get_sand_total_depth()) < pinned_depth_before,
		"a wall-pinned dash must still erode: this feature must not change erosion behaviour, only add its missing visual"
	)
	_expect(
		_count_sand_particles(pinned) == 0,
		"a wall-pinned dash must not spray: with no relative motion there is nothing scraping the dune"
	)

	# Negative leg: sub-pixel creep is not a scrape either. This is distinct from the
	# pinned leg above, which is caught by the zero travel-direction guard.
	var creeping := _build_sand_weather_fixture(40.0)
	owner.player_pos = Vector2(300.0, 700.0)
	_drive_sand_dash_frame(creeping, owner, registry, 300.3, true)
	_expect(
		_count_sand_particles(creeping) == 0,
		"a dash creeping 0.3px must not spray: below SAND_SPRAY_MIN_TRAVEL_PX there is no scrape to throw grains"
	)


func _verify_sand_kickup_spray_stays_in_budget() -> void:
	var owner := FakeSandOwner.new()
	var registry := FakeSandRegistry.new()
	var weather := _build_sand_weather_fixture(40.0)
	var segment_count: int = weather._get_sand_segment_count("bottom")
	var peak_per_frame := 0
	var x := 100.0
	for frame_index in range(120):
		# Refill the dune each frame so erosion never runs dry: this is the worst case
		# for emission, which is exactly what the budget has to survive.
		var depths: Array = []
		for _index in range(segment_count):
			depths.append(40.0)
		weather.sand_wall_depths["bottom"] = depths
		weather.sand_depths = depths
		var before: int = weather.weather_particles.size()
		owner.player_pos = Vector2(x, 700.0)
		x += 28.0
		if x > 600.0:
			x = 100.0
		_drive_sand_dash_frame(weather, owner, registry, x, true)
		peak_per_frame = maxi(peak_per_frame, weather.weather_particles.size() - before)
		_expect(
			weather.weather_particles.size() <= WeatherEventState.SAND_VISUAL_PARTICLE_CAP,
			"sustained dashing must never grow sand particles past SAND_VISUAL_PARTICLE_CAP (sand has no other cap, and every live grain costs a full update + draw iteration even when the render window hides it)"
		)
	_expect(
		peak_per_frame > 0,
		"the budget leg must actually emit, otherwise the cap assertion above is vacuous"
	)
	_expect(
		peak_per_frame <= WeatherEventState.SAND_DASH_SPRAY_MAX_PER_FRAME,
		"one physics frame must emit at most the DASH allowance: the walk and dash erosion legs both run while dashing, so a spray keyed to both would double-emit and exceed this"
	)
	# The shipped render cap is 72, which is <= FPS_CAP_LOD_MAX_FPS, so live play runs at
	# SEVERE LOD. Sizing the cap against the full-quality window (72) would be measuring
	# a budget the shipped build never uses, and every grain above the real window is
	# invisible per-tick work that also evicts other sand bursts sooner.
	_expect(
		BattleRenderQuality.FPS_CAP_LOD_MAX_FPS >= BattleViewLayout.RENDER_FPS_CAP_STABLE_PREFERRED_MAX,
		"the shipped render cap must still fall inside the FPS-cap LOD band; if this flips, the sand budget below was sized against the wrong window"
	)
	_expect(
		WeatherEventState.SAND_VISUAL_PARTICLE_CAP
		<= WeatherEventState.WEATHER_RENDER_PARTICLE_LIMIT_SEVERE_LOD + 8,
		"the sand cap must stay close to the SEVERE-LOD render window (24), not the full-quality one: live play is the severe budget (GRT-029)"
	)
	_expect(
		peak_per_frame * 20 <= WeatherEventState.SAND_VISUAL_PARTICLE_CAP * 3,
		"emission must stay slow enough that a dash's grains die off near the cap instead of hard-deleting each other mid-fade"
	)


func _verify_sand_kickup_spray_uses_isolated_rng() -> void:
	var owner := FakeSandOwner.new()
	var registry := FakeSandRegistry.new()
	# Build the fixture BEFORE seeding: the wall generator legitimately uses the global
	# stream. Only the per-frame spray path is under test here.
	var weather := _build_sand_weather_fixture(40.0)

	seed(20260814)
	var control_rolls: Array[int] = [randi(), randi(), randi()]

	seed(20260814)
	owner.player_pos = Vector2(300.0, 700.0)
	_drive_sand_dash_frame(weather, owner, registry, 328.0, true)
	_expect(
		_count_sand_particles(weather) > 0,
		"the RNG isolation leg must actually spray, otherwise it proves nothing"
	)
	var after_rolls: Array[int] = [randi(), randi(), randi()]
	_expect(
		control_rolls == after_rolls,
		"the dash spray must draw from its own RandomNumberGenerator: it is the first PER-FRAME sand producer, so using the global stream would advance authoritative gameplay RNG on every dash frame (AGENTS.md presentation-randomness rule)"
	)


func _verify_sand_kickup_spray_render_continuity() -> void:
	# Sand became a per-frame producer, so the array now appends AND trims every tick and
	# every survivor's index shifts. Under a stride the `(index - particle_start) % stride`
	# residue then rotates each tick and each grain draws one tick in N — the documented
	# sparse-stride strobe that wind and hail are already exempt from.
	_expect(
		WeatherEventRenderBudget.is_stride_exempt_weather_type("sand"),
		"sand must be stride-exempt now that paddle kick-up shifts every index every tick, or each grain strobes at a 1-in-3 duty cycle under the shipped severe LOD"
	)
	_expect(
		WeatherEventRenderBudget.get_particle_render_stride_for_type("sand", 0.58) == 1,
		"sand must never be stride-decimated at the shipped severe-LOD effect scale"
	)
	# Control: the exemption must not leak into dense ambient weather.
	_expect(
		WeatherEventRenderBudget.get_particle_render_stride_for_type("rain", 0.58) > 1,
		"dense ambient weather must still be stride-decimated under severe LOD"
	)
	# The window cut is a separate mechanism and must survive the exemption.
	_expect(
		WeatherEventRenderBudget.should_skip_windowed_particle("sand", "sand", 0, 10, 1),
		"stride exemption must not disable the newest-N window cut for sand"
	)


func _verify_sand_kickup_spray_mirrors_and_walks() -> void:
	var owner := FakeSandOwner.new()
	var registry := FakeSandRegistry.new()

	# Boss / ceiling wall: the mirror path must work and must throw grains DOWNWARD,
	# away from the band, rather than reusing the floor's upward launch.
	var weather := _build_sand_weather_fixture(40.0)
	var top_depths: Array = []
	for _index in range(weather._get_sand_segment_count("top")):
		top_depths.append(40.0)
	weather.sand_wall_depths["top"] = top_depths
	weather.weather_particles.clear()
	registry.boss_ai_state.snapshot = {"active": true}
	owner.boss_pos = Vector2(300.0, 25.0)
	weather.apply_boss_motion_effects_to_result(
		{"boss_pos": Vector2(328.0, 25.0)}, owner, registry, 1.0
	)
	var ceiling_grains: Array = []
	for value in weather.weather_particles:
		if value is Dictionary and str(value.get("kind", "")) == "sand":
			ceiling_grains.append(value)
	_expect(
		not ceiling_grains.is_empty(),
		"a boss dash across the ceiling dune must spray too: the mirror path is easy to leave unwired"
	)
	for grain in ceiling_grains:
		_expect(
			float(grain.get("vy", 0.0)) > 0.0,
			"ceiling grains must launch downward, away from the top band"
		)
		_expect(
			float(grain.get("y", 0.0)) < 400.0,
			"ceiling grains must spawn at the TOP wall surface, not the floor's"
		)

	# Walking (not dashing) must also throw grains, and must be able to throw them
	# BACKWARD. The walk leg emits at most one grain per frame, so a wake/bow split
	# derived from a per-frame loop index would pin every walking grain to the bow slot.
	var walker := _build_sand_weather_fixture(40.0)
	var walk_registry := FakeSandRegistry.new()
	var walk_owner := FakeSandOwner.new()
	walk_owner.player_pos = Vector2(120.0, 700.0)
	var backward_grains := 0
	var walk_grains := 0
	var walk_x := 120.0
	for _frame in range(90):
		var refill: Array = []
		for _index in range(walker._get_sand_segment_count("bottom")):
			refill.append(40.0)
		walker.sand_wall_depths["bottom"] = refill
		walker.sand_depths = refill
		walker.weather_particles.clear()
		walk_x = 120.0 + fmod(walk_x + 3.0 - 120.0, 460.0)
		_drive_sand_dash_frame(walker, walk_owner, walk_registry, walk_x, false)
		for value in walker.weather_particles:
			if not (value is Dictionary) or str(value.get("kind", "")) != "sand":
				continue
			walk_grains += 1
			if float(value.get("vx", 0.0)) < 0.0:
				backward_grains += 1
	_expect(
		walk_grains > 0,
		"walking across sand must eventually throw grains, not just silently carve the dune"
	)
	_expect(
		backward_grains > 0,
		"walking must be able to throw a grain BACKWARD: the wake/bow split must survive a leg that only ever emits one grain per frame"
	)


# Depth the SEVERE renderer actually paints at world_pos: it samples every Nth segment
# centre and straight-lines between them, so a trench in an unsampled segment is bridged.
func _severe_drawn_depth(depths: Array, world_pos: float) -> float:
	var stride: int = WeatherEventRenderBudget.SAND_RENDER_STRIDE_SEVERE_LOD
	var axis_start: float = WeatherEventState.SAND_HORIZONTAL_START
	var seg: float = WeatherEventState.SAND_SEG_SIZE
	var sampled: Array[int] = []
	for index in range(0, depths.size(), stride):
		sampled.append(index)
	if sampled[sampled.size() - 1] != depths.size() - 1:
		sampled.append(depths.size() - 1)
	for slot in range(sampled.size() - 1):
		var low_index: int = sampled[slot]
		var high_index: int = sampled[slot + 1]
		var low_x: float = axis_start + float(low_index) * seg + seg * 0.5
		var high_x: float = axis_start + float(high_index) * seg + seg * 0.5
		if world_pos < low_x or world_pos > high_x:
			continue
		var blend: float = clampf((world_pos - low_x) / maxf(0.001, high_x - low_x), 0.0, 1.0)
		return lerpf(float(depths[low_index]), float(depths[high_index]), blend)
	return float(depths[clampi(int((world_pos - axis_start) / seg), 0, depths.size() - 1)])


func _verify_sand_kickup_spray_respects_drawn_surface() -> void:
	var owner := FakeSandOwner.new()
	var registry := FakeSandRegistry.new()
	var weather := _build_sand_weather_fixture(40.0)
	var segment_count: int = weather._get_sand_segment_count("bottom")
	# NON-uniform wall: deep dune with a narrow trench cut into segments the severe
	# renderer never samples. A uniform 40/0 fixture cannot detect this class of bug.
	var depths: Array = []
	for index in range(segment_count):
		depths.append(2.0 if index % WeatherEventRenderBudget.SAND_RENDER_STRIDE_SEVERE_LOD == 2 else 42.0)
	# Sweep the whole wall over many frames: trenches are 1-in-N segments, so a single
	# 28 px dash frame emits too few grains to reliably land on one.
	var checked := 0
	var buried := 0
	var worst_depth_inside := 0.0
	var x := 100.0
	owner.player_pos = Vector2(x, 700.0)
	for _frame in range(40):
		var refill: Array = []
		for index in range(segment_count):
			refill.append(2.0 if index % WeatherEventRenderBudget.SAND_RENDER_STRIDE_SEVERE_LOD == 2 else 42.0)
		weather.sand_wall_depths["bottom"] = refill
		weather.sand_depths = refill
		weather.weather_particles.clear()
		x += 28.0
		if x > 580.0:
			x = 100.0
			owner.player_pos = Vector2(x, 700.0)
			continue
		_drive_sand_dash_frame(weather, owner, registry, x, true)
		for value in weather.weather_particles:
			if not (value is Dictionary) or str(value.get("kind", "")) != "sand":
				continue
			checked += 1
			var grain_x: float = float(value.get("x", 0.0))
			var grain_y: float = float(value.get("y", 0.0))
			var drawn_surface_y: float = WeatherEventState.FIELD_HEIGHT - _severe_drawn_depth(refill, grain_x)
			if grain_y > drawn_surface_y + 1.0:
				buried += 1
				worst_depth_inside = maxf(worst_depth_inside, grain_y - drawn_surface_y)
	_expect(checked > 8, "the drawn-surface leg must produce a real sample of grains, or it proves nothing")
	_expect(
		buried == 0,
		"%d/%d kick-up grains started INSIDE the painted dune (worst %.1f px deep): the SEVERE renderer bridges over trenches in segments it never samples, so spraying from the raw trench depth buries the grain and it climbs out of solid sand" % [buried, checked, worst_depth_inside]
	)


func _verify_sand_kickup_spray_stays_on_eroded_ground() -> void:
	var owner := FakeSandOwner.new()
	var registry := FakeSandRegistry.new()
	var weather := _build_sand_weather_fixture(40.0)
	var segment_count: int = weather._get_sand_segment_count("bottom")
	# Partial cluster: sand only on the LEFT half of the swept span. A dash clipping the
	# cluster edge must not throw grains up off the untouched bare floor to its right.
	var boundary_x: float = 360.0
	var depths: Array = []
	for index in range(segment_count):
		var seg_x: float = WeatherEventState.SAND_HORIZONTAL_START + float(index) * WeatherEventState.SAND_SEG_SIZE
		depths.append(40.0 if seg_x < boundary_x else 0.0)
	weather.sand_wall_depths["bottom"] = depths
	weather.sand_depths = depths
	weather.weather_particles.clear()
	# Paddle centre sweeps from inside the cluster to well past its edge.
	owner.player_pos = Vector2(boundary_x - 155.0 * 0.5 - 20.0, 700.0)
	_drive_sand_dash_frame(weather, owner, registry, owner.player_pos.x + 90.0, true)

	var checked := 0
	var off_cluster := 0
	var worst_x := 0.0
	for value in weather.weather_particles:
		if not (value is Dictionary) or str(value.get("kind", "")) != "sand":
			continue
		checked += 1
		var grain_x: float = float(value.get("x", 0.0))
		if grain_x > boundary_x + WeatherEventState.SAND_SEG_SIZE:
			off_cluster += 1
			worst_x = maxf(worst_x, grain_x)
	_expect(checked > 0, "the boundary-dash leg must actually produce grains, or it proves nothing")
	_expect(
		off_cluster == 0,
		"%d/%d kick-up grains landed past the cluster edge (worst x=%.1f vs edge %.1f): erosion reports only a TOTAL, so sampling the whole swept span throws sand off bare floor the dash never disturbed" % [off_cluster, checked, worst_x, boundary_x]
	)
	# The recorded erode sub-span is the mechanism, and it must be strictly narrower than
	# the swept span here — otherwise the assertion above could be passing only because of
	# the separate crest-depth gate and would not notice the span tracking regressing.
	_expect(
		weather._has_sand_erode_hit_span()
		and weather._sand_erode_hit_max < owner.player_pos.x + 155.0 * 0.5,
		"the eroded sub-span must be recorded and must stop short of the swept span's far end on a cluster-edge dash"
	)


func _verify_sand_particles_survive_weather_end() -> void:
	# Sand grains deliberately outlive the weather event through the dissolve phase, but
	# force_end_weather_event clears the context type. If the stride exemption is keyed on
	# the context instead of the particle, those surviving grains get handed back to the
	# severe stride and strobe exactly while the wall is crumbling.
	_expect(
		WeatherEventRenderBudget.is_stride_exempt_particle("", "sand"),
		"a sand grain must stay stride-exempt after the weather type is cleared, or the dissolve phase re-introduces the 1-in-3 strobe"
	)
	_expect(
		not WeatherEventRenderBudget.should_skip_windowed_particle("", "sand", 1, 0, 3),
		"a surviving sand grain must still draw under a stride-3 budget once weather has ended"
	)
	# Control: the per-particle exemption must not blanket-exempt everything.
	_expect(
		WeatherEventRenderBudget.should_skip_windowed_particle("", "rain", 1, 0, 3),
		"the per-particle stride exemption must stay scoped to sparse kinds"
	)


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
	_expect(
		_function_body(renderer_source, "func _draw_particles").find("WeatherEventRenderBudget.should_skip_windowed_particle(") >= 0,
		"texture weather renderer particle loop must defer the window/stride cutoff to the shared helper so core hail is never evicted by a debris burst"
	)
	_expect(
		_function_body(state_source, "func draw(").find("WeatherEventRenderBudget.should_skip_windowed_particle(") >= 0,
		"weather state fallback draw loop must defer the window/stride cutoff to the shared helper so core hail is never evicted by a debris burst"
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
