extends RefCounted

const SETTINGS_SCHEMA_VERSION := 5
const DISPLAY_MODE_FULLSCREEN := "fullscreen"
const DISPLAY_MODE_EXCLUSIVE_FULLSCREEN := "exclusive_fullscreen"
const DISPLAY_MODE_WINDOWED := "windowed"
const RENDER_FPS_CAP_UNLIMITED := 0
const RENDER_FPS_CAP_BALANCED := 72
const RENDER_FPS_CAP_MONITOR := -1
const RENDER_FPS_CAP_STABLE_MONITOR := -2
const RENDER_FPS_CAP_DEFAULT := RENDER_FPS_CAP_STABLE_MONITOR
const VSYNC_MODE_AUTO := -1
const GRAPHICS_SECTION := "graphics"
const META_SECTION := "meta"
const SCHEMA_VERSION_KEY := "settings_schema_version"
const GRAPHICS_KEYS: Array[String] = [
	"remember_display_mode",
	"display_mode",
	"render_fps_cap",
	"vsync_mode",
	"auto_60hz_refresh_rate",
]


func migrate(config: ConfigFile) -> bool:
	var version := int(config.get_value(META_SECTION, SCHEMA_VERSION_KEY, 0))
	if version >= SETTINGS_SCHEMA_VERSION:
		return false
	if version < 2 and config.has_section_key(GRAPHICS_SECTION, "render_fps_cap"):
		var saved_cap := normalize_render_fps_cap(int(config.get_value(
			GRAPHICS_SECTION,
			"render_fps_cap",
			RENDER_FPS_CAP_DEFAULT
		)))
		if saved_cap == RENDER_FPS_CAP_BALANCED:
			config.set_value(GRAPHICS_SECTION, "render_fps_cap", RENDER_FPS_CAP_DEFAULT)
	if version < 3 and not config.has_section_key(GRAPHICS_SECTION, "remember_display_mode"):
		var saved_display_mode := normalize_display_mode(str(config.get_value(
			GRAPHICS_SECTION,
			"display_mode",
			DISPLAY_MODE_WINDOWED
		)))
		if saved_display_mode != DISPLAY_MODE_WINDOWED:
			config.set_value(GRAPHICS_SECTION, "remember_display_mode", true)
	if version < 5 and config.has_section_key(GRAPHICS_SECTION, "render_fps_cap"):
		var saved_cap := normalize_render_fps_cap(int(config.get_value(
			GRAPHICS_SECTION,
			"render_fps_cap",
			RENDER_FPS_CAP_DEFAULT
		)))
		if saved_cap == RENDER_FPS_CAP_MONITOR:
			config.set_value(GRAPHICS_SECTION, "render_fps_cap", RENDER_FPS_CAP_DEFAULT)
	stamp_schema(config)
	return true


func stamp_schema(config: ConfigFile) -> void:
	config.set_value(META_SECTION, SCHEMA_VERSION_KEY, SETTINGS_SCHEMA_VERSION)


func set_default_payload(config: ConfigFile) -> void:
	config.set_value(GRAPHICS_SECTION, "remember_display_mode", false)
	config.set_value(GRAPHICS_SECTION, "render_fps_cap", RENDER_FPS_CAP_DEFAULT)
	config.set_value(GRAPHICS_SECTION, "vsync_mode", VSYNC_MODE_AUTO)
	config.set_value(GRAPHICS_SECTION, "auto_60hz_refresh_rate", false)
	stamp_schema(config)


func complete_missing_payload(config: ConfigFile) -> String:
	var changed := false
	if not config.has_section_key(GRAPHICS_SECTION, "remember_display_mode"):
		var saved_mode := normalize_display_mode(str(config.get_value(
			GRAPHICS_SECTION,
			"display_mode",
			DISPLAY_MODE_WINDOWED
		)))
		config.set_value(GRAPHICS_SECTION, "remember_display_mode", saved_mode != DISPLAY_MODE_WINDOWED)
		changed = true
	if not config.has_section_key(GRAPHICS_SECTION, "render_fps_cap"):
		config.set_value(GRAPHICS_SECTION, "render_fps_cap", RENDER_FPS_CAP_DEFAULT)
		changed = true
	if not config.has_section_key(GRAPHICS_SECTION, "vsync_mode"):
		config.set_value(GRAPHICS_SECTION, "vsync_mode", VSYNC_MODE_AUTO)
		changed = true
	if not config.has_section_key(GRAPHICS_SECTION, "auto_60hz_refresh_rate"):
		config.set_value(GRAPHICS_SECTION, "auto_60hz_refresh_rate", false)
		changed = true
	if bool(config.get_value(GRAPHICS_SECTION, "remember_display_mode", false)):
		var saved_display_mode := normalize_display_mode(str(config.get_value(
			GRAPHICS_SECTION,
			"display_mode",
			DISPLAY_MODE_WINDOWED
		)))
		if not config.has_section_key(GRAPHICS_SECTION, "display_mode") or saved_display_mode.is_empty():
			config.set_value(GRAPHICS_SECTION, "display_mode", DISPLAY_MODE_WINDOWED)
			changed = true
	return "repair_partial" if changed else ""


func has_payload(config: ConfigFile) -> bool:
	for key in GRAPHICS_KEYS:
		if config.has_section_key(GRAPHICS_SECTION, key):
			return true
	return false


func copy_payload(source: ConfigFile, target: ConfigFile) -> void:
	for key in GRAPHICS_KEYS:
		if source.has_section_key(GRAPHICS_SECTION, key):
			target.set_value(GRAPHICS_SECTION, key, source.get_value(GRAPHICS_SECTION, key))


static func normalize_display_mode(mode: String) -> String:
	var normalized := mode.strip_edges().to_lower()
	if normalized == DISPLAY_MODE_EXCLUSIVE_FULLSCREEN or normalized == "exclusive":
		return DISPLAY_MODE_EXCLUSIVE_FULLSCREEN
	if normalized == DISPLAY_MODE_FULLSCREEN:
		return DISPLAY_MODE_FULLSCREEN
	return DISPLAY_MODE_WINDOWED


static func normalize_render_fps_cap(cap: int) -> int:
	if cap == RENDER_FPS_CAP_STABLE_MONITOR:
		return RENDER_FPS_CAP_STABLE_MONITOR
	if cap == RENDER_FPS_CAP_MONITOR:
		return RENDER_FPS_CAP_MONITOR
	if cap <= 0:
		return RENDER_FPS_CAP_UNLIMITED
	return maxi(1, cap)


static func normalize_vsync_mode(mode: int) -> int:
	if mode == VSYNC_MODE_AUTO:
		return VSYNC_MODE_AUTO
	if mode == DisplayServer.VSYNC_DISABLED:
		return DisplayServer.VSYNC_DISABLED
	if mode == DisplayServer.VSYNC_MAILBOX:
		return DisplayServer.VSYNC_MAILBOX
	if mode == DisplayServer.VSYNC_ADAPTIVE:
		return DisplayServer.VSYNC_ADAPTIVE
	return DisplayServer.VSYNC_ENABLED


static func has_utf8_bom(bytes: PackedByteArray) -> bool:
	return bytes.size() >= 3 and bytes[0] == 0xEF and bytes[1] == 0xBB and bytes[2] == 0xBF
