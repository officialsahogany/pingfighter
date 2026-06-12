extends SceneTree

# Diagnostic-only microbench for the F4 sync_after cost split (NOT a
# pass/fail gate - absolute numbers vary per machine; use the RATIOS).
# Measures sync_transient_owner_state in isolation on clean ticks (no value
# changes), dirty ticks (one cooldown key counting down), and the
# value/context build alone, to attribute the per-tick floor between value
# computation, comparison, and owner traffic. Self-contained: builds its own
# runtime/owner, no save data, log, or session state involved.
# Run manually from the repo:
#   godot --headless --path godot -s res://tools/mythic_sync_microbench.gd
# 2026-06-13 reference ratios (unequipped runtime): clean 225.6us, dirty
# 274.4us (write path +49us), value build 183.1us (81% of clean), context
# builds alone 117.9us (52%) - the floor is value-getter fan-out, not owner
# traffic. Context-gating / cadence decisions trace back to this split
# (docs/mythic_transient_sync_slimming_design.md).

const BattleSceneState := preload("res://scripts/core/battle_scene_state.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")


class PlainOwner:
	extends RefCounted

	var scene_state: Object = BattleSceneState.new()

	func _init() -> void:
		scene_state.reset()

	func _get(property: StringName) -> Variant:
		var key := str(property)
		if scene_state.has_key(key):
			return scene_state.get_value(key)
		return null

	func _set(property: StringName, value: Variant) -> bool:
		var key := str(property)
		if not scene_state.has_key(key):
			return false
		scene_state.set_value(key, value)
		return true


func _init() -> void:
	var runtime: Object = MythicItemRuntime.new()
	var owner := PlainOwner.new()
	runtime.reset()
	var syncer: Object = runtime.owner_syncer
	var iterations := 5000

	syncer.sync_transient_owner_state(runtime, owner)

	var start := Time.get_ticks_usec()
	for _i in range(iterations):
		syncer.sync_transient_owner_state(runtime, owner)
	var clean_us := float(Time.get_ticks_usec() - start) / float(iterations)

	start = Time.get_ticks_usec()
	for i in range(iterations):
		runtime.smartphone_cooldown_frames = 100000.0 - float(i)
		syncer.sync_transient_owner_state(runtime, owner)
	var dirty_us := float(Time.get_ticks_usec() - start) / float(iterations)

	start = Time.get_ticks_usec()
	for _i in range(iterations):
		var contexts: Dictionary = syncer._build_transient_contexts(runtime)
		var _sv: Dictionary = syncer._build_transient_state_values(runtime, contexts)
		var _ov: Dictionary = syncer._build_transient_owner_values(runtime, contexts)
	var build_us := float(Time.get_ticks_usec() - start) / float(iterations)

	start = Time.get_ticks_usec()
	for _i in range(iterations):
		var _c: Dictionary = syncer._build_transient_contexts(runtime)
	var contexts_us := float(Time.get_ticks_usec() - start) / float(iterations)

	print("mythic_sync_microbench: clean=%.1fus dirty=%.1fus value_build=%.1fus contexts_only=%.1fus" % [
		clean_us, dirty_us, build_us, contexts_us,
	])
	quit(0)
