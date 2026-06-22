extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemFieldSpawnPool := preload("res://scripts/items/active_item_field_spawn_pool.gd")
const ActiveItemRuntime := preload("res://scripts/items/active_item_runtime.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var active_item_slots: Array = []
	var special_gauge := 0.0
	var special_gauge_max := 500.0
	var lingpet_owned_pet_ids: Array = []
	var owned_lingpet_ids: Array = []
	var owned_ringpet_ids: Array = []
	var lingpet_collection: Dictionary = {}
	var ringpet_collection: Dictionary = {}
	var owned_lingpets: Dictionary = {}
	var owned_ringpets: Dictionary = {}
	var lingpet_slots: Array = []
	var ringpet_slots: Array = []
	var lingpet_slot_pet_ids: Array = []
	var ringpet_slot_pet_ids: Array = []
	var lingpet_active_slot_index := -1
	var ringpet_active_slot_index := -1
	var player_pos := Vector2(302.5, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0

	func queue_redraw() -> void:
		pass


class FakeHudState:
	extends RefCounted

	var selected_index := 0

	func set_selected_index(index: int) -> void:
		selected_index = index

	func get_selected_index() -> int:
		return selected_index


class FakeFeedback:
	extends RefCounted

	var shake_count := 0
	var gauge_flash_count := 0

	func max_screen_shake(_amount: float, _duration: float) -> void:
		shake_count += 1

	func trigger_gauge_flash() -> void:
		gauge_flash_count += 1


class FakeAudio:
	extends RefCounted

	var active_item_count := 0

	func play_active_item() -> void:
		active_item_count += 1


class FakeRegistry:
	extends RefCounted

	var lingpet_runtime: Object
	var hud_state := FakeHudState.new()
	var feedback := FakeFeedback.new()
	var audio := FakeAudio.new()

	func _init(runtime: Object) -> void:
		lingpet_runtime = runtime

	func get_instance(key: String) -> Object:
		match key:
			"lingpet_egg_runtime":
				return lingpet_runtime
			"active_item_hud_state":
				return hud_state
			"battle_feedback_state":
				return feedback
			"game_audio":
				return audio
		return null


func _init() -> void:
	_run()


func _run() -> void:
	_verify_lingpet_feed_catalog_and_icon()
	_verify_lingpet_feed_field_spawn_gate_uses_real_catalog()
	_verify_lingpet_feed_active_item_use_and_blocked_preservation()
	_verify_lingpet_feed_source_contracts()

	if _failures.is_empty():
		print("lingpet_feed_active_item_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_lingpet_feed_catalog_and_icon() -> void:
	var catalog := ActiveItemCatalog.new()
	var item_data: Dictionary = catalog.build_item_by_name("lingpet_feed")
	_expect(not item_data.is_empty(), "lingpet_feed should build from the active item catalog")
	_expect(ActiveItemCatalog.FIELD_SPAWN_ORDER.has("lingpet_feed"), "lingpet_feed should be in the active field-spawn order")
	_expect(str(item_data.get("effect", "")) == "lingpet_feed", "lingpet_feed should dispatch through a matching effect id")
	_expect(bool(item_data.get("consumable", false)), "lingpet_feed should be a consumable active item")
	_expect(float(item_data.get("feed_amount", 0.0)) == 35.0, "lingpet_feed catalog should expose the placeholder feed amount")
	var icon_path := str(item_data.get("icon_path", ""))
	_expect(icon_path.ends_with("lingpet_feed_icon.png"), "lingpet_feed should use its dedicated item icon path")
	_expect(ProjectResourceLoader.load_texture(icon_path) != null, "lingpet_feed icon should load through the project resource loader")


func _verify_lingpet_feed_field_spawn_gate_uses_real_catalog() -> void:
	var pool := ActiveItemFieldSpawnPool.new()
	var empty_owner := FakeOwner.new()
	var owned_owner := FakeOwner.new()
	owned_owner.lingpet_owned_pet_ids = ["maribo"]
	_expect(
		not _array_has_item(pool.build_spawn_candidates(null, empty_owner), "lingpet_feed"),
		"real field-spawn candidates should hide lingpet_feed before the player owns a lingpet"
	)
	pool.clear_spawn_candidate_cache()
	_expect(
		_array_has_item(pool.build_spawn_candidates(null, owned_owner), "lingpet_feed"),
		"real field-spawn candidates should expose lingpet_feed after the player owns a lingpet"
	)


func _verify_lingpet_feed_active_item_use_and_blocked_preservation() -> void:
	var runtime := ActiveItemRuntime.new()
	var lingpet_runtime := LingpetEggRuntime.new()
	var registry := FakeRegistry.new(lingpet_runtime)
	var owner := FakeOwner.new()

	_expect(runtime.grant_item_to_slot("lingpet_feed", owner, registry, false), "fixture should grant a lingpet_feed active item")
	_expect(not runtime.use_slot(0, owner, registry), "lingpet_feed should not apply without an active lingpet")
	_expect(owner.active_item_slots.size() == 1, "failed lingpet_feed should remain in the active slot")

	_expect(lingpet_runtime.debug_grant_and_activate_pet("maribo", owner), "fixture should activate a lingpet")
	_clear_active_item_cooldown(runtime, owner)
	_expect(runtime.use_slot(0, owner, registry), "lingpet_feed should apply through the active item runtime once a lingpet is active")
	_expect(owner.active_item_slots.is_empty(), "successful consumable lingpet_feed should leave the active slot")
	_expect(lingpet_runtime.get_affinity_points("maribo") == 0.0, "successful lingpet_feed item use should not grant feed affinity until the bowl animation completes")
	_expect(bool(lingpet_runtime.get_snapshot().get("feed_bowl_active", false)), "successful lingpet_feed should spawn a visible feed bowl")
	_advance_feed_until_complete(lingpet_runtime, owner, registry)
	_expect(lingpet_runtime.get_affinity_points("maribo") == 35.0, "completed feed bowl animation should grant feed affinity")
	_expect(registry.audio.active_item_count == 1, "successful lingpet_feed should play active item feedback")

	for _i in range(2):
		_expect(runtime.grant_item_to_slot("lingpet_feed", owner, registry, false), "fixture should grant another feed item before the cap")
		_clear_active_item_cooldown(runtime, owner)
		_expect(runtime.use_slot(0, owner, registry), "feed item use before the run cap should apply")
		_advance_feed_until_complete(lingpet_runtime, owner, registry)
	_expect(runtime.grant_item_to_slot("lingpet_feed", owner, registry, false), "fixture should grant a fourth feed item")
	_clear_active_item_cooldown(runtime, owner)
	_expect(not runtime.use_slot(0, owner, registry), "fourth feed item in one run should be blocked by the affinity counter")
	_expect(owner.active_item_slots.size() == 1, "blocked fourth feed should not be consumed")
	_expect(lingpet_runtime.get_last_affinity_result_for_tests().get("blocked_reason", "") == "max_feed_uses", "blocked fourth feed should report max_feed_uses")


func _verify_lingpet_feed_source_contracts() -> void:
	var catalog_source := FileAccess.get_file_as_string("res://scripts/items/active_item_catalog.gd")
	_expect(catalog_source.find("\"lingpet_feed\"") >= 0, "active item catalog should mention lingpet_feed")
	_expect(catalog_source.find("func _build_lingpet_feed") >= 0, "active item catalog should build lingpet_feed")
	_expect(catalog_source.find("LINGPET_FEED_ICON_PATH") >= 0, "active item catalog should use a dedicated feed icon constant")

	var router_source := FileAccess.get_file_as_string("res://scripts/items/active_item_effect_router.gd")
	_expect(router_source.find("\"lingpet_feed\"") >= 0 and router_source.find("\"apply_lingpet_feed\"") >= 0, "active item effect router should dispatch lingpet_feed")

	var controller_source := FileAccess.get_file_as_string("res://scripts/items/active_item_effect_controller.gd")
	var facade_source := FileAccess.get_file_as_string("res://scripts/items/active_item_effect_action_facade.gd")
	_expect(controller_source.find("func apply_lingpet_feed") >= 0, "effect controller should expose apply_lingpet_feed")
	_expect(facade_source.find("feed_lingpet(owner, registry)") >= 0, "effect facade should call the lingpet runtime feed_lingpet entrypoint")
	_expect(FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_feed_bowl_state.gd").find("lingpet_feed_bowl.png") >= 0, "feed bowl state should draw the dedicated bowl icon")

	var debug_source := FileAccess.get_file_as_string("res://scripts/items/active_item_debug_spawn_menu.gd")
	_expect(debug_source.find("\"lingpet_feed\"") >= 0, "debug active item menu should expose lingpet_feed")


func _array_has_item(items: Array, item_name: String) -> bool:
	for item_value in items:
		if item_value is Dictionary and str(item_value.get("name", "")) == item_name:
			return true
	return false


func _clear_active_item_cooldown(runtime: Object, owner: Object) -> void:
	if runtime == null or runtime.slot_controller == null:
		return
	runtime.slot_controller.last_item_use_msec = -999999
	if owner == null:
		return
	for index in range(owner.active_item_slots.size()):
		var item_value: Variant = owner.active_item_slots[index]
		if item_value is Dictionary:
			var item_data: Dictionary = item_value
			item_data["last_use_msec"] = -999999
			owner.active_item_slots[index] = item_data


func _advance_feed_until_complete(lingpet_runtime: Object, owner: Object, registry: Object) -> void:
	for _i in range(260):
		lingpet_runtime.update(1.0 / 60.0, owner, registry)
		if not bool(lingpet_runtime.get_snapshot().get("feed_bowl_active", false)):
			return
	_expect(false, "feed bowl active item animation should complete within the smoke time budget")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
