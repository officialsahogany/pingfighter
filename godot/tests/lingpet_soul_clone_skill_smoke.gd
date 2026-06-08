extends SceneTree

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetRailCard := preload("res://scripts/stages/common/lingpet_rail_card.gd")
const LingpetSkillDispatcher := preload("res://scripts/lingpet/lingpet_skill_dispatcher.gd")
const LingpetSkillRuntimeHost := preload("res://scripts/lingpet/lingpet_skill_runtime_host.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var ball_active := false
	var ball_pos := Vector2(380.0, 650.0)
	var ball_vel := Vector2(0.0, 10.0)
	var ball_size := 28.6
	var player_pos := Vector2(300.0, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var player_floor_y := 700.0
	var max_bounce_angle := 60.0
	var special_gauge := 0.0
	var special_gauge_max := 500.0


class FakeAudio:
	extends RefCounted

	var summon_count := 0
	var active_item_count := 0
	var paddle_hit_count := 0

	func play_lingpet_ghost_summon() -> void:
		summon_count += 1

	func play_active_item() -> void:
		active_item_count += 1

	func play_paddle_hit() -> void:
		paddle_hit_count += 1


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(next_instances: Dictionary = {}) -> void:
		instances = next_instances

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		return value if value is Object else null

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)


class FakeLingpetRuntime:
	extends RefCounted

	var snapshot: Dictionary = {}

	func is_companion_active(_pet_id: String = "") -> bool:
		return true

	func get_snapshot() -> Dictionary:
		return snapshot


func _init() -> void:
	_verify_dispatcher_and_catalog()
	_verify_runtime_hit_duration_and_reset()
	_verify_rail_card_casting_status()

	if _failures.is_empty():
		print("lingpet_soul_clone_skill_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_dispatcher_and_catalog() -> void:
	_expect(LingpetSkillDispatcher.is_supported_kind("soul_clone"), "soul_clone should be a supported lingpet runtime kind")
	_expect(LingpetSkillDispatcher.has_supported_runtime("rabi_soul_clone"), "Rabi Soul Clone should route to a supported runtime")
	_expect(LingpetSkillDispatcher.is_soul_clone("rabi_soul_clone"), "dispatcher should expose a Soul Clone helper")

	var skill: Dictionary = LingpetCatalog.get_active_skill_entry("rabi_soul_clone")
	_expect(not skill.is_empty(), "Rabi catalog should expose Soul Clone metadata")
	_expect(str(skill.get("runtime_kind", "")) == "soul_clone", "Soul Clone metadata should use the soul_clone runtime kind")
	_expect(str(skill.get("name", "")) == "영혼분신", "Rabi active skill should use the requested Korean Soul Clone name")
	_expect(is_equal_approx(float(skill.get("cooldown", 0.0)), 55.0), "Rabi Soul Clone should use the requested 55-second cooldown")
	_expect(is_equal_approx(float(skill.get("windup_seconds", 0.0)), 0.8), "Rabi Soul Clone should keep a short cast wind-up")
	_expect(str(LingpetCatalog.build_default_loadout("rabi").get("active_skill_id", "")) == "rabi_soul_clone", "Rabi default loadout should choose Soul Clone")
	_expect(LingpetCatalog.normalize_active_skill_id("rabi", "rabi_ghost_summon") == "rabi_ghost_summon", "legacy Rabi Ghost Summon loadouts should remain accepted")
	_expect(FileAccess.file_exists(str(skill.get("card_texture_path", ""))), "Soul Clone should use an existing Rabi card texture")
	_expect(FileAccess.file_exists(str(skill.get("icon_texture_path", ""))), "Soul Clone should use an existing Rabi icon texture")


func _verify_runtime_hit_duration_and_reset() -> void:
	var host: Object = LingpetSkillRuntimeHost.new()
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new({"game_audio": audio})
	var origin := Vector2(380.0, 650.0)
	_expect(host.launch("rabi_soul_clone", origin, owner, {"companion_pos": origin}), "runtime host should launch Rabi Soul Clone")
	host.trigger_launch_feedback("rabi_soul_clone", registry)
	_expect(audio.summon_count == 1 and audio.active_item_count == 0, "Soul Clone launch feedback should use the spiritual summon cue")
	_expect(host.is_launch_blocked("rabi_soul_clone"), "Soul Clone should block relaunch while the clone is active")

	host.update(0.10, owner, registry, "rabi_soul_clone")
	var snapshot: Dictionary = host.get_snapshot()
	_expect(bool(snapshot.get("soul_clone_active", false)), "Soul Clone should be active shortly after launch")
	_expect(is_equal_approx(float(snapshot.get("soul_clone_duration", 0.0)), 15.0), "Soul Clone should expose the requested 15-second duration")
	var clone_pos: Vector2 = snapshot.get("soul_clone_pos", Vector2.ZERO)
	_expect(clone_pos != Vector2.ZERO, "Soul Clone should expose its live clone position")

	owner.ball_active = true
	owner.ball_pos = clone_pos
	owner.ball_vel = Vector2(1.5, 9.0)
	host.update(0.016, owner, registry, "rabi_soul_clone")
	snapshot = host.get_snapshot()
	_expect(int(snapshot.get("soul_clone_hit_count", 0)) == 1, "Soul Clone should count a paddle-style ball hit")
	_expect(host.get_soul_clone_hit_count_for_tests() == 1, "runtime host should expose Soul Clone hit count for focused smoke coverage")
	_expect(owner.ball_vel.y < 0.0, "Soul Clone should reflect the ball upward toward the boss side")
	_expect(audio.paddle_hit_count == 1, "Soul Clone ball hit should reuse the paddle-hit sound")
	_expect(is_equal_approx(float(owner.special_gauge), 0.0), "Soul Clone should not grant extra gauge beyond the real companion body")

	host.update(15.05, owner, registry, "rabi_soul_clone")
	snapshot = host.get_snapshot()
	_expect(not bool(snapshot.get("soul_clone_active", true)), "Soul Clone should expire after its 15-second active window")
	_expect(not host.is_launch_blocked("rabi_soul_clone"), "Soul Clone should stop blocking relaunch after it expires")

	host.launch("rabi_soul_clone", origin, owner, {"companion_pos": origin})
	host.reset(owner, registry)
	snapshot = host.get_snapshot()
	_expect(not bool(snapshot.get("soul_clone_active", false)), "Soul Clone reset should clear active clone state")
	_expect(not host.has_visible_effects(), "Soul Clone reset should clear clone visuals and particles")


func _verify_rail_card_casting_status() -> void:
	var runtime := FakeLingpetRuntime.new()
	runtime.snapshot = {
		"companion_skill_id": "rabi_soul_clone",
		"companion_skill_name": "영혼분신",
		"companion_skill_description": "모락모랑의 영혼 분신이 공을 튕겨냅니다.",
		"companion_skill_card_path": "res://assets/sprites/lingpet/rabi_cutin_art_sd_identity_v3_clean.png",
		"companion_skill_cooldown": 44.0,
		"companion_skill_cooldown_duration": 55.0,
		"companion_skill_ready": false,
		"soul_clone_active": true,
	}
	var rail_entry: Dictionary = LingpetRailCard.build_entry(FakeRegistry.new({"lingpet_egg_runtime": runtime}))
	_expect(str(rail_entry.get("id", "")) == "rabi_soul_clone", "shared rail-card entry should use the Soul Clone skill id")
	_expect(str(rail_entry.get("status", "")) == "casting", "Soul Clone should read as casting while its clone is active")
	_expect(absf(float(rail_entry.get("cooldown_total", 0.0)) - 55.0) <= 0.01, "Soul Clone rail entry should carry its 55s cooldown")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
