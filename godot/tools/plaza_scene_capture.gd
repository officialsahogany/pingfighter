extends SceneTree

# Durable visual-QA harness for the retained R1 side-scroll bridge and later
# map-promotion comparisons. `--plaza-view=2020x1246` owns the R1-F sharpness
# evidence surface; the default remains the earlier 1488x918 art-sweep size.
# Renders plaza_scene onto a SubViewport at several player positions and saves
# PNGs so the layering / parallax / building scale can be eyeballed without a
# full battle. Run WITHOUT --headless (dummy driver returns a blank image).
# This is a windowed QA tool, not a headless nightly smoke.

const PlazaScene := preload("res://scripts/plaza/plaza_scene.gd")

const DEFAULT_VIEW := Vector2i(1488, 918)
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
	var menu_type_arg: String = _get_string_arg("--plaza-menu-type=", "bank")
	var full_layout: bool = _get_bool_arg("--plaza-full-layout=", false)
	var capture_size: Vector2i = _get_vector2i_arg("--plaza-view=", DEFAULT_VIEW)
	DirAccess.make_dir_recursive_absolute(out_dir)

	var viewport := SubViewport.new()
	viewport.size = capture_size
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
		"play_arrival_transition": true,
		"full_layout_for_test": full_layout,
	}
	if map_seed > 0:
		configure_data["map_seed"] = map_seed
	plaza.configure(configure_data, Callable(), true)
	plaza.call("_sync_game_rect")
	plaza.call("advance_plaza_warp_transition_for_test", 0.50)
	_sync_retained_world(plaza)
	await process_frame
	await process_frame
	var arrive_image: Image = viewport.get_texture().get_image()
	var arrive_path: String = "%s/plaza_stage%d_warp_arrive_mid.png" % [out_dir, stage_id]
	arrive_image.save_png(arrive_path)
	print("[PlazaCapture] warp_arrive_mid -> %s" % arrive_path)
	plaza.call("advance_plaza_warp_transition_for_test", 0.60)
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
		_sync_retained_world(plaza)
		await process_frame
		await process_frame
		var image: Image = viewport.get_texture().get_image()
		var out_path: String = "%s/plaza_stage%d_%s.png" % [out_dir, stage_id, str(tag)]
		image.save_png(out_path)
		print("[PlazaCapture] %s (player_x=%s) -> %s" % [str(tag), str(shots[tag]), out_path])

	plaza.call("set_player_pos_for_test", Vector2(world_width * 0.8, 666.0))
	_sync_retained_world(plaza)
	await process_frame
	var flicker_a: Image = viewport.get_texture().get_image()
	var flicker_a_path: String = "%s/plaza_stage%d_flicker_tick_a.png" % [out_dir, stage_id]
	flicker_a.save_png(flicker_a_path)
	await process_frame
	await process_frame
	await process_frame
	_sync_retained_world(plaza)
	await process_frame
	var flicker_b: Image = viewport.get_texture().get_image()
	var flicker_b_path: String = "%s/plaza_stage%d_flicker_tick_b.png" % [out_dir, stage_id]
	flicker_b.save_png(flicker_b_path)
	print("[PlazaCapture] flicker ticks -> %s / %s" % [flicker_a_path, flicker_b_path])

	var menu_target: Dictionary = _get_capture_menu_target(plaza, menu_type_arg)
	if not menu_target.is_empty():
		var interaction_rect: Rect2 = menu_target.get("interaction_rect", Rect2())
		var menu_type: String = str(menu_target.get("type", "building"))
		plaza.call("set_player_pos_for_test", Vector2(interaction_rect.get_center().x, 666.0))
		plaza.call("trigger_interaction_for_test", false)
		plaza.call("advance_building_transition_for_test", 0.50)
		_sync_retained_world(plaza)
		await process_frame
		await process_frame
		var building_enter_image: Image = viewport.get_texture().get_image()
		var building_enter_path: String = "%s/plaza_stage%d_building_enter_%s_mid.png" % [out_dir, stage_id, menu_type]
		building_enter_image.save_png(building_enter_path)
		print("[PlazaCapture] building_enter_%s_mid -> %s" % [menu_type, building_enter_path])
		plaza.call("advance_building_transition_for_test", 0.60)
		_sync_retained_world(plaza)
		await process_frame
		await process_frame
		var menu_image: Image = viewport.get_texture().get_image()
		var menu_path: String = "%s/plaza_stage%d_menu_%s.png" % [out_dir, stage_id, menu_type]
		menu_image.save_png(menu_path)
		print("[PlazaCapture] menu_%s -> %s" % [menu_type, menu_path])
		if menu_type == "shop":
			plaza.call("click_interior_object_for_test", "shop_strewn_coin_pile")
			plaza.queue_redraw()
			await process_frame
			await process_frame
			var shop_click_image: Image = viewport.get_texture().get_image()
			var shop_click_path: String = "%s/plaza_stage%d_menu_%s_click.png" % [out_dir, stage_id, menu_type]
			shop_click_image.save_png(shop_click_path)
			print("[PlazaCapture] menu_%s_click -> %s" % [menu_type, shop_click_path])
			plaza.call("advance_interior_view_for_test", 0.75)
			plaza.queue_redraw()
			await process_frame
			await process_frame
			var shop_trade_image: Image = viewport.get_texture().get_image()
			var shop_trade_path: String = "%s/plaza_stage%d_menu_%s_trade.png" % [out_dir, stage_id, menu_type]
			shop_trade_image.save_png(shop_trade_path)
			print("[PlazaCapture] menu_%s_trade -> %s" % [menu_type, shop_trade_path])
		plaza.call("close_menu_for_test", false)
		plaza.call("advance_building_transition_for_test", 0.50)
		_sync_retained_world(plaza)
		await process_frame
		await process_frame
		var building_return_image: Image = viewport.get_texture().get_image()
		var building_return_path: String = "%s/plaza_stage%d_building_return_%s_mid.png" % [out_dir, stage_id, menu_type]
		building_return_image.save_png(building_return_path)
		print("[PlazaCapture] building_return_%s_mid -> %s" % [menu_type, building_return_path])
		plaza.call("advance_building_transition_for_test", 0.60)

	plaza.call("set_player_pos_for_test", Vector2(world_width - 75.0, 666.0))
	plaza.call("trigger_interaction_for_test", false)
	plaza.call("advance_plaza_warp_transition_for_test", 0.50)
	_sync_retained_world(plaza)
	await process_frame
	await process_frame
	var exit_warp_image: Image = viewport.get_texture().get_image()
	var exit_warp_path: String = "%s/plaza_stage%d_warp_exit_mid.png" % [out_dir, stage_id]
	exit_warp_image.save_png(exit_warp_path)
	print("[PlazaCapture] warp_exit_mid -> %s" % exit_warp_path)

	print("[PlazaCapture] done")
	quit(0)


func _sync_retained_world(plaza: Control) -> void:
	# This capture owns a controller-driven PlazaScene. Retained children only
	# consume camera/tick changes through the same owner update used in runtime.
	plaza.call("update_plaza", 0.0)
	plaza.queue_redraw()


func _get_string_arg(prefix: String, fallback: String) -> String:
	var all_args: Array = OS.get_cmdline_user_args() + OS.get_cmdline_args()
	for arg in all_args:
		var text: String = str(arg)
		if text.begins_with(prefix):
			var value: String = text.substr(prefix.length()).strip_edges()
			return value if value != "" else fallback
	return fallback


func _get_int_arg(prefix: String, fallback: int) -> int:
	return int(_get_string_arg(prefix, str(fallback)))


func _get_bool_arg(prefix: String, fallback: bool) -> bool:
	var value := _get_string_arg(prefix, "1" if fallback else "0").to_lower()
	return ["1", "true", "yes", "on"].has(value)


func _get_vector2i_arg(prefix: String, fallback: Vector2i) -> Vector2i:
	var value := _get_string_arg(prefix, "%dx%d" % [fallback.x, fallback.y]).to_lower()
	var parts := value.split("x", false, 1)
	if parts.size() != 2:
		return fallback
	var parsed := Vector2i(int(parts[0]), int(parts[1]))
	return parsed if parsed.x > 0 and parsed.y > 0 else fallback


func _get_capture_menu_target(plaza: Control, desired_type: String) -> Dictionary:
	var specs: Array[Dictionary] = plaza.call("get_building_specs_for_test")
	for spec in specs:
		if str(spec.get("type", "")) == desired_type:
			return spec
	return specs[0] if not specs.is_empty() else {}
