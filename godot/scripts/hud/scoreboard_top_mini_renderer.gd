extends RefCounted

const ScoreboardTopMiniDeuceRenderer := preload("res://scripts/hud/scoreboard_top_mini_deuce_renderer.gd")
const ScoreboardTopMiniNormalRenderer := preload("res://scripts/hud/scoreboard_top_mini_normal_renderer.gd")

var deuce_renderer: Object = ScoreboardTopMiniDeuceRenderer.new()
var normal_renderer: Object = ScoreboardTopMiniNormalRenderer.new()


func draw(
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
	if canvas == null or game_offset.y < 20.0:
		return

	var scale_factor: float = game_size.x / gameplay_width
	var box_width: float = max(96.0, floor(146.0 * scale_factor))
	var box_height: float = max(30.0, floor(38.0 * scale_factor))
	var box_rect := Rect2(
		game_offset.x + (game_size.x - box_width) * 0.5,
		max(2.0, (game_offset.y - box_height) * 0.5),
		box_width,
		box_height
	)

	var sparkle_progress := 0.0
	var sparkle_intensity := 0.0
	if sparkle_timer > 0.0:
		sparkle_progress = clamp(
			1.0 - sparkle_timer / max(0.001, sparkle_duration),
			0.0,
			1.0
		)
		sparkle_intensity = sin(sparkle_progress * PI)

	var is_deuce := deuce_mode or (player_score >= 4 and boss_score >= 4 and player_score == boss_score)
	if is_deuce:
		deuce_renderer.draw(canvas, box_rect, scale_factor, t, sparkle_intensity, player_score, boss_score, quality_scale, stakes)
	else:
		normal_renderer.draw(canvas, box_rect, scale_factor, sparkle_progress, sparkle_intensity, player_score, boss_score, quality_scale, stakes)
