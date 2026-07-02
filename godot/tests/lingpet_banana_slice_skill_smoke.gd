extends SceneTree

const LingpetBananaSliceSkill := preload("res://scripts/lingpet/lingpet_banana_slice_skill.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetSkillDispatcher := preload("res://scripts/lingpet/lingpet_skill_dispatcher.gd")
const LingpetSkillRuntimeHost := preload("res://scripts/lingpet/lingpet_skill_runtime_host.gd")
const BattleUpdateBossAiContextBuilder := preload("res://scripts/core/battle_update_boss_ai_context_builder.gd")
const BossAiState := preload("res://scripts/ai/boss_ai_state.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const SKILL_ID := "monkeyring_banana_slice"
const CARD_PATH := "res://assets/sprites/lingpet/monkeyring_banana_slice_skillcard_imagegen_v1.png"
const ICON_PATH := "res://assets/sprites/lingpet/monkeyring_banana_slice_skill_icon_imagegen_v1.png"

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var current_stage := 1
	var ai_mode := "champion"
	var selected_character_type := "smasher"
	var boss_pos := Vector2(210.0, 25.0)
	var boss_vel := 0.0
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0
	var player_pos := Vector2(300.0, 675.0)
	var ball_active := true
	var waiting_for_serve := false
	var ball_pos := Vector2(300.0, 300.0)
	var ball_vel := Vector2(0.0, -8.0)
	var ball_impact_boost := 1.0
	var ball_boost_decay_rate := 0.975
	var ball_min_boost := 0.70
	var lingpet_puppet_grab_active := false


class FakeAudio:
	extends RefCounted

	var banana_throw_count := 0
	var banana_slip_count := 0

	func play_banana_throw() -> void:
		banana_throw_count += 1

	func play_banana_slip() -> void:
		banana_slip_count += 1


class FakeRegistry:
	extends RefCounted

	var game_audio: Object = null
	var lingpet_egg_runtime: Object = null

	func _init(audio: Object = null, lingpet_runtime: Object = null) -> void:
		game_audio = audio
		lingpet_egg_runtime = lingpet_runtime

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)

	func get_instance(key: String) -> Object:
		match key:
			"game_audio":
				return game_audio
			"lingpet_egg_runtime":
				return lingpet_egg_runtime
		return null


class FakeLingpetContextSource:
	extends RefCounted

	var context := {}

	func get_boss_ai_context() -> Dictionary:
		return context


func _init() -> void:
	seed(20260611)
	_verify_catalog_dispatcher_and_assets()
	_verify_level_scaling_tables_and_launch_context()
	_verify_prepare_throw_delay_and_audio()
	_verify_flight_actually_lands_in_boss_band()
	_verify_landed_banana_triggers_boss_slip()
	_verify_offcenter_slip_direction_and_expiry()
	_verify_boss_ai_context_builder_and_motion()
	_verify_host_wiring_and_cleanup_guards()

	if _failures.is_empty():
		print("lingpet_banana_slice_skill_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_catalog_dispatcher_and_assets() -> void:
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_banana_slice_skill.gd"), "Banana Slice skill module should exist")
	_expect(FileAccess.file_exists(CARD_PATH), "Banana Slice skill card should exist")
	_expect(FileAccess.file_exists(ICON_PATH), "Banana Slice skill icon should exist")
	var card := ProjectResourceLoader.load_texture(CARD_PATH)
	var icon := ProjectResourceLoader.load_texture(ICON_PATH)
	_expect(card != null and card.get_width() == 1720 and card.get_height() == 541, "Banana Slice skill card should load at the catalog card size")
	_expect(icon != null and icon.get_width() == 1254 and icon.get_height() == 1254, "Banana Slice skill icon should load at the catalog icon size")
	var banana := ProjectResourceLoader.load_texture("res://assets/sprites/items/banana.png")
	_expect(banana != null, "Banana Slice should reuse the shared banana texture")

	var skill: Dictionary = LingpetCatalog.get_active_skill("monkeyring")
	_expect(str(skill.get("id", "")) == SKILL_ID, "Ppanamong default active skill should be Banana Slice")
	_expect(str(skill.get("runtime_kind", "")) == "banana_slice", "Banana Slice catalog entry should use banana_slice runtime kind")
	_expect(str(skill.get("name", "")) == "바나나 슬라이스", "Banana Slice should use the requested Korean skill name")
	_expect(str(skill.get("description", "")).find("바나나 두 개를 꺼내") < 0, "Banana Slice description should not claim Lv.1 always throws two bananas")
	_expect(is_equal_approx(float(skill.get("cooldown", 0.0)), 18.0), "Banana Slice should keep the original 18-second cooldown")
	_expect(is_equal_approx(float(skill.get("windup_seconds", 0.0)), 0.45), "Banana Slice should use the Ppanamong 0.45-second windup")
	_expect(is_equal_approx(float(skill.get("slip_seconds", 0.0)), 0.45), "Banana Slice Lv.1 catalog should expose the tuned 0.45-second slip")
	_expect(LingpetSkillDispatcher.is_banana_slice(SKILL_ID), "dispatcher should expose Banana Slice helper")
	_expect(LingpetCatalog.validate_catalog(true).is_empty(), "lingpet catalog should validate with Banana Slice card/icon art")


func _verify_level_scaling_tables_and_launch_context() -> void:
	var lv1: Dictionary = LingpetCatalog.get_active_skill("monkeyring", SKILL_ID, 1)
	var lv2: Dictionary = LingpetCatalog.get_active_skill("monkeyring", SKILL_ID, 2)
	var lv3: Dictionary = LingpetCatalog.get_active_skill("monkeyring", SKILL_ID, 3)
	var lv5: Dictionary = LingpetCatalog.get_active_skill("monkeyring", SKILL_ID, 5)
	_expect(int(lv1.get("banana_count", 0)) == 1, "Banana Slice Lv.1 should flatten to one banana")
	_expect(int(lv2.get("banana_count", 0)) == 1, "Banana Slice Lv.2 should still flatten to one banana")
	_expect(int(lv3.get("banana_count", 0)) == 2, "Banana Slice Lv.3 should be the two-banana boundary")
	_expect(int(lv5.get("banana_count", 0)) == 2, "Banana Slice Lv.5 should stay at two bananas")
	_expect(is_equal_approx(float(lv1.get("slip_speed", 0.0)), 15.0), "Banana Slice Lv.1 should keep original 15 px/frame slip speed")
	_expect(is_equal_approx(float(lv3.get("slip_speed", 0.0)), 17.5), "Banana Slice Lv.3 should flatten to 17.5 px/frame slip speed")
	_expect(is_equal_approx(float(lv5.get("slip_speed", 0.0)), 20.0), "Banana Slice Lv.5 should flatten to 20 px/frame slip speed")
	_expect(is_equal_approx(float(lv1.get("slip_seconds", 0.0)), 0.45), "Banana Slice Lv.1 should use the shortest boss slip duration")
	_expect(is_equal_approx(float(lv3.get("slip_seconds", 0.0)), 0.65), "Banana Slice Lv.3 should scale boss slip duration")
	_expect(is_equal_approx(float(lv5.get("slip_seconds", 0.0)), 0.80), "Banana Slice Lv.5 should restore the original 0.8s boss slip duration")

	_expect(_projectile_count_after_prepare(1) == 1, "Banana Slice Lv.1 default launch should throw exactly one banana")
	_expect(_projectile_count_after_prepare(2) == 1, "Banana Slice Lv.2 launch should throw exactly one banana")
	_expect(_projectile_count_after_prepare(3) == 2, "Banana Slice Lv.3 launch should throw exactly two bananas")

	var owner := FakeOwner.new()
	var lv5_skill := LingpetBananaSliceSkill.new()
	var registry := FakeRegistry.new(FakeAudio.new(), null)
	_expect(bool(lv5_skill.launch(Vector2(300.0, 610.0), owner, {"active_skill_level": 5})), "Banana Slice Lv.5 launch should accept active_skill_level context")
	lv5_skill.force_land_for_tests(Vector2(260.0, 45.0))
	lv5_skill.set_slip_direction_rolls_for_tests([1.0])
	lv5_skill.update(1.0 / 60.0, owner, registry)
	var lv5_context := lv5_skill.get_boss_ai_context()
	_expect(is_equal_approx(float(lv5_context.get("lingpet_banana_slice_boss_slip_speed", 0.0)), 20.0), "Banana Slice Lv.5 slip should begin at 20 px/frame")
	_expect(is_equal_approx(float(lv5_skill.get_snapshot().get("banana_slice_slip_seconds", 0.0)), 0.80), "Banana Slice Lv.5 runtime should arm the original 0.8s boss slip")

	var lv1_skill := LingpetBananaSliceSkill.new()
	_expect(bool(lv1_skill.launch(Vector2(300.0, 610.0), owner, {"active_skill_level": 1})), "Banana Slice Lv.1 launch should accept active_skill_level context")
	_expect(is_equal_approx(float(lv1_skill.get_snapshot().get("banana_slice_slip_seconds", 0.0)), 0.45), "Banana Slice Lv.1 launch should resolve the tuned 0.45s slip through level scaling, not a flat constant")

	var override_skill := LingpetBananaSliceSkill.new()
	_expect(bool(override_skill.launch(Vector2(300.0, 610.0), owner, {"active_skill_level": 1, "slip_seconds": 0.32})), "Banana Slice launch should accept explicit slip duration context")
	_expect(is_equal_approx(float(override_skill.get_snapshot().get("banana_slice_slip_seconds", 0.0)), 0.32), "Banana Slice launch context should override slip duration for catalog-driven launches")


func _verify_prepare_throw_delay_and_audio() -> void:
	var skill := LingpetBananaSliceSkill.new()
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new(audio, null)
	skill.set_landing_xs_for_tests([260.0, 420.0])
	_expect(bool(skill.launch(Vector2(300.0, 610.0), owner, {"registry": registry, "active_skill_level": 3})), "Banana Slice should launch")
	skill.update(0.29, owner, registry)
	_expect(int(skill.get_snapshot().get("banana_slice_projectile_count", -1)) == 0, "Banana Slice PREPARE should not spawn projectiles early")
	_expect(audio.banana_throw_count == 0, "Banana Slice should not play throw audio during PREPARE")
	skill.update(0.02, owner, registry)
	var snap: Dictionary = skill.get_snapshot()
	_expect(int(snap.get("banana_slice_projectile_count", -1)) == 2, "Banana Slice should spawn exactly two bananas after PREPARE")
	_expect(audio.banana_throw_count == 1, "Banana Slice should play one throw cue when both bananas launch")
	var projectiles: Array = snap.get("banana_slice_projectiles", []) as Array
	_expect(projectiles.size() == 2, "Banana Slice snapshot should expose two projectiles")
	if projectiles.size() == 2:
		_expect(is_equal_approx(float((projectiles[0] as Dictionary).get("delay", -1.0)), 0.0), "first Banana Slice projectile should be active immediately")
		_expect(is_equal_approx(float((projectiles[1] as Dictionary).get("delay", -1.0)), 0.15), "second Banana Slice projectile should keep the 0.15s launch delay")
	skill.update(0.10, owner, registry)
	var mid_projectiles: Array = skill.get_snapshot().get("banana_slice_projectiles", []) as Array
	if mid_projectiles.size() == 2:
		_expect(float((mid_projectiles[1] as Dictionary).get("delay", 0.0)) > 0.0, "second Banana Slice projectile should still be delayed at 0.10s")


func _verify_flight_actually_lands_in_boss_band() -> void:
	var skill := LingpetBananaSliceSkill.new()
	var owner := FakeOwner.new()
	owner.boss_pos = Vector2(600.0, 25.0)
	var registry := FakeRegistry.new(FakeAudio.new(), null)
	skill.set_landing_xs_for_tests([200.0, 420.0])
	_expect(bool(skill.launch(Vector2(300.0, 610.0), owner, {"registry": registry, "active_skill_level": 3})), "flight case should launch")
	var guard := 0
	while skill.get_landed_count_for_tests() < 2 and guard < 240:
		skill.update(1.0 / 60.0, owner, registry)
		guard += 1
	_expect(skill.get_landed_count_for_tests() == 2, "both thrown bananas should really fly and land in the boss band")
	_expect(skill.get_projectile_count_for_tests() == 0, "no projectile should keep flying after both bananas landed")
	var landed: Array = skill.get_snapshot().get("banana_slice_landed_bananas", []) as Array
	for entry_value in landed:
		var entry: Dictionary = entry_value as Dictionary
		var pos: Vector2 = entry.get("position", Vector2.ZERO)
		_expect(is_equal_approx(pos.y, 45.0), "landed banana should rest exactly on the boss band y")
		_expect(pos.x >= 30.0 and pos.x <= 730.0, "landed banana x should stay inside the 30..730 clamp")
	_expect(skill.get_slip_state_for_tests().get("active", true) == false, "landing far from the boss should not arm a slip")


func _verify_landed_banana_triggers_boss_slip() -> void:
	var skill := LingpetBananaSliceSkill.new()
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new(audio, null)
	skill.force_land_for_tests(Vector2(260.0, 45.0))
	skill.set_slip_direction_rolls_for_tests([1.0])
	skill.update(1.0 / 60.0, owner, registry)
	var context := skill.get_boss_ai_context()
	_expect(bool(context.get("lingpet_banana_slice_boss_slip_active", false)), "stepping on Banana Slice should expose an active boss slip context")
	_expect(is_equal_approx(float(context.get("lingpet_banana_slice_boss_slip_direction", 0.0)), 1.0), "centered Banana Slice slip should use the injected random direction")
	_expect(is_equal_approx(float(context.get("lingpet_banana_slice_boss_slip_speed", 0.0)), 15.0), "Banana Slice slip should begin at 15 px/frame")
	_expect(is_equal_approx(float(skill.get_snapshot().get("banana_slice_slip_seconds", 0.0)), 0.45), "Banana Slice Lv.1 runtime should arm the tuned shorter slip duration")
	_expect(audio.banana_slip_count == 1, "Banana Slice should play the slip cue when the boss steps on it")
	_expect(skill.get_landed_count_for_tests() == 0, "triggered Banana Slice banana should disappear after one slip")
	skill.update(0.225, owner, registry)
	var half_context := skill.get_boss_ai_context()
	_expect(absf(float(half_context.get("lingpet_banana_slice_boss_slip_speed", 0.0)) - 7.5) <= 0.35, "Banana Slice slip speed should decay linearly near half duration")
	skill.update(0.24, owner, registry)
	_expect(skill.get_boss_ai_context().is_empty(), "Banana Slice Lv.1 slip context should clear after the tuned 0.45s duration")
	skill.cancel(null, null)
	_expect(skill.get_boss_ai_context().is_empty(), "Banana Slice cancel should clear the boss slip context")


func _verify_offcenter_slip_direction_and_expiry() -> void:
	var skill := LingpetBananaSliceSkill.new()
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new(audio, null)
	# Boss rect 210..310 (center 260) vs banana at 230: off-center contact must use
	# the deterministic original formula (paddle_cx > banana_x -> slide left).
	skill.force_land_for_tests(Vector2(230.0, 45.0))
	skill.update(1.0 / 60.0, owner, registry)
	var context := skill.get_boss_ai_context()
	_expect(bool(context.get("lingpet_banana_slice_boss_slip_active", false)), "off-center step should arm the slip")
	_expect(is_equal_approx(float(context.get("lingpet_banana_slice_boss_slip_direction", 0.0)), -1.0), "boss centered right of the banana should slide left (original momentum formula)")
	skill.cancel(null, null)

	var expiry_skill := LingpetBananaSliceSkill.new()
	var expiry_audio := FakeAudio.new()
	var expiry_registry := FakeRegistry.new(expiry_audio, null)
	expiry_skill.force_land_for_tests(Vector2(500.0, 45.0), 0.05)
	expiry_skill.update(0.10, owner, expiry_registry)
	_expect(expiry_skill.get_landed_count_for_tests() == 0, "landed banana should expire after its 3s timer without a step")
	_expect(expiry_skill.get_slip_state_for_tests().get("active", true) == false, "expired banana must not arm a slip")
	_expect(expiry_audio.banana_slip_count == 0, "expired banana must not play the slip cue")
	_expect(expiry_skill.get_boss_ai_context().is_empty(), "expired banana must not expose a boss slip context")


func _verify_boss_ai_context_builder_and_motion() -> void:
	var source := FakeLingpetContextSource.new()
	source.context = {
		"lingpet_banana_slice_boss_slip_active": true,
		"lingpet_banana_slice_boss_slip_direction": 1.0,
		"lingpet_banana_slice_boss_slip_speed": 15.0,
	}
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(null, source)
	var builder := BattleUpdateBossAiContextBuilder.new()
	var context: Dictionary = builder.build_context(owner, registry)
	_expect(bool(context.get("lingpet_banana_slice_boss_slip_active", false)), "boss AI context builder should merge Banana Slice lingpet context")
	var boss_ai := BossAiState.new()
	var result: Dictionary = boss_ai.update(1.0 / 60.0, owner.boss_pos, 0.0, context)
	var next_pos: Vector2 = result.get("boss_pos", owner.boss_pos)
	_expect(is_equal_approx(next_pos.x, owner.boss_pos.x + 15.0), "Boss AI should apply Banana Slice slip as px/frame motion")
	_expect(is_equal_approx(float(result.get("boss_vel", 0.0)), 15.0), "Boss AI should early-return Banana Slice slip velocity instead of tracking the ball")


func _verify_host_wiring_and_cleanup_guards() -> void:
	var host := LingpetSkillRuntimeHost.new()
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new(audio, null)
	_expect(bool(host.launch(SKILL_ID, Vector2(300.0, 610.0), owner, {"registry": registry, "active_skill_level": 3})), "skill runtime host should launch Banana Slice")
	_expect(bool(host.is_launch_blocked(SKILL_ID)), "Banana Slice should block re-arm while PREPARE is active")
	host.update(0.31, owner, registry, SKILL_ID, {"registry": registry})
	_expect(host.get_banana_slice_projectile_count_for_tests() == 2, "skill runtime host should update Banana Slice projectiles")
	host.reset(owner, registry)
	_expect((host.get_boss_ai_context() as Dictionary).is_empty(), "skill runtime host reset should clear Banana Slice boss context")

	var skill_src := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_banana_slice_skill.gd")
	_expect(skill_src.find("owner.set(") < 0, "Banana Slice should not invent owner schema keys")
	_expect(skill_src.find("skip_ball_motion_step") < 0, "Banana Slice should not own or skip the ball motion step")
	_expect(skill_src.find("ball_pos") < 0 and skill_src.find("ball_vel") < 0, "Banana Slice should not read or write ball position/velocity")
	_expect(skill_src.find("SLIP_SPEED_PER_FRAME") < 0, "Banana Slice slip speed should come from level-aware instance state, not a fixed constant")
	var payload_builder_src := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_skill_launch_payload_builder.gd")
	_expect(payload_builder_src.find("\"banana_count\"") >= 0 and payload_builder_src.find("\"slip_speed\"") >= 0, "launch payload builder should pass Banana Slice flattened level values into launch_context")
	var host_src := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_skill_runtime_host.gd")
	var start := host_src.find("func get_boss_ai_context")
	var end := host_src.find("func get_snapshot")
	_expect(start >= 0 and end > start, "skill runtime host should expose get_boss_ai_context before snapshots")
	if start >= 0 and end > start:
		var boss_context_src := host_src.substr(start, end - start)
		_expect(boss_context_src.find("_get_banana_slice_skill") < 0, "host get_boss_ai_context should use the cached Banana Slice member, not lazy-create on the hot path")


func _projectile_count_after_prepare(active_skill_level: int) -> int:
	var skill := LingpetBananaSliceSkill.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(FakeAudio.new(), null)
	skill.set_landing_xs_for_tests([260.0, 420.0])
	if not bool(skill.launch(Vector2(300.0, 610.0), owner, {"active_skill_level": active_skill_level})):
		return -1
	skill.update(0.31, owner, registry)
	return int(skill.get_snapshot().get("banana_slice_projectile_count", -1))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
