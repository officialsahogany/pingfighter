extends SceneTree

const GameplayModuleRegistry := preload("res://scripts/resources/gameplay_module_registry.gd")
const ScriptInstanceCache := preload("res://scripts/resources/script_instance_cache.gd")
const STAGE2_BACKGROUND_PATH := "res://scripts/stages/stage2/stage2_pillar_background.gd"
const CHARACTER_INFO_OVERLAY_KEY := "character_info_overlay"
const CHARACTER_INFO_OVERLAY_PATH := "res://scripts/hud/character_info_overlay.gd"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var cache: Object = ScriptInstanceCache.new()
	_expect(not bool(cache.request_threaded_script(STAGE2_BACKGROUND_PATH, "stage2 pillar background")), "stage2 pillar background script should start as a threaded request")
	_expect(cache.threaded_script_requests.has(STAGE2_BACKGROUND_PATH), "threaded script request should be tracked by path")

	var guard := 0
	while not bool(cache.is_threaded_script_ready(STAGE2_BACKGROUND_PATH, "stage2 pillar background")) and guard < 240:
		guard += 1
		await process_frame
	_expect(guard < 240, "threaded stage2 pillar background script load should finish")
	_expect(cache.script_cache.has(STAGE2_BACKGROUND_PATH), "threaded script load should populate the script cache")

	var instance: Object = cache.create_ref_counted(STAGE2_BACKGROUND_PATH, "stage2 pillar background")
	_expect(instance != null, "threaded-loaded stage2 pillar background script should instantiate")

	var registry := GameplayModuleRegistry.new()
	_expect(not bool(registry.request_threaded_script(CHARACTER_INFO_OVERLAY_KEY)), "character info overlay registry key should start as a threaded request")
	_expect(registry.cache.threaded_script_requests.has(CHARACTER_INFO_OVERLAY_PATH), "character info overlay threaded request should resolve to the HUD overlay script path")
	guard = 0
	while not bool(registry.is_threaded_script_ready(CHARACTER_INFO_OVERLAY_KEY)) and guard < 240:
		guard += 1
		await process_frame
	_expect(guard < 240, "threaded character info overlay script load should finish")
	_expect(registry.cache.script_cache.has(CHARACTER_INFO_OVERLAY_PATH), "threaded character info overlay load should populate the script cache")

	if _failures.is_empty():
		print("script_instance_cache_threaded_script_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
