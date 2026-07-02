extends RefCounted

const TAG_DEFENSE_INTERCEPT := "defense_intercept"
const TAG_RING_DASH_BLOCK := "ring_dash_block"
const PROP_DEFENSE_INTERCEPT_ACTIVE := "defense_intercept_active"


func capture(motion_state: Object, ring_dash_state: Object) -> Dictionary:
	var defense_intercept_active := false
	if motion_state != null:
		defense_intercept_active = bool(motion_state.get(PROP_DEFENSE_INTERCEPT_ACTIVE))
	var ring_dash_block_active := false
	if ring_dash_state != null and ring_dash_state.has_method("has_companion_position_override"):
		ring_dash_block_active = bool(ring_dash_state.has_companion_position_override())
	return {
		TAG_DEFENSE_INTERCEPT: defense_intercept_active,
		TAG_RING_DASH_BLOCK: ring_dash_block_active,
	}


func merge(first: Dictionary, second: Dictionary) -> Dictionary:
	return {
		TAG_DEFENSE_INTERCEPT: _is_tag_active(first, TAG_DEFENSE_INTERCEPT) or _is_tag_active(second, TAG_DEFENSE_INTERCEPT),
		TAG_RING_DASH_BLOCK: _is_tag_active(first, TAG_RING_DASH_BLOCK) or _is_tag_active(second, TAG_RING_DASH_BLOCK),
	}


func has_defense_tag(tags: Dictionary) -> bool:
	return _is_tag_active(tags, TAG_DEFENSE_INTERCEPT) or _is_tag_active(tags, TAG_RING_DASH_BLOCK)


func _is_tag_active(tags: Dictionary, tag: String) -> bool:
	return bool(tags.get(tag, false))
