extends SceneTree

const CommandoFirearmHudRainbowFxHost := preload("res://scripts/hud/commando_firearm_hud_rainbow_fx_host.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_prewarm_status()
	await _verify_sync_and_hide_lifecycle()

	if _failures.is_empty():
		print("commando_firearm_hud_rainbow_fx_host_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_prewarm_status() -> void:
	var status: Dictionary = CommandoFirearmHudRainbowFxHost.build_pipeline_status()
	_expect(bool(status.get("commando_firearm_hud_rainbow_shader_ready", false)), "rainbow HUD shader should preload")
	_expect(bool(status.get("commando_firearm_hud_rainbow_white_texture_ready", false)), "rainbow HUD white texture should prewarm")
	_expect(bool(status.get("commando_firearm_hud_rainbow_spark_texture_ready", false)), "rainbow HUD spark texture should prewarm")


func _verify_sync_and_hide_lifecycle() -> void:
	var host: Node2D = CommandoFirearmHudRainbowFxHost.new()
	get_root().add_child(host)
	await process_frame

	host.begin_frame()
	host.sync_panel(Rect2(Vector2(24.0, 32.0), Vector2(68.0, 112.0)), 0.8, "ak47", 1.25)
	host.end_frame()
	var slot: Sprite2D = host.get_node_or_null("RainbowBorderSlot") as Sprite2D
	_expect(slot != null and slot.visible, "synced rainbow HUD host should show its border slot")
	_expect(host.get_child_count() >= 5, "rainbow HUD host should keep one border slot and four corner emitters")

	host.begin_frame()
	host.end_frame()
	_expect(slot != null and not slot.visible, "unsynced rainbow HUD host should hide at end_frame")

	host.begin_frame()
	host.sync_panel(Rect2(Vector2(40.0, 60.0), Vector2(68.0, 112.0)), 0.6, "suicide_drone", 2.0)
	host.end_frame()
	_expect(slot != null and slot.visible, "rainbow HUD host should show again after a later sync")

	host.set_active(false)
	_expect(not host.visible, "set_active(false) should hide the rainbow HUD host node")
	_expect(slot != null and not slot.visible, "set_active(false) should hide the border slot")

	host.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
