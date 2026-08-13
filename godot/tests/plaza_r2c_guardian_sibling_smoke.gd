extends SceneTree

# R2-C actor-promotion seal: the guardian (수호령) is a direct Y-sort sibling
# of the player wrapper on the candidate host. Seals sibling/zero-z contract,
# foot-anchor projection, sort straddle around a building anchor, stale-request
# hiding, and fail-closed rejection of invalid guardian input.

const PlazaAssetLoader := preload("res://scripts/plaza/plaza_asset_loader.gd")
const PlazaMapLayoutGenerator := preload("res://scripts/plaza/plaza_map_layout_generator.gd")
const PlazaMapProjection := preload("res://scripts/plaza/plaza_map_projection.gd")
const PlazaR2MapWorldCandidateHost := preload("res://scripts/plaza/plaza_r2_map_world_candidate_host.gd")

const WORLD_SIZE := Vector2(2400.0, 1500.0)
const VIEW_SIZE := Vector2(2020.0, 1246.0)
const SPAWN_ANCHOR := Vector2(120.0, 666.0)
const EXIT_ZONE := Rect2(2250.0, 596.0, 120.0, 92.0)
const SAFE_INSETS := {
	"left": 72.0,
	"top": 72.0,
	"right": 360.0,
	"bottom": 120.0,
}

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var specs := PlazaAssetLoader.build_hwangyeok_building_specs(1, 5, false, false)
	var layout := PlazaMapLayoutGenerator.generate(1, 5, WORLD_SIZE, specs, SPAWN_ANCHOR, EXIT_ZONE)
	_expect(bool((layout.get("validation", {}) as Dictionary).get("valid", false)), "seed 5 source layout must be valid")
	var bank := _find_by_type(layout.get("building_specs", []), "bank")
	_expect(not bank.is_empty(), "seed 5 fixture must include bank")
	if bank.is_empty():
		_finish()
		return
	var bank_anchor := bank.get("sort_anchor_world", Vector2.ZERO) as Vector2
	var player_world := bank_anchor + Vector2(0.0, 14.0)

	var host := PlazaR2MapWorldCandidateHost.new()
	host.name = "PlazaR2CGuardianHost"
	root.add_child(host)

	_verify_guardian_absent_backward_compat(host, layout, player_world)
	_verify_guardian_sibling_contract(host, layout, player_world, bank_anchor)
	_verify_guardian_sort_straddle(host, layout, player_world, bank_anchor)
	_verify_guardian_fail_closed(host, layout, player_world)
	_verify_stale_guardian_request_hides(host, layout, player_world)

	host.free()
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("plaza_r2c_guardian_sibling_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _build_state(layout: Dictionary, player_world: Vector2, ticks_msec: int) -> Dictionary:
	return {
		"render_size": VIEW_SIZE,
		"safe_insets": SAFE_INSETS,
		"layout": layout,
		"player_world_pos": player_world,
		"camera_center_world": WORLD_SIZE * 0.5,
		"camera_zoom": 1.0,
		"ticks_msec": ticks_msec,
	}


func _verify_guardian_absent_backward_compat(host: Control, layout: Dictionary, player_world: Vector2) -> void:
	_expect(host.sync_state(_build_state(layout, player_world, 1000)), "guardian-less state must keep syncing")
	var status := host.call("get_debug_status") as Dictionary
	var sort_status := status.get("sort_contract", {}) as Dictionary
	_expect(bool(sort_status.get("valid", false)), "sort contract must stay valid without a guardian request")
	_expect(not bool(sort_status.get("guardian_requested", true)), "an omitted guardian must not be marked requested")
	var guardian_item := host.call("get_guardian_sort_item_for_test") as Node2D
	_expect(guardian_item != null, "the guardian sibling node must exist in the retained tree")
	_expect(guardian_item != null and not guardian_item.visible, "an unrequested guardian must stay hidden")


func _verify_guardian_sibling_contract(
	host: Control,
	layout: Dictionary,
	player_world: Vector2,
	bank_anchor: Vector2
) -> void:
	var guardian_world := player_world + Vector2(-90.0, 26.0)
	var state := _build_state(layout, player_world, 1010)
	state["guardian_world_pos"] = guardian_world
	state["guardian_rect_relative_world"] = Rect2(-30.0, -80.0, 60.0, 90.0)
	state["guardian_color"] = Color(0.72, 0.55, 1.0, 1.0)
	_expect(host.sync_state(state), "guardian state must sync")

	var status := host.call("get_debug_status") as Dictionary
	var sort_status := status.get("sort_contract", {}) as Dictionary
	_expect(bool(sort_status.get("valid", false)), "sort contract must hold with an active guardian")
	_expect(bool(sort_status.get("guardian_requested", false)), "a provided guardian must be marked requested")
	_expect(bool(sort_status.get("guardian_wrapper_visible", false)), "the requested guardian wrapper must be visible")
	_expect(bool(sort_status.get("guardian_body_visible", false)), "the requested guardian body must be visible")

	var actor_item := host.call("get_actor_sort_item_for_test") as Node2D
	var guardian_item := host.call("get_guardian_sort_item_for_test") as Node2D
	_expect(actor_item != null and guardian_item != null, "both actor and guardian siblings must exist")
	if actor_item == null or guardian_item == null:
		return
	_expect(guardian_item.get_parent() == actor_item.get_parent(), "guardian must be a DIRECT sibling of the player wrapper")
	_expect(guardian_item.z_index == 0 and guardian_item.z_as_relative and not guardian_item.top_level, "guardian wrapper must keep the zero-z relative contract")
	_expect(
		(guardian_item.get_meta("sort_anchor_world", Vector2.INF) as Vector2) == guardian_world,
		"guardian sort anchor must be its own world position, not the player's"
	)
	var projection := host.call("get_projection_snapshot_for_test") as Dictionary
	var expected_foot := PlazaMapProjection.world_to_screen(guardian_world, projection)
	_expect(
		guardian_item.position.is_equal_approx(expected_foot),
		"guardian wrapper must sit on its own projected foot anchor (got %s want %s)" % [guardian_item.position, expected_foot]
	)
	_expect(bank_anchor.is_finite(), "bank anchor must stay finite for the straddle leg")


func _verify_guardian_sort_straddle(
	host: Control,
	layout: Dictionary,
	player_world: Vector2,
	bank_anchor: Vector2
) -> void:
	# Structural Y-sort proof: the guardian's projected foot must land above the
	# bank anchor when behind it and below when in front, flipping its paint
	# order relative to the building item. Pixel occlusion stays sealed by the
	# candidate Vulkan QA.
	var behind := bank_anchor + Vector2(60.0, -40.0)
	var in_front := bank_anchor + Vector2(60.0, 52.0)
	var bank_item := host.call("get_building_sort_item_for_test", "bank") as Node2D
	_expect(bank_item != null, "bank sort item must exist for the straddle leg")
	if bank_item == null:
		return

	var state_behind := _build_state(layout, player_world, 1020)
	state_behind["guardian_world_pos"] = behind
	_expect(host.sync_state(state_behind), "behind-anchor guardian state must sync")
	var guardian_item := host.call("get_guardian_sort_item_for_test") as Node2D
	_expect(
		guardian_item != null and guardian_item.position.y < bank_item.position.y,
		"a guardian behind the bank anchor must paint before the bank (guardian_y < bank_y)"
	)

	var state_front := _build_state(layout, player_world, 1030)
	state_front["guardian_world_pos"] = in_front
	_expect(host.sync_state(state_front), "front-anchor guardian state must sync")
	_expect(
		guardian_item != null and guardian_item.position.y > bank_item.position.y,
		"a guardian in front of the bank anchor must paint after the bank (guardian_y > bank_y)"
	)


func _verify_guardian_fail_closed(host: Control, layout: Dictionary, player_world: Vector2) -> void:
	var out_of_world := _build_state(layout, player_world, 1040)
	out_of_world["guardian_world_pos"] = Vector2(WORLD_SIZE.x + 500.0, 100.0)
	_expect(not host.sync_state(out_of_world), "an out-of-world guardian must reject the sync")
	var status := host.call("get_debug_status") as Dictionary
	_expect(str(status.get("last_sync_rejection_reason", "")) == "guardian_out_of_world", "the out-of-world guardian rejection must be diagnosable")
	_expect(not bool(status.get("active", true)), "a rejected guardian sync must leave the host fail-closed")
	_expect(not bool(status.get("guardian_visible", true)), "a rejected guardian sync must hide the guardian")

	var bad_type := _build_state(layout, player_world, 1050)
	bad_type["guardian_world_pos"] = "not_a_vector"
	_expect(not host.sync_state(bad_type), "a mistyped guardian position must reject the sync")
	status = host.call("get_debug_status") as Dictionary
	_expect(str(status.get("last_sync_rejection_reason", "")) == "invalid_guardian_world_pos_type", "the mistyped guardian rejection must be diagnosable")


func _verify_stale_guardian_request_hides(host: Control, layout: Dictionary, player_world: Vector2) -> void:
	var with_guardian := _build_state(layout, player_world, 1060)
	with_guardian["guardian_world_pos"] = player_world + Vector2(-80.0, 20.0)
	_expect(host.sync_state(with_guardian), "guardian state must sync before the stale-request leg")
	var without_guardian := _build_state(layout, player_world, 1070)
	_expect(host.sync_state(without_guardian), "guardian-less resync must succeed")
	var guardian_item := host.call("get_guardian_sort_item_for_test") as Node2D
	_expect(guardian_item != null and not guardian_item.visible, "a stale guardian request must not keep a ghost guardian visible")
	var status := host.call("get_debug_status") as Dictionary
	var sort_status := status.get("sort_contract", {}) as Dictionary
	_expect(bool(sort_status.get("valid", false)), "the contract must stay valid after the guardian request goes stale")

	host.call("clear_transient_canvas_items")
	_expect(guardian_item != null and not guardian_item.visible, "clear_transient_canvas_items must hide the guardian")


func _find_by_type(spec_values: Variant, building_type: String) -> Dictionary:
	if not (spec_values is Array):
		return {}
	for spec_value in spec_values as Array:
		if spec_value is Dictionary and str((spec_value as Dictionary).get("type", "")) == building_type:
			return spec_value as Dictionary
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
