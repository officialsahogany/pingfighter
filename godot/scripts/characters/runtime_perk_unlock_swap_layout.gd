extends RefCounted

const RuntimePerkRuntimeStateAccess := preload("res://scripts/characters/runtime_perk_runtime_state_access.gd")

const RuntimePerkPayloadAccess := preload("res://scripts/characters/runtime_perk_payload_access.gd")

const DEFAULT_CARD_SIZE := Vector2(184.0, 116.0)
const DEFAULT_CARD_GAP := 14.0


func build_layout(pending_unlock_swap: Dictionary, view_size: Vector2) -> Dictionary:
	var candidates: Array = RuntimePerkPayloadAccess.as_array(pending_unlock_swap.get("candidates", []))
	var card_count: int = max(1, candidates.size())
	var card_width := DEFAULT_CARD_SIZE.x
	var card_height := DEFAULT_CARD_SIZE.y
	var gap := DEFAULT_CARD_GAP
	var max_width: float = min(760.0, max(360.0, view_size.x - 96.0))
	var total_width: float = card_width * float(card_count) + gap * float(max(0, card_count - 1))
	if total_width > max_width:
		var scale_factor: float = max_width / total_width
		card_width = floor(card_width * scale_factor)
		card_height = floor(card_height * scale_factor)
		gap = max(8.0, floor(gap * scale_factor))
		total_width = card_width * float(card_count) + gap * float(max(0, card_count - 1))
	var panel_height := 292.0
	var panel_width: float = min(max_width + 72.0, total_width + 96.0)
	var panel_pos := Vector2(floor((view_size.x - panel_width) * 0.5), floor((view_size.y - panel_height) * 0.5))
	var cards_start := Vector2(floor((view_size.x - total_width) * 0.5), panel_pos.y + 106.0)
	return {
		"panel_rect": Rect2(panel_pos, Vector2(panel_width, panel_height)),
		"title_pos": panel_pos + Vector2(panel_width * 0.5, 38.0),
		"new_skill_pos": panel_pos + Vector2(panel_width * 0.5, 70.0),
		"cards_start": cards_start,
		"card_size": Vector2(card_width, card_height),
		"card_gap": gap,
		"hint_pos": panel_pos + Vector2(panel_width * 0.5, panel_height - 34.0),
	}


func build_layout_from_runtime_state(runtime_state: Object, view_size: Vector2) -> Dictionary:
	return build_layout(RuntimePerkRuntimeStateAccess.get_dict(runtime_state, "pending_unlock_swap"), view_size)


func get_option_rects(pending_unlock_swap: Dictionary, view_size: Vector2) -> Array:
	var layout: Dictionary = build_layout(pending_unlock_swap, view_size)
	var candidates: Array = RuntimePerkPayloadAccess.as_array(pending_unlock_swap.get("candidates", []))
	var card_size: Vector2 = RuntimePerkPayloadAccess.as_vector2(layout.get("card_size", DEFAULT_CARD_SIZE))
	var start: Vector2 = RuntimePerkPayloadAccess.as_vector2(layout.get("cards_start", Vector2.ZERO))
	var gap: float = float(layout.get("card_gap", DEFAULT_CARD_GAP))
	var rects: Array = []
	for index in range(candidates.size()):
		rects.append(Rect2(start + Vector2(float(index) * (card_size.x + gap), 0.0), card_size))
	return rects


func get_option_rects_from_runtime_state(runtime_state: Object, view_size: Vector2) -> Array:
	return get_option_rects(RuntimePerkRuntimeStateAccess.get_dict(runtime_state, "pending_unlock_swap"), view_size)


func get_index_at(pending_unlock_swap: Dictionary, position: Vector2, view_size: Vector2) -> int:
	var rects: Array = get_option_rects(pending_unlock_swap, view_size)
	for index in range(rects.size()):
		var rect: Rect2 = rects[index]
		if rect.has_point(position):
			return index
	return -1


func get_index_at_from_runtime_state(runtime_state: Object, position: Vector2, view_size: Vector2) -> int:
	return get_index_at(RuntimePerkRuntimeStateAccess.get_dict(runtime_state, "pending_unlock_swap"), position, view_size)
