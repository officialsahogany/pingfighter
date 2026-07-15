extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const StainedGlassHost := preload("res://scripts/core/battle_loading_stained_glass_host.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const BattleLoadingTips := preload("res://scripts/core/battle_loading_tips.gd")
const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")

const LOADING_WAVE_SHEET_PATH := "res://assets/ui/loading/loading_energy_wave_loop64_autosprite_v1.png"
const LOADING_WAVE_ANCHOR_PATH := "res://assets/ui/loading/loading_energy_wave_anchor_imagegen_v1.png"
const STAGE1_STAINED_GLASS_FULLCOLOR_PATH := "res://assets/ui/loading/stage1_loading_cyber_stained_glass_fullcolor_imagegen_v4.png"
const STAGE1_STAINED_GLASS_REVEAL_MASK_PATH := "res://assets/ui/loading/stage1_loading_cyber_stained_glass_reveal_mask_v6.png"
const STAGE2_STAINED_GLASS_FULLCOLOR_PATH := "res://assets/ui/loading/stage2_loading_cyber_stained_glass_fullcolor_imagegen_v4.png"
const STAGE2_STAINED_GLASS_REVEAL_MASK_PATH := "res://assets/ui/loading/stage2_loading_cyber_stained_glass_reveal_mask_v4.png"
const STAGE3_STAINED_GLASS_FULLCOLOR_PATH := "res://assets/ui/loading/stage3_loading_cyber_stained_glass_fullcolor_imagegen_v1.png"
const STAGE3_STAINED_GLASS_REVEAL_MASK_PATH := "res://assets/ui/loading/stage3_loading_cyber_stained_glass_reveal_mask_v1.png"
const STAGE4_STAINED_GLASS_FULLCOLOR_PATH := "res://assets/ui/loading/stage4_loading_cyber_stained_glass_fullcolor_imagegen_v1.png"
const STAGE4_STAINED_GLASS_REVEAL_MASK_PATH := "res://assets/ui/loading/stage4_loading_cyber_stained_glass_reveal_mask_v1.png"
const STAGE5_STAINED_GLASS_FULLCOLOR_PATH := "res://assets/ui/loading/stage5_hongryun_loading_cyber_stained_glass_fullcolor_v1.png"
const STAGE5_STAINED_GLASS_REVEAL_MASK_PATH := "res://assets/ui/loading/stage5_hongryun_loading_cyber_stained_glass_reveal_mask_v1.png"
const STAGE6_STAINED_GLASS_FULLCOLOR_PATH := "res://assets/sprites/hud/stage6_tetriser_pillar_bg_imagegen_v1.png"
const STAGE6_STAINED_GLASS_REVEAL_MASK_PATH := "res://assets/ui/loading/stage5_hongryun_loading_cyber_stained_glass_reveal_mask_v1.png"
const STAINED_GLASS_HOST_NODE_NAME := "BattleLoadingStainedGlassHost"
const LOADING_WAVE_SHEET_COLS := 8
const LOADING_WAVE_SHEET_ROWS := 8
const LOADING_WAVE_FRAME_COUNT := 64
const LOADING_WAVE_FRAME_INTERVAL := 0.052
const MIN_STAINED_GLASS_REVEAL_SECONDS := 1.25
const FINAL_STAINED_GLASS_REVEAL_SECONDS := 0.36
const LOADING_FONT_PATHS := [
	"res://assets/fonts/NanumSquareB.ttf",
	"res://assets/fonts/PFStardust.ttf",
	"res://assets/fonts/NeoDunggeunmoPro.ttf",
]

var loading_font: Font = null
var loading_wave_sheet_texture: Texture2D = null
var loading_wave_anchor_texture: Texture2D = null
var stage1_stained_glass_texture: Texture2D = null
var stage1_stained_glass_mask_texture: Texture2D = null
var stage2_stained_glass_texture: Texture2D = null
var stage2_stained_glass_mask_texture: Texture2D = null
var stage3_stained_glass_texture: Texture2D = null
var stage3_stained_glass_mask_texture: Texture2D = null
var stage4_stained_glass_texture: Texture2D = null
var stage4_stained_glass_mask_texture: Texture2D = null
var stage5_stained_glass_texture: Texture2D = null
var stage5_stained_glass_mask_texture: Texture2D = null
var stage6_stained_glass_texture: Texture2D = null
var stage6_stained_glass_mask_texture: Texture2D = null
var stained_glass_host: Control = null
var _visible_started_msec: int = -1
var _completion_reveal_started_msec: int = -1


func build_snapshot(owner: Object, module_getter: Callable, context: Dictionary = {}) -> Dictionary:
	var battle_initialized := bool(context.get("battle_initialized", false))
	var stage_landing_intro_started := bool(context.get("stage_landing_intro_started", false))
	var warmup_finished := _is_warmup_finished(module_getter)
	var progress := _resolve_progress(module_getter, warmup_finished, battle_initialized, stage_landing_intro_started)
	if context.has("loading_progress"):
		progress = clampf(float(context.get("loading_progress", progress)), 0.0, 1.0)
	return {
		"title": LanguageSettings.translate_text(str(context.get("loading_title", "스테이지 진입 준비 중"))),
		"subtitle": LanguageSettings.translate_text(str(context.get("loading_subtitle", _build_subtitle(owner)))),
		"status": LanguageSettings.translate_text(str(context.get(
			"loading_status",
			_resolve_status_text(module_getter, warmup_finished, battle_initialized, stage_landing_intro_started)
		))),
		"progress": progress,
		"tip_tier": _resolve_tip_tier(owner),
		"tip_character": _resolve_tip_character(owner),
	}


func draw(
	canvas: CanvasItem,
	owner: Object,
	module_getter: Callable,
	view_size: Vector2,
	context: Dictionary = {}
) -> void:
	if canvas == null:
		return
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		view_size = Vector2(1280.0, 720.0)
	var snapshot := build_snapshot(owner, module_getter, context)
	var display_progress: float = clampf(float(snapshot.get("progress", 0.0)), 0.0, 1.0)
	if _can_show_stained_glass(owner):
		display_progress = _get_stained_glass_display_progress(display_progress)
	else:
		_release_stained_glass_host(owner)
	if _show_stained_glass_host(owner, view_size, snapshot, display_progress):
		return
	var font := _get_loading_font()
	var center := view_size * 0.5
	var tick_seconds := Time.get_ticks_msec() / 1000.0
	var pulse := 0.5 + sin(tick_seconds * 4.0) * 0.5
	var accent := Color(0.0, 0.82, 1.0, 1.0)
	var gold := Color(1.0, 0.72, 0.26, 1.0)

	_draw_background(canvas, view_size, tick_seconds)
	_draw_loading_energy_wave_layer(canvas, view_size, center, pulse)
	_draw_center_glow(canvas, center, pulse, accent, gold)

	var title_center := center + Vector2(0.0, -64.0)
	_draw_centered_text(canvas, font, str(snapshot.get("title", "")), title_center, 28, Color.WHITE)
	_draw_centered_text(canvas, font, str(snapshot.get("subtitle", "")), center + Vector2(0.0, -28.0), 15, Color(0.92, 0.78, 0.46, 0.92))
	# Rotating gameplay tip in place of the old mechanical boot-status line.
	var tip_tier := str(snapshot.get("tip_tier", BattleLoadingTips.TIER_ADVANCED))
	var tip_character := str(snapshot.get("tip_character", ""))
	var tip_text := BattleLoadingTips.rotation_tip_for_elapsed(tip_tier, tip_character, 0, tick_seconds)
	_draw_centered_text(canvas, font, tip_text, center + Vector2(0.0, 16.0), 17, Color(0.76, 0.88, 0.96, 0.96))
	_draw_progress(canvas, font, center, view_size, display_progress, accent, gold)
	_draw_centered_text(canvas, font, LanguageSettings.translate_text("잠시만 기다려 주세요"), center + Vector2(0.0, 122.0), 13, Color(0.64, 0.74, 0.82, 0.72))


func prewarm_assets() -> void:
	_get_loading_font()
	_load_loading_wave_textures()
	_load_stained_glass_textures(1)
	_load_stained_glass_textures(2)
	_load_stained_glass_textures(3)
	_load_stained_glass_textures(4)
	_load_stained_glass_textures(5)
	_load_stained_glass_textures(6)


func prewarm_stage_assets(stage: int) -> void:
	_get_loading_font()
	_load_loading_wave_textures()
	_load_stained_glass_textures(stage)


func should_hold_completion(owner: Object, module_getter: Callable) -> bool:
	if not _can_show_stained_glass(owner):
		_release_stained_glass_host(owner)
		return false
	_mark_visible_started()
	if not _is_warmup_finished(module_getter):
		return false
	if _elapsed_visible_seconds() < MIN_STAINED_GLASS_REVEAL_SECONDS:
		return true
	_mark_completion_reveal_started()
	return _elapsed_completion_reveal_seconds() < FINAL_STAINED_GLASS_REVEAL_SECONDS


func hide_loading() -> void:
	if stained_glass_host != null and is_instance_valid(stained_glass_host) and stained_glass_host.has_method("hide_loading"):
		stained_glass_host.call("hide_loading")
	_release_stained_glass_host()
	_visible_started_msec = -1
	_completion_reveal_started_msec = -1


func release_stained_glass_hosts(owner: Object = null) -> void:
	_release_stained_glass_host(owner)


func _draw_background(canvas: CanvasItem, view_size: Vector2, tick_seconds: float) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.008, 0.010, 0.018, 1.0))
	var top_rect := Rect2(Vector2.ZERO, Vector2(view_size.x, view_size.y * 0.42))
	canvas.draw_rect(top_rect, Color(0.018, 0.042, 0.060, 0.74))
	var grid_step: float = max(34.0, view_size.x / 34.0)
	var x_offset: float = fmod(tick_seconds * 18.0, grid_step)
	var x: float = -view_size.y * 0.18 + x_offset
	while x < view_size.x + grid_step:
		canvas.draw_line(Vector2(x, 0.0), Vector2(x + view_size.y * 0.18, view_size.y), Color(0.0, 0.74, 1.0, 0.045), 1.0)
		x += grid_step
	var y_offset: float = fmod(tick_seconds * 12.0, grid_step)
	var y: float = y_offset
	while y < view_size.y:
		canvas.draw_line(Vector2(0.0, y), Vector2(view_size.x, y), Color(1.0, 0.72, 0.26, 0.030), 1.0)
		y += grid_step


func _draw_center_glow(canvas: CanvasItem, center: Vector2, pulse: float, accent: Color, gold: Color) -> void:
	var base_radius := 156.0 + pulse * 18.0
	canvas.draw_circle(center + Vector2(0.0, -16.0), base_radius, Color(accent.r, accent.g, accent.b, 0.050), true)
	canvas.draw_circle(center + Vector2(0.0, -16.0), base_radius * 0.62, Color(gold.r, gold.g, gold.b, 0.040), true)
	canvas.draw_circle(center + Vector2(0.0, -16.0), base_radius * 0.82, Color(accent.r, accent.g, accent.b, 0.22), false, 2.0, true)


func _draw_progress(canvas: CanvasItem, font: Font, center: Vector2, view_size: Vector2, progress: float, accent: Color, gold: Color) -> void:
	var progress_w: float = clamp(view_size.x * 0.42, 340.0, 640.0)
	var progress_rect := Rect2(Vector2(center.x - progress_w * 0.5, center.y + 54.0), Vector2(progress_w, 10.0))
	canvas.draw_rect(progress_rect, Color(1.0, 1.0, 1.0, 0.12))
	canvas.draw_rect(progress_rect, Color(0.0, 0.0, 0.0, 0.44), false, 1.0)
	canvas.draw_rect(Rect2(progress_rect.position, Vector2(progress_rect.size.x * progress, progress_rect.size.y)), Color(accent.r, accent.g, accent.b, 0.92))
	canvas.draw_line(progress_rect.position + Vector2(0.0, -8.0), progress_rect.position + Vector2(progress_rect.size.x, -8.0), Color(gold.r, gold.g, gold.b, 0.20), 1.0)
	var percent_text := "%d%%" % int(round(progress * 100.0))
	_draw_centered_text(canvas, font, percent_text, Vector2(progress_rect.get_center().x, progress_rect.end.y + 28.0), 18, Color(0.88, 0.94, 1.0, 0.94))


func _draw_loading_energy_wave_layer(canvas: CanvasItem, view_size: Vector2, center: Vector2, pulse: float) -> void:
	_load_loading_wave_textures()
	var texture := loading_wave_sheet_texture
	var source := Rect2()
	if texture != null:
		var texture_size := texture.get_size()
		if texture_size.x <= 1.0 or texture_size.y <= 1.0:
			return
		var cell_size := Vector2(texture_size.x / float(LOADING_WAVE_SHEET_COLS), texture_size.y / float(LOADING_WAVE_SHEET_ROWS))
		var frame_index := int(floor(Time.get_ticks_msec() / 1000.0 / LOADING_WAVE_FRAME_INTERVAL)) % LOADING_WAVE_FRAME_COUNT
		var col := frame_index % LOADING_WAVE_SHEET_COLS
		var row := int(floor(float(frame_index) / float(LOADING_WAVE_SHEET_COLS)))
		source = Rect2(Vector2(float(col) * cell_size.x, float(row) * cell_size.y), cell_size)
	else:
		texture = loading_wave_anchor_texture
		if texture == null:
			return
		source = Rect2(Vector2.ZERO, texture.get_size())
	var wave_width: float = max(view_size.x * 1.12, 640.0)
	var wave_height: float = clamp(view_size.y * 0.30, 190.0, 340.0)
	var wave_center := Vector2(center.x, center.y - 14.0 + sin(Time.get_ticks_msec() * 0.0018) * 7.0)
	var wave_rect := Rect2(wave_center - Vector2(wave_width, wave_height) * 0.5, Vector2(wave_width, wave_height))
	canvas.draw_texture_rect_region(texture, wave_rect.grow(20.0), source, Color(0.0, 0.72, 1.0, 0.10 + pulse * 0.035), false, true)
	canvas.draw_texture_rect_region(texture, wave_rect, source, Color(1.0, 1.0, 1.0, 0.26 + pulse * 0.08), false, true)


func _resolve_progress(
	module_getter: Callable,
	warmup_finished: bool,
	battle_initialized: bool,
	stage_landing_intro_started: bool
) -> float:
	if not warmup_finished:
		return clampf(_get_warmup_progress(module_getter), 0.02, 0.92)
	if not battle_initialized:
		return 0.94
	if not stage_landing_intro_started:
		return 0.97
	return 1.0


func _show_stained_glass_host(owner: Object, view_size: Vector2, snapshot: Dictionary, display_progress: float) -> bool:
	if not _can_show_stained_glass(owner):
		_release_stained_glass_host(owner)
		return false
	var stage: int = maxi(1, int(_safe_owner_get(owner, "current_stage", 1)))
	if not _load_stained_glass_textures(stage):
		_release_stained_glass_host(owner)
		return false
	var host := _ensure_stained_glass_host(owner)
	if host == null:
		return false
	_mark_visible_started()
	host.set("reveal_softness", _get_stage_reveal_softness(stage))
	host.call("configure", _get_stained_glass_texture(stage), _get_stained_glass_mask_texture(stage), _get_loading_font())
	host.call("show_loading", snapshot, display_progress, view_size)
	return true


func _get_stage_reveal_softness(stage: int) -> float:
	match stage:
		1, 3, 4, 5, 6:
			return 0.065
	return 0.055


func _ensure_stained_glass_host(owner: Object) -> Control:
	if stained_glass_host != null and is_instance_valid(stained_glass_host):
		return stained_glass_host
	if not (owner is Node):
		return null
	stained_glass_host = StainedGlassHost.new()
	stained_glass_host.name = STAINED_GLASS_HOST_NODE_NAME
	stained_glass_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stained_glass_host.z_index = 3000
	stained_glass_host.top_level = true
	(owner as Node).add_child(stained_glass_host)
	return stained_glass_host


func _release_stained_glass_host(owner: Object = null) -> void:
	var released := {}
	if stained_glass_host != null and is_instance_valid(stained_glass_host):
		_release_stained_glass_host_node(stained_glass_host, released)
	stained_glass_host = null
	if owner is Node:
		_release_named_stained_glass_hosts(owner as Node, released)


func _release_named_stained_glass_hosts(root: Node, released: Dictionary) -> void:
	if root.name == STAINED_GLASS_HOST_NODE_NAME:
		_release_stained_glass_host_node(root, released)
		return
	for child in root.get_children():
		if child is Node:
			_release_named_stained_glass_hosts(child as Node, released)


func _release_stained_glass_host_node(host: Node, released: Dictionary) -> void:
	if host == null or not is_instance_valid(host):
		return
	var instance_id := host.get_instance_id()
	if released.has(instance_id):
		return
	released[instance_id] = true
	if host.has_method("hide_loading"):
		host.call("hide_loading")
	if host is CanvasItem:
		(host as CanvasItem).visible = false
	host.set_process(false)
	host.set_physics_process(false)
	var parent := host.get_parent()
	if parent != null:
		parent.remove_child(host)
	host.queue_free()


func _load_stained_glass_textures(stage: int) -> bool:
	match stage:
		1:
			if stage1_stained_glass_texture == null:
				stage1_stained_glass_texture = ProjectResourceLoader.load_texture(STAGE1_STAINED_GLASS_FULLCOLOR_PATH)
			if stage1_stained_glass_mask_texture == null:
				stage1_stained_glass_mask_texture = ProjectResourceLoader.load_texture(STAGE1_STAINED_GLASS_REVEAL_MASK_PATH)
		2:
			if stage2_stained_glass_texture == null:
				stage2_stained_glass_texture = ProjectResourceLoader.load_texture(STAGE2_STAINED_GLASS_FULLCOLOR_PATH)
			if stage2_stained_glass_mask_texture == null:
				stage2_stained_glass_mask_texture = ProjectResourceLoader.load_texture(STAGE2_STAINED_GLASS_REVEAL_MASK_PATH)
		3:
			if stage3_stained_glass_texture == null:
				stage3_stained_glass_texture = ProjectResourceLoader.load_texture(STAGE3_STAINED_GLASS_FULLCOLOR_PATH)
			if stage3_stained_glass_mask_texture == null:
				stage3_stained_glass_mask_texture = ProjectResourceLoader.load_texture(STAGE3_STAINED_GLASS_REVEAL_MASK_PATH)
		4:
			if stage4_stained_glass_texture == null:
				stage4_stained_glass_texture = ProjectResourceLoader.load_texture(STAGE4_STAINED_GLASS_FULLCOLOR_PATH)
			if stage4_stained_glass_mask_texture == null:
				stage4_stained_glass_mask_texture = ProjectResourceLoader.load_texture(STAGE4_STAINED_GLASS_REVEAL_MASK_PATH)
		5:
			if stage5_stained_glass_texture == null:
				stage5_stained_glass_texture = ProjectResourceLoader.load_texture(STAGE5_STAINED_GLASS_FULLCOLOR_PATH)
			if stage5_stained_glass_mask_texture == null:
				stage5_stained_glass_mask_texture = ProjectResourceLoader.load_texture(STAGE5_STAINED_GLASS_REVEAL_MASK_PATH)
		6:
			if stage6_stained_glass_texture == null:
				stage6_stained_glass_texture = ProjectResourceLoader.load_texture(STAGE6_STAINED_GLASS_FULLCOLOR_PATH)
			if stage6_stained_glass_mask_texture == null:
				stage6_stained_glass_mask_texture = ProjectResourceLoader.load_texture(STAGE6_STAINED_GLASS_REVEAL_MASK_PATH)
		_:
			return false
	return _get_stained_glass_texture(stage) != null and _get_stained_glass_mask_texture(stage) != null


func _get_stained_glass_texture(stage: int) -> Texture2D:
	match stage:
		1:
			return stage1_stained_glass_texture
		2:
			return stage2_stained_glass_texture
		3:
			return stage3_stained_glass_texture
		4:
			return stage4_stained_glass_texture
		5:
			return stage5_stained_glass_texture
		6:
			return stage6_stained_glass_texture
	return null


func _get_stained_glass_mask_texture(stage: int) -> Texture2D:
	match stage:
		1:
			return stage1_stained_glass_mask_texture
		2:
			return stage2_stained_glass_mask_texture
		3:
			return stage3_stained_glass_mask_texture
		4:
			return stage4_stained_glass_mask_texture
		5:
			return stage5_stained_glass_mask_texture
		6:
			return stage6_stained_glass_mask_texture
	return null


func _can_show_stained_glass(owner: Object) -> bool:
	# Stage 7 is intentionally absent: the Akamu prebattle intro video owns the
	# loading spectacle, and the stained-glass completion hold would deadlock the
	# video handoff (sealed by stage7_akamu_prebattle_live_frame_smoke).
	return [1, 2, 3, 4, 5, 6].has(maxi(1, int(_safe_owner_get(owner, "current_stage", 1))))


func _get_stained_glass_display_progress(raw_progress: float) -> float:
	_mark_visible_started()
	var progress: float = clampf(raw_progress, 0.0, 1.0)
	if _completion_reveal_started_msec >= 0:
		var final_t: float = clampf(_elapsed_completion_reveal_seconds() / FINAL_STAINED_GLASS_REVEAL_SECONDS, 0.0, 1.0)
		var eased := final_t * final_t * (3.0 - 2.0 * final_t)
		return lerpf(0.92, 1.0, eased)
	if progress >= 0.94 and _elapsed_visible_seconds() < MIN_STAINED_GLASS_REVEAL_SECONDS:
		return min(0.92, progress)
	return progress


func _mark_visible_started() -> void:
	if _visible_started_msec < 0:
		_visible_started_msec = Time.get_ticks_msec()


func _mark_completion_reveal_started() -> void:
	if _completion_reveal_started_msec < 0:
		_completion_reveal_started_msec = Time.get_ticks_msec()


func _elapsed_visible_seconds() -> float:
	if _visible_started_msec < 0:
		return 0.0
	return max(0.0, float(Time.get_ticks_msec() - _visible_started_msec) / 1000.0)


func _elapsed_completion_reveal_seconds() -> float:
	if _completion_reveal_started_msec < 0:
		return 0.0
	return max(0.0, float(Time.get_ticks_msec() - _completion_reveal_started_msec) / 1000.0)


func _resolve_status_text(
	module_getter: Callable,
	warmup_finished: bool,
	battle_initialized: bool,
	stage_landing_intro_started: bool
) -> String:
	if not warmup_finished:
		var warmup: Object = _get_module(module_getter, "battle_boot_warmup_controller")
		if warmup != null and warmup.has_method("get_status_text"):
			return LanguageSettings.translate_text(str(warmup.get_status_text()))
		return LanguageSettings.translate_text("전투 데이터 준비 중")
	if not battle_initialized:
		return LanguageSettings.translate_text("전투 상태 초기화 중")
	if not stage_landing_intro_started:
		return LanguageSettings.translate_text("스테이지 입장 연출 준비 중")
	return LanguageSettings.translate_text("준비 완료")


func _get_warmup_progress(module_getter: Callable) -> float:
	var warmup: Object = _get_module(module_getter, "battle_boot_warmup_controller")
	if warmup != null and warmup.has_method("get_progress"):
		return float(warmup.get_progress(module_getter))
	if _is_warmup_finished(module_getter):
		return 1.0
	return 0.12


func _is_warmup_finished(module_getter: Callable) -> bool:
	var warmup: Object = _get_module(module_getter, "battle_boot_warmup_controller")
	if warmup != null and warmup.has_method("is_finished"):
		return bool(warmup.is_finished())
	var readiness: Object = _get_module(module_getter, "battle_scene_readiness_controller")
	if readiness != null and readiness.has_method("is_boot_warmup_finished"):
		return bool(readiness.is_boot_warmup_finished(module_getter))
	return true


func _resolve_tip_tier(owner: Object) -> String:
	# 테스트(junior) league shows the must-know basics; every other league
	# rotates the deeper-system tips.
	return BattleLoadingTips.tier_for_league(
		BattleSceneConfig.normalize_league_mode(str(_safe_owner_get(owner, "ai_mode", "champion")))
	)


func _resolve_tip_character(owner: Object) -> String:
	return BattleLoadingTips.normalize_character_type(
		str(_safe_owner_get(owner, "selected_character_type", "smasher"))
	)


func _build_subtitle(owner: Object) -> String:
	var stage: int = maxi(1, int(_safe_owner_get(owner, "current_stage", 1)))
	var character_name := str(_safe_owner_get(owner, "selected_character_name", ""))
	if character_name.strip_edges() == "":
		character_name = _character_name_from_runtime(str(_safe_owner_get(owner, "selected_character_type", "smasher")))
	return LanguageSettings.format_stage_character_label(stage, character_name)


func _character_name_from_runtime(character_type: String) -> String:
	match character_type.strip_edges().to_lower():
		"viper":
			return LanguageSettings.translate_text("바이퍼")
		"soldier", "commando":
			return LanguageSettings.translate_text("코만도")
		"blacksmith", "baltor":
			return LanguageSettings.translate_text("발토르")
		"optimus":
			return LanguageSettings.translate_text("옵티머스")
	return LanguageSettings.translate_text("스매셔")


func _safe_owner_get(owner: Object, key: String, fallback: Variant) -> Variant:
	if owner == null:
		return fallback
	var value: Variant = owner.get(key)
	return fallback if value == null else value


func _get_loading_font() -> Font:
	if loading_font != null:
		return loading_font
	for path_value in LOADING_FONT_PATHS:
		var path: String = str(path_value)
		var font := ProjectResourceLoader.load_font(path)
		if font != null:
			loading_font = font
			return loading_font
	loading_font = ThemeDB.fallback_font
	return loading_font


func _load_loading_wave_textures() -> void:
	if loading_wave_sheet_texture == null:
		loading_wave_sheet_texture = ProjectResourceLoader.load_texture(LOADING_WAVE_SHEET_PATH)
	if loading_wave_anchor_texture == null:
		loading_wave_anchor_texture = ProjectResourceLoader.load_texture(LOADING_WAVE_ANCHOR_PATH)


func _draw_centered_text(canvas: CanvasItem, font: Font, text: String, center: Vector2, font_size: int, color: Color) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline := center + Vector2(-text_size.x * 0.5, text_size.y * 0.34)
	canvas.draw_string(font, baseline + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, color.a * 0.70))
	canvas.draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, clampi(int(round(float(font_size) * 0.24)), 3, 8), Color(0.0, 0.0, 0.0, color.a * 0.85))
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _get_module(module_getter: Callable, key: String) -> Object:
	if not module_getter.is_valid():
		return null
	var value: Variant = module_getter.call(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null
