extends SceneTree

const Stage5HongryunBossSkillHudRenderer := preload("res://scripts/stages/stage5/stage5_hongryun_boss_skill_hud_renderer.gd")
const Stage5HongryunFireMachineEvent := preload("res://scripts/stages/stage5/stage5_hongryun_fire_machine_event.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_fire_machine_is_map_event_not_skillcard()

	if _failures.is_empty():
		print("stage5_fire_machine_skillcard_boundary_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_fire_machine_is_map_event_not_skillcard() -> void:
	var event := Stage5HongryunFireMachineEvent.new()
	_expect(not event.has_method("get_hud_skill_context"), "fire machine should not expose a boss skill-card context")

	var renderer := Stage5HongryunBossSkillHudRenderer.new()
	var asset_status: Dictionary = renderer.get_asset_status()
	_expect(not asset_status.has("fire_machine_card_texture"), "Stage 5 boss skill HUD should not prewarm a fire-machine card")

	var renderer_source := FileAccess.get_file_as_string("res://scripts/stages/stage5/stage5_hongryun_boss_skill_hud_renderer.gd")
	var hongryun_pillar_source := FileAccess.get_file_as_string("res://scripts/stages/stage5/stage5_hongryun_pillar_scene_drawer.gd")
	var legacy_pillar_source := FileAccess.get_file_as_string("res://scripts/stages/stage5/stage5_pillar_scene_drawer.gd")
	_expect(renderer_source.find("\"hongryun_fire_machine\"") < 0, "Stage 5 boss skill HUD should not render fire-machine skill metadata")
	_expect(hongryun_pillar_source.find("_append_fire_machine_hud_skill") < 0, "Hongryun pillar drawer should not append fire-machine to the skill rail")
	_expect(legacy_pillar_source.find("_append_fire_machine_hud_skill") < 0, "legacy Stage 5 pillar drawer should not append fire-machine to the skill rail")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
