extends SceneTree

const ViperPracticeMode := preload("res://scripts/hud/viper_practice_mode.gd")
const TutorialHintKeycapRenderer := preload("res://scripts/hud/tutorial_hint_keycap_renderer.gd")
const ViperSkillGeometry := preload("res://scripts/characters/viper_skill_geometry.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

var _failures: Array[String] = []
var _language_settings_snapshot: Dictionary = {}


class FakeOwner:
	extends RefCounted

	var ai_mode := "junior"
	var selected_character_type := "viper"
	var special_gauge := 19.0
	var special_gauge_max := 500.0


class FakeViperSkillState:
	extends RefCounted

	var cooldowns: Dictionary = {}


class FakeViperSkillRuntime:
	extends RefCounted

	var shadow_hit_consumed := false
	var marshal_ball_hit := false

	func get_snapshot() -> Dictionary:
		return {
			"shadow_hit_consumed": shadow_hit_consumed,
			"marshal_ball_hit": marshal_ball_hit,
		}


class FakeJetpackHint:
	extends RefCounted

	var jetpack_done := false

	func has_completed_jetpack_tutorial() -> bool:
		return jetpack_done


class ModuleHolder:
	extends RefCounted

	var modules: Dictionary = {}

	func get_module(key: String) -> Object:
		var value: Variant = modules.get(key, null)
		if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
			return value as Object
		return null


class FakeRoundState:
	extends RefCounted

	var waiting_for_serve := true
	var pause_calls := 0

	func is_waiting_for_serve() -> bool:
		return waiting_for_serve

	func pause_serve_for_intro() -> void:
		waiting_for_serve = false
		pause_calls += 1


class FakeRegistry:
	extends RefCounted

	var skill_runtime := FakeViperSkillRuntime.new()
	var round_state: Object = null
	var skill_state: Object = null

	func get_instance(key: String) -> Object:
		if key == "viper_skill_runtime":
			return skill_runtime
		if key == "round_flow_state":
			return round_state
		if key == "viper_skill_state":
			return skill_state
		return null


func _init() -> void:
	_language_settings_snapshot = _snapshot_settings_file(LanguageSettings.SETTINGS_PATH)
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)
	_verify_gating()
	_verify_happy_path_combo()
	_verify_stale_latch_poisoning()
	_verify_marshal_timeout_retry()
	_verify_ball_lost_retry()
	_verify_round_serve_gate()
	_verify_hint_fade_and_keycap()
	_verify_intro_hint_gate()
	_verify_practice_resource_sustain()
	_verify_ground_shadow_step_reach()
	_verify_frame_controller_wiring()

	_restore_language_settings_snapshot()
	if _failures.is_empty():
		print("viper_practice_mode_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_gating() -> void:
	var registry := FakeRegistry.new()

	# 비-바이퍼는 절대 시작하지 않는다.
	var smasher_owner := FakeOwner.new()
	smasher_owner.selected_character_type = "smasher"
	smasher_owner.set_meta("tutorial_grip_style", "wasd_mouse")
	var smasher_mode: Object = ViperPracticeMode.new()
	smasher_mode.update(0.0, smasher_owner, registry)
	_expect(not bool(smasher_mode.get_snapshot().get("active", false)), "practice mode must never start for a non-viper character")

	# 주니어가 아니면 시작하지 않는다.
	var champion_owner := FakeOwner.new()
	champion_owner.ai_mode = "champion"
	champion_owner.set_meta("tutorial_grip_style", "wasd_mouse")
	var champion_mode: Object = ViperPracticeMode.new()
	champion_mode.update(0.0, champion_owner, registry)
	_expect(not bool(champion_mode.get_snapshot().get("active", false)), "practice mode must never start outside the junior league")

	# 그립 선택 전에는 대기한다.
	var ungripped_owner := FakeOwner.new()
	var ungripped_mode: Object = ViperPracticeMode.new()
	ungripped_mode.update(0.0, ungripped_owner, registry)
	_expect(not bool(ungripped_mode.get_snapshot().get("active", false)), "practice mode should wait until a grip style is selected")

	# 주니어 + 바이퍼 + 그립 → AWAIT_SHADOW로 시작, 공 홀드 요청.
	var owner := FakeOwner.new()
	owner.set_meta("tutorial_grip_style", "wasd_mouse")
	var mode: Object = ViperPracticeMode.new()
	_expect(bool(mode.update(0.0, owner, registry)), "junior viper with a grip should start the practice mode")
	_expect(str(mode.get_snapshot().get("phase", "")) == "await_shadow", "practice mode should begin awaiting the shadow step")
	_expect(bool(mode.wants_ball_hold()), "practice mode should request the frozen-ball hold while awaiting the shadow step")
	_expect(str(mode.get_snapshot().get("message", "")) == "A / D 이동 중 S ( 활주 ) 후 다시 S - 쉐도우 백스텝으로 공 맞추기", "shadow phase should teach the full move-glide-shadow step input chain")


func _verify_happy_path_combo() -> void:
	var registry := FakeRegistry.new()
	var owner := FakeOwner.new()
	owner.set_meta("tutorial_grip_style", "wasd_mouse")
	var mode: Object = ViperPracticeMode.new()
	mode.update(0.0, owner, registry)

	# 래치가 false를 한 번 지나야 엣지가 성립한다(정상 캐스트 흐름).
	registry.skill_runtime.shadow_hit_consumed = false
	mode.update(0.016, owner, registry)
	registry.skill_runtime.shadow_hit_consumed = true
	_expect(bool(mode.update(0.016, owner, registry)), "shadow-step hit rising edge should advance the practice mode")
	_expect(str(mode.get_snapshot().get("phase", "")) == "await_marshal", "shadow hit should move the mode to the marshal phase")
	_expect(not bool(mode.wants_ball_hold()), "ball hold should release once the shadow step launches the ball")
	_expect(str(mode.get_snapshot().get("message", "")) == "이어서 S - 마샬킥 연계!", "marshal phase should teach the chain input")

	registry.skill_runtime.marshal_ball_hit = false
	mode.update(0.016, owner, registry)
	registry.skill_runtime.marshal_ball_hit = true
	_expect(bool(mode.update(0.016, owner, registry)), "marshal-kick hit rising edge should complete the practice mode")
	_expect(str(mode.get_snapshot().get("phase", "")) == "complete", "marshal hit should complete the practice")
	_expect(bool(mode.has_completed_required_tutorials()), "completion should satisfy the mid-tutorial gate")
	_expect(not bool(mode.wants_ball_hold()), "completed practice must not hold the ball")
	_expect(not bool(mode.update(0.016, owner, registry)), "completed practice should stay inert")


func _verify_stale_latch_poisoning() -> void:
	var registry := FakeRegistry.new()
	var owner := FakeOwner.new()
	owner.set_meta("tutorial_grip_style", "wasd_mouse")
	var mode: Object = ViperPracticeMode.new()

	# 진입 시점에 이미 shadow_hit_consumed=true(이전 시도 잔여)면 즉시 전이하면 안 된다.
	registry.skill_runtime.shadow_hit_consumed = true
	mode.update(0.0, owner, registry)
	mode.update(0.016, owner, registry)
	mode.update(0.016, owner, registry)
	_expect(str(mode.get_snapshot().get("phase", "")) == "await_shadow", "a stale shadow-hit latch must not advance the practice mode")

	# 래치가 리셋(false)됐다가 다시 true가 되면 그때 전이한다.
	registry.skill_runtime.shadow_hit_consumed = false
	mode.update(0.016, owner, registry)
	registry.skill_runtime.shadow_hit_consumed = true
	mode.update(0.016, owner, registry)
	_expect(str(mode.get_snapshot().get("phase", "")) == "await_marshal", "a fresh shadow-hit edge after reset should advance the mode")

	# 마샬 래치도 동일: 잔여 true로는 완료되지 않는다.
	registry.skill_runtime.marshal_ball_hit = true
	mode.update(0.016, owner, registry)
	mode.update(0.016, owner, registry)
	_expect(str(mode.get_snapshot().get("phase", "")) == "await_marshal", "a stale marshal-hit latch must not complete the practice")
	registry.skill_runtime.marshal_ball_hit = false
	mode.update(0.016, owner, registry)
	registry.skill_runtime.marshal_ball_hit = true
	mode.update(0.016, owner, registry)
	_expect(str(mode.get_snapshot().get("phase", "")) == "complete", "a fresh marshal-hit edge should complete the practice")


func _verify_marshal_timeout_retry() -> void:
	var registry := FakeRegistry.new()
	var owner := FakeOwner.new()
	owner.set_meta("tutorial_grip_style", "wasd_mouse")
	var mode: Object = ViperPracticeMode.new()
	mode.update(0.0, owner, registry)
	registry.skill_runtime.shadow_hit_consumed = false
	mode.update(0.016, owner, registry)
	registry.skill_runtime.shadow_hit_consumed = true
	mode.update(0.016, owner, registry)
	_expect(str(mode.get_snapshot().get("phase", "")) == "await_marshal", "timeout fixture should reach the marshal phase")

	# 마샬킥이 제한시간 안에 착지하지 않으면 재시도(다시 홀드)로 돌아간다.
	_expect(bool(mode.update(8.0, owner, registry)), "marshal timeout should request a state change")
	_expect(str(mode.get_snapshot().get("phase", "")) == "await_shadow", "marshal timeout should return to the shadow phase for a retry")
	_expect(bool(mode.wants_ball_hold()), "retry should re-request the frozen-ball hold")
	_expect(int(mode.get_snapshot().get("retry_count", 0)) == 1, "retry counter should record the failed attempt")

	# 재시도 후에도 정상 성공 경로가 그대로 동작한다(무한 재시도, 스킵 없음).
	registry.skill_runtime.shadow_hit_consumed = false
	mode.update(0.016, owner, registry)
	registry.skill_runtime.shadow_hit_consumed = true
	mode.update(0.016, owner, registry)
	registry.skill_runtime.marshal_ball_hit = false
	mode.update(0.016, owner, registry)
	registry.skill_runtime.marshal_ball_hit = true
	mode.update(0.016, owner, registry)
	_expect(bool(mode.has_completed_required_tutorials()), "retry attempts should still be able to complete the practice")


func _verify_ball_lost_retry() -> void:
	var registry := FakeRegistry.new()
	var owner := FakeOwner.new()
	owner.set_meta("tutorial_grip_style", "wasd_mouse")
	var mode: Object = ViperPracticeMode.new()
	mode.update(0.0, owner, registry)
	_expect(not bool(mode.notify_ball_lost()), "ball-lost notification should be ignored while the ball is held")
	registry.skill_runtime.shadow_hit_consumed = false
	mode.update(0.016, owner, registry)
	registry.skill_runtime.shadow_hit_consumed = true
	mode.update(0.016, owner, registry)

	# AWAIT_MARSHAL 라이브 구간에서 공을 잃으면 점수 대신 재시도.
	_expect(bool(mode.notify_ball_lost()), "losing the live ball during the marshal phase should trigger a retry")
	_expect(str(mode.get_snapshot().get("phase", "")) == "await_shadow", "ball loss should return the mode to the shadow phase")
	_expect(bool(mode.wants_ball_hold()), "ball loss retry should re-request the frozen-ball hold")


# S4: 연습 중 서브 잠금 — 득점 리셋이 서브를 되살려도 매 프레임 재잠금, 완료 후엔 방치.
func _verify_round_serve_gate() -> void:
	var registry := FakeRegistry.new()
	registry.round_state = FakeRoundState.new()
	var owner := FakeOwner.new()
	owner.set_meta("tutorial_grip_style", "wasd_mouse")
	var mode: Object = ViperPracticeMode.new()
	mode.update(0.0, owner, registry)
	mode.update(0.016, owner, registry)
	_expect(not bool(registry.round_state.is_waiting_for_serve()), "practice mode should pause the serve flow while active")

	# 득점/리셋 경로가 waiting_for_serve 를 되살린 상황을 시뮬레이션 → 재잠금.
	registry.round_state.waiting_for_serve = true
	mode.update(0.016, owner, registry)
	_expect(not bool(registry.round_state.is_waiting_for_serve()), "practice mode should re-pause the serve flow after a round reset re-arms it")

	# 콤보 완료 후에는 서브 상태를 건드리지 않는다(정상 득점 경로가 서브를 복원).
	registry.skill_runtime.shadow_hit_consumed = false
	mode.update(0.016, owner, registry)
	registry.skill_runtime.shadow_hit_consumed = true
	mode.update(0.016, owner, registry)
	registry.skill_runtime.marshal_ball_hit = false
	mode.update(0.016, owner, registry)
	registry.skill_runtime.marshal_ball_hit = true
	mode.update(0.016, owner, registry)
	_expect(bool(mode.has_completed_required_tutorials()), "serve-gate fixture should complete the combo")
	registry.round_state.waiting_for_serve = true
	var pause_calls_before: int = registry.round_state.pause_calls
	mode.update(0.016, owner, registry)
	_expect(bool(registry.round_state.is_waiting_for_serve()), "completed practice must leave the serve flow alone")
	_expect(registry.round_state.pause_calls == pause_calls_before, "completed practice must not keep calling pause_serve_for_intro")


# S3: 안내 페이드인(페이즈 전환마다 리셋) + 키캡 토큰화(S만 키캡, 나머지 텍스트).
func _verify_hint_fade_and_keycap() -> void:
	var registry := FakeRegistry.new()
	var owner := FakeOwner.new()
	owner.set_meta("tutorial_grip_style", "wasd_mouse")
	var mode: Object = ViperPracticeMode.new()
	mode.update(0.0, owner, registry)
	_expect(is_equal_approx(float(mode.get_snapshot().get("alpha", 1.0)), 0.0), "hint should begin fully faded out")
	mode.update(0.3, owner, registry)
	var mid_alpha: float = float(mode.get_snapshot().get("alpha", 0.0))
	_expect(mid_alpha > 0.0 and mid_alpha < 1.0, "hint should fade in over time")
	mode.update(0.5, owner, registry)
	_expect(is_equal_approx(float(mode.get_snapshot().get("alpha", 0.0)), 1.0), "hint should hold at full alpha until success (no fade-out)")

	# 페이즈 전환 시 페이드인 재시작.
	registry.skill_runtime.shadow_hit_consumed = false
	mode.update(0.016, owner, registry)
	registry.skill_runtime.shadow_hit_consumed = true
	mode.update(0.016, owner, registry)
	_expect(str(mode.get_snapshot().get("phase", "")) == "await_marshal", "fade fixture should reach the marshal phase")
	_expect(float(mode.get_snapshot().get("alpha", 1.0)) < 0.1, "phase transition should restart the hint fade-in")

	# 연결자에 "→"를 쓰면 방향키 키캡으로 오인 렌더되므로 단어 연결자("후")를 봉인한다.
	var shadow_tokens: Array = TutorialHintKeycapRenderer.split_render_tokens("A / D 이동 중 S ( 활주 ) 후 다시 S - 쉐도우 백스텝으로 공 맞추기")
	_expect(_keycap_values(shadow_tokens) == ["A", "D", "S", "S"], "shadow hint should keycap exactly the move keys, the dash S and the shadow-step S (no stray arrow keycap)")
	var marshal_tokens: Array = TutorialHintKeycapRenderer.split_render_tokens("이어서 S - 마샬킥 연계!")
	_expect(_keycap_values(marshal_tokens) == ["S"], "marshal hint should keycap only the S key")


# S6: 기본 조작 안내 체인(이동→대쉬→체공)이 끝나야 연습이 시작된다.
func _verify_intro_hint_gate() -> void:
	var registry := FakeRegistry.new()
	var holder := ModuleHolder.new()
	var jetpack := FakeJetpackHint.new()
	holder.modules = {"viper_jetpack_tutorial_hint": jetpack}
	var getter := Callable(holder, "get_module")
	var owner := FakeOwner.new()
	owner.set_meta("tutorial_grip_style", "wasd_mouse")
	var mode: Object = ViperPracticeMode.new()

	jetpack.jetpack_done = false
	mode.update(0.0, owner, registry, getter)
	mode.update(5.0, owner, registry, getter)
	_expect(not bool(mode.get_snapshot().get("active", false)), "practice mode should wait for the jetpack tutorial to complete")

	jetpack.jetpack_done = true
	_expect(bool(mode.update(0.0, owner, registry, getter)), "practice mode should start once the jetpack tutorial completes")
	_expect(bool(mode.wants_ball_hold()), "post-intro start should immediately request the ball hold")


# 라이브 QA 피드백: 연습 중 게이지 500 유지 + 쉐백/마샬 쿨타임 0 유지(다른 스킬 불간섭),
# 완료 후에는 정상 규칙 복귀.
func _verify_practice_resource_sustain() -> void:
	var registry := FakeRegistry.new()
	registry.skill_state = FakeViperSkillState.new()
	var owner := FakeOwner.new()
	owner.special_gauge = 19.0
	owner.set_meta("tutorial_grip_style", "wasd_mouse")
	var mode: Object = ViperPracticeMode.new()
	mode.update(0.0, owner, registry)
	registry.skill_state.cooldowns = {
		"shadow_step": {"start_msec": 0, "cooldown_msec": 9000},
		"marshal_kick": {"start_msec": 0, "cooldown_msec": 25000},
		"dive_strike": {"start_msec": 0, "cooldown_msec": 20000},
	}
	mode.update(0.016, owner, registry)
	_expect(is_equal_approx(owner.special_gauge, 500.0), "practice mode should keep the special gauge pinned at max")
	_expect(not registry.skill_state.cooldowns.has("shadow_step"), "practice mode should keep the shadow step cooldown cleared")
	_expect(not registry.skill_state.cooldowns.has("marshal_kick"), "practice mode should keep the marshal kick cooldown cleared")
	_expect(registry.skill_state.cooldowns.has("dive_strike"), "practice mode must not clear unrelated skill cooldowns")

	# 콤보 완료 후에는 게이지/쿨타임을 건드리지 않는다.
	registry.skill_runtime.shadow_hit_consumed = false
	mode.update(0.016, owner, registry)
	registry.skill_runtime.shadow_hit_consumed = true
	mode.update(0.016, owner, registry)
	registry.skill_runtime.marshal_ball_hit = false
	mode.update(0.016, owner, registry)
	registry.skill_runtime.marshal_ball_hit = true
	mode.update(0.016, owner, registry)
	_expect(bool(mode.has_completed_required_tutorials()), "resource-sustain fixture should complete the combo")
	owner.special_gauge = 42.0
	registry.skill_state.cooldowns["shadow_step"] = {"start_msec": 0, "cooldown_msec": 9000}
	mode.update(0.016, owner, registry)
	_expect(is_equal_approx(owner.special_gauge, 42.0), "completed practice must stop pinning the gauge")
	_expect(registry.skill_state.cooldowns.has("shadow_step"), "completed practice must stop clearing cooldowns")


# 라이브 QA 회귀 씰: 홀드 공은 "지상" 쉐도우 백스텝으로 반드시 닿아야 한다(공중
# 캐스트 강제 금지). 지상 캐스트의 웨이브/홀로그램 히트 밴드는 패들 중심
# y = PLAYER_Y(700) + 패들높이/2 에서 수평 이동하므로, 실제 지오메트리 헬퍼로
# 그 밴드와 홀드 공 rect의 교차를 검증한다. HOLD_BALL_POS 재튜닝 시 이 씰이 지킨다.
func _verify_ground_shadow_step_reach() -> void:
	var paddle_size := Vector2(155.0, 50.0)
	var ground_cast_y: float = 700.0 + paddle_size.y * 0.5
	var ball_rect: Rect2 = ViperSkillGeometry.ball_rect({"ball_pos": ViperPracticeMode.HOLD_BALL_POS}, {})
	var wave_rect: Rect2 = ViperSkillGeometry.shadow_step_wave_rect(
		Vector2(ViperPracticeMode.HOLD_BALL_POS.x, ground_cast_y),
		Vector2(110.0, 90.0)
	)
	_expect(wave_rect.intersects(ball_rect), "held ball must be reachable by a GROUND shadow-step wave (no airborne cast required)")
	var hologram_rect: Rect2 = ViperSkillGeometry.shadow_step_hologram_hit_rect(
		Vector2(ViperPracticeMode.HOLD_BALL_POS.x, ground_cast_y),
		paddle_size,
		Vector2(60.0, 50.0)
	)
	_expect(hologram_rect.intersects(ball_rect), "held ball must be reachable by a GROUND shadow-step hologram")


func _verify_frame_controller_wiring() -> void:
	var frame_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_scene_frame_controller.gd")
	_expect(frame_source.find("viper_practice_mode") >= 0, "battle frame controller should update and draw the viper practice mode")


func _keycap_values(elements: Array) -> Array:
	var result: Array = []
	for element_value in elements:
		var element: Dictionary = element_value
		if str(element.get("type", "text")) == "key":
			result.append(str(element.get("value", "")))
	return result


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _snapshot_settings_file(path: String) -> Dictionary:
	var had_original := FileAccess.file_exists(path)
	var original_bytes := PackedByteArray()
	if had_original:
		original_bytes = FileAccess.get_file_as_bytes(path)
	return {
		"had": had_original,
		"bytes": original_bytes,
	}


func _restore_language_settings_snapshot() -> void:
	if _language_settings_snapshot.is_empty():
		return
	_restore_settings_file(
		LanguageSettings.SETTINGS_PATH,
		bool(_language_settings_snapshot.get("had", false)),
		_language_settings_snapshot.get("bytes", PackedByteArray())
	)
	LanguageSettings.reset_cache_for_tests()
	LanguageSettings.apply_saved_language()


func _restore_settings_file(path: String, had_file: bool, file_bytes: PackedByteArray) -> void:
	if had_file:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_buffer(file_bytes)
			file.close()
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
