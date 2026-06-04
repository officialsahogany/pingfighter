extends SceneTree

const DriveCutinFxHost := preload("res://scripts/hud/drive_cutin_fx_host.gd")
const WritheEmber := preload("res://scripts/effects/writhe_ember_material.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const PARTICLE_PATH := "res://assets/ui/skill_cutin/drive/drive_cutin_particle.png"
const BACKPLATE_PATH := "res://assets/ui/skill_cutin/drive/drive_cutin_backplate.png"
const ARC_PATH := "res://assets/ui/skill_cutin/drive/drive_cutin_arc.png"
const VIEW := Vector2(1520, 1500)  # non-square, non-ref to expose drift / scale bugs

var _failures: Array[String] = []


func _init() -> void:
	_test_vfx_textures_load()
	_test_writhe_drive_presets()
	_test_prewarm_and_sync()
	_test_single_cleanup()
	_test_screen_space_anchor_no_drift()

	if _failures.is_empty():
		print("smasher_drive_cutin_fx_host_smoke: ok")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: %s" % f)
		quit(1)


func _test_vfx_textures_load() -> void:
	for p in [PARTICLE_PATH, BACKPLATE_PATH, ARC_PATH]:
		var tex: Texture2D = ProjectResourceLoader.load_texture(p, "", "")
		_expect(tex != null, "VFX texture should load: %s" % p)
		if tex != null:
			_expect(tex.get_width() > 1 and tex.get_height() > 1, "VFX texture should have size: %s" % p)


func _test_writhe_drive_presets() -> void:
	_expect(WritheEmber.has_preset("drive_cutin"), "writhe-ember drive_cutin preset should exist")
	_expect(WritheEmber.has_preset("drive_cutin_enraged"), "writhe-ember drive_cutin_enraged preset should exist")
	var mat := WritheEmber.build_material("drive_cutin")
	_expect(mat != null and mat is ShaderMaterial, "drive_cutin material should build")


func _test_prewarm_and_sync() -> void:
	DriveCutinFxHost.prewarm_assets()
	var host := DriveCutinFxHost.new()
	get_root().add_child(host)
	host.sync_state({"view_size": VIEW, "progress": 0.4, "enraged": false, "quality_scale": 1.0}, true)
	_expect(host.visible, "host should be visible when synced active")
	var status: Dictionary = host.get_debug_status()
	_expect(bool(status.get("particles_emitting", false)), "particles should emit during the in/hold window")
	_expect(bool(status.get("particle_texture_ready", false)), "particle texture should be ready after prewarm")
	_expect(_color_close(status.get("particle_color", Color.TRANSPARENT), DriveCutinFxHost.PARTICLE_COLOR), "particles should use the cyan drive color")
	host.sync_state({"view_size": VIEW, "progress": 0.4, "enraged": true, "quality_scale": 1.0}, true)
	status = host.get_debug_status()
	_expect(_color_close(status.get("particle_color", Color.TRANSPARENT), DriveCutinFxHost.PARTICLE_COLOR_ENRAGED), "enraged particles should use the brighter cyan drive color")
	host.queue_free()


func _test_single_cleanup() -> void:
	var host := DriveCutinFxHost.new()
	get_root().add_child(host)
	host.sync_state({"view_size": VIEW, "progress": 0.3, "quality_scale": 1.0}, true)
	_expect(host.visible, "host visible after active sync")
	# ONE inactive sync must silence everything (single-cleanup contract).
	host.sync_state({"view_size": VIEW, "progress": 0.95, "quality_scale": 1.0}, false)
	_expect(not host.visible, "host hidden after one inactive sync")
	var status: Dictionary = host.get_debug_status()
	_expect(not bool(status.get("particles_emitting", true)), "particles stop emitting after one inactive sync")
	host.queue_free()


func _test_screen_space_anchor_no_drift() -> void:
	# The cut-in is a SCREEN-space HUD overlay: position must be view_size*anchor and
	# scale must be view_size.y/REF -- NOT a game_offset + pos*render_scale playfield
	# mapping. This guards the inferno coordinate trap (drift as window scales).
	var host := DriveCutinFxHost.new()
	get_root().add_child(host)
	host.sync_state({"view_size": VIEW, "progress": 0.4, "quality_scale": 1.0}, true)
	var expected_pos := Vector2(VIEW.x * 0.135, VIEW.y * 0.30)
	_expect(host.position.distance_to(expected_pos) < 1.0,
		"host should sit at view_size*anchor (screen space), got %s expected %s" % [str(host.position), str(expected_pos)])
	var expected_scale := VIEW.y / 750.0
	_expect(absf(host.scale.x - expected_scale) < 0.001 and absf(host.scale.y - expected_scale) < 0.001,
		"host scale should be view_size.y/750, got %s expected %f" % [str(host.scale), expected_scale])
	host.queue_free()


func _expect(condition: bool, message: String = "") -> void:
	if not condition:
		_failures.append(message if message != "" else "assertion failed")


func _color_close(value: Variant, expected: Color) -> bool:
	if not (value is Color):
		return false
	var color: Color = value
	return (
		absf(color.r - expected.r) < 0.01
		and absf(color.g - expected.g) < 0.01
		and absf(color.b - expected.b) < 0.01
		and absf(color.a - expected.a) < 0.01
	)
