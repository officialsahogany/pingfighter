extends SceneTree

# expect-zero-object-leaks — run_smoke_tests.ps1이 종료 시 ObjectDB 누수
# 경고를 이 스모크에 한해 실패로 승격한다(라이브 셸/컨트롤러 회수 봉인).

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


class SingleFrameOwner:
	extends Node2D

	var current_stage := 7


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

	# 코덱스 P2 봉인: 완료 프레임에 로딩 화면이 1프레임 재출현하지 않으려면
	# '같은 process_idle 1회' 안에서 완료 update → 랜딩 시작으로 이어져야
	# 한다(다음 프레임 랜딩만 보장하는 16프레임 대기 봉인으론 구식 return이
	# 통과). 완료 직전 상태의 프레젠테이션으로 1회 호출을 직접 검증.
	var single_registry := RegistryProbe.new()
	var single_flow := BattleSceneFlowController.new()
	single_flow.set("_battle_initialized", true)
	var single_presentation := PresentationProbe.new()
	single_presentation.active = true
	single_presentation.update_calls = 1
	var single_audio := AudioProbe.new()
	var single_owner := SingleFrameOwner.new()
	root.add_child(single_owner)
	single_registry.instances = {
		"stage7_akamu_prebattle_presentation": single_presentation,
		"game_audio": single_audio,
	}
	var single_getter := Callable(single_registry, "get_instance")
	var single_callbacks := {
		"is_battle_initialized": Callable(single_flow, "is_battle_initialized"),
		"is_stage_landing_intro_started": Callable(single_flow, "is_stage_landing_intro_started"),
		"begin_stage_landing_intro": Callable(single_flow, "begin_stage_landing_intro").bind(
			single_owner, single_registry, single_getter, single_getter
		),
	}
	var single_result := bool(BattleSceneIntroFrameController.new().process_idle(
		0.016, single_owner, single_registry, single_getter, single_callbacks
	))
	_expect(single_presentation.update_calls == 2 and single_presentation.completed, "single-call leg precondition: this process_idle should complete the video")
	_expect(
		single_flow.is_stage_landing_intro_started(),
		"video completion must fall through to landing within the SAME process_idle call (no one-frame loading flash)"
	)
	_expect(single_audio.played_stages == [7], "same-call fall-through should also start stage 7 BGM once")
	_expect(
		not single_result,
		"the completing call should hand the frame to the battle scene (returning intro ownership would draw the loading screen once more)"
	)
	single_owner.queue_free()
	await process_frame

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
