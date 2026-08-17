extends RefCounted

const MAX_PENDING_ACTIVATIONS := 16

var _pending_activations := 0


func notify_activation() -> void:
	_pending_activations = mini(MAX_PENDING_ACTIVATIONS, _pending_activations + 1)


func consume_pending_activations() -> int:
	var consumed := _pending_activations
	_pending_activations = 0
	return consumed


func peek_pending_activations() -> int:
	return _pending_activations


func reset() -> void:
	_pending_activations = 0
