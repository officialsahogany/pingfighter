extends RefCounted

const SmasherSkillOrbCooldownRenderer := preload("res://scripts/hud/smasher_skill_orb_cooldown_renderer.gd")
const SmasherSkillOrbSocketRenderer := preload("res://scripts/hud/smasher_skill_orb_socket_renderer.gd")
const SmasherSkillOrbSymbolRenderer := preload("res://scripts/hud/smasher_skill_orb_symbol_renderer.gd")

var cooldown_renderer: Object = SmasherSkillOrbCooldownRenderer.new()
var socket_renderer: Object = SmasherSkillOrbSocketRenderer.new()
var symbol_renderer: Object = SmasherSkillOrbSymbolRenderer.new()


func draw(
	canvas: CanvasItem,
	_center: Vector2,
	icon_radius: float,
	positions: Array[Vector2],
	t: float,
	scale_factor: float,
	context: Dictionary
) -> void:
	var equipped_skills: Array = context.get("equipped_skills", [])
	var equipped_count: int = min(equipped_skills.size(), positions.size())
	var socket_overlap: float = float(context.get("socket_overlap", 1.0))

	for slot_idx in range(positions.size()):
		if slot_idx < equipped_count:
			continue
		socket_renderer.draw_socket(
			canvas,
			positions[slot_idx],
			icon_radius,
			socket_overlap,
			Color(40.0 / 255.0, 40.0 / 255.0, 45.0 / 255.0, 180.0 / 255.0),
			Color(60.0 / 255.0, 60.0 / 255.0, 65.0 / 255.0, 200.0 / 255.0)
		)

	var time_now: int = Time.get_ticks_msec()
	var special_gauge: float = float(context.get("special_gauge", 0.0))
	var skill_costs: Dictionary = context.get("skill_costs", {})
	var skill_colors: Dictionary = context.get("skill_colors", {})
	var skill_icons: Dictionary = context.get("skill_icons", {})
	var skill_state: Object = context.get("skill_state", null)
	var cooldown_seconds: Dictionary = context.get("cooldown_seconds", {})
	var pillar_drawer: Object = context.get("pillar_drawer", null)

	for i in range(equipped_count):
		var skill_name: String = str(equipped_skills[i])
		var slot_pos: Vector2 = positions[i]
		var skill_color: Color = skill_colors.get(skill_name, Color.WHITE)
		var cooldown_ratio: float = _get_cooldown_remaining(skill_state, skill_name, time_now, cooldown_seconds)
		var is_on_cooldown: bool = cooldown_ratio > 0.0
		var is_active: bool = special_gauge >= float(skill_costs.get(skill_name, 0.0)) and not is_on_cooldown

		var activation_elapsed: int = _update_activation_state(skill_state, skill_name, is_active, time_now)
		var symbol_animate: bool = is_active and activation_elapsed < 400
		if symbol_animate:
			var progress: float = float(activation_elapsed) / 400.0
			socket_renderer.draw_activation_flash(canvas, slot_pos, icon_radius, scale_factor, progress, skill_color)

		var bg_color: Color
		var border_color: Color
		if is_active:
			bg_color = Color(skill_color.r, skill_color.g, skill_color.b, 200.0 / 255.0)
			border_color = Color.WHITE
		else:
			bg_color = Color(skill_color.r / 3.0, skill_color.g / 3.0, skill_color.b / 3.0, 150.0 / 255.0)
			border_color = Color(80.0 / 255.0, 80.0 / 255.0, 80.0 / 255.0, 180.0 / 255.0)
		socket_renderer.draw_socket(canvas, slot_pos, icon_radius, socket_overlap, bg_color, border_color)

		if is_active and not is_on_cooldown:
			socket_renderer.draw_ready_ring(canvas, slot_pos, icon_radius + socket_overlap * scale_factor, t, float(i) * 0.6, skill_color)

		var icon_texture: Variant = skill_icons.get(skill_name, null)
		var icon_size: float = icon_radius * 2.0 + 2.0 * scale_factor
		var icon_rect: Rect2 = Rect2(slot_pos - Vector2(icon_size, icon_size) * 0.5, Vector2(icon_size, icon_size))
		if icon_texture is Texture2D:
			var modulate: Color = Color.WHITE if is_active else Color(0.45, 0.45, 0.45, 0.78)
			var texture: Texture2D = icon_texture
			canvas.draw_texture_rect(texture, icon_rect, false, modulate)
		else:
			symbol_renderer.draw(canvas, slot_pos, icon_radius, skill_name, skill_color, is_active)

		if is_on_cooldown:
			cooldown_renderer.draw(canvas, slot_pos, icon_radius + socket_overlap * scale_factor, cooldown_ratio, pillar_drawer)


func _get_cooldown_remaining(skill_state: Object, skill_name: String, time_now: int, cooldown_seconds: Dictionary) -> float:
	if skill_state != null and skill_state.has_method("get_cooldown_remaining"):
		return skill_state.get_cooldown_remaining(skill_name, time_now, float(cooldown_seconds.get(skill_name, 0.0)))
	return 0.0


func _update_activation_state(skill_state: Object, skill_name: String, is_active: bool, time_now: int) -> int:
	if skill_state != null and skill_state.has_method("update_activation_state"):
		return int(skill_state.update_activation_state(skill_name, is_active, time_now))
	return 100000
