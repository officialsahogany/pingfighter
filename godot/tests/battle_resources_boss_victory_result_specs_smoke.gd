extends SceneTree

const BattleResources := preload("res://scripts/resources/battle_resources.gd")
const DefeatChanceGemsContinueScreen := preload("res://scripts/core/defeat_chance_gems_continue_screen.gd")

const EXPECTED_BOSS_VICTORY_PATHS := {
	1: "res://assets/sprites/stage1/dalji/dalji_boss_victory.png",
	2: "res://assets/sprites/stage2/stage2_boss_victory_hop_autosprite_v1_64f.png",
	3: "res://assets/sprites/stage3/menhera_boss_victory.png",
	4: "res://assets/sprites/stage4/stage4_ponk_boss_victory.png",
	5: "res://assets/sprites/stage5/stage5_hongryun_boss_victory.png",
	6: "res://assets/sprites/bosses/stage6_tetriser/stage6_tetriser_boss_victory_4x2.png",
}

var _failures: Array[String] = []


func _init() -> void:
	for stage_id in range(1, 7):
		_verify_boss_victory_result_spec(stage_id)

	if _failures.is_empty():
		print("battle_resources_boss_victory_result_specs_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_boss_victory_result_spec(stage_id: int) -> void:
	var resources: Object = BattleResources.new()
	var specs_value: Variant = resources.call(
		"_get_result_texture_specs",
		"smasher",
		stage_id,
		{
			"player_defeat_active": true,
			"boss_victory_active": true,
		}
	)
	_expect(specs_value is Array, "Stage %d result prewarm specs should be an array" % stage_id)
	if not (specs_value is Array):
		return

	var matches: Array[Dictionary] = []
	for spec_value in specs_value:
		if not (spec_value is Dictionary):
			continue
		var spec: Dictionary = spec_value
		var keys_value: Variant = spec.get("keys", [])
		if keys_value is Array and (keys_value as Array).has("boss_victory_sheet"):
			matches.append(spec)

	_expect(matches.size() == 1, "Stage %d result prewarm should expose exactly one boss_victory_sheet spec" % stage_id)
	if matches.is_empty():
		return

	var expected_path := str(EXPECTED_BOSS_VICTORY_PATHS.get(stage_id, ""))
	var path := str(matches[0].get("path", ""))
	_expect(path == expected_path, "Stage %d boss_victory_sheet should use %s, got %s" % [stage_id, expected_path, path])
	_expect(FileAccess.file_exists(path), "Stage %d boss_victory_sheet file should exist at %s" % [stage_id, path])

	var texture := load(path) as Texture2D
	_expect(texture != null, "Stage %d boss_victory_sheet should load as Texture2D" % stage_id)
	if texture == null:
		return

	if stage_id >= 4:
		_expect(
			texture.get_size() == Vector2(1536.0, 768.0),
			"Stage %d boss victory portal sheet should keep the 4x2 1536x768 handoff size" % stage_id
		)
		var source_rect: Rect2 = DefeatChanceGemsContinueScreen.new()._get_boss_victory_source_rect(texture, stage_id, 7)
		_expect(
			source_rect.size == Vector2(384.0, 384.0),
			"Stage %d continue portal slicer should read the non-square sheet as a 4x2 grid" % stage_id
		)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
