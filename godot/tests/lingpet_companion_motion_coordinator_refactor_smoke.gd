extends SceneTree

# expect-zero-object-leaks -- the coordinator must not retain its runtime facade.

const LingpetCompanionMotionCoordinator := preload("res://scripts/lingpet/lingpet_companion_motion_coordinator.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_owner_boundary()
	_verify_owner_backed_position_and_facing()
	_verify_runtime_facade_is_not_retained()
	if _failures.is_empty():
		print("lingpet_companion_motion_coordinator_refactor_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_owner_boundary() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var owner_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_motion_coordinator.gd")
	var resolver_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_player_runtime_resolver.gd")
	_expect(LingpetCompanionMotionCoordinator != null, "companion motion coordinator should preload")
	_expect(
		runtime_source.find("const LingpetCompanionMotionCoordinator := preload(\"res://scripts/lingpet/lingpet_companion_motion_coordinator.gd\")") >= 0
		and runtime_source.find("var _companion_motion_coordinator: Object = LingpetCompanionMotionCoordinator.new()") >= 0,
		"egg runtime should construct one companion position-priority owner"
	)
	_expect(
		runtime_source.find("LingpetCompanionPlayerRuntimeResolver") >= 0
		and runtime_source.find("_companion_player_runtime_resolver") >= 0,
		"egg runtime should construct one cached player-runtime resolver"
	)
	_expect(
		owner_source.find("func configure(") >= 0
		and owner_source.find("func update(") >= 0
		and owner_source.find("_mount_state.advance(") >= 0
		and owner_source.find("_ring_dash_state.advance(") >= 0
		and owner_source.find("_starlight_tracking_state.has_companion_position_override(") >= 0
		and owner_source.find("_motion_state.update(") >= 0,
		"coordinator should own mount -> skill -> Ring Dash -> Starlight -> patrol priority"
	)
	var wrapper_body := _function_body(runtime_source, "func _update_companion_motion(")
	_expect(
		wrapper_body.find("_companion_motion_coordinator.update(") >= 0
		and wrapper_body.find("_mount_state.advance(") < 0
		and wrapper_body.find("_ring_dash_state.advance(") < 0
		and wrapper_body.find("_companion_motion_state.update(") < 0,
		"egg runtime motion wrapper should be a narrow coordinator delegation"
	)
	var update_body := _function_body(owner_source, "func update(")
	_expect(
		update_body.find("return {") < 0
		and update_body.find("Callable(") < 0,
		"per-tick coordinator should not allocate a result Dictionary or callback"
	)
	_expect(
		owner_source.find("var _invalidate_snapshot: Callable") < 0
		and owner_source.find("var _is_right_click_claimed: Callable") < 0
		and owner_source.find("var _resolve_player_dash_state: Callable") < 0
		and owner_source.find("var _is_player_guard_available: Callable") < 0
		and owner_source.find("WeakRef") >= 0,
		"motion coordinator must retain the facade weakly and own no bound facade Callables"
	)
	var configure_body := _function_body(runtime_source, "func _init(")
	_expect(
		configure_body.find("Callable(self, \"_invalidate_runtime_snapshot_cache\")") < 0
		and configure_body.find("Callable(self, \"_is_right_click_claimed_by_player_skill\")") < 0
		and configure_body.find("Callable(self, \"_resolve_player_dash_state\")") < 0
		and configure_body.find("Callable(self, \"_is_player_guard_available\")") < 0,
		"egg runtime construction must not create a facade/coordinator reference cycle"
	)
	_expect(
		resolver_source.find("get_cached_instance") >= 0
		and resolver_source.find("get_instance(") < 0
		and owner_source.find("_player_runtime_resolver.is_right_click_claimed_by_player_skill") >= 0
		and owner_source.find("_player_runtime_resolver.resolve_player_dash_state") >= 0
		and owner_source.find("_player_runtime_resolver.is_player_guard_available") >= 0,
		"player runtime resolver must own cached-only arbitration used by the motion coordinator"
	)


func _verify_owner_backed_position_and_facing() -> void:
	var runtime := LingpetEggRuntime.new()
	var coordinator: Object = runtime.get("_companion_motion_coordinator")
	_expect(coordinator != null, "fresh egg runtime should expose its motion coordinator")
	if coordinator == null:
		return
	runtime.set("_companion_pos", Vector2(123.0, 456.0))
	_expect(
		coordinator.call("get_position") == Vector2(123.0, 456.0)
		and runtime.get("_companion_motion_state").get("pos") == Vector2(123.0, 456.0),
		"legacy companion position writes should update the owner and patrol state without duplicate storage"
	)
	coordinator.call("set_position", Vector2(321.0, 654.0))
	_expect(runtime.get("_companion_pos") == Vector2(321.0, 654.0), "owner position writes should project through the legacy runtime property")
	runtime.set("_companion_facing_left", true)
	_expect(bool(coordinator.call("is_facing_left")), "legacy facing writes should update the owner")
	coordinator.call("set_facing_left", false)
	_expect(not bool(runtime.get("_companion_facing_left")), "owner facing writes should project through the legacy runtime property")
	var revision_before := int(runtime.get("_runtime_snapshot_revision"))
	coordinator.call("_invalidate_runtime_snapshot")
	_expect(
		int(runtime.get("_runtime_snapshot_revision")) == revision_before + 1,
		"weak facade bridge must still invalidate the runtime snapshot while it is alive"
	)


func _verify_runtime_facade_is_not_retained() -> void:
	var runtime: Object = LingpetEggRuntime.new()
	var runtime_ref: WeakRef = weakref(runtime)
	runtime = null
	_expect(
		runtime_ref.get_ref() == null,
		"motion coordinator must not keep the RefCounted egg-runtime facade alive"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\n\nfunc ", start + signature.length())
	return source.substr(start) if next < 0 else source.substr(start, next - start)
