extends SceneTree

const Stage1PillarHudSceneDrawer := preload("res://scripts/stages/stage1/stage1_pillar_hud_scene_drawer.gd")
const Stage1PillarUiRenderer := preload("res://scripts/hud/stage1_pillar_ui_renderer.gd")

var _failures: Array[String] = []


class FakeTowerFlow:
	extends RefCounted

	var run_id := "tower-hud-run"
	var muhon := 17

	func get_run_id() -> String:
		return run_id

	func get_run_state_snapshot() -> Dictionary:
		return {"muhon": muhon, "gold": 4, "chance_gems": 2}


class CachedOnlyRegistry:
	extends RefCounted

	var flow_owner: Object
	var cold_get_calls := 0

	func _init(value: Object) -> void:
		flow_owner = value

	func get_cached_instance(key: String) -> Object:
		return flow_owner if key == "tower_ascent_flow_owner" else null

	func get_instance(_key: String) -> Object:
		cold_get_calls += 1
		return null


func _init() -> void:
	_verify_cached_run_balance_projection()
	_verify_non_tower_path_stays_hidden()
	_verify_layout_stacks_below_gold()
	if _failures.is_empty():
		print("tower_battle_muhon_hud_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_cached_run_balance_projection() -> void:
	var flow := FakeTowerFlow.new()
	var registry := CachedOnlyRegistry.new(flow)
	var drawer: Object = Stage1PillarHudSceneDrawer.new()
	var model: Dictionary = drawer.call("_build_tower_muhon_hud_context", registry)
	_expect(bool(model.get("tower_muhon_hud_visible", false)), "started tower run should expose the Muhon HUD")
	_expect(int(model.get("tower_muhon_hud_amount", -1)) == 17, "Muhon HUD should read the live tower run balance")
	_expect(registry.cold_get_calls == 0, "Muhon draw projection must never cold-create the tower flow owner")

	flow.muhon = 3
	model = drawer.call("_build_tower_muhon_hud_context", registry)
	_expect(int(model.get("tower_muhon_hud_amount", -1)) == 3, "Muhon HUD should refresh from the cached run state")


func _verify_non_tower_path_stays_hidden() -> void:
	var flow := FakeTowerFlow.new()
	flow.run_id = ""
	var registry := CachedOnlyRegistry.new(flow)
	var drawer: Object = Stage1PillarHudSceneDrawer.new()
	var model: Dictionary = drawer.call("_build_tower_muhon_hud_context", registry)
	_expect(not bool(model.get("tower_muhon_hud_visible", true)), "non-tower battle should not show a stale Muhon counter")
	_expect(registry.cold_get_calls == 0, "hidden Muhon HUD must remain a cached-only lookup")


func _verify_layout_stacks_below_gold() -> void:
	var renderer: Object = Stage1PillarUiRenderer.new()
	var context := {
		"height": 750.0,
		"gold_hud_amount": 1200,
		"tower_muhon_hud_amount": 17,
	}
	var gold_rect: Rect2 = renderer.build_gold_hud_rect(Vector2(260.0, 60.0), Vector2(760.0, 750.0), context)
	var muhon_rect: Rect2 = renderer.build_muhon_hud_rect(Vector2(260.0, 60.0), Vector2(760.0, 750.0), context)
	_expect(muhon_rect.position.x == gold_rect.position.x, "Muhon HUD should share the gold HUD pillar alignment")
	_expect(muhon_rect.position.y > gold_rect.end.y, "Muhon HUD should sit below the gold HUD without overlap")
	_expect(muhon_rect.size == gold_rect.size, "Muhon HUD should reuse the gold HUD footprint")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
