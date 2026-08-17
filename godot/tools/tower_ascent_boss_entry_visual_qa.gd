extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const TowerAscentBossRegistry := preload(
	"res://scripts/tower_ascent/tower_ascent_boss_registry.gd"
)
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)

const OUTPUT_DIR := "res://.godot/codex_captures/tower_boss_integration"
const SUPPORTED_SLOT_IDS := [
	"floor_02_molewang",
	"floor_02_arachne",
	"floor_03_teddy_bear",
	"floor_03_alice",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		_fail("tower boss entry visual QA requires a real window")
		return
	if RenderingServer.get_rendering_device() == null:
		_fail("tower boss entry visual QA requires a Vulkan rendering device")
		return
	var slot_id := _get_slot_argument()
	if slot_id not in SUPPORTED_SLOT_IDS:
		_fail("unsupported tower boss slot: %s" % slot_id)
		return
	var registry := TowerAscentBossRegistry.new()
	var slot := registry.get_slot(slot_id)
	var route := registry.get_standin(slot_id)
	if str(slot.get("status", "")) != TowerAscentBossRegistry.STATUS_PORTED:
		_fail("tower boss slot is not ported: %s" % slot_id)
		return
	var stage_id := int(route.get("stage", 0))
	var variant := str(route.get("variant", ""))
	if stage_id not in [2, 3] or variant.is_empty():
		_fail("tower boss slot has no live battle route: %s" % slot_id)
		return
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_title("승천탑 보스 전투 진입 QA · %s" % slot_id)
	if not _prepare_selection_state(stage_id, variant):
		_fail("GameSelectionState was unavailable for tower battle entry")
		return
	var main_node: Node = MainScene.instantiate()
	get_root().add_child(main_node)
	for _frame in range(4):
		await process_frame
	if int(main_node.get("current_stage")) != stage_id:
		_fail("battle scene did not consume the tower stage route")
		return
	if str(main_node.get("stage_boss_variant")) != variant:
		_fail("battle scene did not consume the tower boss variant route")
		return
	_prepare_battle_scene(main_node)
	for _frame in range(10):
		main_node.queue_redraw()
		await process_frame
	var image := get_root().get_texture().get_image()
	if image == null or image.is_empty():
		_fail("tower boss battle-entry capture was empty")
		return
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		_fail("could not create tower boss capture directory")
		return
	var output_path := output_dir.path_join("%s_battle_entry.png" % slot_id)
	if image.save_png(output_path) != OK:
		_fail("could not save tower boss battle-entry capture: %s" % output_path)
		return
	print("[TowerBossEntryVisualQA] flag=ON slot=%s stage=%d variant=%s evidence=%s" % [
		slot_id,
		stage_id,
		variant,
		output_path,
	])
	print("tower_ascent_boss_entry_visual_qa: ok")
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	main_node.queue_free()
	await process_frame
	quit(0)


func _prepare_selection_state(stage_id: int, variant: String) -> bool:
	var selection_state := get_root().get_node_or_null("GameSelectionState")
	if selection_state == null or not selection_state.has_method("set_stage"):
		return false
	if selection_state.has_method("set_character"):
		selection_state.set_character({
			"id": "smasher",
			"runtime_id": "smasher",
			"name": "스매셔",
		})
	selection_state.set_stage(stage_id, "dalji", false, variant)
	if selection_state.has_method("set_league_mode"):
		selection_state.set_league_mode("champion")
	if selection_state.has_method("request_skip_battle_logo_once"):
		selection_state.request_skip_battle_logo_once()
	return true


func _prepare_battle_scene(main_node: Node) -> void:
	if main_node.has_method("_initialize_battle"):
		main_node.call("_initialize_battle", false)
	if main_node.has_method("configure_player_character"):
		main_node.call("configure_player_character", "smasher")
	var warmup: Object = _get_module(main_node, "battle_boot_warmup_controller")
	if warmup != null:
		warmup.set("boot_warmup_finished", true)
		warmup.set("boot_warmup_step", 999)
	var logo_intro: Object = _get_module(main_node, "penguin_logo_intro")
	if logo_intro != null:
		logo_intro.set("active", false)
	var flow: Object = _get_module(main_node, "battle_scene_flow_controller")
	if flow != null:
		flow.set("_battle_initialized", true)
		flow.set("_stage_landing_intro_started", true)
		flow.set("_ball_spawn_intro_started", true)
	var landing_intro: Object = _get_module(main_node, "stage_landing_intro")
	if landing_intro != null:
		landing_intro.set("active", false)
	var ball_spawn_intro: Object = _get_module(main_node, "stage_ball_spawn_intro")
	if ball_spawn_intro != null:
		if ball_spawn_intro.has_method("reset"):
			ball_spawn_intro.reset()
		ball_spawn_intro.set("active", false)
		ball_spawn_intro.set("overlay_active", false)
	var round_state: Object = _get_module(main_node, "round_flow_state")
	if round_state != null and round_state.has_method("begin_serve"):
		round_state.begin_serve(Time.get_ticks_msec())
	main_node.set("ball_active", true)
	main_node.set("waiting_for_serve", false)
	main_node.set("boss_pos", Vector2(325.0, 25.0))
	main_node.set("player_pos", Vector2(310.0, 650.0))
	main_node.queue_redraw()


func _get_module(main_node: Node, key: String) -> Object:
	if main_node == null or not main_node.has_method("_get_module"):
		return null
	var value: Variant = main_node.call("_get_module", key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _get_slot_argument() -> String:
	for argument in OS.get_cmdline_user_args():
		var value := str(argument)
		if value.begins_with("--tower-boss-slot="):
			return value.trim_prefix("--tower-boss-slot=").strip_edges().to_lower()
	return "floor_02_molewang"


func _fail(message: String) -> void:
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	push_error(message)
	quit(1)
