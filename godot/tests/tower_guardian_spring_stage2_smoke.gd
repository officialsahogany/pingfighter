extends SceneTree

const RuntimePerkState := preload(
	"res://scripts/characters/runtime_perk_state.gd"
)
const CharacterInfoOverlayStatsPresenter := preload(
	"res://scripts/hud/character_info_overlay_stats_presenter.gd"
)
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const TowerAscentGuardianSpringNode := preload(
	"res://scripts/tower_ascent/tower_ascent_guardian_spring_node.gd"
)
const TowerAscentNodeActionTransaction := preload(
	"res://scripts/tower_ascent/tower_ascent_node_action_transaction.gd"
)
const TowerAscentRunState := preload(
	"res://scripts/tower_ascent/tower_ascent_run_state.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted
	var tower_ascent_prayer_count := 0
	var tower_ascent_prayer_locked := false
	var tower_ascent_soul_summoning_owned := true
	var tower_ascent_sealed_guardians: Array = []

	func set_tower_ascent_guardian_projection(
		sealed_guardians: Array,
		soul_summoning_owned: bool
	) -> void:
		tower_ascent_sealed_guardians = sealed_guardians.duplicate(true)
		tower_ascent_soul_summoning_owned = soul_summoning_owned

	func set_tower_ascent_prayer_projection(count: int, locked: bool) -> void:
		tower_ascent_prayer_count = count
		tower_ascent_prayer_locked = locked


class FakeLingpetRuntime:
	extends RefCounted
	var snapshot := {
		"state": "none",
		"pet_id": "",
		"guardian_run_state": {"pets": {}},
	}
	var enhance_calls := 0

	func build_save_snapshot() -> Dictionary:
		return snapshot.duplicate(true)

	func build_guardian_enhance_live_candidates(_owner: Object = null) -> Array:
		return (
			[{"type": "duration", "label": "duration", "weight": 1.0}]
			if str(snapshot.get("state", "")) == "companion"
			else []
		)

	func apply_guardian_enhance_random_roll(
		candidates: Array,
		_owner: Object = null,
		_registry: Object = null,
		_source: String = "perk",
		rng_override: RandomNumberGenerator = null
	) -> Dictionary:
		enhance_calls += 1
		return {
			"accepted": not candidates.is_empty() and rng_override != null,
			"applied_candidate": candidates[0] if not candidates.is_empty() else {},
		}


class FakeRegistry:
	extends RefCounted
	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		return value as Object if value is Object else null

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)


func _init() -> void:
	_verify_menu_prayer_ramp_lock_and_enhance()
	_verify_effective_stat_projection_and_caps()
	_verify_run_reset_and_snapshot_schema()
	if _failures.is_empty():
		print("tower_guardian_spring_stage2_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_menu_prayer_ramp_lock_and_enhance() -> void:
	var spring := TowerAscentGuardianSpringNode.new()
	var run_state := TowerAscentRunState.new()
	var runtime_state := RuntimePerkState.new()
	var lingpet_runtime := FakeLingpetRuntime.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"lingpet_egg_runtime": lingpet_runtime,
		"runtime_perk_state": runtime_state,
	}
	var owner := FakeOwner.new()
	var resolution_ids := {}
	var transaction := TowerAscentNodeActionTransaction.new()
	_expect(run_state.begin("spring-s2", {"gold": 0, "muhon": 10}), "S2 run must start")
	var actions := spring.build_actions("spring-02", 1202, run_state, owner, registry)
	_expect(_action_ids(actions) == ["guardian_spring:palm", "guardian_spring:prayer:0"], "no guardian must expose palm then prayer")
	for index in range(3):
		var prayer := _find_action_with_prefix(actions, "guardian_spring:prayer:")
		var expected_cost := index * TowerAscentTuning.TEMP_SPRING_PRAYER_COST_STEP
		_expect(int(prayer.get("payload", {}).get("cost", -1)) == expected_cost, "prayer cost must ramp 0, 2, 4 from count")
		var result := spring.execute_action(
			str(prayer.get("id", "")),
			"spring-s2:prayer:%d" % index,
			"spring-02",
			1202,
			run_state,
			resolution_ids,
			transaction,
			owner,
			registry
		)
		_expect(bool(result.get("accepted", false)) and bool(result.get("applied", false)), "each affordable prayer must commit")
		actions = spring.build_actions("spring-02", 1202, run_state, owner, registry)
	_expect(run_state.get_prayer_count() == 3, "three prayers must increment the run-owned count")
	_expect(int(run_state.export_economy().get("muhon", -1)) == 4, "prayers must debit exactly 0 + 2 + 4 Muhon")
	spring.sync_owner_projection(owner, run_state, registry)
	_expect(owner.tower_ascent_prayer_count == 3 and runtime_state.get_tower_spring_prayer_count() == 3, "run prayer count must cross owner and runtime projections")

	_expect(run_state.lock_guardian_prayer(), "guardian acquisition must lock prayer once")
	lingpet_runtime.snapshot = {
		"state": "companion",
		"pet_id": "lunabi",
		"guardian_run_state": {"pets": {"lunabi": {}}},
	}
	actions = spring.build_actions("spring-02", 1202, run_state, owner, registry)
	_expect(_action_ids(actions).size() == 2, "guardian menu must keep two stable action slots")
	_expect(str(actions[0].get("id", "")).begins_with("guardian_spring:enhance:"), "guardian menu first slot must be encounter enhancement")
	_expect(str(actions[1].get("id", "")).begins_with("guardian_spring:browse:"), "guardian menu second slot must expose S3 browse")
	_expect(bool(actions[1].get("enabled", false)), "S3 browse must be enabled when the lingpet runtime is present")
	_expect(_find_action_with_prefix(actions, "guardian_spring:prayer:").is_empty(), "prayer must disappear permanently after guardian acquisition")
	for index in range(2):
		var enhance := _find_action_with_prefix(actions, "guardian_spring:enhance:")
		_expect(bool(enhance.get("enabled", false)), "one-Muhon enhancement must stay repeatable")
		var result := spring.execute_action(
			str(enhance.get("id", "")),
			"spring-s2:enhance:%d" % index,
			"spring-02",
			1202,
			run_state,
			resolution_ids,
			transaction,
			owner,
			registry
		)
		_expect(bool(result.get("applied", false)), "repeat enhancement must commit")
		actions = spring.build_actions("spring-02", 1202, run_state, owner, registry)
	_expect(lingpet_runtime.enhance_calls == 2, "repeat enhancement must execute two isolated random rolls")
	_expect(int(run_state.export_economy().get("muhon", -1)) == 2, "two encounters must debit one Muhon each")


func _verify_effective_stat_projection_and_caps() -> void:
	var runtime_state := RuntimePerkState.new()
	runtime_state.set_tower_spring_prayer_count(2)
	_expect(is_equal_approx(runtime_state.get_player_speed_multiplier(), 1.06), "prayer_count 2 must add +6 percentage points to speed")
	_expect(runtime_state.get_active_item_cooldown_msec(100000) == 94000, "prayer_count 2 must reduce cooldown by 6 percent")
	_expect(is_equal_approx(runtime_state.get_tower_spring_prayer_flat_bonus(500.0), 30.0), "flat stats must gain six percent of their baseline")
	_expect(is_equal_approx(runtime_state.get_converted_perk_option_value("bluetooth_ring", "gauge_gain_pct"), 6.0), "gauge gain query must include the global prayer percentage")
	var mythic_runtime := MythicItemRuntime.new()
	mythic_runtime.runtime_perk_state_ref = runtime_state
	_expect(
		is_equal_approx(
			CharacterInfoOverlayStatsPresenter.effective_gauge_gain_per_hit(
				null,
				mythic_runtime,
				null
			),
			53.0
		),
		"production stats presenter must display prayer +6% as 50pt to 53pt vigor gain"
	)
	runtime_state.set_tower_spring_prayer_count(100)
	_expect(runtime_state.get_active_item_cooldown_msec(100000) == 5000, "cooldown prayer reduction must respect the 95 percent cap")


func _verify_run_reset_and_snapshot_schema() -> void:
	var source := TowerAscentRunState.new()
	source.begin("spring-s2-snapshot", {"prayer_count": 2, "prayer_locked": true})
	source.set_phases([{"id": "phase_01", "nodes": [], "edges": []}])
	var snapshot := source.export_snapshot_fields()
	_expect(int(snapshot.get("schema_version", -1)) == TowerAscentRunState.SNAPSHOT_SCHEMA_VERSION, "prayer fields must use the declared run snapshot schema")
	var restored := TowerAscentRunState.new()
	_expect(restored.restore_snapshot(snapshot), "prayer run snapshot must restore")
	_expect(restored.get_prayer_count() == 2 and restored.is_guardian_prayer_locked(), "prayer count and lock must survive restore")
	restored.reset()
	_expect(restored.get_prayer_count() == 0 and not restored.is_guardian_prayer_locked(), "run reset must clear prayer count and lock")


func _action_ids(actions: Array) -> Array[String]:
	var result: Array[String] = []
	for value in actions:
		if value is Dictionary:
			result.append(str((value as Dictionary).get("id", "")))
	return result


func _find_action_with_prefix(actions: Array, prefix: String) -> Dictionary:
	for value in actions:
		if value is Dictionary and str((value as Dictionary).get("id", "")).begins_with(prefix):
			return value as Dictionary
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
