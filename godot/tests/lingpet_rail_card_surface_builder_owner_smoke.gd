extends SceneTree

const LingpetRailCardSurfaceBuilder := preload("res://scripts/lingpet/lingpet_rail_card_surface_builder.gd")


class FakeProfile:
	func is_interaction_permit_for_slot(slot_index: int) -> bool:
		return slot_index == 0


class FakeMountState:
	var mounted := false

	func is_mounted() -> bool:
		return mounted


class FakeSkillState:
	func get_snapshot(
		_active: bool,
		_skill_id: String,
		_cooldown_duration: float,
		_windup_seconds: float,
		_flash_seconds: float,
		suffix: String
	) -> Dictionary:
		return {
			"companion_skill_cooldown%s" % suffix: 3.0,
			"companion_skill_ready%s" % suffix: false,
		}


class FakeRuntimeSurface:
	var primary_state := FakeSkillState.new()
	var second_state := FakeSkillState.new()

	func get_active_slot_count(_profile: Object, _resolver: Object, _host: Object) -> int:
		return 2

	func get_active_surface_for_slot(
		_profile: Object,
		_resolver: Object,
		_persistence: Object,
		_states: Array,
		_host: Object,
		_default_windup_seconds: float,
		slot_index: int,
		_active_slot_count: int = -1
	) -> Dictionary:
		if slot_index == 0:
			return {
				"skill_id": "baekrin_saddle",
				"active_skill": {
					"id": "baekrin_saddle",
					"name": "백린의안장",
					"description": "토글",
					"cooldown": 0.0,
					"card_texture_path": "res://permit.png",
					"enabled": true,
				},
				"skill_state": primary_state,
				"windup_seconds": 0.0,
			}
		return {
			"skill_id": "second_launch",
			"active_skill": {
				"id": "second_launch",
				"name": "두 번째 기술",
				"description": "자동 발동",
				"cooldown": 20.0,
				"card_texture_path": "res://second.png",
				"enabled": true,
			},
			"skill_state": second_state,
			"windup_seconds": 0.5,
		}

	func get_second_active_surface(
		profile: Object,
		resolver: Object,
		persistence: Object,
		states: Array,
		host: Object,
		default_windup_seconds: float,
		active_slot_count: int = -1
	) -> Dictionary:
		return get_active_surface_for_slot(
			profile,
			resolver,
			persistence,
			states,
			host,
			default_windup_seconds,
			1,
			active_slot_count
		)


class FakeSkillRuntimeHost:
	var requested_ids: Array[String] = []

	func get_snapshot_for_skill_id(skill_id: String) -> Dictionary:
		requested_ids.append(skill_id)
		return {"runtime_%s" % skill_id: true}


var _failures: Array[String] = []


func _init() -> void:
	_verify_builder_behavior()
	_verify_runtime_facade_ownership()
	if _failures.is_empty():
		print("lingpet_rail_card_surface_builder_owner_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_builder_behavior() -> void:
	var builder := LingpetRailCardSurfaceBuilder.new()
	var profile := FakeProfile.new()
	var mount_state := FakeMountState.new()
	var runtime_surface := FakeRuntimeSurface.new()
	var host := FakeSkillRuntimeHost.new()
	var surface: Dictionary = builder.get_surface(
		"companion",
		true,
		profile,
		mount_state,
		null,
		null,
		[],
		host,
		runtime_surface,
		1.0,
		0.2
	)
	_expect(str(surface.get("companion_skill_id", "")) == "baekrin_saddle", "primary rail card should preserve the equipped skill")
	_expect(str(surface.get("companion_skill_activation_model", "")) == "interaction_permit", "permit slot should publish its interaction model")
	_expect(bool(surface.get("companion_skill_interaction_available", false)), "equipped permit should be available")
	_expect(not bool(surface.get("companion_skill_interaction_active", true)), "unmounted permit should not be active")
	_expect(str(surface.get("companion_skill_activation_model_1", "")) == "launch", "second launch slot should keep the default model")
	_expect(bool(surface.get("runtime_baekrin_saddle", false)), "primary skill runtime snapshot should be merged")
	_expect(bool(surface.get("runtime_second_launch", false)), "second skill runtime snapshot should be merged")
	_expect(builder.get_surface_build_count_for_tests() == 1, "first rail query should build once")
	var static_builds := builder.get_static_surface_build_count_for_tests()
	builder.get_surface("companion", true, profile, mount_state, null, null, [], host, runtime_surface, 1.0, 0.2)
	_expect(builder.get_surface_build_count_for_tests() == 1, "same-frame rail query should reuse the frame cache")
	_expect(builder.get_static_surface_build_count_for_tests() == static_builds, "same-frame rail query should reuse the static surface")

	mount_state.mounted = true
	builder.invalidate_frame_cache()
	var mounted_surface: Dictionary = builder.get_surface(
		"companion",
		true,
		profile,
		mount_state,
		null,
		null,
		[],
		host,
		runtime_surface,
		1.0,
		0.2
	)
	_expect(bool(mounted_surface.get("companion_skill_interaction_active", false)), "mounted permit should become active after invalidation")
	_expect(builder.get_static_surface_build_count_for_tests() > static_builds, "permit state must participate in static cache identity")


func _verify_runtime_facade_ownership() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var builder_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_rail_card_surface_builder.gd")
	_expect(source.find("LingpetRailCardSurfaceBuilder") >= 0, "egg runtime should preload the rail-card surface builder")
	_expect(source.find("_rail_card_surface_builder.get_surface(") >= 0, "public rail surface should delegate to its owner")
	_expect(source.find("_rail_card_surface_builder.build_interaction_permit_projection(") >= 0, "runtime snapshot should reuse the rail owner's permit projection")
	_expect(source.find("_rail_card_surface_builder.invalidate_frame_cache()") >= 0, "runtime invalidation should clear the narrow rail cache")
	_expect(builder_source.find("func _merge_skill_runtime_snapshot") >= 0, "rail owner should retain narrow per-skill runtime merging")
	for retired_field in [
		"_rail_card_surface_cache",
		"_rail_card_surface_cache_valid",
		"_rail_card_surface_cache_process_frame",
		"_rail_card_surface_cache_physics_frame",
		"_rail_card_surface_build_count_for_tests",
		"_rail_card_static_surface_cache",
		"_rail_card_static_surface_key",
		"_rail_card_static_surface_build_count_for_tests",
	]:
		_expect(source.find("var %s" % retired_field) == -1, "egg runtime should not retain rail-card cache state: %s" % retired_field)
	for retired_function in [
		"func _build_rail_card_surface_uncached",
		"func _build_interaction_permit_projection",
		"func _get_rail_card_static_surface",
		"func _merge_rail_card_slot_static",
		"func _merge_rail_card_slot_dynamic",
		"func _merge_rail_card_skill_runtime_snapshot",
		"func _empty_rail_card_skill_state_snapshot",
	]:
		_expect(source.find(retired_function) == -1, "egg runtime should not retain rail-card projection logic: %s" % retired_function)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
