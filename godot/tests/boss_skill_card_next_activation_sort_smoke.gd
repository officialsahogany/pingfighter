extends SceneTree

const BossSkillCardHudSpec := preload("res://scripts/stages/common/boss_skill_card_hud_spec.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_common_next_activation_sort()
	_verify_stage_renderers_use_shared_sort()

	if _failures.is_empty():
		print("boss_skill_card_next_activation_sort_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_common_next_activation_sort() -> void:
	var entries := [
		{"id": "locked", "status": "locked", "cooldown_remaining": 0.1, "cooldown_total": 10.0, "progress": 0.99},
		{"id": "later", "status": "charging", "cooldown_remaining": 8.0, "cooldown_total": 10.0, "progress": 0.20},
		{"id": "casting", "status": "casting", "cooldown_remaining": 40.0, "cooldown_total": 40.0, "progress": 1.0},
		{"id": "soon", "status": "charging", "cooldown_remaining": 2.0, "cooldown_total": 40.0, "progress": 0.95},
		{"id": "ready", "status": "ready", "ready": true, "cooldown_remaining": 0.0, "cooldown_total": 25.0, "progress": 1.0},
	]
	entries.sort_custom(Callable(self, "_sort_by_next_activation"))
	_expect(
		_entry_ids(entries) == ["casting", "ready", "soon", "later", "locked"],
		"shared boss skillcard sort should use next activation time, with locked/used last"
	)


func _verify_stage_renderers_use_shared_sort() -> void:
	var renderer_paths := [
		"res://scripts/stages/stage1/stage1_dalji_boss_skill_hud_renderer.gd",
		"res://scripts/stages/stage2/stage2_boss_skill_hud_renderer.gd",
		"res://scripts/stages/stage3/stage3_boss_skill_hud_renderer.gd",
		"res://scripts/stages/stage4/stage4_ponk_boss_skill_hud_renderer.gd",
		"res://scripts/stages/stage5/stage5_hongryun_boss_skill_hud_renderer.gd",
	]
	for path in renderer_paths:
		var source := FileAccess.get_file_as_string(path)
		_expect(source.find("compare_skill_entries_by_next_activation") >= 0, "%s should use the shared next-activation sorter" % path)


func _entry_ids(entries: Array) -> Array[String]:
	var ids: Array[String] = []
	for entry in entries:
		if entry is Dictionary:
			ids.append(str((entry as Dictionary).get("id", "")))
	return ids


func _sort_by_next_activation(a: Dictionary, b: Dictionary) -> bool:
	return BossSkillCardHudSpec.compare_skill_entries_by_next_activation(a, b)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
