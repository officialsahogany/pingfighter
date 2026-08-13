extends RefCounted

# R2-C candidate guardian (수호령) locomotion over the compiled 2D navigation
# owner. Canonical 2D transposition of GRT-013: a ground/patrol guardian's
# position must always come from the compiled walkable set — scripted recall
# and teleport destinations are projected onto the walkable union (both X and
# Y may change to reach a valid lane), tracked movement goes through the same
# swept move the player uses (no straight interpolation across blockers), and
# only flight guardians may leave the walkable ground set. The 1D rule
# "keep current Y, change X only" is explicitly NOT the 2D canon.

const PlazaMapNavigationCompiled := preload("res://scripts/plaza/plaza_map_navigation_compiled.gd")

const STYLE_GROUND := "ground"
const STYLE_PATROL := "patrol"
const STYLE_FLIGHT := "flight"

const FOLLOW_STOP_DISTANCE_WORLD := 56.0
const FLIGHT_SPEED_WORLD_PER_SECOND := 240.0
const RECALL_PROJECTION_STEP_WORLD := 8.0
const RECALL_PROJECTION_MAX_RADIUS_WORLD := 320.0
const RECALL_PROJECTION_RING_SAMPLES := 16


static func is_ground_style(locomotion_style: String) -> bool:
	return locomotion_style == STYLE_GROUND or locomotion_style == STYLE_PATROL


static func compute_follow_step(
	compiled_navigation: Object,
	guardian_position: Vector2,
	player_position: Vector2,
	delta: float,
	locomotion_style: String
) -> Dictionary:
	if compiled_navigation == null or not bool(compiled_navigation.call("is_valid")):
		return _step_rejection(guardian_position, "invalid_navigation_owner")
	if not guardian_position.is_finite() or not player_position.is_finite():
		return _step_rejection(guardian_position, "invalid_actor_position")
	if not is_finite(delta) or delta < 0.0:
		return _step_rejection(guardian_position, "invalid_motion_input")

	var to_player := player_position - guardian_position
	if to_player.length() <= FOLLOW_STOP_DISTANCE_WORLD:
		return {
			"valid": true,
			"rejection_reason": "",
			"position": guardian_position,
			"blocked": false,
			"moved": false,
		}

	if locomotion_style == STYLE_FLIGHT:
		# Flight is exempt from the walkable ground set but never from world
		# bounds or finiteness.
		var world_size: Vector2 = compiled_navigation.call("get_world_size")
		var step := to_player.normalized() * FLIGHT_SPEED_WORLD_PER_SECOND * delta
		if step.length() > to_player.length():
			step = to_player
		var next_position := guardian_position + step
		next_position.x = clampf(next_position.x, 0.0, world_size.x)
		next_position.y = clampf(next_position.y, 0.0, world_size.y)
		return {
			"valid": true,
			"rejection_reason": "",
			"position": next_position,
			"blocked": false,
			"moved": not next_position.is_equal_approx(guardian_position),
		}

	# Ground/patrol: the guardian body sweeps through the same compiled
	# occupancy the player uses, so every intermediate sample stays inside the
	# walkable union and outside blockers.
	var move_result: Dictionary = compiled_navigation.call(
		"move_actor", guardian_position, to_player.normalized(), delta
	)
	if not bool(move_result.get("valid", false)):
		return _step_rejection(guardian_position, str(move_result.get("rejection_reason", "move_rejected")))
	var moved_position: Vector2 = move_result.get("actor_position", guardian_position)
	return {
		"valid": true,
		"rejection_reason": "",
		"position": moved_position,
		"blocked": bool(move_result.get("blocked", false)),
		"moved": not moved_position.is_equal_approx(guardian_position),
	}


static func project_recall_destination(
	compiled_navigation: Object,
	desired_position: Vector2,
	locomotion_style: String
) -> Dictionary:
	if compiled_navigation == null or not bool(compiled_navigation.call("is_valid")):
		return _projection_rejection("invalid_navigation_owner")
	if not desired_position.is_finite():
		return _projection_rejection("invalid_desired_position")

	if locomotion_style == STYLE_FLIGHT:
		var world_size: Vector2 = compiled_navigation.call("get_world_size")
		return {
			"valid": true,
			"rejection_reason": "",
			"position": Vector2(
				clampf(desired_position.x, 0.0, world_size.x),
				clampf(desired_position.y, 0.0, world_size.y)
			),
			"projected": false,
		}

	if bool(compiled_navigation.call("can_occupy", desired_position, true)):
		return {
			"valid": true,
			"rejection_reason": "",
			"position": desired_position,
			"projected": false,
		}

	# Bounded outward probe, NOT an exact nearest-point projection: 16 fixed rays
	# (TAU/16 apart, the same angles at every radius) sampled every
	# RECALL_PROJECTION_STEP_WORLD units out to RECALL_PROJECTION_MAX_RADIUS_WORLD.
	# Measured consequences on real generated layouts: (1) the landed placement is
	# nearest only up to the radial step, and can overshoot a nearer lane that no
	# ray crossed; (2) "no_walkable_projection" means "this probe budget found
	# nothing", NOT "the map has no legal placement" — misses are 0 while the true
	# nearest is under ~180 world units and appear only for a minority of
	# dead-zone points in the ~210-310 band.
	# What IS guaranteed, and is the actual contract here: a returned placement is
	# always full-body walkable, failure is always closed (never an invented or
	# off-walkable position, never a 1D "keep Y, change X" residue), both X and Y
	# are free so cross-lane recall is legal, and the result is deterministic.
	# R3 production wiring must either tighten the angular resolution (scale ring
	# samples with radius, and measure the resulting one-shot cost) or handle the
	# closed failure explicitly. Do not treat this as an exact projection.
	var radius := RECALL_PROJECTION_STEP_WORLD
	while radius <= RECALL_PROJECTION_MAX_RADIUS_WORLD:
		for sample_index in range(RECALL_PROJECTION_RING_SAMPLES):
			var angle := TAU * float(sample_index) / float(RECALL_PROJECTION_RING_SAMPLES)
			var candidate := desired_position + Vector2(cos(angle), sin(angle)) * radius
			if bool(compiled_navigation.call("can_occupy", candidate, true)):
				return {
					"valid": true,
					"rejection_reason": "",
					"position": candidate,
					"projected": true,
				}
		radius += RECALL_PROJECTION_STEP_WORLD
	return _projection_rejection("no_walkable_projection")


static func _step_rejection(guardian_position: Vector2, reason: String) -> Dictionary:
	return {
		"valid": false,
		"rejection_reason": reason,
		"position": guardian_position,
		"blocked": true,
		"moved": false,
	}


static func _projection_rejection(reason: String) -> Dictionary:
	return {
		"valid": false,
		"rejection_reason": reason,
		"position": Vector2.INF,
		"projected": false,
	}
