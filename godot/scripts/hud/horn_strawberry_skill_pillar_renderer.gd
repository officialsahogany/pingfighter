extends RefCounted

const SmasherSkillOrbRenderer := preload("res://scripts/hud/smasher_skill_orb_renderer.gd")

const SKILL_HORN_CHARGE := "horn_strawberry_horn_charge"
const SKILL_FIELD := "horn_strawberry_field"
const SKILL_EAT := "horn_strawberry_eat"
const SKILL_BOMB := "horn_strawberry_bomb"

const SKILL_ORDER := [
	SKILL_HORN_CHARGE,
	SKILL_FIELD,
	SKILL_EAT,
	SKILL_BOMB,
]

const SKILL_COSTS := {
	SKILL_HORN_CHARGE: 300.0,
	SKILL_FIELD: 100.0,
	SKILL_EAT: 50.0,
	SKILL_BOMB: 400.0,
}

const SKILL_COOLDOWNS := {
	SKILL_HORN_CHARGE: 20.0,
	SKILL_FIELD: 10.0,
	SKILL_EAT: 0.8,
	SKILL_BOMB: 30.0,
}

# Python-original HUD orb colors (pingfighter HORN_STRAWBERRY skill orbit data):
# 뿔박치기 (220,40,50) red / 딸기장판 (50,150,40) green / 딸기먹기 (240,220,100) yellow /
# 딸기폭탄 (255,80,40) orange.
const SKILL_COLORS := {
	SKILL_HORN_CHARGE: Color(220.0 / 255.0, 40.0 / 255.0, 50.0 / 255.0),
	SKILL_FIELD: Color(50.0 / 255.0, 150.0 / 255.0, 40.0 / 255.0),
	SKILL_EAT: Color(240.0 / 255.0, 220.0 / 255.0, 100.0 / 255.0),
	SKILL_BOMB: Color(255.0 / 255.0, 80.0 / 255.0, 40.0 / 255.0),
}

const SKILL_DATA := {
	SKILL_HORN_CHARGE: {
		"name": SKILL_HORN_CHARGE,
		"korean": "뿔박치기",
		"description": "앞으로 돌진해 보스를 기절시키고 강하게 밀쳐냅니다.",
		"how_to_use": "W를 누르면 뿔박치기를 사용합니다.",
		"motion_hint": "",
		"effect_type": "smash_orange",
		"cost": 300.0,
		"cooldown": 20.0,
		"color": Color(1.0, 0.28, 0.18),
	},
	SKILL_FIELD: {
		"name": SKILL_FIELD,
		"korean": "딸기장판",
		"description": "딸기 장막을 깔아 내려오는 공을 한 번 튕겨냅니다.",
		"how_to_use": "S를 1초 동안 누르고 있으면 장판을 펼칩니다.",
		"motion_hint": "",
		"effect_type": "shield_kiting_arc",
		"cost": 100.0,
		"cooldown": 10.0,
		"color": Color(0.95, 0.18, 0.30),
	},
	SKILL_EAT: {
		"name": SKILL_EAT,
		"korean": "딸기먹기",
		"description": "딸기를 먹어 패들을 키우고 꼭지를 세 갈래로 발사합니다.",
		"how_to_use": "Space 또는 클릭으로 딸기를 먹습니다.",
		"motion_hint": "",
		"effect_type": "projectile_cyan",
		"cost": 50.0,
		"cooldown": 0.8,
		"color": Color(0.28, 0.92, 0.34),
	},
	SKILL_BOMB: {
		"name": SKILL_BOMB,
		"korean": "딸기폭탄",
		"description": "폭탄 30개를 흩뿌리고 페인트 안의 보스를 느리게 합니다.",
		"how_to_use": "A와 D를 0.5초 동안 함께 누르면 폭탄을 던집니다.",
		"motion_hint": "",
		"effect_type": "firearm_trap",
		"cost": 400.0,
		"cooldown": 30.0,
		"color": Color(1.0, 0.58, 0.20),
	},
}

const HOLD_RING_SEGMENTS := 24

var fallback_orb_renderer: Object = SmasherSkillOrbRenderer.new()


func is_active(horn_context: Dictionary) -> bool:
	return bool(horn_context.get("transformed", false))


func build_skill_orb_context(
	horn_context: Dictionary,
	special_gauge: float,
	orb_drawer: Object,
	base_context: Dictionary = {}
) -> Dictionary:
	var cooldown_ratios: Dictionary = {}
	var ready_overrides: Dictionary = {}
	var progress_overrides: Dictionary = {}
	for skill_name in SKILL_ORDER:
		var skill_key: String = str(skill_name)
		var state_context: Dictionary = _get_skill_context(horn_context, skill_key)
		var cooldown_max: float = max(0.001, float(SKILL_COOLDOWNS.get(skill_key, 0.0)))
		var cooldown_sec: float = max(0.0, float(state_context.get("cooldown_sec", 0.0)))
		cooldown_ratios[skill_key] = clamp(cooldown_sec / cooldown_max, 0.0, 1.0)
		ready_overrides[skill_key] = _is_skill_ready(horn_context, skill_key, state_context, special_gauge, cooldown_sec)
		progress_overrides[skill_key] = _get_skill_progress(skill_key, state_context)

	return {
		"cluster_frame_texture": null,
		"cluster_frame_slots": 4,
		"skill_orb_frame_texture": base_context.get("skill_orb_frame_texture", null),
		"skill_icons": base_context.get("skill_icons", {}),
		"skill_state": null,
		"pillar_drawer": orb_drawer,
		"pillar_hud_static_lod": bool(base_context.get("pillar_hud_static_lod", false)),
		"special_gauge": special_gauge,
		"max_slots": 4,
		"equipped_skills": SKILL_ORDER.duplicate(),
		"skill_costs": SKILL_COSTS.duplicate(),
		"skill_colors": SKILL_COLORS.duplicate(),
		"cooldown_seconds": SKILL_COOLDOWNS.duplicate(),
		"skill_cooldown_remaining_ratios": cooldown_ratios,
		"skill_ready_overrides": ready_overrides,
		"skill_progress_overrides": progress_overrides,
		"skill_orb_radius": float(base_context.get("skill_orb_radius", 24.0)),
		"gauge_gap": float(base_context.get("gauge_gap", 28.0)),
		"socket_overlap": float(base_context.get("socket_overlap", 1.0)),
		"frame_safe_pad": float(base_context.get("frame_safe_pad", 8.0)),
		"slot_base_angle": 155.0,
		"slot_angle_step": 38.0,
		"cluster_source_size": base_context.get("cluster_source_size", Vector2(250.0, 650.0)),
		"cluster_gauge_center": base_context.get("cluster_gauge_center", Vector2(141.0, 559.0)),
		"orb_radius_base": float(base_context.get("orb_radius_base", 55.0)),
		"horn_strawberry_context": horn_context,
	}


func draw_underlay(canvas: CanvasItem, center: Vector2, orb_radius: float, scale_factor: float, context: Dictionary) -> void:
	fallback_orb_renderer.draw_underlay(canvas, center, orb_radius, scale_factor, context)


func draw_orbs(canvas: CanvasItem, center: Vector2, orb_radius: float, t: float, scale_factor: float, context: Dictionary) -> void:
	fallback_orb_renderer.draw_orbs(canvas, center, orb_radius, t, scale_factor, context)
	_draw_progress_rings(canvas, center, orb_radius, scale_factor, context)


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
	var positions: Array = get_slot_positions(left_center, orb_radius, scale_factor, skill_context)
	var icon_radius: float = float(skill_context.get("skill_orb_radius", 24.0)) * scale_factor
	var data_map: Dictionary = get_skill_data_map()
	var count: int = min(SKILL_ORDER.size(), positions.size())
	for i in range(count):
		var skill_name: String = str(SKILL_ORDER[i])
		if not data_map.has(skill_name):
			continue
		var slot_center: Vector2 = _as_vector2(positions[i], Vector2.ZERO)
		var rect := Rect2(slot_center - Vector2(icon_radius, icon_radius), Vector2(icon_radius * 2.0, icon_radius * 2.0))
		if rect.has_point(mouse_pos):
			var data: Dictionary = _get_dict(data_map.get(skill_name, {})).duplicate(true)
			data["slot_rect"] = rect
			return data
	return {}


func _draw_progress_rings(
	canvas: CanvasItem,
	center: Vector2,
	orb_radius: float,
	scale_factor: float,
	context: Dictionary
) -> void:
	var progress_map: Dictionary = _get_dict(context.get("skill_progress_overrides", {}))
	if progress_map.is_empty():
		return
	var positions: Array = get_slot_positions(center, orb_radius, scale_factor, context)
	var icon_radius: float = float(context.get("skill_orb_radius", 24.0)) * scale_factor
	var ring_radius: float = icon_radius + 5.0 * scale_factor
	var count: int = min(SKILL_ORDER.size(), positions.size())
	for i in range(count):
		var skill_name: String = str(SKILL_ORDER[i])
		var progress: float = clamp(float(progress_map.get(skill_name, 0.0)), 0.0, 1.0)
		if progress <= 0.0:
			continue
		var color: Color = _get_color(SKILL_COLORS.get(skill_name, Color.WHITE), Color.WHITE)
		var slot_center: Vector2 = _as_vector2(positions[i], Vector2.ZERO)
		canvas.draw_arc(
			slot_center,
			ring_radius,
			-PI * 0.5,
			-PI * 0.5 + TAU * progress,
			HOLD_RING_SEGMENTS,
			Color(color.r, color.g, color.b, 0.88),
			max(1.0, 3.0 * scale_factor),
			true
		)


func _get_skill_context(horn_context: Dictionary, skill_name: String) -> Dictionary:
	match skill_name:
		SKILL_HORN_CHARGE:
			return _get_dict(horn_context.get("horn_charge", {}))
		SKILL_FIELD:
			return _get_dict(horn_context.get("field", {}))
		SKILL_EAT:
			return _get_dict(horn_context.get("eat", {}))
		SKILL_BOMB:
			return _get_dict(horn_context.get("bomb", {}))
	return {}


func _is_skill_ready(
	horn_context: Dictionary,
	skill_name: String,
	state_context: Dictionary,
	special_gauge: float,
	cooldown_sec: float
) -> bool:
	if not is_active(horn_context):
		return false
	if special_gauge + 0.001 < float(SKILL_COSTS.get(skill_name, 0.0)):
		return false
	if cooldown_sec > 0.0:
		return false
	match skill_name:
		SKILL_HORN_CHARGE:
			return not bool(state_context.get("active", false)) and not _is_any_blocking_skill_active(horn_context, skill_name)
		SKILL_FIELD:
			return (
				not bool(state_context.get("holding", false))
				and int(state_context.get("barrier_count", 0)) <= 0
				and not _is_any_blocking_skill_active(horn_context, skill_name)
			)
		SKILL_EAT:
			return not bool(state_context.get("eating", false))
		SKILL_BOMB:
			return (
				not bool(state_context.get("holding", false))
				and not bool(state_context.get("throwing", false))
				and not _is_any_blocking_skill_active(horn_context, skill_name)
			)
	return false


func _is_any_blocking_skill_active(horn_context: Dictionary, ignored_skill: String) -> bool:
	var horn_charge: Dictionary = _get_dict(horn_context.get("horn_charge", {}))
	var eat: Dictionary = _get_dict(horn_context.get("eat", {}))
	var bomb: Dictionary = _get_dict(horn_context.get("bomb", {}))
	if ignored_skill != SKILL_HORN_CHARGE and bool(horn_charge.get("active", false)):
		return true
	if ignored_skill != SKILL_EAT and bool(eat.get("eating", false)):
		return true
	if ignored_skill != SKILL_BOMB and bool(bomb.get("throwing", false)):
		return true
	return false


func _get_skill_progress(skill_name: String, state_context: Dictionary) -> float:
	match skill_name:
		SKILL_HORN_CHARGE:
			if bool(state_context.get("active", false)):
				var phase_duration: float = max(0.001, float(state_context.get("phase_duration_sec", 0.0)))
				var phase_timer: float = clamp(float(state_context.get("phase_timer_sec", 0.0)), 0.0, phase_duration)
				return 1.0 - phase_timer / phase_duration
		SKILL_FIELD:
			if bool(state_context.get("holding", false)):
				return clamp(
					float(state_context.get("hold_timer_sec", 0.0)) / max(0.001, float(state_context.get("hold_min_sec", 1.0))),
					0.0,
					1.0
				)
		SKILL_EAT:
			if bool(state_context.get("eating", false)):
				var eat_duration: float = max(0.001, float(state_context.get("eat_duration_sec", 0.8)))
				var eat_timer: float = clamp(float(state_context.get("eat_timer_sec", 0.0)), 0.0, eat_duration)
				return 1.0 - eat_timer / eat_duration
		SKILL_BOMB:
			if bool(state_context.get("holding", false)):
				return clamp(
					float(state_context.get("hold_timer_sec", 0.0)) / max(0.001, float(state_context.get("hold_sec", 0.5))),
					0.0,
					1.0
				)
			if bool(state_context.get("throwing", false)):
				var throw_duration: float = max(0.001, float(state_context.get("throw_duration_sec", 1.0)))
				var throw_timer: float = clamp(float(state_context.get("throw_timer_sec", 0.0)), 0.0, throw_duration)
				return 1.0 - throw_timer / throw_duration
	return 0.0


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _get_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	return fallback


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
