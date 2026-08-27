extends SceneTree

const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const CommandoSkillState := preload("res://scripts/characters/commando_skill_state.gd")
const CommandoSupplyDropFxHostLifecycle := preload("res://scripts/characters/commando_supply_drop_fx_host_lifecycle.gd")
const CommandoSupplyDropState := preload("res://scripts/characters/commando_supply_drop_state.gd")
const CommandoWeaponController := preload("res://scripts/characters/commando_weapon_controller.gd")

const HOST_PATH := "res://scripts/characters/commando_supply_drop_state.gd"
const LIFECYCLE_PATH := "res://scripts/characters/commando_supply_drop_fx_host_lifecycle.gd"

var _failures: Array[String] = []


class SupplyDropDrawProbe:
	extends Node2D

	var state: Object = null

	func _draw() -> void:
		if state != null:
			state.draw(self, Vector2.ZERO, {"game_offset": Vector2.ZERO, "render_scale": 1.0})


func _init() -> void:
	_verify_owner_boundary()
	call_deferred("_run")


func _run() -> void:
	await _verify_direct_lifecycle_contract()
	await _verify_production_reuse_and_reset()
	if _failures.is_empty():
		print("commando_supply_drop_fx_host_lifecycle_refactor_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_owner_boundary() -> void:
	var host_source := FileAccess.get_file_as_string(HOST_PATH)
	var owner_source := FileAccess.get_file_as_string(LIFECYCLE_PATH)
	_expect(
		host_source.find("const CommandoSupplyDropFxHostLifecycle := preload(\"%s\")" % LIFECYCLE_PATH) >= 0,
		"Supply Drop host should preload the focused FX-host lifecycle"
	)
	_expect(
		host_source.find("var _fx_host_lifecycle: Object = CommandoSupplyDropFxHostLifecycle.new()") >= 0,
		"Supply Drop host should retain one FX-host lifecycle instance"
	)
	for moved_marker in [
		"var fx_host =",
		"var fx_host_add_pending",
		"func _sync_fx_host(",
		"func _get_or_create_fx_host(",
		"func _tear_down_fx_host(",
		"func _is_valid_fx_host(",
		"func _is_fx_host_visible(",
	]:
		_expect(host_source.find(moved_marker) < 0, "Supply Drop host should not retain FX lifecycle marker %s" % moved_marker)
	for delegation in [
		"_fx_host_lifecycle.tear_down(false)",
		"_fx_host_lifecycle.sync(",
		"return _fx_host_lifecycle.get_host()",
		"_fx_host_lifecycle.is_visible()",
		"_fx_host_lifecycle.get_status()",
		"CommandoSupplyDropFxHostLifecycle.prewarm_assets()",
		"CommandoSupplyDropFxHostLifecycle.build_pipeline_status()",
	]:
		_expect(host_source.find(delegation) >= 0, "Supply Drop host should delegate %s" % delegation)
	for owner_marker in [
		"func sync(",
		"func get_or_create(",
		"func tear_down(",
		"func is_valid(",
		"func is_visible(",
		"func is_attached(",
		"func get_host(",
		"func get_status(",
	]:
		_expect(owner_source.find(owner_marker) >= 0, "FX-host lifecycle should implement %s" % owner_marker)


func _verify_direct_lifecycle_contract() -> void:
	var parent := Node2D.new()
	parent.name = "DirectLifecycleParent"
	get_root().add_child(parent)
	var lifecycle: Object = CommandoSupplyDropFxHostLifecycle.new()
	var snapshot := {
		"active": true,
		"aircraft_spawned": true,
		"aircraft_pos": Vector2(240.0, 130.0),
	}
	lifecycle.sync(parent, snapshot, Vector2(3.0, 4.0), true, {"game_offset": Vector2(10.0, 20.0), "render_scale": 1.25})
	var created: Object = lifecycle.get_host()
	_expect(created != null and is_instance_valid(created), "lifecycle should create an FX host for visible layers")
	_expect(lifecycle.is_visible(), "newly synchronized FX host should become visible")
	await process_frame
	await process_frame
	lifecycle.sync(parent, snapshot, Vector2.ZERO, true)
	var attached_status: Dictionary = lifecycle.get_status()
	_expect(lifecycle.is_attached(), "deferred FX host should attach to the requested canvas parent")
	_expect(bool(attached_status.get("attached", false)), "lifecycle status should expose attachment")
	_expect(not bool(attached_status.get("add_pending", true)), "lifecycle should clear its pending flag after attachment")

	lifecycle.sync(parent, {}, Vector2.ZERO, false)
	_expect(not lifecycle.is_visible(), "invisible synchronization should hide the retained FX host")
	_expect(lifecycle.get_host() == created, "hidden FX host should remain reusable")
	lifecycle.sync(parent, snapshot, Vector2.ZERO, true)
	_expect(lifecycle.get_host() == created and lifecycle.is_visible(), "reactivation should reuse and show the same FX host")
	lifecycle.tear_down(false)
	_expect(lifecycle.get_host() == created and not lifecycle.is_visible(), "non-free teardown should retain a hidden reusable host")
	lifecycle.tear_down(true)
	_expect(lifecycle.get_host() == null, "free teardown should release the lifecycle host reference")
	parent.queue_free()
	await process_frame


func _verify_production_reuse_and_reset() -> void:
	var state: Object = CommandoSupplyDropState.new()
	var probe := SupplyDropDrawProbe.new()
	probe.name = "SupplyDropLifecycleProductionProbe"
	probe.state = state
	get_root().add_child(probe)
	var deps := {
		"commando_weapon_controller": CommandoWeaponController.new(),
		"commando_supply_drop_direction": "left_to_right",
		"commando_supply_drop_payload_count": 1,
		"commando_supply_drop_forced_payloads": [{"type": "field_item", "item_id": "gauge_charge"}],
		"commando_supply_drop_aircraft_arrival_delay": 0.0,
		"commando_supply_drop_payload_delays": [1.15],
	}
	var activated: Dictionary = state.update_input(
		{"down_pressed": true, "action_pressed": true},
		1.0,
		500.0,
		CommandoSkillConfig.new(),
		CommandoSkillState.new(),
		deps
	)
	_expect(bool(activated.get("activated", false)), "production state should activate for lifecycle integration")
	probe.queue_redraw()
	await process_frame
	await process_frame
	var created: Object = state.get_fx_host()
	_expect(created != null and is_instance_valid(created), "production draw should expose its lifecycle-managed FX host")
	_expect(bool(state.build_vfx_remaster_plan().get("fx_host_attached", false)), "production plan should expose attached lifecycle status")
	state.reset()
	_expect(state.get_fx_host() == created, "production reset should retain the reusable FX host")
	_expect(not bool(created.get_debug_status().get("active", true)), "production reset should hide the retained FX host immediately")

	state.update_input(
		{"down_pressed": true, "action_pressed": true},
		1.0,
		500.0,
		CommandoSkillConfig.new(),
		CommandoSkillState.new(),
		deps
	)
	probe.queue_redraw()
	await process_frame
	await process_frame
	_expect(state.get_fx_host() == created, "production reactivation should reuse the same FX host")
	_expect(bool(created.get_debug_status().get("active", false)), "production reactivation should show the retained FX host")
	state.reset()
	probe.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
