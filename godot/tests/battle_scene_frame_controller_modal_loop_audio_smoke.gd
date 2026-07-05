extends SceneTree

# Seal: a physics-blocking modal (character info via TAB, pause menu, debug
# pickers) returns from BattleSceneFrameController.process_physics BEFORE the
# update driver -- so update_effects, the only place that stops gameplay loop
# audio, never runs while the modal is open. The dash-delay 후딜 sound is a
# force-looped player, so dashing then opening the character-info panel (TAB)
# left it looping forever until the panel closed. process_physics must stop the
# gameplay loop audio at the modal-block gate. The negative case guards against
# over-stopping loops during normal (non-blocking) play.

const BattleSceneFrameController := preload("res://scripts/core/battle_scene_frame_controller.gd")

var _failures: Array[String] = []


class FakeGameAudio:
	extends RefCounted

	var stop_dash_delay_calls := 0
	var stop_warp_gate_calls := 0

	func stop_dash_delay() -> void:
		stop_dash_delay_calls += 1

	func stop_warp_gate_loop() -> void:
		stop_warp_gate_calls += 1


class FakeModalGate:
	extends RefCounted

	var block := true

	func should_block_battle_physics_with_perf(_module_getter: Callable, _perf_logger: Object = null) -> bool:
		return block

	func should_block_battle_physics(_module_getter: Callable) -> bool:
		return block


class FakeModuleHost:
	extends RefCounted

	var modal_gate := FakeModalGate.new()
	var game_audio := FakeGameAudio.new()

	func get_module(key: String) -> Object:
		match key:
			"battle_scene_modal_gate_controller":
				return modal_gate
			"game_audio":
				return game_audio
		# Every other lookup (readiness controller, match-event driver, result /
		# defeat screens, grip overlay, active_item_runtime, update driver, perf
		# logger) resolves to null so the earlier gates fall through to defaults
		# and the frame reaches the modal-block gate.
		return null


func _init() -> void:
	_verify_modal_block_stops_loop_audio()
	_verify_non_blocking_leaves_loop_audio_untouched()

	if _failures.is_empty():
		print("battle_scene_frame_controller_modal_loop_audio_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _make_callbacks() -> Dictionary:
	return {
		"is_battle_initialized": Callable(self, "_true"),
		"is_stage_landing_intro_started": Callable(self, "_true"),
	}


func _true() -> bool:
	return true


func _verify_modal_block_stops_loop_audio() -> void:
	var controller := BattleSceneFrameController.new()
	var host := FakeModuleHost.new()
	host.modal_gate.block = true

	controller.process_physics(
		1.0 / 60.0,
		null,
		null,
		Callable(host, "get_module"),
		_make_callbacks()
	)

	_expect(
		host.game_audio.stop_dash_delay_calls >= 1,
		"physics-blocking modal must stop the dash-delay loop (the TAB-after-dash 후딜 repeat bug)"
	)
	_expect(
		host.game_audio.stop_warp_gate_calls >= 1,
		"physics-blocking modal must stop every gameplay loop, not only dash-delay"
	)


func _verify_non_blocking_leaves_loop_audio_untouched() -> void:
	var controller := BattleSceneFrameController.new()
	var host := FakeModuleHost.new()
	host.modal_gate.block = false

	controller.process_physics(
		1.0 / 60.0,
		null,
		null,
		Callable(host, "get_module"),
		_make_callbacks()
	)

	_expect(
		host.game_audio.stop_dash_delay_calls == 0,
		"normal (non-blocking) play must NOT stop gameplay loop audio from the modal gate"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
