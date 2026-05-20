extends SceneTree

const Stage1CommandoFirearmFxHost := preload("res://scripts/stages/stage1/stage1_commando_firearm_fx_host.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_fx_host_builds_shader_and_gpu_layers()

	if _failures.is_empty():
		print("commando_firearm_fx_host_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_fx_host_builds_shader_and_gpu_layers() -> void:
	Stage1CommandoFirearmFxHost.prewarm_assets()
	var host := Stage1CommandoFirearmFxHost.new()
	get_root().add_child(host)
	host.sync_state({
		"muzzle_flashes": [
			{"pos": Vector2(32.0, 48.0), "direction": Vector2.RIGHT, "radius": 14.0, "timer_frames": 6.0, "max_timer_frames": 8.0},
		],
		"impact_flashes": [
			{"pos": Vector2(82.0, 96.0), "kind": "bazooka", "radius": 30.0, "timer_frames": 10.0, "max_timer_frames": 14.0},
		],
		"lingering_effects": [
			{"pos": Vector2(120.0, 140.0), "kind": "fire_zone", "width": 150.0, "height": 60.0},
		],
	}, Vector2(3.0, 4.0), true)
	var status: Dictionary = host.get_debug_status()
	_expect(bool(status.get("active", false)), "FX host should become visible when firearm VFX are active")
	_expect(not host.is_processing(), "FX host should stay driven by draw sync instead of detached _process")
	_expect(int(status.get("shader_layers", 0)) == 1, "FX host should build a ShaderMaterial layer")
	_expect(int(status.get("gpu_particle_layers", 0)) == 2, "FX host should build muzzle and impact GPUParticles2D layers")
	_expect(bool(status.get("texture_pieces_ready", false)), "FX host should prewarm texture-piece cache dependencies")
	_expect(bool(status.get("loop_tween_active", false)), "FX host should run a pulse Tween while in the tree")
	_expect(str(status.get("anchor_source", "")) == "impact", "impact flashes should be the highest-priority FX host anchor")
	_expect(host.position == Vector2(85.0, 100.0), "FX host should apply playfield-local shake offset to its anchor")
	host.sync_state({}, Vector2.ZERO, false)
	_expect(not bool(host.get_debug_status().get("active", true)), "FX host should hide when no firearm VFX are active")
	host.tear_down(true)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
