extends RefCounted

const ScoreboardOverlayRenderer := preload("res://scripts/hud/scoreboard_overlay_renderer.gd")
const ScoreboardTopMiniRenderer := preload("res://scripts/hud/scoreboard_top_mini_renderer.gd")

var overlay_renderer: Object = ScoreboardOverlayRenderer.new()
var top_mini_renderer: Object = ScoreboardTopMiniRenderer.new()


func draw_top_mini(
	canvas: Node2D,
	game_offset: Vector2,
	game_size: Vector2,
	gameplay_width: float,
	player_score: int,
	boss_score: int,
	deuce_mode: bool,
	sparkle_timer: float,
	sparkle_duration: float,
	t: float,
	quality_scale: float = 1.0,
	stakes: Dictionary = {}
) -> void:
	top_mini_renderer.draw(
		canvas,
		game_offset,
		game_size,
		gameplay_width,
		player_score,
		boss_score,
		deuce_mode,
		sparkle_timer,
		sparkle_duration,
		t,
		quality_scale,
		stakes
	)


func draw_overlay(
	canvas: Node2D,
	hud_state,
	gameplay_width: float,
	gameplay_height: float,
	win_goal: int,
	fade_in_duration: float,
	draw_context: Dictionary = {},
	perf_logger: Object = null
) -> void:
	overlay_renderer.draw(
		canvas,
		hud_state,
		gameplay_width,
		gameplay_height,
		win_goal,
		fade_in_duration,
		draw_context,
		perf_logger
	)
