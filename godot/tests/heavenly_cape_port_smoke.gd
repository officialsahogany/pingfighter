extends SceneTree

const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const MythicItemOwnerSyncer := preload("res://scripts/items/mythic_item_owner_syncer.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")
const ViperSkillConfig := preload("res://scripts/characters/viper_skill_config.gd")
const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")
const SmasherSkillOrbRenderer := preload("res://scripts/hud/smasher_skill_orb_renderer.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")


class FakeOwner:
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var heavenly_cape_equipped := false
	var heavenly_cape_skill_cooldown_reduction_pct := 0.0
	var heavenly_cape_skill_slot_bonus := 0
	var player_skill_max_slots := 5
	var player_skill_cooldown_multiplier := 1.0
	var redraw_queued := false

	func queue_redraw() -> void:
		redraw_queued = true


class FakeRegistry:
	var mythic_runtime: Object
	var perk_state: Object
	var smasher_config: Object
	var viper_config: Object

	func _init(
		new_runtime: Object,
		new_perk_state: Object,
		new_smasher_config: Object,
		new_viper_config: Object
	) -> void:
		mythic_runtime = new_runtime
		perk_state = new_perk_state
		smasher_config = new_smasher_config
		viper_config = new_viper_config

	func get_instance(key: String) -> Object:
		match key:
			"mythic_item_runtime":
				return mythic_runtime
			"runtime_perk_state":
				return perk_state
			"smasher_skill_config":
				return smasher_config
			"viper_skill_config":
				return viper_config
		return null


class SlotSyncRuntime:
	extends RefCounted

	var computed_slot_bonus := 0
	var slot_bonus_query_count := 0

	func get_player_skill_cooldown_multiplier() -> float:
		return 1.0

	func get_heavenly_cape_skill_slot_bonus() -> int:
		slot_bonus_query_count += 1
		return computed_slot_bonus

	func _get_instance(registry: Object, key: String) -> Object:
		if registry == null or not registry.has_method("get_instance"):
			return null
		return registry.get_instance(key)


func _init() -> void:
	var catalog: Object = MythicItemCatalog.new()
	var item_data: Dictionary = catalog.build_item_by_name("heavenly_cape")
	_expect(not item_data.is_empty(), "Heavenly Cape should exist in the mythic catalog")
	_expect(str(item_data.get("slot", "")) == "back", "Heavenly Cape should equip to the back slot")
	_expect(str(item_data.get("icon_sheet_path", "")) != "", "Heavenly Cape should use an animated icon sheet")
	_expect(int(item_data.get("icon_frame_count", 0)) == 32, "Heavenly Cape should expose 32 smooth icon frames")
	_expect(bool(item_data.get("icon_fill_slot", false)), "Heavenly Cape icon should fill the equipment slot")
	var icon_texture: Texture2D = ProjectResourceLoader.load_texture(str(item_data.get("icon_path", "")))
	_expect(icon_texture != null, "Heavenly Cape static icon should load")
	var icon_sheet: Texture2D = ProjectResourceLoader.load_texture(str(item_data.get("icon_sheet_path", "")))
	_expect(icon_sheet != null, "Heavenly Cape animated icon sheet should load")
	_expect(icon_sheet != null and icon_sheet.get_size() == Vector2(1024.0, 32.0), "Heavenly Cape icon sheet should be 32 smooth 32px frames")

	var character_runtime: Object = PlayerCharacterRuntime.new()
	var smasher_five_frame_key: String = character_runtime.get_skill_cluster_frame_texture_key("smasher", 5)
	var smasher_six_frame_key: String = character_runtime.get_skill_cluster_frame_texture_key("smasher", 6)
	var viper_five_frame_key: String = character_runtime.get_skill_cluster_frame_texture_key("viper", 5)
	var viper_six_frame_key: String = character_runtime.get_skill_cluster_frame_texture_key("viper", 6)
	_expect(str(smasher_five_frame_key) == "smasher_skill_cluster_frame_texture", "Smasher five-slot HUD frame key should stay stable")
	_expect(str(smasher_six_frame_key) == "", "Smasher Heavenly Cape HUD should use dynamic six-slot sockets until a matching retuned frame exists")
	_expect(str(viper_five_frame_key) == "viper_skill_cluster_frame_texture", "Viper five-slot HUD frame key should use the Viper frame")
	_expect(str(viper_six_frame_key) == "", "Viper Heavenly Cape HUD should use dynamic six-slot sockets until a matching retuned frame exists")
	_expect(ProjectResourceLoader.load_texture("res://assets/sprites/hud/player_skill_gauge_full_frame_165_33_5_imagegen_v1.png") is Texture2D, "Smasher five-slot skill-cluster frame should load")
	_expect(ProjectResourceLoader.load_texture("res://assets/sprites/hud/player_skill_gauge_full_frame_155_32_5_imagegen_v1.png") is Texture2D, "Viper five-slot skill-cluster frame should load")

	var orb_renderer: Object = SmasherSkillOrbRenderer.new()
	var viper_five_positions: Array = orb_renderer.get_slot_positions(Vector2(141.0, 559.0), 55.0, 1.0, {
		"max_slots": 5,
		"skill_orb_radius": 24.0,
		"gauge_gap": 28.0,
		"orb_radius_base": 55.0,
		"slot_base_angle": 155.0,
		"slot_angle_step": 32.0,
	})
	var expected_viper_first := Vector2(141.0, 559.0) + Vector2(cos(deg_to_rad(155.0)), sin(deg_to_rad(155.0))) * 107.0
	_expect(viper_five_positions.size() == 5, "Viper five-slot renderer layout should expose five positions")
	_expect(_vector_close(_get_vector2_from_array(viper_five_positions, 0), expected_viper_first, 0.05), "Viper five-slot renderer should use the Viper frame angle")
	var viper_six_positions: Array = orb_renderer.get_slot_positions(Vector2(141.0, 559.0), 55.0, 1.0, {
		"max_slots": 6,
		"skill_orb_radius": 24.0,
		"gauge_gap": 28.0,
		"orb_radius_base": 55.0,
		"slot_base_angle": 155.0,
		"slot_angle_step": 32.0,
	})
	var expected_viper_six_last := Vector2(141.0, 559.0) + Vector2(cos(deg_to_rad(304.0)), sin(deg_to_rad(304.0))) * 107.0
	_expect(viper_six_positions.size() == 6, "Viper Heavenly Cape renderer layout should expose six positions")
	_expect(_vector_close(_get_vector2_from_array(viper_six_positions, 5), expected_viper_six_last, 0.05), "Viper Heavenly Cape sixth slot should rotate leftward away from the playfield")

	var roll_option: Dictionary = _find_roll_option(catalog.get_roll_options("heavenly_cape"), "skill_cooldown_reduction")
	_expect(is_equal_approx(float(roll_option.get("min", 0.0)), 10.0), "Heavenly Cape cooldown roll should start at 10%")
	_expect(is_equal_approx(float(roll_option.get("max", 0.0)), 20.0), "Heavenly Cape cooldown roll should cap at 20%")
	_expect(is_equal_approx(float(roll_option.get("default", 0.0)), 15.0), "Heavenly Cape cooldown roll should default to 15%")
	_expect(_array_has_item(catalog.get_field_spawn_items(), "heavenly_cape"), "Heavenly Cape should be in the field-spawn mythic pool")

	var runtime: Object = MythicItemRuntime.new()
	var perk_state: Object = RuntimePerkState.new()
	var smasher_config: Object = SmasherSkillConfig.new()
	var viper_config: Object = ViperSkillConfig.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(runtime, perk_state, smasher_config, viper_config)

	_expect(
		runtime.equip_item("heavenly_cape", owner, registry, {"skill_cooldown_reduction": 20.0}, false),
		"Heavenly Cape should equip through mythic_item_runtime"
	)
	var snapshot: Dictionary = runtime.get_snapshot()
	_expect(bool(snapshot.get("heavenly_cape_equipped", false)), "snapshot should expose equipped Heavenly Cape")
	_expect(is_equal_approx(float(snapshot.get("heavenly_cape_skill_cooldown_reduction_pct", 0.0)), 20.0), "Heavenly Cape should expose its cooldown roll")
	_expect(int(snapshot.get("heavenly_cape_skill_slot_bonus", 0)) == 1, "Heavenly Cape should expose its +1 skill slot bonus")
	_expect(int(snapshot.get("player_skill_max_slots", 0)) == 6, "Heavenly Cape should raise player skill max slots to six")
	_expect(owner.heavenly_cape_equipped and owner.heavenly_cape_skill_slot_bonus == 1, "owner should receive Heavenly Cape sync")
	_expect(owner.equipment_slots.has("belt2"), "Heavenly Cape should appear in the Godot back equipment slot")
	_expect(not owner.equipment_slots.has("back"), "Heavenly Cape should not sync to the non-rendered legacy back slot")
	_expect(str(owner.equipment_slots["belt2"].get("_equipped_slot", "")) == "belt2", "synced Heavenly Cape item should expose the rendered back slot key")

	var smasher_snapshot: Dictionary = smasher_config.get_snapshot()
	var viper_snapshot: Dictionary = viper_config.get_snapshot()
	_expect(int(smasher_snapshot.get("max_slots", 0)) == 6, "Smasher skill config should receive the sixth slot")
	_expect(int(viper_snapshot.get("max_slots", 0)) == 6, "Viper skill config should receive the sixth slot")
	_expect(is_equal_approx(float(smasher_snapshot.get("cooldown_multiplier", 0.0)), 0.8), "Heavenly Cape should reduce skill cooldowns by its roll")
	var cooldowns: Dictionary = smasher_snapshot.get("cooldown_seconds", {})
	_expect(is_equal_approx(float(cooldowns.get("drive", 0.0)), 12.0), "Heavenly Cape should shorten live skill cooldown seconds")

	_expect(smasher_config.unlock_and_equip_skill("plasma"), "third skill should equip")
	_expect(smasher_config.unlock_and_equip_skill("recovery"), "fourth skill should equip")
	_expect(smasher_config.unlock_and_equip_skill("cleanse"), "fifth skill should equip")
	_expect(smasher_config.unlock_and_equip_skill("shield_kiting"), "Heavenly Cape sixth skill slot should accept one extra skill")
	_expect(not smasher_config.unlock_and_equip_skill("magnum_grip"), "Heavenly Cape should not open a seventh skill slot")
	perk_state.runtime_skill_levels["shield_kiting"] = 1

	_expect(
		runtime.equip_item("timer_belt", owner, registry, {"skill_cooldown_pct": 20.0}, false),
		"Timer Belt should still equip beside Heavenly Cape"
	)
	smasher_snapshot = smasher_config.get_snapshot()
	_expect(is_equal_approx(float(smasher_snapshot.get("cooldown_multiplier", 0.0)), 0.64), "Timer Belt and Heavenly Cape cooldown reductions should stack multiplicatively")

	_expect(runtime.unequip_item("heavenly_cape", owner, registry), "Heavenly Cape should unequip cleanly")
	smasher_snapshot = smasher_config.get_snapshot()
	_expect(int(smasher_snapshot.get("max_slots", 0)) == 5, "unequipping Heavenly Cape should restore five skill slots")
	_expect(_get_array(smasher_snapshot.get("equipped_skills", [])).size() == 5, "unequipping Heavenly Cape should trim the overflow skill")
	_expect(not perk_state.runtime_skill_levels.has("shield_kiting"), "trimmed sixth-slot skill should be removed from runtime perk levels")
	_verify_converted_slot_staleness_and_real_loss()

	print("heavenly_cape_port_smoke: ok")
	quit(0)


func _verify_converted_slot_staleness_and_real_loss() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	var vision_skill_id := CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_ID
	var vision_unlock_id := CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_UNLOCK_ID

	var stale_state := RuntimePerkState.new()
	stale_state.runtime_skill_levels = {
		"heavenly_cape": 1,
		vision_skill_id: 1,
		vision_unlock_id: 1,
	}
	var stale_config := _build_six_slot_smasher(vision_skill_id)
	var stale_runtime := SlotSyncRuntime.new()
	var stale_registry := FakeRegistry.new(stale_runtime, stale_state, stale_config, null)
	MythicItemOwnerSyncer.new().sync_skill_cooldown_to_configs(stale_runtime, stale_registry)
	print(
		"[ChosikSlotTrimTrace] phase=stage_clear_reward_apply sync_calls=%d computed_bonus=%d authoritative_cape_level=%d equipped=%d vision_owned=%s"
		% [
			stale_runtime.slot_bonus_query_count,
			stale_runtime.computed_slot_bonus,
			int(stale_state.runtime_skill_levels.get("heavenly_cape", 0)),
			(stale_config.get_snapshot().get("equipped_skills", []) as Array).size(),
			str(stale_state.runtime_skill_levels.has(vision_skill_id)),
		]
	)
	_expect(
		(stale_config.get_snapshot().get("equipped_skills", []) as Array).size() == 6,
		"a stale derived zero must not trim the sixth Chosik while Heavenly Cape remains authoritatively owned"
	)
	_expect(
		stale_state.runtime_skill_levels.has(vision_skill_id)
		and stale_state.runtime_skill_levels.has(vision_unlock_id),
		"stale slot synchronization must preserve both Vision Chosik ownership keys"
	)

	var lost_state := RuntimePerkState.new()
	lost_state.runtime_skill_levels = {
		vision_skill_id: 1,
		vision_unlock_id: 1,
	}
	var lost_config := _build_six_slot_smasher(vision_skill_id)
	var lost_runtime := SlotSyncRuntime.new()
	var lost_registry := FakeRegistry.new(lost_runtime, lost_state, lost_config, null)
	MythicItemOwnerSyncer.new().sync_skill_cooldown_to_configs(lost_runtime, lost_registry)
	print(
		"[ChosikSlotTrimTrace] phase=confirmed_cape_loss sync_calls=%d computed_bonus=%d authoritative_cape_level=%d equipped=%d"
		% [
			lost_runtime.slot_bonus_query_count,
			lost_runtime.computed_slot_bonus,
			int(lost_state.runtime_skill_levels.get("heavenly_cape", 0)),
			(lost_config.get_snapshot().get("equipped_skills", []) as Array).size(),
		]
	)
	_expect(
		(lost_config.get_snapshot().get("equipped_skills", []) as Array).size() == 5,
		"confirmed Heavenly Cape loss must still shrink equipped Chosik from six to five"
	)
	PerkConversionFlags.debug_set_enabled(false)


func _build_six_slot_smasher(vision_skill_id: String) -> Object:
	var config := SmasherSkillConfig.new()
	config.set_item_skill_slot_bonus(1)
	for skill_id in ["plasma", "recovery", "cleanse", vision_skill_id]:
		_expect(config.unlock_and_equip_skill(skill_id), "six-slot fixture must equip %s" % skill_id)
	return config


func _find_roll_option(options: Array, key: String) -> Dictionary:
	for option_value in options:
		if option_value is Dictionary and str(option_value.get("key", "")) == key:
			return option_value
	return {}


func _array_has_item(items: Array, item_name: String) -> bool:
	for item_value in items:
		if item_value is Dictionary and str(item_value.get("name", "")) == item_name:
			return true
	return false


func _get_array(value: Variant) -> Array:
	return value if value is Array else []


func _get_vector2_from_array(values: Array, index: int) -> Vector2:
	if index >= 0 and index < values.size() and values[index] is Vector2:
		return values[index]
	return Vector2.INF


func _vector_close(actual: Vector2, expected: Vector2, tolerance: float) -> bool:
	return actual.distance_to(expected) <= tolerance


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
