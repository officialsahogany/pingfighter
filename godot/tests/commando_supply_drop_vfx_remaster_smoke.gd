extends SceneTree

const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const CommandoSkillState := preload("res://scripts/characters/commando_skill_state.gd")
const CommandoSupplyDropState := preload("res://scripts/characters/commando_supply_drop_state.gd")
const CommandoWeaponController := preload("res://scripts/characters/commando_weapon_controller.gd")

const VIEW_SIZE := Vector2i(760, 750)

var _failures: Array[String] = []
var _probe: SupplyDropVfxProbe = null
var _supply_state: Object = CommandoSupplyDropState.new()
var _skill_config: Object = CommandoSkillConfig.new()
var _weapon_controller: Object = CommandoWeaponController.new()
var _audio: Object = null
var _deps := {}


class FakeAudio:
	extends RefCounted

	var radio_calls := 0
	var aircraft_play_calls := 0
	var aircraft_stop_calls := 0
	var drop_calls := 0
	var explosion_calls := 0

	func play_commando_supply_radio() -> void:
		radio_calls += 1

	func play_commando_supply_aircraft_loop() -> void:
		aircraft_play_calls += 1

	func stop_commando_supply_aircraft_loop() -> void:
		aircraft_stop_calls += 1

	func play_commando_supply_drop() -> void:
		drop_calls += 1

	func play_grenade_explosion() -> void:
		explosion_calls += 1


class SupplyDropVfxProbe:
	extends Node2D

	var state: Object = null
	var draw_count := 0

	func _draw() -> void:
		draw_count += 1
		if state != null:
			state.draw(self, Vector2.ZERO)


func _init() -> void:
	get_root().size = VIEW_SIZE
	_audio = FakeAudio.new()
	_deps = {
		"audio": _audio,
		"commando_weapon_controller": _weapon_controller,
		"commando_supply_drop_direction": "left_to_right",
		"commando_supply_drop_payload_count": 1,
		"commando_supply_drop_forced_payloads": [
			{"type": "field_item", "item_id": "gauge_charge"},
		],
		"commando_supply_drop_aircraft_arrival_delay": 0.0,
		"commando_supply_drop_payload_delays": [1.15],
		"current_stage": 1,
	}
	_probe = SupplyDropVfxProbe.new()
	_probe.name = "SupplyDropVfxProbe"
	_probe.state = _supply_state
	get_root().add_child(_probe)
	_activate_supply_drop()
	_probe.queue_redraw()
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await process_frame
	_verify_aircraft_vfx_pipeline()
	_verify_aircraft_movement_speed_matches_python_reference()
	var early_result: Dictionary = _supply_state.update(1.2, _deps)
	_expect(not bool(early_result.get("drop_resolved", false)), "supply payload should not resolve while the aircraft is still outside the center background")
	var early_aircraft_x: float = _get_vector2(_supply_state.get_snapshot().get("aircraft_pos", Vector2.ZERO), Vector2.ZERO).x
	_expect(early_aircraft_x < 0.0, "test setup should still have the aircraft in the pillar/background margin before payload release")
	var resolve_result: Dictionary = _supply_state.update(2.8, _deps)
	_expect(bool(resolve_result.get("drop_resolved", false)), "supply drop should resolve before parachute VFX verification")
	_verify_payload_stays_inside_center_background(resolve_result)
	_probe.queue_redraw()
	await process_frame
	await process_frame
	_verify_parachute_vfx_pipeline()
	_supplement_crash_setup()
	_probe.queue_redraw()
	await process_frame
	await process_frame
	_verify_crash_vfx_pipeline()
	_supply_state.reset()
	_verify_fx_host_cleanup()
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("commando_supply_drop_vfx_remaster_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _activate_supply_drop() -> void:
	var activate_result: Dictionary = _supply_state.update_input(
		{"down_pressed": true, "action_pressed": true},
		1.0,
		500.0,
		_skill_config,
		CommandoSkillState.new(),
		_deps
	)
	_expect(bool(activate_result.get("activated", false)), "supply drop should activate for VFX setup")


func _supplement_crash_setup() -> void:
	_supply_state.reset()
	_activate_supply_drop()
	_supply_state.update(0.35, _deps)
	var aircraft_pos: Vector2 = _supply_state.get_snapshot().get("aircraft_pos", Vector2.ZERO)
	var scene := {
		"previous_ball_pos": aircraft_pos + Vector2(0.0, 22.0),
		"ball_pos": aircraft_pos,
		"ball_vel": Vector2(0.0, -12.0),
	}
	var hit: bool = bool(_supply_state.resolve_ball_collision(scene, {
		"ball_size": 28.6,
		"last_hit_by": "player",
	}, _deps))
	_expect(hit, "player-owned ball should enter the supply aircraft crash VFX setup")


func _verify_aircraft_vfx_pipeline() -> void:
	_expect(_probe != null and _probe.draw_count > 0, "supply drop VFX probe should receive a draw callback")
	var plan: Dictionary = _supply_state.build_vfx_remaster_plan()
	_expect(bool(plan.get("godot_native_vfx_remaster", false)), "supply drop should expose the Godot-native VFX remaster flag")
	_expect(bool(plan.get("texture_piece_pipeline", false)), "supply drop should use texture-piece VFX layers")
	_expect(bool(plan.get("shader_host_pipeline", false)), "supply drop should expose a shader host pipeline")
	_expect(bool(plan.get("gpu_particle_pipeline", false)), "supply drop should expose a GPUParticles2D pipeline")
	_expect(bool(plan.get("tween_pipeline", false)), "supply drop should expose the pulse Tween pipeline")
	_expect(bool(plan.get("aircraft_sprite_sheet_pipeline", false)), "active aircraft should use the AutoSprite sheet pipeline")
	_expect(bool(plan.get("aircraft_sprite_sheet_loaded", false)), "active aircraft AutoSprite sheet should load before drawing")
	_expect(int(plan.get("aircraft_sprite_frame_count", 0)) == 16, "active aircraft AutoSprite sheet should expose 16 frames")
	_expect(bool(plan.get("aircraft_crash_sprite_sheet_pipeline", false)), "shot-down aircraft should expose an AutoSprite crash sheet pipeline")
	_expect(bool(plan.get("aircraft_crash_sprite_sheet_loaded", false)), "shot-down aircraft AutoSprite crash sheet should load before drawing")
	_expect(int(plan.get("aircraft_crash_sprite_frame_count", 0)) == 16, "shot-down aircraft AutoSprite crash sheet should expose 16 frames")
	_expect(bool(plan.get("collectible_payload_sprite_pipeline", false)), "supply payload should expose the PNG sprite pipeline")
	var sprite_status: Dictionary = _supply_state.build_aircraft_sprite_status()
	_expect(bool(sprite_status.get("left_loaded", false)), "right-to-left supply aircraft sheet should load")
	_expect(bool(sprite_status.get("right_loaded", false)), "left-to-right mirrored supply aircraft sheet should load")
	_expect(str(sprite_status.get("active_path", "")).ends_with("_right.png"), "default left-to-right flight should use the right-facing mirrored sheet")
	_expect(bool(sprite_status.get("crash_left_loaded", false)), "right-to-left supply aircraft crash sheet should load")
	_expect(bool(sprite_status.get("crash_right_loaded", false)), "left-to-right mirrored supply aircraft crash sheet should load")
	_expect(str(sprite_status.get("crash_active_path", "")).ends_with("_crash_sheet_autosprite_v1_right.png"), "default left-to-right crash should use the right-facing mirrored crash sheet")
	var snapshot: Dictionary = _supply_state.get_snapshot()
	_expect(is_equal_approx(_get_vector2(snapshot.get("aircraft_pos", Vector2.ZERO), Vector2.ZERO).x, -360.0), "left-to-right supply aircraft should spawn from the same off-canvas edge lane as fire support")
	_expect(is_equal_approx(float(sprite_status.get("speed_pixels_per_second", 0.0)), 120.0), "active aircraft should expose Python 2px/frame movement speed")
	_expect(int(plan.get("aircraft_texture_layers", 0)) >= 3, "active aircraft should receive texture-piece VFX layers")
	_expect(int(plan.get("visible_effect_count", 0)) >= 1, "active supply drop should count visible remaster effects")
	_verify_host_status("aircraft")


func _verify_aircraft_movement_speed_matches_python_reference() -> void:
	var before: Dictionary = _supply_state.get_snapshot()
	var start_x: float = _get_vector2(before.get("aircraft_pos", Vector2.ZERO), Vector2.ZERO).x
	_supply_state.update(0.5, _deps)
	var after: Dictionary = _supply_state.get_snapshot()
	var end_x: float = _get_vector2(after.get("aircraft_pos", Vector2.ZERO), Vector2.ZERO).x
	_expect(is_equal_approx(end_x - start_x, 60.0), "supply aircraft should move at Python speed: 2px/frame, 120px/sec")
	_expect(float(after.get("flight_duration", 0.0)) >= 12.0, "supply aircraft should take about 12.3 seconds to cross the screen-edge lane")


func _verify_parachute_vfx_pipeline() -> void:
	var plan: Dictionary = _supply_state.build_vfx_remaster_plan()
	_expect(bool(plan.get("collectible_payload_sprite_loaded", false)), "supply payload parachute crate PNG should load before drawing")
	_expect(int(plan.get("drop_texture_layers", 0)) >= 3, "resolved supply drop should render fading parachute texture layers")
	_expect(int(plan.get("collectible_texture_layers", 0)) >= 3, "collectible supply box should render persistent texture layers")
	_expect(int(plan.get("parachute_texture_layers", 0)) >= 6, "drop and collectible parachutes should both be counted in the remaster plan")
	var payload_status: Dictionary = _supply_state.build_payload_sprite_status()
	_expect(bool(payload_status.get("active_loaded", false)), "supply payload parachute crate sprite should load")
	_expect(str(payload_status.get("path", "")).ends_with("commando_supply_parachute_crate_imagegen_v1.png"), "supply payload should use the generated parachute crate PNG")
	_verify_host_status("collectible")


func _verify_payload_stays_inside_center_background(resolve_result: Dictionary) -> void:
	var drop: Dictionary = resolve_result.get("drop", {}) if resolve_result.get("drop", {}) is Dictionary else {}
	var drop_position: Vector2 = _get_vector2(drop.get("drop_position", Vector2.ZERO), Vector2.ZERO)
	var aircraft_x: float = _get_vector2(_supply_state.get_snapshot().get("aircraft_pos", Vector2.ZERO), Vector2.ZERO).x
	_expect(aircraft_x >= 32.0 and aircraft_x <= 728.0, "first supply payload should resolve only after the aircraft enters the center background")
	_expect(drop_position.x >= 32.0 and drop_position.x <= 728.0, "supply payload should stay inside the center background while the aircraft starts from the screen edge")


func _verify_crash_vfx_pipeline() -> void:
	var plan: Dictionary = _supply_state.build_vfx_remaster_plan()
	_expect(bool(plan.get("aircraft_crash_sprite_sheet_pipeline", false)), "shot-down supply aircraft should keep the AutoSprite crash sheet pipeline active")
	_expect(bool(plan.get("aircraft_crash_sprite_sheet_loaded", false)), "shot-down supply aircraft crash sheet should be loaded")
	_expect(int(plan.get("aircraft_crash_sprite_frame_count", 0)) == 16, "shot-down supply aircraft crash sheet should expose 16 frames")
	_expect(int(plan.get("crash_texture_layers", 0)) > 0, "shot-down supply aircraft should expose crash texture layers")
	_expect(int(plan.get("visible_effect_count", 0)) > 0, "shot-down supply aircraft should keep crash VFX visible")
	_verify_host_status("explosion")


func _verify_host_status(expected_anchor: String) -> void:
	var host: Object = _supply_state.get("fx_host")
	_expect(host != null and is_instance_valid(host), "supply drop should attach an FX host to the draw canvas")
	if host == null or not is_instance_valid(host) or not host.has_method("get_debug_status"):
		return
	var status: Dictionary = host.get_debug_status()
	_expect(bool(status.get("active", false)), "supply drop FX host should be active for %s VFX" % expected_anchor)
	if host is Node:
		_expect(not (host as Node).is_processing(), "supply drop FX host should stay draw-sync driven for %s VFX" % expected_anchor)
	_expect(int(status.get("shader_layers", 0)) == 1, "supply drop FX host should own one shader layer")
	_expect(int(status.get("gpu_particle_layers", 0)) == 2, "supply drop FX host should own drift and crash particle layers")
	_expect(bool(status.get("texture_pieces_ready", false)), "supply drop FX host should prewarm shared texture pieces")
	_expect(bool(status.get("loop_tween_active", false)), "supply drop FX host should keep its pulse Tween alive")
	_expect(str(status.get("anchor_source", "")) == expected_anchor, "supply drop FX host should anchor to %s VFX" % expected_anchor)


func _verify_fx_host_cleanup() -> void:
	var host: Object = _supply_state.get("fx_host")
	_expect(host != null and is_instance_valid(host), "supply drop cleanup should keep a reusable hidden FX host")
	if host == null or not is_instance_valid(host) or not host.has_method("get_debug_status"):
		return
	var status: Dictionary = host.get_debug_status()
	_expect(not bool(status.get("active", true)), "supply drop reset should hide the FX host")


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
