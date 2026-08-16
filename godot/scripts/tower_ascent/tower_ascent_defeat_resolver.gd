extends RefCounted

const MatchScoreState := preload("res://scripts/core/match_score_state.gd")
const TowerAscentRunState := preload(
	"res://scripts/tower_ascent/tower_ascent_run_state.gd"
)


func resolve(
	registry: Object,
	owner: Object,
	run_state: Object,
	continue_callback: Callable,
	exit_callback: Callable
) -> bool:
	if owner == null or not _is_scoreboard_player_defeat(registry):
		return false
	if run_state == null or not run_state.has_method("get_chance_gems"):
		return false
	var chance_gems := maxi(0, int(run_state.call("get_chance_gems")))
	_sync_owner(owner, chance_gems)
	if chance_gems <= 0:
		return _show_settlement_or_exit(registry, owner, exit_callback)
	var continue_screen := _get_instance(registry, "defeat_chance_gems_continue_screen")
	if continue_screen == null:
		continue_screen = _get_instance(registry, "defeat_chance_gems_soft_defeat_screen")
	var consume_callback := Callable(self, "_consume_for_continue").bind(
		run_state,
		owner
	)
	if continue_screen != null:
		if continue_screen.has_method("prewarm_assets"):
			continue_screen.call("prewarm_assets")
		if continue_screen.has_method("show_with_consume"):
			var show_result: Variant = continue_screen.call(
				"show_with_consume",
				owner,
				registry,
				continue_callback,
				consume_callback
			)
			return true if show_result == null else bool(show_result)
		if continue_screen.has_method("show"):
			consume_callback.call()
			var legacy_show_result: Variant = continue_screen.call(
				"show",
				owner,
				registry,
				continue_callback
			)
			return true if legacy_show_result == null else bool(legacy_show_result)
	_consume_for_continue(run_state, owner)
	if continue_callback.is_valid():
		continue_callback.call()
	return true


func is_scoreboard_player_defeat(registry: Object) -> bool:
	return _is_scoreboard_player_defeat(registry)


func _consume_for_continue(run_state: Object, owner: Object) -> int:
	if run_state == null or not run_state.has_method("consume_chance_gem"):
		return 0
	var result: Dictionary = run_state.call("consume_chance_gem")
	var remaining := maxi(0, int(result.get("remaining", 0)))
	_sync_owner(owner, remaining)
	return remaining


func _show_settlement_or_exit(
	registry: Object,
	owner: Object,
	exit_callback: Callable
) -> bool:
	var settlement := _get_instance(registry, "defeat_settlement_screen")
	if settlement == null:
		settlement = _get_instance(registry, "defeat_chance_gems_settlement_screen")
	if settlement != null:
		if settlement.has_method("show"):
			var show_result: Variant = settlement.call(
				"show",
				owner,
				registry,
				exit_callback
			)
			return true if show_result == null else bool(show_result)
		if settlement.has_method("show_from_scoreboard"):
			return bool(settlement.call(
				"show_from_scoreboard",
				owner,
				registry,
				exit_callback
			))
	if exit_callback.is_valid():
		exit_callback.call()
	return true


func _is_scoreboard_player_defeat(registry: Object) -> bool:
	var scoreboard := _get_instance(registry, "scoreboard_state")
	if scoreboard == null:
		return false
	var player_points := _call_int(scoreboard, "get_player_points", 0)
	var boss_points := _call_int(scoreboard, "get_boss_points", 0)
	var win_goal := maxi(1, _call_int(scoreboard, "get_win_goal", MatchScoreState.WIN_GOAL))
	if boss_points < win_goal:
		return false
	if scoreboard.has_method("get_last_scoring_side"):
		return str(scoreboard.call("get_last_scoring_side")) == "boss"
	return boss_points >= player_points


func _sync_owner(owner: Object, count: int) -> void:
	if owner == null:
		return
	owner.set(
		"chance_gems_count",
		clampi(count, 0, TowerAscentRunState.MAX_CHANCE_GEMS)
	)
	owner.set("chance_gems_max", TowerAscentRunState.MAX_CHANCE_GEMS)


func _call_int(target: Object, method_name: String, fallback: int) -> int:
	if target != null and target.has_method(method_name):
		return int(target.call(method_name))
	return fallback


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	var value: Variant = registry.call("get_instance", key)
	return value as Object if value is Object else null
