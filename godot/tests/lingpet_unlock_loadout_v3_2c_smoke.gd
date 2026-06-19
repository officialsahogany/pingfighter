extends SceneTree

const LingpetAffinityState := preload("res://scripts/lingpet/lingpet_affinity_state.gd")
const LingpetAffinityStore := preload("res://scripts/lingpet/lingpet_affinity_store.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const LingpetLoadoutState := preload("res://scripts/lingpet/lingpet_loadout_state.gd")
const CharacterInfoOverlayLingpetPresenter := preload("res://scripts/hud/character_info_overlay_lingpet_presenter.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")


class FakeOwner:
	extends RefCounted

	var values: Dictionary = {}

	func _init() -> void:
		values = {
			"ai_mode": "junior league",
			"selected_character_type": "smasher",
			"current_stage": 1,
			"arena_mode_enabled": false,
			"weather_type": "",
			"player_pos": Vector2(263.75, 675.0),
			"player_paddle_width": 232.5,
			"player_paddle_height": 75.0,
			"boss_pos": Vector2(330.0, 25.0),
			"boss_vel": 0.0,
			"boss_paddle_width": 100.0,
			"boss_hitbox_height": 40.0,
			"ball_active": false,
			"ball_pos": Vector2.ZERO,
			"ball_pos_prev": Vector2.ZERO,
			"ball_vel": Vector2.ZERO,
			"ball_serve_origin": "",
			"ball_size": 28.6,
			"special_gauge": 100.0,
			"special_gauge_max": 500.0,
			"lingpet_id": "",
			"active_lingpet_id": "",
			"current_lingpet_id": "",
			"lingpet_state": "none",
			"ringpet_state": "none",
			"lingpet_owned_pet_ids": [],
			"owned_lingpet_ids": [],
			"owned_ringpet_ids": [],
			"lingpet_collection": {},
			"ringpet_collection": {},
			"owned_lingpets": {},
			"owned_ringpets": {},
			"lingpet_loadouts": {},
			"ringpet_loadouts": {},
			"owned_lingpet_loadouts": {},
			"owned_ringpet_loadouts": {},
			"lingpet_slots": ["", "", ""],
			"ringpet_slots": ["", "", ""],
			"lingpet_slot_pet_ids": ["", "", ""],
			"ringpet_slot_pet_ids": ["", "", ""],
			"lingpet_active_slot_index": 0,
			"ringpet_active_slot_index": 0,
			"lingpet_active_skill_id": "",
			"ringpet_active_skill_id": "",
			"lingpet_active_skill_level": 0,
			"ringpet_active_skill_level": 0,
			"lingpet_second_active_skill_id": "",
			"ringpet_second_active_skill_id": "",
			"lingpet_second_active_skill_level": 0,
			"ringpet_second_active_skill_level": 0,
			"lingpet_passive_skill_id": "",
			"ringpet_passive_skill_id": "",
			"lingpet_passive_skill_level": 0,
			"ringpet_passive_skill_level": 0,
			"lingpet_second_passive_skill_id": "",
			"ringpet_second_passive_skill_id": "",
			"lingpet_second_passive_skill_level": 0,
			"ringpet_second_passive_skill_level": 0,
		}

	func _get(property: StringName) -> Variant:
		return values.get(str(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		values[str(property)] = value
		return true

	func value_of(key: String) -> Variant:
		return values.get(key, null)


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(next_instances: Dictionary = {}) -> void:
		instances = next_instances

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		return value as Object if value is Object else null


var _failures: Array[String] = []
var _runtime_refs: Array[Object] = []


func _init() -> void:
	_verify_catalog_no_skill_and_lumion_pool()
	_verify_no_skill_activation_snapshot()
	_verify_fresh_hatch_keeps_zero_skill_loadout()
	_verify_empty_primary_set_does_not_reinject_defaults()
	_verify_legacy_one_slot_loadout_survives_v3_2c_normalization()
	_verify_primary_unlock_reconcile()
	_verify_single_entry_pool_resolve()
	_verify_second_unlock_flags_fill_slot_one()
	_verify_debug_forced_skill_reconcile_stays_sticky()
	_verify_headstart_rederives_primary_unlock()
	_verify_persisted_unlock_choice_overrides_auto_resolve()
	_verify_stale_persisted_unlock_choice_drops_to_auto_resolve()
	_verify_resolved_unlock_choice_store_roundtrip_and_threading()
	_verify_maribo_headstart_rederives_starter_unlock()
	_verify_active_unlock_options_use_raw_first_two_cap()
	_verify_tab_unlock_options_sequential_queue_count()
	_verify_tab_unlock_options_and_commit_lock()
	_verify_tab_unlock_options_filter_single_candidate()
	_cleanup_runtimes()
	ProjectResourceLoader.clear_caches()

	if _failures.is_empty():
		print("lingpet_unlock_loadout_v3_2c_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_catalog_no_skill_and_lumion_pool() -> void:
	var empty_explicit := LingpetCatalog.get_active_skill("lumion", "", 1)
	_expect(empty_explicit.is_empty(), "explicit empty active id should not fall back to Lumion pool[0]")
	var hatch_loadout := LingpetCatalog.pick_skill_loadout("lumion")
	_expect_str(str(hatch_loadout.get("active_skill_id", "")), "", "new hatch loadout should start with no active skill")
	_expect_str(str(hatch_loadout.get("passive_skill_id", "")), "", "new hatch loadout should start with no passive skill")
	_expect_eq((hatch_loadout.get("active_skill_ids", []) as Array).size(), 0, "new hatch loadout should keep active ids empty")
	_expect_eq((hatch_loadout.get("passive_skill_ids", []) as Array).size(), 0, "new hatch loadout should keep passive ids empty")
	var lumion_active_ids := _skill_ids(LingpetCatalog.get_active_skill_pool("lumion"))
	_expect(lumion_active_ids.has("lumion_thunder_orb"), "Lumion active pool should keep Thunder Orb")
	_expect(lumion_active_ids.has("lumion_solar_bolt"), "Lumion active pool should expose Solar Bolt as an unlock candidate")
	var solar_entry := LingpetCatalog.get_active_skill_entry("lumion_solar_bolt")
	_expect_str(str(solar_entry.get("runtime_kind", "")), "solar_bolt", "Solar Bolt catalog entry should expose runtime_kind")
	_expect(str(solar_entry.get("card_texture_path", "")).ends_with("lumion_solar_bolt_skillcard_imagegen_v1.png"), "Solar Bolt should use its dedicated golden skill-card art")
	_expect(str(solar_entry.get("icon_texture_path", "")).ends_with("lumion_solar_bolt_skill_icon_imagegen_v1.png"), "Solar Bolt should use its dedicated golden skill icon")
	_expect(ProjectResourceLoader.texture_resource_exists(str(solar_entry.get("card_texture_path", ""))), "Solar Bolt dedicated card path should be loadable")
	_expect(ProjectResourceLoader.texture_resource_exists(str(solar_entry.get("icon_texture_path", ""))), "Solar Bolt dedicated icon path should be loadable")


func _verify_no_skill_activation_snapshot() -> void:
	var fixture := _activate_pet("lumion")
	var runtime: Object = fixture.get("runtime")
	var owner: FakeOwner = fixture.get("owner")
	var snapshot: Dictionary = runtime.get_snapshot()
	var loadout: Dictionary = snapshot.get("lingpet_loadouts", {}).get("lumion", {}) as Dictionary
	_expect_str(str(snapshot.get("companion_skill_id", "")), "", "no-skill activation snapshot should keep companion_skill_id empty")
	_expect_str(str(snapshot.get("companion_skill_name", "")), "", "no-skill activation snapshot should keep companion_skill_name empty")
	_expect_str(str(owner.value_of("lingpet_active_skill_id")), "", "no-skill activation owner active id should stay empty")
	_expect_str(str(owner.value_of("lingpet_passive_skill_id")), "", "no-skill activation owner passive id should stay empty")
	_expect_eq((loadout.get("active_skill_ids", []) as Array).size(), 0, "no-skill activation loadout should keep active ids empty")
	_expect_eq((loadout.get("passive_skill_ids", []) as Array).size(), 0, "no-skill activation loadout should keep passive ids empty")
	_expect_eq(int(snapshot.get("companion_skill_level", 0)), 0, "no-skill activation snapshot should keep active level zero")
	_expect_eq(int(snapshot.get("companion_passive_skill_level", 0)), 0, "no-skill activation snapshot should keep passive level zero")


func _verify_fresh_hatch_keeps_zero_skill_loadout() -> void:
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new({})
	var runtime: Object = LingpetEggRuntime.new()
	_runtime_refs.append(runtime)
	runtime.update(0.0, owner, registry)
	var egg_pos: Vector2 = owner.value_of("lingpet_egg_pos")
	_expect(egg_pos != Vector2.ZERO, "fresh hatch fixture should spawn a field egg")
	_register_hit(runtime, owner, registry, egg_pos)
	var hatched_pet_id := str(owner.value_of("active_lingpet_id"))
	_expect(hatched_pet_id != "", "fresh hatch should publish a hatched pet id")
	var loadouts: Dictionary = owner.value_of("lingpet_loadouts") as Dictionary
	var hatch_loadout: Dictionary = loadouts.get(hatched_pet_id, {}) as Dictionary
	_expect_str(str(hatch_loadout.get("active_skill_id", "")), "", "fresh hatch should keep primary active empty until affinity reconcile")
	_expect_str(str(hatch_loadout.get("passive_skill_id", "")), "", "fresh hatch should keep primary passive empty until affinity reconcile")
	_expect_eq((hatch_loadout.get("active_skill_ids", []) as Array).size(), 0, "fresh hatch should keep active ids empty")
	_expect_eq((hatch_loadout.get("passive_skill_ids", []) as Array).size(), 0, "fresh hatch should keep passive ids empty")
	_expect_eq(int(hatch_loadout.get("active_slot_count", -1)), 0, "fresh hatch should keep active slot count at zero")
	_expect_eq(int(hatch_loadout.get("passive_slot_count", -1)), 0, "fresh hatch should keep passive slot count at zero")
	_expect_str(str(owner.value_of("lingpet_active_skill_id")), "", "fresh hatch owner active id should stay empty before reconcile")
	_expect_str(str(owner.value_of("lingpet_passive_skill_id")), "", "fresh hatch owner passive id should stay empty before reconcile")


func _verify_empty_primary_set_does_not_reinject_defaults() -> void:
	var owner := FakeOwner.new()
	var state := LingpetLoadoutState.new()
	var loadout: Dictionary = state.set_pet_loadout(
		owner,
		"maribo",
		"",
		"",
		0,
		0
	)
	_expect_str(str(loadout.get("active_skill_id", "")), "", "empty primary write should not reinject default active")
	_expect_str(str(loadout.get("passive_skill_id", "")), "", "empty primary write should not reinject default passive")
	_expect_eq(int(loadout.get("active_slot_count", -1)), 0, "empty primary write should force active slot count zero")
	_expect_eq(int(loadout.get("passive_slot_count", -1)), 0, "empty primary write should force passive slot count zero")
	_expect_eq((loadout.get("active_skill_ids", []) as Array).size(), 0, "empty primary write should keep active ids empty")
	_expect_eq((loadout.get("passive_skill_ids", []) as Array).size(), 0, "empty primary write should keep passive ids empty")
	_expect_str(str(owner.value_of("lingpet_active_skill_id")), "", "empty primary owner active id should stay empty")
	_expect_str(str(owner.value_of("lingpet_passive_skill_id")), "", "empty primary owner passive id should stay empty")


func _verify_legacy_one_slot_loadout_survives_v3_2c_normalization() -> void:
	var owner := FakeOwner.new()
	owner.values["lingpet_loadouts"] = {
		"maribo": {
			"active_skill_id": "maribo_hydro_sphere",
			"active_skill_level": 2,
			"passive_skill_id": "lingpet_resonance_boost",
			"passive_skill_level": 3,
		},
	}
	var state := LingpetLoadoutState.new()
	state.sync_from_owner(owner)
	var loadout := state.get_loadout("maribo")
	_expect_str(str(loadout.get("active_skill_id", "")), "maribo_hydro_sphere", "pre-V3-2c one-slot active should survive normalization")
	_expect_eq(int(loadout.get("active_skill_level", 0)), 2, "pre-V3-2c one-slot active level should survive normalization")
	_expect_eq((loadout.get("active_skill_ids", []) as Array).size(), 1, "pre-V3-2c active array should contain only slot 0")
	_expect_str(str(loadout.get("second_active_skill_id", "")), "", "pre-V3-2c active should not invent a second slot")
	_expect_str(str(loadout.get("passive_skill_id", "")), "lingpet_resonance_boost", "pre-V3-2c one-slot passive should survive normalization")
	_expect_eq(int(loadout.get("passive_skill_level", 0)), 3, "pre-V3-2c one-slot passive level should survive normalization")
	_expect_eq((loadout.get("passive_skill_ids", []) as Array).size(), 1, "pre-V3-2c passive array should contain only slot 0")
	_expect_str(str(loadout.get("second_passive_skill_id", "")), "", "pre-V3-2c passive should not invent a second slot")


func _verify_primary_unlock_reconcile() -> void:
	var fixture := _activate_pet("lumion")
	var runtime: Object = fixture.get("runtime")
	var owner: FakeOwner = fixture.get("owner")
	var registry: Object = fixture.get("registry")
	_grant_round_commits(runtime, "lumion", 10, registry)
	runtime.update(0.0, owner, registry)
	_expect_eq(runtime.get_affinity_level("lumion"), 1, "ten round commits should reach Lv.1")
	var active_resolved := _resolved_choice(runtime, "lumion", "active")
	var lumion_active_ids := _skill_ids(LingpetCatalog.get_active_skill_pool("lumion"))
	_expect(lumion_active_ids.has(str(active_resolved.get("selected", ""))), "temporary auto-choice should pick one Lumion active candidate")
	_expect(_string_arrays_equal(active_resolved.get("candidates", []) as Array, lumion_active_ids), "active unlock candidates should be the real Lumion active pool")
	_expect_str(str(owner.value_of("lingpet_active_skill_id")), str(active_resolved.get("selected", "")), "active unlock reconcile should equip the auto-selected slot 0")
	_expect_str(str(owner.value_of("lingpet_second_active_skill_id")), "", "active unlock reconcile should leave slot 1 active empty")

	_grant_round_commits(runtime, "lumion", 15, registry)
	runtime.update(0.0, owner, registry)
	_expect_eq(runtime.get_affinity_level("lumion"), 2, "twenty-five round commits should reach Lv.2")
	var passive_resolved := _resolved_choice(runtime, "lumion", "passive")
	var passive_candidates: Array = passive_resolved.get("candidates", []) as Array
	_expect_eq(passive_candidates.size(), 2, "passive unlock should seed two deterministic common-passive candidates")
	_expect(passive_candidates.has(str(passive_resolved.get("selected", ""))), "temporary passive auto-choice should pick one passive candidate")
	_expect(_all_ids_in_pool(passive_candidates, _skill_ids(LingpetCatalog.get_passive_skill_pool("lumion"))), "passive candidates should come from the common passive pool")
	_expect_str(str(owner.value_of("lingpet_passive_skill_id")), str(passive_resolved.get("selected", "")), "passive unlock reconcile should equip the auto-selected slot 0")
	_expect_str(str(owner.value_of("lingpet_second_passive_skill_id")), "", "passive unlock reconcile should leave slot 1 passive empty")

	var repeat_fixture := _activate_pet("lumion")
	var repeat_runtime: Object = repeat_fixture.get("runtime")
	var repeat_owner: FakeOwner = repeat_fixture.get("owner")
	var repeat_registry: Object = repeat_fixture.get("registry")
	_grant_round_commits(repeat_runtime, "lumion", 25, repeat_registry)
	repeat_runtime.update(0.0, repeat_owner, repeat_registry)
	var repeat_passive := _resolved_choice(repeat_runtime, "lumion", "passive")
	_expect(_string_arrays_equal(passive_candidates, repeat_passive.get("candidates", []) as Array), "passive candidate seeding should be deterministic for the same pet")
	_expect(passive_candidates.has(str(repeat_passive.get("selected", ""))), "repeat passive auto-select should still pick one seeded passive candidate")


func _verify_single_entry_pool_resolve() -> void:
	var fixture := _activate_pet("milkring")
	var runtime: Object = fixture.get("runtime")
	var owner: FakeOwner = fixture.get("owner")
	var registry: Object = fixture.get("registry")
	_grant_round_commits(runtime, "milkring", 10, registry)
	runtime.update(0.0, owner, registry)
	var resolved := _resolved_choice(runtime, "milkring", "active")
	_expect_str(str(resolved.get("selected", "")), "milkring_milk_production", "single-entry active pool should resolve directly")
	_expect_eq((resolved.get("candidates", []) as Array).size(), 1, "single-entry resolve should record exactly one candidate")
	_expect(bool(resolved.get("single", false)), "single-entry resolve should mark the choice as single")
	_expect_str(str(owner.value_of("lingpet_active_skill_id")), "milkring_milk_production", "single-entry active resolve should equip slot 0")

	var state := LingpetAffinityState.new()
	var direct := state.resolve_single_unlock("nekuring", LingpetAffinityState.REWARD_TYPE_ACTIVE_UNLOCK, "nekuring_bone_barrier")
	_expect(bool(direct.get("accepted", false)), "resolve_single_unlock should accept a valid Nekuring active skill")
	var direct_resolved: Dictionary = state.get_resolved_unlock_choices("nekuring").get("active", {}) as Dictionary
	_expect_str(str(direct_resolved.get("selected", "")), "nekuring_bone_barrier", "direct single resolve should persist selected id")
	_expect_eq((direct_resolved.get("candidates", []) as Array).size(), 1, "direct single resolve should persist a one-id candidate list")


func _verify_second_unlock_flags_fill_slot_one() -> void:
	var fixture := _activate_pet("red_dragon")
	var runtime: Object = fixture.get("runtime")
	var owner: FakeOwner = fixture.get("owner")
	var registry: Object = fixture.get("registry")
	_grant_round_commits(runtime, "red_dragon", 635, registry)
	runtime.update(0.0, owner, registry)
	_expect_eq(runtime.get_affinity_level("red_dragon"), 25, "fixture should reach Lv.25")
	var rewards: Dictionary = runtime.get_affinity_rewards_for_tests("red_dragon")
	_expect(bool(rewards.get("second_active_unlocked", false)), "Lv.25 fixture should include second active unlock")
	_expect(bool(rewards.get("second_passive_unlocked", false)), "Lv.25 fixture should include second passive unlock")
	var loadout: Dictionary = runtime._loadout_state.get_loadout("red_dragon")
	_expect_eq((loadout.get("active_skill_ids", []) as Array).size(), 2, "V3-2c should write two active ids after second unlock flags")
	_expect_eq((loadout.get("passive_skill_ids", []) as Array).size(), 2, "V3-2c should write two passive ids after second unlock flags")
	var second_active_id := str(loadout.get("second_active_skill_id", ""))
	var second_passive_id := str(loadout.get("second_passive_skill_id", ""))
	_expect(second_active_id != "", "V3-2c should write second active id")
	_expect(second_passive_id != "", "V3-2c should write second passive id")
	_expect(second_active_id != str(loadout.get("active_skill_id", "")), "V3-2c second active should exclude the primary active")
	_expect(second_passive_id != str(loadout.get("passive_skill_id", "")), "V3-2c second passive should exclude the primary passive")
	_expect_str(str(owner.value_of("lingpet_second_active_skill_id")), second_active_id, "owner second active id should mirror the reconciled slot-1 active")
	_expect_str(str(owner.value_of("lingpet_second_passive_skill_id")), second_passive_id, "owner second passive id should mirror the reconciled slot-1 passive")
	_expect_eq(runtime._get_active_slot_count(), 2, "runtime active slot count should enable slot 1 after second active reconcile")
	_expect_str(runtime._get_skill_id_for_slot(1), second_active_id, "runtime slot 1 active id should match the reconciled second active")


func _verify_debug_forced_skill_reconcile_stays_sticky() -> void:
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new({})
	var runtime: Object = LingpetEggRuntime.new()
	_runtime_refs.append(runtime)
	_expect(
		runtime.debug_grant_and_activate_pet("lumion", owner, false, "lumion_thunder_orb", "", registry, 1, 1),
		"debug forced Thunder Orb grant should activate Lumion"
	)
	_grant_round_commits(runtime, "lumion", 10, registry)
	runtime.update(0.0, owner, registry)
	_expect_str(str(owner.value_of("lingpet_active_skill_id")), "lumion_thunder_orb", "debug forced active skill should stay sticky while same-pet reconcile is protected")
	_expect_str(str(runtime.get_snapshot().get("companion_skill_id", "")), "lumion_thunder_orb", "debug forced active skill should stay in the snapshot while forced reconcile is protected")


func _verify_headstart_rederives_primary_unlock() -> void:
	var store_path := _smoke_save_path("headstart")
	var store := LingpetAffinityStore.new()
	store.set_save_path(store_path)
	store.clear()
	_expect(bool(store.set_best_level("lumion", 3)), "headstart fixture should persist Lumion best level")

	var owner_a := FakeOwner.new()
	var registry_a := FakeRegistry.new({"lingpet_affinity_store": store})
	var runtime_a: Object = LingpetEggRuntime.new()
	_runtime_refs.append(runtime_a)
	_expect(runtime_a.debug_grant_and_activate_pet("lumion", owner_a, false, "", "", registry_a), "headstart fixture A should activate Lumion")
	runtime_a.update(0.0, owner_a, registry_a)
	_expect_eq(runtime_a.get_affinity_level("lumion"), 1, "best level 3 should rederive a Lv.1 headstart")
	var active_a := _resolved_choice(runtime_a, "lumion", "active")
	_expect_str(str(owner_a.value_of("lingpet_active_skill_id")), str(active_a.get("selected", "")), "headstart A should equip the automatic primary active unlock")

	var owner_b := FakeOwner.new()
	var registry_b := FakeRegistry.new({"lingpet_affinity_store": store})
	var runtime_b: Object = LingpetEggRuntime.new()
	_runtime_refs.append(runtime_b)
	_expect(runtime_b.debug_grant_and_activate_pet("lumion", owner_b, false, "", "", registry_b), "headstart fixture B should activate Lumion")
	runtime_b.update(0.0, owner_b, registry_b)
	_expect_eq(runtime_b.get_affinity_level("lumion"), 1, "best level 3 should rederive the same Lv.1 headstart on a fresh runtime")
	var active_b := _resolved_choice(runtime_b, "lumion", "active")
	_expect_str(str(owner_b.value_of("lingpet_active_skill_id")), str(active_b.get("selected", "")), "headstart B should equip the automatic primary active unlock")
	_expect_str(str(active_b.get("selected", "")), str(active_a.get("selected", "")), "fresh headstart should deterministically rederive the same automatic active unlock")
	store.clear()


func _verify_persisted_unlock_choice_overrides_auto_resolve() -> void:
	var store_path := _smoke_save_path("persisted_choice")
	var store := LingpetAffinityStore.new()
	store.set_save_path(store_path)
	store.clear()
	_expect(bool(store.set_best_level("lumion", 3)), "persisted-choice fixture should seed Lumion Lv.1 headstart")
	_expect(bool(store.set_resolved_unlock_choice("lumion", "active", "lumion_thunder_orb")), "persisted-choice fixture should save a non-default active choice")

	var owner := FakeOwner.new()
	var registry := FakeRegistry.new({"lingpet_affinity_store": store})
	var runtime: Object = LingpetEggRuntime.new()
	_runtime_refs.append(runtime)
	_expect(runtime.debug_grant_and_activate_pet("lumion", owner, false, "", "", registry), "persisted-choice fixture should activate Lumion")
	runtime.update(0.0, owner, registry)
	_expect_eq(runtime.get_affinity_level("lumion"), 1, "best level 3 should rebuild the Lv.1 unlock before persisted choice reconcile")
	_expect_str(str(owner.value_of("lingpet_active_skill_id")), "lumion_thunder_orb", "persisted active choice should override automatic unlock selection")
	var resolved := _resolved_choice(runtime, "lumion", "active")
	_expect_str(str(resolved.get("selected", "")), "lumion_thunder_orb", "affinity state should carry the persisted active choice after reconcile")
	_expect_str(str(store.get_resolved_unlock_choices("lumion").get("active", "")), "lumion_thunder_orb", "reconcile should not rewrite an existing persisted choice")
	store.clear()


func _verify_stale_persisted_unlock_choice_drops_to_auto_resolve() -> void:
	var store_path := _smoke_save_path("stale_choice")
	var store := LingpetAffinityStore.new()
	store.set_save_path(store_path)
	store.clear()
	_expect(bool(store.set_best_level("lumion", 3)), "stale-choice fixture should seed Lumion Lv.1 headstart")
	_expect(bool(store.set_resolved_unlock_choice("lumion", "active", "missing_solar_bolt")), "stale-choice fixture should save an invalid active choice")

	var owner := FakeOwner.new()
	var registry := FakeRegistry.new({"lingpet_affinity_store": store})
	var runtime: Object = LingpetEggRuntime.new()
	_runtime_refs.append(runtime)
	_expect(runtime.debug_grant_and_activate_pet("lumion", owner, false, "", "", registry), "stale-choice fixture should activate Lumion")
	runtime.update(0.0, owner, registry)
	var resolved := _resolved_choice(runtime, "lumion", "active")
	_expect_str(str(owner.value_of("lingpet_active_skill_id")), str(resolved.get("selected", "")), "stale persisted active should be dropped before loadout write and fall back to automatic selection")
	_expect_str(str(store.get_resolved_unlock_choices("lumion").get("active", "")), "", "stale persisted active choice should be cleared from the permanent store")
	store.clear()


func _verify_resolved_unlock_choice_store_roundtrip_and_threading() -> void:
	var store_path := _smoke_save_path("choice_roundtrip")
	_remove_user_file(store_path)
	_remove_user_file(store_path.trim_suffix(".cfg") + ".last_good.cfg")
	var store := LingpetAffinityStore.new()
	store.set_save_path(store_path)
	_expect(bool(store.set_resolved_unlock_choice("Lumion ", "ACTIVE", " Lumion_Solar_Bolt ")), "resolved choice store should accept normalized pet/key/skill ids")
	var reloaded := LingpetAffinityStore.new()
	reloaded.set_save_path(store_path)
	_expect_eq(int(reloaded.get_schema_version()), 4, "resolved choice store should stamp the v4 schema")
	_expect_str(str(reloaded.get_resolved_unlock_choices("lumion").get("active", "")), "lumion_solar_bolt", "resolved choice should roundtrip through the permanent store")
	var saved_text := FileAccess.get_file_as_string(store_path)
	_expect(saved_text.find("[resolved_unlock_choices]") >= 0 and saved_text.find("lumion.active=\"lumion_solar_bolt\"") >= 0, "resolved choice file should use the pet-scoped selected-only section")
	_expect_str(str(reloaded.last_load_summary), "ok", "choice-only affinity store should not be treated as an empty/corrupt residue file")

	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	_expect(runtime_source.find("_apply_current_loadout(owner, true, false, registry)") >= 0, "companion hot path should thread registry into unlock reconcile")
	_expect(runtime_source.find("_apply_current_loadout(owner, true, true, registry)") >= 0, "hatch/debug paths should thread registry into unlock reconcile")
	var save_store_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_save_store.gd")
	_expect(save_store_source.find("apply_save_snapshot(snapshot, owner, registry)") >= 0, "lingpet save restore should thread registry into snapshot reconcile")
	var plaza_source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_lingpet_store_transactions.gd")
	_expect(plaza_source.find("apply_save_snapshot(snapshot, owner, registry)") >= 0, "plaza rollback restore should thread registry into snapshot reconcile")
	reloaded.clear()
	_remove_user_file(store_path)
	_remove_user_file(store_path.trim_suffix(".cfg") + ".last_good.cfg")


func _verify_maribo_headstart_rederives_starter_unlock() -> void:
	var store_path := _smoke_save_path("maribo_headstart")
	var store := LingpetAffinityStore.new()
	store.set_save_path(store_path)
	store.clear()
	_expect(bool(store.set_best_level("maribo", 3)), "Maribo headstart fixture should persist best level 3")
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new({"lingpet_affinity_store": store})
	var runtime: Object = LingpetEggRuntime.new()
	_runtime_refs.append(runtime)
	_expect(runtime.debug_grant_and_activate_pet("maribo", owner, false, "", "", registry), "Maribo headstart fixture should activate with an empty hatch-zero loadout")
	runtime.update(0.0, owner, registry)
	_expect_eq(runtime.get_affinity_level("maribo"), 1, "Maribo best level 3 should rederive a Lv.1 headstart")
	var resolved := _resolved_choice(runtime, "maribo", "active")
	_expect_str(str(owner.value_of("lingpet_active_skill_id")), str(resolved.get("selected", "")), "Maribo Lv.1 headstart should equip the automatic active unlock")
	_expect_str(str(owner.value_of("lingpet_passive_skill_id")), "", "Maribo Lv.1 headstart should not bypass the Lv.2 passive unlock")
	store.clear()


func _verify_active_unlock_options_use_raw_first_two_cap() -> void:
	var runtime: Object = LingpetEggRuntime.new()
	_runtime_refs.append(runtime)
	var three_ids: Array[String] = ["alpha", "beta", "gamma"]
	_expect(_string_arrays_equal(runtime._first_raw_candidates(three_ids, 2), ["alpha", "beta"]), "active unlock candidate cap should keep the raw first two candidates without shuffling")
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	_expect(runtime_source.find("return _first_raw_candidates(ids, 2)") >= 0, "active unlock candidate helper should use the raw first-two cap")


func _verify_tab_unlock_options_sequential_queue_count() -> void:
	var store_path := _smoke_save_path("picker_queue")
	var store := LingpetAffinityStore.new()
	store.set_save_path(store_path)
	store.clear()
	_expect(bool(store.set_best_level("lumion", 6)), "picker queue fixture should seed Lumion Lv.2 headstart")
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new({"lingpet_affinity_store": store})
	var runtime: Object = LingpetEggRuntime.new()
	_runtime_refs.append(runtime)
	_expect(runtime.debug_grant_and_activate_pet("lumion", owner, false, "", "", registry), "picker queue fixture should activate Lumion")
	runtime.update(0.0, owner, registry)
	var options: Array = runtime.get_unlock_choice_options("lumion", registry)
	_expect(options.is_empty(), "TAB picker should stay hidden because unlock choices auto-resolve")
	_expect_eq(CharacterInfoOverlayLingpetPresenter._count_open_unlock_options(options), 0, "TAB picker waiting indicator should not count auto-resolved choices")
	_expect(CharacterInfoOverlayLingpetPresenter._first_open_unlock_option(options).is_empty(), "TAB picker should have no first open option after auto-resolve")
	store.clear()


func _verify_tab_unlock_options_and_commit_lock() -> void:
	var store_path := _smoke_save_path("picker_commit")
	var store := LingpetAffinityStore.new()
	store.set_save_path(store_path)
	store.clear()
	_expect(bool(store.set_best_level("lumion", 3)), "picker fixture should seed Lumion Lv.1 headstart")
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new({"lingpet_affinity_store": store})
	var runtime: Object = LingpetEggRuntime.new()
	_runtime_refs.append(runtime)
	_expect(runtime.debug_grant_and_activate_pet("lumion", owner, false, "", "", registry), "picker fixture should activate Lumion")
	runtime.update(0.0, owner, registry)

	var active_option := _find_unlock_option(runtime.get_unlock_choice_options("lumion", registry), "active")
	var lumion_active_ids := _skill_ids(LingpetCatalog.get_active_skill_pool("lumion"))
	_expect(active_option.is_empty(), "TAB picker should not expose an open active choice after automatic unlock selection")

	var picked_id := str(lumion_active_ids[1])
	_expect(bool(store.set_resolved_unlock_choice("lumion", "active", picked_id)), "direct store write fixture should save the non-default pick")
	var auto_resolved := _resolved_choice(runtime, "lumion", "active")
	_expect_str(str(owner.value_of("lingpet_active_skill_id")), str(auto_resolved.get("selected", "")), "direct store write alone should not silently reapply the live loadout")
	_expect(bool(store.clear_resolved_unlock_choice("lumion", "active")), "direct store write fixture should clear before testing the public commit path")
	_expect(not bool(runtime.commit_unlock_pick("lumion", "active", picked_id, owner, registry)), "TAB picker commit should reject because the picker surface is closed")
	_expect_str(str(store.get_resolved_unlock_choices("lumion").get("active", "")), "", "closed TAB picker should not write the permanent store")
	_expect_str(str(owner.value_of("lingpet_active_skill_id")), str(auto_resolved.get("selected", "")), "closed TAB picker should not reapply the loadout")
	var locked_option := _find_unlock_option(runtime.get_unlock_choice_options("lumion", registry), "active")
	_expect(locked_option.is_empty(), "closed TAB picker should not expose locked choices either")
	_expect(not bool(runtime.commit_unlock_pick("lumion", "active", str(lumion_active_ids[0]), owner, registry)), "TAB picker should reject all player commits while auto-resolve is active")
	_expect_str(str(store.get_resolved_unlock_choices("lumion").get("active", "")), "", "TAB picker rejected commit should preserve empty stored choice")
	store.clear()


func _verify_tab_unlock_options_filter_single_candidate() -> void:
	var store_path := _smoke_save_path("picker_single_candidate")
	var store := LingpetAffinityStore.new()
	store.set_save_path(store_path)
	store.clear()
	_expect(bool(store.set_best_level("milkring", 3)), "single-candidate picker fixture should seed Milkring Lv.1 headstart")
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new({"lingpet_affinity_store": store})
	var runtime: Object = LingpetEggRuntime.new()
	_runtime_refs.append(runtime)
	_expect(runtime.debug_grant_and_activate_pet("milkring", owner, false, "", "", registry), "single-candidate picker fixture should activate Milkring")
	runtime.update(0.0, owner, registry)
	_expect(_find_unlock_option(runtime.get_unlock_choice_options("milkring", registry), "active").is_empty(), "TAB picker should hide single-candidate auto-resolved active choices")
	_expect(not bool(runtime.commit_unlock_pick("milkring", "active", "milkring_milk_production", owner, registry)), "TAB picker commit should reject a single-candidate auto-resolved choice")
	_expect(store.get_resolved_unlock_choices("milkring").is_empty(), "single-candidate auto-resolve should not become a stored player pick")
	store.clear()


func _activate_pet(pet_id: String) -> Dictionary:
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new({})
	var runtime: Object = LingpetEggRuntime.new()
	_runtime_refs.append(runtime)
	_expect(runtime.debug_grant_and_activate_pet(pet_id, owner, false, "", "", registry), "%s fixture should activate" % pet_id)
	return {"runtime": runtime, "owner": owner, "registry": registry}


func _cleanup_runtimes() -> void:
	for runtime in _runtime_refs:
		if runtime != null and runtime.has_method("reset_for_tests"):
			runtime.reset_for_tests()
	_runtime_refs.clear()


func _grant_round_commits(runtime: Object, pet_id: String, count: int, registry: Object = null) -> void:
	for _i in range(count):
		runtime.debug_add_affinity_points_for_tests(pet_id, LingpetAffinityState.SOURCE_ROUND_COMMIT, {}, registry)


func _register_hit(runtime: Object, owner: FakeOwner, registry: Object, egg_pos: Vector2) -> void:
	owner.values["ball_active"] = true
	owner.values["ball_pos"] = egg_pos
	owner.values["ball_vel"] = Vector2(0.0, 12.0)
	runtime.update(0.0, owner, registry)


func _resolved_choice(runtime: Object, pet_id: String, choice_key: String) -> Dictionary:
	var resolved: Dictionary = runtime._affinity_state.get_resolved_unlock_choices(pet_id)
	return resolved.get(choice_key, {}) as Dictionary


func _find_unlock_option(options: Array, choice_key: String) -> Dictionary:
	for option in options:
		if not (option is Dictionary):
			continue
		var option_dict: Dictionary = option
		if str(option_dict.get("choice_key", "")) == choice_key:
			return option_dict
	return {}


func _skill_ids(pool: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for skill in pool:
		var skill_id := str(skill.get("id", "")).strip_edges()
		if skill_id != "" and not result.has(skill_id):
			result.append(skill_id)
	return result


func _all_ids_in_pool(ids: Array, pool_ids: Array[String]) -> bool:
	for raw_id in ids:
		if not pool_ids.has(str(raw_id)):
			return false
	return true


func _string_arrays_equal(left: Array, right: Array) -> bool:
	if left.size() != right.size():
		return false
	for i in range(left.size()):
		if str(left[i]) != str(right[i]):
			return false
	return true


func _remove_user_file(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(absolute_path)


func _smoke_save_path(slug: String) -> String:
	return "res://.tmp/lingpet_unlock_loadout_v3_2c_smoke_%s_%d_%d.cfg" % [
		slug,
		OS.get_process_id(),
		Time.get_ticks_usec(),
	]


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: int, expected: int, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %d, got %d)" % [message, expected, actual])


func _expect_str(actual: String, expected: String, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, expected, actual])
