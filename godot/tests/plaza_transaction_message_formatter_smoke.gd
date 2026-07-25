extends SceneTree

const PlazaScene := preload("res://scripts/plaza/plaza_scene.gd")
const PlazaTransactionMessageFormatter := preload("res://scripts/plaza/plaza_transaction_message_formatter.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

var _failures: Array[String] = []
var _settings_snapshot: Dictionary = {}


func _init() -> void:
	_settings_snapshot = _snapshot_settings_file(LanguageSettings.SETTINGS_PATH)
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)
	var scene: Object = PlazaScene.new()
	_run_cases(scene)
	if scene is Node:
		(scene as Node).free()
	_restore_settings()
	if _failures.is_empty():
		print("plaza_transaction_message_formatter_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _run_cases(scene: Object) -> void:
	var cases: Array[Dictionary] = [
		{"facility": "bank", "method": "_format_bank_transaction_message", "summary": {"changed": false, "reason": "no_bank_deposit"}, "expected": "찾거나 정산할 예금이 없습니다."},
		{"facility": "bank", "method": "_format_bank_transaction_message", "summary": {"changed": true, "action": "deposit", "delta_deposit": 120}, "expected": "120G를 예금했습니다."},
		{"facility": "shop", "method": "_format_shop_transaction_message", "summary": {"changed": false, "reason": "inventory_full"}, "expected": "인벤토리가 가득 찼습니다."},
		{"facility": "shop", "method": "_format_shop_transaction_message", "summary": {"changed": true, "action": "purchase", "item_name": "gauge_charge", "display_name": "에너지드링크", "delta_gold": -150}, "expected": "에너지드링크을(를) 구매했습니다. -150G"},
		{"facility": "gacha", "method": "_format_gacha_transaction_message", "summary": {"changed": false, "reason": "empty_gacha_pool"}, "expected": "뽑기 캡슐이 비어 있습니다."},
		{"facility": "gacha", "method": "_format_gacha_transaction_message", "summary": {"changed": true, "display_name": "시험 아이템", "delta_gold": -300}, "expected": "시험 아이템을(를) 뽑았습니다. -300G"},
		{"facility": "lingpet_store", "method": "_format_lingpet_store_transaction_message", "summary": {"changed": false, "action": "ring_core", "reason": "perk_slots_full"}, "expected": "퍽 슬롯이 가득 차 링코어를 강화할 수 없습니다."},
		{"facility": "lingpet_store", "method": "_format_lingpet_store_transaction_message", "summary": {"changed": true, "action": "ring_core", "ring_core_name": "공명", "new_cap": 4, "delta_gold": -700}, "expected": "공명 링코어가 친밀도 Lv.4까지 열렸습니다. -700G"},
		{"facility": "lingpet_store", "method": "_format_lingpet_store_transaction_message", "summary": {"changed": true, "action": "egg", "delta_gold": -500}, "expected": "공명 알이 전투에 나타났습니다. -500G"},
		{"facility": "blacksmith", "method": "_format_blacksmith_transaction_message", "summary": {"changed": false, "reason": "max_level", "display_name": "천둥망치"}, "expected": "천둥망치은(는) 이미 최대 강화입니다."},
		{"facility": "blacksmith", "method": "_format_blacksmith_transaction_message", "summary": {"changed": true, "result": "success", "display_name": "천둥망치", "new_level": 3, "delta_gold": -240}, "expected": "천둥망치 +3 강화 성공! -240G"},
		{"facility": "academy", "method": "_format_academy_transaction_message", "summary": {"changed": false, "reason": "choice_already_active"}, "expected": "이미 진행 중인 스킬 선택이 있습니다."},
		{"facility": "academy", "method": "_format_academy_transaction_message", "summary": {"changed": true, "choice_opened": true, "delta_gold": -350}, "expected": "스킬 수업을 시작합니다. -350G"},
		{"facility": "tavern", "method": "_format_tavern_transaction_message", "summary": {"changed": false, "reason": "quest_in_progress"}, "expected": "다음 전투를 마친 뒤 보고할 수 있습니다."},
		{"facility": "tavern", "method": "_format_tavern_transaction_message", "summary": {"changed": true, "action": "complete", "quest_name": "달빛 수색", "delta_gold": 900}, "expected": "달빛 수색 보고 완료. +900G"},
	]
	for case in cases:
		var facility := str(case["facility"])
		var summary: Dictionary = case["summary"]
		var owner_output := _format_owner(facility, summary)
		var facade_output := str(scene.call(str(case["method"]), summary))
		_expect_eq(owner_output, str(case["expected"]), "%s owner output" % facility)
		_expect_eq(facade_output, owner_output, "%s scene facade parity" % facility)
	_expect_eq(PlazaTransactionMessageFormatter.format_facility("unknown", {}), "", "unknown facility")


func _format_owner(facility: String, summary: Dictionary) -> String:
	return PlazaTransactionMessageFormatter.format_facility(facility, summary)


func _expect_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, expected, actual])


func _snapshot_settings_file(path: String) -> Dictionary:
	var had_original := FileAccess.file_exists(path)
	var original_bytes := PackedByteArray()
	if had_original:
		original_bytes = FileAccess.get_file_as_bytes(path)
	return {"had": had_original, "bytes": original_bytes}


func _restore_settings() -> void:
	if _settings_snapshot.is_empty():
		return
	if bool(_settings_snapshot.get("had", false)):
		var file := FileAccess.open(LanguageSettings.SETTINGS_PATH, FileAccess.WRITE)
		if file != null:
			file.store_buffer(_settings_snapshot.get("bytes", PackedByteArray()))
			file.close()
	elif FileAccess.file_exists(LanguageSettings.SETTINGS_PATH):
		DirAccess.remove_absolute(LanguageSettings.SETTINGS_PATH)
