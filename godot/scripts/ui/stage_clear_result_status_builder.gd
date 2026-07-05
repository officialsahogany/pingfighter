extends RefCounted

const StageClearResultActorStatusBuilder := preload("res://scripts/ui/stage_clear_result_actor_status_builder.gd")
const StageClearResultNonActorStatusBuilder := preload("res://scripts/ui/stage_clear_result_non_actor_status_builder.gd")
const StageClearResultSceneContextBuilder := preload("res://scripts/ui/stage_clear_result_scene_context_builder.gd")


static func build_scene_interaction_status(scene: Object, dalji_dialogue: String) -> Dictionary:
	return build_interaction_status(
		StageClearResultSceneContextBuilder.build_scene_context(scene, dalji_dialogue)
	)


static func build_interaction_status(context: Dictionary) -> Dictionary:
	var view_size: Vector2 = context.get("view_size", Vector2.ZERO)
	var layout_scale: float = float(context.get("layout_scale", 1.0))
	var current_stage: int = int(context.get("current_stage", 1))

	var status: Dictionary = {
		"current_stage": current_stage,
	}
	status.merge(StageClearResultNonActorStatusBuilder.build_non_actor_status(context), true)
	status.merge(
		StageClearResultActorStatusBuilder.build_actor_status(
			context,
			current_stage,
			view_size,
			layout_scale
		),
		true
	)
	return status
