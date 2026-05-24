extends SceneTree

const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const TreasureHuntRuntime := preload("res://scripts/items/treasure_hunt_runtime.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

var _failures: Array[String] = []


class FakeOwner:
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var accessory_slot_count := 2
	var runtime_accessory_slot_bonus := 0
	var runtime_perk_levels: Dictionary = {}
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var player_pos := Vector2(300.0, 700.0)

	func queue_redraw() -> void:
		pass


class FakeRegistry:
	var mythic_item_runtime: Object
	var runtime_perk_state: Object

	func _init(mythic_runtime: Object, perk_state: Object) -> void:
		mythic_item_runtime = mythic_runtime
		runtime_perk_state = perk_state

	func get_instance(key: String) -> Object:
		if key == "mythic_item_runtime":
			return mythic_item_runtime
		if key == "runtime_perk_state":
			return runtime_perk_state
		return null


func _init() -> void:
	_verify_effect_state_reset()
	_verify_effective_treasure_map_chance()
	_verify_reward_pools_skip_owned_one_time_items()
	_verify_grant_routes_to_mythic_runtime()
	_verify_japanese_feedback_text()
	_verify_spanish_feedback_text()

	if _failures.is_empty():
		print("treasure_hunt_runtime_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_effect_state_reset() -> void:
	var runtime := TreasureHuntRuntime.new()
	runtime.last_result = {"ok": true, "result_type": "empty"}
	runtime.result_started_msec = Time.get_ticks_msec()
	_expect(runtime.is_effect_active(), "active result should expose a temporary draw effect")
	runtime.reset()
	_expect(runtime.get_last_result().is_empty(), "reset should clear the last treasure result")
	_expect(not runtime.is_effect_active(), "reset should stop the treasure result effect")


func _verify_effective_treasure_map_chance() -> void:
	var mythic_runtime := MythicItemRuntime.new()
	var perk_state := RuntimePerkState.new()
	perk_state.runtime_skill_levels["downtown_treasure_map"] = 6
	var registry := FakeRegistry.new(mythic_runtime, perk_state)
	var runtime := TreasureHuntRuntime.new()
	_expect_close(runtime._get_legendary_chance(registry), 0.38, "effective Lv.6 chance should keep scaling")


func _verify_reward_pools_skip_owned_one_time_items() -> void:
	var mythic_runtime := MythicItemRuntime.new()
	var registry := FakeRegistry.new(mythic_runtime, RuntimePerkState.new())
	var runtime := TreasureHuntRuntime.new()
	_expect(runtime._get_mythic_reward_pool(registry).has("megingjord"), "mythic pool should include unowned mythics")
	_expect(runtime._get_passive_reward_pool(registry).has("dowsing_pendulum"), "passive pool should include passive items")

	var owner := FakeOwner.new()
	_expect(mythic_runtime.acquire_item("lucky_coin", owner, registry, {}, true, false) >= 0, "setup should acquire Lucky Coin")
	_expect(not runtime._get_passive_reward_pool(registry).has("lucky_coin"), "owned one-time passive rewards should be skipped")


func _verify_grant_routes_to_mythic_runtime() -> void:
	var mythic_runtime := MythicItemRuntime.new()
	var perk_state := RuntimePerkState.new()
	var registry := FakeRegistry.new(mythic_runtime, perk_state)
	var runtime := TreasureHuntRuntime.new()
	var owner := FakeOwner.new()

	var passive_result: Dictionary = runtime._grant_passive_or_mythic_reward("dowsing_pendulum", "passive", owner, registry)
	_expect(bool(passive_result.get("ok", false)), "passive treasure reward should grant successfully")
	_expect(_inventory_has_item(mythic_runtime, "dowsing_pendulum"), "passive reward should enter mythic inventory")

	var mythic_result: Dictionary = runtime._grant_passive_or_mythic_reward("megingjord", "legendary", owner, registry)
	_expect(bool(mythic_result.get("ok", false)), "mythic treasure reward should grant successfully")
	_expect(_inventory_has_item(mythic_runtime, "megingjord"), "mythic reward should enter mythic inventory")


func _verify_japanese_feedback_text() -> void:
	var runtime := TreasureHuntRuntime.new()
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_JAPANESE)
	_expect(runtime._format_result_text("神話", "スピードブーツ") == "神話発見：スピードブーツ", "treasure result text should localize to Japanese")
	_expect(runtime._format_feedback_text("スピードブーツ") == "宝探し：スピードブーツ", "treasure feedback text should localize to Japanese")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)


func _verify_spanish_feedback_text() -> void:
	var runtime := TreasureHuntRuntime.new()
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_SPANISH)
	_expect(runtime._format_result_text("Mítico", "Botas de velocidad") == "Mítico encontrado: Botas de velocidad", "treasure result text should localize to Spanish")
	_expect(runtime._format_feedback_text("Botas de velocidad") == "Búsqueda del tesoro: Botas de velocidad", "treasure feedback text should localize to Spanish")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)


func _inventory_has_item(runtime: Object, item_name: String) -> bool:
	var snapshot: Dictionary = runtime.get_snapshot()
	for item_value in snapshot.get("inventory_items", []):
		if item_value is Dictionary and str(item_value.get("name", "")) == item_name:
			return true
	return false


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
