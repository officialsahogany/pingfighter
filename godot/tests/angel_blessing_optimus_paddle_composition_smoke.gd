extends SceneTree

const ActiveItemEffectUpdateDriver := preload("res://scripts/items/active_item_effect_update_driver.gd")
const ActiveItemPaddleSync := preload("res://scripts/items/active_item_paddle_sync.gd")
const BattleSceneApi := preload("res://scripts/core/battle_scene_api.gd")
const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")
const OptimusEnergyState := preload("res://scripts/characters/optimus_energy_state.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")
const RuntimePerkAngelBlessingState := preload("res://scripts/characters/runtime_perk_angel_blessing_state.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

const FIELD_CENTER_X := 380.0
const FIELD_BOTTOM_Y := 750.0
const PLAYER_REFERENCE_WIDTH := 155.0
const ANGEL_AND_COMMON_BULK_SCALE := 1.30 * 1.06


class FakeOwner:
	extends RefCounted

	var selected_character_type := "optimus"
	var special_gauge := 650.0
	var special_gauge_max := 650.0
	var optimus_energy_initialized := true
	var player_pos := Vector2(232.0, 603.0)
	var player_paddle_width := 296.0
	var player_paddle_height := 147.0
	var player_paddle_scale := 296.0 / PLAYER_REFERENCE_WIDTH
	var runtime_paddle_base_width := 296.0
	var runtime_paddle_base_height := 147.0
	var runtime_paddle_scale := ANGEL_AND_COMMON_BULK_SCALE
	var bulkup_paddle_scale := 1.10


class FakeActiveItemTarget:
	extends RefCounted

	var long_boost_active := false
	var long_boost_timer_frames := 0.0
	var long_boost_scale := 1.0
	var milk_bottle_active := false
	var milk_bottle_scale := 1.0
	var strange_vial_active := false
	var strange_vial_timer_frames := 0.0
	var strange_vial_scale := 1.0


class FakeMythicPaddleRuntime:
	extends RefCounted

	var paddle_scale := 1.10

	func get_player_paddle_scale() -> float:
		return paddle_scale


class CountingPaddleSync:
	extends ActiveItemPaddleSync

	var sync_count := 0

	func sync_owner_state(
		owner: Object,
		active_item_scale: float,
		warp_gate_state: Object = null,
		mythic_item_runtime: Object = null
	) -> void:
		sync_count += 1
		super.sync_owner_state(owner, active_item_scale, warp_gate_state, mythic_item_runtime)


class FakeActiveItemRuntime:
	extends RefCounted

	var paddle_scale := 1.20

	func get_player_paddle_scale() -> float:
		return paddle_scale


class DynamicOwner:
	extends RefCounted

	var data: Dictionary = {}

	func _get(property: StringName) -> Variant:
		return data.get(str(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		data[str(property)] = value
		return true


class ApiRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


var _failures: Array[String] = []


func _init() -> void:
	PerkConversionFlags.debug_set_enabled(false)
	_verify_optimus_runtime_snapshots_publish_base_only()
	_verify_effective_max_midpoint_composition()
	_verify_idle_gate_recomposes_changed_inputs()
	_verify_character_switch_recomposes_immediately()

	if _failures.is_empty():
		print("angel_blessing_optimus_paddle_composition_smoke: ok")
		quit(0)
		return

	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_optimus_runtime_snapshots_publish_base_only() -> void:
	var energy_state: Object = OptimusEnergyState.new()
	var full_snapshot: Dictionary = energy_state.build_scale_snapshot(650.0, 650.0)
	_expect_close(
		float(full_snapshot.get("runtime_paddle_base_width", 0.0)),
		296.0,
		"full Optimus snapshot should publish the raw runtime base width"
	)
	_expect_close(
		float(full_snapshot.get("runtime_paddle_base_height", 0.0)),
		147.0,
		"full Optimus snapshot should publish the raw runtime base height"
	)
	_expect(
		full_snapshot.has("player_paddle_width")
		and full_snapshot.has("player_paddle_height")
		and full_snapshot.has("player_paddle_scale"),
		"bootstrap/debug scale snapshot should keep its final raw-size compatibility fields"
	)

	var runtime_base_snapshot: Dictionary = energy_state.build_runtime_base_snapshot(650.0, 650.0)
	_expect_close(
		float(runtime_base_snapshot.get("runtime_paddle_base_width", 0.0)),
		296.0,
		"runtime-base snapshot should publish the raw Optimus width"
	)
	_expect_close(
		float(runtime_base_snapshot.get("runtime_paddle_base_height", 0.0)),
		147.0,
		"runtime-base snapshot should publish the raw Optimus height"
	)
	_expect_base_only_snapshot(runtime_base_snapshot, "Optimus runtime-base snapshot")
	var junior_base_snapshot: Dictionary = energy_state.build_runtime_base_snapshot(650.0, 650.0, 1.5)
	_expect_close(float(junior_base_snapshot.get("runtime_paddle_base_width", 0.0)), 444.0, "Junior Optimus runtime-base width")
	_expect_close(float(junior_base_snapshot.get("runtime_paddle_base_height", 0.0)), 220.5, "Junior Optimus runtime-base height")
	_expect_base_only_snapshot(junior_base_snapshot, "Junior Optimus runtime-base snapshot")

	var owner := FakeOwner.new()
	var prepared_snapshot: Dictionary = energy_state.prepare_owner_runtime_base_for_optimus(owner)
	_expect_base_only_snapshot(prepared_snapshot, "Optimus per-physics prepare snapshot")

	var drained_snapshot: Dictionary = energy_state.update_energy(1.0, 650.0, false, 650.0)
	_expect_close(
		float(drained_snapshot.get("special_gauge", 0.0)),
		643.0,
		"Optimus energy update should still publish the drained gauge"
	)
	_expect(
		float(drained_snapshot.get("runtime_paddle_base_width", 0.0)) < 296.0,
		"drained Optimus snapshot should shrink the raw runtime base width"
	)
	_expect_base_only_snapshot(drained_snapshot, "per-tick Optimus energy snapshot")

	var manual_snapshot: Dictionary = energy_state.update_manual_charge(
		0.0,
		false,
		float(drained_snapshot.get("special_gauge", 643.0)),
		false,
		650.0
	)
	_expect_base_only_snapshot(manual_snapshot, "per-tick Optimus manual-charge snapshot")


func _verify_effective_max_midpoint_composition() -> void:
	var owner := FakeOwner.new()
	var runtime_perk_state := RuntimePerkState.new()
	runtime_perk_state.runtime_skill_levels = {"common_bulk_up": 1}
	runtime_perk_state.roll_angel_blessing_for_stage(
		1,
		runtime_perk_state.get_angel_blessing_state().get_all_buff_ids(),
		1,
		[RuntimePerkAngelBlessingState.BUFF_PADDLE_SIZE]
	)
	owner.runtime_paddle_scale = runtime_perk_state.get_player_paddle_size_multiplier()
	_expect_close(owner.runtime_paddle_scale, ANGEL_AND_COMMON_BULK_SCALE, "real Bulk Up Lv.1 plus Angel paddle scale")
	var midpoint_snapshot: Dictionary = OptimusEnergyState.new().build_runtime_base_snapshot(325.0, 650.0)
	owner.runtime_paddle_base_width = float(midpoint_snapshot.get("runtime_paddle_base_width", 0.0))
	owner.runtime_paddle_base_height = float(midpoint_snapshot.get("runtime_paddle_base_height", 0.0))
	var target := FakeActiveItemTarget.new()
	target.long_boost_scale = 1.20
	var mythic_runtime := FakeMythicPaddleRuntime.new()
	ActiveItemPaddleSync.new().sync_owner_state(owner, target.long_boost_scale, null, mythic_runtime)

	_expect_close(owner.runtime_paddle_base_width, 268.0, "325/650 Optimus raw midpoint width")
	_expect_close(owner.runtime_paddle_base_height, 133.094594594595, "325/650 Optimus raw midpoint height")
	_expect_close(owner.player_paddle_width, 487.48128, "325/650 fully composed midpoint width")
	_expect_close(owner.player_paddle_height, 242.093743783784, "325/650 fully composed midpoint height")
	_expect_composed_owner(owner, target, mythic_runtime, "325/650 exact composition")


func _verify_idle_gate_recomposes_changed_inputs() -> void:
	for change_kind: String in ["base", "runtime", "active", "mythic"]:
		var owner := FakeOwner.new()
		var target := FakeActiveItemTarget.new()
		var mythic_runtime := FakeMythicPaddleRuntime.new()
		var paddle_sync := CountingPaddleSync.new()
		var driver := ActiveItemEffectUpdateDriver.new()
		driver.configure({"paddle_sync": paddle_sync})

		driver._sync_paddle_owner_state(target, owner, null, mythic_runtime)
		_expect(
			paddle_sync.sync_count == 1,
			"%s fixture should prime the idle paddle sync exactly once" % change_kind
		)
		_expect_composed_owner(owner, target, mythic_runtime, "%s initial composition" % change_kind)

		var stable_size := Vector2(owner.player_paddle_width, owner.player_paddle_height)
		var stable_pos: Vector2 = owner.player_pos
		driver._sync_paddle_owner_state(target, owner, null, mythic_runtime)
		_expect(
			paddle_sync.sync_count == 1,
			"%s unchanged idle inputs should stay gated" % change_kind
		)
		_expect(
			Vector2(owner.player_paddle_width, owner.player_paddle_height).is_equal_approx(stable_size)
			and owner.player_pos.is_equal_approx(stable_pos),
			"%s unchanged idle inputs should be idempotent" % change_kind
		)

		match change_kind:
			"base":
				owner.runtime_paddle_base_width = 268.0
				owner.runtime_paddle_base_height = 133.094594594595
			"runtime":
				owner.runtime_paddle_scale = 1.22
			"active":
				target.long_boost_scale = 1.20
			"mythic":
				mythic_runtime.paddle_scale = 1.25
				owner.bulkup_paddle_scale = 1.25

		driver._sync_paddle_owner_state(target, owner, null, mythic_runtime)
		_expect(
			paddle_sync.sync_count == 2,
			"%s change should bypass the idle gate and recompose immediately" % change_kind
		)
		_expect_composed_owner(owner, target, mythic_runtime, "%s changed composition" % change_kind)
		if change_kind == "active":
			var once_composed_size := Vector2(owner.player_paddle_width, owner.player_paddle_height)
			var once_composed_pos: Vector2 = owner.player_pos
			var once_composed_draw_scale: float = owner.player_paddle_scale
			driver._sync_paddle_owner_state(target, owner, null, mythic_runtime)
			_expect(paddle_sync.sync_count == 3, "active scale work should exercise a second compositor call")
			_expect(
				Vector2(owner.player_paddle_width, owner.player_paddle_height).is_equal_approx(once_composed_size),
				"repeated final composition must not compound paddle dimensions"
			)
			_expect(owner.player_pos.is_equal_approx(once_composed_pos), "repeated final composition must preserve the aligned position")
			_expect_close(owner.player_paddle_scale, once_composed_draw_scale, "repeated final composition draw scale")


func _verify_character_switch_recomposes_immediately() -> void:
	var owner := DynamicOwner.new()
	var previous_width: float = 155.0 * ANGEL_AND_COMMON_BULK_SCALE * 1.20 * 1.10
	var previous_height: float = 50.0 * ANGEL_AND_COMMON_BULK_SCALE * 1.20 * 1.10
	owner.data = {
		"ai_mode": "champion",
		"selected_character_type": "smasher",
		"selected_runtime_character_id": "smasher",
		"player_speed": 0.0,
		"player_pos": Vector2(FIELD_CENTER_X - previous_width * 0.5, FIELD_BOTTOM_Y - previous_height),
		"player_paddle_width": previous_width,
		"player_paddle_height": previous_height,
		"player_paddle_scale": previous_width / PLAYER_REFERENCE_WIDTH,
		"runtime_paddle_base_width": 155.0,
		"runtime_paddle_base_height": 50.0,
		"runtime_paddle_scale": ANGEL_AND_COMMON_BULK_SCALE,
		"bulkup_paddle_scale": 1.10,
		"special_gauge": 650.0,
		"special_gauge_max": 650.0,
		"optimus_energy_initialized": false,
	}
	var mythic_runtime := FakeMythicPaddleRuntime.new()
	var registry := ApiRegistry.new()
	registry.instances = {
		"player_character_runtime": PlayerCharacterRuntime.new(),
		"battle_scene_config": BattleSceneConfig.new(),
		"optimus_energy_state": OptimusEnergyState.new(),
		"active_item_runtime": FakeActiveItemRuntime.new(),
		"mythic_item_runtime": mythic_runtime,
	}

	BattleSceneApi.new().configure_player_character(owner, registry, "optimus")
	_expect_close(float(owner.data.get("runtime_paddle_base_width", 0.0)), 296.0, "Optimus switch raw base width")
	_expect_close(float(owner.data.get("runtime_paddle_base_height", 0.0)), 147.0, "Optimus switch raw base height")
	_expect_close(float(owner.data.get("player_paddle_width", 0.0)), 538.41216, "Optimus switch should immediately restore final composed width")
	_expect_close(float(owner.data.get("player_paddle_height", 0.0)), 267.38712, "Optimus switch should immediately restore final composed height")
	var player_pos: Vector2 = owner.data.get("player_pos", Vector2.ZERO)
	_expect_close(player_pos.x + float(owner.data.get("player_paddle_width", 0.0)) * 0.5, FIELD_CENTER_X, "Optimus switch composed center")
	_expect_close(player_pos.y + float(owner.data.get("player_paddle_height", 0.0)), FIELD_BOTTOM_Y, "Optimus switch composed bottom")


func _expect_base_only_snapshot(snapshot: Dictionary, label: String) -> void:
	for final_key: String in ["player_paddle_width", "player_paddle_height", "player_paddle_scale"]:
		_expect(
			not snapshot.has(final_key),
			"%s must leave %s to ActiveItemPaddleSync" % [label, final_key]
		)


func _expect_composed_owner(
	owner: FakeOwner,
	target: FakeActiveItemTarget,
	mythic_runtime: FakeMythicPaddleRuntime,
	label: String
) -> void:
	var active_scale: float = (
		target.long_boost_scale
		* target.milk_bottle_scale
		* target.strange_vial_scale
	)
	var final_scale: float = owner.runtime_paddle_scale * active_scale * mythic_runtime.paddle_scale
	var expected_width: float = owner.runtime_paddle_base_width * final_scale
	var expected_height: float = owner.runtime_paddle_base_height * final_scale
	_expect_close(owner.player_paddle_width, expected_width, "%s width" % label)
	_expect_close(owner.player_paddle_height, expected_height, "%s height" % label)
	_expect_close(
		owner.player_paddle_scale,
		expected_width / PLAYER_REFERENCE_WIDTH,
		"%s draw scale" % label
	)
	_expect_close(
		owner.player_pos.x + owner.player_paddle_width * 0.5,
		FIELD_CENTER_X,
		"%s should preserve horizontal center" % label
	)
	_expect_close(
		owner.player_pos.y + owner.player_paddle_height,
		FIELD_BOTTOM_Y,
		"%s should preserve bottom alignment" % label
	)


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(
		abs(actual - expected) <= 0.0001,
		"%s: got %.6f expected %.6f" % [message, actual, expected]
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
