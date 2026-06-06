extends RefCounted

const BallIntensityPalette := preload("res://scripts/ball/ball_intensity_palette.gd")

const INTENSITY_TRANSITION_SPEED := 0.033
const RALLY_TIER_1_EXCHANGES := 5
const RALLY_TIER_2_EXCHANGES := 10
const RALLY_TIER_3_EXCHANGES := 15
const RALLY_TIER_4_EXCHANGES := 25
const RALLY_TIER_5_EXCHANGES := 35
const STAKES_DEUCE_BONUS := 0.08
const STAKES_MATCH_POINT_BONUS := 0.15

var rally_count := 0
var contact_count := 0
var last_hit_by := ""
var last_hit_actor := ""
var last_contact_tags: Dictionary = {}
var rally_tier_advanced := false
var display_level := 0.0
var target_level := 0
var raw_contact_intensity := 0.0
var stakes_deuce_mode := false
var stakes_player_can_win := false
var stakes_boss_can_win := false
var current_display_colors: Array[Color] = [
	Color(100.0 / 255.0, 180.0 / 255.0, 1.0),
	Color(80.0 / 255.0, 160.0 / 255.0, 1.0),
	Color(60.0 / 255.0, 140.0 / 255.0, 1.0),
]
var current_glow_color := Color(60.0 / 255.0, 100.0 / 255.0, 180.0 / 255.0, 30.0 / 255.0)
var palette: Object = BallIntensityPalette.new()


func reset() -> void:
	rally_count = 0
	contact_count = 0
	last_hit_by = ""
	last_hit_actor = ""
	last_contact_tags.clear()
	rally_tier_advanced = false
	display_level = 0.0
	target_level = 0
	raw_contact_intensity = 0.0
	stakes_deuce_mode = false
	stakes_player_can_win = false
	stakes_boss_can_win = false
	current_display_colors = get_palette(0)
	current_glow_color = get_glow_color(0)


func register_hit(hit_by: String) -> void:
	register_contact(hit_by, hit_by)


func register_contact(actor_id: String, side: String, tags: Dictionary = {}) -> void:
	var normalized_actor := actor_id.strip_edges()
	var normalized_side := side.strip_edges()
	if normalized_side == "":
		normalized_side = normalized_actor
	if normalized_actor == "":
		normalized_actor = normalized_side
	var previous_tier := get_rally_tier()
	contact_count += 1
	if last_hit_by != "" and last_hit_by != normalized_side:
		rally_count += 1
	last_hit_by = normalized_side
	last_hit_actor = normalized_actor
	last_contact_tags = tags.duplicate(true)
	rally_tier_advanced = get_rally_tier() > previous_tier


func calculate(ball_velocity: Vector2) -> float:
	var current_speed: float = ball_velocity.length()
	var speed_level := 0
	if current_speed >= 35.0:
		speed_level = 5
	elif current_speed >= 28.0:
		speed_level = 4
	elif current_speed >= 22.0:
		speed_level = 3
	elif current_speed >= 16.0:
		speed_level = 2
	elif current_speed >= 12.0:
		speed_level = 1

	var rally_bonus: float = min(float(rally_count) * 0.1, 0.5)
	return min(1.0, float(speed_level) / 5.0 + rally_bonus)


func update_transition(ball_velocity: Vector2, fps_scale: float) -> void:
	var intensity: float = calculate(ball_velocity)
	raw_contact_intensity = intensity
	target_level = min(5, int(intensity * 5.0))
	var step: float = INTENSITY_TRANSITION_SPEED * fps_scale
	if display_level < float(target_level):
		display_level = min(float(target_level), display_level + step)
	elif display_level > float(target_level):
		display_level = max(float(target_level), display_level - step)

	var current_level: int = int(display_level)
	var next_level: int = min(5, current_level + 1)
	var blend_factor: float = display_level - float(current_level)
	current_display_colors = palette.blend_palette(current_level, next_level, blend_factor)
	current_glow_color = palette.blend_glow_color(current_level, next_level, blend_factor)


func get_palette(level: int) -> Array[Color]:
	return palette.get_palette(level)


func get_glow_color(level: int) -> Color:
	return palette.get_glow_color(level)


func get_current_colors() -> Array[Color]:
	return current_display_colors.duplicate()


func get_current_glow_color() -> Color:
	return current_glow_color


func get_rally_count() -> int:
	return rally_count


func get_rally_exchange_count() -> int:
	return rally_count


func get_rally_contact_count() -> int:
	return contact_count


func get_rally_tier() -> int:
	if rally_count >= RALLY_TIER_5_EXCHANGES:
		return 5
	if rally_count >= RALLY_TIER_4_EXCHANGES:
		return 4
	if rally_count >= RALLY_TIER_3_EXCHANGES:
		return 3
	if rally_count >= RALLY_TIER_2_EXCHANGES:
		return 2
	if rally_count >= RALLY_TIER_1_EXCHANGES:
		return 1
	return 0


func did_rally_tier_advance() -> bool:
	return rally_tier_advanced


func get_last_hit_by() -> String:
	return last_hit_by


func get_last_hit_side() -> String:
	return last_hit_by


func get_last_hit_actor() -> String:
	return last_hit_actor


func get_last_contact_tags() -> Dictionary:
	return last_contact_tags.duplicate(true)


func get_display_level() -> float:
	return display_level


func get_display_intensity() -> float:
	return clampf(display_level / 5.0, 0.0, 1.0)


func get_raw_contact_intensity() -> float:
	return raw_contact_intensity


func get_theater_intensity() -> float:
	var tier_bonus: float = float(get_rally_tier()) * 0.08
	return clampf(get_display_intensity() + tier_bonus + get_stakes_intensity_bonus(), 0.0, 1.0)


func set_stakes(deuce_mode: bool, player_can_win: bool, boss_can_win: bool) -> void:
	stakes_deuce_mode = deuce_mode
	stakes_player_can_win = player_can_win
	stakes_boss_can_win = boss_can_win


func get_stakes_intensity_bonus() -> float:
	var bonus := 0.0
	if stakes_deuce_mode:
		bonus += STAKES_DEUCE_BONUS
	if stakes_player_can_win or stakes_boss_can_win:
		bonus += STAKES_MATCH_POINT_BONUS
	return bonus


func get_stakes() -> Dictionary:
	return {
		"deuce_mode": stakes_deuce_mode,
		"player_can_win": stakes_player_can_win,
		"boss_can_win": stakes_boss_can_win,
	}


func get_target_level() -> int:
	return target_level
