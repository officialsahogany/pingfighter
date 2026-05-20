extends SceneTree

const CharacterLivePreview := preload("res://scripts/ui/character_live_preview.gd")
const CharacterSelectData := preload("res://scripts/ui/character_select_data.gd")

var failure_count: int = 0
var ran: bool = false


func _process(_delta: float) -> bool:
	if ran:
		return true
	ran = true
	_run()
	return true


func _run() -> void:
	var main_window: Window = get_root()
	var preview: Control = CharacterLivePreview.new()
	preview.size = Vector2(640.0, 800.0)
	main_window.add_child(preview)

	var smasher: Dictionary = _find_character(CharacterSelectData.get_characters(), "ufo_player")
	_expect(not smasher.is_empty(), "character data should include smasher")
	var portrait := load(str(smasher.get("portrait_path", ""))) as Texture2D
	_expect(portrait != null, "smasher portrait should load")
	preview.call("set_character", smasher, portrait)

	var idle_path := str(smasher.get("live2d_fullframe_sheet_path", ""))
	var idle_texture := load(idle_path) as Texture2D
	_expect(idle_texture != null, "smasher idle Live2D sheet should load")
	var idle_config := {
		"cols": int(smasher.get("live2d_fullframe_cols", 1)),
		"rows": int(smasher.get("live2d_fullframe_rows", 1)),
		"count": int(smasher.get("live2d_fullframe_count", 1)),
		"interval": float(smasher.get("live2d_fullframe_interval", 0.16)),
		"trim_rect": smasher.get("live2d_trim_rect", Rect2()),
	}
	preview.call("_finish_fullframe_sheet_load", idle_path, idle_config, idle_texture)
	preview.set("elapsed", 0.24)

	var idle_count := int(preview.get("fullframe_count"))
	var idle_cols := int(preview.get("fullframe_cols"))
	var idle_rows := int(preview.get("fullframe_rows"))
	var idle_interval := float(preview.get("fullframe_interval"))
	var idle_restored_texture := preview.get("fullframe_sheet_texture") as Texture2D
	var one_shot_path := str(smasher.get("live2d_preview_still_path", smasher.get("portrait_path", "")))

	_expect(
		bool(preview.call("play_fullframe_one_shot", {
			"path": one_shot_path,
			"cols": 1,
			"rows": 1,
			"count": 1,
			"interval": 0.016,
			"return_transition_duration": 0.18,
			"restore_elapsed_mode": "restart",
			"restore_after_finish": true,
		})),
		"click one-shot should start"
	)
	preview.call("_process", 0.020)
	_expect(not bool(preview.call("is_one_shot_playing")), "click one-shot should report finished")
	_expect(not bool(preview.get("one_shot_active")), "click one-shot should leave one-shot mode after finishing")
	_expect(preview.get("fullframe_sheet_texture") == idle_restored_texture, "click one-shot should restore the idle texture")
	_expect(int(preview.get("fullframe_count")) == idle_count, "click one-shot should restore idle frame count")
	_expect(int(preview.get("fullframe_cols")) == idle_cols, "click one-shot should restore idle columns")
	_expect(int(preview.get("fullframe_rows")) == idle_rows, "click one-shot should restore idle rows")
	_expect(is_equal_approx(float(preview.get("fullframe_interval")), idle_interval), "click one-shot should restore idle interval")
	_expect(is_equal_approx(float(preview.get("elapsed")), 0.0), "restart restore mode should resume the idle sheet from frame 1")
	_expect(preview.get("return_transition_texture") != null, "click one-shot should arm the return transition overlay")
	_expect(float(preview.get("return_transition_duration")) > 0.0, "click one-shot should set a positive return transition duration")
	preview.call("_process", 0.06)
	_expect(preview.get("return_transition_texture") != null, "return transition overlay should still be active mid-fade")
	preview.call("_process", 0.30)
	_expect(preview.get("return_transition_texture") == null, "return transition overlay should clear after its duration")

	_expect(
		bool(preview.call("play_fullframe_one_shot", {
			"path": one_shot_path,
			"cols": 1,
			"rows": 1,
			"count": 1,
			"interval": 0.016,
			"restore_after_finish": false,
		})),
		"confirm one-shot should start"
	)
	preview.call("_process", 0.020)
	_expect(not bool(preview.call("is_one_shot_playing")), "confirm one-shot should report finished after its duration")
	_expect(bool(preview.get("one_shot_active")), "confirm one-shot should hold the final frame until the owner finishes")
	_expect(int(preview.get("fullframe_count")) == 1, "confirm one-shot should keep its one-shot frame config")
	_expect(preview.get("return_transition_texture") == null, "confirm one-shot should not arm the return transition overlay")

	preview.queue_free()
	if failure_count > 0:
		quit(1)
		return
	print("character_live_preview_one_shot_restore_smoke: ok")
	quit(0)


func _find_character(characters: Array, character_id: String) -> Dictionary:
	for value in characters:
		if value is Dictionary:
			var character: Dictionary = value
			if str(character.get("id", "")) == character_id:
				return character
	return {}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
