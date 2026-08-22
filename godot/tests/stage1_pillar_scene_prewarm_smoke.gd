extends SceneTree

const Stage1PillarSceneDrawer := preload("res://scripts/stages/stage1/stage1_pillar_scene_drawer.gd")
const Stage1PillarHudSceneDrawer := preload("res://scripts/stages/stage1/stage1_pillar_hud_scene_drawer.gd")

var _failures: Array[String] = []
var _modules: Dictionary = {}
var _requests: Dictionary = {}


class FakeModule:
	extends RefCounted

	var prewarm_count := 0

	func prewarm_assets() -> void:
		prewarm_count += 1


class FakeSkillConfig:
	extends RefCounted

	func get_snapshot() -> Dictionary:
		return {
			"max_slots": 5,
			"equipped_skills": [],
		}


class FakeDashState:
	extends RefCounted

	func get_snapshot() -> Dictionary:
		return {}


class FakeBossAiState:
	extends RefCounted

	func get_dash_token_snapshot() -> Dictionary:
		return {}


class FakePillarUiRenderer:
	extends RefCounted

	var draw_count := 0
	var last_sensor_context: Dictionary = {}

	func draw(
		_canvas: CanvasItem,
		_game_offset: Vector2,
		_game_size: Vector2,
		_time_seconds: float,
		context: Dictionary
	) -> void:
		draw_count += 1
		last_sensor_context = context.get("sensor_context", {}) if context.get("sensor_context", {}) is Dictionary else {}


class FakeMythicRuntime:
	extends RefCounted

	func get_sensor_context() -> Dictionary:
		return {
			"equipped": true,
			"ready": true,
		}


class FakeDrawRegistry:
	extends RefCounted

	var cached_runtime: Object = null
	var renderer := FakePillarUiRenderer.new()
	var instance_requests: Array[String] = []
	var cached_requests: Array[String] = []

	func get_instance(key: String) -> Object:
		instance_requests.append(key)
		return _get_cached_test_module(key)

	func get_cached_instance(key: String) -> Object:
		cached_requests.append(key)
		return _get_cached_test_module(key)

	func _get_cached_test_module(key: String) -> Object:
		if key == "mythic_item_runtime":
			return cached_runtime
		match key:
			"stage1_pillar_ui_renderer":
				return renderer
			"smasher_skill_config":
				return FakeSkillConfig.new()
			"smasher_dash_state":
				return FakeDashState.new()
			"boss_ai_state":
				return FakeBossAiState.new()
		return null


func _init() -> void:
	_verify_stage1_pillar_prewarm_touches_hud_modules()
	_verify_stage1_pillar_ui_draw_uses_cached_mythic_runtime()

	if _failures.is_empty():
		print("stage1_pillar_scene_prewarm_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_stage1_pillar_prewarm_touches_hud_modules() -> void:
	_modules.clear()
	_requests.clear()
	var drawer := Stage1PillarSceneDrawer.new()
	drawer.prewarm_assets(Callable(self, "_get_module"), "smasher")
	_expect(_requests.has("smasher_combo_renderer"), "Stage 1 pillar prewarm should touch smasher combo renderer")

	_modules.clear()
	_requests.clear()
	drawer.prewarm_assets(Callable(self, "_get_module"), "soldier")

	for key in [
		"stage1_pillar_ui_renderer",
		"active_item_hud_renderer",
		"horn_strawberry_skill_pillar_renderer",
		"scoreboard_renderer",
		"stage1_dalji_boss_skill_cooldown_state",
		"stage1_dalji_boss_skill_hud_renderer",
		"commando_firearm_selector_renderer",
		"commando_weapon_controller",
		"commando_firearm_runtime",
	]:
		_expect(_requests.has(key), "Stage 1 pillar prewarm should touch %s" % key)
	_expect(_get_fake_module("stage1_dalji_boss_skill_hud_renderer").prewarm_count == 1, "Stage 1 boss skill HUD should prewarm its assets")
	_expect(_get_fake_module("commando_firearm_selector_renderer").prewarm_count == 1, "commando selector should prewarm its assets")

	_modules.clear()
	_requests.clear()
	drawer.prewarm_assets(Callable(self, "_get_module"), "soldier", "pododaejang")
	_expect(_requests.has("stage1_pillar_ui_renderer"), "Pododaejang Stage 1 pillar prewarm should keep shared HUD modules")
	_expect(_requests.has("active_item_hud_renderer"), "Pododaejang Stage 1 pillar prewarm should keep active item HUD modules")
	_expect(_requests.has("commando_firearm_selector_renderer"), "Pododaejang Stage 1 pillar prewarm should keep Commando panel modules")
	_expect(_requests.has("stage1_pododaejang_boss_skill_cooldown_state"), "Pododaejang prewarm should touch its cooldown state")
	_expect(_requests.has("stage1_pododaejang_boss_skill_hud_renderer"), "Pododaejang prewarm should touch its boss skill HUD")
	_expect(_get_fake_module("stage1_pododaejang_boss_skill_hud_renderer").prewarm_count == 1, "Pododaejang boss skill HUD should prewarm its assets")
	_expect(not _requests.has("stage1_dalji_boss_skill_cooldown_state"), "Pododaejang prewarm should not touch Dalji cooldown state")
	_expect(not _requests.has("stage1_dalji_boss_skill_hud_renderer"), "Pododaejang prewarm should not touch Dalji boss skill HUD")
	_expect(not _requests.has("stage1_gaksital_boss_skill_cooldown_state"), "Pododaejang prewarm should not touch Gaksital cooldown state")
	_expect(not _requests.has("stage1_gaksital_boss_skill_hud_renderer"), "Pododaejang prewarm should not touch Gaksital boss skill HUD")


func _verify_stage1_pillar_ui_draw_uses_cached_mythic_runtime() -> void:
	var drawer := Stage1PillarHudSceneDrawer.new()
	var context := {
		"textures": {},
		"selected_character_type": "smasher",
		"height": 750.0,
	}
	var registry_without_runtime := FakeDrawRegistry.new()
	drawer._draw_stage1_pillar_ui(
		null,
		context,
		registry_without_runtime,
		{},
		Vector2.ZERO,
		Vector2(760.0, 750.0),
		0.0
	)
	_expect(registry_without_runtime.cached_requests.has("mythic_item_runtime"), "Stage 1 pillar UI draw should check cached mythic runtime")
	_expect(not registry_without_runtime.instance_requests.has("mythic_item_runtime"), "Stage 1 pillar UI draw should not lazy-create mythic runtime")
	_expect(registry_without_runtime.renderer.last_sensor_context.is_empty(), "missing cached mythic runtime should draw with empty sensor context")

	var registry_with_runtime := FakeDrawRegistry.new()
	registry_with_runtime.cached_runtime = FakeMythicRuntime.new()
	drawer._draw_stage1_pillar_ui(
		null,
		context,
		registry_with_runtime,
		{},
		Vector2.ZERO,
		Vector2(760.0, 750.0),
		0.0
	)
	_expect(not registry_with_runtime.instance_requests.has("mythic_item_runtime"), "cached mythic runtime path should still avoid lazy creation")
	_expect(bool(registry_with_runtime.renderer.last_sensor_context.get("equipped", false)), "cached mythic runtime should supply sensor context")


func _get_module(key: String) -> Object:
	_requests[key] = true
	return _get_fake_module(key)


func _get_fake_module(key: String) -> FakeModule:
	if not _modules.has(key):
		_modules[key] = FakeModule.new()
	return _modules[key]


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
