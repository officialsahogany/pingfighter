extends SceneTree

# Seals the F4-A transient sync slimming contract
# (docs/mythic_transient_sync_slimming_design.md): the per-tick
# sync_transient_owner_state used to read + duplicate(true) the owner's
# mythic_item_state and issue ~45 owner.get reads EVERY physics tick
# (~0.9ms/tick, 81% of the mythic update once an always-true gate item was
# equipped). Values are now compared against a syncer-side last-pushed cache:
#
# 1. A clean tick (no value changes) must not touch the owner AT ALL
#    (zero get attempts, zero set attempts) — fails pre-fix where every
#    tick read the owner 45+ times.
# 2. A dirty tick still reaches the owner and the schema-real
#    mythic_item_state channel carries the exact new value.
# 3. The drift net survives: a third-party owner rewrite plus a cache
#    invalidation (the full-sync / reset boundary hook) repairs the owner
#    on the next tick.
# 4. After a full _sync_owner the transient pass re-primes instead of
#    skipping on a stale cache, and goes back to zero-touch clean ticks.

const BattleSceneState := preload("res://scripts/core/battle_scene_state.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")


# Mirrors battle_scene_shell's schema-gated owner and counts every get/set
# ATTEMPT so clean ticks can be asserted as zero-touch.
class CountingOwner:
	extends RefCounted

	var scene_state: Object = BattleSceneState.new()
	var get_attempts: int = 0
	var set_attempts: int = 0
	var state_get_attempts: int = 0

	func _init() -> void:
		scene_state.reset()

	func _get(property: StringName) -> Variant:
		get_attempts += 1
		var key := str(property)
		if key == "mythic_item_state":
			state_get_attempts += 1
		if scene_state.has_key(key):
			return scene_state.get_value(key)
		return null

	func _set(property: StringName, value: Variant) -> bool:
		set_attempts += 1
		var key := str(property)
		if not scene_state.has_key(key):
			return false
		scene_state.set_value(key, value)
		return true

	func queue_redraw() -> void:
		pass

	func get_mythic_state() -> Dictionary:
		var value: Variant = scene_state.get_value("mythic_item_state")
		return value if value is Dictionary else {}


class NullRegistry:
	extends RefCounted

	func get_instance(_key: String) -> Object:
		return null


var _failures: Array[String] = []


func _init() -> void:
	_verify_clean_tick_is_owner_zero_touch()
	_verify_dirty_tick_reaches_owner_state()
	_verify_invalidate_repairs_third_party_overwrite()
	_verify_full_sync_reprimes_transient_cache()
	_verify_dirty_ticks_never_reread_owner_state()
	_verify_external_unknown_key_survives_rebase_and_pushes()
	_verify_full_sync_refresh_skips_rebase_read()

	if _failures.is_empty():
		print("mythic_transient_sync_slimming_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _make_primed_setup() -> Dictionary:
	var runtime: Object = MythicItemRuntime.new()
	var owner := CountingOwner.new()
	runtime.reset()
	runtime.owner_syncer.sync_transient_owner_state(runtime, owner)
	return {"runtime": runtime, "owner": owner, "syncer": runtime.owner_syncer}


func _verify_clean_tick_is_owner_zero_touch() -> void:
	var setup := _make_primed_setup()
	var owner: CountingOwner = setup["owner"]
	var gets_before: int = owner.get_attempts
	var sets_before: int = owner.set_attempts
	for _i in range(3):
		setup["syncer"].sync_transient_owner_state(setup["runtime"], owner)
	_expect(
		owner.get_attempts == gets_before,
		"clean transient ticks must not read the owner (got %d extra gets)" % (owner.get_attempts - gets_before)
	)
	_expect(
		owner.set_attempts == sets_before,
		"clean transient ticks must not write the owner (got %d extra sets)" % (owner.set_attempts - sets_before)
	)


func _verify_dirty_tick_reaches_owner_state() -> void:
	var setup := _make_primed_setup()
	var runtime: Object = setup["runtime"]
	var owner: CountingOwner = setup["owner"]
	runtime.smartphone_cooldown_frames = 123.0
	setup["syncer"].sync_transient_owner_state(runtime, owner)
	_expect(
		is_equal_approx(float(owner.get_mythic_state().get("smartphone_auto_cooldown_frames", -1.0)), 123.0),
		"dirty smartphone cooldown should land in owner mythic_item_state"
	)
	var gets_before: int = owner.get_attempts
	var sets_before: int = owner.set_attempts
	setup["syncer"].sync_transient_owner_state(runtime, owner)
	_expect(
		owner.get_attempts == gets_before and owner.set_attempts == sets_before,
		"tick after a dirty write should be zero-touch again"
	)


func _verify_invalidate_repairs_third_party_overwrite() -> void:
	var setup := _make_primed_setup()
	var runtime: Object = setup["runtime"]
	var owner: CountingOwner = setup["owner"]
	runtime.smartphone_cooldown_frames = 77.0
	setup["syncer"].sync_transient_owner_state(runtime, owner)
	owner.scene_state.set_value("mythic_item_state", {})
	setup["syncer"].invalidate_transient_sync_cache()
	setup["syncer"].sync_transient_owner_state(runtime, owner)
	_expect(
		is_equal_approx(float(owner.get_mythic_state().get("smartphone_auto_cooldown_frames", -1.0)), 77.0),
		"invalidated cache should repair a third-party owner state wipe on the next tick"
	)


func _verify_full_sync_reprimes_transient_cache() -> void:
	var setup := _make_primed_setup()
	var runtime: Object = setup["runtime"]
	var owner: CountingOwner = setup["owner"]
	var registry := NullRegistry.new()
	runtime.smartphone_cooldown_frames = 55.0
	runtime._sync_owner(owner, registry)
	setup["syncer"].sync_transient_owner_state(runtime, owner)
	_expect(
		is_equal_approx(float(owner.get_mythic_state().get("smartphone_auto_cooldown_frames", -1.0)), 55.0),
		"transient tick after a full sync must not skip on a stale cache"
	)
	var gets_before: int = owner.get_attempts
	var sets_before: int = owner.set_attempts
	setup["syncer"].sync_transient_owner_state(runtime, owner)
	_expect(
		owner.get_attempts == gets_before and owner.set_attempts == sets_before,
		"clean tick after a full-sync re-prime should be zero-touch"
	)


# v2 contract (pushed-dict 보유): dirty ticks must not re-read the owner's
# mythic_item_state — cooldown countdown keys make every tick dirty, so the
# old read+duplicate(true) per dirty tick stayed a standing per-tick cost.
func _verify_dirty_ticks_never_reread_owner_state() -> void:
	var setup := _make_primed_setup()
	var runtime: Object = setup["runtime"]
	var owner: CountingOwner = setup["owner"]
	var state_gets_before: int = owner.state_get_attempts
	for i in range(100):
		runtime.smartphone_cooldown_frames = 200.0 - float(i)
		setup["syncer"].sync_transient_owner_state(runtime, owner)
	var state_gets: int = owner.state_get_attempts - state_gets_before
	_expect(
		state_gets <= 1,
		"100 dirty transient ticks should read owner mythic_item_state at most once (got %d)" % state_gets
	)
	_expect(
		is_equal_approx(float(owner.get_mythic_state().get("smartphone_auto_cooldown_frames", -1.0)), 101.0),
		"last dirty value should still land in owner mythic_item_state"
	)


func _verify_external_unknown_key_survives_rebase_and_pushes() -> void:
	var runtime: Object = MythicItemRuntime.new()
	var owner := CountingOwner.new()
	runtime.reset()
	owner.scene_state.set_value("mythic_item_state", {"external_unknown_key": "keepme"})
	var syncer: Object = runtime.owner_syncer
	syncer.sync_transient_owner_state(runtime, owner)
	_expect(
		str(owner.get_mythic_state().get("external_unknown_key", "")) == "keepme",
		"external unknown key should survive the one-time cache rebase"
	)
	runtime.smartphone_cooldown_frames = 42.0
	syncer.sync_transient_owner_state(runtime, owner)
	_expect(
		str(owner.get_mythic_state().get("external_unknown_key", "")) == "keepme",
		"external unknown key should keep riding later cached pushes"
	)
	_expect(
		is_equal_approx(float(owner.get_mythic_state().get("smartphone_auto_cooldown_frames", -1.0)), 42.0),
		"known keys should still update alongside the preserved external key"
	)


func _verify_full_sync_refresh_skips_rebase_read() -> void:
	var setup := _make_primed_setup()
	var runtime: Object = setup["runtime"]
	var owner: CountingOwner = setup["owner"]
	runtime._sync_owner(owner, NullRegistry.new())
	var state_gets_before: int = owner.state_get_attempts
	runtime.smartphone_cooldown_frames = 9.0
	setup["syncer"].sync_transient_owner_state(runtime, owner)
	_expect(
		owner.state_get_attempts == state_gets_before,
		"full sync should refresh the pushed cache so the next dirty tick needs no owner re-read"
	)
	_expect(
		is_equal_approx(float(owner.get_mythic_state().get("smartphone_auto_cooldown_frames", -1.0)), 9.0),
		"dirty tick after a full-sync refresh should push the new value, not a stale one"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
