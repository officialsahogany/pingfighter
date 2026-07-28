extends SceneTree

const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const LingpetGuardianTransitionState := preload(
	"res://scripts/lingpet/lingpet_guardian_transition_state.gd"
)
const Smoke := preload("res://tests/lingpet_egg_runtime_smoke.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_transition_state_geometry_and_alpha_gate()
	_verify_forced_expiry_interrupts_summon()
	_verify_round_cleanup_clears_transition()

	if _failures.is_empty():
		print("guardian_transition_lifecycle_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_transition_state_geometry_and_alpha_gate() -> void:
	var state: Object = LingpetGuardianTransitionState.new()
	_expect(state.begin_summon(Vector2(380.0, 700.0), Vector2(260.0, 620.0)), "summon transition should start once")
	_expect(not state.begin_stow(Vector2.ZERO, Vector2.ONE), "active transition should reject reentry")
	_expect(state.is_summoning(), "summon mode should be observable")
	state.advance(0.20)
	_expect_float(state.get_companion_alpha(), 0.0, "travel phase must not expose the guardian silhouette")
	state.advance(0.18)
	var dissolve_alpha: float = state.get_companion_alpha()
	_expect(dissolve_alpha > 0.0 and dissolve_alpha < 1.0, "landing phase must alpha-gate materialization")
	_expect(str(state.advance(0.20)) == LingpetGuardianTransitionState.MODE_SUMMON, "completion should emit one summon edge")
	_expect(not state.is_active(), "completed transition must tear itself down")


func _verify_forced_expiry_interrupts_summon() -> void:
	var owner := _make_owner()
	var registry := Smoke.FakeRegistry.new()
	var runtime: Object = LingpetEggRuntime.new()
	_expect(runtime.debug_grant_and_activate_pet("maribo", owner, false, "", "", registry), "fixture should activate a guardian")
	runtime.set_duration_pool_for_tests(50.0, 50.0)
	runtime.update(6.1, owner, registry)
	runtime.try_toggle_guardian_stow(owner, registry)
	runtime.update(0.47, owner, registry)
	runtime.try_toggle_guardian_stow(owner, registry)
	_expect(bool((runtime.get_snapshot().get("guardian_transition", {}) as Dictionary).get("active", false)), "fixture should enter summon transition")
	runtime.set_duration_pool_for_tests(0.2, 50.0)
	runtime.update(0.25, owner, registry)
	var snapshot: Dictionary = runtime.get_snapshot()
	_expect(runtime.is_guardian_stowed(), "expiry must keep guardian stowed")
	_expect(not bool((snapshot.get("guardian_transition", {}) as Dictionary).get("active", true)), "expiry must interrupt and clear summon presentation")
	_expect(not runtime.is_companion_active(), "expiry override must never expose combat availability")
	_cleanup(runtime)


func _verify_round_cleanup_clears_transition() -> void:
	var owner := _make_owner()
	var registry := Smoke.FakeRegistry.new()
	var runtime: Object = LingpetEggRuntime.new()
	runtime.debug_grant_and_activate_pet("maribo", owner, false, "", "", registry)
	runtime.set_duration_pool_for_tests(50.0, 50.0)
	runtime.update(6.1, owner, registry)
	_expect(runtime.try_toggle_guardian_stow(owner, registry), "fixture should consume stow toggle")
	_expect(bool((runtime.get_snapshot().get("guardian_transition", {}) as Dictionary).get("active", false)), "fixture should have a live stow transition")
	runtime.reset_round({"owner": owner, "registry": registry})
	_expect(not bool((runtime.get_snapshot().get("guardian_transition", {}) as Dictionary).get("active", true)), "round cleanup must directly clear transition VFX")
	_cleanup(runtime)


func _make_owner() -> Object:
	var owner := Smoke.FakeOwner.new()
	owner.ai_mode = "champion"
	owner.lingpet_owned_pet_ids = ["maribo"]
	owner.owned_lingpet_ids = ["maribo"]
	owner.owned_ringpet_ids = ["maribo"]
	owner.lingpet_slots = ["maribo", "", ""]
	owner.ringpet_slots = owner.lingpet_slots.duplicate()
	owner.lingpet_slot_pet_ids = owner.lingpet_slots.duplicate()
	owner.ringpet_slot_pet_ids = owner.lingpet_slots.duplicate()
	owner.lingpet_active_slot_index = 0
	owner.ringpet_active_slot_index = 0
	return owner


func _cleanup(runtime: Object) -> void:
	if runtime != null:
		runtime.reset_for_tests()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_float(actual: float, expected: float, message: String) -> void:
	if not is_equal_approx(actual, expected):
		_failures.append("%s (actual=%.4f expected=%.4f)" % [message, actual, expected])
