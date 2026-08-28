extends SceneTree

const BattleTransitionTexturePrewarmController := preload(
	"res://scripts/resources/battle_transition_texture_prewarm_controller.gd"
)

var _failures: Array[String] = []
var _cache_probe_count: int = 0


func _init() -> void:
	_verify_step_cursor_and_cache_hit_contract()
	_verify_battle_resources_delegates_state_ownership()

	if _failures.is_empty():
		print("battle_transition_texture_prewarm_controller_owner_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_step_cursor_and_cache_hit_contract() -> void:
	var controller: Object = BattleTransitionTexturePrewarmController.new()
	_expect(controller.prepare_transition("smasher:1:dalji:false"), "a new transition key should reset the cursor")
	_expect(controller.get_step_index() == 0, "a new transition should start at step zero")
	_expect(
		not controller.prepare_transition("smasher:1:dalji:false"),
		"reusing the active transition key should preserve the current cursor"
	)
	_expect(not controller.advance_step_and_is_complete(2), "the first of two steps should remain in progress")
	_expect(controller.get_step_index() == 1, "advancing should move the cursor exactly once")
	_expect(controller.advance_step_and_is_complete(2), "the second of two steps should complete the sequence")

	var step_done := bool(controller.prewarm_texture_spec_step(
		{
			"keys": ["player_walk_left_texture"],
			"path": "res://tests/fixtures/cached_transition_texture.png",
		},
		Callable(self, "_is_texture_spec_loaded"),
		Callable(self, "_try_store_cached_texture_spec"),
		Callable(self, "_load_texture_spec"),
		Callable(self, "_store_texture_spec")
	))
	_expect(step_done, "a shared-cache hit should complete without starting a worker")
	_expect(_cache_probe_count == 1, "the transition spec should probe the shared cache exactly once")
	_expect(not controller.is_threaded_prewarm_in_flight(), "a cache hit should not occupy the threaded slot")

	controller.reset_transition()
	_expect(controller.get_step_index() == 0, "reset should restore the cursor to step zero")


func _verify_battle_resources_delegates_state_ownership() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/resources/battle_resources.gd")
	_expect(
		source.find("BattleTransitionTexturePrewarmController") >= 0,
		"BattleResources should compose the dedicated transition prewarm controller"
	)
	_expect(
		source.find("var _transition_texture_prewarm_key") < 0,
		"BattleResources should not retain the transition key"
	)
	_expect(
		source.find("var _transition_texture_prewarm_step_index") < 0,
		"BattleResources should not retain the transition step cursor"
	)
	_expect(
		source.find("var _transition_texture_prewarm_current") < 0,
		"BattleResources should not retain the active threaded spec"
	)
	_expect(
		source.find("ResourceLoader.load_threaded_request") < 0,
		"BattleResources should not issue threaded texture requests directly"
	)


func _is_texture_spec_loaded(_spec: Dictionary) -> bool:
	return false


func _try_store_cached_texture_spec(_spec: Dictionary) -> bool:
	_cache_probe_count += 1
	return true


func _load_texture_spec(_spec: Dictionary) -> void:
	pass


func _store_texture_spec(_spec: Dictionary, _texture: Texture2D) -> void:
	pass


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
