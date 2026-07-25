extends SceneTree

const BattleBootWarmupController := preload("res://scripts/core/battle_boot_warmup_controller.gd")
const BattleLoadingTips := preload("res://scripts/core/battle_loading_tips.gd")
const LoadingCameoCatalog := preload("res://scripts/core/loading_cameo_catalog.gd")
const LoadingCameoHost := preload("res://scripts/core/loading_cameo_host.gd")
const BattleLoadingScreenRenderer := preload("res://scripts/core/battle_loading_screen_renderer.gd")
const BattleSceneIntroFrameController := preload("res://scripts/core/battle_scene_intro_frame_controller.gd")

var _failures: Array[String] = []
var _modules: Dictionary = {}


class FakeOwner:
	extends RefCounted

	var current_stage := 3
	var selected_character_name := "바이퍼"
	var selected_character_type := "viper"


class FakeStageNode:
	extends Node2D

	var current_stage := 1
	var selected_character_name := "바이퍼"
	var selected_character_type := "viper"


class FakeReadiness:
	extends RefCounted

	var warmup_finished := false

	func is_boot_warmup_finished(_module_getter: Callable) -> bool:
		return warmup_finished


class FakeAudio:
	extends RefCounted

	var setup_progress := 0.0

	func get_setup_progress() -> float:
		return setup_progress


class FakeLoadingRenderer:
	extends RefCounted

	var draw_calls := 0
	var hold_calls := 0
	var hold_completion := false
	var last_context: Dictionary = {}

	func draw(
		_canvas: CanvasItem,
		_owner: Object,
		_module_getter: Callable,
		_view_size: Vector2,
		context: Dictionary = {}
	) -> void:
		draw_calls += 1
		last_context = context.duplicate(true)

	func should_hold_completion(_owner: Object, _module_getter: Callable) -> bool:
		hold_calls += 1
		return hold_completion


class FakePerfLogger:
	extends RefCounted

	var labels: Array[String] = []
	var counters: Dictionary = {}

	func begin_sample() -> int:
		return Time.get_ticks_usec()

	func finish_sample(label: String, _start_usec: int) -> void:
		labels.append(label)

	func record_counter_sample(label: String, value: float) -> void:
		counters[label] = value


class FakeIntroModule:
	extends RefCounted

	var active := true
	var overlay_active := true
	var update_calls := 0

	func is_active() -> bool:
		return active

	func is_overlay_active() -> bool:
		return overlay_active

	func update(_delta: float, _arg_a: Variant = null, _arg_b: Variant = null) -> void:
		update_calls += 1


class LoadingDrawHarness:
	extends Node2D

	var renderer: Object = null
	var loading_owner: Object = null
	var module_getter: Callable
	var view_size := Vector2(1280.0, 720.0)
	var context: Dictionary = {}
	var draw_count := 0

	func _draw() -> void:
		if renderer == null:
			return
		renderer.draw(self, loading_owner, module_getter, view_size, context)
		draw_count += 1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_not_initialized_gate_draws_loading_screen()
	_verify_boot_warmup_gate_draws_loading_screen()
	_verify_stage_intro_gate_draws_loading_screen()
	_verify_completion_hold_does_not_block_started_intros()
	_verify_loading_snapshot_uses_warmup_status()
	_verify_warmup_progress_contract()
	_verify_boot_warmup_process_perf_batch_label()
	await _verify_minimal_cameo_prewarm_and_session_lock()
	_verify_cameo_uses_live_viewport_after_scene_transition()
	_verify_cameo_host_disables_physics_interpolation()
	_verify_tip_rotation_anchored_to_visible_start()
	await _verify_minimal_completion_hold_timing()
	await _verify_hide_loading_resets_session()
	await _verify_all_stage_numbers_share_minimal_loading()
	_verify_snapshot_keeps_tip_and_progress_contract()

	if _failures.is_empty():
		print("battle_loading_screen_renderer_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_not_initialized_gate_draws_loading_screen() -> void:
	var controller: Object = BattleSceneIntroFrameController.new()
	var loading := FakeLoadingRenderer.new()
	_modules = {"battle_loading_screen_renderer": loading}
	var canvas := Node2D.new()

	var consumed: bool = bool(controller.draw_intro_or_boot(
		canvas,
		FakeOwner.new(),
		null,
		Callable(self, "_get_module"),
		{
			"is_battle_initialized": Callable(self, "_false_callback"),
			"is_stage_landing_intro_started": Callable(self, "_false_callback"),
		},
		Vector2(1280.0, 720.0)
	))
	canvas.free()

	_expect(consumed, "not-initialized intro gate should consume the draw frame")
	_expect(loading.draw_calls == 1, "not-initialized intro gate should draw the loading screen")
	_expect(not bool(loading.last_context.get("battle_initialized", true)), "loading context should mark battle as not initialized")


func _verify_boot_warmup_gate_draws_loading_screen() -> void:
	var controller: Object = BattleSceneIntroFrameController.new()
	var loading := FakeLoadingRenderer.new()
	var readiness := FakeReadiness.new()
	readiness.warmup_finished = false
	_modules = {
		"battle_loading_screen_renderer": loading,
		"battle_scene_readiness_controller": readiness,
	}
	var canvas := Node2D.new()

	var consumed: bool = bool(controller.draw_intro_or_boot(
		canvas,
		FakeOwner.new(),
		null,
		Callable(self, "_get_module"),
		{
			"is_battle_initialized": Callable(self, "_true_callback"),
			"is_stage_landing_intro_started": Callable(self, "_true_callback"),
		},
		Vector2(1280.0, 720.0)
	))
	canvas.free()

	_expect(consumed, "boot-warmup gate should consume the draw frame")
	_expect(loading.draw_calls == 1, "boot-warmup gate should draw the loading screen")
	_expect(bool(loading.last_context.get("battle_initialized", false)), "loading context should preserve initialized state")


func _verify_stage_intro_gate_draws_loading_screen() -> void:
	var controller: Object = BattleSceneIntroFrameController.new()
	var loading := FakeLoadingRenderer.new()
	_modules = {"battle_loading_screen_renderer": loading}
	var canvas := Node2D.new()

	var consumed: bool = bool(controller.draw_intro_or_boot(
		canvas,
		FakeOwner.new(),
		null,
		Callable(self, "_get_module"),
		{
			"is_battle_initialized": Callable(self, "_true_callback"),
			"is_stage_landing_intro_started": Callable(self, "_false_callback"),
		},
		Vector2(1280.0, 720.0)
	))
	canvas.free()

	_expect(consumed, "stage-intro readiness gate should consume the draw frame")
	_expect(loading.draw_calls == 1, "stage-intro readiness gate should draw the loading screen")
	_expect(not bool(loading.last_context.get("stage_landing_intro_started", true)), "loading context should mark stage intro as pending")


func _verify_completion_hold_does_not_block_started_intros() -> void:
	var controller: Object = BattleSceneIntroFrameController.new()
	var loading := FakeLoadingRenderer.new()
	loading.hold_completion = true
	var readiness := FakeReadiness.new()
	readiness.warmup_finished = true
	var landing := FakeIntroModule.new()
	_modules = {
		"battle_loading_screen_renderer": loading,
		"battle_scene_readiness_controller": readiness,
		"stage_landing_intro": landing,
	}

	var consumed_landing: bool = bool(controller.process_idle(
		0.016,
		FakeOwner.new(),
		null,
		Callable(self, "_get_module"),
		{
			"is_battle_initialized": Callable(self, "_true_callback"),
			"is_stage_landing_intro_started": Callable(self, "_true_callback"),
		}
	))

	_expect(consumed_landing, "started landing intro should keep consuming idle frames")
	_expect(landing.update_calls == 1, "started landing intro should update even if the loading renderer would hold")
	_expect(loading.hold_calls == 0, "loading completion hold should not be queried after stage intro starts")

	var ball_spawn := FakeIntroModule.new()
	landing.active = false
	loading.hold_calls = 0
	_modules = {
		"battle_loading_screen_renderer": loading,
		"battle_scene_readiness_controller": readiness,
		"stage_landing_intro": landing,
		"stage_ball_spawn_intro": ball_spawn,
	}

	var consumed_ball_spawn: bool = bool(controller.process_idle(
		0.016,
		FakeOwner.new(),
		null,
		Callable(self, "_get_module"),
		{
			"is_battle_initialized": Callable(self, "_true_callback"),
			"is_stage_landing_intro_started": Callable(self, "_true_callback"),
		}
	))

	_expect(consumed_ball_spawn, "started ball-spawn intro should keep consuming idle frames")
	_expect(ball_spawn.update_calls == 1, "ball-spawn intro should update even if the loading renderer would hold")
	_expect(loading.hold_calls == 0, "loading completion hold should not be queried during ball-spawn intro")


func _verify_loading_snapshot_uses_warmup_status() -> void:
	var renderer: Object = BattleLoadingScreenRenderer.new()
	var warmup: Object = BattleBootWarmupController.new()
	warmup.set("boot_warmup_step", 4)
	_modules = {"battle_boot_warmup_controller": warmup}

	var snapshot: Dictionary = renderer.build_snapshot(
		FakeOwner.new(),
		Callable(self, "_get_module"),
		{
			"battle_initialized": false,
			"stage_landing_intro_started": false,
		}
	)

	_expect(str(snapshot.get("title", "")) == "스테이지 진입 준비 중", "loading snapshot should expose Korean battle-entry title")
	_expect(str(snapshot.get("subtitle", "")).contains("스테이지 3"), "loading subtitle should include selected stage")
	_expect(str(snapshot.get("subtitle", "")).contains("바이퍼"), "loading subtitle should include selected character")
	_expect(str(snapshot.get("status", "")).contains("보스 리소스"), "loading status should come from the warmup step")
	_expect(float(snapshot.get("progress", 0.0)) > 0.15, "loading progress should reflect warmup progress")


func _verify_warmup_progress_contract() -> void:
	var warmup: Object = BattleBootWarmupController.new()
	_expect(int(warmup.get_total_steps()) == 21, "warmup progress should expose the current boot step count")
	_expect(str(warmup.get_status_text()) == "전투 화면 준비 중", "warmup should expose the first loading status")
	warmup.set("boot_warmup_step", 10)
	_expect(
		is_equal_approx(float(warmup.get_progress()), 10.0 / float(warmup.get_total_steps())),
		"warmup progress should scale by total steps"
	)
	var audio := FakeAudio.new()
	audio.setup_progress = 0.5
	warmup.set("boot_warmup_step", 8)
	_modules = {
		"battle_boot_warmup_controller": warmup,
		"game_audio": audio,
	}
	var nested_progress := float(warmup.get_progress(Callable(self, "_get_module")))
	_expect(nested_progress > 8.0 / float(warmup.get_total_steps()), "audio setup progress should advance past the fixed 38 percent step")
	_expect(nested_progress < 9.0 / float(warmup.get_total_steps()), "audio setup progress should stay inside the current boot step")
	var renderer := BattleLoadingScreenRenderer.new()
	_expect(
		is_equal_approx(float(renderer._get_warmup_progress(Callable(self, "_get_module"))), nested_progress),
		"loading renderer should pass the module getter so warmup can expose audio substep progress"
	)
	warmup.set("boot_warmup_step", 18)
	_expect(str(warmup.get_status_text()).contains("결과 화면"), "warmup should expose the stage-clear result prewarm status")
	warmup.set("boot_warmup_finished", true)
	_expect(is_equal_approx(float(warmup.get_progress()), 1.0), "finished warmup should report full progress")
	_expect(str(warmup.get_status_text()) == "전투 준비 완료", "finished warmup should expose completion text")


func _verify_boot_warmup_process_perf_batch_label() -> void:
	var controller: Object = BattleSceneIntroFrameController.new()
	var warmup: Object = BattleBootWarmupController.new()
	warmup.set("boot_warmup_step", 2)
	var readiness := FakeReadiness.new()
	readiness.warmup_finished = false
	var perf_logger := FakePerfLogger.new()
	_modules = {
		"battle_boot_warmup_controller": warmup,
		"battle_perf_logger": perf_logger,
		"battle_scene_readiness_controller": readiness,
	}

	var consumed: bool = bool(controller.process_idle(
		0.016,
		FakeOwner.new(),
		null,
		Callable(self, "_get_module"),
		{
			"run_boot_warmup_step": Callable(self, "_advance_fake_warmup_to_five"),
			"is_battle_initialized": Callable(self, "_true_callback"),
			"is_stage_landing_intro_started": Callable(self, "_false_callback"),
		}
	))

	_expect(consumed, "boot warmup process gate should consume idle frames while loading")
	_expect(perf_logger.labels.has("process.intro.boot_warmup_step"), "boot warmup should keep the legacy aggregate perf label")
	_expect(
		perf_logger.labels.has("process.intro.boot_warmup_batch.step_02_to_05"),
		"boot warmup should expose the budgeted batch start/end step in the perf label"
	)
	_expect(
		perf_logger.labels.has("process.intro.boot_warmup_batch_detail.step_02_to_05.02_texture_resources"),
		"boot warmup should expose the starting warmup detail in a batch-detail perf label"
	)
	_expect(
		is_equal_approx(float(perf_logger.counters.get("boot_warmup.batch.start_step", -1.0)), 2.0),
		"boot warmup perf counters should record the batch start step"
	)
	_expect(
		is_equal_approx(float(perf_logger.counters.get("boot_warmup.batch.end_step", -1.0)), 5.0),
		"boot warmup perf counters should record the batch end step"
	)
	_expect(
		is_equal_approx(float(perf_logger.counters.get("boot_warmup.batch.steps_advanced", -1.0)), 3.0),
		"boot warmup perf counters should record how many boot steps advanced"
	)


func _verify_minimal_cameo_prewarm_and_session_lock() -> void:
	var renderer := BattleLoadingScreenRenderer.new()
	var owner := FakeStageNode.new()
	var canvas := _build_loading_draw_harness(renderer, owner)
	get_root().add_child(canvas)
	renderer.prewarm_assets()
	_expect(
		LoadingCameoCatalog.get_prewarmed_entry_count() == LoadingCameoCatalog.ENTRIES.size(),
		"minimal loading prewarm should load every landed cameo sheet"
	)
	canvas.queue_redraw()
	await process_frame
	var first_state: Dictionary = renderer.get_loading_cameo_debug_state()
	canvas.queue_redraw()
	await process_frame
	var second_state: Dictionary = renderer.get_loading_cameo_debug_state()
	_expect(str(first_state.get("entry_id", "")) == "dalji_hoop_roll", "minimal loading should select the landed Dalji cameo")
	_expect(first_state.get("entry_id", "") == second_state.get("entry_id", ""), "cameo entry must stay fixed during one loading session")
	_expect(int(second_state.get("session_pick_count", 0)) == 1, "draw must not reroll the cameo every frame")
	_expect(bool(second_state.get("visible", false)), "minimal loading should show the cameo host after draw")
	renderer.hide_loading()
	owner.queue_free()
	canvas.queue_free()


func _verify_cameo_uses_live_viewport_after_scene_transition() -> void:
	var host := LoadingCameoHost.new()
	get_root().add_child(host)
	LoadingCameoHost.prewarm_assets()
	var stale_previous_scene_size := Vector2(1280.0, 720.0)
	host.show_loading(stale_previous_scene_size, 0.0, ThemeDB.fallback_font, true)
	var live_view_size: Vector2 = host.get_viewport().get_visible_rect().size
	var state: Dictionary = host.get_debug_state()
	var resolved_view_size: Vector2 = state.get("resolved_view_size", Vector2.ZERO)
	var cameo_center: Vector2 = state.get("cameo_center", Vector2.ZERO)
	_expect(
		resolved_view_size.is_equal_approx(live_view_size),
		"initial battle cameo must resolve the live viewport instead of a stale previous-scene size"
	)
	_expect(
		cameo_center.is_equal_approx(LoadingCameoCatalog.get_cameo_center(live_view_size)),
		"initial battle cameo must stay in the live viewport lower-right corner"
	)
	host.queue_free()


func _verify_cameo_host_disables_physics_interpolation() -> void:
	# Global physics interpolation is enabled project-wide. A host whose sprites
	# spawn at (0,0) and get positioned to the lower-right corner on the same
	# frame renders partway along that path (near screen center) until physics
	# ticks catch up — and the warmup-stalled first battle loading frames keep
	# that artifact on screen for ~0.5s. Full rule: docs/godot_runtime_traps.md.
	var host := LoadingCameoHost.new()
	_expect(
		host.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF,
		"loading cameo host must opt out of global physics interpolation or spawn-frame repositioning glides through screen center"
	)
	host.free()


func _verify_tip_rotation_anchored_to_visible_start() -> void:
	# The tip rotation clock must run on loading-visible elapsed time, not on
	# absolute engine uptime — otherwise every loading opens at a random phase
	# of the rotate window and the first tip can flip away almost instantly.
	var renderer := BattleLoadingScreenRenderer.new()
	var slot_count: int = BattleLoadingTips.get_rotation_tip_count(BattleLoadingTips.TIER_ADVANCED, "viper")
	var first_slot: int = renderer._resolve_tip_start_slot(BattleLoadingTips.TIER_ADVANCED, "viper")
	_expect(first_slot >= 0 and first_slot < slot_count, "tip start slot should land inside the rotation list")
	_expect(
		int(renderer._resolve_tip_start_slot(BattleLoadingTips.TIER_ADVANCED, "viper")) == first_slot,
		"tip start slot must stay fixed during one loading session"
	)
	renderer._mark_visible_started()
	_expect(
		float(renderer._elapsed_visible_seconds()) < 1.0,
		"tip clock should start near zero when the loading opens"
	)
	var now := Time.get_ticks_msec()
	var offset_msec: int = mini(now - 100, int(BattleLoadingTips.TIP_ROTATE_SECONDS * 1000.0) + 200)
	renderer._visible_started_msec = now - offset_msec
	var elapsed := float(renderer._elapsed_visible_seconds())
	_expect(
		absf(elapsed - float(offset_msec) / 1000.0) < 0.5,
		"tip clock should measure elapsed from the visible-start anchor, not absolute uptime"
	)
	renderer.hide_loading()
	_expect(int(renderer._tip_start_slot) == -1, "hide_loading should reroll the tip start slot for the next loading")


func _verify_minimal_completion_hold_timing() -> void:
	var renderer := BattleLoadingScreenRenderer.new()
	var owner := FakeStageNode.new()
	var warmup: Object = BattleBootWarmupController.new()
	warmup.set("boot_warmup_step", int(warmup.get_total_steps()))
	warmup.set("boot_warmup_finished", true)
	_modules = {"battle_boot_warmup_controller": warmup}
	_expect(bool(renderer.should_hold_completion(owner, Callable(self, "_get_module"))), "minimal loading should hold briefly to prevent a one-frame flash")
	var minimum_visible_msec := ceili(BattleLoadingScreenRenderer.MIN_LOADING_VISIBLE_SECONDS * 1000.0) + 1
	var now_msec := Time.get_ticks_msec()
	if now_msec < minimum_visible_msec:
		OS.delay_msec(minimum_visible_msec - now_msec)
		now_msec = Time.get_ticks_msec()
	renderer._visible_started_msec = now_msec - minimum_visible_msec
	_expect(bool(renderer.should_hold_completion(owner, Callable(self, "_get_module"))), "minimal loading should enter its short final fade")
	_expect(renderer._completion_fade_started_msec >= 0, "minimal loading should mark final fade start")
	var final_fade_msec := ceili(BattleLoadingScreenRenderer.FINAL_FADE_SECONDS * 1000.0) + 1
	renderer._completion_fade_started_msec = Time.get_ticks_msec() - final_fade_msec
	_expect(not bool(renderer.should_hold_completion(owner, Callable(self, "_get_module"))), "minimal loading should release after the final fade")
	owner.queue_free()


func _verify_hide_loading_resets_session() -> void:
	var renderer := BattleLoadingScreenRenderer.new()
	var owner := FakeStageNode.new()
	var canvas := _build_loading_draw_harness(renderer, owner)
	get_root().add_child(canvas)
	renderer.prewarm_assets()
	canvas.queue_redraw()
	await process_frame
	_expect(str(renderer.get_loading_cameo_debug_state().get("entry_id", "")) != "", "draw should start a cameo session")
	var released_host := renderer.loading_cameo_host
	renderer.hide_loading()
	var hidden_state: Dictionary = renderer.get_loading_cameo_debug_state()
	_expect(str(hidden_state.get("entry_id", "")) == "", "hide_loading should clear the session cameo pick")
	_expect(
		released_host == null or not is_instance_valid(released_host),
		"hide_loading should synchronously free the detached cameo host"
	)
	_expect(renderer._visible_started_msec == -1, "hide_loading should reset the visibility timer")
	_expect(renderer._completion_fade_started_msec == -1, "hide_loading should reset the fade timer")
	owner.queue_free()
	canvas.queue_free()


func _verify_all_stage_numbers_share_minimal_loading() -> void:
	var renderer := BattleLoadingScreenRenderer.new()
	var owner := FakeStageNode.new()
	var canvas := _build_loading_draw_harness(renderer, owner)
	get_root().add_child(canvas)
	owner.current_stage = 99
	renderer.prewarm_stage_assets(owner.current_stage)
	canvas.queue_redraw()
	await process_frame
	var state: Dictionary = renderer.get_loading_cameo_debug_state()
	_expect(str(state.get("entry_id", "")) == "dalji_hoop_roll", "minimal loading should not depend on stage-specific art")
	_expect(int(state.get("frame_count", 0)) == 16, "minimal loading should expose the 16-frame cameo contract")
	renderer.hide_loading()
	owner.queue_free()
	canvas.queue_free()


func _verify_snapshot_keeps_tip_and_progress_contract() -> void:
	var renderer := BattleLoadingScreenRenderer.new()
	var owner := FakeStageNode.new()
	var snapshot: Dictionary = renderer.build_snapshot(owner, Callable(self, "_get_module"), {"loading_progress": 0.42})
	_expect(is_equal_approx(float(snapshot.get("progress", 0.0)), 0.42), "minimal loading snapshot should preserve caller progress")
	_expect(str(snapshot.get("tip_tier", "")) != "", "minimal loading snapshot should preserve tip tier")
	_expect(str(snapshot.get("tip_character", "")) == "viper", "minimal loading snapshot should preserve tip character")
	owner.free()


func _build_loading_draw_harness(renderer: Object, owner: Object) -> LoadingDrawHarness:
	var harness := LoadingDrawHarness.new()
	harness.renderer = renderer
	harness.loading_owner = owner
	harness.module_getter = Callable(self, "_get_module")
	return harness


func _true_callback() -> bool:
	return true


func _false_callback() -> bool:
	return false


func _advance_fake_warmup_to_five() -> void:
	var warmup: Object = _get_module("battle_boot_warmup_controller")
	if warmup != null:
		warmup.set("boot_warmup_step", 5)


func _get_module(key: String) -> Object:
	var value: Variant = _modules.get(key, null)
	if typeof(value) == TYPE_OBJECT:
		return value as Object
	return null


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
