extends SceneTree

const ScoreboardOverlayRenderer := preload("res://scripts/hud/scoreboard_overlay_renderer.gd")
const ScoreboardState := preload("res://scripts/hud/scoreboard_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	var renderer := ScoreboardOverlayRenderer.new()
	var state := ScoreboardState.new()

	state.start(3, 4, false, "player")
	_expect(
		str(renderer.call("_get_result_focus_side", state)) == "player",
		"a player-scored round must light the player even while the boss leads"
	)

	state.start(4, 3, false, "boss")
	_expect(
		str(renderer.call("_get_result_focus_side", state)) == "boss",
		"a boss-scored round must light the boss even while the player leads"
	)

	state.start(4, 4, false, "player")
	_expect(
		str(renderer.call("_get_result_focus_side", state)) == "player",
		"a tied round must light the actual scorer"
	)

	state.start(4, 3, false, "")
	_expect(
		str(renderer.call("_get_result_focus_side", state)) == "player",
		"legacy snapshots without a scorer should fall back to the score leader"
	)

	if _failures.is_empty():
		print("scoreboard_result_focus_side_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
