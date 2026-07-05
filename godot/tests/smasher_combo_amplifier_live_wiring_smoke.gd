extends SceneTree

# Smasher 콤보증폭칩 — LIVE WIRING 회귀.
# 다른 두 스모크는 resolver/handler에 amp를 직접 주입한다. 이 스모크는 runtime_perk_state가
# 실제 DEPS에서 읽혀 SmasherDriveActivationController / PaddleBouncePostHitHandler를 거쳐
# 자연 발현되는지 검증한다(= 라우터 deps allowlist 누락 같은 조용한 단선을 포착).

const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const SmasherDriveActivationController := preload("res://scripts/characters/smasher_drive_activation_controller.gd")
const SmasherDriveBounceState := preload("res://scripts/characters/smasher_drive_bounce_state.gd")
const PaddleBounceDriveActivationRouter := preload("res://scripts/ball/paddle_bounce_drive_activation_router.gd")
const PaddleBouncePostHitHandler := preload("res://scripts/ball/paddle_bounce_post_hit_handler.gd")
const SmasherPowerSmashState := preload("res://scripts/characters/smasher_power_smash_state.gd")
const BallPhysics := preload("res://scripts/ball/ball_physics.gd")

var _failures: Array[String] = []


class _StubRound:
	func is_waiting_for_serve() -> bool:
		return false


class _StubDriveInput:
	var dir: int
	func _init(d: int) -> void:
		dir = d
	func consume_direction(_frame: int) -> int:
		return dir
	func is_frame_cooldown_blocked() -> bool:
		return false
	func trigger_frame_cooldowns(_perfect: float, _global: float) -> void:
		pass


class _StubCombo:
	var combo: int
	func _init(c: int) -> void:
		combo = c
	func get_effective_combo() -> int:
		return combo
	func reset_combo(_reason: String = "") -> void:
		combo = 0
	func get_combo() -> int:
		return combo


func _init() -> void:
	_verify_router_forwards_perk_state()
	_verify_drive_chip_flows_through_controller()
	_verify_power_smash_chip_flows_through_post_hit_handler()

	if _failures.is_empty():
		print("smasher_combo_amplifier_live_wiring_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _perk_state(level: int) -> Object:
	var rps: Object = RuntimePerkState.new()
	if level > 0:
		rps.runtime_skill_levels["combo_amplifier_chip"] = level
	return rps


# 라우터 deps allowlist가 runtime_perk_state를 controller로 전달하지 않으면 칩 레벨이
# 항상 null→0이 되어 효과가 조용히 죽는다. 그 정확한 단선을 포착.
func _verify_router_forwards_perk_state() -> void:
	var router: Object = PaddleBounceDriveActivationRouter.new()
	var built: Dictionary = router._build_deps({"runtime_perk_state": "SENTINEL"})
	_expect(
		str(built.get("runtime_perk_state", "")) == "SENTINEL",
		"drive router _build_deps must forward runtime_perk_state to the controller"
	)


func _drive_via_controller(chip_level: int) -> Dictionary:
	var controller: Object = SmasherDriveActivationController.new()
	var deps: Dictionary = {
		"round_state": _StubRound.new(),
		"drive_input_state": _StubDriveInput.new(-1),
		"combo_state": _StubCombo.new(5),
		"drive_bounce_state": SmasherDriveBounceState.new(),
		"ball_physics": null,
		"skill_state": null,
		"runtime_perk_state": _perk_state(chip_level),
	}
	var context: Dictionary = {
		"ball_active": true,
		"special_gauge": 100.0,
		"gauge_cost": 0.0,
		"combo_min_count": 2,
		"current_msec": 0,
		"text_duration_frames": 0.0,
	}
	seed(987654321)
	return controller.try_activate(8.0, 0.0, 0.0, 1.0, 0, context, deps)


func _verify_drive_chip_flows_through_controller() -> void:
	var lv0: Dictionary = _drive_via_controller(0)
	var lv5: Dictionary = _drive_via_controller(5)
	_expect(bool(lv0.get("activated", false)) and bool(lv5.get("activated", false)),
		"drive should activate via controller in both cases")
	_expect(
		float(lv5.get("ball_spin_strength", 0.0)) > float(lv0.get("ball_spin_strength", 0.0)) + 0.001,
		"chip read from REAL deps must raise drive spin through the controller path"
	)


func _power_smash_via_post_hit(chip_level: int) -> float:
	var power_state: Object = SmasherPowerSmashState.new()
	power_state.begin_activation(0, 0.0, 3, 0.0, false, 0, 0.0)
	var physics: Object = BallPhysics.new()
	physics.configure_context(1, "champion")
	var handler: Object = PaddleBouncePostHitHandler.new()
	var deps: Dictionary = {
		"power_state": power_state,
		"ball_physics": physics,
		"runtime_perk_state": _perk_state(chip_level),
	}
	var context: Dictionary = {
		"ai_mode": "champion",
		"player_pos": Vector2(302.5, 700.0),
		"paddle_width": 155.0,
		"base_ball_speed": BallPhysics.BALL_BASE_SPEED,
		"combo_min_count": 2,
		"ball_size": 28.6,
	}
	var result: Dictionary = handler.apply(
		true, Vector2(380.0, 700.0), Vector2(0.0, -16.0), 0.0, 155.0,
		true, false, false, 0.0, 0.0, false, false, 0.0, context, deps
	)
	var vel: Vector2 = result.get("ball_vel", Vector2.ZERO)
	return vel.length()


func _verify_power_smash_chip_flows_through_post_hit_handler() -> void:
	var lv0: float = _power_smash_via_post_hit(0)
	var lv5: float = _power_smash_via_post_hit(5)
	_expect(lv0 > 0.0, "post-hit power smash should produce launch speed")
	_expect(
		lv5 > lv0 * 1.05,
		"chip read from REAL deps must raise power-smash launch through PaddleBouncePostHitHandler"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
