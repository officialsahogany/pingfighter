extends RefCounted

# Read-only Stage 6 actor / boss-AI context projection.
#
# Focused owners decide whether their snapshots are copies or borrowed values.
# This builder preserves those boundaries and performs no additional deep copy.


func build_actor_draw_context(
	cell_size: float,
	tetromino_state: Object,
	guard_state: Object,
	wall_state: Object,
	combat_feedback: Object,
	cube_state: Object,
	starpoint_state: Object,
	super_state: Object,
	crystal_shield: Object,
	super_laser_target: Vector2
) -> Dictionary:
	var context := {
		"stage6_tetriser_tetrominoes": tetromino_state.get_draw_list(),
		"stage6_tetriser_guard_blocks": guard_state.get_draw_list(),
		"stage6_tetriser_wall_cells": wall_state.get_draw_list(),
		"stage6_tetriser_debris": combat_feedback.get_debris_draw_list(),
		"stage6_tetriser_cell_size": cell_size,
		"stage6_tetriser_cube": cube_state.get_draw_data(),
		"stage6_tetriser_emp": combat_feedback.get_emp_draw_list(),
		"stage6_tetriser_starpoint_drops": starpoint_state.get_draw_list(),
	}
	context.merge(super_state.get_actor_draw_context(super_laser_target), true)
	context.merge(crystal_shield.get_actor_draw_context(), true)
	return context


func build_boss_ai_context(
	boss_gauge: float,
	tetromino_state: Object,
	super_state: Object,
	crystal_shield: Object
) -> Dictionary:
	var context := {
		"stage6_tetriser_boss_gauge": boss_gauge,
		"stage6_tetriser_tetromino_count": tetromino_state.get_count(),
		"stage6_tetriser_super_active": super_state.is_active(),
		"stage6_tetriser_super_scale": super_state.get_scale(),
	}
	context.merge(crystal_shield.get_boss_ai_context(), true)
	return context
