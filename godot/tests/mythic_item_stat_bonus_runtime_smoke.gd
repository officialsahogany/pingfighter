extends SceneTree

const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const MythicItemStatBonusRuntime := preload("res://scripts/items/mythic_item_stat_bonus_runtime.gd")


class FakeOwner:
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var accessory_slot_count := 2
	var runtime_accessory_slot_bonus := 0
	var player_pos := Vector2(302.5, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var player_paddle_scale := 1.0
	var runtime_paddle_base_width := 155.0
	var runtime_paddle_base_height := 50.0
	var runtime_paddle_scale := 1.0
	var player_speed_multiplier := 1.0
	var player_turn_decel_multiplier := 1.0
	var bulkup_equipped := false
	var bulkup_body_size_pct := 0.0
	var bulkup_paddle_scale := 1.0
	var dashgear_equipped := false
	var dashgear_dash_distance_bonus_pct := 0.0
	var dashgear_boost_charge_chance_pct := 0.0
	var dashholder_equipped := false
	var dashholder_dash_token_bonus := 0
	var dash_token_capacity := 1
	var ai_mode := "champion"
	var starting_dash_tokens := 1

	func queue_redraw() -> void:
		pass


class FakeRegistry:
	var runtime: Object

	func _init(runtime_ref: Object) -> void:
		runtime = runtime_ref

	func get_instance(key: String) -> Object:
		if key == "mythic_item_runtime":
			return runtime
		return null


class FakeRuntimePerkState:
	func get_runtime_skill_bonus(skill_id: String) -> int:
		if skill_id == "dash_amplification":
			return 2
		return 0


func _init() -> void:
	_verify_runtime_constant_ownership()

	var runtime := MythicItemRuntime.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(runtime)

	_expect(
		runtime.equip_item("speedboots", owner, registry, {"speed_bonus_pct": 20.0}, false),
		"Speed Boots should equip for speed multiplier composition"
	)
	_expect_close(runtime.get_player_speed_multiplier(), 1.2, "Speed Boots should set the base speed lane")

	_expect(runtime.equip_item("speedgear", owner, registry, {}, false), "Speed Gear should equip")
	_expect_close(runtime.get_player_turn_decel_multiplier(), 2.5, "Speed Gear should own turn-decel stat lane")
	_expect_close(runtime.get_player_speed_multiplier(), 1.2, "Speed Gear should not change movement speed")

	var config := {}
	runtime.apply_player_movement_config(config)
	_expect(not bool(config.get("gravitybelt_instant_movement", true)), "Gravity Belt config should be inactive before equip")
	_expect(runtime.equip_item("gravitybelt", owner, registry, {}, false), "Gravity Belt should equip")
	config.clear()
	runtime.apply_player_movement_config(config)
	_expect(bool(config.get("gravitybelt_active", false)), "Gravity Belt should set active movement config")
	_expect(bool(config.get("gravitybelt_instant_movement", false)), "Gravity Belt should set instant movement config")

	_expect(
		runtime.equip_item("bulkup", owner, registry, {"body_size_pct": 15.0}, false),
		"Bulk-Up Suit should equip"
	)
	_expect(owner.bulkup_equipped, "owner sync should expose Bulk-Up equipped state")
	_expect_close(owner.bulkup_body_size_pct, 15.0, "owner sync should expose Bulk-Up roll")
	_expect_close(owner.player_paddle_width, 155.0 * 1.15, "owner sync should resize Bulk-Up paddle width")
	_expect_close(owner.player_paddle_height, 50.0 * 1.15, "owner sync should resize Bulk-Up paddle height")
	_expect_close(owner.player_paddle_scale, 1.15, "owner sync should resize Bulk-Up paddle draw scale")
	_expect_close(runtime.get_player_paddle_scale(), 1.15, "Bulk-Up should scale the paddle")
	_expect_close(runtime.get_player_paddle_width(100.0), 115.0, "Bulk-Up should scale paddle width")
	_expect_close(runtime.get_player_paddle_height(20.0), 23.0, "Bulk-Up should scale paddle height")

	_expect(
		runtime.equip_item("dashgear", owner, registry, {"dash_distance_pct": 50.0, "boost_charge_pct": 25.0}, false),
		"Dash Gear should equip"
	)
	_expect(owner.dashgear_equipped, "owner sync should expose Dash Gear equipped state")
	_expect_close(runtime.get_dashgear_dash_distance_bonus_pct(), 50.0, "Dash Gear should expose dash distance roll")
	_expect_close(runtime.get_dash_duration_frames(10.0), 15.0, "Dash Gear should scale dash duration frames")
	_expect_close(runtime.get_boost_charge_chance_pct(), 25.0, "Dash Gear should expose boost charge chance")

	_expect(runtime.equip_item("dashholder", owner, registry, {}, false), "Dash Holder should equip")
	_expect(owner.dashholder_equipped, "owner sync should expose Dash Holder equipped state")
	_expect(owner.dashholder_dash_token_bonus == 1, "Dash Holder should add one dash token")
	_expect(runtime.get_dash_token_capacity(1) == 2, "Dash Holder should raise base dash capacity")
	_expect(
		runtime.get_dash_token_capacity(1, FakeRuntimePerkState.new()) == 4,
		"Dash Holder should stack with runtime dash amplification"
	)
	var junior_runtime := MythicItemRuntime.new()
	var junior_owner := FakeOwner.new()
	junior_owner.ai_mode = "junior"
	junior_owner.starting_dash_tokens = 2
	var junior_registry := FakeRegistry.new(junior_runtime)
	_expect(junior_runtime.equip_item("dashholder", junior_owner, junior_registry, {}, false), "Dash Holder should equip in Junior League")
	_expect(junior_owner.dash_token_capacity == 3, "Dash Holder should stack on Junior League's two-token baseline")

	var gold_index: int = runtime.acquire_item("gold_bar", owner, registry, {}, false, false)
	_expect(gold_index >= 0, "Gold Bar should be acquirable without equipment slot")
	_expect_close(runtime.get_gold_bar_speed_multiplier(), 0.7, "Gold Bar should apply carried movement penalty")
	_expect_close(runtime.get_player_speed_multiplier(), 0.84, "Gold Bar should multiply the existing speed lane")
	_expect(runtime.get_gold_bar_total_sell_price() == 2000, "Gold Bar should expose total sell value")

	print("mythic_item_stat_bonus_runtime_smoke: ok")
	quit(0)


func _verify_runtime_constant_ownership() -> void:
	_expect(is_equal_approx(MythicItemStatBonusRuntime.SPEEDGEAR_TURN_DECEL_MULTIPLIER, 2.5), "stat bonus helper should own Speed Gear turn-decel multiplier")
	_expect(MythicItemStatBonusRuntime.GOLD_BAR_SELL_PRICE == 2000, "stat bonus helper should own Gold Bar sell price")
	_expect(is_equal_approx(MythicItemStatBonusRuntime.GOLD_BAR_SPEED_PENALTY_PCT, 30.0), "stat bonus helper should own Gold Bar speed penalty")
	var runtime_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_runtime.gd")
	var helper_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_stat_bonus_runtime.gd")
	_expect(runtime_source != "", "mythic runtime source should be readable")
	_expect(helper_source != "", "stat bonus helper source should be readable")
	_expect(not runtime_source.contains("STAT_BONUS_CONSTANTS"), "runtime facade should not regain STAT_BONUS_CONSTANTS")
	_expect(not runtime_source.contains("const SPEEDGEAR_TURN_DECEL"), "runtime facade should not regain Speed Gear stat constants")
	_expect(not runtime_source.contains("const GOLD_BAR_SELL"), "runtime facade should not regain Gold Bar sell constants")
	_expect(not runtime_source.contains("const GOLD_BAR_SPEED"), "runtime facade should not regain Gold Bar speed constants")
	_expect(helper_source.contains("const GOLD_BAR_SPEED_PENALTY_PCT"), "stat bonus helper should keep Gold Bar speed constants")


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
