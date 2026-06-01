extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemHudState := preload("res://scripts/hud/active_item_hud_state.gd")
const ActiveItemSlotController := preload("res://scripts/items/active_item_slot_controller.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")


class FakeOwner:
	var active_item_slots: Array = []
	var special_gauge := 0.0
	var special_gauge_max := 500.0


class FakeAudio:
	var alchemy_count := 0
	var active_item_count := 0

	func play_alchemy() -> void:
		alchemy_count += 1

	func play_active_item() -> void:
		active_item_count += 1


class FakeRegistry:
	var runtime_perk_state: Object
	var game_audio: Object

	func _init(perk_state: Object, audio: Object = null) -> void:
		runtime_perk_state = perk_state
		game_audio = audio

	func get_instance(key: String) -> Object:
		match key:
			"runtime_perk_state":
				return runtime_perk_state
			"game_audio":
				return game_audio
		return null


var _effect_calls := 0
var _backup_calls := 0


func _init() -> void:
	var catalog := RuntimePerkCatalog.new()
	var alchemy_data: Dictionary = catalog.get_perk_data("item_recycle")
	_expect(not alchemy_data.is_empty(), "catalog should register Alchemy")
	_expect(str(alchemy_data.get("name", "")) == "연금술", "Alchemy should keep its Korean display name")
	_expect(int(alchemy_data.get("max_level", 0)) == 5, "Alchemy should have five base levels")
	_expect(str(alchemy_data.get("tree", "")) == "item", "Alchemy should live in the item tree")
	_expect(ProjectResourceLoader.load_audio_stream("res://assets/sounds/alchemy.wav") != null, "Alchemy sound should load from Godot assets")

	var perk_state := RuntimePerkState.new()
	perk_state.runtime_skill_levels["item_recycle"] = 5
	_expect_close(perk_state.get_runtime_skill_bonus("item_recycle"), 0.35, "Lv.5 Alchemy bonus should match Python")
	_expect_close(perk_state.get_active_item_recycle_chance(), 0.35, "Lv.5 Alchemy recycle chance should match Python")
	perk_state.item_perk_level_bonus = 1
	_expect_close(perk_state.get_active_item_recycle_chance(), 0.42, "effective Lv.6 Alchemy should keep scaling")
	perk_state.item_perk_level_bonus = 20
	_expect_close(perk_state.get_active_item_recycle_chance(), 0.90, "Alchemy chance should keep Python's 90% cap")

	seed(1)
	_effect_calls = 0
	_backup_calls = 0
	var audio := FakeAudio.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(perk_state, audio)
	var slot_controller := ActiveItemSlotController.new()
	owner.active_item_slots = [_build_test_item("banana")]
	_expect(slot_controller.use_slot(0, owner, registry, false, Callable(self, "_apply_effect"), Callable(self, "_backup_item")), "Alchemy item use should succeed")
	_expect(_effect_calls == 1, "item effect should be applied once")
	_expect(_backup_calls == 0, "recycled consumables should not create a pending throw backup")
	_expect(owner.active_item_slots.size() == 1, "Alchemy should keep the used item in its slot")
	var kept_item: Dictionary = owner.active_item_slots[0]
	_expect(kept_item.has("last_use_msec"), "kept item should receive cooldown timing")
	_expect(int(kept_item.get("alchemy_notice_until_msec", 0)) > Time.get_ticks_msec(), "kept item should expose an Alchemy notice timer")
	_expect(audio.alchemy_count == 1, "Alchemy should play the dedicated audio cue")

	var hud_state := ActiveItemHudState.new()
	var status: Dictionary = hud_state.get_slot_status(0, kept_item, Time.get_ticks_msec(), 5000, registry, perk_state)
	_expect(float(status.get("alchemy_notice_ratio", 0.0)) > 0.0, "HUD status should expose the Alchemy notice")
	_expect(int(ActiveItemCatalog.DEFAULT_COOLDOWN_MSEC) == 7000, "default active-item cooldown should be 7 seconds")
	_expect(
		int(ActiveItemHudState.DEFAULT_ACTIVE_ITEM_COOLDOWN_MS) == int(ActiveItemCatalog.DEFAULT_COOLDOWN_MSEC),
		"active-item HUD cooldown fallback should track the catalog default"
	)
	_expect(
		hud_state.get_active_item_cooldown_msec({}, registry, null) == ActiveItemCatalog.DEFAULT_COOLDOWN_MSEC,
		"active-item HUD default cooldown should use the shared 7-second value"
	)
	var post_serve_throw_status: Dictionary = hud_state.get_slot_status(
		1,
		{"name": "grenade", "last_use_msec": -1},
		Time.get_ticks_msec(),
		0,
		registry,
		perk_state
	)
	_expect(
		int(post_serve_throw_status.get("throw_lock_remaining_seconds", -1)) == 0,
		"throwable active items should not show a post-serve lockout timer"
	)

	var no_perk_state := RuntimePerkState.new()
	_effect_calls = 0
	_backup_calls = 0
	var owner_without_alchemy := FakeOwner.new()
	owner_without_alchemy.active_item_slots = [_build_test_item("banana")]
	var registry_without_alchemy := FakeRegistry.new(no_perk_state, FakeAudio.new())
	var plain_slot_controller := ActiveItemSlotController.new()
	_expect(plain_slot_controller.use_slot(0, owner_without_alchemy, registry_without_alchemy, false, Callable(self, "_apply_effect"), Callable(self, "_backup_item")), "plain item use should succeed")
	_expect(owner_without_alchemy.active_item_slots.is_empty(), "without Alchemy the used consumable should be removed")
	_expect(_backup_calls == 1, "non-recycled consumable path should still call the pending backup hook")

	print("item_alchemy_perk_port_smoke: ok")
	quit(0)


func _build_test_item(item_name: String) -> Dictionary:
	return {
		"name": item_name,
		"effect": item_name,
		"display_name": item_name,
		"cooldown_msec": 0,
		"consumable": true,
	}


func _apply_effect(_item_data: Dictionary, _owner: Object, _registry: Object) -> bool:
	_effect_calls += 1
	return true


func _backup_item(_item_data: Dictionary, _slot_index: int, _owner: Object, _registry: Object) -> void:
	_backup_calls += 1


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
