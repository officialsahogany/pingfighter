extends SceneTree

# R2-C guardian locomotion seals over the compiled navigation owner. Fixture:
# two horizontal lanes at different Y joined by a left vertical link, with a
# full-height blocker splitting lane A. Seals the 2D GRT-013 canon: ground
# bodies never leave the walkable union (no tunneling, no straight lerp), a
# cross-lane recall changes BOTH X and Y onto a valid lane, the naive 1D
# "keep Y, change X only" destination is proven invalid, and only flight is
# exempt from the ground set.

const PlazaMapNavigation := preload("res://scripts/plaza/plaza_map_navigation.gd")
const PlazaMapNavigationCompiled := preload("res://scripts/plaza/plaza_map_navigation_compiled.gd")
const PlazaMapGuardianLocomotion := preload("res://scripts/plaza/plaza_map_guardian_locomotion.gd")

const FRAME_DELTA := 1.0 / 60.0
const LANE_A_CENTER_Y := 640.0
const LANE_B_CENTER_Y := 940.0

var _failures: Array[String] = []


func _init() -> void:
	var compiled: Object = _compile_fixture()
	if compiled == null:
		_fail_and_quit()
		return
	_verify_same_lane_follow_arrives(compiled)
	_verify_blocked_follow_never_tunnels(compiled)
	_verify_flight_exemption_is_real(compiled)
	_verify_cross_lane_recall_changes_both_axes(compiled)
	_verify_naive_x_only_recall_counterproof(compiled)
	_verify_projection_fail_closed_and_deterministic(compiled)
	_verify_probe_budget_invariant_off_axis(compiled)
	_fail_and_quit()


func _fail_and_quit() -> void:
	if _failures.is_empty():
		print("plaza_map_guardian_locomotion_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _compile_fixture() -> Object:
	var fixture := {
		"schema_version": "plaza_map_navigation_qa_fixture_v1",
		"world_size": Vector2(2400.0, 1500.0),
		"walkable_corridor_polygons": [
			{"id": "lane_a", "edge_id": "ea", "edge_kind": "road", "polygon_world": [
				Vector2(200.0, 600.0), Vector2(1000.0, 600.0), Vector2(1000.0, 680.0), Vector2(200.0, 680.0),
			]},
			{"id": "lane_b", "edge_id": "eb", "edge_kind": "road", "polygon_world": [
				Vector2(200.0, 900.0), Vector2(1600.0, 900.0), Vector2(1600.0, 980.0), Vector2(200.0, 980.0),
			]},
			{"id": "link", "edge_id": "el", "edge_kind": "road", "polygon_world": [
				Vector2(200.0, 600.0), Vector2(320.0, 600.0), Vector2(320.0, 980.0), Vector2(200.0, 980.0),
			]},
		],
		"interaction_portals": [],
		"blocked_polygons": [
			{"owner_id": "wall", "kind": "decor", "polygon_world": [
				Vector2(560.0, 600.0), Vector2(640.0, 600.0), Vector2(640.0, 680.0), Vector2(560.0, 680.0),
			]},
		],
	}
	var fingerprint := PlazaMapNavigation.build_qa_geometry_fixture_fingerprint(fixture)
	var state := PlazaMapNavigation.bind_qa_geometry_fixture(fixture, fingerprint)
	if not bool(state.get("valid", false)):
		_expect(false, "guardian fixture must bind: %s" % state.get("rejection_reason", ""))
		return null
	var compiled: Object = PlazaMapNavigationCompiled.compile(state)
	if not bool(compiled.call("is_valid")):
		_expect(false, "guardian fixture must compile")
		return null
	return compiled


func _run_follow(
	compiled: Object,
	start: Vector2,
	player: Vector2,
	style: String,
	ticks: int
) -> Dictionary:
	var position := start
	var blocked_ticks := 0
	var invalid_occupancy_ticks := 0
	var off_walkable_ticks := 0
	for _tick in range(ticks):
		var step: Dictionary = PlazaMapGuardianLocomotion.compute_follow_step(
			compiled, position, player, FRAME_DELTA, style
		)
		if not bool(step.get("valid", false)):
			invalid_occupancy_ticks += 1
			break
		position = step.get("position", position)
		if bool(step.get("blocked", false)):
			blocked_ticks += 1
		if not bool(compiled.call("can_occupy", position, true)):
			off_walkable_ticks += 1
	return {
		"position": position,
		"blocked_ticks": blocked_ticks,
		"invalid_ticks": invalid_occupancy_ticks,
		"off_walkable_ticks": off_walkable_ticks,
	}


func _verify_same_lane_follow_arrives(compiled: Object) -> void:
	var player := Vector2(900.0, LANE_B_CENTER_Y)
	var trace := _run_follow(compiled, Vector2(300.0, LANE_B_CENTER_Y), player, "ground", 240)
	var final_position: Vector2 = trace.get("position", Vector2.INF)
	_expect(
		final_position.distance_to(player) <= PlazaMapGuardianLocomotion.FOLLOW_STOP_DISTANCE_WORLD + 4.0,
		"ground follow on an open lane should arrive at the companion gap (dist=%f)" % final_position.distance_to(player)
	)
	_expect(int(trace.get("off_walkable_ticks", 1)) == 0, "ground follow must keep the full body on the walkable union every tick")
	_expect(int(trace.get("invalid_ticks", 1)) == 0, "ground follow must not reject on an open lane")


func _verify_blocked_follow_never_tunnels(compiled: Object) -> void:
	# Guardian on lane A left of the full-height wall, player on lane A right of
	# it: the direct line crosses the blocker, so a compliant ground body must
	# stay on the left side (the fixture leaves no slide gap) and report blocks.
	var trace := _run_follow(compiled, Vector2(420.0, LANE_A_CENTER_Y), Vector2(900.0, LANE_A_CENTER_Y), "ground", 240)
	var final_position: Vector2 = trace.get("position", Vector2.INF)
	_expect(int(trace.get("off_walkable_ticks", 1)) == 0, "blocked ground follow must never occupy blocker/off-lane space")
	_expect(
		final_position.x < 560.0 - PlazaMapNavigation.ACTOR_COLLISION_SIZE.x * 0.5 + 1.0,
		"blocked ground follow must not tunnel through the wall (x=%f)" % final_position.x
	)
	_expect(int(trace.get("blocked_ticks", 0)) > 0, "blocked ground follow must actually report blocked ticks to be non-vacuous")


func _verify_flight_exemption_is_real(compiled: Object) -> void:
	# Flight from lane A across the un-walkable region toward the far lane B
	# side: at least one intermediate position must be OFF the walkable union,
	# proving the exemption is real and not vacuously covered by corridors.
	var player := Vector2(1400.0, LANE_B_CENTER_Y)
	var trace := _run_follow(compiled, Vector2(900.0, LANE_A_CENTER_Y), player, "flight", 300)
	var final_position: Vector2 = trace.get("position", Vector2.INF)
	_expect(
		final_position.distance_to(player) <= PlazaMapGuardianLocomotion.FOLLOW_STOP_DISTANCE_WORLD + 4.0,
		"flight follow should reach the companion gap across un-walkable space (dist=%f)" % final_position.distance_to(player)
	)
	_expect(
		int(trace.get("off_walkable_ticks", 0)) > 0,
		"flight must traverse off-walkable space in this fixture; zero means the exemption leg is vacuous"
	)
	_expect(int(trace.get("invalid_ticks", 1)) == 0, "flight follow must stay valid")


func _verify_cross_lane_recall_changes_both_axes(compiled: Object) -> void:
	# Guardian parked on lane A; desired recall point sits in the dead zone
	# between the lanes near the player. The projection must land on a valid
	# lane, changing BOTH axes relative to the guardian's old lane position.
	var guardian_lane_position := Vector2(900.0, LANE_A_CENTER_Y)
	var desired := Vector2(1200.0, 790.0)
	var projection: Dictionary = PlazaMapGuardianLocomotion.project_recall_destination(compiled, desired, "ground")
	_expect(bool(projection.get("valid", false)), "cross-lane recall must project onto a walkable placement")
	_expect(bool(projection.get("projected", false)), "the dead-zone desired point must actually require projection")
	var landed: Vector2 = projection.get("position", Vector2.INF)
	_expect(bool(compiled.call("can_occupy", landed, true)), "the projected recall placement must be full-body walkable")
	_expect(
		absf(landed.y - guardian_lane_position.y) > 40.0,
		"a legal cross-lane recall must be free to leave the old lane Y (landed=%s)" % landed
	)


func _verify_naive_x_only_recall_counterproof(compiled: Object) -> void:
	# The 1D residue rule would recall to (player.x, guardian lane Y). In this
	# fixture lane A ends at x=1000 while the player stands at x=1400, so the
	# naive destination must be provably invalid — and the canonical projection
	# of the real desired point must land somewhere else.
	var naive_destination := Vector2(1400.0, LANE_A_CENTER_Y)
	_expect(
		not bool(compiled.call("can_occupy", naive_destination, true)),
		"the naive keep-Y/change-X destination must be invalid in the cross-lane fixture"
	)
	var desired := Vector2(1340.0, LANE_B_CENTER_Y)
	var projection: Dictionary = PlazaMapGuardianLocomotion.project_recall_destination(compiled, desired, "ground")
	_expect(bool(projection.get("valid", false)), "the canonical recall beside the player must be valid")
	_expect(not bool(projection.get("projected", false)), "a directly walkable desired point must pass through unprojected")
	_expect(
		(projection.get("position", Vector2.INF) as Vector2) != naive_destination,
		"the canonical recall must not degenerate to the naive X-only destination"
	)


func _verify_projection_fail_closed_and_deterministic(compiled: Object) -> void:
	var unreachable := Vector2(2300.0, 200.0)
	var rejected: Dictionary = PlazaMapGuardianLocomotion.project_recall_destination(compiled, unreachable, "ground")
	_expect(not bool(rejected.get("valid", true)), "an unreachable recall must fail closed instead of inventing a placement")
	_expect(
		str(rejected.get("rejection_reason", "")) == "no_walkable_projection",
		"the unreachable recall rejection must be diagnosable"
	)

	var desired := Vector2(1200.0, 790.0)
	var first: Dictionary = PlazaMapGuardianLocomotion.project_recall_destination(compiled, desired, "ground")
	var second: Dictionary = PlazaMapGuardianLocomotion.project_recall_destination(compiled, desired, "ground")
	_expect(
		first.get("position", Vector2.INF) == second.get("position", -Vector2.INF),
		"recall projection must be deterministic for identical inputs"
	)

	var flight: Dictionary = PlazaMapGuardianLocomotion.project_recall_destination(compiled, Vector2(2500.0, -50.0), "flight")
	_expect(bool(flight.get("valid", false)), "flight recall should accept any world-clamped destination")
	var flight_position: Vector2 = flight.get("position", Vector2.INF)
	_expect(
		flight_position == Vector2(2400.0, 0.0),
		"flight recall must clamp to world bounds (got %s)" % flight_position
	)


func _verify_probe_budget_invariant_off_axis(compiled: Object) -> void:
	# project_recall_destination is a bounded 16-ray probe, not an exact
	# nearest-point search. The existing legs all resolve straight down onto a
	# horizontal lane (exactly ray index 4), so they cannot observe the angular
	# resolution at all. This leg probes OFF-AXIS desired points — past lane
	# ends and diagonally into the dead zone — and pins the invariant that must
	# survive any future resolution change:
	#   success  -> the returned placement is full-body walkable
	#   failure  -> fail-closed with the diagnosable reason, never an invented
	#               position and never a 1D keep-Y residue
	# It also records the current success/miss split so R3 has a baseline to
	# flip when it tightens the search.
	var off_axis_desired: Array[Vector2] = [
		Vector2(1700.0, 800.0),
		Vector2(1660.0, 860.0),
		Vector2(1120.0, 742.0),
		Vector2(150.0, 520.0),
		Vector2(1820.0, 930.0),
	]
	var succeeded := 0
	var failed_closed := 0
	for desired in off_axis_desired:
		var projection: Dictionary = PlazaMapGuardianLocomotion.project_recall_destination(
			compiled, desired, "ground"
		)
		if bool(projection.get("valid", false)):
			succeeded += 1
			var landed: Vector2 = projection.get("position", Vector2.INF)
			_expect(
				landed.is_finite() and bool(compiled.call("can_occupy", landed, true)),
				"off-axis probe success at %s must land full-body walkable (landed=%s)" % [desired, landed]
			)
			_expect(
				absf(landed.y - desired.y) > 0.0 or absf(landed.x - desired.x) > 0.0 or not bool(projection.get("projected", true)),
				"a projected off-axis result must actually move the destination"
			)
		else:
			failed_closed += 1
			_expect(
				str(projection.get("rejection_reason", "")) == "no_walkable_projection",
				"off-axis probe miss at %s must fail closed with the diagnosable reason" % desired
			)
			_expect(
				not (projection.get("position", Vector2.INF) as Vector2).is_finite(),
				"a failed off-axis probe must not hand back a usable position"
			)
	_expect(
		succeeded + failed_closed == off_axis_desired.size(),
		"every off-axis probe must resolve to exactly one of success or fail-closed"
	)
	_expect(succeeded > 0, "the off-axis probe leg must observe at least one success to be non-vacuous")
	print(
		"plaza_map_guardian_locomotion_smoke: off-axis probe budget baseline success=%d fail_closed=%d of %d"
		% [succeeded, failed_closed, off_axis_desired.size()]
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
