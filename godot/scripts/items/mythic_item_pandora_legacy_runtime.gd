extends RefCounted

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")
const GamepadInput := preload("res://scripts/core/gamepad_input.gd")

const ITEM_PANDORA_LEGACY := "pandora_legacy"
const CARD_COUNT := 3
const ACTIVE_ITEM_KOREAN_NAMES := {
	"gauge_charge": "탕약",
	"life_elixir": "오색약수",
	"vitamin_pill": "경신단",
	"aipill": "신령환",
	"pandora_box": "도깨비 보따리",
	"grenade": "폭화탄",
	"flare": "환광탄",
	"tear_gas": "최루탄",
	"dynamite": "폭렬화통",
	"molotov": "열화병",
	"stopwatch": "요술 회중시계",
	"magnet_field": "흡인진",
	"long_boost": "거신단",
	"regeneration_potion": "원기탕",
	"holy_barrier": "금강결계",
	"dash_boost": "축지부",
	"wall": "토벽패",
	"boomerang": "부메랑",
	"banana": "바나나",
	"soap": "비누",
	"spider_mine": "귀주뢰",
}


func is_equipped(runtime: Object) -> bool:
	return runtime.is_equipped(ITEM_PANDORA_LEGACY)


func is_active(runtime: Object) -> bool:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_level(runtime) > 0
	return is_equipped(runtime)


func get_selection_quality(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return _get_converted_mythic_value(runtime, "selection_quality")
	if not is_equipped(runtime):
		return 0.0
	return clamp(runtime.roll_query.get_equipped_roll_value(runtime, ITEM_PANDORA_LEGACY, "selection_quality"), 0.0, 100.0)


func get_trigger_chance(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return _get_converted_mythic_value(runtime, "trigger_chance")
	if not is_equipped(runtime):
		return 0.0
	return clamp(runtime.roll_query.get_equipped_roll_value(runtime, ITEM_PANDORA_LEGACY, "trigger_chance"), 0.0, 100.0)


func is_selection_active(runtime: Object) -> bool:
	return runtime.pandora_legacy_selection_state.is_active()


func update_selection_overlay(runtime: Object, delta: float) -> void:
	if not runtime.pandora_legacy_selection_state.is_active():
		return
	runtime.pandora_legacy_selection_state.advance_timer(max(0.0, delta * 60.0))


func update_selection_frames(runtime: Object, fps_scale: float) -> void:
	if runtime.pandora_legacy_selection_state.is_active():
		runtime.pandora_legacy_selection_state.advance_timer(fps_scale)


func has_pending_selection(runtime: Object) -> bool:
	return runtime.pandora_legacy_selection_state.has_pending()


func try_queue_round_win(
	runtime: Object,
	deps: Dictionary = {}
) -> bool:
	runtime.pandora_legacy_selection_state.reset_trigger_result()
	if not is_active(runtime):
		return false
	var trigger_chance: float = get_trigger_chance(runtime)
	if trigger_chance <= 0.0:
		return false
	var roll: float = randf() * 100.0
	runtime.pandora_legacy_selection_state.set_trigger_roll(roll)
	if roll >= trigger_chance:
		return false
	var owner: Object = deps.get("owner", null)
	var registry: Object = deps.get("registry", null)
	var choices: Array = generate_selection_choices(runtime, owner, registry)
	if choices.size() < CARD_COUNT:
		return false
	runtime.pandora_legacy_selection_state.queue_choices(choices)
	return true


func start_pending_selection(runtime: Object, owner: Object = null, registry: Object = null) -> bool:
	if not runtime.pandora_legacy_selection_state.start_pending():
		return false
	runtime._sync_owner(owner, registry)
	_queue_owner_redraw(owner)
	return true


func start_selection(runtime: Object, choices: Array, owner: Object = null, registry: Object = null) -> bool:
	if not runtime.pandora_legacy_selection_state.start(choices):
		return false
	runtime._sync_owner(owner, registry)
	_queue_owner_redraw(owner)
	return true


func confirm_selection(runtime: Object, index: int, owner: Object, registry: Object = null) -> bool:
	if not runtime.pandora_legacy_selection_state.is_active():
		return false
	var selected_item: Dictionary = runtime.pandora_legacy_selection_state.get_selected_item(index)
	if selected_item.is_empty():
		return false
	var granted: bool = grant_selected_item(runtime, selected_item, owner, registry)
	clear_selection(runtime, false)
	if granted:
		runtime.audio_router.play_pickup_audio(runtime, registry)
	runtime._sync_owner(owner, registry)
	_queue_owner_redraw(owner)
	return granted


func cancel_selection(runtime: Object, owner: Object, registry: Object = null) -> bool:
	return confirm_selection(runtime, 0, owner, registry)


func generate_selection_choices(
	runtime: Object,
	owner: Object = null,
	registry: Object = null
) -> Array:
	var quality_bonus: float = get_selection_quality(runtime) / 100.0
	return runtime.pandora_legacy_choice_builder.generate_choices(
		runtime.pandora_legacy_pool_builder.build_active_pool(owner, registry),
		runtime.pandora_legacy_pool_builder.build_passive_pool(runtime.catalog, owner),
		runtime.pandora_legacy_pool_builder.build_mythic_pool(runtime.catalog),
		quality_bonus,
		ACTIVE_ITEM_KOREAN_NAMES,
		CARD_COUNT
	)


func get_card_rect(runtime: Object, index: int, view_size: Vector2) -> Rect2:
	return runtime.pandora_legacy_selection_renderer.get_card_rect(index, view_size, CARD_COUNT)


func get_card_index_at(runtime: Object, position: Vector2, view_size: Vector2) -> int:
	return runtime.pandora_legacy_selection_renderer.get_card_index_at(position, view_size, CARD_COUNT)


func draw_selection(runtime: Object, canvas: CanvasItem, view_size: Vector2) -> void:
	runtime.pandora_legacy_selection_renderer.draw_selection_overlay(
		canvas,
		runtime.pandora_legacy_selection_state,
		runtime.pandora_legacy_icon_texture_cache,
		view_size,
		ACTIVE_ITEM_KOREAN_NAMES,
		CARD_COUNT
	)


func handle_selection_input(
	runtime: Object,
	event: InputEvent,
	owner: Object,
	registry: Object,
	view_size: Vector2
) -> bool:
	if not runtime.pandora_legacy_selection_state.is_active():
		return false
	if event is InputEventMouseMotion:
		var hover_index: int = get_card_index_at(runtime, event.position, view_size)
		if hover_index >= 0 and hover_index != int(runtime.pandora_legacy_selection_state.selected_index):
			runtime.pandora_legacy_selection_state.set_selected_index(hover_index)
			_queue_owner_redraw(owner)
		return true
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			var clicked_index: int = get_card_index_at(runtime, mouse_event.position, view_size)
			if clicked_index >= 0:
				confirm_selection(runtime, clicked_index, owner, registry)
		return true
	if GamepadInput.is_gamepad_event(event):
		var horizontal_direction: int = GamepadInput.get_menu_horizontal_event(event)
		if horizontal_direction != 0:
			runtime.pandora_legacy_selection_state.move_selected(horizontal_direction)
			_queue_owner_redraw(owner)
			return true
		if GamepadInput.is_confirm_event(event):
			confirm_selection(runtime, int(runtime.pandora_legacy_selection_state.selected_index), owner, registry)
			return true
		if GamepadInput.is_cancel_event(event):
			cancel_selection(runtime, owner, registry)
			return true
		return true
	if event is InputEventKey:
		var key_event: InputEventKey = event
		if not key_event.pressed or key_event.echo:
			return true
		var keycode: int = key_event.keycode if key_event.keycode != 0 else key_event.physical_keycode
		match keycode:
			KEY_LEFT, KEY_A:
				runtime.pandora_legacy_selection_state.move_selected(-1)
				_queue_owner_redraw(owner)
				return true
			KEY_RIGHT, KEY_D:
				runtime.pandora_legacy_selection_state.move_selected(1)
				_queue_owner_redraw(owner)
				return true
			KEY_SPACE, KEY_ENTER:
				confirm_selection(runtime, int(runtime.pandora_legacy_selection_state.selected_index), owner, registry)
				return true
			KEY_ESCAPE:
				cancel_selection(runtime, owner, registry)
				return true
	return true


func grant_selected_item(
	runtime: Object,
	selected_item: Dictionary,
	owner: Object,
	registry: Object = null
) -> bool:
	return runtime.pandora_legacy_grant_router.grant_selected_item(
		selected_item,
		runtime,
		owner,
		registry,
		runtime.catalog
	)


func clear_selection(runtime: Object, clear_pending: bool = true) -> void:
	runtime.pandora_legacy_selection_state.clear_selection(clear_pending)


func clear_runtime(runtime: Object) -> void:
	runtime.pandora_legacy_selection_state.clear_runtime()
	runtime.pandora_legacy_icon_texture_cache.clear()


# Match-boundary normalize layer. A queued selection is a NEXT-ROUND reward window
# that lives inside ONE match: it is queued on a won round and consumed at the
# following serve. No pending may survive a match / stage boundary — the serve that
# would have consumed it never comes, so it opens at the next stage's first serve
# regardless of who won that round (the "금기개함 fires on a lost round" report).
#
# Deliberately NOT wired into reset_round(): an ordinary round win legitimately
# queues here and must survive that round boundary to be consumed. Only the match
# end and the stage transition may normalize. Keeps the icon texture cache warm —
# only selection state is boundary-scoped.
func normalize_selection_for_boundary(runtime: Object) -> bool:
	var selection_state: Object = runtime.pandora_legacy_selection_state
	if selection_state == null:
		return false
	if not selection_state.has_pending() and not selection_state.is_active():
		return false
	selection_state.clear_selection(true)
	selection_state.reset_trigger_result()
	return true


func _queue_owner_redraw(owner: Object) -> void:
	if owner != null and owner.has_method("queue_redraw"):
		owner.queue_redraw()


func _get_converted_mythic_value(runtime: Object, key: String) -> float:
	if _get_converted_perk_level(runtime) <= 0:
		return 0.0
	return PerkConversionValues.get_mythic_value(ITEM_PANDORA_LEGACY, key)


func _get_converted_perk_level(runtime: Object) -> int:
	if runtime != null and runtime.has_method("get_converted_perk_effect_level"):
		return max(0, int(runtime.get_converted_perk_effect_level(ITEM_PANDORA_LEGACY)))
	return 0
