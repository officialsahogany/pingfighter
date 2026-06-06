extends SceneTree

const BallIntensity := preload("res://scripts/ball/ball_intensity.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_legacy_register_hit_semantics()
	_verify_actor_side_split_for_lingpet_contact()
	_verify_rally_tier_uses_exchange_count()
	_verify_reset_clears_director_backbone()
	_verify_intensity_getters_are_bounded()
	_verify_stakes_feed_theater_intensity()

	if _failures.is_empty():
		print("ball_intensity_director_contract_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_legacy_register_hit_semantics() -> void:
	var intensity := BallIntensity.new()
	intensity.register_hit("player")
	_expect(intensity.get_last_hit_by() == "player", "legacy get_last_hit_by should keep player side")
	_expect(intensity.get_last_hit_side() == "player", "last_hit_side should alias legacy side")
	_expect(intensity.get_last_hit_actor() == "player", "legacy register_hit should use the side as actor")
	_expect(intensity.get_rally_count() == 0, "first legacy hit should not count as an exchange")
	_expect(intensity.get_rally_exchange_count() == 0, "exchange count should mirror legacy rally count")
	_expect(intensity.get_rally_contact_count() == 1, "legacy hit should increment the additive contact count")
	_expect(not intensity.did_rally_tier_advance(), "first legacy hit should not advance rally tier")

	intensity.register_hit("boss")
	_expect(intensity.get_last_hit_by() == "boss", "legacy boss hit should update last_hit_by")
	_expect(intensity.get_rally_count() == 1, "side change should increment legacy rally count")
	_expect(intensity.get_rally_exchange_count() == 1, "side change should increment exchange count")
	_expect(intensity.get_rally_contact_count() == 2, "second legacy hit should increment contact count")

	intensity.register_hit("boss")
	_expect(intensity.get_rally_count() == 1, "same-side legacy hit should not increment rally count")
	_expect(intensity.get_rally_exchange_count() == 1, "same-side legacy hit should not increment exchange count")
	_expect(intensity.get_rally_contact_count() == 3, "same-side legacy hit should still increment contact count")
	_expect(not intensity.did_rally_tier_advance(), "same-side legacy hit should clear tier advance edge")
	_expect(is_equal_approx(intensity.calculate(Vector2(20.0, 0.0)), 0.5), "calculate should preserve speed plus capped rally bonus behavior")


func _verify_actor_side_split_for_lingpet_contact() -> void:
	var intensity := BallIntensity.new()
	intensity.register_contact("player", "player")
	intensity.register_contact("lingpet", "player", {"source": "companion_guard"})
	_expect(intensity.get_last_hit_by() == "player", "lingpet contact should preserve legacy player side")
	_expect(intensity.get_last_hit_side() == "player", "lingpet contact should expose player side")
	_expect(intensity.get_last_hit_actor() == "lingpet", "lingpet contact should expose actor identity")
	_expect(str(intensity.get_last_contact_tags().get("source", "")) == "companion_guard", "lingpet contact should retain copied tags")
	_expect(intensity.get_rally_contact_count() == 2, "same-side lingpet contact should increment total contact count")
	_expect(intensity.get_rally_exchange_count() == 0, "same-side lingpet contact should not increment exchanges")
	_expect(intensity.get_rally_tier() == 0, "same-side lingpet contact should not advance rally tier")

	intensity.register_contact("boss", "boss")
	_expect(intensity.get_last_hit_by() == "boss", "boss contact should update legacy side")
	_expect(intensity.get_last_hit_actor() == "boss", "boss contact should update actor")
	_expect(intensity.get_rally_contact_count() == 3, "boss contact should increment contact count")
	_expect(intensity.get_rally_exchange_count() == 1, "player-side to boss-side contact should increment exchanges")


func _verify_rally_tier_uses_exchange_count() -> void:
	_expect(_tier_after_exchanges(0) == 0, "0 exchanges should stay tier 0")
	_expect(_tier_after_exchanges(4) == 0, "4 exchanges should stay tier 0")
	_expect(_tier_after_exchanges(5) == 1, "5 exchanges should enter tier 1")
	_expect(_tier_after_exchanges(9) == 1, "9 exchanges should stay tier 1")
	_expect(_tier_after_exchanges(10) == 2, "10 exchanges should enter tier 2")
	_expect(_tier_after_exchanges(14) == 2, "14 exchanges should stay tier 2")
	_expect(_tier_after_exchanges(15) == 3, "15 exchanges should enter tier 3")
	_expect(_tier_after_exchanges(24) == 3, "24 exchanges should stay tier 3")
	_expect(_tier_after_exchanges(25) == 4, "25 exchanges should enter tier 4")
	_expect(_tier_after_exchanges(34) == 4, "34 exchanges should stay tier 4")
	_expect(_tier_after_exchanges(35) == 5, "35 exchanges should enter tier 5")
	_expect(_tier_edge_after_exchanges(4) == false, "4th exchange should not raise a tier edge")
	_expect(_tier_edge_after_exchanges(5), "5th exchange should raise the tier 1 edge")
	_expect(_tier_edge_after_exchanges(6) == false, "6th exchange should not repeat the tier 1 edge")
	_expect(_tier_edge_after_exchanges(10), "10th exchange should raise the tier 2 edge")
	_expect(_tier_edge_after_exchanges(35), "35th exchange should raise the tier 5 edge")

	var intensity := BallIntensity.new()
	intensity.register_contact("player", "player")
	for index in range(20):
		intensity.register_contact("lingpet", "player", {"index": index})
	_expect(intensity.get_rally_contact_count() == 21, "same-side contacts should accumulate for analysis")
	_expect(intensity.get_rally_exchange_count() == 0, "same-side contacts should not create exchange count")
	_expect(intensity.get_rally_tier() == 0, "same-side contacts should not advance rally tier")


func _verify_reset_clears_director_backbone() -> void:
	var intensity := BallIntensity.new()
	intensity.register_contact("player", "player")
	intensity.register_contact("lingpet", "player")
	intensity.register_contact("boss", "boss")
	intensity.update_transition(Vector2(30.0, 0.0), 1.0)
	intensity.reset()
	_expect(intensity.get_rally_count() == 0, "reset should clear legacy rally count")
	_expect(intensity.get_rally_contact_count() == 0, "reset should clear contact count")
	_expect(intensity.get_rally_exchange_count() == 0, "reset should clear exchange count")
	_expect(intensity.get_rally_tier() == 0, "reset should clear rally tier")
	_expect(intensity.get_last_hit_by() == "", "reset should clear legacy side")
	_expect(intensity.get_last_hit_actor() == "", "reset should clear actor")
	_expect(intensity.get_last_contact_tags().is_empty(), "reset should clear contact tags")
	_expect(is_equal_approx(intensity.get_raw_contact_intensity(), 0.0), "reset should clear raw contact intensity")
	var stakes: Dictionary = intensity.get_stakes()
	_expect(not bool(stakes.get("deuce_mode", true)), "reset should clear deuce stakes")
	_expect(not bool(stakes.get("player_can_win", true)), "reset should clear player match-point stakes")
	_expect(not bool(stakes.get("boss_can_win", true)), "reset should clear boss match-point stakes")


func _verify_intensity_getters_are_bounded() -> void:
	var intensity := BallIntensity.new()
	intensity.register_hit("player")
	intensity.register_hit("boss")
	intensity.update_transition(Vector2(40.0, 0.0), 1.0)
	_expect(intensity.get_raw_contact_intensity() >= 0.0 and intensity.get_raw_contact_intensity() <= 1.0, "raw contact intensity should stay bounded")
	_expect(intensity.get_display_intensity() >= 0.0 and intensity.get_display_intensity() <= 1.0, "display intensity should stay bounded")
	_expect(intensity.get_theater_intensity() >= 0.0 and intensity.get_theater_intensity() <= 1.0, "theater intensity should stay bounded")
	var stakes: Dictionary = intensity.get_stakes()
	_expect(not bool(stakes.get("deuce_mode", true)), "default stakes should not report deuce")
	_expect(not bool(stakes.get("player_can_win", true)), "default stakes should not report player match point")
	_expect(not bool(stakes.get("boss_can_win", true)), "default stakes should not report boss match point")


func _verify_stakes_feed_theater_intensity() -> void:
	var intensity := BallIntensity.new()
	intensity.update_transition(Vector2(0.0, 0.0), 1.0)
	var neutral_theater: float = intensity.get_theater_intensity()
	intensity.set_stakes(true, false, false)
	var deuce_theater: float = intensity.get_theater_intensity()
	var deuce_stakes: Dictionary = intensity.get_stakes()
	_expect(bool(deuce_stakes.get("deuce_mode", false)), "set_stakes should store deuce mode")
	_expect(deuce_theater > neutral_theater, "deuce stakes should raise theater intensity")

	intensity.set_stakes(true, true, true)
	var both_match_point_theater: float = intensity.get_theater_intensity()
	var both_stakes: Dictionary = intensity.get_stakes()
	_expect(bool(both_stakes.get("player_can_win", false)), "set_stakes should store player match point")
	_expect(bool(both_stakes.get("boss_can_win", false)), "set_stakes should store boss match point")
	_expect(both_match_point_theater > deuce_theater, "match-point stakes should further raise theater intensity")
	_expect(both_match_point_theater <= 1.0, "theater intensity should stay clamped after stakes")

	intensity.set_stakes(true, true, true)
	for _index in range(8):
		intensity.register_hit("player")
		intensity.register_hit("boss")
	intensity.update_transition(Vector2(60.0, 0.0), 500.0)
	_expect(is_equal_approx(intensity.get_theater_intensity(), 1.0), "rally plus stakes should clamp theater intensity to 1")


func _tier_after_exchanges(exchange_count: int) -> int:
	var intensity := BallIntensity.new()
	intensity.register_contact("player", "player")
	for _index in range(exchange_count):
		var next_side := "boss" if intensity.get_last_hit_side() == "player" else "player"
		intensity.register_contact(next_side, next_side)
	_expect(intensity.get_rally_exchange_count() == exchange_count, "test helper should build the requested exchange count")
	return intensity.get_rally_tier()


func _tier_edge_after_exchanges(exchange_count: int) -> bool:
	var intensity := BallIntensity.new()
	intensity.register_contact("player", "player")
	for _index in range(exchange_count):
		var next_side := "boss" if intensity.get_last_hit_side() == "player" else "player"
		intensity.register_contact(next_side, next_side)
	_expect(intensity.get_rally_exchange_count() == exchange_count, "edge helper should build the requested exchange count")
	return intensity.did_rally_tier_advance()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
