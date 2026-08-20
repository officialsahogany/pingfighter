extends RefCounted

const RuntimePerkActiveUnlockFlight := preload(
	"res://scripts/characters/runtime_perk_active_unlock_flight.gd"
)

const DESTINATION_CHOSIK_SLOT := "chosik_slot"
const DESTINATION_BOTTOM_CENTER := "bottom_center"
const BOTTOM_CENTER_HEIGHT_RATIO := 0.91

var _chosik_target_resolver: Object = RuntimePerkActiveUnlockFlight.new()


func resolve_target(
	choice: Dictionary,
	owner: Object,
	registry: Object,
	view_size: Vector2
) -> Dictionary:
	if view_size.x <= 0.0 or view_size.y <= 0.0:
		return {}
	if is_chosik_choice(choice):
		if _chosik_target_resolver == null or not _chosik_target_resolver.has_method("resolve_target"):
			return {}
		var target_value: Variant = _chosik_target_resolver.call(
			"resolve_target",
			choice,
			owner,
			registry,
			view_size
		)
		if not (target_value is Dictionary):
			return {}
		var target := (target_value as Dictionary).duplicate(true)
		if not (target.get("target_pos", null) is Vector2) or (target.get("target_pos", Vector2.ZERO) as Vector2) == Vector2.ZERO:
			return {}
		target["destination_kind"] = DESTINATION_CHOSIK_SLOT
		return target
	return {
		"destination_kind": DESTINATION_BOTTOM_CENTER,
		"target_pos": Vector2(view_size.x * 0.5, view_size.y * BOTTOM_CENTER_HEIGHT_RATIO),
		"slot_index": -1,
	}


static func is_chosik_choice(choice: Dictionary) -> bool:
	var start_kind := str(choice.get("start_card_kind", "")).strip_edges().to_lower()
	if start_kind != "":
		return start_kind == "chosik"
	var reward_kind := str(choice.get("reward_pick_kind", "")).strip_edges().to_lower()
	if reward_kind != "":
		return reward_kind in ["chosik", "vision"]
	return (
		bool(choice.get("is_skill_manual", false))
		or str(choice.get("unlocks_skill", "")).strip_edges() != ""
	)
