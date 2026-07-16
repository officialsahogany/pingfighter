extends SceneTree

const BattleSceneState := preload("res://scripts/core/battle_scene_state.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")


class FakeOwner:
	extends RefCounted

	var values: Dictionary = {
		"equipment_slots": {},
		"passive_item_inventory": [],
		"passive_item_slots": {},
		"equipped_passive_items": {},
		"mythic_item_state": {},
		"special_gauge": 500.0,
		"special_gauge_max": 500.0,
		"starting_dash_tokens": 3,
		"player_pos": Vector2(300.0, 700.0),
		"player_paddle_width": 155.0,
		"player_paddle_height": 50.0,
	}

	func _get(property: StringName) -> Variant:
		return values.get(String(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		values[String(property)] = value
		return true

	func queue_redraw() -> void:
		pass


class FakeRegistry:
	extends RefCounted

	func get_instance(_key: String) -> Object:
		return null


var _failures: Array[String] = []


func _init() -> void:
	_verify_schema_keys()
	_verify_catalog_registration()
	_verify_runtime_state_contract()

	if _failures.is_empty():
		print("odins_eye_catalog_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_schema_keys() -> void:
	for key in [
		"odins_eye_equipped",
		"odins_eye_available",
		"odins_eye_revival_used",
		"odins_eye_penalty_active",
		"odins_eye_revival_animation_active",
		"odins_eye_death_animation_active",
		"odins_eye_context",
		"odins_eye_dash_token_limit",
		"odins_eye_dash_cooldown_multiplier",
		"odins_eye_death_phase",
		"odins_eye_death_overall_progress",
		"odins_eye_death_phase_progress",
		"odins_eye_death_energy_buildup",
		"odins_eye_death_disintegrate_progress",
		"odins_eye_death_shake_intensity",
		"odins_eye_hide_player_paddle",
	]:
		_expect(BattleSceneState.DEFAULT_VALUES.has(key), "BattleSceneState should declare %s" % key)


func _verify_catalog_registration() -> void:
	var catalog: Object = MythicItemCatalog.new()
	var item_data: Dictionary = catalog.build_item_by_name("odins_eye")
	_expect(not item_data.is_empty(), "Odin's Eye should build from catalog")
	_expect(str(item_data.get("slot", "")) == "belt", "Odin's Eye should use the belt slot")
	_expect(str(item_data.get("rarity", "")) == "mythic", "Odin's Eye should be a Godot mythic item")
	_expect(str(item_data.get("display_name", "")) == "오딘의 눈", "Odin's Eye should expose Korean display name")
	_expect(str(item_data.get("icon_path", "")) == "res://assets/sprites/items/odins_eye.png", "Odin's Eye static icon path should be reserved")
	_expect(str(item_data.get("icon_sheet_path", "")) == "res://assets/sprites/items/odins_eye_icon_sheet.png", "Odin's Eye mythic sheet path should be reserved")
	_verify_icon_asset(str(item_data.get("icon_path", "")), Vector2(32.0, 32.0), "Odin's Eye static icon")
	_verify_icon_asset(str(item_data.get("icon_sheet_path", "")), Vector2(1024.0, 32.0), "Odin's Eye mythic icon sheet")
	_expect(_catalog_has_item(catalog.get_field_spawn_items(), "odins_eye"), "Odin's Eye should be in the field spawn pool")
	_expect(_catalog_has_item(catalog.get_debug_items(), "odins_eye"), "Odin's Eye should be in the debug item list")

	var rolls: Array = catalog.get_roll_options("odins_eye")
	_expect(rolls.size() == 1, "Odin's Eye should expose one roll option")
	var revival_roll: Dictionary = _find_roll(rolls, "revival_chance")
	_expect(not revival_roll.is_empty(), "Odin's Eye should expose revival_chance roll")
	_expect(is_equal_approx(float(revival_roll.get("min", 0.0)), 30.0), "revival_chance min should match Python")
	_expect(is_equal_approx(float(revival_roll.get("max", 0.0)), 45.0), "revival_chance max should match Python")
	_expect(is_equal_approx(float(revival_roll.get("default", 0.0)), 35.0), "revival_chance default should match Python")

	var fixed_options: Array = catalog.get_fixed_options("odins_eye")
	_expect(fixed_options.size() == 3, "Odin's Eye should expose three fixed penalty options")


func _verify_runtime_state_contract() -> void:
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var runtime: Object = MythicItemRuntime.new()
	_expect(runtime.get_dash_recharge_frames(120.0) == 120.0, "untriggered Odin's Eye should not affect dash recharge")
	_expect(
		runtime.equip_item("odins_eye", owner, registry, {"revival_chance": 45.0}, false),
		"Odin's Eye should equip"
	)
	_expect(owner.values["equipment_slots"].has("belt"), "Odin's Eye should sync into the belt slot")
	_expect(str(owner.values["equipment_slots"]["belt"].get("name", "")) == "odins_eye", "belt slot should contain Odin's Eye")
	_expect(runtime.is_odins_eye_equipped(), "Odin's Eye should report equipped")
	_expect(runtime.is_odins_eye_available(), "Odin's Eye should be available before first revival")
	_expect(is_equal_approx(runtime.get_odins_eye_revival_chance_pct(), 45.0), "Odin's Eye should read equipped revival chance roll")

	_expect(not runtime.try_trigger_odins_eye_revival("round", 50.0), "roll above chance should not trigger Odin's Eye")
	var failed_context: Dictionary = runtime.get_odins_eye_context()
	_expect(is_equal_approx(float(failed_context.get("last_trigger_roll_pct", 0.0)), 50.0), "failed roll should be recorded")
	_expect(not bool(failed_context.get("last_triggered", true)), "failed roll should record triggered=false")
	_expect(runtime.is_odins_eye_available(), "failed roll should not consume Odin's Eye")

	_expect(runtime.try_trigger_odins_eye_revival("round", 20.0), "roll below chance should trigger Odin's Eye")
	# 라이브 무장값 씰: try_trigger가 리터럴(구 3.0)이 아니라 state 상수로
	# 무장해야 한다 — 리터럴 드리프트는 3.75 재타이밍을 조용히 무효화한다.
	_expect(is_equal_approx(float(runtime.odins_eye_state.revival_timer_sec), 3.75), "try_trigger must arm the 3.75s audio-sync revival timer (not a stale literal)")
	_expect(runtime.is_odins_eye_revival_animation_active(), "trigger should enter revival animation")
	_expect(runtime.is_odins_eye_penalty_active(), "trigger should immediately enable penalty")
	_expect(not runtime.is_odins_eye_available(), "trigger should consume availability")
	_expect(is_equal_approx(runtime.get_odins_eye_move_speed_multiplier(), 0.5), "penalty should halve movement speed")
	_expect(int(runtime.get_odins_eye_dash_token_limit_override()) == 1, "penalty should cap dash tokens to one")
	_expect(is_equal_approx(runtime.get_odins_eye_dash_cooldown_multiplier(), 2.0), "penalty should double dash cooldown")
	_expect(is_equal_approx(runtime.get_dash_recharge_frames(120.0), 240.0), "dash recharge hook should consume Odin's penalty multiplier")
	_expect(runtime.get_dash_token_capacity(3) == 1, "dash token capacity hook should consume Odin's penalty limit")

	runtime.odins_eye_runtime.update_runtime(runtime, 225.0)
	_expect(runtime.consume_odins_eye_revival_finalize_ready(), "revival update should expose one finalize edge")
	_expect(not runtime.consume_odins_eye_revival_finalize_ready(), "revival finalize edge should be one-shot")
	_expect(runtime.is_odins_eye_penalty_active(), "revival finalize should keep penalty active")
	_expect(runtime.is_odins_eye_transformed(), "penalty state should expose transformed=true")

	_expect(runtime.begin_odins_eye_death_sequence("round"), "penalty loss should be able to begin Odin's death sequence")
	_expect(runtime.is_odins_eye_death_animation_active(), "death sequence should enter death animation")
	runtime.odins_eye_runtime.update_runtime(runtime, 132.0)
	_expect(not runtime.consume_odins_eye_death_finalize_ready(), "death should not finalize before the 4.5s audio-aligned event")
	runtime.odins_eye_runtime.update_runtime(runtime, 140.0)
	_expect(runtime.consume_odins_eye_death_finalize_ready(), "death update should expose one finalize edge")
	_expect(not runtime.is_odins_eye_penalty_active(), "death finalize should clear penalty")

	runtime.clear_odins_eye_after_victory()
	_expect(not runtime.has_odins_eye_revival_used(), "victory clear should reset revival usage")


func _verify_icon_asset(path: String, expected_size: Vector2, label: String) -> void:
	var texture: Texture2D = ProjectResourceLoader.load_texture(path)
	_expect(texture != null, "%s should load through ProjectResourceLoader" % label)
	if texture == null:
		return
	_expect(texture.get_size() == expected_size, "%s should have size %s" % [label, expected_size])


func _catalog_has_item(items: Array, item_name: String) -> bool:
	for item_value in items:
		var item_data: Dictionary = item_value if item_value is Dictionary else {}
		if str(item_data.get("name", "")) == item_name:
			return true
	return false


func _find_roll(rolls: Array, key: String) -> Dictionary:
	for roll_value in rolls:
		var roll_data: Dictionary = roll_value if roll_value is Dictionary else {}
		if str(roll_data.get("key", "")) == key:
			return roll_data
	return {}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
