extends SceneTree

const StageClearResultHandlerRegistry := preload("res://scripts/core/stage_clear_result_handler_registry.gd")
const StageClearResultScreen := preload("res://scripts/core/stage_clear_result_screen.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_registry_builds_all_screen_services()
	_verify_registry_applies_services_to_screen()
	_verify_source_boundary()

	if _failures.is_empty():
		print("stage_clear_result_handler_registry_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_registry_builds_all_screen_services() -> void:
	var registry := StageClearResultHandlerRegistry.new()
	var fields: Array = registry.get_field_names()
	var services: Dictionary = registry.build_services()
	_expect(fields.size() == 21, "handler registry should publish every injected result-screen field")
	for field_name in fields:
		var key := str(field_name)
		_expect(registry.has_service_field(key), "handler registry should recognize service field %s" % key)
		_expect(services.has(key), "handler registry should build service %s" % key)
		_expect(services.get(key, null) is Object, "handler registry service %s should be an object" % key)
	_expect(not registry.has_service_field("_scene_node"), "handler registry should not claim screen state fields")


func _verify_registry_applies_services_to_screen() -> void:
	var screen := StageClearResultScreen.new()
	var registry: Object = screen.get("_handler_registry")
	_expect(registry != null, "result screen should keep a handler registry")
	for field_name in StageClearResultHandlerRegistry.FIELD_NAMES:
		var key := str(field_name)
		_expect(screen.get(key) is Object, "result screen should receive injected service %s" % key)


func _verify_source_boundary() -> void:
	var screen_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_screen.gd")
	var registry_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_handler_registry.gd")
	_expect(screen_source.find("StageClearResultHandlerRegistry") >= 0, "result screen should own its helper set through the handler registry")
	_expect(screen_source.find("StageClearResultRewardPlanBuilder := preload") < 0, "result screen should not preload reward plan builder directly")
	_expect(screen_source.find("StageClearResultShowFlowHandler := preload") < 0, "result screen should not preload show flow handler directly")
	_expect(screen_source.find("StageClearResultUpdateFlowHandler := preload") < 0, "result screen should not preload update flow handler directly")
	_expect(screen_source.find("var _reward_plan_builder") < 0, "result screen should not declare individual helper service fields")
	_expect(screen_source.find("var _show_flow_handler") < 0, "result screen should not declare individual flow handler fields")
	_expect(screen_source.find("var _services: Dictionary") >= 0, "result screen should store injected helpers in a service map")
	_expect(screen_source.find("func _get(property: StringName)") >= 0, "result screen should keep dynamic service reads for existing screen.get callers")
	_expect(screen_source.find("func _set(property: StringName") >= 0, "result screen should keep dynamic service writes for registry injection")
	_expect(registry_source.find("StageClearResultRewardPlanBuilder.new()") >= 0, "handler registry should create the reward plan builder")
	_expect(registry_source.find("StageClearResultShowFlowHandler.new()") >= 0, "handler registry should create the show flow handler")
	_expect(registry_source.find("StageClearResultUpdateFlowHandler.new()") >= 0, "handler registry should create the update flow handler")
	_expect(registry_source.find("func has_service_field") >= 0, "handler registry should expose service field validation")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
