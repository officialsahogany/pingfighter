extends SceneTree

# Smasher 콤보증폭칩 — 드라이브 증폭 OUTCOME 스모크.
# 베이스 콤보 스케일링은 이미 포팅돼 있고(smasher_drive_initial_bounce_resolver),
# 이 스모크는 칩 레벨이 콤보 비례 항(공속 bypass / 스핀 / 스핀캡)을 (1+amp)로
# 실제로 증폭하는지 OUTCOME(발사 공속·스핀)으로 검증한다.
#
# 반증검증(수동, in-place Edit 토글 — git reset/checkout/stash 금지):
#  resolver의 (1.0 + combo_amp_speed) / (1.0 + combo_amp_curve)를 제거하면
#  Lv5==Lv0이 되어 _verify_chip_raises_drive_speed / _spin 이 FAIL해야 한다.

const SmasherDriveInitialBounceResolver := preload("res://scripts/characters/smasher_drive_initial_bounce_resolver.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

const _SEED := 987654321
const _COMBO := 2          # 작은 콤보: 발사 속도 캡(미증폭)에 막히지 않게
const _BASE_SPEED := 8.0

var _failures: Array[String] = []


func _init() -> void:
	_verify_bonus_helper_values()
	_verify_curve_lane_caps_at_lv3()
	_verify_chip_raises_drive_speed()
	_verify_chip_raises_drive_spin()
	_verify_lv0_is_noop()

	if _failures.is_empty():
		print("smasher_combo_amplifier_drive_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _make_perk_state(level: int) -> Object:
	var rps: Object = RuntimePerkState.new()
	if level > 0:
		rps.runtime_skill_levels["combo_amplifier_chip"] = level
	return rps


func _amp(level: int) -> Dictionary:
	return _make_perk_state(level).get_combo_amplifier_chip_bonus()


func _apply_drive(amp_speed: float, amp_curve: float) -> Dictionary:
	# 동일 seed로 resolver 내부 randf_range(base 배율)를 고정 → amp만 차이가 되게.
	seed(_SEED)
	var resolver: Object = SmasherDriveInitialBounceResolver.new()
	return resolver.apply(
		_BASE_SPEED, 0.0, -1, _COMBO, 1.0, null, 2, 0.0, amp_speed, amp_curve
	)


func _verify_bonus_helper_values() -> void:
	var lv0: Dictionary = _amp(0)
	_expect(
		is_equal_approx(float(lv0["drive_speed"]), 0.0)
			and is_equal_approx(float(lv0["drive_curve"]), 0.0)
			and is_equal_approx(float(lv0["smash_speed"]), 0.0),
		"Lv0 chip bonus should be all zero"
	)
	var lv1: Dictionary = _amp(1)
	_expect(is_equal_approx(float(lv1["drive_speed"]), 0.90), "Lv1 drive_speed should be +90%")
	_expect(is_equal_approx(float(lv1["drive_curve"]), 0.05), "Lv1 drive_curve should be +5%")
	_expect(is_equal_approx(float(lv1["smash_speed"]), 0.45), "Lv1 smash_speed should be +45%")
	var lv5: Dictionary = _amp(5)
	_expect(is_equal_approx(float(lv5["drive_speed"]), 4.50), "Lv5 drive_speed should be +450%")
	_expect(is_equal_approx(float(lv5["smash_speed"]), 2.25), "Lv5 smash_speed should be +225%")


func _verify_curve_lane_caps_at_lv3() -> void:
	# 공속/스매시는 계속 스케일, 커브만 Lv3에서 하드캡(+15%).
	var lv3: Dictionary = _amp(3)
	var lv4: Dictionary = _amp(4)
	var lv5: Dictionary = _amp(5)
	_expect(is_equal_approx(float(lv3["drive_curve"]), 0.15), "Lv3 drive_curve should be +15% (cap)")
	_expect(is_equal_approx(float(lv4["drive_curve"]), 0.15), "Lv4 drive_curve should stay +15% (Lv3 cap)")
	_expect(is_equal_approx(float(lv5["drive_curve"]), 0.15), "Lv5 drive_curve should stay +15% (Lv3 cap)")
	_expect(
		float(lv5["drive_speed"]) > float(lv3["drive_speed"]) + 0.001,
		"drive_speed lane should keep scaling past Lv3 (no curve cap)"
	)


func _verify_chip_raises_drive_speed() -> void:
	var lv0: Dictionary = _apply_drive(0.0, 0.0)
	var amp5: Dictionary = _amp(5)
	var lv5: Dictionary = _apply_drive(float(amp5["drive_speed"]), float(amp5["drive_curve"]))
	_expect(
		float(lv5["speed"]) > float(lv0["speed"]) + 0.001,
		"Lv5 chip should raise drive launch speed vs Lv0 (combo speed bypass amped)"
	)


func _verify_chip_raises_drive_spin() -> void:
	var lv0: Dictionary = _apply_drive(0.0, 0.0)
	var amp5: Dictionary = _amp(5)
	var lv5: Dictionary = _apply_drive(float(amp5["drive_speed"]), float(amp5["drive_curve"]))
	_expect(
		float(lv5["spin_strength"]) > float(lv0["spin_strength"]) + 0.001,
		"Lv5 chip should raise drive spin_strength vs Lv0 (combo spin amped)"
	)


func _verify_lv0_is_noop() -> void:
	# amp 0 → 기존 base 값 그대로(회귀 가드). 명시 0,0 호출과 amp 인자 생략(default)이 동일해야.
	var explicit_zero: Dictionary = _apply_drive(0.0, 0.0)
	seed(_SEED)
	var resolver: Object = SmasherDriveInitialBounceResolver.new()
	var defaults: Dictionary = resolver.apply(_BASE_SPEED, 0.0, -1, _COMBO, 1.0, null, 2, 0.0)
	_expect(
		is_equal_approx(float(explicit_zero["speed"]), float(defaults["speed"]))
			and is_equal_approx(float(explicit_zero["spin_strength"]), float(defaults["spin_strength"])),
		"amp 0.0 must be a true no-op (equal to no-amp default call)"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
