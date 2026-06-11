extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const VIEW_WIDTH := 1488.0
const VIEW_HEIGHT := 918.0
const WINDOW_TARGET_HEIGHT_RATIO := 0.865
const WINDOW_TARGET_WIDTH_RATIO := 0.90
const GAME_RENDER_MARGIN_Y_RATIO := 0.065
const GAME_RENDER_MIN_MARGIN_Y := 30.0
const MOBILE_SAFE_MARGIN_MIN := 8.0
const DISPLAY_MODE_FULLSCREEN := "fullscreen"
const DISPLAY_MODE_EXCLUSIVE_FULLSCREEN := "exclusive_fullscreen"
const DISPLAY_MODE_WINDOWED := "windowed"
const SETTINGS_PATH := "user://display_settings.cfg"
const SETTINGS_BACKUP_PATH := "user://display_settings.last_good.cfg"
const SETTINGS_SCHEMA_VERSION := 5
const RENDER_FPS_CAP_UNLIMITED := 0
const RENDER_FPS_CAP_STABILITY := 48
const RENDER_FPS_CAP_SMOOTH := 60
const RENDER_FPS_CAP_BALANCED := 72
const RENDER_FPS_CAP_MONITOR := -1
const RENDER_FPS_CAP_STABLE_MONITOR := -2
const RENDER_FPS_CAP_DEFAULT := RENDER_FPS_CAP_STABLE_MONITOR
const RENDER_FPS_CAP_STABLE_MAX := 90
const RENDER_FPS_CAP_STABLE_MIN := 45
# 2026-06-11 promotion: 72 so a 144Hz monitor maps to 72 (was 60 -> 144Hz
# mapped to 48). Gated by the 72fps budget work — clean-run verdict in
# docs/frame_budget_72fps_optimization_design.md §0.2. Physics tick syncs to
# the resolved cap, so 144Hz now runs 72/72 (= the project physics default,
# which also retires the 48-tick tunneling concern for >120Hz displays).
const RENDER_FPS_CAP_STABLE_PREFERRED_MAX := 72
const HIGH_REFRESH_RECOMMENDATION_MIN_HZ := 120
const WINDOWS_DISPLAY_SETTINGS_URI := "ms-settings:display"
const PHYSICS_TICKS_SETTING := "physics/common/physics_ticks_per_second"
const PHYSICS_TICKS_PROJECT_DEFAULT := 72
const PHYSICS_TICKS_SYNC_MIN := 30
const PHYSICS_TICKS_SYNC_MAX := 120
const VSYNC_MODE_AUTO := -1
const VSYNC_MODE_OPTIONS: Array[int] = [
	VSYNC_MODE_AUTO,
	DisplayServer.VSYNC_ENABLED,
	DisplayServer.VSYNC_MAILBOX,
	DisplayServer.VSYNC_DISABLED,
]
const RENDER_FPS_CAP_OPTIONS: Array[int] = [
	RENDER_FPS_CAP_UNLIMITED,
	RENDER_FPS_CAP_STABILITY,
	RENDER_FPS_CAP_SMOOTH,
	RENDER_FPS_CAP_BALANCED,
	RENDER_FPS_CAP_STABLE_MONITOR,
	RENDER_FPS_CAP_MONITOR,
]
const DISPLAY_SETTINGS_GRAPHICS_KEYS: Array[String] = [
	"remember_display_mode",
	"display_mode",
	"render_fps_cap",
	"vsync_mode",
	"auto_60hz_refresh_rate",
]

var _last_windowed_size := Vector2i.ZERO
var _last_windowed_position := Vector2i.ZERO
static var _runtime_render_fps_cap := RENDER_FPS_CAP_DEFAULT
static var _runtime_physics_ticks_per_second := PHYSICS_TICKS_PROJECT_DEFAULT
static var _project_physics_ticks_per_second := PHYSICS_TICKS_PROJECT_DEFAULT
static var _project_physics_ticks_initialized := false
static var _runtime_window_geometry_configured := false
static var _configure_window_count := 0
static var _last_configure_window_summary := "not_called"
static var _last_settings_save_summary := "not_saved"
static var _settings_load_count := 0
static var _last_settings_load_summary := "not_loaded"
static var _last_good_backup_written := false


func configure_window(window: Window) -> void:
	if window == null:
		return
	_configure_window_count += 1
	var can_manage_window := _can_manage_os_window()
	var saved_display_mode := get_saved_display_mode()
	var remember_display_mode := get_remember_display_mode()
	var saved_vsync_mode: int = get_saved_vsync_mode()
	var saved_render_cap: int = get_saved_render_fps_cap()
	var settings_load_summary := get_settings_load_summary()
	var window_geometry_action := "unmanaged"
	if can_manage_window:
		if remember_display_mode:
			if saved_display_mode == DISPLAY_MODE_WINDOWED and not is_fullscreen(window):
				_remember_windowed_geometry(window)
				window_geometry_action = "preserve_windowed"
			else:
				var applied_mode := apply_display_mode(window, saved_display_mode)
				window_geometry_action = "apply_%s" % applied_mode
				if applied_mode == DISPLAY_MODE_WINDOWED:
					_remember_windowed_geometry(window)
		elif not is_fullscreen(window):
			if _runtime_window_geometry_configured:
				window_geometry_action = "preserve_windowed"
			else:
				var target_rect := _build_default_window_rect()
				if target_rect.size.x > 0 and target_rect.size.y > 0:
					window.size = target_rect.size
					window.position = target_rect.position
					window_geometry_action = "apply_default"
				else:
					window_geometry_action = "default_unavailable"
			_remember_windowed_geometry(window)
		else:
			window_geometry_action = "preserve_fullscreen"
		_runtime_window_geometry_configured = true
	apply_auto_refresh_rate(window, get_auto_refresh_rate_enabled())
	apply_render_fps_cap(window, saved_render_cap, saved_vsync_mode)
	apply_vsync_mode(saved_vsync_mode, window)
	_last_configure_window_summary = "count=%d can_manage=%s geometry=%s saved_window=%s remember=%s saved_cap=%s saved_vsync=%s actual_window=%s actual_vsync=%s config=%s" % [
		_configure_window_count,
		"on" if can_manage_window else "off",
		window_geometry_action,
		saved_display_mode,
		"on" if remember_display_mode else "off",
		str(get_render_fps_cap_label(saved_render_cap, window)).replace(" ", "_"),
		get_vsync_mode_label(saved_vsync_mode).replace(" ", "_"),
		get_display_mode(window),
		get_vsync_mode_label(get_vsync_mode()).replace(" ", "_"),
		settings_load_summary,
	]


func toggle_fullscreen(window: Window) -> void:
	if window == null:
		return
	if not _can_manage_os_window():
		return
	var new_mode: String
	if is_fullscreen(window):
		apply_display_mode(window, DISPLAY_MODE_WINDOWED)
		new_mode = DISPLAY_MODE_WINDOWED
	else:
		apply_display_mode(window, DISPLAY_MODE_FULLSCREEN)
		new_mode = DISPLAY_MODE_FULLSCREEN
	# When the user has opted into "remember display mode," keep the saved
	# preference in sync with the runtime toggle so subsequent scene
	# transitions (configure_window) don't bounce the window back to the
	# previously persisted mode.
	if get_remember_display_mode():
		save_display_mode_default(new_mode, true)


func apply_display_mode(window: Window, mode: String) -> String:
	var normalized_mode := _normalize_display_mode(mode)
	if window == null:
		return normalized_mode
	if not _can_manage_os_window():
		return get_display_mode(window)
	if normalized_mode == DISPLAY_MODE_EXCLUSIVE_FULLSCREEN:
		if window.mode != Window.MODE_EXCLUSIVE_FULLSCREEN:
			_remember_windowed_geometry(window)
			window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		return DISPLAY_MODE_EXCLUSIVE_FULLSCREEN
	if normalized_mode == DISPLAY_MODE_FULLSCREEN:
		if window.mode != Window.MODE_FULLSCREEN:
			_remember_windowed_geometry(window)
			window.mode = Window.MODE_FULLSCREEN
		return DISPLAY_MODE_FULLSCREEN
	_restore_windowed(window)
	return DISPLAY_MODE_WINDOWED


func get_display_mode(window: Window) -> String:
	if window == null:
		return DISPLAY_MODE_WINDOWED
	if window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
		return DISPLAY_MODE_EXCLUSIVE_FULLSCREEN
	if window.mode == Window.MODE_FULLSCREEN:
		return DISPLAY_MODE_FULLSCREEN
	return DISPLAY_MODE_WINDOWED


func get_remember_display_mode() -> bool:
	var config := _load_display_settings()
	if config.has_section_key("graphics", "remember_display_mode"):
		return bool(config.get_value("graphics", "remember_display_mode", false))
	var saved_mode := _normalize_display_mode(str(config.get_value("graphics", "display_mode", DISPLAY_MODE_WINDOWED)))
	return saved_mode != DISPLAY_MODE_WINDOWED


func get_saved_display_mode() -> String:
	var config := _load_display_settings()
	return _normalize_display_mode(str(config.get_value("graphics", "display_mode", DISPLAY_MODE_WINDOWED)))


func save_display_mode_default(mode: String, remember_default: bool) -> bool:
	var config := _load_display_settings()
	_stamp_display_settings_schema(config)
	var normalized_mode := _normalize_display_mode(mode)
	if normalized_mode != DISPLAY_MODE_WINDOWED:
		remember_default = true
	config.set_value("graphics", "remember_display_mode", remember_default)
	if remember_default:
		config.set_value("graphics", "display_mode", normalized_mode)
	elif config.has_section_key("graphics", "display_mode"):
		config.erase_section_key("graphics", "display_mode")
	var result := config.save(SETTINGS_PATH)
	_record_settings_save("display", config, result)
	if result == OK:
		_save_last_good_display_settings(config)
	return result == OK


func get_render_fps_cap(window: Window = null) -> int:
	var current_cap: int = int(Engine.get("max_fps"))
	if current_cap <= 0:
		return RENDER_FPS_CAP_UNLIMITED
	var saved_cap: int = get_saved_render_fps_cap()
	if saved_cap == RENDER_FPS_CAP_STABLE_MONITOR and current_cap == _get_stable_monitor_refresh_rate(window):
		return RENDER_FPS_CAP_STABLE_MONITOR
	if saved_cap == RENDER_FPS_CAP_MONITOR and current_cap == _get_monitor_refresh_rate(window):
		return RENDER_FPS_CAP_MONITOR
	return current_cap


func get_saved_render_fps_cap() -> int:
	var config := _load_display_settings()
	return _normalize_render_fps_cap(int(config.get_value("graphics", "render_fps_cap", RENDER_FPS_CAP_DEFAULT)))


func get_render_fps_cap_options() -> Array[int]:
	return RENDER_FPS_CAP_OPTIONS.duplicate()


func apply_render_fps_cap(window: Window, cap: int, vsync_mode: int = VSYNC_MODE_AUTO) -> int:
	var normalized_cap: int = _normalize_render_fps_cap(cap)
	_runtime_render_fps_cap = normalized_cap
	var engine_cap: int = _resolve_render_fps_cap(window, normalized_cap, vsync_mode)
	Engine.set("max_fps", engine_cap)
	_apply_physics_ticks_for_render_cap(normalized_cap, engine_cap)
	return normalized_cap


static func get_runtime_render_fps_cap() -> int:
	return _runtime_render_fps_cap


static func get_runtime_physics_ticks_per_second() -> int:
	return _runtime_physics_ticks_per_second


static func get_configure_window_summary() -> String:
	return _last_configure_window_summary


static func get_settings_save_summary() -> String:
	return _last_settings_save_summary


static func get_settings_load_summary() -> String:
	return _last_settings_load_summary


func save_render_fps_cap_default(cap: int) -> bool:
	var normalized_cap: int = _normalize_render_fps_cap(cap)
	_runtime_render_fps_cap = normalized_cap
	var config := _load_display_settings()
	_stamp_display_settings_schema(config)
	config.set_value("graphics", "render_fps_cap", normalized_cap)
	var result := config.save(SETTINGS_PATH)
	_record_settings_save("render_cap", config, result)
	if result == OK:
		_save_last_good_display_settings(config)
	return result == OK


func get_vsync_mode() -> int:
	return _normalize_vsync_mode(int(DisplayServer.window_get_vsync_mode()))


func get_saved_vsync_mode() -> int:
	var config := _load_display_settings()
	return _normalize_vsync_mode(int(config.get_value("graphics", "vsync_mode", VSYNC_MODE_AUTO)))


func get_vsync_mode_options() -> Array[int]:
	return VSYNC_MODE_OPTIONS.duplicate()


func apply_vsync_mode(mode: int, window: Window = null) -> int:
	var normalized_mode: int = _normalize_vsync_mode(mode)
	DisplayServer.window_set_vsync_mode(_resolve_vsync_mode(window, normalized_mode))
	return normalized_mode


func save_vsync_mode_default(mode: int) -> bool:
	var config := _load_display_settings()
	_stamp_display_settings_schema(config)
	config.set_value("graphics", "vsync_mode", _normalize_vsync_mode(mode))
	var result := config.save(SETTINGS_PATH)
	_record_settings_save("vsync", config, result)
	if result == OK:
		_save_last_good_display_settings(config)
	return result == OK


func get_auto_refresh_rate_enabled() -> bool:
	var config := _load_display_settings()
	return bool(config.get_value("graphics", "auto_60hz_refresh_rate", false))


func apply_auto_refresh_rate(window: Window, enabled: bool) -> bool:
	var refresh_manager := _get_display_refresh_manager()
	if refresh_manager == null:
		return false
	if not enabled:
		if refresh_manager.has_method("restore_refresh_rate"):
			return bool(refresh_manager.restore_refresh_rate())
		return false
	var screen_index: int = DisplayServer.SCREEN_OF_MAIN_WINDOW
	if window != null:
		screen_index = window.current_screen
	if refresh_manager.has_method("apply_auto_60hz"):
		return bool(refresh_manager.apply_auto_60hz(screen_index))
	return false


func save_auto_refresh_rate_default(enabled: bool, window: Window = null) -> bool:
	var config := _load_display_settings()
	_stamp_display_settings_schema(config)
	config.set_value("graphics", "auto_60hz_refresh_rate", enabled)
	var result := config.save(SETTINGS_PATH)
	_record_settings_save("auto_refresh", config, result)
	if result == OK:
		_save_last_good_display_settings(config)
		if not enabled or window != null:
			apply_auto_refresh_rate(window, enabled)
	return result == OK


func get_vsync_mode_label(mode: int) -> String:
	var normalized_mode: int = _normalize_vsync_mode(mode)
	if normalized_mode == VSYNC_MODE_AUTO:
		return "Auto"
	if normalized_mode == DisplayServer.VSYNC_DISABLED:
		return "VSync Off"
	if normalized_mode == DisplayServer.VSYNC_ADAPTIVE:
		return "Adaptive"
	if normalized_mode == DisplayServer.VSYNC_MAILBOX:
		return "Mailbox"
	return "VSync On"


func get_render_fps_cap_label(cap: int, window: Window = null) -> String:
	var normalized_cap: int = _normalize_render_fps_cap(cap)
	if normalized_cap == RENDER_FPS_CAP_STABLE_MONITOR:
		return "Stable %d FPS" % _get_stable_monitor_refresh_rate(window)
	if normalized_cap == RENDER_FPS_CAP_UNLIMITED:
		return LanguageSettings.translate_text("제한 없음")
	if normalized_cap == RENDER_FPS_CAP_MONITOR:
		if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_ENGLISH:
			return "Monitor %d Hz" % _get_monitor_refresh_rate(window)
		if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_SPANISH:
			return "Monitor %d Hz" % _get_monitor_refresh_rate(window)
		if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL:
			return "Monitor %d Hz" % _get_monitor_refresh_rate(window)
		if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_RUSSIAN:
			return "Монитор %d Hz" % _get_monitor_refresh_rate(window)
		if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_CHINESE:
			return "显示器 %d Hz" % _get_monitor_refresh_rate(window)
		if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_JAPANESE:
			return "モニター %d Hz" % _get_monitor_refresh_rate(window)
		return "모니터 %d Hz" % _get_monitor_refresh_rate(window)
	return "%d FPS" % normalized_cap


func get_monitor_refresh_rate(window: Window = null) -> int:
	return _get_monitor_refresh_rate(window)


func is_high_refresh_monitor(window: Window = null) -> bool:
	return get_monitor_refresh_rate(window) >= HIGH_REFRESH_RECOMMENDATION_MIN_HZ


func get_display_pacing_recommendation(
	window: Window = null,
	selected_display_mode: String = DISPLAY_MODE_WINDOWED,
	selected_cap: int = RENDER_FPS_CAP_DEFAULT,
	selected_vsync_mode: int = VSYNC_MODE_AUTO
) -> String:
	var monitor_rate: int = get_monitor_refresh_rate(window)
	var normalized_mode := _normalize_display_mode(selected_display_mode)
	var normalized_cap: int = _normalize_render_fps_cap(selected_cap)
	var normalized_vsync: int = _normalize_vsync_mode(selected_vsync_mode)
	var stable_cap: int = _get_stable_monitor_refresh_rate(window)
	var stable_settings_ready := (
		normalized_mode == DISPLAY_MODE_EXCLUSIVE_FULLSCREEN
		and normalized_cap == RENDER_FPS_CAP_STABLE_MONITOR
		and (
			normalized_vsync == VSYNC_MODE_AUTO
			or normalized_vsync == DisplayServer.VSYNC_ENABLED
		)
	)
	if stable_settings_ready:
		if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_ENGLISH:
			return "%dHz monitor detected: stable pacing will use %d FPS.\nIf you change monitors, the next apply will recalculate the stable cap." % [monitor_rate, stable_cap]
		if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_SPANISH:
			return "Monitor de %d Hz detectado: el ritmo estable usara %d FPS.\nSi cambias de monitor, el proximo aplicar recalculara el limite estable." % [monitor_rate, stable_cap]
		if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL:
			return "Monitor de %d Hz detectado: o ritmo estavel usara %d FPS.\nSe trocar de monitor, a proxima aplicacao recalculara o limite estavel." % [monitor_rate, stable_cap]
		if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_RUSSIAN:
			return "Обнаружен монитор %d Hz: стабильный режим использует %d FPS.\nЕсли сменить монитор, следующее применение пересчитает стабильный лимит." % [monitor_rate, stable_cap]
		if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_CHINESE:
			return "检测到%dHz显示器：稳定节奏将使用%d FPS。\n更换显示器后，下次应用会重新计算稳定上限。" % [monitor_rate, stable_cap]
		if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_JAPANESE:
			return "%dHzモニターを検出：安定ペーシングは%d FPSを使います。\nモニターを変更すると、次回適用時に安定上限を再計算します。" % [monitor_rate, stable_cap]
		return "%dHz 모니터 감지: 안정 페이싱은 %d FPS를 사용합니다.\n모니터를 바꾸면 다음 적용 시 안정 상한을 다시 계산합니다." % [monitor_rate, stable_cap]
	if normalized_cap == RENDER_FPS_CAP_MONITOR:
		if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_ENGLISH:
			return "%dHz monitor detected: render FPS follows the current refresh rate.\nExclusive fullscreen and VSync Auto are the cleanest settings." % monitor_rate
		if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_SPANISH:
			return "Monitor de %d Hz detectado: los FPS de render siguen la frecuencia actual.\nPantalla completa exclusiva y VSync Auto son los ajustes más limpios." % monitor_rate
		if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL:
			return "Monitor de %d Hz detectado: os FPS de renderização seguem a frequência atual.\nTela cheia exclusiva e VSync Auto são as configurações mais limpas." % monitor_rate
		if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_RUSSIAN:
			return "Обнаружен монитор %d Hz: FPS рендера следует текущей частоте.\nЭксклюзивный полный экран и VSync Auto дают самый чистый режим." % monitor_rate
		if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_CHINESE:
			return "检测到%dHz显示器：渲染FPS将跟随当前刷新率。\n推荐使用独占全屏和VSync自动。" % monitor_rate
		if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_JAPANESE:
			return "%dHzモニターを検出：描画FPSは現在のリフレッシュレートに追従します。\n排他全画面とVSync Autoが最も安定します。" % monitor_rate
		return "%dHz 모니터 감지: 렌더 FPS는 현재 주사율을 따라갑니다.\n독점 전체화면과 VSync Auto가 가장 깔끔합니다." % monitor_rate
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_ENGLISH:
		return "%dHz monitor detected: use Stable Monitor for %d FPS pacing.\nUse Recommended to save the display-aware stable cap." % [monitor_rate, stable_cap]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_SPANISH:
		return "Monitor de %d Hz detectado: usa Monitor estable para %d FPS.\nUsa Recomendado para guardar el limite estable de esta pantalla." % [monitor_rate, stable_cap]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL:
		return "Monitor de %d Hz detectado: use Monitor estavel para %d FPS.\nUse Recomendado para salvar o limite estavel desta tela." % [monitor_rate, stable_cap]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_RUSSIAN:
		return "Обнаружен монитор %d Hz: используйте стабильный монитор для %d FPS.\nРекомендованное сохранит стабильный лимит для этого экрана." % [monitor_rate, stable_cap]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_CHINESE:
		return "检测到%dHz显示器：使用稳定显示器节奏会采用%d FPS。\n使用推荐会保存此屏幕的稳定上限。" % [monitor_rate, stable_cap]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_JAPANESE:
		return "%dHzモニターを検出：安定モニター設定では%d FPSを使います。\n推奨値を使うとこの画面の安定上限を保存します。" % [monitor_rate, stable_cap]
	return "%dHz 모니터 감지: 안정 모니터 페이싱은 %d FPS를 사용합니다.\n권장값 적용을 누르면 현재 화면의 안정 상한을 저장합니다." % [monitor_rate, stable_cap]


func open_system_display_settings() -> int:
	if OS.get_name() != "Windows":
		return ERR_UNAVAILABLE
	return OS.shell_open(WINDOWS_DISPLAY_SETTINGS_URI)


func is_fullscreen(window: Window) -> bool:
	if window == null:
		return false
	return window.mode == Window.MODE_FULLSCREEN or window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN


func _normalize_display_mode(mode: String) -> String:
	var normalized := mode.strip_edges().to_lower()
	if normalized == DISPLAY_MODE_EXCLUSIVE_FULLSCREEN or normalized == "exclusive":
		return DISPLAY_MODE_EXCLUSIVE_FULLSCREEN
	if normalized == DISPLAY_MODE_FULLSCREEN:
		return DISPLAY_MODE_FULLSCREEN
	return DISPLAY_MODE_WINDOWED


func _normalize_render_fps_cap(cap: int) -> int:
	if cap == RENDER_FPS_CAP_STABLE_MONITOR:
		return RENDER_FPS_CAP_STABLE_MONITOR
	if cap == RENDER_FPS_CAP_MONITOR:
		return RENDER_FPS_CAP_MONITOR
	if cap <= 0:
		return RENDER_FPS_CAP_UNLIMITED
	return max(1, cap)


func _normalize_vsync_mode(mode: int) -> int:
	if mode == VSYNC_MODE_AUTO:
		return VSYNC_MODE_AUTO
	if mode == DisplayServer.VSYNC_DISABLED:
		return DisplayServer.VSYNC_DISABLED
	if mode == DisplayServer.VSYNC_MAILBOX:
		return DisplayServer.VSYNC_MAILBOX
	if mode == DisplayServer.VSYNC_ADAPTIVE:
		return DisplayServer.VSYNC_ADAPTIVE
	return DisplayServer.VSYNC_ENABLED


func _resolve_render_fps_cap(window: Window, cap: int, _vsync_mode: int = VSYNC_MODE_AUTO) -> int:
	var normalized_cap: int = _normalize_render_fps_cap(cap)
	if normalized_cap == RENDER_FPS_CAP_STABLE_MONITOR:
		return _get_stable_monitor_refresh_rate(window)
	if normalized_cap == RENDER_FPS_CAP_MONITOR:
		return _get_monitor_refresh_rate(window)
	return normalized_cap


func _apply_physics_ticks_for_render_cap(cap: int, engine_cap: int) -> int:
	var physics_ticks: int = _resolve_physics_ticks_per_second(cap, engine_cap)
	Engine.physics_ticks_per_second = physics_ticks
	_runtime_physics_ticks_per_second = physics_ticks
	return physics_ticks


func _resolve_physics_ticks_per_second(cap: int, engine_cap: int) -> int:
	var normalized_cap: int = _normalize_render_fps_cap(cap)
	if normalized_cap == RENDER_FPS_CAP_SMOOTH:
		return RENDER_FPS_CAP_SMOOTH
	if normalized_cap == RENDER_FPS_CAP_BALANCED:
		return RENDER_FPS_CAP_BALANCED
	if (
		normalized_cap == RENDER_FPS_CAP_STABLE_MONITOR
		or normalized_cap == RENDER_FPS_CAP_MONITOR
	):
		if engine_cap >= PHYSICS_TICKS_SYNC_MIN and engine_cap <= PHYSICS_TICKS_SYNC_MAX:
			return engine_cap
	return _get_project_physics_ticks_per_second()


static func _get_project_physics_ticks_per_second() -> int:
	if not _project_physics_ticks_initialized:
		_project_physics_ticks_per_second = clampi(
			int(ProjectSettings.get_setting(PHYSICS_TICKS_SETTING, PHYSICS_TICKS_PROJECT_DEFAULT)),
			PHYSICS_TICKS_SYNC_MIN,
			PHYSICS_TICKS_SYNC_MAX
		)
		_project_physics_ticks_initialized = true
	return _project_physics_ticks_per_second


func _resolve_vsync_mode(window: Window, mode: int) -> int:
	var normalized_mode: int = _normalize_vsync_mode(mode)
	if normalized_mode != VSYNC_MODE_AUTO:
		return normalized_mode
	var render_cap: int = int(Engine.get("max_fps"))
	if render_cap > 0 and render_cap < _get_monitor_refresh_rate(window):
		return DisplayServer.VSYNC_DISABLED
	return DisplayServer.VSYNC_ENABLED


func _get_monitor_refresh_rate(window: Window = null) -> int:
	var screen_index: int = DisplayServer.SCREEN_OF_MAIN_WINDOW
	if window != null:
		screen_index = window.current_screen
	var refresh_rate: float = DisplayServer.screen_get_refresh_rate(screen_index)
	if refresh_rate <= 0.0:
		refresh_rate = 60.0
	return max(30, int(round(refresh_rate)))


func _get_display_refresh_manager() -> Object:
	var main_loop: MainLoop = Engine.get_main_loop()
	if not main_loop is SceneTree:
		return null
	var root := (main_loop as SceneTree).root
	if root == null:
		return null
	var manager := root.get_node_or_null("DisplayRefreshManager")
	if manager != null and is_instance_valid(manager):
		return manager
	return null


func _get_stable_monitor_refresh_rate(window: Window = null) -> int:
	return resolve_stable_cap_for_monitor_rate(_get_monitor_refresh_rate(window))


# Pure divisor mapping so the smoke can seal the monitor-rate table directly
# (144 -> 72, 120 -> 60, <= 90 -> as-is).
static func resolve_stable_cap_for_monitor_rate(monitor_rate: int) -> int:
	if monitor_rate <= RENDER_FPS_CAP_STABLE_MAX:
		return monitor_rate
	# Prefer divisors with enough headroom to avoid near-budget VSync misses.
	for divisor in range(2, 9):
		if monitor_rate % divisor != 0:
			continue
		@warning_ignore("integer_division")
		var candidate: int = monitor_rate / divisor
		if candidate <= RENDER_FPS_CAP_STABLE_PREFERRED_MAX and candidate >= RENDER_FPS_CAP_STABLE_MIN:
			return candidate
	for divisor in range(2, 9):
		if monitor_rate % divisor != 0:
			continue
		@warning_ignore("integer_division")
		var candidate: int = monitor_rate / divisor
		if candidate <= RENDER_FPS_CAP_STABLE_MAX and candidate >= RENDER_FPS_CAP_STABLE_MIN:
			return candidate
	return min(RENDER_FPS_CAP_STABILITY, monitor_rate)


func _load_display_settings() -> ConfigFile:
	var config := ConfigFile.new()
	_settings_load_count += 1
	var exists := FileAccess.file_exists(SETTINGS_PATH)
	if not exists:
		_set_default_display_settings_payload(config)
		var default_save_result := config.save(SETTINGS_PATH)
		_record_settings_save("missing_defaults", config, default_save_result)
		if default_save_result == OK:
			_save_last_good_display_settings(config)
			_record_settings_load("missing_defaults", exists, OK, config)
		else:
			_record_settings_load("missing_defaults_failed", exists, default_save_result, config)
		return config
	var load_state := "ok"
	var load_result := _load_config_file(config)
	var result: int = int(load_result.get("result", OK))
	load_state = str(load_result.get("state", load_state))
	if result != OK:
		_record_settings_load(load_state, exists, result, config)
		return ConfigFile.new()
	var repair_reason := _repair_empty_display_settings_payload(config)
	_migrate_display_settings(config)
	var completion_reason := _complete_missing_display_settings(config)
	if repair_reason != "" or completion_reason != "":
		var reason := repair_reason if repair_reason != "" else completion_reason
		var repair_result := config.save(SETTINGS_PATH)
		_record_settings_save(reason, config, repair_result)
		if repair_result == OK:
			_save_last_good_display_settings(config)
	elif not _last_good_backup_written and not FileAccess.file_exists(SETTINGS_BACKUP_PATH):
		_save_last_good_display_settings(config)
	if repair_reason != "":
		load_state = "%s_%s" % [load_state, repair_reason]
	elif completion_reason != "":
		load_state = "%s_%s" % [load_state, completion_reason]
	_record_settings_load(load_state, exists, result, config)
	return config


func _migrate_display_settings(config: ConfigFile) -> void:
	var version: int = int(config.get_value("meta", "settings_schema_version", 0))
	if version >= SETTINGS_SCHEMA_VERSION:
		return
	var changed := false
	if version < 2 and config.has_section_key("graphics", "render_fps_cap"):
		var saved_cap: int = _normalize_render_fps_cap(int(config.get_value(
			"graphics",
			"render_fps_cap",
			RENDER_FPS_CAP_DEFAULT
		)))
		if saved_cap == RENDER_FPS_CAP_BALANCED:
			config.set_value("graphics", "render_fps_cap", RENDER_FPS_CAP_DEFAULT)
			changed = true
	if version < 3 and not config.has_section_key("graphics", "remember_display_mode"):
		var saved_display_mode := _normalize_display_mode(str(config.get_value(
			"graphics",
			"display_mode",
			DISPLAY_MODE_WINDOWED
		)))
		if saved_display_mode != DISPLAY_MODE_WINDOWED:
			config.set_value("graphics", "remember_display_mode", true)
			changed = true
	if version < 5 and config.has_section_key("graphics", "render_fps_cap"):
		var saved_cap: int = _normalize_render_fps_cap(int(config.get_value(
			"graphics",
			"render_fps_cap",
			RENDER_FPS_CAP_DEFAULT
		)))
		if saved_cap == RENDER_FPS_CAP_MONITOR:
			config.set_value("graphics", "render_fps_cap", RENDER_FPS_CAP_DEFAULT)
			changed = true
	_stamp_display_settings_schema(config)
	changed = true
	if changed:
		var result := config.save(SETTINGS_PATH)
		_record_settings_save("migrate", config, result)


func _stamp_display_settings_schema(config: ConfigFile) -> void:
	config.set_value("meta", "settings_schema_version", SETTINGS_SCHEMA_VERSION)


func _record_settings_save(reason: String, config: ConfigFile, result: int) -> void:
	var saved_mode := _normalize_display_mode(str(config.get_value("graphics", "display_mode", DISPLAY_MODE_WINDOWED)))
	var remember := bool(config.get_value("graphics", "remember_display_mode", false))
	var saved_cap := _normalize_render_fps_cap(int(config.get_value("graphics", "render_fps_cap", RENDER_FPS_CAP_DEFAULT)))
	var saved_vsync := _normalize_vsync_mode(int(config.get_value("graphics", "vsync_mode", VSYNC_MODE_AUTO)))
	var auto_refresh := bool(config.get_value("graphics", "auto_60hz_refresh_rate", false))
	_last_settings_save_summary = "%s_ok=%s_window=%s_remember=%s_cap=%s_vsync=%s_auto60=%s" % [
		reason,
		"on" if result == OK else "off",
		saved_mode,
		"on" if remember else "off",
		str(get_render_fps_cap_label(saved_cap, null)).replace(" ", "_"),
		get_vsync_mode_label(saved_vsync).replace(" ", "_"),
		"on" if auto_refresh else "off",
	]


func _load_config_file(config: ConfigFile) -> Dictionary:
	var raw_bytes := FileAccess.get_file_as_bytes(SETTINGS_PATH)
	if _has_utf8_bom(raw_bytes):
		var clean_bytes := raw_bytes.slice(3)
		var clean_text := clean_bytes.get_string_from_utf8()
		var parse_result := config.parse(clean_text)
		if parse_result == OK:
			var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
			if file != null:
				file.store_string(clean_text)
				file.close()
		return {
			"result": parse_result,
			"state": "ok_clean_bom" if parse_result == OK else "error_clean_bom",
		}
	var result := config.load(SETTINGS_PATH)
	return {
		"result": result,
		"state": "ok" if result == OK else "error",
	}


func _has_utf8_bom(bytes: PackedByteArray) -> bool:
	return bytes.size() >= 3 and bytes[0] == 0xEF and bytes[1] == 0xBB and bytes[2] == 0xBF


func _repair_empty_display_settings_payload(config: ConfigFile) -> String:
	if _has_display_settings_payload(config):
		return ""
	var backup_config := ConfigFile.new()
	if FileAccess.file_exists(SETTINGS_BACKUP_PATH) and backup_config.load(SETTINGS_BACKUP_PATH) == OK:
		if _has_display_settings_payload(backup_config):
			_copy_display_settings_payload(backup_config, config)
			return "repair_backup"
	_set_default_display_settings_payload(config)
	return "repair_defaults"


func _set_default_display_settings_payload(config: ConfigFile) -> void:
	config.set_value("graphics", "remember_display_mode", false)
	config.set_value("graphics", "render_fps_cap", RENDER_FPS_CAP_DEFAULT)
	config.set_value("graphics", "vsync_mode", VSYNC_MODE_AUTO)
	config.set_value("graphics", "auto_60hz_refresh_rate", false)
	_stamp_display_settings_schema(config)


func _complete_missing_display_settings(config: ConfigFile) -> String:
	var changed := false
	if not config.has_section_key("graphics", "remember_display_mode"):
		var saved_mode := _normalize_display_mode(str(config.get_value("graphics", "display_mode", DISPLAY_MODE_WINDOWED)))
		config.set_value("graphics", "remember_display_mode", saved_mode != DISPLAY_MODE_WINDOWED)
		changed = true
	if not config.has_section_key("graphics", "render_fps_cap"):
		config.set_value("graphics", "render_fps_cap", RENDER_FPS_CAP_DEFAULT)
		changed = true
	if not config.has_section_key("graphics", "vsync_mode"):
		config.set_value("graphics", "vsync_mode", VSYNC_MODE_AUTO)
		changed = true
	if not config.has_section_key("graphics", "auto_60hz_refresh_rate"):
		config.set_value("graphics", "auto_60hz_refresh_rate", false)
		changed = true
	if bool(config.get_value("graphics", "remember_display_mode", false)):
		var saved_display_mode := _normalize_display_mode(str(config.get_value("graphics", "display_mode", DISPLAY_MODE_WINDOWED)))
		if not config.has_section_key("graphics", "display_mode") or saved_display_mode == "":
			config.set_value("graphics", "display_mode", DISPLAY_MODE_WINDOWED)
			changed = true
	return "repair_partial" if changed else ""


func _has_display_settings_payload(config: ConfigFile) -> bool:
	for key in DISPLAY_SETTINGS_GRAPHICS_KEYS:
		if config.has_section_key("graphics", key):
			return true
	return false


func _copy_display_settings_payload(source: ConfigFile, target: ConfigFile) -> void:
	for key in DISPLAY_SETTINGS_GRAPHICS_KEYS:
		if source.has_section_key("graphics", key):
			target.set_value("graphics", key, source.get_value("graphics", key))


func _save_last_good_display_settings(config: ConfigFile) -> void:
	if not _has_display_settings_payload(config):
		return
	var backup_config := ConfigFile.new()
	_copy_display_settings_payload(config, backup_config)
	_stamp_display_settings_schema(backup_config)
	if backup_config.save(SETTINGS_BACKUP_PATH) == OK:
		_last_good_backup_written = true


func _record_settings_load(state: String, exists: bool, result: int, config: ConfigFile) -> void:
	_last_settings_load_summary = "count=%d_state=%s_exists=%s_result=%s_schema=%s_window=%s_remember=%s_cap=%s_vsync=%s_auto60=%s" % [
		_settings_load_count,
		state,
		"on" if exists else "off",
		_error_token(result),
		_config_token(config, "meta", "settings_schema_version"),
		_config_token(config, "graphics", "display_mode"),
		_config_token(config, "graphics", "remember_display_mode"),
		_config_token(config, "graphics", "render_fps_cap"),
		_config_token(config, "graphics", "vsync_mode"),
		_config_token(config, "graphics", "auto_60hz_refresh_rate"),
	]


func _config_token(config: ConfigFile, section: String, key: String) -> String:
	if config == null or not config.has_section_key(section, key):
		return "missing"
	return str(config.get_value(section, key, "missing")).strip_edges().replace(" ", "_")


func _error_token(result: int) -> String:
	if result == OK:
		return "OK"
	if result == ERR_FILE_NOT_FOUND:
		return "ERR_FILE_NOT_FOUND"
	return str(result)


func _build_default_window_rect() -> Rect2i:
	var usable_rect: Rect2i = DisplayServer.screen_get_usable_rect()
	if usable_rect.size.x <= 0 or usable_rect.size.y <= 0:
		return Rect2i()

	var width_scale: float = (float(usable_rect.size.x) * WINDOW_TARGET_WIDTH_RATIO) / VIEW_WIDTH
	var height_scale: float = (float(usable_rect.size.y) * WINDOW_TARGET_HEIGHT_RATIO) / VIEW_HEIGHT
	var target_scale: float = min(width_scale, height_scale)
	if target_scale <= 0.0:
		return Rect2i()

	var target_size := Vector2i(
		int(round(VIEW_WIDTH * target_scale)),
		int(round(VIEW_HEIGHT * target_scale))
	)
	@warning_ignore("integer_division")
	var target_position := usable_rect.position + (usable_rect.size - target_size) / 2
	return Rect2i(target_position, target_size)


func _remember_windowed_geometry(window: Window) -> void:
	if window == null or is_fullscreen(window):
		return
	if window.size.x <= 0 or window.size.y <= 0:
		return
	_last_windowed_size = window.size
	_last_windowed_position = window.position


func _restore_windowed(window: Window) -> void:
	window.mode = Window.MODE_WINDOWED
	if _last_windowed_size.x <= 0 or _last_windowed_size.y <= 0:
		var target_rect := _build_default_window_rect()
		if target_rect.size.x <= 0 or target_rect.size.y <= 0:
			return
		_last_windowed_size = target_rect.size
		_last_windowed_position = target_rect.position
	window.size = _last_windowed_size
	window.position = _last_windowed_position


func build_game_layout(view_size: Vector2, game_width: float, game_height: float) -> Dictionary:
	var layout_rect: Rect2 = _build_layout_rect(view_size)
	if game_width <= 0.0 or game_height <= 0.0:
		return {
			"view_size": view_size,
			"safe_rect": layout_rect,
			"game_offset": Vector2.ZERO,
			"game_size": Vector2.ZERO,
			"render_scale": 1.0,
		}

	var render_margin_y: float = _get_render_margin_y(layout_rect)
	var available_height: float = max(1.0, layout_rect.size.y - render_margin_y * 2.0)
	var available_width: float = max(1.0, layout_rect.size.x)
	var render_scale: float = min(available_width / game_width, available_height / game_height)
	var game_size := Vector2(game_width * render_scale, game_height * render_scale)
	var game_offset := layout_rect.position + Vector2(
		(layout_rect.size.x - game_size.x) * 0.5,
		(layout_rect.size.y - game_size.y) * 0.5
	)
	return {
		"view_size": view_size,
		"safe_rect": layout_rect,
		"game_offset": game_offset,
		"game_size": game_size,
		"render_scale": render_scale,
	}


func _get_render_margin_y(layout_rect: Rect2) -> float:
	if _is_mobile_runtime():
		return 0.0
	return max(floor(layout_rect.size.y * GAME_RENDER_MARGIN_Y_RATIO), GAME_RENDER_MIN_MARGIN_Y)


func _build_layout_rect(view_size: Vector2) -> Rect2:
	var fallback := Rect2(Vector2.ZERO, view_size)
	if not _is_mobile_runtime():
		return fallback
	var safe_rect: Rect2 = _get_scaled_display_safe_rect(view_size)
	if safe_rect.size.x <= 0.0 or safe_rect.size.y <= 0.0:
		return fallback.grow_individual(
			-MOBILE_SAFE_MARGIN_MIN,
			-MOBILE_SAFE_MARGIN_MIN,
			-MOBILE_SAFE_MARGIN_MIN,
			-MOBILE_SAFE_MARGIN_MIN
		)
	return safe_rect.intersection(fallback)


func _get_scaled_display_safe_rect(view_size: Vector2) -> Rect2:
	var safe_area: Rect2i = DisplayServer.get_display_safe_area()
	if safe_area.size.x <= 0 or safe_area.size.y <= 0:
		return Rect2()
	var window_size: Vector2i = DisplayServer.window_get_size()
	if window_size.x <= 0 or window_size.y <= 0:
		return Rect2(Vector2(safe_area.position), Vector2(safe_area.size))
	var scale := Vector2(
		view_size.x / float(window_size.x),
		view_size.y / float(window_size.y)
	)
	return Rect2(
		Vector2(safe_area.position) * scale,
		Vector2(safe_area.size) * scale
	)


func _is_mobile_runtime() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")


func _can_manage_os_window() -> bool:
	if _is_mobile_runtime():
		return false
	# Godot editor game embedding owns the host window; moving or switching it
	# prints "Embedded window can't be moved" and fullscreen mode is unsupported.
	return not Engine.is_embedded_in_editor()
