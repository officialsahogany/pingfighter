extends SceneTree

const CharacterSelectData := preload("res://scripts/ui/character_select_data.gd")
const CharacterSelectPrewarm := preload("res://scripts/ui/character_select_prewarm.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_commando_full_body_live2d()

	if _failures.is_empty():
		print("commando_fullbody_live2d_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_commando_full_body_live2d() -> void:
	var commando: Dictionary = _find_character("soldier")
	_expect(not commando.is_empty(), "Commando character-select data should exist")
	if commando.is_empty():
		return

	var sheet_path := str(commando.get("full_body_live2d_sheet_path", ""))
	var frame0_path := str(commando.get("full_body_live2d_path", ""))
	_expect(
		sheet_path.ends_with("commando_fullbody_hatfix_padded_idle_loop49_autosprite_v6_safe.png"),
		"Commando full-body panel should use the padded hat-safe head-to-boot Live2D loop"
	)
	_expect(
		frame0_path.ends_with("commando_fullbody_hatfix_padded_idle_loop49_autosprite_v6_frame0_safe.png"),
		"Commando full-body panel should keep the matching frame0 fallback"
	)
	_expect(int(commando.get("full_body_live2d_cols", 0)) == 7, "Commando full-body Live2D should use seven columns")
	_expect(int(commando.get("full_body_live2d_rows", 0)) == 7, "Commando full-body Live2D should use seven rows")
	_expect(int(commando.get("full_body_live2d_count", 0)) == 49, "Commando full-body Live2D should expose forty-nine frames")
	_expect(float(commando.get("full_body_live2d_interval", 0.0)) <= 0.034, "Commando full-body Live2D should run near 30 FPS")
	_expect(is_equal_approx(float(commando.get("full_body_live2d_stage_scale", 0.0)), 0.784), "Commando full-body Live2D should render at the requested 20 percent smaller scale")
	_expect(commando.get("full_body_live2d_trim_rect", null) is Rect2, "Commando full-body Live2D should use a precomputed trim rect")
	var trim: Rect2 = commando.get("full_body_live2d_trim_rect", Rect2())
	_expect(trim.position.y >= 70.0, "Commando full-body safe sheet should keep hat-safe top padding after inset")
	_expect(trim.size.y >= 860.0, "Commando full-body trim should preserve head-to-boot height")

	var sheet := load(sheet_path) as Texture2D
	_expect(sheet != null, "Commando full-body Live2D sheet should load")
	if sheet != null:
		_expect(sheet.get_size() == Vector2(7168, 7168), "Commando full-body sheet should use 1024 px cells in a 7x7 grid")
	var frame0 := load(frame0_path) as Texture2D
	_expect(frame0 != null, "Commando full-body frame0 fallback should load")
	if frame0 != null:
		_expect(frame0.get_size() == Vector2(1024, 1024), "Commando full-body frame0 fallback should use one 1024 px cell")

	var prewarm := CharacterSelectPrewarm.new()
	prewarm.begin("res://scenes/character_select.tscn")
	_expect(
		_prewarm_has_job(prewarm, sheet_path, "Texture2D"),
		"Character-select loading screen should prewarm the Commando full-body Live2D sheet"
	)


func _find_character(character_id: String) -> Dictionary:
	for value in CharacterSelectData.get_characters():
		if value is Dictionary and str((value as Dictionary).get("id", "")) == character_id:
			return value
	return {}


func _prewarm_has_job(prewarm: Object, path: String, type_hint: String) -> bool:
	if path == "":
		return false
	var current_job: Dictionary = prewarm.get("current_job")
	if str(current_job.get("path", "")) == path and str(current_job.get("type", "")) == type_hint:
		return true
	var jobs: Array = prewarm.get("jobs")
	for value in jobs:
		if value is Dictionary:
			var job: Dictionary = value
			if str(job.get("path", "")) == path and str(job.get("type", "")) == type_hint:
				return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
