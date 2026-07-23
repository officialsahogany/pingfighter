extends SceneTree

# Seal: stage1 필러 HUD 프리웜의 광장 골드 캐시 warm이 결과화면 모듈을
# 콜드 인스턴스화하지 않는다 (perf — 로딩 전환 히치 제거).
#
# 2026-07-24 로딩 히치 진단: stage_runtime_prewarm.step.12.stage1_pillar_scene
# 단일 프레임 1237ms의 정체는 프리웜 step 6이 광장 골드 숫자 하나를 읽으려고
# stage_clear_result_screen 모듈을 통째로 첫 인스턴스화한 것([PrewarmColdInstantiate]
# 계측으로 확정, fps=2). 결과화면은 스테이지 클리어 때만 필요하고, 골드는
# 경량 PlazaSaveStore(동일 클래스·동일 기본 경로)로 직접 읽을 수 있다.
#
# 이 씰이 봉인하는 계약:
#  (1) 프리웜 gold-warm이 module_getter로 'stage_clear_result_screen'를 절대
#      요청하지 않는다(결과화면 콜드 생성 0 = 1237ms 스톨 제거).
#  (2) 그럼에도 골드 캐시는 세이브 파일의 실제 값으로 정확히 데워진다.
#
# 반증검증(수동, in-place 토글 — git reset 금지): 프리웜을 옛 코드
# (_get_module(module_getter, "stage_clear_result_screen"))로 되돌리면 (1)
# 레그가 requested_keys에 그 키가 잡혀 RED.

const PlazaSaveStore := preload("res://scripts/plaza/plaza_save_store.gd")
const Stage1PillarHudSceneDrawer := preload("res://scripts/stages/stage1/stage1_pillar_hud_scene_drawer.gd")

const TEST_SAVE_PATH := "user://__test_prewarm_gold_plaza_save.cfg"
const TEST_GOLD := 4242

var _failures: Array[String] = []
var _requested_keys: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_seed_plaza_save_file(TEST_GOLD)
	_verify_prewarm_warms_gold_without_instantiating_result_screen()
	_cleanup_plaza_save_file()

	if _failures.is_empty():
		print("stage1_pillar_prewarm_gold_no_result_screen_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _seed_plaza_save_file(gold: int) -> void:
	var store := PlazaSaveStore.new()
	store.set_save_path(TEST_SAVE_PATH)
	store.load()
	store.add_plaza_gold(gold)
	# add_plaza_gold saves to TEST_SAVE_PATH.


func _cleanup_plaza_save_file() -> void:
	for path in [TEST_SAVE_PATH, TEST_SAVE_PATH.trim_suffix(".cfg") + ".last_good.cfg"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# module_getter 스파이: 프리웜이 어떤 모듈 키를 요청하는지 기록만 하고 null을
# 돌려준다(결과화면 생성 자체를 막아 히치 재현 없이 계약만 검증).
func _spy_module_getter(key: String) -> Object:
	_requested_keys.append(key)
	return null


func _verify_prewarm_warms_gold_without_instantiating_result_screen() -> void:
	var drawer: Object = Stage1PillarHudSceneDrawer.new()
	drawer.set_plaza_gold_store_save_path_for_test(TEST_SAVE_PATH)

	_requested_keys.clear()
	drawer.call("_refresh_plaza_gold_cache_from_module_getter", Callable(self, "_spy_module_getter"))

	# (1) 결과화면 콜드 생성 0.
	_expect(
		not _requested_keys.has("stage_clear_result_screen"),
		"prewarm gold-warm must NOT request the stage_clear_result_screen module (got %s)" % str(_requested_keys)
	)

	# (2) 골드 캐시가 세이브 파일 실제 값으로 데워짐.
	var warmed: int = int(drawer.get("_plaza_gold_cache_value"))
	_expect(
		warmed == TEST_GOLD,
		"prewarm should warm the plaza gold cache to the saved value (%d, got %d)" % [TEST_GOLD, warmed]
	)
	_expect(
		bool(drawer.get("_plaza_gold_cache_loaded")),
		"prewarm should mark the plaza gold cache as loaded"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
