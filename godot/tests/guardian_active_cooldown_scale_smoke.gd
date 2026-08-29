extends SceneTree

const CharacterInfoOverlayLingpetCardSpecs := preload("res://scripts/hud/character_info_overlay_lingpet_card_specs.gd")
const LingpetActiveSkillSlotResolver := preload("res://scripts/lingpet/lingpet_active_skill_slot_resolver.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetCompanionSkillPersistence := preload("res://scripts/lingpet/lingpet_companion_skill_persistence.gd")
const LingpetCompanionSkillState := preload("res://scripts/lingpet/lingpet_companion_skill_state.gd")
const LingpetCurrentProfile := preload("res://scripts/lingpet/lingpet_current_profile.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const LingpetEnhancementBuffStore := preload("res://scripts/lingpet/lingpet_enhancement_buff_store.gd")
const LingpetOverflowChoiceState := preload("res://scripts/lingpet/lingpet_overflow_choice_state.gd")
const LingpetOverflowGuardianSnapshotBuilder := preload(
	"res://scripts/lingpet/lingpet_overflow_guardian_snapshot_builder.gd"
)
const LingpetRailCardSurfaceBuilder := preload("res://scripts/lingpet/lingpet_rail_card_surface_builder.gd")
const LingpetRailCard := preload("res://scripts/stages/common/lingpet_rail_card.gd")
const LingpetRuntimeSnapshotBuilder := preload("res://scripts/lingpet/lingpet_runtime_snapshot_builder.gd")
const LingpetSkillRuntimeSurface := preload("res://scripts/lingpet/lingpet_skill_runtime_surface.gd")


class EchoSkillState:
	extends RefCounted

	func get_snapshot(
		_active: bool,
		_skill_id: String,
		cooldown_duration: float,
		_windup_seconds: float,
		_flash_seconds: float,
		suffix: String = ""
	) -> Dictionary:
		return {
			"companion_skill_cooldown%s" % suffix: cooldown_duration,
			"companion_skill_cooldown_duration%s" % suffix: cooldown_duration,
			"companion_skill_ready%s" % suffix: false,
		}


class FakeLingpetRuntime:
	extends RefCounted

	var rail_surface: Dictionary

	func _init(value: Dictionary) -> void:
		rail_surface = value

	func is_companion_active() -> bool:
		return true

	func get_rail_card_surface() -> Dictionary:
		return rail_surface


class FakeRegistry:
	extends RefCounted

	var runtime: Object

	func _init(value: Object) -> void:
		runtime = value

	func get_cached_instance(key: String) -> Object:
		return runtime if key == "lingpet_egg_runtime" else null

	func get_instance(key: String) -> Object:
		return get_cached_instance(key)


class FakeLoadoutState:
	extends RefCounted

	var loadout: Dictionary

	func _init(value: Dictionary) -> void:
		loadout = value.duplicate(true)

	func get_stored_loadout(_pet_id: String) -> Dictionary:
		return loadout.duplicate(true)

	func get_loadout(_pet_id: String) -> Dictionary:
		return loadout.duplicate(true)


class NoAssetSkillRuntimeHost:
	extends RefCounted

	var launches: Array[Dictionary] = []

	func get_launch_origin(_skill_id: String, companion_pos: Vector2, companion_radius: float) -> Vector2:
		return companion_pos + Vector2(0.0, -companion_radius)

	func launch(skill_id: String, origin: Vector2, _owner: Object = null, launch_context: Dictionary = {}) -> bool:
		launches.append({
			"skill_id": skill_id,
			"origin": origin,
			"launch_context": launch_context.duplicate(true),
		})
		return true

	func trigger_launch_feedback(_skill_id: String, _registry: Object) -> void:
		pass


var _failures: Array[String] = []


func _init() -> void:
	_verify_two_guardians_and_level_models()
	_verify_floor_bases_and_zero_cooldown()
	_verify_maribo_runtime_launch_and_expiry_boundary()
	_verify_primary_and_second_consumer_parity()
	_verify_overflow_preview_profile_parity()
	if _failures.is_empty():
		print("guardian_active_cooldown_scale_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_two_guardians_and_level_models() -> void:
	var maribo_profile := LingpetCurrentProfile.new()
	maribo_profile.set_pet_id("maribo")
	maribo_profile.set_loadout("maribo_hydro_sphere", "", 1, 1)
	_expect_float(
		float(maribo_profile.get_active_skill().get("cooldown", 0.0)),
		32.0,
		"Maribo primary active should receive one global 0.8 scale"
	)

	var profile := _make_dual_volty_profile()
	var generic_raw := LingpetCatalog.get_active_skill("volty", "volty_gatling_burst", 5)
	var explicit_raw := LingpetCatalog.get_active_skill("volty", "volty_bomb_surprise", 4)
	_expect_float(float(generic_raw.get("cooldown", 0.0)), 44.0, "catalog preview should retain generic Lv.5 cooldown")
	_expect_float(float(explicit_raw.get("cooldown", 0.0)), 47.0, "catalog preview should retain explicit Lv.4 cooldown")
	_expect_float(
		float(profile.get_active_skill(0).get("cooldown", 0.0)),
		35.2,
		"generic primary should scale after its authored level reduction"
	)
	_expect_float(
		float(profile.get_active_skill(1).get("cooldown", 0.0)),
		37.6,
		"explicit cooldown_by_level second slot should scale the selected cooldown once"
	)


func _verify_floor_bases_and_zero_cooldown() -> void:
	var profile := LingpetCurrentProfile.new()
	var generic := {
		"id": "generic_floor_probe",
		"cooldown": 2.0,
		"base_cooldown": 100.0,
		"cooldown_by_level_authoritative": false,
	}
	var generic_floor_base := profile._get_active_skill_cooldown_floor_base(generic)
	profile._apply_guardian_active_cooldown_scale(generic, generic_floor_base)
	_expect_float(generic_floor_base, 100.0, "generic skill floor should use authored base_cooldown")
	_expect_float(float(generic.get("cooldown", 0.0)), 5.0, "generic final cooldown should respect five-percent authored floor")

	var explicit := {
		"id": "explicit_floor_probe",
		"cooldown": 2.0,
		"base_cooldown": 100.0,
		"cooldown_by_level_authoritative": true,
	}
	var explicit_floor_base := profile._get_active_skill_cooldown_floor_base(explicit)
	profile._apply_guardian_active_cooldown_scale(explicit, explicit_floor_base)
	_expect_float(explicit_floor_base, 2.0, "explicit skill floor should use its selected cooldown")
	_expect_float(float(explicit.get("cooldown", 0.0)), 1.6, "explicit selected cooldown should not inherit an unrelated authored floor")

	var permit_profile := LingpetCurrentProfile.new()
	permit_profile.set_pet_id("baekrin")
	permit_profile.set_loadout("baekrin_saddle", "", 5, 1)
	_expect_float(
		float(permit_profile.get_active_skill().get("cooldown", -1.0)),
		0.0,
		"zero-cooldown interaction permit should remain zero"
	)


func _verify_maribo_runtime_launch_and_expiry_boundary() -> void:
	var runtime: Object = LingpetEggRuntime.new()
	runtime._current_profile.set_pet_id("maribo")
	runtime._current_profile.set_loadout("maribo_hydro_sphere", "", 1, 1)
	var no_asset_host := NoAssetSkillRuntimeHost.new()
	runtime._skill_runtime_host = no_asset_host
	runtime._companion_skill_controller.configure(
		runtime._current_profile,
		runtime._active_skill_slot_resolver,
		runtime._companion_skill_visual_resolver,
		runtime._companion_skill_persistence,
		runtime._companion_skill_states,
		no_asset_host,
		runtime._skill_runtime_surface,
		LingpetEggRuntime.COMPANION_SKILL_WINDUP_SECONDS,
		LingpetEggRuntime.COMPANION_RADIUS
	)
	runtime._companion_pos = Vector2(380.0, 650.0)
	runtime.launch_companion_skill_from_controller(null, null, 0)

	_expect(no_asset_host.launches.size() == 1, "LingpetEggRuntime should dispatch one Maribo production launch")
	if no_asset_host.launches.size() == 1:
		var launch: Dictionary = no_asset_host.launches[0]
		_expect(str(launch.get("skill_id", "")) == "maribo_hydro_sphere", "runtime launch should route Maribo Hydro Sphere")
		_expect(
			int((launch.get("launch_context", {}) as Dictionary).get("active_skill_level", 0)) == 1,
			"runtime launch should preserve the selected profile level"
		)
	var skill_state: Object = runtime._companion_skill_states[0]
	_expect_float(float(skill_state.cooldown), 32.0, "actual Maribo runtime launch should arm the profile-resolved 32-second cooldown")
	_expect(not bool(skill_state.can_arm()), "Maribo runtime should remain blocked immediately after launch")

	# LingpetEggRuntime.update delegates every summoned-frame cooldown tick to this
	# exact persistence owner. Keep the host asset-free while exercising both sides
	# of the production expiration boundary.
	runtime._companion_skill_persistence.advance_states(31.999, runtime._companion_skill_states, true)
	_expect(float(skill_state.cooldown) > 0.0, "Maribo runtime cooldown should remain armed just before 32 seconds")
	_expect(not bool(skill_state.can_arm()), "Maribo runtime should not re-arm before the resolved cooldown expires")
	runtime._companion_skill_persistence.advance_states(0.002, runtime._companion_skill_states, true)
	_expect_float(float(skill_state.cooldown), 0.0, "Maribo runtime cooldown should clamp to zero after the 32-second boundary")
	_expect(bool(skill_state.can_arm()), "Maribo runtime should re-arm only after the resolved cooldown expires")


func _verify_primary_and_second_consumer_parity() -> void:
	var profile := _make_dual_volty_profile()
	var primary: Dictionary = profile.get_active_skill(0)
	var second: Dictionary = profile.get_active_skill(1)
	var primary_cooldown := float(primary.get("cooldown", 0.0))
	var second_cooldown := float(second.get("cooldown", 0.0))

	var snapshot_builder := LingpetRuntimeSnapshotBuilder.new()
	var runtime_snapshot := snapshot_builder.build_runtime_snapshot(
		"volty",
		LingpetRuntimeSnapshotBuilder.STATE_COMPANION,
		true,
		1,
		Vector2.ZERO,
		94.0,
		48.0,
		primary,
		0.0,
		["volty"],
		["volty"],
		0,
		0.0,
		null,
		null,
		162.0,
		108.0,
		216.0,
		0.16,
		null,
		40.0,
		EchoSkillState.new(),
		float(primary.get("windup_seconds", 0.0)),
		0.2,
		null,
		second,
		EchoSkillState.new(),
		float(second.get("windup_seconds", 0.0))
	)
	_expect_float(
		float(runtime_snapshot.get("companion_skill_cooldown_duration", 0.0)),
		primary_cooldown,
		"primary runtime snapshot cooldown should equal the profile"
	)
	_expect_float(
		float(runtime_snapshot.get("companion_skill_cooldown_duration_1", 0.0)),
		second_cooldown,
		"second runtime snapshot cooldown should equal the profile"
	)

	var display_snapshot := snapshot_builder.build_character_info_display_snapshot(
		"volty",
		LingpetRuntimeSnapshotBuilder.STATE_COMPANION,
		94.0,
		48.0,
		primary,
		second,
		[],
		0.0,
		162.0,
		108.0,
		216.0,
		0.16,
		40.0,
		0.0,
		""
	)
	_expect_float(
		float(display_snapshot.get("companion_skill_cooldown_duration", 0.0)),
		primary_cooldown,
		"primary character-info snapshot cooldown should equal the profile"
	)
	_expect_float(
		float(display_snapshot.get("companion_skill_cooldown_duration_1", 0.0)),
		second_cooldown,
		"second character-info snapshot cooldown should equal the profile"
	)

	var card_specs := CharacterInfoOverlayLingpetCardSpecs.get_skill_specs(display_snapshot, Color.WHITE)
	_expect(card_specs.size() >= 2, "character-info tooltip projection should include both active slots")
	if card_specs.size() >= 2:
		_expect(
			str((card_specs[0] as Dictionary).get("subtitle", "")).find(str(primary_cooldown)) >= 0,
			"primary character-info tooltip should format the profile cooldown"
		)
		_expect(
			str((card_specs[1] as Dictionary).get("subtitle", "")).find(str(second_cooldown)) >= 0,
			"second character-info tooltip should format the profile cooldown"
		)

	var rail_builder := LingpetRailCardSurfaceBuilder.new()
	var active_skill_slot_resolver := LingpetActiveSkillSlotResolver.new()
	var skill_runtime_surface := LingpetSkillRuntimeSurface.new()
	var companion_skill_persistence := LingpetCompanionSkillPersistence.new()
	var companion_skill_states: Array = [
		LingpetCompanionSkillState.new(),
		LingpetCompanionSkillState.new(),
	]
	_expect(
		active_skill_slot_resolver.get_active_slot_count(profile, null) == 2,
		"production resolver should expose slot 1 only after second_active_unlocked"
	)
	var rail_surface := rail_builder.get_surface(
		"companion",
		true,
		profile,
		null,
		active_skill_slot_resolver,
		companion_skill_persistence,
		companion_skill_states,
		null,
		skill_runtime_surface,
		1.0,
		0.2
	)
	_expect_float(
		float(rail_surface.get("companion_skill_cooldown_duration", 0.0)),
		primary_cooldown,
		"primary rail surface cooldown should equal the profile"
	)
	_expect_float(
		float(rail_surface.get("companion_skill_cooldown_duration_1", 0.0)),
		second_cooldown,
		"second rail surface cooldown should equal the profile"
	)

	var registry := FakeRegistry.new(FakeLingpetRuntime.new(rail_surface))
	var rail_entries := LingpetRailCard.build_entries(registry)
	_expect(rail_entries.size() == 2, "rail projection should include primary and second active cards")
	if rail_entries.size() == 2:
		var primary_entry := rail_entries[0] as Dictionary
		var second_entry := rail_entries[1] as Dictionary
		_expect_float(float(primary_entry.get("cooldown_total", 0.0)), primary_cooldown, "primary rail card should use the profile cooldown")
		_expect_float(float(second_entry.get("cooldown_total", 0.0)), second_cooldown, "second rail card should use the profile cooldown")
		_expect_float(
			float(LingpetRailCard.tooltip_info(primary_entry).get("cooldown_seconds", 0.0)),
			primary_cooldown,
			"primary rail tooltip should use the profile cooldown"
		)
		_expect_float(
			float(LingpetRailCard.tooltip_info(second_entry).get("cooldown_seconds", 0.0)),
			second_cooldown,
			"second rail tooltip should use the profile cooldown"
		)


func _verify_overflow_preview_profile_parity() -> void:
	var profile := _make_dual_volty_profile()
	var loadout := {
		"active_skill_id": "volty_gatling_burst",
		"active_skill_level": 5,
		"active_skill_ids": ["volty_gatling_burst", "volty_bomb_surprise"],
		"active_skill_levels": {
			"volty_gatling_burst": 5,
			"volty_bomb_surprise": 4,
		},
		"active_slot_count": 2,
		"passive_skill_id": "",
		"passive_skill_level": 0,
		"passive_skill_ids": [],
		"passive_skill_levels": {},
		"passive_slot_count": 0,
	}
	var builder := LingpetOverflowGuardianSnapshotBuilder.new()
	var replacement: Dictionary = builder.build_replacement(
		"volty",
		FakeLoadoutState.new(loadout)
	)
	var replacement_actives: Array = replacement.get("active_skills", []) as Array
	_expect(replacement_actives.size() == 2, "overflow replacement preview should preserve primary and second active slots")
	if replacement_actives.size() == 2:
		_expect_float(
			float((replacement_actives[0] as Dictionary).get("cooldown", 0.0)),
			float(profile.get_active_skill(0).get("cooldown", 0.0)),
			"overflow replacement primary cooldown should equal the final profile value"
		)
		_expect_float(
			float((replacement_actives[1] as Dictionary).get("cooldown", 0.0)),
			float(profile.get_active_skill(1).get("cooldown", 0.0)),
			"overflow replacement second cooldown should equal the final profile value"
		)
	_expect_float(
		float(replacement.get("active_skill_cooldown", 0.0)),
		float(profile.get_active_skill(0).get("cooldown", 0.0)),
		"overflow replacement primary summary should equal its resolved slot"
	)

	var choice := LingpetOverflowChoiceState.new()
	choice.begin_main_overflow("rahoset")
	var direct_snapshot: Dictionary = choice.build_snapshot(null)
	var direct_profile := LingpetCurrentProfile.new()
	direct_profile.set_pet_id("rahoset")
	var direct_loadout := LingpetCatalog.build_default_loadout("rahoset")
	direct_profile.set_loadout(
		str(direct_loadout.get("active_skill_id", "")),
		"",
		int(direct_loadout.get("active_skill_level", 1)),
		0
	)
	_expect_float(
		float(direct_profile.get_active_skill(0).get("cooldown", 0.0)),
		24.0,
		"Rahoset default overflow profile should apply the global scale once"
	)
	_expect_float(
		float(direct_snapshot.get("replacement_skill_cooldown", 0.0)),
		float(direct_profile.get_active_skill(0).get("cooldown", 0.0)),
		"direct overflow choice preview should publish the final profile cooldown"
	)


func _make_dual_volty_profile() -> Object:
	var profile := LingpetCurrentProfile.new()
	profile.set_pet_id("volty")
	profile.set_loadout(
		"volty_gatling_burst",
		"",
		5,
		1,
		["volty_gatling_burst", "volty_bomb_surprise"],
		{
			"volty_gatling_burst": 5,
			"volty_bomb_surprise": 4,
		},
		2
	)
	var rewards := LingpetEnhancementBuffStore.get_empty_reward_counts()
	rewards["second_active_unlocked"] = true
	profile.set_enhancement_rewards(LingpetEnhancementBuffStore.normalize_reward_counts(rewards))
	return profile


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_float(actual: float, expected: float, message: String, tolerance: float = 0.001) -> void:
	if absf(actual - expected) > tolerance:
		_failures.append("%s (expected=%.3f actual=%.3f)" % [message, expected, actual])
