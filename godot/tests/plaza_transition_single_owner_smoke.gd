extends SceneTree

const SCENE_PATH := "res://scripts/plaza/plaza_scene.gd"

var _failures: Array[String] = []


func _init() -> void:
	var source := FileAccess.get_file_as_string(SCENE_PATH)
	_expect(source != "", "plaza scene source should be readable")
	_expect(source.contains("var _transition_state: PlazaTransitionState"), "transition state should be statically typed")
	var forbidden := [
		"var _building_transition_active",
		"var _building_transition_phase",
		"var _building_transition_timer",
		"var _building_transition_target",
		"var _building_transition_player_pos",
		"var _building_transition_lingpet_pos",
		"var _plaza_warp_active",
		"var _plaza_warp_phase",
		"var _plaza_warp_timer",
		"func _sync_transition_facade",
	]
	for fragment in forbidden:
		_expect(not source.contains(fragment), "scene should not restore transition mirror: %s" % fragment)

	if _failures.is_empty():
		print("plaza_transition_single_owner_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
