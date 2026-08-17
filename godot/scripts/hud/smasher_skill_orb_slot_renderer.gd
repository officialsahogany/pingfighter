extends RefCounted

const SmasherSkillOrbCooldownRenderer := preload("res://scripts/hud/smasher_skill_orb_cooldown_renderer.gd")
const SmasherSkillOrbSocketRenderer := preload("res://scripts/hud/smasher_skill_orb_socket_renderer.gd")
const SmasherSkillOrbSymbolRenderer := preload("res://scripts/hud/smasher_skill_orb_symbol_renderer.gd")
const SOUL_SUMMON_ART_ID := "soul_summon_art"
const SOUL_SUMMON_ART_ICON: Texture2D = preload(
	"res://assets/sprites/skills/soul_summon_art_skill_orb_imagegen_v1.png"
)
const DALJI_VISION_CHAIN_TOP_ID := "dalji_vision_chain_top"
const DALJI_VISION_CHAIN_TOP_ICON: Texture2D = preload(
	"res://assets/sprites/skills/dalji_vision_chain_top_skill_orb_imagegen_v1.png"
)
const CHEONGRINGWI_VISION_DRAGON_TORRENT_ID := "cheongringwi_vision_dragon_torrent"
const CHEONGRINGWI_VISION_DRAGON_TORRENT_ICON: Texture2D = preload(
	"res://assets/sprites/skills/cheongringwi_vision_earth_vein_quake_skill_orb_imagegen_v1.png"
)
const YEONMYO_VISION_BONGHONGWE_ID := "yeonmyo_vision_bonghongwe"
const YEONMYO_VISION_BONGHONGWE_ICON: Texture2D = preload(
	"res://assets/sprites/skills/yeonmyo_vision_bonghongwe_skill_orb_imagegen_v1.png"
)

const TEXTURE_ORB_EDGE_FILL_EXTRA := 2.0
const TEXTURE_ORB_Y_NUDGE := -1.0

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
	var static_hud_lod := bool(context.get("pillar_hud_static_lod", false))

	for i in range(equipped_count):
		var skill_name: String = str(equipped_skills[i])
		var slot_pos: Vector2 = positions[i]
		var skill_color: Color = skill_colors.get(skill_name, Color.WHITE)
		var cooldown_ratio: float = _get_cooldown_remaining(skill_state, skill_name, time_now, cooldown_seconds, context)
		var is_on_cooldown: bool = cooldown_ratio > 0.0
		var is_active: bool = (
			special_gauge >= float(skill_costs.get(skill_name, 0.0))
			and not is_on_cooldown
			and _is_activation_condition_met(skill_name, context)
		)

		var activation_elapsed: int = _update_activation_state(skill_state, skill_name, is_active, time_now)
		var symbol_animate: bool = is_active and activation_elapsed < 400 and not static_hud_lod
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

		if is_active and not is_on_cooldown and not static_hud_lod:
			socket_renderer.draw_ready_ring(canvas, slot_pos, icon_radius + socket_overlap * scale_factor, t, float(i) * 0.6, skill_color)

		var icon_texture: Texture2D = _resolve_skill_icon_texture(skill_name, skill_icons)
		var icon_size: float = icon_radius * 2.0 + 2.0 * scale_factor
		if icon_texture != null:
			var modulate: Color = Color.WHITE if is_active else Color(0.45, 0.45, 0.45, 0.78)
			var texture_size: float = icon_size + TEXTURE_ORB_EDGE_FILL_EXTRA * scale_factor
			var texture_rect := Rect2(
				slot_pos - Vector2(texture_size, texture_size) * 0.5 + Vector2(0.0, TEXTURE_ORB_Y_NUDGE * scale_factor),
				Vector2(texture_size, texture_size)
			)
			canvas.draw_texture_rect(icon_texture, texture_rect, false, modulate)
		else:
			symbol_renderer.draw(canvas, slot_pos, icon_radius, skill_name, skill_color, is_active)

		if is_on_cooldown:
			cooldown_renderer.draw(
				canvas,
				slot_pos,
				icon_radius + socket_overlap * scale_factor,
				cooldown_ratio,
				pillar_drawer,
				static_hud_lod
			)


func _resolve_skill_icon_texture(skill_name: String, skill_icons: Dictionary) -> Texture2D:
	var mapped_texture: Variant = skill_icons.get(skill_name, null)
	if mapped_texture is Texture2D:
		return mapped_texture as Texture2D
	# Soul Summoning Art is shared by all five characters, while Optimus and
	# Blacksmith intentionally have no character-specific battle icon map.
	# Keep the accepted PNG ahead of the procedural symbol for those live HUDs.
	if skill_name == SOUL_SUMMON_ART_ID:
		return SOUL_SUMMON_ART_ICON
	if skill_name == DALJI_VISION_CHAIN_TOP_ID:
		return DALJI_VISION_CHAIN_TOP_ICON
	if skill_name == CHEONGRINGWI_VISION_DRAGON_TORRENT_ID:
		return CHEONGRINGWI_VISION_DRAGON_TORRENT_ICON
	if skill_name == YEONMYO_VISION_BONGHONGWE_ID:
		return YEONMYO_VISION_BONGHONGWE_ICON
	return null


func _get_cooldown_remaining(
	skill_state: Object,
	skill_name: String,
	time_now: int,
	cooldown_seconds: Dictionary,
	context: Dictionary = {}
) -> float:
	var cooldown_ratios: Dictionary = _get_dictionary(context.get("skill_cooldown_remaining_ratios", {}))
	if cooldown_ratios.has(skill_name):
		return clamp(float(cooldown_ratios.get(skill_name, 0.0)), 0.0, 1.0)
	if skill_state != null and skill_state.has_method("get_cooldown_remaining"):
		return skill_state.get_cooldown_remaining(skill_name, time_now, float(cooldown_seconds.get(skill_name, 0.0)))
	return 0.0


func _update_activation_state(skill_state: Object, skill_name: String, is_active: bool, time_now: int) -> int:
	if skill_state != null and skill_state.has_method("update_activation_state"):
		return int(skill_state.update_activation_state(skill_name, is_active, time_now))
	return 100000


func _is_activation_condition_met(skill_name: String, context: Dictionary) -> bool:
	var ready_overrides: Dictionary = _get_dictionary(context.get("skill_ready_overrides", {}))
	if ready_overrides.has(skill_name):
		return bool(ready_overrides.get(skill_name, false))
	if skill_name == "cleanse":
		return bool(context.get("cleanse_status_active", false))
	return true


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
