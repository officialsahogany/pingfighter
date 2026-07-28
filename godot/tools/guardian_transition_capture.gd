extends SceneTree

# Windowed Vulkan pixel-QA harness for the Guardian summon/stow presentation.
# The canvas calls the production runtime body/front draw passes in their real order.

const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const Smoke := preload("res://tests/lingpet_egg_runtime_smoke.gd")
const OUT_DIR := "D:/tmp/bosspong_guardian_transition_qa"
const VIEW_SIZE := Vector2i(760, 750)


class CaptureCanvas:
	extends Node2D

	var runtime: Object
	var battle_owner: Object

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color(0.035, 0.075, 0.105), true)
		for line in range(7):
			var y := 90.0 + float(line) * 88.0
			draw_line(Vector2(24.0, y), Vector2(736.0, y), Color(0.22, 0.55, 0.58, 0.08), 1.0)
		# Production body pass: behind the player actor.
		runtime.draw_lingpet_body_behind_actors(self)
		var player_pos: Vector2 = battle_owner.player_pos
		var paddle_center := player_pos + Vector2(battle_owner.player_paddle_width * 0.5, battle_owner.player_paddle_height * 0.5)
		draw_circle(paddle_center + Vector2(0.0, -34.0), 22.0, Color(0.18, 0.32, 0.38, 1.0))
		draw_rect(Rect2(player_pos, Vector2(battle_owner.player_paddle_width, battle_owner.player_paddle_height)), Color(0.25, 0.82, 0.78, 0.92), true)
		draw_line(paddle_center + Vector2(-26.0, -56.0), paddle_center + Vector2(26.0, -56.0), Color(0.75, 1.0, 0.92, 0.8), 4.0)
		# Production front pass: projectile/trail/landing and ghost-blink accents.
		runtime.draw(self)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("guardian_transition_capture requires a windowed renderer")
		quit(1)
		return
	if RenderingServer.get_current_rendering_method() != "mobile":
		push_error("Vulkan mobile renderer required, got: %s" % RenderingServer.get_current_rendering_method())
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(OUT_DIR) != OK:
		push_error("failed to create capture directory: %s" % OUT_DIR)
		quit(1)
		return
	for mode in ["summon", "stow"]:
		var bundle: Dictionary = _build_capture_fixture(mode)
		var viewport := SubViewport.new()
		viewport.size = VIEW_SIZE
		viewport.transparent_bg = false
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var canvas := CaptureCanvas.new()
		canvas.runtime = bundle.get("runtime")
		canvas.battle_owner = bundle.get("owner")
		viewport.add_child(canvas)
		canvas.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = viewport.get_texture().get_image()
		var output_path := "%s/guardian_%s_midstream.png" % [OUT_DIR, mode]
		if image == null or image.is_empty() or image.save_png(output_path) != OK:
			push_error("failed to save capture: %s" % output_path)
			quit(1)
			return
		print("[GuardianTransitionCapture] %s" % output_path)
		(bundle.get("runtime") as Object).reset_for_tests()
		root.remove_child(viewport)
		viewport.queue_free()
		await process_frame
	print("[GuardianTransitionCapture] renderer=%s" % RenderingServer.get_current_rendering_method())
	quit(0)


func _build_capture_fixture(mode: String) -> Dictionary:
	var owner := Smoke.FakeOwner.new()
	owner.ai_mode = "champion"
	owner.player_pos = Vector2(302.5, 676.0)
	owner.player_paddle_width = 155.0
	owner.player_paddle_height = 50.0
	owner.lingpet_owned_pet_ids = ["maribo"]
	owner.owned_lingpet_ids = ["maribo"]
	owner.owned_ringpet_ids = ["maribo"]
	owner.lingpet_slots = ["maribo", "", ""]
	owner.ringpet_slots = owner.lingpet_slots.duplicate()
	owner.lingpet_slot_pet_ids = owner.lingpet_slots.duplicate()
	owner.ringpet_slot_pet_ids = owner.lingpet_slots.duplicate()
	owner.lingpet_active_slot_index = 0
	owner.ringpet_active_slot_index = 0
	var registry := Smoke.FakeRegistry.new()
	var runtime: Object = LingpetEggRuntime.new()
	runtime.prewarm_assets()
	runtime.debug_grant_and_activate_pet("maribo", owner, false, "", "", registry)
	runtime.set_duration_pool_for_tests(50.0, 50.0)
	runtime.update(6.1, owner, registry)
	# Pin the live companion after satisfying the six-second minimum so both
	# transition endpoints stay inside the 760x750 production canvas.
	runtime.configure_companion_motion_for_tests(Vector2(245.0, 610.0), 5, 0.0, true)
	runtime.try_toggle_guardian_stow(owner, registry)
	if mode == "summon":
		runtime.update(0.47, owner, registry)
		runtime.try_toggle_guardian_stow(owner, registry)
		runtime.update(0.25, owner, registry)
	else:
		runtime.get("_guardian_transition_state").advance(0.20)
	return {"owner": owner, "runtime": runtime}
