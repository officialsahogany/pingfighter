extends Control

const PenguinLogoIntro := preload("res://scripts/core/penguin_logo_intro.gd")
const BattleViewLayout := preload("res://scripts/core/battle_view_layout.gd")
const CharacterSelectPrewarm := preload("res://scripts/ui/character_select_prewarm.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const BgmMuteState := preload("res://scripts/audio/bgm_mute_state.gd")
const GamepadInput := preload("res://scripts/core/gamepad_input.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")

const LOADING_PERCENT_RATE := 72.0
const LOADING_FINISH_PERCENT_RATE := 96.0
const MAIN_MENU_BGM_PATH := "res://assets/bgm/main_menu_moon_crack.wav"
const MAIN_MENU_BGM_GAIN := 0.82
const MAIN_MENU_BGM_PLAYER_NAME := "PreloadedMenuBgmPlayer"
const MAIN_MENU_BGM_BUS_NAME := "BGM"
const MAIN_MENU_BGM_DEFAULT_BUS_VOLUME := 0.4
const BGM_TOGGLE_KEY := KEY_B
const BGM_PRELOAD_LEAD_SECONDS := 5.0
const BGM_PRELOAD_MIN_PROGRESS := 0.05
const LOADING_WAVE_SHEET_PATH := "res://assets/ui/loading/loading_energy_wave_loop64_autosprite_v1.png"
const LOADING_WAVE_ANCHOR_PATH := "res://assets/ui/loading/loading_energy_wave_anchor_imagegen_v1.png"
const LOADING_WAVE_SHEET_COLS := 8
const LOADING_WAVE_SHEET_ROWS := 8
const LOADING_WAVE_FRAME_COUNT := 64
const LOADING_WAVE_FRAME_INTERVAL := 0.052
const LOADING_FONT_PATHS := [
	"res://assets/fonts/NanumSquareB.ttf",
	"res://assets/fonts/PFStardust.ttf",
	"res://assets/fonts/NeoDunggeunmoPro.ttf",
]

@export var character_select_scene_path: String = "res://scenes/character_select.tscn"
@export var post_intro_scene_path: String = "res://scenes/main_menu.tscn"
@export var starting_stage: int = 1

var logo_intro: Object = PenguinLogoIntro.new()
var view_layout: Object = BattleViewLayout.new()
var character_select_prewarm: Object = CharacterSelectPrewarm.new()
var transitioning: bool = false
var loading_character_select: bool = false
var loading_display_percent: int = 0
var loading_percent_accumulator: float = 0.0
var loading_target_progress: float = 0.0
var loading_elapsed: float = 0.0
var bgm_preload_started: bool = false
var loading_status_text: String = ""
var loading_font: Font = null
var loading_wave_sheet_texture: Texture2D = null
var loading_wave_anchor_texture: Texture2D = null
var main_menu_bgm_muted: bool = false


func _ready() -> void:
	PerkConversionFlags.set_enabled(true)  # 패시브->퍽 전환 시스템 런타임 활성화 (앱 부팅 진입점)
	LanguageSettings.apply_saved_language()
	_configure_app_window()
	_restore_main_menu_bgm_muted()
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	_prepare_selection_state()
	if logo_intro != null and logo_intro.has_method("prewarm_assets"):
		logo_intro.prewarm_assets()
	if logo_intro != null and logo_intro.has_method("begin") and bool(logo_intro.begin(self)):
		queue_redraw()
		return
	_begin_character_select_loading()


func _exit_tree() -> void:
	if logo_intro != null and logo_intro.has_method("cleanup"):
		logo_intro.cleanup()


func _process(delta: float) -> void:
	if transitioning:
		return
	if loading_character_select:
		loading_elapsed += max(delta, 0.0)
		var loading_finished := true
		if character_select_prewarm != null and character_select_prewarm.has_method("update"):
			loading_finished = bool(character_select_prewarm.update())
		_refresh_loading_snapshot(loading_finished)
		_update_loading_display(delta, loading_finished)
		_consider_main_menu_bgm_preload(loading_finished)
		queue_redraw()
		if loading_finished and loading_display_percent >= 100:
			_go_to_character_select()
		return
	if logo_intro != null and logo_intro.has_method("is_active") and bool(logo_intro.is_active()):
		if logo_intro.has_method("update"):
			logo_intro.update(delta)
		queue_redraw()
		if logo_intro.has_method("is_active") and bool(logo_intro.is_active()):
			return
	_begin_character_select_loading()


func _gui_input(event: InputEvent) -> void:
	if _handle_fullscreen_toggle(event):
		accept_event()
		return
	if _handle_bgm_toggle(event):
		accept_event()
		return
	if transitioning:
		return
	if loading_character_select:
		accept_event()
		return
	if event is InputEventMouseButton and event.pressed:
		_begin_character_select_loading()
		accept_event()
	elif GamepadInput.is_intro_skip_event(event):
		_begin_character_select_loading()
		accept_event()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE:
				_begin_character_select_loading()
				accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if _handle_fullscreen_toggle(event):
		return
	if _handle_bgm_toggle(event):
		return
	if transitioning:
		return
	if loading_character_select:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed:
		_begin_character_select_loading()
		get_viewport().set_input_as_handled()
	elif GamepadInput.is_intro_skip_event(event):
		_begin_character_select_loading()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE:
				_begin_character_select_loading()
				get_viewport().set_input_as_handled()


func _handle_fullscreen_toggle(event: InputEvent) -> bool:
	if not _is_key_pressed(event, KEY_F11):
		return false
	if view_layout == null or not view_layout.has_method("toggle_fullscreen"):
		return false
	var window: Window = get_window()
	if window == null:
		return false
	view_layout.toggle_fullscreen(window)
	queue_redraw()
	get_viewport().set_input_as_handled()
	return true


func _handle_bgm_toggle(event: InputEvent) -> bool:
	if not _is_key_pressed(event, BGM_TOGGLE_KEY):
		return false
	_toggle_main_menu_bgm()
	var viewport: Viewport = get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
	return true


func _toggle_main_menu_bgm() -> bool:
	main_menu_bgm_muted = BgmMuteState.toggle(get_tree())
	var player := _get_preloaded_main_menu_bgm_player()
	if main_menu_bgm_muted:
		if player != null and player.playing:
			player.stop()
		return true
	if player == null or player.stream == null:
		_preload_main_menu_bgm()
	elif not player.playing:
		player.play()
	return false


func _is_key_pressed(event: InputEvent, keycode: int) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return false
	return key_event.keycode == keycode or key_event.physical_keycode == keycode


func _draw() -> void:
	var view_size := size
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		view_size = get_viewport_rect().size
	if logo_intro != null and logo_intro.has_method("is_active") and bool(logo_intro.is_active()):
		if logo_intro.has_method("draw"):
			logo_intro.draw(self, view_size)
			return
	if loading_character_select:
		_draw_character_select_loading(view_size)
		return
	draw_rect(Rect2(Vector2.ZERO, view_size), Color.BLACK)


func _prepare_selection_state() -> void:
	var state := get_node_or_null("/root/GameSelectionState")
	if state != null and state.has_method("set_stage"):
		state.set_stage(starting_stage)


func _configure_app_window() -> void:
	var embedded := Engine.is_embedded_in_editor()
	var can_manage := false
	if view_layout != null and view_layout.has_method("_can_manage_os_window"):
		can_manage = view_layout._can_manage_os_window()
	if OS.get_environment("PINGFIGHTER_BOOT_WINDOW_DEBUG") == "1":
		print("[boot] embedded_in_editor=%s can_manage_window=%s window_mode=%s" % [
			str(embedded), str(can_manage),
			str(get_window().mode) if get_window() != null else "null",
		])
	if view_layout != null and view_layout.has_method("configure_window"):
		view_layout.configure_window(get_window())


func _begin_character_select_loading() -> void:
	if transitioning or loading_character_select:
		return
	_prepare_selection_state()
	loading_character_select = true
	loading_display_percent = 0
	loading_percent_accumulator = 0.0
	loading_target_progress = 0.0
	loading_elapsed = 0.0
	bgm_preload_started = false
	loading_status_text = ""
	_get_loading_font()
	_load_loading_wave_textures()
	if logo_intro != null and logo_intro.has_method("cleanup"):
		logo_intro.cleanup()
	if character_select_prewarm != null and character_select_prewarm.has_method("begin"):
		character_select_prewarm.begin(character_select_scene_path)
	_refresh_loading_snapshot(false)
	queue_redraw()


func _go_to_character_select() -> void:
	if transitioning:
		return
	transitioning = true
	loading_character_select = false
	var state := get_node_or_null("/root/GameSelectionState")
	if state != null:
		if state.has_method("set_stage"):
			state.set_stage(starting_stage)
		if state.has_method("request_skip_battle_logo_once"):
			state.request_skip_battle_logo_once()
	if logo_intro != null and logo_intro.has_method("cleanup"):
		logo_intro.cleanup()
	if post_intro_scene_path != "":
		get_tree().change_scene_to_file(post_intro_scene_path)
	elif character_select_scene_path != "":
		var loaded_scene: PackedScene = null
		if character_select_prewarm != null and character_select_prewarm.has_method("get_loaded_scene"):
			loaded_scene = character_select_prewarm.get_loaded_scene()
		if loaded_scene != null:
			get_tree().change_scene_to_packed(loaded_scene)
		else:
			get_tree().change_scene_to_file(character_select_scene_path)


func _refresh_loading_snapshot(loading_finished: bool) -> void:
	loading_target_progress = 1.0 if loading_finished else 0.0
	if character_select_prewarm != null:
		if character_select_prewarm.has_method("get_status_text"):
			loading_status_text = str(character_select_prewarm.get_status_text())
		if character_select_prewarm.has_method("get_progress"):
			loading_target_progress = float(character_select_prewarm.get_progress())
	if loading_finished:
		loading_target_progress = 1.0
	loading_target_progress = clamp(loading_target_progress, 0.0, 1.0)


func _update_loading_display(delta: float, loading_finished: bool) -> void:
	var target_percent := int(floor(loading_target_progress * 100.0))
	if loading_finished:
		target_percent = 100
	else:
		target_percent = clamp(target_percent, 0, 99)
	target_percent = max(target_percent, loading_display_percent)
	if loading_display_percent >= target_percent:
		loading_percent_accumulator = 0.0
		return

	var rate := LOADING_FINISH_PERCENT_RATE if loading_finished else LOADING_PERCENT_RATE
	loading_percent_accumulator = min(2.0, loading_percent_accumulator + max(delta, 0.0) * rate)
	if loading_percent_accumulator >= 1.0:
		loading_percent_accumulator -= 1.0
		loading_display_percent = min(target_percent, loading_display_percent + 1)


func _draw_character_select_loading(view_size: Vector2) -> void:
	var font := _get_loading_font()
	draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.008, 0.010, 0.018, 1.0))
	var center := view_size * 0.5
	var pulse := 0.5 + sin(Time.get_ticks_msec() * 0.004) * 0.5
	var accent := Color(0.0, 0.82, 1.0, 1.0)
	var gold := Color(1.0, 0.72, 0.26, 1.0)
	_draw_loading_energy_wave_layer(view_size, center, pulse)
	var title_center := center + Vector2(0.0, -52.0)
	_draw_centered_text(font, LanguageSettings.translate_text("게임 데이터 준비 중"), title_center, 26, Color.WHITE)
	var status_text := loading_status_text if loading_status_text != "" else LanguageSettings.translate_text("데이터를 준비하는 중입니다")
	var display_progress := float(loading_display_percent) / 100.0
	_draw_centered_text(font, LanguageSettings.translate_text(status_text), center + Vector2(0.0, -8.0), 16, Color(0.76, 0.88, 0.96, 0.96))
	var progress_w: float = clamp(view_size.x * 0.42, 340.0, 640.0)
	var progress_rect := Rect2(Vector2(center.x - progress_w * 0.5, center.y + 34.0), Vector2(progress_w, 10.0))
	draw_rect(progress_rect, Color(1.0, 1.0, 1.0, 0.12))
	draw_rect(progress_rect, Color(0.0, 0.0, 0.0, 0.44), false, 1.0)
	draw_rect(Rect2(progress_rect.position, Vector2(progress_rect.size.x * display_progress, progress_rect.size.y)), Color(accent.r, accent.g, accent.b, 0.92))
	draw_line(progress_rect.position + Vector2(0.0, -8.0), progress_rect.position + Vector2(progress_rect.size.x, -8.0), Color(gold.r, gold.g, gold.b, 0.20), 1.0)
	_draw_centered_text(font, "%d%%" % loading_display_percent, center + Vector2(0.0, 72.0), 18, Color(0.88, 0.94, 1.0, 0.94))
	_draw_centered_text(font, LanguageSettings.translate_text("잠시만 기다려 주세요"), center + Vector2(0.0, 106.0), 13, Color(0.64, 0.74, 0.82, 0.72))


func _consider_main_menu_bgm_preload(loading_finished: bool) -> void:
	# Start the main-menu BGM partway through loading so it is already
	# playing when the menu opens. Trigger when either the prewarm has
	# already finished or the linear-extrapolated remaining time fits
	# inside the preload window.
	if bgm_preload_started:
		return
	var should_start: bool = false
	if loading_finished or loading_target_progress >= 1.0:
		should_start = true
	elif loading_target_progress >= BGM_PRELOAD_MIN_PROGRESS and loading_elapsed > 0.0:
		var estimated_total: float = loading_elapsed / loading_target_progress
		var remaining: float = estimated_total - loading_elapsed
		if remaining <= BGM_PRELOAD_LEAD_SECONDS:
			should_start = true
	if not should_start:
		return
	bgm_preload_started = true
	_preload_main_menu_bgm()


func _preload_main_menu_bgm() -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return
	var existing_player := _get_preloaded_main_menu_bgm_player()
	if existing_player != null and existing_player.playing:
		return
	var stream: AudioStream = ProjectResourceLoader.load_audio_stream(
		MAIN_MENU_BGM_PATH,
		"Missing main-menu BGM: %s",
		"Failed to load main-menu BGM: %s"
	)
	if stream == null:
		return
	_enable_main_menu_bgm_loop(stream)
	_ensure_main_menu_bgm_bus()
	var player: AudioStreamPlayer = existing_player
	if player == null:
		player = AudioStreamPlayer.new()
		player.name = MAIN_MENU_BGM_PLAYER_NAME
		tree.root.add_child(player)
	player.bus = MAIN_MENU_BGM_BUS_NAME
	player.stream = stream
	player.volume_db = _main_menu_bgm_volume_to_db(MAIN_MENU_BGM_GAIN)
	player.pitch_scale = 1.0
	if not main_menu_bgm_muted:
		player.play()


func _get_preloaded_main_menu_bgm_player() -> AudioStreamPlayer:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return null
	var existing: Node = tree.root.get_node_or_null(MAIN_MENU_BGM_PLAYER_NAME)
	return existing as AudioStreamPlayer


func _restore_main_menu_bgm_muted() -> void:
	main_menu_bgm_muted = BgmMuteState.is_muted(get_tree())


func _enable_main_menu_bgm_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var wav_stream: AudioStreamWAV = stream
		wav_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav_stream.loop_begin = 0
		wav_stream.loop_end = max(0, int(round(wav_stream.get_length() * float(wav_stream.mix_rate))))
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true


func _ensure_main_menu_bgm_bus() -> int:
	var bus_index: int = AudioServer.get_bus_index(MAIN_MENU_BGM_BUS_NAME)
	if bus_index >= 0:
		return bus_index
	AudioServer.add_bus(AudioServer.get_bus_count())
	bus_index = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(bus_index, MAIN_MENU_BGM_BUS_NAME)
	AudioServer.set_bus_volume_db(bus_index, _main_menu_bgm_volume_to_db(MAIN_MENU_BGM_DEFAULT_BUS_VOLUME))
	return bus_index


func _main_menu_bgm_volume_to_db(volume: float) -> float:
	var clamped: float = clampf(volume, 0.0, 1.0)
	if clamped <= 0.0:
		return -80.0
	return linear_to_db(clamped)


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


func _draw_loading_energy_wave_layer(view_size: Vector2, center: Vector2, pulse: float) -> void:
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
	var wave_center := Vector2(center.x, center.y - 20.0 + sin(Time.get_ticks_msec() * 0.0018) * 7.0)
	var wave_rect := Rect2(wave_center - Vector2(wave_width, wave_height) * 0.5, Vector2(wave_width, wave_height))
	draw_texture_rect_region(texture, wave_rect.grow(20.0), source, Color(0.0, 0.72, 1.0, 0.10 + pulse * 0.035), false, true)
	draw_texture_rect_region(texture, wave_rect, source, Color(1.0, 1.0, 1.0, 0.26 + pulse * 0.08), false, true)


func _draw_centered_text(font: Font, text: String, center: Vector2, font_size: int, color: Color) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline := center + Vector2(-text_size.x * 0.5, text_size.y * 0.34)
	draw_string(font, baseline + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, color.a * 0.70))
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
