extends RefCounted

const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)
const TowerAscentMapGenerator := preload(
	"res://scripts/tower_ascent/tower_ascent_map_generator.gd"
)

# GRT-054 형제: 발사 비행 예산은 생산 발사 속도에서 파생한다. 고정 1.5초는
# 구 522px/s 시절 값이라 재감속(274px/s, 피드백3 7항) 때 단일 스텝 이동이
# 표적에 못 미쳐 전 노드 스모크의 도달 픽스처가 조용히 깨졌다.
const REFERENCE_FLIGHT_SECONDS := 1.5
const REFERENCE_SERVE_SPEED_PER_SECOND := 522.0


# GRT-054 형제: 노드 스모크의 map_seed 리터럴은 생성기 버전이 바뀔 때마다
# 1층 구성표와 조용히 어긋난다(v11 1층 보스 로스터 개편으로 시드 3/4/5의 1층에서
# 해당 노드가 사라져 도달 씰이 전멸한 사고). 시드는 현행 생성기에서 파생한다.
static func find_initial_route_seed(expected_kind: String) -> int:
	var generator := TowerAscentMapGenerator.new()
	for map_seed in range(1, 513):
		var graph: Dictionary = generator.generate_tower(map_seed)
		if graph.is_empty():
			continue
		var phases: Array = graph.get("phases", [])
		if phases.is_empty():
			continue
		var phase: Dictionary = phases[0]
		var node_by_id: Dictionary = {}
		for node_variant in phase.get("nodes", []):
			if node_variant is Dictionary:
				var node := node_variant as Dictionary
				node_by_id[str(node.get("id", ""))] = node
		for node_id_variant in phase.get("initial_route_candidate_ids", []):
			var node: Dictionary = node_by_id.get(str(node_id_variant), {})
			if str(node.get("kind", "")) == expected_kind:
				return map_seed
	return 0


static func advance_to_node_modal(
	flow: Object,
	expected_kind: String,
	owner: Object = null
) -> bool:
	if flow == null or not flow.has_method("get_phase_name"):
		return false
	if str(flow.get_phase_name()) != "ROUTE_AIM":
		return false
	var target_index := -1
	var targets: Array[Dictionary] = flow.get_route_aim_targets()
	for index in range(targets.size()):
		if str(targets[index].get("kind", "")) == expected_kind:
			target_index = index
			break
	if target_index < 0:
		return false
	flow.debug_launch_at_target(target_index)
	flow.update_selective(
		REFERENCE_FLIGHT_SECONDS * REFERENCE_SERVE_SPEED_PER_SECOND / maxf(
			1.0,
			TowerAscentTuning.TEMP_ROUTE_AIM_SERVE_SPEED_PER_SECOND
		),
		owner
	)
	if str(flow.get_phase_name()) != "MAP_TRANSITION":
		return false
	flow.update_selective(1.0, owner)
	return (
		str(flow.get_phase_name()) == "NODE_MODAL"
		and str(flow.get_node_modal_kind()) == expected_kind
	)
