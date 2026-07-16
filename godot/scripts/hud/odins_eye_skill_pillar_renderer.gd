extends RefCounted

const SmasherSkillOrbRenderer := preload("res://scripts/hud/smasher_skill_orb_renderer.gd")
const SmasherSkillOrbCooldownRenderer := preload("res://scripts/hud/smasher_skill_orb_cooldown_renderer.gd")

const SKILL_DARK_SWAMP := "odins_eye_dark_swamp"
const SKILL_ORDER := [SKILL_DARK_SWAMP]
const SKILL_COST := 100.0
const SKILL_COOLDOWN_SEC := 2.0
const SKILL_COOLDOWN_FRAMES := 120.0
const SKILL_COLOR := Color(0.42, 0.16, 0.68)
const SKILL_COSTS := {SKILL_DARK_SWAMP: SKILL_COST}
const SKILL_COOLDOWNS := {SKILL_DARK_SWAMP: SKILL_COOLDOWN_SEC}
const SKILL_COLORS := {SKILL_DARK_SWAMP: SKILL_COLOR}
const SKILL_DATA := {
	SKILL_DARK_SWAMP: {
		"name": SKILL_DARK_SWAMP,
		"korean": "어둠의 늪",
		"description": "플레이어에서 보스 방향으로 어둠의 수정 가시 12개를 연쇄 소환합니다.\n가시는 공을 위로 튕기고 보스를 밀쳐내며 기절시킵니다.",
		"how_to_use": "오딘의 눈 변신 중 좌클릭(게임패드 주버튼, 모바일 ACCEPT)으로 발동합니다.",
		"motion_hint": "플레이어에서 보스까지 솟아나는 12연속 어둠 가시",
		"effect_type": "odins_eye_dark_swamp",
		"preview_type": "spike_wave",
		"preview_metadata": {
			"family": "odins_eye",
			"scene": "player_to_boss_spike_wave",
			"input": "left_mouse",
			"spike_count": 12,
			"ball_response": "upward_reflect",
			"boss_effects": ["knockback", "stun"],
		},
		"cost": SKILL_COST,
		"cooldown": SKILL_COOLDOWN_SEC,
		"color": SKILL_COLOR,
	},
}

const ACTIVE_RING_SEGMENTS := 28

var fallback_orb_renderer: Object = SmasherSkillOrbRenderer.new()
var cooldown_renderer: Object = SmasherSkillOrbCooldownRenderer.new()


func is_active(odins_eye_context: Dictionary) -> bool:
	return bool(odins_eye_context.get("transformed", false))


func build_skill_orb_context(
	odins_eye_context: Dictionary,
	special_gauge: float,
	orb_drawer: Object,
	base_context: Dictionary = {}
) -> Dictionary:
	var dark_swamp_context: Dictionary = _get_dict(odins_eye_context.get("dark_swamp", {}))
	var cooldown_ratio: float = _get_cooldown_ratio(dark_swamp_context)
	var ready: bool = _is_skill_ready(odins_eye_context, dark_swamp_context, special_gauge, cooldown_ratio)
	var active: bool = bool(dark_swamp_context.get("active", false))
	return {
		"cluster_frame_texture": null,
		"cluster_frame_slots": 1,
		"skill_orb_frame_texture": base_context.get("skill_orb_frame_texture", null),
		"skill_icons": base_context.get("skill_icons", {}),
		"skill_state": null,
		"pillar_drawer": orb_drawer,
		"pillar_hud_static_lod": bool(base_context.get("pillar_hud_static_lod", false)),
		"special_gauge": special_gauge,
		"max_slots": 1,
		"equipped_skills": SKILL_ORDER.duplicate(),
		"skill_costs": SKILL_COSTS.duplicate(),
		"skill_colors": SKILL_COLORS.duplicate(),
		"cooldown_seconds": SKILL_COOLDOWNS.duplicate(),
		"skill_cooldown_remaining_ratios": {SKILL_DARK_SWAMP: cooldown_ratio},
		"skill_ready_overrides": {SKILL_DARK_SWAMP: ready},
		"skill_active_overrides": {SKILL_DARK_SWAMP: active},
		"skill_orb_radius": float(base_context.get("skill_orb_radius", 24.0)),
		"gauge_gap": float(base_context.get("gauge_gap", 28.0)),
		"socket_overlap": float(base_context.get("socket_overlap", 1.0)),
		"frame_safe_pad": float(base_context.get("frame_safe_pad", 8.0)),
		"slot_base_angle": 180.0,
		"slot_angle_step": 0.0,
		"cluster_source_size": base_context.get("cluster_source_size", Vector2(250.0, 650.0)),
		"cluster_gauge_center": base_context.get("cluster_gauge_center", Vector2(141.0, 559.0)),
		"orb_radius_base": float(base_context.get("orb_radius_base", 55.0)),
		"odins_eye_context": odins_eye_context,
		"odins_eye_dark_swamp_context": dark_swamp_context,
	}


func draw_underlay(canvas: CanvasItem, center: Vector2, orb_radius: float, scale_factor: float, context: Dictionary) -> void:
	fallback_orb_renderer.draw_underlay(canvas, center, orb_radius, scale_factor, context)


func draw_orbs(canvas: CanvasItem, center: Vector2, orb_radius: float, t: float, scale_factor: float, context: Dictionary) -> void:
	fallback_orb_renderer.draw_orbs(canvas, center, orb_radius, t, scale_factor, context)
	if canvas == null:
		return
	var positions: Array[Vector2] = get_slot_positions(center, orb_radius, scale_factor, context)
	if positions.is_empty():
		return
	var icon_radius: float = float(context.get("skill_orb_radius", 24.0)) * scale_factor
	if icon_radius <= 0.0:
		return
	var ready_overrides: Dictionary = _get_dict(context.get("skill_ready_overrides", {}))
	var active_overrides: Dictionary = _get_dict(context.get("skill_active_overrides", {}))
	var is_ready: bool = bool(ready_overrides.get(SKILL_DARK_SWAMP, false))
	var is_skill_active: bool = bool(active_overrides.get(SKILL_DARK_SWAMP, false))
	var icons: Dictionary = _get_dict(context.get("skill_icons", {}))
	if not icons.has(SKILL_DARK_SWAMP):
		_draw_dark_swamp_symbol(canvas, positions[0], icon_radius, is_ready, is_skill_active)
		_redraw_cooldown_overlay(canvas, positions[0], icon_radius, scale_factor, context)
	_draw_active_ring(canvas, positions[0], icon_radius, t, scale_factor, context, is_skill_active)


func get_slot_positions(center: Vector2, orb_radius: float, scale_factor: float, context: Dictionary) -> Array[Vector2]:
	return fallback_orb_renderer.get_slot_positions(center, orb_radius, scale_factor, context)


func get_cluster_bounds(center: Vector2, orb_radius: float, scale_factor: float, context: Dictionary) -> Rect2:
	return fallback_orb_renderer.get_cluster_bounds(center, orb_radius, scale_factor, context)


func get_skill_data_map() -> Dictionary:
	return SKILL_DATA.duplicate(true)


func get_skill_order() -> Array:
	return SKILL_ORDER.duplicate()


func find_hovered_skill(
	mouse_pos: Vector2,
	left_center: Vector2,
	orb_radius: float,
	scale_factor: float,
	skill_context: Dictionary
) -> Dictionary:
	var positions: Array[Vector2] = get_slot_positions(left_center, orb_radius, scale_factor, skill_context)
	if positions.is_empty():
		return {}
	var icon_radius: float = float(skill_context.get("skill_orb_radius", 24.0)) * scale_factor
	var slot_center: Vector2 = positions[0]
	var slot_rect := Rect2(
		slot_center - Vector2(icon_radius, icon_radius),
		Vector2(icon_radius * 2.0, icon_radius * 2.0)
	)
	if not slot_rect.has_point(mouse_pos):
		return {}
	var data: Dictionary = _get_dict(SKILL_DATA.get(SKILL_DARK_SWAMP, {})).duplicate(true)
	data["slot_rect"] = slot_rect
	return data


func _is_skill_ready(
	odins_eye_context: Dictionary,
	dark_swamp_context: Dictionary,
	special_gauge: float,
	cooldown_ratio: float
) -> bool:
	if not is_active(odins_eye_context):
		return false
	if not bool(dark_swamp_context.get("enabled", false)):
		return false
	if bool(odins_eye_context.get("revival_animation_active", false)):
		return false
	if bool(odins_eye_context.get("death_animation_active", false)):
		return false
	if bool(dark_swamp_context.get("active", false)):
		return false
	var cooldown_remaining_frames: float = max(0.0, float(dark_swamp_context.get("cooldown_remaining_frames", 0.0)))
	if cooldown_remaining_frames > 0.0 or cooldown_ratio > 0.0:
		return false
	return special_gauge + 0.001 >= SKILL_COST


func _get_cooldown_ratio(dark_swamp_context: Dictionary) -> float:
	if dark_swamp_context.has("cooldown_ratio"):
		return clamp(float(dark_swamp_context.get("cooldown_ratio", 0.0)), 0.0, 1.0)
	var remaining_frames: float = max(0.0, float(dark_swamp_context.get("cooldown_remaining_frames", 0.0)))
	return clamp(remaining_frames / SKILL_COOLDOWN_FRAMES, 0.0, 1.0)


func _draw_dark_swamp_symbol(
	canvas: CanvasItem,
	center: Vector2,
	icon_radius: float,
	is_ready: bool,
	is_skill_active: bool
) -> void:
	var alpha: float = 1.0 if is_ready or is_skill_active else 0.52
	var shadow_color := Color(0.05, 0.01, 0.09, 0.82 * alpha)
	var crystal_color := Color(0.48, 0.16, 0.72, 0.96 * alpha)
	var highlight_color := Color(0.82, 0.54, 1.0, 0.94 * alpha)
	var floor_y: float = center.y + icon_radius * 0.28
	canvas.draw_arc(center + Vector2(0.0, icon_radius * 0.12), icon_radius * 0.52, 0.08 * PI, 0.92 * PI, 14, shadow_color, max(1.0, icon_radius * 0.12), true)
	_draw_crystal_spike(canvas, Vector2(center.x - icon_radius * 0.36, floor_y), icon_radius * 0.30, icon_radius * 0.52, crystal_color, highlight_color)
	_draw_crystal_spike(canvas, Vector2(center.x, floor_y + icon_radius * 0.02), icon_radius * 0.38, icon_radius * 0.78, crystal_color, highlight_color)
	_draw_crystal_spike(canvas, Vector2(center.x + icon_radius * 0.36, floor_y), icon_radius * 0.28, icon_radius * 0.48, crystal_color, highlight_color)
	_draw_left_mouse_marker(canvas, center + Vector2(icon_radius * 0.40, icon_radius * 0.42), icon_radius, alpha)


func _draw_crystal_spike(
	canvas: CanvasItem,
	base_center: Vector2,
	width: float,
	height: float,
	fill_color: Color,
	highlight_color: Color
) -> void:
	if width <= 0.0 or height <= 0.0:
		return
	var left := base_center + Vector2(-width * 0.5, 0.0)
	var tip := base_center + Vector2(0.0, -height)
	var right := base_center + Vector2(width * 0.5, 0.0)
	canvas.draw_colored_polygon(PackedVector2Array([left, tip, right]), fill_color)
	canvas.draw_line(tip, base_center + Vector2(width * 0.12, -height * 0.18), highlight_color, max(1.0, width * 0.13), true)


func _draw_left_mouse_marker(canvas: CanvasItem, center: Vector2, icon_radius: float, alpha: float) -> void:
	var marker_size := Vector2(max(5.0, icon_radius * 0.30), max(7.0, icon_radius * 0.38))
	var marker_rect := Rect2(center - marker_size * 0.5, marker_size)
	var outline := Color(0.93, 0.84, 1.0, 0.88 * alpha)
	canvas.draw_rect(marker_rect, Color(0.08, 0.02, 0.13, 0.82 * alpha), true)
	canvas.draw_rect(marker_rect, outline, false, max(1.0, icon_radius * 0.055))
	canvas.draw_line(Vector2(center.x, marker_rect.position.y), Vector2(center.x, center.y), outline, max(1.0, icon_radius * 0.045))
	canvas.draw_rect(Rect2(marker_rect.position, Vector2(marker_size.x * 0.5, marker_size.y * 0.42)), Color(0.72, 0.38, 0.96, 0.92 * alpha), true)


func _redraw_cooldown_overlay(
	canvas: CanvasItem,
	center: Vector2,
	icon_radius: float,
	scale_factor: float,
	context: Dictionary
) -> void:
	var cooldown_ratios: Dictionary = _get_dict(context.get("skill_cooldown_remaining_ratios", {}))
	var cooldown_ratio: float = clamp(float(cooldown_ratios.get(SKILL_DARK_SWAMP, 0.0)), 0.0, 1.0)
	if cooldown_ratio <= 0.0:
		return
	cooldown_renderer.draw(
		canvas,
		center,
		icon_radius + float(context.get("socket_overlap", 1.0)) * scale_factor,
		cooldown_ratio,
		context.get("pillar_drawer", null),
		bool(context.get("pillar_hud_static_lod", false))
	)


func _draw_active_ring(
	canvas: CanvasItem,
	center: Vector2,
	icon_radius: float,
	t: float,
	scale_factor: float,
	context: Dictionary,
	is_skill_active: bool
) -> void:
	if not is_skill_active:
		return
	var static_hud_lod: bool = bool(context.get("pillar_hud_static_lod", false))
	var pulse: float = 0.5 if static_hud_lod else 0.5 + 0.5 * sin(t * 7.0)
	var ring_radius: float = icon_radius + (4.0 + pulse * 2.0) * scale_factor
	canvas.draw_arc(
		center,
		ring_radius,
		0.0,
		TAU,
		ACTIVE_RING_SEGMENTS,
		Color(0.72, 0.35, 1.0, 0.62 + pulse * 0.24),
		max(1.0, (2.0 + pulse) * scale_factor),
		true
	)


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
