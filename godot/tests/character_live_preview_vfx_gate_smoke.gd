extends SceneTree

const CharacterLivePreview := preload("res://scripts/ui/character_live_preview.gd")

var failure_count: int = 0


class PreviewVfxGateProbe extends CharacterLivePreview:
	var backdrop_draw_calls: int = 0

	func _draw_preview_vfx_texture_backdrop(_floor_y: float) -> void:
		backdrop_draw_calls += 1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var disabled_probe := await _draw_probe(false)
	_expect(disabled_probe.backdrop_draw_calls == 0, "disabled preview VFX should not call the backdrop draw path")
	_expect(disabled_probe.get_node_or_null("CharacterSelectPreviewVfxHost") == null, "disabled preview VFX should not create the host")
	disabled_probe.queue_free()

	var enabled_probe := await _draw_probe(true)
	_expect(enabled_probe.backdrop_draw_calls > 0, "enabled preview VFX should call the backdrop draw path")
	_expect(enabled_probe.get_node_or_null("CharacterSelectPreviewVfxHost") != null, "enabled preview VFX should create the host")
	enabled_probe.queue_free()

	await process_frame
	if failure_count > 0:
		quit(1)
		return
	print("character_live_preview_vfx_gate_smoke: ok")
	quit(0)


func _draw_probe(vfx_enabled: bool) -> PreviewVfxGateProbe:
	var probe := PreviewVfxGateProbe.new()
	probe.set("preview_vfx_enabled", vfx_enabled)
	probe.size = Vector2(640.0, 800.0)
	get_root().add_child(probe)
	probe.queue_redraw()
	await process_frame
	await process_frame
	return probe


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
