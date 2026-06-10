extends SceneTree

const BattleViewLayout := preload("res://scripts/core/battle_view_layout.gd")
const BattleRenderQuality := preload("res://scripts/core/battle_render_quality.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const ViperAirborneLod := preload("res://scripts/core/viper_airborne_lod.gd")
const SETTINGS_PATH := "user://display_settings.cfg"
const SETTINGS_BACKUP_PATH := "user://display_settings.last_good.cfg"

var _failures: Array[String] = []


func _init() -> void:
	var original_cap: int = int(Engine.get("max_fps"))
	var original_physics_ticks: int = int(Engine.physics_ticks_per_second)
	var original_vsync_mode: int = int(DisplayServer.window_get_vsync_mode())
	_verify_render_fps_cap_runtime_options()
	_verify_legacy_display_settings_migrate_without_losing_explicit_choices()
	_verify_materialized_monitor_default_migrates_to_stable_monitor()
	_verify_non_windowed_display_save_forces_remember()
	_verify_auto_refresh_setting_persists_and_repairs_as_opt_in()
	_verify_utf8_bom_settings_load_without_losing_graphics()
	_verify_schema_only_settings_repair_from_last_good_backup()
	_verify_high_refresh_render_quality_lod()
	_verify_vsync_runtime_options()
	_verify_display_pacing_recommendation_helpers()
	_verify_configure_window_applies_pacing_after_display_mode()
	Engine.set("max_fps", original_cap)
	Engine.physics_ticks_per_second = original_physics_ticks
	DisplayServer.window_set_vsync_mode(original_vsync_mode)

	if _failures.is_empty():
		print("render_fps_cap_settings_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_render_fps_cap_runtime_options() -> void:
	var snapshot := _snapshot_display_settings_files()
	_clear_display_settings_files()

	var layout: Object = BattleViewLayout.new()
	var project_physics_ticks: int = clampi(
		int(ProjectSettings.get_setting(BattleViewLayout.PHYSICS_TICKS_SETTING, BattleViewLayout.PHYSICS_TICKS_PROJECT_DEFAULT)),
		BattleViewLayout.PHYSICS_TICKS_SYNC_MIN,
		BattleViewLayout.PHYSICS_TICKS_SYNC_MAX
	)
	var options: Array[int] = layout.get_render_fps_cap_options()
	_expect(options == [0, 48, 60, 72, -2, -1], "render FPS cap options should stay unlimited, 48, 60, 72, stable monitor, monitor")
	_expect(
		int(layout.get_saved_render_fps_cap()) == BattleViewLayout.RENDER_FPS_CAP_STABLE_MONITOR,
		"missing display settings should default render FPS to the stable monitor cap"
	)
	_expect(FileAccess.file_exists(SETTINGS_PATH), "missing display settings should be materialized with default graphics values")
	var default_config := ConfigFile.new()
	default_config.load(SETTINGS_PATH)
	_expect(
		int(default_config.get_value("meta", "settings_schema_version", 0)) >= BattleViewLayout.SETTINGS_SCHEMA_VERSION,
		"materialized default display settings should stamp the current schema"
	)
	_expect(
		int(default_config.get_value("graphics", "render_fps_cap", 0)) == BattleViewLayout.RENDER_FPS_CAP_STABLE_MONITOR,
		"materialized default display settings should persist stable monitor render pacing"
	)

	_expect(int(layout.apply_render_fps_cap(null, 0)) == 0, "unlimited cap should normalize to zero")
	_expect(int(Engine.get("max_fps")) == 0, "unlimited cap should clear Engine.max_fps")
	_expect(int(Engine.physics_ticks_per_second) == project_physics_ticks, "unlimited cap should restore the project physics tick rate")

	_expect(int(layout.apply_render_fps_cap(null, 48)) == 48, "48 FPS cap should normalize to 48")
	_expect(int(Engine.get("max_fps")) == 48, "48 FPS cap should apply to Engine.max_fps")
	_expect(int(Engine.physics_ticks_per_second) == project_physics_ticks, "48 FPS stability cap should keep the project physics tick rate")

	_expect(int(layout.apply_render_fps_cap(null, 72)) == 72, "72 FPS cap should normalize to 72")
	_expect(
		int(Engine.get("max_fps")) == 72,
		"72 FPS cap should apply a strict Engine.max_fps target"
	)
	_expect(int(Engine.physics_ticks_per_second) == 72, "72 FPS cap should sync the physics tick rate to 72")
	_expect(int(layout.apply_render_fps_cap(null, 72, DisplayServer.VSYNC_DISABLED)) == 72, "72 FPS cap should normalize with VSync Off")
	_expect(int(Engine.get("max_fps")) == 72, "72 FPS cap should use strict Engine.max_fps when VSync Off is selected")
	_expect(int(Engine.physics_ticks_per_second) == 72, "strict 72 FPS cap should keep physics at 72")

	_expect(int(layout.apply_render_fps_cap(null, 60)) == 60, "60 FPS cap should normalize to 60")
	_expect(int(Engine.get("max_fps")) == 60, "60 FPS cap should apply to Engine.max_fps")
	_expect(int(Engine.physics_ticks_per_second) == 60, "60 FPS cap should sync the physics tick rate to 60")

	# NOTE (risk, 2026-06-10): Stable Monitor deliberately syncs the physics tick
	# rate to its resolved render cap (assert below), so the shipped 144Hz default
	# resolves to render 48 / physics 48 — NOT the original "48 stable preset"
	# render 48 / physics 72 decoupling (the old Monitor default ran 144/72 here).
	# Coarser physics → watch fast-ball tunneling at paddle edge / holy-barrier
	# band on >120Hz hardware. If tunneling shows up in play, the minimal follow-up
	# is to make STABLE_MONITOR fall back to the project physics default (72) in
	# _resolve_physics_ticks_per_second() and flip the assert below. Keep this
	# contract until that decision is made.
	_expect(int(layout.apply_render_fps_cap(null, -2)) == -2, "stable monitor cap should keep the stable sentinel in settings")
	var stable_cap: int = int(Engine.get("max_fps"))
	_expect(stable_cap >= 45 and stable_cap <= 90, "stable monitor cap should apply a playable refresh divisor")
	_expect(stable_cap != 0, "stable monitor cap should not resolve to unlimited")
	_expect(int(Engine.physics_ticks_per_second) == stable_cap, "stable monitor cap should sync physics to its resolved cap")
	_expect(str(layout.get_render_fps_cap_label(-2, null)).begins_with("Stable "), "stable monitor label should expose the resolved stable cap")

	_expect(int(layout.apply_render_fps_cap(null, -1)) == -1, "monitor cap should keep the monitor sentinel in settings")
	var monitor_cap: int = int(Engine.get("max_fps"))
	_expect(monitor_cap >= 30, "monitor cap should apply a positive monitor-rate Engine.max_fps")
	if monitor_cap <= BattleViewLayout.PHYSICS_TICKS_SYNC_MAX:
		_expect(int(Engine.physics_ticks_per_second) == monitor_cap, "monitor cap should sync physics to the monitor rate when it is in the safe tick range")
	else:
		_expect(int(Engine.physics_ticks_per_second) == project_physics_ticks, "monitor cap should keep project physics when the monitor rate is above the safe tick range")
	_expect(str(layout.get_render_fps_cap_label(-1, null)).ends_with("Hz"), "monitor cap label should expose a refresh-rate value")

	_restore_display_settings_files(snapshot)


func _verify_legacy_display_settings_migrate_without_losing_explicit_choices() -> void:
	var snapshot := _snapshot_display_settings_files()

	var legacy_config := ConfigFile.new()
	legacy_config.set_value("graphics", "display_mode", "exclusive_fullscreen")
	legacy_config.set_value("graphics", "render_fps_cap", 72)
	legacy_config.set_value("graphics", "vsync_mode", DisplayServer.VSYNC_ENABLED)
	legacy_config.save(SETTINGS_PATH)

	var layout: Object = BattleViewLayout.new()
	_expect(int(layout.get_saved_render_fps_cap()) == BattleViewLayout.RENDER_FPS_CAP_STABLE_MONITOR, "legacy saved 72 FPS cap should migrate to the stable monitor default")
	_expect(bool(layout.get_remember_display_mode()), "legacy explicit fullscreen display mode should imply remembered display mode")
	_expect(
		int(layout.get_saved_vsync_mode()) == DisplayServer.VSYNC_ENABLED,
		"legacy explicit VSync On should remain VSync On instead of migrating to Auto"
	)

	var migrated_config := ConfigFile.new()
	migrated_config.load(SETTINGS_PATH)
	_expect(
		int(migrated_config.get_value("meta", "settings_schema_version", 0)) >= 2,
		"display settings migration should stamp the schema version"
	)
	_expect(
		int(migrated_config.get_value("graphics", "render_fps_cap", 0)) == BattleViewLayout.RENDER_FPS_CAP_STABLE_MONITOR,
		"display settings migration should rewrite legacy saved 72 FPS to the stable monitor sentinel"
	)
	_expect(
		bool(migrated_config.get_value("graphics", "remember_display_mode", false)),
		"display settings migration should preserve explicit fullscreen as a remembered display choice"
	)
	_expect(
		int(migrated_config.get_value("graphics", "vsync_mode", DisplayServer.VSYNC_DISABLED)) == DisplayServer.VSYNC_ENABLED,
		"display settings migration should preserve explicit VSync On"
	)
	_expect(
		not bool(migrated_config.get_value("graphics", "auto_60hz_refresh_rate", true)),
		"display settings migration should keep automatic 60Hz switching opt-in"
	)

	_restore_display_settings_files(snapshot)


func _verify_materialized_monitor_default_migrates_to_stable_monitor() -> void:
	var snapshot := _snapshot_display_settings_files()

	var materialized_monitor_config := ConfigFile.new()
	materialized_monitor_config.set_value("graphics", "remember_display_mode", false)
	materialized_monitor_config.set_value("graphics", "display_mode", "windowed")
	materialized_monitor_config.set_value("graphics", "render_fps_cap", BattleViewLayout.RENDER_FPS_CAP_MONITOR)
	materialized_monitor_config.set_value("graphics", "vsync_mode", BattleViewLayout.VSYNC_MODE_AUTO)
	materialized_monitor_config.set_value("graphics", "auto_60hz_refresh_rate", false)
	materialized_monitor_config.set_value("meta", "settings_schema_version", 4)
	materialized_monitor_config.save(SETTINGS_PATH)

	var layout: Object = BattleViewLayout.new()
	_expect(
		int(layout.get_saved_render_fps_cap()) == BattleViewLayout.RENDER_FPS_CAP_STABLE_MONITOR,
		"schema 4 materialized monitor default should migrate to stable monitor"
	)

	var migrated_config := ConfigFile.new()
	migrated_config.load(SETTINGS_PATH)
	_expect(
		int(migrated_config.get_value("meta", "settings_schema_version", 0)) >= BattleViewLayout.SETTINGS_SCHEMA_VERSION,
		"materialized monitor default migration should stamp schema 5"
	)
	_expect(
		int(migrated_config.get_value("graphics", "render_fps_cap", 0)) == BattleViewLayout.RENDER_FPS_CAP_STABLE_MONITOR,
		"materialized monitor default migration should persist stable monitor"
	)

	_restore_display_settings_files(snapshot)


func _verify_non_windowed_display_save_forces_remember() -> void:
	var snapshot := _snapshot_display_settings_files()

	var layout: Object = BattleViewLayout.new()
	_expect(layout.save_display_mode_default("exclusive_fullscreen", false), "exclusive fullscreen display save should succeed")

	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	_expect(
		bool(config.get_value("graphics", "remember_display_mode", false)),
		"exclusive fullscreen display save should force remember_display_mode on"
	)
	_expect(
		str(config.get_value("graphics", "display_mode", "")) == "exclusive_fullscreen",
		"exclusive fullscreen display save should persist the non-windowed display mode"
	)

	_restore_display_settings_files(snapshot)


func _verify_auto_refresh_setting_persists_and_repairs_as_opt_in() -> void:
	var snapshot := _snapshot_display_settings_files()
	_clear_display_settings_files()

	var layout: Object = BattleViewLayout.new()
	_expect(not bool(layout.get_auto_refresh_rate_enabled()), "automatic 60Hz switching should default off")
	_expect(layout.save_auto_refresh_rate_default(true, null), "automatic 60Hz preference save should succeed")
	_expect(bool(layout.get_auto_refresh_rate_enabled()), "automatic 60Hz preference should load when saved")

	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	_expect(
		bool(config.get_value("graphics", "auto_60hz_refresh_rate", false)),
		"automatic 60Hz preference should persist in display settings"
	)
	_expect(
		int(config.get_value("meta", "settings_schema_version", 0)) >= 4,
		"automatic 60Hz preference should stamp the display settings schema"
	)

	_restore_display_settings_files(snapshot)


func _verify_utf8_bom_settings_load_without_losing_graphics() -> void:
	var snapshot := _snapshot_display_settings_files()

	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_8(0xEF)
		file.store_8(0xBB)
		file.store_8(0xBF)
		file.store_string("[graphics]\n\n")
		file.store_string("remember_display_mode=true\n")
		file.store_string("display_mode=\"exclusive_fullscreen\"\n")
		file.store_string("render_fps_cap=48\n")
		file.store_string("vsync_mode=%d\n\n" % DisplayServer.VSYNC_ENABLED)
		file.store_string("[meta]\n\nsettings_schema_version=3\n")
		file.close()

	var layout: Object = BattleViewLayout.new()
	_expect(
		str(layout.get_saved_display_mode()) == "exclusive_fullscreen",
		"UTF-8 BOM display settings should still load the graphics display mode"
	)
	_expect(
		bool(layout.get_remember_display_mode()),
		"UTF-8 BOM display settings should still load remember_display_mode"
	)
	_expect(
		int(layout.get_saved_render_fps_cap()) == 48,
		"UTF-8 BOM display settings should still load render FPS cap"
	)
	_expect(
		int(layout.get_saved_vsync_mode()) == DisplayServer.VSYNC_ENABLED,
		"UTF-8 BOM display settings should still load VSync mode"
	)

	var cleaned_bytes := FileAccess.get_file_as_bytes(SETTINGS_PATH)
	var has_bom := cleaned_bytes.size() >= 3 and cleaned_bytes[0] == 0xEF and cleaned_bytes[1] == 0xBB and cleaned_bytes[2] == 0xBF
	_expect(not has_bom, "UTF-8 BOM display settings should be rewritten without the leading BOM")

	_restore_display_settings_files(snapshot)


func _verify_schema_only_settings_repair_from_last_good_backup() -> void:
	var snapshot := _snapshot_display_settings_files()

	var backup_config := ConfigFile.new()
	backup_config.set_value("graphics", "remember_display_mode", true)
	backup_config.set_value("graphics", "display_mode", "exclusive_fullscreen")
	backup_config.set_value("graphics", "render_fps_cap", 48)
	backup_config.set_value("graphics", "vsync_mode", DisplayServer.VSYNC_ENABLED)
	backup_config.set_value("meta", "settings_schema_version", 3)
	backup_config.save(SETTINGS_BACKUP_PATH)

	var broken_config := ConfigFile.new()
	broken_config.set_value("meta", "settings_schema_version", 3)
	broken_config.save(SETTINGS_PATH)

	var layout: Object = BattleViewLayout.new()
	_expect(
		str(layout.get_saved_display_mode()) == "exclusive_fullscreen",
		"schema-only display settings should restore the saved display mode from last_good backup"
	)
	_expect(
		bool(layout.get_remember_display_mode()),
		"schema-only display settings should restore remember_display_mode from last_good backup"
	)
	_expect(
		int(layout.get_saved_render_fps_cap()) == 48,
		"schema-only display settings should restore render FPS cap from last_good backup"
	)
	_expect(
		int(layout.get_saved_vsync_mode()) == DisplayServer.VSYNC_ENABLED,
		"schema-only display settings should restore VSync mode from last_good backup"
	)

	var repaired_config := ConfigFile.new()
	repaired_config.load(SETTINGS_PATH)
	_expect(
		str(repaired_config.get_value("graphics", "display_mode", "")) == "exclusive_fullscreen",
		"schema-only repair should write the restored display mode back to the main settings file"
	)

	_restore_display_settings_files(snapshot)


func _snapshot_display_settings_files() -> Dictionary:
	return {
		"main": _snapshot_settings_file(SETTINGS_PATH),
		"backup": _snapshot_settings_file(SETTINGS_BACKUP_PATH),
	}


func _snapshot_settings_file(path: String) -> Dictionary:
	var had_original := FileAccess.file_exists(path)
	var original_bytes := PackedByteArray()
	if had_original:
		original_bytes = FileAccess.get_file_as_bytes(path)
	return {
		"had": had_original,
		"bytes": original_bytes,
	}


func _restore_display_settings_files(snapshot: Dictionary) -> void:
	var main_snapshot: Dictionary = snapshot.get("main", {})
	var backup_snapshot: Dictionary = snapshot.get("backup", {})
	_restore_settings_file(SETTINGS_PATH, bool(main_snapshot.get("had", false)), main_snapshot.get("bytes", PackedByteArray()))
	_restore_settings_file(SETTINGS_BACKUP_PATH, bool(backup_snapshot.get("had", false)), backup_snapshot.get("bytes", PackedByteArray()))


func _clear_display_settings_files() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_BACKUP_PATH))


func _restore_settings_file(path: String, had_file: bool, file_bytes: PackedByteArray) -> void:
	if had_file:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_buffer(file_bytes)
			file.close()
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _verify_vsync_runtime_options() -> void:
	var layout: Object = BattleViewLayout.new()
	var options: Array[int] = layout.get_vsync_mode_options()
	_expect(options == [-1, DisplayServer.VSYNC_ENABLED, DisplayServer.VSYNC_MAILBOX, DisplayServer.VSYNC_DISABLED], "vsync options should stay auto, enabled, mailbox, disabled")

	layout.apply_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var can_switch_vsync_mode: bool = int(DisplayServer.window_get_vsync_mode()) == DisplayServer.VSYNC_DISABLED

	Engine.set("max_fps", 48)
	_expect(int(layout.apply_vsync_mode(-1)) == -1, "auto vsync mode should keep the configured auto sentinel")
	if can_switch_vsync_mode:
		_expect(
			int(DisplayServer.window_get_vsync_mode()) == DisplayServer.VSYNC_DISABLED,
			"auto vsync should disable DisplayServer vsync when a fixed below-monitor FPS cap is active"
		)

	layout.apply_render_fps_cap(null, 72)
	_expect(int(layout.apply_vsync_mode(-1)) == -1, "auto vsync mode should stay configurable with strict 72 FPS cap")
	var strict_72_below_monitor := 72 < _get_test_monitor_refresh_rate()
	if can_switch_vsync_mode and strict_72_below_monitor:
		_expect(
			int(DisplayServer.window_get_vsync_mode()) == DisplayServer.VSYNC_DISABLED,
			"auto vsync should disable DisplayServer vsync when strict 72 FPS cap is active below monitor rate"
		)
	elif can_switch_vsync_mode:
		_expect(
			int(DisplayServer.window_get_vsync_mode()) == DisplayServer.VSYNC_ENABLED,
			"auto vsync should use DisplayServer vsync when strict 72 FPS is not below monitor rate"
		)

	layout.apply_render_fps_cap(null, 0)
	Engine.set("max_fps", 0)
	_expect(int(layout.apply_vsync_mode(-1)) == -1, "auto vsync mode should stay configurable with unlimited cap")
	if can_switch_vsync_mode:
		_expect(
			int(DisplayServer.window_get_vsync_mode()) == DisplayServer.VSYNC_ENABLED,
			"auto vsync should use DisplayServer vsync when no lower engine FPS cap is active"
		)

	_expect(int(layout.apply_vsync_mode(DisplayServer.VSYNC_DISABLED)) == DisplayServer.VSYNC_DISABLED, "disabled vsync mode should normalize")

	_expect(int(layout.apply_vsync_mode(DisplayServer.VSYNC_ENABLED)) == DisplayServer.VSYNC_ENABLED, "enabled vsync mode should normalize")
	if can_switch_vsync_mode:
		_expect(
			int(DisplayServer.window_get_vsync_mode()) == DisplayServer.VSYNC_ENABLED,
			"explicit VSync On should apply even when a fixed below-monitor FPS cap is active"
		)

	_expect(int(layout.apply_vsync_mode(DisplayServer.VSYNC_MAILBOX)) == DisplayServer.VSYNC_MAILBOX, "mailbox vsync mode should normalize")

	_expect(str(layout.get_vsync_mode_label(-1)) == "Auto", "auto vsync label should be explicit")
	_expect(str(layout.get_vsync_mode_label(DisplayServer.VSYNC_DISABLED)) == "VSync Off", "disabled vsync label should be explicit")
	_expect(str(layout.get_vsync_mode_label(DisplayServer.VSYNC_ADAPTIVE)) == "Adaptive", "adaptive vsync label should be explicit")
	_expect(str(layout.get_vsync_mode_label(DisplayServer.VSYNC_MAILBOX)) == "Mailbox", "mailbox vsync label should be explicit")


func _verify_display_pacing_recommendation_helpers() -> void:
	var layout: Object = BattleViewLayout.new()
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)
	var monitor_rate: int = int(layout.get_monitor_refresh_rate(null))
	_expect(monitor_rate >= 30, "monitor refresh helper should expose a safe positive refresh rate")
	_expect(
		bool(layout.is_high_refresh_monitor(null)) == (monitor_rate >= BattleViewLayout.HIGH_REFRESH_RECOMMENDATION_MIN_HZ),
		"high-refresh helper should match the recommendation threshold"
	)
	layout.apply_render_fps_cap(null, BattleViewLayout.RENDER_FPS_CAP_STABLE_MONITOR, BattleViewLayout.VSYNC_MODE_AUTO)
	var stable_cap: int = int(Engine.get("max_fps"))
	var recommendation := str(layout.get_display_pacing_recommendation(
		null,
		BattleViewLayout.DISPLAY_MODE_EXCLUSIVE_FULLSCREEN,
		BattleViewLayout.RENDER_FPS_CAP_STABLE_MONITOR,
		BattleViewLayout.VSYNC_MODE_AUTO
	))
	_expect(recommendation.find(str(monitor_rate)) >= 0, "display pacing recommendation should mention the detected monitor refresh rate")
	_expect(recommendation.find(str(stable_cap)) >= 0, "display pacing recommendation should mention the resolved stable cap")
	_expect(recommendation.find("안정") >= 0, "display pacing recommendation should describe stable monitor pacing")


	_verify_spanish_display_pacing_text(layout)
	_verify_portuguese_brazil_display_pacing_text(layout)
	_verify_russian_display_pacing_text(layout)


func _verify_spanish_display_pacing_text(layout: Object) -> void:
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_SPANISH)
	_expect(str(layout.get_render_fps_cap_label(BattleViewLayout.RENDER_FPS_CAP_MONITOR, null)).begins_with("Monitor "), "monitor cap label should localize to Spanish")
	var spanish_recommendation := str(layout.get_display_pacing_recommendation(
		null,
		BattleViewLayout.DISPLAY_MODE_EXCLUSIVE_FULLSCREEN,
		BattleViewLayout.RENDER_FPS_CAP_MONITOR,
		BattleViewLayout.VSYNC_MODE_AUTO
	))
	_expect(spanish_recommendation.find("FPS de render") >= 0, "display pacing recommendation should localize to Spanish")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)


func _verify_portuguese_brazil_display_pacing_text(layout: Object) -> void:
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL)
	_expect(str(layout.get_render_fps_cap_label(BattleViewLayout.RENDER_FPS_CAP_MONITOR, null)).begins_with("Monitor "), "monitor cap label should localize to Brazilian Portuguese")
	var portuguese_recommendation := str(layout.get_display_pacing_recommendation(
		null,
		BattleViewLayout.DISPLAY_MODE_EXCLUSIVE_FULLSCREEN,
		BattleViewLayout.RENDER_FPS_CAP_MONITOR,
		BattleViewLayout.VSYNC_MODE_AUTO
	))
	_expect(portuguese_recommendation.find("FPS de renderização") >= 0, "display pacing recommendation should localize to Brazilian Portuguese")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)


func _verify_russian_display_pacing_text(layout: Object) -> void:
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_RUSSIAN)
	_expect(str(layout.get_render_fps_cap_label(BattleViewLayout.RENDER_FPS_CAP_MONITOR, null)).begins_with("Монитор "), "monitor cap label should localize to Russian")
	var russian_recommendation := str(layout.get_display_pacing_recommendation(
		null,
		BattleViewLayout.DISPLAY_MODE_EXCLUSIVE_FULLSCREEN,
		BattleViewLayout.RENDER_FPS_CAP_MONITOR,
		BattleViewLayout.VSYNC_MODE_AUTO
	))
	_expect(russian_recommendation.find("FPS рендера") >= 0, "display pacing recommendation should localize to Russian")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)


func _verify_high_refresh_render_quality_lod() -> void:
	var snapshot := _snapshot_display_settings_files()

	var layout: Object = BattleViewLayout.new()
	layout.save_render_fps_cap_default(0)

	Engine.set("max_fps", 144)
	BattleRenderQuality.reset_cache_for_test()
	_expect(BattleRenderQuality.is_high_refresh_lod_active(), "144 FPS target should enable high-refresh render-quality LOD")
	_expect(
		BattleRenderQuality.HIGH_REFRESH_EFFECT_SCALE < 0.66,
		"144 FPS target should enter the stricter severe render-quality tier"
	)
	_expect(
		is_equal_approx(BattleRenderQuality.effect_scale({"selected_character_type": "smasher"}), BattleRenderQuality.HIGH_REFRESH_EFFECT_SCALE),
		"non-Viper 144 FPS target should use high-refresh render-quality LOD"
	)

	Engine.set("max_fps", 72)
	BattleRenderQuality.reset_cache_for_test()
	_expect(BattleRenderQuality.is_fps_cap_lod_active(), "72 FPS target should keep capped-frame render-quality LOD")
	_expect(
		BattleRenderQuality.FPS_CAP_EFFECT_SCALE <= BattleRenderQuality.HIGH_REFRESH_EFFECT_SCALE,
		"72 FPS target should use the strict high-refresh render-quality tier"
	)
	_expect(
		is_equal_approx(BattleRenderQuality.effect_scale({"selected_character_type": "smasher"}), BattleRenderQuality.FPS_CAP_EFFECT_SCALE),
		"72 FPS target should keep the capped-frame render-quality scale"
	)

	Engine.set("max_fps", 0)
	BattleRenderQuality.reset_cache_for_test()
	_expect(not BattleRenderQuality.is_high_refresh_lod_active(), "unlimited cap should not imply the high-refresh render-quality target")
	_expect(
		is_equal_approx(BattleRenderQuality.effect_scale({"selected_character_type": "smasher"}), 1.0),
		"unlimited cap should leave non-Viper render quality at full scale"
	)

	layout.save_render_fps_cap_default(72)
	layout.apply_render_fps_cap(null, 72)
	BattleRenderQuality.reset_cache_for_test()
	ViperAirborneLod.reset_cache_for_test()
	_expect(
		BattleRenderQuality.is_fps_cap_lod_active(),
		"saved 72 FPS target should keep capped-frame render-quality LOD with strict Engine.max_fps"
	)
	_expect(
		is_equal_approx(BattleRenderQuality.effect_scale({"selected_character_type": "smasher"}), BattleRenderQuality.FPS_CAP_EFFECT_SCALE),
		"saved 72 FPS target should keep the capped-frame render-quality scale"
	)
	_expect(
		ViperAirborneLod.is_fps_cap_lod_active({"selected_character_type": "viper"}),
		"saved 72 FPS target should keep Viper capped-frame LOD with strict Engine.max_fps"
	)

	_restore_display_settings_files(snapshot)


func _get_test_monitor_refresh_rate() -> int:
	var refresh_rate: float = DisplayServer.screen_get_refresh_rate(DisplayServer.SCREEN_OF_MAIN_WINDOW)
	if refresh_rate <= 0.0:
		refresh_rate = 60.0
	return max(30, int(round(refresh_rate)))


func _verify_configure_window_applies_pacing_after_display_mode() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/core/battle_view_layout.gd")
	var body := _function_body(source, "func configure_window")
	var display_index := body.find("apply_display_mode(window, saved_display_mode)")
	var cap_index := body.find("apply_render_fps_cap(window, saved_render_cap, saved_vsync_mode)")
	var vsync_index := body.find("apply_vsync_mode(saved_vsync_mode, window)")
	_expect(display_index >= 0, "configure_window should honor the saved display mode")
	_expect(cap_index > display_index, "configure_window should apply the render cap after display mode changes")
	_expect(vsync_index > display_index, "configure_window should apply VSync after display mode changes")


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next_func := source.find("\nfunc ", start + signature.length())
	if next_func < 0:
		return source.substr(start)
	return source.substr(start, next_func - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
