extends SceneTree

# Self-contained smoke for the MAIN (plaza / field) egg ball-hit hatch path. This is a
# DIFFERENT code path from the item-egg overflow route (_verify_lingpet_egg_overflow_*
# in lingpet_egg_runtime_smoke.gd): it routes through _resolve_ball_hit's is_full branch
# (_begin_overflow_hatch / begin_main_overflow), not begin_item_egg_overflow. The owner /
# registry / hit-seed helpers below are intentionally local copies so this contract does
# not depend on the in-progress lingpet egg-runtime smoke scaffolding.

const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var ai_mode := "junior league"
	var current_stage := 1
	var selected_character_type := "smasher"
	var player_pos := Vector2(263.75, 675.0)
	var player_paddle_width := 232.5
	var player_paddle_height := 75.0
	var boss_pos := Vector2(330.0, 25.0)
	var boss_vel := 0.0
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0
	var lingpet_puppet_grab_active := false
	var lingpet_star_coil_boss_slow_active := false
	var lingpet_star_coil_boss_slow_multiplier := 1.0
	var lingpet_star_coil_block_boss_dash := false
	var lingpet_star_coil_freeze_boss_skill_cd := false
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
	var lingpet_second_active_skill_id := ""
	var ringpet_second_active_skill_id := ""
	var lingpet_second_active_skill_level := 0
	var ringpet_second_active_skill_level := 0
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
	var lingpet_second_skill_id := ""
	var ringpet_second_skill_id := ""
	var lingpet_second_skill_name := ""
	var ringpet_second_skill_name := ""
	var lingpet_second_skill_max_level := 0
	var ringpet_second_skill_max_level := 0
	var lingpet_second_skill_cooldown := 0.0
	var ringpet_second_skill_cooldown := 0.0
	var lingpet_second_skill_cooldown_duration := 0.0
	var ringpet_second_skill_cooldown_duration := 0.0
	var lingpet_second_skill_ready := false
	var ringpet_second_skill_ready := false
	var lingpet_second_skill_winding_up := false
	var ringpet_second_skill_winding_up := false
	var lingpet_second_skill_windup_ratio := 0.0
	var ringpet_second_skill_windup_ratio := 0.0
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

	func _init(next_instances: Dictionary = {}) -> void:
		instances = next_instances

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		if value is Object:
			return value
		return null




func _init() -> void:
	_verify_main_egg_replace_keeps_one_live_guardian()
	_verify_main_egg_absorb_uses_shared_enhancement()

	if _failures.is_empty():
		print("lingpet_main_egg_overflow_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_main_egg_replace_keeps_one_live_guardian() -> void:
	var owner := FakeOwner.new()
	_seed_lingpet_roster(owner, ["maribo"], 0)
	var registry := FakeRegistry.new({})
	var runtime: Object = LingpetEggRuntime.new()
	runtime._guardian_run_state.set_duration_pool_for_tests(31.0, 42.0)
	_open_main_egg_choice(runtime, owner, registry)
	_expect((owner.lingpet_owned_pet_ids as Array).size() == 1, "pending hatch must not exceed the one-guardian live cap")
	var snapshot: Dictionary = runtime.get_overflow_choice_snapshot()
	var pending_pet := str(snapshot.get("pending_pet_id", ""))
	_expect(pending_pet != "" and pending_pet != "maribo", "replace choice should carry a new pending guardian")
	_expect(not (owner.lingpet_owned_pet_ids as Array).has(pending_pet), "the pending pet must not be owned before the choice commits")
	_expect(bool(runtime.commit_overflow_replace(0, owner, registry)), "replace should commit through live slot zero")
	_expect(not bool(runtime.is_overflow_choice_active()), "committing the replace should close the overflow choice")
	_expect((owner.lingpet_owned_pet_ids as Array).size() == 1, "replace must leave exactly one live guardian")
	_expect((owner.lingpet_owned_pet_ids as Array).has(pending_pet), "the replaced-in pet should now be owned")
	_expect(bool(owner.lingpet_collection.get("maribo", false)), "replace must preserve the old guardian in permanent collection history")
	_expect(bool(owner.lingpet_collection.get(pending_pet, false)), "replace must record the incoming guardian in permanent collection history")
	_expect(is_equal_approx(runtime._guardian_run_state.get_duration_pool_current(), 31.0), "replace must preserve the run-owned duration current value")
	_expect(is_equal_approx(runtime._guardian_run_state.get_duration_pool_max(), 42.0), "replace must preserve the run-owned duration maximum")


func _verify_main_egg_absorb_uses_shared_enhancement() -> void:
	var owner := FakeOwner.new()
	_seed_lingpet_roster(owner, ["maribo"], 0)
	var registry := FakeRegistry.new({})
	var runtime: Object = LingpetEggRuntime.new()
	_open_main_egg_choice(runtime, owner, registry)
	var snapshot: Dictionary = runtime.get_overflow_choice_snapshot()
	var pending_pet := str(snapshot.get("pending_pet_id", ""))
	_expect(bool(runtime.commit_overflow_absorb(owner, registry)), "absorb should resolve through the shared enhancement path")
	_expect(not bool(runtime.is_overflow_choice_active()), "absorb should close the roster choice")
	_expect((owner.lingpet_owned_pet_ids as Array) == ["maribo"], "absorb must keep the current live guardian")
	_expect(bool(owner.lingpet_collection.get(pending_pet, false)), "absorbed guardian must remain in permanent collection history")
	var result: Dictionary = runtime.get_guardian_enhance_last_result_for_tests()
	_expect(bool(result.get("accepted", false)), "absorb must apply exactly one accepted Guardian Enhancement result")
	_expect(str(result.get("trigger_source", "")) == "absorb", "absorb result must identify its source without a parallel reward UI")
	_expect(str(result.get("trigger_source_label", "")).strip_edges() != "", "absorb result must carry localized source copy")
	_expect(bool(runtime.is_guardian_enhance_cutin_active()), "absorb must reuse the compact Guardian Enhancement panel")


func _open_main_egg_choice(runtime: Object, owner: FakeOwner, registry: FakeRegistry) -> void:
	_expect(
		bool(runtime.debug_grant_and_activate_pet("maribo", owner, false, "", "", registry)),
		"fixture must activate the current one-slot guardian before opening another egg"
	)
	var spawn_result: Dictionary = runtime.spawn_plaza_resonance_egg(owner, registry)
	_expect(bool(spawn_result.get("changed", false)), "one occupied live slot must not block a new resonance egg")
	owner.ball_active = true
	owner.ball_serve_origin = "boss"
	var egg_pos: Vector2 = owner.lingpet_egg_pos
	var required_hits := maxi(1, int(owner.lingpet_hatch_required_hits))
	# Keep this seal about the real final-hit path, not about random 2-4 hit fixture
	# timing: arm the production egg state one count below its own rolled threshold.
	runtime._egg_state.hatch_hits = required_hits - 1
	runtime._egg_state.hit_cooldown = 0.0
	runtime._egg_state.ball_was_inside = false
	_register_hit(runtime, owner, egg_pos, 1, registry)
	_expect(bool(runtime.is_hatch_break_active()), "final hit should start the shell-break sequence")
	var pump_guard := 0
	while bool(runtime.is_hatch_break_active()) and pump_guard < 300:
		runtime.advance_hatch_break(1.0 / 60.0, owner, registry)
		pump_guard += 1
	_expect(bool(runtime.is_acquire_cutin_active()), "shell-break commit should open the acquisition cut-in")
	runtime.dismiss_acquire_cutin()
	_expect(bool(runtime.is_overflow_choice_active()), "additional hatch should open Replace / Absorb choice")


func _register_hit(runtime: Object, owner: FakeOwner, egg_pos: Vector2, index: int, registry: Object = null) -> void:
	owner.ball_pos = egg_pos + Vector2(0.0, -90.0)
	owner.ball_vel = Vector2(0.0, 12.0)
	runtime.update(0.21, owner, registry)
	owner.ball_pos = egg_pos + Vector2(float(index), -8.0)
	owner.ball_vel = Vector2(0.0, 12.0)
	runtime.update(0.0, owner, registry)


func _seed_lingpet_roster(owner: Object, pet_ids: Array[String], active_slot_index: int = 0) -> void:
	var ids: Array = pet_ids.duplicate()
	var collection: Dictionary = {}
	for pet_id in ids:
		collection[pet_id] = true
	owner.lingpet_owned_pet_ids = ids.duplicate()
	owner.owned_lingpet_ids = ids.duplicate()
	owner.owned_ringpet_ids = ids.duplicate()
	owner.lingpet_collection = collection.duplicate(true)
	owner.ringpet_collection = collection.duplicate(true)
	owner.owned_lingpets = collection.duplicate(true)
	owner.owned_ringpets = collection.duplicate(true)
	owner.lingpet_slots = ids.duplicate()
	while owner.lingpet_slots.size() < 3:
		owner.lingpet_slots.append("")
	owner.ringpet_slots = owner.lingpet_slots.duplicate()
	owner.lingpet_slot_pet_ids = owner.lingpet_slots.duplicate()
	owner.ringpet_slot_pet_ids = owner.lingpet_slots.duplicate()
	owner.lingpet_active_slot_index = active_slot_index
	owner.ringpet_active_slot_index = active_slot_index



func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
