extends SceneTree

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetMilkShotSkill := preload("res://scripts/lingpet/lingpet_milk_shot_skill.gd")
const LingpetSkillDispatcher := preload("res://scripts/lingpet/lingpet_skill_dispatcher.gd")
const LingpetSkillRuntimeHost := preload("res://scripts/lingpet/lingpet_skill_runtime_host.gd")

const SKILL_ID := "milkring_milk_shot"

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var player_pos := Vector2(302.5, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var boss_pos := Vector2(330.0, 25.0)
	var boss_vel := 0.0
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0


class FakeAudio:
	extends RefCounted

	var shot_count := 0
	var hit_count := 0
	var active_item_count := 0
	var paddle_hit_count := 0

	func play_ragnarok_shot() -> void:
		shot_count += 1

	func play_commando_bullet_impact() -> void:
		hit_count += 1

	func play_active_item() -> void:
		active_item_count += 1

	func play_paddle_hit() -> void:
		paddle_hit_count += 1


class FakeBossAiState:
	extends RefCounted

	var knockback_calls := 0
	var last_velocity := 0.0
	var last_frames := 0.0
	var last_decay := 0.0
	var last_replace := false

	func start_paddle_hit_knockback(velocity: float, frames: float = 0.0, decay: float = 1.0, replace_current: bool = false) -> bool:
		knockback_calls += 1
		last_velocity = velocity
		last_frames = frames
		last_decay = decay
		last_replace = replace_current
		return true


class FakeStatusEffectState:
	extends RefCounted

	var applied: Array[Dictionary] = []

	func apply_status(target: String, status_id: String, duration_frames: float, data: Dictionary = {}, source: String = "") -> Dictionary:
		applied.append({
			"target": target,
			"status_id": status_id,
			"duration_frames": duration_frames,
			"data": data.duplicate(true),
			"source": source,
		})
		return {}

	func get_calls_for_source(source: String) -> Array[Dictionary]:
		var matches: Array[Dictionary] = []
		for status_call in applied:
			if str(status_call.get("source", "")) == source:
				matches.append(status_call)
		return matches


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(next_instances: Dictionary = {}) -> void:
		instances = next_instances

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		return value as Object if value is Object else null


func _init() -> void:
	_verify_dispatcher_catalog_assets_and_levels()
	_verify_normal_milk_shot_hits_boss_with_pistol_knockback()
	_verify_mega_roll_replaces_normal_volley()
	_verify_runtime_host_routes_milk_shot()

	if _failures.is_empty():
		print("lingpet_milk_shot_skill_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_dispatcher_catalog_assets_and_levels() -> void:
	_expect(LingpetSkillDispatcher.is_supported_kind("milk_shot"), "Milk Shot should be a supported lingpet runtime kind")
	_expect(LingpetSkillDispatcher.has_supported_runtime(SKILL_ID), "Milkring Milk Shot should route to a supported runtime")
	_expect(LingpetSkillDispatcher.is_milk_shot(SKILL_ID), "dispatcher should expose a Milk Shot helper")

	var skill: Dictionary = LingpetCatalog.get_active_skill_entry(SKILL_ID)
	_expect(not skill.is_empty(), "Milkring catalog should expose Milk Shot metadata")
	_expect(str(skill.get("runtime_kind", "")) == "milk_shot", "Milk Shot metadata should use the milk_shot runtime kind")
	var milkring_skill_ids := _skill_ids(LingpetCatalog.get_active_skill_pool("milkring"))
	_expect(milkring_skill_ids.has("milkring_milk_production"), "Milkring pool should keep Milk Production")
	_expect(milkring_skill_ids.has(SKILL_ID), "Milkring pool should add Milk Shot")
	_expect_eq(milkring_skill_ids.size(), 2, "Milkring should expose exactly two active candidates")

	var card_path := str(skill.get("card_texture_path", ""))
	var icon_path := str(skill.get("icon_texture_path", ""))
	_expect(load(card_path) is Texture2D, "Milk Shot skill card should import as a Texture2D")
	_expect(load(icon_path) is Texture2D, "Milk Shot skill icon should import as a Texture2D")
	_expect(LingpetCatalog.validate_catalog(true).is_empty(), "live lingpet catalog should validate with Milk Shot card/icon art")

	var expected_cooldowns := [30.0, 27.5, 25.0, 22.5, 20.0]
	var expected_stuns := [0.3, 0.4, 0.5, 0.6, 0.7]
	var expected_knockbacks := [8.0, 10.0, 12.0, 14.0, 16.0]
	var expected_counts := [8, 8, 10, 10, 12]
	var expected_durations := [0.8, 0.92, 1.05, 1.18, 1.3]
	var expected_mega_chances := [0.0, 0.0, 0.30, 0.30, 0.30]
	var expected_mega_counts := [0, 0, 30, 40, 50]
	var expected_mega_durations := [0.0, 0.0, 1.0, 1.25, 1.5]
	for level in range(1, 6):
		var level_skill: Dictionary = LingpetCatalog.get_active_skill("milkring", SKILL_ID, level)
		_expect_float(float(level_skill.get("cooldown", -1.0)), float(expected_cooldowns[level - 1]), "Milk Shot Lv.%d cooldown should be authoritative" % level)
		_expect_float(float(level_skill.get("active_skill_level_cooldown_reduction_pct", -1.0)), 0.0, "Milk Shot Lv.%d should not double-apply universal cooldown tax" % level)
		_expect(bool(level_skill.get("cooldown_by_level_authoritative", false)), "Milk Shot Lv.%d should mark cooldown_by_level as authoritative" % level)
		_expect_float(float(level_skill.get("stun_duration_seconds", -1.0)), float(expected_stuns[level - 1]), "Milk Shot Lv.%d stun seconds should match the locked table" % level)
		_expect_float(float(level_skill.get("knockback_power", -1.0)), float(expected_knockbacks[level - 1]), "Milk Shot Lv.%d knockback should match the Commando pistol baseline table" % level)
		_expect_eq(int(level_skill.get("projectile_count", -1)), int(expected_counts[level - 1]), "Milk Shot Lv.%d projectile count should match the locked table" % level)
		_expect_float(float(level_skill.get("fire_duration_seconds", -1.0)), float(expected_durations[level - 1]), "Milk Shot Lv.%d fire duration should match the locked table" % level)
		_expect_float(float(level_skill.get("mega_chance", -1.0)), float(expected_mega_chances[level - 1]), "Milk Shot Lv.%d mega chance should match the locked table" % level)
		_expect_eq(int(level_skill.get("mega_projectile_count", -1)), int(expected_mega_counts[level - 1]), "Milk Shot Lv.%d mega projectile count should match the locked table" % level)
		_expect_float(float(level_skill.get("mega_duration_seconds", -1.0)), float(expected_mega_durations[level - 1]), "Milk Shot Lv.%d mega duration should match the locked table" % level)


func _verify_normal_milk_shot_hits_boss_with_pistol_knockback() -> void:
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var boss_ai := FakeBossAiState.new()
	var status_state := FakeStatusEffectState.new()
	var registry := FakeRegistry.new({
		"game_audio": audio,
		"boss_ai_state": boss_ai,
		"status_effect_state": status_state,
	})
	var skill: Object = LingpetMilkShotSkill.new()
	var launch_context := _skill_context(1, registry, 1.0)
	_expect(bool(skill.launch(Vector2(380.0, 640.0), owner, launch_context)), "Lv.1 normal Milk Shot should launch")
	var snapshot: Dictionary = skill.get_snapshot()
	_expect(str(snapshot.get("milk_shot_mode", "")) == "normal", "Lv.1 Milk Shot should always use the normal volley")
	_expect_eq(int(snapshot.get("milk_shot_launch_shot_count", 0)), 2, "normal Milk Shot should fire the first left/right volley immediately")
	for i in range(28):
		skill.update(0.04, owner, registry)
		if int(skill.get_snapshot().get("milk_shot_launch_hit_count", 0)) >= 1 and int(skill.get_snapshot().get("milk_shot_launch_shot_count", 0)) >= 8:
			break
	snapshot = skill.get_snapshot()
	_expect_eq(int(snapshot.get("milk_shot_launch_shot_count", 0)), 8, "Lv.1 normal Milk Shot should fire eight projectiles (4 volleys x left/right pair)")
	_expect(int(snapshot.get("milk_shot_launch_hit_count", 0)) >= 1, "Milk Shot projectiles should hit the boss-center radial hit zone")
	_expect(boss_ai.knockback_calls == 0, "Milk Shot should let shared boss stun status own knockback when status state exists")
	var stun_calls := status_state.get_calls_for_source(SKILL_ID)
	_expect(not stun_calls.is_empty(), "Milk Shot should apply boss stun status on projectile impact")
	if not stun_calls.is_empty():
		var status_call: Dictionary = stun_calls[0]
		var status_data: Dictionary = status_call.get("data", {}) as Dictionary
		_expect(str(status_call.get("target", "")) == "boss", "Milk Shot status should target boss")
		_expect(str(status_call.get("status_id", "")) == "stun", "Milk Shot should apply stun")
		_expect_float(float(status_call.get("duration_frames", 0.0)), 18.0, "Milk Shot Lv.1 stun should be 0.3 seconds at 60 FPS")
		_expect_float(absf(float(status_data.get("knockback_vel", 0.0))), 8.0, "Milk Shot Lv.1 knockback should use pistol power 8.0")
		_expect_float(float(status_data.get("knockback_frames", 0.0)), 18.0, "Milk Shot knockback should last 18 frames")
		_expect_float(float(status_data.get("knockback_decay_per_frame", 0.0)), 0.85, "Milk Shot knockback decay should match the pistol baseline")
		_expect(str(status_data.get("source", "")) == SKILL_ID, "Milk Shot status data should keep the source id")

	var radial_skill: Object = LingpetMilkShotSkill.new()
	var boss_rect := Rect2(Vector2(330.0, 25.0), Vector2(100.0, 40.0))
	var boss_center := boss_rect.get_center()
	_expect(bool(radial_skill._projectile_hits_boss(boss_center, boss_rect)), "Milk Shot hit geometry should accept the boss center")
	_expect(not bool(radial_skill._projectile_hits_boss(boss_center + Vector2(66.0, 0.0), boss_rect)), "Milk Shot hit geometry should reject points outside the boss-center radius")


func _verify_mega_roll_replaces_normal_volley() -> void:
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new({})
	var lv3_skill: Object = LingpetMilkShotSkill.new()
	_expect(bool(lv3_skill.launch(Vector2(380.0, 640.0), owner, _skill_context(3, registry, 0.10))), "Lv.3 mega success fixture should launch")
	for i in range(40):
		lv3_skill.update(0.04, owner, registry)
	var lv3_snapshot: Dictionary = lv3_skill.get_snapshot()
	_expect(str(lv3_snapshot.get("milk_shot_mode", "")) == "mega", "Lv.3 roll below 30% should replace normal volley with mega shot")
	_expect_eq(int(lv3_snapshot.get("milk_shot_projectile_limit", 0)), 30, "Lv.3 mega Milk Shot should schedule 30 projectiles")
	_expect_eq(int(lv3_snapshot.get("milk_shot_launch_shot_count", 0)), 30, "Lv.3 mega Milk Shot should fire exactly 30 projectiles")
	_expect_float(float(lv3_snapshot.get("milk_shot_last_mega_roll", -1.0)), 0.10, "Milk Shot should consume the per-launch mega roll once")

	var lv3_fail_skill: Object = LingpetMilkShotSkill.new()
	_expect(bool(lv3_fail_skill.launch(Vector2(380.0, 640.0), owner, _skill_context(3, registry, 0.90))), "Lv.3 normal fallback fixture should launch")
	for i in range(40):
		lv3_fail_skill.update(0.04, owner, registry)
	var lv3_fail_snapshot: Dictionary = lv3_fail_skill.get_snapshot()
	_expect(str(lv3_fail_snapshot.get("milk_shot_mode", "")) == "normal", "Lv.3 roll above 30% should keep the normal volley")
	_expect_eq(int(lv3_fail_snapshot.get("milk_shot_projectile_limit", 0)), 10, "Lv.3 normal Milk Shot should schedule ten projectiles (5 volleys x 2)")
	_expect_eq(int(lv3_fail_snapshot.get("milk_shot_launch_shot_count", 0)), 10, "Lv.3 normal Milk Shot should fire ten projectiles (5 full left/right volleys)")

	var lv5_skill: Object = LingpetMilkShotSkill.new()
	_expect(bool(lv5_skill.launch(Vector2(380.0, 640.0), owner, _skill_context(5, registry, 0.90))), "Lv.5 mega failure fixture should launch")
	for i in range(40):
		lv5_skill.update(0.04, owner, registry)
	var lv5_snapshot: Dictionary = lv5_skill.get_snapshot()
	_expect(str(lv5_snapshot.get("milk_shot_mode", "")) == "normal", "Lv.5 roll above 30% should keep the normal volley")
	_expect_eq(int(lv5_snapshot.get("milk_shot_projectile_limit", 0)), 12, "Lv.5 normal Milk Shot should schedule twelve projectiles (6 volleys x 2)")
	_expect_eq(int(lv5_snapshot.get("milk_shot_launch_shot_count", 0)), 12, "Lv.5 normal Milk Shot should fire twelve projectiles (6 volleys), not the 50-shot mega")
	_expect_float(float(lv5_snapshot.get("milk_shot_last_mega_roll", -1.0)), 0.90, "Milk Shot failed mega fixture should record the per-launch roll")


func _verify_runtime_host_routes_milk_shot() -> void:
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var status_state := FakeStatusEffectState.new()
	var registry := FakeRegistry.new({
		"game_audio": audio,
		"status_effect_state": status_state,
	})
	var host: Object = LingpetSkillRuntimeHost.new()
	var launch_context := _skill_context(5, registry, 0.90)
	_expect(bool(host.launch(SKILL_ID, Vector2(380.0, 640.0), owner, launch_context)), "runtime host should launch Milkring Milk Shot")
	_expect(host.has_visible_effects_for_skill(SKILL_ID), "runtime host should expose Milk Shot visible effects after launch")
	for i in range(40):
		host.update(0.04, owner, registry, SKILL_ID, launch_context)
	var snapshot: Dictionary = host.get_milk_shot_snapshot_for_tests()
	_expect_eq(int(snapshot.get("milk_shot_launch_shot_count", 0)), 12, "runtime host should forward Lv.5 Milk Shot level values (6 volleys x 2)")
	_expect(int(host.get_milk_shot_hit_count_for_tests()) >= 1, "runtime host Milk Shot should hit through the shared update path")


func _skill_context(level: int, registry: Object, mega_roll: float) -> Dictionary:
	var context: Dictionary = LingpetCatalog.get_active_skill("milkring", SKILL_ID, level)
	context["registry"] = registry
	context["active_skill_id"] = SKILL_ID
	context["active_skill_level"] = level
	context["companion_pos"] = Vector2(380.0, 640.0)
	context["milk_shot_mega_roll"] = mega_roll
	return context


func _skill_ids(pool: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for skill in pool:
		var skill_id := str(skill.get("id", "")).strip_edges()
		if skill_id != "" and not result.has(skill_id):
			result.append(skill_id)
	return result


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: int, expected: int, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %d, got %d)" % [message, expected, actual])


func _expect_float(actual: float, expected: float, message: String, epsilon: float = 0.001) -> void:
	if not is_equal_approx(actual, expected) and absf(actual - expected) > epsilon:
		_failures.append("%s (expected %.4f, got %.4f)" % [message, expected, actual])
