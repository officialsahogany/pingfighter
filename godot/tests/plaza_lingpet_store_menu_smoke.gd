extends SceneTree

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetAffinityStore := preload("res://scripts/lingpet/lingpet_affinity_store.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const PlazaLingpetStoreTransactions := preload("res://scripts/plaza/plaza_lingpet_store_transactions.gd")
const PlazaScenePacked := preload("res://scenes/plaza.tscn")
const PlazaSaveStore := preload("res://scripts/plaza/plaza_save_store.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends Node2D

	var ai_mode := "junior league"
	var selected_character_type := "smasher"
	var player_pos := Vector2(263.75, 675.0)
	var player_paddle_width := 232.5
	var player_paddle_height := 75.0
	var boss_pos := Vector2(330.0, 25.0)
	var boss_vel := 0.0
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0
	var lingpet_puppet_grab_active := false
	var ball_active := false
	var ball_pos := Vector2.ZERO
	var ball_pos_prev := Vector2.ZERO
	var ball_vel := Vector2.ZERO
	var ball_serve_origin := ""
	var ball_size := 28.6
	var rally_speed_cap_bonus := 0.0
	var special_gauge := 100.0
	var special_gauge_max := 500.0
	var lingpet_id := ""
	var active_lingpet_id := ""
	var current_lingpet_id := ""
	var lingpet_state := "none"
	var ringpet_state := "none"
	var lingpet_hatch_hits := 0
	var ringpet_hatch_hits := 0
	var lingpet_hatch_required_hits := 3
	var ringpet_hatch_required_hits := 3
	var lingpet_egg_pos := Vector2.ZERO
	var lingpet_companion_pos := Vector2.ZERO
	var ringpet_companion_pos := Vector2.ZERO
	var lingpet_companion_patrol_speed_default := 120.0
	var ringpet_companion_patrol_speed_default := 120.0
	var lingpet_companion_patrol_speed_min := 70.0
	var ringpet_companion_patrol_speed_min := 70.0
	var lingpet_companion_patrol_speed_max := 135.0
	var ringpet_companion_patrol_speed_max := 135.0
	var lingpet_companion_catch_width := 100.0
	var ringpet_companion_catch_width := 100.0
	var lingpet_companion_catch_height := 44.0
	var ringpet_companion_catch_height := 44.0
	var lingpet_companion_defense_rate := 0.0
	var ringpet_companion_defense_rate := 0.0
	var lingpet_companion_appearance_rate := 0.0
	var ringpet_companion_appearance_rate := 0.0
	var lingpet_affinity_level := 0
	var ringpet_affinity_level := 0
	var lingpet_affinity_points := 0.0
	var ringpet_affinity_points := 0.0
	var lingpet_affinity_next_requirement := 0.0
	var ringpet_affinity_next_requirement := 0.0
	var lingpet_affinity_next_label := ""
	var ringpet_affinity_next_label := ""
	var lingpet_bond_points := 0
	var ringpet_bond_points := 0
	var lingpet_bond_title := ""
	var ringpet_bond_title := ""
	var lingpet_companion_defense_intercept_active := false
	var ringpet_companion_defense_intercept_active := false
	var lingpet_companion_defense_intercept_target_x := 0.0
	var ringpet_companion_defense_intercept_target_x := 0.0
	var lingpet_companion_contact_count := 0
	var ringpet_companion_contact_count := 0
	var lingpet_companion_last_contact_pos := Vector2.ZERO
	var ringpet_companion_last_contact_pos := Vector2.ZERO
	var lingpet_companion_hit_cooldown := 0.0
	var ringpet_companion_hit_cooldown := 0.0
	var lingpet_companion_hit_gauge_gain := 0.0
	var ringpet_companion_hit_gauge_gain := 0.0
	var lingpet_companion_hit_gauge_last_gain := 0.0
	var ringpet_companion_hit_gauge_last_gain := 0.0
	var lingpet_companion_hit_gauge_trigger_count := 0
	var ringpet_companion_hit_gauge_trigger_count := 0
	var lingpet_skill_id := ""
	var ringpet_skill_id := ""
	var lingpet_active_skill_id := ""
	var ringpet_active_skill_id := ""
	var lingpet_active_skill_level := 0
	var ringpet_active_skill_level := 0
	var lingpet_active_skill_max_level := 0
	var ringpet_active_skill_max_level := 0
	var lingpet_skill_name := ""
	var ringpet_skill_name := ""
	var lingpet_skill_cooldown := 0.0
	var ringpet_skill_cooldown := 0.0
	var lingpet_skill_cooldown_duration := 40.0
	var ringpet_skill_cooldown_duration := 40.0
	var lingpet_skill_ready := false
	var ringpet_skill_ready := false
	var lingpet_skill_last_gain := 0.0
	var ringpet_skill_last_gain := 0.0
	var lingpet_skill_trigger_count := 0
	var ringpet_skill_trigger_count := 0
	var lingpet_skill_icon_path := ""
	var ringpet_skill_icon_path := ""
	var lingpet_passive_skill_id := ""
	var ringpet_passive_skill_id := ""
	var lingpet_passive_skill_level := 0
	var ringpet_passive_skill_level := 0
	var lingpet_passive_skill_max_level := 0
	var ringpet_passive_skill_max_level := 0
	var lingpet_passive_skill_name := ""
	var ringpet_passive_skill_name := ""
	var lingpet_passive_skill_description := ""
	var ringpet_passive_skill_description := ""
	var lingpet_passive_skill_icon_path := ""
	var ringpet_passive_skill_icon_path := ""
	var lingpet_gauge_gain_bonus_pct := 0.0
	var ringpet_gauge_gain_bonus_pct := 0.0
	var lingpet_player_speed_bonus_pct := 0.0
	var ringpet_player_speed_bonus_pct := 0.0
	var lingpet_starpoint_tracking_chance_pct := 0.0
	var ringpet_starpoint_tracking_chance_pct := 0.0
	var lingpet_ring_dash_chance_pct := 0.0
	var ringpet_ring_dash_chance_pct := 0.0
	var lingpet_ring_dash_force_roll_pct := -1.0
	var lingpet_effect_text := ""
	var lingpet_owned_pet_ids: Array = []
	var owned_lingpet_ids: Array = []
	var owned_ringpet_ids: Array = []
	var lingpet_collection: Dictionary = {}
	var ringpet_collection: Dictionary = {}
	var owned_lingpets: Dictionary = {}
	var owned_ringpets: Dictionary = {}
	var lingpet_loadouts: Dictionary = {}
	var ringpet_loadouts: Dictionary = {}
	var owned_lingpet_loadouts: Dictionary = {}
	var owned_ringpet_loadouts: Dictionary = {}
	var lingpet_slots: Array = ["", "", ""]
	var ringpet_slots: Array = ["", "", ""]
	var lingpet_slot_pet_ids: Array = ["", "", ""]
	var ringpet_slot_pet_ids: Array = ["", "", ""]
	var lingpet_active_slot_index := 0
	var ringpet_active_slot_index := 0


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(next_instances: Dictionary) -> void:
		instances = next_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	_run()


func _run() -> void:
	_verify_lingpet_egg_purchase_spawns_runtime_egg()
	_verify_lingpet_ring_core_purchase_upgrades_account_cap()
	_verify_failed_lingpet_store_actions_do_not_spend_ap()
	_verify_failed_lingpet_ring_core_actions_do_not_mutate_wallet_or_tier()

	if _failures.is_empty():
		print("plaza_lingpet_store_menu_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_lingpet_egg_purchase_spawns_runtime_egg() -> void:
	var save_path := "user://plaza_lingpet_store_menu_smoke.cfg"
	_cleanup(save_path)
	var store := PlazaSaveStore.new()
	store.set_save_path(save_path)
	store.apply_stage_clear_progress(1, 400, true)
	var owner := FakeOwner.new()
	root.add_child(owner)
	var lingpet_runtime: Object = LingpetEggRuntime.new()
	var registry := FakeRegistry.new({"lingpet_egg_runtime": lingpet_runtime})

	var viewport := _build_viewport()
	var scene := _build_scene(viewport, save_path, owner, registry)
	if scene == null:
		viewport.queue_free()
		owner.queue_free()
		_cleanup(save_path)
		return
	_open_building(scene, "lingpet_store")
	var status: Dictionary = scene.get_status()
	_expect(str(status.get("active_menu_type", "")) == "lingpet_store", "lingpet store interaction should open the menu")
	_expect(int(status.get("plaza_gold", 0)) == 400, "lingpet store should read preloaded plaza gold")
	_expect(int(status.get("ap_current", 0)) == 4, "lingpet store should read preloaded AP")

	_expect(scene.trigger_menu_action_for_test(0), "resonance egg purchase should execute")
	status = scene.get_status()
	_expect(int(status.get("plaza_gold", 0)) == 150, "lingpet egg purchase should subtract 250G")
	_expect(int(status.get("ap_current", 0)) == 3, "first lingpet egg purchase should spend one AP")
	_expect(bool(status.get("active_menu_visit_ap_consumed", false)), "lingpet store visit should remember AP was consumed")
	_expect(str(owner.lingpet_state) == "egg", "lingpet egg purchase should put the runtime in egg state")
	_expect(str(owner.lingpet_id) == "" and str(owner.active_lingpet_id) == "" and str(owner.current_lingpet_id) == "", "pre-hatch plaza egg should not publish the hidden pet identity")
	_expect(owner.lingpet_owned_pet_ids.is_empty(), "plaza egg purchase should not directly grant ownership")
	_expect(owner.lingpet_egg_pos is Vector2 and owner.lingpet_egg_pos != Vector2.ZERO, "plaza egg purchase should publish a field egg position")
	var first_summary: Dictionary = status.get("last_lingpet_store_transaction_summary", {})
	_expect(str(first_summary.get("reason", "")) == "ok", "lingpet egg summary should report ok")

	_expect(not scene.trigger_menu_action_for_test(0), "active egg should block duplicate egg purchases")
	status = scene.get_status()
	_expect(int(status.get("plaza_gold", 0)) == 150, "duplicate egg purchase should leave gold unchanged")
	_expect(int(status.get("ap_current", 0)) == 3, "duplicate egg purchase should not spend AP")

	owner.ball_active = true
	owner.ball_serve_origin = "boss"
	var required_hits := maxi(1, int(owner.lingpet_hatch_required_hits))
	var egg_pos: Vector2 = owner.lingpet_egg_pos
	for hit_index in range(required_hits):
		_register_hit(lingpet_runtime, owner, egg_pos, hit_index + 1, registry)
	_expect(str(owner.lingpet_state) == "companion", "purchased plaza egg should hatch through the existing ball-hit flow")
	_expect(owner.lingpet_owned_pet_ids.size() == 1, "hatching the plaza egg should grant ownership through the lingpet runtime")
	_expect(str(owner.active_lingpet_id) != "", "hatching the plaza egg should publish the active lingpet id")

	viewport.queue_free()
	owner.queue_free()
	_cleanup(save_path)


func _verify_lingpet_ring_core_purchase_upgrades_account_cap() -> void:
	var save_path := "user://plaza_lingpet_store_ring_core_smoke.cfg"
	var affinity_path := "user://plaza_lingpet_store_ring_core_affinity_smoke.cfg"
	_cleanup(save_path)
	_cleanup(affinity_path)
	var store := PlazaSaveStore.new()
	store.set_save_path(save_path)
	store.apply_stage_clear_progress(1, 3000, true)
	var affinity_store := LingpetAffinityStore.new()
	affinity_store.set_save_path(affinity_path)
	_expect(bool(affinity_store.set_ring_core_tier(0)), "ring-core fixture should start from explicit no-core tier")
	var owner := FakeOwner.new()
	root.add_child(owner)
	var lingpet_runtime: Object = LingpetEggRuntime.new()
	var registry := FakeRegistry.new({
		"lingpet_egg_runtime": lingpet_runtime,
		"lingpet_affinity_store": affinity_store,
	})

	var viewport := _build_viewport()
	var scene := _build_scene(viewport, save_path, owner, registry)
	if scene == null:
		viewport.queue_free()
		owner.queue_free()
		_cleanup(save_path)
		_cleanup(affinity_path)
		return
	_open_building(scene, "lingpet_store")
	var status: Dictionary = scene.get_status()
	var actions: Array = status.get("active_menu_actions", [])
	_expect(actions.size() >= 2, "lingpet store should expose egg and ring-core actions")
	_expect(str(actions[0]).find(str(PlazaLingpetStoreTransactions.EGG_COST)) >= 0, "dynamic lingpet labels should keep the egg purchase cost")
	_expect(str(actions[1]).find("150") >= 0, "tier-1 ring-core action should show the standard price")

	_expect(scene.trigger_menu_action_for_test(1), "standard ring-core purchase should execute")
	status = scene.get_status()
	var first_summary: Dictionary = status.get("last_lingpet_store_transaction_summary", {})
	_expect(str(first_summary.get("action", "")) == "ring_core", "ring-core purchase should report the ring_core action")
	_expect(str(first_summary.get("reason", "")) == "ok", "ring-core purchase should report ok")
	_expect(int(first_summary.get("new_tier", 0)) == 1, "standard purchase should move to tier 1")
	_expect(int(first_summary.get("new_cap", 0)) == 5, "standard purchase should unlock affinity cap 5")
	_expect(int(first_summary.get("delta_gold", 0)) == -150, "standard purchase should subtract 150G")
	_expect(int(first_summary.get("ap_spent", 0)) == 1, "first ring-core purchase should spend one AP")
	_expect(int(status.get("plaza_gold", 0)) == 2850, "standard purchase should update plaza gold")
	_expect(int(status.get("ap_current", 0)) == 3, "standard purchase should update AP")
	_expect(bool(status.get("active_menu_visit_ap_consumed", false)), "ring-core purchase should mark the lingpet-store AP visit")
	_expect(int(affinity_store.get_ring_core_tier()) == 1, "standard purchase should persist tier 1")
	_expect(int(affinity_store.get_ring_core_cap()) == 5, "standard purchase should expose cap 5")
	actions = status.get("active_menu_actions", [])
	_expect(actions.size() >= 2 and str(actions[1]).find("300") >= 0, "post-purchase ring-core label should refresh to the boost price")

	_expect(scene.trigger_menu_action_for_test(1), "same-visit boost ring-core purchase should execute")
	status = scene.get_status()
	var second_summary: Dictionary = status.get("last_lingpet_store_transaction_summary", {})
	_expect(int(second_summary.get("new_tier", 0)) == 2, "second purchase should move to tier 2")
	_expect(int(second_summary.get("new_cap", 0)) == 10, "boost purchase should unlock affinity cap 10")
	_expect(int(second_summary.get("delta_gold", 0)) == -300, "boost purchase should subtract 300G")
	_expect(int(second_summary.get("ap_spent", 0)) == 0, "same lingpet-store visit should not spend a second AP")
	_expect(int(status.get("plaza_gold", 0)) == 2550, "boost purchase should update plaza gold")
	_expect(int(status.get("ap_current", 0)) == 3, "boost purchase should keep AP after the first visit spend")
	_expect(int(affinity_store.get_ring_core_tier()) == 2, "boost purchase should persist tier 2")
	_expect(int(affinity_store.get_ring_core_cap()) == 10, "boost purchase should expose cap 10")

	viewport.queue_free()
	owner.queue_free()
	_cleanup(save_path)
	_cleanup(affinity_path)


func _verify_failed_lingpet_store_actions_do_not_spend_ap() -> void:
	var poor_path := "user://plaza_lingpet_store_menu_smoke_poor.cfg"
	_cleanup(poor_path)
	var poor_store := PlazaSaveStore.new()
	poor_store.set_save_path(poor_path)
	poor_store.apply_stage_clear_progress(1, 100, true)
	var poor_owner := FakeOwner.new()
	root.add_child(poor_owner)
	var poor_runtime: Object = LingpetEggRuntime.new()
	var poor_registry := FakeRegistry.new({"lingpet_egg_runtime": poor_runtime})
	var poor_viewport := _build_viewport()
	var poor_scene := _build_scene(poor_viewport, poor_path, poor_owner, poor_registry)
	if poor_scene == null:
		poor_viewport.queue_free()
		poor_owner.queue_free()
		_cleanup(poor_path)
		return
	_open_building(poor_scene, "lingpet_store")
	_expect(not poor_scene.trigger_menu_action_for_test(0), "unaffordable lingpet egg should fail")
	var status: Dictionary = poor_scene.get_status()
	_expect(str(poor_owner.lingpet_state) == "none", "failed lingpet egg purchase should not spawn an egg")
	_expect(int(status.get("plaza_gold", 0)) == 100, "failed lingpet egg purchase should leave gold unchanged")
	_expect(int(status.get("ap_current", 0)) == 4, "failed lingpet egg purchase should not spend AP")
	poor_viewport.queue_free()
	poor_owner.queue_free()
	_cleanup(poor_path)

	var full_path := "user://plaza_lingpet_store_menu_smoke_full_collection.cfg"
	_cleanup(full_path)
	var full_store := PlazaSaveStore.new()
	full_store.set_save_path(full_path)
	full_store.apply_stage_clear_progress(1, 400, true)
	var full_owner := FakeOwner.new()
	_seed_all_hatch_candidates_as_owned(full_owner)
	root.add_child(full_owner)
	var full_runtime: Object = LingpetEggRuntime.new()
	var full_registry := FakeRegistry.new({"lingpet_egg_runtime": full_runtime})
	var full_viewport := _build_viewport()
	var full_scene := _build_scene(full_viewport, full_path, full_owner, full_registry)
	if full_scene == null:
		full_viewport.queue_free()
		full_owner.queue_free()
		_cleanup(full_path)
		return
	_open_building(full_scene, "lingpet_store")
	_expect(not full_scene.trigger_menu_action_for_test(0), "owned-full collection should block new egg purchases")
	status = full_scene.get_status()
	_expect(str(full_owner.lingpet_state) == "none", "full collection failure should not spawn an egg")
	_expect(int(status.get("plaza_gold", 0)) == 400, "full collection failure should leave gold unchanged")
	_expect(int(status.get("ap_current", 0)) == 4, "full collection failure should not spend AP")
	var full_summary: Dictionary = status.get("last_lingpet_store_transaction_summary", {})
	_expect(str(full_summary.get("reason", "")) == "no_hatch_candidates", "full collection failure should report no_hatch_candidates")

	full_viewport.queue_free()
	full_owner.queue_free()
	_cleanup(full_path)


func _verify_failed_lingpet_ring_core_actions_do_not_mutate_wallet_or_tier() -> void:
	var poor_save_path := "user://plaza_lingpet_store_ring_core_poor_smoke.cfg"
	var poor_affinity_path := "user://plaza_lingpet_store_ring_core_poor_affinity_smoke.cfg"
	_cleanup(poor_save_path)
	_cleanup(poor_affinity_path)
	var poor_store := PlazaSaveStore.new()
	poor_store.set_save_path(poor_save_path)
	poor_store.apply_stage_clear_progress(1, 100, true)
	var poor_affinity := LingpetAffinityStore.new()
	poor_affinity.set_save_path(poor_affinity_path)
	poor_affinity.set_ring_core_tier(0)
	var poor_owner := FakeOwner.new()
	root.add_child(poor_owner)
	var poor_registry := FakeRegistry.new({
		"lingpet_egg_runtime": LingpetEggRuntime.new(),
		"lingpet_affinity_store": poor_affinity,
	})
	var poor_viewport := _build_viewport()
	var poor_scene := _build_scene(poor_viewport, poor_save_path, poor_owner, poor_registry)
	if poor_scene != null:
		_open_building(poor_scene, "lingpet_store")
		_expect(not poor_scene.trigger_menu_action_for_test(1), "unaffordable ring-core purchase should fail")
		var poor_status: Dictionary = poor_scene.get_status()
		var poor_summary: Dictionary = poor_status.get("last_lingpet_store_transaction_summary", {})
		_expect(str(poor_summary.get("reason", "")) == "not_enough_gold", "unaffordable ring-core purchase should report not_enough_gold")
		_expect(int(poor_status.get("plaza_gold", 0)) == 100, "unaffordable ring-core purchase should leave gold unchanged")
		_expect(int(poor_status.get("ap_current", 0)) == 4, "unaffordable ring-core purchase should not spend AP")
		_expect(int(poor_affinity.get_ring_core_tier()) == 0, "unaffordable ring-core purchase should leave tier unchanged")
	poor_viewport.queue_free()
	poor_owner.queue_free()
	_cleanup(poor_save_path)
	_cleanup(poor_affinity_path)

	var max_save_path := "user://plaza_lingpet_store_ring_core_max_smoke.cfg"
	var max_affinity_path := "user://plaza_lingpet_store_ring_core_max_affinity_smoke.cfg"
	_cleanup(max_save_path)
	_cleanup(max_affinity_path)
	var max_store := PlazaSaveStore.new()
	max_store.set_save_path(max_save_path)
	max_store.apply_stage_clear_progress(1, 3000, true)
	var max_affinity := LingpetAffinityStore.new()
	max_affinity.set_save_path(max_affinity_path)
	max_affinity.set_ring_core_tier(LingpetAffinityStore.MAX_RING_CORE_TIER)
	var max_owner := FakeOwner.new()
	root.add_child(max_owner)
	var max_registry := FakeRegistry.new({
		"lingpet_egg_runtime": LingpetEggRuntime.new(),
		"lingpet_affinity_store": max_affinity,
	})
	var max_viewport := _build_viewport()
	var max_scene := _build_scene(max_viewport, max_save_path, max_owner, max_registry)
	if max_scene != null:
		_open_building(max_scene, "lingpet_store")
		_expect(not max_scene.trigger_menu_action_for_test(1), "max-tier ring-core purchase should fail")
		var max_status: Dictionary = max_scene.get_status()
		var max_summary: Dictionary = max_status.get("last_lingpet_store_transaction_summary", {})
		_expect(str(max_summary.get("reason", "")) == "max_ring_core_tier", "max-tier ring-core purchase should report max_ring_core_tier")
		_expect(int(max_status.get("plaza_gold", 0)) == 3000, "max-tier ring-core purchase should leave gold unchanged")
		_expect(int(max_status.get("ap_current", 0)) == 4, "max-tier ring-core purchase should not spend AP")
		_expect(int(max_affinity.get_ring_core_tier()) == LingpetAffinityStore.MAX_RING_CORE_TIER, "max-tier ring-core purchase should leave tier unchanged")
	max_viewport.queue_free()
	max_owner.queue_free()
	_cleanup(max_save_path)
	_cleanup(max_affinity_path)

	var missing_save_path := "user://plaza_lingpet_store_ring_core_missing_smoke.cfg"
	_cleanup(missing_save_path)
	var missing_store := PlazaSaveStore.new()
	missing_store.set_save_path(missing_save_path)
	missing_store.apply_stage_clear_progress(1, 3000, true)
	var missing_owner := FakeOwner.new()
	root.add_child(missing_owner)
	var missing_registry := FakeRegistry.new({"lingpet_egg_runtime": LingpetEggRuntime.new()})
	var missing_viewport := _build_viewport()
	var missing_scene := _build_scene(missing_viewport, missing_save_path, missing_owner, missing_registry)
	if missing_scene != null:
		_open_building(missing_scene, "lingpet_store")
		_expect(not missing_scene.trigger_menu_action_for_test(1), "missing affinity store should block ring-core purchase")
		var missing_status: Dictionary = missing_scene.get_status()
		var missing_summary: Dictionary = missing_status.get("last_lingpet_store_transaction_summary", {})
		_expect(str(missing_summary.get("reason", "")) == "missing_affinity_store", "missing affinity store should report missing_affinity_store")
		_expect(int(missing_status.get("plaza_gold", 0)) == 3000, "missing affinity store should leave gold unchanged")
		_expect(int(missing_status.get("ap_current", 0)) == 4, "missing affinity store should not spend AP")
	missing_viewport.queue_free()
	missing_owner.queue_free()
	_cleanup(missing_save_path)


func _register_hit(runtime: Object, owner: FakeOwner, egg_pos: Vector2, index: int, registry: Object = null) -> void:
	owner.ball_pos = egg_pos + Vector2(0.0, -90.0)
	owner.ball_vel = Vector2(0.0, 12.0)
	runtime.update(0.21, owner, registry)
	owner.ball_pos = egg_pos + Vector2(float(index), -8.0)
	owner.ball_vel = Vector2(0.0, 12.0)
	runtime.update(0.0, owner, registry)


func _seed_all_hatch_candidates_as_owned(owner: FakeOwner) -> void:
	var candidates: Array[String] = LingpetCatalog.get_hatch_candidates({
		"league_mode": "junior",
		"character_type": "smasher",
	}, [])
	owner.lingpet_owned_pet_ids = candidates.duplicate()
	owner.owned_lingpet_ids = candidates.duplicate()
	owner.owned_ringpet_ids = candidates.duplicate()
	for pet_id in candidates:
		owner.lingpet_collection[pet_id] = true
		owner.ringpet_collection[pet_id] = true
		owner.owned_lingpets[pet_id] = true
		owner.owned_ringpets[pet_id] = true


func _build_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(760, 750)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	return viewport


func _build_scene(viewport: SubViewport, save_path: String, owner: Object, registry: Object) -> Control:
	var scene := PlazaScenePacked.instantiate() as Control
	_expect(scene != null, "plaza scene should instantiate for lingpet store smoke")
	if scene == null:
		return null
	viewport.add_child(scene)
	scene.configure({
		"current_stage": 1,
		"plaza_save_path": save_path,
		"full_layout_for_test": true,
		"runtime_owner": owner,
		"runtime_registry": registry,
	}, Callable(), true)
	scene.update_plaza(1.0 / 60.0)
	return scene


func _open_building(scene: Control, building_type: String) -> void:
	var building: Dictionary = _find_building(scene.get_building_specs_for_test(), building_type)
	_expect(not building.is_empty(), "plaza should include a %s building" % building_type)
	if building.is_empty():
		return
	var interaction_rect: Rect2 = building.get("interaction_rect", Rect2())
	var ground_y := float(scene.get_status().get("ground_y", 0.0))
	scene.set_player_pos_for_test(Vector2(interaction_rect.get_center().x, ground_y))
	_expect(scene.trigger_interaction_for_test(), "%s interaction should open the menu" % building_type)


func _find_building(specs: Array[Dictionary], building_type: String) -> Dictionary:
	for spec in specs:
		if str(spec.get("type", "")) == building_type:
			return spec
	return {}


func _cleanup(path: String) -> void:
	var backup_path := path.trim_suffix(".cfg") + ".last_good.cfg"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
