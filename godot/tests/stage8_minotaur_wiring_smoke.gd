extends SceneTree

# Stage 8 미노타우로스 Slice 1 wiring seal.
# Proves the stage8_minotaur_state instance flows through the REAL deps
# builders on the two highest-risk live paths (effects/update + ball round),
# is present on the include-all reset peek path, and is correctly OMITTED
# when the current stage is not 8 (case-8 gating).
#
# Reverse-verification (반증검증): deleting the `8:` case from
# battle_update_stage_runtime_deps_builder._append_current_stage_deps (or the
# `_append_stage8_deps` body) flips `stage8 effects-path present` RED; deleting
# the `8:` case from ball_dependency_context.get_stage_round_dep_keys flips
# `stage8 ball round-key present` RED. Toggle in place (Edit), never git reset.

const StageRuntimeDepsBuilder := preload("res://scripts/core/battle_update_stage_runtime_deps_builder.gd")
const BallDependencyContext := preload("res://scripts/ball/ball_dependency_context.gd")
const Stage8MinotaurState := preload("res://scripts/stages/stage8/stage8_minotaur_state.gd")

var _failures: Array[String] = []


# Auto-vivifying fake registry: any requested key resolves to a single stable
# instance, so we can assert identity without enumerating every common dep.
class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		if not instances.has(key):
			instances[key] = RefCounted.new()
		return instances[key]

	func get_cached_instance(key: String) -> Object:
		return instances.get(key, null)


class FakeStageRouter:
	extends RefCounted

	func get_instance(_registry: Object, _current_stage: int, _role: String) -> Object:
		return null


func _init() -> void:
	var registry := FakeRegistry.new()
	registry.instances["stage_runtime_router"] = FakeStageRouter.new()
	# Pre-seed the real stage8 state so identity is provable end-to-end.
	var stage8_state := Stage8MinotaurState.new()
	registry.instances["stage8_minotaur_state"] = stage8_state

	var builder: Object = StageRuntimeDepsBuilder.new()

	# --- Effects / per-frame update path (missing case = frozen boss) ---
	var deps_stage8: Dictionary = builder.build_deps(registry, 8)
	_expect(
		deps_stage8.get("stage8_minotaur_state", null) == stage8_state,
		"effects/update deps for stage 8 should inject the stage8_minotaur_state instance"
	)
	var deps_stage7: Dictionary = builder.build_deps(registry, 7)
	_expect(
		not deps_stage7.has("stage8_minotaur_state"),
		"effects/update deps for stage 7 should OMIT stage8_minotaur_state (case-8 gating)"
	)

	# --- Include-all reset peek path (must not cold-instantiate) ---
	var deps_all: Dictionary = builder.build_deps(registry, 2, true)
	_expect(
		deps_all.get("stage8_minotaur_state", null) == stage8_state,
		"include-all reset peek should surface the cached stage8_minotaur_state"
	)

	# --- Ball round-dep path (missing case = collision/round dep miss) ---
	var round_keys_8: Array = BallDependencyContext.get_stage_round_dep_keys(8)
	_expect(
		round_keys_8.has("stage8_minotaur_state"),
		"ball round-dep keys for stage 8 should include stage8_minotaur_state"
	)
	var round_keys_7: Array = BallDependencyContext.get_stage_round_dep_keys(7)
	_expect(
		not round_keys_7.has("stage8_minotaur_state"),
		"ball round-dep keys for stage 7 should OMIT stage8_minotaur_state (case-8 gating)"
	)

	# --- Lifecycle contract sanity (state exposes what the framework calls) ---
	for method_name in [
		"update",
		"reset",
		"reset_for_result",
		"get_boss_ai_context",
		"get_actor_draw_context",
	]:
		_expect(
			stage8_state.has_method(method_name),
			"stage8_minotaur_state must expose %s() for the framework contract" % method_name
		)

	# Stage 8's chosen Slice-5 mechanic is Earthquake Smash. Until that slice is
	# implemented, the shell must not inherit Stage 7's score-three Awakening.
	stage8_state.handle_score_event("player", {"player_score": 3})
	stage8_state.update(1.0 / 60.0, {
		"current_stage": 8,
		"player_score": 3,
		"ball_active": true,
		"waiting_for_serve": false,
	})
	var actor_context: Dictionary = stage8_state.get_actor_draw_context()
	_expect(
		not bool(actor_context.get("stage8_minotaur_awakened", true))
			and not bool(actor_context.get("stage8_minotaur_gameplay_freeze_active", true)),
		"the Stage 8 placeholder shell must not activate copied Stage 7 Awakening gameplay"
	)

	if _failures.is_empty():
		print("stage8_minotaur_wiring_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
