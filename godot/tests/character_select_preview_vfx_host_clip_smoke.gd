extends SceneTree

const CharacterSelectPreviewVfxHost := preload("res://scripts/ui/character_select_preview_vfx_host.gd")
const CharacterSelectData := preload("res://scripts/ui/character_select_data.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

var failure_count: int = 0
var ran: bool = false


func _process(_delta: float) -> bool:
	if ran:
		return true
	ran = true
	_run()
	return true


func _run() -> void:
	var root: Window = get_root()
	var host: Control = CharacterSelectPreviewVfxHost.new()
	host.size = Vector2(640.0, 800.0)
	root.add_child(host)

	var all_characters: Array = CharacterSelectData.get_characters()
	for character_id in ["ufo_player", "soldier", "viper", "blacksmith", "optimus"]:
		var character := _find_character(all_characters, character_id)
		_expect(not character.is_empty(), "character data should include %s" % character_id)
		host.call("set_character", character)
		host.call("_process", 0.016)
		var status: Dictionary = host.call("get_runtime_status")
		_expect(bool(status.get("clip_contents", false)), "VFX host should clip to the LivePreview-local rect")
		_expect(str(status.get("character_id", "")) == character_id, "VFX host should switch preset for %s" % character_id)
		_expect(int(status.get("texture_layers", -1)) == 2, "VFX host should keep only clipped backplate and mandala texture layers for %s" % character_id)
		_expect(int(status.get("gpu_particle_layers", 0)) == 1, "VFX host should keep one clipped particle layer for %s" % character_id)
		host.call("play_confirm", {"amount": 1.0})
		host.call("_process", 0.016)
		var bounds := Rect2(Vector2.ZERO, host.size)
		var rects: Array = host.call("get_layer_rects")
		_expect(rects.size() >= 1, "VFX host should expose the confirm tint rect for %s" % character_id)
		for rect_value in rects:
			if not (rect_value is Rect2):
				continue
			var rect: Rect2 = rect_value
			_expect(_rect_contains(bounds, rect), "VFX layer rect should remain inside LivePreview local rect for %s" % character_id)

	host.call("clear_runtime_state")
	host.free()
	ProjectResourceLoader.clear_caches()
	if failure_count > 0:
		call_deferred("_quit_with_code", 1)
		return
	print("character_select_preview_vfx_host_clip_smoke: ok")
	call_deferred("_quit_with_code", 0)


func _quit_with_code(exit_code: int) -> void:
	for _i in range(3):
		await process_frame
	quit(exit_code)


func _rect_contains(bounds: Rect2, rect: Rect2) -> bool:
	return (
		rect.position.x >= bounds.position.x - 0.01
		and rect.position.y >= bounds.position.y - 0.01
		and rect.end.x <= bounds.end.x + 0.01
		and rect.end.y <= bounds.end.y + 0.01
	)


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
