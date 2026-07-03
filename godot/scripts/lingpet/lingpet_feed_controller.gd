extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const LingpetAffinityState := preload("res://scripts/lingpet/lingpet_affinity_state.gd")
const LingpetFeedBowlState := preload("res://scripts/lingpet/lingpet_feed_bowl_state.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const DEFAULT_PLAYER_WIDTH := 155.0
const DEFAULT_PLAYER_HEIGHT := 50.0
const BOWL_PLAYER_SIDE_OFFSET := 48.0
const BOWL_FLOOR_OFFSET_Y := 18.0
const BOWL_EDGE_MARGIN_X := 24.0
const BOWL_MIN_Y := 36.0
const BOWL_BOTTOM_MARGIN := 20.0
const MAX_FEED_USES_PER_BATTLE := 2

var _bowl_state: Object = LingpetFeedBowlState.new()
var _pending_pet_id := ""
var _pending_feed_amount := 0.0
var _pending_registry: Object = null
var _feed_uses_this_battle := 0


func request(
	pet_id: String,
	owner: Object,
	companion_pos: Vector2,
	motion_style: String,
	affinity_state: Object,
	companion_busy: bool,
	registry: Object = null,
	feed_amount: float = 0.0
) -> Dictionary:
	var normalized_pet_id := pet_id.strip_edges().to_lower()
	if normalized_pet_id == "":
		return _build_request_result(false, "missing_lingpet", normalized_pet_id)
	var normalized_amount := maxf(0.0, feed_amount)
	if normalized_amount <= 0.0:
		return _build_request_result(false, "invalid_feed_amount", normalized_pet_id)
	var blocked_reason := _get_blocked_reason(normalized_pet_id, affinity_state)
	if blocked_reason != "":
		return _build_request_result(false, blocked_reason, normalized_pet_id)
	if companion_busy:
		return _build_request_result(false, "companion_busy", normalized_pet_id)
	var bowl_pos := _resolve_bowl_pos(owner, companion_pos)
	if not _bowl_state.arm(bowl_pos, companion_pos, motion_style):
		return _build_request_result(false, "feed_in_progress", normalized_pet_id)
	_pending_pet_id = normalized_pet_id
	_pending_feed_amount = normalized_amount
	_pending_registry = registry
	var result := _build_request_result(true, "", normalized_pet_id)
	result["pending"] = true
	result["bowl_pos"] = bowl_pos
	result["feed_amount"] = normalized_amount
	return result


func advance(
	delta: float,
	companion_pos: Vector2,
	motion_style: String,
	fallback_registry: Object = null
) -> Dictionary:
	if not _bowl_state.is_active():
		return {}
	var result: Dictionary = _bowl_state.advance(delta, companion_pos, motion_style)
	if not bool(result.get("completed", false)):
		return result
	var feed_pet_id := _pending_pet_id
	var feed_amount := _pending_feed_amount
	var feed_registry := _pending_registry if _pending_registry != null else fallback_registry
	_clear_pending()
	_feed_uses_this_battle = mini(_feed_uses_this_battle + 1, MAX_FEED_USES_PER_BATTLE)
	result["feed_pet_id"] = feed_pet_id
	result["feed_amount"] = feed_amount
	result["feed_registry"] = feed_registry
	result["feed_uses_this_battle"] = _feed_uses_this_battle
	return result


func reset_all() -> void:
	_bowl_state.reset_all()
	_clear_pending()


func reset_for_new_battle() -> void:
	reset_all()
	_feed_uses_this_battle = 0


func get_feed_uses_this_battle_for_tests() -> int:
	return clampi(_feed_uses_this_battle, 0, MAX_FEED_USES_PER_BATTLE)


func is_active() -> bool:
	return _bowl_state.is_active()


func has_visible_effects() -> bool:
	return _bowl_state.has_visible_effects()


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	_bowl_state.draw(canvas, shake_offset)


func has_companion_position_override() -> bool:
	return _bowl_state.has_companion_position_override()


func get_companion_position_override(fallback: Vector2) -> Vector2:
	return _bowl_state.get_companion_position_override(fallback)


func get_snapshot() -> Dictionary:
	return _bowl_state.get_snapshot()


func _get_blocked_reason(pet_id: String, affinity_state: Object) -> String:
	if _bowl_state.is_active():
		return "feed_in_progress"
	if affinity_state == null:
		return "missing_affinity_state"
	if affinity_state.has_method("get_satiety"):
		if float(affinity_state.get_satiety(pet_id)) >= LingpetAffinityState.SATIETY_MAX:
			return "satiety_full"
	if _feed_uses_this_battle >= MAX_FEED_USES_PER_BATTLE:
		return "max_battle_feed_uses"
	return ""


func _build_request_result(accepted: bool, blocked_reason: String, pet_id: String) -> Dictionary:
	return {
		"accepted": accepted,
		"pending": false,
		"pet_id": pet_id,
		"source": "satiety_feed",
		"feed_amount": 0.0,
		"granted_satiety": 0.0,
		"blocked_reason": blocked_reason,
	}


func _resolve_bowl_pos(owner: Object, companion_pos: Vector2) -> Vector2:
	var player_pos := BattleSceneOwnerReader.get_vector2(
		owner,
		"player_pos",
		Vector2(FIELD_WIDTH * 0.5 - DEFAULT_PLAYER_WIDTH * 0.5, FIELD_HEIGHT - DEFAULT_PLAYER_HEIGHT)
	)
	var player_width := maxf(
		1.0,
		float(BattleSceneOwnerReader.get_value(owner, "player_paddle_width", DEFAULT_PLAYER_WIDTH))
	)
	var player_height := maxf(
		1.0,
		float(BattleSceneOwnerReader.get_value(owner, "player_paddle_height", DEFAULT_PLAYER_HEIGHT))
	)
	var player_center_x := player_pos.x + player_width * 0.5
	var side := -1.0 if companion_pos.x <= player_center_x else 1.0
	var x := clampf(
		player_center_x + side * BOWL_PLAYER_SIDE_OFFSET,
		BOWL_EDGE_MARGIN_X,
		FIELD_WIDTH - BOWL_EDGE_MARGIN_X
	)
	var y := clampf(
		player_pos.y + player_height - BOWL_FLOOR_OFFSET_Y,
		BOWL_MIN_Y,
		FIELD_HEIGHT - BOWL_BOTTOM_MARGIN
	)
	return Vector2(x, y)


func _clear_pending() -> void:
	_pending_pet_id = ""
	_pending_feed_amount = 0.0
	_pending_registry = null
