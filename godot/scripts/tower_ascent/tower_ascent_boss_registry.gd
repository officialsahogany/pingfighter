extends RefCounted

const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)

const STATUS_PORTED := "ported"
const STATUS_UNPORTED := "unported"
const STATUS_SHELL := "shell"
const STATUS_NEW_DESIGN := "new_design"

const FLOOR_BOSS_SLOTS := {
	1: [
		{"slot_id": "floor_01_dalji", "display_name": "달지", "status": STATUS_PORTED, "stage": 1, "boss_id": "dalji", "variant": "dalji"},
		{"slot_id": "floor_01_gaksital", "display_name": "각시탈", "status": STATUS_PORTED, "stage": 1, "boss_id": "gaksital", "variant": "gaksi"},
		{"slot_id": "floor_01_podo", "display_name": "포도대장", "status": STATUS_PORTED, "stage": 1, "boss_id": "podo", "variant": "podo"},
	],
	2: [
		{"slot_id": "floor_02_cheongringwi", "display_name": "청린귀", "status": STATUS_PORTED, "stage": 2, "boss_id": "cheongringwi"},
		{"slot_id": "floor_02_molewang", "display_name": "두더지왕", "status": STATUS_PORTED, "stage": 2, "boss_id": "cheongringwi", "variant": "molewang"},
		{"slot_id": "floor_02_arachne", "display_name": "아라크네", "status": STATUS_PORTED, "stage": 2, "boss_id": "cheongringwi", "variant": "arachne"},
	],
	3: [
		{"slot_id": "floor_03_yeonmyo", "display_name": "환묘 연묘", "status": STATUS_PORTED, "stage": 3, "boss_id": "yeonmyo"},
		{"slot_id": "floor_03_teddy_bear", "display_name": "테디베어", "status": STATUS_PORTED, "stage": 3, "boss_id": "yeonmyo", "variant": "teddy_bear"},
		{"slot_id": "floor_03_alice", "display_name": "엘리스", "status": STATUS_PORTED, "stage": 3, "boss_id": "yeonmyo", "variant": "alice"},
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
			result.append((slot_variant as Dictionary).duplicate(true))
	return result


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


func decorate_graph(graph: Dictionary, map_seed: int) -> Dictionary:
	var result := graph.duplicate(true)
	var phases_variant: Variant = result.get("phases", [])
	if not (phases_variant is Array) or (phases_variant as Array).is_empty():
		return {}
	var phase: Dictionary = (phases_variant as Array)[0]
	var nodes: Array = phase.get("nodes", [])
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed ^ 0x4D4150
	for floor_number in range(1, 13):
		var boss_node_indexes: Array[int] = []
		for node_index in range(nodes.size()):
			var node_variant: Variant = nodes[node_index]
			if not (node_variant is Dictionary):
				continue
			var node := node_variant as Dictionary
			if int(node.get("floor", 0)) == floor_number and str(node.get("kind", "")) in ["boss", "combat", "enraged"]:
				boss_node_indexes.append(node_index)
		var slots := get_floor_slots(floor_number)
		if boss_node_indexes.is_empty() or slots.is_empty():
			continue
		_shuffle_slots(slots, rng)
		if floor_number == 11:
			var group_slot_ids: Array[String] = []
			var group_standins: Array[Dictionary] = []
			for slot in slots:
				var slot_id := str(slot.get("slot_id", ""))
				group_slot_ids.append(slot_id)
				group_standins.append(get_standin(slot_id))
			var group_node: Dictionary = nodes[boss_node_indexes[0]]
			group_node["boss_slot_id"] = "floor_11_four_kings_group"
			group_node["boss_sequence_slot_ids"] = group_slot_ids
			group_node["standin_sequence"] = group_standins
			group_node["label"] = "4천왕"
			group_node["encounter_locked"] = true
			continue
		for assignment_index in range(boss_node_indexes.size()):
			var slot: Dictionary = slots[assignment_index % slots.size()]
			var slot_id := str(slot.get("slot_id", ""))
			var node: Dictionary = nodes[boss_node_indexes[assignment_index]]
			node["boss_slot_id"] = slot_id
			node["boss_pool_slot_ids"] = _slot_ids(slots)
			node["boss_port_status"] = str(slot.get("status", ""))
			node["standin"] = get_standin(slot_id)
			node["label"] = str(slot.get("display_name", node.get("label", "보스")))
			if str(slot.get("status", "")) != STATUS_PORTED:
				node["encounter_locked"] = true
	phase["nodes"] = nodes
	result["phases"] = [phase]
	return result


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
