extends RefCounted

const BallUpdateStaticConfig := preload("res://scripts/ball/ball_update_static_config.gd")

const PANEL_POS := Vector2(12.0, 16.0)
const PANEL_SIZE := Vector2(286.0, 100.0)
const FONT_SIZE := 16
const TITLE_SIZE := 17

var active := false
var static_config: Object = BallUpdateStaticConfig.new()


func toggle() -> void:
	active = not active


func close() -> void:
	active = false


func is_active() -> bool:
	return active


func draw(canvas: CanvasItem, owner: Object, _view_size: Vector2, registry: Object = null) -> void:
	if not active:
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return

	var ball_vel: Vector2 = _get_owner_vector2(owner, "ball_vel", Vector2.ZERO)
	var impact_boost: float = max(1.0, _get_owner_float(owner, "ball_impact_boost", 1.0))
	var smasher_wheel_speed_cap: float = _get_owner_float(owner, "smasher_wheel_speed_cap", 0.0)
	var rally_speed_cap_bonus: float = _get_owner_float(owner, "rally_speed_cap_bonus", 0.0)
	var base_speed: float = ball_vel.length()
	var effective_speed: float = base_speed * impact_boost
	var max_speed: float = _get_max_ball_speed(_is_power_smash_active(registry), impact_boost, _get_league_mode(owner), registry, smasher_wheel_speed_cap, rally_speed_cap_bonus)
	var ratio: float = 0.0 if max_speed <= 0.0 else effective_speed / max(0.001, max_speed)
	var state_text: String = "\uc774\ub3d9 \uc911" if bool(_get_owner_value(owner, "ball_active", false)) else "\uc11c\ube0c \ub300\uae30"
	var speed_color: Color = _speed_color(ratio)
	var max_speed_text: String = "\uc81c\ud55c \uc5c6\uc74c" if max_speed <= 0.0 else "%.0f" % max_speed

	var panel_rect := Rect2(PANEL_POS, PANEL_SIZE)
	canvas.draw_rect(panel_rect, Color(0.0, 0.0, 0.0, 0.72))
	canvas.draw_rect(panel_rect, Color(0.26, 0.82, 0.95, 0.62), false, 1.0)

	_draw_text(canvas, font, PANEL_POS + Vector2(12.0, 24.0), "\uacf5\uc18d\ub3c4 DEBUG (F9)", TITLE_SIZE, Color(0.47, 0.94, 1.0))
	_draw_text(canvas, font, PANEL_POS + Vector2(12.0, 46.0), "\uc2e4\uc18d\ub3c4 %.2f / %s" % [effective_speed, max_speed_text], FONT_SIZE, speed_color)
	_draw_text(canvas, font, PANEL_POS + Vector2(12.0, 66.0), "\uae30\ubcf8 %.2f  \ubd80\uc2a4\ud2b8 x%.2f" % [base_speed, impact_boost], FONT_SIZE, Color(0.88, 0.88, 0.88))
	_draw_text(canvas, font, PANEL_POS + Vector2(12.0, 86.0), "vx %.2f  vy %.2f  %s" % [ball_vel.x, ball_vel.y, state_text], FONT_SIZE, Color(0.74, 0.84, 1.0))

	var bar_rect := Rect2(PANEL_POS + Vector2(12.0, PANEL_SIZE.y - 8.0), Vector2(PANEL_SIZE.x - 24.0, 3.0))
	canvas.draw_rect(bar_rect, Color(0.08, 0.14, 0.18, 0.95))
	canvas.draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * clamp(ratio, 0.0, 1.0), bar_rect.size.y)), speed_color)


func _draw_text(canvas: CanvasItem, font: Font, baseline: Vector2, text: String, font_size: int, color: Color) -> void:
	canvas.draw_string_outline(font, baseline + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 2, Color(0.0, 0.0, 0.0, 0.85))
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _speed_color(ratio: float) -> Color:
	if ratio >= 0.98:
		return Color(1.0, 0.42, 0.42)
	if ratio >= 0.82:
		return Color(1.0, 0.86, 0.34)
	return Color(0.48, 1.0, 0.62)


func _get_max_ball_speed(
	power_smash_active: bool = false,
	impact_boost: float = 1.0,
	league_mode: String = "champion",
	registry: Object = null,
	smasher_wheel_speed_cap: float = 0.0,
	rally_speed_cap_bonus: float = 0.0
) -> float:
	var update_config: Dictionary = static_config.build_update_config()
	if power_smash_active:
		return max(
			float(update_config.get("power_smash_max_ball_speed", 35.0)),
			max(0.0, smasher_wheel_speed_cap),
			_get_magnum_grip_speed_cap(registry),
			_get_viper_blade_speed_cap(registry)
		)
	var speed_cap: float = float(update_config.get("mythic_max_ball_speed", 32.0)) if league_mode == "mythic" else float(update_config.get("max_ball_speed", 26.0))
	if impact_boost > 1.001 and league_mode != "mythic":
		speed_cap = max(speed_cap, float(update_config.get("impact_boost_max_ball_speed", 26.0)))
	speed_cap += clamp(rally_speed_cap_bonus, 0.0, float(update_config.get("rally_speed_cap_bonus_max", 10.0)))
	speed_cap = max(speed_cap, max(0.0, smasher_wheel_speed_cap))
	speed_cap = max(speed_cap, _get_magnum_grip_speed_cap(registry))
	speed_cap = max(speed_cap, _get_viper_blade_speed_cap(registry))
	return speed_cap


func _get_league_mode(owner: Object) -> String:
	return str(_get_owner_value(owner, "ai_mode", "champion"))


func _is_power_smash_active(registry: Object) -> bool:
	if registry == null or not registry.has_method("get_instance"):
		return false
	var power_state: Object = registry.get_instance("smasher_power_smash_state")
	if power_state == null or not power_state.has_method("is_parabola_active"):
		return false
	return bool(power_state.is_parabola_active())


func _get_owner_vector2(owner: Object, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = _get_owner_value(owner, key, fallback)
	if value is Vector2:
		return value
	return fallback


func _get_owner_float(owner: Object, key: String, fallback: float) -> float:
	var value: Variant = _get_owner_value(owner, key, fallback)
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	return fallback


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	if owner == null:
		return fallback
	var value: Variant = owner.get(key)
	if value == null:
		return fallback
	return value


func _get_magnum_grip_speed_cap(registry: Object) -> float:
	if registry == null or not registry.has_method("get_instance"):
		return 0.0
	var magnum_state: Object = registry.get_instance("smasher_magnum_grip_state")
	if magnum_state == null:
		return 0.0
	var cap := 0.0
	if magnum_state.has_method("get_release_hit_speed_cap"):
		cap = max(cap, float(magnum_state.get_release_hit_speed_cap()))
	if magnum_state.has_method("get_pending_release_hit_speed_cap"):
		cap = max(cap, float(magnum_state.get_pending_release_hit_speed_cap()))
	return cap


func _get_viper_blade_speed_cap(registry: Object) -> float:
	if registry == null or not registry.has_method("get_instance"):
		return 0.0
	var viper_skill_runtime: Object = registry.get_instance("viper_skill_runtime")
	if viper_skill_runtime == null or not viper_skill_runtime.has_method("get_blade_hit_speed_cap"):
		return 0.0
	return float(viper_skill_runtime.get_blade_hit_speed_cap())
