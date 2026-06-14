extends RefCounted


static func finish_in_place(starpoint_drops: Array, collected_index: int, write_index: int, drop_count: int) -> void:
	if starpoint_drops.size() < drop_count:
		return
	var tail_write := write_index
	for tail_read in range(collected_index + 1, drop_count):
		starpoint_drops[tail_write] = starpoint_drops[tail_read]
		tail_write += 1
	starpoint_drops.resize(tail_write)


static func build_preserved_after_modal(
	starpoint_drops: Array,
	kept_drops: Array,
	collected_index: int,
	drop_count: int
) -> Array:
	if starpoint_drops.size() < drop_count:
		return starpoint_drops
	var preserved: Array = kept_drops.duplicate(false)
	for tail_read in range(collected_index + 1, drop_count):
		preserved.append(starpoint_drops[tail_read])
	return preserved
