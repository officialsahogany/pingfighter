extends SceneTree

const ActiveItemFieldSpawnController := preload("res://scripts/items/active_item_field_spawn_controller.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const PaddleBounceEventRouter := preload("res://scripts/ball/paddle_bounce_event_router.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")


class FakeOwner:
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var gold_digger_equipped := false
	var gold_digger_count := 0
	var gold_digger_gold_bonus_pct := 0.0
	var gold_digger_multiplier := 1.0
	var runtime_perk_levels: Dictionary = {}
	var runtime_perk_pending_choices := 0
	var runtime_perk_starpoints := 0
	var runtime_perk_gold := 0
	var runtime_perk_choice_active := false

	func queue_redraw() -> void:
		pass


class FakeRegistry:
	var runtime_perk_state: Object = null

	func _init(perk_state: Object) -> void:
		runtime_perk_state = perk_state

	func get_instance(key: String) -> Object:
		if key == "runtime_perk_state":
			return runtime_perk_state
		return null


class FakeFeedback:
	var gauge_flash_count := 0

	func trigger_gauge_flash() -> void:
		gauge_flash_count += 1


func _init() -> void:
	var catalog: Object = MythicItemCatalog.new()
	var item_data: Dictionary = catalog.build_item_by_name("gold_digger")
	_expect(not item_data.is_empty(), "Gold Digger should build from catalog")
	_expect(str(item_data.get("slot", "")) == "arm", "Gold Digger should use the shared arm slot")
	_expect(str(item_data.get("display_name", "")) == "골드디거", "Gold Digger should keep Korean display name")
	_expect(ProjectResourceLoader.load_texture(str(item_data.get("icon_path", ""))) != null, "Gold Digger icon should load")
	_expect(_array_has_item(catalog.get_field_spawn_items(), "gold_digger"), "Gold Digger should be in passive field-spawn list")

	var roll_options: Array = catalog.get_roll_options("gold_digger")
	_expect(roll_options.size() == 1, "Gold Digger should have one roll option")
	var option: Dictionary = roll_options[0]
	_expect(str(option.get("key", "")) == "gold_bonus_pct", "Gold Digger roll key should match Python reference")
	_expect(is_equal_approx(float(option.get("min", 0.0)), 25.0), "Gold Digger roll min should be 25%")
	_expect(is_equal_approx(float(option.get("max", 0.0)), 50.0), "Gold Digger roll max should be 50%")
	_expect(is_equal_approx(float(option.get("default", 0.0)), 37.0), "Gold Digger default roll should be 37%")

	var runtime: Object = MythicItemRuntime.new()
	var perk_state: Object = RuntimePerkState.new()
	var registry := FakeRegistry.new(perk_state)
	var owner := FakeOwner.new()
	_expect(runtime.acquire_item("gold_digger", owner, registry, {"gold_bonus_pct": 25.0}, true, false) >= 0, "first Gold Digger should acquire and equip")
	_expect(runtime.acquire_item("gold_digger", owner, registry, {"gold_bonus_pct": 50.0}, true, false) >= 0, "second Gold Digger should acquire and equip")
	_expect(owner.equipment_slots.has("left_arm"), "first Gold Digger should resolve to left arm")
	_expect(owner.equipment_slots.has("right_arm"), "second Gold Digger should resolve to right arm")
	_expect(str(owner.equipment_slots["left_arm"].get("name", "")) == "gold_digger", "left arm should hold Gold Digger")
	_expect(str(owner.equipment_slots["right_arm"].get("name", "")) == "gold_digger", "right arm should hold Gold Digger")
	_expect(owner.gold_digger_equipped, "owner should expose Gold Digger equipped")
	_expect(owner.gold_digger_count == 2, "runtime should count both equipped Gold Diggers")
	_expect(is_equal_approx(owner.gold_digger_gold_bonus_pct, 75.0), "Gold Digger roll bonuses should stack from both arms")
	_expect(is_equal_approx(owner.gold_digger_multiplier, 1.75), "Gold Digger multiplier should stack from both arms")
	_expect(is_equal_approx(perk_state.get_item_gold_gain_multiplier(), 1.75), "runtime perk state should receive Gold Digger gold multiplier")
	_expect(runtime.apply_gold_digger_gold_bonus(100) == 175, "Gold Digger should boost direct gold by stacked multiplier")

	var feedback := FakeFeedback.new()
	var router: Object = PaddleBounceEventRouter.new()
	var gauge_after_hit: float = router.register_player_hit(
		Vector2(320.0, 680.0),
		0.0,
		false,
		false,
		100.0,
		{
			"selected_character_type": "soldier",
			"gauge_charge_per_hit": 50.0,
			"gauge_max": 500.0,
		},
		{
			"mythic_item_runtime": runtime,
			"feedback": feedback,
		}
	)
	_expect(is_equal_approx(gauge_after_hit, 187.0), "normal paddle-hit gauge should receive Gold Digger bonus")
	_expect(feedback.gauge_flash_count == 1, "Gold Digger boosted gauge gain should still trigger feedback")

	_expect(perk_state.award_gold(100) == 175, "runtime perk skill gold should receive Gold Digger bonus")
	_expect(perk_state.apply_choice({"id": "convert_to_gold", "gold_amount": 500}, owner, registry), "Gold conversion choice should apply")
	_expect(owner.runtime_perk_gold == 1050, "Gold conversion should receive Gold Digger bonus through runtime perk state")

	var field_spawn_controller: Object = ActiveItemFieldSpawnController.new()
	var candidate_names: Dictionary = field_spawn_controller.get_field_spawn_candidate_names()
	_expect(candidate_names.has("gold_digger"), "field spawn candidates should include Gold Digger")

	print("gold_digger_port_smoke: ok")
	quit(0)


func _array_has_item(items: Array, item_name: String) -> bool:
	for item_value in items:
		var item: Dictionary = item_value if item_value is Dictionary else {}
		if str(item.get("name", "")) == item_name:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
