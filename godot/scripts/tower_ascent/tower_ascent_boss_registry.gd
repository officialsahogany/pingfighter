extends RefCounted

const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)
const TowerAuditionBuildConfig := preload(
	"res://scripts/tower_ascent/tower_audition_build_config.gd"
)
const StageBossVariantCatalog := preload(
	"res://scripts/stages/common/stage_boss_variant_catalog.gd"
)

const STATUS_PORTED := "ported"
const STATUS_UNPORTED := "unported"
const STATUS_SHELL := "shell"
const STATUS_NEW_DESIGN := "new_design"
const CONTENT_GENERATED := "generated"
const CONTENT_REGISTRY_ONLY := "registry_only"
const FOUR_KINGS_GROUP_SLOT_ID := "floor_11_four_kings_group"
const COMBAT_NODE_KINDS := ["boss", "combat", "enraged"]
const NPC_FILL_KINDS: Array[String] = [
	"rest",
	"guardian_spring",
	"fallen_monk",
	"shop",
	"training",
]
const NPC_FILL_LABELS := {
	"rest": "휴식",
	"guardian_spring": "샘터",
	"fallen_monk": "파계승",
	"shop": "상점",
	"training": "수련장",
}

const FLOOR_BOSS_SLOTS := {
	1: [
		{"slot_id": "floor_01_dalji", "display_name": "달지", "status": STATUS_PORTED, "stage": 1, "boss_id": "dalji", "variant": "dalji"},
		{"slot_id": "floor_01_gaksital", "display_name": "각시탈", "status": STATUS_PORTED, "stage": 1, "boss_id": "gaksital", "variant": "gaksi"},
		{"slot_id": "floor_01_podo", "display_name": "포도대장", "status": STATUS_PORTED, "stage": 1, "boss_id": "podo", "variant": "podo"},
	],
	2: [
		{"slot_id": "floor_02_cheongringwi", "status": STATUS_PORTED, "stage": 2, "boss_id": "cheongringwi"},
		{"slot_id": "floor_02_molewang", "status": STATUS_PORTED, "stage": 2, "boss_id": "cheongringwi", "variant": "molewang"},
		{"slot_id": "floor_02_arachne", "status": STATUS_PORTED, "stage": 2, "boss_id": "cheongringwi", "variant": "arachne"},
	],
	3: [
		{"slot_id": "floor_03_yeonmyo", "status": STATUS_PORTED, "stage": 3, "boss_id": "yeonmyo"},
		{"slot_id": "floor_03_teddy_bear", "status": STATUS_PORTED, "stage": 3, "boss_id": "yeonmyo", "variant": "teddy_bear"},
		{"slot_id": "floor_03_alice", "status": STATUS_PORTED, "stage": 3, "boss_id": "yeonmyo", "variant": "alice"},
	],
	4: [
		{"slot_id": "floor_04_ponk", "display_name": "퐁크", "status": STATUS_PORTED, "stage": 4, "boss_id": "ponk"},
		{"slot_id": "floor_04_shell_01", "display_name": "임시 보스", "status": STATUS_SHELL},
		{"slot_id": "floor_04_shell_02", "display_name": "임시 보스", "status": STATUS_SHELL},
	],
	5: [
		{"slot_id": "floor_05_hongryun", "display_name": "홍련", "status": STATUS_PORTED, "stage": 5, "boss_id": "hongryun"},
		{"slot_id": "floor_05_shell_01", "display_name": "임시 보스", "status": STATUS_SHELL},
		{"slot_id": "floor_05_shell_02", "display_name": "임시 보스", "status": STATUS_SHELL},
	],
	6: [
		{"slot_id": "floor_06_tetriser", "display_name": "테트리서", "status": STATUS_PORTED, "stage": 6, "boss_id": "tetriser"},
		{"slot_id": "floor_06_shell_01", "display_name": "임시 보스", "status": STATUS_SHELL},
		{"slot_id": "floor_06_shell_02", "display_name": "임시 보스", "status": STATUS_SHELL},
	],
	7: [
		{"slot_id": "floor_07_akamu_rigo", "display_name": "아카무 리고", "status": STATUS_PORTED, "stage": 7, "boss_id": "akamu_rigo"},
		{"slot_id": "floor_07_shell_01", "display_name": "임시 보스", "status": STATUS_SHELL},
		{"slot_id": "floor_07_shell_02", "display_name": "임시 보스", "status": STATUS_SHELL},
	],
	8: [
		{"slot_id": "floor_08_minotaur", "display_name": "미노타우로스", "status": STATUS_PORTED, "stage": 8, "boss_id": "minotaur"},
		{"slot_id": "floor_08_shell_01", "display_name": "임시 보스", "status": STATUS_SHELL},
		{"slot_id": "floor_08_shell_02", "display_name": "임시 보스", "status": STATUS_SHELL},
	],
	9: [
		{"slot_id": "floor_09_fake_ending", "display_name": "가짜 엔딩 보스", "status": STATUS_NEW_DESIGN},
	],
	10: [
		{"slot_id": "floor_10_shell_01", "display_name": "임시 보스", "status": STATUS_SHELL},
		{"slot_id": "floor_10_shell_02", "display_name": "임시 보스", "status": STATUS_SHELL},
		{"slot_id": "floor_10_shell_03", "display_name": "임시 보스", "status": STATUS_SHELL},
	],
	11: [
		{"slot_id": "floor_11_king_01", "display_name": "4천왕 슬롯", "status": STATUS_NEW_DESIGN},
		{"slot_id": "floor_11_king_02", "display_name": "4천왕 슬롯", "status": STATUS_NEW_DESIGN},
		{"slot_id": "floor_11_king_03", "display_name": "4천왕 슬롯", "status": STATUS_NEW_DESIGN},
		{"slot_id": "floor_11_king_04", "display_name": "4천왕 슬롯", "status": STATUS_NEW_DESIGN},
	],
	12: [
		{"slot_id": "floor_12_true_ending", "display_name": "진엔딩 보스", "status": STATUS_NEW_DESIGN},
	],
}


func get_floor_slots(floor_number: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot_variant in FLOOR_BOSS_SLOTS.get(floor_number, []):
		if slot_variant is Dictionary:
			var slot: Dictionary = (slot_variant as Dictionary).duplicate(true)
			slot["slot_floor"] = floor_number
			result.append(_with_canonical_display_name(slot))
	return result


func _with_canonical_display_name(slot: Dictionary) -> Dictionary:
	var stage_id: int = int(slot.get("stage", 0))
	if stage_id not in StageBossVariantCatalog.DEFAULT_VARIANT_BY_STAGE:
		return slot
	var variant_id: String = str(slot.get("variant", slot.get("boss_id", "")))
	var entry: Dictionary = StageBossVariantCatalog.get_entry(stage_id, variant_id)
	var display_name: String = str(entry.get("display_name", ""))
	if display_name != "":
		slot["display_name"] = display_name
	return slot


func get_seeded_floor_slots(floor_number: int, map_seed: int) -> Array[Dictionary]:
	return _get_shuffled_generation_slots(floor_number, map_seed)


func get_slot(slot_id: String) -> Dictionary:
	for floor_number in range(1, 13):
		for slot in get_floor_slots(floor_number):
			if str(slot.get("slot_id", "")) == slot_id:
				return slot
	return {}


func get_standin(slot_id: String) -> Dictionary:
	var slot := get_slot(slot_id)
	if slot.is_empty():
		return {}
	if str(slot.get("status", "")) == STATUS_PORTED:
		return {
			"stage": int(slot.get("stage", 0)),
			"boss_id": str(slot.get("boss_id", "")),
			"variant": str(slot.get("variant", "")),
		}
	var standin_variant: Variant = TowerAscentTuning.TEMP_BOSS_STANDIN_BY_SLOT.get(slot_id, {})
	return (standin_variant as Dictionary).duplicate(true) if standin_variant is Dictionary else {}


func resolve_battle_encounter(slot_id: String) -> Dictionary:
	var slot := get_slot(slot_id)
	if slot.is_empty():
		return {}
	var route := get_standin(slot_id)
	var stage_id := int(route.get("stage", 0))
	var boss_id := str(route.get("boss_id", "")).strip_edges()
	if stage_id <= 0 or boss_id.is_empty():
		return {}
	var status := str(slot.get("status", ""))
	return {
		"boss_slot_id": slot_id,
		"display_name": str(slot.get("display_name", boss_id)),
		"stage": stage_id,
		"boss_id": boss_id,
		"variant": str(route.get("variant", "")).strip_edges().to_lower(),
		"fallback_used": status != STATUS_PORTED,
		"source_status": status,
	}


func canonical_encounter_key(route: Dictionary) -> String:
	var stage_id := int(route.get("stage", 0))
	var variant_id := str(route.get("variant", "")).strip_edges().to_lower()
	var boss_id := str(route.get("boss_id", "")).strip_edges().to_lower()
	var encounter_id := variant_id if not variant_id.is_empty() else boss_id
	if stage_id <= 0 or encounter_id.is_empty():
		return ""
	return "%d:%s" % [stage_id, encounter_id]


func decorate_graph(graph: Dictionary, map_seed: int) -> Dictionary:
	var result := graph.duplicate(true)
	var phases_variant: Variant = result.get("phases", [])
	if not (phases_variant is Array) or (phases_variant as Array).is_empty():
		return {}
	var phase: Dictionary = (phases_variant as Array)[0]
	var nodes: Array = phase.get("nodes", [])
	var active_clear_floor := _resolve_active_clear_floor(result)
	var used_generated_encounter_keys: Dictionary = {}
	var generated_boss_budget := _generated_boss_budget(nodes, active_clear_floor)
	var assigned_generated_boss_count := 0
	var terminal_node_index := _find_generated_terminal_node_index(
		nodes,
		active_clear_floor
	)
	if terminal_node_index >= 0:
		var terminal_slots := _get_shuffled_generation_slots(
			active_clear_floor,
			map_seed
		)
		if terminal_slots.is_empty():
			return {}
		var terminal_slot := terminal_slots[0]
		var terminal_key := canonical_encounter_key(
			get_standin(str(terminal_slot.get("slot_id", "")))
		)
		if terminal_key.is_empty():
			return {}
		_assign_boss_slot(
			nodes[terminal_node_index] as Dictionary,
			terminal_slot,
			terminal_slots,
			terminal_key
		)
		used_generated_encounter_keys[terminal_key] = true
		assigned_generated_boss_count = 1
	var generated_candidates := _generated_boss_candidate_indexes(
		nodes,
		active_clear_floor,
		terminal_node_index,
		map_seed
	)
	var unique_exhausted_node_indexes: Dictionary = {}
	for candidate_index in generated_candidates:
		if assigned_generated_boss_count >= generated_boss_budget:
			break
		var candidate_node := nodes[candidate_index] as Dictionary
		var floor_number := int(
			candidate_node.get("segment_floor", candidate_node.get("floor", 0))
		)
		var slots := _get_shuffled_generation_slots(floor_number, map_seed)
		var assigned_candidate := false
		for slot in slots:
			var slot_id := str(slot.get("slot_id", ""))
			var encounter_key := canonical_encounter_key(get_standin(slot_id))
			if encounter_key.is_empty() or used_generated_encounter_keys.has(encounter_key):
				continue
			_assign_boss_slot(candidate_node, slot, slots, encounter_key)
			used_generated_encounter_keys[encounter_key] = true
			assigned_generated_boss_count += 1
			assigned_candidate = true
			break
		if not assigned_candidate:
			unique_exhausted_node_indexes[candidate_index] = true
	for node_index in range(nodes.size()):
		if node_index == terminal_node_index or not (nodes[node_index] is Dictionary):
			continue
		var node := nodes[node_index] as Dictionary
		var segment_floor := int(node.get("segment_floor", node.get("floor", 0)))
		if (
			segment_floor <= active_clear_floor
			and str(node.get("content_state", "")) == CONTENT_GENERATED
			and str(node.get("kind", "")) in COMBAT_NODE_KINDS
			and str(node.get("boss_assignment_state", "")) != "assigned"
		):
			_assign_deterministic_npc_fill(
				node,
				nodes,
				map_seed,
				_slot_ids(_get_shuffled_generation_slots(segment_floor, map_seed)),
				(
					"unique_visible_pool_exhausted"
					if unique_exhausted_node_indexes.has(node_index)
					else "boss_density_budget_exhausted"
				)
			)
	# Locked registry-only floors retain preview metadata but never consume the
	# visible-run density or uniqueness budgets.
	for floor_number in range(active_clear_floor + 1, 13):
		var boss_node_indexes: Array[int] = []
		for node_index in range(nodes.size()):
			var node_variant: Variant = nodes[node_index]
			if not (node_variant is Dictionary):
				continue
			var node := node_variant as Dictionary
			if (
				int(node.get("segment_floor", node.get("floor", 0))) == floor_number
				and str(node.get("kind", "")) in COMBAT_NODE_KINDS
			):
				boss_node_indexes.append(node_index)
		var slots := _get_shuffled_generation_slots(floor_number, map_seed)
		if boss_node_indexes.is_empty():
			continue
		if floor_number == 11:
			_assign_four_kings_group(nodes[boss_node_indexes[0]] as Dictionary, slots)
			for extra_index in range(1, boss_node_indexes.size()):
				_assign_deterministic_npc_fill(
					nodes[boss_node_indexes[extra_index]] as Dictionary,
					nodes,
					map_seed,
					_slot_ids(slots)
				)
			continue
		var used_floor_registry_keys: Dictionary = {}
		for node_index in boss_node_indexes:
			var node := nodes[node_index] as Dictionary
			var assigned := false
			for slot in slots:
				var slot_id := str(slot.get("slot_id", ""))
				var encounter_key := canonical_encounter_key(get_standin(slot_id))
				if encounter_key.is_empty():
					continue
				if used_floor_registry_keys.has(encounter_key):
					continue
				_assign_boss_slot(node, slot, slots, encounter_key)
				used_floor_registry_keys[encounter_key] = true
				assigned = true
				break
			if not assigned:
				_assign_deterministic_npc_fill(
					node,
					nodes,
					map_seed,
					_slot_ids(slots)
				)
	phase["nodes"] = nodes
	result["phases"] = [phase]
	var contract := analyze_visible_boss_contract(result, active_clear_floor)
	if not bool(contract.get("valid", false)):
		return {}
	return result


func get_generation_slots(floor_number: int) -> Array[Dictionary]:
	var slots := get_floor_slots(floor_number)
	if not TowerAuditionBuildConfig.is_linear_floor(floor_number):
		return slots
	var ported_slots: Array[Dictionary] = []
	for slot in slots:
		if str(slot.get("status", "")) == STATUS_PORTED:
			ported_slots.append(slot)
	return ported_slots


func analyze_visible_boss_contract(
	graph: Dictionary,
	active_clear_floor: int = -1
) -> Dictionary:
	var resolved_clear_floor := (
		active_clear_floor
		if active_clear_floor > 0
		else _resolve_active_clear_floor(graph)
	)
	var issues: Array[String] = []
	var used_encounter_keys: Dictionary = {}
	var visible_encounter_count := 0
	for phase_variant in graph.get("phases", []):
		if not (phase_variant is Dictionary):
			continue
		for node_variant in (phase_variant as Dictionary).get("nodes", []):
			if not (node_variant is Dictionary):
				continue
			var node := node_variant as Dictionary
			var segment_floor := int(node.get("segment_floor", node.get("floor", 0)))
			if (
				str(node.get("content_state", "")) != CONTENT_GENERATED
				or segment_floor > resolved_clear_floor
				or str(node.get("kind", "")) not in COMBAT_NODE_KINDS
			):
				continue
			if str(node.get("boss_slot_id", "")) == FOUR_KINGS_GROUP_SLOT_ID:
				var sequence_ids: Array = node.get("boss_sequence_slot_ids", [])
				for sequence_slot_variant in sequence_ids:
					_register_visible_encounter(
						str(sequence_slot_variant),
						segment_floor,
						str(node.get("id", "")),
						used_encounter_keys,
						issues
					)
					visible_encounter_count += 1
				continue
			var slot_id := str(node.get("boss_slot_id", ""))
			if slot_id.is_empty():
				issues.append("visible_boss_missing_slot=%s" % str(node.get("id", "")))
				continue
			_register_visible_encounter(
				slot_id,
				segment_floor,
				str(node.get("id", "")),
				used_encounter_keys,
				issues
			)
			visible_encounter_count += 1
	return {
		"valid": issues.is_empty(),
		"issues": issues,
		"active_clear_floor": resolved_clear_floor,
		"visible_encounter_count": visible_encounter_count,
		"unique_encounter_count": used_encounter_keys.size(),
	}


func _generated_boss_budget(nodes: Array, active_clear_floor: int) -> int:
	var generated_node_count := 0
	for node_variant in nodes:
		if not (node_variant is Dictionary):
			continue
		var node := node_variant as Dictionary
		if (
			str(node.get("content_state", "")) == CONTENT_GENERATED
			and int(node.get("segment_floor", node.get("floor", 0))) <= active_clear_floor
		):
			generated_node_count += 1
	return maxi(
		1,
		floori(
			float(generated_node_count)
			* TowerAscentTuning.TEMP_GENERATED_BOSS_NODE_MAX_RATIO
		)
	)


func _generated_boss_candidate_indexes(
	nodes: Array,
	active_clear_floor: int,
	terminal_node_index: int,
	map_seed: int
) -> Array[int]:
	var indexes_by_floor: Dictionary = {}
	for node_index in range(nodes.size()):
		if node_index == terminal_node_index or not (nodes[node_index] is Dictionary):
			continue
		var node := nodes[node_index] as Dictionary
		var floor_number := int(node.get("segment_floor", node.get("floor", 0)))
		if (
			floor_number <= 0
			or floor_number > active_clear_floor
			or str(node.get("content_state", "")) != CONTENT_GENERATED
			or str(node.get("kind", "")) not in COMBAT_NODE_KINDS
		):
			continue
		var floor_indexes: Array = indexes_by_floor.get(floor_number, [])
		floor_indexes.append(node_index)
		indexes_by_floor[floor_number] = floor_indexes
	var maximum_lane_count := 0
	for floor_number in range(1, active_clear_floor + 1):
		var floor_indexes: Array = indexes_by_floor.get(floor_number, [])
		if floor_indexes.size() > 1:
			var start_index := _stable_npc_fill_index(
				map_seed,
				"generated_boss_floor_%02d" % floor_number,
				floor_indexes.size()
			)
			var rotated: Array = []
			for offset in range(floor_indexes.size()):
				rotated.append(floor_indexes[(start_index + offset) % floor_indexes.size()])
			indexes_by_floor[floor_number] = rotated
		maximum_lane_count = maxi(maximum_lane_count, floor_indexes.size())
	var result: Array[int] = []
	# Round-robin by lane gives each reachable floor a boss before any floor
	# receives a second parallel boss choice. The terminal reservation remains
	# first and cannot be normalized into an NPC.
	for lane_round in range(maximum_lane_count):
		for floor_number in range(1, active_clear_floor + 1):
			var floor_indexes: Array = indexes_by_floor.get(floor_number, [])
			if lane_round < floor_indexes.size():
				result.append(int(floor_indexes[lane_round]))
	return result


func _register_visible_encounter(
	slot_id: String,
	segment_floor: int,
	node_id: String,
	used_encounter_keys: Dictionary,
	issues: Array[String]
) -> void:
	var slot := get_slot(slot_id)
	if slot.is_empty():
		issues.append("unknown_boss_slot=%s:%s" % [node_id, slot_id])
		return
	var slot_floor := int(slot.get("slot_floor", 0))
	if slot_floor != segment_floor:
		issues.append(
			"slot_floor_mismatch=%s:segment_%d:slot_%d"
			% [node_id, segment_floor, slot_floor]
		)
	var encounter_key := canonical_encounter_key(get_standin(slot_id))
	if encounter_key.is_empty():
		issues.append("missing_encounter_key=%s:%s" % [node_id, slot_id])
		return
	if segment_floor == 1 and int(get_standin(slot_id).get("stage", 0)) != 1:
		issues.append("floor_1_forbidden_encounter=%s:%s" % [node_id, encounter_key])
	if used_encounter_keys.has(encounter_key):
		issues.append(
			"duplicate_encounter_key=%s:first_%s:again_%s"
			% [encounter_key, str(used_encounter_keys[encounter_key]), node_id]
		)
		return
	used_encounter_keys[encounter_key] = node_id


func _resolve_active_clear_floor(graph: Dictionary) -> int:
	for phase_variant in graph.get("phases", []):
		if not (phase_variant is Dictionary):
			continue
		var clear_floor := int((phase_variant as Dictionary).get("standard_clear_floor", 0))
		if clear_floor > 0:
			return clear_floor
	return TowerAuditionBuildConfig.get_clear_floor()


func _find_generated_terminal_node_index(nodes: Array, active_clear_floor: int) -> int:
	for node_index in range(nodes.size()):
		if not (nodes[node_index] is Dictionary):
			continue
		var node := nodes[node_index] as Dictionary
		if (
			int(node.get("segment_floor", node.get("floor", 0))) == active_clear_floor
			and str(node.get("content_state", "")) == CONTENT_GENERATED
			and bool(node.get("gatekeeper", false))
			and bool(node.get("floor_boundary", false))
			and str(node.get("kind", "")) == "boss"
		):
			return node_index
	return -1


func _get_shuffled_generation_slots(
	floor_number: int,
	map_seed: int
) -> Array[Dictionary]:
	var slots := get_generation_slots(floor_number)
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed ^ 0x4D4150 ^ (floor_number * 0x45D9F3B)
	_shuffle_slots(slots, rng)
	return slots


func _assign_boss_slot(
	node: Dictionary,
	slot: Dictionary,
	pool_slots: Array[Dictionary],
	encounter_key: String
) -> void:
	var slot_id := str(slot.get("slot_id", ""))
	node["boss_slot_id"] = slot_id
	node["boss_pool_slot_ids"] = _slot_ids(pool_slots)
	node["boss_port_status"] = str(slot.get("status", ""))
	node["boss_encounter_key"] = encounter_key
	node["boss_assignment_state"] = "assigned"
	node["standin"] = get_standin(slot_id)
	node["label"] = str(slot.get("display_name", node.get("label", "보스")))
	if str(slot.get("status", "")) != STATUS_PORTED:
		node["encounter_locked"] = true


func _assign_four_kings_group(node: Dictionary, slots: Array[Dictionary]) -> void:
	var group_slot_ids: Array[String] = []
	var group_standins: Array[Dictionary] = []
	var group_encounter_keys: Array[String] = []
	for slot in slots:
		var slot_id := str(slot.get("slot_id", ""))
		group_slot_ids.append(slot_id)
		var standin := get_standin(slot_id)
		group_standins.append(standin)
		group_encounter_keys.append(canonical_encounter_key(standin))
	node["boss_slot_id"] = FOUR_KINGS_GROUP_SLOT_ID
	node["boss_sequence_slot_ids"] = group_slot_ids
	node["standin_sequence"] = group_standins
	node["boss_encounter_keys"] = group_encounter_keys
	node["boss_assignment_state"] = "assigned"
	node["label"] = "4천왕"
	node["encounter_locked"] = true
	# These stand-ins intentionally consume no visible-run uniqueness while their
	# content_state is registry_only. If active_clear_floor reaches 11 or 12, the
	# contract seal must fail until real, unique boss content replaces them.


func _assign_deterministic_npc_fill(
	node: Dictionary,
	nodes: Array,
	map_seed: int,
	pool_slot_ids: Array[String],
	reason: String = "unique_visible_pool_exhausted"
) -> void:
	var row_kinds: Dictionary = {}
	var global_row := int(node.get("global_row", -1))
	for peer_variant in nodes:
		if not (peer_variant is Dictionary):
			continue
		var peer := peer_variant as Dictionary
		if int(peer.get("global_row", -2)) != global_row:
			continue
		var peer_kind := str(peer.get("kind", ""))
		if peer_kind in NPC_FILL_KINDS:
			row_kinds[peer_kind] = true
	var start_index := _stable_npc_fill_index(
		map_seed,
		str(node.get("id", "")),
		NPC_FILL_KINDS.size()
	)
	var chosen_kind := NPC_FILL_KINDS[start_index]
	for offset in range(NPC_FILL_KINDS.size()):
		var candidate := NPC_FILL_KINDS[(start_index + offset) % NPC_FILL_KINDS.size()]
		if not row_kinds.has(candidate):
			chosen_kind = candidate
			break
	for metadata_key in [
		"boss_slot_id",
		"boss_sequence_slot_ids",
		"standin",
		"standin_sequence",
		"boss_port_status",
		"boss_encounter_key",
		"boss_encounter_keys",
		"encounter_locked",
	]:
		node.erase(metadata_key)
	node["kind"] = chosen_kind
	node["label"] = str(NPC_FILL_LABELS.get(chosen_kind, "노드"))
	node["boss_pool_slot_ids"] = pool_slot_ids.duplicate()
	node["boss_assignment_state"] = "npc_fill"
	node["boss_assignment_reason"] = reason


func _stable_npc_fill_index(map_seed: int, node_id: String, modulo: int) -> int:
	if modulo <= 0:
		return 0
	var accumulator := (map_seed ^ 0x4E5043) & 0x7FFFFFFF
	for byte_value in node_id.to_utf8_buffer():
		accumulator = ((accumulator * 33) + int(byte_value)) & 0x7FFFFFFF
	return accumulator % modulo


func _slot_ids(slots: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for slot in slots:
		result.append(str(slot.get("slot_id", "")))
	return result


func _shuffle_slots(slots: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	for index in range(slots.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var held := slots[index]
		slots[index] = slots[swap_index]
		slots[swap_index] = held
