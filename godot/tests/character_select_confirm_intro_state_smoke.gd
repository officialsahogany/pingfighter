extends SceneTree

const ConfirmIntroState := preload("res://scripts/ui/character_select_confirm_intro_state.gd")

var failure_count := 0


func _init() -> void:
	_verify_screen_single_owner_contract()
	var state := ConfirmIntroState.new()
	_expect(state.request_finish() == ConfirmIntroState.ACTION_NONE, "inactive state should ignore finish requests")
	_expect(state.advance(1.0) == ConfirmIntroState.ACTION_NONE and state.elapsed == 0.0, "inactive state should not advance")

	var plain_character := {
		"id": "smasher",
		"card_color": Color(0.2, 0.7, 1.0),
	}
	state.begin(plain_character, "res://scenes/main.tscn")
	plain_character["id"] = "mutated"
	_expect(state.active and str(state.character.get("id", "")) == "smasher", "begin should deep-copy the selected character")
	_expect(state.pending_scene_path == "res://scenes/main.tscn", "begin should retain the pending scene path")
	var plain_snapshot := state.get_snapshot()
	_expect(bool(plain_snapshot.get("active", false)), "snapshot should expose active state")
	_expect(str((plain_snapshot.get("character", {}) as Dictionary).get("id", "")) == "smasher", "snapshot should expose the selected character")
	var snapshot_character: Dictionary = plain_snapshot.get("character", {})
	snapshot_character["id"] = "snapshot_mutation"
	_expect(str(state.character.get("id", "")) == "smasher", "snapshot should deep-copy character data")
	_expect(state.request_finish() == ConfirmIntroState.ACTION_FINISH, "intro without exit flash should finish directly")
	_expect(state.finish() == "res://scenes/main.tscn", "finish should return the pending scene path")
	_expect(not state.active and state.character.is_empty() and state.pending_scene_path == "", "finish should reset all logical state")

	var flash_character := {
		"id": "viper",
		"confirm_intro_exit_flash_enabled": true,
		"confirm_intro_exit_flash_hold": 0.25,
		"confirm_intro_exit_flash_duration": 0.62,
		"confirm_intro_exit_flash_style": "slash",
		"confirm_intro_exit_flash_color": Color(0.8, 0.1, 0.4),
		"confirm_intro_exit_flash_glow_color": Color(0.2, 0.9, 1.0),
		"confirm_intro_exit_flash_secondary_color": Color(1.0, 0.8, 0.2),
		"confirm_intro_exit_flash_split_intensity": 0.73,
		"confirm_intro_exit_flash_split_count": 13,
	}
	state.begin(flash_character, "res://battle.tscn")
	_expect(state.request_finish() == ConfirmIntroState.ACTION_NONE, "positive flash hold should defer overlay start")
	_expect(state.exit_flash_pending and is_equal_approx(state.exit_flash_hold_remaining, 0.25), "finish request should arm the authored flash hold")
	_expect(state.advance(0.10) == ConfirmIntroState.ACTION_NONE, "flash should remain pending before hold expiry")
	_expect(is_equal_approx(state.elapsed, 0.10) and is_equal_approx(state.exit_flash_hold_remaining, 0.15), "advance should update elapsed and hold clocks together")
	_expect(state.advance(0.16) == ConfirmIntroState.ACTION_START_FLASH, "flash should start on the hold-expiry edge")
	state.mark_flash_started()
	_expect(not state.exit_flash_pending and state.exit_flash_started and state.exit_flash_hold_remaining == 0.0, "marking flash start should consume the pending hold")

	var source_rect := Rect2(120.0, 80.0, 420.0, 360.0)
	var payload := state.build_flash_payload(source_rect)
	_expect(payload.get("source_rect", Rect2()) == source_rect, "flash payload should retain the live preview source rect")
	_expect(is_equal_approx(float(payload.get("duration", 0.0)), 0.62), "flash payload should retain authored duration")
	_expect(str(payload.get("style", "")) == "slash", "flash payload should retain authored style")
	_expect(payload.get("accent", Color.BLACK) == Color(0.8, 0.1, 0.4), "flash payload should retain authored accent")
	_expect(payload.get("glow", Color.BLACK) == Color(0.2, 0.9, 1.0), "flash payload should retain authored glow")
	_expect(is_equal_approx(float(payload.get("split_intensity", 0.0)), 0.73) and int(payload.get("split_count", 0)) == 13, "flash payload should retain split fracture tuning")
	_expect(state.finish() == "res://battle.tscn" and not state.active, "flash completion should return the pending scene and reset")

	state.begin({"confirm_intro_exit_flash_enabled": true, "confirm_intro_exit_flash_hold": 0.0}, "")
	_expect(state.request_finish() == ConfirmIntroState.ACTION_START_FLASH, "zero hold should request the flash immediately")
	state.reset()

	if failure_count > 0:
		quit(1)
		return
	print("character_select_confirm_intro_state_smoke: ok")
	quit(0)


func _verify_screen_single_owner_contract() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/character_select_screen.gd")
	for mirror_name in [
		"confirm_intro_active",
		"confirm_intro_character",
		"confirm_intro_elapsed",
		"confirm_intro_pending_scene_path",
		"confirm_intro_exit_flash_pending",
		"confirm_intro_exit_flash_hold_remaining",
		"confirm_intro_exit_flash_started",
	]:
		_expect(source.find("var %s" % mirror_name) == -1, "%s mirror should be removed" % mirror_name)
	_expect(source.find("func _sync_confirm_intro_facade") == -1, "screen should not synchronize confirm-intro mirrors")
	_expect(source.find("var _confirm_intro_state: CharacterSelectConfirmIntroState") >= 0, "screen should keep one typed confirm-intro owner")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
