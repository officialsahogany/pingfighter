extends SceneTree

const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")


class FakeOwner:
	var selected_character_type := "smasher"
	var player_pos := Vector2(300.0, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var player_paddle_scale := 1.0
	var runtime_paddle_scale := 1.0
	var ball_pos := Vector2(380.0, 360.0)
	var ball_vel := Vector2(4.0, -5.0)
	var player_collision_cooldown := 0.0
	var boss_collision_cooldown := 0.0

	func queue_redraw() -> void:
		pass


class FakeRegistry:
	var runtime_perk_state: Object

	func _init(perk_state: Object) -> void:
		runtime_perk_state = perk_state

	func get_instance(key: String) -> Object:
		if key == "runtime_perk_state":
			return runtime_perk_state
		return null


func _init() -> void:
	var catalog := RuntimePerkCatalog.new()
	var caffeine_data: Dictionary = catalog.get_perk_data("item_caffeine")
	_expect(str(caffeine_data.get("name", "")) == "연효결", "catalog should register Effect-Prolonging Art")
	_expect(int(caffeine_data.get("max_level", 0)) == 5, "Caffeine should have five base levels")
	_expect(str(caffeine_data.get("tree", "")) == "item", "Caffeine should live in the item tree")

	var perk_state := RuntimePerkState.new()
	perk_state.runtime_skill_levels["item_caffeine"] = 2
	_expect_close(perk_state.get_runtime_skill_bonus("item_caffeine"), 0.60, "Lv.2 Caffeine bonus should match Python")
	_expect_close(perk_state.get_active_item_duration_multiplier(), 1.60, "Lv.2 duration multiplier should match Python")
	_expect_close(perk_state.get_active_item_duration_frames(600.0), 960.0, "duration helper should scale base frames")

	perk_state.runtime_skill_levels["item_caffeine"] = 5
	perk_state.item_perk_level_bonus = 1
	_expect(int(perk_state.get_runtime_skill_level("item_caffeine")) == 6, "effective Lv.6 Caffeine should keep scaling")
	_expect_close(perk_state.get_active_item_duration_multiplier(), 2.80, "effective Lv.6 duration multiplier should stay uncapped")
	_expect_close(perk_state.get_active_item_duration_frames(600.0), 1680.0, "effective Lv.6 duration frames should stay uncapped")

	perk_state.item_perk_level_bonus = 0
	perk_state.runtime_skill_levels["item_caffeine"] = 2
	var registry := FakeRegistry.new(perk_state)
	var owner := FakeOwner.new()

	var vitamin_effects := ActiveItemEffectController.new()
	_expect(vitamin_effects.activate_vitamin_pill(owner, registry), "Vitamin Drink should activate")
	_expect_close(vitamin_effects.vitamin_pill_initial_timer_frames, 960.0, "Caffeine should extend Vitamin Drink")
	_expect_close(vitamin_effects.vitamin_pill_timer_frames, 960.0, "Vitamin Drink timer should start from the extended duration")

	var long_effects := ActiveItemEffectController.new()
	_expect(long_effects.activate_long_boost(owner, registry), "Giant Potion should activate")
	_expect_close(long_effects.long_boost_initial_timer_frames, 768.0, "Caffeine should extend Giant Potion")

	var strange_effects := ActiveItemEffectController.new()
	_expect(strange_effects.activate_strange_vial(owner, registry), "Strange Vial should activate")
	_expect_close(strange_effects.strange_vial_initial_timer_frames, 960.0, "Caffeine should extend Strange Vial")

	var magnet_effects := ActiveItemEffectController.new()
	_expect(magnet_effects.activate_magnet_field(owner, registry), "Magnet Field should activate")
	_expect_close(magnet_effects.magnet_field_initial_timer_frames, 768.0, "Caffeine should extend Magnet Field")

	var barrier_effects := ActiveItemEffectController.new()
	_expect(barrier_effects.activate_holy_barrier(owner, registry), "Holy Barrier should activate")
	_expect_close(barrier_effects.holy_barrier_initial_timer_frames, 576.0, "Caffeine should extend Holy Barrier")

	print("item_caffeine_perk_port_smoke: ok")
	quit(0)


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
