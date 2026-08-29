extends SceneTree

const PerkConversionFlags := preload(
	"res://scripts/characters/perk_conversion_flags.gd"
)
const RuntimePerkCatalog := preload(
	"res://scripts/characters/runtime_perk_catalog.gd"
)
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentPerkCandidatePolicy := preload(
	"res://scripts/tower_ascent/tower_ascent_perk_candidate_policy.gd"
)
const TowerRewardPickOfferBuilder := preload(
	"res://scripts/tower_ascent/tower_reward_pick_offer_builder.gd"
)

const BOSS_SLOT_ID := "floor_01_dalji"
const SAMPLE_COUNT := 512
const MIGRATED_SWEEP_COUNT := 256

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var selected_character_type := "smasher"
	var current_stage := 1
	var stage1_boss_variant := "dalji"
	var stage_boss_variant := ""


class FakeUnlockStore:
	extends RefCounted

	func is_unlocked(_content_type: String, _content_id: String) -> bool:
		return true


class FakeSkillConfig:
	extends RefCounted

	var full := false

	func is_shared_slot_full() -> bool:
		return full

	func get_shared_slot_swap_candidates(_skill_id: String) -> Array:
		return []

	func get_skill_data(skill_id: String) -> Dictionary:
		if skill_id == "ghost_shot":
			return {"id": skill_id, "name": "Ghost Shot"}
		return {}


class FakeRuntimeState:
	extends RefCounted

	var runtime_skill_levels: Dictionary = {}
	var fusion_candidate_ids: Array[String] = []

	func get_perk_fusion_candidate_ids(_catalog: Object) -> Array:
		return fusion_candidate_ids.duplicate()

	func get_downtown_treasure_map_reward_pick_multiplier() -> float:
		return 1.0


class FakeCatalog:
	extends RefCounted

	var get_all_calls := 0
	var get_choices_calls := 0
	var has_open_calls := 0
	var training_migrated_raw_only := false

	func get_all_perk_data() -> Dictionary:
		get_all_calls += 1
		if training_migrated_raw_only:
			var migrated_raw: Dictionary = {}
			for perk_id_value: Variant in RuntimePerkCatalog.TRAINING_MIGRATED_PERK_IDS.keys():
				var perk_id := str(perk_id_value)
				migrated_raw[perk_id] = {
					"name": "Raw migrated %s" % perk_id,
					"max_level": 5,
				}
			return migrated_raw
		return {
			"owned_mugong": {
				"name": "Owned Mugong",
				"max_level": 5,
				"descriptions": {1: "Owned level one"},
			},
			"new_mugong": {
				"name": "New Mugong",
				"max_level": 5,
				"descriptions": {1: "New level one"},
			},
			"unlock_ghost_shot": {
				"name": "Ghost Shot Manual",
				"max_level": 1,
				"rarity": "rare",
				"character_restriction": "smasher",
				"unlocks_skill": "ghost_shot",
			},
			"excluded_instant": {
				"name": "Excluded Instant",
				"max_level": 1,
				"tree": "instant",
				"is_instant": true,
			},
		}

	func get_choices(
		_character_type: String,
		_runtime_levels: Dictionary,
		_exclude_instant: bool = false,
		_base_choice_count: int = 3,
		_owner: Object = null,
		_registry: Object = null
	) -> Array:
		get_choices_calls += 1
		# Deliberately disturb the global stream if the removed legacy path is
		# invoked. The production-path RNG counterproof below then turns RED.
		randf()
		return []

	func has_open_perk_slot(
		_runtime_levels: Dictionary,
		_registry: Object = null
	) -> bool:
		has_open_calls += 1
		return false

	func get_perk_data(perk_id: String) -> Dictionary:
		if perk_id == TowerRewardPickOfferBuilder.REFRESH_CHOICE_ID:
			return {
				"id": perk_id,
				"name": "Refresh",
				"description": "Reroll this reward offer.",
				"detail": "Build the next deterministic generation.",
				"tree": "instant",
				"is_instant": true,
			}
		return {
			"id": perk_id,
			"name": "Supreme %s" % perk_id,
			"description": "Supreme reward",
			"max_level": 1,
		}


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Variant:
		return instances.get(key, null)

	func get_cached_instance(key: String) -> Variant:
		return instances.get(key, null)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	PerkConversionFlags.debug_set_enabled(true)
	_verify_v3_constants_and_unowned_full_slot_pool()
	_verify_training_migrated_candidate_gate_and_v3_sweep()
	_verify_refresh_chosik_supreme_and_generation()
	_verify_builder_owns_every_rng_draw()
	_verify_refresh_distribution()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	PerkConversionFlags.debug_set_enabled(false)
	if _failures.is_empty():
		print("tower_reward_pick_v3_offer_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_training_migrated_candidate_gate_and_v3_sweep() -> void:
	var migrated_ids: Array[String] = []
	for perk_id_value: Variant in RuntimePerkCatalog.TRAINING_MIGRATED_PERK_IDS.keys():
		migrated_ids.append(str(perk_id_value))
	migrated_ids.sort()
	_expect(migrated_ids.size() == 10, "training-migrated candidate seal must cover all ten IDs")
	var catalog := FakeCatalog.new()
	catalog.training_migrated_raw_only = true
	var runtime := FakeRuntimeState.new()
	var registry := _build_registry(runtime, catalog)
	var raw_catalog := catalog.get_all_perk_data()
	var policy := TowerAscentPerkCandidatePolicy.new()

	PerkConversionFlags.debug_set_enabled(false)
	var legacy_eligible := 0
	for perk_id in migrated_ids:
		var raw_entry: Dictionary = (raw_catalog.get(perk_id, {}) as Dictionary).duplicate(true)
		raw_entry["id"] = perk_id
		_expect(
			not raw_entry.has("is_physique_training"),
			"raw v3 fixture must omit is_physique_training for %s" % perk_id
		)
		if policy.is_mugong_candidate(raw_entry, {}, "smasher", registry):
			legacy_eligible += 1
	_expect(
		legacy_eligible == migrated_ids.size(),
		"flag-OFF legacy policy must keep all ten migrated IDs eligible, got %d"
		% legacy_eligible
	)

	PerkConversionFlags.debug_set_enabled(true)
	var flag_on_rejected := 0
	for perk_id in migrated_ids:
		var raw_entry: Dictionary = (raw_catalog.get(perk_id, {}) as Dictionary).duplicate(true)
		raw_entry["id"] = perk_id
		if not policy.is_mugong_candidate(raw_entry, {}, "smasher", registry):
			flag_on_rejected += 1
	_expect(
		flag_on_rejected == migrated_ids.size(),
		"flag-ON policy must reject all ten migrated IDs, got %d"
		% flag_on_rejected
	)

	var hit_counts: Dictionary = {}
	for perk_id in migrated_ids:
		hit_counts[perk_id] = 0
	var offer_failures := 0
	var builder := TowerRewardPickOfferBuilder.new()
	for sample_index in range(MIGRATED_SWEEP_COUNT):
		var offer := builder.build_offer(
			_build_context("training-migrated-%03d" % sample_index),
			FakeOwner.new(),
			registry,
			{"vision": 1.0, "supreme": 1.0, "refresh": 1.0, "chosik": 1.0},
			sample_index % 4
		)
		if not bool(offer.get("accepted", false)):
			offer_failures += 1
			continue
		for choice_value: Variant in offer.get("choices", []):
			if not (choice_value is Dictionary):
				continue
			var choice_id := str((choice_value as Dictionary).get("id", ""))
			if hit_counts.has(choice_id):
				hit_counts[choice_id] = int(hit_counts.get(choice_id, 0)) + 1
	var total_hits := 0
	for perk_id in migrated_ids:
		var perk_hits := int(hit_counts.get(perk_id, 0))
		total_hits += perk_hits
		_expect(
			perk_hits == 0,
			"flag-ON v3 sweep must offer migrated ID %s zero times, got %d"
			% [perk_id, perk_hits]
		)
	_expect(offer_failures == 0, "training-migrated v3 sweep must keep offers available")
	print(
		"tower_reward_pick_v3_training_migrated_sweep: ids=%d samples=%d failures=%d hits=%d legacy_eligible=%d flag_on_rejected=%d"
		% [
			migrated_ids.size(),
			MIGRATED_SWEEP_COUNT,
			offer_failures,
			total_hits,
			legacy_eligible,
			flag_on_rejected,
		]
	)


func _verify_v3_constants_and_unowned_full_slot_pool() -> void:
	_expect(
		TowerRewardPickOfferBuilder.OFFER_VERSION == "tower_reward_pick_v3",
		"reward-pick offer version must be v3"
	)
	_expect(
		is_equal_approx(TowerRewardPickOfferBuilder.TEMP_REFRESH_CHANCE, 0.15),
		"refresh appearance chance must be 15 percent"
	)
	_expect(
		TowerRewardPickOfferBuilder.TEMP_REFRESH_COST == 1,
		"refresh must cost one Muhon"
	)
	_expect(
		TowerRewardPickOfferBuilder.TEMP_BAG_EXPANSION_COST == 2,
		"bag expansion must cost two Muhon"
	)
	var runtime := FakeRuntimeState.new()
	runtime.runtime_skill_levels = {"owned_mugong": 2}
	var catalog := FakeCatalog.new()
	var registry := _build_registry(runtime, catalog)
	var offer := TowerRewardPickOfferBuilder.new().build_offer(
		_build_context("unowned-full-slot"),
		FakeOwner.new(),
		registry,
		{"vision": 1.0, "supreme": 1.0, "refresh": 1.0, "chosik": 1.0}
	)
	var choices: Array = offer.get("choices", [])
	_expect(bool(offer.get("accepted", false)), "unowned full-slot offer must generate")
	_expect(_has_choice_id(choices, "new_mugong"), "new Mugong must remain eligible when slots are full")
	_expect(not _has_choice_id(choices, "owned_mugong"), "owned below-max Mugong must not return as a reward upgrade")
	_expect(not _has_choice_id(choices, "unlock_ghost_shot"), "Chosik must not leak into the Mugong pool")
	var new_mugong := _find_choice(choices, "new_mugong")
	_expect(
		bool(new_mugong.get("reward_pick_replacement_eligible", false)),
		"new Mugong must carry the live replacement-route marker"
	)
	var bag := _find_choice(choices, TowerRewardPickOfferBuilder.BAG_EXPANSION_CHOICE_ID)
	_expect(not bag.is_empty(), "reward-only bag expansion must enter the special-card pool")
	_expect(
		str(bag.get("reward_pick_kind", "")) == "bag_expansion"
		and int(bag.get("reward_pick_cost", -1)) == 2
		and bool(bag.get("is_instant", false)),
		"bag expansion must be a two-Muhon slot-free special card"
	)
	_expect(catalog.get_choices_calls == 0, "v3 must never call the globally randomized catalog picker")
	_expect(catalog.get_all_calls == 1, "v3 must enumerate canonical perk data exactly once per offer")
	_expect(catalog.has_open_calls == 0, "offer generation must not filter new Mugong by current slot capacity")
	_expect(int(offer.get("offer_generation", -1)) == 0, "backward-compatible offers must default to generation zero")
	for choice_value: Variant in choices:
		if choice_value is Dictionary:
			_expect(
				int((choice_value as Dictionary).get("reward_pick_offer_generation", -1)) == 0,
				"every default offer card must carry generation zero"
			)


func _verify_refresh_chosik_supreme_and_generation() -> void:
	var runtime := FakeRuntimeState.new()
	var catalog := FakeCatalog.new()
	var registry := _build_registry(runtime, catalog)
	var builder := TowerRewardPickOfferBuilder.new()
	var context := _build_context("refresh-chosik-supreme")
	var overrides := {
		"vision": 1.0,
		"supreme": 0.0,
		"refresh": 0.149999,
		"chosik": 0.249999,
	}
	var first := builder.build_offer(context, FakeOwner.new(), registry, overrides, 7)
	var repeated := builder.build_offer(context, FakeOwner.new(), registry, overrides, 7)
	var choices: Array = first.get("choices", [])
	_expect(bool(first.get("accepted", false)), "forced v3 lane offer must generate")
	_expect(choices.size() == 4, "Supreme, refresh, Chosik, and Mugong must coexist in four slots")
	_expect(_count_kind(choices, "supreme") == 1, "full Mugong slots must not suppress an unowned Supreme card")
	_expect(_count_kind(choices, "refresh") == 1, "refresh roll below 0.15 must append exactly one card")
	_expect(_count_kind(choices, "chosik") == 1, "open Chosik roll below 0.25 must append exactly one card")
	_expect(_count_kind(choices, "mugong") == 1, "protected lanes must retain one unowned Mugong")
	var refresh := _find_choice(choices, TowerRewardPickOfferBuilder.REFRESH_CHOICE_ID)
	_expect(
		int(refresh.get("reward_pick_cost", -1)) == 1
		and int(refresh.get("reward_pick_offer_generation", -1)) == 7,
		"refresh must expose its one-Muhon price and generation"
	)
	_expect(int(first.get("offer_generation", -1)) == 7, "offer must expose the requested reroll generation")
	_expect(
		var_to_bytes(first.get("choices", [])) == var_to_bytes(repeated.get("choices", [])),
		"same context, runtime state, overrides, and generation must be byte-identical"
	)
	_expect(catalog.has_open_calls == 0, "Supreme generation must bypass the obsolete open-slot gate")
	var boundary := builder.build_offer(
		context,
		FakeOwner.new(),
		registry,
		{"vision": 1.0, "supreme": 1.0, "refresh": 0.15, "chosik": 1.0},
		7
	)
	_expect(
		_count_kind(boundary.get("choices", []), "refresh") == 0,
		"refresh roll exactly at 0.15 must miss the strict boundary"
	)
	var next_generation := builder.build_offer(context, FakeOwner.new(), registry, overrides, 8)
	_expect(int(next_generation.get("offer_generation", -1)) == 8, "reroll counter must advance offer generation metadata")
	for choice_value: Variant in next_generation.get("choices", []):
		if choice_value is Dictionary:
			_expect(
				int((choice_value as Dictionary).get("reward_pick_offer_generation", -1)) == 8,
				"rerolled cards must carry their new generation"
			)


func _verify_builder_owns_every_rng_draw() -> void:
	var runtime := FakeRuntimeState.new()
	var catalog := FakeCatalog.new()
	var registry := _build_registry(runtime, catalog)
	var builder := TowerRewardPickOfferBuilder.new()
	var context := _build_context("local-rng-counterproof")
	seed(918273)
	var expected_first := randf()
	var expected_second := randf()
	seed(918273)
	var actual_first := randf()
	var offer_a := builder.build_offer(context, FakeOwner.new(), registry, {}, 3)
	var actual_second := randf()
	_expect(is_equal_approx(actual_first, expected_first), "global RNG fixture must start from its expected first draw")
	_expect(
		is_equal_approx(actual_second, expected_second),
		"production v3 offer generation must not advance global RNG state"
	)
	for _index in range(31):
		randf()
	var offer_b := builder.build_offer(context, FakeOwner.new(), registry, {}, 3)
	_expect(
		var_to_bytes(offer_a.get("choices", [])) == var_to_bytes(offer_b.get("choices", [])),
		"unrelated global RNG draws must not perturb a v3 offer"
	)
	_expect(catalog.get_choices_calls == 0, "production v3 invocation must keep the legacy picker counter at zero")


func _verify_refresh_distribution() -> void:
	var runtime := FakeRuntimeState.new()
	var catalog := FakeCatalog.new()
	var registry := _build_registry(runtime, catalog)
	var builder := TowerRewardPickOfferBuilder.new()
	var refresh_count := 0
	for sample_index in range(SAMPLE_COUNT):
		var offer := builder.build_offer(
			_build_context("refresh-sample-%04d" % sample_index),
			FakeOwner.new(),
			registry,
			{"vision": 1.0, "supreme": 1.0, "chosik": 1.0}
		)
		refresh_count += _count_kind(offer.get("choices", []), "refresh")
	var rate := float(refresh_count) / float(SAMPLE_COUNT)
	_expect(
		rate >= 0.10 and rate <= 0.20,
		"512 deterministic contexts must converge around 15 percent refresh, got %.4f" % rate
	)
	print(
		"tower_reward_pick_v3_refresh_distribution: samples=%d hits=%d rate=%.4f"
		% [SAMPLE_COUNT, refresh_count, rate]
	)


func _build_registry(runtime: Object, catalog: Object) -> FakeRegistry:
	var registry := FakeRegistry.new()
	registry.instances = {
		"runtime_perk_state": runtime,
		"runtime_perk_catalog": catalog,
		"tower_ascent_unlock_store": FakeUnlockStore.new(),
		"smasher_skill_config": FakeSkillConfig.new(),
	}
	return registry


func _build_context(resolution_id: String) -> Dictionary:
	return {
		"node_resolution_id": resolution_id,
		"boss_slot_id": BOSS_SLOT_ID,
		"floor": 1,
		"map_seed": 912,
		"skipped_boss_ids": [],
		"burned_vision_boss_ids": [],
	}


func _find_choice(choices: Array, choice_id: String) -> Dictionary:
	for choice_value: Variant in choices:
		if (
			choice_value is Dictionary
			and str((choice_value as Dictionary).get("id", "")) == choice_id
		):
			return (choice_value as Dictionary).duplicate(true)
	return {}


func _has_choice_id(choices: Array, choice_id: String) -> bool:
	return not _find_choice(choices, choice_id).is_empty()


func _count_kind(choices: Array, kind: String) -> int:
	var count := 0
	for choice_value: Variant in choices:
		if (
			choice_value is Dictionary
			and str((choice_value as Dictionary).get("reward_pick_kind", "")) == kind
		):
			count += 1
	return count


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
