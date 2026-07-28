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
	_verify_main_egg_full_roster_hatch_routes_to_overflow()

	if _failures.is_empty():
		print("lingpet_main_egg_overflow_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_main_egg_full_roster_hatch_routes_to_overflow() -> void:
	# A full 3-slot roster does NOT block the resonance-egg purchase: the gate is
	# should_spawn_egg (the 12-pet junior/smasher pool still has 9 unowned candidates),
	# NOT is_full. Roster-full is resolved at HATCH time by the overflow-replace choice
	# instead of silently exceeding the MAX_OWNED == 3 cap.
	var full_roster: Array[String] = ["maribo", "lunabi", "milkring"]
	var owner := FakeOwner.new()
	_seed_lingpet_roster(owner, full_roster, 0)
	var registry := FakeRegistry.new({})
	var runtime: Object = LingpetEggRuntime.new()

	var spawn_result: Dictionary = runtime.spawn_plaza_resonance_egg(owner, registry)
	_expect(bool(spawn_result.get("changed", false)), "full roster should still spawn a plaza resonance egg")
	_expect(str(owner.lingpet_state) == "egg", "plaza egg purchase at full roster should enter the egg state")

	owner.ball_active = true
	owner.ball_serve_origin = "boss"
	var egg_pos: Vector2 = owner.lingpet_egg_pos
	var required_hits := maxi(1, int(owner.lingpet_hatch_required_hits))
	for hit_index in range(required_hits):
		_register_hit(runtime, owner, egg_pos, hit_index + 1, registry)
	# The final counted hit no longer opens the cut-in on the same frame: the
	# shell-break cinematic (roll / staged cracks / burst hold) runs first while
	# the modal gate holds battle physics, and only its deferred commit opens
	# the acquire cut-in.
	_expect(bool(runtime.is_hatch_break_active()), "the final counted hit should start the shell-break sequence, not the cut-in")
	_expect(not bool(runtime.is_acquire_cutin_active()), "the acquire cut-in must not open before the shell-break sequence commits")
	_expect(not bool(runtime.is_overflow_choice_active()), "the overflow choice must stay closed until the deferred hatch commits")
	var pump_guard := 0
	while bool(runtime.is_hatch_break_active()) and pump_guard < 300:
		runtime.advance_hatch_break(1.0 / 60.0, owner, registry)
		pump_guard += 1
	_expect(not bool(runtime.is_hatch_break_active()), "the shell-break sequence should complete within its time budget")
	_expect(bool(runtime.is_acquire_cutin_active()), "the shell-break commit should open the acquire cut-in")
	# The full-roster hatch starts the acquire cut-in with the overflow choice pending;
	# resolving the cut-in activates the overflow choice.
	runtime.dismiss_acquire_cutin()

	_expect(bool(runtime.is_overflow_choice_active()), "a full-roster MAIN-egg hatch should open the overflow-replace choice")
	_expect((owner.lingpet_owned_pet_ids as Array).size() == 3, "the main-egg overflow hatch must not exceed the 3-pet cap before the player chooses")
	var snapshot: Dictionary = runtime.get_overflow_choice_snapshot()
	var pending_pet := str(snapshot.get("pending_pet_id", ""))
	_expect(pending_pet != "", "the overflow choice should carry the newly hatched pending pet")
	_expect(not (owner.lingpet_owned_pet_ids as Array).has(pending_pet), "the pending pet must not be owned before the choice commits")

	_expect(bool(runtime.commit_overflow_replace(0, owner, registry)), "committing a main-egg overflow replace should succeed")
	_expect(not bool(runtime.is_overflow_choice_active()), "committing the replace should close the overflow choice")
	_expect((owner.lingpet_owned_pet_ids as Array).size() == 3, "after the replace the roster should still hold exactly 3 pets")
	_expect((owner.lingpet_owned_pet_ids as Array).has(pending_pet), "the replaced-in pet should now be owned")


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
