extends SceneTree

const ActiveItemRuntime := preload("res://scripts/items/active_item_runtime.gd")
const ActiveItemRuntimeContextFacade := preload("res://scripts/items/active_item_runtime_context_facade.gd")
const ActiveItemThrowController := preload("res://scripts/items/active_item_throw_controller.gd")
const BallMotionEventProcessor := preload("res://scripts/ball/ball_motion_event_processor.gd")
const BallMotionStepper := preload("res://scripts/ball/ball_motion_stepper.gd")
const BallUpdateOwnerSnapshot := preload("res://scripts/ball/ball_update_owner_snapshot.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var values: Dictionary = {
		"ball_pos": Vector2(380.0, 360.0),
		"ball_vel": Vector2(0.0, -6.0),
		"ball_active": true,
		"current_stage": 7,
		"lingpet_star_coil_freeze_boss_skill_cd": false,
	}

	func _get(property: StringName) -> Variant:
		return values.get(str(property), null)


class Stage7ContextProbe:
	extends RefCounted

	var captured_context: Dictionary = {}

	func is_boss_ball_intangible() -> bool:
		return false

	func resolve_wind_aura_collision(
		_ball_pos: Vector2,
		_ball_vel: Vector2,
		context: Dictionary,
		_deps: Dictionary = {}
	) -> Dictionary:
		captured_context = {
			"lingpet_star_coil_freeze_boss_skill_cd": bool(context.get(
				"lingpet_star_coil_freeze_boss_skill_cd",
				false
			)),
			"active_item_tear_gas_cooldown_pause_active": bool(context.get(
				"active_item_tear_gas_cooldown_pause_active",
				false
			)),
			"active_item_boss_skill_cooldown_paused": bool(context.get(
				"active_item_boss_skill_cooldown_paused",
				false
			)),
		}
		return {}


func _init() -> void:
	_verify_tear_gas_reaches_the_real_motion_step()
	_verify_star_coil_reaches_the_real_motion_step()

	if _failures.is_empty():
		print("ball_boss_skill_pause_context_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_tear_gas_reaches_the_real_motion_step() -> void:
	var active_item_runtime: Object = _build_active_item_runtime()
	active_item_runtime.throw_controller.tear_gas_boss_pause_timer_frames = 3.0

	var direct_context: Dictionary = active_item_runtime.get_ball_collision_context()
	_expect(
		bool(direct_context.get("active_item_tear_gas_cooldown_pause_active", false)),
		"tear gas should keep its compatibility alias in the ball collision context"
	)
	_expect(
		bool(direct_context.get("active_item_boss_skill_cooldown_paused", false)),
		"tear gas should expose the canonical boss-skill pause flag in the ball collision context"
	)

	var owner := FakeOwner.new()
	var captured: Dictionary = _run_motion_step(owner, active_item_runtime)
	_expect(
		bool(captured.get("active_item_tear_gas_cooldown_pause_active", false)),
		"the swept ball motion context should preserve the tear-gas pause alias"
	)
	_expect(
		bool(captured.get("active_item_boss_skill_cooldown_paused", false)),
		"the swept ball motion context should receive the canonical tear-gas pause flag"
	)


func _verify_star_coil_reaches_the_real_motion_step() -> void:
	var active_item_runtime: Object = _build_active_item_runtime()
	var owner := FakeOwner.new()
	owner.values["lingpet_star_coil_freeze_boss_skill_cd"] = true

	var captured: Dictionary = _run_motion_step(owner, active_item_runtime)
	_expect(
		bool(captured.get("lingpet_star_coil_freeze_boss_skill_cd", false)),
		"the owner snapshot should preserve Star Coil's boss-skill pause flag through the swept motion step"
	)
	_expect(
		not bool(captured.get("active_item_tear_gas_cooldown_pause_active", false)),
		"Star Coil alone should not impersonate the tear-gas compatibility alias"
	)


func _run_motion_step(owner: FakeOwner, active_item_runtime: Object) -> Dictionary:
	var context: Dictionary = BallUpdateOwnerSnapshot.new().build(owner)
	var scene: Dictionary = {
		"ball_pos": context.get("ball_pos", Vector2.ZERO),
		"ball_vel": context.get("ball_vel", Vector2.ZERO),
		"ball_impact_boost": 1.0,
		"player_collision_cooldown": 0.0,
		"boss_collision_cooldown": 0.0,
	}
	var stage7_probe := Stage7ContextProbe.new()
	BallMotionEventProcessor.new().step_motion(
		scene,
		1.0,
		context,
		{
			"motion_stepper": BallMotionStepper.new(),
			"stage7_akamu_state": stage7_probe,
			"active_item_runtime": active_item_runtime,
		},
		{}
	)
	return stage7_probe.captured_context


func _build_active_item_runtime() -> Object:
	# Use the production ActiveItemRuntime -> context facade -> throw-controller
	# route while installing only the helpers owned by this focused surface. This
	# avoids constructing unrelated renderer/helper cycles in a headless smoke.
	var runtime: Object = ActiveItemRuntime.new()
	runtime.throw_controller = ActiveItemThrowController.new()
	runtime.effect_controller = null
	runtime.context_facade = ActiveItemRuntimeContextFacade.new()
	runtime._helpers_initialized = true
	return runtime


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
