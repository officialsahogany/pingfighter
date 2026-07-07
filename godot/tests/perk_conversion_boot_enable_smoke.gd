extends SceneTree

# Slice C seal: the compile-time default of PerkConversionFlags stays OFF so
# legacy item-path port smokes are unaffected by the default, and the app boot
# entry (boot_flow_scene._ready) is the single point that turns the passive->perk
# conversion ON at runtime. Reverse-verified: removing the boot enable fails the
# "runtime ON" leg; flipping the compile default fails the "default OFF" leg.

const BootFlowScene := preload("res://scripts/core/boot_flow_scene.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

var _failures: Array[String] = []
var _boot: Control = null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# 1) Compile-time default must be OFF (read before any setter call).
	_expect(not PerkConversionFlags.is_enabled(), "conversion flag compile default should be OFF")

	# 2) Booting the app entry scene must flip it ON at runtime.
	_boot = BootFlowScene.new()
	_boot.set("post_intro_scene_path", "")
	get_root().add_child(_boot)
	current_scene = _boot
	await process_frame
	_boot.set_process(false)

	_expect(PerkConversionFlags.is_enabled(), "boot_flow._ready should enable the passive->perk conversion at runtime")

	_teardown()
	await process_frame
	await process_frame
	ProjectResourceLoader.clear_caches()
	await process_frame

	PerkConversionFlags.set_enabled(false)
	if _failures.is_empty():
		print("perk_conversion_boot_enable_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _teardown() -> void:
	if _boot == null:
		return
	if current_scene == _boot:
		current_scene = null
	_boot.queue_free()
	_boot = null


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
