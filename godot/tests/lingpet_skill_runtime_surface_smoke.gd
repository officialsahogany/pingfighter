extends SceneTree

const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const LingpetSkillRuntimeSurface := preload("res://scripts/lingpet/lingpet_skill_runtime_surface.gd")

var _failures: Array[String] = []


class FakeHost:
	extends RefCounted

	var boss_context: Variant = {}
	var ball_context: Variant = {}
	var bind_state: Variant = {}
	var notify_result := true
	var hit_suppressed := false
	var draw_suppressed := false
	var strike_requested := false
	var boss_calls := 0
	var ball_calls := 0
	var bind_calls := 0
	var hit_suppress_calls := 0
	var draw_suppress_calls := 0
	var strike_request_calls := 0
	var notify_calls := 0
	var last_bind_skill_id := ""
	var last_hit_suppress_skill_id := ""
	var last_draw_suppress_skill_id := ""
	var last_strike_request_skill_id := ""
	var last_notify: Dictionary = {}

	func get_boss_ai_context() -> Variant:
		boss_calls += 1
		return boss_context

	func get_ball_collision_context() -> Variant:
		ball_calls += 1
		return ball_context

	func get_companion_bind_sheet_state(skill_id: String) -> Variant:
		bind_calls += 1
		last_bind_skill_id = skill_id
		return bind_state

	func suppresses_companion_body_hit(skill_id: String) -> bool:
		hit_suppress_calls += 1
		last_hit_suppress_skill_id = skill_id
		return hit_suppressed

	func suppresses_companion_body_draw(skill_id: String) -> bool:
		draw_suppress_calls += 1
		last_draw_suppress_skill_id = skill_id
		return draw_suppressed

	func consume_companion_strike_request(skill_id: String) -> bool:
		strike_request_calls += 1
		last_strike_request_skill_id = skill_id
		return strike_requested

	func notify_lingpet_bone_barrier_hit(
		barrier_id: int,
		impact_pos: Vector2,
		next_ball_vel: Vector2,
		built: bool,
		registry: Object
	) -> bool:
		notify_calls += 1
		last_notify = {
			"barrier_id": barrier_id,
			"impact_pos": impact_pos,
			"next_ball_vel": next_ball_vel,
			"built": built,
			"registry": registry,
		}
		return notify_result


class NoMethodHost:
	extends RefCounted


class FakeProfile:
	extends RefCounted

	var levels: Array = [3, 5]
	var level_calls := 0
	var last_level_slot_index := -1

	func get_active_skill_level_for_slot(slot_index: int = 0) -> int:
		level_calls += 1
		last_level_slot_index = slot_index
		if slot_index < 0 or slot_index >= levels.size():
			return 0
		return int(levels[slot_index])


class FakeActiveSkillSlotResolver:
	extends RefCounted

	var active_skill_ids: Array[String] = ["star_coil", "bubble_trap"]
	var active_skills: Array = [
		{"level": 2, "cooldown": 1.25},
		{"level": 4, "cooldown": 2.5},
	]
	var windup_seconds: Array = [0.35, 0.65]
	var active_id_calls := 0
	var last_profile: Object = null
	var last_host: Object = null

	func get_active_slot_count(_profile: Object, _skill_runtime_host: Object) -> int:
		return active_skill_ids.size()

	func get_active_skill_ids_for_runtime(profile: Object, skill_runtime_host: Object) -> Array[String]:
		active_id_calls += 1
		last_profile = profile
		last_host = skill_runtime_host
		return active_skill_ids

	func get_skill_id_for_slot(_profile: Object, slot_index: int) -> String:
		return str(active_skill_ids[maxi(0, mini(slot_index, active_skill_ids.size() - 1))])

	func get_active_skill_for_slot(_profile: Object, slot_index: int) -> Dictionary:
		return active_skills[maxi(0, mini(slot_index, active_skills.size() - 1))] as Dictionary

	func get_skill_windup_seconds_for_slot(_profile: Object, _default_windup_seconds: float, slot_index: int) -> float:
		return float(windup_seconds[maxi(0, mini(slot_index, windup_seconds.size() - 1))])


class FakeSkillPersistence:
	extends RefCounted

	func get_state_for_slot(skill_states: Array, slot_index: int) -> Object:
		if slot_index < 0 or slot_index >= skill_states.size():
			return null
		return skill_states[slot_index] as Object


class FakeVisualResolver:
	extends RefCounted

	var owner: Variant = {"has": true, "pos": Vector2(10.0, 20.0)}
	var active_owner_calls := 0
	var has_override_calls := 0
	var last_active_skill_ids: Array[String] = []
	var last_host: Object = null
	var last_pos := Vector2.ZERO

	func get_active_position_override_owner(
		active_skill_ids: Array[String],
		skill_runtime_host: Object,
		companion_pos: Vector2
	) -> Variant:
		active_owner_calls += 1
		last_active_skill_ids = active_skill_ids
		last_host = skill_runtime_host
		last_pos = companion_pos
		return owner

	func has_active_position_override(active_position_owner: Dictionary) -> bool:
		has_override_calls += 1
		return bool(active_position_owner.get("has", false))


func _init() -> void:
	_verify_context_gates_and_coercion()
	_verify_body_surface_guards()
	_verify_active_surface_for_slot()
	_verify_active_position_owner_surface()
	_verify_strike_request_surface_guard()
	_verify_notify_forwarding_and_guards()
	_verify_runtime_delegates_skill_runtime_surface()

	if _failures.is_empty():
		print("lingpet_skill_runtime_surface_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_context_gates_and_coercion() -> void:
	var surface := LingpetSkillRuntimeSurface.new()
	var host := FakeHost.new()
	host.boss_context = {"slip": true}
	host.ball_context = {"barrier": true}

	_expect(surface.get_boss_ai_context("egg", "companion", host).is_empty(), "inactive state should not query boss context")
	_expect_eq(host.boss_calls, 0, "inactive boss context should not call the host")
	_expect(surface.get_ball_collision_context("none", "companion", host).is_empty(), "inactive state should not query ball collision context")
	_expect_eq(host.ball_calls, 0, "inactive ball context should not call the host")

	_expect(surface.get_boss_ai_context("companion", "companion", null).is_empty(), "null host should return empty boss context")
	_expect(surface.get_ball_collision_context("companion", "companion", NoMethodHost.new()).is_empty(), "host without ball method should return empty context")

	var boss_context: Dictionary = surface.get_boss_ai_context("companion", "companion", host)
	var ball_context: Dictionary = surface.get_ball_collision_context("companion", "companion", host)
	_expect(bool(boss_context.get("slip", false)), "valid boss context should be forwarded")
	_expect(bool(ball_context.get("barrier", false)), "valid ball collision context should be forwarded")
	_expect_eq(host.boss_calls, 1, "active boss context should call the host once")
	_expect_eq(host.ball_calls, 1, "active ball context should call the host once")

	host.boss_context = "bad"
	host.ball_context = 12
	_expect(surface.get_boss_ai_context("companion", "companion", host).is_empty(), "non-dictionary boss context should coerce to empty")
	_expect(surface.get_ball_collision_context("companion", "companion", host).is_empty(), "non-dictionary ball context should coerce to empty")


func _verify_body_surface_guards() -> void:
	var surface := LingpetSkillRuntimeSurface.new()
	var host := FakeHost.new()
	host.bind_state = {"active": true}

	_expect(not surface.is_companion_body_drawn_in_front("egg", "companion", host, "star_coil"), "inactive state should not query bind sheet state")
	_expect_eq(host.bind_calls, 0, "inactive bind sheet state should not call the host")
	_expect(not surface.is_companion_body_drawn_in_front("companion", "companion", null, "star_coil"), "null host bind sheet state should return false")
	_expect(not surface.is_companion_body_drawn_in_front("companion", "companion", NoMethodHost.new(), "star_coil"), "host without bind sheet state should return false")
	_expect(surface.is_companion_body_drawn_in_front("companion", "companion", host, "star_coil"), "active bind sheet state should draw body in front")
	_expect_eq(host.bind_calls, 1, "active bind sheet state should call the host once")
	_expect_eq(host.last_bind_skill_id, "star_coil", "bind sheet state should receive skill id")

	host.bind_state = "bad"
	_expect(not surface.is_companion_body_drawn_in_front("companion", "companion", host, "star_coil"), "non-dictionary bind sheet state should return false")

	_expect(not surface.is_companion_body_hit_suppressed(null, "bone_barrier"), "null host hit suppression should return false")
	_expect(not surface.is_companion_body_hit_suppressed(NoMethodHost.new(), "bone_barrier"), "host without hit suppression should return false")
	_expect(not surface.is_companion_body_draw_suppressed(null, "star_coil"), "null host draw suppression should return false")
	_expect(not surface.is_companion_body_draw_suppressed(NoMethodHost.new(), "star_coil"), "host without draw suppression should return false")

	host.hit_suppressed = true
	host.draw_suppressed = true
	_expect(surface.is_companion_body_hit_suppressed(host, "bone_barrier"), "hit suppression should forward true host result")
	_expect(surface.is_companion_body_draw_suppressed(host, "star_coil"), "draw suppression should forward true host result")
	_expect_eq(host.hit_suppress_calls, 1, "hit suppression should call the host once")
	_expect_eq(host.draw_suppress_calls, 1, "draw suppression should call the host once")
	_expect_eq(host.last_hit_suppress_skill_id, "bone_barrier", "hit suppression should receive skill id")
	_expect_eq(host.last_draw_suppress_skill_id, "star_coil", "draw suppression should receive skill id")

	host.hit_suppressed = false
	host.draw_suppressed = false
	_expect(not surface.is_companion_body_hit_suppressed(host, "bone_barrier"), "hit suppression should preserve false host result")
	_expect(not surface.is_companion_body_draw_suppressed(host, "star_coil"), "draw suppression should preserve false host result")


func _verify_active_surface_for_slot() -> void:
	var surface := LingpetSkillRuntimeSurface.new()
	var profile := FakeProfile.new()
	var host := FakeHost.new()
	var slot_resolver := FakeActiveSkillSlotResolver.new()
	var persistence := FakeSkillPersistence.new()
	var skill_state_0 := RefCounted.new()
	var skill_state_1 := RefCounted.new()
	var skill_states := [skill_state_0, skill_state_1]

	_expect_eq(surface.get_active_slot_count(profile, slot_resolver, host), 2, "active slot count surface should forward the slot resolver count")
	_expect_eq(surface.get_active_slot_count(profile, null, host), 0, "null slot resolver should return zero active slots")
	_expect_eq(surface.get_active_slot_count(profile, NoMethodHost.new(), host), 0, "slot resolver without count method should return zero active slots")

	var slot_surface: Dictionary = surface.get_active_surface_for_slot(
		profile,
		slot_resolver,
		persistence,
		skill_states,
		host,
		0.25,
		1
	)
	_expect_eq(str(slot_surface.get("skill_id", "")), "bubble_trap", "active surface should include the slot skill id")
	_expect(slot_surface.get("active_skill", {}) == slot_resolver.active_skills[1], "active surface should include the slot active skill dictionary")
	_expect_eq(int(slot_surface.get("active_skill_level_fallback", -1)), 5, "active surface should include the profile active skill level fallback")
	_expect_eq(profile.level_calls, 1, "active surface should query the profile active skill level fallback once")
	_expect_eq(profile.last_level_slot_index, 1, "active surface should query the level fallback for the clamped slot")
	_expect(slot_surface.get("skill_state", null) == skill_state_1, "active surface should include the slot skill state")
	_expect(is_equal_approx(float(slot_surface.get("windup_seconds", -1.0)), 0.65), "active surface should include slot windup seconds")

	var empty_surface: Dictionary = surface.get_active_surface_for_slot(
		profile,
		slot_resolver,
		persistence,
		skill_states,
		host,
		0.25,
		99
	)
	_expect_eq(str(empty_surface.get("skill_id", "")), "", "out-of-range active surface should have no skill id")
	_expect((empty_surface.get("active_skill", {}) as Dictionary).is_empty(), "out-of-range active surface should have no active skill")
	_expect_eq(int(empty_surface.get("active_skill_level_fallback", -1)), 0, "out-of-range active surface should have no active skill level fallback")
	_expect(empty_surface.get("skill_state", null) == null, "out-of-range active surface should have no skill state")


func _verify_active_position_owner_surface() -> void:
	var surface := LingpetSkillRuntimeSurface.new()
	var profile := RefCounted.new()
	var host := FakeHost.new()
	var slot_resolver := FakeActiveSkillSlotResolver.new()
	var visual_resolver := FakeVisualResolver.new()
	var companion_pos := Vector2(33.0, 44.0)

	var active_ids: Array[String] = surface.get_active_skill_ids(profile, slot_resolver, host)
	_expect(active_ids == slot_resolver.active_skill_ids, "active skill id surface should forward resolver-built ids")
	_expect_eq(slot_resolver.active_id_calls, 1, "active skill id surface should resolve ids once")
	_expect(slot_resolver.last_profile == profile, "active skill id surface should forward profile")
	_expect(slot_resolver.last_host == host, "active skill id surface should forward host")
	_expect(surface.get_active_skill_ids(profile, null, host).is_empty(), "null slot resolver should return empty active skill ids")
	_expect(surface.get_active_skill_ids(profile, NoMethodHost.new(), host).is_empty(), "slot resolver without id method should return empty active skill ids")

	var owner: Dictionary = surface.get_active_position_owner(
		profile,
		slot_resolver,
		visual_resolver,
		host,
		companion_pos
	)
	_expect(bool(owner.get("has", false)), "active position owner should forward visual resolver result")
	_expect_eq(slot_resolver.active_id_calls, 2, "active position owner should resolve active skill ids once after the direct id surface check")
	_expect(slot_resolver.last_profile == profile, "active position owner should forward profile to slot resolver")
	_expect(slot_resolver.last_host == host, "active position owner should forward host to slot resolver")
	_expect_eq(visual_resolver.active_owner_calls, 1, "active position owner should call visual resolver once")
	_expect(visual_resolver.last_active_skill_ids == slot_resolver.active_skill_ids, "active position owner should pass active skill ids")
	_expect(visual_resolver.last_host == host, "active position owner should forward host to visual resolver")
	_expect(visual_resolver.last_pos == companion_pos, "active position owner should forward companion position")
	_expect(surface.has_active_position_override(visual_resolver, owner), "active position override predicate should forward true visual result")
	_expect_eq(visual_resolver.has_override_calls, 1, "active position override predicate should call visual resolver once")
	var owner_from_ids: Dictionary = surface.get_active_position_owner_for_ids(
		active_ids,
		visual_resolver,
		host,
		companion_pos
	)
	_expect(bool(owner_from_ids.get("has", false)), "prebuilt active ids should resolve the same active position owner")
	_expect_eq(slot_resolver.active_id_calls, 2, "prebuilt active ids should not re-query the slot resolver")
	_expect_eq(visual_resolver.active_owner_calls, 2, "prebuilt active ids should still query the visual resolver once")

	_expect(surface.get_active_position_owner(profile, null, visual_resolver, host, companion_pos).is_empty(), "null slot resolver should return empty active position owner")
	_expect(surface.get_active_position_owner(profile, slot_resolver, null, host, companion_pos).is_empty(), "null visual resolver should return empty active position owner")
	_expect(surface.get_active_position_owner(profile, slot_resolver, NoMethodHost.new(), host, companion_pos).is_empty(), "visual resolver without owner method should return empty active position owner")
	visual_resolver.owner = "bad"
	_expect(surface.get_active_position_owner(profile, slot_resolver, visual_resolver, host, companion_pos).is_empty(), "non-dictionary active position owner should coerce to empty")
	_expect(surface.has_active_position_override(null, {"has": true}), "null visual resolver predicate should fall back to dictionary has key")
	_expect(not surface.has_active_position_override(NoMethodHost.new(), {"has": false}), "resolver without predicate should fall back to dictionary has key")


func _verify_strike_request_surface_guard() -> void:
	var surface := LingpetSkillRuntimeSurface.new()
	_expect(not surface.consume_companion_strike_request(null, "lunabi_headbutt"), "null host strike request should return false")
	_expect(not surface.consume_companion_strike_request(NoMethodHost.new(), "lunabi_headbutt"), "host without strike request should return false")

	var host := FakeHost.new()
	host.strike_requested = true
	_expect(surface.consume_companion_strike_request(host, "lunabi_headbutt"), "strike request should forward true host result")
	_expect_eq(host.strike_request_calls, 1, "strike request should call the host once")
	_expect_eq(host.last_strike_request_skill_id, "lunabi_headbutt", "strike request should receive skill id")

	host.strike_requested = false
	_expect(not surface.consume_companion_strike_request(host, "lunabi_headbutt"), "strike request should preserve false host result")
	_expect_eq(host.strike_request_calls, 2, "strike request should call the host again for false result")


func _verify_notify_forwarding_and_guards() -> void:
	var surface := LingpetSkillRuntimeSurface.new()
	_expect(not surface.notify_lingpet_bone_barrier_hit(null, 1, Vector2.ZERO, Vector2.ZERO, true, null), "null host notify should return false")
	_expect(not surface.notify_lingpet_bone_barrier_hit(NoMethodHost.new(), 1, Vector2.ZERO, Vector2.ZERO, true, null), "host without notify method should return false")

	var host := FakeHost.new()
	var registry := RefCounted.new()
	var accepted: bool = surface.notify_lingpet_bone_barrier_hit(host, 7, Vector2(12.0, 34.0), Vector2(0.0, -8.0), false, registry)
	_expect(accepted, "notify should return the host result")
	_expect_eq(host.notify_calls, 1, "notify should call the host once")
	_expect_eq(int(host.last_notify.get("barrier_id", -1)), 7, "notify should forward barrier id")
	_expect(host.last_notify.get("impact_pos", Vector2.ZERO) == Vector2(12.0, 34.0), "notify should forward impact position")
	_expect(host.last_notify.get("next_ball_vel", Vector2.ZERO) == Vector2(0.0, -8.0), "notify should forward next ball velocity")
	_expect(not bool(host.last_notify.get("built", true)), "notify should forward built flag")
	_expect(host.last_notify.get("registry", null) == registry, "notify should forward registry")

	host.notify_result = false
	_expect(not surface.notify_lingpet_bone_barrier_hit(host, 8, Vector2.ZERO, Vector2.ZERO, true, registry), "notify should preserve false host result")


func _verify_runtime_delegates_skill_runtime_surface() -> void:
	var runtime := LingpetEggRuntime.new()
	_expect(runtime != null, "runtime fixture should construct")
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var surface_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_skill_runtime_surface.gd")
	_expect(runtime_source.find("LingpetSkillRuntimeSurface") >= 0, "egg runtime should preload the skill runtime surface")
	_expect(runtime_source.find("_skill_runtime_surface.get_boss_ai_context") >= 0, "runtime boss context API should delegate")
	_expect(runtime_source.find("_skill_runtime_surface.get_ball_collision_context") >= 0, "runtime ball collision API should delegate")
	_expect(runtime_source.find("_skill_runtime_surface.notify_lingpet_bone_barrier_hit") >= 0, "runtime bone-barrier notify API should delegate")
	_expect(runtime_source.find("_companion_body_presence_resolver.is_front_pass_body_active") >= 0, "runtime bind-sheet front pass should delegate through the body-presence resolver")
	_expect(runtime_source.find("_skill_runtime_surface.is_companion_body_hit_suppressed") >= 0, "runtime hit suppression should delegate")
	_expect(runtime_source.find("_skill_runtime_surface.is_companion_body_draw_suppressed") >= 0, "runtime draw suppression should delegate")
	_expect(runtime_source.find("_skill_runtime_surface.consume_companion_strike_request") >= 0, "runtime strike request should delegate")
	_expect(runtime_source.find("_skill_runtime_surface.get_active_slot_count") >= 0, "runtime active slot count should delegate")
	_expect(runtime_source.find("_skill_runtime_surface.get_active_skill_ids") >= 0, "runtime active skill id lists should delegate")
	_expect(runtime_source.find("_skill_runtime_surface.get_active_position_owner") >= 0, "runtime active position owner queries should delegate")
	_expect(runtime_source.find("_skill_runtime_surface.has_active_position_override") >= 0, "runtime active position override predicates should delegate")
	_expect(runtime_source.find("has_method(\"get_boss_ai_context\")") < 0, "runtime should not keep boss-context method guards inline")
	_expect(runtime_source.find("has_method(\"get_ball_collision_context\")") < 0, "runtime should not keep ball-context method guards inline")
	_expect(runtime_source.find("has_method(\"get_companion_bind_sheet_state\")") < 0, "runtime should not keep bind-sheet method guards inline")
	_expect(runtime_source.find("has_method(\"suppresses_companion_body_hit\")") < 0, "runtime should not keep hit-suppression method guards inline")
	_expect(runtime_source.find("has_method(\"suppresses_companion_body_draw\")") < 0, "runtime should not keep draw-suppression method guards inline")
	_expect(runtime_source.find("has_method(\"consume_companion_strike_request\")") < 0, "runtime should not keep strike-request method guards inline")
	_expect(runtime_source.find("_active_skill_slot_resolver.get_active_slot_count") < 0, "runtime should not build active slot count inline")
	_expect(runtime_source.find("_active_skill_slot_resolver.get_active_skill_ids_for_runtime") < 0, "runtime should not build active skill id lists inline")
	_expect(runtime_source.find("_active_skill_slot_resolver.get_skill_id_for_slot") < 0, "runtime should not build active skill ids inline")
	_expect(runtime_source.find("_active_skill_slot_resolver.get_active_skill_for_slot") < 0, "runtime should not build active skill dictionaries inline")
	_expect(runtime_source.find("_active_skill_slot_resolver.get_skill_windup_seconds_for_slot") < 0, "runtime should not build active skill windup seconds inline")
	_expect(runtime_source.find("_companion_skill_persistence.get_state_for_slot") < 0, "runtime should not build active skill state slots inline")
	_expect(runtime_source.find("_companion_skill_visual_resolver.get_active_position_override_owner") < 0, "runtime should not keep active-position owner visual resolver calls inline")
	_expect(runtime_source.find("_companion_skill_visual_resolver.has_active_position_override") < 0, "runtime should not keep active-position predicate visual resolver calls inline")
	_expect(surface_source.find("context is Dictionary") >= 0, "surface should own context Dictionary coercion")
	_expect(surface_source.find("func is_companion_body_drawn_in_front") >= 0, "surface should still expose the bind-sheet front-pass predicate")
	_expect(surface_source.find("has_method(\"get_companion_bind_sheet_state\")") >= 0, "surface should own bind-sheet method guard")
	_expect(surface_source.find("has_method(\"suppresses_companion_body_hit\")") >= 0, "surface should own hit-suppression method guard")
	_expect(surface_source.find("has_method(\"suppresses_companion_body_draw\")") >= 0, "surface should own draw-suppression method guard")
	_expect(surface_source.find("has_method(\"consume_companion_strike_request\")") >= 0, "surface should own strike-request method guard")
	_expect(surface_source.find("has_method(\"get_active_slot_count\")") >= 0, "surface should own active slot-count method guard")
	_expect(surface_source.find("has_method(\"get_active_skill_ids_for_runtime\")") >= 0, "surface should own active skill id method guard")
	_expect(surface_source.find("has_method(\"get_active_position_override_owner\")") >= 0, "surface should own active-position owner method guard")
	_expect(surface_source.find("has_method(\"has_active_position_override\")") >= 0, "surface should own active-position predicate method guard")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
