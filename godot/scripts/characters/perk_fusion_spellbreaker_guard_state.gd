extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")

const BYPRODUCT_ID := "spellbreaker_guard"
const TRIGGER_CHANCE := 0.12
const DURATION_SEC := 5.0
const ACTIVATION_FLASH_SEC := 0.42
const PARRY_FLASH_SEC := 0.48
const PLAYER_SIZE_FALLBACK := Vector2(155.0, 50.0)

var _remaining_sec := 0.0
var _activation_flash_sec := 0.0
var _parry_flash_sec := 0.0
var _player_center := Vector2(380.0, 700.0)
var _last_parry_pos := Vector2.ZERO
var _last_roll_unit := -1.0
var _last_skill_id := ""
var _last_skill_label := ""
var _trigger_count := 0
var _parry_count := 0


func try_activate(owned_ids: Variant, roll_unit: float, player_center: Vector2) -> Dictionary:
	var result := {
		"rolled": false,
		"triggered": false,
		"chance": TRIGGER_CHANCE,
		"duration_sec": DURATION_SEC,
	}
	if not _owns_byproduct(owned_ids) or is_active():
		return result
	_last_roll_unit = clampf(roll_unit, 0.0, 1.0)
	result["rolled"] = true
	result["roll_unit"] = _last_roll_unit
	if _last_roll_unit >= TRIGGER_CHANCE:
		return result
	_remaining_sec = DURATION_SEC
	_activation_flash_sec = ACTIVATION_FLASH_SEC
	_player_center = player_center
	_trigger_count += 1
	result["triggered"] = true
	return result


func advance(delta: float, owner: Object = null) -> void:
	var safe_delta := maxf(0.0, delta)
	_remaining_sec = maxf(0.0, _remaining_sec - safe_delta)
	if _remaining_sec <= 0.0001:
		_remaining_sec = 0.0
	_activation_flash_sec = maxf(0.0, _activation_flash_sec - safe_delta)
	_parry_flash_sec = maxf(0.0, _parry_flash_sec - safe_delta)
	if owner != null:
		_player_center = _read_player_center(owner)


func is_active() -> bool:
	return _remaining_sec > 0.0


func try_parry(skill_id: String, skill_label: String, impact_pos: Vector2) -> Dictionary:
	var result := {
		"parried": false,
		"remaining_sec": _remaining_sec,
	}
	if not is_active():
		return result
	_last_skill_id = skill_id.strip_edges()
	_last_skill_label = skill_label.strip_edges()
	_last_parry_pos = impact_pos if impact_pos != Vector2.ZERO else _player_center
	_parry_flash_sec = PARRY_FLASH_SEC
	_parry_count += 1
	result["parried"] = true
	result["remaining_sec"] = _remaining_sec
	result["skill_id"] = _last_skill_id
	return result


func reset_round() -> void:
	_remaining_sec = 0.0
	_activation_flash_sec = 0.0
	_parry_flash_sec = 0.0
	_last_parry_pos = Vector2.ZERO
	_last_roll_unit = -1.0
	_last_skill_id = ""
	_last_skill_label = ""


func reset_all() -> void:
	reset_round()
	_trigger_count = 0
	_parry_count = 0


func has_visible_effects() -> bool:
	return is_active() or _activation_flash_sec > 0.0 or _parry_flash_sec > 0.0


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null or not has_visible_effects():
		return
	var center := _player_center + shake_offset
	if is_active():
		var life_ratio := clampf(_remaining_sec / DURATION_SEC, 0.0, 1.0)
		var pulse := 0.5 + 0.5 * sin(_remaining_sec * 7.4)
		var radius := 69.0 + pulse * 4.0
		canvas.draw_circle(center, radius, Color(0.20, 0.94, 1.0, 0.055 + 0.035 * pulse))
		canvas.draw_arc(center, radius, 0.0, TAU, 48, Color(0.34, 0.96, 1.0, 0.64 + 0.20 * pulse), 3.0, true)
		canvas.draw_arc(center, radius - 8.0, -PI * 0.5, PI * 1.5, 6, Color(0.72, 0.40, 1.0, 0.48 + 0.20 * pulse), 2.0, true)
		_draw_ward_runes(canvas, center, radius - 13.0, life_ratio)
	if _activation_flash_sec > 0.0:
		var activation_t := 1.0 - _activation_flash_sec / ACTIVATION_FLASH_SEC
		canvas.draw_arc(center, lerpf(34.0, 94.0, activation_t), 0.0, TAU, 48, Color(0.72, 0.96, 1.0, 0.72 * (1.0 - activation_t)), 5.0, true)
	if _parry_flash_sec > 0.0:
		var parry_t := 1.0 - _parry_flash_sec / PARRY_FLASH_SEC
		var parry_center := _last_parry_pos + shake_offset
		canvas.draw_line(center, parry_center, Color(0.48, 0.94, 1.0, 0.52 * (1.0 - parry_t)), 3.0, true)
		canvas.draw_arc(parry_center, lerpf(12.0, 48.0, parry_t), 0.0, TAU, 32, Color(0.86, 0.68, 1.0, 0.92 * (1.0 - parry_t)), 4.0, true)


func get_snapshot() -> Dictionary:
	return {
		"spellbreaker_guard_active": is_active(),
		"spellbreaker_guard_remaining_sec": _remaining_sec,
		"spellbreaker_guard_last_roll_unit": _last_roll_unit,
		"spellbreaker_guard_last_skill_id": _last_skill_id,
		"spellbreaker_guard_last_skill_label": _last_skill_label,
		"spellbreaker_guard_trigger_count": _trigger_count,
		"spellbreaker_guard_parry_count": _parry_count,
		"spellbreaker_guard_vfx_active": has_visible_effects(),
	}


func _draw_ward_runes(canvas: CanvasItem, center: Vector2, radius: float, alpha_scale: float) -> void:
	var points := PackedVector2Array()
	for index in range(6):
		var angle := -PI * 0.5 + TAU * float(index) / 6.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	for index in range(6):
		canvas.draw_line(points[index], points[(index + 2) % 6], Color(0.48, 0.86, 1.0, 0.34 + 0.18 * alpha_scale), 1.5, true)


func _read_player_center(owner: Object) -> Vector2:
	var size := Vector2(
		maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "player_paddle_width", PLAYER_SIZE_FALLBACK.x))),
		maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "player_paddle_height", PLAYER_SIZE_FALLBACK.y)))
	)
	var pos := BattleSceneOwnerReader.get_vector2(owner, "player_pos", _player_center - size * 0.5)
	return pos + size * 0.5


func _owns_byproduct(owned_ids: Variant) -> bool:
	match typeof(owned_ids):
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY:
			return BYPRODUCT_ID in owned_ids
		TYPE_DICTIONARY:
			var lookup: Dictionary = owned_ids as Dictionary
			return lookup.has(BYPRODUCT_ID) and bool(lookup.get(BYPRODUCT_ID, false))
	return false
