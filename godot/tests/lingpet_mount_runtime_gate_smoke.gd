extends SceneTree

# 온이마루 탑승 회귀 씰 (parked != disabled trap family).
#
# 탑승은 위치 오버라이드만 걸고 `_companion_motion_state.update()`를 건너뛴다.
# 그래서 탑승 중에는 아래 3가지가 명시적으로 죽어야 한다:
#   1. 선제타격 무장  -- 몸통 피격이 억제된 상태에서 무장하면 허공 스윙이 된다
#                       (트랩 계약: "one switch gates BOTH")
#   2. 방어 인터셉트   -- 갱신 경로가 끊기므로 탑승 직전 래치가 하차까지 남는다
#   3. 클릭 교감       -- 리액션 시트가 carry 합성을 대체해 라이더만 공중에 뜬다
#
# 각 레그는 비탑승 대조군을 함께 단언한다. 대조군이 없으면 "탑승/비탑승 모두
# 미발동"인 변별력 0 씰이 되어 게이트를 제거해도 GREEN이 유지된다.

const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")

const STATE_COMPANION := "companion"
const PLAYER_X := 300.0
const PADDLE_WIDTH := 155.0
const LANE_Y := 655.0

var _failures: Array[String] = []


class FakeInputProbe extends RefCounted:
	var rmb := false
	var down := false

	func is_rmb_pressed() -> bool:
		return rmb

	func is_down_pressed() -> bool:
		return down


class FakeOwner extends RefCounted:
	var player_pos := Vector2(PLAYER_X, 700.0)
	var player_paddle_width := PADDLE_WIDTH
	var player_paddle_height := 50.0
	var ball_active := false
	var ball_pos := Vector2(300.0, 300.0)
	var ball_vel := Vector2.ZERO


class NullRegistry extends RefCounted:
	func get_cached_instance(_instance_name: String) -> Object:
		return null

	func get_instance(_instance_name: String) -> Object:
		return null


# Arity MUST match the real 13-argument call site: a duck-typed `has_method`
# style call cannot be arity-checked by the parser, so a short fake would only
# crash on the frame the branch actually runs.
class SpyAnticipator extends RefCounted:
	var arm_calls := 0

	func maybe_arm_from_sources(
		_owner = null,
		_companion_pos = null,
		_current_profile = null,
		_body_hit_state = null,
		_animator = null,
		_active_skill_ids = null,
		_slot_resolver = null,
		_visual_resolver = null,
		_skill_runtime_surface = null,
		_skill_runtime_host = null,
		_ball_radius_fallback = null,
		_hit_width_fallback = null,
		_hit_height_fallback = null
	) -> void:
		arm_calls += 1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_mount_blocks_strike_arm()
	_verify_mount_retires_defense_intercept()
	_verify_mount_transition_retires_live_click_reaction()
	_verify_mounted_state_refuses_new_click()

	if _failures.is_empty():
		print("lingpet_mount_runtime_gate_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _player_center() -> float:
	return PLAYER_X + PADDLE_WIDTH * 0.5


func _make_summoned_runtime() -> Object:
	var runtime: Object = LingpetEggRuntime.new()
	runtime._state = STATE_COMPANION
	runtime._guardian_stowed = false
	runtime._companion_pos = Vector2(_player_center(), LANE_Y)
	runtime._companion_motion_state.pos = runtime._companion_pos
	runtime._companion_motion_state.motion_visible = true
	runtime._mount_state.set_pet_id("onimaru")
	# S2 안장 게이트: egg 쪽 permit 계산이 runtime._pet_id로 장착 슬롯을 조회하므로
	# mount state에만 펫을 넣으면 permit이 빈 펫 id로 계산돼 강제 하차된다 —
	# 픽스처도 실제 런타임 펫 id를 채운다 (기본값 우회 금지, 2026-08-05 리뷰 P2).
	runtime._pet_id = "onimaru"
	return runtime


func _mount(runtime: Object, owner: Object) -> bool:
	var probe := FakeInputProbe.new()
	runtime._mount_state.set_input_probe(probe)
	probe.rmb = true
	runtime._mount_state.advance(
		owner,
		runtime._companion_pos,
		true,
		false,
		0.0,
		runtime._mount_state.is_mount_permitted("onimaru", []),
		false
	)
	return bool(runtime._mount_state.is_mounted())


# 런타임 경로를 통해 탑승한다. 직접 `_mount_state.advance()`를 부르면 전이 시
# 은퇴/정리 코드를 전부 건너뛰므로, 전이 계약을 검사하는 레그는 이 헬퍼를 써야 한다.
func _mount_via_runtime(runtime: Object, owner: Object, registry: Object) -> bool:
	var probe := FakeInputProbe.new()
	runtime._mount_state.set_input_probe(probe)
	probe.rmb = true
	runtime._update_companion_motion(0.016, owner, registry)
	return bool(runtime._mount_state.is_mounted())


func _verify_mount_blocks_strike_arm() -> void:
	var owner := FakeOwner.new()
	var registry := NullRegistry.new()

	# 대조군: 비탑승이면 무장 경로가 실제로 호출된다.
	var loose: Object = _make_summoned_runtime()
	var loose_spy := SpyAnticipator.new()
	loose._companion_strike_anticipator = loose_spy
	loose.update(0.016, owner, registry)
	_expect(loose_spy.arm_calls > 0, "control: an unmounted summoned companion must reach the strike-arm path")

	var ridden: Object = _make_summoned_runtime()
	var ridden_spy := SpyAnticipator.new()
	ridden._companion_strike_anticipator = ridden_spy
	_expect(_mount(ridden, owner), "fixture sanity: onimaru should mount at the player center")
	ridden.update(0.016, owner, registry)
	_expect(ridden_spy.arm_calls == 0, "탑승 중에는 선제타격을 무장하지 않아야 한다 (허공 스트라이크)")


func _verify_mount_retires_defense_intercept() -> void:
	var owner := FakeOwner.new()
	var registry := NullRegistry.new()
	var runtime: Object = _make_summoned_runtime()
	_expect(_mount(runtime, owner), "fixture sanity: onimaru should mount at the player center")

	# 탑승 프레임에 살아 있던 인터셉트는 하차까지 남아서는 안 된다.
	runtime._companion_motion_state.defense_intercept_active = true
	runtime._companion_motion_state.defense_intercept_target_x = 120.0
	runtime._update_companion_motion(0.016, owner, registry)
	_expect(
		not bool(runtime._companion_motion_state.defense_intercept_active),
		"탑승 진입은 방어 인터셉트를 명시적으로 해제해야 한다 (갱신 경로가 끊기므로 자연 만료가 없다)"
	)


func _verify_mount_transition_retires_live_click_reaction() -> void:
	# 경로 1: 교감이 이미 재생 중인 상태에서 탑승 전이가 일어나면 반응이 끝나야 한다.
	# 탑승 게이트는 NEW 클릭만 막으므로 이 전이를 따로 단언해야 구멍이 드러난다.
	# 마운트는 반드시 런타임 경로(`_update_companion_motion`)를 통해 걸어야 한다 --
	# `_mount_state.advance()`를 직접 부르면 은퇴 코드를 건너뛰어 공허 GREEN이 된다.
	var owner := FakeOwner.new()
	var registry := NullRegistry.new()

	var ridden: Object = _make_summoned_runtime()
	ridden._companion_click_reaction_state.active = true
	ridden._companion_click_reaction_state.timer = 0.2
	_expect(_mount_via_runtime(ridden, owner, registry), "fixture sanity: runtime transition should mount onimaru")
	_expect(
		not bool(ridden.is_companion_click_reaction_active()),
		"탑승 전이는 진행 중인 클릭 교감을 은퇴시켜야 한다 (안 그러면 탈것이 반응 시트로 교체돼 라이더만 공중에 남는다)"
	)

	# 대조군: 탑승하지 않으면 같은 프레임 구동이 반응을 죽이지 않는다 (은퇴가
	# 탑승 전이에만 묶여 있음을 보장 -- 없으면 "그냥 항상 죽는다"와 구별 불가).
	var loose: Object = _make_summoned_runtime()
	loose._companion_click_reaction_state.active = true
	loose._companion_click_reaction_state.timer = 0.2
	loose._update_companion_motion(0.016, owner, registry)
	_expect(
		bool(loose.is_companion_click_reaction_active()),
		"control: an unmounted companion must keep its in-flight click reaction"
	)


func _verify_mounted_state_refuses_new_click() -> void:
	# 경로 2: 이미 탑승한 상태에서 들어온 신규 교감 클릭은 거부되고 계속 비활성.
	var owner := FakeOwner.new()
	var registry := NullRegistry.new()
	var click_at := Vector2(_player_center(), LANE_Y)

	# 대조군: 비탑승이면 같은 클릭이 소비된다. 이미 재생 중 분기를 쓰면 텍스처
	# 로딩 없이도 true 경로에 도달한다.
	var loose: Object = _make_summoned_runtime()
	loose._companion_click_reaction_state.active = true
	_expect(
		bool(loose.try_begin_companion_click_reaction(click_at, registry)),
		"control: an unmounted companion must consume a click on its body"
	)

	var ridden: Object = _make_summoned_runtime()
	_expect(_mount_via_runtime(ridden, owner, registry), "fixture sanity: runtime transition should mount onimaru")
	_expect(
		not bool(ridden.try_begin_companion_click_reaction(click_at, registry)),
		"탑승 중에는 새 클릭 교감이 시작되지 않아야 한다"
	)
	_expect(
		not bool(ridden.is_companion_click_reaction_active()),
		"거부된 클릭이 반응을 켜서도 안 된다"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
