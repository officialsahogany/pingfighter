extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const BattleCoreTexturePaths := preload("res://scripts/resources/battle_core_texture_paths.gd")
const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const DefeatGemShatterFxHost := preload("res://scripts/effects/defeat_gem_shatter_fx_host.gd")
const DefeatContinueColorRestoreFxHost := preload("res://scripts/effects/defeat_continue_color_restore_fx_host.gd")
const DefeatContinueRevivalBeatState := preload("res://scripts/core/defeat_continue_revival_beat_state.gd")

const BUTTON_SIZE := Vector2(330.0, 50.0)
const GEM_COUNT := 3
const GEM_TEXTURE_BOX_SIZE := Vector2(74.0, 96.0)
const GEM_SHATTER_SHEET_COLS := 8
const GEM_SHATTER_SHEET_ROWS := 8
const GEM_SHATTER_FRAME_COUNT := 64
const GEM_SHATTER_DURATION_SEC := 2.0
const GEM_SHATTER_HANDOFF_SEC := 0.28
const GEM_SHATTER_FALLBACK_FRAME_SIZE := Vector2(623.0, 1082.0)
const REVEAL_DURATION_SEC := 1.05
const GEM_IMPACT_DURATION_SEC := 0.42
const CONFIRM_SHAKE_DURATION_SEC := 2.0
const CONFIRM_SHATTER_START_SEC := 2.0
const CONFIRM_SHATTER_DURATION_SEC := 0.60
const CONFIRM_WHITEOUT_START_SEC := 2.30
const CONFIRM_RESET_TIME_SEC := 2.90
const CONFIRM_FADEBACK_END_SEC := 3.50
const REVIVAL_FALLBACK_VIEW_SIZE := Vector2(1280.0, 720.0)
const IMPACT_FLASH_DURATION_SEC := 0.24
const IMPACT_RING_DURATION_SEC := 0.42
const IMPACT_SHAKE_DURATION_SEC := 0.56
const IMPACT_BEAM_DURATION_SEC := 0.50
const IMPACT_CHROMA_DURATION_SEC := 0.34
const AMBIENT_DIVINE_MOTE_COUNT := 34
const AMBIENT_DIVINE_RAY_COUNT := 9
const AMBIENT_DIVINE_PORTAL_BREATH_HZ := 0.08
const CHANCE_GEM_FULL_TEXTURE_PATH := BattleCoreTexturePaths.CHANCE_GEM_FULL_TEXTURE_PATH
const CHANCE_GEM_BROKEN_TEXTURE_PATH := BattleCoreTexturePaths.CHANCE_GEM_BROKEN_TEXTURE_PATH
const CHANCE_GEM_SHATTER_SHEET_TEXTURE_PATH := BattleCoreTexturePaths.CHANCE_GEM_SHATTER_SHEET_TEXTURE_PATH
const DEFEAT_CONTINUE_BACKDROP_TEXTURE_PATH := BattleCoreTexturePaths.DEFEAT_CONTINUE_BACKDROP_TEXTURE_PATH

enum ContinuePhase {
	PRESENT,
	CONSUMING,
}

var active: bool = false
var remaining_gems: int = 0
var max_gems: int = GEM_COUNT
var elapsed_sec: float = 0.0
var reveal_elapsed: float = 0.0
var confirm_elapsed: float = 0.0
var _pending_continue_callback: Callable = Callable()
var _pending_consume_callback: Callable = Callable()
var _pending_owner: Object = null
var _pending_registry: Object = null
var _prewarm_assets_step_index: int = 0
var _gem_shatter_fx_host: Node = null
var _color_restore_fx_host: Node = null
var _phase: int = ContinuePhase.PRESENT
var _post_consume_remaining_gems: int = 0
var _consume_fired: bool = false
var _continue_reset_fired: bool = false
var _shatter_sfx_fired: bool = false


func show(owner: Object, registry: Object, continue_callback: Callable) -> bool:
	return _show_internal(owner, registry, continue_callback, Callable())


func show_with_consume(owner: Object, registry: Object, continue_callback: Callable, consume_callback: Callable) -> bool:
	return _show_internal(owner, registry, continue_callback, consume_callback)


func _show_internal(owner: Object, registry: Object, continue_callback: Callable, consume_callback: Callable) -> bool:
	prewarm_assets()
	_pending_owner = owner
	_pending_registry = registry
	_pending_continue_callback = continue_callback
	_pending_consume_callback = consume_callback
	max_gems = _read_int(owner, "chance_gems_max", GEM_COUNT)
	max_gems = clampi(max_gems, 1, GEM_COUNT)
	remaining_gems = clampi(_read_int(owner, "chance_gems_count", max_gems), 0, max_gems)
	_post_consume_remaining_gems = maxi(0, remaining_gems - 1)
	elapsed_sec = 0.0
	reveal_elapsed = 0.0
	confirm_elapsed = 0.0
	_phase = ContinuePhase.PRESENT
	_consume_fired = false
	_continue_reset_fired = false
	_shatter_sfx_fired = false
	active = true
	_ensure_gem_shatter_fx_host(owner)
	_ensure_color_restore_fx_host(owner)
	_sync_gem_shatter_fx_host(owner, _get_owner_view_size(owner), true)
	_sync_color_restore_fx_host(owner, _get_owner_view_size(owner), true)
	_queue_redraw(owner)
	return true


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass
	_prewarm_liveliness_effects()
	DefeatGemShatterFxHost.prewarm_assets()
	DefeatContinueColorRestoreFxHost.prewarm_assets()
	DefeatContinueRevivalBeatState.prewarm_assets()


func prewarm_assets_step() -> bool:
	var paths := _get_texture_paths()
	if _prewarm_assets_step_index >= paths.size():
		_prewarm_assets_step_index = 0
		_prewarm_liveliness_effects()
		DefeatGemShatterFxHost.prewarm_assets()
		DefeatContinueColorRestoreFxHost.prewarm_assets()
		DefeatContinueRevivalBeatState.prewarm_assets()
		return true
	var path := str(paths[_prewarm_assets_step_index])
	ProjectResourceLoader.load_imported_texture(
		path,
		"Missing defeat continue texture at %s",
		"Failed to load defeat continue texture at %s"
	)
	_prewarm_assets_step_index += 1
	if _prewarm_assets_step_index >= paths.size():
		_prewarm_assets_step_index = 0
		_prewarm_liveliness_effects()
		DefeatGemShatterFxHost.prewarm_assets()
		DefeatContinueColorRestoreFxHost.prewarm_assets()
		DefeatContinueRevivalBeatState.prewarm_assets()
		return true
	return false


func prewarm_assets_threaded_step() -> bool:
	var paths := _get_texture_paths()
	if _prewarm_assets_step_index >= paths.size():
		_prewarm_assets_step_index = 0
		_prewarm_liveliness_effects()
		DefeatGemShatterFxHost.prewarm_assets()
		DefeatContinueColorRestoreFxHost.prewarm_assets()
		DefeatContinueRevivalBeatState.prewarm_assets()
		return true
	var path := str(paths[_prewarm_assets_step_index])
	var result := ProjectResourceLoader.prewarm_texture_threaded_step(
		path,
		"Missing defeat continue texture at %s",
		"Failed to load defeat continue texture at %s",
		ProjectResourceLoader.THREADED_TEXTURE_PREWARM_MAX_MSEC,
		ProjectResourceLoader.THREADED_TEXTURE_PREWARM_MAX_POLLS,
		false,
		true
	)
	if not bool(result.get("done", true)):
		return false
	_prewarm_assets_step_index += 1
	if _prewarm_assets_step_index >= paths.size():
		_prewarm_assets_step_index = 0
		_prewarm_liveliness_effects()
		DefeatGemShatterFxHost.prewarm_assets()
		DefeatContinueColorRestoreFxHost.prewarm_assets()
		DefeatContinueRevivalBeatState.prewarm_assets()
		return true
	return false


func are_assets_ready() -> bool:
	return (
		_get_cached_backdrop_texture() != null
		and _get_cached_gem_texture(false) != null
		and _get_cached_gem_texture(true) != null
		and _get_cached_gem_shatter_texture() != null
	)


func is_active() -> bool:
	return active


func reset() -> void:
	_set_gem_shatter_fx_active(false)
	_set_color_restore_fx_active(false)
	_stop_continue_revival_beat()
	active = false
	remaining_gems = 0
	max_gems = GEM_COUNT
	elapsed_sec = 0.0
	reveal_elapsed = 0.0
	confirm_elapsed = 0.0
	_pending_continue_callback = Callable()
	_pending_consume_callback = Callable()
	_pending_owner = null
	_pending_registry = null
	_phase = ContinuePhase.PRESENT
	_post_consume_remaining_gems = 0
	_consume_fired = false
	_continue_reset_fired = false
	_shatter_sfx_fired = false


func update(delta: float) -> void:
	if not active:
		return
	var safe_delta: float = maxf(0.0, delta)
	elapsed_sec += safe_delta
	reveal_elapsed = minf(REVEAL_DURATION_SEC, reveal_elapsed + safe_delta)
	if _phase == ContinuePhase.CONSUMING:
		confirm_elapsed += safe_delta
		_fire_shatter_sfx_if_ready()
		var reset_was_already_fired := _continue_reset_fired
		_fire_continue_reset_if_ready()
		var reset_fired_this_update := not reset_was_already_fired and _continue_reset_fired
		if not reset_was_already_fired and _continue_reset_fired:
			confirm_elapsed = CONFIRM_RESET_TIME_SEC
		if _continue_reset_fired and not reset_fired_this_update:
			_update_continue_revival_beat(safe_delta)
		if reset_was_already_fired and confirm_elapsed >= CONFIRM_FADEBACK_END_SEC and not _is_continue_revival_beat_active():
			reset()
			return
	_sync_gem_shatter_fx_host(_pending_owner, _get_owner_view_size(_pending_owner), false)
	_sync_color_restore_fx_host(_pending_owner, _get_revival_view_size(_pending_owner), false)


func get_reveal_progress() -> float:
	return _ease_out_cubic(clampf(reveal_elapsed / REVEAL_DURATION_SEC, 0.0, 1.0))


func get_confirm_elapsed() -> float:
	return confirm_elapsed


func get_whiteout_alpha() -> float:
	return _get_whiteout_alpha()


func get_impact_flash_alpha() -> float:
	return _get_impact_flash_alpha()


func get_impact_shake_offset() -> Vector2:
	return _get_impact_shake_offset()


func get_chroma_split_strength() -> float:
	return _get_chroma_split_strength()


func get_impact_light_beam_alpha() -> float:
	return _get_light_beam_alpha()


func get_pre_shatter_charge_strength() -> float:
	return _get_pre_shatter_charge()


func get_pre_shatter_crack_strength() -> float:
	return _get_pre_shatter_crack()


func is_consuming_continue() -> bool:
	return active and _phase == ContinuePhase.CONSUMING


func is_revival_beat_active() -> bool:
	return _is_continue_revival_beat_active()


func get_revival_beat_status() -> Dictionary:
	var beat_state := _get_continue_revival_beat_state()
	if beat_state != null and beat_state.has_method("get_status_for_tests"):
		var status: Variant = beat_state.get_status_for_tests()
		if status is Dictionary:
			return status
	return {}


func get_ambient_divine_status(view_size: Vector2) -> Dictionary:
	return _get_ambient_divine_status(view_size)


func blocks_battle_physics() -> bool:
	return active and (not _continue_reset_fired or _is_continue_revival_beat_active())


func handle_input(event: InputEvent, owner: Object, _registry: Object, view_size: Vector2) -> bool:
	if not active:
		return false
	if not blocks_battle_physics():
		return false
	if _is_confirm_event(event, view_size):
		_begin_continue_cinematic(owner)
		return true
	return true


func draw(canvas: CanvasItem, owner: Object, registry: Object, view_size: Vector2) -> void:
	if canvas == null or not active:
		return
	if _continue_reset_fired:
		_draw_continue_revival_beat(canvas, owner, registry, view_size)
		_draw_whiteout(canvas, view_size)
		return
	var ui_font := _get_ui_font()
	var center := view_size * 0.5
	var pulse: float = 0.5 + 0.5 * sin(elapsed_sec * TAU * 1.35)
	var reveal := get_reveal_progress()
	var accent := Color(0.35, 0.82, 1.0, 0.90)
	var gold := Color(0.92, 0.76, 0.38, 0.92)

	_draw_scene_backdrop(canvas, view_size)
	_draw_entry_reveal_glow(canvas, view_size, reveal, accent)
	_draw_boss_portal_figure(canvas, owner, registry, view_size, pulse)
	_draw_ambient_divine_motion(canvas, view_size)
	_draw_compass_sigil(canvas, center.x, _scaled_y(view_size, 58.0), accent)
	_draw_title_ornaments(canvas, center.x, _scaled_y(view_size, 115.0), minf(view_size.x * 0.33, 360.0), accent)
	_draw_centered_text(canvas, ui_font, "패배", Vector2(center.x, _scaled_y(view_size, 120.0)), _scaled_font(view_size, 44), Color(0.88, 0.94, 1.0, 0.98))
	_draw_centered_text(canvas, ui_font, "아쉽지만 다음 기회를 노려보세요.", Vector2(center.x, _scaled_y(view_size, 174.0)), _scaled_font(view_size, 18), Color(0.54, 0.67, 0.92, 0.92))

	_draw_continue_status_text(canvas, ui_font, view_size, center.x)

	var gem_center_y := _scaled_y(view_size, 540.0)
	var gem_gap := minf(view_size.x * 0.095, 122.0)
	var first_x := center.x - gem_gap
	_draw_gem_rail(canvas, center.x, gem_center_y, gem_gap, accent)
	_sync_gem_shatter_fx_host(owner, view_size, false)
	var visual_remaining := _get_visual_remaining_gems()
	var consumed: int = max_gems - visual_remaining
	var breaking_index := _get_breaking_gem_index()
	var breaking_center := Vector2.ZERO
	if breaking_index >= 0:
		breaking_center = Vector2(first_x + float(breaking_index) * gem_gap, gem_center_y)
	_draw_pre_shatter_charge(canvas, breaking_center, view_size)
	_draw_impact_chroma_split(canvas, breaking_center)
	for i in range(max_gems):
		var gem_center := Vector2(first_x + float(i) * gem_gap, gem_center_y)
		if i == breaking_index:
			gem_center += _get_confirm_shake_offset(i)
		_draw_gem_slot(canvas, gem_center, 26.0, i < consumed, i == breaking_index and _is_shatter_window_active(), pulse)
		if i == breaking_index:
			_draw_pre_shatter_cracks(canvas, gem_center)
	if breaking_index >= 0:
		_draw_shatter_impact_layers(canvas, breaking_center, view_size)

	var guide := "기회의 보석은 패배 시 1개가 소모됩니다.\n모든 보석이 소모되면 더 이상 도전할 수 없습니다."
	var guide_color := Color(0.70, 0.78, 0.90, 0.90)
	if visual_remaining <= 0:
		guide = "이번이 마지막 기회입니다.\n다음 패배 시 게임이 종료됩니다."
		guide_color = gold
	_draw_multiline_centered_text(canvas, ui_font, guide, Vector2(center.x, _scaled_y(view_size, 592.0)), _scaled_font(view_size, 15), guide_color, 24.0)

	if _phase == ContinuePhase.PRESENT:
		var button_rect := _get_button_rect(view_size)
		_draw_button_frame(canvas, button_rect, accent, pulse)
		_draw_centered_text(canvas, ui_font, "확인", button_rect.get_center() + Vector2(0.0, 1.0), _scaled_font(view_size, 18), Color.WHITE)
	_draw_reveal_veil(canvas, view_size, reveal)
	_draw_whiteout(canvas, view_size)


func _draw_scene_backdrop(canvas: CanvasItem, view_size: Vector2) -> void:
	var texture := _get_cached_backdrop_texture()
	if texture != null:
		var backdrop_rect := _cover_texture_rect(texture, Rect2(Vector2.ZERO, view_size))
		canvas.draw_texture_rect(texture, backdrop_rect, false, Color.WHITE)
	else:
		canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.015, 0.020, 0.045, 1.0))
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 0.0, 0.18))
	_draw_backdrop_vignette_bands(canvas, view_size)


func _draw_backdrop_vignette_bands(canvas: CanvasItem, view_size: Vector2) -> void:
	var top_height := view_size.y * 0.36
	var bottom_height := view_size.y * 0.34
	var side_width := view_size.x * 0.23
	_draw_vignette_quad(
		canvas,
		PackedVector2Array([
			Vector2(0.0, 0.0),
			Vector2(view_size.x, 0.0),
			Vector2(view_size.x, top_height),
			Vector2(0.0, top_height),
		]),
		PackedColorArray([
			Color(0.0, 0.0, 0.0, 0.36),
			Color(0.0, 0.0, 0.0, 0.36),
			Color(0.0, 0.0, 0.0, 0.0),
			Color(0.0, 0.0, 0.0, 0.0),
		])
	)
	_draw_vignette_quad(
		canvas,
		PackedVector2Array([
			Vector2(0.0, view_size.y - bottom_height),
			Vector2(view_size.x, view_size.y - bottom_height),
			Vector2(view_size.x, view_size.y),
			Vector2(0.0, view_size.y),
		]),
		PackedColorArray([
			Color(0.0, 0.0, 0.0, 0.0),
			Color(0.0, 0.0, 0.0, 0.0),
			Color(0.0, 0.0, 0.0, 0.38),
			Color(0.0, 0.0, 0.0, 0.38),
		])
	)
	_draw_vignette_quad(
		canvas,
		PackedVector2Array([
			Vector2(0.0, 0.0),
			Vector2(side_width, 0.0),
			Vector2(side_width, view_size.y),
			Vector2(0.0, view_size.y),
		]),
		PackedColorArray([
			Color(0.0, 0.0, 0.0, 0.26),
			Color(0.0, 0.0, 0.0, 0.0),
			Color(0.0, 0.0, 0.0, 0.0),
			Color(0.0, 0.0, 0.0, 0.26),
		])
	)
	_draw_vignette_quad(
		canvas,
		PackedVector2Array([
			Vector2(view_size.x - side_width, 0.0),
			Vector2(view_size.x, 0.0),
			Vector2(view_size.x, view_size.y),
			Vector2(view_size.x - side_width, view_size.y),
		]),
		PackedColorArray([
			Color(0.0, 0.0, 0.0, 0.0),
			Color(0.0, 0.0, 0.0, 0.26),
			Color(0.0, 0.0, 0.0, 0.26),
			Color(0.0, 0.0, 0.0, 0.0),
		])
	)


func _draw_vignette_quad(canvas: CanvasItem, points: PackedVector2Array, colors: PackedColorArray) -> void:
	canvas.draw_polygon(points, colors)


func _draw_entry_reveal_glow(canvas: CanvasItem, view_size: Vector2, reveal: float, accent: Color) -> void:
	var inverse := 1.0 - clampf(reveal, 0.0, 1.0)
	if inverse <= 0.01:
		return
	var center := Vector2(view_size.x * 0.5, _scaled_y(view_size, 344.0))
	var bloom_alpha := 0.14 * inverse
	ImpactFlareTextureCache.draw_glow(canvas, center, minf(view_size.x, view_size.y) * (0.23 + 0.08 * inverse), accent, bloom_alpha)
	var wake := clampf(reveal_elapsed / maxf(REVEAL_DURATION_SEC, 0.001), 0.0, 1.0)
	var wake_alpha := sin(clampf(wake, 0.0, 0.5) * PI * 2.0) * 0.16
	if wake_alpha > 0.0:
		ImpactFlareTextureCache.draw_burst(canvas, center, minf(view_size.x, view_size.y) * (0.19 + wake * 0.08), Color(0.66, 0.86, 1.0, 1.0), wake_alpha)


func _draw_reveal_veil(canvas: CanvasItem, view_size: Vector2, reveal: float) -> void:
	var inverse := 1.0 - clampf(reveal, 0.0, 1.0)
	if inverse <= 0.01:
		return
	var veil_alpha := pow(inverse, 1.7) * 0.74
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 0.0, veil_alpha))


func _draw_boss_portal_figure(canvas: CanvasItem, owner: Object, registry: Object, view_size: Vector2, pulse: float) -> void:
	var texture := _get_cached_boss_victory_texture(registry)
	if texture == null:
		return
	var stage_id: int = maxi(1, _read_int(owner, "current_stage", 1))
	var frame_index := int(floor(elapsed_sec / 0.12))
	var source_rect := _get_boss_victory_source_rect(texture, stage_id, frame_index)
	if source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		return
	var hover := sin(elapsed_sec * TAU * 0.16) * 5.0
	var center := Vector2(view_size.x * 0.5, _scaled_y(view_size, 342.0) + hover)
	var max_size := Vector2(minf(view_size.x * 0.30, 360.0), minf(view_size.y * 0.38, 274.0))
	var draw_rect := _fit_size_rect(source_rect.size, center, max_size)
	var aura_radius := maxf(draw_rect.size.x, draw_rect.size.y) * (0.48 + pulse * 0.03)
	canvas.draw_circle(center + Vector2(0.0, draw_rect.size.y * 0.10), aura_radius, Color(0.12, 0.24, 0.48, 0.18))
	canvas.draw_texture_rect_region(texture, draw_rect, source_rect, Color(0.0, 0.0, 0.0, 0.70), false, true)
	canvas.draw_texture_rect_region(texture, draw_rect, source_rect, Color(0.12, 0.22, 0.50, 0.16), false, true)


func _draw_ambient_divine_motion(canvas: CanvasItem, view_size: Vector2) -> void:
	var status := _get_ambient_divine_status(view_size)
	if not bool(status.get("active", false)):
		return
	var portal_center := _get_ambient_portal_center(view_size)
	_draw_ambient_portal_glow(canvas, portal_center, view_size, status)
	_draw_ambient_light_shafts(canvas, portal_center, view_size, status)
	_draw_ambient_divine_motes(canvas, portal_center, view_size, status)


func _draw_ambient_portal_glow(canvas: CanvasItem, portal_center: Vector2, view_size: Vector2, status: Dictionary) -> void:
	var glow_alpha := float(status.get("portal_glow_alpha", 0.0))
	if glow_alpha <= 0.001:
		return
	var breath := float(status.get("breath", 0.0))
	var radius := minf(view_size.x, view_size.y) * (0.28 + breath * 0.045)
	var cold := Color(0.34, 0.72, 1.0, 1.0)
	ImpactFlareTextureCache.draw_glow(canvas, portal_center, radius, cold, glow_alpha)
	ImpactFlareTextureCache.draw_burst(canvas, portal_center, radius * 0.76, Color(0.72, 0.92, 1.0, 1.0), glow_alpha * 0.34)
	var ring_radius := minf(view_size.x, view_size.y) * (0.24 + breath * 0.03)
	var ring_rect := Rect2(portal_center - Vector2(ring_radius, ring_radius * 0.57), Vector2(ring_radius * 2.0, ring_radius * 1.14))
	_draw_ellipse_arc(canvas, ring_rect, -PI * 0.94, -PI * 0.08, Color(0.50, 0.82, 1.0, glow_alpha * 0.78), 1.2)
	_draw_ellipse_arc(canvas, ring_rect, PI * 1.08, PI * 1.88, Color(0.78, 0.94, 1.0, glow_alpha * 0.54), 0.9)


func _draw_ambient_light_shafts(canvas: CanvasItem, portal_center: Vector2, view_size: Vector2, status: Dictionary) -> void:
	var base_alpha := float(status.get("ray_alpha", 0.0))
	if base_alpha <= 0.001:
		return
	var base_radius := minf(view_size.x, view_size.y)
	for i in range(AMBIENT_DIVINE_RAY_COUNT):
		var ratio := float(i) / float(maxi(1, AMBIENT_DIVINE_RAY_COUNT - 1))
		var angle := lerpf(-PI * 0.86, -PI * 0.14, ratio)
		var phase := elapsed_sec * TAU * (0.052 + float(i % 3) * 0.006) + float(i) * 1.37
		var wave := 0.5 + 0.5 * sin(phase)
		var length := base_radius * (0.29 + 0.16 * wave)
		var inner := base_radius * (0.055 + 0.010 * float(i % 2))
		var direction := Vector2(cos(angle), sin(angle) * 0.76).normalized()
		var start := portal_center + direction * inner
		var end := portal_center + direction * length
		var alpha := base_alpha * (0.54 + 0.46 * wave)
		var width := 1.1 + 1.2 * wave
		canvas.draw_line(start, end, Color(0.58, 0.83, 1.0, alpha), width)
		if i % 3 == 1:
			canvas.draw_line(start, end, Color(0.90, 0.98, 1.0, alpha * 0.32), 0.75)


func _draw_ambient_divine_motes(canvas: CanvasItem, portal_center: Vector2, view_size: Vector2, status: Dictionary) -> void:
	var base_alpha := float(status.get("mote_alpha", 0.0))
	if base_alpha <= 0.001:
		return
	var span_x := minf(view_size.x * 0.56, 760.0)
	var top_y := _scaled_y(view_size, 176.0)
	var bottom_y := _scaled_y(view_size, 650.0)
	for i in range(AMBIENT_DIVINE_MOTE_COUNT):
		var seed := fposmod(float(i) * 0.61803398875, 1.0)
		var speed := 0.050 + float(i % 5) * 0.006
		var rise := fposmod(seed + elapsed_sec * speed, 1.0)
		var fade := sin(rise * PI)
		if fade <= 0.001:
			continue
		var sway := sin(elapsed_sec * TAU * (0.036 + float(i % 4) * 0.006) + seed * TAU * 2.0)
		var x := portal_center.x + (seed - 0.5) * span_x + sway * (28.0 + float(i % 3) * 12.0)
		var y := lerpf(bottom_y, top_y, rise) + sin(seed * TAU * 3.0 + elapsed_sec * TAU * 0.07) * 16.0
		if x < -16.0 or x > view_size.x + 16.0 or y < -16.0 or y > view_size.y + 16.0:
			continue
		var depth := 0.62 + 0.38 * fposmod(seed * 3.71, 1.0)
		var radius := 5.6 + depth * 6.8
		var alpha := base_alpha * fade * depth
		var color := Color(0.58 + depth * 0.18, 0.82 + depth * 0.12, 1.0, 1.0)
		ImpactFlareTextureCache.draw_sparkle(canvas, Vector2(x, y), radius, color, alpha)
		if i % 3 == 0:
			ImpactFlareTextureCache.draw_glow(canvas, Vector2(x, y), radius * 2.9, color, alpha * 0.42)


func _get_ambient_divine_status(view_size: Vector2) -> Dictionary:
	var is_visible := active and not _continue_reset_fired and view_size.x > 1.0 and view_size.y > 1.0
	var breath := 0.5 + 0.5 * sin(elapsed_sec * TAU * AMBIENT_DIVINE_PORTAL_BREATH_HZ)
	var consume_boost := _get_ambient_consume_boost()
	var strength := (1.0 + consume_boost) if is_visible else 0.0
	return {
		"active": is_visible,
		"breath": breath,
		"strength": strength,
		"portal_glow_alpha": (0.42 + breath * 0.22) * strength,
		"ray_alpha": (0.30 + breath * 0.18) * strength,
		"mote_alpha": 0.62 * strength,
		"mote_count": AMBIENT_DIVINE_MOTE_COUNT,
		"ray_count": AMBIENT_DIVINE_RAY_COUNT,
		"clock_sec": elapsed_sec,
		"single_clock": true,
	}


func _get_ambient_consume_boost() -> float:
	if _phase != ContinuePhase.CONSUMING:
		return 0.0
	var build := clampf(confirm_elapsed / maxf(CONFIRM_SHATTER_START_SEC, 0.001), 0.0, 1.0)
	var whiteout_damp := 1.0 - clampf(_get_whiteout_alpha(), 0.0, 1.0)
	return 0.22 * _ease_in_out_cubic(build) * whiteout_damp


func _get_ambient_portal_center(view_size: Vector2) -> Vector2:
	return Vector2(view_size.x * 0.5, _scaled_y(view_size, 344.0))


func _get_cached_boss_victory_texture(registry: Object) -> Texture2D:
	var resources := _get_registry_instance(registry, "battle_resources")
	if resources == null or not resources.has_method("get_resource_cache"):
		return null
	var cache_value: Variant = resources.get_resource_cache()
	if not (cache_value is Dictionary):
		return null
	var cache: Dictionary = cache_value
	var texture_value: Variant = cache.get("boss_victory_sheet", null)
	if texture_value is Texture2D:
		return texture_value
	return null


func _get_boss_victory_source_rect(texture: Texture2D, stage_id: int, frame_index: int) -> Rect2:
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var cols := 4
	var rows := 2
	if stage_id == 2:
		cols = 8
		rows = 8
	elif stage_id >= 4 and texture_size.x <= texture_size.y * 1.05:
		cols = 1
		rows = 1
	var frame_count := maxi(1, cols * rows)
	var frame := posmod(frame_index, frame_count)
	var cell_size := Vector2(texture_size.x / float(cols), texture_size.y / float(rows))
	var row := int(floor(float(frame) / float(cols)))
	return Rect2(Vector2(float(frame % cols) * cell_size.x, float(row) * cell_size.y), cell_size)


func _draw_compass_sigil(canvas: CanvasItem, x: float, y: float, accent: Color) -> void:
	var muted := Color(accent.r, accent.g, accent.b, 0.38)
	canvas.draw_line(Vector2(x, y - 31.0), Vector2(x, y + 31.0), muted, 1.2)
	canvas.draw_line(Vector2(x - 31.0, y), Vector2(x + 31.0, y), muted, 1.2)
	canvas.draw_line(Vector2(x - 21.0, y - 21.0), Vector2(x + 21.0, y + 21.0), Color(accent.r, accent.g, accent.b, 0.24), 1.0)
	canvas.draw_line(Vector2(x - 21.0, y + 21.0), Vector2(x + 21.0, y - 21.0), Color(accent.r, accent.g, accent.b, 0.24), 1.0)
	_draw_diamond_marker(canvas, Vector2(x, y), 12.0, Color(accent.r, accent.g, accent.b, 0.48), false)
	canvas.draw_circle(Vector2(x, y), 2.0, Color(0.80, 0.92, 1.0, 0.82))


func _draw_title_ornaments(canvas: CanvasItem, x: float, y: float, half_width: float, accent: Color) -> void:
	var line_color := Color(accent.r, accent.g, accent.b, 0.30)
	canvas.draw_line(Vector2(x - half_width, y), Vector2(x - 78.0, y), line_color, 1.0)
	canvas.draw_line(Vector2(x + 78.0, y), Vector2(x + half_width, y), line_color, 1.0)
	for side in [-1.0, 1.0]:
		_draw_diamond_marker(canvas, Vector2(x + side * 128.0, y), 5.0, Color(accent.r, accent.g, accent.b, 0.52), false)
		_draw_diamond_marker(canvas, Vector2(x + side * 250.0, y), 4.0, Color(accent.r, accent.g, accent.b, 0.38), false)


func _draw_gem_rail(canvas: CanvasItem, center_x: float, y: float, gem_gap: float, accent: Color) -> void:
	var rail_color := Color(0.68, 0.76, 0.88, 0.38)
	var left_end := center_x - gem_gap * 1.96
	var right_end := center_x + gem_gap * 1.96
	canvas.draw_line(Vector2(left_end, y), Vector2(center_x - gem_gap * 0.62, y), rail_color, 1.2)
	canvas.draw_line(Vector2(center_x + gem_gap * 0.62, y), Vector2(right_end, y), rail_color, 1.2)
	_draw_diamond_marker(canvas, Vector2(center_x - gem_gap * 1.54, y), 7.0, Color(accent.r, accent.g, accent.b, 0.36), false)
	_draw_diamond_marker(canvas, Vector2(center_x + gem_gap * 1.54, y), 7.0, Color(accent.r, accent.g, accent.b, 0.36), false)
	_draw_diamond_marker(canvas, Vector2(center_x - gem_gap * 1.22, y), 3.0, rail_color, true)
	_draw_diamond_marker(canvas, Vector2(center_x + gem_gap * 1.22, y), 3.0, rail_color, true)


func _draw_button_frame(canvas: CanvasItem, rect: Rect2, accent: Color, pulse: float) -> void:
	var corner := minf(rect.size.y * 0.48, 24.0)
	var points: PackedVector2Array = [
		Vector2(rect.position.x + corner, rect.position.y),
		Vector2(rect.end.x - corner, rect.position.y),
		Vector2(rect.end.x, rect.position.y + rect.size.y * 0.5),
		Vector2(rect.end.x - corner, rect.end.y),
		Vector2(rect.position.x + corner, rect.end.y),
		Vector2(rect.position.x, rect.position.y + rect.size.y * 0.5),
	]
	var outline := PackedVector2Array()
	for point in points:
		outline.append(point)
	outline.append(points[0])
	canvas.draw_colored_polygon(points, Color(0.035, 0.090, 0.180, 0.88))
	canvas.draw_polyline(outline, Color(accent.r, accent.g, accent.b, 0.58 + pulse * 0.24), 1.6)
	canvas.draw_line(Vector2(rect.position.x + corner + 8.0, rect.position.y + 5.0), Vector2(rect.end.x - corner - 8.0, rect.position.y + 5.0), Color(1.0, 1.0, 1.0, 0.08), 1.0)


func _draw_centered_text_segments(canvas: CanvasItem, font: Font, segments: Array, center: Vector2, font_size: int) -> void:
	if font == null or segments.is_empty():
		return
	var total_width := 0.0
	var max_height := 0.0
	for segment in segments:
		if not segment is Dictionary:
			continue
		var segment_dict: Dictionary = segment
		var segment_text := str(segment_dict.get("text", ""))
		var segment_size := font.get_string_size(segment_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
		total_width += segment_size.x
		max_height = maxf(max_height, segment_size.y)
	var cursor := Vector2(center.x - total_width * 0.5, center.y - max_height * 0.5 + max_height * 0.78)
	for segment in segments:
		if not segment is Dictionary:
			continue
		var segment_dict: Dictionary = segment
		var text := str(segment_dict.get("text", ""))
		var color := Color.WHITE
		var color_value: Variant = segment_dict.get("color", Color.WHITE)
		if color_value is Color:
			color = color_value
		canvas.draw_string(font, cursor + Vector2(1.5, 1.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, color.a * 0.72))
		canvas.draw_string(font, cursor, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
		cursor.x += font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x


func _draw_continue_status_text(canvas: CanvasItem, font: Font, view_size: Vector2, center_x: float) -> void:
	var center := Vector2(center_x, _scaled_y(view_size, 470.0))
	if _phase == ContinuePhase.PRESENT:
		_draw_centered_text_segments(
			canvas,
			font,
			[
				{"text": "확인하면 기회의 보석이 ", "color": Color(0.90, 0.92, 0.98, 0.96)},
				{"text": "1개", "color": Color(0.43, 0.78, 1.0, 0.98)},
				{"text": " 소모됩니다.", "color": Color(0.90, 0.92, 0.98, 0.96)},
			],
			center,
			_scaled_font(view_size, 20)
		)
		return
	if _is_shatter_window_active() or _has_shatter_completed():
		_draw_centered_text_segments(
			canvas,
			font,
			[
				{"text": "기회의 보석이 ", "color": Color(0.90, 0.92, 0.98, 0.96)},
				{"text": "1개", "color": Color(0.43, 0.78, 1.0, 0.98)},
				{"text": " 소모되었습니다.", "color": Color(0.90, 0.92, 0.98, 0.96)},
			],
			center,
			_scaled_font(view_size, 20)
		)
		return
	_draw_centered_text(canvas, font, "기회의 보석이 흔들립니다...", center, _scaled_font(view_size, 20), Color(0.86, 0.92, 1.0, 0.94))


func _draw_multiline_centered_text(canvas: CanvasItem, font: Font, text: String, center: Vector2, font_size: int, color: Color, line_gap: float) -> void:
	var lines := text.split("\n")
	var start_y := center.y - (float(lines.size() - 1) * line_gap * 0.5)
	for i in range(lines.size()):
		_draw_centered_text(canvas, font, lines[i], Vector2(center.x, start_y + float(i) * line_gap), font_size, color)


func _draw_diamond_marker(canvas: CanvasItem, center: Vector2, radius: float, color: Color, filled: bool) -> void:
	var points: PackedVector2Array = [
		center + Vector2(0.0, -radius),
		center + Vector2(radius, 0.0),
		center + Vector2(0.0, radius),
		center + Vector2(-radius, 0.0),
	]
	if filled:
		canvas.draw_colored_polygon(points, color)
	else:
		var outline := PackedVector2Array()
		for point in points:
			outline.append(point)
		outline.append(points[0])
		canvas.draw_polyline(outline, color, 1.1)


func _draw_pre_shatter_charge(canvas: CanvasItem, center: Vector2, view_size: Vector2) -> void:
	var charge := _get_pre_shatter_charge()
	if charge <= 0.001:
		return
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 0.0, 0.10 * charge))
	var cyan := Color(0.38, 0.82, 1.0, 1.0)
	ImpactFlareTextureCache.draw_glow(canvas, center, 56.0 + 28.0 * charge, cyan, 0.18 * charge)
	ImpactFlareTextureCache.draw_burst(canvas, center, 62.0 + 34.0 * charge, Color(0.72, 0.94, 1.0, 1.0), 0.08 * charge)
	for i in range(4):
		var angle := confirm_elapsed * (1.9 + float(i) * 0.18) + float(i) * TAU * 0.25
		var radius := 34.0 + 24.0 * (1.0 - charge) + float(i % 2) * 9.0
		var start := center + Vector2(cos(angle), sin(angle)) * radius
		var end := center + Vector2(cos(angle + 0.42), sin(angle + 0.42)) * (radius * (0.58 + charge * 0.18))
		canvas.draw_line(start, end, Color(0.48, 0.86, 1.0, 0.26 * charge), 1.1 + charge * 0.6)


func _draw_pre_shatter_cracks(canvas: CanvasItem, center: Vector2) -> void:
	var crack := _get_pre_shatter_crack()
	if crack <= 0.001:
		return
	var core := Color(0.82, 0.94, 1.0, 0.54 * crack)
	var shadow := Color(0.02, 0.08, 0.16, 0.34 * crack)
	var lines: Array = [
		[Vector2(-4.0, -34.0), Vector2(0.0, -14.0), Vector2(-9.0, 4.0)],
		[Vector2(2.0, -12.0), Vector2(12.0, 8.0), Vector2(4.0, 30.0)],
		[Vector2(-8.0, -2.0), Vector2(-22.0, 14.0)],
		[Vector2(8.0, 0.0), Vector2(24.0, -12.0)],
	]
	for entry in lines:
		var points := PackedVector2Array()
		for value in entry:
			var point: Vector2 = value
			points.append(center + point * (0.45 + crack * 0.55))
		canvas.draw_polyline(points, shadow, 3.0)
		canvas.draw_polyline(points, core, 1.1 + crack * 0.7)


func _draw_impact_chroma_split(canvas: CanvasItem, center: Vector2) -> void:
	var strength := _get_chroma_split_strength()
	if strength <= 0.001:
		return
	var offset := 5.0 + 13.0 * strength
	var box := GEM_TEXTURE_BOX_SIZE * (1.10 + strength * 0.28)
	var rect_r := _fit_size_rect(_get_static_gem_frame_size(), center + Vector2(offset, 0.0), box)
	var rect_b := _fit_size_rect(_get_static_gem_frame_size(), center - Vector2(offset, 0.0), box)
	var texture := _get_cached_gem_texture(false)
	if texture != null:
		canvas.draw_texture_rect(texture, rect_r, false, Color(1.0, 0.18, 0.28, 0.18 * strength))
		canvas.draw_texture_rect(texture, rect_b, false, Color(0.22, 0.62, 1.0, 0.24 * strength))


func _draw_shatter_impact_layers(canvas: CanvasItem, center: Vector2, view_size: Vector2) -> void:
	var flash := _get_impact_flash_alpha()
	var ring := _get_impact_ring_alpha()
	var beam := _get_light_beam_alpha()
	var shake := _get_impact_shake_offset()
	if flash <= 0.001 and ring <= 0.001 and beam <= 0.001:
		return
	var draw_center := center + shake
	if flash > 0.001:
		ImpactFlareTextureCache.draw_glow(canvas, draw_center, 118.0 + 58.0 * flash, Color(0.68, 0.94, 1.0, 1.0), 0.34 * flash)
		ImpactFlareTextureCache.draw_burst(canvas, draw_center, 164.0 + 96.0 * flash, Color(0.90, 0.98, 1.0, 1.0), 0.42 * flash)
		canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.80, 0.94, 1.0, 0.08 * flash))
	if ring > 0.001:
		var ring_progress := _get_impact_ring_progress()
		var out := _ease_out_cubic(ring_progress)
		var radius := 54.0 + 180.0 * out
		var ring_rect := Rect2(draw_center - Vector2(radius, radius * 0.58), Vector2(radius * 2.0, radius * 1.16))
		_draw_ellipse_arc(canvas, ring_rect, -PI * 0.06, PI * 0.86, Color(0.58, 0.88, 1.0, 0.48 * ring), 2.8)
		_draw_ellipse_arc(canvas, ring_rect, PI * 1.02, PI * 1.82, Color(0.88, 0.98, 1.0, 0.34 * ring), 1.8)
		_draw_impact_shards(canvas, draw_center, out, ring)
	if beam > 0.001:
		_draw_impact_light_beams(canvas, draw_center, view_size, beam)


func _draw_impact_shards(canvas: CanvasItem, center: Vector2, out: float, alpha: float) -> void:
	var shard_dirs: Array[Vector2] = [
		Vector2(-1.0, -0.55),
		Vector2(-0.48, -1.0),
		Vector2(0.42, -1.0),
		Vector2(1.0, -0.36),
		Vector2(-0.85, 0.42),
		Vector2(0.86, 0.55),
	]
	for i in range(shard_dirs.size()):
		var dir: Vector2 = shard_dirs[i].normalized()
		var travel := 40.0 + 108.0 * out + float(i % 3) * 12.0
		var gravity := Vector2(0.0, 26.0 * out * out)
		var pos := center + dir * travel + gravity
		var size := 12.0 + float(i % 2) * 4.0
		ImpactFlareTextureCache.draw_sparkle(canvas, pos, size, Color(0.70, 0.92, 1.0, 1.0), alpha * (0.42 - float(i) * 0.035))


func _draw_impact_light_beams(canvas: CanvasItem, center: Vector2, view_size: Vector2, alpha: float) -> void:
	var reach := maxf(view_size.x, view_size.y) * (0.22 + 0.20 * alpha)
	var cool := Color(0.46, 0.82, 1.0, 0.34 * alpha)
	var core := Color(0.92, 0.99, 1.0, 0.68 * alpha)
	var horizontal := Vector2(reach, 0.0)
	var vertical := Vector2(0.0, reach * 0.66)
	canvas.draw_line(center - horizontal, center + horizontal, cool, 7.0)
	canvas.draw_line(center - horizontal, center + horizontal, core, 2.0)
	canvas.draw_line(center - vertical, center + vertical, cool, 5.5)
	canvas.draw_line(center - vertical, center + vertical, core, 1.7)
	var diag := reach * 0.52 * 0.7071
	var d1 := Vector2(diag, diag)
	var d2 := Vector2(diag, -diag)
	canvas.draw_line(center - d1, center + d1, Color(0.78, 0.94, 1.0, 0.22 * alpha), 3.2)
	canvas.draw_line(center - d2, center + d2, Color(0.78, 0.94, 1.0, 0.22 * alpha), 3.2)


func _draw_gem_slot(canvas: CanvasItem, center: Vector2, _radius: float, broken: bool, breaking: bool, pulse: float) -> void:
	if breaking:
		_draw_gem_break_impact(canvas, center)
	if breaking and _draw_gem_shatter_sheet(canvas, center):
		return
	var texture: Texture2D = _get_cached_gem_texture(broken)
	if texture == null:
		return
	var rect := _fit_texture_rect(texture, center, GEM_TEXTURE_BOX_SIZE)
	if breaking:
		var glow_alpha := 0.10 + pulse * 0.10
		canvas.draw_circle(center, maxf(rect.size.x, rect.size.y) * 0.55, Color(0.20, 0.68, 1.0, glow_alpha))
	var color := Color.WHITE if not broken else Color(0.82, 0.90, 1.0, 0.76)
	canvas.draw_texture_rect(texture, rect, false, color)


func _draw_gem_break_impact(canvas: CanvasItem, center: Vector2) -> void:
	var progress := clampf(_get_shatter_progress() / maxf(GEM_IMPACT_DURATION_SEC / GEM_SHATTER_DURATION_SEC, 0.001), 0.0, 1.0)
	if progress >= 1.0:
		return
	var out := _ease_out_cubic(progress)
	var fade := pow(1.0 - progress, 1.55)
	var icy := Color(0.40, 0.82, 1.0, 1.0)
	ImpactFlareTextureCache.draw_glow(canvas, center, 78.0 + 36.0 * out, icy, 0.34 * fade)
	if progress <= 0.36:
		var burst_alpha := (1.0 - progress / 0.36) * 0.34
		ImpactFlareTextureCache.draw_burst(canvas, center, 78.0 + 70.0 * out, Color(0.78, 0.93, 1.0, 1.0), burst_alpha)
	var ring_radius := 42.0 + 58.0 * out
	var ring_rect := Rect2(center - Vector2(ring_radius, ring_radius * 0.66), Vector2(ring_radius * 2.0, ring_radius * 1.32))
	var arc_color := Color(0.58, 0.84, 1.0, 0.30 * fade)
	_draw_ellipse_arc(canvas, ring_rect, -PI * 0.04, PI * 0.82, arc_color, 1.4)
	_draw_ellipse_arc(canvas, ring_rect, PI * 1.06, PI * 1.78, Color(0.80, 0.94, 1.0, 0.22 * fade), 1.1)
	_draw_gem_break_sparkles(canvas, center, out, fade)


func _draw_gem_break_sparkles(canvas: CanvasItem, center: Vector2, out: float, fade: float) -> void:
	var offsets: Array[Vector2] = [
		Vector2(-28.0, -22.0),
		Vector2(34.0, -18.0),
		Vector2(-40.0, 10.0),
		Vector2(42.0, 17.0),
		Vector2(6.0, -38.0),
	]
	for i in range(offsets.size()):
		var offset: Vector2 = offsets[i]
		var travel := 0.35 + out * (0.92 + 0.10 * float(i % 2))
		var gravity := Vector2(0.0, 20.0 * out * out)
		var sparkle_center := center + offset * travel + gravity
		var sparkle_alpha := fade * (0.52 - float(i) * 0.055)
		if sparkle_alpha <= 0.0:
			continue
		ImpactFlareTextureCache.draw_sparkle(canvas, sparkle_center, 10.0 + 3.0 * float(i % 2), Color(0.70, 0.90, 1.0, 1.0), sparkle_alpha)


func _draw_gem_shatter_sheet(canvas: CanvasItem, center: Vector2) -> bool:
	var sheet := _get_cached_gem_shatter_texture()
	if sheet == null:
		return false
	var texture_size := sheet.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return false
	if not _is_shatter_window_active():
		return false
	var cell_size := Vector2(texture_size.x / float(GEM_SHATTER_SHEET_COLS), texture_size.y / float(GEM_SHATTER_SHEET_ROWS))
	var progress := _get_shatter_progress()
	var frame := clampi(int(floor(progress * float(GEM_SHATTER_FRAME_COUNT))), 0, GEM_SHATTER_FRAME_COUNT - 1)
	var col := frame % GEM_SHATTER_SHEET_COLS
	var row := int(floor(float(frame) / float(GEM_SHATTER_SHEET_COLS)))
	var source_rect := Rect2(Vector2(float(col) * cell_size.x, float(row) * cell_size.y), cell_size)
	var draw_rect := _fit_size_rect(_get_static_gem_frame_size(), center, GEM_TEXTURE_BOX_SIZE)
	var handoff_start := maxf(1.0 - GEM_SHATTER_HANDOFF_SEC / maxf(GEM_SHATTER_DURATION_SEC, 0.001), 0.0)
	var handoff_progress := 0.0
	if progress > handoff_start:
		handoff_progress = _ease_in_out_cubic((progress - handoff_start) / maxf(1.0 - handoff_start, 0.001))
	var sheet_alpha := 1.0 - handoff_progress
	if sheet_alpha > 0.01:
		canvas.draw_texture_rect_region(sheet, draw_rect, source_rect, Color(1.0, 1.0, 1.0, sheet_alpha), false, true)
	if handoff_progress > 0.0:
		var glow_alpha := 0.08 * (1.0 - handoff_progress)
		if glow_alpha > 0.001:
			canvas.draw_circle(center, maxf(draw_rect.size.x, draw_rect.size.y) * 0.48, Color(0.20, 0.68, 1.0, glow_alpha))
		_draw_static_gem_texture(canvas, center, true, handoff_progress)
	return true


func _draw_static_gem_texture(canvas: CanvasItem, center: Vector2, broken: bool, alpha: float) -> Rect2:
	var texture: Texture2D = _get_cached_gem_texture(broken)
	if texture == null or alpha <= 0.0:
		return Rect2(center, Vector2.ZERO)
	var rect := _fit_texture_rect(texture, center, GEM_TEXTURE_BOX_SIZE)
	var color := Color.WHITE if not broken else Color(0.82, 0.90, 1.0, 0.76)
	color.a *= clampf(alpha, 0.0, 1.0)
	canvas.draw_texture_rect(texture, rect, false, color)
	return rect


func _get_texture_paths() -> Array:
	return [
		DEFEAT_CONTINUE_BACKDROP_TEXTURE_PATH,
		CHANCE_GEM_FULL_TEXTURE_PATH,
		CHANCE_GEM_BROKEN_TEXTURE_PATH,
		CHANCE_GEM_SHATTER_SHEET_TEXTURE_PATH,
	]


func _prewarm_liveliness_effects() -> void:
	ImpactFlareTextureCache.prewarm()


func _ensure_gem_shatter_fx_host(owner: Object) -> Node:
	if _is_valid_gem_shatter_fx_host(_gem_shatter_fx_host):
		return _gem_shatter_fx_host
	if not (owner is Node):
		return null
	var parent := owner as Node
	var existing := parent.get_node_or_null(DefeatGemShatterFxHost.HOST_NAME)
	if _is_valid_gem_shatter_fx_host(existing):
		_gem_shatter_fx_host = existing
		return _gem_shatter_fx_host
	var host := DefeatGemShatterFxHost.new()
	host.name = DefeatGemShatterFxHost.HOST_NAME
	host.visible = false
	parent.add_child(host)
	_gem_shatter_fx_host = host
	return _gem_shatter_fx_host


func _is_valid_gem_shatter_fx_host(host: Node) -> bool:
	return host != null and is_instance_valid(host) and not host.is_queued_for_deletion()


func _set_gem_shatter_fx_active(enabled: bool) -> void:
	if _is_valid_gem_shatter_fx_host(_gem_shatter_fx_host) and _gem_shatter_fx_host.has_method("set_active"):
		_gem_shatter_fx_host.set_active(enabled)


func _sync_gem_shatter_fx_host(owner: Object, view_size: Vector2, allow_create: bool) -> void:
	var host := _gem_shatter_fx_host
	if allow_create:
		host = _ensure_gem_shatter_fx_host(owner)
	if not _is_valid_gem_shatter_fx_host(host):
		return
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		if host.has_method("set_active"):
			host.set_active(false)
		return
	var consumed: int = max_gems - _get_visual_remaining_gems()
	var is_breaking := active and consumed > 0 and _is_shatter_window_active()
	if not is_breaking:
		if host.has_method("set_active"):
			host.set_active(false)
		return
	if host.has_method("sync_state"):
		var shatter_progress := _get_shatter_progress()
		host.sync_state({
			"view_size": view_size,
			"gem_center": _get_consumed_gem_center(view_size, consumed),
			"progress": shatter_progress,
			"elapsed": shatter_progress * GEM_SHATTER_DURATION_SEC,
			"quality_scale": 1.0,
		}, true)


func _ensure_color_restore_fx_host(owner: Object) -> Node:
	if _is_valid_color_restore_fx_host(_color_restore_fx_host):
		return _color_restore_fx_host
	if not (owner is Node):
		return null
	var parent := owner as Node
	var existing := parent.get_node_or_null(DefeatContinueColorRestoreFxHost.HOST_NAME)
	if _is_valid_color_restore_fx_host(existing):
		_color_restore_fx_host = existing
		return _color_restore_fx_host
	var host := DefeatContinueColorRestoreFxHost.new()
	host.name = DefeatContinueColorRestoreFxHost.HOST_NAME
	host.visible = false
	parent.add_child(host)
	_color_restore_fx_host = host
	return _color_restore_fx_host


func _is_valid_color_restore_fx_host(host: Node) -> bool:
	return host != null and is_instance_valid(host) and not host.is_queued_for_deletion()


func _set_color_restore_fx_active(enabled: bool) -> void:
	if _is_valid_color_restore_fx_host(_color_restore_fx_host) and _color_restore_fx_host.has_method("set_active"):
		_color_restore_fx_host.set_active(enabled)


func _sync_color_restore_fx_host(owner: Object, view_size: Vector2, allow_create: bool) -> void:
	var host := _color_restore_fx_host
	if allow_create:
		host = _ensure_color_restore_fx_host(owner)
	if not _is_valid_color_restore_fx_host(host):
		return
	var beat_state := _get_continue_revival_beat_state()
	if beat_state == null or not beat_state.has_method("get_color_restore_status"):
		if host.has_method("set_active"):
			host.set_active(false)
		return
	var status: Variant = beat_state.get_color_restore_status(view_size)
	if not (status is Dictionary):
		if host.has_method("set_active"):
			host.set_active(false)
		return
	if host.has_method("sync_state"):
		host.sync_state(status, bool((status as Dictionary).get("active", false)))


func _start_continue_revival_beat(source_screen_pos: Vector2, view_size: Vector2) -> void:
	var beat_state := _get_continue_revival_beat_state()
	if beat_state == null or not beat_state.has_method("start"):
		return
	beat_state.start(_pending_owner, source_screen_pos, view_size)


func _update_continue_revival_beat(delta: float) -> void:
	var beat_state := _get_continue_revival_beat_state()
	if beat_state != null and beat_state.has_method("update"):
		beat_state.update(delta, _pending_owner, _get_revival_view_size(_pending_owner))


func _draw_continue_revival_beat(canvas: CanvasItem, owner: Object, registry: Object, view_size: Vector2) -> void:
	var beat_state := _get_registry_instance(registry, "defeat_continue_revival_beat_state")
	if beat_state != null and beat_state.has_method("draw_overlay"):
		beat_state.draw_overlay(canvas, owner, view_size)


func _stop_continue_revival_beat() -> void:
	var beat_state := _get_continue_revival_beat_state()
	if beat_state != null and beat_state.has_method("reset"):
		beat_state.reset(_pending_owner)


func _is_continue_revival_beat_active() -> bool:
	var beat_state := _get_continue_revival_beat_state()
	if beat_state != null and beat_state.has_method("blocks_battle_physics"):
		return bool(beat_state.blocks_battle_physics())
	return false


func _get_continue_revival_beat_state() -> Object:
	return _get_registry_instance(_pending_registry, "defeat_continue_revival_beat_state")


func _get_consumed_gem_center(view_size: Vector2, consumed: int) -> Vector2:
	var center := view_size * 0.5
	var gem_center_y := _scaled_y(view_size, 540.0)
	var gem_gap := minf(view_size.x * 0.095, 122.0)
	var first_x := center.x - gem_gap
	var index := clampi(consumed - 1, 0, max_gems - 1)
	return Vector2(first_x + float(index) * gem_gap, gem_center_y)


func _get_owner_view_size(owner: Object) -> Vector2:
	if owner is CanvasItem:
		var canvas_item := owner as CanvasItem
		if canvas_item.is_inside_tree() and canvas_item.get_viewport() != null:
			return canvas_item.get_viewport_rect().size
	if owner is Node:
		var node := owner as Node
		if node.is_inside_tree() and node.get_viewport() != null:
			return node.get_viewport().get_visible_rect().size
	return Vector2.ZERO


func _get_revival_view_size(owner: Object) -> Vector2:
	var view_size := _get_owner_view_size(owner)
	if view_size.x > 1.0 and view_size.y > 1.0:
		return view_size
	return REVIVAL_FALLBACK_VIEW_SIZE


func _draw_ellipse_arc(canvas: CanvasItem, rect: Rect2, start_angle: float, end_angle: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	var center := rect.get_center()
	var radius_x := rect.size.x * 0.5
	var radius_y := rect.size.y * 0.5
	for i in range(28):
		var t := float(i) / 27.0
		var angle := start_angle + (end_angle - start_angle) * t
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	canvas.draw_polyline(points, color, width)


func _get_cached_backdrop_texture() -> Texture2D:
	return ProjectResourceLoader.get_cached_texture(DEFEAT_CONTINUE_BACKDROP_TEXTURE_PATH)


func _get_cached_gem_texture(broken: bool) -> Texture2D:
	var path := CHANCE_GEM_BROKEN_TEXTURE_PATH if broken else CHANCE_GEM_FULL_TEXTURE_PATH
	return ProjectResourceLoader.get_cached_texture(path)


func _get_cached_gem_shatter_texture() -> Texture2D:
	return ProjectResourceLoader.get_cached_texture(CHANCE_GEM_SHATTER_SHEET_TEXTURE_PATH)


func _get_static_gem_frame_size() -> Vector2:
	var texture := _get_cached_gem_texture(false)
	if texture == null:
		texture = _get_cached_gem_texture(true)
	if texture == null:
		return GEM_SHATTER_FALLBACK_FRAME_SIZE
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return GEM_SHATTER_FALLBACK_FRAME_SIZE
	return texture_size


func _fit_texture_rect(texture: Texture2D, center: Vector2, max_size: Vector2) -> Rect2:
	var texture_size := texture.get_size()
	return _fit_size_rect(texture_size, center, max_size)


func _fit_size_rect(source_size: Vector2, center: Vector2, max_size: Vector2) -> Rect2:
	var texture_size := source_size
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Rect2(center, Vector2.ZERO)
	var scale_factor := minf(max_size.x / texture_size.x, max_size.y / texture_size.y)
	var draw_size := texture_size * scale_factor
	return Rect2(center - draw_size * 0.5, draw_size)


func _cover_texture_rect(texture: Texture2D, target: Rect2) -> Rect2:
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0 or target.size.x <= 0.0 or target.size.y <= 0.0:
		return Rect2(target.position, Vector2.ZERO)
	var scale_factor := maxf(target.size.x / texture_size.x, target.size.y / texture_size.y)
	var draw_size := texture_size * scale_factor
	return Rect2(target.get_center() - draw_size * 0.5, draw_size)


func _is_confirm_event(event: InputEvent, view_size: Vector2) -> bool:
	if event == null:
		return false
	if event.is_action_pressed("ui_accept"):
		return true
	if event is InputEventKey:
		var key_event: InputEventKey = event
		return key_event.pressed and not key_event.echo and key_event.keycode in [KEY_ENTER, KEY_SPACE]
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		return (
			mouse_event.pressed
			and mouse_event.button_index == MOUSE_BUTTON_LEFT
			and _get_button_rect(view_size).has_point(mouse_event.position)
		)
	return false


func _begin_continue_cinematic(owner: Object) -> void:
	if _phase != ContinuePhase.PRESENT:
		return
	_phase = ContinuePhase.CONSUMING
	_play_defeat_jewel_sfx()
	confirm_elapsed = 0.0
	_fire_consume_once()
	_set_gem_shatter_fx_active(false)
	_queue_redraw(owner)


func _fire_consume_once() -> void:
	if _consume_fired:
		return
	_consume_fired = true
	var fallback_remaining := maxi(0, remaining_gems - 1)
	_post_consume_remaining_gems = fallback_remaining
	if _pending_consume_callback.is_valid():
		var result: Variant = _pending_consume_callback.call()
		if result != null:
			_post_consume_remaining_gems = clampi(int(result), 0, max_gems)


func _play_defeat_jewel_sfx() -> void:
	var audio := _get_registry_instance(_pending_registry, "game_audio")
	if audio != null and audio.has_method("play_defeat_jewel"):
		audio.play_defeat_jewel()


func _fire_shatter_sfx_if_ready() -> void:
	if _shatter_sfx_fired or not _has_shatter_started():
		return
	_shatter_sfx_fired = true
	_play_defeat_gem_shatter_sfx()


func _play_defeat_gem_shatter_sfx() -> void:
	var audio := _get_registry_instance(_pending_registry, "game_audio")
	if audio != null and audio.has_method("play_defeat_gem_shatter"):
		audio.play_defeat_gem_shatter()


func _fire_continue_reset_if_ready() -> void:
	if _continue_reset_fired or _phase != ContinuePhase.CONSUMING:
		return
	if confirm_elapsed < CONFIRM_RESET_TIME_SEC:
		return
	var callback := _pending_continue_callback
	var view_size := _get_revival_view_size(_pending_owner)
	var consumed_after_reset := clampi(max_gems - _post_consume_remaining_gems, 1, max_gems)
	var source_screen_pos := _get_consumed_gem_center(view_size, consumed_after_reset)
	_continue_reset_fired = true
	remaining_gems = _post_consume_remaining_gems
	_pending_continue_callback = Callable()
	_pending_consume_callback = Callable()
	_set_gem_shatter_fx_active(false)
	if callback.is_valid():
		callback.call()
	_start_continue_revival_beat(source_screen_pos, view_size)


func _get_visual_remaining_gems() -> int:
	if _phase == ContinuePhase.CONSUMING and _has_shatter_started():
		return _post_consume_remaining_gems
	return remaining_gems


func _get_breaking_gem_index() -> int:
	if _phase != ContinuePhase.CONSUMING or _continue_reset_fired:
		return -1
	var index := max_gems - remaining_gems
	if index < 0 or index >= max_gems:
		return -1
	return index


func _has_shatter_started() -> bool:
	return _phase == ContinuePhase.CONSUMING and confirm_elapsed >= CONFIRM_SHATTER_START_SEC


func _has_shatter_completed() -> bool:
	return _phase == ContinuePhase.CONSUMING and confirm_elapsed >= CONFIRM_SHATTER_START_SEC + CONFIRM_SHATTER_DURATION_SEC


func _is_shatter_window_active() -> bool:
	return (
		_phase == ContinuePhase.CONSUMING
		and confirm_elapsed >= CONFIRM_SHATTER_START_SEC
		and confirm_elapsed < CONFIRM_SHATTER_START_SEC + CONFIRM_SHATTER_DURATION_SEC
	)


func _get_shatter_progress() -> float:
	if _phase != ContinuePhase.CONSUMING:
		return 0.0
	return clampf((confirm_elapsed - CONFIRM_SHATTER_START_SEC) / maxf(CONFIRM_SHATTER_DURATION_SEC, 0.001), 0.0, 1.0)


func _get_confirm_shake_offset(index: int) -> Vector2:
	if _phase != ContinuePhase.CONSUMING or _has_shatter_started() or index != _get_breaking_gem_index():
		return Vector2.ZERO
	var progress := clampf(confirm_elapsed / maxf(CONFIRM_SHAKE_DURATION_SEC, 0.001), 0.0, 1.0)
	var intensity := progress * progress
	var amp := 2.0 + 7.0 * intensity
	var x := sin(confirm_elapsed * TAU * 8.2) * amp
	var y := sin(confirm_elapsed * TAU * 11.7 + 0.8) * amp * 0.42
	return Vector2(x, y)


func _get_pre_shatter_charge() -> float:
	if _phase != ContinuePhase.CONSUMING or confirm_elapsed < 0.10 or _has_shatter_started():
		return 0.0
	var progress := clampf(confirm_elapsed / maxf(CONFIRM_SHAKE_DURATION_SEC, 0.001), 0.0, 1.0)
	return progress * progress


func _get_pre_shatter_crack() -> float:
	if _phase != ContinuePhase.CONSUMING or confirm_elapsed < 0.55 or _has_shatter_started():
		return 0.0
	var progress := clampf((confirm_elapsed - 0.55) / maxf(CONFIRM_SHAKE_DURATION_SEC - 0.55, 0.001), 0.0, 1.0)
	return _ease_in_out_cubic(progress)


func _get_impact_time() -> float:
	if _phase != ContinuePhase.CONSUMING:
		return -1.0
	return confirm_elapsed - CONFIRM_SHATTER_START_SEC


func _get_impact_flash_alpha() -> float:
	var time := _get_impact_time()
	if time < 0.0 or time > IMPACT_FLASH_DURATION_SEC:
		return 0.0
	var progress := clampf(time / maxf(IMPACT_FLASH_DURATION_SEC, 0.001), 0.0, 1.0)
	return pow(1.0 - progress, 2.1)


func _get_impact_ring_progress() -> float:
	var time := _get_impact_time()
	if time < 0.0:
		return 0.0
	return clampf(time / maxf(IMPACT_RING_DURATION_SEC, 0.001), 0.0, 1.0)


func _get_impact_ring_alpha() -> float:
	var progress := _get_impact_ring_progress()
	if progress <= 0.0 or progress >= 1.0:
		return 0.0
	return pow(1.0 - progress, 1.35)


func _get_light_beam_alpha() -> float:
	var time := _get_impact_time()
	if time < 0.0 or time > IMPACT_BEAM_DURATION_SEC:
		return 0.0
	var progress := clampf(time / maxf(IMPACT_BEAM_DURATION_SEC, 0.001), 0.0, 1.0)
	var fade_in := clampf(progress / 0.16, 0.0, 1.0)
	var fade_out := pow(1.0 - progress, 1.5)
	return fade_in * fade_out


func _get_chroma_split_strength() -> float:
	var time := _get_impact_time()
	if time < 0.0 or time > IMPACT_CHROMA_DURATION_SEC:
		return 0.0
	var progress := clampf(time / maxf(IMPACT_CHROMA_DURATION_SEC, 0.001), 0.0, 1.0)
	return pow(1.0 - progress, 1.7)


func _get_impact_shake_offset() -> Vector2:
	var time := _get_impact_time()
	if time < 0.0 or time > IMPACT_SHAKE_DURATION_SEC:
		return Vector2.ZERO
	var progress := clampf(time / maxf(IMPACT_SHAKE_DURATION_SEC, 0.001), 0.0, 1.0)
	var trauma := pow(1.0 - progress, 2.4)
	var amp := 10.0 * trauma
	return Vector2(
		sin((confirm_elapsed + 0.11) * TAU * 16.0) * amp,
		sin((confirm_elapsed + 0.37) * TAU * 21.0) * amp * 0.55
	)


func _get_whiteout_alpha() -> float:
	if _phase != ContinuePhase.CONSUMING:
		return 0.0
	if confirm_elapsed < CONFIRM_WHITEOUT_START_SEC:
		return 0.0
	if confirm_elapsed <= CONFIRM_RESET_TIME_SEC:
		var rise := (confirm_elapsed - CONFIRM_WHITEOUT_START_SEC) / maxf(CONFIRM_RESET_TIME_SEC - CONFIRM_WHITEOUT_START_SEC, 0.001)
		return _ease_in_out_cubic(rise)
	var fade := (confirm_elapsed - CONFIRM_RESET_TIME_SEC) / maxf(CONFIRM_FADEBACK_END_SEC - CONFIRM_RESET_TIME_SEC, 0.001)
	return 1.0 - _ease_out_cubic(fade)


func _draw_whiteout(canvas: CanvasItem, view_size: Vector2) -> void:
	var alpha := _get_whiteout_alpha()
	if alpha <= 0.001:
		return
	if alpha < 0.995:
		var ripple_center := Vector2(view_size.x * 0.5, _scaled_y(view_size, 540.0))
		var ripple_progress := clampf((confirm_elapsed - CONFIRM_WHITEOUT_START_SEC) / maxf(CONFIRM_RESET_TIME_SEC - CONFIRM_WHITEOUT_START_SEC, 0.001), 0.0, 1.0)
		var fringe := sin(ripple_progress * PI)
		if fringe > 0.001:
			ImpactFlareTextureCache.draw_glow(canvas, ripple_center, minf(view_size.x, view_size.y) * (0.18 + 0.18 * ripple_progress), Color(0.48, 0.84, 1.0, 1.0), 0.18 * fringe)
			var ring_radius := minf(view_size.x, view_size.y) * (0.12 + 0.20 * _ease_out_cubic(ripple_progress))
			var ring_rect := Rect2(ripple_center - Vector2(ring_radius, ring_radius * 0.50), Vector2(ring_radius * 2.0, ring_radius))
			_draw_ellipse_arc(canvas, ring_rect, -PI * 0.02, PI * 0.92, Color(0.54, 0.88, 1.0, 0.24 * fringe), 2.0)
			_draw_ellipse_arc(canvas, ring_rect, PI * 1.04, PI * 1.82, Color(0.90, 0.98, 1.0, 0.18 * fringe), 1.3)
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.88, 0.95, 1.0, clampf(alpha, 0.0, 1.0)))


func _get_button_rect(view_size: Vector2) -> Rect2:
	var width_scale := clampf(view_size.x / 1280.0, 0.78, 1.08)
	var height_scale := clampf(view_size.y / 720.0, 0.90, 1.12)
	var scaled_size := Vector2(BUTTON_SIZE.x * width_scale, BUTTON_SIZE.y * height_scale)
	var top := minf(view_size.y - scaled_size.y - 26.0, _scaled_y(view_size, 676.0) - scaled_size.y * 0.5)
	return Rect2(Vector2(view_size.x * 0.5 - scaled_size.x * 0.5, top), scaled_size)


func _draw_centered_text(canvas: CanvasItem, font: Font, text: String, center: Vector2, font_size: int, color: Color) -> void:
	if font == null or text == "":
		return
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline := center - text_size * 0.5 + Vector2(0.0, text_size.y * 0.78)
	canvas.draw_string(font, baseline + Vector2(1.5, 1.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, color.a * 0.72))
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _scaled_y(view_size: Vector2, base_y: float) -> float:
	return base_y * clampf(view_size.y / 720.0, 0.78, 1.28)


func _scaled_font(view_size: Vector2, base_size: int) -> int:
	return max(10, int(round(float(base_size) * clampf(view_size.y / 720.0, 0.86, 1.18))))


func _ease_out_cubic(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


func _ease_in_out_cubic(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	if t < 0.5:
		return 4.0 * t * t * t
	return 1.0 - pow(-2.0 * t + 2.0, 3.0) * 0.5


func _get_ui_font() -> Font:
	return ThemeDB.fallback_font


func _read_int(owner: Object, key: String, fallback: int) -> int:
	if owner == null:
		return fallback
	var value: Variant = owner.get(key)
	if value == null:
		return fallback
	return int(value)


func _get_registry_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _queue_redraw(owner: Object) -> void:
	if owner != null and owner.has_method("queue_redraw"):
		owner.queue_redraw()
