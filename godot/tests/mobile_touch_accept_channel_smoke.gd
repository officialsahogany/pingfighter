extends SceneTree

# 모바일 touch-accept 채널 씰: 화면 ACCEPT 버튼 → 정적 채널 → 바이퍼 입력
# 리더의 좌클릭 계약. 오딘 다크 스웜프 스모크의 입력 레그와 같은 계약을
# 오딘 런타임 의존 없이 독립 봉인한다(오딘 스모크 전체는 다크 스웜프 본체
# 복원 슬라이스에서 GREEN이 된다). v2: 런타임 종별 소스 분리 매트릭스,
# disabled 재삽입/orphan drag phantom 차단, 전투 teardown 해제(실 인스턴스
# +getter-null fallback), 실 physics frame N/N+1 캐시 계약, 상위 컨트롤러
# (battle_mobile_touch_controller) 관통까지 봉인.

const ViperInputReader := preload("res://scripts/characters/viper_input_reader.gd")
const MobileTouchControls := preload("res://scripts/core/mobile_touch_controls.gd")
const BattleMobileTouchController := preload("res://scripts/core/battle_mobile_touch_controller.gd")
const BattleSceneTeardownLifecycle := preload("res://scripts/core/battle_scene_teardown_lifecycle.gd")

var _failures: Array[String] = []
var _teardown_mobile_touch_controls: Object = null
var _controller_modules: Dictionary = {}
var _controller_module_identity_log: Array = []


# 런타임 종별 매트릭스용: OS feature에 기대지 않고 종별을 고정한 리더.
class MobileViperReader:
	extends ViperInputReader

	func _is_mobile_runtime() -> bool:
		return true


class DesktopViperReader:
	extends ViperInputReader

	func _is_mobile_runtime() -> bool:
		return false


# 상위 컨트롤러 관통용: headless(데스크톱 feature)에서 모바일 게이트를 연다.
class MobileRuntimeTouchController:
	extends BattleMobileTouchController

	func _is_mobile_runtime() -> bool:
		return true


class FakeControllerOwner:
	extends RefCounted

	var redraw_count := 0

	func queue_redraw() -> void:
		redraw_count += 1

	func get_viewport_rect() -> Rect2:
		return Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))


class FakeModalGate:
	extends RefCounted

	var block := false

	func should_block_mobile_controls(_module_getter: Callable) -> bool:
		return block


func _init() -> void:
	_run()


func _run() -> void:
	_verify_snapshot_contract_keys()
	_verify_action_edge_semantics()
	await _verify_real_physics_frame_cache_contract()
	_verify_mouse_left_source_matrix()
	_verify_disabled_and_orphan_phantom_rejection()
	_verify_battle_teardown_releases_channel()
	_verify_controller_gate_and_fanout()
	if _failures.is_empty():
		print("mobile_touch_accept_channel_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_snapshot_contract_keys() -> void:
	var reader := ViperInputReader.new()
	var idle_snapshot: Dictionary = reader.get_snapshot()
	_expect(idle_snapshot.has("action_just_pressed"), "viper snapshot must contain action_just_pressed")
	_expect(idle_snapshot.has("action_just_released"), "viper snapshot must contain action_just_released")
	_expect(idle_snapshot.has("mouse_left_pressed"), "viper snapshot must contain mouse_left_pressed")
	_expect(idle_snapshot.has("mouse_left_just_pressed"), "viper snapshot must contain mouse_left_just_pressed (dark swamp cast edge)")
	_expect(idle_snapshot.has("jetpack_pressed"), "viper snapshot must keep jetpack_pressed")
	_expect(idle_snapshot.has("action_pressed"), "viper snapshot must keep action_pressed")
	_expect(not bool(idle_snapshot.get("action_just_pressed", true)), "idle viper snapshot must not report a pressed edge")


func _verify_action_edge_semantics() -> void:
	var reader := ViperInputReader.new()
	reader.get_snapshot()
	Input.action_press("ui_accept")
	reader._same_frame_snapshot_key = -1
	var pressed_snapshot: Dictionary = reader.get_snapshot()
	_expect(bool(pressed_snapshot.get("action_pressed", false)), "ui_accept press must read as action_pressed")
	_expect(bool(pressed_snapshot.get("action_just_pressed", false)), "first pressed frame must publish the edge")
	reader._same_frame_snapshot_key = -1
	var held_snapshot: Dictionary = reader.get_snapshot()
	_expect(not bool(held_snapshot.get("action_just_pressed", true)), "held frame must not re-publish the pressed edge")
	Input.action_release("ui_accept")
	reader._same_frame_snapshot_key = -1
	var released_snapshot: Dictionary = reader.get_snapshot()
	_expect(bool(released_snapshot.get("action_just_released", false)), "release frame must publish just_released")
	_expect(not bool(released_snapshot.get("action_just_pressed", true)), "release frame must not publish a pressed edge")


func _verify_real_physics_frame_cache_contract() -> void:
	# 실 physics frame 전환으로 N/N+1 계약을 봉인한다 — private key를 손으로
	# 리셋하는 방식은 production frame-key 함수가 상수로 망가져도 통과한다.
	var reader := ViperInputReader.new()
	reader.get_snapshot()
	Input.action_press("ui_accept")
	await physics_frame
	var first_snapshot: Dictionary = reader.get_snapshot()
	var second_snapshot: Dictionary = reader.get_snapshot()
	_expect(bool(first_snapshot.get("action_just_pressed", false)), "frame N: the first consumer must see the pressed edge")
	_expect(bool(second_snapshot.get("action_just_pressed", false)), "frame N: the second same-frame consumer must see the SAME edge (no same-frame consumption)")
	await physics_frame
	var next_frame_snapshot: Dictionary = reader.get_snapshot()
	_expect(bool(next_frame_snapshot.get("action_pressed", false)), "frame N+1: the action must still read held")
	_expect(not bool(next_frame_snapshot.get("action_just_pressed", true)), "frame N+1: a REAL next physics frame must recompute and drop the edge (a constant frame key would freeze frame N forever)")
	Input.action_release("ui_accept")
	await physics_frame
	reader.get_snapshot()


func _verify_mouse_left_source_matrix() -> void:
	# 좌클릭 소스 매트릭스: 모바일=accept 채널만(합성 LMB 오인 차단),
	# 데스크톱=raw LMB만(채널 무시).
	MobileTouchControls._touch_accept_pressed_static = true
	var mobile_reader := MobileViperReader.new()
	var mobile_snapshot: Dictionary = mobile_reader.get_snapshot()
	_expect(bool(mobile_snapshot.get("mouse_left_pressed", false)), "mobile runtime: touch-accept must read as mouse_left_pressed")
	_expect(bool(mobile_snapshot.get("mouse_left_just_pressed", false)), "mobile runtime: touch-accept press must publish the cast edge")
	_expect(bool(mobile_snapshot.get("jetpack_pressed", false)), "mobile runtime: the ACCEPT pointer must also drive the jetpack channel (single primary pointer)")
	_expect(bool(mobile_snapshot.get("action_pressed", false)), "mobile runtime: the ACCEPT pointer must also drive the action channel (single primary pointer)")
	mobile_reader._same_frame_snapshot_key = -1
	_expect(not bool(mobile_reader.get_snapshot().get("mouse_left_just_pressed", true)), "mobile runtime: a held touch-accept must not re-publish the cast edge")

	var desktop_reader := DesktopViperReader.new()
	var desktop_snapshot: Dictionary = desktop_reader.get_snapshot()
	_expect(not bool(desktop_snapshot.get("mouse_left_pressed", true)), "desktop runtime: the touch-accept channel must be ignored (raw LMB is the only source)")
	MobileTouchControls._touch_accept_pressed_static = false

	# 모바일에서 raw 합성 LMB가 오인되지 않는 것: raw LMB를 실제로 올리고
	# 채널은 내린 상태에서 mouse_left가 false여야 한다.
	var raw_press := InputEventMouseButton.new()
	raw_press.button_index = MOUSE_BUTTON_LEFT
	raw_press.pressed = true
	Input.parse_input_event(raw_press)
	Input.flush_buffered_events()
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var mobile_raw_reader := MobileViperReader.new()
		var mobile_raw_snapshot: Dictionary = mobile_raw_reader.get_snapshot()
		_expect(not bool(mobile_raw_snapshot.get("mouse_left_pressed", true)), "mobile runtime: a raw synthetic LMB (any-touch emulation) must NOT read as the cast click")
		# primary-pointer 통일: 합성 LMB는 제트팩·액션 채널로도 새면 안 된다
		# (이동패드 터치가 비행/시전을 켜는 회귀 클래스).
		_expect(not bool(mobile_raw_snapshot.get("jetpack_pressed", true)), "mobile runtime: a raw synthetic LMB must NOT fire the jetpack channel")
		_expect(not bool(mobile_raw_snapshot.get("action_pressed", true)), "mobile runtime: a raw synthetic LMB must NOT fire the action channel")
		var desktop_raw_reader := DesktopViperReader.new()
		var desktop_raw_snapshot: Dictionary = desktop_raw_reader.get_snapshot()
		_expect(bool(desktop_raw_snapshot.get("mouse_left_pressed", false)), "desktop runtime: the raw LMB must read as the cast click")
		_expect(bool(desktop_raw_snapshot.get("jetpack_pressed", false)), "desktop runtime: the raw LMB must keep firing the jetpack channel")
		_expect(bool(desktop_raw_snapshot.get("action_pressed", false)), "desktop runtime: the raw LMB must keep firing the action channel")
		var raw_release := InputEventMouseButton.new()
		raw_release.button_index = MOUSE_BUTTON_LEFT
		raw_release.pressed = false
		Input.parse_input_event(raw_release)
		Input.flush_buffered_events()
	else:
		_expect(false, "raw LMB injection must be observable in this harness (matrix leg would be vacuous)")


func _verify_disabled_and_orphan_phantom_rejection() -> void:
	var touch_controls := MobileTouchControls.new()
	var view_size := Vector2(1280.0, 720.0)
	var layout: Dictionary = touch_controls._build_layout(view_size, {})
	var accept_center: Vector2 = layout.get("ui_accept", Vector2.ZERO)
	_expect(accept_center != Vector2.ZERO, "mobile layout must expose the ACCEPT button center")

	# 정상 press/release가 채널을 올리고 내린다(실 이벤트 경로).
	var accept_press := InputEventScreenTouch.new()
	accept_press.index = 0
	accept_press.pressed = true
	accept_press.position = accept_center
	touch_controls.handle_input(accept_press, view_size, true, {})
	_expect(MobileTouchControls.is_touch_accept_pressed(), "a real ACCEPT-button touch must set the touch-accept channel")
	var accept_release := InputEventScreenTouch.new()
	accept_release.index = 0
	accept_release.pressed = false
	accept_release.position = accept_center
	touch_controls.handle_input(accept_release, view_size, true, {})
	_expect(not MobileTouchControls.is_touch_accept_pressed(), "the real ACCEPT release must clear the touch-accept channel")

	# disabled(모달) 윈도우의 press는 손가락 기록조차 남기면 안 된다 —
	# active_touches에 남으면 재활성화 프레임에 phantom ACCEPT로 부활한다.
	var disabled_press := InputEventScreenTouch.new()
	disabled_press.index = 1
	disabled_press.pressed = true
	disabled_press.position = accept_center
	touch_controls.handle_input(disabled_press, view_size, false, {})
	_expect(touch_controls.active_touches.is_empty(), "presses during a disabled window must be discarded (no phantom finger)")
	_expect(not MobileTouchControls.is_touch_accept_pressed(), "a disabled-window press must not raise the channel")

	# 재활성화 후 같은 index의 drag가 흘러들어와도(orphan) 등록 금지.
	var orphan_drag := InputEventScreenDrag.new()
	orphan_drag.index = 1
	orphan_drag.position = accept_center
	touch_controls.handle_input(orphan_drag, view_size, true, {})
	_expect(touch_controls.active_touches.is_empty(), "orphan drags must not register a phantom finger")
	_expect(not MobileTouchControls.is_touch_accept_pressed(), "an orphan drag over ACCEPT must not fire the touch-accept channel")

	# disabled 윈도우의 drag도 잔존 손가락을 내린다.
	touch_controls.handle_input(accept_press, view_size, true, {})
	_expect(MobileTouchControls.is_touch_accept_pressed(), "fixture: re-pressed ACCEPT should be live")
	var disabled_drag := InputEventScreenDrag.new()
	disabled_drag.index = 0
	disabled_drag.position = accept_center
	touch_controls.handle_input(disabled_drag, view_size, false, {})
	_expect(touch_controls.active_touches.is_empty(), "a disabled-window drag must drop the held finger")
	_expect(not MobileTouchControls.is_touch_accept_pressed(), "a disabled-window drag must lower the channel")
	touch_controls.release_all()


func _verify_battle_teardown_releases_channel() -> void:
	# 손가락을 누른 채 전투를 떠나는 경로: teardown이 수동 액션과 정적
	# 채널을 함께 내려야 다음 씬으로 눌림이 누출되지 않는다.
	var touch_controls := MobileTouchControls.new()
	var view_size := Vector2(1280.0, 720.0)
	var layout: Dictionary = touch_controls._build_layout(view_size, {})
	var accept_center: Vector2 = layout.get("ui_accept", Vector2.ZERO)
	var held_press := InputEventScreenTouch.new()
	held_press.index = 2
	held_press.pressed = true
	held_press.position = accept_center
	touch_controls.handle_input(held_press, view_size, true, {})
	_expect(MobileTouchControls.is_touch_accept_pressed(), "teardown fixture: the held ACCEPT press must be live before teardown")
	_expect(Input.is_action_pressed("ui_accept"), "teardown fixture: the manual ui_accept action must be live before teardown")

	_teardown_mobile_touch_controls = touch_controls
	BattleSceneTeardownLifecycle.new().exit_tree(null, null, Callable(self, "_get_teardown_module"), {})
	_expect(not MobileTouchControls.is_touch_accept_pressed(), "battle teardown must release the held mobile ACCEPT channel")
	_expect(not Input.is_action_pressed("ui_accept"), "battle teardown must release the manually pressed ui_accept action")

	# getter-null fallback: 모듈이 이미 사라진 teardown에서도 정적 채널과
	# 수동 액션은 강제로 내려가야 한다.
	MobileTouchControls._touch_accept_pressed_static = true
	Input.action_press("ui_accept")
	BattleSceneTeardownLifecycle.new().exit_tree(null, null, Callable(), {})
	_expect(not MobileTouchControls.is_touch_accept_pressed(), "teardown with a null module getter must still clear the static channel")
	_expect(not Input.is_action_pressed("ui_accept"), "teardown with a null module getter must still release the manual action")
	_teardown_mobile_touch_controls = null


func _get_teardown_module(key: String) -> Object:
	if key == "mobile_touch_controls":
		return _teardown_mobile_touch_controls
	return null


func _verify_controller_gate_and_fanout() -> void:
	# 상위 production 컨트롤러 관통: 모바일 런타임 게이트·모달 판정·module
	# getter·handled fanout(queue_redraw)이 실제 ACCEPT press를 모듈까지
	# 흘리는지 봉인한다.
	var touch_controls := MobileTouchControls.new()
	var modal_gate := FakeModalGate.new()
	_controller_modules = {
		"mobile_touch_controls": touch_controls,
		"battle_scene_modal_gate_controller": modal_gate,
	}
	var owner := FakeControllerOwner.new()
	var controller := MobileRuntimeTouchController.new()
	# 컨트롤러는 자체 layout_context(view_layout 부재 fallback)를 모듈에
	# 넘기므로, ACCEPT 좌표도 같은 컨텍스트로 계산해야 실경로와 일치한다.
	var controller_layout_context: Dictionary = controller._build_layout_context(owner, Callable(self, "_get_controller_module"))
	var layout: Dictionary = touch_controls._build_layout(owner.get_viewport_rect().size, controller_layout_context)
	var accept_center: Vector2 = layout.get("ui_accept", Vector2.ZERO)
	var accept_press := InputEventScreenTouch.new()
	accept_press.index = 0
	accept_press.pressed = true
	accept_press.position = accept_center

	# (a) scene_ready=false 게이트: 모듈에 enabled=false로 전달돼 채널이
	# 켜지지 않는다.
	controller.handle_input(accept_press, owner, Callable(self, "_get_controller_module"), false)
	_expect(not MobileTouchControls.is_touch_accept_pressed(), "the controller must not enable controls before the scene is ready")

	# (b) 모달 차단: modal gate가 막으면 press가 phantom 없이 버려진다.
	modal_gate.block = true
	controller.handle_input(accept_press, owner, Callable(self, "_get_controller_module"), true)
	_expect(not MobileTouchControls.is_touch_accept_pressed(), "the controller must discard presses while the modal gate blocks mobile controls")
	_expect(touch_controls.active_touches.is_empty(), "a modal-blocked press must not leave a phantom finger in the module")

	# (c) 정상 경로: 게이트 통과 → 모듈 채널 set + handled fanout(redraw).
	modal_gate.block = false
	var redraw_before: int = owner.redraw_count
	var handled: bool = bool(controller.handle_input(accept_press, owner, Callable(self, "_get_controller_module"), true))
	_expect(handled, "the production controller must report the ACCEPT press as handled")
	_expect(MobileTouchControls.is_touch_accept_pressed(), "the production controller path must raise the touch-accept channel")
	_expect(owner.redraw_count > redraw_before, "the handled fanout must request an owner redraw")

	# (c2) 같은 getter/모듈 소유로 press→release 연속성: release가 다른
	# 인스턴스로 가면 ui_accept가 고착된다 — getter 호출·identity 로그로
	# 동일 인스턴스 소유를 봉인하고, release 후 완전 해제를 확인한다.
	_expect(_controller_module_identity_log.size() >= 2, "the controller must fetch the touch module for every event (press and prior calls)")
	var accept_release := InputEventScreenTouch.new()
	accept_release.index = 0
	accept_release.pressed = false
	accept_release.position = accept_center
	controller.handle_input(accept_release, owner, Callable(self, "_get_controller_module"), true)
	_expect(not MobileTouchControls.is_touch_accept_pressed(), "the controller release must lower the channel through the SAME module instance")
	_expect(not Input.is_action_pressed("ui_accept"), "the controller release must free the manual ui_accept action (a per-event fresh instance would leave it stuck)")
	var identity_baseline: int = _controller_module_identity_log[0]
	for logged_identity in _controller_module_identity_log:
		_expect(logged_identity == identity_baseline, "every getter fetch must return the same touch module instance (ownership continuity)")

	# (c3) held ACCEPT 중 모달 활성화: 이벤트 없이 sync_controls_enabled만
	# 돌아도 손가락·정적 채널·수동 액션이 전부 내려가야 한다.
	controller.handle_input(accept_press, owner, Callable(self, "_get_controller_module"), true)
	_expect(MobileTouchControls.is_touch_accept_pressed(), "modal fixture: the held ACCEPT must be live before the modal opens")
	modal_gate.block = true
	controller.sync_controls_enabled(owner, Callable(self, "_get_controller_module"), true)
	_expect(touch_controls.active_touches.is_empty(), "a modal opening mid-hold must drop the held finger without any new event")
	_expect(not MobileTouchControls.is_touch_accept_pressed(), "a modal opening mid-hold must lower the static channel")
	_expect(not Input.is_action_pressed("ui_accept"), "a modal opening mid-hold must release the manual ui_accept action")
	modal_gate.block = false

	# (d) 데스크톱 런타임(headless 기본): 실 컨트롤러는 top-level에서 즉시
	# 무시한다 — handled=false만으로는 하위 disabled 경로 false와 구분이
	# 안 되므로 getter 호출 0회(모듈 접근 자체가 없음)로 봉인한다.
	var desktop_controller := BattleMobileTouchController.new()
	_controller_module_identity_log.clear()
	var desktop_handled: bool = bool(desktop_controller.handle_input(accept_press, owner, Callable(self, "_get_controller_module"), true))
	_expect(not desktop_handled, "a desktop runtime must bypass the mobile controller entirely")
	_expect(_controller_module_identity_log.is_empty(), "a desktop runtime must not even fetch the touch module (top-level early return)")
	touch_controls.release_all()
	_controller_modules = {}
	_controller_module_identity_log.clear()


func _get_controller_module(key: String) -> Object:
	var value: Variant = _controller_modules.get(key, null)
	if typeof(value) == TYPE_OBJECT:
		if key == "mobile_touch_controls":
			_controller_module_identity_log.append((value as Object).get_instance_id())
		return value as Object
	if key == "mobile_touch_controls":
		_controller_module_identity_log.append(0)
	return null


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
