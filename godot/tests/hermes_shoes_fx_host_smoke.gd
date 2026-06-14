extends SceneTree

const BattleViewLayout := preload("res://scripts/core/battle_view_layout.gd")
const HermesFieldRenderer := preload("res://scripts/items/mythic_item_hermes_field_renderer.gd")
const HermesShoesFxHost := preload("res://scripts/items/mythic_item_hermes_shoes_fx_host.gd")
const HermesShoesState := preload("res://scripts/items/hermes_shoes_state.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _verify_fx_host_screen_space_sync()
	await _verify_round_reset_tears_down_attached_host()
	await process_frame
	if _failures.is_empty():
		print("hermes_shoes_fx_host_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_fx_host_screen_space_sync() -> void:
	var canvas := Node2D.new()
	get_root().add_child(canvas)
	var renderer: Object = HermesFieldRenderer.new()
	var state: Object = HermesShoesState.new()
	state.player_center = Vector2(382.0, 714.0)
	state.player_size = Vector2(155.0, 50.0)
	state.last_move_delta_x = 13.0
	var shake_offset := Vector2(4.0, -2.0)

	renderer.draw_hermes_shoes_effect(canvas, shake_offset, state, true, 24.0, 2.0)
	await process_frame
	renderer.draw_hermes_shoes_effect(canvas, shake_offset, state, true, 24.0, 2.0)
	await process_frame

	var host: Node = canvas.get_node_or_null("MythicHermesShoesFxHost")
	_expect(host != null, "Hermes Shoes renderer should attach a named FX host")
	if host == null:
		canvas.queue_free()
		return
	_expect(host.get_script() == HermesShoesFxHost, "attached Hermes Shoes host should use the dedicated FX host type")
	_expect(host.has_method("get_debug_status"), "Hermes Shoes FX host should expose debug status for render smoke coverage")
	if not host.has_method("get_debug_status"):
		canvas.queue_free()
		return

	var layout: Dictionary = BattleViewLayout.new().build_game_layout(
		canvas.get_viewport_rect().size,
		760.0,
		750.0
	)
	var game_offset: Vector2 = _as_vector2(layout.get("game_offset", Vector2.ZERO), Vector2.ZERO)
	var render_scale: float = max(0.001, float(layout.get("render_scale", 1.0)))
	var expected_screen_pos: Vector2 = game_offset + (state.player_center + shake_offset) * render_scale
	_expect(
		(host as Node2D).position.distance_to(expected_screen_pos) <= 0.01,
		"Hermes Shoes FX host should receive screen-space position; raw playfield coords are invisible/misaligned in letterboxed views"
	)
	_expect(
		(host as Node2D).scale.distance_to(Vector2(render_scale, render_scale)) <= 0.001,
		"Hermes Shoes FX host scale should match the playfield render_scale"
	)
	var status: Dictionary = host.get_debug_status()
	_expect(int(status.get("z_index", -999)) > 0, "Hermes Shoes FX host must render above the custom-drawn playfield background")
	_expect(bool(status.get("visible", false)), "active Hermes Shoes FX host should be visible")
	_expect(bool(status.get("glow_visible", false)), "active Hermes Shoes FX host should show the shader underglow")
	_expect(int(status.get("wake_sprite_count", 0)) >= 7, "Hermes Shoes FX host should build texture sparkle wake sprites")
	_expect(int(status.get("wake_visible_count", 0)) > 0, "active Hermes Shoes movement should show texture sparkle wake pieces")
	_expect(bool(status.get("trail_emitting", false)), "active Hermes Shoes should emit GPU trail particles")
	_expect(not bool(status.get("trail_local_coords", true)), "Hermes Shoes trail particles should remain in screen space instead of sticking to the paddle")

	if host.has_method("tear_down"):
		host.tear_down()
		await process_frame
		var cleared_status: Dictionary = host.get_debug_status()
		_expect(not bool(cleared_status.get("visible", true)), "tear_down should hide the Hermes Shoes FX host")
		_expect(not bool(cleared_status.get("trail_emitting", true)), "tear_down should stop Hermes Shoes trail particles")

	canvas.queue_free()


func _verify_round_reset_tears_down_attached_host() -> void:
	var canvas := Node2D.new()
	get_root().add_child(canvas)
	var runtime: Object = MythicItemRuntime.new()
	while not runtime.prewarm_initialization_step(false):
		pass
	runtime.equipped_items["hermes_shoes"] = {
		"name": "hermes_shoes",
		"equipped": true,
		"_equipped_slot": "shoes",
	}
	runtime.hermes_shoes_state.player_center = Vector2(382.0, 714.0)
	runtime.hermes_shoes_state.player_size = Vector2(155.0, 50.0)
	runtime.hermes_shoes_state.last_move_delta_x = 13.0

	runtime.draw_field_effects(canvas, null, Vector2.ZERO, null, null, {})
	await process_frame
	runtime.draw_field_effects(canvas, null, Vector2.ZERO, null, null, {})
	await process_frame

	var host: Node = canvas.get_node_or_null("MythicHermesShoesFxHost")
	_expect(host != null, "Hermes Shoes runtime draw should attach the FX host before round reset")
	if host == null or not host.has_method("get_debug_status"):
		canvas.queue_free()
		return
	var active_status: Dictionary = host.get_debug_status()
	_expect(bool(active_status.get("visible", false)), "active Hermes Shoes host should be visible before round reset")
	_expect(bool(active_status.get("trail_emitting", false)), "active Hermes Shoes host should emit particles before round reset")

	runtime.reset_round(null)
	await process_frame

	var reset_status: Dictionary = host.get_debug_status()
	_expect(not bool(reset_status.get("visible", true)), "Hermes Shoes round reset should hide the detached FX host without waiting for another draw")
	_expect(not bool(reset_status.get("trail_emitting", true)), "Hermes Shoes round reset should stop old trail particles")
	_expect(not bool(reset_status.get("spark_emitting", true)), "Hermes Shoes round reset should stop old spark particles")

	canvas.queue_free()


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
