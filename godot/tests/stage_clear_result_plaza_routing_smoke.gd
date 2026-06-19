extends SceneTree

const StageClearResultInteractionState := preload("res://scripts/ui/stage_clear_result_interaction_state.gd")
const StageClearResultNavigationActionHandler := preload("res://scripts/ui/stage_clear_result_navigation_action_handler.gd")
const StageClearResultScreen := preload("res://scripts/core/stage_clear_result_screen.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends Node2D

	var current_stage := 1
	var selected_character_type := "smasher"
	var runtime_perk_gold := 0


class FakeResultScene:
	extends Control

	func get_resolved_rewards() -> Array:
		return []


class CallbackSink:
	extends RefCounted

	var reset_calls := 0

	func reset_game() -> void:
		reset_calls += 1


func _init() -> void:
	_run()


func _run() -> void:
	_verify_three_button_action_route()
	_verify_result_character_type_normalization()
	_verify_plaza_delays_result_reset_callback()

	if _failures.is_empty():
		print("stage_clear_result_plaza_routing_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_three_button_action_route() -> void:
	var layout: Dictionary = StageClearResultInteractionState.get_scroll_button_layout(
		Rect2(Vector2(100.0, 200.0), Vector2(700.0, 400.0)),
		1.0
	)
	var plaza_rect: Rect2 = layout.get("plaza_rect", Rect2())
	_expect(plaza_rect.size.x > 0.0 and plaza_rect.size.y > 0.0, "scroll button layout should expose a plaza button rect")
	var clicked: String = StageClearResultInteractionState.get_clicked_button(
		plaza_rect.get_center(),
		layout.get("next_stage_rect", Rect2()),
		plaza_rect,
		layout.get("exit_rect", Rect2()),
		StageClearResultInteractionState.PHASE_VISIBLE
	)
	_expect(clicked == StageClearResultInteractionState.BUTTON_PLAZA, "clicking the middle result button should identify the plaza route")
	_expect(
		StageClearResultNavigationActionHandler.get_scroll_button_action(clicked) == StageClearResultNavigationActionHandler.ACTION_ENTER_PLAZA,
		"plaza result button should map to the plaza entry action"
	)


func _verify_result_character_type_normalization() -> void:
	var owner := FakeOwner.new()
	var screen := StageClearResultScreen.new()
	owner.selected_character_type = " IO "
	_expect(screen._get_selected_character_type(owner) == "optimus", "result screen should normalize Optimus aliases")
	_expect(screen._get_result_victory_character_type(owner) == "smasher", "Optimus should keep the shared Smasher victory result fallback")
	owner.selected_character_type = " Commando "
	_expect(screen._get_selected_character_type(owner) == "soldier", "result screen should normalize Commando aliases")
	_expect(screen._get_result_victory_character_type(owner) == "soldier", "Commando should keep its dedicated victory result assets")
	owner.selected_character_type = " Kohaku "
	_expect(screen._get_selected_character_type(owner) == "blacksmith", "result screen should normalize Blacksmith aliases")
	_expect(screen._get_result_victory_character_type(owner) == "blacksmith", "Blacksmith should keep its dedicated victory result assets")


func _verify_plaza_delays_result_reset_callback() -> void:
	var owner := FakeOwner.new()
	owner.runtime_perk_gold = 321
	owner.selected_character_type = "viper"
	root.add_child(owner)
	var sink := CallbackSink.new()
	var screen := StageClearResultScreen.new()
	var save_path := _smoke_save_path("routing")
	_cleanup_save(save_path)
	screen.set_plaza_save_path_for_test(save_path)
	var fake_result := FakeResultScene.new()
	owner.add_child(fake_result)
	screen.set("active", true)
	screen.set("current_stage", 1)
	screen.set("_pending_owner", owner)
	screen.set("_pending_reset_callback", Callable(sink, "reset_game"))
	screen.set("_scene_node", fake_result)

	screen.call("_finish_enter_plaza")
	_expect(screen.is_active(), "entering the plaza should keep the result screen controller active as an input gate")
	_expect(sink.reset_calls == 0, "plaza entry must not invoke the next-stage reset callback immediately")
	var status: Dictionary = screen.get_status()
	var progress_summary: Dictionary = status.get("last_plaza_progress_summary", {}) if status.get("last_plaza_progress_summary", {}) is Dictionary else {}
	var save_summary: Dictionary = screen.get_plaza_save_summary()
	_expect(int(progress_summary.get("transferred_gold", 0)) == 321, "plaza entry should transfer runtime perk gold exactly once")
	_expect(int(progress_summary.get("granted_ap", 0)) == 1, "plaza entry should grant the stage-clear AP once")
	_expect(owner.runtime_perk_gold == 0, "plaza entry should consume the volatile runtime perk gold")
	_expect(int(save_summary.get("plaza_gold", 0)) == 321, "plaza save should persist transferred gold")
	_expect(int(save_summary.get("ap_current", 0)) == 4, "plaza save should persist the granted AP")
	screen.call("_apply_stage_clear_progress_once", true)
	save_summary = screen.get_plaza_save_summary()
	_expect(int(save_summary.get("plaza_gold", 0)) == 321, "re-entering the plaza edge should not duplicate transferred gold")
	_expect(int(save_summary.get("ap_current", 0)) == 4, "re-entering the plaza edge should not duplicate AP")
	_expect(bool(status.get("plaza_active", false)), "plaza entry should spawn the plaza child scene")
	_expect(owner.get_node_or_null("PlazaScene") != null, "plaza entry should attach a PlazaScene child to the owner")
	var plaza_status: Dictionary = status.get("plaza_status", {}) if status.get("plaza_status", {}) is Dictionary else {}
	_expect(int(plaza_status.get("plaza_gold", 0)) == 321, "spawned plaza should read the same plaza save gold")
	_expect(int(plaza_status.get("ap_current", 0)) == 4, "spawned plaza should read the same plaza save AP")
	_expect(str(plaza_status.get("selected_character_type", "")) == "viper", "result-screen plaza route should pass the selected character through to the plaza")
	_expect(bool(plaza_status.get("player_sprite_loaded", false)), "result-screen plaza route should load the selected character plaza sheet")
	_expect(bool(plaza_status.get("plaza_warp_active", false)), "result-screen plaza route should start the arrival light-pillar phase")
	_expect(str(plaza_status.get("plaza_warp_phase", "")) == "arrive", "result-screen plaza route should mark the arrival light-pillar phase")

	screen.call("_finish_plaza_and_continue")
	_expect(not screen.is_active(), "leaving the plaza should close the result screen controller")
	_expect(sink.reset_calls == 1, "leaving the plaza should invoke the delayed next-stage reset callback exactly once")
	owner.queue_free()
	_cleanup_save(save_path)


func _cleanup_save(path: String) -> void:
	var backup_path := path.trim_suffix(".cfg") + ".last_good.cfg"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path))


func _smoke_save_path(slug: String) -> String:
	return "res://.tmp/stage_clear_result_plaza_routing_smoke_%s_%d_%d.cfg" % [
		slug,
		OS.get_process_id(),
		Time.get_ticks_usec(),
	]


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
