extends SceneTree

const Stage1PillarHudSceneDrawer := preload("res://scripts/stages/stage1/stage1_pillar_hud_scene_drawer.gd")

var _failures: Array[String] = []


class FakePillarUiRenderer:
	extends RefCounted

	var draw_calls := 0
	var build_calls := 0
	var last_context: Dictionary = {}
	var last_build_context: Dictionary = {}

	func draw(
		_canvas: CanvasItem,
		_game_offset: Vector2,
		_game_size: Vector2,
		_time_seconds: float,
		context: Dictionary
	) -> void:
		draw_calls += 1
		last_context = context.duplicate(true)

	func build_commando_firearm_panel_state(_game_offset: Vector2, _game_size: Vector2, context: Dictionary) -> Dictionary:
		build_calls += 1
		last_build_context = context.duplicate(true)
		return {"rect": Rect2(Vector2(10.0, 20.0), Vector2(68.0, 112.0))}


class FakeFirearmRuntime:
	extends RefCounted

	func get_actor_draw_context() -> Dictionary:
		return {
			"commando_firearm_slingshot_state": {
				"charging": true,
				"charge_level": 1,
				"charge_ratio": 0.42,
				"charge_tick_ratio": 0.73,
			},
			"commando_firearm_pistol_state": {
				"shot_pending": false,
				"cooldown_frames": 0.0,
			},
			"commando_firearm_weapon_fire_sheet_state": {
				"active": true,
				"weapon_id": "ak47",
				"timer_frames": 20.0,
				"timer_max_frames": 40.0,
			},
			"commando_firearm_suicide_drone_state": {
				"active": true,
				"pos": Vector2(10.0, 20.0),
			},
		}


class FakePerfLogger:
	extends RefCounted

	func begin_sample() -> int:
		return Time.get_ticks_usec()

	func finish_sample(_label: String, _start_usec: int) -> void:
		pass


class FakeRegistry:
	extends RefCounted

	var entries: Dictionary = {}

	func _init(initial_entries: Dictionary = {}) -> void:
		entries = initial_entries

	func get_instance(key: String) -> Object:
		return entries.get(key, null)


func _init() -> void:
	_verify_stage1_pillar_reads_live_pistol_state()

	if _failures.is_empty():
		print("commando_firearm_pillar_hud_context_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_stage1_pillar_reads_live_pistol_state() -> void:
	var fake_renderer := FakePillarUiRenderer.new()
	var fake_runtime := FakeFirearmRuntime.new()
	var fake_perf_logger := FakePerfLogger.new()
	var registry := FakeRegistry.new({
		"stage1_pillar_ui_renderer": fake_renderer,
		"commando_firearm_runtime": fake_runtime,
		"commando_firearm_selector_renderer": RefCounted.new(),
		"commando_weapon_controller": RefCounted.new(),
	})
	var drawer := Stage1PillarHudSceneDrawer.new()
	drawer._draw_stage1_pillar_ui(
		null,
		{
			"height": 750.0,
			"selected_character_type": "soldier",
			"special_gauge": 100.0,
			"gauge_max": 500.0,
			"battle_perf_logger": fake_perf_logger,
		},
		registry,
		{},
		Vector2.ZERO,
		Vector2(760.0, 750.0),
		0.0
	)
	_expect(fake_renderer.draw_calls == 1, "stage1 pillar HUD should call the pillar UI renderer")
	var pistol_state: Dictionary = _get_dict(fake_renderer.last_context.get("commando_firearm_pistol_state", {}))
	_expect(pistol_state.has("shot_pending"), "stage1 pillar HUD should pass live pistol state from firearm runtime")
	_expect(not bool(pistol_state.get("shot_pending", true)), "base pistol HUD context should preserve pistol shot-pending state")
	var weapon_fire_state: Dictionary = _get_dict(fake_renderer.last_context.get("commando_firearm_weapon_fire_sheet_state", {}))
	_expect(str(weapon_fire_state.get("weapon_id", "")) == "ak47", "stage1 pillar HUD should pass live AK-47 weapon fire state from firearm runtime")
	var suicide_drone_state: Dictionary = _get_dict(fake_renderer.last_context.get("commando_firearm_suicide_drone_state", {}))
	_expect(bool(suicide_drone_state.get("active", false)), "stage1 pillar HUD should pass live suicide-drone state from firearm runtime")
	_expect(fake_renderer.last_context.get("battle_perf_logger", null) == fake_perf_logger, "stage1 pillar HUD should forward the perf logger into the pillar UI renderer")
	drawer.build_commando_firearm_panel_state_for_boss_hud(
		{
			"height": 750.0,
			"selected_character_type": "soldier",
		},
		registry,
		Vector2.ZERO,
		Vector2(760.0, 750.0)
	)
	_expect(fake_renderer.build_calls == 1, "stage1 boss HUD panel-state path should call the pillar UI panel builder")
	var boss_hud_suicide_drone_state: Dictionary = _get_dict(fake_renderer.last_build_context.get("commando_firearm_suicide_drone_state", {}))
	_expect(bool(boss_hud_suicide_drone_state.get("active", false)), "stage1 boss HUD panel-state path should pass live suicide-drone state from firearm runtime")


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
