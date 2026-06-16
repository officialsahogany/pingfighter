extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const CommandoFirearmSelectorAssets := preload("res://scripts/hud/commando_firearm_selector_assets.gd")

const HUD_FRAME_TEXTURE_PATH := CommandoFirearmSelectorAssets.HUD_FRAME_TEXTURE_PATH
const PISTOL_ICON_TEXTURE_PATH := CommandoFirearmSelectorAssets.PISTOL_ICON_TEXTURE_PATH
const BERETTA_ICON_TEXTURE_PATH := CommandoFirearmSelectorAssets.BERETTA_ICON_TEXTURE_PATH
const PISTOL_FIRE_RECOIL_SHEET_PATH := CommandoFirearmSelectorAssets.PISTOL_FIRE_RECOIL_SHEET_PATH
const BERETTA_FIRE_RECOIL_SHEET_PATH := CommandoFirearmSelectorAssets.BERETTA_FIRE_RECOIL_SHEET_PATH
const AK47_ICON_TEXTURE_PATH := CommandoFirearmSelectorAssets.AK47_ICON_TEXTURE_PATH
const AK47_FIRE_RECOIL_SHEET_PATH := CommandoFirearmSelectorAssets.AK47_FIRE_RECOIL_SHEET_PATH
const NET_GUN_ICON_TEXTURE_PATH := CommandoFirearmSelectorAssets.NET_GUN_ICON_TEXTURE_PATH
const NET_GUN_FIRE_RECOIL_SHEET_PATH := CommandoFirearmSelectorAssets.NET_GUN_FIRE_RECOIL_SHEET_PATH
const BAZOOKA_ICON_TEXTURE_PATH := CommandoFirearmSelectorAssets.BAZOOKA_ICON_TEXTURE_PATH
const BAZOOKA_FIRE_RECOIL_SHEET_PATH := CommandoFirearmSelectorAssets.BAZOOKA_FIRE_RECOIL_SHEET_PATH
const FIRE_SUPPORT_ICON_TEXTURE_PATH := CommandoFirearmSelectorAssets.FIRE_SUPPORT_ICON_TEXTURE_PATH
const FIRE_SUPPORT_RADIO_AMMO_TEXTURE_PATH := CommandoFirearmSelectorAssets.FIRE_SUPPORT_RADIO_AMMO_TEXTURE_PATH
const BOWLING_TRAP_ICON_TEXTURE_PATH := CommandoFirearmSelectorAssets.BOWLING_TRAP_ICON_TEXTURE_PATH
const BOWLING_TRAP_INSTALL_SHEET_PATH := CommandoFirearmSelectorAssets.BOWLING_TRAP_INSTALL_SHEET_PATH
const BOWLING_TRAP_CAPTURE_SHEET_PATH := CommandoFirearmSelectorAssets.BOWLING_TRAP_CAPTURE_SHEET_PATH
const SUICIDE_DRONE_ICON_TEXTURE_PATH := CommandoFirearmSelectorAssets.SUICIDE_DRONE_ICON_TEXTURE_PATH
const SUICIDE_DRONE_HOVER_SHEET_PATH := CommandoFirearmSelectorAssets.SUICIDE_DRONE_HOVER_SHEET_PATH
const PANEL_SIZE := Vector2(68.0, 112.0)
const ICON_SIZE := Vector2(50.0, 50.0)
const AMMO_AREA_SIZE := Vector2(58.0, 24.0)
const HUD_AMMO_TRAY_OFFSET := Vector2(8.0, 90.0)
const HUD_AMMO_TRAY_SIZE := Vector2(52.0, 15.0)
const FIRE_SUPPORT_AMMO_UI_SLOT_COUNT := 2
const SLINGSHOT_METER_GRADIENT_SEGMENTS := 12
const PISTOL_FIRE_RECOIL_GRID_COLS := 4
const PISTOL_FIRE_RECOIL_GRID_ROWS := 4
const PISTOL_FIRE_RECOIL_FRAME_COUNT := 16
const PISTOL_FIRE_RECOIL_WINDUP_FRAME_COUNT := 4
const PISTOL_FIRE_RECOIL_POST_FRAME_COUNT := 12
const PISTOL_HUD_PICTURE_SCALE := 1.22
const PISTOL_HUD_PICTURE_Y_OFFSET := 6.0
const AK47_FIRE_RECOIL_GRID_COLS := 4
const AK47_FIRE_RECOIL_GRID_ROWS := 4
const AK47_FIRE_RECOIL_FRAME_COUNT := 16
const AK47_HUD_PICTURE_SCALE := 1.16
const AK47_HUD_PICTURE_Y_OFFSET := 2.0
const AK47_FIRE_RECOIL_DRAW_SCALE := 1.24
const AK47_HUD_RECOIL_PIVOT_RATIO := Vector2(0.24, 0.70)
const AK47_HUD_RECOIL_ROTATION_DEGREES_BY_FRAME := [
	0.0,
	-2.5,
	-5.5,
	-8.0,
	-5.5,
	-2.5,
	-8.5,
	-5.5,
	-3.0,
	-7.0,
	-4.0,
	-2.0,
	-1.0,
	-0.4,
	0.0,
	0.0,
]
const NET_GUN_FIRE_RECOIL_GRID_COLS := 4
const NET_GUN_FIRE_RECOIL_GRID_ROWS := 4
const NET_GUN_FIRE_RECOIL_FRAME_COUNT := 16
const NET_GUN_HUD_PICTURE_SCALE := 1.20
const NET_GUN_HUD_PICTURE_Y_OFFSET := 0.0
const NET_GUN_FIRE_RECOIL_DRAW_SCALE := 1.22
const NET_GUN_HUD_RECOIL_KICK_BY_FRAME := [
	0.0,
	-0.030,
	-0.060,
	-0.085,
	-0.075,
	-0.060,
	-0.050,
	-0.040,
	-0.032,
	-0.024,
	-0.016,
	-0.010,
	-0.006,
	-0.003,
	0.0,
	0.0,
]
const BAZOOKA_FIRE_RECOIL_GRID_COLS := 4
const BAZOOKA_FIRE_RECOIL_GRID_ROWS := 4
const BAZOOKA_FIRE_RECOIL_FRAME_COUNT := 16
const BAZOOKA_HUD_PICTURE_SCALE := 1.16
const BAZOOKA_HUD_PICTURE_Y_OFFSET := 2.0
const BAZOOKA_FIRE_RECOIL_DRAW_SCALE := 1.42
const FIRE_SUPPORT_HUD_PICTURE_SCALE := 1.08
const FIRE_SUPPORT_HUD_PICTURE_Y_OFFSET := 1.0
const FIRE_SUPPORT_RADIO_AMMO_SOURCE_RECT := Rect2(140.0, 53.0, 232.0, 406.0)
const BOWLING_TRAP_HUD_PICTURE_SCALE := 1.20
const BOWLING_TRAP_HUD_PICTURE_Y_OFFSET := 0.0
const BOWLING_TRAP_INSTALL_GRID_COLS := 4
const BOWLING_TRAP_INSTALL_GRID_ROWS := 4
const BOWLING_TRAP_INSTALL_FRAME_COUNT := 16
const BOWLING_TRAP_HUD_INSTALL_DRAW_SCALE := 1.12
const BOWLING_TRAP_CAPTURE_GRID_COLS := 4
const BOWLING_TRAP_CAPTURE_GRID_ROWS := 4
const BOWLING_TRAP_CAPTURE_FRAME_COUNT := 16
const BOWLING_TRAP_HUD_CAPTURE_DRAW_SCALE := 1.10
const BOWLING_TRAP_HUD_MOTION_PIVOT_RATIO := Vector2(0.5, 0.62)
const SUICIDE_DRONE_HOVER_GRID_COLS := 4
const SUICIDE_DRONE_HOVER_GRID_ROWS := 4
const SUICIDE_DRONE_HOVER_FRAME_COUNT := 16
const SUICIDE_DRONE_HOVER_FRAME_MSEC := 70.0
const SUICIDE_DRONE_HUD_HOVER_DRAW_SCALE := 1.12
const SUICIDE_DRONE_HUD_HOVER_Y_OFFSET_RATIO := 0.06

var _hud_frame_texture_checked := false
var _hud_frame_texture: Texture2D = null
var _weapon_texture_checked: Dictionary = {}
var _weapon_texture_cache: Dictionary = {}
var _prewarm_assets_step_index := 0


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	var weapon_texture_paths: Array = CommandoFirearmSelectorAssets.get_weapon_texture_paths()
	if _prewarm_assets_step_index == 0:
		_get_hud_frame_texture()
	elif _prewarm_assets_step_index <= weapon_texture_paths.size():
		_get_cached_weapon_texture(str(weapon_texture_paths[_prewarm_assets_step_index - 1]))
	else:
		_prewarm_assets_step_index = 0
		return true
	_prewarm_assets_step_index += 1
	if _prewarm_assets_step_index > weapon_texture_paths.size():
		_prewarm_assets_step_index = 0
		return true
	return false


func prewarm_textures() -> void:
	prewarm_assets()


func build_panel_state(center: Vector2, scale_factor: float, context: Dictionary) -> Dictionary:
	var weapon_controller: Object = context.get("commando_weapon_controller", null)
	if weapon_controller == null or not weapon_controller.has_method("get_snapshot"):
		return {}
	var snapshot: Dictionary = weapon_controller.get_snapshot()
	var weapon: Dictionary = _get_dict(snapshot.get("current_weapon", {}))
	var current_weapon_id: String = str(snapshot.get("current_weapon_id", weapon.get("weapon_id", "pistol")))
	var weapon_count: int = _get_array(snapshot.get("weapons", [])).size()
	var slingshot_state: Dictionary = _get_dict(context.get("commando_firearm_slingshot_state", {}))
	var resolved_scale: float = max(0.55, scale_factor)
	var size: Vector2 = PANEL_SIZE * resolved_scale
	var rect := Rect2(center - size * 0.5, size)
	var color := _get_weapon_color(current_weapon_id)
	var badge: String = str(weapon.get("badge", ""))
	var rental: bool = bool(weapon.get("rental", false)) or badge == "대여"
	var icon_top: float = rect.position.y + (32.0 if rental else 24.0) * resolved_scale
	var icon_size := ICON_SIZE * resolved_scale
	var icon_rect := Rect2(
		Vector2(rect.position.x + (rect.size.x - icon_size.x) * 0.5, icon_top),
		icon_size
	)
	var ammo_rect := Rect2(
		rect.position + HUD_AMMO_TRAY_OFFSET * resolved_scale,
		HUD_AMMO_TRAY_SIZE * resolved_scale
	)
	var ammo_icon_state: Dictionary = build_ammo_icon_state(weapon, current_weapon_id)
	var status_text: String = str(weapon.get("ammo_text", ""))
	var pistol_state: Dictionary = _get_dict(context.get("commando_firearm_pistol_state", {}))
	var weapon_fire_state: Dictionary = _get_dict(context.get("commando_firearm_weapon_fire_sheet_state", {}))
	var bowling_trap_state: Dictionary = _get_dict(context.get("commando_firearm_bowling_trap_state", {}))
	var bowling_traps: Array = _get_array(context.get("commando_firearm_bowling_traps", []))
	var suicide_drone_state: Dictionary = _get_dict(context.get("commando_firearm_suicide_drone_state", {}))
	var suicide_drone_hover_active: bool = _is_suicide_drone_hover_sheet_active(current_weapon_id, suicide_drone_state)
	var hud_highlight_state: Dictionary = _get_dict(snapshot.get("hud_highlight_state", context.get("commando_firearm_hud_highlight_state", {})))
	var panel_state: Dictionary = CommandoFirearmSelectorAssets.build_panel_asset_paths()
	panel_state.merge({
		"panel_count": 1,
		"rect": rect,
		"hud_frame_rect": rect,
		"icon_rect": icon_rect,
		"meter_rect": ammo_rect,
		"layout": "original_compact_vertical",
		"scale_factor": scale_factor,
		"resolved_scale": resolved_scale,
		"weapon": weapon,
		"weapon_count": weapon_count,
		"current_weapon_id": current_weapon_id,
		"title": str(weapon.get("display_name_ko", current_weapon_id)),
		"status": status_text,
		"badge": badge,
		"rental": rental,
		"can_fire": bool(weapon.get("can_fire", true)),
		"color": color,
		"slingshot_state": slingshot_state,
		"pistol_state": pistol_state,
		"weapon_fire_state": weapon_fire_state,
		"bowling_trap_state": bowling_trap_state,
		"bowling_traps": bowling_traps,
		"suicide_drone_state": suicide_drone_state,
		"hud_highlight_state": hud_highlight_state,
		"hud_highlight_active": _is_hud_highlight_active(current_weapon_id, hud_highlight_state),
		"hud_highlight_ratio": _get_hud_highlight_ratio(hud_highlight_state),
		"pistol_fire_recoil_active": _is_pistol_fire_animation_active(current_weapon_id, pistol_state),
		"pistol_fire_recoil_frame": _get_pistol_fire_recoil_frame(pistol_state),
		"pistol_fire_recoil_frame_count": PISTOL_FIRE_RECOIL_FRAME_COUNT,
		"ak47_fire_recoil_active": _is_ak47_fire_animation_active(current_weapon_id, weapon_fire_state),
		"ak47_fire_recoil_frame": _get_ak47_fire_recoil_frame(weapon_fire_state),
		"ak47_fire_recoil_frame_count": AK47_FIRE_RECOIL_FRAME_COUNT,
		"ak47_fire_recoil_draw_scale": AK47_FIRE_RECOIL_DRAW_SCALE,
		"ak47_fire_recoil_rotation_degrees": _get_ak47_fire_recoil_rotation_degrees(current_weapon_id, weapon_fire_state),
		"net_gun_fire_recoil_active": _is_net_gun_fire_animation_active(current_weapon_id, weapon_fire_state),
		"net_gun_fire_recoil_frame": _get_net_gun_fire_recoil_frame(weapon_fire_state),
		"net_gun_fire_recoil_frame_count": NET_GUN_FIRE_RECOIL_FRAME_COUNT,
		"net_gun_fire_recoil_draw_scale": NET_GUN_FIRE_RECOIL_DRAW_SCALE,
		"net_gun_fire_recoil_kick_ratio": _get_net_gun_fire_recoil_kick_ratio(current_weapon_id, weapon_fire_state),
		"bazooka_fire_recoil_active": _is_bazooka_fire_animation_active(current_weapon_id, weapon_fire_state),
		"bazooka_fire_recoil_frame": _get_bazooka_fire_recoil_frame(weapon_fire_state),
		"bazooka_fire_recoil_frame_count": BAZOOKA_FIRE_RECOIL_FRAME_COUNT,
		"bazooka_fire_recoil_draw_scale": BAZOOKA_FIRE_RECOIL_DRAW_SCALE,
		"bowling_trap_ui_animation_active": _is_bowling_trap_ui_animation_active(current_weapon_id, bowling_trap_state, bowling_traps),
		"bowling_trap_ui_install_animation_active": _is_bowling_trap_install_ui_animation_active(current_weapon_id, bowling_trap_state, bowling_traps),
		"bowling_trap_ui_install_animation_frame": _get_bowling_trap_install_ui_animation_frame(bowling_trap_state, bowling_traps),
		"bowling_trap_ui_install_animation_frame_count": BOWLING_TRAP_INSTALL_FRAME_COUNT,
		"bowling_trap_ui_capture_animation_active": _is_bowling_trap_capture_ui_animation_active(current_weapon_id, bowling_traps),
		"bowling_trap_ui_animation_frame": _get_bowling_trap_ui_animation_frame(bowling_traps),
		"bowling_trap_ui_animation_frame_count": BOWLING_TRAP_CAPTURE_FRAME_COUNT,
		"suicide_drone_hover_sheet_active": suicide_drone_hover_active,
		"suicide_drone_hover_frame": _get_suicide_drone_hover_frame() if suicide_drone_hover_active else 0,
		"suicide_drone_hover_frame_count": SUICIDE_DRONE_HOVER_FRAME_COUNT,
		"suicide_drone_hover_draw_scale": SUICIDE_DRONE_HUD_HOVER_DRAW_SCALE,
		"ammo_icon_state": ammo_icon_state,
	}, true)
	return panel_state


func draw(canvas: CanvasItem, center: Vector2, scale_factor: float, context: Dictionary) -> void:
	if canvas == null:
		return
	var panel_state: Dictionary = build_panel_state(center, scale_factor, context)
	if panel_state.is_empty():
		return
	var rect: Rect2 = _get_rect(panel_state.get("rect", Rect2()))
	var icon_rect: Rect2 = _get_rect(panel_state.get("icon_rect", Rect2()))
	var meter_rect: Rect2 = _get_rect(panel_state.get("meter_rect", Rect2()))
	var color: Color = _get_color(panel_state.get("color", Color.WHITE), Color.WHITE)
	var current_weapon_id: String = str(panel_state.get("current_weapon_id", "pistol"))
	var title: String = str(panel_state.get("title", current_weapon_id))
	var _badge: String = str(panel_state.get("badge", ""))
	var rental: bool = bool(panel_state.get("rental", false))
	var can_fire: bool = bool(panel_state.get("can_fire", true))
	var pistol_state: Dictionary = _get_dict(panel_state.get("pistol_state", {}))
	var weapon_fire_state: Dictionary = _get_dict(panel_state.get("weapon_fire_state", {}))
	var bowling_trap_state: Dictionary = _get_dict(panel_state.get("bowling_trap_state", {}))
	var bowling_traps: Array = _get_array(panel_state.get("bowling_traps", []))
	var suicide_drone_state: Dictionary = _get_dict(panel_state.get("suicide_drone_state", {}))
	var safe_scale: float = max(0.55, float(panel_state.get("resolved_scale", scale_factor)))
	var font: Font = ThemeDB.fallback_font

	_draw_hud_frame(canvas, rect, safe_scale)
	_draw_hud_highlight(canvas, rect, safe_scale, panel_state)
	if rental:
		canvas.draw_string(
			font,
			Vector2(rect.position.x, rect.position.y + 10.0 * safe_scale),
			"대여",
			HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x,
			int(round(15.0 * safe_scale)),
			Color(1.0, 0.18, 0.20, 0.96)
		)
	canvas.draw_string(
		font,
		Vector2(rect.position.x, rect.position.y + (25.0 if rental else 18.0) * safe_scale),
		title,
		HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x,
		int(round(14.0 * safe_scale)),
		Color(0.82, 0.84, 0.82, 0.96) if not rental else Color(0.98, 0.94, 0.38, 0.96)
	)

	_draw_weapon_slot(canvas, icon_rect, current_weapon_id, color, can_fire, rental, safe_scale, pistol_state, weapon_fire_state, bowling_trap_state, bowling_traps, suicide_drone_state)
	var ammo_icon_state: Dictionary = _get_dict(panel_state.get("ammo_icon_state", {}))
	if not ammo_icon_state.is_empty():
		_draw_ammo_icon_display(canvas, meter_rect, safe_scale, ammo_icon_state, color)


func _draw_hud_highlight(canvas: CanvasItem, rect: Rect2, scale_factor: float, panel_state: Dictionary) -> void:
	if not bool(panel_state.get("hud_highlight_active", false)):
		return
	var ratio: float = clamp(float(panel_state.get("hud_highlight_ratio", 0.0)), 0.0, 1.0)
	if ratio <= 0.0:
		return
	var highlight_state: Dictionary = _get_dict(panel_state.get("hud_highlight_state", {}))
	var timer_frames: float = float(highlight_state.get("timer_frames", 0.0))
	var time_seconds: float = float(Time.get_ticks_msec()) * 0.001

	# Tween-style envelope: ease-in over the first ~14 frames after a fresh
	# trigger, then track the timer ratio for the fade-out tail.
	var timer_max_frames: float = max(1.0, float(highlight_state.get("timer_max_frames", 1.0)))
	var elapsed_frames: float = max(0.0, timer_max_frames - timer_frames)
	var ease_in: float = clamp(elapsed_frames / 14.0, 0.0, 1.0)
	ease_in = smoothstep(0.0, 1.0, ease_in)
	var fade_out: float = smoothstep(0.0, 0.45, ratio)
	var envelope: float = ease_in * fade_out

	var pulse: float = 0.5 + 0.5 * sin(timer_frames * 0.30)
	var strength: float = clamp(envelope * (0.65 + 0.35 * pulse), 0.0, 1.0)

	# CPU "texture slice" rainbow perimeter: walk the panel perimeter as a
	# strip of N short segments, each painted with its own HSV-cycled color.
	# This sits on top of the shader quad glow and adds a crisp inner ring
	# even on machines where the shader quad is dropped or low-power.
	var inner := rect.grow(-5.0 * scale_factor)
	var slice_count: int = 48
	var perimeter_points: Array = _build_perimeter_points(inner, slice_count)
	var sweep_phase: float = fposmod(time_seconds * 0.55, 1.0)
	for i in range(slice_count):
		var a: Vector2 = perimeter_points[i]
		var b: Vector2 = perimeter_points[(i + 1) % slice_count]
		var slice_t: float = (float(i) + 0.5) / float(slice_count)
		var hue: float = fposmod(slice_t * 2.0 + time_seconds * 0.42, 1.0)
		var slice_col: Color = Color.from_hsv(hue, 0.78, 1.0, 1.0)
		# Sweep highlight: a bright bump that travels around the perimeter.
		var sweep_d: float = abs(slice_t - sweep_phase)
		sweep_d = min(sweep_d, 1.0 - sweep_d)
		var sweep_boost: float = exp(-sweep_d * 14.0)
		var line_alpha: float = clamp(strength * (0.55 + 0.55 * sweep_boost), 0.0, 1.0)
		var line_color := Color(
			min(1.0, slice_col.r + sweep_boost * 0.45),
			min(1.0, slice_col.g + sweep_boost * 0.45),
			min(1.0, slice_col.b + sweep_boost * 0.45),
			line_alpha
		)
		canvas.draw_line(a, b, line_color, max(1.2, 2.2 * scale_factor), true)

	# Soft inner tint so the panel interior reads "alive" without washing out
	# the icon. Neutral warm tone modulated by the rainbow envelope.
	canvas.draw_rect(rect.grow(-7.0 * scale_factor), Color(0.95, 0.85, 0.35, 0.08 * strength), true)

	# Outer rectangle outline layers, hue-shifted with time for a slow color
	# wash that complements the per-slice perimeter.
	for i in range(3, 0, -1):
		var grow: float = float(i) * 3.5 * scale_factor
		var layer_alpha: float = strength * (0.05 + float(4 - i) * 0.030)
		var layer_hue: float = fposmod(time_seconds * 0.22 + float(i) * 0.12, 1.0)
		var layer_col: Color = Color.from_hsv(layer_hue, 0.55, 1.0, 1.0)
		canvas.draw_rect(
			rect.grow(grow),
			Color(layer_col.r, layer_col.g, layer_col.b, layer_alpha),
			false,
			max(1.0, float(i + 1) * scale_factor)
		)

	# Bright corner pips that pulse with the sweep — the "texture slice"
	# accents that read as discrete chunks of rainbow chrome.
	var corner_pip_color := Color(1.0, 0.96, 0.78, 0.55 * strength)
	var pip_radius: float = max(2.0, 3.5 * scale_factor)
	for c in [inner.position, Vector2(inner.end.x, inner.position.y), Vector2(inner.position.x, inner.end.y), inner.end]:
		canvas.draw_circle(c, pip_radius, corner_pip_color)


func _build_perimeter_points(inner_rect: Rect2, slice_count: int) -> Array:
	var points: Array = []
	var safe_count: int = max(4, slice_count)
	@warning_ignore("integer_division")
	var per_side: int = safe_count / 4
	if per_side < 1:
		per_side = 1
	var top_left: Vector2 = inner_rect.position
	var top_right := Vector2(inner_rect.end.x, inner_rect.position.y)
	var bot_right: Vector2 = inner_rect.end
	var bot_left := Vector2(inner_rect.position.x, inner_rect.end.y)
	for i in range(per_side):
		var t: float = float(i) / float(per_side)
		points.append(top_left.lerp(top_right, t))
	for i in range(per_side):
		var t: float = float(i) / float(per_side)
		points.append(top_right.lerp(bot_right, t))
	for i in range(per_side):
		var t: float = float(i) / float(per_side)
		points.append(bot_right.lerp(bot_left, t))
	for i in range(per_side):
		var t: float = float(i) / float(per_side)
		points.append(bot_left.lerp(top_left, t))
	return points


func _draw_hud_frame(canvas: CanvasItem, rect: Rect2, scale_factor: float) -> void:
	var texture: Texture2D = _get_hud_frame_texture()
	if texture is Texture2D:
		canvas.draw_texture_rect(texture, rect, false, Color(1.0, 1.0, 1.0, 0.98))
		return
	_draw_fallback_hud_frame(canvas, rect, scale_factor)


func _draw_fallback_hud_frame(canvas: CanvasItem, rect: Rect2, scale_factor: float) -> void:
	canvas.draw_rect(rect, Color(0.02, 0.025, 0.025, 0.82), true)
	canvas.draw_rect(rect, Color(0.54, 0.62, 0.45, 0.94), false, max(1.0, 2.0 * scale_factor))
	var inner := rect.grow(-4.0 * scale_factor)
	canvas.draw_rect(inner, Color(0.0, 0.0, 0.0, 0.26), false, max(1.0, scale_factor))


func _get_hud_frame_texture() -> Texture2D:
	if _hud_frame_texture_checked:
		return _hud_frame_texture
	_hud_frame_texture_checked = true
	_hud_frame_texture = ProjectResourceLoader.load_texture(
		HUD_FRAME_TEXTURE_PATH,
		"Missing Commando firearm HUD frame at %s",
		"Failed to load Commando firearm HUD frame at %s"
	)
	return _hud_frame_texture


func _draw_weapon_slot(canvas: CanvasItem, icon_rect: Rect2, weapon_id: String, color: Color, can_fire: bool, _rental: bool, scale_factor: float, pistol_state: Dictionary = {}, weapon_fire_state: Dictionary = {}, bowling_trap_state: Dictionary = {}, bowling_traps: Array = [], suicide_drone_state: Dictionary = {}) -> void:
	_draw_weapon_picture(canvas, _get_weapon_picture_rect(icon_rect, weapon_id, scale_factor), weapon_id, color, can_fire, scale_factor, pistol_state, weapon_fire_state, bowling_trap_state, bowling_traps, suicide_drone_state)
	if not can_fire:
		canvas.draw_rect(icon_rect, Color(0.0, 0.0, 0.0, 0.34), true)
		canvas.draw_line(icon_rect.position + Vector2(5.0, 5.0) * scale_factor, icon_rect.end - Vector2(5.0, 5.0) * scale_factor, Color(0.78, 0.20, 0.20, 0.90), max(1.0, 2.0 * scale_factor), true)


func _get_weapon_picture_rect(icon_rect: Rect2, weapon_id: String, scale_factor: float) -> Rect2:
	if weapon_id == "pistol" or weapon_id == "commando_pistol":
		var draw_size := icon_rect.size * PISTOL_HUD_PICTURE_SCALE
		var position := Vector2(
			icon_rect.position.x + (icon_rect.size.x - draw_size.x) * 0.5,
			icon_rect.position.y + PISTOL_HUD_PICTURE_Y_OFFSET * scale_factor
		)
		return Rect2(position, draw_size)
	if weapon_id == "ak47":
		var draw_size := icon_rect.size * AK47_HUD_PICTURE_SCALE
		var position := Vector2(
			icon_rect.position.x + (icon_rect.size.x - draw_size.x) * 0.5,
			icon_rect.position.y + (icon_rect.size.y - draw_size.y) * 0.5 + AK47_HUD_PICTURE_Y_OFFSET * scale_factor
		)
		return Rect2(position, draw_size)
	if weapon_id == "net_gun":
		var draw_size := icon_rect.size * NET_GUN_HUD_PICTURE_SCALE
		var position := Vector2(
			icon_rect.position.x + (icon_rect.size.x - draw_size.x) * 0.5,
			icon_rect.position.y + (icon_rect.size.y - draw_size.y) * 0.5 + NET_GUN_HUD_PICTURE_Y_OFFSET * scale_factor
		)
		return Rect2(position, draw_size)
	if weapon_id == "bazooka":
		var draw_size := icon_rect.size * BAZOOKA_HUD_PICTURE_SCALE
		var position := Vector2(
			icon_rect.position.x + (icon_rect.size.x - draw_size.x) * 0.5,
			icon_rect.position.y + (icon_rect.size.y - draw_size.y) * 0.5 + BAZOOKA_HUD_PICTURE_Y_OFFSET * scale_factor
		)
		return Rect2(position, draw_size)
	if weapon_id == "fire_support":
		var draw_size := icon_rect.size * FIRE_SUPPORT_HUD_PICTURE_SCALE
		var position := Vector2(
			icon_rect.position.x + (icon_rect.size.x - draw_size.x) * 0.5,
			icon_rect.position.y + (icon_rect.size.y - draw_size.y) * 0.5 + FIRE_SUPPORT_HUD_PICTURE_Y_OFFSET * scale_factor
		)
		return Rect2(position, draw_size)
	if weapon_id == "bowling_trap":
		var draw_size := icon_rect.size * BOWLING_TRAP_HUD_PICTURE_SCALE
		var position := Vector2(
			icon_rect.position.x + (icon_rect.size.x - draw_size.x) * 0.5,
			icon_rect.position.y + (icon_rect.size.y - draw_size.y) * 0.5 + BOWLING_TRAP_HUD_PICTURE_Y_OFFSET * scale_factor
		)
		return Rect2(position, draw_size)
	return icon_rect.grow(-4.0 * scale_factor)


func _draw_weapon_picture(canvas: CanvasItem, rect: Rect2, weapon_id: String, color: Color, active: bool, scale_factor: float, pistol_state: Dictionary = {}, weapon_fire_state: Dictionary = {}, bowling_trap_state: Dictionary = {}, bowling_traps: Array = [], suicide_drone_state: Dictionary = {}) -> void:
	var base_alpha: float = 1.0 if active else 0.48
	match weapon_id:
		"pistol":
			if _draw_pistol_png_picture(canvas, rect, weapon_id, base_alpha, pistol_state):
				return
			_draw_pistol_picture(canvas, rect, base_alpha, scale_factor)
		"ak47":
			if _draw_ak47_png_picture(canvas, rect, weapon_id, base_alpha, weapon_fire_state):
				return
			_draw_ak47_picture(canvas, rect, base_alpha, scale_factor)
		"commando_pistol":
			if _draw_pistol_png_picture(canvas, rect, weapon_id, base_alpha, pistol_state):
				return
			_draw_beretta_picture(canvas, rect, base_alpha, scale_factor)
		"net_gun":
			if _draw_net_gun_png_picture(canvas, rect, weapon_id, base_alpha, weapon_fire_state):
				return
			_draw_net_gun_picture(canvas, rect, base_alpha, scale_factor)
		"bazooka":
			if _draw_bazooka_png_picture(canvas, rect, weapon_id, base_alpha, weapon_fire_state):
				return
			_draw_bazooka_picture(canvas, rect, base_alpha, scale_factor)
		"fire_support":
			if _draw_fire_support_png_picture(canvas, rect, base_alpha):
				return
			_draw_fire_support_picture(canvas, rect, base_alpha, scale_factor)
		"bowling_trap":
			if _draw_bowling_trap_png_picture(canvas, rect, base_alpha, bowling_trap_state, bowling_traps, scale_factor):
				return
			_draw_bowling_trap_picture(canvas, rect, base_alpha, scale_factor)
		"suicide_drone":
			if _is_suicide_drone_hover_sheet_active(weapon_id, suicide_drone_state) and _draw_suicide_drone_hover_sheet_picture(canvas, rect, base_alpha):
				return
			if _draw_suicide_drone_png_picture(canvas, rect, base_alpha):
				return
			_draw_drone_picture(canvas, rect, base_alpha, scale_factor)
		_:
			canvas.draw_circle(rect.get_center(), min(rect.size.x, rect.size.y) * 0.25, Color(color.r, color.g, color.b, base_alpha))


func _draw_pistol_png_picture(canvas: CanvasItem, rect: Rect2, weapon_id: String, alpha: float, pistol_state: Dictionary) -> bool:
	if _is_pistol_fire_animation_active(weapon_id, pistol_state):
		var sheet_path := BERETTA_FIRE_RECOIL_SHEET_PATH if weapon_id == "commando_pistol" else PISTOL_FIRE_RECOIL_SHEET_PATH
		var sheet: Texture2D = _get_cached_weapon_texture(sheet_path)
		if sheet is Texture2D:
			var frame: int = _get_pistol_fire_recoil_frame(pistol_state)
			canvas.draw_texture_rect_region(
				sheet,
				rect,
				_get_pistol_fire_recoil_source_rect(sheet, frame),
				Color(1.0, 1.0, 1.0, alpha),
				false,
				true
			)
			return true
	var icon_path := BERETTA_ICON_TEXTURE_PATH if weapon_id == "commando_pistol" else PISTOL_ICON_TEXTURE_PATH
	var icon: Texture2D = _get_cached_weapon_texture(icon_path)
	if icon is Texture2D:
		canvas.draw_texture_rect(icon, rect, false, Color(1.0, 1.0, 1.0, alpha))
		return true
	return false


func _draw_ak47_png_picture(canvas: CanvasItem, rect: Rect2, weapon_id: String, alpha: float, weapon_fire_state: Dictionary) -> bool:
	if _is_ak47_fire_animation_active(weapon_id, weapon_fire_state):
		var sheet: Texture2D = _get_cached_weapon_texture(AK47_FIRE_RECOIL_SHEET_PATH)
		if sheet is Texture2D:
			var frame: int = _get_ak47_fire_recoil_frame(weapon_fire_state)
			var source_rect: Rect2 = _get_ak47_fire_recoil_source_rect(sheet, frame)
			var modulate := Color(1.0, 1.0, 1.0, alpha)
			var fire_rect: Rect2 = _scale_rect_around_pivot(rect, AK47_FIRE_RECOIL_DRAW_SCALE, AK47_HUD_RECOIL_PIVOT_RATIO)
			var rotation_degrees: float = _get_ak47_fire_recoil_rotation_degrees(weapon_id, weapon_fire_state)
			if abs(rotation_degrees) > 0.01:
				_draw_texture_rect_region_rotated(
					canvas,
					sheet,
					source_rect,
					fire_rect,
					modulate,
					deg_to_rad(rotation_degrees),
					AK47_HUD_RECOIL_PIVOT_RATIO
				)
			else:
				canvas.draw_texture_rect_region(sheet, fire_rect, source_rect, modulate, false, true)
			return true
	var icon: Texture2D = _get_cached_weapon_texture(AK47_ICON_TEXTURE_PATH)
	if icon is Texture2D:
		canvas.draw_texture_rect(icon, rect, false, Color(1.0, 1.0, 1.0, alpha))
		return true
	return false


func _draw_net_gun_png_picture(canvas: CanvasItem, rect: Rect2, weapon_id: String, alpha: float, weapon_fire_state: Dictionary) -> bool:
	if _is_net_gun_fire_animation_active(weapon_id, weapon_fire_state):
		var sheet: Texture2D = _get_cached_weapon_texture(NET_GUN_FIRE_RECOIL_SHEET_PATH)
		if sheet is Texture2D:
			var frame: int = _get_net_gun_fire_recoil_frame(weapon_fire_state)
			var fire_rect: Rect2 = _scale_rect_around_pivot(rect, NET_GUN_FIRE_RECOIL_DRAW_SCALE, Vector2(0.5, 0.5))
			var kick_ratio: float = _get_net_gun_fire_recoil_kick_ratio(weapon_id, weapon_fire_state)
			fire_rect.position += Vector2(rect.size.x * kick_ratio, -rect.size.y * abs(kick_ratio) * 0.16)
			canvas.draw_texture_rect_region(
				sheet,
				fire_rect,
				_get_net_gun_fire_recoil_source_rect(sheet, frame),
				Color(1.0, 1.0, 1.0, alpha),
				false,
				true
			)
			return true
	var icon: Texture2D = _get_cached_weapon_texture(NET_GUN_ICON_TEXTURE_PATH)
	if icon is Texture2D:
		canvas.draw_texture_rect(icon, rect, false, Color(1.0, 1.0, 1.0, alpha))
		return true
	return false


func _draw_bazooka_png_picture(canvas: CanvasItem, rect: Rect2, weapon_id: String, alpha: float, weapon_fire_state: Dictionary) -> bool:
	if _is_bazooka_fire_animation_active(weapon_id, weapon_fire_state):
		var sheet: Texture2D = _get_cached_weapon_texture(BAZOOKA_FIRE_RECOIL_SHEET_PATH)
		if sheet is Texture2D:
			var frame: int = _get_bazooka_fire_recoil_frame(weapon_fire_state)
			var fire_rect: Rect2 = _scale_rect_around_pivot(rect, BAZOOKA_FIRE_RECOIL_DRAW_SCALE, Vector2(0.5, 0.5))
			canvas.draw_texture_rect_region(
				sheet,
				fire_rect,
				_get_bazooka_fire_recoil_source_rect(sheet, frame),
				Color(1.0, 1.0, 1.0, alpha),
				false,
				true
			)
			return true
	var icon: Texture2D = _get_cached_weapon_texture(BAZOOKA_ICON_TEXTURE_PATH)
	if icon is Texture2D:
		canvas.draw_texture_rect(icon, rect, false, Color(1.0, 1.0, 1.0, alpha))
		return true
	return false


func _draw_fire_support_png_picture(canvas: CanvasItem, rect: Rect2, alpha: float) -> bool:
	var icon: Texture2D = _get_cached_weapon_texture(FIRE_SUPPORT_ICON_TEXTURE_PATH)
	if icon is Texture2D:
		canvas.draw_texture_rect(icon, rect, false, Color(1.0, 1.0, 1.0, alpha))
		return true
	return false


func _draw_bowling_trap_png_picture(canvas: CanvasItem, rect: Rect2, alpha: float, bowling_trap_state: Dictionary, bowling_traps: Array, scale_factor: float) -> bool:
	var hud_trap: Dictionary = _get_bowling_trap_hud_trap(bowling_traps)
	if str(hud_trap.get("state", "")) == "installing":
		var install_sheet: Texture2D = _get_cached_weapon_texture(BOWLING_TRAP_INSTALL_SHEET_PATH)
		if install_sheet is Texture2D:
			var install_frame: int = _get_bowling_trap_install_ui_animation_frame(bowling_trap_state, bowling_traps)
			var install_rect: Rect2 = _scale_rect_around_pivot(rect, BOWLING_TRAP_HUD_INSTALL_DRAW_SCALE, Vector2(0.5, 0.5))
			canvas.draw_texture_rect_region(
				install_sheet,
				install_rect,
				_get_bowling_trap_install_source_rect(install_sheet, install_frame),
				Color(1.0, 1.0, 1.0, alpha),
				false,
				true
			)
			return true
	if str(hud_trap.get("state", "")) == "capturing":
		var sheet: Texture2D = _get_cached_weapon_texture(BOWLING_TRAP_CAPTURE_SHEET_PATH)
		if sheet is Texture2D:
			var frame: int = _get_bowling_trap_ui_animation_frame(bowling_traps)
			var capture_rect: Rect2 = _scale_rect_around_pivot(rect, BOWLING_TRAP_HUD_CAPTURE_DRAW_SCALE, Vector2(0.5, 0.5))
			canvas.draw_texture_rect_region(
				sheet,
				capture_rect,
				_get_bowling_trap_capture_source_rect(sheet, frame),
				Color(1.0, 1.0, 1.0, alpha),
				false,
				true
			)
			return true
	var icon: Texture2D = _get_cached_weapon_texture(BOWLING_TRAP_ICON_TEXTURE_PATH)
	if icon is Texture2D:
		var draw_rect: Rect2 = rect
		var rotation: float = 0.0
		if _is_bowling_trap_ui_animation_active("bowling_trap", bowling_trap_state, bowling_traps):
			draw_rect = _get_bowling_trap_motion_rect(rect, bowling_trap_state, hud_trap, scale_factor)
			rotation = _get_bowling_trap_motion_rotation(bowling_trap_state, hud_trap)
		if abs(rotation) > 0.001:
			_draw_texture_rect_region_rotated(
				canvas,
				icon,
				Rect2(Vector2.ZERO, icon.get_size()),
				draw_rect,
				Color(1.0, 1.0, 1.0, alpha),
				rotation,
				BOWLING_TRAP_HUD_MOTION_PIVOT_RATIO
			)
		else:
			canvas.draw_texture_rect(icon, draw_rect, false, Color(1.0, 1.0, 1.0, alpha))
		return true
	return false


func _draw_suicide_drone_png_picture(canvas: CanvasItem, rect: Rect2, alpha: float) -> bool:
	var icon: Texture2D = _get_cached_weapon_texture(SUICIDE_DRONE_ICON_TEXTURE_PATH)
	if icon is Texture2D:
		canvas.draw_texture_rect(icon, rect, false, Color(1.0, 1.0, 1.0, alpha))
		return true
	return false


func _draw_suicide_drone_hover_sheet_picture(canvas: CanvasItem, rect: Rect2, alpha: float) -> bool:
	var sheet: Texture2D = _get_cached_weapon_texture(SUICIDE_DRONE_HOVER_SHEET_PATH)
	if sheet is Texture2D:
		var frame: int = _get_suicide_drone_hover_frame()
		var draw_rect: Rect2 = _scale_rect_around_pivot(rect, SUICIDE_DRONE_HUD_HOVER_DRAW_SCALE, Vector2(0.5, 0.5))
		draw_rect.position.y += rect.size.y * SUICIDE_DRONE_HUD_HOVER_Y_OFFSET_RATIO
		canvas.draw_texture_rect_region(
			sheet,
			draw_rect,
			_get_suicide_drone_hover_source_rect(sheet, frame),
			Color(1.0, 1.0, 1.0, alpha),
			false,
			true
		)
		return true
	return false


func _is_suicide_drone_hover_sheet_active(weapon_id: String, suicide_drone_state: Dictionary) -> bool:
	return weapon_id == "suicide_drone" and bool(suicide_drone_state.get("active", false))


func _is_hud_highlight_active(weapon_id: String, highlight_state: Dictionary) -> bool:
	if not bool(highlight_state.get("active", false)):
		return false
	if float(highlight_state.get("timer_frames", 0.0)) <= 0.0:
		return false
	var highlighted_weapon_id: String = str(highlight_state.get("weapon_id", ""))
	return highlighted_weapon_id.is_empty() or highlighted_weapon_id == weapon_id


func _get_hud_highlight_ratio(highlight_state: Dictionary) -> float:
	if not bool(highlight_state.get("active", false)):
		return 0.0
	var explicit_ratio: float = float(highlight_state.get("ratio", -1.0))
	if explicit_ratio >= 0.0:
		return clamp(explicit_ratio, 0.0, 1.0)
	var timer_frames: float = max(0.0, float(highlight_state.get("timer_frames", 0.0)))
	var timer_max_frames: float = max(1.0, float(highlight_state.get("timer_max_frames", 1.0)))
	return clamp(timer_frames / timer_max_frames, 0.0, 1.0)


func _is_pistol_fire_animation_active(weapon_id: String, pistol_state: Dictionary) -> bool:
	if weapon_id != "pistol" and weapon_id != "commando_pistol":
		return false
	return (
		float(pistol_state.get("fire_delay_frames", 0.0)) > 0.0
		or float(pistol_state.get("post_fire_animation_frames", 0.0)) > 0.0
	)


func _is_ak47_fire_animation_active(weapon_id: String, weapon_fire_state: Dictionary) -> bool:
	return (
		weapon_id == "ak47"
		and bool(weapon_fire_state.get("active", false))
		and str(weapon_fire_state.get("weapon_id", "")) == "ak47"
		and float(weapon_fire_state.get("timer_frames", 0.0)) > 0.0
	)


func _is_net_gun_fire_animation_active(weapon_id: String, weapon_fire_state: Dictionary) -> bool:
	return (
		weapon_id == "net_gun"
		and bool(weapon_fire_state.get("active", false))
		and str(weapon_fire_state.get("weapon_id", "")) == "net_gun"
		and float(weapon_fire_state.get("timer_frames", 0.0)) > 0.0
	)


func _is_bazooka_fire_animation_active(weapon_id: String, weapon_fire_state: Dictionary) -> bool:
	return (
		weapon_id == "bazooka"
		and bool(weapon_fire_state.get("active", false))
		and str(weapon_fire_state.get("weapon_id", "")) == "bazooka"
		and float(weapon_fire_state.get("timer_frames", 0.0)) > 0.0
	)


func _is_bowling_trap_ui_animation_active(weapon_id: String, bowling_trap_state: Dictionary, bowling_traps: Array) -> bool:
	if weapon_id != "bowling_trap":
		return false
	if _get_bowling_trap_hud_trap(bowling_traps).is_empty() and not bool(bowling_trap_state.get("installing", false)):
		return false
	return (
		bool(bowling_trap_state.get("installing", false))
		or float(bowling_trap_state.get("install_pose_frames", 0.0)) > 0.0
		or float(bowling_trap_state.get("control_lock_frames", 0.0)) > 0.0
		or not _get_bowling_trap_hud_trap(bowling_traps).is_empty()
	)


func _is_bowling_trap_capture_ui_animation_active(weapon_id: String, bowling_traps: Array) -> bool:
	if weapon_id != "bowling_trap":
		return false
	return str(_get_bowling_trap_hud_trap(bowling_traps).get("state", "")) == "capturing"


func _is_bowling_trap_install_ui_animation_active(weapon_id: String, bowling_trap_state: Dictionary, bowling_traps: Array) -> bool:
	if weapon_id != "bowling_trap":
		return false
	return (
		str(_get_bowling_trap_hud_trap(bowling_traps).get("state", "")) == "installing"
		or bool(bowling_trap_state.get("installing", false))
	)


func _get_pistol_fire_recoil_frame(pistol_state: Dictionary) -> int:
	var fire_delay_frames: float = float(pistol_state.get("fire_delay_frames", 0.0))
	var fire_delay_max_frames: float = max(1.0, float(pistol_state.get("fire_delay_max_frames", 1.0)))
	if fire_delay_frames > 0.0:
		var windup_progress: float = clamp(1.0 - fire_delay_frames / fire_delay_max_frames, 0.0, 1.0)
		return clampi(
			int(windup_progress * float(PISTOL_FIRE_RECOIL_WINDUP_FRAME_COUNT)),
			0,
			PISTOL_FIRE_RECOIL_WINDUP_FRAME_COUNT - 1
		)
	var post_fire_frames: float = float(pistol_state.get("post_fire_animation_frames", 0.0))
	var post_fire_max_frames: float = max(1.0, float(pistol_state.get("post_fire_animation_max_frames", 1.0)))
	if post_fire_frames > 0.0:
		var post_progress: float = clamp(1.0 - post_fire_frames / post_fire_max_frames, 0.0, 1.0)
		return clampi(
			PISTOL_FIRE_RECOIL_WINDUP_FRAME_COUNT + int(post_progress * float(PISTOL_FIRE_RECOIL_POST_FRAME_COUNT)),
			PISTOL_FIRE_RECOIL_WINDUP_FRAME_COUNT,
			PISTOL_FIRE_RECOIL_FRAME_COUNT - 1
		)
	return 0


func _get_ak47_fire_recoil_frame(weapon_fire_state: Dictionary) -> int:
	var timer_frames: float = max(0.0, float(weapon_fire_state.get("timer_frames", 0.0)))
	var timer_max_frames: float = max(1.0, float(weapon_fire_state.get("timer_max_frames", 1.0)))
	var progress: float = clamp(1.0 - timer_frames / timer_max_frames, 0.0, 1.0)
	return clampi(int(progress * float(AK47_FIRE_RECOIL_FRAME_COUNT)), 0, AK47_FIRE_RECOIL_FRAME_COUNT - 1)


func _get_ak47_fire_recoil_rotation_degrees(weapon_id: String, weapon_fire_state: Dictionary) -> float:
	if not _is_ak47_fire_animation_active(weapon_id, weapon_fire_state):
		return 0.0
	var frame: int = _get_ak47_fire_recoil_frame(weapon_fire_state)
	return float(AK47_HUD_RECOIL_ROTATION_DEGREES_BY_FRAME[clampi(frame, 0, AK47_FIRE_RECOIL_FRAME_COUNT - 1)])


func _get_net_gun_fire_recoil_frame(weapon_fire_state: Dictionary) -> int:
	var timer_frames: float = max(0.0, float(weapon_fire_state.get("timer_frames", 0.0)))
	var timer_max_frames: float = max(1.0, float(weapon_fire_state.get("timer_max_frames", 1.0)))
	var progress: float = clamp(1.0 - timer_frames / timer_max_frames, 0.0, 1.0)
	return clampi(int(progress * float(NET_GUN_FIRE_RECOIL_FRAME_COUNT)), 0, NET_GUN_FIRE_RECOIL_FRAME_COUNT - 1)


func _get_net_gun_fire_recoil_kick_ratio(weapon_id: String, weapon_fire_state: Dictionary) -> float:
	if not _is_net_gun_fire_animation_active(weapon_id, weapon_fire_state):
		return 0.0
	var frame: int = _get_net_gun_fire_recoil_frame(weapon_fire_state)
	return float(NET_GUN_HUD_RECOIL_KICK_BY_FRAME[clampi(frame, 0, NET_GUN_FIRE_RECOIL_FRAME_COUNT - 1)])


func _get_bazooka_fire_recoil_frame(weapon_fire_state: Dictionary) -> int:
	var timer_frames: float = max(0.0, float(weapon_fire_state.get("timer_frames", 0.0)))
	var timer_max_frames: float = max(1.0, float(weapon_fire_state.get("timer_max_frames", 1.0)))
	var progress: float = clamp(1.0 - timer_frames / timer_max_frames, 0.0, 1.0)
	return clampi(int(progress * float(BAZOOKA_FIRE_RECOIL_FRAME_COUNT)), 0, BAZOOKA_FIRE_RECOIL_FRAME_COUNT - 1)


func _get_bowling_trap_ui_animation_frame(bowling_traps: Array) -> int:
	var hud_trap: Dictionary = _get_bowling_trap_hud_trap(bowling_traps)
	if str(hud_trap.get("state", "")) != "capturing":
		return 0
	var raw_progress: float = float(hud_trap.get("capture_progress", -1.0))
	var progress: float = clamp(raw_progress, 0.0, 1.0)
	if raw_progress < 0.0:
		var timer_frames: float = max(0.0, float(hud_trap.get("timer_frames", 0.0)))
		var timer_max_frames: float = max(1.0, float(hud_trap.get("max_timer_frames", 1.0)))
		progress = clamp(1.0 - timer_frames / timer_max_frames, 0.0, 1.0)
	return clampi(int(progress * float(BOWLING_TRAP_CAPTURE_FRAME_COUNT)), 0, BOWLING_TRAP_CAPTURE_FRAME_COUNT - 1)


func _get_bowling_trap_install_ui_animation_frame(bowling_trap_state: Dictionary, bowling_traps: Array) -> int:
	var hud_trap: Dictionary = _get_bowling_trap_hud_trap(bowling_traps)
	var raw_progress: float = float(hud_trap.get("install_progress", bowling_trap_state.get("install_progress", -1.0)))
	var progress: float = clamp(raw_progress, 0.0, 1.0)
	if raw_progress < 0.0:
		var timer_frames: float = max(0.0, float(hud_trap.get("timer_frames", 0.0)))
		var timer_max_frames: float = max(1.0, float(hud_trap.get("max_timer_frames", 1.0)))
		progress = clamp(1.0 - timer_frames / timer_max_frames, 0.0, 1.0)
	return clampi(int(progress * float(BOWLING_TRAP_INSTALL_FRAME_COUNT)), 0, BOWLING_TRAP_INSTALL_FRAME_COUNT - 1)


func _get_suicide_drone_hover_frame() -> int:
	var elapsed_frames: int = int(floor(float(Time.get_ticks_msec()) / SUICIDE_DRONE_HOVER_FRAME_MSEC))
	return elapsed_frames % SUICIDE_DRONE_HOVER_FRAME_COUNT


func _get_bowling_trap_hud_trap(bowling_traps: Array) -> Dictionary:
	for preferred_state in ["capturing", "installing", "waiting"]:
		for trap_value in bowling_traps:
			var trap: Dictionary = _get_dict(trap_value)
			if str(trap.get("state", "")) == preferred_state:
				return trap
	return {}


func _get_bowling_trap_motion_rect(rect: Rect2, bowling_trap_state: Dictionary, hud_trap: Dictionary, scale_factor: float) -> Rect2:
	var trap_state: String = str(hud_trap.get("state", ""))
	if trap_state == "installing":
		var install_progress: float = clamp(float(hud_trap.get("install_progress", bowling_trap_state.get("install_progress", 0.0))), 0.0, 1.0)
		var install_scale: float = 0.92 + 0.12 * sin(install_progress * PI * 0.5)
		var install_y: float = (1.0 - install_progress) * 4.0 * scale_factor
		return _scale_rect_around_pivot(Rect2(rect.position + Vector2(0.0, install_y), rect.size), install_scale, BOWLING_TRAP_HUD_MOTION_PIVOT_RATIO)
	var phase: float = float(Time.get_ticks_msec()) * 0.012
	var pulse: float = 0.5 + 0.5 * sin(phase)
	var bob: float = -1.8 * sin(phase) * scale_factor
	return _scale_rect_around_pivot(Rect2(rect.position + Vector2(0.0, bob), rect.size), 1.0 + 0.035 * pulse, BOWLING_TRAP_HUD_MOTION_PIVOT_RATIO)


func _get_bowling_trap_motion_rotation(bowling_trap_state: Dictionary, hud_trap: Dictionary) -> float:
	var trap_state: String = str(hud_trap.get("state", ""))
	if trap_state == "installing":
		var install_progress: float = clamp(float(hud_trap.get("install_progress", bowling_trap_state.get("install_progress", 0.0))), 0.0, 1.0)
		return lerpf(-0.08, 0.03, install_progress)
	return sin(float(Time.get_ticks_msec()) * 0.012) * 0.045


func _get_pistol_fire_recoil_source_rect(sheet: Texture2D, frame: int) -> Rect2:
	var frame_index: int = clampi(frame, 0, PISTOL_FIRE_RECOIL_FRAME_COUNT - 1)
	var texture_size: Vector2 = sheet.get_size()
	var cell_w: float = texture_size.x / float(PISTOL_FIRE_RECOIL_GRID_COLS)
	var cell_h: float = texture_size.y / float(PISTOL_FIRE_RECOIL_GRID_ROWS)
	var col: int = frame_index % PISTOL_FIRE_RECOIL_GRID_COLS
	@warning_ignore("integer_division")
	var row: int = int(frame_index / PISTOL_FIRE_RECOIL_GRID_COLS)
	return Rect2(float(col) * cell_w, float(row) * cell_h, cell_w, cell_h)


func _get_ak47_fire_recoil_source_rect(sheet: Texture2D, frame: int) -> Rect2:
	var frame_index: int = clampi(frame, 0, AK47_FIRE_RECOIL_FRAME_COUNT - 1)
	var texture_size: Vector2 = sheet.get_size()
	var cell_w: float = texture_size.x / float(AK47_FIRE_RECOIL_GRID_COLS)
	var cell_h: float = texture_size.y / float(AK47_FIRE_RECOIL_GRID_ROWS)
	var col: int = frame_index % AK47_FIRE_RECOIL_GRID_COLS
	@warning_ignore("integer_division")
	var row: int = int(frame_index / AK47_FIRE_RECOIL_GRID_COLS)
	return Rect2(float(col) * cell_w, float(row) * cell_h, cell_w, cell_h)


func _get_net_gun_fire_recoil_source_rect(sheet: Texture2D, frame: int) -> Rect2:
	var frame_index: int = clampi(frame, 0, NET_GUN_FIRE_RECOIL_FRAME_COUNT - 1)
	var texture_size: Vector2 = sheet.get_size()
	var cell_w: float = texture_size.x / float(NET_GUN_FIRE_RECOIL_GRID_COLS)
	var cell_h: float = texture_size.y / float(NET_GUN_FIRE_RECOIL_GRID_ROWS)
	var col: int = frame_index % NET_GUN_FIRE_RECOIL_GRID_COLS
	@warning_ignore("integer_division")
	var row: int = int(frame_index / NET_GUN_FIRE_RECOIL_GRID_COLS)
	return Rect2(float(col) * cell_w, float(row) * cell_h, cell_w, cell_h)


func _get_bazooka_fire_recoil_source_rect(sheet: Texture2D, frame: int) -> Rect2:
	var frame_index: int = clampi(frame, 0, BAZOOKA_FIRE_RECOIL_FRAME_COUNT - 1)
	var texture_size: Vector2 = sheet.get_size()
	var cell_w: float = texture_size.x / float(BAZOOKA_FIRE_RECOIL_GRID_COLS)
	var cell_h: float = texture_size.y / float(BAZOOKA_FIRE_RECOIL_GRID_ROWS)
	var col: int = frame_index % BAZOOKA_FIRE_RECOIL_GRID_COLS
	@warning_ignore("integer_division")
	var row: int = int(frame_index / BAZOOKA_FIRE_RECOIL_GRID_COLS)
	return Rect2(float(col) * cell_w, float(row) * cell_h, cell_w, cell_h)


func _get_bowling_trap_install_source_rect(sheet: Texture2D, frame: int) -> Rect2:
	var frame_index: int = clampi(frame, 0, BOWLING_TRAP_INSTALL_FRAME_COUNT - 1)
	var texture_size: Vector2 = sheet.get_size()
	var cell_w: float = texture_size.x / float(BOWLING_TRAP_INSTALL_GRID_COLS)
	var cell_h: float = texture_size.y / float(BOWLING_TRAP_INSTALL_GRID_ROWS)
	var col: int = frame_index % BOWLING_TRAP_INSTALL_GRID_COLS
	@warning_ignore("integer_division")
	var row: int = int(frame_index / BOWLING_TRAP_INSTALL_GRID_COLS)
	return Rect2(float(col) * cell_w, float(row) * cell_h, cell_w, cell_h)


func _get_bowling_trap_capture_source_rect(sheet: Texture2D, frame: int) -> Rect2:
	var frame_index: int = clampi(frame, 0, BOWLING_TRAP_CAPTURE_FRAME_COUNT - 1)
	var texture_size: Vector2 = sheet.get_size()
	var cell_w: float = texture_size.x / float(BOWLING_TRAP_CAPTURE_GRID_COLS)
	var cell_h: float = texture_size.y / float(BOWLING_TRAP_CAPTURE_GRID_ROWS)
	var col: int = frame_index % BOWLING_TRAP_CAPTURE_GRID_COLS
	@warning_ignore("integer_division")
	var row: int = int(frame_index / BOWLING_TRAP_CAPTURE_GRID_COLS)
	return Rect2(float(col) * cell_w, float(row) * cell_h, cell_w, cell_h)


func _get_suicide_drone_hover_source_rect(sheet: Texture2D, frame: int) -> Rect2:
	var frame_index: int = clampi(frame, 0, SUICIDE_DRONE_HOVER_FRAME_COUNT - 1)
	var texture_size: Vector2 = sheet.get_size()
	var cell_w: float = texture_size.x / float(SUICIDE_DRONE_HOVER_GRID_COLS)
	var cell_h: float = texture_size.y / float(SUICIDE_DRONE_HOVER_GRID_ROWS)
	var col: int = frame_index % SUICIDE_DRONE_HOVER_GRID_COLS
	@warning_ignore("integer_division")
	var row: int = int(frame_index / SUICIDE_DRONE_HOVER_GRID_COLS)
	return Rect2(float(col) * cell_w, float(row) * cell_h, cell_w, cell_h)


func _get_cached_weapon_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if bool(_weapon_texture_checked.get(path, false)):
		var cached = _weapon_texture_cache.get(path, null)
		if cached is Texture2D:
			return cached
		return null
	_weapon_texture_checked[path] = true
	var texture: Texture2D = ProjectResourceLoader.load_texture(path, "", "")
	_weapon_texture_cache[path] = texture
	return texture


func _scale_rect_around_pivot(rect: Rect2, scale: float, pivot_ratio: Vector2) -> Rect2:
	if is_equal_approx(scale, 1.0):
		return rect
	var safe_scale: float = max(0.01, scale)
	var pivot := rect.position + Vector2(
		rect.size.x * pivot_ratio.x,
		rect.size.y * pivot_ratio.y
	)
	var scaled_size := rect.size * safe_scale
	var scaled_position := pivot - Vector2(
		scaled_size.x * pivot_ratio.x,
		scaled_size.y * pivot_ratio.y
	)
	return Rect2(scaled_position, scaled_size)


func _draw_texture_rect_region_rotated(
	canvas: CanvasItem,
	texture: Texture2D,
	source_rect: Rect2,
	target_rect: Rect2,
	modulate: Color,
	rotation_radians: float,
	pivot_ratio: Vector2
) -> void:
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var pivot := target_rect.position + Vector2(
		target_rect.size.x * pivot_ratio.x,
		target_rect.size.y * pivot_ratio.y
	)
	var cos_r: float = cos(rotation_radians)
	var sin_r: float = sin(rotation_radians)
	var corners := [
		target_rect.position,
		Vector2(target_rect.end.x, target_rect.position.y),
		target_rect.end,
		Vector2(target_rect.position.x, target_rect.end.y),
	]
	var points := PackedVector2Array()
	for corner in corners:
		var offset: Vector2 = corner - pivot
		points.append(pivot + Vector2(
			offset.x * cos_r - offset.y * sin_r,
			offset.x * sin_r + offset.y * cos_r
		))
	var uv_min := Vector2(source_rect.position.x / texture_size.x, source_rect.position.y / texture_size.y)
	var uv_max := Vector2(source_rect.end.x / texture_size.x, source_rect.end.y / texture_size.y)
	var uvs := PackedVector2Array([
		Vector2(uv_min.x, uv_min.y),
		Vector2(uv_max.x, uv_min.y),
		Vector2(uv_max.x, uv_max.y),
		Vector2(uv_min.x, uv_max.y),
	])
	var colors := PackedColorArray([modulate, modulate, modulate, modulate])
	canvas.draw_polygon(points, colors, uvs, texture)


func _draw_slingshot_picture(canvas: CanvasItem, rect: Rect2, color: Color, alpha: float, scale_factor: float) -> void:
	var cx: float = rect.position.x + rect.size.x * 0.5
	var fork_y: float = rect.position.y + rect.size.y * 0.32
	var grip_bottom := Vector2(cx, rect.position.y + rect.size.y * 0.84)
	var joint := Vector2(cx, rect.position.y + rect.size.y * 0.52)
	var left := Vector2(rect.position.x + rect.size.x * 0.24, fork_y)
	var right := Vector2(rect.position.x + rect.size.x * 0.76, fork_y)
	canvas.draw_line(grip_bottom + Vector2(2.0, 3.0) * scale_factor, joint + Vector2(2.0, 3.0) * scale_factor, Color(0.0, 0.0, 0.0, 0.26 * alpha), max(2.0, 5.0 * scale_factor), true)
	canvas.draw_line(grip_bottom, joint, Color(0.22, 0.17, 0.10, alpha), max(2.0, 5.0 * scale_factor), true)
	canvas.draw_line(joint, left, Color(0.36, 0.28, 0.16, alpha), max(2.0, 4.0 * scale_factor), true)
	canvas.draw_line(joint, right, Color(0.36, 0.28, 0.16, alpha), max(2.0, 4.0 * scale_factor), true)
	canvas.draw_line(left, right, Color(color.r, color.g, color.b, 0.86 * alpha), max(1.0, 2.0 * scale_factor), true)
	canvas.draw_circle(Vector2(cx, fork_y + 2.0 * scale_factor), 4.0 * scale_factor, Color(0.82, 0.84, 0.86, alpha))
	canvas.draw_circle(Vector2(cx - 1.5 * scale_factor, fork_y), 1.8 * scale_factor, Color(1.0, 1.0, 0.94, 0.86 * alpha))


func _draw_ak47_picture(canvas: CanvasItem, rect: Rect2, alpha: float, scale_factor: float) -> void:
	var y: float = rect.position.y + rect.size.y * 0.42
	var x: float = rect.position.x + rect.size.x * 0.10
	var wood_dark := Color(0.34, 0.21, 0.10, alpha)
	var wood_mid := Color(0.55, 0.34, 0.16, alpha)
	var metal_dark := Color(0.08, 0.08, 0.09, alpha)
	var metal_mid := Color(0.25, 0.25, 0.27, alpha)
	_draw_ellipse(canvas, Rect2(Vector2(x + rect.size.x * 0.12, y + rect.size.y * 0.27), Vector2(rect.size.x * 0.55, rect.size.y * 0.12)), Color(0.0, 0.0, 0.0, 0.28 * alpha))
	var stock := PackedVector2Array([
		Vector2(x, y),
		Vector2(x + rect.size.x * 0.17, y + rect.size.y * 0.02),
		Vector2(x + rect.size.x * 0.17, y + rect.size.y * 0.20),
		Vector2(x - rect.size.x * 0.02, y + rect.size.y * 0.26),
	])
	canvas.draw_colored_polygon(stock, wood_dark)
	canvas.draw_line(Vector2(x + rect.size.x * 0.03, y + rect.size.y * 0.07), Vector2(x + rect.size.x * 0.14, y + rect.size.y * 0.07), wood_mid, max(1.0, scale_factor), true)
	canvas.draw_rect(Rect2(Vector2(x + rect.size.x * 0.16, y), Vector2(rect.size.x * 0.43, rect.size.y * 0.16)), metal_dark, true)
	canvas.draw_rect(Rect2(Vector2(x + rect.size.x * 0.17, y + scale_factor), Vector2(rect.size.x * 0.40, rect.size.y * 0.05)), metal_mid, true)
	canvas.draw_rect(Rect2(Vector2(x + rect.size.x * 0.49, y + rect.size.y * 0.02), Vector2(rect.size.x * 0.22, rect.size.y * 0.11)), wood_mid, true)
	canvas.draw_rect(Rect2(Vector2(x + rect.size.x * 0.69, y + rect.size.y * 0.04), Vector2(rect.size.x * 0.20, rect.size.y * 0.05)), metal_dark, true)
	canvas.draw_rect(Rect2(Vector2(x + rect.size.x * 0.88, y + rect.size.y * 0.025), Vector2(rect.size.x * 0.08, rect.size.y * 0.08)), metal_mid, true)
	var grip := PackedVector2Array([
		Vector2(x + rect.size.x * 0.38, y + rect.size.y * 0.14),
		Vector2(x + rect.size.x * 0.50, y + rect.size.y * 0.14),
		Vector2(x + rect.size.x * 0.45, y + rect.size.y * 0.52),
		Vector2(x + rect.size.x * 0.32, y + rect.size.y * 0.46),
	])
	canvas.draw_colored_polygon(grip, wood_dark)
	var magazine := PackedVector2Array([
		Vector2(x + rect.size.x * 0.54, y + rect.size.y * 0.14),
		Vector2(x + rect.size.x * 0.68, y + rect.size.y * 0.15),
		Vector2(x + rect.size.x * 0.60, y + rect.size.y * 0.52),
		Vector2(x + rect.size.x * 0.49, y + rect.size.y * 0.47),
	])
	canvas.draw_colored_polygon(magazine, Color(0.05, 0.05, 0.06, alpha))


func _draw_pistol_picture(canvas: CanvasItem, rect: Rect2, alpha: float, scale_factor: float) -> void:
	var x: float = rect.position.x + rect.size.x * 0.18
	var y: float = rect.position.y + rect.size.y * 0.34
	_draw_ellipse(canvas, Rect2(Vector2(x + rect.size.x * 0.10, y + rect.size.y * 0.40), Vector2(rect.size.x * 0.56, rect.size.y * 0.12)), Color(0.0, 0.0, 0.0, 0.28 * alpha))
	canvas.draw_rect(Rect2(Vector2(x, y), Vector2(rect.size.x * 0.62, rect.size.y * 0.18)), Color(0.12, 0.13, 0.15, alpha), true)
	canvas.draw_rect(Rect2(Vector2(x + 2.0 * scale_factor, y + 2.0 * scale_factor), Vector2(rect.size.x * 0.50, rect.size.y * 0.05)), Color(0.34, 0.34, 0.38, alpha), true)
	canvas.draw_rect(Rect2(Vector2(x + rect.size.x * 0.58, y + rect.size.y * 0.04), Vector2(rect.size.x * 0.16, rect.size.y * 0.08)), Color(0.08, 0.08, 0.09, alpha), true)
	var grip := PackedVector2Array([
		Vector2(x + rect.size.x * 0.26, y + rect.size.y * 0.16),
		Vector2(x + rect.size.x * 0.43, y + rect.size.y * 0.16),
		Vector2(x + rect.size.x * 0.48, y + rect.size.y * 0.52),
		Vector2(x + rect.size.x * 0.30, y + rect.size.y * 0.58),
	])
	canvas.draw_colored_polygon(grip, Color(0.09, 0.09, 0.11, alpha))
	canvas.draw_rect(Rect2(Vector2(x + rect.size.x * 0.18, y + rect.size.y * 0.17), Vector2(rect.size.x * 0.20, rect.size.y * 0.12)), Color(0.06, 0.06, 0.07, alpha), false, max(1.0, scale_factor))


func _draw_beretta_picture(canvas: CanvasItem, rect: Rect2, alpha: float, scale_factor: float) -> void:
	var x: float = rect.position.x + rect.size.x * 0.12
	var y: float = rect.position.y + rect.size.y * 0.31
	_draw_ellipse(canvas, Rect2(Vector2(x + rect.size.x * 0.15, y + rect.size.y * 0.44), Vector2(rect.size.x * 0.66, rect.size.y * 0.13)), Color(0.0, 0.0, 0.0, 0.30 * alpha))
	canvas.draw_rect(Rect2(Vector2(x, y), Vector2(rect.size.x * 0.72, rect.size.y * 0.16)), Color(0.08, 0.09, 0.10, alpha), true)
	canvas.draw_rect(Rect2(Vector2(x + 2.0 * scale_factor, y + 2.0 * scale_factor), Vector2(rect.size.x * 0.58, rect.size.y * 0.045)), Color(0.60, 0.62, 0.64, 0.86 * alpha), true)
	canvas.draw_rect(Rect2(Vector2(x + rect.size.x * 0.34, y + rect.size.y * 0.035), Vector2(rect.size.x * 0.12, rect.size.y * 0.06)), Color(0.02, 0.02, 0.025, alpha), true)
	canvas.draw_rect(Rect2(Vector2(x + rect.size.x * 0.68, y + rect.size.y * 0.045), Vector2(rect.size.x * 0.16, rect.size.y * 0.07)), Color(0.16, 0.16, 0.18, alpha), true)
	var trigger_guard := Rect2(Vector2(x + rect.size.x * 0.23, y + rect.size.y * 0.17), Vector2(rect.size.x * 0.22, rect.size.y * 0.15))
	canvas.draw_rect(trigger_guard, Color(0.05, 0.05, 0.055, alpha), false, max(1.0, scale_factor))
	var grip := PackedVector2Array([
		Vector2(x + rect.size.x * 0.37, y + rect.size.y * 0.15),
		Vector2(x + rect.size.x * 0.55, y + rect.size.y * 0.15),
		Vector2(x + rect.size.x * 0.61, y + rect.size.y * 0.60),
		Vector2(x + rect.size.x * 0.42, y + rect.size.y * 0.64),
	])
	canvas.draw_colored_polygon(grip, Color(0.045, 0.045, 0.055, alpha))
	canvas.draw_line(Vector2(x + rect.size.x * 0.45, y + rect.size.y * 0.25), Vector2(x + rect.size.x * 0.54, y + rect.size.y * 0.54), Color(0.34, 0.34, 0.36, 0.72 * alpha), max(1.0, scale_factor), true)


func _draw_net_gun_picture(canvas: CanvasItem, rect: Rect2, alpha: float, scale_factor: float) -> void:
	var body := Rect2(rect.position + Vector2(rect.size.x * 0.12, rect.size.y * 0.32), Vector2(rect.size.x * 0.52, rect.size.y * 0.22))
	_draw_ellipse(canvas, Rect2(rect.position + Vector2(rect.size.x * 0.12, rect.size.y * 0.70), Vector2(rect.size.x * 0.62, rect.size.y * 0.12)), Color(0.0, 0.0, 0.0, 0.25 * alpha))
	canvas.draw_rect(body, Color(0.16, 0.42, 0.78, alpha), true)
	canvas.draw_rect(Rect2(body.position + Vector2(1.5, 1.5) * scale_factor, Vector2(body.size.x - 3.0 * scale_factor, body.size.y * 0.34)), Color(0.36, 0.70, 1.0, 0.82 * alpha), true)
	canvas.draw_circle(rect.position + Vector2(rect.size.x * 0.32, rect.size.y * 0.64), rect.size.x * 0.15, Color(0.38, 0.70, 1.0, alpha))
	canvas.draw_circle(rect.position + Vector2(rect.size.x * 0.32, rect.size.y * 0.64), rect.size.x * 0.08, Color(0.12, 0.30, 0.56, alpha))
	canvas.draw_circle(rect.position + Vector2(rect.size.x * 0.73, rect.size.y * 0.40), rect.size.x * 0.16, Color(0.38, 0.78, 1.0, alpha))
	canvas.draw_circle(rect.position + Vector2(rect.size.x * 0.73, rect.size.y * 0.40), rect.size.x * 0.07, Color(0.08, 0.22, 0.45, alpha))
	canvas.draw_rect(Rect2(Vector2(body.end.x, body.position.y + body.size.y * 0.30), Vector2(rect.size.x * 0.20, body.size.y * 0.32)), Color(0.20, 0.62, 0.94, alpha), true)
	for i in range(3):
		var angle: float = -0.55 + float(i) * 0.55
		var start := rect.position + Vector2(rect.size.x * 0.78, rect.size.y * 0.40)
		canvas.draw_line(start, start + Vector2(cos(angle), sin(angle)) * rect.size.x * 0.28, Color(0.32, 0.92, 1.0, 0.50 * alpha), max(1.0, scale_factor), true)


func _draw_bazooka_picture(canvas: CanvasItem, rect: Rect2, alpha: float, scale_factor: float) -> void:
	var start := rect.position + Vector2(rect.size.x * 0.12, rect.size.y * 0.56)
	var end := rect.position + Vector2(rect.size.x * 0.88, rect.size.y * 0.34)
	canvas.draw_line(start + Vector2(2.0, 3.0) * scale_factor, end + Vector2(2.0, 3.0) * scale_factor, Color(0.0, 0.0, 0.0, 0.30 * alpha), max(4.0, 8.0 * scale_factor), true)
	canvas.draw_line(start, end, Color(0.42, 0.28, 0.20, alpha), max(4.0, 8.0 * scale_factor), true)
	canvas.draw_line(start + Vector2(2.0, -1.0) * scale_factor, end + Vector2(2.0, -1.0) * scale_factor, Color(0.72, 0.50, 0.32, 0.78 * alpha), max(1.0, 2.0 * scale_factor), true)
	canvas.draw_circle(end, 6.0 * scale_factor, Color(0.12, 0.12, 0.12, alpha))
	canvas.draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.38, rect.size.y * 0.48), Vector2(rect.size.x * 0.16, rect.size.y * 0.25)), Color(0.14, 0.12, 0.10, alpha), true)


func _draw_fire_support_picture(canvas: CanvasItem, rect: Rect2, alpha: float, scale_factor: float) -> void:
	var c := rect.get_center()
	var plane := PackedVector2Array([
		c + Vector2(-rect.size.x * 0.42, rect.size.y * 0.07),
		c + Vector2(rect.size.x * 0.18, -rect.size.y * 0.17),
		c + Vector2(rect.size.x * 0.43, -rect.size.y * 0.05),
		c + Vector2(rect.size.x * 0.08, rect.size.y * 0.15),
	])
	canvas.draw_colored_polygon(plane, Color(0.18, 0.22, 0.25, alpha))
	canvas.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-rect.size.x * 0.05, -rect.size.y * 0.06),
		c + Vector2(rect.size.x * 0.28, -rect.size.y * 0.30),
		c + Vector2(rect.size.x * 0.14, rect.size.y * 0.02),
	]), Color(0.30, 0.34, 0.38, alpha))
	canvas.draw_line(c + Vector2(-rect.size.x * 0.34, rect.size.y * 0.05), c + Vector2(rect.size.x * 0.34, -rect.size.y * 0.08), Color(0.65, 0.82, 0.88, 0.70 * alpha), max(1.0, scale_factor), true)
	canvas.draw_circle(c + Vector2(rect.size.x * 0.18, rect.size.y * 0.24), 3.0 * scale_factor, Color(1.0, 0.45, 0.18, 0.84 * alpha))


func _draw_bowling_trap_picture(canvas: CanvasItem, rect: Rect2, alpha: float, scale_factor: float) -> void:
	var base := Rect2(rect.position + Vector2(rect.size.x * 0.18, rect.size.y * 0.68), Vector2(rect.size.x * 0.64, rect.size.y * 0.12))
	_draw_ellipse(canvas, Rect2(base.position + Vector2(0.0, 3.0 * scale_factor), base.size), Color(0.0, 0.0, 0.0, 0.26 * alpha))
	canvas.draw_rect(base, Color(0.18, 0.18, 0.20, alpha), true)
	canvas.draw_rect(Rect2(base.position, Vector2(base.size.x, base.size.y * 0.38)), Color(0.46, 0.44, 0.38, alpha), true)
	var core := rect.position + Vector2(rect.size.x * 0.50, rect.size.y * 0.40)
	canvas.draw_circle(core, rect.size.x * 0.12, Color(0.84, 0.84, 0.82, alpha))
	canvas.draw_line(core, rect.position + Vector2(rect.size.x * 0.23, rect.size.y * 0.20), Color(0.22, 0.44, 0.18, alpha), max(2.0, 3.0 * scale_factor), true)
	canvas.draw_line(core, rect.position + Vector2(rect.size.x * 0.77, rect.size.y * 0.20), Color(0.22, 0.44, 0.18, alpha), max(2.0, 3.0 * scale_factor), true)
	canvas.draw_line(rect.position + Vector2(rect.size.x * 0.24, rect.size.y * 0.20), rect.position + Vector2(rect.size.x * 0.33, rect.size.y * 0.33), Color(0.72, 0.78, 0.58, alpha), max(1.0, scale_factor), true)
	canvas.draw_line(rect.position + Vector2(rect.size.x * 0.76, rect.size.y * 0.20), rect.position + Vector2(rect.size.x * 0.67, rect.size.y * 0.33), Color(0.72, 0.78, 0.58, alpha), max(1.0, scale_factor), true)


func _draw_drone_picture(canvas: CanvasItem, rect: Rect2, alpha: float, scale_factor: float) -> void:
	var c := rect.get_center()
	_draw_ellipse(canvas, Rect2(c + Vector2(-rect.size.x * 0.25, rect.size.y * 0.24), Vector2(rect.size.x * 0.50, rect.size.y * 0.12)), Color(0.0, 0.0, 0.0, 0.24 * alpha))
	canvas.draw_rect(Rect2(c - Vector2(rect.size.x * 0.16, rect.size.y * 0.11), Vector2(rect.size.x * 0.32, rect.size.y * 0.22)), Color(0.24, 0.28, 0.34, alpha), true)
	canvas.draw_circle(c + Vector2(0.0, -rect.size.y * 0.01), rect.size.x * 0.08, Color(0.70, 0.90, 1.0, alpha))
	for offset in [Vector2(-0.34, -0.22), Vector2(0.34, -0.22), Vector2(-0.34, 0.22), Vector2(0.34, 0.22)]:
		var rotor := c + Vector2(rect.size.x * offset.x, rect.size.y * offset.y)
		canvas.draw_line(c, rotor, Color(0.30, 0.34, 0.38, alpha), max(1.0, 2.0 * scale_factor), true)
		canvas.draw_circle(rotor, rect.size.x * 0.11, Color(0.10, 0.12, 0.14, alpha))
		canvas.draw_line(rotor + Vector2(-rect.size.x * 0.12, 0.0), rotor + Vector2(rect.size.x * 0.12, 0.0), Color(0.66, 0.74, 0.78, 0.78 * alpha), max(1.0, scale_factor), true)


func _build_slingshot_status_text(state: Dictionary) -> String:
	if bool(state.get("charging", false)):
		var charge_level: int = int(state.get("charge_level", 0))
		if charge_level > 0:
			return "차징 %d단계" % clampi(charge_level, 1, 3)
		return "차징 중"
	var cooldown_frames: float = max(0.0, float(state.get("cooldown_frames", 0.0)))
	if cooldown_frames > 0.0:
		return "쿨다운 %.1f초" % (cooldown_frames / 60.0)
	return "대기"


func _draw_slingshot_meter(canvas: CanvasItem, rect: Rect2, scale_factor: float, state: Dictionary, color: Color) -> void:
	var meter_state: Dictionary = build_slingshot_meter_state(rect, scale_factor, state, color)
	var meter_rect: Rect2 = _get_rect(meter_state.get("rect", Rect2()))
	canvas.draw_rect(meter_rect.grow(1.0 * scale_factor), Color(0.0, 0.0, 0.0, 0.56), true)
	canvas.draw_rect(meter_rect, Color(0.13, 0.16, 0.15, 0.92), true)
	canvas.draw_rect(meter_rect, Color(0.56, 0.62, 0.62, 0.72), false, max(1.0, scale_factor))
	var fill_ratio: float = float(meter_state.get("fill_ratio", 0.0))
	var fill_color: Color = _get_color(meter_state.get("fill_color", Color(color.r, color.g, color.b, 0.82)), Color(color.r, color.g, color.b, 0.82))
	if fill_ratio > 0.0:
		var fill_rect := Rect2(meter_rect.position, Vector2(meter_rect.size.x * fill_ratio, meter_rect.size.y))
		_draw_slingshot_meter_fill(canvas, fill_rect, meter_state, fill_color, scale_factor)
	for i in range(1, 3):
		var x: float = meter_rect.position.x + meter_rect.size.x * float(i) / 3.0
		canvas.draw_line(
			Vector2(x, meter_rect.position.y - scale_factor),
			Vector2(x, meter_rect.end.y + scale_factor),
			Color(0.90, 0.95, 1.0, 0.70),
			max(1.0, scale_factor),
			true
		)


func _draw_base_pistol_status(canvas: CanvasItem, rect: Rect2, scale_factor: float, color: Color) -> void:
	var bar_rect := Rect2(rect.position + Vector2(0.0, 4.0 * scale_factor), Vector2(rect.size.x, max(12.0 * scale_factor, rect.size.y - 6.0 * scale_factor)))
	canvas.draw_rect(bar_rect.grow(1.0 * scale_factor), Color(0.0, 0.0, 0.0, 0.58), true)
	canvas.draw_rect(bar_rect, Color(0.12, 0.12, 0.14, 0.94), true)
	var bullet_scale: float = scale_factor * 0.78
	var bullet_width: float = 5.0 * bullet_scale
	var spacing: float = max(8.0 * scale_factor, (bar_rect.size.x - bullet_width) / 3.0)
	var total_width: float = bullet_width + spacing * 3.0
	var start_x: float = bar_rect.position.x + (bar_rect.size.x - total_width) * 0.5
	var bullet_y: float = bar_rect.position.y + max(1.0, (bar_rect.size.y - 11.0 * bullet_scale) * 0.5)
	for i in range(4):
		_draw_bullet_icon(
			canvas,
			Vector2(start_x + spacing * float(i), bullet_y),
			bullet_scale,
			true,
			Color(0.78, 0.45, 0.20),
			Color(min(1.0, color.r + 0.24), min(1.0, color.g + 0.18), min(1.0, color.b + 0.10))
		)
	var loop_center := bar_rect.get_center() + Vector2(0.0, -0.5 * scale_factor)
	var loop_w: float = 14.0 * scale_factor
	var loop_h: float = 6.0 * scale_factor
	canvas.draw_arc(loop_center - Vector2(loop_w * 0.25, 0.0), loop_h, PI * 0.25, PI * 1.75, 20, Color(0.78, 0.90, 0.76, 0.72), max(1.0, scale_factor), true)
	canvas.draw_arc(loop_center + Vector2(loop_w * 0.25, 0.0), loop_h, -PI * 0.75, PI * 0.75, 20, Color(0.78, 0.90, 0.76, 0.72), max(1.0, scale_factor), true)
	canvas.draw_rect(bar_rect, Color(0.44, 0.44, 0.48, 0.84), false, max(1.0, scale_factor))


func _draw_slingshot_meter_fill(canvas: CanvasItem, fill_rect: Rect2, meter_state: Dictionary, fallback_color: Color, scale_factor: float) -> void:
	if not bool(meter_state.get("fill_gradient_enabled", false)):
		canvas.draw_rect(fill_rect, fallback_color, true)
		return
	var start_color: Color = _get_color(meter_state.get("fill_gradient_start", fallback_color), fallback_color)
	var end_color: Color = _get_color(meter_state.get("fill_gradient_end", fallback_color), fallback_color)
	var segments: int = max(3, min(SLINGSHOT_METER_GRADIENT_SEGMENTS, int(ceil(fill_rect.size.x / max(1.0, 5.0 * scale_factor)))))
	for i in range(segments):
		var left_t: float = float(i) / float(segments)
		var right_t: float = float(i + 1) / float(segments)
		var x0: float = fill_rect.position.x + fill_rect.size.x * left_t
		var x1: float = fill_rect.position.x + fill_rect.size.x * right_t
		var segment_rect := Rect2(Vector2(x0, fill_rect.position.y), Vector2(max(1.0, x1 - x0), fill_rect.size.y))
		canvas.draw_rect(segment_rect, start_color.lerp(end_color, (left_t + right_t) * 0.5), true)
	var glow_alpha: float = clamp(float(meter_state.get("fill_glow_alpha", 0.0)), 0.0, 0.28)
	if glow_alpha > 0.0:
		canvas.draw_rect(fill_rect, Color(1.0, 1.0, 1.0, glow_alpha), true)


func build_slingshot_meter_state(rect: Rect2, scale_factor: float, state: Dictionary, color: Color) -> Dictionary:
	var safe_scale: float = max(0.55, scale_factor)
	var meter_height: float = max(5.0, 6.0 * safe_scale)
	var meter_rect := Rect2()
	if rect.size.y <= 30.0 * safe_scale:
		meter_rect = Rect2(
			Vector2(rect.position.x, rect.position.y + (rect.size.y - meter_height) * 0.5),
			Vector2(rect.size.x, meter_height)
		)
	else:
		var meter_width: float = min(rect.size.x - 8.0 * safe_scale, AMMO_AREA_SIZE.x * safe_scale)
		meter_rect = Rect2(
			Vector2(rect.position.x + (rect.size.x - meter_width) * 0.5, rect.end.y - 12.0 * safe_scale),
			Vector2(meter_width, meter_height)
		)
	var fill_ratio: float = 0.0
	var fill_color := Color(color.r, color.g, color.b, 0.82)
	var charging: bool = bool(state.get("charging", false))
	var charge_level: int = 0
	var charge_intensity: float = 0.0
	var fill_gradient_enabled := false
	var fill_gradient_start := Color(color.r * 0.72, color.g * 0.82, color.b * 0.70, 0.78)
	var fill_gradient_end := fill_color
	var fill_glow_alpha := 0.0
	if charging:
		fill_ratio = clamp(float(state.get("charge_ratio", 0.0)), 0.0, 1.0)
		charge_level = clampi(int(state.get("charge_level", 0)), 0, 3)
		if charge_level >= 3:
			fill_color = Color(1.0, 0.78, 0.28, 0.92)
		charge_intensity = clamp(fill_ratio * 0.88 + float(charge_level) * 0.12, 0.0, 1.0)
		fill_gradient_enabled = fill_ratio > 0.0
		fill_gradient_start = Color(
			clamp(color.r * (0.62 + charge_intensity * 0.34), 0.0, 1.0),
			clamp(color.g * (0.70 + charge_intensity * 0.28), 0.0, 1.0),
			clamp(color.b * (0.62 + charge_intensity * 0.20), 0.0, 1.0),
			0.76 + charge_intensity * 0.12
		)
		var hot_color := Color(1.0, 0.84, 0.34, 0.96)
		var charged_color := Color(
			clamp(color.r + 0.26 + charge_intensity * 0.24, 0.0, 1.0),
			clamp(color.g + 0.16 + charge_intensity * 0.18, 0.0, 1.0),
			clamp(color.b + 0.10, 0.0, 1.0),
			0.84 + charge_intensity * 0.12
		)
		fill_gradient_end = charged_color.lerp(hot_color, clamp(charge_intensity * 0.72, 0.0, 1.0))
		fill_glow_alpha = 0.04 + charge_intensity * 0.12
	else:
		var cooldown_max: float = max(1.0, float(state.get("cooldown_max_frames", 30.0)))
		var cooldown_frames: float = clamp(float(state.get("cooldown_frames", 0.0)), 0.0, cooldown_max)
		if cooldown_frames > 0.0:
			fill_ratio = 1.0 - cooldown_frames / cooldown_max
			fill_color = Color(0.65, 0.72, 0.68, 0.72)
	return {
		"rect": meter_rect,
		"charging": charging,
		"fill_ratio": fill_ratio,
		"fill_color": fill_color,
		"fill_gradient_enabled": fill_gradient_enabled,
		"fill_gradient_start": fill_gradient_start,
		"fill_gradient_end": fill_gradient_end,
		"fill_glow_alpha": fill_glow_alpha,
		"charge_intensity": charge_intensity,
		"charge_sweep_enabled": false,
		"moving_tick_enabled": false,
		"tick_ratio": fill_ratio,
	}


func build_ammo_icon_state(weapon: Dictionary, weapon_id: String) -> Dictionary:
	var ammo_max: int = int(weapon.get("ammo_max", -1))
	var ammo_current: int = int(weapon.get("ammo_current", -1))
	if ammo_max <= 0 or ammo_current < 0:
		return {}
	var reloading: bool = bool(weapon.get("reloading", false))
	var display_ammo: int = int(weapon.get("reload_display_ammo", ammo_current)) if reloading else ammo_current
	var display_slots: int = ammo_max
	var compressed: bool = false
	if weapon_id == "ak47":
		display_slots = 15
		compressed = true
	elif weapon_id == "fire_support":
		display_slots = FIRE_SUPPORT_AMMO_UI_SLOT_COUNT
	elif ammo_max > 12:
		display_slots = 12
		compressed = true
	var filled_slots: int = clampi(display_ammo, 0, display_slots)
	if weapon_id == "fire_support":
		filled_slots = clampi(int(ceil(float(display_ammo) / max(1.0, float(ammo_max)) * float(display_slots))), 0, display_slots)
	elif compressed:
		filled_slots = clampi(int(ceil(float(display_ammo) / max(1.0, float(ammo_max)) * float(display_slots))), 0, display_slots)
	var magazines_max: int = int(weapon.get("magazines_max", -1))
	var magazines_current: int = int(weapon.get("magazines_current", -1))
	var ammo_icon_style := "compact"
	var ammo_icon_texture_path := ""
	if weapon_id == "pistol" or weapon_id == "commando_pistol":
		ammo_icon_style = "pistol_bullet"
	elif weapon_id == "ak47":
		ammo_icon_style = "ak47_belt"
	elif weapon_id == "net_gun" or weapon_id == "suicide_drone":
		ammo_icon_style = "round_charge"
	elif weapon_id == "bowling_trap":
		ammo_icon_style = "segment_bar"
	elif weapon_id == "fire_support":
		ammo_icon_style = "fire_support_radio"
		ammo_icon_texture_path = FIRE_SUPPORT_RADIO_AMMO_TEXTURE_PATH
	return {
		"weapon_id": weapon_id,
		"ammo_current": ammo_current,
		"ammo_max": ammo_max,
		"display_ammo": clampi(display_ammo, 0, ammo_max),
		"display_slots": display_slots,
		"filled_slots": filled_slots,
		"compressed": compressed,
		"reloading": reloading,
		"magazines_current": magazines_current,
		"magazines_max": magazines_max,
		"ammo_icon_style": ammo_icon_style,
		"ammo_icon_texture_path": ammo_icon_texture_path,
	}


func _draw_ammo_icon_display(canvas: CanvasItem, rect: Rect2, scale_factor: float, state: Dictionary, color: Color) -> void:
	var weapon_id: String = str(state.get("weapon_id", ""))
	if weapon_id == "pistol" or weapon_id == "commando_pistol":
		_draw_pistol_ammo_icons(canvas, rect, scale_factor, state)
	elif weapon_id == "ak47":
		_draw_ak47_ammo_belt(canvas, rect, scale_factor, state)
	elif weapon_id in ["net_gun", "suicide_drone"]:
		_draw_round_ammo_icons(canvas, rect, scale_factor, state, color)
	elif weapon_id == "bowling_trap":
		_draw_segment_ammo_bar(canvas, rect, scale_factor, state, Color(0.55, 0.78, 0.48))
	elif weapon_id == "fire_support":
		_draw_fire_support_radio_ammo_icons(canvas, rect, scale_factor, state)
	else:
		_draw_compact_ammo_icons(canvas, rect, scale_factor, state, color)


func _draw_ak47_ammo_belt(canvas: CanvasItem, rect: Rect2, scale_factor: float, state: Dictionary) -> void:
	var slots: int = clampi(int(state.get("display_slots", 15)), 1, 18)
	var filled: int = clampi(int(state.get("filled_slots", 0)), 0, slots)
	var bar_rect := Rect2(rect.position + Vector2(0.0, 4.0 * scale_factor), Vector2(rect.size.x, max(12.0 * scale_factor, rect.size.y - 6.0 * scale_factor)))
	canvas.draw_rect(bar_rect.grow(1.0 * scale_factor), Color(0.0, 0.0, 0.0, 0.62), true)
	canvas.draw_rect(bar_rect, Color(0.13, 0.13, 0.15, 0.96), true)
	var gap: float = max(1.0, 1.0 * scale_factor)
	var bullet_w: float = max(2.0, (bar_rect.size.x - gap * float(slots + 1)) / float(slots))
	for i in range(slots):
		var bullet_rect := Rect2(
			Vector2(bar_rect.position.x + gap + float(i) * (bullet_w + gap), bar_rect.position.y + 2.0 * scale_factor),
			Vector2(bullet_w, bar_rect.size.y - 4.0 * scale_factor)
		)
		if i < filled:
			canvas.draw_rect(Rect2(bullet_rect.position, Vector2(bullet_rect.size.x, bullet_rect.size.y * 0.35)), Color(0.78, 0.42, 0.18, 1.0), true)
			canvas.draw_rect(Rect2(bullet_rect.position + Vector2(0.0, bullet_rect.size.y * 0.35), Vector2(bullet_rect.size.x, bullet_rect.size.y * 0.65)), Color(0.82, 0.66, 0.26, 1.0), true)
			canvas.draw_line(bullet_rect.position + Vector2(1.0 * scale_factor, 0.0), bullet_rect.position + Vector2(1.0 * scale_factor, bullet_rect.size.y), Color(1.0, 0.86, 0.42, 0.66), max(1.0, 0.7 * scale_factor), true)
		else:
			canvas.draw_rect(bullet_rect, Color(0.05, 0.05, 0.06, 0.92), true)
	canvas.draw_rect(bar_rect, Color(0.42, 0.42, 0.46, 0.90), false, max(1.0, scale_factor))


func _draw_pistol_ammo_icons(canvas: CanvasItem, rect: Rect2, scale_factor: float, state: Dictionary) -> void:
	var ammo_max: int = clampi(int(state.get("display_slots", 4)), 1, 12)
	var filled: int = clampi(int(state.get("filled_slots", 0)), 0, ammo_max)
	var compact: bool = ammo_max > 8
	var bullet_scale: float = min(scale_factor * (0.72 if compact else 0.88), rect.size.y / 12.0)
	var bullet_width: float = 5.0 * bullet_scale
	var minimum_spacing: float = (4.0 if compact else 7.0) * scale_factor
	var bullet_spacing: float = max(minimum_spacing, (rect.size.x - bullet_width) / max(1.0, float(ammo_max - 1)))
	var bullet_total_width: float = bullet_width + bullet_spacing * float(ammo_max - 1)
	var start_x: float = rect.position.x + (rect.size.x - bullet_total_width) * 0.5
	var bullet_height: float = max(7.0, 11.0 * bullet_scale)
	var bullet_y: float = rect.position.y + max(0.0, (rect.size.y - bullet_height) * 0.5)
	for i in range(ammo_max):
		_draw_bullet_icon(
			canvas,
			Vector2(start_x + bullet_spacing * float(i), bullet_y),
			bullet_scale,
			i < filled,
			Color(0.78, 0.45, 0.20),
			Color(0.88, 0.70, 0.24)
		)

	var magazines_max: int = int(state.get("magazines_max", -1))
	var magazines_current: int = int(state.get("magazines_current", -1))
	if magazines_max <= 0 or rect.size.y < 22.0 * scale_factor:
		return
	var mag_scale: float = min(scale_factor * 0.64, rect.size.y / 16.0)
	var mag_w: float = max(5.0, 7.0 * mag_scale)
	var mag_spacing: float = max(8.0 * mag_scale, mag_w + 3.0 * scale_factor)
	var mag_total_width: float = mag_w + mag_spacing * float(magazines_max - 1)
	var mag_start_x: float = rect.position.x + (rect.size.x - mag_total_width) * 0.5
	var mag_y: float = rect.end.y - max(8.0, 11.0 * mag_scale)
	for i in range(magazines_max):
		_draw_magazine_icon(canvas, Vector2(mag_start_x + mag_spacing * float(i), mag_y), mag_scale, i < magazines_current)


func _draw_round_ammo_icons(canvas: CanvasItem, rect: Rect2, scale_factor: float, state: Dictionary, color: Color) -> void:
	var slots: int = clampi(int(state.get("display_slots", 0)), 1, 6)
	var filled: int = clampi(int(state.get("filled_slots", 0)), 0, slots)
	var radius: float = min(7.0 * scale_factor, rect.size.y * 0.34)
	var spacing: float = (rect.size.x - radius * 2.0) / max(1.0, float(slots - 1))
	var start_x: float = rect.position.x + radius
	var y: float = rect.position.y + rect.size.y * 0.50
	for i in range(slots):
		var center := Vector2(start_x + spacing * float(i), y)
		if i < filled:
			canvas.draw_circle(center + Vector2(1.0, 1.0) * scale_factor, radius, Color(0.0, 0.0, 0.0, 0.22))
			canvas.draw_circle(center, radius, Color(min(1.0, color.r + 0.20), min(1.0, color.g + 0.22), min(1.0, color.b + 0.30), 0.96))
			canvas.draw_circle(center + Vector2(-radius * 0.30, -radius * 0.30), radius * 0.38, Color(1.0, 1.0, 1.0, 0.66))
		else:
			canvas.draw_circle(center, radius, Color(0.08, 0.08, 0.10, 0.86))
			canvas.draw_circle(center, radius, Color(0.22, 0.22, 0.25, 0.72), false, max(1.0, scale_factor))


func _draw_segment_ammo_bar(canvas: CanvasItem, rect: Rect2, scale_factor: float, state: Dictionary, color: Color) -> void:
	var slots: int = clampi(int(state.get("display_slots", 0)), 1, 8)
	var filled: int = clampi(int(state.get("filled_slots", 0)), 0, slots)
	var bar_rect := Rect2(rect.position + Vector2(0.0, rect.size.y * 0.35), Vector2(rect.size.x, max(5.0 * scale_factor, rect.size.y * 0.30)))
	canvas.draw_rect(bar_rect, Color(0.10, 0.12, 0.12, 0.92), true)
	var gap: float = max(1.0, scale_factor)
	var segment_w: float = (bar_rect.size.x - gap * float(slots + 1)) / float(slots)
	for i in range(slots):
		var segment := Rect2(Vector2(bar_rect.position.x + gap + float(i) * (segment_w + gap), bar_rect.position.y + gap), Vector2(segment_w, max(1.0, bar_rect.size.y - gap * 2.0)))
		canvas.draw_rect(segment, color if i < filled else Color(0.20, 0.22, 0.24, 0.86), true)
	canvas.draw_rect(bar_rect, Color(0.54, 0.58, 0.60, 0.78), false, max(1.0, scale_factor))


func _draw_fire_support_radio_ammo_icons(canvas: CanvasItem, rect: Rect2, scale_factor: float, state: Dictionary) -> void:
	var slots: int = clampi(int(state.get("display_slots", 0)), 1, FIRE_SUPPORT_AMMO_UI_SLOT_COUNT)
	var filled: int = clampi(int(state.get("filled_slots", 0)), 0, slots)
	var gap: float = max(4.0 * scale_factor, 7.0 * scale_factor)
	var icon_h: float = max(9.0 * scale_factor, min(14.5 * scale_factor, rect.size.y * 0.96))
	var icon_w: float = min(12.0 * scale_factor, icon_h * 0.78)
	icon_w = min(icon_w, max(5.0 * scale_factor, (rect.size.x - gap * float(slots - 1)) / float(slots)))
	var total_w: float = icon_w * float(slots) + gap * float(slots - 1)
	var start_x: float = rect.position.x + (rect.size.x - total_w) * 0.5
	var icon_y: float = rect.position.y + (rect.size.y - icon_h) * 0.5
	var texture: Texture2D = _get_cached_weapon_texture(FIRE_SUPPORT_RADIO_AMMO_TEXTURE_PATH)
	for i in range(slots):
		var icon_rect := Rect2(
			Vector2(start_x + float(i) * (icon_w + gap), icon_y),
			Vector2(icon_w, icon_h)
		)
		var slot_filled: bool = i < filled
		canvas.draw_rect(icon_rect.grow(0.75 * scale_factor), Color(0.0, 0.0, 0.0, 0.24 if slot_filled else 0.14), true)
		if texture is Texture2D:
			var tint := Color(1.0, 1.0, 1.0, 0.96) if slot_filled else Color(0.18, 0.18, 0.20, 0.50)
			canvas.draw_texture_rect_region(texture, icon_rect, FIRE_SUPPORT_RADIO_AMMO_SOURCE_RECT, tint, false, true)
		else:
			_draw_fire_support_radio_ammo_fallback(canvas, icon_rect, scale_factor, slot_filled)
		if not slot_filled:
			canvas.draw_rect(icon_rect.grow(0.45 * scale_factor), Color(0.31, 0.31, 0.35, 0.74), false, max(1.0, 0.75 * scale_factor))


func _draw_fire_support_radio_ammo_fallback(canvas: CanvasItem, rect: Rect2, scale_factor: float, filled: bool) -> void:
	var alpha: float = 0.96 if filled else 0.42
	var body_rect := Rect2(
		rect.position + Vector2(rect.size.x * 0.16, rect.size.y * 0.27),
		Vector2(rect.size.x * 0.68, rect.size.y * 0.66)
	)
	var antenna_top := Vector2(body_rect.position.x + body_rect.size.x * 0.30, rect.position.y + rect.size.y * 0.04)
	var antenna_bottom := Vector2(body_rect.position.x + body_rect.size.x * 0.42, body_rect.position.y + 1.0 * scale_factor)
	canvas.draw_line(antenna_bottom, antenna_top, Color(0.10, 0.11, 0.12, alpha), max(1.0, 1.5 * scale_factor), true)
	canvas.draw_rect(body_rect, Color(0.11, 0.12, 0.14, alpha), true)
	canvas.draw_rect(body_rect, Color(0.42, 0.44, 0.46, alpha * 0.80), false, max(1.0, 0.9 * scale_factor))
	for i in range(3):
		var grille_y: float = body_rect.position.y + body_rect.size.y * (0.24 + 0.13 * float(i))
		canvas.draw_line(
			Vector2(body_rect.position.x + body_rect.size.x * 0.23, grille_y),
			Vector2(body_rect.end.x - body_rect.size.x * 0.18, grille_y),
			Color(0.58, 0.60, 0.62, alpha * 0.72),
			max(1.0, 0.7 * scale_factor),
			true
		)
	if filled:
		canvas.draw_circle(body_rect.position + Vector2(body_rect.size.x * 0.72, body_rect.size.y * 0.13), max(1.0, 1.2 * scale_factor), Color(1.0, 0.20, 0.08, 0.94))


func _draw_compact_ammo_icons(canvas: CanvasItem, rect: Rect2, scale_factor: float, state: Dictionary, color: Color) -> void:
	var slots: int = clampi(int(state.get("display_slots", 0)), 1, 12)
	var filled: int = clampi(int(state.get("filled_slots", 0)), 0, slots)
	var icon_scale: float = scale_factor * (0.66 if bool(state.get("compressed", false)) else 0.78)
	var spacing: float = max(5.0 * scale_factor, (rect.size.x - 5.0 * icon_scale) / max(1.0, float(slots - 1)))
	var icon_width: float = 5.0 * icon_scale
	var total_width: float = icon_width + spacing * float(slots - 1)
	var start_x: float = rect.position.x + (rect.size.x - total_width) * 0.5
	var icon_y: float = rect.position.y + max(1.0, (rect.size.y - 11.0 * icon_scale) * 0.5)
	var tip_color: Color = Color(0.80, 0.46, 0.18)
	var body_color: Color = Color(
		min(1.0, color.r * 0.75 + 0.30),
		min(1.0, color.g * 0.75 + 0.24),
		min(1.0, color.b * 0.75 + 0.10),
		1.0
	)
	for i in range(slots):
		_draw_bullet_icon(canvas, Vector2(start_x + spacing * float(i), icon_y), icon_scale, i < filled, tip_color, body_color)


func _draw_bullet_icon(canvas: CanvasItem, pos: Vector2, scale_factor: float, filled: bool, tip_color: Color, body_color: Color) -> void:
	var w: float = max(3.0, 5.0 * scale_factor)
	var h: float = max(7.0, 11.0 * scale_factor)
	var tip_h: float = h * 0.42
	var cx: float = pos.x + w * 0.5
	if not filled:
		canvas.draw_rect(Rect2(pos + Vector2(-1.0, 0.0) * scale_factor, Vector2(w + 2.0 * scale_factor, h)), Color(0.08, 0.08, 0.09, 0.80), true)
		var empty_tip := PackedVector2Array([
			Vector2(cx, pos.y + 1.0 * scale_factor),
			Vector2(pos.x + 0.6 * scale_factor, pos.y + tip_h),
			Vector2(pos.x + w - 0.6 * scale_factor, pos.y + tip_h),
		])
		canvas.draw_colored_polygon(empty_tip, Color(0.19, 0.19, 0.21, 0.92))
		canvas.draw_rect(Rect2(Vector2(pos.x + 0.7 * scale_factor, pos.y + tip_h), Vector2(w - 1.4 * scale_factor, h - tip_h - 1.0 * scale_factor)), Color(0.16, 0.16, 0.18, 0.92), true)
		return
	canvas.draw_rect(Rect2(pos + Vector2(1.0, h - 1.5) * scale_factor, Vector2(w, 1.6 * scale_factor)), Color(0.0, 0.0, 0.0, 0.26), true)
	var tip_dark := PackedVector2Array([
		Vector2(cx, pos.y),
		Vector2(pos.x - 0.8 * scale_factor, pos.y + tip_h + 0.8 * scale_factor),
		Vector2(pos.x + w + 0.8 * scale_factor, pos.y + tip_h + 0.8 * scale_factor),
	])
	canvas.draw_colored_polygon(tip_dark, Color(tip_color.r * 0.62, tip_color.g * 0.62, tip_color.b * 0.62, 1.0))
	var tip := PackedVector2Array([
		Vector2(cx, pos.y + 0.8 * scale_factor),
		Vector2(pos.x, pos.y + tip_h),
		Vector2(pos.x + w, pos.y + tip_h),
	])
	canvas.draw_colored_polygon(tip, tip_color)
	var case_rect := Rect2(Vector2(pos.x, pos.y + tip_h), Vector2(w, h - tip_h - 1.0 * scale_factor))
	canvas.draw_rect(case_rect, body_color, true)
	canvas.draw_line(case_rect.position + Vector2(1.0, 0.8) * scale_factor, case_rect.position + Vector2(1.0, case_rect.size.y - 0.8 * scale_factor), Color(1.0, 0.92, 0.50, 0.78), max(1.0, 0.8 * scale_factor), true)
	canvas.draw_line(Vector2(case_rect.end.x - 0.6 * scale_factor, case_rect.position.y), Vector2(case_rect.end.x - 0.6 * scale_factor, case_rect.end.y), Color(0.28, 0.20, 0.08, 0.62), max(1.0, 0.8 * scale_factor), true)
	canvas.draw_rect(Rect2(Vector2(pos.x, case_rect.end.y), Vector2(w, max(1.0, 1.4 * scale_factor))), Color(0.46, 0.34, 0.13, 1.0), true)


func _draw_magazine_icon(canvas: CanvasItem, pos: Vector2, scale_factor: float, filled: bool) -> void:
	var w: float = max(5.0, 7.0 * scale_factor)
	var h: float = max(8.0, 11.0 * scale_factor)
	var rect := Rect2(pos, Vector2(w, h))
	if filled:
		canvas.draw_rect(rect, Color(0.16, 0.15, 0.12, 0.95), true)
		canvas.draw_rect(Rect2(pos + Vector2(1.0, 1.0) * scale_factor, Vector2(w - 2.0 * scale_factor, max(1.0, 2.2 * scale_factor))), Color(0.82, 0.62, 0.22, 0.95), true)
		canvas.draw_line(pos + Vector2(2.0, 4.5) * scale_factor, pos + Vector2(2.0, h - 2.0 * scale_factor), Color(0.35, 0.32, 0.26, 0.90), max(1.0, scale_factor), true)
		canvas.draw_rect(rect, Color(0.05, 0.05, 0.04, 0.92), false, max(1.0, scale_factor))
	else:
		canvas.draw_rect(rect, Color(0.11, 0.11, 0.13, 0.84), true)
		canvas.draw_rect(rect, Color(0.24, 0.24, 0.27, 0.86), false, max(1.0, scale_factor))
		canvas.draw_line(pos + Vector2(1.5, 1.5) * scale_factor, pos + Vector2(w - 1.5 * scale_factor, h - 1.5 * scale_factor), Color(0.34, 0.34, 0.38, 0.88), max(1.0, scale_factor), true)


func _get_weapon_color(weapon_id: String) -> Color:
	match weapon_id:
		"pistol":
			return Color(200.0 / 255.0, 180.0 / 255.0, 120.0 / 255.0)
		"net_gun":
			return Color(100.0 / 255.0, 180.0 / 255.0, 100.0 / 255.0)
		"fire_support", "suicide_drone":
			return Color(1.0, 100.0 / 255.0, 50.0 / 255.0)
		"bowling_trap":
			return Color(200.0 / 255.0, 80.0 / 255.0, 80.0 / 255.0)
		"bazooka":
			return Color(220.0 / 255.0, 120.0 / 255.0, 70.0 / 255.0)
		"ak47":
			return Color(110.0 / 255.0, 135.0 / 255.0, 85.0 / 255.0)
		"commando_pistol":
			return Color(200.0 / 255.0, 180.0 / 255.0, 120.0 / 255.0)
	return Color(120.0 / 255.0, 180.0 / 255.0, 82.0 / 255.0)


func _draw_ellipse(canvas: CanvasItem, rect: Rect2, color: Color, segments: int = 28) -> void:
	if canvas == null or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var points := PackedVector2Array()
	var center := rect.get_center()
	var rx: float = rect.size.x * 0.5
	var ry: float = rect.size.y * 0.5
	for i in range(max(8, segments)):
		var angle: float = TAU * float(i) / float(max(8, segments))
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	canvas.draw_colored_polygon(points, color)


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _get_rect(value: Variant) -> Rect2:
	if value is Rect2:
		return value
	return Rect2()


func _get_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	return fallback
