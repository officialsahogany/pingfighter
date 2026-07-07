extends SceneTree

const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")
const ViperSkillConfig := preload("res://scripts/characters/viper_skill_config.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var active_item_slots: Array = []
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var accessory_slot_count := 4
	var selected_character_type := "smasher"
	var special_gauge := 500.0
	var special_gauge_max := 500.0
	var player_pos := Vector2(302.5, 690.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var boss_pos := Vector2(330.0, 25.0)
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0
	var values: Dictionary = {}

	func _get(property: StringName) -> Variant:
		return values.get(String(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		values[String(property)] = value
		return true

	func queue_redraw() -> void:
		values["redraw_queued"] = true

	func request_battle_redraw() -> void:
		values["redraw_requested"] = true


class FakeAudio:
	extends RefCounted

	var active_item_count := 0
	var pickup_count := 0
	var horn_change_count := 0

	func play_active_item() -> void:
		active_item_count += 1

	func play_item_get() -> void:
		pickup_count += 1

	func play_horn_strawberry_change() -> void:
		horn_change_count += 1

	func play_megingjord() -> void:
		active_item_count += 1


class FakeFeedback:
	extends RefCounted

	var flash_count := 0
	var spin_count := 0
	var max_shake := 0.0

	func trigger_gauge_flash() -> void:
		flash_count += 1

	func trigger_orb_gauge_spin() -> void:
		spin_count += 1

	func max_screen_shake(amount: float, _intensity: float) -> void:
		max_shake = max(max_shake, amount)

	func set_screen_shake(amount: float, _intensity: float) -> void:
		max_shake = max(max_shake, amount)


class FakeInputReader:
	extends RefCounted

	var snapshot: Dictionary = {}

	func get_snapshot() -> Dictionary:
		return snapshot


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(source_instances: Dictionary) -> void:
		instances = source_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	seed(55055)
	PerkConversionFlags.debug_set_enabled(false)
	_verify_off_flag_keeps_mythic_item_rolls()
	_verify_on_flag_uses_mythic_fixed_values()
	_verify_on_flag_level_zero_and_item_only_are_inactive()
	_verify_on_flag_perk_replaces_item_without_max()
	_verify_crown_bonus_source_and_exemptions()
	_verify_horn_used_state_and_stage_boundary()
	_verify_runtime_consumers_use_batch5_gates()
	PerkConversionFlags.debug_set_enabled(false)

	if _failures.is_empty():
		print("perk_conversion_gate_batch5_smoke: ok")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_off_flag_keeps_mythic_item_rolls() -> void:
	PerkConversionFlags.debug_set_enabled(false)
	for lane_value in _value_lanes():
		var lane: Dictionary = lane_value
		var env := _make_env({})
		var runtime: Object = env["runtime"]
		_expect(_equip_item(env, str(lane["item"]), lane["rolls"]), "OFF %s fixture should equip" % str(lane["item"]))
		_expect(bool(runtime.call(str(lane["active"]))), "OFF %s active gate should follow equipped state" % str(lane["item"]))
		_expect_close(
			float(runtime.call(str(lane["getter"]))),
			float(lane["off"]),
			"OFF %s.%s should keep the item roll path" % [str(lane["item"]), str(lane["key"])]
		)


func _verify_on_flag_uses_mythic_fixed_values() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	for lane_value in _value_lanes():
		var lane: Dictionary = lane_value
		var env := _make_env({str(lane["item"]): 1})
		var runtime: Object = env["runtime"]
		_expect(bool(runtime.call(str(lane["active"]))), "ON perk-only %s should be active" % str(lane["item"]))
		_expect_close(
			float(runtime.call(str(lane["getter"]))),
			PerkConversionValues.get_mythic_value(str(lane["item"]), str(lane["key"])),
			"ON perk-only %s.%s should use the fixed mythic value" % [str(lane["item"]), str(lane["key"])]
		)


func _verify_on_flag_level_zero_and_item_only_are_inactive() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	for lane_value in _value_lanes():
		var lane: Dictionary = lane_value
		var zero_env := _make_env({})
		var zero_runtime: Object = zero_env["runtime"]
		_expect(not bool(zero_runtime.call(str(lane["active"]))), "ON level 0 %s should be inactive" % str(lane["item"]))
		_expect_close(
			float(zero_runtime.call(str(lane["getter"]))),
			0.0,
			"ON level 0 %s.%s should expose 0" % [str(lane["item"]), str(lane["key"])]
		)

		var item_env := _make_env({})
		var item_runtime: Object = item_env["runtime"]
		_expect(_equip_item(item_env, str(lane["item"]), lane["high_rolls"]), "ON item-only %s fixture should equip" % str(lane["item"]))
		_expect(not bool(item_runtime.call(str(lane["active"]))), "ON item-only %s should be inactive" % str(lane["item"]))
		_expect_close(
			float(item_runtime.call(str(lane["getter"]))),
			0.0,
			"ON item-only %s.%s should not leak item rolls" % [str(lane["item"]), str(lane["key"])]
		)


func _verify_on_flag_perk_replaces_item_without_max() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	for lane_value in _value_lanes():
		var lane: Dictionary = lane_value
		var env := _make_env({str(lane["item"]): 1})
		var runtime: Object = env["runtime"]
		_expect(_equip_item(env, str(lane["item"]), lane["high_rolls"]), "ON item+perk %s fixture should equip" % str(lane["item"]))
		_expect(bool(runtime.call(str(lane["active"]))), "ON item+perk %s should be active through the perk" % str(lane["item"]))
		_expect_close(
			float(runtime.call(str(lane["getter"]))),
			PerkConversionValues.get_mythic_value(str(lane["item"]), str(lane["key"])),
			"ON %s.%s should replace item rolls instead of max/adding them" % [str(lane["item"]), str(lane["key"])]
		)


func _verify_crown_bonus_source_and_exemptions() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	var crown_env := _make_env({
		"transcendent_crown": 1,
		"odins_eye": 1,
		"star_detector": 2,
	})
	var crown_runtime: Object = crown_env["runtime"]
	var crown_state: Object = crown_env["state"]
	crown_runtime.refresh_runtime_perk_scaling(crown_env["owner"], crown_env["registry"])
	_expect_close(crown_runtime.get_transcendent_crown_skill_bonus(), 2.0, "ON Crown perk should provide the fixed +2 source")
	_expect(int(crown_state.get_item_perk_level_bonus()) == 2, "ON Crown source should sync +2 into RuntimePerkState")
	_expect(int(crown_state.get_converted_perk_effect_level("star_detector")) == 4, "ON Crown should raise regular converted perks")
	_expect(int(crown_state.get_converted_perk_effect_level("odins_eye")) == 1, "ON Crown should not raise another mythic perk")
	_expect(int(crown_state.get_converted_perk_effect_level("transcendent_crown")) == 1, "ON Crown should not raise itself")

	PerkConversionFlags.debug_set_enabled(false)
	var off_env := _make_env({"star_detector": 2})
	_expect(_equip_item(off_env, "transcendent_crown", {"skill_bonus": 2.0}), "OFF Crown fixture should equip")
	var off_state: Object = off_env["state"]
	_expect(int(off_state.get_item_perk_level_bonus()) == 2, "OFF Crown should keep the equipped item roll as the bonus source")
	_expect(int(off_state.get_converted_perk_effect_level("star_detector")) == 4, "OFF Crown item roll should still raise regular converted perks")

	PerkConversionFlags.debug_set_enabled(true)
	var stack_env := _make_env({
		"transcendent_crown": 1,
		"star_detector": 2,
	})
	_expect(_equip_item(stack_env, "sage_ring", {"sage_speed_penalty_pct": 9.0, "sage_body_penalty_pct": 11.0}), "ON Sage Ring transition fixture should equip")
	var stack_state: Object = stack_env["state"]
	_expect(int(stack_state.get_item_perk_level_bonus()) == 3, "ON Crown fixed source should stack with Sage Ring during the transition")
	_expect(int(stack_state.get_converted_perk_effect_level("star_detector")) == 5, "ON Crown + Sage Ring should both feed regular converted perks")


func _verify_horn_used_state_and_stage_boundary() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	var env := _make_env({"horn_strawberry_mask": 1})
	var runtime: Object = env["runtime"]
	var owner: Object = env["owner"]
	owner.special_gauge = 500.0
	_expect(_feed_horn_command(env), "ON perk-only Horn command should enter through the real command listener")
	_expect(runtime.is_horn_strawberry_event_playing(), "ON Horn command should start the transform event")
	_expect_close(float(owner.special_gauge), 0.0, "ON Horn command should spend the existing gauge cost")

	owner.special_gauge = 500.0
	_expect(not runtime.try_horn_strawberry_transform(owner, env["registry"]), "ON Horn used state should block same-stage direct retry")
	runtime.reset_round(env["registry"])
	_expect(not runtime.try_horn_strawberry_transform(owner, env["registry"]), "ON Horn round reset should preserve the used-this-stage lock")
	runtime.on_stage_advance(owner, env["registry"])
	owner.special_gauge = 500.0
	_expect(runtime.try_horn_strawberry_transform(owner, env["registry"]), "ON Horn stage advance should reuse the existing used reset boundary")


func _verify_runtime_consumers_use_batch5_gates() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	_verify_cape_slot_consumer()
	_verify_odins_eye_revival_consumer()
	_verify_pandora_round_win_consumer()


func _verify_cape_slot_consumer() -> void:
	var env := _make_env({"heavenly_cape": 1})
	var runtime: Object = env["runtime"]
	runtime.refresh_runtime_perk_scaling(env["owner"], env["registry"])
	_expect(runtime.is_heavenly_cape_active(), "ON perk-only Cape should be active")
	_expect(int(runtime.get_player_skill_max_slots(5)) == 6, "ON Cape runtime slot getter should add the fixed slot")
	_expect_close(runtime.get_player_skill_cooldown_multiplier(), 0.85, "ON Cape runtime cooldown multiplier should use the fixed reduction")
	var smasher_config: Object = env["registry"].get_instance("smasher_skill_config")
	_expect(smasher_config != null, "Cape consumer fixture should provide the Smasher skill config")
	if smasher_config != null:
		_expect(int(smasher_config.get_max_skill_slots()) == 6, "ON Cape sync should update the real skill-config slot path")
		_expect_close(float(smasher_config.get_effective_cooldown_multiplier()), 0.85, "ON Cape sync should update the real skill-config cooldown path")


func _verify_odins_eye_revival_consumer() -> void:
	var env := _make_env({"odins_eye": 1})
	var runtime: Object = env["runtime"]
	_expect(runtime.is_odins_eye_active(), "ON perk-only Odin should be active")
	_expect(runtime.is_odins_eye_available(), "ON perk-only Odin should be available before use")
	_expect(runtime.try_trigger_odins_eye_revival("round", 0.0), "ON perk-only Odin should trigger through the real revival entry")
	_expect(runtime.has_odins_eye_revival_used(), "ON Odin trigger should mark the existing used state")
	_expect(not runtime.is_odins_eye_available(), "ON Odin used state should block another revival")


func _verify_pandora_round_win_consumer() -> void:
	var env := _make_env({"pandora_legacy": 1})
	var runtime: Object = env["runtime"]
	var triggered := false
	for _attempt in range(120):
		if runtime.try_queue_pandora_legacy_round_win({
			"owner": env["owner"],
			"registry": env["registry"],
		}):
			triggered = true
			break
	_expect(triggered, "ON perk-only Pandora should queue through the real round-win trigger")
	_expect(runtime.has_pending_pandora_legacy_selection(), "ON Pandora should leave a pending selection")
	_expect(runtime.pandora_legacy_selection_state.pending_choices.size() == 3, "ON Pandora should keep the existing three-card transition pool")


func _value_lanes() -> Array:
	return [
		_lane("hermes_shoes", "speed_bonus", "get_hermes_shoes_speed_bonus_pct", "is_hermes_shoes_active", {"speed_bonus": 137.0}, {"speed_bonus": 300.0}, 137.0),
		_lane("celestial_armor", "trigger_chance_pct", "get_celestial_armor_trigger_chance_pct", "is_celestial_armor_active", {"trigger_chance_pct": 88.0, "gauge_cost": 42.0}, {"trigger_chance_pct": 100.0, "gauge_cost": 99.0}, 88.0),
		_lane("celestial_armor", "gauge_cost", "get_celestial_armor_gauge_cost", "is_celestial_armor_active", {"trigger_chance_pct": 88.0, "gauge_cost": 42.0}, {"trigger_chance_pct": 100.0, "gauge_cost": 99.0}, 42.0),
		_lane("ragnarok_hammer", "trigger_chance", "get_ragnarok_trigger_chance", "is_ragnarok_hammer_active", {"trigger_chance": 86.0, "stun_duration": 1.1, "speed_boost": 70.0, "gauge_cost": 44.0}, {"trigger_chance": 100.0, "stun_duration": 1.2, "speed_boost": 90.0, "gauge_cost": 80.0}, 86.0),
		_lane("ragnarok_hammer", "stun_duration", "get_ragnarok_stun_duration", "is_ragnarok_hammer_active", {"trigger_chance": 86.0, "stun_duration": 1.1, "speed_boost": 70.0, "gauge_cost": 44.0}, {"trigger_chance": 100.0, "stun_duration": 1.2, "speed_boost": 90.0, "gauge_cost": 80.0}, 1.1),
		_lane("ragnarok_hammer", "speed_boost", "get_ragnarok_speed_boost", "is_ragnarok_hammer_active", {"trigger_chance": 86.0, "stun_duration": 1.1, "speed_boost": 70.0, "gauge_cost": 44.0}, {"trigger_chance": 100.0, "stun_duration": 1.2, "speed_boost": 90.0, "gauge_cost": 80.0}, 70.0),
		_lane("ragnarok_hammer", "gauge_cost", "get_ragnarok_gauge_cost", "is_ragnarok_hammer_active", {"trigger_chance": 86.0, "stun_duration": 1.1, "speed_boost": 70.0, "gauge_cost": 44.0}, {"trigger_chance": 100.0, "stun_duration": 1.2, "speed_boost": 90.0, "gauge_cost": 80.0}, 44.0),
		_lane("poseidon_trident", "cooldown", "get_poseidon_cooldown", "is_poseidon_trident_active", {"cooldown": 8.0, "gauge_cost": 44.0, "vortex_size": 260.0}, {"cooldown": 12.0, "gauge_cost": 70.0, "vortex_size": 450.0}, 8.0),
		_lane("poseidon_trident", "gauge_cost", "get_poseidon_gauge_cost", "is_poseidon_trident_active", {"cooldown": 8.0, "gauge_cost": 44.0, "vortex_size": 260.0}, {"cooldown": 12.0, "gauge_cost": 70.0, "vortex_size": 450.0}, 44.0),
		_lane("poseidon_trident", "vortex_size", "get_poseidon_vortex_size", "is_poseidon_trident_active", {"cooldown": 8.0, "gauge_cost": 44.0, "vortex_size": 260.0}, {"cooldown": 12.0, "gauge_cost": 70.0, "vortex_size": 450.0}, 260.0),
		_lane("megingjord", "extra_pick_chance", "get_megingjord_extra_pick_chance", "is_megingjord_active", {"extra_pick_chance": 45.0}, {"extra_pick_chance": 95.0}, 45.0),
		_lane("heavenly_cape", "skill_slot_bonus", "get_heavenly_cape_skill_slot_bonus", "is_heavenly_cape_active", {"skill_cooldown_reduction": 22.0}, {"skill_cooldown_reduction": 45.0}, 1.0),
		_lane("heavenly_cape", "skill_cooldown_reduction", "get_heavenly_cape_skill_cooldown_reduction_pct", "is_heavenly_cape_active", {"skill_cooldown_reduction": 22.0}, {"skill_cooldown_reduction": 45.0}, 22.0),
		_lane("transcendent_crown", "skill_bonus", "get_transcendent_crown_skill_bonus", "is_transcendent_crown_active", {"skill_bonus": 1.0}, {"skill_bonus": 1.0}, 1.0),
		_lane("odins_eye", "revival_chance", "get_odins_eye_revival_chance_pct", "is_odins_eye_active", {"revival_chance": 70.0}, {"revival_chance": 100.0}, 70.0),
		_lane("horn_strawberry_mask", "transform_duration", "get_horn_strawberry_transform_duration_sec", "is_horn_strawberry_mask_active", {"transform_duration": 65.0}, {"transform_duration": 70.0}, 65.0),
		_lane("baal_boots", "gauge_recovery", "get_baal_boots_gauge_recovery", "is_baal_boots_active", {"gauge_recovery": 450.0}, {"gauge_recovery": 500.0}, 450.0),
		_lane("pandora_legacy", "selection_quality", "get_pandora_legacy_selection_quality", "is_pandora_legacy_active", {"selection_quality": 77.0, "trigger_chance": 88.0}, {"selection_quality": 100.0, "trigger_chance": 100.0}, 77.0),
		_lane("pandora_legacy", "trigger_chance", "get_pandora_legacy_trigger_chance", "is_pandora_legacy_active", {"selection_quality": 77.0, "trigger_chance": 88.0}, {"selection_quality": 100.0, "trigger_chance": 100.0}, 88.0),
	]


func _lane(
	item: String,
	key: String,
	getter: String,
	active: String,
	rolls: Dictionary,
	high_rolls: Dictionary,
	off_value: float
) -> Dictionary:
	return {
		"item": item,
		"key": key,
		"getter": getter,
		"active": active,
		"rolls": rolls,
		"high_rolls": high_rolls,
		"off": off_value,
	}


func _make_env(levels: Dictionary) -> Dictionary:
	var runtime := MythicItemRuntime.new()
	runtime.get_snapshot()
	var state := RuntimePerkState.new()
	for id_value in levels.keys():
		state.runtime_skill_levels[str(id_value)] = int(levels[id_value])
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new({
		"mythic_item_runtime": runtime,
		"runtime_perk_state": state,
		"game_audio": FakeAudio.new(),
		"battle_feedback_state": FakeFeedback.new(),
		"smasher_skill_config": SmasherSkillConfig.new(),
		"viper_skill_config": ViperSkillConfig.new(),
		"commando_skill_config": CommandoSkillConfig.new(),
		"smasher_input_reader": FakeInputReader.new(),
	})
	runtime.owner_syncer.sync_runtime_perk_state_ref(runtime, registry)
	return {
		"runtime": runtime,
		"state": state,
		"owner": owner,
		"registry": registry,
	}


func _equip_item(env: Dictionary, item_name: String, rolls: Dictionary) -> bool:
	return bool(env["runtime"].equip_item(item_name, env["owner"], env["registry"], rolls, false))


func _feed_horn_command(env: Dictionary) -> bool:
	var runtime: Object = env["runtime"]
	var owner: Object = env["owner"]
	var registry: Object = env["registry"]
	var input_reader: Object = registry.get_instance("smasher_input_reader")
	var triggered := false
	var frames: Array = [
		{"left_pressed": true},
		{},
		{"right_pressed": true},
		{},
		{"left_pressed": true},
		{},
		{"right_pressed": true},
		{},
		{"left_pressed": true},
		{},
		{"right_pressed": true},
	]
	for frame_value in frames:
		var frame: Dictionary = frame_value
		input_reader.snapshot = frame
		runtime.update(owner, registry, 0.1)
		triggered = runtime.is_horn_strawberry_event_playing() or triggered
	return triggered


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
