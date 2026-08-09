extends SceneTree
# expect-zero-object-leaks -- acquisition fixtures must release runtime owners.

const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const LingpetAcquisitionLifecycleCoordinator := preload(
	"res://scripts/lingpet/lingpet_acquisition_lifecycle_coordinator.gd"
)
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const Smoke := preload("res://tests/lingpet_egg_runtime_smoke.gd")

var _failures: Array[String] = []


class FakeCommitFacade:
	extends RefCounted

	var regular_commit_calls := 0
	var sync_calls := 0

	func _finish_regular_hatch(_owner: Object, _registry: Object) -> void:
		regular_commit_calls += 1

	func _sync_owner(_owner: Object, _registry: Object) -> void:
		sync_calls += 1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_facade_ownership_boundary()
	_verify_guarded_pending_commit()
	_verify_production_lifecycle()
	await process_frame
	await process_frame
	if _failures.is_empty():
		print("lingpet_acquisition_lifecycle_coordinator_owner_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_facade_ownership_boundary() -> void:
	var facade_source := FileAccess.get_file_as_string(
		"res://scripts/lingpet/lingpet_egg_runtime.gd"
	)
	var coordinator_source := FileAccess.get_file_as_string(
		"res://scripts/lingpet/lingpet_acquisition_lifecycle_coordinator.gd"
	)
	_expect(
		facade_source.find("LingpetAcquisitionLifecycleCoordinator") >= 0
		and facade_source.find("_acquisition_lifecycle.configure") >= 0,
		"egg runtime must configure one acquisition lifecycle owner"
	)
	var delegated_functions := {
		"func is_acquire_cutin_active": "_acquisition_lifecycle.is_acquire_cutin_active",
		"func is_hatch_break_active": "_acquisition_lifecycle.is_hatch_break_active",
		"func advance_hatch_break": "_acquisition_lifecycle.advance_hatch_break",
		"func _reset_hatch_break_sequence": "_acquisition_lifecycle.reset_hatch_break_sequence",
		"func advance_acquire_cutin": "_acquisition_lifecycle.advance_acquire_cutin",
		"func get_acquire_cutin_progress": "_acquisition_lifecycle.get_acquire_cutin_progress",
		"func is_acquire_cutin_awaiting_dismiss": "_acquisition_lifecycle.is_acquire_cutin_awaiting_dismiss",
		"func begin_acquire_cutin_dismiss": "_acquisition_lifecycle.begin_acquire_cutin_dismiss",
		"func is_acquire_cutin_dismissing": "_acquisition_lifecycle.is_acquire_cutin_dismissing",
		"func get_acquire_cutin_dismiss_progress": "_acquisition_lifecycle.get_acquire_cutin_dismiss_progress",
		"func dismiss_acquire_cutin": "_acquisition_lifecycle.dismiss_acquire_cutin",
	}
	for signature in delegated_functions.keys():
		var delegated_call := str(delegated_functions[signature])
		_expect(
			_function_body(facade_source, str(signature)).find(delegated_call) >= 0,
			"%s must delegate to %s" % [str(signature), delegated_call]
		)
	for retired_facade_state in [
		"var _hatch_break_pending_kind",
		"var _hatch_break_burst_hold",
		"func _commit_pending_hatch",
	]:
		_expect(
			facade_source.find(retired_facade_state) < 0,
			"egg runtime must not regain acquisition lifecycle state %s" % retired_facade_state
		)
	for owned_behavior in [
		"PENDING_KIND_REGULAR",
		"PENDING_KIND_OVERFLOW",
		"HATCH_BREAK_BURST_HOLD_SECONDS",
		"_egg_state.trigger_hatch_break()",
		"_egg_state.trigger_hatch_flash",
		"func _commit_pending_hatch",
		"_asset_prewarm_state.prewarm_registry_step",
		"_overlay_host_resolver.is_anim_ready",
		"_overflow_choice_state.resolve_after_acquire_cutin",
		"_audio_dispatcher.play_lingpet_acquire_cutin",
		"_audio_dispatcher.play_lingpet_acquire_click_reaction_backing",
		"WeakRef",
	]:
		_expect(
			coordinator_source.find(owned_behavior) >= 0,
			"acquisition lifecycle coordinator must own %s" % owned_behavior
		)
	_expect(
		coordinator_source.find("runtime_facade.has_method(commit_method)") >= 0,
		"deferred hatch commit must verify the resolved facade method before consuming pending state"
	)
	_expect(
		coordinator_source.find("runtime_facade.has_method(\"_sync_owner\")") >= 0,
		"deferred hatch commit must guard the compatibility owner-sync callback"
	)


func _verify_guarded_pending_commit() -> void:
	var coordinator := LingpetAcquisitionLifecycleCoordinator.new()
	coordinator.configure(null, null, null, null, null, null, null, null, null, 0.0)
	coordinator._pending_hatch_kind = LingpetAcquisitionLifecycleCoordinator.PENDING_KIND_REGULAR
	coordinator._burst_hold_remaining = 0.45
	coordinator._commit_pending_hatch(null, null)
	_expect(
		coordinator._pending_hatch_kind == LingpetAcquisitionLifecycleCoordinator.PENDING_KIND_REGULAR,
		"missing facade must preserve the pending hatch for a later retry"
	)
	_expect(is_equal_approx(coordinator._burst_hold_remaining, 0.45), "missing facade must preserve the burst hold")

	var facade := FakeCommitFacade.new()
	coordinator.configure(null, null, null, null, null, null, null, null, facade, 0.0)
	var owner := RefCounted.new()
	coordinator._commit_pending_hatch(owner, null)
	_expect(facade.regular_commit_calls == 1, "resolved facade must receive one regular hatch commit")
	_expect(facade.sync_calls == 1, "resolved facade must receive one guarded owner sync")
	_expect(coordinator._pending_hatch_kind == "", "successful hatch commit must consume pending state")
	_expect(is_zero_approx(coordinator._burst_hold_remaining), "successful hatch commit must clear the burst hold")


func _verify_production_lifecycle() -> void:
	var owner := Smoke.FakeOwner.new()
	var registry := Smoke.FakeRegistry.new()
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner, registry)
	var egg_pos: Vector2 = owner.lingpet_egg_pos
	owner.ball_active = true
	owner.ball_pos = egg_pos + Vector2(0.0, -90.0)
	owner.ball_vel = Vector2(0.0, 12.0)
	runtime.update(0.21, owner, registry)
	owner.ball_pos = egg_pos + Vector2(1.0, -8.0)
	owner.ball_vel = Vector2(0.0, 12.0)
	runtime.update(0.0, owner, registry)
	_expect(runtime.is_hatch_break_active(), "final production egg hit must begin shell break")
	_expect(not runtime.is_acquire_cutin_active(), "cut-in must stay closed on the hatch hit frame")
	var burst_seen := false
	var guard := 0
	while runtime.is_hatch_break_active() and guard < 300:
		runtime.advance_hatch_break(1.0 / 60.0, owner, registry)
		if runtime._egg_state.has_hatch_flash() and not runtime.is_acquire_cutin_active():
			burst_seen = true
		guard += 1
	_expect(burst_seen, "shell burst hold must remain visible before acquisition commit")
	_expect(not runtime.is_hatch_break_active(), "production shell break must finish within its bounded clock")
	_expect(runtime.is_acquire_cutin_active(), "deferred hatch commit must open acquisition cut-in")
	_expect(str(owner.lingpet_state) == "companion", "deferred hatch commit must publish companion state")
	runtime.advance_acquire_cutin(3.0, registry)
	_expect(runtime.is_acquire_cutin_awaiting_dismiss(), "completed reveal must await player dismissal")
	_expect(runtime.begin_acquire_cutin_dismiss(registry), "dismiss request must start the exit action")
	_expect(runtime.is_acquire_cutin_dismissing(), "dismiss request must retain the active exit phase")
	runtime.advance_acquire_cutin(5.0, registry)
	_expect(not runtime.is_acquire_cutin_active(), "completed exit action must close the acquisition cut-in")
	runtime.reset_for_tests()
	registry.instances.clear()
	ProjectResourceLoader.clear_caches()


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\nfunc ", start + 1)
	return source.substr(start) if next < 0 else source.substr(start, next - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
