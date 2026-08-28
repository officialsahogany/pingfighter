extends SceneTree

const BattleResultTexturePrewarmController := preload(
	"res://scripts/resources/battle_result_texture_prewarm_controller.gd"
)

var _failures: Array[String] = []
var _cache_probe_count: int = 0


func _init() -> void:
	_verify_deferred_queue_contract()
	_verify_battle_resources_delegates_state_ownership()

	if _failures.is_empty():
		print("battle_result_texture_prewarm_controller_owner_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_deferred_queue_contract() -> void:
	var controller: Object = BattleResultTexturePrewarmController.new()
	controller.queue_result_texture_prewarm(
		[
			{
				"keys": ["player_victory_sheet"],
				"path": "res://tests/fixtures/deferred_result_texture.png",
			},
		],
		1
	)
	_expect(controller.has_result_texture_prewarm_work(), "queued result work should be observable before its delay elapses")
	_expect(
		not bool(controller.update_result_texture_prewarm(
			Callable(self, "_is_texture_spec_loaded"),
			Callable(self, "_try_store_cached_texture_spec"),
			Callable(self, "_store_texture_spec")
		)),
		"the first update should consume one delay frame without resolving specs"
	)
	_expect(_cache_probe_count == 0, "delay frames should defer cache probing too")
	_expect(
		bool(controller.update_result_texture_prewarm(
			Callable(self, "_is_texture_spec_loaded"),
			Callable(self, "_try_store_cached_texture_spec"),
			Callable(self, "_store_texture_spec")
		)),
		"the next update should finish when the queued spec is already cached"
	)
	_expect(_cache_probe_count == 1, "the queued spec should be cache-probed exactly once after the delay")
	_expect(not controller.has_result_texture_prewarm_work(), "completed cached result work should leave no queued state")
	_expect(not controller.is_threaded_prewarm_in_flight(), "cached result work should not leave a threaded request active")


func _verify_battle_resources_delegates_state_ownership() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/resources/battle_resources.gd")
	_expect(
		source.find("BattleResultTexturePrewarmController") >= 0,
		"BattleResources should compose the dedicated result texture prewarm controller"
	)
	_expect(
		source.find("var _result_texture_prewarm_jobs") < 0,
		"BattleResources should not retain the result prewarm job queue"
	)
	_expect(
		source.find("var _result_texture_prewarm_pending") < 0,
		"BattleResources should not retain deferred result prewarm state"
	)
	_expect(
		source.find("ResourceLoader.load_threaded_get_status(_result_texture_prewarm_path") < 0,
		"BattleResources should not poll the result texture worker directly"
	)


func _is_texture_spec_loaded(_spec: Dictionary) -> bool:
	return false


func _try_store_cached_texture_spec(_spec: Dictionary) -> bool:
	_cache_probe_count += 1
	return true


func _store_texture_spec(_spec: Dictionary, _texture: Texture2D) -> void:
	pass


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
