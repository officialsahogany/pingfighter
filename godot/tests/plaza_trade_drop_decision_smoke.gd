extends SceneTree

const PlazaTradeDropDecision := preload("res://scripts/plaza/plaza_trade_drop_decision.gd")

var _failures: Array[String] = []


func _init() -> void:
	_expect_empty(PlazaTradeDropDecision.resolve("", 2, "shop", false, -1, false), "blank source panel")
	_expect_empty(PlazaTradeDropDecision.resolve("shop", -1, "player", false, -1, false), "negative source index")

	_expect_action(
		PlazaTradeDropDecision.resolve("shop", 8, "player", false, -1, false),
		PlazaTradeDropDecision.ACTION_TRADE,
		"cross-panel shop trade"
	)
	_expect_action(
		PlazaTradeDropDecision.resolve("player", 3, "shop", false, -1, true),
		PlazaTradeDropDecision.ACTION_CONFIRM_SELL,
		"cross-panel equipped sale"
	)
	_expect_action(
		PlazaTradeDropDecision.resolve("shop", 8, "shop", false, 12, false),
		PlazaTradeDropDecision.ACTION_REORDER,
		"same-panel drag reorder"
	)
	var reorder := PlazaTradeDropDecision.resolve("shop", 8, "shop", false, 12, false)
	_expect(int(reorder.get("from_index", -1)) == 8 and int(reorder.get("to_index", -1)) == 12, "reorder indices")
	_expect_empty(
		PlazaTradeDropDecision.resolve("shop", 8, "shop", false, -1, false),
		"same-panel invalid drop"
	)

	_expect_action(
		PlazaTradeDropDecision.resolve("shop", 8, "", true, -1, false),
		PlazaTradeDropDecision.ACTION_TRADE,
		"short click released outside panel"
	)
	_expect_action(
		PlazaTradeDropDecision.resolve("player", 0, "player", true, 0, true),
		PlazaTradeDropDecision.ACTION_CONFIRM_SELL,
		"equipped player click"
	)
	_expect_empty(
		PlazaTradeDropDecision.resolve("shop", 8, "", false, -1, false),
		"drag released outside panels"
	)

	if _failures.is_empty():
		print("plaza_trade_drop_decision_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect_action(decision: Dictionary, expected: String, label: String) -> void:
	var actual := str(decision.get("action", ""))
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, expected, actual])


func _expect_empty(decision: Dictionary, label: String) -> void:
	if not decision.is_empty():
		_failures.append("%s: expected no decision, got %s" % [label, decision])


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
