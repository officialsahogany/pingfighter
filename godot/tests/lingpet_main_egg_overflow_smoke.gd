extends SceneTree

# Self-contained smoke for the MAIN (plaza / field) egg ball-hit hatch path. This is a
# DIFFERENT code path from the item-egg overflow route (_verify_lingpet_egg_overflow_*
# in lingpet_egg_runtime_smoke.gd): it routes through _resolve_ball_hit's is_full branch
# (_begin_overflow_hatch / begin_main_overflow), not begin_item_egg_overflow. The owner /
# registry / hit-seed helpers below are intentionally local copies so this contract does
# not depend on the in-progress lingpet egg-runtime smoke scaffolding.

const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const LingpetOverflowChoiceOverlayHost := preload("res://scripts/hud/lingpet_overflow_choice_overlay_host.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

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


class FakeTowerRevealFlow:
	extends RefCounted

	var calls := 0

	func record_guardian_identity_reveal(pet_id: String, _registry: Object = null) -> Dictionary:
		calls += 1
		return {
			"accepted": true,
			"handled": true,
			"tower_sealed": false,
			"pet_id": pet_id,
		}




func _init() -> void:
	_verify_tower_main_egg_keeps_overflow_choice()
	_verify_tower_item_egg_keeps_overflow_choice()
	_verify_main_egg_replace_keeps_one_live_guardian()
	_verify_main_egg_replace_refills_expired_duration_pool()
	_verify_main_egg_absorb_uses_shared_enhancement()
	_verify_comparison_shows_live_guardian_state()
	_verify_empty_skill_slots_are_not_faked()
	_verify_skill_names_localize()

	if _failures.is_empty():
		print("lingpet_main_egg_overflow_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_tower_main_egg_keeps_overflow_choice() -> void:
	var owner := FakeOwner.new()
	_seed_lingpet_roster(owner, ["maribo"], 0)
	var tower_flow := FakeTowerRevealFlow.new()
	var registry := FakeRegistry.new({"tower_ascent_flow_owner": tower_flow})
	var runtime: Object = LingpetEggRuntime.new()
	_open_main_egg_choice(runtime, owner, registry)
	_expect(tower_flow.calls == 1, "Tower main-egg reveal must reach the active flow owner")
	_expect(bool(runtime.is_overflow_choice_active()), "Tower main-egg hatch at full roster must open the existing Replace / Absorb choice")
	_expect(not bool(runtime.get_overflow_choice_snapshot().get("pending_pet_id", "") == ""), "Tower main-egg overflow must preserve the incoming guardian identity")


func _verify_tower_item_egg_keeps_overflow_choice() -> void:
	var owner := FakeOwner.new()
	owner.ai_mode = "champion"
	_seed_lingpet_roster(owner, ["maribo"], 0)
	var tower_flow := FakeTowerRevealFlow.new()
	var registry := FakeRegistry.new({"tower_ascent_flow_owner": tower_flow})
	var runtime: Object = LingpetEggRuntime.new()
	_expect(
		bool(runtime.debug_grant_and_activate_pet("maribo", owner, false, "", "", registry)),
		"Tower item-egg fixture must begin with one active guardian"
	)
	_expect(bool(runtime.deploy_egg_from_item(owner, registry, true)), "Tower item egg must deploy beside the active guardian")
	var item_egg_state: Object = runtime.get("_item_egg_state") as Object
	var item_lifecycle: Object = runtime.get("_item_egg_lifecycle_state") as Object
	var required_hits := maxi(1, int(item_egg_state.get_required_hits(item_lifecycle.get_required_hits(3))))
	item_egg_state.hatch_hits = required_hits - 1
	item_egg_state.hit_cooldown = 0.0
	item_egg_state.ball_was_inside = false
	owner.ball_active = true
	owner.ball_serve_origin = "boss"
	_register_hit(runtime, owner, item_egg_state.pos, 1, registry)
	_expect(bool(runtime.is_acquire_cutin_active()), "Tower item-egg final hit must open the existing acquisition cut-in")
	runtime.dismiss_acquire_cutin()
	runtime.update(0.0, owner, registry)
	_expect(tower_flow.calls == 1, "Tower item-egg reveal must reach the active flow owner")
	_expect(bool(runtime.is_overflow_choice_active()), "Tower item-egg hatch at full roster must open the existing Replace / Absorb choice")
	_expect(bool(runtime.get("_overflow_choice_state").is_item_egg_source()), "Tower item-egg overflow must retain its item source contract")


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
	var current_guardian: Dictionary = snapshot.get("current_guardian", {}) as Dictionary
	_expect(str(current_guardian.get("pet_id", "")) == "maribo", "comparison snapshot must keep the existing guardian on the left")
	_expect(str(current_guardian.get("art_path", "")).strip_edges() != "", "existing guardian comparison must expose its portrait")
	_expect(not (current_guardian.get("stats", {}) as Dictionary).is_empty(), "existing guardian comparison must expose effective stats")
	_expect(str(current_guardian.get("active_skill_name", "")).strip_edges() != "", "existing guardian comparison must expose its equipped active skill")
	_expect(int(current_guardian.get("active_skill_level", 0)) > 0, "existing guardian comparison must expose its effective active skill level")
	_expect(str(current_guardian.get("active_skill_icon_path", "")).strip_edges() != "", "existing guardian comparison must expose its active skill icon")
	_expect(str(current_guardian.get("passive_skill_icon_path", "")).strip_edges() != "", "existing guardian comparison must expose its passive skill icon")
	# The hatch roll can legitimately land on level 0 (= that slot stays empty), so the
	# preview assertions below would be RNG-flaky against the raw roll. Pin a concrete
	# preview loadout and re-read through the production snapshot path instead.
	var preview_active_id := _install_deterministic_preview_loadout(runtime, owner, pending_pet)
	var expected_preview_icon := str(
		LingpetCatalog.get_active_skill(pending_pet, preview_active_id).get("icon_texture_path", "")
	)
	snapshot = runtime.get_overflow_choice_snapshot()
	var replacement_guardian: Dictionary = snapshot.get("replacement_guardian", {}) as Dictionary
	_expect(str(replacement_guardian.get("pet_id", "")) == pending_pet, "comparison snapshot must put the incoming guardian on the right")
	_expect(str(replacement_guardian.get("art_path", "")).strip_edges() != "", "incoming guardian comparison must expose its portrait")
	_expect(str(replacement_guardian.get("active_skill_name", "")).strip_edges() != "", "incoming guardian comparison must expose its preview skill")
	_expect(str(replacement_guardian.get("active_skill_icon_path", "")) == expected_preview_icon, "incoming guardian comparison must expose its preview skill icon")
	_expect(str(replacement_guardian.get("passive_skill_name", "")).strip_edges() != "", "incoming guardian comparison must expose its rolled passive skill")
	_expect(str(replacement_guardian.get("passive_skill_icon_path", "")).strip_edges() != "", "incoming guardian comparison must expose its rolled passive skill icon")
	var preview_loadout: Dictionary = runtime._loadout_state.get_stored_loadout(pending_pet)
	_expect(not preview_loadout.is_empty(), "incoming guardian skill preview must be stored before replacement confirmation")
	_expect(not (owner.lingpet_owned_pet_ids as Array).has(pending_pet), "the pending pet must not be owned before the choice commits")
	_expect(bool(runtime.commit_overflow_replace(0, owner, registry)), "replace should commit through live slot zero")
	var committed_loadout: Dictionary = runtime._loadout_state.get_stored_loadout(pending_pet)
	_expect(str(committed_loadout.get("active_skill_id", "")) == str(preview_loadout.get("active_skill_id", "")), "confirmed replacement must keep the previewed active skill")
	_expect(str(committed_loadout.get("passive_skill_id", "")) == str(preview_loadout.get("passive_skill_id", "")), "confirmed replacement must keep the previewed passive skill")
	_expect(not bool(runtime.is_overflow_choice_active()), "committing the replace should close the overflow choice")
	_expect((owner.lingpet_owned_pet_ids as Array).size() == 1, "replace must leave exactly one live guardian")
	_expect((owner.lingpet_owned_pet_ids as Array).has(pending_pet), "the replaced-in pet should now be owned")
	_expect(bool(owner.lingpet_collection.get("maribo", false)), "replace must preserve the old guardian in permanent collection history")
	_expect(bool(owner.lingpet_collection.get(pending_pet, false)), "replace must record the incoming guardian in permanent collection history")
	# Contract (2026-08-08, user): a NEW guardian arrives at full uptime. Replacement
	# refills the run-shared pool to 100% while the once-per-run maximum -- including
	# Guardian Enhancement duration increases -- stays untouched.
	_expect(is_equal_approx(runtime._guardian_run_state.get_duration_pool_current(), 42.0), "replace must refill the run-owned duration pool to its maximum")
	_expect(is_equal_approx(runtime._guardian_run_state.get_duration_pool_max(), 42.0), "replace must preserve the run-owned duration maximum")
	_expect(runtime.get_duration_pool_pct() == 100, "replace must publish a full duration pool to the HUD")


# The worst live case for the refill contract: the pool ran dry, the guardian was
# force-stowed and the resummon lock latched. Breaking a new egg and choosing Replace must
# hand the incoming guardian a full pool AND clear that lock -- otherwise a replacement
# bought at 0% is unusable until a third of the pool trickles back.
func _verify_main_egg_replace_refills_expired_duration_pool() -> void:
	var owner := FakeOwner.new()
	_seed_lingpet_roster(owner, ["maribo"], 0)
	var registry := FakeRegistry.new({})
	var runtime: Object = LingpetEggRuntime.new()
	_open_main_egg_choice(runtime, owner, registry)
	runtime._guardian_run_state.set_duration_pool_for_tests(0.0, 42.0)
	_expect(bool(runtime._guardian_run_state.is_duration_resummon_locked()), "fixture must start from an expired, resummon-locked pool")
	_expect(bool(runtime.commit_overflow_replace(0, owner, registry)), "replace should commit even from a fully drained pool")
	_expect(is_equal_approx(runtime._guardian_run_state.get_duration_pool_current(), 42.0), "a replacement guardian must start from a full duration pool")
	_expect(runtime.get_duration_pool_pct() == 100, "a drained pool must read 100% after replacement")
	_expect(not bool(runtime._guardian_run_state.is_duration_resummon_locked()), "the replacement refill must clear the expiry resummon lock")
	_expect(bool(runtime._guardian_run_state.can_resummon_guardian()), "a replacement guardian must be summonable immediately")


func _verify_main_egg_absorb_uses_shared_enhancement() -> void:
	var owner := FakeOwner.new()
	_seed_lingpet_roster(owner, ["maribo"], 0)
	var registry := FakeRegistry.new({})
	var runtime: Object = LingpetEggRuntime.new()
	_open_main_egg_choice(runtime, owner, registry)
	var snapshot: Dictionary = runtime.get_overflow_choice_snapshot()
	var pending_pet := str(snapshot.get("pending_pet_id", ""))
	runtime._guardian_run_state.set_duration_pool_for_tests(20.0, 42.0)
	_expect(bool(runtime.commit_overflow_absorb(owner, registry)), "absorb should resolve through the shared enhancement path")
	# Control group for the replacement refill: absorption keeps the current guardian, so
	# it must NOT top the pool up. The enhancement roll it grants can still add at most
	# +15s (revalidation fallback) or +5s (duration increase), both well under the max.
	_expect(runtime._guardian_run_state.get_duration_pool_current() < 42.0, "absorption must not refill the duration pool -- only replacement does")
	_expect(not bool(runtime.is_overflow_choice_active()), "absorb should close the roster choice")
	_expect((owner.lingpet_owned_pet_ids as Array) == ["maribo"], "absorb must keep the current live guardian")
	_expect(bool(owner.lingpet_collection.get(pending_pet, false)), "absorbed guardian must remain in permanent collection history")
	var result: Dictionary = runtime.get_guardian_enhance_last_result_for_tests()
	_expect(bool(result.get("accepted", false)), "absorb must apply exactly one accepted Guardian Enhancement result")
	_expect(str(result.get("trigger_source", "")) == "absorb", "absorb result must identify its source without a parallel reward UI")
	_expect(str(result.get("trigger_source_label", "")).strip_edges() != "", "absorb result must carry localized source copy")
	_expect(bool(runtime.is_guardian_enhance_cutin_active()), "absorb must reuse the compact Guardian Enhancement panel")


# Regression seal: the Replace comparison must mirror the LIVE guardian, not the
# acquisition-time roll. Guardian Enhancement raises the effective skill level and can
# unlock a second passive slot, and both were invisible on the comparison card because
# the snapshot published the raw stored loadout level and slot 0 only.
func _verify_comparison_shows_live_guardian_state() -> void:
	var owner := FakeOwner.new()
	_seed_lingpet_roster(owner, ["maribo"], 0)
	var registry := FakeRegistry.new({})
	var runtime: Object = LingpetEggRuntime.new()
	_expect(
		bool(runtime.debug_grant_and_activate_pet("maribo", owner, false, "", "", registry)),
		"fixture must activate the current guardian before enhancing it"
	)
	for reward_type in ["active_unlock", "passive_unlock", "second_passive_unlock"]:
		_expect(
			bool(_apply_enhancement(runtime, owner, registry, str(reward_type), 0).get("accepted", false)),
			"fixture must land the %s Guardian Enhancement" % reward_type
		)
	var applied_active_bonus := 0
	for _i in range(2):
		if bool(_apply_enhancement(runtime, owner, registry, "active_skill", 1).get("accepted", false)):
			applied_active_bonus += 1
	_expect(applied_active_bonus >= 1, "fixture must raise the active skill level above its stored roll")
	_expect(
		bool(_apply_enhancement(runtime, owner, registry, "passive_skill", 1).get("accepted", false)),
		"fixture must raise the primary passive level above its stored roll"
	)
	var stored_loadout: Dictionary = runtime._loadout_state.get_stored_loadout("maribo")
	var stored_active_level := int(
		(stored_loadout.get("active_skill_levels", {}) as Dictionary).get(
			str(stored_loadout.get("active_skill_id", "")),
			int(stored_loadout.get("active_skill_level", 1))
		)
	)
	# The profile hands back its own cache dicts and wipes them in place on the next
	# invalidation, so the oracle must be deep-copied before the hatch flow runs.
	var live_active: Dictionary = (runtime._current_profile.get_active_skill(0) as Dictionary).duplicate(true)
	var live_passives: Array = []
	for live_passive in runtime._current_profile.get_passive_skills():
		live_passives.append((live_passive as Dictionary).duplicate(true))
	var live_active_level := int(live_active.get("level", 0))
	_expect(live_passives.size() >= 2, "fixture must unlock the second passive slot on the live guardian")
	_expect(
		live_active_level > stored_active_level,
		"fixture must make the live effective level diverge from the acquisition-time stored level"
	)

	_open_main_egg_choice_after_setup(runtime, owner, registry)
	var snapshot: Dictionary = runtime.get_overflow_choice_snapshot()
	var current_guardian: Dictionary = snapshot.get("current_guardian", {}) as Dictionary
	_expect(str(current_guardian.get("pet_id", "")) == "maribo", "comparison must describe the live guardian")
	_expect(
		int(current_guardian.get("active_skill_level", 0)) == live_active_level,
		"comparison must show the live effective active level, not the acquisition-time stored roll"
	)
	_expect(
		str(current_guardian.get("active_skill_name", "")) == str(live_active.get("name", "")),
		"comparison must show the currently equipped active skill"
	)
	var active_skills: Array = current_guardian.get("active_skills", []) as Array
	var passive_skills: Array = current_guardian.get("passive_skills", []) as Array
	_expect(active_skills.size() >= 1, "comparison must publish every equipped active slot")
	_expect(
		passive_skills.size() == live_passives.size(),
		"comparison must publish every unlocked passive slot (%d live)" % live_passives.size()
	)
	for index in range(mini(passive_skills.size(), live_passives.size())):
		var listed: Dictionary = passive_skills[index] as Dictionary
		var live_passive: Dictionary = live_passives[index] as Dictionary
		_expect(
			str(listed.get("name", "")) == str(live_passive.get("name", "")),
			"comparison passive slot %d must match the live loadout" % index
		)
		_expect(
			int(listed.get("level", 0)) == int(live_passive.get("level", 0)),
			"comparison passive slot %d must show its live effective level" % index
		)
	var info: Dictionary = LingpetOverflowChoiceOverlayHost.build_current_guardian_info_for_tests(snapshot, "ko")
	var entries: Array = info.get("skill_entries", []) as Array
	_expect(
		entries.size() == active_skills.size() + passive_skills.size(),
		"the comparison card must draw one row per live skill slot"
	)
	_expect(
		str(entries[0].get("title", "")).find("Lv.%d" % live_active_level) >= 0,
		"the comparison card active row must render the live effective level"
	)


# A hatch skill roll of level 0 is a normal ~25% outcome meaning "that slot stays
# empty", and the rolled preview loadout is exactly what a confirmed replacement keeps.
# So neither side of the comparison may invent a skill: the incoming guardian must not
# borrow the shared pool's first passive, and a passive-only live guardian must not be
# redrawn from the catalog default loadout.
func _verify_empty_skill_slots_are_not_faked() -> void:
	var owner := FakeOwner.new()
	_seed_lingpet_roster(owner, ["maribo"], 0)
	var registry := FakeRegistry.new({})
	var runtime: Object = LingpetEggRuntime.new()
	_expect(
		bool(runtime.debug_grant_and_activate_pet("maribo", owner, false, "", "", registry)),
		"fixture must activate the current guardian"
	)
	# The catalog default passive for any pet is the shared pool's FIRST passive, so the
	# live guardian is given a DIFFERENT passive and no active at all: with the default
	# clobber present the card shows 공명 증폭 + a default active it never had.
	var pool_first_passive := str(LingpetCatalog.get_passive_skill("maribo", "").get("name", ""))
	_expect(pool_first_passive != "", "fixture needs the shared pool's first passive name")
	_install_loadout(runtime, owner, "maribo", "", "lingpet_light_eater", 0, 2)
	_open_main_egg_choice_after_setup(runtime, owner, registry)
	var pending_pet := str(runtime.get_overflow_choice_snapshot().get("pending_pet_id", ""))
	# Incoming guardian: an active, but the passive roll came back empty.
	var incoming_active := str(LingpetCatalog.get_active_skill(pending_pet).get("id", ""))
	_install_loadout(runtime, owner, pending_pet, incoming_active, "", 3, 0)
	var snapshot: Dictionary = runtime.get_overflow_choice_snapshot()

	var current_guardian: Dictionary = snapshot.get("current_guardian", {}) as Dictionary
	var current_actives: Array = current_guardian.get("active_skills", []) as Array
	var current_passives: Array = current_guardian.get("passive_skills", []) as Array
	_expect(current_actives.is_empty(), "a live guardian with no rolled active must not be given the default active")
	_expect(str(current_guardian.get("active_skill_name", "")) == "", "empty active slot must publish an empty primary name")
	_expect(current_passives.size() == 1, "a passive-only live guardian must keep exactly its own passive")
	var kept_passive := str((current_passives[0] as Dictionary).get("name", ""))
	_expect(kept_passive != pool_first_passive, "the live guardian's real passive must survive (default-loadout clobber would swap in the pool's first passive)")
	_expect(int((current_passives[0] as Dictionary).get("level", 0)) == 2, "the live guardian's real passive level must survive")

	var replacement_guardian: Dictionary = snapshot.get("replacement_guardian", {}) as Dictionary
	var incoming_passives: Array = replacement_guardian.get("passive_skills", []) as Array
	_expect(incoming_passives.is_empty(), "an unrolled incoming passive slot must stay empty, not borrow the shared pool")
	_expect(str(replacement_guardian.get("passive_skill_name", "")) == "", "an unrolled incoming passive must not publish a borrowed name")
	_expect((replacement_guardian.get("active_skills", []) as Array).size() == 1, "the incoming rolled active must still be published")

	var copy: Dictionary = LingpetOverflowChoiceOverlayHost.get_copy_for_language_for_tests("ko")
	var none_label := str(copy.get("skill_none", ""))
	_expect(none_label != "", "the comparison copy must localize an explicit empty-slot label")
	var incoming_info: Dictionary = LingpetOverflowChoiceOverlayHost.build_guardian_info_for_tests(snapshot, "ko")
	_expect(
		str(incoming_info.get("passive_title", "")) == none_label,
		"the incoming card must render its empty passive slot as an explicit none row"
	)
	_expect(
		str(incoming_info.get("passive_title", "")) != pool_first_passive,
		"the incoming card must never show the shared pool's first passive as its own"
	)
	_expect(
		str(incoming_info.get("passive_title", "")) != str(copy.get("passive_pending_title", "")),
		"an already-rolled empty passive is not 'decided on acquisition'"
	)
	var current_info: Dictionary = LingpetOverflowChoiceOverlayHost.build_current_guardian_info_for_tests(snapshot, "ko")
	_expect(
		str(current_info.get("skill_title", "")) == none_label,
		"the live card must render its empty active slot as an explicit none row"
	)
	var current_entries: Array = current_info.get("skill_entries", []) as Array
	_expect(current_entries.size() == 2, "an empty slot still occupies one labelled row")


# The catalog stores Korean skill names and LanguageSettingsData carries their
# non-Korean forms, so a non-Korean comparison card must not keep the Korean name.
func _verify_skill_names_localize() -> void:
	var snapshot := {
		"current_guardian": {
			"pet_id": "rahoset",
			"display_name": "라호세트",
			"stats": {},
			"active_skills": [{
				"name": "모래감옥",
				"description": "",
				"cooldown": 30.0,
				"icon_path": "icon",
				"level": 3,
			}],
			"passive_skills": [],
		},
	}
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_ENGLISH)
	var info: Dictionary = LingpetOverflowChoiceOverlayHost.build_current_guardian_info_for_tests(snapshot, "en")
	var english_copy: Dictionary = LingpetOverflowChoiceOverlayHost.get_copy_for_language_for_tests("en")
	LanguageSettings.set_test_locale_override("")
	var title := str(info.get("skill_title", ""))
	_expect(title.find("모래감옥") < 0, "an English comparison card must not keep the Korean skill name")
	_expect(title.find("Sand Prison") >= 0, "an English comparison card must use the translated skill name")
	_expect(
		str(info.get("passive_title", "")) == str(english_copy.get("skill_none", "")),
		"the empty-slot row must use the active locale's none label"
	)


func _install_loadout(
	runtime: Object,
	owner: FakeOwner,
	pet_id: String,
	active_id: String,
	passive_id: String,
	active_level: int,
	passive_level: int
) -> void:
	var loadout: Dictionary = {
		"active_skill_id": active_id,
		"active_skill_level": active_level,
		"active_skill_ids": [active_id] if active_id != "" else [],
		"active_skill_levels": {active_id: active_level} if active_id != "" else {},
		"active_slot_count": 1 if active_id != "" else 0,
		"passive_skill_id": passive_id,
		"passive_skill_level": passive_level,
		"passive_skill_ids": [passive_id] if passive_id != "" else [],
		"passive_skill_levels": {passive_id: passive_level} if passive_id != "" else {},
		"passive_slot_count": 1 if passive_id != "" else 0,
	}
	runtime._loadout_state.loadouts_by_pet_id[pet_id] = loadout
	var loadouts: Dictionary = runtime._loadout_state.get_loadouts()
	for key in ["lingpet_loadouts", "ringpet_loadouts", "owned_lingpet_loadouts", "owned_ringpet_loadouts"]:
		owner.set(key, loadouts.duplicate(true))


func _install_deterministic_preview_loadout(runtime: Object, owner: FakeOwner, pet_id: String) -> String:
	# Which pet hatches is random, and not every catalog active skill ships an icon yet
	# (baekrin has none on either of its actives), so prefer an icon-bearing skill and
	# return the chosen id so the caller can assert the icon PLUMBING against the
	# catalog value instead of against art coverage.
	var active_id := ""
	for skill in LingpetCatalog.get_active_skill_pool(pet_id):
		if str(skill.get("icon_texture_path", "")).strip_edges() != "":
			active_id = str(skill.get("id", ""))
			break
	if active_id == "":
		active_id = str(LingpetCatalog.get_active_skill(pet_id).get("id", ""))
	_expect(active_id != "", "fixture needs a catalog active skill for the incoming guardian")
	runtime._loadout_state.loadouts_by_pet_id[pet_id] = {
		"active_skill_id": active_id,
		"active_skill_level": 3,
		"active_skill_ids": [active_id],
		"active_skill_levels": {active_id: 3},
		"active_slot_count": 1,
		"passive_skill_id": "lingpet_resonance_boost",
		"passive_skill_level": 2,
		"passive_skill_ids": ["lingpet_resonance_boost"],
		"passive_skill_levels": {"lingpet_resonance_boost": 2},
		"passive_slot_count": 1,
	}
	# Mirror it onto the owner too: the commit path re-reads the owner loadout dicts
	# (sync_from_owner) and would otherwise discard this preview.
	var loadouts: Dictionary = runtime._loadout_state.get_loadouts()
	for key in ["lingpet_loadouts", "ringpet_loadouts", "owned_lingpet_loadouts", "owned_ringpet_loadouts"]:
		owner.set(key, loadouts.duplicate(true))
	return active_id


func _apply_enhancement(
	runtime: Object,
	owner: Object,
	registry: Object,
	reward_type: String,
	skill_slot: int
) -> Dictionary:
	var candidate: Dictionary = {
		"type": reward_type,
		"storage_owner": "lingpet_enhancement_buff_store",
	}
	if skill_slot > 0:
		candidate["skill_slot"] = skill_slot
	return runtime.apply_guardian_enhancement_candidate(candidate, owner, registry, "maribo")


func _open_main_egg_choice(runtime: Object, owner: FakeOwner, registry: FakeRegistry) -> void:
	_expect(
		bool(runtime.debug_grant_and_activate_pet("maribo", owner, false, "", "", registry)),
		"fixture must activate the current one-slot guardian before opening another egg"
	)
	# The live guardian's own hatch roll can land on level 0 (= that slot stays empty),
	# which is a legitimate state the comparison now reports truthfully. Pin a loadout so
	# the assertions below stay about snapshot plumbing rather than about the roll.
	_install_loadout(
		runtime,
		owner,
		"maribo",
		str(LingpetCatalog.get_active_skill("maribo").get("id", "")),
		"lingpet_resonance_boost",
		3,
		2
	)
	_open_main_egg_choice_after_setup(runtime, owner, registry)


func _open_main_egg_choice_after_setup(runtime: Object, owner: FakeOwner, registry: FakeRegistry) -> void:
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
