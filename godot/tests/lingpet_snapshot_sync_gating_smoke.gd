extends SceneTree

# Seals the F-lingpet-1 snapshot sync gating contract: the per-tick
# lingpet_runtime_snapshot_builder.sync_owner used to issue ~83 unconditional
# owner.set() calls (static names/descriptions/pools included) plus per-tick
# array duplicates — 0.32ms/tick standing, 38% of the lingpet update.
#
# 1. 100 stable companion ticks stay within a small volatile-key write budget
#    (pre-fix: ~83 sets EVERY tick).
# 2. After a pet switch the static keys converge to the new pet's values.
# 3. A level change updates the related display keys.
# 4. Mutating the owner-held slots array can neither alias the builder cache
#    nor leak into the next legitimate push (fresh detached copies).
# The schema-declared key seal stays in character_info_live_stats_smoke and
# now also scans the gated _set_single/_set_pair helpers.

const BattleSceneState := preload("res://scripts/core/battle_scene_state.gd")
const LingpetAffinityState := preload("res://scripts/lingpet/lingpet_affinity_state.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")


class SchemaGatedCountingOwner:
	extends RefCounted

	var scene_state: Object = BattleSceneState.new()
	var set_attempts: int = 0
	var set_counts_by_key: Dictionary = {}

	func _init() -> void:
		scene_state.reset()

	func _get(property: StringName) -> Variant:
		var key := str(property)
		if scene_state.has_key(key):
			return scene_state.get_value(key)
		return null

	func _set(property: StringName, value: Variant) -> bool:
		set_attempts += 1
		var key := str(property)
		set_counts_by_key[key] = int(set_counts_by_key.get(key, 0)) + 1
		if not scene_state.has_key(key):
			return false
		scene_state.set_value(key, value)
		return true

	func top_set_keys(limit: int = 12) -> String:
		var entries: Array = []
		for key in set_counts_by_key:
			entries.append([int(set_counts_by_key[key]), str(key)])
		entries.sort_custom(func(a, b): return int(a[0]) > int(b[0]))
		var parts: Array[String] = []
		for i in range(mini(limit, entries.size())):
			parts.append("%s=%d" % [entries[i][1], entries[i][0]])
		return ", ".join(parts)

	func queue_redraw() -> void:
		pass

	func value_of(key: String) -> Variant:
		return scene_state.get_value(key) if scene_state.has_key(key) else null

	func set_value(key: String, value: Variant) -> void:
		if scene_state.has_key(key):
			scene_state.set_value(key, value)


class NullRegistry:
	extends RefCounted

	func get_instance(_key: String) -> Object:
		return null


var _failures: Array[String] = []


func _init() -> void:
	_verify_stable_ticks_stay_within_volatile_write_budget()
	_verify_runtime_snapshot_reuses_same_frame_cache()
	_verify_static_surface_resyncs_after_enhancement_change()
	_verify_skill_effects_skip_idle_runtime_updates()
	_verify_pet_switch_converges_static_keys()
	_verify_level_change_updates_display_keys()
	_verify_second_skill_live_values_sync_through_schema_owner()
	_verify_owner_array_mutation_cannot_poison_cache()

	ProjectResourceLoader.clear_caches()
	if _failures.is_empty():
		print("lingpet_snapshot_sync_gating_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _make_companion_setup(active_level: int = 1) -> Dictionary:
	var runtime: Object = LingpetEggRuntime.new()
	var owner := SchemaGatedCountingOwner.new()
	var registry := NullRegistry.new()
	_expect(
		bool(runtime.debug_grant_and_activate_pet("maribo", owner, false, "maribo_hydro_sphere", "lingpet_starlight_tracking", registry, active_level, 1)),
		"gating smoke should activate a Maribo companion through the debug grant"
	)
	runtime.update(1.0 / 72.0, owner, registry)
	return {"runtime": runtime, "owner": owner, "registry": registry}


func _verify_stable_ticks_stay_within_volatile_write_budget() -> void:
	var setup := _make_companion_setup()
	var owner: SchemaGatedCountingOwner = setup["owner"]
	var runtime: Object = setup["runtime"]
	runtime._snapshot_builder.reset_owner_sync_build_counters_for_tests()
	var sets_before: int = owner.set_attempts
	owner.set_counts_by_key = {}
	for _i in range(100):
		runtime.update(1.0 / 72.0, owner, setup["registry"])
	var sets: int = owner.set_attempts - sets_before
	var static_builds: int = int(runtime._snapshot_builder.get_owner_static_surface_build_count_for_tests())
	print("lingpet_snapshot_sync_gating_smoke: stable 100-tick owner.set count = %d" % sets)
	print("lingpet_snapshot_sync_gating_smoke: stable 100-tick owner static surface builds = %d" % static_builds)
	_expect(
		sets <= 100 * 12,
		"100 stable companion ticks should stay within the volatile write budget (got %d sets, pre-fix ~10100; top keys: %s)" % [sets, owner.top_set_keys()]
	)
	_expect(
		static_builds <= 2,
		"100 stable companion ticks should skip the static owner surface build after convergence (got %d builds)" % static_builds
	)


func _verify_runtime_snapshot_reuses_same_frame_cache() -> void:
	var setup := _make_companion_setup()
	var owner: SchemaGatedCountingOwner = setup["owner"]
	var runtime: Object = setup["runtime"]
	runtime.reset_runtime_snapshot_cache_counters_for_tests()
	var first_snapshot: Dictionary = runtime.get_snapshot()
	var second_snapshot: Dictionary = runtime.get_snapshot()
	_expect(first_snapshot == second_snapshot, "same-frame runtime snapshots should be stable when no state changes")
	_expect(
		int(runtime.get_runtime_snapshot_build_count_for_tests()) == 1,
		"same-frame get_snapshot calls should build the lingpet runtime snapshot once"
	)
	var base_patrol_speed: float = float(first_snapshot.get("companion_patrol_speed_default", 0.0))
	runtime.set_debug_move_speed_override(2.0)
	var changed_snapshot: Dictionary = runtime.get_snapshot()
	_expect(
		int(runtime.get_runtime_snapshot_build_count_for_tests()) == 2,
		"direct runtime state changes should invalidate the same-frame snapshot cache"
	)
	_expect(
		is_equal_approx(float(changed_snapshot.get("companion_patrol_speed_default", -1.0)), base_patrol_speed * 2.0),
		"invalidated snapshot should expose the changed move-speed override"
	)
	runtime.get_snapshot()
	_expect(
		int(runtime.get_runtime_snapshot_build_count_for_tests()) == 2,
		"changed snapshot should also be reused for later same-frame reads"
	)
	runtime.update(1.0 / 72.0, owner, setup["registry"])
	runtime.get_snapshot()
	_expect(
		int(runtime.get_runtime_snapshot_build_count_for_tests()) == 3,
		"runtime update should invalidate the snapshot cache before post-update HUD reads"
	)


func _verify_static_surface_resyncs_after_enhancement_change() -> void:
	var setup := _make_companion_setup()
	var owner: SchemaGatedCountingOwner = setup["owner"]
	var runtime: Object = setup["runtime"]
	for _i in range(100):
		runtime.update(1.0 / 72.0, owner, setup["registry"])
	var base_speed := float(owner.value_of("lingpet_companion_patrol_speed_default"))
	_expect(base_speed > 0.0, "resync fixture should start with a published companion patrol speed")
	runtime._snapshot_builder.reset_owner_sync_build_counters_for_tests()
	var result: Dictionary = runtime.apply_guardian_enhancement_candidate(
		{"type": LingpetAffinityState.REWARD_TYPE_MOBILITY},
		owner,
		setup["registry"],
		"maribo"
	)
	_expect(bool(result.get("accepted", false)), "resync fixture should accept one Guardian Enhance mobility stack")
	_expect(
		float(owner.value_of("lingpet_companion_patrol_speed_default")) > base_speed,
		"Guardian Enhance should refresh the owner surface immediately through its apply coordinator"
	)
	runtime.update(1.0 / 72.0, owner, setup["registry"])
	var static_builds: int = int(runtime._snapshot_builder.get_owner_static_surface_build_count_for_tests())
	var synced_speed := float(owner.value_of("lingpet_companion_patrol_speed_default"))
	print("lingpet_snapshot_sync_gating_smoke: enhancement-input static builds = %d" % static_builds)
	_expect(static_builds >= 1 and static_builds <= 2, "enhancement apply plus one runtime update should rebuild the static owner surface at most twice (got %d)" % static_builds)
	_expect(synced_speed > base_speed, "Guardian Enhance patrol speed should resync to the owner after the changed-input update")


func _verify_skill_effects_skip_idle_runtime_updates() -> void:
	var setup := _make_companion_setup()
	var owner: SchemaGatedCountingOwner = setup["owner"]
	var runtime: Object = setup["runtime"]
	owner.set_value("ball_active", false)
	runtime._companion_skill_state.cooldown = 5.0
	runtime.reset_skill_effect_update_counters_for_tests()
	for _i in range(20):
		runtime.update(1.0 / 72.0, owner, setup["registry"])
	var skips: int = int(runtime.get_skill_effect_idle_skip_count_for_tests())
	var runtime_updates: int = int(runtime.get_skill_effect_runtime_update_count_for_tests())
	print("lingpet_snapshot_sync_gating_smoke: idle skill_effect skips = %d runtime_updates = %d" % [skips, runtime_updates])
	_expect(skips >= 20, "cooldown/ball-inactive idle skill effects should take the fast path each tick (got %d skips)" % skips)
	_expect(runtime_updates == 0, "cooldown/ball-inactive idle skill effects should not call runtime update (got %d calls)" % runtime_updates)


func _verify_pet_switch_converges_static_keys() -> void:
	var setup := _make_companion_setup()
	var owner: SchemaGatedCountingOwner = setup["owner"]
	var runtime: Object = setup["runtime"]
	_expect(
		str(owner.value_of("lingpet_skill_id")) == "maribo_hydro_sphere",
		"pre-switch active skill id should be synced"
	)
	_expect(
		bool(runtime.debug_grant_and_activate_pet("rabi", owner, false, "rabi_ghost_summon", "", setup["registry"])),
		"gating smoke should switch to a Rabi companion"
	)
	runtime.update(1.0 / 72.0, owner, setup["registry"])
	_expect(str(owner.value_of("lingpet_id")) == "rabi", "static pet id key should converge to the new pet after a switch")
	_expect(
		str(owner.value_of("lingpet_skill_id")) == "rabi_ghost_summon",
		"static skill id key should converge to the new pet's skill after a switch"
	)


func _verify_level_change_updates_display_keys() -> void:
	var setup := _make_companion_setup()
	var owner: SchemaGatedCountingOwner = setup["owner"]
	var runtime: Object = setup["runtime"]
	_expect(int(owner.value_of("lingpet_active_skill_level")) == 1, "baseline active skill level should be synced")
	_expect(
		bool(runtime.debug_grant_and_activate_pet("maribo", owner, false, "maribo_hydro_sphere", "lingpet_starlight_tracking", setup["registry"], 3, 1)),
		"gating smoke should re-apply the loadout at level 3"
	)
	runtime.update(1.0 / 72.0, owner, setup["registry"])
	_expect(
		int(owner.value_of("lingpet_active_skill_level")) == 3,
		"level change should reach the display key through the gated sync (got %s)" % str(owner.value_of("lingpet_active_skill_level"))
	)


func _verify_second_skill_live_values_sync_through_schema_owner() -> void:
	var runtime: Object = LingpetEggRuntime.new()
	var owner := SchemaGatedCountingOwner.new()
	var registry := NullRegistry.new()
	owner.set_value("ball_active", true)
	owner.set_value("ball_pos", Vector2(380.0, 260.0))
	owner.set_value("ball_vel", Vector2(0.0, -12.0))
	_expect(
		bool(runtime.debug_grant_and_activate_pet("red_dragon", owner, false, "red_dragon_dragon_breath", "", registry, 1, 1)),
		"second-skill owner fixture should activate Red Dragon"
	)
	_force_second_active_runtime_profile(runtime, "red_dragon", "red_dragon_dragon_breath", "red_dragon_dragon_wing")
	runtime.configure_companion_motion_for_tests(Vector2(380.0, 260.0), 7, 0.0, true)
	runtime.update(0.05, owner, registry)
	runtime.update(0.10, owner, registry)
	var snapshot: Dictionary = runtime.get_snapshot()
	_expect(str(snapshot.get("companion_skill_id", "")) == "red_dragon_dragon_breath", "bare companion skill id should remain slot 0")
	_expect(snapshot.has("companion_skill_cooldown_duration"), "slot-0 snapshot should keep the bare cooldown-duration key for HUD back-compat")
	_expect(snapshot.has("companion_skill_windup_ratio"), "slot-0 snapshot should keep the bare windup-ratio key for HUD back-compat")
	_expect(not snapshot.has("companion_skill_id_0"), "slot-0 snapshot should not be renamed to an indexed key")
	_expect(str(snapshot.get("companion_skill_id_1", "")) == "red_dragon_dragon_wing", "slot-1 internal snapshot should expose the second active id")
	_expect(bool(snapshot.get("companion_skill_winding_up_1", false)), "slot-1 internal snapshot should expose live windup state")
	var snapshot_ratio := float(snapshot.get("companion_skill_windup_ratio_1", 0.0))
	_expect(snapshot_ratio > 0.0 and snapshot_ratio <= 1.0, "slot-1 internal snapshot should expose a normalized windup ratio")
	_expect(str(owner.value_of("lingpet_second_skill_id")) == "red_dragon_dragon_wing", "schema-gated owner should receive the live second skill id")
	_expect(str(owner.value_of("ringpet_second_skill_id")) == "red_dragon_dragon_wing", "ringpet mirror should receive the live second skill id")
	_expect(float(owner.value_of("lingpet_second_skill_cooldown_duration")) > 0.0, "schema-gated owner should receive the live second skill cooldown duration")
	_expect(float(owner.value_of("lingpet_second_skill_cooldown_duration")) < float(owner.value_of("lingpet_skill_cooldown_duration")), "second skill cooldown duration should stay divergent from slot 0")
	_expect(bool(owner.value_of("lingpet_second_skill_winding_up")), "schema-gated owner should receive live second skill windup state")
	var owner_ratio := float(owner.value_of("lingpet_second_skill_windup_ratio"))
	_expect(owner_ratio > 0.0 and owner_ratio <= 1.0, "schema-gated owner should receive a normalized second skill windup ratio")

	var locked_runtime: Object = LingpetEggRuntime.new()
	var locked_owner := owner
	_expect(
		bool(locked_runtime.debug_grant_and_activate_pet("red_dragon", locked_owner, false, "red_dragon_dragon_breath", "", registry, 1, 1)),
		"locked second-skill fixture should clear a previously live second-skill owner"
	)
	var locked_ids: Array[String] = ["red_dragon_dragon_breath", "red_dragon_dragon_wing"]
	locked_runtime._current_profile.active_skill_ids = locked_ids
	locked_runtime._current_profile.active_skill_levels = {"red_dragon_dragon_breath": 1, "red_dragon_dragon_wing": 1}
	locked_runtime._current_profile.active_slot_count = 2
	locked_runtime.update(0.05, locked_owner, registry)
	var locked_snapshot: Dictionary = locked_runtime.get_snapshot()
	_expect(str(locked_snapshot.get("companion_skill_id_1", "")) == "", "slot-1 snapshot should stay hidden before second_active_unlocked")
	_expect(is_equal_approx(float(locked_snapshot.get("companion_skill_cooldown_1", -1.0)), 0.0), "locked slot-1 snapshot cooldown should reset to default")
	_expect(is_equal_approx(float(locked_snapshot.get("companion_skill_cooldown_duration_1", -1.0)), 0.0), "locked slot-1 snapshot cooldown duration should reset to default")
	_expect(is_equal_approx(float(locked_snapshot.get("companion_skill_windup_ratio_1", -1.0)), 0.0), "locked slot-1 snapshot windup ratio should reset to default")
	_expect(not bool(locked_snapshot.get("companion_skill_ready_1", true)), "locked slot-1 snapshot ready should reset to default")
	_expect(str(locked_owner.value_of("lingpet_second_skill_id")) == "", "owner second skill id should stay default before second_active_unlocked")
	_expect(str(locked_owner.value_of("ringpet_second_skill_id")) == "", "ringpet owner second skill id should stay default before second_active_unlocked")
	_expect(is_equal_approx(float(locked_owner.value_of("lingpet_second_skill_cooldown")), 0.0), "owner second skill cooldown should clear stale live values before second_active_unlocked")
	_expect(is_equal_approx(float(locked_owner.value_of("lingpet_second_skill_cooldown_duration")), 0.0), "owner second skill cooldown duration should clear stale live values before second_active_unlocked")
	_expect(not bool(locked_owner.value_of("lingpet_second_skill_ready")), "owner second skill ready should stay default before second_active_unlocked")
	_expect(not bool(locked_owner.value_of("lingpet_second_skill_winding_up")), "owner second skill windup should stay default before second_active_unlocked")
	_expect(is_equal_approx(float(locked_owner.value_of("lingpet_second_skill_windup_ratio")), 0.0), "owner second skill windup ratio should clear stale live values before second_active_unlocked")


func _verify_owner_array_mutation_cannot_poison_cache() -> void:
	var setup := _make_companion_setup()
	var owner: SchemaGatedCountingOwner = setup["owner"]
	var runtime: Object = setup["runtime"]
	var owner_slots_value: Variant = owner.value_of("lingpet_slots")
	_expect(owner_slots_value is Array, "owner should hold a synced lingpet slots array")
	if owner_slots_value is Array:
		(owner_slots_value as Array).append("junk_external_mutation")
	runtime.update(1.0 / 72.0, owner, setup["registry"])
	_expect(
		bool(runtime.debug_grant_and_activate_pet("rabi", owner, false, "rabi_ghost_summon", "", setup["registry"])),
		"gating smoke should change the slot lineup after the external mutation"
	)
	runtime.update(1.0 / 72.0, owner, setup["registry"])
	var refreshed: Variant = owner.value_of("lingpet_slots")
	_expect(refreshed is Array, "owner should hold a refreshed lingpet slots array")
	if refreshed is Array:
		_expect(
			not (refreshed as Array).has("junk_external_mutation"),
			"a legitimate slot change must deliver a fresh detached copy, not the externally mutated array"
		)
		_expect(
			(refreshed as Array).has("rabi"),
			"the refreshed slots array should contain the newly granted pet"
		)


func _force_second_active_runtime_profile(runtime: Object, pet_id: String, first_skill_id: String, second_skill_id: String) -> void:
	var ids: Array[String] = [first_skill_id, second_skill_id]
	var levels: Dictionary = {}
	if first_skill_id != "":
		levels[first_skill_id] = 1
	if second_skill_id != "":
		levels[second_skill_id] = 1
	var rewards := LingpetAffinityState.get_empty_reward_counts()
	rewards["second_active_unlocked"] = true
	rewards["signature"] = "snapshot-sync-second-active-%s-%s" % [first_skill_id, second_skill_id]
	runtime._current_profile.set_pet_id(pet_id)
	runtime._current_profile.active_skill_ids = ids
	runtime._current_profile.active_skill_levels = levels
	runtime._current_profile.active_slot_count = 2
	runtime._current_profile.active_skill_id = first_skill_id
	runtime._current_profile.active_skill_level = 1 if first_skill_id != "" else 0
	runtime._current_profile.set_enhancement_rewards(rewards)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
