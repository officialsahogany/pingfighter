extends SceneTree
# 바이퍼 연습모드 S2: 공 소유형 홀드(정지·히트가능·동일프레임 해제) 봉인.
# SSOT: docs/viper_practice_mode_slice_plan.md §S2.

const ViperPracticeMode := preload("res://scripts/hud/viper_practice_mode.gd")
const BallUpdateController := preload("res://scripts/ball/ball_update_controller.gd")
const GameplayModuleRegistry := preload("res://scripts/resources/gameplay_module_registry.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var ai_mode := "junior"
	var selected_character_type := "viper"
	var ball_pos := Vector2.ZERO
	var ball_vel := Vector2.ZERO
	var ball_active := false


class FakeViperSkillRuntime:
	extends RefCounted

	var shadow_hit_consumed := false
	var marshal_ball_hit := false

	func get_snapshot() -> Dictionary:
		return {
			"shadow_hit_consumed": shadow_hit_consumed,
			"marshal_ball_hit": marshal_ball_hit,
		}


class FakeRegistry:
	extends RefCounted

	var skill_runtime := FakeViperSkillRuntime.new()

	func get_instance(key: String) -> Object:
		if key == "viper_skill_runtime":
			return skill_runtime
		return null


func _init() -> void:
	_verify_hold_asserts_while_awaiting_shadow()
	_verify_same_frame_release_on_shadow_hit()
	_verify_stale_latch_rehold_after_ball_loss()
	_verify_marshal_completion_via_ball_path()
	_verify_double_observe_same_frame_is_safe()
	_verify_ball_staging()
	_verify_score_loss_intercept()
	_verify_ball_path_wiring()

	if _failures.is_empty():
		print("viper_practice_mode_ball_hold_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _start_mode(registry: FakeRegistry) -> Array:
	var owner := FakeOwner.new()
	owner.set_meta("tutorial_grip_style", "wasd_mouse")
	var mode: Object = ViperPracticeMode.new()
	mode.update(0.0, owner, registry)
	return [mode, owner]


func _verify_hold_asserts_while_awaiting_shadow() -> void:
	var registry := FakeRegistry.new()
	var pair := _start_mode(registry)
	var mode: Object = pair[0]

	var result: Dictionary = mode.apply_ball_hold_motion({}, registry.skill_runtime)
	_expect(bool(result.get("skip_ball_motion_step", false)), "hold should raise skip_ball_motion_step while awaiting the shadow step")
	_expect(result.get("ball_pos", Vector2.ZERO) == ViperPracticeMode.HOLD_BALL_POS, "hold should pin the ball at the practice hold position")
	_expect(result.get("ball_vel", Vector2.ONE) == Vector2.ZERO, "hold should zero the ball velocity every frame")
	_expect(float(result.get("player_collision_cooldown", 0.0)) >= 6.0, "hold should keep the paddle collision cooldown armed")

	# 매 프레임 재assert(라운드경계 정규화가 skip을 내려도 자가 복구).
	var repeat: Dictionary = mode.apply_ball_hold_motion({}, registry.skill_runtime)
	_expect(bool(repeat.get("skip_ball_motion_step", false)), "hold should re-assert the skip flag every physics frame")


func _verify_same_frame_release_on_shadow_hit() -> void:
	var registry := FakeRegistry.new()
	var pair := _start_mode(registry)
	var mode: Object = pair[0]
	mode.apply_ball_hold_motion({}, registry.skill_runtime)

	# 쉐백이 이번 물리 프레임에 공을 맞춤(바이퍼 패스가 발사 속도를 이미 씀).
	registry.skill_runtime.shadow_hit_consumed = true
	var release: Dictionary = mode.apply_ball_hold_motion({}, registry.skill_runtime)
	_expect(str(mode.get_snapshot().get("phase", "")) == "await_marshal", "ball-path observation should advance the mode on the hit frame")
	_expect(release.has("skip_ball_motion_step") and not bool(release.get("skip_ball_motion_step", true)), "hit frame must release skip_ball_motion_step in the SAME frame")
	_expect(not release.has("ball_vel"), "release must not overwrite the launch velocity the shadow hit just wrote")

	# 해제 후에는 더 이상 공 상태를 건드리지 않는다.
	var after: Dictionary = mode.apply_ball_hold_motion({}, registry.skill_runtime)
	_expect(after.is_empty(), "released hold should stop writing ball state")


func _verify_stale_latch_rehold_after_ball_loss() -> void:
	var registry := FakeRegistry.new()
	var pair := _start_mode(registry)
	var mode: Object = pair[0]
	mode.apply_ball_hold_motion({}, registry.skill_runtime)
	registry.skill_runtime.shadow_hit_consumed = true
	mode.apply_ball_hold_motion({}, registry.skill_runtime)
	_expect(str(mode.get_snapshot().get("phase", "")) == "await_marshal", "stale-latch fixture should reach the marshal phase")

	# 마샬 구간에서 공 상실 → 재시도. 래치는 여전히 true(다음 쉐백 시전까지 유지).
	mode.notify_ball_lost()
	_expect(str(mode.get_snapshot().get("phase", "")) == "await_shadow", "ball loss should return to the shadow phase")
	for _i in range(3):
		var rehold: Dictionary = mode.apply_ball_hold_motion({}, registry.skill_runtime)
		_expect(bool(rehold.get("skip_ball_motion_step", false)), "retry must re-hold the ball even while the shadow latch is stale true")
	_expect(str(mode.get_snapshot().get("phase", "")) == "await_shadow", "a stale shadow latch must not re-advance the retry")

	# 새 쉐백 시전(래치 리셋) 후 명중 → 정상 재전이.
	registry.skill_runtime.shadow_hit_consumed = false
	mode.apply_ball_hold_motion({}, registry.skill_runtime)
	registry.skill_runtime.shadow_hit_consumed = true
	mode.apply_ball_hold_motion({}, registry.skill_runtime)
	_expect(str(mode.get_snapshot().get("phase", "")) == "await_marshal", "a fresh shadow hit after the retry should advance again")


func _verify_marshal_completion_via_ball_path() -> void:
	var registry := FakeRegistry.new()
	var pair := _start_mode(registry)
	var mode: Object = pair[0]
	mode.apply_ball_hold_motion({}, registry.skill_runtime)
	registry.skill_runtime.shadow_hit_consumed = true
	mode.apply_ball_hold_motion({}, registry.skill_runtime)

	registry.skill_runtime.marshal_ball_hit = false
	mode.apply_ball_hold_motion({}, registry.skill_runtime)
	registry.skill_runtime.marshal_ball_hit = true
	var result: Dictionary = mode.apply_ball_hold_motion({}, registry.skill_runtime)
	_expect(bool(mode.has_completed_required_tutorials()), "marshal hit observed on the ball path should complete the practice")
	_expect(result.is_empty(), "completed practice must not write ball state from the hold hook")


func _verify_double_observe_same_frame_is_safe() -> void:
	var registry := FakeRegistry.new()
	var pair := _start_mode(registry)
	var mode: Object = pair[0]
	var owner: Object = pair[1]
	mode.apply_ball_hold_motion({}, registry.skill_runtime)
	registry.skill_runtime.shadow_hit_consumed = true
	mode.apply_ball_hold_motion({}, registry.skill_runtime)
	_expect(str(mode.get_snapshot().get("phase", "")) == "await_marshal", "double-observe fixture should reach the marshal phase via the ball path")

	# 같은 프레임에 HUD 업데이트가 같은 스냅샷을 다시 관찰해도 상태가 흔들리면 안 된다.
	mode.update(0.016, owner, registry)
	_expect(str(mode.get_snapshot().get("phase", "")) == "await_marshal", "HUD update observing the same latch values must not double-advance or regress the phase")


func _verify_ball_staging() -> void:
	var registry := FakeRegistry.new()
	var owner := FakeOwner.new()
	owner.set_meta("tutorial_grip_style", "wasd_mouse")
	var mode: Object = ViperPracticeMode.new()
	mode.update(0.0, owner, registry)
	mode.update(0.016, owner, registry)
	_expect(bool(owner.ball_active), "awaiting-shadow update should stage an inactive ball as active at the hold spot")
	_expect(owner.ball_pos == ViperPracticeMode.HOLD_BALL_POS, "staged ball should sit at the practice hold position")
	_expect(owner.ball_vel == Vector2.ZERO, "staged ball should start with zero velocity")

	# 공이 이미 활성인 동안은 HUD 경로가 공 상태를 덮어쓰지 않는다(물리 경로 단독 소유).
	owner.ball_pos = Vector2(100.0, 100.0)
	mode.update(0.016, owner, registry)
	_expect(owner.ball_pos == Vector2(100.0, 100.0), "HUD staging must not overwrite a live ball owned by the physics hold")


# S5: 라이브 구간(마샬 대기) 공 상실은 점수 대신 재시도로 흡수. 완료/홀드/부재
# 상태에서는 절대 삼키지 않는다(본게임 득점 보존).
func _verify_score_loss_intercept() -> void:
	var controller: Object = BallUpdateController.new()
	var registry := FakeRegistry.new()
	var pair := _start_mode(registry)
	var mode: Object = pair[0]

	# 홀드 구간(AWAIT_SHADOW)에서는 흡수하지 않는다(skip 중이라 애초에 득점도 없음).
	var held_scene := {"ball_active": true, "ball_vel": Vector2(3.0, 9.0)}
	_expect(not bool(controller._try_intercept_viper_practice_ball_loss(held_scene, {"viper_practice_mode": mode})), "hold phase must not intercept score events")
	_expect(bool(held_scene.get("ball_active", false)), "non-intercepted scene must stay untouched")

	# 마샬 구간으로 진입시킨 뒤 상실 → 흡수 + 공 비활성화 + 재시도 복귀.
	mode.apply_ball_hold_motion({}, registry.skill_runtime)
	registry.skill_runtime.shadow_hit_consumed = true
	mode.apply_ball_hold_motion({}, registry.skill_runtime)
	var live_scene := {"ball_active": true, "ball_vel": Vector2(3.0, 9.0)}
	_expect(bool(controller._try_intercept_viper_practice_ball_loss(live_scene, {"viper_practice_mode": mode})), "marshal-phase ball loss should be intercepted instead of scoring")
	_expect(not bool(live_scene.get("ball_active", true)), "intercepted ball should deactivate for re-staging at the hold spot")
	_expect(str(mode.get_snapshot().get("phase", "")) == "await_shadow", "intercepted loss should return the practice to the shadow phase")

	# 완료 후에는 절대 삼키지 않는다 — 본게임 득점 보존(핵심 안전선).
	registry.skill_runtime.shadow_hit_consumed = false
	mode.apply_ball_hold_motion({}, registry.skill_runtime)
	registry.skill_runtime.shadow_hit_consumed = true
	mode.apply_ball_hold_motion({}, registry.skill_runtime)
	registry.skill_runtime.marshal_ball_hit = false
	mode.apply_ball_hold_motion({}, registry.skill_runtime)
	registry.skill_runtime.marshal_ball_hit = true
	mode.apply_ball_hold_motion({}, registry.skill_runtime)
	_expect(bool(mode.has_completed_required_tutorials()), "intercept fixture should complete the combo")
	var post_scene := {"ball_active": true, "ball_vel": Vector2(3.0, 9.0)}
	_expect(not bool(controller._try_intercept_viper_practice_ball_loss(post_scene, {"viper_practice_mode": mode})), "completed practice must never swallow real-game score events")

	# 모듈 부재(비바이퍼/미등록) 시에도 득점은 그대로 흐른다.
	_expect(not bool(controller._try_intercept_viper_practice_ball_loss({}, {})), "missing practice module must not intercept score events")

	# 배선 순서: 인터셉트는 step_motion 결과와 score_event 반환 사이에 있어야 한다.
	var source: String = FileAccess.get_file_as_string("res://scripts/ball/ball_update_controller.gd")
	var step_index: int = source.find("motion_event_processor.step_motion(")
	var intercept_index: int = source.find("_try_intercept_viper_practice_ball_loss(scene, frame_deps)")
	var score_return_index: int = source.find("{\"score_event\": score_event}")
	_expect(step_index >= 0 and intercept_index > step_index and score_return_index > intercept_index, "score-loss intercept must sit between step_motion and the score_event return")


func _verify_ball_path_wiring() -> void:
	var update_controller_source: String = FileAccess.get_file_as_string("res://scripts/ball/ball_update_controller.gd")
	_expect(update_controller_source.find("apply_viper_practice_hold") >= 0, "ball update controller should invoke the practice hold after the viper skill pass")
	var viper_pass_index: int = update_controller_source.find("apply_viper_chaos_spear")
	var hold_index: int = update_controller_source.find("apply_viper_practice_hold")
	var skip_gate_index: int = update_controller_source.find("skip_ball_motion_step", hold_index)
	_expect(viper_pass_index >= 0 and hold_index > viper_pass_index and skip_gate_index > hold_index, "practice hold must run after the viper pass and before the skip short-circuit")

	var motion_controller_source: String = FileAccess.get_file_as_string("res://scripts/ball/ball_frame_motion_controller.gd")
	_expect(motion_controller_source.find("viper_practice_mode") >= 0, "frame motion controller should fetch the practice module from ball deps")

	var deps_source: String = FileAccess.get_file_as_string("res://scripts/ball/ball_dependency_context.gd")
	_expect(deps_source.find("viper_practice_mode") >= 0, "ball dependency context should provide the practice module to the ball path")

	var registry := GameplayModuleRegistry.new()
	var module: Object = registry.get_instance("viper_practice_mode")
	_expect(module != null and module.has_method("apply_ball_hold_motion"), "practice mode should be registered and expose the ball hold hook")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
