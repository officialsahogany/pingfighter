extends SceneTree

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var ai_mode := "junior league"
	var selected_character_type := "smasher"
	var player_pos := Vector2(263.75, 675.0)
	var player_paddle_width := 232.5
	var player_paddle_height := 75.0
	var boss_pos := Vector2(330.0, 25.0)
	var boss_vel := 0.0
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0
	var ball_active := false
	var ball_pos := Vector2.ZERO
	var ball_vel := Vector2.ZERO
	var ball_serve_origin := ""
	var ball_size := 28.6
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
	var lingpet_effect_text := ""
	var lingpet_owned_pet_ids: Array = []
	var owned_lingpet_ids: Array = []
	var owned_ringpet_ids: Array = []
	var lingpet_collection: Dictionary = {}
	var ringpet_collection: Dictionary = {}
	var owned_lingpets: Dictionary = {}
	var owned_ringpets: Dictionary = {}
	var lingpet_slots: Array = ["", "", ""]
	var ringpet_slots: Array = ["", "", ""]
	var lingpet_slot_pet_ids: Array = ["", "", ""]
	var ringpet_slot_pet_ids: Array = ["", "", ""]
	var lingpet_active_slot_index := 0
	var ringpet_active_slot_index := 0


func _init() -> void:
	_verify_draft_bat_stays_out_of_remaining_slot_candidates()

	if _failures.is_empty():
		print("lingpet_draft_bat_hatch_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_draft_bat_stays_out_of_remaining_slot_candidates() -> void:
	var owner := FakeOwner.new()
	_seed_existing_lingpets(owner)
	var context := {"league_mode": "junior", "character_type": "smasher"}
	var candidates: Array[String] = LingpetCatalog.get_hatch_candidates(context, owner.lingpet_owned_pet_ids)
	_expect(candidates.is_empty(), "draft_bat should not remain as a hatch candidate after every live lingpet is owned")
	_expect(not LingpetCatalog.get_pet_ids().has("draft_bat"), "draft_bat should stay out of enabled pet ids")
	_expect(LingpetCatalog.get_pet_ids(true).has("draft_bat"), "draft_bat metadata should remain available for tooling")
	_expect(not LingpetCatalog.is_pet_enabled("draft_bat"), "draft_bat should remain disabled until hatch-pool approval")

	var runtime: Object = LingpetEggRuntime.new()
	var collection_state: Object = runtime.get("_collection_state")
	collection_state.set_owned_pet_ids(owner.lingpet_owned_pet_ids)
	collection_state.set_battle_slots(owner.lingpet_slots)
	collection_state.set_active_slot_index(owner.lingpet_active_slot_index)
	_expect(not bool(runtime.call("_should_spawn_lingpet_egg", owner)), "runtime should not spawn a hatch egg when only disabled draft_bat remains unowned")


func _seed_existing_lingpets(owner: FakeOwner) -> void:
	var owned: Array[String] = []
	for pet_id in LingpetCatalog.get_pet_ids():
		if pet_id != "draft_bat":
			owned.append(pet_id)
	owner.lingpet_owned_pet_ids = owned.duplicate()
	owner.owned_lingpet_ids = owned.duplicate()
	owner.owned_ringpet_ids = owned.duplicate()
	owner.lingpet_collection = {}
	for pet_id in owned:
		owner.lingpet_collection[pet_id] = true
	owner.ringpet_collection = owner.lingpet_collection.duplicate()
	owner.owned_lingpets = owner.lingpet_collection.duplicate()
	owner.owned_ringpets = owner.lingpet_collection.duplicate()
	owner.lingpet_slots = ["maribo", "lunabi", ""]
	owner.ringpet_slots = owner.lingpet_slots.duplicate()
	owner.lingpet_slot_pet_ids = owner.lingpet_slots.duplicate()
	owner.ringpet_slot_pet_ids = owner.lingpet_slots.duplicate()
	owner.lingpet_active_slot_index = 0
	owner.ringpet_active_slot_index = 0


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
