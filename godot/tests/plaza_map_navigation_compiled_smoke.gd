extends SceneTree

# MEDIUM activation-gate seal for the compiled navigation owner: the compiled
# fast path must produce RESULT-IDENTICAL movement to the Dictionary-state
# reference on real generator layouts and on the 2px-slit fixture, stay immune
# to post-compile source mutation, and beat the per-tick-revalidating reference
# on steady p95 at the real 60Hz cadence.

const PlazaAssetLoader := preload("res://scripts/plaza/plaza_asset_loader.gd")
const PlazaMapLayoutGenerator := preload("res://scripts/plaza/plaza_map_layout_generator.gd")
const PlazaMapNavigation := preload("res://scripts/plaza/plaza_map_navigation.gd")
const PlazaMapNavigationCompiled := preload("res://scripts/plaza/plaza_map_navigation_compiled.gd")

const WORLD_SIZE := Vector2(2400.0, 1500.0)
const SPAWN_ANCHOR := Vector2(120.0, 666.0)
const EXIT_ZONE := Rect2(Vector2(2250.0, 596.0), Vector2(120.0, 92.0))
const FRAME_DELTA := 1.0 / 60.0
const PARITY_TICKS := 240
const PERF_WARMUP_TICKS := 60
const PERF_SAMPLE_TICKS := 600
const DENSEST_SEED_SCAN := 16
const COMPILED_P95_CEILING_USEC := 2000.0

var _failures: Array[String] = []


func _init() -> void:
	var representative := _bind_seed_layout(5)
	_expect(bool(representative.get("valid", false)), "seed 5 layout must bind for the compiled parity seal")

	var densest_seed := _find_densest_seed()
	var densest := _bind_seed_layout(densest_seed)
	_expect(bool(densest.get("valid", false)), "densest seed %d layout must bind for the perf seal" % densest_seed)

	_verify_compile_contract(representative)
	_verify_move_parity(representative, "seed5")
	_verify_move_parity(densest, "densest_seed_%d" % densest_seed)
	_verify_slit_parity()
	_verify_portal_toggle_parity(representative)
	_verify_mutation_immunity(representative)
	_verify_steady_p95(densest, densest_seed)

	if _failures.is_empty():
		print("plaza_map_navigation_compiled_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _bind_seed_layout(map_seed: int) -> Dictionary:
	var selected_specs := PlazaAssetLoader.build_hwangyeok_building_specs(1, map_seed, false, false)
	var layout := PlazaMapLayoutGenerator.generate(1, map_seed, WORLD_SIZE, selected_specs, SPAWN_ANCHOR, EXIT_ZONE)
	return PlazaMapNavigation.bind_layout(layout, str(layout.get("fingerprint", "")))


func _find_densest_seed() -> int:
	var densest_seed := 1
	var densest_count := -1
	for map_seed in range(1, DENSEST_SEED_SCAN + 1):
		var state := _bind_seed_layout(map_seed)
		if not bool(state.get("valid", false)):
			continue
		var count := 0
		for key in ["walkable_corridor_polygons", "interaction_portals", "blocked_polygons"]:
			count += (state.get(key, []) as Array).size()
		if count > densest_count:
			densest_count = count
			densest_seed = map_seed
	print("[NavPerf] densest seed=%d polygon_manifest_count=%d" % [densest_seed, densest_count])
	return densest_seed


func _verify_compile_contract(navigation_state: Dictionary) -> void:
	var compiled: Object = PlazaMapNavigationCompiled.compile(navigation_state)
	_expect(bool(compiled.call("is_valid")), "compile should accept a validated bound state")
	_expect(
		str(compiled.call("get_geometry_digest")) == str(navigation_state.get("geometry_digest", "")),
		"compiled owner should carry the bound geometry digest"
	)

	var tampered := navigation_state.duplicate(true)
	var corridors: Array = tampered.get("walkable_corridor_polygons", [])
	if not corridors.is_empty() and corridors[0] is Dictionary:
		var polygon: Array = []
		for point in (corridors[0] as Dictionary).get("polygon_world", []):
			polygon.append(point)
		if not polygon.is_empty():
			polygon[0] = (polygon[0] as Vector2) + Vector2(1.0, 0.0)
		(corridors[0] as Dictionary)["polygon_world"] = polygon
	var tampered_compiled: Object = PlazaMapNavigationCompiled.compile(tampered)
	_expect(not bool(tampered_compiled.call("is_valid")), "compile must reject a tampered bound state")

	var rejected: Object = PlazaMapNavigationCompiled.compile({"valid": false})
	_expect(not bool(rejected.call("is_valid")), "compile must reject an unbound state")


func _walk_direction(tick: int) -> Vector2:
	return Vector2(cos(float(tick) * 0.13), sin(float(tick) * 0.07))


func _verify_move_parity(navigation_state: Dictionary, label: String) -> void:
	var compiled: Object = PlazaMapNavigationCompiled.compile(navigation_state)
	if not bool(compiled.call("is_valid")):
		_expect(false, "%s: compiled owner must be valid for parity" % label)
		return
	var reference_position := SPAWN_ANCHOR
	var compiled_position := SPAWN_ANCHOR
	var divergence_count := 0
	var blocked_ticks := 0
	for tick in range(PARITY_TICKS):
		var direction := _walk_direction(tick)
		var reference: Dictionary = PlazaMapNavigation.move_actor(
			navigation_state, reference_position, direction, FRAME_DELTA
		)
		var candidate: Dictionary = compiled.call("move_actor", compiled_position, direction, FRAME_DELTA)
		if (
			bool(reference.get("valid", false)) != bool(candidate.get("valid", false))
			or str(reference.get("rejection_reason", "")) != str(candidate.get("rejection_reason", ""))
			or reference.get("actor_position", Vector2.INF) != candidate.get("actor_position", -Vector2.INF)
			or reference.get("applied_delta", Vector2.INF) != candidate.get("applied_delta", -Vector2.INF)
			or bool(reference.get("blocked", false)) != bool(candidate.get("blocked", false))
			or int(reference.get("sweep_substeps", -1)) != int(candidate.get("sweep_substeps", -2))
		):
			divergence_count += 1
			if divergence_count == 1:
				_expect(
					false,
					"%s tick %d: compiled result diverged (ref=%s cand=%s)" % [label, tick, reference, candidate]
				)
		if bool(reference.get("blocked", false)):
			blocked_ticks += 1
		reference_position = reference.get("actor_position", reference_position)
		compiled_position = candidate.get("actor_position", compiled_position)
	_expect(divergence_count == 0, "%s: %d/%d parity divergences" % [label, divergence_count, PARITY_TICKS])
	_expect(blocked_ticks > 0, "%s: parity walk must exercise blocked ticks to be non-vacuous" % label)
	_expect(
		reference_position != SPAWN_ANCHOR,
		"%s: parity walk must actually move the actor to be non-vacuous" % label
	)


func _verify_slit_parity() -> void:
	# Two corridors separated by a 2px slit: the 38px-wide actor must be
	# rejected in the gap by BOTH implementations.
	var fixture := {
		"schema_version": "plaza_map_navigation_qa_fixture_v1",
		"world_size": WORLD_SIZE,
		"walkable_corridor_polygons": [
			{"id": "slit_left", "edge_id": "e1", "edge_kind": "road", "polygon_world": [
				Vector2(100.0, 500.0), Vector2(400.0, 500.0), Vector2(400.0, 700.0), Vector2(100.0, 700.0),
			]},
			{"id": "slit_right", "edge_id": "e2", "edge_kind": "road", "polygon_world": [
				Vector2(402.0, 500.0), Vector2(700.0, 500.0), Vector2(700.0, 700.0), Vector2(402.0, 700.0),
			]},
		],
		"interaction_portals": [],
		"blocked_polygons": [],
	}
	var fingerprint := PlazaMapNavigation.build_qa_geometry_fixture_fingerprint(fixture)
	var state := PlazaMapNavigation.bind_qa_geometry_fixture(fixture, fingerprint)
	_expect(bool(state.get("valid", false)), "slit fixture must bind")
	var compiled: Object = PlazaMapNavigationCompiled.compile(state)
	_expect(bool(compiled.call("is_valid")), "slit fixture must compile")

	var gap_center := Vector2(401.0, 600.0)
	var reference_occupy := PlazaMapNavigation.can_occupy(state, gap_center, true)
	var compiled_occupy := bool(compiled.call("can_occupy", gap_center, true))
	_expect(not reference_occupy, "reference must reject the 2px slit center")
	_expect(compiled_occupy == reference_occupy, "compiled slit occupancy must match the reference")

	var start := Vector2(360.0, 600.0)
	var reference_walk := start
	var compiled_walk := start
	for _tick in range(40):
		var reference: Dictionary = PlazaMapNavigation.move_actor(state, reference_walk, Vector2.RIGHT, FRAME_DELTA)
		var candidate: Dictionary = compiled.call("move_actor", compiled_walk, Vector2.RIGHT, FRAME_DELTA)
		reference_walk = reference.get("actor_position", reference_walk)
		compiled_walk = candidate.get("actor_position", compiled_walk)
	_expect(reference_walk == compiled_walk, "slit wall walk must stay in parity (ref=%s cand=%s)" % [reference_walk, compiled_walk])
	_expect(
		reference_walk.x < 400.0 - PlazaMapNavigation.ACTOR_COLLISION_SIZE.x * 0.5 + 1.0,
		"the 2px slit must still stop the reference walk (x=%f)" % reference_walk.x
	)


func _verify_portal_toggle_parity(navigation_state: Dictionary) -> void:
	var compiled: Object = PlazaMapNavigationCompiled.compile(navigation_state)
	var toggle_checked := 0
	for portal in navigation_state.get("interaction_portals", []) as Array:
		if not (portal is Dictionary):
			continue
		var polygon: Array = (portal as Dictionary).get("polygon_world", [])
		if polygon.is_empty():
			continue
		var centroid := Vector2.ZERO
		for point in polygon:
			centroid += point as Vector2
		centroid /= float(polygon.size())
		for include_portals in [true, false]:
			var reference := PlazaMapNavigation.can_occupy(navigation_state, centroid, include_portals)
			var candidate := bool(compiled.call("can_occupy", centroid, include_portals))
			_expect(
				reference == candidate,
				"portal toggle parity failed at %s include=%s (ref=%s cand=%s)" % [centroid, include_portals, reference, candidate]
			)
			toggle_checked += 1
	_expect(toggle_checked > 0, "portal toggle parity must check at least one portal")


func _verify_mutation_immunity(navigation_state: Dictionary) -> void:
	var source := navigation_state.duplicate(true)
	var compiled: Object = PlazaMapNavigationCompiled.compile(source)
	var probe_direction := Vector2.RIGHT
	var before: Dictionary = compiled.call("move_actor", SPAWN_ANCHOR, probe_direction, FRAME_DELTA)

	var corridors: Array = source.get("walkable_corridor_polygons", [])
	_expect(not corridors.is_empty(), "mutation immunity needs at least one corridor")
	if not corridors.is_empty() and corridors[0] is Dictionary:
		var polygon: Array = []
		for point in (corridors[0] as Dictionary).get("polygon_world", []):
			polygon.append(point)
		if not polygon.is_empty():
			polygon[0] = (polygon[0] as Vector2) + Vector2(50.0, 0.0)
		(corridors[0] as Dictionary)["polygon_world"] = polygon

	var after: Dictionary = compiled.call("move_actor", SPAWN_ANCHOR, probe_direction, FRAME_DELTA)
	_expect(
		before.get("actor_position", Vector2.INF) == after.get("actor_position", -Vector2.INF)
		and bool(before.get("valid", false)) == bool(after.get("valid", false)),
		"post-compile source mutation must not reach the compiled geometry"
	)
	var reference_after: Dictionary = PlazaMapNavigation.move_actor(source, SPAWN_ANCHOR, probe_direction, FRAME_DELTA)
	_expect(
		not bool(reference_after.get("valid", true)),
		"the Dictionary reference must still go RED on the same mutation (contract preserved both ways)"
	)


func _verify_steady_p95(navigation_state: Dictionary, densest_seed: int) -> void:
	var compiled: Object = PlazaMapNavigationCompiled.compile(navigation_state)
	if not bool(compiled.call("is_valid")):
		_expect(false, "perf seal requires a valid compiled owner")
		return

	var reference_samples := _sample_move_usec_reference(navigation_state)
	var compiled_samples := _sample_move_usec_compiled(compiled)
	var reference_p95 := _percentile(reference_samples, 0.95)
	var compiled_p95 := _percentile(compiled_samples, 0.95)
	var reference_max := _percentile(reference_samples, 1.0)
	var compiled_max := _percentile(compiled_samples, 1.0)
	print("[NavPerf] seed=%d ticks=%d reference p95=%.1fus max=%.1fus | compiled p95=%.1fus max=%.1fus" % [
		densest_seed, PERF_SAMPLE_TICKS, reference_p95, reference_max, compiled_p95, compiled_max,
	])
	_expect(
		compiled_p95 <= reference_p95,
		"compiled p95 (%.1fus) must not exceed the per-tick-revalidating reference p95 (%.1fus)" % [compiled_p95, reference_p95]
	)
	_expect(
		compiled_p95 < COMPILED_P95_CEILING_USEC,
		"compiled p95 (%.1fus) must stay under the %.0fus activation ceiling" % [compiled_p95, COMPILED_P95_CEILING_USEC]
	)


func _sample_move_usec_reference(navigation_state: Dictionary) -> Array[float]:
	var samples: Array[float] = []
	var position := SPAWN_ANCHOR
	for tick in range(PERF_WARMUP_TICKS + PERF_SAMPLE_TICKS):
		var direction := _walk_direction(tick)
		var began := Time.get_ticks_usec()
		var result: Dictionary = PlazaMapNavigation.move_actor(navigation_state, position, direction, FRAME_DELTA)
		var elapsed := float(Time.get_ticks_usec() - began)
		if tick >= PERF_WARMUP_TICKS:
			samples.append(elapsed)
		position = result.get("actor_position", position)
	return samples


func _sample_move_usec_compiled(compiled: Object) -> Array[float]:
	var samples: Array[float] = []
	var position := SPAWN_ANCHOR
	for tick in range(PERF_WARMUP_TICKS + PERF_SAMPLE_TICKS):
		var direction := _walk_direction(tick)
		var began := Time.get_ticks_usec()
		var result: Dictionary = compiled.call("move_actor", position, direction, FRAME_DELTA)
		var elapsed := float(Time.get_ticks_usec() - began)
		if tick >= PERF_WARMUP_TICKS:
			samples.append(elapsed)
		position = result.get("actor_position", position)
	return samples


func _percentile(samples: Array[float], ratio: float) -> float:
	if samples.is_empty():
		return 0.0
	var sorted := samples.duplicate()
	sorted.sort()
	var index := clampi(int(floor(float(sorted.size()) * ratio)), 0, sorted.size() - 1)
	return sorted[index]


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
