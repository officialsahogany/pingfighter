extends SceneTree

const CharacterInfoOverlay := preload("res://scripts/hud/character_info_overlay.gd")
const CharacterInfoOverlayLingpetPresenter := preload("res://scripts/hud/character_info_overlay_lingpet_presenter.gd")
const CharacterInfoOverlayValueUtils := preload("res://scripts/hud/character_info_overlay_value_utils.gd")
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
	_verify_draft_bat_hatches_as_remaining_slot_candidate()

	if _failures.is_empty():
		print("lingpet_draft_bat_hatch_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_draft_bat_hatches_as_remaining_slot_candidate() -> void:
	var owner := FakeOwner.new()
	_seed_existing_lingpets(owner)
	var context := {"league_mode": "junior", "character_type": "smasher"}
	var candidates: Array[String] = LingpetCatalog.get_hatch_candidates(context, owner.lingpet_owned_pet_ids)
	_expect(candidates.size() == 1 and candidates.has("draft_bat"), "draft_bat should be the only hatch candidate after every other live lingpet is owned")

	var runtime: Object = LingpetEggRuntime.new()
	var collection_state: Object = runtime.get("_collection_state")
	collection_state.set_owned_pet_ids(owner.lingpet_owned_pet_ids)
	collection_state.set_battle_slots(owner.lingpet_slots)
	collection_state.set_active_slot_index(owner.lingpet_active_slot_index)
	_expect(bool(runtime.call("_should_spawn_lingpet_egg", owner)), "runtime collection state should still allow a hatch egg while draft_bat remains unowned")
	runtime.call("_spawn_egg", owner)
	_expect(str(owner.lingpet_state) == "egg", "forced remaining-candidate egg should enter egg state")
	_expect(str(owner.active_lingpet_id) == "", "egg state should not reveal draft_bat before the hatch hit")

	var egg_pos: Vector2 = owner.lingpet_egg_pos
	owner.ball_active = true
	owner.ball_serve_origin = "boss"
	_register_hit(runtime, owner, egg_pos)

	_expect(str(owner.lingpet_state) == "companion", "counted boss ball hit should hatch the draft_bat egg")
	_expect(str(owner.active_lingpet_id) == "draft_bat", "hatched draft_bat should become the active companion")
	_expect(owner.lingpet_owned_pet_ids.has("maribo") and owner.lingpet_owned_pet_ids.has("lunabi") and owner.lingpet_owned_pet_ids.has("draft_bat"), "hatching draft_bat should preserve existing owned pets")
	_expect(bool(owner.lingpet_collection.get("draft_bat", false)), "draft_bat should be marked in the lingpet collection")
	_expect((owner.lingpet_slots as Array).size() == 3, "lingpet slots should stay capped at three entries")
	_expect(str((owner.lingpet_slots as Array)[0]) == "maribo" and str((owner.lingpet_slots as Array)[1]) == "lunabi" and str((owner.lingpet_slots as Array)[2]) == "draft_bat", "draft_bat should fill the first empty battle slot without displacing owned slots")
	_expect(int(owner.lingpet_active_slot_index) == 2, "newly hatched draft_bat should select its battle slot as the active slot")

	var snapshot: Dictionary = runtime.get_snapshot()
	_expect(str(snapshot.get("active_pet_id", "")) == "draft_bat", "runtime snapshot should expose draft_bat as the active pet")
	_expect(int(snapshot.get("active_slot_index", -1)) == 2, "runtime snapshot should expose draft_bat's slot as active")
	_expect(str(snapshot.get("companion_skill_id", "")) == "draft_bat_moon_orbit", "draft_bat should publish the Moon Orbit active skill")
	_expect(is_equal_approx(float(snapshot.get("companion_skill_cooldown_duration", 0.0)), 35.0), "Moon Orbit cooldown should be 35 seconds")
	_expect(is_equal_approx(float(snapshot.get("companion_skill_windup_seconds", 0.0)), 0.85), "Moon Orbit windup should be 0.85 seconds")
	_expect(is_equal_approx(float(snapshot.get("companion_patrol_speed_default", 0.0)), 216.0), "draft_bat should expose its catalog default patrol speed")
	_expect(is_equal_approx(float(snapshot.get("companion_patrol_speed_min", 0.0)), 170.0), "draft_bat should use its catalog patrol speed min")
	_expect(is_equal_approx(float(snapshot.get("companion_patrol_speed_max", 0.0)), 260.0), "draft_bat should use its catalog patrol speed max")
	_expect(float(snapshot.get("companion_patrol_speed", 0.0)) >= 170.0 and float(snapshot.get("companion_patrol_speed", 0.0)) <= 260.0, "draft_bat's current randomized patrol speed should stay inside its catalog range")
	_expect(is_equal_approx(float(snapshot.get("companion_catch_width", 0.0)), 84.0), "draft_bat should use its catalog body/catch width")
	_expect(is_equal_approx(float(snapshot.get("companion_catch_height", 0.0)), 52.0), "draft_bat should use its catalog body/catch height")
	_expect(is_equal_approx(float(snapshot.get("companion_defense_rate", 0.0)), 0.10), "draft_bat should use its catalog defense rate")
	_expect(is_equal_approx(float(snapshot.get("companion_hit_gauge_gain", 0.0)), 40.0), "draft_bat should keep the shared 40 gauge gain on body hit")
	var passive_id := str(snapshot.get("companion_passive_skill_id", ""))
	_expect(_shared_passive_ids().has(passive_id), "draft_bat should receive one of the shared lingpet passives")
	var expected_gauge_bonus := 4.0 if passive_id == "lingpet_resonance_boost" else 0.0
	_expect(is_equal_approx(float(snapshot.get("gauge_gain_bonus_pct", -1.0)), expected_gauge_bonus), "draft_bat gauge bonus should match its selected shared passive")
	var expected_player_speed_bonus := 4.0 if passive_id == "lingpet_tailwind_steps" else 0.0
	_expect(is_equal_approx(float(snapshot.get("companion_player_speed_bonus_pct", -1.0)), expected_player_speed_bonus), "draft_bat player speed bonus should match its selected shared passive")

	var overlay := CharacterInfoOverlay.new()
	var panel: Dictionary = CharacterInfoOverlayLingpetPresenter.build_panel_snapshot(owner, Callable(CharacterInfoOverlayValueUtils, "safe_owner_get"), CharacterInfoOverlay.LINGPET_HATCH_REQUIRED_HITS)
	_expect(str(panel.get("pet_id", "")) == "draft_bat", "character info panel should read the hatched draft_bat pet id")
	_expect(str(panel.get("title", "")) == LingpetCatalog.get_display_name("draft_bat"), "character info panel should reveal draft_bat's catalog display name")
	_expect(str(panel.get("companion_skill_id", "")) == "draft_bat_moon_orbit", "character info panel should expose draft_bat's active skill id")
	_expect(str(panel.get("companion_skill_icon_path", "")).ends_with("draft_bat_moon_orbit_skill_icon_imagegen_v1.png"), "character info panel should resolve draft_bat's skill icon path through the catalog fallback")
	_expect(str(panel.get("companion_passive_skill_id", "")) == passive_id, "character info panel should expose draft_bat's selected shared passive skill id")
	var skill_specs: Array = CharacterInfoOverlayLingpetPresenter.get_skill_specs(panel, CharacterInfoOverlay.STAT_BUFF_COLOR)
	_expect(skill_specs.size() == 2, "draft_bat should show its active skill and shared passive skill icons")
	_expect(_skill_specs_have_id(skill_specs, "draft_bat_moon_orbit"), "draft_bat skill icons should include Moon Orbit")
	_expect(_skill_specs_have_id(skill_specs, passive_id), "draft_bat skill icons should include the selected shared passive")
	for raw_spec in skill_specs:
		var skill_spec: Dictionary = raw_spec as Dictionary
		_expect(str(skill_spec.get("title", "")) != "" and str(skill_spec.get("body", "")) != "", "draft_bat skill icons should carry tooltip title and body text")
	var stat_rows: Array = overlay._build_lingpet_stats(owner)
	_expect(_rows_contain_value(stat_rows, "3.60"), "draft_bat panel speed should display as 3.60, not the player's 6.00 speed")
	_expect(not _rows_contain_value(stat_rows, "6.00"), "draft_bat panel stats should not leak the player movement speed value")


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


func _register_hit(runtime: Object, owner: FakeOwner, egg_pos: Vector2) -> void:
	owner.ball_pos = egg_pos + Vector2(0.0, -90.0)
	owner.ball_vel = Vector2(0.0, 12.0)
	runtime.update(0.21, owner)
	owner.ball_pos = egg_pos + Vector2(1.0, -8.0)
	owner.ball_vel = Vector2(0.0, 12.0)
	runtime.update(0.0, owner)


func _rows_contain_value(rows: Array, expected_value: String) -> bool:
	for row_value in rows:
		var row: Dictionary = row_value as Dictionary
		if str(row.get("value", "")) == expected_value:
			return true
	return false


func _shared_passive_ids() -> Array[String]:
	return ["lingpet_resonance_boost", "lingpet_afterglow_leak", "lingpet_tailwind_steps"]


func _skill_specs_have_id(skill_specs: Array, expected_id: String) -> bool:
	for raw_spec in skill_specs:
		var skill_spec: Dictionary = raw_spec as Dictionary
		if str(skill_spec.get("id", "")) == expected_id:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
