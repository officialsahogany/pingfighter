extends SceneTree

# 승리 전리품 상자(보스 격파 후 드랍) 오퍼 씰: 매치가 끝난 뒤 열리는 상자 퍽
# 선택에는 즉시형 보상 퍽(차원개방 / 풀게이징 / 원숭이은혜)이 나오면 안 된다.
# 이 시점에는 공/랠리가 없어 즉발 효과를 쓸 곳이 없으므로 상자 보상 한 장이
# 사장된 카드로 소모된다. 새로고침은 선택지 재굴림 유틸이라 의도적으로 남긴다
# (= INSTANT_PERKS 전체를 끄는 `exclude_instant`와는 다른 계약).
#
# 씰 구성:
#   1) 카탈로그 대조군/게이트 — 같은 풀에서 플래그만 뒤집어 변별력을 증명한다
#      (플래그 OFF에서 3종이 실제로 나온다는 대조군이 없으면 공허 GREEN).
#   2) 실 RuntimePerkState.open_next_choice 관통 — 카탈로그 직접 호출이 아니라
#      실제 모달 오픈 경로가 owner 플래그를 카탈로그까지 전달하는지.
#   3) 실 전리품 페이즈 관통 — 상자 드랍 -> 패들 픽업 -> 실 리졸버 스타포인트
#      그랜트 -> 실 퍽 상태 collect_star_points -> 실 오픈까지 왕복시켜, 살아있는
#      선택지 카드에 3종이 없음을 단언한다.

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const VictoryLootPhaseState := preload("res://scripts/core/victory_loot_phase_state.gd")
const StageClearRewardResolver := preload("res://scripts/core/stage_clear_reward_resolver.gd")
const BattleSceneState := preload("res://scripts/core/battle_scene_state.gd")
const MatchScoreState := preload("res://scripts/core/match_score_state.gd")

# 전리품 상자 수는 점수 구간 파생이므로 픽스처 점수도 룰 상수에서 만든다.
const DEUCE_WIN_PLAYER_SCORE := MatchScoreState.WIN_GOAL + 1
const DEUCE_WIN_BOSS_SCORE := MatchScoreState.WIN_GOAL - 1

const EXCLUDED_IDS := ["instant_gauge_full", "instant_dimension_gate", "instant_monkey_blessing"]
const KEPT_INSTANT_ID := "common_refresh"

# 카탈로그 스캔: 풀 전체가 결과에 들어오도록 큰 목표 장수로 뽑는다.
const POOL_SCAN_TARGET := 300
const POOL_SCAN_ITERATIONS := 24
# 실 모달 경로는 3장 드로우라 확률적 — 대조군이 3종을 한 번도 못 보는 일이
# 없도록 충분히 반복한다(장당 히트율 ~20%대, 80회면 미검출 확률 ~1e-9).
const MODAL_DRAW_ITERATIONS := 80

var _failures: Array[String] = []
var _legs_completed: int = 0


class SchemaGatedOwner:
	extends RefCounted

	var scene_state: Object = BattleSceneState.new()
	var rejected_keys: Array[String] = []

	func _init() -> void:
		scene_state.reset()
		scene_state.set_value("selected_character_type", "smasher")
		# 보스 비전 20% lane은 이 스위트의 관심사가 아니다 — 전용 씰이 따로 봉인한다.
		scene_state.set_value("stage1_boss_variant", "gaksi")
		scene_state.set_value("boss_pos", Vector2(330.0, 25.0))
		scene_state.set_value("player_pos", Vector2(-500.0, 700.0))
		scene_state.set_value("player_paddle_width", 155.0)
		scene_state.set_value("player_paddle_height", 50.0)

	func _get(property: StringName) -> Variant:
		var key := str(property)
		if scene_state.has_key(key):
			return scene_state.get_value(key)
		return null

	func _set(property: StringName, value: Variant) -> bool:
		var key := str(property)
		if not scene_state.has_key(key):
			rejected_keys.append(key)
			return false
		scene_state.set_value(key, value)
		return true

	func value_of(key: String) -> Variant:
		if scene_state.has_key(key):
			return scene_state.get_value(key)
		return null


class FakeRegistry:
	extends RefCounted

	var runtime_perk_state: Object = null
	var runtime_perk_catalog: Object = null

	func get_instance(key: String) -> Object:
		match key:
			"runtime_perk_state":
				return runtime_perk_state
			"runtime_perk_catalog":
				return runtime_perk_catalog
			_:
				return null


class StarpointRollRealGrantResolver:
	# 롤만 고정(항상 스타포인트)하고 지급은 실 리졸버로 넘긴다 — 그래야
	# _grant_starpoint_reward -> collect_star_points 실경로를 관통한다.
	extends RefCounted

	var _real: Object = StageClearRewardResolver.new()
	var roll_calls := 0

	func roll_reward(_box_kind: String, _owner: Object = null, _registry: Object = null) -> Dictionary:
		roll_calls += 1
		return {"type": "starpoint", "label": "★ 1", "amount": 1}

	func grant_rewards(rewards: Array, owner: Object, registry: Object) -> Dictionary:
		return _real.grant_rewards(rewards, owner, registry)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# 라이브 런타임은 패시브->퍽 전환 플래그가 ON(boot_flow_scene._ready)이고,
	# 스모크 기본값은 OFF다. 예약/슬롯 예산 레인이 갈리므로 양쪽에서 봉인한다.
	for conversion_enabled in [false, true]:
		PerkConversionFlags.debug_set_enabled(bool(conversion_enabled))
		_verify_catalog_pool_flag_flip(bool(conversion_enabled))
		_verify_real_modal_open_path_respects_loot_flag(bool(conversion_enabled))
	PerkConversionFlags.debug_set_enabled(false)
	_verify_victory_loot_box_choice_excludes_instants()

	# 레그-abort 공허 GREEN 방지: 각 레그가 끝까지 돈 횟수를 센다.
	if _legs_completed != 5:
		_failures.append(
			"every leg must run to completion (aborted leg = vacuous GREEN); completed=%d/5" % _legs_completed
		)

	if _failures.is_empty():
		print("victory_loot_instant_perk_exclusion_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_catalog_pool_flag_flip(conversion_enabled: bool) -> void:
	var lane := "conversion=%s" % str(conversion_enabled)
	var catalog := RuntimePerkCatalog.new()

	# 대조군: 전리품 페이즈가 아니면 3종이 정상적으로 오퍼된다.
	var off_owner := SchemaGatedOwner.new()
	off_owner.scene_state.set_value("victory_loot_phase_active", false)
	var off_ids := _scan_catalog_ids(catalog, off_owner)
	for excluded_id in EXCLUDED_IDS:
		_expect(
			off_ids.has(excluded_id),
			"control(%s): %s must still be offered outside the victory loot phase (else the gate leg is vacuous)" % [lane, excluded_id]
		)

	# 게이트: 전리품 페이즈 중에는 3종이 한 번도 나오지 않는다.
	var on_owner := SchemaGatedOwner.new()
	on_owner.scene_state.set_value("victory_loot_phase_active", true)
	var on_ids := _scan_catalog_ids(catalog, on_owner)
	for excluded_id in EXCLUDED_IDS:
		_expect(
			not on_ids.has(excluded_id),
			"victory loot phase offers must never contain the instant reward perk %s (%s)" % [excluded_id, lane]
		)
	# 표적 제외 계약: 새로고침까지 같이 죽으면 exclude_instant와 구분되지 않는다.
	_expect(
		on_ids.has(KEPT_INSTANT_ID),
		"victory loot exclusion must stay targeted — %s (choice reroll) should still be offered (%s)" % [KEPT_INSTANT_ID, lane]
	)
	_expect(
		off_owner.rejected_keys.is_empty() and on_owner.rejected_keys.is_empty(),
		"loot flag fixtures must use declared owner schema keys only (%s)" % lane
	)
	_legs_completed += 1


func _verify_real_modal_open_path_respects_loot_flag(conversion_enabled: bool) -> void:
	var lane := "conversion=%s" % str(conversion_enabled)
	# 카탈로그 직접 호출이 아니라 실제 모달 오픈 경로(state -> open flow ->
	# catalog.get_choices)가 owner 플래그를 관통하는지 확인한다.
	var catalog := RuntimePerkCatalog.new()
	var registry := FakeRegistry.new()

	var off_owner := SchemaGatedOwner.new()
	off_owner.scene_state.set_value("victory_loot_phase_active", false)
	var off_hits := _count_excluded_hits_over_modal_draws(catalog, registry, off_owner)
	_expect(
		off_hits > 0,
		"control(%s): the live modal path should still draw instant reward perks outside the loot phase (%d draws)" % [lane, MODAL_DRAW_ITERATIONS]
	)

	var on_owner := SchemaGatedOwner.new()
	on_owner.scene_state.set_value("victory_loot_phase_active", true)
	var on_hits := _count_excluded_hits_over_modal_draws(catalog, registry, on_owner)
	_expect(
		on_hits == 0,
		"live modal opens during the loot phase must not draw instant reward perks (%s); hits=%d" % [lane, on_hits]
	)
	_legs_completed += 1


func _verify_victory_loot_box_choice_excludes_instants() -> void:
	# 실 왕복: 상자 드랍 -> 패들 픽업 -> 실 리졸버 스타포인트 그랜트 ->
	# 실 RuntimePerkState.collect_star_points -> 실 선택지 오픈.
	var owner := SchemaGatedOwner.new()
	var catalog := RuntimePerkCatalog.new()
	var perk_state := RuntimePerkState.new()
	var registry := FakeRegistry.new()
	registry.runtime_perk_state = perk_state
	registry.runtime_perk_catalog = catalog

	var loot := VictoryLootPhaseState.new()
	var resolver := StarpointRollRealGrantResolver.new()
	# _ensure_reward_resolver는 start()에서 도는 lazy 생성이라 주입은 start 이전.
	loot.set_reward_resolver_for_test(resolver)
	_expect(
		loot.start(owner, registry, DEUCE_WIN_PLAYER_SCORE, DEUCE_WIN_BOSS_SCORE, Callable()),
		"loot pierce leg should start a one-box deuce loot phase"
	)
	_expect(
		bool(owner.value_of("victory_loot_phase_active")),
		"loot start must mirror the owner schema flag the catalog gate reads"
	)

	for _i in range(600):
		loot.update(1.0 / 60.0)
		if str((loot.boxes[0] as Dictionary).get("phase", "")) == VictoryLootPhaseState.BOX_PHASE_REST:
			break
	var rest_pos: Vector2 = (loot.boxes[0] as Dictionary).get("pos")
	owner.scene_state.set_value("player_pos", rest_pos - Vector2(77.5, 25.0))
	for _i in range(240):
		loot.update(1.0 / 60.0)
		if bool((loot.boxes[0] as Dictionary).get("reward_granted", false)):
			break

	_expect(resolver.roll_calls == 1, "the pierce leg should open exactly one box")
	_expect(
		bool((loot.boxes[0] as Dictionary).get("reward_granted", false)),
		"the box reward must actually grant (an ungranted box makes the choice assertion vacuous)"
	)
	var live_ids := _choice_ids(perk_state.current_choices)
	_expect(
		not live_ids.is_empty(),
		"the loot box starpoint should open a live perk choice (empty choices = vacuous assertion)"
	)
	for excluded_id in EXCLUDED_IDS:
		_expect(
			not live_ids.has(excluded_id),
			"the live victory loot box perk choice must not offer %s; ids=%s" % [excluded_id, ", ".join(live_ids)]
		)
	_legs_completed += 1


func _scan_catalog_ids(catalog: Object, owner: Object) -> Dictionary:
	var seen: Dictionary = {}
	for _i in range(POOL_SCAN_ITERATIONS):
		for choice_id in _choice_ids(catalog.get_choices("smasher", {}, false, POOL_SCAN_TARGET, owner, null)):
			seen[choice_id] = true
	return seen


func _count_excluded_hits_over_modal_draws(catalog: Object, registry: Object, owner: Object) -> int:
	var hits: int = 0
	for _i in range(MODAL_DRAW_ITERATIONS):
		var state := RuntimePerkState.new()
		state.pending_skill_choices = 1
		state.open_next_choice("smasher", catalog, false, owner, registry)
		for choice_id in _choice_ids(state.current_choices):
			if EXCLUDED_IDS.has(choice_id):
				hits += 1
	return hits


func _choice_ids(choices: Array) -> Array[String]:
	var ids: Array[String] = []
	for value in choices:
		if value is Dictionary:
			ids.append(str((value as Dictionary).get("id", "")))
	return ids


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
