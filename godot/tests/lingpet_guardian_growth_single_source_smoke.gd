extends SceneTree

const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const LingpetGuardianRunState := preload("res://scripts/lingpet/lingpet_guardian_run_state.gd")

class FakeOwner:
	extends Node
	var ball_active := true
	var ball_pos := Vector2(320.0, 314.0)
	var ball_vel := Vector2(0.0, 14.0)
	var ball_size := 28.6
	var max_bounce_angle := 60.0
	var rally_speed_cap_bonus := 0.0
	var special_gauge := 0.0
	var special_gauge_max := 500.0
	var player_pos := Vector2.ZERO
	var player_paddle_width := 155.0

var _failures: Array[String] = []


func _init() -> void:
	_verify_ball_hits_are_growth_neutral()
	_verify_retired_save_keys_are_read_and_discarded()
	_verify_retired_pipeline_is_absent()
	if _failures.is_empty():
		print("lingpet_guardian_growth_single_source_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_ball_hits_are_growth_neutral() -> void:
	var runtime: Object = LingpetEggRuntime.new()
	var owner := FakeOwner.new()
	runtime._state = LingpetEggRuntime.STATE_COMPANION
	runtime._pet_id = "maribo"
	runtime._current_profile.set_pet_id("maribo")
	runtime._current_profile.set_loadout("maribo_hydro_sphere", "lingpet_ring_dash", 1, 1)
	runtime._guardian_run_state.configure_reward_context(
		"maribo",
		LingpetGuardianRunState.MOTION_STYLE_PATROL,
		1,
		1,
		0,
		false,
		"maribo_hydro_sphere",
		"lingpet_ring_dash"
	)
	runtime.configure_companion_motion_for_tests(Vector2(320.0, 320.0), 7, 0.0, true)
	var before: Dictionary = runtime.get_guardian_enhancement_rewards_for_tests("maribo")
	for _index in range(20):
		runtime._companion_body_hit_state.cooldown = 0.0
		runtime._companion_body_hit_state.ball_was_inside = false
		owner.ball_pos = Vector2(320.0, 314.0)
		owner.ball_vel = Vector2(0.0, 14.0)
		_expect(bool(runtime._resolve_companion_ball_hit(owner)), "real companion body-hit path should register every fixture hit")
	var after_hits: Dictionary = runtime.get_guardian_enhancement_rewards_for_tests("maribo")
	_expect(after_hits == before, "twenty real companion ball hits must not mutate guardian growth")
	var result: Dictionary = runtime.apply_guardian_enhancement_candidate(
		{"type": LingpetGuardianRunState.REWARD_TYPE_ACTIVE_SKILL, "skill_slot": 1},
		owner,
		null,
		"maribo"
	)
	var after_enhance: Dictionary = runtime.get_guardian_enhancement_rewards_for_tests("maribo")
	_expect(bool(result.get("accepted", false)), "Guardian Enhance must remain the live growth trigger")
	_expect(int(after_enhance.get("active_skill_bonus", 0)) == int(before.get("active_skill_bonus", 0)) + 1, "Guardian Enhance should apply exactly one active-skill growth stack")
	owner.queue_free()


func _verify_retired_save_keys_are_read_and_discarded() -> void:
	var state: Object = LingpetGuardianRunState.new()
	var legacy_value_key := "sati" + "ety"
	state.import_run_state({
		"duration_pool": 44.0,
		"duration_pool_max": 50.0,
		"duration_increase_count": 0,
		"pets": {
			"maribo": {
				"pet_id": "maribo",
				"reward_counts": {"active_skill_bonus": 2},
				"affinity_points": 999.0,
				"affinity_level": 25,
				"reward_deck": [{"type": "mobility"}],
				"reward_history": [{"type": "defense"}],
				legacy_value_key: 12.0,
			},
		},
	})
	var exported: Dictionary = state.export_run_state()
	var pets: Dictionary = exported.get("pets", {}) as Dictionary
	var maribo: Dictionary = pets.get("maribo", {}) as Dictionary
	_expect(is_equal_approx(float(exported.get("duration_pool", 0.0)), 44.0), "new run-shared duration state must survive legacy-key import")
	_expect(int((maribo.get("reward_counts", {}) as Dictionary).get("active_skill_bonus", 0)) == 2, "enhancement buff store must survive legacy-key import")
	for retired_key in LingpetGuardianRunState.RETIRED_RUN_STATE_KEYS + [legacy_value_key, legacy_value_key + "_exhausted", legacy_value_key + "_exhaustion_timer"]:
		_expect(not maribo.has(retired_key), "legacy save key must be read-and-discarded: %s" % retired_key)


func _verify_retired_pipeline_is_absent() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var owner_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_guardian_run_state.gd")
	var panel_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_lingpet_presenter.gd")
	var schema_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_state.gd")
	for needle in ["func add_affinity_points(", "func get_affinity_points(", "func handle_score_event(", "LingpetAffinityGrantController", "LingpetAffinityBattleLifecycle"]:
		_expect(runtime_source.find(needle) < 0, "egg runtime must not retain retired affinity ingress: %s" % needle)
	for needle in ["func add_points(", "func _build_reward_deck(", "affinity_points\": 0.0", "affinity_level\": 0"]:
		_expect(owner_source.find(needle) < 0, "guardian owner must not retain retired growth engine: %s" % needle)
	_expect(panel_source.find("affinity_level") < 0 and panel_source.find("교감") < 0, "TAB guardian presentation must not retain affinity rows")
	_expect(schema_source.find("lingpet_affinity_points") < 0 and schema_source.find("lingpet_affinity_level") < 0, "battle owner schema must not publish retired affinity keys")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
