extends SceneTree

# Seals the converted-perk effective-level overflow contract:
# `PerkConversionValues.get_value()` must EXTRAPOLATE past the authored table
# end (transcendent_crown / sage_ring / ignition overflow, CLAUDE.md
# "overflow keeps scaling" standard) instead of freezing at the Lv.max entry,
# while OVERFLOW_VALUE_BOUNDS clamps only domain-invalid results
# (chance > 100%, negative costs, zero auto-dash cooldown).

const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")

# 기대 바운드 맵 독립 선언(코덱스 P2 게이트): 정확히 15개 퍽의 17개
# 레인. 부메랑 스턴/유도 pct는 확률이 아니라 배수 소비(1.0+pct/100,
# mythic_item_throw_bonus_runtime)라 100% 캡=부당한 밸런스 하드캡 —
# 바운드 없이 계속 스케일한다(구조 스윕이 계속-성장 레그로 커버).
# 실제 OVERFLOW_VALUE_BOUNDS와 perk/key/min·max/값 집합을 양방향
# 정확 비교하고, 각 레인은 bound를 확실히 넘는 오버레벨에서 최종값이
# 정확히 bound에 붙는 행동까지 검증한다 — 구조 스윕만으로는 바운드
# 다수가 삭제돼도(직접 검증 5레인 외) GREEN인 구멍이 있었다.
const EXPECTED_OVERFLOW_BOUNDS := {
	"adversity_armor": {"trigger_chance_pct": {"max": 100.0}},
	"sensor": {"auto_dash_cooldown_sec": {"min": 1.0}},
	"battery": {"gauge_preserve_pct": {"max": 100.0}},
	"master": {"item_cooldown_pct": {"max": 95.0}},
	"lucky_coin": {"double_spawn_pct": {"max": 100.0}},
	"shrapnel_armor": {
		"trigger_chance_pct": {"max": 100.0},
		"gauge_cost": {"min": 0.0},
	},
	"foul_whistle": {"negate_chance_pct": {"max": 100.0}},
	"neural_helmet": {"aipill_gauge_reduction": {"max": 90.0}},
	"commando_arm": {"prep_reduction_pct": {"max": 95.0}},
	"rainbow_fur_glove": {
		"rainbow_glove_trigger_chance_pct": {"max": 100.0},
		"rainbow_glove_cooldown_reduction_pct": {"max": 95.0},
	},
	"soul_burst": {"soul_burst_gauge_cost": {"min": 0.0}},
	"bulletproof_hat": {"posture_correction_pct": {"max": 100.0}},
	"venom_mist_gauntlet": {"mist_trigger_chance_pct": {"max": 100.0}},
	"dowsing_goggles": {"bonus_perk_chance": {"max": 100.0}},
}

var _failures: Array[String] = []


func _init() -> void:
	_verify_within_table_values_unchanged()
	_verify_level_zero_contract_preserved()
	_verify_overflow_extends_linear_tables()
	_verify_overflow_extends_plateau_tables_by_average_slope()
	_verify_overflow_extends_decreasing_cost_tables()
	_verify_overflow_respects_domain_bounds()
	_verify_bounds_map_matches_expected_exactly()
	_verify_every_expected_bound_is_reachable_and_sticks()
	_verify_single_entry_tables_stay_fixed()
	_verify_every_multi_entry_lane_moves_or_hits_bound()
	if not _failures.is_empty():
		quit(1)
		return
	print("perk_conversion_overflow_scaling_smoke: ok")
	quit(0)


func _verify_within_table_values_unchanged() -> void:
	_expect_close(PerkConversionValues.get_value("star_detector", "star_bonus_pct", 3), 15.0, "within-table Lv.3 value must stay authored")
	_expect_close(PerkConversionValues.get_value("star_detector", "star_bonus_pct", 5), 25.0, "within-table Lv.5 value must stay authored")
	_expect_close(PerkConversionValues.get_value("soul_burst", "soul_burst_gauge_cost", 3), 135.0, "within-table cost value must stay authored")
	_expect_close(PerkConversionValues.get_value("shrapnel_armor", "gauge_cost", 5), 25.0, "within-table Lv.5 cost must stay authored")


func _verify_level_zero_contract_preserved() -> void:
	_expect_close(PerkConversionValues.get_value("star_detector", "star_bonus_pct", 0), 5.0, "level 0 must keep returning the Lv.1 value (S1c consumer contract)")
	_expect_close(PerkConversionValues.get_value("star_detector", "star_bonus_pct", -3), 5.0, "negative level must keep returning the Lv.1 value")


func _verify_overflow_extends_linear_tables() -> void:
	# star_detector [5..25] -> +5/level past the end.
	_expect_close(PerkConversionValues.get_value("star_detector", "star_bonus_pct", 6), 30.0, "Lv.6 star bonus must extrapolate past the table end")
	_expect_close(PerkConversionValues.get_value("star_detector", "star_bonus_pct", 7), 35.0, "Lv.7 star bonus must keep extrapolating")
	# gold_digger [15..55] -> +10/level past the end.
	_expect_close(PerkConversionValues.get_value("gold_digger", "gold_bonus_pct", 6), 65.0, "Lv.6 gold bonus must extrapolate past the table end")


func _verify_overflow_extends_plateau_tables_by_average_slope() -> void:
	# sensor token count [1,1,2,2,2]: last segment is flat, so overflow must
	# use the table's AVERAGE slope (+0.25/level) or the lane freezes forever.
	_expect_close(PerkConversionValues.get_value("sensor", "auto_dash_token_count", 9), 3.0, "plateau-shaped token table must keep growing via average slope")


func _verify_overflow_extends_decreasing_cost_tables() -> void:
	# shrapnel_armor gauge_cost [50..25] -> -6.25/level past the end.
	_expect_close(PerkConversionValues.get_value("shrapnel_armor", "gauge_cost", 7), 12.5, "Lv.7 shrapnel cost must keep decreasing")
	# soul_burst gauge_cost [170..100] -> -17.5/level past the end.
	_expect_close(PerkConversionValues.get_value("soul_burst", "soul_burst_gauge_cost", 6), 82.5, "Lv.6 soul burst cost must keep decreasing")


func _verify_overflow_respects_domain_bounds() -> void:
	_expect_close(PerkConversionValues.get_value("battery", "gauge_preserve_pct", 6), 100.0, "gauge preserve must cap at 100% (raw extrapolation would be 115)")
	_expect_close(PerkConversionValues.get_value("venom_mist_gauntlet", "mist_trigger_chance_pct", 12), 100.0, "trigger chance must cap at 100%")
	_expect_close(PerkConversionValues.get_value("dowsing_goggles", "bonus_perk_chance", 10), 100.0, "bonus perk chance must cap at 100%")
	_expect_close(PerkConversionValues.get_value("soul_burst", "soul_burst_gauge_cost", 12), 0.0, "cost lanes must floor at 0, never negative")
	_expect_close(PerkConversionValues.get_value("sensor", "auto_dash_cooldown_sec", 12), 1.0, "sensor auto-dash cooldown must floor at 1s")
	# 감소 계열 4레인은 소비 코드 실효 한도와 정합(레거시 패리티 —
	# 100으로 두면 neural은 실효 무증가·master는 쿨다운 0이 된다).
	_expect_close(PerkConversionValues.get_value("neural_helmet", "aipill_gauge_reduction", 17), 90.0, "neural gauge reduction must cap at the 90 base-gauge consumption limit")
	_expect_close(PerkConversionValues.get_value("neural_helmet", "aipill_ball_speed_bonus_pct", 7), 14.0, "Gangsin ball-speed bonus must keep scaling past max level")
	_expect_close(PerkConversionValues.get_value("master", "item_cooldown_pct", 60), 95.0, "master cooldown reduction must cap at the legacy 95 limit (never a zero cooldown)")
	_expect_close(PerkConversionValues.get_value("commando_arm", "prep_reduction_pct", 20), 95.0, "commando prep reduction must cap at the legacy 95 limit")
	_expect_close(PerkConversionValues.get_value("rainbow_fur_glove", "rainbow_glove_cooldown_reduction_pct", 30), 95.0, "rainbow cooldown reduction must cap at the consumer 0.95 clamp")


func _verify_bounds_map_matches_expected_exactly() -> void:
	# 양방향 정확 비교: 누락도 잉여도 결함이다(14개가 삭제돼도 GREEN이던
	# 구조-스윕 구멍 차단).
	var actual: Dictionary = PerkConversionValues.OVERFLOW_VALUE_BOUNDS
	_expect(actual.size() == EXPECTED_OVERFLOW_BOUNDS.size(), "bounds map must cover exactly %d perks (got %d)" % [EXPECTED_OVERFLOW_BOUNDS.size(), actual.size()])
	for perk_id_value in EXPECTED_OVERFLOW_BOUNDS.keys():
		var perk_id: String = str(perk_id_value)
		if not actual.has(perk_id):
			_expect(false, "bounds map is missing perk %s" % perk_id)
			continue
		var expected_lanes: Dictionary = EXPECTED_OVERFLOW_BOUNDS[perk_id]
		var actual_lanes: Dictionary = actual[perk_id]
		_expect(actual_lanes.size() == expected_lanes.size(), "%s must declare exactly %d bounded lanes (got %d)" % [perk_id, expected_lanes.size(), actual_lanes.size()])
		for key_value in expected_lanes.keys():
			var key: String = str(key_value)
			if not actual_lanes.has(key):
				_expect(false, "%s is missing bounded lane %s" % [perk_id, key])
				continue
			var expected_bound: Dictionary = expected_lanes[key]
			var actual_bound: Dictionary = actual_lanes[key]
			_expect(actual_bound.size() == expected_bound.size(), "%s.%s bound entry must match exactly" % [perk_id, key])
			for side_value in expected_bound.keys():
				var side: String = str(side_value)
				_expect(
					actual_bound.has(side) and is_equal_approx(float(actual_bound.get(side, NAN)), float(expected_bound[side])),
					"%s.%s %s bound must equal %.1f" % [perk_id, key, side, float(expected_bound[side])]
				)
	for perk_id_value in actual.keys():
		_expect(EXPECTED_OVERFLOW_BOUNDS.has(str(perk_id_value)), "unexpected extra bounded perk %s (balance caps do not belong here)" % str(perk_id_value))


func _verify_every_expected_bound_is_reachable_and_sticks() -> void:
	# 17레인 전수 행동 검증: 각 레인의 평균 기울기로 bound를 확실히 넘는
	# 오버레벨을 계산해 최종값이 정확히 bound에 붙는지 확인한다.
	for perk_id_value in EXPECTED_OVERFLOW_BOUNDS.keys():
		var perk_id: String = str(perk_id_value)
		for key_value in EXPECTED_OVERFLOW_BOUNDS[perk_id].keys():
			var key: String = str(key_value)
			var bounds: Dictionary = EXPECTED_OVERFLOW_BOUNDS[perk_id][key]
			var values: Array = PerkConversionValues.CONVERTED_PERK_VALUES.get(perk_id, {}).get(key, [])
			_expect(values.size() >= 2, "%s.%s bounded lane must be a multi-entry table" % [perk_id, key])
			if values.size() < 2:
				continue
			var size := values.size()
			var last := float(values[size - 1])
			var slope := (last - float(values[0])) / float(size - 1)
			if bounds.has("max"):
				_expect(slope > 0.0, "%s.%s max-bounded lane must grow toward its bound" % [perk_id, key])
				if slope > 0.0:
					var over_level: int = size + int(ceil((float(bounds["max"]) - last) / slope)) + 5
					_expect(
						is_equal_approx(PerkConversionValues.get_value(perk_id, key, over_level), float(bounds["max"])),
						"%s.%s must stick exactly on its max bound at Lv.%d" % [perk_id, key, over_level]
					)
			if bounds.has("min"):
				_expect(slope < 0.0, "%s.%s min-bounded lane must shrink toward its bound" % [perk_id, key])
				if slope < 0.0:
					var under_level: int = size + int(ceil((last - float(bounds["min"])) / -slope)) + 5
					_expect(
						is_equal_approx(PerkConversionValues.get_value(perk_id, key, under_level), float(bounds["min"])),
						"%s.%s must stick exactly on its min bound at Lv.%d" % [perk_id, key, under_level]
					)


func _verify_single_entry_tables_stay_fixed() -> void:
	_expect_close(PerkConversionValues.get_value("gravitybelt", "gravitybelt_instant_movement", 7), 1.0, "single-entry boolean tables must never extrapolate")
	_expect_close(PerkConversionValues.get_value("smartphone", "smartphone_auto_use_enabled", 7), 1.0, "single-entry boolean tables must never extrapolate")


func _verify_every_multi_entry_lane_moves_or_hits_bound() -> void:
	# Structural sweep: every multi-entry lane must either keep moving in its
	# slope direction past the table end, or sit exactly on a declared bound.
	for perk_id_value in PerkConversionValues.CONVERTED_PERK_VALUES.keys():
		var perk_id: String = str(perk_id_value)
		var table: Dictionary = PerkConversionValues.CONVERTED_PERK_VALUES[perk_id]
		for key_value in table.keys():
			var key: String = str(key_value)
			var values: Array = table[key]
			if values.size() < 2:
				continue
			var size := values.size()
			var slope := (float(values[size - 1]) - float(values[0])) / float(size - 1)
			var at_end := PerkConversionValues.get_value(perk_id, key, size)
			var over := PerkConversionValues.get_value(perk_id, key, size + 2)
			var bounds: Dictionary = PerkConversionValues.OVERFLOW_VALUE_BOUNDS.get(perk_id, {}).get(key, {})
			if slope > 0.0:
				if bounds.has("max"):
					_expect(over > at_end or is_equal_approx(over, float(bounds["max"])), "%s.%s overflow must grow or sit on its max bound" % [perk_id, key])
				else:
					_expect(over > at_end, "%s.%s overflow must keep growing past the table end" % [perk_id, key])
			elif slope < 0.0:
				if bounds.has("min"):
					_expect(over < at_end or is_equal_approx(over, float(bounds["min"])), "%s.%s overflow must shrink or sit on its min bound" % [perk_id, key])
				else:
					_expect(over < at_end, "%s.%s overflow must keep shrinking past the table end" % [perk_id, key])
			else:
				_expect(is_equal_approx(over, at_end), "%s.%s flat table should stay flat" % [perk_id, key])


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)
