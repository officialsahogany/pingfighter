extends SceneTree

const BallContactDeformationState := preload(
	"res://scripts/ball/ball_contact_deformation_state.gd"
)
const BallRenderer := preload("res://scripts/ball/ball_renderer.gd")

const FAST_EVENT := {
	"id": 71,
	"pos": Vector2(380.0, 680.0),
	"velocity": Vector2(0.0, -35.0),
	"intensity": 1.0,
	"kind": "player_paddle",
}

var _failures: Array[String] = []


func _init() -> void:
	_verify_three_phase_motion_and_area_preservation()
	_verify_speed_scaling_and_event_lifecycle()
	_verify_directional_point_mapping()
	_verify_production_gates_and_transform_safety()

	if _failures.is_empty():
		print("ball_contact_squash_stretch_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_three_phase_motion_and_area_preservation() -> void:
	var state := BallContactDeformationState.new()
	state.sync_event(FAST_EVENT, 1000.0)
	var impact: Dictionary = state.get_snapshot(1000.0)
	var held: Dictionary = state.get_snapshot(1016.0)
	var launch: Dictionary = state.get_snapshot(1042.0)
	var settle: Dictionary = state.get_snapshot(1095.0)
	var expired: Dictionary = state.get_snapshot(1113.0)

	_expect(str(impact.get("phase", "")) == "compression", "contact frame should begin in compression")
	_expect(float(impact.get("axis_scale", 1.0)) <= 0.77, "a maximum-speed hit should visibly compress along the collision axis")
	_expect(float(held.get("axis_scale", 1.0)) < 0.84, "compression should survive at least one 60 Hz display frame")
	_expect(str(launch.get("phase", "")) == "launch_stretch", "the second phase should identify launch stretch")
	_expect(float(launch.get("axis_scale", 1.0)) >= 1.15, "the launch peak should stretch along outgoing velocity")
	_expect(float(launch.get("perpendicular_scale", 1.0)) < 0.94, "launch stretch should narrow across outgoing velocity")
	_expect(str(settle.get("phase", "")) == "settle", "the final phase should be a small elastic settle")
	_expect(absf(float(settle.get("axis_scale", 1.0)) - 1.0) < 0.035, "settle should stay subtle before returning to a circle")
	_expect(expired.is_empty(), "the presentation-only deformation should expire after 112 ms")

	for snapshot in [impact, held, launch, settle]:
		var area_scale: float = (
			float(snapshot.get("axis_scale", 1.0))
			* pow(float(snapshot.get("perpendicular_scale", 1.0)), 2.0)
		)
		_expect(is_equal_approx(area_scale, 1.0), "every phase should preserve approximate projected volume")


func _verify_speed_scaling_and_event_lifecycle() -> void:
	var medium_state := BallContactDeformationState.new()
	medium_state.sync_event({
		"id": 72,
		"velocity": Vector2(0.0, -23.5),
		"kind": "player_paddle",
	}, 2000.0)
	var medium: Dictionary = medium_state.get_snapshot(2000.0)
	_expect(
		float(medium.get("axis_scale", 0.0)) > 0.84,
		"mid-speed contact should compress less than a maximum-speed hit"
	)

	var low_state := BallContactDeformationState.new()
	low_state.sync_event({
		"id": 73,
		"velocity": Vector2(0.0, -BallContactDeformationState.SPEED_START),
		"kind": "player_paddle",
	}, 3000.0)
	_expect(low_state.get_snapshot(3000.0).is_empty(), "low-speed contact should remain round")

	var duplicate_state := BallContactDeformationState.new()
	duplicate_state.sync_event(FAST_EVENT, 4000.0)
	var launch_before_duplicate: Dictionary = duplicate_state.get_snapshot(4042.0)
	duplicate_state.sync_event(FAST_EVENT, 4042.0)
	var launch_after_duplicate: Dictionary = duplicate_state.get_snapshot(4042.0)
	_expect(
		launch_after_duplicate == launch_before_duplicate,
		"a persistent hit event must not restart compression every draw frame"
	)
	duplicate_state.sync_event({
		"id": 74,
		"velocity": Vector2(35.0, 0.0),
		"kind": "wall",
	}, 4050.0)
	_expect(duplicate_state.get_snapshot(4050.0).is_empty(), "wall events should not reuse the paddle squash")
	duplicate_state.clear()
	duplicate_state.sync_event(FAST_EVENT, 5000.0)
	_expect(not duplicate_state.get_snapshot(5000.0).is_empty(), "round cleanup should allow a reused event id to start fresh")


func _verify_directional_point_mapping() -> void:
	var state := BallContactDeformationState.new()
	state.sync_event(FAST_EVENT, 6000.0)
	var impact: Dictionary = state.get_snapshot(6000.0)
	var pivot := Vector2(100.0, 100.0)
	var along := pivot + Vector2.UP * 10.0
	var across := pivot + Vector2.RIGHT * 10.0
	var mapped_pivot: Vector2 = BallContactDeformationState.map_point(pivot, pivot, impact)
	var mapped_along: Vector2 = BallContactDeformationState.map_point(along, pivot, impact)
	var mapped_across: Vector2 = BallContactDeformationState.map_point(across, pivot, impact)
	_expect(mapped_pivot == pivot, "deformation should remain centered on the rendered ball")
	_expect(mapped_along.distance_to(pivot) < 8.0, "impact should shorten geometry along outgoing velocity")
	_expect(mapped_across.distance_to(pivot) > 11.0, "impact should widen geometry perpendicular to outgoing velocity")


func _verify_production_gates_and_transform_safety() -> void:
	_expect(not _resolve_for_context({}, "energy", false, "").is_empty(), "default energy ball should consume the contact deformation")
	_expect(_resolve_for_context({"ball_contact_deformation_enabled": false}, "energy", false, "").is_empty(), "explicit reverse flag should keep the original round ball")
	_expect(_resolve_for_context({}, "pingpong", false, "").is_empty(), "ping-pong identity should remain round")
	_expect(_resolve_for_context({}, "prism", true, "").is_empty(), "prism identity should remain round")
	_expect(_resolve_for_context({"bomb_ball_loaded": true}, "energy", false, "").is_empty(), "bomb identity should remain round")
	_expect(_resolve_for_context({}, "energy", false, "drive").is_empty(), "Drive should keep its dedicated ball presentation")

	var quad_source: String = FileAccess.get_file_as_string(
		"res://scripts/ball/ball_deformation_texture_quad.gd"
	)
	var energy_source: String = FileAccess.get_file_as_string(
		"res://scripts/ball/energy_ball_renderer.gd"
	)
	_expect(
		quad_source.find("canvas." + "draw_set_transform(") < 0
		and energy_source.find("canvas." + "draw_set_transform(") < 0,
		"ball deformation must preserve the parent playfield transform"
	)
	_expect(quad_source.contains("draw_polygon(points, colors, uvs, texture)"), "deformed textures should use a direct textured quad")
	_expect(energy_source.contains("_apply_node_fx_deformation"), "the detached shader core should share the body deformation")


func _resolve_for_context(
	context: Dictionary,
	visual_type: String,
	draw_as_prism: bool,
	skill_fx_mode: String
) -> Dictionary:
	var renderer := BallRenderer.new()
	return renderer._resolve_contact_deformation(
		context,
		visual_type,
		draw_as_prism,
		skill_fx_mode,
		FAST_EVENT,
		7000.0
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
