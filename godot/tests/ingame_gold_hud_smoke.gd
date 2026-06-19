extends SceneTree

const PlazaSaveStore := preload("res://scripts/plaza/plaza_save_store.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const Stage1PillarHudSceneDrawer := preload("res://scripts/stages/stage1/stage1_pillar_hud_scene_drawer.gd")
const Stage1PillarUiRenderer := preload("res://scripts/hud/stage1_pillar_ui_renderer.gd")
const StageClearResultScreen := preload("res://scripts/core/stage_clear_result_screen.gd")

var _failures: Array[String] = []


class FakeRegistry:
	var runtime_perk_state: Object
	var stage_clear_result_screen: Object

	func _init(perk_state: Object, result_screen: Object) -> void:
		runtime_perk_state = perk_state
		stage_clear_result_screen = result_screen

	func get_instance(key: String) -> Object:
		match key:
			"runtime_perk_state":
				return runtime_perk_state
			"stage_clear_result_screen":
				return stage_clear_result_screen
		return null

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)


class FakeResultScreen:
	extends RefCounted

	var cached_summary: Dictionary = {}
	var load_summary: Dictionary = {}
	var load_calls := 0

	func get_cached_plaza_save_summary() -> Dictionary:
		return cached_summary.duplicate(true)

	func get_plaza_save_summary() -> Dictionary:
		load_calls += 1
		return load_summary.duplicate(true)


func _init() -> void:
	_verify_renderer_layout_contract()
	_verify_gold_amount_uses_wallet_plus_runtime()
	_verify_gold_amount_draw_path_uses_cached_summary_only()

	if _failures.is_empty():
		print("ingame_gold_hud_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_renderer_layout_contract() -> void:
	var renderer: Object = Stage1PillarUiRenderer.new()
	_expect(renderer.format_gold_amount(0) == "0", "gold HUD should format zero plainly")
	_expect(renderer.format_gold_amount(1500) == "1,500", "gold HUD should group thousands with commas")
	_expect(renderer.format_gold_amount(1234567) == "1,234,567", "gold HUD should format long wallet values")

	var fullscreen_rect: Rect2 = renderer.build_gold_hud_rect(
		Vector2(260.0, 60.0),
		Vector2(760.0, 750.0),
		{"height": 750.0, "gold_hud_amount": 1500}
	)
	_expect(fullscreen_rect.position.x < 260.0, "gold HUD should use the left letterbox when there is room")
	_expect(fullscreen_rect.position.y >= 60.0, "gold HUD should sit near the game top edge")
	_expect(fullscreen_rect.size.y >= 39.0, "gold HUD should keep the original 40px source-height feel")

	var window_rect: Rect2 = renderer.build_gold_hud_rect(
		Vector2.ZERO,
		Vector2(760.0, 750.0),
		{"height": 750.0, "gold_hud_amount": 1234567}
	)
	_expect(window_rect.position.x >= 0.0, "windowed gold HUD should stay visible inside the canvas")
	_expect(window_rect.end.x <= 760.0, "windowed gold HUD should not overflow the playfield width")


func _verify_gold_amount_uses_wallet_plus_runtime() -> void:
	var save_path := _build_save_path("wallet")
	_cleanup_save(save_path)

	var store: Object = PlazaSaveStore.new()
	store.set_save_path(save_path)
	store.apply_stage_clear_progress(1, 200, true)

	var result_screen: Object = StageClearResultScreen.new()
	result_screen.set_plaza_save_path_for_test(save_path)
	var perk_state: Object = RuntimePerkState.new()
	perk_state.award_gold(25)
	var registry := FakeRegistry.new(perk_state, result_screen)
	var drawer: Object = Stage1PillarHudSceneDrawer.new()

	drawer.sync_plaza_gold_cache({"current_stage": 2}, registry)
	var amount: int = int(drawer.call("_build_gold_hud_amount", {"current_stage": 2, "runtime_perk_gold": 25}, registry))
	_expect(amount == 225, "gold HUD should show plaza wallet gold plus the live owner runtime gold")

	store.perform_shop_wallet_transaction("purchase", 80, false)
	drawer.sync_plaza_gold_cache({"current_stage": 3}, registry)
	var reloaded_amount: int = int(drawer.call("_build_gold_hud_amount", {"current_stage": 3, "runtime_perk_gold": 0}, registry))
	_expect(reloaded_amount == 120, "gold HUD should reload saved wallet gold after a stage transition without reusing stale runtime state gold")

	_cleanup_save(save_path)


func _verify_gold_amount_draw_path_uses_cached_summary_only() -> void:
	var result_screen := FakeResultScreen.new()
	result_screen.cached_summary = {
		"save_path": "user://cached_gold_only.cfg",
		"plaza_gold": 300,
	}
	result_screen.load_summary = {
		"save_path": "user://cached_gold_only.cfg",
		"plaza_gold": 999,
	}
	var registry := FakeRegistry.new(null, result_screen)
	var drawer: Object = Stage1PillarHudSceneDrawer.new()

	var amount: int = int(drawer.call("_build_gold_hud_amount", {"current_stage": 2, "runtime_perk_gold": 25}, registry))
	_expect(amount == 325, "gold HUD draw path should consume cached plaza summary plus runtime gold")
	_expect(result_screen.load_calls == 0, "gold HUD draw path should not call the loading plaza summary API")

	result_screen.cached_summary = {}
	var runtime_only_amount: int = int(drawer.call("_build_gold_hud_amount", {"current_stage": 3, "runtime_perk_gold": 7}, registry))
	_expect(runtime_only_amount == 307, "gold HUD draw path should keep the last warmed wallet cache when no cached summary is available")
	_expect(result_screen.load_calls == 0, "gold HUD draw path should still avoid loading when cached summary is missing")


func _cleanup_save(path: String) -> void:
	var backup_path := path.trim_suffix(".cfg") + ".last_good.cfg"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path))


func _build_save_path(label: String) -> String:
	return "res://.tmp/ingame_gold_hud_smoke_%s_%d_%d.cfg" % [
		label,
		OS.get_process_id(),
		Time.get_ticks_usec(),
	]


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
