extends SceneTree

const MAIN_MENU_SCENE_PATH := "res://scenes/main_menu.tscn"


class QuitRequestSink:
	extends RefCounted

	var quit_calls: int = 0

	func request_quit() -> void:
		quit_calls += 1


var failure_count: int = 0
var menu: Control = null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(MAIN_MENU_SCENE_PATH) as PackedScene
	_expect(packed != null, "main menu scene should load for quit confirmation smoke")
	if packed == null:
		_finish()
		return

	menu = packed.instantiate()
	get_root().add_child(menu)
	current_scene = menu
	await process_frame
	_finish_intro_reveal()
	await process_frame

	var quit_button := menu.get_node_or_null("ButtonStack/QuitButton") as Button
	var quit_overlay := menu.get_node_or_null("QuitConfirmOverlay") as Control
	var quit_yes_button := menu.get_node_or_null("QuitConfirmOverlay/DialogPanel/DialogMargin/DialogVBox/ButtonRow/YesButton") as Button
	var quit_no_button := menu.get_node_or_null("QuitConfirmOverlay/DialogPanel/DialogMargin/DialogVBox/ButtonRow/NoButton") as Button
	_expect(quit_button != null, "main menu quit button should exist")
	if quit_button != null:
		_expect(not quit_button.visible, "main menu quit button should stay hidden on the touch-to-start screen")
	_expect(quit_overlay != null, "quit confirmation overlay should exist")
	_expect(quit_yes_button != null, "quit confirmation yes button should exist")
	_expect(quit_no_button != null, "quit confirmation no button should exist")

	var quit_sink := QuitRequestSink.new()
	menu.set("application_quit_callback", Callable(quit_sink, "request_quit"))

	if quit_button != null:
		quit_button.pressed.emit()
	await process_frame
	_expect(quit_overlay != null and quit_overlay.visible, "quit button should open the confirmation overlay")
	_expect(quit_no_button != null and quit_no_button.has_focus(), "confirmation overlay should default focus to no")

	if quit_no_button != null:
		quit_no_button.pressed.emit()
	await process_frame
	_expect(quit_overlay != null and not quit_overlay.visible, "no button should close the confirmation overlay")
	_expect(quit_button != null and not quit_button.visible, "canceling quit should not reveal the hidden quit button")
	_expect(quit_sink.quit_calls == 0, "canceling quit should not call the quit callback")

	if quit_button != null:
		quit_button.pressed.emit()
	await process_frame
	_expect(quit_overlay != null and quit_overlay.visible, "quit confirmation should reopen after cancel")

	if quit_yes_button != null:
		quit_yes_button.pressed.emit()
	await process_frame
	_expect(quit_overlay != null and not quit_overlay.visible, "yes button should close the confirmation overlay")
	_expect(quit_sink.quit_calls == 1, "confirming quit should call the quit callback exactly once")
	_expect(bool(menu.get("transitioning")), "confirming quit should set transitioning")

	_finish()


func _finish() -> void:
	if failure_count > 0:
		quit(1)
		return
	print("main_menu_quit_confirmation_smoke: ok")
	quit(0)


func _finish_intro_reveal() -> void:
	if menu == null:
		return
	var reveal := menu.get_node_or_null("RevealLayer")
	if reveal != null and reveal.has_method("_finish_reveal"):
		reveal.call("_finish_reveal")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
