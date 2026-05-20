extends SceneTree

const ActiveItemFieldSpawnPool := preload("res://scripts/items/active_item_field_spawn_pool.gd")
const BossAIState := preload("res://scripts/ai/boss_ai_state.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const PaddleBouncePostHitHandler := preload("res://scripts/ball/paddle_bounce_post_hit_handler.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")


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
	var special_gauge := 100.0
	var special_gauge_max := 500.0
	var player_pos := Vector2(300.0, 680.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var boss_pos := Vector2(335.0, 70.0)
	var boss_paddle_size := Vector2(100.0, 40.0)
	var shrapnel_armor_equipped := false
	var shrapnel_armor_active := false
	var shrapnel_armor_trigger_chance_pct := 0.0
	var shrapnel_armor_shard_count := 0
	var shrapnel_armor_knockback_level := 0
	var shrapnel_armor_gauge_cost := 0.0
	var shrapnel_armor_context: Dictionary = {}

	func queue_redraw() -> void:
		pass


class FakeAudio:
	var fire_calls := 0
	var hit_calls := 0
	var fallback_calls := 0

	func play_shrapnel_armor_fire() -> void:
		fire_calls += 1

	func play_shrapnel_armor_hit() -> void:
		hit_calls += 1

	func play_active_item() -> void:
		fallback_calls += 1


class FakeFeedback:
	var shake_calls := 0
	var gauge_flash_calls := 0

	func max_screen_shake(_amount: float, _intensity: float) -> void:
		shake_calls += 1

	func trigger_gauge_flash() -> void:
		gauge_flash_calls += 1


class FakeRegistry:
	var mythic_item_runtime: Object
	var runtime_perk_state: Object
	var game_audio: Object
	var battle_feedback_state: Object

	func _init(
		item_runtime: Object,
		perk_state: Object = null,
		audio: Object = null,
		feedback: Object = null
	) -> void:
		mythic_item_runtime = item_runtime
		runtime_perk_state = perk_state
		game_audio = audio
		battle_feedback_state = feedback

	func get_instance(key: String) -> Object:
		match key:
			"mythic_item_runtime":
				return mythic_item_runtime
			"runtime_perk_state":
				return runtime_perk_state
			"game_audio":
				return game_audio
			"battle_feedback_state":
				return battle_feedback_state
		return null


func _init() -> void:
	var catalog := MythicItemCatalog.new()
	var item_data: Dictionary = catalog.build_item_by_name("shrapnel_armor")
	_expect(not item_data.is_empty(), "Shrapnel Armor should be registered in the passive catalog")
	_expect(str(item_data.get("display_name", "")) == "파편갑옷", "Shrapnel Armor should keep Korean display name")
	_expect(str(item_data.get("slot", "")) == "top", "Shrapnel Armor should use the top slot")
	_expect(str(item_data.get("type", "")) == "passive", "Shrapnel Armor should be a passive item")
	_expect(abs(float(item_data.get("chance", 0.0)) - 0.004) <= 0.000001, "field chance should match Python")
	_expect(_array_has_item(catalog.get_field_spawn_items(), "shrapnel_armor"), "Shrapnel Armor should be in the field-spawn passive pool")
	_expect(_array_has_item(catalog.get_debug_items(), "shrapnel_armor"), "Shrapnel Armor should be in the debug passive pool")
	_expect(ProjectResourceLoader.load_texture("res://assets/sprites/items/shrapnel_armor.png") != null, "Shrapnel Armor icon should load from Godot assets")
	_expect_shrapnel_rolls(catalog)

	var runtime := MythicItemRuntime.new()
	var perk_state := RuntimePerkState.new()
	var audio := FakeAudio.new()
	var feedback := FakeFeedback.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(runtime, perk_state, audio, feedback)
	var field_spawn_pool := ActiveItemFieldSpawnPool.new()
	_expect(
		field_spawn_pool.get_field_spawn_candidate_names(registry, owner).has("shrapnel_armor"),
		"shared field-spawn pool should expose Shrapnel Armor before ownership"
	)
	_expect(
		runtime.equip_item("shrapnel_armor", owner, registry, {
			"trigger_chance_pct": 100.0,
			"shard_count": 6.0,
			"knockback_level": 2.0,
			"gauge_cost": 35.0,
		}, false),
		"Shrapnel Armor should equip through mythic_item_runtime"
	)
	_expect(owner.equipment_slots.has("top"), "Shrapnel Armor should sync to the top slot")
	_expect(str(owner.equipment_slots["top"].get("name", "")) == "shrapnel_armor", "top slot should contain Shrapnel Armor")
	_expect(owner.shrapnel_armor_equipped, "owner sync should expose Shrapnel Armor equipped state")
	_expect(owner.shrapnel_armor_active, "owner sync should expose Shrapnel Armor active state")
	_expect_close(owner.shrapnel_armor_trigger_chance_pct, 100.0, "owner sync should expose trigger chance")
	_expect(owner.shrapnel_armor_shard_count == 6, "owner sync should expose shard count")
	_expect(owner.shrapnel_armor_knockback_level == 2, "owner sync should expose knockback level")
	_expect_close(owner.shrapnel_armor_gauge_cost, 35.0, "owner sync should expose gauge cost")
	_expect(
		field_spawn_pool.get_field_spawn_candidate_names(registry, owner).has("shrapnel_armor"),
		"owned Shrapnel Armor should remain in the field pool because Python allows duplicates"
	)

	var proc_context := {
		"special_gauge": owner.special_gauge,
		"player_pos": owner.player_pos,
		"player_paddle_width": owner.player_paddle_width,
		"player_paddle_height": owner.player_paddle_height,
	}
	var proc_result: Dictionary = runtime.try_proc_shrapnel_armor_player_hit(
		Vector2(360.0, 650.0),
		proc_context,
		{"owner": owner, "registry": registry, "feedback": feedback}
	)
	_expect(bool(proc_result.get("activated", false)), "100% Shrapnel Armor should proc on player paddle hit")
	_expect_close(owner.special_gauge, 65.0, "proc should spend gauge from the owner")
	_expect_close(float(proc_context.get("special_gauge", 0.0)), 65.0, "proc should mutate context gauge")
	_expect(int(proc_result.get("shard_count", 0)) == 6, "proc result should expose shard count")
	_expect(audio.fire_calls == 1, "Shrapnel Armor fire audio should play on proc")
	_expect(feedback.shake_calls == 1, "Shrapnel Armor proc should request feedback shake")
	var snapshot: Dictionary = runtime.get_snapshot()
	_expect(bool(snapshot.get("shrapnel_armor_effect_active", false)), "proc should expose active shard VFX")
	_expect(int(snapshot.get("shrapnel_armor_active_shards", 0)) == 6, "proc should create the rolled number of shards")

	runtime.reset_round(registry)
	owner.special_gauge = 100.0
	var post_hit_handler := PaddleBouncePostHitHandler.new()
	var proc_post_hit_context := _build_post_hit_context(owner, 50.0)
	var proc_post_hit_result: Dictionary = post_hit_handler.apply(
		true,
		Vector2(360.0, 650.0),
		Vector2(0.0, -12.0),
		0.0,
		owner.player_paddle_width,
		false,
		false,
		false,
		0.0,
		0.0,
		false,
		false,
		owner.special_gauge,
		proc_post_hit_context,
		{"mythic_item_runtime": runtime, "registry": registry, "feedback": feedback}
	)
	_expect_close(
		float(proc_post_hit_result.get("special_gauge", -1.0)),
		115.0,
		"post-hit Shrapnel Armor should spend gauge without wiping the normal paddle-hit charge"
	)
	_expect(bool(proc_post_hit_result.get("shrapnel_armor_activated", false)), "post-hit route should expose Shrapnel Armor activation")

	runtime.reset_round(registry)
	owner.special_gauge = 0.0
	var low_gain_context := _build_post_hit_context(owner, 30.0)
	var low_gain_result: Dictionary = post_hit_handler.apply(
		true,
		Vector2(360.0, 650.0),
		Vector2(0.0, -12.0),
		0.0,
		owner.player_paddle_width,
		false,
		false,
		false,
		0.0,
		0.0,
		false,
		false,
		owner.special_gauge,
		low_gain_context,
		{"mythic_item_runtime": runtime, "registry": registry, "feedback": feedback}
	)
	_expect_close(
		float(low_gain_result.get("special_gauge", -1.0)),
		30.0,
		"insufficient Shrapnel Armor proc should preserve normal paddle-hit gauge gain"
	)
	_expect(not bool(low_gain_result.get("shrapnel_armor_activated", false)), "low-gauge post-hit route should not activate Shrapnel Armor")

	runtime.reset_round(registry)
	owner.special_gauge = 10.0
	var low_gauge_context := {"special_gauge": owner.special_gauge, "player_pos": owner.player_pos}
	var low_gauge_result: Dictionary = runtime.try_proc_shrapnel_armor_player_hit(
		Vector2(360.0, 650.0),
		low_gauge_context,
		{"owner": owner, "registry": registry}
	)
	_expect(not bool(low_gauge_result.get("activated", false)), "Shrapnel Armor should fail when gauge is insufficient")
	_expect_close(owner.special_gauge, 10.0, "failed low-gauge proc should not spend gauge")

	_expect(
		runtime.equip_item("shrapnel_armor", owner, registry, {
			"trigger_chance_pct": 0.0,
			"shard_count": 6.0,
			"knockback_level": 2.0,
			"gauge_cost": 35.0,
		}, false),
		"Shrapnel Armor should update roll overrides"
	)
	owner.special_gauge = 100.0
	var zero_chance_result: Dictionary = runtime.try_proc_shrapnel_armor_player_hit(
		Vector2(360.0, 650.0),
		{"special_gauge": owner.special_gauge, "player_pos": owner.player_pos},
		{"owner": owner, "registry": registry}
	)
	_expect(not bool(zero_chance_result.get("activated", false)), "0% Shrapnel Armor should not proc")
	_expect_close(owner.special_gauge, 100.0, "failed chance roll should not spend gauge")

	_expect(
		runtime.equip_item("shrapnel_armor", owner, registry, {
			"trigger_chance_pct": 100.0,
			"shard_count": 6.0,
			"knockback_level": 2.0,
			"gauge_cost": 35.0,
		}, false),
		"Shrapnel Armor should re-equip deterministic rolls"
	)
	runtime.reset_round(registry)
	runtime.shrapnel_armor_shards = [{
		"position": Vector2(380.0, 100.0),
		"velocity": Vector2(2.0, -1.0),
		"life": 60.0,
		"max_life": 60.0,
		"size": 4.0,
		"rotation": 0.0,
		"rot_speed": 0.0,
		"color_shift": 0.0,
		"trail": [],
	}]
	runtime.update(owner, registry, 1.0 / 60.0)
	var hit_context: Dictionary = runtime.get_boss_ai_context()
	_expect(bool(hit_context.get("shrapnel_armor_boss_stun_active", false)), "shard hit should expose boss stun context")
	_expect(bool(hit_context.get("shrapnel_armor_boss_knockback_active", false)), "shard hit should expose boss knockback context")
	_expect_close(float(hit_context.get("shrapnel_armor_boss_knockback_vel", 0.0)), 9.6, "shard hit should apply Python level 2 knockback")
	_expect(audio.hit_calls == 1, "Shrapnel Armor hit audio should play on boss hit")
	_expect(int(runtime.get_snapshot().get("shrapnel_armor_active_shards", -1)) == 0, "colliding shard should be removed")

	var boss_ai := BossAIState.new()
	var moved: Dictionary = boss_ai.update(
		1.0 / 60.0,
		Vector2(330.0, 25.0),
		0.0,
		{
			"width": 760.0,
			"play_left": 0.0,
			"play_right": 760.0,
			"boss_paddle_width": 100.0,
			"shrapnel_armor_boss_stun_active": true,
			"shrapnel_armor_boss_knockback_active": true,
			"shrapnel_armor_boss_knockback_vel": 9.6,
		}
	)
	_expect_close(float(moved.get("boss_vel", 0.0)), 9.6, "boss AI should consume Shrapnel Armor knockback velocity")
	_expect_close(_get_vector2(moved.get("boss_pos", Vector2.ZERO)).x, 339.6, "boss AI should move boss by Shrapnel Armor knockback")

	var polish_state := RuntimePerkState.new()
	polish_state.runtime_skill_levels["item_polish"] = 2
	var polish_runtime := MythicItemRuntime.new()
	var polish_owner := FakeOwner.new()
	var polish_registry := FakeRegistry.new(polish_runtime, polish_state)
	_expect(
		polish_runtime.equip_item("shrapnel_armor", polish_owner, polish_registry, {
			"trigger_chance_pct": 8.0,
			"shard_count": 4.0,
			"knockback_level": 2.0,
			"gauge_cost": 35.0,
		}, false),
		"Shrapnel Armor should equip in the polish scaling path"
	)
	_expect_close(polish_runtime.get_shrapnel_armor_trigger_chance_pct(), 9.92, "Polish should boost trigger chance through the shared roll helper")
	_expect(polish_runtime.get_shrapnel_armor_shard_count() == 5, "Polish should boost shard count through the shared roll helper")
	_expect_close(polish_runtime.get_shrapnel_armor_gauge_cost(), 28.225806, "Polish should reduce reverse gauge cost through the shared roll helper")

	print("shrapnel_armor_port_smoke: ok")
	quit(0)


func _array_has_item(items: Array, item_name: String) -> bool:
	for item_value in items:
		if item_value is Dictionary and str(item_value.get("name", "")) == item_name:
			return true
	return false


func _expect_shrapnel_rolls(catalog: Object) -> void:
	var rolls: Array = catalog.get_roll_options("shrapnel_armor")
	_expect(rolls.size() == 4, "Shrapnel Armor should expose four roll options")
	_expect(_roll_option_has_range(rolls, "trigger_chance_pct", 8.0, 15.0, 12.0), "trigger chance roll should match Python")
	_expect(_roll_option_has_range(rolls, "shard_count", 4.0, 8.0, 6.0), "shard count roll should match Python")
	_expect(_roll_option_has_range(rolls, "knockback_level", 1.0, 4.0, 2.0), "knockback level roll should match Python")
	var gauge_roll := _find_roll(rolls, "gauge_cost")
	_expect(not gauge_roll.is_empty(), "gauge cost roll should exist")
	_expect(is_equal_approx(float(gauge_roll.get("min", 0.0)), 25.0), "gauge cost min should match Python")
	_expect(is_equal_approx(float(gauge_roll.get("max", 0.0)), 50.0), "gauge cost max should match Python")
	_expect(is_equal_approx(float(gauge_roll.get("default", 0.0)), 35.0), "gauge cost default should match Python")
	_expect(bool(gauge_roll.get("reverse", false)), "gauge cost should be a reverse roll")


func _roll_option_has_range(
	rolls: Array,
	option_key: String,
	minimum: float,
	maximum: float,
	default_value: float
) -> bool:
	var roll := _find_roll(rolls, option_key)
	return (
		not roll.is_empty()
		and is_equal_approx(float(roll.get("min", 0.0)), minimum)
		and is_equal_approx(float(roll.get("max", 0.0)), maximum)
		and is_equal_approx(float(roll.get("default", 0.0)), default_value)
	)


func _find_roll(rolls: Array, key: String) -> Dictionary:
	for roll_value in rolls:
		var roll_data: Dictionary = roll_value if roll_value is Dictionary else {}
		if str(roll_data.get("key", "")) == key:
			return roll_data
	return {}


func _build_post_hit_context(owner: Object, gauge_charge_per_hit: float) -> Dictionary:
	return {
		"selected_character_type": "soldier",
		"special_gauge": owner.special_gauge,
		"gauge_charge_per_hit": gauge_charge_per_hit,
		"gauge_max": owner.special_gauge_max,
		"player_pos": owner.player_pos,
		"player_y": owner.player_pos.y,
		"player_paddle_width": owner.player_paddle_width,
		"player_paddle_height": owner.player_paddle_height,
		"paddle_width": owner.player_paddle_width,
		"ball_size": 28.6,
	}


func _get_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
