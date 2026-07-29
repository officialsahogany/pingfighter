extends SceneTree

const LingpetAffinityContextCoordinator := preload("res://scripts/lingpet/lingpet_affinity_context_coordinator.gd")
const LingpetAffinityState := preload("res://scripts/lingpet/lingpet_affinity_state.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetCurrentProfile := preload("res://scripts/lingpet/lingpet_current_profile.gd")

var _failures: Array[String] = []


class EmptyLoadoutState:
	extends RefCounted

	func get_loadout(_pet_id: String) -> Dictionary:
		return {}


func _init() -> void:
	_verify_catalog_hatch_skill_roll_distribution()
	_verify_hatch_passive_id_covers_full_pool()
	_verify_hatch_stat_roll_projection_and_caps()
	_verify_hatch_candidate_pool_exhaustion()

	if _failures.is_empty():
		print("lingpet_hatch_randomization_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_catalog_hatch_skill_roll_distribution() -> void:
	var first_rng := RandomNumberGenerator.new()
	first_rng.seed = 4242
	var first_loadout := LingpetCatalog.pick_skill_loadout("maribo", first_rng)
	var repeat_rng := RandomNumberGenerator.new()
	repeat_rng.seed = 4242
	var repeat_loadout := LingpetCatalog.pick_skill_loadout("maribo", repeat_rng)
	_expect_str(_loadout_signature(first_loadout), _loadout_signature(repeat_loadout), "seeded hatch skill rolls should be reproducible")

	# The hatch passive IDENTITY is now randomly drawn from the shared common passive pool
	# (not pinned to pool[0] = 공명 증폭). Collect the pool ids so the distribution sweep can
	# assert both membership (every rolled passive is a valid pool entry) and coverage (more
	# than one distinct passive appears -- the falsification anchor: a pool[0]-hardcoded roll
	# only ever surfaces one id).
	var passive_pool_ids := {}
	for passive in LingpetCatalog.get_passive_skill_pool("maribo"):
		var pool_passive_id := str((passive as Dictionary).get("id", "")).strip_edges()
		if pool_passive_id != "":
			passive_pool_ids[pool_passive_id] = true
	_expect(passive_pool_ids.size() >= 2, "common passive pool should expose at least two passives for the hatch draw")
	_expect(passive_pool_ids.has("lingpet_light_eater"), "common passive pool should include the light-eater passive")
	var light_eater_skill := LingpetCatalog.get_passive_skill("maribo", "lingpet_light_eater", 5)
	_expect(not light_eater_skill.is_empty(), "light-eater passive should build from the common passive pool")
	_expect_float(
		float(light_eater_skill.get("satiety_drain_reduction_pct", 0.0)),
		LingpetAffinityState.get_satiety_drain_reduction_pct_for_level(5),
		"light-eater passive should materialize the shared Lv.5 drain reduction"
	)

	var active_counts := [0, 0, 0, 0]
	var passive_counts := [0, 0, 0, 0]
	var seen_passive_ids := {}
	var saw_invalid_passive_id := false
	var saw_active_without_passive := false
	var saw_passive_without_active := false
	var saw_both_present := false
	var saw_both_missing := false
	for seed in range(1, 801):
		var rng := RandomNumberGenerator.new()
		rng.seed = int(seed)
		var loadout := LingpetCatalog.pick_skill_loadout("maribo", rng)
		var active_level := int(loadout.get("active_skill_level", 0))
		var passive_level := int(loadout.get("passive_skill_level", 0))
		_expect(active_level >= 0 and active_level <= 3, "active hatch level should be none or Lv1-3")
		_expect(passive_level >= 0 and passive_level <= 3, "passive hatch level should be none or Lv1-3")
		active_counts[active_level] = int(active_counts[active_level]) + 1
		passive_counts[passive_level] = int(passive_counts[passive_level]) + 1
		_expect_hatch_skill_shape(loadout, true)
		_expect_hatch_skill_shape(loadout, false)
		if passive_level > 0:
			var rolled_passive_id := str(loadout.get("passive_skill_id", ""))
			seen_passive_ids[rolled_passive_id] = true
			if not passive_pool_ids.has(rolled_passive_id):
				saw_invalid_passive_id = true
		saw_active_without_passive = saw_active_without_passive or (active_level > 0 and passive_level == 0)
		saw_passive_without_active = saw_passive_without_active or (active_level == 0 and passive_level > 0)
		saw_both_present = saw_both_present or (active_level > 0 and passive_level > 0)
		saw_both_missing = saw_both_missing or (active_level == 0 and passive_level == 0)
	for bucket in range(4):
		_expect(int(active_counts[bucket]) >= 120 and int(active_counts[bucket]) <= 280, "active hatch bucket %d should stay near the 25 percent contract" % bucket)
		_expect(int(passive_counts[bucket]) >= 120 and int(passive_counts[bucket]) <= 280, "passive hatch bucket %d should stay near the 25 percent contract" % bucket)
	_expect(saw_active_without_passive, "active and passive hatch rolls should be independent enough to allow active-only starts")
	_expect(saw_passive_without_active, "active and passive hatch rolls should be independent enough to allow passive-only starts")
	_expect(saw_both_present, "hatch rolls should allow both skills to start present")
	_expect(saw_both_missing, "hatch rolls should preserve the no-skill start as a possible outcome")
	_expect(not saw_invalid_passive_id, "every rolled hatch passive id should be a member of the common passive pool")
	# The pinned-pool[0] regression only needs "more than one passive can appear" through the real
	# pick_skill_loadout path; full-pool range coverage is proven separately and robustly (adaptive
	# to pool growth) by _verify_hatch_passive_id_covers_full_pool so a growing pool cannot make
	# this fixed-seed integration sweep flaky.
	_expect(seen_passive_ids.size() >= 2, "hatch passive draw should surface more than one passive (not pinned to pool[0])")


func _verify_hatch_passive_id_covers_full_pool() -> void:
	# Directly exercise the id roll (bypassing the 75% present-level gate so empty rolls do not
	# dilute the sweep) and cap the seed loop ADAPTIVELY (scales with the pool) so this stays a
	# strong, non-brittle range seal as COMMON_PASSIVE_SKILL_POOL grows. Falsification targets:
	# a pinned pool[0] surfaces exactly one id, and an off-by-one range (e.g. size-2) never reaches
	# the last id -- both fail the full-coverage assert.
	var pool_ids := {}
	for passive in LingpetCatalog.get_passive_skill_pool("maribo"):
		var pool_passive_id := str((passive as Dictionary).get("id", "")).strip_edges()
		if pool_passive_id != "":
			pool_ids[pool_passive_id] = true
	_expect(pool_ids.size() >= 2, "common passive pool should expose at least two passives for the range check")
	var seen := {}
	var saw_invalid := false
	var seed_cap := maxi(4000, pool_ids.size() * 400)
	for seed in range(1, seed_cap + 1):
		var rng := RandomNumberGenerator.new()
		rng.seed = int(seed)
		var rolled := str(LingpetCatalog._roll_hatch_passive_id(rng))
		seen[rolled] = true
		if not pool_ids.has(rolled):
			saw_invalid = true
		if seen.size() == pool_ids.size():
			break
	_expect(not saw_invalid, "direct hatch passive id roll should only return common-pool members")
	_expect_eq(seen.size(), pool_ids.size(), "direct hatch passive id roll should reach every common-pool index (full uniform range)")


func _verify_hatch_stat_roll_projection_and_caps() -> void:
	var affinity_state := LingpetAffinityState.new()
	affinity_state.set_hatch_stat_roll("maribo", 0.5, 0.5)
	_expect(bool(affinity_state.has_hatch_stat_roll("maribo")), "hatch stat roll should be tracked per pet")
	var coordinator := LingpetAffinityContextCoordinator.new()
	var profile := LingpetCurrentProfile.new()
	profile.set_pet_id("maribo")
	coordinator.sync_current_profile("maribo", "maribo", profile, EmptyLoadoutState.new(), affinity_state)
	var base_speed := LingpetCatalog.get_stat("maribo", "patrol_speed_default", 120.0)
	var base_defense := LingpetCatalog.get_stat("maribo", "defense_rate", 0.0)
	_expect_float(profile.get_stat("patrol_speed_default", 0.0), base_speed * 1.15, "hatch mobility headstart should raise patrol speed by its share of the +30 percent cap")
	_expect_float(profile.get_stat("defense_rate", 0.0), base_defense + 0.04, "hatch defense headstart should raise patrol defense by its share of the +0.08 cap")

	var capped_rewards := LingpetAffinityState.get_empty_reward_counts()
	capped_rewards["mobility_stacks"] = LingpetAffinityState.MAX_MOBILITY_STACKS
	capped_rewards["defense_stacks"] = LingpetAffinityState.MAX_DEFENSE_STACKS
	capped_rewards["signature"] = "hatch-cap-fixture"
	profile.set_enhancement_rewards(capped_rewards)
	_expect_float(profile.get_stat("patrol_speed_default", 0.0), base_speed * 1.30, "hatch mobility plus enhancement mobility should share the +30 percent cap")
	_expect_float(profile.get_stat("defense_rate", 0.0), base_defense + 0.08, "hatch defense plus enhancement defense should share the +0.08 cap")

	var flight_profile := LingpetCurrentProfile.new()
	flight_profile.set_pet_id("rabi")
	flight_profile.set_hatch_stat_roll(0.5, 1.0)
	flight_profile.set_enhancement_rewards(capped_rewards)
	var base_appearance := LingpetCatalog.get_stat("rabi", "appearance_rate", 0.0)
	_expect_float(flight_profile.get_stat("appearance_rate", 0.0), base_appearance + 0.30, "flight mobility headstart plus enhancement mobility should share the +0.30 appearance bonus cap")
	_expect_float(flight_profile.get_stat("defense_rate", 0.0), 0.0, "flight hatch defense headstart should stay a dead-stat no-op")

	affinity_state.reset_for_new_run()
	_expect(not bool(affinity_state.has_hatch_stat_roll("maribo")), "new run reset should clear hatch stat rolls")


func _verify_hatch_candidate_pool_exhaustion() -> void:
	# Realistic small-pool exhaustion, kept at the catalog unit level. The live catalog
	# gates every enabled lingpet to {junior, smasher} (a 12-pet pool), so there is NO
	# natural hatch context with a <= 3 candidate pool to exercise this through the plaza
	# integration smoke. A synthetic ENTRIES table (not a fake context forced into the
	# integration path) is the honest way to lock the gate that produces
	# should_spawn_egg == false / the runtime's no_hatch_candidates reason.
	var entries := {
		"alpha": {"unlock": {"league_mode": "junior", "character_type": "smasher"}},
		"beta": {"unlock": {"league_mode": "junior", "character_type": "smasher"}},
		# Same league, different character -> must be gated OUT of a smasher context.
		"gamma": {"unlock": {"league_mode": "junior", "character_type": "viper"}},
		# Disabled -> never a candidate even with a matching unlock.
		"delta": {"enabled": false, "unlock": {"league_mode": "junior", "character_type": "smasher"}},
	}
	var ctx := {"league_mode": "junior", "character_type": "smasher"}

	var full_pool := LingpetCatalog.get_hatch_candidates_from_entries(entries, ctx, [])
	_expect_eq(full_pool.size(), 2, "unlock + enabled gating should yield exactly the 2 matching smasher pets")
	_expect(full_pool.has("alpha") and full_pool.has("beta"), "matching enabled pets should be candidates")
	_expect(not full_pool.has("gamma"), "a different-character pet must be gated out of the candidate pool")
	_expect(not full_pool.has("delta"), "a disabled pet must never be a candidate")

	var partial := LingpetCatalog.get_hatch_candidates_from_entries(entries, ctx, ["alpha"])
	_expect_eq(partial.size(), 1, "owning one candidate should leave exactly the other unowned")
	_expect(partial.has("beta"), "the still-unowned candidate should remain")

	var exhausted := LingpetCatalog.get_hatch_candidates_from_entries(entries, ctx, ["alpha", "beta"])
	_expect_eq(exhausted.size(), 0, "owning every matching candidate should exhaust the pool (should_spawn_egg == false)")
	_expect_str(
		LingpetCatalog.pick_hatch_pet_id_from_entries(entries, ctx, ["alpha", "beta"]),
		"",
		"an exhausted pool should pick no pet (drives the runtime no_hatch_candidates reason)"
	)


func _expect_hatch_skill_shape(loadout: Dictionary, active: bool) -> void:
	var prefix := "active" if active else "passive"
	var skill_id := str(loadout.get("%s_skill_id" % prefix, ""))
	var level := int(loadout.get("%s_skill_level" % prefix, 0))
	var slot_count := int(loadout.get("%s_slot_count" % prefix, 0))
	var ids: Array = loadout.get("%s_skill_ids" % prefix, []) as Array
	var levels: Dictionary = loadout.get("%s_skill_levels" % prefix, {}) as Dictionary
	if level == 0:
		_expect_str(skill_id, "", "%s missing hatch roll should keep an empty id" % prefix)
		_expect_eq(slot_count, 0, "%s missing hatch roll should keep slot_count 0" % prefix)
		_expect_eq(ids.size(), 0, "%s missing hatch roll should keep ids empty" % prefix)
	else:
		_expect(skill_id != "", "%s present hatch roll should write a skill id" % prefix)
		_expect_eq(slot_count, 1, "%s present hatch roll should open exactly one slot" % prefix)
		_expect_eq(ids.size(), 1, "%s present hatch roll should expose exactly one id" % prefix)
		_expect_eq(int(levels.get(skill_id, 0)), level, "%s present hatch roll should mirror its level map" % prefix)


func _loadout_signature(loadout: Dictionary) -> String:
	return "%s|%d|%d|%s|%d|%d" % [
		str(loadout.get("active_skill_id", "")),
		int(loadout.get("active_skill_level", 0)),
		int(loadout.get("active_slot_count", 0)),
		str(loadout.get("passive_skill_id", "")),
		int(loadout.get("passive_skill_level", 0)),
		int(loadout.get("passive_slot_count", 0)),
	]


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: int, expected: int, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %d, got %d)" % [message, expected, actual])


func _expect_float(actual: float, expected: float, message: String) -> void:
	if not is_equal_approx(actual, expected):
		_failures.append("%s (expected %.3f, got %.3f)" % [message, expected, actual])


func _expect_str(actual: String, expected: String, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, expected, actual])
