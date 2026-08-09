extends SceneTree

const PlazaScene := preload("res://scripts/plaza/plaza_scene.gd")
const PlazaStatusSnapshotBuilder := preload("res://scripts/plaza/plaza_status_snapshot_builder.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_builder_contract()
	_verify_facade_ownership()
	if _failures.is_empty():
		print("plaza_status_snapshot_builder_owner_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_builder_contract() -> void:
	var scene := PlazaScene.new()
	var builder := PlazaStatusSnapshotBuilder.new()
	var context: Dictionary = scene._build_status_snapshot_context()
	var status: Dictionary = builder.build(context)
	_expect(str(status.get("flow_gate", "")) == "street", "fresh Plaza status should begin at the street flow gate")
	_expect(int(status.get("current_stage", 0)) == 1, "snapshot builder should preserve the current stage")
	_expect(status.get("world_size", Vector2.ZERO) == PlazaScene.MAP_SIZE, "snapshot builder should preserve Plaza world geometry")
	_expect(not bool(status.get("menu_open", true)), "fresh Plaza status should report a closed building menu")
	var character_info_status := status.get("character_info_overlay_status", {}) as Dictionary
	_expect(not bool(character_info_status.get("active", true)), "missing character-info host should expose an inactive nested snapshot")
	_expect(not bool(character_info_status.get("visible", true)), "missing character-info host should expose a hidden nested snapshot")
	_expect(context.size() == PlazaStatusSnapshotBuilder.REQUIRED_CONTEXT_KEYS.size(), "Plaza facade should provide every required status context key exactly once")
	scene.free()


func _verify_facade_ownership() -> void:
	var scene_source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_scene.gd")
	var builder_source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_status_snapshot_builder.gd")
	var wrapper_body := _function_body(scene_source, "func get_status(")
	_expect(scene_source.find("PlazaStatusSnapshotBuilder") >= 0, "Plaza scene should preload the status snapshot builder")
	_expect(scene_source.find("var _status_snapshot_builder:") >= 0, "Plaza scene should own one status snapshot builder instance")
	_expect(wrapper_body.find("_status_snapshot_builder.build(_build_status_snapshot_context())") >= 0, "public Plaza status should delegate one explicit context to the snapshot owner")
	_expect(wrapper_body.find("\"flow_gate\"") < 0, "Plaza facade should not retain the inline status schema")
	_expect(builder_source.find("scene.get(") < 0, "snapshot builder must not reflect Plaza private fields by string")
	_expect(builder_source.find("callv(") < 0, "snapshot builder must not reflect Plaza private methods by string")
	_expect(builder_source.find("REQUIRED_CONTEXT_KEYS") >= 0, "snapshot builder must reject incomplete explicit contexts")
	for required_key in [
		"\"flow_gate\"",
		"\"interior_view_status\"",
		"\"last_shop_transaction_summary\"",
		"\"runtime_perk_choice_active\"",
		"\"minimap_state\"",
	]:
		_expect(builder_source.find(required_key) >= 0, "snapshot builder should own status key %s" % required_key)


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next_function := source.find("\nfunc ", start + signature.length())
	if next_function < 0:
		return source.substr(start)
	return source.substr(start, next_function - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
