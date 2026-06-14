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

	var character := _find_character(CharacterSelectData.get_characters(), "ufo_player")
	_expect(not character.is_empty(), "character data should include ufo_player")
	host.call("set_character", character)
	host.call("set_hover_amount", 1.0)
	host.call("_process", 0.08)
	var status: Dictionary = host.call("get_runtime_status")
	_expect(bool(status.get("active", false)), "VFX host should activate after set_character")
	_expect(bool(status.get("visible", false)), "VFX host should be visible after set_character")
	_expect(str(status.get("character_id", "")) == "ufo_player", "VFX host should track the selected character id")
	_expect(int(status.get("texture_layers", -1)) == 2, "VFX host should own only backplate and mandala texture layers")
	_expect(int(status.get("gpu_particle_layers", 0)) == 1, "VFX host should build one GPUParticles2D layer")
	_expect(bool(status.get("particles_emitting", false)), "VFX particles should emit while active")
	_expect(float(status.get("hover_amount", 0.0)) > 0.0, "VFX hover envelope should advance")

	host.call("play_confirm", {"amount": 1.0})
	host.call("_process", 0.02)
	status = host.call("get_runtime_status")
	_expect(float(status.get("confirm_amount", 0.0)) > 0.0, "VFX confirm envelope should arm")

	host.call("clear_runtime_state")
	status = host.call("get_runtime_status")
	_expect(not bool(status.get("active", true)), "VFX host should deactivate on clear_runtime_state")
	_expect(not bool(status.get("visible", true)), "VFX host should hide on clear_runtime_state")
	_expect(not bool(status.get("particles_emitting", true)), "VFX particles should stop on clear_runtime_state")
	_expect(not bool(status.get("process_enabled", true)), "VFX host should stop processing when inactive")

	host.free()
	ProjectResourceLoader.clear_caches()
	if failure_count > 0:
		call_deferred("_quit_with_code", 1)
		return
	print("character_select_preview_vfx_host_lifecycle_smoke: ok")
	call_deferred("_quit_with_code", 0)


func _quit_with_code(exit_code: int) -> void:
	for _i in range(3):
		await process_frame
	quit(exit_code)


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
