extends SceneTree

const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")
const CommandoFirearmOriginGeometry := preload("res://scripts/characters/commando_firearm_origin_geometry.gd")
const CommandoFirearmHitGeometry := preload("res://scripts/characters/commando_firearm_hit_geometry.gd")
const CommandoFirearmLingeringEffectState := preload("res://scripts/characters/commando_firearm_lingering_effect_state.gd")
const CommandoFirearmLingeringFireFlameState := preload("res://scripts/characters/commando_firearm_lingering_fire_flame_state.gd")
const CommandoFirearmLingeringNetFieldState := preload("res://scripts/characters/commando_firearm_lingering_net_field_state.gd")
const CommandoFirearmLingeringStatusState := preload("res://scripts/characters/commando_firearm_lingering_status_state.gd")
const CommandoFirearmTimerState := preload("res://scripts/characters/commando_firearm_timer_state.gd")
const CommandoFirearmValueUtils := preload("res://scripts/characters/commando_firearm_value_utils.gd")

var _failures: Array[String] = []


class FakeNetConstrictAudio:
	extends RefCounted

	var capture_calls: int = 0
	var constrict_calls: int = 0

	func play_commando_net_gun_constrict() -> void:
		constrict_calls += 1

	func play_commando_net_gun_capture() -> void:
		capture_calls += 1


class FakeDashState:
	extends RefCounted

	var active := false

	func _init(is_active: bool = false) -> void:
		active = is_active

	func get_snapshot() -> Dictionary:
		return {"active": active}


class FakeStatusEffectState:
	extends RefCounted

	var calls: Array = []

	func apply_status(target: String, status_id: String, duration_frames: float, data: Dictionary, source: String) -> void:
		calls.append({
			"target": target,
			"status_id": status_id,
			"duration_frames": duration_frames,
			"data": data.duplicate(true),
			"source": source,
		})


class FakeDopingContextRuntime:
	extends RefCounted

	var context: Dictionary

	func _init(initial_context: Dictionary) -> void:
		context = initial_context

	func get_doping_potion_context() -> Dictionary:
		return context


class FakeDopingActiveRuntime:
	extends RefCounted

	var active: bool

	func _init(initial_active: bool) -> void:
		active = initial_active

	func is_doping_potion_active() -> bool:
		return active


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary

	func _init(initial_instances: Dictionary) -> void:
		instances = initial_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	_verify_direct_value_utils()
	_verify_runtime_value_utils_integration()
	_verify_removed_fire_flame_owner_bridges()
	_verify_removed_net_field_clamp_bridges()
	_verify_removed_net_field_predicate_bridges()
	_verify_removed_net_field_setup_bridges()
	_verify_removed_lingering_status_setup_bridges()
	_verify_removed_lingering_status_application_bridges()
	_verify_removed_lingering_effect_timer_bridges()
	_verify_removed_lingering_storage_bridges()
	_verify_removed_hit_geometry_result_bridges()
	_verify_removed_support_aircraft_geometry_bridges()
	_verify_removed_projectile_value_bridges()
	_verify_removed_pistol_value_bridges()
	_verify_removed_doping_value_bridges()
	_verify_removed_timed_effect_update_bridges()
	_verify_removed_append_limited_bridge()
	_verify_removed_registry_value_bridge()
	_verify_removed_type_value_bridges()
	_verify_removed_skill_cooldown_bridges()

	if _failures.is_empty():
		print("commando_firearm_value_utils_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_value_utils() -> void:
	var values: Array = [{"id": 1}, {"id": 2}]
	CommandoFirearmValueUtils.append_limited(values, {"id": 3}, 2)
	_expect(values.size() == 2, "append_limited should preserve the requested limit")
	_expect(int(CommandoFirearmValueUtils.get_dict(values[0]).get("id", 0)) == 2, "append_limited should evict the oldest value first")
	_expect(int(CommandoFirearmValueUtils.get_dict(values[1]).get("id", 0)) == 3, "append_limited should append the new value")

	var zero_limit_values: Array = []
	CommandoFirearmValueUtils.append_limited(zero_limit_values, {"id": 1}, 0)
	CommandoFirearmValueUtils.append_limited(zero_limit_values, {"id": 2}, 0)
	_expect(zero_limit_values.size() == 1, "append_limited should clamp non-positive limits to one")
	_expect(int(CommandoFirearmValueUtils.get_dict(zero_limit_values[0]).get("id", 0)) == 2, "append_limited should keep the newest value for clamped limits")

	_expect(CommandoFirearmValueUtils.get_vector2(Vector2(3.0, 4.0), Vector2.ONE) == Vector2(3.0, 4.0), "get_vector2 should return Vector2 values")
	_expect(CommandoFirearmValueUtils.get_vector2("bad", Vector2.ONE) == Vector2.ONE, "get_vector2 should use fallback for non-Vector2 values")
	_expect(CommandoFirearmValueUtils.get_color(Color.RED, Color.BLUE) == Color.RED, "get_color should return Color values")
	_expect(CommandoFirearmValueUtils.get_color("bad", Color.BLUE) == Color.BLUE, "get_color should use fallback for non-Color values")
	_expect(CommandoFirearmValueUtils.get_dict({"ok": true}).get("ok", false), "get_dict should return Dictionary values")
	_expect(CommandoFirearmValueUtils.get_dict(["bad"]).is_empty(), "get_dict should use an empty dictionary fallback")
	_expect(CommandoFirearmValueUtils.get_array([1, 2]).size() == 2, "get_array should return Array values")
	_expect(CommandoFirearmValueUtils.get_array({"bad": true}).is_empty(), "get_array should use an empty array fallback")

	var doping_defaults := {
		"head_leg_multiplier": 2.0,
		"fire_rate_multiplier": 0.5,
		"pistol_cooldown_frames": 30.0,
		"pistol_control_lock_frames": 9.0,
		"pistol_speed_multiplier": 1.2,
		"beretta_cooldown_frames": 15.0,
		"ak47_fire_interval_frames": 3.0,
		"bazooka_cooldown_frames": 60.0,
		"bazooka_control_lock_frames": 15.0,
	}
	var inactive_doping: Dictionary = CommandoFirearmValueUtils.normalize_doping_potion_context({}, doping_defaults)
	_expect(not bool(inactive_doping.get("active", true)), "inactive doping context should default to inactive")
	_expect(is_equal_approx(float(inactive_doping.get("head_leg_multiplier", 0.0)), 1.0), "inactive doping should keep neutral head/leg multiplier")
	_expect(is_equal_approx(float(inactive_doping.get("fire_rate_multiplier", 0.0)), 1.0), "inactive doping should keep neutral fire rate")
	_expect(is_equal_approx(float(inactive_doping.get("pistol_speed_multiplier", 0.0)), 1.0), "inactive doping should keep neutral pistol speed")
	_expect(is_equal_approx(float(inactive_doping.get("pistol_cooldown_frames", 0.0)), 30.0), "inactive doping should preserve cooldown default")
	var active_doping: Dictionary = CommandoFirearmValueUtils.normalize_doping_potion_context({
		"active_item_doping_potion_active": true,
		"active_item_doping_potion_head_leg_multiplier": 2.5,
		"active_item_doping_potion_fire_rate_multiplier": -0.5,
		"active_item_doping_potion_pistol_cooldown_frames": -4.0,
		"active_item_doping_potion_pistol_control_lock_frames": -1.0,
		"active_item_doping_potion_pistol_speed_multiplier": -2.0,
		"active_item_doping_potion_beretta_cooldown_frames": -8.0,
		"active_item_doping_potion_ak47_fire_interval_frames": -3.0,
		"active_item_doping_potion_bazooka_cooldown_frames": -60.0,
		"active_item_doping_potion_bazooka_control_lock_frames": -15.0,
	}, doping_defaults)
	_expect(bool(active_doping.get("active", false)), "legacy active doping key should be recognized")
	_expect(is_equal_approx(float(active_doping.get("head_leg_multiplier", 0.0)), 2.5), "legacy head/leg multiplier key should be recognized")
	_expect(is_equal_approx(float(active_doping.get("fire_rate_multiplier", 0.0)), 0.01), "doping fire rate multiplier should clamp to a positive value")
	_expect(is_equal_approx(float(active_doping.get("pistol_cooldown_frames", 0.0)), 1.0), "doping cooldown should clamp to one frame")
	_expect(is_equal_approx(float(active_doping.get("pistol_control_lock_frames", -1.0)), 0.0), "doping control lock should clamp to zero")
	_expect(is_equal_approx(float(active_doping.get("pistol_speed_multiplier", 0.0)), 0.01), "doping speed should clamp to a positive value")
	_expect(is_equal_approx(float(active_doping.get("beretta_cooldown_frames", 0.0)), 1.0), "doping Beretta cooldown should clamp to one frame")
	_expect(is_equal_approx(float(active_doping.get("ak47_fire_interval_frames", 0.0)), 1.0), "doping AK-47 interval should clamp to one frame")
	_expect(is_equal_approx(float(active_doping.get("bazooka_cooldown_frames", 0.0)), 1.0), "doping bazooka cooldown should clamp to one frame")
	_expect(is_equal_approx(float(active_doping.get("bazooka_control_lock_frames", -1.0)), 0.0), "doping bazooka lock should clamp to zero")
	var runtime_context_doping: Dictionary = CommandoFirearmValueUtils.get_doping_potion_context_from_deps({
		"active_item_runtime": FakeDopingContextRuntime.new({
			"active": true,
			"pistol_cooldown_frames": 22.0,
		}),
	}, doping_defaults)
	_expect(bool(runtime_context_doping.get("active", false)), "doping deps helper should read active-item runtime context")
	_expect(is_equal_approx(float(runtime_context_doping.get("pistol_cooldown_frames", 0.0)), 22.0), "doping deps helper should preserve runtime cooldown")
	var runtime_active_doping: Dictionary = CommandoFirearmValueUtils.get_doping_potion_context_from_deps({
		"active_item_runtime": FakeDopingActiveRuntime.new(true),
	}, doping_defaults)
	_expect(bool(runtime_active_doping.get("active", false)), "doping deps helper should read active-item runtime active flag")
	var direct_context_doping: Dictionary = CommandoFirearmValueUtils.get_doping_potion_context_from_deps({
		"active_item_doping_potion_context": {
			"active": true,
			"head_leg_multiplier": 3.0,
		},
	}, doping_defaults)
	_expect(is_equal_approx(float(direct_context_doping.get("head_leg_multiplier", 0.0)), 3.0), "doping deps helper should read direct context payloads")
	var applied_doping_config: Dictionary = {}
	CommandoFirearmValueUtils.apply_doping_potion_to_pistol_config(applied_doping_config, direct_context_doping, doping_defaults)
	_expect(bool(applied_doping_config.get("active_item_doping_potion_active", false)), "doping config helper should mark active contexts")
	_expect(is_equal_approx(float(applied_doping_config.get("active_item_doping_potion_head_leg_multiplier", 0.0)), 3.0), "doping config helper should project head/leg multiplier")
	var inactive_doping_config: Dictionary = {}
	CommandoFirearmValueUtils.apply_doping_potion_to_pistol_config(inactive_doping_config, {}, doping_defaults)
	_expect(not bool(inactive_doping_config.get("active_item_doping_potion_active", true)), "doping config helper should mark inactive contexts")
	var pending_geometry := {
		"player_pos": Vector2(1.0, 2.0),
		"boss_pos": Vector2(3.0, 4.0),
	}
	CommandoFirearmValueUtils.refresh_pending_fire_geometry(
		pending_geometry,
		{
			"player_pos": Vector2(10.0, 20.0),
			"paddle_width": 123.0,
			"ignored": true,
		},
		["player_pos", "paddle_width", "boss_pos"]
	)
	_expect(pending_geometry.get("player_pos", Vector2.ZERO) == Vector2(10.0, 20.0), "pending geometry helper should refresh present geometry keys")
	_expect(is_equal_approx(float(pending_geometry.get("paddle_width", 0.0)), 123.0), "pending geometry helper should copy newly present geometry keys")
	_expect(pending_geometry.get("boss_pos", Vector2.ZERO) == Vector2(3.0, 4.0), "pending geometry helper should preserve keys missing from the source config")
	var empty_pending_geometry := {}
	CommandoFirearmValueUtils.refresh_pending_fire_geometry(empty_pending_geometry, {"player_pos": Vector2.ONE}, ["player_pos"])
	_expect(empty_pending_geometry.is_empty(), "pending geometry helper should ignore empty pending configs")
	var timed_effects: Array = CommandoFirearmValueUtils.advance_timed_effects([
		{"id": "alive", "timer_frames": 3.0},
		{"id": "expired", "timer_frames": 1.0},
		"bad",
	], 1.0)
	_expect(timed_effects.size() == 1, "timed effect helper should remove expired and invalid effects")
	_expect(str(CommandoFirearmValueUtils.get_dict(timed_effects[0]).get("id", "")) == "alive", "timed effect helper should preserve live effects")
	_expect(is_equal_approx(float(CommandoFirearmValueUtils.get_dict(timed_effects[0]).get("timer_frames", 0.0)), 2.0), "timed effect helper should decrement live timers")
	_expect(is_equal_approx(CommandoFirearmValueUtils.get_pistol_cooldown_frames("pistol", {}, false, 60.0, 46.0, 30.0), 60.0), "base pistol cooldown should use base frames")
	_expect(is_equal_approx(CommandoFirearmValueUtils.get_pistol_cooldown_frames("commando_pistol", {}, false, 60.0, 46.0, 30.0), 46.0), "commando pistol cooldown should use Beretta frames")
	_expect(is_equal_approx(CommandoFirearmValueUtils.get_pistol_cooldown_frames("commando_pistol", {"pistol_cooldown_frames": 22.0}, true, 60.0, 46.0, 30.0), 22.0), "active doping cooldown should override weapon cooldown")
	_expect(is_equal_approx(CommandoFirearmValueUtils.get_pistol_cooldown_frames("commando_pistol", {"pistol_cooldown_frames": 30.0, "beretta_cooldown_frames": 15.0}, true, 60.0, 46.0, 30.0), 15.0), "active doping should allow a separate Beretta cooldown")
	_expect(is_equal_approx(CommandoFirearmValueUtils.get_pistol_cooldown_frames("commando_pistol", {}, true, 60.0, 46.0, 30.0), 30.0), "active doping cooldown should use default when context omits it")
	_expect(CommandoFirearmValueUtils.is_pistol_weapon("pistol"), "base pistol should be classified as a pistol weapon")
	_expect(CommandoFirearmValueUtils.is_pistol_weapon("commando_pistol"), "commando_pistol should be classified as a pistol weapon")
	_expect(not CommandoFirearmValueUtils.is_pistol_weapon("ak47"), "ak47 should not be classified as a pistol weapon")
	_expect(is_equal_approx(CommandoFirearmValueUtils.get_pistol_hit_doping_multiplier({}, {}, 2.0), 1.0), "inactive doping multiplier should be neutral")
	_expect(is_equal_approx(CommandoFirearmValueUtils.get_pistol_hit_doping_multiplier({}, {"active_item_doping_potion_active": true}, 2.0), 2.0), "context active doping should use the default multiplier")
	_expect(is_equal_approx(CommandoFirearmValueUtils.get_pistol_hit_doping_multiplier({
		"active_item_doping_potion_active": true,
		"active_item_doping_potion_head_leg_multiplier": 2.75,
	}, {"active_item_doping_potion_head_leg_multiplier": 2.0}, 2.0), 2.75), "projectile doping multiplier should override context")
	_expect(is_equal_approx(CommandoFirearmValueUtils.get_pistol_hit_doping_multiplier({
		"active_item_doping_potion_active": true,
		"active_item_doping_potion_head_leg_multiplier": -5.0,
	}, {}, 2.0), 0.0), "doping hit multiplier should clamp negative values")
	var base_chances: Dictionary = CommandoFirearmValueUtils.get_pistol_hit_chances({}, 1.0, 0.10, 0.12)
	_expect(is_equal_approx(float(base_chances.get("head_chance", 0.0)), 0.10), "base headshot chance should use the default")
	_expect(is_equal_approx(float(base_chances.get("leg_chance", 0.0)), 0.12), "base legshot chance should use the default")
	var doped_chances: Dictionary = CommandoFirearmValueUtils.get_pistol_hit_chances({}, 2.0, 0.10, 0.12)
	_expect(is_equal_approx(float(doped_chances.get("head_chance", 0.0)), 0.20), "doped headshot chance should scale")
	_expect(is_equal_approx(float(doped_chances.get("leg_chance", 0.0)), 0.24), "doped legshot chance should scale")
	var capped_chances: Dictionary = CommandoFirearmValueUtils.get_pistol_hit_chances({
		"commando_pistol_head_chance": 0.8,
		"commando_pistol_leg_chance": 0.6,
	}, 1.0, 0.10, 0.12)
	_expect(is_equal_approx(float(capped_chances.get("head_chance", 0.0)) + float(capped_chances.get("leg_chance", 0.0)), 0.95), "pistol hit chances should preserve the 95 percent combined cap")
	_expect(float(capped_chances.get("head_chance", 0.0)) > float(capped_chances.get("leg_chance", 0.0)), "chance cap should preserve head/leg ratio")
	var clamped_chances: Dictionary = CommandoFirearmValueUtils.get_pistol_hit_chances({
		"commando_pistol_head_chance": -1.0,
		"commando_pistol_leg_chance": 3.0,
	}, 1.0, 0.10, 0.12)
	_expect(is_equal_approx(float(clamped_chances.get("head_chance", -1.0)), 0.0), "negative headshot chance should clamp to zero")
	_expect(is_equal_approx(float(clamped_chances.get("leg_chance", 0.0)), 0.95), "large legshot chance should clamp through the combined cap")
	_expect(is_equal_approx(CommandoFirearmValueUtils.get_pistol_shot_roll({"shot_roll": 0.33}, {"commando_pistol_shot_roll": 0.9}), 0.33), "shot_roll should have highest priority")
	_expect(is_equal_approx(CommandoFirearmValueUtils.get_pistol_shot_roll({"pistol_shot_roll": 0.44}, {"commando_pistol_shot_roll": 0.9}), 0.44), "pistol_shot_roll should have projectile priority")
	_expect(is_equal_approx(CommandoFirearmValueUtils.get_pistol_shot_roll({}, {"commando_pistol_shot_roll": 0.55}), 0.55), "context shot roll should be used when projectile has none")
	var random_roll: float = CommandoFirearmValueUtils.get_pistol_shot_roll({"shot_roll": "bad"}, {"commando_pistol_shot_roll": 0.55})
	_expect(random_roll >= 0.0 and random_roll <= 1.0, "invalid shot_roll should fall back to a random 0..1 roll")
	_expect(CommandoFirearmValueUtils.get_target_reached_expire_reason("bazooka", {"kind": "rocket"}) == "", "bazooka should stay alive when reaching target without a hit")
	_expect(CommandoFirearmValueUtils.get_target_reached_expire_reason("fire_support", {"kind": "support"}) == "expired", "support projectiles should expire after reaching target")
	_expect(CommandoFirearmValueUtils.get_target_reached_expire_reason("suicide_drone", {"kind": "drone"}) == "expired", "drone projectiles should expire after reaching target")
	_expect(CommandoFirearmValueUtils.get_target_reached_expire_reason("ak47", {"kind": "bullet"}) == "", "bullet projectiles should not use target-reached expiration")
	_expect(CommandoFirearmValueUtils.is_fire_support_weapon("fire_support"), "fire support classifier should recognize the support weapon")
	_expect(not CommandoFirearmValueUtils.is_fire_support_weapon("bazooka"), "fire support classifier should reject other weapons")
	_expect(CommandoFirearmValueUtils.is_net_gun_weapon("net_gun"), "net gun classifier should recognize the net weapon")
	_expect(not CommandoFirearmValueUtils.is_net_gun_weapon("ak47"), "net gun classifier should reject other weapons")
	_expect(CommandoFirearmValueUtils.support_bomb_target_y_already_reached({"support_target_y_reached": 1.0}), "support target-Y helper should recognize reached flags")
	_expect(not CommandoFirearmValueUtils.support_bomb_target_y_already_reached({"support_target_y_reached": 0.0}), "support target-Y helper should ignore zero flags")
	_expect(CommandoFirearmValueUtils.projectile_life_expired({"life_frames": 0.0}), "projectile life helper should expire at zero frames")
	_expect(CommandoFirearmValueUtils.projectile_life_expired({"life_frames": -1.0}), "projectile life helper should expire below zero frames")
	_expect(not CommandoFirearmValueUtils.projectile_life_expired({"life_frames": 0.01}), "projectile life helper should keep positive life frames")
	_expect(CommandoFirearmValueUtils.get_projectile_target({"target": Vector2(12.0, 34.0)}, Vector2(50.0, 60.0)) == Vector2(12.0, 34.0), "projectile target helper should use explicit Vector2 targets")
	_expect(CommandoFirearmValueUtils.get_projectile_target({}, Vector2(50.0, 60.0)) == Vector2(50.0, 60.0), "projectile target helper should use fallback when target is missing")
	_expect(CommandoFirearmValueUtils.get_projectile_target({"target": "bad"}, Vector2(50.0, 60.0)) == Vector2(50.0, 60.0), "projectile target helper should use fallback for invalid targets")
	_expect(CommandoFirearmValueUtils.get_projectile_weapon_id({"weapon_id": "bazooka"}, "pistol") == "bazooka", "projectile weapon helper should use explicit weapon ids")
	_expect(CommandoFirearmValueUtils.get_projectile_weapon_id({}, "pistol") == "pistol", "projectile weapon helper should use fallback when weapon id is missing")
	_expect(CommandoFirearmValueUtils.get_projectile_weapon_id({"weapon_id": 7}, "pistol") == "7", "projectile weapon helper should preserve string conversion behavior")
	_expect(CommandoFirearmValueUtils.get_projectile_kind({"kind": "drone"}) == "drone", "projectile kind helper should use explicit kinds")
	_expect(CommandoFirearmValueUtils.get_projectile_kind({}, "bullet") == "bullet", "projectile kind helper should use fallback when kind is missing")
	_expect(CommandoFirearmValueUtils.get_projectile_kind({"kind": 4}) == "4", "projectile kind helper should preserve string conversion behavior")


func _verify_runtime_value_utils_integration() -> void:
	var runtime := CommandoFirearmRuntime.new()
	var values: Array = [{"id": 1}, {"id": 2}]
	CommandoFirearmValueUtils.append_limited(values, {"id": 3}, 2)
	_expect(values.size() == 2 and int(CommandoFirearmValueUtils.get_dict(values[0]).get("id", 0)) == 2, "append helper should evict the oldest value through value utils")
	_expect(CommandoFirearmValueUtils.get_vector2(Vector2(5.0, 6.0), Vector2.ZERO) == Vector2(5.0, 6.0), "value utils vector helper should return Vector2 values")
	_expect(CommandoFirearmValueUtils.get_vector2(12, Vector2.ONE) == Vector2.ONE, "value utils vector helper should preserve fallback behavior")
	_expect(CommandoFirearmValueUtils.get_color(Color.GREEN, Color.BLUE) == Color.GREEN, "value utils color helper should return Color values")
	_expect(CommandoFirearmValueUtils.get_color(12, Color.BLUE) == Color.BLUE, "value utils color helper should preserve fallback behavior")
	_expect(CommandoFirearmValueUtils.get_dict({"value": 7}).get("value", 0) == 7, "value utils dict helper should return Dictionary values")
	_expect(CommandoFirearmValueUtils.get_dict("bad").is_empty(), "value utils dict helper should preserve fallback behavior")
	_expect(CommandoFirearmValueUtils.get_array(["a"]).size() == 1, "value utils array helper should return Array values")
	_expect(CommandoFirearmValueUtils.get_array("bad").is_empty(), "value utils array helper should preserve fallback behavior")
	var registry_marker := RefCounted.new()
	_expect(CommandoFirearmValueUtils.get_instance(FakeRegistry.new({"marker": registry_marker}), "marker") == registry_marker, "registry helper should read available registry instances")
	_expect(CommandoFirearmValueUtils.get_instance(RefCounted.new(), "marker") == null, "registry helper should reject objects without get_instance")
	var runtime_doping: Dictionary = CommandoFirearmValueUtils.normalize_doping_potion_context({
		"active": true,
		"head_leg_multiplier": 3.0,
		"pistol_cooldown_frames": 18.0,
	}, _doping_defaults())
	_expect(bool(runtime_doping.get("active", false)), "doping normalization should preserve active state")
	_expect(is_equal_approx(float(runtime_doping.get("head_leg_multiplier", 0.0)), 3.0), "doping normalization should preserve explicit multiplier")
	_expect(is_equal_approx(float(runtime_doping.get("pistol_cooldown_frames", 0.0)), 18.0), "doping normalization should preserve explicit cooldown")
	var runtime_deps_doping: Dictionary = CommandoFirearmValueUtils.get_doping_potion_context_from_deps({
		"active_item_doping_potion_context": runtime_doping,
	}, _doping_defaults())
	_expect(bool(runtime_deps_doping.get("active", false)), "doping deps helper should read direct contexts")
	var runtime_config_doping: Dictionary = CommandoFirearmValueUtils.normalize_doping_potion_context({
		"active_item_doping_potion_active": true,
		"active_item_doping_potion_pistol_speed_multiplier": 1.4,
	}, _doping_defaults())
	_expect(is_equal_approx(float(runtime_config_doping.get("pistol_speed_multiplier", 0.0)), 1.4), "doping config helper should read projected config values")
	var runtime_applied_config: Dictionary = {}
	CommandoFirearmValueUtils.apply_doping_potion_to_pistol_config(runtime_applied_config, runtime_deps_doping, _doping_defaults())
	_expect(bool(runtime_applied_config.get("active_item_doping_potion_active", false)), "doping config apply helper should project the active flag")
	runtime.pistol_pending_config = {
		"player_pos": Vector2(1.0, 2.0),
		"boss_pos": Vector2(3.0, 4.0),
	}
	runtime.pistol_fire_delay_frames = 2.0
	var pending_result: Dictionary = CommandoFirearmTimerState.advance_runtime_firearm_timers(
		runtime,
		{
			"player_pos": Vector2(10.0, 20.0),
			"paddle_width": 123.0,
		},
		{},
		1.0,
		CommandoFirearmRuntime.AK47_RECOIL_RECOVERY_PER_FRAME,
		CommandoFirearmRuntime.PISTOL_PENDING_FIRE_GEOMETRY_KEYS,
		CommandoFirearmRuntime.BASE_WEAPON_ID,
		CommandoFirearmRuntime.PISTOL_POST_FIRE_ANIMATION_FRAMES
	)
	_expect(bool(pending_result.get("shot_pending", false)), "runtime timer path should preserve pending pistol shots")
	_expect(CommandoFirearmValueUtils.get_vector2(runtime.pistol_pending_config.get("player_pos", Vector2.ZERO), Vector2.ZERO) == Vector2(10.0, 20.0), "runtime timer path should refresh pending player position")
	_expect(is_equal_approx(float(runtime.pistol_pending_config.get("paddle_width", 0.0)), 123.0), "runtime timer path should copy pending paddle width")
	_expect(CommandoFirearmValueUtils.get_vector2(runtime.pistol_pending_config.get("boss_pos", Vector2.ZERO), Vector2.ZERO) == Vector2(3.0, 4.0), "runtime timer path should preserve absent pending boss position")
	runtime.muzzle_flashes = [{"id": "muzzle", "timer_frames": 2.0}]
	runtime.update_effects(1.0, 0, {}, {})
	_expect(is_equal_approx(float(CommandoFirearmValueUtils.get_dict(runtime.muzzle_flashes[0]).get("timer_frames", 0.0)), 1.0), "runtime effect update should decrement muzzle flashes through value utils")
	runtime.update_effects(1.0, 0, {}, {})
	_expect(runtime.muzzle_flashes.is_empty(), "runtime effect update should remove expired muzzle flashes through value utils")
	runtime.impact_flashes = [{"id": "impact", "timer_frames": 2.0}]
	runtime.update_effects(2.0, 0, {}, {})
	_expect(runtime.impact_flashes.is_empty(), "runtime effect update should remove expired impact flashes through value utils")
	_expect(is_equal_approx(CommandoFirearmValueUtils.get_pistol_cooldown_frames("pistol", {}, false, 60.0, 30.0, 30.0), 60.0), "base pistol cooldown helper should keep base timing")
	_expect(CommandoFirearmValueUtils.get_pistol_cooldown_frames("commando_pistol", {}, false, 60.0, 30.0, 30.0) < 60.0, "commando pistol cooldown helper should keep faster Beretta timing")
	_expect(is_equal_approx(CommandoFirearmValueUtils.get_pistol_cooldown_frames("commando_pistol", runtime_doping, true, 60.0, 30.0, 30.0), 18.0), "active doping cooldown helper should prefer explicit cooldown")
	_expect(is_equal_approx(CommandoFirearmValueUtils.get_pistol_control_lock_frames(runtime_doping, true, 18.0, 9.0), 9.0), "active doping pistol control-lock helper should use normalized defaults")
	_expect(is_equal_approx(CommandoFirearmValueUtils.get_doping_fire_rate_multiplier(runtime_doping, 0.5), 0.5), "doping fire-rate helper should use normalized defaults")
	_expect(is_equal_approx(CommandoFirearmValueUtils.get_ak47_fire_interval_frames(runtime_doping, true, 6.0, 3.0), 3.0), "AK-47 interval helper should use doping timing")
	_expect(is_equal_approx(CommandoFirearmValueUtils.get_bazooka_cooldown_frames(runtime_doping, true, 120.0, 60.0), 60.0), "bazooka cooldown helper should use doping timing")
	_expect(is_equal_approx(CommandoFirearmValueUtils.get_bazooka_control_lock_frames(runtime_doping, true, 30.0, 15.0), 15.0), "bazooka control-lock helper should use doping timing")
	_expect(CommandoFirearmHitGeometry.get_target_reached_expire_reason("fire_support", {"kind": "support"}) == "expired", "hit geometry target-reached expire helper should delegate")
	_expect(CommandoFirearmHitGeometry.is_fire_support_weapon("fire_support"), "hit geometry fire-support classifier helper should delegate")
	_expect(CommandoFirearmHitGeometry.is_net_gun_weapon("net_gun"), "hit geometry net-gun classifier helper should delegate")
	_expect(CommandoFirearmHitGeometry.support_bomb_target_y_already_reached({"support_target_y_reached": 1.0}), "hit geometry support target-Y helper should delegate")
	_expect(CommandoFirearmHitGeometry.projectile_life_expired({"life_frames": 0.0}), "hit geometry projectile life helper should delegate")
	_expect(CommandoFirearmValueUtils.is_pistol_weapon(CommandoFirearmValueUtils.get_projectile_weapon_id({"weapon_id": "pistol"}, ""), "pistol"), "wall-bouncing pistol helper should accept the base pistol")
	_expect(CommandoFirearmValueUtils.is_pistol_weapon(CommandoFirearmValueUtils.get_projectile_weapon_id({"weapon_id": "commando_pistol"}, ""), "pistol"), "wall-bouncing pistol helper should accept the Commando pistol")
	_expect(not CommandoFirearmValueUtils.is_pistol_weapon(CommandoFirearmValueUtils.get_projectile_weapon_id({"weapon_id": "ak47"}, ""), "pistol"), "wall-bouncing pistol helper should reject non-pistols")
	_expect(not CommandoFirearmValueUtils.is_pistol_weapon(CommandoFirearmValueUtils.get_projectile_weapon_id({}, ""), "pistol"), "wall-bouncing pistol helper should preserve missing weapon-id behavior")
	_expect(is_equal_approx(CommandoFirearmLingeringEffectState.get_duration({"duration_frames": 90.0}, false, false, 30.0), 90.0), "lingering duration owner should use normal duration frames")
	_expect(is_equal_approx(CommandoFirearmLingeringEffectState.get_duration({"duration_frames": -4.0}, false, false, 30.0), 1.0), "lingering duration owner should clamp normal durations to one frame")
	_expect(is_equal_approx(CommandoFirearmLingeringEffectState.get_duration({}, false, false, 30.0), 1.0), "lingering duration owner should default missing normal durations to one frame")
	_expect(is_equal_approx(CommandoFirearmLingeringEffectState.get_duration({"duration_frames": 90.0, "dissolve_frames": 14.0}, true, true, 30.0), 14.0), "lingering duration owner should use dissolve frames for dissolving nets")
	_expect(is_equal_approx(CommandoFirearmLingeringEffectState.get_duration({"duration_frames": 90.0, "dissolve_frames": -2.0}, true, true, 30.0), 1.0), "lingering duration owner should clamp dissolve durations to one frame")
	_expect(is_equal_approx(CommandoFirearmLingeringEffectState.get_duration({"duration_frames": 90.0, "dissolve_frames": 14.0}, true, false, 30.0), 90.0), "lingering duration owner should ignore dissolve frames for live nets")
	_expect(CommandoFirearmLingeringNetFieldState.get_default_lingering_effect_pos({"width": 120.0}, Vector2(20.0, 10.0), 760.0, 750.0) == Vector2(60.0, 18.0), "default lingering pos owner should clamp left and top edges")
	_expect(CommandoFirearmLingeringNetFieldState.get_default_lingering_effect_pos({"width": 120.0}, Vector2(740.0, 745.0), 760.0, 750.0) == Vector2(700.0, 732.0), "default lingering pos owner should clamp right and bottom edges")
	_expect(CommandoFirearmLingeringNetFieldState.get_default_lingering_effect_pos({"width": 120.0}, Vector2(300.0, 400.0), 760.0, 750.0) == Vector2(300.0, 400.0), "default lingering pos owner should preserve in-field positions")
	_expect(CommandoFirearmLingeringNetFieldState.get_default_lingering_effect_pos({}, Vector2(20.0, 400.0), 760.0, 750.0) == Vector2(40.0, 400.0), "default lingering pos owner should use the fallback width")
	_expect(CommandoFirearmLingeringNetFieldState.get_lingering_effect_pos({"kind": "fire_zone", "width": 120.0}, {"pos": Vector2(20.0, 10.0)}, {}, Vector2(20.0, 10.0), Vector2.ZERO, 760.0, 750.0, 280.0, 90.0, 140.0) == Vector2(60.0, 18.0), "lingering effect pos owner should preserve non-net positioning")
	var net_pos_profile := {
		"width": 280.0,
		"height": 140.0,
		"min_height": 90.0,
	}
	var net_pos_context := {"boss_hitbox_height": 100.0}
	_expect(CommandoFirearmLingeringNetFieldState.get_net_lingering_effect_pos(net_pos_profile, {"target": Vector2(0.0, 10.0)}, net_pos_context, Vector2(20.0, 500.0), Vector2.ZERO, 760.0, 750.0, 280.0, 90.0, 140.0) == Vector2(140.0, 75.0), "net lingering pos owner should clamp left and top edges")
	_expect(CommandoFirearmLingeringNetFieldState.get_net_lingering_effect_pos(net_pos_profile, {"target": Vector2(0.0, 745.0)}, net_pos_context, Vector2(740.0, 50.0), Vector2.ZERO, 760.0, 750.0, 280.0, 90.0, 140.0) == Vector2(620.0, 675.0), "net lingering pos owner should clamp right and bottom edges")
	_expect(CommandoFirearmLingeringNetFieldState.get_net_lingering_effect_pos(net_pos_profile, {"target": Vector2(0.0, 400.0)}, net_pos_context, Vector2(300.0, 50.0), Vector2.ZERO, 760.0, 750.0, 280.0, 90.0, 140.0) == Vector2(300.0, 400.0), "net lingering pos owner should preserve in-field positions and target y")
	_expect(CommandoFirearmLingeringNetFieldState.get_net_lingering_effect_pos(net_pos_profile, {}, {
		"boss_pos": Vector2(320.0, 50.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 100.0,
	}, Vector2(300.0, 50.0), Vector2(320.0, 100.0), 760.0, 750.0, 280.0, 90.0, 140.0) == Vector2(300.0, 100.0), "net lingering pos owner should fall back to the boss target y")
	_expect(CommandoFirearmLingeringNetFieldState.get_lingering_effect_pos({"kind": "net_field", "width": 280.0, "height": 140.0, "min_height": 90.0}, {
		"pos": Vector2(20.0, 500.0),
		"target": Vector2(0.0, 10.0),
	}, net_pos_context, Vector2(20.0, 500.0), Vector2.ZERO, 760.0, 750.0, 280.0, 90.0, 140.0) == Vector2(140.0, 75.0), "lingering effect pos owner should preserve net positioning")
	_expect(CommandoFirearmLingeringEffectState.get_size({"width": 80.0, "height": 36.0}, {"impact_radius": 12.0}, false, 280.0, 140.0) == Vector2(80.0, 36.0), "lingering size owner should prefer explicit profile dimensions")
	_expect(CommandoFirearmLingeringEffectState.get_size({}, {"impact_radius": 12.0}, false, 280.0, 140.0) == Vector2(24.0, 14.4), "lingering size owner should derive normal dimensions from impact radius")
	_expect(CommandoFirearmLingeringEffectState.get_size({}, {}, false, 280.0, 140.0) == Vector2(48.0, 28.8), "lingering size owner should use the default impact radius")
	var net_lingering_profile := {
		"height": 140.0,
		"min_height": 90.0,
	}
	var net_lingering_size: Vector2 = CommandoFirearmLingeringEffectState.get_size(
		net_lingering_profile,
		{"impact_radius": 12.0},
		true,
		280.0,
		CommandoFirearmLingeringNetFieldState.get_net_effect_height(net_lingering_profile, {"boss_hitbox_height": 100.0}, 90.0, 140.0)
	)
	_expect(net_lingering_size == Vector2(280.0, 110.0), "lingering size owner should use net width and boss-scaled net height")
	_expect(is_equal_approx(CommandoFirearmLingeringNetFieldState.get_net_effect_desired_height({"boss_hitbox_height": 100.0}), 110.0), "net effect desired-height owner should scale boss hitbox height")
	_expect(is_equal_approx(CommandoFirearmLingeringNetFieldState.get_net_effect_desired_height({}), 44.0), "net effect desired-height owner should use the default boss height")
	_expect(is_equal_approx(CommandoFirearmLingeringNetFieldState.get_net_effect_desired_height({"boss_hitbox_height": -5.0}), 1.1), "net effect desired-height owner should clamp boss height before scaling")
	_expect(CommandoFirearmLingeringNetFieldState.get_net_effect_height_limits({"height": 140.0, "min_height": 90.0}, 90.0, 140.0) == Vector2(90.0, 140.0), "net effect height-limit owner should preserve profile limits")
	_expect(CommandoFirearmLingeringNetFieldState.get_net_effect_height_limits({}, 90.0, 140.0) == Vector2(90.0, 140.0), "net effect height-limit owner should use default net limits")
	_expect(CommandoFirearmLingeringNetFieldState.get_net_effect_height_limits({"height": -4.0, "min_height": 0.0}, 90.0, 140.0) == Vector2(1.0, 1.0), "net effect height-limit owner should clamp limits to positive values")
	_expect(is_equal_approx(CommandoFirearmLingeringNetFieldState.get_net_effect_height({"height": 140.0, "min_height": 90.0}, {"boss_hitbox_height": 20.0}, 90.0, 140.0), 90.0), "net effect height owner should clamp low desired height to min")
	_expect(is_equal_approx(CommandoFirearmLingeringNetFieldState.get_net_effect_height({"height": 140.0, "min_height": 90.0}, {"boss_hitbox_height": 100.0}, 90.0, 140.0), 110.0), "net effect height owner should preserve desired height inside limits")
	_expect(is_equal_approx(CommandoFirearmLingeringNetFieldState.get_net_effect_height({"height": 140.0, "min_height": 90.0}, {"boss_hitbox_height": 200.0}, 90.0, 140.0), 140.0), "net effect height owner should clamp high desired height to max")
	_expect(is_equal_approx(CommandoFirearmLingeringNetFieldState.get_net_shape_seed_phase(0), 0.0), "net shape seed owner should keep zero seeds at zero phase")
	_expect(is_equal_approx(CommandoFirearmLingeringNetFieldState.get_net_shape_seed_phase(1), 0.61803398875), "net shape seed owner should use golden-ratio phase")
	_expect(is_equal_approx(CommandoFirearmLingeringNetFieldState.get_net_shape_seed_phase(2), 0.2360679775), "net shape seed owner should wrap phases")
	_expect(is_equal_approx(CommandoFirearmLingeringNetFieldState.get_net_shape_scale(0.0, 0.0), 0.82), "net shape scale owner should preserve the base scale at zero angle")
	_expect(CommandoFirearmLingeringNetFieldState.get_net_shape_point(100.0, 50.0, 0, 36, 0.0).is_equal_approx(Vector2(41.0, 0.0)), "net shape point owner should preserve the first outline point")
	_expect(CommandoFirearmLingeringNetFieldState.get_net_shape_point(100.0, 50.0, 9, 36, 0.0).is_equal_approx(Vector2(0.0, 14.0)), "net shape point owner should preserve quarter-turn outline points")
	var net_shape: Array = CommandoFirearmLingeringNetFieldState.generate_net_shape(100.0, 50.0, 0)
	_expect(net_shape.size() == 36, "net shape owner should generate the expected outline point count")
	_expect(CommandoFirearmValueUtils.get_vector2(net_shape[0], Vector2.ZERO).is_equal_approx(Vector2(41.0, 0.0)), "net shape owner should preserve the deterministic first point")
	runtime.shot_serial = 40
	runtime.lingering_effects.clear()
	runtime._spawn_lingering_effect("suicide_drone", {"id": 77, "pos": Vector2(100.0, 80.0)}, {})
	_expect(int(CommandoFirearmValueUtils.get_dict(runtime.lingering_effects[0]).get("id", 0)) == 77, "lingering spawn path should preserve explicit ids")
	_expect(runtime.shot_serial == 40, "lingering spawn path should not consume serials for explicit ids")
	runtime._spawn_lingering_effect("suicide_drone", {"pos": Vector2(100.0, 80.0)}, {})
	_expect(int(CommandoFirearmValueUtils.get_dict(runtime.lingering_effects[1]).get("id", 0)) == 41, "lingering spawn path should allocate missing ids")
	_expect(runtime.shot_serial == 41, "lingering spawn path should advance serials for missing ids")
	runtime._spawn_lingering_effect("suicide_drone", {"id": 0, "pos": Vector2(100.0, 80.0)}, {})
	_expect(int(CommandoFirearmValueUtils.get_dict(runtime.lingering_effects[2]).get("id", 0)) == 42, "lingering spawn path should allocate zero ids")
	_expect(runtime.shot_serial == 42, "lingering spawn path should advance serials for zero ids")
	var runtime_source := FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	_expect(not runtime_source.contains("func _get_lingering_effect_id("), "runtime should not keep a lingering effect-id bridge")
	var base_lingering_effect: Dictionary = CommandoFirearmLingeringEffectState.build_effect(
		"suicide_drone",
		{
			"kind": "fire_zone",
			"color": Color.RED,
			"secondary": Color.GREEN,
		},
		{
			"color": Color.BLUE,
			"secondary": Color.YELLOW,
		},
		Vector2(100.0, 80.0),
		17,
		Vector2(120.0, 45.0),
		90.0
	)
	_expect(int(base_lingering_effect.get("id", 0)) == 17, "lingering effect builder should preserve ids")
	_expect(str(base_lingering_effect.get("weapon_id", "")) == "suicide_drone", "lingering effect builder should preserve weapon ids")
	_expect(str(base_lingering_effect.get("kind", "")) == "fire_zone", "lingering effect builder should preserve profile kind")
	_expect(base_lingering_effect.get("pos", Vector2.ZERO) == Vector2(100.0, 80.0), "lingering effect builder should preserve positions")
	_expect(is_equal_approx(float(base_lingering_effect.get("width", 0.0)), 120.0), "lingering effect builder should preserve effect width")
	_expect(is_equal_approx(float(base_lingering_effect.get("height", 0.0)), 45.0), "lingering effect builder should preserve effect height")
	_expect(is_equal_approx(float(base_lingering_effect.get("timer_frames", 0.0)), 90.0), "lingering effect builder should preserve duration")
	_expect(is_equal_approx(float(base_lingering_effect.get("max_timer_frames", 0.0)), 90.0), "lingering effect builder should preserve max duration")
	_expect(is_equal_approx(float(base_lingering_effect.get("phase", -1.0)), 0.0), "lingering effect builder should start phase at zero")
	_expect(base_lingering_effect.get("color", Color.WHITE) == Color.RED, "lingering effect builder should prefer profile color")
	_expect(base_lingering_effect.get("secondary", Color.WHITE) == Color.GREEN, "lingering effect builder should prefer profile secondary color")
	_expect(str(base_lingering_effect.get("source", "")) == "commando_firearm_suicide_drone_lingering_17", "lingering effect builder should build stable source ids")
	var fallback_lingering_effect: Dictionary = CommandoFirearmLingeringEffectState.build_effect(
		"bowling_trap",
		{},
		{
			"color": Color.BLUE,
			"secondary": Color.YELLOW,
		},
		Vector2.ZERO,
		18,
		Vector2.ONE,
		1.0
	)
	_expect(str(fallback_lingering_effect.get("kind", "")) == "field", "lingering effect builder should default missing kinds")
	_expect(fallback_lingering_effect.get("color", Color.WHITE) == Color.BLUE, "lingering effect builder should fall back to projectile color")
	_expect(fallback_lingering_effect.get("secondary", Color.WHITE) == Color.YELLOW, "lingering effect builder should fall back to projectile secondary color")
	var lingering_spawn_result: Dictionary = CommandoFirearmLingeringEffectState.build_spawn_result(base_lingering_effect, 90.0)
	_expect(str(lingering_spawn_result.get("kind", "")) == "fire_zone", "lingering spawn result owner should preserve effect kind")
	_expect(is_equal_approx(float(lingering_spawn_result.get("duration_frames", 0.0)), 90.0), "lingering spawn result owner should preserve duration")
	_expect(str(lingering_spawn_result.get("source", "")) == "commando_firearm_suicide_drone_lingering_17", "lingering spawn result owner should preserve effect source")
	var fallback_spawn_result: Dictionary = CommandoFirearmLingeringEffectState.build_spawn_result({}, 1.0)
	_expect(str(fallback_spawn_result.get("kind", "missing")).is_empty(), "lingering spawn result owner should default missing kind to empty")
	_expect(str(fallback_spawn_result.get("source", "missing")).is_empty(), "lingering spawn result owner should default missing source to empty")
	_expect(is_equal_approx(float(fallback_spawn_result.get("duration_frames", 0.0)), 1.0), "lingering spawn result owner should preserve fallback durations")
	_expect(CommandoFirearmLingeringStatusState.get_profile_id({"status_id": "burn"}) == "burn", "lingering status profile-id helper should read status ids")
	_expect(CommandoFirearmLingeringStatusState.get_profile_id({}).is_empty(), "lingering status profile-id helper should default missing ids to empty")
	_expect(is_equal_approx(CommandoFirearmLingeringStatusState.get_profile_duration({"status_duration_frames": 36.0}, 18.0), 36.0), "lingering status profile-duration helper should read explicit durations")
	_expect(is_equal_approx(CommandoFirearmLingeringStatusState.get_profile_duration({}, 18.0), 18.0), "lingering status profile-duration helper should use the default duration")
	_expect(is_equal_approx(CommandoFirearmLingeringStatusState.get_profile_interval({"status_interval_frames": 8.0}, 12.0), 8.0), "lingering status profile-interval helper should read explicit intervals")
	_expect(is_equal_approx(CommandoFirearmLingeringStatusState.get_profile_interval({}, 12.0), 12.0), "lingering status profile-interval helper should use the default interval")
	_expect(is_equal_approx(CommandoFirearmLingeringStatusState.get_initial_cooldown(0.0), 0.0), "lingering status initial-cooldown helper should start ready")
	_expect(CommandoFirearmLingeringStatusState.has_profile_slow_multiplier({"slow_multiplier": 0.45}), "lingering status profile slow-multiplier guard should detect explicit multipliers")
	_expect(not CommandoFirearmLingeringStatusState.has_profile_slow_multiplier({}), "lingering status profile slow-multiplier guard should reject missing multipliers")
	_expect(is_equal_approx(CommandoFirearmLingeringStatusState.get_profile_slow_multiplier({"slow_multiplier": 0.45}, 1.0), 0.45), "lingering status profile slow-multiplier helper should read explicit multipliers")
	_expect(is_equal_approx(CommandoFirearmLingeringStatusState.get_profile_slow_multiplier({}, 1.0), 1.0), "lingering status profile slow-multiplier helper should use the default multiplier")
	var copied_slow_profile_effect := {}
	CommandoFirearmLingeringStatusState.apply_profile_slow_multiplier(copied_slow_profile_effect, {"slow_multiplier": 0.45}, 1.0)
	_expect(is_equal_approx(float(copied_slow_profile_effect.get("slow_multiplier", 0.0)), 0.45), "lingering status profile slow-multiplier apply helper should copy explicit multipliers")
	var missing_slow_profile_effect := {"kept": true}
	CommandoFirearmLingeringStatusState.apply_profile_slow_multiplier(missing_slow_profile_effect, {}, 1.0)
	_expect(not missing_slow_profile_effect.has("slow_multiplier") and bool(missing_slow_profile_effect.get("kept", false)), "lingering status profile slow-multiplier apply helper should ignore missing multipliers")
	var base_status_profile_effect := {}
	CommandoFirearmLingeringStatusState.apply_profile_base_fields(base_status_profile_effect, {
		"status_duration_frames": 36.0,
		"status_interval_frames": 8.0,
	}, "burn", 18.0, 12.0, 0.0)
	_expect(str(base_status_profile_effect.get("status_id", "")) == "burn", "lingering status base-field helper should store status ids")
	_expect(is_equal_approx(float(base_status_profile_effect.get("status_duration_frames", 0.0)), 36.0), "lingering status base-field helper should store duration frames")
	_expect(is_equal_approx(float(base_status_profile_effect.get("status_interval_frames", 0.0)), 8.0), "lingering status base-field helper should store interval frames")
	_expect(is_equal_approx(float(base_status_profile_effect.get("status_cooldown_frames", -1.0)), 0.0), "lingering status base-field helper should start cooldowns ready")
	_expect(CommandoFirearmLingeringStatusState.should_apply_effect_status_fields("burn", false), "lingering status field guard should accept active status profiles")
	_expect(not CommandoFirearmLingeringStatusState.should_apply_effect_status_fields("", false), "lingering status field guard should reject missing status ids")
	_expect(not CommandoFirearmLingeringStatusState.should_apply_effect_status_fields("burn", true), "lingering status field guard should reject dissolving effects")
	var empty_status_effect := {"kept": true}
	CommandoFirearmLingeringStatusState.apply_effect_status_fields(empty_status_effect, {}, false, 18.0, 12.0, 0.0, 1.0)
	_expect(not empty_status_effect.has("status_id") and bool(empty_status_effect.get("kept", false)), "lingering status field helper should ignore profiles without status ids")
	var dissolved_status_effect := {}
	CommandoFirearmLingeringStatusState.apply_effect_status_fields(dissolved_status_effect, {"status_id": "slow"}, true, 18.0, 12.0, 0.0, 1.0)
	_expect(dissolved_status_effect.is_empty(), "lingering status field helper should skip dissolving effects")
	var default_status_effect := {}
	CommandoFirearmLingeringStatusState.apply_effect_status_fields(default_status_effect, {"status_id": "burn"}, false, 18.0, 12.0, 0.0, 1.0)
	_expect(str(default_status_effect.get("status_id", "")) == "burn", "lingering status field helper should store status ids")
	_expect(is_equal_approx(float(default_status_effect.get("status_duration_frames", 0.0)), 18.0), "lingering status field helper should default status duration")
	_expect(is_equal_approx(float(default_status_effect.get("status_interval_frames", 0.0)), 12.0), "lingering status field helper should default status interval")
	_expect(is_equal_approx(float(default_status_effect.get("status_cooldown_frames", -1.0)), 0.0), "lingering status field helper should start cooldowns ready")
	_expect(not default_status_effect.has("slow_multiplier"), "lingering status field helper should not invent slow multipliers")
	var slow_status_effect := {}
	CommandoFirearmLingeringStatusState.apply_effect_status_fields(slow_status_effect, {
		"status_id": "slow",
		"status_duration_frames": 36.0,
		"status_interval_frames": 8.0,
		"slow_multiplier": 0.45,
	}, false, 18.0, 12.0, 0.0, 1.0)
	_expect(is_equal_approx(float(slow_status_effect.get("status_duration_frames", 0.0)), 36.0), "lingering status field helper should preserve explicit status durations")
	_expect(is_equal_approx(float(slow_status_effect.get("status_interval_frames", 0.0)), 8.0), "lingering status field helper should preserve explicit status intervals")
	_expect(is_equal_approx(float(slow_status_effect.get("slow_multiplier", 0.0)), 0.45), "lingering status field helper should preserve slow multipliers")
	var fire_flame_count := CommandoFirearmLingeringFireFlameState.get_flame_count()
	var non_fire_seed_effect := {"kind": "field"}
	_expect(not CommandoFirearmLingeringEffectState.is_fire_zone(non_fire_seed_effect), "lingering fire-zone owner should reject non-fire effects")
	_expect(not CommandoFirearmLingeringFireFlameState.is_fire_zone(non_fire_seed_effect), "lingering fire flame owner should reject non-fire effects")
	CommandoFirearmLingeringFireFlameState.seed_effect_flames(non_fire_seed_effect)
	_expect(not non_fire_seed_effect.has("flames"), "lingering fire spawn path should ignore non-fire effects")
	var direct_fire_seed_effect := {"kind": "fire_zone", "width": 80.0, "height": 40.0}
	CommandoFirearmLingeringFireFlameState.seed_effect_flames(direct_fire_seed_effect)
	_expect(CommandoFirearmValueUtils.get_array(direct_fire_seed_effect.get("flames", [])).size() == fire_flame_count, "lingering fire owner should seed fire-zone flames")
	CommandoFirearmLingeringFireFlameState.update_effect_flames(direct_fire_seed_effect, 1.0)
	_expect(CommandoFirearmValueUtils.get_array(direct_fire_seed_effect.get("flames", [])).size() == fire_flame_count, "lingering fire owner should update seeded fire-zone flames")
	runtime.lingering_effects.clear()
	var fire_spawn_result: Dictionary = runtime._spawn_lingering_effect("suicide_drone", {"id": 78, "pos": Vector2(100.0, 80.0)}, {})
	var fire_seed_effect: Dictionary = {}
	if not runtime.lingering_effects.is_empty():
		fire_seed_effect = CommandoFirearmValueUtils.get_dict(runtime.lingering_effects[0])
	_expect(str(fire_spawn_result.get("kind", "")) == "fire_zone", "lingering fire spawn path should return fire-zone results")
	_expect(fire_flame_count == 15, "lingering fire flame-count helper should preserve the deterministic flame count")
	_expect(CommandoFirearmValueUtils.get_array(fire_seed_effect.get("flames", [])).size() == fire_flame_count, "lingering fire spawn path should seed deterministic fire flames")
	_expect(CommandoFirearmLingeringFireFlameState.get_effect_size({"width": 80.0, "height": 40.0}) == Vector2(80.0, 40.0), "lingering fire effect-size helper should preserve explicit dimensions")
	_expect(CommandoFirearmLingeringFireFlameState.get_effect_size({}) == Vector2(150.0, 60.0), "lingering fire effect-size helper should use default dimensions")
	_expect(CommandoFirearmLingeringFireFlameState.get_effect_size({"width": -4.0, "height": 0.0}) == Vector2(1.0, 1.0), "lingering fire effect-size helper should clamp dimensions to positive values")
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_effect_width({"width": 80.0}), 80.0), "lingering fire effect-width helper should preserve explicit widths")
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_effect_width({}), 150.0), "lingering fire effect-width helper should use the default width")
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_effect_height({"height": 40.0}), 40.0), "lingering fire effect-height helper should preserve explicit heights")
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_effect_height({}), 60.0), "lingering fire effect-height helper should use the default height")
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_effect_dimension({"width": -4.0}, "width", 150.0), 1.0), "lingering fire effect-dimension helper should clamp dimensions")
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_flame_cycle_angle(2), TAU * 2.0 / 15.0), "lingering fire flame cycle-angle helper should preserve circular spacing")
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_flame_angle(2), TAU * 2.0 / 15.0), "lingering fire flame angle helper should preserve spawn spacing")
	_expect(CommandoFirearmLingeringFireFlameState.get_flame_pattern_value(2, 7, 11) == 3, "lingering fire flame pattern helper should preserve modular spacing")
	_expect(CommandoFirearmLingeringFireFlameState.get_flame_ring_pattern_value(2) == 3, "lingering fire flame ring-pattern helper should preserve ring spacing")
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_flame_ring_factor(1), 0.7), "lingering fire flame ring-factor helper should preserve staggered ring factors")
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_flame_ring(0), 0.26), "lingering fire flame ring helper should preserve the first ring")
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_flame_ring(1), 0.736), "lingering fire flame ring helper should preserve staggered rings")
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_flame_spawn_radius_x(80.0, 0.26), 10.4), "lingering fire flame spawn-radius x helper should preserve ring-scaled x radii")
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_flame_spawn_radius_y(40.0, 0.26), 5.2), "lingering fire flame spawn-radius y helper should preserve ring-scaled y radii")
	_expect(CommandoFirearmLingeringFireFlameState.get_flame_spawn_radius(80.0, 40.0, 0.26).is_equal_approx(Vector2(10.4, 5.2)), "lingering fire flame spawn-radius helper should preserve ring-scaled radii")
	_expect(CommandoFirearmLingeringFireFlameState.get_flame_offset_from_radius(0.0, Vector2(10.4, 5.2)).is_equal_approx(Vector2(10.4, 0.0)), "lingering fire flame radius-offset helper should preserve angle projection")
	_expect(CommandoFirearmLingeringFireFlameState.get_flame_offset(0, 80.0, 40.0, 0.0).is_equal_approx(Vector2(10.4, 0.0)), "lingering fire flame offset helper should preserve the first flame offset")
	_expect(CommandoFirearmLingeringFireFlameState.get_flame_size_pattern_value(1) == 5, "lingering fire flame size-pattern helper should preserve size spacing")
	_expect(CommandoFirearmLingeringFireFlameState.get_flame_size_offset(1) == 5, "lingering fire flame size-offset helper should preserve staggered size offsets")
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_flame_size(0), 8.0), "lingering fire flame size helper should preserve the first size")
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_flame_size(1), 13.0), "lingering fire flame size helper should preserve staggered sizes")
	_expect(CommandoFirearmLingeringFireFlameState.get_flame_lifetime_pattern_value(5) == 15, "lingering fire flame lifetime-pattern helper should preserve lifetime spacing")
	_expect(CommandoFirearmLingeringFireFlameState.get_flame_lifetime_offset(5) == 15, "lingering fire flame lifetime-offset helper should preserve staggered lifetime offsets")
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_flame_lifetime(0), 22.0), "lingering fire flame lifetime helper should preserve the first lifetime")
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_flame_lifetime(5), 37.0), "lingering fire flame lifetime helper should preserve staggered lifetimes")
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_flame_phase_spacing(), 0.67), "lingering fire flame phase-spacing helper should preserve phase spacing")
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_flame_phase(2), 1.34), "lingering fire flame phase helper should preserve phase spacing")
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_flame_max_lifetime(), 40.0), "lingering fire flame max-lifetime helper should preserve max lifetime")
	var first_fire_flame: Dictionary = CommandoFirearmLingeringFireFlameState.build_flame(0, 80.0, 40.0)
	_expect(CommandoFirearmValueUtils.get_vector2(first_fire_flame.get("offset", Vector2.ZERO), Vector2.ZERO).is_equal_approx(Vector2(10.4, 0.0)), "lingering fire flame builder should preserve the first flame offset")
	_expect(is_equal_approx(float(first_fire_flame.get("size", 0.0)), 8.0), "lingering fire flame builder should preserve the first flame size")
	_expect(is_equal_approx(float(first_fire_flame.get("lifetime", 0.0)), 22.0), "lingering fire flame builder should preserve the first flame lifetime")
	_expect(is_equal_approx(float(first_fire_flame.get("max_lifetime", 0.0)), 40.0), "lingering fire flame builder should preserve max lifetime")
	_expect(is_equal_approx(float(first_fire_flame.get("phase", -1.0)), 0.0), "lingering fire flame builder should preserve the first flame phase")
	var live_net_lifecycle := {}
	CommandoFirearmLingeringNetFieldState.apply_lifecycle_fields(live_net_lifecycle, false)
	_expect(not bool(live_net_lifecycle.get("dissolve", true)), "lingering net lifecycle owner should preserve live dissolve state")
	_expect(bool(live_net_lifecycle.get("boss_trapped", false)), "lingering net lifecycle owner should trap bosses for live nets")
	_expect(bool(live_net_lifecycle.get("hooked_player", false)), "lingering net lifecycle owner should hook players for live nets")
	_expect(not bool(live_net_lifecycle.get("rope_broken", true)), "lingering net lifecycle owner should keep live ropes intact")
	_expect(is_equal_approx(float(live_net_lifecycle.get("rope_snap_timer", -1.0)), 0.0), "lingering net lifecycle owner should start snap timers at zero")
	var dissolve_net_lifecycle := {}
	CommandoFirearmLingeringNetFieldState.apply_lifecycle_fields(dissolve_net_lifecycle, true)
	_expect(bool(dissolve_net_lifecycle.get("dissolve", false)), "lingering net lifecycle owner should preserve dissolve state")
	_expect(not bool(dissolve_net_lifecycle.get("boss_trapped", true)), "lingering net lifecycle owner should not trap bosses for dissolving nets")
	_expect(not bool(dissolve_net_lifecycle.get("hooked_player", true)), "lingering net lifecycle owner should not hook players for dissolving nets")
	_expect(bool(dissolve_net_lifecycle.get("rope_broken", false)), "lingering net lifecycle owner should mark dissolving ropes broken")
	_expect(is_equal_approx(CommandoFirearmLingeringNetFieldState.get_rope_snap_duration({"dash_break_frames": 12.0}, 24.0), 12.0), "lingering net rope-snap duration owner should read explicit durations")
	_expect(is_equal_approx(CommandoFirearmLingeringNetFieldState.get_rope_snap_duration({}, 24.0), 24.0), "lingering net rope-snap duration owner should use the default dash-break duration")
	_expect(CommandoFirearmLingeringNetFieldState.get_origin({"origin": Vector2(3.0, 4.0)}, Vector2.ZERO) == Vector2(3.0, 4.0), "lingering net origin owner should preserve explicit origins")
	var fallback_net_origin_context := {"player_pos": Vector2(120.0, 640.0), "player_paddle_width": 90.0, "player_paddle_height": 24.0}
	var fallback_net_origin: Vector2 = CommandoFirearmOriginGeometry.get_commando_fire_sheet_world_pos(
		fallback_net_origin_context,
		CommandoFirearmRuntime.COMMANDO_NET_GUN_FIRE_MUZZLE_SOURCE,
		Vector2(CommandoFirearmRuntime.FIELD_WIDTH, CommandoFirearmRuntime.FIELD_HEIGHT),
		CommandoFirearmRuntime.COMMANDO_FIRE_SHEET_SOURCE_CELL_SIZE,
		CommandoFirearmRuntime.COMMANDO_FIRE_SHEET_PLAYER_FOOT_Y_OFFSET
	)
	_expect(CommandoFirearmLingeringNetFieldState.get_origin({}, fallback_net_origin) == fallback_net_origin, "lingering net origin owner should use net aim origin fallback")
	_expect(is_equal_approx(CommandoFirearmLingeringNetFieldState.get_player_slow_multiplier({"player_slow_multiplier": 0.55}, 1.0), 0.55), "lingering net player slow owner should read explicit multipliers")
	_expect(is_equal_approx(CommandoFirearmLingeringNetFieldState.get_player_slow_multiplier({}, 1.0), 1.0), "lingering net player slow owner should default to neutral movement")
	var net_profile_effect := {}
	CommandoFirearmLingeringNetFieldState.apply_profile_fields(
		net_profile_effect,
		{
			"dash_break_frames": 12.0,
			"player_slow_multiplier": 0.55,
		},
		{"origin": Vector2(3.0, 4.0)},
		Vector2.ZERO,
		24.0,
		1.0
	)
	_expect(is_equal_approx(float(net_profile_effect.get("rope_snap_duration", 0.0)), 12.0), "lingering net profile owner should preserve explicit rope snap duration")
	_expect(net_profile_effect.get("origin", Vector2.ZERO) == Vector2(3.0, 4.0), "lingering net profile owner should preserve explicit origins")
	_expect(is_equal_approx(float(net_profile_effect.get("player_slow_multiplier", 0.0)), 0.55), "lingering net profile owner should preserve explicit player slow multipliers")
	_expect(is_equal_approx(CommandoFirearmLingeringNetFieldState.get_deploy_x(Vector2(100.0, 80.0)), 100.0), "lingering net deploy-x owner should use the effect center x")
	_expect(CommandoFirearmLingeringNetFieldState.get_net_rect(Vector2(100.0, 80.0), Vector2(280.0, 110.0)) == Rect2(Vector2(-40.0, 25.0), Vector2(280.0, 110.0)), "lingering net rect owner should build centered rects")
	_expect(is_equal_approx(CommandoFirearmLingeringNetFieldState.get_initial_constrict_factor(), 1.0), "lingering net initial constrict owner should preserve the default constrict factor")
	_expect(CommandoFirearmValueUtils.get_array(CommandoFirearmLingeringNetFieldState.build_net_shape(Vector2(280.0, 110.0), 7)).size() == 36, "lingering net shape builder owner should preserve deterministic shape point count")
	var net_geometry_effect := {}
	CommandoFirearmLingeringNetFieldState.apply_geometry_fields(net_geometry_effect, Vector2(100.0, 80.0), Vector2(280.0, 110.0), 7)
	_expect(is_equal_approx(float(net_geometry_effect.get("deploy_x", 0.0)), 100.0), "lingering net geometry owner should store deploy x")
	_expect(net_geometry_effect.get("net_rect", Rect2()) == Rect2(Vector2(-40.0, 25.0), Vector2(280.0, 110.0)), "lingering net geometry owner should build a centered net rect")
	_expect(is_equal_approx(float(net_geometry_effect.get("constrict_factor", 0.0)), 1.0), "lingering net geometry owner should initialize constrict factor")
	_expect(CommandoFirearmValueUtils.get_array(net_geometry_effect.get("shape", [])).size() == 36, "lingering net geometry owner should seed deterministic shape points")
	runtime.lingering_effects.clear()
	var live_net_result: Dictionary = runtime._spawn_lingering_effect(
		"net_gun",
		{
			"id": 7,
			"origin": Vector2(3.0, 4.0),
			"pos": Vector2(300.0, 80.0),
			"target": Vector2(300.0, 80.0),
		},
		{"boss_hitbox_height": 100.0}
	)
	var live_net_effect: Dictionary = {}
	if not runtime.lingering_effects.is_empty():
		live_net_effect = CommandoFirearmValueUtils.get_dict(runtime.lingering_effects[0])
	_expect(str(live_net_result.get("kind", "")) == "net_field", "lingering net spawn path should return net-field results")
	_expect(not bool(live_net_effect.get("dissolve", true)), "lingering net spawn path should preserve live net dissolve state")
	_expect(bool(live_net_effect.get("boss_trapped", false)), "lingering net spawn path should trap the boss for live nets")
	_expect(bool(live_net_effect.get("hooked_player", false)), "lingering net spawn path should hook the player for live nets")
	_expect(not bool(live_net_effect.get("rope_broken", true)), "lingering net spawn path should keep live net ropes intact")
	_expect(is_equal_approx(float(live_net_effect.get("rope_snap_duration", 0.0)), CommandoFirearmRuntime.NET_GUN_DASH_BREAK_FRAMES), "lingering net spawn path should preserve runtime rope snap duration")
	_expect(live_net_effect.get("origin", Vector2.ZERO) == Vector2(3.0, 4.0), "lingering net spawn path should preserve explicit origins")
	_expect(is_equal_approx(float(live_net_effect.get("deploy_x", 0.0)), 300.0), "lingering net spawn path should store deploy x")
	_expect(is_equal_approx(float(live_net_effect.get("player_slow_multiplier", 0.0)), CommandoFirearmRuntime.NET_GUN_PLAYER_SLOW_MULTIPLIER), "lingering net spawn path should preserve runtime player slow multipliers")
	_expect(live_net_effect.get("net_rect", Rect2()) == Rect2(Vector2(160.0, 25.0), Vector2(280.0, 110.0)), "lingering net spawn path should build a centered net rect")
	_expect(is_equal_approx(float(live_net_effect.get("constrict_factor", 0.0)), 1.0), "lingering net spawn path should initialize constrict factor")
	_expect(CommandoFirearmValueUtils.get_array(live_net_effect.get("shape", [])).size() == 36, "lingering net spawn path should seed the deterministic net shape")
	runtime.lingering_effects.clear()
	var dissolved_net_result: Dictionary = runtime._spawn_lingering_effect(
		"net_gun",
		CommandoFirearmLingeringEffectState.build_net_dissolve_projectile({
			"id": 8,
			"origin": Vector2(8.0, 9.0),
			"pos": Vector2(300.0, 60.0),
			"target": Vector2(300.0, 60.0),
		}),
		{"boss_hitbox_height": 20.0}
	)
	var dissolved_net_effect: Dictionary = {}
	if not runtime.lingering_effects.is_empty():
		dissolved_net_effect = CommandoFirearmValueUtils.get_dict(runtime.lingering_effects[0])
	_expect(str(dissolved_net_result.get("kind", "")) == "net_field", "lingering net dissolve spawn path should return net-field results")
	_expect(bool(dissolved_net_effect.get("dissolve", false)), "lingering net dissolve spawn path should preserve dissolving net state")
	_expect(not bool(dissolved_net_effect.get("boss_trapped", true)), "lingering net dissolve spawn path should not trap bosses for dissolving nets")
	_expect(not bool(dissolved_net_effect.get("hooked_player", true)), "lingering net dissolve spawn path should not hook players for dissolving nets")
	_expect(bool(dissolved_net_effect.get("rope_broken", false)), "lingering net dissolve spawn path should mark dissolving net ropes broken")
	_expect(is_equal_approx(float(dissolved_net_effect.get("rope_snap_duration", 0.0)), CommandoFirearmRuntime.NET_GUN_DASH_BREAK_FRAMES), "lingering net dissolve spawn path should preserve runtime rope snap duration")
	_expect(is_equal_approx(float(dissolved_net_effect.get("player_slow_multiplier", 0.0)), CommandoFirearmRuntime.NET_GUN_PLAYER_SLOW_MULTIPLIER), "lingering net dissolve spawn path should preserve runtime player slow multipliers")
	_expect(dissolved_net_effect.get("net_rect", Rect2()) == Rect2(Vector2(160.0, 20.0), Vector2(280.0, 90.0)), "lingering net dissolve spawn path should build a min-height net rect")
	_expect(CommandoFirearmLingeringNetFieldState.is_net_gun_effect({"weapon_id": "net_gun"}), "net-gun effect owner should recognize net effects")
	_expect(not CommandoFirearmLingeringNetFieldState.is_net_gun_effect({"weapon_id": "ak47"}), "net-gun effect owner should reject other weapon effects")
	_expect(CommandoFirearmLingeringNetFieldState.is_active_hooked_net_field({"weapon_id": "net_gun", "hooked_player": true}), "active hooked net owner should accept hooked live nets")
	_expect(not CommandoFirearmLingeringNetFieldState.is_active_hooked_net_field({"weapon_id": "net_gun", "hooked_player": true, "dissolve": true}), "active hooked net owner should reject dissolving nets")
	_expect(CommandoFirearmLingeringNetFieldState.is_boss_clamping_net_field({"weapon_id": "net_gun", "boss_trapped": true}), "boss-clamping net owner should accept trapped live nets")
	_expect(not CommandoFirearmLingeringNetFieldState.is_boss_clamping_net_field({"weapon_id": "net_gun", "boss_trapped": true, "dissolve": true}), "boss-clamping net owner should reject dissolving nets")
	_expect(not CommandoFirearmLingeringNetFieldState.is_boss_clamping_net_field({"weapon_id": "net_gun", "boss_trapped": false}), "boss-clamping net owner should require trapped boss state")
	_expect(CommandoFirearmLingeringNetFieldState.is_net_constrict_candidate({"weapon_id": "net_gun", "hooked_player": true, "constrict_factor": 0.8}, CommandoFirearmRuntime.NET_CONSTRICT_MIN), "net constrict candidate owner should accept active nets above the minimum")
	_expect(not CommandoFirearmLingeringNetFieldState.is_net_constrict_candidate({"weapon_id": "net_gun", "hooked_player": true, "constrict_factor": 0.6}, CommandoFirearmRuntime.NET_CONSTRICT_MIN), "net constrict candidate owner should reject nets at the minimum")
	_expect(not CommandoFirearmLingeringNetFieldState.is_net_constrict_candidate({"weapon_id": "net_gun", "hooked_player": true, "dissolve": true, "constrict_factor": 0.8}, CommandoFirearmRuntime.NET_CONSTRICT_MIN), "net constrict candidate owner should reject dissolving nets")
	_expect(CommandoFirearmLingeringNetFieldState.get_net_constrict_input_direction({"left_pressed": true}) == -1, "net constrict input owner should map left to -1")
	_expect(CommandoFirearmLingeringNetFieldState.get_net_constrict_input_direction({"right_pressed": true}) == 1, "net constrict input owner should map right to 1")
	_expect(CommandoFirearmLingeringNetFieldState.get_net_constrict_input_direction({"left_pressed": true, "right_pressed": true}) == 0, "net constrict input owner should cancel opposing directions")
	_expect(CommandoFirearmLingeringNetFieldState.get_net_constrict_input_direction({}) == 0, "net constrict input owner should map no input to zero")
	runtime.net_constrict_last_dir = -1
	runtime.net_constrict_last_tick_msec = 1000
	_expect(not CommandoFirearmLingeringNetFieldState.should_record_net_constrict_input(0, runtime.net_constrict_last_dir), "net constrict record owner should ignore neutral input")
	_expect(not CommandoFirearmLingeringNetFieldState.should_record_net_constrict_input(-1, runtime.net_constrict_last_dir), "net constrict record owner should ignore repeated direction")
	_expect(CommandoFirearmLingeringNetFieldState.should_record_net_constrict_input(1, runtime.net_constrict_last_dir), "net constrict record owner should accept alternating direction")
	_expect(CommandoFirearmLingeringNetFieldState.should_apply_net_constrict_input(1, 1400, runtime.net_constrict_last_dir, runtime.net_constrict_last_tick_msec, CommandoFirearmRuntime.NET_CONSTRICT_WINDOW_MSEC), "net constrict apply owner should accept alternating input inside the timing window")
	_expect(not CommandoFirearmLingeringNetFieldState.should_apply_net_constrict_input(1, 1401, runtime.net_constrict_last_dir, runtime.net_constrict_last_tick_msec, CommandoFirearmRuntime.NET_CONSTRICT_WINDOW_MSEC), "net constrict apply owner should reject alternating input outside the timing window")
	_expect(not CommandoFirearmLingeringNetFieldState.should_apply_net_constrict_input(-1, 1400, runtime.net_constrict_last_dir, runtime.net_constrict_last_tick_msec, CommandoFirearmRuntime.NET_CONSTRICT_WINDOW_MSEC), "net constrict apply owner should reject repeated direction inside the timing window")
	_expect(is_equal_approx(CommandoFirearmLingeringNetFieldState.get_net_constrict_factor({}, CommandoFirearmLingeringNetFieldState.get_initial_constrict_factor()), 1.0), "net constrict factor owner should use the initial constrict default")
	_expect(is_equal_approx(CommandoFirearmLingeringNetFieldState.get_net_constrict_factor({"constrict_factor": 0.75}, CommandoFirearmLingeringNetFieldState.get_initial_constrict_factor()), 0.75), "net constrict factor owner should preserve explicit values")
	_expect(is_equal_approx(CommandoFirearmLingeringNetFieldState.get_next_net_constrict_factor({}, CommandoFirearmRuntime.NET_CONSTRICT_MIN, CommandoFirearmRuntime.NET_CONSTRICT_STEP), 0.96), "net constrict factor owner should step down from the default value")
	_expect(is_equal_approx(CommandoFirearmLingeringNetFieldState.get_next_net_constrict_factor({"constrict_factor": 0.8}, CommandoFirearmRuntime.NET_CONSTRICT_MIN, CommandoFirearmRuntime.NET_CONSTRICT_STEP), 0.76), "net constrict factor owner should step down active nets")
	_expect(is_equal_approx(CommandoFirearmLingeringNetFieldState.get_next_net_constrict_factor({"constrict_factor": 0.62}, CommandoFirearmRuntime.NET_CONSTRICT_MIN, CommandoFirearmRuntime.NET_CONSTRICT_STEP), 0.6), "net constrict factor owner should clamp near-minimum nets")
	_expect(is_equal_approx(CommandoFirearmLingeringNetFieldState.get_next_net_constrict_factor({"constrict_factor": 0.6}, CommandoFirearmRuntime.NET_CONSTRICT_MIN, CommandoFirearmRuntime.NET_CONSTRICT_STEP), 0.6), "net constrict factor owner should keep minimum nets at the floor")
	runtime.lingering_effects = [
		{"weapon_id": "net_gun", "hooked_player": true, "constrict_factor": 0.8},
		{"weapon_id": "net_gun", "hooked_player": true, "constrict_factor": 0.72},
		{"weapon_id": "net_gun", "hooked_player": true, "constrict_factor": 0.62},
	]
	var net_audio := FakeNetConstrictAudio.new()
	runtime.net_constrict_last_dir = -1
	runtime.net_constrict_last_tick_msec = 1000
	var net_constrict_result: Dictionary = CommandoFirearmLingeringNetFieldState.apply_net_constrict_input(
		runtime.lingering_effects,
		{"right_pressed": true},
		1400,
		runtime.net_constrict_last_dir,
		runtime.net_constrict_last_tick_msec,
		CommandoFirearmRuntime.NET_CONSTRICT_MIN,
		CommandoFirearmRuntime.NET_CONSTRICT_STEP,
		CommandoFirearmRuntime.NET_CONSTRICT_WINDOW_MSEC,
		net_audio
	)
	runtime.lingering_effects = CommandoFirearmValueUtils.get_array(net_constrict_result.get("effects", runtime.lingering_effects))
	runtime.net_constrict_last_dir = int(net_constrict_result.get("last_dir", runtime.net_constrict_last_dir))
	runtime.net_constrict_last_tick_msec = int(net_constrict_result.get("last_tick_msec", runtime.net_constrict_last_tick_msec))
	_expect(is_equal_approx(float(CommandoFirearmValueUtils.get_dict(runtime.lingering_effects[0]).get("constrict_factor", 0.0)), 0.76), "net constrict input path should update the first active net")
	_expect(is_equal_approx(float(CommandoFirearmValueUtils.get_dict(runtime.lingering_effects[1]).get("constrict_factor", 0.0)), 0.68), "net constrict input path should update every active candidate")
	_expect(is_equal_approx(float(CommandoFirearmValueUtils.get_dict(runtime.lingering_effects[2]).get("constrict_factor", 0.0)), 0.6), "net constrict input path should clamp active nets at the floor")
	_expect(net_audio.constrict_calls == 1, "net constrict input path should play netcome audio when available")
	_expect(net_audio.capture_calls == 0, "net constrict input path should not reuse capture audio when netcome audio is available")
	net_constrict_result = CommandoFirearmLingeringNetFieldState.apply_net_constrict_input(
		runtime.lingering_effects,
		{"left_pressed": true},
		1410,
		runtime.net_constrict_last_dir,
		runtime.net_constrict_last_tick_msec,
		CommandoFirearmRuntime.NET_CONSTRICT_MIN,
		CommandoFirearmRuntime.NET_CONSTRICT_STEP,
		CommandoFirearmRuntime.NET_CONSTRICT_WINDOW_MSEC,
		RefCounted.new()
	)
	runtime.lingering_effects = CommandoFirearmValueUtils.get_array(net_constrict_result.get("effects", runtime.lingering_effects))
	runtime.net_constrict_last_dir = int(net_constrict_result.get("last_dir", runtime.net_constrict_last_dir))
	runtime.net_constrict_last_tick_msec = int(net_constrict_result.get("last_tick_msec", runtime.net_constrict_last_tick_msec))
	_expect(is_equal_approx(float(CommandoFirearmValueUtils.get_dict(runtime.lingering_effects[0]).get("constrict_factor", 0.0)), 0.72), "net constrict input path should tolerate audio deps without constrict methods")
	_expect(net_audio.constrict_calls == 1, "net constrict input path should not call the previous audio dep again")
	_expect(net_audio.capture_calls == 0, "net constrict input path should keep capture audio untouched")
	_expect(CommandoFirearmLingeringNetFieldState.get_net_field_pos({"pos": Vector2(12.0, 34.0)}) == Vector2(12.0, 34.0), "net field pos owner should read effect positions")
	_expect(CommandoFirearmLingeringNetFieldState.get_net_field_pos({"pos": "bad"}) == Vector2.ZERO, "net field pos owner should fall back for invalid positions")
	_expect(is_equal_approx(CommandoFirearmLingeringNetFieldState.get_net_field_effect_width({"width": -5.0}, 280.0), 1.0), "net field width owner should clamp to a positive width")
	_expect(is_equal_approx(CommandoFirearmLingeringNetFieldState.get_net_field_effect_height({"height": 0.0}, 90.0), 1.0), "net field height owner should clamp to a positive height")
	_expect(CommandoFirearmLingeringNetFieldState.get_net_field_boss_pos({"boss_pos": Vector2(90.0, 45.0)}) == Vector2(90.0, 45.0), "net field boss-pos owner should read context boss positions")
	_expect(is_equal_approx(CommandoFirearmLingeringNetFieldState.get_net_field_boss_width({"boss_width": 44.0}), 44.0), "net field boss-width owner should use boss_width fallback")
	_expect(is_equal_approx(CommandoFirearmLingeringNetFieldState.get_net_field_boss_width({"boss_width": 44.0, "boss_paddle_width": 36.0}), 36.0), "net field boss-width owner should prefer paddle width")
	_expect(is_equal_approx(CommandoFirearmLingeringNetFieldState.get_net_field_boss_width({"boss_paddle_width": -8.0}), 1.0), "net field boss-width owner should clamp to a positive width")
	_expect(is_equal_approx(CommandoFirearmLingeringNetFieldState.get_net_field_min_boss_clamp_width(50.0), 60.0), "net min boss clamp width owner should preserve boss padding")
	_expect(is_equal_approx(CommandoFirearmLingeringNetFieldState.get_net_field_min_boss_clamp_width(-8.0), 11.0), "net min boss clamp width owner should clamp invalid boss widths")
	_expect(is_equal_approx(CommandoFirearmLingeringNetFieldState.get_net_field_constricted_width(80.0, 0.5), 40.0), "net constricted width owner should scale by constrict factor")
	_expect(is_equal_approx(CommandoFirearmLingeringNetFieldState.get_net_field_constricted_width(-8.0, 0.5), 0.5), "net constricted width owner should clamp invalid field widths before scaling")
	_expect(is_equal_approx(CommandoFirearmLingeringNetFieldState.get_net_field_clamp_width({"weapon_id": "net_gun"}, 80.0, 20.0), 80.0), "net clamp width owner should stay full width when not hooked")
	_expect(is_equal_approx(CommandoFirearmLingeringNetFieldState.get_net_field_clamp_width({
		"weapon_id": "net_gun",
		"hooked_player": true,
		"constrict_factor": 0.5,
	}, 80.0, 20.0), 40.0), "net clamp width owner should shrink hooked nets by constrict factor")
	_expect(is_equal_approx(CommandoFirearmLingeringNetFieldState.get_net_field_clamp_width({
		"weapon_id": "net_gun",
		"hooked_player": true,
		"constrict_factor": 0.1,
	}, 80.0, 50.0), 60.0), "net clamp width owner should keep enough width for boss paddle")
	_expect(CommandoFirearmLingeringNetFieldState.get_net_field_clamp_size({"weapon_id": "net_gun"}, 80.0, 0.0, 20.0) == Vector2(80.0, 1.0), "net clamp size owner should preserve width and clamp invalid heights")
	_expect(CommandoFirearmLingeringNetFieldState.get_net_field_clamp_origin(Vector2(100.0, 100.0), Vector2(80.0, 40.0)) == Vector2(60.0, 80.0), "net clamp origin owner should center clamp size around the field position")
	_expect(CommandoFirearmLingeringNetFieldState.get_net_field_clamp_rect({
		"weapon_id": "net_gun",
	}, Vector2(100.0, 100.0), 80.0, 40.0, 20.0) == Rect2(Vector2(60.0, 80.0), Vector2(80.0, 40.0)), "net clamp rect owner should center the full net field")
	_expect(CommandoFirearmLingeringNetFieldState.get_net_field_clamp_rect({
		"weapon_id": "net_gun",
		"hooked_player": true,
		"constrict_factor": 0.5,
	}, Vector2(100.0, 100.0), 80.0, 40.0, 20.0) == Rect2(Vector2(80.0, 80.0), Vector2(40.0, 40.0)), "net clamp rect owner should center the shrunken net field")
	var net_clamp_rect := Rect2(Vector2(60.0, 80.0), Vector2(80.0, 40.0))
	_expect(is_equal_approx(CommandoFirearmLingeringNetFieldState.get_net_field_safe_boss_width(-8.0), 1.0), "net clamp safe boss-width owner should clamp invalid widths")
	_expect(is_equal_approx(CommandoFirearmLingeringNetFieldState.get_net_field_safe_boss_width(20.0), 20.0), "net clamp safe boss-width owner should preserve positive widths")
	_expect(is_equal_approx(CommandoFirearmLingeringNetFieldState.get_net_field_boss_clamp_min_x(net_clamp_rect), 60.0), "net clamp min-x owner should use the clamp rect left edge")
	_expect(is_equal_approx(CommandoFirearmLingeringNetFieldState.get_net_field_boss_clamp_max_x(20.0, net_clamp_rect), 120.0), "net clamp max-x owner should reserve boss width at the right edge")
	_expect(is_equal_approx(CommandoFirearmLingeringNetFieldState.get_net_field_clamped_boss_x(20.0, 20.0, net_clamp_rect), 60.0), "net clamp boss-x owner should clamp left of the field")
	_expect(is_equal_approx(CommandoFirearmLingeringNetFieldState.get_net_field_clamped_boss_x(130.0, 20.0, net_clamp_rect), 120.0), "net clamp boss-x owner should clamp right of the field")
	_expect(is_equal_approx(CommandoFirearmLingeringNetFieldState.get_net_field_clamped_boss_x(100.0, 20.0, net_clamp_rect), 100.0), "net clamp boss-x owner should preserve in-range positions")
	_expect(CommandoFirearmLingeringNetFieldState.get_net_field_clamped_boss_pos(Vector2(20.0, 90.0), 20.0, net_clamp_rect) == Vector2(60.0, 90.0), "net clamp boss-pos owner should clamp x while preserving y")
	_expect(CommandoFirearmLingeringNetFieldState.get_net_field_clamped_boss_pos(Vector2(100.0, 90.0), 20.0, net_clamp_rect) == Vector2(100.0, 90.0), "net clamp boss-pos owner should preserve in-range positions")
	_expect(CommandoFirearmLingeringNetFieldState.should_emit_net_field_boss_clamp_result(Vector2(20.0, 90.0), Vector2(60.0, 90.0)), "net clamp result predicate owner should emit changed boss positions")
	_expect(not CommandoFirearmLingeringNetFieldState.should_emit_net_field_boss_clamp_result(Vector2(100.0, 90.0), Vector2(100.0, 90.0)), "net clamp result predicate owner should ignore unchanged boss positions")
	var empty_clamp_result: Dictionary = CommandoFirearmLingeringNetFieldState.build_net_field_boss_clamp_result(Vector2(100.0, 90.0), 20.0, net_clamp_rect)
	_expect(empty_clamp_result.is_empty(), "net clamp result owner should stay empty when the boss is already inside the field")
	var left_clamp_result: Dictionary = CommandoFirearmLingeringNetFieldState.build_net_field_boss_clamp_result(Vector2(20.0, 90.0), 20.0, net_clamp_rect)
	_expect(bool(left_clamp_result.get("commando_net_gun_boss_clamped", false)), "net clamp result owner should flag clamped boss positions")
	_expect(left_clamp_result.get("boss_pos", Vector2.ZERO) == Vector2(60.0, 90.0), "net clamp result owner should return the clamped boss position")
	_expect(left_clamp_result.get("commando_net_gun_clamp_rect", Rect2()) == net_clamp_rect, "net clamp result owner should preserve the clamp rect")
	var clamp_result: Dictionary = CommandoFirearmLingeringNetFieldState.apply_net_field_boss_clamp({
		"weapon_id": "net_gun",
		"boss_trapped": true,
		"pos": Vector2(100.0, 100.0),
		"width": 80.0,
		"height": 40.0,
	}, {
		"boss_pos": Vector2(20.0, 90.0),
		"boss_paddle_width": 20.0,
	}, CommandoFirearmRuntime.NET_GUN_WIDTH, CommandoFirearmRuntime.NET_GUN_MIN_HEIGHT)
	_expect(bool(clamp_result.get("commando_net_gun_boss_clamped", false)), "net boss clamp should return a clamp result for trapped live nets")
	_expect(CommandoFirearmLingeringNetFieldState.apply_net_field_boss_clamp({
		"weapon_id": "net_gun",
		"boss_trapped": true,
		"dissolve": true,
	}, {"boss_pos": Vector2(20.0, 90.0)}, CommandoFirearmRuntime.NET_GUN_WIDTH, CommandoFirearmRuntime.NET_GUN_MIN_HEIGHT).is_empty(), "net boss clamp should ignore dissolving nets")
	var lingering_timer_effect := {
		"timer_frames": 10.0,
		"phase": 2.0,
		"rope_broken": true,
		"rope_snap_timer": 3.0,
	}
	_expect(is_equal_approx(CommandoFirearmLingeringEffectState.get_timer(lingering_timer_effect), 10.0), "lingering current-timer owner should read explicit timers")
	_expect(is_equal_approx(CommandoFirearmLingeringEffectState.get_timer({}), 0.0), "lingering current-timer owner should default missing timers to zero")
	_expect(is_equal_approx(CommandoFirearmLingeringEffectState.get_phase(lingering_timer_effect), 2.0), "lingering current-phase owner should read explicit phases")
	_expect(is_equal_approx(CommandoFirearmLingeringEffectState.get_phase({}), 0.0), "lingering current-phase owner should default missing phases to zero")
	_expect(is_equal_approx(CommandoFirearmLingeringEffectState.get_rope_snap_timer(lingering_timer_effect), 3.0), "lingering rope-snap current-timer owner should read explicit snap timers")
	_expect(is_equal_approx(CommandoFirearmLingeringEffectState.get_rope_snap_timer({}), 0.0), "lingering rope-snap current-timer owner should default missing snap timers to zero")
	_expect(CommandoFirearmLingeringEffectState.has_timer(0.1), "lingering positive-timer owner should accept positive timers")
	_expect(not CommandoFirearmLingeringEffectState.has_timer(0.0), "lingering positive-timer owner should reject zero timers")
	_expect(is_equal_approx(CommandoFirearmLingeringEffectState.get_timer_step(-5.0), 0.0), "lingering timer-step owner should clamp negative steps")
	_expect(is_equal_approx(CommandoFirearmLingeringEffectState.get_timer_step(4.0), 4.0), "lingering timer-step owner should preserve positive steps")
	_expect(is_equal_approx(CommandoFirearmLingeringEffectState.get_next_timer(lingering_timer_effect, 4.0), 6.0), "lingering next-timer owner should reduce active timers")
	_expect(is_equal_approx(CommandoFirearmLingeringEffectState.get_next_phase(lingering_timer_effect, 4.0, CommandoFirearmRuntime.LINGERING_EFFECT_PHASE_STEP), 2.48), "lingering next-phase owner should advance effect phase")
	_expect(is_equal_approx(CommandoFirearmLingeringEffectState.get_phase_step(4.0, CommandoFirearmRuntime.LINGERING_EFFECT_PHASE_STEP), 0.48), "lingering phase-step owner should preserve phase advance")
	_expect(CommandoFirearmLingeringEffectState.should_advance_rope_snap_timer(lingering_timer_effect), "lingering rope-snap predicate owner should accept broken ropes")
	_expect(is_equal_approx(CommandoFirearmLingeringEffectState.get_next_rope_snap_timer(lingering_timer_effect, 4.0), 0.0), "lingering rope-snap next-timer owner should clamp expired snap timers")
	CommandoFirearmLingeringEffectState.advance_timers(lingering_timer_effect, 4.0, CommandoFirearmRuntime.LINGERING_EFFECT_PHASE_STEP)
	_expect(is_equal_approx(float(lingering_timer_effect.get("timer_frames", 0.0)), 6.0), "lingering timer owner should reduce active timers by the frame step")
	_expect(is_equal_approx(float(lingering_timer_effect.get("phase", 0.0)), 2.48), "lingering timer owner should advance phase by the frame step")
	_expect(is_equal_approx(float(lingering_timer_effect.get("rope_snap_timer", 0.0)), 0.0), "lingering timer owner should clamp rope snap timers at zero")
	CommandoFirearmLingeringEffectState.advance_timers(lingering_timer_effect, -5.0, CommandoFirearmRuntime.LINGERING_EFFECT_PHASE_STEP)
	_expect(is_equal_approx(float(lingering_timer_effect.get("timer_frames", 0.0)), 6.0), "lingering timer owner should ignore negative frame steps")
	var plain_lingering_timer_effect := {
		"timer_frames": 2.0,
		"phase": 0.5,
		"rope_snap_timer": 7.0,
	}
	CommandoFirearmLingeringEffectState.advance_timers(plain_lingering_timer_effect, 4.0, CommandoFirearmRuntime.LINGERING_EFFECT_PHASE_STEP)
	_expect(is_equal_approx(float(plain_lingering_timer_effect.get("timer_frames", 0.0)), 0.0), "lingering timer owner should clamp expired timers at zero")
	_expect(is_equal_approx(float(plain_lingering_timer_effect.get("rope_snap_timer", 0.0)), 7.0), "lingering timer owner should not touch rope timers unless the rope is broken")
	_expect(CommandoFirearmLingeringEffectState.is_fire_zone({"kind": "fire_zone"}), "lingering fire-zone owner should recognize fire zones")
	_expect(not CommandoFirearmLingeringEffectState.is_fire_zone({"kind": "net_field"}), "lingering fire-zone owner should reject other effect kinds")
	var fire_zone_frame_effect := {
		"kind": "fire_zone",
		"timer_frames": 12.0,
		"phase": 1.0,
		"width": 80.0,
		"height": 40.0,
		"id": 3,
	}
	CommandoFirearmLingeringEffectState.advance_timers(fire_zone_frame_effect, 2.0, CommandoFirearmRuntime.LINGERING_EFFECT_PHASE_STEP)
	fire_zone_frame_effect["flames"] = CommandoFirearmLingeringFireFlameState.get_flames_for_frame(fire_zone_frame_effect, 2.0)
	_expect(is_equal_approx(float(fire_zone_frame_effect.get("timer_frames", 0.0)), 10.0), "lingering frame owners should advance timers")
	_expect(is_equal_approx(float(fire_zone_frame_effect.get("phase", 0.0)), 1.24), "lingering frame owners should advance effect phase")
	_expect(CommandoFirearmValueUtils.get_array(fire_zone_frame_effect.get("flames", [])).size() == fire_flame_count, "lingering frame owners should build fire-zone flames")
	_expect(CommandoFirearmLingeringFireFlameState.get_flames({"flames": [{"lifetime": 3.0}]}).size() == 1, "fire flames owner reader should preserve valid flame arrays")
	_expect(CommandoFirearmLingeringFireFlameState.get_flames({"flames": "bad"}).is_empty(), "fire flames owner reader should reject invalid flame arrays")
	_expect(CommandoFirearmLingeringFireFlameState.should_seed_flames([]), "fire flames owner seed predicate should accept empty flame arrays")
	_expect(not CommandoFirearmLingeringFireFlameState.should_seed_flames([{"lifetime": 3.0}]), "fire flames owner seed predicate should reject existing flame arrays")
	var expired_fire_flame := {
		"offset": Vector2.ZERO,
		"size": 4.0,
		"lifetime": 1.0,
		"phase": 2.0,
	}
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_flame_current_lifetime(expired_fire_flame), 1.0), "fire flame current-lifetime owner should read explicit lifetimes")
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_flame_current_lifetime({}), 0.0), "fire flame current-lifetime owner should default missing lifetimes to zero")
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_flame_current_phase(expired_fire_flame), 2.0), "fire flame current-phase owner should read explicit phases")
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_flame_current_phase({}), 0.0), "fire flame current-phase owner should default missing phases to zero")
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_flame_phase_step(2.0), 0.16), "fire flame phase-step owner should preserve phase advance")
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_flame_next_lifetime(expired_fire_flame, 2.0), -1.0), "fire flame next-lifetime owner should subtract frame steps")
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_flame_next_phase(expired_fire_flame, 2.0), 2.16), "fire flame next-phase owner should advance by the frame step")
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_flame_next_lifetime({}, 2.0), -2.0), "fire flame next-lifetime owner should default missing lifetimes to zero")
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_flame_next_phase({}, 2.0), 0.16), "fire flame next-phase owner should default missing phases to zero")
	_expect(CommandoFirearmLingeringFireFlameState.should_reset_flame(0.0), "fire flame reset predicate owner should include zero lifetimes")
	_expect(CommandoFirearmLingeringFireFlameState.should_reset_flame(-0.01), "fire flame reset predicate owner should include negative lifetimes")
	_expect(not CommandoFirearmLingeringFireFlameState.should_reset_flame(0.01), "fire flame reset predicate owner should reject positive lifetimes")
	_expect(CommandoFirearmLingeringFireFlameState.get_effect_id({"id": 3}) == 3, "fire flame effect-id owner should read explicit ids")
	_expect(CommandoFirearmLingeringFireFlameState.get_effect_id({}) == 0, "fire flame effect-id owner should default missing ids to zero")
	_expect(CommandoFirearmLingeringFireFlameState.get_flame_reset_angle_index(2, {"id": 3}) == 5, "fire flame reset-angle-index owner should include the effect id")
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_flame_reset_angle(2, {"id": 3}), TAU / 3.0), "fire flame reset-angle owner should include the effect id")
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_flame_reset_radius_x(80.0), 27.2), "fire flame reset-radius x owner should preserve reseed x radii")
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_flame_reset_radius_y(40.0), 15.2), "fire flame reset-radius y owner should preserve reseed y radii")
	_expect(CommandoFirearmLingeringFireFlameState.get_flame_reset_radius(80.0, 40.0).is_equal_approx(Vector2(27.2, 15.2)), "fire flame reset-radius owner should preserve reseed radii")
	_expect(CommandoFirearmLingeringFireFlameState.get_flame_reset_offset(2, {"id": 3}, 80.0, 40.0).is_equal_approx(Vector2(-13.6, 13.163586)), "fire flame reset-offset owner should preserve reset positions")
	_expect(CommandoFirearmLingeringFireFlameState.get_flame_reset_size_pattern_value(2) == 0, "fire flame reset-size-pattern owner should preserve reseed size spacing")
	_expect(CommandoFirearmLingeringFireFlameState.get_flame_reset_size_offset(2) == 0, "fire flame reset-size-offset owner should preserve reseed size offsets")
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_flame_reset_size(2), 9.0), "fire flame reset-size owner should preserve reseed sizes")
	_expect(CommandoFirearmLingeringFireFlameState.get_flame_reset_lifetime_pattern_value(2) == 10, "fire flame reset-lifetime-pattern owner should preserve reseed lifetime spacing")
	_expect(CommandoFirearmLingeringFireFlameState.get_flame_reset_lifetime_offset(2) == 10, "fire flame reset-lifetime-offset owner should preserve reseed lifetime offsets")
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_flame_reset_lifetime(2), 34.0), "fire flame reset-lifetime owner should preserve reseed lifetimes")
	var reset_values_fire_flame := {}
	CommandoFirearmLingeringFireFlameState.apply_flame_reset_values(reset_values_fire_flame, 2, {"id": 3}, 80.0, 40.0)
	_expect(CommandoFirearmValueUtils.get_vector2(reset_values_fire_flame.get("offset", Vector2.ZERO), Vector2.ZERO).is_equal_approx(Vector2(-13.6, 13.163586)), "fire flame reset-values owner should apply reset offsets")
	_expect(is_equal_approx(float(reset_values_fire_flame.get("size", 0.0)), 9.0), "fire flame reset-values owner should apply reset sizes")
	var reset_motion_fire_flame := {
		"offset": Vector2.ZERO,
		"size": 4.0,
	}
	var reset_motion_lifetime: float = CommandoFirearmLingeringFireFlameState.apply_flame_motion(reset_motion_fire_flame, 2, {"id": 3}, -1.0, 2.16, 2.0, 80.0, 40.0)
	_expect(is_equal_approx(reset_motion_lifetime, 34.0), "fire flame motion owner should return reset lifetimes")
	_expect(is_equal_approx(float(reset_motion_fire_flame.get("size", 0.0)), 9.0), "fire flame motion owner should apply reset sizes")
	var reset_path_fire_flame := {
		"offset": Vector2.ZERO,
		"size": 4.0,
	}
	var reset_path_lifetime: float = CommandoFirearmLingeringFireFlameState.apply_flame_reset_motion(reset_path_fire_flame, 2, {"id": 3}, 80.0, 40.0)
	_expect(is_equal_approx(reset_path_lifetime, 34.0), "fire flame reset-motion owner should return reset lifetimes")
	_expect(is_equal_approx(float(reset_path_fire_flame.get("size", 0.0)), 9.0), "fire flame reset-motion owner should apply reset sizes")
	var written_fire_flame: Dictionary = CommandoFirearmLingeringFireFlameState.apply_flame_frame_values({}, 12.0, 3.5)
	_expect(is_equal_approx(float(written_fire_flame.get("lifetime", 0.0)), 12.0), "fire flame frame-value owner should write lifetimes")
	_expect(is_equal_approx(float(written_fire_flame.get("phase", 0.0)), 3.5), "fire flame frame-value owner should write phases")
	var reset_fire_flame: Dictionary = CommandoFirearmLingeringFireFlameState.advance_flame(expired_fire_flame, 2, {"id": 3}, 2.0, 80.0, 40.0)
	_expect(is_equal_approx(float(reset_fire_flame.get("lifetime", 0.0)), 34.0), "fire flame frame owner should reseed expired lifetimes")
	_expect(is_equal_approx(float(reset_fire_flame.get("phase", 0.0)), 2.16), "fire flame frame owner should still advance expired flame phase")
	_expect(is_equal_approx(float(reset_fire_flame.get("size", 0.0)), 9.0), "fire flame frame owner should reseed expired flame size")
	_expect(not CommandoFirearmValueUtils.get_vector2(reset_fire_flame.get("offset", Vector2.ZERO), Vector2.ZERO).is_equal_approx(Vector2.ZERO), "fire flame frame owner should reseed expired flame offset")
	var drifting_fire_flame := {
		"offset": Vector2(50.0, -50.0),
		"size": 10.0,
		"lifetime": 20.0,
		"phase": 1.0,
	}
	var drift_step: Vector2 = CommandoFirearmLingeringFireFlameState.get_flame_drift_step(1.16, 2.0)
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_flame_drift_wave_offset(1.16, 2.0), sin(1.16) * 0.44), "fire flame drift-wave owner should preserve horizontal wave drift")
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_flame_drift_rise_offset(2.0), -0.32), "fire flame drift-rise owner should preserve upward drift")
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_flame_offset_bound(80.0), 38.4), "fire flame offset-bound owner should preserve clamp bounds")
	_expect(CommandoFirearmLingeringFireFlameState.get_flame_current_offset(drifting_fire_flame).is_equal_approx(Vector2(50.0, -50.0)), "fire flame current-offset owner should read explicit offsets")
	_expect(CommandoFirearmLingeringFireFlameState.get_flame_current_offset({"offset": "bad"}).is_equal_approx(Vector2.ZERO), "fire flame current-offset owner should default invalid offsets")
	_expect(is_equal_approx(drift_step.x, sin(1.16) * 0.44), "fire flame drift-step helper should preserve horizontal wave drift")
	_expect(is_equal_approx(drift_step.y, -0.32), "fire flame drift-step helper should preserve upward drift")
	_expect(CommandoFirearmLingeringFireFlameState.get_flame_unclamped_drift_offset(drifting_fire_flame, 1.16, 2.0).is_equal_approx(Vector2(50.0, -50.0) + drift_step), "fire flame unclamped drift-offset owner should add drift step to the current offset")
	_expect(CommandoFirearmLingeringFireFlameState.get_flame_unclamped_drift_offset({}, 0.0, 2.0).is_equal_approx(Vector2(0.0, -0.32)), "fire flame unclamped drift-offset owner should default missing offsets before applying drift")
	_expect(CommandoFirearmLingeringFireFlameState.clamp_flame_offset(Vector2(50.0, -50.0), 80.0, 40.0).is_equal_approx(Vector2(38.4, -19.2)), "fire flame offset clamp owner should preserve effect bounds")
	_expect(CommandoFirearmLingeringFireFlameState.get_flame_drift_offset(drifting_fire_flame, 1.16, 2.0, 80.0, 40.0).is_equal_approx(Vector2(38.4, -19.2)), "fire flame drift-offset owner should clamp active drift inside the effect")
	_expect(CommandoFirearmLingeringFireFlameState.get_flame_drift_offset({}, 0.0, 2.0, 80.0, 40.0).is_equal_approx(Vector2(0.0, -0.32)), "fire flame drift-offset owner should default missing offsets to zero")
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_flame_current_size(drifting_fire_flame), 10.0), "fire flame current-size owner should read explicit sizes")
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_flame_current_size({}), 10.0), "fire flame current-size owner should default missing sizes")
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_flame_size_decay(2.0), 0.970225), "fire flame size-decay owner should preserve decay rate")
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_flame_unclamped_drift_size(drifting_fire_flame, 2.0), 9.70225), "fire flame unclamped drift-size owner should apply decay to current size")
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_flame_unclamped_drift_size({"size": 1.0}, 2.0), 0.970225), "fire flame unclamped drift-size owner should preserve pre-clamp small sizes")
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.clamp_flame_drift_size(1.0), 3.0), "fire flame size clamp owner should preserve minimum size")
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_flame_drift_size(drifting_fire_flame, 2.0), 9.70225), "fire flame drift-size owner should decay active flame size")
	_expect(is_equal_approx(CommandoFirearmLingeringFireFlameState.get_flame_drift_size({"size": 1.0}, 2.0), 3.0), "fire flame drift-size owner should clamp size at the floor")
	var drift_motion_fire_flame := {
		"offset": Vector2(50.0, -50.0),
		"size": 10.0,
	}
	var drift_motion_lifetime: float = CommandoFirearmLingeringFireFlameState.apply_flame_motion(drift_motion_fire_flame, 1, {"id": 3}, 18.0, 1.16, 2.0, 80.0, 40.0)
	_expect(is_equal_approx(drift_motion_lifetime, 18.0), "fire flame motion owner should preserve active lifetimes")
	_expect(CommandoFirearmValueUtils.get_vector2(drift_motion_fire_flame.get("offset", Vector2.ZERO), Vector2.ZERO).is_equal_approx(Vector2(38.4, -19.2)), "fire flame motion owner should apply active drift")
	var drift_path_fire_flame := {
		"offset": Vector2(50.0, -50.0),
		"size": 10.0,
	}
	var drift_path_lifetime: float = CommandoFirearmLingeringFireFlameState.apply_flame_drift_motion(drift_path_fire_flame, 1.16, 2.0, 80.0, 40.0, 18.0)
	_expect(is_equal_approx(drift_path_lifetime, 18.0), "fire flame drift-motion helper should preserve active lifetimes")
	_expect(CommandoFirearmValueUtils.get_vector2(drift_path_fire_flame.get("offset", Vector2.ZERO), Vector2.ZERO).is_equal_approx(Vector2(38.4, -19.2)), "fire flame drift-motion helper should apply active drift")
	var drifted_fire_flame: Dictionary = CommandoFirearmLingeringFireFlameState.advance_flame(drifting_fire_flame, 1, {"id": 3}, 2.0, 80.0, 40.0)
	_expect(is_equal_approx(float(drifted_fire_flame.get("lifetime", 0.0)), 18.0), "fire flame frame owner should reduce active lifetimes")
	_expect(is_equal_approx(float(drifted_fire_flame.get("phase", 0.0)), 1.16), "fire flame frame owner should advance active flame phase")
	var drifted_fire_offset: Vector2 = CommandoFirearmValueUtils.get_vector2(drifted_fire_flame.get("offset", Vector2.ZERO), Vector2.ZERO)
	_expect(is_equal_approx(drifted_fire_offset.x, 38.4), "fire flame frame owner should clamp drift x inside the effect width")
	_expect(is_equal_approx(drifted_fire_offset.y, -19.2), "fire flame frame owner should clamp drift y inside the effect height")
	_expect(float(drifted_fire_flame.get("size", 0.0)) < 10.0, "fire flame frame owner should decay active flame size")
	var advanced_fire_flames: Array = CommandoFirearmLingeringFireFlameState.advance_flames([
		{
			"offset": Vector2(0.0, 0.0),
			"size": 10.0,
			"lifetime": 20.0,
			"phase": 1.0,
		},
		{
			"offset": Vector2.ZERO,
			"size": 4.0,
			"lifetime": 1.0,
			"phase": 2.0,
		},
	], {"id": 3, "width": 80.0, "height": 40.0}, 2.0)
	_expect(advanced_fire_flames.size() == 2, "fire flames batch owner should preserve flame count")
	_expect(is_equal_approx(float((advanced_fire_flames[0] as Dictionary).get("lifetime", 0.0)), 18.0), "fire flames batch owner should advance active flames")
	_expect(is_equal_approx(float((advanced_fire_flames[1] as Dictionary).get("lifetime", 0.0)), 29.0), "fire flames batch owner should reset expired flames by index")
	_expect(is_equal_approx(float((advanced_fire_flames[1] as Dictionary).get("size", 0.0)), 16.0), "fire flames batch owner should apply reset sizes by index")
	_expect(CommandoFirearmLingeringFireFlameState.get_flame_at_index(advanced_fire_flames, 0).has("lifetime"), "fire flame indexed owner should preserve dictionary entries")
	_expect(CommandoFirearmLingeringFireFlameState.get_flame_at_index(["bad"], 0).is_empty(), "fire flame indexed owner should reject non-dictionary entries")
	_expect(CommandoFirearmLingeringFireFlameState.get_flame_at_index(advanced_fire_flames, -1).is_empty(), "fire flame indexed owner should reject negative indices")
	_expect(CommandoFirearmLingeringFireFlameState.get_flame_at_index(advanced_fire_flames, 2).is_empty(), "fire flame indexed owner should reject out-of-range indices")
	var seeded_fire_flames: Array = CommandoFirearmLingeringFireFlameState.get_flames_for_frame({"width": 80.0, "height": 40.0}, 2.0)
	_expect(seeded_fire_flames.size() == fire_flame_count, "fire flames frame owner should seed missing flame arrays")
	var invalid_fire_flames: Array = CommandoFirearmLingeringFireFlameState.get_flames_for_frame({"flames": "bad", "width": 80.0, "height": 40.0}, 2.0)
	_expect(invalid_fire_flames.size() == fire_flame_count, "fire flames frame owner should seed invalid flame arrays")
	var advanced_frame_fire_flames: Array = CommandoFirearmLingeringFireFlameState.get_flames_for_frame({
		"flames": [
			{
				"offset": Vector2.ZERO,
				"size": 10.0,
				"lifetime": 20.0,
				"phase": 1.0,
			},
		],
		"id": 3,
		"width": 80.0,
		"height": 40.0,
	}, 2.0)
	_expect(advanced_frame_fire_flames.size() == 1, "fire flames frame owner should keep existing flame arrays")
	_expect(is_equal_approx(float((advanced_frame_fire_flames[0] as Dictionary).get("lifetime", 0.0)), 18.0), "fire flames frame owner should advance existing flame arrays")
	var non_fire_frame_effect := {
		"kind": "net_field",
		"timer_frames": 8.0,
		"phase": 0.0,
	}
	CommandoFirearmLingeringEffectState.advance_timers(non_fire_frame_effect, 2.0, CommandoFirearmRuntime.LINGERING_EFFECT_PHASE_STEP)
	_expect(is_equal_approx(float(non_fire_frame_effect.get("timer_frames", 0.0)), 6.0), "lingering frame owner should advance non-fire timers")
	_expect(not non_fire_frame_effect.has("flames"), "lingering frame owner should not build flames for non-fire effects")
	CommandoFirearmLingeringEffectState.advance_timers(non_fire_frame_effect, -5.0, CommandoFirearmRuntime.LINGERING_EFFECT_PHASE_STEP)
	_expect(is_equal_approx(float(non_fire_frame_effect.get("timer_frames", 0.0)), 6.0), "lingering frame owner should ignore negative frame steps")
	_expect(is_equal_approx(float(non_fire_frame_effect.get("phase", 0.0)), 0.24), "lingering frame owner should not advance phase for negative frame steps")
	_expect(CommandoFirearmLingeringEffectState.is_active({"timer_frames": 0.1}), "lingering active owner should accept positive timers")
	_expect(not CommandoFirearmLingeringEffectState.is_active({"timer_frames": 0.0}), "lingering active owner should reject expired timers")
	_expect(not CommandoFirearmLingeringEffectState.is_active({}), "lingering active owner should reject missing timers")
	var lingering_merge_result := {"kept": "result"}
	var lingering_merge_context := {"kept": "context"}
	_expect(not CommandoFirearmLingeringEffectState.has_clamp_result({}), "lingering clamp-result predicate owner should reject empty payloads")
	_expect(CommandoFirearmLingeringEffectState.has_clamp_result({"boss_pos": Vector2(60.0, 90.0)}), "lingering clamp-result predicate owner should accept payloads")
	var clamp_payload_target := {"boss_pos": Vector2.ZERO}
	CommandoFirearmLingeringEffectState.apply_clamp_payload(clamp_payload_target, {"boss_pos": Vector2(60.0, 90.0)})
	_expect(clamp_payload_target.get("boss_pos", Vector2.ZERO) == Vector2(60.0, 90.0), "lingering clamp-payload owner should merge clamp data into targets")
	CommandoFirearmLingeringEffectState.merge_clamp_result(lingering_merge_result, lingering_merge_context, {})
	_expect(lingering_merge_result == {"kept": "result"}, "lingering clamp merge owner should ignore empty clamp results")
	_expect(lingering_merge_context == {"kept": "context"}, "lingering clamp merge owner should leave context unchanged for empty clamp results")
	CommandoFirearmLingeringEffectState.merge_clamp_result(lingering_merge_result, lingering_merge_context, {
		"boss_pos": Vector2(60.0, 90.0),
		"commando_net_gun_boss_clamped": true,
	})
	_expect(lingering_merge_result.get("boss_pos", Vector2.ZERO) == Vector2(60.0, 90.0), "lingering clamp merge owner should merge clamp data into update results")
	_expect(bool(lingering_merge_context.get("commando_net_gun_boss_clamped", false)), "lingering clamp merge owner should merge clamp data into context")
	var active_lingering_result := {}
	var active_lingering_context := {
		"boss_pos": Vector2(20.0, 90.0),
		"boss_paddle_width": 20.0,
	}
	var active_lingering_effect := {
		"weapon_id": "net_gun",
		"boss_trapped": true,
		"pos": Vector2(100.0, 100.0),
		"width": 80.0,
		"height": 40.0,
		"timer_frames": 10.0,
		"status_id": "",
	}
	var active_clamp_result: Dictionary = CommandoFirearmLingeringNetFieldState.apply_net_field_boss_clamp(active_lingering_effect, active_lingering_context, 280.0, 90.0)
	_expect(bool(active_clamp_result.get("commando_net_gun_boss_clamped", false)), "active lingering clamp-result owner should preserve live net clamps")
	runtime.lingering_effects = [{
		"weapon_id": "net_gun",
		"boss_trapped": true,
		"pos": Vector2(100.0, 100.0),
		"width": 80.0,
		"height": 40.0,
		"timer_frames": 10.0,
		"status_id": "",
	}]
	runtime.lingering_effects[0] = active_lingering_effect
	_apply_active_runtime_lingering_effect(runtime, 0, CommandoFirearmValueUtils.get_dict(runtime.lingering_effects[0]), 1.0, active_lingering_context, {}, active_lingering_result)
	_expect(bool(active_lingering_result.get("commando_net_gun_boss_clamped", false)), "active lingering helper should merge clamp results into update results")
	_expect(active_lingering_context.get("boss_pos", Vector2.ZERO) == Vector2(60.0, 90.0), "active lingering helper should merge clamp results into context")
	_expect(CommandoFirearmValueUtils.get_dict(runtime.lingering_effects[0]).get("pos", Vector2.ZERO) == Vector2(100.0, 100.0), "active lingering helper should store the updated effect back into the array")
	_expect(CommandoFirearmLingeringStatusState.get_lingering_effect_rect_pos({"pos": Vector2(100.0, 100.0)}) == Vector2(100.0, 100.0), "lingering effect rect-pos helper should read explicit positions")
	_expect(CommandoFirearmLingeringStatusState.get_lingering_effect_rect_pos({"pos": "bad"}) == Vector2.ZERO, "lingering effect rect-pos helper should default invalid positions")
	_expect(is_equal_approx(CommandoFirearmLingeringStatusState.get_lingering_effect_rect_width({"width": -5.0}), 1.0), "lingering effect rect-width helper should clamp invalid widths")
	_expect(is_equal_approx(CommandoFirearmLingeringStatusState.get_lingering_effect_rect_height({"height": 0.0}), 1.0), "lingering effect rect-height helper should clamp invalid heights")
	_expect(CommandoFirearmLingeringStatusState.get_lingering_effect_rect_size({"width": 80.0, "height": 40.0}) == Vector2(80.0, 40.0), "lingering effect rect-size helper should preserve explicit sizes")
	_expect(CommandoFirearmLingeringStatusState.get_lingering_effect_rect({
		"pos": Vector2(100.0, 100.0),
		"width": 80.0,
		"height": 40.0,
	}) == Rect2(Vector2(60.0, 80.0), Vector2(80.0, 40.0)), "lingering effect rect helper should center effect rects on their position")
	_expect(CommandoFirearmLingeringStatusState.get_lingering_effect_rect({
		"pos": Vector2(10.0, 20.0),
		"width": -5.0,
		"height": 0.0,
	}) == Rect2(Vector2(9.5, 19.5), Vector2(1.0, 1.0)), "lingering effect rect helper should clamp effect size")
	_expect(CommandoFirearmLingeringStatusState.get_lingering_boss_rect_pos({"boss_pos": Vector2(70.0, 40.0)}) == Vector2(70.0, 40.0), "lingering boss rect-pos helper should read explicit positions")
	_expect(CommandoFirearmLingeringStatusState.get_lingering_boss_rect_pos({"boss_pos": "bad"}) == Vector2.ZERO, "lingering boss rect-pos helper should default invalid positions")
	_expect(is_equal_approx(CommandoFirearmLingeringStatusState.get_lingering_boss_rect_width({"boss_width": 44.0}), 44.0), "lingering boss rect-width helper should use boss-width fallback")
	_expect(is_equal_approx(CommandoFirearmLingeringStatusState.get_lingering_boss_rect_width({"boss_width": 44.0, "boss_paddle_width": 30.0}), 30.0), "lingering boss rect-width helper should prefer paddle width")
	_expect(is_equal_approx(CommandoFirearmLingeringStatusState.get_lingering_boss_rect_height({"boss_hitbox_height": -9.0}), 1.0), "lingering boss rect-height helper should clamp invalid heights")
	_expect(CommandoFirearmLingeringStatusState.get_lingering_boss_rect_size({"boss_paddle_width": 30.0, "boss_hitbox_height": 24.0}) == Vector2(30.0, 24.0), "lingering boss rect-size helper should preserve paddle dimensions")
	_expect(CommandoFirearmLingeringStatusState.get_lingering_boss_rect({
		"boss_pos": Vector2(70.0, 40.0),
		"boss_paddle_width": 30.0,
		"boss_hitbox_height": 24.0,
	}) == Rect2(Vector2(70.0, 40.0), Vector2(30.0, 24.0)), "lingering boss rect helper should use boss paddle dimensions")
	_expect(CommandoFirearmLingeringStatusState.get_lingering_boss_rect({
		"boss_pos": Vector2(70.0, 40.0),
		"boss_width": 44.0,
		"boss_hitbox_height": -9.0,
	}) == Rect2(Vector2(70.0, 40.0), Vector2(44.0, 1.0)), "lingering boss rect helper should use fallback width and clamp height")
	_expect(CommandoFirearmLingeringStatusState.do_lingering_rects_intersect(
		Rect2(Vector2(60.0, 80.0), Vector2(80.0, 40.0)),
		Rect2(Vector2(90.0, 90.0), Vector2(20.0, 20.0))
	), "lingering rect intersection helper should detect overlaps")
	_expect(not CommandoFirearmLingeringStatusState.do_lingering_rects_intersect(
		Rect2(Vector2(90.0, 90.0), Vector2(20.0, 20.0)),
		Rect2(Vector2(200.0, 200.0), Vector2(20.0, 20.0))
	), "lingering rect intersection helper should reject separated rects")
	_expect(CommandoFirearmLingeringStatusState.lingering_effect_hits_boss({
		"pos": Vector2(100.0, 100.0),
		"width": 80.0,
		"height": 40.0,
	}, {
		"boss_pos": Vector2(90.0, 90.0),
		"boss_paddle_width": 20.0,
		"boss_hitbox_height": 20.0,
	}), "lingering hit helper should detect intersecting rects")
	_expect(not CommandoFirearmLingeringStatusState.lingering_effect_hits_boss({
		"pos": Vector2(100.0, 100.0),
		"width": 20.0,
		"height": 20.0,
	}, {
		"boss_pos": Vector2(200.0, 200.0),
		"boss_paddle_width": 20.0,
		"boss_hitbox_height": 20.0,
	}), "lingering hit helper should reject separated rects")
	var lingering_status_cooldown := {"status_cooldown_frames": 5.0}
	_expect(is_equal_approx(CommandoFirearmLingeringStatusState.get_status_cooldown(lingering_status_cooldown), 5.0), "lingering status cooldown reader should read cooldowns")
	_expect(is_equal_approx(CommandoFirearmLingeringStatusState.get_status_cooldown({}), 0.0), "lingering status cooldown reader should default missing cooldowns")
	_expect(is_equal_approx(CommandoFirearmLingeringStatusState.get_status_cooldown({"status_cooldown_frames": -3.0}), 0.0), "lingering status cooldown reader should clamp negative cooldowns")
	_expect(is_equal_approx(CommandoFirearmLingeringStatusState.get_next_status_cooldown(lingering_status_cooldown, 2.0), 3.0), "lingering status cooldown next helper should reduce cooldowns")
	_expect(is_equal_approx(CommandoFirearmLingeringStatusState.get_next_status_cooldown(lingering_status_cooldown, 0.0), 5.0), "lingering status cooldown next helper should ignore negative frame steps")
	_expect(is_equal_approx(CommandoFirearmLingeringStatusState.get_next_status_cooldown(lingering_status_cooldown, 9.0), 0.0), "lingering status cooldown next helper should clamp at zero")
	var stored_status_cooldown := {}
	_expect(is_equal_approx(CommandoFirearmLingeringStatusState.set_status_cooldown(stored_status_cooldown, 4.0), 4.0), "lingering status cooldown setter should return stored cooldowns")
	_expect(is_equal_approx(float(stored_status_cooldown.get("status_cooldown_frames", 0.0)), 4.0), "lingering status cooldown setter should store cooldowns")
	_expect(is_equal_approx(CommandoFirearmLingeringStatusState.advance_status_cooldown(lingering_status_cooldown, 2.0), 3.0), "lingering status cooldown helper should reduce cooldowns")
	_expect(is_equal_approx(float(lingering_status_cooldown.get("status_cooldown_frames", 0.0)), 3.0), "lingering status cooldown helper should store reduced cooldowns")
	_expect(is_equal_approx(CommandoFirearmLingeringStatusState.advance_status_cooldown(lingering_status_cooldown, 0.0), 3.0), "lingering status cooldown helper should ignore negative frame steps")
	_expect(is_equal_approx(CommandoFirearmLingeringStatusState.advance_status_cooldown(lingering_status_cooldown, 9.0), 0.0), "lingering status cooldown helper should clamp cooldowns at zero")
	var default_lingering_status_cooldown := {}
	_expect(is_equal_approx(CommandoFirearmLingeringStatusState.advance_status_cooldown(default_lingering_status_cooldown, 1.0), 0.0), "lingering status cooldown helper should default missing cooldowns to zero")
	_expect(is_equal_approx(float(default_lingering_status_cooldown.get("status_cooldown_frames", -1.0)), 0.0), "lingering status cooldown helper should store default zero cooldowns")
	_expect(is_equal_approx(CommandoFirearmLingeringStatusState.get_status_slow_multiplier({"slow_multiplier": 0.45}, 1.0, 0.0, 1.0), 0.45), "lingering status slow multiplier helper should read multipliers")
	_expect(is_equal_approx(CommandoFirearmLingeringStatusState.get_status_slow_multiplier({}, 1.0, 0.0, 1.0), 1.0), "lingering status slow multiplier helper should default missing multipliers")
	_expect(is_equal_approx(CommandoFirearmLingeringStatusState.get_status_slow_multiplier({"slow_multiplier": 1.4}, 1.0, 0.0, 1.0), 1.0), "lingering status slow multiplier helper should clamp high multipliers")
	_expect(is_equal_approx(CommandoFirearmLingeringStatusState.get_status_slow_multiplier({"slow_multiplier": -0.2}, 1.0, 0.0, 1.0), 0.0), "lingering status slow multiplier helper should clamp low multipliers")
	_expect(CommandoFirearmLingeringStatusState.get_status_data_source({"source": "net_field"}) == "net_field", "lingering status data-source helper should read explicit sources")
	_expect(CommandoFirearmLingeringStatusState.get_status_data_source({}).is_empty(), "lingering status data-source helper should default missing sources to empty")
	_expect(CommandoFirearmLingeringStatusState.get_status_data_source({"source": ""}).is_empty(), "lingering status data-source helper should preserve explicit empty sources")
	_expect(CommandoFirearmLingeringStatusState.should_include_status_slow_multiplier("slow", "slow"), "lingering status slow-multiplier guard should accept slow statuses")
	_expect(not CommandoFirearmLingeringStatusState.should_include_status_slow_multiplier("burn", "slow"), "lingering status slow-multiplier guard should reject generic statuses")
	_expect(not CommandoFirearmLingeringStatusState.should_include_status_slow_multiplier("", "slow"), "lingering status slow-multiplier guard should reject missing statuses")
	var slow_status_data: Dictionary = CommandoFirearmLingeringStatusState.build_status_data({
		"source": "net_field",
		"slow_multiplier": 0.45,
	}, "slow", "slow", 1.0, 0.0, 1.0)
	_expect(str(slow_status_data.get("source", "")) == "net_field", "lingering status data helper should preserve source")
	_expect(is_equal_approx(float(slow_status_data.get("multiplier", 0.0)), 0.45), "lingering status data helper should include slow multipliers")
	var clamped_slow_status_data: Dictionary = CommandoFirearmLingeringStatusState.build_status_data({
		"slow_multiplier": 1.4,
	}, "slow", "slow", 1.0, 0.0, 1.0)
	_expect(is_equal_approx(float(clamped_slow_status_data.get("multiplier", 0.0)), 1.0), "lingering status data helper should clamp high slow multipliers")
	var low_clamped_slow_status_data: Dictionary = CommandoFirearmLingeringStatusState.build_status_data({
		"slow_multiplier": -0.2,
	}, "slow", "slow", 1.0, 0.0, 1.0)
	_expect(is_equal_approx(float(low_clamped_slow_status_data.get("multiplier", 1.0)), 0.0), "lingering status data helper should clamp low slow multipliers")
	var generic_status_data: Dictionary = CommandoFirearmLingeringStatusState.build_status_data({
		"source": "fire_zone",
		"slow_multiplier": 0.2,
	}, "burn", "slow", 1.0, 0.0, 1.0)
	_expect(str(generic_status_data.get("source", "")) == "fire_zone", "lingering status data helper should preserve source for generic statuses")
	_expect(not generic_status_data.has("multiplier"), "lingering status data helper should only add multipliers for slow")
	var reset_status_cooldown := {"status_interval_frames": 8.0}
	_expect(is_equal_approx(CommandoFirearmLingeringStatusState.get_status_interval(reset_status_cooldown, 12.0), 8.0), "lingering status interval helper should read interval frames")
	_expect(is_equal_approx(CommandoFirearmLingeringStatusState.get_status_interval({"status_interval_frames": -2.0}, 12.0), 1.0), "lingering status interval helper should clamp intervals to one frame")
	_expect(is_equal_approx(CommandoFirearmLingeringStatusState.get_status_interval({}, 12.0), 12.0), "lingering status interval helper should default missing intervals")
	_expect(is_equal_approx(CommandoFirearmLingeringStatusState.reset_status_cooldown(reset_status_cooldown, 12.0), 8.0), "lingering status reset helper should use interval frames")
	_expect(is_equal_approx(float(reset_status_cooldown.get("status_cooldown_frames", 0.0)), 8.0), "lingering status reset helper should store interval frames")
	var min_reset_status_cooldown := {"status_interval_frames": -2.0}
	_expect(is_equal_approx(CommandoFirearmLingeringStatusState.reset_status_cooldown(min_reset_status_cooldown, 12.0), 1.0), "lingering status reset helper should clamp intervals to one frame")
	var default_reset_status_cooldown := {}
	_expect(is_equal_approx(CommandoFirearmLingeringStatusState.reset_status_cooldown(default_reset_status_cooldown, 12.0), 12.0), "lingering status reset helper should default missing intervals")
	var fake_status_state := FakeStatusEffectState.new()
	_expect(CommandoFirearmLingeringStatusState.get_status_id({"status_id": "slow"}) == "slow", "lingering status-id helper should read status ids")
	_expect(CommandoFirearmLingeringStatusState.get_status_id({}).is_empty(), "lingering status-id helper should default missing ids to empty")
	_expect(CommandoFirearmLingeringStatusState.is_status_effect_state(fake_status_state), "lingering status-state predicate should accept apply-capable objects")
	_expect(not CommandoFirearmLingeringStatusState.is_status_effect_state(null), "lingering status-state predicate should reject null")
	_expect(not CommandoFirearmLingeringStatusState.is_status_effect_state(RefCounted.new()), "lingering status-state predicate should reject objects without apply_status")
	_expect(CommandoFirearmLingeringStatusState.get_status_effect_state({"status_effect_state": fake_status_state}) == fake_status_state, "lingering status-state helper should return apply-capable status state")
	_expect(CommandoFirearmLingeringStatusState.get_status_effect_state({}) == null, "lingering status-state helper should ignore missing status state")
	_expect(CommandoFirearmLingeringStatusState.get_status_effect_state({"status_effect_state": RefCounted.new()}) == null, "lingering status-state helper should reject status state without apply_status")
	_expect(CommandoFirearmLingeringStatusState.get_status_application({}, {"status_effect_state": fake_status_state}).is_empty(), "lingering status application helper should reject missing status ids")
	_expect(CommandoFirearmLingeringStatusState.get_status_application({"status_id": "slow"}, {}).is_empty(), "lingering status application helper should reject missing status state")
	_expect(CommandoFirearmLingeringStatusState.get_status_application({"status_id": "slow"}, {"status_effect_state": RefCounted.new()}).is_empty(), "lingering status application helper should reject invalid status state")
	var status_application: Dictionary = CommandoFirearmLingeringStatusState.get_status_application({"status_id": "slow"}, {"status_effect_state": fake_status_state})
	_expect(str(status_application.get("status_id", "")) == "slow", "lingering status application helper should preserve valid status ids")
	_expect(status_application.get("status_effect_state", null) == fake_status_state, "lingering status application helper should preserve valid status state")
	_expect(CommandoFirearmLingeringStatusState.has_status_application(status_application), "lingering status application guard should accept valid applications")
	_expect(not CommandoFirearmLingeringStatusState.has_status_application({}), "lingering status application guard should reject empty applications")
	_expect(not CommandoFirearmLingeringStatusState.has_status_application({"status_id": "slow"}), "lingering status application guard should reject missing status state")
	_expect(not CommandoFirearmLingeringStatusState.has_status_application({"status_id": "slow", "status_effect_state": RefCounted.new()}), "lingering status application guard should reject invalid status state")
	_expect(CommandoFirearmLingeringStatusState.get_status_application_id(status_application) == "slow", "lingering status application-id helper should read status ids")
	_expect(CommandoFirearmLingeringStatusState.get_status_application_id({}).is_empty(), "lingering status application-id helper should default missing ids to empty")
	_expect(CommandoFirearmLingeringStatusState.get_status_application_state(status_application) == fake_status_state, "lingering status application-state helper should read valid status state")
	_expect(CommandoFirearmLingeringStatusState.get_status_application_state({}) == null, "lingering status application-state helper should ignore missing status state")
	_expect(CommandoFirearmLingeringStatusState.get_status_application_state({"status_effect_state": RefCounted.new()}) == null, "lingering status application-state helper should reject invalid status state")
	_expect(CommandoFirearmRuntime.LINGERING_STATUS_TARGET == "boss", "lingering status target constant should stay boss")
	_expect(CommandoFirearmRuntime.LINGERING_STATUS_ID_SLOW == "slow", "lingering status slow-id constant should stay slow")
	_expect(is_equal_approx(CommandoFirearmRuntime.LINGERING_STATUS_DEFAULT_DURATION_FRAMES, 18.0), "lingering status duration constant should match the shipped default")
	_expect(is_equal_approx(CommandoFirearmRuntime.LINGERING_STATUS_DEFAULT_INTERVAL_FRAMES, 12.0), "lingering status interval constant should match the shipped default")
	_expect(is_equal_approx(CommandoFirearmRuntime.LINGERING_STATUS_INITIAL_COOLDOWN_FRAMES, 0.0), "lingering status initial cooldown constant should start ready")
	_expect(CommandoFirearmRuntime.LINGERING_STATUS_DEFAULT_SOURCE == "commando_firearm_lingering", "lingering status source constant should match the shipped default")
	_expect(is_equal_approx(CommandoFirearmRuntime.LINGERING_STATUS_DEFAULT_SLOW_MULTIPLIER, 1.0), "lingering status slow default constant should match the shipped default")
	_expect(is_equal_approx(CommandoFirearmRuntime.LINGERING_STATUS_MIN_SLOW_MULTIPLIER, 0.0), "lingering status slow min constant should stay zero")
	_expect(is_equal_approx(CommandoFirearmRuntime.LINGERING_STATUS_MAX_SLOW_MULTIPLIER, 1.0), "lingering status slow max constant should stay one")
	_expect(CommandoFirearmLingeringStatusState.get_status_target("boss") == "boss", "lingering status target helper should target the boss")
	_expect(is_equal_approx(CommandoFirearmLingeringStatusState.get_status_duration({"status_duration_frames": 32.0}, 18.0), 32.0), "lingering status duration helper should read explicit durations")
	_expect(is_equal_approx(CommandoFirearmLingeringStatusState.get_status_duration({}, 18.0), 18.0), "lingering status duration helper should default missing durations")
	_expect(CommandoFirearmLingeringStatusState.get_status_source({"source": "net_field"}, "commando_firearm_lingering") == "net_field", "lingering status source helper should read explicit sources")
	_expect(CommandoFirearmLingeringStatusState.get_status_source({}, "commando_firearm_lingering") == "commando_firearm_lingering", "lingering status source helper should default missing sources")
	_expect(CommandoFirearmLingeringStatusState.get_status_source({"source": ""}, "commando_firearm_lingering").is_empty(), "lingering status source helper should preserve explicit empty sources")
	_expect(not CommandoFirearmLingeringStatusState.is_status_cooldown_ready(0.1), "lingering status cooldown-ready helper should reject active cooldowns")
	_expect(CommandoFirearmLingeringStatusState.is_status_cooldown_ready(0.0), "lingering status cooldown-ready helper should accept zero cooldowns")
	_expect(CommandoFirearmLingeringStatusState.is_status_cooldown_ready(-0.1), "lingering status cooldown-ready helper should accept negative cooldowns")
	var overlapping_status_effect := {
		"pos": Vector2(100.0, 100.0),
		"width": 80.0,
		"height": 40.0,
	}
	var overlapping_status_context := {
		"boss_pos": Vector2(90.0, 90.0),
		"boss_paddle_width": 20.0,
		"boss_hitbox_height": 20.0,
	}
	_expect(CommandoFirearmLingeringStatusState.is_status_ready_to_apply(0.0, overlapping_status_effect, overlapping_status_context), "lingering status ready helper should accept ready overlapping effects")
	_expect(not CommandoFirearmLingeringStatusState.is_status_ready_to_apply(0.1, overlapping_status_effect, overlapping_status_context), "lingering status ready helper should reject active cooldowns")
	_expect(not CommandoFirearmLingeringStatusState.is_status_ready_to_apply(0.0, {
		"pos": Vector2(10.0, 10.0),
		"width": 20.0,
		"height": 20.0,
	}, overlapping_status_context), "lingering status ready helper should reject effects that miss the boss")
	var blocked_status_effect := {
		"status_cooldown_frames": 5.0,
		"pos": Vector2(100.0, 100.0),
		"width": 80.0,
		"height": 40.0,
	}
	_expect(not CommandoFirearmLingeringStatusState.can_apply_status(blocked_status_effect, {
		"boss_pos": Vector2(90.0, 90.0),
		"boss_paddle_width": 20.0,
		"boss_hitbox_height": 20.0,
	}, 2.0), "lingering status apply gate should reject active cooldowns")
	_expect(is_equal_approx(float(blocked_status_effect.get("status_cooldown_frames", 0.0)), 3.0), "lingering status apply gate should still advance cooldowns")
	var missed_status_effect := {
		"status_cooldown_frames": 0.0,
		"pos": Vector2(100.0, 100.0),
		"width": 20.0,
		"height": 20.0,
	}
	_expect(not CommandoFirearmLingeringStatusState.can_apply_status(missed_status_effect, {
		"boss_pos": Vector2(200.0, 200.0),
		"boss_paddle_width": 20.0,
		"boss_hitbox_height": 20.0,
	}, 1.0), "lingering status apply gate should reject effects that miss the boss")
	var ready_status_effect := {
		"status_cooldown_frames": 1.0,
		"pos": Vector2(100.0, 100.0),
		"width": 80.0,
		"height": 40.0,
	}
	_expect(CommandoFirearmLingeringStatusState.can_apply_status(ready_status_effect, {
		"boss_pos": Vector2(90.0, 90.0),
		"boss_paddle_width": 20.0,
		"boss_hitbox_height": 20.0,
	}, 1.0), "lingering status apply gate should accept ready overlapping effects")
	_expect(is_equal_approx(float(ready_status_effect.get("status_cooldown_frames", -1.0)), 0.0), "lingering status apply gate should clamp ready cooldowns to zero")
	var live_status_context := {
		"boss_pos": Vector2(90.0, 90.0),
		"boss_paddle_width": 20.0,
		"boss_hitbox_height": 20.0,
	}
	var live_status_effect := {
		"status_id": "slow",
		"status_cooldown_frames": 0.0,
		"status_interval_frames": 9.0,
		"source": "net_field",
		"status_duration_frames": 32.0,
		"slow_multiplier": 0.4,
		"pos": Vector2(100.0, 100.0),
		"width": 80.0,
		"height": 40.0,
	}
	var direct_status_state := FakeStatusEffectState.new()
	var direct_apply_status_effect: Dictionary = live_status_effect.duplicate(true)
	_expect(CommandoFirearmLingeringStatusState.apply_status_if_ready(
		direct_apply_status_effect,
		live_status_context,
		{"status_effect_state": direct_status_state},
		1.0,
		CommandoFirearmRuntime.LINGERING_STATUS_TARGET,
		CommandoFirearmRuntime.LINGERING_STATUS_ID_SLOW,
		CommandoFirearmRuntime.LINGERING_STATUS_DEFAULT_DURATION_FRAMES,
		CommandoFirearmRuntime.LINGERING_STATUS_DEFAULT_INTERVAL_FRAMES,
		CommandoFirearmRuntime.LINGERING_STATUS_DEFAULT_SLOW_MULTIPLIER,
		CommandoFirearmRuntime.LINGERING_STATUS_MIN_SLOW_MULTIPLIER,
		CommandoFirearmRuntime.LINGERING_STATUS_MAX_SLOW_MULTIPLIER,
		CommandoFirearmRuntime.LINGERING_STATUS_DEFAULT_SOURCE
	), "lingering status apply helper should apply ready statuses")
	_expect(direct_status_state.calls.size() == 1, "lingering status apply helper should call status state once")
	var helper_status_call: Dictionary = direct_status_state.calls[0]
	_expect(str(helper_status_call.get("target", "")) == "boss", "lingering status apply helper should target the boss")
	_expect(str(helper_status_call.get("status_id", "")) == "slow", "lingering status apply helper should preserve status id")
	_expect(is_equal_approx(float(helper_status_call.get("duration_frames", 0.0)), 32.0), "lingering status apply helper should preserve duration")
	_expect((helper_status_call.get("data", {}) as Dictionary).get("multiplier", 0.0) == 0.4, "lingering status apply helper should pass status data")
	_expect(str(helper_status_call.get("source", "")) == "net_field", "lingering status apply helper should preserve explicit source")
	_expect(is_equal_approx(float(direct_apply_status_effect.get("status_cooldown_frames", 0.0)), 9.0), "lingering status apply helper should reset cooldown after apply")
	runtime.lingering_effects = [live_status_effect]
	_apply_active_runtime_lingering_effect(
		runtime,
		0,
		CommandoFirearmValueUtils.get_dict(runtime.lingering_effects[0]),
		1.0,
		live_status_context,
		{"status_effect_state": fake_status_state},
		{}
	)
	_expect(fake_status_state.calls.size() == 1, "lingering status effect path should call status state once")
	var direct_status_call: Dictionary = fake_status_state.calls[0]
	_expect(str(direct_status_call.get("target", "")) == "boss", "lingering status effect path should target the boss")
	_expect(str(direct_status_call.get("status_id", "")) == "slow", "lingering status effect path should preserve status id")
	_expect(is_equal_approx(float(direct_status_call.get("duration_frames", 0.0)), 32.0), "lingering status effect path should preserve duration")
	_expect((direct_status_call.get("data", {}) as Dictionary).get("multiplier", 0.0) == 0.4, "lingering status effect path should pass status data")
	_expect(str(direct_status_call.get("source", "")) == "net_field", "lingering status effect path should preserve explicit source")
	_expect(is_equal_approx(float(live_status_effect.get("status_cooldown_frames", 0.0)), 9.0), "lingering status effect path should reset cooldown after apply")
	var default_apply_status_effect := {
		"status_id": "burn",
		"status_cooldown_frames": 0.0,
		"pos": Vector2(100.0, 100.0),
		"width": 80.0,
		"height": 40.0,
	}
	runtime.lingering_effects = [default_apply_status_effect]
	_apply_active_runtime_lingering_effect(
		runtime,
		0,
		CommandoFirearmValueUtils.get_dict(runtime.lingering_effects[0]),
		1.0,
		live_status_context,
		{"status_effect_state": fake_status_state},
		{}
	)
	_expect(str((fake_status_state.calls[1] as Dictionary).get("source", "")) == "commando_firearm_lingering", "lingering status effect path should use default source")
	_expect(is_equal_approx(float((fake_status_state.calls[1] as Dictionary).get("duration_frames", 0.0)), 18.0), "lingering status effect path should use default duration")
	_apply_active_runtime_lingering_effect(
		runtime,
		0,
		CommandoFirearmValueUtils.get_dict(runtime.lingering_effects[0]),
		1.0,
		live_status_context,
		{},
		{}
	)
	_apply_active_runtime_lingering_effect(
		runtime,
		0,
		CommandoFirearmValueUtils.get_dict(runtime.lingering_effects[0]),
		1.0,
		live_status_context,
		{"status_effect_state": RefCounted.new()},
		{}
	)
	_expect(fake_status_state.calls.size() == 2, "lingering status effect path should ignore invalid applications")
	runtime.lingering_effects = [
		{"id": "first", "timer_frames": 2.0, "phase": 0.0},
		{"id": "expired", "timer_frames": 0.0, "phase": 0.0},
		{"id": "last", "timer_frames": 2.0, "phase": 0.0},
	]
	_advance_runtime_lingering_effects(runtime, 1.0, {}, {})
	_expect(runtime.lingering_effects.size() == 2, "lingering update should remove exactly one expired effect")
	_expect(str(CommandoFirearmValueUtils.get_dict(runtime.lingering_effects[0]).get("id", "")) == "first", "lingering update should preserve earlier effects")
	_expect(str(CommandoFirearmValueUtils.get_dict(runtime.lingering_effects[1]).get("id", "")) == "last", "lingering update should preserve later effects")
	_expect(CommandoFirearmLingeringNetFieldState.is_player_dash_active({"dash_snapshot": {"active": true}}), "direct net dash helper should read active dash snapshots")
	_expect(not CommandoFirearmLingeringNetFieldState.is_player_dash_active({"dash_snapshot": {"active": false}}), "direct net dash helper should read inactive dash snapshots")
	var direct_dash_trigger: Dictionary = CommandoFirearmLingeringNetFieldState.get_dash_trigger_result({"dash_snapshot": {"active": true}}, {}, false)
	_expect(bool(direct_dash_trigger.get("dash_triggered", false)), "direct net dash trigger helper should fire on rising dash state")
	var direct_dash_repeat: Dictionary = CommandoFirearmLingeringNetFieldState.get_dash_trigger_result({"dash_snapshot": {"active": true}}, {}, true)
	_expect(not bool(direct_dash_repeat.get("dash_triggered", false)), "direct net dash trigger helper should reject repeated active dash state")
	var direct_dash_break_effects := [
		{"weapon_id": "net_gun", "hooked_player": true, "timer_frames": 90.0},
		{"weapon_id": "net_gun", "hooked_player": true, "dissolve": true, "timer_frames": 90.0},
	]
	var direct_dash_break: Dictionary = CommandoFirearmLingeringNetFieldState.apply_dash_break_if_triggered(
		direct_dash_break_effects,
		{"dash_snapshot": {"active": true}},
		{},
		false,
		24.0
	)
	_expect(bool(direct_dash_break.get("dash_triggered", false)), "direct net dash break helper should report rising dash triggers")
	_expect(bool(CommandoFirearmValueUtils.get_dict(direct_dash_break_effects[0]).get("rope_broken", false)), "direct net dash break helper should break active hooked nets")
	_expect(not bool(CommandoFirearmValueUtils.get_dict(direct_dash_break_effects[1]).get("rope_broken", false)), "direct net dash break helper should leave dissolving nets unchanged")
	runtime.net_gun_last_dash_active = false
	runtime.lingering_effects = []
	_advance_runtime_lingering_effects(runtime, 1.0, {"dash_snapshot": {"active": true}}, {})
	_expect(runtime.net_gun_last_dash_active, "lingering update should store active dash state")
	_advance_runtime_lingering_effects(runtime, 1.0, {"dash_snapshot": {"active": true}}, {})
	_expect(runtime.net_gun_last_dash_active, "lingering update should keep repeated active dash state")
	_advance_runtime_lingering_effects(runtime, 1.0, {"dash_snapshot": {"active": false}}, {})
	_expect(not runtime.net_gun_last_dash_active, "lingering update should store inactive dash state")
	var fake_dash_state := FakeDashState.new(true)
	_advance_runtime_lingering_effects(runtime, 1.0, {"dash_snapshot": null}, {"dash_state": fake_dash_state})
	_expect(runtime.net_gun_last_dash_active, "lingering update should read active dash state dependencies")
	fake_dash_state.active = false
	_advance_runtime_lingering_effects(runtime, 1.0, {"dash_snapshot": null}, {"dash_state": fake_dash_state})
	_expect(not runtime.net_gun_last_dash_active, "lingering update should clear dependency dash state")
	var direct_marked_broken_net := {
		"weapon_id": "net_gun",
		"hooked_player": true,
		"dissolve": false,
		"rope_broken": false,
		"timer_frames": 90.0,
		"max_timer_frames": 90.0,
		"rope_snap_timer": 0.0,
		"status_id": "net_capture",
	}
	CommandoFirearmLingeringNetFieldState.mark_hooked_field_broken(direct_marked_broken_net, 24.0)
	_expect(not bool(direct_marked_broken_net.get("hooked_player", true)), "direct net broken helper should clear hooked state")
	_expect(bool(direct_marked_broken_net.get("dissolve", false)), "direct net broken helper should start dissolve")
	_expect(is_equal_approx(float(direct_marked_broken_net.get("timer_frames", 0.0)), 24.0), "direct net broken helper should use dash-break timer")
	_expect(str(direct_marked_broken_net.get("status_id", "missing")).is_empty(), "direct net broken helper should clear active status")
	runtime.lingering_effects = [
		{"weapon_id": "net_gun", "hooked_player": false},
		{"weapon_id": "net_gun", "hooked_player": true},
	]
	_expect(CommandoFirearmLingeringNetFieldState.has_active_hooked_net_field(runtime.lingering_effects), "hooked net field owner should find active hooked net effects")
	runtime.lingering_effects = [{"weapon_id": "net_gun", "hooked_player": true, "dissolve": true}]
	_expect(not CommandoFirearmLingeringNetFieldState.has_active_hooked_net_field(runtime.lingering_effects), "hooked net field owner should ignore dissolving net effects")
	runtime.lingering_effects = [
		{"weapon_id": "net_gun", "hooked_player": true},
		{"weapon_id": "net_gun", "hooked_player": true, "dissolve": true},
		{"weapon_id": "ak47", "hooked_player": true},
	]
	CommandoFirearmLingeringNetFieldState.break_active_hooked_net_fields(runtime.lingering_effects, 24.0)
	var broken_net: Dictionary = CommandoFirearmValueUtils.get_dict(runtime.lingering_effects[0])
	_expect(not bool(broken_net.get("hooked_player", true)), "break hooked nets should clear hooked state on active net fields")
	_expect(bool(broken_net.get("dissolve", false)), "break hooked nets should start dissolve on active net fields")
	_expect(bool(broken_net.get("rope_broken", false)), "break hooked nets should mark rope_broken on active net fields")
	_expect(is_equal_approx(float(broken_net.get("timer_frames", 0.0)), 24.0), "break hooked nets should use dash-break timer")
	_expect(bool(CommandoFirearmValueUtils.get_dict(runtime.lingering_effects[1]).get("dissolve", false)), "break hooked nets should leave already dissolving nets alone")
	_expect(not bool(CommandoFirearmValueUtils.get_dict(runtime.lingering_effects[2]).get("dissolve", false)), "break hooked nets should ignore non-net effects")
	var fire_support_hit_projectile := {
		"weapon_id": "fire_support",
		"pos": Vector2(360.0, 90.0),
		"target_y": 82.0,
	}
	_expect(CommandoFirearmHitGeometry.get_fire_support_target_y_impact_reason(
		"fire_support",
		fire_support_hit_projectile,
		{"impact_radius": 36.0},
		Rect2(Vector2(330.0, 50.0), Vector2(100.0, 40.0))
	) == "target", "fire-support target-Y impact helper should return target on boss hit")
	_expect(CommandoFirearmHitGeometry.get_fire_support_target_y_impact_reason(
		"fire_support",
		{
			"weapon_id": "fire_support",
			"pos": Vector2(0.0, 0.0),
			"target_y": 999.0,
			"support_target_y_reached": 1.0,
		},
		{"impact_radius": 36.0},
		Rect2(Vector2(330.0, 50.0), Vector2(100.0, 40.0))
	) == "expired", "fire-support target-Y impact helper should expire already-reached bombs")
	_expect(CommandoFirearmHitGeometry.get_fire_support_target_y_impact_reason(
		"bazooka",
		{"pos": Vector2(360.0, 90.0), "target_y": 82.0},
		{"impact_radius": 36.0},
		Rect2(Vector2(330.0, 50.0), Vector2(100.0, 40.0))
	) == "", "fire-support target-Y impact helper should ignore other weapons")
	_expect(CommandoFirearmHitGeometry.get_net_passed_target_impact_reason(
		"net_gun",
		{
			"prev_pos": Vector2(370.0, 70.0),
			"pos": Vector2(420.0, 70.0),
		},
		Vector2(380.0, 70.0)
	) == "expired", "net passed-target impact helper should expire nets after passing the target")
	_expect(CommandoFirearmHitGeometry.get_net_passed_target_impact_reason(
		"net_gun",
		{
			"prev_pos": Vector2(260.0, 70.0),
			"pos": Vector2(300.0, 70.0),
		},
		Vector2(380.0, 70.0)
	) == "", "net passed-target impact helper should keep approaching nets alive")
	_expect(CommandoFirearmHitGeometry.get_net_passed_target_impact_reason(
		"ak47",
		{
			"prev_pos": Vector2(370.0, 70.0),
			"pos": Vector2(420.0, 70.0),
		},
		Vector2(380.0, 70.0)
	) == "", "net passed-target impact helper should ignore non-net weapons")
	_expect(CommandoFirearmHitGeometry.get_target_reached_impact_reason(
		"bazooka",
		{
			"weapon_id": "bazooka",
			"pos": Vector2(300.0, 70.0),
			"velocity": Vector2.ZERO,
			"radius": 5.0,
			"explosion_radius": 85.0,
		},
		{"kind": "rocket", "explosion_radius": 85.0},
		Rect2(Vector2(330.0, 50.0), Vector2(100.0, 40.0)),
		Vector2(300.0, 70.0)
	) == "target", "target-reached impact helper should return target when the reached impact hits boss")
	_expect(CommandoFirearmHitGeometry.get_target_reached_impact_reason(
		"fire_support",
		{
			"weapon_id": "fire_support",
			"pos": Vector2(100.0, 100.0),
			"velocity": Vector2.ZERO,
			"radius": 5.0,
		},
		{"kind": "support", "explosion_radius": 10.0},
		Rect2(Vector2(330.0, 50.0), Vector2(100.0, 40.0)),
		Vector2(100.0, 100.0)
	) == "expired", "target-reached impact helper should expire reached support projectiles that miss")
	_expect(CommandoFirearmHitGeometry.get_target_reached_impact_reason(
		"bazooka",
		{
			"weapon_id": "bazooka",
			"pos": Vector2(0.0, 0.0),
			"velocity": Vector2.ZERO,
			"radius": 5.0,
		},
		{"kind": "rocket", "explosion_radius": 10.0},
		Rect2(Vector2(330.0, 50.0), Vector2(100.0, 40.0)),
		Vector2(0.0, 0.0)
	) == "", "target-reached impact helper should keep missed bazooka shots alive")
	_expect(CommandoFirearmHitGeometry.get_target_reached_impact_reason(
		"fire_support",
		{
			"weapon_id": "fire_support",
			"pos": Vector2(0.0, 0.0),
			"velocity": Vector2.ZERO,
			"radius": 5.0,
		},
		{"kind": "support", "explosion_radius": 10.0},
		Rect2(Vector2(330.0, 50.0), Vector2(100.0, 40.0)),
		Vector2(100.0, 100.0)
	) == "", "target-reached impact helper should not expire projectiles before target reach")


func _verify_removed_projectile_value_bridges() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	for bridge_name in [
		"_get_projectile_target",
		"_get_projectile_weapon_id",
		"_get_projectile_kind",
	]:
		_expect(source.find("func %s(" % bridge_name) == -1, "runtime should not keep projectile value bridge %s" % bridge_name)


func _verify_removed_pistol_value_bridges() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	for bridge_name in [
		"_is_pistol_weapon",
		"_get_pistol_hit_doping_multiplier",
		"_get_pistol_hit_chances",
		"_get_pistol_shot_roll",
		"_refresh_pending_pistol_fire_geometry",
	]:
		_expect(source.find("func %s(" % bridge_name) == -1, "runtime should not keep pistol value bridge %s" % bridge_name)


func _verify_removed_fire_flame_owner_bridges() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	for bridge_name in [
		"_get_lingering_fire_flames_for_frame",
		"_get_lingering_fire_flames",
		"_should_seed_lingering_fire_flames",
		"_seed_lingering_fire_flames",
		"_update_lingering_fire_flames",
		"_advance_lingering_fire_flames",
		"_get_lingering_fire_flame_at_index",
		"_advance_lingering_fire_flame",
		"_apply_lingering_fire_flame_frame_values",
		"_apply_lingering_fire_flame_motion",
		"_apply_lingering_fire_flame_reset_motion",
		"_should_reset_lingering_fire_flame",
		"_get_lingering_fire_flame_next_lifetime",
		"_get_lingering_fire_flame_next_phase",
		"_get_lingering_fire_flame_current_lifetime",
		"_get_lingering_fire_flame_current_phase",
		"_get_lingering_fire_flame_phase_step",
		"_reset_lingering_fire_flame",
		"_apply_lingering_fire_flame_reset_values",
		"_get_lingering_fire_flame_reset_angle",
		"_get_lingering_fire_flame_reset_angle_index",
		"_get_lingering_fire_effect_id",
		"_get_lingering_fire_flame_reset_offset",
		"_get_lingering_fire_flame_reset_radius",
		"_get_lingering_fire_flame_reset_radius_x",
		"_get_lingering_fire_flame_reset_radius_y",
		"_get_lingering_fire_flame_reset_size",
		"_get_lingering_fire_flame_reset_size_offset",
		"_get_lingering_fire_flame_reset_size_pattern_value",
		"_get_lingering_fire_flame_reset_lifetime",
		"_get_lingering_fire_flame_reset_lifetime_offset",
		"_get_lingering_fire_flame_reset_lifetime_pattern_value",
		"_apply_lingering_fire_flame_drift_motion",
		"_drift_lingering_fire_flame",
		"_get_lingering_fire_flame_drift_offset",
		"_get_lingering_fire_flame_current_offset",
		"_get_lingering_fire_flame_unclamped_drift_offset",
		"_get_lingering_fire_flame_drift_step",
		"_get_lingering_fire_flame_drift_wave_offset",
		"_get_lingering_fire_flame_drift_rise_offset",
		"_clamp_lingering_fire_flame_offset",
		"_get_lingering_fire_flame_offset_bound",
		"_get_lingering_fire_flame_drift_size",
		"_get_lingering_fire_flame_current_size",
		"_get_lingering_fire_flame_unclamped_drift_size",
		"_get_lingering_fire_flame_size_decay",
		"_clamp_lingering_fire_flame_drift_size",
	]:
		_expect(source.find("func %s" % bridge_name) < 0, "runtime should not keep fire-flame owner bridge %s" % bridge_name)


func _verify_removed_net_field_clamp_bridges() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	for bridge_name in [
		"_get_net_field_pos",
		"_get_net_field_effect_width",
		"_get_net_field_effect_height",
		"_get_net_field_boss_pos",
		"_get_net_field_boss_width",
		"_get_net_field_clamp_width",
		"_get_net_field_min_boss_clamp_width",
		"_get_net_field_constricted_width",
		"_get_net_field_clamp_rect",
		"_get_net_field_clamp_size",
		"_get_net_field_clamp_origin",
		"_get_net_field_clamped_boss_x",
		"_get_net_field_safe_boss_width",
		"_get_net_field_boss_clamp_min_x",
		"_get_net_field_boss_clamp_max_x",
		"_get_net_field_clamped_boss_pos",
		"_should_emit_net_field_boss_clamp_result",
		"_build_net_field_boss_clamp_result",
		"_apply_net_field_boss_clamp",
		"_get_active_lingering_clamp_result",
		"_apply_active_lingering_clamp",
	]:
		_expect(source.find("func %s" % bridge_name) < 0, "runtime should not keep net-field clamp bridge %s" % bridge_name)


func _verify_removed_net_field_predicate_bridges() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	for bridge_name in [
		"_is_player_dash_active",
		"_is_net_gun_effect",
		"_is_active_hooked_net_field",
		"_is_boss_clamping_net_field",
		"_is_net_constrict_candidate",
		"_get_net_constrict_input_direction",
		"_should_record_net_constrict_input",
		"_should_apply_net_constrict_input",
		"_get_next_net_constrict_factor",
		"_get_net_constrict_factor",
		"_update_net_constrict_input",
		"_apply_net_constrict_to_indices",
		"_play_net_constrict_audio",
		"_get_net_constrict_candidate_indices",
		"_sync_net_field_rope_origin",
		"_should_sync_net_field_rope_origin",
		"_has_hooked_net_field",
		"_consume_net_gun_dash_trigger",
		"_break_hooked_net_fields",
	]:
		_expect(source.find("func %s" % bridge_name) < 0, "runtime should not keep net-field predicate bridge %s" % bridge_name)


func _verify_removed_net_field_setup_bridges() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	for bridge_name in [
		"_apply_lingering_net_fields",
		"_mark_hooked_net_field_broken",
		"_apply_lingering_net_lifecycle_fields",
		"_get_lingering_net_rope_snap_duration",
		"_get_lingering_net_origin",
		"_get_lingering_net_player_slow_multiplier",
		"_apply_lingering_net_profile_fields",
		"_apply_lingering_net_geometry_fields",
		"_get_lingering_net_deploy_x",
		"_get_lingering_net_rect",
		"_get_lingering_net_initial_constrict_factor",
		"_build_lingering_net_shape",
		"_generate_net_shape",
		"_get_net_shape_seed_phase",
		"_get_net_shape_scale",
		"_get_net_shape_point",
		"_get_net_lingering_effect_pos",
		"_get_default_lingering_effect_pos",
		"_get_lingering_effect_pos",
		"_get_net_effect_desired_height",
		"_get_net_effect_height",
		"_get_net_effect_height_limits",
	]:
		_expect(source.find("func %s" % bridge_name) < 0, "runtime should not keep net-field setup bridge %s" % bridge_name)


func _verify_removed_lingering_status_setup_bridges() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	for bridge_name in [
		"_apply_lingering_effect_status_fields",
		"_apply_lingering_status_profile_base_fields",
		"_apply_lingering_status_profile_slow_multiplier",
		"_get_lingering_status_profile_id",
		"_get_lingering_status_profile_duration",
		"_get_lingering_status_profile_interval",
		"_get_lingering_status_initial_cooldown",
		"_has_lingering_status_profile_slow_multiplier",
		"_get_lingering_status_profile_slow_multiplier",
		"_should_apply_lingering_effect_status_fields",
	]:
		_expect(source.find("func %s" % bridge_name) < 0, "runtime should not keep lingering-status setup bridge %s" % bridge_name)


func _verify_removed_lingering_status_application_bridges() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	for bridge_name in [
		"_get_lingering_status_id",
		"_get_lingering_status_effect_state",
		"_get_lingering_status_application",
		"_has_lingering_status_application",
		"_get_lingering_status_application_id",
		"_get_lingering_status_application_state",
		"_is_lingering_status_effect_state",
		"_can_apply_lingering_status",
		"_is_lingering_status_ready_to_apply",
		"_get_lingering_status_target",
		"_get_lingering_status_duration",
		"_get_lingering_status_source",
		"_build_lingering_status_data",
		"_should_include_lingering_status_slow_multiplier",
		"_get_lingering_status_data_source",
		"_get_lingering_status_slow_multiplier",
		"_reset_lingering_status_cooldown",
		"_get_lingering_status_interval",
		"_advance_lingering_status_cooldown",
		"_set_lingering_status_cooldown",
		"_get_lingering_status_cooldown",
		"_get_next_lingering_status_cooldown",
		"_is_lingering_status_cooldown_ready",
		"_apply_lingering_status_application",
		"_apply_ready_lingering_status",
		"_apply_lingering_status_to_boss",
		"_lingering_effect_hits_boss",
		"_do_lingering_rects_intersect",
		"_get_lingering_effect_rect",
		"_get_lingering_effect_rect_pos",
		"_get_lingering_effect_rect_width",
		"_get_lingering_effect_rect_height",
		"_get_lingering_effect_rect_size",
		"_get_lingering_boss_rect",
		"_get_lingering_boss_rect_pos",
		"_get_lingering_boss_rect_width",
		"_get_lingering_boss_rect_height",
		"_get_lingering_boss_rect_size",
		"_apply_lingering_effect_status",
	]:
		_expect(source.find("func %s" % bridge_name) < 0, "runtime should not keep lingering-status application bridge %s" % bridge_name)


func _verify_removed_lingering_effect_timer_bridges() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	for bridge_name in [
		"_advance_lingering_effect_timers",
		"_get_lingering_effect_timer_step",
		"_get_next_lingering_effect_timer",
		"_get_next_lingering_effect_phase",
		"_get_lingering_effect_timer",
		"_get_lingering_effect_phase",
		"_get_lingering_effect_phase_step",
		"_should_advance_lingering_rope_snap_timer",
		"_get_next_lingering_rope_snap_timer",
		"_get_lingering_rope_snap_timer",
		"_is_lingering_fire_zone",
		"_is_lingering_effect_active",
		"_has_lingering_effect_timer",
		"_merge_lingering_clamp_result",
		"_has_lingering_clamp_result",
		"_apply_lingering_clamp_payload",
		"_get_lingering_effect_size",
		"_advance_lingering_effect_frame",
	]:
		_expect(source.find("func %s" % bridge_name) < 0, "runtime should not keep lingering-effect timer bridge %s" % bridge_name)


func _verify_removed_lingering_storage_bridges() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	for bridge_name in [
		"_store_lingering_effect_at_index",
		"_get_lingering_effect_at_index",
		"_remove_lingering_effect_at_index",
	]:
		_expect(source.find("func %s" % bridge_name) < 0, "runtime should not keep lingering storage bridge %s" % bridge_name)


func _verify_removed_hit_geometry_result_bridges() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	for bridge_name in [
		"_get_hit_knockback_velocity",
		"_get_result_hit_profile",
		"_get_hit_knockback_direction",
	]:
		_expect(source.find("func %s" % bridge_name) < 0, "runtime should not keep hit-geometry result bridge %s" % bridge_name)


func _verify_removed_support_aircraft_geometry_bridges() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	for bridge_name in [
		"_get_support_aircraft_collision_rect",
		"_support_aircraft_ball_path_hits",
	]:
		_expect(source.find("func %s" % bridge_name) < 0, "runtime should not keep support-aircraft geometry bridge %s" % bridge_name)


func _verify_removed_doping_value_bridges() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	for bridge_name in [
		"_get_pistol_cooldown_frames",
		"_get_doping_potion_context_from_deps",
		"_get_doping_potion_context_from_config",
		"_get_doping_potion_defaults",
		"_apply_doping_potion_to_pistol_config",
		"_normalize_doping_potion_context",
		"_get_doping_fire_rate_multiplier",
		"_get_ak47_fire_interval_frames",
		"_get_bazooka_cooldown_frames",
		"_get_bazooka_control_lock_frames",
	]:
		_expect(source.find("func %s" % bridge_name) < 0, "runtime should not keep doping value bridge %s" % bridge_name)


func _verify_removed_timed_effect_update_bridges() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	for bridge_name in [
		"_update_muzzle_flashes",
		"_update_impact_flashes",
	]:
		_expect(source.find("func %s" % bridge_name) < 0, "runtime should not keep timed-effect update bridge %s" % bridge_name)


func _verify_removed_append_limited_bridge() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	_expect(source.find("func _append_limited") < 0, "runtime should not keep append-limited value bridge")


func _verify_removed_registry_value_bridge() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	_expect(source.find("func _get_instance") < 0, "runtime should not keep registry value bridge")


func _verify_removed_type_value_bridges() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	for bridge_name in [
		"_get_vector2",
		"_get_color",
		"_get_dict",
		"_get_array",
	]:
		_expect(source.find("func %s(" % bridge_name) < 0, "runtime should not keep type value bridge %s" % bridge_name)


func _verify_removed_skill_cooldown_bridges() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	for bridge_name in [
		"_trigger_firearm_skill_cooldown",
		"_get_firearm_skill_cooldown_seconds",
	]:
		_expect(source.find("func %s(" % bridge_name) < 0, "runtime should not keep skill cooldown bridge %s" % bridge_name)


func _doping_defaults() -> Dictionary:
	return {
		"head_leg_multiplier": CommandoFirearmRuntime.DOPING_POTION_HEAD_LEG_MULTIPLIER,
		"fire_rate_multiplier": CommandoFirearmRuntime.DOPING_POTION_FIRE_RATE_MULTIPLIER,
		"pistol_cooldown_frames": CommandoFirearmRuntime.DOPING_POTION_PISTOL_COOLDOWN_FRAMES,
		"pistol_control_lock_frames": CommandoFirearmRuntime.DOPING_POTION_PISTOL_CONTROL_LOCK_FRAMES,
		"pistol_speed_multiplier": CommandoFirearmRuntime.DOPING_POTION_PISTOL_SPEED_MULTIPLIER,
		"beretta_cooldown_frames": CommandoFirearmRuntime.DOPING_POTION_BERETTA_COOLDOWN_FRAMES,
		"ak47_fire_interval_frames": CommandoFirearmRuntime.DOPING_POTION_AK47_FIRE_INTERVAL_FRAMES,
		"bazooka_cooldown_frames": CommandoFirearmRuntime.DOPING_POTION_BAZOOKA_COOLDOWN_FRAMES,
		"bazooka_control_lock_frames": CommandoFirearmRuntime.DOPING_POTION_BAZOOKA_CONTROL_LOCK_FRAMES,
	}


func _apply_active_runtime_lingering_effect(
	runtime: Object,
	index: int,
	effect: Dictionary,
	timer_step: float,
	context: Dictionary,
	deps: Dictionary,
	result: Dictionary
) -> void:
	CommandoFirearmLingeringEffectState.apply_runtime_active_effect_at_index(
		runtime.lingering_effects,
		index,
		effect,
		timer_step,
		context,
		deps,
		result,
		Vector2(CommandoFirearmRuntime.FIELD_WIDTH, CommandoFirearmRuntime.FIELD_HEIGHT),
		CommandoFirearmRuntime.COMMANDO_NET_GUN_FIRE_MUZZLE_SOURCE,
		CommandoFirearmRuntime.COMMANDO_FIRE_SHEET_SOURCE_CELL_SIZE,
		CommandoFirearmRuntime.COMMANDO_FIRE_SHEET_PLAYER_FOOT_Y_OFFSET,
		CommandoFirearmRuntime.NET_GUN_WIDTH,
		CommandoFirearmRuntime.NET_GUN_MIN_HEIGHT,
		CommandoFirearmRuntime.LINGERING_STATUS_TARGET,
		CommandoFirearmRuntime.LINGERING_STATUS_ID_SLOW,
		CommandoFirearmRuntime.LINGERING_STATUS_DEFAULT_DURATION_FRAMES,
		CommandoFirearmRuntime.LINGERING_STATUS_DEFAULT_INTERVAL_FRAMES,
		CommandoFirearmRuntime.LINGERING_STATUS_DEFAULT_SLOW_MULTIPLIER,
		CommandoFirearmRuntime.LINGERING_STATUS_MIN_SLOW_MULTIPLIER,
		CommandoFirearmRuntime.LINGERING_STATUS_MAX_SLOW_MULTIPLIER,
		CommandoFirearmRuntime.LINGERING_STATUS_DEFAULT_SOURCE
	)


func _advance_runtime_lingering_effects(
	runtime: Object,
	fps_scale: float,
	context: Dictionary,
	deps: Dictionary
) -> Dictionary:
	return CommandoFirearmLingeringEffectState.advance_runtime_effects(
		runtime,
		context,
		deps,
		fps_scale,
		CommandoFirearmRuntime.NET_GUN_DASH_BREAK_FRAMES,
		CommandoFirearmRuntime.LINGERING_EFFECT_PHASE_STEP,
		Vector2(CommandoFirearmRuntime.FIELD_WIDTH, CommandoFirearmRuntime.FIELD_HEIGHT),
		CommandoFirearmRuntime.COMMANDO_NET_GUN_FIRE_MUZZLE_SOURCE,
		CommandoFirearmRuntime.COMMANDO_FIRE_SHEET_SOURCE_CELL_SIZE,
		CommandoFirearmRuntime.COMMANDO_FIRE_SHEET_PLAYER_FOOT_Y_OFFSET,
		CommandoFirearmRuntime.NET_GUN_WIDTH,
		CommandoFirearmRuntime.NET_GUN_MIN_HEIGHT,
		CommandoFirearmRuntime.LINGERING_STATUS_TARGET,
		CommandoFirearmRuntime.LINGERING_STATUS_ID_SLOW,
		CommandoFirearmRuntime.LINGERING_STATUS_DEFAULT_DURATION_FRAMES,
		CommandoFirearmRuntime.LINGERING_STATUS_DEFAULT_INTERVAL_FRAMES,
		CommandoFirearmRuntime.LINGERING_STATUS_DEFAULT_SLOW_MULTIPLIER,
		CommandoFirearmRuntime.LINGERING_STATUS_MIN_SLOW_MULTIPLIER,
		CommandoFirearmRuntime.LINGERING_STATUS_MAX_SLOW_MULTIPLIER,
		CommandoFirearmRuntime.LINGERING_STATUS_DEFAULT_SOURCE
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
