extends SceneTree

const SourceContractFunctionBody := preload("res://tests/source_contract_function_body.gd")

const BattlePlayfieldEffectsDrawer := preload("res://scripts/core/battle_playfield_effects_drawer.gd")
const BattleViewLayout := preload("res://scripts/core/battle_view_layout.gd")
const SmasherPlasmaState := preload("res://scripts/characters/smasher_plasma_state.gd")
const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")
const SmasherSkillState := preload("res://scripts/characters/smasher_skill_state.gd")

const VIEW_SIZE := Vector2i(1180, 820)
const GAME_OFFSET := Vector2(190.0, 35.0)
const RENDER_SCALE := 1.18
const PLAYER_POS := Vector2(300.0, 700.0)
const SHAKE_OFFSET := Vector2(4.0, -3.0)
const HOST_NAME := "SmasherPlasmaFxHost"

var _failures: Array[String] = []
var _probe: PlasmaVisualProbe = null
var _drawer: Object = null
var _registry: FakeRegistry = null


class PlasmaVisualProbe:
	extends Node2D


class FakeFeedback:
	extends RefCounted

	var offset := Vector2.ZERO

	func _init(next_offset: Vector2 = Vector2.ZERO) -> void:
		offset = next_offset

	func get_shake_offset() -> Vector2:
		return offset


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		if value is Object:
			return value
		return null


func _init() -> void:
	get_root().size = VIEW_SIZE
	_verify_live_wiring_source()
	_drawer = BattlePlayfieldEffectsDrawer.new()
	_probe = PlasmaVisualProbe.new()
	_probe.name = "PlasmaVisualProbe"
	get_root().add_child(_probe)
	_registry = FakeRegistry.new()
	_registry.instances["battle_view_layout"] = BattleViewLayout.new()
	_registry.instances["battle_feedback_state"] = FakeFeedback.new(SHAKE_OFFSET)
	call_deferred("_run")


func _run() -> void:
	var charge_state: Object = _make_charging_state()
	_expect(charge_state.is_charging(), "charge fixture should be charging")
	_registry.instances["smasher_plasma_state"] = charge_state
	_drawer.draw_plasma_effects(_probe, _registry, Vector2.ZERO, _draw_context("smasher"))
	await process_frame
	await process_frame

	var host: Node = _probe.get_node_or_null(HOST_NAME)
	_expect(host != null, "plasma host should be attached to the playfield canvas")
	_expect(host != null and host.visible, "plasma host should be visible while charging")
	if host != null:
		var charge_fx: Dictionary = charge_state.get_plasma_fx_state(SHAKE_OFFSET)
		var expected_charge_pos: Vector2 = GAME_OFFSET + _as_vector2(charge_fx.get("pos", Vector2.ZERO), Vector2.ZERO) * RENDER_SCALE
		_expect_vector2_close(host.position, expected_charge_pos, "charge host should use screen-space playfield coordinates")
		_expect_vector2_close(host.scale, Vector2(RENDER_SCALE, RENDER_SCALE), "charge host should inherit render scale")
		var debug_status: Dictionary = host.get_debug_status() if host.has_method("get_debug_status") else {}
		_expect(bool(debug_status.get("active", false)), "charge host debug status should be active")
		_expect(bool(debug_status.get("enraged", false)), "max charge host should use enraged plasma presets")

	var wave_state: Object = _make_wave_state()
	_expect(wave_state.is_wave_active(), "wave fixture should be active")
	_registry.instances["smasher_plasma_state"] = wave_state
	_drawer.draw_plasma_effects(_probe, _registry, Vector2.ZERO, _draw_context("smasher"))
	await process_frame

	var wave_host: Node = _probe.get_node_or_null(HOST_NAME)
	_expect(wave_host == host, "wave sync should reuse the same plasma host")
	if wave_host != null:
		var wave_fx: Dictionary = wave_state.get_plasma_fx_state(SHAKE_OFFSET)
		var expected_wave_pos: Vector2 = GAME_OFFSET + _as_vector2(wave_fx.get("pos", Vector2.ZERO), Vector2.ZERO) * RENDER_SCALE
		_expect(wave_host.visible, "plasma host should stay visible while the projectile is active")
		_expect_vector2_close(wave_host.position, expected_wave_pos, "wave host should follow the projectile in screen space")

	_drawer.draw_plasma_effects(_probe, _registry, Vector2.ZERO, _draw_context("viper"))
	_expect(host != null and not host.visible, "plasma host should hide outside smasher context")

	_registry.instances.erase("smasher_plasma_state")
	_drawer.draw_plasma_effects(_probe, _registry, Vector2.ZERO, _draw_context("smasher"))
	_expect(host != null and not host.visible, "plasma host should stay hidden when the plasma state is absent")
	_finish()


func _draw_context(character_type: String) -> Dictionary:
	return {
		"selected_character_type": character_type,
		"game_offset": GAME_OFFSET,
		"render_scale": RENDER_SCALE,
		"shake_offset": Vector2.ZERO,
	}


func _verify_live_wiring_source() -> void:
	var drawer_src := FileAccess.get_file_as_string("res://scripts/core/battle_playfield_effects_drawer.gd")
	var draw_body := _function_body(drawer_src, "func draw_plasma_effects(")
	_expect(draw_body != "", "plasma draw body should be readable")
	_expect(draw_body.find("get_plasma_fx_state") >= 0, "plasma draw should request host-ready runtime state")
	_expect(draw_body.find("sync_state") >= 0, "plasma draw should sync the modular host")
	_expect(draw_body.find("draw_contact_overlay") >= 0, "plasma draw should keep the boss contact overlay path")
	_expect(draw_body.find("plasma_state.draw(") < 0, "plasma draw should retire the procedural charge/wave body")
	_expect(drawer_src.find("SmasherPlasmaFxHost") >= 0, "effects drawer should own the SmasherPlasmaFxHost preload")

	var state_src := FileAccess.get_file_as_string("res://scripts/characters/smasher_plasma_state.gd")
	_expect(state_src.find("func get_plasma_fx_state") >= 0, "plasma state should expose host-ready FX state")
	_expect(state_src.find("SmasherPlasmaFxHost.prewarm_assets()") >= 0, "plasma prewarm should include modular host assets")


func _function_body(source: String, signature: String) -> String:
	return SourceContractFunctionBody.extract(source, signature)

func _make_charging_state() -> Object:
	var state: Object = SmasherPlasmaState.new()
	var deps := _make_deps()
	var config := _make_config()
	var gauge := 500.0
	for i in range(182):
		var result: Dictionary = state.update_input({"up_pressed": true}, 1000 + i * 16, gauge, PLAYER_POS, config, deps)
		gauge = float(result.get("special_gauge", gauge))
	return state


func _make_wave_state() -> Object:
	var state: Object = SmasherPlasmaState.new()
	var deps := _make_deps()
	var config := _make_config()
	var gauge := 500.0
	for i in range(182):
		var result: Dictionary = state.update_input({"up_pressed": true}, 1000 + i * 16, gauge, PLAYER_POS, config, deps)
		gauge = float(result.get("special_gauge", gauge))
	state.update_input({"up_pressed": false}, 4000, gauge, PLAYER_POS, config, deps)
	return state


func _make_deps() -> Dictionary:
	var skill_config: Object = SmasherSkillConfig.new()
	_expect(skill_config.unlock_and_equip_skill("plasma"), "plasma should equip for the visual fixture")
	return {
		"skill_config": skill_config,
		"skill_state": SmasherSkillState.new(),
	}


func _make_config() -> Dictionary:
	return {
		"ball_active": true,
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"gauge_max": 500.0,
	}


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _expect_vector2_close(actual: Vector2, expected: Vector2, message: String) -> void:
	if actual.distance_to(expected) > 0.05:
		_failures.append("%s (actual=%s expected=%s)" % [message, actual, expected])


func _finish() -> void:
	if _failures.is_empty():
		print("smasher_plasma_visual_render_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
