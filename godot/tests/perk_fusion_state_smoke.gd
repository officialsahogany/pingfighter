extends SceneTree

const PerkFusionCatalog := preload("res://scripts/characters/perk_fusion_catalog.gd")
const PerkFusionState := preload("res://scripts/characters/perk_fusion_state.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")

var _failures: Array[String] = []
var _catalog := RuntimePerkCatalog.new()
var _fusion_catalog := PerkFusionCatalog.new()


func _init() -> void:
	_test_classification_and_candidates()
	_test_record_creation_and_deep_copy()
	_test_next_fusion_tokens_are_atomic_and_persistent()
	_test_restore_self_heal_revision_and_reset()
	_test_canonical_api_and_schema_surface()

	if _failures.is_empty():
		print("perk_fusion_state_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_classification_and_candidates() -> void:
	_expect_class("sage_ring", PerkFusionCatalog.CLASS_MYTHIC_SYSTEM)
	_expect_class("core_flip", PerkFusionCatalog.CLASS_UNLOCK)
	_expect_class("dark_blade", PerkFusionCatalog.CLASS_UNLOCK)
	_expect_class("common_refresh", PerkFusionCatalog.CLASS_INSTANT)
	_expect_class("dash_amplification", PerkFusionCatalog.CLASS_SYSTEM_CHOICE)

	var kick: Dictionary = _fusion_catalog.classify_perk("kick_enhance", _catalog, 3)
	_expect(
		str(kick.get("fusion_class", "")) == PerkFusionCatalog.CLASS_NUMERIC_PASSIVE,
		"kick_enhance should remain a numeric fusion candidate"
	)
	_expect(
		not bool(kick.get("penalty_hookable", true)),
		"character-tree numeric perks must be penalty_hookable=false"
	)
	_expect(
		not bool(_fusion_catalog.classify_perk("sage_ring", _catalog, 3).get("penalty_hookable", true)),
		"mythic_system perks must be side-effect exempt"
	)
	_expect(
		bool(_fusion_catalog.classify_perk("item_luck", _catalog, 3).get("limit_break_eligible", false)),
		"linear central-helper perk should be explicitly limit-break eligible"
	)
	for overflow_perk_id in [
		"perk_laurel_shield", "dowsing_goggles", "battery", "lucky_coin",
		"foul_whistle", "rainbow_fur_glove", "soul_burst", "bulletproof_hat",
	]:
		var overflow_data: Dictionary = _catalog.get_perk_data(overflow_perk_id)
		_expect(
			bool(_fusion_catalog.classify_perk(
				overflow_perk_id,
				_catalog,
				int(overflow_data.get("max_level", 0))
			).get("limit_break_eligible", false)),
			"%s should opt into its production Lv.6+ scaling path" % overflow_perk_id
		)
	_expect(
		not bool(_fusion_catalog.classify_perk("sage_ring", _catalog, 3).get("limit_break_eligible", true)),
		"effective-level-exempt perk should not be limit-break eligible"
	)

	_expect(_fusion_catalog.is_candidate("kick_enhance", 3, _catalog), "S3-maxed kick_enhance should be a candidate")
	_expect(not _fusion_catalog.is_candidate("kick_enhance", 2, _catalog), "non-maxed S3 base level must be rejected")
	_expect(_fusion_catalog.is_candidate("sage_ring", 3, _catalog), "S3-maxed Hyeonmun Charyeok should remain a candidate")
	_expect(not _fusion_catalog.is_candidate("sage_ring", 2, _catalog), "effective bonus must not replace the S3 base max-level gate")
	_expect(not _fusion_catalog.is_candidate("core_flip", 1, _catalog), "unlock perks must not be candidates")
	_expect(not _fusion_catalog.is_candidate("dash_amplification", 3, _catalog), "multi-slot dash amplification must not be a candidate")

	var all_data: Dictionary = _catalog.get_all_perk_data()
	for perk_id_value: Variant in all_data.keys():
		var perk_id: String = str(perk_id_value)
		var classification: Dictionary = _fusion_catalog.classify_perk(perk_id, _catalog)
		_expect(not classification.is_empty(), "catalog entry %s should have a fusion classification" % perk_id)
		_expect(
			str(classification.get("fusion_class", "")) in PerkFusionCatalog.FUSION_CLASSES,
			"catalog entry %s should use one of the six fusion classes" % perk_id
		)
		_expect(
			typeof(classification.get("penalty_hookable", null)) == TYPE_BOOL,
			"catalog entry %s should have a boolean penalty_hookable decision" % perk_id
		)


func _test_record_creation_and_deep_copy() -> void:
	var state := PerkFusionState.new()
	var levels := {
		"kick_enhance": 3,
		"item_luck": 3,
		"common_swiftness": 5,
	}
	var candidates: Array[String] = state.get_candidates(_catalog, levels)
	_expect("item_luck" in candidates and "kick_enhance" in candidates, "state candidate API should expose maxed sources")
	var created: Dictionary = state.commit_fusion(
		["kick_enhance", "item_luck"],
		{
			"outcome": "side_effect",
			"option_penalties": {
				"item_luck": {
					"spawn_delay": {
						"original_value": 1.0,
						"adjusted_value": 0.8,
						"multiplier": 0.8,
						"value_kind": "float",
						"polarity": "forward",
						"nominal_pct": 20.0,
					},
				},
			},
		},
		_catalog,
		levels
	)
	_expect(not created.is_empty(), "two maxed, unit-slot sources should create a fusion record")
	_expect(str(created.get("fusion_id", "")) == "fusion_0", "first record should use fusion_0")
	_expect(
		created.get("sources", []) == ["item_luck", "kick_enhance"],
		"record sources should be sorted and fixed to exactly two ids"
	)
	_expect(int(created.get("slot_reduction", 0)) == 1, "each record should publish one refunded slot")
	_expect(state.get_slot_reduction() == 1, "slot reduction should equal the valid fusion record count")
	_expect(state.get_revision() == 1, "successful creation should advance revision once")
	_expect(state.is_source_fused("item_luck"), "fused-source lookup should contain the first source")
	_expect(state.is_source_fused("kick_enhance"), "fused-source lookup should contain the second source")
	_expect(
		str(state.get_fused_source_lookup().get("kick_enhance", "")) == "fusion_0",
		"fused-source lookup should resolve to the owning fusion id"
	)
	_expect(
		str(state.get_record_for_source("kick_enhance").get("fusion_id", "")) == "fusion_0",
		"fused-record lookup should return a deep-copied owning record"
	)
	_expect(
		not _fusion_catalog.is_candidate("kick_enhance", 3, _catalog, state),
		"already-fused sources must not remain candidates"
	)

	var revision_before_reject: int = state.get_revision()
	_expect(
		state.create_record(["item_luck", "kick_enhance"], levels, _catalog).is_empty(),
		"duplicate pairs should be rejected"
	)
	_expect(
		state.create_record(["kick_enhance", "common_swiftness"], levels, _catalog).is_empty(),
		"a source already used by another record should be rejected"
	)
	_expect(state.get_revision() == revision_before_reject, "rejected records must not change revision")

	created["sources"][0] = "mutated_return"
	(created["option_penalties"] as Dictionary)["item_luck"] = {"spawn_delay": {"multiplier": 0.1}}
	var snapshot: Dictionary = state.get_snapshot()
	(snapshot["records"] as Array)[0]["sources"][0] = "mutated_snapshot"
	((snapshot["records"] as Array)[0]["option_penalties"] as Dictionary)["item_luck"] = {"spawn_delay": {"multiplier": 0.2}}
	var stored: Dictionary = state.get_all_records()[0]
	_expect(
		stored.get("sources", []) == ["item_luck", "kick_enhance"],
		"returned records and snapshots must not alias state-owned sources"
	)
	_expect_close(
		float(((((stored.get("option_penalties", {}) as Dictionary).get("item_luck", {}) as Dictionary).get("spawn_delay", {}) as Dictionary).get("multiplier", 0.0))),
		0.8,
		"snapshot must deep-copy nested record dictionaries"
	)


func _test_restore_self_heal_revision_and_reset() -> void:
	var state := PerkFusionState.new()
	var levels := {
		"item_luck": 3,
		"kick_enhance": 3,
		"common_bulk_up": 5,
		"common_swiftness": 4,
	}
	var snapshot := {
		"records": [
			{
				"fusion_id": "fusion_4",
				"sources": ["kick_enhance", "item_luck"],
				"outcome": "byproduct",
				"byproducts": ["sleeve_cosmos", "reverb"],
				"byproduct_payloads": {"sleeve_cosmos": {}},
			},
			{"fusion_id": "fusion_5", "sources": ["item_luck", "kick_enhance"], "outcome": "success"},
			{"fusion_id": "fusion_6", "sources": ["kick_enhance", "common_bulk_up"], "outcome": "success"},
			{"fusion_id": "fusion_7", "sources": ["not_a_real_perk", "common_bulk_up"], "outcome": "success"},
			{"fusion_id": "fusion_8", "sources": ["dash_lightweight", "common_bulk_up"], "outcome": "success"},
			{"fusion_id": "fusion_9", "sources": ["common_swiftness", "common_bulk_up"], "outcome": "success"},
		],
		"next_fusion_index": 10,
		"fusion_revision": 11,
	}
	var result: Dictionary = state.restore_snapshot(snapshot, _catalog, levels)
	_expect(int(result.get("kept", 0)) == 1, "restore should keep only the first valid record")
	_expect(int(result.get("dropped", 0)) == 5, "restore should self-heal all five invalid records")
	var reasons: Dictionary = result.get("dropped_by_reason", {}) as Dictionary
	_expect(int(reasons.get("duplicate_pair", 0)) == 1, "restore should identify duplicate pairs")
	_expect(int(reasons.get("source_reused", 0)) == 1, "restore should identify source reuse")
	_expect(int(reasons.get("missing_source", 0)) == 1, "restore should identify missing catalog ids")
	_expect(int(reasons.get("source_not_owned", 0)) == 1, "restore should identify non-owned sources")
	_expect(int(reasons.get("source_not_maxed", 0)) == 1, "restore should identify non-maxed sources")
	_expect(state.get_all_records().size() == 1, "invalid restored records must be physically removed")
	var healed_record: Dictionary = state.get_all_records()[0]
	_expect(healed_record.get("byproducts", []) == ["reverb"], "restore must prune retired byproducts while keeping live ones")
	_expect(not (healed_record.get("byproduct_payloads", {}) as Dictionary).has("sleeve_cosmos"), "restore must drop retired byproduct payloads")
	_expect("sleeve_cosmos" not in state.get_owned_byproduct_ids(), "pruned retired byproducts must not surface as owned")
	_expect(state.get_slot_reduction_count() == 1, "slot reduction must count only healed, valid records")
	_expect(state.get_revision() == 12, "restore should advance beyond the serialized revision")
	_expect(state.get_next_fusion_index() == 10, "restore should preserve the monotonic next fusion index")

	levels["common_swiftness"] = 5
	var next_record: Dictionary = state.commit_fusion(
		["common_swiftness", "common_bulk_up"],
		{},
		_catalog,
		levels
	)
	_expect(str(next_record.get("fusion_id", "")) == "fusion_10", "post-restore creation should not reuse ids")
	_expect(state.get_slot_reduction_count() == 2, "two valid records should refund two slots")

	var revision_before_reset: int = state.get_revision()
	state.reset()
	_expect(state.get_all_records().is_empty(), "reset should clear all fusion records")
	_expect(state.get_fused_source_lookup().is_empty(), "reset should clear the fused-source lookup")
	_expect(state.get_slot_reduction_count() == 0, "reset should clear slot reduction")
	_expect(state.get_next_fusion_index() == 0, "reset should restart the run-local fusion index")
	_expect(state.get_revision() == revision_before_reset + 1, "reset should invalidate revision-dependent caches")


func _test_next_fusion_tokens_are_atomic_and_persistent() -> void:
	var state := PerkFusionState.new()
	var levels := {
		"item_luck": 3,
		"common_bulk_up": 5,
		"common_swiftness": 5,
		"common_training": 5,
	}
	var first: Dictionary = state.commit_fusion(
		["item_luck", "common_bulk_up"],
		{"outcome": "byproduct", "byproducts": ["core_stabilize", "dual_catalyst"]},
		_catalog,
		levels
	)
	_expect(not first.is_empty(), "token byproducts should commit with the fusion record")
	_expect(state.is_core_stabilize_armed() and state.is_dual_catalyst_armed(), "new tokens should arm only after the owning record commits")
	_expect(state.get_revision() == 1, "record plus token arm should advance revision exactly once")

	var second: Dictionary = state.commit_fusion(
		["common_swiftness", "common_training"],
		{
			"outcome": "success",
			"token_consumption": {"core_stabilize": true, "dual_catalyst": true},
		},
		_catalog,
		levels
	)
	_expect(not second.is_empty(), "a second valid fusion should consume armed tokens atomically")
	_expect(not state.is_core_stabilize_armed() and not state.is_dual_catalyst_armed(), "consumed one-shot tokens should disarm")
	_expect(state.get_revision() == 2, "record plus token consumption should advance revision exactly once")
	_expect(state.get_owned_byproduct_ids() == ["core_stabilize", "dual_catalyst"], "consumption must not erase byproduct acquisition history")

	var snapshot: Dictionary = state.get_snapshot()
	_expect(int(snapshot.get("fusion_revision", -1)) == state.get_revision(), "snapshot should expose the canonical fusion revision")
	_expect(not snapshot.has("revision"), "snapshot should not duplicate the canonical fusion_revision under a generic revision key")
	var restored := PerkFusionState.new()
	restored.restore_snapshot(snapshot, _catalog, levels)
	_expect(not restored.is_core_stabilize_armed() and not restored.is_dual_catalyst_armed(), "snapshot restore should preserve consumed token state")


func _test_canonical_api_and_schema_surface() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/characters/perk_fusion_state.gd")
	for dead_api in ["get_records", "to_save_data", "restore", "get_fused_record_for_source"]:
		_expect(source.find("func %s(" % dead_api) < 0, "dead fusion state API %s should not remain public" % dead_api)
	_expect(source.find("snapshot.get(\"fusion_records\"") < 0, "restore should accept only the canonical records key")
	_expect(source.find("snapshot.get(\"revision\"") < 0, "restore should accept only canonical fusion_revision")
	_expect(source.find("typeof(entry) == TYPE_INT") < 0, "raw numeric option penalties should not remain a multiplier compatibility shape")

	var levels := {"item_luck": 3, "kick_enhance": 3}
	var legacy_key_state := PerkFusionState.new()
	var legacy_restore := legacy_key_state.restore_snapshot(
		{
			"fusion_revision": 4,
			"fusion_records": [{
				"fusion_id": "fusion_0",
				"sources": ["item_luck", "kick_enhance"],
			}],
		},
		_catalog,
		levels
	)
	_expect(int(legacy_restore.get("kept", -1)) == 0 and legacy_key_state.get_all_records().is_empty(), "legacy fusion_records should not restore into the canonical schema")


func _expect_class(perk_id: String, expected_class: String) -> void:
	var classification: Dictionary = _fusion_catalog.classify_perk(perk_id, _catalog)
	_expect(
		str(classification.get("fusion_class", "")) == expected_class,
		"%s should classify as %s, got %s" % [
			perk_id,
			expected_class,
			str(classification.get("fusion_class", "<missing>")),
		]
	)


func _expect_close(actual: float, expected: float, message: String) -> void:
	if not is_equal_approx(actual, expected):
		_failures.append("%s (expected %.3f, got %.3f)" % [message, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
