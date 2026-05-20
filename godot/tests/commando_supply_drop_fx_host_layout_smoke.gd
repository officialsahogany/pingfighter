extends SceneTree

const CommandoSupplyDropFxHost := preload("res://scripts/characters/commando_supply_drop_fx_host.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _verify_explosion_anchor_uses_screen_layout()

	if _failures.is_empty():
		print("commando_supply_drop_fx_host_layout_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_explosion_anchor_uses_screen_layout() -> void:
	CommandoSupplyDropFxHost.prewarm_assets()
	var host := CommandoSupplyDropFxHost.new()
	get_root().add_child(host)
	await process_frame

	var snapshot := {
		"explosion_effects": [
			{"pos": Vector2(80.0, 96.0), "radius": 42.0, "life": 0.4, "duration": 0.6},
		],
	}
	var layout_context := {
		"game_offset": Vector2(260.0, 20.0),
		"render_scale": 1.5,
	}
	host.sync_state(snapshot, Vector2(5.0, 4.0), true, layout_context)
	await process_frame

	var status: Dictionary = host.get_debug_status()
	_expect(bool(status.get("active", false)), "supply drop FX host should activate for explosion VFX")
	_expect(not host.is_processing(), "supply drop FX host should stay driven by draw sync instead of detached _process")
	_expect(str(status.get("anchor_source", "")) == "explosion", "supply drop FX host should anchor to explosion VFX first")
	_expect(host.position == Vector2(387.5, 170.0), "supply drop FX host should convert playfield-local explosion anchors into screen layout space")
	_expect(host.scale == Vector2(1.5, 1.5), "supply drop FX host should scale its node-hosted layers with the playfield")

	host.sync_state({}, Vector2.ZERO, false)
	await process_frame
	_expect(not bool(host.get_debug_status().get("active", true)), "supply drop FX host should hide when no supply VFX are active")
	host.tear_down(true)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
