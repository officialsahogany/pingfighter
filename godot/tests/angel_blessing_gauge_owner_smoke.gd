extends SceneTree

const CharacterInfoOverlayOwnerState := preload("res://scripts/hud/character_info_overlay_owner_state.gd")
const CharacterInfoOverlayStatsPresenter := preload("res://scripts/hud/character_info_overlay_stats_presenter.gd")
const MythicItemOwnerSyncer := preload("res://scripts/items/mythic_item_owner_syncer.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const OptimusEnergyState := preload("res://scripts/characters/optimus_energy_state.gd")
const OptimusPlayerController := preload("res://scripts/characters/optimus_player_controller.gd")
const RuntimePerkAngelBlessingGaugeCompositor := preload("res://scripts/characters/runtime_perk_angel_blessing_gauge_compositor.gd")
const RuntimePerkAngelBlessingState := preload("res://scripts/characters/runtime_perk_angel_blessing_state.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

var _failures: Array[String] = []


class FakeGaugeOwner:
	extends RefCounted

	var special_gauge := 250.0
	var special_gauge_max := 500.0


class FakeMythicRuntime:
	extends RefCounted

	var next_unblessed_max := 500.0
	var synced_special_gauge_max := 500.0
	var synced_special_gauge_unblessed_max := 500.0
	var synced_angel_gauge_multiplier := 1.0
	var runtime_perk_state_ref: Object = null

	func get_effective_special_gauge_max(_base_max: float) -> float:
		return next_unblessed_max

	func _safe_owner_get(owner: Object, key: String, fallback: Variant) -> Variant:
		var value: Variant = owner.get(key) if owner != null else null
		return fallback if value == null else value


class FakeOptimusOwner:
	extends RefCounted

	var selected_character_type := "optimus"
	var optimus_energy_initialized := false
	var special_gauge := 0.0
	var special_gauge_max := 650.0


class FakeInputReader:
	extends RefCounted

	func get_snapshot() -> Dictionary:
		return {
			"direction": 0.0,
			"left_pressed": false,
			"right_pressed": false,
			"down_pressed": false,
			"action_pressed": false,
		}


class PassthroughPlayerController:
	extends RefCounted

	func update(
		_delta: float,
		_frame_counter: int,
		player_pos: Vector2,
		player_speed: float,
		config: Dictionary,
		_deps: Dictionary
	) -> Dictionary:
		return {
			"player_pos": player_pos,
			"player_speed": player_speed,
			"special_gauge": float(config.get("special_gauge", 0.0)),
		}


func _init() -> void:
	_verify_pure_cause_policy()
	_verify_owner_writer_and_cache()
	_verify_tab_uses_owner_final_once()
	_verify_full_reset_clears_gauge_caches_and_blessing()
	_verify_optimus_effective_max()

	if _failures.is_empty():
		print("angel_blessing_gauge_owner_smoke: ok")
		quit(0)
	else:
		for failure: String in _failures:
			push_error(failure)
		quit(1)


func _verify_pure_cause_policy() -> void:
	var fuel_only: Dictionary = RuntimePerkAngelBlessingGaugeCompositor.resolve_owner_values(
		500.0,
		540.0,
		1.0,
		1.0,
		333.0
	)
	_expect_close(float(fuel_only.get("next_max", 0.0)), 540.0, "Fuel-only sync should use the raw next max")
	_expect_close(float(fuel_only.get("next_gauge", 0.0)), 360.0, "Fuel-only sync should preserve ratio with legacy rounding")
	_expect(str(fuel_only.get("preserve_mode", "")) == "source_ratio", "Fuel-only sync should report source-ratio mode")

	var angel_only: Dictionary = RuntimePerkAngelBlessingGaugeCompositor.resolve_owner_values(
		500.0,
		500.0,
		1.0,
		1.30,
		250.0
	)
	_expect_close(float(angel_only.get("next_max", 0.0)), 650.0, "Angel-only sync should expand the final max")
	_expect_close(float(angel_only.get("next_gauge", 0.0)), 250.0, "Angel-only sync must preserve absolute current gauge")
	_expect(str(angel_only.get("preserve_mode", "")) == "angel_absolute", "Angel-only sync should report absolute mode")

	var angel_clamp: Dictionary = RuntimePerkAngelBlessingGaugeCompositor.resolve_owner_values(
		500.0,
		500.0,
		1.30,
		1.0,
		620.0
	)
	_expect_close(float(angel_clamp.get("next_gauge", 0.0)), 500.0, "Angel removal should only clamp values above the new max")

	var simultaneous: Dictionary = RuntimePerkAngelBlessingGaugeCompositor.resolve_owner_values(
		500.0,
		540.0,
		1.0,
		1.30,
		250.0
	)
	_expect_close(float(simultaneous.get("next_max", 0.0)), 702.0, "simultaneous sync should compose raw max then Angel")
	_expect_close(float(simultaneous.get("next_gauge", 0.0)), 270.0, "simultaneous sync should scale current gauge for Fuel only")
	_expect(str(simultaneous.get("preserve_mode", "")) == "source_ratio_then_angel_absolute", "simultaneous sync should expose its ordered policy")

	var repeated: Dictionary = RuntimePerkAngelBlessingGaugeCompositor.resolve_owner_values(
		540.0,
		540.0,
		1.30,
		1.30,
		270.0
	)
	_expect_close(float(repeated.get("next_gauge", 0.0)), 270.0, "identical sync should be idempotent")


func _verify_owner_writer_and_cache() -> void:
	var runtime_state: Object = RuntimePerkState.new()
	var runtime := FakeMythicRuntime.new()
	runtime.runtime_perk_state_ref = runtime_state
	var owner := FakeGaugeOwner.new()
	var syncer: Object = MythicItemOwnerSyncer.new()
	var constants := {"base_special_gauge_max": 500.0}

	runtime.next_unblessed_max = 540.0
	syncer.sync_fuel_pouch_gauge_max(runtime, owner, constants)
	_expect_close(owner.special_gauge_max, 540.0, "single owner writer should apply Fuel raw max")
	_expect_close(owner.special_gauge, 270.0, "single owner writer should keep Fuel ratio")

	runtime_state.roll_angel_blessing_for_stage(
		1,
		runtime_state.get_angel_blessing_state().get_all_buff_ids(),
		1,
		[RuntimePerkAngelBlessingState.BUFF_GAUGE_MAX]
	)
	syncer.sync_fuel_pouch_gauge_max(runtime, owner, constants)
	_expect_close(owner.special_gauge_max, 702.0, "single owner writer should apply Angel after Fuel")
	_expect_close(owner.special_gauge, 270.0, "Angel activation must not fill current gauge")
	_expect_close(runtime.synced_special_gauge_unblessed_max, 540.0, "writer should cache raw max separately")
	_expect_close(runtime.synced_angel_gauge_multiplier, 1.30, "writer should cache Angel multiplier")

	syncer.sync_fuel_pouch_gauge_max(runtime, owner, constants)
	_expect_close(owner.special_gauge, 270.0, "repeated owner sync should not drift gauge")

	runtime.runtime_perk_state_ref = null
	syncer.sync_fuel_pouch_gauge_max(runtime, owner, constants)
	_expect_close(owner.special_gauge_max, 702.0, "temporary missing perk ref should retain cached Angel max")
	_expect_close(owner.special_gauge, 270.0, "temporary missing perk ref should retain current gauge")

	runtime.runtime_perk_state_ref = runtime_state
	owner.special_gauge = 620.0
	runtime_state.roll_angel_blessing_for_stage(
		2,
		runtime_state.get_angel_blessing_state().get_all_buff_ids(),
		1,
		[RuntimePerkAngelBlessingState.BUFF_MOVE_SPEED]
	)
	syncer.sync_fuel_pouch_gauge_max(runtime, owner, constants)
	_expect_close(owner.special_gauge_max, 540.0, "next stage without gauge blessing should remove only Angel max")
	_expect_close(owner.special_gauge, 540.0, "Angel removal should preserve absolute current gauge then clamp")


func _verify_tab_uses_owner_final_once() -> void:
	var runtime_state: Object = RuntimePerkState.new()
	runtime_state.roll_angel_blessing_for_stage(
		1,
		runtime_state.get_angel_blessing_state().get_all_buff_ids(),
		1,
		[RuntimePerkAngelBlessingState.BUFF_GAUGE_MAX]
	)
	var displayed_max: float = CharacterInfoOverlayStatsPresenter.effective_max_gauge(
		650.0,
		[runtime_state],
		Callable(CharacterInfoOverlayOwnerState, "apply_stat_chain")
	)
	_expect_close(displayed_max, 650.0, "TAB should display the already-composed owner max exactly once")
	_expect(not runtime_state.has_method("get_special_gauge_max"), "runtime perk state must not expose a generic double-apply gauge getter")


func _verify_full_reset_clears_gauge_caches_and_blessing() -> void:
	var mythic_runtime: Object = MythicItemRuntime.new()
	mythic_runtime.synced_special_gauge_max = 702.0
	mythic_runtime.synced_special_gauge_unblessed_max = 540.0
	mythic_runtime.synced_angel_gauge_multiplier = 1.30
	mythic_runtime.reset()
	_expect_close(mythic_runtime.synced_special_gauge_max, 500.0, "mythic reset should clear final gauge cache")
	_expect_close(mythic_runtime.synced_special_gauge_unblessed_max, 500.0, "mythic reset should clear raw gauge cache")
	_expect_close(mythic_runtime.synced_angel_gauge_multiplier, 1.0, "mythic reset should clear Angel gauge cache")

	var runtime_state: Object = RuntimePerkState.new()
	runtime_state.roll_angel_blessing_for_stage(
		1,
		runtime_state.get_angel_blessing_state().get_all_buff_ids(),
		1,
		[RuntimePerkAngelBlessingState.BUFF_GAUGE_MAX]
	)
	runtime_state.reset()
	var snapshot: Dictionary = runtime_state.get_angel_blessing_snapshot()
	_expect((snapshot.get("active_buff_ids", []) as Array).is_empty(), "runtime perk full reset should clear active Angel buffs")
	_expect((snapshot.get("triggered_stages", []) as Array).is_empty(), "runtime perk full reset should clear Angel stage history")


func _verify_optimus_effective_max() -> void:
	var owner := FakeOptimusOwner.new()
	var energy_state: Object = OptimusEnergyState.new()
	var prepared: Dictionary = energy_state.prepare_owner_for_optimus(owner)
	_expect_close(owner.special_gauge_max, 650.0, "Optimus prepare should preserve effective max")
	_expect_close(owner.special_gauge, 650.0, "Optimus prepare should fill to effective max")
	_expect_close(float(prepared.get("optimus_energy_ratio", 0.0)), 1.0, "Optimus prepare should use effective max as ratio denominator")

	var half: Dictionary = energy_state.build_scale_snapshot(325.0, 650.0)
	_expect_close(float(half.get("optimus_energy_ratio", 0.0)), 0.5, "Optimus snapshot should use effective max denominator")
	var movement: Dictionary = energy_state.apply_movement_config({"paddle_speed": 4.0}, 325.0, 650.0)
	_expect_close(float(movement.get("paddle_speed", 0.0)), 2.0, "Optimus movement penalty should use effective max denominator")

	var drained: Dictionary = energy_state.update_energy(10.0, 650.0, false, 650.0)
	_expect_close(float(drained.get("special_gauge", 0.0)), 580.0, "Optimus drain should start from effective max")
	_expect_close(float(drained.get("special_gauge_max", 0.0)), 650.0, "Optimus drain snapshot should preserve effective max")

	energy_state.reset()
	energy_state.update_manual_charge(0.25, true, 640.0, false, 650.0)
	var charged: Dictionary = energy_state.update_manual_charge(0.25, true, 640.0, false, 650.0)
	_expect_close(float(charged.get("special_gauge", 0.0)), 650.0, "Optimus manual charge should cap at effective max")
	_expect_close(float(charged.get("special_gauge_max", 0.0)), 650.0, "Optimus manual snapshot should preserve effective max")

	var controller: Object = OptimusPlayerController.new()
	controller.shared_controller = PassthroughPlayerController.new()
	var controller_result: Dictionary = controller.update(
		1.0,
		1,
		Vector2.ZERO,
		4.0,
		{
			"special_gauge": 650.0,
			"gauge_max": 650.0,
			"paddle_speed": 4.0,
			"paddle_max_speed": 4.0,
			"paddle_accel": 0.5,
			"paddle_decel": 0.25,
			"paddle_turn_decel": 0.2,
		},
		{
			"optimus_energy_state": OptimusEnergyState.new(),
			"input_reader": FakeInputReader.new(),
		}
	)
	_expect_close(float(controller_result.get("special_gauge", 0.0)), 643.0, "Optimus controller should forward effective max to drain")
	_expect_close(float(controller_result.get("special_gauge_max", 0.0)), 650.0, "Optimus controller should keep effective max in result")


func _expect_close(actual: float, expected: float, message: String) -> void:
	if abs(actual - expected) > 0.001:
		_failures.append("%s (actual %.4f, expected %.4f)" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
