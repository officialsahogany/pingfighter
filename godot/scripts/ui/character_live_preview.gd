@tool
extends Control

signal one_shot_finished

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const CharacterSelectPreviewVfxHost := preload("res://scripts/ui/character_select_preview_vfx_host.gd")

const LAYER_ORDER := [
	"back_hair",
	"body",
	"head",
	"front_hair",
	"eyes_open",
	"mouth",
	"glasses",
	"arm_back",
	"arm_front",
	"racket",
	"accessory",
	"effects",
]
const LOAD_LAYER_KEYS := [
	"back_hair",
	"body",
	"arm_back",
	"head",
	"front_hair",
	"eyes_open",
	"eyes_closed",
	"mouth",
	"glasses",
	"arm_front",
	"racket",
	"accessory",
	"effects",
]

var character: Dictionary = {}
var portrait_texture: Texture2D = null
var layer_textures: Dictionary = {}
var fullframe_sheet_texture: Texture2D = null
var fullframe_cols: int = 1
var fullframe_rows: int = 1
var fullframe_count: int = 1
var fullframe_interval: float = 0.16
var elapsed: float = 0.0
var look_offset: Vector2 = Vector2.ZERO
var interaction_hover_amount: float = 0.0
var interaction_click_flash: float = 0.0
var interaction_active: bool = false
var fullframe_trim_relative_rect := Rect2()
var fullframe_trim_valid: bool = false
var fullframe_loading: bool = false
var fullframe_loading_path: String = ""
var fullframe_loading_config: Dictionary = {}
var fullframe_loading_candidates: Array = []
var fullframe_loading_candidate_index: int = 0
var fullframe_loading_progress: float = 0.0
var fullframe_loading_failed: bool = false
var one_shot_active: bool = false
var one_shot_finished_emitted: bool = false
var one_shot_min_duration: float = 0.0
var one_shot_restore_after_finish: bool = true
var one_shot_trim_transparent_source: bool = false
var one_shot_float_motion_enabled: bool = false
var one_shot_align_bottom_to_cutline: bool = false
var one_shot_stage_scale: float = 1.0
var one_shot_stage_offset_ratio: Vector2 = Vector2.ZERO
var one_shot_restore_texture: Texture2D = null
var one_shot_restore_cols: int = 1
var one_shot_restore_rows: int = 1
var one_shot_restore_count: int = 1
var one_shot_restore_interval: float = 0.16
var one_shot_restore_elapsed_offset: float = 0.0
var one_shot_restore_elapsed_mode: String = "continue"
var one_shot_restore_trim_relative_rect := Rect2()
var one_shot_restore_trim_valid: bool = false
var one_shot_transition_texture: Texture2D = null
var one_shot_transition_cols: int = 1
var one_shot_transition_rows: int = 1
var one_shot_transition_count: int = 1
var one_shot_transition_interval: float = 0.16
var one_shot_transition_elapsed_offset: float = 0.0
var one_shot_transition_duration: float = 0.0
var one_shot_transition_trim_source: bool = true
var one_shot_transition_trim_relative_rect := Rect2()
var one_shot_transition_trim_valid: bool = false
var one_shot_return_transition_duration_pending: float = 0.0
var one_shot_return_transition_stage_scale_pending: float = 1.0
var one_shot_return_transition_stage_offset_ratio_pending: Vector2 = Vector2.ZERO
var one_shot_return_transition_float_motion_pending: bool = false
var one_shot_pending_return_config: Dictionary = {}
var one_shot_playing_configured_return: bool = false
var return_transition_texture: Texture2D = null
var return_transition_cols: int = 1
var return_transition_rows: int = 1
var return_transition_final_frame_index: int = 0
var return_transition_start_elapsed: float = 0.0
var return_transition_duration: float = 0.0
var return_transition_trim_source: bool = false
var return_transition_trim_relative_rect := Rect2()
var return_transition_trim_valid: bool = false
var return_transition_stage_scale: float = 1.0
var return_transition_stage_offset_ratio: Vector2 = Vector2.ZERO
var return_transition_float_motion_enabled: bool = false
var preview_vfx_host: Control = null
var preview_vfx_enabled: bool = true


func _ready() -> void:
	clip_contents = true
	_ensure_preview_vfx_host()
	_sync_preview_vfx_layout()


func _exit_tree() -> void:
	clear_runtime_state()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_sync_preview_vfx_layout()


func clear_runtime_state() -> void:
	_clear_preview_vfx()
	_drain_fullframe_sheet_load()
	character.clear()
	portrait_texture = null
	layer_textures.clear()
	fullframe_sheet_texture = null
	fullframe_cols = 1
	fullframe_rows = 1
	fullframe_count = 1
	fullframe_interval = 0.16
	fullframe_trim_relative_rect = Rect2()
	fullframe_trim_valid = false
	fullframe_loading = false
	fullframe_loading_path = ""
	fullframe_loading_config = {}
	fullframe_loading_candidates.clear()
	fullframe_loading_candidate_index = 0
	fullframe_loading_progress = 0.0
	fullframe_loading_failed = false
	one_shot_active = false
	one_shot_finished_emitted = false
	one_shot_min_duration = 0.0
	one_shot_pending_return_config.clear()
	one_shot_playing_configured_return = false
	_clear_one_shot_restore_source()
	_clear_one_shot_transition()
	_clear_return_transition()


func set_character(data: Dictionary, texture: Texture2D) -> void:
	_drain_fullframe_sheet_load()
	one_shot_active = false
	one_shot_finished_emitted = false
	one_shot_min_duration = 0.0
	one_shot_restore_after_finish = true
	one_shot_restore_elapsed_mode = "continue"
	one_shot_trim_transparent_source = false
	one_shot_float_motion_enabled = false
	one_shot_align_bottom_to_cutline = false
	one_shot_stage_scale = 1.0
	one_shot_stage_offset_ratio = Vector2.ZERO
	one_shot_return_transition_duration_pending = 0.0
	one_shot_return_transition_stage_scale_pending = 1.0
	one_shot_return_transition_stage_offset_ratio_pending = Vector2.ZERO
	one_shot_return_transition_float_motion_pending = false
	one_shot_pending_return_config.clear()
	one_shot_playing_configured_return = false
	_clear_one_shot_restore_source()
	_clear_one_shot_transition()
	_clear_return_transition()
	character = data.duplicate(true)
	portrait_texture = _load_preview_still_texture(texture)
	var fullframe_started := _begin_fullframe_sheet_load()
	if not fullframe_started:
		_load_layer_textures()
	if fullframe_sheet_texture != null:
		layer_textures.clear()
	_enforce_layer_policy()
	_sync_preview_vfx_character()
	queue_redraw()


func set_interaction_state(hover_amount: float, click_flash: float, active: bool) -> void:
	interaction_hover_amount = clamp(hover_amount, 0.0, 1.0)
	interaction_click_flash = clamp(click_flash, 0.0, 1.0)
	interaction_active = active
	_sync_preview_vfx_interaction()
	queue_redraw()


func play_confirm_vfx(config: Dictionary = {}) -> void:
	if not preview_vfx_enabled:
		return
	_ensure_preview_vfx_host()
	if preview_vfx_host != null and preview_vfx_host.has_method("play_confirm"):
		preview_vfx_host.call("play_confirm", config)


func _ensure_preview_vfx_host() -> void:
	if not preview_vfx_enabled:
		return
	if preview_vfx_host != null and is_instance_valid(preview_vfx_host):
		return
	var host: Control = CharacterSelectPreviewVfxHost.new()
	host.name = "CharacterSelectPreviewVfxHost"
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.position = Vector2.ZERO
	host.size = size
	host.z_index = -20
	add_child(host)
	move_child(host, 0)
	preview_vfx_host = host


func _sync_preview_vfx_character() -> void:
	_ensure_preview_vfx_host()
	if preview_vfx_host == null:
		return
	if character.is_empty():
		if preview_vfx_host.has_method("set_active"):
			preview_vfx_host.call("set_active", false)
		return
	if preview_vfx_host.has_method("set_character"):
		preview_vfx_host.call("set_character", character)
	if preview_vfx_enabled:
		_sync_preview_vfx_layout()
	_sync_preview_vfx_interaction()


func _sync_preview_vfx_interaction() -> void:
	if preview_vfx_host == null or not is_instance_valid(preview_vfx_host):
		return
	if preview_vfx_host.has_method("set_interaction_state"):
		preview_vfx_host.call(
			"set_interaction_state",
			interaction_hover_amount,
			interaction_click_flash,
			interaction_active or not character.is_empty()
		)


func _sync_preview_vfx_layout() -> void:
	if preview_vfx_host == null or not is_instance_valid(preview_vfx_host):
		return
	preview_vfx_host.position = Vector2.ZERO
	preview_vfx_host.size = size
	_sync_preview_vfx_look_offset()


func _sync_preview_vfx_look_offset() -> void:
	if preview_vfx_host == null or not is_instance_valid(preview_vfx_host):
		return
	if preview_vfx_host.has_method("set_look_offset"):
		preview_vfx_host.call("set_look_offset", look_offset)


func _clear_preview_vfx() -> void:
	if preview_vfx_host == null or not is_instance_valid(preview_vfx_host):
		preview_vfx_host = null
		return
	if preview_vfx_host.has_method("clear_runtime_state"):
		preview_vfx_host.call("clear_runtime_state")


func _is_preview_vfx_host_active() -> bool:
	return (
		preview_vfx_enabled
		and preview_vfx_host != null
		and is_instance_valid(preview_vfx_host)
		and preview_vfx_host.visible
	)


func play_fullframe_one_shot(config: Dictionary) -> bool:
	_drain_fullframe_sheet_load()
	var sheet_path := str(config.get("path", ""))
	if sheet_path == "":
		return false
	var texture := ProjectResourceLoader.load_imported_texture(
		sheet_path,
		"Missing character-select one-shot sheet: %s",
		"Failed to load character-select one-shot sheet: %s"
	)
	if texture == null:
		return false
	one_shot_restore_after_finish = bool(config.get("restore_after_finish", true))
	one_shot_restore_elapsed_mode = str(config.get("restore_elapsed_mode", "continue"))
	if one_shot_restore_after_finish:
		_capture_one_shot_restore_source()
	else:
		_clear_one_shot_restore_source()
	_capture_one_shot_transition_source(float(config.get("transition_duration", 0.0)))
	_clear_return_transition()
	var intro_duration: float = max(0.0, float(config.get("transition_duration", 0.0)))
	one_shot_return_transition_duration_pending = max(0.0, float(config.get("return_transition_duration", intro_duration)))
	one_shot_return_transition_stage_scale_pending = max(0.5, float(config.get("stage_scale", 1.0)))
	one_shot_return_transition_stage_offset_ratio_pending = Vector2(
		float(config.get("stage_x_offset_ratio", 0.0)),
		float(config.get("stage_y_offset_ratio", 0.0))
	)
	one_shot_return_transition_float_motion_pending = bool(config.get("float_motion_enabled", false))
	one_shot_pending_return_config = _build_configured_return_one_shot(config)
	one_shot_playing_configured_return = false
	_apply_fullframe_sheet_config(config)
	one_shot_min_duration = max(0.0, float(config.get("min_duration", 0.0)))
	fullframe_sheet_texture = texture
	ProjectResourceLoader.store_texture(sheet_path, texture)
	layer_textures.clear()
	fullframe_loading = false
	fullframe_loading_failed = false
	fullframe_loading_path = ""
	fullframe_loading_progress = 1.0
	fullframe_trim_relative_rect = Rect2()
	fullframe_trim_valid = false
	_apply_explicit_fullframe_trim_rect(config, "trim_rect")
	elapsed = 0.0
	one_shot_active = true
	one_shot_finished_emitted = false
	one_shot_trim_transparent_source = bool(config.get("trim_transparent_source", false))
	one_shot_float_motion_enabled = bool(config.get("float_motion_enabled", false))
	one_shot_align_bottom_to_cutline = bool(config.get("align_bottom_to_cutline", false))
	one_shot_stage_scale = max(0.5, float(config.get("stage_scale", 1.0)))
	one_shot_stage_offset_ratio = Vector2(
		float(config.get("stage_x_offset_ratio", 0.0)),
		float(config.get("stage_y_offset_ratio", 0.0))
	)
	queue_redraw()
	return true


func _capture_one_shot_restore_source() -> void:
	one_shot_restore_texture = fullframe_sheet_texture
	one_shot_restore_cols = fullframe_cols
	one_shot_restore_rows = fullframe_rows
	one_shot_restore_count = fullframe_count
	one_shot_restore_interval = fullframe_interval
	one_shot_restore_elapsed_offset = elapsed
	one_shot_restore_trim_relative_rect = fullframe_trim_relative_rect
	one_shot_restore_trim_valid = fullframe_trim_valid


func _clear_one_shot_restore_source() -> void:
	one_shot_restore_texture = null
	one_shot_restore_cols = 1
	one_shot_restore_rows = 1
	one_shot_restore_count = 1
	one_shot_restore_interval = 0.16
	one_shot_restore_elapsed_offset = 0.0
	one_shot_restore_elapsed_mode = "continue"
	one_shot_restore_trim_relative_rect = Rect2()
	one_shot_restore_trim_valid = false


func _capture_one_shot_transition_source(duration: float) -> void:
	_clear_one_shot_transition()
	if duration <= 0.0 or fullframe_sheet_texture == null:
		return
	if bool(character.get("live2d_trim_transparent_source", true)) and not fullframe_trim_valid:
		_apply_explicit_fullframe_trim_rect(character, "live2d_trim_rect")
	if bool(character.get("live2d_trim_transparent_source", true)) and not fullframe_trim_valid:
		_build_fullframe_trim_rect()
	one_shot_transition_texture = fullframe_sheet_texture
	one_shot_transition_cols = fullframe_cols
	one_shot_transition_rows = fullframe_rows
	one_shot_transition_count = fullframe_count
	one_shot_transition_interval = fullframe_interval
	one_shot_transition_elapsed_offset = elapsed
	one_shot_transition_duration = max(0.01, duration)
	one_shot_transition_trim_source = bool(character.get("live2d_trim_transparent_source", true))
	one_shot_transition_trim_relative_rect = fullframe_trim_relative_rect
	one_shot_transition_trim_valid = fullframe_trim_valid


func _clear_one_shot_transition() -> void:
	one_shot_transition_texture = null
	one_shot_transition_cols = 1
	one_shot_transition_rows = 1
	one_shot_transition_count = 1
	one_shot_transition_interval = 0.16
	one_shot_transition_elapsed_offset = 0.0
	one_shot_transition_duration = 0.0
	one_shot_transition_trim_source = true
	one_shot_transition_trim_relative_rect = Rect2()
	one_shot_transition_trim_valid = false


func _clear_return_transition() -> void:
	return_transition_texture = null
	return_transition_cols = 1
	return_transition_rows = 1
	return_transition_final_frame_index = 0
	return_transition_start_elapsed = 0.0
	return_transition_duration = 0.0
	return_transition_trim_source = false
	return_transition_trim_relative_rect = Rect2()
	return_transition_trim_valid = false
	return_transition_stage_scale = 1.0
	return_transition_stage_offset_ratio = Vector2.ZERO
	return_transition_float_motion_enabled = false


func _build_configured_return_one_shot(config: Dictionary) -> Dictionary:
	var return_path := str(config.get("return_sheet_path", ""))
	if return_path == "":
		return {}
	return {
		"path": return_path,
		"cols": int(config.get("return_cols", 1)),
		"rows": int(config.get("return_rows", 1)),
		"count": int(config.get("return_count", 1)),
		"interval": float(config.get("return_interval", config.get("interval", 0.033))),
		"min_interval": float(config.get("return_min_interval", config.get("min_interval", 0.016))),
		"min_duration": float(config.get("return_min_duration", 0.0)),
		"trim_transparent_source": bool(config.get("return_trim_transparent_source", config.get("trim_transparent_source", false))),
		"trim_rect": config.get("return_trim_rect", Rect2()),
		"float_motion_enabled": bool(config.get("return_float_motion_enabled", config.get("float_motion_enabled", false))),
		"align_bottom_to_cutline": bool(config.get("return_align_bottom_to_cutline", config.get("align_bottom_to_cutline", false))),
		"stage_scale": float(config.get("return_stage_scale", config.get("stage_scale", 1.0))),
		"stage_x_offset_ratio": float(config.get("return_stage_x_offset_ratio", config.get("stage_x_offset_ratio", 0.0))),
		"stage_y_offset_ratio": float(config.get("return_stage_y_offset_ratio", config.get("stage_y_offset_ratio", 0.0))),
	}


func _start_configured_return_one_shot() -> bool:
	_drain_fullframe_sheet_load()
	if one_shot_pending_return_config.is_empty():
		return false
	var config := one_shot_pending_return_config.duplicate(true)
	one_shot_pending_return_config.clear()
	var sheet_path := str(config.get("path", ""))
	if sheet_path == "":
		return false
	var texture := ProjectResourceLoader.load_imported_texture(
		sheet_path,
		"Missing character-select return sheet: %s",
		"Failed to load character-select return sheet: %s"
	)
	if texture == null:
		return false
	_clear_one_shot_transition()
	_clear_return_transition()
	one_shot_return_transition_duration_pending = 0.0
	one_shot_return_transition_stage_scale_pending = 1.0
	one_shot_return_transition_stage_offset_ratio_pending = Vector2.ZERO
	one_shot_return_transition_float_motion_pending = false
	_apply_fullframe_sheet_config(config)
	one_shot_min_duration = max(0.0, float(config.get("min_duration", 0.0)))
	fullframe_sheet_texture = texture
	ProjectResourceLoader.store_texture(sheet_path, texture)
	layer_textures.clear()
	fullframe_loading = false
	fullframe_loading_failed = false
	fullframe_loading_path = ""
	fullframe_loading_progress = 1.0
	fullframe_trim_relative_rect = Rect2()
	fullframe_trim_valid = false
	_apply_explicit_fullframe_trim_rect(config, "trim_rect")
	elapsed = 0.0
	one_shot_active = true
	one_shot_finished_emitted = false
	one_shot_restore_after_finish = true
	one_shot_playing_configured_return = true
	one_shot_trim_transparent_source = bool(config.get("trim_transparent_source", false))
	one_shot_float_motion_enabled = bool(config.get("float_motion_enabled", false))
	one_shot_align_bottom_to_cutline = bool(config.get("align_bottom_to_cutline", false))
	one_shot_stage_scale = max(0.5, float(config.get("stage_scale", 1.0)))
	one_shot_stage_offset_ratio = Vector2(
		float(config.get("stage_x_offset_ratio", 0.0)),
		float(config.get("stage_y_offset_ratio", 0.0))
	)
	queue_redraw()
	return true


func _capture_return_transition_source() -> void:
	_clear_return_transition()
	if one_shot_return_transition_duration_pending <= 0.0:
		return
	if fullframe_sheet_texture == null:
		return
	if one_shot_trim_transparent_source and not fullframe_trim_valid:
		_apply_explicit_fullframe_trim_rect(character, "live2d_trim_rect")
	if one_shot_trim_transparent_source and not fullframe_trim_valid:
		_build_fullframe_trim_rect()
	return_transition_texture = fullframe_sheet_texture
	return_transition_cols = max(1, fullframe_cols)
	return_transition_rows = max(1, fullframe_rows)
	var frame_total: int = max(1, fullframe_count)
	return_transition_final_frame_index = clamp(frame_total - 1, 0, return_transition_cols * return_transition_rows - 1)
	return_transition_duration = max(0.01, one_shot_return_transition_duration_pending)
	return_transition_trim_source = one_shot_trim_transparent_source
	return_transition_trim_relative_rect = fullframe_trim_relative_rect
	return_transition_trim_valid = fullframe_trim_valid
	return_transition_stage_scale = one_shot_return_transition_stage_scale_pending
	return_transition_stage_offset_ratio = one_shot_return_transition_stage_offset_ratio_pending
	return_transition_float_motion_enabled = one_shot_return_transition_float_motion_pending


func is_one_shot_playing() -> bool:
	return one_shot_active and not one_shot_finished_emitted


func _process(delta: float) -> void:
	elapsed += delta
	_poll_fullframe_sheet_load()
	_update_one_shot_state()
	if one_shot_transition_texture != null and elapsed >= one_shot_transition_duration:
		_clear_one_shot_transition()
	if return_transition_texture != null and elapsed >= return_transition_start_elapsed + return_transition_duration:
		_clear_return_transition()
	var local_mouse := get_local_mouse_position()
	var target := Vector2.ZERO
	if Rect2(Vector2.ZERO, size).has_point(local_mouse):
		var center := size * 0.5
		var denom: float = max(1.0, min(size.x, size.y))
		target = (local_mouse - center) / denom * 34.0
		target.x = clamp(target.x, -18.0, 18.0)
		target.y = clamp(target.y, -14.0, 14.0)
	look_offset = look_offset.lerp(target, min(1.0, delta * 8.0))
	_sync_preview_vfx_look_offset()
	queue_redraw()


func _update_one_shot_state() -> void:
	if not one_shot_active or one_shot_finished_emitted:
		return
	var frame_total: int = maxi(1, fullframe_count)
	var duration: float = maxf(maxf(fullframe_interval, fullframe_interval * float(frame_total)), one_shot_min_duration)
	if elapsed < duration:
		return
	one_shot_finished_emitted = true
	if one_shot_restore_after_finish:
		if not one_shot_playing_configured_return and _start_configured_return_one_shot():
			return
		_restore_one_shot_source()
	else:
		queue_redraw()
	one_shot_finished.emit()


func _restore_one_shot_source() -> void:
	var completed_one_shot_elapsed := elapsed
	_capture_return_transition_source()
	one_shot_active = false
	one_shot_finished_emitted = false
	one_shot_min_duration = 0.0
	one_shot_trim_transparent_source = false
	one_shot_float_motion_enabled = false
	one_shot_align_bottom_to_cutline = false
	one_shot_stage_scale = 1.0
	one_shot_stage_offset_ratio = Vector2.ZERO
	one_shot_playing_configured_return = false
	one_shot_pending_return_config.clear()
	_clear_one_shot_transition()
	if one_shot_restore_texture != null:
		fullframe_sheet_texture = one_shot_restore_texture
		fullframe_cols = max(1, one_shot_restore_cols)
		fullframe_rows = max(1, one_shot_restore_rows)
		var max_frame_count: int = fullframe_cols * fullframe_rows
		fullframe_count = clamp(one_shot_restore_count, 1, max_frame_count)
		fullframe_interval = max(0.016, one_shot_restore_interval)
		if one_shot_restore_elapsed_mode == "restart":
			elapsed = 0.0
		else:
			elapsed = one_shot_restore_elapsed_offset + completed_one_shot_elapsed
		fullframe_trim_relative_rect = one_shot_restore_trim_relative_rect
		fullframe_trim_valid = one_shot_restore_trim_valid
		fullframe_loading = false
		fullframe_loading_failed = false
		fullframe_loading_path = ""
		fullframe_loading_config = {}
		fullframe_loading_candidates.clear()
		fullframe_loading_candidate_index = 0
		fullframe_loading_progress = 1.0
		layer_textures.clear()
	else:
		fullframe_sheet_texture = null
		fullframe_trim_relative_rect = Rect2()
		fullframe_trim_valid = false
		fullframe_loading = false
		fullframe_loading_failed = false
		fullframe_loading_path = ""
		fullframe_loading_config = {}
		fullframe_loading_candidates.clear()
		fullframe_loading_candidate_index = 0
		fullframe_loading_progress = 0.0
		if not _begin_fullframe_sheet_load():
			_load_layer_textures()
	_clear_one_shot_restore_source()
	if return_transition_texture != null:
		return_transition_start_elapsed = elapsed
	one_shot_return_transition_duration_pending = 0.0
	queue_redraw()


func _draw() -> void:
	if size.x < 4.0 or size.y < 4.0:
		return
	var accent := _accent_color()
	var glow := _glow_color()
	_draw_preview_backdrop(accent, glow)

	var floor_y := _stage_floor_y()
	var art_w: float = min(size.x * 0.88, size.y * 1.04)
	var art_h: float = size.y * 0.80
	var art_rect := Rect2(Vector2((size.x - art_w) * 0.5, floor_y - art_h + size.y * 0.02), Vector2(art_w, art_h))
	var art_scale: float = max(0.50, float(character.get("live2d_stage_scale", 1.0)))
	if abs(art_scale - 1.0) > 0.001:
		var anchored_bottom := art_rect.end.y
		art_rect.size *= art_scale
		art_rect.position.x = (size.x - art_rect.size.x) * 0.5
		art_rect.position.y = anchored_bottom - art_rect.size.y
	var art_x_scale: float = max(0.50, float(character.get("live2d_stage_x_scale", 1.0)))
	if abs(art_x_scale - 1.0) > 0.001:
		var center_x: float = art_rect.get_center().x
		art_rect.size.x *= art_x_scale
		art_rect.position.x = center_x - art_rect.size.x * 0.5
	art_rect.position.y += size.y * float(character.get("live2d_stage_y_offset", 0.0))
	var min_top_ratio: float = float(character.get("live2d_stage_min_top_ratio", -1.0))
	if min_top_ratio >= 0.0:
		var min_top: float = size.y * min_top_ratio
		if art_rect.position.y < min_top:
			art_rect.position.y = min_top

	if fullframe_sheet_texture != null:
		_draw_fullframe_sheet_preview(art_rect)
	elif _has_layer_textures():
		_draw_layered_preview(art_rect)
	elif portrait_texture != null:
		_draw_card_parallax_preview(art_rect)
	else:
		_draw_procedural_preview(art_rect)

	_draw_character_bottom_apron(accent, glow)
	_draw_scanlines(glow)
	_draw_nameplate(accent, glow)
	_draw_interaction_overlay(accent, glow)
	_draw_fullframe_loading_badge(accent, glow)
	_draw_preview_card_frame(accent, glow)


func _begin_fullframe_sheet_load() -> bool:
	_drain_fullframe_sheet_load()
	fullframe_sheet_texture = null
	fullframe_trim_relative_rect = Rect2()
	fullframe_trim_valid = false
	fullframe_loading = false
	fullframe_loading_failed = false
	fullframe_loading_path = ""
	fullframe_loading_config = {}
	fullframe_loading_candidates.clear()
	fullframe_loading_candidate_index = 0
	fullframe_loading_progress = 0.0
	fullframe_cols = max(1, int(character.get("live2d_fullframe_cols", 1)))
	fullframe_rows = max(1, int(character.get("live2d_fullframe_rows", 1)))
	var max_frame_count: int = fullframe_cols * fullframe_rows
	fullframe_count = clamp(int(character.get("live2d_fullframe_count", max_frame_count)), 1, max_frame_count)
	fullframe_interval = max(0.016, float(character.get("live2d_fullframe_interval", 0.16)))
	var candidates_value: Variant = character.get("live2d_fullframe_sheet_candidates", [])
	if candidates_value is Array:
		for candidate_value in candidates_value:
			if not (candidate_value is Dictionary):
				continue
			var candidate: Dictionary = candidate_value
			var candidate_path := str(candidate.get("path", ""))
			if candidate_path == "":
				continue
			fullframe_loading_candidates.append(candidate.duplicate(true))
	var sheet_path := str(character.get("live2d_fullframe_sheet_path", ""))
	if fullframe_loading_candidates.is_empty() and sheet_path != "":
		fullframe_loading_candidates.append({
			"path": sheet_path,
			"cols": fullframe_cols,
			"rows": fullframe_rows,
			"count": fullframe_count,
			"interval": fullframe_interval,
		})
	return _request_next_fullframe_sheet()


func _request_next_fullframe_sheet() -> bool:
	fullframe_loading = false
	fullframe_loading_path = ""
	fullframe_loading_config = {}
	while fullframe_loading_candidate_index < fullframe_loading_candidates.size():
		var candidate_value: Variant = fullframe_loading_candidates[fullframe_loading_candidate_index]
		fullframe_loading_candidate_index += 1
		if not (candidate_value is Dictionary):
			continue
		var candidate: Dictionary = candidate_value
		var candidate_path := str(candidate.get("path", ""))
		if candidate_path == "":
			continue
		var cached_texture := ProjectResourceLoader.get_cached_texture(candidate_path)
		if cached_texture != null:
			_finish_fullframe_sheet_load(candidate_path, candidate, cached_texture)
			return true
		if not _can_thread_load_texture(candidate_path):
			var fallback_texture := ProjectResourceLoader.load_imported_texture(candidate_path)
			if fallback_texture != null:
				_finish_fullframe_sheet_load(candidate_path, candidate, fallback_texture)
				return true
			continue
		var request_error := ResourceLoader.load_threaded_request(candidate_path, "Texture2D", true)
		if request_error == OK or request_error == ERR_BUSY:
			fullframe_loading = true
			fullframe_loading_path = candidate_path
			fullframe_loading_config = candidate.duplicate(true)
			fullframe_loading_progress = max(fullframe_loading_progress, 0.01)
			return true
	fullframe_loading_failed = not fullframe_loading_candidates.is_empty()
	if fullframe_sheet_texture == null:
		_load_layer_textures()
		_enforce_layer_policy()
	return false


func _can_thread_load_texture(path: String) -> bool:
	return FileAccess.file_exists("%s.import" % path) or ResourceLoader.exists(path, "Texture2D")


func _poll_fullframe_sheet_load() -> void:
	if not fullframe_loading or fullframe_loading_path == "":
		return
	var progress_values: Array = []
	var status := ResourceLoader.load_threaded_get_status(fullframe_loading_path, progress_values)
	if progress_values.size() > 0:
		fullframe_loading_progress = clamp(max(fullframe_loading_progress, float(progress_values[0])), 0.0, 1.0)
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			var resource := ResourceLoader.load_threaded_get(fullframe_loading_path)
			var texture := resource as Texture2D
			if texture != null:
				_finish_fullframe_sheet_load(fullframe_loading_path, fullframe_loading_config, texture)
			elif not _request_next_fullframe_sheet():
				queue_redraw()
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			if not _request_next_fullframe_sheet():
				queue_redraw()


func _drain_fullframe_sheet_load() -> void:
	if not fullframe_loading or fullframe_loading_path == "":
		return
	var path := fullframe_loading_path
	fullframe_loading = false
	fullframe_loading_path = ""
	fullframe_loading_config = {}
	fullframe_loading_progress = 0.0
	if not _can_thread_load_texture(path):
		return
	var progress_values: Array = []
	var status := ResourceLoader.load_threaded_get_status(path, progress_values)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		ResourceLoader.load_threaded_get(path)


func _finish_fullframe_sheet_load(path: String, config: Dictionary, texture: Texture2D) -> void:
	_apply_fullframe_sheet_config(config)
	fullframe_sheet_texture = texture
	ProjectResourceLoader.store_texture(path, texture)
	layer_textures.clear()
	fullframe_loading = false
	fullframe_loading_failed = false
	fullframe_loading_path = ""
	fullframe_loading_progress = 1.0
	fullframe_trim_relative_rect = Rect2()
	fullframe_trim_valid = false
	_apply_explicit_fullframe_trim_rect(config, "trim_rect")
	if not fullframe_trim_valid:
		_apply_explicit_fullframe_trim_rect(character, "live2d_trim_rect")
	queue_redraw()


func _apply_fullframe_sheet_config(config: Dictionary) -> void:
	fullframe_cols = max(1, int(config.get("cols", fullframe_cols)))
	fullframe_rows = max(1, int(config.get("rows", fullframe_rows)))
	var max_frame_count: int = fullframe_cols * fullframe_rows
	fullframe_count = clamp(int(config.get("count", max_frame_count)), 1, max_frame_count)
	var interval_floor: float = max(0.01, float(config.get("min_interval", 0.016)))
	fullframe_interval = max(interval_floor, float(config.get("interval", fullframe_interval)))


func _load_preview_still_texture(fallback: Texture2D) -> Texture2D:
	var still_path := str(character.get("live2d_preview_still_path", ""))
	if still_path == "":
		return fallback
	var still_texture := ProjectResourceLoader.load_texture(
		still_path,
		"Missing character preview still: %s",
		"Failed to load character preview still: %s"
	)
	return still_texture if still_texture != null else fallback


func _load_layer_textures() -> void:
	layer_textures.clear()
	var layers_value: Variant = character.get("live2d_layers", {})
	if not (layers_value is Dictionary):
		return
	var layers: Dictionary = layers_value
	for key in LOAD_LAYER_KEYS:
		var path := str(layers.get(key, ""))
		if path == "":
			continue
		var texture := ProjectResourceLoader.load_texture(path)
		if texture != null:
			layer_textures[key] = texture
	_enforce_layer_policy()


func _enforce_layer_policy() -> void:
	if not bool(character.get("live2d_canvas_locked", false)) and not bool(character.get("allow_free_live2d_parts", false)):
		layer_textures.clear()
	if bool(character.get("live2d_canvas_locked", false)) and not _has_registered_layer_set():
		layer_textures.clear()


func _has_layer_textures() -> bool:
	return layer_textures.has("body") or layer_textures.has("head")


func _has_registered_layer_set() -> bool:
	for required_key in ["body", "head", "eyes_open", "front_hair", "arm_front"]:
		if not layer_textures.has(required_key):
			return false
	var body: Texture2D = layer_textures.get("body", null)
	if body == null:
		return false
	var body_size := body.get_size()
	if body_size.x < 250.0 or body_size.y < 350.0:
		return false
	for key in layer_textures.keys():
		var texture: Texture2D = layer_textures.get(key, null)
		if texture == null:
			continue
		var size_value := texture.get_size()
		if abs(size_value.x - body_size.x) > 2.0 or abs(size_value.y - body_size.y) > 2.0:
			return false
	return true


func _draw_preview_backdrop(accent: Color, glow: Color) -> void:
	var host_backdrop_active := _is_preview_vfx_host_active()
	if not host_backdrop_active:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.018, 0.020, 0.034, 0.98))
		draw_rect(Rect2(Vector2(8.0, 8.0), size - Vector2(16.0, 16.0)), Color(0.026, 0.032, 0.052, 0.92))
	var floor_y := _stage_floor_y()
	if host_backdrop_active:
		_draw_preview_vfx_data_motes(accent, glow, floor_y)
		_draw_preview_vfx_scan_sweep(accent, glow, floor_y)
	var center := Vector2(size.x * 0.5, floor_y)
	_draw_ellipse(center + Vector2(0.0, size.y * 0.018), Vector2(size.x * 0.08, size.y * 0.011), Color(0.0, 0.0, 0.0, 0.22), true)
	_draw_stage_side_hud(accent, glow, floor_y)


func _draw_preview_vfx_data_motes(accent: Color, glow: Color, floor_y: float) -> void:
	var top_y: float = size.y * 0.16
	var travel_h: float = max(1.0, floor_y - top_y)
	var mote_count := 30
	for mote_index in range(mote_count):
		var seed := float(mote_index)
		var speed: float = 0.045 + _preview_vfx_hash(seed, 1.3) * 0.040
		var phase: float = fposmod(elapsed * speed + _preview_vfx_hash(seed, 4.7), 1.0)
		var y: float = floor_y - travel_h * phase
		var base_x: float = size.x * lerp(0.18, 0.82, _preview_vfx_hash(seed, 9.1))
		var sway: float = sin(elapsed * (0.62 + _preview_vfx_hash(seed, 2.1) * 0.55) + seed) * size.x * 0.020
		var point := Vector2(base_x + sway, y)
		var fade: float = sin(phase * PI)
		var radius: float = 1.0 + _preview_vfx_hash(seed, 6.2) * 1.8
		var alpha: float = fade * (0.10 + interaction_hover_amount * 0.055)
		var mote_color := glow.lerp(accent, _preview_vfx_hash(seed, 3.4))
		draw_circle(point, radius + 1.8, Color(mote_color.r, mote_color.g, mote_color.b, alpha * 0.22), true)
		draw_circle(point, radius, Color(mote_color.r, mote_color.g, mote_color.b, alpha), true)
		if mote_index % 5 == 0:
			draw_line(
				point + Vector2(0.0, radius + 2.0),
				point + Vector2(0.0, radius + 16.0),
				Color(mote_color.r, mote_color.g, mote_color.b, alpha * 0.45),
				1.0
			)


func _draw_preview_vfx_scan_sweep(accent: Color, glow: Color, floor_y: float) -> void:
	var scan_top: float = size.y * 0.14
	var scan_bottom: float = floor_y + size.y * 0.08
	var scan_span: float = max(1.0, scan_bottom - scan_top)
	var scan_phase: float = fposmod(elapsed * 0.16, 1.0)
	var scan_y: float = scan_top + scan_span * scan_phase
	var scan_alpha: float = 0.10 + interaction_hover_amount * 0.07
	for trail_index in range(4):
		var trail_offset: float = float(trail_index) * size.y * 0.018
		var trail_alpha: float = scan_alpha * (1.0 - float(trail_index) * 0.22)
		var y: float = scan_y - trail_offset
		if y < scan_top or y > scan_bottom:
			continue
		draw_line(
			Vector2(size.x * 0.22, y),
			Vector2(size.x * 0.78, y),
			Color(glow.r, glow.g, glow.b, trail_alpha),
			2.0 - float(trail_index) * 0.32
		)
		draw_line(
			Vector2(size.x * 0.32, y + size.y * 0.006),
			Vector2(size.x * 0.68, y + size.y * 0.006),
			Color(accent.r, accent.g, accent.b, trail_alpha * 0.55),
			1.0
		)
	var ring_center := Vector2(size.x * 0.5, floor_y + size.y * 0.010)
	var ring_radius := Vector2(min(size.x * 0.31, size.y * 0.34), size.y * 0.052)
	for tick_index in range(10):
		var phase: float = fposmod(elapsed * 0.26 + float(tick_index) / 10.0, 1.0)
		var angle: float = phase * TAU
		var point := ring_center + Vector2(cos(angle) * ring_radius.x, sin(angle) * ring_radius.y)
		var tangent := Vector2(-sin(angle), cos(angle)).normalized()
		var tick_alpha: float = (0.045 + interaction_hover_amount * 0.035) * (0.5 + 0.5 * sin(phase * PI))
		draw_line(
			point - tangent * size.x * 0.012,
			point + tangent * size.x * 0.012,
			Color(glow.r, glow.g, glow.b, tick_alpha),
			1.4
		)


func _preview_vfx_hash(a: float, b: float) -> float:
	var hashed := sin(a * 12.9898 + b * 78.233) * 43758.5453
	return hashed - floor(hashed)


func _draw_preview_card_frame(accent: Color, glow: Color) -> void:
	var pulse := 0.5 + sin(elapsed * 2.6) * 0.5
	var outer := Rect2(Vector2.ZERO, size).grow(-3.0)
	var mid := outer.grow(-8.0)
	var inner := outer.grow(-18.0)
	draw_rect(outer.grow(5.0), Color(glow.r, glow.g, glow.b, 0.12 + pulse * 0.05), false, 3.0)
	draw_rect(outer, Color(accent.r, accent.g, accent.b, 0.88), false, 3.0)
	draw_rect(mid, Color(glow.r, glow.g, glow.b, 0.28), false, 1.2)
	draw_rect(inner, Color(1.0, 1.0, 1.0, 0.10), false, 1.0)
	var corner_len: float = min(size.x, size.y) * 0.085
	var inset: float = 17.0
	var w: float = 2.0
	var corner_color := Color(glow.r, glow.g, glow.b, 0.62)
	var highlight := Color(1.0, 1.0, 1.0, 0.20)
	for corner in [
		Vector2(inset, inset),
		Vector2(size.x - inset, inset),
		Vector2(inset, size.y - inset),
		Vector2(size.x - inset, size.y - inset),
	]:
		var sx: float = 1.0 if corner.x < size.x * 0.5 else -1.0
		var sy: float = 1.0 if corner.y < size.y * 0.5 else -1.0
		draw_line(corner, corner + Vector2(corner_len * sx, 0.0), corner_color, w)
		draw_line(corner, corner + Vector2(0.0, corner_len * sy), corner_color, w)
		draw_line(corner + Vector2(5.0 * sx, 5.0 * sy), corner + Vector2(corner_len * 0.55 * sx, 5.0 * sy), highlight, 1.0)


func _draw_character_bottom_apron(accent: Color, glow: Color) -> void:
	var cutline_ratio: float = float(character.get("live2d_card_cutline_ratio", -1.0))
	if cutline_ratio <= 0.0:
		return
	var cut_y: float = _character_bottom_cutline_y()
	var apron := Rect2(0.0, cut_y, size.x, size.y - cut_y)
	for layer in range(6):
		var t: float = float(layer) / 5.0
		var y: float = cut_y + t * size.y * 0.030
		draw_rect(
			Rect2(0.0, y, size.x, size.y - y),
			Color(0.012, 0.016, 0.026, 0.34 + t * 0.08)
		)
	draw_rect(apron, Color(accent.r * 0.05, accent.g * 0.05, accent.b * 0.05, 0.34))
	draw_line(Vector2(size.x * 0.08, cut_y), Vector2(size.x * 0.92, cut_y), Color(glow.r, glow.g, glow.b, 0.70), 2.0)
	draw_line(Vector2(size.x * 0.18, cut_y + 7.0), Vector2(size.x * 0.82, cut_y + 7.0), Color(1.0, 1.0, 1.0, 0.12), 1.0)
	_draw_ellipse(
		Vector2(size.x * 0.5, cut_y + size.y * 0.036),
		Vector2(min(size.x * 0.32, size.y * 0.34), size.y * 0.034),
		Color(glow.r, glow.g, glow.b, 0.20),
		false,
		1.2
	)


func _character_bottom_cutline_y() -> float:
	var cutline_ratio: float = float(character.get("live2d_card_cutline_ratio", -1.0))
	if cutline_ratio <= 0.0:
		return _stage_floor_y()
	return clamp(size.y * cutline_ratio, size.y * 0.58, size.y - 96.0)


func _stage_floor_y() -> float:
	return size.y * 0.80


func _draw_stage_side_hud(accent: Color, glow: Color, floor_y: float) -> void:
	var panel_top: float = size.y * 0.25
	var panel_h: float = size.y * 0.30
	var _tick_h: float = max(6.0, size.y * 0.012)
	for side in [-1.0, 1.0]:
		var anchor_x: float = size.x * (0.17 if side < 0.0 else 0.83)
		var inner_x: float = anchor_x + side * size.x * 0.055
		draw_line(Vector2(anchor_x, panel_top), Vector2(anchor_x, panel_top + panel_h), Color(glow.r, glow.g, glow.b, 0.18), 1.2)
		draw_line(Vector2(anchor_x, panel_top), Vector2(inner_x, panel_top), Color(glow.r, glow.g, glow.b, 0.22), 1.2)
		draw_line(Vector2(anchor_x, panel_top + panel_h), Vector2(inner_x, panel_top + panel_h), Color(glow.r, glow.g, glow.b, 0.22), 1.2)
		for row in range(7):
			var t := float(row) / 6.0
			var y: float = lerp(panel_top + size.y * 0.035, panel_top + panel_h - size.y * 0.035, t)
			var length: float = size.x * (0.020 + 0.025 * (0.5 + sin(elapsed * 1.4 + float(row)) * 0.5))
			var start_x: float = anchor_x + side * size.x * 0.016
			draw_line(Vector2(start_x, y), Vector2(start_x + side * length, y), Color(accent.r, accent.g, accent.b, 0.18 + t * 0.10), 1.0)
		var diamond_center := Vector2(anchor_x + side * size.x * 0.026, panel_top - size.y * 0.035)
		var diamond_size: float = max(5.0, size.y * 0.014)
		var pts := PackedVector2Array([
			diamond_center + Vector2(0.0, -diamond_size),
			diamond_center + Vector2(side * diamond_size, 0.0),
			diamond_center + Vector2(0.0, diamond_size),
			diamond_center + Vector2(-side * diamond_size, 0.0),
		])
		draw_colored_polygon(pts, Color(accent.r, accent.g, accent.b, 0.24))
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(glow.r, glow.g, glow.b, 0.42), 1.0)
	var rail_y: float = floor_y + size.y * 0.135
	draw_line(Vector2(size.x * 0.33, rail_y), Vector2(size.x * 0.43, rail_y), Color(accent.r, accent.g, accent.b, 0.20), 2.0)
	draw_line(Vector2(size.x * 0.57, rail_y), Vector2(size.x * 0.67, rail_y), Color(accent.r, accent.g, accent.b, 0.20), 2.0)


func _draw_ellipse(center: Vector2, radius: Vector2, color: Color, filled: bool, width: float = 1.0) -> void:
	if radius.x <= 0.5 or radius.y <= 0.5:
		return
	var base_radius: float = max(radius.x, radius.y)
	draw_set_transform(center, 0.0, Vector2(radius.x / base_radius, radius.y / base_radius))
	if filled:
		draw_circle(Vector2.ZERO, base_radius, color, true)
	else:
		draw_circle(Vector2.ZERO, base_radius, color, false, width, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_fullframe_sheet_preview(art_rect: Rect2) -> void:
	if fullframe_sheet_texture == null:
		return
	var texture_size := fullframe_sheet_texture.get_size()
	if texture_size.x <= 1.0 or texture_size.y <= 1.0:
		return
	var frame_index := int(floor(elapsed / fullframe_interval)) % fullframe_count
	if one_shot_active:
		frame_index = clamp(int(floor(elapsed / fullframe_interval)), 0, max(0, fullframe_count - 1))
	var col := frame_index % fullframe_cols
	var row := int(floor(float(frame_index) / float(fullframe_cols)))
	var cell_size := Vector2(texture_size.x / float(fullframe_cols), texture_size.y / float(fullframe_rows))
	var source_rect := Rect2(Vector2(float(col) * cell_size.x, float(row) * cell_size.y), cell_size)
	var deform_still := fullframe_count == 1 and bool(character.get("live2d_deform_still", false))
	var natural_still := fullframe_count == 1 and not deform_still
	var render_source_rect := source_rect if deform_still or (one_shot_active and not one_shot_trim_transparent_source) else _fullframe_render_source_rect(source_rect)
	var bob_amount: float = float(character.get("live2d_float_bob", 2.0 if natural_still else 5.0))
	var sway_amount: float = float(character.get("live2d_float_sway", 0.8 if natural_still else 0.0))
	var scale_amount: float = float(character.get("live2d_float_scale", 0.005 if natural_still else 0.010))
	var mouse_response: float = float(character.get("live2d_mouse_response", 0.08 if natural_still else 0.16))
	if one_shot_active and not one_shot_float_motion_enabled:
		bob_amount = 0.0
		sway_amount = 0.0
		scale_amount = 0.0
		mouse_response = 0.0
	var bob := sin(elapsed * 1.18) * bob_amount + sin(elapsed * 0.61 + 1.3) * bob_amount * 0.20
	var sway := sin(elapsed * 0.82 + 0.7) * sway_amount
	var target_rect := _scale_rect(art_rect, 1.0 + sin(elapsed * 1.05) * scale_amount)
	target_rect.position += Vector2(look_offset.x * mouse_response + sway, look_offset.y * mouse_response * 0.65 + bob)
	if one_shot_active:
		if abs(one_shot_stage_scale - 1.0) > 0.001:
			target_rect = _scale_rect(target_rect, one_shot_stage_scale)
		target_rect.position += Vector2(size.x * one_shot_stage_offset_ratio.x, size.y * one_shot_stage_offset_ratio.y)
	var should_align_bottom := bool(character.get("live2d_align_bottom_to_cutline", false))
	if one_shot_active:
		should_align_bottom = should_align_bottom and one_shot_align_bottom_to_cutline
	if should_align_bottom:
		var aligned_rect := _live2d_stage_fit_rect(render_source_rect.size, target_rect)
		if aligned_rect.size.y > 1.0:
			target_rect.position.y += _character_bottom_cutline_y() - aligned_rect.end.y
	var fitted_rect := _live2d_stage_fit_rect(render_source_rect.size, target_rect)
	var glow := _glow_color()
	var pulse := 0.5 + sin(elapsed * 3.0) * 0.5
	var current_modulate := Color.WHITE
	if one_shot_active and one_shot_transition_texture != null and one_shot_transition_duration > 0.0:
		var transition_progress: float = clamp(elapsed / one_shot_transition_duration, 0.0, 1.0)
		transition_progress = transition_progress * transition_progress * (3.0 - 2.0 * transition_progress)
		_draw_one_shot_transition_source(art_rect, 1.0 - transition_progress)
		current_modulate.a = transition_progress
	elif return_transition_texture != null and return_transition_duration > 0.0:
		var elapsed_in_return: float = elapsed - return_transition_start_elapsed
		if elapsed_in_return >= 0.0:
			var return_progress: float = clamp(elapsed_in_return / return_transition_duration, 0.0, 1.0)
			return_progress = return_progress * return_progress * (3.0 - 2.0 * return_progress)
			current_modulate.a = return_progress
	_draw_ellipse(
		Vector2(fitted_rect.get_center().x, _stage_floor_y() + size.y * 0.012),
		Vector2(max(fitted_rect.size.x * 0.34, size.x * 0.12), size.y * 0.040),
		Color(glow.r, glow.g, glow.b, 0.12 + pulse * 0.08),
		false,
		2.0
	)
	if deform_still:
		_draw_texture_region_deformed(fullframe_sheet_texture, source_rect, target_rect, current_modulate)
		if bool(character.get("live2d_motion_regions_enabled", false)):
			_draw_still_motion_regions(fullframe_sheet_texture, source_rect, target_rect, current_modulate)
		_draw_blink_overlay(source_rect, target_rect)
	elif bool(character.get("live2d_deform_fullframe_sheet", false)):
		_draw_texture_region_deformed(fullframe_sheet_texture, render_source_rect, target_rect, current_modulate)
	else:
		draw_texture_rect_region(fullframe_sheet_texture, fitted_rect, render_source_rect, current_modulate, false, true)
	_draw_return_transition_overlay(art_rect)


func _draw_return_transition_overlay(art_rect: Rect2) -> void:
	if return_transition_texture == null or return_transition_duration <= 0.0:
		return
	var elapsed_in_return: float = elapsed - return_transition_start_elapsed
	if elapsed_in_return < 0.0:
		return
	var progress: float = clamp(elapsed_in_return / return_transition_duration, 0.0, 1.0)
	progress = progress * progress * (3.0 - 2.0 * progress)
	var alpha: float = 1.0 - progress
	if alpha <= 0.002:
		return
	var texture_size: Vector2 = return_transition_texture.get_size()
	if texture_size.x <= 1.0 or texture_size.y <= 1.0:
		return
	var cols: int = max(1, return_transition_cols)
	var rows: int = max(1, return_transition_rows)
	var cell_size := Vector2(texture_size.x / float(cols), texture_size.y / float(rows))
	var idx: int = clamp(return_transition_final_frame_index, 0, cols * rows - 1)
	var col: int = idx % cols
	var row: int = int(floor(float(idx) / float(cols)))
	var source_rect := Rect2(Vector2(float(col) * cell_size.x, float(row) * cell_size.y), cell_size)
	var render_source_rect: Rect2 = source_rect
	if return_transition_trim_source and return_transition_trim_valid and return_transition_trim_relative_rect.size.x > 1.0 and return_transition_trim_relative_rect.size.y > 1.0:
		render_source_rect = Rect2(source_rect.position + return_transition_trim_relative_rect.position, return_transition_trim_relative_rect.size)
	var target_rect := art_rect
	if return_transition_float_motion_enabled:
		var bob_amount: float = float(character.get("live2d_float_bob", 5.0))
		var sway_amount: float = float(character.get("live2d_float_sway", 0.0))
		var scale_amount: float = float(character.get("live2d_float_scale", 0.010))
		var mouse_response: float = float(character.get("live2d_mouse_response", 0.16))
		var bob := sin(elapsed * 1.18) * bob_amount + sin(elapsed * 0.61 + 1.3) * bob_amount * 0.20
		var sway := sin(elapsed * 0.82 + 0.7) * sway_amount
		target_rect = _scale_rect(target_rect, 1.0 + sin(elapsed * 1.05) * scale_amount)
		target_rect.position += Vector2(look_offset.x * mouse_response + sway, look_offset.y * mouse_response * 0.65 + bob)
	if abs(return_transition_stage_scale - 1.0) > 0.001:
		target_rect = _scale_rect(target_rect, return_transition_stage_scale)
	target_rect.position += Vector2(size.x * return_transition_stage_offset_ratio.x, size.y * return_transition_stage_offset_ratio.y)
	if bool(character.get("live2d_align_bottom_to_cutline", false)):
		var aligned_rect := _live2d_stage_fit_rect(render_source_rect.size, target_rect)
		if aligned_rect.size.y > 1.0:
			target_rect.position.y += _character_bottom_cutline_y() - aligned_rect.end.y
	var fitted_rect := _live2d_stage_fit_rect(render_source_rect.size, target_rect)
	draw_texture_rect_region(return_transition_texture, fitted_rect, render_source_rect, Color(1.0, 1.0, 1.0, alpha), false, true)


func _draw_one_shot_transition_source(art_rect: Rect2, alpha: float) -> void:
	if one_shot_transition_texture == null or alpha <= 0.001:
		return
	var texture_size: Vector2 = one_shot_transition_texture.get_size()
	if texture_size.x <= 1.0 or texture_size.y <= 1.0:
		return
	var previous_elapsed: float = one_shot_transition_elapsed_offset + elapsed
	var previous_count: int = max(1, one_shot_transition_count)
	var frame_index := int(floor(previous_elapsed / max(0.01, one_shot_transition_interval))) % previous_count
	var col: int = frame_index % max(1, one_shot_transition_cols)
	var row: int = int(floor(float(frame_index) / float(max(1, one_shot_transition_cols))))
	var cell_size := Vector2(texture_size.x / float(max(1, one_shot_transition_cols)), texture_size.y / float(max(1, one_shot_transition_rows)))
	var source_rect := Rect2(Vector2(float(col) * cell_size.x, float(row) * cell_size.y), cell_size)
	var render_source_rect: Rect2 = source_rect
	if one_shot_transition_trim_source and one_shot_transition_trim_valid and one_shot_transition_trim_relative_rect.size.x > 1.0 and one_shot_transition_trim_relative_rect.size.y > 1.0:
		render_source_rect = Rect2(source_rect.position + one_shot_transition_trim_relative_rect.position, one_shot_transition_trim_relative_rect.size)
	var natural_still: bool = previous_count == 1 and not bool(character.get("live2d_deform_still", false))
	var bob_amount: float = float(character.get("live2d_float_bob", 2.0 if natural_still else 5.0))
	var sway_amount: float = float(character.get("live2d_float_sway", 0.8 if natural_still else 0.0))
	var scale_amount: float = float(character.get("live2d_float_scale", 0.005 if natural_still else 0.010))
	var mouse_response: float = float(character.get("live2d_mouse_response", 0.08 if natural_still else 0.16))
	var bob := sin(previous_elapsed * 1.18) * bob_amount + sin(previous_elapsed * 0.61 + 1.3) * bob_amount * 0.20
	var sway := sin(previous_elapsed * 0.82 + 0.7) * sway_amount
	var target_rect := _scale_rect(art_rect, 1.0 + sin(previous_elapsed * 1.05) * scale_amount)
	target_rect.position += Vector2(look_offset.x * mouse_response + sway, look_offset.y * mouse_response * 0.65 + bob)
	if bool(character.get("live2d_align_bottom_to_cutline", false)):
		var aligned_rect := _live2d_stage_fit_rect(render_source_rect.size, target_rect)
		if aligned_rect.size.y > 1.0:
			target_rect.position.y += _character_bottom_cutline_y() - aligned_rect.end.y
	var fitted_rect := _live2d_stage_fit_rect(render_source_rect.size, target_rect)
	draw_texture_rect_region(one_shot_transition_texture, fitted_rect, render_source_rect, Color(1.0, 1.0, 1.0, alpha), false, true)


func _draw_layered_preview(art_rect: Rect2) -> void:
	var breath := sin(elapsed * 2.1) * 5.0
	var blink := fmod(elapsed, 4.2) > 4.06
	var motion_strength: float = max(0.0, float(character.get("live2d_layer_motion_strength", 1.0)))
	for key in LAYER_ORDER:
		var key_name: String = str(key)
		var draw_key: String = key_name
		if key_name == "eyes_open" and blink and layer_textures.has("eyes_closed"):
			draw_key = "eyes_closed"
		var texture_value: Variant = layer_textures.get(draw_key, null)
		if not (texture_value is Texture2D):
			continue
		var texture: Texture2D = texture_value
		var parallax: float = _layer_parallax(draw_key)
		var canvas_locked := bool(character.get("live2d_canvas_locked", false))
		var layer_rect: Rect2 = art_rect if canvas_locked else _layer_target_rect(draw_key, art_rect)
		if canvas_locked and bool(character.get("live2d_canvas_offsets_enabled", true)):
			layer_rect.position += _canvas_locked_layer_offset(draw_key, art_rect)
		layer_rect.position += Vector2(
			look_offset.x * parallax * motion_strength,
			(look_offset.y + breath) * parallax * motion_strength
		)
		layer_rect = _scale_rect(layer_rect, 1.0 + sin(elapsed * 2.0) * 0.008 * max(0.2, parallax) * motion_strength)
		_draw_texture_fit(texture, layer_rect, Color.WHITE)


func _draw_card_parallax_preview(art_rect: Rect2) -> void:
	var accent := _accent_color()
	var glow := _glow_color()
	var bob := sin(elapsed * 2.0) * 5.0
	var base_rect := _scale_rect(_still_preview_rect(art_rect), 1.0 + sin(elapsed * 1.8) * 0.012)
	base_rect.position += Vector2(look_offset.x * 0.16, look_offset.y * 0.12 + bob)
	@warning_ignore("shadowed_variable_base_class")
	var draw_rect := _fit_region_rect(portrait_texture.get_size(), base_rect)
	_draw_texture_fit(portrait_texture, base_rect, Color(1.0, 1.0, 1.0, 0.96))

	var pulse := 0.5 + sin(elapsed * 3.2) * 0.5
	draw_rect(draw_rect.grow(3.0), Color(glow.r, glow.g, glow.b, 0.24 + pulse * 0.10), false, 2.0)
	draw_rect(draw_rect.grow(8.0), Color(accent.r, accent.g, accent.b, 0.10), false, 1.0)
	var glint_y := draw_rect.position.y + draw_rect.size.y * 0.32 + sin(elapsed * 5.0) * 2.0
	draw_line(
		Vector2(draw_rect.position.x + draw_rect.size.x * 0.34, glint_y),
		Vector2(draw_rect.position.x + draw_rect.size.x * 0.66, glint_y + 2.0),
		Color(1.0, 1.0, 1.0, 0.25 + pulse * 0.25),
		2.0
	)


func _still_preview_rect(art_rect: Rect2) -> Rect2:
	var width_ratio: float = float(character.get("live2d_still_preview_width_ratio", 0.66))
	var height_ratio: float = float(character.get("live2d_still_preview_height_ratio", 0.70))
	var still_w: float = min(art_rect.size.x * width_ratio, size.x * 0.58)
	var still_h: float = min(art_rect.size.y * height_ratio, size.y * 0.62)
	var bottom_y: float = min(_stage_floor_y() + size.y * 0.035, art_rect.end.y)
	var rect := Rect2(Vector2((size.x - still_w) * 0.5, bottom_y - still_h), Vector2(still_w, still_h))
	var min_top: float = size.y * 0.10
	if rect.position.y < min_top:
		rect.position.y = min_top
	return rect


func _draw_procedural_preview(art_rect: Rect2) -> void:
	var accent := _accent_color()
	var glow := _glow_color()
	var center := art_rect.get_center() + look_offset * 0.18
	var bob := sin(elapsed * 2.0) * 5.0
	var body_rect := Rect2(center + Vector2(-art_rect.size.x * 0.18, art_rect.size.y * 0.02 + bob), Vector2(art_rect.size.x * 0.36, art_rect.size.y * 0.34))
	draw_rect(body_rect, Color(accent.r * 0.35, accent.g * 0.35, accent.b * 0.35, 0.92))
	draw_rect(body_rect, Color(glow.r, glow.g, glow.b, 0.85), false, 2.0)
	var head_center := center + Vector2(look_offset.x * 0.45, -art_rect.size.y * 0.17 + bob * 0.5)
	draw_circle(head_center, art_rect.size.x * 0.135, Color(0.92, 0.88, 0.82, 1.0))
	draw_circle(head_center + Vector2(0.0, -2.0), art_rect.size.x * 0.15, Color(accent.r, accent.g, accent.b, 0.36))
	var arm_swing := sin(elapsed * 2.8) * art_rect.size.x * 0.04
	draw_line(body_rect.position + Vector2(0.0, body_rect.size.y * 0.2), body_rect.position + Vector2(-art_rect.size.x * 0.16, body_rect.size.y * 0.55 + arm_swing), Color(glow.r, glow.g, glow.b, 0.9), 7.0)
	draw_line(body_rect.position + Vector2(body_rect.size.x, body_rect.size.y * 0.2), body_rect.position + Vector2(body_rect.size.x + art_rect.size.x * 0.16, body_rect.size.y * 0.55 - arm_swing), Color(glow.r, glow.g, glow.b, 0.9), 7.0)
	draw_line(head_center + Vector2(-art_rect.size.x * 0.055, -3.0), head_center + Vector2(art_rect.size.x * 0.055, -2.0), Color(0.08, 0.12, 0.16, 0.85), 2.0)


func _draw_scanlines(glow: Color) -> void:
	var floor_y := _stage_floor_y()
	var y := size.y * 0.16 + fmod(elapsed * 18.0, 18.0)
	while y < floor_y - size.y * 0.10:
		var left_x := size.x * 0.23
		var right_x := size.x * 0.77
		draw_line(Vector2(left_x, y), Vector2(left_x + size.x * 0.08, y), Color(glow.r, glow.g, glow.b, 0.038), 1.0)
		draw_line(Vector2(right_x - size.x * 0.08, y), Vector2(right_x, y), Color(glow.r, glow.g, glow.b, 0.038), 1.0)
		y += 18.0


func _draw_nameplate(accent: Color, glow: Color) -> void:
	var label := str(character.get("class_name", character.get("name", "Live Preview")))
	var display_name := str(character.get("character_name", character.get("name", "")))
	var font := ThemeDB.fallback_font
	var role_size := 14
	var name_size := 28
	var y: float = min(size.y - 52.0, _stage_floor_y() + size.y * 0.115)
	var center_x: float = size.x * 0.5
	var line_w: float = min(size.x * 0.34, 250.0)
	_draw_ellipse(Vector2(center_x, y + 17.0), Vector2(line_w * 0.64, 12.0), Color(glow.r, glow.g, glow.b, 0.08), true)
	draw_line(Vector2(center_x - line_w * 0.5, y + 17.0), Vector2(center_x + line_w * 0.5, y + 17.0), Color(glow.r, glow.g, glow.b, 0.58), 1.4)
	draw_line(Vector2(center_x - line_w * 0.28, y + 24.0), Vector2(center_x + line_w * 0.28, y + 24.0), Color(1.0, 1.0, 1.0, 0.16), 1.0)
	_draw_centered_text(font, label, Vector2(center_x, y - 8.0), role_size, Color(accent.r, accent.g, accent.b, 0.94))
	_draw_centered_text(font, display_name, Vector2(center_x, y + 26.0), name_size, Color(1.0, 1.0, 1.0, 0.98))


func _draw_interaction_overlay(accent: Color, glow: Color) -> void:
	var hover := interaction_hover_amount
	var flash := interaction_click_flash
	if hover <= 0.01 and flash <= 0.01:
		return
	var pulse := 0.5 + sin(elapsed * 6.4) * 0.5
	var floor_y := _stage_floor_y()
	var center := Vector2(size.x * 0.5, floor_y)
	var base_radius := Vector2(min(size.x * 0.34, size.y * 0.38), size.y * 0.085)
	var glow_alpha: float = clamp(0.18 * hover + 0.34 * flash + pulse * 0.10 * hover, 0.0, 0.75)
	var line_alpha: float = clamp(0.38 * hover + 0.78 * flash + pulse * 0.14 * hover, 0.0, 1.0)
	_draw_ellipse(center, base_radius * (1.08 + hover * 0.08 + flash * 0.10), Color(glow.r, glow.g, glow.b, glow_alpha), false, 4.0 + flash * 2.0)
	_draw_ellipse(center, base_radius * (0.68 + flash * 0.06), Color(1.0, 1.0, 1.0, 0.18 * hover + 0.28 * flash), false, 1.2 + flash)
	for side in [-1.0, 1.0]:
		var x: float = size.x * (0.24 if side < 0.0 else 0.76)
		var y0: float = size.y * 0.20
		var y1: float = floor_y - size.y * 0.05
		var arm: float = size.x * (0.048 + hover * 0.020 + flash * 0.018)
		draw_line(Vector2(x, y0), Vector2(x + side * arm, y0), Color(accent.r, accent.g, accent.b, line_alpha), 2.0)
		draw_line(Vector2(x, y1), Vector2(x + side * arm, y1), Color(accent.r, accent.g, accent.b, line_alpha), 2.0)
		draw_line(Vector2(x, y0), Vector2(x, y0 + size.y * 0.052), Color(glow.r, glow.g, glow.b, line_alpha * 0.72), 1.4)
		draw_line(Vector2(x, y1), Vector2(x, y1 - size.y * 0.052), Color(glow.r, glow.g, glow.b, line_alpha * 0.72), 1.4)
	if flash > 0.01:
		_draw_click_scan_flash(Rect2(Vector2(size.x * 0.22, size.y * 0.16), Vector2(size.x * 0.56, floor_y - size.y * 0.16)), accent, flash)


func _draw_fullframe_loading_badge(accent: Color, glow: Color) -> void:
	if not fullframe_loading:
		return
	var font := ThemeDB.fallback_font
	var panel_w: float = clamp(size.x * 0.46, 230.0, 360.0)
	var panel_h: float = 54.0
	var panel := Rect2(Vector2((size.x - panel_w) * 0.5, size.y * 0.135), Vector2(panel_w, panel_h))
	var pulse := 0.5 + sin(elapsed * 5.0) * 0.5
	draw_rect(panel.grow(5.0), Color(glow.r, glow.g, glow.b, 0.10 + pulse * 0.05))
	draw_rect(panel, Color(0.018, 0.024, 0.036, 0.88))
	draw_rect(panel, Color(accent.r, accent.g, accent.b, 0.72), false, 1.4)
	_draw_centered_text(font, "\uc560\ub2c8\uba54\uc774\uc158 \uc900\ube44 \uc911", panel.get_center() + Vector2(0.0, -8.0), 15, Color(0.92, 0.96, 1.0, 0.96))
	var progress_rect := Rect2(panel.position + Vector2(18.0, panel.size.y - 15.0), Vector2(panel.size.x - 36.0, 4.0))
	draw_rect(progress_rect, Color(1.0, 1.0, 1.0, 0.12))
	var progress: float = clamp(fullframe_loading_progress, 0.0, 1.0)
	if progress <= 0.03:
		var sweep_w: float = max(34.0, progress_rect.size.x * 0.22)
		var sweep_x: float = progress_rect.position.x + fmod(elapsed * 86.0, progress_rect.size.x + sweep_w) - sweep_w
		draw_rect(Rect2(Vector2(sweep_x, progress_rect.position.y), Vector2(sweep_w, progress_rect.size.y)), Color(glow.r, glow.g, glow.b, 0.68))
	else:
		draw_rect(Rect2(progress_rect.position, Vector2(progress_rect.size.x * progress, progress_rect.size.y)), Color(glow.r, glow.g, glow.b, 0.80))


func _draw_interaction_corners(rect: Rect2, accent: Color, glow: Color, hover: float, flash: float) -> void:
	var length: float = 34.0 + 22.0 * hover + 18.0 * flash
	var inset: float = 12.0
	var width: float = 2.5 + 2.0 * hover + 2.0 * flash
	var color := Color(glow.r, glow.g, glow.b, clamp(0.54 * hover + 0.86 * flash, 0.0, 1.0))
	var highlight := Color(accent.r, accent.g, accent.b, clamp(0.68 * hover + 0.95 * flash, 0.0, 1.0))
	var p0 := rect.position + Vector2(inset, inset)
	var p1 := Vector2(rect.end.x - inset, rect.position.y + inset)
	var p2 := Vector2(rect.position.x + inset, rect.end.y - inset)
	var p3 := rect.end - Vector2(inset, inset)
	for corner in [p0, p1, p2, p3]:
		var sx: float = 1.0 if corner.x < rect.get_center().x else -1.0
		var sy: float = 1.0 if corner.y < rect.get_center().y else -1.0
		draw_line(corner, corner + Vector2(length * sx, 0.0), color, width)
		draw_line(corner, corner + Vector2(0.0, length * sy), color, width)
		draw_line(corner + Vector2(5.0 * sx, 5.0 * sy), corner + Vector2((length * 0.62) * sx, 5.0 * sy), highlight, max(1.0, width - 1.2))


func _draw_click_scan_flash(rect: Rect2, accent: Color, flash: float) -> void:
	var progress: float = 1.0 - flash
	var scan_y: float = lerp(rect.position.y + 18.0, rect.end.y - 18.0, progress)
	draw_line(
		Vector2(rect.position.x + 22.0, scan_y),
		Vector2(rect.end.x - 22.0, scan_y + 8.0),
		Color(1.0, 1.0, 1.0, 0.28 * flash),
		3.0
	)
	draw_line(
		Vector2(rect.position.x + 42.0, scan_y + 16.0),
		Vector2(rect.end.x - 42.0, scan_y + 24.0),
		Color(accent.r, accent.g, accent.b, 0.34 * flash),
		2.0
	)


func _layer_parallax(key: String) -> float:
	match key:
		"back_hair":
			return 0.20
		"body":
			return 0.04
		"arm_back":
			return 0.10
		"head":
			return 0.12
		"front_hair":
			return 0.28
		"eyes_open", "eyes_closed", "mouth", "glasses":
			return 0.16
		"arm_front", "racket":
			return 0.22
		"accessory", "effects":
			return 0.30
	return 0.22


func _layer_target_rect(key: String, art_rect: Rect2) -> Rect2:
	var center_ratio := Vector2(0.5, 0.5)
	var size_ratio := Vector2(0.42, 0.32)
	match key:
		"back_hair":
			center_ratio = Vector2(0.49, 0.34)
			size_ratio = Vector2(0.50, 0.36)
		"body":
			center_ratio = Vector2(0.50, 0.66)
			size_ratio = Vector2(0.66, 0.54)
		"arm_back":
			center_ratio = Vector2(0.37, 0.64)
			size_ratio = Vector2(0.50, 0.44)
		"head":
			center_ratio = Vector2(0.50, 0.37)
			size_ratio = Vector2(0.46, 0.38)
		"eyes_open", "eyes_closed":
			center_ratio = Vector2(0.50, 0.35)
			size_ratio = Vector2(0.26, 0.10)
		"mouth":
			center_ratio = Vector2(0.50, 0.43)
			size_ratio = Vector2(0.15, 0.075)
		"front_hair":
			center_ratio = Vector2(0.50, 0.29)
			size_ratio = Vector2(0.52, 0.34)
		"arm_front":
			center_ratio = Vector2(0.61, 0.64)
			size_ratio = Vector2(0.54, 0.48)
		"accessory":
			center_ratio = Vector2(0.70, 0.55)
			size_ratio = Vector2(0.30, 0.24)
	var draw_size := Vector2(art_rect.size.x * size_ratio.x, art_rect.size.y * size_ratio.y)
	var center := art_rect.position + Vector2(art_rect.size.x * center_ratio.x, art_rect.size.y * center_ratio.y)
	return Rect2(center - draw_size * 0.5, draw_size)


func _canvas_locked_layer_offset(key: String, art_rect: Rect2) -> Vector2:
	match key:
		"arm_front":
			return Vector2(art_rect.size.x * 0.10, art_rect.size.y * 0.13)
		"accessory":
			return Vector2(art_rect.size.x * 0.04, art_rect.size.y * 0.05)
	return Vector2.ZERO


func _accent_color() -> Color:
	var color_value: Variant = character.get("card_color", Color(0.0, 0.9, 1.0, 1.0))
	return color_value if color_value is Color else Color(0.0, 0.9, 1.0, 1.0)


func _glow_color() -> Color:
	var color_value: Variant = character.get("glow_color", _accent_color())
	return color_value if color_value is Color else _accent_color()


@warning_ignore("shadowed_variable_base_class")
func _draw_texture_cover(texture: Texture2D, target: Rect2, modulate: Color = Color.WHITE) -> void:
	var tex_size := texture.get_size()
	if tex_size.x <= 1.0 or tex_size.y <= 1.0 or target.size.x <= 1.0 or target.size.y <= 1.0:
		return
	var source := Rect2(Vector2.ZERO, tex_size)
	var target_aspect := target.size.x / target.size.y
	var tex_aspect := tex_size.x / tex_size.y
	if tex_aspect > target_aspect:
		source.size.x = tex_size.y * target_aspect
		source.position.x = (tex_size.x - source.size.x) * 0.5
	else:
		source.size.y = tex_size.x / target_aspect
		source.position.y = (tex_size.y - source.size.y) * 0.5
	draw_texture_rect_region(texture, target, source, modulate, false, true)


@warning_ignore("shadowed_variable_base_class")
func _draw_texture_fit(texture: Texture2D, target: Rect2, modulate: Color = Color.WHITE) -> void:
	var tex_size := texture.get_size()
	if tex_size.x <= 1.0 or tex_size.y <= 1.0:
		return
	var scale_factor: float = min(target.size.x / tex_size.x, target.size.y / tex_size.y)
	var draw_size := tex_size * scale_factor
	@warning_ignore("shadowed_variable_base_class")
	var draw_rect := Rect2(target.position + (target.size - draw_size) * 0.5, draw_size)
	draw_texture_rect(texture, draw_rect, false, modulate)


@warning_ignore("shadowed_variable_base_class")
func _draw_texture_region_fit(texture: Texture2D, source: Rect2, target: Rect2, modulate: Color = Color.WHITE) -> void:
	if source.size.x <= 1.0 or source.size.y <= 1.0:
		return
	@warning_ignore("shadowed_variable_base_class")
	var draw_rect := _fit_region_rect(source.size, target)
	draw_texture_rect_region(texture, draw_rect, source, modulate, false, true)


@warning_ignore("shadowed_variable_base_class")
func _draw_texture_region_deformed(texture: Texture2D, source: Rect2, target: Rect2, modulate: Color = Color.WHITE) -> void:
	if source.size.x <= 1.0 or source.size.y <= 1.0:
		return
	@warning_ignore("shadowed_variable_base_class")
	var draw_rect := _fit_region_rect(source.size, target)
	if draw_rect.size.x <= 1.0 or draw_rect.size.y <= 1.0:
		return
	var strip_count: int = clamp(int(character.get("live2d_deform_strips", 18)), 8, 32)
	var strength: float = max(0.0, float(character.get("live2d_motion_strength", 1.0)))
	for strip_index in range(strip_count):
		var t0: float = float(strip_index) / float(strip_count)
		var t1: float = float(strip_index + 1) / float(strip_count)
		var source_y0: float = source.position.y + source.size.y * t0
		var source_y1: float = source.position.y + source.size.y * t1
		var strip_source := Rect2(
			Vector2(source.position.x, source_y0),
			Vector2(source.size.x, source_y1 - source_y0)
		)
		var strip_target := Rect2(
			draw_rect.position + Vector2(0.0, draw_rect.size.y * t0),
			Vector2(draw_rect.size.x, draw_rect.size.y * (t1 - t0))
		)
		var top_weight: float = 1.0 - t0
		var chest_weight: float = max(0.0, 1.0 - abs(t0 - 0.56) * 3.0)
		var shoulder_weight: float = max(0.0, 1.0 - abs(t0 - 0.70) * 5.0)
		var sway: float = sin(elapsed * 1.35 + t0 * 4.4) * (1.0 + top_weight * 2.3) * strength
		var breath: float = sin(elapsed * 2.05) * (chest_weight * 1.4 + shoulder_weight * 0.5) * strength
		var vertical: float = sin(elapsed * 1.85 + t0 * 2.1) * (0.18 + top_weight * 0.48) * strength
		strip_target.position.x += sway + look_offset.x * (0.025 + top_weight * 0.055)
		strip_target.position.y += vertical + look_offset.y * (0.010 + top_weight * 0.026)
		strip_target.position.x -= abs(breath) * 0.5
		strip_target.size.x += abs(breath)
		var overlap: float = 1.0
		if strip_index > 0:
			strip_target.position.y -= overlap
			strip_target.size.y += overlap
		if strip_index < strip_count - 1:
			strip_target.size.y += overlap
		draw_texture_rect_region(texture, strip_target, strip_source, modulate, false, true)


@warning_ignore("shadowed_variable_base_class")
func _draw_still_motion_regions(texture: Texture2D, source: Rect2, target: Rect2, modulate: Color = Color.WHITE) -> void:
	var regions_value: Variant = character.get("live2d_motion_regions", [])
	if not (regions_value is Array):
		return
	var regions: Array = regions_value
	if regions.is_empty():
		return
	@warning_ignore("shadowed_variable_base_class")
	var draw_rect := _fit_region_rect(source.size, target)
	if draw_rect.size.x <= 1.0 or draw_rect.size.y <= 1.0:
		return
	var strength: float = max(0.0, float(character.get("live2d_motion_strength", 1.0)))
	var pixel_scale: float = draw_rect.size.x / source.size.x
	for region_value in regions:
		if not (region_value is Dictionary):
			continue
		var region: Dictionary = region_value
		var rect_value: Variant = region.get("source_rect", Rect2())
		if not (rect_value is Rect2):
			continue
		var normalized_rect: Rect2 = rect_value
		var source_region := _normalized_rect_to_source(source, normalized_rect)
		var target_region := _source_subrect_to_target_rect(source, draw_rect, source_region)
		if target_region.size.x <= 1.0 or target_region.size.y <= 1.0:
			continue
		var pivot_value: Variant = region.get("pivot", Vector2(0.5, 0.5))
		var pivot_ratio: Vector2 = pivot_value if pivot_value is Vector2 else Vector2(0.5, 0.5)
		var offset_value: Variant = region.get("offset", Vector2.ZERO)
		var offset_base: Vector2 = offset_value if offset_value is Vector2 else Vector2.ZERO
		var speed: float = float(region.get("speed", 1.0))
		var phase: float = float(region.get("phase", 0.0))
		var wave: float = sin(elapsed * speed + phase)
		var secondary_wave: float = sin(elapsed * speed * 0.73 + phase * 1.7)
		var motion_offset := Vector2(offset_base.x * wave, offset_base.y * secondary_wave) * pixel_scale * strength
		motion_offset += look_offset * (0.012 + abs(wave) * 0.010) * strength
		@warning_ignore("shadowed_variable_base_class")
		var rotation: float = float(region.get("rotation", 0.0)) * wave * strength
		var scale_offset_value: Variant = region.get("scale_offset", Vector2.ZERO)
		var scale_offset: Vector2 = scale_offset_value if scale_offset_value is Vector2 else Vector2.ZERO
		var motion_scale := Vector2(
			clamp(1.0 + scale_offset.x * wave * strength, 0.88, 1.16),
			clamp(1.0 + scale_offset.y * secondary_wave * strength, 0.88, 1.16)
		)
		_draw_texture_region_transformed(texture, source_region, target_region, pivot_ratio, motion_offset, rotation, modulate, motion_scale)


func _draw_blink_overlay(source: Rect2, target: Rect2) -> void:
	if not bool(character.get("live2d_blink_enabled", false)):
		return
	var blink_amount := _blink_amount()
	if blink_amount <= 0.01:
		return
	var eyes_value: Variant = character.get("live2d_blink_eyes", [])
	if not (eyes_value is Array):
		return
	@warning_ignore("shadowed_variable_base_class")
	var draw_rect := _fit_region_rect(source.size, target)
	for eye_value in eyes_value:
		if not (eye_value is Dictionary):
			continue
		var eye: Dictionary = eye_value
		var center_value: Variant = eye.get("center", Vector2.ZERO)
		var size_value: Variant = eye.get("size", Vector2(0.1, 0.03))
		var center_ratio: Vector2 = center_value if center_value is Vector2 else Vector2.ZERO
		var size_ratio: Vector2 = size_value if size_value is Vector2 else Vector2(0.1, 0.03)
		var center := draw_rect.position + Vector2(draw_rect.size.x * center_ratio.x, draw_rect.size.y * center_ratio.y)
		center += look_offset * 0.018
		var eye_size := Vector2(draw_rect.size.x * size_ratio.x, draw_rect.size.y * size_ratio.y)
		var angle: float = float(eye.get("angle", 0.0))
		_draw_closed_eye(center, eye_size, angle, blink_amount)


func _blink_amount() -> float:
	var interval: float = max(0.4, float(character.get("live2d_blink_interval", 3.4)))
	var duration: float = clamp(float(character.get("live2d_blink_duration", 0.22)), 0.08, interval * 0.45)
	var phase: float = fmod(elapsed + 1.15, interval)
	if phase > duration:
		return 0.0
	var t: float = clamp(phase / duration, 0.0, 1.0)
	return sin(t * PI)


func _draw_closed_eye(center: Vector2, eye_size: Vector2, angle: float, amount: float) -> void:
	var skin_color := Color(0.72, 0.47, 0.38, 0.64 * amount)
	var line_color := Color(0.035, 0.025, 0.030, 0.92 * amount)
	var crease_color := Color(0.0, 0.88, 1.0, 0.30 * amount)
	draw_set_transform(center, angle, Vector2.ONE)
	var half_w: float = eye_size.x * 0.50
	var cover_width: float = max(2.0, eye_size.y * 1.9 * amount)
	var line_width: float = max(1.2, eye_size.y * 0.52)
	draw_line(Vector2(-half_w, 0.0), Vector2(half_w, 0.0), skin_color, cover_width)
	draw_line(Vector2(-half_w * 0.92, 0.0), Vector2(half_w * 0.92, 0.0), line_color, line_width)
	draw_line(Vector2(-half_w * 0.68, eye_size.y * 0.38), Vector2(half_w * 0.68, eye_size.y * 0.36), crease_color, max(1.0, line_width * 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


@warning_ignore("shadowed_variable_base_class")
func _draw_texture_region_transformed(texture: Texture2D, source: Rect2, target: Rect2, pivot_ratio: Vector2, offset: Vector2, rotation: float, modulate: Color = Color.WHITE, scale: Vector2 = Vector2.ONE) -> void:
	var pivot := target.position + Vector2(target.size.x * pivot_ratio.x, target.size.y * pivot_ratio.y)
	draw_set_transform(pivot + offset, rotation, scale)
	draw_texture_rect_region(texture, Rect2(target.position - pivot, target.size), source, modulate, false, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _fullframe_render_source_rect(source_rect: Rect2) -> Rect2:
	if not bool(character.get("live2d_trim_transparent_source", true)):
		return source_rect
	if not fullframe_trim_valid:
		_apply_explicit_fullframe_trim_rect(character, "live2d_trim_rect")
	if not fullframe_trim_valid:
		_build_fullframe_trim_rect()
	if not fullframe_trim_valid or fullframe_trim_relative_rect.size.x <= 1.0 or fullframe_trim_relative_rect.size.y <= 1.0:
		return source_rect
	return Rect2(source_rect.position + fullframe_trim_relative_rect.position, fullframe_trim_relative_rect.size)


func _apply_explicit_fullframe_trim_rect(source: Dictionary, key: String) -> void:
	var rect_value: Variant = source.get(key, Rect2())
	var rect := Rect2()
	if rect_value is Rect2:
		rect = rect_value
	elif rect_value is Dictionary:
		var rect_dict: Dictionary = rect_value
		rect = Rect2(
			Vector2(float(rect_dict.get("x", 0.0)), float(rect_dict.get("y", 0.0))),
			Vector2(float(rect_dict.get("w", 0.0)), float(rect_dict.get("h", 0.0)))
		)
	elif rect_value is Array:
		var rect_array: Array = rect_value
		if rect_array.size() >= 4:
			rect = Rect2(
				Vector2(float(rect_array[0]), float(rect_array[1])),
				Vector2(float(rect_array[2]), float(rect_array[3]))
			)
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return
	fullframe_trim_relative_rect = rect
	fullframe_trim_valid = true


func _build_fullframe_trim_rect() -> void:
	fullframe_trim_valid = false
	fullframe_trim_relative_rect = Rect2()
	if fullframe_sheet_texture == null:
		return
	var image := fullframe_sheet_texture.get_image()
	if image == null or image.get_width() <= 1 or image.get_height() <= 1:
		return
	var texture_size := fullframe_sheet_texture.get_size()
	var cell_w: int = max(1, int(floor(texture_size.x / float(max(1, fullframe_cols)))))
	var cell_h: int = max(1, int(floor(texture_size.y / float(max(1, fullframe_rows)))))
	var min_x: int = cell_w
	var min_y: int = cell_h
	var max_x: int = 0
	var max_y: int = 0
	var found := false
	var sample_limit: int = clamp(int(character.get("live2d_trim_sample_frame_limit", 16)), 1, max(1, fullframe_count))
	var sample_indices: Array = []
	if sample_limit >= fullframe_count:
		for all_frame_index in range(fullframe_count):
			sample_indices.append(all_frame_index)
	else:
		for sample_index in range(sample_limit):
			var t: float = 0.0 if sample_limit <= 1 else float(sample_index) / float(sample_limit - 1)
			var sampled_frame_index := int(round(t * float(fullframe_count - 1)))
			if sample_indices.find(sampled_frame_index) < 0:
				sample_indices.append(sampled_frame_index)
	for frame_index_value in sample_indices:
		var sample_frame_index := int(frame_index_value)
		var col := sample_frame_index % fullframe_cols
		var row := int(floor(float(sample_frame_index) / float(fullframe_cols)))
		var origin := Vector2i(col * cell_w, row * cell_h)
		if origin.x >= image.get_width() or origin.y >= image.get_height():
			continue
		var region_size := Vector2i(min(cell_w, image.get_width() - origin.x), min(cell_h, image.get_height() - origin.y))
		if region_size.x <= 1 or region_size.y <= 1:
			continue
		var used := image.get_region(Rect2i(origin, region_size)).get_used_rect()
		if used.size.x <= 0 or used.size.y <= 0:
			continue
		var used_end := used.position + used.size
		min_x = min(min_x, used.position.x)
		min_y = min(min_y, used.position.y)
		max_x = max(max_x, used_end.x)
		max_y = max(max_y, used_end.y)
		found = true
	if not found:
		return
	var pad: int = int(max(6.0, float(min(cell_w, cell_h)) * float(character.get("live2d_trim_padding_ratio", 0.035))))
	var x0: int = int(clamp(min_x - pad, 0, max(0, cell_w - 1)))
	var y0: int = int(clamp(min_y - pad, 0, max(0, cell_h - 1)))
	var x1: int = int(clamp(max_x + pad, x0 + 1, cell_w))
	var y1: int = int(clamp(max_y + pad, y0 + 1, cell_h))
	fullframe_trim_relative_rect = Rect2(Vector2(float(x0), float(y0)), Vector2(float(x1 - x0), float(y1 - y0)))
	fullframe_trim_valid = true


func _normalized_rect_to_source(source: Rect2, normalized_rect: Rect2) -> Rect2:
	return Rect2(
		source.position + Vector2(source.size.x * normalized_rect.position.x, source.size.y * normalized_rect.position.y),
		Vector2(source.size.x * normalized_rect.size.x, source.size.y * normalized_rect.size.y)
	)


func _source_subrect_to_target_rect(source: Rect2, target: Rect2, source_region: Rect2) -> Rect2:
	var pos_ratio := Vector2(
		(source_region.position.x - source.position.x) / source.size.x,
		(source_region.position.y - source.position.y) / source.size.y
	)
	var size_ratio := Vector2(source_region.size.x / source.size.x, source_region.size.y / source.size.y)
	return Rect2(
		target.position + Vector2(target.size.x * pos_ratio.x, target.size.y * pos_ratio.y),
		Vector2(target.size.x * size_ratio.x, target.size.y * size_ratio.y)
	)


func _fit_region_rect(source_size: Vector2, target: Rect2) -> Rect2:
	if source_size.x <= 1.0 or source_size.y <= 1.0 or target.size.x <= 1.0 or target.size.y <= 1.0:
		return Rect2(target.position, Vector2.ZERO)
	var scale_factor: float = min(target.size.x / source_size.x, target.size.y / source_size.y)
	var draw_size := source_size * scale_factor
	return Rect2(target.position + (target.size - draw_size) * 0.5, draw_size)


func _live2d_stage_fit_rect(source_size: Vector2, target: Rect2) -> Rect2:
	var fit_rect := _fit_region_rect(source_size, target)
	var y_scale: float = max(0.50, float(character.get("live2d_stage_y_scale", 1.0)))
	if fit_rect.size.y <= 1.0 or abs(y_scale - 1.0) <= 0.001:
		return fit_rect
	var bottom_y: float = fit_rect.end.y
	fit_rect.size.y *= y_scale
	fit_rect.position.y = bottom_y - fit_rect.size.y
	return fit_rect


func _scale_rect(rect: Rect2, scale_factor: float) -> Rect2:
	var center := rect.get_center()
	var scaled_size := rect.size * scale_factor
	return Rect2(center - scaled_size * 0.5, scaled_size)


func _draw_centered_text(font: Font, text: String, center: Vector2, font_size: int, color: Color) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline := center + Vector2(-text_size.x * 0.5, text_size.y * 0.34)
	draw_string(font, baseline + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, color.a * 0.7))
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
