extends SceneTree

const LingpetGuardianRunState := preload("res://scripts/lingpet/lingpet_guardian_run_state.gd")
const LingpetCurrentProfile := preload("res://scripts/lingpet/lingpet_current_profile.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const LingpetProfileRuntimeSurface := preload("res://scripts/lingpet/lingpet_profile_runtime_surface.gd")

var _failures: Array[String] = []


class FakeProfile:
	extends RefCounted

	var required_hits_calls := 0
	var stat_calls: Array[String] = []

	func get_required_hits(fallback: int) -> int:
		required_hits_calls += 1
		return fallback + 2

	func get_stat(stat_key: String, fallback: float) -> float:
		stat_calls.append(stat_key)
		match stat_key:
			"catch_width":
				return 123.0
			"catch_height":
				return 45.0
			_:
				return fallback

	func get_hit_gauge_gain(fallback: float) -> float:
		return fallback + 7.0

	func get_gauge_gain_bonus_pct(_fallback: float) -> float:
		return 25.0

	func get_player_speed_bonus_pct(_fallback: float) -> float:
		return 15.0

	func get_passive_skill() -> Dictionary:
		return {"id": "maribo_resonance_boost", "level": 2}

	func get_motion_style() -> String:
		return "free_flight"

	func get_active_skill_pool() -> Array[Dictionary]:
		return [{"id": "maribo_hydro_sphere"}, {"id": "maribo_bubble_trap"}]

	func get_passive_skill_pool() -> Array[Dictionary]:
		return [{"id": "maribo_resonance_boost"}]


class NoMethodProfile:
	extends RefCounted


class ProjectionProfile:
	extends RefCounted

	func get_gauge_gain_bonus_pct(_fallback: float) -> float:
		return 25.0

	func get_player_speed_bonus_pct(_fallback: float) -> float:
		return 15.0

	func get_passive_skills() -> Array[Dictionary]:
		return [
			{
				"id": "speed_and_gauge_a",
				"name": "첫 번째 수호령 버프",
				"player_speed_bonus_pct": 10.0,
				"gauge_gain_bonus_pct": 10.0,
			},
			{
				"id": "speed_and_gauge_b",
				"name": "두 번째 수호령 버프",
				"player_speed_bonus_pct": 5.0,
				"gauge_gain_bonus_pct": 5.0,
			},
		]


func _init() -> void:
	_verify_profile_runtime_surface_forwards_profile_values()
	_verify_profile_runtime_surface_fallbacks()
	_verify_real_profile_second_passive_surface_and_effect_level()
	_verify_runtime_surface_cache_reuses_stable_profile()
	_verify_derived_player_stat_projection()
	_verify_runtime_derived_stat_facades()

	if _failures.is_empty():
		print("lingpet_profile_runtime_surface_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_profile_runtime_surface_forwards_profile_values() -> void:
	var surface := LingpetProfileRuntimeSurface.new()
	var profile := FakeProfile.new()
	var runtime_surface: Dictionary = surface.build_runtime_surface(profile, 1, 100.0, 44.0, 40.0)

	_expect_eq(int(runtime_surface.get("required_hits", 0)), 3, "runtime surface should forward required-hit lookup")
	_expect_eq(profile.required_hits_calls, 1, "runtime surface should query required hits once")
	_expect_float(float(runtime_surface.get("catch_width", 0.0)), 123.0, "runtime surface should forward catch-width lookup")
	_expect_float(float(runtime_surface.get("catch_height", 0.0)), 45.0, "runtime surface should forward catch-height lookup")
	_expect_float(float(runtime_surface.get("hit_gauge_gain", 0.0)), 47.0, "runtime surface should forward hit-gauge lookup")
	_expect_float(float(runtime_surface.get("gauge_gain_bonus_pct", 0.0)), 25.0, "runtime surface should forward gauge bonus lookup")
	_expect_eq(str((runtime_surface.get("passive_skill", {}) as Dictionary).get("id", "")), "maribo_resonance_boost", "runtime surface should forward passive skill lookup")
	_expect_float(surface.get_player_speed_bonus_pct(profile), 15.0, "surface should forward player-speed bonus lookup")
	_expect_eq(surface.get_motion_style(profile), "free_flight", "surface should forward motion style lookup")
	_expect_eq(surface.get_active_skill_pool(profile).size(), 2, "surface should forward active skill pool lookup")
	_expect_eq(surface.get_passive_skill_pool(profile).size(), 1, "surface should forward passive skill pool lookup")


func _verify_profile_runtime_surface_fallbacks() -> void:
	var surface := LingpetProfileRuntimeSurface.new()
	var no_method_profile := NoMethodProfile.new()
	var runtime_surface: Dictionary = surface.build_runtime_surface(no_method_profile, 1, 100.0, 44.0, 40.0)

	_expect_eq(int(runtime_surface.get("required_hits", 0)), 1, "surface should keep required-hit fallback for profiles without methods")
	_expect_float(float(runtime_surface.get("catch_width", 0.0)), 100.0, "surface should keep catch-width fallback for profiles without methods")
	_expect_float(float(runtime_surface.get("catch_height", 0.0)), 44.0, "surface should keep catch-height fallback for profiles without methods")
	_expect_float(float(runtime_surface.get("hit_gauge_gain", 0.0)), 40.0, "surface should keep hit-gauge fallback for profiles without methods")
	_expect_float(float(runtime_surface.get("gauge_gain_bonus_pct", -1.0)), 0.0, "surface should keep gauge-bonus fallback for profiles without methods")
	_expect((runtime_surface.get("passive_skill", {}) as Dictionary).is_empty(), "surface should keep passive fallback empty for profiles without methods")
	_expect_float(surface.get_player_speed_bonus_pct(no_method_profile), 0.0, "surface should keep player-speed fallback for profiles without methods")
	_expect_eq(surface.get_motion_style(no_method_profile, "patrol"), "patrol", "surface should keep motion-style fallback for profiles without methods")
	_expect(surface.get_active_skill_pool(no_method_profile).is_empty(), "surface should keep active skill pool fallback empty")
	_expect(surface.get_passive_skill_pool(no_method_profile).is_empty(), "surface should keep passive skill pool fallback empty")


func _verify_real_profile_second_passive_surface_and_effect_level() -> void:
	var surface := LingpetProfileRuntimeSurface.new()
	var profile := LingpetCurrentProfile.new()
	profile.set_pet_id("maribo")
	profile.set_loadout(
		"maribo_hydro_sphere",
		"lingpet_resonance_boost",
		1,
		2,
		["maribo_hydro_sphere"],
		{"maribo_hydro_sphere": 1},
		1,
		["lingpet_resonance_boost", "lingpet_afterglow_leak"],
		{
			"lingpet_resonance_boost": 2,
			"lingpet_afterglow_leak": 3,
		},
		2
	)
	var rewards := LingpetGuardianRunState.get_empty_reward_counts()
	rewards["passive_skill_bonus"] = 1
	rewards["second_passive_skill_bonus"] = 2
	rewards["signature"] = "passive-slot-surface"
	profile.set_enhancement_rewards(rewards)

	var primary := surface.get_passive_skill(profile)
	var second := surface.get_passive_skill(profile, 1)
	var by_id := surface.get_passive_skill_by_id(profile, "lingpet_afterglow_leak")
	var passive_skills := surface.get_passive_skills(profile)
	_expect_eq(str(primary.get("id", "")), "lingpet_resonance_boost", "primary passive should still resolve through the default surface")
	_expect_eq(int(primary.get("level", 0)), 3, "primary passive should use passive_skill_bonus")
	_expect_eq(str(second.get("id", "")), "lingpet_afterglow_leak", "slot-1 passive should resolve by slot")
	_expect_eq(int(second.get("level", 0)), 5, "slot-1 passive should use second_passive_skill_bonus")
	_expect_float(float(second.get("afterglow_total_gauge", 0.0)), 100.0, "slot-1 passive flattened values should use the effective Lv.5")
	_expect_eq(str(by_id.get("id", "")), "lingpet_afterglow_leak", "surface should find a passive by id even when it is in slot 1")
	_expect_eq(passive_skills.size(), 2, "surface should expose both passive slots")

	var second_effect_profile := LingpetCurrentProfile.new()
	second_effect_profile.set_pet_id("maribo")
	second_effect_profile.set_loadout(
		"maribo_hydro_sphere",
		"lingpet_afterglow_leak",
		1,
		1,
		["maribo_hydro_sphere"],
		{"maribo_hydro_sphere": 1},
		1,
		["lingpet_afterglow_leak", "lingpet_resonance_boost"],
		{
			"lingpet_afterglow_leak": 1,
			"lingpet_resonance_boost": 2,
		},
		2
	)
	var second_effect_rewards := LingpetGuardianRunState.get_empty_reward_counts()
	second_effect_rewards["second_passive_skill_bonus"] = 2
	second_effect_rewards["signature"] = "second-passive-effect"
	second_effect_profile.set_enhancement_rewards(second_effect_rewards)
	_expect_float(
		second_effect_profile.get_gauge_gain_bonus_pct(0.0),
		13.0,
		"second passive effects should contribute to profile stat helpers"
	)


func _verify_runtime_surface_cache_reuses_stable_profile() -> void:
	var surface := LingpetProfileRuntimeSurface.new()
	var profile := LingpetCurrentProfile.new()
	profile.set_pet_id("maribo")
	profile.set_loadout("maribo_hydro_sphere", "lingpet_resonance_boost", 1, 1)
	surface.reset_runtime_surface_build_count_for_tests()

	var first_surface: Dictionary = surface.build_runtime_surface(profile, 1, 100.0, 44.0, 40.0)
	var second_surface: Dictionary = surface.build_runtime_surface(profile, 1, 100.0, 44.0, 40.0)
	_expect(first_surface == second_surface, "stable profile runtime surface should be reusable")
	_expect_eq(surface.get_runtime_surface_build_count_for_tests(), 1, "stable profile runtime surface should build once")

	profile.set_loadout("maribo_hydro_sphere", "lingpet_resonance_boost", 1, 2)
	surface.build_runtime_surface(profile, 1, 100.0, 44.0, 40.0)
	_expect_eq(surface.get_runtime_surface_build_count_for_tests(), 2, "profile metadata changes should invalidate the runtime surface cache")


func _verify_derived_player_stat_projection() -> void:
	var surface := LingpetProfileRuntimeSurface.new()
	var profile := ProjectionProfile.new()
	_expect_float(
		surface.apply_gauge_gain_per_hit(profile, true, 50.0),
		62.0,
		"active guardian gauge projection should floor the profile-wide bonus"
	)
	_expect_float(
		surface.apply_gauge_gain_per_hit(profile, false, 50.0),
		50.0,
		"inactive guardian should not change gauge gain"
	)
	_expect_float(
		surface.get_player_speed_multiplier(profile, true),
		1.15,
		"active guardian speed projection should expose the profile-wide multiplier"
	)
	_expect_float(
		surface.get_player_speed_multiplier(profile, false),
		1.0,
		"inactive guardian should not change player speed"
	)
	var speed_entries: Array = surface.build_player_stat_breakdown(
		profile,
		true,
		"player_speed"
	)
	_expect_eq(speed_entries.size(), 2, "speed breakdown should retain both contributing passives")
	_expect_float(float((speed_entries[0] as Dictionary).get("before", 0.0)), 1.0, "speed breakdown should start at the neutral multiplier")
	_expect_float(float((speed_entries[0] as Dictionary).get("after", 0.0)), 1.1, "first speed row should add ten percent")
	_expect_float(float((speed_entries[1] as Dictionary).get("after", 0.0)), 1.15, "second speed row should use the cumulative fifteen percent")
	var gauge_entries: Array = surface.build_player_stat_breakdown(
		profile,
		true,
		"gauge_gain",
		50.0
	)
	_expect_eq(gauge_entries.size(), 2, "gauge breakdown should retain both contributing passives")
	_expect_float(float((gauge_entries[0] as Dictionary).get("after", 0.0)), 55.0, "first gauge row should floor from the original base")
	_expect_float(float((gauge_entries[1] as Dictionary).get("after", 0.0)), 57.0, "second gauge row should keep cumulative floor semantics")
	_expect(
		surface.build_player_stat_breakdown(profile, false, "player_speed").is_empty(),
		"inactive guardian breakdown should stay empty"
	)
	_expect(
		surface.build_player_stat_breakdown(profile, true, "unsupported").is_empty(),
		"unsupported stat breakdown should stay empty"
	)


func _verify_runtime_derived_stat_facades() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var surface_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_profile_runtime_surface.gd")
	_expect(runtime_source.find("_profile_runtime_surface.apply_gauge_gain_per_hit(") >= 0, "gauge facade should delegate derived math")
	_expect(runtime_source.find("_profile_runtime_surface.get_player_speed_multiplier(") >= 0, "speed facade should delegate derived math")
	_expect(runtime_source.find("_profile_runtime_surface.build_player_stat_breakdown(") >= 0, "stat-breakdown facade should delegate projection")
	_expect(runtime_source.find("for passive: Dictionary in _profile_runtime_surface.get_passive_skills") == -1, "egg runtime should not retain passive breakdown assembly")
	_expect(surface_source.find("func apply_gauge_gain_per_hit") >= 0, "profile surface should own gauge derivation")
	_expect(surface_source.find("func get_player_speed_multiplier") >= 0, "profile surface should own speed derivation")
	_expect(surface_source.find("func build_player_stat_breakdown") >= 0, "profile surface should own stat breakdown projection")

	var inactive_runtime := LingpetEggRuntime.new()
	_expect_float(inactive_runtime.get_gauge_gain_per_hit(50.0), 50.0, "inactive runtime gauge facade should keep the base")
	_expect_float(inactive_runtime.get_player_speed_multiplier(), 1.0, "inactive runtime speed facade should stay neutral")
	_expect(inactive_runtime.get_player_stat_breakdown("player_speed").is_empty(), "inactive runtime breakdown should stay empty")

	var tailwind_runtime := LingpetEggRuntime.new()
	_expect(
		tailwind_runtime.debug_grant_and_activate_pet(
			"maribo",
			null,
			false,
			"maribo_hydro_sphere",
			"lingpet_tailwind_steps",
			null,
			1,
			3
		),
		"runtime facade fixture should activate a Lv.3 Tailwind guardian"
	)
	_expect_float(tailwind_runtime.get_player_speed_multiplier(), 1.10, "runtime speed facade should preserve Lv.3 Tailwind scaling")
	var tailwind_entries: Array = tailwind_runtime.get_player_stat_breakdown("player_speed")
	_expect_eq(tailwind_entries.size(), 1, "runtime speed breakdown should expose the equipped passive")
	if not tailwind_entries.is_empty():
		_expect_eq(str((tailwind_entries[0] as Dictionary).get("label", "")), "순풍 발산", "runtime speed breakdown should keep the catalog label")

	var resonance_runtime := LingpetEggRuntime.new()
	_expect(
		resonance_runtime.debug_grant_and_activate_pet(
			"maribo",
			null,
			false,
			"maribo_hydro_sphere",
			"lingpet_resonance_boost",
			null,
			1,
			3
		),
		"runtime facade fixture should activate a Lv.3 Resonance guardian"
	)
	_expect_float(resonance_runtime.get_gauge_gain_per_hit(50.0), 55.0, "runtime gauge facade should preserve Lv.3 Resonance flooring")
	var resonance_entries: Array = resonance_runtime.get_player_stat_breakdown("gauge_gain", 50.0)
	_expect_eq(resonance_entries.size(), 1, "runtime gauge breakdown should expose the equipped passive")
	if not resonance_entries.is_empty():
		_expect_float(float((resonance_entries[0] as Dictionary).get("after", 0.0)), 55.0, "runtime gauge breakdown should match effective gain")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected=%s actual=%s)" % [message, str(expected), str(actual)])


func _expect_float(actual: float, expected: float, message: String, tolerance: float = 0.001) -> void:
	if absf(actual - expected) > tolerance:
		_failures.append("%s (expected=%.3f actual=%.3f)" % [message, expected, actual])
