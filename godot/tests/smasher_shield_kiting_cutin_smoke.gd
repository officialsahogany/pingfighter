extends SceneTree

const SmasherShieldKitingState := preload("res://scripts/characters/smasher_shield_kiting_state.gd")
const SkillCutinOverlayHost := preload("res://scripts/hud/skill_cutin_overlay_host.gd")
const SkillCutinDriveRenderer := preload("res://scripts/hud/skill_cutin_drive_renderer.gd")

var _failures: Array[String] = []
var _draw_ran := false


class FakeSkillConfig:
	func is_skill_equipped(skill_name: String) -> bool:
		return skill_name == "shield_kiting"

	func get_skill_cost(_skill_name: String) -> float:
		return 130.0

	func get_cooldown_seconds(_skill_name: String) -> float:
		return 12.0


class FakeSkillState:
	var triggered_skill := ""

	func trigger_configured_cooldown(skill_name: String, _time_now: int, _skill_config: Object) -> void:
		triggered_skill = skill_name

	func get_configured_cooldown_remaining(_skill_name: String, _time_now: int, _skill_config: Object) -> float:
		return 0.0


class FakePartialCutinState:
	extends RefCounted

	var progress := 0.0
	var active := true

	func is_active() -> bool:
		return active

	func get_progress() -> float:
		return progress


class ShieldCutinDrawProbe:
	extends Node2D

	var host: Object = null
	var shield_state: Object = null
	var smoke: Object = null

	func _draw() -> void:
		if host == null or shield_state == null:
			return
		var state := FakePartialCutinState.new()
		for p in [0.0, 0.12, 0.3, 0.5, 0.7, 0.9, 1.0]:
			state.progress = float(p)
			state.active = true
			host.draw_shield_kiting_cutin(self, state, shield_state, Vector2(760, 750))
		host.draw_shield_kiting_cutin(null, state, shield_state, Vector2(760, 750))
		state.active = false
		host.draw_shield_kiting_cutin(self, state, shield_state, Vector2(760, 750))
		if smoke != null:
			smoke._draw_ran = true


func _init() -> void:
	_test_activation_starts_partial_cutin()
	_test_renderer_contract()
	_test_frame_controller_fanout()
	_start_draw_probe()


func _test_activation_starts_partial_cutin() -> void:
	var shield_state := SmasherShieldKitingState.new()
	var skill_state := FakeSkillState.new()
	var context: Dictionary = _base_context()
	var now_msec := Time.get_ticks_msec()
	shield_state.last_action_edge_msec = now_msec - 120
	var activation: Dictionary = shield_state.update_input(
		{"action_pressed": true},
		now_msec,
		500.0,
		Vector2(302.5, 690.0),
		context,
		{
			"skill_config": FakeSkillConfig.new(),
			"skill_state": skill_state,
		}
	)
	_expect(bool(activation.get("activated", false)), "Shield Kiting activation should succeed from the double-tap edge")
	_expect(skill_state.triggered_skill == "shield_kiting", "Shield Kiting activation should still trigger cooldown")
	_expect(shield_state.is_partial_cutin_active(), "Shield Kiting activation should start the partial cut-in")
	_expect(str(shield_state.cutin_state.get_skill_name()) == "shield_kiting", "partial cut-in state should publish shield_kiting")
	_expect(absf(shield_state.cutin_state.get_duration() - 2.70) < 0.01, "Shield Kiting partial cut-in should use the extended 2.7s timing")
	for _i in 120:
		shield_state.update_effects(1.0)
	_expect(shield_state.is_partial_cutin_active(), "Shield Kiting partial cut-in should still be visible after roughly 2 seconds")
	for _i in 50:
		shield_state.update_effects(1.0)
	_expect(not shield_state.is_partial_cutin_active(), "Shield Kiting partial cut-in should expire through effect updates")
	shield_state.cutin_state.begin("shield_kiting", 1.0)
	shield_state.reset_round()
	_expect(not shield_state.is_partial_cutin_active(), "round reset should clear Shield Kiting partial cut-in")


func _test_renderer_contract() -> void:
	_expect(SkillCutinDriveRenderer.SKILL_SHIELD_KITING == "shield_kiting", "drive-style renderer should expose shield_kiting skill id")
	_expect(SkillCutinDriveRenderer.SHIELD_KITING_CHARACTER_PATH.ends_with(".png"), "Shield Kiting cut-in should expose a PNG character asset path")
	var host := SkillCutinOverlayHost.new()
	host.prewarm_assets()
	var shield_state := SmasherShieldKitingState.new()
	var texture: Texture2D = host._get_drive_texture(SkillCutinDriveRenderer.SHIELD_KITING_CHARACTER_PATH)
	_expect(host.has_method("draw_shield_kiting_cutin"), "overlay host should expose Shield Kiting partial cut-in draw")
	_expect(texture != null and texture.get_size().x > 1.0 and texture.get_size().y > 1.0, "Shield Kiting cut-in character art should load")
	_expect(SkillCutinDriveRenderer.shield_kiting_slide_ratio(0.50) == 0.0, "Shield Kiting cut-in should stay seated during the 2s hold")
	_expect(SkillCutinDriveRenderer.shield_kiting_alpha(0.50) == 1.0, "Shield Kiting cut-in should stay fully opaque during the 2s hold")
	_expect(SkillCutinDriveRenderer.shield_kiting_slide_ratio(0.90) > 0.0, "Shield Kiting cut-in should only exit after its long hold")
	_expect(shield_state.has_method("draw_cutin_symbol"), "Shield Kiting state should expose a cut-in symbol drawer")


func _test_frame_controller_fanout() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/core/battle_scene_frame_controller.gd")
	_expect(source.find("smasher_shield_kiting_state") >= 0, "frame controller should inspect Shield Kiting state for partial cut-in")
	_expect(source.find("draw_shield_kiting_cutin") >= 0, "frame controller should draw the Shield Kiting partial cut-in")
	_expect(source.find("draw_shield_now") >= 0, "frame controller should gate Shield Kiting partial cut-in separately from Drive")


func _start_draw_probe() -> void:
	var host := SkillCutinOverlayHost.new()
	host.prewarm_assets()
	var probe := ShieldCutinDrawProbe.new()
	probe.host = host
	probe.shield_state = SmasherShieldKitingState.new()
	probe.smoke = self
	get_root().add_child(probe)
	probe.queue_redraw()
	call_deferred("_finish_draw_probe")


func _finish_draw_probe() -> void:
	await process_frame
	await process_frame
	_expect(_draw_ran, "Shield Kiting cut-in draw probe should run")
	if _failures.is_empty():
		print("smasher_shield_kiting_cutin_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _base_context() -> Dictionary:
	return {
		"selected_character_type": "smasher",
		"ball_active": true,
		"waiting_for_serve": false,
		"ball_pos": Vector2(120.0, 220.0),
		"ball_vel": Vector2(0.0, 8.0),
		"ball_size": 28.6,
		"player_paddle_size": Vector2(155.0, 50.0),
		"paddle_width": 155.0,
		"paddle_height": 50.0,
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
