extends SceneTree

const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const WeatherEventState := preload("res://scripts/stages/common/weather_event_state.gd")
const BAAL_TRIGGER_SECONDS := 2.51


class FakeOwner:
	var current_stage := 1
	var ai_mode := "champion"
	var arena_mode_enabled := false
	var weather_type := ""
	var weather_event_active := false
	var weather_event_context: Dictionary = {}
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var baal_boots_equipped := false
	var baal_boots_active := false
	var baal_boots_context: Dictionary = {}
	var megingjord_equipped := false
	var dowsing_pendulum_equipped := false
	var dowsing_pendulum_range := 0.0
	var dowsing_pendulum_context: Dictionary = {}
	var slot_add_equipped := false
	var active_item_slot_capacity_bonus := 0
	var active_item_slot_capacity := 3
	var player_pos := Vector2(302.0, 700.0)
	var boss_pos := Vector2(330.0, 25.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0
	var special_gauge := 0.0
	var special_gauge_max := 500.0


class FakeAudio:
	var active_count := 0
	var pulse_count := 0

	func play_soul_burst_dash() -> void:
		active_count += 1

	func play_shield_kiting_hit() -> void:
		pulse_count += 1

	func play_active_item() -> void:
		active_count += 1


class FakeFeedback:
	var shake_amount := 0.0
	var gauge_flash_count := 0

	func max_screen_shake(amount: float, _intensity: float) -> void:
		shake_amount = max(shake_amount, amount)

	func set_screen_shake(amount: float, _intensity: float) -> void:
		shake_amount = max(shake_amount, amount)

	func trigger_gauge_flash() -> void:
		gauge_flash_count += 1


class FakeRegistry:
	var instances: Dictionary = {}

	func _init(source_instances: Dictionary) -> void:
		instances = source_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	_verify_catalog_and_asset()
	_verify_rain_absorb_flow()
	_verify_sand_absorb_same_frame_clear()

	print("baal_boots_weather_port_smoke: ok")
	quit(0)


func _verify_catalog_and_asset() -> void:
	var catalog: Object = MythicItemCatalog.new()
	var item: Dictionary = catalog.build_item_by_name("baal_boots")
	_expect(not item.is_empty(), "Baal's Boots should be registered in the mythic catalog")
	_expect(str(item.get("display_name", "")) == "바알의 부츠", "Baal's Boots should expose the Korean display name")
	_expect(str(item.get("slot", "")) == "shoes", "Baal's Boots should occupy the shoes equipment slot")
	var roll_option: Dictionary = _find_roll_option(item, "gauge_recovery")
	_expect(is_equal_approx(float(roll_option.get("min", 0.0)), 300.0), "gauge recovery roll should start at 300")
	_expect(is_equal_approx(float(roll_option.get("max", 0.0)), 500.0), "gauge recovery roll should cap at 500")
	_expect(is_equal_approx(float(roll_option.get("default", 0.0)), 400.0), "gauge recovery default should be 400")
	_expect(_array_has_item(catalog.get_field_spawn_items(), "baal_boots"), "Baal's Boots should be in the mythic field-spawn pool")
	_expect(int(item.get("icon_frame_count", 0)) == 32, "Baal's Boots should expose 32 smooth icon frames")
	_expect_original_icon_assets(item, "Baal's Boots")


func _verify_rain_absorb_flow() -> void:
	var owner := FakeOwner.new()
	var weather: Object = WeatherEventState.new()
	var runtime: Object = MythicItemRuntime.new()
	var audio := FakeAudio.new()
	var feedback := FakeFeedback.new()
	var registry := FakeRegistry.new({
		"weather_event_state": weather,
		"game_audio": audio,
		"battle_feedback_state": feedback,
	})

	weather.force_start_weather_event("rain", 1, 1, owner, registry)
	_expect(runtime.equip_item("baal_boots", owner, registry, {"gauge_recovery": 400.0}, false), "Baal's Boots should equip through mythic runtime")
	_expect(str(owner.equipment_slots.get("shoes", {}).get("name", "")) == "baal_boots", "Baal's Boots should sync into the shoes slot")
	_expect(str(runtime.get_baal_boots_context().get("pending_weather_type", "")) == "rain", "active rain should arm Baal's Boots")

	runtime.update(owner, registry, BAAL_TRIGGER_SECONDS)
	_expect(not bool(weather.is_weather_active()), "Baal absorb should force-end the source weather immediately after capturing it")
	_expect(runtime.should_pause_game(), "Baal absorb should pause gameplay during the absorb cinematic")
	_expect(str(owner.weather_type) == "", "source weather type should be cleared on the owner when absorbed")

	runtime.update(owner, registry, 1.0)
	var context: Dictionary = runtime.get_baal_boots_context()
	_expect(bool(context.get("round_effect_active", false)), "Baal's Boots should activate the absorbed weather effect after the cinematic")
	_expect(str(context.get("round_weather_type", "")) == "rain", "absorbed rain should become the round effect")
	_expect(is_equal_approx(float(owner.special_gauge), 400.0), "Baal's Boots should recover the rolled gauge amount")
	_expect(feedback.gauge_flash_count >= 1, "Baal gauge recovery should trigger gauge feedback")

	runtime.apply_baal_boots_player_hit(
		Vector2(380.0, 650.0),
		Vector2(0.0, -9.0),
		{
			"boss_pos": owner.boss_pos,
			"boss_paddle_size": Vector2(owner.boss_paddle_width, owner.boss_hitbox_height),
		},
		{"registry": registry, "feedback": feedback}
	)
	for _i in range(90):
		runtime.update(owner, registry, 1.0 / 60.0)
	_expect(bool(runtime.get_boss_ai_context().get("baal_boots_boss_slow_active", false)), "absorbed rain projectiles should slow the boss after contact")
	_expect(is_equal_approx(float(runtime.get_boss_ai_context().get("baal_boots_boss_slow_multiplier", 0.0)), 0.70), "rain slow multiplier should match the Python value")


func _verify_sand_absorb_same_frame_clear() -> void:
	var owner := FakeOwner.new()
	var weather: Object = WeatherEventState.new()
	var runtime: Object = MythicItemRuntime.new()
	var registry := FakeRegistry.new({
		"weather_event_state": weather,
		"game_audio": FakeAudio.new(),
		"battle_feedback_state": FakeFeedback.new(),
	})

	_expect(runtime.equip_item("baal_boots", owner, registry, {"gauge_recovery": 400.0}, false), "Baal's Boots should equip for the sand absorb test")
	weather.force_start_weather_event("sand", 1, 1, owner, registry)
	var built_depth: float = float(weather.get_sand_total_depth())
	_expect(built_depth > 0.0, "sand weather should create terrain before Baal absorb")
	runtime.on_weather_round_start(owner, registry, "sand")
	runtime.update(owner, registry, BAAL_TRIGGER_SECONDS)
	_expect(not bool(weather.is_weather_active()), "sand source weather should be inactive as soon as Baal absorb starts")
	_expect(float(weather.get_sand_total_depth()) <= 0.001, "sand terrain should be zeroed on the absorb-start frame")
	_expect(float(runtime.get_baal_boots_context().get("sand_absorbed_total", 0.0)) >= built_depth * 0.95, "Baal should remember the absorbed sand amount before clearing terrain")
	runtime.update(owner, registry, 1.0)
	_expect(float(weather.get_sand_total_depth()) > 0.0, "absorbed sand should rebuild Baal's defensive mound after the cinematic")


func _array_has_item(items: Array, item_name: String) -> bool:
	for item_value in items:
		if item_value is Dictionary and str(item_value.get("name", "")) == item_name:
			return true
	return false


func _find_roll_option(item_data: Dictionary, key: String) -> Dictionary:
	for option_value in item_data.get("roll_options", []):
		if option_value is Dictionary and str(option_value.get("key", "")) == key:
			return option_value
	return {}


func _expect_original_icon_assets(item_data: Dictionary, item_label: String) -> void:
	var icon: Texture2D = ProjectResourceLoader.load_texture(str(item_data.get("icon_path", "")))
	_expect(icon != null, "%s static icon should load" % item_label)
	if icon != null:
		_expect(icon.get_width() == 32 and icon.get_height() == 32, "%s static icon should be the original 32px render" % item_label)

	var sheet: Texture2D = ProjectResourceLoader.load_texture(str(item_data.get("icon_sheet_path", "")))
	_expect(sheet != null, "%s animated icon sheet should load" % item_label)
	if sheet != null:
		_expect(sheet.get_width() == 1024 and sheet.get_height() == 32, "%s animated icon sheet should be the smooth 32-frame render" % item_label)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
