extends SceneTree

const BattleSceneFrameController := preload("res://scripts/core/battle_scene_frame_controller.gd")
const BattleSceneIntroFrameController := preload("res://scripts/core/battle_scene_intro_frame_controller.gd")
const BattleLoadingScreenRenderer := preload("res://scripts/core/battle_loading_screen_renderer.gd")
const BattleSceneFlowController := preload("res://scripts/core/battle_scene_flow_controller.gd")

var _failures: Array[String] = []


class RegistryProbe:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		return value as Object if value is Object else null

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)

	func clear_all() -> void:
		instances.clear()


class ReadinessProbe:
	extends RefCounted

	func is_boot_warmup_finished(_module_getter: Callable) -> bool:
		return true

	func is_intro_or_warmup_blocking(
		_module_getter: Callable,
		_battle_initialized: bool,
		_stage_landing_intro_started: bool
	) -> bool:
		return false

	func is_mobile_touch_scene_ready(
		_module_getter: Callable,
		_battle_initialized: bool,
		_stage_landing_intro_started: bool
	) -> bool:
		return false


class PresentationProbe:
	extends RefCounted

	var active := false
	var completed := false
	var begin_calls := 0
	var update_calls := 0

	func begin_video(_owner: Object, _registry: Object) -> bool:
		begin_calls += 1
		if completed:
			return false
		active = true
		return true

	func update(_delta: float, _owner: Object, _registry: Object) -> void:
		update_calls += 1
		if update_calls >= 2:
			active = false
			completed = true

	func is_active() -> bool:
		return active

	func is_video_active() -> bool:
		return active

	func tear_down() -> void:
		active = false


class AudioProbe:
	extends RefCounted

	var played_stages: Array[int] = []

	func play_stage_bgm(stage_id: int) -> bool:
		played_stages.append(stage_id)
		return true

	func stop_bgm() -> void:
		pass


class LiveBattleShellProbe:
	extends "res://scripts/core/battle_scene_shell.gd"

	var observed_process_calls := 0
	var observed_draw_calls := 0

	func _process(delta: float) -> void:
		observed_process_calls += 1
		super._process(delta)

	func _draw() -> void:
		observed_draw_calls += 1
		super._draw()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var shell := LiveBattleShellProbe.new()
	shell.process_mode = Node.PROCESS_MODE_DISABLED
	shell.set_process(false)
	shell.set_physics_process(false)
	shell.set("current_stage", 7)

	var registry := RegistryProbe.new()
	var frame_controller := BattleSceneFrameController.new()
	var intro_controller := BattleSceneIntroFrameController.new()
	var loading_renderer := BattleLoadingScreenRenderer.new()
	var flow := BattleSceneFlowController.new()
	var readiness := ReadinessProbe.new()
	var presentation := PresentationProbe.new()
	var audio := AudioProbe.new()
	registry.instances = {
		"battle_scene_frame_controller": frame_controller,
		"battle_scene_intro_frame_controller": intro_controller,
		"battle_loading_screen_renderer": loading_renderer,
		"battle_scene_flow_controller": flow,
		"battle_scene_readiness_controller": readiness,
		"stage7_akamu_prebattle_presentation": presentation,
		"game_audio": audio,
	}
	shell.gameplay_modules = registry
	root.add_child(shell)

	# The normal boot has already shown the stained-glass loading reveal before
	# Stage 7 begins its video. Seed only that elapsed wall clock; from here the
	# SceneTree itself owns every shell process/draw and presentation update.
	while Time.get_ticks_msec() < 1800:
		await process_frame
	loading_renderer.set("_visible_started_msec", 1)
	loading_renderer.set("_completion_reveal_started_msec", 1)
	shell.process_mode = Node.PROCESS_MODE_INHERIT
	shell.set_process(true)

	for _frame in range(6):
		await process_frame
		if presentation.update_calls > 0:
			break
	_expect(presentation.update_calls == 1 and presentation.active, "live shell should reach an in-progress Stage 7 video frame")
	_expect(audio.played_stages.is_empty(), "live shell must not start Stage 7 BGM while the embedded video is active")
	_expect(not bool(flow.get("_battle_bgm_started")), "live shell should leave the post-video BGM latch unconsumed during playback")

	var frames_after_landing := 0
	for _frame in range(16):
		await process_frame
		if flow.is_stage_landing_intro_started():
			frames_after_landing += 1
			if frames_after_landing >= 3:
				break

	_expect(shell.observed_process_calls >= 2, "SceneTree should drive the live shell process path")
	_expect(shell.observed_draw_calls >= 1, "SceneTree should drive the live shell draw path")
	_expect(presentation.begin_calls == 2, "live shell should arm the video once, then re-enter landing after completion")
	_expect(presentation.update_calls >= 2, "live shell process_idle should advance Stage 7 video without direct test injection")
	_expect(presentation.completed, "live shell should let the Stage 7 presentation complete")
	_expect(flow.is_battle_initialized(), "live shell should initialize battle state before the Stage 7 video")
	_expect(flow.is_stage_landing_intro_started(), "live shell should leave the video and start landing without a loading-hold softlock")
	_expect(frames_after_landing >= 3, "live shell should keep pumping after the post-video landing handoff")
	_expect(audio.played_stages == [7], "live shell should start Stage 7 BGM exactly once after video completion")

	shell.process_mode = Node.PROCESS_MODE_DISABLED
	shell.set_process(false)
	shell.queue_free()
	await process_frame
	frame_controller = null
	intro_controller = null
	loading_renderer = null
	flow = null
	readiness = null
	presentation = null
	audio = null
	registry = null
	shell = null
	for _frame in range(4):
		await process_frame

	if _failures.is_empty():
		print("stage7_akamu_prebattle_live_frame_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
