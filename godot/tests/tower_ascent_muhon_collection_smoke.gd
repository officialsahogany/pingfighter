extends SceneTree

const RuntimePerkStarpointAbsorption := preload(
	"res://scripts/characters/runtime_perk_starpoint_absorption.gd"
)
const RuntimePerkStarpointCollectionFlow := preload(
	"res://scripts/characters/runtime_perk_starpoint_collection_flow.gd"
)
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const BattleBootResourcePrewarmController := preload(
	"res://scripts/core/battle_boot_resource_prewarm_controller.gd"
)

const PRODUCER_PATHS := [
	"res://scripts/stages/common/starpoint_collection_reward_policy.gd",
	"res://scripts/characters/mythic_perk_grant_helper.gd",
	"res://scripts/core/stage_clear_reward_resolver.gd",
	"res://scripts/plaza/plaza_academy_transactions.gd",
	"res://scripts/core/battle_scene_api.gd",
]

var _failures: Array[String] = []
var _open_choice_calls := 0


func _init() -> void:
	_verify_tower_collection_routes_to_muhon_without_choice()
	_verify_tower_collection_fails_closed_without_owner()
	_verify_stage_entry_prewarm_removes_cold_first_pickup()
	_verify_legacy_mode_skips_tower_prewarm()
	_verify_reserved_chosik_keeps_content_choice_semantics()
	_verify_real_flow_owner_accumulates_run_muhon()
	_verify_producer_audit_contract()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_ascent_muhon_collection_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_tower_collection_routes_to_muhon_without_choice() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var state := FakeStarpointState.new()
	var tower_owner := FakeTowerFlowOwner.new()
	var result := _collect(2, state, FakeRegistry.new(tower_owner), FakeCatalog.new())
	_expect(bool(result.get("accepted", false)), "tower collection must be accepted by the run owner")
	_expect(str(result.get("collection_mode", "")) == "tower_muhon", "tower collection must declare the Muhon route")
	_expect(tower_owner.collected_muhon == 2, "the full compatibility pickup amount must reach run_state.muhon")
	_expect(state.starpoint_for_skills == 0 and state.pending_skill_choices == 0, "tower Muhon must not mutate legacy choice counters")
	_expect(not state.choice_active and _open_choice_calls == 0, "tower Muhon must not open a combat choice modal")


func _verify_tower_collection_fails_closed_without_owner() -> void:
	var state := FakeStarpointState.new()
	var result := _collect(1, state, FakeRegistry.new(null), FakeCatalog.new())
	_expect(not bool(result.get("accepted", true)), "missing tower flow owner must reject the collection")
	_expect(str(result.get("blocked_reason", "")) == "missing_tower_ascent_flow_owner", "missing owner rejection must stay diagnosable")
	_expect(state.pending_skill_choices == 0 and _open_choice_calls == 0, "failed tower routing must not fall back into a legacy modal")


func _verify_stage_entry_prewarm_removes_cold_first_pickup() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var registry := ColdTrackingRegistry.new()
	var state := FakeStarpointState.new()
	var cold_pickup := _collect(1, state, registry, FakeCatalog.new())
	_expect(not bool(cold_pickup.get("accepted", true)), "an unprewarmed tower pickup must fail closed instead of cold-creating the flow owner")
	_expect(registry.get_instance_calls == 0, "the pickup hot path must never call get_instance")
	var prewarm_controller := BattleBootResourcePrewarmController.new()
	var prewarm_started_usec := Time.get_ticks_usec()
	var prewarm_result: Dictionary = prewarm_controller.prewarm_tower_ascent_muhon_collection(
		null,
		Callable(registry, "get_instance")
	)
	var prewarm_elapsed_usec := maxi(0, Time.get_ticks_usec() - prewarm_started_usec)
	_expect(bool(prewarm_result.get("accepted", false)), "stage-entry prewarm must start the tower run owner")
	_expect(registry.get_instance_calls == 1, "stage-entry prewarm must own the one cold tower-flow creation")
	var pickup_create_calls_before := registry.get_instance_calls
	var pickup_started_usec := Time.get_ticks_usec()
	var hot_pickup := _collect(1, state, registry, FakeCatalog.new())
	var pickup_elapsed_usec := maxi(0, Time.get_ticks_usec() - pickup_started_usec)
	_expect(bool(hot_pickup.get("accepted", false)), "the first post-prewarm Muhon pickup must be accepted")
	_expect(registry.get_instance_calls == pickup_create_calls_before, "the first pickup must not cold-create any registry module")
	_expect(registry.get_cached_instance_calls >= 2, "both the fail-closed and warmed pickup legs must use cached lookup")
	_expect(int(registry.flow_owner.get_run_state_snapshot().get("muhon", 0)) == 1, "the warmed first pickup must reach run_state.muhon")
	print("tower_muhon_first_pickup_measurement: prewarm_usec=%d pickup_usec=%d cold_creations_during_pickup=0" % [prewarm_elapsed_usec, pickup_elapsed_usec])


func _verify_legacy_mode_skips_tower_prewarm() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(false)
	var registry := ColdTrackingRegistry.new()
	var result: Dictionary = BattleBootResourcePrewarmController.new().prewarm_tower_ascent_muhon_collection(
		null,
		Callable(registry, "get_instance")
	)
	_expect(bool(result.get("accepted", false)), "flag OFF prewarm must remain a no-op success")
	_expect(str(result.get("reason", "")) == "feature_disabled", "flag OFF prewarm must expose its no-op reason")
	_expect(registry.get_instance_calls == 0, "flag OFF must not create the tower flow owner during common prewarm")
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)


func _verify_reserved_chosik_keeps_content_choice_semantics() -> void:
	var state := FakeStarpointState.new()
	var tower_owner := FakeTowerFlowOwner.new()
	var result := _collect(1, state, FakeRegistry.new(tower_owner), FakeReservedCatalog.new())
	_expect(bool(result.get("accepted", false)), "reserved Chosik compatibility collection must remain accepted")
	_expect(state.pending_skill_choices == 1 and state.choice_active, "reserved Chosik must still materialize one exact content choice")
	_expect(tower_owner.collected_muhon == 0, "reserved Chosik content must not be converted into currency")
	_expect(_open_choice_calls == 1, "reserved Chosik must open exactly one choice")


func _verify_real_flow_owner_accumulates_run_muhon() -> void:
	var flow_owner := TowerAscentFlowOwner.new()
	var first: Dictionary = flow_owner.collect_muhon(2)
	var second: Dictionary = flow_owner.collect_muhon(3)
	var snapshot: Dictionary = flow_owner.get_run_state_snapshot()
	_expect(bool(first.get("accepted", false)) and bool(second.get("accepted", false)), "real tower owner must accept positive Muhon pickups")
	_expect(int(snapshot.get("muhon", 0)) == 5, "real run_state must accumulate all tower Muhon pickups")
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(false)
	var rejected: Dictionary = flow_owner.collect_muhon(1)
	_expect(not bool(rejected.get("accepted", true)), "flag OFF must reject direct tower Muhon mutation")
	_expect(int(flow_owner.get_run_state_snapshot().get("muhon", 0)) == 5, "flag OFF rejection must leave the run balance unchanged")
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)


func _verify_producer_audit_contract() -> void:
	for path in PRODUCER_PATHS:
		var source := FileAccess.get_file_as_string(path)
		_expect(source.find("collect_star_points(") >= 0, "audited compatibility producer disappeared without updating the Phase A report: %s" % path)
	var flow_source := FileAccess.get_file_as_string(
		"res://scripts/characters/runtime_perk_starpoint_collection_flow.gd"
	)
	_expect(flow_source.find("_collect_tower_muhon") >= 0, "all audited producers must converge on the central tower Muhon route")
	_expect(flow_source.find("has_reserved_boss_vision_offer") >= 0, "the secret-Chosik content exception must remain explicit")
	_expect(flow_source.find("_get_cached_registry_instance") >= 0, "tower Muhon collection must keep its cached-only owner lookup")
	_expect(flow_source.find("var flow_owner := _get_registry_instance") < 0, "tower Muhon collection must not restore a cold get_instance lookup")
	var prewarm_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_boot_resource_prewarm_controller.gd"
	)
	_expect(prewarm_source.find("tower_ascent_runtime") >= 0, "stage-runtime prewarm must retain the tower Muhon step label")
	_expect(prewarm_source.find("prewarm_tower_ascent_muhon_collection") >= 0, "stage-runtime prewarm must retain the tower owner wiring")


func _collect(
	amount: int,
	state: Object,
	registry: Object,
	catalog: Object
) -> Dictionary:
	var callbacks := {
		"open_next_choice": Callable(self, "_open_next_choice").bind(state),
	}
	return RuntimePerkStarpointCollectionFlow.new().collect_star_points(
		amount,
		"smasher",
		catalog,
		null,
		registry,
		false,
		state,
		RuntimePerkStarpointAbsorption.new(),
		null,
		null,
		callbacks,
		1
	)


func _open_next_choice(
	_character_type: String,
	_catalog: Object,
	_reroll: bool,
	_owner: Object,
	_registry: Object,
	_source: Variant,
	_context: Dictionary,
	state: Object
) -> Dictionary:
	_open_choice_calls += 1
	state.set("choice_active", true)
	return {"accepted": true}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


class FakeStarpointState:
	extends RefCounted
	var starpoint_for_skills := 0
	var pending_skill_choices := 0
	var choice_active := false


class FakeTowerFlowOwner:
	extends RefCounted
	var collected_muhon := 0

	func collect_muhon(amount: int, _owner: Object = null) -> Dictionary:
		collected_muhon += amount
		return {
			"accepted": true,
			"reason": "collected",
			"amount": amount,
			"balances": {"muhon": collected_muhon},
		}


class FakeRegistry:
	extends RefCounted
	var tower_flow_owner: Object

	func _init(value: Object) -> void:
		tower_flow_owner = value

	func get_instance(key: String) -> Object:
		return tower_flow_owner if key == "tower_ascent_flow_owner" else null

	func get_cached_instance(key: String) -> Object:
		return tower_flow_owner if key == "tower_ascent_flow_owner" else null


class ColdTrackingRegistry:
	extends RefCounted
	var flow_owner: Object = null
	var get_instance_calls := 0
	var get_cached_instance_calls := 0

	func get_instance(key: String) -> Object:
		if key != "tower_ascent_flow_owner":
			return null
		get_instance_calls += 1
		if flow_owner == null:
			flow_owner = TowerAscentFlowOwner.new()
		return flow_owner

	func get_cached_instance(key: String) -> Object:
		if key != "tower_ascent_flow_owner":
			return null
		get_cached_instance_calls += 1
		return flow_owner


class FakeCatalog:
	extends RefCounted


class FakeReservedCatalog:
	extends RefCounted

	func has_reserved_boss_vision_offer() -> bool:
		return true
