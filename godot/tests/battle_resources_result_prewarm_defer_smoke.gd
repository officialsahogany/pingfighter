extends SceneTree

const BattleResources := preload("res://scripts/resources/battle_resources.gd")

var _failures: Array[String] = []


func _init() -> void:
	var resources: Object = BattleResources.new()
	resources.queue_result_texture_prewarm(
		"smasher",
		1,
		{
			"player_victory_active": true,
			"boss_defeat_active": true,
		}
	)

	_expect(resources.has_result_texture_prewarm_work(), "queued result prewarm should report pending work")
	_expect(not _has_result_texture(resources), "queued result prewarm should not touch result textures immediately")
	_expect(not bool(resources.update_result_texture_prewarm()), "first queued update should wait one frame")
	_expect(not _has_result_texture(resources), "first queued update should not start visible result texture work")

	if _failures.is_empty():
		print("battle_resources_result_prewarm_defer_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _has_result_texture(resources: Object) -> bool:
	var cache: Dictionary = resources.get_resource_cache()
	return (
		cache.get("player_victory_sheet", null) is Texture2D
		or cache.get("boss_defeat_sheet", null) is Texture2D
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
