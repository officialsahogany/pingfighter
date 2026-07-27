extends SceneTree

# Stage 6 테트리서 비주얼 셸 프리웜 봉인.
#
# 회귀 사건(2026-07-27 라이브 실측, S6 스파이크 창 #1):
#   actors.lookup_renderer            max 43.50ms   <- 렌더러 모듈 콜드 인스턴스화
#   actors.renderer_draw              max 51.70ms   <- 보스 시트 7장 동기 디코드
#   01.actors.total                   max 95.37ms
#   draw.scene.playfield              max 97.14ms
#   stage6.pillar.tetriser_boss_hud   max 156.61ms  <- 스킬카드 PNG 4장 동기 로드
#   draw.pillar_overlay.post_hud      max 157.19ms
# 원인: `battle_boot_resource_prewarm_controller`의 스테이지별 프리웜 match에
# `6:`이 없어(1,2,3,4,5,7만 존재) Stage 6 전체가 `return 0`으로 떨어졌고,
# `stage6_tetriser_actor_renderer.prewarm_assets_step()`은 자식 위임 없이
# `return true`라 디버그 피커가 불러도 무의미했다. 두 콜드 경로가 통째로 첫
# 전투 draw 프레임에 떨어졌다(Hot-Path Lazy Init Trap).
#
# 이 씰이 함께 무는 세 가지(하나라도 빠지면 결함을 못 잡는다):
#   1. 컨트롤러 wiring — 스텝 수/라벨/디스패치가 Stage 6를 실제로 태우는가
#   2. registry 인스턴스화 — 첫 draw 전에 모듈 3종이 생성되는가(43.50ms 클래스)
#   3. uncached 동기 디코드 수 — 프리웜 후 남은 미캐시 자산이 0인가(51.70/156.61ms 클래스)
# 기존 `battle_boot_resource_prewarm_smoke`는 S6 wiring이 없고
# `stage6_boss_skill_hud_prewarm_smoke`는 HUD 단품만 봐서 둘 다 GREEN인 채로
# 이 결함을 통과시켰다.

const BattleBootResourcePrewarmController := preload("res://scripts/core/battle_boot_resource_prewarm_controller.gd")
const Stage6TetriserActorRenderer := preload("res://scripts/stages/stage6/stage6_tetriser_actor_renderer.gd")
const Stage6TetriserBossActorRenderer := preload("res://scripts/stages/stage6/stage6_tetriser_boss_actor_renderer.gd")
const Stage6TetriserBossSkillHudAssets := preload("res://scripts/stages/stage6/stage6_tetriser_boss_skill_hud_assets.gd")
const Stage6TetriserBossSkillHudRenderer := preload("res://scripts/stages/stage6/stage6_tetriser_boss_skill_hud_renderer.gd")
const Stage6TetriserPillarBackground := preload("res://scripts/stages/stage6/stage6_tetriser_pillar_background.gd")
const Stage6TetriserPillarSceneDrawer := preload("res://scripts/stages/stage6/stage6_tetriser_pillar_scene_drawer.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const STAGE6 := 6
const EXPECTED_STEP_LABELS := [
	"stage6_pillar_background",
	"stage6_tetriser_actor_renderer",
	"stage6_tetriser_pillar_scene_drawer",
	"stage6_tetriser_boss_skill_hud_renderer",
]
const HUD_CARD_PATHS := [
	Stage6TetriserBossSkillHudAssets.TETRO_DROP_SKILLCARD_TEXTURE_PATH,
	Stage6TetriserBossSkillHudAssets.GUARD_BLOCK_SKILLCARD_TEXTURE_PATH,
	Stage6TetriserBossSkillHudAssets.TETRO_WALL_SKILLCARD_TEXTURE_PATH,
	Stage6TetriserBossSkillHudAssets.SUPER_TETRISER_SKILLCARD_TEXTURE_PATH,
]
# 프리웜 공통 스텝 수만큼 오프셋을 밀어야 스테이지별 스텝이 시작된다.
const COMMON_STEP_COUNT := BattleBootResourcePrewarmController.STAGE_RUNTIME_PREWARM_COMMON_STEP_COUNT

var _failures: Array[String] = []


class FakeOwner:
	var current_stage := 6
	var selected_character_type := "smasher"


# 요청된 모듈 키를 기록하는 lazy registry. 프리웜이 실제로 인스턴스를
# 만들어 캐시에 남기는지( = 첫 draw 때 콜드 lookup이 없는지) 관측한다.
class FakeModuleRegistry:
	var instances: Dictionary = {}
	var requested: Array[String] = []

	func get_module(key: String) -> Object:
		requested.append(key)
		if instances.has(key):
			return instances[key]
		var made: Object = _make(key)
		if made != null:
			instances[key] = made
		return made

	func has_cached(key: String) -> bool:
		return instances.has(key)

	func _make(key: String) -> Object:
		match key:
			"stage6_tetriser_pillar_background":
				return Stage6TetriserPillarBackground.new()
			"stage6_tetriser_actor_renderer":
				return Stage6TetriserActorRenderer.new()
			"stage6_tetriser_pillar_scene_drawer":
				return Stage6TetriserPillarSceneDrawer.new()
			"stage6_tetriser_boss_skill_hud_renderer":
				return Stage6TetriserBossSkillHudRenderer.new()
		return null


func _init() -> void:
	_test_controller_wires_stage6_steps()
	_test_prewarm_instantiates_visual_shell_modules()
	_test_boss_sheets_leave_no_uncached_decode()
	_test_hud_skillcards_leave_no_uncached_decode()

	if _failures.is_empty():
		print("stage6_visual_shell_prewarm_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


# 레그 1 — 컨트롤러 wiring. 수정 전에는 step_count == 0이라 RED.
func _test_controller_wires_stage6_steps() -> void:
	var controller := BattleBootResourcePrewarmController.new()
	var owner := FakeOwner.new()
	var step_count: int = controller._get_stage_specific_runtime_prewarm_step_count(owner, STAGE6)
	_expect(
		step_count == EXPECTED_STEP_LABELS.size(),
		"Stage 6 runtime prewarm should expose %d stage steps (got %d)" % [EXPECTED_STEP_LABELS.size(), step_count]
	)
	for i in range(EXPECTED_STEP_LABELS.size()):
		var label: String = controller._get_stage_runtime_prewarm_step_label(
			owner, STAGE6, COMMON_STEP_COUNT + i
		)
		_expect(
			label == str(EXPECTED_STEP_LABELS[i]),
			"Stage 6 prewarm step %d should be labelled '%s' (got '%s')" % [i, EXPECTED_STEP_LABELS[i], label]
		)


# 레그 2 — registry 인스턴스화(actors.lookup_renderer 43.50ms 클래스).
# 프리웜이 돌고 나면 비주얼 셸 모듈 3종이 registry 캐시에 있어야 첫 draw가
# 콜드 생성을 하지 않는다. 수정 전에는 아무 키도 요청되지 않아 RED.
func _test_prewarm_instantiates_visual_shell_modules() -> void:
	var controller := BattleBootResourcePrewarmController.new()
	var owner := FakeOwner.new()
	var registry := FakeModuleRegistry.new()
	_run_all_stage6_steps(controller, owner, registry)

	for key in [
		"stage6_tetriser_pillar_background",
		"stage6_tetriser_actor_renderer",
		"stage6_tetriser_pillar_scene_drawer",
		"stage6_tetriser_boss_skill_hud_renderer",
	]:
		_expect(
			registry.has_cached(key),
			"Stage 6 prewarm should instantiate '%s' before the first battle draw" % key
		)


# 레그 3 — uncached 동기 디코드(actors.renderer_draw 51.70ms 클래스).
# 전체 API 호출 수가 아니라 "프리웜 후에도 캐시에 없는 자산 수"를 센다.
# 수정 전에는 actor renderer가 자식 위임을 안 해 7장 전부 미캐시 -> RED.
func _test_boss_sheets_leave_no_uncached_decode() -> void:
	ProjectResourceLoader.clear_caches()
	var actor_renderer := Stage6TetriserActorRenderer.new()
	actor_renderer.prewarm_assets()

	var uncached := _count_uncached(_boss_sheet_paths())
	_expect(
		uncached == 0,
		"Stage 6 actor prewarm should leave 0 uncached boss sheets (got %d of %d)" % [uncached, _boss_sheet_paths().size()]
	)


# 레그 4 — 스킬카드 PNG(stage6.pillar.tetriser_boss_hud 156.61ms 클래스).
# 컨트롤러 경유로 돌려서 wiring까지 함께 문다(HUD 단품 호출이 아님).
func _test_hud_skillcards_leave_no_uncached_decode() -> void:
	ProjectResourceLoader.clear_caches()
	var controller := BattleBootResourcePrewarmController.new()
	var owner := FakeOwner.new()
	var registry := FakeModuleRegistry.new()
	_run_all_stage6_steps(controller, owner, registry)

	var uncached := _count_uncached(HUD_CARD_PATHS)
	_expect(
		uncached == 0,
		"Stage 6 prewarm should leave 0 uncached boss skillcards (got %d of %d)" % [uncached, HUD_CARD_PATHS.size()]
	)


func _run_all_stage6_steps(controller: Object, owner: Object, registry: Object) -> void:
	var getter := Callable(registry, "get_module")
	var step_count: int = controller._get_stage_specific_runtime_prewarm_step_count(owner, STAGE6)
	for stage_step in range(step_count):
		# 스텝형 프리웜은 false를 반환하며 여러 프레임에 걸쳐 진행한다.
		# 씰에서는 완료까지 돌리되 무한 루프는 상한으로 막는다.
		var guard := 0
		while not controller._run_stage_specific_runtime_prewarm_step(owner, getter, STAGE6, stage_step):
			guard += 1
			if guard > 64:
				_failures.append("Stage 6 prewarm step %d did not finish within 64 iterations" % stage_step)
				break


func _boss_sheet_paths() -> Array:
	var paths: Array = []
	for key in Stage6TetriserBossActorRenderer.STATE_ORDER:
		paths.append(str(Stage6TetriserBossActorRenderer.SHEET_PATHS[key]))
	return paths


func _count_uncached(paths: Array) -> int:
	var uncached := 0
	for path in paths:
		if ProjectResourceLoader.get_cached_texture(str(path)) == null:
			uncached += 1
	return uncached


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
