extends SceneTree

const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const YanguiHoechunFieldRenderer := preload("res://scripts/items/mythic_item_yangui_hoechun_field_renderer.gd")


class FakeOwner:
	var special_gauge := 100.0
	var player_pos := Vector2(300.0, 690.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var ball_active := true
	var ball_pos := Vector2(329.5, 675.0)
	var ball_vel := Vector2(5.0, 12.0)
	var ball_radius := 14.3
	var ball_size := 28.6


class FakeRegistry:
	func get_instance(_key: String) -> Object:
		return null


class DrawProbe:
	extends Node2D

	var renderer: Object = null
	var context: Dictionary = {}
	var draw_calls := 0

	func _draw() -> void:
		draw_calls += 1
		renderer.draw_effect(self, Vector2.ZERO, context)


func _init() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	var runtime: Object = MythicItemRuntime.new()
	while not runtime.prewarm_initialization_step(false):
		pass
	var perk_state: Object = RuntimePerkState.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	runtime.runtime_perk_state_ref = perk_state
	perk_state.runtime_skill_levels["yangui_hoechun"] = 1

	_expect(is_equal_approx(runtime.yangui_hoechun_runtime.get_trigger_chance(), 0.5), "양의회천 trigger chance should be 50%")
	_expect(is_equal_approx(runtime.yangui_hoechun_runtime.get_gauge_cost(), 30.0), "양의회천 gauge cost should be 30")

	# 0.49 succeeds, spends exactly 30, and emits one wave on each side.
	runtime.yangui_hoechun_runtime.set_test_proc_rolls([0.49])
	perk_state.notify_perk_fusion_skill_used()
	_expect(perk_state.peek_pending_chosik_activations() == 1, "shared Chosik signal should queue one activation")
	runtime.yangui_hoechun_runtime.update_runtime(runtime, owner, registry, 0.0)
	_expect(perk_state.peek_pending_chosik_activations() == 0, "runtime should consume the queued Chosik signal")
	_expect(is_equal_approx(owner.special_gauge, 70.0), "successful activation should spend exactly 30 gauge")
	var context: Dictionary = runtime.yangui_hoechun_runtime.get_draw_context()
	_expect(bool(context.get("wave_active", false)), "successful activation should start the paired energy wave")
	_expect(float(context.get("left_front_x", 0.0)) < float(context.get("origin", Vector2.ZERO).x), "left wave should start left of the player")
	_expect(float(context.get("right_front_x", 0.0)) > float(context.get("origin", Vector2.ZERO).x), "right wave should start right of the player")

	# A descending ball touching the left wave reflects upward without changing speed.
	var speed_before := owner.ball_vel.length()
	runtime.yangui_hoechun_runtime.update_runtime(runtime, owner, registry, 0.001)
	_expect(owner.ball_vel.y < 0.0, "descending ball should reflect upward")
	_expect(is_equal_approx(owner.ball_vel.length(), speed_before), "reflection should preserve ball speed")
	context = runtime.yangui_hoechun_runtime.get_draw_context()
	_expect(int(context.get("last_reflect_side", 0)) == -1, "left energy wave should record the reflection side")
	owner.ball_vel = Vector2(5.0, 12.0)
	runtime.yangui_hoechun_runtime.update_runtime(runtime, owner, registry, 0.001)
	_expect(owner.ball_vel.y > 0.0, "one emitted pair should not reflect the same ball repeatedly")

	# The exact 50% boundary fails and must not spend gauge.
	runtime.yangui_hoechun_runtime.clear_runtime()
	owner.special_gauge = 100.0
	runtime.yangui_hoechun_runtime.set_test_proc_rolls([0.50])
	perk_state.notify_perk_fusion_skill_used()
	runtime.yangui_hoechun_runtime.update_runtime(runtime, owner, registry, 0.0)
	_expect(is_equal_approx(owner.special_gauge, 100.0), "failed 50% roll should not spend gauge")
	_expect(not runtime.yangui_hoechun_runtime.is_wave_active(), "failed roll should not emit waves")

	# Exact cost is accepted; insufficient gauge fails before rolling or spending.
	owner.special_gauge = 30.0
	runtime.yangui_hoechun_runtime.set_test_proc_rolls([0.10])
	perk_state.notify_perk_fusion_skill_used()
	runtime.yangui_hoechun_runtime.update_runtime(runtime, owner, registry, 0.0)
	_expect(is_equal_approx(owner.special_gauge, 0.0), "exactly 30 gauge should activate and drain to zero")
	runtime.yangui_hoechun_runtime.clear_runtime()
	owner.special_gauge = 29.0
	runtime.yangui_hoechun_runtime.set_test_proc_rolls([0.10])
	perk_state.notify_perk_fusion_skill_used()
	runtime.yangui_hoechun_runtime.update_runtime(runtime, owner, registry, 0.0)
	_expect(is_equal_approx(owner.special_gauge, 29.0), "insufficient gauge should remain unchanged")
	_expect(not runtime.yangui_hoechun_runtime.is_wave_active(), "insufficient gauge should not emit waves")

	# An ascending ball passes through; round reset clears both VFX and queued events.
	owner.special_gauge = 100.0
	owner.ball_vel = Vector2(5.0, -12.0)
	runtime.yangui_hoechun_runtime.set_test_proc_rolls([0.10])
	perk_state.notify_perk_fusion_skill_used()
	runtime.yangui_hoechun_runtime.update_runtime(runtime, owner, registry, 0.001)
	_expect(owner.ball_vel.y < 0.0, "ascending ball should not be redirected")
	perk_state.notify_perk_fusion_skill_used()
	perk_state.reset_perk_fusion_round_byproducts()
	_expect(perk_state.peek_pending_chosik_activations() == 0, "round reset should clear queued Chosik activations")
	runtime.reset_round(registry)
	_expect(not runtime.yangui_hoechun_runtime.has_visible_effects(), "round reset should clear 양의회천 VFX")

	# Unowned events are consumed rather than firing later after acquisition.
	perk_state.runtime_skill_levels.erase("yangui_hoechun")
	perk_state.notify_perk_fusion_skill_used()
	runtime.yangui_hoechun_runtime.update_runtime(runtime, owner, registry, 0.0)
	perk_state.runtime_skill_levels["yangui_hoechun"] = 1
	owner.special_gauge = 100.0
	runtime.yangui_hoechun_runtime.update_runtime(runtime, owner, registry, 0.0)
	_expect(is_equal_approx(owner.special_gauge, 100.0), "unowned Chosik events must not survive until later acquisition")

	# The public mythic update facade must consume the same event on its idle path.
	owner.ball_active = false
	runtime.yangui_hoechun_runtime.set_test_proc_rolls([0.10])
	perk_state.notify_perk_fusion_skill_used()
	runtime.update(owner, registry, 0.0)
	_expect(is_equal_approx(owner.special_gauge, 70.0), "public mythic update should execute 양의회천 on the idle path")
	owner.ball_active = true

	# Real CanvasItem._draw path must accept the paired-wave context without errors.
	owner.special_gauge = 100.0
	runtime.yangui_hoechun_runtime.set_test_proc_rolls([0.10])
	perk_state.notify_perk_fusion_skill_used()
	runtime.yangui_hoechun_runtime.update_runtime(runtime, owner, registry, 0.0)
	var probe := DrawProbe.new()
	probe.renderer = YanguiHoechunFieldRenderer.new()
	probe.context = runtime.yangui_hoechun_runtime.get_draw_context()
	root.add_child(probe)
	probe.queue_redraw()
	await process_frame
	await process_frame
	_expect(probe.draw_calls > 0, "양의회천 VFX should render through a real CanvasItem._draw call")
	probe.queue_free()
	await process_frame

	PerkConversionFlags.debug_set_enabled(false)
	print("yangui_hoechun_runtime_smoke: ok")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	PerkConversionFlags.debug_set_enabled(false)
	quit(1)
