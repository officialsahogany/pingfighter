extends SceneTree

const ActiveItemFieldSpawnPool := preload("res://scripts/items/active_item_field_spawn_pool.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const MythicItemRainbowFurGloveRuntime := preload("res://scripts/items/mythic_item_rainbow_fur_glove_runtime.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const SmasherSkillState := preload("res://scripts/characters/smasher_skill_state.gd")
const ViperSkillState := preload("res://scripts/characters/viper_skill_state.gd")


class FakeOwner:
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var accessory_slot_count := 2
	var runtime_accessory_slot_bonus := 0
	var runtime_perk_levels: Dictionary = {}
	var selected_character_type := "smasher"
	var player_pos := Vector2(300.0, 680.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var rainbow_fur_glove_equipped := false
	var rainbow_fur_glove_active := false
	var rainbow_fur_glove_trigger_chance_pct := 0.0
	var rainbow_fur_glove_cooldown_reduction_pct := 0.0
	var rainbow_fur_glove_context: Dictionary = {}

	func queue_redraw() -> void:
		pass


class FakeAudio:
	var rainbow_calls := 0
	var fallback_calls := 0

	func play_rainbow_fur_glove() -> void:
		rainbow_calls += 1

	func play_active_item() -> void:
		fallback_calls += 1


class FakeFeedback:
	var shake_calls := 0

	func max_screen_shake(_amount: float, _intensity: float) -> void:
		shake_calls += 1


class FakeRegistry:
	var mythic_item_runtime: Object
	var runtime_perk_state: Object
	var smasher_skill_state: Object
	var viper_skill_state: Object
	var game_audio: Object
	var battle_feedback_state: Object

	func _init(
		item_runtime: Object,
		perk_state: Object,
		smasher_state: Object = null,
		viper_state: Object = null,
		audio: Object = null,
		feedback: Object = null
	) -> void:
		mythic_item_runtime = item_runtime
		runtime_perk_state = perk_state
		smasher_skill_state = smasher_state
		viper_skill_state = viper_state
		game_audio = audio
		battle_feedback_state = feedback

	func get_instance(key: String) -> Object:
		match key:
			"mythic_item_runtime":
				return mythic_item_runtime
			"runtime_perk_state":
				return runtime_perk_state
			"smasher_skill_state":
				return smasher_skill_state
			"viper_skill_state":
				return viper_skill_state
			"game_audio":
				return game_audio
			"battle_feedback_state":
				return battle_feedback_state
		return null


func _init() -> void:
	_test_runtime_constant_ownership()
	var catalog := MythicItemCatalog.new()
	var item_data: Dictionary = catalog.build_item_by_name("rainbow_fur_glove")
	_expect(not item_data.is_empty(), "Rainbow Fur Glove should be registered in the passive catalog")
	_expect(str(item_data.get("slot", "")) == "arm", "Rainbow Fur Glove should use the arm slot")
	_expect(str(item_data.get("type", "")) == "passive", "Rainbow Fur Glove should be a passive item")
	_expect(abs(float(item_data.get("chance", 0.0)) - 0.004) <= 0.000001, "field chance should match Python")
	_expect(_array_has_item(catalog.get_field_spawn_items(), "rainbow_fur_glove"), "Rainbow Fur Glove should be in the field-spawn passive pool")
	_expect(_array_has_item(catalog.get_debug_items(), "rainbow_fur_glove"), "Rainbow Fur Glove should be in the debug passive pool")
	_expect(ProjectResourceLoader.load_texture("res://assets/sprites/items/rainbow_fur_glove.png") != null, "Rainbow Fur Glove icon should load from Godot assets")
	_expect(_roll_option_has_range(catalog, "rainbow_glove_trigger_chance_pct", 5.0, 10.0, 5.0), "trigger chance roll should match Python")
	_expect(_roll_option_has_range(catalog, "rainbow_glove_cooldown_reduction_pct", 30.0, 50.0, 30.0), "cooldown reduction roll should match Python")

	var runtime := MythicItemRuntime.new()
	var perk_state := RuntimePerkState.new()
	var smasher_state := SmasherSkillState.new()
	var viper_state := ViperSkillState.new()
	var audio := FakeAudio.new()
	var feedback := FakeFeedback.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(runtime, perk_state, smasher_state, viper_state, audio, feedback)
	var field_spawn_pool := ActiveItemFieldSpawnPool.new()
	_expect(
		field_spawn_pool.get_field_spawn_candidate_names(registry, owner).has("rainbow_fur_glove"),
		"shared field-spawn pool should expose Rainbow Fur Glove before ownership"
	)
	_expect(
		runtime.equip_item("rainbow_fur_glove", owner, registry, {
			"rainbow_glove_trigger_chance_pct": 100.0,
			"rainbow_glove_cooldown_reduction_pct": 50.0,
		}, false),
		"Rainbow Fur Glove should equip through mythic_item_runtime"
	)
	_expect(owner.rainbow_fur_glove_equipped, "owner sync should expose Rainbow Fur Glove equipped state")
	_expect(owner.rainbow_fur_glove_active, "owner sync should expose Rainbow Fur Glove active state")
	_expect_close(owner.rainbow_fur_glove_trigger_chance_pct, 100.0, "owner sync should expose the trigger chance")
	_expect_close(owner.rainbow_fur_glove_cooldown_reduction_pct, 50.0, "owner sync should expose the cooldown reduction")
	_expect(
		not field_spawn_pool.get_field_spawn_candidate_names(registry, owner).has("rainbow_fur_glove"),
		"owned Rainbow Fur Glove should be excluded from the one-time passive field pool"
	)

	var current_msec := 2000
	smasher_state.trigger_cooldown("drive", 1000, 10.0)
	viper_state.trigger_cooldown("shadow_step", 1000, 10.0)
	var proc_result: Dictionary = runtime.try_proc_rainbow_fur_glove_player_hit(
		Vector2(360.0, 650.0),
		{
			"current_time_msec": current_msec,
			"player_pos": owner.player_pos,
			"player_paddle_width": owner.player_paddle_width,
			"player_paddle_height": owner.player_paddle_height,
		},
		{"owner": owner, "registry": registry, "feedback": feedback}
	)
	_expect(bool(proc_result.get("activated", false)), "100% Rainbow Fur Glove should proc on player paddle hit")
	_expect_close(float(proc_result.get("cooldown_reduction_pct", 0.0)), 50.0, "proc result should expose the real reduction")
	_expect(
		int(proc_result.get("cooldown_states_changed", 0)) == 2,
		"proc should reduce all registered player skill cooldown states: got %d smasher=%s viper=%s" % [
			int(proc_result.get("cooldown_states_changed", 0)),
			str(smasher_state.get_cooldowns()),
			str(viper_state.get_cooldowns()),
		]
	)
	_expect_close(smasher_state.get_cooldown_remaining("drive", current_msec, 10.0), 0.4, "Smasher cooldown should be shortened by 50% of its total cooldown")
	_expect_close(viper_state.get_cooldown_remaining("shadow_step", current_msec, 10.0), 0.4, "Viper cooldown should be shortened by 50% of its total cooldown")
	_expect(audio.rainbow_calls == 1, "Rainbow Fur Glove audio should fire on proc")
	_expect(feedback.shake_calls == 1, "Rainbow Fur Glove proc should request a small feedback shake")
	var snapshot: Dictionary = runtime.get_snapshot()
	_expect(bool(snapshot.get("rainbow_fur_glove_effect_active", false)), "proc should expose an active rainbow aura snapshot")
	_expect(float(snapshot.get("rainbow_fur_glove_aura_timer_frames", 0.0)) > 0.0, "proc should start the aura timer")
	for _i in range(80):
		runtime.update(owner, registry, 1.0)
	_expect(not bool(runtime.get_snapshot().get("rainbow_fur_glove_effect_active", true)), "aura should clean itself up after its short runtime")

	_expect(runtime.unequip_item("rainbow_fur_glove", owner, registry), "Rainbow Fur Glove should unequip")
	_expect(not owner.rainbow_fur_glove_equipped, "owner sync should clear equipped state on unequip")
	_expect_close(runtime.get_rainbow_fur_glove_trigger_chance_pct(), 0.0, "unequipped trigger chance should be inactive")
	_expect_close(runtime.get_rainbow_fur_glove_cooldown_reduction_pct(), 0.0, "unequipped cooldown reduction should be inactive")

	var polish_state := RuntimePerkState.new()
	polish_state.runtime_skill_levels["item_polish"] = 2
	var polish_runtime := MythicItemRuntime.new()
	var polish_owner := FakeOwner.new()
	var polish_registry := FakeRegistry.new(polish_runtime, polish_state)
	_expect(
		polish_runtime.equip_item("rainbow_fur_glove", polish_owner, polish_registry, {
			"rainbow_glove_trigger_chance_pct": 8.0,
			"rainbow_glove_cooldown_reduction_pct": 40.0,
		}, false),
		"Rainbow Fur Glove should equip in the polish scaling path"
	)
	_expect_close(polish_runtime.get_rainbow_fur_glove_trigger_chance_pct(), 9.92, "Polish should boost trigger chance through the shared roll helper")
	_expect_close(polish_runtime.get_rainbow_fur_glove_cooldown_reduction_pct(), 49.6, "Polish should boost cooldown reduction through the shared roll helper")

	print("rainbow_fur_glove_port_smoke: ok")
	quit(0)


func _test_runtime_constant_ownership() -> void:
	_expect(is_equal_approx(MythicItemRainbowFurGloveRuntime.AURA_FRAMES, 36.0), "Rainbow Fur Glove helper should own aura timing")
	_expect(MythicItemRainbowFurGloveRuntime.PARTICLE_COUNT == 18, "Rainbow Fur Glove helper should own particle count")
	var runtime_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_runtime.gd")
	var helper_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_rainbow_fur_glove_runtime.gd")
	_expect(not runtime_source.contains("RAINBOW_FUR_GLOVE_CONSTANTS"), "runtime facade should not regain RAINBOW_FUR_GLOVE_CONSTANTS")
	_expect(not runtime_source.contains("const RAINBOW_FUR_GLOVE_MAX"), "runtime facade should not regain Rainbow Fur Glove cap constants")
	_expect(not runtime_source.contains("const RAINBOW_FUR_GLOVE_AURA"), "runtime facade should not regain Rainbow Fur Glove aura constants")
	_expect(not runtime_source.contains("const RAINBOW_FUR_GLOVE_COLORS"), "runtime facade should not regain Rainbow Fur Glove color constants")
	_expect(helper_source.contains("const MAX_COOLDOWN_REDUCTION_PCT"), "Rainbow Fur Glove helper should keep cooldown cap constants")


func _array_has_item(items: Array, item_name: String) -> bool:
	for item_value in items:
		if item_value is Dictionary and str(item_value.get("name", "")) == item_name:
			return true
	return false


func _roll_option_has_range(
	catalog: Object,
	option_key: String,
	minimum: float,
	maximum: float,
	default_value: float
) -> bool:
	for option_value in catalog.get_roll_options("rainbow_fur_glove"):
		if not (option_value is Dictionary):
			continue
		var option: Dictionary = option_value
		if str(option.get("key", "")) != option_key:
			continue
		return (
			abs(float(option.get("min", 0.0)) - minimum) <= 0.000001
			and abs(float(option.get("max", 0.0)) - maximum) <= 0.000001
			and abs(float(option.get("default", 0.0)) - default_value) <= 0.000001
		)
	return false


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
