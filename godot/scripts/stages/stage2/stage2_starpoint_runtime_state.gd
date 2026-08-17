extends RefCounted


var drops: Array = []
var particles: Array = []


func clear() -> bool:
	var had_runtime_state := has_runtime_state()
	drops.clear()
	particles.clear()
	return had_runtime_state


func has_runtime_state() -> bool:
	return not drops.is_empty() or not particles.is_empty()


func append_drop(drop: Dictionary) -> void:
	drops.append(drop)


func append_particles(entries: Array) -> void:
	particles.append_array(entries)


func get_drop_count() -> int:
	return drops.size()


func get_drop_snapshot() -> Array:
	return drops.duplicate(true)
