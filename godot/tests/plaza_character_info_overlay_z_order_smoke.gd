extends SceneTree

const PlazaScenePacked := preload("res://scenes/plaza.tscn")

const LIVE_PLAZA_Z_INDEX := 1200

var _failures: Array[String] = []


class CallbackSink:
	extends RefCounted

	var exit_calls := 0

	func exit_plaza() -> void:
		exit_calls += 1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _verify_character_info_overlay_renders_above_driven_plaza()

	if _failures.is_empty():
		print("plaza_character_info_overlay_z_order_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_character_info_overlay_renders_above_driven_plaza() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(760, 750)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var scene := PlazaScenePacked.instantiate() as Control
	_expect(scene != null, "plaza scene should instantiate")
	if scene == null:
		viewport.queue_free()
		return

	scene.z_index = LIVE_PLAZA_Z_INDEX
	viewport.add_child(scene)
	var save_path := _smoke_save_path("character_info_z")
	_cleanup_save(save_path)
	var sink := CallbackSink.new()
	scene.configure({"current_stage": 1, "plaza_save_path": save_path, "full_layout_for_test": true}, Callable(sink, "exit_plaza"), true)
	scene.size = Vector2(760.0, 750.0)
	scene.update_plaza(1.0 / 60.0)

	_send_key(scene, KEY_TAB)
	var host := scene.get_node_or_null("PlazaCharacterInfoOverlayHost") as Control
	_expect(host != null, "TAB should create the plaza character-info overlay host")
	var status: Dictionary = scene.get_status()
	_expect(bool(status.get("character_info_overlay_active", false)), "TAB should activate the plaza character-info overlay")
	_expect(bool(status.get("character_info_overlay_visible", false)), "TAB should make the plaza character-info overlay visible")
	if host != null:
		var host_effective_z := _effective_z_index(host)
		var plaza_effective_z := _effective_z_index(scene)
		_expect(host.z_index > 0, "plaza character-info host should render above the plaza draw pass")
		_expect(host_effective_z > plaza_effective_z, "plaza character-info host effective z should sit above the driven plaza root")

	var ground_y := float(status.get("ground_y", 0.0))
	scene.set_player_pos_for_test(Vector2(180.0, ground_y - 80.0))
	var before_blocked: Vector2 = scene.get_status().get("player_pos", Vector2.ZERO)
	scene.move_player_for_test(Vector2.RIGHT, 1.0 / 60.0)
	var after_blocked: Vector2 = scene.get_status().get("player_pos", Vector2.ZERO)
	_expect(after_blocked.is_equal_approx(before_blocked), "active character-info overlay should intentionally pause plaza movement")

	_send_key(scene, KEY_TAB)
	status = scene.get_status()
	_expect(not bool(status.get("character_info_overlay_active", true)), "second TAB should close the plaza character-info overlay")
	var before_resume: Vector2 = scene.get_status().get("player_pos", Vector2.ZERO)
	scene.move_player_for_test(Vector2.RIGHT, 1.0 / 60.0)
	var after_resume: Vector2 = scene.get_status().get("player_pos", Vector2.ZERO)
	_expect(after_resume.x > before_resume.x, "plaza movement should resume after the character-info overlay closes")

	viewport.queue_free()
	_cleanup_save(save_path)


func _send_key(scene: Control, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	scene.handle_plaza_input(event)


func _effective_z_index(item: CanvasItem) -> int:
	var total := item.z_index
	var parent := item.get_parent()
	if item.z_as_relative and parent is CanvasItem:
		total += _effective_z_index(parent as CanvasItem)
	return total


func _smoke_save_path(slug: String) -> String:
	return "res://.tmp/plaza_character_info_overlay_z_order_smoke_%s_%d_%d.cfg" % [
		slug,
		OS.get_process_id(),
		Time.get_ticks_usec(),
	]


func _cleanup_save(path: String) -> void:
	var backup_path := path.trim_suffix(".cfg") + ".last_good.cfg"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
