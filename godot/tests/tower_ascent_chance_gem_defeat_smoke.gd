extends SceneTree

const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentRunState := preload(
	"res://scripts/tower_ascent/tower_ascent_run_state.gd"
)
const BattleSceneMatchFlowDriver := preload(
	"res://scripts/core/battle_scene_match_flow_driver.gd"
)

var _failures: Array[String] = []
var _continue_calls := 0
var _exit_calls := 0


class FakeOwner:
	extends RefCounted
	var current_stage := 1
	var chance_gems_count := -1
	var chance_gems_max := -1


class FakeScoreboard:
	extends RefCounted
	var player_points := 3
	var boss_points := 7
	var win_goal := 7
	var last_scoring_side := "boss"

	func get_player_points() -> int:
		return player_points

	func get_boss_points() -> int:
		return boss_points

	func get_win_goal() -> int:
		return win_goal

	func get_last_scoring_side() -> String:
		return last_scoring_side


class FakePlazaStore:
	extends RefCounted
	var get_calls := 0
	var consume_calls := 0

	func get_chance_gems() -> int:
		get_calls += 1
		return 99

	func consume_chance_gem() -> int:
		consume_calls += 1
		return 98


class FakeContinueScreen:
	extends RefCounted
	var show_calls := 0
	var consume_callback := Callable()
	var continue_callback := Callable()

	func prewarm_assets() -> void:
		pass

	func show_with_consume(
		_owner: Object,
		_registry: Object,
		continue_action: Callable,
		consume_action: Callable
	) -> bool:
		show_calls += 1
		continue_callback = continue_action
		consume_callback = consume_action
		return true

	func confirm() -> void:
		var consume_action := consume_callback
		var continue_action := continue_callback
		consume_callback = Callable()
		continue_callback = Callable()
		if consume_action.is_valid():
			consume_action.call()
		if continue_action.is_valid():
			continue_action.call()


class FakeSettlementScreen:
	extends RefCounted
	var show_calls := 0
	var exit_callback := Callable()

	func show(_owner: Object, _registry: Object, exit_action: Callable) -> bool:
		show_calls += 1
		exit_callback = exit_action
		return true


class FakeRegistry:
	extends RefCounted
	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		return value as Object if value is Object else null


func _init() -> void:
	_verify_three_run_scoped_retries_then_settlement()
	_verify_match_driver_routes_tower_before_plaza()
	_verify_non_defeat_and_flag_off_fail_closed()
	_verify_missing_continue_screen_fallback()
	_verify_run_state_default_and_cap()
	_verify_production_boundaries()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_ascent_chance_gem_defeat_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_three_run_scoped_retries_then_settlement() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var owner := FakeOwner.new()
	var scoreboard := FakeScoreboard.new()
	var plaza_store := FakePlazaStore.new()
	var continue_screen := FakeContinueScreen.new()
	var settlement_screen := FakeSettlementScreen.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"scoreboard_state": scoreboard,
		"plaza_save_store": plaza_store,
		"defeat_chance_gems_continue_screen": continue_screen,
		"defeat_settlement_screen": settlement_screen,
	}
	var flow_owner := TowerAscentFlowOwner.new()
	for expected_remaining in [2, 1, 0]:
		_expect(flow_owner.resolve_defeat(
			registry,
			owner,
			Callable(self, "_record_continue"),
			Callable(self, "_record_exit")
		), "defeat with a run gem must be handled by tower flow")
		continue_screen.confirm()
		_expect(
			int(flow_owner.get_run_state_snapshot().chance_gems) == expected_remaining,
			"confirmed retry must consume exactly one run-scoped chance gem"
		)
		_expect(owner.chance_gems_count == expected_remaining, "owner HUD mirror must follow run balance")
	_expect(flow_owner.resolve_defeat(
		registry,
		owner,
		Callable(self, "_record_continue"),
		Callable(self, "_record_exit")
	), "defeat at zero run gems must be handled as run settlement")
	_expect(settlement_screen.show_calls == 1, "fourth defeat must open settlement instead of another retry")
	_expect(continue_screen.show_calls == 3, "only three retry prompts may open per run")
	_expect(_continue_calls == 3, "three confirmed retries must invoke continue three times")
	_expect(plaza_store.get_calls == 0 and plaza_store.consume_calls == 0, "tower defeat must never read or consume plaza-owned gems")
	if settlement_screen.exit_callback.is_valid():
		settlement_screen.exit_callback.call()
	_expect(_exit_calls == 1, "settlement exit must retain the run-ending callback")


func _verify_non_defeat_and_flag_off_fail_closed() -> void:
	var owner := FakeOwner.new()
	var scoreboard := FakeScoreboard.new()
	scoreboard.boss_points = 6
	var registry := FakeRegistry.new()
	registry.instances = {"scoreboard_state": scoreboard}
	var flow_owner := TowerAscentFlowOwner.new()
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	_expect(not flow_owner.resolve_defeat(
		registry,
		owner,
		Callable(self, "_record_continue"),
		Callable(self, "_record_exit")
	), "non-defeat scoreboard must not start or consume a tower run")
	_expect(flow_owner.get_run_id().is_empty(), "non-defeat path must leave run state unopened")
	scoreboard.boss_points = 7
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(false)
	_expect(not flow_owner.resolve_defeat(
		registry,
		owner,
		Callable(self, "_record_continue"),
		Callable(self, "_record_exit")
	), "flag OFF must leave defeat handling to the legacy plaza path")
	_expect(flow_owner.get_run_id().is_empty(), "flag OFF defeat must not create tower run state")


func _verify_match_driver_routes_tower_before_plaza() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var owner := FakeOwner.new()
	var scoreboard := FakeScoreboard.new()
	var plaza_store := FakePlazaStore.new()
	var continue_screen := FakeContinueScreen.new()
	var flow_owner := TowerAscentFlowOwner.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"scoreboard_state": scoreboard,
		"plaza_save_store": plaza_store,
		"tower_ascent_flow_owner": flow_owner,
		"defeat_chance_gems_continue_screen": continue_screen,
	}
	var driver := BattleSceneMatchFlowDriver.new()
	_expect(bool(driver.call(
		"_resolve_match_defeat",
		registry,
		owner,
		Callable(),
		Callable()
	)), "production match driver must accept tower defeat before legacy fallback")
	continue_screen.confirm()
	_expect(flow_owner.get_run_state_snapshot().chance_gems == 2, "production driver retry must consume the flow-owned run gem")
	_expect(plaza_store.get_calls == 0 and plaza_store.consume_calls == 0, "production driver tower branch must bypass plaza persistence")


func _verify_missing_continue_screen_fallback() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var owner := FakeOwner.new()
	var scoreboard := FakeScoreboard.new()
	var plaza_store := FakePlazaStore.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"scoreboard_state": scoreboard,
		"plaza_save_store": plaza_store,
	}
	var flow_owner := TowerAscentFlowOwner.new()
	var continue_calls_before := _continue_calls
	_expect(flow_owner.resolve_defeat(
		registry,
		owner,
		Callable(self, "_record_continue"),
		Callable(self, "_record_exit")
	), "missing retry screen must fall back to a safe immediate retry")
	_expect(flow_owner.get_run_state_snapshot().chance_gems == 2, "fallback retry must still consume one run gem")
	_expect(_continue_calls == continue_calls_before + 1, "fallback retry must invoke continue exactly once")
	_expect(plaza_store.get_calls == 0 and plaza_store.consume_calls == 0, "fallback retry must remain isolated from plaza persistence")


func _verify_run_state_default_and_cap() -> void:
	var state := TowerAscentRunState.new()
	_expect(state.begin("chance-default"), "tower run must start without a supplied economy snapshot")
	_expect(state.get_chance_gems() == 3, "new tower run must start with three chance gems")
	state.apply_reward_bundle({"chance_gems": 9})
	_expect(state.get_chance_gems() == 3, "chance gem recovery must respect the hard cap of three")


func _verify_production_boundaries() -> void:
	var resolver_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_defeat_resolver.gd"
	)
	var driver_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_scene_match_flow_driver.gd"
	)
	_expect(resolver_source.find("plaza_save_store") < 0, "tower resolver source must not depend on plaza persistence")
	_expect(driver_source.find("tower_flow_owner.resolve_defeat") >= 0, "production match defeat path must route through tower flow first")


func _record_continue() -> void:
	_continue_calls += 1


func _record_exit() -> void:
	_exit_calls += 1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
