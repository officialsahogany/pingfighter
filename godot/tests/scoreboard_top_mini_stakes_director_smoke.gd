extends SceneTree

const ScoreboardRenderer := preload("res://scripts/hud/scoreboard_renderer.gd")
const ScoreboardTopMiniRenderer := preload("res://scripts/hud/scoreboard_top_mini_renderer.gd")
const ScoreboardTopMiniNormalRenderer := preload("res://scripts/hud/scoreboard_top_mini_normal_renderer.gd")
const ScoreboardTopMiniNormalChromeRenderer := preload("res://scripts/hud/scoreboard_top_mini_normal_chrome_renderer.gd")
const ScoreboardTopMiniDeuceRenderer := preload("res://scripts/hud/scoreboard_top_mini_deuce_renderer.gd")
const ScoreboardTopMiniDeuceEffectRenderer := preload("res://scripts/hud/scoreboard_top_mini_deuce_effect_renderer.gd")
const Stage1TopMiniScoreboardSceneDrawer := preload("res://scripts/stages/stage1/stage1_top_mini_scoreboard_scene_drawer.gd")

var _failures: Array[String] = []


class FakeScoreState:
	extends RefCounted

	var player_score := 4
	var boss_score := 2
	var deuce_mode := false
	var player_can_win := true
	var boss_can_win := false
	var would_score_finish_calls: Array[String] = []
	var danger_calls := 0

	func get_snapshot() -> Dictionary:
		return {
			"player_score": player_score,
			"boss_score": boss_score,
			"deuce_mode": deuce_mode,
		}

	func would_score_finish(scoring_side: String) -> bool:
		would_score_finish_calls.append(scoring_side)
		if scoring_side == "player":
			return player_can_win
		if scoring_side == "boss":
			return boss_can_win
		return false

	func is_player_in_danger() -> bool:
		danger_calls += 1
		return boss_can_win


class FakeScoreboardRenderer:
	extends RefCounted

	var draw_calls := 0
	var last_player_score := -1
	var last_boss_score := -1
	var last_deuce_mode := true
	var last_stakes: Dictionary = {}

	func draw_top_mini(
		_canvas,
		_game_offset: Vector2,
		_game_size: Vector2,
		_gameplay_width: float,
		player_score: int,
		boss_score: int,
		deuce_mode: bool,
		_sparkle_timer: float,
		_sparkle_duration: float,
		_t: float,
		_quality_scale: float = 1.0,
		stakes: Dictionary = {}
	) -> void:
		draw_calls += 1
		last_player_score = player_score
		last_boss_score = boss_score
		last_deuce_mode = deuce_mode
		last_stakes = stakes.duplicate(true)


class FakeRegistry:
	extends RefCounted

	var scoreboard_renderer := FakeScoreboardRenderer.new()
	var score_state: Object = null

	func _init(new_score_state: Object) -> void:
		score_state = new_score_state

	func get_instance(key: String) -> Object:
		if key == "scoreboard_renderer":
			return scoreboard_renderer
		if key == "match_score_state":
			return score_state
		return null


class FakeForwardTopMiniRenderer:
	extends RefCounted

	var last_stakes: Dictionary = {}
	var draw_calls := 0

	func draw(
		_canvas: Node2D,
		_game_offset: Vector2,
		_game_size: Vector2,
		_gameplay_width: float,
		_player_score: int,
		_boss_score: int,
		_deuce_mode: bool,
		_sparkle_timer: float,
		_sparkle_duration: float,
		_t: float,
		_quality_scale: float = 1.0,
		stakes: Dictionary = {}
	) -> void:
		draw_calls += 1
		last_stakes = stakes.duplicate(true)


class FakeNormalRenderer:
	extends RefCounted

	var draw_calls := 0
	var last_player_score := -1
	var last_boss_score := -1
	var last_stakes: Dictionary = {}

	func draw(
		_canvas: Node2D,
		_rect: Rect2,
		_scale_factor: float,
		_sparkle_progress: float,
		_sparkle_intensity: float,
		player_score: int,
		boss_score: int,
		_quality_scale: float = 1.0,
		stakes: Dictionary = {}
	) -> void:
		draw_calls += 1
		last_player_score = player_score
		last_boss_score = boss_score
		last_stakes = stakes.duplicate(true)


class FakeDeuceRenderer:
	extends RefCounted

	var draw_calls := 0
	var last_player_score := -1
	var last_boss_score := -1
	var last_stakes: Dictionary = {}

	func draw(
		_canvas: Node2D,
		_rect: Rect2,
		_scale_factor: float,
		_t: float,
		_sparkle_intensity: float,
		player_score: int,
		boss_score: int,
		_quality_scale: float = 1.0,
		stakes: Dictionary = {}
	) -> void:
		draw_calls += 1
		last_player_score = player_score
		last_boss_score = boss_score
		last_stakes = stakes.duplicate(true)


func _init() -> void:
	_verify_stage1_drawer_derives_normal_match_point_stakes()
	_verify_scoreboard_renderer_forwards_optional_stakes()
	_verify_top_mini_routes_stakes_to_normal_and_deuce()
	_verify_stakes_visual_helpers_are_distinct_and_noop_by_default()

	if _failures.is_empty():
		print("scoreboard_top_mini_stakes_director_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_stage1_drawer_derives_normal_match_point_stakes() -> void:
	var score_state := FakeScoreState.new()
	score_state.player_score = 4
	score_state.boss_score = 2
	score_state.deuce_mode = false
	score_state.player_can_win = true
	score_state.boss_can_win = false
	var registry := FakeRegistry.new(score_state)
	var drawer := Stage1TopMiniScoreboardSceneDrawer.new()
	drawer.draw(
		null,
		{"width": 760.0, "top_mini_score_sparkle_duration": 0.35},
		registry,
		{},
		Vector2(260.0, 40.0),
		Vector2(760.0, 750.0),
		0.0
	)
	_expect(registry.scoreboard_renderer.draw_calls == 1, "Stage 1 top mini drawer should call scoreboard renderer")
	_expect(registry.scoreboard_renderer.last_player_score == 4 and registry.scoreboard_renderer.last_boss_score == 2, "normal match point should keep the live score")
	_expect(not registry.scoreboard_renderer.last_deuce_mode, "4-2 match point should not be forced through deuce mode")
	_expect(bool(registry.scoreboard_renderer.last_stakes.get("player_can_win", false)), "4-2 should expose player match-point stakes")
	_expect(not bool(registry.scoreboard_renderer.last_stakes.get("boss_can_win", true)), "4-2 should not expose boss danger stakes")
	_expect(score_state.would_score_finish_calls == ["player"], "stakes should use would_score_finish(\"player\") instead of hard-coded score thresholds")
	_expect(score_state.danger_calls == 1, "stakes should use is_player_in_danger for boss danger")


func _verify_scoreboard_renderer_forwards_optional_stakes() -> void:
	var renderer := ScoreboardRenderer.new()
	var fake_top := FakeForwardTopMiniRenderer.new()
	renderer.top_mini_renderer = fake_top
	var stakes := {"player_can_win": true, "boss_can_win": false}
	renderer.draw_top_mini(
		null,
		Vector2.ZERO,
		Vector2(760.0, 750.0),
		760.0,
		4,
		2,
		false,
		0.0,
		0.35,
		0.0,
		1.0,
		stakes
	)
	_expect(fake_top.draw_calls == 1, "scoreboard renderer should forward top-mini draw")
	_expect(fake_top.last_stakes == stakes, "scoreboard renderer should append stakes without changing them")


func _verify_top_mini_routes_stakes_to_normal_and_deuce() -> void:
	var renderer := ScoreboardTopMiniRenderer.new()
	var fake_normal := FakeNormalRenderer.new()
	var fake_deuce := FakeDeuceRenderer.new()
	renderer.normal_renderer = fake_normal
	renderer.deuce_renderer = fake_deuce
	var canvas := Node2D.new()
	var opportunity := {"player_can_win": true, "boss_can_win": false}
	renderer.draw(canvas, Vector2(260.0, 40.0), Vector2(760.0, 750.0), 760.0, 4, 2, false, 0.0, 0.35, 0.0, 1.0, opportunity)
	_expect(fake_normal.draw_calls == 1 and fake_deuce.draw_calls == 0, "normal match point should still route to the normal renderer")
	_expect(fake_normal.last_stakes == opportunity, "normal renderer should receive match-point stakes")

	var both := {"player_can_win": true, "boss_can_win": true}
	renderer.draw(canvas, Vector2(260.0, 40.0), Vector2(760.0, 750.0), 760.0, 6, 6, true, 0.0, 0.35, 0.0, 1.0, both)
	_expect(fake_deuce.draw_calls == 1, "deuce score should route to the deuce renderer")
	_expect(fake_deuce.last_stakes == both, "deuce renderer should receive both-sided stakes")
	canvas.free()


func _verify_stakes_visual_helpers_are_distinct_and_noop_by_default() -> void:
	var normal := ScoreboardTopMiniNormalRenderer.new()
	var normal_chrome := ScoreboardTopMiniNormalChromeRenderer.new()
	var deuce := ScoreboardTopMiniDeuceRenderer.new()
	var deuce_effect := ScoreboardTopMiniDeuceEffectRenderer.new()
	var empty := {}
	var opportunity := {"player_can_win": true, "boss_can_win": false}
	var danger := {"player_can_win": false, "boss_can_win": true}
	var both := {"player_can_win": true, "boss_can_win": true}

	_expect(normal._get_player_score_color(empty) == ScoreboardTopMiniNormalRenderer.PLAYER_NORMAL_COLOR, "empty stakes should keep the normal player color")
	_expect(normal._get_boss_score_color(empty) == ScoreboardTopMiniNormalRenderer.BOSS_NORMAL_COLOR, "empty stakes should keep the normal boss color")
	_expect(normal_chrome._get_player_bay_rim_color(empty) == ScoreboardTopMiniNormalChromeRenderer.BASE_BAY_RIM_COLOR, "empty stakes should keep the player bay rim unchanged")
	_expect(normal_chrome._get_boss_bay_rim_color(empty) == ScoreboardTopMiniNormalChromeRenderer.BASE_BAY_RIM_COLOR, "empty stakes should keep the boss bay rim unchanged")
	_expect(is_equal_approx(deuce._get_stakes_glow_bonus(empty), 0.0), "empty stakes should not boost deuce glow")
	_expect(is_equal_approx(deuce._get_stakes_jitter_multiplier(empty), 1.0), "empty stakes should not boost deuce jitter")
	_expect(is_equal_approx(deuce_effect._get_stakes_global_boost(empty), 0.0), "empty stakes should not boost deuce effect layers")

	_expect(normal._get_player_score_color(opportunity) != normal._get_boss_score_color(danger), "opportunity and danger score accents should use different colors")
	_expect(normal_chrome._get_player_bay_rim_color(opportunity) != normal_chrome._get_boss_bay_rim_color(danger), "opportunity and danger bay rims should use different colors")
	_expect(deuce._get_stakes_glow_bonus(both) > deuce._get_stakes_glow_bonus(opportunity), "both-sided deuce stakes should be stronger than player-only stakes")
	_expect(deuce._get_stakes_glow_bonus(both) > deuce._get_stakes_glow_bonus(danger), "both-sided deuce stakes should be stronger than danger-only stakes")
	_expect(deuce_effect._get_stakes_global_boost(both) > deuce_effect._get_stakes_global_boost(opportunity), "both-sided deuce stakes should maximize effect boost")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
