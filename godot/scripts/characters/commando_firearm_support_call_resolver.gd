extends RefCounted


static func get_delay_frames(
	call_id: int,
	target: Vector2,
	min_frames: float,
	max_frames: float
) -> float:
	var span: int = int(max_frames - min_frames) + 1
	@warning_ignore("shadowed_global_identifier")
	var seed: int = support_call_seed(call_id, target)
	return min_frames + float(seed % max(1, span))


static func get_bomb_count(
	call_id: int,
	target: Vector2,
	min_count: int,
	max_count: int
) -> int:
	var span: int = int(max_count - min_count) + 1
	@warning_ignore("shadowed_global_identifier")
	var seed: int = support_call_seed(call_id + 17, target)
	return min_count + seed % max(1, span)


static func support_call_seed(call_id: int, target: Vector2) -> int:
	var raw: int = (
		call_id * 1103515245
		+ int(round(target.x * 13.0))
		+ int(round(target.y * 31.0))
		+ 12345
	)
	return abs(raw)
