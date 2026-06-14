extends RefCounted

const StagePlayfieldBounds := preload("res://scripts/stages/common/stage_playfield_bounds.gd")


func get_left(context: Dictionary) -> float:
	return StagePlayfieldBounds.get_left(context)


func get_right(context: Dictionary) -> float:
	return StagePlayfieldBounds.get_right(context)


func get_height(context: Dictionary) -> float:
	return StagePlayfieldBounds.get_height(context)
