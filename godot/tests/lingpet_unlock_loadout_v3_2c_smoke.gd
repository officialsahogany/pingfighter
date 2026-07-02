extends SceneTree

const LingpetAffinityState := preload("res://scripts/lingpet/lingpet_affinity_state.gd")
const LingpetRingCoreRules := preload("res://scripts/lingpet/lingpet_ring_core_rules.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const LingpetLoadoutState := preload("res://scripts/lingpet/lingpet_loadout_state.gd")
const LingpetUnlockLoadoutReconciler := preload("res://scripts/lingpet/lingpet_unlock_loadout_reconciler.gd")
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


class FakeSharedModuleHost:
	extends RefCounted

	func would_share_module(_first_skill_id: String, _second_skill_id: String) -> bool:
		return true


var _failures: Array[String] = []
var _runtime_refs: Array[Object] = []


func _init() -> void:
	_verify_catalog_no_skill_and_lumion_pool()
	_verify_no_skill_activation_snapshot()
	_verify_fresh_hatch_applies_randomized_skill_loadout_consistently()
	_verify_empty_primary_set_does_not_reinject_defaults()
	_verify_legacy_one_slot_loadout_survives_v3_2c_normalization()
	_verify_existing_saved_active_skill_loadout_restores_without_reroll()
	_verify_primary_unlock_reconcile()
	_verify_lazy_applied_key_reconcile_runs_before_cache_return()
	_verify_milkring_two_entry_pool_resolve()
	_verify_single_entry_unlock_resolves_without_pending_choice()
	_verify_resolved_unlocks_stay_pet_scoped_until_switch()
	_verify_volatile_restore_rederives_loadout_from_affinity_run_state()
	_verify_second_unlock_flags_fill_slot_one()
	_verify_debug_forced_skill_reconcile_stays_sticky()
	_verify_run_state_lv1_rederives_primary_unlock()
	_verify_maribo_lv1_rederives_starter_unlock()
	_verify_active_unlock_options_use_raw_first_two_cap()
	_verify_shared_runtime_module_rejection_owner()
	_verify_tab_unlock_options_sequential_queue_count()
	_verify_tab_unlock_options_and_commit_lock()
	_verify_tab_unlock_options_hide_auto_resolved_milkring_choice()
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
	_verify_active_skill_pool_entries_do_not_keep_legacy_single_key()
	var empty_explicit := LingpetCatalog.get_active_skill("lumion", "", 1)
	_expect(empty_explicit.is_empty(), "explicit empty active id should not fall back to Lumion pool[0]")
	var empty_loadout := LingpetCatalog.build_empty_loadout("lumion")
	_expect_empty_skill_channel(empty_loadout, "active", "explicit empty loadout should keep active skill empty")
	_expect_empty_skill_channel(empty_loadout, "passive", "explicit empty loadout should keep passive skill empty")
	var roll_rng := RandomNumberGenerator.new()
	roll_rng.seed = 20260626
	var hatch_loadout := LingpetCatalog.pick_skill_loadout("lumion", roll_rng)
	_expect_hatch_roll_channel(hatch_loadout, "active", "lumion_thunder_orb", "new hatch active roll")
	# Hatch passive identity is now randomly drawn from the shared common passive pool
	# (no longer pinned to pool[0] = lingpet_resonance_boost); assert pool membership + shape.
	_expect_hatch_passive_roll_from_pool(hatch_loadout, "new hatch passive roll")
	var lumion_active_ids := _skill_ids(LingpetCatalog.get_active_skill_pool("lumion"))
	_expect(lumion_active_ids.has("lumion_thunder_orb"), "Lumion active pool should keep Thunder Orb")
	_expect(lumion_active_ids.has("lumion_solar_bolt"), "Lumion active pool should expose Solar Bolt as an unlock candidate")
	var solar_entry := LingpetCatalog.get_active_skill_entry("lumion_solar_bolt")
	_expect_str(str(solar_entry.get("runtime_kind", "")), "solar_bolt", "Solar Bolt catalog entry should expose runtime_kind")
	_expect(str(solar_entry.get("card_texture_path", "")).ends_with("lumion_solar_bolt_skillcard_imagegen_v1.png"), "Solar Bolt should use its dedicated golden skill-card art")
	_expect(str(solar_entry.get("icon_texture_path", "")).ends_with("lumion_solar_bolt_skill_icon_imagegen_v1.png"), "Solar Bolt should use its dedicated golden skill icon")
	_expect(ProjectResourceLoader.texture_resource_exists(str(solar_entry.get("card_texture_path", ""))), "Solar Bolt dedicated card path should be loadable")
	_expect(ProjectResourceLoader.texture_resource_exists(str(solar_entry.get("icon_texture_path", ""))), "Solar Bolt dedicated icon path should be loadable")


func _verify_active_skill_pool_entries_do_not_keep_legacy_single_key() -> void:
	for raw_pet_id in LingpetCatalog.PETS.keys():
		var entry: Variant = LingpetCatalog.PETS.get(raw_pet_id, {})
		if not (entry is Dictionary):
			continue
		var entry_data: Dictionary = entry as Dictionary
		var pool: Variant = entry_data.get("active_skill_pool", [])
		if pool is Array and not (pool as Array).is_empty():
			_expect(
				not entry_data.has("active_skill"),
				"%s should not keep the legacy active_skill key next to active_skill_pool" % str(raw_pet_id)
			)


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


func _verify_fresh_hatch_applies_randomized_skill_loadout_consistently() -> void:
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
	_expect(not hatch_loadout.is_empty(), "fresh hatch should publish a loadout snapshot")
	_expect_runtime_channel_matches_loadout(owner, hatch_loadout, "active", "fresh hatch active roll")
	_expect_runtime_channel_matches_loadout(owner, hatch_loadout, "passive", "fresh hatch passive roll")


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


func _verify_existing_saved_active_skill_loadout_restores_without_reroll() -> void:
	var restore_snapshot := {
		"version": 1,
		"pet_id": "lumion",
		"state": "companion",
		"hatch_hits": 0,
		"required_hits": LingpetCatalog.get_required_hits("lumion"),
		"egg_color_index": -1,
		"companion_pos": Vector2(210.0, 510.0),
		"owned_pet_ids": ["lumion"],
		"battle_slot_pet_ids": ["lumion", "", ""],
		"lingpet_slots": ["lumion", "", ""],
		"active_slot_index": 0,
		"active_pet_id": "lumion",
		"lingpet_loadouts": {
			"lumion": {
				"active_skill_id": "lumion_solar_bolt",
				"active_skill_level": 3,
				"passive_slot_count": 0,
			},
		},
	}
	var restored_runtime: Object = LingpetEggRuntime.new()
	_runtime_refs.append(restored_runtime)
	var restored_owner := FakeOwner.new()
	var restored_registry := FakeRegistry.new({})
	var restore_result: Dictionary = restored_runtime.apply_save_snapshot(restore_snapshot, restored_owner, restored_registry)
	_expect(bool(restore_result.get("restored", false)), "existing saved active-skill restore should succeed")
	_expect_str(str(restored_owner.value_of("active_lingpet_id")), "lumion", "existing saved active-skill restore should reactivate Lumion")
	_expect_str(str(restored_owner.value_of("lingpet_active_skill_id")), "lumion_solar_bolt", "existing saved active_skill_id should survive restore without rerolling to pool[0]")
	_expect_eq(int(restored_owner.value_of("lingpet_active_skill_level")), 3, "existing saved active_skill_level should survive restore")
	var restored_loadout: Dictionary = restored_runtime._loadout_state.get_loadout("lumion")
	_expect_str(str(restored_loadout.get("active_skill_id", "")), "lumion_solar_bolt", "restored normalized loadout should keep the saved active id")
	_expect_eq(int(restored_loadout.get("active_skill_level", 0)), 3, "restored normalized loadout should keep the saved active level")
	_expect_eq((restored_loadout.get("active_skill_ids", []) as Array).size(), 1, "restored legacy one-id loadout should normalize into one active slot")
	_expect_str(str((restored_loadout.get("active_skill_ids", []) as Array)[0]), "lumion_solar_bolt", "restored active_skill_ids[0] should be the saved skill, not the catalog default")


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
	_verify_primary_unlock_active_can_arm_and_launch(runtime, owner, registry, str(active_resolved.get("selected", "")))

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


func _verify_primary_unlock_active_can_arm_and_launch(runtime: Object, owner: FakeOwner, registry: Object, selected_id: String) -> void:
	_expect(selected_id != "", "S2 cast fixture should have a selected active skill id")
	owner.values["ball_active"] = true
	owner.values["ball_pos"] = Vector2(40.0, 520.0)
	owner.values["ball_vel"] = Vector2(0.0, 180.0)
	runtime.configure_companion_motion_for_tests(Vector2(380.0, 260.0), 13, 0.0, true)
	runtime.update(0.05, owner, registry)
	var slot0_state: Object = _skill_state_for_runtime_slot(runtime, 0)
	_expect(bool(slot0_state.windup_active), "S2 active unlock should arm the reconciled slot-0 skill windup")
	_expect_eq(int(owner.value_of("lingpet_skill_trigger_count")), 0, "S2 active unlock should not launch before windup completes")
	_expect(bool(runtime.get_snapshot().get("companion_skill_winding_up", false)), "S2 active unlock snapshot should expose the armed windup")

	var windup_seconds := float(runtime.get_snapshot().get("companion_skill_windup_seconds", LingpetEggRuntime.COMPANION_SKILL_WINDUP_SECONDS))
	runtime.update(windup_seconds + 0.05, owner, registry)
	var launch_snapshot: Dictionary = runtime.get_snapshot()
	_expect_eq(int(owner.value_of("lingpet_skill_trigger_count")), 1, "S2 active unlock should dispatch through the skill runtime host after windup")
	_expect(float(owner.value_of("lingpet_skill_cooldown")) > 0.0, "S2 active unlock should spend cooldown after launch")
	_expect(not bool(launch_snapshot.get("companion_skill_winding_up", true)), "S2 active unlock windup should clear after launch")
	if selected_id == "lumion_thunder_orb":
		_expect(bool(launch_snapshot.get("thunder_orb_projectile_active", false)), "S2 Lumion Thunder Orb should launch a live projectile")


func _verify_lazy_applied_key_reconcile_runs_before_cache_return() -> void:
	var fixture := _activate_pet("lumion")
	var runtime: Object = fixture.get("runtime")
	var owner: FakeOwner = fixture.get("owner")
	var registry: Object = fixture.get("registry")
	_expect(runtime._loadout_state.has_applied_runtime_cache(), "empty activation should establish an applied loadout cache key")
	_expect_str(str(owner.value_of("lingpet_active_skill_id")), "", "pre-unlock cached loadout should keep active id empty")

	_grant_round_commits(runtime, "lumion", 10, registry)
	_expect(not runtime._loadout_state.has_applied_runtime_cache(), "level-gain unlock should invalidate the applied loadout cache before the next update")
	runtime.update(0.0, owner, registry)
	var resolved := _resolved_choice(runtime, "lumion", "active")
	var selected_id := str(resolved.get("selected", ""))
	_expect(selected_id != "", "level-gain unlock should resolve an active skill after cache invalidation")
	_expect_str(str(owner.value_of("lingpet_active_skill_id")), selected_id, "unlock reconcile should run after applied-cache invalidation instead of staying on the old empty cache")
	_expect_str(str(runtime.get_snapshot().get("companion_skill_id", "")), selected_id, "snapshot should refresh after cached-loadout unlock reconcile")


func _verify_milkring_two_entry_pool_resolve() -> void:
	var fixture := _activate_pet("milkring")
	var runtime: Object = fixture.get("runtime")
	var owner: FakeOwner = fixture.get("owner")
	var registry: Object = fixture.get("registry")
	_grant_round_commits(runtime, "milkring", 10, registry)
	runtime.update(0.0, owner, registry)
	var resolved := _resolved_choice(runtime, "milkring", "active")
	var milkring_active_ids := _skill_ids(LingpetCatalog.get_active_skill_pool("milkring"))
	_expect(milkring_active_ids.has("milkring_milk_production"), "Milkring active pool should keep Milk Production")
	_expect(milkring_active_ids.has("milkring_milk_shot"), "Milkring active pool should add Milk Shot")
	_expect_eq(milkring_active_ids.size(), 2, "Milkring active pool should now expose two active candidates")
	var candidates: Array = resolved.get("candidates", []) as Array
	_expect(_string_arrays_equal(candidates, milkring_active_ids), "Milkring active resolve should record the full two-skill pool")
	_expect(candidates.has(str(resolved.get("selected", ""))), "Milkring active resolve should auto-select one of the two active skills")
	_expect(bool(resolved.get("random", false)), "Milkring two-entry active resolve should be marked as random")
	_expect(not bool(resolved.get("single", false)), "Milkring two-entry active resolve should not use single-candidate semantics")
	_expect_str(str(owner.value_of("lingpet_active_skill_id")), str(resolved.get("selected", "")), "Milkring active auto-resolve should equip the selected slot 0")

	var state := LingpetAffinityState.new()
	var direct := state.resolve_single_unlock("nekuring", LingpetAffinityState.REWARD_TYPE_ACTIVE_UNLOCK, "nekuring_bone_barrier")
	_expect(bool(direct.get("accepted", false)), "resolve_single_unlock should accept a valid Nekuring active skill")
	var direct_resolved: Dictionary = state.get_resolved_unlock_choices("nekuring").get("active", {}) as Dictionary
	_expect_str(str(direct_resolved.get("selected", "")), "nekuring_bone_barrier", "direct single resolve should persist selected id")
	_expect_eq((direct_resolved.get("candidates", []) as Array).size(), 1, "direct single resolve should persist a one-id candidate list")


func _verify_single_entry_unlock_resolves_without_pending_choice() -> void:
	var fixture := _activate_pet("orosha")
	var runtime: Object = fixture.get("runtime")
	var owner: FakeOwner = fixture.get("owner")
	var registry: Object = fixture.get("registry")
	var orosha_active_ids := _skill_ids(LingpetCatalog.get_active_skill_pool("orosha"))
	_expect(_string_arrays_equal(orosha_active_ids, ["orosha_star_coil"]), "Orosha fixture should keep a one-entry active skill pool")
	_grant_round_commits(runtime, "orosha", 10, registry)
	runtime.update(0.0, owner, registry)
	var resolved := _resolved_choice(runtime, "orosha", "active")
	_expect(bool(resolved.get("single", false)), "one-entry active unlock should resolve through single-candidate semantics")
	_expect_eq((resolved.get("candidates", []) as Array).size(), 1, "one-entry active unlock should record exactly one candidate")
	_expect_str(str(resolved.get("selected", "")), "orosha_star_coil", "one-entry active unlock should select the only Orosha active")
	_expect(runtime._affinity_state.get_pending_unlock_choices("orosha").is_empty(), "one-entry active unlock should not leave a pending TAB choice")
	_expect_str(str(owner.value_of("lingpet_active_skill_id")), "orosha_star_coil", "one-entry active unlock should equip the only active skill")


func _verify_resolved_unlocks_stay_pet_scoped_until_switch() -> void:
	var fixture := _activate_pet("lumion")
	var runtime: Object = fixture.get("runtime")
	var owner: FakeOwner = fixture.get("owner")
	var registry: Object = fixture.get("registry")
	runtime._affinity_state.resolve_single_unlock(
		"maribo",
		LingpetAffinityState.REWARD_TYPE_ACTIVE_UNLOCK,
		"maribo_hydro_sphere"
	)
	runtime.update(0.0, owner, registry)
	_expect_str(str(owner.value_of("active_lingpet_id")), "lumion", "per-pet fixture should still have Lumion active before switching")
	_expect_str(str(owner.value_of("lingpet_active_skill_id")), "", "Maribo resolved unlock should not leak into Lumion's current loadout")

	_expect(runtime.debug_grant_and_activate_pet("maribo", owner, false, "", "", registry), "per-pet fixture should switch to Maribo")
	_expect_str(str(owner.value_of("active_lingpet_id")), "maribo", "per-pet fixture should publish Maribo after switching")
	_expect_str(str(owner.value_of("lingpet_active_skill_id")), "maribo_hydro_sphere", "Maribo resolved unlock should apply only after Maribo becomes the active pet")


func _verify_volatile_restore_rederives_loadout_from_affinity_run_state() -> void:
	var source_runtime: Object = LingpetEggRuntime.new()
	_runtime_refs.append(source_runtime)
	source_runtime._affinity_state.resolve_single_unlock(
		"lumion",
		LingpetAffinityState.REWARD_TYPE_ACTIVE_UNLOCK,
		"lumion_solar_bolt"
	)
	var restore_snapshot := {
		"version": 1,
		"pet_id": "lumion",
		"state": "companion",
		"hatch_hits": 0,
		"required_hits": LingpetCatalog.get_required_hits("lumion"),
		"egg_color_index": -1,
		"companion_pos": Vector2(180.0, 520.0),
		"owned_pet_ids": ["lumion"],
		"battle_slot_pet_ids": ["lumion", "", ""],
		"lingpet_slots": ["lumion", "", ""],
		"active_slot_index": 0,
		"active_pet_id": "lumion",
		"affinity_run_state": source_runtime._affinity_state.export_run_state(),
	}
	_expect(not restore_snapshot.has("lingpet_loadouts"), "volatile restore fixture should intentionally omit saved loadouts")
	var restored_runtime: Object = LingpetEggRuntime.new()
	_runtime_refs.append(restored_runtime)
	var restored_owner := FakeOwner.new()
	var restored_registry := FakeRegistry.new({})
	var restore_result: Dictionary = restored_runtime.apply_save_snapshot(restore_snapshot, restored_owner, restored_registry)
	_expect(bool(restore_result.get("restored", false)), "affinity-run-state restore should succeed without persisted loadouts")
	_expect_str(str(restored_owner.value_of("active_lingpet_id")), "lumion", "affinity-run-state restore should reactivate the saved pet")
	_expect_str(str(restored_owner.value_of("lingpet_active_skill_id")), "lumion_solar_bolt", "restore should rederive active loadout from resolved affinity choice")
	var restored_loadout: Dictionary = restored_runtime._loadout_state.get_loadout("lumion")
	_expect_str(str(restored_loadout.get("active_skill_id", "")), "lumion_solar_bolt", "restore should rebuild loadout_state from affinity choices instead of requiring saved loadouts")


func _verify_second_unlock_flags_fill_slot_one() -> void:
	var fixture := _activate_pet("red_dragon")
	var runtime: Object = fixture.get("runtime")
	var owner: FakeOwner = fixture.get("owner")
	var registry: Object = fixture.get("registry")
	runtime._affinity_state.resolve_single_unlock(
		"red_dragon",
		LingpetAffinityState.REWARD_TYPE_ACTIVE_UNLOCK,
		"red_dragon_dragon_breath"
	)
	runtime._affinity_state.resolve_single_unlock(
		"red_dragon",
		LingpetAffinityState.REWARD_TYPE_PASSIVE_UNLOCK,
		"lingpet_resonance_boost"
	)
	runtime._affinity_state.resolve_single_unlock(
		"red_dragon",
		LingpetAffinityState.REWARD_TYPE_SECOND_ACTIVE_UNLOCK,
		"red_dragon_dragon_wing"
	)
	runtime._affinity_state.resolve_single_unlock(
		"red_dragon",
		LingpetAffinityState.REWARD_TYPE_SECOND_PASSIVE_UNLOCK,
		"lingpet_afterglow_leak"
	)
	runtime._loadout_state.set_skip_unlock_reconcile(false)
	runtime._loadout_state.invalidate_runtime_cache()
	runtime.update(0.0, owner, registry)
	var rewards: Dictionary = runtime.get_affinity_rewards_for_tests("red_dragon")
	_expect(bool(rewards.get("second_active_unlocked", false)), "fixture should include explicit second active unlock")
	_expect(bool(rewards.get("second_passive_unlocked", false)), "fixture should include explicit second passive unlock")
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
	var active_slot_count: int = runtime._skill_runtime_surface.get_active_slot_count(
		runtime._current_profile,
		runtime._active_skill_slot_resolver,
		runtime._skill_runtime_host
	)
	var slot_one_surface: Dictionary = runtime._skill_runtime_surface.get_active_surface_for_slot(
		runtime._current_profile,
		runtime._active_skill_slot_resolver,
		null,
		[],
		runtime._skill_runtime_host,
		0.0,
		1
	)
	_expect_eq(active_slot_count, 2, "runtime active slot count should enable slot 1 after second active reconcile")
	_expect_str(str(slot_one_surface.get("skill_id", "")), second_active_id, "runtime slot 1 active id should match the reconciled second active")


func _verify_debug_forced_skill_reconcile_stays_sticky() -> void:
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new({})
	var runtime: Object = LingpetEggRuntime.new()
	_runtime_refs.append(runtime)
	_set_run_ring_core_tier_for_smoke(runtime)
	_expect(
		runtime.debug_grant_and_activate_pet("lumion", owner, false, "lumion_thunder_orb", "", registry, 1, 1),
		"debug forced Thunder Orb grant should activate Lumion"
	)
	_grant_round_commits(runtime, "lumion", 10, registry)
	runtime.update(0.0, owner, registry)
	_expect_str(str(owner.value_of("lingpet_active_skill_id")), "lumion_thunder_orb", "debug forced active skill should stay sticky while same-pet reconcile is protected")
	_expect_str(str(runtime.get_snapshot().get("companion_skill_id", "")), "lumion_thunder_orb", "debug forced active skill should stay in the snapshot while forced reconcile is protected")


func _verify_run_state_lv1_rederives_primary_unlock() -> void:
	# R3 / per-run: no store headstart. Two fresh run-state Lv.1 fixtures should
	# each auto-resolve a valid primary active unlock, and an explicitly seeded
	# pair should deterministically rederive the same automatic active unlock.
	var lumion_active_ids := _skill_ids(LingpetCatalog.get_active_skill_pool("lumion"))

	var fixture_a := _activate_pet("lumion")
	var runtime_a: Object = fixture_a.get("runtime")
	var owner_a: FakeOwner = fixture_a.get("owner")
	var registry_a: Object = fixture_a.get("registry")
	_grant_round_commits(runtime_a, "lumion", 10, registry_a)
	runtime_a.update(0.0, owner_a, registry_a)
	_expect_eq(runtime_a.get_affinity_level("lumion"), 1, "ten run-state commits should reach Lv.1")
	var active_a := _resolved_choice(runtime_a, "lumion", "active")
	_expect_str(str(owner_a.value_of("lingpet_active_skill_id")), str(active_a.get("selected", "")), "run-state Lv.1 A should equip the automatic primary active unlock")
	_expect(lumion_active_ids.has(str(active_a.get("selected", ""))), "run-state Lv.1 A should auto-select a valid Lumion active unlock")

	var fixture_b := _activate_pet("lumion")
	var runtime_b: Object = fixture_b.get("runtime")
	var owner_b: FakeOwner = fixture_b.get("owner")
	var registry_b: Object = fixture_b.get("registry")
	_grant_round_commits(runtime_b, "lumion", 10, registry_b)
	runtime_b.update(0.0, owner_b, registry_b)
	_expect_eq(runtime_b.get_affinity_level("lumion"), 1, "ten run-state commits should reach Lv.1 on a fresh runtime")
	var active_b := _resolved_choice(runtime_b, "lumion", "active")
	_expect_str(str(owner_b.value_of("lingpet_active_skill_id")), str(active_b.get("selected", "")), "run-state Lv.1 B should equip the automatic primary active unlock")
	_expect(lumion_active_ids.has(str(active_b.get("selected", ""))), "run-state Lv.1 B should auto-select a valid Lumion active unlock")

	var seed_value := 24680
	var seeded_a := _activate_pet("lumion")
	var seeded_runtime_a: Object = seeded_a.get("runtime")
	var seeded_owner_a: FakeOwner = seeded_a.get("owner")
	var seeded_registry_a: Object = seeded_a.get("registry")
	seeded_runtime_a.set_affinity_reward_seed_for_tests("lumion", seed_value)
	_grant_round_commits(seeded_runtime_a, "lumion", 10, seeded_registry_a)
	seeded_runtime_a.update(0.0, seeded_owner_a, seeded_registry_a)
	var seeded_active_a := _resolved_choice(seeded_runtime_a, "lumion", "active")

	var seeded_b := _activate_pet("lumion")
	var seeded_runtime_b: Object = seeded_b.get("runtime")
	var seeded_owner_b: FakeOwner = seeded_b.get("owner")
	var seeded_registry_b: Object = seeded_b.get("registry")
	seeded_runtime_b.set_affinity_reward_seed_for_tests("lumion", seed_value)
	_grant_round_commits(seeded_runtime_b, "lumion", 10, seeded_registry_b)
	seeded_runtime_b.update(0.0, seeded_owner_b, seeded_registry_b)
	var seeded_active_b := _resolved_choice(seeded_runtime_b, "lumion", "active")
	_expect_str(str(seeded_active_b.get("selected", "")), str(seeded_active_a.get("selected", "")), "explicitly seeded fresh run-state Lv.1 fixtures should deterministically rederive the same automatic active unlock")


func _verify_maribo_lv1_rederives_starter_unlock() -> void:
	# R3 / per-run: run-state Lv.1 (no store headstart). Maribo's Lv.1 should
	# auto-resolve the active unlock while leaving the Lv.2 passive unlock gated.
	var fixture := _activate_pet("maribo")
	var runtime: Object = fixture.get("runtime")
	var owner: FakeOwner = fixture.get("owner")
	var registry: Object = fixture.get("registry")
	_grant_round_commits(runtime, "maribo", 10, registry)
	runtime.update(0.0, owner, registry)
	_expect_eq(runtime.get_affinity_level("maribo"), 1, "ten run-state commits should reach Maribo Lv.1")
	var resolved := _resolved_choice(runtime, "maribo", "active")
	_expect_str(str(owner.value_of("lingpet_active_skill_id")), str(resolved.get("selected", "")), "Maribo Lv.1 should equip the automatic active unlock")
	_expect_str(str(owner.value_of("lingpet_passive_skill_id")), "", "Maribo Lv.1 should not bypass the Lv.2 passive unlock")


func _verify_active_unlock_options_use_raw_first_two_cap() -> void:
	var reconciler := LingpetUnlockLoadoutReconciler.new()
	var three_ids: Array[String] = ["alpha", "beta", "gamma"]
	_expect(_string_arrays_equal(reconciler.first_raw_candidates(three_ids, 2), ["alpha", "beta"]), "active unlock candidate cap should keep the raw first two candidates without shuffling")
	var reconciler_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_unlock_loadout_reconciler.gd")
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var current_loadout_applier_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_current_loadout_applier.gd")
	_expect(reconciler_source.find("return first_raw_candidates(ids, 2)") >= 0, "unlock-loadout owner should use the raw first-two active candidate cap")
	_expect(runtime_source.find("func _first_raw_candidates") < 0, "egg runtime should not keep the old first-candidates test wrapper")
	_expect(runtime_source.find("func _has_unlock_reconcile_work") < 0, "egg runtime should not keep a single-use unlock-work pass-through wrapper")
	_expect(runtime_source.find("_current_loadout_applier.apply") >= 0, "egg runtime loadout apply path should delegate to the current-loadout applier")
	_expect(current_loadout_applier_source.find("unlock_loadout_reconciler.has_work") >= 0, "current-loadout applier should call the unlock reconciler work gate directly")


func _verify_shared_runtime_module_rejection_owner() -> void:
	var owner := FakeOwner.new()
	var affinity_state := LingpetAffinityState.new()
	var loadout_state := LingpetLoadoutState.new()
	var reconciler := LingpetUnlockLoadoutReconciler.new()
	affinity_state.resolve_single_unlock(
		"red_dragon",
		LingpetAffinityState.REWARD_TYPE_ACTIVE_UNLOCK,
		"red_dragon_dragon_breath"
	)
	affinity_state.resolve_single_unlock(
		"red_dragon",
		LingpetAffinityState.REWARD_TYPE_SECOND_ACTIVE_UNLOCK,
		"red_dragon_dragon_wing"
	)
	_expect(
		reconciler.reconcile(
			owner,
			"red_dragon",
			affinity_state,
			loadout_state,
			FakeSharedModuleHost.new()
		),
		"unlock-loadout owner should report the initial resolved loadout write"
	)
	var loadout: Dictionary = loadout_state.get_loadout("red_dragon")
	_expect_str(
		str(loadout.get("active_skill_id", "")),
		"red_dragon_dragon_breath",
		"shared-module rejection should preserve the primary active skill"
	)
	_expect_str(
		str(loadout.get("second_active_skill_id", "")),
		"",
		"shared-module rejection should suppress the conflicting second active skill"
	)


func _verify_tab_unlock_options_sequential_queue_count() -> void:
	# R3 / per-run: run-state Lv.2 (no store headstart).
	var fixture := _activate_pet("lumion")
	var runtime: Object = fixture.get("runtime")
	var owner: FakeOwner = fixture.get("owner")
	var registry: Object = fixture.get("registry")
	_grant_round_commits(runtime, "lumion", 25, registry)
	runtime.update(0.0, owner, registry)
	_expect_eq(runtime.get_affinity_level("lumion"), 2, "twenty-five run-state commits should reach Lv.2")
	var options: Array = runtime.get_unlock_choice_options("lumion", registry)
	_expect(options.is_empty(), "TAB picker should stay hidden because unlock choices auto-resolve")
	_expect_eq(CharacterInfoOverlayLingpetPresenter._count_open_unlock_options(options), 0, "TAB picker waiting indicator should not count auto-resolved choices")
	_expect(CharacterInfoOverlayLingpetPresenter._first_open_unlock_option(options).is_empty(), "TAB picker should have no first open option after auto-resolve")


func _verify_tab_unlock_options_and_commit_lock() -> void:
	# R3 / per-run: run-state Lv.1 (no store headstart). The TAB picker stays
	# closed under auto-resolve, so every player commit must be rejected and the
	# auto-resolved loadout must survive every rejection.
	var fixture := _activate_pet("lumion")
	var runtime: Object = fixture.get("runtime")
	var owner: FakeOwner = fixture.get("owner")
	var registry: Object = fixture.get("registry")
	_grant_round_commits(runtime, "lumion", 10, registry)
	runtime.update(0.0, owner, registry)
	_expect_eq(runtime.get_affinity_level("lumion"), 1, "ten run-state commits should reach Lv.1")

	var lumion_active_ids := _skill_ids(LingpetCatalog.get_active_skill_pool("lumion"))
	var active_option := _find_unlock_option(runtime.get_unlock_choice_options("lumion", registry), "active")
	_expect(active_option.is_empty(), "TAB picker should not expose an open active choice after automatic unlock selection")

	var auto_resolved := _resolved_choice(runtime, "lumion", "active")
	_expect(not bool(runtime.commit_unlock_pick("lumion", "active", str(lumion_active_ids[1]), owner, registry)), "TAB picker commit should reject because the picker surface is closed")
	_expect_str(str(owner.value_of("lingpet_active_skill_id")), str(auto_resolved.get("selected", "")), "rejected commit should not reapply the loadout")
	var locked_option := _find_unlock_option(runtime.get_unlock_choice_options("lumion", registry), "active")
	_expect(locked_option.is_empty(), "closed TAB picker should not expose locked choices either")
	_expect(not bool(runtime.commit_unlock_pick("lumion", "active", str(lumion_active_ids[0]), owner, registry)), "TAB picker should reject all player commits while auto-resolve is active")
	_expect_str(str(owner.value_of("lingpet_active_skill_id")), str(auto_resolved.get("selected", "")), "auto-resolved active should remain after every rejected commit")


func _verify_tab_unlock_options_hide_auto_resolved_milkring_choice() -> void:
	# R3 / per-run: run-state Lv.1 (no store headstart).
	var fixture := _activate_pet("milkring")
	var runtime: Object = fixture.get("runtime")
	var owner: FakeOwner = fixture.get("owner")
	var registry: Object = fixture.get("registry")
	_grant_round_commits(runtime, "milkring", 10, registry)
	runtime.update(0.0, owner, registry)
	_expect_eq(runtime.get_affinity_level("milkring"), 1, "ten run-state commits should reach Milkring Lv.1")
	var milkring_active_ids := _skill_ids(LingpetCatalog.get_active_skill_pool("milkring"))
	_expect(_find_unlock_option(runtime.get_unlock_choice_options("milkring", registry), "active").is_empty(), "TAB picker should hide Milkring's auto-resolved active choice")
	for skill_id in milkring_active_ids:
		_expect(not bool(runtime.commit_unlock_pick("milkring", "active", skill_id, owner, registry)), "TAB picker commit should reject Milkring's auto-resolved active choice %s" % skill_id)
	_expect(not _resolved_choice(runtime, "milkring", "active").is_empty(), "Milkring auto-resolve should be recorded in run-state, not as a stored player pick")


func _activate_pet(pet_id: String) -> Dictionary:
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new({})
	var runtime: Object = LingpetEggRuntime.new()
	_runtime_refs.append(runtime)
	_set_run_ring_core_tier_for_smoke(runtime)
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


func _set_run_ring_core_tier_for_smoke(runtime: Object, tier: int = LingpetRingCoreRules.MAX_RING_CORE_TIER) -> void:
	runtime._affinity_state.set_run_ring_core_tier(tier)


func _skill_state_for_runtime_slot(runtime: Object, slot_index: int) -> Object:
	return runtime._companion_skill_persistence.get_state_for_slot(
		runtime._companion_skill_states,
		slot_index
	)


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


func _expect_empty_skill_channel(loadout: Dictionary, channel: String, label: String) -> void:
	var id_key := "%s_skill_id" % channel
	var level_key := "%s_skill_level" % channel
	var ids_key := "%s_skill_ids" % channel
	var slot_count_key := "%s_slot_count" % channel
	_expect_str(str(loadout.get(id_key, "")), "", "%s id" % label)
	_expect_eq(int(loadout.get(level_key, -1)), 0, "%s level" % label)
	_expect_eq((loadout.get(ids_key, []) as Array).size(), 0, "%s ids" % label)
	_expect_eq(int(loadout.get(slot_count_key, -1)), 0, "%s slot count" % label)


func _expect_hatch_roll_channel(loadout: Dictionary, channel: String, expected_skill_id: String, label: String) -> void:
	var id_key := "%s_skill_id" % channel
	var level_key := "%s_skill_level" % channel
	var ids_key := "%s_skill_ids" % channel
	var levels_key := "%s_skill_levels" % channel
	var slot_count_key := "%s_slot_count" % channel
	var skill_id := str(loadout.get(id_key, ""))
	var level := int(loadout.get(level_key, 0))
	var ids: Array = loadout.get(ids_key, []) as Array
	var levels: Dictionary = loadout.get(levels_key, {}) as Dictionary
	var slot_count := int(loadout.get(slot_count_key, 0))
	_expect(level >= 0 and level <= 3, "%s level should stay in hatch roll range 0..3" % label)
	if level > 0:
		_expect_str(skill_id, expected_skill_id, "%s id should match the catalog default when rolled" % label)
		_expect(ids.has(expected_skill_id), "%s ids should include rolled skill" % label)
		_expect_eq(slot_count, 1, "%s slot count should open with a rolled skill" % label)
		_expect_eq(int(levels.get(expected_skill_id, 0)), level, "%s level map should mirror rolled level" % label)
	else:
		_expect_str(skill_id, "", "%s id should stay empty when roll is zero" % label)
		_expect_eq(ids.size(), 0, "%s ids should stay empty when roll is zero" % label)
		_expect_eq(slot_count, 0, "%s slot count should stay zero when roll is zero" % label)


func _expect_hatch_passive_roll_from_pool(loadout: Dictionary, label: String) -> void:
	# The hatch passive identity is a random draw from the shared common passive pool, so assert
	# pool membership + roll shape rather than a fixed id (which grows stale as passives are added).
	var skill_id := str(loadout.get("passive_skill_id", ""))
	var level := int(loadout.get("passive_skill_level", 0))
	var ids: Array = loadout.get("passive_skill_ids", []) as Array
	var levels: Dictionary = loadout.get("passive_skill_levels", {}) as Dictionary
	var slot_count := int(loadout.get("passive_slot_count", 0))
	var pool_ids := _skill_ids(LingpetCatalog.get_passive_skill_pool("lumion"))
	_expect(level >= 0 and level <= 3, "%s level should stay in hatch roll range 0..3" % label)
	if level > 0:
		_expect(pool_ids.has(skill_id), "%s id should be drawn from the common passive pool" % label)
		_expect(ids.has(skill_id), "%s ids should include the rolled passive" % label)
		_expect_eq(slot_count, 1, "%s slot count should open with a rolled passive" % label)
		_expect_eq(int(levels.get(skill_id, 0)), level, "%s level map should mirror rolled level" % label)
	else:
		_expect_str(skill_id, "", "%s id should stay empty when roll is zero" % label)
		_expect_eq(ids.size(), 0, "%s ids should stay empty when roll is zero" % label)
		_expect_eq(slot_count, 0, "%s slot count should stay zero when roll is zero" % label)


func _expect_runtime_channel_matches_loadout(owner: FakeOwner, loadout: Dictionary, channel: String, label: String) -> void:
	var id_key := "%s_skill_id" % channel
	var level_key := "%s_skill_level" % channel
	var ids_key := "%s_skill_ids" % channel
	var levels_key := "%s_skill_levels" % channel
	var slot_count_key := "%s_slot_count" % channel
	var skill_id := str(loadout.get(id_key, ""))
	var level := int(loadout.get(level_key, 0))
	var ids: Array = loadout.get(ids_key, []) as Array
	var levels: Dictionary = loadout.get(levels_key, {}) as Dictionary
	var slot_count := int(loadout.get(slot_count_key, 0))
	_expect_str(str(owner.value_of("lingpet_%s_skill_id" % channel)), skill_id, "%s owner id should mirror loadout" % label)
	_expect_eq(int(owner.value_of("lingpet_%s_skill_level" % channel)), level, "%s owner level should mirror loadout" % label)
	_expect(level >= 0 and level <= 3, "%s level should stay in hatch roll range 0..3" % label)
	if skill_id == "":
		_expect_eq(level, 0, "%s empty id should have zero level" % label)
		_expect_eq(ids.size(), 0, "%s empty id should keep ids empty" % label)
		_expect_eq(slot_count, 0, "%s empty id should keep slot count zero" % label)
	else:
		_expect(level > 0, "%s non-empty id should have positive level" % label)
		_expect(ids.has(skill_id), "%s ids should include the primary skill" % label)
		_expect_eq(slot_count, 1, "%s slot count should open with a primary skill" % label)
		_expect_eq(int(levels.get(skill_id, 0)), level, "%s level map should mirror primary level" % label)


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
