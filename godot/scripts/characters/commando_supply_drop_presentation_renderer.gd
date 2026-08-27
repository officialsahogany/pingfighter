extends RefCounted

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ImpactShockwaveTextureCache := preload("res://scripts/effects/impact_shockwave_texture_cache.gd")
const GrenadeExplosionDrawer := preload("res://scripts/effects/grenade_explosion_drawer.gd")
const CommandoSupplyDropAircraftSpriteRenderer := preload("res://scripts/characters/commando_supply_drop_aircraft_sprite_renderer.gd")
const CommandoSupplyDropEffectState := preload("res://scripts/characters/commando_supply_drop_effect_state.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const DROP_EFFECT_SECONDS := CommandoSupplyDropEffectState.DROP_EFFECT_SECONDS
const SUPPLY_PAYLOAD_SPRITE_PATH := "res://assets/sprites/effects/commando_supply_drop/commando_supply_parachute_crate_imagegen_v1.png"
const SUPPLY_PAYLOAD_DRAW_SIZE := Vector2(84.0, 84.0)
const SUPPLY_PAYLOAD_DRAW_OFFSET := Vector2(0.0, -14.0)

static var _supply_payload_texture: Texture2D = null
static var _supply_payload_texture_checked := false


static func build_draw_plan(context: Dictionary) -> Dictionary:
	return {
		"shake_offset": _get_vector2(context.get("shake_offset", Vector2.ZERO), Vector2.ZERO),
		"hold_gauge_status": _get_dict(context.get("hold_gauge_status", {})),
		"explosion_effects": _get_array(context.get("explosion_effects", [])),
		"aircraft": _get_dict(context.get("aircraft", {})),
		"drop_effects": _get_array(context.get("drop_effects", [])),
		"collectible_drops": _get_array(context.get("collectible_drops", [])),
		"crash_blast_zone": _get_dict(context.get("crash_blast_zone", {})),
	}


static func build_payload_sprite_status() -> Dictionary:
	var payload_texture: Texture2D = _get_supply_payload_texture()
	return {
		"sprite_pipeline": true,
		"path": SUPPLY_PAYLOAD_SPRITE_PATH,
		"active_loaded": payload_texture != null,
		"draw_size": SUPPLY_PAYLOAD_DRAW_SIZE,
		"draw_offset": SUPPLY_PAYLOAD_DRAW_OFFSET,
		"texture_size": payload_texture.get_size() if payload_texture != null else Vector2.ZERO,
	}


static func prewarm_assets() -> void:
	ImpactFlareTextureCache.prewarm()
	ImpactShockwaveTextureCache.prewarm()
	GrenadeExplosionDrawer.prewarm_assets()
	CommandoSupplyDropAircraftSpriteRenderer.prewarm_assets()
	_get_supply_payload_texture()


static func draw(canvas: CanvasItem, context: Dictionary) -> void:
	if canvas == null:
		return
	prewarm_assets()
	var plan: Dictionary = build_draw_plan(context)
	var shake_offset: Vector2 = plan.get("shake_offset", Vector2.ZERO)
	var hold_gauge_status: Dictionary = plan.get("hold_gauge_status", {})
	var explosion_effects: Array = plan.get("explosion_effects", [])
	var aircraft: Dictionary = plan.get("aircraft", {})
	var drop_effects: Array = plan.get("drop_effects", [])
	var collectible_drops: Array = plan.get("collectible_drops", [])
	var crash_blast_zone: Dictionary = plan.get("crash_blast_zone", {})

	_draw_hold_gauge(canvas, hold_gauge_status, shake_offset)
	_draw_supply_texture_layers(
		canvas,
		explosion_effects,
		aircraft,
		drop_effects,
		collectible_drops,
		shake_offset
	)
	if not crash_blast_zone.is_empty():
		GrenadeExplosionDrawer.draw_zone(canvas, crash_blast_zone, shake_offset)
	for effect_value in explosion_effects:
		if effect_value is Dictionary:
			_draw_explosion_effect(canvas, effect_value, shake_offset)
	if bool(aircraft.get("visible", false)):
		_draw_aircraft(canvas, aircraft, shake_offset)
	for effect_value in drop_effects:
		if effect_value is Dictionary:
			_draw_drop_effect(canvas, effect_value, shake_offset)
	for drop_value in collectible_drops:
		if drop_value is Dictionary:
			_draw_collectible_drop(canvas, drop_value, shake_offset)


static func _draw_hold_gauge(canvas: CanvasItem, status: Dictionary, shake_offset: Vector2) -> void:
	if not bool(status.get("visible", false)):
		return
	var progress: float = clamp(float(status.get("progress", 0.0)), 0.0, 1.0)
	var gauge_rect: Rect2 = status.get("rect", Rect2())
	gauge_rect.position += shake_offset
	canvas.draw_rect(gauge_rect.grow(2.0), Color(0.0, 0.0, 0.0, 0.70))
	canvas.draw_rect(gauge_rect, Color(0.04, 0.06, 0.06, 0.92))
	canvas.draw_rect(gauge_rect.grow(1.0), Color(1.0, 1.0, 1.0, 0.92), false, 2.0)

	var fill_width: int = int(floor(gauge_rect.size.x * progress))
	if fill_width > 0:
		for index in range(fill_width):
			var ratio: float = float(index) / max(1.0, gauge_rect.size.x)
			var fill_color := Color(1.0 - ratio * 0.20, 200.0 / 255.0 + (55.0 / 255.0) * ratio, 0.0, 0.95)
			var x: float = gauge_rect.position.x + float(index)
			canvas.draw_line(
				Vector2(x, gauge_rect.position.y),
				Vector2(x, gauge_rect.position.y + gauge_rect.size.y - 1.0),
				fill_color,
				1.0
			)

	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var font_size := 13
	var percent_text: String = "%d%%" % int(round(progress * 100.0))
	var text_size: Vector2 = font.get_string_size(percent_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var text_pos := Vector2(
		gauge_rect.get_center().x - text_size.x * 0.5,
		gauge_rect.position.y + (gauge_rect.size.y - text_size.y) * 0.5 + font.get_ascent(font_size)
	)
	canvas.draw_string_outline(font, text_pos, percent_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 1, Color.BLACK)
	canvas.draw_string(font, text_pos, percent_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color.WHITE)


static func _draw_supply_texture_layers(
	canvas: CanvasItem,
	explosion_effects: Array,
	aircraft: Dictionary,
	drop_effects: Array,
	collectible_drops: Array,
	shake_offset: Vector2
) -> void:
	for effect_value in explosion_effects:
		if effect_value is Dictionary:
			_draw_explosion_texture_layer(canvas, effect_value, shake_offset)
	if bool(aircraft.get("visible", false)):
		_draw_aircraft_texture_layer(canvas, aircraft, shake_offset)
	for effect_value in drop_effects:
		if effect_value is Dictionary:
			_draw_parachute_texture_layer(canvas, effect_value, shake_offset, true)
	for drop_value in collectible_drops:
		if drop_value is Dictionary:
			_draw_parachute_texture_layer(canvas, drop_value, shake_offset, false)


static func _draw_aircraft_texture_layer(canvas: CanvasItem, aircraft: Dictionary, shake_offset: Vector2) -> void:
	var pos: Vector2 = _get_vector2(aircraft.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var direction: String = str(aircraft.get("direction", "left_to_right"))
	var rotation: float = float(aircraft.get("rotation", 0.0))
	var crashing: bool = bool(aircraft.get("crashing", false))
	var nose_sign := 1.0 if direction != "right_to_left" else -1.0
	var core_color := Color(0.52, 0.82, 1.0, 1.0)
	var warn_color := Color(1.0, 0.62, 0.20, 1.0) if crashing else Color(1.0, 0.78, 0.32, 1.0)
	var tail_pos := _aircraft_point(pos, -48.0, 8.0, nose_sign, rotation)
	var cockpit_pos := _aircraft_point(pos, 14.0, 5.0, nose_sign, rotation)
	ImpactFlareTextureCache.draw_glow(canvas, tail_pos, 58.0 if crashing else 44.0, warn_color, 0.12 if crashing else 0.07)
	ImpactShockwaveTextureCache.draw_full_ring(canvas, pos, 58.0 if crashing else 46.0, core_color, 0.09 if crashing else 0.07)
	ImpactFlareTextureCache.draw_sparkle(canvas, cockpit_pos, 26.0, core_color, 0.12)


static func _draw_parachute_texture_layer(canvas: CanvasItem, drop: Dictionary, shake_offset: Vector2, fading: bool) -> void:
	var pos: Vector2 = _get_vector2(drop.get("pos", drop.get("drop_position", Vector2.ZERO)), Vector2.ZERO) + shake_offset
	var alpha: float = 0.52
	if fading:
		var duration: float = max(0.001, float(drop.get("duration", DROP_EFFECT_SECONDS)))
		alpha = clamp(float(drop.get("life", 0.0)) / duration, 0.0, 1.0) * 0.42
	var payload_type: String = str(drop.get("type", ""))
	var payload_color := Color(0.54, 0.90, 1.0, 1.0) if payload_type == "field_item" else Color(0.95, 0.82, 0.44, 1.0)
	var canopy_pos := pos + Vector2(0.0, -28.0)
	var box_pos := pos + Vector2(0.0, 8.0)
	ImpactFlareTextureCache.draw_glow(canvas, box_pos, 46.0, payload_color, alpha * 0.16)
	ImpactShockwaveTextureCache.draw_full_ring(canvas, canopy_pos, 34.0, payload_color, alpha * 0.16)
	ImpactFlareTextureCache.draw_sparkle(canvas, box_pos, 24.0, Color(1.0, 0.96, 0.64, 1.0), alpha * 0.24)


static func _draw_explosion_texture_layer(canvas: CanvasItem, effect: Dictionary, shake_offset: Vector2) -> void:
	var duration: float = max(0.001, float(effect.get("duration", 0.5)))
	var alpha: float = clamp(float(effect.get("life", 0.0)) / duration, 0.0, 1.0)
	if alpha <= 0.0:
		return
	var pos: Vector2 = _get_vector2(effect.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var radius: float = max(2.0, float(effect.get("radius", 4.0))) * (1.15 - alpha * 0.15)
	var base_color: Color = _get_color(effect, "color", Color(1.0, 0.48, 0.10, 1.0))
	var kind: String = str(effect.get("kind", "spark"))
	if kind == "smoke":
		ImpactFlareTextureCache.draw_glow(canvas, pos, radius * 4.6, Color(0.30, 0.30, 0.28, 1.0), alpha * 0.045)
		return
	if kind == "debris":
		ImpactFlareTextureCache.draw_sparkle(canvas, pos, radius * 3.2, base_color, alpha * 0.16)
		return
	ImpactFlareTextureCache.draw_burst(canvas, pos, radius * 4.0, base_color, alpha * 0.18)
	ImpactShockwaveTextureCache.draw_full_ring(canvas, pos, radius * 3.2, Color(1.0, 0.88, 0.32, 1.0), alpha * 0.12)


static func _draw_aircraft(canvas: CanvasItem, aircraft: Dictionary, shake_offset: Vector2) -> void:
	var pos: Vector2 = _get_vector2(aircraft.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var direction: String = str(aircraft.get("direction", "left_to_right"))
	var rotation: float = float(aircraft.get("rotation", 0.0))
	var crashing: bool = bool(aircraft.get("crashing", false))
	if CommandoSupplyDropAircraftSpriteRenderer.draw_sprite(
		canvas,
		pos,
		direction,
		rotation,
		crashing,
		float(aircraft.get("flight_elapsed", 0.0)),
		float(aircraft.get("crash_elapsed", 0.0)),
		max(0.001, float(aircraft.get("crash_frame_interval", 0.001)))
	):
		return
	var nose_sign := 1.0 if direction != "right_to_left" else -1.0
	var body_color := Color(0.47, 0.50, 0.38, 0.92)
	var wing_color := Color(0.35, 0.43, 0.30, 0.88)
	var glass_color := Color(0.70, 0.88, 0.95, 0.86)
	var dark := Color(0.10, 0.12, 0.10, 0.9)
	var body := [
		_aircraft_point(pos, -34.0, 5.0, nose_sign, rotation),
		_aircraft_point(pos, 34.0, 1.0, nose_sign, rotation),
		_aircraft_point(pos, 42.0, 11.0, nose_sign, rotation),
		_aircraft_point(pos, -38.0, 15.0, nose_sign, rotation),
	]
	canvas.draw_colored_polygon(PackedVector2Array(body), body_color)
	canvas.draw_line(
		_aircraft_point(pos, -46.0, 0.0, nose_sign, rotation),
		_aircraft_point(pos, 18.0, -3.0, nose_sign, rotation),
		wing_color,
		8.0
	)
	canvas.draw_line(
		_aircraft_point(pos, -18.0, 14.0, nose_sign, rotation),
		_aircraft_point(pos, 22.0, 28.0, nose_sign, rotation),
		wing_color,
		4.0
	)
	var cockpit := [
		_aircraft_point(pos, 5.0, 2.0, nose_sign, rotation),
		_aircraft_point(pos, 21.0, 2.0, nose_sign, rotation),
		_aircraft_point(pos, 21.0, 11.0, nose_sign, rotation),
		_aircraft_point(pos, 5.0, 11.0, nose_sign, rotation),
	]
	canvas.draw_colored_polygon(PackedVector2Array(cockpit), glass_color)
	canvas.draw_line(
		_aircraft_point(pos, 43.0, 8.0, nose_sign, rotation),
		_aircraft_point(pos, 55.0, 1.0, nose_sign, rotation),
		dark,
		2.0
	)
	canvas.draw_line(
		_aircraft_point(pos, 43.0, 8.0, nose_sign, rotation),
		_aircraft_point(pos, 55.0, 15.0, nose_sign, rotation),
		dark,
		2.0
	)


static func _draw_explosion_effect(canvas: CanvasItem, effect: Dictionary, shake_offset: Vector2) -> void:
	var pos: Vector2 = _get_vector2(effect.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var duration: float = max(0.001, float(effect.get("duration", 0.5)))
	var alpha: float = clamp(float(effect.get("life", 0.0)) / duration, 0.0, 1.0)
	var base_color: Color = _get_color(effect, "color", Color(1.0, 0.5, 0.1, 1.0))
	base_color.a *= alpha
	var radius: float = max(1.0, float(effect.get("radius", 4.0))) * (1.15 - alpha * 0.15)
	if str(effect.get("kind", "")) == "debris":
		canvas.draw_rect(Rect2(pos - Vector2(radius, radius) * 0.5, Vector2(radius, radius)), base_color)
	else:
		canvas.draw_circle(pos, radius, base_color)


static func _draw_drop_effect(canvas: CanvasItem, effect: Dictionary, shake_offset: Vector2) -> void:
	var pos: Vector2 = _get_vector2(effect.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var duration: float = max(0.001, float(effect.get("duration", DROP_EFFECT_SECONDS)))
	var alpha: float = clamp(float(effect.get("life", 0.0)) / duration, 0.0, 1.0)
	if _draw_supply_payload_sprite(canvas, pos, alpha):
		return
	var color := Color(0.58, 0.62, 0.42, alpha)
	var line_color := Color(0.20, 0.22, 0.18, alpha)
	canvas.draw_arc(pos + Vector2(0.0, -26.0), 28.0, PI, TAU, 18, color, 5.0)
	canvas.draw_line(pos + Vector2(-22.0, -20.0), pos + Vector2(-12.0, -2.0), line_color, 1.5)
	canvas.draw_line(pos + Vector2(22.0, -20.0), pos + Vector2(12.0, -2.0), line_color, 1.5)
	canvas.draw_rect(Rect2(pos + Vector2(-15.0, -2.0), Vector2(30.0, 22.0)), Color(0.42, 0.43, 0.28, alpha))
	canvas.draw_rect(Rect2(pos + Vector2(-15.0, -2.0), Vector2(30.0, 22.0)), line_color, false, 2.0)


static func _draw_supply_payload_sprite(canvas: CanvasItem, pos: Vector2, alpha: float) -> bool:
	var texture: Texture2D = _get_supply_payload_texture()
	if texture == null:
		return false
	var clamped_alpha: float = clamp(alpha, 0.0, 1.0)
	if clamped_alpha <= 0.0:
		return true
	var draw_center := pos + SUPPLY_PAYLOAD_DRAW_OFFSET
	var dest_rect := Rect2(draw_center - SUPPLY_PAYLOAD_DRAW_SIZE * 0.5, SUPPLY_PAYLOAD_DRAW_SIZE)
	canvas.draw_texture_rect(texture, dest_rect, false, Color(1.0, 1.0, 1.0, clamped_alpha))
	return true


static func _draw_collectible_drop(canvas: CanvasItem, drop: Dictionary, shake_offset: Vector2) -> void:
	var effect: Dictionary = drop.duplicate(true)
	effect["pos"] = _get_vector2(drop.get("pos", drop.get("drop_position", Vector2.ZERO)), Vector2.ZERO)
	effect["life"] = 1.0
	effect["duration"] = 1.0
	_draw_drop_effect(canvas, effect, shake_offset)


static func _aircraft_point(pos: Vector2, local_x: float, local_y: float, nose_sign: float, rotation: float) -> Vector2:
	return pos + Vector2(local_x * nose_sign, local_y).rotated(rotation)


static func _get_supply_payload_texture() -> Texture2D:
	if _supply_payload_texture_checked:
		return _supply_payload_texture
	_supply_payload_texture_checked = true
	_supply_payload_texture = ProjectResourceLoader.load_texture(SUPPLY_PAYLOAD_SPRITE_PATH, "", "")
	return _supply_payload_texture


static func _get_color(entry: Dictionary, key: String, fallback: Color) -> Color:
	var value: Variant = entry.get(key, fallback)
	return value if value is Color else fallback


static func _get_array(value: Variant) -> Array:
	return value if value is Array else []


static func _get_dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
