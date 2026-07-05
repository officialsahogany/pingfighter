extends SceneTree

const BattleEffectsUpdateController := preload("res://scripts/effects/battle_effects_update_controller.gd")
const Stage2BossSkillState := preload("res://scripts/stages/stage2/stage2_boss_skill_state.gd")
const Stage3BossSkillState := preload("res://scripts/stages/stage3/stage3_boss_skill_state.gd")
const Stage4ActorRenderer := preload("res://scripts/stages/stage4/stage4_actor_renderer.gd")
const Stage4MapState := preload("res://scripts/stages/stage4/stage4_map_state.gd")
const Stage4PonkSkillState := preload("res://scripts/stages/stage4/stage4_ponk_skill_state.gd")
const StatusEffectOverlayRenderer := preload("res://scripts/status/status_effect_overlay_renderer.gd")

var _failures: Array[String] = []


class FakeActiveItemRuntime:
	extends RefCounted

	var paused := true

	func get_boss_ai_context() -> Dictionary:
		return {
			"active_item_tear_gas_cooldown_pause_active": paused,
			"active_item_boss_skill_cooldown_paused": paused,
		}


class FakeStage2Background:
	extends RefCounted

	var quake_casts := 0
	var water_phase := "idle"

	func is_quake_active() -> bool:
		return false

	func is_boss_rage_active() -> bool:
		return false

	func get_water_cannon_phase() -> String:
		return water_phase

	func get_rock_count() -> int:
		return 0

	func activate_quake(
		_duration_sec: float,
		_rock_count: int,
		_enraged: bool,
		_launch_guard: bool,
		_deps: Dictionary
	) -> bool:
		quake_casts += 1
		return true


class FakeCanvas:
	extends Node2D


class FakeDrawModule:
	extends RefCounted

	var draw_calls := 0

	func draw(_canvas: CanvasItem, _context: Dictionary, _shake_offset: Vector2, _perf_logger: Object = null) -> void:
		draw_calls += 1


class FakeStatusOverlay:
	extends RefCounted

	var full_overlay_calls := 0
	var pause_marker_calls := 0
	var last_context: Dictionary = {}
	var last_options: Dictionary = {}

	func draw_boss_status_overlays(
		_canvas: CanvasItem,
		context: Dictionary,
		_boss_pos: Vector2,
		_boss_paddle_size: Vector2,
		_boss_hitbox_height: float,
		_shake_offset: Vector2,
		options: Dictionary = {}
	) -> void:
		full_overlay_calls += 1
		last_context = context.duplicate(true)
		last_options = options.duplicate(true)

	func draw_boss_cooldown_pause_marker(
		_canvas: CanvasItem,
		_context: Dictionary,
		_boss_pos: Vector2,
		_boss_paddle_size: Vector2,
		_boss_hitbox_height: float,
		_shake_offset: Vector2,
		_options: Dictionary = {}
	) -> void:
		pause_marker_calls += 1


func _init() -> void:
	_verify_stage2_effect_update_uses_tear_gas_pause()
	_verify_stage3_effect_update_uses_tear_gas_pause()
	_verify_stage4_effect_update_uses_tear_gas_pause()
	_verify_pause_marker_draw_context_aliases()
	_verify_stage4_actor_renderer_draws_full_status_overlay()

	if _failures.is_empty():
		print("active_item_boss_skill_cooldown_pause_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_stage2_effect_update_uses_tear_gas_pause() -> void:
	var controller: Object = BattleEffectsUpdateController.new()
	var stage2_state: Object = Stage2BossSkillState.new()
	var stage2_background := FakeStage2Background.new()
	var active_item_runtime := FakeActiveItemRuntime.new()
	stage2_state.set("quake_cooldown", 20.0)
	stage2_state.set("water_cannon_delay", 18.0)
	stage2_state.set("speed_defense_since_activation", 7.0)

	controller.update(5.0, _base_context(2), {
		"active_item_runtime": active_item_runtime,
		"stage2_boss_skill_state": stage2_state,
		"stage_background": stage2_background,
	})

	_expect(is_equal_approx(stage2_state.get_quake_cooldown(), 20.0), "Stage 2 quake cooldown should stop while tear gas pause is active")
	_expect(is_equal_approx(stage2_state.get_water_cannon_delay(), 18.0), "Stage 2 water cannon cooldown should stop while tear gas pause is active")
	_expect(
		is_equal_approx(float(stage2_state.get("speed_defense_since_activation")), 7.0),
		"Stage 2 speed defense cooldown should stop while tear gas pause is active"
	)
	_expect(stage2_background.quake_casts == 0, "Stage 2 should not cast a paused ready skill")
	_expect(str(stage2_state.get_status()) == "paused", "Stage 2 should expose a paused boss-skill status")

	active_item_runtime.paused = false
	controller.update(1.0, _base_context(2), {
		"active_item_runtime": active_item_runtime,
		"stage2_boss_skill_state": stage2_state,
		"stage_background": stage2_background,
	})
	_expect(is_equal_approx(stage2_state.get_quake_cooldown(), 19.0), "Stage 2 quake cooldown should resume after tear gas pause clears")
	_expect(is_equal_approx(stage2_state.get_water_cannon_delay(), 17.0), "Stage 2 water cannon cooldown should resume after tear gas pause clears")
	_expect(
		is_equal_approx(float(stage2_state.get("speed_defense_since_activation")), 8.0),
		"Stage 2 speed defense cooldown should resume after tear gas pause clears"
	)


func _verify_stage3_effect_update_uses_tear_gas_pause() -> void:
	var controller: Object = BattleEffectsUpdateController.new()
	var stage3_state: Object = Stage3BossSkillState.new()
	var active_item_runtime := FakeActiveItemRuntime.new()
	stage3_state.set("psycho_cooldown", 12.0)
	stage3_state.set("tears_cooldown", 9.0)
	stage3_state.set("curse_cooldown", 11.0)

	controller.update(5.0, _base_context(3), {
		"active_item_runtime": active_item_runtime,
		"stage3_boss_skill_state": stage3_state,
	})

	var snapshot: Dictionary = stage3_state.get_snapshot()
	_expect(is_equal_approx(float(snapshot.get("psycho_cooldown", 0.0)), 12.0), "Stage 3 psycho ball cooldown should stop while tear gas pause is active")
	_expect(is_equal_approx(float(snapshot.get("tears_cooldown", 0.0)), 9.0), "Stage 3 tear shower cooldown should stop while tear gas pause is active")
	_expect(is_equal_approx(float(snapshot.get("curse_cooldown", 0.0)), 11.0), "Stage 3 curse chest cooldown should stop while tear gas pause is active")
	_expect(str(snapshot.get("status", "")) == "paused", "Stage 3 should expose a paused boss-skill status")

	active_item_runtime.paused = false
	controller.update(1.0 / 60.0, _base_context(3), {
		"active_item_runtime": active_item_runtime,
		"stage3_boss_skill_state": stage3_state,
	})
	snapshot = stage3_state.get_snapshot()
	_expect(float(snapshot.get("psycho_cooldown", 0.0)) < 12.0, "Stage 3 psycho ball cooldown should resume after tear gas pause clears")
	_expect(float(snapshot.get("tears_cooldown", 0.0)) < 9.0, "Stage 3 tear shower cooldown should resume after tear gas pause clears")
	_expect(float(snapshot.get("curse_cooldown", 0.0)) < 11.0, "Stage 3 curse chest cooldown should resume after tear gas pause clears")


func _verify_stage4_effect_update_uses_tear_gas_pause() -> void:
	var controller: Object = BattleEffectsUpdateController.new()
	var map_state: Object = Stage4MapState.new()
	var ponk_state: Object = Stage4PonkSkillState.new()
	var active_item_runtime := FakeActiveItemRuntime.new()
	ponk_state.set("magnetic_cooldown_seconds", 14.0)
	ponk_state.set("meditation_cooldown_seconds", 8.0)
	ponk_state.set("illusion_unlocked", true)
	ponk_state.set("illusion_cooldown_seconds", 6.0)

	controller.update(5.0, _base_context(4), {
		"active_item_runtime": active_item_runtime,
		"stage_background": map_state,
		"stage4_map_state": map_state,
		"stage4_ponk_skill_state": ponk_state,
	})

	var snapshot: Dictionary = ponk_state.get_debug_snapshot()
	_expect(is_equal_approx(float(snapshot.get("magnetic_cooldown_seconds", 0.0)), 14.0), "Stage 4 magnetic cooldown should stop while tear gas pause is active")
	_expect(is_equal_approx(float(snapshot.get("meditation_cooldown_seconds", 0.0)), 8.0), "Stage 4 meditation cooldown should stop while tear gas pause is active")
	_expect(is_equal_approx(float(snapshot.get("illusion_cooldown_seconds", 0.0)), 6.0), "Stage 4 illusion cooldown should stop while tear gas pause is active")

	active_item_runtime.paused = false
	controller.update(1.0 / 60.0, _base_context(4), {
		"active_item_runtime": active_item_runtime,
		"stage_background": map_state,
		"stage4_map_state": map_state,
		"stage4_ponk_skill_state": ponk_state,
	})
	snapshot = ponk_state.get_debug_snapshot()
	_expect(float(snapshot.get("magnetic_cooldown_seconds", 0.0)) < 14.0, "Stage 4 magnetic cooldown should resume after tear gas pause clears")
	_expect(float(snapshot.get("meditation_cooldown_seconds", 0.0)) < 8.0, "Stage 4 meditation cooldown should resume after tear gas pause clears")
	_expect(float(snapshot.get("illusion_cooldown_seconds", 0.0)) < 6.0, "Stage 4 illusion cooldown should resume after tear gas pause clears")


func _verify_pause_marker_draw_context_aliases() -> void:
	var overlay: Object = StatusEffectOverlayRenderer.new()
	_expect(
		bool(overlay._is_boss_cooldown_pause_marker_active({"active_item_boss_tear_gas_pause_active": true})),
		"boss pause marker should keep the legacy tear-gas actor key"
	)
	_expect(
		bool(overlay._is_boss_cooldown_pause_marker_active({"active_item_boss_skill_cooldown_paused": true})),
		"boss pause marker should accept the boss skill cooldown pause key"
	)
	_expect(
		bool(overlay._is_boss_cooldown_pause_marker_active({"active_item_tear_gas_cooldown_pause_active": true})),
		"boss pause marker should accept the tear-gas cooldown pause key"
	)
	_expect(
		not bool(overlay._is_boss_cooldown_pause_marker_active({})),
		"boss pause marker should stay hidden without a pause flag"
	)
	var stage4_renderer_source := FileAccess.get_file_as_string("res://scripts/stages/stage4/stage4_actor_renderer.gd")
	_expect(
		stage4_renderer_source.find("draw_boss_status_overlays") >= 0,
		"Stage 4 actor renderer should draw the shared boss status overlay stack after boss skill FX"
	)


func _verify_stage4_actor_renderer_draws_full_status_overlay() -> void:
	var renderer: Object = Stage4ActorRenderer.new()
	renderer.playfield_renderer = FakeDrawModule.new()
	renderer.player_renderer = FakeDrawModule.new()
	renderer.boss_renderer = FakeDrawModule.new()
	renderer.bird_event_renderer = FakeDrawModule.new()
	renderer.monk_event_renderer = FakeDrawModule.new()
	renderer.ponk_skill_renderer = FakeDrawModule.new()
	renderer.commando_firearm_renderer = FakeDrawModule.new()
	var overlay := FakeStatusOverlay.new()
	renderer.status_overlay_renderer = overlay

	var context := _base_context(4)
	context["active_item_boss_stun_active"] = true
	context["active_item_boss_stun_frame"] = 2
	context["active_item_boss_skill_cooldown_paused"] = true
	var canvas := FakeCanvas.new()
	renderer.draw(canvas, context)
	canvas.free()

	_expect(overlay.full_overlay_calls == 1, "Stage 4 actor renderer should call the full shared boss status overlay stack")
	_expect(overlay.pause_marker_calls == 0, "Stage 4 actor renderer should not bypass stun stars with the marker-only path")
	_expect(bool(overlay.last_context.get("active_item_boss_stun_active", false)), "Stage 4 status overlay should receive boss stun context for star animation")
	_expect(is_equal_approx(float(overlay.last_options.get("cooldown_pause_center_y_offset", 0.0)), -30.0), "Stage 4 should preserve the existing pause-marker vertical offset")


func _base_context(stage_id: int) -> Dictionary:
	return {
		"current_stage": stage_id,
		"ball_active": true,
		"waiting_for_serve": false,
		"selected_character_type": "smasher",
		"ai_mode": "champion",
		"player_score": 0,
		"boss_score": 0,
		"player_pos": Vector2(300.0, 680.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"ball_pos": Vector2(380.0, 360.0),
		"ball_vel": Vector2(0.0, -8.0),
		"dash_snapshot": {},
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
