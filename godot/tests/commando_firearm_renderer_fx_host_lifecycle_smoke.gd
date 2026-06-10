extends SceneTree

const Stage1CommandoFirearmRenderer := preload("res://scripts/stages/stage1/stage1_commando_firearm_renderer.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _verify_renderer_deferred_fx_host_lifecycle()
	_verify_sync_fx_host_shallow_copy_isolation()

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


# Perf regression guard for the deep->shallow copy in _sync_fx_host (frame-budget
# work 2026-06): the firing-frame hot path used draw_items.duplicate(true),
# deep-copying every projectile/casing/effect array purely to swap the
# impact_flashes key to the grenade-filtered set. The shallow copy must still
# (a) hand the fx host the FILTERED impact_flashes (grenade_explosion removed),
# and (b) NOT mutate the caller's original draw_items, since draw() reads the
# original (unfiltered, with grenade) impact_flashes right after _sync_fx_host.
class CaptureFxHost:
	extends Node2D

	var captured_impact_flashes: Array = []
	var sync_called := false

	func sync_state(draw_items: Dictionary, _shake_offset: Vector2, _active: bool, _layout: Dictionary = {}) -> void:
		sync_called = true
		var value: Variant = draw_items.get("impact_flashes", [])
		captured_impact_flashes = value if value is Array else []


func _verify_sync_fx_host_shallow_copy_isolation() -> void:
	var renderer := Stage1CommandoFirearmRenderer.new()
	var host := CaptureFxHost.new()
	host.name = "CommandoFirearmFxHost"
	get_root().add_child(host)
	renderer.fx_host = host

	var bullet_flash := {"pos": Vector2(40.0, 90.0), "kind": "bazooka", "radius": 30.0}
	var grenade_flash := {"pos": Vector2(120.0, 110.0), "kind": "grenade_explosion", "radius": 50.0}
	var original_impacts: Array = [bullet_flash, grenade_flash]
	var draw_items := {
		"projectiles": [{"pos": Vector2(10.0, 10.0), "kind": "bullet"}],
		"muzzle_flashes": [{"pos": Vector2(20.0, 30.0), "direction": Vector2.RIGHT, "radius": 12.0}],
		"impact_flashes": original_impacts,
		"lingering_effects": [],
		"shell_casings": [],
		"pistol_feedbacks": [],
		"support_calls": [],
		"bowling_traps": [],
	}

	renderer._sync_fx_host(host, draw_items, Vector2(3.0, 2.0), {"render_scale": 1.0})

	_expect(host.sync_called, "shallow-copy path should still call host.sync_state when firearm VFX is active")
	# (a) host receives the grenade-filtered impact set (1 entry, the bullet only)
	_expect(
		host.captured_impact_flashes.size() == 1
		and str(_dict_of(host.captured_impact_flashes[0]).get("kind", "")) == "bazooka",
		"fx host must receive the grenade-filtered impact_flashes (grenade_explosion removed)"
	)
	# (b) the caller's original draw_items must be untouched by the shallow copy +
	# key swap: same Array instance, still holding the unfiltered 2 entries incl
	# the grenade. This is what lets draw() render the grenade explosion zone.
	_expect(
		draw_items["impact_flashes"] is Array and (draw_items["impact_flashes"] as Array).size() == 2,
		"_sync_fx_host must not mutate the caller's impact_flashes (draw() reads the unfiltered set after)"
	)
	_expect(
		draw_items["impact_flashes"] == original_impacts,
		"_sync_fx_host must leave the original impact_flashes Array reference intact"
	)

	host.queue_free()


func _dict_of(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
