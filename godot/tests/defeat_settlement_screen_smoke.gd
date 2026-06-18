extends SceneTree

const DefeatSettlementScreen := preload("res://scripts/core/defeat_settlement_screen.gd")
const BattleSceneModalGateController := preload("res://scripts/core/battle_scene_modal_gate_controller.gd")

var _failures: Array[String] = []
var _exit_calls := 0


class FakeOwner:
	extends RefCounted

	var current_stage := 5
	var runtime_perk_gold := 37
	var active_item_slots: Array = [
		{"item_id": "grenade"},
		{"display_name": "테스트 액티브"},
	]
	var passive_item_inventory: Array = [
		{"display_name": "보존 패시브"},
	]
	var runtime_perk_levels: Dictionary = {
		"dash_lightweight": 2,
	}
	var redraws := 0

	func queue_redraw() -> void:
		redraws += 1


class FakeStore:
	extends RefCounted

	var plaza_gold := 120
	var get_calls := 0

	func get_plaza_gold() -> int:
		get_calls += 1
		return plaza_gold


class FakeScoreState:
	extends RefCounted

	func get_snapshot() -> Dictionary:
		return {
			"player_score": 2,
			"boss_score": 5,
			"win_goal": 5,
		}


class FakeRuntimePerkState:
	extends RefCounted

	func get_snapshot() -> Dictionary:
		return {
			"runtime_skill_levels": {
				"dash_lightweight": 2,
				"dash_jump": 1,
			},
		}


class FakeMythicRuntime:
	extends RefCounted

	func get_snapshot() -> Dictionary:
		return {
			"inventory_items": [
				{"display_name": "신화 보존"},
				{"name": "megingjord"},
			],
		}


class FakeRegistry:
	extends RefCounted

	var settlement_screen: Object = null
	var store: Object = FakeStore.new()
	var score_state: Object = FakeScoreState.new()
	var runtime_perk_state: Object = FakeRuntimePerkState.new()
	var mythic_runtime: Object = FakeMythicRuntime.new()

	func get_instance(key: String) -> Object:
		match key:
			"defeat_settlement_screen":
				return settlement_screen
			"plaza_save_store":
				return store
			"match_score_state":
				return score_state
			"runtime_perk_state":
				return runtime_perk_state
			"mythic_item_runtime":
				return mythic_runtime
			_:
				return null

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)


func _init() -> void:
	_verify_settlement_snapshot_and_one_shot_exit()
	_verify_modal_gate_and_runtime_wiring()

	if _failures.is_empty():
		print("defeat_settlement_screen_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_settlement_snapshot_and_one_shot_exit() -> void:
	_exit_calls = 0
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var screen := DefeatSettlementScreen.new()
	registry.settlement_screen = screen

	_expect(screen.show(owner, registry, Callable(self, "_record_exit")), "show should open the defeat settlement screen")
	_expect(screen.is_active(), "settlement screen should become active after show")
	_expect(owner.redraws == 1, "show should request redraw")
	_expect((registry.store as FakeStore).get_calls == 1, "settlement should read plaza gold once while taking the snapshot")
	_expect(owner.runtime_perk_gold == 37, "settlement must not transfer or clear runtime perk gold")

	var snapshot := screen.get_snapshot()
	var gold: Dictionary = snapshot.get("gold", {})
	var score: Dictionary = snapshot.get("score", {})
	var stage: Dictionary = snapshot.get("stage", {})
	var active_items: Array = snapshot.get("active_items", [])
	var passive_items: Array = snapshot.get("passive_items", [])
	var perks: Array = snapshot.get("perks", [])
	_expect(int(gold.get("plaza", -1)) == 120, "snapshot should include plaza gold")
	_expect(int(gold.get("runtime", -1)) == 37, "snapshot should include in-run perk gold")
	_expect(int(gold.get("total", -1)) == 157, "snapshot should display plaza + in-run gold total")
	_expect(int(score.get("player", -1)) == 2 and int(score.get("boss", -1)) == 5, "snapshot should capture the final score")
	_expect(str(stage.get("current_boss", "")) == "홍련", "stage 5 should map to Hongryun in the Godot route")
	_expect((stage.get("cleared_bosses", []) as Array).has("폰크"), "cleared bosses should include previous Godot stages")
	_expect(active_items.has("테스트 액티브"), "snapshot should include active item labels")
	_expect(passive_items.has("신화 보존"), "snapshot should prefer mythic runtime inventory over owner fallback")
	_expect(perks.size() == 2, "snapshot should prefer runtime perk state levels over owner fallback")

	var echo_event := InputEventKey.new()
	echo_event.pressed = true
	echo_event.echo = true
	echo_event.keycode = KEY_SPACE
	screen.handle_input(echo_event, owner, registry, Vector2(1280.0, 720.0))
	_expect(screen.is_active() and _exit_calls == 0, "echo confirm key must not dismiss settlement")

	var confirm_event := InputEventKey.new()
	confirm_event.pressed = true
	confirm_event.keycode = KEY_SPACE
	screen.handle_input(confirm_event, owner, registry, Vector2(1280.0, 720.0))
	_expect(not screen.is_active(), "confirm key should close settlement")
	_expect(_exit_calls == 1, "confirm key should call the exit callback once")

	screen.handle_input(confirm_event, owner, registry, Vector2(1280.0, 720.0))
	_expect(_exit_calls == 1, "closed settlement must not call exit again")


func _verify_modal_gate_and_runtime_wiring() -> void:
	var registry := FakeRegistry.new()
	var screen := DefeatSettlementScreen.new()
	registry.settlement_screen = screen
	var gate := BattleSceneModalGateController.new()
	_expect(not gate.should_block_battle_physics(Callable(registry, "get_instance")), "inactive settlement should not block physics")
	screen.show(FakeOwner.new(), registry, Callable(self, "_record_exit"))
	_expect(gate.is_defeat_settlement_active(Callable(registry, "get_instance")), "modal gate should expose defeat settlement activity")
	_expect(gate.should_block_battle_physics(Callable(registry, "get_instance")), "active settlement should block battle physics")
	screen.reset()
	registry.settlement_screen = null

	var catalog_source := FileAccess.get_file_as_string("res://scripts/resources/gameplay_core_module_catalog.gd")
	var flow_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_match_flow_driver.gd")
	var frame_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_frame_controller.gd")
	var input_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_input_controller.gd")
	var gate_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_modal_gate_controller.gd")
	_expect(catalog_source.find("defeat_settlement_screen") >= 0, "defeat settlement screen should be registered in the core module catalog")
	_expect(flow_source.find("_show_defeat_settlement") >= 0, "match flow should route final defeats through settlement")
	_expect(frame_source.find("process.frame.defeat_settlement") >= 0, "frame controller should update the defeat settlement screen")
	_expect(frame_source.find("draw.frame.defeat_settlement") >= 0, "frame controller should draw the defeat settlement screen")
	_expect(frame_source.find("physics.frame.gate.defeat_settlement") >= 0, "frame controller should stop physics while settlement is active")
	_expect(input_source.find("_handle_defeat_settlement_input") >= 0, "input controller should route input to defeat settlement")
	_expect(gate_source.find("physics.modal_gate.defeat_settlement") >= 0, "modal gate should block battle physics for settlement")


func _record_exit() -> void:
	_exit_calls += 1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
