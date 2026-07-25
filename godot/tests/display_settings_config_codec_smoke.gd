extends SceneTree

const DisplaySettingsConfigCodec := preload("res://scripts/core/display_settings_config_codec.gd")
const SourceContractFunctionBody := preload("res://tests/source_contract_function_body.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_defaults_and_completion()
	_verify_schema_migrations()
	_verify_payload_copy_and_normalization()
	_verify_layout_boundary_contract()
	if _failures.is_empty():
		print("display_settings_config_codec_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_defaults_and_completion() -> void:
	var codec := DisplaySettingsConfigCodec.new()
	var defaults := ConfigFile.new()
	codec.set_default_payload(defaults)
	_expect(codec.has_payload(defaults), "default display settings should contain a graphics payload")
	_expect(not bool(defaults.get_value("graphics", "remember_display_mode", true)), "display mode should default to not remembered")
	_expect(int(defaults.get_value("graphics", "render_fps_cap", 0)) == DisplaySettingsConfigCodec.RENDER_FPS_CAP_STABLE_MONITOR, "render cap should default to stable monitor")
	_expect(int(defaults.get_value("graphics", "vsync_mode", 0)) == DisplaySettingsConfigCodec.VSYNC_MODE_AUTO, "VSync should default to auto")
	_expect(not bool(defaults.get_value("graphics", "auto_60hz_refresh_rate", true)), "automatic 60Hz switching should remain opt-in")
	_expect(int(defaults.get_value("meta", "settings_schema_version", 0)) == DisplaySettingsConfigCodec.SETTINGS_SCHEMA_VERSION, "defaults should stamp the current schema")

	var partial := ConfigFile.new()
	partial.set_value("graphics", "display_mode", DisplaySettingsConfigCodec.DISPLAY_MODE_FULLSCREEN)
	_expect(codec.complete_missing_payload(partial) == "repair_partial", "partial settings should report repair")
	_expect(bool(partial.get_value("graphics", "remember_display_mode", false)), "partial fullscreen settings should infer remembered display mode")
	_expect(int(partial.get_value("graphics", "render_fps_cap", 0)) == DisplaySettingsConfigCodec.RENDER_FPS_CAP_DEFAULT, "partial settings should fill render cap")
	_expect(codec.complete_missing_payload(partial).is_empty(), "complete settings should not report a second repair")


func _verify_schema_migrations() -> void:
	var codec := DisplaySettingsConfigCodec.new()
	var legacy := ConfigFile.new()
	legacy.set_value("graphics", "display_mode", DisplaySettingsConfigCodec.DISPLAY_MODE_EXCLUSIVE_FULLSCREEN)
	legacy.set_value("graphics", "render_fps_cap", DisplaySettingsConfigCodec.RENDER_FPS_CAP_BALANCED)
	legacy.set_value("graphics", "vsync_mode", DisplayServer.VSYNC_ENABLED)
	_expect(codec.migrate(legacy), "legacy settings should migrate")
	_expect(bool(legacy.get_value("graphics", "remember_display_mode", false)), "legacy fullscreen should become remembered")
	_expect(int(legacy.get_value("graphics", "render_fps_cap", 0)) == DisplaySettingsConfigCodec.RENDER_FPS_CAP_DEFAULT, "legacy materialized 72 cap should migrate to stable monitor")
	_expect(int(legacy.get_value("graphics", "vsync_mode", -99)) == DisplayServer.VSYNC_ENABLED, "migration should preserve explicit VSync")
	_expect(int(legacy.get_value("meta", "settings_schema_version", 0)) == DisplaySettingsConfigCodec.SETTINGS_SCHEMA_VERSION, "migration should stamp the current schema")
	_expect(not codec.migrate(legacy), "current-schema settings should not migrate twice")

	var schema_four := ConfigFile.new()
	schema_four.set_value("meta", "settings_schema_version", 4)
	schema_four.set_value("graphics", "render_fps_cap", DisplaySettingsConfigCodec.RENDER_FPS_CAP_MONITOR)
	_expect(codec.migrate(schema_four), "schema-four settings should migrate")
	_expect(int(schema_four.get_value("graphics", "render_fps_cap", 0)) == DisplaySettingsConfigCodec.RENDER_FPS_CAP_DEFAULT, "schema-four monitor sentinel should migrate to stable monitor")


func _verify_payload_copy_and_normalization() -> void:
	var codec := DisplaySettingsConfigCodec.new()
	var source := ConfigFile.new()
	source.set_value("graphics", "remember_display_mode", true)
	source.set_value("graphics", "display_mode", "exclusive_fullscreen")
	source.set_value("graphics", "render_fps_cap", 48)
	source.set_value("meta", "settings_schema_version", 3)
	var target := ConfigFile.new()
	codec.copy_payload(source, target)
	_expect(str(target.get_value("graphics", "display_mode", "")) == "exclusive_fullscreen", "payload copy should preserve graphics values")
	_expect(not target.has_section("meta"), "payload copy should not copy source schema metadata")
	_expect(DisplaySettingsConfigCodec.normalize_display_mode(" EXCLUSIVE ") == DisplaySettingsConfigCodec.DISPLAY_MODE_EXCLUSIVE_FULLSCREEN, "display mode normalization should preserve the exclusive alias")
	_expect(DisplaySettingsConfigCodec.normalize_display_mode("unknown") == DisplaySettingsConfigCodec.DISPLAY_MODE_WINDOWED, "unknown display mode should fall back to windowed")
	_expect(DisplaySettingsConfigCodec.normalize_render_fps_cap(-99) == DisplaySettingsConfigCodec.RENDER_FPS_CAP_UNLIMITED, "unknown negative render cap should normalize to unlimited")
	_expect(DisplaySettingsConfigCodec.normalize_vsync_mode(999) == DisplayServer.VSYNC_ENABLED, "unknown VSync mode should normalize to enabled")
	var bom := PackedByteArray([0xEF, 0xBB, 0xBF, 0x5B])
	_expect(DisplaySettingsConfigCodec.has_utf8_bom(bom), "codec should recognize a UTF-8 BOM")
	_expect(not DisplaySettingsConfigCodec.has_utf8_bom(PackedByteArray([0xEF, 0xBB])), "short byte payload should not be a BOM")


func _verify_layout_boundary_contract() -> void:
	var layout_source := FileAccess.get_file_as_string("res://scripts/core/battle_view_layout.gd")
	var codec_source := FileAccess.get_file_as_string("res://scripts/core/display_settings_config_codec.gd")
	_expect(layout_source.find("var _display_settings_codec: DisplaySettingsConfigCodec") >= 0, "battle view layout should keep one typed settings codec")
	_expect(_function_body(layout_source, "func _migrate_display_settings(").find("_display_settings_codec.migrate") >= 0, "layout migration facade should delegate to the codec")
	_expect(_function_body(layout_source, "func _complete_missing_display_settings(").find("_display_settings_codec.complete_missing_payload") >= 0, "layout completion facade should delegate to the codec")
	for facade in [
		["func _stamp_display_settings_schema(", "_display_settings_codec.stamp_schema"],
		["func _set_default_display_settings_payload(", "_display_settings_codec.set_default_payload"],
		["func _has_display_settings_payload(", "_display_settings_codec.has_payload"],
		["func _copy_display_settings_payload(", "_display_settings_codec.copy_payload"],
		["func _normalize_display_mode(", "DisplaySettingsConfigCodec.normalize_display_mode"],
		["func _normalize_render_fps_cap(", "DisplaySettingsConfigCodec.normalize_render_fps_cap"],
		["func _normalize_vsync_mode(", "DisplaySettingsConfigCodec.normalize_vsync_mode"],
	]:
		_expect(_function_body(layout_source, str(facade[0])).find(str(facade[1])) >= 0, "layout facade should delegate to codec: %s" % str(facade[0]))
	_expect(layout_source.find("if version < 2") == -1 and layout_source.find("if version < 5") == -1, "battle view layout should not retain schema-version transition formulas")
	var load_body := _function_body(layout_source, "func _load_config_file(")
	_expect(load_body.find("FileAccess.get_file_as_bytes") >= 0 and load_body.find("config.parse(clean_text)") >= 0, "battle view layout should retain raw-byte BOM rewrite I/O")
	var repair_body := _function_body(layout_source, "func _repair_empty_display_settings_payload(")
	_expect(repair_body.find("_get_settings_backup_path()") >= 0 and repair_body.find("backup_config.load") >= 0, "battle view layout should retain last-good file recovery")
	_expect(codec_source.find("FileAccess") < 0 and codec_source.find("DirAccess") < 0, "display settings codec should stay independent of filesystem I/O")


func _function_body(source: String, signature: String) -> String:
	return SourceContractFunctionBody.extract(source, signature)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
