extends SceneTree

const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const CommandoSkillState := preload("res://scripts/characters/commando_skill_state.gd")
const CommandoSupplyDropState := preload("res://scripts/characters/commando_supply_drop_state.gd")
const CommandoSupplyDropPresentationRenderer := preload("res://scripts/characters/commando_supply_drop_presentation_renderer.gd")
const CommandoWeaponController := preload("res://scripts/characters/commando_weapon_controller.gd")

const HOST_PATH := "res://scripts/characters/commando_supply_drop_state.gd"
const RENDERER_PATH := "res://scripts/characters/commando_supply_drop_presentation_renderer.gd"

var _failures: Array[String] = []


func _init() -> void:
	_verify_owner_boundary()
	_verify_draw_plan_normalization()
	_verify_payload_sprite_status()
	_verify_production_context_facade()
	if _failures.is_empty():
		print("commando_supply_drop_presentation_renderer_refactor_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_owner_boundary() -> void:
	var host_source := FileAccess.get_file_as_string(HOST_PATH)
	var renderer_source := FileAccess.get_file_as_string(RENDERER_PATH)
	_expect(
		host_source.find("const CommandoSupplyDropPresentationRenderer := preload(\"%s\")" % RENDERER_PATH) >= 0,
		"Supply Drop host should preload the focused presentation renderer"
	)
	_expect(
		host_source.find("CommandoSupplyDropPresentationRenderer.draw(canvas, _build_presentation_context(shake_offset))") >= 0,
		"Supply Drop host should delegate its CanvasItem draw pass through one context"
	)
	_expect(
		host_source.find("return CommandoSupplyDropPresentationRenderer.build_payload_sprite_status()") >= 0,
		"Supply Drop host should delegate payload sprite status"
	)
	_expect(
		host_source.find("CommandoSupplyDropPresentationRenderer.prewarm_assets()") >= 0,
		"Supply Drop host should delegate presentation prewarm"
	)
	for moved_marker in [
		"func _draw_hold_gauge(",
		"func _draw_supply_texture_layers(",
		"func _draw_aircraft_texture_layer(",
		"func _draw_parachute_texture_layer(",
		"func _draw_explosion_texture_layer(",
		"func _draw_aircraft(",
		"func _draw_explosion_effect(",
		"func _draw_drop_effect(",
		"func _draw_supply_payload_sprite(",
		"func _draw_collectible_drop(",
		"static func _get_supply_payload_texture(",
	]:
		_expect(host_source.find(moved_marker) < 0, "Supply Drop host should not retain presentation marker %s" % moved_marker)
	_expect(host_source.find("canvas.draw_") < 0, "Supply Drop host should not retain direct CanvasItem drawing")
	for moved_dependency in [
		"const ImpactFlareTextureCache := preload(",
		"const ImpactShockwaveTextureCache := preload(",
		"const ProjectResourceLoader := preload(",
	]:
		_expect(host_source.find(moved_dependency) < 0, "Supply Drop host should not retain presentation dependency %s" % moved_dependency)
	for owner_marker in [
		"static func draw(",
		"static func build_draw_plan(",
		"static func build_payload_sprite_status(",
		"static func prewarm_assets(",
		"static func _draw_aircraft(",
		"static func _draw_drop_effect(",
		"static func _draw_explosion_effect(",
	]:
		_expect(renderer_source.find(owner_marker) >= 0, "presentation renderer should implement %s" % owner_marker)


func _verify_draw_plan_normalization() -> void:
	var plan: Dictionary = CommandoSupplyDropPresentationRenderer.build_draw_plan({
		"shake_offset": Vector2(3.0, 4.0),
		"hold_gauge_status": {"visible": true, "progress": 0.5, "rect": Rect2(1.0, 2.0, 60.0, 10.0)},
		"explosion_effects": [{"kind": "spark"}],
		"aircraft": {"visible": true, "crashing": false, "direction": "left_to_right"},
		"drop_effects": [{"life": 0.5}],
		"collectible_drops": [{"type": "field_item"}],
		"crash_blast_zone": {"active": true},
	})
	_expect(plan.get("shake_offset", Vector2.ZERO) == Vector2(3.0, 4.0), "draw plan should preserve shake offset")
	_expect(bool((plan.get("hold_gauge_status", {}) as Dictionary).get("visible", false)), "draw plan should preserve gauge visibility")
	_expect((plan.get("explosion_effects", []) as Array).size() == 1, "draw plan should preserve explosion effects")
	_expect(bool((plan.get("aircraft", {}) as Dictionary).get("visible", false)), "draw plan should preserve aircraft visibility")
	_expect((plan.get("drop_effects", []) as Array).size() == 1, "draw plan should preserve drop effects")
	_expect((plan.get("collectible_drops", []) as Array).size() == 1, "draw plan should preserve collectible drops")
	_expect(not (plan.get("crash_blast_zone", {}) as Dictionary).is_empty(), "draw plan should preserve the crash blast zone")
	var defaults: Dictionary = CommandoSupplyDropPresentationRenderer.build_draw_plan({
		"shake_offset": "invalid",
		"explosion_effects": 3,
		"aircraft": [],
	})
	_expect(defaults.get("shake_offset", Vector2.ONE) == Vector2.ZERO, "draw plan should normalize invalid shake offset")
	_expect((defaults.get("explosion_effects", [1]) as Array).is_empty(), "draw plan should normalize invalid effect arrays")
	_expect((defaults.get("aircraft", {"visible": true}) as Dictionary).is_empty(), "draw plan should normalize invalid aircraft data")


func _verify_payload_sprite_status() -> void:
	CommandoSupplyDropPresentationRenderer.prewarm_assets()
	var status: Dictionary = CommandoSupplyDropPresentationRenderer.build_payload_sprite_status()
	_expect(bool(status.get("sprite_pipeline", false)), "presentation renderer should expose the payload sprite pipeline")
	_expect(bool(status.get("active_loaded", false)), "presentation renderer should load the payload sprite")
	_expect(str(status.get("path", "")).ends_with("commando_supply_parachute_crate_imagegen_v1.png"), "presentation renderer should own the payload sprite path")
	_expect(status.get("draw_size", Vector2.ZERO) == Vector2(84.0, 84.0), "presentation renderer should preserve payload draw size")
	_expect(status.get("draw_offset", Vector2.ZERO) == Vector2(0.0, -14.0), "presentation renderer should preserve payload draw offset")


func _verify_production_context_facade() -> void:
	var state: Object = CommandoSupplyDropState.new()
	var deps := {
		"commando_weapon_controller": CommandoWeaponController.new(),
		"commando_supply_drop_direction": "left_to_right",
		"commando_supply_drop_payload_count": 1,
		"commando_supply_drop_forced_payloads": [{"type": "field_item", "item_id": "gauge_charge"}],
		"commando_supply_drop_aircraft_arrival_delay": 0.0,
		"commando_supply_drop_payload_delays": [1.15],
	}
	var activation: Dictionary = state.update_input(
		{"down_pressed": true, "action_pressed": true},
		1.0,
		500.0,
		CommandoSkillConfig.new(),
		CommandoSkillState.new(),
		deps
	)
	_expect(bool(activation.get("activated", false)), "production host should activate for presentation context verification")
	var context: Dictionary = state._build_presentation_context(Vector2(7.0, -3.0))
	var plan: Dictionary = CommandoSupplyDropPresentationRenderer.build_draw_plan(context)
	_expect(plan.get("shake_offset", Vector2.ZERO) == Vector2(7.0, -3.0), "production context should preserve draw shake")
	var aircraft: Dictionary = plan.get("aircraft", {}) if plan.get("aircraft", {}) is Dictionary else {}
	_expect(bool(aircraft.get("visible", false)), "production context should expose the active aircraft")
	_expect(not bool(aircraft.get("crashing", true)), "production context should expose normal flight before shoot-down")
	_expect(str(aircraft.get("direction", "")) == "left_to_right", "production context should preserve aircraft direction")
	var hit: bool = state.shoot_down_aircraft(deps, "presentation_smoke")
	_expect(hit, "production aircraft should enter crash state for presentation verification")
	plan = CommandoSupplyDropPresentationRenderer.build_draw_plan(state._build_presentation_context(Vector2.ZERO))
	aircraft = plan.get("aircraft", {}) if plan.get("aircraft", {}) is Dictionary else {}
	_expect(bool(aircraft.get("visible", false)) and bool(aircraft.get("crashing", false)), "production context should expose the crashing aircraft")
	_expect((plan.get("explosion_effects", []) as Array).size() == 19, "production context should expose the delegated hit recipe")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
