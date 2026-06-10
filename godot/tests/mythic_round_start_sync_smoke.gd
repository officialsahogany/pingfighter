extends SceneTree

# Seals the F1 round-start sync slim-down (frame-budget work, 2026-06-10):
# `mythic_item_runtime.on_round_start` used to run the full ~250-key
# `_sync_owner` on EVERY round restart (twice when adversity armor was not
# equipped), costing 3.0~3.5ms on the round-resume frame — a guaranteed frame
# doubling at 72 FPS. Round start mutates nothing beyond the adversity-armor
# branch, so the trailing sync is now the change-gated transient pass and the
# unequipped adversity branch only full-syncs when it actually cleared
# owner-visible state.
#
# Contract sealed here:
# 1. Equipped armor with a pending shield still activates AND propagates
#    through the schema-real channel (`mythic_item_state`) on round start.
# 2. Stale unequipped armor state is cleared AND the cleared state is synced.
# 3. A clean round start performs only a handful of owner writes — NOT the
#    ~250-write full sync (the perf regression this slice removes).
# 4. Transient runtime drift (e.g. smartphone cooldown) still reaches the
#    owner through the round-start drift net.

const BattleSceneState := preload("res://scripts/core/battle_scene_state.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")


# Mirrors battle_scene_shell: set()/get() route through battle_scene_state,
# which silently no-ops writes to keys missing from DEFAULT_VALUES. Counts
# every set ATTEMPT so the test can distinguish a full sync (~250 attempts)
# from the slim round-start path regardless of schema acceptance.
class SchemaGatedCountingOwner:
	extends RefCounted

	var scene_state: Object = BattleSceneState.new()
	var set_attempts: int = 0

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
	seed(7)
	_verify_equipped_pending_round_start_propagates()
	_verify_stale_unequipped_state_syncs_cleared()
	_verify_clean_round_start_skips_full_sync()
	_verify_transient_drift_reaches_owner()

	if _failures.is_empty():
		print("mythic_round_start_sync_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_equipped_pending_round_start_propagates() -> void:
	var runtime: Object = MythicItemRuntime.new()
	var owner := SchemaGatedCountingOwner.new()
	var registry := NullRegistry.new()
	_expect(runtime.equip_item("adversity_armor", owner, registry, {
		"trigger_chance_pct": 100.0,
		"invincible_duration_sec": 8.0,
	}, false), "adversity armor should equip")
	_expect(runtime.try_queue_adversity_armor_after_loss({"owner": owner, "registry": registry}), "100% roll should queue the next-round shield")
	runtime.on_round_start(owner, registry)
	_expect(not runtime.adversity_armor_pending_invincible, "round start should consume pending shield")
	_expect(runtime.is_adversity_armor_invincible(), "round start should activate invincibility")
	var state: Dictionary = owner.get_mythic_state()
	_expect(bool(state.get("adversity_armor_invincible", false)), "schema owner mythic_item_state should expose active invincibility after round start")
	_expect(not bool(state.get("adversity_armor_pending_invincible", true)), "schema owner mythic_item_state should expose consumed pending flag after round start")


func _verify_stale_unequipped_state_syncs_cleared() -> void:
	var runtime: Object = MythicItemRuntime.new()
	var owner := SchemaGatedCountingOwner.new()
	var registry := NullRegistry.new()
	# Stale armor state without the item equipped (e.g. unequipped mid-round).
	runtime.is_adversity_armor_equipped()
	runtime.adversity_armor_pending_invincible = true
	runtime.adversity_armor_invincible_timer_frames = 120.0
	runtime.adversity_armor_invincible_total_frames = 120.0
	runtime.owner_syncer.sync_transient_owner_state(runtime, owner)
	_expect(bool(owner.get_mythic_state().get("adversity_armor_pending_invincible", false)), "priming sync should expose the stale pending flag")

	owner.set_attempts = 0
	runtime.on_round_start(owner, registry)
	_expect(not runtime.adversity_armor_pending_invincible, "round start should clear stale unequipped pending flag")
	_expect(runtime.adversity_armor_invincible_timer_frames <= 0.0, "round start should clear stale unequipped invincibility timer")
	var state: Dictionary = owner.get_mythic_state()
	_expect(not bool(state.get("adversity_armor_pending_invincible", false)), "cleared pending flag should reach the schema owner")
	_expect(not bool(state.get("adversity_armor_invincible", false)), "cleared invincibility should reach the schema owner")
	_expect(owner.set_attempts > 50, "clearing stale visible state should still run the full owner sync (got %d attempts)" % owner.set_attempts)


func _verify_clean_round_start_skips_full_sync() -> void:
	# Case A: no mythic items at all — the common early-game round restart.
	var runtime: Object = MythicItemRuntime.new()
	var owner := SchemaGatedCountingOwner.new()
	var registry := NullRegistry.new()
	runtime.on_round_start(owner, registry)
	owner.set_attempts = 0
	runtime.on_round_start(owner, registry)
	_expect(
		owner.set_attempts < 30,
		"clean unequipped round start must not run the ~250-write full sync (got %d attempts)" % owner.set_attempts
	)

	# Case B: armor equipped but no pending shield — the common equipped case.
	var equipped_runtime: Object = MythicItemRuntime.new()
	var equipped_owner := SchemaGatedCountingOwner.new()
	_expect(equipped_runtime.equip_item("adversity_armor", equipped_owner, registry, {
		"trigger_chance_pct": 100.0,
		"invincible_duration_sec": 8.0,
	}, false), "adversity armor should equip for the no-pending case")
	equipped_runtime.on_round_start(equipped_owner, registry)
	equipped_owner.set_attempts = 0
	equipped_runtime.on_round_start(equipped_owner, registry)
	_expect(
		equipped_owner.set_attempts < 30,
		"equipped no-pending round start must not run the ~250-write full sync (got %d attempts)" % equipped_owner.set_attempts
	)


func _verify_transient_drift_reaches_owner() -> void:
	var runtime: Object = MythicItemRuntime.new()
	var owner := SchemaGatedCountingOwner.new()
	var registry := NullRegistry.new()
	runtime.on_round_start(owner, registry)
	runtime.smartphone_cooldown_frames = 30.0
	runtime.on_round_start(owner, registry)
	_expect(
		is_equal_approx(float(owner.get_mythic_state().get("smartphone_auto_cooldown_frames", 0.0)), 30.0),
		"round-start drift net should sync transient runtime values into mythic_item_state"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
