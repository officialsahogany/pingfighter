extends SceneTree

# Guards the shared boss electrocution FIELD host (body-conforming electrocution:
# BOX spark shower + procedural crackle bolts, NOT a magic ring): the spark
# texture loads, the host builds its spark-particle child and activates /
# deactivates from the shared electric-stun flags (Ragnarok + central
# electric_stun), the static factory dedupes a single host per canvas, and
# sync_field bakes the playfield->screen transform (children do not inherit the
# parent canvas's draw_set_transform mapping — pins the top-left-detach regression).
#
# Nodes are created standalone (never parented into the SceneTree) and freed
# explicitly so the headless run reports no leaked instances; the tween path is
# guarded for the not-in-tree case so sync_field/deactivate stay crash-free.

const ElectrocutionFieldHost := preload("res://scripts/effects/boss_electrocution_field_fx_host.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_pipeline_and_texture()
	_verify_host_builds_and_toggles()
	_verify_screen_transform_bake()
	_verify_drive_from_context()
	_verify_static_factory_dedupes()

	if _failures.is_empty():
		print("boss_electrocution_field_fx_host_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_pipeline_and_texture() -> void:
	var status: Dictionary = ElectrocutionFieldHost.build_pipeline_status()
	_expect(bool(status.get("boss_electrocution_field_spark_ready", false)), "pipeline status should report the spark texture ready")
	_expect(int(status.get("boss_electrocution_field_bolt_count", 0)) > 0, "pipeline status should report a positive crackle-bolt count")
	var tex: Texture2D = ProjectResourceLoader.load_texture(ElectrocutionFieldHost.SPARK_PATH)
	_expect(tex != null and tex.get_width() > 0, "electrocution spark texture should load: %s" % ElectrocutionFieldHost.SPARK_PATH)


func _verify_host_builds_and_toggles() -> void:
	var host: Node = ElectrocutionFieldHost.new()
	# sync_field(playfield_center, game_offset, render_scale, intensity, peak)
	host.sync_field(Vector2(380.0, 60.0), Vector2.ZERO, 1.0, 1.0, false)
	_expect(host.visible, "sync_field should make the field visible")
	_expect(bool(host.is_field_active_for_tests()), "sync_field should mark the field active")
	# Spark shower particle is the only child node; bolts/flashes are procedural _draw.
	_expect(host.get_child_count() == 1, "field host should build exactly the spark-particle child, got %d" % host.get_child_count())
	host.deactivate()
	_expect(not bool(host.is_field_active_for_tests()), "deactivate should clear the active target so the field fades out")
	host.free()


func _verify_screen_transform_bake() -> void:
	var host: Node = ElectrocutionFieldHost.new()
	host.sync_field(Vector2(380.0, 60.0), Vector2(120.0, 40.0), 1.25, 1.0, false)
	# Children do not inherit the parent canvas's draw_set_transform mapping, so
	# the host must bake game_offset + playfield * render_scale itself.
	_expect(host.position.is_equal_approx(Vector2(120.0, 40.0) + Vector2(380.0, 60.0) * 1.25), "sync_field should map playfield center to screen via game_offset + center * render_scale")
	_expect(host.scale.is_equal_approx(Vector2(1.25, 1.25)), "sync_field should scale the field by render_scale")
	host.free()


func _verify_drive_from_context() -> void:
	var canvas := Node2D.new()
	# Ragnarok source flag.
	ElectrocutionFieldHost.drive_from_context(canvas, Vector2(380.0, 60.0), {"ragnarok_hammer_electric_stun_active": true})
	var host_a: Node = ElectrocutionFieldHost.get_or_create_on_canvas(canvas)
	_expect(host_a != null, "ragnarok electric stun flag should drive a field host onto the canvas")
	_expect(bool(host_a.is_field_active_for_tests()), "ragnarok flag should leave the field active")
	# Central electric stun source (Lumion thunder orb path).
	ElectrocutionFieldHost.drive_from_context(canvas, Vector2(380.0, 60.0), {"boss_electric_stun_active": true})
	_expect(bool(host_a.is_field_active_for_tests()), "central boss_electric_stun_active should keep the field active")
	# No electric stun -> hide.
	ElectrocutionFieldHost.drive_from_context(canvas, Vector2(380.0, 60.0), {})
	_expect(not bool(host_a.is_field_active_for_tests()), "no electric-stun flag should deactivate the shared field")
	if is_instance_valid(host_a):
		host_a.free()
	canvas.free()


func _verify_static_factory_dedupes() -> void:
	var canvas := Node2D.new()
	var host_a: Node = ElectrocutionFieldHost.get_or_create_on_canvas(canvas)
	var host_b: Node = ElectrocutionFieldHost.get_or_create_on_canvas(canvas)
	_expect(host_a != null and host_a == host_b, "get_or_create_on_canvas should return a single deduped host per canvas")
	_expect(str(host_a.name) == ElectrocutionFieldHost.HOST_NAME, "field host should be named %s" % ElectrocutionFieldHost.HOST_NAME)
	if is_instance_valid(host_a):
		host_a.free()
	canvas.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
