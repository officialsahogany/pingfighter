extends SceneTree

# Repeatable windowed pixel-QA harness for Mystic Dice D1/D2. Run without
# --headless so the SubViewport uses the real canvas renderer:
#   godot --path godot -s res://tools/mystic_dice_overlay_capture.gd

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const CharacterInfoOverlay := preload("res://scripts/hud/character_info_overlay.gd")
const CharacterInfoOverlayPerkPresenter := preload("res://scripts/hud/character_info_overlay_perk_presenter.gd")
const MysticDiceModalFlow := preload("res://scripts/characters/mystic_dice_modal_flow.gd")
const MysticDiceLocalization := preload("res://scripts/characters/mystic_dice_localization.gd")
const MysticDiceOverlayRenderer := preload("res://scripts/hud/mystic_dice_overlay_renderer.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const OUT_DIR := "d:/tmp/bosspong_ui_panel_capture/mystic_dice"


class DiceDrawer:
	extends Node2D

	var renderer: Object
	var modal_snapshot: Dictionary
	var dice_snapshot: Dictionary
	var view_size: Vector2

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.06, 0.10, 0.18))
		draw_circle(Vector2(view_size.x * 0.27, view_size.y * 0.52), minf(view_size.x, view_size.y) * 0.15, Color(0.25, 0.46, 0.72, 0.48))
		draw_rect(Rect2(0.0, view_size.y * 0.80, view_size.x, view_size.y * 0.20), Color(0.04, 0.07, 0.13))
		renderer.draw(self, modal_snapshot, dice_snapshot, view_size)


class TooltipDrawer:
	extends Node2D

	var overlay: Object
	var icon_renderer: Object
	var tooltip_data: Dictionary
	var view_size: Vector2

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.055, 0.085, 0.14))
		draw_circle(Vector2(view_size.x * 0.74, view_size.y * 0.34), minf(view_size.x, view_size.y) * 0.16, Color(0.38, 0.18, 0.64, 0.34))
		draw_rect(Rect2(18.0, 18.0, 76.0, 76.0), Color(0.05, 0.04, 0.12, 0.94))
		draw_rect(Rect2(18.0, 18.0, 76.0, 76.0), Color(0.40, 0.90, 1.0, 0.82), false, 2.0)
		icon_renderer.draw_icon(self, "mystic_dice", Rect2(22.0, 22.0, 68.0, 68.0), 1.0, true)
		overlay._draw_tooltip(self, tooltip_data, Vector2(24.0, view_size.y - 72.0), view_size, ThemeDB.fallback_font)


var _saved_capture_paths: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("mystic_dice_overlay_capture must run without --headless")
		LanguageSettings.set_test_locale_override("")
		quit(1)
		return
	# 비저장 override — 캡처 도구가 실 user:// 언어 설정을 저장 오염하면
	# 안 된다(v4 확립 규칙). 종료 시 해제.
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	# 증적 저장은 fail-closed: 디렉터리 생성 실패도 즉시 실패다(증적 없는
	# quit(0) 금지).
	var out_dir_error := DirAccess.make_dir_recursive_absolute(OUT_DIR)
	if out_dir_error != OK:
		push_error("MysticDiceCapture: output directory create failed (error=%d)" % out_dir_error)
		LanguageSettings.set_test_locale_override("")
		quit(1)
		return
	var renderer := MysticDiceOverlayRenderer.new()
	renderer.prewarm_assets()
	# D5 확정 밸런스(굴림 ±3 / 누적 ±9) 안의 대표 fixture — 이전 ±10
	# 수치는 이제 런타임에서 불가능해 픽셀 QA가 실제를 대표하지 못한다.
	var raw := {
		"player_speed": 3,
		"paddle_size": -3,
		"skill_gauge": 0,
		"dash_distance": 2,
		"dash_recovery": -3,
		"dash_cooldown": 3,
		"item_cooldown": -2,
	}
	var benefits := {
		"player_speed": 3,
		"paddle_size": -3,
		"skill_gauge": 0,
		"dash_distance": 2,
		"dash_recovery": 3,
		"dash_cooldown": -3,
		"item_cooldown": 2,
	}
	var dice_snapshot := {
		"permanent_raw": {
			"player_speed": 5,
			"paddle_size": -5,
			"skill_gauge": 9,
			"dash_distance": 0,
			"dash_recovery": -9,
			"dash_cooldown": 5,
			"item_cooldown": -5,
		},
	}
	var common := {
		"current_roll": {"raw": raw, "benefits": benefits},
		"roll_duration": MysticDiceModalFlow.ROLL_DURATION,
		"rerolls_remaining": 2,
		"selected_action": MysticDiceModalFlow.ACTION_CONFIRM,
	}
	var shots := [
		{"name": "d1_mid_roll", "size": Vector2i(760, 750), "phase": MysticDiceModalFlow.PHASE_ROLLING, "elapsed": 1.0},
		{"name": "d2_result", "size": Vector2i(760, 750), "phase": MysticDiceModalFlow.PHASE_RESULT, "elapsed": 0.0},
		{"name": "d2_hover_10s", "size": Vector2i(760, 750), "phase": MysticDiceModalFlow.PHASE_RESULT, "elapsed": 10.25},
		{"name": "d2_minimum", "size": Vector2i(300, 420), "phase": MysticDiceModalFlow.PHASE_RESULT, "elapsed": 10.25},
	]
	for shot_value: Variant in shots:
		var shot: Dictionary = shot_value as Dictionary
		var viewport := SubViewport.new()
		viewport.size = shot.get("size", Vector2i(760, 750))
		viewport.transparent_bg = false
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		get_root().add_child(viewport)
		var drawer := DiceDrawer.new()
		drawer.renderer = renderer
		drawer.modal_snapshot = common.duplicate(true)
		drawer.modal_snapshot["phase"] = str(shot.get("phase", ""))
		drawer.modal_snapshot["phase_elapsed"] = float(shot.get("elapsed", 0.0))
		drawer.dice_snapshot = dice_snapshot
		drawer.view_size = Vector2(viewport.size)
		viewport.add_child(drawer)
		drawer.queue_redraw()
		await process_frame
		await process_frame
		var image: Image = viewport.get_texture().get_image()
		var output_path := "%s/%s.png" % [OUT_DIR, str(shot.get("name", "shot"))]
		if not _save_capture_or_fail(image, output_path):
			LanguageSettings.set_test_locale_override("")
			quit(1)
			return
		get_root().remove_child(viewport)
		viewport.queue_free()
		await process_frame

	var state := RuntimePerkState.new()
	state.commit_mystic_dice_roll(raw)
	var catalog := RuntimePerkCatalog.new()
	var acquired: Array = CharacterInfoOverlayPerkPresenter.build_acquired_perks({}, catalog, null, state.get_snapshot())
	if acquired.is_empty():
		push_error("Mystic Dice tooltip capture could not build its projected entry")
		LanguageSettings.set_test_locale_override("")
		quit(1)
		return
	var dice_entry: Dictionary = acquired[0] as Dictionary
	var detail_body := str(dice_entry.get("detail", ""))
	var stat_entries: Array = CharacterInfoOverlayPerkPresenter.build_perk_stat_entries(str(dice_entry.get("description", "")), detail_body)
	var tooltip_data := {
		"title": str(dice_entry.get("name", "신비의 주사위")),
		"subtitle": "×%d" % int(dice_entry.get("_mystic_dice_use_count", 1)),
		"body": detail_body,
		"color": dice_entry.get("icon_color", Color(0.42, 0.82, 1.0)),
		"roll_options": stat_entries,
		"right_header": MysticDiceLocalization.text("accumulated_changes"),
		"tooltip_kind": "mystic_dice",
		"anchor_rect": Rect2(20.0, 490.0, 48.0, 48.0),
	}
	var icon_renderer := RuntimePerkIconRenderer.new()
	icon_renderer.prewarm_assets()
	for tooltip_size: Vector2i in [Vector2i(760, 750), Vector2i(420, 560)]:
		var viewport := SubViewport.new()
		viewport.size = tooltip_size
		viewport.transparent_bg = false
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		get_root().add_child(viewport)
		var drawer := TooltipDrawer.new()
		drawer.overlay = CharacterInfoOverlay.new()
		drawer.icon_renderer = icon_renderer
		drawer.tooltip_data = tooltip_data
		drawer.view_size = Vector2(tooltip_size)
		viewport.add_child(drawer)
		drawer.queue_redraw()
		await process_frame
		await process_frame
		var image: Image = viewport.get_texture().get_image()
		var output_path := "%s/tab_tooltip_%dx%d.png" % [OUT_DIR, tooltip_size.x, tooltip_size.y]
		if not _save_capture_or_fail(image, output_path):
			LanguageSettings.set_test_locale_override("")
			quit(1)
			return
		get_root().remove_child(viewport)
		viewport.queue_free()
		await process_frame
	# 기대 산출물 전수(D1/D2/hover/minimum 4샷 + 툴팁 2해상도 = 6파일)
	# fail-closed 검사 — 하나라도 빠지면 캡처 세트가 불완전하다.
	if _saved_capture_paths.size() != 6:
		push_error("MysticDiceCapture: expected 6 capture files, saved %d" % _saved_capture_paths.size())
		LanguageSettings.set_test_locale_override("")
		quit(1)
		return
	print("[MysticDiceCapture] complete: %d files" % _saved_capture_paths.size())
	LanguageSettings.set_test_locale_override("")
	quit(0)


# 저장 오류·파일 부재·빈 파일을 전부 실패로 취급하는 fail-closed 저장 헬퍼.
func _save_capture_or_fail(image: Image, output_path: String) -> bool:
	if image == null or image.is_empty():
		push_error("MysticDiceCapture: capture image is empty for %s" % output_path)
		return false
	var save_error := image.save_png(output_path)
	if save_error != OK:
		push_error("MysticDiceCapture: save failed for %s (error=%d)" % [output_path, save_error])
		return false
	if not FileAccess.file_exists(output_path):
		push_error("MysticDiceCapture: saved file missing on disk: %s" % output_path)
		return false
	if FileAccess.get_file_as_bytes(output_path).is_empty():
		push_error("MysticDiceCapture: saved file is empty on disk: %s" % output_path)
		return false
	_saved_capture_paths.append(output_path)
	print("[MysticDiceCapture] %s" % output_path)
	return true
