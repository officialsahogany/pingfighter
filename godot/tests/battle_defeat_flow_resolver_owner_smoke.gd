extends SceneTree

const BattleDefeatFlowResolver := preload(
	"res://scripts/core/battle_defeat_flow_resolver.gd"
)

var _failures: Array[String] = []
var _continue_calls := 0
var _exit_calls := 0


class FakeOwner:
	extends RefCounted

	var chance_gems_count := 0
	var chance_gems_max := 3


class FakeScoreboard:
	extends RefCounted

	var player_points := 1
	var boss_points := 5
	var win_goal := 5
	var last_scoring_side := "boss"

	func get_player_points() -> int:
		return player_points

	func get_boss_points() -> int:
		return boss_points

	func get_win_goal() -> int:
		return win_goal

	func get_last_scoring_side() -> String:
		return last_scoring_side


class FakeChanceGemStore:
	extends RefCounted

	var chance_gems := 0
	var max_chance_gems := 3
	var consume_calls := 0

	func _init(initial_count: int) -> void:
		chance_gems = initial_count

	func get_chance_gems() -> int:
		return chance_gems

	func get_max_chance_gems() -> int:
		return max_chance_gems

	func consume_chance_gem() -> int:
		consume_calls += 1
		chance_gems = maxi(0, chance_gems - 1)
		return chance_gems


class FakeContinueScreen:
	extends RefCounted

	var prewarm_calls := 0
	var show_calls := 0
	var continue_callback := Callable()
	var consume_callback := Callable()

	func prewarm_assets() -> void:
		prewarm_calls += 1

	func show_with_consume(
		_owner: Object,
		_registry: Object,
		next_continue_callback: Callable,
		next_consume_callback: Callable
	) -> bool:
		show_calls += 1
		continue_callback = next_continue_callback
		consume_callback = next_consume_callback
		return true


class FakeSettlementScreen:
	extends RefCounted

	var show_calls := 0
	var exit_callback := Callable()

	func show(
		_owner: Object,
		_registry: Object,
		next_exit_callback: Callable
	) -> bool:
		show_calls += 1
		exit_callback = next_exit_callback
		return true


class FakeRegistry:
	extends RefCounted

	var modules: Dictionary = {}

	func get_instance(key: String) -> Object:
		var value: Variant = modules.get(key, null)
		return value as Object if value is Object else null


func _init() -> void:
	_verify_non_defeat_falls_through()
	_verify_continue_delays_consumption_until_confirm()
	_verify_empty_store_routes_to_settlement()
	_verify_missing_continue_screen_falls_back_safely()
	_verify_source_ownership()

	if _failures.is_empty():
		print("battle_defeat_flow_resolver_owner_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_non_defeat_falls_through() -> void:
	var owner := FakeOwner.new()
	var scoreboard := FakeScoreboard.new()
	scoreboard.boss_points = 4
	var store := FakeChanceGemStore.new(2)
	var registry := _build_registry(scoreboard, store)
	var handled: bool = BattleDefeatFlowResolver.new().resolve(
		registry,
		owner,
		Callable(self, "_record_continue"),
		Callable(self, "_record_exit")
	)
	_expect(not handled, "non-defeat scoreboard result must fall through")
	_expect(store.consume_calls == 0, "non-defeat must not consume a chance gem")


func _verify_continue_delays_consumption_until_confirm() -> void:
	_continue_calls = 0
	var owner := FakeOwner.new()
	var store := FakeChanceGemStore.new(2)
	var continue_screen := FakeContinueScreen.new()
	var registry := _build_registry(FakeScoreboard.new(), store)
	registry.modules["defeat_chance_gems_continue_screen"] = continue_screen
	var resolver: Object = BattleDefeatFlowResolver.new()

	var handled: bool = resolver.resolve(
		registry,
		owner,
		Callable(self, "_record_continue"),
		Callable(self, "_record_exit")
	)
	_expect(handled, "defeat with gems must be handled by the continue screen")
	_expect(continue_screen.prewarm_calls == 1, "continue screen must prewarm before show")
	_expect(continue_screen.show_calls == 1, "continue screen must open once")
	_expect(store.consume_calls == 0, "opening the continue screen must not consume early")
	_expect(owner.chance_gems_count == 2 and owner.chance_gems_max == 3, "store count and capacity must mirror to owner before confirm")

	var remaining: int = int(continue_screen.consume_callback.call())
	continue_screen.continue_callback.call()
	_expect(remaining == 1 and store.consume_calls == 1, "confirm callback must consume exactly one gem")
	_expect(owner.chance_gems_count == 1, "remaining gem count must mirror to owner")
	_expect(_continue_calls == 1, "continue callback must remain the match-flow driver's callback")
	continue_screen.continue_callback = Callable()
	continue_screen.consume_callback = Callable()


func _verify_empty_store_routes_to_settlement() -> void:
	_exit_calls = 0
	var owner := FakeOwner.new()
	owner.chance_gems_count = 2
	var store := FakeChanceGemStore.new(0)
	var settlement := FakeSettlementScreen.new()
	var registry := _build_registry(FakeScoreboard.new(), store)
	registry.modules["defeat_settlement_screen"] = settlement

	var handled: bool = BattleDefeatFlowResolver.new().resolve(
		registry,
		owner,
		Callable(self, "_record_continue"),
		Callable(self, "_record_exit")
	)
	_expect(handled, "zero-gem defeat must be handled by settlement")
	_expect(owner.chance_gems_count == 0, "empty store must overwrite stale owner gem count")
	_expect(settlement.show_calls == 1, "zero-gem defeat must open settlement once")
	settlement.exit_callback.call()
	_expect(_exit_calls == 1, "settlement must receive the driver's exit callback")
	settlement.exit_callback = Callable()


func _verify_missing_continue_screen_falls_back_safely() -> void:
	_continue_calls = 0
	var owner := FakeOwner.new()
	var store := FakeChanceGemStore.new(2)
	var registry := _build_registry(FakeScoreboard.new(), store)

	var handled: bool = BattleDefeatFlowResolver.new().resolve(
		registry,
		owner,
		Callable(self, "_record_continue"),
		Callable(self, "_record_exit")
	)
	_expect(handled, "missing continue screen must still preserve the continue path")
	_expect(store.consume_calls == 1 and owner.chance_gems_count == 1, "fallback must consume exactly one gem")
	_expect(_continue_calls == 1, "fallback must invoke the supplied continue callback once")


func _verify_source_ownership() -> void:
	var resolver_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_defeat_flow_resolver.gd"
	)
	var driver_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_scene_match_flow_driver.gd"
	)
	_expect(resolver_source.contains("show_with_consume"), "resolver must own delayed-consume screen routing")
	_expect(resolver_source.contains("consume_chance_gem"), "resolver must own chance-gem consumption")
	_expect(resolver_source.contains("defeat_settlement_screen"), "resolver must own settlement selection")
	_expect(driver_source.contains("BattleDefeatFlowResolver.new()"), "match-flow driver must compose the resolver")
	_expect(driver_source.contains("_defeat_flow_resolver.resolve("), "match-flow driver must delegate defeat resolution")
	_expect(not driver_source.contains("func _show_defeat_continue_screen"), "driver must not retain continue-screen dispatch")
	_expect(not driver_source.contains("func _get_chance_gems_count"), "driver must not retain chance-gem storage policy")


func _build_registry(scoreboard: Object, store: Object) -> FakeRegistry:
	var registry := FakeRegistry.new()
	registry.modules = {
		"scoreboard_state": scoreboard,
		"plaza_save_store": store,
	}
	return registry


func _record_continue() -> void:
	_continue_calls += 1


func _record_exit() -> void:
	_exit_calls += 1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
