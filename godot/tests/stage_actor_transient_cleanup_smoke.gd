extends SceneTree

const BattlePlayfieldEffectsDrawer := preload("res://scripts/core/battle_playfield_effects_drawer.gd")
const Stage1ActorRenderer := preload("res://scripts/stages/stage1/stage1_actor_renderer.gd")
const Stage2ActorRenderer := preload("res://scripts/stages/stage2/stage2_actor_renderer.gd")
const Stage3ActorRenderer := preload("res://scripts/stages/stage3/stage3_actor_renderer.gd")
const Stage4ActorRenderer := preload("res://scripts/stages/stage4/stage4_actor_renderer.gd")
const Stage5HongryunActorRenderer := preload("res://scripts/stages/stage5/stage5_hongryun_actor_renderer.gd")

var _failures: Array[String] = []


class FakeActorRenderer:
	extends RefCounted

	var clear_calls: int = 0
	var draw_calls: int = 0

	func clear_transient_canvas_items() -> void:
		clear_calls += 1

	func draw(_canvas: CanvasItem, _context: Dictionary, _perf_logger: Object = null) -> void:
		draw_calls += 1


class FakeRouter:
	extends RefCounted

	func get_module_key(stage: int, role: String) -> String:
		if role != "actor_renderer":
			return ""
		match stage:
			1:
				return "stage1_actor_renderer"
			2:
				return "stage2_actor_renderer"
			3:
				return "stage3_actor_renderer"
			4:
				return "stage4_actor_renderer"
			5:
				return "stage5_hongryun_actor_renderer"
			_:
				return "stage1_actor_renderer"

	func get_instance(registry: Object, stage: int, role: String) -> Object:
		var key := get_module_key(stage, role)
		if key == "" or registry == null or not registry.has_method("get_cached_instance"):
			return null
		return registry.get_cached_instance(key)


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}
	var get_instance_calls: Array[String] = []
	var get_cached_instance_calls: Array[String] = []

	func get_instance(key: String) -> Object:
		get_instance_calls.append(key)
		return instances.get(key, null)

	func get_cached_instance(key: String) -> Object:
		get_cached_instance_calls.append(key)
		return instances.get(key, null)


func _init() -> void:
	_verify_stage_actor_renderers_expose_transient_cleanup()
	_verify_inactive_stage_actor_transients_are_cleared()
	_verify_inactive_stage_actor_cleanup_settles_after_handoff()
	_verify_inactive_cleanup_uses_cached_renderers_only()
	_verify_current_actor_transients_clear_when_actor_context_is_empty()

	if _failures.is_empty():
		print("stage_actor_transient_cleanup_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_stage_actor_renderers_expose_transient_cleanup() -> void:
	var renderers := {
		"Stage 1": Stage1ActorRenderer.new(),
		"Stage 2": Stage2ActorRenderer.new(),
		"Stage 3": Stage3ActorRenderer.new(),
		"Stage 4": Stage4ActorRenderer.new(),
		"Stage 5": Stage5HongryunActorRenderer.new(),
	}
	for label in renderers.keys():
		var renderer: Object = renderers[label]
		_expect(renderer.has_method("clear_transient_canvas_items"), "%s actor renderer should expose transient canvas cleanup" % label)


func _verify_inactive_stage_actor_transients_are_cleared() -> void:
	var drawer := BattlePlayfieldEffectsDrawer.new()
	var registry := _build_registry()
	var stage1: FakeActorRenderer = registry.instances["stage1_actor_renderer"]
	var stage2: FakeActorRenderer = registry.instances["stage2_actor_renderer"]
	var stage5: FakeActorRenderer = registry.instances["stage5_hongryun_actor_renderer"]

	drawer.draw_actors(null, registry, {"current_stage": 5}, {"visible": true})

	_expect(stage1.clear_calls == 1, "inactive Stage 1 actor renderer should clear transient canvas items")
	_expect(stage2.clear_calls == 1, "inactive Stage 2 actor renderer should clear transient canvas items")
	_expect(stage5.clear_calls == 0, "current Stage 5 actor renderer should not be cleared before drawing")
	_expect(stage5.draw_calls == 1, "current Stage 5 actor renderer should still draw")


func _verify_inactive_stage_actor_cleanup_settles_after_handoff() -> void:
	var drawer := BattlePlayfieldEffectsDrawer.new()
	var registry := _build_registry()
	var stage1: FakeActorRenderer = registry.instances["stage1_actor_renderer"]
	var stage2: FakeActorRenderer = registry.instances["stage2_actor_renderer"]

	drawer.draw_actors(null, registry, {"current_stage": 2}, {"visible": true})
	drawer.draw_actors(null, registry, {"current_stage": 2}, {"visible": true})
	drawer.draw_actors(null, registry, {"current_stage": 2}, {"visible": true})

	_expect(stage1.clear_calls == 2, "inactive cleanup should keep a short handoff grace window")
	_expect(stage2.clear_calls == 0, "current Stage 2 actor renderer should not be cleared as inactive")

	drawer.draw_actors(null, registry, {"current_stage": 5}, {"visible": true})

	_expect(stage2.clear_calls == 1, "stage changes should restart inactive cleanup for the previous stage")


func _verify_inactive_cleanup_uses_cached_renderers_only() -> void:
	var drawer := BattlePlayfieldEffectsDrawer.new()
	var registry := _build_registry()
	registry.instances.erase("stage2_actor_renderer")
	registry.instances.erase("stage3_actor_renderer")
	registry.instances.erase("stage4_actor_renderer")
	registry.instances.erase("stage5_hongryun_actor_renderer")
	var stage1: FakeActorRenderer = registry.instances["stage1_actor_renderer"]

	drawer.draw_actors(null, registry, {"current_stage": 1}, {"visible": true})

	_expect(stage1.draw_calls == 1, "current Stage 1 actor renderer should still draw")
	for key in [
		"stage2_actor_renderer",
		"stage3_actor_renderer",
		"stage4_actor_renderer",
		"stage5_hongryun_actor_renderer",
	]:
		_expect(not registry.get_instance_calls.has(key), "inactive cleanup should not instantiate " + key)
	_expect(registry.get_cached_instance_calls.has("stage2_actor_renderer"), "inactive cleanup should check cached Stage 2 renderer")
	_expect(registry.get_cached_instance_calls.has("stage5_hongryun_actor_renderer"), "inactive cleanup should check cached Stage 5 renderer")


func _verify_current_actor_transients_clear_when_actor_context_is_empty() -> void:
	var drawer := BattlePlayfieldEffectsDrawer.new()
	var registry := _build_registry()
	var stage5: FakeActorRenderer = registry.instances["stage5_hongryun_actor_renderer"]

	drawer.draw_actors(null, registry, {"current_stage": 5}, {})

	_expect(stage5.clear_calls == 1, "current actor renderer should clear transients when actor draw is skipped")
	_expect(stage5.draw_calls == 0, "current actor renderer should not draw with an empty actor context")


func _build_registry() -> FakeRegistry:
	var registry := FakeRegistry.new()
	registry.instances = {
		"stage_runtime_router": FakeRouter.new(),
		"stage1_actor_renderer": FakeActorRenderer.new(),
		"stage2_actor_renderer": FakeActorRenderer.new(),
		"stage3_actor_renderer": FakeActorRenderer.new(),
		"stage4_actor_renderer": FakeActorRenderer.new(),
		"stage5_hongryun_actor_renderer": FakeActorRenderer.new(),
	}
	return registry


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
