extends SceneTree

const OWNER_PATH := "res://scripts/plaza/plaza_transaction_message_formatter.gd"
const SCENE_PATH := "res://scripts/plaza/plaza_scene.gd"

const FACADES := {
	"_format_bank_transaction_message": "format_bank",
	"_format_shop_transaction_message": "format_shop",
	"_format_gacha_transaction_message": "format_gacha",
	"_format_lingpet_store_transaction_message": "format_lingpet_store",
	"_format_blacksmith_transaction_message": "format_blacksmith",
	"_format_academy_transaction_message": "format_academy",
	"_format_tavern_transaction_message": "format_tavern",
}

var _failures: Array[String] = []


func _init() -> void:
	var scene_source := FileAccess.get_file_as_string(SCENE_PATH)
	var owner_source := FileAccess.get_file_as_string(OWNER_PATH)
	_expect(scene_source.find("const PlazaTransactionMessageFormatter := preload(\"%s\")" % OWNER_PATH) >= 0, "plaza scene should preload the transaction-message owner")
	_expect(scene_source.find("const LanguageSettings := preload") < 0, "plaza scene should not retain formatter-only localization ownership")
	_expect(scene_source.find("func _localize_shop_item_name") < 0, "plaza scene should not retain the formatter's item-name localization policy")
	_expect(owner_source.find("func localize_shop_item_name") >= 0, "formatter owner should retain shop item-name localization")
	for raw_facade in FACADES.keys():
		var facade := str(raw_facade)
		var owner_method := str(FACADES[raw_facade])
		var body := _function_body(scene_source, "func %s" % facade)
		_expect(body != "", "plaza scene should retain compatibility facade %s" % facade)
		_expect(body.find("PlazaTransactionMessageFormatter.%s(summary)" % owner_method) >= 0, "%s should delegate to the formatter owner" % facade)
		_expect(_count_nonempty_body_lines(body) <= 2, "%s should stay a one-line compatibility facade" % facade)

	if _failures.is_empty():
		print("plaza_transaction_message_formatter_owner_integration_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var end := source.find("\nfunc ", start + signature.length())
	return source.substr(start) if end < 0 else source.substr(start, end - start)


func _count_nonempty_body_lines(body: String) -> int:
	var count := 0
	for line in body.split("\n"):
		if str(line).strip_edges() != "":
			count += 1
	return maxi(0, count - 1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
