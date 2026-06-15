extends SceneTree

# One-off visual QA harness for the S4 side-scroll plaza shell.
# Renders plaza_scene onto a SubViewport at several player positions and saves
# PNGs so the layering / parallax / building scale can be eyeballed without a
# full battle. Run WITHOUT --headless (dummy driver returns a blank image).
# Not a smoke test -- safe to delete.

const PlazaScene := preload("res://scripts/plaza/plaza_scene.gd")

const VIEW := Vector2i(1488, 918)
const DEFAULT_STAGE_ID := 1
const DEFAULT_OUT_DIR := "d:/tmp/plaza_s4"


class CaptureOwner:
	extends Node2D

	var selected_character_type := "smasher"
	var active_lingpet_id := ""
	var current_lingpet_id := ""
	var lingpet_id := ""
	var lingpet_state := "none"

	func _init(character_type: String, pet_id: String) -> void:
		selected_character_type = character_type
		if pet_id == "":
			return
		active_lingpet_id = pet_id
		current_lingpet_id = pet_id
		lingpet_id = pet_id
		lingpet_state = "companion"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("plaza_scene_capture must run WITHOUT --headless")
		quit(1)
		return
	var stage_id: int = _get_int_arg("--plaza-stage=", DEFAULT_STAGE_ID)
	var out_dir: String = _get_string_arg("--plaza-out=", DEFAULT_OUT_DIR)
	var character_type: String = _get_string_arg("--plaza-character=", "smasher")
	var lingpet_id: String = _get_string_arg("--plaza-lingpet=", "")
	DirAccess.make_dir_recursive_absolute(out_dir)

	var viewport := SubViewport.new()
	viewport.size = VIEW
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)

	var plaza: Control = PlazaScene.new()
	plaza.set("_driven_by_controller", true)
	viewport.add_child(plaza)
	var capture_owner := CaptureOwner.new(character_type, lingpet_id)
	viewport.add_child(capture_owner)
	var map_seed: int = _get_int_arg("--plaza-map-seed=", 0)
	var configure_data: Dictionary = {
		"current_stage": stage_id,
		"plaza_save_path": "user://plaza_scene_capture_stage%d.cfg" % stage_id,
		"runtime_owner": capture_owner,
		"selected_character_type": character_type,
	}
	if map_seed > 0:
		configure_data["map_seed"] = map_seed
	plaza.configure(configure_data, Callable(), true)
	plaza.call("_sync_game_rect")
	var status: Dictionary = plaza.call("get_status")
	var world_size: Vector2 = status.get("world_size", Vector2(1900.0, 750.0))
	var world_width: float = max(760.0, world_size.x)

	# Sweep several camera positions across the current side-scroll street.
	var shots: Dictionary = {
		"spawn_left": 120.0,
		"buildings_a": world_width * 0.35,
		"buildings_b": world_width * 0.58,
		"buildings_c": world_width * 0.78,
		"exit_right": world_width - 60.0,
	}
	for tag in shots.keys():
		plaza.call("set_player_pos_for_test", Vector2(float(shots[tag]), 666.0))
		plaza.queue_redraw()
		await process_frame
		await process_frame
		var image: Image = viewport.get_texture().get_image()
		var out_path: String = "%s/plaza_stage%d_%s.png" % [out_dir, stage_id, str(tag)]
		image.save_png(out_path)
		print("[PlazaCapture] %s (player_x=%s) -> %s" % [str(tag), str(shots[tag]), out_path])

	plaza.call("set_player_pos_for_test", Vector2(world_width * 0.8, 666.0))
	plaza.queue_redraw()
	await process_frame
	var flicker_a: Image = viewport.get_texture().get_image()
	var flicker_a_path: String = "%s/plaza_stage%d_flicker_tick_a.png" % [out_dir, stage_id]
	flicker_a.save_png(flicker_a_path)
	await process_frame
	await process_frame
	await process_frame
	plaza.queue_redraw()
	await process_frame
	var flicker_b: Image = viewport.get_texture().get_image()
	var flicker_b_path: String = "%s/plaza_stage%d_flicker_tick_b.png" % [out_dir, stage_id]
	flicker_b.save_png(flicker_b_path)
	print("[PlazaCapture] flicker ticks -> %s / %s" % [flicker_a_path, flicker_b_path])

	var menu_target: Dictionary = _get_capture_menu_target(plaza)
	if not menu_target.is_empty():
		var interaction_rect: Rect2 = menu_target.get("interaction_rect", Rect2())
		var menu_type: String = str(menu_target.get("type", "building"))
		plaza.call("set_player_pos_for_test", Vector2(interaction_rect.get_center().x, 666.0))
		plaza.call("trigger_interaction_for_test", false)
		plaza.call("advance_building_transition_for_test", 0.50)
		plaza.queue_redraw()
		await process_frame
		await process_frame
		var warp_enter_image: Image = viewport.get_texture().get_image()
		var warp_enter_path: String = "%s/plaza_stage%d_warp_enter_%s_mid.png" % [out_dir, stage_id, menu_type]
		warp_enter_image.save_png(warp_enter_path)
		print("[PlazaCapture] warp_enter_%s_mid -> %s" % [menu_type, warp_enter_path])
		plaza.call("advance_building_transition_for_test", 0.60)
		plaza.queue_redraw()
		await process_frame
		await process_frame
		var menu_image: Image = viewport.get_texture().get_image()
		var menu_path: String = "%s/plaza_stage%d_menu_%s.png" % [out_dir, stage_id, menu_type]
		menu_image.save_png(menu_path)
		print("[PlazaCapture] menu_%s -> %s" % [menu_type, menu_path])
		plaza.call("close_menu_for_test", false)
		plaza.call("advance_building_transition_for_test", 0.50)
		plaza.queue_redraw()
		await process_frame
		await process_frame
		var warp_return_image: Image = viewport.get_texture().get_image()
		var warp_return_path: String = "%s/plaza_stage%d_warp_return_%s_mid.png" % [out_dir, stage_id, menu_type]
		warp_return_image.save_png(warp_return_path)
		print("[PlazaCapture] warp_return_%s_mid -> %s" % [menu_type, warp_return_path])

	print("[PlazaCapture] done")
	quit(0)


func _get_string_arg(prefix: String, fallback: String) -> String:
	for arg in OS.get_cmdline_args():
		var text: String = str(arg)
		if text.begins_with(prefix):
			var value: String = text.substr(prefix.length()).strip_edges()
			return value if value != "" else fallback
	return fallback


func _get_int_arg(prefix: String, fallback: int) -> int:
	return int(_get_string_arg(prefix, str(fallback)))


func _get_capture_menu_target(plaza: Control) -> Dictionary:
	var specs: Array[Dictionary] = plaza.call("get_building_specs_for_test")
	for spec in specs:
		if str(spec.get("type", "")) == "bank":
			return spec
	return specs[0] if not specs.is_empty() else {}
