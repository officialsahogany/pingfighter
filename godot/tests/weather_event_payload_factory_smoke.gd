extends SceneTree

const GameplayStageModuleCatalog := preload("res://scripts/resources/gameplay_stage_module_catalog.gd")
const WeatherEventPayloadFactory := preload("res://scripts/stages/common/weather_event_payload_factory.gd")


var _failures: Array[String] = []

func _init() -> void:
	seed(20260612)
	var fire_color := Color(1.0, 95.0 / 255.0, 35.0 / 255.0, 1.0)
	var fire_particles: Array[Dictionary] = WeatherEventPayloadFactory.build_fire_hit_explosion_particles(
		Vector2(120.0, 240.0),
		5,
		4,
		fire_color
	)
	_expect(fire_particles.size() == 9, "fire hit factory should create explosion plus spark particles")
	var fire_explosion_count := 0
	var fire_spark_count := 0
	for particle in fire_particles:
		_expect(is_equal_approx(float(particle.get("x", 0.0)), 120.0), "fire particle should preserve x")
		_expect(is_equal_approx(float(particle.get("y", 0.0)), 240.0), "fire particle should preserve y")
		_expect(str(particle.get("weather_type", "")) == "fire", "fire particle should keep weather type")
		match str(particle.get("kind", "")):
			"fire_explosion":
				fire_explosion_count += 1
				_expect(particle.get("color", null) == fire_color, "fire explosion should use weather fire color")
				_expect(float(particle.get("life", 0.0)) >= 18.0 and float(particle.get("life", 0.0)) <= 34.0, "fire explosion life should stay in range")
				_expect(is_equal_approx(float(particle.get("max_life", -1.0)), float(particle.get("life", 0.0))), "fire explosion max_life should match life")
				_expect(float(particle.get("size", 0.0)) >= 3.4 and float(particle.get("size", 0.0)) <= 8.4, "fire explosion size should stay in range")
				_expect(is_equal_approx(float(particle.get("gravity", 0.0)), 0.08), "fire explosion gravity should stay tuned")
				_expect(is_equal_approx(float(particle.get("friction", 0.0)), 0.955), "fire explosion friction should stay tuned")
			"fire_spark":
				fire_spark_count += 1
				_expect(particle.get("color", null) == Color(1.0, 0.72, 0.18, 1.0), "fire spark should use hot spark color")
				_expect(float(particle.get("life", 0.0)) >= 14.0 and float(particle.get("life", 0.0)) <= 26.0, "fire spark life should stay in range")
				_expect(float(particle.get("size", 0.0)) >= 2.0 and float(particle.get("size", 0.0)) <= 4.2, "fire spark size should stay in range")
				_expect(float(particle.get("length", 0.0)) >= 8.0 and float(particle.get("length", 0.0)) <= 18.0, "fire spark length should stay in range")
				_expect(float(particle.get("spin", 0.0)) >= -0.10 and float(particle.get("spin", 0.0)) <= 0.10, "fire spark spin should stay in range")
				_expect(is_equal_approx(float(particle.get("gravity", 0.0)), 0.05), "fire spark gravity should stay tuned")
			_:
				_expect(false, "fire hit factory emitted an unknown particle kind")
	_expect(fire_explosion_count == 5, "fire hit factory should honor explosion count")
	_expect(fire_spark_count == 4, "fire hit factory should honor spark count")
	_expect(WeatherEventPayloadFactory.build_fire_hit_explosion_particles(Vector2.ZERO, -1, -1, fire_color).is_empty(), "negative fire counts should produce no fire particles")

	seed(20260612)
	var hail_color := Color(215.0 / 255.0, 240.0 / 255.0, 1.0, 1.0)
	var normal_hail: Array[Dictionary] = WeatherEventPayloadFactory.build_hail_impact_particles(
		Vector2(320.0, 640.0),
		14.0,
		false,
		hail_color
	)
	_verify_hail_payload(normal_hail, Vector2(320.0, 640.0), 14.0, false, hail_color)

	seed(20260612)
	var dash_hail: Array[Dictionary] = WeatherEventPayloadFactory.build_hail_impact_particles(
		Vector2(320.0, 640.0),
		14.0,
		true,
		hail_color
	)
	_verify_hail_payload(dash_hail, Vector2(320.0, 640.0), 14.0, true, hail_color)

	seed(20260612)
	var sand_color := Color(0.74, 0.58, 0.32, 1.0)
	var sand_particle: Dictionary = WeatherEventPayloadFactory.build_sand_dissolve_particle(
		Vector2(300.0, 500.0),
		Vector2(1.2, -0.4),
		sand_color
	)
	_expect(float(sand_particle.get("x", 0.0)) >= 296.0 and float(sand_particle.get("x", 0.0)) <= 304.0, "sand dissolve x should jitter within range")
	_expect(float(sand_particle.get("y", 0.0)) >= 496.0 and float(sand_particle.get("y", 0.0)) <= 504.0, "sand dissolve y should jitter within range")
	_expect(is_equal_approx(float(sand_particle.get("vx", 0.0)), 1.2), "sand dissolve vx should preserve velocity")
	_expect(is_equal_approx(float(sand_particle.get("vy", 0.0)), -0.4), "sand dissolve vy should preserve velocity")
	_expect(float(sand_particle.get("life", 0.0)) >= 20.0 and float(sand_particle.get("life", 0.0)) <= 45.0, "sand dissolve life should stay in range")
	_expect(is_equal_approx(float(sand_particle.get("max_life", 0.0)), 45.0), "sand dissolve max_life should stay tuned")
	_expect(float(sand_particle.get("size", 0.0)) >= 1.0 and float(sand_particle.get("size", 0.0)) <= 3.0, "sand dissolve size should stay in range")
	_expect(str(sand_particle.get("kind", "")) == "sand", "sand dissolve kind should stay sand")
	_expect(str(sand_particle.get("weather_type", "")) == "sand", "sand dissolve weather type should stay sand")
	_expect(sand_particle.get("color", null) == sand_color, "sand dissolve should use weather sand color")
	_expect(is_equal_approx(float(sand_particle.get("gravity", 0.0)), 0.15), "sand dissolve gravity should stay tuned")
	_expect(is_equal_approx(float(sand_particle.get("friction", 0.0)), 0.95), "sand dissolve friction should stay tuned")

	seed(20260612)
	var ice_color := Color(0.66, 0.90, 1.0, 1.0)
	var ice_particle: Dictionary = WeatherEventPayloadFactory.build_ice_slide_particle(
		Vector2(100.0, 200.0),
		715.0,
		1,
		ice_color
	)
	_expect(float(ice_particle.get("x", 0.0)) >= 110.0 and float(ice_particle.get("x", 0.0)) <= 235.0, "ice slide x should offset from source")
	_expect(float(ice_particle.get("y", 0.0)) >= 711.0 and float(ice_particle.get("y", 0.0)) <= 719.0, "ice slide y should jitter around lane")
	_expect(float(ice_particle.get("vx", 0.0)) >= -4.5 and float(ice_particle.get("vx", 0.0)) <= -1.5, "ice slide vx should oppose direction")
	_expect(float(ice_particle.get("vy", 99.0)) >= -2.5 and float(ice_particle.get("vy", 99.0)) <= 2.5, "ice slide vy should stay in range")
	_expect(float(ice_particle.get("life", 0.0)) >= 16.0 and float(ice_particle.get("life", 0.0)) <= 34.0, "ice slide life should stay in range")
	_expect(is_equal_approx(float(ice_particle.get("max_life", 0.0)), 34.0), "ice slide max_life should stay tuned")
	_expect(float(ice_particle.get("size", 0.0)) >= 2.0 and float(ice_particle.get("size", 0.0)) <= 5.0, "ice slide size should stay in range")
	_expect(str(ice_particle.get("kind", "")) == "ice", "ice slide kind should stay ice")
	_expect(str(ice_particle.get("weather_type", "")) == "ice", "ice slide weather type should stay ice")
	_expect(ice_particle.get("color", null) == ice_color, "ice slide should use weather ice color")

	seed(20260612)
	var sand_erosion: Dictionary = WeatherEventPayloadFactory.build_sand_erosion_particle(
		Vector2(150.0, 360.0),
		Vector2(-0.8, 1.7),
		sand_color
	)
	_expect(float(sand_erosion.get("x", 0.0)) >= 144.0 and float(sand_erosion.get("x", 0.0)) <= 156.0, "sand erosion x should jitter around source")
	_expect(float(sand_erosion.get("y", 0.0)) >= 354.0 and float(sand_erosion.get("y", 0.0)) <= 366.0, "sand erosion y should jitter around source")
	_expect(is_equal_approx(float(sand_erosion.get("vx", 0.0)), -0.8), "sand erosion vx should preserve velocity")
	_expect(is_equal_approx(float(sand_erosion.get("vy", 0.0)), 1.7), "sand erosion vy should preserve velocity")
	_expect(float(sand_erosion.get("life", 0.0)) >= 18.0 and float(sand_erosion.get("life", 0.0)) <= 35.0, "sand erosion life should stay in range")
	_expect(is_equal_approx(float(sand_erosion.get("max_life", 0.0)), 35.0), "sand erosion max_life should stay tuned")
	_expect(float(sand_erosion.get("size", 0.0)) >= 2.0 and float(sand_erosion.get("size", 0.0)) <= 4.0, "sand erosion size should stay in range")
	_expect(str(sand_erosion.get("kind", "")) == "sand", "sand erosion kind should stay sand")
	_expect(str(sand_erosion.get("weather_type", "")) == "sand", "sand erosion weather type should stay sand")
	_expect(sand_erosion.get("color", null) == sand_color, "sand erosion should use weather sand color")
	_expect(is_equal_approx(float(sand_erosion.get("gravity", 0.0)), 0.12), "sand erosion gravity should stay tuned")
	_expect(is_equal_approx(float(sand_erosion.get("friction", 0.0)), 0.95), "sand erosion friction should stay tuned")

	_verify_sand_kickup_payload(sand_color)

	var source := FileAccess.get_file_as_string("res://scripts/stages/common/weather_event_state.gd")
	_expect(source.find("WeatherEventPayloadFactory.build_fire_hit_explosion_particles") >= 0, "weather state should delegate fire hit payloads")
	_expect(source.find("WeatherEventPayloadFactory.build_hail_impact_particles") >= 0, "weather state should delegate hail impact payloads")
	_expect(source.find("WeatherEventPayloadFactory.build_sand_dissolve_particle") >= 0, "weather state should delegate sand dissolve payloads")
	_expect(source.find("WeatherEventPayloadFactory.build_ice_slide_particle") >= 0, "weather state should delegate ice slide payloads")
	_expect(source.find("WeatherEventPayloadFactory.build_sand_erosion_particle") >= 0, "weather state should delegate sand erosion payloads")
	_expect(source.find("WeatherEventPayloadFactory.build_sand_kickup_particle") >= 0, "weather state should delegate paddle sand kick-up payloads")

	var modules: Dictionary = GameplayStageModuleCatalog.MODULES
	_expect(modules.has("weather_event_payload_factory"), "stage module catalog should list the common weather payload factory")

	if _failures.is_empty():
		print("weather_event_payload_factory_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_sand_kickup_payload(sand_color: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260814
	var origin := Vector2(400.0, 712.0)
	# Bottom wall: outward = -1.0 means grains are thrown UP off the sand surface.
	var trailing: Dictionary = WeatherEventPayloadFactory.build_sand_kickup_particle(
		origin, 1.0, -1.0, 1.0, true, sand_color, rng
	)
	var bow: Dictionary = WeatherEventPayloadFactory.build_sand_kickup_particle(
		origin, 1.0, -1.0, 1.0, false, sand_color, rng
	)
	_expect(
		float(trailing.get("vx", 0.0)) < 0.0,
		"a trailing kick-up grain must be thrown OPPOSITE travel so a rightward dash leaves a wake behind it"
	)
	_expect(
		float(bow.get("vx", 0.0)) > 0.0,
		"a bow-spray kick-up grain must be thrown WITH travel so the plow front reads forward"
	)
	_expect(
		float(trailing.get("vy", 0.0)) < 0.0 and float(bow.get("vy", 0.0)) < 0.0,
		"bottom-wall kick-up must launch away from the sand (upward), not into it"
	)
	var ceiling: Dictionary = WeatherEventPayloadFactory.build_sand_kickup_particle(
		Vector2(400.0, 38.0), -1.0, 1.0, 1.0, true, sand_color, rng
	)
	_expect(
		float(ceiling.get("vy", 0.0)) > 0.0,
		"top-wall kick-up must fall away from the ceiling band, so outward flips with the side"
	)
	_expect(
		float(ceiling.get("vx", 0.0)) > 0.0,
		"trailing direction must mirror with travel_dir, not be hardcoded to one side"
	)
	# speed_scale coupling has to be measured against an IDENTICAL random draw, otherwise
	# any "fast grain is faster than some threshold" assertion just re-states the tuning
	# bands and passes whether or not speed_scale is wired to the velocity at all.
	var slow_rng := RandomNumberGenerator.new()
	slow_rng.seed = 991
	var fast_rng := RandomNumberGenerator.new()
	fast_rng.seed = 991
	var slow: Dictionary = WeatherEventPayloadFactory.build_sand_kickup_particle(
		origin, 1.0, -1.0, 1.0, true, sand_color, slow_rng
	)
	var fast: Dictionary = WeatherEventPayloadFactory.build_sand_kickup_particle(
		origin, 1.0, -1.0, 2.0, true, sand_color, fast_rng
	)
	_expect(
		is_equal_approx(float(fast.get("vy", 0.0)), float(slow.get("vy", 0.0)) * 2.0)
		and is_equal_approx(float(fast.get("vx", 0.0)), float(slow.get("vx", 0.0)) * 2.0),
		"speed_scale must multiply BOTH launch axes: doubling it on the same random draw must exactly double vx and vy, so a fast dash sprays proportionally harder"
	)
	# The grain must actually peak and fall back inside its own lifetime, or it reads as
	# a spark sailing off screen instead of kicked sand. Rise time = |vy| / gravity.
	for ballistic in [trailing, bow, fast]:
		_expect(
			absf(float(ballistic.get("vy", 0.0))) / maxf(0.001, float(ballistic.get("gravity", 0.0)))
			< float(ballistic.get("life", 0.0)),
			"a kick-up grain must reach its apex before its life expires, otherwise gravity is too weak for the launch speed and the spray never arcs back into the dune"
		)
	for particle in [trailing, bow, ceiling, fast]:
		var life: float = float(particle.get("life", 0.0))
		_expect(life >= 14.0 and life <= 24.0, "sand kick-up life should stay in range")
		_expect(
			is_equal_approx(float(particle.get("max_life", -1.0)), life),
			"sand kick-up max_life must equal life: a freshly kicked grain starts opaque, and the renderer tone hash reads max_life"
		)
		var grain_size: float = float(particle.get("size", 0.0))
		_expect(grain_size >= 1.4 and grain_size <= 3.4, "sand kick-up size should stay in range")
		_expect(str(particle.get("kind", "")) == "sand", "sand kick-up must reuse kind 'sand' so it inherits gravity/friction, cleanup, and the sand draw case")
		_expect(str(particle.get("weather_type", "")) == "sand", "sand kick-up weather type should stay sand")
		_expect(particle.get("color", null) == sand_color, "sand kick-up should use the weather sand color")
		var gravity: float = float(particle.get("gravity", 0.0))
		_expect(gravity >= 0.30 and gravity <= 0.62, "sand kick-up gravity should stay in the tuned band so grains arc back into the dune")
		var friction: float = float(particle.get("friction", 0.0))
		_expect(friction >= 0.84 and friction <= 0.91, "sand kick-up friction should stay in the tuned band")
		# Coarseness drives size, gravity and friction from ONE roll, so a heavy grain
		# must never come out with fine-grit drag and vice versa: that pairing is what
		# makes the spray stratify instead of moving as one uniform sheet.
		var coarseness: float = clampf((grain_size - 1.4) / 2.0, 0.0, 1.0)
		_expect(
			is_equal_approx(gravity, lerpf(0.30, 0.62, coarseness))
			and is_equal_approx(friction, lerpf(0.84, 0.91, coarseness)),
			"sand kick-up size, gravity and friction must all come from the same coarseness roll"
		)
	# The renderer derives grain tone AND fleck offset from exactly size + max_life, so a
	# constant in EITHER field tiles one identical grain. Asserted over a sample with a
	# distinct-count on each field independently — an OR across two grains would pass
	# while one of the two fields was pinned.
	var sample_rng := RandomNumberGenerator.new()
	sample_rng.seed = 4242
	var seen_sizes: Dictionary = {}
	var seen_lives: Dictionary = {}
	for sample_index in range(10):
		var grain: Dictionary = WeatherEventPayloadFactory.build_sand_kickup_particle(
			origin, 1.0, -1.0, 1.0, sample_index % 4 != 0, sand_color, sample_rng
		)
		seen_sizes[snappedf(float(grain.get("size", 0.0)), 0.001)] = true
		seen_lives[snappedf(float(grain.get("max_life", 0.0)), 0.001)] = true
	_expect(
		seen_sizes.size() >= 5,
		"grain size must vary per grain: the renderer's tone hash reads size, so pinning it tiles one identical grain"
	)
	_expect(
		seen_lives.size() >= 5,
		"grain max_life must vary per grain: the renderer's tone hash reads max_life too, so pinning it tiles one identical grain"
	)


func _verify_hail_payload(particles: Array[Dictionary], position: Vector2, size: float, dash_destroy: bool, hail_color: Color) -> void:
	var expected_shards: int = int(max(8.0, size * (2.5 if dash_destroy else 1.45)))
	var expected_dust: int = int(max(8.0, size * (5.0 if dash_destroy else 2.6)))
	_expect(particles.size() == 1 + expected_shards + expected_dust, "hail impact factory should create burst, shards, and dust")
	var burst_count := 0
	var shard_count := 0
	var dust_count := 0
	for particle in particles:
		_expect(is_equal_approx(float(particle.get("x", 0.0)), position.x), "hail particle should preserve x")
		_expect(is_equal_approx(float(particle.get("y", 0.0)), position.y), "hail particle should preserve y")
		_expect(str(particle.get("weather_type", "")) == "hail", "hail particle should keep weather type")
		_expect(particle.get("color", null) == hail_color, "hail particle should use weather hail color")
		match str(particle.get("kind", "")):
			"hail_burst":
				burst_count += 1
				_expect(is_equal_approx(float(particle.get("life", 0.0)), 12.0 if dash_destroy else 16.0), "hail burst life should match dash mode")
				_expect(float(particle.get("size", 0.0)) >= max(11.0, size * (2.05 if dash_destroy else 1.72)), "hail burst size should scale from source shard")
				_expect(float(particle.get("angle", -1.0)) >= 0.0 and float(particle.get("angle", -1.0)) <= PI * 0.5, "hail burst angle should stay in opening quadrant")
			"hail_shard":
				shard_count += 1
				var shard_min_life := 18.0 if dash_destroy else 14.0
				var shard_max_life := 32.0 if dash_destroy else 26.0
				var shard_min_size := 3.0 if dash_destroy else 2.5
				var shard_max_size := 7.0 if dash_destroy else 5.5
				_expect(float(particle.get("life", 0.0)) >= shard_min_life and float(particle.get("life", 0.0)) <= shard_max_life, "hail shard life should stay in range")
				_expect(float(particle.get("size", 0.0)) >= shard_min_size and float(particle.get("size", 0.0)) <= shard_max_size, "hail shard size should stay in range")
				_expect(float(particle.get("spin", 0.0)) >= -0.06 and float(particle.get("spin", 0.0)) <= 0.06, "hail shard spin should stay in range")
				_expect(is_equal_approx(float(particle.get("gravity", 0.0)), 0.22), "hail shard gravity should stay tuned")
			"hail_impact":
				dust_count += 1
				var dust_min_life := 20.0 if dash_destroy else 14.0
				var dust_max_life := 40.0 if dash_destroy else 28.0
				var dust_min_size := 3.0 if dash_destroy else 2.2
				var dust_max_size := 8.0 if dash_destroy else 5.6
				_expect(float(particle.get("life", 0.0)) >= dust_min_life and float(particle.get("life", 0.0)) <= dust_max_life, "hail dust life should stay in range")
				_expect(float(particle.get("size", 0.0)) >= dust_min_size and float(particle.get("size", 0.0)) <= dust_max_size, "hail dust size should stay in range")
				_expect(is_equal_approx(float(particle.get("gravity", 0.0)), 0.3), "hail dust gravity should stay tuned")
			_:
				_expect(false, "hail impact factory emitted an unknown particle kind")
	_expect(burst_count == 1, "hail impact factory should emit exactly one burst")
	_expect(shard_count == expected_shards, "hail impact factory should honor shard count")
	_expect(dust_count == expected_dust, "hail impact factory should honor dust count")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
