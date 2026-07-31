extends RefCounted

const GamepadInput := preload("res://scripts/core/gamepad_input.gd")
const MobileTouchControls := preload("res://scripts/core/mobile_touch_controls.gd")

var _last_action_pressed := false
var _last_mouse_left_pressed := false
var _last_secondary_action_pressed := false
var _suppress_primary_pointer_until_release := false
var _same_frame_snapshot: Dictionary = {}
var _same_frame_snapshot_key := -1


func get_snapshot() -> Dictionary:
	# 한 물리 프레임 안에서 여러 소비자가 이 리더를 공유한다(다크 스웜프
	# 시전 리스너가 update_mythic_items에서 플레이어 컨트롤보다 먼저 읽는
	# 계열). 같은 프레임의 두 번째 호출이 just-pressed/just-released 에지를
	# 재계산하면 뒤 소비자가 읽기 전에 에지가 소모되므로, 같은 프레임에는
	# 같은 스냅샷을 돌려준다(smasher_input_reader와 동일 계약).
	var frame_key: int = _get_snapshot_frame_key()
	if frame_key == _same_frame_snapshot_key:
		return _same_frame_snapshot.duplicate(true)
	var left_pressed: bool = Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A) or GamepadInput.is_left_pressed()
	var right_pressed: bool = Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D) or GamepadInput.is_right_pressed()
	var up_pressed: bool = Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W) or GamepadInput.is_up_pressed()
	var down_pressed: bool = Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S) or GamepadInput.is_down_pressed()
	# 플랫폼별 primary-pointer를 '한 번' 계산해 모든 소비 채널(mouse_left·
	# jetpack·action)이 공유한다: 모바일은 emulate_mouse_from_touch가 모든
	# 터치(이동패드 포함)를 합성 LMB로 바꾸므로 raw 폴링을 어느 채널에서든
	# 읽으면 이동 터치가 제트팩/시전으로 오인된다 — 모바일은 화면 ACCEPT
	# 채널만, 데스크톱은 raw LMB만이 포인터 소스다.
	var primary_pointer_pressed: bool
	if _is_mobile_runtime():
		primary_pointer_pressed = MobileTouchControls.is_touch_accept_pressed()
	else:
		primary_pointer_pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if _suppress_primary_pointer_until_release and not primary_pointer_pressed:
		_suppress_primary_pointer_until_release = false
	var effective_primary_pointer_pressed := primary_pointer_pressed and not _suppress_primary_pointer_until_release
	var jetpack_pressed: bool = Input.is_key_pressed(KEY_SPACE) or effective_primary_pointer_pressed or GamepadInput.is_primary_action_pressed()
	var action_pressed: bool = (
		Input.is_action_pressed("ui_accept")
		or Input.is_key_pressed(KEY_SPACE)
		or Input.is_key_pressed(KEY_X)
		or effective_primary_pointer_pressed
		or GamepadInput.is_primary_action_pressed()
	)
	var action_just_pressed: bool = action_pressed and not _last_action_pressed
	var action_just_released: bool = not action_pressed and _last_action_pressed
	_last_action_pressed = action_pressed
	# 좌클릭 채널(다크 스웜프 시전 에지의 소비 지점)도 같은 primary-pointer.
	var mouse_left_pressed: bool = effective_primary_pointer_pressed
	var mouse_left_just_pressed: bool = mouse_left_pressed and not _last_mouse_left_pressed
	_last_mouse_left_pressed = mouse_left_pressed
	# Desktop RMB is a separate skill command channel. Mobile/gamepad alternatives are
	# intentionally unresolved until a dedicated UX binding is approved.
	var secondary_action_pressed := not _is_mobile_runtime() and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var secondary_action_just_pressed := secondary_action_pressed and not _last_secondary_action_pressed
	_last_secondary_action_pressed = secondary_action_pressed
	var direction := 0.0
	if left_pressed:
		direction -= 1.0
	if right_pressed:
		direction += 1.0

	_same_frame_snapshot = {
		"left_pressed": left_pressed,
		"right_pressed": right_pressed,
		"up_pressed": up_pressed,
		"down_pressed": down_pressed,
		"action_pressed": action_pressed,
		"action_just_pressed": action_just_pressed,
		"action_just_released": action_just_released,
		"mouse_left_pressed": mouse_left_pressed,
		"mouse_left_just_pressed": mouse_left_just_pressed,
		"jetpack_pressed": jetpack_pressed,
		"secondary_action_pressed": secondary_action_pressed,
		"secondary_action_just_pressed": secondary_action_just_pressed,
		"direction": direction,
		"power_smash_direction": _get_exclusive_horizontal_direction(left_pressed, right_pressed),
	}
	_same_frame_snapshot_key = frame_key
	return _same_frame_snapshot.duplicate(true)


func suppress_primary_pointer_until_release() -> void:
	_suppress_primary_pointer_until_release = true
	_last_mouse_left_pressed = false
	_same_frame_snapshot_key = -1


func _get_snapshot_frame_key() -> int:
	return int(Engine.get_physics_frames())


func _is_mobile_runtime() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")


func _get_exclusive_horizontal_direction(left_pressed: bool, right_pressed: bool) -> int:
	if left_pressed and not right_pressed:
		return -1
	if right_pressed and not left_pressed:
		return 1
	return 0
