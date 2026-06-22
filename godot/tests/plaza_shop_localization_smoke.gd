extends SceneTree

# Focused regression seal for the Plaza shop-transaction i18n slice.
#
# The localization_coverage_smoke whitelist does NOT exercise plaza draw surfaces, so this
# smoke drives the REAL formatter (plaza_scene._format_shop_transaction_message) under every
# non-Korean language and asserts the actual rendered output:
#   - no Korean leaks (the core regression),
#   - printf placeholders are fully substituted (no leftover %s / %d),
#   - no raw key fallback ("plaza.msg." should never reach the player),
#   - the output actually diverges from the Korean render (proves a template/translation was
#     hit, not raw Korean passthrough), and
#   - the item name is localized before substitution (Korean display name never appears).
# EN content is pinned exactly to lock template + substitution + name-localization together.
# Korean behavior is asserted unchanged (particles + Korean item name preserved).

const PlazaScene := preload("res://scripts/plaza/plaza_scene.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

var _failures: Array[String] = []
var _settings_snapshot: Dictionary = {}


func _init() -> void:
	_settings_snapshot = _snapshot_settings_file(LanguageSettings.SETTINGS_PATH)
	var scene: Object = PlazaScene.new()
	_run(scene)
	if scene is Node:
		(scene as Node).free()
	_restore_settings()

	if _failures.is_empty():
		print("plaza_shop_localization_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _cases() -> Array:
	# label -> summary dict shaped exactly like _build_shop_trade_summary output.
	return [
		{"label": "purchase", "summary": {"action": "purchase", "changed": true, "item_name": "gauge_charge", "display_name": "에너지드링크", "delta_gold": -150}},
		{"label": "sale", "summary": {"action": "sale", "changed": true, "item_name": "speedboots", "display_name": "스피드부츠", "sell_price": 80}},
		{"label": "traded", "summary": {"action": "reorder", "changed": true, "item_name": "gauge_charge", "display_name": "에너지드링크"}},
		{"label": "empty_item", "summary": {"action": "purchase", "changed": true, "item_name": "", "display_name": "", "delta_gold": -100}},
		{"label": "no_ap", "summary": {"changed": false, "reason": "no_ap"}},
		{"label": "not_enough_gold", "summary": {"changed": false, "reason": "not_enough_gold"}},
		{"label": "active_slots_full", "summary": {"changed": false, "reason": "active_slots_full"}},
		{"label": "no_active_item", "summary": {"changed": false, "reason": "no_active_item"}},
		{"label": "no_passive_item", "summary": {"changed": false, "reason": "no_passive_item"}},
		{"label": "inventory_full", "summary": {"changed": false, "reason": "inventory_full"}},
		{"label": "missing_item_runtime", "summary": {"changed": false, "reason": "missing_item_runtime"}},
		{"label": "missing_owner", "summary": {"changed": false, "reason": "missing_owner"}},
		{"label": "unknown_reason", "summary": {"changed": false, "reason": "totally_unknown"}},
	]


func _run(scene: Object) -> void:
	var cases: Array = _cases()

	# Korean reference + behavior-preservation.
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)
	var korean_render: Dictionary = {}
	for case in cases:
		korean_render[str(case["label"])] = str(scene.call("_format_shop_transaction_message", case["summary"]))
	var ko_purchase: String = str(korean_render.get("purchase", ""))
	_expect(ko_purchase.find("구매했습니다") >= 0, "KO purchase should keep Korean copy, got '%s'" % ko_purchase)
	_expect(ko_purchase.find("에너지드링크") >= 0, "KO purchase should keep Korean item name, got '%s'" % ko_purchase)
	_expect(ko_purchase.find("%s") < 0 and ko_purchase.find("%d") < 0, "KO purchase should be fully substituted, got '%s'" % ko_purchase)
	_expect(str(korean_render.get("empty_item", "")).find("아이템") >= 0, "KO empty-item fallback should read '아이템'")

	# Every non-Korean language: drive the real formatter and assert no leaks.
	for language in [
		LanguageSettings.LANGUAGE_ENGLISH,
		LanguageSettings.LANGUAGE_CHINESE,
		LanguageSettings.LANGUAGE_JAPANESE,
		LanguageSettings.LANGUAGE_SPANISH,
		LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL,
		LanguageSettings.LANGUAGE_RUSSIAN,
	]:
		LanguageSettings.set_language(language)
		for case in cases:
			var label: String = str(case["label"])
			var out: String = str(scene.call("_format_shop_transaction_message", case["summary"]))
			var ctx: String = "[%s/%s] '%s'" % [language, label, out]
			_expect(out != "", "%s empty output" % ctx)
			_expect(not _has_hangul(out), "%s leaked Korean" % ctx)
			_expect(out.find("%s") < 0 and out.find("%d") < 0, "%s unsubstituted placeholder" % ctx)
			_expect(out.find("plaza.msg.") < 0, "%s raw key leak" % ctx)
			_expect(out != str(korean_render.get(label, "")), "%s did not localize away from Korean" % ctx)

	# Pin EN content exactly: template + numeric substitution + name localization in one shot.
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_ENGLISH)
	_expect_eq(str(scene.call("_format_shop_transaction_message", cases[0]["summary"])), "Purchased Energy Drink. -150G", "EN purchase exact")
	_expect_eq(str(scene.call("_format_shop_transaction_message", cases[1]["summary"])), "Sold Speed Boots. +80G", "EN sale exact")
	_expect_eq(str(scene.call("_format_shop_transaction_message", cases[3]["summary"])), "Purchased Item. -100G", "EN empty-item fallback exact")
	_expect_eq(str(scene.call("_format_shop_transaction_message", cases[4]["summary"])), "Not enough Keys.", "EN no_ap exact")
	_expect_eq(str(scene.call("_format_shop_transaction_message", cases[12]["summary"])), "Can't trade right now.", "EN unknown-reason default exact")


func _has_hangul(text: String) -> bool:
	for index in range(text.length()):
		var code := text.unicode_at(index)
		if code >= 0x1100 and code <= 0x11FF:
			return true
		if code >= 0x3130 and code <= 0x318F:
			return true
		if code >= 0xAC00 and code <= 0xD7AF:
			return true
	return false


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
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LanguageSettings.SETTINGS_PATH))
	LanguageSettings.reset_cache_for_tests()
	LanguageSettings.apply_saved_language()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: String, expected: String, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected '%s', got '%s'" % [label, expected, actual])
