extends SceneTree

const Stage1CommandoFirearmRenderer := preload("res://scripts/stages/stage1/stage1_commando_firearm_renderer.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _verify_renderer_deferred_fx_host_lifecycle()

	if _failures.is_empty():
		print("commando_firearm_renderer_fx_host_lifecycle_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_renderer_deferred_fx_host_lifecycle() -> void:
	var renderer := Stage1CommandoFirearmRenderer.new()
	var canvas := Node2D.new()
	canvas.name = "CommandoFirearmRendererSmokeCanvas"
	get_root().add_child(canvas)

	var context := {
		"game_offset": Vector2(260.0, 20.0),
		"render_scale": 1.5,
		"commando_firearm_muzzle_flashes": [
			{"pos": Vector2(30.0, 50.0), "direction": Vector2.RIGHT, "radius": 12.0},
		],
		"commando_firearm_impact_flashes": [
			{"pos": Vector2(80.0, 96.0), "kind": "bazooka", "radius": 34.0, "timer_frames": 9.0, "max_timer_frames": 14.0},
		],
		"commando_firearm_lingering_effects": [
			{"pos": Vector2(120.0, 140.0), "kind": "fire_zone", "width": 150.0, "height": 60.0},
		],
	}
	renderer._sync_fx_host(canvas, renderer.build_draw_items(context), Vector2(5.0, 4.0), context)

	await process_frame

	var host: Node = canvas.get_node_or_null("CommandoFirearmFxHost")
	_expect(host != null, "Stage1 renderer should attach the Commando firearm FX host through the live canvas path")
	if host != null:
		var status: Dictionary = host.get_debug_status()
		_expect(bool(status.get("active", false)), "deferred FX host should preserve its pre-tree active sync after _ready")
		_expect(not host.is_processing(), "renderer-attached FX host should not run a detached _process callback")
		_expect(str(status.get("anchor_source", "")) == "impact", "renderer-attached FX host should keep impact as the anchor priority")
		_expect(host.position == Vector2(387.5, 170.0), "renderer-attached FX host should convert playfield-local impact anchors into screen layout space")
		_expect(host.scale == Vector2(1.5, 1.5), "renderer-attached FX host should scale its node-hosted layers with the playfield")

	renderer._sync_fx_host(canvas, renderer.build_draw_items({}), Vector2.ZERO)
	await process_frame

	if host != null:
		_expect(not bool(host.get_debug_status().get("active", true)), "renderer-attached FX host should hide when draw context has no firearm VFX")

	canvas.queue_free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
