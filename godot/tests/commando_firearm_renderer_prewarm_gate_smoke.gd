extends SceneTree

const Stage1CommandoFirearmRenderer := preload("res://scripts/stages/stage1/stage1_commando_firearm_renderer.gd")
const Stage1CommandoFirearmFxHost := preload("res://scripts/stages/stage1/stage1_commando_firearm_fx_host.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_prewarm_idempotence()
	_verify_has_anything_to_draw()
	_verify_draw_early_return_when_inactive()

	if _failures.is_empty():
		print("commando_firearm_renderer_prewarm_gate_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_prewarm_idempotence() -> void:
	Stage1CommandoFirearmRenderer.reset_prewarm_cache_for_test()
	Stage1CommandoFirearmFxHost.reset_prewarm_cache_for_test()
	_expect(not Stage1CommandoFirearmRenderer._prewarmed, "renderer prewarm flag should start false after reset")
	_expect(not Stage1CommandoFirearmFxHost._prewarmed, "fx_host prewarm flag should start false after reset")
	_expect(not Stage1CommandoFirearmRenderer.prewarm_assets_step(), "renderer staged prewarm should expose its first chunk")
	_expect(not Stage1CommandoFirearmRenderer._prewarmed, "renderer staged prewarm should not latch after one chunk")
	var staged_guard := 0
	while not Stage1CommandoFirearmRenderer.prewarm_assets_step() and staged_guard < 40:
		staged_guard += 1
	_expect(staged_guard < 40, "renderer staged prewarm should finish within its declared chunks")
	_expect(Stage1CommandoFirearmRenderer._prewarmed, "renderer staged prewarm should latch true when chunks finish")
	Stage1CommandoFirearmRenderer.reset_prewarm_cache_for_test()
	Stage1CommandoFirearmFxHost.reset_prewarm_cache_for_test()
	Stage1CommandoFirearmRenderer.prewarm_assets()
	_expect(Stage1CommandoFirearmRenderer._prewarmed, "renderer prewarm flag should latch true after first call")
	_expect(Stage1CommandoFirearmFxHost._prewarmed, "fx_host prewarm flag should latch true via the renderer prewarm dispatch")
	# Second call should short-circuit. We cannot detect that directly without a counter,
	# but we can verify it does not throw and the flag remains true.
	Stage1CommandoFirearmRenderer.prewarm_assets()
	_expect(Stage1CommandoFirearmRenderer._prewarmed, "renderer prewarm flag should stay true across repeated calls")
	Stage1CommandoFirearmRenderer.reset_prewarm_cache_for_test()
	Stage1CommandoFirearmFxHost.reset_prewarm_cache_for_test()


func _verify_has_anything_to_draw() -> void:
	_expect(not Stage1CommandoFirearmRenderer.has_anything_to_draw({}), "empty context should report no commando state")
	_expect(not Stage1CommandoFirearmRenderer.has_anything_to_draw({"commando_firearm_projectiles": []}), "empty projectile array should report no commando state")
	var expected_keys := [
		"commando_firearm_projectiles",
		"commando_firearm_muzzle_flashes",
		"commando_firearm_impact_flashes",
		"commando_firearm_lingering_effects",
		"commando_firearm_shell_casings",
		"commando_firearm_pistol_feedbacks",
		"commando_firearm_support_calls",
		"commando_firearm_bowling_traps",
	]
	for key in expected_keys:
		var context: Dictionary = {key: [{"pos": Vector2.ZERO}]}
		_expect(
			Stage1CommandoFirearmRenderer.has_anything_to_draw(context),
			"context with a non-empty %s array should report commando state present" % key
		)


func _verify_draw_early_return_when_inactive() -> void:
	# When no commando arrays are populated AND there is no fx_host yet, draw()
	# must short-circuit before reaching `prewarm_assets()`. We detect the short
	# circuit by verifying the prewarm flag is NOT latched after the call.
	Stage1CommandoFirearmRenderer.reset_prewarm_cache_for_test()
	Stage1CommandoFirearmFxHost.reset_prewarm_cache_for_test()
	var renderer := Stage1CommandoFirearmRenderer.new()
	var canvas := Node2D.new()
	get_root().add_child(canvas)
	renderer.draw(canvas, {}, Vector2.ZERO)
	_expect(
		not Stage1CommandoFirearmRenderer._prewarmed,
		"draw() with empty context and no fx_host should early-return before prewarm dispatch"
	)
	# Verifying the positive branch (commando state present → draw proceeds → prewarm
	# latches) is left to the existing `commando_firearm_renderer_fx_host_lifecycle`
	# and `commando_firearm_stage1_visual_qa` smokes. Calling draw() here with active
	# state would invoke `draw_polygon`/`draw_line` on a Node2D outside its `_draw()`
	# callback, which Godot rejects with a non-fatal error that trips the smoke
	# harness's strict-error check.
	canvas.queue_free()
	Stage1CommandoFirearmRenderer.reset_prewarm_cache_for_test()
	Stage1CommandoFirearmFxHost.reset_prewarm_cache_for_test()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
