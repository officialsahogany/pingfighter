extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const MatchScoreState := preload("res://scripts/core/match_score_state.gd")
const PlazaSaveStore := preload("res://scripts/plaza/plaza_save_store.gd")


func resolve(
	registry: Object,
	owner: Object,
	continue_callback: Callable,
	exit_callback: Callable
) -> bool:
	if owner == null or not _is_scoreboard_player_defeat(registry):
		return false
	var chance_gems_count: int = _get_chance_gems_count(owner, registry)
	if chance_gems_count <= 0:
		return _show_defeat_settlement(registry, owner, exit_callback)
	if _show_defeat_continue_screen(registry, owner, continue_callback):
		return true
	_consume_chance_gem(owner, registry, chance_gems_count)
	_call_callback(continue_callback)
	return true


func _show_defeat_continue_screen(
	registry: Object,
	owner: Object,
	continue_callback: Callable
) -> bool:
	var continue_screen: Object = _get_instance(
		registry,
		"defeat_chance_gems_continue_screen"
	)
	if continue_screen == null:
		continue_screen = _get_instance(registry, "defeat_chance_gems_soft_defeat_screen")
	if continue_screen == null:
		return false
	if continue_screen.has_method("prewarm_assets"):
		continue_screen.call("prewarm_assets")
	var consume_callback: Callable = Callable(
		self,
		"_consume_chance_gem_for_continue"
	).bind(
		owner,
		registry
	)
	if continue_screen.has_method("show_with_consume"):
		var show_with_consume_result: Variant = continue_screen.call(
			"show_with_consume",
			owner,
			registry,
			continue_callback,
			consume_callback
		)
		return true if show_with_consume_result == null else bool(show_with_consume_result)
	if continue_screen.has_method("show"):
		_consume_chance_gem_for_continue(owner, registry)
		var show_result: Variant = continue_screen.call(
			"show",
			owner,
			registry,
			continue_callback
		)
		return true if show_result == null else bool(show_result)
	return false


func _show_defeat_settlement(
	registry: Object,
	owner: Object,
	exit_callback: Callable
) -> bool:
	var settlement_screen: Object = _get_instance(registry, "defeat_settlement_screen")
	if settlement_screen == null:
		settlement_screen = _get_instance(
			registry,
			"defeat_chance_gems_settlement_screen"
		)
	if settlement_screen == null:
		return false
	if settlement_screen.has_method("show"):
		var show_result: Variant = settlement_screen.call(
			"show",
			owner,
			registry,
			exit_callback
		)
		return true if show_result == null else bool(show_result)
	if settlement_screen.has_method("show_from_scoreboard"):
		return bool(settlement_screen.call(
			"show_from_scoreboard",
			owner,
			registry,
			exit_callback
		))
	return false


func _is_scoreboard_player_defeat(registry: Object) -> bool:
	var scoreboard_state: Object = _get_instance(registry, "scoreboard_state")
	if scoreboard_state == null:
		return false
	var player_points: int = _call_scoreboard_int(scoreboard_state, "get_player_points", 0)
	var boss_points: int = _call_scoreboard_int(scoreboard_state, "get_boss_points", 0)
	var win_goal: int = maxi(
		1,
		_call_scoreboard_int(scoreboard_state, "get_win_goal", MatchScoreState.WIN_GOAL)
	)
	if boss_points < win_goal:
		return false
	if scoreboard_state.has_method("get_last_scoring_side"):
		return str(scoreboard_state.call("get_last_scoring_side")) == "boss"
	return boss_points >= player_points


func _get_chance_gems_count(owner: Object, registry: Object = null) -> int:
	var store: Object = _get_chance_gem_store(registry)
	if store != null and store.has_method("get_chance_gems"):
		var count: int = maxi(0, int(store.call("get_chance_gems")))
		_sync_owner_chance_gems(owner, count, _get_chance_gems_max(store))
		return count
	return max(0, int(BattleSceneOwnerReader.get_value(
		owner,
		"chance_gems_count",
		0
	)))


func _consume_chance_gem(
	owner: Object,
	registry: Object,
	current_count: int
) -> int:
	var store: Object = _get_chance_gem_store(registry)
	if store != null and store.has_method("consume_chance_gem"):
		var remaining: int = maxi(0, int(store.call("consume_chance_gem")))
		_sync_owner_chance_gems(owner, remaining, _get_chance_gems_max(store))
		return remaining
	var fallback_remaining: int = maxi(0, current_count - 1)
	_sync_owner_chance_gems(owner, fallback_remaining)
	return fallback_remaining


func _consume_chance_gem_for_continue(owner: Object, registry: Object) -> int:
	var current_count: int = _get_chance_gems_count(owner, registry)
	if current_count <= 0:
		return 0
	return _consume_chance_gem(owner, registry, current_count)


func _get_chance_gem_store(registry: Object) -> Object:
	return _get_instance(registry, "plaza_save_store")


func _get_chance_gems_max(store: Object = null) -> int:
	if store != null and store.has_method("get_max_chance_gems"):
		return maxi(1, int(store.call("get_max_chance_gems")))
	return PlazaSaveStore.MAX_CHANCE_GEMS


func _sync_owner_chance_gems(
	owner: Object,
	count: int,
	max_count: int = PlazaSaveStore.MAX_CHANCE_GEMS
) -> void:
	if owner == null:
		return
	owner.set("chance_gems_count", clampi(count, 0, max_count))
	owner.set("chance_gems_max", max_count)


func _call_scoreboard_int(
	scoreboard_state: Object,
	method_name: String,
	fallback: int
) -> int:
	if scoreboard_state != null and scoreboard_state.has_method(method_name):
		return int(scoreboard_state.call(method_name))
	return fallback


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	var value: Variant = registry.call("get_instance", key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _call_callback(callback: Callable) -> void:
	if callback.is_valid():
		callback.call()
