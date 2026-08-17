extends SceneTree

const PerkFusionByproductRuntime := preload("res://scripts/characters/perk_fusion_byproduct_runtime.gd")
const PerkFusionReverbVfxState := preload("res://scripts/characters/perk_fusion_reverb_vfx_state.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const RuntimePerkUpdateDriver := preload("res://scripts/core/battle_scene_runtime_perk_update_driver.gd")

var _failures: Array[String] = []


class OwnerFixture:
	extends RefCounted

	var player_pos := Vector2(100.0, 690.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var redraw_requests := 0

	func request_battle_redraw() -> void:
		redraw_requests += 1


class RegistryFixture:
	extends RefCounted

	var runtime_state: Object
	var catalog: Object

	func _init(runtime_value: Object, catalog_value: Object) -> void:
		runtime_state = runtime_value
		catalog = catalog_value

	func get_instance(key: String) -> Object:
		match key:
			"runtime_perk_state":
				return runtime_state
			"runtime_perk_catalog":
				return catalog
		return null

	func get_cached_instance(key: String) -> Object:
		return runtime_state if key == "runtime_perk_state" else null


func _init() -> void:
	_verify_direct_vfx_lifecycle()
	_verify_runtime_activation_refresh_and_expiry()
	_verify_production_driver_redraw_and_cleanup()
	_verify_draw_fanout_contract()
	if _failures.is_empty():
		print("perk_fusion_reverb_vfx_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_direct_vfx_lifecycle() -> void:
	var state := PerkFusionReverbVfxState.new()
	var owner := OwnerFixture.new()
	state.trigger()
	_expect(not state.has_visible_effects(), "Reverb VFX should wait for a real player sample instead of drawing at a fallback position")
	_expect(state.advance(1.0 / 60.0, owner, true), "active Reverb should request its first visible frame")
	var activation: Dictionary = state.get_snapshot()
	_expect(bool(activation.get("reverb_vfx_active", false)), "first owner sample should expose the active Reverb VFX")
	_expect(float(activation.get("reverb_vfx_activation_flash_remaining_sec", 0.0)) > 0.0, "activation should arm the cyan-gold expanding flash")
	_expect(int(activation.get("reverb_vfx_trigger_count", 0)) == 1, "one trigger should publish one visual activation")

	owner.player_pos.x += 28.0
	state.advance(0.08, owner, true)
	var moving: Dictionary = state.get_snapshot()
	_expect(int(moving.get("reverb_vfx_echo_count", 0)) == 1, "moving at least five pixels should spawn one direction-aware echo")
	var echoes: Array = moving.get("reverb_vfx_echoes", []) as Array
	var first_echo: Dictionary = echoes[0] as Dictionary if not echoes.is_empty() else {}
	_expect(float((first_echo.get("direction", Vector2.ZERO) as Vector2).x) > 0.9, "rightward movement should orient the first echo trail to the right")
	var echo_count_before_stationary := echoes.size()
	state.advance(0.01, owner, true)
	_expect(int(state.get_snapshot().get("reverb_vfx_echo_count", -1)) == echo_count_before_stationary, "stationary frames must not create fake movement echoes")

	for _index in range(10):
		owner.player_pos.x += 9.0
		state.advance(0.08, owner, true)
	var capped: Dictionary = state.get_snapshot()
	_expect(int(capped.get("reverb_vfx_echo_count", 0)) > 0, "continuous movement should retain a short visible echo train")
	_expect(int(capped.get("reverb_vfx_echo_count", 99)) <= PerkFusionReverbVfxState.MAX_ECHO_COUNT, "the echo train must remain hard-capped")

	owner.player_pos.x += PerkFusionReverbVfxState.TELEPORT_DISTANCE_PX + 1.0
	state.advance(0.08, owner, true)
	_expect(int(state.get_snapshot().get("reverb_vfx_echo_count", -1)) == 0, "teleport-sized jumps should clear echoes instead of drawing a cross-field trail")
	state.reset_round()
	_expect(not state.has_visible_effects(), "round reset should clear Reverb rings, flash, and echoes")
	_expect(int(state.get_snapshot().get("reverb_vfx_echo_count", -1)) == 0, "round reset should leave no echo payload")


func _verify_runtime_activation_refresh_and_expiry() -> void:
	var runtime := PerkFusionByproductRuntime.new()
	var owner := OwnerFixture.new()
	runtime.on_skill_used([])
	runtime.update(1.0 / 60.0, [], owner)
	_expect(not runtime.has_visible_effects(), "using a Chosik without owning Reverb must not emit its VFX")

	var owned := [PerkFusionByproductRuntime.REVERB_ID]
	runtime.on_skill_used(owned)
	var active_result: Dictionary = runtime.update(1.0 / 60.0, owned, owner)
	_expect(is_equal_approx(runtime.get_player_move_speed_multiplier(), 1.70), "the visual activation must preserve the exact +70% gameplay multiplier")
	_expect(bool(active_result.get("request_redraw", false)), "active Reverb VFX should request the coalesced battle redraw path")
	_expect(runtime.has_visible_effects(), "owned Chosik use should expose Reverb through the shared byproduct draw gate")
	owner.player_pos.x += 24.0
	runtime.update(0.08, owned, owner)
	var before_refresh: Dictionary = runtime.get_snapshot()
	runtime.on_skill_used(owned)
	runtime.update(0.01, owned, owner)
	var after_refresh: Dictionary = runtime.get_snapshot()
	_expect(int(after_refresh.get("reverb_vfx_trigger_count", 0)) == int(before_refresh.get("reverb_vfx_trigger_count", 0)) + 1, "retriggering should replay the activation flash exactly once")
	_expect(is_equal_approx(runtime.get_player_move_speed_multiplier(), 1.70), "retriggering must refresh duration without stacking above 1.70x")
	runtime.update(3.01, owned, owner)
	_expect(is_equal_approx(runtime.get_player_move_speed_multiplier(), 1.0), "Reverb gameplay must expire after the refreshed three-second duration")
	_expect(not runtime.has_visible_effects(), "Reverb VFX must disappear on the same expiry tick as its gameplay bonus")
	_expect(int(runtime.get_snapshot().get("reverb_vfx_echo_count", -1)) == 0, "expiry should tear down every retained echo")


func _verify_production_driver_redraw_and_cleanup() -> void:
	var state := RuntimePerkState.new()
	var catalog := RuntimePerkCatalog.new()
	state.runtime_skill_levels = {"item_luck": 5, "common_bulk_up": 5}
	var record: Dictionary = state.commit_perk_fusion(
		["item_luck", "common_bulk_up"],
		{"outcome": "byproduct", "byproducts": ["reverb"]},
		catalog
	)
	var owner := OwnerFixture.new()
	var registry := RegistryFixture.new(state, catalog)
	state.notify_perk_fusion_skill_used()
	RuntimePerkUpdateDriver.new().update_runtime_perk_resume(owner, registry, 1.0 / 60.0)
	_expect(not record.is_empty(), "production fixture should acquire Reverb through the canonical fusion record")
	_expect(owner.redraw_requests == 1, "the real runtime-perk driver should request one coalesced redraw on the first active tick")
	_expect(state.has_perk_fusion_byproduct_visible_effects(), "the runtime facade should expose Reverb to the real playfield draw fanout")
	owner.player_pos.x += 30.0
	RuntimePerkUpdateDriver.new().update_runtime_perk_resume(owner, registry, 0.08)
	_expect(owner.redraw_requests == 2, "moving Reverb should keep redrawing through the owner request API")
	state.reset_perk_fusion_round_byproducts()
	_expect(not state.has_perk_fusion_byproduct_visible_effects(), "production round cleanup should hide Reverb immediately")


func _verify_draw_fanout_contract() -> void:
	var byproduct_source := FileAccess.get_file_as_string("res://scripts/characters/perk_fusion_byproduct_runtime.gd")
	var playfield_source := FileAccess.get_file_as_string("res://scripts/core/battle_playfield_scene_drawer.gd")
	var driver_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_runtime_perk_update_driver.gd")
	_expect(byproduct_source.contains("PerkFusionReverbVfxState") and byproduct_source.contains("_reverb_vfx_state.draw(canvas, shake_offset)"), "the canonical byproduct owner should construct and draw the focused Reverb VFX state")
	_expect(playfield_source.contains("_draw_perk_fusion_byproduct_effects(canvas, registry, shake_offset)"), "the real playfield draw pass should retain the shared Superior Martial Art VFX fanout")
	_expect(driver_source.contains("byproduct_result.get(\"request_redraw\", false)"), "the always-on gameplay driver should consume Reverb's redraw request")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
