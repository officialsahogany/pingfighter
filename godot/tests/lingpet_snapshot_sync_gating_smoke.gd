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


class NullRegistry:
	extends RefCounted

	func get_instance(_key: String) -> Object:
		return null


var _failures: Array[String] = []


func _init() -> void:
	_verify_stable_ticks_stay_within_volatile_write_budget()
	_verify_pet_switch_converges_static_keys()
	_verify_level_change_updates_display_keys()
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
	var sets_before: int = owner.set_attempts
	owner.set_counts_by_key = {}
	for _i in range(100):
		setup["runtime"].update(1.0 / 72.0, owner, setup["registry"])
	var sets: int = owner.set_attempts - sets_before
	print("lingpet_snapshot_sync_gating_smoke: stable 100-tick owner.set count = %d" % sets)
	_expect(
		sets <= 100 * 12,
		"100 stable companion ticks should stay within the volatile write budget (got %d sets, pre-fix ~10100; top keys: %s)" % [sets, owner.top_set_keys()]
	)


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


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
