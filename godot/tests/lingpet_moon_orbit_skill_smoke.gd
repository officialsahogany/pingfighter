extends SceneTree

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetRailCard := preload("res://scripts/stages/common/lingpet_rail_card.gd")
const LingpetSkillDispatcher := preload("res://scripts/lingpet/lingpet_skill_dispatcher.gd")
const LingpetSkillRuntimeHost := preload("res://scripts/lingpet/lingpet_skill_runtime_host.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var boss_pos := Vector2(330.0, 25.0)
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0
	var boss_wall_y := 12.0


class FakeStatusEffectState:
	extends RefCounted

	var calls: Array[Dictionary] = []

	func apply_status(target: String, status_id: String, duration_frames: float, data: Dictionary = {}, source: String = "") -> Dictionary:
		var status_call := {
			"target": target,
			"status_id": status_id,
			"duration_frames": duration_frames,
			"data": data.duplicate(true),
			"source": source,
		}
		calls.append(status_call)
		return status_call

	func get_calls_for_source(source: String) -> Array[Dictionary]:
		var matches: Array[Dictionary] = []
		for status_call in calls:
			if str(status_call.get("source", "")) == source:
				matches.append(status_call)
		return matches


class FakeRegistry:
	extends RefCounted

	var status_effect_state: Object = null
	var lingpet_runtime: Object = null

	func _init(status_state: Object = null, runtime: Object = null) -> void:
		status_effect_state = status_state
		lingpet_runtime = runtime

	func get_instance(key: String) -> Object:
		if key == "status_effect_state":
			return status_effect_state
		if key == "lingpet_egg_runtime":
			return lingpet_runtime
		return null


class FakeLingpetRuntime:
	extends RefCounted

	var snapshot: Dictionary = {}

	func is_companion_active(_pet_id: String = "") -> bool:
		return true

	func get_snapshot() -> Dictionary:
		return snapshot


func _init() -> void:
	_verify_dispatcher_and_catalog_scaffold()
	_verify_runtime_host_moon_orbit_flow()

	if _failures.is_empty():
		print("lingpet_moon_orbit_skill_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_dispatcher_and_catalog_scaffold() -> void:
	_expect(LingpetSkillDispatcher.is_supported_kind("moon_orbit"), "moon_orbit should be a supported lingpet runtime kind")
	_expect(LingpetSkillDispatcher.has_supported_runtime("draft_bat_moon_orbit"), "draft_bat_moon_orbit should route to a supported runtime")
	_expect(LingpetSkillDispatcher.is_moon_orbit("draft_bat_moon_orbit"), "dispatcher should expose a moon_orbit helper")

	var skill: Dictionary = LingpetCatalog.get_active_skill_entry("draft_bat_moon_orbit")
	_expect(not skill.is_empty(), "draft_bat catalog entry should expose the Moon Orbit skill metadata")
	_expect(str(skill.get("runtime_kind", "")) == "moon_orbit", "draft_bat skill metadata should use the moon_orbit runtime kind")
	_expect(str(skill.get("card_texture_path", "")).ends_with("draft_bat_moon_orbit_skillcard_imagegen_v1.png"), "draft_bat skill metadata should point at the accepted skill-card art")
	_expect(str(skill.get("icon_texture_path", "")).ends_with("draft_bat_moon_orbit_skill_icon_imagegen_v1.png"), "draft_bat skill metadata should point at the accepted skill icon")
	_expect(LingpetRailCard.is_lingpet_skill({"id": "draft_bat_moon_orbit"}), "shared rail-card helper should recognize draft_bat Moon Orbit as a lingpet skill")
	for visual_key in ["cutin_art", "cutin_anim", "cutin_dismiss_anim", "click_reaction_anim"]:
		var visual_path: String = LingpetCatalog.get_visual_path("draft_bat", visual_key)
		_expect(visual_path != "", "draft_bat should expose %s visual metadata even while disabled" % visual_key)
		_expect(FileAccess.file_exists(visual_path), "draft_bat visual file should exist for %s" % visual_key)
	_expect(not LingpetCatalog.get_pet_ids().has("draft_bat"), "draft_bat should stay disabled until its acquisition/click sheets are ready")
	_expect(LingpetCatalog.get_pet_ids(true).has("draft_bat"), "draft_bat should remain discoverable for tooling and future enablement")
	_expect(LingpetCatalog.validate_catalog(true).is_empty(), "disabled draft_bat metadata should not break strict catalog validation")

	var runtime := FakeLingpetRuntime.new()
	runtime.snapshot = {
		"companion_skill_id": "draft_bat_moon_orbit",
		"companion_skill_name": "월영 궤도",
		"companion_skill_description": "월영장을 만듭니다.",
		"companion_skill_card_path": str(skill.get("card_texture_path", "")),
		"companion_skill_cooldown": 12.0,
		"companion_skill_cooldown_duration": 35.0,
		"companion_skill_ready": false,
		"moon_orbit_projectile_active": false,
		"moon_orbit_field_active": true,
	}
	var rail_entry: Dictionary = LingpetRailCard.build_entry(FakeRegistry.new(null, runtime))
	_expect(str(rail_entry.get("id", "")) == "draft_bat_moon_orbit", "shared rail-card entry should use the Moon Orbit skill id")
	_expect(str(rail_entry.get("status", "")) == "casting", "Moon Orbit projectile/field should read as casting on the shared rail")


func _verify_runtime_host_moon_orbit_flow() -> void:
	var host: Object = LingpetSkillRuntimeHost.new()
	var owner := FakeOwner.new()
	var status_state := FakeStatusEffectState.new()
	var registry := FakeRegistry.new(status_state)
	var skill_id := "draft_bat_moon_orbit"
	var launch_origin := Vector2(380.0, 560.0)

	_expect(not host.has_visible_effects(), "fresh runtime host should not show Moon Orbit effects")
	_expect(host.launch(skill_id, launch_origin, owner), "runtime host should launch draft_bat Moon Orbit")
	_expect(host.is_launch_blocked(skill_id), "Moon Orbit should block relaunch while its projectile is in flight")
	_expect(host.has_visible_effects(), "Moon Orbit projectile should mark the runtime host as visible")

	host.update(1.0, owner, registry, skill_id)
	var snapshot: Dictionary = host.get_snapshot()
	_expect(not bool(snapshot.get("moon_orbit_projectile_active", true)), "Moon Orbit projectile should stop at the opponent wall")
	_expect(bool(snapshot.get("moon_orbit_field_active", false)), "Moon Orbit should create a field after the wall impact")
	_expect(float(snapshot.get("moon_orbit_field_half_width", 0.0)) > float(snapshot.get("moon_orbit_field_half_height", 0.0)) * 2.0, "Moon Orbit field should be a wide horizontal ellipse")
	_expect(is_equal_approx(float(snapshot.get("moon_orbit_slow_multiplier", 0.0)), 0.72), "Moon Orbit should expose its boss slow multiplier")

	var slow_calls: Array[Dictionary] = status_state.get_calls_for_source("draft_bat_moon_orbit_field")
	_expect(not slow_calls.is_empty(), "Moon Orbit field should apply boss slow while the boss overlaps it")
	if not slow_calls.is_empty():
		var first_slow: Dictionary = slow_calls[0]
		_expect(str(first_slow.get("target", "")) == "boss", "Moon Orbit slow should target the boss")
		_expect(str(first_slow.get("status_id", "")) == "slow", "Moon Orbit should reuse the slow status")
		_expect(is_equal_approx(float(first_slow.get("duration_frames", 0.0)), 4.0), "Moon Orbit slow should refresh with a short 4-frame duration")
		var data: Dictionary = first_slow.get("data", {}) as Dictionary
		_expect(is_equal_approx(float(data.get("multiplier", 0.0)), 0.72), "Moon Orbit slow should use the tuned 72 percent multiplier")
		_expect(str(data.get("visual", "")) == "draft_bat_moon_orbit", "Moon Orbit slow should tag its own visual id")

	host.update(4.3, owner, registry, skill_id)
	snapshot = host.get_snapshot()
	_expect(not bool(snapshot.get("moon_orbit_field_active", true)), "Moon Orbit field should expire after its 4-second duration")
	_expect(not host.is_launch_blocked(skill_id), "Moon Orbit should stop blocking launch after the field expires")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
