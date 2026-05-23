extends SceneTree

const BootFlowScene := preload("res://scripts/core/boot_flow_scene.gd")

var failure_count: int = 0
var boot: Control = null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	boot = BootFlowScene.new()
	boot.set("post_intro_scene_path", "")
	get_root().add_child(boot)
	current_scene = boot
	await process_frame

	boot.set_process(false)
	boot.set("loading_character_select", true)
	boot.call("_preload_main_menu_bgm")
	var player := _get_preloaded_bgm_player()
	_expect(player != null, "loading screen should create the preloaded menu BGM player")
	if player != null:
		_expect(player.playing, "loading screen preloaded BGM should start playing")
	_send_b_to_boot()
	await process_frame
	_expect(bool(boot.get("main_menu_bgm_muted")), "B key should mark loading BGM muted")
	if player != null:
		_expect(not player.playing, "B key should stop the loading BGM")

	_send_b_to_boot()
	await process_frame
	_expect(not bool(boot.get("main_menu_bgm_muted")), "second B key should clear loading BGM muted")
	if player != null:
		_expect(player.playing, "second B key should resume the loading BGM")

	if player != null:
		player.queue_free()
		await process_frame
	if boot != null:
		if current_scene == boot:
			current_scene = null
		boot.queue_free()
		boot = null
		await process_frame
	get_root().set_meta("main_menu_bgm_muted", false)
	_finish()


func _get_preloaded_bgm_player() -> AudioStreamPlayer:
	return get_root().get_node_or_null("PreloadedMenuBgmPlayer") as AudioStreamPlayer


func _send_b_to_boot() -> void:
	if boot == null:
		return
	var event := InputEventKey.new()
	event.pressed = true
	@warning_ignore("int_as_enum_without_cast")
	event.keycode = KEY_B
	@warning_ignore("int_as_enum_without_cast")
	event.physical_keycode = KEY_B
	boot._gui_input(event)


func _finish() -> void:
	if failure_count > 0:
		quit(1)
		return
	print("boot_flow_bgm_toggle_smoke: ok")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
