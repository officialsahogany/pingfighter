extends SceneTree

# 뿔딸기 마스크 owner 스키마 교정 씰 — S3-a 슬라이스 A-0.
#
# 배경(owner-field 스키마 트랩):
#   mythic_item_owner_syncer 는 horn 계열 6키를 이미 만들어 owner 에 쓰고 있는데
#   (`:476-479`, `:520-524`), BattleSceneState.DEFAULT_VALUES 에 선언이 없어서
#   BattleSceneShell._set() 이 전부 거부하고 있었다(`battle_scene_shell.gd:136-138`).
#   `owner.set()` 은 조용한 no-op 이고 리더는 폴백만 돌려주므로, 소비자는 영원히
#   "변신 안 함"으로 읽는다. 실제로 config builder 는 owner 를 못 믿고 런타임을
#   직접 호출하는 우회를 쓰고 있었다.
#
# ⚠️ 이 씰은 **자유로운 values dict 를 가진 fake owner 를 쓰지 않는다.** 그런 페이크는
#    어떤 키든 받아주므로 스키마 결함이 그대로 통과하는 공허 GREEN 이 된다.
#    실제 BattleSceneState / BattleSceneShell 을 관통한다.

const BattleSceneState := preload("res://scripts/core/battle_scene_state.gd")
const BattleSceneShell := preload("res://scripts/core/battle_scene_shell.gd")
const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")

const HORN_BOOL_KEYS := [
	"horn_strawberry_mask_equipped",
	"horn_strawberry_transformed",
	"horn_strawberry_event_playing",
	"horn_strawberry_skills_locked",
	"horn_strawberry_control_locked",
]
const HORN_DICT_KEY := "horn_strawberry_context"

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _expect(label: String, ok: bool) -> void:
	if ok:
		print("PASS: %s" % label)
	else:
		_failed = true
		printerr("FAIL: %s" % label)


func _run() -> void:
	_test_declared_with_defaults()
	_test_state_set_get_roundtrip()
	_test_reset_restores_defaults()
	_test_shell_accepts_writes()
	_test_reader_absent_vs_false_semantics()

	if _failed:
		printerr("battle_scene_state_horn_strawberry_schema_smoke: FAILED")
		quit(1)
		return
	print("battle_scene_state_horn_strawberry_schema_smoke: ok")
	quit(0)


func _all_keys() -> Array:
	var keys: Array = HORN_BOOL_KEYS.duplicate()
	keys.append(HORN_DICT_KEY)
	return keys


func _test_declared_with_defaults() -> void:
	var state := BattleSceneState.new()
	for key in _all_keys():
		_expect("스키마 선언: %s" % str(key), state.has_key(str(key)))
	for key in HORN_BOOL_KEYS:
		_expect("기본값 false: %s" % str(key), state.get_value(str(key)) == false)
	var context_default: Variant = state.get_value(HORN_DICT_KEY)
	_expect("기본값 빈 dict: %s" % HORN_DICT_KEY, context_default is Dictionary and (context_default as Dictionary).is_empty())


func _test_state_set_get_roundtrip() -> void:
	var state := BattleSceneState.new()
	for key in HORN_BOOL_KEYS:
		state.set_value(str(key), true)
		_expect("set → get 왕복: %s" % str(key), state.get_value(str(key)) == true)
	state.set_value(HORN_DICT_KEY, {"transformed": true, "phase": "event"})
	var ctx: Variant = state.get_value(HORN_DICT_KEY)
	_expect(
		"set → get 왕복: %s (dict 내용 보존)" % HORN_DICT_KEY,
		ctx is Dictionary and bool((ctx as Dictionary).get("transformed", false)) and str((ctx as Dictionary).get("phase", "")) == "event"
	)


func _test_reset_restores_defaults() -> void:
	var state := BattleSceneState.new()
	for key in HORN_BOOL_KEYS:
		state.set_value(str(key), true)
	state.set_value(HORN_DICT_KEY, {"transformed": true})
	state.reset()
	for key in HORN_BOOL_KEYS:
		_expect("reset 후 기본값 복귀: %s" % str(key), state.get_value(str(key)) == false)
	var ctx: Variant = state.get_value(HORN_DICT_KEY)
	_expect(
		"reset 후 기본값 복귀: %s" % HORN_DICT_KEY,
		ctx is Dictionary and (ctx as Dictionary).is_empty()
	)


func _test_shell_accepts_writes() -> void:
	# 실제 owner 표면(BattleSceneShell)이 write 를 **받아들이는지** 본다.
	# 교정 전에는 _set() 이 false 를 돌려주고 값이 사라졌다.
	var shell := BattleSceneShell.new()
	for key in HORN_BOOL_KEYS:
		shell.set(str(key), true)
		_expect(
			"셸 write 수용: %s (owner.set 이 조용히 버려지지 않음)" % str(key),
			bool(BattleSceneOwnerReader.get_value(shell, str(key), false))
		)
	shell.set(HORN_DICT_KEY, {"transformed": true})
	var ctx: Dictionary = BattleSceneOwnerReader.get_dictionary(shell, HORN_DICT_KEY)
	_expect("셸 write 수용: %s" % HORN_DICT_KEY, bool(ctx.get("transformed", false)))
	shell.free()


func _test_reader_absent_vs_false_semantics() -> void:
	# 오딘 fallback 의미론이 성립하려면 리더가 "키 부재"와 "키 존재+false"를 구분해야
	# 한다. 부재 → null → 폴백 / 존재+false → false.
	var shell := BattleSceneShell.new()
	_expect(
		"미선언 키는 폴백을 돌려준다(부재 판정)",
		bool(BattleSceneOwnerReader.get_value(shell, "__undeclared_key__", true))
	)
	shell.set("odins_eye_transformed", false)
	shell.set("odins_eye_penalty_active", true)
	_expect(
		"선언 키가 false 면 폴백을 쓰지 않는다 (transformed=false → penalty 무시)",
		not bool(BattleSceneOwnerReader.get_value(
			shell,
			"odins_eye_transformed",
			BattleSceneOwnerReader.get_value(shell, "odins_eye_penalty_active", false)
		))
	)
	shell.free()
