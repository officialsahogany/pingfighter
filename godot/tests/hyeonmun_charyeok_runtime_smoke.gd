extends SceneTree

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkHyeonmunCharyeokState := preload("res://scripts/characters/runtime_perk_hyeonmun_charyeok_state.gd")
const RuntimePerkHyeonmunCharyeokRenderer := preload("res://scripts/characters/runtime_perk_hyeonmun_charyeok_renderer.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

var _failures: Array[String] = []


class FakeTimerStack:
	extends RefCounted

	var claims: Array[String] = []

	func claim(key: String, active: bool) -> int:
		if not active:
			return -1
		claims.append(key)
		return claims.size() - 1


class FakeCrownRuntime:
	extends RefCounted

	func get_transcendent_crown_skill_bonus() -> int:
		return 2


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(source: Dictionary = {}) -> void:
		instances = source

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	_verify_catalog_and_curve()
	_verify_probability_boundary()
	_verify_runtime_activation_refresh_and_expiry()
	_verify_crown_composition_and_round_reset()
	_verify_timer_stack_contract()
	_verify_production_wiring()
	PerkConversionFlags.debug_set_enabled(false)
	if _failures.is_empty():
		print("hyeonmun_charyeok_runtime_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_catalog_and_curve() -> void:
	var data: Dictionary = RuntimePerkCatalog.new().get_perk_data("sage_ring")
	_expect(str(data.get("name", "")) == "현문차력", "compatibility id sage_ring should keep the Hyeonmun Charyeok player-facing name")
	_expect(int(data.get("max_level", 0)) == 5, "Hyeonmun Charyeok should have five invested levels")
	var descriptions: Dictionary = data.get("descriptions", {})
	var expected_bonuses := [1, 1, 2, 2, 3]
	var expected_durations := [6.0, 7.0, 8.0, 9.0, 10.0]
	for index in range(5):
		var level := index + 1
		_expect_close(RuntimePerkHyeonmunCharyeokState.resolve_trigger_chance_pct(level), 5.0, "fixed trigger chance Lv.%d" % level)
		_expect(RuntimePerkHyeonmunCharyeokState.resolve_level_bonus(level) == expected_bonuses[index], "level bonus tier Lv.%d" % level)
		_expect_close(RuntimePerkHyeonmunCharyeokState.resolve_duration_sec(level), expected_durations[index], "duration Lv.%d" % level)
		var copy := str(descriptions.get(level, ""))
		_expect(copy.find("5%") >= 0, "catalog copy should show fixed 5%% at Lv.%d" % level)
		_expect(copy.find("+%d" % expected_bonuses[index]) >= 0, "catalog copy should show the level bonus at Lv.%d" % level)
		_expect(copy.find("%d초" % int(expected_durations[index])) >= 0, "catalog copy should show duration at Lv.%d" % level)


func _verify_probability_boundary() -> void:
	var miss_state := RuntimePerkHyeonmunCharyeokState.new()
	var miss: Dictionary = miss_state.try_proc(1, 0.05)
	_expect(not bool(miss.get("activated", false)), "a roll exactly at 5% should fail the [0, 5%) proc window")
	var hit_state := RuntimePerkHyeonmunCharyeokState.new()
	var hit: Dictionary = hit_state.try_proc(1, 0.049999)
	_expect(bool(hit.get("activated", false)), "a roll just below 5% should proc")


func _verify_runtime_activation_refresh_and_expiry() -> void:
	var state := RuntimePerkState.new()
	state.runtime_skill_levels["sage_ring"] = 1
	var first: Dictionary = state.try_proc_hyeonmun_charyeok({"hyeonmun_charyeok_roll_unit": 0.0})
	_expect(bool(first.get("activated", false)), "forced Lv.1 hit should activate Hyeonmun")
	_expect(state.get_hyeonmun_charyeok_level_bonus() == 1, "Lv.1 activation should grant +1")
	_expect(state.get_item_perk_level_bonus() == 1, "activation should immediately feed the canonical effective-level source")
	_expect(state.get_runtime_skill_level("sage_ring") == 1, "Hyeonmun should remain self-exempt from free effective levels")
	_expect(state.update_hyeonmun_charyeok(2.0), "active timer should request redraw while ticking")
	_expect_close(float(state.get_hyeonmun_charyeok_snapshot().get("remaining_sec", 0.0)), 4.0, "Lv.1 remaining duration after two seconds")

	state.runtime_skill_levels["sage_ring"] = 5
	var refresh: Dictionary = state.try_proc_hyeonmun_charyeok({"hyeonmun_charyeok_roll_unit": 0.0})
	_expect(bool(refresh.get("refreshed", false)), "re-proc while active should report a refresh")
	_expect(state.get_hyeonmun_charyeok_level_bonus() == 3, "refresh should adopt the current Lv.5 +3 tier")
	_expect(state.get_item_perk_level_bonus() == 3, "refresh should replace +1 with +3 rather than stack to +4")
	_expect_close(float(state.get_hyeonmun_charyeok_snapshot().get("remaining_sec", 0.0)), 10.0, "refresh should refill the Lv.5 duration")
	state.update_hyeonmun_charyeok(9.5)
	_expect(state.is_hyeonmun_charyeok_active(), "buff should remain active before the final half-second")
	state.update_hyeonmun_charyeok(0.5)
	_expect(not state.is_hyeonmun_charyeok_active(), "buff should expire at its authored duration")
	_expect(state.get_item_perk_level_bonus() == 0, "expiry should remove the temporary canonical bonus")
	_expect(state.get_hyeonmun_charyeok_snapshot().is_empty() == false, "snapshot surface should remain available while inactive")
	_expect(state.get_snapshot().has("hyeonmun_charyeok"), "runtime perk snapshot should expose Hyeonmun timer state")


func _verify_crown_composition_and_round_reset() -> void:
	var state := RuntimePerkState.new()
	state.runtime_skill_levels["sage_ring"] = 3
	var crown_runtime := FakeCrownRuntime.new()
	var registry := FakeRegistry.new({"mythic_item_runtime": crown_runtime})
	var proc: Dictionary = state.try_proc_hyeonmun_charyeok(
		{"hyeonmun_charyeok_roll_unit": 0.0},
		{"mythic_item_runtime": crown_runtime, "registry": registry}
	)
	_expect(bool(proc.get("activated", false)), "Lv.3 crown fixture should proc")
	_expect(state.get_item_perk_level_bonus() == 4, "Crown +2 and active Hyeonmun Lv.3 +2 should compose to +4")
	_expect(state.reset_hyeonmun_charyeok_round(registry), "round reset should clear an active Hyeonmun buff")
	_expect(not state.is_hyeonmun_charyeok_active(), "round reset should end the buff")
	_expect(state.get_item_perk_level_bonus() == 2, "round reset should remove Hyeonmun while preserving Crown +2")
	_expect(not state.reset_hyeonmun_charyeok_round(registry), "repeated round reset should be a no-op")

	PerkConversionFlags.debug_set_enabled(false)
	var disabled: Dictionary = state.try_proc_hyeonmun_charyeok({"hyeonmun_charyeok_roll_unit": 0.0})
	_expect(not bool(disabled.get("activated", false)), "flag-OFF legacy Sage Ring must not arm the converted Hyeonmun proc")
	PerkConversionFlags.debug_set_enabled(true)


func _verify_timer_stack_contract() -> void:
	var renderer := RuntimePerkHyeonmunCharyeokRenderer.new()
	var stack := FakeTimerStack.new()
	_expect(renderer.claim_timer_stack_index(stack) == 0, "a lone Hyeonmun bar should claim bottom stack index 0")
	_expect(stack.claims == [RuntimePerkHyeonmunCharyeokRenderer.TIMER_STACK_KEY], "timer should use its stable shared-stack key")
	var bottom := renderer.get_timer_bar_position(0)
	var upper := renderer.get_timer_bar_position(1)
	_expect_close(bottom.y - upper.y, RuntimePerkHyeonmunCharyeokRenderer.TIMER_STACK_SPACING, "additional timer bars should stack upward")
	_expect(RuntimePerkHyeonmunCharyeokRenderer.ICON_TEXTURE != null, "timer gauge should preload the accepted Hyeonmun icon")


func _verify_production_wiring() -> void:
	var paddle_source := FileAccess.get_file_as_string("res://scripts/ball/paddle_bounce_post_hit_handler.gd")
	var update_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_runtime_perk_update_driver.gd")
	var cleanup_source := FileAccess.get_file_as_string("res://scripts/ball/ball_round_actor_cleanup.gd")
	var drawer_source := FileAccess.get_file_as_string("res://scripts/core/battle_playfield_scene_drawer.gd")
	_expect(paddle_source.find("try_proc_hyeonmun_charyeok(context, deps)") >= 0, "real player paddle-hit fanout should attempt the 5% proc")
	_expect(update_source.find("update_hyeonmun_charyeok(delta, owner, registry)") >= 0, "battle runtime-perk driver should tick the gameplay-time duration")
	_expect(update_source.find("_request_battle_redraw(owner)") >= 0, "physics timer should use the coalesced battle redraw path")
	_expect(cleanup_source.find("reset_hyeonmun_charyeok_round") >= 0, "round cleanup should clear the temporary buff")
	_expect(drawer_source.find("draw_runtime_perk_timer_effects") >= 0, "playfield draw fanout should include the shared timer bar")


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(absf(actual - expected) <= 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
