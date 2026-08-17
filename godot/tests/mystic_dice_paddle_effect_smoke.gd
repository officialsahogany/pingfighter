extends SceneTree

const BallRoundActorCleanup := preload("res://scripts/ball/ball_round_actor_cleanup.gd")
const BattlePlayfieldEffectsDrawer := preload("res://scripts/core/battle_playfield_effects_drawer.gd")
const BattleSceneRuntimePerkUpdateDriver := preload(
	"res://scripts/core/battle_scene_runtime_perk_update_driver.gd"
)
const MatchResetController := preload("res://scripts/core/match_reset_controller.gd")
const MatchScoreEventController := preload("res://scripts/core/match_score_event_controller.gd")
const MysticDicePaddleEffect := preload(
	"res://scripts/characters/mystic_dice_paddle_effect.gd"
)
const MysticDicePaddleFxHost := preload(
	"res://scripts/characters/mystic_dice_paddle_fx_host.gd"
)
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const BattleBootResourcePrewarmController := preload(
	"res://scripts/core/battle_boot_resource_prewarm_controller.gd"
)
const SourceContractFunctionBody := preload("res://tests/source_contract_function_body.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_three_second_expiry_hides_bound_host()
	_verify_detached_host_is_controller_driven_and_deterministic()
	_verify_screen_state_mapping()
	_verify_physics_update_uses_dirty_redraw()
	_verify_round_score_stage_and_full_reset_cleanup()
	_verify_real_boot_lifecycle_binds_scene_host()
	_verify_source_contracts()
	if _failures.is_empty():
		print("mystic_dice_paddle_effect_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_three_second_expiry_hides_bound_host() -> void:
	var effect := MysticDicePaddleEffect.new()
	var host := HostProbe.new()
	var started: Dictionary = effect.start()
	effect.bind_host(host)
	host.set_active(true)
	_expect(bool(started.get("active", false)), "start should activate the three-second logical effect")
	_expect(is_equal_approx(float(started.get("remaining_seconds", 0.0)), 3.0), "start should expose the full three-second duration")
	_expect(effect.update(1.25), "active effect should advance from gameplay time")
	_expect(effect.is_active() and host.active, "effect and host should remain active before three seconds")
	_expect(effect.update(1.75), "final gameplay-time step should consume the remaining duration")
	_expect(not effect.is_active(), "effect should expire exactly at three seconds")
	_expect(not host.active and host.last_active_value == false, "natural expiry must directly hide the bound host")
	_expect(int(host.set_active_calls) == 2, "expiry should issue one hide after the test activation")
	host.free()


func _verify_detached_host_is_controller_driven_and_deterministic() -> void:
	var host := MysticDicePaddleFxHost.new()
	host.sync_state({
		"active": true,
		"screen_pos": Vector2(420.0, 610.0),
		"clip_position": Vector2(40.0, 10.0),
		"clip_size": Vector2(950.0, 937.5),
		"paddle_size": Vector2(155.0, 50.0),
		"render_scale": 1.25,
		"elapsed_seconds": 1.20,
		"intensity": 0.60,
	}, true)
	var status: Dictionary = host.get_debug_status()
	_expect(bool(status.get("active", false)), "valid sync should make the detached host visible")
	_expect(not bool(status.get("processing", true)), "controller-driven host must keep its own process disabled")
	_expect(int(status.get("visible_particle_count", 0)) > 0, "mid-effect deterministic schedule should expose live particles")
	_expect(bool(status.get("draw_bridge_is_child", false)), "clip host must render through a child CanvasItem bridge")
	_expect(status.get("draw_bridge_position") == Vector2(380.0, 600.0), "draw bridge should place the effect in clip-local coordinates")
	_expect(host.clip_contents and host.position == Vector2(40.0, 10.0), "host should own a full-playfield clip rect at the game offset")
	_expect(host.size == Vector2(950.0, 937.5) and host.scale == Vector2.ONE, "host clip size should match the rendered game canvas without node-scale leakage")
	host.set_active(false)
	_expect(not host.visible, "explicit host deactivation should hide presentation immediately")
	host.free()


func _verify_screen_state_mapping() -> void:
	var drawer := BattlePlayfieldEffectsDrawer.new()
	var state: Dictionary = drawer._build_mystic_dice_paddle_screen_state(
		{
			"active": true,
			"elapsed_seconds": 0.5,
			"intensity": 0.8,
		},
		null,
		null,
		{
			"game_offset": Vector2(120.0, 30.0),
			"game_size": Vector2(1520.0, 1500.0),
			"render_scale": 2.0,
			"player_pos": Vector2(100.0, 600.0),
			"player_paddle_size": Vector2(160.0, 48.0),
		},
		Vector2(3.0, -4.0)
	)
	var expected_center := Vector2(100.0, 600.0) + Vector2(80.0, 24.0) + Vector2(3.0, -4.0)
	_expect(state.get("screen_pos") == Vector2(120.0, 30.0) + expected_center * 2.0, "screen host should follow game offset, shake, paddle center, and render scale")
	_expect(state.get("clip_position") == Vector2(120.0, 30.0) and state.get("clip_size") == Vector2(1520.0, 1500.0), "detached host should clip to the full rendered game canvas")
	_expect(state.get("paddle_size") == Vector2(160.0, 48.0), "host should retain playfield paddle dimensions before node scaling")


func _verify_physics_update_uses_dirty_redraw() -> void:
	var pending_state := RuntimePerkState.new()
	pending_state._mystic_dice_paddle_effect_pending = true
	_expect(not bool(pending_state.get_mystic_dice_paddle_effect_snapshot().get("active", false)), "accepted finish should remain presentation-pending while modal physics is blocked")
	pending_state.update_mystic_dice_paddle_effect(0.1)
	var resumed_snapshot: Dictionary = pending_state.get_mystic_dice_paddle_effect_snapshot()
	_expect(bool(resumed_snapshot.get("active", false)), "first resumed gameplay tick should start the deferred three-second effect")
	_expect(is_equal_approx(float(resumed_snapshot.get("remaining_seconds", 0.0)), 3.0), "resume tick must not consume time that elapsed before the deferred effect started")

	var runtime := UpdateProbe.new()
	var registry := RegistryProbe.new(runtime)
	var owner := RedrawOwnerProbe.new()
	BattleSceneRuntimePerkUpdateDriver.new().update_runtime_perk_resume(owner, registry, 0.5)
	_expect(runtime.update_calls == 1, "runtime-perk physics driver should advance the Dice paddle effect once")
	_expect(owner.request_calls == 1, "active physics update should request the coalesced battle redraw")


func _verify_round_score_stage_and_full_reset_cleanup() -> void:
	var round_fixture := _active_runtime_fixture()
	BallRoundActorCleanup.new().reset_actor_round_state({"runtime_perk_state": round_fixture.state})
	_expect(_fixture_hidden(round_fixture), "generic round cleanup should clear logic and hide the host immediately")
	_free_fixture(round_fixture)

	var score_fixture := _active_runtime_fixture()
	MatchScoreEventController.new()._queue_perk_fusion_round_boundary(
		"player",
		{"runtime_perk_state": score_fixture.state}
	)
	_expect(_fixture_hidden(score_fixture), "accepted-score boundary should hide the host before result draw fanout stops")
	_free_fixture(score_fixture)

	var stage_fixture := _active_runtime_fixture()
	MatchResetController.new().reset_for_stage_transition(
		{"runtime_perk_state": stage_fixture.state},
		{}
	)
	_expect(_fixture_hidden(stage_fixture), "stage transition reset should clear the transient Dice paddle host")
	_free_fixture(stage_fixture)

	var reset_fixture := _active_runtime_fixture()
	reset_fixture.state.reset()
	_expect(_fixture_hidden(reset_fixture), "new-run/full reset should clear logic and hide the bound host")
	_free_fixture(reset_fixture)


# 실 부트 lifecycle 관통(v1 반려 P1): 실제 부트 프리웜 스텝이 실 씬 노드
# 아래에 실 호스트를 생성·부착·바인딩하고, 실 드로어 팬아웃이 그 호스트를
# 활성화하며, 씬 해제 후 stale 바인딩이 서빙되지 않고 재부트가 재바인딩
# 하는지 — 테스트가 가짜 호스트를 직접 바인딩하는 공허 경로를 걷어낸다.
func _verify_real_boot_lifecycle_binds_scene_host() -> void:
	var controller := BattleBootResourcePrewarmController.new()
	var state := RuntimePerkState.new()
	var owner := Node.new()
	root.add_child(owner)
	var module_getter := func(key: String) -> Object:
		return state if key == "runtime_perk_state" else null
	var step_done := false
	for _step_index: int in range(8):
		if bool(controller.prewarm_runtime_perk_overlay_resources_step(owner, module_getter)):
			step_done = true
			break
	_expect(step_done, "real boot prewarm step should complete")
	var host: Node = state.get_mystic_dice_paddle_fx_host()
	_expect(host != null and host.is_inside_tree() and host.get_parent() == owner, "boot step must create and attach the paddle host under the battle scene")
	_expect(host != null and host.has_method("sync_state") and host.has_method("get_debug_status"), "bound host should be the real MysticDicePaddleFxHost")
	var attached_child_count := owner.get_child_count()
	controller.battle_runtime_perk_overlay_prewarmed = false
	controller.prewarm_runtime_perk_overlay_resources_step(owner, module_getter)
	_expect(owner.get_child_count() == attached_child_count, "re-running the boot step must not attach a duplicate host")

	state.start_mystic_dice_paddle_effect()
	state.update_mystic_dice_paddle_effect(0.5)
	var drawer := BattlePlayfieldEffectsDrawer.new()
	var registry := RegistryProbe.new(state)
	drawer.draw_mystic_dice_paddle_effect(
		registry,
		{
			"game_offset": Vector2(40.0, 10.0),
			"game_size": Vector2(950.0, 937.5),
			"render_scale": 1.25,
			"player_pos": Vector2(100.0, 600.0),
			"player_paddle_size": Vector2(155.0, 50.0),
		},
		Vector2.ZERO
	)
	var status: Dictionary = host.get_debug_status()
	_expect(bool(status.get("active", false)), "real drawer fanout should activate the boot-attached host mid-effect")

	owner.free()
	_expect(state.get_mystic_dice_paddle_fx_host() == null, "a freed scene host must not be served as a stale binding")
	state.clear_mystic_dice_paddle_effect()
	var rebooted_controller := BattleBootResourcePrewarmController.new()
	var owner_next := Node.new()
	root.add_child(owner_next)
	var reboot_done := false
	for _reboot_index: int in range(8):
		if bool(rebooted_controller.prewarm_runtime_perk_overlay_resources_step(owner_next, module_getter)):
			reboot_done = true
			break
	_expect(reboot_done, "rebooted prewarm step should complete")
	var rebound_host: Node = state.get_mystic_dice_paddle_fx_host()
	_expect(rebound_host != null and rebound_host.is_inside_tree() and rebound_host.get_parent() == owner_next, "a fresh battle boot must rebind a new scene host after the old scene was freed")
	owner_next.free()


func _verify_source_contracts() -> void:
	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var owner_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_mystic_dice_runtime_state.gd")
	var finish_body := SourceContractFunctionBody.extract(owner_source, "func finish_modal_from_runtime_state")
	var accepted_index := finish_body.find("if not bool(finish_result.get(\"accepted\", false))")
	var pending_index := finish_body.find("queue_paddle_effect()")
	_expect(accepted_index >= 0 and pending_index > accepted_index, "accepted Dice finish should arm the paddle effect for the first resumed physics tick")
	var facade_finish_body := SourceContractFunctionBody.extract(state_source, "func _finish_mystic_dice_modal")
	_expect(facade_finish_body.contains("_mystic_dice_runtime_state.finish_modal_from_runtime_state"), "runtime Dice finish should delegate the transaction to the feature owner")

	var host_source := FileAccess.get_file_as_string("res://scripts/characters/mystic_dice_paddle_fx_host.gd")
	var draw_source := FileAccess.get_file_as_string("res://scripts/characters/mystic_dice_paddle_draw_bridge.gd")
	var draw_body := SourceContractFunctionBody.extract(draw_source, "func _draw()")
	_expect(not draw_body.contains("randf") and not draw_body.contains("randi"), "hot host draw must not consume RNG")
	_expect(not draw_body.contains("load(") and not draw_body.contains("ResourceLoader"), "hot host draw must not load resources")
	_expect(not host_source.contains("func _process("), "detached host must remain controller-driven")
	_expect(host_source.contains("clip_contents = true"), "detached screen-space host must clip to the full game canvas")
	_expect(host_source.contains("add_child(_draw_bridge)"), "the clipped Control must own the procedural CanvasItem as a child")

	var update_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_runtime_perk_update_driver.gd")
	var update_body := SourceContractFunctionBody.extract(update_source, "func update_runtime_perk_resume")
	_expect(update_body.contains("update_mystic_dice_paddle_effect"), "gameplay-time update fanout should own the three-second clock")
	var redraw_body := SourceContractFunctionBody.extract(update_source, "func _request_battle_redraw")
	_expect(redraw_body.contains("request_battle_redraw") and not redraw_body.contains(".queue_redraw"), "physics path must use only the coalesced redraw API")

	var boot_source := FileAccess.get_file_as_string("res://scripts/core/battle_boot_resource_prewarm_controller.gd")
	var boot_body := SourceContractFunctionBody.extract(boot_source, "func prewarm_runtime_perk_overlay_resources_step")
	_expect(boot_body.contains("_ensure_mystic_dice_paddle_fx_host"), "battle boot loading step must own the scene-host attach/bind wiring")

	var reset_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_reset_state.gd")
	_expect(reset_source.contains("_reset_mystic_dice_paddle_effect(runtime_state)"), "new-run reset facade should own direct effect cleanup")
	var scene_drawer_source := FileAccess.get_file_as_string("res://scripts/core/battle_playfield_scene_drawer.gd")
	_expect(scene_drawer_source.contains("draw_mystic_dice_paddle_effect"), "playfield fanout should sync the detached host after player rendering")


func _active_runtime_fixture() -> Dictionary:
	var state := RuntimePerkState.new()
	var host := HostProbe.new()
	state.start_mystic_dice_paddle_effect()
	state.bind_mystic_dice_paddle_fx_host(host)
	host.set_active(true)
	return {"state": state, "host": host}


func _fixture_hidden(fixture: Dictionary) -> bool:
	var state: Object = fixture.get("state")
	var host: Object = fixture.get("host")
	var snapshot: Dictionary = state.get_mystic_dice_paddle_effect_snapshot()
	return not bool(snapshot.get("active", true)) and not bool(host.active)


func _free_fixture(fixture: Dictionary) -> void:
	var host: Node = fixture.get("host")
	if host != null and is_instance_valid(host):
		host.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


class HostProbe:
	extends Node

	var active := false
	var set_active_calls := 0
	var last_active_value := false

	func set_active(next_active: bool) -> void:
		active = next_active
		last_active_value = next_active
		set_active_calls += 1


class UpdateProbe:
	extends RefCounted

	var update_calls := 0

	func update_mystic_dice_paddle_effect(_delta: float) -> bool:
		update_calls += 1
		return true


class RegistryProbe:
	extends RefCounted

	var runtime: Object

	func _init(next_runtime: Object) -> void:
		runtime = next_runtime

	func get_instance(key: String) -> Object:
		return runtime if key == "runtime_perk_state" else null


class RedrawOwnerProbe:
	extends RefCounted

	var request_calls := 0

	func request_battle_redraw() -> void:
		request_calls += 1
