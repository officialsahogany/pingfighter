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
const TEMP_OPTIONAL_EXTRA_BOSS_FLOOR_MIN := 2
const TEMP_OPTIONAL_EXTRA_BOSS_SPAWN_CHANCE_PER_FLOOR := 0.45
const TEMP_OPTIONAL_EXTRA_BOSS_MAX_PER_FLOOR := 1
const OPTIONAL_EXTRA_BOSS_SEED_SALT := 0x58425234
const OPTIONAL_EXTRA_BOSS_DISTRIBUTION_KEY := "optional_extra_boss_distribution"

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
		"variant": StageBossVariantCatalog.canonicalize_variant_id(
			route.get("variant", "")
		),
		"fallback_used": status != STATUS_PORTED,
		"source_status": status,
	}


func canonical_encounter_key(route: Dictionary) -> String:
	var stage_id := int(route.get("stage", 0))
	var variant_id := StageBossVariantCatalog.canonicalize_variant_id(
		route.get("variant", "")
	)
	var boss_id := str(route.get("boss_id", "")).strip_edges().to_lower()
	var encounter_id := variant_id if not variant_id.is_empty() else boss_id
	if stage_id <= 0 or encounter_id.is_empty():
		return ""
	return "%d:%s" % [stage_id, encounter_id]


func resolve_boss_icon_id_for_route(route: Dictionary) -> String:
	var variant_id := StageBossVariantCatalog.canonicalize_variant_id(
		route.get("variant", "")
	)
	if variant_id == "gaksi":
		return "gaksital"
	if not variant_id.is_empty():
		return variant_id
	var boss_id := str(route.get("boss_id", "")).strip_edges().to_lower()
	return "gaksital" if boss_id == "gaksi" else boss_id


func resolve_boss_icon_id_for_node(node: Dictionary) -> String:
	var route := _resolve_node_standin(node)
	var boss_id := resolve_boss_icon_id_for_route(route)
	if not boss_id.is_empty():
		return boss_id
	var slot_id := str(node.get("boss_slot_id", "")).strip_edges().to_lower()
	var parts := slot_id.split("_", false)
	if parts.size() >= 3 and parts[0] == "floor" and str(parts[1]).is_valid_int():
		return "_".join(parts.slice(2))
	return ""


func resolve_battle_encounter_for_node(node: Dictionary) -> Dictionary:
	var slot_id := str(node.get("boss_slot_id", "")).strip_edges()
	var slot := get_slot(slot_id)
	var standin := _resolve_node_standin(node)
	var standin_key := canonical_encounter_key(standin)
	var icon_boss_id := resolve_boss_icon_id_for_route(standin)
	if slot.is_empty() or standin_key.is_empty() or icon_boss_id.is_empty():
		return {}
	var stage_id := int(standin.get("stage", 0))
	var boss_id := str(standin.get("boss_id", "")).strip_edges().to_lower()
	var variant_id := StageBossVariantCatalog.canonicalize_variant_id(
		standin.get("variant", "")
	)
	if stage_id <= 0 or boss_id.is_empty():
		return {}
	var slot_encounter := resolve_battle_encounter(slot_id)
	var slot_key := canonical_encounter_key(slot_encounter)
	var assigned_key := str(node.get("boss_encounter_key", "")).strip_edges()
	var display_name := str(slot.get("display_name", boss_id))
	if stage_id in StageBossVariantCatalog.DEFAULT_VARIANT_BY_STAGE:
		var display_entry := StageBossVariantCatalog.get_entry(
			stage_id,
			variant_id if not variant_id.is_empty() else boss_id
		)
		display_name = str(display_entry.get("display_name", display_name))
	return {
		"boss_slot_id": slot_id,
		"display_name": display_name,
		"stage": stage_id,
		"boss_id": boss_id,
		"variant": variant_id,
		"fallback_used": str(slot.get("status", "")) != STATUS_PORTED,
		"source_status": str(slot.get("status", "")),
		"node_id": str(node.get("id", "")),
		"canonical_key": standin_key,
		"icon_boss_id": icon_boss_id,
		"identity_corrected": (
			standin_key != slot_key
			or assigned_key.is_empty()
			or standin_key != assigned_key
		),
		"assigned_key": assigned_key,
		"slot_key": slot_key,
	}


func _resolve_node_standin(node: Dictionary) -> Dictionary:
	if node.has("standin"):
		var standin_variant: Variant = node.get("standin", {})
		return (
			(standin_variant as Dictionary).duplicate(true)
			if standin_variant is Dictionary
			else {}
		)
	return get_standin(str(node.get("boss_slot_id", "")).strip_edges())


func repair_boss_node_identity(node: Dictionary) -> Dictionary:
	var initial_report := analyze_boss_node_identity(node)
	if bool(initial_report.get("valid", false)):
		return {
			"valid": true,
			"changed": false,
			"node": node.duplicate(true),
			"initial_report": initial_report,
		}
	var slot_id := str(node.get("boss_slot_id", "")).strip_edges()
	var live_standin := get_standin(slot_id)
	var live_key := canonical_encounter_key(live_standin)
	if live_standin.is_empty() or live_key.is_empty():
		return {
			"valid": false,
			"changed": false,
			"node": node.duplicate(true),
			"initial_report": initial_report,
		}
	var repaired := node.duplicate(true)
	repaired["standin"] = live_standin
	repaired["boss_encounter_key"] = live_key
	repaired.erase("map_icon_boss_id")
	var repaired_report := analyze_boss_node_identity(repaired)
	return {
		"valid": bool(repaired_report.get("valid", false)),
		"changed": true,
		"node": repaired,
		"initial_report": initial_report,
		"repaired_report": repaired_report,
	}


func reseed_gatekeeper_boss_node_identity(node: Dictionary, map_seed: int) -> Dictionary:
	if not bool(node.get("gatekeeper", false)):
		return {
			"valid": false,
			"changed": false,
			"reason": "not_gatekeeper",
			"node": node.duplicate(true),
		}
	var floor_number := int(node.get("segment_floor", node.get("floor", 0)))
	var slots := get_seeded_floor_slots(floor_number, map_seed)
	for slot in slots:
		var slot_id := str(slot.get("slot_id", ""))
		var encounter_key := canonical_encounter_key(get_standin(slot_id))
		if slot_id.is_empty() or encounter_key.is_empty():
			continue
		var reseeded := node.duplicate(true)
		reseeded.erase("encounter_locked")
		reseeded.erase("map_icon_boss_id")
		reseeded.erase("route_disabled")
		reseeded.erase("skipped")
		_assign_boss_slot(reseeded, slot, slots, encounter_key)
		reseeded["content_state"] = CONTENT_GENERATED
		reseeded["boss_assignment_state"] = "snapshot_gatekeeper_reseeded"
		var report := analyze_boss_node_identity(reseeded)
		return {
			"valid": bool(report.get("valid", false)),
			"changed": true,
			"reason": "same_floor_live_slot",
			"node": reseeded,
			"report": report,
		}
	return {
		"valid": false,
		"changed": false,
		"reason": "same_floor_live_slot_unavailable",
		"node": node.duplicate(true),
	}


func analyze_boss_node_identity(
	node: Dictionary,
	opening_stage1_variant: String = ""
) -> Dictionary:
	var issues: Array[String] = []
	var node_id := str(node.get("id", ""))
	var assigned_key := str(node.get("boss_encounter_key", ""))
	var standin_variant: Variant = node.get("standin", {})
	var standin: Dictionary = standin_variant if standin_variant is Dictionary else {}
	var standin_key := canonical_encounter_key(standin)
	var slot_id := str(node.get("boss_slot_id", ""))
	var slot_key := canonical_encounter_key(get_standin(slot_id))
	if assigned_key.is_empty():
		issues.append("assigned_key_missing")
	if standin_key != assigned_key:
		issues.append(
			"standin_key_mismatch=%s:assigned_%s:standin_%s"
			% [node_id, assigned_key, standin_key]
		)
	if slot_key != assigned_key:
		issues.append(
			"slot_key_mismatch=%s:assigned_%s:slot_%s"
			% [node_id, assigned_key, slot_key]
		)
	var normalized_opening := _normalize_stage1_variant(opening_stage1_variant)
	if (
		not normalized_opening.is_empty()
		and int(node.get("segment_floor", node.get("floor", 0))) == 1
		and bool(node.get("gatekeeper", false))
	):
		var opening_key := canonical_encounter_key({
			"stage": 1,
			"variant": normalized_opening,
		})
		if opening_key != assigned_key:
			issues.append(
				"opening_gate_mismatch=%s:opening_%s:gate_%s"
				% [node_id, opening_key, assigned_key]
			)
	return {
		"valid": issues.is_empty(),
		"node_id": node_id,
		"assigned_key": assigned_key,
		"standin_key": standin_key,
		"slot_key": slot_key,
		"issues": issues,
	}


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
	if int(result.get("floor_one_expansion_row_count", 0)) > 0:
		var floor_one_assignment_count := _assign_floor_one_generated_encounters(
			nodes,
			map_seed,
			used_generated_encounter_keys
		)
		if floor_one_assignment_count < 0:
			return {}
		assigned_generated_boss_count += floor_one_assignment_count
		# The 20% figure is a ceiling, not a reason to add unrelated bosses
		# when first-floor NPC rows enlarge the denominator. Preserve the
		# pre-expansion budget and add only the actual optional encounters.
		generated_boss_budget = mini(
			generated_boss_budget,
			_generated_boss_budget(nodes, active_clear_floor, true)
				+ maxi(0, floor_one_assignment_count - 1)
		)
		if assigned_generated_boss_count > generated_boss_budget:
			return {}
	# 피드백2 8항: 모든 생성 관문은 초크포인트 조우다. 예산·라운드로빈보다
	# 먼저 층 풀에서 배정을 예약하며, 유니크 키가 소진된 층(셸 스탠드인이
	# 층간 중복 키를 공유)은 첫 유효 슬롯을 중복 표식과 함께 배정한다 —
	# 관문은 반드시 그 층 보스가 지켜야 하고, 실제 변형 보스가 포팅되면
	# 중복 표식은 자연 소멸한다.
	for gate_index in range(nodes.size()):
		if gate_index == terminal_node_index or not (nodes[gate_index] is Dictionary):
			continue
		var gate_node := nodes[gate_index] as Dictionary
		var gate_floor := int(
			gate_node.get("segment_floor", gate_node.get("floor", 0))
		)
		if (
			not bool(gate_node.get("gatekeeper", false))
			or gate_floor > active_clear_floor
			or str(gate_node.get("content_state", "")) != CONTENT_GENERATED
			or str(gate_node.get("kind", "")) not in COMBAT_NODE_KINDS
			or str(gate_node.get("boss_assignment_state", "")) == "assigned"
		):
			continue
		var gate_slots := _get_shuffled_generation_slots(gate_floor, map_seed)
		var gate_assigned := false
		for gate_slot in gate_slots:
			var gate_key := canonical_encounter_key(
				get_standin(str(gate_slot.get("slot_id", "")))
			)
			if gate_key.is_empty() or used_generated_encounter_keys.has(gate_key):
				continue
			_assign_boss_slot(gate_node, gate_slot, gate_slots, gate_key)
			used_generated_encounter_keys[gate_key] = true
			assigned_generated_boss_count += 1
			gate_assigned = true
			break
		if not gate_assigned:
			for gate_slot in gate_slots:
				var gate_key := canonical_encounter_key(
					get_standin(str(gate_slot.get("slot_id", "")))
				)
				if gate_key.is_empty():
					continue
				_assign_boss_slot(gate_node, gate_slot, gate_slots, gate_key)
				gate_node["standin_duplicate_gate"] = true
				assigned_generated_boss_count += 1
				gate_assigned = true
				break
		if not gate_assigned:
			return {}
	var optional_extra_report := _assign_optional_extra_bosses(
		result,
		phase,
		nodes,
		active_clear_floor,
		map_seed,
		used_generated_encounter_keys
	)
	if not bool(optional_extra_report.get("valid", false)):
		return {}
	assigned_generated_boss_count += int(optional_extra_report.get("spawned_count", 0))
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
		if str(candidate_node.get("boss_assignment_state", "")) == "assigned":
			continue
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
	var optional_extra_bypass := analyze_optional_extra_boss_bypass(
		result,
		active_clear_floor
	)
	if not bool(optional_extra_bypass.get("valid", false)):
		return {}
	var contract := analyze_visible_boss_contract(result, active_clear_floor)
	if not bool(contract.get("valid", false)):
		return {}
	return result


func analyze_optional_extra_boss_bypass(
	graph: Dictionary,
	active_clear_floor: int = -1
) -> Dictionary:
	var resolved_clear_floor := (
		active_clear_floor
		if active_clear_floor > 0
		else _resolve_active_clear_floor(graph)
	)
	var issues: Array[String] = []
	var optional_node_count := 0
	for phase_variant in graph.get("phases", []):
		if not (phase_variant is Dictionary):
			continue
		var phase := phase_variant as Dictionary
		for node_variant in phase.get("nodes", []):
			if not (node_variant is Dictionary):
				continue
			var node := node_variant as Dictionary
			if not bool(node.get("optional_extra_boss", false)):
				continue
			optional_node_count += 1
			var node_id := str(node.get("id", ""))
			if not _has_entry_to_terminal_path_avoiding_node(
				phase,
				node_id,
				resolved_clear_floor
			):
				issues.append("forced_optional_extra_boss=%s" % node_id)
	return {
		"valid": issues.is_empty(),
		"issues": issues,
		"optional_node_count": optional_node_count,
	}


func _assign_optional_extra_bosses(
	result: Dictionary,
	phase: Dictionary,
	nodes: Array,
	active_clear_floor: int,
	map_seed: int,
	used_generated_encounter_keys: Dictionary
) -> Dictionary:
	var maximum_floor := active_clear_floor - 1
	var floor_reports: Dictionary = {}
	var roll_hit_count := 0
	var spawned_count := 0
	var unique_pool_exhausted_skip_count := 0
	var no_bypass_candidate_skip_count := 0
	var row_width_by_node_id := _row_width_by_node_id(phase)
	for floor_number in range(
		TEMP_OPTIONAL_EXTRA_BOSS_FLOOR_MIN,
		maximum_floor + 1
	):
		var rng := RandomNumberGenerator.new()
		rng.seed = _optional_extra_boss_floor_seed(map_seed, floor_number)
		var spawn_roll := rng.randf()
		var floor_report := {
			"roll": spawn_roll,
			"roll_hit": spawn_roll < TEMP_OPTIONAL_EXTRA_BOSS_SPAWN_CHANCE_PER_FLOOR,
			"spawned_count": 0,
			"skip_reason": "chance_miss",
			"node_id": "",
			"boss_slot_id": "",
		}
		if not bool(floor_report.get("roll_hit", false)):
			floor_reports[floor_number] = floor_report
			continue
		roll_hit_count += 1
		var available_slots: Array[Dictionary] = []
		for slot in _get_shuffled_generation_slots(floor_number, map_seed):
			var slot_id := str(slot.get("slot_id", ""))
			var encounter_key := canonical_encounter_key(get_standin(slot_id))
			if encounter_key.is_empty() or used_generated_encounter_keys.has(encounter_key):
				continue
			available_slots.append({
				"slot": slot,
				"encounter_key": encounter_key,
			})
		if available_slots.is_empty():
			floor_report["skip_reason"] = "unique_pool_exhausted"
			unique_pool_exhausted_skip_count += 1
			floor_reports[floor_number] = floor_report
			continue
		var candidate_indexes := _optional_extra_boss_candidate_indexes(
			nodes,
			floor_number,
			row_width_by_node_id
		)
		var selected_index := -1
		if not candidate_indexes.is_empty():
			var start_index := rng.randi_range(0, candidate_indexes.size() - 1)
			for candidate_offset in range(candidate_indexes.size()):
				var candidate_index := int(candidate_indexes[
					(start_index + candidate_offset) % candidate_indexes.size()
				])
				var candidate_node := nodes[candidate_index] as Dictionary
				if _has_entry_to_terminal_path_avoiding_node(
					phase,
					str(candidate_node.get("id", "")),
					active_clear_floor
				):
					selected_index = candidate_index
					break
		if selected_index < 0:
			floor_report["skip_reason"] = "no_bypass_candidate"
			no_bypass_candidate_skip_count += 1
			floor_reports[floor_number] = floor_report
			continue
		var selected_node := nodes[selected_index] as Dictionary
		var selected_slot_report := available_slots[0]
		var selected_slot := selected_slot_report.get("slot", {}) as Dictionary
		var selected_key := str(selected_slot_report.get("encounter_key", ""))
		selected_node["optional_extra_boss"] = true
		selected_node["optional_extra_boss_source_kind"] = str(
			selected_node.get("kind", "")
		)
		selected_node["optional_extra_boss_source_label"] = str(
			selected_node.get("label", "")
		)
		selected_node["kind"] = "boss"
		_assign_boss_slot(
			selected_node,
			selected_slot,
			_get_shuffled_generation_slots(floor_number, map_seed),
			selected_key
		)
		used_generated_encounter_keys[selected_key] = true
		spawned_count += 1
		floor_report["spawned_count"] = TEMP_OPTIONAL_EXTRA_BOSS_MAX_PER_FLOOR
		floor_report["skip_reason"] = ""
		floor_report["node_id"] = str(selected_node.get("id", ""))
		floor_report["boss_slot_id"] = str(selected_node.get("boss_slot_id", ""))
		floor_reports[floor_number] = floor_report
	var report := {
		"floor_min": TEMP_OPTIONAL_EXTRA_BOSS_FLOOR_MIN,
		"floor_max": maximum_floor,
		"spawn_chance_per_floor": TEMP_OPTIONAL_EXTRA_BOSS_SPAWN_CHANCE_PER_FLOOR,
		"max_per_floor": TEMP_OPTIONAL_EXTRA_BOSS_MAX_PER_FLOOR,
		"roll_hit_count": roll_hit_count,
		"spawned_count": spawned_count,
		"unique_pool_exhausted_skip_count": unique_pool_exhausted_skip_count,
		"no_bypass_candidate_skip_count": no_bypass_candidate_skip_count,
		"floor_reports": floor_reports,
	}
	result[OPTIONAL_EXTRA_BOSS_DISTRIBUTION_KEY] = report
	return {
		"valid": true,
		"spawned_count": spawned_count,
	}


func _row_width_by_node_id(phase: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for floor_variant in phase.get("floors", []):
		if not (floor_variant is Dictionary):
			continue
		for row_variant in (floor_variant as Dictionary).get("rows", []):
			if not (row_variant is Dictionary):
				continue
			var node_ids: Array = (row_variant as Dictionary).get("node_ids", [])
			for node_id_variant in node_ids:
				result[str(node_id_variant)] = node_ids.size()
	return result


func _optional_extra_boss_candidate_indexes(
	nodes: Array,
	floor_number: int,
	row_width_by_node_id: Dictionary
) -> Array[int]:
	var result: Array[int] = []
	for node_index in range(nodes.size()):
		if not (nodes[node_index] is Dictionary):
			continue
		var node := nodes[node_index] as Dictionary
		var node_id := str(node.get("id", ""))
		if (
			int(node.get("segment_floor", node.get("floor", 0))) != floor_number
			or int(row_width_by_node_id.get(node_id, 0)) < 2
			or str(node.get("content_state", "")) != CONTENT_GENERATED
			or str(node.get("kind", "")) not in NPC_FILL_KINDS
			or bool(node.get("gatekeeper", false))
			or bool(node.get("floor_one_boss_choice", false))
			or bool(node.get("standin_duplicate_gate", false))
			or str(node.get("boss_assignment_state", "")) == "assigned"
		):
			continue
		result.append(node_index)
	return result


func _has_entry_to_terminal_path_avoiding_node(
	phase: Dictionary,
	blocked_node_id: String,
	active_clear_floor: int
) -> bool:
	var entry_id := str(phase.get("entry_node_id", ""))
	var terminal_id := ""
	for node_variant in phase.get("nodes", []):
		if not (node_variant is Dictionary):
			continue
		var node := node_variant as Dictionary
		if (
			int(node.get("segment_floor", node.get("floor", 0))) == active_clear_floor
			and str(node.get("content_state", "")) == CONTENT_GENERATED
			and bool(node.get("gatekeeper", false))
			and bool(node.get("floor_boundary", false))
		):
			terminal_id = str(node.get("id", ""))
			break
	if (
		entry_id.is_empty()
		or terminal_id.is_empty()
		or blocked_node_id == entry_id
		or blocked_node_id == terminal_id
	):
		return false
	var adjacency: Dictionary = {}
	for edge_variant in phase.get("edges", []):
		if not (edge_variant is Dictionary):
			continue
		var edge := edge_variant as Dictionary
		var from_id := str(edge.get("from", ""))
		var to_id := str(edge.get("to", ""))
		if from_id == blocked_node_id or to_id == blocked_node_id:
			continue
		var targets: Array = adjacency.get(from_id, [])
		targets.append(to_id)
		adjacency[from_id] = targets
	var visited: Dictionary = {entry_id: true}
	var pending: Array[String] = [entry_id]
	while not pending.is_empty():
		var current_id: String = pending.pop_back()
		for target_variant in adjacency.get(current_id, []):
			var target_id := str(target_variant)
			if visited.has(target_id):
				continue
			visited[target_id] = true
			pending.append(target_id)
	return visited.has(terminal_id)


func _optional_extra_boss_floor_seed(map_seed: int, floor_number: int) -> int:
	return int(
		(map_seed ^ OPTIONAL_EXTRA_BOSS_SEED_SALT ^ (floor_number * 0x45D9F3B))
		& 0x7fffffff
	)


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
				issues,
				bool(node.get("standin_duplicate_gate", false))
			)
			visible_encounter_count += 1
	return {
		"valid": issues.is_empty(),
		"issues": issues,
		"active_clear_floor": resolved_clear_floor,
		"visible_encounter_count": visible_encounter_count,
		"unique_encounter_count": used_encounter_keys.size(),
	}


func _generated_boss_budget(
	nodes: Array,
	active_clear_floor: int,
	exclude_floor_one_added_nodes: bool = false
) -> int:
	var generated_node_count := 0
	for node_variant in nodes:
		if not (node_variant is Dictionary):
			continue
		var node := node_variant as Dictionary
		if (
			str(node.get("content_state", "")) == CONTENT_GENERATED
			and int(node.get("segment_floor", node.get("floor", 0))) <= active_clear_floor
			and (
				not exclude_floor_one_added_nodes
				or not bool(node.get("floor_one_expansion_added_node", false))
			)
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
			or str(node.get("boss_assignment_state", "")) == "assigned"
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


func _assign_floor_one_generated_encounters(
	nodes: Array,
	map_seed: int,
	used_generated_encounter_keys: Dictionary
) -> int:
	var start_gate_index := -1
	var encounter_indexes: Array[int] = []
	for node_index in range(nodes.size()):
		if not (nodes[node_index] is Dictionary):
			continue
		var node := nodes[node_index] as Dictionary
		if (
			int(node.get("segment_floor", node.get("floor", 0))) != 1
			or str(node.get("content_state", "")) != CONTENT_GENERATED
			or str(node.get("kind", "")) not in COMBAT_NODE_KINDS
		):
			continue
		if bool(node.get("gatekeeper", false)):
			start_gate_index = node_index
		elif bool(node.get("floor_one_boss_choice", false)):
			encounter_indexes.append(node_index)
	if start_gate_index < 0 or encounter_indexes.is_empty():
		return -1
	var ordered_indexes: Array[int] = [start_gate_index]
	ordered_indexes.append_array(encounter_indexes)
	var slots := _get_shuffled_generation_slots(1, map_seed)
	if slots.size() < ordered_indexes.size():
		return -1
	var assigned_count := 0
	for node_index in ordered_indexes:
		var assigned := false
		for slot in slots:
			var slot_id := str(slot.get("slot_id", ""))
			var encounter_key := canonical_encounter_key(get_standin(slot_id))
			if (
				encounter_key.is_empty()
				or used_generated_encounter_keys.has(encounter_key)
			):
				continue
			_assign_boss_slot(
				nodes[node_index] as Dictionary,
				slot,
				slots,
				encounter_key
			)
			used_generated_encounter_keys[encounter_key] = true
			assigned_count += 1
			assigned = true
			break
		if not assigned:
			return -1
	return assigned_count


func _register_visible_encounter(
	slot_id: String,
	segment_floor: int,
	node_id: String,
	used_encounter_keys: Dictionary,
	issues: Array[String],
	allow_standin_duplicate: bool = false
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
	# 피드백2 8항: 초크포인트 관문은 층 풀의 유니크 키가 소진되어도 그 층
	# 보스가 지켜야 하므로, 명시적 스탠드인 중복 표식이 있는 관문은 런 전체
	# 유니크 계약에서 대체 조우로 취급된다 — 키를 소비하지도, 등록 순서와
	# 무관하게 충돌을 일으키지도 않는다(실 변형 보스가 포팅되면 소멸).
	if allow_standin_duplicate:
		return
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


func _normalize_stage1_variant(value: String) -> String:
	if not StageBossVariantCatalog.is_ported_variant(1, value):
		return ""
	return StageBossVariantCatalog.normalize_variant(1, value)


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
