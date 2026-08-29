extends SceneTree

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetCollectionState := preload("res://scripts/lingpet/lingpet_collection_state.gd")
const LingpetCurrentProfile := preload("res://scripts/lingpet/lingpet_current_profile.gd")
const LingpetSaveRestorePlanner := preload("res://scripts/lingpet/lingpet_save_restore_planner.gd")
const LingpetOverflowChoiceState := preload("res://scripts/lingpet/lingpet_overflow_choice_state.gd")
const LingpetOverflowReplacePlan := preload("res://scripts/lingpet/lingpet_overflow_replace_plan.gd")
const LingpetOverflowChoiceOverlayHost := preload("res://scripts/hud/lingpet_overflow_choice_overlay_host.gd")
const LingpetGuardianEnhanceOfferEngine := preload("res://scripts/lingpet/lingpet_guardian_enhance_offer_engine.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted
	var ai_mode := "junior league"
	var selected_character_type := "smasher"
	var lingpet_id := "maribo"
	var lingpet_state := "companion"
	var lingpet_owned_pet_ids: Array = ["maribo", "lunabi", "milkring"]
	var owned_lingpet_ids: Array = lingpet_owned_pet_ids.duplicate()
	var owned_ringpet_ids: Array = lingpet_owned_pet_ids.duplicate()
	var lingpet_collection: Dictionary = {"maribo": true, "lunabi": true, "milkring": true}
	var ringpet_collection: Dictionary = lingpet_collection.duplicate(true)
	var owned_lingpets: Dictionary = lingpet_collection.duplicate(true)
	var owned_ringpets: Dictionary = lingpet_collection.duplicate(true)
	var lingpet_slots: Array = ["", "lunabi", "maribo"]
	var ringpet_slots: Array = lingpet_slots.duplicate()
	var lingpet_slot_pet_ids: Array = lingpet_slots.duplicate()
	var ringpet_slot_pet_ids: Array = lingpet_slots.duplicate()
	var lingpet_active_slot_index := 2
	var ringpet_active_slot_index := 2


class FakeChoiceRuntime:
	extends RefCounted
	var snapshot := {
		"active": true,
		"absorb_only": false,
		"pending_pet_id": "rahoset",
	}
	var replace_count := 0
	var absorb_count := 0

	func is_overflow_choice_active() -> bool:
		return true

	func get_overflow_choice_snapshot() -> Dictionary:
		return snapshot.duplicate(true)

	func commit_overflow_replace(_slot_index: int, _owner: Object, _registry: Object) -> bool:
		replace_count += 1
		return true

	func commit_overflow_absorb(_owner: Object, _registry: Object) -> bool:
		absorb_count += 1
		return true


func _init() -> void:
	_verify_live_roster_and_collection_history_are_separate()
	_verify_legacy_three_slot_restore_takes_first_valid_only()
	_verify_collection_complete_eggs_become_absorb_only()
	_verify_two_choice_and_absorb_source_localization()
	_verify_new_guardian_portrait_and_tooltip_payload()
	_verify_production_overflow_icon_prewarm_wiring()
	_verify_two_choice_input_routes()
	_verify_retired_cycle_source_is_absent()
	_verify_round_reset_closes_absorb_presentation()
	if _failures.is_empty():
		print("lingpet_one_guardian_roster_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_live_roster_and_collection_history_are_separate() -> void:
	var owner := FakeOwner.new()
	var state := LingpetCollectionState.new()
	state.sync_from_owner(owner)
	_expect(state.get_owned_pet_ids() == ["lunabi"], "legacy live roster must prefer the first valid battle slot")
	_expect(state.get_battle_slots() == ["lunabi"], "legacy slot array must adopt only its first valid slot")
	var collected: Array[String] = state.get_collected_pet_ids()
	for pet_id in ["maribo", "lunabi", "milkring"]:
		_expect(collected.has(pet_id), "legacy ids must survive as permanent collection history: %s" % pet_id)
	var replaced: Dictionary = state.replace_slot(owner, 0, "volty")
	_expect(str(replaced.get("new_pet_id", "")) == "volty", "slot zero replacement must accept one incoming guardian")
	_expect(owner.lingpet_owned_pet_ids == ["volty"], "owner live roster must stay capped at one")
	for pet_id in ["maribo", "lunabi", "milkring", "volty"]:
		_expect(bool(owner.lingpet_collection.get(pet_id, false)), "replacement must preserve collection history: %s" % pet_id)


func _verify_legacy_three_slot_restore_takes_first_valid_only() -> void:
	var state := LingpetCollectionState.new()
	var planner := LingpetSaveRestorePlanner.new()
	var plan: Dictionary = planner.build_plan({
		"state": "companion",
		"pet_id": "maribo",
		"owned_pet_ids": ["volty", "milkring", "maribo"],
		"battle_slot_pet_ids": ["", "lunabi", "maribo"],
		"active_slot_index": 2,
	}, null, state, "maribo", "companion")
	_expect(str(plan.get("pet_id", "")) == "lunabi", "legacy restore must choose the first valid slot, not the old active index")
	_expect(state.get_owned_pet_ids() == ["lunabi"], "legacy restore must publish one live owner")
	_expect(state.get_battle_slots() == ["lunabi"], "legacy restore must shrink slots to one entry")
	var collected: Array[String] = state.get_collected_pet_ids()
	for pet_id in ["volty", "milkring", "maribo"]:
		_expect(collected.has(pet_id), "legacy owned ids must migrate into collection history: %s" % pet_id)


func _verify_collection_complete_eggs_become_absorb_only() -> void:
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["maribo"]
	owner.owned_lingpet_ids = ["maribo"]
	owner.owned_ringpet_ids = ["maribo"]
	owner.lingpet_slots = ["maribo"]
	owner.ringpet_slots = ["maribo"]
	owner.lingpet_slot_pet_ids = ["maribo"]
	owner.ringpet_slot_pet_ids = ["maribo"]
	var all_collected: Dictionary = {}
	for pet_id in LingpetCatalog.get_pet_ids():
		all_collected[pet_id] = true
	owner.lingpet_collection = all_collected.duplicate(true)
	owner.ringpet_collection = all_collected.duplicate(true)
	owner.owned_lingpets = all_collected.duplicate(true)
	owner.owned_ringpets = all_collected.duplicate(true)
	var state := LingpetCollectionState.new()
	_expect(state.should_spawn_egg(owner), "collection completion must not suppress later eggs")
	var hatch_pet_id := state.pick_hatch_pet_id(owner)
	_expect(hatch_pet_id != "", "collection-complete egg must still choose an enabled hatch identity")
	_expect(state.is_absorb_only_candidate(owner, hatch_pet_id), "collection-complete hatch must be marked absorb-only")
	var choice := LingpetOverflowChoiceState.new()
	choice.begin_main_overflow(hatch_pet_id, true)
	var plan: Dictionary = LingpetOverflowReplacePlan.new().consume(owner, 0, choice, state)
	_expect(not bool(plan.get("handled", false)), "absorb-only hatch must reject replacement")


func _verify_two_choice_and_absorb_source_localization() -> void:
	for language in ["ko", "en", "zh", "ja", "es", "pt-BR", "ru"]:
		var choice_copy := LingpetOverflowChoiceOverlayHost.get_copy_for_language_for_tests(language)
		_expect(str(choice_copy.get("replace", "")).strip_edges() != "", "%s must localize Replace" % language)
		_expect(str(choice_copy.get("absorb", "")).strip_edges() != "", "%s must localize Absorb" % language)
		_expect(str(choice_copy.get("absorb_desc", "")).strip_edges() != "", "%s must explain the enhancement reward" % language)
		_expect(str(choice_copy.get("base_note", "")).strip_edges() != "", "%s must explain when individual bonuses are rolled" % language)
		_expect(str(choice_copy.get("passive_note", "")).strip_edges() != "", "%s must explain the shared passive roll" % language)
		_expect(str(choice_copy.get("passive_pending_title", "")).strip_edges() != "", "%s must label the pending passive slot" % language)
		_expect(str(choice_copy.get("compare_title", "")).strip_edges() != "", "%s must localize the comparison title" % language)
		_expect(str(choice_copy.get("current_guardian", "")).strip_edges() != "", "%s must label the current guardian" % language)
		_expect(str(choice_copy.get("replacement_guardian", "")).strip_edges() != "", "%s must label the replacement guardian" % language)
		_expect(str(choice_copy.get("cancel_action", "")).strip_edges() != "", "%s must localize the comparison cancel button" % language)
		_expect(str(choice_copy.get("confirm_question", "")).find("%s") >= 0, "%s replacement confirmation must include the incoming guardian name" % language)
		var result_copy := LingpetGuardianEnhanceOfferEngine.get_result_copy_for_language_for_tests(language)
		_expect(str(result_copy.get("source_absorb", "")).strip_edges() != "", "%s must localize the absorption result source" % language)


func _verify_new_guardian_portrait_and_tooltip_payload() -> void:
	var owner := FakeOwner.new()
	var collection_state := LingpetCollectionState.new()
	collection_state.sync_from_owner(owner)
	var choice := LingpetOverflowChoiceState.new()
	choice.begin_main_overflow("rahoset")
	choice.activate_after_cutin()
	var snapshot: Dictionary = choice.build_snapshot(collection_state)
	var preview_profile := LingpetCurrentProfile.new()
	preview_profile.set_pet_id("rahoset")
	var preview_loadout := LingpetCatalog.build_default_loadout("rahoset")
	preview_profile.set_loadout(
		str(preview_loadout.get("active_skill_id", "")),
		"",
		int(preview_loadout.get("active_skill_level", 1)),
		0
	)
	var preview_cooldown := float(preview_profile.get_active_skill(0).get("cooldown", 0.0))
	_expect(is_equal_approx(preview_cooldown, 24.0), "Rahoset overflow profile should apply the final guardian cooldown scale")
	var expected_art_path := LingpetCatalog.get_visual_path("rahoset", "cutin_art")
	_expect(str(snapshot.get("pending_art_path", "")) == expected_art_path, "overflow snapshot must expose the acquired guardian portrait path")
	_expect(FileAccess.file_exists(expected_art_path), "overflow guardian portrait path must point to a real source asset")
	var stats: Dictionary = snapshot.get("pending_stats", {}) as Dictionary
	_expect(is_equal_approx(float(stats.get("appearance_rate", 0.0)), 0.30), "overflow tooltip payload must expose Rahoset's appearance rate")
	_expect(is_equal_approx(float(stats.get("hit_gauge_gain", 0.0)), 40.0), "overflow tooltip payload must expose guardian vigor gain")
	_expect(str(snapshot.get("replacement_skill_name", "")) == "모래감옥", "overflow tooltip payload must expose the acquired guardian's active skill")
	_expect(str(snapshot.get("replacement_skill_description", "")).find("보스 주위") >= 0, "overflow tooltip payload must include the active skill description")
	_expect(is_equal_approx(float(snapshot.get("replacement_skill_cooldown", 0.0)), preview_cooldown), "overflow tooltip payload must expose the profile-resolved active cooldown")
	var info := LingpetOverflowChoiceOverlayHost.build_guardian_info_for_tests(snapshot, "ko")
	_expect(str(info.get("title", "")) == "라호세트", "guardian art tooltip must use the acquired guardian name")
	_expect((info.get("stat_rows", []) as Array).size() >= 4, "guardian art tooltip must present the base stat rows")
	_expect(str(info.get("skill_title", "")).find("모래감옥") >= 0, "guardian art tooltip must present the active skill name")
	_expect(str(info.get("skill_icon_path", "")) == str(snapshot.get("replacement_skill_icon_path", "")), "guardian art tooltip must preserve the active skill icon")
	_expect(str(info.get("skill_description", "")).find("감옥") >= 0, "guardian art tooltip must present the active skill details")
	_expect(str(info.get("passive_title", "")).strip_edges() != "", "guardian art tooltip must visibly label the pending passive slot")
	_expect(str(info.get("passive_note", "")).find("공용 패시브") >= 0, "guardian art tooltip must explain the random passive")
	var art_rect := LingpetOverflowChoiceOverlayHost.new().get_new_pet_art_rect_for_tests(Vector2(760.0, 750.0))
	_expect(art_rect.size.x >= 96.0 and art_rect.size.y >= 90.0, "new guardian portrait must have a clearly visible hover target")


func _verify_production_overflow_icon_prewarm_wiring() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/core/battle_boot_resource_prewarm_controller.gd")
	var step_start := source.find("func _run_stage_runtime_prewarm_step(")
	var step_end := source.find("\nfunc ", step_start + 1)
	var step_body := source.substr(step_start, step_end - step_start)
	var host_lookup := step_body.find('"lingpet_overflow_choice_overlay_host"')
	var host_prewarm := step_body.find("overflow_choice_host.prewarm_assets()", host_lookup)
	_expect(host_lookup >= 0, "battle boot prewarm must instantiate the production overflow choice host")
	_expect(host_prewarm > host_lookup, "battle boot prewarm must warm overflow active/passive skill icons before draw")


func _verify_two_choice_input_routes() -> void:
	var owner := FakeOwner.new()
	var runtime := FakeChoiceRuntime.new()
	var host := LingpetOverflowChoiceOverlayHost.new()
	var key_one := InputEventKey.new()
	key_one.pressed = true
	key_one.keycode = KEY_1
	_expect(host.handle_input(key_one, runtime, owner, null, Vector2(760.0, 750.0)), "Replace shortcut must be consumed")
	_expect(host.get_phase_for_tests() == LingpetOverflowChoiceOverlayHost.PHASE_COMPARE, "first Replace action must open the comparison screen")
	_expect(runtime.replace_count == 0 and runtime.absorb_count == 0, "opening replacement comparison must not mutate the roster")
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	_expect(host.handle_input(escape, runtime, owner, null, Vector2(760.0, 750.0)), "escape must be consumed")
	_expect(host.get_phase_for_tests() == LingpetOverflowChoiceOverlayHost.PHASE_CHOICE, "comparison escape must return to the initial choice")
	_expect(runtime.replace_count == 0 and runtime.absorb_count == 0, "comparison cancellation must be a complete no-op")
	_expect(host.handle_input(key_one, runtime, owner, null, Vector2(760.0, 750.0)), "comparison reopen must be consumed")
	var enter := InputEventKey.new()
	enter.pressed = true
	enter.keycode = KEY_ENTER
	_expect(host.handle_input(enter, runtime, owner, null, Vector2(760.0, 750.0)), "comparison Replace button must be consumed")
	_expect(host.get_phase_for_tests() == LingpetOverflowChoiceOverlayHost.PHASE_CONFIRM, "comparison Replace must open the second confirmation")
	_expect(runtime.replace_count == 0, "second confirmation must appear before the roster commit")
	_expect(host.handle_input(escape, runtime, owner, null, Vector2(760.0, 750.0)), "confirmation escape must be consumed")
	_expect(host.get_phase_for_tests() == LingpetOverflowChoiceOverlayHost.PHASE_COMPARE, "confirmation escape must return to comparison")
	_expect(runtime.replace_count == 0 and runtime.absorb_count == 0, "confirmation cancellation must be a complete no-op")
	_expect(host.handle_input(enter, runtime, owner, null, Vector2(760.0, 750.0)), "comparison Replace retry must be consumed")
	_expect(host.handle_input(enter, runtime, owner, null, Vector2(760.0, 750.0)), "final confirmation must be consumed")
	_expect(runtime.replace_count == 1 and runtime.absorb_count == 0, "only final confirmation may call production replacement")
	var mouse_runtime := FakeChoiceRuntime.new()
	var mouse_host := LingpetOverflowChoiceOverlayHost.new()
	_expect(mouse_host.handle_input(key_one, mouse_runtime, owner, null, Vector2(760.0, 750.0)), "mouse cancellation fixture must open comparison")
	var compare_layout := mouse_host.get_compare_layout_for_tests(Vector2(760.0, 750.0))
	var cancel_click := InputEventMouseButton.new()
	cancel_click.pressed = true
	cancel_click.button_index = MOUSE_BUTTON_LEFT
	cancel_click.position = (compare_layout.get("secondary_button", Rect2()) as Rect2).get_center()
	_expect(mouse_host.handle_input(cancel_click, mouse_runtime, owner, null, Vector2(760.0, 750.0)), "comparison cancel button must be consumed")
	_expect(mouse_host.get_phase_for_tests() == LingpetOverflowChoiceOverlayHost.PHASE_CHOICE, "comparison cancel button must return to the initial choice")
	_expect(mouse_runtime.replace_count == 0 and mouse_runtime.absorb_count == 0, "comparison cancel button must not mutate the roster")
	_expect(mouse_host.handle_input(key_one, mouse_runtime, owner, null, Vector2(760.0, 750.0)), "mouse confirmation fixture must reopen comparison")
	var replace_click := InputEventMouseButton.new()
	replace_click.pressed = true
	replace_click.button_index = MOUSE_BUTTON_LEFT
	replace_click.position = (compare_layout.get("primary_button", Rect2()) as Rect2).get_center()
	_expect(mouse_host.handle_input(replace_click, mouse_runtime, owner, null, Vector2(760.0, 750.0)), "comparison Replace button click must be consumed")
	_expect(mouse_host.get_phase_for_tests() == LingpetOverflowChoiceOverlayHost.PHASE_CONFIRM, "comparison Replace button click must open confirmation")
	_expect(mouse_runtime.replace_count == 0, "comparison Replace button click must not commit early")
	var confirm_layout := mouse_host.get_confirm_layout_for_tests(Vector2(760.0, 750.0))
	var confirm_cancel_click := InputEventMouseButton.new()
	confirm_cancel_click.pressed = true
	confirm_cancel_click.button_index = MOUSE_BUTTON_LEFT
	confirm_cancel_click.position = (confirm_layout.get("secondary_button", Rect2()) as Rect2).get_center()
	_expect(mouse_host.handle_input(confirm_cancel_click, mouse_runtime, owner, null, Vector2(760.0, 750.0)), "confirmation cancel button must be consumed")
	_expect(mouse_host.get_phase_for_tests() == LingpetOverflowChoiceOverlayHost.PHASE_COMPARE, "confirmation cancel button must return to comparison")
	_expect(mouse_runtime.replace_count == 0 and mouse_runtime.absorb_count == 0, "confirmation cancel button must be a complete no-op")
	var escape_runtime := FakeChoiceRuntime.new()
	var escape_host := LingpetOverflowChoiceOverlayHost.new()
	_expect(escape_host.handle_input(escape, escape_runtime, owner, null, Vector2(760.0, 750.0)), "initial escape must be consumed")
	_expect(escape_runtime.absorb_count == 1, "initial escape must preserve the production absorption shortcut")
	var absorb_only_runtime := FakeChoiceRuntime.new()
	absorb_only_runtime.snapshot["absorb_only"] = true
	var absorb_only_host := LingpetOverflowChoiceOverlayHost.new()
	_expect(absorb_only_host.handle_input(key_one, absorb_only_runtime, owner, null, Vector2(760.0, 750.0)), "absorb-only Replace shortcut must be consumed")
	_expect(absorb_only_runtime.replace_count == 0 and absorb_only_runtime.absorb_count == 1, "absorb-only hatch must not reach replacement even through the Replace shortcut")


func _verify_retired_cycle_source_is_absent() -> void:
	var router_source := FileAccess.get_file_as_string("res://scripts/core/battle_lingpet_interaction_input_router.gd")
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	_expect(router_source.find("LINGPET_CYCLE_KEY") < 0 and router_source.find("cycle_lingpet_slot") < 0, "battle input router must retire L/Shift+L cycling")
	_expect(runtime_source.find("func cycle_lingpet_slot") < 0, "one-guardian runtime must retire cycle API")


func _verify_round_reset_closes_absorb_presentation() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var reset_start := runtime_source.find("func reset_round(")
	var reset_end := runtime_source.find("\nfunc ", reset_start + 1)
	var reset_body := runtime_source.substr(reset_start, reset_end - reset_start)
	var absorb_at := reset_body.find("commit_overflow_absorb(owner, registry)")
	var close_after_absorb_at := reset_body.find("cancel_guardian_enhance_cutin(registry)", absorb_at + 1)
	_expect(absorb_at >= 0, "round reset must settle an unanswered hatch through absorption")
	_expect(close_after_absorb_at > absorb_at, "round reset must close the compact enhancement presentation reopened by absorption")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
