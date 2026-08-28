extends RefCounted

## Owns Commando-specific actor projection math and legacy overlay calibration.
## The shared actor context retains final public key assembly.

const CommandoWeaponAnchorTable := preload("res://scripts/characters/commando_weapon_anchor_table.gd")

const IDLE_FRAME_COUNT := 8
const IDLE_GRID_COLS := 4
const IDLE_GRID_ROWS := 2
const RADIO_CALL_FRAME_COUNT := 8
const RADIO_CALL_GRID_COLS := 4
const RADIO_CALL_GRID_ROWS := 2
const RADIO_CALL_FRAME_MSEC := 110

# Legacy replacement-overlay calibration. The active policy uses authored
# weapon-fire sheets, but the public context remains stable for gated fallback.
const WEAPON_OVERLAY_TABLE := {
	"ak47": {
		"texture_key": "commando_weapon_overlay_ak47",
		"anchor_back": Vector2(40.0, 102.0),
		"anchor_left": Vector2(20.0, 102.0),
		"anchor_right": Vector2(60.0, 102.0),
		"draw_size": Vector2(100.0, 30.0),
		"flip_h_for_walk_left": true,
	},
	"bazooka": {
		"texture_key": "commando_weapon_overlay_bazooka",
		"anchor_back": Vector2(35.0, 95.0),
		"anchor_left": Vector2(15.0, 95.0),
		"anchor_right": Vector2(55.0, 95.0),
		"draw_size": Vector2(110.0, 42.0),
		"flip_h_for_walk_left": true,
	},
	"net_gun": {
		"texture_key": "commando_weapon_overlay_net_gun",
		"anchor_back": Vector2(47.0, 95.0),
		"anchor_left": Vector2(27.0, 95.0),
		"anchor_right": Vector2(67.0, 95.0),
		"draw_size": Vector2(85.0, 47.0),
		"flip_h_for_walk_left": true,
	},
	"bowling_trap": {
		"texture_key": "commando_weapon_overlay_bowling_trap",
		"anchor_back": Vector2(75.0, 75.0),
		"anchor_left": Vector2(70.0, 75.0),
		"anchor_right": Vector2(80.0, 75.0),
		"draw_size": Vector2(31.0, 75.0),
		"flip_h_for_walk_left": false,
	},
	"suicide_drone": {
		"texture_key": "commando_weapon_overlay_suicide_drone",
		"anchor_back": Vector2(35.0, 60.0),
		"anchor_left": Vector2(15.0, 60.0),
		"anchor_right": Vector2(55.0, 60.0),
		"draw_size": Vector2(91.0, 95.0),
		"flip_h_for_walk_left": false,
	},
}

var weapon_anchor_table: Object = CommandoWeaponAnchorTable.new()


func get_b2_animation_state(
	is_commando: bool,
	player_speed: float,
	dash_active: bool,
	player_walk_direction: int
) -> String:
	if not is_commando:
		return ""
	var player_move_active: bool = abs(player_speed) > 0.2 or dash_active
	if not player_move_active:
		return CommandoWeaponAnchorTable.ANIMATION_IDLE_BACK
	if player_walk_direction < 0:
		return CommandoWeaponAnchorTable.ANIMATION_WALK_LEFT
	return CommandoWeaponAnchorTable.ANIMATION_WALK_RIGHT


func get_b2_frame_index(animation_state: String, animation_context: Dictionary) -> int:
	if animation_state == CommandoWeaponAnchorTable.ANIMATION_IDLE_BACK:
		return int(animation_context.get("player_idle_frame", 0))
	if (
		animation_state == CommandoWeaponAnchorTable.ANIMATION_WALK_LEFT
		or animation_state == CommandoWeaponAnchorTable.ANIMATION_WALK_RIGHT
		or animation_state == CommandoWeaponAnchorTable.ANIMATION_WALK_BACK
	):
		return int(animation_context.get("player_sprite_frame", 0))
	return 0


func get_weapon_fire_sheet(textures: Dictionary, weapon_id: String) -> Variant:
	match weapon_id:
		"ak47":
			return textures.get("commando_player_ak47_fire_sheet", null)
		"bazooka":
			return textures.get("commando_player_bazooka_fire_sheet", null)
		"net_gun":
			return textures.get("commando_player_net_gun_fire_sheet", null)
		"bowling_trap":
			return textures.get("commando_player_bowling_trap_place_sheet", null)
		"suicide_drone":
			return textures.get("commando_player_suicide_drone_control_sheet", null)
	return null


func get_weapon_fire_frame(fire_state: Dictionary) -> int:
	var frame_count: int = max(1, int(fire_state.get("frame_count", 8)))
	var timer_max: float = max(1.0, float(fire_state.get("timer_max_frames", 1.0)))
	var timer: float = clamp(float(fire_state.get("timer_frames", 0.0)), 0.0, timer_max)
	var progress: float = clamp(1.0 - timer / timer_max, 0.0, 1.0)
	return clamp(int(progress * float(frame_count)), 0, frame_count - 1)


func get_weapon_fire_flip_h(
	active: bool,
	weapon_id: String,
	player_walk_direction: int,
	player_pos: Vector2,
	player_size: Vector2,
	commando_firearm_context: Dictionary
) -> bool:
	if not active:
		return false
	if weapon_id == "suicide_drone":
		return _get_suicide_drone_control_flip_h(player_pos, player_size, commando_firearm_context)
	return player_walk_direction < 0


func is_supply_radio_motion(deps: Dictionary) -> bool:
	var supply_state: Object = deps.get("commando_supply_drop_state", null) as Object
	if supply_state == null:
		return false
	if supply_state.has_method("get_snapshot"):
		var snapshot := _get_dict(supply_state.get_snapshot())
		return bool(snapshot.get("radio_motion", false))
	return bool(supply_state.get("radio_motion"))


func is_reload_radio_motion(deps: Dictionary) -> bool:
	var reload_state: Object = deps.get("commando_reload_delivery_state", null) as Object
	if reload_state == null:
		return false
	if reload_state.has_method("get_snapshot"):
		var snapshot := _get_dict(reload_state.get_snapshot())
		if snapshot.has("radio_visible"):
			return bool(snapshot.get("radio_visible", false)) and float(snapshot.get("radio_alpha", 1.0)) > 0.0
	return bool(reload_state.get("active")) and str(reload_state.get("phase")) == "radio"


func is_fire_support_radio_motion(commando_firearm_context: Dictionary) -> bool:
	for value in _get_array(commando_firearm_context.get("commando_firearm_support_calls", [])):
		var call := _get_dict(value)
		if str(call.get("weapon_id", "")) != "fire_support":
			continue
		if (
			bool(call.get("radio_active", false))
			or float(call.get("radio_timer_frames", 0.0)) > 0.0
			or str(call.get("state", "")) == "calling"
		):
			return true
	return false


func get_radio_call_frame(context: Dictionary) -> int:
	var current_msec: int = max(0, int(context.get("current_msec", Time.get_ticks_msec())))
	return int(floor(float(current_msec) / float(RADIO_CALL_FRAME_MSEC))) % RADIO_CALL_FRAME_COUNT


func get_frame_anchor(animation_state: String, frame_index: int) -> Dictionary:
	return weapon_anchor_table.get_frame_anchor(animation_state, frame_index)


func get_weapon_pivot(weapon_id: String) -> Dictionary:
	return weapon_anchor_table.get_weapon_pivot(weapon_id)


func is_b2_overlay_renderable(animation_state: String, frame_index: int, weapon_id: String) -> bool:
	return weapon_anchor_table.is_overlay_renderable(animation_state, frame_index, weapon_id)


func is_walk_left_animation(animation_state: String) -> bool:
	return animation_state == CommandoWeaponAnchorTable.ANIMATION_WALK_LEFT


func resolve_b2_anchor(
	frame_anchor: Dictionary,
	weapon_pivot: Dictionary,
	animation_state: String
) -> Vector2:
	var anchor_overrides: Variant = weapon_pivot.get("anchor_overrides", {})
	if anchor_overrides is Dictionary and anchor_overrides.has(animation_state):
		var override_value: Variant = anchor_overrides[animation_state]
		if override_value is Vector2:
			return override_value
	var primary_anchor: Variant = frame_anchor.get("primary", Vector2.ZERO)
	return primary_anchor if primary_anchor is Vector2 else Vector2.ZERO


func get_overlay_texture_key(weapon_id: String) -> String:
	return String(_get_overlay_entry(weapon_id).get("texture_key", ""))


func get_overlay_anchor_back(weapon_id: String) -> Vector2:
	return _get_overlay_entry(weapon_id).get("anchor_back", Vector2.ZERO)


func get_overlay_anchor_left(weapon_id: String) -> Vector2:
	return _get_overlay_entry(weapon_id).get("anchor_left", Vector2.ZERO)


func get_overlay_anchor_right(weapon_id: String) -> Vector2:
	return _get_overlay_entry(weapon_id).get("anchor_right", Vector2.ZERO)


func get_overlay_draw_size(weapon_id: String) -> Vector2:
	return _get_overlay_entry(weapon_id).get("draw_size", Vector2.ZERO)


func get_overlay_flip_h_for_walk_left(weapon_id: String) -> bool:
	return bool(_get_overlay_entry(weapon_id).get("flip_h_for_walk_left", false))


func _get_suicide_drone_control_flip_h(
	player_pos: Vector2,
	player_size: Vector2,
	commando_firearm_context: Dictionary
) -> bool:
	var drone_state: Dictionary = _get_dict(commando_firearm_context.get("commando_firearm_suicide_drone_state", {}))
	if not bool(drone_state.get("active", false)):
		return false
	var drone_pos: Vector2 = _get_vector2(drone_state, "pos", player_pos)
	var player_center_x: float = player_pos.x + max(0.0, player_size.x) * 0.5
	return drone_pos.x < player_center_x - 0.5


func _get_overlay_entry(weapon_id: String) -> Dictionary:
	var value: Variant = WEAPON_OVERLAY_TABLE.get(weapon_id, null)
	return value as Dictionary if value is Dictionary else {}


func _get_dict(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


func _get_array(value: Variant) -> Array:
	return value as Array if value is Array else []


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	return value as Vector2 if value is Vector2 else fallback
