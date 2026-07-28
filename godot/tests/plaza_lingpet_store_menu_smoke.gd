extends SceneTree

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const PlazaLingpetStoreTransactions := preload("res://scripts/plaza/plaza_lingpet_store_transactions.gd")
const PlazaScenePacked := preload("res://scenes/plaza.tscn")
const PlazaSaveStore := preload("res://scripts/plaza/plaza_save_store.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

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
	call_deferred("_run")


func _run() -> void:
	_verify_lingpet_store_runtime_only_sources()
	_verify_lingpet_egg_purchase_spawns_runtime_egg()
	_verify_retired_ring_core_action_is_absent()
	_verify_failed_lingpet_store_actions_do_not_spend_ap()
	_verify_full_roster_allows_egg_purchase_and_routes_to_overflow()

	_cleanup_scene_nodes()
	ProjectResourceLoader.clear_caches()
	await _drain_frames(30)
	ProjectResourceLoader.clear_caches()
	await _drain_frames(5)
	call_deferred("_finish")


func _finish() -> void:
	if _failures.is_empty():
		print("plaza_lingpet_store_menu_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _drain_frames(frame_count: int) -> void:
	for i in frame_count:
		ProjectResourceLoader.try_resolve_finished_threaded_prewarm()
		await process_frame


func _cleanup_scene_nodes() -> void:
	for child in root.get_children():
		if child is SubViewport:
			(child as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
		if is_instance_valid(child):
			child.queue_free()


func _verify_lingpet_store_runtime_only_sources() -> void:
	var transaction_source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_lingpet_store_transactions.gd")
	var message_formatter_source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_transaction_message_formatter.gd")
	_expect(transaction_source.find("lingpet_affinity_store") < 0, "plaza lingpet store transactions should not request the removed affinity store module key")
	_expect(transaction_source.find("LingpetAffinityStore") < 0, "plaza lingpet store transactions should not preload or use the meta-only affinity store")
	_expect(transaction_source.find("upgrade_run_ring_core_tier") < 0, "plaza transactions should not expose the retired ring-core purchase path")
	_expect(message_formatter_source.find("ring_core") < 0, "plaza formatter should not expose retired ring-core outcomes")


func _verify_retired_ring_core_action_is_absent() -> void:
	var save_path := _smoke_save_path("retired_ring_core")
	_cleanup(save_path)
	var store := PlazaSaveStore.new()
	store.set_save_path(save_path)
	store.apply_stage_clear_progress(1, 3000, true)
	var owner := FakeOwner.new()
	root.add_child(owner)
	var registry := FakeRegistry.new({"lingpet_egg_runtime": LingpetEggRuntime.new()})
	var viewport := _build_viewport()
	var scene := _build_scene(viewport, save_path, owner, registry)
	if scene != null:
		_open_building(scene, "lingpet_store")
		var status: Dictionary = scene.get_status()
		var actions: Array = status.get("active_menu_actions", [])
		_expect(actions.size() == 1, "lingpet store should expose only the resonance egg after ring-core retirement")
		var before_gold := int(status.get("plaza_gold", 0))
		var before_ap := int(status.get("ap_current", 0))
		_expect(not scene.trigger_menu_action_for_test(1), "retired ring-core action index should fail closed")
		status = scene.get_status()
		_expect(int(status.get("plaza_gold", 0)) == before_gold, "retired action probe should not mutate gold")
		_expect(int(status.get("ap_current", 0)) == before_ap, "retired action probe should not mutate AP")
	viewport.queue_free()
	owner.queue_free()
	_cleanup(save_path)


func _verify_lingpet_egg_purchase_spawns_runtime_egg() -> void:
	var save_path := _smoke_save_path("egg_purchase")
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
	var required_hits := maxi(1, int(lingpet_runtime.get_snapshot().get("required_hits", owner.lingpet_hatch_required_hits)))
	var egg_pos: Vector2 = owner.lingpet_egg_pos
	for hit_index in range(required_hits):
		_register_hit(lingpet_runtime, owner, egg_pos, hit_index + 1, registry)
	_expect(str(owner.lingpet_state) == "companion", "purchased plaza egg should hatch through the existing ball-hit flow")
	_expect(owner.lingpet_owned_pet_ids.size() == 1, "hatching the plaza egg should grant ownership through the lingpet runtime")
	_expect(str(owner.active_lingpet_id) != "", "hatching the plaza egg should publish the active lingpet id")

	viewport.queue_free()
	owner.queue_free()
	_cleanup(save_path)


func _verify_failed_lingpet_store_actions_do_not_spend_ap() -> void:
	var poor_path := _smoke_save_path("poor")
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


func _verify_full_roster_allows_egg_purchase_and_routes_to_overflow() -> void:
	# Contract (corrected): a FULL 3-slot roster does NOT block the resonance-egg
	# purchase. The plaza egg gate is should_spawn_egg (catalog still has unowned
	# candidates), NOT is_full. Roster-full is resolved at HATCH time by the
	# overflow-replace choice, not by refusing the purchase.
	#
	# History: the prior assertion seeded 12 owned pets and expected the purchase to
	# be blocked with no_hatch_candidates. That state is impossible in production --
	# every owned-write path caps the collection at MAX_OWNED == MAX_BATTLE_SLOTS == 3,
	# so get_owned_pet_ids_from_owner can never represent a collection larger than the
	# 12-pet junior/smasher candidate pool, and should_spawn_egg is (correctly) true.
	var save_path := _smoke_save_path("full_roster_overflow")
	_cleanup(save_path)
	var store := PlazaSaveStore.new()
	store.set_save_path(save_path)
	store.apply_stage_clear_progress(1, 400, true)
	var owner := FakeOwner.new()
	# A real, production-reachable full roster: exactly 3 owned pets filling the 3
	# battle slots (NOT the impossible 12-owned state). The junior/smasher candidate
	# pool is 12, so 9 candidates remain unowned and the egg stays purchasable.
	_seed_full_roster(owner, ["maribo", "lunabi", "milkring"])
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

	_expect(lingpet_runtime._collection_state.is_full(owner), "test setup: a 3-pet roster should read as full")

	# Roster-full-allows-purchase: a full 3-slot roster does NOT block the egg purchase.
	# The purchase succeeds and spawns a field egg; roster-full is resolved later, at
	# HATCH time, by the overflow-replace choice (covered as a focused runtime contract in
	# lingpet_egg_runtime_smoke._verify_main_egg_full_roster_hatch_routes_to_overflow --
	# kept out of this integration smoke so it does not drive the renderer/cut-in path).
	_expect(scene.trigger_menu_action_for_test(0), "full 3-slot roster should still allow the resonance egg purchase")
	var status: Dictionary = scene.get_status()
	_expect(str(owner.lingpet_state) == "egg", "full-roster egg purchase should spawn a field egg")
	_expect(int(status.get("plaza_gold", 0)) == 150, "full-roster egg purchase should subtract 250G")
	_expect(int(status.get("ap_current", 0)) == 3, "full-roster egg purchase should spend one AP")
	var summary: Dictionary = status.get("last_lingpet_store_transaction_summary", {})
	_expect(str(summary.get("reason", "")) == "ok", "full-roster egg purchase should report ok")

	viewport.queue_free()
	owner.queue_free()
	_cleanup(save_path)


func _register_hit(runtime: Object, owner: FakeOwner, egg_pos: Vector2, index: int, registry: Object = null) -> void:
	owner.ball_pos = egg_pos + Vector2(0.0, -90.0)
	owner.ball_vel = Vector2(0.0, 12.0)
	runtime.update(0.21, owner, registry)
	owner.ball_pos = egg_pos + Vector2(float(index), -8.0)
	owner.ball_vel = Vector2(0.0, 12.0)
	runtime.update(0.0, owner, registry)
	# The final counted hit defers the hatch behind the shell-break cinematic
	# (physics held by the modal gate; clock pumped from the ungated idle path).
	# Mirror that pump so post-hatch assertions see the committed state.
	var pump_guard := 0
	while bool(runtime.is_hatch_break_active()) and pump_guard < 300:
		runtime.advance_hatch_break(1.0 / 60.0, owner, registry)
		pump_guard += 1


func _seed_full_roster(owner: FakeOwner, pet_ids: Array) -> void:
	# Seed a production-reachable full roster: the owned collection IS the battle
	# slots (capped at MAX_BATTLE_SLOTS == 3), so fill both with the same pet ids.
	var roster: Array = pet_ids.slice(0, 3)
	owner.lingpet_owned_pet_ids = roster.duplicate()
	owner.owned_lingpet_ids = roster.duplicate()
	owner.lingpet_slots = roster.duplicate()
	owner.lingpet_slot_pet_ids = roster.duplicate()
	owner.lingpet_active_slot_index = 0
	for pet_id in roster:
		owner.lingpet_collection[pet_id] = true
		owner.owned_lingpets[pet_id] = true


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


func _smoke_save_path(slug: String) -> String:
	return "res://.tmp/plaza_lingpet_store_menu_smoke_%s_%d_%d.cfg" % [
		slug,
		OS.get_process_id(),
		Time.get_ticks_usec(),
	]


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
