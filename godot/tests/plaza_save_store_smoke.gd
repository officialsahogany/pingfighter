extends SceneTree

const PlazaSaveStore := preload("res://scripts/plaza/plaza_save_store.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run()


func _run() -> void:
	_verify_roundtrip_and_bom_rewrite()
	_verify_chance_gems_roundtrip_consume_and_v5_migration()
	_verify_stage_clear_progress_is_exact_gold_units()
	_verify_stage_ap_records_once()
	_verify_stage_map_seed_roundtrip()
	_verify_bank_transactions_and_ap_consumption()
	_verify_bank_interest_once_per_stage()
	_verify_shop_wallet_transactions_and_ap_consumption()
	_verify_gacha_payment_and_ap_consumption()
	_verify_lingpet_egg_payment_and_ap_consumption()
	_verify_blacksmith_payment_and_ap_consumption()
	_verify_academy_payment_and_ap_consumption()
	_verify_tavern_quest_state_and_ap_consumption()
	_verify_corrupt_primary_recovers_last_good()

	if _failures.is_empty():
		print("plaza_save_store_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_roundtrip_and_bom_rewrite() -> void:
	var path := _test_path("roundtrip")
	_cleanup(path)
	var store := PlazaSaveStore.new()
	store.set_save_path(path)
	var apply_summary: Dictionary = store.apply_stage_clear_progress(1, 123, true)
	_expect(int(apply_summary.get("transferred_gold", 0)) == 123, "stage clear should transfer exact runtime gold")
	_expect(int(apply_summary.get("granted_ap", 0)) == 1, "stage clear should grant one AP")

	var loaded := PlazaSaveStore.new()
	loaded.set_save_path(path)
	var loaded_summary: Dictionary = loaded.get_summary()
	_expect(int(loaded_summary.get("plaza_gold", 0)) == 123, "save/load should preserve plaza gold")
	_expect(int(loaded_summary.get("ap_current", 0)) == PlazaSaveStore.BASE_AP + 1, "save/load should preserve AP")
	_expect(not bool(loaded_summary.get("ap_is_first_stage", true)), "first-stage AP flag should clear after the first clear")

	var original_text := FileAccess.get_file_as_string(path)
	_write_text_with_bom(path, original_text)
	var bom_loaded := PlazaSaveStore.new()
	bom_loaded.set_save_path(path)
	_expect(bom_loaded.load(), "BOM-prefixed plaza save should parse")
	var bom_summary: Dictionary = bom_loaded.get_summary()
	_expect(str(bom_summary.get("load", "")) == "ok", "BOM load should keep the normal ok summary")
	_expect(int(bom_summary.get("plaza_gold", 0)) == 123, "BOM load should preserve plaza gold")
	_expect(not _file_starts_with_bom(path), "BOM load should rewrite the primary save without BOM")
	_cleanup(path)


func _verify_chance_gems_roundtrip_consume_and_v5_migration() -> void:
	var path := _test_path("chance_gems")
	_cleanup(path)
	var store := PlazaSaveStore.new()
	store.set_save_path(path)
	_expect(store.get_schema_version() == PlazaSaveStore.SAVE_SCHEMA_VERSION, "plaza save should expose the current schema")
	_expect(store.get_max_chance_gems() == PlazaSaveStore.MAX_CHANCE_GEMS, "chance gem max should be the shared store constant")
	_expect(store.get_chance_gems() == PlazaSaveStore.MAX_CHANCE_GEMS, "new saves should start with full chance gems")
	_expect(store.consume_chance_gem() == PlazaSaveStore.MAX_CHANCE_GEMS - 1, "first chance gem consume should decrement by one")
	_expect(store.consume_chance_gem() == PlazaSaveStore.MAX_CHANCE_GEMS - 2, "second chance gem consume should persist another decrement")

	var reloaded := PlazaSaveStore.new()
	reloaded.set_save_path(path)
	_expect(reloaded.get_chance_gems() == PlazaSaveStore.MAX_CHANCE_GEMS - 2, "chance gems should survive save/load roundtrip")
	_expect(int(reloaded.get_summary().get("chance_gems", -1)) == PlazaSaveStore.MAX_CHANCE_GEMS - 2, "summary should expose current chance gems")
	_expect(int(reloaded.get_summary().get("chance_gems_max", -1)) == PlazaSaveStore.MAX_CHANCE_GEMS, "summary should expose chance gem capacity")
	_expect(reloaded.consume_chance_gem() == 0, "third consume should reach zero")
	_expect(reloaded.consume_chance_gem() == 0, "empty chance gem consume should stay at zero")
	reloaded.reset_chance_gems_for_new_playthrough()
	_expect(reloaded.get_chance_gems() == PlazaSaveStore.MAX_CHANCE_GEMS, "chance gem reset should refill to max")

	var legacy_path := _test_path("chance_gems_v4")
	_cleanup(legacy_path)
	_write_plain_text(legacy_path, "[meta]\nschema_version=4\n[wallet]\nplaza_gold=77\nap_current=4\nap_is_first_stage=false\n")
	var migrated := PlazaSaveStore.new()
	migrated.set_save_path(legacy_path)
	_expect(migrated.load(), "v4 plaza save without chance gems should migrate")
	_expect(migrated.get_schema_version() == PlazaSaveStore.SAVE_SCHEMA_VERSION, "v4 migration should stamp the v5 schema")
	_expect(migrated.get_chance_gems() == PlazaSaveStore.MAX_CHANCE_GEMS, "v4 migration should refill missing chance gems to max")
	_expect(migrated.get_plaza_gold() == 77, "v4 migration should preserve existing plaza gold")
	_cleanup(path)
	_cleanup(legacy_path)


func _verify_stage_clear_progress_is_exact_gold_units() -> void:
	var path := _test_path("gold_units")
	_cleanup(path)
	var store := PlazaSaveStore.new()
	store.set_save_path(path)
	var one_gold_summary: Dictionary = store.apply_stage_clear_progress(2, 1, false)
	_expect(int(one_gold_summary.get("plaza_gold", 0)) == 1, "plaza gold should store exact gold units, not starpoint placeholder values")
	var negative_summary: Dictionary = store.apply_stage_clear_progress(2, -200, false)
	_expect(int(negative_summary.get("plaza_gold", 0)) == 1, "negative or placeholder-like values should not reduce plaza gold")
	_cleanup(path)


func _verify_stage_ap_records_once() -> void:
	var path := _test_path("ap_once")
	_cleanup(path)
	var store := PlazaSaveStore.new()
	store.set_save_path(path)
	var first_summary: Dictionary = store.apply_stage_clear_progress(3, 0, true)
	var second_summary: Dictionary = store.apply_stage_clear_progress(3, 0, true)
	var next_stage_summary: Dictionary = store.apply_stage_clear_progress(4, 0, true)
	_expect(int(first_summary.get("granted_ap", 0)) == 1, "first clear of a stage should grant AP")
	_expect(int(second_summary.get("granted_ap", 0)) == 0, "same stage clear edge should not grant AP twice")
	_expect(int(next_stage_summary.get("granted_ap", 0)) == 1, "next real stage advance should be able to grant AP")
	_expect(int(next_stage_summary.get("ap_current", 0)) == PlazaSaveStore.BASE_AP + 2, "AP should persist cumulative stage advances")
	_cleanup(path)


func _verify_stage_map_seed_roundtrip() -> void:
	var path := _test_path("map_seed")
	_cleanup(path)
	var store := PlazaSaveStore.new()
	store.set_save_path(path)
	var stage_one_seed := store.get_or_create_stage_map_seed(1)
	var stage_one_repeat := store.get_or_create_stage_map_seed(1)
	var stage_two_seed := store.get_or_create_stage_map_seed(2)
	_expect(stage_one_seed > 0, "stage map seed should be positive")
	_expect(stage_one_repeat == stage_one_seed, "stage map seed should be stable within the same store")
	_expect(stage_two_seed > 0, "different stages should receive their own positive map seeds")
	var loaded := PlazaSaveStore.new()
	loaded.set_save_path(path)
	var loaded_seed := loaded.get_or_create_stage_map_seed(1)
	_expect(loaded_seed == stage_one_seed, "stage map seed should survive save/load roundtrip")
	var seeds: Dictionary = loaded.get_summary().get("stage_map_seeds", {})
	_expect(int(seeds.get("1", 0)) == stage_one_seed, "summary should expose persisted stage map seeds")
	_cleanup(path)


func _verify_bank_transactions_and_ap_consumption() -> void:
	var path := _test_path("bank_tx")
	_cleanup(path)
	var store := PlazaSaveStore.new()
	store.set_save_path(path)
	store.apply_stage_clear_progress(1, 250, true)
	var deposit_summary: Dictionary = store.perform_bank_transaction("deposit", 1, 100, true)
	_expect(bool(deposit_summary.get("changed", false)), "bank deposit should change the ledger")
	_expect(int(deposit_summary.get("delta_gold", 0)) == -100, "bank deposit should subtract the deposited gold from plaza wallet")
	_expect(int(deposit_summary.get("delta_deposit", 0)) == 100, "bank deposit should add to the bank balance")
	_expect(int(deposit_summary.get("ap_spent", 0)) == 1, "first bank transaction should consume one AP")
	_expect(int(deposit_summary.get("plaza_gold", 0)) == 150, "bank deposit should leave the remaining plaza gold")
	_expect(int(deposit_summary.get("bank_deposit_gold", 0)) == 100, "bank deposit should persist the bank balance")
	_expect(int(deposit_summary.get("ap_current", 0)) == PlazaSaveStore.BASE_AP, "bank deposit AP spend should preserve current-minus-one semantics")

	var withdraw_summary: Dictionary = store.perform_bank_transaction("withdraw", 1, 100, false)
	_expect(bool(withdraw_summary.get("changed", false)), "bank withdraw should change the ledger")
	_expect(int(withdraw_summary.get("delta_gold", 0)) == 100, "bank withdraw should return gold to the plaza wallet")
	_expect(int(withdraw_summary.get("delta_deposit", 0)) == -100, "bank withdraw should subtract from the bank balance")
	_expect(int(withdraw_summary.get("ap_spent", 0)) == 0, "same bank visit can run follow-up transactions without another AP spend")
	_expect(int(withdraw_summary.get("plaza_gold", 0)) == 250, "bank withdraw should restore wallet gold")
	_expect(int(withdraw_summary.get("bank_deposit_gold", 0)) == 0, "bank withdraw should clear the bank balance")
	_cleanup(path)


func _verify_bank_interest_once_per_stage() -> void:
	var path := _test_path("bank_interest")
	_cleanup(path)
	var store := PlazaSaveStore.new()
	store.set_save_path(path)
	store.apply_stage_clear_progress(2, 300, true)
	store.perform_bank_transaction("deposit", 2, 200, true)
	var interest_summary: Dictionary = store.perform_bank_transaction("interest", 2, 100, false)
	_expect(bool(interest_summary.get("changed", false)), "bank interest should change the ledger when a deposit exists")
	_expect(int(interest_summary.get("interest_gold", 0)) == 10, "bank interest should pay 5 percent of the deposit in v1")
	_expect(int(interest_summary.get("plaza_gold", 0)) == 110, "bank interest should add the payout to the plaza wallet")
	var repeat_summary: Dictionary = store.perform_bank_transaction("interest", 2, 100, false)
	_expect(not bool(repeat_summary.get("changed", true)), "bank interest should only be claimable once per stage")
	_expect(str(repeat_summary.get("reason", "")) == "interest_already_claimed", "repeat bank interest should report the stage guard")
	var next_stage_summary: Dictionary = store.perform_bank_transaction("interest", 3, 100, false)
	_expect(bool(next_stage_summary.get("changed", false)), "bank interest should become available on the next stage")
	_expect(int(next_stage_summary.get("interest_gold", 0)) == 10, "next-stage bank interest should use the same v1 rate")
	_cleanup(path)


func _verify_shop_wallet_transactions_and_ap_consumption() -> void:
	var path := _test_path("shop_wallet")
	_cleanup(path)
	var store := PlazaSaveStore.new()
	store.set_save_path(path)
	store.apply_stage_clear_progress(1, 200, true)
	var purchase_summary: Dictionary = store.perform_shop_wallet_transaction("purchase", 80, true)
	_expect(bool(purchase_summary.get("changed", false)), "shop purchase should change the wallet")
	_expect(int(purchase_summary.get("delta_gold", 0)) == -80, "shop purchase should subtract the item price")
	_expect(int(purchase_summary.get("ap_spent", 0)) == 1, "first shop purchase should spend AP")
	_expect(int(purchase_summary.get("plaza_gold", 0)) == 120, "shop purchase should preserve remaining gold")
	_expect(int(purchase_summary.get("ap_current", 0)) == PlazaSaveStore.BASE_AP, "shop purchase AP spend should preserve current-minus-one semantics")

	var sale_summary: Dictionary = store.perform_shop_wallet_transaction("sale", 40, false)
	_expect(bool(sale_summary.get("changed", false)), "shop sale should change the wallet")
	_expect(int(sale_summary.get("delta_gold", 0)) == 40, "shop sale should add the sell price")
	_expect(int(sale_summary.get("ap_spent", 0)) == 0, "same shop visit can run follow-up transactions without another AP spend")
	_expect(int(sale_summary.get("plaza_gold", 0)) == 160, "shop sale should add gold to the plaza wallet")

	var expensive_summary: Dictionary = store.perform_shop_wallet_transaction("purchase", 9999, true)
	_expect(not bool(expensive_summary.get("changed", true)), "shop purchase should fail when gold is insufficient")
	_expect(str(expensive_summary.get("reason", "")) == "not_enough_gold", "insufficient shop purchase should report not_enough_gold")
	_expect(int(expensive_summary.get("ap_spent", 0)) == 0, "failed shop purchase should not spend AP")
	_expect(int(expensive_summary.get("plaza_gold", 0)) == 160, "failed shop purchase should leave wallet unchanged")
	_cleanup(path)


func _verify_gacha_payment_and_ap_consumption() -> void:
	var path := _test_path("gacha_payment")
	_cleanup(path)
	var store := PlazaSaveStore.new()
	store.set_save_path(path)
	store.apply_stage_clear_progress(1, 250, true)
	var pull_summary: Dictionary = store.perform_gacha_pull_payment(150, true)
	_expect(bool(pull_summary.get("changed", false)), "gacha payment should change the wallet")
	_expect(int(pull_summary.get("delta_gold", 0)) == -150, "gacha payment should subtract the pull cost")
	_expect(int(pull_summary.get("ap_spent", 0)) == 1, "first gacha pull should spend AP")
	_expect(int(pull_summary.get("plaza_gold", 0)) == 100, "gacha payment should preserve remaining gold")
	_expect(int(pull_summary.get("ap_current", 0)) == PlazaSaveStore.BASE_AP, "gacha AP spend should preserve current-minus-one semantics")

	var expensive_summary: Dictionary = store.perform_gacha_pull_payment(9999, true)
	_expect(not bool(expensive_summary.get("changed", true)), "gacha payment should fail when gold is insufficient")
	_expect(str(expensive_summary.get("reason", "")) == "not_enough_gold", "insufficient gacha payment should report not_enough_gold")
	_expect(int(expensive_summary.get("ap_spent", 0)) == 0, "failed gacha payment should not spend AP")
	_expect(int(expensive_summary.get("plaza_gold", 0)) == 100, "failed gacha payment should leave wallet unchanged")
	_cleanup(path)


func _verify_lingpet_egg_payment_and_ap_consumption() -> void:
	var path := _test_path("lingpet_egg_payment")
	_cleanup(path)
	var store := PlazaSaveStore.new()
	store.set_save_path(path)
	store.apply_stage_clear_progress(1, 350, true)
	var payment_summary: Dictionary = store.perform_lingpet_egg_payment(250, true)
	_expect(bool(payment_summary.get("changed", false)), "lingpet egg payment should change the wallet")
	_expect(int(payment_summary.get("delta_gold", 0)) == -250, "lingpet egg payment should subtract the egg cost")
	_expect(int(payment_summary.get("ap_spent", 0)) == 1, "first lingpet egg purchase should spend AP")
	_expect(int(payment_summary.get("plaza_gold", 0)) == 100, "lingpet egg payment should preserve remaining gold")
	_expect(int(payment_summary.get("ap_current", 0)) == PlazaSaveStore.BASE_AP, "lingpet egg AP spend should preserve current-minus-one semantics")

	var expensive_summary: Dictionary = store.perform_lingpet_egg_payment(9999, true)
	_expect(not bool(expensive_summary.get("changed", true)), "lingpet egg payment should fail when gold is insufficient")
	_expect(str(expensive_summary.get("reason", "")) == "not_enough_gold", "insufficient lingpet egg payment should report not_enough_gold")
	_expect(int(expensive_summary.get("ap_spent", 0)) == 0, "failed lingpet egg payment should not spend AP")
	_expect(int(expensive_summary.get("plaza_gold", 0)) == 100, "failed lingpet egg payment should leave wallet unchanged")
	_cleanup(path)


func _verify_blacksmith_payment_and_ap_consumption() -> void:
	var path := _test_path("blacksmith_payment")
	_cleanup(path)
	var store := PlazaSaveStore.new()
	store.set_save_path(path)
	store.apply_stage_clear_progress(1, 200, true)
	var payment_summary: Dictionary = store.perform_blacksmith_enhancement_payment(100, true)
	_expect(bool(payment_summary.get("changed", false)), "blacksmith payment should change the wallet")
	_expect(int(payment_summary.get("delta_gold", 0)) == -100, "blacksmith payment should subtract the enhancement cost")
	_expect(int(payment_summary.get("ap_spent", 0)) == 1, "first blacksmith attempt should spend AP")
	_expect(int(payment_summary.get("plaza_gold", 0)) == 100, "blacksmith payment should preserve remaining gold")
	_expect(int(payment_summary.get("ap_current", 0)) == PlazaSaveStore.BASE_AP, "blacksmith AP spend should preserve current-minus-one semantics")

	var expensive_summary: Dictionary = store.perform_blacksmith_enhancement_payment(9999, true)
	_expect(not bool(expensive_summary.get("changed", true)), "blacksmith payment should fail when gold is insufficient")
	_expect(str(expensive_summary.get("reason", "")) == "not_enough_gold", "insufficient blacksmith payment should report not_enough_gold")
	_expect(int(expensive_summary.get("ap_spent", 0)) == 0, "failed blacksmith payment should not spend AP")
	_expect(int(expensive_summary.get("plaza_gold", 0)) == 100, "failed blacksmith payment should leave wallet unchanged")
	_cleanup(path)


func _verify_academy_payment_and_ap_consumption() -> void:
	var path := _test_path("academy_payment")
	_cleanup(path)
	var store := PlazaSaveStore.new()
	store.set_save_path(path)
	store.apply_stage_clear_progress(1, 320, true)
	var payment_summary: Dictionary = store.perform_academy_lesson_payment(200, true)
	_expect(bool(payment_summary.get("changed", false)), "academy payment should change the wallet")
	_expect(int(payment_summary.get("delta_gold", 0)) == -200, "academy payment should subtract the lesson cost")
	_expect(int(payment_summary.get("ap_spent", 0)) == 1, "first academy lesson should spend AP")
	_expect(int(payment_summary.get("plaza_gold", 0)) == 120, "academy payment should preserve remaining gold")
	_expect(int(payment_summary.get("ap_current", 0)) == PlazaSaveStore.BASE_AP, "academy AP spend should preserve current-minus-one semantics")

	var expensive_summary: Dictionary = store.perform_academy_lesson_payment(9999, true)
	_expect(not bool(expensive_summary.get("changed", true)), "academy payment should fail when gold is insufficient")
	_expect(str(expensive_summary.get("reason", "")) == "not_enough_gold", "insufficient academy payment should report not_enough_gold")
	_expect(int(expensive_summary.get("ap_spent", 0)) == 0, "failed academy payment should not spend AP")
	_expect(int(expensive_summary.get("plaza_gold", 0)) == 120, "failed academy payment should leave wallet unchanged")
	_cleanup(path)


func _verify_tavern_quest_state_and_ap_consumption() -> void:
	var path := _test_path("tavern_quest")
	_cleanup(path)
	var store := PlazaSaveStore.new()
	store.set_save_path(path)
	store.apply_stage_clear_progress(1, 0, true)
	var quest := {
		"id": "smoke_quest_stage_1",
		"name": "스모크 의뢰",
		"description": "다음 전투를 마친 뒤 보고합니다.",
		"accepted_stage": 1,
		"reward_gold": 180,
	}
	var accept_summary: Dictionary = store.perform_tavern_accept_quest(1, quest, true)
	_expect(bool(accept_summary.get("changed", false)), "tavern accept should persist an active quest")
	_expect(int(accept_summary.get("ap_spent", 0)) == 1, "first tavern accept should spend AP")
	_expect(int(accept_summary.get("ap_current", 0)) == PlazaSaveStore.BASE_AP, "tavern accept AP spend should preserve current-minus-one semantics")
	var active_quest: Dictionary = store.get_summary().get("tavern_active_quest", {})
	_expect(str(active_quest.get("id", "")) == "smoke_quest_stage_1", "tavern accept should save the active quest id")

	var repeat_accept_summary: Dictionary = store.perform_tavern_accept_quest(1, quest, true)
	_expect(not bool(repeat_accept_summary.get("changed", true)), "tavern should reject a second active quest")
	_expect(str(repeat_accept_summary.get("reason", "")) == "quest_already_active", "repeat tavern accept should report the active quest guard")
	_expect(int(repeat_accept_summary.get("ap_spent", 0)) == 0, "rejected tavern accept should not spend AP")

	var early_complete_summary: Dictionary = store.perform_tavern_complete_quest(1, true)
	_expect(not bool(early_complete_summary.get("changed", true)), "tavern report should wait for a later stage")
	_expect(str(early_complete_summary.get("reason", "")) == "quest_in_progress", "same-stage tavern report should report quest_in_progress")
	_expect(int(early_complete_summary.get("ap_spent", 0)) == 0, "same-stage tavern report should not spend AP")

	store.apply_stage_clear_progress(2, 25, true)
	var complete_summary: Dictionary = store.perform_tavern_complete_quest(2, true)
	_expect(bool(complete_summary.get("changed", false)), "tavern report should complete after a later stage clear")
	_expect(int(complete_summary.get("delta_gold", 0)) == 180, "tavern report should award the quest gold")
	_expect(int(complete_summary.get("plaza_gold", 0)) == 205, "tavern report should add reward gold to the existing wallet")
	_expect(int(complete_summary.get("ap_spent", 0)) == 1, "first successful tavern report visit should spend AP")
	_expect((store.get_summary().get("tavern_active_quest", {}) as Dictionary).is_empty(), "tavern report should clear the active quest")
	var completed_quests: Dictionary = store.get_summary().get("tavern_completed_quests", {})
	_expect(bool(completed_quests.get("smoke_quest_stage_1", false)), "tavern report should persist the completed quest id")

	var repeat_complete_summary: Dictionary = store.perform_tavern_complete_quest(2, true)
	_expect(not bool(repeat_complete_summary.get("changed", true)), "tavern should reject reporting without an active quest")
	_expect(str(repeat_complete_summary.get("reason", "")) == "no_active_quest", "repeat tavern report should report no_active_quest")
	_expect(int(repeat_complete_summary.get("ap_spent", 0)) == 0, "rejected tavern report should not spend AP")
	_cleanup(path)


func _verify_corrupt_primary_recovers_last_good() -> void:
	var path := _test_path("recover")
	_cleanup(path)
	var store := PlazaSaveStore.new()
	store.set_save_path(path)
	store.apply_stage_clear_progress(5, 77, true)
	_write_plain_text(path, "[wallet\nplaza_gold =")

	var recovered := PlazaSaveStore.new()
	recovered.set_save_path(path)
	_expect(recovered.load(), "corrupted primary should recover from last_good")
	var summary: Dictionary = recovered.get_summary()
	_expect(str(summary.get("load", "")) == "recovered_last_good", "load summary should report last_good recovery")
	_expect(int(summary.get("plaza_gold", 0)) == 77, "last_good recovery should restore plaza gold")
	_expect(int(summary.get("ap_current", 0)) == PlazaSaveStore.BASE_AP + 1, "last_good recovery should restore AP")
	_cleanup(path)


func _test_path(label: String) -> String:
	return "res://.tmp/plaza_save_store_smoke_%s_%d_%d.cfg" % [
		label,
		OS.get_process_id(),
		Time.get_ticks_usec(),
	]


func _cleanup(path: String) -> void:
	var backup_path := path.trim_suffix(".cfg") + ".last_good.cfg"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path))


func _write_text_with_bom(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_expect(file != null, "test should be able to write BOM save fixture")
	if file == null:
		return
	var bytes := PackedByteArray([0xEF, 0xBB, 0xBF])
	bytes.append_array(text.to_utf8_buffer())
	file.store_buffer(bytes)
	file.close()


func _write_plain_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_expect(file != null, "test should be able to write corrupt save fixture")
	if file == null:
		return
	file.store_string(text)
	file.close()


func _file_starts_with_bom(path: String) -> bool:
	var bytes := FileAccess.get_file_as_bytes(path)
	return bytes.size() >= 3 and bytes[0] == 0xEF and bytes[1] == 0xBB and bytes[2] == 0xBF


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
