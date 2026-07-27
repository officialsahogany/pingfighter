extends SceneTree

# expect-zero-object-leaks

const OWNER_PATH := "res://scripts/lingpet/lingpet_skill_companion_surface_router.gd"
const HOST_PATH := "res://scripts/lingpet/lingpet_skill_runtime_host.gd"

var _failures: Array[String] = []


class FakeSkill:
	extends RefCounted

	var override_active := true
	var override_pos := Vector2(321.0, 654.0)
	var suppress_hit := true
	var suppress_draw := true
	var strike_pending := true
	var pose_progress := 0.625

	func has_companion_position_override() -> bool:
		return override_active

	func get_companion_position_override(fallback: Vector2) -> Vector2:
		return override_pos if override_active else fallback

	func suppresses_companion_body_hit() -> bool:
		return suppress_hit

	func suppresses_companion_body_draw() -> bool:
		return suppress_draw

	func consume_companion_strike_request() -> bool:
		var result := strike_pending
		strike_pending = false
		return result

	func get_companion_cast_pose_progress() -> float:
		return pose_progress


func _init() -> void:
	_verify_owner_boundary()
	if FileAccess.file_exists(OWNER_PATH):
		_verify_launch_origins()
		_verify_position_override_policy()
		_verify_body_presence_policy()
		_verify_strike_request_policy()
		_verify_cast_pose_and_windup_policy()

	if _failures.is_empty():
		print("lingpet_skill_companion_surface_router_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_owner_boundary() -> void:
	_expect(FileAccess.file_exists(OWNER_PATH), "Ringpet companion skill surface should have a focused router")
	if not FileAccess.file_exists(OWNER_PATH):
		return
	var host_source := FileAccess.get_file_as_string(HOST_PATH)
	var router_source := FileAccess.get_file_as_string(OWNER_PATH)
	_expect(host_source.contains("LingpetSkillCompanionSurfaceRouter"), "skill host should preload the companion-surface router")
	_expect(host_source.contains("_companion_surface_router.get_launch_origin(skill_id, companion_pos, companion_radius)"), "launch-origin facade should delegate unchanged inputs")
	_expect(host_source.contains("_companion_surface_router.has_companion_position_override(skill_kind, skill)"), "position-override facade should delegate resolved kind and existing module")
	_expect(host_source.contains("func get_active_position_override_owner"), "host should retain cross-slot position-owner payload priority")
	_expect(not host_source.contains("-maxf(0.0, companion_radius) - 8.0"), "host should not retain launch-origin geometry")
	_expect(not host_source.contains("-maxf(0.0, companion_radius) - 10.0"), "host should not retain elevated launch-origin geometry")
	_expect(router_source.contains("func get_launch_origin("), "focused router should own launch-origin geometry")
	_expect(not router_source.contains("Callable") and not router_source.contains("Dictionary"), "companion-surface router should stay allocation-free and host-agnostic")


func _verify_launch_origins() -> void:
	var router: Object = _new_router()
	var companion_pos := Vector2(400.0, 600.0)
	var radius := 20.0
	for skill_id in ["maribo_hydro_sphere", "draft_bat_moon_orbit", "maribo_bubble_trap"]:
		_expect(router.get_launch_origin(skill_id, companion_pos, radius) == Vector2(400.0, 572.0), "%s should launch 8px above the companion radius" % skill_id)
	_expect(router.get_launch_origin("milkring_milk_shot", companion_pos, radius) == Vector2(400.0, 593.0), "Milk Shot should launch at the 0.35-radius muzzle offset")
	for skill_id in ["lumion_thunder_orb", "lumion_solar_bolt", "red_dragon_dragon_breath", "orbi_dwarf_magic"]:
		_expect(router.get_launch_origin(skill_id, companion_pos, radius) == Vector2(400.0, 570.0), "%s should launch 10px above the companion radius" % skill_id)
	for skill_id in ["lunabi_headbutt", "volty_bomb_surprise", "orbi_gravity_accel", "rahoset_sand_prison", "unsupported_skill", ""]:
		_expect(router.get_launch_origin(skill_id, companion_pos, radius) == companion_pos, "%s should launch from the companion center" % skill_id)
	_expect(router.get_launch_origin("maribo_hydro_sphere", companion_pos, -50.0) == Vector2(400.0, 592.0), "negative companion radius should clamp to zero before applying the 8px offset")


func _verify_position_override_policy() -> void:
	var router: Object = _new_router()
	var skill := FakeSkill.new()
	var fallback := Vector2(11.0, 22.0)
	for skill_kind in [
		"headbutt",
		"bomb_surprise",
		"gatling_burst",
		"puppet_grab",
		"doll_curse",
		"banana_slice",
		"wild_roar",
		"star_coil",
		"sand_prison",
	]:
		_expect(router.has_companion_position_override(skill_kind, skill), "%s should expose an active module override" % skill_kind)
		_expect(router.get_companion_position_override(skill_kind, skill, fallback) == skill.override_pos, "%s should forward the module override position" % skill_kind)
	for skill_kind in ["hydro_sphere", "gravity_accel", "none"]:
		_expect(not router.has_companion_position_override(skill_kind, skill), "%s should not own the companion position" % skill_kind)
		_expect(router.get_companion_position_override(skill_kind, skill, fallback) == fallback, "%s should preserve the position fallback" % skill_kind)
	_expect(not router.has_companion_position_override("headbutt", null), "missing focused module should not claim a position override")
	skill.override_active = false
	_expect(not router.has_companion_position_override("headbutt", skill), "inactive module should release its position override")
	_expect(router.get_companion_position_override("headbutt", skill, fallback) == fallback, "inactive module should return the caller fallback")


func _verify_body_presence_policy() -> void:
	var router: Object = _new_router()
	var skill := FakeSkill.new()
	for skill_kind in ["headbutt", "bomb_surprise", "gatling_burst"]:
		_expect(router.suppresses_companion_body_hit(skill_kind, skill), "%s should forward body-hit suppression" % skill_kind)
	_expect(not router.suppresses_companion_body_hit("puppet_grab", skill), "Puppet Grab position ownership should not suppress ordinary body hits")
	_expect(not router.suppresses_companion_body_hit("headbutt", null), "missing Headbutt module should fail open for body hits")
	_expect(router.suppresses_companion_body_draw("gatling_burst", skill), "Gatling Burst should replace the normal companion draw")
	_expect(not router.suppresses_companion_body_draw("bomb_surprise", skill), "Bomb Surprise should keep the normal companion draw policy")
	_expect(not router.suppresses_companion_body_draw("gatling_burst", null), "missing Gatling module should keep the normal companion draw")


func _verify_strike_request_policy() -> void:
	var router: Object = _new_router()
	var skill := FakeSkill.new()
	_expect(router.consume_companion_strike_request("headbutt", skill), "Headbutt should forward its one-shot strike request")
	_expect(not router.consume_companion_strike_request("headbutt", skill), "consumed Headbutt strike request should stay consumed")
	skill.strike_pending = true
	_expect(not router.consume_companion_strike_request("bomb_surprise", skill), "non-Headbutt skills should not consume a strike request")
	_expect(skill.strike_pending, "unsupported strike route should not mutate the module")


func _verify_cast_pose_and_windup_policy() -> void:
	var router: Object = _new_router()
	var skill := FakeSkill.new()
	for skill_kind in ["puppet_grab", "doll_curse", "banana_slice", "wild_roar", "sand_prison"]:
		_expect(is_equal_approx(float(router.get_companion_cast_pose_progress(skill_kind, skill)), 0.625), "%s should forward cast-pose progress" % skill_kind)
	_expect(is_equal_approx(float(router.get_companion_cast_pose_progress("headbutt", skill)), -1.0), "Headbutt should not request a cast-pose sheet")
	_expect(is_equal_approx(float(router.get_companion_cast_pose_progress("puppet_grab", null)), -1.0), "missing cast module should return the inactive sentinel")
	for skill_id in ["maribo_hydro_sphere", "orbi_gravity_accel", "rahoset_sand_prison"]:
		_expect(router.should_show_cast_windup(skill_id), "%s should retain the supported-runtime windup gate" % skill_id)
	_expect(not router.should_show_cast_windup("unsupported_skill"), "unsupported skill should not show a cast windup")
	_expect(not router.should_show_cast_windup(""), "empty skill id should not show a cast windup")


func _new_router() -> Object:
	var router_script: Script = load(OWNER_PATH)
	return router_script.new()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
