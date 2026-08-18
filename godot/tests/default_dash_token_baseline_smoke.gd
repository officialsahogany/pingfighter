extends SceneTree

const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")
const BattleSceneState := preload("res://scripts/core/battle_scene_state.gd")
const MatchResetController := preload("res://scripts/core/match_reset_controller.gd")
const RuntimePerkCharacterContext := preload("res://scripts/characters/runtime_perk_character_context.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_league_baselines()
	_verify_state_and_reset_fallbacks()
	_verify_derived_capacity_sources()
	if _failures.is_empty():
		print("default_dash_token_baseline_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_league_baselines() -> void:
	var config: Object = BattleSceneConfig.new()
	for mode in ["champion", "limit", "mythic", "junior"]:
		_expect(
			int(config.get_starting_dash_tokens_for_mode(mode)) == 2,
			"%s should start with two dash charges" % mode
		)
	_expect(
		BattleSceneConfig.JUNIOR_STARTING_DASH_TOKENS == BattleSceneConfig.DEFAULT_STARTING_DASH_TOKENS,
		"Junior should preserve its existing two charges without adding a league-only bonus"
	)


func _verify_state_and_reset_fallbacks() -> void:
	var state: Object = BattleSceneState.new()
	_expect(int(state.get_value("starting_dash_tokens")) == 2, "battle state schema should default to two dash charges")
	var reset: Object = MatchResetController.new()
	_expect(int(reset.call("_get_dash_token_capacity", {})) == 2, "round reset fallback should refill two dash charges")
	var context: Object = RuntimePerkCharacterContext.new()
	_expect(int(context.get_starting_dash_tokens(null)) == 2, "runtime perk capacity should inherit the two-charge baseline")


func _verify_derived_capacity_sources() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_runtime.gd")
	var stat_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_stat_bonus_runtime.gd")
	var snapshot_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_snapshot_builder.gd")
	_expect(runtime_source.find("base_tokens: int = 2") >= 0, "mythic runtime default capacity should use the two-charge baseline")
	_expect(stat_source.find("base_tokens: int = 2") >= 0, "mythic stat capacity should use the two-charge baseline")
	_expect(snapshot_source.find("get_dash_token_capacity(2)") >= 0, "mythic display snapshot should not retain a one-charge assumption")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
