extends SceneTree

const BattleBootWarmupController := preload("res://scripts/core/battle_boot_warmup_controller.gd")
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


class FakeStage2Node:
	extends Node2D

	var current_stage := 2
	var selected_character_name := "바이퍼"
	var selected_character_type := "viper"


class FakeStage3Node:
	extends Node2D

	var current_stage := 3
	var selected_character_type := "viper"


class FakeStage4Node:
	extends Node2D

	var current_stage := 4
	var selected_character_type := "viper"


class FakeReadiness:
	extends RefCounted

	var warmup_finished := false

	func is_boot_warmup_finished(_module_getter: Callable) -> bool:
		return warmup_finished


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


func _init() -> void:
	_verify_not_initialized_gate_draws_loading_screen()
	_verify_boot_warmup_gate_draws_loading_screen()
	_verify_stage_intro_gate_draws_loading_screen()
	_verify_completion_hold_does_not_block_started_intros()
	_verify_loading_snapshot_uses_warmup_status()
	_verify_warmup_progress_contract()
	_verify_stage1_stained_glass_loading_path()
	_verify_stage2_stained_glass_loading_path()
	_verify_stage3_stained_glass_loading_path()
	_verify_stage4_stained_glass_loading_path()
	_verify_stained_glass_host_released_on_non_stained_stage5()
	_verify_orphan_stained_glass_host_swept_on_non_stained_stage5()

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
	_expect(int(warmup.get_total_steps()) == 20, "warmup progress should expose the current boot step count")
	_expect(str(warmup.get_status_text()) == "전투 화면 준비 중", "warmup should expose the first loading status")
	warmup.set("boot_warmup_step", 10)
	_expect(is_equal_approx(float(warmup.get_progress()), 0.5), "warmup progress should scale by total steps")
	warmup.set("boot_warmup_finished", true)
	_expect(is_equal_approx(float(warmup.get_progress()), 1.0), "finished warmup should report full progress")
	_expect(str(warmup.get_status_text()) == "전투 준비 완료", "finished warmup should expose completion text")


func _verify_stage1_stained_glass_loading_path() -> void:
	var renderer := BattleLoadingScreenRenderer.new()
	var owner := FakeStageNode.new()
	var canvas := Node2D.new()
	var warmup: Object = BattleBootWarmupController.new()
	warmup.set("boot_warmup_step", 20)
	warmup.set("boot_warmup_finished", true)
	_modules = {"battle_boot_warmup_controller": warmup}

	renderer.prewarm_assets()
	_expect(renderer.get("stage1_stained_glass_texture") != null, "stage 1 stained-glass full-color texture should load")
	_expect(renderer.get("stage1_stained_glass_mask_texture") != null, "stage 1 stained-glass reveal mask should load")

	renderer.draw(
		canvas,
		owner,
		Callable(self, "_get_module"),
		Vector2(1280.0, 720.0),
		{
			"battle_initialized": false,
			"stage_landing_intro_started": false,
		}
	)
	_expect(renderer.get("stained_glass_host") != null, "stage 1 loading should attach a stained-glass host")
	_expect(bool(renderer.should_hold_completion(owner, Callable(self, "_get_module"))), "stage 1 loading should hold the completion reveal briefly")
	_spin_wait_msec(1350)
	_expect(bool(renderer.should_hold_completion(owner, Callable(self, "_get_module"))), "stage 1 loading should hold the final stained-glass flash")
	_expect(renderer._completion_reveal_started_msec >= 0, "stage 1 loading should start a completion reveal timer")
	var final_progress := float(renderer._get_stained_glass_display_progress(1.0))
	_expect(final_progress >= 0.92, "stage 1 final reveal should open the last color band")
	renderer._completion_reveal_started_msec = Time.get_ticks_msec() - 500
	_expect(not bool(renderer.should_hold_completion(owner, Callable(self, "_get_module"))), "stage 1 loading should release after the final flash")

	renderer.hide_loading()
	_expect(renderer.get("stained_glass_host") == null, "stage 1 loading should release the stained-glass host after hide")
	owner.free()
	canvas.free()


func _verify_stage2_stained_glass_loading_path() -> void:
	var renderer := BattleLoadingScreenRenderer.new()
	var owner := FakeStage2Node.new()
	var canvas := Node2D.new()
	var warmup: Object = BattleBootWarmupController.new()
	warmup.set("boot_warmup_step", 20)
	warmup.set("boot_warmup_finished", true)
	_modules = {"battle_boot_warmup_controller": warmup}

	renderer.prewarm_assets()
	_expect(renderer.get("stage2_stained_glass_texture") != null, "stage 2 stained-glass full-color texture should load")
	_expect(renderer.get("stage2_stained_glass_mask_texture") != null, "stage 2 stained-glass reveal mask should load")

	renderer.draw(
		canvas,
		owner,
		Callable(self, "_get_module"),
		Vector2(1280.0, 720.0),
		{
			"battle_initialized": false,
			"stage_landing_intro_started": false,
		}
	)
	_expect(renderer.get("stained_glass_host") != null, "stage 2 loading should attach a stained-glass host")
	_expect(bool(renderer.should_hold_completion(owner, Callable(self, "_get_module"))), "stage 2 loading should reuse the stained-glass completion hold")

	renderer.hide_loading()
	_expect(renderer.get("stained_glass_host") == null, "stage 2 loading should release the stained-glass host after hide")
	owner.free()
	canvas.free()


func _verify_stage3_stained_glass_loading_path() -> void:
	var renderer := BattleLoadingScreenRenderer.new()
	var owner := FakeStage3Node.new()
	var canvas := Node2D.new()
	var warmup: Object = BattleBootWarmupController.new()
	warmup.set("boot_warmup_step", 20)
	warmup.set("boot_warmup_finished", true)
	_modules = {"battle_boot_warmup_controller": warmup}

	renderer.prewarm_assets()
	_expect(renderer.get("stage3_stained_glass_texture") != null, "stage 3 stained-glass full-color texture should load")
	_expect(renderer.get("stage3_stained_glass_mask_texture") != null, "stage 3 stained-glass reveal mask should load")
	_expect(
		is_equal_approx(float(renderer._get_stage_reveal_softness(3)), float(renderer._get_stage_reveal_softness(1))),
		"stage 3 stained-glass reveal softness should match the stage 1 bottom-up reveal"
	)

	renderer.draw(
		canvas,
		owner,
		Callable(self, "_get_module"),
		Vector2(1280.0, 720.0),
		{
			"battle_initialized": false,
			"stage_landing_intro_started": false,
		}
	)
	_expect(renderer.get("stained_glass_host") != null, "stage 3 loading should attach a stained-glass host")
	_expect(bool(renderer.should_hold_completion(owner, Callable(self, "_get_module"))), "stage 3 loading should reuse the stained-glass completion hold")

	renderer.hide_loading()
	_expect(renderer.get("stained_glass_host") == null, "stage 3 loading should release the stained-glass host after hide")
	owner.free()
	canvas.free()


func _verify_stage4_stained_glass_loading_path() -> void:
	var renderer := BattleLoadingScreenRenderer.new()
	var owner := FakeStage4Node.new()
	var canvas := Node2D.new()
	var warmup: Object = BattleBootWarmupController.new()
	warmup.set("boot_warmup_step", 20)
	warmup.set("boot_warmup_finished", true)
	_modules = {"battle_boot_warmup_controller": warmup}

	renderer.prewarm_assets()
	_expect(renderer.get("stage4_stained_glass_texture") != null, "stage 4 stained-glass full-color texture should load")
	_expect(renderer.get("stage4_stained_glass_mask_texture") != null, "stage 4 stained-glass reveal mask should load")
	_expect(
		is_equal_approx(float(renderer._get_stage_reveal_softness(4)), float(renderer._get_stage_reveal_softness(1))),
		"stage 4 stained-glass reveal softness should match the stage 1 bottom-up reveal"
	)

	renderer.draw(
		canvas,
		owner,
		Callable(self, "_get_module"),
		Vector2(1280.0, 720.0),
		{
			"battle_initialized": false,
			"stage_landing_intro_started": false,
		}
	)
	_expect(renderer.get("stained_glass_host") != null, "stage 4 loading should attach a stained-glass host")
	_expect(bool(renderer.should_hold_completion(owner, Callable(self, "_get_module"))), "stage 4 loading should reuse the stained-glass completion hold")

	renderer.hide_loading()
	_expect(renderer.get("stained_glass_host") == null, "stage 4 loading should release the stained-glass host after hide")
	owner.free()
	canvas.free()


func _verify_stained_glass_host_released_on_non_stained_stage5() -> void:
	var renderer := BattleLoadingScreenRenderer.new()
	var owner := FakeStage2Node.new()
	var canvas := Node2D.new()
	var warmup: Object = BattleBootWarmupController.new()
	warmup.set("boot_warmup_step", 20)
	warmup.set("boot_warmup_finished", true)
	_modules = {"battle_boot_warmup_controller": warmup}
	renderer.prewarm_assets()
	renderer.draw(
		canvas,
		owner,
		Callable(self, "_get_module"),
		Vector2(1280.0, 720.0),
		{
			"battle_initialized": false,
			"stage_landing_intro_started": false,
		}
	)
	_expect(renderer.get("stained_glass_host") != null, "stage 2 loading should create the stained-glass host before stage changes")
	owner.current_stage = 5
	_expect(
		not bool(renderer.should_hold_completion(owner, Callable(self, "_get_module"))),
		"stage 5 loading should not hold stained-glass completion"
	)
	_expect(renderer.get("stained_glass_host") == null, "stage 5 loading draw should release the previous stained-glass host")
	_expect(owner.get_node_or_null("BattleLoadingStainedGlassHost") == null, "stage 5 loading draw should remove the stained-glass host from the battle tree")
	owner.free()
	canvas.free()


func _verify_orphan_stained_glass_host_swept_on_non_stained_stage5() -> void:
	var renderer := BattleLoadingScreenRenderer.new()
	var owner := FakeStage2Node.new()
	var stale_host := Control.new()
	stale_host.name = "BattleLoadingStainedGlassHost"
	owner.add_child(stale_host)
	owner.current_stage = 5
	_expect(
		not bool(renderer.should_hold_completion(owner, Callable(self, "_get_module"))),
		"stage 5 loading should not hold completion with an orphan stained-glass host"
	)
	_expect(owner.get_node_or_null("BattleLoadingStainedGlassHost") == null, "stage 5 loading should sweep orphan stained-glass hosts without renderer references")
	owner.free()


func _true_callback() -> bool:
	return true


func _false_callback() -> bool:
	return false


func _get_module(key: String) -> Object:
	var value: Variant = _modules.get(key, null)
	if typeof(value) == TYPE_OBJECT:
		return value as Object
	return null


func _spin_wait_msec(duration_msec: int) -> void:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < duration_msec:
		pass


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
