extends SceneTree

const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const EggRuntimeSmoke := preload("res://tests/lingpet_egg_runtime_smoke.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_item_egg_deploys_while_companion_active()
	_verify_item_egg_hatch_rolls_loadout()
	_verify_item_egg_replace_absorb_choice()
	_verify_item_egg_reset_resolves_to_absorb()
	_verify_dead_legacy_seal_bodies_are_gone()
	ProjectResourceLoader.clear_caches()
	if _failures.is_empty():
		print("lingpet_one_guardian_item_egg_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_item_egg_deploys_while_companion_active() -> void:
	var fixture := _make_fixture()
	var runtime: Object = fixture.runtime
	var owner: Object = fixture.owner
	var registry: Object = fixture.registry
	_expect(runtime.can_offer_egg_item(owner, registry), "an occupied one-guardian roster must still offer another egg")
	_expect(runtime.deploy_egg_from_item(owner, registry), "the production item path must deploy a coexisting egg while the guardian is active")
	_expect(str(owner.lingpet_state) == "companion", "coexisting egg deployment must not suspend the current guardian")
	_expect(str(owner.active_lingpet_id) == "maribo", "coexisting egg deployment must keep the current guardian identity")
	_expect(runtime.is_item_egg_active(), "coexisting item egg must remain active beside the guardian")
	var pending_pet_id := str(runtime.get_item_egg_pet_id())
	_expect(pending_pet_id != "" and pending_pet_id != "maribo", "coexisting item egg must roll another catalog identity")
	_expect(not runtime.can_offer_egg_item(owner, registry), "a second egg offer must stay blocked during incubation")
	_expect(not runtime.deploy_egg_from_item(owner, registry), "a second item egg must not deploy during incubation")
	_cleanup(runtime)


func _verify_item_egg_hatch_rolls_loadout() -> void:
	var saw_level_two_or_more := false
	var saw_none_or_one := false
	for _attempt in range(16):
		var fixture := _make_fixture()
		var runtime: Object = fixture.runtime
		var owner: Object = fixture.owner
		var pending_pet_id := _open_item_egg_choice(runtime, owner, fixture.registry)
		var preview_snapshot: Dictionary = runtime.get_overflow_choice_snapshot()
		var preview_guardian: Dictionary = preview_snapshot.get("replacement_guardian", {}) as Dictionary
		var preview_loadout: Dictionary = runtime._loadout_state.get_stored_loadout(pending_pet_id)
		var active_level := int(preview_loadout.get("active_skill_level", -1))
		var passive_level := int(preview_loadout.get("passive_skill_level", -1))
		var active_id := str(preview_loadout.get("active_skill_id", ""))
		var passive_id := str(preview_loadout.get("passive_skill_id", ""))
		var expected_active_icon := ""
		if active_id != "":
			expected_active_icon = str(LingpetCatalog.get_active_skill(pending_pet_id, active_id, active_level).get("icon_texture_path", ""))
		var expected_passive_icon := ""
		if passive_id != "":
			expected_passive_icon = str(LingpetCatalog.get_passive_skill(pending_pet_id, passive_id, passive_level).get("icon_texture_path", ""))
		_expect(str(preview_guardian.get("active_skill_icon_path", "")) == expected_active_icon, "item-egg preview must mirror the rolled active icon path")
		_expect(str(preview_guardian.get("passive_skill_icon_path", "")) == expected_passive_icon, "item-egg preview must mirror the rolled passive icon path")
		_expect(runtime.commit_overflow_replace(0, owner, fixture.registry), "item-egg Replace must commit through live slot zero")
		var loadouts: Dictionary = owner.lingpet_loadouts as Dictionary
		_expect(loadouts.has(pending_pet_id), "item-egg Replace must persist the incoming guardian loadout")
		var loadout: Dictionary = loadouts.get(pending_pet_id, {}) as Dictionary
		_expect(str(loadout.get("active_skill_id", "")) == str(preview_loadout.get("active_skill_id", "")), "item-egg confirmation must keep the previewed active skill")
		_expect(str(loadout.get("passive_skill_id", "")) == str(preview_loadout.get("passive_skill_id", "")), "item-egg confirmation must keep the previewed passive skill")
		active_level = int(loadout.get("active_skill_level", -1))
		passive_level = int(loadout.get("passive_skill_level", -1))
		_expect(active_level >= 0 and active_level <= 3, "item-egg active level must come from the 0..3 hatch roll")
		_expect(passive_level >= 0 and passive_level <= 3, "item-egg passive level must come from the 0..3 hatch roll")
		saw_level_two_or_more = saw_level_two_or_more or active_level >= 2 or passive_level >= 2
		saw_none_or_one = saw_none_or_one or active_level <= 1 or passive_level <= 1
		_cleanup(runtime)
	_expect(saw_level_two_or_more, "production item-egg Replace must surface a rolled level above the old Lv.1 fallback")
	_expect(saw_none_or_one, "production item-egg Replace must preserve low/empty hatch outcomes")


func _verify_item_egg_replace_absorb_choice() -> void:
	var replace_fixture := _make_fixture()
	var replace_pending := _open_item_egg_choice(
		replace_fixture.runtime,
		replace_fixture.owner,
		replace_fixture.registry
	)
	# Same duration contract as the main-egg route: a new guardian arrives at 100%.
	replace_fixture.runtime._guardian_run_state.set_duration_pool_for_tests(11.0, 44.0)
	_expect(replace_fixture.runtime.commit_overflow_replace(0, replace_fixture.owner, replace_fixture.registry), "item-egg Replace choice must succeed")
	_expect((replace_fixture.owner.lingpet_owned_pet_ids as Array) == [replace_pending], "item-egg Replace must leave exactly the incoming live guardian")
	_expect(bool(replace_fixture.owner.lingpet_collection.get("maribo", false)), "item-egg Replace must preserve the outgoing guardian in collection history")
	_expect(is_equal_approx(replace_fixture.runtime.get_duration_pool_current(), 44.0), "item-egg Replace must refill the run-shared duration pool to its maximum")
	_expect(is_equal_approx(replace_fixture.runtime.get_duration_pool_max(), 44.0), "item-egg Replace must preserve the once-per-run duration maximum")
	_expect(replace_fixture.runtime.get_duration_pool_pct() == 100, "item-egg Replace must publish a full duration pool to the HUD")
	_cleanup(replace_fixture.runtime)

	var absorb_fixture := _make_fixture()
	var absorb_pending := _open_item_egg_choice(
		absorb_fixture.runtime,
		absorb_fixture.owner,
		absorb_fixture.registry
	)
	_expect(absorb_fixture.runtime.commit_overflow_absorb(absorb_fixture.owner, absorb_fixture.registry), "item-egg Absorb choice must succeed")
	_expect((absorb_fixture.owner.lingpet_owned_pet_ids as Array) == ["maribo"], "item-egg Absorb must keep the current live guardian")
	_expect(bool(absorb_fixture.owner.lingpet_collection.get(absorb_pending, false)), "item-egg Absorb must preserve the incoming identity in collection history")
	var result: Dictionary = absorb_fixture.runtime.get_guardian_enhance_last_result_for_tests()
	_expect(bool(result.get("accepted", false)), "item-egg Absorb must grant exactly one accepted Guardian Enhancement")
	_expect(str(result.get("trigger_source", "")) == "absorb", "item-egg Absorb must use the shared absorption enhancement source")
	_cleanup(absorb_fixture.runtime)


func _verify_item_egg_reset_resolves_to_absorb() -> void:
	var fixture := _make_fixture()
	var pending_pet_id := _open_item_egg_choice(fixture.runtime, fixture.owner, fixture.registry)
	fixture.runtime.reset_round({"registry": fixture.registry})
	_expect(not fixture.runtime.is_overflow_choice_active(), "round reset must resolve an unanswered item-egg choice")
	_expect(not fixture.runtime.is_guardian_enhance_cutin_active(), "round reset must not leave the absorption enhancement panel reopened")
	fixture.runtime.update(0.0, fixture.owner, fixture.registry)
	_expect((fixture.owner.lingpet_owned_pet_ids as Array) == ["maribo"], "owner-less reset absorption must restore the current one-guardian roster")
	_expect(
		bool(fixture.owner.lingpet_collection.get(pending_pet_id, false)),
		"owner-less reset absorption must republish the absorbed identity into collection history (pending=%s, owner=%s, internal=%s)" % [
			pending_pet_id,
			str(fixture.owner.lingpet_collection),
			str((fixture.runtime.get("_collection_state") as Object).get_collected_pet_ids()),
		]
	)
	_cleanup(fixture.runtime)


func _verify_dead_legacy_seal_bodies_are_gone() -> void:
	var legacy_source := FileAccess.get_file_as_string("res://tests/lingpet_egg_runtime_smoke.gd")
	for dead_name in [
		"_verify_lingpet_egg_deploys_while_companion_active",
		"_verify_item_egg_hatch_rolls_loadout",
		"_verify_lingpet_egg_overflow_replace_release_choice",
		"_verify_lingpet_egg_overflow_reset_resolves_to_release",
		"_verify_lingpet_battle_slot_model",
		"_verify_lingpet_skill_cooldown_survives_slot_switch",
		"_verify_lingpet_slot_switch_clears_owner_locked_skill_flags",
		"_verify_lingpet_skill_waits_for_switch_transition",
	]:
		_expect(legacy_source.find("func %s" % dead_name) < 0, "retired empty-GREEN body must be absent: %s" % dead_name)
	var live_source := FileAccess.get_file_as_string("res://tests/lingpet_one_guardian_item_egg_smoke.gd")
	for live_name in [
		"_verify_item_egg_deploys_while_companion_active",
		"_verify_item_egg_hatch_rolls_loadout",
		"_verify_item_egg_replace_absorb_choice",
		"_verify_item_egg_reset_resolves_to_absorb",
	]:
		_expect(live_source.count(live_name) >= 2, "retargeted item-egg leg must have both an _init call and body: %s" % live_name)
	var router_source := FileAccess.get_file_as_string("res://tests/battle_lingpet_interaction_input_router_owner_smoke.gd")
	var hud_source := FileAccess.get_file_as_string("res://tests/lingpet_battle_slot_hud_removed_smoke.gd")
	_expect(router_source.find("func _verify_slot_cycle_directions") < 0, "retired slot-cycle direction body must stay deleted")
	_expect(hud_source.find("func _verify_lingpet_cycle_key_avoids_item_number_keys") < 0, "retired L-cycle key body must stay deleted")


func _make_fixture() -> Dictionary:
	var owner := EggRuntimeSmoke.FakeOwner.new()
	owner.ai_mode = "champion"
	var runtime: Object = LingpetEggRuntime.new()
	var registry: Object = EggRuntimeSmoke.FakeRegistry.new({"lingpet_egg_runtime": runtime})
	_expect(runtime.debug_grant_and_activate_pet("maribo", owner, false, "", "", registry), "fixture must activate the current guardian")
	return {"owner": owner, "runtime": runtime, "registry": registry}


func _open_item_egg_choice(runtime: Object, owner: Object, registry: Object) -> String:
	_expect(runtime.deploy_egg_from_item(owner, registry), "fixture must deploy a coexisting item egg")
	var pending_pet_id := str(runtime.get_item_egg_pet_id())
	owner.ball_active = true
	var hit_guard := 0
	while runtime.is_item_egg_active() and hit_guard < 12:
		var egg_pos: Vector2 = (runtime.get("_item_egg_state") as Object).pos
		_register_hit(runtime, owner, egg_pos, hit_guard + 1, registry)
		hit_guard += 1
	_expect(not runtime.is_item_egg_active(), "item egg must hatch within its 2..4-hit contract")
	_expect(runtime.is_acquire_cutin_active(), "item-egg hatch must open the acquisition cut-in")
	_finish_acquire_cutin(runtime, registry)
	runtime.update(0.0, owner, registry)
	_expect(runtime.is_overflow_choice_active(), "one occupied live slot must route item-egg hatch to Replace / Absorb")
	_expect(str(runtime.get_overflow_choice_snapshot().get("pending_pet_id", "")) == pending_pet_id, "overflow choice must retain the hatched item-egg identity")
	return pending_pet_id


func _register_hit(runtime: Object, owner: Object, egg_pos: Vector2, index: int, registry: Object) -> void:
	owner.ball_pos = egg_pos + Vector2(0.0, -90.0)
	owner.ball_vel = Vector2(0.0, 12.0)
	runtime.update(0.21, owner, registry)
	owner.ball_pos = egg_pos + Vector2(float(index), -8.0)
	owner.ball_vel = Vector2(0.0, 12.0)
	runtime.update(0.0, owner, registry)


func _finish_acquire_cutin(runtime: Object, registry: Object) -> void:
	runtime.advance_acquire_cutin(3.0, registry)
	if runtime.is_acquire_cutin_awaiting_dismiss():
		runtime.begin_acquire_cutin_dismiss(registry)
	var guard := 0
	while runtime.is_acquire_cutin_active() and guard < 700:
		runtime.advance_acquire_cutin(0.1, registry)
		guard += 1
	_expect(not runtime.is_acquire_cutin_active(), "fixture must fully dismiss the acquisition cut-in")


func _cleanup(runtime: Object) -> void:
	if runtime != null:
		runtime.reset_for_tests()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
