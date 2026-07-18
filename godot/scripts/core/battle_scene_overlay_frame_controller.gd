extends RefCounted

const CharacterInfoOverlayHost := preload("res://scripts/hud/character_info_overlay_host.gd")
const BattleSceneOverlayFrameUtils := preload("res://scripts/core/battle_scene_overlay_frame_utils.gd")
const BattleViewLayout := preload("res://scripts/core/battle_view_layout.gd")
const AngelBlessingRollOverlayHost := preload("res://scripts/hud/angel_blessing_roll_overlay_host.gd")
const PerkFusionColdBootCinematicRuntime := preload("res://scripts/hud/perk_fusion_cold_boot_cinematic_runtime.gd")

const CLEAN_CAPTURE_ENV := "PINGFIGHTER_BATTLE_PERF_CLEAN_CAPTURE"
const CLEAN_CAPTURE_FLAG_PATH := "res://battle_perf_clean_capture.flag"
const CHARACTER_INFO_HOST_NODE_NAME := "BattleCharacterInfoOverlayHost"
const ANGEL_BLESSING_HOST_NODE_NAME := "AngelBlessingRollOverlayHost"

var _clean_capture_checked := false
var _clean_capture_enabled := false
var _character_info_overlay_host: Control = null
var _angel_blessing_overlay_host: Object = null
var _battle_view_layout: Object = BattleViewLayout.new()
# 콜드부트 시네마틱 호스트 lifecycle(CB3): 융합 모달은 물리 flow가
# choice_active에서 조기 반환하므로, 모달 중에도 도는 이 idle 경로의
# runtime_perk_state.update 직후가 유일한 실 sync 지점이다.
var _cold_boot_cinematic_runtime: Object = PerkFusionColdBootCinematicRuntime.new()


func process_idle(
	delta: float,
	owner: Object,
	_registry: Object,
	module_getter: Callable
) -> bool:
	var perf_logger: Object = BattleSceneOverlayFrameUtils.get_module(module_getter, "battle_perf_logger")
	var sample_start: int = BattleSceneOverlayFrameUtils.perf_begin(perf_logger)
	_sync_character_info_overlay_host_visibility(owner, _registry, module_getter)
	if _is_clean_capture_enabled():
		if _close_clean_capture_overlays(owner, module_getter):
			BattleSceneOverlayFrameUtils.queue_redraw(owner)
	BattleSceneOverlayFrameUtils.perf_end(perf_logger, "process.overlay.clean_capture", sample_start)

	sample_start = BattleSceneOverlayFrameUtils.perf_begin(perf_logger)
	var passive_module_getter: Callable = _get_passive_module_getter(_registry, module_getter)
	var modal_gate: Object = BattleSceneOverlayFrameUtils.get_modal_gate(passive_module_getter)
	var perk_choice_active: bool = _is_runtime_perk_choice_active(passive_module_getter, modal_gate)
	var perk_feedback_active: bool = _is_runtime_perk_feedback_active(passive_module_getter, modal_gate)
	var angel_modal_work: bool = _has_angel_blessing_modal_work(passive_module_getter, modal_gate)
	var process_overlay_activity: String = _get_blocking_process_overlay_activity(passive_module_getter, modal_gate)
	BattleSceneOverlayFrameUtils.perf_end(perf_logger, "process.overlay.modal_scan", sample_start)
	if not angel_modal_work:
		_hide_angel_blessing_overlay_host()
	if not perk_choice_active and not perk_feedback_active and not angel_modal_work and process_overlay_activity == "":
		return false

	if perk_choice_active or perk_feedback_active or angel_modal_work:
		var runtime_perk_state: Object = BattleSceneOverlayFrameUtils.get_module(module_getter, "runtime_perk_state")
		if runtime_perk_state != null and runtime_perk_state.has_method("update"):
			sample_start = BattleSceneOverlayFrameUtils.perf_begin(perf_logger)
			if runtime_perk_state.has_method("update_with_perf"):
				runtime_perk_state.update_with_perf(delta, BattleSceneOverlayFrameUtils.get_view_size(owner), owner, _registry, perf_logger)
			else:
				runtime_perk_state.update(delta, BattleSceneOverlayFrameUtils.get_view_size(owner), owner, _registry)
			BattleSceneOverlayFrameUtils.perf_end(perf_logger, "process.overlay.runtime_perk_update", sample_start)
			# 콜드부트 호스트 sync: flow 틱(위 update) 직후 같은 idle 프레임에서
			# 생성/비트 미러/이벤트 소비/종료를 처리한다.
			_cold_boot_cinematic_runtime.sync_from_runtime_state(runtime_perk_state, owner, delta)
			var next_angel_modal_work := _has_angel_blessing_modal_work(passive_module_getter, modal_gate)
			if next_angel_modal_work:
				_sync_angel_blessing_overlay_host(owner, module_getter, true)
			else:
				_hide_angel_blessing_overlay_host()
			var next_perk_choice_active := _is_runtime_perk_choice_active(passive_module_getter, modal_gate)
			var next_perk_feedback_active := _is_runtime_perk_feedback_active(passive_module_getter, modal_gate)
			# Angel owns a detached clipped draw bridge and redraws it directly. Do
			# not redraw the 5-10 ms immediate-mode battle shell for an unbounded
			# wait-confirm phase when no standard perk overlay needs that canvas.
			if perk_choice_active or perk_feedback_active or next_perk_choice_active or next_perk_feedback_active:
				sample_start = BattleSceneOverlayFrameUtils.perf_begin(perf_logger)
				BattleSceneOverlayFrameUtils.queue_redraw(owner)
				BattleSceneOverlayFrameUtils.perf_end(perf_logger, "process.overlay.runtime_perk_queue_redraw", sample_start)
	perk_choice_active = _is_runtime_perk_choice_active(passive_module_getter, modal_gate)
	var angel_modal_active: bool = _is_angel_blessing_modal_active(passive_module_getter, modal_gate)
	if perk_choice_active or angel_modal_active:
		return true

	match process_overlay_activity:
		"character_debug":
			sample_start = BattleSceneOverlayFrameUtils.perf_begin(perf_logger)
			BattleSceneOverlayFrameUtils.queue_redraw(owner)
			BattleSceneOverlayFrameUtils.perf_end(perf_logger, "process.overlay.character_debug", sample_start)
			return true
		"perk_debug":
			var perk_debug_picker: Object = BattleSceneOverlayFrameUtils.get_module(module_getter, "runtime_perk_debug_picker")
			if perk_debug_picker != null and perk_debug_picker.has_method("update"):
				sample_start = BattleSceneOverlayFrameUtils.perf_begin(perf_logger)
				perk_debug_picker.update(delta)
				BattleSceneOverlayFrameUtils.perf_end(perf_logger, "process.overlay.perk_debug_update", sample_start)
			sample_start = BattleSceneOverlayFrameUtils.perf_begin(perf_logger)
			BattleSceneOverlayFrameUtils.queue_redraw(owner)
			BattleSceneOverlayFrameUtils.perf_end(perf_logger, "process.overlay.perk_debug_queue_redraw", sample_start)
			return true
		"stage_debug":
			sample_start = BattleSceneOverlayFrameUtils.perf_begin(perf_logger)
			BattleSceneOverlayFrameUtils.queue_redraw(owner)
			BattleSceneOverlayFrameUtils.perf_end(perf_logger, "process.overlay.stage_debug", sample_start)
			return true
		"weather_debug":
			sample_start = BattleSceneOverlayFrameUtils.perf_begin(perf_logger)
			BattleSceneOverlayFrameUtils.queue_redraw(owner)
			BattleSceneOverlayFrameUtils.perf_end(perf_logger, "process.overlay.weather_debug", sample_start)
			return true
		"lingpet_debug":
			sample_start = BattleSceneOverlayFrameUtils.perf_begin(perf_logger)
			BattleSceneOverlayFrameUtils.queue_redraw(owner)
			BattleSceneOverlayFrameUtils.perf_end(perf_logger, "process.overlay.lingpet_debug_queue_redraw", sample_start)
			return true
		"mythic_management":
			sample_start = BattleSceneOverlayFrameUtils.perf_begin(perf_logger)
			BattleSceneOverlayFrameUtils.queue_redraw(owner)
			BattleSceneOverlayFrameUtils.perf_end(perf_logger, "process.overlay.mythic_management", sample_start)
			return true
		"pandora_legacy":
			var mythic_item_runtime: Object = BattleSceneOverlayFrameUtils.get_module(module_getter, "mythic_item_runtime")
			if mythic_item_runtime != null and mythic_item_runtime.has_method("update_pandora_legacy_selection_overlay"):
				sample_start = BattleSceneOverlayFrameUtils.perf_begin(perf_logger)
				mythic_item_runtime.update_pandora_legacy_selection_overlay(delta)
				BattleSceneOverlayFrameUtils.perf_end(perf_logger, "process.overlay.pandora_legacy_update", sample_start)
			sample_start = BattleSceneOverlayFrameUtils.perf_begin(perf_logger)
			BattleSceneOverlayFrameUtils.queue_redraw(owner)
			BattleSceneOverlayFrameUtils.perf_end(perf_logger, "process.overlay.pandora_legacy_queue_redraw", sample_start)
			return true
		"active_item_debug":
			sample_start = BattleSceneOverlayFrameUtils.perf_begin(perf_logger)
			BattleSceneOverlayFrameUtils.queue_redraw(owner)
			BattleSceneOverlayFrameUtils.perf_end(perf_logger, "process.overlay.active_item_debug", sample_start)
			return true
		"pause":
			var pause_menu: Object = BattleSceneOverlayFrameUtils.get_module(module_getter, "pause_menu_overlay")
			if pause_menu != null and pause_menu.has_method("update"):
				sample_start = BattleSceneOverlayFrameUtils.perf_begin(perf_logger)
				pause_menu.update(delta)
				BattleSceneOverlayFrameUtils.perf_end(perf_logger, "process.overlay.pause_update", sample_start)
			sample_start = BattleSceneOverlayFrameUtils.perf_begin(perf_logger)
			BattleSceneOverlayFrameUtils.queue_redraw(owner)
			BattleSceneOverlayFrameUtils.perf_end(perf_logger, "process.overlay.pause_queue_redraw", sample_start)
			return true
		"elixir":
			var elixir_runtime_module: Object = BattleSceneOverlayFrameUtils.get_module(module_getter, "active_item_runtime")
			if elixir_runtime_module != null and elixir_runtime_module.has_method("update_elixir_cinematic"):
				sample_start = BattleSceneOverlayFrameUtils.perf_begin(perf_logger)
				elixir_runtime_module.update_elixir_cinematic(delta)
				BattleSceneOverlayFrameUtils.perf_end(perf_logger, "process.overlay.elixir_update", sample_start)
			sample_start = BattleSceneOverlayFrameUtils.perf_begin(perf_logger)
			BattleSceneOverlayFrameUtils.queue_redraw(owner)
			BattleSceneOverlayFrameUtils.perf_end(perf_logger, "process.overlay.elixir_queue_redraw", sample_start)
			return true
		"character_info":
			var character_info: Object = BattleSceneOverlayFrameUtils.get_module(module_getter, "character_info_overlay")
			var should_redraw := true
			if character_info != null and character_info.has_method("update"):
				var update_start: int = BattleSceneOverlayFrameUtils.perf_begin(perf_logger)
				var update_result: Variant = character_info.update(delta)
				BattleSceneOverlayFrameUtils.perf_end(perf_logger, "process.overlay.character_info_update", update_start)
				if typeof(update_result) == TYPE_BOOL:
					should_redraw = bool(update_result)
			if should_redraw:
				var redraw_start: int = BattleSceneOverlayFrameUtils.perf_begin(perf_logger)
				_queue_character_info_overlay_redraw(owner, _registry, module_getter, true)
				BattleSceneOverlayFrameUtils.perf_end(perf_logger, "process.overlay.character_info_queue_redraw", redraw_start)
			return true
		"ball_speed":
			sample_start = BattleSceneOverlayFrameUtils.perf_begin(perf_logger)
			BattleSceneOverlayFrameUtils.queue_redraw(owner)
			BattleSceneOverlayFrameUtils.perf_end(perf_logger, "process.overlay.ball_speed", sample_start)
	return false


func draw(
	canvas: CanvasItem,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	view_size: Vector2
) -> void:
	var perf_logger: Object = BattleSceneOverlayFrameUtils.get_module(module_getter, "battle_perf_logger")
	var sample_start: int = 0
	var passive_module_getter: Callable = _get_passive_module_getter(registry, module_getter)
	var modal_gate: Object = BattleSceneOverlayFrameUtils.get_modal_gate(passive_module_getter)
	var draw_overlay_activity: String = _get_primary_draw_overlay_activity(passive_module_getter, modal_gate)
	if draw_overlay_activity == "":
		return

	match draw_overlay_activity:
		"character_debug":
			sample_start = BattleSceneOverlayFrameUtils.perf_begin(perf_logger)
			var character_debug_picker: Object = BattleSceneOverlayFrameUtils.get_module(module_getter, "character_debug_picker")
			if character_debug_picker != null and character_debug_picker.has_method("draw"):
				character_debug_picker.draw(canvas, owner, view_size)
			BattleSceneOverlayFrameUtils.perf_end(perf_logger, "draw.overlay.character_debug", sample_start)
			return
		"perk_debug":
			sample_start = BattleSceneOverlayFrameUtils.perf_begin(perf_logger)
			var perk_debug_picker: Object = BattleSceneOverlayFrameUtils.get_module(module_getter, "runtime_perk_debug_picker")
			if perk_debug_picker != null and perk_debug_picker.has_method("draw"):
				perk_debug_picker.draw(canvas, owner, registry, view_size)
			BattleSceneOverlayFrameUtils.perf_end(perf_logger, "draw.overlay.perk_debug", sample_start)
			return
		"stage_debug":
			sample_start = BattleSceneOverlayFrameUtils.perf_begin(perf_logger)
			var stage_debug_picker: Object = BattleSceneOverlayFrameUtils.get_module(module_getter, "stage_debug_picker")
			if stage_debug_picker != null and stage_debug_picker.has_method("draw"):
				stage_debug_picker.draw(canvas, owner, view_size)
			BattleSceneOverlayFrameUtils.perf_end(perf_logger, "draw.overlay.stage_debug", sample_start)
			return
		"weather_debug":
			sample_start = BattleSceneOverlayFrameUtils.perf_begin(perf_logger)
			var weather_debug_picker: Object = BattleSceneOverlayFrameUtils.get_module(module_getter, "weather_debug_picker")
			if weather_debug_picker != null and weather_debug_picker.has_method("draw"):
				weather_debug_picker.draw(canvas, owner, registry, view_size)
			BattleSceneOverlayFrameUtils.perf_end(perf_logger, "draw.overlay.weather_debug", sample_start)
			return
		"lingpet_debug":
			sample_start = BattleSceneOverlayFrameUtils.perf_begin(perf_logger)
			var lingpet_debug_picker: Object = BattleSceneOverlayFrameUtils.get_module(module_getter, "lingpet_debug_picker")
			if lingpet_debug_picker != null and lingpet_debug_picker.has_method("draw"):
				lingpet_debug_picker.draw(canvas, owner, registry, view_size)
			BattleSceneOverlayFrameUtils.perf_end(perf_logger, "draw.overlay.lingpet_debug", sample_start)
			return
		"mythic_management":
			sample_start = BattleSceneOverlayFrameUtils.perf_begin(perf_logger)
			var mythic_item_runtime: Object = BattleSceneOverlayFrameUtils.get_module(module_getter, "mythic_item_runtime")
			if mythic_item_runtime != null and mythic_item_runtime.has_method("draw_debug_management_menu"):
				mythic_item_runtime.draw_debug_management_menu(canvas, owner, registry, view_size)
			BattleSceneOverlayFrameUtils.perf_end(perf_logger, "draw.overlay.mythic_management", sample_start)
			return
		"pandora_legacy":
			sample_start = BattleSceneOverlayFrameUtils.perf_begin(perf_logger)
			var mythic_item_runtime: Object = BattleSceneOverlayFrameUtils.get_module(module_getter, "mythic_item_runtime")
			if mythic_item_runtime != null and mythic_item_runtime.has_method("draw_pandora_legacy_selection"):
				mythic_item_runtime.draw_pandora_legacy_selection(canvas, owner, registry, view_size)
			BattleSceneOverlayFrameUtils.perf_end(perf_logger, "draw.overlay.pandora_legacy", sample_start)
			return
		"pause":
			sample_start = BattleSceneOverlayFrameUtils.perf_begin(perf_logger)
			var pause_menu: Object = BattleSceneOverlayFrameUtils.get_module(module_getter, "pause_menu_overlay")
			if pause_menu != null and pause_menu.has_method("draw"):
				pause_menu.draw(canvas, owner, registry, view_size)
			BattleSceneOverlayFrameUtils.perf_end(perf_logger, "draw.overlay.pause", sample_start)
			return
		"elixir":
			sample_start = BattleSceneOverlayFrameUtils.perf_begin(perf_logger)
			var elixir_runtime_module: Object = BattleSceneOverlayFrameUtils.get_module(module_getter, "active_item_runtime")
			if elixir_runtime_module != null and elixir_runtime_module.has_method("draw_elixir_cinematic"):
				elixir_runtime_module.draw_elixir_cinematic(canvas, view_size)
			BattleSceneOverlayFrameUtils.perf_end(perf_logger, "draw.overlay.elixir", sample_start)
			return
		"character_info":
			sample_start = BattleSceneOverlayFrameUtils.perf_begin(perf_logger)
			var character_info: Object = BattleSceneOverlayFrameUtils.get_module(module_getter, "character_info_overlay")
			if not _sync_character_info_overlay_host(canvas, character_info, owner, registry, view_size, false):
				if character_info != null and character_info.has_method("draw"):
					character_info.draw(canvas, owner, registry, view_size)
			BattleSceneOverlayFrameUtils.perf_end(perf_logger, "draw.overlay.character_info", sample_start)
			return
		"active_item_debug":
			sample_start = BattleSceneOverlayFrameUtils.perf_begin(perf_logger)
			var active_item_runtime: Object = BattleSceneOverlayFrameUtils.get_module(module_getter, "active_item_runtime")
			if active_item_runtime != null and active_item_runtime.has_method("draw_debug_spawn_menu"):
				active_item_runtime.draw_debug_spawn_menu(canvas, view_size, owner)
			BattleSceneOverlayFrameUtils.perf_end(perf_logger, "draw.overlay.active_item_debug", sample_start)
			if _is_ball_speed_debug_active(module_getter):
				_draw_ball_speed_debug(canvas, owner, registry, module_getter, view_size, perf_logger)
			return
		"ball_speed":
			_draw_ball_speed_debug(canvas, owner, registry, module_getter, view_size, perf_logger)
			return


func _draw_ball_speed_debug(
	canvas: CanvasItem,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	view_size: Vector2,
	perf_logger: Object
) -> void:
	var sample_start: int = BattleSceneOverlayFrameUtils.perf_begin(perf_logger)
	var ball_speed_debug: Object = BattleSceneOverlayFrameUtils.get_module(module_getter, "ball_speed_debug_overlay")
	if ball_speed_debug != null and ball_speed_debug.has_method("draw"):
		ball_speed_debug.draw(canvas, owner, view_size, registry)
	BattleSceneOverlayFrameUtils.perf_end(perf_logger, "draw.overlay.ball_speed_debug", sample_start)


func queue_character_info_overlay_redraw(owner: Object, registry: Object, module_getter: Callable, force_redraw: bool = true) -> bool:
	return _queue_character_info_overlay_redraw(owner, registry, module_getter, force_redraw)


func prewarm_angel_blessing_runtime_nodes(owner: Object) -> bool:
	AngelBlessingRollOverlayHost.prewarm_assets()
	var host := _get_or_create_angel_blessing_overlay_host(owner)
	if host == null:
		return false
	host.prepare()
	host.set_active(false)
	return true


func reset_angel_blessing_presentation() -> void:
	_hide_angel_blessing_overlay_host()
	AngelBlessingRollOverlayHost.hide_all_existing_hosts()


func get_angel_blessing_host_for_test() -> Object:
	return _angel_blessing_overlay_host


func _queue_character_info_overlay_redraw(owner: Object, registry: Object, module_getter: Callable, force_redraw: bool = true) -> bool:
	var character_info: Object = BattleSceneOverlayFrameUtils.get_module(module_getter, "character_info_overlay")
	var view_size := BattleSceneOverlayFrameUtils.get_view_size(owner)
	if _sync_character_info_overlay_host(owner, character_info, owner, registry, view_size, force_redraw):
		return true
	BattleSceneOverlayFrameUtils.queue_redraw(owner)
	return false


func _sync_character_info_overlay_host_visibility(owner: Object, registry: Object, module_getter: Callable) -> void:
	if _character_info_overlay_host == null or not is_instance_valid(_character_info_overlay_host):
		return
	var character_info: Object = BattleSceneOverlayFrameUtils.get_cached_module(registry, "character_info_overlay")
	if character_info == null:
		character_info = BattleSceneOverlayFrameUtils.get_module(module_getter, "character_info_overlay")
	var active := character_info != null and character_info.has_method("is_active") and bool(character_info.is_active())
	if not active:
		_character_info_overlay_host.hide_overlay()
		return
	_character_info_overlay_host.sync_overlay(character_info, owner, registry, BattleSceneOverlayFrameUtils.get_view_size(owner), false)


func _sync_character_info_overlay_host(canvas_or_owner: Object, character_info: Object, owner: Object, registry: Object, view_size: Vector2, force_redraw: bool) -> bool:
	if character_info == null or not character_info.has_method("is_active") or not bool(character_info.is_active()):
		if _character_info_overlay_host != null and is_instance_valid(_character_info_overlay_host):
			_character_info_overlay_host.hide_overlay()
		return true
	var host := _get_or_create_character_info_overlay_host(canvas_or_owner)
	if host == null:
		return false
	host.sync_overlay(character_info, owner, registry, view_size, force_redraw)
	return true


func _get_or_create_character_info_overlay_host(canvas_or_owner: Object) -> Control:
	if _character_info_overlay_host != null and is_instance_valid(_character_info_overlay_host):
		return _character_info_overlay_host
	if not (canvas_or_owner is Node):
		return null
	var parent := canvas_or_owner as Node
	var existing := parent.get_node_or_null(CHARACTER_INFO_HOST_NODE_NAME)
	if existing is Control:
		_character_info_overlay_host = existing as Control
		return _character_info_overlay_host
	var host := CharacterInfoOverlayHost.new()
	host.name = CHARACTER_INFO_HOST_NODE_NAME
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.z_index = 3000
	host.top_level = true
	parent.add_child(host)
	_character_info_overlay_host = host
	return _character_info_overlay_host


func _sync_angel_blessing_overlay_host(owner: Object, module_getter: Callable, force_create: bool) -> void:
	var runtime_state: Object = BattleSceneOverlayFrameUtils.get_module(module_getter, "runtime_perk_state")
	if runtime_state == null or not runtime_state.has_method("get_angel_blessing_presentation_snapshot"):
		if _angel_blessing_overlay_host != null and is_instance_valid(_angel_blessing_overlay_host):
			_angel_blessing_overlay_host.set_active(false)
		return
	var snapshot_value: Variant = runtime_state.get_angel_blessing_presentation_snapshot()
	var snapshot: Dictionary = snapshot_value if snapshot_value is Dictionary else {}
	var absorption_value: Variant = snapshot.get("absorption", {})
	var absorption: Dictionary = absorption_value if absorption_value is Dictionary else {}
	var visible_work := bool(snapshot.get("modal_active", false)) or bool(absorption.get("active", false))
	if not visible_work and not force_create:
		if _angel_blessing_overlay_host != null and is_instance_valid(_angel_blessing_overlay_host):
			_angel_blessing_overlay_host.set_active(false)
		return
	var host := _get_or_create_angel_blessing_overlay_host(owner)
	if host == null:
		return
	if not visible_work:
		host.set_active(false)
		return
	var view_size := BattleSceneOverlayFrameUtils.get_view_size(owner)
	var layout: Dictionary = _battle_view_layout.build_game_layout(view_size, 760.0, 750.0)
	host.sync_state(snapshot, _get_owner_player_pos(owner), layout)


func _hide_angel_blessing_overlay_host() -> void:
	if _angel_blessing_overlay_host != null and is_instance_valid(_angel_blessing_overlay_host):
		_angel_blessing_overlay_host.set_active(false)


func _get_or_create_angel_blessing_overlay_host(owner: Object) -> Object:
	if _angel_blessing_overlay_host != null and is_instance_valid(_angel_blessing_overlay_host):
		return _angel_blessing_overlay_host
	if not (owner is Node):
		return null
	var parent := owner as Node
	var existing := parent.get_node_or_null(ANGEL_BLESSING_HOST_NODE_NAME)
	if existing is Node2D:
		_angel_blessing_overlay_host = existing as Node2D
		_angel_blessing_overlay_host.prepare()
		return _angel_blessing_overlay_host
	var host := AngelBlessingRollOverlayHost.new()
	host.name = ANGEL_BLESSING_HOST_NODE_NAME
	parent.add_child(host)
	host.prepare()
	_angel_blessing_overlay_host = host
	return _angel_blessing_overlay_host


func _get_owner_player_pos(owner: Object) -> Vector2:
	if owner == null:
		return Vector2(380.0, 690.0)
	var value: Variant = owner.get("player_pos")
	if not (value is Vector2):
		return Vector2(380.0, 690.0)
	var width_value: Variant = owner.get("player_paddle_width")
	var height_value: Variant = owner.get("player_paddle_height")
	var paddle_width := maxf(0.0, float(width_value)) if width_value != null else 155.0
	var paddle_height := maxf(0.0, float(height_value)) if height_value != null else 50.0
	return (value as Vector2) + Vector2(paddle_width, paddle_height) * 0.5


func _is_runtime_perk_choice_active(module_getter: Callable, modal_gate: Object = null) -> bool:
	return BattleSceneOverlayFrameUtils.call_modal_gate_bool(module_getter, "is_runtime_perk_choice_active", false, modal_gate)


func _is_runtime_perk_feedback_active(module_getter: Callable, modal_gate: Object = null) -> bool:
	return BattleSceneOverlayFrameUtils.call_modal_gate_bool(module_getter, "is_runtime_perk_feedback_active", false, modal_gate)


func _is_angel_blessing_modal_active(module_getter: Callable, modal_gate: Object = null) -> bool:
	return BattleSceneOverlayFrameUtils.call_modal_gate_bool(module_getter, "is_angel_blessing_modal_active", false, modal_gate)


func _has_angel_blessing_modal_work(module_getter: Callable, modal_gate: Object = null) -> bool:
	return BattleSceneOverlayFrameUtils.call_modal_gate_bool(module_getter, "has_angel_blessing_modal_work", false, modal_gate)


func _is_character_debug_picker_open(module_getter: Callable, modal_gate: Object = null) -> bool:
	return BattleSceneOverlayFrameUtils.call_modal_gate_bool(module_getter, "is_character_debug_picker_open", false, modal_gate)


func _is_perk_debug_picker_open(module_getter: Callable, modal_gate: Object = null) -> bool:
	return BattleSceneOverlayFrameUtils.call_modal_gate_bool(module_getter, "is_perk_debug_picker_open", false, modal_gate)


func _is_mythic_management_menu_open(module_getter: Callable, modal_gate: Object = null) -> bool:
	return BattleSceneOverlayFrameUtils.call_modal_gate_bool(module_getter, "is_mythic_management_menu_open", false, modal_gate)


func _is_pandora_legacy_selection_active(module_getter: Callable, modal_gate: Object = null) -> bool:
	return BattleSceneOverlayFrameUtils.call_modal_gate_bool(module_getter, "is_pandora_legacy_selection_active", false, modal_gate)


func _is_stage_debug_picker_open(module_getter: Callable, modal_gate: Object = null) -> bool:
	return BattleSceneOverlayFrameUtils.call_modal_gate_bool(module_getter, "is_stage_debug_picker_open", false, modal_gate)


func _is_weather_debug_picker_open(module_getter: Callable, modal_gate: Object = null) -> bool:
	return BattleSceneOverlayFrameUtils.call_modal_gate_bool(module_getter, "is_weather_debug_picker_open", false, modal_gate)


func _is_lingpet_debug_picker_open(module_getter: Callable, modal_gate: Object = null) -> bool:
	return BattleSceneOverlayFrameUtils.call_modal_gate_bool(module_getter, "is_lingpet_debug_picker_open", false, modal_gate)


func _is_active_item_debug_spawn_menu_open(module_getter: Callable, modal_gate: Object = null) -> bool:
	return BattleSceneOverlayFrameUtils.call_modal_gate_bool(module_getter, "is_active_item_debug_spawn_menu_open", false, modal_gate)


func _is_character_info_active(module_getter: Callable, modal_gate: Object = null) -> bool:
	return BattleSceneOverlayFrameUtils.call_modal_gate_bool(module_getter, "is_character_info_active", false, modal_gate)


func _is_pause_menu_active(module_getter: Callable, modal_gate: Object = null) -> bool:
	return BattleSceneOverlayFrameUtils.call_modal_gate_bool(module_getter, "is_pause_menu_active", false, modal_gate)


func _is_elixir_cinematic_active(module_getter: Callable, modal_gate: Object = null) -> bool:
	return BattleSceneOverlayFrameUtils.call_modal_gate_bool(module_getter, "is_elixir_cinematic_active", false, modal_gate)


func _is_ball_speed_debug_active(module_getter: Callable) -> bool:
	var ball_speed_debug: Object = BattleSceneOverlayFrameUtils.get_module(module_getter, "ball_speed_debug_overlay")
	if ball_speed_debug == null or not ball_speed_debug.has_method("is_active"):
		return false
	return bool(ball_speed_debug.is_active())


func has_blocking_activity(module_getter: Callable) -> bool:
	return _has_process_overlay_activity(module_getter)


func _has_process_overlay_activity(module_getter: Callable) -> bool:
	# This gate is consumed ONLY by the skill / drive cut-in draws
	# (battle_scene_frame_controller._draw_skill_cutin_if_active /
	# _draw_drive_cutin_if_active) to suppress the cut-in while a real blocking
	# MODAL is up. It must NOT include runtime perk FEEDBACK: that is a transient,
	# non-modal notification that does not pause battle physics, and a skill
	# activation routinely raises it on the same frame the freeze cut-in starts.
	# Including it here blanked the headline power-smash / drive cut-in for the
	# ~1s the feedback lingered ("invisible early, only the fade-out tail at the
	# end"). Perk CHOICE (the real fullscreen selection modal) stays gated.
	var modal_gate: Object = BattleSceneOverlayFrameUtils.get_modal_gate(module_getter)
	return (
		_is_runtime_perk_choice_active(module_getter, modal_gate)
		or _is_angel_blessing_modal_active(module_getter, modal_gate)
		or _get_blocking_process_overlay_activity(module_getter, modal_gate) != ""
	)


func _get_blocking_process_overlay_activity(module_getter: Callable, modal_gate: Object = null) -> String:
	if _is_character_debug_picker_open(module_getter, modal_gate):
		return "character_debug"
	if _is_perk_debug_picker_open(module_getter, modal_gate):
		return "perk_debug"
	if _is_stage_debug_picker_open(module_getter, modal_gate):
		return "stage_debug"
	if _is_weather_debug_picker_open(module_getter, modal_gate):
		return "weather_debug"
	if _is_lingpet_debug_picker_open(module_getter, modal_gate):
		return "lingpet_debug"
	if _is_mythic_management_menu_open(module_getter, modal_gate):
		return "mythic_management"
	if _is_pandora_legacy_selection_active(module_getter, modal_gate):
		return "pandora_legacy"
	if _is_active_item_debug_spawn_menu_open(module_getter, modal_gate):
		return "active_item_debug"
	if _is_pause_menu_active(module_getter, modal_gate):
		return "pause"
	if _is_elixir_cinematic_active(module_getter, modal_gate):
		return "elixir"
	if _is_character_info_active(module_getter, modal_gate):
		return "character_info"
	if _is_ball_speed_debug_active(module_getter):
		return "ball_speed"
	return ""


func _has_draw_overlay_activity(module_getter: Callable) -> bool:
	return _get_primary_draw_overlay_activity(module_getter, BattleSceneOverlayFrameUtils.get_modal_gate(module_getter)) != ""


func _get_primary_draw_overlay_activity(module_getter: Callable, modal_gate: Object = null) -> String:
	if _is_character_debug_picker_open(module_getter, modal_gate):
		return "character_debug"
	if _is_perk_debug_picker_open(module_getter, modal_gate):
		return "perk_debug"
	if _is_stage_debug_picker_open(module_getter, modal_gate):
		return "stage_debug"
	if _is_weather_debug_picker_open(module_getter, modal_gate):
		return "weather_debug"
	if _is_lingpet_debug_picker_open(module_getter, modal_gate):
		return "lingpet_debug"
	if _is_mythic_management_menu_open(module_getter, modal_gate):
		return "mythic_management"
	if _is_pandora_legacy_selection_active(module_getter, modal_gate):
		return "pandora_legacy"
	if _is_pause_menu_active(module_getter, modal_gate):
		return "pause"
	if _is_elixir_cinematic_active(module_getter, modal_gate):
		return "elixir"
	if _is_character_info_active(module_getter, modal_gate):
		return "character_info"
	if _is_active_item_debug_spawn_menu_open(module_getter, modal_gate):
		return "active_item_debug"
	if _is_ball_speed_debug_active(module_getter):
		return "ball_speed"
	return ""


func _get_passive_module_getter(registry: Object, module_getter: Callable) -> Callable:
	if registry != null and registry.has_method("get_cached_instance"):
		return Callable(self, "_get_cached_or_core_module").bind(registry, module_getter)
	return module_getter


func _get_cached_or_core_module(key: String, registry: Object, module_getter: Callable) -> Object:
	if key == "battle_scene_modal_gate_controller" or key == "battle_perf_logger":
		return BattleSceneOverlayFrameUtils.get_module(module_getter, key)
	var cached: Variant = registry.get_cached_instance(key)
	if typeof(cached) == TYPE_OBJECT and is_instance_valid(cached):
		return cached as Object
	return null


func _is_clean_capture_enabled() -> bool:
	if _clean_capture_checked:
		return _clean_capture_enabled
	_clean_capture_checked = true
	var env_value: String = OS.get_environment(CLEAN_CAPTURE_ENV).strip_edges().to_lower()
	if env_value in ["0", "false", "no", "off"]:
		_clean_capture_enabled = false
		return _clean_capture_enabled
	_clean_capture_enabled = env_value in ["1", "true", "yes", "on"] or FileAccess.file_exists(CLEAN_CAPTURE_FLAG_PATH)
	return _clean_capture_enabled


func _close_clean_capture_overlays(owner: Object, module_getter: Callable) -> bool:
	var closed_any := false
	if _is_character_debug_picker_open(module_getter):
		closed_any = _close_overlay_menu("character_debug_picker", "close", module_getter) or closed_any
	if _is_perk_debug_picker_open(module_getter):
		closed_any = _close_overlay_menu("runtime_perk_debug_picker", "close", module_getter) or closed_any
	if _is_stage_debug_picker_open(module_getter):
		closed_any = _close_overlay_menu("stage_debug_picker", "close", module_getter) or closed_any
	if _is_weather_debug_picker_open(module_getter):
		closed_any = _close_overlay_menu("weather_debug_picker", "close", module_getter) or closed_any
	if _is_lingpet_debug_picker_open(module_getter):
		closed_any = _close_overlay_menu("lingpet_debug_picker", "close", module_getter) or closed_any
	if _is_mythic_management_menu_open(module_getter):
		closed_any = _close_mythic_management_debug_menu(module_getter) or closed_any
	if _is_active_item_debug_spawn_menu_open(module_getter):
		closed_any = _close_active_item_debug_menu(module_getter) or closed_any
	if _is_ball_speed_debug_active(module_getter):
		closed_any = _close_ball_speed_debug(module_getter) or closed_any
	if _is_character_info_active(module_getter):
		closed_any = _close_overlay_menu("character_info_overlay", "close", module_getter) or closed_any
	if owner != null and bool(owner.get("player_customization_debug_overlay_enabled")):
		owner.set("player_customization_debug_overlay_enabled", false)
		closed_any = true
	return closed_any


func _close_active_item_debug_menu(module_getter: Callable) -> bool:
	var active_item_runtime: Object = BattleSceneOverlayFrameUtils.get_module(module_getter, "active_item_runtime")
	if active_item_runtime == null:
		return false
	if active_item_runtime.has_method("close_debug_spawn_menu"):
		active_item_runtime.close_debug_spawn_menu()
		return true
	if _is_active_item_debug_spawn_menu_open(module_getter) and active_item_runtime.has_method("toggle_debug_spawn_menu"):
		active_item_runtime.toggle_debug_spawn_menu()
		return true
	return false


func _close_mythic_management_debug_menu(module_getter: Callable) -> bool:
	var mythic_item_runtime: Object = BattleSceneOverlayFrameUtils.get_module(module_getter, "mythic_item_runtime")
	if mythic_item_runtime == null:
		return false
	if mythic_item_runtime.has_method("close_debug_management_menu"):
		mythic_item_runtime.close_debug_management_menu()
		return true
	if _is_mythic_management_menu_open(module_getter) and mythic_item_runtime.has_method("toggle_debug_management_menu"):
		mythic_item_runtime.toggle_debug_management_menu()
		return true
	return false


func _close_ball_speed_debug(module_getter: Callable) -> bool:
	var ball_speed_debug: Object = BattleSceneOverlayFrameUtils.get_module(module_getter, "ball_speed_debug_overlay")
	if ball_speed_debug == null:
		return false
	if ball_speed_debug.has_method("close"):
		ball_speed_debug.close()
		return true
	if _is_ball_speed_debug_active(module_getter) and ball_speed_debug.has_method("toggle"):
		ball_speed_debug.toggle()
		return true
	return false


func _close_overlay_menu(module_key: String, close_method: String, module_getter: Callable) -> bool:
	var module: Object = BattleSceneOverlayFrameUtils.get_module(module_getter, module_key)
	if module != null and module.has_method(close_method):
		module.call(close_method)
		return true
	return false
