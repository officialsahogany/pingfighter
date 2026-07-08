extends SceneTree

const StarpointDowsingAttraction := preload("res://scripts/stages/common/starpoint_dowsing_attraction.gd")
const Stage1BalloonEvent := preload("res://scripts/stages/stage1/stage1_balloon_event.gd")
const Stage2PillarBackground := preload("res://scripts/stages/stage2/stage2_pillar_background.gd")
const Stage3BossSkillState := preload("res://scripts/stages/stage3/stage3_boss_skill_state.gd")
const Stage4BirdEvent := preload("res://scripts/stages/stage4/stage4_bird_event.gd")
const Stage5HongryunState := preload("res://scripts/stages/stage5/stage5_hongryun_state.gd")
const Stage6TetriserState := preload("res://scripts/stages/stage6/stage6_tetriser_state.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")

const ACTIVE_DOWSING_CONTEXT := {
	"active": true,
	"range": 280.0,
	"force": 3.5,
	"min_distance": 30.0,
	"max_speed": 8.0,
}
const PLAYER_CENTER := Vector2(380.0, 715.0)

var _failures: Array[String] = []


class StubMythicRuntime:
	extends RefCounted

	var pendulum_context: Dictionary = {}

	func get_dowsing_pendulum_context() -> Dictionary:
		return pendulum_context


class StubRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		return value if value is Object else null


func _init() -> void:
	_verify_attraction_pulls_drop_toward_player()
	_verify_attraction_converges_over_steps()
	_verify_out_of_range_untouched()
	_verify_min_distance_untouched()
	_verify_inactive_context_noop()
	_verify_starlight_claimed_drop_skipped()
	_verify_max_speed_capped()
	_verify_resolve_context_gates_on_active()
	_verify_stage_states_delegate_attraction()
	_verify_stage2_behavioral_pull()
	_verify_stage_loop_behavioral_pull_all_stages()
	_verify_perk_conversion_end_to_end_pull()

	if _failures.is_empty():
		print("starpoint_dowsing_attraction_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _build_drop(pos: Vector2, vel: Vector2 = Vector2.ZERO) -> Dictionary:
	return {
		"life": 600.0,
		"pos": pos,
		"vel": vel,
		"size": 12.0,
	}


func _verify_attraction_pulls_drop_toward_player() -> void:
	var drop := _build_drop(Vector2(300.0, 500.0))
	StarpointDowsingAttraction.apply_to_drop(drop, ACTIVE_DOWSING_CONTEXT, PLAYER_CENTER, 1.0)
	var vel: Vector2 = drop.get("vel", Vector2.ZERO)
	_expect(vel.x > 0.0, "dowsing attraction should pull drop velocity toward the player on x")
	_expect(vel.y > 0.0, "dowsing attraction should pull drop velocity toward the player on y")


func _verify_attraction_converges_over_steps() -> void:
	var drop := _build_drop(Vector2(250.0, 520.0))
	var start_distance: float = Vector2(drop["pos"]).distance_to(PLAYER_CENTER)
	for _step in range(30):
		StarpointDowsingAttraction.apply_to_drop(drop, ACTIVE_DOWSING_CONTEXT, PLAYER_CENTER, 1.0)
		drop["pos"] = Vector2(drop["pos"]) + Vector2(drop["vel"])
	var end_distance: float = Vector2(drop["pos"]).distance_to(PLAYER_CENTER)
	_expect(
		end_distance < start_distance * 0.5,
		"dowsing attraction should converge the drop toward the player over repeated steps"
	)


func _verify_out_of_range_untouched() -> void:
	var drop := _build_drop(Vector2(60.0, 80.0), Vector2(1.0, 2.0))
	StarpointDowsingAttraction.apply_to_drop(drop, ACTIVE_DOWSING_CONTEXT, PLAYER_CENTER, 1.0)
	_expect(
		Vector2(drop.get("vel", Vector2.ZERO)) == Vector2(1.0, 2.0),
		"dowsing attraction should not touch drops outside the attraction range"
	)


func _verify_min_distance_untouched() -> void:
	var drop := _build_drop(PLAYER_CENTER + Vector2(10.0, 0.0), Vector2(1.0, 2.0))
	StarpointDowsingAttraction.apply_to_drop(drop, ACTIVE_DOWSING_CONTEXT, PLAYER_CENTER, 1.0)
	_expect(
		Vector2(drop.get("vel", Vector2.ZERO)) == Vector2(1.0, 2.0),
		"dowsing attraction should not touch drops inside min distance"
	)


func _verify_inactive_context_noop() -> void:
	var drop := _build_drop(Vector2(300.0, 500.0), Vector2(1.0, 2.0))
	StarpointDowsingAttraction.apply_to_drop(drop, {}, PLAYER_CENTER, 1.0)
	_expect(
		Vector2(drop.get("vel", Vector2.ZERO)) == Vector2(1.0, 2.0),
		"empty dowsing context should be a no-op"
	)


func _verify_starlight_claimed_drop_skipped() -> void:
	var drop := _build_drop(Vector2(300.0, 500.0), Vector2(1.0, 2.0))
	drop["lingpet_starlight_tracking_active"] = true
	StarpointDowsingAttraction.apply_to_drop(drop, ACTIVE_DOWSING_CONTEXT, PLAYER_CENTER, 1.0)
	_expect(
		Vector2(drop.get("vel", Vector2.ZERO)) == Vector2(1.0, 2.0),
		"starlight-tracking claimed drops should be exempt from dowsing attraction"
	)


func _verify_max_speed_capped() -> void:
	var strong_context := {
		"active": true,
		"range": 600.0,
		"force": 50.0,
		"min_distance": 30.0,
		"max_speed": 8.0,
	}
	var drop := _build_drop(Vector2(340.0, 660.0), Vector2(6.0, 6.0))
	StarpointDowsingAttraction.apply_to_drop(drop, strong_context, PLAYER_CENTER, 1.0)
	_expect(
		Vector2(drop.get("vel", Vector2.ZERO)).length() <= 8.0 + 0.001,
		"dowsing attraction should cap the drop speed at max_speed"
	)


func _verify_resolve_context_gates_on_active() -> void:
	var runtime := StubMythicRuntime.new()
	var registry := StubRegistry.new()
	registry.instances["mythic_item_runtime"] = runtime

	runtime.pendulum_context = {"active": false}
	var inactive: Dictionary = StarpointDowsingAttraction.resolve_context({"registry": registry}, {})
	_expect(inactive.is_empty(), "resolve_context should return empty when the pendulum is inactive")

	runtime.pendulum_context = ACTIVE_DOWSING_CONTEXT
	var from_registry: Dictionary = StarpointDowsingAttraction.resolve_context({"registry": registry}, {})
	_expect(
		bool(from_registry.get("active", false)) and float(from_registry.get("range", 0.0)) == 280.0,
		"resolve_context should surface the active pendulum context from the registry"
	)

	var from_deps: Dictionary = StarpointDowsingAttraction.resolve_context({}, {"mythic_item_runtime": runtime})
	_expect(
		bool(from_deps.get("active", false)),
		"resolve_context should accept a direct mythic_item_runtime dep"
	)

	var missing: Dictionary = StarpointDowsingAttraction.resolve_context({}, {})
	_expect(missing.is_empty(), "resolve_context should return empty without a runtime source")


func _verify_stage_states_delegate_attraction() -> void:
	var paths := [
		"res://scripts/stages/stage1/stage1_balloon_event.gd",
		"res://scripts/stages/stage2/stage2_pillar_background.gd",
		"res://scripts/stages/stage3/stage3_boss_skill_state.gd",
		"res://scripts/stages/stage4/stage4_bird_event.gd",
		"res://scripts/stages/stage5/stage5_hongryun_state.gd",
		"res://scripts/stages/stage6/stage6_tetriser_state.gd",
	]
	for path in paths:
		var source: String = FileAccess.get_file_as_string(path)
		_expect(
			source.find("StarpointDowsingAttraction.resolve_context") >= 0,
			"%s should resolve the dowsing context for starpoint drops" % path
		)
		_expect(
			source.find("StarpointDowsingAttraction.apply_to_drop") >= 0,
			"%s should apply dowsing attraction to starpoint drops" % path
		)


func _verify_stage2_behavioral_pull() -> void:
	var runtime := StubMythicRuntime.new()
	runtime.pendulum_context = {
		"active": true,
		"range": 600.0,
		"force": 3.5,
		"min_distance": 30.0,
		"max_speed": 8.0,
	}
	var registry := StubRegistry.new()
	registry.instances["mythic_item_runtime"] = runtime

	var context := {
		"current_stage": 2,
		"player_pos": Vector2(690.0, 700.0),
		"player_paddle_size": Vector2(20.0, 20.0),
		"play_left": 0.0,
		"play_right": 760.0,
		"height": 750.0,
		"registry": registry,
	}

	var pulled_background := Stage2PillarBackground.new()
	pulled_background.starpoint_drops = [_build_drop(Vector2(400.0, 600.0))]
	pulled_background._update_starpoint_drops(1.0, context, {})
	_expect(pulled_background.starpoint_drops.size() == 1, "Stage 2 pulled drop should stay alive")
	var pulled_vel: Vector2 = Vector2(pulled_background.starpoint_drops[0].get("vel", Vector2.ZERO))
	_expect(
		pulled_vel.x > 0.0,
		"Stage 2 drop update should gain x velocity toward the player while dowsing is active"
	)

	var baseline_context := context.duplicate(true)
	baseline_context.erase("registry")
	var baseline_background := Stage2PillarBackground.new()
	baseline_background.starpoint_drops = [_build_drop(Vector2(400.0, 600.0))]
	baseline_background._update_starpoint_drops(1.0, baseline_context, {})
	_expect(baseline_background.starpoint_drops.size() == 1, "Stage 2 baseline drop should stay alive")
	var baseline_vel: Vector2 = Vector2(baseline_background.starpoint_drops[0].get("vel", Vector2.ZERO))
	_expect(
		is_zero_approx(baseline_vel.x),
		"Stage 2 drop update should keep x velocity untouched without dowsing"
	)


func _build_stage_context(stage_id: int, registry: Object) -> Dictionary:
	var context := {
		"current_stage": stage_id,
		"width": 760.0,
		"height": 750.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"play_height": 750.0,
		"player_pos": Vector2(302.5, 690.0),
		"player_paddle_size": Vector2(155.0, 50.0),
	}
	if registry != null:
		context["registry"] = registry
	return context


func _build_dowsing_registry(range_value: float = 600.0) -> Object:
	var runtime := StubMythicRuntime.new()
	runtime.pendulum_context = {
		"active": true,
		"range": range_value,
		"force": 3.5,
		"min_distance": 30.0,
		"max_speed": 8.0,
	}
	var registry := StubRegistry.new()
	registry.instances["mythic_item_runtime"] = runtime
	return registry


# 각 스테이지 루프 구조 변형(S1 멤버 바운드, S3 next_drops, S4 in-place,
# S6 자체 rect 해석)이 실제로 흡인을 적용하는지 행동으로 검증한다.
# S2는 위 레그, S5는 아래 E2E 레그가 커버.
func _verify_stage_loop_behavioral_pull_all_stages() -> void:
	var registry: Object = _build_dowsing_registry()

	var stage1 := Stage1BalloonEvent.new()
	stage1.starpoint_drops.append(_build_drop(Vector2(200.0, 600.0)))
	stage1._update_starpoint_drops(1.0, _build_stage_context(1, registry), {})
	_expect(stage1.starpoint_drops.size() == 1, "Stage 1 pulled drop should stay alive")
	_expect(
		Vector2(stage1.starpoint_drops[0].get("vel", Vector2.ZERO)).x > 0.0,
		"Stage 1 drop loop should apply dowsing attraction"
	)

	var stage3 := Stage3BossSkillState.new()
	stage3.starpoint_drops.append(_build_drop(Vector2(200.0, 600.0)))
	stage3._update_starpoint_drops(1.0, _build_stage_context(3, registry), {})
	_expect(stage3.starpoint_drops.size() == 1, "Stage 3 pulled drop should stay alive")
	_expect(
		Vector2(stage3.starpoint_drops[0].get("vel", Vector2.ZERO)).x > 0.0,
		"Stage 3 drop loop should apply dowsing attraction"
	)

	var stage4 := Stage4BirdEvent.new()
	stage4.starpoint_drops.append(_build_drop(Vector2(200.0, 600.0)))
	stage4._update_starpoint_drops(1.0, _build_stage_context(4, registry), {})
	_expect(stage4.starpoint_drops.size() == 1, "Stage 4 pulled drop should stay alive")
	_expect(
		Vector2(stage4.starpoint_drops[0].get("vel", Vector2.ZERO)).x > 0.0,
		"Stage 4 drop loop should apply dowsing attraction"
	)

	var stage6 := Stage6TetriserState.new()
	stage6._starpoint_drops.append(_build_drop(Vector2(200.0, 600.0)))
	stage6._update_starpoint_drops(1.0, _build_stage_context(6, registry), {})
	_expect(stage6._starpoint_drops.size() == 1, "Stage 6 pulled drop should stay alive")
	_expect(
		Vector2(stage6._starpoint_drops[0].get("vel", Vector2.ZERO)).x > 0.0,
		"Stage 6 drop loop should apply dowsing attraction"
	)


# 다우징 "퍽" 실경로 관통 E2E: 변환 플래그 ON + RuntimePerkState 레벨 →
# MythicItemRuntime 컨텍스트 → 스테이지5 실업데이트 흡인까지.
func _verify_perk_conversion_end_to_end_pull() -> void:
	PerkConversionFlags.debug_set_enabled(true)

	var mythic_runtime: Object = MythicItemRuntime.new()
	var perk_state: Object = RuntimePerkState.new()
	perk_state.runtime_skill_levels["dowsing_pendulum"] = 5
	mythic_runtime.get_snapshot()
	var registry := StubRegistry.new()
	registry.instances["mythic_item_runtime"] = mythic_runtime
	registry.instances["runtime_perk_state"] = perk_state
	mythic_runtime.owner_syncer.sync_runtime_perk_state_ref(mythic_runtime, registry)

	var expected_range: float = PerkConversionValues.get_value("dowsing_pendulum", "attraction_range", 5)
	_expect(
		is_equal_approx(mythic_runtime.get_dowsing_pendulum_range(), expected_range),
		"converted dowsing perk Lv5 should surface the Lv5 attraction range"
	)
	var resolved: Dictionary = StarpointDowsingAttraction.resolve_context({"registry": registry}, {})
	_expect(
		bool(resolved.get("active", false)) and is_equal_approx(float(resolved.get("range", 0.0)), expected_range),
		"resolve_context should surface the converted perk range end to end"
	)

	var state := Stage5HongryunState.new()
	var context: Dictionary = _build_stage_context(5, registry)
	context["ball_active"] = true
	context["waiting_for_serve"] = false
	context["ball_pos"] = Vector2(380.0, 60.0)
	context["ball_vel"] = Vector2(2.0, -6.0)
	context["boss_pos"] = Vector2(330.0, 25.0)
	state._spawn_starpoint_drop_at(Vector2(200.0, 600.0), {}, context)
	_expect(state.starpoint_drops.size() == 1, "E2E: stage 5 spawn helper should append one drop")
	state.starpoint_drops[0]["vel"] = Vector2.ZERO
	state.update(1.0 / 60.0, context, {})
	_expect(state.starpoint_drops.size() == 1, "E2E: pulled drop should stay alive")
	_expect(
		Vector2(state.starpoint_drops[0].get("vel", Vector2.ZERO)).x > 0.0,
		"E2E: converted dowsing perk should pull stage 5 starpoint drops through the live update"
	)

	PerkConversionFlags.debug_set_enabled(false)

	var off_state := Stage5HongryunState.new()
	var off_context: Dictionary = _build_stage_context(5, registry)
	off_context["ball_active"] = true
	off_context["waiting_for_serve"] = false
	off_context["ball_pos"] = Vector2(380.0, 60.0)
	off_context["ball_vel"] = Vector2(2.0, -6.0)
	off_context["boss_pos"] = Vector2(330.0, 25.0)
	off_state._spawn_starpoint_drop_at(Vector2(200.0, 600.0), {}, off_context)
	off_state.starpoint_drops[0]["vel"] = Vector2.ZERO
	off_state.update(1.0 / 60.0, off_context, {})
	_expect(off_state.starpoint_drops.size() == 1, "E2E control: drop should stay alive without the perk")
	_expect(
		is_zero_approx(Vector2(off_state.starpoint_drops[0].get("vel", Vector2.ZERO)).x),
		"E2E control: flag OFF without equip should leave the drop x velocity untouched"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
