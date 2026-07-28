extends RefCounted

const INPUT_GUARD_SECONDS := 0.20

var active := false
var selected_index := 0
var elapsed := 0.0
var _pet_id := ""
var _candidates: Array[Dictionary] = []


func start(pet_id: String, candidates: Array) -> bool:
	var normalized: Array[Dictionary] = []
	for value in candidates:
		if value is Dictionary and str((value as Dictionary).get("type", "")).strip_edges() != "":
			normalized.append((value as Dictionary).duplicate(true))
	if normalized.size() < 2 or normalized.size() > 3:
		return false
	_pet_id = pet_id.strip_edges().to_lower()
	_candidates = normalized
	selected_index = 0
	elapsed = 0.0
	active = true
	return true


func advance(delta: float) -> void:
	if active:
		elapsed += maxf(0.0, delta)


func can_confirm() -> bool:
	return active and elapsed >= INPUT_GUARD_SECONDS and not _candidates.is_empty()


func move_selection(delta_index: int) -> int:
	if not active or _candidates.is_empty():
		return -1
	selected_index = posmod(selected_index + delta_index, _candidates.size())
	return selected_index


func select_index(index: int) -> bool:
	if not active or index < 0 or index >= _candidates.size():
		return false
	selected_index = index
	return true


func close() -> void:
	active = false
	elapsed = 0.0
	selected_index = 0
	_pet_id = ""
	_candidates.clear()


func reset() -> void:
	close()


func get_snapshot() -> Dictionary:
	return {
		"active": active,
		"pet_id": _pet_id,
		"candidates": _candidates.duplicate(true),
		"selected_index": selected_index,
		"elapsed": elapsed,
		"can_confirm": can_confirm(),
	}
